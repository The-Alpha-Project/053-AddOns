--------------------------------------------------------------------------------
-- SimpleMacros windows: the macro window (like 1.12 "Create Macros"), the name and
-- icon popup, and the export window.
--------------------------------------------------------------------------------

SIMPLEMACROS_POPUP_ICONS = 20;          -- icons shown in the popup (5 x 4)
SIMPLEMACROS_POPUP_COLUMNS = 5;
SIMPLEMACROS_POPUP_ROWS = 4;
SIMPLEMACROS_POPUP_ROW = 40;            -- height of a row

SimpleMacrosFrame_Tab = "g";            -- "g" general, "c" character
SimpleMacrosFrame_Selected = nil;       -- selected slot in the current tab
SimpleMacrosFrame_LoadedText = nil;     -- body text when the macro was selected
SimpleMacrosPopup_Slot = nil;           -- square chosen for a new macro
SimpleMacrosPopup_Mode = nil;           -- "new" or "edit"
SimpleMacrosPopup_Icon = 1;             -- selected index in SimpleMacros_Icons


--------------------------------------------------------------------------------
-- Macro window
--------------------------------------------------------------------------------

function SimpleMacrosFrame_Toggle()
	if ( SimpleMacrosFrame:IsVisible() ) then
		HideUIPanel(SimpleMacrosFrame);
	else
		ShowUIPanel(SimpleMacrosFrame);
	end
end

function SimpleMacrosFrame_OnShow()
	PlaySound("igCharacterInfoOpen");
	if ( not SimpleSave_Set ) then
		SimpleMacros_Print("|cffff4040SimpleSave is not installed: macros cannot be saved.|r");
	end
	SimpleMacrosFrame_SelectFirst();
	SimpleMacrosFrame_Update();
end

-- The window must fit on the screen (the interface can be scaled up).
function SimpleMacrosFrame_OnHide()
	PlaySound("igCharacterInfoClose");
	SimpleMacrosFrame_SaveBody();
	SimpleMacrosBodyEditBox:ClearFocus();
	SimpleMacrosPopupFrame:Hide();
	SimpleMacrosHelpFrame:Hide();
	SimpleMacrosShareFrame:Hide();
	if ( SimpleMacros_Dragging ) then
		SimpleMacros_ClearAssign();
	end
end

function SimpleMacrosFrame_SetTab(scope)
	SimpleMacrosFrame_SaveBody();
	SimpleMacrosFrame_Tab = scope;
	SimpleMacrosFrame_SelectFirst();
	SimpleMacrosFrame_Update();
end

-- Selects the first macro of the current tab (or nothing when it is empty).
function SimpleMacrosFrame_SelectFirst()
	local i;
	SimpleMacrosFrame_Selected = nil;
	for i = 1, SIMPLEMACROS_MAX_MACROS do
		if ( SimpleMacros_Macros[SimpleMacrosFrame_Tab][i] ) then
			SimpleMacrosFrame_Select(i);
			return;
		end
	end
	SimpleMacrosFrame_Select(nil);
end

function SimpleMacrosFrame_Select(slot)
	SimpleMacrosFrame_Selected = slot;
	local macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, slot);
	if ( macro ) then
		SimpleMacrosFrame_LoadedText = macro.body;
		SimpleMacrosBodyEditBox:SetText(macro.body);
	else
		SimpleMacrosFrame_LoadedText = nil;
		SimpleMacrosBodyEditBox:SetText("");
	end
	SimpleMacrosBodyEditBox:ClearFocus();
end

-- Saves the body text if it was changed. Called on Save, on selecting another
-- macro, on changing tab and when the window closes (like 1.12).
function SimpleMacrosFrame_SaveBody()
	local macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, SimpleMacrosFrame_Selected);
	if ( not macro ) then
		return;
	end
	local text = SimpleMacrosBodyEditBox:GetText() or "";
	if ( text ~= macro.body ) then
		SimpleMacrosFrame_LoadedText = text;
		SimpleMacros_SetMacro(SimpleMacrosFrame_Tab, SimpleMacrosFrame_Selected, macro.name, macro.icon, text);
	end
end

