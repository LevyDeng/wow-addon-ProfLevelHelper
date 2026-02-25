--[[
  Core: skill-up formula, recipe iteration, cost per skill point.
  chance = (graySkill - playerSkill) / (graySkill - yellowSkill), clamped [0,1].
  Orange (playerSkill < yellow) = 100%, Gray (playerSkill >= gray) = 0%.
]]

local L = ProfLevelHelper
local EFF_COST_UNKNOWN = 999999999
-- AH cut: player receives 95% of listing price (5% tax).
local AH_TAX_FACTOR = 0.95

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
                        local createdItemID = info and info[5]
                        local numMadeMin = info and info[10] or 1
                        local numMadeMax = info and info[11] or 1
                        local numMade = (type(numMadeMin) == "number" and type(numMadeMax) == "number") and ((numMadeMin + numMadeMax) / 2) or 1
                        if numMade <= 0 then numMade = 1 end

                        local recipeName = name
                        if recipeItemIDs and recipeItemIDs[1] then
                            local rid = recipeItemIDs[1]
                            local db = ProfLevelHelperDB
                            if db and db.IDToName and db.IDToName[rid] then
                                recipeName = db.IDToName[rid]
                            elseif GetItemInfo then
                                local rn = GetItemInfo(rid)
                                if rn and rn ~= "" then recipeName = rn end
                            end
                        end

                        list[#list + 1] = {
                            name = name,
                            recipeName = recipeName,
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
                            createdItemID = createdItemID,
                            numMade = numMade,
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
                local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i) or nil
                local createdItemID = nil
                if itemLink and type(itemLink) == "string" then
                    createdItemID = tonumber(itemLink:match("item:(%d+)"))
                end
                local numMade = 1
                if GetTradeSkillNumMade then
                    local nMin, nMax = GetTradeSkillNumMade(i)
                    if nMin and nMax then numMade = (nMin + nMax) / 2 elseif nMin then numMade = nMin end
                    if numMade <= 0 then numMade = 1 end
                end
                local recipeName = name
                if link and type(link) == "string" then
                    local rid = tonumber(link:match("item:(%d+)"))
                    if rid then
                        local db = ProfLevelHelperDB
                        if db and db.IDToName and db.IDToName[rid] then
                            recipeName = db.IDToName[rid]
                        elseif GetItemInfo then
                            local rn = GetItemInfo(rid)
                            if rn and rn ~= "" then recipeName = rn end
                        end
                    end
                end
                list[#list + 1] = {
                    name = name,
                    recipeName = recipeName,
                    index = i,
                    skillType = skillType,
                    numSkillUps = numSkillUps,
                    reagents = reagents,
                    recipeLink = link,
                    isKnown = true,
                    createdItemID = createdItemID,
                    numMade = numMade,
                }
            end
        end
    end
    return list, profName, currentSkill, maxSkill or 450
end

-- Preload item data for a list of item IDs using async ContinueOnItemLoad.
-- Calls callback() once every uncached item finishes loading, or after timeout seconds.
-- If all items are already cached, callback is called on the next frame.
function L.EnsureItemsLoaded(itemIDs, callback, timeout)
    if not itemIDs or #itemIDs == 0 then
        callback()
        return
    end
    local pending = 0
    local done = false
    local function finish()
        if not done then
            done = true
            callback()
        end
    end
    for _, id in ipairs(itemIDs) do
        if GetItemInfo(id) == nil then
            if Item and Item.CreateFromItemID then
                pending = pending + 1
                local item = Item:CreateFromItemID(id)
                item:ContinueOnItemLoad(function()
                    pending = pending - 1
                    if pending <= 0 then finish() end
                end)
            end
        end
    end
    if pending <= 0 then
        -- All already cached; defer one frame so the call is always async.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, finish)
        else
            finish()
        end
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(timeout or 3.0, finish)
    end
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

-- Debug: print learn/yellow/grey for 辣味狼排 and nearby recipes. Run with /plh testlearn (open profession first).
function L.TestRecipeLearnLevels()
    local profName, currentSkill, maxSkill = L.GetCurrentProfessionSkill()
    if not profName then
        L.Print("请先打开专业技能窗口后再执行 /plh testlearn")
        return
    end
    L.Print("--- Recipe learn level test (prof: " .. profName .. ") ---")

    local ala = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent
    if not ala or not ala.get_pid_by_pname or not ala.get_list_by_pid or not ala.get_difficulty_rank_list_by_sid then
        L.Print("ala DataAgent not available - recipe data comes from game UI fallback (no learn/yellow/grey).")
    else
        local pid = ala.get_pid_by_pname(profName)
        local sids = pid and ala.get_list_by_pid(pid)
        if not sids then
            L.Print("ala: no spell list for this profession.")
        else
            -- Raw ala: find 辣味狼排 by spell name and print what ala returns
            for _, sid in ipairs(sids) do
                local name = GetSpellInfo(sid)
                if name == "辣味狼排" then
                    local learn, yellow, green, grey = ala.get_difficulty_rank_list_by_sid(sid)
                    L.Print("[ala raw] 辣味狼排 sid=" .. tostring(sid) .. " learn=" .. tostring(learn) .. " yellow=" .. tostring(yellow) .. " green=" .. tostring(green) .. " grey=" .. tostring(grey))
                    break
                end
            end
            -- List all recipes with learn in 170..260 for context
            L.Print("[ala] Recipes with learn in 170-260:")
            for _, sid in ipairs(sids) do
                local name = GetSpellInfo(sid)
                if name then
                    local learn, yellow, green, grey = ala.get_difficulty_rank_list_by_sid(sid)
                    if learn and learn >= 170 and learn <= 260 then
                        L.Print("  learn=" .. tostring(learn) .. " yellow=" .. tostring(yellow) .. " grey=" .. tostring(grey) .. " | " .. tostring(name))
                    end
                end
            end
        end
    end

    -- What we actually use (from GetRecipeList)
    local recipes = L.GetRecipeList(ProfLevelHelperDB and ProfLevelHelperDB.IncludeHolidayRecipes)
    if not recipes then
        L.Print("GetRecipeList returned nil.")
        return
    end
    local db = ProfLevelHelperDB or {}
    local found = false
    for _, rec in ipairs(recipes) do
        if rec.name == "辣味狼排" then
            found = true
            local effective = (db.RecipeLearnOverrides and db.RecipeLearnOverrides[rec.name]) and db.RecipeLearnOverrides[rec.name] or rec.learn or 1
            L.Print("[ProfLevelHelper] 辣味狼排 rec.learn=" .. tostring(rec.learn) .. " yellow=" .. tostring(rec.yellow) .. " grey=" .. tostring(rec.grey) .. " -> effective learnSkill=" .. tostring(effective))
            break
        end
    end
    if not found then
        L.Print("[ProfLevelHelper] 辣味狼排 not in filtered recipe list (may be filtered out by source/material).")
    end
    L.Print("--- end test ---")
