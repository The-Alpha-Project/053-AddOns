-- Stand-ins for base functions the 0.5.3 client lacks (AlphaUI normally supplies them).
-- The client has no type() either, so none is used here.
if ( not tostring ) then
	tostring = function(value)
		if ( value == nil ) then
			return "";
		end
		if ( value == true ) then
			return "true";
		end
		if ( value == false ) then
			return "false";
		end
		return format("%s", value);
	end
end
if ( not tonumber ) then
	tonumber = function(value)
		if ( value == nil or value == true or value == false ) then
			return nil;
		end
		value = gsub(format("%s", value), "^%s+", "");
		value = gsub(value, "%s+$", "");
		if ( strfind(value, "^[-+]?%d+%.?%d*$") or strfind(value, "^[-+]?%d*%.%d+$") ) then
			return value + 0;
		end
		return nil;
	end
end
--------------------------------------------------------------------------------
-- SimpleSave for WoW 0.5.3
--
-- Shared save module for addons. 0.5.3 has no SavedVariables, but key bindings
-- are saved to bindings.wtf by SaveBindings() and read back at login. SimpleSave
-- stores addon data as made-up "key names" bound to the hidden commands
-- ADDONDATA1-40 from Interface\Bindings.xml, e.g.
--     bind s001Size.70+Alpha.85 ADDONDATA2
--
-- Format
--   * All data is one text: records "addon.name.value" joined with "+".
--     Letters and digits are kept, a space becomes "_", every other byte
--     becomes "=" + one lower case letter (common signs, see below) or
--     "=XX" (hex), so only A-Z a-z 0-9 _ . + = are ever written
--     (all tested in game). No "-" (it means a modifier key, e.g. CTRL-A).
--   * Format 2 (written since 1.17): every record keeps its own keys,
--     "t" + 2 character slot + 2 character part + payload (base 36, lower
--     case only), so a change rewrites only that record's keys instead of
--     every key after it. Key "t0000" is a header with the format, the
--     record count, the key count and a checksum of the whole text, so a
--     damaged or cut save is detected and never overwritten by accident.
--     Slot s, part p is bound to ADDONDATA(((s + p) mod 40) + 1), the
--     header to ADDONDATA1.
--   * Format 1 (1.16 and older, still read): the whole text cut into keys
--     "s" + 3 digit chunk number + payload, header chunk 000, chunk n bound
--     to ADDONDATA((n mod 40) + 1). It is replaced by format 2 at the first
--     save.
--
-- API for other addons (load SimpleSave first in FrameXML.toc)
--   SimpleSave_Get(addon, name [, default])        -> string or default
--   SimpleSave_GetNumber(addon, name [, default])  -> number or default
--   SimpleSave_Set(addon, name, value)             value: string, number or nil
--   SimpleSave_GetChar / SimpleSave_GetCharNumber / SimpleSave_SetChar
--                                                  same, per character
--   SimpleSave_ClearAddon(addon)
--   SimpleSave_IsLoaded()                          -> 1 when the save is read
--   SimpleSave_RegisterLoad(func)                  func() runs once the save
--                                                  is read (at once if already)
-- Changes are written about one second after the last Set (SaveBindings
-- writes the file at once), never while the Key Bindings window is open.
--------------------------------------------------------------------------------

-- Installed on its own and inside SimpleQoL: 0.5.3 keeps the frames of the
-- copy loaded first under their names, so no frame is hidden here (that hid
-- the frames in use). The newest version runs: a copy loaded after an equal
-- or newer version stops here, and the other copy's frames stop themselves.
local function SimpleSave_VersionValue(v)
	local s, e, major, minor = strfind(v or "", "^(%d+)%.?(%d*)");
	if ( not major ) then
		return 0;
	end
	return major * 1000 + (tonumber(minor) or 0);
end
if ( SIMPLESAVE_VERSION and SimpleSave_VersionValue(SIMPLESAVE_VERSION) >= SimpleSave_VersionValue("1.12") ) then
	return;
end
SIMPLESAVE_VERSION = "1.24";
SIMPLESAVE_FORMAT = "1";          -- old format (read only, see below)
SIMPLESAVE_FORMAT2 = "2";
SIMPLESAVE_B36 = "0123456789abcdefghijklmnopqrstuvwxyz";
SIMPLESAVE_MAX_SLOTS = 1295;       -- slot codes 01-zz (00 = header)
SIMPLESAVE_MAX_PARTS = 1296;       -- part codes 00-zz
SIMPLESAVE_COMMANDS = 40;          -- ADDONDATA1 .. ADDONDATA40
SIMPLESAVE_KEY_LENGTH = 30;        -- whole key; a 60 char key came back as 31
SIMPLESAVE_PAYLOAD = SIMPLESAVE_KEY_LENGTH - 4;
SIMPLESAVE_PAYLOAD2 = SIMPLESAVE_KEY_LENGTH - 5;
SIMPLESAVE_MAX_CHUNKS = 999;
SIMPLESAVE_WRITE_DELAY = 1.0;
SIMPLESAVE_STEP_COMMANDS = 8;      -- commands read per frame during a spread-out save
SIMPLESAVE_URGENT_GAP = 30;        -- settings: at most one disk write per 30 seconds (they apply in game at once)
SIMPLESAVE_AUTO_DELAY = 300;       -- data the addons collect by themselves: at most one write per 5 minutes
-- Values the addons collect by themselves while playing (addon, name start).
-- Everything else (settings the player changes) is written after 1 second.
SIMPLESAVE_AUTO = {
	{ "SimpleWalk", "" },
	{ "SimpleMap", "N" },
	{ "SimpleQoL", "Prices" },
	{ "SimpleQoL", "MaxLevel" },
	{ "SimpleQoL@", "Known" },
};
SIMPLESAVE_EXPORT_PART = 900;      -- characters per export part

SimpleSave_Data = {};              -- SimpleSave_Data[addon][name] = "value"
SimpleSave_Loaded = nil;
SimpleSave_Blocked = nil;          -- reason text when the saved data is damaged
SimpleSave_RawStream = nil;        -- damaged data kept for export
SimpleSave_Dirty = nil;
SimpleSave_DirtyTime = 0;
SimpleSave_Urgent = nil;          -- a setting changed: write after 1 second
SimpleSave_LastFlush = nil;        -- time of the last write
SimpleSave_Job = nil;              -- a save spread over several frames (see SimpleSave_JobStep)
SimpleSave_Writing = nil;
SimpleSave_LoadFuncs = SimpleSave_LoadFuncs or {};
SimpleSave_LastError = nil;
SimpleSave_Chunks = 0;
SimpleSave_SlotOf = {};            -- record id ("addon.name" encoded) -> slot
SimpleSave_SlotUsed = {};          -- slot -> record id
SimpleSave_KeyCount = 0;           -- data keys found by the last read
SimpleSave_Bytes = 0;
SimpleSave_KeyBindingsHooked = nil;
SimpleSave_LoadedEmpty = nil;      -- 1 while nothing was found at login


-- Quit fix, shared by all our 0.5.3 addons and always on: the normal Quit
-- often freezes the client, ForceQuit closes at once (settings are still
-- written). Whichever addon loads first installs it, only once.
if ( not SIMPLE_QUITFIX_DONE ) then
	SIMPLE_QUITFIX_DONE = 1;
	SimpleQuitFix_OrigQuit = Quit;
	Quit = function()
		if ( ForceQuit ) then
			ForceQuit();
		elseif ( SimpleQuitFix_OrigQuit ) then
			SimpleQuitFix_OrigQuit();
		end
	end;
end