function SimpleMacrosFrame_Update()
	if ( not SimpleMacrosFrame or not SimpleMacrosFrame:IsVisible() ) then
		return;
	end
	local tab = SimpleMacrosFrame_Tab;
	local i, button, icon, nameText, macro;

	-- Tabs
	SimpleMacrosFrameTabGeneral:SetText("General Macros");
	SimpleMacrosFrameTabCharacter:SetText((SimpleMacros_PlayerName or "Character").." Macros");
	if ( tab == "g" ) then
		SimpleMacrosFrameTabGeneral:Disable();
		SimpleMacrosFrameTabCharacter:Enable();
	else
		SimpleMacrosFrameTabGeneral:Enable();
		SimpleMacrosFrameTabCharacter:Disable();
	end

	-- Grid of 18 macros
	for i = 1, SIMPLEMACROS_MAX_MACROS do
		button = getglobal("SimpleMacrosButton"..i);
		icon = getglobal("SimpleMacrosButton"..i.."Icon");
		nameText = getglobal("SimpleMacrosButton"..i.."Name");
		macro = SimpleMacros_Macros[tab][i];
		if ( macro ) then
			icon:SetTexture(SimpleMacros_MacroTexture(macro));
			icon:Show();
			nameText:SetText(macro.name);
			button:Enable();
		else
			icon:Hide();
			nameText:SetText("");
			button:Enable();
		end
		if ( i == SimpleMacrosFrame_Selected ) then
			button:SetChecked(1);
		else
			button:SetChecked(nil);
		end
	end

	-- Selected macro
	macro = SimpleMacros_GetMacro(tab, SimpleMacrosFrame_Selected);
	if ( macro ) then
		SimpleMacrosSelectedIcon:SetTexture(SimpleMacros_MacroTexture(macro));
		SimpleMacrosSelectedIcon:Show();
		SimpleMacrosSelectedName:SetText(macro.name);
		SimpleMacrosEditButton:Enable();
		SimpleMacrosDeleteButton:Enable();
		SimpleMacrosSaveButton:Enable();
		SimpleMacrosCancelButton:Enable();
		SimpleMacrosBodyEditBox:Show();
	else
		SimpleMacrosSelectedIcon:Hide();
		SimpleMacrosSelectedName:SetText("");
		SimpleMacrosEditButton:Disable();
		SimpleMacrosDeleteButton:Disable();
		SimpleMacrosSaveButton:Disable();
		SimpleMacrosCancelButton:Disable();
		SimpleMacrosBodyEditBox:Hide();
	end

	if ( SimpleMacros_FirstFreeSlot(tab) ) then
		SimpleMacrosNewButton:Enable();
	else
		SimpleMacrosNewButton:Disable();
	end

	SimpleMacrosNamesButton:SetText(SimpleMacros_NamesText());
	SimpleMacrosFrame_UpdateCount();
	SimpleMacrosStatusText:SetText(SimpleMacros_Storage_StatusText());
	if ( not SimpleSave_Set ) then
		SimpleMacrosStatusText:SetTextColor(1.0, 0.25, 0.25);
	elseif ( SimpleMacros_StorageLoaded ) then
		SimpleMacrosStatusText:SetTextColor(0.5, 1.0, 0.5);
	else
		SimpleMacrosStatusText:SetTextColor(1.0, 0.82, 0.0);
	end
end

function SimpleMacrosFrame_UpdateCount()
	local text = SimpleMacrosBodyEditBox:GetText() or "";
	SimpleMacrosCharCount:SetText(strlen(text).."/"..SIMPLEMACROS_MAX_BODY.." Characters Used");
end

