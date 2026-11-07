--------------------------------------------------------------------------------
-- ImprovedErrorFrame for WoW 0.5.3
-- Collects Lua errors in one window instead of the stock popup:
-- every unique error is kept once with a repeat count, you can page through
-- them, show them all as text, and clear them.
--
-- Lua 5.0 rules for this client: no string methods, no # or % operators,
-- no pairs/ipairs/type/pcall, ASCII only.
--------------------------------------------------------------------------------

-- Installed on its own and inside SimpleQoL: 0.5.3 keeps the frames of the
-- copy loaded first under their names, so no frame is hidden here (that hid
-- the frames in use). The newest version runs: a copy loaded after an equal
-- or newer version stops here, and the other copy's frames stop themselves.
local function IEF_VersionValue(v)
	local s, e, major, minor = strfind(v or "", "^(%d+)%.?(%d*)");
	if ( not major ) then
		return 0;
	end
	return major * 1000 + (tonumber(minor) or 0);
end
if ( IEF_VERSION and IEF_VersionValue(IEF_VERSION) >= IEF_VersionValue("1.16") ) then
	return;
end
IEF_VERSION = "1.17";
IEF_MAX_ERRORS = 100;            -- unique errors kept per session

IEF_Errors = IEF_Errors or {};                 -- { text, count, time, file, line, msg }
IEF_Current = 0;                 -- index shown in the window
IEF_ShowAll = nil;               -- 1 = window shows all errors as one text
IEF_AutoOpen = nil;              -- 1 = open the window on a new error (off: errors only go to the icon and chat)
IEF_Dropped = 0;                 -- errors not stored because the list was full
IEF_Dirty = nil;                 -- 1 = window/button must be refreshed
IEF_OpenRequest = nil;           -- 1 = open the window on the next frame
IEF_UpdateTime = nil;            -- GetTime() of the refresh in progress
IEF_TestPending = nil;           -- 1 = raise the test error on the next frame
IEF_IconEnabled = 1;             -- 1 = show the error icon when there are errors
IEF_IconDragging = nil;          -- 1 = the icon follows the cursor
IEF_IconMoved = nil;             -- 1 = the last mouse press was a move, not a click
IEF_IconOffsetX = 0;             -- cursor offset from the icon center while moving
IEF_IconOffsetY = 0;

-- The real stock popup, kept for message() and as a last fallback.
IEF_RealScriptErrors = IEF_RealScriptErrors or ScriptErrors;
IEF_RealScriptErrorsMessage = IEF_RealScriptErrorsMessage or ScriptErrors_Message;


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function IEF_Print(text, r, g, b)
	if ( ChatFrame ) then
		ChatFrame:AddMessage(text, r or 1.0, g or 0.3, b or 0.3);
	end
end

function IEF_TimeText()
	if ( GetGameTime ) then
		local hour, minute = GetGameTime();
		if ( hour and minute ) then
			return format("%02d:%02d", hour, minute);
		end
	end
	return "--:--";
end

-- Splits "Interface\FrameXML\File.lua:41: message" or
-- "[string \"...\"]:3: message" into file, line, message.
function IEF_Split(text)
	local _, _, file, line, msg = strfind(text, "^%[string \"(.-)\"%]:(%d+):%s*(.*)$");
	if ( file ) then
		return "[string] "..file, line, msg;
	end
	_, _, file, line, msg = strfind(text, "^(.-):(%d+):%s*(.*)$");
	if ( file and file ~= "" ) then
		return file, line, msg;
	end
	return nil, nil, text;
end

function IEF_Find(text)
	local i;
	for i = 1, getn(IEF_Errors) do
		if ( IEF_Errors[i].text == text ) then
			return i;
		end
	end
	return nil;
end

function IEF_ErrorAsText(index)
	local e = IEF_Errors[index];
	if ( not e ) then
		return "";
	end
	local text = "Error "..index.." (x"..e.count..", "..e.time..")\n";
	if ( e.file ) then
		text = text.."File: "..e.file.."\nLine: "..e.line.."\n";
	end
	return text..e.msg;