-- Online signal, shared by all our 0.5.3 addons: once after login a short
-- "H1" message goes to a hidden password channel, and "B1" on Logout / Quit.
-- SimpleQoL shows these as "Name has come online / gone offline". The
-- channel never shows in the chat. Whichever addon loads first installs it,
-- and each addon calls SimpleHello_Tick() from an OnUpdate it already has.
if ( not SIMPLE_HELLO_DONE ) then
	SIMPLE_HELLO_DONE = 1;
	SIMPLE_HELLO_CHANNEL = "SimpleAddons";
	SIMPLE_HELLO_PASSWORD = "sAdd0nz7q";
	SimpleHello_Sent = nil;
	SimpleHello_Start = nil;
	SimpleHello_JoinTime = 0;
	SimpleHello_Last = 0;

	function SimpleHello_Channel(join)
		local number = GetChannelName and GetChannelName(SIMPLE_HELLO_CHANNEL);
		if ( number and number > 0 ) then
			return number;
		end
		if ( join and JoinChannelByName and GetTime() - SimpleHello_JoinTime > 15 ) then
			SimpleHello_JoinTime = GetTime();
			JoinChannelByName(SIMPLE_HELLO_CHANNEL, SIMPLE_HELLO_PASSWORD);
		end
		return nil;
	end

	function SimpleHello_Tick()
		if ( SimpleHello_Sent ) then
			SimpleHello_Tick = nil;
			return;
		end
		if ( GetTime() - SimpleHello_Last < 1 ) then
			return;
		end
		SimpleHello_Last = GetTime();
		-- A few seconds after entering the world, so the channel can be joined.
		if ( not SimpleHello_Start ) then
			SimpleHello_Start = GetTime();
		end
		if ( GetTime() - SimpleHello_Start < 5 ) then
			return;
		end
		local number = SimpleHello_Channel(1);
		if ( number ) then
			SimpleHello_Sent = 1;
			SendChatMessage("H1", "CHANNEL", nil, number);
			SimpleHello_Tick = nil;
		end
	end

	function SimpleHello_Bye()
		local number = SimpleHello_Channel();
		if ( number ) then
			SendChatMessage("B1", "CHANNEL", nil, number);
		end
	end

	SimpleHello_OrigLogout = Logout;
	Logout = function()
		SimpleHello_Bye();
		SimpleHello_OrigLogout();
	end;
	SimpleHello_OrigForceQuit = ForceQuit;
	ForceQuit = function()
		SimpleHello_Bye();
		SimpleHello_OrigForceQuit();
	end;

	SimpleHello_OrigChatOnEvent = ChatFrame_OnEvent;
	function ChatFrame_OnEvent(event)
		if ( strfind(event, "^CHAT_MSG_CHANNEL") and strfind(strlower((arg4 or "").." "..(arg9 or "")), "simpleaddons", 1, 1) ) then
			return;
		end
		SimpleHello_OrigChatOnEvent(event);
	end
end


-- 1 if Interface\Bindings.xml knows the command (GetBinding lists the
-- commands of the Key Bindings window; hidden ones are not listed).
function SimpleBindings_Has(command)
	if ( not GetNumBindings or not GetBinding ) then
		return 1;
	end
	local i;
	for i = 1, GetNumBindings() do
		if ( GetBinding(i) == command ) then
			return 1;
		end
	end
	return nil;
end

-- /sv lists the versions of all our installed addons. Every addon carries
-- this same copy, so it works with any of them installed.
function SimpleVersions_Show()
	local list = { "SimpleSave", SIMPLESAVE_VERSION, "SimpleQoL", SIMPLEQOL_VERSION, "ActionBars", ACTIONBARS_VERSION,
		"ImprovedErrorFrame", IEF_VERSION, "TradeSkillPlus", TRADESKILLPLUS_VERSION, "SimpleMap", SIMPLEMAP_VERSION,
		"SimpleChat", SIMPLECHAT_VERSION, "SimpleMacros", SIMPLEMACROS_VERSION, "SimpleWalk", SIMPLEWALK_VERSION };
	local i;
	for i = 1, 17, 2 do
		if ( list[i + 1] ) then
			ChatFrame:AddMessage(list[i].." "..list[i + 1], 1.0, 0.82, 0.0);
		end
	end
	-- Only GMs ever see anything of SimpleGM.
	if ( SIMPLEGM_VERSION and SimpleGM_State == 1 ) then
		ChatFrame:AddMessage("SimpleGM "..SIMPLEGM_VERSION, 1.0, 0.82, 0.0);
	end
end
SlashCmdList["SIMPLEVERSIONS"] = SimpleVersions_Show;
SLASH_SIMPLEVERSIONS1 = "/sv";
SLASH_SIMPLEVERSIONS2 = "/simpleversion";

SIMPLE_BINDINGS_WARNING = "|cffff4040Interface\\Bindings.xml from the zip is missing:|r key bindings for the extra bars and saving with SimpleSave will not work. Copy the Interface folder from the zip into the game folder and restart.";

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

function SimpleSave_Print(text)
	if ( ChatFrame ) then
		ChatFrame:AddMessage("SimpleSave: "..text, 1.0, 0.82, 0.0);
	end
end

SIMPLESAVE_HEX = "0123456789ABCDEF";
-- Short codes for common signs: "=" + a lower case letter. Hex escapes
-- always use upper case (0-9 A-F), so the two never mix.
SIMPLESAVE_SHORT_SIGNS = "\n/()-:,'%!.+=_#[]";
SIMPLESAVE_SHORT_CODES = "nsoqmkcapxdtehrgi";

-- 1 if the table has at least one entry (no "next" needed).
function SimpleSave_HasAny(list)
	local found = nil;
	foreach(list, function() found = 1; return 1; end);
	return found;
end

function SimpleSave_Hex2(byte)
	local high = floor(byte / 16);
	local low = byte - high * 16;
	return strsub(SIMPLESAVE_HEX, high + 1, high + 1)..strsub(SIMPLESAVE_HEX, low + 1, low + 1);
end

function SimpleSave_HexValue(char)
	if ( char == "" ) then
		return nil;
	end
	local position = strfind(SIMPLESAVE_HEX, char, 1, 1);
	if ( not position ) then
		return nil;
	end
	return position - 1;
end

-- gsub with a function does the work in C, so long texts stay fast.
function SimpleSave_EncodeChar(char)
	if ( char == " " ) then
		return "_";
	end
	local short = strfind(SIMPLESAVE_SHORT_SIGNS, char, 1, 1);
	if ( short ) then
		return "="..strsub(SIMPLESAVE_SHORT_CODES, short, short);
	end
	return "="..SimpleSave_Hex2(strbyte(char));
end

function SimpleSave_Encode(text)
	return (gsub(text, "[^A-Za-z0-9]", SimpleSave_EncodeChar));
end

SimpleSave_DecodeBad = nil;

-- token = the one or two characters after "=".
function SimpleSave_DecodeToken(token)
	local first = strsub(token, 1, 1);
	local rest = strsub(token, 2);
	if ( first == "" ) then
		SimpleSave_DecodeBad = 1;
		return "";
	end
	local short = strfind(SIMPLESAVE_SHORT_CODES, first, 1, 1);
	if ( short ) then
		return strsub(SIMPLESAVE_SHORT_SIGNS, short, short)..rest;
	end
	local high = SimpleSave_HexValue(first);
	local low = SimpleSave_HexValue(rest);
	if ( not high or not low ) then
		SimpleSave_DecodeBad = 1;
		return "";
	end
	return strchar(high * 16 + low);
end

-- Returns the decoded text, or nil if the text is not valid.
function SimpleSave_Decode(text)
	if ( strfind(text, "[^A-Za-z0-9_=]") ) then
		return nil;
	end
	SimpleSave_DecodeBad = nil;
	-- "_" first: escape tokens never contain "_", and their output is not
	-- scanned again, so nothing is decoded twice.
	local result = gsub(text, "_", " ");
	result = gsub(result, "=([A-Za-z0-9]?[A-Z0-9]?)", SimpleSave_DecodeToken);
	if ( SimpleSave_DecodeBad ) then
		return nil;
	end
	return result;
end

-- Addon names are shortened in the saved text ("SimpleQoL@Name" -> "Q" + "@Name")
-- to save keys. Old saves with the long names are still read.
SIMPLESAVE_ABBREV = { SimpleQoL = "Q", SimpleMap = "M", SimpleMacros = "X", SimpleChat = "C",
	SimpleWalk = "W", ActionBars = "A", IEF = "I", SimpleGM = "G" };
SIMPLESAVE_ABBREV_BACK = {};
foreach(SIMPLESAVE_ABBREV, function(name, code) SIMPLESAVE_ABBREV_BACK[code] = name; end);

function SimpleSave_EncodeAddon(addon)
	local at = strfind(addon, "@", 1, 1);
	local base = addon;
	local rest = "";
	if ( at ) then
		base = strsub(addon, 1, at - 1);
		rest = strsub(addon, at);
	end
	local code = SIMPLESAVE_ABBREV[base];
	if ( code ) then
		return code..SimpleSave_Encode(rest);
	end
	if ( SIMPLESAVE_ABBREV_BACK[base] ) then
		-- A real addon named like a code: its letter is escaped.
		return "="..SimpleSave_Hex2(strbyte(base, 1))..SimpleSave_Encode(strsub(base, 2))..SimpleSave_Encode(rest);
	end
	return SimpleSave_Encode(addon);
end

-- Returns the addon name, or nil if the text is not valid.
function SimpleSave_DecodeAddon(field)
	local s, e, lead = strfind(field, "^([A-Za-z0-9]*)");
	local rest = strsub(field, e + 1);
	local name = SIMPLESAVE_ABBREV_BACK[lead];
	if ( name and (rest == "" or strsub(rest, 1, 1) == "=") ) then
		rest = SimpleSave_Decode(rest);
		if ( not rest ) then
			return nil;
		end
		return name..rest;
	end
	return SimpleSave_Decode(field);
end

function SimpleSave_Checksum(text)
	local sum = 7;
	local length = strlen(text);
	local i;
	for i = 1, length do
		sum = mod(sum * 31 + strbyte(text, i), 65521);
	end
	return SimpleSave_Hex2(floor(sum / 256))..SimpleSave_Hex2(mod(sum, 256));
