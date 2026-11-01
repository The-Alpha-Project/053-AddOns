--------------------------------------------------------------------------------
-- SimpleMacros compatibility: 1.12 functions and chat commands the 0.5.3
-- client may lack. Everything here is added only when it does not exist, so
-- the client's own versions (and other addons') always win.
--------------------------------------------------------------------------------

-- CastSpellByName("Shadow Bolt") or ("Shadow Bolt(Rank 2)"); 1 = on myself.
if ( not CastSpellByName ) then
	CastSpellByName = function(text, onSelf)
		SimpleMacros_CastNamed(text, onSelf);
	end
end

if ( not UseItemByName ) then
	UseItemByName = function(text)
		SimpleMacros_Use(text);
	end
end

if ( not GetUnitName ) then
	GetUnitName = function(unit)
		return UnitName(unit);
	end
end

-- Combat state of the player only, from the combat events.
if ( not UnitAffectingCombat ) then
	UnitAffectingCombat = function(unit)
		if ( unit == "player" ) then
			return SimpleMacros_InCombat;
		end
		return nil;
	end
end

if ( not TargetLastTarget ) then
	TargetLastTarget = function()
		SimpleMacros_TargetLast();
	end
end
if ( not TargetLastEnemy ) then
	TargetLastEnemy = function()
		SimpleMacros_TargetLast();
	end
end
if ( not TargetByName ) then
	TargetByName = function(text)
		SimpleMacros_TargetByName(text);
	end
end

if ( not PetStopAttack ) then
	PetStopAttack = function()
		if ( PetFollow ) then
			PetFollow();
		end
	end
end

-- Target changes made by a script are noticed at once, so TargetLastTarget() right
-- after ClearTarget() or TargetUnit() goes back to the right unit (the target event
-- arrives only after the script).
local SimpleMacros_NativeClearTarget = ClearTarget;
local SimpleMacros_NativeTargetUnit = TargetUnit;
local SimpleMacros_NativeTargetNearestEnemy = TargetNearestEnemy;
if ( SimpleMacros_NativeClearTarget ) then
	ClearTarget = function()
		SimpleMacros_NativeClearTarget();
		SimpleMacros_TargetChanged();
	end
end
if ( SimpleMacros_NativeTargetUnit ) then
	TargetUnit = function(unit)
		SimpleMacros_NativeTargetUnit(unit);
		SimpleMacros_TargetChanged();
	end
end
if ( SimpleMacros_NativeTargetNearestEnemy ) then
	TargetNearestEnemy = function(reverse)
		SimpleMacros_NativeTargetNearestEnemy(reverse);
		SimpleMacros_TargetChanged();
	end
end

-- More 1.12 functions that old macros call. Without them the line fails with a Lua error.
if ( not StopAttack ) then
	StopAttack = function()
		SimpleMacros_StopAttack();
	end
end

-- Approximation: the client has no auto repeat state, a toggled action counts as current.
if ( not IsAutoRepeatAction and IsCurrentAction ) then
	IsAutoRepeatAction = function(slot)
		return IsCurrentAction(slot);
	end
end

-- Cannot be done in this client: kept so a macro line does not fail.
if ( not RetrieveCorpse ) then
	RetrieveCorpse = function()
	end
end

if ( not SpellStopCasting ) then
	SpellStopCasting = function()
		if ( SpellIsTargeting and SpellIsTargeting() and SpellStopTargeting ) then
			SpellStopTargeting();
		end
	end
end

if ( not TargetNearestEnemyPlayer ) then
	TargetNearestEnemyPlayer = function()
		SimpleMacros_CycleTarget(function(u) return UnitIsPlayer(u) and SimpleMacros_IsHarm(u); end);
	end
end

-- Zorlen/SuperMacro style helpers used in old macros (only when no addon has them).
if ( not cast ) then
	cast = function(text)
		SimpleMacros_CastNamed(text);
	end
end
if ( not buffed ) then
	buffed = function(text, unit)
		unit = unit or "target";
		if ( SimpleMacros_UnitHasAura(unit, text, nil) or SimpleMacros_UnitHasAura(unit, text, 1) ) then
			return 1;
		end
		return nil;
	end
end

-- UnitBuff / UnitDebuff (unit, index) -> icon path. Only the player's own
-- auras can be read in 0.5.3; other units give nothing.
if ( not UnitBuff ) then
	UnitBuff = function(unit, index)
		if ( unit ~= "player" or not index ) then
			return nil;
		end
		local list = SimpleMacros_PlayerBuffs(nil);
		local entry = list[index];
		return entry and entry.texture or nil;
	end
