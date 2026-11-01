-- TradeSkillPlus v23 for WoW 0.5.3
--
-- Create sends the amount to the client with DoTradeSkill(recipe, count), like in 1.12.1.
-- If the client does not repeat the craft by itself, the addon starts each craft.
-- If the client rejects an attempt (e.g. "Another action is in progress"), the addon
-- retries until it goes through, as long as there are reagents left.
-- Every finished craft is counted via SPELLCAST_STOP.

-- Installed on its own and inside SimpleQoL: 0.5.3 keeps the frames of the
-- copy loaded first under their names, so no frame is hidden here (that hid
-- the frames in use). The newest version runs: a copy loaded after an equal
-- or newer version stops here, and the other copy's frames stop themselves.
local function TradeSkillPlus_VersionValue(v)
	local s, e, major, minor = strfind(v or "", "^(%d+)%.?(%d*)");
	if ( not major ) then
		return 0;
	end
	return major * 1000 + (tonumber(minor) or 0);
end
if ( TRADESKILLPLUS_VERSION and TradeSkillPlus_VersionValue(TRADESKILLPLUS_VERSION) >= TradeSkillPlus_VersionValue("25") ) then
	return;
end
TRADESKILLPLUS_VERSION = "25";
TRADESKILLPLUS_DEBUG = 0;            -- 1 = print what the queue is doing to chat (for debugging)

TRADESKILLPLUS_MAX_AMOUNT = 99;      -- highest amount selectable in the box
TRADESKILLPLUS_DETECT_TIME = 0.4;    -- wait after the first craft: does the client repeat by itself?
TRADESKILLPLUS_NATIVE_WAIT = 1.5;    -- wait for the client's own repeat, once we know it does that
TRADESKILLPLUS_ATTEMPT_WAIT = 0.6;   -- wait for an attempt to start a cast
TRADESKILLPLUS_RETRY_TIME = 0.2;     -- pause before retrying after a rejection
TRADESKILLPLUS_MAX_ATTEMPTS = 25;    -- attempts in a row before giving up (about 5-10 s)
TRADESKILLPLUS_CAST_TIMEOUT = 20;    -- max cast length before giving up

TradeSkillPlus_Amount = 1;      -- amount selected in the box
TradeSkillPlus_Queue = 0;       -- crafts remaining
TradeSkillPlus_Active = 0;      -- 1 = a queue is running
TradeSkillPlus_State = 0;       -- 0 idle, 1 attempt sent, 2 casting, 3 waiting before next
TradeSkillPlus_Timer = 0;
TradeSkillPlus_Attempts = 0;    -- attempts in a row without a cast starting
TradeSkillPlus_Native = -1;     -- -1 unknown, 1 client repeats by itself, 0 addon starts each craft
TradeSkillPlus_LastSkill = 0;
TradeSkillPlus_Typing = 0;      -- 1 = the player is typing in the amount box
TradeSkillPlus_SettingText = 0; -- 1 = the addon itself is changing the box text
TradeSkillPlus_OldAmount = 1;   -- amount before typing started (restored on Escape)

-- Selecting a recipe fires no event in 0.5.3, so the buttons were left in the
-- state of the previous recipe (Create greyed out until + or - was pressed).
-- Refresh them whenever the stock code changes the selection.
-- Which copy runs: each loaded copy sets TradeSkillPlus_Copy to its own
-- table; the hook of an earlier copy then only passes the call on.
local TradeSkillPlus_ThisCopy = {};
TradeSkillPlus_Copy = TradeSkillPlus_ThisCopy;

TradeSkillPlus_OrigSetSelection = TradeSkillPlus_OrigSetSelection or TradeSkillFrame_SetSelection;
local TradeSkillPlus_StockSetSelection = TradeSkillPlus_OrigSetSelection;
function TradeSkillFrame_SetSelection(id)
	TradeSkillPlus_StockSetSelection(id);
	if (TradeSkillPlus_Off or TradeSkillPlus_Copy ~= TradeSkillPlus_ThisCopy) then
		return;
	end
	if (TradeSkillPlus_Active == 0 and TradeSkillFrame.selectedSkill ~= TradeSkillPlus_LastSkill) then
		TradeSkillPlus_LastSkill = TradeSkillFrame.selectedSkill;
		TradeSkillPlus_Amount = 1;
	end
	TradeSkillPlus_Update();
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


function TradeSkillPlus_Debug(text)
	if (TRADESKILLPLUS_DEBUG == 1) then
		local frame = DEFAULT_CHAT_FRAME or ChatFrame;
		if (frame) then
			frame:AddMessage("TSP: " .. text, 1.0, 1.0, 0.0);
		end
	end
end


