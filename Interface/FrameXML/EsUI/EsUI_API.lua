----------------------------------------------------------------------------------------
--	print
----------------------------------------------------------------------------------------
if not print then
	function print(arg)
		DEFAULT_CHAT_FRAME:AddMessage(arg)
	end
end

----------------------------------------------------------------------------------------
--	tonumber
----------------------------------------------------------------------------------------
if not tonumber then
	function tonumber(arg)
		if arg then return arg + 0 end -- really only useful on strings where ONLY numbers are contained
	end
end

----------------------------------------------------------------------------------------
--	tostring
----------------------------------------------------------------------------------------
if not tostring then
	function tostring(arg)
		if arg then return arg .. "" end -- really only useful on numbers
	end
end

----------------------------------------------------------------------------------------
--	strsplit
----------------------------------------------------------------------------------------
if not strsplit and string.split then strsplit = string.split end

if not strsplit then
	function strsplit(delimiter, subject)
		if not subject then return nil end

		local delimiter, fields = delimiter or ":", {}
		local pattern = format("([^%s]+)", delimiter)
		gsub(subject, pattern, function(c) fields[getn(fields) + 1] = c end)
		return fields[1], fields[2], fields[3], fields[4], fields[5], fields[6], fields[7], fields[8], fields[9], fields[10], fields[11], fields[12], fields[13], fields[14], fields[15], fields[16], fields[17], fields[18], fields[19], fields[20]
	end
end

----------------------------------------------------------------------------------------
--	DecodeResolution
----------------------------------------------------------------------------------------
if not DecodeResolution then
	function DecodeResolution(valueString)
		if(valueString == nil) then
			return 0, 0
		end
		local xIndex = strfind(valueString, "x")
		local width = strsub(valueString, 1, xIndex - 1)
		local height = strsub(valueString, xIndex + 1, strlen(valueString))
		local widthIndex = strfind(height, " ")
		if widthIndex then
			height = strsub(height, 0, widthIndex - 1)
		end
		return tonumber(width), tonumber(height)
	end
end

----------------------------------------------------------------------------------------
--	GetBuildInfo (1.10.0)
----------------------------------------------------------------------------------------
if not GetBuildInfo then
	local builds = {
		["0.3.4"] = {"2953", 26}, -- guessed interface version
		["0.4.0"] = {"", 26}, -- unknown build number / guessed interface version
		["0.5.3"] = {"3368", 26},
		["0.5.4"] = {"", 26}, -- unknown build number
		["0.5.5"] = {"3494", 26},
		["0.6.0"] = {"3592", 26},
		["0.7.0"] = {"3694", 26},
		["0.7.1"] = {"3702", 26},
		["0.7.2"] = {"3705", 26},
		["0.7.3"] = {"3710", 26},
		["0.7.5"] = {"3711", 26},
		["0.7.6"] = {"3712", 26},
		["0.8.0"] = {"3734", 26},
		["0.9.0"] = {"3807", 26},
		["0.9.1"] = {"3810", 26},
		["0.10.0"] = {"3892", 83},
		["0.11.0"] = {"3925", 106},
		["0.12.0"] = {"3988", 3986},
		["1.0.0"] = {"3980", 3975},
		["1.0.1"] = {"3989", 3986},
		["1.1.0"] = {"4044", 3975},
		["1.1.1"] = {"4062", 4062},
		["1.1.2"] = {"4125", 4120},
		["1.2.0"] = {"4147", 4146},
		["1.2.1"] = {"4150", 4150},
		["1.2.2"] = {"4196", 4196},
		["1.2.3"] = {"4211", 4211},
		["1.2.4"] = {"4222", 4216},
		["1.3.0"] = {"4273", 1300},
		["1.3.1"] = {"4297", 1300},
		["1.3.2"] = {"4298", 1300},
		["1.4.0"] = {"4341", 1300},
		["1.4.1"] = {"4364", 1300},
		["1.4.2"] = {"4375", 1300},
		["1.5.0"] = {"4442", 1500},
		["1.5.1"] = {"4449", 1500},
		["1.6.0"] = {"4500", 1600},
		["1.6.1"] = {"4544", 1600},
		["1.7.0"] = {"4671", 1700},
		["1.7.1"] = {"4695", 1700},
		["1.8.0"] = {"4735", 1800},
		["1.8.1"] = {"4769", 1800},
		["1.8.2"] = {"4784", 1800},
		["1.8.3"] = {"4807", 1800},
		["1.8.4"] = {"4878", 1800},
		["1.9.0"] = {"4937", 10900},
		["1.9.1"] = {"4983", 10900},
		["1.9.2"] = {"4996", 10900},
		["1.9.3"] = {"5059", 10900},
		["1.9.4"] = {"5086", 10900},
	}

	function GetBuildInfo()
		local version = gsub(GetBuildVersion(), "%s+", "")
		local major, minor, fix = strsplit(".", version)

		major = major or 0
		minor = minor or 0
		fix = fix or 0

		if tonumber(major) > 1 then
			fix = minor
			minor = major
			major = 0
		end

		version = major .. "." .. minor .. "." .. fix

		local build = builds[version] and builds[version][1] or ""
		local date = GetDate()
		local tocversion = builds[version] and builds[version][2] or 26

		return version, build, date, tocversion
	end
