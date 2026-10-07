local _, addon = ...
local options = addon.WeakOptions
if not options then return end

-- ==================== 眼神特写调参区 ====================
-- 修改后保存本文件，在游戏里 /reload。两个角色可以分别调整。
-- 三段顺序播放：入场并渐显 → 中间展示 → 出场并渐隐；形变与透明度同时变化。
-- 时间单位：秒；Joker 总时长 = slideIn + hold + slideOut；结城理 = scaleIn + hold + scaleOut。
-- fadeIn/fadeOut 包含在对应入场/出场时间内，超过时自动缩短；0 表示不渐变。
-- 渐显从入场开始；渐隐在出场末尾完成。入场/出场时间为 0 时立即完成该阶段。
-- 距离单位：UI 单位，不随图片大小缩放。保存的 X/Y 是中间停留时的图片中心。
-- 滑入起点 = X - slideInDistance；滑出终点 = X + slideOutDistance。
-- smoothing 控制快慢变化：NONE 匀速、IN 慢入、OUT 慢出、IN_OUT 慢入慢出、OUT_IN 快入快出。
local PORTRAIT_CONFIG = {
    joker = {
        fadeIn = 0.15,       -- 入场滑动期间渐显
        slideIn = 0.15,      -- 入场总时间：从左侧平滑移动到保存的位置
        hold = 0.7,          -- 中间原地停留
        slideOut = 0.4,     -- 出场总时间：原地渐隐
        fadeOut = 0.4,      -- 原地渐隐消失，单位：秒
        slideInDistance = 50,
        slideOutDistance = 0, -- 不进行出场滑动，保持停留位置
        fadeSmoothing = "IN_OUT",
        slideSmoothing = "IN_OUT",
    },
    makoto = {              -- 结城理，与 Joker 完全独立
        animation = "scale", -- 原地缩放，不进行左右移动
        fadeIn = 0.2,        -- 与入场放大同时渐显
        scaleIn = 0.15,       -- 入场放大时间
        hold = 1,          -- 保持中心位置，同时缓慢微放大
        scaleOut = 0.15,      -- 出场快速放大时间
        fadeOut = 0.2,       -- 与出场放大同时渐隐
        -- 以下均为相对面板“图片大小”的绝对倍数（不是逐段相乘），允许 0.05～5。
        startScale = 0.85,   -- 入场起始大小：85%
        enterScale = 1.00,   -- 入场结束大小：100%
        holdScale = 1.04,    -- 中间结束大小：104%；设为与 enterScale 相同可取消微放大
        exitScale = 1.25,    -- 出场结束大小：125%
        fadeSmoothing = "IN_OUT",
        scaleSmoothing = "IN_OUT", -- 入场/出场放大的速度曲线
        holdSmoothing = "NONE",    -- 中间微放大匀速进行
    },
}
-- ==================== 调参区结束 ====================

local definitions = {
    joker = { field = "weakJokerSpellInput", texture = "肘可特写.tga", ratio = 1024 / 2048 },
    makoto = { field = "weakMakotoSpellInput", texture = "牢理特写.tga", ratio = 1080 / 1920 },
}
local actors, bindings, nameCache = {}, {}, {}
local previews, pendingBook = {}, false
local runtime = {}
addon.WeakPortraits = runtime

-- 在任何比较、格式化或索引外部值之前检查。缺少安全 API 时安静拒绝。
local function Public(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and not secret
end
local function Number(value)
    if not Public(value) or type(value) ~= "number" then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end
local function SpellID(value)
    value = Number(value)
    if value and value > 0 and value <= 2147483647 and value == math.floor(value) then return value end
end
local function InCombat()
    if type(InCombatLockdown) ~= "function" then return true end
    local ok, result = pcall(InCombatLockdown)
    return not ok or not Public(result) or result ~= false
end
local function SpellInfo(value)
    if not C_Spell or type(C_Spell.GetSpellInfo) ~= "function" then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, value)
    if ok and Public(info) and type(info) == "table" then return info end
end
local function AddBookEntry(slot, bank)
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
    if not ok or not Public(info) or type(info) ~= "table" then return end
    local id = SpellID(info.spellID)
    if not id then return end
    local spell = SpellInfo(id)
    local name = spell and spell.name
    if Public(name) and type(name) == "string" and name ~= "" then nameCache[name] = id end
