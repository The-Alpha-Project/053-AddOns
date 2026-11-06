--------------------------------------------------------------------------------
-- SimpleQoL, part 3: friendly spells on yourself, target nearest enemy on
-- attack, compare with equipped items, trainer "select next", clams, heal at
-- 10% health and position sharing with other SimpleQoL users.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Friendly spells on yourself / target nearest enemy on attack
--------------------------------------------------------------------------------

SimpleQoL_PressedAction = nil;       -- last action pressed by the player
SimpleQoL_PressedTime = 0;
SimpleQoL_Retried = nil;             -- 1 while pressing it again ourselves

-- After a spell was started: if the client waits for a target (glowing hand)
-- choose it for the player.
-- An action button that holds an item (its tooltip has a "Use:" line). An
-- item that waits for a target (a rod used on another item) is left alone.
function SimpleQoL_ActionIsItem(id)
	if ( not id or not SimpleQoLScanTooltip or not SimpleQoLScanTooltip.SetAction ) then
		return nil;
	end
	SimpleQoLScanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	SimpleQoLScanTooltip:SetAction(id);
	local i;
	for i = 2, (SimpleQoLScanTooltip:NumLines() or 0) do
		local line = getglobal("SimpleQoLScanTooltipTextLeft"..i);
		local text = line and line:GetText();
		if ( text and strsub(text, 1, 4) == "Use:" ) then
			return 1;
		end
	end
	return nil;
end

function SimpleQoL_AfterCast(hadTarget, actionId)
	if ( not SpellIsTargeting or not SpellIsTargeting() ) then
		return;
	end
	if ( actionId and SimpleQoL_ActionIsItem(actionId) ) then
		return;
	end
	local friendlyTarget = UnitExists("target") and UnitIsFriend("player", "target");
	if ( SimpleQoL_On["selfcast"] and not friendlyTarget and SpellCanTargetUnit("player") ) then
		SpellTargetUnit("player");
		return;
	end
	if ( SimpleQoL_On["autotarget"] and not hadTarget and TargetNearestEnemy ) then
		TargetNearestEnemy();
		if ( UnitExists("target") and SpellCanTargetUnit("target") ) then
			SpellTargetUnit("target");
		end
	end
end

SimpleQoL_Orig_More_UseAction = UseAction;
function UseAction(id, checkCursor, onSelf)
	local hadTarget = UnitExists("target");
	if ( not SimpleQoL_Retried ) then
		SimpleQoL_PressedAction = id;
		SimpleQoL_PressedTime = GetTime();
		-- The Attack button needs a target before it is pressed.
		if ( SimpleQoL_On["autotarget"] and not hadTarget and IsAttackAction and IsAttackAction(id) and TargetNearestEnemy ) then
			TargetNearestEnemy();
		end
	end
	SimpleQoL_Orig_More_UseAction(id, checkCursor, onSelf);
	SimpleQoL_AfterCast(hadTarget, id);
end

SimpleQoL_Orig_More_CastSpell = CastSpell;
function CastSpell(id, bookType)
	local hadTarget = UnitExists("target");
	SimpleQoL_PressedAction = nil;
	SimpleQoL_Orig_More_CastSpell(id, bookType);
	SimpleQoL_AfterCast(hadTarget);
end

-- "You have no target" right after an action press: target the nearest enemy
-- and press the action once more. Returns 1 when the error should be hidden.
function SimpleQoL_NoTargetError(message)
	if ( not SimpleQoL_On["autotarget"] or SimpleQoL_Retried or not SimpleQoL_PressedAction ) then
		return nil;
	end
	if ( message ~= (ERR_GENERIC_NO_TARGET or "You have no target") or GetTime() - SimpleQoL_PressedTime > 0.5 ) then
		return nil;
	end
	if ( UnitExists("target") or not TargetNearestEnemy ) then
		return nil;
	end
	TargetNearestEnemy();
	if ( not UnitExists("target") ) then
		return nil;
	end
	SimpleQoL_Retried = 1;
	UseAction(SimpleQoL_PressedAction, 0);
	SimpleQoL_Retried = nil;
	SimpleQoL_PressedAction = nil;
	return 1;
end


--------------------------------------------------------------------------------
-- Compare with equipped items (EquipCompare). Uses the stock ShoppingTooltip1
-- and 2, which GameTooltip already hides when it hides.
--------------------------------------------------------------------------------

SimpleQoL_ComparePending = nil;
SimpleQoL_CompareItem = nil;          -- name of the item the compare belongs to

-- Slot text in the tooltip -> inventory slots to show.
function SimpleQoL_CompareSlots(text)
	if ( not text ) then
		return nil;
	end
	local map = {
		{ INVTYPE_HEAD, "HeadSlot" }, { INVTYPE_NECK, "NeckSlot" }, { INVTYPE_SHOULDER, "ShoulderSlot" },
		{ INVTYPE_CLOAK, "BackSlot" }, { INVTYPE_CHEST, "ChestSlot" }, { INVTYPE_ROBE, "ChestSlot" },
		{ INVTYPE_BODY, "ShirtSlot" }, { INVTYPE_TABARD, "TabardSlot" }, { INVTYPE_WRIST, "WristSlot" },
		{ INVTYPE_HAND, "HandsSlot" }, { INVTYPE_WAIST, "WaistSlot" }, { INVTYPE_LEGS, "LegsSlot" },
		{ INVTYPE_FEET, "FeetSlot" }, { INVTYPE_FINGER, "Finger0Slot", "Finger1Slot" },
		{ INVTYPE_TRINKET, "Trinket0Slot", "Trinket1Slot" },
		{ INVTYPE_WEAPON, "MainHandSlot", "SecondaryHandSlot" }, { INVTYPE_2HWEAPON, "MainHandSlot", "SecondaryHandSlot" },
		{ INVTYPE_WEAPONMAINHAND, "MainHandSlot" }, { INVTYPE_WEAPONOFFHAND, "SecondaryHandSlot" },
		{ INVTYPE_SHIELD, "SecondaryHandSlot" }, { INVTYPE_HOLDABLE, "SecondaryHandSlot" },
		{ INVTYPE_RANGED, "RangedSlot" }, { "Wand", "RangedSlot" }, { "Bow", "RangedSlot" }, { "Gun", "RangedSlot" },
		{ "Crossbow", "RangedSlot" }, { "Thrown", "RangedSlot" }, { "Ranged Right", "RangedSlot" },
	};
	local i;
	for i = 1, getn(map) do
		if ( map[i][1] and text == map[i][1] ) then
			return map[i];
		end
	end
	return nil;