end

----------------------------------------------------------------------------------------
--	InCombatLockdown (2.0.1)
----------------------------------------------------------------------------------------
InCombatLockdown = InCombatLockdown or function()
	return ESUI_IN_COMBAT_LOCKDOWN
end

----------------------------------------------------------------------------------------
--	UnitInRaid (1.6.0)
----------------------------------------------------------------------------------------
if not UnitInRaid then
	function UnitInRaid(unit)
		if not GetNumRaidMembers or (GetNumRaidMembers and GetNumRaidMembers() > 0) then
			return
		else
			local name = unit and UnitName(unit)
			if name then
				for i = 1, GetNumRaidMembers() do
					local rName = GetRaidRosterInfo(i)
					if rName and name == rName then
						return i
					end
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------
--	ToggleFrame -- TODO: Label which patch this was added
----------------------------------------------------------------------------------------
if not ToggleFrame then
	function ToggleFrame(frame)
		if not frame then return end

		if frame:IsVisible() then
			HideUIPanel(frame)
		else
			ShowUIPanel(frame)
		end
	end
end

----------------------------------------------------------------------------------------
--	SecondsToTimeAbbrev -- TODO: Label which patch this was added
----------------------------------------------------------------------------------------
if not SecondsToTimeAbbrev then
	function SecondsToTimeAbbrev(seconds)
		local tempTime
		if ( seconds >= 86400  ) then
			tempTime = ceil(seconds / 86400)
			return format(TEXT(DAY_ONELETTER_ABBR), tempTime)
		end
		if ( seconds >= 3600  ) then
			tempTime = ceil(seconds / 3600)
			return format(TEXT(HOUR_ONELETTER_ABBR), tempTime)
		end
		if ( seconds >= 60  ) then
			tempTime = ceil(seconds / 60)
			return format(TEXT(MINUTE_ONELETTER_ABBR), tempTime)
		end
		return format(TEXT(SECOND_ONELETTER_ABBR), seconds)
	end
end

----------------------------------------------------------------------------------------
--	UnitBuff / UnitDebuff / UnitAura -- TODO: Finish this
----------------------------------------------------------------------------------------
if not UnitBuff then
	function UnitBuff(unit, buffIndex, castable)
		if not unit or not buffIndex then return end

		local name, rank, iconTexture, count, duration, timeLeft

		if GetPlayerBuff(buffIndex, "HELPFUL|PASSIVE") then
			if unit == "player" then
				iconTexture = GetPlayerBuffTexture(buffIndex)
				timeLeft = GetPlayerBuffTimeLeft(buffIndex)
			else

			end
		end

		return name, rank, iconTexture, count, duration, timeLeft
	end
end
