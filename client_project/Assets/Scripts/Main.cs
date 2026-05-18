using System.IO;
using System.Text;
using UnityEngine;
using XLua;

public class Main : MonoBehaviour
{
    LuaEnv _luaEnv;
    LuaFunction _luaUpdate;
    LuaFunction _luaOnMessage;
    LuaFunction _luaOnInput;

    void Awake()
    {
        Application.runInBackground = true;
    }

    void Start()
    {
        _luaEnv = new LuaEnv();
        _luaEnv.AddLoader(ScriptLuaLoader);

        _luaEnv.Global.Set("send_to_server", new System.Action<int, string>(OnLuaSendToServer));

        _luaEnv.DoString("require 'Main'");
        _luaEnv.Global.Get("Main", out LuaTable mainTable);
        if (mainTable != null)
        {
            using (var initFn = mainTable.Get<LuaFunction>("init"))
            {
                if (initFn != null)
                {
                    try
                    {
                        var opts = _luaEnv.NewTable();
                        opts.Set("client_id", 1);
                        initFn.Call(opts);
                        opts.Dispose();
                    }
                    catch (System.Exception e)
                    {
                        Debug.LogWarning("[Main] Main.init: " + e.Message);
                    }
                }
            }
            mainTable.Dispose();
        }
        else
            Debug.LogWarning("[Main] Main module not found after require Main");

        Net.Start();

        _luaEnv.Global.Get("Main", out LuaTable mainTable2);
        if (mainTable2 != null)
        {
            _luaUpdate = mainTable2.Get<LuaFunction>("update");
            _luaOnMessage = mainTable2.Get<LuaFunction>("on_message");
            _luaOnInput = mainTable2.Get<LuaFunction>("on_input");
            mainTable2.Dispose();
        }
    }

    static byte[] ScriptLuaLoader(ref string filename)
    {
        var rel = filename.Replace('.', Path.DirectorySeparatorChar) + ".lua";
        var path = Path.Combine(Application.dataPath, "ScriptLua", rel);
        if (!File.Exists(path))
            return null;
        return File.ReadAllBytes(path);
    }

    static void OnLuaSendToServer(int clientId, string data)
    {
        if (string.IsNullOrEmpty(data))
            return;
        var bytes = Encoding.UTF8.GetBytes(data);
        Net.EnqueueSend(bytes);
    }

    void Update()
    {
        if (_luaEnv == null)
            return;

        _luaEnv.Tick();

        while (Net.TryDequeueReceive(out var payload))
        {
            var msg = Encoding.UTF8.GetString(payload);
            try
            {
                _luaOnMessage?.Call(msg);
            }
            catch (System.Exception e)
            {
                Debug.LogWarning("[Main] on_message: " + e.Message);
            }
        }

        try
        {
            _luaUpdate?.Call(Time.deltaTime);
        }
        catch (System.Exception e)
        {
            Debug.LogWarning("[Main] update: " + e.Message);
        }
    }

    void OnDestroy()
    {
        Net.Stop();

        if (_luaEnv != null)
        {
            var lp = _luaEnv.Global.GetInPath<LuaTable>("login_panel");
            if (lp != null)
            {
                using (var onClose = lp.Get<LuaFunction>("OnClose"))
                    onClose?.Call();
                lp.Dispose();
            }
        }

        _luaUpdate?.Dispose(); _luaUpdate = null;
        _luaOnMessage?.Dispose(); _luaOnMessage = null;
        _luaOnInput?.Dispose(); _luaOnInput = null;
        _luaEnv?.Dispose(); _luaEnv = null;
    }
}
