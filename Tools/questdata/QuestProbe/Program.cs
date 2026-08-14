// QuestProbe —— 无头客户端任务接取探针（Mir3-Research 侧工具，只读复用 zircon LibraryCore）。
//
// 目的：端到端验证 quest_apply 落地的任务在真实服务端「可见可接」。
// 流程（全部走真实网络协议，与 GodotClient 同一封包路径）：
//   1. 正常注册账号（合法邮箱）+ 建战士角色 → 断开
//   2. 以 GM 通道重连：C.Login{EMailAddress=角色名, Password=Server.ini MasterPassword}
//      （SEnvir.Login 实证：非法邮箱 + 主密码 → 该角色账号 TempAdmin，IsGM=true）
//   3. @LEVEL 提级 → @MOVE 传送到任务 NPC 旁 → 等待 S.ObjectNPC
//   4. C.NPCCall 打开对话 → C.QuestAccept → 断言 S.QuestChanged 带 QuestIndex
//   5. 证据 JSON 落盘（--out），控制台 [PASS]/[EVIDENCE] 行供归档
//
// 用法：
//   dotnet run --project Tools/questdata/QuestProbe -- \
//     --host 127.0.0.1 --port 7000 --email questprobe@test.com --pass q1234567 \
//     --char QuestProbeW --master <Server.ini 的 MasterPassword> \
//     --npc 155 --quest 63 --map 01 --x 429 --y 263 --level 20 \
//     --out docs/screenshots/quest_accept_evidence.json
using System.Drawing;
using System.Net.Sockets;
using System.Text.Json;
using Library.Network;
using C = Library.Network.ClientPackets;
using G = Library.Network.GeneralPackets;
using S = Library.Network.ServerPackets;

var opt = new Args(args);
var log = (string tag, string msg) => Console.WriteLine($"[{tag}] {msg}");
var evidence = new Dictionary<string, object>
{
    ["started_at"] = DateTime.UtcNow.ToString("o"),
    ["account"] = opt.Email,
    ["character"] = opt.Char,
    ["target_quest_index"] = opt.Quest,
    ["target_npc_index"] = opt.Npc,
};
// ---- 客户端参照库加载（Packet.CompleteObject 反查需要；BotRunner BotDatabaseLoader 同款）----
var dbRoot = opt.DbRoot;
{
    var root = Path.GetFullPath(dbRoot);
    if (!root.EndsWith(Path.DirectorySeparatorChar)) root += Path.DirectorySeparatorChar;
    var session = new MirDB.Session(MirDB.SessionMode.Users, root) { BackUp = false };
    session.Initialize(System.Reflection.Assembly.GetAssembly(typeof(Library.SystemModels.ItemInfo)));
    if (!session.SystemDatabaseExists)
    {
        Console.WriteLine($"[FAIL] System.db 不在 {root}（--dbroot 指定客户端 Data 目录）");
        return 1;
    }
    Library.Globals.ItemInfoList = session.GetCollection<Library.SystemModels.ItemInfo>();
    Library.Globals.MagicInfoList = session.GetCollection<Library.SystemModels.MagicInfo>();
    Library.Globals.MapInfoList = session.GetCollection<Library.SystemModels.MapInfo>();
    Library.Globals.CurrencyInfoList = session.GetCollection<Library.SystemModels.CurrencyInfo>();
    Library.Globals.InstanceInfoList = session.GetCollection<Library.SystemModels.InstanceInfo>();
    Library.Globals.NPCPageList = session.GetCollection<Library.SystemModels.NPCPage>();
    Library.Globals.MonsterInfoList = session.GetCollection<Library.SystemModels.MonsterInfo>();
    Library.Globals.StoreInfoList = session.GetCollection<Library.SystemModels.StoreInfo>();
    Library.Globals.NPCInfoList = session.GetCollection<Library.SystemModels.NPCInfo>();
    Library.Globals.MovementInfoList = session.GetCollection<Library.SystemModels.MovementInfo>();
    Library.Globals.QuestInfoList = session.GetCollection<Library.SystemModels.QuestInfo>();
    Library.Globals.QuestTaskList = session.GetCollection<Library.SystemModels.QuestTask>();
    Library.Globals.CompanionInfoList = session.GetCollection<Library.SystemModels.CompanionInfo>();
    Library.Globals.CompanionLevelInfoList = session.GetCollection<Library.SystemModels.CompanionLevelInfo>();
    Library.Globals.DisciplineInfoList = session.GetCollection<Library.SystemModels.DisciplineInfo>();
    Library.Globals.FameInfoList = session.GetCollection<Library.SystemModels.FameInfo>();
    Library.Globals.BundleInfoList = session.GetCollection<Library.SystemModels.BundleInfo>();
    Library.Globals.LootBoxInfoList = session.GetCollection<Library.SystemModels.LootBoxInfo>();
    Library.Globals.HelpInfoList = session.GetCollection<Library.SystemModels.HelpInfo>();
    Library.Globals.MilestoneInfoList = session.GetCollection<Library.SystemModels.MilestoneInfo>();
    Library.Globals.MilestoneTaskInfoList = session.GetCollection<Library.SystemModels.MilestoneInfoTask>();
    Console.WriteLine($"[DB] System.db 加载完成：items={Library.Globals.ItemInfoList.Count} "
                    + $"maps={Library.Globals.MapInfoList.Count} monsters={Library.Globals.MonsterInfoList.Count} "
                    + $"quests={Library.Globals.QuestInfoList.Count}");
}
ProbeConnection conn = null;
var stage = "connect";        // connect→account→char→reconnect→gmwait→game→level→move→converse→accept
var deadline = DateTime.UtcNow.AddSeconds(opt.Timeout);
uint npcObjectId = 0;
int gmRetry = 0;
bool npcSeen = false, moveSent = false, accepted = false, failed = false;
DateTime levelSentAt = DateTime.MinValue;
DateTime converseSentAt = DateTime.MinValue;


