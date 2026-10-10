local _, addon = ...

local reportedThemeErrors = {}

local function ApplyPanelTheme(methodName, ...)
    local panelTheme = addon and addon.PanelTheme
    local method = panelTheme and panelTheme[methodName]
    if type(method) ~= "function" then return false end

    local ok, errorMessage = pcall(method, panelTheme, ...)
    if not ok and not reportedThemeErrors[methodName] then
        reportedThemeErrors[methodName] = true
        print("|cffFF3333[P5S UI]|r 主题样式加载失败（" .. methodName .. "）：" .. tostring(errorMessage))
    end
    return ok
end

-- ==========================================
-- 1. 基础设置与位置微调区
-- ==========================================
local BASE_SIZE = 400
local MIN_SIZE = 200
local MAX_SIZE = 800

local HIT_LEFT   = 40    
local HIT_RIGHT  = 180   
local HIT_TOP    = 150    
local HIT_BOTTOM = 100    

-- 【HP 血条调整参数】
local HP_WIDTH  = 196.5
local HP_HEIGHT = 195
local HP_X      = 91.5
local HP_Y      = -19
local HP_ANGLE  = 0.5    

-- 【HP 护盾条调整参数】
local SHIELD_WIDTH  = 196.5
local SHIELD_HEIGHT = 195
local SHIELD_X      = 91.5
local SHIELD_Y      = -19.5
local SHIELD_ANGLE  = 0.5     

-- 【SP 能量条调整参数】
local SP_WIDTH  = 184
local SP_HEIGHT = 180
local SP_X      = 66
local SP_Y      = -30
local SP_ANGLE  = 0     

-- 【角色等级文字调整参数】
local LV_SIZE   = 24    
local LV_X      = -51    
local LV_Y      = -57    
local LV_ANGLE  = 0.5     

-- 【数值文字区块调整参数】
local TEXT_X     = 122      
local TEXT_Y     = -5     
local TEXT_ANGLE = 0.5     
local VALUE_SIZE = 26      
local SLASH_SIZE = 20      
local LABEL_SIZE = 14      

-- 【漫画风错位黑底参数】
local SHADOW_X   = 5.5       
local SHADOW_Y   = 1      

-- 【状态图标调整参数 (攻、防、速)】
local ATK_WIDTH  = 250
local ATK_HEIGHT = 250
local ATK_X      = 170
local ATK_Y      = 50
local ATK_ANGLE  = 0

local DEF_WIDTH  = 250
local DEF_HEIGHT = 250
local DEF_X      = 178
local DEF_Y      = 43
local DEF_ANGLE  = 0

local SPD_WIDTH  = 250
local SPD_HEIGHT = 250
local SPD_X      = 182
local SPD_Y      = 35
local SPD_ANGLE  = 0

-- === 【动态卡槽视觉偏移参数】 ===
local SLOT_SHIFT_X = 73  
local SLOT_SHIFT_Y = 0   

-- ==========================================
-- 2. 创建主框体 (Joker 血条主体)
-- ==========================================
local P5SFrame = CreateFrame("Frame", "P5S_MainFrame", UIParent)
P5SFrame:SetSize(BASE_SIZE, BASE_SIZE) 

function P5SFrame:ApplyResourceBarVisibility()
    local enabled = not P5S_UI_DB or P5S_UI_DB.resourceBarEnabled ~= false
    -- 只改变整套组件的可见性与鼠标交互，保留原生动画和 Showtime 时间轴。
    -- 不读取子 Aura 控件的显隐或其他受限值，也不改变各子项的独立开关。
    if not enabled then self:StopMovingOrSizing() end
    self:SetAlpha(enabled and 1 or 0)
    self:EnableMouse(enabled)
    if self.resourceBarCheck then self.resourceBarCheck:SetChecked(enabled) end
end

-- 第三资源使用主框体上的内部对象，避免长期占用 core.lua 已接近上限的顶层局部变量。
P5SFrame.thirdResource = {
    -- 【样式 A 的视觉微调】样式 B/C/D 在下方各自独立调整。
    scale = 0.87,        -- 单张贴纸缩放：1 为原尺寸
    offsetX = 38,        -- 整排横向偏移：正数向右，负数向左
    offsetY = 4,      -- 整排纵向偏移：正数向上，负数向下
    rowAngle = 5,        -- 整排基线角度：正数让右端抬高，即逆时针倾斜

    -- 【基础排版】通常不必修改；stepX 控制贴纸之间的横向间距。
    maxSlots = 7,
    slotWidth = 31,
    slotHeight = 32,
    startX = 4,
    centerY = -92,
    stepX = 18,
    texture = "Interface\\AddOns\\P5S\\P5S_UI\\Media\\第三资源贴纸_A.tga",
    styleOrder = {"A", "B", "C", "D"},
    styles = {
        A = {
            label = "样式A",
            texture = "Interface\\AddOns\\P5S\\P5S_UI\\Media\\第三资源贴纸_A.tga",
        },
        B = {
            label = "样式B",
            texture = "Interface\\AddOns\\P5S\\P5S_UI\\Media\\第三资源贴纸_E.tga",
            -- 【样式 B 独立排版】只改这里即可；保存后进游戏 /reload 查看。
            -- 保留用户调好的参数；与样式 A/C/D 独立，后续调整互不影响。
            layout = {
                scale = 0.87,       -- 单张贴纸缩放：越大越大，不改变中心间距
                offsetX = 38,       -- 整排左右偏移：正数向右，负数向左
                offsetY = 4,        -- 整排上下偏移：正数向上，负数向下
                rowAngle = 5,       -- 基线倾斜角度：正数让右端抬高
                slotWidth = 40,     -- 单张基础宽度（最终再乘 scale）
                slotHeight = 30,    -- 单张基础高度（最终再乘 scale）
                startX = 4,         -- 整排基础起点 X，通常只调 offsetX 即可
                centerY = -92,      -- 整排基础位置 Y，通常只调 offsetY 即可
                stepX = 18,         -- 相邻贴纸中心的横向间距：越大越疏
                -- 以下 7 项按固定槽位从左到右；不足 7 格时显示最右侧所需格数。
                angles = {-10, -3, 8, -10, 10, 4, -8}, -- 各贴纸旋转角度，0 为不旋转
                yOffsets = {-2, -4, 1, -2, 1, 4, 3},  -- 各贴纸在基线旋转前的上下错位
            },
        },
        C = {
            label = "样式C",
            texture = "Interface\\AddOns\\P5S\\P5S_UI\\Media\\第三资源贴纸_B.tga",
            -- 【样式 C 独立排版】只改这里即可；保存后进游戏 /reload 查看。
            -- 初值复制自用户调好的样式 B；本套参数独立，后续调整互不影响。
            layout = {
                scale = 0.87,       -- 单张贴纸缩放：越大越大，不改变中心间距
                offsetX = 38,       -- 整排左右偏移：正数向右，负数向左
                offsetY = 4,        -- 整排上下偏移：正数向上，负数向下
                rowAngle = 5,       -- 基线倾斜角度：正数让右端抬高
                slotWidth = 43,     -- 单张基础宽度（最终再乘 scale）
                slotHeight = 32,    -- 单张基础高度（最终再乘 scale）
                startX = 4,         -- 整排基础起点 X，通常只调 offsetX 即可
                centerY = -92,      -- 整排基础位置 Y，通常只调 offsetY 即可
                stepX = 18,         -- 相邻贴纸中心的横向间距：越大越疏
                -- 以下 7 项按固定槽位从左到右；不足 7 格时显示最右侧所需格数。
                angles = {-10, -3, 8, -10, 10, 4, -8}, -- 各贴纸旋转角度，0 为不旋转
                yOffsets = {-2, -4, 1, -2, 1, 4, 1},  -- 各贴纸在基线旋转前的上下错位
            },
        },
        D = {
            label = "样式D",
            texture = "Interface\\AddOns\\P5S\\P5S_UI\\Media\\第三资源贴纸_F.tga",
            -- 【样式 D 独立排版】只改这里即可；保存后进游戏 /reload 查看。
            -- 初值复制自用户调好的样式 B；本套参数独立，后续调整互不影响。
            layout = {
                scale = 0.88,       -- 单张贴纸缩放：越大越大，不改变中心间距
                offsetX = 38,       -- 整排左右偏移：正数向右，负数向左
                offsetY = 4,        -- 整排上下偏移：正数向上，负数向下
                rowAngle = 5,       -- 基线倾斜角度：正数让右端抬高
                slotWidth = 38,     -- 单张基础宽度（最终再乘 scale）
                slotHeight = 36,    -- 单张基础高度（最终再乘 scale）
                startX = 4,         -- 整排基础起点 X，通常只调 offsetX 即可
                centerY = -92,      -- 整排基础位置 Y，通常只调 offsetY 即可
                stepX = 18,         -- 相邻贴纸中心的横向间距：越大越疏
                -- 以下 7 项按固定槽位从左到右；不足 7 格时显示最右侧所需格数。
                angles = {0, 0, 0, 0, 0, 0, 0}, -- 各贴纸旋转角度，0 为不旋转
                yOffsets = {-3.8, -2.8, -1.9, -1, 0, 1, 2},  -- 各贴纸在基线旋转前的上下错位
            },
        },
    },
    angles = {-10, -3, 8, -10, 10, 4, -8}, -- 样式 A 各贴纸旋转
    yOffsets = {-2, -4, 1, -2, 1, 4, 1},  -- 样式 A 各贴纸上下错位
    emptyBrightness = 0.48,
    runeCooldownBrightness = 0.72, -- 死亡骑士冷却灰色明度：越小越暗
    slots = {},
}

P5SFrame:SetHitRectInsets(HIT_LEFT, HIT_RIGHT, HIT_TOP, HIT_BOTTOM)

-- 亚森火焰：BLP 是 8 列 × 16 行的图集，前 79 格有效（每格 256²）。
-- 仅使用 Showtime 的手填爆发时间与本地时钟，不读取 Aura 或冷却数值。
-- 单独作用域避免增加本文件已接近 Lua 5.1 上限的顶层局部变量。
do
    -- 【亚森背景火焰微调】只改这里；保存文件后 /reload，再点 Showtime“快速预览”。
    -- 宽高和偏移使用主框体的基础 UI 单位，最终跟随主框体整体缩放。
    local FIRE_CONFIG = {
        width = 300,  -- 宽度：越大越宽，必须大于 0
        height = 290, -- 高度：越大越高，必须大于 0
        x = -90,       -- 相对主框体中心：正数向右，负数向左
        y = 70,       -- 相对主框体中心：正数向上，负数向下
        fps = 30,    -- 每秒播放帧数：越大越快，必须大于 0
        frames = 79, -- 循环前 N 帧：整数 1～79，通常保持 79
        alpha = 1.0, -- 不透明度：0 完全透明，1 完全显示，例如 0.6 为 60%
        fadeIn = 0.25,  -- 渐显秒数：从爆发开始计算；0 为立即显示
        fadeOut = 0.25, -- 渐隐秒数：在爆发结束前完成；0 为立即隐藏
        -- 渐显/渐隐包含在爆发持续内；极短爆发时各自最多占剩余时间的一半。
        desaturated = true, -- true：先去色再染色；false：保留原图颜色参与染色
        -- 染色 RGB（0～1）：保留当前调好的颜色；HP 字色为 { 0.4, 1.0, 0.8 }。
        -- 去色后仍保留原图明暗；如需只看灰度，将颜色改为 { 1, 1, 1 }。
        color = { 0.1, 1.0, 0.8 },
    }
    local fire = { playing = false, failed = false, settings = FIRE_CONFIG }
    P5SFrame.firePreview = fire

    function fire:RefreshControl()
        if self.check then
            self.check:SetChecked(P5S_UI_DB and P5S_UI_DB.showtimeFireEnabled and true or false)
            _G[self.check:GetName() .. "Text"]:SetText(self.failed and "显示亚森火焰（本次加载不可用）" or "显示亚森火焰")
        end
    end

    function fire:Stop()
        self.playing = false
        if self.driver then
            self.driver:SetScript("OnUpdate", nil)
            self.driver:Hide()
        end
        if self.texture then self.texture:Hide() end
    end

    function fire:Fail()
        -- 本次加载发生渲染错误后不再重试，不刷屏、不停用其他模块。
        self.failed = true
        self:Stop()
        self:RefreshControl()
    end

    function fire:SetFrame(index)
        local column, row = index % 8, math.floor(index / 8)
        self.texture:SetTexCoord(column / 8, (column + 1) / 8, row / 16, (row + 1) / 16)
        self.frameIndex = index
    end

    function fire:ApplyLayout()
        local settings = self.settings
        self.texture:ClearAllPoints()
        self.texture:SetPoint("CENTER", P5SFrame, "CENTER", settings.x, settings.y)
        self.texture:SetSize(settings.width, settings.height)
    end

    function fire:Render()
        local now = GetTime()
        if now >= self.endsAt then self:Stop(); return end
        local elapsed = math.max(0, now - self.startedAt)
        local opacity = 1
        if self.fadeIn > 0 then opacity = math.min(opacity, elapsed / self.fadeIn) end
        if self.fadeOut > 0 then opacity = math.min(opacity, (self.endsAt - now) / self.fadeOut) end
        self.texture:SetAlpha(self.settings.alpha * opacity)
        local index = math.floor((elapsed % (self.settings.frames / self.settings.fps)) * self.settings.fps)
        index = math.min(self.settings.frames - 1, index)
        -- 卡顿直接跳到当前帧；每次更新至多裁切一次，不补跑历史帧。
        if index ~= self.frameIndex then self:SetFrame(index) end
    end

    function fire:Tick()
        if self.playing and not pcall(self.Render, self) then self:Fail() end
    end

    function fire:Start(endsAt)
        if not self.settings or self.failed then return end
        local ok = pcall(function()
            -- 参数写错时只停用火焰，避免无效帧数/速度进入逐帧回调。
            local settings = self.settings
            for _, key in ipairs({ "width", "height", "x", "y", "fps", "frames", "fadeIn", "fadeOut" }) do
                local value = settings[key]
                assert(type(value) == "number" and value == value and value > -math.huge and value < math.huge)
            end
            assert(settings.width > 0 and settings.height > 0 and settings.fps > 0)
            assert(settings.fadeIn >= 0 and settings.fadeOut >= 0)
            assert(settings.frames >= 1 and settings.frames <= 79 and settings.frames == math.floor(settings.frames))
            assert(type(settings.alpha) == "number" and settings.alpha >= 0 and settings.alpha <= 1)
            assert(type(settings.desaturated) == "boolean" and type(settings.color) == "table")
            for index = 1, 3 do
                local channel = settings.color[index]
                assert(type(channel) == "number" and channel >= 0 and channel <= 1)
            end
            local now = GetTime()
            assert(type(endsAt) == "number" and endsAt < math.huge and endsAt > now)
            if not self.texture then
                -- 同一主框体 BACKGROUND 的最低子层，低于黑底及所有 TGA。
                self.texture = P5SFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
                self.texture:Hide()
                local loaded = self.texture:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\亚森背景火焰.blp")
                if loaded == false then error("Fire texture unavailable") end
                self.texture:SetBlendMode("ADD")
            end
            if not self.driver then
                self.driver = CreateFrame("Frame", nil, P5SFrame)
                self.driver:Hide()
                -- 父框体隐藏时停止逐帧回调；重新出现时按真实经过时间恢复，不延长爆发。
                self.driver:SetScript("OnShow", function() self:Tick() end)
            end
            self:ApplyLayout()
            -- 原生纹理先去色、再乘 RGB 染色，保留 BLP 自带的透明区域与明暗层次。
            -- 去色和染色仅启动时应用；逐帧仅更新透明度与图集坐标。
            self.texture:SetDesaturated(settings.desaturated)
            self.texture:SetVertexColor(settings.color[1], settings.color[2], settings.color[3], 1)
            self.startedAt = now
            self.endsAt = endsAt
            self.fadeIn = math.min(settings.fadeIn, (endsAt - now) / 2)
            self.fadeOut = math.min(settings.fadeOut, (endsAt - now) / 2)
            self.playing = true
            self:SetFrame(0)
            self:Render()
            if not self.playing then return end
            self.texture:Show()
            self.driver:SetScript("OnUpdate", function() self:Tick() end)
            self.driver:Show()
        end)
        if not ok then self:Fail(); return end
    end

    function fire:CreateControl(section)
        self.check = CreateFrame("CheckButton", "P5S_ShowtimeFireEnabled", section, "UICheckButtonTemplate")
        self.check:SetPoint("TOPLEFT", section, "TOPLEFT", 18, -183)
        self:RefreshControl()
        self.check:SetScript("OnClick", function(control)
            if not P5S_UI_DB then return end
            P5S_UI_DB.showtimeFireEnabled = control:GetChecked() and true or false
            self:SyncToShowtime()
            self:RefreshControl()
        end)
        ApplyPanelTheme("StyleCheckBox", self.check)
    end
end

local bgTexture = P5SFrame:CreateTexture(nil, "BACKGROUND")
bgTexture:SetAllPoints(P5SFrame) 
bgTexture:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\肘可血条框体纯黑.tga")

local showtimeDimTexture = P5SFrame:CreateTexture(nil, "ARTWORK", nil, 0)
showtimeDimTexture:SetAllPoints(P5SFrame)
showtimeDimTexture:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\showtime槽.tga")
showtimeDimTexture:SetAlpha(0)

local showtimeTexture = P5SFrame:CreateTexture(nil, "ARTWORK", nil, 1)
showtimeTexture:SetAllPoints(P5SFrame)
showtimeTexture:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\showtime槽.tga")

-- Showtime 槽的径向裁切在 ADDON_LOADED 后初始化。
-- 这样即使 12.1 径向 API 在某个客户端环境中不可用，/p5s 也仍会先完成注册。
local SHOWTIME_PHASE_DISABLED = "DISABLED"
local SHOWTIME_PHASE_READY = "READY"
local SHOWTIME_PHASE_BURST = "BURST"
local SHOWTIME_PHASE_RECOVERY = "RECOVERY"
local SHOWTIME_PHASE_FAST_FINISH = "FAST_FINISH"
local SHOWTIME_PHASE_READY_FADE = "READY_FADE"