end


--------------------------------------------------------------------------------
-- Error capture.
-- In 0.5.3 the client may call either our _ERRORMESSAGE or the stock one it
-- saw at startup. The stock one shows ScriptErrors / ScriptErrors_Message, so
-- those two globals are replaced by stand-ins that record the error instead.
-- Either way every error ends in IEF_Record. IEF_Record only stores data;
-- all window work happens one frame later in IEF_OnUpdate, so an error in the
-- window code can never block the capture.
--------------------------------------------------------------------------------

function IEF_Record(text)
	if ( not text ) then
		return;
	end
	text = text.."";

	local index = IEF_Find(text);
	if ( index ) then
		IEF_Errors[index].count = IEF_Errors[index].count + 1;
		IEF_Errors[index].time = IEF_TimeText();
	elseif ( getn(IEF_Errors) < IEF_MAX_ERRORS ) then
		local file, line, msg = IEF_Split(text);
		tinsert(IEF_Errors, { text = text, count = 1, time = IEF_TimeText(), file = file, line = line, msg = msg });
		index = getn(IEF_Errors);
		IEF_Print("Lua error "..index..": "..text);
		if ( IEF_AutoOpen ) then
			IEF_OpenRequest = index;
		end
	else
		IEF_Dropped = IEF_Dropped + 1;
	end

	-- An error raised by our own refresh must not start a new refresh,
	-- otherwise a broken window would loop every frame.
	if ( not ( IEF_UpdateTime and GetTime and IEF_UpdateTime == GetTime() ) ) then
		IEF_Dirty = 1;
	end
end

function _ERRORMESSAGE(text)
	if ( debuginfo ) then
		debuginfo();
	end
	IEF_Record(text);
end

-- Stand-ins for the stock popup frame and its text.
IEF_FakeErrorText = {};
function IEF_FakeErrorText.SetText(self, text)
	IEF_Record(text);
end
function IEF_FakeErrorText.GetText(self)
	return "";
end

IEF_FakeErrorFrame = {};
function IEF_FakeErrorFrame.IsVisible(self)
	return nil;
end
function IEF_FakeErrorFrame.Show(self)
end
function IEF_FakeErrorFrame.Hide(self)
end

ScriptErrors = IEF_FakeErrorFrame;
ScriptErrors_Message = IEF_FakeErrorText;

-- message() is used by addons for plain popups, so it keeps the real dialog.
function message(text)
	if ( IEF_RealScriptErrors and IEF_RealScriptErrorsMessage and not IEF_RealScriptErrors:IsVisible() ) then
		IEF_RealScriptErrorsMessage:SetText(text);
		IEF_RealScriptErrors:Show();
	end
end

-- Runs every frame (IEFEventFrame in the XML).
-- The event frame of an earlier copy (loaded twice) stops itself.
function IEF_IsOldFrame()
	if ( this == IEFEventFrame or not this or not this.GetName or this:GetName() ~= "IEFEventFrame" ) then
		return nil;
	end
	this:UnregisterEvent("PLAYER_ENTERING_WORLD");
	this:Hide();
	return 1;
end

function IEF_OnUpdate()
	if ( IEF_IsOldFrame() ) then
		return;
	end
	if ( SimpleHello_Tick ) then
		SimpleHello_Tick();
	end
	if ( IEF_Off ) then
		return;
	end
	if ( IEF_IconDragging ) then
		IEF_Icon_DragUpdate();
	end
	if ( IEF_TestPending ) then
		IEF_TestPending = nil;
		IEF_MakeTestError();
	end
	if ( not IEF_Dirty and not IEF_OpenRequest ) then
		return;
	end
	if ( GetTime ) then
		IEF_UpdateTime = GetTime();
	end
	IEF_Dirty = nil;
	if ( IEF_OpenRequest ) then
		local index = IEF_OpenRequest;
		IEF_OpenRequest = nil;
		if ( not ImprovedErrorFrame:IsVisible() ) then
			IEF_Current = index;
			IEF_ShowAll = nil;
			-- OnShow marks the window dirty; it is filled on the next frame.
			ImprovedErrorFrame:Show();
			IEF_UpdateTime = nil;
			return;
		end
	end
	IEF_UpdateButton();
	if ( ImprovedErrorFrame:IsVisible() ) then
		IEF_Update();
	end
	IEF_UpdateTime = nil;
