--------------------------------------------------------------------------------
-- SimpleMacros engine: runs macro text line by line.
--
-- Understands the 1.12 macro commands and the newer (Classic) syntax:
--   /cast [conditions] Spell; [conditions] Other Spell; Last Spell
--   /castsequence [conditions] reset=5/target/combat Spell, Spell, null, !Spell
--   /use, /equip, /target, /targetenemy, /targetenemyplayer, /targetfriend,
--   /targetlasttarget, /cleartarget, /startattack, /stopattack, /petattack,
--   /petfollow, /petwait, /petpassive, /petdefensive, /petaggressive,
--   /cancelaura, /cancelform, /stopcasting, /dismount, /click, /stopmacro,
--   /assist, /run, /script and everything else through the chat box.
--   #show / #showtooltip [spell or slot]: icon and tooltip of the macro.
-- Conditions: combat, harm, help, dead, exists, pet, pet:Name, mod:shift,
--   button:N, group, group:party/raid, form:N, stealth, mounted, worn:Type,
--   channeling, casting, buff:Name, debuff:Name, @unit / target=unit, and the
--   same with "no" in front. Several conditions in one [ ] need all to be
--   true, several [ ][ ] need one.
--
-- 0.5.3 lacks some functions the newer macros use (UnitAffectingCombat,
-- TargetLastTarget, TargetByName, UnitBuff ...). They are replaced here with
-- events and with what the client has; when something cannot be done the
-- condition is simply false and nothing is printed.
--
-- Lua 5.0 rules: no string methods, no # or %, no string.match.
--------------------------------------------------------------------------------

-- What the client itself has, taken before SimpleMacros_Compat.lua adds stand-ins.
SIMPLEMACROS_NATIVE = {
	TargetLastTarget = TargetLastTarget, TargetByName = TargetByName, UnitAffectingCombat = UnitAffectingCombat,
	UnitBuff = UnitBuff, UnitDebuff = UnitDebuff, StopAttack = StopAttack, CastSpellByName = CastSpellByName,
};

SIMPLEMACROS_SOFT_GCD = 1.6;       -- cooldowns shorter than this are the global cooldown

SimpleMacros_InCombat = nil;       -- 1 between PLAYER_REGEN_DISABLED and ENABLED
SimpleMacros_Attacking = nil;      -- 1 while auto attack is on
SimpleMacros_PrevTarget = nil;     -- name of the target before the current one
SimpleMacros_CurTarget = nil;
SimpleMacros_Channel = nil;        -- name of the spell being channeled
SimpleMacros_Casting = nil;
SimpleMacros_Click = nil;          -- mouse button of the click that runs the macro
SimpleMacros_Once = {};            -- messages printed once

function SimpleMacros_Say(key, text)
	if ( not SimpleMacros_Once[key] ) then
		SimpleMacros_Once[key] = 1;
		SimpleMacros_Print(text);
	end
end

--------------------------------------------------------------------------------
-- Spells, items and auras
--------------------------------------------------------------------------------

SimpleMacros_SpellCache = nil;
SimpleMacros_Stamp = 0;        -- changes when the spell book changes
SimpleMacros_ItemStamp = 0;    -- changes when the bags change

function SimpleMacros_ClearSpellCache()
	SimpleMacros_SpellCache = nil;
	SimpleMacros_Stamp = SimpleMacros_Stamp + 1;
end

local function SimpleMacros_AddBookToCache(cache, book)
	local i = 1;
	local name, rank, key;
	while ( i <= MAX_SPELLS ) do
		name, rank = GetSpellName(i, book);
		if ( not name ) then
			break
		end
		key = strlower(name);
		-- Later entries are higher ranks, so the last one wins.
		cache[key] = { id = i, book = book };
		if ( rank and rank ~= "" ) then
			cache[key.."("..strlower(rank)..")"] = { id = i, book = book };
		end
		i = i + 1;
	end
end

function SimpleMacros_BuildSpellCache()
	local cache = {};
	SimpleMacros_AddBookToCache(cache, BOOKTYPE_ABILITY);
	SimpleMacros_AddBookToCache(cache, BOOKTYPE_SPELL);
	SimpleMacros_SpellCache = cache;
end

-- "Shadow Bolt (Rank 2)" and "Shadow Bolt(rank 2)" -> "shadow bolt(rank 2)"
function SimpleMacros_SpellKey(text)
	local key = strlower(SimpleMacros_Trim(text));
	key = gsub(key, "^!", "");
	key = gsub(key, "%s*%(%s*", "(");
	key = gsub(key, "%s*%)%s*$", ")");
	return key;
end

function SimpleMacros_FindSpell(text)
	if ( not text or text == "" ) then
		return nil;
	end
	if ( not SimpleMacros_SpellCache ) then
		SimpleMacros_BuildSpellCache();
	end
	local entry = SimpleMacros_SpellCache[SimpleMacros_SpellKey(text)];
	if ( entry ) then
		return entry.id, entry.book;
	end
	return nil;
end

function SimpleMacros_NameFromLink(link)
	if ( not link ) then
		return nil;
	end
	local s, e, name = strfind(link, "%[(.-)%]");
	return name;
end

function SimpleMacros_FindBagItem(name)
	local lowerName = strlower(SimpleMacros_Trim(name));
	local bag, slot, slots, itemName;
	for bag = 0, 4 do
		slots = GetContainerNumSlots(bag) or 0;
		for slot = 1, slots do
			itemName = SimpleMacros_NameFromLink(GetContainerItemLink(bag, slot));
			if ( itemName and strlower(itemName) == lowerName ) then
				return bag, slot;
			end
		end
	end
	return nil;
end

function SimpleMacros_FindEquippedItem(name)
	local lowerName = strlower(SimpleMacros_Trim(name));
	local slot, itemName;
	if ( not GetInventoryItemLink ) then
		return nil;
	end
	-- 0.5.3 has slots 1 to 19 (no ammo slot 0: the call raises an error).
	for slot = 1, 19 do
		itemName = SimpleMacros_NameFromLink(GetInventoryItemLink("player", slot));
		if ( itemName and strlower(itemName) == lowerName ) then
			return slot;
		end
	end
	return nil;
end

-- Player buffs by the name part of their icon file (no UnitBuff in 0.5.3).
SIMPLEMACROS_AURA_ICONS = {
	["stealth"] = "ability_stealth", ["prowl"] = "ability_ambush", ["shadowform"] = "spell_shadow_shadowform",
	["aspect of the cheetah"] = "ability_mount_jungletiger", ["aspect of the monkey"] = "ability_hunter_aspectofthemonkey",
	["aspect of the hawk"] = "spell_nature_ravenform", ["aspect of the pack"] = "ability_mount_whitetiger",
	["aspect of the wild"] = "spell_nature_protectionformnature", ["aspect of the beast"] = "ability_mount_pinktiger",
	["inner fire"] = "spell_holy_innerfire", ["power word: shield"] = "spell_holy_powerwordshield",
	["slice and dice"] = "ability_rogue_slicedice", ["feign death"] = "ability_rogue_feigndeath",
	["vanish"] = "ability_vanish", ["shadowmeld"] = "ability_ambush", ["bear form"] = "ability_racial_bearform", ["cat form"] = "ability_druid_catform",
};

SimpleMacros_AuraTip = nil;