end

function SimpleQoL_CompareHide()
	ShoppingTooltip1:Hide();
	ShoppingTooltip2:Hide();
	SimpleQoL_CompareItem = nil;
end

function SimpleQoL_CompareShow()
	SimpleQoL_ComparePending = nil;
	if ( not SimpleQoL_On["compare"] or not GameTooltip:IsVisible() ) then
		return;
	end
	local name = GameTooltipTextLeft1:GetText();
	if ( name and name == SimpleQoL_CompareItem and ShoppingTooltip1:IsVisible() ) then
		return;                       -- the same item again (tooltip refresh)
	end
	SimpleQoL_CompareHide();
	-- The slot is one of the first lines (after the name and "Binds when ...").
	-- Lines 2 to 7 (this client can show an id line first); the slot is on
	-- the left, the weapon type (e.g. Wand) on the right.
	local slots, i;
	for i = 2, 7 do
		local line = getglobal("GameTooltipTextLeft"..i);
		local right = getglobal("GameTooltipTextRight"..i);
		if ( line and line:IsVisible() ) then
			slots = SimpleQoL_CompareSlots(line:GetText());
			if ( not slots and right and right:IsVisible() ) then
				slots = SimpleQoL_CompareSlots(right:GetText());
			end
			if ( slots ) then
				break
			end
		end
	end
	if ( not slots ) then
		return;
	end
	-- Open on the side of the screen with room.
	local x = GameTooltip:GetCenter();
	local sx = UIParent:GetCenter();
	local point, relative = "TOPLEFT", "TOPRIGHT";
	if ( x and sx and x > sx ) then
		point, relative = "TOPRIGHT", "TOPLEFT";
	end
	local anchor = GameTooltip;
	local shown = 0;
	for i = 2, getn(slots) do
		local slotId = GetInventorySlotInfo(slots[i]);
		local tooltip = getglobal("ShoppingTooltip"..(shown + 1));
		if ( slotId and tooltip ) then
			tooltip:SetOwner(GameTooltip, "ANCHOR_NONE");
			if ( tooltip:SetInventoryItem("player", slotId) ) then
				tooltip:ClearAllPoints();
				tooltip:SetPoint(point, anchor:GetName(), relative, 0, 0);
				tooltip:Show();
				anchor = tooltip;
				shown = shown + 1;
			else
				tooltip:Hide();
			end
		end
	end
	if ( shown > 0 ) then
		SimpleQoL_CompareItem = name;
	end
end

-- Item tooltips (bags, quest rewards, quest log, merchant, loot, trade,
-- crafting) ask for a compare on the next frame, when their lines are set.
function SimpleQoL_HookCompare(method)
	local orig = GameTooltip[method];
	if ( not orig ) then
		return;
	end
	GameTooltip[method] = function(self, a, b, c)
		local r1, r2 = orig(self, a, b, c);
		if ( self == GameTooltip ) then
			SimpleQoL_ComparePending = 1;
		end
		return r1, r2;
	end;
end

SimpleQoL_HookCompare("SetBagItem");
SimpleQoL_HookCompare("SetLootItem");
SimpleQoL_HookCompare("SetMerchantItem");
SimpleQoL_HookCompare("SetQuestItem");
SimpleQoL_HookCompare("SetQuestLogItem");
SimpleQoL_HookCompare("SetTradePlayerItem");
SimpleQoL_HookCompare("SetTradeTargetItem");
SimpleQoL_HookCompare("SetCraftItem");
SimpleQoL_HookCompare("SetTradeSkillItem");

function SimpleQoL_CompareUpdate()
	if ( SimpleQoL_ComparePending ) then
		SimpleQoL_CompareShow();
	elseif ( SimpleQoL_CompareItem and ( not GameTooltip:IsVisible() or GameTooltipTextLeft1:GetText() ~= SimpleQoL_CompareItem ) ) then
		SimpleQoL_CompareHide();
	end
end


--------------------------------------------------------------------------------
-- Trainer: after Train, select the next spell you can learn.
--------------------------------------------------------------------------------

SimpleQoL_TrainIndex = nil;
SimpleQoL_TrainName = nil;
SimpleQoL_TrainSub = nil;
SimpleQoL_TrainTime = 0;
SimpleQoL_TrainTalent = nil;

function SimpleQoL_TrainRemember(index, talent)
	SimpleQoL_TrainIndex = index;
	SimpleQoL_TrainName = nil;
	SimpleQoL_TrainSub = nil;
	if ( index ) then
		SimpleQoL_TrainName, SimpleQoL_TrainSub = GetTrainerServiceInfo(index);
	end
	SimpleQoL_TrainTime = GetTime();
	SimpleQoL_TrainTalent = talent;
end

SimpleQoL_Orig_ClassTrainerTrain = ClassTrainerTrainButton_OnClick;
function ClassTrainerTrainButton_OnClick()
	SimpleQoL_TrainRemember(ClassTrainerFrame.selectedService, nil);
	SimpleQoL_Orig_ClassTrainerTrain();
end

SimpleQoL_Orig_TalentTrainerTrain = TalentTrainerTrainButton_OnClick;
function TalentTrainerTrainButton_OnClick()
	SimpleQoL_TrainRemember(TalentTrainerFrame.selectedService, 1);
	SimpleQoL_Orig_TalentTrainerTrain();
end