end

function IEF_OnLoad()
	tinsert(UISpecialFrames, "ImprovedErrorFrame");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
end

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

-- Tooltip placement, shared by all our 0.5.3 addons: the tooltip opens on the
-- side of its owner that faces the middle of the screen, so it never ends up
-- outside the screen. Whichever addon loads first installs it, only once.
-- Version 2 adds line wrapping; a newer copy replaces an older one.
if ( not SIMPLE_TOOLTIP_DONE or SIMPLE_TOOLTIP_DONE < 2 ) then
	SIMPLE_TOOLTIP_DONE = 2;
	function SimpleTooltip_SetOwner(owner, tooltip)
		if ( not tooltip ) then
			tooltip = GameTooltip;
		end
		local x, y = owner:GetCenter();
		local sx, sy = UIParent:GetCenter();
		-- SetPoint in 0.5.3 needs the frame's name, not the frame itself.
		local ownerName = owner.GetName and owner:GetName();
		if ( not x or not sx or not ownerName ) then
			tooltip:SetOwner(owner, "ANCHOR_RIGHT");
			return;
		end
		tooltip:SetOwner(owner, "ANCHOR_NONE");
		local v = "BOTTOM";
		local ov = "TOP";
		if ( y > sy ) then
			v = "TOP";
			ov = "BOTTOM";
		end
		local h = "LEFT";
		local oh = "RIGHT";
		if ( x > sx ) then
			h = "RIGHT";
			oh = "LEFT";
		end
		tooltip:ClearAllPoints();
		tooltip:SetPoint(v..h, ownerName, ov..oh, 0, 0);
	end
	-- Stock action buttons (all bars) use the same placement.
	if ( ActionButton_SetTooltip ) then
		ActionButton_SetTooltip = function()
			SimpleTooltip_SetOwner(this);
			if ( GameTooltip:SetAction(ActionButton_GetPagedID(this)) ) then
				this.updateTooltip = TOOLTIP_UPDATE_TIME;
			else
				this.updateTooltip = nil;
			end
		end;
	end
	-- Long tooltip lines are split at spaces into lines of about 45 visible
	-- characters, so no tooltip gets wider than the screen. Color codes are
	-- carried over to the next line.
	SIMPLE_TOOLTIP_WIDTH = 45;
	function SimpleTooltip_VisibleLen(text)
		local visible = gsub(text, "|c%x%x%x%x%x%x%x%x", "");
		visible = gsub(visible, "|r", "");
		return strlen(visible);
	end
	function SimpleTooltip_Wrap(text, width)
		local lines = {};
		if ( not width ) then
			width = SIMPLE_TOOLTIP_WIDTH;
		end
		if ( SimpleTooltip_VisibleLen(text) <= width ) then
			tinsert(lines, text);
			return lines;
		end
		local line = "";
		local lineLen = 0;
		local color = nil;
		local pos = 1;
		while ( 1 ) do
			local s, e, word = strfind(text, "(%S+)", pos);
			if ( not s ) then
				break
			end
			pos = e + 1;
			local len = SimpleTooltip_VisibleLen(word);
			if ( lineLen > 0 and lineLen + 1 + len > width ) then
				if ( color ) then
					line = line.."|r";
				end
				tinsert(lines, line);
				line = color or "";
				lineLen = 0;
			end
			if ( lineLen > 0 ) then
				line = line.." ";
				lineLen = lineLen + 1;
			end
			line = line..word;
			lineLen = lineLen + len;
			-- The color in effect after this word.
			local p = 1;
			while ( 1 ) do
				local cs, ce = strfind(word, "|c%x%x%x%x%x%x%x%x", p);
				local rs, re = strfind(word, "|r", p, 1);
				if ( not cs and not rs ) then
					break
				end
				if ( cs and (not rs or cs < rs) ) then
					color = strsub(word, cs, ce);
					p = ce + 1;
				else
					color = nil;
					p = re + 1;
				end
			end
		end
		if ( line ~= "" ) then
			tinsert(lines, line);
		end
		return lines;
	end
	if ( GameTooltip and not SIMPLE_TOOLTIP_WRAP ) then
		SIMPLE_TOOLTIP_WRAP = 1;
		SimpleTooltip_OrigAddLine = GameTooltip.AddLine;
		SimpleTooltip_OrigSetText = GameTooltip.SetText;
		GameTooltip.AddLine = function(self, text, a, r, g, b)
			if ( not text or text == "" ) then
				SimpleTooltip_OrigAddLine(self, text, a, r, g, b);
				return;
			end
			local lines = SimpleTooltip_Wrap(text);
			local i;
			for i = 1, getn(lines) do
				local right = "";
				if ( i == 1 and a ) then
					right = a;
				end
				SimpleTooltip_OrigAddLine(self, lines[i], right, r, g, b);
			end
		end;
		GameTooltip.SetText = function(self, text, r, g, b, a)
			if ( not text or text == "" ) then
				SimpleTooltip_OrigSetText(self, text, r, g, b, a);
				return;
			end
			local lines = SimpleTooltip_Wrap(text);
			SimpleTooltip_OrigSetText(self, lines[1], r, g, b, a);
			local i;
			for i = 2, getn(lines) do
				SimpleTooltip_OrigAddLine(self, lines[i], "", r or 1.0, g or 1.0, b or 1.0);
			end
		end;
	end
