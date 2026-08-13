using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
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
                Console.WriteLine("用法: NpcMover dump <db_root> <out_json> | NpcMover plan <db_root> <plan_tsv> [apply]");
                return 1;
            }
            string mode = args[0];
            string root = args[1];
            if (!root.EndsWith("/")) root += "/";

            var session = new Session(SessionMode.Both, root);
            session.Initialize(Assembly.GetAssembly(typeof(ItemInfo)), Assembly.GetAssembly(typeof(Library.SystemModels.MapInfo)));
            Console.WriteLine($"库路径: {session.SystemPath} 存在={session.SystemDatabaseExists}");

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
