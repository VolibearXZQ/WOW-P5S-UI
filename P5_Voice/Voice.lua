-- ==========================================
-- P5S Voice - 技能与双音频配置面板
-- 支持配置、试听，以及基于玩家施法事件 Spell ID 的实际语音触发。
-- ==========================================

local _, addon = ...
local L = (addon and addon.L) or setmetatable({}, { __index = function(_, key) return key end })

local ADDON_NAME = "P5S"
local AUDIO_ROOT_PATH = "Interface\\AddOns\\P5S\\P5_Voice\\"
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local PANEL_BACKGROUND_TEXTURE = "Interface\\DialogFrame\\UI-DialogBox-Background"

local FALLBACK_THEME_COLORS = {
    panelBackground = { 0.035, 0.040, 0.060, 0.96 },
    panelBorder = { 0.24, 0.28, 0.36, 0.95 },
    headerBackground = { 0.055, 0.060, 0.085, 0.98 },
    accent = { 0.82, 0.07, 0.05, 1.00 },
    accentBright = { 1.00, 0.25, 0.20, 1.00 },
    accentSoft = { 0.90, 0.08, 0.06, 0.15 },
    controlBackground = { 0.050, 0.058, 0.080, 0.94 },
    controlBorder = { 0.28, 0.32, 0.40, 0.90 },
    controlHover = { 0.095, 0.105, 0.140, 0.98 },
    text = { 0.94, 0.95, 0.98, 1.00 },
    textDim = { 0.60, 0.62, 0.68, 1.00 },
}

local reportedVoiceThemeErrors = {}

local function ApplyVoicePanelTheme(methodName, ...)
    local panelTheme = addon and addon.PanelTheme
    local method = panelTheme and panelTheme[methodName]
    if type(method) ~= "function" then return false end

    local ok, errorMessage = pcall(method, panelTheme, ...)
    if not ok and not reportedVoiceThemeErrors[methodName] then
        reportedVoiceThemeErrors[methodName] = true
        print(L["|cffFF3333[P5 Voice]|r 设置面板主题应用失败（"] .. methodName .. L["）："] .. tostring(errorMessage))
    end
    return ok
end

local function GetVoiceThemeColors()
    local panelTheme = addon and addon.PanelTheme
    return (panelTheme and panelTheme.COLORS) or FALLBACK_THEME_COLORS
end

local function SetTextureColor(texture, color, alpha)
    if not texture then return end
    texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function EnsureBackdrop(frame)
    if not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
    return frame.SetBackdrop ~= nil
end

local PANEL_BACKDROP = {
    bgFile = PANEL_BACKGROUND_TEXTURE,
    edgeFile = WHITE_TEXTURE,
    tile = true,
    tileSize = 32,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local CONTROL_BACKDROP = {
    bgFile = WHITE_TEXTURE,
    edgeFile = WHITE_TEXTURE,
    edgeSize = 1,
}

local function ApplyVoicePanelFallback(frame)
    local colors = GetVoiceThemeColors()
    if EnsureBackdrop(frame) then
        frame:SetBackdrop(PANEL_BACKDROP)
        frame:SetBackdropColor(
            colors.panelBackground[1],
            colors.panelBackground[2],
            colors.panelBackground[3],
            colors.panelBackground[4]
        )
        frame:SetBackdropBorderColor(
            colors.panelBorder[1],
            colors.panelBorder[2],
            colors.panelBorder[3],
            colors.panelBorder[4]
        )
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:HookScript("OnShow", function(panel)
        panel:Raise()
    end)
end

local function EnsureVoicePanelChrome(frame)
    local colors = GetVoiceThemeColors()
    if not frame.TitleBg then
        frame.TitleBg = frame:CreateTexture(nil, "BACKGROUND")
        frame.TitleBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TitleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.TitleBg:SetHeight(38)
        SetTextureColor(frame.TitleBg, colors.headerBackground)

        local divider = frame:CreateTexture(nil, "BORDER")
        divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -39)
        divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -39)
        divider:SetHeight(1)
        SetTextureColor(divider, colors.accent, 0.68)
        frame.HeaderDivider = divider
    end

    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -7)
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
        end)
    end
end

local function CreateVoiceSettingsSection(parent, x, y, width, height, titleText)
    local colors = GetVoiceThemeColors()
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    section:SetSize(width, height)

    local accent = section:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -10)
    title:SetText(titleText)

    if not ApplyVoicePanelTheme("StyleSection", section, title, accent) then
        section:SetBackdrop(CONTROL_BACKDROP)
        section:SetBackdropColor(0.035, 0.040, 0.058, 0.72)
        section:SetBackdropBorderColor(
            colors.controlBorder[1],
            colors.controlBorder[2],
            colors.controlBorder[3],
            0.72
        )
        SetTextureColor(accent, colors.accent)
        title:SetTextColor(
            colors.accentBright[1],
            colors.accentBright[2],
            colors.accentBright[3],
            colors.accentBright[4]
        )
    end

    section.Title = title
    section.Accent = accent
    return section
end

local function HideButtonTemplateChrome(button)
    if button.NineSlice then button.NineSlice:Hide() end
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local region = button[key]
        if region then
            region:SetAlpha(0)
            region:Hide()
        end
    end

    local normalTexture = button:GetNormalTexture()
    local pushedTexture = button:GetPushedTexture()
    local disabledTexture = button:GetDisabledTexture()
    if normalTexture then normalTexture:SetAlpha(0) end
    if pushedTexture then pushedTexture:SetAlpha(0) end
    if disabledTexture then disabledTexture:SetAlpha(0) end
end

local function UpdateIdentityButtonStyle(button)
    local palette = button._p5VoiceIdentityPalette
    if not palette or not button.SetBackdropColor then return end

    local multiplier = 1.00
    local border = palette.border
    local borderAlpha = 0.78
    if button._p5VoiceIdentityPressed then
        multiplier = 0.82
    elseif button._p5VoiceIdentitySelected then
        multiplier = 1.00
        border = palette.selectedBorder
        borderAlpha = 1.00
    elseif button:IsMouseOver() then
        multiplier = 1.00
        border = palette.selectedBorder
        borderAlpha = 0.95
    end

    button:SetBackdropColor(
        palette.background[1] * multiplier,
        palette.background[2] * multiplier,
        palette.background[3] * multiplier,
        palette.background[4]
    )
    button:SetBackdropBorderColor(border[1], border[2], border[3], borderAlpha)

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetTextColor(palette.text[1], palette.text[2], palette.text[3], palette.text[4])
    end

    if button._p5VoiceIdentityAccent then
        button._p5VoiceIdentityAccent:SetShown(button._p5VoiceIdentitySelected == true)
    end
end

local function StyleIdentityButton(button, palette)
    if not button or button._p5VoiceIdentityStyled then return end
    button._p5VoiceIdentityStyled = true
    button._p5VoiceIdentityPalette = palette

    HideButtonTemplateChrome(button)
    if EnsureBackdrop(button) then button:SetBackdrop(CONTROL_BACKDROP) end

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    highlight:SetColorTexture(1, 1, 1, 0.08)
    button:SetHighlightTexture(highlight)

    local selectedAccent = button:CreateTexture(nil, "OVERLAY")
    selectedAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    selectedAccent:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    selectedAccent:SetHeight(3)
    SetTextureColor(selectedAccent, palette.selectedBorder)
    selectedAccent:Hide()
    button._p5VoiceIdentityAccent = selectedAccent

    button:HookScript("OnEnter", UpdateIdentityButtonStyle)
    button:HookScript("OnLeave", function(self)
        self._p5VoiceIdentityPressed = false
        UpdateIdentityButtonStyle(self)
    end)
    button:HookScript("OnMouseDown", function(self)
        self._p5VoiceIdentityPressed = true
        UpdateIdentityButtonStyle(self)
    end)
    button:HookScript("OnMouseUp", function(self)
        self._p5VoiceIdentityPressed = false
        UpdateIdentityButtonStyle(self)
    end)
    button:HookScript("OnShow", UpdateIdentityButtonStyle)
    UpdateIdentityButtonStyle(button)
end

local function ApplyVoiceLocalStyle(styleName, styleFunction, ...)
    local ok, errorMessage = pcall(styleFunction, ...)
    if not ok and not reportedVoiceThemeErrors[styleName] then
        reportedVoiceThemeErrors[styleName] = true
        print(L["|cffFF3333[P5 Voice]|r 设置面板局部样式加载失败（"] .. styleName .. L["）："] .. tostring(errorMessage))
    end
    return ok
end

local AUDIO_SOURCES = P5S_VOICE_AUDIO_SOURCES or {
    {
        key = "joker",
        label = L["P5 雨宫莲语音"],
        shortLabel = "Joker",
        directory = "音频",
        files = P5S_VOICE_AUDIO_FILES or {},
        useLegacyFileName = true,
    },
}

local audioItems = {}
local audioItemsByID = {}
local audioSourcesByKey = {}
for _, source in ipairs(AUDIO_SOURCES) do
    audioSourcesByKey[source.key] = source
    for _, fileName in ipairs(source.files or {}) do
        -- 改名音频沿用旧标识；英文名仅用于显示，分类与播放仍使用实际文件名。
        local savedFileName = source.legacyFileNames and source.legacyFileNames[fileName] or fileName
        local audioID = source.useLegacyFileName and savedFileName or (source.directory .. "\\" .. savedFileName)
        local englishName = addon and addon.IsEnglish and source.englishNames and source.englishNames[fileName]
        local item = {
            id = audioID,
            fileName = fileName,
            displayName = type(englishName) == "string" and englishName ~= "" and englishName or fileName,
            sourceKey = source.key,
            -- 共用一个目录项和保存标识，跨角色切换不会重复加入随机池。
            shared = source.key == "makoto" and (string.find(fileName, "胜利_", 1, true) == 1
                or string.find(fileName, "死亡&复活", 1, true) == 1),
            relativePath = source.directory .. "\\" .. fileName,
        }
        table.insert(audioItems, item)
        audioItemsByID[audioID] = item
    end
end

local sectionDefinitions = {
    { key = "skill",         title = L["技能释放语音"], count = 20, lineColor = { 0.90, 0.12, 0.12, 0.80 } },
    { key = "cooldownReady", title = L["技能冷却完毕语音"], count = 20, lineColor = { 0.15, 0.65, 1.00, 0.80 } },
    { key = "healing",       title = L["治疗语音"], count = 20, lineColor = { 0.15, 0.85, 0.30, 0.80 } },
    { key = "burst",         title = L["爆发语音"], count = 20, lineColor = { 0.65, 0.25, 1.00, 0.80 } },
    -- 胜利页使用独立语音池，不创建技能行，也不加入施法触发映射。
    { key = "victory",       title = L["胜利语音"], count = 0, lineColor = { 1.00, 0.72, 0.15, 0.80 } },
    { key = "characterEvents", title = L["角色事件语音"], count = 0, lineColor = { 0.10, 0.85, 0.80, 0.80 } },
}

local characterEventDefinitions = {
    { key = "death", title = L["死亡语音"], help = L["真正死亡时播放；假死不触发。"] },
    { key = "resurrection", title = L["复活语音"], help = L["恢复存活后播放；释放灵魂、收到复活邀请时不播放。"] },
    { key = "levelUp", title = L["升级语音"], help = L["玩家升级时播放；同一次升级只触发一次。"] },
    { key = "specialization", title = L["切换专精"], help = L["实际切换专精后播放；同一专精内更换天赋方案不触发。"] },
}

local victoryEnemyOptions = {
    { key = "normal",      label = L["普通小怪"],          default = false },
    { key = "elite",       label = L["精英小怪"],          default = false },
    { key = "rare",        label = L["稀有 / 稀有精英"],   default = false },
    { key = "dungeonBoss", label = L["地下城 Boss"],       default = true },
    { key = "raidBoss",    label = L["团队副本 Boss"],     default = true },
    { key = "worldBoss",   label = L["世界 Boss"],         default = false },
}

local voiceInputs = {
    skill = {},
    cooldownReady = {},
    healing = {},
    burst = {},
    victory = {},
    characterEvents = {},
}

local voiceRows = {
    skill = {},
    cooldownReady = {},
    healing = {},
    burst = {},
    victory = {},
    characterEvents = {},
}

local channelOptions = {
    { label = L["主音量"], value = "Master" },
    { label = L["音乐"],   value = "Music" },
    { label = L["效果"],   value = "SFX" },
    { label = L["环境音"], value = "Ambience" },
    { label = L["对话"],   value = "Dialog" },
}

local validChannels = {}
local channelLabels = {}
for _, option in ipairs(channelOptions) do
    validChannels[option.value] = true
    channelLabels[option.value] = option.label
end

local spellNameToID = {}
local voiceTriggerMap = {}
local cooldownReadyTriggerMap = {}
local cooldownWatchers = {}
local spellBookCacheBuilt = false
local pendingSpellBookCacheRebuild = false
local activeVoiceInput = nil
local spellLinkHookInstalled = false
local PruneCooldownWatchers

local function TrimText(text)
    text = tostring(text or "")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function NormalizeSpellInputSeparators(text)
    text = tostring(text or "")
    -- Lua 5.1 pattern 按字节处理；先转换中文标点，再只按 ASCII 分隔。
    text = text:gsub("，", ",")
    text = text:gsub("；", ";")
    text = text:gsub("、", ",")
    return text
end

local function AddSpellNameToCache(cache, spellID, spellName)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return end

    spellName = TrimText(spellName)
    if spellName == "" and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.name then
            spellName = TrimText(info.name)
        end
    end

    if spellName ~= "" and cache[spellName] == nil then
        cache[spellName] = math.floor(spellID)
    end
end

local function RebuildSpellBookNameCache()
    -- 技能名称解析不在战斗中扫描技能书；纯 Spell ID 始终可以直接保存。
    if InCombatLockdown and InCombatLockdown() then
        pendingSpellBookCacheRebuild = true
        return
    end

    local cache = {}

    if C_SpellBook
        and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo then

        local bankList = {}
        if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
            table.insert(bankList, Enum.SpellBookSpellBank.Player)
        else
            table.insert(bankList, "spell")
        end

        local okLines, numSkillLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        if okLines and type(numSkillLines) == "number" then
            for lineIndex = 1, numSkillLines do
                local okLine, lineInfoOrName, _, itemIndexOffset, numSpellBookItems =
                    pcall(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)

                local offset, count
                if okLine then
                    if type(lineInfoOrName) == "table" then
                        offset = lineInfoOrName.itemIndexOffset
                            or lineInfoOrName.spellBookItemOffset
                            or lineInfoOrName.offset
                        count = lineInfoOrName.numSpellBookItems
                            or lineInfoOrName.numSlots
                            or lineInfoOrName.numItems
                    else
                        offset = itemIndexOffset
                        count = numSpellBookItems
                    end
                end

                if type(offset) == "number" and type(count) == "number" and count > 0 then
                    for slot = offset + 1, offset + count do
                        for _, bank in ipairs(bankList) do
                            local okItem, itemInfo = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                            if okItem and type(itemInfo) == "table" then
                                local spellID = itemInfo.spellID
                                    or itemInfo.actionID
                                    or itemInfo.spellIDOfOverriddenSpell
                                AddSpellNameToCache(cache, spellID, itemInfo.name)
                            end
                        end
                    end
                end
            end
        end
    end

    -- 旧技能书接口兜底；正式服不存在这些函数时会直接跳过。
    if type(GetNumSpellTabs) == "function"
        and type(GetSpellTabInfo) == "function"
        and type(GetSpellBookItemInfo) == "function" then

        local okTabs, numTabs = pcall(GetNumSpellTabs)
        if okTabs and type(numTabs) == "number" then
            for tabIndex = 1, numTabs do
                local okTab, _, _, offset, numSlots = pcall(GetSpellTabInfo, tabIndex)
                if okTab and type(offset) == "number" and type(numSlots) == "number" then
                    for slot = offset + 1, offset + numSlots do
                        local spellName
                        if type(GetSpellBookItemName) == "function" then
                            local okName, name = pcall(GetSpellBookItemName, slot, BOOKTYPE_SPELL or "spell")
                            if okName then spellName = name end
                        end

                        local okItem, _, spellID = pcall(GetSpellBookItemInfo, slot, BOOKTYPE_SPELL or "spell")
                        if okItem then
                            AddSpellNameToCache(cache, spellID, spellName)
                        end
                    end
                end
            end
        end
    end

    spellNameToID = cache
    spellBookCacheBuilt = true
    pendingSpellBookCacheRebuild = false
end

local function ResolveSpellInput(text)
    text = TrimText(text)
    if text == "" then return nil, nil end

    local linkedSpellID = text:match("spell:(%d+)")
    if linkedSpellID then
        local spellID = tonumber(linkedSpellID)
        local spellName
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(info) == "table" then spellName = info.name end
        end
        return spellID, spellName
    end

    local numericID = tonumber(text)
    if numericID and numericID > 0 then
        numericID = math.floor(numericID)
        local spellName
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, numericID)
            if ok and type(info) == "table" then spellName = info.name end
        end
        return numericID, spellName
    end

    local cachedSpellID = spellNameToID[text]
    if cachedSpellID then return cachedSpellID, text end

    if InCombatLockdown and InCombatLockdown() then
        return nil, nil
    end

    if not spellBookCacheBuilt then
        RebuildSpellBookNameCache()
    end

    cachedSpellID = spellNameToID[text]
    if cachedSpellID then return cachedSpellID, text end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, text)
        if ok and type(info) == "table" and info.spellID then
            return info.spellID, info.name
        end
    end

    if type(GetSpellInfo) == "function" then
        local ok, name, _, _, _, _, _, spellID = pcall(GetSpellInfo, text)
        if ok and spellID then return spellID, name end
    end

    return nil, nil