-- Each player buff: icon (lower case) and, when the tooltip can tell, its name.
function SimpleMacros_PlayerBuffs(harm)
	local list = {};
	if ( not GetPlayerBuff or not GetPlayerBuffTexture ) then
		return list;
	end
	local i, buff, texture, name;
	for i = 0, 31 do
		buff = GetPlayerBuff(i, harm and "HARMFUL" or "HELPFUL");
		if ( not buff or buff < 0 ) then
			break
		end
		texture = GetPlayerBuffTexture(buff);
		name = nil;
		if ( SimpleMacrosScanTooltip and SimpleMacrosScanTooltip.SetPlayerBuff ) then
			SimpleMacrosScanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
			SimpleMacrosScanTooltip:SetPlayerBuff(buff);
			name = SimpleMacrosScanTooltipTextLeft1 and SimpleMacrosScanTooltipTextLeft1:GetText();
		end
		tinsert(list, { index = buff, texture = texture, icon = strlower(texture or ""), name = name and strlower(name) or nil });
	end
	return list;
end

-- 1 when the player has the buff (by name).
function SimpleMacros_HasBuff(text)
	local want = strlower(SimpleMacros_Trim(text));
	local icon = SIMPLEMACROS_AURA_ICONS[want];
	local list = SimpleMacros_PlayerBuffs();
	local i;
	for i = 1, getn(list) do
		if ( list[i].name == want ) then
			return list[i].index;
		end
		if ( icon and strfind(list[i].icon, icon, 1, 1) ) then
			return list[i].index;
		end
	end
	return nil;
end

-- Debuffs / buffs of other units when the client can tell.
function SimpleMacros_UnitHasAura(unit, text, harmful)
	if ( unit == "player" and not harmful ) then
		return SimpleMacros_HasBuff(text);
	end
	local want = strlower(SimpleMacros_Trim(text));
	local icon = SIMPLEMACROS_AURA_ICONS[want] or want;
	local fn = harmful and SIMPLEMACROS_NATIVE.UnitDebuff or SIMPLEMACROS_NATIVE.UnitBuff;
	if ( not fn ) then
		return nil;
	end
	local i = 1;
	local texture;
	while ( i <= 40 ) do
		texture = fn(unit, i);
		if ( not texture ) then
			break
		end
		if ( strfind(strlower(texture), icon, 1, 1) ) then
			return i;
		end
		i = i + 1;
	end
	return nil;
end

--------------------------------------------------------------------------------
-- Unit helpers
--------------------------------------------------------------------------------

SIMPLEMACROS_UNIT_WORDS = {
	target = "target", player = "player", pet = "pet", mouseover = "mouseover", focus = "focus",
	targettarget = "targettarget", pettarget = "pettarget", party1 = "party1", party2 = "party2",
	party3 = "party3", party4 = "party4", partypet1 = "partypet1", partypet2 = "partypet2",
	partypet3 = "partypet3", partypet4 = "partypet4", mouseovertarget = "mouseovertarget",
	playertarget = "targettarget", me = "player", self = "player", cursor = "cursor",
};

function SimpleMacros_Unit(word)
	word = strlower(SimpleMacros_Trim(word or ""));
	return SIMPLEMACROS_UNIT_WORDS[word];
end

function SimpleMacros_UnitExists(unit)
	if ( unit == "cursor" ) then
		return 1;
	end
	return unit and UnitExists(unit) and 1 or nil;
end

function SimpleMacros_IsDead(unit)
	return SimpleMacros_UnitExists(unit) and UnitIsDead(unit) and 1 or nil;
end

function SimpleMacros_IsHelp(unit)
	if ( unit == "cursor" or not SimpleMacros_UnitExists(unit) ) then
		return nil;
	end
	return UnitIsFriend("player", unit) and 1 or nil;
end

function SimpleMacros_IsHarm(unit)
	if ( unit == "cursor" or not SimpleMacros_UnitExists(unit) ) then
		return nil;
	end
	if ( UnitCanAttack ) then
		return UnitCanAttack("player", unit) and 1 or nil;
	end
	if ( UnitIsFriend("player", unit) ) then
		return nil;
	end
	return 1;
end

function SimpleMacros_InCombatNow()
	if ( SIMPLEMACROS_NATIVE.UnitAffectingCombat ) then
		return SIMPLEMACROS_NATIVE.UnitAffectingCombat("player") and 1 or nil;
	end
	return SimpleMacros_InCombat;
end

-- SimpleQoL_IsMounted (server message or AlphaUI) first, then the native
-- IsMounted if this client build has it, guarded since it is untested here.
-- The "mount" buff-icon fallback below was dead code: every mount uses its
-- own icon, there is no shared "mount" icon to match on, so it never caught
-- anything and SIMPLEMACROS_AURA_ICONS never had a "mount" entry.
function SimpleMacros_IsMountedNow()
	if ( SimpleQoL_IsMounted ) then
		return SimpleQoL_IsMounted() and 1 or nil;
	end
	if ( IsMounted ) then
		return IsMounted() and 1 or nil;
	end
	return nil;
end

function SimpleMacros_ActiveForm()
	if ( not GetNumShapeshiftForms or not GetShapeshiftFormInfo ) then
		return nil;
	end
	local i, icon, name, active;
	for i = 1, GetNumShapeshiftForms() do
		icon, name, active = GetShapeshiftFormInfo(i);
		if ( active and active ~= 0 ) then
			return i, name;
		end
	end
	return nil;
end

function SimpleMacros_PetFamily()
	if ( not UnitExists("pet") ) then
		return nil;
	end
	local family = UnitCreatureFamily and UnitCreatureFamily("pet");
	if ( not family or family == "" ) then
		family = UnitName("pet");
	end
	return family and strlower(family) or nil;
end

-- The kind of weapon in the ranged / main hand slots, from the item tooltip.
SIMPLEMACROS_WEAPON_WORDS = { "bow", "crossbow", "gun", "thrown", "wand", "dagger", "sword", "axe", "mace", "staff",
	"polearm", "fist", "shield", "idol", "libram", "totem" };
function SimpleMacros_WornMatches(kind)
	kind = strlower(SimpleMacros_Trim(kind));
	if ( not SimpleMacrosScanTooltip or not SimpleMacrosScanTooltip.SetInventoryItem ) then
		return nil;
	end
	local slot, i, line, text;
	for slot = 16, 18 do
		if ( GetInventoryItemLink and GetInventoryItemLink("player", slot) ) then
			SimpleMacrosScanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
			SimpleMacrosScanTooltip:SetInventoryItem("player", slot);
			for i = 1, 8 do
				line = getglobal("SimpleMacrosScanTooltipTextLeft"..i);
				text = line and line:GetText();
				if ( text ) then
					text = strlower(text);
					if ( text == kind or text == kind.."s" or strfind(text, kind, 1, 1) and strlen(text) < strlen(kind) + 14 ) then
						return 1;
					end
				end
			end
		end
	end
	return nil;
end

function SimpleMacros_GroupMatches(kind)
	local party = GetNumPartyMembers and GetNumPartyMembers() or 0;
	local raid = GetNumRaidMembers and GetNumRaidMembers() or 0;
	kind = strlower(SimpleMacros_Trim(kind or ""));
	if ( kind == "raid" ) then
		return raid > 0;
	elseif ( kind == "party" ) then
		return party > 0 and raid == 0;
	end
	return party > 0 or raid > 0;
end

--------------------------------------------------------------------------------
-- Conditions
--------------------------------------------------------------------------------

