--------------------------------------------------------------------------------
-- SimpleMacros on action buttons.
--
-- A macro is placed on a real action slot (stock bar, bonus bar, and the
-- ActionBars addon when it is installed). The client cannot hold a macro on
-- the cursor, so a macro is "carried" by an icon that follows the mouse:
--   * drag a macro from the macro window and let go over an action button
--   * or click it (Shift+click in the window, or drag and let go elsewhere),
--     then click an action button
--   * drag a macro from one action button to another the same way (click the
--     target button), right-click or Escape cancels
-- Dragging a real spell onto a macro button replaces the macro, and the macro
-- you replaced is carried (swap), like spells.
--
-- The action functions the buttons use (HasAction, GetActionTexture,
-- UseAction, PickupAction, ...) are wrapped. Without a macro in a slot every
-- call goes straight to the original function.
--------------------------------------------------------------------------------

SimpleMacros_AssignRef = nil;           -- macro being carried ("g3")
SimpleMacros_Dragging = nil;            -- carried from the macro window with the button still down
SimpleMacros_DropTime = 0;
SimpleMacros_SlotCount = 0;
SimpleMacros_GridOn = nil;
SimpleMacros_Buttons = nil;             -- action buttons (found once)
SimpleMacros_SlotTexture = {};          -- slot -> texture shown last
SimpleMacros_SlotTimer = 0;
SimpleMacros_SlotCDLen = {};
SimpleMacros_SlotCD = {};               -- slot -> cooldown last shown
SimpleMacros_SlotActive = {};           -- slot -> 1 when shown as active
SimpleMacros_ShowNames = 1;             -- macro name on its action button (letters at the bottom right)
SIMPLEMACROS_NAME_LETTERS = 6;

-- 1 if a macro is placed in this action slot, else nil.
function SimpleMacros_SlotMacro(slot)
	local ref = SimpleMacros_Slot[slot];
	if ( not ref ) then
		return nil;
	end
	return SimpleMacros_GetMacroByRef(ref);
end

-- The action buttons of the stock bars and of ActionBars (when installed).
function SimpleMacros_FindButtons()
	if ( SimpleMacros_Buttons ) then
		return SimpleMacros_Buttons;
	end
	local list = {};
	local i, button;
	for i = 1, 12 do
		button = getglobal("ActionButton"..i);
		if ( button ) then
			tinsert(list, button);
		end
		button = getglobal("BonusActionButton"..i);
		if ( button ) then
			tinsert(list, button);
		end
	end
	for i = 25, 72 do
		button = getglobal("ActionBarsButton"..i);
		if ( button ) then
			tinsert(list, button);
		end
	end
	-- Only cached once the buttons exist (after the interface has loaded).
	if ( getn(list) > 0 and SimpleMacros_Loaded ) then
		SimpleMacros_Buttons = list;
	end
	return list;
end

--------------------------------------------------------------------------------
-- Slot data
--------------------------------------------------------------------------------

function SimpleMacros_CountSlots()
	local count = 0;
	local slot;
	for slot = 1, SIMPLEMACROS_MAX_SLOT do
		if ( SimpleMacros_Slot[slot] ) then
			count = count + 1;
		end
	end
	SimpleMacros_SlotCount = count;
	if ( SimpleMacrosSlotFrame ) then
		if ( count > 0 ) then
			SimpleMacrosSlotFrame:Show();
		else
			SimpleMacrosSlotFrame:Hide();
		end
	end
end

-- "12=g3;25=c5"
function SimpleMacros_SlotsToString()
	local text = "";
	local slot;
	for slot = 1, SIMPLEMACROS_MAX_SLOT do
		if ( SimpleMacros_Slot[slot] ) then
			if ( text ~= "" ) then
				text = text..";";
			end
			text = text..slot.."="..SimpleMacros_Slot[slot];
		end
	end
	return text;
end

function SimpleMacros_SlotsFromString(text)
	local slot, ref;
	SimpleMacros_Slot = {};
	if ( text ) then
		for slot, ref in string.gfind(text, "(%d+)=([gc]%d+)") do
			slot = tonumber(slot);
			if ( slot and slot >= 1 and slot <= SIMPLEMACROS_MAX_SLOT ) then
				SimpleMacros_Slot[slot] = ref;
			end
		end
	end
	SimpleMacros_CountSlots();
end

