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
    local name, current, max = GetTradeSkillLine()
    if not name or name == "" then return nil, 0, 0 end
    return name, current, max
end

-- Build list of recipes for current profession. Optional filter: includeHoliday.
function L.GetRecipeList(includeHoliday)
    if not GetNumTradeSkills then
        LoadAddOn("Blizzard_TradeSkillUI")
    end
    local profName, currentSkill, maxSkill = L.GetCurrentProfessionSkill()
    if not profName then return nil, "请先打开专业技能窗口" end
    includeHoliday = includeHoliday == nil and ProfLevelHelperDB.IncludeHolidayRecipes or includeHoliday

    local list = {}
    local knownRecipes = {}
    local num = GetNumTradeSkills and GetNumTradeSkills() or 0
    for i = 1, num do
        local name = GetTradeSkillInfo(i)
        if name then knownRecipes[name] = true end
    end

    local ala = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent
    if ala and ala.get_pid_by_pname then
        local pid = ala.get_pid_by_pname(profName)
        if pid then
            local sids = ala.get_list_by_pid(pid)
            if sids then
                for _, sid in ipairs(sids) do
                    local name = GetSpellInfo(sid)
                    if name and (includeHoliday or not L.IsHolidayRecipe(name, profName)) then
                        local learn, yellow, green, grey = ala.get_difficulty_rank_list_by_sid(sid)
                        local r_ids, r_counts = ala.get_reagents_by_sid(sid)
                        local info = ala.get_info_by_sid(sid)
                        
                        if learn and grey then
                            local reagents = {}
                            if r_ids and r_counts then
                                for idx, rid in ipairs(r_ids) do
                                    local rCount = r_counts[idx] or 1
                                    reagents[#reagents + 1] = { itemID = rid, count = rCount }
                                end
                            end
                            
                            local isTrainer = info and info[14]
                            local trainPrice = info and info[15]
                            local recipeItemIDs = info and info[16]
                            
                            list[#list + 1] = {
                                name = name,
                                sid = sid,
                                learn = learn,
                                yellow = yellow,
                                green = green,
                                grey = grey,
                                reagents = reagents,
                                isTrainer = isTrainer,
                                trainPrice = trainPrice,
                                recipeItemIDs = recipeItemIDs,
                                isKnown = knownRecipes[name] or false,
                                index = sid,
                            }
                        end
                    end
                end
                return list, profName, currentSkill
            end
        end
    end

    -- Fallback to native scan
    for i = 1, num do
        local name, skillType, numAvailable, _, _, numSkillUps = GetTradeSkillInfo(i)
        if name and skillType and skillType ~= "header" and name ~= "Other" then
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
                    isKnown = true,
                }
            end
        end
    end
    return list, profName, currentSkill
end

-- Placeholder: mark holiday/seasonal recipes.
function L.IsHolidayRecipe(recipeName, profName)
    return false
end

-- Get yellow/gray skill levels for a recipe. Uses static data if available, else approximates.
function L.GetRecipeThresholds(recipeName, profName, currentSkill)
    local data = ProfLevelHelper.RecipeThresholds and ProfLevelHelper.RecipeThresholds[profName]
        and ProfLevelHelper.RecipeThresholds[profName][recipeName]
    if data and data.yellow and data.gray then
        return data.yellow, data.gray
    end
    local _, _, maxSkill = L.GetCurrentProfessionSkill()
    maxSkill = maxSkill or 300
    currentSkill = currentSkill or 0
    local yellow = currentSkill + 5
    local gray = math.min(maxSkill, currentSkill + 30)
    return yellow, gray
end

-- Cost per one craft: materials (from AH or vendor) + recipe acquisition (once per recipe).
function L.CraftCost(reagents)
    local cost = 0
    for _, r in ipairs(reagents or {}) do
        local unitPrice = L.GetItemPrice(r.itemID or r.name)
        cost = cost + (unitPrice or 0) * (r.count or 0)
    end
    return cost
end

-- Resolve item name or id to price: AH then vendor. Returns copper.
function L.GetItemPrice(itemNameOrLinkOrId)
    local id = type(itemNameOrLinkOrId) == "number" and itemNameOrLinkOrId or nil
    if type(itemNameOrLinkOrId) == "string" then
        if not id then
            id = tonumber(itemNameOrLinkOrId:match("item:(%d+)"))
        end
        if not id and ProfLevelHelperDB.NameToID then
            id = ProfLevelHelperDB.NameToID[itemNameOrLinkOrId]
        end
    end
    if id and ProfLevelHelperDB.AHPrices and ProfLevelHelperDB.AHPrices[id] then
        return ProfLevelHelperDB.AHPrices[id]
    end
    if id and ProfLevelHelperDB.VendorPrices and ProfLevelHelperDB.VendorPrices[id] then
        return ProfLevelHelperDB.VendorPrices[id]
    end
    -- Fallback: GetItemInfo vendor price (sell price; buy often roughly 4x higher)
    if id then
        local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(id)
        if vendorPrice and vendorPrice > 0 then
            return vendorPrice * 4
        end
    end
    return 0 -- Failed to calculate
end

-- Build leveling table
function L.BuildLevelingTable(includeHoliday)
    local recipes, profName, currentSkill = L.GetRecipeList(includeHoliday)
    if not recipes or #recipes == 0 then return nil, profName, currentSkill end

    local result = {}
    for _, rec in ipairs(recipes) do
        local canProcess = true
        if rec.learn and currentSkill < rec.learn then 
            canProcess = false 
        end

        if canProcess then
            local yellow, gray = rec.yellow, rec.grey
            if not yellow or not gray then
                yellow, gray = L.GetRecipeThresholds(rec.name, profName, currentSkill)
            end
            
            local chance = L.CalcSkillUpChance(gray, yellow, currentSkill)
            if chance <= 0 and rec.skillType and rec.skillType ~= "trivial" and rec.skillType ~= "difficult" then
                if rec.skillType == "optimal" then chance = 1
                elseif rec.skillType == "easy" then chance = 0.6
                elseif rec.skillType == "medium" then chance = 0.3
                end
            end
            if rec.skillType == "trivial" or rec.skillType == "difficult" then chance = 0 end
            
            if chance > 0 then
                local recipeCost = ProfLevelHelper.GetRecipeAcquisitionCost(rec)
                if rec.isKnown or recipeCost ~= nil then
                    local matCost = L.CraftCost(rec.reagents)
                    local totalPerCraft = matCost
                    local expectedCrafts = chance > 0 and (1 / chance) or 999
                    local costPerSkillPoint = totalPerCraft * expectedCrafts
                    costPerSkillPoint = costPerSkillPoint + (recipeCost or 0)

                    result[#result + 1] = {
                        name = rec.name,
                        index = rec.index,
                        chance = chance,
                        matCost = matCost,
                        recipeCost = recipeCost or 0,
                        costPerSkillPoint = costPerSkillPoint,
                        reagents = rec.reagents,
                        isKnown = rec.isKnown,
                    }
                end
            end
        end
    end
    table.sort(result, function(a, b) return (a.costPerSkillPoint or 999999) < (b.costPerSkillPoint or 999999) end)
    return result, profName, currentSkill
end