-- Runs on TRAINER_UPDATE after the stock trainer frames handled it. The list
-- can update more than once after Train, and the first update may come
-- before the spell is learned: we wait (up to 5 seconds) until the trained
-- line is no longer available, then select the next available line below it,
-- or the first one from the top when there is none below.
function SimpleQoL_TrainerNext()
	local start = SimpleQoL_TrainIndex;
	if ( not start ) then
		return;
	end
	if ( not SimpleQoL_On["trainer"] or GetTime() - SimpleQoL_TrainTime > 5 ) then
		SimpleQoL_TrainIndex = nil;
		return;
	end
	local count = GetNumTrainerServices();
	local i, n;
	for i = 1, count do
		local name, subText, serviceType = GetTrainerServiceInfo(i);
		if ( name == SimpleQoL_TrainName and subText == SimpleQoL_TrainSub and serviceType == "available" ) then
			return;
		end
	end
	SimpleQoL_TrainIndex = nil;
	if ( count < 1 ) then
		return;
	end
	start = max(1, min(start, count));
	local found;
	for n = 0, count - 1 do
		i = mod(start - 1 + n, count) + 1;
		local name, subText, serviceType = GetTrainerServiceInfo(i);
		if ( serviceType == "available" ) then
			found = i;
			break
		end
	end
	if ( not found ) then
		return;
	end
	local frame, scroll, displayed, height, selectFn, updateFn;
	if ( SimpleQoL_TrainTalent ) then
		frame, scroll, displayed, height = TalentTrainerFrame, TalentTrainerListScrollFrame, TALENTS_DISPLAYED, TALENT_TRAINER_SKILL_HEIGHT;
		selectFn, updateFn = TalentTrainer_SetSelection, TalentTrainerFrame_Update;
	else
		frame, scroll, displayed, height = ClassTrainerFrame, ClassTrainerListScrollFrame, CLASS_TRAINER_SKILLS_DISPLAYED, CLASS_TRAINER_SKILL_HEIGHT;
		selectFn, updateFn = ClassTrainer_SetSelection, ClassTrainerFrame_Update;
	end
	if ( not frame or not frame:IsVisible() or not selectFn ) then
		return;
	end
	frame.showSkillDetails = 1;
	frame.selectedService = found;
	selectFn(found);
	-- Scroll so the selected line can be seen.
	local offset = FauxScrollFrame_GetOffset(scroll) or 0;
	if ( found <= offset or found > offset + (displayed or 11) ) then
		offset = max(0, min(found - 1, count - (displayed or 11)));
		FauxScrollFrame_SetOffset(scroll, offset);
		getglobal(scroll:GetName().."ScrollBar"):SetValue(offset * (height or 16));
	end
	updateFn();
end


--------------------------------------------------------------------------------
-- Open clams automatically / heal at 10% health
--------------------------------------------------------------------------------

SIMPLEQOL_CLAMS = { "Small Barnacled Clam", "Thick-shelled Clam", "Big-mouth Clam", "Soft-shelled Clam" };
SIMPLEQOL_BLOODSTONES = { "Greater Bloodstone", "Bloodstone", "Lesser Bloodstone", "Minor Bloodstone" };
SIMPLEQOL_POTIONS = { "Major Healing Potion", "Superior Healing Potion", "Greater Healing Potion", "Healing Potion",
	"Lesser Healing Potion", "Minor Healing Potion", "Discolored Healing Potion" };
SimpleQoL_ClamTime = nil;             -- GetTime() for the next clam check
SimpleQoL_ClamLooting = nil;          -- 1 = the next loot window is a clam
SimpleQoL_HealTime = 0;

-- First bag slot holding one of the names (in list order); ready = no cooldown.
function SimpleQoL_FindNamed(list, ready)
	local i, bag, slot;
	for i = 1, getn(list) do
		for bag = 0, 4 do
			for slot = 1, GetContainerNumSlots(bag) do
				local link = GetContainerItemLink(bag, slot);
				if ( link and SimpleQoL_LinkName(link) == list[i] ) then
					local start = 0;
					if ( ready and GetContainerItemCooldown ) then
						start = GetContainerItemCooldown(bag, slot);
					end
					if ( not start or start == 0 ) then
						return bag, slot, list[i];
					end
				end
			end
		end
	end
	return nil;
end

function SimpleQoL_ClamUpdate()
	if ( not SimpleQoL_ClamTime or GetTime() < SimpleQoL_ClamTime ) then
		return;
	end
	SimpleQoL_ClamTime = nil;
	if ( not SimpleQoL_On["clams"] ) then
		return;
	end
	-- Only while you do nothing else: not in combat, casting, eating or
	-- drinking, mounted, or holding something on the cursor.
	if ( SimpleQoL_InCombat or UnitIsDead("player") or (LootFrame and LootFrame:IsVisible()) or SimpleQoL_Busy()
			or SimpleQoL_CursorBusy() or SimpleQoL_IsEating() or SimpleQoL_IsMounted() ) then
		SimpleQoL_ClamTime = GetTime() + 2;
		return;
	end
	local bag, slot = SimpleQoL_FindNamed(SIMPLEQOL_CLAMS);
	if ( bag ) then
		SimpleQoL_ClamLooting = 1;
		UseContainerItem(bag, slot);
		-- More clams: the bag update after looting checks again.
	end
end

-- Low health in combat (percent from the /qol boxes): Bloodstone or potion,
-- and for priests and paladins the emergency shield. A running cast is broken
-- with a jump first (0.5.3 has no SpellStopCasting; moving breaks a cast),
-- and everything is tried again 0.2 seconds later.
SimpleQoL_ShieldTime = 0;
SimpleQoL_EmergencyJump = 0;
SimpleQoL_EmergencyRetry = nil;
SIMPLEQOL_SHIELD_SPELLS = {
	priest = { "Holy Word: Shield" },
	paladin = { "Divine Shield", "Lay on Hands", "Divine Favor" },
	rogue = { "Vanish" },
	warrior = { "Shield Wall" },
	mage = { "Frost Nova" },
	hunter = { "Feign Death" },
	warlock = {},                     -- the Voidwalker's Sacrifice (a pet action)
	shaman = { "Ethereal Form" },
};
-- Spells that leave a buff on you: while one is on you nothing more is cast.
SIMPLEQOL_SHIELD_BUFFS = { ["Holy Word: Shield"] = 1, ["Divine Shield"] = 1, ["Divine Favor"] = 1,
	["Shield Wall"] = 1, ["Feign Death"] = 1, ["Ethereal Form"] = 1 };
SimpleQoL_EvasionTime = 0;
SimpleQoL_ShieldTries = 0;            -- casts close together (a cast that keeps failing)
SimpleQoL_ShieldBlockUntil = 0;

function SimpleQoL_HealthLow(pct)
	local health, maxHealth = UnitHealth("player"), UnitHealthMax("player");
	return health and maxHealth and maxHealth > 0 and health > 0 and health <= maxHealth * pct / 100;
end

-- Highest rank of a spell in your spell book, or nil.
function SimpleQoL_FindSpell(name)
	local i, found = 1, nil;
	while ( 1 ) do
		local spell = GetSpellName(i, "spell");
		if ( not spell ) then
			return found;
		end
		if ( spell == name ) then
			found = i;
		end
		i = i + 1;
	end
end

