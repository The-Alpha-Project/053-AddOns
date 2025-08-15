-- Credits: Nutrinoff

DEFAULT_CHAT_FRAME:AddMessage("|cff20ff20ExtendedStats v0.0.1 addon loaded.|r")

-- === Constants === --
local WHITE = "|cFFFFFFFF"
local HIGHLIGHT = "|cFFFFFF00"
local RESET = "|r"
local BASE_PROC_CHANCE = 0.03
local BASE_CRIT_CHANCE = 0.05
local BASE_MELEE_MISS_CHANCE = 0.05

-- === Class Stat Mappings === --
local CLASS_NAME_TO_TOKEN = {
    ["Warrior"] = "WARRIOR", ["Paladin"] = "PALADIN", ["Hunter"] = "HUNTER",
    ["Rogue"] = "ROGUE", ["Priest"] = "PRIEST", ["Shaman"] = "SHAMAN",
    ["Mage"] = "MAGE", ["Warlock"] = "WARLOCK", ["Druid"] = "DRUID"
}

local CLASS_BASE_DODGE = {
    DRUID = 0.9, MAGE = 3.2, PALADIN = 0.7,
    PRIEST = 3.0, SHAMAN = 1.7, WARLOCK = 2.0
}

local CLASS_AGI_DODGE_SCALING = {
    DRUID = {4.6, 20.0}, PALADIN = {4.6, 20.0}, SHAMAN = {4.6, 20.0},
    MAGE = {12.9, 20.0}, ROGUE = {1.1, 14.5}, HUNTER = {1.8, 26.5},
    PRIEST = {11.0, 20.0}, WARLOCK = {8.4, 20.0}, WARRIOR = {3.9, 20.0}
}

local CLASS_STRENGTH_SCALING_CRIT = {
    DRUID = {4.6, 20.0}, PALADIN = {4.6, 20.0}, SHAMAN = {4.6, 20.0},
    MAGE = {12.9, 20.0}, ROGUE = {2.2, 29.0}, HUNTER = {1.8, 26.5},
    PRIEST = {11.0, 20.0}, WARLOCK = {8.4, 20.0}, WARRIOR = {7.8, 40.0}
}

local CLASS_AGI_PROC_SCALING = CLASS_AGI_DODGE_SCALING

local CLASS_MAGIC_SCHOOLS = {
    WARRIOR = {}, ROGUE = {},
    MAGE = {"Fire", "Frost"},
    PRIEST = {"Holy", "Shadow"},
    PALADIN = {"Holy"},
    DRUID = {"Nature"},
    WARLOCK = {"Fire", "Shadow"},
    SHAMAN = {"Fire", "Frost", "Nature"}
}

local SPELL_SCHOOLS = {"Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane"}
local SKILL_CATEGORIES = {"class", "secondary", "spec", "racial", "proficiency"}

-- === Utility Functions === --
function FormatStat(base, modifier)
    local total = base + modifier
    if modifier == 0 then return tostring(base) end
    local sign = modifier > 0 and "+" or ""
    local color = modifier > 0 and "|cff20ff20" or "|cffff2020"
    return color .. total .. " (" .. base .. sign .. modifier .. ")" .. "|r"
end

local function Interpolate(v1, v60, level)
    return ((v1 * (60 - level)) + (v60 * (level - 1))) / 59
end

-- === Estimators === --
function EstimateArmorReduction(armor, level)
    local reduction = (0.3 * (armor - 1)) / (10 * level + 89)
    if reduction > 0.75 then reduction = 0.75 end
    if reduction < 0 then reduction = 0 end
    return string.format("%.2f%%", reduction * 100)
end

function EstimateDodge(agi, level, classToken, defenseSkill)
    local base = CLASS_BASE_DODGE[classToken] or 0
    local scaling = CLASS_AGI_DODGE_SCALING[classToken] or {20, 20}
    local rate = Interpolate(scaling[1], scaling[2], level)
    local bonus = agi / rate
    local diff = defenseSkill - (level * 5)
    local percent = bonus + base + diff * 0.04
    if percent > 100 then percent = 100 end
    return string.format("%.2f%%", percent)
end

function EstimateBlock(str, level, classToken, rating)
    local scaling = CLASS_AGI_DODGE_SCALING[classToken] or {20, 20}
    local rate = Interpolate(scaling[1], scaling[2], level)
    local bonus = str / rate
    local diff = rating - (level * 5)
    local percent = bonus + diff * 0.04
    if percent > 100 then percent = 100 end
    if percent < 0 then percent = 0 end
    return string.format("%.2f%%", percent)
