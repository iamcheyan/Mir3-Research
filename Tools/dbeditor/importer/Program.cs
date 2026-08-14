// DBImporter —— 把 dbeditor JSON 工作区的改动写入 System.db（临时副本）。
//
// 语义（Zircon LibraryCore/MirDB 源码实证）：
//   - [Association] 配对属性 setter 自动维护反向 DBBindingList（DBObject.OnChanged →
//     CreateLink/RemoveLink）→ 派生回链（ItemInfo.Drops）不直接写，由子行 DropInfo.Item 驱动；
//   - 无 Association 的 DBBindingList（SetInfo.Items）是普通存储数据 → Clear + Add 直写；
//   - Stats = SortedDictionary<Stat,int> 索引器（赋 0 即删键）；
//   - CreateNewObject() 自动分配 Index = max+1（与编辑器 next_index 同规则）；
//   - Delete() 走 Session 级联（Aggregate Association 一并处理）；
//   - Save(true) 自动 bump SystemDatabaseInfo.Version。
//
// 安全：端口 7000 在监听则拒绝（--no-port-check 仅供隔离测试）；校验失败或
// 不支持的改动类型 → 中止且不落盘。退出码：0 成功/无改动，10 服务端运行，
// 11 悬空引用，12 应用失败。
using Library;
using Library.SystemModels;
using Library.MirDB;
using MirDB;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Text.Json;

string workspace = null, srcDb = null, reportPath = null;
bool noPortCheck = args.Contains("--no-port-check");
for (int i = 0; i < args.Length - 1; i++)
{
    if (args[i] == "--workspace") workspace = args[++i];
    else if (args[i] == "--src") srcDb = args[++i];
    else if (args[i] == "--report") reportPath = args[++i];
}
if (workspace == null || srcDb == null)
{
    Console.Error.WriteLine("用法: DBImporter --workspace <dir> --src <System.db> [--report <path>] [--no-port-check]");
    return 2;
}

var log = new StringBuilder();
void Log(string s) { log.AppendLine(s); Console.WriteLine(s); }

// ---------- 1) 服务端运行检测 ----------
if (!noPortCheck)
{
    try
    {
        using var tcp = new TcpClient();
        tcp.Connect("127.0.0.1", 7000);
        Log("[X] 端口 7000 有监听（服务端运行中）——拒绝写库。");
        if (reportPath != null) File.WriteAllText(reportPath, log.ToString());
        return 10;
    }
    catch (SocketException) { /* 未监听，继续 */ }
}

// ---------- 2) 载入工作区 / 基线 / meta ----------
var wsDir = new DirectoryInfo(workspace);
var baseDir = new DirectoryInfo(Path.Combine(workspace, "_baseline"));

Dictionary<string, JsonElement[]> LoadRows(DirectoryInfo d)
{
    var map = new Dictionary<string, JsonElement[]>();
    if (!d.Exists) return map;
    foreach (var f in d.GetFiles("*.json"))
    {
        if (f.Name == "baseline.json" || f.Name == "meta.json" || f.Name == "state.json") continue;
        var root = JsonDocument.Parse(File.ReadAllText(f.FullName)).RootElement;
        if (!root.TryGetProperty("rows", out var rows)) continue;   // 非 probe 输出，跳过
        map[Path.GetFileNameWithoutExtension(f.Name)] = rows.EnumerateArray().ToArray();
    }
    return map;
}

var cur = LoadRows(wsDir);
var old = LoadRows(baseDir);
var meta = JsonDocument.Parse(File.ReadAllText(Path.Combine(workspace, "meta.json"))).RootElement;

var asm = Assembly.GetAssembly(typeof(ItemInfo));
var types = asm.GetTypes().Where(t => typeof(DBObject).IsAssignableFrom(t) && !t.IsAbstract)
                            .ToDictionary(t => t.Name, t => t);

bool ReflistDerived(string table, string field)
{
    if (!meta.TryGetProperty(table, out var tm) || !tm.TryGetProperty("fields", out var fs))
        return false;
    if (!fs.TryGetProperty(field, out var fm) || !fm.TryGetProperty("to", out var to))
        return false;
    string child = to.GetString();
    if (!meta.TryGetProperty(child, out var cm) || !cm.TryGetProperty("fields", out var cfs))
        return false;
    foreach (var p in cfs.EnumerateObject())
        if (p.Value.ValueKind == JsonValueKind.Object
            && p.Value.TryGetProperty("type", out var t) && t.GetString() == "ref"
            && p.Value.TryGetProperty("to", out var tt) && tt.GetString() == table)
            return true;
    return false;
}

