local _, addon = ...
local L = (addon and addon.L) or setmetatable({}, { __index = function(_, key) return key end })

-- 名称仅在脱战配置阶段解析；实际显示仍由原生 AuraContainer 驱动。
local WIDTH, HEIGHT = 980, 520
local groups = {
    { key = "attack", symbol = L["攻"], title = L["攻击强化 · 攻"], description = L["伤害、攻击等增益。"] },
    { key = "defense", symbol = L["防"], title = L["防御强化 · 防"], description = L["减伤、防御等增益。"] },
    { key = "speed", symbol = L["速"], title = L["速度强化 · 速"], description = L["移速或急速 Buff。"] },
}
local levels = {
    { key = "small", title = L["小提升"], arrows = "↑" },
    { key = "large", title = L["大提升"], arrows = "↑↑" },
}
local rows = {}

local function Theme(methodName, ...)
    local theme = addon and addon.PanelTheme
    local method = theme and theme[methodName]
    if type(method) ~= "function" then return false end
    return pcall(method, theme, ...)
end

local function GetDraft()
    if type(P5S_UI_DB) ~= "table" then return nil end
    if type(P5S_UI_DB.buffIndicatorDraft) ~= "table" then
        P5S_UI_DB.buffIndicatorDraft = { version = 1, groups = {} }
    end
    local draft = P5S_UI_DB.buffIndicatorDraft
    -- 未知版本不改写；旧战斗提示配置始终不受影响。
    if draft.version ~= 1 then return nil end
    if type(draft.groups) ~= "table" then draft.groups = {} end
    for _, group in ipairs(groups) do
        if type(draft.groups[group.key]) ~= "table" then draft.groups[group.key] = {} end
        for _, level in ipairs(levels) do
            if type(draft.groups[group.key][level.key]) ~= "string" then
                draft.groups[group.key][level.key] = ""
            end
        end
    end
    return draft
end

local function Public(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and not secret
end
local function ValidID(id)
    return type(id) == "number" and id > 0 and id <= 2147483647 and id == math.floor(id)
end
local function CanResolveNames()
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    return ok and Public(combat) and combat == false
end
local function SpellInfo(value)
    if not C_Spell or type(C_Spell.GetSpellInfo) ~= "function" then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, value)
    if ok and Public(info) and type(info) == "table"
        and Public(info.name) and type(info.name) == "string"
        and Public(info.spellID) and ValidID(info.spellID) then return info end
end
-- 名称解析专用：玩家 Buff 与同名施法并不总是同一个 ID。
-- 三组共用身份表；同 ID 的施法/Buff 也必须明确记录，不能一直标为候选。
-- 对照客户端法术记录及 SimC midnight；显示效果仍需本机实测。
local knownBuffs = {
    { name = "反魔法护罩", buffID = 48707, castID = 48707 },
    { name = "枯萎凋零", buffID = 188290, castID = 43265 },
    { name = "符文刃舞", buffID = 81256, castID = 49028 },
    { name = "白骨之盾", buffID = 195181 },
    { name = "吸血鬼之血", buffID = 55233, castID = 55233 },
    { name = "死亡脚步", buffID = 48265, castID = 48265 },
    { name = "鲜血禁闭", buffID = 273947 }, -- 用户客户端同名自身 Buff 已确认。
}
local BUFF_BY_CAST, CAST_BY_BUFF, BUFF_BY_NAME, KNOWN_BUFF_IDS = {}, {}, {}, {}
for _, record in ipairs(knownBuffs) do
    BUFF_BY_NAME[record.name] = record.buffID
    KNOWN_BUFF_IDS[record.buffID] = true
    if record.castID then
        BUFF_BY_CAST[record.castID] = record.buffID
        CAST_BY_BUFF[record.buffID] = record.castID
    end
end
-- 仅用于配置文案；数字 ID 始终按原值绑定，名称查询失败不阻止应用。
local displayNames, displayNameCount = {}, 0
local function DisplayName(id)
    if displayNames[id] then return displayNames[id] end
    local name
    if CanResolveNames() then
        local info = SpellInfo(id)
        if info and info.name ~= "" then name = info.name end
    end
    if not name then
        for _, record in ipairs(knownBuffs) do
            if record.buffID == id or record.castID == id then name = record.name; break end
        end
    end
    if name then
        if displayNameCount >= 768 then displayNames, displayNameCount = {}, 0 end
        displayNames[id] = name
        displayNameCount = displayNameCount + 1
    end
    return name