function SimpleQoL_SpellReady(id)
	if ( not GetSpellCooldown ) then
		return 1;
	end
	local start, duration = GetSpellCooldown(id, "spell");
	return not start or start == 0 or not duration or start + duration <= GetTime();
end

-- 1 when the buff of this spell is on you (same icon, or same name in the
-- buff tooltip).
function SimpleQoL_HasSpellBuff(id, name)
	if ( not GetPlayerBuff ) then
		return nil;
	end
	local icon = GetSpellTexture and GetSpellTexture(id, "spell");
	local i;
	for i = 0, 23 do
		local index = GetPlayerBuff(i, "HELPFUL");
		if ( index and index >= 0 ) then
			if ( icon and GetPlayerBuffTexture and GetPlayerBuffTexture(index) == icon ) then
				return 1;
			end
			if ( SimpleQoL_TooltipName and SimpleQoL_TooltipName("SetPlayerBuff", index) == name ) then
				return 1;
			end
		end
	end
	return nil;
end

-- Ready to use something now; otherwise a running cast is broken first.
function SimpleQoL_EmergencyReady()
	if ( SpellIsTargeting and SpellIsTargeting() and SpellStopTargeting ) then
		SpellStopTargeting();
	end
	local casting = SimpleQoL_Casting or (CastingBarFrame and (CastingBarFrame.casting or CastingBarFrame.channeling));
	if ( not casting ) then
		return 1;
	end
	local now = GetTime();
	if ( Jump and now - SimpleQoL_EmergencyJump > 1.5 ) then
		SimpleQoL_EmergencyJump = now;
		if ( SimpleWalk_Move ) then
			SimpleWalk_Move(Jump);
		else
			Jump();
		end
	end
	SimpleQoL_EmergencyRetry = now + 0.2;
	return nil;
end

-- The spell to cast now, or nil. Priest: the shield unless it is on you.
-- Paladin: Divine Shield; Lay on Hands only when Divine Shield is not on you
-- and cannot be cast (cooldown or not learned), then Divine Favor. Rogue:
-- Vanish. Warrior: Shield Wall. Mage: Frost Nova. Hunter: Feign Death.
function SimpleQoL_ShieldSpell(class)
	local list = SIMPLEQOL_SHIELD_SPELLS[class];
	-- Rogue: Vanish, unless you are in stealth already.
	if ( class == "rogue" and SimpleQoL_IsStealthed and SimpleQoL_IsStealthed() ) then
		return nil;
	end
	local ids = {};
	local i;
	for i = 1, getn(list) do
		ids[i] = SimpleQoL_FindSpell(list[i]) or 0;
		if ( ids[i] ~= 0 and SIMPLEQOL_SHIELD_BUFFS[list[i]] and SimpleQoL_HasSpellBuff(ids[i], list[i]) ) then
			return nil;
		end
	end
	-- The first one that can be cast now (paladin: Divine Shield, then Lay on
	-- Hands, then Divine Favor).
	for i = 1, getn(list) do
		if ( ids[i] ~= 0 and SimpleQoL_SpellReady(ids[i]) ) then
			return ids[i], list[i];
		end
	end
	return nil;
end

function SimpleQoL_ShieldCheck()
	if ( not SimpleQoL_On["shield"] or not SimpleQoL_InCombat or GetTime() - SimpleQoL_ShieldTime < 0.5 ) then
		return;
	end
	local class = SimpleQoL_ShieldClass();
	if ( not class or not GetSpellName or not SimpleQoL_HealthLow(SimpleQoL_Pct.Shield) ) then
		return;
	end
	if ( GetTime() < SimpleQoL_ShieldBlockUntil ) then
		return;
	end
	if ( class == "warlock" ) then
		SimpleQoL_SacrificeCheck();
		return;
	end
	local id, name = SimpleQoL_ShieldSpell(class);
	if ( not id or not SimpleQoL_EmergencyReady() ) then
		return;
	end
	-- A cast that keeps failing (Shield Wall without a shield ...): a pause
	-- after three tries, so the error does not repeat all the time.
	if ( GetTime() - SimpleQoL_ShieldTime < 2 ) then
		SimpleQoL_ShieldTries = SimpleQoL_ShieldTries + 1;
	else
		SimpleQoL_ShieldTries = 1;
	end
	if ( SimpleQoL_ShieldTries > 3 ) then
		SimpleQoL_ShieldTries = 0;
		SimpleQoL_ShieldBlockUntil = GetTime() + 10;
		return;
	end
	SimpleQoL_ShieldTime = GetTime();
	-- Checked again after 0.5 seconds: no shield on you and still low health
	-- (stunned, interrupted ...) means it is tried again.
	SimpleQoL_ShieldVerify = GetTime() + 0.5;
	-- A friendly target other than you would get the spell.
	if ( (class == "priest" or class == "paladin") and UnitExists("target") and UnitIsFriend("player", "target") and not UnitIsUnit("target", "player") ) then
		ClearTarget();
	end
	CastSpell(id, "spell");
	if ( SpellIsTargeting and SpellIsTargeting() ) then
		SpellTargetUnit("player");
	end
	SimpleQoL_Print("low health, cast "..name..".");
end

-- Warlock: the Voidwalker's "Sacrificial Shield" (any name with "sacrific"), only
-- while a pet that has it (Voidwalker) is out and it is ready.
function SimpleQoL_SacrificeSlot()
	if ( not GetPetActionInfo or not CastPetAction or not (PetHasActionBar and PetHasActionBar()) ) then
		return nil;
	end
	local i;
	for i = 1, 10 do
		local name = GetPetActionInfo(i);
		if ( name and strfind(strlower(name), "sacrific", 1, 1) ) then
			if ( GetPetActionCooldown ) then
				local start, duration = GetPetActionCooldown(i);
				if ( start and start > 0 and duration and start + duration > GetTime() ) then
					return nil;
				end
			end
			return i, name;
		end
	end
	return nil;
end

function SimpleQoL_SacrificeCheck()
	local slot, name = SimpleQoL_SacrificeSlot();
	if ( not slot ) then
		return;
	end
	SimpleQoL_ShieldTime = GetTime();
	CastPetAction(slot);
	SimpleQoL_Print("low health, your pet used "..name..".");
end

