using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Security.Cryptography;
using System.Net.Sockets;
using Library;
using Library.SystemModels;
using MirDB;
using System.Collections.Concurrent;

namespace NpcMover
{
    // 用法:
    //   NpcMover dump <db_root> <out_json>            导出 MapInfo + NPCInfo(含 Region/坐标) 快照
    //   NpcMover plan  <db_root> <plan_tsv> [apply]   按 TSV 计划移动 NPC: npcIndex <TAB> mapIndex <TAB> x <TAB> y
    //                                                  独占区域原位改 Map/PointRegion; 共享区域新建 MapRegion
    //   NpcMover approved <db_root> <approved_plan.json> [apply]
    //                                                  应用人工批准的 NPC + RespawnInfo 位置计划
    class Program
    {
        static string Esc(string s)
        {
            if (s == null) return "";
            var sb = new StringBuilder();
            foreach (char c in s)
            {
                switch (c)
                {
                    case '\\': sb.Append("\\\\"); break;
                    case '"': sb.Append("\\\""); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20) sb.AppendFormat("\\u{0:x4}", (int)c);
                        else sb.Append(c);
                        break;
                }
            }
            return sb.ToString();
        }

        static int Main(string[] args)
        {
            Console.OutputEncoding = Encoding.UTF8;
            if (args.Length < 3)
            {
                Console.WriteLine("用法: NpcMover dump <db_root> <out_json> | NpcMover plan <db_root> <plan_tsv> [apply] | NpcMover approved <db_root> <approved_plan.json> [apply]");
                return 1;
            }
            string mode = args[0];
            string root = args[1];
            if (!root.EndsWith("/")) root += "/";

            var session = new Session(SessionMode.Both, root);
            session.Initialize(Assembly.GetAssembly(typeof(ItemInfo)), Assembly.GetAssembly(typeof(Library.SystemModels.MapInfo)));
            Console.WriteLine($"库路径: {session.SystemPath} 存在={session.SystemDatabaseExists}");
            if (mode == "approved")
            {
                bool apply = args.Length > 3 && args[3].Equals("apply", StringComparison.OrdinalIgnoreCase);
                using JsonDocument document = JsonDocument.Parse(File.ReadAllText(args[2]));
                JsonElement plan = document.RootElement;
                if (!plan.TryGetProperty("mode", out var planMode) || planMode.GetString() != "approved-offline-plan"
                    || !plan.TryGetProperty("database_write", out var databaseWrite) || databaseWrite.GetBoolean())
                {
                    Console.WriteLine("拒绝：计划必须是 validate_manual_review.py 生成的 database_write=false approved-offline-plan");
                    return 1;
                }

                var maps = session.GetCollection<MapInfo>().Binding.ToDictionary(x => x.Index);
                var npcs = session.GetCollection<NPCInfo>().Binding.ToDictionary(x => x.Index);
                var respawns = session.GetCollection<RespawnInfo>().Binding.ToDictionary(x => x.Index);
                var errors = new List<string>();
                var npcMoves = plan.TryGetProperty("npc_moves", out var npcMoveArray) ? npcMoveArray.EnumerateArray().ToList() : new List<JsonElement>();
                var respawnUpdates = plan.TryGetProperty("respawn_updates", out var respawnArray) ? respawnArray.EnumerateArray().ToList() : new List<JsonElement>();

                int RequiredInt(JsonElement row, string name, string label)
                {
                    if (!row.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out int result))
                    {
                        errors.Add($"{label}: {name} 必须是整数");
                        return 0;
                    }
                    return result;
                }

                string RequiredString(JsonElement row, string name, string label)
                {
                    if (!row.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(value.GetString()))
                    {
                        errors.Add($"{label}: {name} 必须是非空字符串");
                        return string.Empty;
                    }
                    return value.GetString();
                }

                var seenNpc = new HashSet<int>();
                foreach (var row in npcMoves)
                {
                    int index = RequiredInt(row, "npc_index", "NPC");
                    int mapIndex = RequiredInt(row, "map_index", $"NPC#{index}");
                    int x = RequiredInt(row, "x", $"NPC#{index}");
                    int y = RequiredInt(row, "y", $"NPC#{index}");
                    RequiredString(row, "map", $"NPC#{index}");
                    if (!seenNpc.Add(index)) errors.Add($"NPC#{index}: 重复计划");
                    if (!npcs.ContainsKey(index)) errors.Add($"NPC#{index}: 数据库不存在");
                    if (!maps.ContainsKey(mapIndex)) errors.Add($"NPC#{index}: MapInfo#{mapIndex} 不存在");
                    if (x < 0 || y < 0) errors.Add($"NPC#{index}: 坐标不能为负");
                }

                var seenRespawn = new HashSet<int>();
                foreach (var row in respawnUpdates)
                {
                    int index = RequiredInt(row, "respawn_index", "RespawnInfo");
                    int mapIndex = RequiredInt(row, "map_index", $"RespawnInfo#{index}");
                    int x = RequiredInt(row, "x", $"RespawnInfo#{index}");
                    int y = RequiredInt(row, "y", $"RespawnInfo#{index}");
                    int count = RequiredInt(row, "count", $"RespawnInfo#{index}");
                    int range = RequiredInt(row, "range", $"RespawnInfo#{index}");
                    int interval = RequiredInt(row, "interval", $"RespawnInfo#{index}");
                    RequiredString(row, "map", $"RespawnInfo#{index}");
                    if (!seenRespawn.Add(index)) errors.Add($"RespawnInfo#{index}: 重复计划");
                    if (!respawns.ContainsKey(index)) errors.Add($"RespawnInfo#{index}: 数据库不存在");
                    if (!maps.ContainsKey(mapIndex)) errors.Add($"RespawnInfo#{index}: MapInfo#{mapIndex} 不存在");
                    if (x < 0 || y < 0 || count < 0 || range < 0 || interval < 0)
                        errors.Add($"RespawnInfo#{index}: 坐标/count/range/interval 不能为负");
                }

                if (errors.Count > 0)
                {
                    foreach (string error in errors) Console.WriteLine($"拒绝：{error}");
                    return 1;
                }

                Console.WriteLine($"批准计划：NPC {npcMoves.Count} 条，RespawnInfo {respawnUpdates.Count} 条，模式={(apply ? "写库" : "干跑")}");
                if (!apply)
                {
                    Console.WriteLine("(干跑，未写库)");
                    return 0;
                }

                bool PortOpen()
                {
                    try
                    {
                        using var client = new TcpClient();
                        var task = client.ConnectAsync("127.0.0.1", 7000);
                        return task.Wait(300) && client.Connected;
                    }
                    catch
                    {
                        return false;
                    }
                }

                if (PortOpen())
                {
                    Console.WriteLine("拒绝写库：TCP 7000 仍在监听");
                    return 2;
                }

                string clientPath = args.Length > 4
                    ? args[4]
                    : Path.Combine(Environment.GetEnvironmentVariable("MIR3_ZIRCON_ROOT") ?? "/home/tetsuya/development/zircon", "Debug", "Client", "Data", "System.db");
                if (!File.Exists(session.SystemPath) || !File.Exists(clientPath))
                {
                    Console.WriteLine($"拒绝写库：服务端或客户端 System.db 不存在 ({session.SystemPath}; {clientPath})");
                    return 1;
                }
                string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
                string serverBackup = Path.Combine(root, "Backup", $"npc-monster-align-{stamp}", "System.db");
                string clientBackup = Path.Combine(Path.GetDirectoryName(clientPath)!, "..", "Backup", $"npc-monster-align-{stamp}", "System.db");
                Directory.CreateDirectory(Path.GetDirectoryName(serverBackup)!);
                Directory.CreateDirectory(Path.GetDirectoryName(clientBackup)!);
                File.Copy(session.SystemPath, serverBackup, true);
                File.Copy(clientPath, clientBackup, true);
                Console.WriteLine($"服务端备份 -> {serverBackup}");
                Console.WriteLine($"客户端备份 -> {clientBackup}");

                bool IsExclusive(MapRegion region, DBObject self)
                {
                    if (region == null) return false;
                    if (region.NPCs != null && region.NPCs.Any(x => x != self)) return false;
                    if (region.Respawns != null && region.Respawns.Any(x => x != self)) return false;
                    if (region.SourceMovements != null && region.SourceMovements.Count > 0) return false;
                    if (region.DestinationMovements != null && region.DestinationMovements.Count > 0) return false;
                    if (region.SafeZones != null && region.SafeZones.Count > 0) return false;
                    if (region.BindSafeZones != null && region.BindSafeZones.Count > 0) return false;
                    if (region.QuestTasks != null && region.QuestTasks.Count > 0) return false;
                    return true;
                }

                string RegionDescription(MapRegion old, MapInfo map, string fallback)
                {
                    string suffix = old?.Description ?? string.Empty;
                    int slash = suffix.IndexOf(" / ", StringComparison.Ordinal);
                    if (slash >= 0) suffix = suffix.Substring(slash + 3);
                    return suffix.Length > 0 ? $"{map.FileName} / {suffix}" : (old?.Description ?? fallback);
                }

                int movedNpc = 0, movedRespawn = 0, createdRegions = 0;
                foreach (var row in npcMoves)
                {
                    int index = row.GetProperty("npc_index").GetInt32();
                    var npc = npcs[index];
                    var map = maps[row.GetProperty("map_index").GetInt32()];
                    int x = row.GetProperty("x").GetInt32(), y = row.GetProperty("y").GetInt32();
                    MapRegion old = npc.Region;
                    MapRegion target;
                    if (IsExclusive(old, npc))
                        target = old;
                    else
                    {
                        target = session.GetCollection<MapRegion>().CreateNewObject();
                        target.RegionType = old?.RegionType ?? RegionType.None;
                        target.Size = old?.Size ?? 0;
                        createdRegions++;
                    }
                    target.Description = RegionDescription(old, map, npc.NPCName);
                    target.Map = map;
                    target.BitRegion = null;
                    target.PointRegion = new Point[] { new Point(x, y) };
                    npc.Region = target;
                    movedNpc++;
                }

                foreach (var row in respawnUpdates)
                {
                    int index = row.GetProperty("respawn_index").GetInt32();
                    var respawn = respawns[index];
                    var map = maps[row.GetProperty("map_index").GetInt32()];
                    int x = row.GetProperty("x").GetInt32(), y = row.GetProperty("y").GetInt32();
                    int count = row.GetProperty("count").GetInt32(), range = row.GetProperty("range").GetInt32(), interval = row.GetProperty("interval").GetInt32();
                    MapRegion old = respawn.Region;
                    MapRegion target;
                    if (IsExclusive(old, respawn))
                        target = old;
                    else
                    {
                        target = session.GetCollection<MapRegion>().CreateNewObject();
                        target.RegionType = old?.RegionType ?? RegionType.None;
                        createdRegions++;
                    }
                    target.Description = RegionDescription(old, map, $"Respawn {index}");
                    target.Map = map;
                    target.Size = range;
                    target.BitRegion = null;
                    target.PointRegion = new Point[] { new Point(x, y) };
                    respawn.Region = target;
                    respawn.Count = count;
                    respawn.Delay = interval;
                    movedRespawn++;
                }

                session.Save(true);
                File.Copy(session.SystemPath, clientPath, true);
                Console.WriteLine($"写库完成：NPC {movedNpc}，RespawnInfo {movedRespawn}，新建 MapRegion {createdRegions}");
                Console.WriteLine($"客户端 System.db 已同步 -> {clientPath}");

                var roundTrip = new Session(SessionMode.Both, root);
                roundTrip.Initialize(Assembly.GetAssembly(typeof(ItemInfo)), Assembly.GetAssembly(typeof(Library.SystemModels.MapInfo)));
                var roundTripNpcs = roundTrip.GetCollection<NPCInfo>().Binding.ToDictionary(x => x.Index);
                var roundTripRespawns = roundTrip.GetCollection<RespawnInfo>().Binding.ToDictionary(x => x.Index);
                var roundTripErrors = new List<string>();

                bool RegionMatches(MapRegion region, int mapIndex, int x, int y, int? size = null)
                {
                    return region?.Map?.Index == mapIndex
                        && region.PointRegion != null
                        && region.PointRegion.Length == 1
                        && region.PointRegion[0].X == x
                        && region.PointRegion[0].Y == y
                        && (!size.HasValue || region.Size == size.Value);
                }

                foreach (var row in npcMoves)
                {
                    int index = row.GetProperty("npc_index").GetInt32();
                    if (!roundTripNpcs.TryGetValue(index, out var npc)
                        || !RegionMatches(npc.Region, row.GetProperty("map_index").GetInt32(), row.GetProperty("x").GetInt32(), row.GetProperty("y").GetInt32()))
                        roundTripErrors.Add($"NPC#{index} 位置回读不一致");
                }
                foreach (var row in respawnUpdates)
                {
                    int index = row.GetProperty("respawn_index").GetInt32();
                    if (!roundTripRespawns.TryGetValue(index, out var respawn)
                        || !RegionMatches(respawn.Region, row.GetProperty("map_index").GetInt32(), row.GetProperty("x").GetInt32(), row.GetProperty("y").GetInt32(), row.GetProperty("range").GetInt32())
                        || respawn.Count != row.GetProperty("count").GetInt32()
                        || respawn.Delay != row.GetProperty("interval").GetInt32())
                        roundTripErrors.Add($"RespawnInfo#{index} 位置/count/delay 回读不一致");
                }

                bool FilesEqual(string left, string right)
                {
                    using var leftStream = File.OpenRead(left);
                    using var rightStream = File.OpenRead(right);
                    if (leftStream.Length != rightStream.Length) return false;
                    return SHA256.HashData(leftStream).SequenceEqual(SHA256.HashData(rightStream));
                }

                if (!FilesEqual(session.SystemPath, clientPath))
                    roundTripErrors.Add("服务端与客户端 System.db SHA-256 不一致");
                if (roundTripErrors.Count > 0)
                {
                    foreach (string error in roundTripErrors) Console.WriteLine($"round-trip 失败：{error}");
                    Console.WriteLine($"备份保留：{serverBackup}; {clientBackup}");
                    return 3;
                }
                Console.WriteLine($"round-trip 通过：NPC {npcMoves.Count}，RespawnInfo {respawnUpdates.Count}，双库 SHA-256 一致");
                return 0;
            }