end

function EstimateParry(defSkill, level)
    return string.format("%.2f%%", 5.0 + (defSkill - level * 5) * 0.04)
end

function EstimateProcChance(agi, level, classToken)
    local scaling = CLASS_AGI_PROC_SCALING[classToken] or {20, 20}
    local rate = Interpolate(scaling[1], scaling[2], level)
    local proc = BASE_PROC_CHANCE + (agi / rate / 100)
    if proc > 1 then proc = 1 end
    return string.format("%.2f%%", proc * 100)
end

function EstimateBlockValue(str)
    return tostring(str)
end

function EstimateCritChance(str, level, classToken, weaponSkill)
    local scaling = CLASS_STRENGTH_SCALING_CRIT[classToken] or {20, 20}
    local rate = Interpolate(scaling[1], scaling[2], level)
    local base = BASE_CRIT_CHANCE + (str / rate / 100)
    local diff = weaponSkill - (level * 5)
    local bonus = (diff < 0) and diff * 0.002 or diff * 0.0004
    local crit = base + bonus
    if crit > 1 then crit = 1 end
    if crit < 0 then crit = 0 end
    return string.format("%.2f%%", crit * 100)
end

function EstimateMissChance(level, weaponSkill)
    local diff = (level * 5) - weaponSkill
    local miss = BASE_MELEE_MISS_CHANCE + diff * 0.04
    if miss > 1 then miss = 1 end
    if miss < 0 then miss = 0 end
    return string.format("%.2f%%", miss * 100)
end

function EstimateHitChance()
    return "0.00%"
end

function EstimateSpellCritChance()
    return "5.00%"
end

function EstimateSpellResistChance()
    return EstimateSpellResistChanceBySchool(UnitLevel("player"))
end

function EstimateSpellResistChanceBySchool(level)
    local result = {}
    local classToken = CLASS_NAME_TO_TOKEN[UnitClass("player")]
    local defense = level * 5
    for i = 1, table.getn(SPELL_SCHOOLS) do
        local school = SPELL_SCHOOLS[i]
        if not CLASS_MAGIC_SCHOOLS[classToken] or IsSchoolUsedByClass(classToken, school) then
            local skill = GetSpellSchoolSkill(school) or 0
            local diff = defense - skill
            local resist = 0.04
            if diff > 0 then
                resist = resist + (diff < 75 and diff / 5 / 100 or 0.04 + ((diff / 5 / 100 - 0.02) * 7))
            end
            result[school] = string.format("%.2f%%", math.min(100, math.max(0, resist * 100)))
        else
            result[school] = "N/A"
        end
    end
    return result
end

function EstimateSpellDamage()
    return {
        Holy = "0", Fire = "0", Nature = "0",
        Frost = "0", Shadow = "0", Arcane = "0"
    }
end

function EstimateCastingSpeed()
    return "0.00%"
end

function EstimateSpellCostModifier()
    return "0.00%"
end

function EstimateManaRegen(spirit, classToken)
    local regen = 0
    if classToken == "PRIEST" then regen = spirit * 0.15
    elseif classToken == "MAGE" then regen = spirit * 0.1
    elseif classToken == "DRUID" then regen = spirit * 0.08
    elseif classToken == "PALADIN" then regen = spirit * 0.075
    elseif classToken == "SHAMAN" or classToken == "WARLOCK" then regen = spirit * 0.07
    end
    return string.format("%.2f", regen * 2.5) .. " / 5s"
end

function IsSchoolUsedByClass(classToken, school)
    local schools = CLASS_MAGIC_SCHOOLS[classToken] or {}
    for i = 1, table.getn(schools) do
        if schools[i] == school then return true end
    end
    return false
end

function ClassUsesAnyMagic(classToken)
    local schools = CLASS_MAGIC_SCHOOLS[classToken]
    return schools and table.getn(schools) > 0
end

function GetShieldSkill()
    local numPerCategory = { GetSkillLineInfo() }
    for catIndex = 1, 5 do
        local category = SKILL_CATEGORIES[catIndex]
        local count = numPerCategory[catIndex]
        for i = 1, count do
            local name, _, rank = GetSkillByIndex(category, i)
            if name == "Shields" then return rank end
        end
    end
    return nil
end
-- Continuation of Utility and Estimation Functions