-- name, argument (lower case), unit -> 1 or nil. Unknown conditions are true.
function SimpleMacros_Test(name, value, unit)
	local isHelp, isHarm;
	if ( name == "combat" ) then
		return SimpleMacros_InCombatNow();
	elseif ( name == "harm" ) then
		return SimpleMacros_IsHarm(unit);
	elseif ( name == "help" ) then
		return SimpleMacros_IsHelp(unit);
	elseif ( name == "dead" ) then
		return SimpleMacros_IsDead(unit);
	elseif ( name == "exists" ) then
		return SimpleMacros_UnitExists(unit);
	elseif ( name == "target" and value ~= "" ) then
		-- [target=Name] given as a condition: the unit is a name, unsupported.
		return nil;
	elseif ( name == "pet" ) then
		if ( value == "" ) then
			return UnitExists("pet") and 1 or nil;
		end
		local family = SimpleMacros_PetFamily();
		if ( family and (family == value or strfind(family, value, 1, 1)) ) then
			return 1;
		end
		return nil;
	elseif ( name == "mod" or name == "modifier" ) then
		if ( value == "" ) then
			return (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) and 1 or nil;
		elseif ( value == "shift" ) then
			return IsShiftKeyDown() and 1 or nil;
		elseif ( value == "ctrl" or value == "control" ) then
			return IsControlKeyDown() and 1 or nil;
		elseif ( value == "alt" ) then
			return IsAltKeyDown() and 1 or nil;
		end
		return nil;
	elseif ( name == "button" or name == "btn" ) then
		local want = tonumber(value);
		local have = SimpleMacros_Click == "RightButton" and 2 or (SimpleMacros_Click == "MiddleButton" and 3 or 1);
		if ( want and want == have ) then
			return 1;
		end
		return nil;
	elseif ( name == "group" ) then
		return SimpleMacros_GroupMatches(value) and 1 or nil;
	elseif ( name == "form" or name == "stance" ) then
		local index, formName = SimpleMacros_ActiveForm();
		if ( value == "" ) then
			return index and 1 or nil;
		end
		if ( value == "0" ) then
			return not index and 1 or nil;
		end
		if ( index and (tostring(index) == value or (formName and strlower(formName) == value)) ) then
			return 1;
		end
		return nil;
	elseif ( name == "stealth" ) then
		return (SimpleMacros_HasBuff("stealth") or SimpleMacros_HasBuff("prowl") or SimpleMacros_HasBuff("vanish") or SimpleMacros_HasBuff("shadowmeld")) and 1 or nil;
	elseif ( name == "mounted" ) then
		return SimpleMacros_IsMountedNow();
	elseif ( name == "worn" or name == "equipped" ) then
		return SimpleMacros_WornMatches(value);
	elseif ( name == "channeling" ) then
		if ( not SimpleMacros_Channel ) then
			return nil;
		end
		if ( value == "" or value == strlower(SimpleMacros_Channel) ) then
			return 1;
		end
		return nil;
	elseif ( name == "casting" or name == "cast" ) then
		return (SimpleMacros_Casting or SimpleMacros_Channel) and 1 or nil;
	elseif ( name == "buff" ) then
		return SimpleMacros_UnitHasAura(unit or "player", value, nil) and 1 or nil;
	elseif ( name == "debuff" ) then
		return SimpleMacros_UnitHasAura(unit or "target", value, 1) and 1 or nil;
	elseif ( name == "known" ) then
		if ( value == "" ) then
			return nil;
		end
		return SimpleMacros_FindSpell(value) and 1 or nil;
	elseif ( name == "bar" or name == "actionbar" ) then
		local want = tonumber(value);
		if ( want and want == (CURRENT_ACTIONBAR_PAGE or 1) ) then
			return 1;
		end
		return nil;
	elseif ( name == "indoors" or name == "outdoors" ) then
		return 1;
	elseif ( name == "flying" or name == "swimming" or name == "flyable" ) then
		return nil;
	elseif ( name == "party" ) then
		return UnitInParty and UnitInParty(unit or "target") and 1 or nil;
	elseif ( name == "raid" ) then
		return nil;
	elseif ( name == "type" ) then
		return nil;
	end
	return 1;
end

-- One condition text like "nocombat", "mod:shift/ctrl", "@mouseover".
-- Returns ok (1/nil), unit (when the condition names one).
function SimpleMacros_Condition(text, unit)
	text = strlower(SimpleMacros_Trim(text));
	if ( text == "" ) then
		return 1, nil;
	end
	local s, e, who = strfind(text, "^@%s*(.+)$");
	if ( not who ) then
		s, e, who = strfind(text, "^target%s*=%s*(.+)$");
	end
	if ( who ) then
		return 1, who;
	end
	local name, value = text, "";
	local colon = strfind(text, ":", 1, 1);
	if ( colon ) then
		name = SimpleMacros_Trim(strsub(text, 1, colon - 1));
		value = SimpleMacros_Trim(strsub(text, colon + 1));
	end
	local negated = nil;
	-- "nocombat", "noharm" ... ("nomod" etc.); real names starting with "no"
	-- do not exist among the conditions.
	if ( strsub(name, 1, 2) == "no" and name ~= "nocast" ) then
		negated = 1;
		name = strsub(name, 3);
	elseif ( name == "nocast" ) then
		negated = 1;
		name = "casting";
	elseif ( name == "notarget" ) then
		negated = 1;
		name = "exists";
	end
	if ( name == "" ) then
		return 1, nil;
	end
	-- Several values: "shift/ctrl", "1/2".
	local result;
	if ( value == "" ) then
		result = SimpleMacros_Test(name, "", unit);
	else
		result = nil;
		local rest = value.."/";
		local part;
		while ( rest ~= "" ) do
			local slash = strfind(rest, "/", 1, 1);
			part = SimpleMacros_Trim(strsub(rest, 1, slash - 1));
			rest = strsub(rest, slash + 1);
			if ( part ~= "" and SimpleMacros_Test(name, part, unit) ) then
				result = 1;
				break
			end
		end
	end
	if ( negated ) then
		if ( result ) then
			return nil, nil;
		end
		return 1, nil;
	end
	return result, nil;
end

-- "[a,b][c]" group text (without the outer brackets of the first) ->
-- returns ok, unit for one bracket's content.
SIMPLEMACROS_COND_NAMES = {
	combat = 1, harm = 1, help = 1, dead = 1, exists = 1, target = 1, pet = 1, mod = 1, modifier = 1, button = 1,
	btn = 1, group = 1, form = 1, stance = 1, stealth = 1, mounted = 1, worn = 1, equipped = 1, channeling = 1,
	casting = 1, cast = 1, buff = 1, debuff = 1, indoors = 1, outdoors = 1, flying = 1, swimming = 1,
	flyable = 1, party = 1, raid = 1, type = 1, known = 1, bar = 1, actionbar = 1,
};

-- A space starts a new condition only before a condition word or a unit, so
-- spaces inside a value ("buff:Power Word: Shield") are kept.
function SimpleMacros_SplitWord(word)
	local lowerWord = strlower(word);
	if ( strsub(lowerWord, 1, 1) == "@" or SIMPLEMACROS_COND_NAMES[lowerWord] ) then
		return ","..word;
	end
	if ( strsub(lowerWord, 1, 2) == "no" and SIMPLEMACROS_COND_NAMES[strsub(lowerWord, 3)] ) then
		return ","..word;
	end
	return " "..word;
end

function SimpleMacros_Group(content)
	local unit = "target";
	local explicit = nil;
	local ok = 1;
	local rest = content..",";
	local part, comma;
	-- Space separated conditions ("[harm nodead]") count like commas.
	rest = gsub(rest, "%s+([@%a][%w]*)", SimpleMacros_SplitWord);
	rest = gsub(rest, ":%s*,", ":");
	-- A unit comes first in practice; read units before the other tests.
	local parts = {};
	while ( rest ~= "" ) do
		comma = strfind(rest, ",", 1, 1);
		part = strsub(rest, 1, comma - 1);
		rest = strsub(rest, comma + 1);
		part = SimpleMacros_Trim(part);
		if ( part ~= "" ) then
			tinsert(parts, part);
		end
	end
	local i, res, who;
	for i = 1, getn(parts) do
		res, who = SimpleMacros_Condition(parts[i], unit);
		if ( who ) then
			unit = SimpleMacros_Unit(who);
			explicit = 1;
			if ( not unit ) then
				-- A name or an unknown word as unit: not supported.
				unit = "none";
			end
		end
	end
	for i = 1, getn(parts) do
		res, who = SimpleMacros_Condition(parts[i], unit);
		if ( not who and not res ) then
			ok = nil;
			break
		end
	end
	return ok, unit, explicit;
