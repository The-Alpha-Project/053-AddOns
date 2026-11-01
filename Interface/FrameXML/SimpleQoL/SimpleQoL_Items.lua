--------------------------------------------------------------------------------
-- SimpleQoL, part 8: "Already known" on recipes you know, Flash Powder count
-- on Vanish, ammunition count on quivers and ammo pouches, and AlphaUI's
-- target distance text kept from showing through the bag.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Already known: the recipes of every profession window you open are kept
-- (per character). A recipe item tooltip ("Pattern: Red Linen Vest") then
-- says "Already known" in red when you know it.
--------------------------------------------------------------------------------

SIMPLEQOL_RECIPE_PREFIXES = { "Pattern", "Recipe", "Plans", "Schematic", "Formula", "Manual", "Design" };
SimpleQoL_KnownProfs = {};            -- profession -> { recipe code -> 1 }
SimpleQoL_KnownPending = nil;

function SimpleQoL_SaveKnown(prof)
	if ( not SimpleSave_SetChar ) then
		return;
	end
	-- "$" and 5 letters per recipe (a short code of its name), to save space.
	local text = "$";
	foreach(SimpleQoL_KnownProfs[prof], function(code) text = text..code; end);
	SimpleSave_SetChar("SimpleQoL", "Known"..gsub(prof, "[^%a]", ""), text);
	local profs = {};
	foreach(SimpleQoL_KnownProfs, function(p) tinsert(profs, p); end);
	SimpleSave_SetChar("SimpleQoL", "KnownProfs", SimpleQoL_JoinBars(profs));
end

function SimpleQoL_LoadKnown()
	SimpleQoL_KnownProfs = {};
	if ( not SimpleSave_GetChar ) then
		return;
	end
	local profs = SimpleQoL_SplitBars(SimpleSave_GetChar("SimpleQoL", "KnownProfs", ""));
	local i, j;
	for i = 1, getn(profs) do
		local set = {};
		local text = SimpleSave_GetChar("SimpleQoL", "Known"..gsub(profs[i], "[^%a]", ""), "");
		if ( strsub(text, 1, 1) == "$" ) then
			for j = 2, strlen(text) - 4, 5 do
				set[strsub(text, j, j + 4)] = 1;
			end
			SimpleQoL_KnownProfs[profs[i]] = set;
		elseif ( strsub(text, 1, 1) == "#" ) then
			-- 4-letter codes from 2.11 cannot be turned into names: they are
			-- read again the next time this profession window is opened.
			SimpleQoL_KnownProfs[profs[i]] = set;
			SimpleQoL_SaveKnown(profs[i]);
		else
			-- Saved by an older version as full names: stored again as codes.
			local names = SimpleQoL_SplitBars(text);
			for j = 1, getn(names) do
				set[SimpleQoL_KnownCode(names[j])] = 1;
			end
			SimpleQoL_KnownProfs[profs[i]] = set;
			SimpleQoL_SaveKnown(profs[i]);
		end
	end
end

-- A recipe name as 5 letters / digits (a hash; a false match is very rare).
SIMPLEQOL_CODE_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
function SimpleQoL_KnownCode(name)
	local h = 0;
	local i;
	for i = 1, strlen(name) do
		h = mod(h * 31 + strbyte(name, i), 916132832);
	end
	local code = "";
	for i = 1, 5 do
		local d = mod(h, 62);
		code = code..strsub(SIMPLEQOL_CODE_CHARS, d + 1, d + 1);
		h = floor(h / 62);
	end
	return code;
end

function SimpleQoL_JoinBars(list)
	local text = "";
	local i;
	for i = 1, getn(list) do
		if ( i > 1 ) then
			text = text.."|";
		end
		text = text..list[i];
	end
	return text;
end

function SimpleQoL_SplitBars(text)
	local list = {};
	local pos = 1;
	while ( text and text ~= "" ) do
		local s, e = strfind(text, "|", pos, 1);
		if ( not s ) then
			tinsert(list, strsub(text, pos));
			break
		end
		tinsert(list, strsub(text, pos, s - 1));
		pos = e + 1;
	end
	return list;
end

