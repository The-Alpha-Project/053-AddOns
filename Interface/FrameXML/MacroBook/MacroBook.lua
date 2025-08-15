-- Credits: Nutrinoff

-- SavedVariables
MacroBook_Macros = MacroBook_Macros or {}

MacroBookSlashHandlers = {
  -- Chat & Social
  ["/afk"] = function(msg) SendChatMessage(msg, "AFK") end,
  ["/dnd"] = function(msg) SendChatMessage(msg, "DND") end,
  ["/whisper"] = function(msg) ChatMenu_Whisper() end,  -- needs improvement
  ["/reply"] = function(msg) ChatFrame_ReplyTell() end,

  -- Guild
  ["/ginvite"] = function(msg) GuildInviteByName(msg) end,
  ["/gkick"] = function(msg) GuildUninviteByName(msg) end,
  ["/gpromote"] = function(msg) GuildPromoteByName(msg) end,
  ["/gdemote"] = function(msg) GuildDemoteByName(msg) end,
  ["/gleader"] = function(msg) GuildSetLeaderByName(msg) end,
  ["/gmotd"] = function(msg) GuildSetMOTD(msg) end,
  ["/gquit"] = function() GuildLeave() end,
  ["/gdisband"] = function() GuildDisband() end,
  ["/ginfo"] = function() GuildInfo() end,
  ["/groster"] = function() GuildRoster() end,
  ["/ghelp"] = function() ChatFrame_DisplayGuildHelp() end,

  -- Party / Player
  ["/invite"] = function(msg) InviteByName(msg) end,
  ["/uninvite"] = function(msg) UninviteByName(msg) end,
  ["/promote"] = function(msg) PromoteByName(msg) end,
  ["/duel"] = function(msg) StartDuel(msg) end,
  ["/forfeit"] = function() CancelDuel() end,
  ["/follow"] = function(msg) FollowByName(msg) end,
  ["/assist"] = function(msg) AssistByName(msg) end,
  ["/inspect"] = function() InspectUnit("target") end,
  ["/trade"] = function() InitiateTrade("target") end,

  -- Account / UI
  ["/reload"] = function() ReloadUI() end,
  ["/logout"] = function() Logout() end,
  ["/quit"] = function() Quit() end,
  ["/bug"] = function() ShowSuggestFrame() end,
  ["/suggest"] = function() ShowSuggestFrame() end,
  ["/played"] = function() RequestTimePlayed() end,
  ["/time"] = function() ChatFrame_DisplayGameTime() end,
  ["/bindzone"] = function() GetBindZone() end,
  ["/stuck"] = function() Stuck() end,

  -- Loot
  ["/ffa"] = function() SetLootMethod("freeforall") end,
  ["/roundrobin"] = function() SetLootMethod("roundrobin") end,
  ["/master"] = function(msg) SetLootMethod("master", msg) end,

  -- Random
  ["/random"] = function(msg)
    local num1, num2 = string.match(msg, "(%d+)[%s-]*(%d*)")
    if not num1 then RandomRoll("1", "100")
    elseif num1 and num2 == "" then RandomRoll("1", num1)
    else RandomRoll(num1, num2) end
  end,

  -- Channel management
  ["/join"] = function(msg) JoinChannelByName(msg) end,
  ["/leave"] = function(msg) LeaveChannelByName(msg) end,
  ["/list"] = function() ListChannels() end,
  ["/mod"] = function(msg) ChannelModerator(msg) end,
  ["/unmod"] = function(msg) ChannelUnmoderator(msg) end,
  ["/mute"] = function(msg) ChannelMute(msg) end,
  ["/unmute"] = function(msg) ChannelUnmute(msg) end,
  ["/kick"] = function(msg) ChannelKick(msg) end,
  ["/ban"] = function(msg) ChannelBan(msg) end,
  ["/unban"] = function(msg) ChannelUnban(msg) end,
  ["/owner"] = function(msg) SetChannelOwner(msg) end,
  ["/password"] = function(msg) SetChannelPassword(msg) end,
  ["/announce"] = function(msg) ChannelToggleAnnouncements(msg) end,
  ["/cinvite"] = function(msg) ChannelInvite(msg) end,

  -- Friends / Ignore
  ["/friend"] = function(msg) AddFriend(msg) end,
  ["/removefriend"] = function(msg) RemoveFriend(msg) end,
  ["/ignore"] = function(msg) AddOrDelIgnore(msg) end,
  ["/unignore"] = function(msg) DelIgnore(msg) end,

  -- Scripting & debug
  ["/script"] = function(msg) RunScript(msg) end,
  ["/note"] = function(msg) ReportNote(msg) end,
  ["/combatlog"] = function() ToggleCombatLogFileWrite() end,
}