end

-- Splits "[c1][c2] text" into the text and its groups. Returns text, groups,
-- where groups is nil without brackets, else a list of { content }.
function SimpleMacros_TakeGroups(alt)
	alt = SimpleMacros_Trim(alt);
	local groups = nil;
	while ( strsub(alt, 1, 1) == "[" ) do
		local close = strfind(alt, "]", 1, 1);
		if ( not close ) then
			break
		end
		if ( not groups ) then
			groups = {};
		end
		tinsert(groups, strsub(alt, 2, close - 1));
		alt = SimpleMacros_Trim(strsub(alt, close + 1));
	end
	return alt, groups;
end

-- Chooses the alternative of "rest" ("[c] A; [c2] B; C") that holds.
-- Returns argument text, unit, explicit unit flag, the alternative index; nil
-- when none holds.
function SimpleMacros_Choose(rest)
	local text = rest..";";
	local index = 0;
	local alt, groups, semi, i, ok, unit, explicit, okAny;
	while ( text ~= "" ) do
		-- ";" inside brackets does not exist, so a plain search is enough.
		semi = strfind(text, ";", 1, 1);
		alt = strsub(text, 1, semi - 1);
		text = strsub(text, semi + 1);
		index = index + 1;
		if ( SimpleMacros_Trim(alt) ~= "" or index == 1 ) then
			alt, groups = SimpleMacros_TakeGroups(alt);
			if ( not groups ) then
				return alt, "target", nil, index;
			end
			okAny = nil;
			for i = 1, getn(groups) do
				ok, unit, explicit = SimpleMacros_Group(groups[i]);
				if ( ok ) then
					okAny = 1;
					break
				end
			end
			if ( okAny ) then
				return alt, unit, explicit, index;
			end
		end
	end
	return nil;
end

--------------------------------------------------------------------------------
-- Targeting
--------------------------------------------------------------------------------

function SimpleMacros_TargetChanged()
	local name = UnitExists("target") and UnitName("target") or nil;
	if ( name ~= SimpleMacros_CurTarget ) then
		SimpleMacros_PrevTarget = SimpleMacros_CurTarget;
		SimpleMacros_CurTarget = name;
	end
end

-- Cycles through the nearest enemies until test(unit) holds; the old target
-- is put back (cleared) when nothing was found. Needs TargetNearestEnemy.
function SimpleMacros_CycleTarget(test)
	if ( not TargetNearestEnemy ) then
		return nil;
	end
	local before = UnitExists("target") and UnitName("target") or nil;
	local first = nil;
	local i;
	for i = 1, 8 do
		TargetNearestEnemy();
		if ( not UnitExists("target") ) then
			break
		end
		local name = UnitName("target");
		if ( first and name == first and i > 1 ) then
			break
		end
		first = first or name;
		if ( test("target") ) then
			return 1;
		end
	end
	if ( not before ) then
		ClearTarget();
	end
	return nil;
end

function SimpleMacros_TargetByName(text)
	text = strlower(SimpleMacros_Trim(text));
	if ( text == "" ) then
		return nil;
	end
	if ( SIMPLEMACROS_NATIVE.TargetByName ) then
		SIMPLEMACROS_NATIVE.TargetByName(text);
		return 1;
	end
	if ( UnitExists("target") and strfind(strlower(UnitName("target") or ""), text, 1, 1) ) then
		return 1;
	end
	return SimpleMacros_CycleTarget(function(unit)
		return strfind(strlower(UnitName(unit) or ""), text, 1, 1);
	end);
end

-- /targetexact Name: an enemy whose name is exactly this (checked by cycling).
function SimpleMacros_TargetExact(text)
	text = strlower(SimpleMacros_Trim(text));
	if ( text == "" ) then
		return nil;
	end
	if ( UnitExists("target") and strlower(UnitName("target") or "") == text ) then
		return 1;
	end
	return SimpleMacros_CycleTarget(function(unit)
		return strlower(UnitName(unit) or "") == text;
	end);
end

-- /targetparty: the next party member after the current target (party1 to party4).
function SimpleMacros_TargetParty()
	local start = 0;
	local i, index;
	if ( UnitExists("target") ) then
		local name = UnitName("target");
		for i = 1, 4 do
			if ( UnitExists("party"..i) and UnitName("party"..i) == name ) then
				start = i;
			end
		end
	end
	for i = 1, 4 do
		index = start + i;
		if ( index > 4 ) then
			index = index - 4;
		end
		if ( UnitExists("party"..index) ) then
			TargetUnit("party"..index);
			return 1;
		end
	end
	return nil;
end

-- /changeactionbar n and /swapactionbar a b: the same page change as Shift+arrows.
function SimpleMacros_ChangeBar(page)
	page = tonumber(page);
	if ( not page or not NUM_ACTIONBAR_PAGES or not ChangeActionBarPage ) then
		return;
	end
	page = floor(page);
	if ( page < 1 or page > NUM_ACTIONBAR_PAGES or page == CURRENT_ACTIONBAR_PAGE ) then
		return;
	end
	CURRENT_ACTIONBAR_PAGE = page;
	ChangeActionBarPage();
end

function SimpleMacros_SwapBar(text)
	local s, e, first, second = strfind(SimpleMacros_Trim(text), "^(%d+)%s+(%d+)$");
	if ( not first ) then
		return;
	end
	if ( CURRENT_ACTIONBAR_PAGE == tonumber(first) ) then
		SimpleMacros_ChangeBar(second);
	else
		SimpleMacros_ChangeBar(first);
	end
end

function SimpleMacros_TargetLast()
	if ( SIMPLEMACROS_NATIVE.TargetLastTarget ) then
		SIMPLEMACROS_NATIVE.TargetLastTarget();
		return;
	end
	local name = SimpleMacros_PrevTarget;
	if ( name ) then
		local units = { "player", "pet", "party1", "party2", "party3", "party4" };
		local i;
		for i = 1, 6 do
			if ( UnitExists(units[i]) and UnitName(units[i]) == name ) then
				TargetUnit(units[i]);
				return;
			end
		end
		SimpleMacros_TargetByName(name);
	else
		ClearTarget();
	end
end

