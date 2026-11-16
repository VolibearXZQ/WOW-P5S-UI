local _, addon = ...

-- Client identity is static. Never infer permission to inspect combat values from it.
local compat = {}
addon.Compat = compat
compat.IsForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
if not compat.IsForever and type(GetBuildInfo) == "function" then
    local ok, _, _, _, interface = pcall(GetBuildInfo)
    compat.IsForever = ok and interface == 16001
end

local function Public(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == false
end

-- Forever retains spell ranks. A bare name binds the highest learned rank;
-- explicit Spell IDs and links still bind exactly the rank the user entered.
-- Called only while rebuilding the existing out-of-combat spellbook caches.
function compat.UseSpellBookItem(slot, bank)
    if not compat.IsForever then return true end
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    if not ok or not Public(combat) or combat ~= false then return false end
    local method = C_SpellBook and C_SpellBook.IsSpellBookItemLowRank
    if type(method) ~= "function" then return false end
    local valid, lowRank = pcall(method, slot, bank)
    return valid and Public(lowRank) and lowRank == false
end

-- Follow Blizzard's Camelot TargetBoundComboPointBar. Do not perform arithmetic
-- or comparisons on the returned count until it has passed Secret Value checks.
local comboUnavailable = false
function compat.ReadTargetComboPoints()
    if comboUnavailable then return false end
    if type(GetComboPoints) ~= "function" then comboUnavailable = true; return false end
    local ok, value = pcall(GetComboPoints, "player", "target")
    if not ok then comboUnavailable = true; return false end
    if not Public(value) or type(value) ~= "number" then return false end
    if value ~= value or value == math.huge or value == -math.huge or value < 0 then return false end
    return true, value
end