-- Rogue: Evasion at its own percent (a second box next to Vanish).
function SimpleQoL_EvasionCheck()
	if ( not SimpleQoL_On["evasion"] or not SimpleQoL_InCombat or GetTime() - SimpleQoL_EvasionTime < 0.5 ) then
		return;
	end
	if ( SimpleQoL_ShieldClass() ~= "rogue" or not GetSpellName or not SimpleQoL_HealthLow(SimpleQoL_Pct.Evasion) ) then
		return;
	end
	-- Not in stealth, and not right after Vanish.
	if ( GetTime() - SimpleQoL_ShieldTime < 1 or (SimpleQoL_IsStealthed and SimpleQoL_IsStealthed()) ) then
		return;
	end
	local id = SimpleQoL_FindSpell("Evasion");
	if ( not id or SimpleQoL_HasSpellBuff(id, "Evasion") or not SimpleQoL_SpellReady(id) or not SimpleQoL_EmergencyReady() ) then
		return;
	end
	SimpleQoL_EvasionTime = GetTime();
	CastSpell(id, "spell");
	SimpleQoL_Print("low health, cast Evasion.");
end

function SimpleQoL_HealthCheck()
	SimpleQoL_ShieldCheck();
	SimpleQoL_EvasionCheck();
	-- Only in combat.
	if ( not SimpleQoL_On["autoheal"] or not SimpleQoL_InCombat or GetTime() - SimpleQoL_HealTime < 2 ) then
		return;
	end
	if ( not SimpleQoL_HealthLow(SimpleQoL_Pct.Heal) ) then
		return;
	end
	local bag, slot, name = SimpleQoL_FindNamed(SIMPLEQOL_BLOODSTONES, 1);
	if ( not bag ) then
		bag, slot, name = SimpleQoL_FindNamed(SIMPLEQOL_POTIONS, 1);
	end
	if ( bag and SimpleQoL_EmergencyReady() ) then
		SimpleQoL_HealTime = GetTime();
		UseContainerItem(bag, slot);
		SimpleQoL_Print("low health, used "..name..".");
	end
end

-- Runs from the OnUpdate: the retry after a cast was broken.
function SimpleQoL_EmergencyUpdate()
	if ( SimpleQoL_EmergencyRetry and GetTime() >= SimpleQoL_EmergencyRetry ) then
		SimpleQoL_EmergencyRetry = nil;
		SimpleQoL_HealthCheck();
	end
	if ( SimpleQoL_ShieldVerify and GetTime() >= SimpleQoL_ShieldVerify ) then
		SimpleQoL_ShieldVerify = nil;
		SimpleQoL_ShieldCheck();
	end
end


--------------------------------------------------------------------------------
-- Share position with other SimpleQoL users. Messages go through a hidden
-- password channel (not an "_addon" channel: those are not passed on to other
-- players). Shown on the minimap here and on SimpleMap.
--------------------------------------------------------------------------------

SIMPLEQOL_POS_CHANNEL = SIMPLE_HELLO_CHANNEL or "SimpleAddons";
SIMPLEQOL_POS_PASSWORD = SIMPLE_HELLO_PASSWORD or "sAdd0nz7q";
SIMPLEQOL_POS_SEND = 3;              -- seconds between sends while moving
SIMPLEQOL_POS_HEARTBEAT = 15;        -- seconds between sends while standing
SIMPLEQOL_POS_TIMEOUT = 30;          -- forget players not heard for this long
SIMPLEQOL_NUM_DOTS = 20;
-- Zone sizes in yards: 0.5.3 WorldMapArea bounds are inclusive tile indices,
-- so a map spans (right - left + 1) tiles of 533.33 yards (confirmed in game).
SIMPLEQOL_ZONE_YARDS = {
	Durotar = { 6400, 4267 }, Mulgore = { 6400, 4267 }, Barrens = { 12800, 8533 }, Kalimdor = { 33600, 22400 },
	Azeroth = { 30400, 20267 }, Alterac = { 3200, 2133 }, Arathi = { 4800, 3200 }, Badlands = { 4800, 3200 },
	Blackrock = { 3200, 2133 }, BlastedLands = { 4800, 3200 }, Tirisfal = { 4800, 3200 }, Silverpine = { 4800, 3200 },
	WesternPlaguelands = { 4800, 3200 }, EasternPlaguelands = { 6400, 4267 }, Hilsbrad = { 4800, 3200 },
	Hinterlands = { 4800, 3200 }, DunMorogh = { 4800, 3200 }, SearingGorge = { 4800, 3200 }, BurningSteppes = { 3200, 2133 },
	Elwynn = { 4800, 3200 }, DarrowmereLake = { 3200, 2133 }, DeadwindPass = { 3200, 2133 }, Duskwood = { 3200, 2133 },
	LochModan = { 4800, 3200 }, Redridge = { 3200, 2133 }, Stranglethorn = { 6400, 4267 }, SwampOfSorrows = { 3200, 2133 },
	Westfall = { 4800, 3200 }, Wetlands = { 4800, 3200 },
};
-- Minimap diameter in yards per zoom level (outdoor values of the later
-- clients; to be confirmed in 0.5.3).
SIMPLEQOL_MINIMAP_YARDS = { 466.67, 400, 333.33, 266.67, 200, 133.33 };

-- Minimap diameter in yards (read from the 0.5.3 client code): outdoors
-- 466.67, 400, 333.33, 266.67, 200, 133.33 and indoors 300, 240, 180, 120,
-- 80, 50 for zoom 0..5. Indoors is found with the two zoom settings:
-- the minimap shows the "inside" zoom when you are indoors (cities and
-- buildings count as indoors).
SIMPLEQOL_MINIMAP_INDOOR = { 300, 240, 180, 120, 80, 50 };
SimpleQoL_MinimapInside = nil;
SimpleQoL_MinimapInsideTime = -10;

function SimpleQoL_MinimapIsInside()
	if ( GetTime() - SimpleQoL_MinimapInsideTime < 1 ) then
		return SimpleQoL_MinimapInside;
	end
	SimpleQoL_MinimapInsideTime = GetTime();
	if ( not Minimap or not Minimap.GetZoom ) then
		return nil;
	end
	local zoom = Minimap:GetZoom();
	local outZoom = GetCVar and tonumber(GetCVar("minimapZoom"));
	local inZoom = GetCVar and tonumber(GetCVar("minimapInsideZoom"));
	local inside = nil;
	if ( outZoom and inZoom ) then
		if ( outZoom ~= inZoom ) then
			inside = (zoom == inZoom);
		else
			-- Both settings equal: change the zoom for a moment and see which
			-- of the two follows.
			local other = zoom;
			if ( zoom < 2 ) then
				other = zoom + 1;
			else
				other = zoom - 1;
			end
			Minimap:SetZoom(other);
			inside = (tonumber(GetCVar("minimapZoom")) ~= Minimap:GetZoom());
			Minimap:SetZoom(zoom);
		end
	end
	SimpleQoL_MinimapInside = inside;
	return inside;
