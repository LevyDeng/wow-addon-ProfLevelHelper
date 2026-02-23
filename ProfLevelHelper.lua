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
    db.AHPriceCurve = db.AHPriceCurve or {}
    db.VendorPrices = db.VendorPrices or {}
    if ProfLevelHelper_VendorPrices and type(ProfLevelHelper_VendorPrices) == "table" then
        for k, v in pairs(ProfLevelHelper_VendorPrices) do
            if type(k) == "number" and type(v) == "number" and v > 0 then
                db.VendorPrices[k] = v
            end
        end
    end
    db.NameToID = db.NameToID or {}
    db.IDToName = db.IDToName or {}
    db.TrainerCosts = db.TrainerCosts or {}
    if db.UseTieredPricing == nil then db.UseTieredPricing = true end
    if db.TieredPricingMaxRounds == nil then db.TieredPricingMaxRounds = 10 end
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
    db.AHSellBackBlacklist = db.AHSellBackBlacklist or {}
    db.AHSellBackWhitelist = db.AHSellBackWhitelist or {}

    if db.MinAHQuantity == nil then db.MinAHQuantity = 40 end
    if db.IncludeHolidayRecipes == nil then db.IncludeHolidayRecipes = false end
    if db.scanPerFrame == nil then db.scanPerFrame = 100 end
    if db.IgnoredOutlierPercent == nil then db.IgnoredOutlierPercent = 0.10 end
    if db.TargetSkillStart == nil then db.TargetSkillStart = 1 end
    if db.TargetSkillEnd == nil then db.TargetSkillEnd = 400 end

    -- Source filters: default to trainer + AH only for out-of-box experience
    if db.IncludeSourceTrainer == nil then db.IncludeSourceTrainer = true end
    if db.IncludeSourceAH == nil then db.IncludeSourceAH = true end
    if db.IncludeSourceVendor == nil then db.IncludeSourceVendor = false end
    if db.IncludeSourceQuest == nil then db.IncludeSourceQuest = false end
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
    elseif msg == "recordvendor" or msg == "vendor" then
        local n = (ProfLevelHelper and ProfLevelHelper.RecordVendorPrices and ProfLevelHelper.RecordVendorPrices()) or 0
        L.Print(string.format("已记录当前商人售价（仅金币）: %d 种物品。使用 /plh dumpvendor 导出为 Lua 保存到 VendorPrices.lua。", n))
    elseif msg == "dumpvendor" then
        if L.ShowVendorDump then L.ShowVendorDump() end
    elseif msg == "options" or msg == "config" then
        L.OpenOptions()
    elseif msg == "debug" then
        L.PrintDebugInfo()
    elseif msg == "testlearn" then
        if L.TestRecipeLearnLevels then L.TestRecipeLearnLevels() end
    elseif msg == "testcost" or msg:match("^testcost ") then
        local skill = msg:match("^testcost%s+(%d+)")
        if not L.TestCostAtSkill then
            L.Print("testcost 未加载，请确认已打开专业技能窗口后重载界面 /reload")
        else
            L.Print("正在执行 testcost，等级: " .. (skill or "175"))
            local ok, err = pcall(function() L.TestCostAtSkill(skill) end)
            if not ok then L.Print("testcost 报错: " .. tostring(err)) end
        end
    else
        L.Print("Usage: /plh scan | list | options | debug | testlearn | testcost [等级]")
        L.Print("  scan    - 扫描拍卖行")
        L.Print("  list    - 显示推荐冲级列表")
        L.Print("  options - 打开设置界面")
        L.Print("  debug   - 打印调试信息（故障排查用）")
        L.Print("  testlearn - 检测配方学习等级来源(ala vs 本插件)，需先打开专业窗口")
        L.Print("  testcost [等级] - 在指定等级打印各配方单次/升1级成本，默认175")
        L.Print("  recordvendor - 打开商人窗口后执行，记录当前商人售价")
        L.Print("  dumpvendor - 将已记录的商人售价导出为 Lua，复制保存为 VendorPrices.lua")
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