end

local function BuildSpellIDMap(inputText)
    local map = {}
    local validList = {}
    local invalidList = {}

    inputText = NormalizeSpellInputSeparators(inputText)
    for token in inputText:gmatch("[^,;]+") do
        token = TrimText(token)
        if token ~= "" then
            local spellID, spellName = ResolveSpellInput(token)
            spellID = tonumber(spellID)
            if spellID and spellID > 0 then
                spellID = math.floor(spellID)
                if not map[spellID] then
                    map[spellID] = true
                    if spellName and spellName ~= "" then
                        table.insert(validList, spellName .. "(" .. tostring(spellID) .. ")")
                    else
                        table.insert(validList, tostring(spellID))
                    end
                end
            else
                table.insert(invalidList, token)
            end
        end
    end

    return map, validList, invalidList
end

local function JoinList(list)
    if not list or #list == 0 then return L["无"] end
    return table.concat(list, ", ")
end

local function GetSortedSpellIDs(entry)
    local ids = {}
    if entry and type(entry.spellIDs) == "table" then
        for spellID, enabled in pairs(entry.spellIDs) do
            spellID = tonumber(spellID)
            if enabled and spellID then table.insert(ids, math.floor(spellID)) end
        end
    end
    table.sort(ids)
    return ids
end

local function NormalizeMainAudioChoices(entry)
    if type(entry) ~= "table" then return {} end
    if type(entry.audio1Choices) == "table" and entry.audio1 == entry.audio1Choices[1] then
        return entry.audio1Choices
    end

    local normalized = {}
    local seen = {}
    local function AddChoice(audioID)
        if type(audioID) ~= "string" or audioID == "" or seen[audioID] then return end
        seen[audioID] = true
        table.insert(normalized, audioID)
    end

    -- audio1 继续保留为第一条主音频，兼容旧 SavedVariables 与旧版本插件。
    AddChoice(entry.audio1)
    if type(entry.audio1Choices) == "table" then
        for _, audioID in ipairs(entry.audio1Choices) do
            AddChoice(audioID)
        end
    end

    entry.audio1Choices = normalized
    entry.audio1 = normalized[1]
    return normalized
end

local function GetMainAudioChoices(entry)
    if type(entry) ~= "table" or type(entry.audio1Choices) ~= "table" then return {} end
    return entry.audio1Choices
end

local function GetMainAudioChoiceMap(entry)
    local choiceMap = {}
    local choices = GetMainAudioChoices(entry)
    for _, audioID in ipairs(choices) do
        choiceMap[audioID] = true
    end
    return choiceMap, #choices
end

local function SetMainAudioChoiceSelected(entry, audioID, selected)
    local choices = NormalizeMainAudioChoices(entry)
    local updated = {}
    local found = false

    for _, choiceID in ipairs(choices) do
        if choiceID == audioID then
            found = true
            if selected then table.insert(updated, choiceID) end
        else
            table.insert(updated, choiceID)
        end
    end
    if selected and not found and type(audioID) == "string" and audioID ~= "" then
        table.insert(updated, audioID)
    end

    entry.audio1Choices = updated
    entry.audio1 = updated[1]
    return #updated
end

local function ClearMainAudioChoices(entry)
    if type(entry) ~= "table" then return end
    entry.audio1Choices = {}
    entry.audio1 = nil
end

local function GetRandomMainAudioID(entry)
    local choices = GetMainAudioChoices(entry)
    local playableCount = 0
    for _, audioID in ipairs(choices) do
        if audioItemsByID[audioID] then
            playableCount = playableCount + 1
        end
    end
    if playableCount == 0 then return nil end

    local targetIndex = math.random(playableCount)
    for _, audioID in ipairs(choices) do
        if audioItemsByID[audioID] then
            targetIndex = targetIndex - 1
            if targetIndex == 0 then return audioID end
        end
    end
end

local EnsureVoiceProfiles, RefreshVoiceProfiles

local function NormalizeCharacterEventSettings(settings)
    if type(settings) ~= "table" then settings = {} end
    for _, definition in ipairs(characterEventDefinitions) do
        local entry = settings[definition.key]
        if type(entry) ~= "table" then entry = {}; settings[definition.key] = entry end
        if type(entry.enabled) ~= "boolean" then entry.enabled = false end
        if type(entry.mainAudio) ~= "table" then entry.mainAudio = { audio1Choices = {} } end
        NormalizeMainAudioChoices(entry.mainAudio)
    end
    return settings
end

local function EnsureDatabase()
    if type(P5S_Voice_DB) ~= "table" then
        P5S_Voice_DB = {}
    end
    if type(P5S_Voice_DB.inputs) ~= "table" then
        P5S_Voice_DB.inputs = {}
    end
    if not validChannels[P5S_Voice_DB.channel] then
        P5S_Voice_DB.channel = "Master"
    end

    -- 胜利设置独立保存，不影响其他四组技能语音。
    if type(P5S_Voice_DB.victorySettings) ~= "table" then
        P5S_Voice_DB.victorySettings = {}
    end
    local victorySettings = P5S_Voice_DB.victorySettings
    if type(victorySettings.enemyTypes) ~= "table" then
        victorySettings.enemyTypes = {}
    end
    for _, option in ipairs(victoryEnemyOptions) do
        if type(victorySettings.enemyTypes[option.key]) ~= "boolean" then
            victorySettings.enemyTypes[option.key] = option.default
        end
    end
    if type(victorySettings.antiSpamEnabled) ~= "boolean" then
        victorySettings.antiSpamEnabled = true
    end
    if type(victorySettings.enabled) ~= "boolean" then
        victorySettings.enabled = false
    end

    -- 仅首次创建语音池时汇总旧胜利行；保留旧行，清空新池后不会再次导入。
    if type(victorySettings.mainAudio) ~= "table" then
        victorySettings.mainAudio = { audio1Choices = {} }
        local legacyRows = P5S_Voice_DB.inputs.victory
        if type(legacyRows) == "table" then
            for index = 1, 20 do
                local legacy = legacyRows[index]
                if type(legacy) == "table" then
                    local copy = { audio1 = legacy.audio1, audio1Choices = legacy.audio1Choices }
                    for _, audioID in ipairs(NormalizeMainAudioChoices(copy)) do
                        SetMainAudioChoiceSelected(victorySettings.mainAudio, audioID, true)
                    end
                end
            end
        end
    end
    NormalizeMainAudioChoices(victorySettings.mainAudio)
    P5S_Voice_DB.characterEvents = NormalizeCharacterEventSettings(P5S_Voice_DB.characterEvents)

    for _, definition in ipairs(sectionDefinitions) do
        local section = P5S_Voice_DB.inputs[definition.key]
        if type(section) ~= "table" then
            section = {}
            P5S_Voice_DB.inputs[definition.key] = section
        end

        for index = 1, definition.count do
            if type(section[index]) ~= "table" then
                section[index] = {
                    input = "",
                    spellID = nil,
                    spellName = nil,
                    spellIDs = {},
                    audio1 = nil,
                    audio1Choices = {},
                    audio2 = nil,
                }
            end

            local entry = section[index]
            if type(entry.spellIDs) ~= "table" then
                entry.spellIDs = {}
                local legacySpellID = tonumber(entry.spellID)
                if legacySpellID and legacySpellID > 0 then
                    entry.spellIDs[math.floor(legacySpellID)] = true
                end
            end
            NormalizeMainAudioChoices(entry)
        end
    end
    if EnsureVoiceProfiles then EnsureVoiceProfiles() end
end

local function GetVoiceAudioEntry(sectionKey, index)
    if not P5S_Voice_DB then return nil end
    if sectionKey == "victory" then
        local settings = P5S_Voice_DB.victorySettings
        return settings and settings.mainAudio
    end
    if sectionKey == "characterEvents" then
        local settings = P5S_Voice_DB.characterEvents
        return settings and settings[index] and settings[index].mainAudio
    end
    local section = P5S_Voice_DB.inputs and P5S_Voice_DB.inputs[sectionKey]
    return section and section[index]
end

local function SetEntrySpellMap(entry, map)
    entry.spellIDs = map or {}
    entry.spellID = nil
    entry.spellName = nil

    local ids = GetSortedSpellIDs(entry)
    if ids[1] then entry.spellID = ids[1] end
end

local function RebuildVoiceTriggerMap()
    EnsureDatabase()
    local newVoiceMap = {}
    local newCooldownReadyMap = {}

    for _, definition in ipairs(sectionDefinitions) do
        local targetMap = definition.key == "cooldownReady" and newCooldownReadyMap or newVoiceMap
        for index = 1, definition.count do
            local entry = P5S_Voice_DB.inputs[definition.key][index]
            for _, spellID in ipairs(GetSortedSpellIDs(entry)) do
                if not targetMap[spellID] then targetMap[spellID] = {} end
                table.insert(targetMap[spellID], {
                    sectionKey = definition.key,
                    index = index,
                })
            end
        end
    end

    voiceTriggerMap = newVoiceMap
    cooldownReadyTriggerMap = newCooldownReadyMap
    if PruneCooldownWatchers then PruneCooldownWatchers() end
end

local function ReparseStoredSpellInputs()
    if InCombatLockdown and InCombatLockdown() then return end
    EnsureDatabase()

    for _, definition in ipairs(sectionDefinitions) do
        for index = 1, definition.count do
            local entry = P5S_Voice_DB.inputs[definition.key][index]
            local inputText = TrimText(entry.input)
            if inputText == "" then
                SetEntrySpellMap(entry, {})
            else
                local map = BuildSpellIDMap(inputText)
                -- 技能书临时不可用时保留上一次成功解析结果，避免无意清空触发。
                if next(map) ~= nil then SetEntrySpellMap(entry, map) end
            end
        end
    end

    RebuildVoiceTriggerMap()
end

local RefreshVoiceInputs
local AudioPicker

local VoicePanel = CreateFrame("Frame", "P5VoiceConfigPanel", UIParent, "BackdropTemplate")
VoicePanel:SetSize(1120, 820)
VoicePanel:SetPoint("CENTER")
VoicePanel:SetClampedToScreen(true)
VoicePanel:SetMovable(true)
VoicePanel:EnableMouse(true)
VoicePanel:RegisterForDrag("LeftButton")
VoicePanel:SetScript("OnDragStart", VoicePanel.StartMoving)
VoicePanel:SetScript("OnDragStop", VoicePanel.StopMovingOrSizing)
VoicePanel:Hide()

-- 优先注册命令，任何主题或控件样式错误都不能让 /p5voice 消失。
SLASH_P5VOICE1 = "/p5voice"
SlashCmdList["P5VOICE"] = function()
    if VoicePanel:IsShown() then
        VoicePanel:Hide()
        if AudioPicker then AudioPicker:Hide() end
    else
        if RefreshVoiceInputs then RefreshVoiceInputs() end
        VoicePanel:Show()
    end
end

if not ApplyVoicePanelTheme("ApplyOptionsPanel", VoicePanel) then
    ApplyVoicePanelFallback(VoicePanel)
end
EnsureVoicePanelChrome(VoicePanel)

VoicePanel.title = VoicePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
VoicePanel.title:SetPoint("CENTER", VoicePanel.TitleBg, "CENTER", 0, 0)
VoicePanel.title:SetText(L["P5S 技能语音设置"])
ApplyVoicePanelTheme("StylePanelTitle", VoicePanel.title)
ApplyVoicePanelTheme("StyleCloseButton", VoicePanel.CloseButton)

local backToMainButton = CreateFrame("Button", "P5VoiceBackToMainButton", VoicePanel, "UIPanelButtonTemplate")
backToMainButton:SetSize(156, 26)
backToMainButton:SetPoint("BOTTOMRIGHT", VoicePanel, "BOTTOMRIGHT", -34, 17)
backToMainButton:SetText(L["返回P5S主界面"])
backToMainButton:SetScript("OnClick", function()
    VoicePanel:Hide()
    if AudioPicker then AudioPicker:Hide() end

    local mainPanel = _G.P5S_OptionsPanel
    if mainPanel and mainPanel:IsShown() then
        if mainPanel.Raise then mainPanel:Raise() end
        return
    end

    local commandHandler = SlashCmdList and SlashCmdList["P5SUI"]
    if type(commandHandler) ~= "function" then
        print(L["|cffFF3333[P5 Voice]|r P5S 主界面设置暂时不可用。"])
        return
    end
    commandHandler("")
end)
ApplyVoicePanelTheme("StyleButton", backToMainButton)

local infoSection = CreateVoiceSettingsSection(VoicePanel, 24, -56, 1062, 86, L["使用说明"])

local description = infoSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
description:SetPoint("TOPLEFT", infoSection, "TOPLEFT", 18, -36)
description:SetWidth(740)
description:SetJustifyH("LEFT")
description:SetText(L["每行可用逗号分隔多个技能名称 / Spell ID；按回车或点击其他位置会自动保存。"])
ApplyVoicePanelTheme("StyleBodyText", description)

local cooldownDescription = infoSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
cooldownDescription:SetPoint("TOPLEFT", infoSection, "TOPLEFT", 18, -58)
cooldownDescription:SetWidth(740)
cooldownDescription:SetJustifyH("LEFT")
cooldownDescription:SetText(L["技能冷却完毕语音监测普通与充能技能；充能每恢复一层播放一次，并忽略公共冷却。"])
ApplyVoicePanelTheme("StyleMutedText", cooldownDescription)

local statusAccent = VoicePanel:CreateTexture(nil, "ARTWORK")
statusAccent:SetPoint("BOTTOMLEFT", VoicePanel, "BOTTOMLEFT", 25, 21)
statusAccent:SetSize(4, 16)

local statusText = VoicePanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statusText:SetPoint("BOTTOMLEFT", VoicePanel, "BOTTOMLEFT", 38, 23)
statusText:SetWidth(880)
statusText:SetJustifyH("LEFT")
statusText:SetText(L["施法与技能冷却完毕语音已启用；触发入口只使用玩家施法事件提供的 Spell ID。"])

local function SetStatus(message, isWarning)
    statusText:SetText(message)
    if isWarning then
        statusText:SetTextColor(1, 0.75, 0.2)
        statusAccent:SetColorTexture(1, 0.58, 0.12, 0.95)
    else
        statusText:SetTextColor(0.4, 1, 0.6)
        statusAccent:SetColorTexture(0.25, 0.88, 0.48, 0.95)
    end
    if RefreshVoiceProfiles then RefreshVoiceProfiles() end
end

SetStatus(L["施法与技能冷却完毕语音已启用；触发入口只使用玩家施法事件提供的 Spell ID。"], false)

local function GetAudioDisplayName(audioID)
    local item = audioItemsByID[audioID]
    if not item then return tostring(audioID or "") end

    local source = audioSourcesByKey[item.sourceKey]
    local sourceLabel = item.shared and L["通用"] or (source and source.shortLabel or item.sourceKey)
    return sourceLabel .. L["｜"] .. item.displayName
end

-- 只记录手动试听的句柄；自动触发语音不随设置窗口关闭而停止。
local previewSoundHandles = {}
local function StopAudioPreview()
    local handles = previewSoundHandles
    previewSoundHandles = {}
    if type(StopSound) ~= "function" then return end
    for _, soundHandle in ipairs(handles) do
        pcall(StopSound, soundHandle, 0)
    end
end