end

-- Splits text at every plain (not pattern) separator.
function SimpleSave_Split(text, separator)
	local list = {};
	local start = 1;
	local position;
	if ( text == "" ) then
		return list;
	end
	while ( 1 ) do
		position = strfind(text, separator, start, 1);
		if ( not position ) then
			tinsert(list, strsub(text, start));
			return list;
		end
		tinsert(list, strsub(text, start, position - 1));
		start = position + 1;
	end
end

-- Sorts a list of strings (no table.sort needed).
function SimpleSave_SortList(list)
	local count = getn(list);
	local i, j, value;
	for i = 2, count do
		value = list[i];
		j = i - 1;
		while ( j >= 1 and list[j] > value ) do
			list[j + 1] = list[j];
			j = j - 1;
		end
		list[j + 1] = value;
	end
end

function SimpleSave_Pad3(number)
	if ( number < 10 ) then
		return "00"..number;
	elseif ( number < 100 ) then
		return "0"..number;
	end
	return ""..number;
end

function SimpleSave_Command(chunk)
	return "ADDONDATA"..(mod(chunk, SIMPLESAVE_COMMANDS) + 1);
end

-- All keys currently bound to the ADDONDATA commands, as a list.
-- All keys bound to the ADDONDATA commands: map key -> command.
function SimpleSave_ReadKeyMap()
	local map = {};
	local i, j, found, command;
	for i = 1, SIMPLESAVE_COMMANDS do
		command = "ADDONDATA"..i;
		found = { GetBindingKey(command) };
		for j = 1, getn(found) do
			if ( found[j] and found[j] ~= "" ) then
				map[found[j]] = command;
			end
		end
	end
	return map;
end


--------------------------------------------------------------------------------
-- Data stream: SimpleSave_Data <-> one encoded text
--------------------------------------------------------------------------------

-- All records "addon.name.value" (encoded), sorted.
function SimpleSave_BuildRecords()
	local records = {};
	foreach(SimpleSave_Data, function(addon, values)
		foreach(values, function(name, value)
			tinsert(records, SimpleSave_EncodeAddon(addon).."."..SimpleSave_Encode(name).."."..SimpleSave_Encode(value));
		end);
	end);
	SimpleSave_SortList(records);
	return records;
end

-- The records joined with "+" (the text that is checksummed and exported).
-- Joined in pairs, so long texts are not copied over and over.
function SimpleSave_Join(records)
	local list = {};
	local i;
	for i = 1, getn(records) do
		list[i] = records[i];
	end
	local count = getn(list);
	while ( count > 1 ) do
		local out = 0;
		i = 1;
		while ( i <= count ) do
			out = out + 1;
			if ( i < count ) then
				list[out] = list[i].."+"..list[i + 1];
			else
				list[out] = list[i];
			end
			i = i + 2;
		end
		for i = out + 1, count do
			list[i] = nil;
		end
		count = out;
	end
	return list[1] or "";
end

--------------------------------------------------------------------------------
-- Fast path for saving: the same records, checksum and length as
-- BuildRecords + Join + Checksum, without redoing all the work every time.
--   * encoded names and values are kept and only redone when a value changed
--   * the sorted order only changes when values are added or removed (the
--     order is decided by "addon.name" alone: encoded names never contain ".")
--   * the checksum is put together from each record's own part, so the whole
--     text never has to be built (h(A+B) = h(A) * 31^len(B) + h0(B), mod 65521)
--------------------------------------------------------------------------------

SimpleSave_EncCache = {};          -- text -> encoded text (value names)
SimpleSave_AddonCache = {};        -- addon -> encoded addon
SimpleSave_RecCache = {};          -- id "addon.name" -> { value, record, hash, power }
SimpleSave_SortedIds = nil;        -- sorted ids of the last fast build

function SimpleSave_EncodeCached(text)
	local e = SimpleSave_EncCache[text];
	if ( not e ) then
		e = SimpleSave_Encode(text);
		SimpleSave_EncCache[text] = e;
	end
	return e;
end

function SimpleSave_EncodeAddonCached(addon)
	local e = SimpleSave_AddonCache[addon];
	if ( not e ) then
		e = SimpleSave_EncodeAddon(addon);
		SimpleSave_AddonCache[addon] = e;
	end
	return e;
end

-- Hash part of one text starting from 0, and 31^length (both mod 65521).
function SimpleSave_HashPart(text)
	local sum = 0;
	local power = 1;
	local i;
	for i = 1, strlen(text) do
		sum = mod(sum * 31 + strbyte(text, i), 65521);
		power = mod(power * 31, 65521);
	end
	return sum, power;
end

-- Returns records (sorted), the checksum text and the length of the joined text.
function SimpleSave_FastRecords()
	local seen = {};
	local count = 0;
	local added = nil;
	foreach(SimpleSave_Data, function(addon, values)
		local ea = SimpleSave_EncodeAddonCached(addon);
		foreach(values, function(name, value)
			local id = ea.."."..SimpleSave_EncodeCached(name);
			local c = SimpleSave_RecCache[id];
			if ( not c ) then
				c = {};
				SimpleSave_RecCache[id] = c;
				added = 1;
			end
			if ( c.value ~= value ) then
				c.value = value;
				c.record = id.."."..SimpleSave_Encode(value);
				c.hash, c.power = SimpleSave_HashPart(c.record);
			end
			seen[id] = 1;
			count = count + 1;
		end);
	end);
	-- Removed values leave the cache.
	local removed = nil;
	foreach(SimpleSave_RecCache, function(id)
		if ( not seen[id] ) then
			SimpleSave_RecCache[id] = nil;
			removed = 1;
		end
	end);
	if ( added or removed or not SimpleSave_SortedIds or getn(SimpleSave_SortedIds) ~= count ) then
		local ids = {};
		foreach(seen, function(id) tinsert(ids, id); end);
		SimpleSave_SortList(ids);
		SimpleSave_SortedIds = ids;
	end
	local records = {};
	local sum = 7;
	local length = 0;
	local i, c;
	for i = 1, getn(SimpleSave_SortedIds) do
		c = SimpleSave_RecCache[SimpleSave_SortedIds[i]];
		if ( i > 1 ) then
			sum = mod(sum * 31 + 43, 65521);   -- "+"
			length = length + 1;
		end
		sum = mod(sum * c.power + c.hash, 65521);
		length = length + strlen(c.record);
		records[i] = c.record;
	end
	return records, SimpleSave_Hex2(floor(sum / 256))..SimpleSave_Hex2(mod(sum, 256)), length;
end

function SimpleSave_BuildStream()
	return SimpleSave_Join(SimpleSave_BuildRecords());
end

-- "addon.name" part of a record (encoded parts never contain ".").
function SimpleSave_RecordId(record)
	local s, e, id = strfind(record, "^([^.]*%.[^.]*)%.");
	return id;
end

function SimpleSave_B36(number)
	local high = floor(number / 36);
	local low = number - high * 36;
	return strsub(SIMPLESAVE_B36, high + 1, high + 1)..strsub(SIMPLESAVE_B36, low + 1, low + 1);
end

-- Value of a 2 character base 36 code, or nil.
function SimpleSave_B36Value(code)
	local high = strfind(SIMPLESAVE_B36, strsub(code, 1, 1), 1, 1);
	local low = strfind(SIMPLESAVE_B36, strsub(code, 2, 2), 1, 1);
	if ( not high or not low or strlen(code) ~= 2 ) then
		return nil;
	end
	return (high - 1) * 36 + low - 1;
end

-- Returns a data table, or nil and an error text.
function SimpleSave_ParseStream(stream)
	local data = {};
	local records = SimpleSave_Split(stream, "+");
	local i, fields, addon, name, value;
	for i = 1, getn(records) do
		fields = SimpleSave_Split(records[i], ".");
		if ( getn(fields) ~= 3 ) then
			return nil, "bad record "..i;
		end
		addon = SimpleSave_DecodeAddon(fields[1]);
		name = SimpleSave_Decode(fields[2]);
		value = SimpleSave_Decode(fields[3]);
		if ( not addon or not name or not value ) then
			return nil, "bad text in record "..i;
		end
		if ( not data[addon] ) then
			data[addon] = {};
		end
		data[addon][name] = value;
	end
	return data;
end