-- Makes the buttons of one slot draw again.
function SimpleMacros_SlotChanged(slot)
	local list = SimpleMacros_FindButtons();
	local oldThis = this;
	local i, button;
	SimpleMacros_SlotTexture[slot] = nil;
	SimpleMacros_SlotCD[slot] = nil;
	SimpleMacros_SlotActive[slot] = nil;
	for i = 1, getn(list) do
		button = list[i];
		-- Only buttons that are shown: showing a hidden button here runs the
		-- scripts of its child frames in the middle of the stock update.
		-- A hidden button updates itself when its bar shows it.
		if ( button:IsVisible() and ActionButton_GetPagedID(button) == slot ) then
			this = button;
			ActionButton_Update();
			this = button;
			ActionButton_UpdateState();
		end
	end
	if ( ActionBars_OnEvent and ActionBarsEventFrame ) then
		this = ActionBarsEventFrame;
		ActionBars_OnEvent("ACTIONBAR_SLOT_CHANGED");
	end
	this = oldThis;
end

function SimpleMacros_SetSlot(slot, ref)
	if ( not slot or slot < 1 or slot > SIMPLEMACROS_MAX_SLOT ) then
		return;
	end
	SimpleMacros_Slot[slot] = ref;
	SimpleMacros_CountSlots();
	SimpleMacros_Storage_SaveSlots();
	SimpleMacros_SlotChanged(slot);
end

-- A deleted macro leaves the buttons.
function SimpleMacros_RemoveRefFromSlots(ref)
	local slot;
	local removed = {};
	for slot = 1, SIMPLEMACROS_MAX_SLOT do
		if ( SimpleMacros_Slot[slot] == ref ) then
			SimpleMacros_Slot[slot] = nil;
			tinsert(removed, slot);
		end
	end
	if ( getn(removed) > 0 ) then
		SimpleMacros_CountSlots();
		SimpleMacros_Storage_SaveSlots();
		for slot = 1, getn(removed) do
			SimpleMacros_SlotChanged(removed[slot]);
		end
	end
end

-- After loading or any change of the macros: every macro button draws again.
function SimpleMacrosSlots_Refresh()
	if ( SimpleMacros_SlotCount == 0 ) then
		return;
	end
	local slot;
	for slot = 1, SIMPLEMACROS_MAX_SLOT do
		if ( SimpleMacros_Slot[slot] ) then
			SimpleMacros_SlotChanged(slot);
		end
	end
end

-- Cooldown of what the macro shows (spell or item), 0 when it shows nothing.
function SimpleMacros_SlotCooldown(macro)
	local kind, a, b = SimpleMacros_ShowTarget(macro);
	local start, duration, enable;
	if ( kind == "spell" and GetSpellCooldown ) then
		start, duration, enable = GetSpellCooldown(a, b);
	elseif ( kind == "slot" and GetInventoryItemCooldown ) then
		start, duration, enable = GetInventoryItemCooldown("player", a);
	elseif ( kind == "bag" and GetContainerItemCooldown ) then
		start, duration, enable = GetContainerItemCooldown(a, b);
	end
	if ( start and duration ) then
		return start, duration, enable or 1;
	end
	return 0, 0, 0;
end


--------------------------------------------------------------------------------
-- Carrying a macro
--------------------------------------------------------------------------------

-- Empty slots light up while a macro is carried, like when a spell is dragged.
function SimpleMacros_Grid(on)
	if ( (on and SimpleMacros_GridOn) or (not on and not SimpleMacros_GridOn) ) then
		return;
	end
	SimpleMacros_GridOn = on;
	local ev = "ACTIONBAR_HIDEGRID";
	if ( on ) then
		ev = "ACTIONBAR_SHOWGRID";
	end
	local oldThis = this;
	local list = SimpleMacros_FindButtons();
	local i;
	for i = 1, getn(list) do
		this = list[i];
		ActionButton_OnEvent(ev);
	end
	if ( ActionBars_OnEvent and ActionBarsEventFrame ) then
		this = ActionBarsEventFrame;
		ActionBars_OnEvent(ev);
	end
	this = oldThis;
end

-- Spells that cannot be cast in combat: the button of a macro that shows one
-- is dark in combat, like the normal button.
SIMPLEMACROS_NOCOMBAT = { ["Stealth"] = 1, ["Prowl"] = 1, ["Sap"] = 1 };

