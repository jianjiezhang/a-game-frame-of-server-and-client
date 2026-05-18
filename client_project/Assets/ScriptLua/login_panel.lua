--- login_panel：登录界面
login_panel = {}

local UnityEngine = CS.UnityEngine
local Debug = UnityEngine.Debug
local GameObject = UnityEngine.GameObject
local Resources = UnityEngine.Resources
local TMP_InputField = CS.TMPro.TMP_InputField
local Button = CS.UnityEngine.UI.Button

local root
local fields = {}
local send_click_handler
local send_button

local function trim(s)
    if s == nil then
        return ""
    end
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function find_input_under_group(groupTr)
    if groupTr == nil then
        return nil
    end
    local t = groupTr:Find("InputField")
    if t == nil then
        t = groupTr:Find("inputField")
    end
    if t == nil then
        return nil
    end
    return t:GetComponent(typeof(TMP_InputField))
end

local function on_send_click()
    local u = trim(fields.user and fields.user.text or "")
    local p = trim(fields.password and fields.password.text or "")
    local aid = trim(fields.account_id and fields.account_id.text or "")
    local aname = trim(fields.account_name and fields.account_name.text or "")
    local rid = trim(fields.role_id and fields.role_id.text or "")
    local rname = trim(fields.role_name and fields.role_name.text or "")

    if u == "" or p == "" or aid == "" or aname == "" or rid == "" or rname == "" then
        Debug.Log("[login_panel] 请填写完整登录信息（6 项均不能为空）")
        return
    end

    if Main and Main.auth then 
        Main.auth(u, p, aid, aname, rid, rname)
    end
end

-- 完整初始化：查找 UI → 实例化 prefab → OnInit → OnShow
-- 由 Main.init 调用，外部无需再单独调用
function login_panel.init()
    local allui = GameObject.Find("ALLUI")
    local canvas = allui and allui.transform:Find("Canvas") or nil
    local ui = canvas and canvas:Find("UI") or nil
    if not ui then
        Debug.Log("[login_panel.init] ALLUI/Canvas/UI not found")
        return
    end

    local prefab = Resources.Load("login_panel")
    if not prefab then
        Debug.Log("[login_panel.init] prefab 'login_panel' not found in Resources")
        return
    end

    local go = GameObject.Instantiate(prefab, ui, false)
    go:SetActive(true)
    root = go

    if login_panel.OnInit then
        login_panel.OnInit(go)
    end
    if login_panel.OnShow then
        login_panel.OnShow()
    end
end

function login_panel.OnInit(gameObject)
    root = gameObject
    local tr = gameObject.transform

    fields.user = find_input_under_group(tr:Find("user"))
    fields.password = find_input_under_group(tr:Find("password"))
    fields.account_id = find_input_under_group(tr:Find("account_id"))
    fields.account_name = find_input_under_group(tr:Find("account_name"))
    fields.role_id = find_input_under_group(tr:Find("role_id"))
    fields.role_name = find_input_under_group(tr:Find("role_name"))

    local btnTr = tr:Find("btn_send")
    if btnTr ~= nil then
        send_button = btnTr:GetComponent(typeof(Button))
    end

    if send_button == nil then
        Debug.Log("[login_panel] 未找到 btn_send 上的 Button")
        return
    end

    send_click_handler = on_send_click
    send_button.onClick:AddListener(send_click_handler)
end

function login_panel.OnShow()
    if root ~= nil then
        root:SetActive(true)
    end
end

function login_panel.OnLoginSuccess(callback)
    Debug.Log("[login_panel] 登录成功")
    if root ~= nil then
        Debug.Log("[login_panel] 设置 root 为 false")
        root:SetActive(false)
    end
    if callback then
        callback()
    end
end

function login_panel.OnLoginFailed()
    Debug.Log("登录失败")
end

function login_panel.OnClose()
    if send_button ~= nil and send_click_handler ~= nil then
        send_button.onClick:RemoveListener(send_click_handler)
    end
    send_button = nil
    send_click_handler = nil
    fields = {}
    root = nil
end

return login_panel