-- The keys (in chunk order, header first) for a stream.
-- The keys for the records: map key -> command, and the number of keys.
-- Every record keeps the slot it had, so unchanged records keep their keys.
-- Returns nil and an error text when the data does not fit.
function SimpleSave_BuildKeys(records, checksum)
	local present = {};
	local i;
	for i = 1, getn(records) do
		present[SimpleSave_RecordId(records[i])] = 1;
	end
	-- Slots of removed records are free again.
	foreach(SimpleSave_SlotOf, function(id, slot)
		if ( not present[id] ) then
			SimpleSave_SlotOf[id] = nil;
			SimpleSave_SlotUsed[slot] = nil;
		end
	end);
	local wanted = {};
	local count = 1;
	local parts = 0;
	local free = 1;
	local record, id, slot, n, p, code;
	for i = 1, getn(records) do
		record = records[i];
		id = SimpleSave_RecordId(record);
		slot = SimpleSave_SlotOf[id];
		if ( not slot ) then
			while ( free <= SIMPLESAVE_MAX_SLOTS and SimpleSave_SlotUsed[free] ) do
				free = free + 1;
			end
			if ( free > SIMPLESAVE_MAX_SLOTS ) then
				return nil, "too many saved values ("..getn(records)..")";
			end
			slot = free;
			SimpleSave_SlotOf[id] = slot;
			SimpleSave_SlotUsed[slot] = id;
		end
		n = ceil(strlen(record) / SIMPLESAVE_PAYLOAD2);
		if ( n > SIMPLESAVE_MAX_PARTS ) then
			return nil, "one value is too long ("..strlen(record).." characters)";
		end
		code = "t"..SimpleSave_B36(slot);
		for p = 0, n - 1 do
			wanted[code..SimpleSave_B36(p)..strsub(record, p * SIMPLESAVE_PAYLOAD2 + 1, (p + 1) * SIMPLESAVE_PAYLOAD2)] = SimpleSave_Command(slot + p);
		end
		count = count + n;
		parts = parts + n;
	end
	wanted["t0000"..SIMPLESAVE_FORMAT2.."."..getn(records).."."..parts.."."..checksum] = SimpleSave_Command(0);
	return wanted, count;
end

-- Reads the bound keys (format 2, else format 1). Returns:
--   "empty"            nothing saved yet
--   "ok", stream       a complete, valid save
--   "bad", text, raw   damaged (text = reason, raw = what could be read)
-- and, for format 2, a map record id -> slot as fourth value.
function SimpleSave_ReadStream()
	local map = SimpleSave_ReadKeyMap();
	local new = nil;
	SimpleSave_KeyCount = 0;
	foreach(map, function(key)
		if ( strfind(key, "^t%w%w%w%w") ) then
			new = 1;
		end
		if ( strfind(key, "^[st]%w%w%w") ) then
			SimpleSave_KeyCount = SimpleSave_KeyCount + 1;
		end
	end);
	if ( new ) then
		return SimpleSave_ReadStream2(map);
	end
	return SimpleSave_ReadStream1(map);
end

function SimpleSave_ReadStream2(map)
	local header = nil;
	local slots = {};
	local bad = nil;
	foreach(map, function(key)
		local s, e, slotCode, partCode, payload = strfind(key, "^t(%w%w)(%w%w)(.*)$");
		if ( not slotCode ) then
			return;
		end
		if ( slotCode == "00" and partCode == "00" ) then
			header = payload;
			return;
		end
		local slot = SimpleSave_B36Value(slotCode);
		local part = SimpleSave_B36Value(partCode);
		if ( not slot or not part or slot == 0 ) then
			bad = "unknown key '"..key.."'";
			return;
		end
		if ( not slots[slot] ) then
			slots[slot] = {};
		end
		slots[slot][part + 1] = payload;
	end);
	local records = {};
	local ids = {};
	local parts = 0;
	foreach(slots, function(slot, list)
		local found = 0;
		foreach(list, function() found = found + 1; end);
		local record = "";
		local p = 1;
		while ( list[p] ) do
			record = record..list[p];
			p = p + 1;
		end
		if ( p - 1 ~= found ) then
			bad = "a key of value "..slot.." is missing";
		end
		parts = parts + found;
		tinsert(records, record);
		local id = SimpleSave_RecordId(record);
		if ( id ) then
			ids[id] = slot;
		end
	end);
	SimpleSave_SortList(records);
	local stream = SimpleSave_Join(records);
	if ( bad ) then
		return "bad", bad, stream;
	end
	if ( not header ) then
		return "bad", "the header is missing", stream;
	end
	local s, e, count, keys, checksum = strfind(header, "^"..SIMPLESAVE_FORMAT2.."%.(%d+)%.(%d+)%.(%x%x%x%x)$");
	if ( not count ) then
		return "bad", "unknown header '"..header.."'", stream;
	end
	if ( count + 0 ~= getn(records) or keys + 0 ~= parts ) then
		return "bad", "keys are missing ("..parts.." of "..keys..")", stream;
	end
	if ( SimpleSave_Checksum(stream) ~= checksum ) then
		return "bad", "the checksum does not match (cut or changed data)", stream;
	end
	return "ok", stream, nil, ids;
end

function SimpleSave_ReadStream1(map)
	local keys = {};
	foreach(map, function(key) tinsert(keys, key); end);
	local parts = {};
	local header = nil;
	local any = nil;
	local i, s, e, number, payload;
	for i = 1, getn(keys) do
		s, e, number, payload = strfind(keys[i], "^s(%d%d%d)(.*)$");
		if ( number ) then
			any = 1;
			number = number + 0;
			if ( number == 0 ) then
				header = payload;
			else
				parts[number] = payload;
			end
		end
	end
	if ( not any ) then
		return "empty";
	end
	local raw = "";
	local n = 1;
	while ( parts[n] ) do
		raw = raw..parts[n];
		n = n + 1;
	end
	if ( not header ) then
		return "bad", "the header is missing", raw;
	end
	local count, checksum;
	s, e, count, checksum = strfind(header, "^"..SIMPLESAVE_FORMAT.."%.(%d+)%.(%x%x%x%x)$");
	if ( not count ) then
		return "bad", "unknown header '"..header.."'", raw;
	end
	count = count + 0;
	local stream = "";
	for i = 1, count do
		if ( not parts[i] ) then
			return "bad", "part "..i.." of "..count.." is missing", raw;
		end
		stream = stream..parts[i];
	end
	if ( SimpleSave_Checksum(stream) ~= checksum ) then
		return "bad", "the checksum does not match (cut or changed data)", stream;
	end
	return "ok", stream;
end


--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------

function SimpleSave_Load()
	local state, stream, raw, ids = SimpleSave_ReadStream();
	SimpleSave_LoadedEmpty = nil;
	SimpleSave_SlotOf = {};
	SimpleSave_SlotUsed = {};
	if ( state == "empty" ) then
		SimpleSave_Data = {};
		SimpleSave_Chunks = 0;
		SimpleSave_Bytes = 0;
		SimpleSave_LoadedEmpty = 1;
	elseif ( state == "ok" ) then
		local data, err = SimpleSave_ParseStream(stream);
		if ( not data ) then
			SimpleSave_SetBlocked(err, stream);
			return;
		end
		SimpleSave_Data = data;
		-- Format 2: keep the slots, so the next save only rewrites changes.
		if ( ids ) then
			foreach(ids, function(id, slot)
				SimpleSave_SlotOf[id] = slot;
				SimpleSave_SlotUsed[slot] = id;
			end);
		end
		SimpleSave_Chunks = SimpleSave_KeyCount - 1;
		SimpleSave_Bytes = strlen(stream);
		if ( SimpleSave_Migrate(ids) ) then
			-- Written again soon, in the short format.
			SimpleSave_MarkDirty();
		end
		SimpleSave_WarnFull();
	else
		SimpleSave_SetBlocked(stream, raw);
		return;
	end
	SimpleSave_Blocked = nil;
	SimpleSave_RawStream = nil;
	SimpleSave_FinishLoad();
end

-- Damaged save: nothing is overwritten until the user decides (/ssave).
-- Addons still get their default values and can work for this session.
function SimpleSave_SetBlocked(reason, raw)
	SimpleSave_Blocked = reason;
	SimpleSave_RawStream = raw;
	SimpleSave_Data = {};
	SimpleSave_Print("|cffff4040the saved addon data could not be read ("..reason..").|r Nothing will be saved until you choose: /ssave import (restore a backup) or /ssave reset (start empty).");
	SimpleSave_FinishLoad();
end

function SimpleSave_FinishLoad()
	if ( SimpleSave_Loaded ) then
		return;
	end
	SimpleSave_Loaded = 1;
	local funcs = SimpleSave_LoadFuncs;
	SimpleSave_LoadFuncs = {};
	local i;
	for i = 1, getn(funcs) do
		funcs[i]();
	end
end

function SimpleSave_IsLoaded()
	return SimpleSave_Loaded;
end

function SimpleSave_RegisterLoad(func)
	if ( SimpleSave_Loaded ) then
		func();
	else
		tinsert(SimpleSave_LoadFuncs, func);
	end
end


--------------------------------------------------------------------------------
-- Capacity, usage and clean-up
--------------------------------------------------------------------------------

-- Keys one value needs (the whole record is cut into pieces of 25 characters).
function SimpleSave_RecordKeys(addon, name, value)
	local n = strlen(SimpleSave_EncodeAddon(addon)) + strlen(SimpleSave_Encode(name)) + strlen(SimpleSave_Encode(value)) + 2;
	return ceil(n / SIMPLESAVE_PAYLOAD2);