end
local function NameEntry(id, source)
    if BUFF_BY_CAST[id] and BUFF_BY_CAST[id] ~= id then
        return { id = BUFF_BY_CAST[id], source = "known" }
    end
    if KNOWN_BUFF_IDS[id] and (source == "spell" or source == "catalog") then source = "known" end
    return { id = id, source = source }
end
local function CachedName(name)
    local draft = GetDraft()
    local cache = draft and draft.nameCache
    local entry = type(cache) == "table" and cache[name]
    if type(entry) == "table" and ValidID(entry.id)
        and (entry.source == "aura" or entry.source == "known" or entry.source == "spell" or entry.source == "catalog") then
        return NameEntry(entry.id, entry.source)
    end
end
-- 只索引客户端目录的静态法术身份，不读取冷却、Aura 状态或原生框体。
-- 每次打开面板/应用配置至多构建一次；目录缺失或失败时继续其他解析路径。
local catalogNames
local function ResetCatalog()
    if CanResolveNames() then catalogNames = nil end
end
local function CatalogName(name)
    if not CanResolveNames() then return nil end
    if not catalogNames then
        catalogNames = {}
        local api, categories = C_CooldownViewer, Enum and Enum.CooldownViewerCategory
        if not api or not categories or type(api.GetCooldownViewerCategorySet) ~= "function"
            or type(api.GetCooldownViewerCooldownInfo) ~= "function" then return nil end
        local seenSpells, seenCooldowns = {}, {}
        local function AddSpell(id)
            if not Public(id) or not ValidID(id) or seenSpells[id] then return end
            seenSpells[id] = true
            local info = SpellInfo(id)
            if not info then return end
            local key = info.name:lower()
            local entry = NameEntry(id, "catalog")
            local ids = catalogNames[key]
            if not ids then ids = {}; catalogNames[key] = ids end
            ids[entry.id] = true
        end
        for _, categoryName in ipairs({ "Essential", "Utility", "TrackedBuff", "TrackedBar" }) do
            local category = categories[categoryName]
            if Public(category) and type(category) == "number" then
                local ok, cooldowns = pcall(api.GetCooldownViewerCategorySet, category, true)
                if ok and Public(cooldowns) and type(cooldowns) == "table" then
                    for index = 1, 256 do
                        local cooldownID = cooldowns[index]
                        if not Public(cooldownID) then break end
                        if cooldownID == nil then break end
                        if ValidID(cooldownID) and not seenCooldowns[cooldownID] then
                            seenCooldowns[cooldownID] = true
                            local gotInfo, info = pcall(api.GetCooldownViewerCooldownInfo, cooldownID)
                            if gotInfo and Public(info) and type(info) == "table" then
                                AddSpell(info.spellID)
                                AddSpell(info.overrideSpellID)
                                AddSpell(info.overrideTooltipSpellID)
                                local linked = info.linkedSpellIDs
                                if Public(linked) and type(linked) == "table" then
                                    for linkIndex = 1, 32 do
                                        local id = linked[linkIndex]
                                        if not Public(id) or id == nil then break end
                                        AddSpell(id)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local matches = catalogNames[name:lower()]
    if not matches then return nil end
    local ids = {}
    for id in pairs(matches) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids == 1 then return NameEntry(ids[1], "catalog") end
    local summary = {}
    for index = 1, math.min(8, #ids) do summary[index] = ids[index] end
    return nil, name .. L["：同名目录 ID 有多个（"] .. table.concat(summary, ", ")
        .. (#ids > 8 and "…" or "") .. L["），请填写要监控的 Buff ID。"]
end
local function ResolveName(name, learn)
    local cached = CachedName(name)
    if not CanResolveNames() then return cached end
    -- 编辑与应用均可脱战查询当前同名 Buff；不监视事件、不查询时间或层数。
    if learn and C_UnitAuras and type(C_UnitAuras.GetAuraDataBySpellName) == "function" then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if ok and Public(aura) and type(aura) == "table"
            and Public(aura.name) and type(aura.name) == "string" and aura.name == name
            and Public(aura.spellId) and ValidID(aura.spellId) then
            return NameEntry(aura.spellId, "aura")
        end
    end
    if cached and cached.source == "aura" then return cached end
    -- 优先使用已核对的 Buff 映射；不要把同名施法 ID 直接用于监控。
    if BUFF_BY_NAME[name] then return { id = BUFF_BY_NAME[name], source = "known" } end
    for _, record in ipairs(knownBuffs) do
        local id = record.buffID
        local info = SpellInfo(id)
        if info and info.name:lower() == name:lower() then return { id = id, source = "known" } end
    end
    local catalogEntry, catalogError = CatalogName(name)
    if catalogEntry or catalogError then return catalogEntry, catalogError end
    local info = SpellInfo(name)
    if info and info.name:lower() == name:lower() then
        return NameEntry(info.spellID, "spell")
    end
    return cached
end

local function ParseIDs(text, learn, resolvedNames)
    local ids, seen, details, labels = {}, {}, {}, {}
    local hasNames, tentative = false, false
    local missingName = false
    text = text:gsub("，", ","):gsub("；", ","):gsub("、", ",")
    -- 名称允许内部空格；旧版纯数字空格分隔仍兼容。
    local tokens = {}
    for part in text:gmatch("[^,;\r\n]+") do
        local token = part:match("^%s*(.-)%s*$")
        if token:match("^[%d%s]+$") then
            for number in token:gmatch("%d+") do tokens[#tokens + 1] = number end
        elseif token ~= "" then tokens[#tokens + 1] = token end
    end
    if #tokens > 128 then return nil, L["每份列表最多填写 64 个不同 ID。"] end
    for _, token in ipairs(tokens) do
        local id, entry, displayName
        if token:match("^%d+$") then
            id = tonumber(token)
            if not ValidID(id) then return nil, L["ID 必须是有效范围内的正整数。"] end
            displayName = DisplayName(id)
            missingName = missingName or not displayName
        else
            hasNames = true
            local resolveError
            entry, resolveError = ResolveName(token, learn)
            if not entry then
                return nil, resolveError or (CanResolveNames() and (L["未找到："] .. token .. L["；请确认完整 Buff 名称或填写 ID。"])
                    or L["新名称待脱战解析；也可直接填写 Buff ID。"])
            end
            id = entry.id
            displayName = token
            tentative = tentative or entry.source == "spell" or entry.source == "catalog"
            if resolvedNames then resolvedNames[token] = { id = id, source = entry.source } end
        end
        local description
        if entry and entry.source == "catalog" then
            description = token .. L["\n客户端目录候选 ID："] .. id .. L["（无需先触发；实际 Buff 对应需实测）"]
        elseif entry and entry.source == "spell" then
            description = token .. L["\n候选技能 ID："] .. id .. L["（尚未确认同名 Buff ID，需实测）"]
        elseif entry then
            description = token .. L["\n监控 Buff ID："] .. id
            if CAST_BY_BUFF[id] == id then
                description = description .. L["\n施法技能与 Buff 共用此 ID。"]
            elseif CAST_BY_BUFF[id] then
                description = description .. L["\n同名施法技能 ID："] .. CAST_BY_BUFF[id] .. L["（不用于此名称的监控）"]
            end
        else
            description = displayName and (L["已解析 Buff："] .. displayName .. L["\n监控 ID："] .. id)
                or (L["监控 ID："] .. id .. L["\n暂未解析到名称；仍按此 ID 绑定。"])
            if CAST_BY_BUFF[id] == id then
                description = description .. L["\n已核对的 Buff ID；施法技能与 Buff 共用此 ID。"]
            elseif BUFF_BY_CAST[id] then
                tentative = true
                description = description .. L["\n此为施法 ID，对应玩家 Buff ID："] .. BUFF_BY_CAST[id] .. L["；建议改填 Buff ID 或名称。"]
            elseif not KNOWN_BUFF_IDS[id] then
                description = description .. L["\n名称仅供核对，实际 Buff 对应需实测。"]
            end
        end
        details[#details + 1] = description
        if not seen[id] then
            if #ids >= 64 then return nil, L["每份列表最多填写 64 个不同 ID。"] end
            ids[#ids + 1] = id
            labels[#labels + 1] = displayName or ("ID " .. id)
            seen[id] = true
        end
    end
    return ids, nil, seen, { names = hasNames, tentative = tentative, missingName = missingName,
        labels = labels, text = table.concat(details, "\n") }
end

local function GetConfig()
    local draft = GetDraft()
    if not draft then return nil, L["分组版本不兼容或尚未初始化。"] end
    ResetCatalog()
    local config, resolvedNames = {}, {}
    for _, group in ipairs(groups) do
        local result = { all = {} }
        for _, level in ipairs(levels) do
            local ids, errorText, set = ParseIDs(draft.groups[group.key][level.key], true, resolvedNames)
            if not ids then return nil, group.title .. L["："] .. errorText end
            result[level.key] = set
            for _, id in ipairs(ids) do result.all[id] = true end
        end
        config[group.key] = result
    end
    -- 只保留当前有效配置使用的名称，最多六份各128个输入项；不记录 Buff 是否存在。
    draft.nameCache = resolvedNames
    return config
end

local function RefreshGroupStatus(key)
    local groupRows = rows[key]
    local smallIDs, smallError, smallSet, smallDetails = ParseIDs(groupRows.small.input:GetText(), true)
    local largeIDs, largeError, _, largeDetails = ParseIDs(groupRows.large.input:GetText(), true)
    local overlap = false
    if smallIDs and largeIDs then
        for _, id in ipairs(largeIDs) do
            if smallSet[id] then overlap = true; break end
        end
    end
    for _, level in ipairs(levels) do
        local ids, errorText, details
        if level.key == "small" then
            ids, errorText, details = smallIDs, smallError, smallDetails
        else
            ids, errorText, details = largeIDs, largeError, largeDetails
        end
        local label = groupRows[level.key].status
        groupRows[level.key].detail = errorText or (details and details.text)
        if errorText then
            label:SetText(errorText)
            label:SetTextColor(1, 0.5, 0.35)
        elseif overlap then
            label:SetText(L["大小列表有相同 ID，将按大提升显示。"])
            label:SetTextColor(1, 0.75, 0.3)
        elseif #ids == 0 then
            label:SetText(L["未填写"])
            label:SetTextColor(0.6, 0.62, 0.68)
        else
            local summary = #ids == 1 and (L["已绑定："] .. details.labels[1])
                or (L["已绑定 "] .. #ids .. L[" 项 Buff"])
            local uncertain = details.tentative or details.missingName
            if uncertain then
                summary = summary .. (#ids > 1 and L["（含待确认项）"]
                    or (details.missingName and L["（名称待确认）"] or L["（待确认）"]))
            end
            summary = summary:gsub("|", "||")
            label:SetText(summary)
            label:SetTextColor(uncertain and 1 or 0.65, 0.8, 0.6)
        end
    end
end

local panel = CreateFrame("Frame", "P5S_BuffOptionsPanel", UIParent, "BackdropTemplate")
panel:SetSize(WIDTH, HEIGHT)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetToplevel(true)
panel:SetClampedToScreen(true)
panel:Hide()

if not Theme("ApplyOptionsPanel", panel) then
    panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8", tile = true, tileSize = 32, edgeSize = 1 })
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

local function Label(parent, text, x, y, width, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    Theme("StyleBodyText", label)
    return label
end

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("CENTER", panel.TitleBg, "CENTER")
title:SetText(L["攻 · 防 · 速 — 战斗增益设置"])
Theme("StylePanelTitle", title)
local modeLabel = Label(panel, "", 24, -62, 730)

local function ReturnToMain()
    panel:Hide()
    local main = _G.P5S_OptionsPanel
    if main and main:IsShown() then main:Raise()
    elseif SlashCmdList.P5SUI then SlashCmdList.P5SUI() end
end

local notice = Label(panel, L["填写后按回车或点击输入框外即可应用。同类优先显示双箭头大提升。"], 24, -102, 928)
Theme("StyleMutedText", notice)

local dirty = false
local function CommitDraft(force)
    if not dirty and not force then return end
    -- 回车随后也会触发失焦；先清除标记，避免同一次编辑重复应用。
    dirty = false
    if addon.BuffRuntime then
        addon.BuffRuntime.Apply()
        for _, group in ipairs(groups) do RefreshGroupStatus(group.key) end
    end
end

for index, group in ipairs(groups) do
    local card = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    card:SetSize(296, 310)
    card:SetPoint("TOPLEFT", panel, "TOPLEFT", 24 + (index - 1) * 318, -140)
    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("BOTTOMLEFT")
    accent:SetWidth(4)
    local heading = Label(card, group.title, 14, -12, 268, "GameFontNormal")
    if not Theme("StyleSection", card, heading, accent) then
        card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        card:SetBackdropColor(0.035, 0.040, 0.058, 0.72)
        card:SetBackdropBorderColor(0.28, 0.32, 0.40, 0.72)
        accent:SetColorTexture(0.82, 0.07, 0.05, 1)
    end
    local description = Label(card, group.description, 16, -42, 264, "GameFontDisableSmall")
    Theme("StyleMutedText", description)
    rows[group.key] = {}
    for levelIndex, level in ipairs(levels) do
        local key, field = group.key, level.key
        local top = -80 - (levelIndex - 1) * 108
        Label(card, level.title .. " · " .. group.symbol .. level.arrows, 16, top, 264)
        local input = CreateFrame("EditBox", "P5S_Buff_" .. key .. "_" .. field, card, "InputBoxTemplate")
        input:SetSize(258, 30)
        input:SetPoint("TOPLEFT", card, "TOPLEFT", 20, top - 26)
        input:SetAutoFocus(false)
        input:SetMaxLetters(1024)
        local status = Label(card, "", 16, top - 66, 264, "GameFontDisableSmall")
        status:SetHeight(36)
        rows[key][field] = { input = input, status = status }
        input:SetScript("OnTextChanged", function(self, userInput)
            if not userInput then return end
            local draft = GetDraft()
            if not draft then return end
            draft.groups[key][field] = self:GetText()
            dirty = true
            RefreshGroupStatus(key)
        end)
        input:SetScript("OnEnterPressed", function(self) CommitDraft(true); self:ClearFocus() end)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        input:HookScript("OnEditFocusLost", function() CommitDraft() end)
        Theme("StyleEditBox", input)
        input:HookScript("OnEnter", function(self)
            local detail = rows[key][field].detail
            if GameTooltip and detail and detail ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["名称 / ID 解析结果"])
                GameTooltip:AddLine(detail:gsub("|", "||"), 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        input:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
end

local help = Label(panel, L["填写完整 Buff 名称或 ID，多个用逗号分隔。"], 24, -470, 730, "GameFontDisableSmall")
Theme("StyleMutedText", help)

local back = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
back:SetSize(180, 30)
back:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 24)
back:SetText(L["返回 P5S 主界面"])
back:SetScript("OnClick", ReturnToMain)
Theme("StyleButton", back)

panel:HookScript("OnShow", function(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    ResetCatalog()
    self:SetScale(math.min(1, UIParent:GetWidth() / (WIDTH + 40), UIParent:GetHeight() / (HEIGHT + 40)))
    self:Raise()
    local draft = GetDraft()
    modeLabel:SetText(P5S_UI_DB and P5S_UI_DB.indicatorMode == "buff"
        and L["当前用途：自身 Buff 监控"]
        or L["当前用途：进战 / 脱战提示"])
    for _, group in ipairs(groups) do
        for _, level in ipairs(levels) do
            local input = rows[group.key][level.key].input
            input:SetEnabled(draft ~= nil)
            input:SetText(draft and draft.groups[group.key][level.key] or "")
        end
        RefreshGroupStatus(group.key)
    end
    if not draft then
        notice:SetText(L["分组数据暂不可编辑（尚未初始化或版本不兼容）；原有战斗提示不受影响。"])
    else
        notice:SetText(L["填写后按回车或点击输入框外即可应用。同类优先显示双箭头大提升。"])
    end
end)
panel:HookScript("OnHide", function(self)
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    self:StopMovingOrSizing()
    for _, group in ipairs(groups) do
        for _, level in ipairs(levels) do rows[group.key][level.key].input:ClearFocus() end
    end
    CommitDraft()
end)

-- 只检查本页普通输入框的鼠标和键盘焦点，不读取任何 Aura 控件状态。
panel:SetScript("OnEvent", function(_, event)
    if event ~= "GLOBAL_MOUSE_DOWN" then return end
    for _, group in ipairs(groups) do
        for _, level in ipairs(levels) do
            local input = rows[group.key][level.key].input
            if input:HasFocus() and not input:IsMouseOver() then input:ClearFocus() end
        end
    end
end)

addon.BuffOptions = {
    GetConfig = GetConfig,
    RefreshRuntimeStatus = function()
        for _, group in ipairs(groups) do RefreshGroupStatus(group.key) end
    end,
    Open = function() panel:Show(); panel:Raise(); return true end,
}