end


--------------------------------------------------------------------------------
-- Saving with SimpleSave (addon "IEF"): Auto, icon on/off, icon place.
--------------------------------------------------------------------------------

function IEF_OnEvent(event)
	if ( IEF_IsOldFrame() ) then
		return;
	end
	if ( event == "PLAYER_ENTERING_WORLD" and not IEF_Started ) then
		IEF_Started = 1;
		if ( SimpleSave_RegisterLoad ) then
			SimpleSave_RegisterLoad(IEF_LoadSettings);
		else
			if ( not SIMPLE_SAVE_WARNED ) then
				SIMPLE_SAVE_WARNED = 1;
				IEF_Print("|cffff4040Dependency missing: SimpleSave.|r ImprovedErrorFrame settings are not saved between sessions.", 1.0, 0.82, 0.0);
			end
		end
	end
end

-- SimpleQoL can turn this addon off (/qol, Modules). Only while SimpleQoL is
-- installed, so a lone ImprovedErrorFrame can never stay off by an old setting.
function IEF_ModuleOff()
	return SIMPLEQOL_VERSION and SimpleSave_Get and SimpleSave_Get("SimpleQoL", "errorframe") == "0";
end

-- Off: the game's own error window is used again.
function IEF_TurnOff()
	IEF_Off = 1;
	ScriptErrors = IEF_RealScriptErrors;
	ScriptErrors_Message = IEF_RealScriptErrorsMessage;
	IEF_IconEnabled = nil;
	IEF_UpdateButton();
	ImprovedErrorFrame:Hide();
end