end

-- Keys used now by all data (without the header key).
function SimpleSave_KeysNeeded()
	local total = 0;
	local records = SimpleSave_FastRecords();
	local i;
	for i = 1, getn(records) do
		total = total + ceil(strlen(records[i]) / SIMPLESAVE_PAYLOAD2);
	end
	return total;
end

-- 1 when the current data fits (checked before a save is promised to the player).
function SimpleSave_WouldFit()
	if ( not SimpleSave_Loaded or SimpleSave_Blocked ) then
		return nil;
	end
	return SimpleSave_KeysNeeded() <= SIMPLESAVE_MAX_CHUNKS and 1 or nil;
end

-- Name of the character in an "addon@Name" key, or nil.
function SimpleSave_CharOf(addon)
	local at = strfind(addon, "@", 1, 1);
	if ( at ) then
		return strsub(addon, at + 1);
	end
	return nil;
end

-- Biggest users of the space: { { text, keys }, ... } sorted, biggest first.
-- All characters together count as one line.
function SimpleSave_UsageList()
	local groups = {};
	local order = {};
	foreach(SimpleSave_Data, function(addon, values)
		local label = addon;
		if ( SimpleSave_CharOf(addon) ) then
			label = "characters";
		end
		if ( not groups[label] ) then
			groups[label] = 0;
			tinsert(order, label);
		end
		foreach(values, function(name, value)
			groups[label] = groups[label] + SimpleSave_RecordKeys(addon, name, value);
		end);
	end);
	local list = {};
	local i, j, entry;
	for i = 1, getn(order) do
		entry = { order[i], groups[order[i]] };
		j = getn(list);
		tinsert(list, entry);
		while ( j >= 1 and list[j][2] < entry[2] ) do
			list[j + 1] = list[j];
			list[j] = entry;
			j = j - 1;
		end
	end
	return list;
end

-- Characters with saved data: { { name, keys, entries }, ... }, biggest first.
function SimpleSave_CharList()
	local chars = {};
	local order = {};
	foreach(SimpleSave_Data, function(addon, values)
		local who = SimpleSave_CharOf(addon);
		if ( who ) then
			if ( not chars[who] ) then
				chars[who] = { who, 0, 0 };
				tinsert(order, who);
			end
			foreach(values, function(name, value)
				chars[who][2] = chars[who][2] + SimpleSave_RecordKeys(addon, name, value);
				chars[who][3] = chars[who][3] + 1;
			end);
		end
	end);
	local list = {};
	local i, j, entry;
	for i = 1, getn(order) do
		entry = chars[order[i]];
		tinsert(list, entry);
		j = getn(list) - 1;
		while ( j >= 1 and list[j][2] < entry[2] ) do
			list[j + 1] = list[j];
			list[j] = entry;
			j = j - 1;
		end
	end
	return list;
end

-- Removes all saved data of one character (who = name) or of every character
-- except the current one (who = nil). Returns the number of values removed.
function SimpleSave_ForgetChars(who)
	local current = UnitName("player");
	local remove = {};
	foreach(SimpleSave_Data, function(addon)
		local c = SimpleSave_CharOf(addon);
		if ( c ) then
			if ( who and strlower(c) == strlower(who) ) then
				tinsert(remove, addon);
			elseif ( not who and c ~= current ) then
				tinsert(remove, addon);
			end
		end
	end);
	local count = 0;
	local i;
	for i = 1, getn(remove) do
		foreach(SimpleSave_Data[remove[i]], function() count = count + 1; end);
		SimpleSave_Data[remove[i]] = nil;
	end
	if ( count > 0 ) then
		SimpleSave_MarkDirty();
	end
	return count;
end

-- Values that older versions saved and nothing uses any more.
SIMPLESAVE_OBSOLETE = { "AUIPortraits", "AUIClock" };

-- Called once after the save is read. Returns 1 when something was removed
-- or the save still has the long addon names (it is then written again).
function SimpleSave_Migrate(ids)
	local changed = nil;
	local remove = {};
	foreach(SimpleSave_Data, function(addon, values)
		if ( strfind(addon, "^SimpleQoL@") ) then
			local i;
			for i = 1, getn(SIMPLESAVE_OBSOLETE) do
				if ( values[SIMPLESAVE_OBSOLETE[i]] ~= nil ) then
					values[SIMPLESAVE_OBSOLETE[i]] = nil;
					changed = 1;
				end
			end
			if ( not SimpleSave_HasAny(values) ) then
				tinsert(remove, addon);
			end
		end
	end);
	local i;
	for i = 1, getn(remove) do
		SimpleSave_Data[remove[i]] = nil;
	end
	-- Old save: the ids still start with a long addon name.
	if ( ids ) then
		foreach(ids, function(id)
			local s, e, lead = strfind(id, "^(%a+)");
			if ( lead and SIMPLESAVE_ABBREV[lead] ) then
				changed = 1;
			end
		end);
	end
	return changed;
end

-- Chat and screen message when a save fails, with what takes the space.
function SimpleSave_Fail(reason)
	SimpleSave_LastError = reason;
	SimpleSave_FailTime = GetTime();
	local text = reason;
	if ( strfind(reason, "^too much data") ) then
		local list = SimpleSave_UsageList();
		local top = "";
		local i;
		for i = 1, min(3, getn(list)) do
			if ( i > 1 ) then
				top = top..", ";
			end
			top = top..list[i][1].." "..list[i][2];
		end
		text = reason.." - the biggest users (keys): "..top..". /ssave chars shows the characters, /ssave forget <name> removes one";
	end
	SimpleSave_Print("|cffff4040could not save: "..text.."|r");
	if ( UIErrorsFrame ) then
		UIErrorsFrame:AddMessage("SimpleSave: your settings could NOT be saved ("..reason..")", 1.0, 0.1, 0.1, 1.0, UIERRORS_HOLD_TIME or 5);
	end
end

-- Warns once per session when the space is nearly used up.
function SimpleSave_WarnFull()
	local percent = floor(SimpleSave_Chunks * 100 / SIMPLESAVE_MAX_CHUNKS + 0.5);
	if ( percent >= 85 and not SimpleSave_WarnedFull ) then
		SimpleSave_WarnedFull = 1;
		SimpleSave_Print("|cffffa040the save is "..percent.."% full.|r /ssave shows what takes the space.");
	end
end


--------------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------------

-- Binds exactly the keys for the current data and removes old ones.
-- Returns 1 if the bindings now hold the data (checked by reading them back).
function SimpleSave_WriteKeys()
	local records, checksum, length = SimpleSave_FastRecords();
	local wanted, count = SimpleSave_BuildKeys(records, checksum);
	if ( not wanted ) then
		SimpleSave_LastError = count;
		return nil;
	end
	if ( count - 1 > SIMPLESAVE_MAX_CHUNKS ) then
		SimpleSave_LastError = "too much data ("..length.." characters, "..(count - 1).." of "..SIMPLESAVE_MAX_CHUNKS.." keys)";
		return nil;
	end
	-- Other addons (SimpleMacros) skip the key binding events of this write.
	SimpleSave_LastWrite = GetTime();
	SimpleSave_Writing = 1;
	-- Only keys that differ are touched: old ones (other values, old format,
	-- test keys, leftovers) are removed, missing ones are added.
	local have = SimpleSave_ReadKeyMap();
	local changed = nil;
	foreach(have, function(key, command)
		if ( wanted[key] ~= command ) then
			SetBinding(key);
			changed = 1;
		end
	end);
	foreach(wanted, function(key, command)
		if ( have[key] ~= command ) then
			SetBinding(key, command);
			changed = 1;
		end
	end);
	SimpleSave_KeysChanged = changed;
	if ( not changed ) then
		-- Nothing differs: the file already holds this data.
		SimpleSave_Writing = nil;
		SimpleSave_Chunks = count - 1;
		SimpleSave_Bytes = length;
		SimpleSave_LastError = nil;
		return 1;
	end
	SimpleSave_Writing = nil;
	-- Read back: exactly the wanted keys must be bound now.
	local now = SimpleSave_ReadKeyMap();
	local ok = 1;
	local found = 0;
	foreach(now, function(key, command)
		found = found + 1;
		if ( wanted[key] ~= command ) then
			ok = nil;
		end
	end);
	if ( ok and found == count ) then
		SimpleSave_Chunks = count - 1;
		SimpleSave_Bytes = length;
		SimpleSave_LastError = nil;
		return 1;
	end
	SimpleSave_LastError = "the client did not keep all keys ("..count.." keys)";
	return nil;
end