end

-- Debug: at a given skill level, print per-craft cost and per-skill-point cost for each valid recipe. Run /plh testcost [skill], default 175.
function L.TestCostAtSkill(skill)
    skill = tonumber(skill) or 175
    local recipes, profName = L.GetRecipeList(ProfLevelHelperDB and ProfLevelHelperDB.IncludeHolidayRecipes)
    if not recipes or #recipes == 0 then
        L.Print("请先打开专业技能窗口（点开烹饪等专业）后再执行 /plh testcost " .. skill)
        return
    end
    local db = ProfLevelHelperDB or {}
    local effectiveCost = L.ComputeEffectiveMaterialCosts(recipes)
    for _, rec in ipairs(recipes) do
        rec.matCost = L.CraftCostWithEffective(rec.reagents, effectiveCost)
        rec.sellPricePerItem = 0
        rec.ahPricePerItem = 0
        if rec.createdItemID and GetItemInfo then
            local _, _, _, _, _, _, _, _, _, _, vp = GetItemInfo(rec.createdItemID)
            if vp and vp > 0 then rec.sellPricePerItem = vp end
        end
        if rec.createdItemID then
            rec.ahPricePerItem = L.GetSellBackValueWhenUsingAH(rec, db) or 0
        end
    end
    local filteredRecipes = {}
    for _, rec in ipairs(recipes) do
        local allowed = true
        for _, r in ipairs(rec.reagents or {}) do
            local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
            if not id then allowed = false break end
            local c = effectiveCost[id]
            if not c or c >= EFF_COST_UNKNOWN then allowed = false break end
        end
        if allowed then filteredRecipes[#filteredRecipes + 1] = rec end
    end
    L.Print("--- Cost at skill " .. skill .. " (" .. profName .. ", " .. #filteredRecipes .. " recipes) ---")
    for _, rec in ipairs(filteredRecipes) do
        local learnSkill = (db.RecipeLearnOverrides and db.RecipeLearnOverrides[rec.name]) and db.RecipeLearnOverrides[rec.name] or rec.learn or 1
        local yellow, gray = rec.yellow, rec.grey
        if not yellow or not gray then
            yellow, gray = L.GetRecipeThresholds(rec.name, profName, skill)
        end
        if skill >= learnSkill and skill < gray then
            local chance = L.CalcSkillUpChance(gray, yellow, skill)
            if chance > 0 then
                local expectedCrafts = 1 / chance
                local numMade = rec.numMade or 1
                local sellBackVendor = (rec.sellPricePerItem or 0) * numMade * expectedCrafts
                local sellBackAH = (rec.ahPricePerItem or 0) * AH_TAX_FACTOR * numMade * expectedCrafts
                local useAH = (db.SellBackMethod == "ah" and not (db.AHSellBackBlacklist and db.AHSellBackBlacklist[rec.createdItemID])) or (db.SellBackMethod == "vendor" and ((db.AHSellBackWhitelist and db.AHSellBackWhitelist[rec.createdItemID]) or (db.UseDisenchantRecovery and L.IsDisenchantable(rec.createdItemID))))
                local bestSb = (db.UseDisenchantRecovery and L.GetBestSellBackPerItem(rec, db)) or nil
                local sellBack = (bestSb and bestSb > 0) and (bestSb * numMade * expectedCrafts) or (useAH and sellBackAH or sellBackVendor)
                local matGross = rec.matCost * expectedCrafts
                local stepCost = matGross - sellBack
                local matPerCraft = rec.matCost
                local sellPerCraft = (bestSb and bestSb > 0) and (bestSb * numMade) or ((useAH and (rec.ahPricePerItem or 0) * AH_TAX_FACTOR or (rec.sellPricePerItem or 0)) * numMade)
                L.Print(string.format("  %s | 单次: 材料%d铜 回血%d铜 净%d铜 | 升1级: 期望%.2f次 净花费%d铜", rec.name, matPerCraft, sellPerCraft, matPerCraft - sellPerCraft, expectedCrafts, stepCost))
            end
        end
    end
    L.Print("--- end testcost ---")
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

-- Warn once per session for disenchant-related issues.
local DEWarned = {}
local function WarnOnce(key, msg)
    if not DEWarned[key] then
        DEWarned[key] = true
        L.Print(msg)
    end
end

-- Get disenchant value (copper, after 5% AH tax) and breakdown using Auctionator.Enchant.GetDisenchantBreakdown + our AHPrices.
-- Returns: value (number or nil), breakdown (array of { name, expectedQty, itemID }), err (string or nil: "no_auctionator", "no_api", "no_item", "no_breakdown").
function L.GetDisenchantValueAndBreakdown(itemID)
    local db = ProfLevelHelperDB
    if not db or not itemID then return nil, nil, "no_item" end
    if not Auctionator or not Auctionator.Enchant then
        WarnOnce("no_auctionator", "分解回血需要 Auctionator 插件，请先启用。")
        return nil, nil, "no_auctionator"
    end
    if type(Auctionator.Enchant.GetDisenchantBreakdown) ~= "function" then
        WarnOnce("no_api", "无法获取分解明细（Auctionator 接口不可用），请更新 Auctionator。")
        return nil, nil, "no_api"
    end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return nil, nil, "no_item" end
    local itemInfo = { getInfo(itemID) }
    if not itemInfo or not itemInfo[1] or not itemInfo[2] then
        return nil, nil, "no_item"
    end
    local itemLink = itemInfo[2]
    local results = Auctionator.Enchant.GetDisenchantBreakdown(itemLink, itemInfo)
    if not results or type(results) ~= "table" then
        WarnOnce("no_api", "无法获取分解明细（Auctionator 接口不可用），请更新 Auctionator。")
        return nil, nil, "no_api"
    end
    if #results == 0 then return nil, {}, nil end
    local nameToID = {}
    if Auctionator.Constants and Auctionator.Constants.DisenchantingItemName and type(Auctionator.Constants.DisenchantingItemName) == "table" then
        for id, nm in pairs(Auctionator.Constants.DisenchantingItemName) do
            if type(nm) == "string" and nm ~= "" then nameToID[nm] = id end
        end
    end
    if db.NameToID then
        for nm, id in pairs(db.NameToID) do
            if type(nm) == "string" and nm ~= "" then nameToID[nm] = id end
        end
    end
    -- Aggregate by material: each outcome is (percent, qty, material). Expected qty = sum(percent/100 * qty). Price = sum(expectedQty * our AHPrices[itemID]) * 0.95.
    local totalValue = 0
    local byMaterial = {}   -- name -> { expectedQty = number, itemID = number }
    for _, line in ipairs(results) do
        local raw = (line and tostring(line)):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local pct, qty, matName = raw:match("(%d+%.?%d*)%s*%%%s*(%d+)%s+(.+)")
        if pct and qty and matName then
            matName = strtrim and strtrim(matName) or matName:gsub("^%s+", ""):gsub("%s+$", "")
            local percent = tonumber(pct) or 0
            local q = tonumber(qty) or 0
            local expectedQty = (percent / 100) * q
            local mid = nameToID[matName] or (db.NameToID and db.NameToID[matName])
            local price = (mid and db.AHPrices and db.AHPrices[mid]) and db.AHPrices[mid] or 0
            totalValue = totalValue + expectedQty * price
            if not byMaterial[matName] then
                byMaterial[matName] = { expectedQty = 0, itemID = mid }
            end
            byMaterial[matName].expectedQty = byMaterial[matName].expectedQty + expectedQty
        end
    end
    local breakdown = {}
    for name, t in pairs(byMaterial) do
        if t.expectedQty and t.expectedQty > 0 then
            breakdown[#breakdown + 1] = { name = name, expectedQty = t.expectedQty, itemID = t.itemID }
        end
    end
    -- No parseable breakdown => treat as not disenchantable (use normal sellback).
    if #breakdown == 0 then return nil, {}, nil end
    if totalValue <= 0 then return nil, breakdown, nil end
    return math.floor(totalValue * 0.95), breakdown, nil
end

-- Per-item price used for AH sellback (recovery). When UseDisenchantRecovery is on, uses our disenchant calc (GetDisenchantBreakdown + AHPrices); else AHPrices. If disenchant fails (e.g. Auctionator not loaded), falls back to AHPrices.
function L.GetSellBackAHPricePerItem(itemID)
    local db = ProfLevelHelperDB
    if not db or not itemID then return nil end
    if db.UseDisenchantRecovery then
        local value, _, err = L.GetDisenchantValueAndBreakdown(itemID)
        if not err and type(value) == "number" and value > 0 then return value end
    end
    if db.AHPrices and db.AHPrices[itemID] and db.AHPrices[itemID] > 0 then return db.AHPrices[itemID] end
    return nil
end

-- True if item can be disenchanted and we get a valid breakdown (so we have expected materials for value calc).
function L.IsDisenchantable(itemID)
    if not itemID then return false end
    local value, breakdown = L.GetDisenchantValueAndBreakdown(itemID)
    return type(value) == "number" and value > 0 and breakdown and #breakdown > 0
end

-- Per-item value when using AH-path recovery. Whitelist (vendor mode) = direct AH sell item; else disenchant (if option) or AH.
function L.GetSellBackValueWhenUsingAH(rec, db)
    if not rec or not rec.createdItemID or not db then return nil end
    if db.SellBackMethod == "vendor" and db.AHSellBackWhitelist and db.AHSellBackWhitelist[rec.createdItemID] then
        if db.AHPrices and db.AHPrices[rec.createdItemID] and db.AHPrices[rec.createdItemID] > 0 then
            return db.AHPrices[rec.createdItemID]
        end
        return nil
    end
    return L.GetSellBackAHPricePerItem(rec.createdItemID)
end

-- When not in list: vendor mode and not whitelisted => max(vendor, disenchant); AH mode and not blacklisted => max(disenchant, vendor). Returns nil when in list (use normal rule).
function L.GetBestSellBackPerItem(rec, db)
    if not rec or not rec.createdItemID or not db then return nil end
    if db.SellBackMethod == "vendor" and db.AHSellBackWhitelist and db.AHSellBackWhitelist[rec.createdItemID] then
        return nil
    end
    if db.SellBackMethod == "ah" and db.AHSellBackBlacklist and db.AHSellBackBlacklist[rec.createdItemID] then
        return nil
    end
    local vendor = rec.sellPricePerItem or 0
    local deVal = L.GetDisenchantValueAndBreakdown(rec.createdItemID)
    local disenchant = (type(deVal) == "number" and deVal > 0) and deVal or 0
    local best = math.max(vendor, disenchant)
    return best > 0 and best or nil
end

-- Resolve item name or id to price. Returns copper.
-- NPC vendor price only from VendorPrices.lua (ProfLevelHelper_VendorPrices); not from addon-recorded or GetItemInfo.
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
    if not id then return 0 end
    local db = ProfLevelHelperDB
    local vp = ProfLevelHelper_VendorPrices
    if vp and vp[id] and vp[id] > 0 then
        return vp[id]
    end
    local best = nil
    if db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0 then
        best = db.AHPrices[id]
    end
    if db.FragmentCosts and db.FragmentCosts[id] and (db.FragmentValueInCopper or 0) > 0 then
        local fc = db.FragmentCosts[id] * db.FragmentValueInCopper
        if fc > 0 and (not best or fc < best) then best = fc end
    end
    if best then return best end
    return 0
end

-- Returns the MARGINAL unit price when cumUnits have already been purchased.
-- Walks the price curve to find which tier the next unit falls into.
-- NPC-sold items (VendorPrices.lua only) use fixed price; AH curve not used for them.
function L.GetTierPriceAtCumQty(itemID, cumUnits)
    local db = ProfLevelHelperDB
    if not db or not itemID then return 0 end
    local vp = ProfLevelHelper_VendorPrices
    if vp and vp[itemID] and vp[itemID] > 0 then
        return vp[itemID]
    end
    local curve = db.AHPriceCurve and db.AHPriceCurve[itemID]
    local tierPrice
    if not curve or #curve == 0 then
        tierPrice = L.GetItemPrice(itemID) or 0
    else
        local accum = 0
        for _, tier in ipairs(curve) do
            accum = accum + tier[1]
            if cumUnits < accum then tierPrice = tier[2]; break end
        end
        tierPrice = tierPrice or curve[#curve][2]
    end
    return tierPrice or 0
end

-- Returns average cost per unit when buying `qty` units using the stored AH price curve.
-- NPC-sold items always use their fixed vendor price.
-- When qty exceeds total AH supply the last tier price is extrapolated.
function L.GetMarginalCostForQty(itemID, qty)
    local db = ProfLevelHelperDB
    if not db or not itemID or not qty or qty <= 0 then return 0 end
    local vp = ProfLevelHelper_VendorPrices
    if vp and vp[itemID] and vp[itemID] > 0 then
        return vp[itemID]
    end
    local curve = db.AHPriceCurve and db.AHPriceCurve[itemID]
    if not curve or #curve == 0 then
        return L.GetItemPrice(itemID) or 0
    end
    local remaining = qty
    local totalCost = 0
    local lastPrice = curve[#curve][2]
    for _, tier in ipairs(curve) do
        if remaining <= 0 then break end
        local tierQty   = tier[1]
        local tierPrice = tier[2]
        lastPrice = tierPrice
        local take = math.min(remaining, tierQty)
        totalCost = totalCost + take * tierPrice
        remaining = remaining - take
    end
    if remaining > 0 then
        totalCost = totalCost + remaining * lastPrice
    end
    return totalCost / qty
end

-- Build effective cost per item: min(market price, cost to craft from other recipes).
-- Handles chains (e.g. Lesser Healing Potion as material for Healing Potion). Returns map itemID -> copper.
-- Optional baseOverride: map itemID -> copper that replaces AH lookup for specific items (used by tiered DP).
function L.ComputeEffectiveMaterialCosts(recipes, baseOverride)
    local db = ProfLevelHelperDB
    local nameToID = db and db.NameToID
    local effectiveCost = {}
    local itemIds = {}

    for _, rec in ipairs(recipes or {}) do
        if rec.createdItemID then
            itemIds[rec.createdItemID] = true
        end
        for _, r in ipairs(rec.reagents or {}) do
            local id = r.itemID or (r.name and nameToID and nameToID[r.name])
            if id then itemIds[id] = true end
        end
    end

    for id in pairs(itemIds) do
        local p = (baseOverride and baseOverride[id]) or L.GetItemPrice(id)
        -- Treat price=0 as "no data" (EFF_COST_UNKNOWN), not free.
        effectiveCost[id] = (p and p > 0) and p or EFF_COST_UNKNOWN
    end

    local maxIter = 50
    while maxIter > 0 do
        maxIter = maxIter - 1
        local changed = false
        for _, rec in ipairs(recipes or {}) do
            if rec.createdItemID and rec.numMade and rec.numMade > 0 then
                local costSum = 0
                local allKnown = true
                for _, r in ipairs(rec.reagents or {}) do
                    local id = r.itemID or (r.name and nameToID and nameToID[r.name])
                    local c = (id and effectiveCost[id]) or EFF_COST_UNKNOWN
                    if c >= EFF_COST_UNKNOWN then allKnown = false end
                    costSum = costSum + (c or 0) * (r.count or 0)
                end
                if allKnown then
                    local costPer = costSum / rec.numMade
                    local cur = effectiveCost[rec.createdItemID]
                    if cur == nil or costPer < cur then
                        effectiveCost[rec.createdItemID] = costPer
                        changed = true
                    end
                end
            end
        end
        if not changed then break end
    end

    return effectiveCost
end

-- Cost per one craft; if effectiveCost map is provided, use it for unit prices (craft-chain aware).
function L.CraftCostWithEffective(reagents, effectiveCost)
    local cost = 0
    local db = ProfLevelHelperDB
    local nameToID = db and db.NameToID
    for _, r in ipairs(reagents or {}) do
        local id = r.itemID or (r.name and nameToID and nameToID[r.name])
        local unitPrice
        if effectiveCost and id and effectiveCost[id] and effectiveCost[id] < EFF_COST_UNKNOWN then
            unitPrice = effectiveCost[id]
        else
            unitPrice = L.GetItemPrice(id or r.name)
        end
        cost = cost + (unitPrice or 0) * (r.count or 0)
    end
    return cost
end

-- Build a map of items that are both produced and consumed within the route.
-- Returns { [itemID] = { qty = N, price = P } } where:
--   qty   = min(totalProduced, totalConsumed) -- units available as self-produced supply
--   price = max(vendorSellBack, ahSellBack)   -- best opportunity cost per unit
-- This is used by the refinement loop to prepend a self-produced price tier into the AH
-- price curve, so the DP correctly prices intermediate materials at opportunity cost.
function L.BuildRouteProducedInfo(route, db)
    if not route or not db then return {} end
    local produced = {}
    local consumed = {}
    local sbPrice  = {}
    for _, seg in ipairs(route) do
        local rec = seg.recipe
        if rec.createdItemID then
            local qty = (rec.numMade or 1) * seg.totalCrafts
            produced[rec.createdItemID] = (produced[rec.createdItemID] or 0) + qty
            local vendor = rec.sellPricePerItem or 0
            local ah     = (rec.ahPricePerItem   or 0) * AH_TAX_FACTOR
            local sb = math.max(vendor, ah)
            if sb > 0 then
                sbPrice[rec.createdItemID] = math.max(sbPrice[rec.createdItemID] or 0, sb)
            end
        end
        for _, r in ipairs(rec.reagents or {}) do
            local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
            if id then
                consumed[id] = (consumed[id] or 0) + math.ceil(r.count * seg.totalCrafts)
            end
        end
    end
    local rpInfo = {}
    for id, prod in pairs(produced) do
        local cons     = consumed[id] or 0
        local selfUsed = math.min(prod, cons)
        if selfUsed > 0 and sbPrice[id] and sbPrice[id] > 0 then
            rpInfo[id] = { qty = selfUsed, price = sbPrice[id] }
        end
    end
    return rpInfo
end

-- Build merged price curve (route-produced tier + AH curve) sorted cheapest-first.
-- Used by GetTierPriceAtCumQtyWithRP and GetMarginalCostWithRP.
local function buildMergedCurve(itemID, rpInfo)
    local db    = ProfLevelHelperDB
    local rp    = rpInfo and rpInfo[itemID]
    local curve = db and db.AHPriceCurve and db.AHPriceCurve[itemID]
    local merged = {}
    if rp then merged[#merged + 1] = { rp.qty, rp.price } end
    if curve then
        for _, tier in ipairs(curve) do merged[#merged + 1] = { tier[1], tier[2] } end
    end
    table.sort(merged, function(a, b) return a[2] < b[2] end)
    return merged
end

-- Like GetTierPriceAtCumQty but prepends the route-produced tier from rpInfo.
-- Returns the marginal price for the unit at cumulative position cumUnits.
function L.GetTierPriceAtCumQtyWithRP(itemID, cumUnits, rpInfo)
    if not rpInfo or not rpInfo[itemID] then
        return L.GetTierPriceAtCumQty(itemID, cumUnits)
    end
    local vp = ProfLevelHelper_VendorPrices
    if vp and vp[itemID] and vp[itemID] > 0 then return vp[itemID] end
    local merged = buildMergedCurve(itemID, rpInfo)
    if #merged == 0 then return L.GetItemPrice(itemID) or 0 end
    local accum = 0
    for _, tier in ipairs(merged) do
        accum = accum + tier[1]
        if cumUnits < accum then return tier[2] end
    end
    return merged[#merged][2]
end

-- Like GetMarginalCostForQty but prepends the route-produced tier from rpInfo.
-- Returns the weighted-average cost per unit for buying `qty` total units.
function L.GetMarginalCostWithRP(itemID, qty, rpInfo)
    if not rpInfo or not rpInfo[itemID] then
        return L.GetMarginalCostForQty(itemID, qty)
    end
    if not qty or qty <= 0 then return 0 end
    local vp = ProfLevelHelper_VendorPrices
    if vp and vp[itemID] and vp[itemID] > 0 then return vp[itemID] end
    local merged = buildMergedCurve(itemID, rpInfo)
    if #merged == 0 then return L.GetItemPrice(itemID) or 0 end
    local remaining = qty
    local totalCost = 0
    local lastPrice = merged[#merged][2]
    for _, tier in ipairs(merged) do
        if remaining <= 0 then break end
        local take = math.min(remaining, tier[1])
        totalCost = totalCost + take * tier[2]
        remaining = remaining - take
        lastPrice = tier[2]
    end
    if remaining > 0 then totalCost = totalCost + remaining * lastPrice end
    return totalCost / qty
end

-- Calculate global cheapest route using Dynamic Programming (Shortest Path).
--
-- When db.UseTieredPricing is active:
--   The prefix-sum for each recipe is built with PER-SKILL-LEVEL material costs.
--   At skill level l the material cost uses GetTierPriceAtCumQty(id, cumEC * count),
--   where cumEC = expected crafts accumulated from the recipe's validStart up to l.
--   This means the DP naturally sees the real price escalation as a recipe consumes
--   more and more of the cheap AH stock; the optimizer can split a recipe segment
--   exactly where a different recipe becomes cheaper.
--
--   Additionally, up to TieredPricingMaxRounds iterative passes are run, each time
--   recomputing effectiveCost from the previous route's material totals. This helps
--   craft-chain items (where a sub-crafted material's cost changes based on route)
--   converge to better prices. Stops early when total cost no longer improves.
function L.CalculateLevelingRoute(targetStart, targetEnd, includeHoliday)
    local allRecipes, profName, currentSkill, pMaxSkill = L.GetRecipeList(includeHoliday)
    if not allRecipes or #allRecipes == 0 then return nil, profName, currentSkill, currentSkill, 0 end

    targetStart = targetStart or currentSkill
    targetEnd   = targetEnd   or pMaxSkill
    L.Print(string.format("计算路线: %d -> %d (%s)", targetStart, targetEnd, tostring(profName)))
    if targetStart >= targetEnd then
        L.Print("错误: 起点等级已大于或等于终点等级。")
        return nil, profName, targetStart, targetEnd, 0
    end

    local db     = ProfLevelHelperDB
    local DPINF  = 99999999999
    -- Pre-compute once: whether to use per-level tier pricing in prefix sums.
    local useTieredPricing = db.UseTieredPricing and db.AHPriceCurve and next(db.AHPriceCurve)
    local nameToID = db.NameToID

    -- Mutable upvalue: route-produced info for the current iteration.
    -- runDP closes over this so getTierPrice can reflect the latest rpInfo
    -- without passing it as an argument through every call site.
    local currentRPInfo = {}

    local function getTierPrice(id, cumUnits)
        return L.GetTierPriceAtCumQtyWithRP(id, cumUnits, currentRPInfo)
    end

    -- -----------------------------------------------------------------------
    -- Inner function: filter allRecipes with given effectiveCost, run the
    -- Segment-DP, reconstruct and return (route, totalCost) or (nil, 0).
    -- -----------------------------------------------------------------------
    local function runDP(effectiveCost)
        -- Pre-calculate per-recipe costs and apply source / price filters.
        local filteredRecipes = {}
        for _, rec in ipairs(allRecipes) do
            rec.matCost = L.CraftCostWithEffective(rec.reagents, effectiveCost)
            rec.sellPricePerItem = 0
            rec.ahPricePerItem   = 0
            if rec.createdItemID then
                if GetItemInfo then
                    local _, _, _, _, _, _, _, _, _, _, vp = GetItemInfo(rec.createdItemID)
                    if vp and vp > 0 then rec.sellPricePerItem = vp end
                end
                rec.ahPricePerItem = L.GetSellBackValueWhenUsingAH(rec, db) or 0
            end
            local rCost, rSource = ProfLevelHelper.GetRecipeAcquisitionCost(rec)
            rCost = rCost or 0
            if rec.isTrainer and rCost > 0 and rCost == rec.trainPrice then
                rCost = math.floor(rCost * 0.9)
            end
            rec.acqCost   = rCost
            rec.acqSource = rSource or "未知来源"

            local allowed = true
            if not rec.isKnown then
                if rec.acqSource == "训练师学习" and db.IncludeSourceTrainer == false then allowed = false end
                if rec.acqSource == "拍卖行购买" and db.IncludeSourceAH == false then allowed = false end
                if rec.acqSource == "NPC 购买" and db.IncludeSourceVendor == false then allowed = false end
                if rec.acqSource:match("任务") and db.IncludeSourceQuest == false then allowed = false end
                if (rec.acqSource == "需打怪或购买(价格未知)" or rec.acqSource == "未知来源" or rec.acqSource:match("打怪掉落")) and db.IncludeSourceUnknown == false then allowed = false end
            end
            if allowed then
                for _, r in ipairs(rec.reagents or {}) do
                    local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
                    if not id then allowed = false; break end
                    local hasPrice = (effectiveCost[id] and effectiveCost[id] > 0 and effectiveCost[id] < EFF_COST_UNKNOWN)
                        or (db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0)
                        or (ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0)
                        or (db.FragmentCosts and db.FragmentCosts[id] and (db.FragmentValueInCopper or 0) > 0)
                    if not hasPrice then allowed = false; break end
                end
            end
            -- MinAHQuantity filter: skip when tiered pricing is active, because the price
            -- curve already penalises scarcity by extrapolating at the last-tier price.
            local useTiered = db.UseTieredPricing and db.AHPriceCurve and next(db.AHPriceCurve)
            local minQty = (not useTiered and db.MinAHQuantity and db.MinAHQuantity > 0) and db.MinAHQuantity or 0
            if allowed and minQty > 0 and db.AHPrices and db.AHQty and next(db.AHQty) then
                for _, r in ipairs(rec.reagents or {}) do
                    local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
                    if id then
                        local hasVendorOrFrag = (ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0)
                            or (db.FragmentCosts and db.FragmentCosts[id] and (db.FragmentValueInCopper or 0) > 0)
                        if not hasVendorOrFrag and (db.AHQty[id] or 0) < minQty then
                            allowed = false; break
                        end
                    end
                end
            end
            -- When tiered pricing is on: do not recommend recipes whose materials are
            -- sourced from AH but have zero AH quantity (e.g. "柔软的狂鱼肉" not on AH).
            -- Materials with VendorPrices or FragmentCosts are allowed without AH stock.
            if allowed and useTiered and db.AHQty and next(db.AHQty) then
                for _, r in ipairs(rec.reagents or {}) do
                    local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
                    if id then
                        local hasVendorOrFrag = (ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0)
                            or (db.FragmentCosts and db.FragmentCosts[id] and (db.FragmentValueInCopper or 0) > 0)
                        if not hasVendorOrFrag and (db.AHQty[id] or 0) < 1 then
                            allowed = false; break
                        end
                    end
                end
            end
            if allowed then filteredRecipes[#filteredRecipes + 1] = rec end
        end
        L.Print("过滤后可用配方数量: " .. #filteredRecipes)

        -- ===== Segment DP with prefix sums =====
        -- dp[s] = min total cost to reach skill s from targetStart.
        -- Transition: dp[s] = min_r { acqCost[r] + prefix[r][s] + min_t(dp[t] - prefix[r][t]) }
        -- Running minimum best[r] updated as t advances. O(N * R).
        local recInfos = {}
        for ri, rec in ipairs(filteredRecipes) do
            local learnSkill = (db.RecipeLearnOverrides and db.RecipeLearnOverrides[rec.name])
                and db.RecipeLearnOverrides[rec.name] or rec.learn or 1
            local yellow, gray = rec.yellow, rec.grey
            if not yellow or not gray then
                yellow, gray = L.GetRecipeThresholds(rec.name, profName, learnSkill)
            end
            local useAH      = (db.SellBackMethod == "ah" and not (db.AHSellBackBlacklist and db.AHSellBackBlacklist[rec.createdItemID])) or (db.SellBackMethod == "vendor" and ((db.AHSellBackWhitelist and db.AHSellBackWhitelist[rec.createdItemID]) or (db.UseDisenchantRecovery and L.IsDisenchantable(rec.createdItemID))))
            local numMade    = rec.numMade or 1
            local acqCost    = (not rec.isKnown) and (rec.acqCost or 0) or 0
            local validStart = math.max(learnSkill, targetStart)
            local validEnd   = math.min(gray - 1, targetEnd - 1)
            local bestSb     = (db.UseDisenchantRecovery and L.GetBestSellBackPerItem(rec, db)) or nil

            local pStep, pCrafts, pMat, pSellV, pSellA = {}, {}, {}, {}, {}
            local cs, cc, cm, cv, ca = 0, 0, 0, 0, 0
            -- cumEC: expected crafts accumulated from validStart; used to look up
            -- the correct price tier when useTieredPricing is true.
            local cumEC = 0
            for l = validStart, validEnd + 1 do
                pStep[l] = cs; pCrafts[l] = cc; pMat[l] = cm; pSellV[l] = cv; pSellA[l] = ca
                if l <= validEnd then
                    local chance = L.CalcSkillUpChance(gray, yellow, l)
                    if chance <= 0 and rec.skillType and rec.skillType ~= "trivial" and rec.skillType ~= "difficult" then
                        if     rec.skillType == "optimal" then chance = 1
                        elseif rec.skillType == "easy"    then chance = 0.6
                        elseif rec.skillType == "medium"  then chance = 0.3
                        end
                    end
                    if rec.skillType == "trivial" or rec.skillType == "difficult" then chance = 0 end
                    if chance > 0 then
                        local ec  = 1 / chance
                        -- Material cost at this skill level.
                        -- With tiered pricing: use the marginal price from the curve at the
                        -- point where cumEC*count units have already been consumed.
                        -- This makes the prefix sum reflect actual price escalation as crafts
                        -- accumulate, rather than a single averaged cost.
                        local matCostAtL = rec.matCost
                        if useTieredPricing then
                            matCostAtL = 0
                            local fallback = false
                            for _, r in ipairs(rec.reagents or {}) do
                                local id = r.itemID or (r.name and nameToID and nameToID[r.name])
                                if id then
                                    local tierPrice = getTierPrice(id, cumEC * r.count)
                                    matCostAtL = matCostAtL + tierPrice * r.count
                                else
                                    fallback = true; break
                                end
                            end
                            if fallback then matCostAtL = rec.matCost end
                        end
                        local mg  = matCostAtL * ec
                        local svV = (rec.sellPricePerItem or 0) * numMade * ec
                        local svA = (rec.ahPricePerItem  or 0) * AH_TAX_FACTOR * numMade * ec
                        local sb  = (bestSb and bestSb > 0) and (bestSb * numMade * ec) or (useAH and svA or svV)
                        cs = cs + (mg - sb); cc = cc + ec; cm = cm + mg; cv = cv + svV; ca = ca + svA
                        cumEC = cumEC + ec
                    end
                end
            end
            recInfos[ri] = {
                rec = rec, validStart = validStart, validEnd = validEnd, gray = gray,
                acqCost = acqCost,
                pStep = pStep, pCrafts = pCrafts, pMat = pMat, pSellV = pSellV, pSellA = pSellA,
            }
        end

        local dp      = {}; for s = targetStart, targetEnd do dp[s] = DPINF end; dp[targetStart] = 0
        local segPath = {}
        local best    = {}; for ri = 1, #recInfos do best[ri]  = DPINF end
        local bestT   = {}; for ri = 1, #recInfos do bestT[ri] = targetStart end

        for s = targetStart + 1, targetEnd do
            local t = s - 1
            for ri, info in ipairs(recInfos) do
                if t >= info.validStart and t <= info.validEnd and dp[t] < DPINF and info.pStep[t] then
                    local val = dp[t] - info.pStep[t]
                    if val < best[ri] then best[ri] = val; bestT[ri] = t end
                end
            end
            for ri, info in ipairs(recInfos) do
                if s <= info.gray and info.pStep[s] and best[ri] < DPINF then
                    local candidate = info.acqCost + info.pStep[s] + best[ri]
                    if candidate < dp[s] then
                        dp[s] = candidate
                        segPath[s] = { ri = ri, startT = bestT[ri], recCostActual = info.acqCost }
                    end
                end
            end
        end

        if dp[targetEnd] >= DPINF then
            local maxReached = targetStart
            for s = targetStart, targetEnd do
                if dp[s] < DPINF then maxReached = s end
            end
            L.Print(string.format("错误: 算法在等级 %d 处中断，无法到达 %d。请检查此时是否缺少可用的后续配方。", maxReached, targetEnd))
            return nil, 0
        end

        -- Reconstruct route by backtracking.
        local consolidatedRoute = {}
        local curr        = targetEnd
        local seenRecipes = {}
        while curr > targetStart do
            local seg = segPath[curr]
            if not seg then break end
            local info = recInfos[seg.ri]
            local rec  = info.rec
            local t, e = seg.startT, curr
            local totalMat    = (info.pMat[e]    or 0) - (info.pMat[t]    or 0)
            local totalSV     = (info.pSellV[e]  or 0) - (info.pSellV[t]  or 0)
            local totalSA     = (info.pSellA[e]  or 0) - (info.pSellA[t]  or 0)
            local totalCrafts = (info.pCrafts[e] or 0) - (info.pCrafts[t] or 0)
            local recCostOnce = 0
            if not seenRecipes[rec.name] then
                recCostOnce = seg.recCostActual or 0
                seenRecipes[rec.name] = true
            end
            local useAH    = (db.SellBackMethod == "ah" and not (db.AHSellBackBlacklist and db.AHSellBackBlacklist[rec.createdItemID])) or (db.SellBackMethod == "vendor" and ((db.AHSellBackWhitelist and db.AHSellBackWhitelist[rec.createdItemID]) or (db.UseDisenchantRecovery and L.IsDisenchantable(rec.createdItemID))))
            local bestSb   = (db.UseDisenchantRecovery and L.GetBestSellBackPerItem(rec, db)) or nil
            local sellBack = (bestSb and bestSb > 0) and (bestSb * (rec.numMade or 1) * totalCrafts) or (useAH and totalSA or totalSV)
            table.insert(consolidatedRoute, 1, {
                startSkill          = t,
                endSkill            = e,
                recipe              = rec,
                totalCrafts         = totalCrafts,
                totalMatCost        = totalMat,
                totalSellBackVendor = totalSV,
                totalSellBackAH     = totalSA,
                totalRecCost        = recCostOnce,
                recSource           = rec.acqSource,
                segmentTotalCost    = recCostOnce + totalMat - sellBack,
            })
            curr = t
        end
        return consolidatedRoute, dp[targetEnd]
    end -- end runDP

    -- Round 1: standard benchmark prices, no route-produced info yet.
    local effectiveCost = L.ComputeEffectiveMaterialCosts(allRecipes)
    local route, totalCost = runDP(effectiveCost)

    -- Refinement loop: iteratively refine costs using both tiered AH pricing and
    -- route-produced opportunity costs.  Runs unconditionally (not only when tiered
    -- pricing is enabled) because route-produced pricing benefits all users.
    -- Each round:
    --   1. Extract route-produced info (items both crafted and consumed in the route).
    --   2. Build a baseOverride that merges the self-produced tier into the AH curve
    --      using GetMarginalCostWithRP (weighted average over total consumption qty).
    --   3. Recompute effectiveCost and re-run DP.
    --   4. Stop when total cost no longer improves or no override exists.
    if route then
        local maxRounds = (type(db.TieredPricingMaxRounds) == "number" and db.TieredPricingMaxRounds > 0)
            and math.min(100, math.floor(db.TieredPricingMaxRounds)) or 10
        local prevCost = totalCost
        local hasTieredData = db.UseTieredPricing and db.AHPriceCurve and next(db.AHPriceCurve)
        for _ = 1, maxRounds - 1 do
            -- Update currentRPInfo so getTierPrice (used inside runDP prefix sums) reflects
            -- the latest route's self-produced tiers.
            currentRPInfo = L.BuildRouteProducedInfo(route, db)
            local qtyMap = {}
            for _, seg in ipairs(route) do
                for _, r in ipairs(seg.recipe.reagents or {}) do
                    local id = r.itemID or (r.name and db.NameToID and db.NameToID[r.name])
                    if id then qtyMap[id] = (qtyMap[id] or 0) + math.ceil(r.count * seg.totalCrafts) end
                end
            end
            local baseOverride = {}
            for id, qty in pairs(qtyMap) do
                local needsOverride = (hasTieredData and db.AHPriceCurve[id]) or currentRPInfo[id]
                if needsOverride then
                    local tp = L.GetMarginalCostWithRP(id, qty, currentRPInfo)
                    if tp and tp > 0 then baseOverride[id] = tp end
                end
            end
            if not next(baseOverride) and not next(currentRPInfo) then break end
            effectiveCost = L.ComputeEffectiveMaterialCosts(allRecipes, baseOverride)
            local route2, totalCost2 = runDP(effectiveCost)
            if not route2 or totalCost2 >= prevCost then break end
            route, totalCost, prevCost = route2, totalCost2, totalCost2
        end
    end

    if not route then
        return nil, profName, targetStart, targetEnd, 0
    end
    return route, profName, targetStart, targetEnd, totalCost
end
