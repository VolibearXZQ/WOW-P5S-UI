local _, addon = ...

-- Lua 只处理用户配置。Aura 匹配、优先级和补位全部留在原生控件内。
local layout = addon.BuffIndicatorLayout
local MEDIA = "Interface\\AddOns\\P5S\\P5S_UI\\Media\\"
local runtime = {}
addon.BuffRuntime = runtime
local host
local positions, priorities = {}, {}
local attempted, failed, pending, applied = false, false, false, false
local status = "尚未应用分组。"

local function Filters(ids) return { includeSpellIDs = ids } end

local function Flow(container)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutPadding(0, 0, 0, 0)
    container:SetFlowLayoutMaximumLineSize(math.huge)
end

local function Group(container, key, ids, index, width, height, initialize)
    local initializationFailed = false
    container:AddAuraGroup(key, "HELPFUL", {
        candidateFilters = Filters(ids), maxFrameCount = 1,
        layout = { layoutIndex = index, elementWidth = width, elementHeight = height,
            elementSpacing = 0, groupSpacing = 0, forceNewLine = false },
        initializeFrame = function(button)
            local ok = pcall(initialize, button)
            if not ok then initializationFailed = true end
        end,
    })
    assert(not initializationFailed)
end

local function Initialize()
    if attempted then return not failed end
    attempted = true
    local ok = pcall(function()
        assert(layout and type(AuraContainerInbound) == "table")
        host = CreateFrame("Frame", nil, layout.parent)
        host:SetAllPoints(layout.parent)
        host:EnableMouse(false)
        host:Hide()
        for index, definition in ipairs(layout.groups) do
            local category = definition
            local position = CreateFrame("AuraContainer", nil, host, "CustomAuraContainerTemplate")
            positions[index] = position
            position:EnableMouse(false)
            -- 原来的第 i 类位置减去前方所有格数。原生宽度再补回实际存在的前方类别。
            -- 只建立锚点，不读取容器宽度、坐标或显示结果。现有 SLOT_SHIFT_Y 为 0。
            position:SetPoint("TOPLEFT", host, "CENTER", category.x - (index - 1) * layout.shiftX, category.y)
            position:SetSize(0, 1)
            Flow(position)
            for previous = 1, index - 1 do
                Group(position, layout.groups[previous].key, {}, previous, layout.shiftX, 1,
                    function(button) button:SetSize(layout.shiftX, 1); button:EnableMouse(false) end)
            end
            local initializationFailed = false
            position:AddAuraSlot("category", "HELPFUL", {
                candidateFilters = Filters({}),
                templateNames = { "DisableUntrustedLayoutScriptsTemplate" },
                initializeFrame = function(button)
                    -- 原生回调可能安全隔离错误，因此单独记录初始化失败，不能当作 Aura 状态。
                    local initialized = pcall(function()
                        button:SetSize(category.width, category.height)
                        button:SetPoint("CENTER", position, "TOPRIGHT", 0, 0)
                        button:EnableMouse(false)
                        button:SetClipsChildren(true)
                        local priority = CreateFrame("AuraContainer", nil, button, "CustomAuraContainerTemplate")
                        priorities[index] = priority
                        priority:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
                        priority:EnableMouse(false)
                        Flow(priority)
                        for rank, level in ipairs({ "large", "small" }) do
                            local asset = MEDIA .. category.text .. (level == "large" and "大提升.tga" or "小提升.tga")
                            Group(priority, level, {}, rank, category.width, category.height, function(icon)
                                icon:SetSize(category.width, category.height)
                                icon:EnableMouse(false)
                                local texture = icon:CreateTexture(nil, "OVERLAY")
                                texture:SetAllPoints(icon)
                                texture:SetTexture(asset)
                            end)
                        end
                        priority:SetUnit("player")
                        priority:Show()
                    end)
                    if not initialized then initializationFailed = true end
                end,
            })
            assert(not initializationFailed and priorities[index])
            position:SetUnit("player")
            position:Show()
        end
    end)
    failed = not ok
    if failed then
        if host then host:Hide() end
        status = "Buff 显示初始化失败；本次加载已停用，请 /reload 后重试。"
    end
    return ok
end

function runtime.RefreshVisibility()
    if host then
        if applied and not failed and P5S_UI_DB and P5S_UI_DB.indicatorMode == "buff" then
            host:Show()
        else host:Hide() end
    end
end

function runtime.Apply()
    if InCombatLockdown() then
        pending = true
        status = "已保存；脱战后应用分组，当前继续使用上次有效分组。"
        runtime.RefreshVisibility()
        return false
    end
    pending = false
    local config, errorText = addon.BuffOptions.GetConfig()
    if not config then
        status = errorText .. " 当前保留上次有效分组。"
        return false
    end
    if not Initialize() then return false end
    -- 复用原生容器及池；编辑配置不会不断创建新控件。
    local ok = pcall(function()
        host:Hide()
        for index, category in ipairs(layout.groups) do
            local group = config[category.key]
            for previous = 1, index - 1 do
                local key = layout.groups[previous].key
                positions[index]:SetAuraGroupCandidateFilters(key, Filters(config[key].all))
            end
            positions[index]:SetAuraSlotCandidateFilters("category", Filters(group.all))
            priorities[index]:SetAuraGroupCandidateFilters("large", Filters(group.large))
            priorities[index]:SetAuraGroupCandidateFilters("small", Filters(group.small))
        end
    end)
    if not ok then
        failed = true
        host:Hide()
        status = "Buff 分组应用失败；本次加载已停用，请 /reload 后重试。"
        return false
    end
    applied = true
    status = "分组已应用；同类大提升优先。请在主面板选择自身 Buff 监控。"
    runtime.RefreshVisibility()
    return true
end

function runtime.GetStatus() return status end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or pending then
        runtime.Apply()
        if addon.BuffOptions.RefreshRuntimeStatus then addon.BuffOptions.RefreshRuntimeStatus() end
    end
end)