Dictionary<int, JsonElement> RowMap(JsonElement[] rows)
{
    var m = new Dictionary<int, JsonElement>();
    foreach (var r in rows) m[r.GetProperty("Index").GetInt32()] = r;
    return m;
}

// ---------- 3) 变更集 ----------
var changes = new List<(string table, string op, int index, JsonElement row)>();
foreach (var (table, rows) in cur)
{
    var oldMap = old.TryGetValue(table, out var o) ? RowMap(o) : new Dictionary<int, JsonElement>();
    var newMap = RowMap(rows);
    foreach (var idx in newMap.Keys)
        if (!oldMap.ContainsKey(idx)) changes.Add((table, "add", idx, newMap[idx]));
        else if (!JsonElement.DeepEquals(oldMap[idx], newMap[idx]))
            changes.Add((table, "mod", idx, newMap[idx]));
    foreach (var idx in oldMap.Keys.Where(k => !newMap.ContainsKey(k)))
        changes.Add((table, "del", idx, default));
}
if (changes.Count == 0)
{
    Log("[=] 无改动。");
    Log("NO_CHANGES=1");
    if (reportPath != null) File.WriteAllText(reportPath, log.ToString());
    return 0;
}
Log($"[*] 变更 {changes.Count} 处：{string.Join(", ", changes.GroupBy(c => c.table).Select(g => $"{g.Key}×{g.Count()}"))}");

// ---------- 4) 悬空引用预校验（按应用后的最终状态） ----------
var errors = new List<string>();
foreach (var (table, rows) in cur)
{
    if (!types.ContainsKey(table)) { errors.Add($"未知表 {table}"); continue; }
    var fields = meta.GetProperty(table).GetProperty("fields");
    foreach (var row in rows)
    {
        foreach (var p in row.EnumerateObject())
        {
            if (!fields.TryGetProperty(p.Name, out var fm)) continue;
            var ft = fm.TryGetProperty("type", out var t) ? t.GetString() : null;
            string to = fm.TryGetProperty("to", out var tt) ? tt.GetString() : null;
            void CheckRef(JsonElement el)
            {
                if (!el.TryGetProperty("Index", out var ix)) return;
                int target = ix.GetInt32();
                if (to != null && cur.TryGetValue(to, out var tr) && !RowMap(tr).ContainsKey(target))
                    errors.Add($"{table}#{row.GetProperty("Index").GetInt32()}.{p.Name} -> {to}#{target} 不存在");
            }
            if (ft == "ref" && p.Value.ValueKind == JsonValueKind.Object) CheckRef(p.Value);
            else if (ft == "reflist" && p.Value.ValueKind == JsonValueKind.Array && to != null
                     && !ReflistDerived(table, p.Name))
                foreach (var el in p.Value.EnumerateArray())
                    if (el.ValueKind == JsonValueKind.Object) CheckRef(el);
        }
    }
}
if (errors.Count > 0)
{
    Log($"[X] 悬空引用 {errors.Count} 处，拒绝写库：");
    foreach (var e in errors.Take(20)) Log("    " + e);
    if (reportPath != null) File.WriteAllText(reportPath, log.ToString());
    return 11;
}
Log("[*] 引用完整性校验通过。");

