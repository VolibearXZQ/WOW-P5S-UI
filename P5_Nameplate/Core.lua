-- ==========================================
-- P5_Nameplate Core.lua
-- 清理版：保留当前已验证稳定的爱心血条 / WEAK / CRITICAL / TECHNICAL 逻辑
-- 说明：本版删除了被后半段覆盖的重复旧框体与旧事件处理，不改当前生效动画公式。
-- ==========================================

local _, addon = ...

local reportedTargetThemeErrors = {}

local function ApplyTargetPanelTheme(methodName, ...)
    local panelTheme = addon and addon.PanelTheme
    local method = panelTheme and panelTheme[methodName]
    if type(method) ~= "function" then return false end

    local ok, errorMessage = pcall(method, panelTheme, ...)
    if not ok and not reportedTargetThemeErrors[methodName] then
        reportedTargetThemeErrors[methodName] = true
        print("|cffFF0000[P5血条]|r 设置面板主题应用失败（" .. methodName .. "）：" .. tostring(errorMessage))
    end
    return ok
end

-- ==========================================
-- 基础框架与事件注册
-- ==========================================
local P5Frame = CreateFrame("Frame")
P5Frame:RegisterEvent("ADDON_LOADED") 
P5Frame:RegisterEvent("PLAYER_LOGIN")
P5Frame:RegisterEvent("SPELLS_CHANGED")
P5Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
P5Frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
P5Frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
P5Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
P5Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
P5Frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
P5Frame:RegisterEvent("UNIT_FLAGS")
P5Frame:RegisterEvent("UNIT_HEALTH")
P5Frame:RegisterEvent("UNIT_MAXHEALTH")
P5Frame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
P5Frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

-- 【新增】：在默认设置中加入心跳开关和三个动画参数
local defaultSettings = {
    oocEnabled = true, combatEnabled = true,
    oocScale = 1.0,    oocX = 0,    oocY = -90,
    combatScale = 1.0, combatX = 20,  combatY = -80,
    pulseEnabled = true, pulseScale = 1.05, pulseExpDur = 0.15, pulseShrDur = 0.70,

    -- 技能触发配置：支持 Spell ID；也支持在设置面板里输入技能名称后尝试解析。
    weakSpellInput = "",
    criticalSpellInput = "",
    technicalSpellInput = "",
    allAttackSpellInput = "",

    -- 总攻击触发后的心跳持续时间，单位：秒。
    allAttackPulseTime = 5.00,

    -- 弹字 Y 轴默认位置。这里的数值就是当前代码里已经调好的默认位置。
    weakPopupY = 137,
    criticalPopupY = 137,
    technicalPopupY = 140,
    allAttackPopupY = 95
}

-- ==========================================
-- 1. 创建“编组盒子”和图层
-- ==========================================
local OOCGroup = CreateFrame("Frame", nil, P5Frame)
OOCGroup:SetSize(1, 1) 

local texOOCBase = OOCGroup:CreateTexture(nil, "BACKGROUND")
texOOCBase:SetTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\脱战选中目标.tga")
texOOCBase:SetSize(400, 400)
texOOCBase:SetPoint("CENTER", OOCGroup, "CENTER", 0, 0)

local texOOCText = OOCGroup:CreateTexture(nil, "OVERLAY")
texOOCText:SetTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\Chance.tga")
texOOCText:SetSize(600, 600)
texOOCText:SetRotation(0.1)
texOOCText:SetPoint("LEFT", texOOCBase, "CENTER", -160, 65)

-- ==========================================
-- 技能命中文字测试：醉酿投 -> WEAK高清
-- ==========================================
local TEST_WEAK_SPELL_ID = 121253
local TEST_CRITICAL_SPELL_ID = 205523
local TEST_TECHNICAL_SPELL_ID = 115181
local TEST_ALL_ATTACK_SPELL_ID = 116670

-- 技能触发映射表：战斗中只查 UNIT_SPELLCAST_SUCCEEDED 给到的 spellID。
-- 设置面板保存后会重建这些表；不要在战斗事件里读取 Buff / Aura / 技能充能。
local weakSpellIDMap = {}
local criticalSpellIDMap = {}
local technicalSpellIDMap = {}
local allAttackSpellIDMap = {}

local function TrimP5Text(text)
    text = tostring(text or "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function NormalizeP5SpellInputSeparators(text)
    text = tostring(text or "")

    -- 不要把中文标点直接写进 Lua 的字符类里。
    -- Lua 5.1 的 pattern 按字节处理，"[^,，;；]+" 会把部分中文 UTF-8 字节当成分隔符，
    -- 例如“掌”“引”会被截断成乱码/方框，导致技能名无法解析。
    -- 这里先把中文分隔符替换成 ASCII，再只按 ASCII 分隔。
    text = text:gsub("，", ",")
    text = text:gsub("；", ";")
    text = text:gsub("、", ",")

    return text
end

-- 技能名称解析缓存：优先从玩家技能书建立“本地化技能名 -> Spell ID”的映射。
-- 这样比直接 C_Spell.GetSpellInfo("中文技能名") 更稳，尤其是部分中文字符/本地化名称不能被直接反查时。
local p5SpellNameToID = {}
local p5SpellBookCacheBuilt = false
local p5PendingSpellBookCacheRebuild = false

local function AddP5SpellNameToCache(cache, spellID, spellName)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return end

    spellName = TrimP5Text(spellName or "")

    if spellName == "" and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.name then
            spellName = TrimP5Text(info.name)
        end
    end

    if spellName ~= "" and cache[spellName] == nil then
        cache[spellName] = math.floor(spellID)
    end
end

local function RebuildP5SpellBookNameCache()
    -- 不在战斗中扫描技能书；战斗中用户依然可以用纯 Spell ID 保存。
    if InCombatLockdown and InCombatLockdown() then
        p5PendingSpellBookCacheRebuild = true
        return
    end

    local cache = {}

    -- 正式服新接口路径：C_SpellBook
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
        local bankList = {}
        if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
            table.insert(bankList, Enum.SpellBookSpellBank.Player)
        else
            table.insert(bankList, "spell")
        end

        local okLines, numSkillLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        if okLines and type(numSkillLines) == "number" then
            for lineIndex = 1, numSkillLines do
                local okLine, lineInfoOrName, _, itemIndexOffset, numSpellBookItems = pcall(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)
                local offset, count

                if okLine then
                    if type(lineInfoOrName) == "table" then
                        offset = lineInfoOrName.itemIndexOffset or lineInfoOrName.spellBookItemOffset or lineInfoOrName.offset
                        count = lineInfoOrName.numSpellBookItems or lineInfoOrName.numSlots or lineInfoOrName.numItems
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
                                local spellID = itemInfo.spellID or itemInfo.actionID or itemInfo.spellIDOfOverriddenSpell
                                AddP5SpellNameToCache(cache, spellID, itemInfo.name)
                            end
                        end
                    end
                end
            end
        end
    end

    -- 旧接口兜底路径：部分环境仍然存在这些函数。
    if type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" and type(GetSpellBookItemInfo) == "function" then
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
                            AddP5SpellNameToCache(cache, spellID, spellName)
                        end
                    end
                end
            end
        end
    end

    p5SpellNameToID = cache
    p5SpellBookCacheBuilt = true
    p5PendingSpellBookCacheRebuild = false
end

local function ResolveP5SpellToken(token)
    token = TrimP5Text(token)
    if token == "" then
        return nil, nil
    end

    -- 支持直接粘贴 / Shift-点击产生的技能链接，例如 |Hspell:121253:0|h[醉酿投]|h。
    local linkedSpellID = token:match("spell:(%d+)")
    if linkedSpellID then
        return tonumber(linkedSpellID), nil
    end

    local numericID = tonumber(token)
    if numericID then
        return math.floor(numericID), nil
    end

    -- 技能名解析只发生在用户确认输入/重建配置时；真正战斗触发时不会查 API。
    -- 先查我们已经建好的本地缓存：Lua 表查询本身不需要读技能书，也不涉及战斗限制。
    local cachedSpellID = p5SpellNameToID[token]
    if cachedSpellID then
        return cachedSpellID, token
    end

    -- 如果缓存里没有命中，才考虑重建技能书缓存或调用 API。
    -- 这些动作不要在战斗中做；战斗中如果遇到未缓存的中文技能名，就保持旧映射，不强行清空。
    if InCombatLockdown and InCombatLockdown() then
        return nil, nil
    end

    if not p5SpellBookCacheBuilt then
        RebuildP5SpellBookNameCache()
    end

    cachedSpellID = p5SpellNameToID[token]
    if cachedSpellID then
        return cachedSpellID, token
    end

    -- 技能书没有命中时，再尝试 API 直接反查。
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, token)
        if ok and type(info) == "table" and info.spellID then
            return info.spellID, info.name
        end
    end

    -- 兼容部分旧接口环境；正式服新环境没有也没关系。
    if type(GetSpellInfo) == "function" then
        local ok, name, rank, icon, castTime, minRange, maxRange, spellID = pcall(GetSpellInfo, token)
        if ok and spellID then
            return spellID, name
        end
    end

    return nil, nil
end

local function BuildP5SpellIDMap(inputText)
    local map = {}
    local validList = {}
    local invalidList = {}

    inputText = NormalizeP5SpellInputSeparators(inputText)
    for token in inputText:gmatch("[^,;]+") do
        token = TrimP5Text(token)
        if token ~= "" then
            local spellID, spellName = ResolveP5SpellToken(token)
            if spellID then
                if not map[spellID] then
                    map[spellID] = true
                    if spellName then
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

local function RebuildP5SpellTriggerMaps()
    weakSpellIDMap = BuildP5SpellIDMap(P5_NameplateDB and P5_NameplateDB.weakSpellInput or defaultSettings.weakSpellInput)
    criticalSpellIDMap = BuildP5SpellIDMap(P5_NameplateDB and P5_NameplateDB.criticalSpellInput or defaultSettings.criticalSpellInput)
    technicalSpellIDMap = BuildP5SpellIDMap(P5_NameplateDB and P5_NameplateDB.technicalSpellInput or defaultSettings.technicalSpellInput)
    allAttackSpellIDMap = BuildP5SpellIDMap(P5_NameplateDB and P5_NameplateDB.allAttackSpellInput or defaultSettings.allAttackSpellInput)
end

local function SetSingleP5SpellTriggerMap(dbKey, inputText)
    local map, validList, invalidList = BuildP5SpellIDMap(inputText)

    if dbKey == "weakSpellInput" then
        weakSpellIDMap = map
    elseif dbKey == "criticalSpellInput" then
        criticalSpellIDMap = map
    elseif dbKey == "technicalSpellInput" then
        technicalSpellIDMap = map
    elseif dbKey == "allAttackSpellInput" then
        allAttackSpellIDMap = map
    end

    return validList, invalidList