-- 12.1 径向接口的 Percent 仍以整圆 0～1 表示实际扫角；Start/EndOffset
-- 只调整边界，不能把逻辑 0～1 自动压缩为一段短弧。裁切圆心向左 55、
-- 向下 30 个基础 UI 单位后已经进入素材主体附近，完整 alpha 角域会环绕
-- 圆心展开；当前按视觉微调目标使用 149°～223°。START 放在标准坐标
-- 223°，真正交给 Texture / RadialProgress 动画的百分比统一乘以 74/360：
-- 爆发时边界从 149°逆时针退到 223°，恢复时再沿原路顺时针补回。
local SHOWTIME_RADIAL_START_OFFSET = 47 / 360 -- 绝对标准坐标 223°
local SHOWTIME_RADIAL_SWEEP_PERCENT = 74 / 360 -- 实际 74° 扫角占整圆的比例
local SHOWTIME_RADIAL_REVERSE = false
local SHOWTIME_RADIAL_FEATHER = 0 -- 短弧首轮验证先使用硬边，避免羽化掩盖起始变化
local SHOWTIME_DIM_ALPHA = 0.35
local SHOWTIME_EARLY_FINISH_SECONDS = 0.5
local SHOWTIME_READY_FADE_SECONDS = 0.4
local SHOWTIME_COOLDOWN_ARM_DELAY = 0.05
local SHOWTIME_PREVIEW_BURST_SECONDS = 3
local SHOWTIME_PREVIEW_COOLDOWN_SECONDS = 8

local showtimeState = {
    phase = SHOWTIME_PHASE_DISABLED,
    generation = 0,
    phaseStartedAt = 0,
    phaseDuration = 0,
    fromPercent = 1,
    toPercent = 1,
    burstDuration = 15,
    cooldownDuration = 120,
    cooldownReadyEarly = false,
    preview = false,
}

local showtimeRenderer = {
    initialized = false,
    available = false,
    failed = false,
    centerOffsetX = -55,
    centerOffsetY = -30,
}

local showtimeCooldownWatcher = {
    generation = 0,
    pending = false,
    armed = false,
    installing = false,
    finishedWhileInstalling = false,
    mode = nil,
    spellID = nil,
    cycleGeneration = nil,
    frame = nil,
}

local showtimeSpellNameToID = {}
local showtimeSpellBookCacheBuilt = false
local showtimePendingSpellBookCacheRebuild = false
local runtimeShowtimeSpellID = nil
local runtimeShowtimeSpellName = nil
local showtimeResolutionWarning = nil

local showtimeSpellInput
local showtimeBurstInput
local showtimeCooldownInput
local showtimeStatusText
local CommitShowtimeOptions
local RefreshShowtimeOptionControls
local EnterShowtimeReady
local EnterShowtimeDisabled
local StartShowtimeReadyFade
local StartShowtimeRecovery
local StartShowtimeFastFinish
local StartShowtimeCycle
local RestoreShowtimeCycle
local HandleShowtimeCooldownReady

-- 冷却补满后只运行 0.4 秒：把同一张完整暗色素材平滑恢复到正常亮度。
-- 这里不依赖径向接口，因此 12.1 径向能力失效时仍能保留渐显。
local showtimeReadyFadeDriver = CreateFrame("Frame", nil, P5SFrame)
showtimeReadyFadeDriver:Hide()
showtimeReadyFadeDriver:SetScript("OnUpdate", function(self)
    local generation = self._p5sGeneration
    if generation ~= showtimeState.generation or showtimeState.phase ~= SHOWTIME_PHASE_READY_FADE then
        self:Hide()
        self._p5sGeneration = nil
        return
    end

    local duration = showtimeState.phaseDuration
    local progress = 1
    if duration and duration > 0 then
        progress = (GetTime() - showtimeState.phaseStartedAt) / duration
        if progress < 0 then
            progress = 0
        elseif progress > 1 then
            progress = 1
        end
    end

    showtimeDimTexture:SetAlpha(SHOWTIME_DIM_ALPHA + ((1 - SHOWTIME_DIM_ALPHA) * progress))
    if progress >= 1 then
        self:Hide()
        self._p5sGeneration = nil
        EnterShowtimeReady(generation)
    end
end)

local borderTexture = P5SFrame:CreateTexture(nil, "OVERLAY")
borderTexture:SetAllPoints(P5SFrame)
borderTexture:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\肘可血条框体.tga")

P5SFrame:SetMovable(true)
P5SFrame:EnableMouse(true)
P5SFrame:RegisterForDrag("LeftButton")

P5SFrame:SetScript("OnDragStart", function(self)
    if not P5S_UI_DB.isLocked then self:StartMoving() end
end)

P5SFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    P5S_UI_DB.point = point
    P5S_UI_DB.relativePoint = relativePoint
    P5S_UI_DB.xOfs = xOfs
    P5S_UI_DB.yOfs = yOfs
end)

-- ==========================================
-- 3. 创建动态血条、护盾条、能量条以及各项文字
-- ==========================================
local hpBg = CreateFrame("Frame", "P5S_HPBg", P5SFrame)
hpBg:SetSize(HP_WIDTH, HP_HEIGHT)
hpBg:SetPoint("CENTER", P5SFrame, "CENTER", HP_X, HP_Y)
hpBg:SetFrameLevel(P5SFrame:GetFrameLevel() + 1)
local hpBgTex = hpBg:CreateTexture(nil, "BACKGROUND")
hpBgTex:SetAllPoints(hpBg)
hpBgTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\HP底色.tga")

local spBg = CreateFrame("Frame", "P5S_SPBg", P5SFrame)
spBg:SetSize(SP_WIDTH, SP_HEIGHT)
spBg:SetPoint("CENTER", P5SFrame, "CENTER", SP_X, SP_Y)
spBg:SetFrameLevel(P5SFrame:GetFrameLevel() + 1)
local spBgTex = spBg:CreateTexture(nil, "BACKGROUND")
spBgTex:SetAllPoints(spBg)
spBgTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\SP底色.tga")

local hpBar = CreateFrame("StatusBar", "P5S_HPBar", P5SFrame)
hpBar:SetSize(HP_WIDTH, HP_HEIGHT) 
hpBar:SetPoint("CENTER", P5SFrame, "CENTER", HP_X, HP_Y) 
hpBar:SetStatusBarTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\HP.tga")
hpBar:SetFrameLevel(P5SFrame:GetFrameLevel() + 2)

local shieldBar = CreateFrame("StatusBar", "P5S_ShieldBar", P5SFrame)
shieldBar:SetSize(SHIELD_WIDTH, SHIELD_HEIGHT) 
shieldBar:SetPoint("CENTER", P5SFrame, "CENTER", SHIELD_X, SHIELD_Y) 
shieldBar:SetStatusBarTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\Shield.tga")
shieldBar:SetFrameLevel(P5SFrame:GetFrameLevel() + 3)

local spBar = CreateFrame("StatusBar", "P5S_SPBar", P5SFrame)
spBar:SetSize(SP_WIDTH, SP_HEIGHT)
spBar:SetPoint("CENTER", P5SFrame, "CENTER", SP_X, SP_Y)
spBar:SetStatusBarTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\SP.tga")
spBar:SetFrameLevel(P5SFrame:GetFrameLevel() + 2)

-- 三条状态条共用原生平滑方式，每条各自保留初始化和失败回退状态。
for _, bar in ipairs({hpBar, shieldBar, spBar}) do
    local interpolation = Enum and Enum.StatusBarInterpolation
        and Enum.StatusBarInterpolation.ExponentialEaseOut
    local initialized = false

    function bar:UpdateSmoothValue(maximum, value, immediate)
        -- Secret 数值只传给原生控件；不在 Lua 中比较、求差或模拟回复。
        if initialized and not immediate and interpolation then
            local ok = pcall(self.SetMinMaxValues, self, 0, maximum, interpolation)
            if ok then
                ok = pcall(self.SetValue, self, value, interpolation)
            end
            if ok then return end

            -- 本次加载只尝试到首次失败，随后安静回退到原来的即时显示。
            interpolation = nil
        end

        self:SetMinMaxValues(0, maximum)
        self:SetValue(value)
        initialized = true
    end
end

do
    local resource = P5SFrame.thirdResource

    resource.frame = CreateFrame("Frame", "P5S_ThirdResourceFrame", P5SFrame)
    resource.frame:SetAllPoints(P5SFrame)
    resource.frame:SetFrameLevel(P5SFrame:GetFrameLevel() + 4)
    resource.frame:Hide()

    for index = 1, resource.maxSlots do
        local slot = CreateFrame("Frame", "P5S_ThirdResourceSlot" .. index, resource.frame)
        -- 尺寸、位置和旋转在 ApplyLayout 中统一按所选样式应用。

        local emptyTexture = slot:CreateTexture(nil, "ARTWORK")
        emptyTexture:SetAllPoints(slot)
        emptyTexture:SetTexture(resource.texture)
        if emptyTexture.SetDesaturated then
            emptyTexture:SetDesaturated(true)
        end
        emptyTexture:SetVertexColor(
            resource.emptyBrightness,
            resource.emptyBrightness,
            resource.emptyBrightness,
            1
        )

        local fill = CreateFrame("StatusBar", nil, slot)
        fill:SetAllPoints(slot)
        fill:SetFrameLevel(slot:GetFrameLevel() + 1)
        fill:SetStatusBarTexture(resource.texture)
        fill:SetOrientation("VERTICAL")
        fill:SetMinMaxValues(0, 1)
        fill:SetValue(0)
        fill:Hide()

        slot.emptyTexture = emptyTexture
        slot.fill = fill
        resource.slots[index] = slot
    end
end

local lvFrame = CreateFrame("Frame", "P5S_LvFrame", P5SFrame)
lvFrame:SetSize(50, 50)
lvFrame:SetPoint("CENTER", P5SFrame, "CENTER", LV_X, LV_Y)
lvFrame:SetFrameLevel(P5SFrame:GetFrameLevel() + 1)

local lvText = lvFrame:CreateFontString(nil, "OVERLAY")
lvText:SetFont("Interface\\AddOns\\P5S\\P5S_UI\\Media\\微软雅黑粗体.ttf", LV_SIZE, "OUTLINE")
lvText:SetPoint("CENTER", lvFrame, "CENTER", 0, 0)
lvText:SetTextColor(1, 1, 1) 

local textFrame = CreateFrame("Frame", "P5S_TextFrame", P5SFrame)
textFrame:SetSize(150, 60)
textFrame:SetPoint("CENTER", P5SFrame, "CENTER", TEXT_X, TEXT_Y)
textFrame:SetFrameLevel(P5SFrame:GetFrameLevel() + 1)

local hpValueText = textFrame:CreateFontString(nil, "OVERLAY")
hpValueText:SetFont("Interface\\AddOns\\P5S\\P5S_UI\\Media\\微软雅黑粗体.ttf", VALUE_SIZE, "OUTLINE")
hpValueText:SetPoint("BOTTOMLEFT", textFrame, "BOTTOMLEFT", 0, 0)
hpValueText:SetTextColor(0.4, 1.0, 0.8) 
hpValueText:SetShadowColor(0, 0, 0, 1) 
hpValueText:SetShadowOffset(SHADOW_X, SHADOW_Y) 

local hpLabel = textFrame:CreateFontString(nil, "OVERLAY")
hpLabel:SetFont("Interface\\AddOns\\P5S\\P5S_UI\\Media\\微软雅黑粗体.ttf", LABEL_SIZE, "OUTLINE")
hpLabel:SetPoint("BOTTOMLEFT", hpValueText, "TOPLEFT", -5, -1)
hpLabel:SetText("HP")
hpLabel:SetTextColor(0.4, 1.0, 0.8)
hpLabel:SetShadowColor(0, 0, 0, 1)
hpLabel:SetShadowOffset(SHADOW_X, SHADOW_Y)

local slashText = textFrame:CreateFontString(nil, "OVERLAY")
slashText:SetFont("Interface\\AddOns\\P5S\\P5S_UI\\Media\\微软雅黑粗体.ttf", SLASH_SIZE, "OUTLINE")
slashText:SetPoint("LEFT", hpValueText, "RIGHT", 4, 0)
slashText:SetText("/")
slashText:SetTextColor(0.6, 0.6, 0.6)
slashText:SetShadowColor(0, 0, 0, 1)
slashText:SetShadowOffset(SHADOW_X, SHADOW_Y)

local spValueText = textFrame:CreateFontString(nil, "OVERLAY")
spValueText:SetFont("Interface\\AddOns\\P5S\\P5S_UI\\Media\\微软雅黑粗体.ttf", VALUE_SIZE, "OUTLINE")
spValueText:SetPoint("LEFT", slashText, "RIGHT", 4, 0)
spValueText:SetTextColor(1.0, 0.4, 0.8) 
spValueText:SetShadowColor(0, 0, 0, 1)
spValueText:SetShadowOffset(SHADOW_X, SHADOW_Y)

local spLabel = textFrame:CreateFontString(nil, "OVERLAY")
spLabel:SetFont("Interface\\AddOns\\P5S\\P5S_UI\\Media\\微软雅黑粗体.ttf", LABEL_SIZE, "OUTLINE")
spLabel:SetPoint("BOTTOMLEFT", spValueText, "TOPLEFT", -5, -1)
spLabel:SetText("SP")
spLabel:SetTextColor(1.0, 0.4, 0.8)
spLabel:SetShadowColor(0, 0, 0, 1)
spLabel:SetShadowOffset(SHADOW_X, SHADOW_Y)

local atkFrame = CreateFrame("Frame", "P5S_AtkFrame", P5SFrame)
atkFrame:SetSize(ATK_WIDTH, ATK_HEIGHT)
atkFrame:SetPoint("CENTER", P5SFrame, "CENTER", ATK_X, ATK_Y)
atkFrame:SetFrameLevel(P5SFrame:GetFrameLevel() + 1)
local atkTex = atkFrame:CreateTexture(nil, "OVERLAY")
atkTex:SetAllPoints(atkFrame)
atkTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\攻小提升.tga")
atkFrame:Hide()

local defFrame = CreateFrame("Frame", "P5S_DefFrame", P5SFrame)
defFrame:SetSize(DEF_WIDTH, DEF_HEIGHT)
defFrame:SetPoint("CENTER", P5SFrame, "CENTER", DEF_X, DEF_Y)
defFrame:SetFrameLevel(P5SFrame:GetFrameLevel() + 1)
local defTex = defFrame:CreateTexture(nil, "OVERLAY")
defTex:SetAllPoints(defFrame)
defTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\防小提升.tga")
defFrame:Hide()

local spdFrame = CreateFrame("Frame", "P5S_SpdFrame", P5SFrame)
spdFrame:SetSize(SPD_WIDTH, SPD_HEIGHT)
spdFrame:SetPoint("CENTER", P5SFrame, "CENTER", SPD_X, SPD_Y)
spdFrame:SetFrameLevel(P5SFrame:GetFrameLevel() + 1)
local spdTex = spdFrame:CreateTexture(nil, "OVERLAY")
spdTex:SetAllPoints(spdFrame)
spdTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\速小提升.tga")
spdFrame:Hide()

local function ApplyRotation(frame, angle)
    if angle and angle ~= 0 then
        if not frame.rotGroup then
            frame.rotGroup = frame:CreateAnimationGroup()
            frame.rotAnim = frame.rotGroup:CreateAnimation("Rotation")
            frame.rotAnim:SetEndDelay(9999999) 
        end
        frame.rotGroup:Stop()
        frame.rotAnim:SetDegrees(angle)
        frame.rotAnim:SetDuration(0) 
        frame.rotGroup:Play()
    end
end

ApplyRotation(hpBg, HP_ANGLE)
ApplyRotation(spBg, SP_ANGLE)
ApplyRotation(hpBar, HP_ANGLE)
ApplyRotation(shieldBar, SHIELD_ANGLE) 
ApplyRotation(spBar, SP_ANGLE)
ApplyRotation(lvFrame, LV_ANGLE)
ApplyRotation(textFrame, TEXT_ANGLE) 
ApplyRotation(atkFrame, ATK_ANGLE)
ApplyRotation(defFrame, DEF_ANGLE)
ApplyRotation(spdFrame, SPD_ANGLE)

-- 静态布局接口：Buff 模块只共享配置，不读取原图标或受限控件的状态。
addon.BuffIndicatorLayout = {
    parent = P5SFrame, shiftX = SLOT_SHIFT_X,
    groups = {
        { key = "attack", text = "攻", width = ATK_WIDTH, height = ATK_HEIGHT, x = ATK_X, y = ATK_Y },
        { key = "defense", text = "防", width = DEF_WIDTH, height = DEF_HEIGHT, x = DEF_X, y = DEF_Y },
        { key = "speed", text = "速", width = SPD_WIDTH, height = SPD_HEIGHT, x = SPD_X, y = SPD_Y },
    },
}
do
    local resource = P5SFrame.thirdResource

    function resource:ApplyLayout(styleKey)
        local style = type(styleKey) == "string" and self.styles[styleKey]
        local layout = style and style.layout or self
        local rowRadians = math.rad(layout.rowAngle)
        local rowCos = math.cos(rowRadians)
        local rowSin = math.sin(rowRadians)
        local rowPivotX = layout.startX + (((self.maxSlots - 1) * layout.stepX) / 2)

        for index = 1, self.maxSlots do
            local slot = self.slots[index]
            local baseX = layout.startX + ((index - 1) * layout.stepX)
            local baseY = layout.yOffsets[index] or 0
            local deltaX = baseX - rowPivotX
            local rotatedX = rowPivotX + (deltaX * rowCos) - (baseY * rowSin) + layout.offsetX
            local rotatedY = layout.centerY + (deltaX * rowSin) + (baseY * rowCos) + layout.offsetY

            slot:SetSize(layout.slotWidth * layout.scale, layout.slotHeight * layout.scale)
            slot:ClearAllPoints()
            slot:SetPoint("CENTER", self.frame, "CENTER", rotatedX, rotatedY)

            local angle = layout.angles[index] or 0
            if angle == 0 then
                -- 切换到不旋转的样式时，清除上一套样式残留的旋转动画。
                if slot.rotGroup then slot.rotGroup:Stop() end
            else
                ApplyRotation(slot, angle)
            end
        end
    end

    resource:ApplyLayout("A")
end

-- ==========================================
-- 4. 核心逻辑：战斗状态图标与 Showtime 技能时间轴
-- ==========================================