function SimpleMacrosButton_OnClick()
	local slot = this:GetID();
	local macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, slot);
	if ( not macro ) then
		-- An empty square: make a new macro on this square.
		this:SetChecked(nil);
		if ( SimpleMacros_AssignRef ) then
			SimpleMacros_ClearAssign();
		end
		if ( arg1 ~= "RightButton" and GetTime() - SimpleMacros_DropTime >= 0.2 ) then
			SimpleMacrosFrame_SaveBody();
			SimpleMacrosPopup_Show("new", slot);
		end
		return;
	end
	if ( GetTime() - SimpleMacros_DropTime < 0.2 ) then
		return;
	end
	if ( SimpleMacros_AssignRef ) then
		SimpleMacros_ClearAssign();
	end
	if ( arg1 == "RightButton" ) then
		-- Right-click tests the macro.
		this:SetChecked(nil);
		SimpleMacros_RunMacro(macro, "RightButton");
		return;
	end
	SimpleMacrosFrame_SaveBody();
	SimpleMacrosFrame_Select(slot);
	if ( IsShiftKeyDown() ) then
		SimpleMacros_StartAssign(SimpleMacros_MakeRef(SimpleMacrosFrame_Tab, slot));
	end
	SimpleMacrosFrame_Update();
end

function SimpleMacrosButton_OnLoad()
	this:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	this:RegisterForDrag("LeftButton");
end

function SimpleMacrosButton_OnEnter()
	local macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, this:GetID());
	if ( macro ) then
		SimpleMacros_ShowTooltip(this, macro);
	end
end

function SimpleMacros_ShowTooltip(owner, macro)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
	GameTooltip:SetText(macro.name, 1.0, 1.0, 1.0);
	local body = (macro.body or "").."\n";
	local line;
	local count = 0;
	for line in string.gfind(body, "([^\n]*)\n") do
		if ( line ~= "" and count < 8 ) then
			GameTooltip:AddLine(line, "", 1.0, 1.0, 1.0);
			count = count + 1;
		end
	end
	GameTooltip:Show();
end

function SimpleMacrosNewButton_OnClick()
	SimpleMacrosFrame_SaveBody();
	SimpleMacrosPopup_Show("new");
end

function SimpleMacrosEditButton_OnClick()
	SimpleMacrosFrame_SaveBody();
	SimpleMacrosPopup_Show("edit");
end

function SimpleMacrosDeleteButton_OnClick()
	if ( not SimpleMacrosFrame_Selected ) then
		return;
	end
	SimpleMacros_DeleteMacro(SimpleMacrosFrame_Tab, SimpleMacrosFrame_Selected);
	SimpleMacrosFrame_SelectFirst();
	SimpleMacrosFrame_Update();
end

function SimpleMacrosSaveButton_OnClick()
	SimpleMacrosFrame_SaveBody();
	SimpleMacrosBodyEditBox:ClearFocus();
	SimpleMacrosFrame_Update();
end

-- Like 1.12: Cancel throws away changes that were not saved and leaves the
-- macro (nothing selected). The macros themselves are not touched.
function SimpleMacrosCancelButton_OnClick()
	local text = SimpleMacrosBodyEditBox:GetText() or "";
	SimpleMacrosBodyEditBox:ClearFocus();
	if ( text ~= (SimpleMacrosFrame_LoadedText or "") ) then
		SimpleMacros_Print("Changes discarded.");
	end
	SimpleMacrosFrame_Select(nil);
	SimpleMacrosFrame_Update();
end

function SimpleMacrosBodyEditBox_OnTextChanged()
	local scrollBar = getglobal(this:GetParent():GetName().."ScrollBar");
	this:GetParent():UpdateScrollChildRect();
	local min, max = scrollBar:GetMinMaxValues();
	if ( max > 0 and this.max ~= max ) then
		this.max = max;
		scrollBar:SetValue(max);
	end
	SimpleMacrosFrame_UpdateCount();
end

-- Dragging a macro out of the window: it follows the mouse. Let go over an
-- action button to place it (see SimpleMacros_Slots.lua).
function SimpleMacrosButton_OnDragStart()
	local macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, this:GetID());
	if ( not macro ) then
		return;
	end
	SimpleMacrosFrame_SaveBody();
	SimpleMacros_ClearAssign();
	SimpleMacros_StartAssign(SimpleMacros_MakeRef(SimpleMacrosFrame_Tab, this:GetID()), 1);
	SimpleMacros_Dragging = 1;
end

function SimpleMacrosButton_OnMouseUp()
	SimpleMacros_DropFromWindow();
end


--------------------------------------------------------------------------------
-- Name and icon popup
--------------------------------------------------------------------------------