end
if ( not UnitDebuff ) then
	UnitDebuff = function(unit, index)
		if ( unit ~= "player" or not index ) then
			return nil;
		end
		local list = SimpleMacros_PlayerBuffs(1);
		local entry = list[index];
		return entry and entry.texture or nil;
	end
end

-- Typed in the chat box, the macro commands work too (0.5.3 has none of them).
-- The slash words (always declared; a command is registered only when no
-- other addon or the client already owns the word).
SLASH_SIMPLEMACROSCMDCAST1 = "/cast";
SLASH_SIMPLEMACROSCMDCASTSEQUENCE1 = "/castsequence";
SLASH_SIMPLEMACROSCMDCASTRANDOM1 = "/castrandom";
SLASH_SIMPLEMACROSCMDUSE1 = "/use";
SLASH_SIMPLEMACROSCMDUSERANDOM1 = "/userandom";
SLASH_SIMPLEMACROSCMDEQUIP1 = "/equip";
SLASH_SIMPLEMACROSCMDTARGET1 = "/target";
SLASH_SIMPLEMACROSCMDTAR1 = "/tar";
SLASH_SIMPLEMACROSCMDTARGETENEMY1 = "/targetenemy";
SLASH_SIMPLEMACROSCMDTARGETENEMYPLAYER1 = "/targetenemyplayer";
SLASH_SIMPLEMACROSCMDTARGETFRIEND1 = "/targetfriend";
SLASH_SIMPLEMACROSCMDTARGETLASTTARGET1 = "/targetlasttarget";
SLASH_SIMPLEMACROSCMDCLEARTARGET1 = "/cleartarget";
SLASH_SIMPLEMACROSCMDASSIST1 = "/assist";
SLASH_SIMPLEMACROSCMDSTARTATTACK1 = "/startattack";
SLASH_SIMPLEMACROSCMDSTOPATTACK1 = "/stopattack";
SLASH_SIMPLEMACROSCMDPETATTACK1 = "/petattack";
SLASH_SIMPLEMACROSCMDPETFOLLOW1 = "/petfollow";
SLASH_SIMPLEMACROSCMDPETWAIT1 = "/petwait";
SLASH_SIMPLEMACROSCMDPETPASSIVE1 = "/petpassive";
SLASH_SIMPLEMACROSCMDPETDEFENSIVE1 = "/petdefensive";
SLASH_SIMPLEMACROSCMDPETAGGRESSIVE1 = "/petaggressive";
SLASH_SIMPLEMACROSCMDCANCELAURA1 = "/cancelaura";
SLASH_SIMPLEMACROSCMDCANCELFORM1 = "/cancelform";
SLASH_SIMPLEMACROSCMDSTOPCASTING1 = "/stopcasting";
SLASH_SIMPLEMACROSCMDDISMOUNT1 = "/dismount";
SLASH_SIMPLEMACROSCMDCLICK1 = "/click";

SIMPLEMACROS_CHAT_COMMANDS = {
	"cast", "castsequence", "castrandom", "use", "userandom", "equip", "target", "tar", "targetenemy",
	"targetenemyplayer", "targetfriend", "targetlasttarget", "cleartarget", "assist", "startattack",
	"stopattack", "petattack", "petfollow", "petwait", "petpassive", "petdefensive", "petaggressive",
	"cancelaura", "cancelform", "stopcasting", "dismount", "click",
};

function SimpleMacros_Compat_Slashes()
	local taken = {};
	local key, value, i, word;
	for key, value in SlashCmdList do
		i = 1;
		word = getglobal("SLASH_"..key..i);
		while ( word ) do
			if ( strsub(key, 1, 15) ~= "SIMPLEMACROSCMD" ) then
				taken[strlower(word)] = 1;
			end
			i = i + 1;
			word = getglobal("SLASH_"..key..i);
		end
	end
	local k, name, id;
	for k = 1, getn(SIMPLEMACROS_CHAT_COMMANDS) do
		name = SIMPLEMACROS_CHAT_COMMANDS[k];
		if ( not taken["/"..name] ) then
			id = "SIMPLEMACROSCMD"..strupper(name);
			SlashCmdList[id] = SimpleMacros_ChatHandler(name);
		end
	end
end

function SimpleMacros_ChatHandler(name)
	return function(msg)
		SimpleMacros_Click = "LeftButton";
		SimpleMacros_RunLine("/"..name.." "..(msg or ""), "chat");
		SimpleMacros_Click = nil;
	end
end