// ---------- 5) 打开会话（临时副本） ----------
var tmp = Path.Combine(Path.GetTempPath(), "dbeditor_import_" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(tmp);
File.Copy(srcDb, Path.Combine(tmp, "System.db"), true);
var session = new Session(SessionMode.System, tmp + Path.DirectorySeparatorChar);
session.Initialize(asm);

var miObjects = typeof(ADBCollection).GetMethod("GetObjects",
    BindingFlags.NonPublic | BindingFlags.Instance);
var miCreate = typeof(ADBCollection).GetMethod("CreateObject",
    BindingFlags.NonPublic | BindingFlags.Instance);

ADBCollection Col(string table) => session.GetCollection(types[table]);
IEnumerable<DBObject> Objects(ADBCollection c) => (IEnumerable<DBObject>)miObjects.Invoke(c, null);
DBObject NewObj(ADBCollection c) => (DBObject)miCreate.Invoke(c, null);

DBObject ByIndex(ADBCollection c, int idx)
{
    foreach (var o in Objects(c))
        if (o.Index == idx) return o;
    return null;
}

// ---------- 6) 应用变更（先删 → 改 → 增【两阶段：先建后填，Index 重映射】） ----------
var remap = new Dictionary<string, Dictionary<int, int>>();   // 工作区 Index → MirDB 真实 Index
int applied = 0;
foreach (var (table, op, index, _) in changes.Where(c => c.op == "del").OrderBy(c => c.index))
{
    var target = ByIndex(Col(table), index);
    if (target == null) { errors.Add($"删除 {table}#{index}: 目标不存在"); continue; }
    target.Delete();
    applied++; Log($"[-] {table}#{index}");
}
// 修改：跨表前向引用（mod 引用本批 Add 的新行，如 NPCInfo.EntryPage → 新 NPCPage）
// 无法在 mod 阶段满足 → 先试改；若仅因「引用目标缺失」失败则整体延后，Add 后重放。
var modList = changes.Where(c => c.op == "mod").OrderBy(c => c.index).ToList();
var deferred = new List<(string table, int index, JsonElement row)>();
foreach (var (table, op, index, row) in modList)
{
    var target = ByIndex(Col(table), index);
    if (target == null) { errors.Add($"修改 {table}#{index}: 目标不存在"); continue; }
    int errBefore = errors.Count;
    ApplyRow(table, types[table], target, row);
    bool missingRefs = errors.Skip(errBefore).Any(e => e.Contains("引用目标缺失") || e.Contains("元素缺失"));
    if (missingRefs)
    {
        // 撤销本轮已写字段成本高（部分字段已生效）——直接记录，不回滚；
        // Add 后重放会覆盖全部字段，最终态正确。
        deferred.Add((table, index, row));
        // 引用缺失只是「暂时」错误：从 errors 移除，重放失败才最终算错
        errors.RemoveRange(errBefore, errors.Count - errBefore);
        Log($"[~] {table}#{index} → 前向引用，延后到 Add 之后重放");
        continue;
    }
    applied++; Log($"[~] {table}#{index}");
}
// 阶段 A：先创建全部新行（CreateNew 由 MirDB 按表内计数器分配真实 Index——
// 工作区 max+1 可能落后于计数器（历史删除留下的空洞），记录 工作区→真实 映射。
var addList = changes.Where(c => c.op == "add").OrderBy(c => c.index).ToList();
foreach (var g in addList.GroupBy(c => c.table))
{
    var map = new Dictionary<int, int>();
    foreach (var c in g)
    {
        var ob = NewObj(Col(c.table));
        // QuestInfo.OnCreated() 会自动补一条 HaveNotCompleted-self QuestRequirement
        //（引擎防重复接取惯例）。工作区行已显式含该条 → 删掉自动条目防重复入库。
        if (c.table == "QuestInfo")
            foreach (var auto in ((Library.SystemModels.QuestInfo)ob).Requirements.ToList())
                auto.Delete();
        map[c.index] = ob.Index;
    }
    remap[g.Key] = map;
}
// 阶段 B：填充字段；引用目标若是本批新行，按映射改指真实 Index
foreach (var (table, op, index, row) in addList)
{
    var real = remap[table][index];
    var ob = ByIndex(Col(table), real);
    if (ob == null) { errors.Add($"新增 {table}#{index}: 创建后找不到对象"); continue; }
    ApplyRow(table, types[table], ob, row);
    applied++;
    Log(real == index
        ? $"[+] {table}#{index}（Index 自洽）"
        : $"[+] {table}#{index} → 重映射 #{real}");
}
// 重放修改：引用了本批新行的 mod（如 NPCInfo.EntryPage → 新 NPCPage）
if (deferred.Count > 0)
{
    foreach (var (table, index, row) in deferred)
    {
        var target = ByIndex(Col(table), index);
        if (target == null) { errors.Add($"修改 {table}#{index}: 目标不存在"); continue; }
        ApplyRow(table, types[table], target, row);
        applied++; Log($"[~] {table}#{index}（前向引用重放）");
    }
}
// 输出重映射表（供 sync.sh 的 round-trip 对比换算工作区 Index）
foreach (var (t, m) in remap)
{
    var moved = m.Where(kv => kv.Key != kv.Value).ToList();
    if (moved.Count > 0)
        Log("REMAP=" + t + ":" + string.Join(",", moved.Select(kv => $"{kv.Key}={kv.Value}")));
}
if (errors.Count > 0)
{
    Log($"[X] 应用失败 {errors.Count} 处，放弃保存：");
    foreach (var e in errors.Take(20)) Log("    " + e);
    if (reportPath != null) File.WriteAllText(reportPath, log.ToString());
    return 12;
}

// ---------- 7) 保存 ----------
session.Save(true);
Log($"[*] 新版本: {session.SystemDatabaseVersion}");
Log($"[*] 已保存: {Path.Combine(tmp, "System.db")}");
Log($"[*] 应用 {applied}/{changes.Count} 处变更。");
Log("DB_OUT=" + Path.Combine(tmp, "System.db"));
if (reportPath != null) File.WriteAllText(reportPath, log.ToString());
return 0;

// ---------- 字段写入 ----------
void ApplyRow(string table, Type type, DBObject ob, JsonElement row)
{
    var fields = meta.GetProperty(table).GetProperty("fields");

    void Set(PropertyInfo pr, FieldInfo fi, DBObject o, object v)
    {
        if (pr != null && pr.CanWrite) pr.SetValue(o, v);
        else if (fi != null) fi.SetValue(o, v);
        else throw new InvalidOperationException("成员不可写");
    }

    foreach (var p in row.EnumerateObject())
    {
        if (p.Name == "Index" || p.Name == "_Identity") continue;
        if (!fields.TryGetProperty(p.Name, out var fm))
        { errors.Add($"{table}#{ob.Index}: 字段 {p.Name} 不在 schema"); continue; }
        var ft = fm.TryGetProperty("type", out var t) ? t.GetString() : null;
        string to = fm.TryGetProperty("to", out var tt) ? tt.GetString() : null;

        var prop = type.GetProperty(p.Name);
        var field = type.GetField(p.Name);
        if (prop == null && field == null)
        { errors.Add($"{table}#{ob.Index}.{p.Name}: 反射找不到成员"); continue; }
        Type memberType = prop?.PropertyType ?? field.FieldType;

        try
        {
            switch (ft)
            {
                case "int":
                    Set(prop, field, ob, Convert.ChangeType(p.Value.GetInt32(), memberType)); break;
                case "bool":
                    Set(prop, field, ob, p.Value.GetBoolean()); break;
                case "float":
                case "number":
                    Set(prop, field, ob, Convert.ChangeType(p.Value.GetDouble(), memberType)); break;
                case "ref":
                {
                    if (p.Value.ValueKind == JsonValueKind.Null) { Set(prop, field, ob, null); break; }
                    int refIdx = p.Value.GetProperty("Index").GetInt32();
                    if (remap.TryGetValue(to ?? "", out var m) && m.TryGetValue(refIdx, out var realIdx))
                        refIdx = realIdx;
                    var target = ByIndex(Col(to), refIdx);
                    if (target == null) { errors.Add($"{table}#{ob.Index}.{p.Name}: 引用目标缺失"); break; }
                    Set(prop, field, ob, target);
                    break;
                }
                case "enum":
                    Set(prop, field, ob, Enum.Parse(memberType, p.Value.GetString())); break;
                case "stats":
                {
                    var stats = (Stats)(prop != null ? prop.GetValue(ob) : field.GetValue(ob));
                    if (stats == null) { stats = new Stats(); Set(prop, field, ob, stats); }
                    stats.Values.Clear();
                    foreach (var it in p.Value.EnumerateArray())
                        stats[(Stat)Enum.Parse(typeof(Stat), it.GetProperty("Stat").GetString())]
                            = it.GetProperty("Value").GetInt32();
                    break;
                }
                case "reflist":
                {
                    if (ReflistDerived(table, p.Name))
                        break;    // Association 回链：由子行 ref setter 自动维护
                    var list = (System.Collections.IList)(prop != null ? prop.GetValue(ob) : field.GetValue(ob));
                    list.Clear();
                    foreach (var el in p.Value.EnumerateArray())
                    {
                        int elIdx = el.GetProperty("Index").GetInt32();
                        if (remap.TryGetValue(to ?? "", out var m) && m.TryGetValue(elIdx, out var realIdx))
                            elIdx = realIdx;
                        var target = ByIndex(Col(to), elIdx);
                        if (target == null) { errors.Add($"{table}#{ob.Index}.{p.Name}[]: 元素缺失"); break; }
                        list.Add(target);
                    }
                    break;
                }
                case "string":
                    Set(prop, field, ob, p.Value.ValueKind == JsonValueKind.Null ? null : p.Value.GetString()); break;
                default:
                    errors.Add($"{table}#{ob.Index}.{p.Name}: 类型 {ft} 暂不支持写入（改动被拒绝）");
                    break;
            }
        }
        catch (Exception ex)
        {
            errors.Add($"{table}#{ob.Index}.{p.Name}: {ex.Message}");
        }
    }
}