            if (mode == "dump")
            {
                var maps = session.GetCollection<MapInfo>().Binding.ToList();
                var npcs = session.GetCollection<NPCInfo>().Binding.ToList();

                var sb = new StringBuilder();
                sb.AppendLine("{");
                sb.AppendLine(" \"maps\": [");
                for (int i = 0; i < maps.Count; i++)
                {
                    var m = maps[i];
                    sb.AppendLine($"  {{\"index\":{m.Index},\"file\":\"{Esc(m.FileName)}\",\"desc\":\"{Esc(m.Description)}\"}}{(i < maps.Count - 1 ? "," : "")}");
                }
                sb.AppendLine(" ],");
                sb.AppendLine(" \"npcs\": [");
                for (int i = 0; i < npcs.Count; i++)
                {
                    var n = npcs[i];
                    var r = n.Region;
                    string rDesc = r?.Description ?? "";
                    string rMap = r?.Map?.FileName ?? "";
                    string pts = "";
                    bool shared = false;
                    if (r != null)
                    {
                        var p = r.PointRegion;
                        pts = p == null ? "" : string.Join(",", p.Select(q => $"{q.X},{q.Y}"));
                        shared = r.NPCs.Count > 1 || r.SourceMovements.Count > 0 || r.DestinationMovements.Count > 0
                              || r.Respawns.Count > 0 || r.SafeZones.Count > 0 || r.BindSafeZones.Count > 0 || r.QuestTasks.Count > 0;
                    }
                    string page = n.EntryPage?.Description ?? "";
                    sb.AppendLine($"  {{\"index\":{n.Index},\"name\":\"{Esc(n.NPCName)}\",\"category\":\"{n.Category}\",\"page\":\"{Esc(page)}\"," +
                        $"\"region\":{{\"index\":{r?.Index.ToString() ?? "0"},\"desc\":\"{Esc(rDesc)}\",\"mapFile\":\"{Esc(rMap)}\",\"mapIndex\":{r?.Map?.Index.ToString() ?? "0"}," +
                        $"\"points\":\"{Esc(pts)}\",\"shared\":{(shared ? "true" : "false")},\"npcCount\":{r?.NPCs.Count.ToString() ?? "0"}}}}}{(i < npcs.Count - 1 ? "," : "")}");
                }
                sb.AppendLine(" ]");
                sb.AppendLine("}");
                File.WriteAllText(args[2], sb.ToString());
                Console.WriteLine($"导出: {maps.Count} 张地图, {npcs.Count} 个 NPC -> {args[2]}");
                return 0;
            }

