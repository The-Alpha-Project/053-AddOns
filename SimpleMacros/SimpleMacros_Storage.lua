--------------------------------------------------------------------------------
-- SimpleMacros storage: macros are saved with SimpleSave (bindings.wtf), so
-- they survive a restart without any server patch or file editing.
--
--   general macros (all characters):   key "g<slot>m"
--   character macros (this character): key "c<slot>m"
--   macros on action buttons (this character): key "slots" ("12=g3;25=c5")
-- m = "1" + name, icon and body as one text (name, icon, body separated by new
-- lines) with common words replaced by short codes, so more macros fit in the
-- shared SimpleSave space. Older versions saved the keys n, i and b; they are
-- still read and are replaced by the short form when loaded.
-- Without SimpleSave the macros work for the session only.
--------------------------------------------------------------------------------

SimpleMacros_StorageLoaded = nil;

function SimpleMacros_Storage_StatusText()
	if ( not SimpleSave_Set ) then
		return "SimpleSave is not installed: macros cannot be saved.";
	end
	if ( not SimpleMacros_StorageLoaded ) then
		return "Loading macros...";
	end
	return "Saved automatically (SimpleSave).";
end

local function SimpleMacros_Get(scope, key, default)
	if ( scope == "c" and SimpleSave_GetChar ) then
		return SimpleSave_GetChar("SimpleMacros", key, default);
	end
	return SimpleSave_Get("SimpleMacros", key, default);
end

local function SimpleMacros_Put(scope, key, value)
	-- value nil removes the key.
	if ( scope == "c" and SimpleSave_SetChar ) then
		SimpleSave_SetChar("SimpleMacros", key, value);
	else
		SimpleSave_Set("SimpleMacros", key, value);
	end
end

-- Short codes: "%" and one of these characters stand for a word of this list.
-- The list and its order must never change (the stored version number is 1).
SIMPLEMACROS_DICT_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
SIMPLEMACROS_DICT = {
	"\n/cast ", "/cast ", "#showtooltip", "#show ", "/startattack", "/stopattack", "/petattack", "/petfollow",
	"/cancelaura ", "/castsequence ", "/castrandom ", "/use ", "/target", "/script ", "/run ", "/stopmacro",
	"/cleartarget", "/targetenemy", "/stopcasting", "[combat", "[nocombat", "[mod:shift", "[mod:ctrl", "[harm",
	"[help", "[@mouseover", "[nopet", "[pet", "[stealth", "[nostealth", "CastSpellByName(", "TargetNearestEnemy()",
	"UnitExists(", "GetUnitName(", "IsCurrentAction(", "AttackTarget()", "UnitAffectingCombat(", "TargetLastTarget()",
	"StopAttack()", "PlayerFrame.inCombat", "IsAutoRepeatAction(", "UseAction(", "ClearTarget()", "PetAttack()",
	"UseItemByName(", "INV_Misc_QuestionMark", "Spell_Shadow_", "Spell_Nature_", "Spell_Holy_", "Spell_Fire_",
	"Spell_Frost_", "Ability_", "INV_Misc_", "INV_Weapon_", "Spell_", "Shadow Bolt", "Summon ", "Curse of ",
	"Rank ", "\n/", "mouseover", "\"target\"",
};
SimpleMacros_DictOrder = nil;

-- Entry numbers, longest word first (so the longest match is used).
function SimpleMacros_DictOrderList()
	if ( SimpleMacros_DictOrder ) then
		return SimpleMacros_DictOrder;
	end
	local order = {};
	local i, j, k;
	for i = 1, getn(SIMPLEMACROS_DICT) do
		j = 1;
		while ( j <= getn(order) and strlen(SIMPLEMACROS_DICT[order[j]]) >= strlen(SIMPLEMACROS_DICT[i]) ) do
			j = j + 1;
		end
		tinsert(order, j, i);
	end
	SimpleMacros_DictOrder = order;
	return order;
end

-- Replaces every plain (not pattern) occurrence of word in text.
function SimpleMacros_ReplacePlain(text, word, code)
	local result = "";
	local start = 1;
	local first, last;
	while ( 1 ) do
		first, last = strfind(text, word, start, 1);
		if ( not first ) then
			break
		end
		result = result..strsub(text, start, first - 1)..code;
		start = last + 1;
	end
	return result..strsub(text, start);
end

function SimpleMacros_Compress(text)
	text = gsub(text, "%%", "%%%%");
	local order = SimpleMacros_DictOrderList();
	local i, entry;
	for i = 1, getn(order) do
		entry = order[i];
		text = SimpleMacros_ReplacePlain(text, SIMPLEMACROS_DICT[entry], "%"..strsub(SIMPLEMACROS_DICT_CHARS, entry, entry));
	end
	return text;
end

function SimpleMacros_DictWord(char)
	if ( char == "%" ) then
		return "%";
	end
	local entry = strfind(SIMPLEMACROS_DICT_CHARS, char, 1, 1);
	return entry and SIMPLEMACROS_DICT[entry] or "";
end

function SimpleMacros_Decompress(text)
	return (gsub(text, "%%(.)", SimpleMacros_DictWord));
end

-- Name, icon and body of a macro as the stored text, and back (nil if damaged).
function SimpleMacros_PackMacro(macro)
	return "1"..SimpleMacros_Compress((macro.name or "").."\n"..(macro.icon or "").."\n"..(macro.body or ""));