end

function SimpleQoL_MinimapYards()
	local zoom = 0;
	if ( Minimap.GetZoom ) then
		zoom = Minimap:GetZoom();
	end
	if ( SimpleQoL_MinimapIsInside() ) then
		return SIMPLEQOL_MINIMAP_INDOOR[zoom + 1] or SIMPLEQOL_MINIMAP_INDOOR[1];
	end
	return SIMPLEQOL_MINIMAP_YARDS[zoom + 1] or SIMPLEQOL_MINIMAP_YARDS[1];
end

SimpleQoL_Players = {};               -- { name, map, x, y, time }
SimpleQoL_PosJoinTime = 0;
SimpleQoL_PosSentTime = 0;
SimpleQoL_PosCheckTime = 0;
SimpleQoL_PosLast = nil;              -- last sent text
SimpleQoL_PosZoneDirty = 1;           -- the map must be set to the current zone
SimpleQoL_DotTime = 0;
SimpleQoL_MyMap = nil;
SimpleQoL_MyX = nil;
SimpleQoL_MyY = nil;

function SimpleQoL_PlayersOn()
	return SimpleQoL_On["share"] or SimpleQoL_On["shareguild"];
end

function SimpleQoL_MyGuild()
	local name = GetGuildInfo and GetGuildInfo("player");
	return name or "";
end

-- What a player shares: "F" (faction: everyone who shares) or "G" (guild
-- only). Faction wins when both are on. nil = nothing.
function SimpleQoL_ShareMode()
	if ( SimpleQoL_On["share"] ) then
		return "F";
	end
	if ( SimpleQoL_On["shareguild"] and SimpleQoL_MyGuild() ~= "" ) then
		return "G";
	end
	return nil;
end

-- Do you see this player? You must share yourself (faction or guild). A
-- faction player is seen by everyone who shares faction and by their
-- guildmates; a guild player only by guildmates.
function SimpleQoL_PosVisible(p)
	if ( not SimpleQoL_PlayersOn() ) then
		return nil;
	end
	local mine = SimpleQoL_MyGuild();
	local sameGuild = mine ~= "" and p.guild == mine;
	if ( p.mode == "G" ) then
		return sameGuild;
	end
	return SimpleQoL_On["share"] or sameGuild;
end

function SimpleQoL_PosChannel()
	local number = GetChannelName and GetChannelName(SIMPLEQOL_POS_CHANNEL);
	if ( number and number > 0 ) then
		return number;
	end
	if ( GetTime() - SimpleQoL_PosJoinTime > 15 ) then
		SimpleQoL_PosJoinTime = GetTime();
		JoinChannelByName(SIMPLEQOL_POS_CHANNEL, SIMPLEQOL_POS_PASSWORD);
	end
	return nil;
end

-- The map must show your zone for GetPlayerMapPosition. Only changed while no
-- map window is open, so a map you are looking at is never switched.
function SimpleQoL_PosMapReady(force)
	local mapOpen = (WorldMapFrame and WorldMapFrame:IsVisible()) or (SimpleMapFrame and SimpleMapFrame:IsVisible());
	local x, y = GetPlayerMapPosition("player");
	if ( x and (x > 0 or y > 0) and not SimpleQoL_PosZoneDirty ) then
		return 1;
	end
	if ( mapOpen ) then
		return x and (x > 0 or y > 0);
	end
	-- A search that found no position (inside an instance, for example) is
	-- not repeated every half second: the pause grows to 10 seconds, and a
	-- zone change starts over at once.
	if ( not force and not SimpleQoL_PosZoneDirty and SimpleQoL_PosRetryAt and GetTime() < SimpleQoL_PosRetryAt ) then
		return nil;
	end
	SimpleQoL_PosZoneDirty = nil;
	if ( SimpleMap_FindWorldZone ) then
		SimpleMap_FindWorldZone();
	else
		SimpleQoL_FindZoneMap();
	end
	x, y = GetPlayerMapPosition("player");
	if ( x and (x > 0 or y > 0) ) then
		SimpleQoL_PosRetryAt = nil;
		SimpleQoL_PosRetryWait = nil;
		return 1;
	end
	SimpleQoL_PosRetryWait = min(10, (SimpleQoL_PosRetryWait or 0.5) * 2);
	SimpleQoL_PosRetryAt = GetTime() + SimpleQoL_PosRetryWait;
	return nil;
end

-- Same search as SimpleMap's "Current Zone", for use without SimpleMap.
function SimpleQoL_FindZoneMap()
	local zone = strlower(GetZoneText() or "");
	local c, z;
	if ( zone == "" ) then
		return;
	end
	c = 1;
	while ( c <= 2 ) do
		local zones = { GetMapZones(c) };
		for z = 1, getn(zones) do
			if ( strlower(zones[z]) == zone ) then
				SetMapZoom(c, z);
				return;
			end
		end
		c = c + 1;
	end
	for c = 1, 2 do
		SetMapZoom(c);
		local x, y = GetPlayerMapPosition("player");
		if ( x and (x > 0 or y > 0) ) then
			return;
		end
	end
end

function SimpleQoL_PosUpdate()
	local now = GetTime();
	-- Checked twice a second at most (in a zone without a position this made
	-- the map search run on every frame).
	if ( now - SimpleQoL_PosCheckTime < 0.5 ) then
		return;
	end
	SimpleQoL_PosCheckTime = now;
	if ( now - SimpleQoL_PosSentTime < SIMPLEQOL_POS_SEND ) then
		return;
	end
	local mode = SimpleQoL_ShareMode();
	if ( not mode ) then
		return;
	end
	local channel = SimpleQoL_PosChannel();
	if ( not channel or not SimpleQoL_PosMapReady() ) then
		SimpleQoL_MyMap = nil;
		return;
	end
	local x, y = GetPlayerMapPosition("player");
	SimpleQoL_MyMap = GetMapInfo();
	SimpleQoL_MyX = x;
	SimpleQoL_MyY = y;
	if ( not SimpleQoL_MyMap ) then
		return;
	end
	local text = "P2;"..SimpleQoL_MyMap..";"..floor(x * 1000 + 0.5)..";"..floor(y * 1000 + 0.5)..";"..mode..";"..SimpleQoL_MyGuild();
	if ( text == SimpleQoL_PosLast and now - SimpleQoL_PosSentTime < SIMPLEQOL_POS_HEARTBEAT ) then
		return;
	end
	SimpleQoL_PosLast = text;
	SimpleQoL_PosSentTime = now;
	SendChatMessage(text, "CHANNEL", nil, channel);