local function ClampShowtimePercent(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function TrimShowtimeText(text)
    text = tostring(text or "")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetValidatedShowtimeSeconds(value, defaultValue)
    local seconds = tonumber(value)
    if not seconds or seconds ~= seconds then
        seconds = defaultValue
    end
    if seconds < 0.1 then seconds = 0.1 end
    if seconds > 7200 then seconds = 7200 end
    return seconds
end

local function FormatShowtimeSeconds(value)
    local text = string.format("%.2f", tonumber(value) or 0)
    return text:gsub("0+$", ""):gsub("%.$", "")
end

local function GetShowtimeSpellName(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return nil end

    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, math.floor(spellID))
        if ok and type(info) == "table" and type(info.name) == "string" then
            return info.name
        end
    end

    if type(GetSpellInfo) == "function" then
        local ok, spellName = pcall(GetSpellInfo, math.floor(spellID))
        if ok and type(spellName) == "string" then
            return spellName
        end
    end
    return nil
end

local function AddShowtimeSpellNameToCache(cache, spellID, spellName)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return end

    spellName = TrimShowtimeText(spellName or GetShowtimeSpellName(spellID) or "")
    if spellName ~= "" and cache[spellName] == nil then
        cache[spellName] = math.floor(spellID)
    end
end

local function RebuildShowtimeSpellBookNameCache()
    if InCombatLockdown and InCombatLockdown() then
        showtimePendingSpellBookCacheRebuild = true
        return false
    end

    local cache = {}

    if C_SpellBook
        and type(C_SpellBook.GetNumSpellBookSkillLines) == "function"
        and type(C_SpellBook.GetSpellBookSkillLineInfo) == "function"
        and type(C_SpellBook.GetSpellBookItemInfo) == "function"
    then
        local spellBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or "spell"
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
                        local okItem, itemInfo = pcall(C_SpellBook.GetSpellBookItemInfo, slot, spellBank)
                        if okItem and type(itemInfo) == "table" then
                            local spellID = itemInfo.spellID or itemInfo.actionID or itemInfo.spellIDOfOverriddenSpell
                            AddShowtimeSpellNameToCache(cache, spellID, itemInfo.name)
                        end
                    end
                end
            end
        end
    end

    if type(GetNumSpellTabs) == "function"
        and type(GetSpellTabInfo) == "function"
        and type(GetSpellBookItemInfo) == "function"
    then
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
                            AddShowtimeSpellNameToCache(cache, spellID, spellName)
                        end
                    end
                end
            end
        end
    end

    showtimeSpellNameToID = cache
    showtimeSpellBookCacheBuilt = true
    showtimePendingSpellBookCacheRebuild = false
    return true
end

local function ResolveShowtimeSpellToken(token)
    token = TrimShowtimeText(token)
    if token == "" then return nil, nil end

    local linkedSpellID = token:match("spell:(%d+)")
    if linkedSpellID then
        local spellID = tonumber(linkedSpellID)
        local spellName = GetShowtimeSpellName(spellID)
        if spellName then return spellID, spellName end
        return nil, nil
    end

    local numericID = tonumber(token)
    if numericID and numericID > 0 then
        numericID = math.floor(numericID)
        local spellName = GetShowtimeSpellName(numericID)
        if spellName then return numericID, spellName end
        return nil, nil
    end

    local cachedSpellID = showtimeSpellNameToID[token]
    if cachedSpellID then return cachedSpellID, token end

    if InCombatLockdown and InCombatLockdown() then
        return nil, nil
    end

    if not showtimeSpellBookCacheBuilt then
        RebuildShowtimeSpellBookNameCache()
    end
    cachedSpellID = showtimeSpellNameToID[token]
    if cachedSpellID then return cachedSpellID, token end

    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, token)
        if ok and type(info) == "table" and tonumber(info.spellID) then
            return math.floor(tonumber(info.spellID)), info.name
        end
    end

    if type(GetSpellInfo) == "function" then
        local ok, spellName, _, _, _, _, _, spellID = pcall(GetSpellInfo, token)
        if ok and tonumber(spellID) then
            return math.floor(tonumber(spellID)), spellName
        end
    end
    return nil, nil
end

local function RefreshShowtimeStatusText()
    if not showtimeStatusText then return end

    local phaseLabels = {
        [SHOWTIME_PHASE_DISABLED] = "未启用",
        [SHOWTIME_PHASE_READY] = "已就绪",
        [SHOWTIME_PHASE_BURST] = "爆发裁切中",
        [SHOWTIME_PHASE_RECOVERY] = "冷却恢复中",
        [SHOWTIME_PHASE_FAST_FINISH] = "提前转好",
        [SHOWTIME_PHASE_READY_FADE] = "冷却完成渐显中",
    }

    if showtimeResolutionWarning then
        showtimeStatusText:SetText(showtimeResolutionWarning)
        showtimeStatusText:SetTextColor(1, 0.76, 0.25)
        return
    end

    local phaseText = phaseLabels[showtimeState.phase] or "待命"
    if showtimeState.preview then
        showtimeStatusText:SetText("快速预览  ·  " .. phaseText)
        showtimeStatusText:SetTextColor(1, 0.55, 0.58)
        return
    end
    if runtimeShowtimeSpellID then
        local spellName = runtimeShowtimeSpellName or "技能"
        showtimeStatusText:SetText(string.format("已绑定：%s（%d）  ·  %s", spellName, runtimeShowtimeSpellID, phaseText))
        showtimeStatusText:SetTextColor(0.82, 0.86, 0.95)
    else
        showtimeStatusText:SetText("尚未绑定技能  ·  可输入名称、Spell ID，或 Shift+点击技能")
        showtimeStatusText:SetTextColor(0.72, 0.75, 0.82)
    end
end

local function ResolveSavedShowtimeSpell()
    if not P5S_UI_DB then return false end

    local inputText = TrimShowtimeText(P5S_UI_DB.showtimeSpellInput)
    if inputText == "" then
        runtimeShowtimeSpellID = nil
        runtimeShowtimeSpellName = nil
        P5S_UI_DB.showtimeSpellID = nil
        P5S_UI_DB.showtimeEnabled = false
        showtimeResolutionWarning = nil
        RefreshShowtimeStatusText()
        return false
    end

    local spellID, spellName = ResolveShowtimeSpellToken(inputText)
    if spellID then
        runtimeShowtimeSpellID = spellID
        runtimeShowtimeSpellName = spellName or GetShowtimeSpellName(spellID)
        P5S_UI_DB.showtimeSpellID = spellID
        P5S_UI_DB.showtimeEnabled = true
        showtimeResolutionWarning = nil
        RefreshShowtimeStatusText()
        return true
    end

    local savedSpellID = tonumber(P5S_UI_DB.showtimeSpellID)
    if savedSpellID and savedSpellID > 0 then
        runtimeShowtimeSpellID = math.floor(savedSpellID)
        runtimeShowtimeSpellName = GetShowtimeSpellName(runtimeShowtimeSpellID)
        showtimeResolutionWarning = "当前名称暂时无法解析，继续使用上次有效的 Spell ID。"
    else
        runtimeShowtimeSpellID = nil
        runtimeShowtimeSpellName = nil
        showtimeResolutionWarning = "技能无法识别；建议改用 Spell ID。"
    end
    P5S_UI_DB.showtimeEnabled = runtimeShowtimeSpellID ~= nil
    RefreshShowtimeStatusText()
    return runtimeShowtimeSpellID ~= nil
end

local function IsShowtimeSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, isSecret = pcall(issecretvalue, value)
    if not ok or type(isSecret) ~= "boolean" then return true end
    return isSecret
end

local function GetShowtimeNonSecretBoolean(value)
    if IsShowtimeSecretValue(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function GetShowtimeChargeRecoveryState(spellID)
    if not C_Spell or type(C_Spell.GetSpellCharges) ~= "function" then
        return nil, nil
    end

    local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, spellID)
    if not ok then return nil, nil end
    if type(chargeInfo) == "nil" then return false, nil end
    if IsShowtimeSecretValue(chargeInfo) or type(chargeInfo) ~= "table" then return nil, nil end

    local isActive = GetShowtimeNonSecretBoolean(chargeInfo.isActive)
    if isActive == nil then return nil, nil end
    return true, isActive
end

local function GetShowtimeCooldownEventState(spellID, includeGlobalCooldownState)
    if not C_Spell or type(C_Spell.GetSpellCooldown) ~= "function" then
        return nil, nil, nil
    end

    local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or IsShowtimeSecretValue(cooldownInfo) or type(cooldownInfo) ~= "table" then
        return nil, nil, nil
    end

    local isEnabled = GetShowtimeNonSecretBoolean(cooldownInfo.isEnabled)
    local isActive = GetShowtimeNonSecretBoolean(cooldownInfo.isActive)
    if isEnabled == nil or isActive == nil then return nil, nil, nil end

    local isOnGCD
    if includeGlobalCooldownState and type(cooldownInfo.isOnGCD) ~= "nil" then
        isOnGCD = GetShowtimeNonSecretBoolean(cooldownInfo.isOnGCD)
        if isOnGCD == nil then return nil, nil, nil end
    end
    return isEnabled, isActive, isOnGCD
end

local function IsShowtimeCooldownDefinitelyReady(spellID)
    -- isOnGCD 只有在 SPELL_UPDATE_COOLDOWN 事件期间可信；普通回调只使用另外两个安全布尔值。
    local isEnabled, isActive = GetShowtimeCooldownEventState(spellID, false)
    return isEnabled == true and isActive == false
end

local function IsOrdinaryShowtimeSpellDefinitelyReady(spellID)
    local isChargeSpell = GetShowtimeChargeRecoveryState(spellID)
    return isChargeSpell == false and IsShowtimeCooldownDefinitelyReady(spellID)
end

local function GetShowtimeCooldownDurationObject(spellID)
    local method = C_Spell and C_Spell.GetSpellCooldownDuration
    if type(method) ~= "function" then return nil end

    local ok, duration = pcall(method, spellID, true)
    if not ok then return nil end
    return duration
end

local function ClearShowtimeCooldownWatcher()
    local watcher = showtimeCooldownWatcher
    watcher.pending = false
    watcher.armed = false
    watcher.installing = false
    watcher.finishedWhileInstalling = false
    watcher.mode = nil
    watcher.spellID = nil
    watcher.cycleGeneration = nil
    watcher.generation = watcher.generation + 1
    if watcher.frame and type(watcher.frame.Clear) == "function" then
        pcall(watcher.frame.Clear, watcher.frame)
    end
end

local function EnsureShowtimeCooldownWatcherFrame()
    local watcher = showtimeCooldownWatcher
    if watcher.frame == false then return nil end
    if watcher.frame then return watcher.frame end

    local okFrame, cooldownFrame = pcall(CreateFrame, "Cooldown", nil, UIParent)
    if not okFrame or not cooldownFrame then
        watcher.frame = false
        return nil
    end

    local okSetup = pcall(function()
        cooldownFrame:SetSize(1, 1)
        cooldownFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        cooldownFrame:SetAlpha(0)
        cooldownFrame:SetHideCountdownNumbers(true)
        cooldownFrame:SetDrawSwipe(false)
        cooldownFrame:SetDrawEdge(false)
        cooldownFrame:SetDrawBling(false)
        cooldownFrame:Show()
    end)
    if not okSetup then
        watcher.frame = false
        return nil
    end

    watcher.frame = cooldownFrame
    cooldownFrame:SetScript("OnCooldownDone", function()
        if not watcher.armed then return end
        if watcher.installing then
            watcher.finishedWhileInstalling = true
            return
        end
        if watcher.cycleGeneration ~= showtimeState.generation then
            ClearShowtimeCooldownWatcher()
            return
        end
        -- DurationObject 结束后再用非数值布尔状态确认；冷却被延长或 hold 时不误判。
        if IsShowtimeCooldownDefinitelyReady(watcher.spellID) then
            HandleShowtimeCooldownReady()
        end
    end)
    return cooldownFrame
end

local function SetShowtimeWatcherDuration()
    local watcher = showtimeCooldownWatcher
    local cooldownFrame = watcher.frame
    local setDurationMethod = cooldownFrame and cooldownFrame.SetCooldownFromDurationObject
    if type(setDurationMethod) ~= "function" then return false end

    local duration = GetShowtimeCooldownDurationObject(watcher.spellID)
    if type(duration) == "nil" then return false, false end

    watcher.installing = true
    watcher.finishedWhileInstalling = false
    local ok = pcall(setDurationMethod, cooldownFrame, duration, true)
    watcher.installing = false
    return ok and not watcher.finishedWhileInstalling
end

local function ArmShowtimeCooldownWatcher(spellID, cycleGeneration)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 or not EnsureShowtimeCooldownWatcherFrame() then return end

    ClearShowtimeCooldownWatcher()
    local watcher = showtimeCooldownWatcher
    watcher.pending = true
    watcher.spellID = math.floor(spellID)
    watcher.cycleGeneration = cycleGeneration
    local watcherGeneration = watcher.generation

    local function ArmAfterCooldownDataUpdate()
        if watcher.generation ~= watcherGeneration or not watcher.pending then return end
        if watcher.cycleGeneration ~= showtimeState.generation then
            ClearShowtimeCooldownWatcher()
            return
        end

        local isChargeSpell = GetShowtimeChargeRecoveryState(watcher.spellID)
        if isChargeSpell == nil then
            ClearShowtimeCooldownWatcher()
            return
        end

        -- 不读取充能层数时无法把“当前施放”可靠对应到某一层恢复。
        -- 首版充能技能只运行手填时间轴，不启用提前完成检查。
        if isChargeSpell then
            ClearShowtimeCooldownWatcher()
            return
        end

        watcher.mode = "cooldown"
        watcher.pending = false
        watcher.armed = true
        local installed = SetShowtimeWatcherDuration()
        if not installed then
            -- 与语音模块一致：安装期间同步完成不视为真实冷却结束，避免数据尚未刷新时误报。
            ClearShowtimeCooldownWatcher()
        end
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(SHOWTIME_COOLDOWN_ARM_DELAY, ArmAfterCooldownDataUpdate)
    else
        ArmAfterCooldownDataUpdate()
    end
end

local function RefreshReducedShowtimeCooldownWatcher()
    local watcher = showtimeCooldownWatcher
    if not watcher.armed or watcher.cycleGeneration ~= showtimeState.generation then return end

    local isEnabled, isActive, isOnGCD = GetShowtimeCooldownEventState(watcher.spellID, true)
    if isEnabled == true and (isActive == false or isOnGCD == true) then
        HandleShowtimeCooldownReady()
    end
end

local function StopShowtimeRadialAnimations()
    local groups = {
        showtimeRenderer.burstGroup,
        showtimeRenderer.recoveryGroup,
        showtimeRenderer.fastFinishGroup,
    }
    for _, group in ipairs(groups) do
        if group and type(group.Stop) == "function" then
            pcall(group.Stop, group)
        end
    end
end

local function StopShowtimeAnimations()
    StopShowtimeRadialAnimations()
    showtimeReadyFadeDriver:Hide()
    showtimeReadyFadeDriver._p5sGeneration = nil
end

local function DisableShowtimeRenderer(errorMessage)
    showtimeRenderer.available = false
    -- 径向能力失效只停止径向动画；若恰逢冷却完成渐显，静态层仍可继续。
    StopShowtimeRadialAnimations()
    if type(showtimeTexture.ClearRadialProgressBar) == "function" then
        pcall(showtimeTexture.ClearRadialProgressBar, showtimeTexture)
    end
    if showtimeState.phase == SHOWTIME_PHASE_READY or showtimeState.phase == SHOWTIME_PHASE_DISABLED then
        showtimeDimTexture:SetAlpha(1)
        showtimeTexture:SetAlpha(0)
    elseif showtimeState.phase == SHOWTIME_PHASE_RECOVERY
        or showtimeState.phase == SHOWTIME_PHASE_FAST_FINISH
        or showtimeState.phase == SHOWTIME_PHASE_READY_FADE
    then
        showtimeDimTexture:SetAlpha(SHOWTIME_DIM_ALPHA)
        showtimeTexture:SetAlpha(0)
    else
        showtimeDimTexture:SetAlpha(0)
        showtimeTexture:SetAlpha(1)
    end

    if not showtimeRenderer.failed then
        showtimeRenderer.failed = true
        local detail = errorMessage and ("（" .. tostring(errorMessage) .. "）") or ""
        print("|cffffcc00[P5S UI]|r Showtime 径向动画不可用，已降级为静态显示" .. detail .. "。")
    end
end

local function SetShowtimeVisual(percent, alpha)
    local visualAlpha = type(alpha) == "number" and alpha or 1
    local dimmed = visualAlpha < 1
    if showtimeState.phase == SHOWTIME_PHASE_READY or showtimeState.phase == SHOWTIME_PHASE_DISABLED then
        -- 就绪/停用时直接显示未裁切的完整底图，避免径向参数或初始化时序让原图消失。
        showtimeDimTexture:SetAlpha(1)
        showtimeTexture:SetAlpha(0)
        return
    end
    if showtimeState.phase == SHOWTIME_PHASE_READY_FADE then
        -- 渐显阶段改用未裁切的完整静态素材，始终保持单层显示。
        showtimeDimTexture:SetAlpha(visualAlpha)
        showtimeTexture:SetAlpha(0)
        return
    end
    if showtimeRenderer.available then
        local ok, errorMessage = pcall(
            showtimeTexture.SetRadialProgressBarPercent,
            showtimeTexture,
            ClampShowtimePercent(percent) * SHOWTIME_RADIAL_SWEEP_PERCENT
        )
        if not ok then
            DisableShowtimeRenderer(errorMessage)
        end
    end
    if showtimeRenderer.available then
        -- 正常冷却恢复只显示径向纹理本身，并直接降低它的亮度；
        -- 不再在下方铺一张完整暗图。
        showtimeDimTexture:SetAlpha(0)
        showtimeTexture:SetAlpha(visualAlpha)
    elseif dimmed then
        -- 径向接口不可用时无法播放恢复动画，保留单张完整暗图静态降级。
        showtimeDimTexture:SetAlpha(visualAlpha)
        showtimeTexture:SetAlpha(0)
    else
        showtimeDimTexture:SetAlpha(0)
        showtimeTexture:SetAlpha(1)
    end
end