HandleInit();
while (DateTime.UtcNow < deadline && !accepted && !failed)
{
    if (stage == "reconnect" || stage == "gmretry")
    {
        log("--", stage == "reconnect" ? "GM 通道重连…" : "5s 后重试 GM 登录…");
        if (stage == "gmretry") Thread.Sleep(5000);
        conn = NewConn();
        stage = "gmwait";
        continue;
    }
    try { conn.Process(); }
    catch (Exception ex) { Fail($"Process 异常: {ex.Message}\n{ex.StackTrace}"); break; }
    Thread.Sleep(50);
    if (!conn.Connected) { Fail($"连接断开（stage={stage}）"); break; }
    // @LEVEL 后 2.5s 发 @MOVE（GM 命令即时生效，无需解析回话）
    if (stage == "level" && !moveSent && levelSentAt != DateTime.MinValue
        && (DateTime.UtcNow - levelSentAt).TotalSeconds > 2.5)
    {
        moveSent = true;
        stage = "move";
        conn.Enqueue(new C.Chat { Text = $"@MOVE {opt.Map} {opt.X} {opt.Y}" });
        log("->", $"@MOVE {opt.Map} {opt.X} {opt.Y}");
    }
    if (stage == "move" && npcSeen) TryConverse();
    // 对话 3s 无响应 → 重发 NPCCall（ObjectID 可能因对象重建失效）
    if (stage == "converse" && converseSentAt != DateTime.MinValue
        && (DateTime.UtcNow - converseSentAt).TotalSeconds > 3)
    {
        converseSentAt = DateTime.UtcNow;
        conn.Enqueue(new C.NPCCall { ObjectID = npcObjectId });
        log("->", $"NPCCall 重试 {{ObjectID={npcObjectId}}}");
    }
}
if (!accepted && !failed) Fail($"超时（stage={stage}）");
return accepted ? 0 : 1;

void HandleInit()
{
    conn = NewConn();
}

ProbeConnection NewConn()
{
    var tcp = new TcpClient();
    tcp.Connect(opt.Host, opt.Port);
    var c = new ProbeConnection(tcp, Handle);
    c.OnException = (o, ex) =>
    {
        var root = ex;
        while (root.InnerException != null) root = root.InnerException;
        log("!!", $"{ex.GetType().Name}: {root.Message}\n{root.StackTrace}");
    };
    return c;
}

void ReconnectAsGM()
{
    // 只标记；真正重建在主循环（避免在封包线程里替换 conn 造成竞态）
    stage = "reconnect";
}

void TryConverse()
{
    if (npcObjectId == 0) return;
    stage = "converse";
    converseSentAt = DateTime.UtcNow;
    conn.Enqueue(new C.NPCCall { ObjectID = npcObjectId });
    log("->", $"NPCCall {{ObjectID={npcObjectId}}}");
}

void Handle(Packet p)
{
    log("<<", p.PacketType?.Name ?? p.GetType().Name);
    try { HandleInner(p); }
    catch (Exception ex) { Fail($"Handle 异常({p.PacketType?.Name}): {ex.GetType().Name}: {ex.Message}\n{ex.StackTrace}"); }
}

