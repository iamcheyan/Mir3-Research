// DBImporter — dbeditor JSON 工作区 → System.db 写回器。
//
// 工作流（见 Tools/dbeditor/README.md）：
//   编辑器保存只落 JSON 工作区（Tools/dbeditor/workspace/）；
//   用户显式点「同步到数据库」后由本程序执行：
//     1. 端口检测（7000 有监听 = 服务端在跑 → 拒绝，退出码 2）
//     2. 载入 System.db（SessionMode.System，绝不碰 Users.db）
//     3. 阶段A校验：工作区 JSON 解析 + enum/数值范围/图像帧范围
//     4. 应用差异（删除/新增/修改，只动受管表的差异字段）
//     5. 阶段B校验：引用完整性（含悬空引用与被删记录的反向引用）
//     6. 备份双库（时间戳目录）→ session.Save(true)（自动 bump 版本）
//     7. 服务端库复制到客户端 Data/System.db
//     8. round-trip：重新打开库逐字段读回验证
//
// 用法:
//   DBImporter --mode info                              # 打印库版本/md5/行数(JSON)
//   DBImporter --mode enums  --out enums.json           # 导出枚举字典(前端下拉用)
//   DBImporter --mode check  --workspace <dir>          # 只校验，写 sync_report.txt
//   DBImporter --mode sync   --workspace <dir>          # 全量同步
// 可选: --root <服务端Database目录>  --client <客户端System.db路径>
//
// 退出码: 0=成功  1=校验失败  2=服务端在跑  3=其他错误
using System.Collections;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Text.Json;
using Library.MirDB;
using Library.SystemModels;
using MirDB;

string mode = "info";
string workspace = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "dbeditor", "workspace"));
string root = "/home/tetsuya/development/zircon/Debug/ServerCore/Database/";
string clientPath = "/home/tetsuya/development/zircon/Debug/Client/Data/System.db";
string outPath = null;

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--mode": mode = args[++i]; break;
        case "--workspace": workspace = Path.GetFullPath(args[++i]); break;
        case "--root": root = args[++i]; break;
        case "--client": clientPath = args[++i]; break;
        case "--out": outPath = args[++i]; break;
        default: Console.WriteLine($"未知参数: {args[i]}"); return 3;
    }
}
if (!root.EndsWith(Path.DirectorySeparatorChar)) root += Path.DirectorySeparatorChar;

var report = new StringBuilder();
DateTime now = DateTime.Now;
void Log(string line) { Console.WriteLine(line); report.AppendLine($"[{now:yyyy-MM-dd HH:mm:ss}] {line}"); }

// ---------- 模式: enums（枚举字典导出，前端下拉/校验用） ----------
if (mode == "enums")
{
    var dict = new SortedDictionary<string, Dictionary<string, int>>(StringComparer.Ordinal);
    foreach (Type t in typeof(ItemInfo).Assembly.GetTypes().Where(t => t.IsEnum).OrderBy(t => t.FullName))
    {
        var members = new Dictionary<string, int>();
        foreach (object v in Enum.GetValues(t)) members[v.ToString()] = Convert.ToInt32(v);
        dict[t.FullName ?? t.Name] = members;
    }
    File.WriteAllText(outPath ?? "enums.json", JsonSerializer.Serialize(dict, new JsonSerializerOptions { WriteIndented = true }));
    Console.WriteLine($"枚举字典 -> {outPath ?? "enums.json"} ({dict.Count} 个枚举)");
    return 0;
}

