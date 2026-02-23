--[[
  UI: options (holiday recipes), result list frame.
]]

local L = ProfLevelHelper

function L.FormatAHScanTime()
    local t = ProfLevelHelperDB and ProfLevelHelperDB.AHScanTime
    if t and t > 0 then
        if date then
            local ok, s = pcall(date, "%Y-%m-%d %H:%M", t)
            return ok and s or tostring(t)
        end
        return tostring(t)
    end
    return "Never"
end

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
    f:SetSize(320, 455)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    -- Make sure it floats visually above ResultFrame
    if L.ResultFrame then f:SetFrameLevel(L.ResultFrame:GetFrameLevel() + 10) end
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0, 0, 0, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- ScrollFrame so options content can scroll when it doesn't fit
    local scroll = f.optionsScroll or CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", -32, 58)
    f.optionsScroll = scroll
    local content = f.optionsScrollChild
    if not content then
        content = CreateFrame("Frame", nil, scroll)
        content:SetSize(260, 480)
        scroll:SetScrollChild(content)
        f.optionsScrollChild = content
    end

    local title = f.title or f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("ProfLevelHelper (设置选项)")
    f.title = title

    local scanBtn = f.scanBtn or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    scanBtn:SetSize(120, 22)
    scanBtn:SetPoint("TOPLEFT", 24, -40)
    scanBtn:SetText("全量扫描拍卖行")
    scanBtn:SetScript("OnClick", function()
        if L.AHScanRunning then return end
        L.ScanAH()
    end)
    f.scanBtn = scanBtn
    L.ScanAHButton = scanBtn

    local cb = f.checkHoliday or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 24, -70)
    cb:SetChecked(ProfLevelHelperDB.IncludeHolidayRecipes)
    cb:SetScript("OnClick", function()
        ProfLevelHelperDB.IncludeHolidayRecipes = cb:GetChecked()
        if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
    end)
    f.checkHoliday = cb
    local cbLabel = cb.label or cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText("规划路线时包含节日配方")
    cb.label = cbLabel

    -- Input Start
    local startLabel = f.startLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    startLabel:SetPoint("TOPLEFT", 24, -110)
    startLabel:SetText("规划起点 (当前等级):")
    f.startLabel = startLabel
    local startInput = f.startInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    startInput:SetSize(40, 20)
    startInput:SetPoint("LEFT", startLabel, "RIGHT", 10, 0)
    startInput:SetAutoFocus(false)
    startInput:SetNumeric(true)
    startInput:SetText(tostring(ProfLevelHelperDB.TargetSkillStart or 1))
    startInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then 
            ProfLevelHelperDB.TargetSkillStart = val 
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
        end
    end)
    f.startInput = startInput

    -- Input End
    local endLabel = f.endLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    endLabel:SetPoint("TOPLEFT", 24, -140)
    endLabel:SetText("规划终点 (目标满级):")
    f.endLabel = endLabel
    local endInput = f.endInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    endInput:SetSize(40, 20)
    endInput:SetPoint("LEFT", endLabel, "RIGHT", 10, 0)
    endInput:SetAutoFocus(false)
    endInput:SetNumeric(true)
    endInput:SetText(tostring(ProfLevelHelperDB.TargetSkillEnd or 450))
    endInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then 
            ProfLevelHelperDB.TargetSkillEnd = val 
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
        end
    end)
    f.endInput = endInput

    -- Input Outlier Percent
    local pctLabel = f.pctLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pctLabel:SetPoint("TOPLEFT", 24, -170)
    pctLabel:SetText("异常低价过滤比例 (%):")
    f.pctLabel = pctLabel
    local pctInput = f.pctInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    pctInput:SetSize(40, 20)
    pctInput:SetPoint("LEFT", pctLabel, "RIGHT", 10, 0)
    pctInput:SetAutoFocus(false)
    pctInput:SetNumeric(true)
    local currPct = ProfLevelHelperDB.IgnoredOutlierPercent
    if currPct == nil then currPct = 0.10 end
    if currPct > 1 then
        ProfLevelHelperDB.IgnoredOutlierPercent = currPct / 100
        currPct = currPct / 100
    end
    currPct = math.max(0, math.min(100, math.floor(currPct * 100)))
    pctInput:SetText(tostring(currPct))
    pctInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then 
            ProfLevelHelperDB.IgnoredOutlierPercent = val / 100.0 
        end
    end)
    f.pctInput = pctInput

    -- Min AH quantity for materials (skipped automatically when tiered pricing is active)
    local minQtyLabel = f.minQtyLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minQtyLabel:SetPoint("TOPLEFT", 24, -200)
    minQtyLabel:SetText("材料在拍卖行中的最小存在数量 (开启阶梯价格时自动忽略):")
    f.minQtyLabel = minQtyLabel
    local minQtyInput = f.minQtyInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    minQtyInput:SetSize(50, 20)
    minQtyInput:SetPoint("LEFT", minQtyLabel, "RIGHT", 10, 0)
    minQtyInput:SetAutoFocus(false)
    minQtyInput:SetNumeric(true)
    minQtyInput:SetText(tostring(ProfLevelHelperDB.MinAHQuantity or 50))
    minQtyInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then
            ProfLevelHelperDB.MinAHQuantity = val
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
        end
    end)
    f.minQtyInput = minQtyInput

    -- Titan Fragment: value per fragment (copper), default 8 silver
    local fragLabel = f.fragLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fragLabel:SetPoint("TOPLEFT", 24, -230)
    fragLabel:SetText("泰坦碎片单价(铜):")
    f.fragLabel = fragLabel
    local fragInput = f.fragInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    fragInput:SetSize(60, 20)
    fragInput:SetPoint("LEFT", fragLabel, "RIGHT", 10, 0)
    fragInput:SetAutoFocus(false)
    fragInput:SetNumeric(true)
    fragInput:SetText(tostring(ProfLevelHelperDB.FragmentValueInCopper or 800))
    fragInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then
            ProfLevelHelperDB.FragmentValueInCopper = val
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
        end
    end)
    f.fragInput = fragInput

    -- Sell-back method: vendor or AH (affects net cost calculation)
    local sellBackLabel = f.sellBackLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sellBackLabel:SetPoint("TOPLEFT", 24, -255)
    sellBackLabel:SetText("回血方式:")
    f.sellBackLabel = sellBackLabel
    local cbVendor = f.cb_sellBackVendor or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbVendor:SetPoint("LEFT", sellBackLabel, "RIGHT", 8, 0)
    cbVendor:SetChecked(ProfLevelHelperDB.SellBackMethod ~= "ah")
    cbVendor:SetScript("OnClick", function()
        ProfLevelHelperDB.SellBackMethod = "vendor"
        if f.cb_sellBackAH then f.cb_sellBackAH:SetChecked(false) end
        if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
    end)
    f.cb_sellBackVendor = cbVendor
    local lblV = cbVendor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblV:SetPoint("LEFT", cbVendor, "RIGHT", 2, 0)
    lblV:SetText("卖店")
    local cbAH = f.cb_sellBackAH or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbAH:SetPoint("LEFT", lblV, "RIGHT", 16, 0)
    cbAH:SetChecked(ProfLevelHelperDB.SellBackMethod == "ah")
    cbAH:SetScript("OnClick", function()
        ProfLevelHelperDB.SellBackMethod = "ah"
        if f.cb_sellBackVendor then f.cb_sellBackVendor:SetChecked(false) end
        if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
    end)
    f.cb_sellBackAH = cbAH
    local lblA = cbAH:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblA:SetPoint("LEFT", cbAH, "RIGHT", 2, 0)
    lblA:SetText("拍卖")

    -- AH sell-back blacklist: show count and "View blacklist" button (clear is in detail UI)
    local blLabel = f.blLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blLabel:SetPoint("TOPLEFT", 24, -272)
    blLabel:SetText("AH回血黑名单:")
    f.blLabel = blLabel
    local blCountText = f.blCountText or content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blCountText:SetPoint("LEFT", blLabel, "RIGHT", 6, 0)
    f.blCountText = blCountText
    local blDetailBtn = f.blDetailBtn or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    blDetailBtn:SetSize(90, 20)
    blDetailBtn:SetPoint("LEFT", blCountText, "RIGHT", 12, 0)
    blDetailBtn:SetText("查看黑名单")
    blDetailBtn:SetScript("OnClick", function()
        if L.ShowAHSellBackBlacklistDetail then L.ShowAHSellBackBlacklistDetail() end
    end)
    f.blDetailBtn = blDetailBtn

    -- Source Filters
    local yOfs = -302
    local function createCheckbox(key, text)
        local cb = f["cb_"..key] or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 24, yOfs)
        if ProfLevelHelperDB[key] == nil then ProfLevelHelperDB[key] = false end
        cb:SetChecked(ProfLevelHelperDB[key])
        cb:SetScript("OnClick", function()
            ProfLevelHelperDB[key] = cb:GetChecked()
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
        end)
        f["cb_"..key] = cb
        local cbLabel = cb.label or cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cbLabel:SetText(text)
        cb.label = cbLabel
        yOfs = yOfs - 25
    end

    createCheckbox("IncludeSourceTrainer", "包含训练师图纸")
    createCheckbox("IncludeSourceAH", "包含拍卖行图纸")
    createCheckbox("IncludeSourceVendor", "包含NPC出售图纸")
    createCheckbox("IncludeSourceQuest", "包含任务奖励图纸")
    createCheckbox("IncludeSourceUnknown", "包含未知/打怪掉落图纸")
    createCheckbox("UseTieredPricing", "使用动态阶梯价格（需先扫描拍卖行）")

    -- Tiered pricing max iterations (only used when UseTieredPricing is on)
    local roundsLabel = f.tieredRoundsLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roundsLabel:SetPoint("TOPLEFT", 24, yOfs)
    roundsLabel:SetText("阶梯价格迭代轮数 (1-100):")
    f.tieredRoundsLabel = roundsLabel
    local roundsInput = f.tieredRoundsInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    roundsInput:SetSize(40, 20)
    roundsInput:SetPoint("LEFT", roundsLabel, "RIGHT", 10, 0)
    roundsInput:SetAutoFocus(false)
    roundsInput:SetNumeric(true)
    local currRounds = ProfLevelHelperDB.TieredPricingMaxRounds
    if currRounds == nil or type(currRounds) ~= "number" or currRounds < 1 then currRounds = 10 end
    currRounds = math.min(100, math.max(1, math.floor(currRounds)))
    ProfLevelHelperDB.TieredPricingMaxRounds = currRounds
    roundsInput:SetText(tostring(currRounds))
    roundsInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 100 then
            ProfLevelHelperDB.TieredPricingMaxRounds = math.floor(val)
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
        end
    end)
    f.tieredRoundsInput = roundsInput
    yOfs = yOfs - 22

    local feedback = f.feedbackText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    feedback:SetPoint("BOTTOM", 0, 38)
    feedback:SetText("反馈邮箱: ptrees@126.com")
    f.feedbackText = feedback

    local close = f.closeBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 22)
    close:SetPoint("BOTTOM", 0, 16)
    close:SetText("关闭")
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn = close

    if f.cb_sellBackVendor and f.cb_sellBackAH then
        f.cb_sellBackVendor:SetChecked(ProfLevelHelperDB.SellBackMethod ~= "ah")
        f.cb_sellBackAH:SetChecked(ProfLevelHelperDB.SellBackMethod == "ah")
    end
    local nBl = 0
    if ProfLevelHelperDB.AHSellBackBlacklist then
        for _ in pairs(ProfLevelHelperDB.AHSellBackBlacklist) do nBl = nBl + 1 end
    end
    if f.blCountText then f.blCountText:SetText("已屏蔽 " .. nBl .. " 种") end
    L.UpdateScanButtonState()
    f:Show()
