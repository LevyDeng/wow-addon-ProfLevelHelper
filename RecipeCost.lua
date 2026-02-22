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
        -- Only use explicitly recorded vendor prices (populated when the user visits an NPC vendor).
        -- GetItemInfo's vendor price field is the item's sell value (what you get selling to a vendor),
        -- NOT the NPC buy price. Most recipe scrolls cannot be bought from vendors at all, so using
        -- sell price * 4 as a proxy produces an incorrect tiny price that overrides the real AH price
        -- on the second call (once GetItemInfo is cached), causing the same recipe to flip from
        -- "拍卖行购买" to "NPC 购买" between calls.
        local vendorPrice = db.VendorPrices and db.VendorPrices[id]
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

-- Record Titan Fragment exchange: open the fragment vendor, then run /plh recordfragment.
-- Uses GetMerchantItemCostItem when the merchant uses alternate currency (e.g. fragments).
function ProfLevelHelper.RecordFragmentCosts()
    if not GetMerchantNumItems then return end
    local db = ProfLevelHelperDB
    db.FragmentCosts = db.FragmentCosts or {}
    local count = 0
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then
                local _, _, _, quantity = GetMerchantItemInfo(i)
                quantity = (quantity and quantity > 0) and quantity or 1
                -- Only record when the item is paid with alternate currency (fragments).
                -- If GetMerchantItemCostInfo(i) is 0, the item is gold-priced; do not record it,
                -- or we would wrongly treat copper (e.g. 80000 for 8g) as fragment count.
                local costInfoCount = (GetMerchantItemCostInfo and GetMerchantItemCostInfo(i)) or 0
                if costInfoCount and costInfoCount > 0 and GetMerchantItemCostItem then
                    local _, value = GetMerchantItemCostItem(i, 1)
                    if value and value > 0 then
                        db.FragmentCosts[id] = value / quantity
                        count = count + 1
                    end
                end
            end
        end
    end
    if ProfLevelHelper and ProfLevelHelper.Print then
        ProfLevelHelper.Print(string.format("已记录泰坦碎片兑换: %d 种物品。请在设置中填写「碎片单价(铜)」(默认8银)。", count))
    end
end

-- Dev only: export FragmentCosts as Lua for saving to FragmentCosts.lua. Format: ProfLevelHelper_FragmentCosts = { ... }
function ProfLevelHelper.ExportFragmentCostsToLuaString()
    local db = ProfLevelHelperDB
    if not db or not db.FragmentCosts then return "ProfLevelHelper_FragmentCosts = {\n}\n" end
    local t = {}
    t[#t + 1] = "-- Titan Fragment costs: itemID = fragments per unit. Save as FragmentCosts.lua in addon folder.\nProfLevelHelper_FragmentCosts = {\n"
    for id, frag in pairs(db.FragmentCosts) do
        if type(id) == "number" and type(frag) == "number" then
            t[#t + 1] = ("  [%d] = %s,\n"):format(id, tostring(frag))
        end
    end
    t[#t + 1] = "}\n"
    return table.concat(t)
end