function SimpleSave_Flush()
	if ( not SimpleSave_Loaded or SimpleSave_Blocked ) then
		return;
	end
	-- Saving now would also save unconfirmed changes in the Key Bindings
	-- window; wait until it is closed.
	if ( KeyBindingFrame and KeyBindingFrame:IsVisible() ) then
		return;
	end
	-- Safety: if nothing was found at login but saved keys exist now (bindings
	-- read late), load them first and put this session's changes on top,
	-- instead of removing them.
	if ( SimpleSave_LoadedEmpty and SimpleSave_ReadStream() ~= "empty" ) then
		SimpleSave_LateLoad();
		if ( SimpleSave_Blocked ) then
			return;
		end
	end
	SimpleSave_Job = nil;
	SimpleSave_Dirty = nil;
	SimpleSave_Urgent = nil;
	SimpleSave_LastFlush = GetTime();
	if ( SimpleSave_WriteKeys() ) then
		SimpleSave_LoadedEmpty = nil;
		-- Writing the file is the slow part: only when a key really changed.
		if ( SimpleSave_KeysChanged ) then
			SaveBindings();
			SimpleSave_LastWrite = GetTime();
		end
	else
		SimpleSave_Fail(SimpleSave_LastError or "unknown error");
	end
end

--------------------------------------------------------------------------------
-- Spread-out save: the same work as SimpleSave_Flush, but one small step per
-- frame (read 8 commands, change 1 key, ...) so saving causes no lag spike.
-- Nothing reaches the file before the last step (SaveBindings), so a crash in
-- between leaves the previous save. Quit, Logout and loading screens still use
-- SimpleSave_Flush, which finishes everything at once.
--------------------------------------------------------------------------------

function SimpleSave_CanWrite()
	if ( not SimpleSave_Loaded or SimpleSave_Blocked ) then
		return nil;
	end
	if ( KeyBindingFrame and KeyBindingFrame:IsVisible() ) then
		return nil;
	end
	return 1;
end

function SimpleSave_StartJob()
	if ( not SimpleSave_CanWrite() ) then
		return;
	end
	-- Rare case (bindings read late): do it all at once as before.
	if ( SimpleSave_LoadedEmpty ) then
		SimpleSave_Flush();
		return;
	end
	SimpleSave_Dirty = nil;
	SimpleSave_Urgent = nil;
	SimpleSave_LastFlush = GetTime();
	local records, checksum, length = SimpleSave_FastRecords();
	local wanted, count = SimpleSave_BuildKeys(records, checksum);
	if ( not wanted ) then
		SimpleSave_Fail(count or "unknown error");
		return;
	end
	if ( count - 1 > SIMPLESAVE_MAX_CHUNKS ) then
		SimpleSave_Fail("too much data ("..length.." characters, "..(count - 1).." of "..SIMPLESAVE_MAX_CHUNKS.." keys)");
		return;
	end
	SimpleSave_Job = { step = "read", command = 1, have = {}, wanted = wanted, count = count, bytes = length };
end

-- Reads the next commands into map; returns 1 when all 40 are read.
function SimpleSave_JobRead(job, map)
	local last = min(job.command + SIMPLESAVE_STEP_COMMANDS - 1, SIMPLESAVE_COMMANDS);
	local i, j, found, command;
	for i = job.command, last do
		command = "ADDONDATA"..i;
		found = { GetBindingKey(command) };
		for j = 1, getn(found) do
			if ( found[j] and found[j] ~= "" ) then
				map[found[j]] = command;
			end
		end
	end
	job.command = last + 1;
	return job.command > SIMPLESAVE_COMMANDS;
end

function SimpleSave_JobStep()
	local job = SimpleSave_Job;
	if ( not SimpleSave_CanWrite() ) then
		-- Key Bindings window opened: try again later.
		SimpleSave_Job = nil;
		SimpleSave_MarkDirty();
		return;
	end
	if ( job.step == "read" ) then
		if ( SimpleSave_JobRead(job, job.have) ) then
			-- Old keys are removed first, then the new ones are added.
			job.changes = {};
			foreach(job.have, function(key, command)
				if ( job.wanted[key] ~= command ) then
					tinsert(job.changes, { key });
				end
			end);
			foreach(job.wanted, function(key, command)
				if ( job.have[key] ~= command ) then
					tinsert(job.changes, { key, command });
				end
			end);
			if ( getn(job.changes) == 0 ) then
				-- The file already holds this data.
				SimpleSave_Job = nil;
				SimpleSave_LoadedEmpty = nil;
				return;
			end
			job.step = "write";
			job.index = 1;
		end
	elseif ( job.step == "write" ) then
		local change = job.changes[job.index];
		-- Other addons (SimpleMacros) skip the key binding events of this write.
		SimpleSave_LastWrite = GetTime();
		SimpleSave_Writing = 1;
		if ( change[2] ) then
			SetBinding(change[1], change[2]);
		else
			SetBinding(change[1]);
		end
		SimpleSave_Writing = nil;
		job.index = job.index + 1;
		if ( job.index > getn(job.changes) ) then
			job.step = "check";
			job.command = 1;
			job.now = {};
		end
	elseif ( job.step == "check" ) then
		if ( SimpleSave_JobRead(job, job.now) ) then
			-- Read back: exactly the wanted keys must be bound now.
			local ok = 1;
			local found = 0;
			foreach(job.now, function(key, command)
				found = found + 1;
				if ( job.wanted[key] ~= command ) then
					ok = nil;
				end
			end);
			if ( ok and found == job.count ) then
				SimpleSave_Chunks = job.count - 1;
				SimpleSave_Bytes = job.bytes;
				SimpleSave_LastError = nil;
				SimpleSave_WarnFull();
				job.step = "save";
			else
				SimpleSave_Job = nil;
				SimpleSave_Fail("the client did not keep all keys ("..job.count.." keys)");
			end
		end
	elseif ( job.step == "save" ) then
		SimpleSave_Job = nil;
		SimpleSave_LoadedEmpty = nil;
		SaveBindings();
		SimpleSave_LastWrite = GetTime();
	end
end

-- Saved keys showed up after login: load them and put this session's
-- changes on top.
function SimpleSave_LateLoad()
	local pending = SimpleSave_Data;
	SimpleSave_Loaded = nil;
	SimpleSave_Load();
	if ( SimpleSave_Blocked ) then
		return;
	end
	foreach(pending, function(addon, values)
		foreach(values, function(name, value)
			SimpleSave_Set(addon, name, value);
		end);
	end);
end

-- 1 when the value is data an addon collects by itself (see SIMPLESAVE_AUTO).
function SimpleSave_IsAuto(addon, name)
	local i, entry;
	for i = 1, getn(SIMPLESAVE_AUTO) do
		entry = SIMPLESAVE_AUTO[i];
		if ( strsub(addon, 1, strlen(entry[1])) == entry[1] and strsub(name, 1, strlen(entry[2])) == entry[2] ) then
			-- "SimpleQoL" must not match "SimpleQoL@Name" (per character).
			if ( strlen(addon) == strlen(entry[1]) or strsub(entry[1], -1) == "@" ) then
				return 1;
			end
		end
	end
	return nil;
end

function SimpleSave_MarkDirty(addon, name)
	SimpleSave_Dirty = 1;
	SimpleSave_DirtyTime = GetTime();
	if ( not addon or not SimpleSave_IsAuto(addon, name) ) then
		SimpleSave_Urgent = 1;
	end
end


--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function SimpleSave_Get(addon, name, default)
	local values = SimpleSave_Data[addon];
	if ( values and values[name] ) then
		return values[name];
	end
	return default;
end

function SimpleSave_GetNumber(addon, name, default)
	local value = SimpleSave_Get(addon, name, nil);
	if ( value ) then
		local s, e, number = strfind(value, "^(%-?%d+%.?%d*)$");
		if ( number ) then
			return number + 0;
		end
	end
	return default;
end

function SimpleSave_Set(addon, name, value)
	if ( not addon or not name ) then
		return;
	end
	addon = ""..addon;
	name = ""..name;
	if ( value ~= nil ) then
		value = ""..value;
	end
	local values = SimpleSave_Data[addon];
	if ( value == nil ) then
		if ( not values or values[name] == nil ) then
			return;
		end
		values[name] = nil;
		if ( not SimpleSave_HasAny(values) ) then
			SimpleSave_Data[addon] = nil;
		end
	else
		if ( not values ) then
			values = {};
			SimpleSave_Data[addon] = values;
		end
		if ( values[name] == value ) then
			return;
		end
		values[name] = value;
	end
	SimpleSave_MarkDirty(addon, name);
end

function SimpleSave_ClearAddon(addon)
	if ( SimpleSave_Data[addon] ) then
		SimpleSave_Data[addon] = nil;
		SimpleSave_MarkDirty();
	end
end

-- Per character: stored under "addon@CharacterName".
function SimpleSave_CharAddon(addon)
	return addon.."@"..(UnitName("player") or "?");
end

function SimpleSave_GetChar(addon, name, default)
	return SimpleSave_Get(SimpleSave_CharAddon(addon), name, default);
end

function SimpleSave_GetCharNumber(addon, name, default)
	return SimpleSave_GetNumber(SimpleSave_CharAddon(addon), name, default);
end

function SimpleSave_SetChar(addon, name, value)
	SimpleSave_Set(SimpleSave_CharAddon(addon), name, value);