end

-- Blacklist detail UI: list each blacklisted item with [Remove], and [Clear all] button
function L.ShowAHSellBackBlacklistDetail()
    local bl = ProfLevelHelperDB.AHSellBackBlacklist or {}
    local list = {}
    for id in pairs(bl) do list[#list + 1] = id end
    table.sort(list)

    local f = L.BlacklistDetailFrame
    if not f then
        f = CreateFrame("Frame", "ProfLevelHelperBlacklistDetail", UIParent, "BackdropTemplate")
        L.BlacklistDetailFrame = f
        f:SetSize(340, 380)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        if L.OptionsFrame then f:SetFrameLevel(L.OptionsFrame:GetFrameLevel() + 5) end
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:SetBackdropColor(0, 0, 0, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("黑名单详情 (AH回血)")
        f.title = title

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -44)
        scroll:SetPoint("BOTTOMRIGHT", -32, 52)
        f.scroll = scroll
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(280, 1)
        scroll:SetScrollChild(content)
        f.scrollContent = content

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(100, 22)
        clearBtn:SetPoint("BOTTOM", -60, 16)
        clearBtn:SetText("清空黑名单")
        clearBtn:SetScript("OnClick", function()
            ProfLevelHelperDB.AHSellBackBlacklist = {}
            local opt = L.OptionsFrame
            if opt and opt.blCountText then opt.blCountText:SetText("已屏蔽 0 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowAHSellBackBlacklistDetail()
        end)
        f.clearBtn = clearBtn

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOM", 60, 16)
        closeBtn:SetText("关闭")
        closeBtn:SetScript("OnClick", function() f:Hide() end)
        f.closeBtn = closeBtn
    end

    local content = f.scrollContent
    content:SetHeight(1)
    for k, row in pairs(content) do
        if type(row) == "table" and row.Hide then row:Hide() end
    end

    local ROW_H = 22
    local y = 0
    for _, itemID in ipairs(list) do
        local name = GetItemInfo(itemID) or ("Item " .. tostring(itemID))
        local row = content["row_" .. itemID]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetHeight(ROW_H)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT", 8, 0)
            row.label:SetPoint("RIGHT", -70, 0)
            row.label:SetWordWrap(false)
            row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.btn:SetSize(50, 18)
            row.btn:SetPoint("RIGHT", 0, 0)
            row.btn:SetText("移除")
            content["row_" .. itemID] = row
        end
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        row.label:SetText(name)
        row.btn:SetScript("OnClick", function()
            if ProfLevelHelperDB.AHSellBackBlacklist then ProfLevelHelperDB.AHSellBackBlacklist[itemID] = nil end
            local nBl = 0
            if ProfLevelHelperDB.AHSellBackBlacklist then
                for _ in pairs(ProfLevelHelperDB.AHSellBackBlacklist) do nBl = nBl + 1 end
            end
            local opt = L.OptionsFrame
            if opt and opt.blCountText then opt.blCountText:SetText("已屏蔽 " .. nBl .. " 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowAHSellBackBlacklistDetail()
        end)
        row:Show()
        y = y + ROW_H
    end
    content:SetHeight(math.max(1, y))
    f.clearBtn:SetShown(#list > 0)
    f:Show()
end

function L.ShowResultList()
    local includeHoliday = ProfLevelHelperDB.IncludeHolidayRecipes
    local _, pCurr, pMax = L.GetCurrentProfessionSkill()
    local startSkill = ProfLevelHelperDB.TargetSkillStart or pCurr or 1
    local endSkill = ProfLevelHelperDB.TargetSkillEnd or pMax or 350

    -- Collect all item IDs from the recipe list so we can preload them via
    -- Item:ContinueOnItemLoad before calculating, ensuring GetItemInfo is
    -- populated for every item and the route result is consistent on every run.
    local recipes0 = L.GetRecipeList(includeHoliday)
    if not recipes0 then
        L.Print("请先打开专业技能窗口。")
        return
    end
    local ids, seen = {}, {}
    local function collectID(id)
        if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    for _, rec in ipairs(recipes0) do
        collectID(rec.createdItemID)
        for _, r in ipairs(rec.reagents or {}) do collectID(r.itemID) end
        for _, rid in ipairs(rec.recipeItemIDs or {}) do collectID(rid) end
    end

    L.EnsureItemsLoaded(ids, function()
        -- Lua has no try/catch; pcall(f) returns ok, ... or false, errmsg.
        local ok, a, b, c, d, e = pcall(function()
            return L.CalculateLevelingRoute(startSkill, endSkill, includeHoliday)
        end)
        if not ok then
            L.Print("|cffff0000ProfLevelHelper 错误: " .. tostring(a) .. "|r")
            return
        end
        local route, profName, actualStart, actualEnd, totalCost = a, b, c, d, e
        if not route or #route == 0 then
            local s = actualStart or startSkill or "?"
            local e = actualEnd or endSkill or "?"
            L.Print(profName and ("无法找到一条从 " .. s .. " 到 ".. e .. " 的冲级路线，可能是缺乏有效配方或者拍卖行数据不足。") or "请先打开专业技能窗口。")
            return
        end

        if not ProfLevelHelperDB.AHPrices or next(ProfLevelHelperDB.AHPrices) == nil then
            L.Print("|cffff2222警告：尚未扫描拍卖行物价，所有的消耗计算可能存在极大的误差（按 NPC 售出价格预估），请尽快去主城拍卖行点击扫描一次！|r")
        end

        if not L.ResultFrame then
            local f = CreateFrame("Frame", "ProfLevelHelperResult", UIParent, "BackdropTemplate")
            L.ResultFrame = f
            f:SetSize(600, 480)
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

            local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -12)
            f.title = title

            local ahTimeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ahTimeLabel:SetPoint("TOPLEFT", 20, -30)
            f.ahTimeLabel = ahTimeLabel

            local scroll = CreateFrame("ScrollFrame", "ProfLevelHelperResultScroll", f, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 20, -44)
            scroll:SetPoint("BOTTOMRIGHT", -36, 46)
            f.scroll = scroll

            local content = CreateFrame("Frame", nil, scroll)
            content:SetSize(scroll:GetWidth() - 20, 1)
            scroll:SetScrollChild(content)
            f.content = content

            local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            close:SetSize(100, 22)
            close:SetPoint("BOTTOMRIGHT", -20, 12)
            close:SetText("关闭")
            close:SetScript("OnClick", function() f:Hide() end)
            f.closeBtn = close

            local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            exportBtn:SetSize(100, 22)
            exportBtn:SetPoint("BOTTOM", 0, 12)
            exportBtn:SetText("复制到剪贴板")
            exportBtn:SetScript("OnClick", function()
                if L.ShowExportFrame then L.ShowExportFrame() end
            end)
            f.exportBtn = exportBtn

            local optionsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            optionsBtn:SetSize(100, 22)
            optionsBtn:SetPoint("BOTTOMLEFT", 20, 12)
            optionsBtn:SetText("更改选项")
            optionsBtn:SetScript("OnClick", function() L.OpenOptions() end)
            f.optionsBtn = optionsBtn
        end

        local f = L.ResultFrame

        local function CopperToGold(c)
            if type(c) ~= "number" or c == 0 then return "0 铜" end
            c = math.floor(c + 0.5)
            local g = math.floor(c / 10000)
            local s = math.floor((c % 10000) / 100)
            local co = math.floor(c % 100)
            local str = ""
            if g > 0 then str = str .. "|cffffdf00" .. g .. "金|r " end
            if s > 0 or g > 0 then str = str .. "|cffc0c0c0" .. s .. "银|r " end
            str = str .. "|cffb87333" .. co .. "铜|r"
            return str
        end

        f.title:SetText(profName and (profName .. "路线 " .. actualStart .. " -> " .. actualEnd .. " (预测花费 " .. CopperToGold(totalCost) .. ")") or "推荐列表")
        f.ahTimeLabel:SetText("AH data updated: " .. L.FormatAHScanTime())
        local content = f.content
        local scroll = f.scroll

        if content.lines then
            for _, g in ipairs(content.lines) do g:Hide() end
        end
        if content.segmentBtns then
            for _, b in ipairs(content.segmentBtns) do b:Hide() end
        end
        content.lines = {}
        content.segmentBtns = {}

        local y = 0
        for i, seg in ipairs(route) do
            local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            table.insert(content.lines, line)
            line:SetPoint("TOPLEFT", 0, -y)
            line:SetJustifyH("LEFT")

            local reqStr = ""
            local alaAgent = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent
            for _, r in ipairs(seg.recipe.reagents or {}) do
                local itemName = r.name
                if not itemName and r.itemID then
                    if alaAgent and alaAgent.item_name then
                        itemName = alaAgent.item_name(r.itemID)
                    end
                    if not itemName then
                        local iname = GetItemInfo(r.itemID)
                        if iname then itemName = iname end
                    end
                end
                if not itemName then
                    itemName = "ID:" .. tostring(r.itemID)
                end
                local totQty = math.ceil(r.count * seg.totalCrafts)
                reqStr = reqStr .. itemName .. "*" .. totQty .. " "
            end
            if reqStr == "" then reqStr = "无或由材料制成" end

            local rNameC = (seg.recipe.recipeName or seg.recipe.name) or "?"
            if not seg.recipe.isKnown then
                rNameC = "|cffff2222[未学]|r" .. rNameC .. " |cff888888(获取: " .. (seg.recSource or "未知") .. ")|r"
            else
                rNameC = "|cff22ff22[已学]|r" .. rNameC
            end

            line:SetText(("[%d-%d] %s x%.0f次\n  配方: %s | 制作: %s | 回血(卖NPC: %s | AH: %s) | 净花费: %s\n  材料: %s"):format(
                seg.startSkill, seg.endSkill, rNameC, seg.totalCrafts,
                CopperToGold(seg.totalRecCost or 0), CopperToGold(seg.totalMatCost or 0),
                CopperToGold(seg.totalSellBackVendor or 0), CopperToGold(seg.totalSellBackAH or 0), CopperToGold(seg.segmentTotalCost or 0),
                reqStr))
            line:SetWidth(scroll:GetWidth() - 24)
            line:Show()

            local currentHeight = line:GetStringHeight()
            if not currentHeight or currentHeight == 0 then currentHeight = 38 end
            if ProfLevelHelperDB.SellBackMethod == "ah" and seg.recipe.createdItemID then
                local bl = ProfLevelHelperDB.AHSellBackBlacklist or {}
                local isBlacklisted = bl[seg.recipe.createdItemID]
                local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                btn:SetSize(78, 18)
                btn:SetPoint("TOPRIGHT", content, "TOPLEFT", scroll:GetWidth() - 82, -y)
                btn:SetText(isBlacklisted and "[改回AH回血]" or "[不按AH回血]")
                btn.itemID = seg.recipe.createdItemID
                btn:SetScript("OnClick", function()
                    local id = btn.itemID
                    if id and ProfLevelHelperDB.AHSellBackBlacklist then
                        if isBlacklisted then
                            ProfLevelHelperDB.AHSellBackBlacklist[id] = nil
                        else
                            ProfLevelHelperDB.AHSellBackBlacklist[id] = true
                        end
                        L.ShowResultList()
                    end
                end)
                btn:Show()
                table.insert(content.segmentBtns, btn)
            end
            y = y + currentHeight + 16
        end

        local sumLine = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        table.insert(content.lines, sumLine)
        sumLine:SetPoint("TOPLEFT", 0, -(y + 10))
        sumLine:SetJustifyH("LEFT")
        sumLine:SetText("============\n总计预计花费: " .. CopperToGold(totalCost) .. "\n============")
        sumLine:Show()

        y = y + 80
        content:SetHeight(y)

        L.CurrentRouteData = {
            route = route,
            startS = actualStart,
            endS = actualEnd,
            totalCost = totalCost,
            profName = profName
        }

        f:Show()
    end, 3.0)
end

function L.ShowExportFrame()
    local data = L.CurrentRouteData
    if not data then return end
    
    local f = L.ExportFrame
    if not f then
        f = CreateFrame("Frame", "ProfLevelHelperExport", UIParent, "BackdropTemplate")
        L.ExportFrame = f
        f:SetSize(500, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        if L.ResultFrame then f:SetFrameLevel(L.ResultFrame:GetFrameLevel() + 20) end
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:SetBackdropColor(0, 0, 0, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -16)
        title:SetText("按下 Ctrl+C 复制以下文本")
        
        local sf = CreateFrame("ScrollFrame", "ProfLevelHelperExportScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 20, -40)
        sf:SetPoint("BOTTOMRIGHT", -36, 46)
        
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(430)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.editBox = eb
        
        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetSize(100, 22)
        close:SetPoint("BOTTOM", 0, 12)
        close:SetText("关闭")
        close:SetScript("OnClick", function() f:Hide() end)
    end
    
    local c = data.totalCost
    local g = math.floor(c / 10000)
    local s = math.floor((c % 10000) / 100)
    local co = math.floor(c % 100)
    local costStr = string.format("%d金 %d银 %d铜", g, s, co)
    
    local ahTimeStr = L.FormatAHScanTime and L.FormatAHScanTime() or "Never"
    local txt = string.format("【ProfLevelHelper】%s冲级路线 (%d -> %d)\n总计花费: %s\nAH data updated: %s\n\n", data.profName, data.startS, data.endS, costStr, ahTimeStr)
    local alaAgent = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent

    for _, seg in ipairs(data.route) do
        local rNameC = (seg.recipe.recipeName or seg.recipe.name) or "?"
        local reqStr = ""
        for _, r in ipairs(seg.recipe.reagents or {}) do
            local itemName = r.name
            if not itemName and r.itemID then
                if alaAgent and alaAgent.item_name then itemName = alaAgent.item_name(r.itemID) end
                if not itemName then local iname = GetItemInfo(r.itemID) if iname then itemName = iname end end
            end
            if not itemName then itemName = "ID:" .. tostring(r.itemID) end
            local totQty = math.ceil(r.count * seg.totalCrafts)
            reqStr = reqStr .. itemName .. "*" .. totQty .. " "
        end
        if reqStr == "" then reqStr = "无或由材料制成" end
        
        local acq = seg.recSource and ("来源:"..seg.recSource) or ""
        local function c2s(c) local C = math.floor((c or 0) + 0.5); local g,s,co = math.floor(C/10000), math.floor((C%10000)/100), math.floor(C%100); return string.format("%d金%d银%d铜", g, s, co) end
        txt = txt .. string.format("[%d-%d] %s x%.0f次 | 配方:%s 制作:%s 回血(卖NPC:%s AH:%s) 净花费:%s | %s - 材料: %s\n", seg.startSkill, seg.endSkill, rNameC, seg.totalCrafts, c2s(seg.totalRecCost), c2s(seg.totalMatCost), c2s(seg.totalSellBackVendor), c2s(seg.totalSellBackAH), c2s(seg.segmentTotalCost), acq, reqStr)
    end
    
    f.editBox:SetText(txt)
    f.editBox:HighlightText()
    f:Show()
end

-- Inject hook button into Blizzard_TradeSkillUI when it loads.
local function CreateTradeSkillButton()
    if not TradeSkillFrame or L.TradeSkillButton then return end
    local btn = CreateFrame("Button", "ProfLevelHelperTradeSkillBtn", TradeSkillFrame, "UIPanelButtonTemplate")
    L.TradeSkillButton = btn
    btn:SetSize(90, 22)
    btn:SetPoint("TOPRIGHT", TradeSkillFrame, "TOPRIGHT", -40, -40)
    btn:SetText("冲点助手")
    btn:SetScript("OnClick", function()
        L.ShowResultList()
    end)
    if alaTradeSkillFrame then
        -- if alaTradeSkill is hooked securely, reposition slightly so we don't overlap their buttons.
        btn:SetPoint("TOPRIGHT", TradeSkillFrame, "TOPRIGHT", -150, -40)
    end
end

-- Dev only: show FragmentCosts as Lua text for copying into FragmentCosts.lua. /plh dumpfragment
function L.ShowFragmentDump()
    local str = (ProfLevelHelper and ProfLevelHelper.ExportFragmentCostsToLuaString and ProfLevelHelper.ExportFragmentCostsToLuaString()) or "ProfLevelHelper_FragmentCosts = {\n}\n"
    local f = L.FragmentDumpFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        L.FragmentDumpFrame = f
        f:SetSize(500, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        f:SetBackdropColor(0, 0, 0, 1)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Fragment data — copy and save as FragmentCosts.lua")
        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetSize(80, 22)
        close:SetPoint("BOTTOM", 0, 12)
        close:SetText("Close")
        close:SetScript("OnClick", function() f:Hide() end)
        local eb = CreateFrame("EditBox", nil, f)
        eb:SetPoint("TOPLEFT", 16, -36)
        eb:SetPoint("BOTTOMRIGHT", -16, 40)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        f.editBox = eb
    end
    f.editBox:SetText(str)
    f.editBox:HighlightText(0, #str)
    f:Show()
end

if IsAddOnLoaded("Blizzard_TradeSkillUI") then
    CreateTradeSkillButton()
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Blizzard_TradeSkillUI" then
            CreateTradeSkillButton()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