end

local SKILL_POPUP_SIZE = 285
local SKILL_POPUP_OFFSET_X = -21
local SKILL_POPUP_OFFSET_Y = 137
-- WEAK 弹字动画参数：总时长 = 中段动作 + 静止停留 + 渐隐
local SKILL_POPUP_TOTAL_TIME = 1.10
local SKILL_POPUP_MOTION_TIME = 0.2
local SKILL_POPUP_FADE_OUT = 0.15
local SKILL_POPUP_HOLD_AFTER_MOTION = math.max(0, SKILL_POPUP_TOTAL_TIME - SKILL_POPUP_MOTION_TIME - SKILL_POPUP_FADE_OUT)

-- 中段动作参数：先微微放大，再回到原尺寸，同时左右晃动
local SKILL_POPUP_START_SCALE = 1.1
local SKILL_POPUP_SHAKE_X = 8
local SKILL_POPUP_SHAKE_CYCLES = 2


-- CRITICAL 弹字基础尺寸与位置：幻灭踢触发。
-- 注意：下面的动画时长 / 弹簧参数在后面的 CRITICAL 参数区。
local CRITICAL_POPUP_SIZE = 335
local CRITICAL_POPUP_OFFSET_X = -21
local CRITICAL_POPUP_OFFSET_Y = 137

local CRITICAL_POPUP_TOTAL_TIME = 1.18
local CRITICAL_POPUP_TOP_HOLD_TIME = 0.24
local CRITICAL_POPUP_DROP_TIME = 0.34
local CRITICAL_POPUP_FADE_OUT = 0.18
local CRITICAL_POPUP_MOTION_TIME = CRITICAL_POPUP_TOP_HOLD_TIME + CRITICAL_POPUP_DROP_TIME
local CRITICAL_POPUP_HOLD_AFTER_MOTION = math.max(0, CRITICAL_POPUP_TOTAL_TIME - CRITICAL_POPUP_MOTION_TIME - CRITICAL_POPUP_FADE_OUT)

-- Critical 起始状态：在原位置上方出现，并且略微放大。
local CRITICAL_START_OFFSET_Y = -5
local CRITICAL_START_SCALE = 1.15

-- 下落弹簧参数：数值越大，越快砸回原位；频率越高，回弹次数越密。
local CRITICAL_DROP_DECAY = 7
local CRITICAL_DROP_FREQUENCY = 12

-- 缩放弹簧参数：让图片从放大状态缩回原尺寸，并带一点点“压回去”的弹性。
local CRITICAL_SCALE_DECAY = 5.8
local CRITICAL_SCALE_FREQUENCY = 15
local CRITICAL_MIN_SCALE = 0.7

-- TECHNICAL 弹字参数：火焰之息触发。
-- 动画逻辑：从左侧快速滑入（带渐显） -> 原地停住 -> 往右快速滑出（带渐隐）。
-- Technical 宽高可以分开调；用于修正素材本身比例。
local TECHNICAL_POPUP_WIDTH = 260
local TECHNICAL_POPUP_HEIGHT = 70
local TECHNICAL_POPUP_OFFSET_X = -27
local TECHNICAL_POPUP_OFFSET_Y = 140
local TECHNICAL_POPUP_IN_TIME = 0.2
local TECHNICAL_POPUP_HOLD_TIME = 0.80
local TECHNICAL_POPUP_OUT_TIME = 0.18
local TECHNICAL_POPUP_TOTAL_TIME = TECHNICAL_POPUP_IN_TIME + TECHNICAL_POPUP_HOLD_TIME + TECHNICAL_POPUP_OUT_TIME

-- 左进右出位移：START 越负，入场时越靠左；END 越大，出场时越往右。
local TECHNICAL_START_OFFSET_X = -90
local TECHNICAL_END_OFFSET_X = 95

-- 总攻击弹字参数：先只加入素材显示、尺寸、位置和旋转。
-- 位置默认和 WEAK 保持一致；后续再单独调整触发技能和动画效果。
-- 旋转使用“角度制”：例如 5 或 -5。正负方向如果和预期相反，直接把数值改成相反数。
local ALL_ATTACK_POPUP_SIZE = 370
local ALL_ATTACK_POPUP_OFFSET_X = 145
local ALL_ATTACK_POPUP_OFFSET_Y = 95
local ALL_ATTACK_POPUP_ROTATION_DEGREES = 0

-- 总攻击动画参数：渐显 -> 心跳脉冲 N 秒 -> 渐隐。N 会由设置面板写入。
local ALL_ATTACK_POPUP_FADE_IN = 0.22
local ALL_ATTACK_POPUP_PULSE_TIME = 5.00
local ALL_ATTACK_POPUP_FADE_OUT = 0.28
local ALL_ATTACK_POPUP_PULSE_SCALE = 1.05
local ALL_ATTACK_POPUP_PULSE_EXPAND_TIME = 0.12
local ALL_ATTACK_POPUP_PULSE_SHRINK_TIME = 0.48
local ALL_ATTACK_POPUP_TOTAL_TIME = ALL_ATTACK_POPUP_FADE_IN + ALL_ATTACK_POPUP_PULSE_TIME + ALL_ATTACK_POPUP_FADE_OUT

local CombatGroup = CreateFrame("Frame", nil, P5Frame)
CombatGroup:SetSize(1, 1)

local texCombatBase = CombatGroup:CreateTexture(nil, "BACKGROUND")
texCombatBase:SetTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\进战斗血条框体.tga")
texCombatBase:SetSize(480, 480)
texCombatBase:SetPoint("CENTER", CombatGroup, "CENTER", 0, 0)

local combatHealthBar = CreateFrame("StatusBar", nil, CombatGroup)
combatHealthBar:SetStatusBarTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\爱心血条.tga")
combatHealthBar:SetOrientation("HORIZONTAL")
combatHealthBar:SetSize(51.5, 51.5)
combatHealthBar:SetPoint("CENTER", texCombatBase, "CENTER", 26.5, -23.5)

local combatShieldBar = CreateFrame("StatusBar", nil, CombatGroup)
combatShieldBar:SetStatusBarTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\爱心血条（护盾）.tga")
combatShieldBar:SetOrientation("HORIZONTAL")
combatShieldBar:SetSize(52, 52)
combatShieldBar:SetPoint("CENTER", texCombatBase, "CENTER", 26.5, -23.5)
combatShieldBar:SetFrameLevel(combatHealthBar:GetFrameLevel() + 1)

-- WEAK 弹字改为挂到 UIParent，而不是挂在姓名板/进战组下面。
-- 目的：尽量避开其他姓名板插件的 debuff 图标图层，把弹字压到更高层。
local WeakPopupFrame = CreateFrame("Frame", nil, UIParent)
WeakPopupFrame:SetFrameStrata("TOOLTIP")
WeakPopupFrame:SetFrameLevel(9999)
WeakPopupFrame:SetToplevel(true)
WeakPopupFrame:SetSize(SKILL_POPUP_SIZE, SKILL_POPUP_SIZE)
WeakPopupFrame:SetAlpha(0)
WeakPopupFrame:Hide()

local texWeakTest = WeakPopupFrame:CreateTexture(nil, "OVERLAY", nil, 7)
texWeakTest:SetTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\WEAK高清.tga")
texWeakTest:SetAllPoints(WeakPopupFrame)

WeakPopupFrame.popupGroup = WeakPopupFrame:CreateAnimationGroup()

-- CRITICAL 弹字同样挂到 UIParent / TOOLTIP 高层。
-- 注意：不要用 GetCenter / GetLeft / GetTop 测量姓名板位置，只用 SetPoint 直接锚定 texCombatBase。
local CriticalPopupFrame = CreateFrame("Frame", nil, UIParent)
CriticalPopupFrame:SetFrameStrata("TOOLTIP")
CriticalPopupFrame:SetFrameLevel(9999)
CriticalPopupFrame:SetToplevel(true)
CriticalPopupFrame:SetSize(CRITICAL_POPUP_SIZE, CRITICAL_POPUP_SIZE)
CriticalPopupFrame:SetAlpha(0)
CriticalPopupFrame:Hide()

local texCriticalTest = CriticalPopupFrame:CreateTexture(nil, "OVERLAY", nil, 7)
texCriticalTest:SetTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\Critical.tga")
texCriticalTest:SetAllPoints(CriticalPopupFrame)

CriticalPopupFrame.popupGroup = CriticalPopupFrame:CreateAnimationGroup()

-- TECHNICAL 弹字同样挂到 UIParent / TOOLTIP 高层。
-- 注意：和 WEAK / CRITICAL 一样，不测量姓名板坐标，只直接锚定 texCombatBase。
local TechnicalPopupFrame = CreateFrame("Frame", nil, UIParent)
TechnicalPopupFrame:SetFrameStrata("TOOLTIP")
TechnicalPopupFrame:SetFrameLevel(9999)
TechnicalPopupFrame:SetToplevel(true)
TechnicalPopupFrame:SetSize(TECHNICAL_POPUP_WIDTH, TECHNICAL_POPUP_HEIGHT)
TechnicalPopupFrame:SetAlpha(0)
TechnicalPopupFrame:Hide()

local texTechnicalTest = TechnicalPopupFrame:CreateTexture(nil, "OVERLAY", nil, 7)
texTechnicalTest:SetTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\Technical.tga")
texTechnicalTest:SetAllPoints(TechnicalPopupFrame)

-- 总攻击弹字不挂在 CombatGroup 下面。
-- 原因：脱战时 CombatGroup 是隐藏的；如果为了显示总攻击而强行 CombatGroup:Show()，
-- 就会把进战组爱心血条也拉出来，和脱战组叠在一起。
-- 但也不能长期挂在 UIParent 高层，否则会盖住姓名板血条和 Debuff。
-- 这里先创建在 UIParent；真正显示/刷新时会 SetParent 到当前目标 nameplate。
-- 这样它能脱战单独显示，又能回到姓名板层级里，被血条/Buff 挡住。
local AllAttackPopupFrame = CreateFrame("Frame", nil, UIParent)
AllAttackPopupFrame:SetFrameStrata("BACKGROUND")
AllAttackPopupFrame:SetFrameLevel(0)
AllAttackPopupFrame:SetSize(ALL_ATTACK_POPUP_SIZE, ALL_ATTACK_POPUP_SIZE)
AllAttackPopupFrame:SetAlpha(0)
AllAttackPopupFrame:Hide()

local texAllAttackTest = AllAttackPopupFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
texAllAttackTest:SetTexture("Interface\\AddOns\\P5S\\P5_Nameplate\\Media\\总攻击.tga")
texAllAttackTest:SetAllPoints(AllAttackPopupFrame)
texAllAttackTest:SetRotation(math.rad(ALL_ATTACK_POPUP_ROTATION_DEGREES))

AllAttackPopupFrame.popupGroup = AllAttackPopupFrame:CreateAnimationGroup()