function SimpleMacrosPopup_Show(mode, slot)
	SimpleMacrosPopup_Mode = mode;
	SimpleMacrosPopup_Slot = slot;
	SimpleMacrosPopup_Icon = 1;
	local macro = nil;
	if ( mode == "edit" ) then
		macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, SimpleMacrosFrame_Selected);
		if ( not macro ) then
			return;
		end
		SimpleMacrosPopupNameEditBox:SetText(macro.name);
		SimpleMacrosPopup_Icon = SimpleMacrosPopup_FindIcon(macro.icon);
	else
		SimpleMacrosPopupNameEditBox:SetText("");
	end
	SimpleMacrosHelpFrame:Hide();
	SimpleMacrosShareFrame:Hide();
	SimpleMacrosPopupSearchEditBox:SetText("");
	SimpleMacrosPopup_View = nil;
	SimpleMacrosPopupFrame:Show();
	SimpleMacrosPopupNameEditBox:SetFocus();
	SimpleMacrosPopup_Update();
	SimpleMacrosPopup_ScrollToIcon();
	SimpleMacrosPopup_Update();
end

function SimpleMacrosPopup_FindIcon(icon)
	local lowerIcon = strlower(icon or "");
	local i;
	for i = 1, getn(SimpleMacros_Icons) do
		if ( strlower(SimpleMacros_Icons[i]) == lowerIcon ) then
			return i;
		end
	end
	return 1;
end

-- Search: SimpleMacrosPopup_View is nil (all icons) or a list of indexes into
-- SimpleMacros_Icons whose names contain the search text.
SimpleMacrosPopup_View = nil;
SimpleMacrosPopup_Keys = nil;

function SimpleMacrosPopup_Count()
	if ( SimpleMacrosPopup_View ) then
		return getn(SimpleMacrosPopup_View);
	end
	return getn(SimpleMacros_Icons);
end

-- Position in the shown list -> index in SimpleMacros_Icons.
function SimpleMacrosPopup_IconIndex(position)
	if ( SimpleMacrosPopup_View ) then
		return SimpleMacrosPopup_View[position];
	end
	if ( position >= 1 and position <= getn(SimpleMacros_Icons) ) then
		return position;
	end
	return nil;
end

function SimpleMacrosPopup_RowCount()
	return ceil(SimpleMacrosPopup_Count() / SIMPLEMACROS_POPUP_COLUMNS);
end

-- Lower case icon names without underscores, made once.
function SimpleMacrosPopup_BuildKeys()
	SimpleMacrosPopup_Keys = {};
	local i;
	for i = 1, getn(SimpleMacros_Icons) do
		SimpleMacrosPopup_Keys[i] = gsub(strlower(SimpleMacros_Icons[i]), "_", "");
	end
end

-- Called when the search text changes.
function SimpleMacrosPopup_Search(text)
	text = gsub(strlower(text or ""), "[ _]", "");
	if ( text == "" ) then
		SimpleMacrosPopup_View = nil;
	else
		if ( not SimpleMacrosPopup_Keys ) then
			SimpleMacrosPopup_BuildKeys();
		end
		local view = {};
		local i;
		for i = 1, getn(SimpleMacros_Icons) do
			if ( strfind(SimpleMacrosPopup_Keys[i], text, 1, 1) ) then
				tinsert(view, i);
			end
		end
		SimpleMacrosPopup_View = view;
	end
	if ( SimpleMacrosPopupFrame:IsVisible() ) then
		SimpleMacrosPopupScrollScrollBar:SetValue(0);
		SimpleMacrosPopup_Update();
	end
end

