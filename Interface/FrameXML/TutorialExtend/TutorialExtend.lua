local TotalTimePlayed = 0;
local IgnoreEvents = false

function TutorialExtend_OnLoad()
	local currXP = UnitXP("player");
	-- Only hook to events if experience equals 0 (New Player)
	if( currXP == 0 ) then
		this:RegisterEvent("TIME_PLAYED_MSG");
		this:RegisterEvent("PLAYER_ENTERING_WORLD");
	end
end

function TutorialExtend_OnEvent()
	-- On entering world, request time played, which will later trigger 'TIME_PLAYED_MSG'
	if( event == "PLAYER_ENTERING_WORLD" ) then
		RequestTimePlayed();
	end
	
	if( event == "TIME_PLAYED_MSG" ) then
		TotalTimePlayed = floor(arg1);
		-- Check if TotalTimePlayed is less than 5 seconds.
		if( TotalTimePlayed < 5 ) then
			InitializeTutorials();
		end
	end
end

function InitializeTutorials()
	
	local currXP = UnitXP("player");
	if currXP == 0 then
		for i=1, 18 do
			TutorialFrame_NewTutorial(i);
		end
	end
end