local function PlayAudioFile(audioID, quiet, isPreview)
    EnsureDatabase()
    if not audioID or audioID == "" then return false end

    local item = audioItemsByID[audioID]
    if not item then
        if not quiet then SetStatus(L["找不到音频目录项："] .. tostring(audioID), true) end
        return false
    end
    if type(PlaySoundFile) ~= "function" then
        if not quiet then SetStatus(L["当前环境没有可用的音频播放接口。"], true) end
        return false
    end

    local ok, willPlay, soundHandle = pcall(PlaySoundFile, AUDIO_ROOT_PATH .. item.relativePath, P5S_Voice_DB.channel)
    if not ok or willPlay == false then
        if not quiet then SetStatus(L["音频播放失败："] .. GetAudioDisplayName(audioID), true) end
        return false
    end

    if isPreview and type(soundHandle) == "number" then
        previewSoundHandles[#previewSoundHandles + 1] = soundHandle
    end
    if not quiet then
        SetStatus(L["正在试听："] .. GetAudioDisplayName(audioID) .. L["（"] .. channelLabels[P5S_Voice_DB.channel] .. L["）"], false)
    end
    return true
end

local function PlayConfiguredEntry(sectionKey, index, isPreview)
    if isPreview then StopAudioPreview() end
    local entry = GetVoiceAudioEntry(sectionKey, index)
    if not entry then return false end

    local played = false
    local mainAudioID = GetRandomMainAudioID(entry)
    if mainAudioID then
        played = PlayAudioFile(mainAudioID, true, isPreview) or played
    end
    if sectionKey ~= "victory" and sectionKey ~= "characterEvents" and entry.audio2 and entry.audio2 ~= mainAudioID then
        played = PlayAudioFile(entry.audio2, true, isPreview) or played
    end
    return played, mainAudioID
end

local ResetVictoryPlayback
do
    local MIN_COMBAT_SECONDS, SETTLE_SECONDS, REPLAY_SECONDS = 10, 2, 60
    local MAX_TRACKED_UNITS = 128
    local session, pending, lastPlayedAt
    local unitTrackingAvailable = true
    local classificationKeys = {
        normal = "normal", minus = "normal", trivial = "normal",
        elite = "elite", rare = "rare", rareelite = "rare", worldboss = "worldBoss",
    }

    -- 先排除 Secret Value，再做类型检查、比较、字符串处理或表索引。
    local function IsPlain(value, expectedType)
        if type(issecretvalue) ~= "function" then return false end
        local ok, secret = pcall(issecretvalue, value)
        return ok and not secret and type(value) == expectedType
    end

    local function Read(api, expectedType, ...)
        if type(api) ~= "function" then return nil end
        local ok, value = pcall(api, ...)
        if ok and IsPlain(value, expectedType) then return value end
    end

    local function Settings()
        return P5S_Voice_DB and P5S_Voice_DB.victorySettings
    end

    local function PlayerAlive()
        return Read(UnitIsDeadOrGhost, "boolean", "player") == false
            and Read(UnitIsFeignDeath, "boolean", "player") == false
    end

    local function InstanceType()
        if type(IsInInstance) ~= "function" then return nil end
        local ok, _, instanceType = pcall(IsInInstance)
        if ok and IsPlain(instanceType, "string") then return instanceType end
    end

    local function CancelPending()
        local job = pending
        pending = nil
        if job and job.timer and job.timer.Cancel then job.timer:Cancel() end
    end

    ResetVictoryPlayback = function()
        CancelPending()
        session = nil
    end

    local function NewSession(now)
        return { startedAt = now, instanceType = InstanceType(), units = {}, unitCount = 0, kills = {} }
    end

    local function WantsUnitTracking()
        local settings = Settings()
        local types = settings and settings.enemyTypes
        return types and (types.normal or types.elite or types.rare or types.worldBoss)
    end

    local function MarkDead(guid)
        if not session or session.bossSeen or not IsPlain(guid, "string") then return end
        local record = session.units[guid]
        if record and not record.dead then
            record.dead = true
            session.kills[record.key] = true
        end
    end

    local function ObserveUnit(unit)
        local current = session
        if not unitTrackingAvailable or not current or not current.inCombat or current.bossSeen or not WantsUnitTracking() then return end
        if current.instanceType ~= "none" and current.instanceType ~= "party" and current.instanceType ~= "raid" then return end
        if not IsPlain(unit, "string") or (unit ~= "target" and not unit:match("^nameplate%d+$")) then return end
        local guid = Read(UnitGUID, "string", unit)
        if not guid then return end
        local dead = Read(UnitIsDead, "boolean", unit)
        if dead == true then MarkDead(guid); return end
        if dead ~= false or current.units[guid] then return end
        if Read(UnitCanAttack, "boolean", "player", unit) ~= true
            or Read(UnitPlayerControlled, "boolean", unit) ~= false
            or Read(UnitAffectingCombat, "boolean", unit) ~= true then return end

        -- 只记录确有玩家/宠物仇恨关系的敌人；受限状态不参与运算。
        local threat = Read(UnitThreatSituation, "number", "player", unit)
        if not threat then threat = Read(UnitThreatSituation, "number", "pet", unit) end
        if not threat or threat < 0 then return end
        local classification = Read(UnitClassification, "string", unit)
        local key = classification and classificationKeys[classification]
        if not key then return end
        if key == "worldBoss" and current.instanceType ~= "none" then
            current.bossSeen = true -- 副本首领不降级成小怪击杀。
            return
        end
        if current.unitCount >= MAX_TRACKED_UNITS then
            current.incomplete = true
            return
        end
        current.units[guid] = { key = key }
        current.unitCount = current.unitCount + 1
    end

    local function ObserveVisibleUnits()
        ObserveUnit("target")
        if WantsUnitTracking() then
            for index = 1, 40 do ObserveUnit("nameplate" .. index) end
        end
    end

    local function SelectedResult(current, settings)
        if current.bossSeen then
            local result = current.result
            if result and settings.enemyTypes[result.key] then return result.duration end
            return nil
        end
        if current.incomplete or current.unitCount == 0 then return nil end
        -- 已观察到的敌人必须全部确认死亡，避免杀一只后逃跑也庆祝。
        for _, record in pairs(current.units) do
            if not record.dead then return nil end
        end
        for key in pairs(current.kills) do
            if settings.enemyTypes[key] then return current.outAt - current.startedAt end
        end
    end

    local function Finish(current)
        if session ~= current then return end
        local settings = Settings()
        local now = Read(GetTime, "number")
        local duration = settings and SelectedResult(current, settings)
        local allowed = settings and settings.enabled and now and duration and current.instanceType
            and current.participated and not current.encounter
            and PlayerAlive() and Read(UnitAffectingCombat, "boolean", "player") == false
            and InstanceType() == current.instanceType
        if allowed and settings.antiSpamEnabled then
            allowed = duration >= MIN_COMBAT_SECONDS and now - current.outAt >= SETTLE_SECONDS
                and (not lastPlayedAt or now - lastPlayedAt >= REPLAY_SECONDS)
        end
        ResetVictoryPlayback() -- 消费本场结果；失败、受限或被限频都不补播。
        if allowed then
            local audioID = GetRandomMainAudioID(settings.mainAudio)
            if audioID and PlayAudioFile(audioID, true) then lastPlayedAt = now end
        end
    end

    local function ScheduleFinish()
        local current = session
        if not current or not current.outAt or current.encounter or pending then return end
        if not PlayerAlive() then ResetVictoryPlayback(); return end
        local settings = Settings()
        local now = Read(GetTime, "number")
        if not settings or not now or not C_Timer or type(C_Timer.NewTimer) ~= "function" then
            ResetVictoryPlayback()
            return
        end
        -- 关闭保护也延至下一次计时回调，容纳同一批次的死亡/失败事件。
        local delay = settings.antiSpamEnabled and math.max(0.05, SETTLE_SECONDS - (now - current.outAt)) or 0.05
        local job = { session = current }
        pending = job
        local ok, timer = pcall(C_Timer.NewTimer, delay, function()
            if pending ~= job then return end
            pending = nil
            Finish(current)
        end)
        if ok then job.timer = timer else ResetVictoryPlayback() end
    end

    local function BeginCombat()
        CancelPending()
        local now = Read(GetTime, "number")
        if not now or not PlayerAlive() then ResetVictoryPlayback(); return end
        if not session or not session.encounter then session = NewSession(now) end
        session.inCombat = true
        session.participated = true
        session.outAt = nil
        ObserveVisibleUnits()
    end

    local function EndCombat()
        if not session or session.outAt then return end
        local now = Read(GetTime, "number")
        if not now then ResetVictoryPlayback(); return end
        ObserveVisibleUnits()
        session.inCombat = false
        session.outAt = now
        if not PlayerAlive() then
            CancelPending()
            if not session.encounter then session = nil end
            return
        end
        ScheduleFinish()
    end

    local function EncounterStart(encounterID)
        if not IsPlain(encounterID, "number") then ResetVictoryPlayback(); return end
        local now = Read(GetTime, "number")
        if not now then ResetVictoryPlayback(); return end
        CancelPending()
        if not session or session.outAt then session = NewSession(now) end
        local current = session
        if current.encounter and current.encounter.id == encounterID then return end
        current.bossSeen = true
        current.result = nil
        current.encounter = { id = encounterID, startedAt = now }
        if Read(UnitAffectingCombat, "boolean", "player") == true and PlayerAlive() then
            current.inCombat = true
            current.participated = true
        end
    end

    local function EncounterEnd(encounterID, success)
        if not IsPlain(encounterID, "number") or not IsPlain(success, "number") then
            ResetVictoryPlayback()
            return
        end
        local current = session
        local encounter = current and current.encounter
        if not encounter or encounter.id ~= encounterID then return end
        current.encounter = nil
        local now = Read(GetTime, "number")
        if success ~= 1 or not now or not PlayerAlive() then
            ResetVictoryPlayback()
            return
        end
        local instanceType = current.instanceType
        local key = instanceType == "party" and "dungeonBoss"
            or (instanceType == "raid" and "raidBoss" or (instanceType == "none" and "worldBoss"))
        if not key then ResetVictoryPlayback(); return end
        current.result = { key = key, duration = now - encounter.startedAt }
        if Read(UnitAffectingCombat, "boolean", "player") == true then
            current.inCombat = true
            current.outAt = nil
        end
        ScheduleFinish() -- 兼容先脱战或先收到首领结果的两种事件顺序。
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEAVING_WORLD" then
            ResetVictoryPlayback()
            return
        end
        local settings = Settings()
        if not settings or not settings.enabled then ResetVictoryPlayback(); return end
        if event == "PLAYER_DEAD" then
            CancelPending()
            -- 保留仍在进行的首领遭遇，允许战复后活着完成击杀。
            if not session or not session.encounter then session = nil end
        elseif event == "PLAYER_REGEN_DISABLED" then
            BeginCombat()
        elseif event == "PLAYER_REGEN_ENABLED" then
            EndCombat()
        elseif event == "ENCOUNTER_START" then
            EncounterStart(...)
        elseif event == "ENCOUNTER_END" then
            local encounterID, _, _, _, success = ...
            EncounterEnd(encounterID, success)
        elseif event == "UNIT_DIED" then
            MarkDead(...)
        elseif event == "PLAYER_TARGET_CHANGED" then
            ObserveUnit("target")
        else
            ObserveUnit(...)
        end
    end)
    -- 本模块独立接收事件；注册失败只停用自动胜利，不影响设置和技能语音。
    local registered = true
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_DEAD",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENCOUNTER_START", "ENCOUNTER_END",
    }) do
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then
            frame:UnregisterAllEvents()
            ResetVictoryPlayback()
            registered = false
            break
        end
    end
    if registered then
        for _, event in ipairs({ "UNIT_DIED", "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED", "UNIT_THREAT_LIST_UPDATE", "UNIT_FLAGS" }) do
            local ok = pcall(frame.RegisterEvent, frame, event)
            if not ok and event == "UNIT_DIED" then unitTrackingAvailable = false end
        end
    end
end

-- 角色事件独立于施法/胜利。只读安全的原生死亡状态，不读取生命值或复活技能。
local ResetCharacterEventPlayback
do
    local wasDead, initialized, inWorld, pending, lastLevel, lastSpecID

    local function Plain(value, expected)
        if type(issecretvalue) ~= "function" then return false end
        local ok, secret = pcall(issecretvalue, value)
        return ok and not secret and type(value) == expected
    end

    local function Read(api, expected)
        if type(api) ~= "function" then return nil end
        local ok, value = pcall(api, "player")
        if ok and Plain(value, expected) then return value end
    end

    local function DeadState()
        local dead, feign = Read(UnitIsDeadOrGhost, "boolean"), Read(UnitIsFeignDeath, "boolean")
        if dead == nil or feign ~= false then return nil end
        return dead
    end

    local function ReadSpecializationID()
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
        if type(getSpec) ~= "function" or type(getInfo) ~= "function" then return nil end
        local ok, index = pcall(getSpec)
        if not ok or not Plain(index, "number") or index <= 0 then return nil end
        local infoOK, specID = pcall(getInfo, index)
        if infoOK and Plain(specID, "number") and specID > 0 then return specID end
    end

    ResetCharacterEventPlayback = function()
        if pending and pending.timer then pcall(pending.timer.Cancel, pending.timer) end
        pending = nil
    end

    local function Play(key)
        EnsureDatabase()
        local settings = P5S_Voice_DB.characterEvents[key]
        if settings.enabled then PlayConfiguredEntry("characterEvents", key) end
    end

    local Observe
    Observe = function(kind, attempt)
        local dead = DeadState()
        if kind == "death" and dead == true then
            local changed = wasDead ~= true
            wasDead = true
            if changed and inWorld then Play("death") end
            return
        elseif kind == "resurrection" and dead == false then
            local changed = wasDead == true
            wasDead = false
            if changed and inWorld then Play("resurrection") end
            return
        end
        -- 事件可能早于原生状态刷新；最多再检查两次，无轮询和跨事件补播队列。
        if attempt < 2 and C_Timer and type(C_Timer.NewTimer) == "function" then
            local job = {}
            pending = job
            local ok, timer = pcall(C_Timer.NewTimer, attempt == 0 and 0.05 or 0.20, function()
                if pending ~= job then return end
                pending = nil
                Observe(kind, attempt + 1)
            end)
            if ok then job.timer = timer else pending = nil; wasDead = nil end
        elseif dead == nil then
            wasDead = nil -- 无法确认时放弃，不让旧死亡状态造成以后误报。
        elseif kind == "resurrection" then
            wasDead = dead -- 仍为灵魂/尸体；等待下一次真正复活事件。
        end
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_LEAVING_WORLD" then
            ResetCharacterEventPlayback()
            inWorld = false
            lastSpecID = nil
        elseif event == "PLAYER_ENTERING_WORLD" then
            ResetCharacterEventPlayback()
            inWorld = true
            lastSpecID = ReadSpecializationID() -- 进入世界只记录当前专精，不补播。
            if not initialized or (Plain(arg1, "boolean") and arg1) or (Plain(arg2, "boolean") and arg2) then
                wasDead = DeadState() -- 登录、重载只建立基线，不播死亡或复活。
                initialized = true
            elseif wasDead == true then
                Observe("resurrection", 0) -- 支持灵魂进入副本时自动复活，保留过图前状态。
            else
                wasDead = DeadState()
            end
            local level = Read(UnitLevel, "number")
            if level and level > 0 and (not lastLevel or level > lastLevel) then lastLevel = level end
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            if not Plain(arg1, "string") or arg1 ~= "player" then return end
            local specID = ReadSpecializationID()
            local previous = lastSpecID
            lastSpecID = specID -- 禁用、空池或读取失败也消费本次变化，之后不补播。
            if initialized and inWorld and previous and specID and previous ~= specID then
                Play("specialization")
            end
        elseif event == "PLAYER_LEVEL_UP" then
            if not Plain(arg1, "number") or arg1 <= 0 or arg1 ~= math.floor(arg1) then return end
            if lastLevel and arg1 <= lastLevel then return end
            lastLevel = arg1
            if initialized and inWorld then Play("levelUp") end
        elseif initialized then
            ResetCharacterEventPlayback()
            if event == "PLAYER_DEAD" then Observe("death", 0)
            elseif inWorld then Observe("resurrection", 0) end
        end
    end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_DEAD",
        "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_LEVEL_UP" }) do
        if not pcall(frame.RegisterEvent, frame, event) then
            frame:UnregisterAllEvents()
            ResetCharacterEventPlayback()
            break -- 只停用本模块；选择、试听、其他自动语音不受影响。
        end
    end
    -- 此事件不可用时，仅切专精语音降级，保留原有死亡/复活/升级事件。
    pcall(frame.RegisterEvent, frame, "PLAYER_SPECIALIZATION_CHANGED")
end

local function TriggerVoiceForSpell(spellID)
    local targets = voiceTriggerMap[spellID]
    if not targets then return end

    for _, target in ipairs(targets) do
        PlayConfiguredEntry(target.sectionKey, target.index)
    end
end

-- 冷却结束语音使用原生 Cooldown 控件托管持续时间对象。
-- 不读取、比较或格式化可能受保护的开始时间、持续时间和充能数量；
-- 施法后只挂载一次持续时间对象，避免全局冷却更新重复覆盖原生结束回调。

local COOLDOWN_ARM_DELAY = 0.05

local function ClearCooldownWatcher(watcher)
    if not watcher then return end

    watcher.pending = false
    watcher.armed = false
    watcher.installing = false
    watcher.finishedWhileInstalling = false
    watcher.mode = nil
    watcher.generation = (watcher.generation or 0) + 1
    if watcher.frame and watcher.frame.Clear then
        pcall(watcher.frame.Clear, watcher.frame)
    end
end

local function CompleteCooldownWatcher(spellID, watcher)
    ClearCooldownWatcher(watcher)
    local targets = cooldownReadyTriggerMap[spellID]
    if not targets then return end

    for _, target in ipairs(targets) do
        PlayConfiguredEntry(target.sectionKey, target.index)
    end
end

local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end

    local ok, isSecret = pcall(issecretvalue, value)
    if not ok or type(isSecret) ~= "boolean" then return true end
    return isSecret
end

local function GetNonSecretBoolean(value)
    if IsSecretValue(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function GetChargeRecoveryState(spellID)
    if not C_Spell or type(C_Spell.GetSpellCharges) ~= "function" then
        return nil, nil
    end

    local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, spellID)
    if not ok then return nil, nil end

    if type(chargeInfo) == "nil" then return false, nil end
    if IsSecretValue(chargeInfo) or type(chargeInfo) ~= "table" then return nil, nil end

    -- 不读取 currentCharges 或任何充能时间，只使用明确标记为 NeverSecret 的活动状态。
    local isActive = GetNonSecretBoolean(chargeInfo.isActive)
    if isActive == nil then return nil, nil end

    return true, isActive
end

local function GetCooldownEventState(spellID)
    if not C_Spell or type(C_Spell.GetSpellCooldown) ~= "function" then
        return nil, nil, nil
    end

    local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or IsSecretValue(cooldownInfo) or type(cooldownInfo) ~= "table" then
        return nil, nil, nil
    end

    -- 只读取 API 明确标记为 NeverSecret 的布尔状态；不读取或比较冷却时间数字。
    local isEnabled = GetNonSecretBoolean(cooldownInfo.isEnabled)
    local isActive = GetNonSecretBoolean(cooldownInfo.isActive)
    if isEnabled == nil or isActive == nil then return nil, nil, nil end

    local isOnGCD
    if type(cooldownInfo.isOnGCD) ~= "nil" then
        isOnGCD = GetNonSecretBoolean(cooldownInfo.isOnGCD)
        if isOnGCD == nil then return nil, nil, nil end
    end

    return isEnabled, isActive, isOnGCD