-- 1 / nil: the list above first (the native button has the same blind spot
-- in combat - it stays bright for these - so checking it first used to hide
-- the NOCOMBAT dark-out whenever a macro happened to mirror a normal
-- button), else the normal button of the same spell, else bright.
function SimpleMacros_MacroUsable(macro)
	if ( SimpleMacros_InCombat ) then
		local kind, a, b = SimpleMacros_ShowTarget(macro);
		if ( kind == "spell" and GetSpellName ) then
			local name = GetSpellName(a, b);
			if ( name and SIMPLEMACROS_NOCOMBAT[name] ) then
				return nil;
			end
		end
	end
	local mirror = SimpleMacros_MirrorSlot(macro);
	if ( mirror and SimpleMacros_SlotNative.IsUsableAction ) then
		local usable = SimpleMacros_SlotNative.IsUsableAction(mirror);
		return usable;
	end
	return 1;
end

-- The buttons look at what they may do again (after entering or leaving combat).
function SimpleMacros_RefreshUsable()
	local oldThis = this;
	local list = SimpleMacros_FindButtons();
	local i;
	for i = 1, getn(list) do
		this = list[i];
		ActionButton_OnEvent("ACTIONBAR_UPDATE_USABLE");
	end
	this = oldThis;
end

function SimpleMacros_StartAssign(ref, quiet)
	local macro = SimpleMacros_GetMacroByRef(ref);
	if ( not macro ) then
		return;
	end
	SimpleMacros_AssignRef = ref;
	SimpleMacrosCarryIcon:SetTexture(SimpleMacros_MacroTexture(macro));
	SimpleMacrosCarry_Follow();
	SimpleMacrosCarryFrame:Show();
	SimpleMacrosCatcher:Show();
	SimpleMacros_Grid(1);
	if ( not quiet ) then
		SimpleMacros_Print("Click an action button to place the macro (right-click or Escape cancels).");
	end
end

function SimpleMacros_ClearAssign()
	SimpleMacros_AssignRef = nil;
	SimpleMacros_Dragging = nil;
	SimpleMacrosCarryFrame:Hide();
	SimpleMacrosCatcher:Hide();
	SimpleMacros_Grid(nil);
end

-- Units: frame positions (GetLeft, GetCenter) and the mouse use screen units,
-- SetPoint uses interface units. The probes in the XML give the factor.
function SimpleMacros_Scale()
	local x1 = SimpleMacrosProbeBoxTopLeft:GetCenter();
	local x2 = SimpleMacrosProbeBoxBottomRight:GetCenter();
	if ( not x1 or not x2 ) then
		return 1;
	end
	local width = x2 - x1;
	if ( width < 0 ) then
		width = -width;
	end
	if ( width < 10 ) then
		return 1;
	end
	return 98 / width;
end

-- The icon that follows the mouse while a macro is carried.
function SimpleMacrosCarry_Follow()
	local x, y = GetCursorPosition();
	local sx, sy = SimpleMacrosProbeScreen:GetCenter();
	if ( not x or not sx ) then
		return;
	end
	local k = SimpleMacros_Scale();
	SimpleMacrosCarryFrame:ClearAllPoints();
	SimpleMacrosCarryFrame:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", (x - sx) * k + 1, (y - sy) * k + 1);
end

-- True when the mouse is over the frame. GetCenter and the mouse are in screen
-- units, GetWidth and GetHeight in interface units (factor from the probes).
function SimpleMacros_CursorIn(frame)
	local x, y = GetCursorPosition();
	local cx, cy = frame:GetCenter();
	local width, height = frame:GetWidth(), frame:GetHeight();
	if ( not x or not cx or not width or not height ) then
		return nil;
	end
	local k = SimpleMacros_Scale();
	local dx = x - cx;
	local dy = y - cy;
	if ( dx < 0 ) then
		dx = -dx;
	end
	if ( dy < 0 ) then
		dy = -dy;
	end
	return dx <= width / k / 2 and dy <= height / k / 2;
end

-- Action slot of the button under the mouse, or nil.
function SimpleMacros_SlotAtCursor()
	local list = SimpleMacros_FindButtons();
	local i, button;
	for i = 1, getn(list) do
		button = list[i];
		if ( button:IsVisible() and SimpleMacros_CursorIn(button) ) then
			return ActionButton_GetPagedID(button);
		end
	end
	return nil;
