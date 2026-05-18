using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using UnityEngine;

/// <summary>
/// 静态网络服务：独立线程 TCP、2 字节大端长度 + 负载、收发队列。
/// 传输细节集中在 <see cref="TcpFramedConnection"/>，后续可换实现或加中间层。
/// </summary>
public static class Net
{
    const int DefaultPort = 8894;
    const int MaxFrameBody = 0xffff;
    const int JoinTimeoutMs = 3000;

    static readonly ConcurrentQueue<byte[]> SendQueue = new ConcurrentQueue<byte[]>();
    static readonly ConcurrentQueue<byte[]> RecvQueue = new ConcurrentQueue<byte[]>();

    static Thread _worker;
    static volatile bool _running;
    static volatile bool _connected;

    static string _host = "192.168.182.130";
    static int _port = DefaultPort;

    static int _reconnectDelayMs = 500;
    static readonly object StateLock = new object();

    static TcpFramedConnection _conn;
    static List<byte> _rxAccum;

    public static bool IsConnected => _connected;

    public static void Start(string host = null, int? port = null)
    {
        if (_running)
            return;

        if (!string.IsNullOrEmpty(host))
            _host = host;
        if (port.HasValue)
            _port = port.Value;

        _running = true;
        _worker = new Thread(WorkerLoop) { IsBackground = true, Name = "NetThread" };
        _worker.Start();
    }

    public static void Stop()
    {
        _running = false;
        lock (StateLock)
        {
            _conn?.Close();
            _conn = null;
        }

        if (_worker != null && _worker.IsAlive)
        {
            if (!_worker.Join(JoinTimeoutMs))
                Debug.LogWarning("[Net] worker thread did not exit in time");
        }
        _worker = null;
        _connected = false;
        while (SendQueue.TryDequeue(out _)) { }
        while (RecvQueue.TryDequeue(out _)) { }
        _rxAccum = null;
    }

    /// <summary>入队待发送负载（不含 2 字节头）；断线时丢弃队列，避免陈旧包。</summary>
    public static void EnqueueSend(byte[] payload)
    {
        if (payload == null || payload.Length == 0 || payload.Length > MaxFrameBody)
            return;
        var copy = new byte[payload.Length];
        Buffer.BlockCopy(payload, 0, copy, 0, payload.Length);
        SendQueue.Enqueue(copy);
    }

    public static bool TryDequeueReceive(out byte[] payload) => RecvQueue.TryDequeue(out payload);

    static void WorkerLoop()
    {
        _rxAccum = new List<byte>(8192);
        while (_running)
        {
            try
            {
                if (!_connected)
                {
                    ConnectOnce();
                    if (!_connected)
                    {
                        Thread.Sleep(_reconnectDelayMs);
                        _reconnectDelayMs = Math.Min(_reconnectDelayMs * 2, 8000);
                        continue;
                    }
                    _reconnectDelayMs = 500;
                }

                DrainSendQueue();
                if (!_connected)
                    continue;

                if (!PollReceive())
                    Thread.Sleep(1);
            }
            catch (Exception e)
            {
                Debug.LogWarning("[Net] worker: " + e.Message);
                DisconnectCleanup();
                Thread.Sleep(_reconnectDelayMs);
            }
        }

        DisconnectCleanup();
    }

    static void ConnectOnce()
    {
        lock (StateLock)
        {
            _conn?.Close();
            var socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp)
            {
                NoDelay = true
            };
            try
            {
                socket.Connect(_host, _port);
                _conn = new TcpFramedConnection(socket);
                _connected = true;
                _rxAccum.Clear();
                Debug.Log($"[Net] connected {_host}:{_port}");
            }
            catch (Exception e)
            {
                Debug.Log($"[Net] connect failed {_host}:{_port} — {e.Message}");
                try { socket.Close(); } catch { /* ignore */ }
                _conn = null;
                _connected = false;
            }
        }
    }

    static void DrainSendQueue()
    {
        TcpFramedConnection c;
        lock (StateLock)
            c = _conn;
        if (c == null || !c.IsAlive)
        {
            DisconnectCleanup();
            return;
        }

        while (SendQueue.TryDequeue(out var payload))
        {
            try
            {
                if (!c.TrySendFrame(payload))
                {
                    DiscardPendingSends();
                    DisconnectCleanup();
                    return;
                }
            }
            catch
            {
                DiscardPendingSends();
                DisconnectCleanup();
                return;
            }
        }
    }

    static void DiscardPendingSends()
    {
        while (SendQueue.TryDequeue(out _)) { }
    }

    static bool PollReceive()
    {
        TcpFramedConnection c;
        lock (StateLock)
            c = _conn;
        if (c == null || !c.IsAlive)
        {
            DisconnectCleanup();
            return false;
        }

        try
        {
            if (!c.PollRead(100_000))
                return false;

            var scratch = new byte[8192];
            int n = c.Receive(scratch);
            if (n == 0)
            {
                DisconnectCleanup();
                return false;
            }
            if (n < 0)
                return false;

            for (int i = 0; i < n; i++)
                _rxAccum.Add(scratch[i]);

            ExtractFrames();
            return true;
        }
        catch
        {
            DisconnectCleanup();
            return false;
        }
    }

    static void ExtractFrames()
    {
        var buf = _rxAccum;
        int o = 0;
        while (buf.Count - o >= 2)
        {
            int bodyLen = (buf[o] << 8) | buf[o + 1];
            if (bodyLen <= 0 || bodyLen > MaxFrameBody)
            {
                Debug.LogWarning("[Net] invalid frame length, closing");
                DisconnectCleanup();
                return;
            }
            if (buf.Count - o < 2 + bodyLen)
                break;

            var payload = new byte[bodyLen];
            for (int i = 0; i < bodyLen; i++)
                payload[i] = buf[o + 2 + i];
            RecvQueue.Enqueue(payload);
            o += 2 + bodyLen;
        }
        if (o > 0)
            buf.RemoveRange(0, o);
    }

    static void DisconnectCleanup()
    {
        lock (StateLock)
        {
            _conn?.Close();
            _conn = null;
        }
        if (_connected)
            Debug.Log("[Net] disconnected");
        _connected = false;
        DiscardPendingSends();
        _rxAccum?.Clear();
    }

    /// <summary>可替换为其它协议栈；默认 TCP + 定长头。</summary>
    sealed class TcpFramedConnection
    {
        readonly Socket _socket;

        public bool IsAlive => _socket != null && _socket.Connected;

        public TcpFramedConnection(Socket socket) => _socket = socket;

        public void Close()
        {
            try
            {
                _socket?.Shutdown(SocketShutdown.Both);
            }
            catch { /* ignore */ }
            try
            {
                _socket?.Close();
            }
            catch { /* ignore */ }
        }

        public bool PollRead(int microSeconds) =>
            _socket.Poll(microSeconds, SelectMode.SelectRead);

        public int Receive(byte[] buffer) => _socket.Receive(buffer, SocketFlags.None);

        public bool TrySendFrame(byte[] body)
        {
            if (body.Length > MaxFrameBody)
                return false;
            var frame = new byte[2 + body.Length];
            frame[0] = (byte)(body.Length >> 8);
            frame[1] = (byte)(body.Length & 0xff);
            Buffer.BlockCopy(body, 0, frame, 2, body.Length);
            int sent = 0;
            while (sent < frame.Length)
            {
                int n = _socket.Send(frame, sent, frame.Length - sent, SocketFlags.None);
                if (n <= 0)
                    return false;
                sent += n;
            }
            return true;
        }
    }
}
