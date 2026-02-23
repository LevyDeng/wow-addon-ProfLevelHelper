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

-- Parse add-input to itemID: number, item link, or name (NameToID from AH scan).
function L.ParseItemIdFromAddInput(str, db)
    if not str or str == "" then return nil end
    str = str:match("^%s*(.-)%s*$") or str
    local id = tonumber(str)
    if id and id > 0 then return id end
    id = str and str:match("item:(%d+)")
    if id then return tonumber(id) end
    if db and db.NameToID and db.NameToID[str] then return db.NameToID[str] end
    return nil
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
    f:SetSize(420, 455)
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
        scroll:SetScrollChild(content)
        f.optionsScrollChild = content
    end
    content:SetSize(360, 480)

    local title = f.title or f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("ProfLevelHelper (设置选项)")
    f.title = title

    L.ScanAHButton = nil

    local cb = f.checkHoliday or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 24, -40)
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
    startLabel:SetPoint("TOPLEFT", 24, -80)
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
    endLabel:SetPoint("TOPLEFT", 24, -110)
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
    pctLabel:SetPoint("TOPLEFT", 24, -140)
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

    -- Min AH quantity for materials (skipped when tiered pricing is on)
    local minQtyLabel = f.minQtyLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minQtyLabel:SetPoint("TOPLEFT", 24, -170)
    minQtyLabel:SetText("材料最小AH数量 (阶梯开启时忽略):")
    f.minQtyLabel = minQtyLabel
    local minQtyInput = f.minQtyInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    minQtyInput:SetSize(60, 20)
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
    fragLabel:SetPoint("TOPLEFT", 24, -200)
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
    sellBackLabel:SetPoint("TOPLEFT", 24, -225)
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

    -- AH sell-back blacklist: label can wrap; count and button on next line
    local blLabel = f.blLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blLabel:SetPoint("TOPLEFT", 24, -242)
    blLabel:SetWidth(332)
    blLabel:SetWordWrap(true)
    blLabel:SetNonSpaceWrap(false)
    blLabel:SetText("AH回血黑名单(一些很难卖出的物品可以加入黑名单, 使用卖店方式回血):")
    f.blLabel = blLabel
    local blCountText = f.blCountText or content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blCountText:SetPoint("TOPLEFT", blLabel, "BOTTOMLEFT", 0, -4)
    f.blCountText = blCountText
    local blDetailBtn = f.blDetailBtn or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    blDetailBtn:SetSize(90, 20)
    blDetailBtn:SetPoint("LEFT", blCountText, "RIGHT", 12, 0)
    blDetailBtn:SetText("查看黑名单")
    blDetailBtn:SetScript("OnClick", function()
        if L.ShowAHSellBackBlacklistDetail then L.ShowAHSellBackBlacklistDetail() end
    end)
    f.blDetailBtn = blDetailBtn

    -- AH sell-back whitelist: only when using vendor sell-back; items in whitelist use AH recovery
    local wlLabel = f.wlLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wlLabel:SetPoint("TOPLEFT", blCountText, "BOTTOMLEFT", 0, -14)
    wlLabel:SetWidth(332)
    wlLabel:SetWordWrap(true)
    wlLabel:SetNonSpaceWrap(false)
    wlLabel:SetText("AH回血白名单(卖店回血时, 名单中的物品强制按AH价回血):")
    f.wlLabel = wlLabel
    local wlCountText = f.wlCountText or content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wlCountText:SetPoint("TOPLEFT", wlLabel, "BOTTOMLEFT", 0, -4)
    f.wlCountText = wlCountText
    local wlDetailBtn = f.wlDetailBtn or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    wlDetailBtn:SetSize(90, 20)
    wlDetailBtn:SetPoint("LEFT", wlCountText, "RIGHT", 12, 0)
    wlDetailBtn:SetText("查看白名单")
    wlDetailBtn:SetScript("OnClick", function()
        if L.ShowAHSellBackWhitelistDetail then L.ShowAHSellBackWhitelistDetail() end
    end)
    f.wlDetailBtn = wlDetailBtn

    -- Tiered pricing and source filters: anchor below whitelist so they never overlap when labels wrap
    local lastCbAnchor = wlCountText
    local gap = 20
    local function createCheckbox(key, text)
        local cb = f["cb_"..key] or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", lastCbAnchor, "BOTTOMLEFT", 0, -gap)
        lastCbAnchor = cb
        gap = (key == "UseTieredPricing") and 47 or 25
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
    end

    createCheckbox("UseTieredPricing", "使用动态阶梯价格（需先扫描拍卖行）")

    -- Source Filters (recipe source)
    createCheckbox("IncludeSourceTrainer", "包含训练师图纸")
    createCheckbox("IncludeSourceAH", "包含拍卖行图纸")
    createCheckbox("IncludeSourceVendor", "包含NPC出售图纸")
    createCheckbox("IncludeSourceQuest", "包含任务奖励图纸")
    createCheckbox("IncludeSourceUnknown", "包含未知/打怪掉落图纸")

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
    local nWl = 0
    if ProfLevelHelperDB.AHSellBackWhitelist then
        for _ in pairs(ProfLevelHelperDB.AHSellBackWhitelist) do nWl = nWl + 1 end
    end
    if f.blCountText then f.blCountText:SetText("已屏蔽 " .. nBl .. " 种") end
    if f.wlCountText then f.wlCountText:SetText("已添加 " .. nWl .. " 种") end
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

        local addRow = CreateFrame("Frame", nil, f)
        addRow:SetSize(300, 24)
        addRow:SetPoint("TOP", 0, -40)
        f.addRow = addRow
        local addEdit = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
        addEdit:SetSize(180, 20)
        addEdit:SetPoint("LEFT", 12, 0)
        addEdit:SetAutoFocus(false)
        addEdit:SetScript("OnEnterPressed", function() addEdit:ClearFocus() end)
        addEdit:SetScript("OnEscapePressed", function() addEdit:ClearFocus() end)
        f.addEdit = addEdit
        local addBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
        addBtn:SetSize(50, 20)
        addBtn:SetPoint("LEFT", addEdit, "RIGHT", 8, 0)
        addBtn:SetText("添加")
        addBtn:SetScript("OnClick", function()
            local str = addEdit:GetText()
            local id = L.ParseItemIdFromAddInput(str, ProfLevelHelperDB)
            if id and id > 0 then
                ProfLevelHelperDB.AHSellBackBlacklist = ProfLevelHelperDB.AHSellBackBlacklist or {}
                ProfLevelHelperDB.AHSellBackBlacklist[id] = true
                addEdit:SetText("")
                local opt = L.OptionsFrame
                if opt and opt.blCountText then
                    local n = 0
                    for _ in pairs(ProfLevelHelperDB.AHSellBackBlacklist) do n = n + 1 end
                    opt.blCountText:SetText("已屏蔽 " .. n .. " 种")
                end
                if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
                L.ShowAHSellBackBlacklistDetail()
            else
                local trimmed = str and (str:gsub("^%s+", ""):gsub("%s+$", "") or "")
                if trimmed and trimmed ~= "" then
                    L.Print("未找到该物品，请输入物品ID/链接，或先扫描拍卖行后再输入物品名称。")
                end
            end
        end)
        f.addBtn = addBtn
        local addHint = addRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        addHint:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        addHint:SetText("(ID/链接/名称)")
        f.addHint = addHint

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -68)
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