void HandleInner(Packet p)
{
    switch (p)
    {
        case G.Connected:
            conn.Enqueue(new G.Connected());
            if (stage == "connect")
            {
                stage = "account";
                conn.Enqueue(new C.SelectLanguage { Language = "CHINESE" });
                conn.Enqueue(new C.NewAccount
                {
                    EMailAddress = opt.Email, Password = opt.Pass,
                    RealName = opt.Char, BirthDate = new DateTime(1990, 1, 1),
                    Referral = string.Empty, CheckSum = string.Empty,
                });
                log("->", "NewAccount（已存在也无妨）");
            }
            else if (stage == "gmwait")
            {
                stage = "gmlogin";
                conn.Enqueue(new C.SelectLanguage { Language = "CHINESE" });
                conn.Enqueue(new C.Login
                {
                    EMailAddress = opt.Char, Password = opt.Master, CheckSum = string.Empty,
                });
                log("->", $"GM 登录（用户名=角色名 {opt.Char} + 主密码）");
            }
            break;

        case S.NewAccount r:
            if (r.Result is Library.NewAccountResult.Success or Library.NewAccountResult.AlreadyExists)
            {
                log("<-", $"NewAccount {r.Result}");
                conn.Enqueue(new C.Login { EMailAddress = opt.Email, Password = opt.Pass, CheckSum = string.Empty });
                stage = "char";
            }
            else Fail($"账号注册失败: {r.Result}");
            break;

        case S.Login r:
            if (r.Result == Library.LoginResult.AlreadyLoggedIn)
            {
                // 服务端对旧会话断连有延迟；标记后由主循环延迟重建（不在封包线程里睡）
                log("<-", "AlreadyLoggedIn（旧会话未清），主循环 5s 后重连");
                gmRetry++;
                if (gmRetry > 6) { Fail("AlreadyLoggedIn 重试 6 次仍失败"); break; }
                stage = "gmretry";
                break;
            }
            if (r.Result != Library.LoginResult.Success) { Fail($"登录失败: {r.Result} {r.Message}"); break; }
            if (stage == "gmlogin")
            {
                evidence["gm_login"] = true;
                log("<-", "GM 登录成功（TempAdmin）");
                var gmc = r.Characters?.FirstOrDefault(c => c.CharacterName == opt.Char);
                if (gmc == null) { Fail("GM 登录后找不到角色"); break; }
                conn.Enqueue(new C.StartGame { CharacterIndex = gmc.CharacterIndex });
                log("->", $"StartGame {{CharacterIndex={gmc.CharacterIndex}}}");
                stage = "game";
            }
            else
            {
                var sel = r.Characters?.FirstOrDefault(c => c.CharacterName == opt.Char);
                if (sel != null)
                {
                    evidence["char_created"] = true;
                    log("<-", $"角色已存在（{sel.CharacterName}）");
                    stage = "reconnect";
                    ReconnectAsGM();
                }
                else
                {
                    log("->", "NewCharacter 战士 " + opt.Char);
                    conn.Enqueue(new C.NewCharacter
                    {
                        CharacterName = opt.Char, Class = Enum.Parse<Library.MirClass>(opt.Class, true),
                        Gender = Library.MirGender.Male, HairType = 1,
                        HairColour = Color.White, ArmourColour = Color.White,
                        CheckSum = string.Empty,
                    });
                }
            }
            break;

        case S.NewCharacter r:
            if (r.Result == Library.NewCharacterResult.Success && r.Character != null)
            {
                log("<-", "角色创建成功");
                evidence["char_created"] = true;
                stage = "reconnect";       // 断连/重连都在主循环做（防 ReceiveList 置空竞态）
            }
            else if (r.Result == Library.NewCharacterResult.AlreadyExists)
            {
                stage = "reconnect";
            }
            else Fail($"角色创建失败: {r.Result}");
            break;

        case S.StartGame r:
            log("<-", $"S.StartGame Result={r.Result} Message={r.Message} HasStartInfo={r.StartInformation != null}");
            if (r.Result != Library.StartGameResult.Success) { Fail($"进入游戏失败: {r.Result} {r.Message}"); break; }
            log("<-", $"已进入游戏（角色 {r.StartInformation?.Name}）");
            evidence["in_game"] = true;
            stage = "level";
            levelSentAt = DateTime.UtcNow;
            conn.Enqueue(new C.Chat { Text = $"@LEVEL {opt.Level}" });
            log("->", $"@LEVEL {opt.Level}");
            break;

        case S.ObjectNPC r:
            if (r.NPCIndex == opt.Npc)
            {
                // 每次（重）见到都更新 ObjectID：传送后服务端重建对象，旧 ID 会失效
                npcObjectId = r.ObjectID;
                if (!npcSeen) evidence["npc_seen"] = new { object_id = r.ObjectID, location = r.CurrentLocation.ToString() };
                bool was = npcSeen;
                npcSeen = true;
                if (!was) log("<-", $"目标 NPC #{r.NPCIndex} 出现在视野 ({r.CurrentLocation})");
                if (stage is "move" or "converse") TryConverse();
            }
            break;

        case S.Chat r:
            if (!string.IsNullOrEmpty(r.Text) && r.ObjectID != 0)
                log("chat", r.Text);
            break;

        case S.NPCResponse r:
            log("<-", "NPCResponse（对话页已打开）");
            if (stage == "converse")
            {
                stage = "accept";
                conn.Enqueue(new C.QuestAccept { Index = opt.Quest });
                log("->", $"QuestAccept {{Index={opt.Quest}}}");
            }
            break;

        case S.QuestChanged r:
            var q = r.Quest;
            log("<-", $"QuestChanged: QuestIndex={q?.QuestIndex} Completed={q?.Completed}"
                     + $" Tasks=[{string.Join(",", q?.Tasks?.Select(t => $"{t.TaskIndex}:{t.Amount}") ?? Array.Empty<string>())}]");
            if (q != null && q.QuestIndex == opt.Quest)
            {
                accepted = true;
                evidence["accepted"] = true;
                evidence["quest_changed"] = new
                {
                    quest_index = q.QuestIndex,
                    completed = q.Completed,
                    tasks = q.Tasks?.Select(t => new { task_index = t.TaskIndex, amount = t.Amount }),
                };
                WriteEvidence();
                log("PASS", $"任务 #{opt.Quest} 接取成功：服务端已建立 UserQuest（S.QuestChanged 下发）");
            }
            break;

        case G.Disconnect r:
            Fail($"被服务端断开: {r.Reason}");
            break;
    }
}

