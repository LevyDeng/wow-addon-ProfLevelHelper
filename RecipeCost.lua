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
        local vendorPrice = ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id]
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

    -- Trust ala's isTrainer: if true, treat as trainer recipe even when trainPrice is missing (e.g. 0).
    if rec.isTrainer then
        local tp = (type(rec.trainPrice) == "number" and rec.trainPrice >= 0) and rec.trainPrice or 0
        if cost == nil or tp < cost then
            cost = tp
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

    -- Recipes with no recipe item (learned directly from trainer) and a learn level are trainer recipes.
    -- ala may not set isTrainer for some recipes; avoid marking them as unknown.
    if source == "未知来源" or source == "需打怪或购买(价格未知)" then
        local noRecipeItem = not rec.recipeItemIDs or type(rec.recipeItemIDs) ~= "table" or #rec.recipeItemIDs == 0
        if noRecipeItem and rec.learn and type(rec.learn) == "number" then
            source = "训练师学习"
            if cost == nil then cost = 0 end
        end
    end

    return cost, source
end

-- Default vendor discount: 0.8 = 80% (8折). Recorded price is divided by this to get "base" price.
local VENDOR_RECORD_DISCOUNT = 0.8

-- Record NPC vendor buy prices (gold/copper) for items in the currently open merchant window.
-- Assumes displayed price is reputation-discounted; divides by VENDOR_RECORD_DISCOUNT (default 0.8) to store base price.
-- Only records items sold for gold (skips fragment/other-currency items).
function ProfLevelHelper.RecordVendorPrices()
    if not GetMerchantNumItems then return 0 end
    local db = ProfLevelHelperDB
    db.VendorPrices = db.VendorPrices or {}
    local count = 0
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then
                local _, _, price, quantity = GetMerchantItemInfo(i)
                local costInfoCount = (GetMerchantItemCostInfo and GetMerchantItemCostInfo(i)) or 0
                if price and price > 0 and costInfoCount == 0 then
                    quantity = (quantity and quantity > 0) and quantity or 1
                    local unitPrice = (price / quantity) / VENDOR_RECORD_DISCOUNT
                    db.VendorPrices[id] = unitPrice
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Export VendorPrices as Lua string for saving to VendorPrices.lua (itemID = copper).
function ProfLevelHelper.ExportVendorPricesToLuaString()
    local db = ProfLevelHelperDB
    if not db or not db.VendorPrices then return "ProfLevelHelper_VendorPrices = {\n}\n" end
    local t = {}
    t[#t + 1] = "-- NPC vendor buy prices (copper). Open a vendor, run /plh recordvendor, then /plh dumpvendor; save as VendorPrices.lua.\nProfLevelHelper_VendorPrices = {\n"
    for id, price in pairs(db.VendorPrices) do
        if type(id) == "number" and type(price) == "number" and price > 0 then
            t[#t + 1] = ("  [%d] = %.2f,\n"):format(id, price)
        end
    end
    t[#t + 1] = "}\n"
    return table.concat(t)
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
