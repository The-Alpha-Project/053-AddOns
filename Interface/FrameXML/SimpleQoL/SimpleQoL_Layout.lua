-- Stand-ins for base functions the 0.5.3 client lacks (AlphaUI normally supplies them).
-- The client has no type() either, so none is used here.
if ( not tostring ) then
	tostring = function(value)
		if ( value == nil ) then
			return "";
		end
		if ( value == true ) then
			return "true";
		end
		if ( value == false ) then
			return "false";
		end
		return format("%s", value);
	end
end
if ( not tonumber ) then
	tonumber = function(value)
		if ( value == nil or value == true or value == false ) then
			return nil;
		end
		value = gsub(format("%s", value), "^%s+", "");
		value = gsub(value, "%s+$", "");
		if ( strfind(value, "^[-+]?%d+%.?%d*$") or strfind(value, "^[-+]?%d*%.%d+$") ) then
			return value + 0;
		end
		return nil;
	end
end
-- Options rows below the emergency rows: { name, x, y } (TOPLEFT of the window).
SIMPLEQOL_OPTIONS_SHIFT = {
	{ "SimpleQoLOptionsHeader5", 254, -256 },
	{ "SimpleQoLOption28", 250, -274 },
	{ "SimpleQoLOption29", 250, -294 },
	{ "SimpleQoLOption30", 250, -314 },
	{ "SimpleQoLOption31", 250, -334 },
	{ "SimpleQoLOption32", 250, -354 },
	{ "SimpleQoLOption36", 250, -374 },
	{ "SimpleQoLOption38", 250, -394 },
	{ "SimpleQoLOptionsHeader6", 254, -418 },
	{ "SimpleQoLOption33", 250, -436 },
	{ "SimpleQoLOptionsModule_actionbars", 400, -438 },
	{ "SimpleQoLOption34", 250, -456 },
	{ "SimpleQoLOption35", 250, -476 },
	{ "SimpleQoLOptionsModule_errorframe", 400, -478 },
};