// ---------- 模式: info（库版本/指纹） ----------
if (mode == "info")
{
    var session = new Session(SessionMode.System, root) { BackUp = false };
    session.Initialize(typeof(ItemInfo).Assembly);

    var counts = new SortedDictionary<string, int>();
    foreach (var (type, coll) in AllCollections(session))
    {
        var list = (IList)coll.GetType().GetField("Binding")!.GetValue(coll)!;
        if (list.Count > 0) counts[type.Name] = list.Count;
    }

    string Md5(string p) => File.Exists(p)
        ? Convert.ToHexString(System.Security.Cryptography.MD5.HashData(File.ReadAllBytes(p))).ToLowerInvariant()
        : null;

    Console.WriteLine(JsonSerializer.Serialize(new
    {
        version = session.SystemDatabaseVersion,
        server_md5 = Md5(session.SystemPath),
        client_md5 = Md5(clientPath),
        counts,
    }, new JsonSerializerOptions { WriteIndented = true }));
    return 0;
}

if (mode != "check" && mode != "sync")
{
    Console.WriteLine($"未知模式: {mode}"); return 3;
}

// ---------- 同步前置: 端口检测（仅 sync；check 是只读校验，服务端运行时也允许） ----------
// 只对真实服务端库生效；/tmp 测试副本不受此限（写副本无风险，否则无法在服务端运行期间测试 importer）。
string realRoot = Path.GetFullPath("/home/tetsuya/development/zircon/Debug/ServerCore/Database/");
bool isRealRoot = string.Equals(Path.GetFullPath(root), realRoot, StringComparison.OrdinalIgnoreCase);
if (mode == "sync" && isRealRoot && PortListening(7000))
{
    string msg = "拒绝执行: 7000 端口有监听（服务端正在运行）。请先停止服务端再同步。";
    Console.WriteLine(msg);
    File.WriteAllText(Path.Combine(workspace, "sync_report.txt"), $"[{now:yyyy-MM-dd HH:mm:ss}] {msg}\n");
    return 2;
}

// ---------- 配置 ----------
var cfg = LoadConfig(workspace);

// ---------- 载入库 ----------
var errs = new List<string>();
var sessionMain = new Session(SessionMode.System, root) { BackUp = false };
sessionMain.Initialize(typeof(ItemInfo).Assembly);
string oldVersion = sessionMain.SystemDatabaseVersion;
Log($"库版本(同步前): {oldVersion ?? "(空)"}");
Log($"服务端库: {sessionMain.SystemPath}");
Log($"客户端库: {clientPath}");

