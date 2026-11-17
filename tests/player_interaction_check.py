"""Lua 5.1 contract tests. Native targeting, rendering and taint need in-game tests."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
combat = false
InCombatLockdown = function() return combat end
UIParent = {}
P5S_UI_DB = {size=400, point='CENTER',relativePoint='CENTER',xOfs=10,yOfs=20}
local methods = {}
local function protected(self) assert(not self.secure or not combat, 'protected mutation in combat') end
function methods:Hide() protected(self); self.shown=false end
function methods:SetShown(value) protected(self); self.shown=value end
function methods:SetAttribute(key,value) protected(self); self.attrs[key]=value end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:RegisterForDrag(...) self.drags={...} end
function methods:SetSize(...) protected(self); self.size={...} end
function methods:GetSize() return unpack(self.size) end
function methods:SetHitRectInsets(...) protected(self); self.insets={...} end
function methods:GetHitRectInsets() return unpack(self.insets) end
function methods:SetScale(scale) protected(self); self.scale=scale end
function methods:GetScale() return self.scale end
function methods:SetFrameStrata(value) protected(self); self.strata=value end
function methods:GetFrameStrata() return self.strata end
function methods:SetFrameLevel(value) protected(self); self.level=value end
function methods:GetFrameLevel() return self.level end
function methods:ClearAllPoints() protected(self); self.point=nil end
function methods:SetPoint(...) protected(self); self.point={...} end
function methods:GetPoint() if self.point then return unpack(self.point) end end
function methods:SetScript(key,value) self.scripts[key]=value end
function methods:HookScript(key,value) self.scripts[key]=value end
function methods:RegisterEvent(key) self.events[key]=true end
function methods:StartMoving() protected(self); self.moving=true end
function methods:StopMovingOrSizing() protected(self); self.moving=false end
function methods:ApplyResourceBarVisibility() if not combat then self.visible=P5S_UI_DB.resourceBarEnabled~=false end end
function hooksecurefunc(obj, key, hook)
 local old=obj[key]; obj[key]=function(self,...) old(self,...); hook(self,...) end
end
frames={}
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({scripts={},attrs={},events={},secure=template~=nil,parent=parent,template=template}, {__index=methods})
 if name then _G[name]=f end
 table.insert(frames,f); return f
end
P5S_MainFrame=CreateFrame('Frame','P5S_MainFrame',UIParent)
local f=P5S_MainFrame
f:SetSize(400,400); f:SetHitRectInsets(40,180,150,100)
f:SetScale(1); f:SetFrameStrata('MEDIUM'); f:SetFrameLevel(1)
f:SetPoint('CENTER',UIParent,'CENTER',10,20)
GameTooltip={SetOwner=function(self,owner) self.owner=owner end,
 SetUnit=function(self,unit) self.unit=unit end, Show=function(self) self.shown=true end,
 Hide=function(self) self.shown=false end, IsOwned=function(self,owner) return self.owner==owner end}
''')
lua.execute(Path('P5S_UI/PlayerInteraction.lua').read_text(encoding='utf-8-sig'))
lua.execute(r'''
local b,f=P5S_PlayerButton,P5S_MainFrame
local events=frames[#frames]
assert(b.parent==UIParent and b.template=='SecureUnitButtonTemplate')
assert(b.attrs.unit=='player' and b.attrs['*type1']=='target' and b.clicks[1]=='LeftButtonUp')
assert(b.insets[1]==40 and b.insets[2]==180 and b.insets[3]==150 and b.insets[4]==100)
assert(b.point[2]==UIParent and b.shown)
b.scripts.OnEnter(b); assert(GameTooltip.shown and GameTooltip.unit=='player')
b.scripts.OnLeave(b); assert(not GameTooltip.shown)
P5S_UI_DB.isLocked=true; b.scripts.OnDragStart(b); assert(not f.moving)
P5S_UI_DB.isLocked=false; b.scripts.OnDragStart(b); assert(f.moving)
f:SetPoint('CENTER',UIParent,'CENTER',80,90); assert(b.point[4]==10)
b.scripts.OnDragStop(b); assert(not f.moving and b.point[4]==80 and P5S_UI_DB.xOfs==80)
f:SetScale(1.5); assert(b.scale==1.5)
combat=true
b.scripts.OnDragStart(b); assert(not f.moving)
b.scripts.OnEnter(b); assert(GameTooltip.shown)
P5S_UI_DB.size=600; P5S_UI_DB.resourceBarEnabled=false
f:ApplyResourceBarVisibility(); assert(b.shown)
events.scripts.OnEvent(events,'PLAYER_ENTERING_WORLD'); assert(b.shown)
combat=false; events.scripts.OnEvent(events,'PLAYER_REGEN_ENABLED')
assert(not b.shown and not f.visible and b.scale==1.5)
P5S_UI_DB.resourceBarEnabled=true; f:ApplyResourceBarVisibility(); assert(b.shown)
b.scripts.OnDragStart(b); f:SetPoint('CENTER',UIParent,'CENTER',123,456)
combat=true; events.scripts.OnEvent(events,'PLAYER_REGEN_DISABLED')
assert(not f.moving and f.point[4]==80 and b.point[4]==80 and P5S_UI_DB.xOfs==80)
b.scripts.OnDragStop(b)
combat=false; events.scripts.OnEvent(events,'PLAYER_REGEN_ENABLED')
assert(b.shown and b.point[4]==80)
''')
print('Secure attributes, exact hit area, tooltip, lock/drag, combat deferral and interrupted drag passed')