local function InitializeShowtimeRenderer()
    if showtimeRenderer.initialized then return showtimeRenderer.available end
    showtimeRenderer.initialized = true

    local requiredMethods = {
        "SetRadialProgressBarPercent",
        "SetRadialProgressBarStartOffset",
        "SetRadialProgressBarEndOffset",
        "SetRadialProgressBarReverse",
        "SetRadialProgressBarFeather",
    }
    for _, methodName in ipairs(requiredMethods) do
        if type(showtimeTexture[methodName]) ~= "function" then
            DisableShowtimeRenderer("缺少 " .. methodName)
            return false
        end
    end

    local ok, errorMessage = pcall(function()
        -- 原生径向裁切始终以 Texture 自身中心为圆心。把承载径向效果的
        -- Texture 向左、向下移动，再用纹理坐标等量反向补偿：素材仍对齐
        -- 原框体，但裁切圆心会相对素材左移、下移。负的框体 X/Y 偏移
        -- 分别代表向左/向下；U 与 X 同向，V 与框体 Y 反向。
        showtimeTexture:ClearAllPoints()
        showtimeTexture:SetSize(BASE_SIZE, BASE_SIZE)
        showtimeTexture:SetPoint(
            "CENTER",
            P5SFrame,
            "CENTER",
            showtimeRenderer.centerOffsetX,
            showtimeRenderer.centerOffsetY
        )
        showtimeTexture:SetTexCoord(
            showtimeRenderer.centerOffsetX / BASE_SIZE,
            -showtimeRenderer.centerOffsetY / BASE_SIZE,
            showtimeRenderer.centerOffsetX / BASE_SIZE,
            1 - showtimeRenderer.centerOffsetY / BASE_SIZE,
            1 + showtimeRenderer.centerOffsetX / BASE_SIZE,
            -showtimeRenderer.centerOffsetY / BASE_SIZE,
            1 + showtimeRenderer.centerOffsetX / BASE_SIZE,
            1 - showtimeRenderer.centerOffsetY / BASE_SIZE
        )

        showtimeTexture:SetRadialProgressBarStartOffset(SHOWTIME_RADIAL_START_OFFSET)
        showtimeTexture:SetRadialProgressBarEndOffset(0)
        showtimeTexture:SetRadialProgressBarReverse(SHOWTIME_RADIAL_REVERSE)
        showtimeTexture:SetRadialProgressBarFeather(SHOWTIME_RADIAL_FEATHER)
        showtimeTexture:SetRadialProgressBarPercent(SHOWTIME_RADIAL_SWEEP_PERCENT)

        showtimeRenderer.burstGroup = showtimeTexture:CreateAnimationGroup()
        showtimeRenderer.burstAnimation = showtimeRenderer.burstGroup:CreateAnimation("RadialProgress")
        showtimeRenderer.burstAnimation:SetSmoothing("NONE")

        showtimeRenderer.recoveryGroup = showtimeTexture:CreateAnimationGroup()
        showtimeRenderer.recoveryAnimation = showtimeRenderer.recoveryGroup:CreateAnimation("RadialProgress")
        showtimeRenderer.recoveryAnimation:SetSmoothing("NONE")

        showtimeRenderer.fastFinishGroup = showtimeTexture:CreateAnimationGroup()
        showtimeRenderer.fastFinishAnimation = showtimeRenderer.fastFinishGroup:CreateAnimation("RadialProgress")
        showtimeRenderer.fastFinishAnimation:SetSmoothing("NONE")

        showtimeRenderer.burstGroup:SetScript("OnFinished", function(group)
            local generation = group._p5sGeneration
            if generation ~= showtimeState.generation or showtimeState.phase ~= SHOWTIME_PHASE_BURST then return end
            SetShowtimeVisual(0, 1)
            StartShowtimeRecovery(generation)
        end)

        showtimeRenderer.recoveryGroup:SetScript("OnFinished", function(group)
            local generation = group._p5sGeneration
            if generation ~= showtimeState.generation or showtimeState.phase ~= SHOWTIME_PHASE_RECOVERY then return end
            StartShowtimeReadyFade(generation)
        end)

        showtimeRenderer.fastFinishGroup:SetScript("OnFinished", function(group)
            local generation = group._p5sGeneration
            if generation ~= showtimeState.generation or showtimeState.phase ~= SHOWTIME_PHASE_FAST_FINISH then return end
            StartShowtimeReadyFade(generation)
        end)
    end)

    if not ok then
        -- 圆心补偿本身失败时恢复原始布局，保证静态降级图仍与底图对齐。
        showtimeTexture:ClearAllPoints()
        showtimeTexture:SetAllPoints(P5SFrame)
        showtimeTexture:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
        DisableShowtimeRenderer(errorMessage)
        return false
    end

    showtimeRenderer.available = true
    showtimeTexture:SetAlpha(1)
    return true
end

local function PlayShowtimeRadialAnimation(group, animation, fromPercent, toPercent, duration, generation)
    if not showtimeRenderer.available or not group or not animation then return false end

    local ok, errorMessage = pcall(function()
        group:Stop()
        group._p5sGeneration = generation
        local radialFromPercent = ClampShowtimePercent(fromPercent) * SHOWTIME_RADIAL_SWEEP_PERCENT
        local radialToPercent = ClampShowtimePercent(toPercent) * SHOWTIME_RADIAL_SWEEP_PERCENT
        showtimeTexture:SetRadialProgressBarPercent(radialFromPercent)
        animation:SetFromPercent(radialFromPercent)
        animation:SetToPercent(radialToPercent)
        animation:SetDuration(duration)
        group:Play()
    end)
    if not ok then
        DisableShowtimeRenderer(errorMessage)
        return false
    end
    return true
end

local function PlayShowtimeFastFinishAnimation(fromPercent, duration, generation)
    local group = showtimeRenderer.fastFinishGroup
    local animation = showtimeRenderer.fastFinishAnimation
    if not showtimeRenderer.available or not group or not animation then return false end

    local ok, errorMessage = pcall(function()
        group:Stop()
        group._p5sGeneration = generation
        local radialFromPercent = ClampShowtimePercent(fromPercent) * SHOWTIME_RADIAL_SWEEP_PERCENT
        showtimeTexture:SetRadialProgressBarPercent(radialFromPercent)
        animation:SetFromPercent(radialFromPercent)
        animation:SetToPercent(SHOWTIME_RADIAL_SWEEP_PERCENT)
        animation:SetDuration(duration)
        group:Play()
    end)
    if not ok then
        DisableShowtimeRenderer(errorMessage)
        return false
    end
    return true
end

local function ScheduleShowtimePhaseEnd(duration, generation, phase, callback)
    local function FinishPhase()
        if showtimeState.generation ~= generation or showtimeState.phase ~= phase then return end
        callback(generation)
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(duration, FinishPhase)
    else
        FinishPhase()
    end
end

local function GetCurrentShowtimePercent()
    local duration = showtimeState.phaseDuration
    if not duration or duration <= 0 then return ClampShowtimePercent(showtimeState.toPercent or 1) end

    local elapsed = GetTime() - showtimeState.phaseStartedAt
    local progress = ClampShowtimePercent(elapsed / duration)
    local fromPercent = showtimeState.fromPercent or 1
    local toPercent = showtimeState.toPercent or 1
    return ClampShowtimePercent(fromPercent + ((toPercent - fromPercent) * progress))
end

local function IsRealShowtimeCycleActive()
    return not showtimeState.preview
        and (showtimeState.phase == SHOWTIME_PHASE_BURST
            or showtimeState.phase == SHOWTIME_PHASE_RECOVERY
            or showtimeState.phase == SHOWTIME_PHASE_FAST_FINISH
            or showtimeState.phase == SHOWTIME_PHASE_READY_FADE)
end

function P5SFrame.firePreview:SyncToShowtime()
    local endsAt = showtimeState.phaseStartedAt + showtimeState.phaseDuration
    if P5S_UI_DB and P5S_UI_DB.showtimeFireEnabled
        and showtimeState.phase == SHOWTIME_PHASE_BURST and endsAt > GetTime()
    then
        -- 施放、重载恢复或中途勾选均共用原爆发终点，不重新计完整持续时间。
        self:Start(endsAt)
    else
        self:Stop()
    end
end

EnterShowtimeReady = function(expectedGeneration)
    if expectedGeneration and expectedGeneration ~= showtimeState.generation then return end

    P5SFrame.firePreview:Stop()
    showtimeState.generation = showtimeState.generation + 1
    StopShowtimeAnimations()
    ClearShowtimeCooldownWatcher()
    if P5S_UI_DB and P5S_UI_DB.showtimeEnabled and runtimeShowtimeSpellID then
        showtimeState.phase = SHOWTIME_PHASE_READY
    else
        showtimeState.phase = SHOWTIME_PHASE_DISABLED
    end
    showtimeState.phaseStartedAt = 0
    showtimeState.phaseDuration = 0
    showtimeState.fromPercent = 1
    showtimeState.toPercent = 1
    showtimeState.cooldownReadyEarly = false
    showtimeState.preview = false
    SetShowtimeVisual(1, 1)
    if P5S_UI_DB then P5S_UI_DB.showtimeLastTriggerServerTime = nil end
    RefreshShowtimeStatusText()
end

EnterShowtimeDisabled = function()
    P5SFrame.firePreview:Stop()
    showtimeState.generation = showtimeState.generation + 1
    StopShowtimeAnimations()
    ClearShowtimeCooldownWatcher()
    showtimeState.phase = SHOWTIME_PHASE_DISABLED
    showtimeState.phaseStartedAt = 0
    showtimeState.phaseDuration = 0
    showtimeState.fromPercent = 1
    showtimeState.toPercent = 1
    showtimeState.cooldownReadyEarly = false
    showtimeState.preview = false
    SetShowtimeVisual(1, 1)
    if P5S_UI_DB then P5S_UI_DB.showtimeLastTriggerServerTime = nil end
    RefreshShowtimeStatusText()
end

StartShowtimeReadyFade = function(expectedGeneration)
    if expectedGeneration and expectedGeneration ~= showtimeState.generation then return end
    if showtimeState.phase ~= SHOWTIME_PHASE_RECOVERY
        and showtimeState.phase ~= SHOWTIME_PHASE_FAST_FINISH
    then
        return
    end

    showtimeState.generation = showtimeState.generation + 1
    local generation = showtimeState.generation
    StopShowtimeAnimations()
    ClearShowtimeCooldownWatcher()
    showtimeState.phase = SHOWTIME_PHASE_READY_FADE
    showtimeState.phaseStartedAt = GetTime()
    showtimeState.phaseDuration = SHOWTIME_READY_FADE_SECONDS
    showtimeState.fromPercent = 1
    showtimeState.toPercent = 1
    showtimeState.cooldownReadyEarly = false

    -- 恢复终点的暗色径向素材已经补满；切到同一张完整静态素材后，
    -- 只让这一层从暗色渐显到正常亮度，避免重新出现垫底层。
    SetShowtimeVisual(1, SHOWTIME_DIM_ALPHA)
    if P5S_UI_DB then P5S_UI_DB.showtimeLastTriggerServerTime = nil end
    showtimeReadyFadeDriver._p5sGeneration = generation
    showtimeReadyFadeDriver:Show()
    RefreshShowtimeStatusText()
end

StartShowtimeFastFinish = function(expectedGeneration)
    if expectedGeneration and expectedGeneration ~= showtimeState.generation then return end

    if showtimeState.phase == SHOWTIME_PHASE_BURST then
        showtimeState.cooldownReadyEarly = true
        ClearShowtimeCooldownWatcher()
        RefreshShowtimeStatusText()
        return
    end
    if showtimeState.phase ~= SHOWTIME_PHASE_RECOVERY then return end

    local elapsed = math.max(0, GetTime() - showtimeState.phaseStartedAt)
    local remainingManualDuration = math.max(0, showtimeState.phaseDuration - elapsed)
    local currentPercent = GetCurrentShowtimePercent()
    if remainingManualDuration <= 0 or currentPercent >= 1 then
        StartShowtimeReadyFade(showtimeState.generation)
        return
    end

    local finishDuration = math.min(SHOWTIME_EARLY_FINISH_SECONDS, remainingManualDuration)
    showtimeState.generation = showtimeState.generation + 1
    local generation = showtimeState.generation
    StopShowtimeAnimations()
    ClearShowtimeCooldownWatcher()
    showtimeState.phase = SHOWTIME_PHASE_FAST_FINISH
    showtimeState.phaseStartedAt = GetTime()
    showtimeState.phaseDuration = finishDuration
    showtimeState.fromPercent = currentPercent
    showtimeState.toPercent = 1
    SetShowtimeVisual(currentPercent, SHOWTIME_DIM_ALPHA)
    RefreshShowtimeStatusText()

    if not PlayShowtimeFastFinishAnimation(currentPercent, finishDuration, generation) then
        ScheduleShowtimePhaseEnd(finishDuration, generation, SHOWTIME_PHASE_FAST_FINISH, StartShowtimeReadyFade)
    end
end

StartShowtimeRecovery = function(expectedGeneration)
    if expectedGeneration ~= showtimeState.generation or showtimeState.phase ~= SHOWTIME_PHASE_BURST then return end

    P5SFrame.firePreview:Stop()
    local recoveryDuration = math.max(0, showtimeState.cooldownDuration - showtimeState.burstDuration)
    if not showtimeState.preview
        and runtimeShowtimeSpellID
        and IsOrdinaryShowtimeSpellDefinitelyReady(runtimeShowtimeSpellID)
    then
        showtimeState.cooldownReadyEarly = true
        ClearShowtimeCooldownWatcher()
    end
    showtimeState.phase = SHOWTIME_PHASE_RECOVERY
    showtimeState.phaseStartedAt = GetTime()
    showtimeState.phaseDuration = recoveryDuration
    showtimeState.fromPercent = 0
    showtimeState.toPercent = 1
    SetShowtimeVisual(0, SHOWTIME_DIM_ALPHA)

    if recoveryDuration <= 0 then
        StartShowtimeReadyFade(expectedGeneration)
        return
    end
    if showtimeState.cooldownReadyEarly then
        showtimeState.phaseDuration = SHOWTIME_EARLY_FINISH_SECONDS
        StartShowtimeFastFinish(expectedGeneration)
        return
    end

    RefreshShowtimeStatusText()
    if not PlayShowtimeRadialAnimation(
        showtimeRenderer.recoveryGroup,
        showtimeRenderer.recoveryAnimation,
        0,
        1,
        recoveryDuration,
        expectedGeneration
    ) then
        ScheduleShowtimePhaseEnd(recoveryDuration, expectedGeneration, SHOWTIME_PHASE_RECOVERY, StartShowtimeReadyFade)
    end
end

local function GetShowtimeServerTime()
    if type(GetServerTime) == "function" then
        local ok, serverTime = pcall(GetServerTime)
        if ok and type(serverTime) == "number" then return serverTime end
    end
    return nil
end

StartShowtimeCycle = function(isPreview, burstOverride, cooldownOverride)
    if isPreview and IsRealShowtimeCycleActive() then
        print("|cffffcc00[P5S UI]|r 当前真实 Showtime 周期仍在运行，暂不启动预览。")
        return false
    end

    if not isPreview and (not P5S_UI_DB or not P5S_UI_DB.showtimeEnabled or not runtimeShowtimeSpellID) then
        EnterShowtimeDisabled()
        return false
    end

    local burstDuration = GetValidatedShowtimeSeconds(
        burstOverride or (P5S_UI_DB and P5S_UI_DB.showtimeBurstDuration),
        15
    )
    local cooldownDuration = GetValidatedShowtimeSeconds(
        cooldownOverride or (P5S_UI_DB and P5S_UI_DB.showtimeCooldownDuration),
        120
    )
    if cooldownDuration < burstDuration then cooldownDuration = burstDuration end

    showtimeState.generation = showtimeState.generation + 1
    local generation = showtimeState.generation
    StopShowtimeAnimations()
    ClearShowtimeCooldownWatcher()
    showtimeState.phase = SHOWTIME_PHASE_BURST
    showtimeState.phaseStartedAt = GetTime()
    showtimeState.phaseDuration = burstDuration
    showtimeState.fromPercent = 1
    showtimeState.toPercent = 0
    showtimeState.burstDuration = burstDuration
    showtimeState.cooldownDuration = cooldownDuration
    showtimeState.cooldownReadyEarly = false
    showtimeState.preview = isPreview and true or false
    SetShowtimeVisual(1, 1)
    P5SFrame.firePreview:SyncToShowtime()

    if P5S_UI_DB and not isPreview then
        P5S_UI_DB.showtimeLastTriggerServerTime = GetShowtimeServerTime()
    end
    RefreshShowtimeStatusText()

    if not PlayShowtimeRadialAnimation(
        showtimeRenderer.burstGroup,
        showtimeRenderer.burstAnimation,
        1,
        0,
        burstDuration,
        generation
    ) then
        ScheduleShowtimePhaseEnd(burstDuration, generation, SHOWTIME_PHASE_BURST, StartShowtimeRecovery)
    end

    if not isPreview then
        ArmShowtimeCooldownWatcher(runtimeShowtimeSpellID, generation)
    end
    return true
end

HandleShowtimeCooldownReady = function()
    local generation = showtimeState.generation
    ClearShowtimeCooldownWatcher()
    if showtimeState.phase == SHOWTIME_PHASE_BURST then
        showtimeState.cooldownReadyEarly = true
        RefreshShowtimeStatusText()
    elseif showtimeState.phase == SHOWTIME_PHASE_RECOVERY then
        StartShowtimeFastFinish(generation)
    end
end