-- 入场不做渐显：一出现就是 100% 不透明。
-- 先让它完整显示“中段动作 + 静止停留”，最后再渐隐。
local weakHold = WeakPopupFrame.popupGroup:CreateAnimation("Alpha")
weakHold:SetOrder(1)
weakHold:SetFromAlpha(1)
weakHold:SetToAlpha(1)
weakHold:SetDuration(SKILL_POPUP_MOTION_TIME + SKILL_POPUP_HOLD_AFTER_MOTION)

local weakFadeOut = WeakPopupFrame.popupGroup:CreateAnimation("Alpha")
weakFadeOut:SetOrder(2)
weakFadeOut:SetFromAlpha(1)
weakFadeOut:SetToAlpha(0)
weakFadeOut:SetDuration(SKILL_POPUP_FADE_OUT)
weakFadeOut:SetSmoothing("IN")

-- CRITICAL 入场不渐显；上方停顿 + 下砸回弹结束后停留一下，最后渐隐。
local criticalHold = CriticalPopupFrame.popupGroup:CreateAnimation("Alpha")
criticalHold:SetOrder(1)
criticalHold:SetFromAlpha(1)
criticalHold:SetToAlpha(1)
criticalHold:SetDuration(CRITICAL_POPUP_MOTION_TIME + CRITICAL_POPUP_HOLD_AFTER_MOTION)

local criticalFadeOut = CriticalPopupFrame.popupGroup:CreateAnimation("Alpha")
criticalFadeOut:SetOrder(2)
criticalFadeOut:SetFromAlpha(1)
criticalFadeOut:SetToAlpha(0)
criticalFadeOut:SetDuration(CRITICAL_POPUP_FADE_OUT)
criticalFadeOut:SetSmoothing("IN")

-- 总攻击动画：渐显 -> 维持显示并由 OnUpdate 做心跳脉冲 -> 渐隐。
-- 这里只负责 Alpha；Scale 脉冲放在 AllAttackTestAnimDriver 里，避免影响层级和锚点。
local allAttackFadeIn = AllAttackPopupFrame.popupGroup:CreateAnimation("Alpha")
allAttackFadeIn:SetOrder(1)
allAttackFadeIn:SetFromAlpha(0)
allAttackFadeIn:SetToAlpha(1)
allAttackFadeIn:SetDuration(ALL_ATTACK_POPUP_FADE_IN)
allAttackFadeIn:SetSmoothing("OUT")

local allAttackHold = AllAttackPopupFrame.popupGroup:CreateAnimation("Alpha")
allAttackHold:SetOrder(2)
allAttackHold:SetFromAlpha(1)
allAttackHold:SetToAlpha(1)
allAttackHold:SetDuration(ALL_ATTACK_POPUP_PULSE_TIME)

local allAttackFadeOut = AllAttackPopupFrame.popupGroup:CreateAnimation("Alpha")
allAttackFadeOut:SetOrder(3)
allAttackFadeOut:SetFromAlpha(1)
allAttackFadeOut:SetToAlpha(0)
allAttackFadeOut:SetDuration(ALL_ATTACK_POPUP_FADE_OUT)
allAttackFadeOut:SetSmoothing("IN")

local function GetValidatedAllAttackPulseTime(value)
    value = tonumber(value)
    if not value then
        value = defaultSettings.allAttackPulseTime or 5.00
    end

    -- 给设置面板一个安全范围，避免输入 0、负数或特别大的值导致体验异常。
    if value < 0.10 then value = 0.10 end
    if value > 60.00 then value = 60.00 end

    return value
end

local function ApplyAllAttackDurationSetting()
    ALL_ATTACK_POPUP_PULSE_TIME = GetValidatedAllAttackPulseTime(P5_NameplateDB and P5_NameplateDB.allAttackPulseTime)
    ALL_ATTACK_POPUP_TOTAL_TIME = ALL_ATTACK_POPUP_FADE_IN + ALL_ATTACK_POPUP_PULSE_TIME + ALL_ATTACK_POPUP_FADE_OUT

    -- 这组 Alpha 动画目前主要保留为结构备份；实际淡入/淡出由 OnUpdate 手动驱动。
    -- 同步一下 duration，避免以后重新启用 popupGroup:Play() 时和设置值不一致。
    if allAttackHold then
        allAttackHold:SetDuration(ALL_ATTACK_POPUP_PULSE_TIME)
    end
end

local WeakTestAnimDriver = CreateFrame("Frame", nil, P5Frame)
WeakTestAnimDriver:Hide()

local CriticalTestAnimDriver = CreateFrame("Frame", nil, P5Frame)
CriticalTestAnimDriver:Hide()

local TechnicalTestAnimDriver = CreateFrame("Frame", nil, P5Frame)
TechnicalTestAnimDriver:Hide()

local AllAttackTestAnimDriver = CreateFrame("Frame", nil, P5Frame)
AllAttackTestAnimDriver:Hide()

local weakTestAnimElapsed = 0
local criticalTestAnimElapsed = 0
local technicalTestAnimElapsed = 0
local allAttackTestAnimElapsed = 0
local allAttackPopupActive = false
local HideWeakTestPopup
local HideCriticalTestPopup
local HideTechnicalTestPopup
local HideAllAttackTestPopup

local function GetP5PopupYOffset(dbKey, fallbackValue)
    local value

    if P5_NameplateDB and P5_NameplateDB[dbKey] ~= nil then
        value = tonumber(P5_NameplateDB[dbKey])
    end

    if value == nil then
        value = tonumber(fallbackValue) or 0
    end

    return value
end

local function GetWeakPopupUserScale()
    -- 不再读取 texCombatBase:GetCenter() / GetLeft() 这类几何位置。
    -- 至暗之夜里，姓名板相关区域在战斗中可能是 restricted region，测量它会触发 FrameMeasurement 错误。
    -- 这里只读取我们自己 SavedVariables 里的缩放值，用来让 WEAK 大小大致跟随进战组缩放。
    return (P5_NameplateDB and P5_NameplateDB.combatScale) or defaultSettings.combatScale or 1
end

local function RepositionWeakTestPopup(shakeX)
    shakeX = shakeX or 0

    local userScale = GetWeakPopupUserScale()
    WeakPopupFrame:SetSize(SKILL_POPUP_SIZE * userScale, SKILL_POPUP_SIZE * userScale)
    WeakPopupFrame:ClearAllPoints()

    -- 关键改动：
    -- WeakPopupFrame 仍然挂在 UIParent / TOOLTIP 高层，
    -- 但位置直接锚定到 texCombatBase，不主动 GetCenter 测量坐标。
    -- 这样避免 FrameMeasurement restricted region 错误。
    WeakPopupFrame:SetPoint(
        "CENTER",
        texCombatBase,
        "CENTER",
        (SKILL_POPUP_OFFSET_X + shakeX) * userScale,
        GetP5PopupYOffset("weakPopupY", SKILL_POPUP_OFFSET_Y) * userScale
    )
    return true
end

local function ResetWeakTestPopupTransform()
    WeakPopupFrame:SetScale(1)
    RepositionWeakTestPopup(0)
end

local function GetCriticalPopupUserScale()
    -- 和 WEAK 一样，只读 SavedVariables 缩放值，不测量姓名板。
    return (P5_NameplateDB and P5_NameplateDB.combatScale) or defaultSettings.combatScale or 1
end

local function RepositionCriticalTestPopup(extraY)
    extraY = extraY or 0

    local userScale = GetCriticalPopupUserScale()
    CriticalPopupFrame:SetSize(CRITICAL_POPUP_SIZE * userScale, CRITICAL_POPUP_SIZE * userScale)
    CriticalPopupFrame:ClearAllPoints()
    CriticalPopupFrame:SetPoint(
        "CENTER",
        texCombatBase,
        "CENTER",
        CRITICAL_POPUP_OFFSET_X * userScale,
        (GetP5PopupYOffset("criticalPopupY", CRITICAL_POPUP_OFFSET_Y) + extraY) * userScale
    )
    return true
end

local function ResetCriticalTestPopupTransform()
    CriticalPopupFrame:SetScale(1)
    RepositionCriticalTestPopup(0)
end

local function GetTechnicalPopupUserScale()
    return (P5_NameplateDB and P5_NameplateDB.combatScale) or defaultSettings.combatScale or 1
end

local function RepositionTechnicalTestPopup(extraX)
    extraX = extraX or 0

    local userScale = GetTechnicalPopupUserScale()
    TechnicalPopupFrame:SetSize(TECHNICAL_POPUP_WIDTH * userScale, TECHNICAL_POPUP_HEIGHT * userScale)
    TechnicalPopupFrame:ClearAllPoints()
    TechnicalPopupFrame:SetPoint(
        "CENTER",
        texCombatBase,
        "CENTER",
        (TECHNICAL_POPUP_OFFSET_X + extraX) * userScale,
        GetP5PopupYOffset("technicalPopupY", TECHNICAL_POPUP_OFFSET_Y) * userScale
    )
    return true
end

local function ResetTechnicalTestPopupTransform()
    TechnicalPopupFrame:SetScale(1)
    RepositionTechnicalTestPopup(0)
end

local function AttachAllAttackPopupToCurrentNameplate()
    local nameplate = C_NamePlate.GetNamePlateForUnit("target")
    if not nameplate then
        return false
    end

    -- 关键：总攻击挂到当前目标姓名板，而不是 CombatGroup，也不是 UIParent 高层。
    -- 这样脱战时不会强行显示进战组，同时图层会参与姓名板自己的层级排序。
    if AllAttackPopupFrame:GetParent() ~= nameplate then
        AllAttackPopupFrame:SetParent(nameplate)
    end

    AllAttackPopupFrame:SetFrameStrata("BACKGROUND")
    AllAttackPopupFrame:SetFrameLevel(0)
    return true
end

local function GetAllAttackPopupUserScale()
    -- 总攻击不挂在 CombatGroup 下面，因此不会继承 CombatGroup 的缩放。
    -- 所以这里和 WEAK / CRITICAL / TECHNICAL 一样，读取 combatScale，
    -- 让它在视觉上仍然跟随进战组缩放，但不会强行显示进战组。
    return (P5_NameplateDB and P5_NameplateDB.combatScale) or defaultSettings.combatScale or 1
end

local function RepositionAllAttackTestPopup()
    if not AttachAllAttackPopupToCurrentNameplate() then
        return false
    end

    local userScale = GetAllAttackPopupUserScale()
    AllAttackPopupFrame:SetSize(ALL_ATTACK_POPUP_SIZE * userScale, ALL_ATTACK_POPUP_SIZE * userScale)
    AllAttackPopupFrame:ClearAllPoints()
    AllAttackPopupFrame:SetPoint(
        "CENTER",
        texCombatBase,
        "CENTER",
        ALL_ATTACK_POPUP_OFFSET_X * userScale,
        GetP5PopupYOffset("allAttackPopupY", ALL_ATTACK_POPUP_OFFSET_Y) * userScale
    )
    return true
