--- proto_panel：协议调试面板 + 坦克按钮
proto_panel = {}

local CS = CS
local UnityEngine = CS.UnityEngine
local Debug = UnityEngine.Debug
local GameObject = CS.UnityEngine.GameObject
local Button = CS.UnityEngine.UI.Button
local TextMeshProUGUI = CS.TMPro.TextMeshProUGUI

local field_go
local btn_send_go
local input_field
local button

local btn_tank
local txt_content

local __btn_tank_state = "gen_tank"
local __tank_follow_mode = "self"

local WIRE_DELAY_FRAMES = 1
local wire_countdown = 0

local function printf(fmt, ...)
    print(string.format("[proto_panel] " .. tostring(fmt), ...))
end

local function FindChildByName(root, name)
    if not root then
        return nil
    end
    if root.name == name then
        return root
    end
    for i = 0, root.childCount - 1 do
        local child = root:GetChild(i)
        local found = FindChildByName(child, name)
        if found then
            return found
        end
    end
    return nil
end

local function wire_proto_input()
    field_go = GameObject.Find("protofield")
    btn_send_go = GameObject.Find("btn_send")
    if not field_go or not btn_send_go then
        printf("[wire_proto_input] protofield or btn_send not found, skip")
        return false
    end

    input_field = field_go:GetComponent(typeof(CS.TMPro.TMP_InputField))
    if not input_field then
        input_field = field_go:GetComponent(typeof(CS.UnityEngine.UI.InputField))
    end
    button = btn_send_go:GetComponent(typeof(Button))
    if not button then
        printf("[wire_proto_input] btn_send has no Button component")
        return false
    end

    button.onClick:AddListener(function()
        if not input_field then return end
        local line = input_field.text
        if not line or line == "" then return end
        Main.on_input(line)
    end)
    return true
end

local function wire_btn_tank()
    local canvas = nil
    local allui = GameObject.Find("ALLUI")
    if allui then
        local c = allui.transform:Find("Canvas")
        if c then canvas = c end
    end
    local proto = canvas and canvas:Find("Proto") or nil
    local proto_panel_tr = proto and proto:Find("proto_panel") or nil

    if not proto_panel_tr then
        printf("[wire_btn_tank] proto_panel not found")
        return
    end

    local btn_tank_tr = FindChildByName(proto_panel_tr, "btn_tank")
    if btn_tank_tr then
        btn_tank = btn_tank_tr.gameObject
        local txt_tr = FindChildByName(btn_tank_tr, "txt_content")
        if txt_tr then
            txt_content = txt_tr:GetComponent(typeof(TextMeshProUGUI))
            printf("[wire_btn_tank] txt_content found, TMPro=" .. tostring(txt_content ~= nil))
        end
    else
        Debug.LogWarning("[proto_panel] btn_tank not found under proto_panel")
    end
end

function proto_panel.BtnTankClicked()
    local state = __btn_tank_state
    local mode = __tank_follow_mode
    printf("[BtnTankClicked] state=" .. tostring(state) .. " follow_mode=" .. tostring(mode) .. " in_scene=" .. tostring(scene_panel.is_in_scene()))
    if state == "gen_tank" then
        Main.send_proto(Proto.new("m_scene_gen_tank_tos"))
    elseif state == "forward_tank" then
        __btn_tank_state = "forward_self"
        __tank_follow_mode = "tank"
        if txt_content then
            txt_content.text = __btn_tank_state
        end
        if scene_panel and scene_panel.SetTankFollowMode then
            scene_panel.SetTankFollowMode("tank")
        end
    elseif state == "forward_self" then
        __btn_tank_state = "forward_tank"
        __tank_follow_mode = "self"
        if txt_content then
            txt_content.text = __btn_tank_state
        end
        if scene_panel and scene_panel.SetTankFollowMode then
            scene_panel.SetTankFollowMode("self")
        end
    end
end

--- Tank 生成成功时调用，同步 UI 状态
function proto_panel.OnTankGenerated()
    __btn_tank_state = "forward_tank"
    __tank_follow_mode = "self"
    if txt_content then
        txt_content.text = __btn_tank_state
    end
end

function proto_panel.init()
    wire_btn_tank()
    if btn_tank and btn_tank:GetComponent(typeof(Button)) then
        btn_tank:GetComponent(typeof(Button)).onClick:AddListener(proto_panel.BtnTankClicked)
    end
    wire_countdown = WIRE_DELAY_FRAMES
    if txt_content then
        txt_content.text = __btn_tank_state
    end
end

function proto_panel.Update()
    if wire_countdown > 0 then
        wire_countdown = wire_countdown - 1
        if wire_countdown == 0 then
            if wire_proto_input() then
                printf("[Update] proto input wired")
            end
        end
    end
end

function proto_panel.OnClose()
    if button and btn_send_go then
        local btn = btn_send_go:GetComponent(typeof(Button))
        if btn then
            btn.onClick:RemoveAllListeners()
        end
    end
    if btn_tank then
        local btn = btn_tank:GetComponent(typeof(Button))
        if btn then
            btn.onClick:RemoveAllListeners()
        end
    end
    input_field = nil
    button = nil
    field_go = nil
    btn_send_go = nil
    btn_tank = nil
    txt_content = nil
    wire_countdown = 0
    __btn_tank_state = "gen_tank"
    __tank_follow_mode = "self"
end

return proto_panel