end

-- A message in the position channel.
function SimpleQoL_PosMessage(message, sender)
	if ( not sender or sender == UnitName("player") ) then
		return;
	end
	local s, e, map, x, y, mode, guild = strfind(message or "", "^P2;([^;]+);(%d+);(%d+);(%a);(.*)$");
	if ( not map ) then
		-- Older versions: everyone, no guild.
		s, e, map, x, y = strfind(message or "", "^P1;([^;]+);(%d+);(%d+)$");
		mode, guild = "F", "";
	end
	if ( not map ) then
		return;
	end
	local i, entry;
	for i = 1, getn(SimpleQoL_Players) do
		if ( SimpleQoL_Players[i].name == sender ) then
			entry = SimpleQoL_Players[i];
		end
	end
	if ( not entry ) then
		entry = { name = sender };
		tinsert(SimpleQoL_Players, entry);
	end
	entry.map = map;
	entry.mode = mode;
	entry.guild = guild or "";
	entry.x = (x + 0) / 1000;
	entry.y = (y + 0) / 1000;
	entry.time = GetTime();
end

function SimpleQoL_IsPosChannel(text)
	-- The lower case name is made once, not for every chat message.
	SimpleQoL_PosChannelLower = SimpleQoL_PosChannelLower or strlower(SIMPLEQOL_POS_CHANNEL);
	return text and strfind(strlower(text), SimpleQoL_PosChannelLower, 1, 1);
end

-- A player in your party already has the party dot, so no second dot.
function SimpleQoL_InMyParty(name)
	local n = GetNumPartyMembers and GetNumPartyMembers() or 0;
	local i;
	for i = 1, n do
		if ( UnitName("party"..i) == name ) then
			return 1;
		end
	end
	return nil;
end

-- Players on the minimap, like party members.
SimpleQoL_DotsIdle = nil;

function SimpleQoL_DotsUpdate()
	-- With no dots to show the check is only made twice a second.
	local wait = 0.05;
	if ( SimpleQoL_DotsIdle ) then
		wait = 0.5;
	end
	if ( GetTime() - SimpleQoL_DotTime < wait ) then
		return;
	end
	SimpleQoL_DotTime = GetTime();
	local shown = 0;
	local i;
	-- Forget players not heard from for a while.
	i = 1;
	while ( i <= getn(SimpleQoL_Players) ) do
		if ( GetTime() - SimpleQoL_Players[i].time > SIMPLEQOL_POS_TIMEOUT ) then
			tremove(SimpleQoL_Players, i);
		else
			i = i + 1;
		end
	end
	if ( getn(SimpleQoL_Players) == 0 or not SimpleQoL_PlayersOn() ) then
		if ( not SimpleQoL_DotsIdle ) then
			SimpleQoL_DotsIdle = 1;
			local k;
			for k = 1, SIMPLEQOL_NUM_DOTS do
				getglobal("SimpleQoLMinimapDot"..k):Hide();
			end
		end
		return;
	end
	SimpleQoL_DotsIdle = nil;
	local size = SimpleQoL_MyMap and SIMPLEQOL_ZONE_YARDS[SimpleQoL_MyMap];
	-- Your own position every update (not only when it is sent), so the
	-- dots stay put while you move.
	-- When the map no longer shows your zone (another addon or a zone change
	-- moved it) the zone is found again, otherwise your position is stuck and
	-- the dots would move with you.
	if ( SimpleQoL_MyMap ) then
		local x, y = GetPlayerMapPosition("player");
		if ( GetMapInfo() ~= SimpleQoL_MyMap or not x or (x == 0 and y == 0) ) then
			if ( SimpleQoL_PosMapReady() ) then
				SimpleQoL_MyMap = GetMapInfo();
				size = SimpleQoL_MyMap and SIMPLEQOL_ZONE_YARDS[SimpleQoL_MyMap];
				x, y = GetPlayerMapPosition("player");
			end
		end
		if ( GetMapInfo() == SimpleQoL_MyMap and x and (x > 0 or y > 0) ) then
			SimpleQoL_MyX = x;
			SimpleQoL_MyY = y;
		end
	end
	if ( SimpleQoL_PlayersOn() and size and SimpleQoL_MyX ) then
		local yards = SimpleQoL_MinimapYards();
		local radius = Minimap:GetWidth() / 2;
		local scale = Minimap:GetWidth() / yards;
		for i = 1, getn(SimpleQoL_Players) do
			local p = SimpleQoL_Players[i];
			-- A player in the next zone is converted to your map (SimpleMap).
			local px, py = nil, nil;
			if ( p.map == SimpleQoL_MyMap ) then
				px, py = p.x, p.y;
			elseif ( SimpleMap_ConvertPos ) then
				px, py = SimpleMap_ConvertPos(p.map, p.x, p.y, SimpleQoL_MyMap);
			end
			if ( shown < SIMPLEQOL_NUM_DOTS and px and not SimpleQoL_InMyParty(p.name) and SimpleQoL_PosVisible(p) ) then
				local dx = (px - SimpleQoL_MyX) * size[1] * scale;
				local dy = (py - SimpleQoL_MyY) * size[2] * scale;
				if ( dx * dx + dy * dy < (radius - 4) * (radius - 4) ) then
					shown = shown + 1;
					local dot = getglobal("SimpleQoLMinimapDot"..shown);
					dot.name = p.name;
					dot:ClearAllPoints();
					dot:SetPoint("CENTER", "Minimap", "CENTER", dx, -dy);
					dot:Show();
				end
			end
		end
	end
	for i = shown + 1, SIMPLEQOL_NUM_DOTS do
		getglobal("SimpleQoLMinimapDot"..i):Hide();
	end
end

function SimpleQoL_Dot_OnEnter()
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText(this.name or "");
	GameTooltip:Show();
end

