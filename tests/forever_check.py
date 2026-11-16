"""Run from the repository root with Python + lupa (Lua 5.1).

Exercises real addon functions with synthetic public/secret API results.
This does not replace testing the client renderer, event order or taint.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path.cwd()
lua = LuaRuntime(unpack_returned_tuples=True)
read = lambda p: (root / p).read_text(encoding="utf-8-sig")
load = lua.eval("function(s, env) local f,e=loadstring(s); assert(f,e); setfenv(f,env); return f end")
for line in read("P5S.toc").splitlines():
    if line.strip().endswith(".lua"):
        lua.execute("assert(loadstring(...))", read(line.strip().replace("\\", "/")))
print("All loaded files compile as Lua 5.1")

lua.execute(r'''
checks = 0
function check(ok, label) assert(ok, label); checks = checks + 1 end
function environment(forever)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.secret = newproxy(true)
    local mt = getmetatable(env.secret)
    for _, key in ipairs({'__lt','__le','__add','__sub','__mul','__div','__tostring'}) do
        mt[key] = function() error('secret used') end
    end
    env.issecretvalue = function(v) return rawequal(v, env.secret) end
    env.InCombatLockdown = function() return env.combat or false end
    env.WOW_PROJECT_CAMELOT = 18
    env.WOW_PROJECT_ID = forever and 18 or 1
    env.GetBuildInfo = function() return 'test','70938','date',forever and 16001 or 120105 end
    env.Enum = { SpellBookSpellBank = {Player = 0}, PowerType = {ComboPoints=4, Energy=3} }
    env.books = {{spellID=101,name='Ranked'}, {spellID=202,name='Ranked'}, {spellID=303,name='Single'}}
    env.highest = 202
    env.rankCalls = 0
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() assert(not env.combat); return 1 end,
        GetSpellBookSkillLineInfo = function() assert(not env.combat); return {itemIndexOffset=0,numSpellBookItems=#env.books} end,
        GetSpellBookItemInfo = function(slot) assert(not env.combat); return env.books[slot] end,
        IsSpellBookItemLowRank = function(slot)
            assert(not env.combat); env.rankCalls=env.rankCalls+1
            if env.rankError then error('rank failed') end
            if env.rankSecret then return env.secret end
            return env.books[slot].name=='Ranked' and env.books[slot].spellID~=env.highest
        end,
    }
    env.C_Spell = {GetSpellInfo = function(id)
        assert(not env.combat)
        for _, spell in ipairs(env.books) do
            if spell.spellID==id then return {spellID=id,name=spell.name} end
        end
        return nil
    end}
    env.GetComboPoints = function(unit, target)
        check(unit=='player' and target=='target','combo units')
        if env.comboError then error('combo failed') end
        return env.combo
    end
    return env
end
''')

def setup(forever):
    env = lua.globals().environment(forever)
    addon = lua.table()
    load(read("P5S_UI/Compat.lua"), env)("P5S", addon)
    env.addon = addon
    return env, addon

for forever in (False, True):
    env, addon = setup(forever)
    lua.globals().env, lua.globals().addon = env, addon
    lua.execute(r'''
        check(addon.Compat.IsForever==(env.WOW_PROJECT_ID==18),'client detection')
        local c=addon.Compat
        if c.IsForever then
            check(not c.UseSpellBookItem(1,0) and c.UseSpellBookItem(2,0),'rank selection')
            env.rankSecret=true; check(not c.UseSpellBookItem(2,0),'secret rank rejected'); env.rankSecret=false
            env.rankError=true; check(not c.UseSpellBookItem(2,0),'rank exception rejected'); env.rankError=false
            env.combat=true; local calls=env.rankCalls
            check(not c.UseSpellBookItem(2,0) and env.rankCalls==calls,'no combat rank query'); env.combat=false
        else
            env.combat=true
            check(c.UseSpellBookItem(1,0) and env.rankCalls==0,'retail unchanged'); env.combat=false
        end
        env.combo=3; local ok,value=c.ReadTargetComboPoints(); check(ok and value==3,'public combo')
        env.combo=env.secret; check(not c.ReadTargetComboPoints(),'secret combo rejected')
        env.combo=0/0; check(not c.ReadTargetComboPoints(),'NaN rejected')
        env.combo=math.huge; check(not c.ReadTargetComboPoints(),'infinity rejected')
        local checker=env.issecretvalue; env.issecretvalue=nil; env.combo=3
        check(not c.ReadTargetComboPoints(),'missing checker rejected'); env.issecretvalue=checker
        env.comboError=true; check(not c.ReadTargetComboPoints(),'combo error rejected'); env.comboError=false
        env.GetComboPoints=function() error('must not retry failed API') end
        check(not c.ReadTargetComboPoints(),'API failure latched until reload')
    ''')

env, addon = setup(False)
env.WOW_PROJECT_CAMELOT = None
env.GetBuildInfo = lua.eval("function() return '1.60.1','70938','date',16001 end")
load(read("P5S_UI/Compat.lua"), env)("P5S", addon)
assert addon.Compat.IsForever

# Execute the actual four parsers, not a separate implementation of the parser.
parsers = [
    ("P5S_UI/core.lua", "local function ClampShowtimePercent", "local function RefreshShowtimeStatusText", "local showtimeSpellNameToID={}\n", "RebuildShowtimeSpellBookNameCache", "ResolveShowtimeSpellToken"),
    ("P5_Nameplate/Core.lua", "local function TrimP5Text", "local function BuildP5SpellIDMap", "", "RebuildP5SpellBookNameCache", "ResolveP5SpellToken"),
    ("P5_Voice/Voice.lua", "local function TrimText", "local function BuildSpellIDMap", "local spellNameToID={}\n", "RebuildSpellBookNameCache", "ResolveSpellInput"),
]
for forever in (False, True):
    for path, start, end, prefix, rebuild, resolve in parsers:
        env, addon = setup(forever)
        source = read(path).split(start,1)[1].split(end,1)[0]
        api = load(prefix+start+source+f"\nreturn {{rebuild={rebuild},resolve={resolve}}}",env)()
        api.rebuild()
        assert api.resolve("Ranked")[0] == (202 if forever else 101), path
        assert api.resolve("101")[0] == 101, path
        assert api.resolve("|Hspell:101:0|h[Ranked]|h")[0] == 101, path
        env.combat = True
        calls = env.rankCalls
        api.rebuild()
        assert env.rankCalls == calls and api.resolve("Ranked")[0] == (202 if forever else 101)
        env.combat = False
        if forever:
            env.books[4] = lua.table(spellID=404,name="Ranked")
            env.highest = 404
            api.rebuild()
            assert api.resolve("Ranked")[0] == 404, path
    env, addon = setup(forever)
    lua.globals().env, lua.globals().addon = env, addon
    lua.execute(r'''
        env.P5S_UI_DB={weakJokerSpellInput='Ranked'}
        env.settings={}
        addon.WeakOptions={GetSettings=function() return env.settings end,SetBindingStatus=function(_,s) env.status=s end}
    ''')
    source = read("P5S_UI/WeakRuntime.lua").split("local function SetVisual",1)[0]
    api = load(source+"\nreturn {rebuild=RebuildBook,resolve=runtime.ResolveBinding,ids=function() return bindings.joker end}",env)("P5S",addon)
    api.rebuild(); api.resolve("joker")
    assert api.ids()[202]  # Original Weak resolver kept the last entry; Forever explicitly filters.
    env.P5S_UI_DB.weakJokerSpellInput = "101"
    api.resolve("joker"); assert api.ids()[101]
    env.P5S_UI_DB.weakJokerSpellInput = "Ranked"
    api.resolve("joker"); env.combat=True
    api.rebuild(); api.resolve("joker"); assert api.ids()[202]
    env.combat=False
    if forever:
        env.books[4]=lua.table(spellID=404,name="Ranked"); env.highest=404
        api.rebuild(); api.resolve("joker"); assert api.ids()[404]
print("Four spell parsers: rank ordering, explicit IDs/links, learning and combat deferral passed")

# Execute the real third-resource Update block with controlled renderer methods.
core = read("P5S_UI/core.lua")
config = core.split("    resource.byClass = {",1)[1].split("    resource.getPlayerSpecialization",1)[0]
update = "    function resource:Update()"+core.split("    function resource:Update()",1)[1].split("\nend\n\nlocal PlayerEvents",1)[0]
for forever in (False,True):
    env, addon = setup(forever)
    env.Enum.PowerType.Runes=5; env.Enum.PowerType.ArcaneCharges=16
    env.Enum.PowerType.Chi=12; env.Enum.PowerType.HolyPower=9
    env.Enum.PowerType.SoulShards=7; env.Enum.PowerType.Essence=19
    lua.globals().env = env
    lua.execute(r'''
        env.resource={}
        env.currentClass='ROGUE'; env.currentSpec=103; env.power=2; env.combo=4; env.maxPower=5; env.powerType=3
        env.UnitPowerMax=function() return env.maxPower end
        env.UnitPower=function() return env.power end
        env.UnitPowerType=function() return env.powerType end
        function env.resource:GetPlayerClassFilename() return env.currentClass end
        function env.resource:GetCurrentSpecID() return env.currentSpec end
        function env.resource:IsSafeNumber(v) return not env.issecretvalue(v) and type(v)=='number' and v==v end
        function env.resource:Hide() self.hidden=true; self.value=nil end
        function env.resource:ShowValue(maximum,value) self.hidden=false; self.value=value; self.maximum=maximum end
        function env.resource:ShowRunes() self.runes=true end
    ''')
    load("local resource=resource\nresource.byClass = {"+config+update,env)()
    r=env.resource
    r.Update(r); assert r.value==(4 if forever else 2)
    env.currentClass="DRUID"; env.currentSpec=1484
    r.Update(r); assert (r.value==4 if forever else r.hidden)
    env.currentSpec=103; env.powerType=1
    r.Update(r); assert r.hidden
    env.powerType=3; env.currentClass="ROGUE"; env.combo=env.secret
    r.Update(r); assert (r.hidden if forever else r.value==2)
    env.combo=0; r.Update(r); assert r.value==(0 if forever else 2)
    if forever:
        for cls in ("MAGE","PALADIN","WARLOCK","WARRIOR","PRIEST","HUNTER","SHAMAN"):
            env.currentClass=cls; r.Update(r); assert r.hidden,cls
print("Retail/Forever resource paths, druid form, target count and secret fallback passed")

# Real event handler: transfer events have no unit token and must not fall through
# to unrelated unit/health comparisons or queries.
events="local PlayerEvents"+core.split("local PlayerEvents",1)[1].split("-- 5. 创建设置面板",1)[0]
for forever in (False,True):
    env,addon=setup(forever)
    lua.globals().env=env
    lua.execute(r'''
        env.updates=0
        env.P5SFrame={thirdResource={Update=function() env.updates=env.updates+1 end}}
        env.CreateFrame=function()
            return {events={},RegisterEvent=function(self,e) self.events[e]=true end,
                RegisterUnitEvent=function() end,SetScript=function(self,_,callback) self.callback=callback end}
        end
        env.C_CurveUtil={CreateCurve=function() return {SetType=function() end,AddPoint=function() end} end}
        env.Enum.LuaCurveType={Linear=1}
    ''')
    frame=load(events+"\nreturn PlayerEvents",env)()
    assert bool(frame.events.COMBO_TARGET_CHANGED)==forever
    if forever:
        frame.callback(frame,"COMBO_TARGET_CHANGED",env.secret,env.secret)
        assert env.updates==1
        frame.callback(frame,"PLAYER_TARGET_CHANGED")
        assert env.updates==2
print("Target change/transfer event registration and early return passed")

for forever in (False,True):
    env, addon = setup(forever)
    source=read("P5S_UI/BuffOptions.lua").split("local BUFF_BY_CAST",1)[0]
    known=load(source+"\nreturn knownBuffs",env)("P5S",addon)
    assert len(known)==(0 if forever else 7)
    env.P5S_UI_DB=lua.table()
    env.Enum.CooldownViewerCategory=lua.table(Essential=0)
    env.books[2].name="Higher"
    env.C_CooldownViewer=lua.eval("function() return {GetCooldownViewerCategorySet=function() return {1} end, GetCooldownViewerCooldownInfo=function() return {spellID=101,displaySpellID=202} end} end")()
    source=read("P5S_UI/BuffOptions.lua").split("local function ParseIDs",1)[0]
    catalog=load(source+"\nreturn CatalogName",env)("P5S",addon)
    entry=catalog("Higher")
    assert (entry.id==202 if forever else entry is None)
print("Retail Buff presets isolated; compat assertions:",lua.globals().checks)