function GetBlockSkill()
    local numPerCategory = { GetSkillLineInfo() }
    for catIndex = 1, 5 do
        local category = SKILL_CATEGORIES[catIndex]
        local count = numPerCategory[catIndex]
        for i = 1, count do
            local name, _, rank = GetSkillByIndex(category, i)
            if name == "Block" then return rank end
        end
    end
    return nil
end

function GetSpellSchoolSkill(schoolName)
    local numPerCategory = { GetSkillLineInfo() }
    for catIndex = 1, 5 do
        local category = SKILL_CATEGORIES[catIndex]
        local count = numPerCategory[catIndex]
        for i = 1, count do
            local name, _, rank = GetSkillByIndex(category, i)
            if name and strfind(string.lower(name), string.lower(schoolName)) then
                return rank
            end
        end
    end
    return nil
end

function GetRangedWeaponStats()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetInventoryItem("player", 18)

    local name, minDmg, maxDmg, speed, weaponType = nil, nil, nil, nil, nil

    for i = 1, 15 do
        local left = getglobal("GameTooltipTextLeft"..i)
        local right = getglobal("GameTooltipTextRight"..i)

        if i == 1 and left and left:GetText() then
            name = left:GetText()
        end

        if left and left:GetText() then
            local text = left:GetText()
            local _, _, low, high = strfind(text, "(%d+)%s?%-+%s?(%d+)%s?[Dd]amage")
            if low and high then
                minDmg = tonumber(low)
                maxDmg = tonumber(high)
            end
        end

        if right and right:GetText() then
            local rtext = right:GetText()
            if rtext == "Bow" or rtext == "Gun" or rtext == "Thrown" or rtext == "Crossbow" or rtext == "Wand" then
                weaponType = rtext
            end
            if strfind(rtext, "Speed") then
                local sub = strsub(rtext, strfind(rtext, "Speed") + 5)
                sub = gsub(sub, "[:%s]", "")
                local num = tonumber(sub)
                if num then speed = num end
            end
        end
    end

    GameTooltip:Hide()
    return minDmg, maxDmg, speed, weaponType, name
end

function HasRangedWeaponEquipped()
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetInventoryItem("player", 18)

    for i = 1, 10 do
        local left = getglobal("GameTooltipTextLeft"..i)
        if left and left:GetText() then
            local text = left:GetText()
            if strfind(text, "%d+%s?%-+%s?%d+%s?[Dd]amage") then
                GameTooltip:Hide()
                return true
            end
        end
    end

    GameTooltip:Hide()
    return false
end

function GetRangedWeaponSkill(weaponType)
    if not weaponType then return nil end

    local skillName = nil
    if weaponType == "Bow" then skillName = "Bows"
    elseif weaponType == "Gun" then skillName = "Guns"
    elseif weaponType == "Crossbow" then skillName = "Crossbows"
    elseif weaponType == "Thrown" then skillName = "Thrown"
    elseif weaponType == "Wand" then skillName = "Wands" end

    if not skillName then return nil end

    local numPerCategory = { GetSkillLineInfo() }
    for catIndex = 1, 5 do
        local category = SKILL_CATEGORIES[catIndex]
        local count = numPerCategory[catIndex]
        for i = 1, count do
            local name, _, rank = GetSkillByIndex(category, i)
            if name == skillName then return rank end
        end
    end

    return nil
end