-- Our position channel never shows in the chat.
SimpleQoL_Orig_More_ChatFrame_OnEvent = ChatFrame_OnEvent;
function ChatFrame_OnEvent(event)
	if ( strfind(event, "^CHAT_MSG_CHANNEL") and SimpleQoL_IsPosChannel((arg4 or "").." "..(arg9 or "").." "..(arg1 or "")) ) then
		return;
	end
	SimpleQoL_Orig_More_ChatFrame_OnEvent(event);
end


--------------------------------------------------------------------------------
-- Events and update (SimpleQoLMoreFrame)
--------------------------------------------------------------------------------

function SimpleQoL_More_OnLoad()
	this:RegisterEvent("TRAINER_UPDATE");
	this:RegisterEvent("BAG_UPDATE");
	this:RegisterEvent("UNIT_HEALTH");
	this:RegisterEvent("CHAT_MSG_CHANNEL");
	this:RegisterEvent("ZONE_CHANGED");
	this:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	this:RegisterEvent("MINIMAP_ZONE_CHANGED");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_REGEN_ENABLED");
end

function SimpleQoL_More_OnEvent(event)
	if ( event == "TRAINER_UPDATE" ) then
		SimpleQoL_TrainerNext();
	elseif ( event == "BAG_UPDATE" or event == "PLAYER_REGEN_ENABLED" ) then
		if ( SimpleQoL_On["clams"] ) then
			SimpleQoL_ClamTime = GetTime() + 0.5;
		end
	elseif ( event == "UNIT_HEALTH" ) then
		if ( arg1 == "player" ) then
			SimpleQoL_HealthCheck();
		end
	elseif ( event == "CHAT_MSG_CHANNEL" ) then
		if ( SimpleQoL_IsPosChannel((arg4 or "").." "..(arg9 or "")) ) then
			SimpleQoL_PosMessage(arg1, arg2);
		end
	else
		-- Zone changes and login: find the zone map again before the next send.
		SimpleQoL_PosZoneDirty = 1;
		SimpleQoL_PosRetryAt = nil;
		SimpleQoL_PosRetryWait = nil;
	end
end

function SimpleQoL_More_OnUpdate()
	if ( not SimpleQoL_Loaded ) then
		return;
	end
	SimpleQoL_CompareUpdate();
	SimpleQoL_ClamUpdate();
	SimpleQoL_EmergencyUpdate();
	SimpleQoL_PosUpdate();
	SimpleQoL_DotsUpdate();
end


--------------------------------------------------------------------------------
-- /position and /gps: your coordinates, or your target's when you have one,
-- as zone coordinates and as server X / Y (Z is not known to the client).
-- /cinfo: what the client knows about your target.
--------------------------------------------------------------------------------

function SimpleQoL_UnitPosition(unit)
	-- A command you typed always searches.
	if ( not SimpleQoL_PosMapReady(1) ) then
		return nil;
	end
	local x, y = GetPlayerMapPosition(unit);
	if ( not x or (x == 0 and y == 0) ) then
		return nil;
	end
	return x, y, GetMapInfo();
end

function SimpleQoL_PositionLines(unit)
	local name = UnitName(unit) or "?";
	local x, y, map = SimpleQoL_UnitPosition(unit);
	if ( not x ) then
		return { name..": position not known here." };
	end
	local lines = { format("%s: %s %.1f, %.1f", name, GetZoneText() or "", x * 100, y * 100) };
	if ( SimpleMap_WorldPos ) then
		local wx, wy, mapId = SimpleMap_WorldPos(map, x, y);
		if ( wx ) then
			tinsert(lines, format("X: %.1f, Y: %.1f, Map: %d (Z is not known to the client)", wx, wy, mapId));
		end
	end
	return lines;
end

function SimpleQoL_ChatLines(lines)
	local i;
	for i = 1, getn(lines) do
		ChatFrame:AddMessage(lines[i], 1.0, 1.0, 0.0);
	end
end

SLASH_SIMPLEQOLPOSITION1 = "/position";
SLASH_SIMPLEQOLPOSITION2 = "/gps";
SlashCmdList["SIMPLEQOLPOSITION"] = function(msg)
	local unit = "player";
	if ( UnitExists("target") ) then
		unit = "target";
	end
	SimpleQoL_ChatLines(SimpleQoL_PositionLines(unit));
end;

-- The first line of this client's unit tooltip can be the GUID ("0x...").
function SimpleQoL_TargetGuid()
	if ( not SimpleQoLScanTooltip or not SimpleQoLScanTooltip.SetUnit ) then
		return nil;
	end
	SimpleQoLScanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	SimpleQoLScanTooltip:SetUnit("target");
	local i;
	for i = 1, 3 do
		local line = getglobal("SimpleQoLScanTooltipTextLeft"..i);
		local text = line and line:GetText();
		if ( text and strfind(text, "^0x%x+$") ) then
			return text;
		end
	end
	return nil;
end

function SimpleQoL_CreatureInfo()
	if ( not UnitExists("target") ) then
		return { "/cinfo: you have no target." };
	end
	local lines = { "["..(UnitName("target") or "?").."]" };
	tinsert(lines, "Level: "..(UnitLevel("target") or "?"));
	tinsert(lines, "Health: "..(UnitHealth("target") or 0).." / "..(UnitHealthMax("target") or 0));
	if ( UnitManaMax and (UnitManaMax("target") or 0) > 0 ) then
		tinsert(lines, "Mana: "..(UnitMana("target") or 0).." / "..UnitManaMax("target"));
	end
	local reaction = UnitReaction and UnitReaction("player", "target");
	local kind = "neutral";
	if ( UnitIsEnemy and UnitIsEnemy("player", "target") ) then
		kind = "hostile";
	elseif ( UnitIsFriend("player", "target") ) then
		kind = "friendly";
	end
	tinsert(lines, "Reaction: "..kind..(reaction and (" ("..reaction..")") or ""));
	if ( UnitIsPlayer and UnitIsPlayer("target") ) then
		tinsert(lines, "Player: "..(UnitClass("target") or "?").." "..(UnitRace and UnitRace("target") or ""));
	end
	local guid = SimpleQoL_TargetGuid();
	if ( guid ) then
		tinsert(lines, "Guid: "..guid);
	end
	local pos = SimpleQoL_PositionLines("target");
	local i;
	for i = 1, getn(pos) do
		tinsert(lines, pos[i]);
	end
	return lines;
end

SLASH_SIMPLEQOLCINFO1 = "/cinfo";
SlashCmdList["SIMPLEQOLCINFO"] = function(msg)
	SimpleQoL_ChatLines(SimpleQoL_CreatureInfo());
end;