RestoreShowtimeCycle = function()
    P5SFrame.firePreview:Stop()
    if not P5S_UI_DB or not P5S_UI_DB.showtimeEnabled or not runtimeShowtimeSpellID then
        EnterShowtimeDisabled()
        return
    end

    local triggerTime = tonumber(P5S_UI_DB.showtimeLastTriggerServerTime)
    local serverTime = GetShowtimeServerTime()
    if not triggerTime or not serverTime then
        EnterShowtimeReady()
        return
    end

    local elapsed = serverTime - triggerTime
    local burstDuration = GetValidatedShowtimeSeconds(P5S_UI_DB.showtimeBurstDuration, 15)
    local cooldownDuration = GetValidatedShowtimeSeconds(P5S_UI_DB.showtimeCooldownDuration, 120)
    if cooldownDuration < burstDuration then cooldownDuration = burstDuration end
    if elapsed < 0 then
        EnterShowtimeReady()
        return
    end

    showtimeState.generation = showtimeState.generation + 1
    local generation = showtimeState.generation
    StopShowtimeAnimations()
    ClearShowtimeCooldownWatcher()
    showtimeState.burstDuration = burstDuration
    showtimeState.cooldownDuration = cooldownDuration
    showtimeState.cooldownReadyEarly = false
    showtimeState.preview = false

    if elapsed < burstDuration then
        local currentPercent = ClampShowtimePercent(1 - (elapsed / burstDuration))
        local remainingDuration = burstDuration - elapsed
        showtimeState.phase = SHOWTIME_PHASE_BURST
        showtimeState.phaseStartedAt = GetTime()
        showtimeState.phaseDuration = remainingDuration
        showtimeState.fromPercent = currentPercent
        showtimeState.toPercent = 0
        SetShowtimeVisual(currentPercent, 1)
        P5SFrame.firePreview:SyncToShowtime()
        RefreshShowtimeStatusText()

        if not PlayShowtimeRadialAnimation(
            showtimeRenderer.burstGroup,
            showtimeRenderer.burstAnimation,
            currentPercent,
            0,
            remainingDuration,
            generation
        ) then
            ScheduleShowtimePhaseEnd(remainingDuration, generation, SHOWTIME_PHASE_BURST, StartShowtimeRecovery)
        end
        ArmShowtimeCooldownWatcher(runtimeShowtimeSpellID, generation)
        return
    end

    if cooldownDuration > burstDuration and elapsed < cooldownDuration then
        local recoveryDuration = cooldownDuration - burstDuration
        local recoveryElapsed = elapsed - burstDuration
        local currentPercent = ClampShowtimePercent(recoveryElapsed / recoveryDuration)
        local remainingDuration = cooldownDuration - elapsed
        showtimeState.phase = SHOWTIME_PHASE_RECOVERY
        showtimeState.phaseStartedAt = GetTime()
        showtimeState.phaseDuration = remainingDuration
        showtimeState.fromPercent = currentPercent
        showtimeState.toPercent = 1
        SetShowtimeVisual(currentPercent, SHOWTIME_DIM_ALPHA)
        RefreshShowtimeStatusText()

        if IsOrdinaryShowtimeSpellDefinitelyReady(runtimeShowtimeSpellID) then
            StartShowtimeFastFinish(generation)
            return
        end

        if not PlayShowtimeRadialAnimation(
            showtimeRenderer.recoveryGroup,
            showtimeRenderer.recoveryAnimation,
            currentPercent,
            1,
            remainingDuration,
            generation
        ) then
            ScheduleShowtimePhaseEnd(remainingDuration, generation, SHOWTIME_PHASE_RECOVERY, StartShowtimeReadyFade)
        end
        ArmShowtimeCooldownWatcher(runtimeShowtimeSpellID, generation)
        return
    end

    EnterShowtimeReady(generation)
end

local function ResetShowtimeForConfiguration()
    if P5S_UI_DB and P5S_UI_DB.showtimeEnabled and runtimeShowtimeSpellID then
        EnterShowtimeReady()
    else
        EnterShowtimeDisabled()
    end
end

local function UpdateCombatIcons()
    atkFrame:Hide()
    atkFrame:ClearAllPoints()
    defFrame:Hide()
    defFrame:ClearAllPoints()
    spdFrame:Hide()
    spdFrame:ClearAllPoints()

    if addon.BuffRuntime then
        addon.BuffRuntime.RefreshVisibility()
    end
    -- Buff 模式由原生容器显示；进脱战事件不能重新显示旧提示。
    if P5S_UI_DB and P5S_UI_DB.indicatorMode == "buff" then return end

    local isCombat = UnitAffectingCombat("player")
    local enabled = false
    local state = 15

    if isCombat then
        enabled = P5S_UI_DB.combatIndicatorEnabled
        state = P5S_UI_DB.combatIconState or 7
    else
        enabled = P5S_UI_DB.outOfCombatIndicatorEnabled
        state = P5S_UI_DB.outOfCombatIconState or 15
    end

    if not enabled or state == 15 then return end

    if state <= 7 then
        atkTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\攻小提升.tga")
        defTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\防小提升.tga")
        spdTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\速小提升.tga")
    else
        atkTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\攻大提升.tga")
        defTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\防大提升.tga")
        spdTex:SetTexture("Interface\\AddOns\\P5S\\P5S_UI\\Media\\速大提升.tga")
    end

    local layoutState = (state > 7) and (state - 7) or state

    if layoutState == 1 then 
        atkFrame:SetPoint("CENTER", P5SFrame, "CENTER", ATK_X, ATK_Y)
        atkFrame:Show()
    elseif layoutState == 2 then 
        defFrame:SetPoint("CENTER", P5SFrame, "CENTER", DEF_X - SLOT_SHIFT_X, DEF_Y + SLOT_SHIFT_Y)
        defFrame:Show()
    elseif layoutState == 3 then 
        spdFrame:SetPoint("CENTER", P5SFrame, "CENTER", SPD_X - (SLOT_SHIFT_X * 2), SPD_Y + (SLOT_SHIFT_Y * 2))
        spdFrame:Show()
    elseif layoutState == 4 then 
        atkFrame:SetPoint("CENTER", P5SFrame, "CENTER", ATK_X, ATK_Y)
        defFrame:SetPoint("CENTER", P5SFrame, "CENTER", DEF_X, DEF_Y)
        atkFrame:Show() defFrame:Show()
    elseif layoutState == 5 then 
        atkFrame:SetPoint("CENTER", P5SFrame, "CENTER", ATK_X, ATK_Y)
        spdFrame:SetPoint("CENTER", P5SFrame, "CENTER", SPD_X - SLOT_SHIFT_X, SPD_Y + SLOT_SHIFT_Y)
        atkFrame:Show() spdFrame:Show()
    elseif layoutState == 6 then 
        defFrame:SetPoint("CENTER", P5SFrame, "CENTER", DEF_X - SLOT_SHIFT_X, DEF_Y + SLOT_SHIFT_Y)
        spdFrame:SetPoint("CENTER", P5SFrame, "CENTER", SPD_X - SLOT_SHIFT_X, SPD_Y + SLOT_SHIFT_Y)
        defFrame:Show() spdFrame:Show()
    elseif layoutState == 7 then 
        atkFrame:SetPoint("CENTER", P5SFrame, "CENTER", ATK_X, ATK_Y)
        defFrame:SetPoint("CENTER", P5SFrame, "CENTER", DEF_X, DEF_Y)
        spdFrame:SetPoint("CENTER", P5SFrame, "CENTER", SPD_X, SPD_Y)
        atkFrame:Show() defFrame:Show() spdFrame:Show()
    end
end
addon.RefreshCombatIndicators = UpdateCombatIcons

do
    local resource = P5SFrame.thirdResource
    resource.byClass = {
        DEATHKNIGHT = {powerType = Enum.PowerType.Runes, powerToken = "RUNES", usesRuneCooldowns = true},
        DRUID = {powerType = Enum.PowerType.ComboPoints, powerToken = "COMBO_POINTS", specID = 103, requiresEnergyForm = true},
        ROGUE = {powerType = Enum.PowerType.ComboPoints, powerToken = "COMBO_POINTS"},
        MAGE = {powerType = Enum.PowerType.ArcaneCharges, powerToken = "ARCANE_CHARGES", specID = 62},
        MONK = {powerType = Enum.PowerType.Chi, powerToken = "CHI", specID = 269},
        PALADIN = {powerType = Enum.PowerType.HolyPower, powerToken = "HOLY_POWER"},
        WARLOCK = {powerType = Enum.PowerType.SoulShards, powerToken = "SOUL_SHARDS", supportsPartialFill = true},
        EVOKER = {powerType = Enum.PowerType.Essence, powerToken = "ESSENCE"},
    }
    resource.getPlayerSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    resource.getPlayerSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    resource.runeEntries = {}
    resource.runeOrder = {}
    for index = 1, 6 do
        local entry = {runeIndex = index}
        resource.runeEntries[index] = entry
        resource.runeOrder[index] = entry
    end
    resource.runeSortCompare = function(left, right)
        if left.state ~= right.state then
            return left.state > right.state
        end
        if left.state == 2 and left.endTime ~= right.endTime then
            return left.endTime < right.endTime
        end
        return left.runeIndex < right.runeIndex
    end

    function resource:IsSecretValue(value)
        if type(issecretvalue) ~= "function" then return false end
        local ok, isSecret = pcall(issecretvalue, value)
        if not ok or type(isSecret) ~= "boolean" then return true end
        return isSecret
    end

    function resource:IsSafeNumber(value)
        if self:IsSecretValue(value) then return false end
        return type(value) == "number" and value == value
    end

    function resource:IsSafeBoolean(value)
        if self:IsSecretValue(value) then return false end
        return type(value) == "boolean"
    end

    function resource:GetPlayerClassFilename()
        local ok, _, classFilename = pcall(UnitClass, "player")
        if not ok or self:IsSecretValue(classFilename) or type(classFilename) ~= "string" then
            return nil
        end
        return classFilename
    end

    function resource:IsCurrentPowerToken(powerToken)
        if self:IsSecretValue(powerToken) or type(powerToken) ~= "string" then
            return false
        end
        local playerClass = self:GetPlayerClassFilename()
        local config = playerClass and self.byClass[playerClass]
        return config and powerToken == config.powerToken or false
    end

    function resource:GetStyleTexture(styleKey)
        local style = type(styleKey) == "string" and self.styles[styleKey]
        local texture = style and style.texture
        if type(texture) ~= "string" or texture == "" then
            texture = self.styles.A.texture
        end
        return texture
    end

    function resource:ApplyStyle(styleKey)
        local texture = self:GetStyleTexture(styleKey)
        if type(texture) ~= "string" or texture == "" then return end

        self:ApplyLayout(styleKey)
        self.texture = texture
        for index = 1, self.maxSlots do
            local slot = self.slots[index]
            if slot then
                if slot.emptyTexture then
                    slot.emptyTexture:SetTexture(texture)
                end
                if slot.fill then
                    slot.fill:SetStatusBarTexture(texture)
                end
            end
        end
    end

    function resource:RefreshOptionControls()
        if not P5S_UI_DB then return end

        if self.optionCheck then
            self.optionCheck:SetChecked(P5S_UI_DB.thirdResourceEnabled ~= false)
        end

        local styleKey = P5S_UI_DB.thirdResourceStyle
        local style = type(styleKey) == "string" and self.styles[styleKey]
        if not style then
            styleKey = "A"
            style = self.styles.A
        end
        if self.optionDropdown then
            UIDropDownMenu_SetSelectedValue(self.optionDropdown, styleKey)
            UIDropDownMenu_SetText(self.optionDropdown, style.label)
        end
    end

    function resource:CreateOptionControls(parent)
        local resourceTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        resourceTitle:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -135)
        resourceTitle:SetText("第三资源")
        ApplyPanelTheme("StyleBodyText", resourceTitle)

        local visibilityCheck = CreateFrame(
            "CheckButton",
            "P5S_ThirdResourceEnabledCheck",
            parent,
            "UICheckButtonTemplate"
        )
        visibilityCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 132, -132)
        _G[visibilityCheck:GetName() .. "Text"]:SetText("显示")
        visibilityCheck:SetScript("OnClick", function(button)
            if not P5S_UI_DB then return end
            P5S_UI_DB.thirdResourceEnabled = button:GetChecked() and true or false
            self:Update()
        end)
        ApplyPanelTheme("StyleCheckBox", visibilityCheck)
        self.optionCheck = visibilityCheck

        local styleDropdown = CreateFrame(
            "Frame",
            "P5S_ThirdResourceStyleDropdown",
            parent,
            "UIDropDownMenuTemplate"
        )
        styleDropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 270, -126)
        UIDropDownMenu_SetWidth(styleDropdown, 245)
        UIDropDownMenu_SetText(styleDropdown, self.styles.A.label)
        UIDropDownMenu_Initialize(styleDropdown, function(_, level)
            for _, styleKey in ipairs(self.styleOrder) do
                local style = self.styles[styleKey]
                local info = UIDropDownMenu_CreateInfo()
                info.text = style.label
                info.value = styleKey
                info.arg1 = styleKey
                info.checked = P5S_UI_DB and P5S_UI_DB.thirdResourceStyle == styleKey
                info.justifyH = "RIGHT"
                info.func = function(_, selectedStyle)
                    if not P5S_UI_DB or not self.styles[selectedStyle] then return end
                    P5S_UI_DB.thirdResourceStyle = selectedStyle
                    self:ApplyStyle(selectedStyle)
                    self:RefreshOptionControls()
                    self:Update()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        ApplyPanelTheme("StyleDropDown", styleDropdown)
        UIDropDownMenu_JustifyText(styleDropdown, "RIGHT")
        self.optionDropdown = styleDropdown
    end

    function resource:Hide()
        self.frame:Hide()
    end

    function resource:SetSlotFillAppearance(slot, desaturated, brightness)
        local fillTexture = slot.fill:GetStatusBarTexture()
        if not fillTexture then return end

        if fillTexture.SetDesaturated then
            fillTexture:SetDesaturated(desaturated)
        end
        local vertexBrightness = brightness or 1
        fillTexture:SetVertexColor(
            vertexBrightness,
            vertexBrightness,
            vertexBrightness,
            1
        )
    end

    function resource:SetSlotFill(slot, amount)
        -- SetMinMaxValues 会解除 StatusBar 与旧 LuaDurationObject 的绑定，
        -- 保证切换职业或回到普通离散资源时不会残留符文冷却动画。
        self:SetSlotFillAppearance(slot, false, 1)
        slot.fill:SetMinMaxValues(0, 1)
        if amount <= 0 then
            slot.fill:SetValue(0)
            slot.fill:Hide()
            return
        end

        if amount > 1 then amount = 1 end
        slot.fill:SetValue(amount)
        slot.fill:Show()
    end

    function resource:ShowValue(slotCount, currentValue)
        slotCount = math.floor(slotCount)
        if slotCount < 1 then
            self:Hide()
            return
        end
        if slotCount > self.maxSlots then
            slotCount = self.maxSlots
        end

        if currentValue < 0 then currentValue = 0 end
        if currentValue > slotCount then currentValue = slotCount end

        local firstVisibleIndex = self.maxSlots - slotCount + 1
        for index = 1, self.maxSlots do
            local slot = self.slots[index]
            if index >= firstVisibleIndex then
                local logicalIndex = index - firstVisibleIndex + 1
                self:SetSlotFill(slot, currentValue - (logicalIndex - 1))
                slot:Show()
            else
                self:SetSlotFill(slot, 0)
                slot:Hide()
            end
        end
        self.frame:Show()
    end

    function resource:EnsureRuneDurationSupport()
        if self.runeDurationSupportChecked then
            return self.runeDurationSupported
        end

        self.runeDurationSupportChecked = true
        self.runeDurationSupported = false

        local interpolation = Enum
            and Enum.StatusBarInterpolation
            and Enum.StatusBarInterpolation.Immediate
        local direction = Enum
            and Enum.StatusBarTimerDirection
            and Enum.StatusBarTimerDirection.ElapsedTime
        if type(C_DurationUtil) ~= "table"
            or type(C_DurationUtil.CreateDuration) ~= "function"
            or interpolation == nil
            or direction == nil then
            return false
        end

        local firstVisibleIndex = self.maxSlots - 6 + 1
        local durationObjects = {}
        for logicalIndex = 1, 6 do
            local slot = self.slots[firstVisibleIndex + logicalIndex - 1]
            if not slot or type(slot.fill.SetTimerDuration) ~= "function" then
                return false
            end

            local ok, durationObject = pcall(C_DurationUtil.CreateDuration)
            if not ok
                or durationObject == nil
                or type(durationObject.SetTimeFromStart) ~= "function" then
                return false
            end
            durationObjects[logicalIndex] = durationObject
        end

        for logicalIndex = 1, 6 do
            local slot = self.slots[firstVisibleIndex + logicalIndex - 1]
            slot.runeDuration = durationObjects[logicalIndex]
        end
        self.runeInterpolation = interpolation
        self.runeTimerDirection = direction
        self.runeDurationSupported = true
        return true
    end

    function resource:SetRuneCooldownFill(slot, startTime, duration)
        local durationObject = slot.runeDuration
        if not durationObject then return false end

        -- 死亡骑士冷却进度使用压暗灰色；就绪与其他职业仍由 SetSlotFill 恢复为原色黄色。
        self:SetSlotFillAppearance(slot, true, self.runeCooldownBrightness)
        -- 先解除旧计时器，再把实际符文冷却交给原生 StatusBar 连续填充。
        slot.fill:SetMinMaxValues(0, 0)
        local okDuration = pcall(
            durationObject.SetTimeFromStart,
            durationObject,
            startTime,
            duration,
            1
        )
        local okTimer = okDuration and pcall(
            slot.fill.SetTimerDuration,
            slot.fill,
            durationObject,
            self.runeInterpolation,
            self.runeTimerDirection
        )
        if not okTimer then
            self.runeDurationSupported = false
            self:SetSlotFill(slot, 0)
            return false
        end

        slot.fill:Show()
        return true
    end

    function resource:ShowRunes()
        if type(GetRuneCooldown) ~= "function" then
            self:Hide()
            return
        end

        local readyRuneCount = 0
        local hasActiveCooldown = false
        local timingIsSafe = true
        for runeIndex = 1, 6 do
            local ok, startTime, duration, runeReady = pcall(GetRuneCooldown, runeIndex)
            if not ok or not self:IsSafeBoolean(runeReady) then
                self:Hide()
                return
            end

            local entry = self.runeEntries[runeIndex]
            entry.startTime = nil
            entry.duration = nil
            entry.endTime = nil
            if runeReady then
                readyRuneCount = readyRuneCount + 1
                entry.state = 3 -- 已就绪
            elseif self:IsSecretValue(startTime) or self:IsSecretValue(duration) then
                timingIsSafe = false
                entry.state = 1
            elseif startTime == nil then
                entry.state = 1 -- 已消耗，但尚未进入最多三枚并行恢复的队列
            elseif not self:IsSafeNumber(startTime) or not self:IsSafeNumber(duration) then
                timingIsSafe = false
                entry.state = 1
            elseif startTime <= 0 then
                entry.state = 1
            elseif duration > 0 then
                entry.state = 2 -- 正在恢复
                entry.startTime = startTime
                entry.duration = duration
                entry.endTime = startTime + duration
                hasActiveCooldown = true
            else
                timingIsSafe = false
                entry.state = 1
            end

            self.runeOrder[runeIndex] = entry
        end

        -- 时间值不可安全读取或客户端缺少原生计时能力时，安静降级为连续数量显示。
        if not timingIsSafe
            or (hasActiveCooldown and not self:EnsureRuneDurationSupport()) then
            self:ShowValue(6, readyRuneCount)
            return
        end

        table.sort(self.runeOrder, self.runeSortCompare)
        local firstVisibleIndex = self.maxSlots - 6 + 1
        for index = 1, self.maxSlots do
            local slot = self.slots[index]
            if index < firstVisibleIndex then
                self:SetSlotFill(slot, 0)
                slot:Hide()
            else
                local logicalIndex = index - firstVisibleIndex + 1
                local entry = self.runeOrder[logicalIndex]
                if entry.state == 3 then
                    self:SetSlotFill(slot, 1)
                elseif entry.state == 2 then
                    if not self:SetRuneCooldownFill(slot, entry.startTime, entry.duration) then
                        self:ShowValue(6, readyRuneCount)
                        return
                    end
                else
                    self:SetSlotFill(slot, 0)
                end
                slot:Show()
            end
        end
        self.frame:Show()
    end

    function resource:GetCurrentSpecID()
        if type(self.getPlayerSpecialization) ~= "function"
            or type(self.getPlayerSpecializationInfo) ~= "function" then
            return nil
        end

        local okIndex, specializationIndex = pcall(self.getPlayerSpecialization)
        if not okIndex or not self:IsSafeNumber(specializationIndex) or specializationIndex < 1 then
            return nil
        end

        local okInfo, specializationID = pcall(self.getPlayerSpecializationInfo, specializationIndex)
        if not okInfo or not self:IsSafeNumber(specializationID) then
            return nil
        end
        return specializationID
    end

    function resource:Update()
        if P5S_UI_DB and P5S_UI_DB.thirdResourceEnabled == false then
            self:Hide()
            return
        end

        local playerClass = self:GetPlayerClassFilename()
        local config = playerClass and self.byClass[playerClass]
        if not config or not self:IsSafeNumber(config.powerType) then
            self:Hide()
            return
        end

        if config.specID and self:GetCurrentSpecID() ~= config.specID then
            self:Hide()
            return
        end

        if config.requiresEnergyForm then
            local okType, displayedPowerType = pcall(UnitPowerType, "player")
            if not okType or not self:IsSafeNumber(displayedPowerType)
                or displayedPowerType ~= Enum.PowerType.Energy then
                self:Hide()
                return
            end
        end

        if config.usesRuneCooldowns then
            self:ShowRunes()
            return
        end

        local okMax, maxPower = pcall(UnitPowerMax, "player", config.powerType)
        local okCurrent, currentPower = pcall(UnitPower, "player", config.powerType)
        if not okMax or not okCurrent
            or not self:IsSafeNumber(maxPower)
            or not self:IsSafeNumber(currentPower) then
            self:Hide()
            return
        end

        if config.supportsPartialFill and type(UnitPowerDisplayMod) == "function" then
            local okRaw, rawPower = pcall(UnitPower, "player", config.powerType, true)
            local okMod, displayMod = pcall(UnitPowerDisplayMod, config.powerType)
            if okRaw and okMod
                and self:IsSafeNumber(rawPower)
                and self:IsSafeNumber(displayMod)
                and displayMod > 0 then
                currentPower = rawPower / displayMod
            end
        end

        self:ShowValue(maxPower, currentPower)
    end
end

local PlayerEvents = CreateFrame("Frame")
PlayerEvents:RegisterEvent("UNIT_HEALTH")
PlayerEvents:RegisterEvent("UNIT_MAXHEALTH")
PlayerEvents:RegisterEvent("UNIT_POWER_UPDATE")
PlayerEvents:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
PlayerEvents:RegisterEvent("UNIT_MAXPOWER")
PlayerEvents:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
PlayerEvents:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED") 
PlayerEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
PlayerEvents:RegisterEvent("PLAYER_LEVEL_UP") 
PlayerEvents:RegisterEvent("PLAYER_REGEN_DISABLED") 
PlayerEvents:RegisterEvent("PLAYER_REGEN_ENABLED")  
PlayerEvents:RegisterEvent("RUNE_POWER_UPDATE")
PlayerEvents:RegisterUnitEvent("UNIT_SPELL_HASTE", "player")
PlayerEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
PlayerEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
PlayerEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
PlayerEvents:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
PlayerEvents:RegisterEvent("PLAYER_TARGET_CHANGED")

local percentCurve = C_CurveUtil.CreateCurve()
percentCurve:SetType(Enum.LuaCurveType.Linear)
percentCurve:AddPoint(0, 0)
percentCurve:AddPoint(1, 100)

PlayerEvents:SetScript("OnEvent", function(self, event, arg1, arg2)
    -- RUNE_POWER_UPDATE 的事件参数在 12.1 可为 Secret Payload；不要让它进入后续单位字符串比较。
    if event == "RUNE_POWER_UPDATE" then
        P5SFrame.thirdResource:Update()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then 
        arg1 = "player" 
    end

    if event == "PLAYER_ENTERING_WORLD" then
        lvText:SetText(UnitLevel("player"))
    elseif event == "PLAYER_LEVEL_UP" then
        lvText:SetText(arg1)
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        UpdateCombatIcons()
    end

    if event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_LEVEL_UP"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "PLAYER_TARGET_CHANGED"
        or (arg1 == "player" and (
            event == "UNIT_DISPLAYPOWER"
            or event == "UNIT_SPELL_HASTE"
            or event == "PLAYER_SPECIALIZATION_CHANGED"
            or ((event == "UNIT_POWER_UPDATE"
                or event == "UNIT_POWER_FREQUENT"
                or event == "UNIT_MAXPOWER")
                and P5SFrame.thirdResource:IsCurrentPowerToken(arg2))
        )) then
        P5SFrame.thirdResource:Update()
    end

    if arg1 == "player" and event ~= "UNIT_POWER_FREQUENT" then
        local immediate = event == "PLAYER_ENTERING_WORLD" or event == "UNIT_MAXHEALTH"
        local maxHealth = UnitHealthMax("player")
        hpBar:UpdateSmoothValue(maxHealth, UnitHealth("player"), immediate)
        hpValueText:SetFormattedText("%.0f", UnitHealthPercent("player", true, percentCurve))
        
        shieldBar:UpdateSmoothValue(maxHealth, UnitGetTotalAbsorbs("player"), immediate)
    end

    -- 高频资源事件只刷新 SP；生命与护盾仍沿用原来的刷新路径。
    if event == "PLAYER_ENTERING_WORLD"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or (arg1 == "player" and (
            event == "UNIT_POWER_UPDATE"
            or event == "UNIT_POWER_FREQUENT"
            or event == "UNIT_MAXPOWER"
            or event == "UNIT_DISPLAYPOWER"
            or event == "PLAYER_SPECIALIZATION_CHANGED"
        )) then
        local maxSp = UnitPowerMax("player")
        local spRaw = UnitPower("player")

        -- 登录、切换资源/形态/专精及上限变化直接对齐，不从旧资源量插值。
        local immediate = event ~= "UNIT_POWER_UPDATE" and event ~= "UNIT_POWER_FREQUENT"
        spBar:UpdateSmoothValue(maxSp, spRaw, immediate)
        
        -- 判断玩家的能量类型，如果是蓝条 (Mana)，则利用暴雪 API 转换为百分比显示
        local powerType = UnitPowerType("player")
        if powerType == Enum.PowerType.Mana then
            -- 使用 12.0 最新安全 API 直接获取百分比，彻底规避 Secret Value 的算术报错
            local percent = UnitPowerPercent("player", powerType, true, percentCurve) or 0
            spValueText:SetFormattedText("%.0f", percent)
        else
            -- 怒气、能量等其他资源，直接显示原始数值，SetText 天生支持处理 Secret Value
            spValueText:SetText(spRaw)
        end
    end
end)

-- ==========================================
-- 5. 创建设置面板 (GUI)
-- ==========================================
local OptionsPanel = CreateFrame("Frame", "P5S_OptionsPanel", UIParent, "BackdropTemplate")
OptionsPanel:SetSize(700, 820)
OptionsPanel:SetPoint("CENTER")
OptionsPanel:SetClampedToScreen(true)
OptionsPanel:Hide()

-- 优先注册命令，避免任何视觉主题错误影响 /p5s 的可用性。
SLASH_P5SUI1 = "/p5s"
SlashCmdList["P5SUI"] = function()
    if OptionsPanel:IsShown() then OptionsPanel:Hide() else OptionsPanel:Show() end
end

ApplyPanelTheme("ApplyOptionsPanel", OptionsPanel)

-- 主题初始化失败时保留最基本的标题锚点和关闭能力。
if not OptionsPanel.TitleBg then
    OptionsPanel.TitleBg = OptionsPanel:CreateTexture(nil, "BACKGROUND")
    OptionsPanel.TitleBg:SetPoint("TOPLEFT", OptionsPanel, "TOPLEFT", 1, -1)
    OptionsPanel.TitleBg:SetPoint("TOPRIGHT", OptionsPanel, "TOPRIGHT", -1, -1)
    OptionsPanel.TitleBg:SetHeight(38)
    OptionsPanel.TitleBg:SetColorTexture(0.055, 0.060, 0.085, 0.98)
end

if not OptionsPanel.CloseButton then
    OptionsPanel.CloseButton = CreateFrame("Button", nil, OptionsPanel, "UIPanelCloseButton")
    OptionsPanel.CloseButton:SetPoint("TOPRIGHT", OptionsPanel, "TOPRIGHT", -14, -7)
    OptionsPanel.CloseButton:SetScript("OnClick", function()
        OptionsPanel:Hide()
    end)
end

OptionsPanel:SetMovable(true)
OptionsPanel:EnableMouse(true)
OptionsPanel:RegisterForDrag("LeftButton")
OptionsPanel:SetScript("OnDragStart", OptionsPanel.StartMoving)
OptionsPanel:SetScript("OnDragStop", OptionsPanel.StopMovingOrSizing)

OptionsPanel:SetScript("OnHide", function()
    if CommitShowtimeOptions then
        CommitShowtimeOptions(true)
    end
end)

-- 各种隐藏入口仍保存；仅手动点击关闭按钮时提示，切换设置页保持安静。
OptionsPanel.CloseButton:HookScript("OnClick", function()
    print("|cffFF0000[P5S UI]|r 设置已保存，萨斯噶Joker！")
end)

OptionsPanel.title = OptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
OptionsPanel.title:SetPoint("CENTER", OptionsPanel.TitleBg, "CENTER", 0, 0)
OptionsPanel.title:SetText("P5S 资源条设置")
ApplyPanelTheme("StylePanelTitle", OptionsPanel.title)

local function OpenSiblingSettingsPanel(slashKey, panelName)
    OptionsPanel:Hide()

    local commandHandler = SlashCmdList[slashKey]
    if not commandHandler then
        print("|cffFF0000[P5S UI]|r 对应的设置面板暂时不可用。")
        return
    end

    -- 目标面板本身是切换式命令；若它已显示，先关闭再重新打开。
    local targetPanel = _G[panelName]
    if targetPanel and targetPanel:IsShown() then
        commandHandler("")
    end
    commandHandler("")
end

local function CreateSettingsSection(topOffset, height, titleText, descriptionText)
    local section = CreateFrame("Frame", nil, OptionsPanel, "BackdropTemplate")
    section:SetPoint("TOPLEFT", OptionsPanel, "TOPLEFT", 24, topOffset)
    section:SetPoint("TOPRIGHT", OptionsPanel, "TOPRIGHT", -34, topOffset)
    section:SetHeight(height)

    local accent = section:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -10)
    title:SetText(titleText)
    ApplyPanelTheme("StyleSection", section, title, accent)

    local description = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    description:SetPoint("TOPLEFT", section, "TOPLEFT", 200, -12)
    description:SetPoint("TOPRIGHT", section, "TOPRIGHT", -16, -12)
    description:SetJustifyH("LEFT")
    description:SetText(descriptionText)
    ApplyPanelTheme("StyleMutedText", description)

    return section
