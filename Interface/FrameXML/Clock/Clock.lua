--[[

	Clock: a simple in-game clock window
		copyright 2004 by Telo
        * ported to 0.5.3.3368 by GrenderG *

	- Displays the time in a small, movable window
	- Displays time-based character information in a tooltip on mouseover

]]

-- Configuration variables
local MilitaryTime = 0;		-- set this to something other than nil to use 24-hour display
local OffsetHour = 0;			-- this is the hour offset applied to server time
local OffsetMinute = 0;			-- this is the minute offset applied to server time


-- Constants
CLOCK_UPDATE_RATE = 0.1;
RUN_SPEED = 7;

-- Local variables

local TotalTimePlayed = 0;
local LevelTimePlayed = 0;
local SessionTimePlayed = 0;
local ElapsedSinceLastPlayedMessage = 0;
local NeedPlayedMessage = 1;

local localInitialXP;
local localSessionXP = 0;
local localRolloverXP = 0;

local localHealthSecondTimer = 0;
local localInitialHealth;
local localHealthPerSecond;
local localManaSecondTimer = 0;
local localInitialMana;
local localManaPerSecond;

local localInCombat;
local localLastPosition;
local localTravelTime = 0;
local localTravelDist = 0;

local localSpeed = 0;
local localSpeedDist = 0;
local localSpeedTime = 0;

-- Local functions
local function Clock_ResetHealth()
	localHealthSecondTimer = 0;
	localInitialHealth = UnitHealth("player");
end

local function Clock_ResetMana()
	localManaSecondTimer = 0;
	localInitialMana = UnitMana("player");
end

-- Callback functions
function ToggleClock()
	if( ClockFrame:IsVisible() ) then
		HideUIPanel(ClockFrame);
	else
		ShowUIPanel(ClockFrame);
	end
end

function ResetClockPosition(setval, checked)
	ClockFrame:ClearAllPoints();
	ClockFrame:SetPoint("TOP", "UIParent", "TOP", 0, 0);
end

function ClockFormat(checked)
	MilitaryTime = checked;
end

function ClockOffset(checked,value)
	local offset = value;
	if( OffsetHour > 0 ) then
		OffsetHour = math.floor(offset);
	else
		OffsetHour = math.ceil(offset);
	end
	OffsetMinute = (value - OffsetHour) * 60;
end

function ClockDisplay(toggle)
	if ( toggle == 1 ) then 
		ClockFrame:Show();
	else
		ClockFrame:Hide();
	end
end

local function Clock_ParsePosition(position)
	local x, y, z;
	local iStart, iEnd;
	
	iStart, iEnd, x, y, z = string.find(position, "^(.-), (.-), (.-)$");
	if( z ) then
		return x + 0.0, y + 0.0, z + 0.0;
	end
	return nil, nil, nil;
end

-- OnFoo functions
function Clock_OnLoad()
	this:RegisterEvent("TIME_PLAYED_MSG");
	this:RegisterEvent("PLAYER_LEVEL_UP");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_XP_UPDATE");
	this:RegisterEvent("UNIT_HEALTH");
	this:RegisterEvent("UNIT_MANA");
	this:RegisterEvent("PLAYER_ENTER_COMBAT");
	this:RegisterEvent("PLAYER_LEAVE_COMBAT");
	
if( Cosmos_RegisterConfiguration ~= nil ) then
		Cosmos_RegisterConfiguration("COS_CLOCK_SECTION",
			"SEPARATOR",
			"Clock",
			"This is a clock."
			);
		Cosmos_RegisterConfiguration("COS_CLOCK_ENABLE",
			"CHECKBOX",
			"Enable the Clock", 
			"This will display the in-game clock with a nice mouseover.",
			ClockDisplay,
			0,
			1
		);
		Cosmos_RegisterConfiguration("COS_CLOCK_OFFSET",
			"SLIDER",
			"Game time offset",
			"This is the offset from the server time\nto your local time.",
			ClockOffset,
			0,
			0,
			-12,
			12,
			"Offset",
			0.5,
			1,
			" hour(s)",
			1
			);
		Cosmos_RegisterConfiguration("COS_CLOCK_TWENTYFOUR_HOURS",
			"CHECKBOX",
			"Use 24-hour time format",
			"If checked, time will be displayed\nin twenty-four hour format.",
			ClockFormat,
			0,
			1
			);
		Cosmos_RegisterConfiguration("COS_CLOCK_RESET_POSITION",
			"BUTTON",
			"Reset clock position",
			"Reset the position of the clock to its default.",
			ResetClockPosition,
			0,
			0,
			0,
			0,
			"Reset"
			);
	end
	ClockFrame.TimeSinceLastUpdate = 0;