function IEF_LoadSettings()
	if ( IEF_ModuleOff() ) then
		IEF_TurnOff();
		return;
	end
	IEF_SettingsLoaded = 1;
	-- "AutoOpen" replaces the old "Auto" key, so the window no longer pops up
	-- for users who had the old default saved.
	local auto = SimpleSave_Get("IEF", "AutoOpen");
	if ( auto == "0" ) then
		IEF_AutoOpen = nil;
	elseif ( auto == "1" ) then
		IEF_AutoOpen = 1;
	end
	local icon = SimpleSave_Get("IEF", "Icon");
	if ( icon == "0" ) then
		IEF_IconEnabled = nil;
	elseif ( icon == "1" ) then
		IEF_IconEnabled = 1;
	end
	local x = SimpleSave_GetNumber("IEF", "IconX");
	local y = SimpleSave_GetNumber("IEF", "IconY");
	if ( x and y ) then
		ImprovedErrorButton:ClearAllPoints();
		ImprovedErrorButton:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", x, y);
	end
	IEF_Dirty = 1;
end

function IEF_SaveSettings()
	if ( not SimpleSave_Set or not IEF_SettingsLoaded ) then
		return;
	end
	if ( IEF_AutoOpen ) then
		SimpleSave_Set("IEF", "AutoOpen", "1");
	else
		SimpleSave_Set("IEF", "AutoOpen", "0");
	end
	if ( IEF_IconEnabled ) then
		SimpleSave_Set("IEF", "Icon", "1");
	else
		SimpleSave_Set("IEF", "Icon", "0");
	end
	if ( IEF_IconX ) then
		SimpleSave_Set("IEF", "IconX", floor(IEF_IconX + 0.5));
		SimpleSave_Set("IEF", "IconY", floor(IEF_IconY + 0.5));
	end
end


--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------

function IEF_Update()
	local total = getn(IEF_Errors);
	if ( SimpleSave_Set ) then
		ImprovedErrorFrameDependency:SetText("");
	else
		ImprovedErrorFrameDependency:SetText("|cffff4040Dependency missing: SimpleSave|r (settings not saved)");
	end
	if ( IEF_Current > total ) then
		IEF_Current = total;
	end
	if ( IEF_Current < 1 and total > 0 ) then
		IEF_Current = 1;
	end

	local text = "";
	if ( total == 0 ) then
		ImprovedErrorFrameInfo:SetText("No errors");
		ImprovedErrorFrameWhere:SetText("");
	elseif ( IEF_ShowAll ) then
		local i;
		for i = 1, total do
			if ( i > 1 ) then
				text = text.."\n\n";
			end
			text = text..IEF_ErrorAsText(i);
		end
		if ( IEF_Dropped > 0 ) then
			text = text.."\n\n("..IEF_Dropped.." more errors were not stored)";
		end
		ImprovedErrorFrameInfo:SetText("All errors ("..total..")");
		ImprovedErrorFrameWhere:SetText("");
	else
		local e = IEF_Errors[IEF_Current];
		ImprovedErrorFrameInfo:SetText("Error "..IEF_Current.." of "..total.."     Count: "..e.count.."     Last: "..e.time);
		if ( e.file ) then
			ImprovedErrorFrameWhere:SetText("|cffffd100File:|r "..e.file.."   |cffffd100Line:|r "..e.line);
		else
			ImprovedErrorFrameWhere:SetText("");
		end
		text = e.msg;
	end
	-- Plain FontString, not an EditBox: a multi-line EditBox crashed the
	-- 0.5.3 client (CSimpleEditBox.cpp, stringWidth > 0).
	ImprovedErrorFrameText:SetText(text);
	ImprovedErrorFrameScrollFrame:UpdateScrollChildRect();

	if ( IEF_ShowAll or IEF_Current <= 1 ) then
		ImprovedErrorFramePrevButton:Disable();
	else
		ImprovedErrorFramePrevButton:Enable();
	end
	if ( IEF_ShowAll or IEF_Current >= total ) then
		ImprovedErrorFrameNextButton:Disable();
	else
		ImprovedErrorFrameNextButton:Enable();
	end
	if ( IEF_ShowAll ) then
		ImprovedErrorFrameAllButton:SetText("One");
	else
		ImprovedErrorFrameAllButton:SetText("All");
	end
	if ( IEF_AutoOpen ) then
		ImprovedErrorFrameAutoButton:SetText("Auto: On");
	else
		ImprovedErrorFrameAutoButton:SetText("Auto: Off");
	end