function SimpleMacros_TargetCommand(command, text, unit)
	text = SimpleMacros_Trim(text);
	local lowerText = strlower(text);
	if ( command == "cleartarget" ) then
		ClearTarget();
	elseif ( command == "targetlasttarget" or command == "targetlast" ) then
		SimpleMacros_TargetLast();
	elseif ( command == "targetenemy" ) then
		if ( lowerText == "player" ) then
			SimpleMacros_CycleTarget(function(u) return UnitIsPlayer(u) and SimpleMacros_IsHarm(u); end);
		elseif ( TargetNearestEnemy ) then
			TargetNearestEnemy();
		end
	elseif ( command == "targetenemyplayer" ) then
		SimpleMacros_CycleTarget(function(u) return UnitIsPlayer(u) and SimpleMacros_IsHarm(u); end);
	elseif ( command == "targetexact" ) then
		SimpleMacros_TargetExact(text);
	elseif ( command == "targetparty" ) then
		SimpleMacros_TargetParty();
	elseif ( command == "targetfriend" or command == "targetfriendplayer" ) then
		if ( TargetNearestFriend ) then
			TargetNearestFriend();
		end
	elseif ( command == "assist" ) then
		if ( text ~= "" and SimpleMacros_Unit(text) ) then
			AssistUnit(SimpleMacros_Unit(text));
		elseif ( AssistUnit ) then
			AssistUnit(unit or "target");
		end
	else
		-- /target, /tar
		if ( lowerText == "" ) then
			if ( unit and unit ~= "target" and SimpleMacros_UnitExists(unit) ) then
				TargetUnit(unit);
			end
		elseif ( lowerText == "nearest" or lowerText == "enemy" ) then
			if ( TargetNearestEnemy ) then
				TargetNearestEnemy();
			end
		elseif ( SimpleMacros_Unit(text) and SimpleMacros_Unit(text) ~= "cursor" ) then
			TargetUnit(SimpleMacros_Unit(text));
		else
			SimpleMacros_TargetByName(text);
		end
	end
end

--------------------------------------------------------------------------------
-- Casting
--------------------------------------------------------------------------------

function SimpleMacros_OnCooldown(id, book)
	if ( not GetSpellCooldown ) then
		return nil;
	end
	local start, duration = GetSpellCooldown(id, book);
	if ( start and start > 0 and duration and duration > SIMPLEMACROS_SOFT_GCD ) then
		return 1;
	end
	return nil;
end

-- Clicks the ground at the cursor for a spell that asks for a place.
function SimpleMacros_ClickCursor()
	if ( SpellIsTargeting and SpellIsTargeting() and CameraOrSelectOrMoveStart ) then
		CameraOrSelectOrMoveStart();
		CameraOrSelectOrMoveStop();
	end
end

-- Casts spell id on a unit. "target" and nil cast normally. Another unit is
-- targeted for the cast and the old target is put back afterwards.
function SimpleMacros_CastAt(id, book, unit, explicit)
	if ( unit == "cursor" ) then
		CastSpell(id, book);
		SimpleMacros_ClickCursor();
		return;
	end
	if ( not explicit or not unit or unit == "target" or unit == "none" ) then
		CastSpell(id, book);
		return;
	end
	if ( not SimpleMacros_UnitExists(unit) ) then
		return;
	end
	if ( unit == "player" ) then
		CastSpell(id, book);
		if ( SpellIsTargeting and SpellIsTargeting() ) then
			SpellTargetUnit("player");
		end
		return;
	end
	if ( UnitExists("target") and UnitIsUnit(unit, "target") ) then
		CastSpell(id, book);
		return;
	end
	local hadTarget = UnitExists("target");
	TargetUnit(unit);
	CastSpell(id, book);
	if ( SpellIsTargeting and SpellIsTargeting() ) then
		SpellStopTargeting();
	end
	if ( hadTarget ) then
		SimpleMacros_TargetLast();
	else
		ClearTarget();
	end
end

-- Auto Shot / Shoot / Attack already running: "!Spell" does not toggle them.
function SimpleMacros_AutoRepeating(name)
	local key = strlower(name);
	if ( key == "attack" ) then
		return SimpleMacros_Attacking;
	end
	if ( (key == "auto shot" or key == "shoot" or key == "shoot bow" or key == "shoot gun" or key == "shoot crossbow" or key == "throw")
		and IsAutoRepeatAction ) then
		local i;
		for i = 1, 120 do
			if ( IsAutoRepeatAction(i) ) then
				return 1;
			end
		end
	end
	return nil;
end

-- Pet ability by name (Devour Magic, Seduction ...): its slot on the pet bar.
function SimpleMacros_PetActionIndex(text)
	if ( not GetPetActionInfo or not CastPetAction or not UnitExists("pet") ) then
		return nil;
	end
	local want = strlower(SimpleMacros_Trim(text));
	local i, name, subtext, texture, isToken;
	for i = 1, 10 do
		name, subtext, texture, isToken = GetPetActionInfo(i);
		if ( name and not isToken and strlower(name) == want ) then
			return i;
		end
	end
	return nil;
end

-- CastSpellByName of 1.12: the second argument 1 means "on myself".
function SimpleMacros_CastNamed(text, onSelf)
	if ( not text ) then
		return;
	end
	local id, book = SimpleMacros_FindSpell(text);
	if ( id ) then
		CastSpell(id, book);
		if ( onSelf and SpellIsTargeting and SpellIsTargeting() ) then
			SpellTargetUnit("player");
		end
		return;
	end
	local petSlot = SimpleMacros_PetActionIndex(text);
	if ( petSlot ) then
		CastPetAction(petSlot);
		return;
	end
	SimpleMacros_Say("spell:"..strlower(text), "Unknown spell: "..text);
end

function SimpleMacros_CastByName(text, unit, explicit)
	text = SimpleMacros_Trim(text);
	if ( text == "" ) then
		return nil;
	end
	local noToggle = strsub(text, 1, 1) == "!";
	local plain = gsub(text, "^!%s*", "");
	if ( noToggle and SimpleMacros_AutoRepeating(plain) ) then
		return nil;
	end
	local id, book = SimpleMacros_FindSpell(plain);
	if ( id ) then
		SimpleMacros_CastAt(id, book, unit, explicit);
		return 1, id, book;
	end
	if ( strlower(plain) == "attack" ) then
		SimpleMacros_StartAttack();
		return 1;
	end
	local petSlot = SimpleMacros_PetActionIndex(plain);
	if ( petSlot ) then
		CastPetAction(petSlot);
		return 1;
	end
	SimpleMacros_Say("spell:"..strlower(plain), "Unknown spell: "..plain);
	return nil;
end

--------------------------------------------------------------------------------
-- /castsequence
--------------------------------------------------------------------------------

SimpleMacros_Sequences = {};       -- key -> { index, time, target, combat }

function SimpleMacros_SplitList(text, sep)
	local list = {};
	text = text..sep;
	local pos, part;
	while ( text ~= "" ) do
		pos = strfind(text, sep, 1, 1);
		part = SimpleMacros_Trim(strsub(text, 1, pos - 1));
		text = strsub(text, pos + 1);
		if ( part ~= "" ) then
			tinsert(list, part);
		end
	end
	return list;
end

function SimpleMacros_SequenceReset(seq, options)
	if ( not options ) then
		return false;
	end
	local now = GetTime();
	local combat = SimpleMacros_InCombatNow();
	local target = UnitExists("target") and UnitName("target") or "";
	local reset = false;
	local i, opt, secs;
	for i = 1, getn(options) do
		opt = strlower(options[i]);
		secs = tonumber(opt);
		if ( secs ) then
			if ( seq.time and now - seq.time >= secs ) then
				reset = true;
			end
		elseif ( opt == "target" ) then
			if ( seq.target ~= target ) then
				reset = true;
			end
		elseif ( opt == "combat" ) then
			if ( (seq.combat and 1 or 0) ~= (combat and 1 or 0) ) then
				reset = true;
			end
		elseif ( opt == "shift" and IsShiftKeyDown() ) then
			reset = true;
		elseif ( opt == "ctrl" and IsControlKeyDown() ) then
			reset = true;
		elseif ( opt == "alt" and IsAltKeyDown() ) then
			reset = true;
		end
	end
	return reset;
end