end

function Clock_OnUpdate(arg1)
	SessionTimePlayed = SessionTimePlayed + arg1;
	ElapsedSinceLastPlayedMessage = ElapsedSinceLastPlayedMessage + arg1;
	localHealthSecondTimer = localHealthSecondTimer + arg1;
	localManaSecondTimer = localManaSecondTimer + arg1;
	
	if( localHealthSecondTimer >= 1 and localInitialHealth ) then
		if( UnitHealth("player") < UnitHealthMax("player") ) then
			local hps = UnitHealth("player") - localInitialHealth;
			if( hps > 0 ) then
				localHealthPerSecond = hps / localHealthSecondTimer;
			end
		end
		Clock_ResetHealth();
	end
	
	if( localManaSecondTimer >= 1 and localInitialMana ) then
		if( UnitMana("player") < UnitManaMax("player") ) then
			local mps = UnitMana("player") - localInitialMana;
			if( mps > 0 ) then
				localManaPerSecond = mps / localManaSecondTimer;
			end
		end
		Clock_ResetMana();
	end
	
	ClockFrame.TimeSinceLastUpdate = ClockFrame.TimeSinceLastUpdate + arg1;
	if( ClockFrame.TimeSinceLastUpdate > CLOCK_UPDATE_RATE ) then
		ClockText:SetText(Clock_GetTimeText());
		if( CosmosTooltip:IsOwned(this) ) then
			Clock_SetTooltip();
		end
		ClockFrame.TimeSinceLastUpdate = 0;
	end
	
	if( localLastPosition ) then
		local currentPos = { };
		currentPos.x, currentPos.y, currentPos.z = Clock_ParsePosition(GetCurrentPosition());
		if( currentPos.z ) then
			local dist;

			-- travel speed ignores Z-distance (i.e. you run faster up or down hills)			
			dist = math.sqrt(
					((localLastPosition.x - currentPos.x) * (localLastPosition.x - currentPos.x)) +
					((localLastPosition.y - currentPos.y) * (localLastPosition.y - currentPos.y)));
			localSpeedDist = localSpeedDist + dist;
			localSpeedTime = localSpeedTime + arg1;
			if( localSpeedTime >= 1 ) then
				localSpeed = (floor(localSpeedDist / localSpeedTime + 0.5) / RUN_SPEED) * 100;
				localSpeedDist = 0;
				localSpeedTime = 0;
			end
			if( dist > 0 ) then
				if( not localInCombat ) then
					localTravelTime = localTravelTime + arg1;
					localTravelDist = localTravelDist + dist;
				end
				localLastPosition.x = currentPos.x;
				localLastPosition.y = currentPos.y;
				localLastPosition.z = currentPos.z;
			end
		end
	end
end

