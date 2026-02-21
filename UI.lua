--[[
  UI: options (holiday recipes), result list frame.
]]

local L = ProfLevelHelper

-- Scan progress frame (shown during AH scan)
function L.ShowScanProgress()
    local f = L.ScanProgressFrame
    if not f then
        f = CreateFrame("Frame", "ProfLevelHelperScanProgress", UIParent, "BackdropTemplate")
        L.ScanProgressFrame = f
        f:SetSize(360, 110)
        f:SetPoint("CENTER", 0, 150)
        f:SetFrameStrata("DIALOG")
        -- EasyAuction-like dark background
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:SetBackdropColor(0, 0, 0, 0.9)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("ProfLevelHelper (扫描拍卖行)")
        f.title = title
        
        local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        status:SetPoint("TOP", 0, -42)
        status:SetText("准备中...")
        f.status = status
        
        local bar = CreateFrame("StatusBar", nil, f)
        bar:SetSize(310, 20)
        bar:SetPoint("TOP", 0, -66)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        -- EasyAuction green ish color
        bar:SetStatusBarColor(0.2, 0.8, 0.2)
        
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bar)
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        -- Percentage text in the middle of the bar
        local pctText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        pctText:SetPoint("CENTER", 0, 0)
        pctText:SetText("0%")
        f.pctText = pctText
        
        f.bar = bar
        
        -- Border for status bar (optional aesthetic)
        local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", 2, -2)
        border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
    end
    f.status:SetText("准备发送请求给服务器...")
    f.pctText:SetText("0%")
    f.bar:SetValue(0)
    f:Show()
    
    if f.prepareTicker then f.prepareTicker:Cancel() end
    local start = GetTime()
    f.prepareTicker = C_Timer and C_Timer.NewTicker(0.1, function()
        if not f:IsShown() or not L.AHScanRunning then return end
        local txt = f.status:GetText()
        if txt and (string.match(txt, "^准备发送") or string.match(txt, "^正在等待响应")) then
            f.status:SetText(string.format("正在等待响应 (这可能会造成暂时的画面停止)... %.1fs", GetTime() - start))
        end
    end)
end

function L.UpdateScanProgress(current, total, elapsed, customStatus)
    local f = L.ScanProgressFrame
    if not f or not f:IsShown() then return end
    if f.prepareTicker then f.prepareTicker:Cancel() f.prepareTicker = nil end
    elapsed = elapsed or 0
    if total and total > 0 then
        local pct = math.floor(100 * current / total)
        f.bar:SetMinMaxValues(0, total)
        f.bar:SetValue(current)
        f.pctText:SetText(pct .. "%")
        if customStatus then
            f.status:SetText(customStatus)
        else
            f.status:SetText(string.format("处理中: %d / %d  (用时 %.1fs)", current, total, elapsed))
        end
    else
        f.status:SetText(string.format("准备处理数据... %.1fs", elapsed))
    end
end

function L.HideScanProgress()
    local f = L.ScanProgressFrame
    if f then
        if f.prepareTicker then f.prepareTicker:Cancel() f.prepareTicker = nil end
        f:Hide()
    end
end

function L.UpdateScanButtonState(customText)
    local btn = L.ScanAHButton
    if not btn then return end
    if L.AHScanRunning then
        btn:SetEnabled(false)
        btn:SetText(customText or "扫描中...")
    else
        btn:SetEnabled(true)
        btn:SetText("扫描拍卖行")
    end
end

function L.OpenOptions()
    if L.OptionsFrame and L.OptionsFrame:IsShown() then
        L.OptionsFrame:Hide()
        return
    end
    local f = L.OptionsFrame or CreateFrame("Frame", "ProfLevelHelperOptions", UIParent, "BackdropTemplate")
    L.OptionsFrame = f
    f:SetSize(320, 150)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f.title or f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("ProfLevelHelper")
    f.title = title

    local scanBtn = f.scanBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scanBtn:SetSize(100, 22)
    scanBtn:SetPoint("TOPLEFT", 24, -40)
    scanBtn:SetText("扫描拍卖行")
    scanBtn:SetScript("OnClick", function()
        if L.AHScanRunning then return end
        L.ScanAH()
    end)
    f.scanBtn = scanBtn
    L.ScanAHButton = scanBtn

    local cb = f.checkHoliday or CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 24, -70)
    cb:SetChecked(ProfLevelHelperDB.IncludeHolidayRecipes)
    cb:SetScript("OnClick", function()
        ProfLevelHelperDB.IncludeHolidayRecipes = cb:GetChecked()
    end)
    f.checkHoliday = cb
    local cbLabel = cb.label or cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText("计算时包含节日/季节性配方")
    cb.label = cbLabel

    local close = f.closeBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 22)
    close:SetPoint("BOTTOM", 0, 16)
    close:SetText("关闭")
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn = close

    L.UpdateScanButtonState()
    f:Show()
end

function L.ShowResultList()
    local includeHoliday = ProfLevelHelperDB.IncludeHolidayRecipes
    local result, profName, currentSkill = L.BuildLevelingTable(includeHoliday)
    if not result or #result == 0 then
        L.Print(profName and ("在技能点 " .. tostring(currentSkill) .. " 下没有可用于冲 "..profName.." 的配方。") or "请先打开专业技能窗口。")
        return
    end

    if L.ResultFrame and L.ResultFrame:IsShown() then
        L.ResultFrame:Hide()
        return
    end

    local f = L.ResultFrame or CreateFrame("Frame", "ProfLevelHelperResult", UIParent, "BackdropTemplate")
    L.ResultFrame = f
    f:SetSize(460, 380)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f.title or f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(profName and (profName .. " (当前熟练度 " .. tostring(currentSkill) .. ") - 推荐充点方案") or "推荐列表")
    f.title = title

    local scroll = f.scroll or CreateFrame("ScrollFrame", "ProfLevelHelperResultScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -36)
    scroll:SetPoint("BOTTOMRIGHT", -36, 36)
    f.scroll = scroll

    local content = f.content or CreateFrame("Frame", nil, scroll)
    content:SetSize(scroll:GetWidth() - 20, 1)
    scroll:SetScrollChild(content)
    f.content = content

    local function CopperToGold(c)
        if not c or c == 0 then return "0 铜" end
        local g = math.floor(c / 10000)
        local s = math.floor((c % 10000) / 100)
        local co = c % 100
        if g > 0 then return g .. "金" .. s .. "银" .. co .. "铜"
        elseif s > 0 then return s .. "银" .. co .. "铜"
        else return co .. "铜" end
    end

    local y = 0
    local lineHeight = 18
    for i = 1, math.min(#result, 50) do
        local r = result[i]
        local line = content.lines and content.lines[i] or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if not content.lines then content.lines = {} end
        content.lines[i] = line
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetJustifyH("LEFT")
        line:SetText(("%d. %s  | 成功率 %.0f%%  | 单点成本: %s  (单份花费: %s)"):format(
            i, r.name or "?", (r.chance or 0) * 100, CopperToGold(r.costPerSkillPoint), CopperToGold(r.recipeCost)))
        line:SetWidth(scroll:GetWidth() - 24)
        y = y + lineHeight
    end
    content:SetHeight(y)

    local close = f.closeBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 22)
    close:SetPoint("BOTTOM", 0, 12)
    close:SetText("关闭")
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn = close

    f:Show()
end