end
local function RebuildBook()
    if InCombat() then pendingBook = true; return end
    pendingBook = false
    nameCache = {}
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function"
        or type(C_SpellBook.GetSpellBookSkillLineInfo) ~= "function"
        or type(C_SpellBook.GetSpellBookItemInfo) ~= "function" then return end
    local ok, count = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    count = ok and Number(count)
    if not count or count < 0 or count > 100 then return end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not bank then return end
    for line = 1, math.floor(count) do
        local valid, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if valid and Public(info) and type(info) == "table" then
            local offset, items = Number(info.itemIndexOffset), Number(info.numSpellBookItems)
            if offset and items and offset >= 0 and items >= 0 and offset + items <= 4096 then
                for slot = math.floor(offset) + 1, math.floor(offset + items) do AddBookEntry(slot, bank) end
            end
        end
    end
end

function runtime.InvalidateBinding(key)
    bindings[key] = nil
    options.SetBindingStatus(key, "输入已保存，回车或离开输入框完成绑定")
end
function runtime.ResolveBinding(key)
    local def, config = definitions[key], options.GetSettings(key)
    if not def or not config then return end
    if actors[key] and actors[key].failed then
        bindings[key] = nil
        options.SetBindingStatus(key, "图片或动画加载失败，本次加载已停用此图")
        return
    end
    local text = P5S_UI_DB[def.field]
    if type(text) ~= "string" then text = "" end
    text = text:match("^%s*(.-)%s*$")
    bindings[key] = nil
    if text == "" then
        config.resolvedInput, config.resolvedSpellID = nil, nil
        options.SetBindingStatus(key, "未绑定：输入技能名称、Spell ID 或链接")
        return
    end
    local id = SpellID(tonumber(text:match("spell:(%d+)") or text)) or nameCache[text]
    -- 已解析的同一输入可在战斗中重载后恢复，不查询战斗数据。
    if not id and InCombat() and config.resolvedInput == text then id = SpellID(config.resolvedSpellID) end
    if not id and not InCombat() then
        local info = SpellInfo(text)
        if info then id = SpellID(info.spellID) end
    end
    if id then
        bindings[key] = id
        config.resolvedInput, config.resolvedSpellID = text, id
        options.SetBindingStatus(key, "已绑定 Spell ID: " .. id)
    else
        config.resolvedInput, config.resolvedSpellID = nil, nil
        options.SetBindingStatus(key, InCombat() and "技能名称待脱战解析；也可直接填 Spell ID" or "未识别技能，请填写实际施放的 Spell ID")
    end
end

local function SetVisual(actor, offset, alpha, scale)
    if actor.scaleStages then actor.visual:SetScale(scale or 1) end
    actor.visual:ClearAllPoints()
    actor.visual:SetPoint("CENTER", actor.frame, "CENTER", offset, 0)
    actor.visual:SetAlpha(alpha)
end
local function StopActor(actor)
    actor.active, actor.current = false, nil
    actor.frame:SetScript("OnUpdate", nil)
    actor.drag = nil
    for _, group in ipairs(actor.groups) do group:Stop() end
end
local function Rest(actor)
    local config = options.GetSettings(actor.key)
    local preview = previews[actor.key] and config
    SetVisual(actor, 0, 1)
    actor.frame:EnableMouse(preview and not config.isLocked or false)
    if preview then actor.frame:Show() else actor.frame:Hide() end
end
local function DisableActor(actor)
    actor.failed = true
    pcall(StopActor, actor)
    pcall(actor.frame.Hide, actor.frame)
    options.SetBindingStatus(actor.key, "图片或动画加载失败，本次加载已停用此图")
end
local function SafeActor(actor, fn, ...)
    if not actor or actor.failed then return end
    if not pcall(fn, actor, ...) then DisableActor(actor) end
end
local function ApplyLayout(actor)
    local config = options.GetSettings(actor.key)
    if not config then return end
    actor.frame:ClearAllPoints()
    actor.frame:SetPoint("CENTER", UIParent, "CENTER", config.xOfs, config.yOfs)
    actor.frame:SetSize(config.size, config.size * definitions[actor.key].ratio)
    actor.visual:SetSize(config.size, config.size * definitions[actor.key].ratio)
    if config.isLocked or not previews[actor.key] then
        actor.drag = nil
        actor.frame:SetScript("OnUpdate", nil)
    end
    if not actor.active then Rest(actor) end