end

-- Puts the carried macro in a slot. What was there is swapped: a spell goes to
-- the cursor, a macro is carried.
function SimpleMacros_PlaceCarried(slot)
	local ref = SimpleMacros_AssignRef;
	if ( not ref or not slot ) then
		return;
	end
	local old = SimpleMacros_Slot[slot];
	if ( old and not SimpleMacros_GetMacroByRef(old) ) then
		old = nil;
	end
	local native = SimpleMacros_SlotNative;
	if ( native.HasAction(slot) ) then
		native.PickupAction(slot);
	end
	-- The slot is filled before the grid goes off, so its button stays shown.
	SimpleMacros_SetSlot(slot, ref);
	SimpleMacros_ClearAssign();
	if ( old and old ~= ref ) then
		SimpleMacros_StartAssign(old, 1);
	end
end

-- Drag from the macro window: let go over an action button to place it.
-- Let go over the window to cancel. Let go elsewhere: the macro keeps
-- following the mouse until you click an action button.
function SimpleMacros_DropFromWindow()
	if ( not SimpleMacros_Dragging or not SimpleMacros_AssignRef ) then
		return;
	end
	SimpleMacros_Dragging = nil;
	SimpleMacros_DropTime = GetTime();
	local slot = SimpleMacros_SlotAtCursor();
	if ( slot ) then
		SimpleMacros_PlaceCarried(slot);
	elseif ( SimpleMacrosFrame:IsVisible() and SimpleMacros_CursorIn(SimpleMacrosFrame) ) then
		SimpleMacros_ClearAssign();
	end
end

-- A click on the world (nothing else under the mouse) drops the macro.
function SimpleMacrosCatcher_OnMouseUp(button)
	if ( SimpleMacros_AssignRef and GetTime() - SimpleMacros_DropTime > 0.2 ) then
		SimpleMacros_ClearAssign();
	end
end


-- Some spells change the icon on a normal action button (for example while
-- they are on cooldown or active). A macro that shows such a spell follows the
-- icon of a normal action button that holds the same spell. The button is found
-- by its icon when the spell is idle, and only trusted while its icon is the
-- spell icon, or the cooldown or active state shows it is the same spell.
SIMPLEMACROS_REAL_SLOTS = 120;

function SimpleMacros_SameIcon(a, b)
	if ( not a or not b ) then
		return nil;
	end
	return strlower(a) == strlower(b);
end

function SimpleMacros_NearTime(a, b)
	if ( not a or not b ) then
		return nil;
	end
	local d = a - b;
	if ( d < 0 ) then
		d = -d;
	end
	return d < 0.05;
end

-- Lower case icon -> first normal button (lowest number) that has it, made
-- once per frame.
SimpleMacros_IconSlotMap = nil;
SimpleMacros_IconSlotTime = -10;
function SimpleMacros_IconSlots(now)
	if ( SimpleMacros_IconSlotMap and now - SimpleMacros_IconSlotTime < 0.02 ) then
		return SimpleMacros_IconSlotMap;
	end
	local map = {};
	local native = SimpleMacros_SlotNative;
	local i, texture, key;
	for i = 1, SIMPLEMACROS_REAL_SLOTS do
		if ( not SimpleMacros_Slot[i] and native.HasAction(i) ) then
			texture = native.GetActionTexture(i);
			if ( texture ) then
				key = strlower(texture);
				if ( not map[key] ) then
					map[key] = i;
				end
			end
		end
	end
	SimpleMacros_IconSlotMap = map;
	SimpleMacros_IconSlotTime = now;
	return map;
end

