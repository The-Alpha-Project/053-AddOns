--------------------------------------------------------------------------------
-- SimpleQoL, modules: loaded last in SimpleQoL.xml, after the built-in copies
-- of ImprovedErrorFrame, ActionBars and TradeSkillPlus were made. It remembers
-- those copies. The same addon may also be installed on its own, in any
-- order and version: the newest copy runs (older copies loaded later run
-- instead, as before). Frames that an older copy hid are started again.
--------------------------------------------------------------------------------

SimpleQoL_ModCopies = {
	actionbars = {
		handler = "ActionBars_OnEvent", frames = { "ActionBarsEventFrame" }, count = { "ActionBarsCD", 72 },
		events = { "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID" },
	},
	errorframe = {
		handler = "IEF_OnEvent", frames = { "IEFEventFrame", "ImprovedErrorFrame", "ImprovedErrorButton" },
		events = { "PLAYER_ENTERING_WORLD" },
	},
	tradeskillplus = {
		handler = "TradeSkillPlus_OnEvent", frames = { "TradeSkillPlusFrame", "TradeSkillPlusRowBackground", "TradeSkillPlusJoints", "TradeSkillPlusCreateAllButton",
			"TradeSkillPlusMinusButton", "TradeSkillPlusAmountBox", "TradeSkillPlusPlusButton", "TradeSkillPlusCreateButton" },
		events = { "PLAYER_ENTERING_WORLD", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_CLOSE", "SPELLCAST_START",
			"SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "UI_ERROR_MESSAGE" },
	},
};

-- Our copies right now (their frames and which copy runs).
function SimpleQoL_ModRemember()
	foreach(SimpleQoL_ModCopies, function(key, copy)
		local list = {};
		local i;
		for i = 1, getn(copy.frames) do
			tinsert(list, getglobal(copy.frames[i]) or 0);
		end
		if ( copy.count ) then
			for i = 1, copy.count[2] do
				tinsert(list, getglobal(copy.count[1]..i) or 0);
			end
		end
		copy.objects = list;
	end);
	SimpleQoL_ModCopies.actionbars.token = ActionBars_Copy;
	SimpleQoL_ModCopies.tradeskillplus.token = TradeSkillPlus_Copy;
	SimpleQoL_ModCopies.errorframe.real = IEF_RealScriptErrors;
	SimpleQoL_ModCopies.errorframe.realMessage = IEF_RealScriptErrorsMessage;
end

-- At login: an older copy loaded after ours may have hidden the event frame
-- in use (0.5.3 keeps the frames of the copy loaded first under their names,
-- older copies hid them when loaded). It runs again and gets the login event
-- it missed. Not for a module turned off in /qol (it hides itself).
function SimpleQoL_ModHeal()
	foreach(SimpleQoL_ModCopies, function(key, copy)
		if ( copy.superseded or ( SimpleSave_Get and SimpleSave_Get("SimpleQoL", key) == "0" ) ) then
			return;
		end
		local frame = getglobal(copy.frames[1]);
		if ( not frame or frame:IsVisible() ) then
			return;
		end
		copy.healed = 1;
		local j;
		for j = 1, getn(copy.events) do
			frame:RegisterEvent(copy.events[j]);
		end
		frame:Show();
		local handler = getglobal(copy.handler);
		if ( handler ) then
			local old = this;
			this = frame;
			handler("PLAYER_ENTERING_WORLD");
			this = old;
		end
	end);
end

-- At login: a copy loaded after ours made new frames, so ours steps back.
function SimpleQoL_ModCheck()
	foreach(SimpleQoL_ModCopies, function(key, copy)
		local first = copy.objects and copy.objects[1];
		if ( not first or first == 0 or first == getglobal(copy.frames[1]) ) then
			return;
		end
		copy.superseded = 1;
		local i, j;
		for i = 1, getn(copy.objects) do
			local frame = copy.objects[i];
			if ( frame ~= 0 ) then
				if ( i == 1 ) then
					for j = 1, getn(copy.events) do
						frame:UnregisterEvent(copy.events[j]);
					end
				end
				frame:Hide();
			end
		end
	end);
	-- Our hooks only pass calls on (unless a newer copy already took over).
	if ( SimpleQoL_ModCopies.actionbars.superseded and ActionBars_Copy == SimpleQoL_ModCopies.actionbars.token ) then
		ActionBars_Copy = "SimpleQoL";
	end
	if ( SimpleQoL_ModCopies.tradeskillplus.superseded and TradeSkillPlus_Copy == SimpleQoL_ModCopies.tradeskillplus.token ) then
		TradeSkillPlus_Copy = "SimpleQoL";
	end
	-- An older copy loaded later took our error catcher for the game's window.
	if ( SimpleQoL_ModCopies.errorframe.superseded and SimpleQoL_ModCopies.errorframe.real ) then
		IEF_RealScriptErrors = SimpleQoL_ModCopies.errorframe.real;
		IEF_RealScriptErrorsMessage = SimpleQoL_ModCopies.errorframe.realMessage;
	end
	SimpleQoL_ModHeal();
end

SimpleQoL_ModRemember();