end

-- The window is filled one frame after it is shown, when its layout exists.
function IEF_OnShow()
	IEF_Dirty = 1;
end

function IEF_Prev()
	IEF_Current = IEF_Current - 1;
	IEF_Update();
end

function IEF_Next()
	IEF_Current = IEF_Current + 1;
	IEF_Update();
end

function IEF_ToggleAll()
	if ( IEF_ShowAll ) then
		IEF_ShowAll = nil;
	else
		IEF_ShowAll = 1;
	end
	IEF_Update();
end

function IEF_ToggleAuto()
	if ( IEF_AutoOpen ) then
		IEF_AutoOpen = nil;
	else
		IEF_AutoOpen = 1;
	end
	IEF_SaveSettings();
	IEF_Update();
end

function IEF_Clear()
	IEF_CopyBox_Clear();
	IEF_Errors = {};
	IEF_Current = 0;
	IEF_Dropped = 0;
	IEF_ShowAll = nil;
	IEF_UpdateButton();
	IEF_Update();
end

function IEF_Toggle()
	if ( ImprovedErrorFrame:IsVisible() ) then
		ImprovedErrorFrame:Hide();
	else
		if ( IEF_Current < 1 ) then
			IEF_Current = getn(IEF_Errors);
		end
		ImprovedErrorFrame:Show();
	end
end


--------------------------------------------------------------------------------
-- Copy box: a single-line EditBox (single-line boxes are safe in 0.5.3, the
-- chat box is one). Select the text in it and press Ctrl+C.
--------------------------------------------------------------------------------

function IEF_CopyText()
	local text = "";
	if ( IEF_ShowAll ) then
		local i;
		for i = 1, getn(IEF_Errors) do
			if ( i > 1 ) then
				text = text.." || ";
			end
			text = text..IEF_Errors[i].text.." (x"..IEF_Errors[i].count..")";
		end
	elseif ( IEF_Errors[IEF_Current] ) then
		text = IEF_Errors[IEF_Current].text;
	end
	-- One line only: newlines and tabs become spaces.
	text = gsub(text, "[\r\n\t]+", " ");
	return text;
end

function IEF_Copy()
	if ( getn(IEF_Errors) == 0 ) then
		return;
	end
	ImprovedErrorFrameCopyBox:SetText(IEF_CopyText());
	ImprovedErrorFrameCopyBox:SetFocus();
	ImprovedErrorFrameCopyHint:SetText("Select the text (Ctrl+A or mouse), then Ctrl+C");
end

function IEF_CopyBox_Clear()
	ImprovedErrorFrameCopyBox:SetText("");
	ImprovedErrorFrameCopyBox:ClearFocus();
	ImprovedErrorFrameCopyHint:SetText("Click the error text or Copy to put it here");
end


--------------------------------------------------------------------------------
-- Error icon: a small icon with the error count, shown when there are errors
-- and the window is closed. Click opens the window, Shift+drag moves it,
-- /errors icon hides it.
--------------------------------------------------------------------------------

function IEF_UpdateButton()
	local total = getn(IEF_Errors);
	if ( IEF_IconEnabled and total > 0 and not ImprovedErrorFrame:IsVisible() ) then
		ImprovedErrorButtonCount:SetText(total);
		ImprovedErrorButton:Show();
	else
		IEF_IconDragging = nil;
		ImprovedErrorButton:Hide();
	end
end

function IEF_Icon_OnMouseDown(mouseButton)
	IEF_IconMoved = nil;
	if ( mouseButton == "LeftButton" and IsShiftKeyDown() ) then
		local x, y = GetCursorPosition();
		local cx, cy = ImprovedErrorButton:GetCenter();
		IEF_IconOffsetX = x - cx;
		IEF_IconOffsetY = y - cy;
		IEF_IconDragging = 1;
		IEF_IconMoved = 1;
	end