function MacroBook_CastSpellByName(spellName)
    for i = 1, MAX_SPELLS do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if name == spellName then
            CastSpell(i, BOOKTYPE_SPELL)
            return true
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff2020MacroBook: Could not find spell '"..spellName.."'|r")
    return false
end


-- Fallback for RunMacroText if missing in 0.5.3
if not RunMacroText then
  function RunMacroText(text)
    for line in string.gfind(text, "[^\n]+") do
      local space = string.find(line, " ")
      local cmd, args
      if space then
        cmd = string.sub(line, 1, space - 1)
        args = string.sub(line, space + 1)
      else
        cmd = line
        args = ""
      end

      cmd = string.lower(cmd)

      -- Direct handlers
      if MacroBookSlashHandlers[cmd] then
        MacroBookSlashHandlers[cmd](args)

      -- Built-in chat or cast
      elseif cmd == "/say" then
        SendChatMessage(args, "SAY")
      elseif cmd == "/yell" then
        SendChatMessage(args, "YELL")
      elseif cmd == "/party" then
        SendChatMessage(args, "PARTY")
      elseif cmd == "/cast" then
        MacroBook_CastSpellByName(args)

      -- Emotes (like /dance)
      elseif string.sub(cmd, 1, 1) == "/" then
        local emoteToken = string.upper(string.sub(cmd, 2))
        local i = 1
        local token = getglobal("EMOTE"..i.."_TOKEN")
        while token do
          if token == emoteToken then
            DoEmote(token, args)
            return
          end
          i = i + 1
          token = getglobal("EMOTE"..i.."_TOKEN")
        end

        -- Voice Macros (like /v cheer)
        local v = 1
        local vm = getglobal("SLASH_VOICEMACRO"..v)
        while vm do
          if string.lower(vm) == cmd then
            for index, voice in ipairs(VoiceMacroList or {}) do
              local j = 1
              local token = getglobal("VOICEMACRO_"..voice..j)
              while token do
                if string.upper(token) == string.upper(args) then
                  PlayVocalCategory(index - 1)
                  return
                end
                j = j + 1
                token = getglobal("VOICEMACRO_"..voice..j)
              end
            end
          end
          v = v + 1
          vm = getglobal("SLASH_VOICEMACRO"..v)
        end

      else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444MacroBook: Unknown macro command:|r " .. line)
      end
    end
  end
end



-- Override CastSpell for macros
local original_CastSpell = CastSpell
function CastSpell(id, bookType)
    if bookType == "macro" and MacroBook_Macros[id] then
        RunMacroText(MacroBook_Macros[id].command)
        return
    end
    original_CastSpell(id, bookType)
end

-- Override PickupSpell to support "macro"
local original_PickupSpell = PickupSpell
function PickupSpell(id, bookType)
    if bookType == "macro" and MacroBook_Macros[id] then
        PickupMacro(id)
        return
    end
    original_PickupSpell(id, bookType)
end

