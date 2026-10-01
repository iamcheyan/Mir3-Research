using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Net.Sockets;
using System.Threading;
using Library;
using Library.Network;
using G = Library.Network.GeneralPackets;
using C = Library.Network.ClientPackets;
using S = Library.Network.ServerPackets;

// 通过游戏协议建角色: 登录 -> NewCharacter -> 断线
// 用法: CharCreator [host] [port] [角色名] [class=0/1/2]  |  CharCreator --list [host] [port]
//       CharCreator --delete <idx>... [host] [port]
class CreateConnection : BaseConnection
{
    private readonly string _charName;
    private readonly MirClass _cls;
    private readonly bool _listOnly;
    private readonly System.Collections.Generic.List<int> _deleteIndices;
    private int _deleteStage;

    protected override TimeSpan TimeOutDelay => TimeSpan.FromSeconds(30);
    public CreateConnection(TcpClient client, string name, MirClass cls, bool listOnly = false, System.Collections.Generic.List<int> deleteIndices = null) : base(client)
    { _charName = name; _cls = cls; _listOnly = listOnly; _deleteIndices = deleteIndices; }

    public override void TryDisconnect() { Connected = false; }
    public override void TrySendDisconnect(Packet p) { SendDisconnect(p); }
    public void StartReceive() { BeginReceive(); }

    protected override void ProcessUnhandledPacket(Packet p)
    {
        Console.WriteLine($"[<-] (未处理) {p.PacketType.Name}");
    }

    public void Process(G.Connected p) { Enqueue(new G.Connected()); }
    public void Process(G.GoodVersion p)
    {
        Console.WriteLine("[OK] 版本校验通过, 发送 Login");
        Enqueue(new C.Login { EMailAddress = "test@test.com", Password = "test123" });
    }
    public void Process(S.Login p)
    {
        if (p.Result != LoginResult.Success)
        {
            Console.WriteLine($"[FAIL] 登录失败: {p.Result} {p.Message}");
            Connected = false;
            return;
        }
        Console.WriteLine($"[OK] 登录成功, 现有角色数: {p.Characters?.Count ?? 0}");
        foreach (var c in p.Characters ?? new System.Collections.Generic.List<SelectInfo>())
            Console.WriteLine($"    #{c.CharacterIndex} {c.CharacterName} Lv{c.Level} {c.Class} {c.Gender}");
        if (_listOnly) { Connected = false; return; }
        if (_deleteIndices is { Count: > 0 })
        {
            _deleteStage = 0;
            SendDelete();
            return;
        }
        Console.WriteLine($"[->] NewCharacter: {_charName} class={_cls}");
        Enqueue(new C.NewCharacter
        {
            CharacterName = _charName,
            Class = _cls,
            Gender = MirGender.Male,
            HairType = 1,
            HairColour = System.Drawing.Color.Black,
            ArmourColour = System.Drawing.Color.White,
            CheckSum = "",
        });
    }
    private void SendDelete()
    {
        int idx = _deleteIndices[_deleteStage];
        Console.WriteLine($"[->] DeleteCharacter: #{idx}");
        Enqueue(new C.DeleteCharacter { CharacterIndex = idx, CheckSum = "" });
    }
    public void Process(S.DeleteCharacter p)
    {
        Console.WriteLine($"[<-] DeleteCharacter 结果: {p.Result}");
        _deleteStage++;
        if (_deleteStage < _deleteIndices.Count) SendDelete();
        else Connected = false;
    }
    public void Process(S.NewCharacter p)
    {
        Console.WriteLine($"[<-] NewCharacter 结果: {p.Result}");
        Connected = false;
    }
    public void Process(G.Disconnect p)
    {
        Console.WriteLine($"[<-] Disconnect: {p.Reason}");
        Connected = false;
    }
}

class Program
{
    static int Main(string[] args)
    {
        Packet.IsClient = true;
        bool listOnly = args.Contains("--list", StringComparer.OrdinalIgnoreCase);
        List<int> del = new List<int>();
        for (int i = 0; i < args.Length - 1; i++)
            if (args[i].Equals("--delete", StringComparison.OrdinalIgnoreCase)) del.Add(int.Parse(args[i + 1]));
        var pos = args.Where(a => !a.Equals("--list", StringComparison.OrdinalIgnoreCase)
            && !a.Equals("--delete", StringComparison.OrdinalIgnoreCase)).ToList();
        // 去掉 --delete 后面的索引值
        for (int i = 0; i < args.Length - 1; i++)
            if (args[i].Equals("--delete", StringComparison.OrdinalIgnoreCase)) pos.Remove(args[i + 1]);
        string host = pos.Count > 0 ? pos[0] : "127.0.0.1";
        int port = pos.Count > 1 ? int.Parse(pos[1]) : 7001;
        string name = pos.Count > 2 ? pos[2] : "TestMage";
        int cls = pos.Count > 3 ? int.Parse(pos[3]) : 1;

        Console.WriteLine(listOnly
            ? $"连接 {host}:{port} 列出角色 ..."
            : $"连接 {host}:{port} 创建角色 {name} class={cls} ...");
        TcpClient client = new TcpClient();
        try { client.Connect(host, port); }
        catch (Exception ex) { Console.WriteLine("连接失败: " + ex.Message); return 1; }

        var conn = new CreateConnection(client, name, (MirClass)cls, listOnly, del.Count > 0 ? del : null);
        conn.OnException = (o, ex) => Console.WriteLine($"[!!] {ex.GetType().Name}: {ex.Message}");
        conn.StartReceive();
        conn.UpdateTimeOut();

        for (int i = 0; i < 150 && conn.Connected; i++)
        {
            try { conn.Process(); }
            catch (Exception ex) { Console.WriteLine($"[!!] {ex.Message}"); break; }
            Thread.Sleep(100);
        }
        Console.WriteLine("完成");
        return 0;
    }
}