var meta = JsonSerializer.Deserialize<Dictionary<string, MetaColl>>(
    File.ReadAllText(Path.Combine(workspace, "meta.json")),
    new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

Type TypeOf(string name) => sessionMain.Assemblies.SelectMany(a => a.GetTypes()).FirstOrDefault(t => t.Name == name);

// 活动对象索引: Type -> (Index -> DBObject)，随应用过程保持最新
var live = new Dictionary<Type, SortedDictionary<int, DBObject>>();
foreach (var (type, coll) in AllCollections(sessionMain))
{
    var rows = new SortedDictionary<int, DBObject>();
    var list = (IList)coll.GetType().GetField("Binding")!.GetValue(coll)!;
    foreach (DBObject ob in list) rows[ob.Index] = ob;
    live[type] = rows;
}

// ---------- 读工作区（受管表） ----------
var ws = new Dictionary<string, Dictionary<int, JsonElement>>(); // table -> Index -> row
foreach (string table in cfg.Managed)
{
    string file = Path.Combine(workspace, table + ".json");
    if (!File.Exists(file)) { errs.Add($"工作区缺少 {table}.json"); continue; }
    var rows = new Dictionary<int, JsonElement>();
    foreach (JsonElement r in JsonSerializer.Deserialize<JsonElement>(File.ReadAllText(file)).GetProperty("rows").EnumerateArray())
    {
        int idx = r.GetProperty("Index").GetInt32();
        if (rows.ContainsKey(idx)) errs.Add($"{table}: 工作区存在重复 Index {idx}");
        rows[idx] = r;
    }
    ws[table] = rows;
}
// 基线行（首次导出的原始工作区）: 区分「用户引入的脏数据」与「库中原有的历史脏数据」
// 优先 _baseline/（dbeditor app.py ensure_baseline 生成），兼容 baseline/
var baselineDir = Directory.Exists(Path.Combine(workspace, "_baseline"))
    ? Path.Combine(workspace, "_baseline")
    : Path.Combine(workspace, "baseline");
var baselineRows = new Dictionary<string, Dictionary<int, JsonElement>>();
foreach (string table in cfg.Managed)
{
    string file = Path.Combine(baselineDir, table + ".json");
    var rows = new Dictionary<int, JsonElement>();
    if (File.Exists(file))
        foreach (JsonElement r in JsonSerializer.Deserialize<JsonElement>(File.ReadAllText(file)).GetProperty("rows").EnumerateArray())
            rows[r.GetProperty("Index").GetInt32()] = r;
    baselineRows[table] = rows;
}
// 必填引用为空是否为「原有状态」: 基线里该行该字段同样为空 => 历史遗留, 放行
bool NullRefPreexisting(string table, int idx, string fname)
{
    return baselineRows.TryGetValue(table, out var br) &&
           br.TryGetValue(idx, out var brow) &&
           (!brow.TryGetProperty(fname, out JsonElement bel) || bel.ValueKind == JsonValueKind.Null);
}

// ---------- 阶段A: 静态校验（解析层 + 范围规则） ----------
foreach (string table in cfg.Managed)
{
    var fields = meta[table].Fields;
    foreach (var (idx, row) in ws[table])
    {
        foreach (var (fname, fm) in fields)
        {
            if (!row.TryGetProperty(fname, out JsonElement el)) continue;
            switch (fm.Type)
            {
                case "enum":
                    if (el.ValueKind == JsonValueKind.String)
                    {
                        Type et = FindEnum(fm.To ?? fname);
                        if (et == null || !Enum.IsDefined(et, el.GetString()!))
                            errs.Add($"{table}#{idx}.{fname}: 非法枚举值 \"{el.GetString()}\"");
                    }
                    else errs.Add($"{table}#{idx}.{fname}: 枚举字段应为字符串");
                    break;
                case "int":
                    if (el.ValueKind != JsonValueKind.Number || !el.TryGetInt64(out long _))
                        errs.Add($"{table}#{idx}.{fname}: 应为整数，实际 {el}");
                    break;
                case "number":
                    if (el.ValueKind != JsonValueKind.Number)
                        errs.Add($"{table}#{idx}.{fname}: 应为数字，实际 {el}");
                    break;
                case "bool":
                    if (el.ValueKind != JsonValueKind.True && el.ValueKind != JsonValueKind.False)
                        errs.Add($"{table}#{idx}.{fname}: 应为布尔，实际 {el}");
                    break;
                case "string":
                    if (el.ValueKind != JsonValueKind.String)
                        errs.Add($"{table}#{idx}.{fname}: 应为字符串，实际 {el}");
                    break;
                case "ref":
                    if (el.ValueKind == JsonValueKind.Object)
                    {
                        if (!el.TryGetProperty("Index", out JsonElement ri) || ri.ValueKind != JsonValueKind.Number)
                            errs.Add($"{table}#{idx}.{fname}: 引用缺少 Index");
                        else if (ri.GetInt32() < 0)
                            errs.Add($"{table}#{idx}.{fname}: 引用 Index 不能为负 ({ri})");
                    }
                    else if (el.ValueKind != JsonValueKind.Null)
                        errs.Add($"{table}#{idx}.{fname}: 引用格式错误");
                    break;
            }
        }
        // 数值范围 / 图像帧范围 / 必填引用
        foreach (var (rule, op) in cfg.Numeric)
        {
            if (!rule.StartsWith(table + ".")) continue;
            string fname = rule[(table.Length + 1)..];
            if (!row.TryGetProperty(fname, out JsonElement el) || el.ValueKind != JsonValueKind.Number) continue;
            decimal v = el.GetDecimal();
            bool ok = op switch
            {
                ">=0" => v >= 0,
                ">0" => v > 0,
                "0..1" => v >= 0 && v <= 1,
                _ => true,
            };
            if (!ok) errs.Add($"{table}#{idx}.{fname}: 数值 {v} 违反约束 {op}");
        }
        foreach (var (field, range) in cfg.ImageRanges)
        {
            if (!field.StartsWith(table + ".")) continue;
            string fname = field[(table.Length + 1)..];
            if (!row.TryGetProperty(fname, out JsonElement el) || el.ValueKind != JsonValueKind.Number) continue;
            int v = el.GetInt32();
            if (v < range[0] || v > range[1])
                errs.Add($"{table}#{idx}.{fname}: 图像帧 {v} 超出范围 [{range[0]}, {range[1]}]");
        }
        foreach (string rr in cfg.RequiredRefs)
        {
            if (!rr.StartsWith(table + ".")) continue;
            string fname = rr[(table.Length + 1)..];
            bool isNull = !row.TryGetProperty(fname, out JsonElement el) || el.ValueKind == JsonValueKind.Null ||
                          (el.ValueKind == JsonValueKind.Object && (!el.TryGetProperty("Index", out var ix) || ix.GetInt32() <= 0));
            if (isNull && !NullRefPreexisting(table, idx, fname))
                errs.Add($"{table}#{idx}.{fname}: 必填引用为空（基线中该字段有值，疑被清空）");
        }
    }
}

if (errs.Count > 0)
{
    Log($"阶段A校验失败: {errs.Count} 处错误，未写库。");
    foreach (string e in errs) Log("  ✗ " + e);
    WriteReport(workspace, report);
    return 1;
}
Log("阶段A校验通过（解析/枚举/范围/帧号）。");

// ---------- 应用差异（内存中） ----------
int nDel = 0, nAdd = 0, nUpd = 0;
var detail = new List<string>();

foreach (string table in cfg.Managed)
{
    Type type = TypeOf(table);
    var settable = SettableFields(meta, table);

    var dbRows = live[type];
    var rows = ws[table];

    // 删除
    foreach (var (idx, ob) in dbRows.ToList())
        if (!rows.ContainsKey(idx))
        {
            ob.Delete();
            dbRows.Remove(idx);
            nDel++; detail.Add($"删除 {table}#{idx}");
        }

    var added = new HashSet<int>();
    // 新增
    foreach (var (idx, row) in rows)
        if (!dbRows.ContainsKey(idx))
        {
            DBObject ob = CreateObject(sessionMain, type);
            if (ob.Index != idx)
            {
                if (dbRows.ContainsKey(idx)) { errs.Add($"{table}: 新记录 Index {idx} 与现存记录冲突"); continue; }
                typeof(DBObject).GetProperty("Index")!.GetSetMethod(true)!.Invoke(ob, new object[] { idx });
            }
            added.Add(idx);
            ApplyFields(ob, row, settable, live, errs);
            nAdd++; detail.Add($"新增 {table}#{idx}");
        }

    // 修改（只应用差异字段）
    foreach (var (idx, row) in rows)
    {
        if (added.Contains(idx)) continue;
        if (!dbRows.TryGetValue(idx, out DBObject ob)) continue;
        var changed = DiffFields(ob, row, settable);
        if (changed.Count > 0)
        {
            ApplyFields(ob, row, settable, live, errs, only: new HashSet<string>(changed));
            nUpd++; detail.Add($"修改 {table}#{idx}: {string.Join(", ", changed)}");
        }
    }
}

if (errs.Count > 0)
{
    Log($"应用差异时出错: {errs.Count} 处，未写库。");
    foreach (string e in errs) Log("  ✗ " + e);
    WriteReport(workspace, report);
    return 1;
}
Log($"差异应用: 新增 {nAdd} / 修改 {nUpd} / 删除 {nDel}");
if (mode == "check")
{
    foreach (string d in detail.Take(200)) Log("  · " + d);
    if (detail.Count > 200) Log($"  … 共 {detail.Count} 条");
}

// ---------- 阶段B: 引用完整性（对应用后的活动状态校验） ----------
foreach (string table in cfg.Managed)
{
    Type type = TypeOf(table);
    foreach (var (idx, ob) in live[type])
    {
        foreach (var (fname, fm) in meta[table].Fields.Where(kv => kv.Value.Type == "ref"))
        {
            Type toType = TypeOf(fm.To);
            if (toType == null) continue;
            PropertyInfo p = type.GetProperty(fname);
            if (p == null) continue;
            DBObject target = (DBObject)p.GetValue(ob);
            if (target == null)
            {
                if (cfg.RequiredRefs.Contains($"{table}.{fname}") && !NullRefPreexisting(table, idx, fname))
                    errs.Add($"{table}#{idx}.{fname}: 必填引用为空");
                continue;
            }
            if (!live.TryGetValue(toType, out var targetRows) || !targetRows.ContainsKey(target.Index))
                errs.Add($"{table}#{idx}.{fname}: 悬空引用 -> {fm.To}#{target.Index}");
        }
    }
}

// 反向引用: 被删除的受管记录仍被其他表引用（含未受管表如 QuestReward/NPCGood）
var managedByType = cfg.Managed.Select(TypeOf).Where(t => t != null).ToHashSet();
foreach (var (type, coll) in AllCollections(sessionMain))
{
    if (!meta.TryGetValue(type.Name, out var mc)) continue;
    var refFields = mc.Fields.Where(kv => kv.Value.Type == "ref" && managedByType.Any(m => m.Name == kv.Value.To)).ToList();
    if (refFields.Count == 0) continue;

    var list = (IList)coll.GetType().GetField("Binding")!.GetValue(coll)!;
    foreach (DBObject ob in list)
    {
        foreach (var (fname, fm) in refFields)
        {
            PropertyInfo p = type.GetProperty(fname);
            if (p == null) continue;
            if (p.GetValue(ob) is not DBObject target) continue;
            Type toType = managedByType.First(m => m.Name == fm.To);
            if (!live.TryGetValue(toType, out var targetRows) || !targetRows.ContainsKey(target.Index))
                errs.Add($"反向引用悬空: {type.Name}#{ob.Index}.{fname} -> {fm.To}#{target.Index} (目标记录不存在)");
        }
    }
}

if (errs.Count > 0)
{
    Log($"阶段B引用校验失败: {errs.Count} 处错误，未写库。");
    foreach (string e in errs) Log("  ✗ " + e);
    WriteReport(workspace, report);
    return 1;
}
Log("阶段B引用完整性校验通过。");

if (mode == "check")
{
    Log($"CHECK OK: 工作区可安全同步（新增 {nAdd} / 修改 {nUpd} / 删除 {nDel}）。");
    WriteReport(workspace, report);
    return 0;
}

// ---------- 备份双库 ----------
string ts = now.ToString("yyyyMMdd-HHmmss");
string serverBackupDir = Path.Combine(root, "Backup", $"dbeditor-{ts}");
Directory.CreateDirectory(serverBackupDir);
string serverBackup = Path.Combine(serverBackupDir, "System.db");
File.Copy(sessionMain.SystemPath, serverBackup, true);
Log($"服务端库备份 -> {serverBackup}");

string clientBackup = null;
if (File.Exists(clientPath))
{
    string clientBackupDir = Path.Combine(Path.GetDirectoryName(clientPath)!, "Backup", $"dbeditor-{ts}");
    Directory.CreateDirectory(clientBackupDir);
    clientBackup = Path.Combine(clientBackupDir, "System.db");
    File.Copy(clientPath, clientBackup, true);
    Log($"客户端库备份 -> {clientBackup}");
}

// ---------- 写库（Session 自带 gzip 备份 + 版本自动 bump） ----------
sessionMain.BackUp = true;
sessionMain.Save(true);  // 系统数据有变更时自动 BumpSystemVersion（YYYY.MM.DD.N 递增）
string newVersion = sessionMain.SystemDatabaseVersion;
Log($"已写服务端库，版本 {oldVersion} -> {newVersion}");

// ---------- 双库: 复制到客户端 ----------
File.Copy(sessionMain.SystemPath, clientPath, true);
Log($"客户端库已更新 <- {sessionMain.SystemPath}");

// ---------- round-trip: 重新打开库逐字段验证 ----------
var sessionRt = new Session(SessionMode.System, root) { BackUp = false };
sessionRt.Initialize(typeof(ItemInfo).Assembly);
var liveRt = new Dictionary<Type, SortedDictionary<int, DBObject>>();
foreach (var (type, coll) in AllCollections(sessionRt))
{
    var l = new SortedDictionary<int, DBObject>();
    var list = (IList)coll.GetType().GetField("Binding")!.GetValue(coll)!;
    foreach (DBObject ob in list) l[ob.Index] = ob;
    liveRt[type] = l;
}

int rtFail = 0, rtChecked = 0;
var rtErrs = new List<string>();
foreach (string table in cfg.Managed)
{
    Type type = sessionRt.Assemblies.SelectMany(a => a.GetTypes()).First(t => t.Name == table);
    var settable = SettableFields(meta, table);
    var dbRows = liveRt[type];

    foreach (var (idx, row) in ws[table])
    {
        if (!dbRows.TryGetValue(idx, out DBObject ob))
        { rtErrs.Add($"round-trip: {table}#{idx} 读取回不存在"); rtFail++; continue; }
        var diff = DiffFields(ob, row, settable);
        rtChecked++;
        if (diff.Count > 0)
        {
            rtFail++;
            rtErrs.Add($"round-trip: {table}#{idx} 字段未生效: {string.Join(", ", diff)}");
        }
    }
    foreach (var idx in dbRows.Keys)
        if (!ws[table].ContainsKey(idx))
        { rtErrs.Add($"round-trip: {table}#{idx} 应删除但仍存在"); rtFail++; }
}

if (rtFail > 0)
{
    Log($"ROUND-TRIP FAIL: {rtFail}/{rtChecked} 条未验证通过（库已写入，可用备份恢复: {serverBackup}）");
    foreach (string e in rtErrs.Take(50)) Log("  ✗ " + e);
    WriteReport(workspace, report);
    return 1;
}
Log($"ROUND-TRIP OK: {rtChecked} 条记录逐字段读回验证通过（{cfg.Managed.Count} 张受管表）。");

report.AppendLine();
report.AppendLine("---- 变更明细 ----");
foreach (string d in detail) report.AppendLine("  " + d);
report.AppendLine($"---- 备份 ----\n  服务端: {serverBackup}\n  客户端: {clientBackup}");
report.AppendLine($"round-trip: 通过 ({rtChecked} 条)");
WriteReport(workspace, report);

Console.WriteLine($"\n同步完成: 新增 {nAdd} / 修改 {nUpd} / 删除 {nDel}，版本 {oldVersion} -> {newVersion}");
Console.WriteLine("请重启服务端使改动生效。");
return 0;

// ===================== 辅助 =====================

static Dictionary<string, MetaField> SettableFields(Dictionary<string, MetaColl> meta, string table) =>
    meta[table].Fields.Where(kv => kv.Value.Type is "string" or "bool" or "int" or "number" or "datetime" or "enum" or "ref")
                       .ToDictionary(kv => kv.Key, kv => kv.Value);

static IEnumerable<(Type type, ADBCollection coll)> AllCollections(Session session)
{
    var field = typeof(Session).GetField("Collections", BindingFlags.NonPublic | BindingFlags.Instance)!;
    var dict = (IDictionary)field.GetValue(session)!;
    foreach (DictionaryEntry e in dict) yield return ((Type)e.Key, (ADBCollection)e.Value);
}

static DBObject CreateObject(Session session, Type type)
{
    // DBCollection<T>.CreateNewObject() 公开: 追加到末尾, Index = ++Index
    ADBCollection coll = session.GetCollection(type);
    return (DBObject)coll.GetType().GetMethod("CreateNewObject")!.Invoke(coll, null)!;
}

static Type FindEnum(string name)
{
    foreach (Type t in typeof(ItemInfo).Assembly.GetTypes())
        if (t.IsEnum && (t.Name == name || t.FullName == name)) return t;
    return null;
}

// 把 JSON 值规范成与 DB 属性可比的形式; 返回 null 表示 null/缺失
static object CanonicalJson(JsonElement el)
{
    return el.ValueKind switch
    {
        JsonValueKind.Number => el.TryGetInt64(out long l) ? l : el.GetDecimal(),
        JsonValueKind.String => el.GetString()!,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Null => null,
        JsonValueKind.Object when el.TryGetProperty("Index", out var ix) => ix.GetInt32(),
        _ => null!,
    };
}

static object CanonicalDb(PropertyInfo p, DBObject ob)
{
    object v = p.GetValue(ob);
    if (v == null) return null;
    if (v is DBObject dbo) return (long)dbo.Index;
    if (v is DateTime dt) return dt.ToString("yyyy-MM-dd HH:mm:ss");
    if (v is bool b) return b;
    if (v is decimal d) return d;
    if (v is double dd) return (decimal)dd;
    if (v is float ff) return (decimal)ff;
    if (v is int or long or short or byte or sbyte or ushort or uint or ulong) return (long)Convert.ToInt64(v);
    if (v is string s) return s;
    if (p.PropertyType.IsEnum) return v.ToString()!;
    return null!;
}

static List<string> DiffFields(DBObject ob, JsonElement row, Dictionary<string, MetaField> settable)
{
    var changed = new List<string>();
    foreach (var (fname, fm) in settable)
    {
        PropertyInfo p = ob.GetType().GetProperty(fname);
        if (p == null || !p.CanWrite) continue;

        object dbVal = CanonicalDb(p, ob);
        object jsonVal = row.TryGetProperty(fname, out JsonElement el) && el.ValueKind != JsonValueKind.Null
            ? CanonicalJson(el) : null;

        bool eq;
        if (dbVal is long || dbVal is decimal || jsonVal is long || jsonVal is decimal)
        {
            decimal d = dbVal == null ? 0m : Convert.ToDecimal(dbVal);
            decimal j = jsonVal == null ? 0m : Convert.ToDecimal(jsonVal);
            eq = d == j;
        }
        else if (dbVal is bool dbb && jsonVal is bool jb) eq = dbb == jb;
        else if (dbVal is string ds) eq = ds == jsonVal?.ToString();
        else eq = (dbVal == null && jsonVal == null) || Equals(dbVal, jsonVal);
        if (!eq) changed.Add(fname);
    }
    return changed;
}

static void ApplyFields(DBObject ob, JsonElement row, Dictionary<string, MetaField> settable,
    Dictionary<Type, SortedDictionary<int, DBObject>> live, List<string> errs, HashSet<string> only = null)
{
    foreach (var (fname, fm) in settable)
    {
        if (only != null && !only.Contains(fname)) continue;
        PropertyInfo p = ob.GetType().GetProperty(fname);
        if (p == null || !p.CanWrite) continue;
        if (!row.TryGetProperty(fname, out JsonElement el) || el.ValueKind == JsonValueKind.Null)
        {
            if (fm.Type == "ref" && p.GetValue(ob) != null) p.SetValue(ob, null);
            continue;
        }
        try
        {
            switch (fm.Type)
            {
                case "ref":
                {
                    int targetIdx = el.GetProperty("Index").GetInt32();
                    Type toType = live.Keys.FirstOrDefault(t => t.Name == fm.To);
                    DBObject target = targetIdx > 0 && toType != null && live[toType].TryGetValue(targetIdx, out var t2) ? t2 : null;
                    if (targetIdx > 0 && target == null)
                        errs.Add($"{ob.GetType().Name}#{ob.Index}.{fname}: 引用 {fm.To}#{targetIdx} 无法解析");
                    p.SetValue(ob, target);
                    break;
                }
                case "enum":
                    p.SetValue(ob, Enum.Parse(FindEnum(fm.To ?? fname)!, el.GetString()!));
                    break;
                case "int": p.SetValue(ob, Convert.ChangeType(el.GetInt64(), p.PropertyType)); break;
                case "number": p.SetValue(ob, Convert.ChangeType(el.GetDecimal(), p.PropertyType)); break;
                case "bool": p.SetValue(ob, el.GetBoolean()); break;
                case "datetime": p.SetValue(ob, DateTime.Parse(el.GetString()!)); break;
                default: p.SetValue(ob, el.GetString()); break;
            }
        }
        catch (Exception ex)
        {
            errs.Add($"{ob.GetType().Name}#{ob.Index}.{fname}: 应用值 {el} 失败 ({ex.Message})");
        }
    }
}

static void WriteReport(string workspace, StringBuilder report)
{
    File.WriteAllText(Path.Combine(workspace, "sync_report.txt"), report.ToString());
}

static bool PortListening(int port)
{
    try
    {
        using var c = new TcpClient();
        var task = c.ConnectAsync("127.0.0.1", port);
        task.Wait(800);
        return c.Connected;
    }
    catch { return false; }
}

static Cfg LoadConfig(string workspace)
{
    string file = Path.Combine(workspace, "editor_config.json");
    if (File.Exists(file))
        return JsonSerializer.Deserialize<Cfg>(File.ReadAllText(file))!;
    return new Cfg();
}

// ===================== 配置/元数据 POCO =====================

class Cfg
{
    public List<string> Managed { get; set; } = new()
    {
        // 父表在前，子表在后（新增记录的引用解析按此顺序）
        "ItemInfo", "SetInfo", "MonsterInfo", "MagicInfo",
        "ItemInfoStat", "SetInfoStat", "MonsterInfoStat",
        "StoreInfo", "RespawnInfo", "GuardInfo", "DropInfo",
    };
    public Dictionary<string, int[]> ImageRanges { get; set; } = new()
    {
        // 基线实测最大帧号 6010（多图集编址，Inventory.Zl 之外还有高级图集），留余量到 6999
        ["ItemInfo.Image"] = new[] { 0, 6999 },
    };
    public Dictionary<string, string> Numeric { get; set; } = new()
    {
        ["ItemInfo.Price"] = ">=0",
        ["ItemInfo.SellRate"] = "0..1",
        ["ItemInfo.StackSize"] = ">=0",
        ["ItemInfo.Weight"] = ">=0",
        ["ItemInfo.Durability"] = ">=0",
        ["ItemInfo.RequiredAmount"] = ">=0",
        ["DropInfo.Chance"] = ">=0",
        ["DropInfo.Amount"] = ">=0",
        ["StoreInfo.Price"] = ">=0",
        ["StoreInfo.HuntGoldPrice"] = ">=0",
        ["RespawnInfo.Count"] = ">=0",
        ["RespawnInfo.Delay"] = ">=0",
        ["MonsterInfo.Level"] = ">=0",
        ["MonsterInfo.Experience"] = ">=0",
        ["MagicInfo.NeedLevel1"] = ">=0",
        ["MagicInfo.NeedLevel2"] = ">=0",
        ["MagicInfo.NeedLevel3"] = ">=0",
    };
    public List<string> RequiredRefs { get; set; } = new()
    {
        "DropInfo.Item", "DropInfo.Monster",
        "ItemInfoStat.Item", "MonsterInfoStat.Monster", "SetInfoStat.Set",
        "StoreInfo.Item", "RespawnInfo.Monster", "RespawnInfo.Region",
        "GuardInfo.Map", "GuardInfo.Monster",
    };
}

class MetaColl
{
    public string Zh { get; set; }
    public List<string> Identity { get; set; }
    public Dictionary<string, MetaField> Fields { get; set; }
}

class MetaField
{
    public string Zh { get; set; }
    public string Type { get; set; }
    public string To { get; set; }
}