-- SimpleQoL can turn this addon off (/qol, Modules). Only while SimpleQoL is
-- installed, so a lone TradeSkillPlus can never stay off by an old setting.
function TradeSkillPlus_ModuleOff()
	return SIMPLEQOL_VERSION and SimpleSave_Get and SimpleSave_Get("SimpleQoL", "tradeskillplus") == "0";
end

-- Off: our buttons are hidden and the game's Create button is back.
function TradeSkillPlus_CheckOff()
	if (not TradeSkillPlus_ModuleOff()) then
		return;
	end
	TradeSkillPlus_Off = 1;
	local names = { "TradeSkillPlusRowBackground", "TradeSkillPlusJoints", "TradeSkillPlusCreateAllButton", "TradeSkillPlusMinusButton",
		"TradeSkillPlusAmountBox", "TradeSkillPlusPlusButton", "TradeSkillPlusCreateButton" };
	local i;
	for i = 1, getn(names) do
		local frame = getglobal(names[i]);
		if (frame) then
			frame:Hide();
		end
	end
	TradeSkillCancelButton:SetWidth(80);
	TradeSkillCreateButton:Show();
end

function TradeSkillPlus_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("TRADE_SKILL_SHOW");
	this:RegisterEvent("TRADE_SKILL_UPDATE");
	this:RegisterEvent("TRADE_SKILL_CLOSE");
	this:RegisterEvent("SPELLCAST_START");
	this:RegisterEvent("SPELLCAST_STOP");
	this:RegisterEvent("SPELLCAST_FAILED");
	this:RegisterEvent("SPELLCAST_INTERRUPTED");
	this:RegisterEvent("UI_ERROR_MESSAGE");
end


function TradeSkillPlus_StopQueue(reason)
	if (TradeSkillPlus_Active == 1 and reason) then
		TradeSkillPlus_Debug("stop: " .. reason);
	end
	TradeSkillPlus_Queue = 0;
	TradeSkillPlus_Active = 0;
	TradeSkillPlus_State = 0;
	TradeSkillPlus_Timer = 0;
	TradeSkillPlus_Attempts = 0;
	TradeSkillPlus_Update();
end


-- An attempt did not go through: wait a moment and retry
function TradeSkillPlus_AttemptFailed(why)
	if (TradeSkillPlus_Attempts >= TRADESKILLPLUS_MAX_ATTEMPTS) then
		TradeSkillPlus_StopQueue("too many failed attempts (" .. why .. ")");
		return;
	end
	TradeSkillPlus_Debug("retry (" .. why .. ")");
	TradeSkillPlus_State = 3;
	TradeSkillPlus_Timer = TRADESKILLPLUS_RETRY_TIME;
end


