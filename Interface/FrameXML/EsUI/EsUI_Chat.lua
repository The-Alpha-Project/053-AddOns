----------------------------------------------------------------------------------------
--	Profanity Filter
----------------------------------------------------------------------------------------
SetCVar("profanityFilter", EsUI.C.Chat.profanity_filter and 1 or 0)

----------------------------------------------------------------------------------------
--	Chat Copy
----------------------------------------------------------------------------------------
local function Copy(string, r, g, b)
	if not string then return end

	string = format("|cff%02x%02x%02x%s|r", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255, string)

	if not ESUI_CHAT_COPY_CONTENTS then
		ESUI_CHAT_COPY_CONTENTS = string
	else
		ESUI_CHAT_COPY_CONTENTS = strsub(ESUI_CHAT_COPY_CONTENTS, -99999) -- truncate if too many characters
		ESUI_CHAT_COPY_CONTENTS = ESUI_CHAT_COPY_CONTENTS .. "\n" .. string
	end
end

local originalChatFrameOnEvent = ChatFrame_OnEvent
ChatFrame_OnEvent = function(event)
	if event == "PLAYER_LOGOUT_FAILED" then
		Copy(TEXT(PLAYER_LOGOUT_FAILED), 1, 0, 0)
	end

	if event == "PLAYER_LEVEL_UP" then
		-- Level up
		local info = ChatTypeInfo["SYSTEM"]

		local string = format(TEXT(LEVEL_UP), arg1)
		Copy(string, info.r, info.g, info.b)

		if arg3 > 0 then
			string = format(TEXT(LEVEL_UP_HEALTH_MANA), arg2, arg3)
		else
			string = format(TEXT(LEVEL_UP_HEALTH), arg2)
		end
		Copy(string, info.r, info.g, info.b)

		if arg4 > 0 then
			string = format(GetText("LEVEL_UP_CHAR_POINTS", nil, arg4), arg4)
			Copy(string, info.r, info.g, info.b)
		end

		if arg5 > 0 then
			string = format(GetText("LEVEL_UP_SKILL_POINTS", nil, arg5), arg5)
			Copy(string, info.r, info.g, info.b)
		end
	end

	if strsub(event, 1, 8) == "CHAT_MSG" then
		local type = strsub(event, 10)
		local info = ChatTypeInfo[type]

		if type == "SYSTEM" or type == "TEXT_EMOTE" or type == "SKILL" or type == "LOOT" then
			Copy(arg1, info.r, info.g, info.b)
		elseif type == "COMBAT_LOG" then
			Copy(arg1, info.r, info.g, info.b)
		elseif type == "IGNORED" then
			Copy(format(TEXT(getglobal("CHAT_IGNORED")), arg2), info.r, info.g, info.b)
		elseif type == "CHANNEL_LIST" then
			if strlen(arg4) > 0 then
				Copy(format(TEXT(getglobal("CHAT_" .. type .. "_GET")) .. arg1, arg4), info.r, info.g, info.b)
			else
				Copy(arg1, info.r, info.g, info.b)
			end
		elseif type == "CHANNEL_NOTICE_USER" then
			if strlen(arg5) > 0 then
				-- TWO users in this notice (E.G. x kicked y)
				Copy(format(TEXT(getglobal("CHAT_" .. arg1 .. "_NOTICE")), arg4, arg2, arg5), info.r, info.g, info.b)
			else
				Copy(format(TEXT(getglobal("CHAT_" .. arg1 .. "_NOTICE")), arg4, arg2), info.r, info.g, info.b)
			end
		elseif type == "CHANNEL_NOTICE" then
			Copy(format(TEXT(getglobal("CHAT_" .. arg1 .. "_NOTICE")), arg4), info.r, info.g, info.b)
		elseif arg1 then
			-- Hide addon messages
			if strsub(event, 1, 16) == "CHAT_MSG_CHANNEL" then
				if arg4 and strfind(arg4, "Addonauras") then
					return
				end
			end

			arg1 = gsub(arg1, "%%", "%%%%")
			local body

			-- Add AFK/DND flags
			local pflag
			if strlen(arg6) > 0 then
				pflag = TEXT(getglobal("CHAT_FLAG_" .. arg6))
			else
				pflag = ""
			end
			if strlen(arg3) > 0 and arg3 ~= "Universal" and arg3 ~= this.defaultLanguage then
				local languageHeader = "[" .. arg3 .. "] "
				body = format(TEXT(getglobal("CHAT_" .. type .. "_GET")) .. languageHeader .. arg1, pflag .. arg2)
			else
				body = format(TEXT(getglobal("CHAT_" .. type .. "_GET")) .. arg1, pflag .. arg2)
			end

			-- Add Channel
			if strlen(arg4) > 0 then
				body = "[" .. arg4 .. "] " .. body
			end

			Copy(body, info.r, info.g, info.b)
		end
	end

	originalChatFrameOnEvent(event)
end