end

local function GetCooldownDurationObject(spellID)
    if not C_Spell or type(C_Spell.GetSpellCooldownDuration) ~= "function" then
        return nil
    end

    local ignoreGlobalCooldown = true
    local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID, ignoreGlobalCooldown)
    if not ok then return nil end
    return duration
end

local function GetChargeDurationObject(spellID)
    if not C_Spell or type(C_Spell.GetSpellChargeDuration) ~= "function" then
        return nil
    end

    local ok, duration = pcall(C_Spell.GetSpellChargeDuration, spellID)
    if not ok then return nil end
    return duration
end

local HandleCooldownWatcherDone

local function GetOrCreateCooldownWatcher(spellID)
    local watcher = cooldownWatchers[spellID]
    if watcher then return watcher end

    watcher = {
        generation = 0,
        pending = false,
        armed = false,
        installing = false,
        finishedWhileInstalling = false,
        mode = nil,
    }

    local cooldownFrame = CreateFrame("Cooldown", nil, UIParent)
    cooldownFrame:SetSize(1, 1)
    cooldownFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    cooldownFrame:SetAlpha(0)
    cooldownFrame:SetHideCountdownNumbers(true)
    cooldownFrame:SetDrawSwipe(false)
    cooldownFrame:SetDrawEdge(false)
    cooldownFrame:SetDrawBling(false)
    cooldownFrame:Show()

    watcher.frame = cooldownFrame
    cooldownWatchers[spellID] = watcher

    cooldownFrame:SetScript("OnCooldownDone", function()
        local currentWatcher = cooldownWatchers[spellID]
        if currentWatcher ~= watcher or not watcher.armed then return end

        if watcher.installing then
            -- 零持续时间在挂载过程中同步结束时不播放，避免无真实冷却误触发。
            watcher.finishedWhileInstalling = true
            return
        end

        -- 原生 Cooldown 已确认当前普通冷却或一层充能恢复结束。
        HandleCooldownWatcherDone(spellID, watcher)
    end)

    return watcher
end

local function SetWatcherDuration(spellID, watcher)
    local setDurationMethod = watcher.frame and watcher.frame.SetCooldownFromDurationObject
    if type(setDurationMethod) ~= "function" then return false end

    local duration
    if watcher.mode == "charge" then
        duration = GetChargeDurationObject(spellID)
    else
        duration = GetCooldownDurationObject(spellID)
    end
    if type(duration) == "nil" then return false end

    watcher.installing = true
    watcher.finishedWhileInstalling = false
    local ok = pcall(setDurationMethod, watcher.frame, duration, true)
    watcher.installing = false
    return ok and not watcher.finishedWhileInstalling
end

local function ScheduleCooldownWatcherArm(spellID, watcher, generation, determineMode)
    local function ArmAfterCooldownDataUpdate()
        if watcher.generation ~= generation or not watcher.pending then return end

        local isChargeSpell, isChargeRecoveryActive = GetChargeRecoveryState(spellID)
        if isChargeSpell == nil then
            ClearCooldownWatcher(watcher)
            return
        end

        if determineMode then
            watcher.mode = isChargeSpell and "charge" or "cooldown"
        elseif watcher.mode == "charge" and isChargeSpell ~= true then
            ClearCooldownWatcher(watcher)
            return
        end

        if watcher.mode == "charge" and isChargeRecoveryActive ~= true then
            -- 已恢复到满层时结束连续监测，不播放额外语音。
            ClearCooldownWatcher(watcher)
            return
        end

        watcher.pending = false
        watcher.armed = true
        if not SetWatcherDuration(spellID, watcher) then
            -- 接口缺失、受限或没有真实冷却时安静取消本次监测。
            ClearCooldownWatcher(watcher)
        end
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(COOLDOWN_ARM_DELAY, ArmAfterCooldownDataUpdate)
    else
        ArmAfterCooldownDataUpdate()
    end
end

HandleCooldownWatcherDone = function(spellID, watcher)
    if watcher.mode ~= "charge" then
        CompleteCooldownWatcher(spellID, watcher)
        return
    end

    local targets = cooldownReadyTriggerMap[spellID]
    if not targets then
        ClearCooldownWatcher(watcher)
        return
    end

    -- 当前这一层已经由原生控件确认恢复；每层只在这里播放一次。
    watcher.pending = true
    watcher.armed = false
    watcher.installing = false
    watcher.finishedWhileInstalling = false
    watcher.generation = (watcher.generation or 0) + 1
    local generation = watcher.generation

    for _, target in ipairs(targets) do
        PlayConfiguredEntry(target.sectionKey, target.index)
    end

    -- 如果后面还有层数正在恢复，短延迟后挂接下一轮；满层则安静结束。
    ScheduleCooldownWatcherArm(spellID, watcher, generation, false)
end

local function StartCooldownReadyWatch(spellID)
    spellID = tonumber(spellID)
    if not spellID or not cooldownReadyTriggerMap[spellID] then return end

    local watcher = GetOrCreateCooldownWatcher(spellID)

    -- 多层充能连续消耗时，最早一层的恢复终点不会改变；保留当前原生计时，
    -- 避免每次消耗下一层都覆盖即将到达的完成回调。
    if watcher.mode == "charge" and (watcher.pending or watcher.armed) then return end

    watcher.pending = true
    watcher.armed = false
    watcher.installing = false
    watcher.finishedWhileInstalling = false
    watcher.mode = nil
    watcher.generation = (watcher.generation or 0) + 1
    if watcher.frame and watcher.frame.Clear then
        pcall(watcher.frame.Clear, watcher.frame)
    end

    local generation = watcher.generation
    -- 固定短延迟后判断普通/充能模式并挂接当前恢复周期，不依赖事件先后顺序。
    ScheduleCooldownWatcherArm(spellID, watcher, generation, true)
end

local function RefreshReducedCooldownWatchers()
    for spellID, watcher in pairs(cooldownWatchers) do
        if watcher.mode == "cooldown" and watcher.armed then
            local isEnabled, isActive, isOnGCD = GetCooldownEventState(spellID)

            -- 冷却被缩短或重置时，原先挂载的 DurationObject 不一定会提前结束。
            -- SPELL_UPDATE_COOLDOWN 内若技能已无自身冷却（或只剩公共冷却），立即完成；
            -- 状态不可安全读取或技能仍处于 hold 状态时，保留原生结束回调作为降级。
            if isEnabled == true and (isActive == false or isOnGCD == true) then
                CompleteCooldownWatcher(spellID, watcher)
            end
        end
    end
end

PruneCooldownWatchers = function()
    for spellID, watcher in pairs(cooldownWatchers) do
        if not cooldownReadyTriggerMap[spellID] then
            ClearCooldownWatcher(watcher)
        end
    end
end

local function InstallSpellLinkInputHook()
    if spellLinkHookInstalled or type(hooksecurefunc) ~= "function" then return end
    spellLinkHookInstalled = true

    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if activeVoiceInput
            and activeVoiceInput.HasFocus
            and activeVoiceInput:HasFocus()
            and type(link) == "string" then
            activeVoiceInput:Insert(link)
        end
    end)
end

local function SaveVoiceInput(sectionKey, index, editBox)
    EnsureDatabase()

    local text = TrimText(editBox:GetText())
    local entry = P5S_Voice_DB.inputs[sectionKey][index]
    entry.input = text

    if text == "" then
        SetEntrySpellMap(entry, {})
        RebuildVoiceTriggerMap()
        editBox:SetText("")
        SetStatus(L["已清空当前技能输入；该行已选音频仍然保留。"], false)
        return
    end

    local spellIDMap, validList, invalidList = BuildSpellIDMap(text)
    SetEntrySpellMap(entry, spellIDMap)
    RebuildVoiceTriggerMap()

    if #validList > 0 and #invalidList == 0 then
        SetStatus(L["已保存触发技能："] .. JoinList(validList), false)
    elseif #validList > 0 then
        SetStatus(L["已保存："] .. JoinList(validList) .. L["；无法识别："] .. JoinList(invalidList), true)
    else
        SetStatus(L["已保留输入，但没有可用的触发技能；建议脱战后重试或直接填写 Spell ID。"], true)
    end
end

local function SaveActiveVoiceInput()
    local focusedInput = activeVoiceInput
    if focusedInput
        and focusedInput.HasFocus
        and focusedInput:HasFocus()
        and focusedInput.p5VoiceSectionKey
        and focusedInput.p5VoiceIndex then
        SaveVoiceInput(focusedInput.p5VoiceSectionKey, focusedInput.p5VoiceIndex, focusedInput)
        focusedInput.p5SkipFocusSave = true
        focusedInput:ClearFocus()
    end
    activeVoiceInput = nil
end

local function GetAudioCategory(fileName)
    if string.find(fileName, "复活", 1, true) == 1
        or string.find(fileName, "死亡", 1, true) == 1
        or string.find(fileName, "升级", 1, true) == 1
        or string.find(fileName, "切专精", 1, true) == 1 then return "other" end
    if string.find(fileName, "胜利_", 1, true) == 1 then return "victory" end
    if string.find(fileName, "冷却_", 1, true) == 1 then return "cooldown" end
    if string.find(fileName, "面具", 1, true) == 1 then return "persona" end
    if string.find(fileName, "治疗", 1, true) == 1 then return "healing" end
    return "skill"
end

local categoryLabels = {
    skill = L["技能"],
    healing = L["治疗"],
    persona = L["面具"],
    cooldown = L["冷却"],
    victory = L["胜利"],
    other = L["角色事件"],
}

local RefreshVoiceRow

-- ==========================================
-- 音频选择器：分类、单独预览和选择
-- ==========================================
AudioPicker = CreateFrame("Frame", "P5VoiceAudioPicker", UIParent, "BackdropTemplate")
AudioPicker:SetSize(1000, 680)
AudioPicker:SetPoint("CENTER")
AudioPicker:SetClampedToScreen(true)
AudioPicker:SetMovable(true)
AudioPicker:EnableMouse(true)
AudioPicker:RegisterForDrag("LeftButton")
AudioPicker:SetScript("OnDragStart", AudioPicker.StartMoving)
AudioPicker:SetScript("OnDragStop", AudioPicker.StopMovingOrSizing)
AudioPicker:Hide()
AudioPicker:HookScript("OnHide", StopAudioPreview)

if not ApplyVoicePanelTheme("ApplyOptionsPanel", AudioPicker) then
    ApplyVoicePanelFallback(AudioPicker)
end
EnsureVoicePanelChrome(AudioPicker)
AudioPicker:SetFrameStrata("FULLSCREEN_DIALOG")
AudioPicker:HookScript("OnShow", function(panel)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:Raise()
end)

AudioPicker.title = AudioPicker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
AudioPicker.title:SetPoint("CENTER", AudioPicker.TitleBg, "CENTER", 0, 0)
AudioPicker.title:SetText(L["选择音频"])
ApplyVoicePanelTheme("StylePanelTitle", AudioPicker.title)
ApplyVoicePanelTheme("StyleCloseButton", AudioPicker.CloseButton)

local pickerTarget = nil
local pickerSource = "joker"
local pickerCategory = "skill"

local pickerAccentPalettes = {
    joker = {
        accent = { 0.82, 0.07, 0.05, 1.00 },
        accentBright = { 1.00, 0.25, 0.20, 1.00 },
        accentSoft = { 0.90, 0.08, 0.06, 0.15 },
        selectionSoft = { 0.90, 0.08, 0.06, 0.13 },
        selectionText = { 1.00, 0.35, 0.30, 1.00 },
    },
    makoto = {
        accent = { 0, 5 / 255, 131 / 255, 1.00 },
        accentBright = { 25 / 255, 246 / 255, 1, 1.00 },
        accentSoft = { 0, 5 / 255, 131 / 255, 0.28 },
        selectionSoft = { 0, 5 / 255, 131 / 255, 0.28 },
        selectionText = { 25 / 255, 246 / 255, 1, 1.00 },
    },
}

local pickerAccentButtons = {}

local function GetPickerAccentPalette()
    return pickerAccentPalettes[pickerSource] or pickerAccentPalettes.joker
end

local function SetTextureVertexColor(texture, color)
    if not texture then return end
    if texture.SetDesaturated then texture:SetDesaturated(true) end
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function UpdatePickerAccentButtonStyle(button)
    if not button or not button.SetBackdropColor then return end

    local colors = GetVoiceThemeColors()
    local palette = GetPickerAccentPalette()
    local controlPressed = colors.controlPressed or { 0.030, 0.035, 0.055, 0.98 }
    local controlDisabled = colors.controlDisabled or { 0.035, 0.038, 0.050, 0.78 }
    local background = colors.controlBackground
    local border = colors.controlBorder
    local textColor = colors.text
    local borderAlpha = border[4] or 1

    if not button:IsEnabled() then
        background = controlDisabled
        textColor = colors.textDim
        borderAlpha = 0.45
    elseif button._p5VoicePickerPressed then
        background = controlPressed
        border = palette.accent
    elseif button:IsMouseOver() then
        background = colors.controlHover
        border = palette.accentBright
    end

    button:SetBackdropColor(background[1], background[2], background[3], background[4] or 1)
    button:SetBackdropBorderColor(border[1], border[2], border[3], borderAlpha)

    local fontString = button:GetFontString()
    if fontString then
        fontString:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    end

    local highlight = button:GetHighlightTexture()
    if highlight then SetTextureColor(highlight, palette.accentSoft) end
end

local function StylePickerAccentButton(button)
    if not button or button._p5VoicePickerAccentStyled then return end
    button._p5VoicePickerAccentStyled = true

    HideButtonTemplateChrome(button)
    if EnsureBackdrop(button) then button:SetBackdrop(CONTROL_BACKDROP) end

    local highlight = button:GetHighlightTexture()
    if not highlight then
        highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button:SetHighlightTexture(highlight)
    end

    button:HookScript("OnEnter", UpdatePickerAccentButtonStyle)
    button:HookScript("OnLeave", function(self)
        self._p5VoicePickerPressed = false
        UpdatePickerAccentButtonStyle(self)
    end)
    button:HookScript("OnMouseDown", function(self)
        self._p5VoicePickerPressed = true
        UpdatePickerAccentButtonStyle(self)
    end)
    button:HookScript("OnMouseUp", function(self)
        self._p5VoicePickerPressed = false
        UpdatePickerAccentButtonStyle(self)
    end)
    button:HookScript("OnShow", UpdatePickerAccentButtonStyle)

    table.insert(pickerAccentButtons, button)
    UpdatePickerAccentButtonStyle(button)
end

local pickerHeaderLeftAccent = AudioPicker:CreateTexture(nil, "BORDER", nil, 7)
pickerHeaderLeftAccent:SetPoint("TOPLEFT", AudioPicker, "TOPLEFT", 1, -1)
pickerHeaderLeftAccent:SetPoint("BOTTOMLEFT", AudioPicker, "TOPLEFT", 1, -39)
pickerHeaderLeftAccent:SetWidth(3)

local pickerHeaderRightAccent = AudioPicker:CreateTexture(nil, "BORDER", nil, 7)
pickerHeaderRightAccent:SetPoint("TOPRIGHT", AudioPicker, "TOPRIGHT", -1, -1)
pickerHeaderRightAccent:SetPoint("BOTTOMRIGHT", AudioPicker, "TOPRIGHT", -1, -39)
pickerHeaderRightAccent:SetWidth(3)

local pickerFilterSection = CreateVoiceSettingsSection(AudioPicker, 24, -56, 952, 146, L["音频来源与分类"])
local pickerListSection = CreateVoiceSettingsSection(AudioPicker, 24, -214, 952, 420, L["音频列表"])

local pickerHelpText = pickerFilterSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pickerHelpText:SetPoint("TOPLEFT", pickerFilterSection, "TOPLEFT", 18, -116)
pickerHelpText:SetWidth(916)
pickerHelpText:SetHeight(16)
pickerHelpText:SetJustifyH("LEFT")
if pickerHelpText.SetWordWrap then pickerHelpText:SetWordWrap(false) end
pickerHelpText:SetText(L["提示：主音频可多选；触发时会随机播放一条，选好后直接关闭窗口即可。"])
ApplyVoicePanelTheme("StyleMutedText", pickerHelpText)

local clearAudioButton = CreateFrame("Button", nil, pickerFilterSection, "UIPanelButtonTemplate")
clearAudioButton:SetSize(148, 26)
clearAudioButton:SetPoint("TOPRIGHT", pickerFilterSection, "TOPRIGHT", -18, -38)
clearAudioButton:SetText(L["清除当前音频"])
ApplyVoicePanelTheme("StyleButton", clearAudioButton)
ApplyVoiceLocalStyle("StylePickerAccentButton:clear", StylePickerAccentButton, clearAudioButton)

local sourceButtonPalettes = {
    joker = {
        background = { 250 / 255, 0, 0, 1 },
        text = { 1, 1, 1, 1 },
        border = { 0.62, 0.08, 0.07, 1 },
        selectedBorder = { 1, 1, 1, 1 },
    },
    makoto = {
        background = { 0, 5 / 255, 131 / 255, 1 },
        text = { 25 / 255, 246 / 255, 1, 1 },
        border = { 0.08, 0.24, 0.62, 1 },
        selectedBorder = { 25 / 255, 246 / 255, 1, 1 },
    },
}