            if (mode == "plan")
            {
                string planFile = args[2];
                bool apply = args.Length > 3 && args[3] == "apply";

                var maps = session.GetCollection<MapInfo>().Binding.ToList();
                var npcs = session.GetCollection<NPCInfo>().Binding.ToList();
                var npcByIndex = npcs.ToDictionary(n => n.Index);
                var mapByIndex = maps.ToDictionary(m => m.Index);

                // 通用引用扫描: 所有含 MapRegion 属性的 system 类型 (Castle/Event/Fishing/Instance/
                // Milestone/Mine/Movement/NPC/Quest/Respawn/SafeZone)。原位改仅当 region 只被
                // 本 NPC 的 Region 属性引用 (引用计数==1 且引用者就是自己)。
                var refTypes = new Type[]
                {
                    typeof(CastleInfo), typeof(FishingInfo), typeof(InstanceInfo), typeof(PlayerEventTrigger), typeof(MonsterEventTrigger), typeof(MonsterEventAction),
                    typeof(MilestoneInfo), typeof(MineInfo), typeof(MovementInfo), typeof(NPCInfo),
                    typeof(QuestInfo), typeof(RespawnInfo), typeof(SafeZoneInfo),
                };
                var refProps = new List<(Type t, PropertyInfo p)>();
                foreach (var t in refTypes)
                    foreach (var p in t.GetProperties(BindingFlags.Public | BindingFlags.Instance))
                        if (p.PropertyType == typeof(MapRegion)) refProps.Add((t, p));

                int CountRefs(MapRegion region, NPCInfo self, out string who)
                {
                    who = null;
                    int count = 0;
                    foreach (var (t, p) in refProps)
                    {
                        IEnumerable<DBObject> obs =
                            t == typeof(CastleInfo) ? session.GetCollection<CastleInfo>().Binding.Cast<DBObject>() :
                            t == typeof(PlayerEventTrigger) ? session.GetCollection<PlayerEventTrigger>().Binding.Cast<DBObject>() :
                            t == typeof(MonsterEventTrigger) ? session.GetCollection<MonsterEventTrigger>().Binding.Cast<DBObject>() :
                            t == typeof(MonsterEventAction) ? session.GetCollection<MonsterEventAction>().Binding.Cast<DBObject>() :
                            t == typeof(FishingInfo) ? session.GetCollection<FishingInfo>().Binding.Cast<DBObject>() :
                            t == typeof(InstanceInfo) ? session.GetCollection<InstanceInfo>().Binding.Cast<DBObject>() :
                            t == typeof(MilestoneInfo) ? session.GetCollection<MilestoneInfo>().Binding.Cast<DBObject>() :
                            t == typeof(MineInfo) ? session.GetCollection<MineInfo>().Binding.Cast<DBObject>() :
                            t == typeof(MovementInfo) ? session.GetCollection<MovementInfo>().Binding.Cast<DBObject>() :
                            t == typeof(NPCInfo) ? session.GetCollection<NPCInfo>().Binding.Cast<DBObject>() :
                            t == typeof(QuestInfo) ? session.GetCollection<QuestInfo>().Binding.Cast<DBObject>() :
                            t == typeof(RespawnInfo) ? session.GetCollection<RespawnInfo>().Binding.Cast<DBObject>() :
                            session.GetCollection<SafeZoneInfo>().Binding.Cast<DBObject>();
                        foreach (var ob in obs)
                        {
                            if (p.GetValue(ob) != region) continue;
                            if (ob is NPCInfo n && n == self) continue;
                            count++;
                            if (who == null) who = $"{t.Name}.{p.Name}#{ob.Index}";
                        }
                    }
                    return count;
                }

                var moves = new List<(NPCInfo npc, MapInfo map, int x, int y)>();

                foreach (var line in File.ReadAllLines(planFile))
                {
                    if (string.IsNullOrWhiteSpace(line) || line.StartsWith("#")) continue;
                    var p = line.Split('\t');
                    if (p.Length < 4) { Console.WriteLine($"跳过格式错误行: {line}"); continue; }
                    int ni = int.Parse(p[0].Trim()), mi = int.Parse(p[1].Trim()), x = int.Parse(p[2].Trim()), y = int.Parse(p[3].Trim());
                    if (!npcByIndex.TryGetValue(ni, out var npc)) { Console.WriteLine($"跳过: NPC Index {ni} 不存在"); continue; }
                    if (!mapByIndex.TryGetValue(mi, out var map)) { Console.WriteLine($"跳过: Map Index {mi} 不存在"); continue; }
                    moves.Add((npc, map, x, y));
                }
                Console.WriteLine($"计划移动 {moves.Count} 个 NPC{(apply ? " (写库)" : " (干跑)")}\n");

                int moved = 0, reused = 0, created = 0, unchanged = 0;
                foreach (var (npc, map, x, y) in moves)
                {
                    var old = npc.Region;
                    string oldDesc = $"{old?.Map?.FileName ?? "?"} ({old?.PointRegion?.FirstOrDefault().X.ToString() ?? "?"},{old?.PointRegion?.FirstOrDefault().Y.ToString() ?? "?"})";
                    if (old != null && old.Map == map && old.PointRegion != null && old.PointRegion.Length == 1
                        && old.PointRegion[0].X == x && old.PointRegion[0].Y == y)
                    {
                        unchanged++;
                        continue;
                    }
                    string refBy = null;
                    bool exclusive = old != null && CountRefs(old, npc, out refBy) == 0;
                    if (!exclusive && old != null)
                        Console.WriteLine($"  !! [{npc.Index}] {npc.NPCName}: 旧 region 被其他对象引用 ({refBy}) -> 新建 region");

                    MapRegion target;
                    if (exclusive)
                    {
                        target = old;
                        reused++;
                    }
                    else
                    {
                        target = session.GetCollection<MapRegion>().CreateNewObject();
                        target.RegionType = old?.RegionType ?? RegionType.None;
                        target.Size = old?.Size ?? 0;
                        created++;
                    }

                    // Description 约定: "<地图文件名> / <店型>" —— 保留斜杠后缀
                    string suffix = old?.Description ?? "";
                    int slash = suffix.IndexOf(" / ");
                    if (slash >= 0) suffix = suffix.Substring(slash + 3);
                    target.Description = suffix.Length > 0 ? $"{map.FileName} / {suffix}" : (old?.Description ?? npc.NPCName);
                    target.Map = map;
                    target.PointRegion = new Point[] { new Point(x, y) };
                    npc.Region = target;
                    moved++;
                    Console.WriteLine($"  [{npc.Index}] {npc.NPCName}: {oldDesc} -> {map.FileName} ({x},{y}) [{(exclusive ? "原位改" : "新建region")}]");
                }

                Console.WriteLine($"\n结果: 移动 {moved} (原位改 {reused} / 新建 {created}) | 已在目标位置 {unchanged} | 共 {npcs.Count} NPC");
                if (apply && moved > 0)
                {
                    session.Save(true);
                    Console.WriteLine("已写库(全量保存)");
                }
                else if (!apply) Console.WriteLine("(干跑,未写库)");
                return 0;
            }

            Console.WriteLine($"未知模式: {mode}");
            return 1;
        }
    }
}