-- The event frame of an earlier copy (loaded twice) stops itself.
function TradeSkillPlus_IsOldFrame()
	if ( this == TradeSkillPlusFrame or not this or not this.GetName or this:GetName() ~= "TradeSkillPlusFrame" ) then
		return nil;
	end
	local events = { "PLAYER_ENTERING_WORLD", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_CLOSE", "SPELLCAST_START",
		"SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "UI_ERROR_MESSAGE" };
	local i;
	for i = 1, getn(events) do
		this:UnregisterEvent(events[i]);
	end
	this:Hide();
	return 1;
end

function TradeSkillPlus_OnEvent(event)
	if (TradeSkillPlus_IsOldFrame()) then
		return;
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		if (not TradeSkillPlus_Started and SimpleSave_RegisterLoad) then
			TradeSkillPlus_Started = 1;
			SimpleSave_RegisterLoad(TradeSkillPlus_CheckOff);
		end
		return;
	end
	if (TradeSkillPlus_Off) then
		return;
	end

	if (event == "TRADE_SKILL_SHOW") then
		TradeSkillPlus_Amount = 1;
		TradeSkillPlus_LastSkill = TradeSkillFrame.selectedSkill;
		TradeSkillPlus_StopQueue();
		TradeSkillPlus_HideMoney();
		TradeSkillPlus_Update();
		return;
	end

	if (event == "TRADE_SKILL_CLOSE") then
		TradeSkillPlus_CancelTyping();
		TradeSkillPlus_StopQueue("window closed");
		return;
	end

	if (event == "TRADE_SKILL_UPDATE") then
		TradeSkillPlus_HideMoney();
		if (TradeSkillPlus_Active == 0) then
			-- new recipe selected: reset to 1
			if (TradeSkillFrame.selectedSkill ~= TradeSkillPlus_LastSkill) then
				TradeSkillPlus_LastSkill = TradeSkillFrame.selectedSkill;
				TradeSkillPlus_Amount = 1;
			end
		end
		TradeSkillPlus_Update();
		return;
	end

	-- Everything below only applies while a queue is running
	if (TradeSkillPlus_Active == 0) then
		return;
	end

	if (event == "SPELLCAST_START") then
		if (TradeSkillPlus_State == 3) then
			-- a cast started without us asking: the client repeats by itself
			if (TradeSkillPlus_Native ~= 1) then
				TradeSkillPlus_Debug("client repeats by itself");
			end
			TradeSkillPlus_Native = 1;
		end
		TradeSkillPlus_State = 2;
		TradeSkillPlus_Attempts = 0;
		TradeSkillPlus_Timer = TRADESKILLPLUS_CAST_TIMEOUT;
		return;
	end

	if (event == "SPELLCAST_STOP") then
		if (TradeSkillPlus_State == 2) then
			-- a craft finished
			TradeSkillPlus_Queue = TradeSkillPlus_Queue - 1;
			if (TradeSkillPlus_Queue < 1) then
				TradeSkillPlus_StopQueue("done");
				return;
			end
			TradeSkillPlus_State = 3;
			if (TradeSkillPlus_Native == -1) then
				TradeSkillPlus_Timer = TRADESKILLPLUS_DETECT_TIME;
			elseif (TradeSkillPlus_Native == 1) then
				TradeSkillPlus_Timer = TRADESKILLPLUS_NATIVE_WAIT;
			else
				-- start the next one on the next frame (not inside the STOP event)
				TradeSkillPlus_Timer = 0;
			end
		end
		return;
	end

	if (event == "SPELLCAST_INTERRUPTED") then
		if (TradeSkillPlus_State == 2) then
			-- e.g. the player moved during a cast: stop
			TradeSkillPlus_StopQueue("interrupted");
		end
		return;
	end

	if (event == "SPELLCAST_FAILED" or event == "UI_ERROR_MESSAGE") then
		-- an attempt was rejected; only matters while we wait for our attempt to start
		if (TradeSkillPlus_State == 1) then
			TradeSkillPlus_AttemptFailed(arg1 or event);
		end
		return;
	end
end


function TradeSkillPlus_OnUpdate(elapsed)
	if (TradeSkillPlus_IsOldFrame()) then
		return;
	end

	if (TradeSkillPlus_Active == 0) then
		return;
	end

	TradeSkillPlus_Timer = TradeSkillPlus_Timer - (elapsed or 0);
	if (TradeSkillPlus_Timer > 0) then
		return;
	end

	if (TradeSkillPlus_State == 3) then
		if (TradeSkillPlus_Native == -1) then
			-- no repeat from the client: the addon starts each craft
			TradeSkillPlus_Native = 0;
			TradeSkillPlus_Debug("addon starts each craft");
		end
		TradeSkillPlus_DoNextCraft();
	elseif (TradeSkillPlus_State == 1) then
		-- the attempt did not start a cast
		TradeSkillPlus_AttemptFailed("no cast started");
	elseif (TradeSkillPlus_State == 2) then
		TradeSkillPlus_StopQueue("cast never finished");
	end
end


function TradeSkillPlus_HideMoney()
	if (TradeSkillCostFrame) then
		TradeSkillCostFrame:Hide();
	end
	if (TradeSkillMoneyFrame) then
		TradeSkillMoneyFrame:Hide();
	end
	if (TradeSkillDetailMoneyFrame) then
		TradeSkillDetailMoneyFrame:Hide();
	end
end


-- How many of the selected recipe there are reagents for (0 if none)
function TradeSkillPlus_GetAvailable()
	local id = TradeSkillFrame.selectedSkill;
	local name, skillType, numAvailable;

	if (not id) then
		return 0;
	end

	name, skillType, numAvailable = GetTradeSkillInfo(id);

	if (skillType == "header" or not numAvailable or numAvailable < 0) then
		return 0;
	end

	return numAvailable;
end


-- Highest amount in the box (at least 1, at most 99)
function TradeSkillPlus_GetMax()
	local max = TradeSkillPlus_GetAvailable();

	if (max < 1) then
		max = 1;
	end
	if (max > TRADESKILLPLUS_MAX_AMOUNT) then
		max = TRADESKILLPLUS_MAX_AMOUNT;
	end

	return max;
end


function TradeSkillPlus_SetButton(button, enabled)
	if (button) then
		if (enabled == 1) then
			button:Enable();
		else
			button:Disable();
		end
	end
end


function TradeSkillPlus_Update()
	local max = TradeSkillPlus_GetMax();
	local canCraft = 0;
	local canChange = 0;

	if (TradeSkillPlus_Amount < 1) then
		TradeSkillPlus_Amount = 1;
	end
	if (TradeSkillPlus_Active == 0 and TradeSkillPlus_Amount > max) then
		TradeSkillPlus_Amount = max;
	end

	-- do not overwrite the box while the player is typing in it
	if (TradeSkillPlus_Typing == 0) then
		TradeSkillPlus_SetBoxText("" .. TradeSkillPlus_Amount);
	end

	-- + and - only when at least one can be made (like Create).
	if (TradeSkillPlus_Active == 0 and TradeSkillPlus_GetAvailable() > 0) then
		canCraft = 1;
		canChange = 1;
	end

	TradeSkillPlus_SetButton(TradeSkillPlusCreateButton, canCraft);
	TradeSkillPlus_SetButton(TradeSkillPlusCreateAllButton, canCraft);
	TradeSkillPlus_SetButton(TradeSkillPlusMinusButton, canChange);
	TradeSkillPlus_SetButton(TradeSkillPlusPlusButton, canChange);
end


function TradeSkillPlus_ChangeAmount(v)
	if (TradeSkillPlus_Active == 1) then
		return;
	end
	TradeSkillPlus_FinishTyping();

	TradeSkillPlus_Amount = TradeSkillPlus_Amount + v;
	TradeSkillPlus_Update();
end


function TradeSkillPlus_DoNextCraft()
	if (TradeSkillPlus_Queue < 1) then
		TradeSkillPlus_StopQueue("done");
		return;
	end
	if (TradeSkillPlus_GetAvailable() < 1) then
		TradeSkillPlus_StopQueue("out of reagents");
		return;
	end

	TradeSkillPlus_Attempts = TradeSkillPlus_Attempts + 1;
	TradeSkillPlus_State = 1;
	TradeSkillPlus_Timer = TRADESKILLPLUS_ATTEMPT_WAIT;
	-- like in 1.12.1: pass the remaining count
	DoTradeSkill(TradeSkillFrame.selectedSkill, TradeSkillPlus_Queue);
end


function TradeSkillPlus_StartQueue(amount)
	if (TradeSkillPlus_Active == 1 or amount < 1) then
		return;
	end

	TradeSkillPlus_Active = 1;
	TradeSkillPlus_Queue = amount;
	TradeSkillPlus_Attempts = 0;
	TradeSkillPlus_Update();
	TradeSkillPlus_DoNextCraft();
end


function TradeSkillPlus_CreateClick()
	TradeSkillPlus_FinishTyping();
	TradeSkillPlus_StartQueue(TradeSkillPlus_Amount);
end


function TradeSkillPlus_CreateAll()
	TradeSkillPlus_FinishTyping();
	TradeSkillPlus_StartQueue(TradeSkillPlus_GetAvailable());
end


-- ---------------------------------------------------------------------------
-- Amount box (EditBox): click it and type a number, or use - and +
-- ---------------------------------------------------------------------------

-- Set the box text without treating it as player input
function TradeSkillPlus_SetBoxText(text)
	if (TradeSkillPlusAmountBox) then
		TradeSkillPlus_SettingText = 1;
		TradeSkillPlusAmountBox:SetText(text);
		TradeSkillPlus_SettingText = 0;
	end
end


-- Player clicked the box: start typing with an empty box
function TradeSkillPlus_BoxClicked()
	if (TradeSkillPlus_Active == 1) then
		return;
	end
	if (TradeSkillPlus_Typing == 0) then
		TradeSkillPlus_OldAmount = TradeSkillPlus_Amount;
		TradeSkillPlus_Typing = 1;
		TradeSkillPlus_SetBoxText("");
	end
	TradeSkillPlusAmountBox:SetFocus();
end


-- Box text changed: keep digits only (max 2) and use the number as the amount
function TradeSkillPlus_BoxTextChanged()
	local text;
	local clean;
	local number;

	if (TradeSkillPlus_SettingText == 1 or TradeSkillPlus_Typing == 0) then
		return;
	end

	text = TradeSkillPlusAmountBox:GetText() or "";
	clean = gsub(text, "%D", "");
	if (strlen(clean) > 2) then
		clean = strsub(clean, 1, 2);
	end
	if (clean ~= text) then
		TradeSkillPlus_SetBoxText(clean);
	end

	number = tonumber(clean);
	if (number and number > 0) then
		TradeSkillPlus_Amount = number;
	end
end


-- Enter (or Create / Create All): accept the typed number
function TradeSkillPlus_FinishTyping()
	if (TradeSkillPlus_Typing == 1) then
		TradeSkillPlus_Typing = 0;
		if (TradeSkillPlusAmountBox) then
			TradeSkillPlusAmountBox:ClearFocus();
		end
		TradeSkillPlus_Update();
	end
end


-- Escape: throw away what was typed
function TradeSkillPlus_CancelTyping()
	if (TradeSkillPlus_Typing == 1) then
		TradeSkillPlus_Amount = TradeSkillPlus_OldAmount;
	end
	TradeSkillPlus_FinishTyping();
	if (TradeSkillPlusAmountBox) then
		TradeSkillPlusAmountBox:ClearFocus();
	end
end