function SimpleMacros_MirrorTexture(macro, base)
	-- An icon chosen by hand always stays.
	if ( macro.icon and macro.icon ~= "" and macro.icon ~= SIMPLEMACROS_DEFAULT_ICON ) then
		macro.mirror = nil;
		return base;
	end
	local kind = SimpleMacros_ShowTarget(macro);
	if ( kind ~= "spell" or not base ) then
		macro.mirror = nil;
		return base;
	end
	local native = SimpleMacros_SlotNative;
	local slot = macro.mirror;
	if ( slot and (SimpleMacros_Slot[slot] or not native.HasAction(slot)) ) then
		macro.mirror = nil;
		slot = nil;
	end
	if ( slot ) then
		local texture = native.GetActionTexture(slot);
		if ( SimpleMacros_SameIcon(texture, base) ) then
			macro.alt = nil;
			return base;
		end
		local ok = texture and macro.alt == texture;
		if ( texture and not ok ) then
			local s1, d1 = native.GetActionCooldown(slot);
			local s2, d2 = SimpleMacros_SlotCooldown(macro);
			if ( d1 and d1 > 0 and SimpleMacros_NearTime(s1, s2) and SimpleMacros_NearTime(d1, d2) ) then
				ok = 1;
			elseif ( native.IsCurrentAction and native.IsCurrentAction(slot) and SimpleMacros_MacroActive(macro) ) then
				ok = 1;
			end
		end
		if ( ok ) then
			macro.alt = texture;
			return texture;
		end
		macro.mirror = nil;
	end
	-- Look for a button holding the spell (not more often than every 2 seconds).
	local now = GetTime();
	if ( not macro.mirrorTry or now - macro.mirrorTry > 2 ) then
		macro.mirrorTry = now;
		-- The normal buttons are read once per frame for all macros (before, each
		-- macro read all of them); the first button with the same icon wins.
		local found = nil;
		if ( base ) then
			found = SimpleMacros_IconSlots(now)[strlower(base)];
		end
		if ( found ) then
			macro.mirror = found;
		end
		if ( not macro.mirror ) then
			-- Not on any button: look again only after a while.
			macro.mirrorTry = now + 8;
		end
	end
	return base;
end

-- The normal button holding the same spell (found by SimpleMacros_MirrorTexture):
-- what it reports is what the macro button should show as well.
function SimpleMacros_MirrorSlot(macro)
	local slot = macro.mirror;
	if ( slot and not SimpleMacros_Slot[slot] ) then
		return slot;
	end
	return nil;
end

-- "Checked" glow: the spell is being cast or is queued (as on the normal
-- button), or a toggle spell is active.
function SimpleMacros_MacroCurrent(macro)
	local slot = SimpleMacros_MirrorSlot(macro);
	local native = SimpleMacros_SlotNative;
	if ( slot and native.IsCurrentAction and native.IsCurrentAction(slot) ) then
		return 1;
	end
	return SimpleMacros_MacroActive(macro);
end

-- Toggle spells show as "checked" on a normal button while their buff is up
-- (Stealth and so on). A macro that shows such a spell does the same.
SimpleMacros_ToggleIcons = nil;

SimpleMacros_IconBaseCache = {};
function SimpleMacros_IconBase(texture)
	-- Remembered per texture name: the buff check asks again and again.
	local base = SimpleMacros_IconBaseCache[texture or ""];
	if ( not base ) then
		base = strlower(gsub(texture or "", "^.*\\", ""));
		SimpleMacros_IconBaseCache[texture or ""] = base;
	end
	return base;
end

function SimpleMacros_MacroActive(macro)
	local kind, a, b = SimpleMacros_ShowTarget(macro);
	if ( kind ~= "spell" or not GetSpellTexture or not GetPlayerBuff or not GetPlayerBuffTexture ) then
		return nil;
	end
	local texture = GetSpellTexture(a, b);
	if ( not texture ) then
		return nil;
	end
	if ( not SimpleMacros_ToggleIcons ) then
		SimpleMacros_ToggleIcons = {};
		local name, icon;
		if ( SIMPLEMACROS_AURA_ICONS ) then
			for name, icon in SIMPLEMACROS_AURA_ICONS do
				SimpleMacros_ToggleIcons[icon] = 1;
			end
		end
	end
	local base = SimpleMacros_IconBase(texture);
	if ( not SimpleMacros_ToggleIcons[base] ) then
		return nil;
	end
	local i, buff, buffTexture;
	for i = 0, 31 do
		buff = GetPlayerBuff(i, "HELPFUL");
		if ( not buff or buff < 0 ) then
			break
		end
		buffTexture = GetPlayerBuffTexture(buff);
		if ( buffTexture and SimpleMacros_IconBase(buffTexture) == base ) then
			return 1;
		end
	end
	return nil;
end


--------------------------------------------------------------------------------
-- The action functions
--------------------------------------------------------------------------------