end

local appearanceSection = CreateSettingsSection(-116, 180, "Joker 资源条", "显示生命、法力/能量及职业专属资源。")
local indicatorSection = CreateSettingsSection(-308, 232, "攻/防/速 战斗提示", "用攻、防、速图标提示进脱战状态或自身 Buff。")
local showtimeSection = CreateSettingsSection(-552, 232, "Showtime 爆发槽", "施放绑定技能后，显示爆发持续与冷却进度。")

do
    local authorText = OptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    authorText:SetFont(authorText:GetFont(), 11, "")
    authorText:SetPoint("BOTTOMLEFT", OptionsPanel, "BOTTOMLEFT", 24, 19)
    authorText:SetSize(240, 14)
    authorText:SetJustifyH("LEFT")
    authorText:SetJustifyV("MIDDLE")
    authorText:SetText("插件制作：难刷素材的XZQ")
    ApplyPanelTheme("StyleMutedText", authorText)

    local copyrightText = OptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    copyrightText:SetFont(copyrightText:GetFont(), 10, "")
    copyrightText:SetPoint("BOTTOMRIGHT", OptionsPanel, "BOTTOMRIGHT", -34, 6)
    copyrightText:SetSize(642, 26)
    copyrightText:SetJustifyH("RIGHT")
    copyrightText:SetJustifyV("BOTTOM")
    copyrightText:SetSpacing(1)
    copyrightText:SetWordWrap(true)
    copyrightText:SetText("Persona 5 Strikers ©ATLUS ©SEGA / ©KOEI TECMO GAMES\nPersona 3 Reload / Persona Q ©ATLUS ©SEGA")
    ApplyPanelTheme("StyleMutedText", copyrightText)
end

local navigationLabel = OptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
navigationLabel:SetPoint("LEFT", OptionsPanel, "TOPLEFT", 34, -76)
navigationLabel:SetText("快速切换")
ApplyPanelTheme("StyleMutedText", navigationLabel)

local targetSettingsButton = CreateFrame("Button", "P5S_TargetSettingsButton", OptionsPanel, "UIPanelButtonTemplate")
targetSettingsButton:SetSize(170, 30)
targetSettingsButton:SetPoint("TOPLEFT", OptionsPanel, "TOPLEFT", 118, -61)
targetSettingsButton:SetText("爱心血条设置")
targetSettingsButton:SetScript("OnClick", function()
    OpenSiblingSettingsPanel("P5TARGET", "P5ConfigPanel")
end)
ApplyPanelTheme("StyleButton", targetSettingsButton)

local voiceSettingsButton = CreateFrame("Button", "P5S_VoiceSettingsButton", OptionsPanel, "UIPanelButtonTemplate")
voiceSettingsButton:SetSize(170, 30)
voiceSettingsButton:SetPoint("LEFT", targetSettingsButton, "RIGHT", 14, 0)
voiceSettingsButton:SetText("技能语音设置")
voiceSettingsButton:SetScript("OnClick", function()
    OpenSiblingSettingsPanel("P5VOICE", "P5VoiceConfigPanel")
end)
ApplyPanelTheme("StyleButton", voiceSettingsButton)

do
    local weakSettingsButton = CreateFrame("Button", "P5S_WeakSettingsButton", OptionsPanel, "UIPanelButtonTemplate")
    weakSettingsButton:SetSize(170, 30)
    weakSettingsButton:SetPoint("LEFT", voiceSettingsButton, "RIGHT", 14, 0)
    weakSettingsButton:SetText("眼神特写设置")
    weakSettingsButton:SetScript("OnClick", function()
        OpenSiblingSettingsPanel("P5WEAK", "P5WeakConfigPanel")
    end)
    ApplyPanelTheme("StyleButton", weakSettingsButton)
end

do
    local visibilityCheck = CreateFrame("CheckButton", "P5S_ResourceBarEnabledCheck", appearanceSection, "UICheckButtonTemplate")
    visibilityCheck:SetPoint("TOPLEFT", appearanceSection, "TOPLEFT", 22, -38)
    _G[visibilityCheck:GetName() .. "Text"]:SetText("显示整套资源条")
    visibilityCheck:SetScript("OnClick", function(self)
        if not P5S_UI_DB then return end
        P5S_UI_DB.resourceBarEnabled = self:GetChecked() and true or false
        P5SFrame:ApplyResourceBarVisibility()
    end)
    P5SFrame.resourceBarCheck = visibilityCheck
    ApplyPanelTheme("StyleCheckBox", visibilityCheck)

    local sizeLabel = appearanceSection:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", appearanceSection, "TOPLEFT", 22, -85)
    sizeLabel:SetText("整体大小")
    ApplyPanelTheme("StyleBodyText", sizeLabel)
end

local slider = CreateFrame("Slider", "P5S_SizeSlider", appearanceSection, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", appearanceSection, "TOPLEFT", 132, -82)
slider:SetWidth(410)
slider:SetMinMaxValues(MIN_SIZE, MAX_SIZE)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)

_G[slider:GetName() .. 'Low']:SetText(MIN_SIZE)
_G[slider:GetName() .. 'High']:SetText(MAX_SIZE)

local sliderText = _G[slider:GetName() .. 'Text']

slider:SetScript("OnValueChanged", function(self, value)
    local roundedValue = math.floor(value + 0.5)
    local scale = roundedValue / BASE_SIZE
    P5SFrame:SetScale(scale)
    sliderText:SetText(tostring(roundedValue))
    if P5S_UI_DB then P5S_UI_DB.size = roundedValue end
end)
ApplyPanelTheme("StyleSlider", slider)

local lockCheck = CreateFrame("CheckButton", "P5S_LockCheck", appearanceSection, "UICheckButtonTemplate")
lockCheck:SetPoint("TOPLEFT", appearanceSection, "TOPLEFT", 300, -38)
_G[lockCheck:GetName() .. "Text"]:SetText("锁定位置")

lockCheck:SetScript("OnClick", function(self)
    local isChecked = self:GetChecked()
    P5S_UI_DB.isLocked = isChecked
end)
ApplyPanelTheme("StyleCheckBox", lockCheck)
P5SFrame.thirdResource:CreateOptionControls(appearanceSection)

local stateOptions = {
    "1. 攻小", "2. 防小", "3. 速小", "4. 攻小+防小", "5. 攻小+速小", "6. 防小+速小", "7. 攻小+防小+速小",
    "8. 攻大", "9. 防大", "10. 速大", "11. 攻大+防大", "12. 攻大+速大", "13. 防大+速大", "14. 攻大+防大+速大",
    "15. 关闭显示"
}

-- 【战斗提示相关】
local statusHeader = indicatorSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statusHeader:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 140, -76)
statusHeader:SetText("状态")
ApplyPanelTheme("StyleMutedText", statusHeader)