end

local function ResetAllAttackTestPopupTransform()
    AllAttackPopupFrame:SetScale(1)
    texAllAttackTest:SetRotation(math.rad(ALL_ATTACK_POPUP_ROTATION_DEGREES))
    -- 注意：这里只重置缩放和旋转，不强制 Reposition。
    -- 总攻击可能在目标切换/无目标的瞬间仍处于全局计时中，
    -- 此时强制 Reposition 会因为没有当前 nameplate 而失败。
end

local function EaseOutCubic(p)
    return 1 - ((1 - p) * (1 - p) * (1 - p))
end

-- 提前声明：总攻击 OnUpdate 需要调用它。
-- Lua 的 local 作用域从声明处才开始；如果声明放在 OnUpdate 后面，
-- OnUpdate 里会误读成全局 UpdateP5Visuals，导致 nil 调用报错。
local UpdateP5Visuals

WeakTestAnimDriver:SetScript("OnUpdate", function(self, elapsed)
    if not WeakPopupFrame:IsShown() then
        self:Hide()
        return
    end

    if not UnitExists("target") or not C_NamePlate.GetNamePlateForUnit("target") then
        HideWeakTestPopup()
        return
    end

    weakTestAnimElapsed = weakTestAnimElapsed + elapsed

    local currentScale = 1
    local shakeX = 0

    if weakTestAnimElapsed < SKILL_POPUP_MOTION_TIME then
        local p = weakTestAnimElapsed / SKILL_POPUP_MOTION_TIME
        local eased = EaseOutCubic(p)

        -- Scale：从微微放大，回到原尺寸。
        currentScale = SKILL_POPUP_START_SCALE + (1 - SKILL_POPUP_START_SCALE) * eased

        -- X 轴晃动：只动左右，不动上下；末尾稍微衰减，避免停下时突兀。
        local shakeDecay = 1 - 0.35 * p
        shakeX = math.sin(p * SKILL_POPUP_SHAKE_CYCLES * math.pi * 2) * SKILL_POPUP_SHAKE_X * shakeDecay
    end

    WeakPopupFrame:SetScale(currentScale)
    RepositionWeakTestPopup(shakeX)
    WeakPopupFrame:Raise()
end)

CriticalTestAnimDriver:SetScript("OnUpdate", function(self, elapsed)
    if not CriticalPopupFrame:IsShown() then
        self:Hide()
        return
    end

    if not UnitExists("target") or not C_NamePlate.GetNamePlateForUnit("target") then
        HideCriticalTestPopup()
        return
    end

    criticalTestAnimElapsed = criticalTestAnimElapsed + elapsed

    local currentScale = 1
    local extraY = 0

    if criticalTestAnimElapsed < CRITICAL_POPUP_TOP_HOLD_TIME then
        -- 第一段：没有渐显，直接在原位置上方放大出现，并停住一小段时间。
        currentScale = CRITICAL_START_SCALE
        extraY = CRITICAL_START_OFFSET_Y
    elseif criticalTestAnimElapsed < CRITICAL_POPUP_MOTION_TIME then
        -- 第二段：从上方往下砸回原位。
        -- p 是 0 到 1 的进度；这里用阻尼弹簧曲线，让它越过原位一点点再弹回来。
        local t = criticalTestAnimElapsed - CRITICAL_POPUP_TOP_HOLD_TIME
        local p = t / CRITICAL_POPUP_DROP_TIME

        extraY = CRITICAL_START_OFFSET_Y
            * math.exp(-CRITICAL_DROP_DECAY * p)
            * math.cos(CRITICAL_DROP_FREQUENCY * p)

        -- 缩放也用一条阻尼曲线：从放大状态迅速缩回原尺寸，并带轻微回弹。
        currentScale = 1 + (CRITICAL_START_SCALE - 1)
            * math.exp(-CRITICAL_SCALE_DECAY * p)
            * math.cos(CRITICAL_SCALE_FREQUENCY * p)

        -- 防止参数调得太猛时图片被压得过小。
        if currentScale < CRITICAL_MIN_SCALE then
            currentScale = CRITICAL_MIN_SCALE
        end
    end

    CriticalPopupFrame:SetScale(currentScale)
    RepositionCriticalTestPopup(extraY)
    CriticalPopupFrame:Raise()
end)

TechnicalTestAnimDriver:SetScript("OnUpdate", function(self, elapsed)
    if not TechnicalPopupFrame:IsShown() then
        self:Hide()
        return
    end

    if not UnitExists("target") or not C_NamePlate.GetNamePlateForUnit("target") then
        HideTechnicalTestPopup()
        return
    end

    technicalTestAnimElapsed = technicalTestAnimElapsed + elapsed

    local alpha = 1
    local extraX = 0

    if technicalTestAnimElapsed < TECHNICAL_POPUP_IN_TIME then
        local p = technicalTestAnimElapsed / TECHNICAL_POPUP_IN_TIME
        local eased = EaseOutCubic(p)

        extraX = TECHNICAL_START_OFFSET_X * (1 - eased)
        alpha = p

    elseif technicalTestAnimElapsed < (TECHNICAL_POPUP_IN_TIME + TECHNICAL_POPUP_HOLD_TIME) then
        extraX = 0
        alpha = 1

    elseif technicalTestAnimElapsed < TECHNICAL_POPUP_TOTAL_TIME then
        local t = technicalTestAnimElapsed - TECHNICAL_POPUP_IN_TIME - TECHNICAL_POPUP_HOLD_TIME
        local p = t / TECHNICAL_POPUP_OUT_TIME
        local eased = EaseOutCubic(p)

        extraX = TECHNICAL_END_OFFSET_X * eased
        alpha = 1 - p
    else
        HideTechnicalTestPopup()
        return
    end

    TechnicalPopupFrame:SetScale(1)
    TechnicalPopupFrame:SetAlpha(alpha)
    RepositionTechnicalTestPopup(extraX)
    TechnicalPopupFrame:Raise()
end)

AllAttackTestAnimDriver:SetScript("OnUpdate", function(self, elapsed)
    -- 总攻击是“全局持续时间”效果：
    -- 触发后计时开始，期间切换目标只重新挂载到当前目标姓名板，不重置剩余时间。
    if not allAttackPopupActive then
        self:Hide()
        return
    end

    allAttackTestAnimElapsed = allAttackTestAnimElapsed + elapsed

    if allAttackTestAnimElapsed >= ALL_ATTACK_POPUP_TOTAL_TIME then
        HideAllAttackTestPopup()
        return
    end

    local alpha = 1
    if allAttackTestAnimElapsed < ALL_ATTACK_POPUP_FADE_IN then
        local p = allAttackTestAnimElapsed / ALL_ATTACK_POPUP_FADE_IN
        alpha = EaseOutCubic(p)
    elseif allAttackTestAnimElapsed >= (ALL_ATTACK_POPUP_FADE_IN + ALL_ATTACK_POPUP_PULSE_TIME) then
        local fadeElapsed = allAttackTestAnimElapsed - ALL_ATTACK_POPUP_FADE_IN - ALL_ATTACK_POPUP_PULSE_TIME
        local p = math.min(1, fadeElapsed / ALL_ATTACK_POPUP_FADE_OUT)
        alpha = 1 - p
    end

    local currentScale = 1
    local pulseStartTime = ALL_ATTACK_POPUP_FADE_IN
    local pulseEndTime = ALL_ATTACK_POPUP_FADE_IN + ALL_ATTACK_POPUP_PULSE_TIME

    if allAttackTestAnimElapsed >= pulseStartTime and allAttackTestAnimElapsed < pulseEndTime then
        local pulseElapsed = allAttackTestAnimElapsed - pulseStartTime
        local cycleTime = ALL_ATTACK_POPUP_PULSE_EXPAND_TIME + ALL_ATTACK_POPUP_PULSE_SHRINK_TIME
        local t = pulseElapsed % cycleTime

        if t < ALL_ATTACK_POPUP_PULSE_EXPAND_TIME then
            local p = t / ALL_ATTACK_POPUP_PULSE_EXPAND_TIME
            local eased = EaseOutCubic(p)
            currentScale = 1 + (ALL_ATTACK_POPUP_PULSE_SCALE - 1) * eased
        else
            local p = (t - ALL_ATTACK_POPUP_PULSE_EXPAND_TIME) / ALL_ATTACK_POPUP_PULSE_SHRINK_TIME
            local eased = EaseOutCubic(p)
            currentScale = ALL_ATTACK_POPUP_PULSE_SCALE + (1 - ALL_ATTACK_POPUP_PULSE_SCALE) * eased
        end
    end

    -- 没有目标、目标没有姓名板、或目标刚切换导致 nameplate 暂时没生成时，
    -- 不结束总攻击，只暂时隐藏；计时继续走。
    if not UnitExists("target") or not C_NamePlate.GetNamePlateForUnit("target") then
        AllAttackPopupFrame:Hide()
        return
    end

    UpdateP5Visuals()

    if not RepositionAllAttackTestPopup() then
        AllAttackPopupFrame:Hide()
        return
    end

    texAllAttackTest:SetRotation(math.rad(ALL_ATTACK_POPUP_ROTATION_DEGREES))
    AllAttackPopupFrame:SetFrameStrata("BACKGROUND")
    AllAttackPopupFrame:SetFrameLevel(0)
    AllAttackPopupFrame:SetScale(currentScale)
    AllAttackPopupFrame:SetAlpha(alpha)
    AllAttackPopupFrame:Show()
    -- 不调用 Raise()：总攻击要留在姓名板底层，允许被血条/Buff 遮住。
end)

WeakPopupFrame.popupGroup:SetScript("OnFinished", function()
    WeakTestAnimDriver:Hide()
    ResetWeakTestPopupTransform()
    WeakPopupFrame:SetAlpha(0)
    WeakPopupFrame:Hide()
end)

CriticalPopupFrame.popupGroup:SetScript("OnFinished", function()
    CriticalTestAnimDriver:Hide()
    ResetCriticalTestPopupTransform()
    CriticalPopupFrame:SetAlpha(0)
    CriticalPopupFrame:Hide()
end)

AllAttackPopupFrame.popupGroup:SetScript("OnFinished", function()
    -- 现在总攻击由 AllAttackTestAnimDriver 全局计时控制。
    -- 这里保留空壳，避免旧 AnimationGroup 意外接管显示时长。
end)

OOCGroup:Hide()
CombatGroup:Hide()
texOOCText:Hide()