end

function SimpleMacros_UnpackMacro(value)
	if ( not value or strsub(value, 1, 1) ~= "1" ) then
		return nil;
	end
	local text = SimpleMacros_Decompress(strsub(value, 2));
	local first = strfind(text, "\n", 1, 1);
	if ( not first ) then
		return nil;
	end
	local second = strfind(text, "\n", first + 1, 1);
	if ( not second ) then
		return nil;
	end
	return strsub(text, 1, first - 1), strsub(text, first + 1, second - 1), strsub(text, second + 1);
end

function SimpleMacros_Storage_SaveMacro(scope, slot)
	if ( not SimpleSave_Set or not SimpleMacros_StorageLoaded ) then
		return;
	end
	local macro = SimpleMacros_Macros[scope][slot];
	if ( not macro ) then
		return;
	end
	local ref = scope..slot;
	SimpleMacros_Put(scope, ref.."m", SimpleMacros_PackMacro(macro));
	-- Older keys (and an empty icon memory) are removed: they only take space.
	SimpleMacros_Put(scope, ref.."n", nil);
	SimpleMacros_Put(scope, ref.."i", nil);
	SimpleMacros_Put(scope, ref.."b", nil);
	SimpleMacros_Put(scope, ref.."t", nil);
end

-- Icon last worked out for an automatic icon.
function SimpleMacros_Storage_SaveTex(macro)
	if ( not SimpleSave_Set or not SimpleMacros_StorageLoaded or not macro.ref ) then
		return;
	end
	local value = macro.lastTex;
	if ( value == "" ) then
		value = nil;
	end
	SimpleMacros_Put(strsub(macro.ref, 1, 1), macro.ref.."t", value);
end

function SimpleMacros_Storage_DeleteMacro(scope, slot)
	if ( not SimpleSave_Set or not SimpleMacros_StorageLoaded ) then
		return;
	end
	local ref = scope..slot;
	SimpleMacros_Put(scope, ref.."m", nil);
	SimpleMacros_Put(scope, ref.."n", nil);
	SimpleMacros_Put(scope, ref.."i", nil);
	SimpleMacros_Put(scope, ref.."b", nil);
	SimpleMacros_Put(scope, ref.."t", nil);
end

function SimpleMacros_Storage_SaveSlots()
	if ( not SimpleSave_Set or not SimpleMacros_StorageLoaded ) then
		return;
	end
	SimpleMacros_Put("c", "slots", SimpleMacros_SlotsToString());
end

function SimpleMacros_Storage_SaveNames()
	if ( not SimpleSave_Set or not SimpleMacros_StorageLoaded ) then
		return;
	end
	if ( SimpleMacros_ShowNames ) then
		SimpleMacros_Put("g", "names", "1");
	else
		SimpleMacros_Put("g", "names", "0");
	end
end

function SimpleMacros_Storage_Load()
	SimpleMacros_StorageLoaded = 1;
	if ( not SimpleSave_Get ) then
		-- Without SimpleSave macros work during the session but are not saved.
		SimpleMacros_Loaded = 1;
		SimpleMacros_OnMacrosChanged();
		return;
	end
	local scopes = { "g", "c" };
	local s, i, ref, name, icon, body, packed;
	local old = {};
	for s = 1, 2 do
		for i = 1, SIMPLEMACROS_MAX_MACROS do
			ref = scopes[s]..i;
			name = nil;
			packed = SimpleMacros_Get(scopes[s], ref.."m", "");
			if ( packed and packed ~= "" ) then
				name, icon, body = SimpleMacros_UnpackMacro(packed);
			end
			if ( not name ) then
				-- Saved by an older version: keys n, i and b.
				name = SimpleMacros_Get(scopes[s], ref.."n", "");
				if ( name and name ~= "" ) then
					icon = SimpleMacros_Get(scopes[s], ref.."i", "");
					body = SimpleMacros_Get(scopes[s], ref.."b", "");
					tinsert(old, { scopes[s], i });
				end
			end
			if ( name and name ~= "" ) then
				SimpleMacros_Macros[scopes[s]][i] = { name = name, icon = icon, body = body, ref = ref };
				body = SimpleMacros_Get(scopes[s], ref.."t", "");
				if ( body and body ~= "" ) then
					SimpleMacros_Macros[scopes[s]][i].lastTex = body;
				end
			else
				SimpleMacros_Macros[scopes[s]][i] = nil;
			end
		end
	end
	if ( SimpleMacros_Get("g", "names", "1") == "0" ) then
		SimpleMacros_ShowNames = nil;
	else
		SimpleMacros_ShowNames = 1;
	end
	SimpleMacros_SlotsFromString(SimpleMacros_Get("c", "slots", ""));
	SimpleMacros_Loaded = 1;
	SimpleMacros_OnMacrosChanged();
	-- Older saves are written again in the short form (the old keys are removed).
	for i = 1, getn(old) do
		SimpleMacros_Storage_SaveMacro(old[i][1], old[i][2]);
	end
end

function SimpleMacros_Storage_Start()
	if ( SimpleSave_RegisterLoad ) then
		SimpleSave_RegisterLoad(SimpleMacros_Storage_Load);
	else
		SimpleMacros_Storage_Load();
		SimpleMacros_Print("|cffff4040Dependency missing: SimpleSave.|r Macros are not saved between sessions.");
	end
end
