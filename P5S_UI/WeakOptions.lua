local _, addon = ...
local L = (addon and addon.L) or setmetatable({}, { __index = function(_, key) return key end })

-- 独立设置入口；通过插件私有共享对象通知图片模块。
local function NotifyRuntime(method, ...)
    local runtime = addon and addon.WeakPortraits
    if runtime and type(runtime[method]) == "function" then runtime[method](...) end
end
local function ApplyWeakTheme(methodName, ...)
    local theme = addon and addon.PanelTheme
    local method = theme and theme[methodName]
    if type(method) ~= "function" then return false end
    return pcall(method, theme, ...)
end

local PANEL_WIDTH, PANEL_HEIGHT = 900, 520
local panel = CreateFrame("Frame", "P5WeakConfigPanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetToplevel(true)
panel:SetClampedToScreen(true)
panel:Hide()

-- 在所有主题调用前注册；主题失败不影响命令和基础控件。
SLASH_P5WEAK1 = "/p5weak"
SlashCmdList["P5WEAK"] = function()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

if not ApplyWeakTheme("ApplyOptionsPanel", panel) then
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 32, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel:SetBackdropColor(0.035, 0.040, 0.060, 0.96)
    panel:SetBackdropBorderColor(0.24, 0.28, 0.36, 0.95)
end

if not panel.TitleBg then
    panel.TitleBg = panel:CreateTexture(nil, "BACKGROUND")
    panel.TitleBg:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.TitleBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.TitleBg:SetHeight(38)
    panel.TitleBg:SetColorTexture(0.055, 0.060, 0.085, 0.98)
end
if not panel.CloseButton then
    panel.CloseButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    panel.CloseButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -7)
    panel.CloseButton:SetScript("OnClick", function() panel:Hide() end)
end

panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:HookScript("OnShow", function(self)
    self:SetScale(math.min(1, UIParent:GetWidth() / (PANEL_WIDTH + 40), UIParent:GetHeight() / (PANEL_HEIGHT + 40)))
    self:Raise()
end)

panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
panel.title:SetPoint("CENTER", panel.TitleBg, "CENTER", 0, 0)
panel.title:SetText(L["Weak眼神特写"])
ApplyWeakTheme("StylePanelTitle", panel.title)

local description = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
description:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -56)
description:SetText(L["多个技能用逗号分隔，支持名称、Spell ID 或链接；回车或离开输入框完成绑定，设置自动保存。"])
ApplyWeakTheme("StyleMutedText", description)

local section = CreateFrame("Frame", nil, panel, "BackdropTemplate")
section:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -86)
section:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -86)
section:SetHeight(350)
local accent = section:CreateTexture(nil, "ARTWORK")
accent:SetPoint("TOPLEFT")
accent:SetPoint("BOTTOMLEFT")
accent:SetWidth(4)
local sectionTitle = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sectionTitle:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -12)
sectionTitle:SetText(L["技能与图片设置"])
if not ApplyWeakTheme("StyleSection", section, sectionTitle, accent) then
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    section:SetBackdropColor(0.035, 0.040, 0.058, 0.72)
    section:SetBackdropBorderColor(0.28, 0.32, 0.40, 0.72)
    accent:SetColorTexture(0.82, 0.07, 0.05, 1)
end

local MIN_SIZE, MAX_SIZE, DEFAULT_SIZE = 200, 4000, 400
local POSITION_LIMIT = 10000
local copiedPosition -- 本次加载内共用的坐标快照；不与任一角色配置共享表。

local function FiniteNumber(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function NormalizePosition(value)
    value = FiniteNumber(value) or 0
    value = math.max(-POSITION_LIMIT, math.min(POSITION_LIMIT, value))
    return math.floor(value * 10 + 0.5) / 10
end

local function GetPortraitSettings(key)
    if not P5S_UI_DB then return nil end
    if type(P5S_UI_DB.weakPortraitSettings) ~= "table" then P5S_UI_DB.weakPortraitSettings = {} end
    local settings = P5S_UI_DB.weakPortraitSettings
    if type(settings[key]) ~= "table" then settings[key] = {} end
    local config = settings[key]
    config.size = math.floor(math.max(MIN_SIZE, math.min(MAX_SIZE, FiniteNumber(config.size) or DEFAULT_SIZE)) + 0.5)
    if type(config.isLocked) ~= "boolean" then config.isLocked = true end
    -- 图片中心统一锚定 UIParent 中心；X/Y 使用未乘图片缩放的 UI 单位。
    config.xOfs = NormalizePosition(config.xOfs)
    config.yOfs = NormalizePosition(config.yOfs)
    return config
end

local bindingLabels = {}
addon.WeakOptions = {
    GetSettings = GetPortraitSettings,
    SetBindingStatus = function(key, text)
        if bindingLabels[key] then bindingLabels[key]:SetText(text) end
    end,
}

local feedback = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
feedback:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 30)
feedback:SetWidth(660)
feedback:SetJustifyH("LEFT")
feedback:SetText(L["在一组中复制位置，再到另一组粘贴；只复制位置。"])
ApplyWeakTheme("StyleMutedText", feedback)