function SimpleMacros_CastSequence(key, rest, unit, explicit)
	local options = nil;
	local s, e, optText = strfind(rest, "^reset%s*=%s*(%S+)%s*");
	if ( optText ) then
		options = SimpleMacros_SplitList(optText, "/");
		rest = SimpleMacros_Trim(strsub(rest, e + 1));
	end
	local items = SimpleMacros_SplitList(rest, ",");
	local count = getn(items);
	if ( count == 0 ) then
		return;
	end
	local seq = SimpleMacros_Sequences[key];
	if ( not seq ) then
		seq = { index = 1 };
		SimpleMacros_Sequences[key] = seq;
	end
	if ( SimpleMacros_SequenceReset(seq, options) ) then
		seq.index = 1;
	end
	if ( seq.index > count ) then
		seq.index = 1;
	end
	local item = items[seq.index];
	local advance = 1;
	if ( strlower(item) ~= "null" ) then
		local plain = gsub(item, "^!%s*", "");
		local id, book = SimpleMacros_FindSpell(plain);
		if ( id and SimpleMacros_OnCooldown(id, book) ) then
			advance = nil;
		else
			local ok = SimpleMacros_CastByName(item, unit, explicit);
			if ( not ok ) then
				advance = nil;
			end
		end
	end
	seq.time = GetTime();
	seq.target = UnitExists("target") and UnitName("target") or "";
	seq.combat = SimpleMacros_InCombatNow();
	if ( advance ) then
		seq.index = seq.index + 1;
		if ( seq.index > count ) then
			seq.index = 1;
		end
	end
end

--------------------------------------------------------------------------------
-- Other commands
--------------------------------------------------------------------------------

function SimpleMacros_StartAttack()
	if ( SimpleMacros_Attacking ) then
		return;
	end
	if ( AttackTarget and UnitExists("target") and SimpleMacros_IsHarm("target") ) then
		AttackTarget();
	end
end

function SimpleMacros_StopAttack()
	if ( SIMPLEMACROS_NATIVE.StopAttack ) then
		SIMPLEMACROS_NATIVE.StopAttack();
	elseif ( SimpleMacros_Attacking and AttackTarget ) then
		AttackTarget();
	end
end

function SimpleMacros_Use(text, unit)
	text = SimpleMacros_Trim(text);
	if ( text == "" ) then
		return;
	end
	local onSelf = nil;
	if ( unit == "player" ) then
		onSelf = 1;
	end
	local s, e, a, b = strfind(text, "^(%d+)%s+(%d+)$");
	if ( a ) then
		UseContainerItem(tonumber(a), tonumber(b), onSelf);
		return;
	end
	s, e, a = strfind(text, "^(%d+)$");
	if ( a ) then
		if ( tonumber(a) >= 1 and tonumber(a) <= 19 ) then
			UseInventoryItem(tonumber(a));
		end
		return;
	end
	local bag, slot = SimpleMacros_FindBagItem(text);
	if ( bag ) then
		UseContainerItem(bag, slot, onSelf);
		if ( onSelf and SpellIsTargeting and SpellIsTargeting() ) then
			SpellTargetUnit("player");
		end
		return;
	end
	slot = SimpleMacros_FindEquippedItem(text);
	if ( slot ) then
		UseInventoryItem(slot);
		return;
	end
	-- Not an item: maybe a spell name.
	local id, book = SimpleMacros_FindSpell(text);
	if ( id ) then
		CastSpell(id, book);
		return;
	end
end

function SimpleMacros_Equip(text)
	local bag, slot = SimpleMacros_FindBagItem(text);
	if ( bag ) then
		PickupContainerItem(bag, slot);
		AutoEquipCursorItem();
	end
end

function SimpleMacros_CancelAura(text)
	local want = strlower(SimpleMacros_Trim(text));
	if ( want == "" or not CancelPlayerBuff ) then
		return;
	end
	local index = SimpleMacros_HasBuff(want);
	if ( index ) then
		CancelPlayerBuff(index);
	end
end

function SimpleMacros_CancelForm()
	local index = SimpleMacros_ActiveForm();
	if ( index and CastShapeshiftForm ) then
		CastShapeshiftForm(index);
	end
end

function SimpleMacros_Dismount()
	if ( SimpleQoL_Dismount and SimpleMacros_IsMountedNow() ) then
		SimpleQoL_Dismount();
	end
end

-- Sends one line through the normal chat box, exactly like pressing Enter.
function SimpleMacros_RunChatLine(text)
	local box = ChatFrameEditBox;
	local oldThis = this;
	local wasVisible = box:IsVisible();
	local oldText = box:GetText();

	box:SetText(text);
	this = box;
	ChatEdit_OnEnterPressed();
	this = oldThis;

	if ( wasVisible and oldText and oldText ~= "" ) then
		box:Show();
		box:SetText(oldText);
	end
end

SIMPLEMACROS_PET = {
	petattack = 1, petfollow = 1, petwait = 1, petpassive = 1, petdefensive = 1, petaggressive = 1, petdismiss = 1,
};

function SimpleMacros_PetCommand(command, unit, explicit)
	if ( command == "petattack" ) then
		if ( explicit and unit and unit ~= "target" and SimpleMacros_UnitExists(unit) and PetAttack ) then
			-- Another unit than the target: attack it without changing target.
			local had = UnitExists("target");
			TargetUnit(unit);
			PetAttack();
			if ( had ) then
				SimpleMacros_TargetLast();
			else
				ClearTarget();
			end
		elseif ( PetAttack ) then
			PetAttack();
		end
	elseif ( command == "petfollow" and PetFollow ) then
		PetFollow();
	elseif ( command == "petwait" and PetWait ) then
		PetWait();
	elseif ( command == "petpassive" and PetPassiveMode ) then
		PetPassiveMode();
	elseif ( command == "petdefensive" and PetDefensiveMode ) then
		PetDefensiveMode();
	elseif ( command == "petaggressive" and PetAggressiveMode ) then
		PetAggressiveMode();
	elseif ( command == "petdismiss" and PetDismiss ) then
		PetDismiss();
	end
end

--------------------------------------------------------------------------------
-- Running a line and a macro
--------------------------------------------------------------------------------

-- Commands that take conditions. All others go to the chat box unchanged.
SIMPLEMACROS_COND_COMMANDS = {
	cast = 1, spell = 1, castsequence = 1, use = 1, equip = 1, target = 1, tar = 1, targetenemy = 1,
	targetenemyplayer = 1, targetfriend = 1, targetfriendplayer = 1, targetlasttarget = 1, targetlast = 1,
	cleartarget = 1, assist = 1, startattack = 1, stopattack = 1, attack = 1, petattack = 1, petfollow = 1,
	petwait = 1, petpassive = 1, petdefensive = 1, petaggressive = 1, petdismiss = 1, cancelaura = 1,
	cancelform = 1, stopcasting = 1, stopchanneling = 1, dismount = 1, click = 1, stopmacro = 1, clearfocus = 1,
	focus = 1, equipslot = 1, castrandom = 1, userandom = 1, targetexact = 1, targetparty = 1,
	changeactionbar = 1, swapactionbar = 1,
};