local original_SpellButton_OnEnter = SpellButton_OnEnter
function SpellButton_OnEnter()
    local id = this:GetID() + (SPELLS_PER_PAGE * (SPELLBOOK_PAGENUMBERS[SpellBookFrame.bookType] - 1))

    if SpellBookFrame.bookType == "macro" then
        local macro = MacroBook_Macros[id]
        if macro then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(macro.name, 1.0, 0.82, 0)
            GameTooltip:AddLine(macro.command, 1, 1, 1, true)
            GameTooltip:Show()
        else
            GameTooltip:Hide()
        end
    else
        original_SpellButton_OnEnter()
    end
end

function SpellButton_OnLeave()
    GameTooltip:Hide()
end
-- Simulate cursor pickup (placeholder)
function PickupMacro(id)
    local macro = MacroBook_Macros[id]
    if not macro then return end

    DEFAULT_CHAT_FRAME:AddMessage("Picked up macro: |cffffff00"..macro.name.."|r")
    -- TODO: Register a cursor payload here if you want to drop it onto bars
    -- You could implement a custom action bar that accepts MacroBook macros
end

-- Override SpellButton_OnClick to support macro dragging/casting
local original_SpellButton_OnClick = SpellButton_OnClick
function SpellButton_OnClick(drag)
    local id = this:GetID() + (SPELLS_PER_PAGE * (SPELLBOOK_PAGENUMBERS[SpellBookFrame.bookType] - 1))
    if id > MAX_SPELLS then return end

    if SpellBookFrame.bookType == "macro" then
        if drag or IsShiftKeyDown() then
            PickupMacro(id)
        else
            CastSpell(id, "macro")
        end
    else
        original_SpellButton_OnClick(drag)
    end
end

-- Custom tab handler
function MacroBook_SelectTab(id)
    if SpellBookFrameTab1 and SpellBookFrameTab2 then
        PanelTemplates_SetTab(SpellBookFrame, id)
    end
    SpellBookFrame:SetID(id)
    SpellBookFrame.bookType = "macro"
    SpellBookFrame_Update()
end

-- Backup original spellbook update
local _OriginalSpellBookFrame_Update = SpellBookFrame_Update

function SpellBookFrame_Update()
    _OriginalSpellBookFrame_Update()

    -- Handle macro tab title/sound
    if SpellBookFrame.bookType == "macro" then
        SpellBookTitleText:SetText("Macro Book")
        PlaySound("igAbilityOpen")
    elseif SpellBookFrame.bookType == "spell" then
        SpellBookTitleText:SetText(TEXT(SPELLBOOK))
    elseif SpellBookFrame.bookType == "ability" then
        SpellBookTitleText:SetText(TEXT(ABILITIES))
    end

    if SpellBookFrame.bookType == "macro" then
        MacroBookEditorFrame:Show()
    else
        MacroBookEditorFrame:Hide()
    end


    -- Enable/Disable tab visuals
    for i = 1, 4 do
        local tab = getglobal("SpellBookFrameTab"..i)
        if tab then
            if i == PanelTemplates_GetSelectedTab(SpellBookFrame) then
                tab:Disable()
            else
                tab:Enable()
            end
        end
    end

    -- Skip rendering macros unless we're on that tab
    if SpellBookFrame.bookType ~= "macro" then return end

    local offset = (SPELLBOOK_PAGENUMBERS["macro"] - 1) * SPELLS_PER_PAGE

    for i = 1, SPELLS_PER_PAGE do
    local macro = MacroBook_Macros[i + offset]
    local button = getglobal("SpellButton" .. i)
    if not button then break end

    local icon = getglobal(button:GetName().."IconTexture")
    local nameText = getglobal(button:GetName().."SpellName")
    local subText = getglobal(button:GetName().."SubSpellName")

    if macro then
        icon:SetTexture(macro.icon)
        nameText:SetText(macro.name)
        subText:SetText("")
        button:Enable()
        button:Show()
    else
        icon:SetTexture("")
        nameText:SetText("")
        subText:SetText("")
        button:Disable()
        button:Show()

        -- Wipe any leftover spellbook data
        button.spellName = nil
        button.spellRank = nil
        button.id = nil
        button.command = nil
        button.action = nil
        button.tooltipName = nil
        button.bookType = nil
        local highlight = getglobal(button:GetName().."Highlight")
        local border = getglobal(button:GetName().."Border")

    if highlight then
        highlight:Hide()
        highlight:SetTexture("")
    end

    if border then
        border:Hide()
        border:SetTexture("")
    end
        local normal = getglobal(button:GetName().."NormalTexture")
    if normal then
        normal:SetVertexColor(1, 1, 1)
        normal:SetTexture("")
    end
    end