local sourceButtons = {}
for buttonIndex, source in ipairs(AUDIO_SOURCES) do
    local button = CreateFrame("Button", nil, pickerFilterSection, "UIPanelButtonTemplate")
    button:SetSize(208, 30)
    button:SetPoint("TOPLEFT", pickerFilterSection, "TOPLEFT", 18 + ((buttonIndex - 1) * 218), -36)
    button:SetText(source.label)
    button.sourceKey = source.key
    ApplyVoiceLocalStyle("StyleIdentityButton:" .. tostring(source.key), StyleIdentityButton, button, sourceButtonPalettes[source.key] or {
        background = { 0.15, 0.17, 0.22, 1 },
        text = { 0.94, 0.95, 0.98, 1 },
        border = { 0.28, 0.32, 0.40, 1 },
        selectedBorder = { 1.00, 0.25, 0.20, 1 },
    })
    sourceButtons[source.key] = button
end

local categoryButtons = {}
local categoryOrder = { "skill", "healing", "persona", "cooldown", "victory", "other" }
for buttonIndex, category in ipairs(categoryOrder) do
    local button = CreateFrame("Button", nil, pickerFilterSection, "UIPanelButtonTemplate")
    button:SetSize(144, 30)
    button:SetPoint("TOPLEFT", pickerFilterSection, "TOPLEFT", 18 + ((buttonIndex - 1) * 154), -78)
    button:SetText(categoryLabels[category])
    button.category = category
    ApplyVoicePanelTheme("StyleButton", button)
    ApplyVoiceLocalStyle("StylePickerAccentButton:category:" .. tostring(category), StylePickerAccentButton, button)

    local selectedAccent = button:CreateTexture(nil, "OVERLAY")
    selectedAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    selectedAccent:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    selectedAccent:SetHeight(3)
    SetTextureColor(selectedAccent, GetPickerAccentPalette().accentBright)
    selectedAccent:Hide()
    button.p5SelectionAccent = selectedAccent
    categoryButtons[category] = button
end

local pickerTableHeader = CreateFrame("Frame", nil, pickerListSection, "BackdropTemplate")
pickerTableHeader:SetPoint("TOPLEFT", pickerListSection, "TOPLEFT", 14, -34)
pickerTableHeader:SetSize(894, 24)
pickerTableHeader:SetBackdrop(CONTROL_BACKDROP)
pickerTableHeader:SetBackdropColor(0.050, 0.058, 0.080, 0.94)
pickerTableHeader:SetBackdropBorderColor(0.28, 0.32, 0.40, 0.72)

local pickerFileHeader = pickerTableHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pickerFileHeader:SetPoint("LEFT", pickerTableHeader, "LEFT", 14, 0)
pickerFileHeader:SetText(L["音频文件"])
ApplyVoicePanelTheme("StyleMutedText", pickerFileHeader)

local pickerActionHeader = pickerTableHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pickerActionHeader:SetPoint("LEFT", pickerTableHeader, "LEFT", 646, 0)
pickerActionHeader:SetWidth(212)
pickerActionHeader:SetJustifyH("CENTER")
pickerActionHeader:SetText(L["操作"])
ApplyVoicePanelTheme("StyleMutedText", pickerActionHeader)

local pickerScroll = CreateFrame("ScrollFrame", "P5VoiceAudioPickerScroll", pickerListSection, "UIPanelScrollFrameTemplate")
pickerScroll:SetPoint("TOPLEFT", pickerListSection, "TOPLEFT", 14, -64)
pickerScroll:SetPoint("BOTTOMRIGHT", pickerListSection, "BOTTOMRIGHT", -28, 38)

local pickerContent = CreateFrame("Frame", nil, pickerScroll)
pickerContent:SetSize(894, 1)
pickerScroll:SetScrollChild(pickerContent)

local pickerResultText = pickerListSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pickerResultText:SetPoint("BOTTOMLEFT", pickerListSection, "BOTTOMLEFT", 18, 13)
pickerResultText:SetWidth(910)
pickerResultText:SetJustifyH("LEFT")
ApplyVoicePanelTheme("StyleMutedText", pickerResultText)

local pickerEmptyText = pickerListSection:CreateFontString(nil, "OVERLAY", "GameFontDisable")
pickerEmptyText:SetPoint("CENTER", pickerScroll, "CENTER", 0, 0)
pickerEmptyText:SetText(L["没有符合当前筛选条件的音频"])
ApplyVoicePanelTheme("StyleMutedText", pickerEmptyText)
pickerEmptyText:Hide()

local RefreshAudioPickerResults
local pickerRows = {}
for rowIndex = 1, #audioItems do
    local row = CreateFrame("Frame", nil, pickerContent)
    row:SetSize(894, 34)
    row:SetPoint("TOPLEFT", 0, -((rowIndex - 1) * 36))

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    if rowIndex % 2 == 0 then
        bg:SetColorTexture(0.055, 0.062, 0.085, 0.78)
    else
        bg:SetColorTexture(0.030, 0.035, 0.052, 0.64)
    end

    local selectedBackground = row:CreateTexture(nil, "BORDER")
    selectedBackground:SetAllPoints(row)
    SetTextureColor(selectedBackground, GetPickerAccentPalette().selectionSoft)
    selectedBackground:Hide()
    row.selectedBackground = selectedBackground

    local selectedAccent = row:CreateTexture(nil, "ARTWORK")
    selectedAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    selectedAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    selectedAccent:SetWidth(3)
    SetTextureColor(selectedAccent, GetPickerAccentPalette().accentBright)
    selectedAccent:Hide()
    row.selectedAccent = selectedAccent

    local hover = row:CreateTexture(nil, "ARTWORK")
    hover:SetAllPoints(row)
    hover:SetColorTexture(1, 1, 1, 0.045)
    hover:Hide()
    row.hover = hover

    row.fileText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.fileText:SetPoint("LEFT", 14, 0)
    row.fileText:SetWidth(610)
    row.fileText:SetHeight(20)
    row.fileText:SetJustifyH("LEFT")
    if row.fileText.SetWordWrap then row.fileText:SetWordWrap(false) end
    ApplyVoicePanelTheme("StyleBodyText", row.fileText)

    row.previewButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.previewButton:SetSize(80, 24)
    row.previewButton:SetPoint("LEFT", 646, 0)
    row.previewButton:SetText(L["试听"])
    row.previewButton:SetScript("OnClick", function()
        StopAudioPreview()
        PlayAudioFile(row.audioID, false, true)
    end)
    ApplyVoicePanelTheme("StyleButton", row.previewButton)
    ApplyVoiceLocalStyle("StylePickerAccentButton:preview", StylePickerAccentButton, row.previewButton)

    row.selectButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.selectButton:SetSize(116, 24)
    row.selectButton:SetPoint("LEFT", 742, 0)
    row.selectButton:SetText(L["选择"])
    row.selectButton:SetScript("OnClick", function()
        if not pickerTarget or not row.audioID then return end
        EnsureDatabase()
        local entry = GetVoiceAudioEntry(pickerTarget.sectionKey, pickerTarget.index)
        local selectedAudioID = row.audioID

        if pickerTarget.slotKey == "audio1" then
            local choiceMap = GetMainAudioChoiceMap(entry)
            local isAdding = not choiceMap[selectedAudioID]
            local selectedCount = SetMainAudioChoiceSelected(entry, selectedAudioID, isAdding)
            RefreshVoiceRow(pickerTarget.sectionKey, pickerTarget.index, false)
            RefreshAudioPickerResults(true)

            if isAdding then
                SetStatus(L["已加入主音频随机池；当前共 "] .. tostring(selectedCount) .. L[" 条。"], false)
            else
                SetStatus(L["已移出主音频随机池；当前剩余 "] .. tostring(selectedCount) .. L[" 条。"], false)
            end
            return
        end

        entry.audio2 = selectedAudioID
        RefreshVoiceRow(pickerTarget.sectionKey, pickerTarget.index, false)
        AudioPicker:Hide()
        SetStatus(L["已选择叠加音频；点击“试听”可播放。"], false)
    end)
    ApplyVoicePanelTheme("StyleButton", row.selectButton)
    ApplyVoiceLocalStyle("StylePickerAccentButton:select", StylePickerAccentButton, row.selectButton)

    row:SetScript("OnEnter", function()
        local item = audioItemsByID[row.audioID]
        if not item then return end
        row.hover:Show()
        local source = audioSourcesByKey[item.sourceKey]
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(item.displayName, 1, 1, 1)
        GameTooltip:AddLine(L["角色："] .. (item.shared and L["P5 雨宫莲 / P3 结城理通用"] or (source and source.label or item.sourceKey)), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["分类："] .. categoryLabels[GetAudioCategory(item.fileName)], 0.8, 0.8, 0.8)
        if row.isCurrentSelection then
            local palette = GetPickerAccentPalette()
            local selectionText = palette.selectionText
            GameTooltip:AddLine(
                pickerTarget and pickerTarget.slotKey == "audio1"
                    and L["已加入主音频随机播放"]
                    or L["当前叠加音频已选择此文件"],
                selectionText[1],
                selectionText[2],
                selectionText[3]
            )
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        row.hover:Hide()
        GameTooltip_Hide()
    end)

    row:Hide()
    pickerRows[rowIndex] = row
end

local appliedPickerAccentSource

local function RefreshAudioPickerAccentTheme()
    if appliedPickerAccentSource == pickerSource then return end
    appliedPickerAccentSource = pickerSource

    local palette = GetPickerAccentPalette()
    SetTextureColor(AudioPicker.HeaderDivider, palette.accent, 0.68)
    SetTextureColor(pickerHeaderLeftAccent, palette.accent, 1.00)
    SetTextureColor(pickerHeaderRightAccent, palette.accent, 1.00)

    if AudioPicker.CloseButton then
        SetTextureVertexColor(AudioPicker.CloseButton:GetNormalTexture(), palette.accentBright)
        SetTextureVertexColor(AudioPicker.CloseButton:GetPushedTexture(), palette.accent)
        SetTextureVertexColor(AudioPicker.CloseButton:GetHighlightTexture(), palette.accentBright)
    end

    for _, section in ipairs({ pickerFilterSection, pickerListSection }) do
        SetTextureColor(section.Accent, palette.accent)
        if section.Title then
            section.Title:SetTextColor(
                palette.accentBright[1],
                palette.accentBright[2],
                palette.accentBright[3],
                palette.accentBright[4]
            )
        end
    end

    for _, button in ipairs(pickerAccentButtons) do
        UpdatePickerAccentButtonStyle(button)
    end
    for _, button in pairs(categoryButtons) do
        SetTextureColor(button.p5SelectionAccent, palette.accentBright)
    end
    for _, row in ipairs(pickerRows) do
        SetTextureColor(row.selectedBackground, palette.selectionSoft)
        SetTextureColor(row.selectedAccent, palette.accentBright)
    end
end

RefreshAudioPickerResults = function(preserveScroll)
    ApplyVoiceLocalStyle("RefreshAudioPickerAccentTheme", RefreshAudioPickerAccentTheme)
    local previousScroll = preserveScroll and pickerScroll:GetVerticalScroll() or 0
    local shownCount = 0
    local currentAudioID
    local selectedAudioMap = {}
    local selectedAudioCount = 0
    if pickerTarget and P5S_Voice_DB and P5S_Voice_DB.inputs then
        local entry = GetVoiceAudioEntry(pickerTarget.sectionKey, pickerTarget.index)
        if entry and pickerTarget.slotKey == "audio1" then
            selectedAudioMap, selectedAudioCount = GetMainAudioChoiceMap(entry)
        else
            currentAudioID = entry and entry[pickerTarget.slotKey]
        end
    end

    for _, item in ipairs(audioItems) do
        local sourceMatches = item.sourceKey == pickerSource or item.shared
        local categoryMatches = GetAudioCategory(item.fileName) == pickerCategory
        if sourceMatches and categoryMatches then
            shownCount = shownCount + 1
            local row = pickerRows[shownCount]
            row.audioID = item.id
            row.fileText:SetText(item.displayName)
            if pickerTarget and pickerTarget.slotKey == "audio1" then
                row.isCurrentSelection = selectedAudioMap[item.id] == true
            else
                row.isCurrentSelection = item.id == currentAudioID
            end
            row.selectedBackground:SetShown(row.isCurrentSelection)
            row.selectedAccent:SetShown(row.isCurrentSelection)
            if pickerTarget and pickerTarget.slotKey == "audio1" then
                row.selectButton:SetText(row.isCurrentSelection and L["取消选择"] or L["加入随机"])
            else
                row.selectButton:SetText(row.isCurrentSelection and L["已选择"] or L["选择"])
            end
            row:Show()
        end
    end

    for rowIndex = shownCount + 1, #pickerRows do
        local row = pickerRows[rowIndex]
        row.audioID = nil
        row.isCurrentSelection = false
        row.selectedBackground:Hide()
        row.selectedAccent:Hide()
        row:Hide()
    end

    pickerContent:SetHeight(math.max(1, shownCount * 36))
    pickerScroll:SetVerticalScroll(preserveScroll and previousScroll or 0)

    for category, button in pairs(categoryButtons) do
        button:Enable()
        button.p5SelectionAccent:SetShown(category == pickerCategory)
    end
    for sourceKey, button in pairs(sourceButtons) do
        button:Enable()
        button._p5VoiceIdentitySelected = sourceKey == pickerSource
        ApplyVoiceLocalStyle("UpdateIdentityButtonStyle", UpdateIdentityButtonStyle, button)
    end

    local source = audioSourcesByKey[pickerSource]
    local resultSummary =
        L["显示 "] .. tostring(shownCount) .. L[" 项  ·  "]
        .. (source and source.label or pickerSource) .. "  ·  "
        .. (categoryLabels[pickerCategory] or pickerCategory)
    if pickerTarget and pickerTarget.slotKey == "audio1" then
        resultSummary = resultSummary .. L["  ·  已选 "] .. tostring(selectedAudioCount) .. L[" 条"]
    end
    pickerResultText:SetText(resultSummary)
    pickerEmptyText:SetShown(shownCount == 0)

    if shownCount == 0 then
        SetStatus(L["当前角色的这个分类下没有音频。"], true)
    end
end

for category, button in pairs(categoryButtons) do
    local selectedCategory = category
    button:SetScript("OnClick", function()
        pickerCategory = selectedCategory
        RefreshAudioPickerResults(false)
    end)
end

for sourceKey, button in pairs(sourceButtons) do
    local selectedSource = sourceKey
    button:SetScript("OnClick", function()
        pickerSource = selectedSource
        RefreshAudioPickerResults(false)
    end)
end

clearAudioButton:SetScript("OnClick", function()
    if not pickerTarget then return end
    EnsureDatabase()
    local entry = GetVoiceAudioEntry(pickerTarget.sectionKey, pickerTarget.index)

    if pickerTarget.slotKey == "audio1" then
        ClearMainAudioChoices(entry)
        RefreshVoiceRow(pickerTarget.sectionKey, pickerTarget.index, false)
        RefreshAudioPickerResults(true)
        SetStatus(pickerTarget.sectionKey == "victory" and L["已清空胜利语音池。"] or L["已清除该行的全部主音频。"], false)
        return
    end

    entry.audio2 = nil
    RefreshVoiceRow(pickerTarget.sectionKey, pickerTarget.index, false)
    AudioPicker:Hide()
    SetStatus(L["已清除当前叠加音频。"], false)
end)

local function OpenAudioPicker(sectionKey, index, slotKey)
    EnsureDatabase()
    pickerTarget = { sectionKey = sectionKey, index = index, slotKey = slotKey }
    local entry = GetVoiceAudioEntry(sectionKey, index)
    local currentAudioID
    if slotKey == "audio1" then
        for _, audioID in ipairs(GetMainAudioChoices(entry)) do
            if audioItemsByID[audioID] then
                currentAudioID = audioID
                break
            end
        end
    else
        currentAudioID = entry.audio2
    end
    local currentItem = audioItemsByID[currentAudioID]
    if not currentItem or not currentItem.shared then
        pickerSource = currentItem and currentItem.sourceKey or "joker"
    end
    pickerCategory = sectionKey == "victory" and "victory"
        or (sectionKey == "characterEvents" and "other")
        or (currentItem and GetAudioCategory(currentItem.fileName) or "skill")
    AudioPicker.title:SetText(slotKey == "audio1" and L["选择主音频"] or L["选择叠加音频"])
    pickerHelpText:SetText(
        slotKey == "audio1"
            and L["提示：主音频可多选；触发时会随机播放一条，选好后直接关闭窗口即可。"]
            or L["提示：叠加音频为单选；选择后会自动返回设置面板。"]
    )
    clearAudioButton:SetText(slotKey == "audio1" and L["清除全部主音频"] or L["清除当前音频"])
    RefreshAudioPickerResults(false)
    AudioPicker:Show()
end

VoicePanel:SetScript("OnHide", function()
    StopAudioPreview()
    SaveActiveVoiceInput()
    AudioPicker:Hide()
    print(L["|cffFF0000[P5S 语音]|r 语音已保存，偏铝唢呐！"])
end)

-- ==========================================
-- 主设置面板：频道、前四组各20行配置与胜利独立设置
-- ==========================================
local channelDropdown = CreateFrame("Frame", "P5VoiceChannelDropdown", infoSection, "UIDropDownMenuTemplate")
channelDropdown:SetPoint("TOPRIGHT", infoSection, "TOPRIGHT", -4, -24)
UIDropDownMenu_SetWidth(channelDropdown, 118)