-- The profession window is open: remember its recipes.
function SimpleQoL_ReadTradeSkills()
	if ( not GetNumTradeSkills or not GetTradeSkillLine ) then
		return;
	end
	local prof = GetTradeSkillLine();
	SimpleQoL_KnownLast = "window "..(prof or "nil").." with "..(GetNumTradeSkills() or 0).." lines";
	if ( not prof or prof == "" or prof == "UNKNOWN" ) then
		return;
	end
	-- Added to what is known already: folded headers hide some recipes.
	local set = SimpleQoL_KnownProfs[prof] or {};
	local count = 0;
	local i;
	for i = 1, GetNumTradeSkills() do
		local name, kind = GetTradeSkillInfo(i);
		if ( name and kind ~= "header" ) then
			set[SimpleQoL_KnownCode(name)] = 1;
			count = count + 1;
		end
	end
	if ( count == 0 ) then
		return;
	end
	SimpleQoL_KnownProfs[prof] = set;
	SimpleQoL_SaveKnown(prof);
end

function SimpleQoL_IsKnownRecipe(title)
	local s, e, prefix, name = strfind(title or "", "^(%a+): (.+)$");
	if ( not name ) then
		return nil;
	end
	local i;
	local isRecipe = nil;
	for i = 1, getn(SIMPLEQOL_RECIPE_PREFIXES) do
		if ( prefix == SIMPLEQOL_RECIPE_PREFIXES[i] ) then
			isRecipe = 1;
		end
	end
	if ( not isRecipe ) then
		return nil;
	end
	local known = nil;
	local code = SimpleQoL_KnownCode(name);
	foreach(SimpleQoL_KnownProfs, function(prof, set)
		if ( set[code] ) then
			known = 1;
		end
	end);
	return known;
end

-- Read whenever the profession window is drawn (and while it is open), not
-- only on its events.
if ( TradeSkillFrame_Update ) then
	SimpleQoL_Orig_TradeSkillFrame_Update = TradeSkillFrame_Update;
	function TradeSkillFrame_Update()
		SimpleQoL_Orig_TradeSkillFrame_Update();
		SimpleQoL_ReadTradeSkills();
	end
end

-- Item tooltips get their lines on the next frame; check then.
function SimpleQoL_KnownUpdate()
	if ( not SimpleQoL_KnownPending ) then
		return;
	end
	SimpleQoL_KnownPending = nil;
	if ( not GameTooltip:IsVisible() or not GameTooltipTextLeft1 ) then
		return;
	end
	-- The item name is not always the first line (this client can show an
	-- id line first), so the first three lines are checked.
	local i;
	for i = 1, 3 do
		local line = getglobal("GameTooltipTextLeft"..i);
		local text = line and line:GetText();
		if ( text == "Already known" or text == "|cffff2020Already known|r" ) then
			return;
		end
		if ( SimpleQoL_IsKnownRecipe(text) ) then
			-- Colors given as numbers did not show in this client (black text);
			-- a color code in the text works.
			GameTooltip:AddLine("|cffff2020Already known|r", "", 1.0, 0.125, 0.125);
			GameTooltip:Show();
			return;
		end
	end
end

function SimpleQoL_HookKnown(method)
	local orig = GameTooltip[method];
	if ( not orig ) then
		return;
	end
	GameTooltip[method] = function(self, a, b, c)
		local r1, r2 = orig(self, a, b, c);
		if ( self == GameTooltip ) then
			SimpleQoL_KnownPending = 1;
		end
		return r1, r2;
	end;
end

SimpleQoL_HookKnown("SetBagItem");
SimpleQoL_HookKnown("SetLootItem");
SimpleQoL_HookKnown("SetMerchantItem");
SimpleQoL_HookKnown("SetQuestItem");
SimpleQoL_HookKnown("SetQuestLogItem");
SimpleQoL_HookKnown("SetTradePlayerItem");
SimpleQoL_HookKnown("SetTradeTargetItem");
SimpleQoL_HookKnown("SetInventoryItem");
SimpleQoL_HookKnown("SetAuctionItem");


--------------------------------------------------------------------------------
-- Spells that use up a reagent show how many you carry (always on): Vanish
-- (Flash Powder) and the warlock spells that use a Soul Shard. Taken from the
-- 0.5.3 spell data by icon; the class keeps shared icons apart.
--------------------------------------------------------------------------------