local combatTitle2 = indicatorSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
combatTitle2:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 300, -76)
combatTitle2:SetText("动画组合")
ApplyPanelTheme("StyleMutedText", combatTitle2)

local combatTitle = indicatorSection:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
combatTitle:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 22, -103)
combatTitle:SetText("进入战斗")
ApplyPanelTheme("StyleBodyText", combatTitle)

local combatCheck = CreateFrame("CheckButton", "P5S_CombatCheck", indicatorSection, "UICheckButtonTemplate")
combatCheck:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 132, -100)
_G[combatCheck:GetName() .. "Text"]:SetText("启用")

combatCheck:SetScript("OnClick", function(self)
    if P5S_UI_DB.indicatorMode == "buff" then return end
    P5S_UI_DB.combatIndicatorEnabled = self:GetChecked()
    UpdateCombatIcons()
end)
ApplyPanelTheme("StyleCheckBox", combatCheck)

local combatDropdown = CreateFrame("Frame", "P5S_StateDropdown", indicatorSection, "UIDropDownMenuTemplate")
combatDropdown:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 270, -94)
UIDropDownMenu_SetWidth(combatDropdown, 245)

UIDropDownMenu_Initialize(combatDropdown, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    for i, text in ipairs(stateOptions) do
        info.text = text
        info.arg1 = i
        info.func = function(self, arg1)
            if P5S_UI_DB.indicatorMode == "buff" then return end
            UIDropDownMenu_SetSelectedValue(combatDropdown, arg1)
            UIDropDownMenu_SetText(combatDropdown, stateOptions[arg1])
            P5S_UI_DB.combatIconState = arg1
            UpdateCombatIcons()
        end
        UIDropDownMenu_AddButton(info)
    end
end)
ApplyPanelTheme("StyleDropDown", combatDropdown)

-- 【脱战显示相关】
local oocTitle = indicatorSection:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
oocTitle:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 22, -143)
oocTitle:SetText("脱离战斗")
ApplyPanelTheme("StyleBodyText", oocTitle)

local oocCheck = CreateFrame("CheckButton", "P5S_OocCheck", indicatorSection, "UICheckButtonTemplate")
oocCheck:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 132, -140)
_G[oocCheck:GetName() .. "Text"]:SetText("启用")

oocCheck:SetScript("OnClick", function(self)
    if P5S_UI_DB.indicatorMode == "buff" then return end
    P5S_UI_DB.outOfCombatIndicatorEnabled = self:GetChecked()
    UpdateCombatIcons()
end)
ApplyPanelTheme("StyleCheckBox", oocCheck)

local oocDropdown = CreateFrame("Frame", "P5S_StateDropdownOoc", indicatorSection, "UIDropDownMenuTemplate")
oocDropdown:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 270, -134)
UIDropDownMenu_SetWidth(oocDropdown, 245)

UIDropDownMenu_Initialize(oocDropdown, function(self, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    for i, text in ipairs(stateOptions) do
        info.text = text
        info.arg1 = i
        info.func = function(self, arg1)
            if P5S_UI_DB.indicatorMode == "buff" then return end
            UIDropDownMenu_SetSelectedValue(oocDropdown, arg1)
            UIDropDownMenu_SetText(oocDropdown, stateOptions[arg1])
            P5S_UI_DB.outOfCombatIconState = arg1
            UpdateCombatIcons()
        end
        UIDropDownMenu_AddButton(info)
    end
end)
ApplyPanelTheme("StyleDropDown", oocDropdown)

-- 用途单选，保存模式但不伪装已实现的 Buff 监控。
do
    local combatMode = CreateFrame("CheckButton", "P5S_CombatModeCheck", indicatorSection, "UICheckButtonTemplate")
    combatMode:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 16, -40)
    _G[combatMode:GetName() .. "Text"]:SetText("用于进战/脱战提示")
    ApplyPanelTheme("StyleCheckBox", combatMode)

    local separator = indicatorSection:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 16, -179)
    separator:SetPoint("TOPRIGHT", indicatorSection, "TOPRIGHT", -16, -179)
    separator:SetHeight(1)
    separator:SetColorTexture(0.28, 0.32, 0.40, 0.7)

    local buffMode = CreateFrame("CheckButton", "P5S_BuffModeCheck", indicatorSection, "UICheckButtonTemplate")
    buffMode:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 16, -195)
    _G[buffMode:GetName() .. "Text"]:SetText("用于自身Buff监控")
    ApplyPanelTheme("StyleCheckBox", buffMode)

    function indicatorSection:RefreshMode()
        if not P5S_UI_DB then return end
        if P5S_UI_DB.indicatorMode ~= "buff" then P5S_UI_DB.indicatorMode = "combat" end
        local isCombatMode = P5S_UI_DB.indicatorMode == "combat"
        combatMode:SetChecked(isCombatMode)
        buffMode:SetChecked(not isCombatMode)
        combatCheck:SetEnabled(isCombatMode)
        oocCheck:SetEnabled(isCombatMode)
        local toggleDropdown = isCombatMode and UIDropDownMenu_EnableDropDown or UIDropDownMenu_DisableDropDown
        if toggleDropdown then toggleDropdown(combatDropdown); toggleDropdown(oocDropdown) end
        combatTitle:SetAlpha(isCombatMode and 1 or 0.45)
        oocTitle:SetAlpha(isCombatMode and 1 or 0.45)
    end
    local function SelectMode(mode)
        if not P5S_UI_DB then return end
        P5S_UI_DB.indicatorMode = mode
        if mode == "buff" and addon.BuffRuntime then addon.BuffRuntime.Apply() end
        if CloseDropDownMenus then CloseDropDownMenus() end
        indicatorSection:RefreshMode()
        UpdateCombatIcons()
    end
    -- 再点当前项仍保持选中，不能同时全选或全不选。
    combatMode:SetScript("OnClick", function() SelectMode("combat") end)
    buffMode:SetScript("OnClick", function() SelectMode("buff") end)
    OptionsPanel:HookScript("OnShow", function() indicatorSection:RefreshMode() end)

    local buffSettingsButton = CreateFrame("Button", "P5S_BuffSettingsButton", indicatorSection, "UIPanelButtonTemplate")
    buffSettingsButton:SetSize(160, 28)
    buffSettingsButton:SetPoint("TOPLEFT", indicatorSection, "TOPLEFT", 300, -192)
    buffSettingsButton:SetText("Buff 监控设置")
    buffSettingsButton:SetScript("OnClick", function()
        local options = addon and addon.BuffOptions
        if options and type(options.Open) == "function" and options.Open() then
            OptionsPanel:Hide()
        end
    end)
    ApplyPanelTheme("StyleButton", buffSettingsButton)
end

-- === 【Showtime 爆发槽控制台】 ===
do
local activeShowtimeSpellInput = nil
local showtimeSpellLinkHookInstalled = false

local function InstallShowtimeSpellLinkInputHook()
    if showtimeSpellLinkHookInstalled or type(hooksecurefunc) ~= "function" then return end
    showtimeSpellLinkHookInstalled = true

    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if activeShowtimeSpellInput
            and activeShowtimeSpellInput.HasFocus
            and activeShowtimeSpellInput:HasFocus()
            and type(link) == "string"
        then
            activeShowtimeSpellInput:Insert(link)
        end
    end)
end

local showtimeSpellLabel = showtimeSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
showtimeSpellLabel:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 22, -42)
showtimeSpellLabel:SetText("爆发技能")
ApplyPanelTheme("StyleBodyText", showtimeSpellLabel)

showtimeSpellInput = CreateFrame("EditBox", "P5S_ShowtimeSpellInput", showtimeSection, "InputBoxTemplate")
showtimeSpellInput:SetSize(300, 25)
showtimeSpellInput:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 104, -35)
showtimeSpellInput:SetAutoFocus(false)
showtimeSpellInput:SetMaxLetters(255)
showtimeSpellInput:SetScript("OnEnterPressed", function(self)
    if CommitShowtimeOptions then CommitShowtimeOptions(false) end
    self:ClearFocus()
end)
showtimeSpellInput:SetScript("OnEscapePressed", function(self)
    if P5S_UI_DB then self:SetText(P5S_UI_DB.showtimeSpellInput or "") end
    self:ClearFocus()
end)
showtimeSpellInput:SetScript("OnEditFocusGained", function(self)
    activeShowtimeSpellInput = self
    InstallShowtimeSpellLinkInputHook()
end)
showtimeSpellInput:SetScript("OnEditFocusLost", function(self)
    if activeShowtimeSpellInput == self then activeShowtimeSpellInput = nil end
    if CommitShowtimeOptions then CommitShowtimeOptions(true) end
end)
ApplyPanelTheme("StyleEditBox", showtimeSpellInput)

local showtimePreviewButton = CreateFrame("Button", "P5S_ShowtimePreviewButton", showtimeSection, "UIPanelButtonTemplate")
showtimePreviewButton:SetSize(76, 26)
showtimePreviewButton:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 418, -35)
showtimePreviewButton:SetText("快速预览")
showtimePreviewButton:SetScript("OnClick", function()
    if IsRealShowtimeCycleActive() then
        print("|cffffcc00[P5S UI]|r 当前真实 Showtime 周期仍在运行，暂不启动预览。")
        return
    end
    if CommitShowtimeOptions then CommitShowtimeOptions(true) end
    StartShowtimeCycle(true, SHOWTIME_PREVIEW_BURST_SECONDS, SHOWTIME_PREVIEW_COOLDOWN_SECONDS)
end)
ApplyPanelTheme("StyleButton", showtimePreviewButton)

showtimeStatusText = showtimeSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
showtimeStatusText:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 104, -67)
showtimeStatusText:SetWidth(450)
showtimeStatusText:SetJustifyH("LEFT")
showtimeStatusText:SetText("尚未绑定技能")
ApplyPanelTheme("StyleMutedText", showtimeStatusText)

local showtimeBurstLabel = showtimeSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
showtimeBurstLabel:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 22, -100)
showtimeBurstLabel:SetText("爆发持续")
ApplyPanelTheme("StyleBodyText", showtimeBurstLabel)

showtimeBurstInput = CreateFrame("EditBox", "P5S_ShowtimeBurstInput", showtimeSection, "InputBoxTemplate")
showtimeBurstInput:SetSize(62, 24)
showtimeBurstInput:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 104, -93)
showtimeBurstInput:SetAutoFocus(false)
showtimeBurstInput:SetJustifyH("CENTER")
showtimeBurstInput:SetMaxLetters(8)
ApplyPanelTheme("StyleEditBox", showtimeBurstInput)

local showtimeBurstUnit = showtimeSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
showtimeBurstUnit:SetPoint("LEFT", showtimeBurstInput, "RIGHT", 7, 0)
showtimeBurstUnit:SetText("秒")
ApplyPanelTheme("StyleMutedText", showtimeBurstUnit)

local showtimeCooldownLabel = showtimeSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
showtimeCooldownLabel:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 232, -100)
showtimeCooldownLabel:SetText("技能总冷却")
ApplyPanelTheme("StyleBodyText", showtimeCooldownLabel)

showtimeCooldownInput = CreateFrame("EditBox", "P5S_ShowtimeCooldownInput", showtimeSection, "InputBoxTemplate")
showtimeCooldownInput:SetSize(70, 24)
showtimeCooldownInput:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 338, -93)
showtimeCooldownInput:SetAutoFocus(false)
showtimeCooldownInput:SetJustifyH("CENTER")
showtimeCooldownInput:SetMaxLetters(8)
ApplyPanelTheme("StyleEditBox", showtimeCooldownInput)

local showtimeCooldownUnit = showtimeSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
showtimeCooldownUnit:SetPoint("LEFT", showtimeCooldownInput, "RIGHT", 7, 0)
showtimeCooldownUnit:SetText("秒（从施放算起）")
ApplyPanelTheme("StyleMutedText", showtimeCooldownUnit)

local function CommitShowtimeNumericInput(self)
    if CommitShowtimeOptions then CommitShowtimeOptions(false) end
    self:ClearFocus()
end
showtimeBurstInput:SetScript("OnEnterPressed", CommitShowtimeNumericInput)
showtimeCooldownInput:SetScript("OnEnterPressed", CommitShowtimeNumericInput)
showtimeBurstInput:HookScript("OnEditFocusLost", function()
    if CommitShowtimeOptions then CommitShowtimeOptions(true) end
end)
showtimeCooldownInput:HookScript("OnEditFocusLost", function()
    if CommitShowtimeOptions then CommitShowtimeOptions(true) end
end)
showtimeBurstInput:SetScript("OnEscapePressed", function(self)
    if P5S_UI_DB then self:SetText(FormatShowtimeSeconds(P5S_UI_DB.showtimeBurstDuration)) end
    self:ClearFocus()
end)
showtimeCooldownInput:SetScript("OnEscapePressed", function(self)
    if P5S_UI_DB then self:SetText(FormatShowtimeSeconds(P5S_UI_DB.showtimeCooldownDuration)) end
    self:ClearFocus()
end)

-- 只监听面板打开期间的点击；Shift+点击仍留给技能链接输入。
local showtimeInputs = { showtimeSpellInput, showtimeBurstInput, showtimeCooldownInput }
OptionsPanel:HookScript("OnShow", function(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
end)
OptionsPanel:HookScript("OnHide", function(self)
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    for _, input in ipairs(showtimeInputs) do input:ClearFocus() end
end)
OptionsPanel:HookScript("OnEvent", function(_, event)
    if event ~= "GLOBAL_MOUSE_DOWN" then return end
    for _, input in ipairs(showtimeInputs) do
        if input:HasFocus() and not input:IsMouseOver()
            and not (input == showtimeSpellInput and IsShiftKeyDown())
        then
            input:ClearFocus()
        end
    end
end)

local showtimeHelpText = showtimeSection:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
showtimeHelpText:SetPoint("TOPLEFT", showtimeSection, "TOPLEFT", 22, -137)
showtimeHelpText:SetWidth(540)
showtimeHelpText:SetJustifyH("LEFT")
showtimeHelpText:SetText("总冷却从施放算起且不短于爆发；普通技能提前转好时用 0.5 秒补全。充能技能首版仅按手填时间。预览：3 秒 / 8 秒。")
ApplyPanelTheme("StyleMutedText", showtimeHelpText)
end

P5SFrame.firePreview:CreateControl(showtimeSection)

-- 关于窗口只展示静态文案，不读取战斗数据或改动角色设置。
do
    local aboutPanel
    local aboutFailed = false
    local aboutButton = CreateFrame("Button", nil, showtimeSection, "UIPanelButtonTemplate")
    aboutButton:SetSize(90, 26)
    aboutButton:SetPoint("TOPRIGHT", showtimeSection, "TOPRIGHT", -22, -186)
    ApplyPanelTheme("StyleButton", aboutButton)
    aboutButton:SetText("关于")

    local function CreateAboutPanel()
        local panel = CreateFrame("Frame", "P5S_AboutPanel", UIParent, "BackdropTemplate")
        aboutPanel = panel
        panel:Hide()
        panel:SetSize(720, 680)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:SetToplevel(true)
        panel:SetClampedToScreen(true)
        panel:SetMovable(true)
        panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        panel:SetScript("OnHide", panel.StopMovingOrSizing)

        -- 先创建基础背景与关闭按钮，主题缺失或单项失败仍可阅读与关闭。
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        panel:SetBackdropColor(0.035, 0.040, 0.060, 0.98)
        panel:SetBackdropBorderColor(0.24, 0.28, 0.36, 1)
        ApplyPanelTheme("ApplyOptionsPanel", panel)
        if not panel.CloseButton then
            panel.CloseButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
            panel.CloseButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -7)
            panel.CloseButton:SetScript("OnClick", function() panel:Hide() end)
        end

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", panel, "TOP", 0, -12)
        title:SetText("关于 P5SUI / About P5SUI")
        ApplyPanelTheme("StylePanelTitle", title)

        local scroll = CreateFrame("ScrollFrame", "P5S_AboutScroll", panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -90)
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -48, 56)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(640, 1)
        scroll:SetScrollChild(content)

        -- 独立段落按实际文本高度排版，中文和英文均完整保留。
        local blocks = {
            {"title", "关于 P5SUI"},
            {"lead", "P5SUI — Persona 5 Strikers Inspired UI"},
            {"body", "P5SUI 是一款为《魔兽世界》制作的免费、非官方粉丝创作插件，旨在将《女神异闻录5 乱战：魅影攻手》（Persona 5 Strikers）的视觉风格与战斗界面体验带入《魔兽世界》。"},
            {"section", "开发信息"},
            {"lead", "创作者 / 项目维护：难刷素材的XZQ"},
            {"body", "由 |cffffffff难刷素材的XZQ|r 开发，负责界面设计、功能规划、游戏素材处理、测试及维护。"},
            {"body", "插件的功能系统、动画交互、职业适配、语音播放和设置界面均在 AI 辅助下开发完成，附加美术素材由 |cffffffff难刷素材的XZQ|r 自行绘制。"},
            {"section", "特别鸣谢"},
            {"lead", "OpenAI Codex"},
            {"body", "Codex 提供的代码编写、功能实现、调试与技术支持，让许多复杂的设计构想得以实现。"},
            {"lead", "ChatGPT"},
            {"body", "ChatGPT 提供的技术研究、功能规划、设计讨论与问题分析，帮助本项目从最初的构想逐步发展为完整的插件。"},
            {"section", "原作品与版权声明"},
            {"body", "本插件使用了以下作品中的部分原始游戏素材，包括界面贴图、角色美术、音效及语音等："},
            {"lead", "Persona 5 Strikers"},
            {"body", "©ATLUS ©SEGA / ©KOEI TECMO GAMES"},
            {"lead", "Persona 3 Reload"},
            {"body", "©ATLUS ©SEGA"},
            {"lead", "Persona Q: Shadow of the Labyrinth"},
            {"body", "©ATLUS ©SEGA"},
            {"body", "上述游戏的原始素材、角色、音频及相关知识产权均归其各自权利人所有。"},
            {"body", "P5SUI 是独立制作的免费、非官方粉丝项目，未获得上述游戏版权方的正式授权，也不代表 ATLUS、SEGA、KOEI TECMO GAMES、Blizzard Entertainment 或 OpenAI 的官方立场。"},
            {"lead", "感谢所有使用和支持 P5SUI 的玩家！"},
            {"title", "About P5SUI", "english"},
            {"lead", "P5SUI — Persona 5 Strikers Inspired UI"},
            {"body", "P5SUI is a free, unofficial fan-made addon for World of Warcraft, created to bring the distinctive visual style and combat interface experience of Persona 5 Strikers into World of Warcraft."},
            {"section", "Development"},
            {"lead", "Creator / Project Maintainer: 难刷素材的XZQ"},
            {"body", "This project was initiated and directed by 难刷素材的XZQ, including UI design, feature planning, game asset processing, testing, and maintenance."},
            {"body", "The addon's functionality, animations, class integrations, and configuration systems were developed with AI assistance. Additional original artwork was also created by 难刷素材的XZQ."},
            {"section", "Special Thanks"},
            {"lead", "OpenAI Codex"},
            {"body", "For providing invaluable assistance with code development, feature implementation, debugging, and technical challenges, helping bring complex design ideas to life."},
            {"lead", "ChatGPT"},
            {"body", "For supporting technical research, feature planning, design discussions, and problem-solving throughout development, helping transform the initial concept into a fully featured addon."},
            {"section", "Copyright & Disclaimer"},
            {"body", "This addon contains original game assets, including UI textures, character artwork, sound effects, and voice clips, derived from the following titles:"},
            {"lead", "Persona 5 Strikers"},
            {"body", "©ATLUS ©SEGA / ©KOEI TECMO GAMES"},
            {"lead", "Persona 3 Reload"},
            {"body", "©ATLUS ©SEGA"},
            {"lead", "Persona Q: Shadow of the Labyrinth"},
            {"body", "©ATLUS ©SEGA"},
            {"body", "All original game assets, characters, audio, and related intellectual property belong to their respective rights holders."},
            {"body", "P5SUI is an independently developed, free, unofficial fan project. It is not officially licensed, affiliated with, sponsored by, or endorsed by ATLUS, SEGA, KOEI TECMO GAMES, Blizzard Entertainment, or OpenAI."},
            {"lead", "Thank you to everyone who uses and supports P5SUI!"},
        }
        local offset, englishOffset = 4, 0
        for _, block in ipairs(blocks) do
            local kind, text = block[1], block[2]
            if block[3] == "english" then
                local divider = content:CreateTexture(nil, "ARTWORK")
                divider:SetColorTexture(0.82, 0.07, 0.05, 0.65)
                divider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset - 10)
                divider:SetSize(640, 1)
                offset = offset + 38
                englishOffset = offset
            elseif kind == "section" then
                offset = offset + 12
            end
            local textRegion = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            textRegion:SetFont(textRegion:GetFont(), kind == "title" and 22 or (kind == "section" and 16 or 14), "")
            textRegion:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
            textRegion:SetWidth(640)
            textRegion:SetJustifyH("LEFT")
            textRegion:SetJustifyV("TOP")
            textRegion:SetWordWrap(true)
            textRegion:SetSpacing(4)
            if kind == "section" then
                textRegion:SetTextColor(1, 0.30, 0.25)
            elseif kind == "body" then
                textRegion:SetTextColor(0.82, 0.84, 0.88)
            else
                textRegion:SetTextColor(0.96, 0.97, 1)
            end
            textRegion:SetText(text)
            offset = offset + textRegion:GetStringHeight() + (kind == "lead" and 8 or 16)
        end
        content:SetHeight(offset + 12)

        local function JumpTo(offsetY)
            scroll:SetVerticalScroll(math.min(offsetY, scroll:GetVerticalScrollRange()))
        end
        local chineseButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        chineseButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -52)
        chineseButton:SetSize(90, 26)
        chineseButton:SetText("中文")
        chineseButton:SetScript("OnClick", function() JumpTo(0) end)
        ApplyPanelTheme("StyleButton", chineseButton)
        local englishButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        englishButton:SetPoint("LEFT", chineseButton, "RIGHT", 10, 0)
        englishButton:SetSize(90, 26)
        englishButton:SetText("English")
        englishButton:SetScript("OnClick", function() JumpTo(englishOffset) end)
        ApplyPanelTheme("StyleButton", englishButton)

        local closeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        closeButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 16)
        closeButton:SetSize(100, 26)
        closeButton:SetText("关闭 / Close")
        closeButton:SetScript("OnClick", function() panel:Hide() end)
        ApplyPanelTheme("StyleButton", closeButton)
        panel:HookScript("OnShow", function(self)
            self:SetScale(math.min(1, UIParent:GetWidth() / 760, UIParent:GetHeight() / 720))
            scroll:SetVerticalScroll(0)
            self:Raise()
        end)
        table.insert(UISpecialFrames, "P5S_AboutPanel")
        return panel
    end

    aboutButton:SetScript("OnClick", function()
        if aboutFailed then return end
        local ok = pcall(function()
            local panel = aboutPanel or CreateAboutPanel()
            panel:Show()
            panel:Raise()
        end)
        if not ok then
            aboutFailed = true
            if aboutPanel then aboutPanel:Hide() end
            aboutButton:SetText("关于（不可用）")
            aboutButton:Disable()
        end
    end)
    OptionsPanel:HookScript("OnHide", function()
        if aboutPanel then aboutPanel:Hide() end
    end)