end
end

-- Initialize safely
function MacroBook_Init()
    DEFAULT_CHAT_FRAME:AddMessage("|cff20ff20MacroBook v0.0.1 Loaded|r")

    if SpellBookFrameTab1 and SpellBookFrameTab2 then
        PanelTemplates_SetNumTabs(SpellBookFrame, 4)
    end

    SPELLBOOK_PAGENUMBERS["macro"] = SPELLBOOK_PAGENUMBERS["macro"] or 1

    if SpellBookFrameTab4 then
        SpellBookFrameTab4:Show()
    end
end

local original_SpellButton_UpdateSelection = SpellButton_UpdateSelection
function SpellButton_UpdateSelection()
    if SpellBookFrame.bookType == "macro" then
        this:SetChecked("false") -- macros can't be "active"
        return
    end
    original_SpellButton_UpdateSelection()
end

local original_SpellButton_UpdateButton = SpellButton_UpdateButton
function SpellButton_UpdateButton()
    if not this:IsVisible() then return end

    local id = this:GetID() + (SPELLS_PER_PAGE * (SPELLBOOK_PAGENUMBERS[SpellBookFrame.bookType] - 1))

    if SpellBookFrame.bookType == "macro" then
        local macro = MacroBook_Macros[id]
        local name = this:GetName()

        local icon = getglobal(name.."IconTexture")
        local spellName = getglobal(name.."SpellName")
        local subName = getglobal(name.."SubSpellName")
        local cooldown = getglobal(name.."Cooldown")
        local highlight = getglobal(name.."Highlight")
        local normalTexture = getglobal(name.."NormalTexture")

        if macro then
            icon:SetTexture(macro.icon)
            spellName:SetText(macro.name)
            subName:SetText("")
            spellName:SetTextColor(1.0, 0.82, 0)
            icon:SetVertexColor(1.0, 1.0, 1.0)
            icon:Show()
            spellName:Show()
            subName:Hide()
            cooldown:Hide()
            highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
            this:SetChecked(false)
            normalTexture:SetVertexColor(1.0, 1.0, 1.0)
        else
            icon:Hide()
            spellName:Hide()
            subName:Hide()
            cooldown:Hide()
        end

        return
    end

    -- For all other book types
    original_SpellButton_UpdateButton()
end

function MacroBook_NewMacro()
    DEFAULT_CHAT_FRAME:AddMessage("New macro creation not yet implemented.")
end

function MacroBook_SaveMacro()
    local nameBox = getglobal("MacroBookEditorFrameNameInput")
    local bodyBox = getglobal("MacroBookEditorFrameBodyInput")

    if not nameBox or not bodyBox then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MacroBook: Editor fields not found.|r")
        return
    end

    local name = nameBox:GetText()
    local body = bodyBox:GetText()

    if name == "" or body == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000MacroBook: Name and body cannot be empty.|r")
        return
    end

    -- Add the new macro
    table.insert(MacroBook_Macros, {
        name = name,
        icon = "Interface\\Icons\\INV_MISC_QUESTIONMARK", -- placeholder
        command = body
    })

    DEFAULT_CHAT_FRAME:AddMessage("|cff20ff20MacroBook: Macro '"..name.."' saved.|r")

    -- Clear the fields
    nameBox:SetText("")
    bodyBox:SetText("")

    -- Refresh
    SpellBookFrame_Update()
end