local channelLabel = infoSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
channelLabel:SetPoint("RIGHT", channelDropdown, "LEFT", 6, 2)
channelLabel:SetText(L["播放频道："])
ApplyVoicePanelTheme("StyleBodyText", channelLabel)

UIDropDownMenu_Initialize(channelDropdown, function()
    for _, option in ipairs(channelOptions) do
        local label = option.label
        local value = option.value
        local info = UIDropDownMenu_CreateInfo()
        info.text = label
        info.value = value
        info.checked = P5S_Voice_DB and P5S_Voice_DB.channel == value
        info.func = function()
            EnsureDatabase()
            P5S_Voice_DB.channel = value
            UIDropDownMenu_SetSelectedValue(channelDropdown, value)
            UIDropDownMenu_SetText(channelDropdown, label)
            SetStatus(L["播放频道已切换为："] .. label, false)
        end
        UIDropDownMenu_AddButton(info)
    end
end)
ApplyVoicePanelTheme("StyleDropDown", channelDropdown)

local configSection = CreateVoiceSettingsSection(VoicePanel, 24, -254, 1062, 512, L["语音配置 · 每类 20 项"])

local victorySettingsFrame = CreateFrame("Frame", nil, configSection)
victorySettingsFrame:SetPoint("TOPLEFT", configSection, "TOPLEFT", 14, -76)
victorySettingsFrame:SetSize(1004, 416)
victorySettingsFrame:Hide()
local RefreshVictorySettings, RefreshCharacterEventSettings