end
local function Advance(actor, stage)
    if stage > 3 then
        actor.active, actor.current = false, nil
        Rest(actor)
        return
    end
    local tuning = PORTRAIT_CONFIG[actor.key]
    local alpha = stage == 1 and tuning.fadeIn > 0 and 0 or 1
    if actor.scaleStages then
        SetVisual(actor, 0, alpha, actor.scaleStages[stage][1])
    else
        SetVisual(actor, stage == 1 and -tuning.slideInDistance or 0, alpha)
    end
    actor.current = actor.groups[stage]
    if actor.durations[stage] == 0 then Advance(actor, stage + 1) else actor.current:Play() end
end
local function PlayActor(actor)
    if previews[actor.key] then return end -- 调位置期间保持静态，不被技能打断。
    StopActor(actor)
    ApplyLayout(actor)
    actor.active = true
    actor.frame:EnableMouse(false)
    -- 先设为透明，防止 Show 当帧闪出停留位置。
    SetVisual(actor, 0, 0)
    actor.frame:Show()
    Advance(actor, 1)
end
local function BuildActor(actor)
    local tuning = PORTRAIT_CONFIG[actor.key]
    local isScale = tuning.animation == "scale"
    local enterTime = isScale and tuning.scaleIn or tuning.slideIn
    local exitTime = isScale and tuning.scaleOut or tuning.slideOut
    local durations = { tuning.fadeIn, enterTime, tuning.hold, exitTime, tuning.fadeOut }
    local smoothing = { NONE = true, IN = true, OUT = true, IN_OUT = true, OUT_IN = true }
    assert(smoothing[tuning.fadeSmoothing])
    for _, duration in ipairs(durations) do assert(Number(duration) and duration >= 0 and duration <= 60) end
    assert(#durations == 5)
    if isScale then
        assert(smoothing[tuning.scaleSmoothing] and smoothing[tuning.holdSmoothing])
        for _, field in ipairs({ "startScale", "enterScale", "holdScale", "exitScale" }) do
            local value = Number(tuning[field])
            assert(value and value >= 0.05 and value <= 5)
        end
        actor.scaleStages = {
            { tuning.startScale, tuning.enterScale },
            { tuning.enterScale, tuning.holdScale },
            { tuning.holdScale, tuning.exitScale },
        }
    else
        assert(smoothing[tuning.slideSmoothing])
        for _, distance in ipairs({ tuning.slideInDistance, tuning.slideOutDistance }) do
            assert(Number(distance) and distance >= 0 and distance <= 10000)
        end
    end
    actor.durations = { enterTime, tuning.hold, exitTime }
    local visual = CreateFrame("Frame", nil, actor.frame)
    actor.visual = visual
    visual:EnableMouse(false)
    local texture = visual:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(visual)
    assert(texture:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\" .. definitions[actor.key].texture) ~= false)
    for stage = 1, 3 do
        local group = visual:CreateAnimationGroup()
        actor.groups[stage] = group
        local duration = actor.durations[stage]
        local kind = isScale and "Scale" or (stage == 2 and "Animation" or "Translation")
        local animation = group:CreateAnimation(kind)
        animation:SetOrder(1)
        animation:SetDuration(duration)
        if kind == "Scale" then
            -- 每段从上一段的绝对大小衔接；原生动画只施加该段的相对倍率。
            local scales = actor.scaleStages[stage]
            local ratio = scales[2] / scales[1]
            animation:SetOrigin("CENTER", 0, 0)
            animation:SetScaleFrom(1, 1)
            animation:SetScaleTo(ratio, ratio)
            animation:SetSmoothing(stage == 2 and tuning.holdSmoothing or tuning.scaleSmoothing)
        elseif kind == "Translation" then
            animation:SetOffset(stage == 1 and tuning.slideInDistance or tuning.slideOutDistance, 0)
            animation:SetSmoothing(tuning.slideSmoothing)
        end
        if stage ~= 2 then
            local fadeDuration = math.min(stage == 1 and tuning.fadeIn or tuning.fadeOut, duration)
            if fadeDuration > 0 then
                -- 相同 order：Alpha 与 Translation 并行，阶段结束前始终保留最终透明度。
                local alpha = group:CreateAnimation("Alpha")
                alpha:SetOrder(1)
                alpha:SetDuration(fadeDuration)
                alpha:SetFromAlpha(stage == 1 and 0 or 1)
                alpha:SetToAlpha(stage == 1 and 1 or 0)
                alpha:SetSmoothing(tuning.fadeSmoothing)
                if stage == 1 then
                    alpha:SetEndDelay(duration - fadeDuration)
                else
                    alpha:SetStartDelay(duration - fadeDuration)
                end
                group:SetToFinalAlpha(true)
            end
        end
        group:SetScript("OnFinished", function()
            if actor.active and actor.current == group then SafeActor(actor, Advance, stage + 1) end
        end)
        group:SetScript("OnStop", function()
            if actor.active and actor.current == group then
                SafeActor(actor, function(self) self.active, self.current = false, nil; Rest(self) end)
            end
        end)
    end
    actor.frame:SetScript("OnHide", function() SafeActor(actor, StopActor) end)
    actor.frame:RegisterForDrag("LeftButton")
    actor.frame:SetScript("OnDragStart", function()
        SafeActor(actor, function(self)
            local config = options.GetSettings(self.key)
            if not previews[self.key] or config.isLocked or self.active then return end
            local x, y = GetCursorPosition()
            local scale = Number(UIParent:GetEffectiveScale())
            if not Number(x) or not Number(y) or not scale or scale <= 0 then return end
            self.drag = { x = x, y = y, xOfs = config.xOfs, yOfs = config.yOfs, scale = scale }
            self.frame:SetScript("OnUpdate", function()
                SafeActor(self, function(current)
                    local drag = current.drag
                    if not drag then return end
                    local cx, cy = GetCursorPosition()
                    if not Number(cx) or not Number(cy) then return end
                    local settings = options.GetSettings(current.key)
                    settings.xOfs = math.max(-10000, math.min(10000, drag.xOfs + (cx - drag.x) / drag.scale))
                    settings.yOfs = math.max(-10000, math.min(10000, drag.yOfs + (cy - drag.y) / drag.scale))
                    ApplyLayout(current)
                end)
            end)
        end)
    end)
    actor.frame:SetScript("OnDragStop", function()
        actor.drag = nil
        actor.frame:SetScript("OnUpdate", nil)
    end)
    ApplyLayout(actor)
end

function runtime.RefreshLayout(key) SafeActor(actors[key], ApplyLayout) end
function runtime.SetPreview(key, value)
    if not definitions[key] then return end
    previews[key] = value and true or false
    SafeActor(actors[key], function(actor)
        if previews[key] then StopActor(actor) end
        ApplyLayout(actor)
    end)
end
local initialized = false
local function Initialize()
    if initialized or not P5S_UI_DB then return end
    initialized = true
    for key in pairs(definitions) do
        local frame = CreateFrame("Frame", "P5S_WeakPortrait_" .. key, UIParent)
        frame:Hide()
        frame:SetFrameStrata("HIGH")
        local actor = { key = key, frame = frame, groups = {} }
        actors[key] = actor
        SafeActor(actor, BuildActor)
    end
    RebuildBook()
    for key in pairs(definitions) do runtime.ResolveBinding(key) end
end
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Initialize()
        if event == "PLAYER_ENTERING_WORLD" then
            for key in pairs(definitions) do runtime.RefreshLayout(key) end
        end
    elseif event == "SPELLS_CHANGED" then
        RebuildBook()
        if not pendingBook then
            for key in pairs(definitions) do runtime.ResolveBinding(key) end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingBook then RebuildBook() end
        for key in pairs(definitions) do runtime.ResolveBinding(key) end
    elseif event == "PLAYER_LEAVING_WORLD" then
        for _, actor in pairs(actors) do
            SafeActor(actor, function(self) StopActor(self); self.frame:Hide() end)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 唯一战斗触发来源：玩家事件直接提供的 spellID；不读 Aura/冷却/充能。
        if not Public(unit) or unit ~= "player" then return end
        spellID = SpellID(spellID)
        if not spellID then return end
        for key, id in pairs(bindings) do
            if spellID == id then SafeActor(actors[key], PlayActor) end
        end
    end
end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_LEAVING_WORLD", "UNIT_SPELLCAST_SUCCEEDED" }) do
    pcall(events.RegisterEvent, events, event)
end
