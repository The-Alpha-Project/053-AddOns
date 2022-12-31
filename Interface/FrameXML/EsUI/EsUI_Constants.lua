DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or ChatFrame1 or ChatFrame

CLASS_SORT_ORDER = CLASS_SORT_ORDER or {
	"WARRIOR",
	"PALADIN",
	"PRIEST",
	"SHAMAN",
	"DRUID",
	"ROGUE",
	"MAGE",
	"WARLOCK",
	"HUNTER",
	"UNKNOWN",
}

CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS or {
	["WARRIOR"]     = {0, 0.25, 0, 0.25},
	["MAGE"]        = {0.25, 0.49609375, 0, 0.25},
	["ROGUE"]       = {0.49609375, 0.7421875, 0, 0.25},
	["DRUID"]       = {0.7421875, 0.98828125, 0, 0.25},
	["HUNTER"]      = {0, 0.25, 0.25, 0.5},
	["SHAMAN"]      = {0.25, 0.49609375, 0.25, 0.5},
	["PRIEST"]      = {0.49609375, 0.7421875, 0.25, 0.5},
	["WARLOCK"]     = {0.7421875, 0.98828125, 0.25, 0.5},
	["PALADIN"]     = {0, 0.25, 0.5, 0.75},
	["GM"]          = {0.5, 0.73828125, 0.5, .75},
}

-- colors as of 1.1.0.4044
RAID_CLASS_COLORS = {
	["HUNTER"] = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
	["WARLOCK"] = { r = 0.53, g = 0.53, b = 0.93, colorStr = "ff8788ee" },
	["PRIEST"] = { r = 1.0, g = 1.0, b = 1.0, colorStr = "ffffffff" },
	["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
	["MAGE"] = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" },
	["ROGUE"] = { r = 1.0, g = 0.96, b = 0.41, colorStr = "fffff569" },
	["DRUID"] = { r = 1.0, g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
	["SHAMAN"] = { r = 0.0, g = 0.44, b = 0.87, colorStr = "ff0070de" },
	["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
}

-- original colors in patch 0.10.0.3892
--[[
RAID_CLASS_COLORS = {
	["HUNTER"] = { r = 0.96, g = 0.6, b = 0.47 },
	["WARLOCK"] = { r = 0.96, g = 0.6, b = 0.76 },
	["PRIEST"] = { r = 0.51, g = 0.58, b = 0.79 },
	["PALADIN"] = { r = 0.49, g = 0.65, b = 0.85 },
	["MAGE"] = { r = 0.78, g = 0.7, b = 0.6 },
	["ROGUE"] = { r = 0.67, g = 0.83, b = 0.45 },
	["DRUID"] = { r = 0.85, g = 0.67, b = 0.38 },
	["SHAMAN"] = { r = 0.38, g = 0.71, b = 0.84 },
	["WARRIOR"] = { r = 1, g = 0.96, b = 0.41 }
}
--]]

DAY_ONELETTER_ABBR = "%d d"
HOUR_ONELETTER_ABBR = "%d h"
MINUTE_ONELETTER_ABBR = "%d m"
SECOND_ONELETTER_ABBR = "%d s"

MAX_TARGET_DEBUFFS = 16

function RefreshEsUIVariables()
	EsUI.Name = UnitName("player")
	EsUI.Gender = UnitSex("player") == 0 and MALE or FEMALE
	EsUI.Race = UnitRace("player")
	EsUI.Class = UnitClass("player")
	EsUI.Level = UnitLevel("player")
	EsUI.ClassColor = EsUI.Class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[strupper(EsUI.Class)]
	EsUI.Resolution = ({GetScreenResolutions()})[GetCurrentResolution()] or GetCVar("gxResolution")
	EsUI.ScreenWidth, EsUI.ScreenHeight = DecodeResolution(EsUI.Resolution)
	EsUI.GameVersion, EsUI.GameBuild, EsUI.GameDate, EsUI.GameTOCVersion = GetBuildInfo()
end
RefreshEsUIVariables()