if ( not SimpleMacros_SlotNative ) then
	SimpleMacros_SlotNative = {
		HasAction = HasAction,
		GetActionTexture = GetActionTexture,
		GetActionCount = GetActionCount,
		GetActionCooldown = GetActionCooldown,
		IsUsableAction = IsUsableAction,
		IsCurrentAction = IsCurrentAction,
		IsAutoRepeatAction = IsAutoRepeatAction,
		IsAttackAction = IsAttackAction,
		UseAction = UseAction,
		PickupAction = PickupAction,
		PlaceAction = PlaceAction,
		SetAction = GameTooltip.SetAction,
	};

	function HasAction(slot)
		if ( SimpleMacros_Slot[slot] and SimpleMacros_SlotMacro(slot) ) then
			return 1;
		end
		return SimpleMacros_SlotNative.HasAction(slot);
	end

	-- Working out a macro (spell search, tooltips) can run frame scripts, which
	-- change `this`; the stock code that called us still needs it. So it is put
	-- back in every wrapper that works out a macro.
	function GetActionTexture(slot)
		if ( SimpleMacros_Slot[slot] ) then
			local macro = SimpleMacros_SlotMacro(slot);
			if ( macro ) then
				local oldThis = this;
				local texture = SimpleMacros_MirrorTexture(macro, SimpleMacros_MacroTexture(macro));
				this = oldThis;
				return texture;
			end
		end
		return SimpleMacros_SlotNative.GetActionTexture(slot);
	end

	function GetActionCount(slot)
		if ( SimpleMacros_Slot[slot] and SimpleMacros_SlotMacro(slot) ) then
			return 0;
		end
		return SimpleMacros_SlotNative.GetActionCount(slot);
	end

	function GetActionCooldown(slot)
		if ( SimpleMacros_Slot[slot] ) then
			local macro = SimpleMacros_SlotMacro(slot);
			if ( macro ) then
				local oldThis = this;
				local start, duration, enable = SimpleMacros_SlotCooldown(macro);
				this = oldThis;
				return start, duration, enable;
			end
		end
		return SimpleMacros_SlotNative.GetActionCooldown(slot);
	end

	function IsUsableAction(slot)
		if ( SimpleMacros_Slot[slot] ) then
			local macro = SimpleMacros_SlotMacro(slot);
			if ( macro ) then
				local oldThis = this;
				local usable = SimpleMacros_MacroUsable(macro);
				this = oldThis;
				return usable, nil;
			end
		end
		return SimpleMacros_SlotNative.IsUsableAction(slot);
	end

	if ( SimpleMacros_SlotNative.IsCurrentAction ) then
		function IsCurrentAction(slot)
			if ( SimpleMacros_Slot[slot] ) then
				local macro = SimpleMacros_SlotMacro(slot);
				if ( macro ) then
					local oldThis = this;
					local active = SimpleMacros_MacroCurrent(macro);
					this = oldThis;
					return active;
				end
			end
			return SimpleMacros_SlotNative.IsCurrentAction(slot);
		end
	end

	if ( SimpleMacros_SlotNative.IsAutoRepeatAction ) then
		function IsAutoRepeatAction(slot)
			if ( SimpleMacros_Slot[slot] ) then
				local macro = SimpleMacros_SlotMacro(slot);
				if ( macro ) then
					local mirror = SimpleMacros_MirrorSlot(macro);
					if ( mirror ) then
						return SimpleMacros_SlotNative.IsAutoRepeatAction(mirror);
					end
					return nil;
				end
			end
			return SimpleMacros_SlotNative.IsAutoRepeatAction(slot);
		end
	end

	if ( SimpleMacros_SlotNative.IsAttackAction ) then
		function IsAttackAction(slot)
			if ( SimpleMacros_Slot[slot] ) then
				local macro = SimpleMacros_SlotMacro(slot);
				if ( macro ) then
					local mirror = SimpleMacros_MirrorSlot(macro);
					if ( mirror ) then
						return SimpleMacros_SlotNative.IsAttackAction(mirror);
					end
					return nil;
				end
			end
			return SimpleMacros_SlotNative.IsAttackAction(slot);
		end
	end

	-- Click or key on an action button. While a macro is carried, a click
	-- places it (right-click cancels).
	-- The stock handlers use `this` after calling these, and showing or hiding
	-- a frame here runs its scripts and changes `this`: it is put back.
	function UseAction(slot, checkCursor, onSelf)
		local oldThis = this;
		local r1, r2 = SimpleMacros_UseAction(slot, checkCursor, onSelf);
		this = oldThis;
		return r1, r2;
	end

	function SimpleMacros_UseAction(slot, checkCursor, onSelf)
		if ( SimpleMacros_AssignRef ) then
			if ( arg1 == "RightButton" ) then
				SimpleMacros_ClearAssign();
			else
				SimpleMacros_PlaceCarried(slot);
			end
			return;
		end
		if ( SimpleMacros_Slot[slot] ) then
			local macro = SimpleMacros_SlotMacro(slot);
			if ( macro ) then
				-- A spell or item on the cursor is dropped here, not used.
				if ( checkCursor and CursorHasItem and CursorHasSpell and (CursorHasItem() or CursorHasSpell()) ) then
					PlaceAction(slot);
					return;
				end
				local click = "LeftButton";
				if ( arg1 == "RightButton" ) then
					click = "RightButton";
				end
				SimpleMacros_RunMacro(macro, click);
				return;
			end
		end
		return SimpleMacros_SlotNative.UseAction(slot, checkCursor, onSelf);
	end

	-- Picking up a button: a macro is carried. With a spell on the cursor
	-- the spell goes in and the macro is carried (swap).
	function PickupAction(slot)
		local oldThis = this;
		local r1, r2 = SimpleMacros_PickupAction(slot);
		this = oldThis;
		return r1, r2;
	end

	function SimpleMacros_PickupAction(slot)
		if ( SimpleMacros_AssignRef ) then
			SimpleMacros_PlaceCarried(slot);
			return;
		end
		if ( SimpleMacros_Slot[slot] ) then
			local ref = SimpleMacros_Slot[slot];
			if ( SimpleMacros_GetMacroByRef(ref) ) then
				local native = SimpleMacros_SlotNative;
				if ( not CursorHasItem or not CursorHasSpell or CursorHasItem() or CursorHasSpell() ) then
					native.PlaceAction(slot);
				end
				SimpleMacros_SetSlot(slot, nil);
				SimpleMacros_StartAssign(ref, 1);
				return;
			end
		end
		return SimpleMacros_SlotNative.PickupAction(slot);
	end

	-- A spell or item dropped on a macro button replaces the macro.
	function PlaceAction(slot)
		local oldThis = this;
		local r1, r2 = SimpleMacros_PlaceAction(slot);
		this = oldThis;
		return r1, r2;
	end

	function SimpleMacros_PlaceAction(slot)
		-- The client may report a release over a button as a drop.
		if ( SimpleMacros_AssignRef and not SimpleMacros_Dragging ) then
			SimpleMacros_PlaceCarried(slot);
			return;
		end
		if ( SimpleMacros_Slot[slot] ) then
			local ref = SimpleMacros_Slot[slot];
			if ( SimpleMacros_GetMacroByRef(ref) ) then
				SimpleMacros_SetSlot(slot, nil);
				SimpleMacros_SlotNative.PlaceAction(slot);
				SimpleMacros_StartAssign(ref, 1);
				return;
			end
		end
		return SimpleMacros_SlotNative.PlaceAction(slot);
	end

	-- Tooltip: the spell or item the macro shows, else the macro itself.
	function GameTooltip.SetAction(self, slot)
		if ( SimpleMacros_Slot[slot] and this and this.GetName ) then
			local macro = SimpleMacros_SlotMacro(slot);
			if ( macro ) then
				-- Showing the tooltip runs its scripts and changes `this`.
				local oldThis = this;
				SimpleMacros_BarTooltip(this, macro);
				this = oldThis;
				return 1;
			end
		end
		return SimpleMacros_SlotNative.SetAction(self, slot);
	end