end

local function ApplyShowtimeSpellInput(inputText)
    inputText = TrimShowtimeText(inputText)

    if inputText == "" then
        P5S_UI_DB.showtimeSpellInput = ""
        P5S_UI_DB.showtimeSpellID = nil
        runtimeShowtimeSpellID = nil
        runtimeShowtimeSpellName = nil
        showtimeResolutionWarning = nil
        return true
    end

    local spellID, spellName = ResolveShowtimeSpellToken(inputText)
    if spellID then
        P5S_UI_DB.showtimeSpellInput = inputText
        P5S_UI_DB.showtimeSpellID = spellID
        runtimeShowtimeSpellID = spellID
        runtimeShowtimeSpellName = spellName or GetShowtimeSpellName(spellID)
        showtimeResolutionWarning = nil
        return true
    end

    if runtimeShowtimeSpellID then
        local spellName = runtimeShowtimeSpellName or "技能"
        showtimeResolutionWarning = string.format(
            "无法识别新输入；技能绑定未改变，仍使用 %s（%d）。",
            spellName,
            runtimeShowtimeSpellID
        )
    else
        showtimeResolutionWarning = "技能无法识别，技能绑定未保存；建议改用有效 Spell ID。"
    end
    return false
end

RefreshShowtimeOptionControls = function(force)
    if not P5S_UI_DB then return end
    P5SFrame.firePreview:RefreshControl()
    if force or not showtimeSpellInput:HasFocus() then
        showtimeSpellInput:SetText(P5S_UI_DB.showtimeSpellInput or "")
    end
    if force or not showtimeBurstInput:HasFocus() then
        showtimeBurstInput:SetText(FormatShowtimeSeconds(P5S_UI_DB.showtimeBurstDuration))
    end
    if force or not showtimeCooldownInput:HasFocus() then
        showtimeCooldownInput:SetText(FormatShowtimeSeconds(P5S_UI_DB.showtimeCooldownDuration))
    end
    RefreshShowtimeStatusText()
end

CommitShowtimeOptions = function(silent)
    if not P5S_UI_DB then return false end
    -- 回车后的失焦、关闭和预览可能连续提交；无编辑时不重复解析或重置周期。
    if showtimeSpellInput:GetText() == (P5S_UI_DB.showtimeSpellInput or "")
        and showtimeBurstInput:GetText() == FormatShowtimeSeconds(P5S_UI_DB.showtimeBurstDuration)
        and showtimeCooldownInput:GetText() == FormatShowtimeSeconds(P5S_UI_DB.showtimeCooldownDuration)
    then
        return true
    end

    local oldEnabled = P5S_UI_DB.showtimeEnabled and true or false
    local oldSpellID = runtimeShowtimeSpellID
    local oldBurstDuration = P5S_UI_DB.showtimeBurstDuration
    local oldCooldownDuration = P5S_UI_DB.showtimeCooldownDuration

    local burstDuration = GetValidatedShowtimeSeconds(showtimeBurstInput:GetText(), oldBurstDuration or 15)
    local cooldownDuration = GetValidatedShowtimeSeconds(showtimeCooldownInput:GetText(), oldCooldownDuration or 120)
    if cooldownDuration < burstDuration then cooldownDuration = burstDuration end
    local inputText = TrimShowtimeText(showtimeSpellInput:GetText())

    P5S_UI_DB.showtimeBurstDuration = burstDuration
    P5S_UI_DB.showtimeCooldownDuration = cooldownDuration
    local resolved = true
    if inputText ~= (P5S_UI_DB.showtimeSpellInput or "") or not runtimeShowtimeSpellID then
        resolved = ApplyShowtimeSpellInput(inputText)
    end
    local enabled = runtimeShowtimeSpellID ~= nil
    P5S_UI_DB.showtimeEnabled = enabled

    local changed = oldEnabled ~= enabled
        or oldSpellID ~= runtimeShowtimeSpellID
        or oldBurstDuration ~= burstDuration
        or oldCooldownDuration ~= cooldownDuration

    if changed then
        ResetShowtimeForConfiguration()
    else
        RefreshShowtimeStatusText()
    end
    RefreshShowtimeOptionControls(true)

    if not silent then
        if resolved and runtimeShowtimeSpellID then
            local spellName = runtimeShowtimeSpellName or "技能"
            print(string.format("|cffFF3333[P5S UI]|r Showtime 已绑定：%s（%d）。", spellName, runtimeShowtimeSpellID))
        elseif resolved then
            print("|cffffcc00[P5S UI]|r Showtime 技能已清空。")
        else
            print("|cffffcc00[P5S UI]|r " .. (showtimeResolutionWarning or "技能无法识别。"))
        end
    end
    return resolved
end

OptionsPanel:HookScript("OnShow", function()
    -- 放大后的面板在较小 UI 尺寸下等比缩小，保留所有底部控件。
    OptionsPanel:SetScale(math.min(1, UIParent:GetWidth() / 740, UIParent:GetHeight() / 860))
    P5SFrame:ApplyResourceBarVisibility()
    P5SFrame.thirdResource:RefreshOptionControls()
    if RefreshShowtimeOptionControls then RefreshShowtimeOptionControls() end
end)

-- ==========================================
-- 6. 初始化数据库
-- ==========================================
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("SPELLS_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= "P5S" then return end

        if not P5S_UI_DB then P5S_UI_DB = {} end

        -- 数据初始化防崩垫底保护
        if P5S_UI_DB.size == nil then P5S_UI_DB.size = 400 end
        if P5S_UI_DB.point == nil then P5S_UI_DB.point = "CENTER" end
        if P5S_UI_DB.relativePoint == nil then P5S_UI_DB.relativePoint = "CENTER" end
        if P5S_UI_DB.xOfs == nil then P5S_UI_DB.xOfs = 0 end
        if P5S_UI_DB.yOfs == nil then P5S_UI_DB.yOfs = 0 end
        if P5S_UI_DB.isLocked == nil then P5S_UI_DB.isLocked = false end
        if type(P5S_UI_DB.resourceBarEnabled) ~= "boolean" then
            P5S_UI_DB.resourceBarEnabled = true
        end
        if type(P5S_UI_DB.thirdResourceEnabled) ~= "boolean" then
            P5S_UI_DB.thirdResourceEnabled = true
        end
        if type(P5S_UI_DB.thirdResourceStyle) ~= "string"
            or not P5SFrame.thirdResource.styles[P5S_UI_DB.thirdResourceStyle] then
            P5S_UI_DB.thirdResourceStyle = "A"
        end

        if P5S_UI_DB.combatIndicatorEnabled == nil then P5S_UI_DB.combatIndicatorEnabled = true end
        if P5S_UI_DB.combatIconState == nil then P5S_UI_DB.combatIconState = 7 end
        if P5S_UI_DB.outOfCombatIndicatorEnabled == nil then P5S_UI_DB.outOfCombatIndicatorEnabled = false end
        if P5S_UI_DB.outOfCombatIconState == nil then P5S_UI_DB.outOfCombatIconState = 15 end
        indicatorSection:RefreshMode()

        -- 保留旧呼吸灯字段及其原有含义，避免破坏已有角色级配置。
        if P5S_UI_DB.stBreathEnabled == nil then P5S_UI_DB.stBreathEnabled = true end
        if P5S_UI_DB.stBreathMode == nil then P5S_UI_DB.stBreathMode = 1 end
        if P5S_UI_DB.stBreathMax == nil then P5S_UI_DB.stBreathMax = 1.0 end
        if P5S_UI_DB.stBreathMin == nil then P5S_UI_DB.stBreathMin = 0.5 end
        if P5S_UI_DB.stBreathDur == nil then P5S_UI_DB.stBreathDur = 1.0 end

        -- Showtime 爆发槽使用独立字段；总冷却从成功施放时开始计算。
        -- showtimeEnabled 保留兼容字段，由下方技能解析结果自动同步。
        if type(P5S_UI_DB.showtimeFireEnabled) ~= "boolean" then P5S_UI_DB.showtimeFireEnabled = true end
        if type(P5S_UI_DB.showtimeSpellInput) ~= "string" then P5S_UI_DB.showtimeSpellInput = "" end
        if P5S_UI_DB.showtimeBurstDuration == nil then P5S_UI_DB.showtimeBurstDuration = 15 end
        if P5S_UI_DB.showtimeCooldownDuration == nil then P5S_UI_DB.showtimeCooldownDuration = 120 end
        P5S_UI_DB.showtimeBurstDuration = GetValidatedShowtimeSeconds(P5S_UI_DB.showtimeBurstDuration, 15)
        P5S_UI_DB.showtimeCooldownDuration = GetValidatedShowtimeSeconds(P5S_UI_DB.showtimeCooldownDuration, 120)
        if P5S_UI_DB.showtimeCooldownDuration < P5S_UI_DB.showtimeBurstDuration then
            P5S_UI_DB.showtimeCooldownDuration = P5S_UI_DB.showtimeBurstDuration
        end
        if tonumber(P5S_UI_DB.showtimeSpellID) then
            P5S_UI_DB.showtimeSpellID = math.floor(tonumber(P5S_UI_DB.showtimeSpellID))
        else
            P5S_UI_DB.showtimeSpellID = nil
        end
        P5S_UI_DB.showtimeVersion = 1

        -- 平滑过渡
        if not P5S_UI_DB.v2 then
            if P5S_UI_DB.combatIconState == 8 then P5S_UI_DB.combatIconState = 15 end
            if P5S_UI_DB.outOfCombatIconState == 8 then P5S_UI_DB.outOfCombatIconState = 15 end
            P5S_UI_DB.v2 = true
        end

        -- UI 层数据投射
        P5SFrame:SetScale(P5S_UI_DB.size / BASE_SIZE)
        slider:SetValue(P5S_UI_DB.size)
        P5SFrame:ClearAllPoints()
        P5SFrame:SetPoint(P5S_UI_DB.point, UIParent, P5S_UI_DB.relativePoint, P5S_UI_DB.xOfs, P5S_UI_DB.yOfs)
        lockCheck:SetChecked(P5S_UI_DB.isLocked)
        P5SFrame:ApplyResourceBarVisibility()
        P5SFrame.thirdResource:ApplyStyle(P5S_UI_DB.thirdResourceStyle)
        P5SFrame.thirdResource:RefreshOptionControls()

        combatCheck:SetChecked(P5S_UI_DB.combatIndicatorEnabled)
        UIDropDownMenu_SetSelectedValue(combatDropdown, P5S_UI_DB.combatIconState)
        UIDropDownMenu_SetText(combatDropdown, stateOptions[P5S_UI_DB.combatIconState])

        oocCheck:SetChecked(P5S_UI_DB.outOfCombatIndicatorEnabled)
        UIDropDownMenu_SetSelectedValue(oocDropdown, P5S_UI_DB.outOfCombatIconState)
        UIDropDownMenu_SetText(oocDropdown, stateOptions[P5S_UI_DB.outOfCombatIconState])

        InitializeShowtimeRenderer()
        ResolveSavedShowtimeSpell()
        RefreshShowtimeOptionControls()
        RestoreShowtimeCycle()
        UpdateCombatIcons()
        return
    end

    if not P5S_UI_DB then return end

    if event == "PLAYER_LOGIN" then
        local previousSpellID = runtimeShowtimeSpellID
        RebuildShowtimeSpellBookNameCache()
        ResolveSavedShowtimeSpell()
        if previousSpellID ~= runtimeShowtimeSpellID then
            RestoreShowtimeCycle()
        elseif runtimeShowtimeSpellID
            and not showtimeState.preview
            and (showtimeState.phase == SHOWTIME_PHASE_BURST or showtimeState.phase == SHOWTIME_PHASE_RECOVERY)
        then
            -- ADDON_LOADED 时冷却数据可能尚未就绪；登录完成后为恢复中的周期重挂一次。
            ArmShowtimeCooldownWatcher(runtimeShowtimeSpellID, showtimeState.generation)
        end
        RefreshShowtimeOptionControls()
        return
    end

    if event == "SPELLS_CHANGED" then
        if InCombatLockdown and InCombatLockdown() then
            showtimePendingSpellBookCacheRebuild = true
            return
        end

        local previousSpellID = runtimeShowtimeSpellID
        RebuildShowtimeSpellBookNameCache()
        ResolveSavedShowtimeSpell()
        if previousSpellID ~= runtimeShowtimeSpellID then
            ResetShowtimeForConfiguration()
        end
        RefreshShowtimeOptionControls()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and showtimePendingSpellBookCacheRebuild then
        local previousSpellID = runtimeShowtimeSpellID
        RebuildShowtimeSpellBookNameCache()
        ResolveSavedShowtimeSpell()
        if previousSpellID ~= runtimeShowtimeSpellID then
            ResetShowtimeForConfiguration()
        end
        RefreshShowtimeOptionControls()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        -- 战斗触发只比较事件直接提供的玩家 spellID，不读取 Aura、Buff 或冷却数值。
        if unit == "player"
            and P5S_UI_DB.showtimeEnabled
            and runtimeShowtimeSpellID
            and spellID == runtimeShowtimeSpellID
        then
            StartShowtimeCycle(false)
        end
        return
    end

    if event == "SPELL_UPDATE_COOLDOWN" then
        -- 只读取 C_Spell.GetSpellCooldown 中明确可安全使用的布尔状态。
        -- 数字冷却受限时，径向动画继续按用户填写的总冷却运行。
        RefreshReducedShowtimeCooldownWatcher()
    end
end)