-- Runs one line. Returns "stop" when the macro should stop.
function SimpleMacros_RunLine(line, key)
	if ( strsub(line, 1, 2) == "//" or strsub(line, 1, 2) == "--" ) then
		return nil;
	end
	local s, e, command, rest = strfind(line, "^/(%S+)%s*(.-)%s*$");
	if ( not command ) then
		SimpleMacros_RunChatLine(line);
		return nil;
	end
	command = strlower(command);
	if ( (command == "run" or command == "script") and RunScript ) then
		if ( rest ~= "" ) then
			RunScript(rest);
		end
		return nil;
	end
	if ( not SIMPLEMACROS_COND_COMMANDS[command] ) then
		-- /run, /script, /say ... as typed. /console cannot be run from here.
		if ( command == "console" ) then
			SimpleMacros_Say("console", "/console cannot be used from a macro in this client.");
			return nil;
		end
		SimpleMacros_RunChatLine(line);
		return nil;
	end
	local arg, unit, explicit = SimpleMacros_Choose(rest);
	if ( not arg ) then
		return nil;
	end
	if ( unit == "none" ) then
		-- A unit we cannot resolve (a name): do nothing for this line.
		return nil;
	end
	if ( command == "stopmacro" ) then
		return "stop";
	elseif ( command == "cast" or command == "spell" ) then
		SimpleMacros_CastByName(arg, unit, explicit);
	elseif ( command == "castrandom" or command == "userandom" ) then
		local list = SimpleMacros_SplitList(arg, ",");
		if ( getn(list) > 0 ) then
			local pick = list[random(1, getn(list))];
			if ( command == "castrandom" ) then
				SimpleMacros_CastByName(pick, unit, explicit);
			else
				SimpleMacros_Use(pick, unit);
			end
		end
	elseif ( command == "castsequence" ) then
		SimpleMacros_CastSequence(key..":"..line, arg, unit, explicit);
	elseif ( command == "use" ) then
		SimpleMacros_Use(arg, explicit and unit or nil);
	elseif ( command == "equip" or command == "equipslot" ) then
		SimpleMacros_Equip(arg);
	elseif ( command == "startattack" or command == "attack" ) then
		SimpleMacros_StartAttack();
	elseif ( command == "stopattack" ) then
		SimpleMacros_StopAttack();
	elseif ( SIMPLEMACROS_PET[command] ) then
		SimpleMacros_PetCommand(command, unit, explicit);
	elseif ( command == "cancelaura" ) then
		SimpleMacros_CancelAura(arg);
	elseif ( command == "cancelform" ) then
		SimpleMacros_CancelForm();
	elseif ( command == "stopcasting" or command == "stopchanneling" ) then
		if ( SpellStopCasting ) then
			SpellStopCasting();
		end
	elseif ( command == "dismount" ) then
		SimpleMacros_Dismount();
	elseif ( command == "click" ) then
		local frame = getglobal(arg);
		if ( frame and frame.Click ) then
			frame:Click();
		end
	elseif ( command == "changeactionbar" ) then
		SimpleMacros_ChangeBar(arg);
	elseif ( command == "swapactionbar" ) then
		SimpleMacros_SwapBar(arg);
	elseif ( command == "clearfocus" or command == "focus" ) then
		-- 0.5.3 has no focus target.
		return nil;
	else
		SimpleMacros_TargetCommand(command, arg, unit);
	end
	return nil;
end

function SimpleMacros_RunMacro(macro, button)
	if ( not macro or not macro.body ) then
		return;
	end
	SimpleMacros_Click = button or "LeftButton";
	local key = macro.name or "macro";
	local body = macro.body.."\n";
	local line, raw;
	for raw in string.gfind(body, "([^\n]*)\n") do
		line = SimpleMacros_Trim(raw);
		if ( line ~= "" and strsub(line, 1, 1) ~= "#" ) then
			if ( SimpleMacros_RunLine(line, key) == "stop" ) then
				break
			end
		end
	end
	SimpleMacros_Click = nil;
end

--------------------------------------------------------------------------------
-- #show / #showtooltip: icon, tooltip and cooldown of a macro
--------------------------------------------------------------------------------

-- The spell or item a macro shows. Returns kind, a, b:
--   "spell", id, book | "slot", inventory slot | "bag", bag, slot | nil
function SimpleMacros_ShowTarget(macro)
	if ( not macro or not macro.body ) then
		return nil;
	end
	-- The answer is remembered; macros with [conditions] are worked out again
	-- each time because the answer can change with shift, combat and so on.
	local cache = macro.cache;
	local now = GetTime();
	-- A macro with [conditions] is still worked out again, but not again within
	-- the same frame (the bar check asks several times in a row).
	if ( cache and cache.stamp == SimpleMacros_Stamp and (not cache.item or cache.istamp == SimpleMacros_ItemStamp)
		and (not cache.dynamic or now - cache.time < 0.02) ) then
		return cache.kind, cache.a, cache.b;
	end
	local kind, a, b = SimpleMacros_ShowTargetRaw(macro);
	if ( macro.dynamic == nil ) then
		macro.dynamic = strfind(macro.body, "[", 1, 1) and 1 or 0;
	end
	-- The table is reused for a macro with [conditions] (no new table four
	-- times a second); a spell book change starts a new one.
	if ( not cache or cache.stamp ~= SimpleMacros_Stamp ) then
		cache = {};
		macro.cache = cache;
	end
	cache.stamp = SimpleMacros_Stamp;
	cache.istamp = SimpleMacros_ItemStamp;
	cache.time = now;
	cache.kind = kind;
	cache.a = a;
	cache.b = b;
	cache.item = (kind == "bag" or kind == "slot");
	cache.dynamic = (macro.dynamic == 1);
	return kind, a, b;
end

-- The spell name in CastSpellByName("Name") or cast("Name") inside script text.
function SimpleMacros_ScriptSpell(text)
	local s1, e1, name = strfind(text or "", "CastSpellByName%s*%(%s*\"([^\"]+)\"");
	if ( not name ) then
		s1, e1, name = strfind(text or "", "CastSpellByName%s*%(%s*'([^']+)'");
	end
	if ( not name ) then
		s1, e1, name = strfind(text or "", "cast%s*%(%s*\"([^\"]+)\"");
	end
	return s1, e1, name;
end

function SimpleMacros_ShowTargetRaw(macro)
	local body = macro.body.."\n";
	local wantShow, showArg = nil, "";
	local line, raw, s, e, word, rest;
	for raw in string.gfind(body, "([^\n]*)\n") do
		line = SimpleMacros_Trim(raw);
		s, e, word, rest = strfind(line, "^#(%a+)%s*(.-)$");
		if ( word and (strlower(word) == "show" or strlower(word) == "showtooltip") ) then
			wantShow = 1;
			showArg = rest;
			break
		end
	end
	local function resolve(name)
		name = SimpleMacros_Trim(name or "");
		name = gsub(name, "^!%s*", "");
		if ( name == "" ) then
			return nil;
		end
		local s2, e2, slot = strfind(name, "^(%d+)$");
		if ( slot ) then
			if ( tonumber(slot) >= 1 and tonumber(slot) <= 19 ) then
				return "slot", tonumber(slot);
			end
			return nil;
		end
		local id, book = SimpleMacros_FindSpell(name);
		if ( not id and strfind(name, "(", 1, 1) ) then
			id, book = SimpleMacros_FindSpell((gsub(name, "%s*%(.*%)%s*$", "")));
		end
		if ( id ) then
			return "spell", id, book;
		end
		local bag, bslot = SimpleMacros_FindBagItem(name);
		if ( bag ) then
			return "bag", bag, bslot;
		end
		local eq = SimpleMacros_FindEquippedItem(name);
		if ( eq ) then
			return "slot", eq;
		end
		-- A spell the character does not know: its icon is still known by name.
		local key = gsub(name, "%s*%(.*%)%s*$", "");
		key = strlower(key);
		local path = SIMPLEMACROS_SPELL_ICONS and SIMPLEMACROS_SPELL_ICONS[key];
		if ( path ) then
			return "icon", path, name;
		end
		return nil;
	end
	if ( wantShow and showArg ~= "" ) then
		return resolve(showArg);
	end
	-- Old macro trick: /run --CastSpellByName("Spell") only names the icon.
	local kindC, aC, bC;
	for raw in string.gfind(body, "([^\n]*)\n") do
		line = SimpleMacros_Trim(raw);
		local sc, ec, cmdC, scriptC = strfind(line, "^/(%a+)%s+%-%-%s*(.-)$");
		if ( cmdC and (strlower(cmdC) == "run" or strlower(cmdC) == "script") ) then
			local sn, en, spellC = SimpleMacros_ScriptSpell(scriptC);
			if ( spellC ) then
				kindC, aC, bC = resolve(spellC);
				if ( kindC ) then
					return kindC, aC, bC;
				end
			end
		end
	end
	-- The first thing the macro would cast or use right now.
	for raw in string.gfind(body, "([^\n]*)\n") do
		line = SimpleMacros_Trim(raw);
		local s3, e3, command, rest2 = strfind(line, "^/(%S+)%s*(.-)%s*$");
		if ( command and (strlower(command) == "run" or strlower(command) == "script") ) then
			local sn2, en2, spellR = SimpleMacros_ScriptSpell(rest2);
			if ( spellR and not strfind(rest2, "^%-%-") ) then
				kindC, aC, bC = resolve(spellR);
				if ( kindC ) then
					return kindC, aC, bC;
				end
			end
		elseif ( command ) then
			command = strlower(command);
			if ( command == "cast" or command == "spell" or command == "castsequence" or command == "use" ) then
				local text, unit = SimpleMacros_Choose(rest2);
				if ( text and text ~= "" ) then
					if ( command == "castsequence" ) then
						text = gsub(text, "^reset%s*=%s*%S+%s*", "");
						local list = SimpleMacros_SplitList(text, ",");
						local k;
						for k = 1, getn(list) do
							if ( strlower(list[k]) ~= "null" ) then
								local kind, a, b = resolve(list[k]);
								if ( kind ) then
									return kind, a, b;
								end
							end
						end
					else
						local kind, a, b = resolve(text);
						if ( kind ) then
							return kind, a, b;
						end
					end
				end
			end
		end
	end
	return nil;
