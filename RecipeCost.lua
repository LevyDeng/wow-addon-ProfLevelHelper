--[[
  Recipe acquisition cost: min of AH, vendor, trainer.
]]

ProfLevelHelper.RecipeThresholds = ProfLevelHelper.RecipeThresholds or {}

function ProfLevelHelper.PlayerKnowsRecipe(recipeIndex)
    if not GetTradeSkillInfo or type(recipeIndex) ~= "number" then return false end
    local name, skillType = GetTradeSkillInfo(recipeIndex)
    return name and skillType and skillType ~= "header" and skillType ~= "difficult"
end

local function GetRecipeItemID(recipeLink)
    if not recipeLink or type(recipeLink) ~= "string" then return nil end
    local id = recipeLink:match("item:(%d+)")
    return id and tonumber(id) or nil
end

local function GetRecipeSpellID(recipeLink)
    if not recipeLink or type(recipeLink) ~= "string" then return nil end
    local id = recipeLink:match("enchant:(%d+)") or recipeLink:match("spell:(%d+)")
    return id and tonumber(id) or nil
end

function ProfLevelHelper.GetRecipeAcquisitionCost(rec)
    if not rec then return nil, nil end
    if rec.isKnown then return 0, "已学习" end
    
    -- Fallback for native API
    if rec.index and ProfLevelHelper.PlayerKnowsRecipe(rec.index) then return 0, "已学习" end

    local db = ProfLevelHelperDB
    local cost = nil
    local source = "未知来源"

    local function checkPrice(id)
        if not id then return end
        if db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0 then
            if cost == nil or db.AHPrices[id] < cost then
                cost = db.AHPrices[id]
                source = "拍卖行购买"
            end
        end
        local vendorPrice = db.VendorPrices and db.VendorPrices[id]
        if not vendorPrice and GetItemInfo then
            local _, _, _, _, _, _, _, _, _, _, vp = GetItemInfo(id)
            if vp and vp > 0 then vendorPrice = vp * 4 end
        end
        if vendorPrice and vendorPrice > 0 then
            if cost == nil or vendorPrice < cost then
                cost = vendorPrice
                source = "NPC 购买"
            end
        end
    end

    if rec.recipeItemIDs and type(rec.recipeItemIDs) == "table" then
        for _, id in ipairs(rec.recipeItemIDs) do
            checkPrice(id)
        end
    elseif rec.recipeLink then
        checkPrice(GetRecipeItemID(rec.recipeLink))
    end

    if rec.isTrainer and rec.trainPrice and rec.trainPrice >= 0 then
        if cost == nil or rec.trainPrice < cost then
            cost = rec.trainPrice
            source = "训练师学习"
        end
    end

    local spellID = (rec.recipeLink and GetRecipeSpellID(rec.recipeLink)) or rec.sid
    local name = rec.name
    local trainerCost = db.TrainerCosts and (db.TrainerCosts[spellID or name] or db.TrainerCosts[name])
    if trainerCost and trainerCost >= 0 then
        if cost == nil or trainerCost < cost then
            cost = trainerCost
            source = "训练师学习"
        end
    end

    if cost == nil and (rec.recipeItemIDs or rec.recipeLink) then
        source = "需打怪或购买(价格未知)"
    end

    return cost, source
end

function ProfLevelHelper.RecordVendorPrices()
    if not GetMerchantNumItems then return end
    local db = ProfLevelHelperDB
    db.VendorPrices = db.VendorPrices or {}
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then
                local _, _, price = GetMerchantItemInfo(i)
                if price and price > 0 then
                    db.VendorPrices[id] = price
                end
            end
        end
    end
end