end


--------------------------------------------------------------------------------
-- Key Bindings window protection
--   "Reset To Default" calls DefaultBindings(), which would remove the data
--   keys. SimpleSave puts them back right after, so Okay saves them again and
--   Cancel restores the file (which still has them).
--------------------------------------------------------------------------------

function SimpleSave_HookBindings()
	if ( SimpleSave_KeyBindingsHooked or not DefaultBindings ) then
		return;
	end
	SimpleSave_KeyBindingsHooked = 1;
	SimpleSave_Orig_DefaultBindings = DefaultBindings;
	DefaultBindings = function()
		SimpleSave_Orig_DefaultBindings();
		if ( SimpleSave_Loaded and not SimpleSave_Blocked ) then
			SimpleSave_Job = nil;
			SimpleSave_WriteKeys();
			if ( KeyBindingFrameOutputText ) then
				KeyBindingFrameOutputText:SetText("Addon settings were kept (SimpleSave).");
			end
		end
	end
	-- Write pending changes before the game closes.
	SimpleSave_Orig_ForceQuit = ForceQuit;
	if ( ForceQuit ) then
		ForceQuit = function()
			SimpleSave_Flush();
			SimpleSave_Orig_ForceQuit();
		end
	end
	SimpleSave_Orig_Quit = Quit;
	if ( Quit ) then
		Quit = function()
			SimpleSave_Flush();
			SimpleSave_Orig_Quit();
		end
	end
	SimpleSave_Orig_Logout = Logout;
	if ( Logout ) then
		Logout = function()
			SimpleSave_Flush();
			SimpleSave_Orig_Logout();
		end
	end
end


--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function SimpleSave_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("UPDATE_BINDINGS");
	this:RegisterEvent("PLAYER_QUITING");
	this:RegisterEvent("PLAYER_CAMPING");
	this:RegisterEvent("PLAYER_LEAVING_WORLD");
	SlashCmdList["SIMPLESAVE"] = SimpleSave_Slash;
	SLASH_SIMPLESAVE1 = "/ssave";
	SLASH_SIMPLESAVE2 = "/simplesave";
	SLASH_SIMPLESAVE3 = "/ss";
end

-- The ADDONDATA commands are hidden, so the visible ADDONKEY1 from the same
-- Bindings.xml is checked instead.
function SimpleSave_CheckBindings()
	if ( SimpleSave_BindingsChecked ) then
		return;
	end
	SimpleSave_BindingsChecked = 1;
	SimpleSave_BindingsMissing = not SimpleBindings_Has("ADDONKEY1");
	-- Shown once, even when several of our addons notice it.
	if ( SimpleSave_BindingsMissing and not SIMPLE_BINDINGS_WARNED ) then
		SIMPLE_BINDINGS_WARNED = 1;
		SimpleSave_Print(SIMPLE_BINDINGS_WARNING);
	end
end

-- The event frame of the other copy (loaded twice) stops itself.
function SimpleSave_IsOldFrame()
	if ( this == SimpleSaveEventFrame or not this or not this.GetName or this:GetName() ~= "SimpleSaveEventFrame" ) then
		return nil;
	end
	this:UnregisterEvent("PLAYER_ENTERING_WORLD");
	this:UnregisterEvent("UPDATE_BINDINGS");
	this:UnregisterEvent("PLAYER_QUITING");
	this:Hide();
	return 1;
end

function SimpleSave_OnEvent(event)
	if ( SimpleSave_IsOldFrame() ) then
		return;
	end
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		SimpleSave_HookBindings();
		SimpleSave_CheckBindings();
		if ( not SimpleSave_Loaded ) then
			if ( SimpleSave_HasAny(SimpleSave_Data) ) then
				-- An addon called Set before the save was read: keep it on top.
				SimpleSave_LateLoad();
			else
				SimpleSave_Load();
			end
		end
	elseif ( event == "UPDATE_BINDINGS" ) then
		-- Bindings may be read after the first PLAYER_ENTERING_WORLD on some
		-- clients: if nothing was found before, look again (once data shows up).
		if ( SimpleSave_Loaded and not SimpleSave_Writing and not SimpleSave_Job and not SimpleSave_Blocked and SimpleSave_LoadedEmpty ) then
			if ( SimpleSave_ReadStream() ~= "empty" ) then
				SimpleSave_LateLoad();
			end
		end
	elseif ( event == "PLAYER_QUITING" ) then
		SimpleSave_Flush();
	elseif ( event == "PLAYER_CAMPING" or event == "PLAYER_LEAVING_WORLD" ) then
		-- Logging out or a loading screen: write what is still waiting.
		if ( SimpleSave_Dirty or SimpleSave_Job ) then
			SimpleSave_Flush();
		end
	end
end

function SimpleSave_OnUpdate()
	if ( SimpleSave_IsOldFrame() ) then
		return;
	end
	if ( SimpleHello_Tick ) then
		SimpleHello_Tick();
	end
	if ( SimpleSave_Job ) then
		SimpleSave_JobStep();
	elseif ( SimpleSave_Dirty ) then
		local now = GetTime();
		if ( not SimpleSave_LastFlush ) then
			SimpleSave_LastFlush = now - SIMPLESAVE_URGENT_GAP;
		end
		-- Writing bindings.wtf can take 100-250 ms on a slow (USB) disk, so
		-- changed settings are written at most every 30 seconds, collected
		-- data at most every 5 minutes, everything at logout and loading screens.
		if ( now - SimpleSave_DirtyTime >= SIMPLESAVE_WRITE_DELAY
				and ((SimpleSave_Urgent and now - SimpleSave_LastFlush >= SIMPLESAVE_URGENT_GAP)
					or now - SimpleSave_LastFlush >= SIMPLESAVE_AUTO_DELAY) ) then
			SimpleSave_StartJob();
		end
	end
end


--------------------------------------------------------------------------------
-- Export / import (backup). The export text is "SS1:<checksum>:<stream>",
-- shown in parts of SIMPLESAVE_EXPORT_PART characters (one line each).
--------------------------------------------------------------------------------

SimpleSave_ExportParts = {};
SimpleSave_ExportIndex = 1;
SimpleSave_ImportText = "";
SimpleSave_Mode = nil;

function SimpleSave_ExportText()
	local stream;
	if ( SimpleSave_Blocked ) then
		stream = SimpleSave_RawStream or "";
	else
		stream = SimpleSave_BuildStream();
	end
	return "SS1:"..SimpleSave_Checksum(stream)..":"..stream;
end

function SimpleSave_ShowExport()
	local text = SimpleSave_ExportText();
	SimpleSave_ExportParts = {};
	local i = 1;
	while ( i <= strlen(text) ) do
		tinsert(SimpleSave_ExportParts, strsub(text, i, i + SIMPLESAVE_EXPORT_PART - 1));
		i = i + SIMPLESAVE_EXPORT_PART;
	end
	SimpleSave_ExportIndex = 1;
	SimpleSave_Mode = "export";
	SimpleSaveFrame:Show();
	SimpleSave_UpdateFrame();
end

function SimpleSave_ShowImport()
	SimpleSave_ImportText = "";
	SimpleSave_Mode = "import";
	SimpleSaveFrame:Show();
	SimpleSaveFrameEditBox:SetText("");
	SimpleSave_UpdateFrame();
end

function SimpleSave_UpdateFrame()
	local count = getn(SimpleSave_ExportParts);
	if ( SimpleSave_Mode == "export" ) then
		SimpleSaveFrameTitle:SetText("SimpleSave Backup");
		SimpleSaveFrameEditBox:SetText(SimpleSave_ExportParts[SimpleSave_ExportIndex] or "");
		SimpleSaveFrameEditBox:SetFocus();
		SimpleSaveFrameInfo:SetText("Part "..SimpleSave_ExportIndex.." of "..count..". Click the box, Ctrl+A, Ctrl+C and paste it into a text file. Copy every part in order.");
		SimpleSaveFramePrevButton:Show();
		SimpleSaveFrameNextButton:Show();
		SimpleSaveFrameAddButton:Hide();
		SimpleSaveFrameImportButton:Hide();
		if ( SimpleSave_ExportIndex > 1 ) then
			SimpleSaveFramePrevButton:Enable();
		else
			SimpleSaveFramePrevButton:Disable();
		end
		if ( SimpleSave_ExportIndex < count ) then
			SimpleSaveFrameNextButton:Enable();
		else
			SimpleSaveFrameNextButton:Disable();
		end
	else
		SimpleSaveFrameTitle:SetText("SimpleSave Restore");
		SimpleSaveFrameInfo:SetText("Paste part 1 into the box (Ctrl+V) and click Add part. Repeat for every part in order, then click Restore. Pasted so far: "..strlen(SimpleSave_ImportText).." characters.");
		SimpleSaveFramePrevButton:Hide();
		SimpleSaveFrameNextButton:Hide();
		SimpleSaveFrameAddButton:Show();
		SimpleSaveFrameImportButton:Show();
	end