-- The icon list is a scroll list: 4 rows of 5 are shown, the rest by scrolling.
function SimpleMacrosPopup_Update()
	local rows = SimpleMacrosPopup_RowCount();
	FauxScrollFrame_Update(SimpleMacrosPopupScroll, rows, SIMPLEMACROS_POPUP_ROWS, SIMPLEMACROS_POPUP_ROW);
	local rowOffset = FauxScrollFrame_GetOffset(SimpleMacrosPopupScroll) or 0;
	local offset = rowOffset * SIMPLEMACROS_POPUP_COLUMNS;
	local i, index, button, icon;
	for i = 1, SIMPLEMACROS_POPUP_ICONS do
		index = SimpleMacrosPopup_IconIndex(offset + i);
		button = getglobal("SimpleMacrosPopupButton"..i);
		icon = getglobal("SimpleMacrosPopupButton"..i.."Icon");
		if ( index and SimpleMacros_Icons[index] ) then
			icon:SetTexture(SimpleMacros_IconPath(SimpleMacros_Icons[index]));
			button:Show();
			if ( index == SimpleMacrosPopup_Icon ) then
				button:SetChecked(1);
			else
				button:SetChecked(nil);
			end
		else
			button:Hide();
		end
	end
	if ( SimpleMacrosPopup_View ) then
		SimpleMacrosPopupPageText:SetText(getn(SimpleMacrosPopup_View).." icons found");
	else
		SimpleMacrosPopupPageText:SetText("Scroll for more icons ("..getn(SimpleMacros_Icons)..")");
	end
	SimpleMacrosPopupSelectedIcon:SetTexture(SimpleMacros_IconPath(SimpleMacros_Icons[SimpleMacrosPopup_Icon]));
	if ( SimpleMacrosPopup_Icon == 1 ) then
		SimpleMacrosPopupIconHint:SetText("Automatic: icon of the first /cast");
	else
		SimpleMacrosPopupIconHint:SetText(SimpleMacros_Icons[SimpleMacrosPopup_Icon]);
	end
end

function SimpleMacrosPopupButton_OnClick()
	local rowOffset = FauxScrollFrame_GetOffset(SimpleMacrosPopupScroll) or 0;
	local index = SimpleMacrosPopup_IconIndex(rowOffset * SIMPLEMACROS_POPUP_COLUMNS + this:GetID());
	if ( index ) then
		SimpleMacrosPopup_Icon = index;
	end
	SimpleMacrosPopup_Update();
end

-- Scrolls the list so the chosen icon is in view.
function SimpleMacrosPopup_ScrollToIcon()
	local position = SimpleMacrosPopup_Icon;
	if ( SimpleMacrosPopup_View ) then
		position = 1;
		local i;
		for i = 1, getn(SimpleMacrosPopup_View) do
			if ( SimpleMacrosPopup_View[i] == SimpleMacrosPopup_Icon ) then
				position = i;
				break
			end
		end
	end
	local row = floor((position - 1) / SIMPLEMACROS_POPUP_COLUMNS);
	local last = SimpleMacrosPopup_RowCount() - SIMPLEMACROS_POPUP_ROWS;
	if ( row > last ) then
		row = last;
	end
	if ( row < 0 ) then
		row = 0;
	end
	SimpleMacrosPopupScrollScrollBar:SetValue(row * SIMPLEMACROS_POPUP_ROW);
end

function SimpleMacrosPopup_Okay()
	local name = SimpleMacros_Trim(SimpleMacrosPopupNameEditBox:GetText());
	local icon = SimpleMacros_Icons[SimpleMacrosPopup_Icon] or SIMPLEMACROS_DEFAULT_ICON;
	if ( name == "" ) then
		SimpleMacros_Print("Please enter a name for the macro.");
		return;
	end
	if ( SimpleMacrosPopup_Mode == "new" ) then
		local slot = SimpleMacrosPopup_Slot;
		if ( not slot or SimpleMacros_Macros[SimpleMacrosFrame_Tab][slot] ) then
			slot = SimpleMacros_FirstFreeSlot(SimpleMacrosFrame_Tab);
		end
		if ( not slot ) then
			SimpleMacros_Print("This tab is full ("..SIMPLEMACROS_MAX_MACROS.." macros).");
			return;
		end
		SimpleMacros_SetMacro(SimpleMacrosFrame_Tab, slot, name, icon, "");
		SimpleMacrosFrame_Select(slot);
		SimpleMacrosPopupFrame:Hide();
		SimpleMacrosFrame_Update();
		SimpleMacrosBodyEditBox:SetFocus();
	else
		local macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, SimpleMacrosFrame_Selected);
		if ( macro ) then
			SimpleMacros_SetMacro(SimpleMacrosFrame_Tab, SimpleMacrosFrame_Selected, name, icon, macro.body);
		end
		SimpleMacrosPopupFrame:Hide();
		SimpleMacrosFrame_Update();
	end