local rows = {
    { label = "Joker", key = "joker", field = "weakJokerSpellInput", name = "P5S_WeakJokerSpellInput", prefix = "P5S_WeakJoker" },
    { label = L["结城理"], key = "makoto", field = "weakMakotoSpellInput", name = "P5S_WeakMakotoSpellInput", prefix = "P5S_WeakMakoto" },
}
for index, row in ipairs(rows) do
    local field = row.field
    local top = -58 - (index - 1) * 150
    local input = CreateFrame("EditBox", row.name, section, "InputBoxTemplate")
    input:SetSize(300, 28)
    input:SetPoint("TOPLEFT", section, "TOPLEFT", 100, top)
    input:SetAutoFocus(false)
    input:SetMaxLetters(255)
    -- 移除 InputBoxTemplate 自带的聚焦全选；保留原生点击定位和拖选，主题稍后附加焦点配色。
    input:SetScript("OnEditFocusGained", nil)
    input:SetScript("OnTextChanged", function(self, userInput)
        if userInput and P5S_UI_DB then
            P5S_UI_DB[field] = self:GetText()
            NotifyRuntime("InvalidateBinding", row.key)
        end
    end)
    input:SetScript("OnEnterPressed", function(self)
        NotifyRuntime("ResolveBinding", row.key)
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEditFocusLost", function() NotifyRuntime("ResolveBinding", row.key) end)
    input:SetScript("OnHide", function(self)
        NotifyRuntime("ResolveBinding", row.key)
        self:ClearFocus()
    end)
    ApplyWeakTheme("StyleEditBox", input)
    local bindingLabel = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bindingLabel:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -3)
    bindingLabel:SetWidth(300)
    bindingLabel:SetWordWrap(false)
    bindingLabel:SetJustifyH("LEFT")
    bindingLabel:SetText(L["可绑定多个技能，用逗号分隔"])
    bindingLabels[row.key] = bindingLabel
    ApplyWeakTheme("StyleMutedText", bindingLabel)

    local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", input, "LEFT", -76, 0)
    label:SetText(row.label)
    ApplyWeakTheme("StyleBodyText", label)

    local sizeSlider = CreateFrame("Slider", row.prefix .. "SizeSlider", section, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", section, "TOPLEFT", 450, top - 6)
    sizeSlider:SetWidth(220)
    sizeSlider:SetMinMaxValues(MIN_SIZE, MAX_SIZE)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    _G[sizeSlider:GetName() .. "Low"]:SetText(MIN_SIZE)
    _G[sizeSlider:GetName() .. "High"]:SetText(MAX_SIZE)
    local sizeText = _G[sizeSlider:GetName() .. "Text"]
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        local config = GetPortraitSettings(row.key)
        if not config or not FiniteNumber(value) then return end
        config.size = math.floor(math.max(MIN_SIZE, math.min(MAX_SIZE, value)) + 0.5)
        sizeText:SetText(L["图片大小: "] .. config.size)
        NotifyRuntime("RefreshLayout", row.key)
    end)
    ApplyWeakTheme("StyleSlider", sizeSlider)

    local lockCheck = CreateFrame("CheckButton", row.prefix .. "LockCheck", section, "UICheckButtonTemplate")
    _G[lockCheck:GetName() .. "Text"]:SetText(L["锁定位置"])
    lockCheck:SetScript("OnClick", function(self)
        local config = GetPortraitSettings(row.key)
        if config then config.isLocked = self:GetChecked() and true or false end
        NotifyRuntime("RefreshLayout", row.key)
    end)
    ApplyWeakTheme("StyleCheckBox", lockCheck)

    -- 临时预览只在面板打开期间有效，关闭时清除勾选和显示状态。
    local previewCheck = CreateFrame("CheckButton", row.prefix .. "PreviewCheck", section, "UICheckButtonTemplate")
    previewCheck:SetPoint("TOPLEFT", section, "TOPLEFT", 96, top - 54)
    previewCheck:SetChecked(false)
    _G[previewCheck:GetName() .. "Text"]:SetText(L["保持显示"])
    previewCheck:SetScript("OnClick", function(self)
        NotifyRuntime("SetPreview", row.key, self:GetChecked() and true or false)
    end)
    ApplyWeakTheme("StyleCheckBox", previewCheck)
    lockCheck:SetPoint("TOPLEFT", previewCheck, "TOPLEFT", 122, 0)

    local centerButton = CreateFrame("Button", row.prefix .. "CenterPosition", section, "UIPanelButtonTemplate")
    centerButton:SetSize(120, 28)
    centerButton:SetPoint("TOPLEFT", section, "TOPLEFT", 710, top - 3)
    centerButton:SetText(L["重置位置"])
    centerButton:SetScript("OnClick", function()
        local config = GetPortraitSettings(row.key)
        if not config then return end
        config.xOfs, config.yOfs = 0, 0
        -- 保留当前预览选择；预览开启时同时结束旧拖动，避免坐标被写回。
        NotifyRuntime("SetPreview", row.key, previewCheck:GetChecked() and true or false)
        feedback:SetText(row.label .. L[" 已回到屏幕中央；大小、技能与锁定状态保留。"])
    end)
    ApplyWeakTheme("StyleButton", centerButton)

    local copyButton = CreateFrame("Button", row.prefix .. "CopyPosition", section, "UIPanelButtonTemplate")
    copyButton:SetSize(96, 28)
    copyButton:SetPoint("TOPLEFT", section, "TOPLEFT", 466, top - 54)
    copyButton:SetText(L["复制位置"])
    copyButton:SetScript("OnClick", function()
        local config = GetPortraitSettings(row.key)
        if not config then return end
        copiedPosition = { xOfs = config.xOfs, yOfs = config.yOfs, label = row.label }
        feedback:SetText(L["已复制 "] .. row.label .. L[" 的位置，可粘贴给另一张眼神图。"])
    end)
    ApplyWeakTheme("StyleButton", copyButton)

    local pasteButton = CreateFrame("Button", row.prefix .. "PastePosition", section, "UIPanelButtonTemplate")
    pasteButton:SetSize(96, 28)
    pasteButton:SetPoint("LEFT", copyButton, "RIGHT", 12, 0)
    pasteButton:SetText(L["粘贴位置"])
    pasteButton:SetScript("OnClick", function()
        if not copiedPosition then
            feedback:SetText(L["请先在 Joker 或结城理处点击“复制位置”。"])
            return
        end
        local config = GetPortraitSettings(row.key)
        if not config then return end
        -- 只复制坐标数值，保留目标的技能、大小与锁定状态。
        config.xOfs, config.yOfs = copiedPosition.xOfs, copiedPosition.yOfs
        NotifyRuntime("RefreshLayout", row.key)
        feedback:SetText(string.format(L["已将 %s 的位置粘贴给 %s；大小与锁定状态保留。"], copiedPosition.label, row.label))
    end)
    ApplyWeakTheme("StyleButton", pasteButton)

    panel:HookScript("OnHide", function()
        previewCheck:SetChecked(false)
        NotifyRuntime("SetPreview", row.key, false)
        NotifyRuntime("ResolveBinding", row.key)
    end)
    panel:HookScript("OnShow", function()
        if not P5S_UI_DB then return end
        if type(P5S_UI_DB[field]) ~= "string" then P5S_UI_DB[field] = "" end
        input:SetText(P5S_UI_DB[field])
        input:SetCursorPosition(0)
        local config = GetPortraitSettings(row.key)
        sizeSlider:SetValue(config.size)
        lockCheck:SetChecked(config.isLocked)
    end)