do
    local enableCheck = CreateFrame("CheckButton", "P5VoiceVictoryEnabledCheck", victorySettingsFrame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 0, -4)
    enableCheck:SetSize(22, 22)
    local enableLabel = enableCheck.Text or _G[enableCheck:GetName() .. "Text"]
    enableLabel:ClearAllPoints()
    enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 6, 0)
    enableLabel:SetText(L["启用胜利语音"])
    ApplyVoicePanelTheme("StyleCheckBox", enableCheck)
    enableCheck:SetScript("OnClick", function(self)
        EnsureDatabase()
        P5S_Voice_DB.victorySettings.enabled = not not self:GetChecked()
        ResetVictoryPlayback()
        SetStatus(self:GetChecked() and L["胜利语音已开启，将从下一场战斗开始判断。"] or L["胜利语音已关闭，待播放语音已取消。"], false)
    end)

    local enemyLabel = victorySettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enemyLabel:SetPoint("TOPLEFT", 0, -54)
    enemyLabel:SetText(L["适用敌人："])
    ApplyVoicePanelTheme("StyleBodyText", enemyLabel)

    local enemyDropdown = CreateFrame("Frame", "P5VoiceVictoryEnemyDropdown", victorySettingsFrame, "UIDropDownMenuTemplate")
    enemyDropdown:SetPoint("TOPLEFT", 84, -42)
    UIDropDownMenu_SetWidth(enemyDropdown, 260)

    local protectionCheck = CreateFrame("CheckButton", "P5VoiceVictoryProtectionCheck", victorySettingsFrame, "UICheckButtonTemplate")
    protectionCheck:SetPoint("TOPLEFT", 416, -49)
    protectionCheck:SetSize(22, 22)
    local protectionLabel = protectionCheck.Text or _G[protectionCheck:GetName() .. "Text"]
    protectionLabel:ClearAllPoints()
    protectionLabel:SetPoint("LEFT", protectionCheck, "RIGHT", 6, 0)
    protectionLabel:SetText(L["防连续播放保护"])
    ApplyVoicePanelTheme("StyleCheckBox", protectionCheck)

    local protectionHelp = victorySettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    protectionHelp:SetPoint("TOPLEFT", 588, -50)
    protectionHelp:SetWidth(416)
    protectionHelp:SetJustifyH("LEFT")
    protectionHelp:SetText(L["战斗至少 10 秒，连续脱战 2 秒后播放；\n两次胜利语音至少间隔 60 秒。"])
    ApplyVoicePanelTheme("StyleMutedText", protectionHelp)

    local pendingNote = victorySettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pendingNote:SetPoint("TOPLEFT", 200, -8)
    pendingNote:SetWidth(804)
    pendingNote:SetJustifyH("LEFT")
    pendingNote:SetText(L["设置自动保存；开启并选择主音频后，从下一场战斗开始判断胜利。"])
    ApplyVoicePanelTheme("StyleMutedText", pendingNote)

    local audioButton = CreateFrame("Button", "P5VoiceVictoryAudioButton", victorySettingsFrame, "UIPanelButtonTemplate")
    audioButton:SetPoint("TOPLEFT", 0, -104)
    audioButton:SetSize(400, 30)
    audioButton:SetText(L["选择主音频"])
    audioButton:SetScript("OnClick", function() OpenAudioPicker("victory", 1, "audio1") end)
    ApplyVoicePanelTheme("StyleButton", audioButton)

    local selectedText = victorySettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selectedText:SetPoint("TOPLEFT", 0, -146)
    selectedText:SetWidth(1004)
    selectedText:SetJustifyH("LEFT")
    ApplyVoicePanelTheme("StyleBodyText", selectedText)

    local previewButton = CreateFrame("Button", "P5VoiceVictoryPreviewButton", victorySettingsFrame, "UIPanelButtonTemplate")
    previewButton:SetPoint("TOPLEFT", 416, -104)
    previewButton:SetSize(84, 30)
    previewButton:SetText(L["试听"])
    previewButton:SetScript("OnClick", function()
        StopAudioPreview()
        EnsureDatabase()
        local audioID = GetRandomMainAudioID(P5S_Voice_DB.victorySettings.mainAudio)
        if audioID then PlayAudioFile(audioID, false, true)
        else SetStatus(L["请先选择至少一条有效的胜利主音频。"], true) end
    end)
    ApplyVoicePanelTheme("StyleButton", previewButton)

    local clearButton = CreateFrame("Button", "P5VoiceVictoryClearButton", victorySettingsFrame, "UIPanelButtonTemplate")
    clearButton:SetPoint("TOPLEFT", 512, -104)
    clearButton:SetSize(84, 30)
    clearButton:SetText(L["清空"])
    clearButton:SetScript("OnClick", function()
        EnsureDatabase()
        ClearMainAudioChoices(P5S_Voice_DB.victorySettings.mainAudio)
        ResetVictoryPlayback()
        RefreshVictorySettings()
        if pickerTarget and pickerTarget.sectionKey == "victory" then RefreshAudioPickerResults(true) end
        SetStatus(L["已清空胜利语音池；开关和敌人类型设置已保留。"], false)
    end)
    ApplyVoicePanelTheme("StyleButton", clearButton)

    local rulesSection = CreateVoiceSettingsSection(victorySettingsFrame, 0, -184, 1004, 224, L["胜利语音规则"])
    local rules = rulesSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rules:SetPoint("TOPLEFT", 18, -38)
    rules:SetWidth(968)
    rules:SetJustifyH("LEFT")
    rules:SetText(
        L["开启后：仅在所选敌人类型的战斗确认胜利时，从主音频池随机播放一条；无需绑定技能。\n\n"]
        .. L["胜利判断：副本 Boss 以成功结果为准；其他敌人须安全记录交战并确认记录中的敌人全部死亡，信息受限时跳过。\n\n"]
        .. L["死亡与失败：玩家仍然死亡或处于灵魂状态、团灭、战斗失败不播；仅仅脱战不算胜利，复活后不补播。\n\n"]
        .. L["开启保护：战斗至少 10 秒，连续脱战 2 秒，且距上次胜利播放至少 60 秒；等待期间重新进战则取消，不排队补播。\n\n"]
        .. L["关闭保护：取消上述时长与间隔限制；仍需确认胜利、排除死亡与失败，同一场战斗最多播放一次。"]
    )
    ApplyVoicePanelTheme("StyleBodyText", rules)

    RefreshVictorySettings = function()
        EnsureDatabase()
        local settings = P5S_Voice_DB.victorySettings
        local count, selectedLabel = 0, nil
        for _, option in ipairs(victoryEnemyOptions) do
            if settings.enemyTypes[option.key] then
                count = count + 1
                selectedLabel = option.label
            end
        end
        local summary = count == 0 and L["未选择敌人类型"]
            or (count == 1 and selectedLabel or L["已选择 "] .. count .. L[" 类敌人（可多选）"])
        UIDropDownMenu_SetText(enemyDropdown, summary)
        protectionCheck:SetChecked(settings.antiSpamEnabled)
        enableCheck:SetChecked(settings.enabled)
        local choices = GetMainAudioChoices(settings.mainAudio)
        local available = 0
        for _, audioID in ipairs(choices) do
            if audioItemsByID[audioID] then available = available + 1 end
        end
        selectedText:SetText(#choices == 0 and L["尚未选择主音频；支持多选，每次随机播放一条。"]
            or L["已选 "] .. #choices .. L[" 条主音频（可播放 "] .. available .. L[" 条）；点击“选择主音频”可查看或取消选择。"])
    end

    UIDropDownMenu_Initialize(enemyDropdown, function(_, level)
        EnsureDatabase()
        for _, option in ipairs(victoryEnemyOptions) do
            local key = option.key
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = key
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.checked = function() return P5S_Voice_DB.victorySettings.enemyTypes[key] end
            info.func = function()
                EnsureDatabase()
                local selected = P5S_Voice_DB.victorySettings.enemyTypes
                selected[key] = not selected[key]
                ResetVictoryPlayback()
                RefreshVictorySettings()
                SetStatus(L["胜利语音适用敌人已保存，将从下一场战斗使用新设置。"], false)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    ApplyVoicePanelTheme("StyleDropDown", enemyDropdown)

    protectionCheck:SetScript("OnClick", function(self)
        EnsureDatabase()
        P5S_Voice_DB.victorySettings.antiSpamEnabled = not not self:GetChecked()
        ResetVictoryPlayback()
        SetStatus(L["防连续播放保护选项已保存，将从下一场战斗使用新设置。"], false)
    end)
    victorySettingsFrame:SetScript("OnShow", RefreshVictorySettings)
    victorySettingsFrame:SetScript("OnHide", function()
        if UIDROPDOWNMENU_OPEN_MENU == enemyDropdown then CloseDropDownMenus() end
    end)
end

local characterEventsFrame = CreateFrame("Frame", nil, configSection)
characterEventsFrame:SetPoint("TOPLEFT", configSection, "TOPLEFT", 14, -76)
characterEventsFrame:SetSize(1004, 416)
characterEventsFrame:Hide()
do
    local controls = {}
    for index, definition in ipairs(characterEventDefinitions) do
        local key, title = definition.key, definition.title
        local card = CreateVoiceSettingsSection(characterEventsFrame, 0, -((index - 1) * 92), 1004, 84, title)
        local help = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        help:SetPoint("TOPLEFT", 160, -12)
        help:SetWidth(824)
        help:SetJustifyH("LEFT")
        help:SetText(definition.help)
        ApplyVoicePanelTheme("StyleMutedText", help)

        local check = CreateFrame("CheckButton", "P5VoiceCharacter" .. key .. "Enabled", card, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 14, -40)
        check:SetSize(22, 22)
        local label = check.Text or _G[check:GetName() .. "Text"]
        label:ClearAllPoints()
        label:SetPoint("LEFT", check, "RIGHT", 6, 0)
        label:SetText(L["启用"])
        ApplyVoicePanelTheme("StyleCheckBox", check)
        check:SetScript("OnClick", function(self)
            EnsureDatabase()
            P5S_Voice_DB.characterEvents[key].enabled = not not self:GetChecked()
            ResetCharacterEventPlayback()
            SetStatus(title .. (self:GetChecked() and L["已开启；从下一次对应事件生效。"] or L["已关闭。"]), false)
        end)

        local audio = CreateFrame("Button", "P5VoiceCharacter" .. key .. "Audio", card, "UIPanelButtonTemplate")
        audio:SetPoint("TOPLEFT", 120, -36)
        audio:SetSize(400, 30)
        audio:SetText(L["选择主音频"])
        audio:SetScript("OnClick", function() OpenAudioPicker("characterEvents", key, "audio1") end)
        ApplyVoicePanelTheme("StyleButton", audio)

        local preview = CreateFrame("Button", "P5VoiceCharacter" .. key .. "Preview", card, "UIPanelButtonTemplate")
        preview:SetPoint("TOPLEFT", 532, -36)
        preview:SetSize(84, 30)
        preview:SetText(L["试听"])
        preview:SetScript("OnClick", function()
            StopAudioPreview()
            EnsureDatabase()
            local audioID = GetRandomMainAudioID(GetVoiceAudioEntry("characterEvents", key))
            if audioID then PlayAudioFile(audioID, false, true)
            else SetStatus(L["请先选择至少一条有效的"] .. title .. L["。"], true) end
        end)
        ApplyVoicePanelTheme("StyleButton", preview)

        local clear = CreateFrame("Button", "P5VoiceCharacter" .. key .. "Clear", card, "UIPanelButtonTemplate")
        clear:SetPoint("TOPLEFT", 628, -36)
        clear:SetSize(84, 30)
        clear:SetText(L["清空"])
        clear:SetScript("OnClick", function()
            EnsureDatabase()
            ClearMainAudioChoices(GetVoiceAudioEntry("characterEvents", key))
            ResetCharacterEventPlayback()
            RefreshCharacterEventSettings()
            if pickerTarget and pickerTarget.sectionKey == "characterEvents" and pickerTarget.index == key then
                RefreshAudioPickerResults(true)
            end
            SetStatus(L["已清空"] .. title .. L["的音频选择；开关保持原样。"], false)
        end)
        ApplyVoicePanelTheme("StyleButton", clear)

        local summary = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summary:SetPoint("TOPLEFT", 728, -42)
        summary:SetWidth(256)
        summary:SetJustifyH("LEFT")
        ApplyVoicePanelTheme("StyleBodyText", summary)
        controls[key] = { check = check, summary = summary }
    end

    local note = characterEventsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 14, -374)
    note:SetWidth(976)
    note:SetJustifyH("LEFT")
    note:SetText(L["四项独立开关，默认关闭；在“角色事件”分类选择音频，多选后每次随机播放一条，设置随语音方案保存。\n复活包含他人复活、跑尸、灵魂医者及灵魂石等自我复活；选择音频不播放，点击“试听”才试听。"])
    ApplyVoicePanelTheme("StyleMutedText", note)

    RefreshCharacterEventSettings = function()
        EnsureDatabase()
        for _, definition in ipairs(characterEventDefinitions) do
            local settings = P5S_Voice_DB.characterEvents[definition.key]
            local control = controls[definition.key]
            control.check:SetChecked(settings.enabled)
            local choices, available = GetMainAudioChoices(settings.mainAudio), 0
            for _, audioID in ipairs(choices) do
                if audioItemsByID[audioID] then available = available + 1 end
            end
            control.summary:SetText(#choices == 0 and L["尚未选择主音频"]
                or L["已选 "] .. #choices .. L[" 条，可播放 "] .. available .. L[" 条"])
        end
    end
    characterEventsFrame:SetScript("OnShow", RefreshCharacterEventSettings)
end

local tableHeader = CreateFrame("Frame", nil, configSection, "BackdropTemplate")
tableHeader:SetPoint("TOPLEFT", configSection, "TOPLEFT", 14, -76)
tableHeader:SetSize(1004, 24)
tableHeader:SetBackdrop(CONTROL_BACKDROP)
tableHeader:SetBackdropColor(0.050, 0.058, 0.080, 0.94)
tableHeader:SetBackdropBorderColor(0.28, 0.32, 0.40, 0.72)

local function CreateColumnTitle(text, x, width)
    local title = tableHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    title:SetPoint("LEFT", x, 0)
    title:SetWidth(width)
    title:SetJustifyH("LEFT")
    title:SetText(text)
    ApplyVoicePanelTheme("StyleMutedText", title)
end

CreateColumnTitle(L["序号"], 8, 32)
CreateColumnTitle(L["技能名称 / Spell ID"], 48, 220)
CreateColumnTitle(L["主音频（可多选）"], 282, 260)
CreateColumnTitle(L["叠加音频（可选）"], 554, 260)
CreateColumnTitle(L["操作"], 826, 160)

local rowScroll = CreateFrame("ScrollFrame", "P5VoiceRowsScroll", configSection, "UIPanelScrollFrameTemplate")
rowScroll:SetPoint("TOPLEFT", configSection, "TOPLEFT", 14, -106)
rowScroll:SetPoint("BOTTOMRIGHT", configSection, "BOTTOMRIGHT", -28, 14)

local rowContent = CreateFrame("Frame", nil, rowScroll)
rowContent:SetSize(1004, 1)
rowScroll:SetScrollChild(rowContent)

local function SetAudioButtonText(button, audioID)
    if not audioID or audioID == "" then
        button:SetText(L["选择音频…"])
    elseif not audioItemsByID[audioID] then
        button:SetText(L["|cffff5555缺失：|r"] .. audioID)
    else
        button:SetText(GetAudioDisplayName(audioID))
    end
end

local function SetMainAudioButtonText(button, entry)
    local choices = GetMainAudioChoices(entry)
    if #choices == 0 then
        button:SetText(L["选择主音频…"])
    elseif #choices == 1 then
        SetAudioButtonText(button, choices[1])
    else
        button:SetText(L["随机播放 "] .. tostring(#choices) .. L[" 条语音"])
    end
end

RefreshVoiceRow = function(sectionKey, index, refreshInput)
    EnsureDatabase()
    if sectionKey == "victory" then
        RefreshVictorySettings()
        return
    end
    if sectionKey == "characterEvents" then
        RefreshCharacterEventSettings()
        return
    end
    local entry = P5S_Voice_DB.inputs[sectionKey][index]
    local row = voiceRows[sectionKey][index]
    if not row then return end

    if refreshInput ~= false then
        row.editBox:SetText(entry.input or "")
    end
    SetMainAudioButtonText(row.audio1Button, entry)
    SetAudioButtonText(row.audio2Button, entry.audio2)
end

local function ShowAudioButtonTooltip(button, sectionKey, index, slotKey)
    EnsureDatabase()
    local entry = P5S_Voice_DB.inputs[sectionKey][index]

    if slotKey == "audio1" then
        local choices = GetMainAudioChoices(entry)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

        if #choices == 0 then
            GameTooltip:SetText(L["尚未选择主音频"], 1, 1, 1)
            GameTooltip:AddLine(L["点击打开选择器；主音频支持多选和随机播放。"], 0.8, 0.8, 0.8)
        elseif #choices == 1 then
            local item = audioItemsByID[choices[1]]
            if item then
                local source = audioSourcesByKey[item.sourceKey]
                GameTooltip:SetText(item.displayName, 1, 1, 1)
                GameTooltip:AddLine(L["角色："] .. (item.shared and L["P5 雨宫莲 / P3 结城理通用"] or (source and source.label or item.sourceKey)), 0.8, 0.8, 0.8)
                GameTooltip:AddLine(L["当前主音频共 1 条；点击可继续添加随机语音。"], 0.8, 0.8, 0.8)
            else
                GameTooltip:SetText(L["找不到主音频："] .. choices[1], 1, 0.35, 0.35)
                GameTooltip:AddLine(L["点击打开选择器，可移除此项或添加其他语音。"], 0.8, 0.8, 0.8)
            end
        else
            GameTooltip:SetText(L["已选择 "] .. tostring(#choices) .. L[" 个主音频"], 1, 1, 1)
            GameTooltip:AddLine(L["每次触发会从以下语音中随机播放一条："], 0.8, 0.8, 0.8)
            local shownChoiceCount = math.min(#choices, 6)
            for choiceIndex = 1, shownChoiceCount do
                local audioID = choices[choiceIndex]
                local prefix = audioItemsByID[audioID] and "- " or L["- 缺失："]
                GameTooltip:AddLine(prefix .. GetAudioDisplayName(audioID), 0.72, 0.82, 1.0)
            end
            if #choices > shownChoiceCount then
                GameTooltip:AddLine(L["另有 "] .. tostring(#choices - shownChoiceCount) .. L[" 条……"], 0.6, 0.62, 0.68)
            end
            GameTooltip:AddLine(L["点击继续添加或取消选择。"], 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
        return
    end

    local audioID = entry.audio2
    local item = audioItemsByID[audioID]
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if item then
        local source = audioSourcesByKey[item.sourceKey]
        GameTooltip:SetText(item.displayName, 1, 1, 1)
        GameTooltip:AddLine(L["角色："] .. (item.shared and L["P5 雨宫莲 / P3 结城理通用"] or (source and source.label or item.sourceKey)), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["点击重新选择；可在选择器中清除此项。"], 0.8, 0.8, 0.8)
    elseif audioID then
        GameTooltip:SetText(L["找不到音频："] .. audioID, 1, 0.35, 0.35)
        GameTooltip:AddLine(L["点击重新选择；可在选择器中清除此项。"], 0.8, 0.8, 0.8)
    else
        GameTooltip:SetText(L["尚未选择音频"], 1, 1, 1)
        GameTooltip:AddLine(L["点击打开音频选择器。"], 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function CreateVoiceRow(sectionKey, index, y, alternate, sectionColor)
    local row = CreateFrame("Frame", nil, rowContent)
    row:SetSize(1004, 38)
    row:SetPoint("TOPLEFT", 0, y)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    if alternate then
        bg:SetColorTexture(0.055, 0.062, 0.085, 0.72)
    else
        bg:SetColorTexture(0.030, 0.035, 0.052, 0.56)
    end

    local separator = row:CreateTexture(nil, "BORDER")
    separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    separator:SetHeight(1)
    separator:SetColorTexture(0.28, 0.32, 0.40, 0.22)

    local numberText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    numberText:SetPoint("LEFT", 8, 0)
    numberText:SetWidth(32)
    numberText:SetText(string.format("%02d", index))
    if sectionColor then
        numberText:SetTextColor(sectionColor[1], sectionColor[2], sectionColor[3], 1)
    end

    local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    editBox:SetSize(220, 26)
    editBox:SetPoint("LEFT", 48, 0)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(255)
    editBox.p5VoiceSectionKey = sectionKey
    editBox.p5VoiceIndex = index
    editBox:HookScript("OnTextChanged", function(self)
        if self:HasFocus() and RefreshVoiceProfiles then RefreshVoiceProfiles() end
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        SaveVoiceInput(sectionKey, index, self)
        self.p5SkipFocusSave = true
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        RefreshVoiceRow(sectionKey, index, true)
        self.p5SkipFocusSave = true
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        activeVoiceInput = self
        InstallSpellLinkInputHook()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        if activeVoiceInput == self then activeVoiceInput = nil end
        if self.p5SkipFocusSave then
            self.p5SkipFocusSave = nil
            return
        end
        SaveVoiceInput(sectionKey, index, self)
    end)
    editBox:SetScript("OnEnter", function(self)
        EnsureDatabase()
        local entry = P5S_Voice_DB.inputs[sectionKey][index]
        local spellIDs = GetSortedSpellIDs(entry)
        local spellIDTexts = {}
        for _, spellID in ipairs(spellIDs) do table.insert(spellIDTexts, tostring(spellID)) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if #spellIDs > 0 then
            GameTooltip:SetText(entry.input ~= "" and entry.input or L["已解析技能"], 1, 1, 1)
            GameTooltip:AddLine("Spell ID: " .. table.concat(spellIDTexts, ", "), 0.5, 1, 0.5, true)
        else
            GameTooltip:SetText(L["技能尚未解析"], 1, 0.8, 0.2)
            GameTooltip:AddLine(L["可用逗号分隔多个技能；按回车或点击其他位置保存。"], 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    editBox:SetScript("OnLeave", GameTooltip_Hide)
    ApplyVoicePanelTheme("StyleEditBox", editBox)

    local audio1Button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    audio1Button:SetSize(260, 25)
    audio1Button:SetPoint("LEFT", 282, 0)
    if audio1Button:GetFontString() then
        local fontString = audio1Button:GetFontString()
        fontString:SetSize(240, 20)
        if fontString.SetWordWrap then fontString:SetWordWrap(false) end
        if fontString.SetMaxLines then fontString:SetMaxLines(1) end
    end
    audio1Button:SetScript("OnClick", function() OpenAudioPicker(sectionKey, index, "audio1") end)
    audio1Button:SetScript("OnEnter", function(self) ShowAudioButtonTooltip(self, sectionKey, index, "audio1") end)
    audio1Button:SetScript("OnLeave", GameTooltip_Hide)
    ApplyVoicePanelTheme("StyleButton", audio1Button)

    local audio2Button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    audio2Button:SetSize(260, 25)
    audio2Button:SetPoint("LEFT", 554, 0)
    if audio2Button:GetFontString() then
        local fontString = audio2Button:GetFontString()
        fontString:SetSize(240, 20)
        if fontString.SetWordWrap then fontString:SetWordWrap(false) end
        if fontString.SetMaxLines then fontString:SetMaxLines(1) end
    end
    audio2Button:SetScript("OnClick", function() OpenAudioPicker(sectionKey, index, "audio2") end)
    audio2Button:SetScript("OnEnter", function(self) ShowAudioButtonTooltip(self, sectionKey, index, "audio2") end)
    audio2Button:SetScript("OnLeave", GameTooltip_Hide)
    ApplyVoicePanelTheme("StyleButton", audio2Button)

    local previewButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    previewButton:SetSize(74, 25)
    previewButton:SetPoint("LEFT", 826, 0)
    previewButton:SetText(L["试听"])
    previewButton:SetScript("OnClick", function()
        EnsureDatabase()
        local entry = P5S_Voice_DB.inputs[sectionKey][index]
        local played, mainAudioID = PlayConfiguredEntry(sectionKey, index, true)
        if played then
            local randomNote = mainAudioID and #GetMainAudioChoices(entry) > 1
                and L["；本次随机："] .. GetAudioDisplayName(mainAudioID)
                or ""
            SetStatus(
                L["正在试听第 "] .. string.format("%02d", index) .. L[" 行的音频组合"]
                .. randomNote .. L["（"] .. channelLabels[P5S_Voice_DB.channel] .. L["）。"],
                false
            )
        else
            SetStatus(L["当前行没有可播放的有效音频。"], true)
        end
    end)
    ApplyVoicePanelTheme("StyleButton", previewButton)

    local clearButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    clearButton:SetSize(68, 25)
    clearButton:SetPoint("LEFT", 912, 0)
    clearButton:SetText(L["清空"])
    clearButton:SetScript("OnClick", function()
        EnsureDatabase()
        local entry = P5S_Voice_DB.inputs[sectionKey][index]
        entry.input = ""
        SetEntrySpellMap(entry, {})
        ClearMainAudioChoices(entry)
        entry.audio2 = nil
        RebuildVoiceTriggerMap()
        RefreshVoiceRow(sectionKey, index, true)
        SetStatus(L["已清空当前整行配置。"], false)
    end)
    ApplyVoicePanelTheme("StyleButton", clearButton)

    row.editBox = editBox
    row.audio1Button = audio1Button
    row.audio2Button = audio2Button
    voiceInputs[sectionKey][index] = editBox
    voiceRows[sectionKey][index] = row
end

local sectionTabs = {}
local activeVoiceSection
local SelectVoiceSection

local function UpdateVoiceSectionTabStyle(button)
    local color = button.p5TabColor
    if not color or not button.SetBackdropColor then return end

    local colors = GetVoiceThemeColors()
    local highlighted = button.p5TabSelected or button:IsMouseOver()
    local background = highlighted and colors.controlHover or colors.controlBackground
    local border = highlighted and color or colors.controlBorder
    -- 将原悬浮效果合入背景，选中后移开鼠标仍保持同样的色块。
    local tint = highlighted and 0.15 or 0
    button:SetBackdropColor(
        background[1] * (1 - tint) + color[1] * tint,
        background[2] * (1 - tint) + color[2] * tint,
        background[3] * (1 - tint) + color[3] * tint,
        background[4] or 1
    )
    button:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function StyleVoiceSectionTab(button, color)
    local accent = button:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    accent:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    accent:SetHeight(3)
    SetTextureColor(accent, color)
    accent:Hide()
    button.p5SelectionAccent = accent
    button.p5TabColor = color

    HideButtonTemplateChrome(button)
    if EnsureBackdrop(button) then button:SetBackdrop(CONTROL_BACKDROP) end
    -- 本地背景负责选中与悬浮反馈，避免通用红色高亮再次叠加。
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetColorTexture(0, 0, 0, 0) end
    local function RefreshStyle(self)
        ApplyVoiceLocalStyle("UpdateVoiceSectionTabStyle", UpdateVoiceSectionTabStyle, self)
    end
    for _, script in ipairs({ "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnShow" }) do
        button:HookScript(script, RefreshStyle)
    end
    RefreshStyle(button)
end

for tabIndex, definition in ipairs(sectionDefinitions) do
    local sectionKey = definition.key
    local button = CreateFrame("Button", nil, configSection, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", configSection, "TOPLEFT", 14 + ((tabIndex - 1) * 169), -34)
    button:SetSize(159, 30)
    button:SetText(definition.title)
    button:SetScript("OnClick", function() SelectVoiceSection(sectionKey) end)
    ApplyVoicePanelTheme("StyleButton", button)
    ApplyVoiceLocalStyle("StyleVoiceSectionTab", StyleVoiceSectionTab, button, definition.lineColor)
    sectionTabs[sectionKey] = button

    -- 各组复用同一可视区域，行始终绑定原分组与序号，避免切换时串写配置。
    for index = 1, definition.count do
        CreateVoiceRow(sectionKey, index, -4 - ((index - 1) * 40), index % 2 == 0, definition.lineColor)
        voiceRows[sectionKey][index]:Hide()
    end
end

SelectVoiceSection = function(sectionKey)
    if not sectionTabs[sectionKey] or activeVoiceSection == sectionKey then return end
    SaveActiveVoiceInput()
    AudioPicker:Hide()
    pickerTarget = nil
    activeVoiceSection = sectionKey

    local victorySelected = sectionKey == "victory"
    local eventsSelected = sectionKey == "characterEvents"
    victorySettingsFrame:SetShown(victorySelected)
    characterEventsFrame:SetShown(eventsSelected)
    tableHeader:SetShown(not victorySelected and not eventsSelected)
    rowScroll:SetShown(not victorySelected and not eventsSelected)
    configSection.Title:SetText(eventsSelected and L["角色事件语音配置"] or (victorySelected and L["胜利语音配置"] or L["语音配置 · 每类 20 项"]))
    description:SetText(eventsSelected and L["分别设置死亡、复活、升级和切换专精语音；开启对应选项并选择主音频即可，无需绑定技能。"] or (victorySelected
        and L["选择想听的胜利主音频，可多选；试听会随机播放其中一条，清空只移除语音选择。"]
        or L["每行可用逗号分隔多个技能名称 / Spell ID；按回车或点击其他位置会自动保存。"]))
    cooldownDescription:SetText(eventsSelected and L["只在对应事件发生时播放；登录、重载不会补播，释放灵魂不算复活。"] or (victorySelected
        and L["自动播放遵循敌人筛选、胜利确认和保护规则；手动试听不受总开关与保护间隔限制。"]
        or L["技能冷却完毕语音监测普通与充能技能；充能每恢复一层播放一次，并忽略公共冷却。"]))

    for _, definition in ipairs(sectionDefinitions) do
        local selected = definition.key == sectionKey
        for index = 1, definition.count do
            local row = voiceRows[definition.key][index]
            if selected and VoicePanel:IsShown() then
                RefreshVoiceRow(definition.key, index, true)
            end
            row:SetShown(selected)
        end
        local button = sectionTabs[definition.key]
        button.p5TabSelected = selected
        local accent = button.p5SelectionAccent
        if accent then accent:SetShown(selected) end
        ApplyVoiceLocalStyle("UpdateVoiceSectionTabStyle", UpdateVoiceSectionTabStyle, button)
        if selected then rowContent:SetHeight(4 + (definition.count * 40) + 8) end
    end
    rowScroll:SetVerticalScroll(0)
end
SelectVoiceSection("skill")

RefreshVoiceInputs = function()
    EnsureDatabase()
    for _, definition in ipairs(sectionDefinitions) do
        for index = 1, definition.count do
            RefreshVoiceRow(definition.key, index, true)
        end
    end
    UIDropDownMenu_SetSelectedValue(channelDropdown, P5S_Voice_DB.channel)
    UIDropDownMenu_SetText(channelDropdown, channelLabels[P5S_Voice_DB.channel])
    RefreshVictorySettings()
    RefreshCharacterEventSettings()
    if RefreshVoiceProfiles then RefreshVoiceProfiles() end
end

-- 方案是独立快照；inputs / victorySettings / characterEvents 保留当前工作配置。
do
    local function Copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for key, item in pairs(value) do result[key] = Copy(item) end
        return result
    end

    local function Snapshot(includeDraft)
        local db = P5S_Voice_DB
        local result = { channel = db.channel, inputs = {}, victorySettings = Copy(db.victorySettings),
            characterEvents = Copy(db.characterEvents) }
        for _, definition in ipairs(sectionDefinitions) do
            if definition.count > 0 then
                local rows = {}
                result.inputs[definition.key] = rows
                for index = 1, definition.count do
                    local entry = db.inputs[definition.key][index]
                    rows[index] = {
                        input = entry.input or "", spellIDs = Copy(entry.spellIDs),
                        audio1Choices = Copy(entry.audio1Choices), audio1 = entry.audio1, audio2 = entry.audio2,
                    }
                end
            end
        end
        if includeDraft and activeVoiceInput and activeVoiceInput:HasFocus() then
            local rows = result.inputs[activeVoiceInput.p5VoiceSectionKey]
            if rows then rows[activeVoiceInput.p5VoiceIndex].input = TrimText(activeVoiceInput:GetText()) end
        end
        return result
    end

    local function EqualSettings(left, right)
        if type(left) ~= type(right) then return false end
        if type(left) ~= "table" then return left == right end
        for key, value in pairs(left) do
            -- 名称重新解析的缓存变化不算用户修改，快照仍保留 ID 用于恢复。
            if key ~= "spellIDs" and not EqualSettings(value, right[key]) then return false end
        end
        for key in pairs(right) do
            if key ~= "spellIDs" and left[key] == nil then return false end
        end
        return true
    end

    EnsureVoiceProfiles = function()
        local db = P5S_Voice_DB
        if db.profiles == nil then
            db.profiles = {
                version = 1, nextID = 2, activeID = 1, order = { 1 },
                items = { [1] = { name = L["初始方案"], data = Snapshot(false) } },
            }
        end
        local library = db.profiles
        if type(library) == "table" and library.version == 1 and type(library.items) == "table"
            and type(library.order) == "table" and library.characterEventsVersion ~= 2 then
            for _, profile in pairs(library.items) do
                if type(profile) == "table" and type(profile.data) == "table" then
                    profile.data.characterEvents = NormalizeCharacterEventSettings(profile.data.characterEvents)
                end
            end
            library.characterEventsVersion = 2 -- 补齐缺少的角色事件，保留旧三项，不继承工作配置。
        end
    end

    local function Library()
        local library = P5S_Voice_DB and P5S_Voice_DB.profiles
        if type(library) == "table" and library.version == 1
            and type(library.items) == "table" and type(library.order) == "table" then return library end
    end

    local function Dirty()
        local library = Library()
        local profile = library and library.items[library.activeID]
        return not profile or not EqualSettings(Snapshot(true), profile.data)
    end

    local function DisplayName(name)
        return (name or L["未命名配置"]):gsub("|", "||")
    end

    local function Plain(value, expected)
        if type(issecretvalue) ~= "function" then return false end
        local ok, secret = pcall(issecretvalue, value)
        return ok and not secret and type(value) == expected
    end

    local profileSection = CreateVoiceSettingsSection(VoicePanel, 24, -154, 1062, 88, L["语音方案 · 当前角色"])
    local specText = profileSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specText:SetPoint("TOPRIGHT", profileSection, "TOPRIGHT", -18, -12)
    specText:SetWidth(560)
    specText:SetJustifyH("RIGHT")
    ApplyVoicePanelTheme("StyleBodyText", specText)
    local function RefreshSpecialization()
        local label = L["当前专精：暂不可用"]
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
        if type(getSpec) == "function" and type(getInfo) == "function" then
            local ok, index = pcall(getSpec)
            if ok and Plain(index, "number") and index > 0 then
                local infoOK, _, name, _, _, role = pcall(getInfo, index)
                if infoOK and Plain(name, "string") then
                    local classOK, className = false, nil
                    if type(UnitClass) == "function" then classOK, className = pcall(UnitClass, "player") end
                    local classLabel = classOK and Plain(className, "string") and (className .. " · ") or ""
                    local roles = { TANK = L["坦克"], HEALER = L["治疗"], DAMAGER = L["输出"] }
                    local roleLabel = Plain(role, "string") and roles[role] or nil
                    label = L["当前专精："] .. classLabel .. name .. (roleLabel and (L["（"] .. roleLabel .. L["）"]) or "")
                end
            elseif ok and (Plain(index, "nil") or (Plain(index, "number") and index == 0)) then
                label = L["当前专精：尚未选择"]
            end
        end
        specText:SetText(label)
    end

    local dropdown = CreateFrame("Frame", "P5VoiceProfileDropdown", profileSection, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", profileSection, "TOPLEFT", 2, -30)
    UIDropDownMenu_SetWidth(dropdown, 360)
    ApplyVoicePanelTheme("StyleDropDown", dropdown)
    local profileState = profileSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    profileState:SetPoint("TOPLEFT", profileSection, "TOPLEFT", 18, -66)
    profileState:SetWidth(1000)
    profileState:SetJustifyH("LEFT")

    local function Button(parent, name, text, x, y, width)
        local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        button:SetSize(width or 94, 26)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        button:SetText(text)
        ApplyVoicePanelTheme("StyleButton", button)
        return button
    end
    local saveButton = Button(profileSection, "P5VoiceProfileSave", L["保存"], 410, -34)
    local newButton = Button(profileSection, "P5VoiceProfileSaveAs", L["另存为"], 516, -34)
    local manageButton = Button(profileSection, "P5VoiceProfileManage", L["管理…"], 622, -34)

    -- 模态遮罩阻止确认期间继续改动底层配置；关闭面板会取消操作。
    local overlay = CreateFrame("Frame", "P5VoiceProfileOverlay", VoicePanel)
    overlay:SetAllPoints(VoicePanel)
    overlay:SetFrameLevel(VoicePanel:GetFrameLevel() + 100)
    overlay:EnableMouse(true)
    local shade = overlay:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(overlay)
    shade:SetColorTexture(0, 0, 0, 0.65)
    local dialog = CreateFrame("Frame", "P5VoiceProfileDialog", overlay, "BackdropTemplate")
    dialog:SetSize(560, 260)
    dialog:SetPoint("CENTER", overlay, "CENTER")
    dialog:EnableMouse(true)
    dialog:SetBackdrop(CONTROL_BACKDROP)
    dialog:SetBackdropColor(0.035, 0.04, 0.06, 1)
    dialog:SetBackdropBorderColor(0.82, 0.07, 0.05, 1)
    local prompt = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    prompt:SetPoint("TOPLEFT", 22, -22)
    prompt:SetSize(516, 66)
    prompt:SetJustifyH("LEFT")
    prompt:SetJustifyV("TOP")
    local nameBox = CreateFrame("EditBox", "P5VoiceProfileName", dialog, "InputBoxTemplate")
    nameBox:SetSize(500, 28)
    nameBox:SetPoint("TOPLEFT", 28, -100)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)
    ApplyVoicePanelTheme("StyleEditBox", nameBox)
    local manager = CreateFrame("Frame", "P5VoiceProfileManageDropdown", dialog, "UIDropDownMenuTemplate")
    manager:SetPoint("TOPLEFT", 8, -96)
    UIDropDownMenu_SetWidth(manager, 484)
    ApplyVoicePanelTheme("StyleDropDown", manager)
    local errorText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    errorText:SetPoint("TOPLEFT", 22, -146)
    errorText:SetSize(516, 40)
    errorText:SetJustifyH("LEFT")
    errorText:SetTextColor(1, 0.75, 0.2)
    local buttons = {
        Button(dialog, "P5VoiceProfileConfirm", L["确定"], 22, -208, 166),
        Button(dialog, "P5VoiceProfileAlternate", "", 197, -208, 166),
        Button(dialog, "P5VoiceProfileCancel", L["取消"], 372, -208, 166),
    }
    local action, targetID, afterSaveID, manageID
    local OpenDialog, ApplyProfile, RequestSwitch
    local function CloseDialog()
        overlay:Hide()
        nameBox:ClearFocus()
        CloseDropDownMenus()
        action, targetID, afterSaveID = nil, nil, nil
    end
    overlay:Hide()

    RefreshVoiceProfiles = function()
        local library = Library()
        if not library then
            profileState:SetText(L["方案数据暂不可用；当前语音设置仍可使用。"])
            return
        end
        local profile = library.items[library.activeID]
        UIDropDownMenu_SetText(dropdown, DisplayName(profile and profile.name))
        local dirty = Dirty()
        profileState:SetText(dirty and L["有未保存到方案的修改 · 当前调整自动保留，点击“保存”更新命名方案。"]
            or L["与已保存方案一致 · 可另存多套配置；专精变化后请手动选择方案。"])
        profileState:SetTextColor(dirty and 1 or 0.6, dirty and 0.75 or 0.62, dirty and 0.2 or 0.68)
    end

    local function CanSwitch()
        if type(InCombatLockdown) ~= "function" then return false end
        local ok, combat = pcall(InCombatLockdown)
        if not ok or not Plain(combat, "boolean") or combat ~= false then
            SetStatus(L["战斗中不能切换语音方案，请脱战后重新选择。"], true)
            return false
        end
        return true
    end

    local function SaveCurrent()
        SaveActiveVoiceInput()
        local library = Library()
        local profile = library and library.items[library.activeID]
        if not profile then return false end
        profile.data = Snapshot(false)
        SetStatus(L["已保存语音方案："] .. DisplayName(profile.name), false)
        return true
    end

    ApplyProfile = function(id)
        if not CanSwitch() then CloseDialog(); return end
        local library = Library()
        local profile = library and library.items[id]
        if not profile or type(profile.data) ~= "table" or type(profile.data.inputs) ~= "table"
            or type(profile.data.victorySettings) ~= "table" then
            SetStatus(L["这个方案的数据不可用，当前配置未改变。"], true)
            return
        end
        SaveActiveVoiceInput()
        local data = Copy(profile.data)
        AudioPicker:Hide()
        pickerTarget = nil
        ResetVictoryPlayback() -- 不清除已成功播放时间，防止切换绕过限频。
        ResetCharacterEventPlayback()
        for _, watcher in pairs(cooldownWatchers) do ClearCooldownWatcher(watcher) end
        for _, definition in ipairs(sectionDefinitions) do
            if definition.count > 0 then P5S_Voice_DB.inputs[definition.key] = data.inputs[definition.key] or {} end
        end
        P5S_Voice_DB.victorySettings = data.victorySettings
        P5S_Voice_DB.characterEvents = data.characterEvents
        P5S_Voice_DB.channel = data.channel
        library.activeID = id
        EnsureDatabase()
        RebuildSpellBookNameCache()
        ReparseStoredSpellInputs()
        RefreshVoiceInputs()
        CloseDialog()
        local missing = {}
        local function CheckAudio(entry)
            for _, audioID in ipairs(GetMainAudioChoices(entry)) do
                if not audioItemsByID[audioID] then missing[audioID] = true end
            end
            if entry.audio2 and not audioItemsByID[entry.audio2] then missing[entry.audio2] = true end
        end
        for _, definition in ipairs(sectionDefinitions) do
            for index = 1, definition.count do CheckAudio(P5S_Voice_DB.inputs[definition.key][index]) end
        end
        CheckAudio(P5S_Voice_DB.victorySettings.mainAudio)
        for _, definition in ipairs(characterEventDefinitions) do
            CheckAudio(P5S_Voice_DB.characterEvents[definition.key].mainAudio)
        end
        local missingCount = 0
        for _ in pairs(missing) do missingCount = missingCount + 1 end
        local note = missingCount > 0 and (L["；有 "] .. missingCount .. L[" 条音频目录项缺失，保留选择并跳过播放。"])
            or L["；之后的施法、战斗及角色事件使用新设置。"]
        SetStatus(L["已切换语音方案："] .. DisplayName(profile.name) .. note, missingCount > 0)
    end

    OpenDialog = function(mode, id, nextID)
        SaveActiveVoiceInput()
        AudioPicker:Hide()
        CloseDropDownMenus()
        action, targetID, afterSaveID = mode, id, nextID
        errorText:SetText("")
        nameBox:Hide()
        manager:Hide()
        buttons[2]:Hide()
        buttons[1]:SetText(L["确定"])
        buttons[3]:SetText(L["取消"])
        local library = Library()
        local profile = library and library.items[id]
        if mode == "name" or mode == "rename" then
            prompt:SetText(mode == "name" and L["另存为语音方案\n输入名称（最多 40 个字符，不能与已有方案重名）。"]
                or L["重命名语音方案\n只修改名称，保存内容保持不变。"])
            nameBox:SetText(mode == "rename" and profile and profile.name or "")
            nameBox:Show()
        elseif mode == "switch" then
            prompt:SetText(L["当前调整尚未保存到方案。\n切换到“"] .. DisplayName(profile and profile.name) .. L["”之前，要保存吗？"])
            buttons[1]:SetText(L["保存并切换"])
            buttons[2]:SetText(L["不保存，直接切换"])
            buttons[2]:Show()
        elseif mode == "delete" then
            prompt:SetText(L["确认删除语音方案“"] .. DisplayName(profile and profile.name) .. L["”？\n此操作无法撤销；当前正在使用的语音配置会保留。"])
            buttons[1]:SetText(L["删除方案"])
        elseif mode == "manage" then
            prompt:SetText(L["管理语音方案\n选择需要重命名或删除的方案，不会切换当前配置。"])
            manageID = library.activeID or library.order[1]
            UIDropDownMenu_SetText(manager, DisplayName(manageID and library.items[manageID] and library.items[manageID].name))
            manager:Show()
            buttons[1]:SetText(L["重命名"])
            buttons[2]:SetText(L["删除…"])
            buttons[2]:Show()
            buttons[3]:SetText(L["关闭"])
        end
        overlay:Show()
        if nameBox:IsShown() then nameBox:SetFocus(); nameBox:HighlightText() end
    end

    local function SaveNamed()
        local library = Library()
        if not library then return end
        local name = TrimText(nameBox:GetText())
        if name == "" or name:find("[%c|]") then
            errorText:SetText(L["请输入名称，不要包含换行或竖线符号。"])
            return
        end
        for id, profile in pairs(library.items) do
            if profile.name == name and (action ~= "rename" or id ~= targetID) then
                errorText:SetText(L["已有同名方案，请换一个名称。"])
                return
            end
        end
        local nextID = afterSaveID
        if nextID and not CanSwitch() then CloseDialog(); return end
        if action == "rename" then
            if not library.items[targetID] then return end
            library.items[targetID].name = name
        else
            SaveActiveVoiceInput()
            local id = tonumber(library.nextID) or 1
            while library.items[id] do id = id + 1 end
            library.nextID = id + 1
            library.items[id] = { name = name, data = Snapshot(false) }
            table.insert(library.order, id)
            library.activeID = id
        end
        CloseDialog()
        SetStatus(L["已保存语音方案："] .. DisplayName(name), false)
        if nextID then ApplyProfile(nextID) end
    end

    RequestSwitch = function(id)
        SaveActiveVoiceInput()
        local library = Library()
        if not library or not library.items[id] or not CanSwitch() then return end
        if id == library.activeID and not Dirty() then return end
        if Dirty() then OpenDialog("switch", id) else ApplyProfile(id) end
    end

    -- 超过 15 个方案时按组展开，避免菜单超出屏幕。
    local function InitializeMenu(frame, callback)
        UIDropDownMenu_Initialize(frame, function(_, level, menuList)
            local library = Library()
            if not library then return end
            level = level or 1
            local total = #library.order
            if total > 15 and level == 1 then
                for first = 1, total, 15 do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = L["方案 "] .. first .. "–" .. math.min(first + 14, total)
                    info.hasArrow, info.notCheckable, info.menuList = true, true, first
                    UIDropDownMenu_AddButton(info, level)
                end
                return
            end
            local first = level == 2 and menuList or 1
            if type(first) ~= "number" then return end
            for index = first, math.min(first + 14, total) do
                local id = library.order[index]
                local profile = library.items[id]
                if profile then
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = DisplayName(profile.name)
                    info.checked = id == (frame == manager and manageID or library.activeID)
                    info.func = function() CloseDropDownMenus(); callback(id) end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)
    end
    InitializeMenu(dropdown, RequestSwitch)
    InitializeMenu(manager, function(id)
        manageID = id
        UIDropDownMenu_SetText(manager, DisplayName(Library().items[id].name))
    end)

    buttons[1]:SetScript("OnClick", function()
        if action == "name" or action == "rename" then SaveNamed()
        elseif action == "switch" then
            if not CanSwitch() then CloseDialog(); return end
            local id = targetID
            if SaveCurrent() then ApplyProfile(id) else OpenDialog("name", nil, id) end
        elseif action == "manage" then
            if manageID then OpenDialog("rename", manageID) end
        elseif action == "delete" then
            local library = Library()
            if not library then return end
            library.items[targetID] = nil
            for index = #library.order, 1, -1 do
                if library.order[index] == targetID then table.remove(library.order, index) end
            end
            if library.activeID == targetID then library.activeID = nil end
            CloseDialog()
            SetStatus(L["方案已删除，当前语音配置保持不变。"], false)
        end
    end)
    buttons[2]:SetScript("OnClick", function()
        if action == "switch" then ApplyProfile(targetID)
        elseif action == "manage" and manageID then OpenDialog("delete", manageID) end
    end)
    buttons[3]:SetScript("OnClick", CloseDialog)
    nameBox:SetScript("OnEnterPressed", SaveNamed)
    nameBox:SetScript("OnEscapePressed", CloseDialog)
    saveButton:SetScript("OnClick", function()
        if Library() and not SaveCurrent() then OpenDialog("name") end
    end)
    newButton:SetScript("OnClick", function() if Library() then OpenDialog("name") end end)
    manageButton:SetScript("OnClick", function() if Library() then OpenDialog("manage") end end)

    VoicePanel:HookScript("OnShow", function()
        EnsureDatabase()
        RefreshVoiceProfiles()
        RefreshSpecialization()
        local height = UIParent:GetHeight()
        if type(height) == "number" and height > 30 then VoicePanel:SetScale(math.min(1, (height - 30) / 820)) end
    end)
    VoicePanel:HookScript("OnHide", CloseDialog)
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_LOGOUT" then
            SaveActiveVoiceInput()
        elseif event == "PLAYER_REGEN_DISABLED" then
            if overlay:IsShown() and (action == "switch" or afterSaveID) then
                CloseDialog()
                SetStatus(L["已进入战斗，方案切换已取消，请脱战后重新选择。"], true)
            end
        elseif event ~= "PLAYER_SPECIALIZATION_CHANGED" or (Plain(unit, "string") and unit == "player") then
            RefreshSpecialization()
        end
    end)
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_DISABLED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    RefreshSpecialization()
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("SPELLS_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
EventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...

    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        EnsureDatabase()
        RebuildSpellBookNameCache()
        ReparseStoredSpellInputs()
        RefreshVoiceInputs()
        return
    end

    if event == "PLAYER_LOGIN" then
        RebuildSpellBookNameCache()
        ReparseStoredSpellInputs()
        return
    end

    if event == "SPELLS_CHANGED" then
        if InCombatLockdown and InCombatLockdown() then
            pendingSpellBookCacheRebuild = true
            return
        end
        RebuildSpellBookNameCache()
        ReparseStoredSpellInputs()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and pendingSpellBookCacheRebuild then
        RebuildSpellBookNameCache()
        ReparseStoredSpellInputs()
        return
    end

    if event == "SPELL_UPDATE_COOLDOWN" then
        RefreshReducedCooldownWatchers()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            -- 触发入口只使用事件直接提供的 spellID；冷却数字仍不进入 Lua 比较或运算。
            TriggerVoiceForSpell(spellID)
            StartCooldownReadyWatch(spellID)
        end
    end
end)
