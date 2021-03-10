-- Version definition
VERSION = "0.0.2";

-- Utils
NORMAL_FONT_COLOR_CODE = "|cffffd200";
HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff";
RED_FONT_COLOR_CODE = "|cffff2020";
GREEN_FONT_COLOR_CODE = "|cff20ff20";
GRAY_FONT_COLOR_CODE = "|cff808080";
YELLOW_FONT_COLOR_CODE = "|cffffff00";
LIGHTYELLOW_FONT_COLOR_CODE = "|cffffff9a";
ORANGE_FONT_COLOR_CODE = "|cffff7f3f";
FONT_COLOR_CODE_CLOSE = "|r"; 

function UIPrint(text)
    ChatFrame:AddMessage(text);
end

function UIColorize(text, color)
    return color .. text .. FONT_COLOR_CODE_CLOSE
end

function UIPrintWelcomeMessage()
    UIPrint("UIOverhaul version " .. UIColorize(VERSION, GREEN_FONT_COLOR_CODE) .. " loaded.");
end
