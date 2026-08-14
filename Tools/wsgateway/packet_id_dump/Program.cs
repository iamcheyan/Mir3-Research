using System;
using System.Collections.Generic;
using System.Reflection;
using Library.Network;

// 复刻 LibraryCore/Network/Packet.cs 静态构造的 Packets 排序表，
// 用反射读出私有静态字段 Packets，打印每个包类型的索引（即线上 packet id）。
class Program
{
    static void Main()
    {
        // 强制运行 Packet 静态构造函数（完成排序）
        System.Runtime.CompilerServices.RuntimeHelpers.RunClassConstructor(typeof(Packet).TypeHandle);

        FieldInfo fi = typeof(Packet).GetField("Packets", BindingFlags.Static | BindingFlags.NonPublic);
        List<Type> packets = (List<Type>)fi.GetValue(null);

        Console.WriteLine($"Count={packets.Count}");
        for (int i = 0; i < packets.Count; i++)
            Console.WriteLine($"{i}\t{packets[i].Namespace}\t{packets[i].Name}");
    }
}