-- ==========================================
-- 【修改】：让动画参数可以被动态修改
-- ==========================================
local function AddP5Animations(region, needFade, needPulse)
    if needFade then
        region.fadeGroup = region:CreateAnimationGroup()
        local fade = region.fadeGroup:CreateAnimation("Alpha")
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(0.25)
        fade:SetSmoothing("OUT")
    end
    
    if needPulse then
        region.pulseGroup = region:CreateAnimationGroup()
        region.pulseGroup:SetLooping("REPEAT")
        
        -- 把子动画存到对象上 (s1, s2)，以便后续直接通过面板修改参数
        region.s1 = region.pulseGroup:CreateAnimation("Scale")
        region.s1:SetOrder(1)
        region.s1:SetSmoothing("OUT")
        
        region.s2 = region.pulseGroup:CreateAnimation("Scale")
        region.s2:SetOrder(2)
        region.s2:SetSmoothing("IN")
        
        -- 赋予默认值 (后面会被读取的数据库覆盖)
        region.s1:SetScale(1.05, 1.05) 
        region.s1:SetDuration(0.15)
        region.s2:SetScale(1/1.05, 1/1.05) 
        region.s2:SetDuration(0.7)
    end
end

AddP5Animations(texOOCBase, true, false)
AddP5Animations(texOOCText, true, true)
AddP5Animations(texCombatBase, false, true)
AddP5Animations(combatHealthBar, false, true)
AddP5Animations(combatShieldBar, false, true)

HideWeakTestPopup = function()
    WeakTestAnimDriver:Hide()
    WeakPopupFrame.popupGroup:Stop()
    ResetWeakTestPopupTransform()
    WeakPopupFrame:SetAlpha(0)
    WeakPopupFrame:Hide()
end

HideCriticalTestPopup = function()
    CriticalTestAnimDriver:Hide()
    CriticalPopupFrame.popupGroup:Stop()
    ResetCriticalTestPopupTransform()
    CriticalPopupFrame:SetAlpha(0)
    CriticalPopupFrame:Hide()
end

HideTechnicalTestPopup = function()
    TechnicalTestAnimDriver:Hide()
    ResetTechnicalTestPopupTransform()
    TechnicalPopupFrame:SetAlpha(0)
    TechnicalPopupFrame:Hide()
end

HideAllAttackTestPopup = function()
    AllAttackPopupFrame.popupGroup:Stop()
    AllAttackTestAnimDriver:Hide()
    allAttackPopupActive = false
    allAttackTestAnimElapsed = 0
    ResetAllAttackTestPopupTransform()
    AllAttackPopupFrame:SetAlpha(0)
    AllAttackPopupFrame:Hide()
end

local function ShowWeakTestPopup()
    if not UnitExists("target") then return end
    if not C_NamePlate.GetNamePlateForUnit("target") then return end

    -- 技能事件可能比血条刷新早一点点，先确保进战组已经重新挂到当前目标血条上。
    UpdateP5Visuals()

    -- 弹字父级是 UIParent；血条显隐只由 UpdateP5Visuals 决定，避免脱战施法拉起进战组。

    WeakPopupFrame.popupGroup:Stop()
    WeakTestAnimDriver:Hide()
    weakTestAnimElapsed = 0
    ResetWeakTestPopupTransform()

    if not RepositionWeakTestPopup(0) then
        return
    end

    WeakPopupFrame:SetFrameStrata("TOOLTIP")
    WeakPopupFrame:SetFrameLevel(9999)
    WeakPopupFrame:SetAlpha(1)
    WeakPopupFrame:Show()
    WeakPopupFrame:Raise()
    WeakPopupFrame.popupGroup:Play()
    WeakTestAnimDriver:Show()
end

local function ShowCriticalTestPopup()
    if not UnitExists("target") then return end
    if not C_NamePlate.GetNamePlateForUnit("target") then return end

    -- 和 WEAK 一样，只刷新/重挂已有框体，不测量姓名板坐标。
    UpdateP5Visuals()

    CriticalPopupFrame.popupGroup:Stop()
    CriticalTestAnimDriver:Hide()
    criticalTestAnimElapsed = 0
    ResetCriticalTestPopupTransform()

    CriticalPopupFrame:SetScale(CRITICAL_START_SCALE)
    if not RepositionCriticalTestPopup(CRITICAL_START_OFFSET_Y) then
        return
    end

    CriticalPopupFrame:SetFrameStrata("TOOLTIP")
    CriticalPopupFrame:SetFrameLevel(9999)
    CriticalPopupFrame:SetAlpha(1)
    CriticalPopupFrame:Show()
    CriticalPopupFrame:Raise()
    CriticalPopupFrame.popupGroup:Play()
    CriticalTestAnimDriver:Show()
end

local function ShowTechnicalTestPopup()
    if not UnitExists("target") then return end
    if not C_NamePlate.GetNamePlateForUnit("target") then return end

    UpdateP5Visuals()

    TechnicalTestAnimDriver:Hide()
    technicalTestAnimElapsed = 0
    ResetTechnicalTestPopupTransform()

    if not RepositionTechnicalTestPopup(TECHNICAL_START_OFFSET_X) then
        return
    end

    TechnicalPopupFrame:SetScale(1)
    TechnicalPopupFrame:SetFrameStrata("TOOLTIP")
    TechnicalPopupFrame:SetFrameLevel(9999)
    TechnicalPopupFrame:SetAlpha(0)
    TechnicalPopupFrame:Show()
    TechnicalPopupFrame:Raise()
    TechnicalTestAnimDriver:Show()
end

local function ShowAllAttackTestPopup()
    -- 触发总攻击时才重置持续时间。
    -- 之后 PLAYER_TARGET_CHANGED / NAME_PLATE_UNIT_ADDED 只会重挂到新目标，不会刷新剩余时间。
    ApplyAllAttackDurationSetting()
    if not UnitExists("target") then return end
    if not C_NamePlate.GetNamePlateForUnit("target") then return end

    UpdateP5Visuals()

    AllAttackPopupFrame.popupGroup:Stop()
    allAttackPopupActive = true
    allAttackTestAnimElapsed = 0
    ResetAllAttackTestPopupTransform()

    if not RepositionAllAttackTestPopup() then
        return
    end

    texAllAttackTest:SetRotation(math.rad(ALL_ATTACK_POPUP_ROTATION_DEGREES))
    AllAttackPopupFrame:SetFrameStrata("BACKGROUND")
    AllAttackPopupFrame:SetFrameLevel(0)
    AllAttackPopupFrame:SetScale(1)
    AllAttackPopupFrame:SetAlpha(0)
    AllAttackPopupFrame:Show()
    -- 不调用 Raise()：总攻击要留在姓名板底层，允许被血条/Buff 遮住。
    AllAttackTestAnimDriver:Show()
end

-- 【新增】：一个专门用于实时应用进战心跳参数的函数
local function ApplyPulseSettings()
    local scale = P5_NameplateDB.pulseScale
    local expDur = P5_NameplateDB.pulseExpDur
    local shrDur = P5_NameplateDB.pulseShrDur
    
    -- 只针对进战组的三个图层进行修改
    local combatElements = {texCombatBase, combatHealthBar, combatShieldBar}
    for _, el in ipairs(combatElements) do
        if el.pulseGroup then
            -- 正在跳动时修改参数会报错，所以先悄悄暂停
            local wasPlaying = el.pulseGroup:IsPlaying()
            el.pulseGroup:Stop()
            
            -- 注入新的动画参数
            el.s1:SetScale(scale, scale)
            el.s1:SetDuration(expDur)
            el.s2:SetScale(1/scale, 1/scale)
            el.s2:SetDuration(shrDur)
            
            -- 如果玩家开启了效果，且之前正在战斗中，就恢复播放
            if wasPlaying and P5_NameplateDB.pulseEnabled then
                el.pulseGroup:Play()
            end
        end
    end
end

-- ==========================================
-- 2. 距离检测逻辑
-- ==========================================
local RANGE_ITEM_ID = 31463 

local updateTimer = 0
OOCGroup:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer > 0.15 then
        updateTimer = 0
        if UnitExists("target") then
            local inRange = C_Item.IsItemInRange(RANGE_ITEM_ID, "target")
            
            if inRange and UnitCanAttack("player", "target") then
                if not texOOCText:IsShown() then
                    texOOCText:Show()
                    texOOCText.fadeGroup:Stop(); texOOCText.fadeGroup:Play()
                    texOOCText.pulseGroup:Stop(); texOOCText.pulseGroup:Play()
                end
            else
                if texOOCText:IsShown() then
                    texOOCText:Hide()
                    texOOCText.fadeGroup:Stop()
                    texOOCText.pulseGroup:Stop()
                end
            end
        end
    end
end)

-- ==========================================
-- 3. 核心视觉与状态分发
-- ==========================================
local function UpdateTargetHealth()
    if not UnitExists("target") then return end
    local maxHP = UnitHealthMax("target")
    local currentHP = UnitHealth("target")
    combatHealthBar:SetMinMaxValues(0, maxHP)
    combatHealthBar:SetValue(currentHP)
end

local function UpdateTargetShield()
    if not UnitExists("target") then return end
    local maxHP = UnitHealthMax("target")
    local absorbs = UnitGetTotalAbsorbs("target")
    combatShieldBar:SetMinMaxValues(0, maxHP)
    combatShieldBar:SetValue(absorbs)
end

UpdateP5Visuals = function()
    local nameplate = C_NamePlate.GetNamePlateForUnit("target")
    if nameplate then
        OOCGroup:SetParent(nameplate)
        CombatGroup:SetParent(nameplate)
        AttachAllAttackPopupToCurrentNameplate()
        
        OOCGroup:ClearAllPoints()
        OOCGroup:SetPoint("CENTER", nameplate, "CENTER", P5_NameplateDB.oocX, P5_NameplateDB.oocY)
        OOCGroup:SetScale(P5_NameplateDB.oocScale)
        
        CombatGroup:ClearAllPoints()
        CombatGroup:SetPoint("CENTER", nameplate, "CENTER", P5_NameplateDB.combatX, P5_NameplateDB.combatY)
        CombatGroup:SetScale(P5_NameplateDB.combatScale)

        local isCombat = InCombatLockdown() or UnitAffectingCombat("player") or UnitAffectingCombat("target")

        if isCombat and P5_NameplateDB.combatEnabled then
            if not CombatGroup:IsShown() then
                CombatGroup:Show()
            end
            
            -- 【修改】：增加心跳开关判断
            if P5_NameplateDB.pulseEnabled then
                if not texCombatBase.pulseGroup:IsPlaying() then
                    texCombatBase.pulseGroup:Play()
                    combatHealthBar.pulseGroup:Play()
                    combatShieldBar.pulseGroup:Play()
                end
            else
                texCombatBase.pulseGroup:Stop()
                combatHealthBar.pulseGroup:Stop()
                combatShieldBar.pulseGroup:Stop()
            end

            OOCGroup:Hide()
            texOOCText:Hide()
            UpdateTargetHealth()
            UpdateTargetShield()
        else
            if not isCombat and P5_NameplateDB.oocEnabled then
                if not OOCGroup:IsShown() then
                    OOCGroup:Show()
                    texOOCBase.fadeGroup:Stop(); texOOCBase.fadeGroup:Play()
                    updateTimer = 1
                end
            else
                OOCGroup:Hide()
                texOOCText:Hide()
                texOOCBase.fadeGroup:Stop()
                texOOCText.fadeGroup:Stop()
                texOOCText.pulseGroup:Stop()
            end
            CombatGroup:Hide()
            texCombatBase.pulseGroup:Stop()
            combatHealthBar.pulseGroup:Stop()
            combatShieldBar.pulseGroup:Stop()
        end
    else
        OOCGroup:Hide()
        CombatGroup:Hide()
        HideWeakTestPopup()
        HideCriticalTestPopup()
        HideTechnicalTestPopup()
        if allAttackPopupActive then
            AllAttackPopupFrame:Hide()
        else
            HideAllAttackTestPopup()
        end
    end
