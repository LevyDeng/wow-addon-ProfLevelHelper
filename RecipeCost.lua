--[[
  Recipe acquisition cost: minimum of AH price, vendor price, trainer cost.
  Player already known = 0. Otherwise use scanned AH, VendorPrices (from merchant scan), or TrainerCosts.
]]

ProfLevelHelper.RecipeThresholds = ProfLevelHelper.RecipeThresholds or {} -- [profName][recipeName] = { yellow, gray }

-- Check if player already knows this recipe (current profession window).
function ProfLevelHelper.PlayerKnowsRecipe(recipeIndex)
    if not GetTradeSkillInfo or not recipeIndex then return false end
    local name, skillType = GetTradeSkillInfo(recipeIndex)
    return name and skillType and skillType ~= "header" and skillType ~= "difficult"
end

-- Get recipe item ID from link (pattern/schematic/recipe item).
local function GetRecipeItemID(recipeLink)
    if not recipeLink or type(recipeLink) ~= "string" then return nil end
    local id = recipeLink:match("item:(%d+)")
    return id and tonumber(id) or nil
end

-- Get spell ID from recipe link (e.g. enchant) if it's a spell.
local function GetRecipeSpellID(recipeLink)
    if not recipeLink or type(recipeLink) ~= "string" then return nil end
    local id = recipeLink:match("enchant:(%d+)") or recipeLink:match("spell:(%d+)")
    return id and tonumber(id) or nil
end

-- Recipe acquisition cost (copper): 0 if known, else min(AH, vendor, trainer).
function ProfLevelHelper.GetRecipeAcquisitionCost(recipeEntry)
    if not recipeEntry then return nil end
    local index = recipeEntry.index
    if ProfLevelHelper.PlayerKnowsRecipe(index) then return 0 end

    local itemID = GetRecipeItemID(recipeEntry.recipeLink)
    local spellID = GetRecipeSpellID(recipeEntry.recipeLink)
    local name = recipeEntry.name
    local db = ProfLevelHelperDB
    local cost = nil

    -- AH price (from scan)
    if itemID and db.AHPrices and db.AHPrices[itemID] and db.AHPrices[itemID] > 0 then
        cost = (cost == nil or db.AHPrices[itemID] < cost) and db.AHPrices[itemID] or cost
    end

    -- Vendor price (from merchant scan or GetItemInfo)
    if itemID then
        local vendorPrice = db.VendorPrices and db.VendorPrices[itemID]
        if not vendorPrice and GetItemInfo then
            local _, _, _, _, _, _, _, _, _, _, vp = GetItemInfo(itemID)
            vendorPrice = vp
        end
        if vendorPrice and vendorPrice > 0 then
            cost = (cost == nil or vendorPrice < cost) and vendorPrice or cost
        end
    end

    -- Trainer cost (saved or 0)
    local trainerCost = db.TrainerCosts and (db.TrainerCosts[spellID or name] or db.TrainerCosts[name])
    if trainerCost and trainerCost >= 0 then
        cost = (cost == nil or trainerCost < cost) and trainerCost or cost
    end

    return cost
end

-- Record vendor price when merchant frame is open (call from Scan.lua on MERCHANT_SHOW).
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
