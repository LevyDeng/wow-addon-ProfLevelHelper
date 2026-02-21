--[[
  Core: skill-up formula, recipe iteration, cost per skill point.
  chance = (graySkill - playerSkill) / (graySkill - yellowSkill), clamped [0,1].
  Orange (playerSkill < yellow) = 100%, Gray (playerSkill >= gray) = 0%.
]]

local L = ProfLevelHelper

-- Skill-up chance: (G - X) / (G - Y), clamp to [0, 1]. Orange = 1, Gray = 0.
function L.CalcSkillUpChance(graySkill, yellowSkill, playerSkill)
    if not graySkill or not yellowSkill or playerSkill == nil then return 0 end
    if playerSkill >= graySkill then return 0 end
    if playerSkill < yellowSkill then return 1 end
    if graySkill <= yellowSkill then return 1 end
    local chance = (graySkill - playerSkill) / (graySkill - yellowSkill)
    return math.max(0, math.min(1, chance))
end

-- Get profession name and current skill (when tradeskill frame is open).
function L.GetCurrentProfessionSkill()
    if not GetTradeSkillLine then return nil, 0, 0 end
    local name, _, current, max = GetTradeSkillLine()
    if not name or name == "" then return nil, 0, 0 end
    return name, current, max
end

-- Build list of recipes for current profession. Optional filter: includeHoliday.
-- Returns array of { name, index, skillType, numSkillUps, reagents, recipeLink }.
-- Recipe thresholds (yellow/gray) come from data or fallback from skillType.
function L.GetRecipeList(includeHoliday)
    if not GetNumTradeSkills then
        LoadAddOn("Blizzard_TradeSkillUI")
    end
    local profName, currentSkill = L.GetCurrentProfessionSkill()
    if not profName then return nil, "Open profession window first" end
    includeHoliday = includeHoliday == nil and ProfLevelHelperDB.IncludeHolidayRecipes or includeHoliday

    local list = {}
    local num = GetNumTradeSkills and GetNumTradeSkills() or 0
    for i = 1, num do
        local name, skillType, numAvailable, _, _, numSkillUps = GetTradeSkillInfo(i)
        if name and skillType and skillType ~= "header" and name ~= "Other" then
            -- Optional: skip holiday recipes (can be marked in data later)
            if includeHoliday or not L.IsHolidayRecipe(name, profName) then
                local reagents = {}
                local numReagents = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0
                for r = 1, numReagents do
                    local rName, _, rCount, rHave = GetTradeSkillReagentInfo(i, r)
                    if rName and rName ~= "" then
                        reagents[#reagents + 1] = { name = rName, count = rCount, have = rHave }
                    end
                end
                local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i) or nil
                list[#list + 1] = {
                    name = name,
                    index = i,
                    skillType = skillType,
                    numSkillUps = numSkillUps,
                    reagents = reagents,
                    recipeLink = link,
                }
            end
        end
    end
    return list, profName, currentSkill
end

-- Placeholder: mark holiday/seasonal recipes (extend with data later).
function L.IsHolidayRecipe(recipeName, profName)
    -- Optional: ProfLevelHelperDB.HolidayRecipes[profName][recipeName] or pattern match
    return false
end

-- Get yellow/gray skill levels for a recipe. Uses static data if available, else approximates from skillType.
function L.GetRecipeThresholds(recipeName, profName, currentSkill)
    local data = ProfLevelHelper.RecipeThresholds and ProfLevelHelper.RecipeThresholds[profName]
        and ProfLevelHelper.RecipeThresholds[profName][recipeName]
    if data and data.yellow and data.gray then
        return data.yellow, data.gray
    end
    -- Fallback: no static data - use approximate range so formula gives reasonable chance.
    local _, _, maxSkill = L.GetCurrentProfessionSkill()
    maxSkill = maxSkill or 300
    currentSkill = currentSkill or 0
    local yellow = currentSkill + 5
    local gray = math.min(maxSkill, currentSkill + 30)
    return yellow, gray
end

-- Cost per one craft: materials (from AH or vendor) + recipe acquisition (once per recipe).
-- recipeAcquisitionCost is passed from RecipeCost module (min of AH/vendor/trainer).
function L.CraftCost(reagents, recipeAcquisitionCost, oneTimeRecipeCost)
    local cost = oneTimeRecipeCost or 0
    for _, r in ipairs(reagents or {}) do
        local unitPrice = L.GetItemPrice(r.name)
        cost = cost + (unitPrice or 0) * (r.count or 0)
    end
    return cost
end

-- Resolve item name to price: AH (scanned) then vendor. Returns copper.
function L.GetItemPrice(itemNameOrLink)
    local id = type(itemNameOrLink) == "number" and itemNameOrLink or nil
    if not id and type(itemNameOrLink) == "string" then
        id = tonumber(itemNameOrLink:match("item:(%d+)"))
        if not id and ProfLevelHelperDB.NameToID then
            id = ProfLevelHelperDB.NameToID[itemNameOrLink]
        end
    end
    if id and ProfLevelHelperDB.AHPrices and ProfLevelHelperDB.AHPrices[id] then
        return ProfLevelHelperDB.AHPrices[id]
    end
    if id and ProfLevelHelperDB.VendorPrices and ProfLevelHelperDB.VendorPrices[id] then
        return ProfLevelHelperDB.VendorPrices[id]
    end
    -- Fallback: GetItemInfo vendor price (sell price; buy often higher - use as hint)
    if id then
        local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(id)
        if vendorPrice and vendorPrice > 0 then
            return vendorPrice
        end
    end
    return nil
end

-- Build leveling table: for each recipe, expected cost per skill point at current skill.
function L.BuildLevelingTable(includeHoliday)
    local recipes, profName, currentSkill = L.GetRecipeList(includeHoliday)
    if not recipes or #recipes == 0 then return nil, profName, currentSkill end

    local result = {}
    for _, rec in ipairs(recipes) do
        local yellow, gray = L.GetRecipeThresholds(rec.name, profName, currentSkill)
        local chance = L.CalcSkillUpChance(gray, yellow, currentSkill)
        -- Fallback when no threshold data: use skillType (optimal=100%, easy~60%, medium~30%, trivial/difficult=0%)
        if chance <= 0 and rec.skillType and rec.skillType ~= "trivial" and rec.skillType ~= "difficult" then
            if rec.skillType == "optimal" then chance = 1
            elseif rec.skillType == "easy" then chance = 0.6
            elseif rec.skillType == "medium" then chance = 0.3
            end
        end
        if rec.skillType == "trivial" or rec.skillType == "difficult" then chance = 0 end
        if chance <= 0 then goto continue end

        local recipeCost = ProfLevelHelper.GetRecipeAcquisitionCost(rec)
        local matCost = L.CraftCost(rec.reagents, nil, 0)
        local totalPerCraft = matCost
        local expectedCrafts = chance > 0 and (1 / chance) or 999
        local costPerSkillPoint = totalPerCraft * expectedCrafts
        -- Amortize one-time recipe cost over expected crafts for this recipe's skill range (simplified: over 1 skillup).
        costPerSkillPoint = costPerSkillPoint + (recipeCost or 0)

        result[#result + 1] = {
            name = rec.name,
            index = rec.index,
            chance = chance,
            matCost = matCost,
            recipeCost = recipeCost or 0,
            costPerSkillPoint = costPerSkillPoint,
            reagents = rec.reagents,
        }
        ::continue::
    end
    table.sort(result, function(a, b) return (a.costPerSkillPoint or 999999) < (b.costPerSkillPoint or 999999) end)
    return result, profName, currentSkill
end