end

-- ==========================================
-- 4. 设置面板（现代红色主题）
-- ==========================================
local ConfigPanel = CreateFrame("Frame", "P5ConfigPanel", UIParent, "BackdropTemplate")
ConfigPanel:SetSize(1120, 680)
ConfigPanel:SetPoint("CENTER")
ConfigPanel:SetClampedToScreen(true)
ConfigPanel:Hide()

-- 优先注册命令，任何主题或控件样式错误都不能让 /p5target 消失。
SLASH_P5TARGET1 = "/p5target"
SlashCmdList["P5TARGET"] = function()
    if ConfigPanel:IsShown() then ConfigPanel:Hide() else ConfigPanel:Show() end
end

local panelThemeApplied = ApplyTargetPanelTheme("ApplyOptionsPanel", ConfigPanel)
if not panelThemeApplied then
    ConfigPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 32,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    ConfigPanel:SetBackdropColor(0.035, 0.040, 0.060, 0.96)
    ConfigPanel:SetBackdropBorderColor(0.24, 0.28, 0.36, 0.95)
    ConfigPanel:SetFrameStrata("DIALOG")
    ConfigPanel:SetToplevel(true)
    ConfigPanel:HookScript("OnShow", function(panel)
        panel:Raise()
    end)
end

-- 主题缺失或初始化中途失败时，仍保留可辨识的标题栏和关闭能力。
if not ConfigPanel.TitleBg then
    ConfigPanel.TitleBg = ConfigPanel:CreateTexture(nil, "BACKGROUND")
    ConfigPanel.TitleBg:SetPoint("TOPLEFT", ConfigPanel, "TOPLEFT", 1, -1)
    ConfigPanel.TitleBg:SetPoint("TOPRIGHT", ConfigPanel, "TOPRIGHT", -1, -1)
    ConfigPanel.TitleBg:SetHeight(38)
    ConfigPanel.TitleBg:SetColorTexture(0.055, 0.060, 0.085, 0.98)
end

if not ConfigPanel.CloseButton then
    ConfigPanel.CloseButton = CreateFrame("Button", nil, ConfigPanel, "UIPanelCloseButton")
    ConfigPanel.CloseButton:SetPoint("TOPRIGHT", ConfigPanel, "TOPRIGHT", -14, -7)
    ConfigPanel.CloseButton:SetScript("OnClick", function()
        ConfigPanel:Hide()
    end)
end

ConfigPanel:SetMovable(true)
ConfigPanel:EnableMouse(true)
ConfigPanel:RegisterForDrag("LeftButton")
ConfigPanel:SetScript("OnDragStart", ConfigPanel.StartMoving)
ConfigPanel:SetScript("OnDragStop", ConfigPanel.StopMovingOrSizing)
ConfigPanel:HookScript("OnShow", function(panel)
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if type(width) == "number" and type(height) == "number" and width > 30 and height > 30 then
        panel:SetScale(math.min(1, (width - 30) / 1120, (height - 30) / 680))
    end
end)

ConfigPanel.title = ConfigPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ConfigPanel.title:SetPoint("CENTER", ConfigPanel.TitleBg, "CENTER", 0, 0)
ConfigPanel.title:SetText("P5S 目标血条设置")
ApplyTargetPanelTheme("StylePanelTitle", ConfigPanel.title)

local p5CloseButton = ConfigPanel.CloseButton
ApplyTargetPanelTheme("StyleCloseButton", p5CloseButton)
p5CloseButton:HookScript("OnClick", function()
    print("|cffFF0000[P5S 血条]|r 设置已保存，Joker卡酷一！")
end)

local function CreateSettingsSection(parent, x, y, width, height, titleText)
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

    if not ApplyTargetPanelTheme("StyleSection", section, title, accent) then
        section:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        section:SetBackdropColor(0.035, 0.040, 0.058, 0.72)
        section:SetBackdropBorderColor(0.28, 0.32, 0.40, 0.72)
        accent:SetColorTexture(0.82, 0.07, 0.05, 1)
        title:SetTextColor(1.00, 0.25, 0.20, 1)
    end

    return section
end

local function CreateSectionDivider(parent, y)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)
    divider:SetHeight(1)
    divider:SetColorTexture(0.28, 0.32, 0.40, 0.55)
    return divider
end

local function CreateGroupLabel(parent, titleText, metaText, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    title:SetText(titleText)
    ApplyTargetPanelTheme("StyleBodyText", title)

    if metaText then
        local meta = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        meta:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -96, y)
        meta:SetText(metaText)
        ApplyTargetPanelTheme("StyleMutedText", meta)
    end

    return title
end

-- 两栏同类标签共用颜色；在通用主题之后应用，只改变设置面板文字。
local popupLabelColors = {
    WEAK = {1.00, 0.82, 0.30},
    CRITICAL = {1.00, 0.45, 0.42},
    TECHNICAL = {0.30, 0.85, 1.00},
    ["总攻击"] = {0.80, 0.62, 1.00},
}
popupLabelColors["总攻击 · 爆发计时"] = popupLabelColors["总攻击"]

local function ApplyPopupLabelColor(label, text)
    local color = popupLabelColors[text]
    if color then
        label:SetTextColor(color[1], color[2], color[3], 1)
    end
end

local function CreateSlider(name, parent, labelText, minVal, maxVal, step, x, y, dbKey, isFloat, width, layout)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetSize(width or 150, 17)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local lowText = _G[name .. "Low"]
    local highText = _G[name .. "High"]
    local label = _G[name .. "Text"]
    lowText:SetText(minVal)
    highText:SetText(maxVal)
    label:SetText(labelText)

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetWidth(44)
    valueText:SetJustifyH("RIGHT")

    label:ClearAllPoints()
    if layout == "stacked" then
        label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
        valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)
    else
        label:SetWidth(70)
        label:SetJustifyH("LEFT")
        label:SetPoint("RIGHT", slider, "LEFT", -10, 0)
        valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        P5_NameplateDB[dbKey] = value
        if isFloat then
            valueText:SetText(string.format("%.2f", value))
        else
            valueText:SetText(tostring(math.floor(value)))
        end

        if dbKey == "pulseScale" or dbKey == "pulseExpDur" or dbKey == "pulseShrDur" then
            ApplyPulseSettings()
        elseif dbKey == "weakPopupY" or dbKey == "criticalPopupY" or dbKey == "technicalPopupY" or dbKey == "allAttackPopupY" then
            if WeakPopupFrame and WeakPopupFrame:IsShown() then RepositionWeakTestPopup(0) end
            if CriticalPopupFrame and CriticalPopupFrame:IsShown() then RepositionCriticalTestPopup(0) end
            if TechnicalPopupFrame and TechnicalPopupFrame:IsShown() then RepositionTechnicalTestPopup(0) end
            if AllAttackPopupFrame and AllAttackPopupFrame:IsShown() then RepositionAllAttackTestPopup() end
        else
            UpdateP5Visuals()
        end
    end)

    ApplyTargetPanelTheme("StyleSlider", slider)
    ApplyPopupLabelColor(label, labelText)
    ApplyTargetPanelTheme("StyleBodyText", valueText)
    return slider, valueText
end

local sliders = {}
local spellInputs = {}
local allAttackDurationInput = nil
local activeP5SpellInput = nil
local p5SpellLinkHookInstalled = false

local function InstallP5SpellLinkInputHook()
    if p5SpellLinkHookInstalled or type(hooksecurefunc) ~= "function" then return end
    p5SpellLinkHookInstalled = true

    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if activeP5SpellInput and activeP5SpellInput.HasFocus and activeP5SpellInput:HasFocus() and type(link) == "string" then
            activeP5SpellInput:Insert(link)
        end
    end)
end

local function JoinP5List(list)
    if not list or #list == 0 then
        return "无"
    end
    return table.concat(list, ", ")
end

local function SaveP5SpellInput(dbKey, editBox, displayName)
    local text = editBox:GetText() or ""
    P5_NameplateDB[dbKey] = text

    local validList, invalidList = SetSingleP5SpellTriggerMap(dbKey, text)

    if #validList > 0 then
        print("|cffef4444P5_Nameplate:|r " .. displayName .. " 触发技能已保存：" .. JoinP5List(validList))
    else
        print("|cffef4444P5_Nameplate:|r " .. displayName .. " 当前没有有效触发技能。")
    end

    if #invalidList > 0 then
        print("|cffffcc00P5_Nameplate:|r 以下输入无法识别，建议改用 Spell ID：" .. JoinP5List(invalidList))
    end
end