-- Whitelist detail UI: list + manual add + clear
function L.ShowAHSellBackWhitelistDetail()
    local wl = ProfLevelHelperDB.AHSellBackWhitelist or {}
    local list = {}
    for id in pairs(wl) do list[#list + 1] = id end
    table.sort(list)

    local f = L.WhitelistDetailFrame
    if not f then
        f = CreateFrame("Frame", "ProfLevelHelperWhitelistDetail", UIParent, "BackdropTemplate")
        L.WhitelistDetailFrame = f
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
        title:SetText("白名单详情 (卖店时强制AH回血)")
        f.title = title

        local addRow = CreateFrame("Frame", nil, f)
        addRow:SetSize(300, 24)
        addRow:SetPoint("TOP", 0, -40)
        f.addRow = addRow
        local addEdit = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
        addEdit:SetSize(180, 20)
        addEdit:SetPoint("LEFT", 12, 0)
        addEdit:SetAutoFocus(false)
        addEdit:SetScript("OnEnterPressed", function() addEdit:ClearFocus() end)
        addEdit:SetScript("OnEscapePressed", function() addEdit:ClearFocus() end)
        f.addEdit = addEdit
        local addBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
        addBtn:SetSize(50, 20)
        addBtn:SetPoint("LEFT", addEdit, "RIGHT", 8, 0)
        addBtn:SetText("添加")
        addBtn:SetScript("OnClick", function()
            local str = addEdit:GetText()
            local id = L.ParseItemIdFromAddInput(str, ProfLevelHelperDB)
            if id and id > 0 then
                ProfLevelHelperDB.AHSellBackWhitelist = ProfLevelHelperDB.AHSellBackWhitelist or {}
                ProfLevelHelperDB.AHSellBackWhitelist[id] = true
                addEdit:SetText("")
                local opt = L.OptionsFrame
                if opt and opt.wlCountText then
                    local n = 0
                    for _ in pairs(ProfLevelHelperDB.AHSellBackWhitelist) do n = n + 1 end
                    opt.wlCountText:SetText("已添加 " .. n .. " 种")
                end
                if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
                L.ShowAHSellBackWhitelistDetail()
            else
                local trimmed = str and (str:gsub("^%s+", ""):gsub("%s+$", "") or "")
                if trimmed and trimmed ~= "" then
                    L.Print("未找到该物品，请输入物品ID/链接，或先扫描拍卖行后再输入物品名称。")
                end
            end
        end)
        f.addBtn = addBtn
        local addHint = addRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        addHint:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        addHint:SetText("(ID/链接/名称)")
        f.addHint = addHint

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -68)
        scroll:SetPoint("BOTTOMRIGHT", -32, 52)
        f.scroll = scroll
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(280, 1)
        scroll:SetScrollChild(content)
        f.scrollContent = content

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(100, 22)
        clearBtn:SetPoint("BOTTOM", -60, 16)
        clearBtn:SetText("清空白名单")
        clearBtn:SetScript("OnClick", function()
            ProfLevelHelperDB.AHSellBackWhitelist = {}
            local opt = L.OptionsFrame
            if opt and opt.wlCountText then opt.wlCountText:SetText("已添加 0 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowAHSellBackWhitelistDetail()
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
            if ProfLevelHelperDB.AHSellBackWhitelist then ProfLevelHelperDB.AHSellBackWhitelist[itemID] = nil end
            local nWl = 0
            if ProfLevelHelperDB.AHSellBackWhitelist then
                for _ in pairs(ProfLevelHelperDB.AHSellBackWhitelist) do nWl = nWl + 1 end
            end
            local opt = L.OptionsFrame
            if opt and opt.wlCountText then opt.wlCountText:SetText("已添加 " .. nWl .. " 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowAHSellBackWhitelistDetail()
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
            f:SetSize(660, 480)
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

        local db = ProfLevelHelperDB
        local fragVal = (db and db.FragmentValueInCopper) and db.FragmentValueInCopper or 0
        local totalGold = 0
        local totalFragments = 0
        for _, seg in ipairs(route) do
            local fragmentCount = 0
            for _, r in ipairs(seg.recipe.reagents or {}) do
                local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
                if id and db then
                    local fragCost = (db.FragmentCosts and db.FragmentCosts[id] and fragVal > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                    local ahCost = (db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                    local vendorCost = (db.VendorPrices and db.VendorPrices[id] and db.VendorPrices[id] > 0) and db.VendorPrices[id] or 999999999
                    local best = math.min(ahCost, vendorCost, fragCost)
                    if fragCost < 999999999 and best == fragCost then
                        fragmentCount = fragmentCount + math.ceil(r.count * seg.totalCrafts) * (db.FragmentCosts[id] or 0)
                    end
                end
            end
            local goldMat = (seg.totalMatCost or 0) - fragmentCount * fragVal
            local useAH = db and ((db.SellBackMethod == "ah") and not (db.AHSellBackBlacklist and seg.recipe.createdItemID and db.AHSellBackBlacklist[seg.recipe.createdItemID]) or (db.SellBackMethod == "vendor") and (db.AHSellBackWhitelist and seg.recipe.createdItemID and db.AHSellBackWhitelist[seg.recipe.createdItemID]))
            local sellback = useAH and (seg.totalSellBackAH or 0) or (seg.totalSellBackVendor or 0)
            totalGold = totalGold + (seg.totalRecCost or 0) + goldMat - sellback
            totalFragments = totalFragments + fragmentCount
        end
        local titleFragStr = totalFragments > 0 and (tostring(math.floor(totalFragments + 0.5)) .. " 碎片") or "0 碎片"
        f.title:SetText(profName and (profName .. "路线 " .. actualStart .. " -> " .. actualEnd .. " (预测 金钱: " .. CopperToGold(totalGold) .. "  碎片: " .. titleFragStr .. ")") or "推荐列表")

        totalGold = 0
        totalFragments = 0
        local y = 0
        for i, seg in ipairs(route) do
            local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            table.insert(content.lines, line)
            line:SetPoint("TOPLEFT", 0, -y)
            line:SetJustifyH("LEFT")

            local reqStr = ""
            local fragStr = ""
            local fragmentCount = 0
            local alaAgent = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent
            for _, r in ipairs(seg.recipe.reagents or {}) do
                local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
                local itemName = r.name
                if not itemName and id then
                    if alaAgent and alaAgent.item_name then
                        itemName = alaAgent.item_name(id)
                    end
                    if not itemName then
                        local iname = GetItemInfo(id)
                        if iname then itemName = iname end
                    end
                end
                if not itemName then
                    itemName = "ID:" .. tostring(id or r.itemID)
                end
                local totQty = math.ceil(r.count * seg.totalCrafts)
                local fragCost = (id and db and db.FragmentCosts and db.FragmentCosts[id] and (fragVal or 0) > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                local ahCost = (id and db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                local vendorCost = (id and db.VendorPrices and db.VendorPrices[id] and db.VendorPrices[id] > 0) and db.VendorPrices[id] or 999999999
                local best = math.min(ahCost, vendorCost, fragCost)
                local useFrag = (fragCost < 999999999 and best == fragCost)
                if useFrag then
                    fragmentCount = fragmentCount + totQty * (db.FragmentCosts[id] or 0)
                    fragStr = fragStr .. itemName .. "*" .. totQty .. " "
                else
                    reqStr = reqStr .. itemName .. "*" .. totQty .. " "
                end
            end
            if reqStr == "" then reqStr = "无" end
            local materialsLine = reqStr
            if fragStr ~= "" then
                materialsLine = materialsLine .. " | 碎片兑换: " .. fragStr
            end

            local goldMat = (seg.totalMatCost or 0) - fragmentCount * fragVal
            local useAH = db and ((db.SellBackMethod == "ah") and not (db.AHSellBackBlacklist and seg.recipe.createdItemID and db.AHSellBackBlacklist[seg.recipe.createdItemID]) or (db.SellBackMethod == "vendor") and (db.AHSellBackWhitelist and seg.recipe.createdItemID and db.AHSellBackWhitelist[seg.recipe.createdItemID]))
            local sellback = useAH and (seg.totalSellBackAH or 0) or (seg.totalSellBackVendor or 0)
            local segGold = (seg.totalRecCost or 0) + goldMat - sellback
            totalGold = totalGold + segGold
            totalFragments = totalFragments + fragmentCount
            local goldStr = CopperToGold(segGold)
            local fragCostStr = fragmentCount > 0 and (tostring(math.floor(fragmentCount + 0.5)) .. " 碎片") or "0 碎片"

            local rNameC = (seg.recipe.recipeName or seg.recipe.name) or "?"
            if not seg.recipe.isKnown then
                rNameC = "|cffff2222[未学]|r" .. rNameC .. " |cff888888(获取: " .. (seg.recSource or "未知") .. ")|r"
            else
                rNameC = "|cff22ff22[已学]|r" .. rNameC
            end

            line:SetText(("[%d-%d] %s x%.0f次\n  配方: %s | 制作(金钱): %s | 制作(碎片): %s | 回血(卖NPC: %s | AH: %s) | 净花费 金钱: %s 碎片: %s\n  材料: %s"):format(
                seg.startSkill, seg.endSkill, rNameC, seg.totalCrafts,
                CopperToGold(seg.totalRecCost or 0), CopperToGold(goldMat), fragCostStr,
                CopperToGold(seg.totalSellBackVendor or 0), CopperToGold(seg.totalSellBackAH or 0),
                goldStr, fragCostStr,
                materialsLine))
            line:SetWidth(scroll:GetWidth() - 116)
            line:Show()

            local currentHeight = line:GetStringHeight()
            if not currentHeight or currentHeight == 0 then currentHeight = 38 end
            if seg.recipe.createdItemID then
                if ProfLevelHelperDB.SellBackMethod == "ah" then
                    local bl = ProfLevelHelperDB.AHSellBackBlacklist or {}
                    local isBlacklisted = bl[seg.recipe.createdItemID]
                    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    btn:SetSize(78, 18)
                    btn:SetPoint("TOPRIGHT", content, "TOPLEFT", scroll:GetWidth() - 30, -y)
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
                else
                    local wl = ProfLevelHelperDB.AHSellBackWhitelist or {}
                    local isWhitelisted = wl[seg.recipe.createdItemID]
                    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    btn:SetSize(78, 18)
                    btn:SetPoint("TOPRIGHT", content, "TOPLEFT", scroll:GetWidth() - 30, -y)
                    btn:SetText(isWhitelisted and "[取消AH回血]" or "[改为AH回血]")
                    btn.itemID = seg.recipe.createdItemID
                    btn:SetScript("OnClick", function()
                        local id = btn.itemID
                        if id and ProfLevelHelperDB.AHSellBackWhitelist then
                            if isWhitelisted then
                                ProfLevelHelperDB.AHSellBackWhitelist[id] = nil
                            else
                                ProfLevelHelperDB.AHSellBackWhitelist[id] = true
                            end
                            L.ShowResultList()
                        end
                    end)
                    btn:Show()
                    table.insert(content.segmentBtns, btn)
                end
            end
            y = y + currentHeight + 16
        end

        local sumLine = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        table.insert(content.lines, sumLine)
        sumLine:SetPoint("TOPLEFT", 0, -(y + 10))
        sumLine:SetJustifyH("LEFT")
        local totalFragStr = totalFragments > 0 and (tostring(math.floor(totalFragments + 0.5)) .. " 碎片") or "0 碎片"
        sumLine:SetText("============\n总计 金钱: " .. CopperToGold(totalGold) .. "  碎片: " .. totalFragStr .. "\n============")
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
    
    local ahTimeStr = L.FormatAHScanTime and L.FormatAHScanTime() or "Never"
    local alaAgent = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent
    local db = ProfLevelHelperDB
    local fragVal = (db and db.FragmentValueInCopper) and db.FragmentValueInCopper or 0
    local function c2s(c) local C = math.floor((c or 0) + 0.5); local g,s,co = math.floor(C/10000), math.floor((C%10000)/100), math.floor(C%100); return string.format("%d金%d银%d铜", g, s, co) end

    local exportTotalGold = 0
    local exportTotalFragments = 0
    local bodyTxt = ""
    for _, seg in ipairs(data.route) do
        local rNameC = (seg.recipe.recipeName or seg.recipe.name) or "?"
        local reqStr = ""
        local fragStr = ""
        local fragmentCount = 0
        for _, r in ipairs(seg.recipe.reagents or {}) do
            local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
            local itemName = r.name
            if not itemName and id then
                if alaAgent and alaAgent.item_name then itemName = alaAgent.item_name(id) end
                if not itemName then local iname = GetItemInfo(id) if iname then itemName = iname end end
            end
            if not itemName then itemName = "ID:" .. tostring(id or r.itemID) end
            local totQty = math.ceil(r.count * seg.totalCrafts)
            local fragCost = (id and db.FragmentCosts and db.FragmentCosts[id] and fragVal > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
            local ahCost = (id and db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
            local vendorCost = (id and db.VendorPrices and db.VendorPrices[id] and db.VendorPrices[id] > 0) and db.VendorPrices[id] or 999999999
            local best = math.min(ahCost, vendorCost, fragCost)
            local useFrag = (fragCost < 999999999 and best == fragCost)
            if useFrag then
                fragmentCount = fragmentCount + totQty * (db.FragmentCosts[id] or 0)
                fragStr = fragStr .. itemName .. "*" .. totQty .. " "
            else
                reqStr = reqStr .. itemName .. "*" .. totQty .. " "
            end
        end
        if reqStr == "" then reqStr = "无" end
        local materialsLine = reqStr
        if fragStr ~= "" then materialsLine = materialsLine .. " | 碎片兑换: " .. fragStr end

        local goldMat = (seg.totalMatCost or 0) - fragmentCount * fragVal
        local useAH = db and ((db.SellBackMethod == "ah") and not (db.AHSellBackBlacklist and seg.recipe.createdItemID and db.AHSellBackBlacklist[seg.recipe.createdItemID]) or (db.SellBackMethod == "vendor") and (db.AHSellBackWhitelist and seg.recipe.createdItemID and db.AHSellBackWhitelist[seg.recipe.createdItemID]))
        local sellback = useAH and (seg.totalSellBackAH or 0) or (seg.totalSellBackVendor or 0)
        local segGold = (seg.totalRecCost or 0) + goldMat - sellback
        local fragCostStr = fragmentCount > 0 and (tostring(math.floor(fragmentCount + 0.5)) .. "碎片") or "0碎片"
        local acq = seg.recSource and ("来源:"..seg.recSource) or ""
        exportTotalGold = exportTotalGold + segGold
        exportTotalFragments = exportTotalFragments + fragmentCount

        bodyTxt = bodyTxt .. string.format("[%d-%d] %s x%.0f次 | 配方:%s 制作(金钱):%s 制作(碎片):%s 回血(卖NPC:%s AH:%s) 净花费(金钱):%s 净花费(碎片):%s | %s - 材料: %s\n", seg.startSkill, seg.endSkill, rNameC, seg.totalCrafts, c2s(seg.totalRecCost), c2s(goldMat), fragCostStr, c2s(seg.totalSellBackVendor), c2s(seg.totalSellBackAH), c2s(segGold), fragCostStr, acq, materialsLine)
    end

    local totalFragStr = exportTotalFragments > 0 and (tostring(math.floor(exportTotalFragments + 0.5)) .. "碎片") or "0碎片"
    local txt = string.format("【ProfLevelHelper】%s冲级路线 (%d -> %d)\n总计 金钱: %s  碎片: %s\nAH data updated: %s\n\n", data.profName, data.startS, data.endS, c2s(exportTotalGold), totalFragStr, ahTimeStr) .. bodyTxt

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

-- Show VendorPrices as Lua text for copying into VendorPrices.lua. /plh dumpvendor
function L.ShowVendorDump()
    local str = (ProfLevelHelper and ProfLevelHelper.ExportVendorPricesToLuaString and ProfLevelHelper.ExportVendorPricesToLuaString()) or "ProfLevelHelper_VendorPrices = {\n}\n"
    local f = L.VendorDumpFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        L.VendorDumpFrame = f
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
        title:SetText("Vendor prices — copy and save as VendorPrices.lua")
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