end


--------------------------------------------------------------------------------
-- Icons of macros that show a spell or item follow it (changes with the
-- target, bags and so on). Only runs while a macro is on an action button.
--------------------------------------------------------------------------------

function SimpleMacrosSlots_OnUpdate(elapsed)
	SimpleMacros_SlotTimer = SimpleMacros_SlotTimer - (elapsed or 0);
	if ( SimpleMacros_SlotTimer > 0 ) then
		return;
	end
	SimpleMacros_SlotTimer = 0.4;
	if ( SimpleMacros_BindingsDirty ) then
		SimpleMacros_BindingsDirty = nil;
		SimpleMacros_OnMacrosChanged();
	end
	local slot, macro, texture, list, i, button, icon, start, duration, key, active;
	local oldThis = this;
	for slot = 1, SIMPLEMACROS_MAX_SLOT do
		if ( SimpleMacros_Slot[slot] ) then
			macro = SimpleMacros_GetMacroByRef(SimpleMacros_Slot[slot]);
			if ( macro ) then
				-- Cooldown and "active" state follow the spell, also when the
				-- client sends no event for them.
				start, duration = SimpleMacros_SlotCooldown(macro);
				-- Numbers are compared, no new string is made every 0.4 seconds.
				key = (start ~= SimpleMacros_SlotCD[slot] or duration ~= SimpleMacros_SlotCDLen[slot]);
				active = SimpleMacros_MacroCurrent(macro) or 0;
				if ( key or active ~= SimpleMacros_SlotActive[slot] ) then
					local cdChanged = key;
					SimpleMacros_SlotCD[slot] = start;
					SimpleMacros_SlotCDLen[slot] = duration;
					SimpleMacros_SlotActive[slot] = active;
					list = SimpleMacros_FindButtons();
					for i = 1, getn(list) do
						button = list[i];
						if ( ActionButton_GetPagedID(button) == slot and button:IsVisible() ) then
							this = button;
							if ( cdChanged ) then
								ActionButton_UpdateCooldown();
							end
							ActionButton_UpdateState();
						end
					end
				end
				texture = SimpleMacros_MirrorTexture(macro, SimpleMacros_MacroTexture(macro));
				if ( texture ~= SimpleMacros_SlotTexture[slot] ) then
					SimpleMacros_SlotTexture[slot] = texture;
					list = SimpleMacros_FindButtons();
					for i = 1, getn(list) do
						button = list[i];
						if ( ActionButton_GetPagedID(button) == slot ) then
							icon = getglobal(button:GetName().."Icon");
							if ( icon and texture ) then
								icon:SetTexture(texture);
							end
						end
					end
				end
			end
		end
	end
	this = oldThis;