end

function IEF_Icon_OnMouseUp()
	if ( IEF_IconDragging ) then
		IEF_IconDragging = nil;
		IEF_SaveSettings();
	end
end

function IEF_Icon_DragUpdate()
	local x, y = GetCursorPosition();
	ImprovedErrorButton:ClearAllPoints();
	IEF_IconX = x - IEF_IconOffsetX;
	IEF_IconY = y - IEF_IconOffsetY;
	ImprovedErrorButton:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", IEF_IconX, IEF_IconY);
end

function IEF_Icon_OnClick()
	if ( IEF_IconMoved ) then
		IEF_IconMoved = nil;
		return;
	end
	IEF_Toggle();
end

function IEF_Icon_OnEnter()
	SimpleTooltip_SetOwner(this);
	GameTooltip:SetText("Lua errors: "..getn(IEF_Errors));
	GameTooltip:AddLine("|cffffffffClick: open the error window|r");
	GameTooltip:AddLine("|cffffffffShift+drag: move|r");
	GameTooltip:AddLine("|cffffffff/errors icon: hide this icon|r");
	GameTooltip:Show();
end

function IEF_Icon_OnLeave()
	GameTooltip:Hide();
end


--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

SLASH_IMPROVEDERRORS1 = "/errors";
SLASH_IMPROVEDERRORS2 = "/ief";
SlashCmdList["IMPROVEDERRORS"] = function(msg)
	local simpleVersionAsk = strlower(gsub(msg or "", "%s", ""));
	if ( simpleVersionAsk == "v" or simpleVersionAsk == "version" ) then
		ChatFrame:AddMessage("ImprovedErrorFrame "..IEF_VERSION, 1.0, 0.82, 0.0);
		return;
	end
	if ( IEF_Off ) then
		IEF_Print("ImprovedErrorFrame is turned off in /qol (Modules). Turn it on there and log in again.", 1.0, 0.82, 0.0);
		return;
	end
	msg = strlower(msg or "");
	msg = gsub(msg, "^%s+", "");
	msg = gsub(msg, "%s+$", "");
	if ( msg == "clear" ) then
		IEF_Clear();
		IEF_Print("Errors cleared.", 1.0, 0.82, 0.0);
	elseif ( msg == "auto" ) then
		IEF_ToggleAuto();
		if ( IEF_AutoOpen ) then
			IEF_Print("The error window opens on new errors.", 1.0, 0.82, 0.0);
		else
			IEF_Print("The error window no longer opens by itself.", 1.0, 0.82, 0.0);
		end
	elseif ( msg == "icon" ) then
		if ( IEF_IconEnabled ) then
			IEF_IconEnabled = nil;
			IEF_Print("Error icon hidden. New errors still show a chat line.", 1.0, 0.82, 0.0);
		else
			IEF_IconEnabled = 1;
			IEF_Print("Error icon shown.", 1.0, 0.82, 0.0);
		end
		IEF_SaveSettings();
		IEF_UpdateButton();
	elseif ( msg == "test" ) then
		-- Raised on the next frame, outside the chat box code.
		IEF_Print("Making a test error...", 1.0, 0.82, 0.0);
		IEF_TestPending = 1;
	elseif ( msg == "help" ) then
		IEF_Print("/errors - open or close the error window", 1.0, 0.82, 0.0);
		IEF_Print("/errors clear - remove all errors", 1.0, 0.82, 0.0);
		IEF_Print("/errors auto - open the window on new errors on/off", 1.0, 0.82, 0.0);
		IEF_Print("/errors icon - show or hide the error icon", 1.0, 0.82, 0.0);
		IEF_Print("/errors test - make a test error", 1.0, 0.82, 0.0);
	else
		IEF_Toggle();
	end
end

function IEF_MakeTestError()
	local nothing = nil;
	nothing.field = 1;
end