end

function SimpleMacros_ShowTexture(macro)
	local kind, a, b = SimpleMacros_ShowTarget(macro);
	if ( kind == "spell" and GetSpellTexture ) then
		return GetSpellTexture(a, b);
	elseif ( kind == "icon" ) then
		return SimpleMacros_IconPath(a);
	elseif ( kind == "slot" and GetInventoryItemTexture ) then
		return GetInventoryItemTexture("player", a);
	elseif ( kind == "bag" and GetContainerItemInfo ) then
		local texture = GetContainerItemInfo(a, b);
		return texture;
	end
	return nil;
end

-- Texture to show for a macro. The question mark icon means "automatic":
-- the icon of what the macro shows (#show / #showtooltip) or casts first.
function SimpleMacros_MacroTexture(macro)
	if ( not macro ) then
		return nil;
	end
	if ( not macro.icon or macro.icon == "" or macro.icon == SIMPLEMACROS_DEFAULT_ICON ) then
		local texture = SimpleMacros_ShowTexture(macro);
		if ( texture ) then
			-- Remembered, so a character that does not know the spell (or has
			-- not got the item) still shows the right icon.
			if ( macro.lastTex ~= texture ) then
				local first = (macro.lastTex == nil);
				macro.lastTex = texture;
				local kind = SimpleMacros_ShowTarget(macro);
				-- Spells are found by name (SimpleMacros_SpellIcons.lua); only
				-- icons of items need to be remembered.
				if ( (kind == "bag" or kind == "slot") and (first or macro.dynamic ~= 1) and SimpleMacros_Storage_SaveTex ) then
					SimpleMacros_Storage_SaveTex(macro);
				end
			end
			return texture;
		end
		if ( macro.lastTex and macro.lastTex ~= "" ) then
			return macro.lastTex;
		end
	end
	return SimpleMacros_IconPath(macro.icon);
end

-- Tooltip of a macro button: the spell or item the macro shows, else the
-- macro itself.
function SimpleMacros_BarTooltip(owner, macro)
	local kind, a, b = SimpleMacros_ShowTarget(macro);
	local has = nil;
	if ( kind ) then
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
		if ( kind == "spell" and GameTooltip.SetSpell and GameTooltip:SetSpell(a, b) ) then
			-- The client's own spell tooltip, so it looks like the normal buttons.
			has = 1;
		elseif ( kind == "spell" and GetSpellName ) then
			local spellName, rank = GetSpellName(a, b);
			GameTooltip:SetText(spellName or "", 1.0, 1.0, 1.0);
			if ( rank and rank ~= "" ) then
				GameTooltip:AddLine(rank, "", 0.8, 0.8, 0.8);
			end
			has = 1;
		elseif ( kind == "icon" ) then
			GameTooltip:SetText(b or "", 1.0, 1.0, 1.0);
			has = 1;
		elseif ( kind == "slot" and GameTooltip.SetInventoryItem ) then
			GameTooltip:SetInventoryItem("player", a);
			has = 1;
		elseif ( kind == "bag" and GameTooltip.SetBagItem ) then
			GameTooltip:SetBagItem(a, b);
			has = 1;
		end
	end
	if ( has ) then
		GameTooltip:Show();
	else
		SimpleMacros_ShowTooltip(owner, macro);
	end
end

--------------------------------------------------------------------------------
-- Events that replace missing functions
--------------------------------------------------------------------------------

function SimpleMacrosEngine_OnLoad()
	this:RegisterEvent("PLAYER_REGEN_DISABLED");
	this:RegisterEvent("PLAYER_REGEN_ENABLED");
	this:RegisterEvent("PLAYER_ENTER_COMBAT");
	this:RegisterEvent("PLAYER_LEAVE_COMBAT");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	this:RegisterEvent("BAG_UPDATE");
	this:RegisterEvent("SPELLCAST_START");
	this:RegisterEvent("SPELLCAST_STOP");
	this:RegisterEvent("SPELLCAST_FAILED");
	this:RegisterEvent("SPELLCAST_INTERRUPTED");
	this:RegisterEvent("SPELLCAST_CHANNEL_START");
	this:RegisterEvent("SPELLCAST_CHANNEL_STOP");
end

function SimpleMacrosEngine_OnEvent(event)
	if ( event == "PLAYER_REGEN_DISABLED" ) then
		SimpleMacros_InCombat = 1;
		if ( PlayerFrame ) then
			PlayerFrame.inCombat = 1;
		end
		if ( SimpleMacros_RefreshUsable ) then
			SimpleMacros_RefreshUsable();
		end
	elseif ( event == "PLAYER_REGEN_ENABLED" ) then
		SimpleMacros_InCombat = nil;
		if ( PlayerFrame ) then
			PlayerFrame.inCombat = nil;
		end
		if ( SimpleMacros_RefreshUsable ) then
			SimpleMacros_RefreshUsable();
		end
	elseif ( event == "PLAYER_ENTER_COMBAT" ) then
		SimpleMacros_Attacking = 1;
	elseif ( event == "PLAYER_LEAVE_COMBAT" ) then
		SimpleMacros_Attacking = nil;
	elseif ( event == "PLAYER_TARGET_CHANGED" ) then
		SimpleMacros_TargetChanged();
	elseif ( event == "BAG_UPDATE" ) then
		SimpleMacros_ItemStamp = SimpleMacros_ItemStamp + 1;
	elseif ( event == "SPELLCAST_START" ) then
		SimpleMacros_Casting = arg1 or 1;
	elseif ( event == "SPELLCAST_CHANNEL_START" ) then
		SimpleMacros_Channel = arg2 or "channel";
	elseif ( event == "SPELLCAST_CHANNEL_STOP" ) then
		SimpleMacros_Channel = nil;
	else
		SimpleMacros_Casting = nil;
	end
end