end




--------------------------------------------------------------------------------
-- Export and import: one macro as one line of text ("SM1^name^icon^body", new
-- lines in the body written as <<NL>>). A single line EditBox is used, as the
-- multi line ones are not safe for copying in this client.
--------------------------------------------------------------------------------

SIMPLEMACROS_SHARE_TAG = "SM1";
SIMPLEMACROS_SHARE_NL = "<<NL>>";

function SimpleMacros_ExportText(macro)
	local name = gsub(macro.name or "", "%^", "?");
	local body = macro.body or "";
	local icon = SimpleMacros_IconName(macro.icon);
	-- SM2: a new line is one ` (shorter). SM1 when the text already has a `.
	if ( not strfind(body, "`", 1, 1) ) then
		return "SM2^"..name.."^"..icon.."^"..gsub(body, "\n", "`");
	end
	return SIMPLEMACROS_SHARE_TAG.."^"..name.."^"..icon.."^"..gsub(body, "\n", SIMPLEMACROS_SHARE_NL);
end

-- Returns name, icon, body, or nil when the text is not an exported macro.
function SimpleMacros_ParseExport(text)
	text = SimpleMacros_Trim(text or "");
	local s, e, tag, name, icon, body = strfind(text, "^(SM[12])%^([^%^]*)%^([^%^]*)%^(.*)$");
	if ( not s ) then
		return nil;
	end
	if ( tag == "SM2" ) then
		body = gsub(body, "`", "\n");
	else
		body = gsub(body, "<<NL>>", "\n");
	end
	return name, icon, body;
end

function SimpleMacrosShare_Show()
	SimpleMacrosFrame_SaveBody();
	SimpleMacrosPopupFrame:Hide();
	SimpleMacrosHelpFrame:Hide();
	SimpleMacrosShareFrame:Show();
	SimpleMacrosShare_Export();
end

function SimpleMacrosShare_Toggle()
	if ( SimpleMacrosShareFrame:IsVisible() ) then
		SimpleMacrosShareFrame:Hide();
	else
		SimpleMacrosShare_Show();
	end
end

-- Puts the selected macro into the box.
function SimpleMacrosShare_Export()
	local macro = nil;
	if ( SimpleMacrosFrame_Selected ) then
		macro = SimpleMacros_GetMacro(SimpleMacrosFrame_Tab, SimpleMacrosFrame_Selected);
	end
	if ( not macro ) then
		SimpleMacrosShareBox:SetText("");
		SimpleMacrosShareStatus:SetText("Select a macro first to export it.");
		return;
	end
	SimpleMacrosShareBox:SetText(SimpleMacros_ExportText(macro));
	SimpleMacrosShareBox:SetFocus();
	SimpleMacrosShareStatus:SetText("Exported: "..macro.name..". Click the box, then Ctrl+A and Ctrl+C.");
end

-- Adds the macro in the box to the first free square of the current tab.
function SimpleMacrosShare_Import()
	local name, icon, body = SimpleMacros_ParseExport(SimpleMacrosShareBox:GetText());
	if ( not name ) then
		SimpleMacrosShareStatus:SetText("|cffff4040That is not an exported macro.|r Paste a line that starts with SM.");
		return;
	end
	local slot = SimpleMacros_FirstFreeSlot(SimpleMacrosFrame_Tab);
	if ( not slot ) then
		SimpleMacrosShareStatus:SetText("|cffff4040This tab is full ("..SIMPLEMACROS_MAX_MACROS.." macros).|r Delete one or use the other tab.");
		return;
	end
	SimpleMacros_SetMacro(SimpleMacrosFrame_Tab, slot, name, icon, body);
	SimpleMacrosFrame_Select(slot);
	SimpleMacrosFrame_Update();
	SimpleMacrosShareBox:SetText("");
	SimpleMacrosShareStatus:SetText("Imported: "..name..".");
end