SIMPLEQOL_REAGENT_COUNTS = {
	{ "ability_vanish", "Flash Powder", "ROGUE" },
	{ "spell_shadow_summonfelhunter", "Soul Shard", "WARLOCK" },
	{ "spell_shadow_summonvoidwalker", "Soul Shard", "WARLOCK" },
	{ "spell_shadow_summonsuccubus", "Soul Shard", "WARLOCK" },
	{ "spell_shadow_soulgem", "Soul Shard", "WARLOCK" },
	{ "spell_shadow_twilight", "Soul Shard", "WARLOCK" },
	{ "spell_shadow_cripple", "Soul Shard", "WARLOCK" },
	{ "spell_nature_swiftness", "Soul Shard", "WARLOCK" },
	{ "inv_misc_gem_sapphire_01", "Soul Shard", "WARLOCK" },
	{ "inv_stone_04", "Soul Shard", "WARLOCK" },
};

-- The reagent entries of your class (made once; none for most classes).
function SimpleQoL_ReagentList()
	if ( not SimpleQoL_ReagentClassList ) then
		local class = UnitClass("player");
		if ( not class ) then
			return {};
		end
		class = strupper(class);
		SimpleQoL_ReagentClassList = {};
		local i;
		for i = 1, getn(SIMPLEQOL_REAGENT_COUNTS) do
			if ( SIMPLEQOL_REAGENT_COUNTS[i][3] == class ) then
				tinsert(SimpleQoL_ReagentClassList, SIMPLEQOL_REAGENT_COUNTS[i]);
			end
		end
	end
	return SimpleQoL_ReagentClassList;
end

-- counts: item name -> count, shared by one pass over all buttons.
function SimpleQoL_ReagentCount(button, counts)
	local list = SimpleQoL_ReagentList();
	if ( getn(list) == 0 or not button or not GetActionTexture or not ActionButton_GetPagedID ) then
		return;
	end
	local id = ActionButton_GetPagedID(button);
	local texture = id and GetActionTexture(id);
	if ( not texture ) then
		return;
	end
	local lower = strlower(texture);
	local i;
	for i = 1, getn(list) do
		if ( strfind(lower, list[i][1], 1, 1) ) then
			local text = getglobal(button:GetName().."Count");
			if ( text ) then
				local name = list[i][2];
				local count = counts and counts[name];
				if ( not count ) then
					count = SimpleQoL_CountItem(name);
					if ( counts ) then
						counts[name] = count;
					end
				end
				text:SetText(count);
			end
			return;
		end
	end
end

SimpleQoL_Orig_ActionButton_UpdateCount = ActionButton_UpdateCount;
function ActionButton_UpdateCount()
	SimpleQoL_Orig_ActionButton_UpdateCount();
	SimpleQoL_ReagentCount(this);
end

function SimpleQoL_UpdateReagentCounts()
	if ( getn(SimpleQoL_ReagentList()) == 0 ) then
		return;
	end
	local counts = {};
	-- The button names are built once, not on every pass.
	if ( not SimpleQoL_ReagentButtons ) then
		SimpleQoL_ReagentButtons = {};
		local i;
		for i = 1, 12 do
			tinsert(SimpleQoL_ReagentButtons, "ActionButton"..i);
			tinsert(SimpleQoL_ReagentButtons, "BonusActionButton"..i);
		end
		for i = 25, 72 do
			tinsert(SimpleQoL_ReagentButtons, "ActionBarsButton"..i);
		end
	end
	local i;
	for i = 1, getn(SimpleQoL_ReagentButtons) do
		SimpleQoL_ReagentCount(getglobal(SimpleQoL_ReagentButtons[i]), counts);
	end
end