end

function SimpleSave_ExportStep(step)
	SimpleSave_ExportIndex = max(1, min(SimpleSave_ExportIndex + step, getn(SimpleSave_ExportParts)));
	SimpleSave_UpdateFrame();
end

function SimpleSave_AddPart()
	local text = SimpleSaveFrameEditBox:GetText() or "";
	text = gsub(text, "%s", "");
	SimpleSave_ImportText = SimpleSave_ImportText..text;
	SimpleSaveFrameEditBox:SetText("");
	SimpleSave_UpdateFrame();
end

-- Returns 1 on success, or nil and an error text.
function SimpleSave_Import(text)
	text = gsub(text or "", "%s", "");
	local s, e, checksum, stream = strfind(text, "^SS1:(%x%x%x%x):(.*)$");
	if ( not checksum ) then
		return nil, "this is not a SimpleSave backup";
	end
	if ( SimpleSave_Checksum(stream) ~= checksum ) then
		return nil, "the backup is incomplete or changed (a part is missing?)";
	end
	local data, err = SimpleSave_ParseStream(stream);
	if ( not data ) then
		return nil, err;
	end
	SimpleSave_Data = data;
	SimpleSave_Blocked = nil;
	SimpleSave_RawStream = nil;
	SimpleSave_Loaded = 1;
	SimpleSave_Flush();
	return 1;
end

function SimpleSave_DoImport()
	SimpleSave_AddPart();
	local ok, err = SimpleSave_Import(SimpleSave_ImportText);
	if ( ok ) then
		SimpleSave_Print("backup restored. Type /reload so all addons read it.");
		SimpleSaveFrame:Hide();
	else
		SimpleSave_Print("|cffff4040restore failed: "..err..".|r");
		SimpleSave_ImportText = "";
		SimpleSave_UpdateFrame();
	end
end


--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

function SimpleSave_CountAddons()
	local list = {};
	foreach(SimpleSave_Data, function(addon, values)
		local count = 0;
		foreach(values, function() count = count + 1; end);
		tinsert(list, addon.." ("..count..")");
	end);
	SimpleSave_SortList(list);
	return list;
end

-- Capacity test: about 10000 characters (36 full macros), checked again
-- after a restart.
function SimpleSave_TestText()
	local pieces = { "#showtooltip Shadow Bolt\n", "/cast Shadow Bolt(Rank 2)\n", "/script ActionBars_Toggle(1, 'x');\n", "/say Hello, 100% ok! [Test] #", "/use 0 1\n" };
	local text = "";
	local i = 1;
	while ( strlen(text) < 10000 ) do
		text = text..pieces[mod(i, 5) + 1]..i;
		i = i + 1;
	end
	return text;
end

function SimpleSave_Test()
	if ( SimpleSave_Blocked ) then
		SimpleSave_Print("|cffff4040test failed: the save could not be read after the restart ("..SimpleSave_Blocked.."). Type /ssave reset.|r");
		return;
	end
	if ( SimpleSave_Get("SimpleSaveTest", "state") == "written" ) then
		local ok = ( SimpleSave_Get("SimpleSaveTest", "data") == SimpleSave_TestText() );
		SimpleSave_ClearAddon("SimpleSaveTest");
		SimpleSave_Flush();
		if ( ok ) then
			SimpleSave_Print("|cff40ff40TEST OK:|r 10000 characters came back after the restart. The test data was removed.");
		else
			SimpleSave_Print("|cffff4040TEST FAILED: the test data came back changed.|r The test data was removed.");
		end
		return;
	end
	SimpleSave_Set("SimpleSaveTest", "data", SimpleSave_TestText());
	SimpleSave_Set("SimpleSaveTest", "state", "written");
	SimpleSave_Flush();
	if ( SimpleSave_LastError ) then
		SimpleSave_Print("|cffff4040test failed at once: "..SimpleSave_LastError.."|r");
		SimpleSave_ClearAddon("SimpleSaveTest");
		SimpleSave_Flush();
		return;
	end
	SimpleSave_Print("test data written ("..SimpleSave_Chunks.." keys, about "..ceil(SimpleSave_Chunks / SIMPLESAVE_COMMANDS).." per command). Close the game with Quit, start it again and type /ssave test once more.");
end

function SimpleSave_Slash(msg)
	local simpleVersionAsk = strlower(gsub(msg or "", "%s", ""));
	if ( simpleVersionAsk == "v" or simpleVersionAsk == "version" ) then
		ChatFrame:AddMessage("SimpleSave "..SIMPLESAVE_VERSION, 1.0, 0.82, 0.0);
		return;
	end
	msg = strlower(msg or "");
	if ( msg == "test" ) then
		SimpleSave_Test();
	elseif ( msg == "export" or msg == "backup" ) then
		SimpleSave_ShowExport();
	elseif ( msg == "import" or msg == "restore" ) then
		SimpleSave_ShowImport();
	elseif ( msg == "reset" or msg == "clear" or msg == "clear confirm" or msg == "reset confirm" ) then
		-- Removes everything: asked once, answered within 30 seconds.
		if ( msg == "reset" or msg == "clear" ) then
			SimpleSave_ClearAsked = GetTime();
			SimpleSave_Print("|cffff4040this removes ALL saved data of ALL Simple AddOns (settings, macros, positions, builds, every character).|r Type /ss clear confirm within 30 seconds to do it. /ssave export makes a backup first.");
		elseif ( not SimpleSave_ClearAsked or GetTime() - SimpleSave_ClearAsked > 30 ) then
			SimpleSave_Print("type /ss clear first.");
		else
			SimpleSave_ClearAsked = nil;
			SimpleSave_Data = {};
			SimpleSave_Blocked = nil;
			SimpleSave_RawStream = nil;
			SimpleSave_Loaded = 1;
			SimpleSave_Flush();
			SimpleSave_Print("all saved addon data was removed. Type /reload.");
		end
	elseif ( msg == "save" ) then
		SimpleSave_Flush();
		if ( not SimpleSave_LastError ) then
			SimpleSave_Print("saved.");
		end
	elseif ( msg == "chars" or msg == "characters" ) then
		local list = SimpleSave_CharList();
		if ( getn(list) == 0 ) then
			SimpleSave_Print("no character has saved data.");
		else
			local i;
			for i = 1, getn(list) do
				SimpleSave_Print("  "..list[i][1]..(list[i][1] == UnitName("player") and " (this character)" or "").." - "..list[i][2].." keys, "..list[i][3].." values");
			end
			SimpleSave_Print("/ssave forget <name> removes one character's data, /ssave forget all removes every character except this one. Make a backup first with /ssave export.");
		end
	elseif ( strsub(msg, 1, 6) == "forget" ) then
		local who = gsub(strsub(msg, 7), "^%s+", "");
		who = gsub(who, "%s+$", "");
		if ( not SimpleSave_Loaded or SimpleSave_Blocked ) then
			SimpleSave_Print("the save is not ready.");
		elseif ( who == "" ) then
			SimpleSave_Print("type /ssave forget <character name>, or /ssave forget all.");
		elseif ( who == "all" ) then
			SimpleSave_Print(SimpleSave_ForgetChars(nil).." values of other characters removed. They are written to the file within a few seconds.");
		else
			local count = SimpleSave_ForgetChars(who);
			if ( count == 0 ) then
				SimpleSave_Print("no saved data for '"..who.."'. /ssave chars lists the characters.");
			else
				SimpleSave_Print(count.." values of "..who.." removed. They are written to the file within a few seconds.");
			end
		end
	else
		SimpleSave_Print("version "..SIMPLESAVE_VERSION);
		if ( SimpleSave_BindingsMissing ) then
			SimpleSave_Print(SIMPLE_BINDINGS_WARNING);
		end
		if ( SimpleSave_Blocked ) then
			SimpleSave_Print("|cffff4040status: damaged save ("..SimpleSave_Blocked..")|r");
		elseif ( not SimpleSave_Loaded ) then
			SimpleSave_Print("status: not loaded yet");
		else
			SimpleSave_Print("status: OK, "..SimpleSave_Bytes.." characters in "..SimpleSave_Chunks.." of "..SIMPLESAVE_MAX_CHUNKS.." keys ("..floor(SimpleSave_Chunks * 100 / SIMPLESAVE_MAX_CHUNKS + 0.5).."%) in bindings.wtf");
		end
		if ( SimpleSave_LastError ) then
			SimpleSave_Print("|cffff4040last error: "..SimpleSave_LastError.."|r");
		end
		local list = SimpleSave_UsageList();
		local i;
		for i = 1, getn(list) do
			SimpleSave_Print("  "..list[i][1].." - "..list[i][2].." keys");
		end
		SimpleSave_Print("/ssave chars = characters, /ssave forget <name> = remove a character's data, /ssave export = backup, /ssave import = restore, /ssave reset = remove all, /ssave test = capacity test");
	end
end