function Clock_OnEvent()
	if( event == "TIME_PLAYED_MSG" ) then
		TotalTimePlayed = arg1;
		LevelTimePlayed = arg2;
		ElapsedSinceLastPlayedMessage = 0;
		NeedPlayedMessage = 0;
		
	-- Sync up all of the times to the session time; this makes
	-- the tooltip look nicer as everything changes all at once
	local fraction = SessionTimePlayed - floor(SessionTimePlayed);
		TotalTimePlayed = floor(TotalTimePlayed) + fraction;
		LevelTimePlayed = floor(LevelTimePlayed) + fraction;

		if( CosmosTooltip:IsOwned(this) ) then
			Clock_SetTooltip();
		end
	elseif( event == "PLAYER_LEVEL_UP" ) then
		LevelTimePlayed = SessionTimePlayed - floor(SessionTimePlayed);
		localRolloverXP = localSessionXP;
		localInitialXP = 0;
		if( CosmosTooltip:IsOwned(this) ) then
			Clock_SetTooltip();
		end
	elseif( event == "PLAYER_ENTERING_WORLD" ) then
		if( not localInitialXP ) then
		localInitialXP = UnitXP("player");
			localLastPosition = { };
			localLastPosition.x, localLastPosition.y, localLastPosition.z = Clock_ParsePosition(GetCurrentPosition());
			if( not localLastPosition.z ) then
				localLastPosition = nil;
			end
		end
		Clock_ResetHealth();
		Clock_ResetMana();
	elseif( event == "PLAYER_XP_UPDATE" ) then
		if( localInitialXP ) then
			localSessionXP = UnitXP("player") - localInitialXP + localRolloverXP;
		end
	elseif( event == "UNIT_HEALTH" ) then
		if( arg1 == "player" ) then
			if( not localInitialHealth or UnitHealth("player") - localInitialHealth < 0 ) then
				Clock_ResetHealth();
			end
		end
	elseif( event == "UNIT_MANA" ) then
		if( arg1 == "player" ) then
			if( not localInitialMana or UnitMana("player") - localInitialMana < 0 ) then
				Clock_ResetMana();
			end
		end
	elseif( event == "PLAYER_ENTER_COMBAT" ) then
		localInCombat = 1;
	elseif( event == "PLAYER_LEAVE_COMBAT" ) then
		localInCombat = nil;
	end
end

function ClockText_OnEnter()
	if( NeedPlayedMessage == 1 ) then
		RequestTimePlayed();
	end
	CosmosTooltip:SetOwner(ClockFrame, "ANCHOR_BOTTOMLEFT");
	Clock_SetTooltip();

	Clock_SetClockTooltipPoint();	
end

function Clock_SetClockTooltipPoint()
 	-- Figured out the scale system.. it shows the scale between the object and the UIParent
	local x,y = ClockFrame:GetCenter();
	local screenWidth = UIParent:GetWidth();
	local screenHeight = UIParent:GetHeight();
	if (x~=nil and y~=nil and screenWidth>0 and screenHeight>0) then
		local anchorPoint = "";
		local relativePoint = "";
		if (y <= (screenHeight * (1/2))) then
			anchorPoint = "BOTTOM";
			relativePoint = "TOP";
		else
			anchorPoint = "TOP";
			relativePoint = "BOTTOM";
		end
		if (x <= (screenWidth * (1/2))) then
			anchorPoint = anchorPoint.."LEFT";
			relativePoint = relativePoint.."LEFT";
		else
			anchorPoint = anchorPoint.."RIGHT";
			relativePoint = relativePoint.."RIGHT";
		end
		
		if (anchorPoint == "") then
			anchorPoint = "TOPLEFT";
		end
		
		if (relativePoint == "") then
			anchorPoint = "BOTTOMLEFT";
		end
		
		CosmosTooltip:ClearAllPoints();
		CosmosTooltip:SetPoint(anchorPoint, ClockFrame:GetName(), relativePoint, 0, 0);
	end
end

-- Helper functions
function Clock_GetTimeText()
	local hour, minute = GetGameTime();
	local pm;

	hour = hour + OffsetHour;
	minute = minute + OffsetMinute;
	if( minute > 59 ) then
		minute = minute - 60;
		hour = hour + 1;
	elseif( minute < 0 ) then
		minute = 60 + minute;
		hour = hour - 1;
	end
	if( hour > 23 ) then
		hour = hour - 24;
	elseif( hour < 0 ) then
		hour = 24 + hour;
	end

	if( MilitaryTime == 1 ) then
		return format(TEXT(TIME_TWENTYFOURHOURS), hour, minute);
	else
		if( hour >= 12 ) then
			pm = 1;
			hour = hour - 12;
		else
			pm = 0;
		end
		if( hour == 0 ) then
			hour = 12;
		end
		if( pm == 1 ) then
			return format(TEXT(TIME_TWELVEHOURPM), hour, minute);
		else
			return format(TEXT(TIME_TWELVEHOURAM), hour, minute);
		end
	end
end

local function Clock_FormatPart(fmt, val)
	local part;

	part = format(TEXT(fmt), val);
	if( val ~= 1 ) then
		part = part.."s";
	end

	return part;