local function CreateSpellInputRow(name, parent, displayName, dbKey, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    label:SetText(displayName)
    ApplyTargetPanelTheme("StyleBodyText", label)
    ApplyPopupLabelColor(label, displayName)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    hint:SetText("回车保存")
    ApplyTargetPanelTheme("StyleMutedText", hint)

    local editBox = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    editBox:SetSize(324, 26)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y - 20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(255)
    editBox:SetScript("OnEnterPressed", function(self)
        SaveP5SpellInput(dbKey, self, displayName)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        activeP5SpellInput = self
        InstallP5SpellLinkInputHook()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        if activeP5SpellInput == self then
            activeP5SpellInput = nil
        end
    end)
    ApplyTargetPanelTheme("StyleEditBox", editBox)

    return editBox
end

local function FormatP5Seconds(value)
    value = GetValidatedAllAttackPulseTime(value)
    local text = string.format("%.2f", value)
    text = text:gsub("0+$", ""):gsub("%.$", "")
    return text
end

local function SaveAllAttackPulseTime(editBox)
    local rawText = TrimP5Text(editBox:GetText() or "")
    local value = tonumber(rawText)

    if not value then
        value = defaultSettings.allAttackPulseTime or 5.00
        print("|cffffcc00P5_Nameplate:|r 总攻击持续时间无法识别，已恢复为默认 " .. FormatP5Seconds(value) .. " 秒。")
    else
        value = GetValidatedAllAttackPulseTime(value)
        print("|cffef4444P5_Nameplate:|r 总攻击持续时间已保存：" .. FormatP5Seconds(value) .. " 秒。")
    end

    P5_NameplateDB.allAttackPulseTime = value
    editBox:SetText(FormatP5Seconds(value))
    ApplyAllAttackDurationSetting()
end

local function CreateDurationInputRow(parent, displayName, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    label:SetText(displayName)
    ApplyTargetPanelTheme("StyleBodyText", label)

    local editBox = CreateFrame("EditBox", "P5AllAttackDurationInput", parent, "InputBoxTemplate")
    editBox:SetSize(90, 26)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y - 20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(8)
    editBox:SetScript("OnEnterPressed", function(self)
        SaveAllAttackPulseTime(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    ApplyTargetPanelTheme("StyleEditBox", editBox)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
    hint:SetText("秒  ·  0.1–60")
    ApplyTargetPanelTheme("StyleMutedText", hint)

    return editBox
end

local function RefreshP5PopupYPosition(dbKey)
    if dbKey == "weakPopupY" then
        if WeakPopupFrame and WeakPopupFrame:IsShown() then RepositionWeakTestPopup(0) end
    elseif dbKey == "criticalPopupY" then
        if CriticalPopupFrame and CriticalPopupFrame:IsShown() then RepositionCriticalTestPopup(0) end
    elseif dbKey == "technicalPopupY" then
        if TechnicalPopupFrame and TechnicalPopupFrame:IsShown() then RepositionTechnicalTestPopup(0) end
    elseif dbKey == "allAttackPopupY" then
        if AllAttackPopupFrame and AllAttackPopupFrame:IsShown() then RepositionAllAttackTestPopup() end
    else
        if WeakPopupFrame and WeakPopupFrame:IsShown() then RepositionWeakTestPopup(0) end
        if CriticalPopupFrame and CriticalPopupFrame:IsShown() then RepositionCriticalTestPopup(0) end
        if TechnicalPopupFrame and TechnicalPopupFrame:IsShown() then RepositionTechnicalTestPopup(0) end
        if AllAttackPopupFrame and AllAttackPopupFrame:IsShown() then RepositionAllAttackTestPopup() end
    end
end

local function ResetSingleP5PopupYPosition(dbKey, sliderKey, displayName)
    P5_NameplateDB[dbKey] = defaultSettings[dbKey]

    if sliders[sliderKey] then
        sliders[sliderKey]:SetValue(P5_NameplateDB[dbKey])
    end

    RefreshP5PopupYPosition(dbKey)
    print("|cffef4444P5_Nameplate:|r " .. displayName .. " 的 Y 轴位置已恢复默认。")
end

local function ResetP5PopupYPositions()
    P5_NameplateDB.weakPopupY = defaultSettings.weakPopupY
    P5_NameplateDB.criticalPopupY = defaultSettings.criticalPopupY
    P5_NameplateDB.technicalPopupY = defaultSettings.technicalPopupY
    P5_NameplateDB.allAttackPopupY = defaultSettings.allAttackPopupY

    if sliders.weakPopupY then sliders.weakPopupY:SetValue(P5_NameplateDB.weakPopupY) end
    if sliders.criticalPopupY then sliders.criticalPopupY:SetValue(P5_NameplateDB.criticalPopupY) end
    if sliders.technicalPopupY then sliders.technicalPopupY:SetValue(P5_NameplateDB.technicalPopupY) end
    if sliders.allAttackPopupY then sliders.allAttackPopupY:SetValue(P5_NameplateDB.allAttackPopupY) end

    RefreshP5PopupYPosition()
    print("|cffef4444P5_Nameplate:|r Weak / Critical / Technical / 总攻击 的 Y 轴位置已全部恢复默认。")
end

local function CreatePopupYResetButton(parent, y, dbKey, sliderKey, displayName)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(62, 24)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, y)
    button:SetText("重置")
    button:SetScript("OnClick", function()
        ResetSingleP5PopupYPosition(dbKey, sliderKey, displayName)
    end)
    ApplyTargetPanelTheme("StyleButton", button)
    return button
end

-- 三张信息卡把目标框体、技能触发和弹字位置分开，所有设置同时可见且无需滚动。
local targetSection = CreateSettingsSection(ConfigPanel, 24, -64, 360, 556, "目标框体")
local spellSection = CreateSettingsSection(ConfigPanel, 400, -64, 360, 556, "技能触发")
local popupSection = CreateSettingsSection(ConfigPanel, 776, -64, 320, 556, "弹字位置")

local function CreateTargetDisplayCheck(name, dbKey, y)
    local check = CreateFrame("CheckButton", name, targetSection, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check:SetPoint("TOPLEFT", targetSection, "TOPLEFT", 98, y)
    local label = check.Text or _G[name .. "Text"]
    if not label then
        label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    check.Text = label
    label:ClearAllPoints()
    label:SetPoint("LEFT", check, "RIGHT", 6, 0)
    label:SetText("启用")
    check:SetScript("OnClick", function(self)
        P5_NameplateDB[dbKey] = self:GetChecked() and true or false
        UpdateP5Visuals()
    end)
    ApplyTargetPanelTheme("StyleCheckBox", check)
    return check
end

CreateGroupLabel(targetSection, "脱战显示", "CHANCE", -40)
local oocEnabledCheck = CreateTargetDisplayCheck("P5OOCEnabledCheck", "oocEnabled", -34)
sliders.oocScale = CreateSlider("P5SliderOOCScale", targetSection, "缩放", 0.5, 2.0, 0.05, 98, -78, "oocScale", true, 188)
sliders.oocX = CreateSlider("P5SliderOOCX", targetSection, "X 偏移", -300, 300, 1, 98, -120, "oocX", false, 188)
sliders.oocY = CreateSlider("P5SliderOOCY", targetSection, "Y 偏移", -300, 300, 1, 98, -162, "oocY", false, 188)

CreateSectionDivider(targetSection, -196)
CreateGroupLabel(targetSection, "进战显示", "爱心血条", -210)
local combatEnabledCheck = CreateTargetDisplayCheck("P5CombatEnabledCheck", "combatEnabled", -204)
sliders.combatScale = CreateSlider("P5SliderCombatScale", targetSection, "缩放", 0.5, 2.0, 0.05, 98, -248, "combatScale", true, 188)
sliders.combatX = CreateSlider("P5SliderCombatX", targetSection, "X 偏移", -300, 300, 1, 98, -290, "combatX", false, 188)
sliders.combatY = CreateSlider("P5SliderCombatY", targetSection, "Y 偏移", -300, 300, 1, 98, -332, "combatY", false, 188)

CreateSectionDivider(targetSection, -366)
CreateGroupLabel(targetSection, "心跳动画", nil, -380)

local pulseCheck = CreateFrame("CheckButton", "P5PulseCheck", targetSection, "UICheckButtonTemplate")
pulseCheck:SetPoint("TOPLEFT", targetSection, "TOPLEFT", 98, -374)
local pulseCheckText = pulseCheck.Text or _G[pulseCheck:GetName() .. "Text"]
if not pulseCheckText then
    pulseCheckText = pulseCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
end
pulseCheck.Text = pulseCheckText
pulseCheckText:ClearAllPoints()
pulseCheckText:SetPoint("LEFT", pulseCheck, "RIGHT", 6, 0)
pulseCheckText:SetText("启用")
pulseCheck:SetScript("OnClick", function(self)
    P5_NameplateDB.pulseEnabled = self:GetChecked()
    UpdateP5Visuals()
end)
ApplyTargetPanelTheme("StyleCheckBox", pulseCheck)

sliders.pulseScale = CreateSlider("P5SliderPulseScale", targetSection, "膨胀比例", 1.0, 1.5, 0.01, 98, -418, "pulseScale", true, 188)
sliders.pulseExpDur = CreateSlider("P5SliderPulseExpDur", targetSection, "膨胀时间", 0.05, 1.0, 0.05, 98, -460, "pulseExpDur", true, 188)
sliders.pulseShrDur = CreateSlider("P5SliderPulseShrDur", targetSection, "回落时间", 0.1, 2.0, 0.05, 98, -502, "pulseShrDur", true, 188)

local function CreateTargetGroupResetButton(y, keys, resetPulse)
    local button = CreateFrame("Button", nil, targetSection, "UIPanelButtonTemplate")
    button:SetSize(62, 24)
    button:SetPoint("TOPRIGHT", targetSection, "TOPRIGHT", -18, y)
    button:SetText("重置")
    button:SetScript("OnClick", function()
        -- 只重置本组，避免覆盖其他分组及尚未按回车的技能输入。
        for _, key in ipairs(keys) do
            P5_NameplateDB[key] = defaultSettings[key]
        end
        for _, key in ipairs(keys) do
            if sliders[key] then sliders[key]:SetValue(P5_NameplateDB[key]) end
        end
        if resetPulse then
            pulseCheck:SetChecked(P5_NameplateDB.pulseEnabled)
            ApplyPulseSettings()
        end
        UpdateP5Visuals()
    end)
    ApplyTargetPanelTheme("StyleButton", button)
end

CreateTargetGroupResetButton(-34, {"oocScale", "oocX", "oocY"})
CreateTargetGroupResetButton(-204, {"combatScale", "combatX", "combatY"})
CreateTargetGroupResetButton(-374, {"pulseEnabled", "pulseScale", "pulseExpDur", "pulseShrDur"}, true)

local spellDesc = spellSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
spellDesc:SetPoint("TOPLEFT", spellSection, "TOPLEFT", 18, -44)
spellDesc:SetWidth(324)
spellDesc:SetJustifyH("LEFT")
spellDesc:SetText("输入技能名称或 Spell ID；多个项目用逗号分隔。")
ApplyTargetPanelTheme("StyleMutedText", spellDesc)

spellInputs.weak = CreateSpellInputRow("P5WeakSpellInput", spellSection, "WEAK", "weakSpellInput", -88)
spellInputs.critical = CreateSpellInputRow("P5CriticalSpellInput", spellSection, "CRITICAL", "criticalSpellInput", -168)
spellInputs.technical = CreateSpellInputRow("P5TechnicalSpellInput", spellSection, "TECHNICAL", "technicalSpellInput", -248)
spellInputs.allAttack = CreateSpellInputRow("P5AllAttackSpellInput", spellSection, "总攻击 · 爆发计时", "allAttackSpellInput", -328)
allAttackDurationInput = CreateDurationInputRow(spellSection, "总攻击持续时间", -408)

local spellTip = spellSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
spellTip:SetPoint("TOPLEFT", spellSection, "TOPLEFT", 18, -476)
spellTip:SetWidth(324)
spellTip:SetJustifyH("LEFT")
spellTip:SetText("示例：121253, 猛虎掌；支持 Shift-点击技能书填入链接。")
ApplyTargetPanelTheme("StyleMutedText", spellTip)

local popupPositionDesc = popupSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
popupPositionDesc:SetPoint("TOPLEFT", popupSection, "TOPLEFT", 18, -44)
popupPositionDesc:SetWidth(284)
popupPositionDesc:SetJustifyH("LEFT")
popupPositionDesc:SetText("仅调整 Y 轴；数值越大，弹字越靠上。")
ApplyTargetPanelTheme("StyleMutedText", popupPositionDesc)

sliders.weakPopupY = CreateSlider("P5SliderWeakPopupY", popupSection, "WEAK", defaultSettings.weakPopupY - 80, defaultSettings.weakPopupY + 80, 1, 18, -108, "weakPopupY", false, 210, "stacked")
sliders.criticalPopupY = CreateSlider("P5SliderCriticalPopupY", popupSection, "CRITICAL", defaultSettings.criticalPopupY - 80, defaultSettings.criticalPopupY + 80, 1, 18, -188, "criticalPopupY", false, 210, "stacked")
sliders.technicalPopupY = CreateSlider("P5SliderTechnicalPopupY", popupSection, "TECHNICAL", defaultSettings.technicalPopupY - 80, defaultSettings.technicalPopupY + 80, 1, 18, -268, "technicalPopupY", false, 210, "stacked")
sliders.allAttackPopupY = CreateSlider("P5SliderAllAttackPopupY", popupSection, "总攻击", defaultSettings.allAttackPopupY - 80, defaultSettings.allAttackPopupY + 80, 1, 18, -348, "allAttackPopupY", false, 210, "stacked")

CreatePopupYResetButton(popupSection, -99, "weakPopupY", "weakPopupY", "Weak")
CreatePopupYResetButton(popupSection, -179, "criticalPopupY", "criticalPopupY", "Critical")
CreatePopupYResetButton(popupSection, -259, "technicalPopupY", "technicalPopupY", "Technical")
CreatePopupYResetButton(popupSection, -339, "allAttackPopupY", "allAttackPopupY", "总攻击")

local resetPopupPositionBtn = CreateFrame("Button", nil, popupSection, "UIPanelButtonTemplate")
resetPopupPositionBtn:SetSize(128, 28)
resetPopupPositionBtn:SetPoint("TOPLEFT", popupSection, "TOPLEFT", 18, -400)
resetPopupPositionBtn:SetText("重置全部位置")
resetPopupPositionBtn:SetScript("OnClick", function()
    ResetP5PopupYPositions()
end)
ApplyTargetPanelTheme("StyleButton", resetPopupPositionBtn)

local popupPositionTip = popupSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
popupPositionTip:SetPoint("TOPLEFT", popupSection, "TOPLEFT", 18, -450)
popupPositionTip:SetWidth(284)
popupPositionTip:SetJustifyH("LEFT")
popupPositionTip:SetText("单项重置只影响对应弹字；重置全部位置不会改动技能、持续时间或血条设置。")
ApplyTargetPanelTheme("StyleMutedText", popupPositionTip)

local function InitSliders()
    oocEnabledCheck:SetChecked(P5_NameplateDB.oocEnabled)
    combatEnabledCheck:SetChecked(P5_NameplateDB.combatEnabled)
    sliders.oocScale:SetValue(P5_NameplateDB.oocScale)
    sliders.oocX:SetValue(P5_NameplateDB.oocX)
    sliders.oocY:SetValue(P5_NameplateDB.oocY)
    sliders.combatScale:SetValue(P5_NameplateDB.combatScale)
    sliders.combatX:SetValue(P5_NameplateDB.combatX)
    sliders.combatY:SetValue(P5_NameplateDB.combatY)

    pulseCheck:SetChecked(P5_NameplateDB.pulseEnabled)
    sliders.pulseScale:SetValue(P5_NameplateDB.pulseScale)
    sliders.pulseExpDur:SetValue(P5_NameplateDB.pulseExpDur)
    sliders.pulseShrDur:SetValue(P5_NameplateDB.pulseShrDur)

    if spellInputs.weak then spellInputs.weak:SetText(P5_NameplateDB.weakSpellInput or "") end
    if spellInputs.critical then spellInputs.critical:SetText(P5_NameplateDB.criticalSpellInput or "") end
    if spellInputs.technical then spellInputs.technical:SetText(P5_NameplateDB.technicalSpellInput or "") end
    if spellInputs.allAttack then spellInputs.allAttack:SetText(P5_NameplateDB.allAttackSpellInput or "") end
    if allAttackDurationInput then allAttackDurationInput:SetText(FormatP5Seconds(P5_NameplateDB.allAttackPulseTime)) end

    if sliders.weakPopupY then sliders.weakPopupY:SetValue(P5_NameplateDB.weakPopupY or defaultSettings.weakPopupY) end
    if sliders.criticalPopupY then sliders.criticalPopupY:SetValue(P5_NameplateDB.criticalPopupY or defaultSettings.criticalPopupY) end
    if sliders.technicalPopupY then sliders.technicalPopupY:SetValue(P5_NameplateDB.technicalPopupY or defaultSettings.technicalPopupY) end
    if sliders.allAttackPopupY then sliders.allAttackPopupY:SetValue(P5_NameplateDB.allAttackPopupY or defaultSettings.allAttackPopupY) end

    RebuildP5SpellTriggerMaps()
    ApplyAllAttackDurationSetting()
    ApplyPulseSettings()
end

local backToMainButton = CreateFrame("Button", "P5TargetBackToMainButton", ConfigPanel, "UIPanelButtonTemplate")
backToMainButton:SetSize(156, 26)
backToMainButton:SetPoint("BOTTOMRIGHT", ConfigPanel, "BOTTOMRIGHT", -24, 17)
backToMainButton:SetText("返回P5S主界面")
backToMainButton:SetScript("OnClick", function()
    ConfigPanel:Hide()

    local mainPanel = _G.P5S_OptionsPanel
    if mainPanel and mainPanel:IsShown() then
        if mainPanel.Raise then mainPanel:Raise() end
        return
    end

    local commandHandler = SlashCmdList and SlashCmdList["P5SUI"]
    if type(commandHandler) ~= "function" then
        print("|cffFF0000[P5血条]|r P5S 主界面设置暂时不可用。")
        return
    end
    commandHandler("")
end)
ApplyTargetPanelTheme("StyleButton", backToMainButton)

local footerTip = ConfigPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footerTip:SetPoint("BOTTOMLEFT", ConfigPanel, "BOTTOMLEFT", 24, 23)
footerTip:SetWidth(880)
footerTip:SetJustifyH("LEFT")
footerTip:SetText("滑块实时生效  ·  技能与持续时间按回车保存  ·  /p5atk 预览总攻击")
ApplyTargetPanelTheme("StyleMutedText", footerTip)

-- 临时预览总攻击弹字：选中目标后输入 /p5atk。
-- 现在也已经接入活血术 SpellID 116670，用于技能触发测试。
SLASH_P5ALLATTACK1 = "/p5atk"
SlashCmdList["P5ALLATTACK"] = function()
    ShowAllAttackTestPopup()
end

-- ==========================================
-- 5. 事件拦截
-- ==========================================
P5Frame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    
    if event == "ADDON_LOADED" and arg1 == "P5S" then
        if P5_NameplateDB == nil then P5_NameplateDB = {} end
        for k, v in pairs(defaultSettings) do
            if P5_NameplateDB[k] == nil then P5_NameplateDB[k] = v end
        end
        -- 新开关兼容旧角色配置；明确保存的 false 必须保留。
        if type(P5_NameplateDB.oocEnabled) ~= "boolean" then P5_NameplateDB.oocEnabled = true end
        if type(P5_NameplateDB.combatEnabled) ~= "boolean" then P5_NameplateDB.combatEnabled = true end
        RebuildP5SpellBookNameCache()
        InitSliders()
        return
    end

    if event == "PLAYER_LOGIN" then
        RebuildP5SpellBookNameCache()
        RebuildP5SpellTriggerMaps()
        print("|cffFF0000[P5S UI]|r 插件已加载，请输入 |cffffd100/p5s|r 打开设置面板。")
        return
    end

    if event == "SPELLS_CHANGED" then
        -- 战斗中有些技能会导致 SPELLS_CHANGED，例如技能临时变化、替换或充能相关刷新。
        -- 这里不能重建触发映射，否则中文技能名会因为不能安全扫描技能书而被解析失败，
        -- 最终把 weak/critical/technical/allAttack 的映射表清空，表现为“打着打着弹字全部失效”。
        if InCombatLockdown and InCombatLockdown() then
            p5PendingSpellBookCacheRebuild = true
            return
        end

        RebuildP5SpellBookNameCache()
        RebuildP5SpellTriggerMaps()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and p5PendingSpellBookCacheRebuild then
        RebuildP5SpellBookNameCache()
        RebuildP5SpellTriggerMaps()
        -- 不 return，继续刷新一次目标显示。
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "player" then
            -- 这里仍然只判断事件给到的 spellID，不读取玩家 Buff / Aura / 技能充能。
            if weakSpellIDMap[spellID] then
                ShowWeakTestPopup()
            end

            if criticalSpellIDMap[spellID] then
                ShowCriticalTestPopup()
            end

            if technicalSpellIDMap[spellID] then
                ShowTechnicalTestPopup()
            end

            if allAttackSpellIDMap[spellID] then
                ShowAllAttackTestPopup()
            end
        end
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 == "target" and CombatGroup:IsShown() then
            UpdateTargetHealth()
            UpdateTargetShield()
        end
        return 
    end

    if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if arg1 == "target" and CombatGroup:IsShown() then UpdateTargetShield() end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        OOCGroup:Hide()
        CombatGroup:Hide()
        texOOCText:Hide()
        HideWeakTestPopup()
        HideCriticalTestPopup()
        HideTechnicalTestPopup()
        -- 总攻击是爆发提示：目标切换时不清除，只让 OnUpdate 在剩余时间内重新挂到新目标。
        UpdateP5Visuals()
        if allAttackPopupActive then
            RepositionAllAttackTestPopup()
        end
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        if UnitIsUnit(arg1, "target") then
            OOCGroup:Hide()
            CombatGroup:Hide()
            texOOCText:Hide()
            HideWeakTestPopup()
            HideCriticalTestPopup()
            HideTechnicalTestPopup()
            -- 总攻击不因姓名板刷新/目标血条重建而结束；OnUpdate 会在剩余时间内重新挂载。
            UpdateP5Visuals()
            if allAttackPopupActive then
                RepositionAllAttackTestPopup()
            end
        end
        return
    end

    if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_FLAGS" then
        if arg1 ~= "target" and arg1 ~= "player" then return end
    end
    
    UpdateP5Visuals()
end)