end

local helpText = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
helpText:SetPoint("TOPLEFT", section, "TOPLEFT", 24, -310)
helpText:SetWidth(800)
helpText:SetJustifyH("LEFT")
helpText:SetText(L["勾选“保持显示”并解锁后拖动；图片移出屏幕时，点击“重置位置”找回。\n位置自动保存；关闭面板会取消“保持显示”，再次打开时默认未勾选。"])
ApplyWeakTheme("StyleMutedText", helpText)

local voiceTip = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
voiceTip:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -448)
voiceTip:SetWidth(852)
voiceTip:SetJustifyH("LEFT")
voiceTip:SetText(L["推荐搭配“技能语音设置 → 爆发语音”，绑定同一技能，让眼神特写与语音同步，更还原原版游戏效果。"])
ApplyWeakTheme("StyleMutedText", voiceTip)

local backButton = CreateFrame("Button", "P5WeakBackToMainButton", panel, "UIPanelButtonTemplate")
backButton:SetSize(156, 28)
backButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 24)
backButton:SetText(L["返回P5S主界面"])
backButton:SetScript("OnClick", function()
    panel:Hide()
    local mainPanel = _G.P5S_OptionsPanel
    if mainPanel and mainPanel:IsShown() then
        if mainPanel.Raise then mainPanel:Raise() end
        return
    end
    local commandHandler = SlashCmdList["P5SUI"]
    if type(commandHandler) == "function" then commandHandler("") end
end)
ApplyWeakTheme("StyleButton", backButton)