end

function Clock_FormatTime(time)
	local d, h, m, s;
	local text = "";
	local skip = 1;

	d, h, m, s = ChatFrame_TimeBreakDown(time);
	if( d > 0 ) then
		text = text..Clock_FormatPart(CLOCK_TIME_DAY, d)..", ";
		skip = 0;
	end
	if( (skip == 0) or (h > 0) ) then
		text = text..Clock_FormatPart(CLOCK_TIME_HOUR, h)..", ";
		skip = 0;
	end
	if( (skip == 0) or (m > 0) ) then
		text = text..Clock_FormatPart(CLOCK_TIME_MINUTE, m)..", ";
		skip = 0;
	end
	if( (skip == 0) or (s > 0) ) then
		text = text..Clock_FormatPart(CLOCK_TIME_SECOND, s);
	end

	return text;
end

function Clock_SetTooltip()
	local total, level, session;
	local xpPerHourLevel, xpPerHourSession;
	local xpTotal, xpCurrent, xpToLevel;
	local text;

	total = format(TEXT(TIME_PLAYED_TOTAL), Clock_FormatTime(TotalTimePlayed + ElapsedSinceLastPlayedMessage));
	level = format(TEXT(TIME_PLAYED_LEVEL), Clock_FormatTime(LevelTimePlayed + ElapsedSinceLastPlayedMessage));
	session = format(TEXT(TIME_PLAYED_SESSION), Clock_FormatTime(SessionTimePlayed));

	if( NeedPlayedMessage == 1 ) then
		text = session;
	else
		text = total.."\n"..level.."\n"..session;
	end

	if( (LevelTimePlayed + ElapsedSinceLastPlayedMessage > 0) or SessionTimePlayed > 0 ) then
		text = text.."\n";
	end
	if( LevelTimePlayed + ElapsedSinceLastPlayedMessage > 0 ) then
		xpPerHourLevel = UnitXP("player") / ((LevelTimePlayed + ElapsedSinceLastPlayedMessage) / 3600);
		text = text.."\n"..format(TEXT(EXP_PER_HOUR_LEVEL), xpPerHourLevel);
	else
		xpPerHourLevel = 0;
	end
	if( SessionTimePlayed > 0 ) then
		xpPerHourSession = localSessionXP / (SessionTimePlayed / 3600);
		text = text.."\n"..format(TEXT(EXP_PER_HOUR_SESSION), xpPerHourSession);
	else
		xpPerHourSession = 0;
	end
	
	xpTotal = UnitXPMax("player");
	xpCurrent = UnitXP("player");
	if( xpCurrent < xpTotal ) then
		xpToLevel = xpTotal - xpCurrent;
		text = text.."\n"..format(TEXT(EXP_TO_LEVEL), xpToLevel, (xpToLevel / xpTotal) * 100);
		if( xpPerHourLevel > 0 ) then
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_LEVEL), Clock_FormatTime((xpToLevel / xpPerHourLevel) * 3600));
		else
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_LEVEL), TEXT(TIME_INFINITE));
		end
		if( xpPerHourSession > 0 ) then
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_SESSION), Clock_FormatTime((xpToLevel / xpPerHourSession) * 3600));
		else
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_SESSION), TEXT(TIME_INFINITE));
		end
	end

	if( localHealthPerSecond or localManaPerSecond ) then
		text = text.."\n";
	end
	if( localHealthPerSecond ) then
		text = text.."\n"..format(TEXT(HEALTH_PER_SECOND), localHealthPerSecond);
	end
	if( localManaPerSecond ) then
		text = text.."\n"..format(TEXT(MANA_PER_SECOND), localManaPerSecond);
	end
	
	text = text.."\n\n"..format(TEXT(NONCOMBAT_TRAVEL_DISTANCE), localTravelDist);
	if( SessionTimePlayed ~= 0 ) then
		text = text.."\n"..format(TEXT(NONCOMBAT_TRAVEL_PERCENTAGE), (localTravelTime / SessionTimePlayed) * 100.0);
	end
	
	text = text.."\n\n"..format(TEXT(TRAVEL_SPEED), localSpeed);
	
	CosmosTooltip:SetText(text);
end