--------------------------------------------------------------------------------
-- Ammunition in quivers and ammo pouches, on their bag buttons (with "Free
-- bag slots").
--------------------------------------------------------------------------------

-- "A" for a quiver (arrows only), "B" for an ammo pouch (bullets only), nil
-- for other bags. Names from SimpleQoL_Ammo.lua, else by the word.
function SimpleQoL_AmmoBagKind(bag)
	if ( not bag or bag < 1 or bag > 10 or not GetBagName ) then
		return nil;
	end
	local name = GetBagName(bag);
	if ( not name ) then
		return nil;
	end
	local kind = SIMPLEQOL_AMMO_BAGS and SIMPLEQOL_AMMO_BAGS[name];
	if ( kind ) then
		return kind;
	end
	local lower = strlower(name);
	if ( strfind(lower, "quiver", 1, 1) ) then
		return "A";
	end
	if ( strfind(lower, "ammo", 1, 1) or strfind(lower, "shot pouch", 1, 1) or strfind(lower, "bandolier", 1, 1) ) then
		return "B";
	end
	return nil;
end

function SimpleQoL_IsAmmoBag(bag)
	return SimpleQoL_AmmoBagKind(bag);
end

-- The slots of a quiver or ammo pouch get a brown frame (the stock bags and
-- AlphaUI's bag), so you can tell them from your other bags.
SIMPLEQOL_AMMO_TINT = { 0.85, 0.55, 0.22 };
-- The slots of the bag under the mouse (on the bag bar) get a violet frame
-- (far from the brown of quivers and ammo pouches).
SIMPLEQOL_BAGHOVER_TINT = { 0.72, 0.48, 1.0 };
SimpleQoL_BagHover = nil;             -- bag number (0 = backpack) under the mouse
function SimpleQoL_TintAmmoButton(button, bag)
	local name = button and button.GetName and button:GetName();
	local texture = name and getglobal(name.."NormalTexture");
	if ( not texture ) then
		return;
	end
	if ( SimpleQoL_BagHover and SimpleQoL_BagHover == bag ) then
		texture:SetVertexColor(SIMPLEQOL_BAGHOVER_TINT[1], SIMPLEQOL_BAGHOVER_TINT[2], SIMPLEQOL_BAGHOVER_TINT[3]);
	elseif ( SimpleQoL_AmmoBagKind(bag) ) then
		texture:SetVertexColor(SIMPLEQOL_AMMO_TINT[1], SIMPLEQOL_AMMO_TINT[2], SIMPLEQOL_AMMO_TINT[3]);
	else
		texture:SetVertexColor(1.0, 1.0, 1.0);
	end
end

-- AlphaUI's bag sets the frame color back to white on every update.
if ( SetItemButtonNormalTextureVertexColor ) then
	SimpleQoL_Orig_SetItemButtonNormalTextureVertexColor = SetItemButtonNormalTextureVertexColor;
	function SetItemButtonNormalTextureVertexColor(button, r, g, b)
		SimpleQoL_Orig_SetItemButtonNormalTextureVertexColor(button, r, g, b);
		local parent = button and button.GetParent and button:GetParent();
		if ( r == 1 and g == 1 and b == 1 and parent and parent.GetID ) then
			local id = parent:GetID();
			if ( id == SimpleQoL_BagHover or SimpleQoL_AmmoBagKind(id) ) then
				SimpleQoL_TintAmmoButton(button, id);
			end
		end
	end
end

-- The stock bags.
if ( ContainerFrame_Update ) then
	SimpleQoL_Orig_ContainerFrame_Update = ContainerFrame_Update;
	function ContainerFrame_Update(frame)
		SimpleQoL_Orig_ContainerFrame_Update(frame);
		if ( frame and frame.size and frame.GetID ) then
			local bag = frame:GetID();
			local j;
			for j = 1, frame.size do
				SimpleQoL_TintAmmoButton(getglobal(frame:GetName().."Item"..j), bag);
			end
		end
	end
end

-- Bag under the mouse: the slots of that bag get a violet frame in the open
-- inventory (AlphaUI's merged bag and the stock bag windows alike), so you can
-- see which slots belong to which bag. Position based, so it needs no script
-- of the bag buttons.
SIMPLEQOL_BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" };

function SimpleQoL_BagUnderMouse()
	local first = getglobal(SIMPLEQOL_BAG_BUTTONS[1]);
	if ( not first or not first:IsVisible() ) then
		return nil;
	end
	local cx, cy = GetCursorPosition();
	local fx, fy = first:GetCenter();
	if ( not cx or not fx ) then
		return nil;
	end
	local k = SimpleQoL_Scale();
	local sx, sy = SimpleQoLProbeScreen:GetCenter();
	if ( not sx ) then
		return nil;
	end
	local x = (cx - sx) * k + 1;
	local y = (cy - sy) * k + 1;
	if ( SimpleQoL_Abs(y - ((fy - sy) * k + 1)) > 30 ) then
		return nil;
	end
	local i;
	for i = 1, getn(SIMPLEQOL_BAG_BUTTONS) do
		local button = getglobal(SIMPLEQOL_BAG_BUTTONS[i]);
		local bx, by;
		if ( button ) then
			bx, by = button:GetCenter();
		end
		if ( bx and button:IsVisible() ) then
			bx = (bx - sx) * k + 1;
			by = (by - sy) * k + 1;
			if ( SimpleQoL_Abs(x - bx) <= (button:GetWidth() or 37) / 2 and SimpleQoL_Abs(y - by) <= (button:GetHeight() or 37) / 2 ) then
				return i - 1;
			end
		end
	end
	return nil;
end

-- Colours the frames of one bag's slots again (violet while it is the hovered
-- bag, else ammo brown or white).
function SimpleQoL_BagRetint(bag)
	local count = GetContainerNumSlots and GetContainerNumSlots(bag) or 0;
	local j;
	for j = 1, count do
		SimpleQoL_TintAmmoButton(getglobal("MainMergedBagsFrameBag"..bag.."Item"..j), bag);
	end
	local i;
	for i = 1, (NUM_CONTAINER_FRAMES or 16) do
		local frame = getglobal("ContainerFrame"..i);
		if ( frame and frame:IsVisible() and frame:GetID() == bag ) then
			for j = 1, (frame.size or count) do
				SimpleQoL_TintAmmoButton(getglobal("ContainerFrame"..i.."Item"..j), bag);
			end
		end
	end
end

function SimpleQoL_BagHoverUpdate()
	local bag = SimpleQoL_BagUnderMouse();
	if ( bag == SimpleQoL_BagHover ) then
		return;
	end
	local old = SimpleQoL_BagHover;
	SimpleQoL_BagHover = bag;
	if ( old ) then
		SimpleQoL_BagRetint(old);
	end
	if ( bag ) then
		SimpleQoL_BagRetint(bag);
	end
end

function SimpleQoL_UpdateAmmoCounts()
	local bag;
	for bag = 1, 4 do
		local text = getglobal("SimpleQoLBagCount"..bag.."Text");
		if ( text ) then
			if ( SimpleQoL_On["bagslots"] and SimpleQoL_IsAmmoBag(bag) ) then
				local total = 0;
				local slot;
				for slot = 1, (GetContainerNumSlots(bag) or 0) do
					local texture, count = GetContainerItemInfo(bag, slot);
					if ( texture ) then
						total = total + (count or 1);
					end
				end
				text:SetText(total);
			else
				text:SetText("");
			end
		end
	end
end


--------------------------------------------------------------------------------
-- AlphaUI's target distance text ("57 yds") is drawn above everything; it is
-- made invisible while it lies over the open bag.
--------------------------------------------------------------------------------

SimpleQoL_DistanceHidden = nil;

function SimpleQoL_FrameBox(frame)
	local cx, cy = frame:GetCenter();
	if ( not cx ) then
		return nil;
	end
	local x, y = SimpleQoL_ToScreen(cx, cy);
	local w, h = (frame:GetWidth() or 0) / 2, (frame:GetHeight() or 0) / 2;
	return x - w, y - h, x + w, y + h;
end

function SimpleQoL_DistanceCheck()
	local text = MainTargetDistanceFrame;
	local bag = MainMergedBagsFrame;
	if ( not text or not text.SetAlpha ) then
		return;
	end
	local cover = nil;
	if ( bag and bag:IsVisible() and text:IsVisible() ) then
		local l1, b1, r1, t1 = SimpleQoL_FrameBox(bag);
		local l2, b2, r2, t2 = SimpleQoL_FrameBox(text);
		if ( l1 and l2 and l2 < r1 and l1 < r2 and b2 < t1 and b1 < t2 ) then
			cover = 1;
		end
	end
	if ( cover and not SimpleQoL_DistanceHidden ) then
		SimpleQoL_DistanceHidden = 1;
		text:SetAlpha(0);
	elseif ( not cover and SimpleQoL_DistanceHidden ) then
		SimpleQoL_DistanceHidden = nil;
		text:SetAlpha(1);
	end
end


--------------------------------------------------------------------------------
-- Right-click a ring, weapon, armor ... in your bags to put it on (always on;
-- not while a merchant, trade, bank or auction window is open).
--------------------------------------------------------------------------------

SIMPLEQOL_EQUIP_SLOTS = { INVTYPE_2HWEAPON, INVTYPE_BODY, INVTYPE_CHEST, INVTYPE_CLOAK, INVTYPE_FEET,
	INVTYPE_FINGER, INVTYPE_HAND, INVTYPE_HEAD, INVTYPE_HOLDABLE, INVTYPE_LEGS, INVTYPE_NECK, INVTYPE_RANGED,
	INVTYPE_ROBE, INVTYPE_SHIELD, INVTYPE_SHOULDER, INVTYPE_TABARD, INVTYPE_TRINKET, INVTYPE_WAIST,
	INVTYPE_WEAPON, INVTYPE_WEAPONMAINHAND, INVTYPE_WEAPONOFFHAND, INVTYPE_WRIST, "Wand" };

function SimpleQoL_IsEquipSlotText(text)
	if ( not text ) then
		return nil;
	end
	local i;
	for i = 1, getn(SIMPLEQOL_EQUIP_SLOTS) do
		if ( SIMPLEQOL_EQUIP_SLOTS[i] and text == SIMPLEQOL_EQUIP_SLOTS[i] ) then
			return 1;
		end
	end
	return nil;
end

function SimpleQoL_CanWear(bag, slot)
	if ( not SimpleQoLScanTooltip or not AutoEquipCursorItem ) then
		return nil;
	end
	local windows = { MerchantFrame, TradeFrame, BankFrame, AuctionFrame };
	local i;
	for i = 1, 4 do
		if ( windows[i] and windows[i]:IsVisible() ) then
			return nil;
		end
	end
	-- SetBagItem returns nothing for most items here; the lines tell.
	SimpleQoLScanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	SimpleQoLScanTooltip:SetBagItem(bag, slot);
	local lines = SimpleQoLScanTooltip:NumLines() or 0;
	for i = 2, min(8, lines) do
		local line = getglobal("SimpleQoLScanTooltipTextLeft"..i);
		if ( line and SimpleQoL_IsEquipSlotText(line:GetText()) ) then
			return 1;
		end
	end
	return nil;
end

SimpleQoL_Orig_Items_UseContainerItem = UseContainerItem;
function UseContainerItem(bag, slot)
	-- While the client waits for a target (an item that is used on another
	-- item), the click belongs to the client: nothing of ours.
	if ( SpellIsTargeting and SpellIsTargeting() ) then
		SimpleQoL_Orig_Items_UseContainerItem(bag, slot);
		return;
	end
	if ( not SimpleQoL_Internal and not (CursorHasItem and CursorHasItem()) and SimpleQoL_CanWear(bag, slot) ) then
		PickupContainerItem(bag, slot);
		AutoEquipCursorItem();
		return;
	end
	SimpleQoL_Orig_Items_UseContainerItem(bag, slot);
end


--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

SimpleQoL_ItemsTime = 0;
SimpleQoL_ItemsDirty = 1;

--------------------------------------------------------------------------------
-- Quest progress on enemies: pointing at a mob you have to kill for a quest
-- adds "Quest name: Mob 4/8" to its tooltip (kill objectives "Mob slain").
--------------------------------------------------------------------------------

SimpleQoL_QuestMobs = nil;            -- lower-case mob name -> { line, ... }; nil = read again
SimpleQoL_MobPending = nil;           -- name of the mob whose tooltip waits for the lines

SimpleQoL_QuestMobsStale = nil;      -- the quest log changed since the last read
SimpleQoL_QuestMobsTime = 0;

function SimpleQoL_ReadQuestMobs()
	SimpleQoL_QuestMobsStale = nil;
	SimpleQoL_QuestMobsTime = GetTime();
	SimpleQoL_QuestMobs = {};
	if ( not GetNumQuestLogEntries or not GetQuestLogLeaderBoard ) then
		return;
	end
	local selected = GetQuestLogSelection and GetQuestLogSelection();
	local i, j;
	for i = 1, GetNumQuestLogEntries() do
		local title, level, tag, isHeader = GetQuestLogTitle(i);
		if ( title and not isHeader ) then
			SelectQuestLogEntry(i);
			for j = 1, (GetNumQuestLeaderBoards() or 0) do
				local text, kind, finished = GetQuestLogLeaderBoard(j);
				local s, e, mob, have, need = strfind(text or "", "^(.+) slain: (%d+)/(%d+)$");
				if ( mob ) then
					local color = "|cffffffff";
					if ( finished ) then
						color = "|cff20ff20";
					end
					local key = strlower(mob);
					if ( not SimpleQoL_QuestMobs[key] ) then
						SimpleQoL_QuestMobs[key] = {};
					end
					tinsert(SimpleQoL_QuestMobs[key], "|cffffd100"..title..":|r "..color..mob.." "..have.."/"..need.."|r");
				end
			end
		end
	end
	if ( selected ) then
		SelectQuestLogEntry(selected);
	end
end

function SimpleQoL_MobTooltipUpdate()
	local name = SimpleQoL_MobPending;
	if ( not name ) then
		return;
	end
	SimpleQoL_MobPending = nil;
	if ( not GameTooltip:IsVisible() or not GameTooltipTextLeft1 ) then
		return;
	end
	-- The first line is the name (other addons may color it).
	local first = gsub(gsub(GameTooltipTextLeft1:GetText() or "", "|c%x%x%x%x%x%x%x%x", ""), "|r", "");
	if ( first ~= name ) then
		return;
	end
	-- Read again after a quest log change, but at most once a second (reading
	-- the log also causes quest log events, which made every mouse-over read
	-- the whole log again).
	if ( not SimpleQoL_QuestMobs or (SimpleQoL_QuestMobsStale and GetTime() - SimpleQoL_QuestMobsTime > 1) ) then
		SimpleQoL_ReadQuestMobs();
	end
	local lines = SimpleQoL_QuestMobs[strlower(name)];
	if ( not lines ) then
		return;
	end
	local i;
	for i = 1, getn(lines) do
		GameTooltip:AddLine(lines[i]);
	end
	GameTooltip:Show();
end

function SimpleQoL_Items_OnLoad()
	this:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	this:RegisterEvent("QUEST_LOG_UPDATE");
	this:RegisterEvent("TRADE_SKILL_SHOW");
	this:RegisterEvent("TRADE_SKILL_UPDATE");
	this:RegisterEvent("BAG_UPDATE");
	this:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
end

function SimpleQoL_Items_OnEvent(event)
	if ( event == "UPDATE_MOUSEOVER_UNIT" ) then
		if ( UnitExists("mouseover") and not UnitIsPlayer("mouseover") ) then
			SimpleQoL_MobPending = UnitName("mouseover");
		end
	elseif ( event == "QUEST_LOG_UPDATE" ) then
		-- Read again the next time it is needed (not while the tracker reads).
		if ( not SimpleQoL_TrackerBusy ) then
			SimpleQoL_QuestMobsStale = 1;
		end
	elseif ( event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" ) then
		SimpleQoL_ReadTradeSkills();
	else
		SimpleQoL_ItemsDirty = 1;
	end
end

function SimpleQoL_Items_OnUpdate()
	if ( not SimpleQoL_Loaded ) then
		return;
	end
	SimpleQoL_KnownUpdate();
	SimpleQoL_MobTooltipUpdate();
	-- Bag changes come in bursts (looting): at most twice a second.
	local now = GetTime();
	if ( (SimpleQoL_ItemsDirty and now - SimpleQoL_ItemsTime > 0.5) or now - SimpleQoL_ItemsTime > 10 ) then
		SimpleQoL_ItemsDirty = nil;
		SimpleQoL_ItemsTime = GetTime();
		SimpleQoL_UpdateReagentCounts();
		SimpleQoL_UpdateAmmoCounts();
		if ( TradeSkillFrame and TradeSkillFrame:IsVisible() ) then
			SimpleQoL_ReadTradeSkills();
		end
	end
	if ( now - (SimpleQoL_BagHoverTime or 0) > 0.1 ) then
		SimpleQoL_BagHoverTime = now;
		SimpleQoL_BagHoverUpdate();
	end
	if ( now - (SimpleQoL_DistanceTime or 0) > 0.5 ) then
		SimpleQoL_DistanceTime = now;
		SimpleQoL_DistanceCheck();
	end
end
