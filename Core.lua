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
    local num = GetNumTradeSkills and GetNumTradeSkills() or 0

    local ala = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent
    if ala and ala.get_pid_by_pname then
        local pid = ala.get_pid_by_pname(profName)
        local sids = pid and ala.get_list_by_pid(pid)
        if pid and sids then
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
                        local recipeItemIDs = nil
                        if info and info[16] and type(info[16]) == "table" then
                            recipeItemIDs = {}
                            for _, rid in ipairs(info[16]) do
                                recipeItemIDs[#recipeItemIDs + 1] = rid
                            end
                        end
                        
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
                            isKnown = (IsSpellKnown and IsSpellKnown(sid)) or false,
                            index = sid,
                        }
                    end
                end
            end
            return list, profName, currentSkill, maxSkill or 450
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
    return list, profName, currentSkill, maxSkill or 450
end

local HOLIDAY_RECIPES = {
    -- 感恩节 (Pilgrim's Bounty)
    ["香料面包布丁"] = true,
    ["南瓜馅饼"] = true,
    ["酸果蔓酱"] = true,
    ["蜜汁薯块"] = true,
    ["慢烤火鸡"] = true,
    ["玉米馅料"] = true,
    ["糖心甜土豆"] = true,
    ["Spice Bread Stuffing"] = true,
    ["Pumpkin Pie"] = true,
    ["Cranberry Chutney"] = true,
    ["Candied Sweet Potato"] = true,
    ["Slow-Roasted Turkey"] = true,
    -- 冬幕节 (Winter Veil)
    ["蛋奶酒"] = true,
    ["小姜饼"] = true,
    ["热苹果酒"] = true,
    ["冬天爷爷的手套"] = true,
    ["寒冬之刃"] = true,
    ["寒冬之力"] = true,
    ["绿色节日衬衣"] = true,
    ["Egg Nog"] = true,
    ["Gingerbread Cookie"] = true,
    ["Hot Apple Cider"] = true,
}

-- Check if recipe is a holiday/seasonal recipe.
function L.IsHolidayRecipe(recipeName, profName)
    if not recipeName then return false end
    if HOLIDAY_RECIPES[recipeName] then return true end
    -- Just in case someone puts the event name in recipe name
    if recipeName:match("感恩节") or recipeName:match("冬幕节") then return true end
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
    maxSkill = maxSkill or 450
    currentSkill = currentSkill or 0
    local yellow = currentSkill + 5
    local gray = math.min(maxSkill, currentSkill + 30)
    return yellow, gray
end

-- Cost per one craft: materials (from AH or vendor).
function L.CraftCost(reagents)
    local cost = 0
    for _, r in ipairs(reagents or {}) do
        local unitPrice = L.GetItemPrice(r.itemID or r.name)
        cost = cost + (unitPrice or 0) * (r.count or 0)
    end
    return cost
end

-- Return total quantity of item on AH at scan time (0 if not scanned or not on AH).
function L.GetAHQuantity(itemId)
    if not itemId then return 0 end
    local db = ProfLevelHelperDB
    if not db or not db.AHQty then return 0 end
    return db.AHQty[itemId] or 0
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

-- Calculate global cheapest route using Dynamic Programming (Shortest Path)
function L.CalculateLevelingRoute(targetStart, targetEnd, includeHoliday)
    local recipes, profName, currentSkill, pMaxSkill = L.GetRecipeList(includeHoliday)
    if not recipes or #recipes == 0 then return nil, profName, currentSkill, currentSkill, 0 end

    targetStart = targetStart or currentSkill
    targetEnd = targetEnd or pMaxSkill
    L.Print(string.format("计算路线: %d -> %d (%s)", targetStart, targetEnd, tostring(profName)))
    if targetStart >= targetEnd then 
        L.Print("错误: 起点等级已大于或等于终点等级。")
        return nil, profName, targetStart, targetEnd, 0 
    end
    
    -- DP array storing min cost to reach a specific skill point
    local dp = {}
    local path = {} -- path[skill] = { prevSkill = S, cost = C, recipe = R, crafts = N, matCost = M, recCost = RC }
    
    for s = targetStart, targetEnd do
        dp[s] = 99999999999 -- effectively infinity
    end
    dp[targetStart] = 0
    
    -- Pre-calculate material and acquisition costs to save time, and apply source filters
    local filteredRecipes = {}
    for _, rec in ipairs(recipes) do
        rec.matCost = L.CraftCost(rec.reagents)
        -- Trainer cost discount handles 0.9 inside RecipeCost if we had reputation logic, 
        -- but here user requested a flat 0.9 reputation discount for trainers.
        local rCost, rSource = ProfLevelHelper.GetRecipeAcquisitionCost(rec)
        rCost = rCost or 0
        if rec.isTrainer and rCost > 0 and rCost == rec.trainPrice then
            rCost = math.floor(rCost * 0.9)
        end
        rec.acqCost = rCost
        rec.acqSource = rSource or "未知来源"
        
        local allowed = true
        local db = ProfLevelHelperDB
        if not rec.isKnown then
            if rec.acqSource == "训练师学习" and db.IncludeSourceTrainer == false then allowed = false end
            if rec.acqSource == "拍卖行购买" and db.IncludeSourceAH == false then allowed = false end
            if rec.acqSource == "NPC 购买" and db.IncludeSourceVendor == false then allowed = false end
            if rec.acqSource:match("任务") and db.IncludeSourceQuest == false then allowed = false end
            if (rec.acqSource == "需打怪或购买(价格未知)" or rec.acqSource == "未知来源" or rec.acqSource:match("打怪掉落")) and db.IncludeSourceUnknown == false then allowed = false end
        end
        -- Exclude recipe if any material has no price in our data (would be treated as 0 and wrongly recommended).
        if allowed then
            for _, r in ipairs(rec.reagents or {}) do
                local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
                if not id then
                    allowed = false
                    break
                end
                local hasPrice = (db.AHPrices and db.AHPrices[id]) or (db.VendorPrices and db.VendorPrices[id])
                if not hasPrice then
                    allowed = false
                    break
                end
            end
        end
        -- Exclude recipe if any material we price from AH has AH quantity below minimum.
        local minQty = (db.MinAHQuantity and db.MinAHQuantity > 0) and db.MinAHQuantity or 0
        if allowed and minQty > 0 and db.AHPrices and db.AHQty and next(db.AHQty) then
            for _, r in ipairs(rec.reagents or {}) do
                local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
                if id and db.AHPrices[id] and (db.AHQty[id] or 0) < minQty then
                    allowed = false
                    break
                end
            end
        end

        if allowed then
            table.insert(filteredRecipes, rec)
        end
    end
    recipes = filteredRecipes
    L.Print("过滤后可用配方数量: " .. #recipes)
    
    -- Find shortest path using Bellman-Ford like DP logic across skill levels
    for currentPoint = targetStart, targetEnd - 1 do
        if dp[currentPoint] < 99999999999 then
            -- We track which recipes have had their acquisition cost paid in this DP branch.
            -- A true Dijkstra with full state would require a bitmask of learned recipes, which is too huge.
            -- Heuristic: Assume the user buys the recipe exactly once when they craft it for the first time *in this step*.
            for _, rec in ipairs(recipes) do
                local learnSkill = rec.learn or 1
                local yellow, gray = rec.yellow, rec.grey
                if not yellow or not gray then
                    yellow, gray = L.GetRecipeThresholds(rec.name, profName, currentPoint)
                end
                
                -- Check if we can craft it at all at 'currentPoint'
                if currentPoint >= learnSkill and currentPoint < gray then
                    local chance = L.CalcSkillUpChance(gray, yellow, currentPoint)
                    if chance <= 0 and rec.skillType and rec.skillType ~= "trivial" and rec.skillType ~= "difficult" then
                        if rec.skillType == "optimal" then chance = 1
                        elseif rec.skillType == "easy" then chance = 0.6
                        elseif rec.skillType == "medium" then chance = 0.3
                        end
                    end
                    if rec.skillType == "trivial" or rec.skillType == "difficult" then chance = 0 end
                    
                    if chance > 0 then
                        -- Expected crafts to gain 1 skill point
                        local expectedCrafts = 1 / chance
                        local stepCost = rec.matCost * expectedCrafts
                        
                        -- If the recipe from the previous step is different, we add the acquisition cost. 
                        -- It's an approximation but avoids exponential state complexity.
                        local isNewRecipe = true
                        if path[currentPoint] and path[currentPoint].recipe.name == rec.name then
                            isNewRecipe = false
                        end
                        
                        local additionalRecCost = 0
                        local recSource = rec.acqSource
                        if isNewRecipe and not rec.isKnown then
                            additionalRecCost = rec.acqCost
                        end
                        
                        local nextPoint = currentPoint + 1
                        local newTotalCost = dp[currentPoint] + stepCost + additionalRecCost
                        
                        if newTotalCost < dp[nextPoint] then
                            dp[nextPoint] = newTotalCost
                            path[nextPoint] = {
                                prevSkill = currentPoint,
                                stepTotalCost = stepCost + additionalRecCost,
                                recipe = rec,
                                crafts = expectedCrafts,
                                matCost = stepCost,
                                recCost = additionalRecCost,
                                recSource = recSource
                            }
                        end
                    end
                end
            end
        end
    end
    
    if dp[targetEnd] >= 99999999999 then
        local maxReached = targetStart
        for s = targetStart, targetEnd do
            if dp[s] < 99999999999 then maxReached = s end
        end
        L.Print(string.format("错误: 算法在等级 %d 处中断，无法到达 %d。请检查此时是否缺少可用的后续配方。", maxReached, targetEnd))
        return nil, profName, targetStart, targetEnd, 0 -- Unreachable
    end
    
    -- Reconstruct the route by backtracking
    local route = {}
    local curr = targetEnd
    while curr > targetStart do
        local step = path[curr]
        if not step then break end
        table.insert(route, 1, {
            skillReached = curr,
            prevSkill = step.prevSkill,
            recipe = step.recipe,
            crafts = step.crafts,
            matCost = step.matCost,
            recCost = step.recCost,
            recSource = step.recSource,
            stepTotalCost = step.stepTotalCost
        })
        curr = step.prevSkill
    end
    
    -- Consolidate contiguous steps using the same recipe into larger segments
    local consolidatedRoute = {}
    local currentSegment = nil
    
    for i, step in ipairs(route) do
        if not currentSegment then
            currentSegment = {
                startSkill = step.prevSkill,
                endSkill = step.skillReached,
                recipe = step.recipe,
                totalCrafts = step.crafts,
                totalMatCost = step.matCost,
                totalRecCost = step.recCost,
                recSource = step.recSource,
                segmentTotalCost = step.stepTotalCost
            }
        elseif currentSegment.recipe.name == step.recipe.name then
            currentSegment.endSkill = step.skillReached
            currentSegment.totalCrafts = currentSegment.totalCrafts + step.crafts
            currentSegment.totalMatCost = currentSegment.totalMatCost + step.matCost
            currentSegment.totalRecCost = currentSegment.totalRecCost + step.recCost
            currentSegment.segmentTotalCost = currentSegment.segmentTotalCost + step.stepTotalCost
        else
            table.insert(consolidatedRoute, currentSegment)
            currentSegment = {
                startSkill = step.prevSkill,
                endSkill = step.skillReached,
                recipe = step.recipe,
                totalCrafts = step.crafts,
                totalMatCost = step.matCost,
                totalRecCost = step.recCost,
                recSource = step.recSource,
                segmentTotalCost = step.stepTotalCost
            }
        end
    end
    if currentSegment then
        table.insert(consolidatedRoute, currentSegment)
    end
    
    return consolidatedRoute, profName, targetStart, targetEnd, dp[targetEnd]
end