void Fail(string msg)
{
    if (failed) return;
    failed = true;
    log("FAIL", msg);
    evidence["accepted"] = false;
    evidence["fail_reason"] = msg;
    WriteEvidence();
}

void WriteEvidence()
{
    if (string.IsNullOrEmpty(opt.Out)) return;
    var full = Path.GetFullPath(opt.Out);
    var dir = Path.GetDirectoryName(full);
    if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
    File.WriteAllText(full, JsonSerializer.Serialize(evidence,
        new JsonSerializerOptions { WriteIndented = true }));
    log("EVIDENCE", full);
}

// ---- 连接类：未处理包派发给外部回调（BotRunner BotConnection 同款） ----
sealed class ProbeConnection : BaseConnection
{
    private readonly Action<Packet> _handler;
    protected override TimeSpan TimeOutDelay => TimeSpan.FromSeconds(60);
    public ProbeConnection(TcpClient client, Action<Packet> handler) : base(client)
    {
        _handler = handler;
        AdditionalLogging = true;     // 让 BaseConnection 内部异常走 OnException（可见）
        UpdateTimeOut();
        BeginReceive();
    }
    public override void TryDisconnect() => Disconnect();
    public override void TrySendDisconnect(Packet p) => SendDisconnect(p);
    protected override void ProcessUnhandledPacket(Packet p) => _handler(p);
    public void Process(G.Connected p) => _handler(p);
    public void Process(G.CheckVersion p) { Enqueue(new G.Version { ClientHash = Array.Empty<byte>() }); }
    public void Process(G.GoodVersion p) { }
    public void Process(G.Disconnect p) { Connected = false; _handler(p); }
    public void Process(G.Ping p) { Enqueue(new G.Ping()); }
}

// ---- 命令行参数 ----
sealed class Args
{
    public string Host = "127.0.0.1";
    public int Port = 7000;
    public string Email = "questprobe@test.com";
    public string Pass = "q1234567";
    public string Char = "QuestProbeW";
    public string Class = "Warrior";
    public string Master = "";
    public string DbRoot = "/home/tetsuya/development/zircon/Debug/Client/Data";
    public int Npc;
    public int Quest;
    public string Map = "01";
    public int X, Y;
    public int Level = 20;
    public int Timeout = 150;
    public string Out;
    public Args(string[] a)
    {
        for (int i = 0; i < a.Length - 1; i++)
        {
            switch (a[i])
            {
                case "--host": Host = a[++i]; break;
                case "--port": Port = int.Parse(a[++i]); break;
                case "--email": Email = a[++i]; break;
                case "--pass": Pass = a[++i]; break;
                case "--char": Char = a[++i]; break;
                case "--class": Class = a[++i]; break;
                case "--master": Master = a[++i]; break;
                case "--dbroot": DbRoot = a[++i]; break;
                case "--npc": Npc = int.Parse(a[++i]); break;
                case "--quest": Quest = int.Parse(a[++i]); break;
                case "--map": Map = a[++i]; break;
                case "--x": X = int.Parse(a[++i]); break;
                case "--y": Y = int.Parse(a[++i]); break;
                case "--level": Level = int.Parse(a[++i]); break;
                case "--timeout": Timeout = int.Parse(a[++i]); break;
                case "--out": Out = a[++i]; break;
            }
        }
    }
}
