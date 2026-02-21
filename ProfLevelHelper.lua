--[[
  ProfLevelHelper - Profession leveling assistant.
  Considers: AH prices (materials + recipes), NPC vendor recipe prices, trainer recipe costs.
]]

local ADDON_NAME = "ProfLevelHelper"
ProfLevelHelper = ProfLevelHelper or {}
local L = ProfLevelHelper

-- Default saved DB: AH prices, vendor prices (from merchant scan), options
ProfLevelHelperDB = ProfLevelHelperDB or {
    AHPrices = {},           -- [itemID] = min unit price (copper)
    VendorPrices = {},       -- [itemID] = vendorBuyPrice (copper), filled when visiting vendor
    TrainerCosts = {},       -- [spellID or recipeName] = cost (copper), optional
    IncludeHolidayRecipes = false,
    scanPerFrame = 100,      -- AH scan: items per batch (50-200, like EasyAuction)
    TargetSkillStart = 1,
    TargetSkillEnd = 350,
    IncludeSourceTrainer = true,
    IncludeSourceAH = true,
    IncludeSourceVendor = false,
    IncludeSourceQuest = false,
    IncludeSourceUnknown = false,
}

function L.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffProfLevelHelper|r: " .. tostring(msg))
    end
end

-- Slash commands
SLASH_PROFLEVELHELPER1 = "/plh"
SLASH_PROFLEVELHELPER2 = "/proflevelhelper"
-- Event frame (AH scan is one-shot inside Scan.lua; only merchant here)
local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        L.OnMerchantShow()
    end
end)

SlashCmdList["PROFLEVELHELPER"] = function(msg)
    msg = msg and strtrim(msg):lower() or ""
    if msg == "scan" or msg == "ah" then
        L.ScanAH()
    elseif msg == "list" or msg == "show" then
        L.ShowResultList()
    elseif msg == "options" or msg == "config" then
        L.OpenOptions()
    else
        L.Print("Usage: /plh scan | list | options")
        L.Print("  scan   - Scan auction house (run at AH)")
        L.Print("  list   - Show cheapest leveling list for current profession (open profession first)")
        L.Print("  options - Toggle holiday recipes and open settings")
    end
end