-- Cleaned and fully Alpha-compatible version of UpdateExtendedStats
function UpdateExtendedStats()
    if not ExtendedStatsFrameText then
        DEFAULT_CHAT_FRAME:AddMessage("Frame not ready")
        return
    end

    -- General
    local className = UnitClass("player")
    local classToken = CLASS_NAME_TO_TOKEN[className] or "WARRIOR"
    local level = UnitLevel("player") or 0
    local hp = UnitHealthMax("player") or 0
    local mp = UnitManaMax("player") or 0

    -- Primary Stats
    local strBase, strMod = UnitStat("player", 1)
    local agiBase, agiMod = UnitStat("player", 2)
    local staBase, staMod = UnitStat("player", 3)
    local intBase, intMod = UnitStat("player", 4)
    local spiBase, spiMod = UnitStat("player", 5)

    local strTotal = strBase + strMod
    local agiTotal = agiBase + agiMod
    local intTotal = intBase + intMod
    local spiTotal = spiBase + spiMod

    -- Armor and Defense
    local _, baseArmor, posBuffArmor, negBuffArmor = UnitArmor("player")
    local armorText = FormatStat(baseArmor, posBuffArmor + negBuffArmor)
    local armorReductionText = EstimateArmorReduction(baseArmor + posBuffArmor + negBuffArmor, level)

    local defBase, defMod = UnitDefense("player")
    local defenseText = FormatStat(defBase, defMod)
    local defSkill = defBase + defMod

    -- Block Skill Setup
    local shieldSkill = GetShieldSkill() or (level * 5)
    local blockSkill = GetBlockSkill() or (level * 5)
    local skillForBlock = defSkill
    local showBlockSkillText = true

    if classToken == "PALADIN" then
        skillForBlock = blockSkill
    elseif classToken == "WARRIOR" then
        skillForBlock = shieldSkill
    elseif classToken == "ROGUE" or classToken == "SHAMAN" or classToken == "HUNTER" then
        skillForBlock = defSkill
        showBlockSkillText = false
    else
        skillForBlock = shieldSkill
    end

    -- Melee
    local atkBase, atkMod = UnitAttackBothHands("player")
    local attackText = FormatStat(atkBase, atkMod)
    local minDmg, maxDmg, pBonus, r1, r2, r3, r4, r5 = UnitDamage("player")
    local totalDmgBonus = pBonus + r1 + r2 + r3 + r4 + r5
    local damageText = string.format("%d - %d", minDmg + totalDmgBonus, maxDmg + totalDmgBonus)
    local mainSpeed = UnitAttackSpeed("player")
    local speedText = string.format("%.2f", mainSpeed or 0)

    local dodgeText = EstimateDodge(agiTotal, level, classToken, defSkill)
    local parryText = EstimateParry(defSkill, level)
    local blockText = EstimateBlock(strTotal, level, classToken, skillForBlock)
    local procText = EstimateProcChance(agiTotal, level, classToken)
    local blockValue = EstimateBlockValue(strTotal)
    local critText = EstimateCritChance(strTotal, level, classToken, atkBase)
    local hitBonusText = EstimateHitChance()
    local missText = EstimateMissChance(level, atkBase)

    -- Spell
    local spellCritText = EstimateSpellCritChance(intTotal)
    local spellResistText = EstimateSpellResistChance()
    local spellDmg = EstimateSpellDamage()
    local castingSpeedText = EstimateCastingSpeed()
    local spellCostModText = EstimateSpellCostModifier()
    local manaRegenText = EstimateManaRegen(spiTotal, classToken)

    -- Resistances
    local resNames = { "Holy", "Fire", "Nature", "Frost", "Shadow" }
    local resLines = {}
    for i = 1, 5 do
        local _, base = UnitResistance("player", i)
        table.insert(resLines, string.format("%s: %d", resNames[i], base))
    end

    -- Output Text Construction
    local text = ""
    text = text .. "HP: " .. hp .. "\n"
    text = text .. "MP: " .. mp .. "\n\n"

    text = text .. WHITE .. "MELEE:\n" .. RESET
    text = text .. "Attack Rating: " .. attackText .. "\n"
    text = text .. "Damage: " .. damageText .. "\n"
    text = text .. "Attack Speed: " .. speedText .. "\n"
    text = text .. "Crit Chance: " .. critText .. "\n"
    text = text .. "Hit Chance (Bonus): " .. hitBonusText .. "\n"
    text = text .. "Miss Chance: " .. missText .. "\n"
    text = text .. "Proc Chance: " .. procText .. "\n\n"

    -- Ranged
    local tooltipMin, tooltipMax, weaponSpeed = GetRangedWeaponStats()
    local hasRanged = HasRangedWeaponEquipped()
    local rangedColor = hasRanged and "" or "|cff888888"
    local rap = agiTotal * 2
    local bonusDmg = rap / 14
    local finalMin = tooltipMin and (tooltipMin + bonusDmg) or bonusDmg
    local finalMax = tooltipMax and (tooltipMax + bonusDmg) or bonusDmg
    local avgFinal = (finalMin + finalMax) / 2
    local rangedDps = weaponSpeed and (avgFinal / weaponSpeed) or 0
    local _, _, _, weaponType = GetRangedWeaponStats()
    local rangedSkill = GetRangedWeaponSkill(weaponType) or (level * 5)
    local rangedCrit = EstimateCritChance(strTotal, level, classToken, rangedSkill)
    local rangedMiss = EstimateMissChance(level, rangedSkill)
    local rangedHit = EstimateHitChance()

    text = text .. WHITE .. "RANGED:\n" .. RESET
    text = text .. rangedColor .. "Attack Rating: " .. rangedSkill .. RESET .. "\n"
    text = text .. rangedColor .. (tooltipMin and string.format("Damage: %.1f - %.1f\n", finalMin, finalMax) or "Damage: N/A\n") .. RESET
    text = text .. rangedColor .. (weaponSpeed and string.format("Attack Speed: %.2f\n", weaponSpeed) or "Attack Speed: N/A\n") .. RESET
    text = text .. rangedColor .. "Crit Chance: " .. rangedCrit .. RESET .. "\n"
    text = text .. rangedColor .. "Hit Chance (Bonus): " .. rangedHit .. RESET .. "\n"
    text = text .. rangedColor .. "Miss Chance: " .. rangedMiss .. RESET .. "\n\n"

    -- Defense
    text = text .. WHITE .. "DEFENSIVE:\n" .. RESET
    text = text .. "Armor: " .. armorText .. "\n"
    text = text .. "Armor Dmg Reduction: " .. armorReductionText .. "\n"
    text = text .. "Defense: " .. defenseText .. "\n"
    if showBlockSkillText then
        text = text .. (classToken == "PALADIN" and "Block Skill: " or "Shield Skill: ") .. skillForBlock .. "\n"
    end
    text = text .. "Dodge: " .. dodgeText .. "\n"
    text = text .. "Parry: " .. parryText .. "\n"
    text = text .. "Block: " .. blockText .. "\n"
    text = text .. "Block Value: " .. blockValue .. "\n\n"

    -- Magic
    local magicColor = ClassUsesAnyMagic(classToken) and "" or "|cff888888"
    text = text .. WHITE .. "MAGICAL:\n" .. RESET
    text = text .. magicColor .. "Spell Crit Chance: " .. spellCritText .. RESET .. "\n"
    text = text .. magicColor .. "Casting Speed: " .. castingSpeedText .. RESET .. "\n"
    text = text .. magicColor .. "Mana Regen: " .. manaRegenText .. RESET .. "\n"
    text = text .. magicColor .. "Spell Cost Modifier: " .. spellCostModText .. RESET .. "\n\n"

    -- Spell Resist
    text = text .. WHITE .. "SPELL RESIST CHANCE:\n" .. RESET
    for i = 1, table.getn(SPELL_SCHOOLS) do
        local school = SPELL_SCHOOLS[i]
        local value = spellResistText[school]
        local color = IsSchoolUsedByClass(classToken, school) and "" or "|cff888888"
        text = text .. color .. school .. " Resist Chance: " .. (value or "N/A") .. RESET .. "\n"
    end

    -- Spell Damage
    text = text .. "\n" .. WHITE .. "SPELL BONUS DAMAGE:\n" .. RESET
    for i = 1, table.getn(SPELL_SCHOOLS) do
        local school = SPELL_SCHOOLS[i]
        local value = spellDmg[school]
        local color = IsSchoolUsedByClass(classToken, school) and "" or "|cff888888"
        text = text .. color .. school .. " Damage: " .. (value or "N/A") .. RESET .. "\n"
    end

    -- Resistances
    text = text .. "\n" .. WHITE .. "RESISTANCES:\n" .. RESET
    text = text .. table.concat(resLines, "\n")

    ExtendedStatsFrameText:SetText(text)
end

SLASH_HELLOWORLD1 = "/extstats"
SlashCmdList["HELLOWORLD"] = function()
    if ExtendedStatsFrame:IsShown() then
        ExtendedStatsFrame:Hide()
    else
        UpdateExtendedStats()
        ExtendedStatsFrame:Show()
    end
end

function ExtendedStats_OnEvent(event)
    UpdateExtendedStats()
end
-- === Auto Talent Passive Scanner (runs when talent frame is opened) === --

function ExtendedStats_ScanLearnedTalents()
    if not IsTalentTrainer then return end
    if not IsTalentTrainer() then return end

    local count = GetNumTrainerServices()
    for i = 1, count do
        local name, subtext, type = GetTrainerServiceInfo(i)
        if type == "used" then
            local desc = GetTrainerServiceDescription(i)
            DEFAULT_CHAT_FRAME:AddMessage("Learned Talent: " .. name)
            if desc then
                DEFAULT_CHAT_FRAME:AddMessage("  -> " .. desc)
            end
        end
    end
end