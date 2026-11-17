local frame = P5S_MainFrame
if not frame then return end

-- Keep the secure mouse surface independent: protecting the artwork's parent
-- would also restrict its animated children during combat.
local button = CreateFrame("Button", "P5S_PlayerButton", UIParent, "SecureUnitButtonTemplate")
button:Hide()
button:SetAttribute("unit", "player")
button:SetAttribute("*type1", "target")
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")
button:SetSize(frame:GetSize())
button:SetHitRectInsets(frame:GetHitRectInsets())

local dragging = false
local function Sync()
    if InCombatLockdown() or dragging or not P5S_UI_DB then return end
    button:SetScale(frame:GetScale())
    button:SetFrameStrata(frame:GetFrameStrata())
    button:SetFrameLevel(frame:GetFrameLevel() + 20)
    button:ClearAllPoints()
    local point, _, relativePoint, x, y = frame:GetPoint()
    if not point then return end
    button:SetPoint(point, UIParent, relativePoint, x, y)
    button:SetShown(P5S_UI_DB.resourceBarEnabled ~= false)
end

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint()
    P5S_UI_DB.point, P5S_UI_DB.relativePoint = point, relativePoint
    P5S_UI_DB.xOfs, P5S_UI_DB.yOfs = x, y
end

local function StopDrag()
    if not dragging then return end
    frame:StopMovingOrSizing()
    SavePosition()
    dragging = false
    Sync()
end

button:SetScript("OnDragStart", function(self)
    if InCombatLockdown() or not P5S_UI_DB or P5S_UI_DB.isLocked then return end
    dragging = true
    GameTooltip:Hide()
    frame:StartMoving()
end)
button:SetScript("OnDragStop", function()
    if not InCombatLockdown() then StopDrag() end
end)
button:SetScript("OnEnter", function(self)
    if dragging then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetUnit("player")
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)
button:HookScript("OnHide", function(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)

hooksecurefunc(frame, "SetPoint", Sync)
hooksecurefunc(frame, "SetScale", Sync)
hooksecurefunc(frame, "ApplyResourceBarVisibility", Sync)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" and dragging then
        -- The secure surface stays at its last committed location while moving.
        -- If combat interrupts a drag, restore artwork there without touching it.
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = button:GetPoint()
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relativePoint, x, y)
        SavePosition()
        dragging = false
    end
    if InCombatLockdown() then return end
    StopDrag()
    if P5S_UI_DB then
        frame:SetScale(P5S_UI_DB.size / 400)
        frame:ApplyResourceBarVisibility()
    end
    Sync()
end)
Sync()
