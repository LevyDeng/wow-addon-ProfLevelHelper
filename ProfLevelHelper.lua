--[[
  ProfLevelHelper - Profession leveling assistant.
  Considers: AH prices (materials + recipes), NPC vendor recipe prices, trainer recipe costs.
]]

local ADDON_NAME = "ProfLevelHelper"
ProfLevelHelper = ProfLevelHelper or {}
local L = ProfLevelHelper

-- Default saved DB initialize function
local function InitDB()
    ProfLevelHelperDB = ProfLevelHelperDB or {}
    local db = ProfLevelHelperDB
    db.AHPrices = db.AHPrices or {}
    db.AHQty = db.AHQty or {}
    db.VendorPrices = db.VendorPrices or {}
    db.NameToID = db.NameToID or {}
    db.TrainerCosts = db.TrainerCosts or {}
    -- Fragment data comes only from FragmentCosts.lua; replace SavedVariables so old/wrong data is cleared.
    db.FragmentCosts = {}
    if ProfLevelHelper_FragmentCosts and type(ProfLevelHelper_FragmentCosts) == "table" then
        for k, v in pairs(ProfLevelHelper_FragmentCosts) do
            if type(k) == "number" and type(v) == "number" and v > 0 then
                db.FragmentCosts[k] = v
            end
        end
    end
    if db.FragmentValueInCopper == nil then db.FragmentValueInCopper = 800 end
    if db.SellBackMethod == nil then db.SellBackMethod = "vendor" end

    if db.MinAHQuantity == nil then db.MinAHQuantity = 50 end
    if db.IncludeHolidayRecipes == nil then db.IncludeHolidayRecipes = false end
    if db.scanPerFrame == nil then db.scanPerFrame = 100 end
    if db.IgnoredOutlierPercent == nil then db.IgnoredOutlierPercent = 0.10 end
    if db.TargetSkillStart == nil then db.TargetSkillStart = 1 end
    if db.TargetSkillEnd == nil then db.TargetSkillEnd = 450 end
    
    -- New source filters: Default to TRUE for common sources so users don't see "empty list"
    if db.IncludeSourceTrainer == nil then db.IncludeSourceTrainer = true end
    if db.IncludeSourceAH == nil then db.IncludeSourceAH = true end
    if db.IncludeSourceVendor == nil then db.IncludeSourceVendor = true end
    if db.IncludeSourceQuest == nil then db.IncludeSourceQuest = true end
    if db.IncludeSourceUnknown == nil then db.IncludeSourceUnknown = false end
end

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
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
    elseif event == "MERCHANT_SHOW" then
        L.OnMerchantShow()
    end
end)

SlashCmdList["PROFLEVELHELPER"] = function(msg)
    msg = msg and strtrim(msg):lower() or ""
    if msg == "scan" or msg == "ah" then
        L.ScanAH()
    elseif msg == "list" or msg == "show" then
        L.ShowResultList()
    elseif msg == "recordfragment" or msg == "fragment" then
        if L.RecordFragmentCosts then L.RecordFragmentCosts() end
    elseif msg == "dumpfragment" then
        if L.ShowFragmentDump then L.ShowFragmentDump() end
    elseif msg == "options" or msg == "config" then
        L.OpenOptions()
    elseif msg == "debug" then
        L.PrintDebugInfo()
    else
        L.Print("Usage: /plh scan | list | options | debug")
        L.Print("  scan    - 扫描拍卖行")
        L.Print("  list    - 显示推荐冲级列表")
        L.Print("  options - 打开设置界面")
        L.Print("  debug   - 打印调试信息（故障排查用）")
        L.Print("Feedback: ptrees@126.com")
    end
end

function L.PrintDebugInfo()
    local db = ProfLevelHelperDB
    if not db then L.Print("错误: 数据库未初始化。") return end
    L.Print("--- 插件调试信息 ---")
    L.Print("AHPrices 数量: " .. L.TableCount(db.AHPrices or {}))
    L.Print("NameToID 数量: " .. L.TableCount(db.NameToID or {}))
    L.Print("过滤系数: " .. (db.IgnoredOutlierPercent or 0.10))
    
    local pName, pCurr, pMax = L.GetCurrentProfessionSkill()
    L.Print(string.format("当前专业: %s (%d/%d)", pName or "未打开专业界面", pCurr or 0, pMax or 0))
    
    if pName then
        local recipes = L.GetRecipeList(db.IncludeHolidayRecipes)
        L.Print("可用配方总数 (当前专业): " .. (recipes and #recipes or 0))
    end
end