end


--------------------------------------------------------------------------------
-- Macro name on the action button (option, default on). The name is written in
-- the count text of the button, which macros do not use.
--------------------------------------------------------------------------------

if ( ActionButton_UpdateCount and not SimpleMacros_Orig_UpdateCount ) then
	SimpleMacros_Orig_UpdateCount = ActionButton_UpdateCount;
	function ActionButton_UpdateCount()
		SimpleMacros_Orig_UpdateCount();
		-- No macro names on the bars and nothing changed on this button
		-- before: nothing to do (no text is built for every button).
		if ( not this.simpleMacrosName and not (SimpleMacros_ShowNames and SimpleMacros_SlotCount > 0) ) then
			return;
		end
		local text = getglobal(this:GetName().."Count");
		if ( not text ) then
			return;
		end
		local macro = nil;
		if ( SimpleMacros_ShowNames and SimpleMacros_SlotCount > 0 ) then
			macro = SimpleMacros_SlotMacro(ActionButton_GetPagedID(this));
		end
		if ( macro ) then
			-- The name sits in the middle at the bottom of the button.
			if ( not this.simpleMacrosName ) then
				this.simpleMacrosName = 1;
				text:ClearAllPoints();
				text:SetPoint("BOTTOM", this:GetName(), "BOTTOM", 0, 3);
				text:SetJustifyH("CENTER");
			end
			text:SetText(strsub(macro.name or "", 1, SIMPLEMACROS_NAME_LETTERS));
		elseif ( this.simpleMacrosName ) then
			-- Back to the normal place of the count (bottom right).
			this.simpleMacrosName = nil;
			text:ClearAllPoints();
			text:SetPoint("BOTTOMRIGHT", this:GetName(), "BOTTOMRIGHT", -2, 2);
			text:SetJustifyH("RIGHT");
		end
	end
end

function SimpleMacros_SetShowNames(on)
	if ( on ) then
		SimpleMacros_ShowNames = 1;
	else
		SimpleMacros_ShowNames = nil;
	end
	SimpleMacros_Storage_SaveNames();
	SimpleMacrosSlots_Refresh();
	if ( SimpleMacrosNamesButton ) then
		SimpleMacrosFrame_Update();
	end
end

function SimpleMacros_NamesText()
	if ( SimpleMacros_ShowNames ) then
		return "Button names: On";
	end
	return "Button names: Off";
end
