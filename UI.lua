--[[
  UI: options (holiday recipes), result list frame.
]]

local L = ProfLevelHelper
if not L then
    print("ProfLevelHelper: UI.lua - ProfLevelHelper global is nil, cannot load.")
    return
end
-- Stub so L.ShowResultList is never nil; real definition overwrites this later. If you see stub message, UI.lua failed before line with "function L.ShowResultList".
L.ShowResultList = L.ShowResultList or function()
    if L and L.Print then L.Print("|cffff0000ShowResultList 仍是占位，说明 UI.lua 在定义真实函数前就报错或中断。请开启「显示 Lua 错误」后 /reload 查看报错。|r") end
end

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

-- Parse add-input to spell ID: number, spell link (|Hspell:12345|), or spell name (if spellIdList provided).
-- spellIdList: optional table of spell IDs to match name against (e.g. keys of KnownCooldownSpellIDs).
function L.ParseSpellIdFromAddInput(str, spellIdList)
    if not str or str == "" then return nil end
    str = str:match("^%s*(.-)%s*$") or str
    local id = tonumber(str)
    if id and id > 0 then return id end
    id = str and str:match("spell:(%d+)")
    if id then return tonumber(id) end
    if spellIdList and GetSpellInfo and str and str ~= "" then
        local lower = str:lower()
        for sid in pairs(spellIdList) do
            if type(sid) == "number" then
                local name = GetSpellInfo(sid)
                if name and name:lower() == lower then return sid end
            end
        end
        for _, sid in ipairs(spellIdList) do
            if type(sid) == "number" then
                local name = GetSpellInfo(sid)
                if name and name:lower() == lower then return sid end
            end
        end
    end
    return nil
end

-- Count total entries in generic recipe list (spell + item + name).
function L.RecipeListCount(t)
    if not t or type(t) ~= "table" then return 0 end
    local n = 0
    if t.spell then for _ in pairs(t.spell) do n = n + 1 end end
    if t.item then for _ in pairs(t.item) do n = n + 1 end end
    if t.name then for _ in pairs(t.name) do n = n + 1 end end
    return n
end

-- Build flat list { { type, id, display }, ... } from RecipeBlacklist/Whitelist for UI.
function L.RecipeListEntries(t)
    local list = {}
    if not t or type(t) ~= "table" then return list end
    if type(t.spell) == "table" then
        for sid in pairs(t.spell) do
            local name = (GetSpellInfo and GetSpellInfo(sid)) or ("Spell " .. tostring(sid))
            list[#list + 1] = { type = "spell", id = sid, display = name .. " (id:" .. tostring(sid) .. ")" }
        end
    end
    if type(t.item) == "table" then
        for id in pairs(t.item) do
            local name = (GetItemInfo and GetItemInfo(id)) or ("Item " .. tostring(id))
            list[#list + 1] = { type = "item", id = id, display = name .. " (id:" .. tostring(id) .. ")" }
        end
    end
    if type(t.name) == "table" then
        for name in pairs(t.name) do
            list[#list + 1] = { type = "name", id = name, display = name }
        end
    end
    table.sort(list, function(a, b) return (a.display or "") < (b.display or "") end)
    return list
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
        btn:SetText("ProfLevelHelper扫描")
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
    -- Pending options: only apply to DB on 确认; 取消 discards. Init from current DB each time we open.
    local db = ProfLevelHelperDB
    f.pending = {
        IncludeHolidayRecipes = db.IncludeHolidayRecipes,
        TargetSkillStart = db.TargetSkillStart or 1,
        TargetSkillEnd = db.TargetSkillEnd or 450,
        IgnoredOutlierPercent = db.IgnoredOutlierPercent ~= nil and db.IgnoredOutlierPercent or 0.10,
        MinAHQuantity = db.MinAHQuantity or 50,
        FragmentValueInCopper = db.FragmentValueInCopper or 800,
        AvailableTitanFragments = db.AvailableTitanFragments,
        SellBackMethod = db.SellBackMethod or "vendor",
        UseDisenchantRecovery = db.UseDisenchantRecovery == true,
        UseTieredPricing = db.UseTieredPricing == true,
        IncludeSourceTrainer = db.IncludeSourceTrainer ~= false,
        IncludeSourceAH = db.IncludeSourceAH ~= false,
        IncludeSourceVendor = db.IncludeSourceVendor == true,
        IncludeSourceQuest = db.IncludeSourceQuest == true,
        IncludeSourceUnknown = db.IncludeSourceUnknown == true,
        ExcludeCooldownRecipes = db.ExcludeCooldownRecipes == true,
    }
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
    cb:SetChecked(f.pending.IncludeHolidayRecipes)
    cb:SetScript("OnClick", function()
        f.pending.IncludeHolidayRecipes = cb:GetChecked()
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
    startInput:SetText(tostring(f.pending.TargetSkillStart))
    startInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then f.pending.TargetSkillStart = val end
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
    endInput:SetText(tostring(f.pending.TargetSkillEnd))
    endInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then f.pending.TargetSkillEnd = val end
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
    local currPct = f.pending.IgnoredOutlierPercent
    if currPct > 1 then currPct = currPct / 100 end
    currPct = math.max(0, math.min(100, math.floor(currPct * 100)))
    pctInput:SetText(tostring(currPct))
    pctInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val then f.pending.IgnoredOutlierPercent = val / 100.0 end
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
    minQtyInput:SetText(tostring(f.pending.MinAHQuantity))
    minQtyInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then f.pending.MinAHQuantity = val end
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
    fragInput:SetText(tostring(f.pending.FragmentValueInCopper))
    fragInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 0 then f.pending.FragmentValueInCopper = val end
    end)
    f.fragInput = fragInput
    local fragValueBtn = f.fragValueBtn or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    fragValueBtn:SetSize(120, 20)
    fragValueBtn:SetPoint("LEFT", fragInput, "RIGHT", 10, 0)
    fragValueBtn:SetText("查看当前碎片价值")
    fragValueBtn:SetScript("OnClick", function()
        if L.ShowFragmentValueTable then L.ShowFragmentValueTable() end
    end)
    f.fragValueBtn = fragValueBtn

    -- Available Titan Fragments cap (empty = unlimited). Shadow price model: fragments as limited resource.
    local fragCapLabel = f.fragCapLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fragCapLabel:SetPoint("TOPLEFT", 24, -218)
    fragCapLabel:SetText("可用泰坦碎片数量(空=不限):")
    f.fragCapLabel = fragCapLabel
    local fragCapInput = f.fragCapInput or CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    fragCapInput:SetSize(80, 20)
    fragCapInput:SetPoint("LEFT", fragCapLabel, "RIGHT", 10, 0)
    fragCapInput:SetAutoFocus(false)
    fragCapInput:SetNumeric(true)
    fragCapInput:SetText(f.pending.AvailableTitanFragments and tostring(f.pending.AvailableTitanFragments) or "")
    fragCapInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if self:GetText():match("^%s*$") then
            f.pending.AvailableTitanFragments = nil
        elseif val and val >= 0 then
            f.pending.AvailableTitanFragments = math.floor(val)
        end
    end)
    f.fragCapInput = fragCapInput

    -- Sell-back method: vendor or AH (affects net cost calculation)
    local sellBackLabel = f.sellBackLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sellBackLabel:SetPoint("TOPLEFT", 24, -243)
    sellBackLabel:SetText("回血方式:")
    f.sellBackLabel = sellBackLabel
    local cbVendor = f.cb_sellBackVendor or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbVendor:SetPoint("LEFT", sellBackLabel, "RIGHT", 8, 0)
    cbVendor:SetChecked(f.pending.SellBackMethod ~= "ah")
    cbVendor:SetScript("OnClick", function()
        f.pending.SellBackMethod = "vendor"
        if f.cb_sellBackAH then f.cb_sellBackAH:SetChecked(false) end
    end)
    f.cb_sellBackVendor = cbVendor
    local lblV = cbVendor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblV:SetPoint("LEFT", cbVendor, "RIGHT", 2, 0)
    lblV:SetText("卖店")
    local cbAH = f.cb_sellBackAH or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbAH:SetPoint("LEFT", lblV, "RIGHT", 16, 0)
    cbAH:SetChecked(f.pending.SellBackMethod == "ah")
    cbAH:SetScript("OnClick", function()
        f.pending.SellBackMethod = "ah"
        if f.cb_sellBackVendor then f.cb_sellBackVendor:SetChecked(false) end
    end)
    f.cb_sellBackAH = cbAH
    local lblA = cbAH:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblA:SetPoint("LEFT", cbAH, "RIGHT", 2, 0)
    lblA:SetText("拍卖")

    -- Disenchant recovery: use Auctionator disenchant value as AH sellback when enabled (black/whitelist still apply)
    local cbDE = f.cb_UseDisenchantRecovery or CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbDE:SetPoint("TOPLEFT", 24, -252)
    cbDE:SetChecked(f.pending.UseDisenchantRecovery)
    cbDE:SetScript("OnClick", function()
        f.pending.UseDisenchantRecovery = cbDE:GetChecked()
    end)
    f.cb_UseDisenchantRecovery = cbDE
    local lblDE = cbDE.label or cbDE:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblDE:SetPoint("LEFT", cbDE, "RIGHT", 4, 0)
    lblDE:SetText("分解回血(需Auctionator, 可分解物按分解期望价回血)")
    cbDE.label = lblDE

    -- AH sell-back blacklist: label can wrap; count and button on next line
    local blLabel = f.blLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blLabel:SetPoint("TOPLEFT", f.cb_UseDisenchantRecovery, "BOTTOMLEFT", 0, -8)
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
        cb:SetChecked(f.pending[key])
        cb:SetScript("OnClick", function()
            f.pending[key] = cb:GetChecked()
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
    createCheckbox("ExcludeCooldownRecipes", "排除有冷却的配方")

    -- Cooldown recipe blacklist/whitelist
    local cdBlLabel = f.cdBlLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdBlLabel:SetPoint("TOPLEFT", lastCbAnchor, "BOTTOMLEFT", 0, -8)
    cdBlLabel:SetWidth(332)
    cdBlLabel:SetWordWrap(true)
    cdBlLabel:SetNonSpaceWrap(false)
    cdBlLabel:SetText("配方黑名单(一律排除；先选类型再输入):")
    f.cdBlLabel = cdBlLabel
    local cdBlCountText = f.cdBlCountText or content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cdBlCountText:SetPoint("TOPLEFT", cdBlLabel, "BOTTOMLEFT", 0, -4)
    f.cdBlCountText = cdBlCountText
    local cdBlDetailBtn = f.cdBlDetailBtn or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    cdBlDetailBtn:SetSize(90, 20)
    cdBlDetailBtn:SetPoint("LEFT", cdBlCountText, "RIGHT", 12, 0)
    cdBlDetailBtn:SetText("查看黑名单")
    cdBlDetailBtn:SetScript("OnClick", function()
        if L.ShowCooldownBlacklistDetail then L.ShowCooldownBlacklistDetail() end
    end)
    f.cdBlDetailBtn = cdBlDetailBtn

    local cdWlLabel = f.cdWlLabel or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdWlLabel:SetPoint("TOPLEFT", cdBlCountText, "BOTTOMLEFT", 0, -14)
    cdWlLabel:SetWidth(332)
    cdWlLabel:SetWordWrap(true)
    cdWlLabel:SetNonSpaceWrap(false)
    cdWlLabel:SetText("配方白名单(一律允许，勾选排除CD时仍允许；先选类型再输入):")
    f.cdWlLabel = cdWlLabel
    local cdWlCountText = f.cdWlCountText or content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cdWlCountText:SetPoint("TOPLEFT", cdWlLabel, "BOTTOMLEFT", 0, -4)
    f.cdWlCountText = cdWlCountText
    local cdWlDetailBtn = f.cdWlDetailBtn or CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    cdWlDetailBtn:SetSize(90, 20)
    cdWlDetailBtn:SetPoint("LEFT", cdWlCountText, "RIGHT", 12, 0)
    cdWlDetailBtn:SetText("查看白名单")
    cdWlDetailBtn:SetScript("OnClick", function()
        if L.ShowCooldownWhitelistDetail then L.ShowCooldownWhitelistDetail() end
    end)
    f.cdWlDetailBtn = cdWlDetailBtn

    local feedback = f.feedbackText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    feedback:SetPoint("BOTTOM", 0, 38)
    feedback:SetText("反馈邮箱: ptrees@126.com")
    f.feedbackText = feedback

    local confirmBtn = f.confirmBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    confirmBtn:SetSize(80, 22)
    confirmBtn:SetPoint("BOTTOM", 40, 16)
    confirmBtn:SetText("确认")
    confirmBtn:SetScript("OnClick", function()
        local p = f.pending
        if p then
            ProfLevelHelperDB.IncludeHolidayRecipes = p.IncludeHolidayRecipes
            ProfLevelHelperDB.TargetSkillStart = p.TargetSkillStart
            ProfLevelHelperDB.TargetSkillEnd = p.TargetSkillEnd
            ProfLevelHelperDB.IgnoredOutlierPercent = p.IgnoredOutlierPercent
            ProfLevelHelperDB.MinAHQuantity = p.MinAHQuantity
            ProfLevelHelperDB.FragmentValueInCopper = p.FragmentValueInCopper
            ProfLevelHelperDB.AvailableTitanFragments = p.AvailableTitanFragments
            ProfLevelHelperDB.SellBackMethod = p.SellBackMethod
            ProfLevelHelperDB.UseDisenchantRecovery = p.UseDisenchantRecovery
            ProfLevelHelperDB.UseTieredPricing = p.UseTieredPricing
            ProfLevelHelperDB.IncludeSourceTrainer = p.IncludeSourceTrainer
            ProfLevelHelperDB.IncludeSourceAH = p.IncludeSourceAH
            ProfLevelHelperDB.IncludeSourceVendor = p.IncludeSourceVendor
            ProfLevelHelperDB.IncludeSourceQuest = p.IncludeSourceQuest
            ProfLevelHelperDB.IncludeSourceUnknown = p.IncludeSourceUnknown
            ProfLevelHelperDB.ExcludeCooldownRecipes = p.ExcludeCooldownRecipes
        end
        f:Hide()
        if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
    end)
    f.confirmBtn = confirmBtn
    local cancelBtn = f.cancelBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 22)
    cancelBtn:SetPoint("BOTTOM", -40, 16)
    cancelBtn:SetText("取消")
    cancelBtn:SetScript("OnClick", function() f:Hide() end)
    f.cancelBtn = cancelBtn
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
    local nCdBl = L.RecipeListCount(ProfLevelHelperDB.RecipeBlacklist)
    local nCdWl = L.RecipeListCount(ProfLevelHelperDB.RecipeWhitelist)
    if f.cdBlCountText then f.cdBlCountText:SetText("已屏蔽 " .. nCdBl .. " 种") end
    if f.cdWlCountText then f.cdWlCountText:SetText("已添加 " .. nCdWl .. " 种") end
    local nKnownCd = 0
    if ProfLevelHelperDB.KnownCooldownSpellIDs then
        for _ in pairs(ProfLevelHelperDB.KnownCooldownSpellIDs) do nKnownCd = nKnownCd + 1 end
    end
    if f.knownCdCountText then f.knownCdCountText:SetText("已添加 " .. nKnownCd .. " 种(法术ID)") end
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
        local displayText = name .. " (id:" .. tostring(itemID) .. ")"
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
        row.label:SetText(displayText)
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
        local displayText = name .. " (id:" .. tostring(itemID) .. ")"
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
        row.label:SetText(displayText)
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

-- Recipe blacklist detail: type selector (spell/item/name) then input, list all three.
function L.ShowCooldownBlacklistDetail()
    local bl = ProfLevelHelperDB.RecipeBlacklist or { spell = {}, item = {}, name = {} }
    local list = L.RecipeListEntries(bl)

    local f = L.CooldownBlacklistDetailFrame
    if not f then
        f = CreateFrame("Frame", "ProfLevelHelperCDBlacklistDetail", UIParent, "BackdropTemplate")
        L.CooldownBlacklistDetailFrame = f
        f:SetSize(360, 400)
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
        title:SetText("配方黑名单")
        f.title = title

        f.addType = "item"
        local typeNames = { spell = "法术", item = "成品", name = "配方名" }
        local typeOrder = { "item", "spell", "name" }
        local typeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        typeLabel:SetPoint("TOPLEFT", 12, -40)
        typeLabel:SetText("添加类型(名称或id):")
        local typeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        typeBtn:SetSize(100, 22)
        typeBtn:SetPoint("LEFT", typeLabel, "RIGHT", 8, 0)
        typeBtn:SetText("成品(点击切换)")
        f.typeBtn = typeBtn
        f.typeNames = typeNames
        typeBtn:SetScript("OnClick", function()
            local nextIdx = 1
            for i, k in ipairs(typeOrder) do
                if k == (f.addType or "item") then nextIdx = (i % #typeOrder) + 1; break end
            end
            f.addType = typeOrder[nextIdx]
            typeBtn:SetText((typeNames[f.addType] or "成品") .. "(点击切换)")
        end)

        local addRow = CreateFrame("Frame", nil, f)
        addRow:SetSize(320, 24)
        addRow:SetPoint("TOP", 0, -64)
        f.addRow = addRow
        local addEdit = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
        addEdit:SetSize(200, 20)
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
            local typ = f.addType or "item"
            local bl = ProfLevelHelperDB.RecipeBlacklist
            if not bl.spell then bl.spell = {} end
            if not bl.item then bl.item = {} end
            if not bl.name then bl.name = {} end
            local ok = false
            if typ == "spell" then
                local known = ProfLevelHelperDB.KnownCooldownSpellIDs or {}
                local id = L.ParseSpellIdFromAddInput(str, known)
                if id and id > 0 then bl.spell[id] = true; ok = true end
            elseif typ == "item" then
                local id = L.ParseItemIdFromAddInput(str, ProfLevelHelperDB)
                if id and id > 0 then bl.item[id] = true; ok = true end
            else
                local trimmed = str and str:match("^%s*(.-)%s*$") or ""
                if trimmed ~= "" then bl.name[trimmed] = true; ok = true end
            end
            if ok then
                addEdit:SetText("")
                local opt = L.OptionsFrame
                if opt and opt.cdBlCountText then opt.cdBlCountText:SetText("已屏蔽 " .. L.RecipeListCount(ProfLevelHelperDB.RecipeBlacklist) .. " 种") end
                if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
                L.ShowCooldownBlacklistDetail()
            end
        end)
        f.addBtn = addBtn

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -92)
        scroll:SetPoint("BOTTOMRIGHT", -32, 52)
        f.scroll = scroll
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(300, 1)
        scroll:SetScrollChild(content)
        f.scrollContent = content

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(100, 22)
        clearBtn:SetPoint("BOTTOM", -60, 16)
        clearBtn:SetText("清空黑名单")
        clearBtn:SetScript("OnClick", function()
            ProfLevelHelperDB.RecipeBlacklist = { spell = {}, item = {}, name = {} }
            local opt = L.OptionsFrame
            if opt and opt.cdBlCountText then opt.cdBlCountText:SetText("已屏蔽 0 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowCooldownBlacklistDetail()
        end)
        f.clearBtn = clearBtn

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOM", 60, 16)
        closeBtn:SetText("关闭")
        closeBtn:SetScript("OnClick", function() f:Hide() end)
        f.closeBtn = closeBtn
    end

        if f.typeBtn and f.typeNames then
            local txt = f.typeNames[f.addType or "item"] or "成品"
            f.typeBtn:SetText(txt .. "(点击切换)")
        end

        local content = f.scrollContent
        content:SetHeight(1)
        for k, row in pairs(content) do
            if type(row) == "table" and row.Hide then row:Hide() end
        end

        local ROW_H = 22
        local y = 0
        for i, entry in ipairs(list) do
            local row = content["row_" .. i]
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
                content["row_" .. i] = row
            end
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", 0, -y)
            row.label:SetText(entry.display)
            local typ, id = entry.type, entry.id
            row.btn:SetScript("OnClick", function()
                local bl = ProfLevelHelperDB.RecipeBlacklist
            if bl then
                if typ == "spell" and bl.spell then bl.spell[id] = nil
                elseif typ == "item" and bl.item then bl.item[id] = nil
                elseif typ == "name" and bl.name then bl.name[id] = nil end
            end
            local opt = L.OptionsFrame
            if opt and opt.cdBlCountText then opt.cdBlCountText:SetText("已屏蔽 " .. L.RecipeListCount(ProfLevelHelperDB.RecipeBlacklist) .. " 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowCooldownBlacklistDetail()
        end)
        row:Show()
        y = y + ROW_H
    end
    content:SetHeight(math.max(1, y))
    f.clearBtn:SetShown(#list > 0)
    f:Show()
end

-- Recipe whitelist detail: type selector (spell/item/name) then input, list all three.
function L.ShowCooldownWhitelistDetail()
    local wl = ProfLevelHelperDB.RecipeWhitelist or { spell = {}, item = {}, name = {} }
    local list = L.RecipeListEntries(wl)

    local f = L.CooldownWhitelistDetailFrame
    if not f then
        f = CreateFrame("Frame", "ProfLevelHelperCDWhitelistDetail", UIParent, "BackdropTemplate")
        L.CooldownWhitelistDetailFrame = f
        f:SetSize(360, 400)
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
        title:SetText("配方白名单")
        f.title = title

        f.addType = "item"
        local typeNames = { spell = "法术", item = "成品", name = "配方名" }
        local typeOrder = { "item", "spell", "name" }
        local typeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        typeLabel:SetPoint("TOPLEFT", 12, -40)
        typeLabel:SetText("添加类型(名称或id):")
        local typeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        typeBtn:SetSize(100, 22)
        typeBtn:SetPoint("LEFT", typeLabel, "RIGHT", 8, 0)
        typeBtn:SetText("成品(点击切换)")
        f.typeBtn = typeBtn
        f.typeNames = typeNames
        typeBtn:SetScript("OnClick", function()
            local nextIdx = 1
            for i, k in ipairs(typeOrder) do
                if k == (f.addType or "item") then nextIdx = (i % #typeOrder) + 1; break end
            end
            f.addType = typeOrder[nextIdx]
            typeBtn:SetText((typeNames[f.addType] or "成品") .. "(点击切换)")
        end)

        local addRow = CreateFrame("Frame", nil, f)
        addRow:SetSize(320, 24)
        addRow:SetPoint("TOP", 0, -64)
        f.addRow = addRow
        local addEdit = CreateFrame("EditBox", nil, addRow, "InputBoxTemplate")
        addEdit:SetSize(200, 20)
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
            local typ = f.addType or "item"
            local wl = ProfLevelHelperDB.RecipeWhitelist
            if not wl.spell then wl.spell = {} end
            if not wl.item then wl.item = {} end
            if not wl.name then wl.name = {} end
            local ok = false
            if typ == "spell" then
                local known = ProfLevelHelperDB.KnownCooldownSpellIDs or {}
                local id = L.ParseSpellIdFromAddInput(str, known)
                if id and id > 0 then wl.spell[id] = true; ok = true end
            elseif typ == "item" then
                local id = L.ParseItemIdFromAddInput(str, ProfLevelHelperDB)
                if id and id > 0 then wl.item[id] = true; ok = true end
            else
                local trimmed = str and str:match("^%s*(.-)%s*$") or ""
                if trimmed ~= "" then wl.name[trimmed] = true; ok = true end
            end
            if ok then
                addEdit:SetText("")
                local opt = L.OptionsFrame
                if opt and opt.cdWlCountText then opt.cdWlCountText:SetText("已添加 " .. L.RecipeListCount(ProfLevelHelperDB.RecipeWhitelist) .. " 种") end
                if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
                L.ShowCooldownWhitelistDetail()
            end
        end)
        f.addBtn = addBtn

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -92)
        scroll:SetPoint("BOTTOMRIGHT", -32, 52)
        f.scroll = scroll
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(300, 1)
        scroll:SetScrollChild(content)
        f.scrollContent = content

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(100, 22)
        clearBtn:SetPoint("BOTTOM", -60, 16)
        clearBtn:SetText("清空白名单")
        clearBtn:SetScript("OnClick", function()
            ProfLevelHelperDB.RecipeWhitelist = { spell = {}, item = {}, name = {} }
            local opt = L.OptionsFrame
            if opt and opt.cdWlCountText then opt.cdWlCountText:SetText("已添加 0 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowCooldownWhitelistDetail()
        end)
        f.clearBtn = clearBtn

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOM", 60, 16)
        closeBtn:SetText("关闭")
        closeBtn:SetScript("OnClick", function() f:Hide() end)
        f.closeBtn = closeBtn
    end

    if f.typeBtn and f.typeNames then
        local txt = f.typeNames[f.addType or "item"] or "成品"
        f.typeBtn:SetText(txt .. "(点击切换)")
    end

    local content = f.scrollContent
    content:SetHeight(1)
    for k, row in pairs(content) do
        if type(row) == "table" and row.Hide then row:Hide() end
    end

    local ROW_H = 22
    local y = 0
    for i, entry in ipairs(list) do
        local row = content["row_" .. i]
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
            content["row_" .. i] = row
        end
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        row.label:SetText(entry.display)
        local typ, id = entry.type, entry.id
        row.btn:SetScript("OnClick", function()
            local wl = ProfLevelHelperDB.RecipeWhitelist
            if wl then
                if typ == "spell" and wl.spell then wl.spell[id] = nil
                elseif typ == "item" and wl.item then wl.item[id] = nil
                elseif typ == "name" and wl.name then wl.name[id] = nil end
            end
            local opt = L.OptionsFrame
            if opt and opt.cdWlCountText then opt.cdWlCountText:SetText("已添加 " .. L.RecipeListCount(ProfLevelHelperDB.RecipeWhitelist) .. " 种") end
            if L.ResultFrame and L.ResultFrame:IsShown() then L.ShowResultList() end
            L.ShowCooldownWhitelistDetail()
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
        local route, profName, actualStart, actualEnd, totalCost
        if not ok then
            L.Print("|cffff0000ProfLevelHelper 错误: " .. tostring(a) .. "|r")
            route = nil
            profName = nil
            actualStart = startSkill
            actualEnd = endSkill
        else
            route, profName, actualStart, actualEnd, totalCost = a, b, c, d, e
        end

        local function ensureResultFrameAndShowNoRoute(msg)
            if not L.ResultFrame then
                local fr = CreateFrame("Frame", "ProfLevelHelperResult", UIParent, "BackdropTemplate")
                L.ResultFrame = fr
                fr:SetSize(660, 480)
                fr:SetPoint("CENTER")
                fr:SetFrameStrata("DIALOG")
                fr:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true, tileSize = 32, edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 },
                })
                fr:SetBackdropColor(0, 0, 0, 0.9)
                fr:EnableMouse(true)
                fr:SetMovable(true)
                fr:RegisterForDrag("LeftButton")
                fr:SetScript("OnDragStart", fr.StartMoving)
                fr:SetScript("OnDragStop", fr.StopMovingOrSizing)
                local title = fr:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                title:SetPoint("TOP", 0, -12)
                fr.title = title
                local ahTimeLabel = fr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                ahTimeLabel:SetPoint("TOPLEFT", 20, -30)
                fr.ahTimeLabel = ahTimeLabel
                local scroll = CreateFrame("ScrollFrame", "ProfLevelHelperResultScroll", fr, "UIPanelScrollFrameTemplate")
                scroll:SetPoint("TOPLEFT", 20, -44)
                scroll:SetPoint("BOTTOMRIGHT", -36, 46)
                fr.scroll = scroll
                local content = CreateFrame("Frame", nil, scroll)
                content:SetSize(scroll:GetWidth() - 20, 1)
                scroll:SetScrollChild(content)
                fr.content = content
                local close = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
                close:SetSize(100, 22)
                close:SetPoint("BOTTOMRIGHT", -20, 12)
                close:SetText("关闭")
                close:SetScript("OnClick", function() fr:Hide() end)
                fr.closeBtn = close
                local exportBtn = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
                exportBtn:SetSize(100, 22)
                exportBtn:SetPoint("BOTTOM", 0, 12)
                exportBtn:SetText("复制到剪贴板")
                exportBtn:SetScript("OnClick", function() if L.ShowExportFrame then L.ShowExportFrame() end end)
                fr.exportBtn = exportBtn
                local optionsBtn = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
                optionsBtn:SetSize(100, 22)
                optionsBtn:SetPoint("BOTTOMLEFT", 20, 12)
                optionsBtn:SetText("更改选项")
                optionsBtn:SetScript("OnClick", function() L.OpenOptions() end)
                fr.optionsBtn = optionsBtn
            end
            local f = L.ResultFrame
            f.title:SetText(msg or "冲点推荐")
            f.ahTimeLabel:SetText("AH data updated: " .. L.FormatAHScanTime())
            local content = f.content
            if content.lines then for _, g in ipairs(content.lines) do g:Hide() end end
            if content.segmentBtns then for _, b in ipairs(content.segmentBtns) do b:Hide() end end
            content.lines = {}
            content.segmentBtns = {}
            local hint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            hint:SetPoint("TOPLEFT", 0, 0)
            hint:SetWidth(f:GetWidth() - 60)
            hint:SetWordWrap(true)
            hint:SetNonSpaceWrap(true)
            hint:SetText("请点击下方「更改选项」调整目标等级、黑名单/白名单、数据源等后重试。")
            table.insert(content.lines, hint)
            content:SetHeight(40)
            f:Show()
        end

        if not ok then
            ensureResultFrameAndShowNoRoute("ProfLevelHelper 计算出错，请检查配置或重试。")
            return
        end
        if not route or #route == 0 then
            local s = actualStart or startSkill or "?"
            local e = actualEnd or endSkill or "?"
            local msg = profName and ("未找到 " .. s .. " -> " .. e .. " 的冲级路线，请修改配置后重试。") or "请先打开专业技能窗口。"
            L.Print(profName and ("无法找到一条从 " .. s .. " 到 ".. e .. " 的冲级路线，可能是缺乏有效配方或者拍卖行数据不足。") or "请先打开专业技能窗口。")
            ensureResultFrameAndShowNoRoute(msg)
            return
        end

        if not ProfLevelHelperDB.AHPrices or next(ProfLevelHelperDB.AHPrices) == nil then
            L.Print("|cffff2222警告：尚未扫描拍卖行物价，所有的消耗计算可能存在极大的误差（按 NPC 售出价格预估），请尽快去主城拍卖行点击扫描一次！|r")
        end

        if not L.ResultFrame then
            local f = CreateFrame("Frame", "ProfLevelHelperResult", UIParent, "BackdropTemplate")
            L.ResultFrame = f
            f:SetSize(1240, 520)
            f:SetPoint("CENTER")
            f:SetFrameStrata("DIALOG")
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
            f:SetBackdropColor(0, 0, 0, 0.95)
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
            content:SetSize(1200, 1)
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
        local function CopperToGoldSigned(c)
            if type(c) ~= "number" then return "0 铜" end
            if c < 0 then return "-" .. CopperToGold(-c) end
            return CopperToGold(c)
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
        if db and db.UseDisenchantRecovery and (not Auctionator or not Auctionator.Enchant) then
            L.Print("分解回血已勾选但未检测到 Auctionator 插件，分解相关回血不可用，请启用 Auctionator 后重载界面。")
        end
        local fragVal = (db and db.FragmentValueInCopper) and db.FragmentValueInCopper or 0
        local totalGold = 0
        local totalFragments = 0
        for _, seg in ipairs(route) do
            local fragmentCount = (type(seg.fragmentCount) == "number" and seg.fragmentCount >= 0) and seg.fragmentCount or 0
            if fragmentCount == 0 then
                for _, r in ipairs(seg.recipe.reagents or {}) do
                    local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
                    if id and db then
                        local fragCost = (db.FragmentCosts and db.FragmentCosts[id] and fragVal > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                        local ahCost = (db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                        local vendorCost = (ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0) and ProfLevelHelper_VendorPrices[id] or 999999999
                        local best = math.min(ahCost, vendorCost, fragCost)
                        if fragCost < 999999999 and best == fragCost then
                            fragmentCount = fragmentCount + (r.count or 0) * seg.totalCrafts * (db.FragmentCosts[id] or 0)
                        end
                    end
                end
            end
            local goldMat = (seg.totalMatCost or 0) - fragmentCount * fragVal
            local useAH = db and ((db.SellBackMethod == "ah" and not (db.AHSellBackBlacklist and seg.recipe.createdItemID and db.AHSellBackBlacklist[seg.recipe.createdItemID])) or (db.SellBackMethod == "vendor" and ((db.AHSellBackWhitelist and seg.recipe.createdItemID and db.AHSellBackWhitelist[seg.recipe.createdItemID]) or (db.UseDisenchantRecovery and L.IsDisenchantable(seg.recipe.createdItemID)))))
            local bestSb = (db and db.UseDisenchantRecovery and L.GetBestSellBackPerItem and L.GetBestSellBackPerItem(seg.recipe, db)) or nil
            local sellback = (bestSb and bestSb > 0) and (bestSb * (seg.recipe.numMade or 1) * seg.totalCrafts) or (useAH and (seg.totalSellBackAH or 0) or (seg.totalSellBackVendor or 0))
            totalGold = totalGold + (seg.totalRecCost or 0) + goldMat - sellback
            totalFragments = totalFragments + fragmentCount
        end
        local titleFragStr = totalFragments > 0 and (tostring(math.floor(totalFragments + 0.5)) .. " 碎片") or "0 碎片"
        f.title:SetText(profName and (profName .. "路线 " .. actualStart .. " -> " .. actualEnd .. " (预测 金钱: " .. CopperToGoldSigned(totalGold) .. "  碎片: " .. titleFragStr .. ")") or "推荐列表")

        totalGold = 0
        totalFragments = 0
        local totalCostBeforeSellback = 0
        local y = 0
        -- Net buy quantities: total consumed minus total produced in route.
        -- Items whose net qty <= 0 are fully self-supplied and excluded from the summary.
        local producedQtyMap = {}
        for _, seg in ipairs(route) do
            local cid = seg.recipe and seg.recipe.createdItemID
            if cid then
                local qty = (seg.recipe.numMade or 1) * seg.totalCrafts
                producedQtyMap[cid] = (producedQtyMap[cid] or 0) + qty
            end
        end
        local consumedQtyMap = {}
        for _, seg in ipairs(route) do
            for _, r in ipairs(seg.recipe.reagents or {}) do
                local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
                if id then
                    consumedQtyMap[id] = (consumedQtyMap[id] or 0) + (r.count or 0) * seg.totalCrafts
                end
            end
        end
        local netBuyQtyMap = {}
        for id, consumed in pairs(consumedQtyMap) do
            local net = consumed - (producedQtyMap[id] or 0)
            if net > 0 then netBuyQtyMap[id] = math.ceil(net) end
        end
        -- buyTotals/fragTotals: id -> {name, qty}. purchaseList: unified order (recipe then its materials).
        local buyTotals = {}
        local fragTotals = {}
        local fragOrder = {}
        local fragOrderSet = {}
        local routeUsesFragmentCount = false
        -- Table Column Definitions (10 Columns); col3 "配方价格" widened, col6 "回血信息" shortened
        local colX = {0, 60, 125, 200, 245, 605, 835, 925, 1015, 1065}
        local colW = {55, 60, 70, 40, 355, 225, 85, 85, 45, 120}
        
        -- Header Row
        local header = CreateFrame("Frame", nil, content)
        header:SetSize(scroll:GetWidth(), 26)
        header:SetPoint("TOPLEFT", 0, 0)
        table.insert(content.lines, header)
        local function CreateHeaderCol(text, x, width)
            local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", x, 0)
            fs:SetWidth(width)
            fs:SetJustifyH("LEFT")
            fs:SetText(text)
            return fs
        end
        CreateHeaderCol("点数", colX[1], colW[1])
        CreateHeaderCol("配方名", colX[2], colW[2])
        CreateHeaderCol("配方价格", colX[3], colW[3])
        CreateHeaderCol("次数", colX[4], colW[4])
        CreateHeaderCol("材料", colX[5], colW[5])
        CreateHeaderCol("回血信息", colX[6], colW[6])
        CreateHeaderCol("制作成本", colX[7], colW[7])
        CreateHeaderCol("净成本", colX[8], colW[8])
        CreateHeaderCol("碎片", colX[9], colW[9])
        CreateHeaderCol("操作", colX[10], colW[10])
        
        y = 28

        for i, seg in ipairs(route) do
            local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
            row:SetSize(scroll:GetWidth(), 1) -- height dynamic
            row:SetPoint("TOPLEFT", 0, -y)
            if i % 2 == 0 then
                row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                row:SetBackdropColor(1, 1, 1, 0.05)
            end
            table.insert(content.lines, row)

            local function CreateRowCol(x, width)
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("TOPLEFT", x, -4)
                fs:SetWidth(width)
                fs:SetJustifyH("LEFT")
                return fs
            end

            local cSkill = CreateRowCol(colX[1], colW[1])
            local skillCaps = { 75, 150, 225, 300, 375 }
            local needCapWarning = false
            for _, cap in ipairs(skillCaps) do
                if seg.startSkill <= cap and cap <= seg.endSkill then needCapWarning = true; break end
            end
            cSkill:SetText(("[%d-%d]"):format(seg.startSkill, seg.endSkill) .. (needCapWarning and ("\n" .. "|cffff0000注意突破上限|r") or ""))

            local cRecipe = CreateRowCol(colX[2], colW[2])
            local cRecPrice = CreateRowCol(colX[3], colW[3])
            local cCrafts = CreateRowCol(colX[4], colW[4])
            cCrafts:SetText(("%.0f次"):format(seg.totalCrafts))

            local cMaterials = CreateRowCol(colX[5], colW[5])
            local cSellback = CreateRowCol(colX[6], colW[6])
            local cProdCost = CreateRowCol(colX[7], colW[7])
            local cNet = CreateRowCol(colX[8], colW[8])
            local cFrag = CreateRowCol(colX[9], colW[9])

            local matLines = {}
            local routeFragmentCountProvided = (type(seg.fragmentCount) == "number" and seg.fragmentCount >= 0)
            local fragmentCount = routeFragmentCountProvided and seg.fragmentCount or 0
            local alaAgent = _G.__ala_meta__ and _G.__ala_meta__.prof and _G.__ala_meta__.prof.DT and _G.__ala_meta__.prof.DT.DataAgent
            
            local totalRefCost = 0
            local totalTieredCost = 0
            local matSources = {} 
            
            for i, r in ipairs(seg.recipe.reagents or {}) do
                local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
                local itemName = r.name
                if not itemName and id then
                    if alaAgent and alaAgent.item_name then itemName = alaAgent.item_name(id) end
                    if not itemName then local iname = GetItemInfo(id) if iname then itemName = iname end end
                end
                if not itemName then itemName = "ID:" .. tostring(id or r.itemID) end
                
                local m = seg.materialDetails and seg.materialDetails[i]
                local totQty = (m and m.qty ~= nil) and m.qty or ((r.count or 0) * seg.totalCrafts)
                
                local qF, qA = 0, 0
                if routeFragmentCountProvided then
                    qF = (seg.fragmentSources and seg.fragmentSources[id]) or 0
                    qA = totQty - qF
                else
                    local fragCost = (id and db and db.FragmentCosts and db.FragmentCosts[id] and (fragVal or 0) > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                    local ahCost = (id and db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                    local vendorCost = (id and ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0) and ProfLevelHelper_VendorPrices[id] or 999999999
                    local best = math.min(ahCost, vendorCost, fragCost)
                    local useFrag = (fragCost < 999999999 and best == fragCost)
                    if useFrag then
                        qF, qA = totQty, 0
                        fragmentCount = fragmentCount + totQty * (db.FragmentCosts[id] or 0)
                    else
                        qF, qA = 0, totQty
                    end
                end
                
                matSources[i] = { qF = qF, qA = qA, id = id, itemName = itemName, totQty = totQty, unitPrice = (m and m.unitPrice or 0) }
                
                if qA > 0 then
                    local tiers = seg.materialPriceTiers and id and seg.materialPriceTiers[id]
                    if tiers and #tiers > 0 then
                        for _, t in ipairs(tiers) do totalTieredCost = totalTieredCost + (t.price or 0) * (t.qty or 0) end
                    else
                        totalRefCost = totalRefCost + (m and m.unitPrice or 0) * qA
                    end
                end
                
                -- Summary totals
                if id and not buyTotals[id] and not fragTotals[id] then
                    local netQty = netBuyQtyMap[id]
                    if netQty and netQty > 0 then
                        if routeFragmentCountProvided then
                            buyTotals[id] = { name = itemName, qty = netQty }
                        else
                            local fragCost = (id and db.FragmentCosts and db.FragmentCosts[id] and (fragVal or 0) > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                            local ahCost = (id and db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                            local vendorCost = (id and ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0) and ProfLevelHelper_VendorPrices[id] or 999999999
                            local best = math.min(ahCost, vendorCost, fragCost)
                            if fragCost < 999999999 and best == fragCost then
                                if not fragOrderSet[id] then fragOrderSet[id] = true; table.insert(fragOrder, id) end
                                fragTotals[id] = { name = itemName, qty = netQty }
                            else
                                buyTotals[id] = { name = itemName, qty = netQty }
                            end
                        end
                    end
                end
            end
            
            local goldMat = (seg.totalMatCost or 0) - fragmentCount * fragVal
            local scale = (totalRefCost and totalRefCost > 0 and (goldMat - totalTieredCost) >= 0) and ((goldMat - totalTieredCost) / totalRefCost) or 1
            
            for i, _ in ipairs(seg.recipe.reagents or {}) do
                local s = matSources[i]
                if s.qF > 0 then
                    local fPerItem = (s.id and db.FragmentCosts and db.FragmentCosts[s.id]) or 0
                    table.insert(matLines, s.itemName .. "(" .. fPerItem .. "碎片/个)*" .. s.qF .. " ->|cff888888总计" .. s.qF .. "|r")
                end
                if s.qA > 0 then
                    local tiers = seg.materialPriceTiers and s.id and seg.materialPriceTiers[s.id]
                    if tiers and #tiers > 0 then
                        local parts = {}
                        local currentAHTotal = 0
                        for _, t in ipairs(tiers) do
                            local pricePart = (t.price and t.price > 0) and ("(" .. CopperToGold(t.price) .. ")") or ""
                            parts[#parts + 1] = pricePart .. "*" .. (t.qty or 0)
                            currentAHTotal = currentAHTotal + (t.qty or 0)
                        end
                        table.insert(matLines, s.itemName .. " " .. table.concat(parts, " ") .. " ->|cff888888总计" .. currentAHTotal .. "|r")
                    else
                        local displayPrice = s.unitPrice * scale
                        local pricePart = (displayPrice > 0) and ("(" .. CopperToGold(displayPrice) .. ")") or ""
                        table.insert(matLines, s.itemName .. pricePart .. "*" .. s.qA .. " ->|cff888888总计" .. s.qA .. "|r")
                    end
                end
            end
            
            reqStr = table.concat(matLines, "\n")
            if reqStr == "" then reqStr = "无" end
            local materialsLine = reqStr
            
            if routeFragmentCountProvided and seg.fragmentSources and next(seg.fragmentSources) then
                routeUsesFragmentCount = true
                local segFragStr = ""
                for id, qty in pairs(seg.fragmentSources) do
                    local itemName = nil
                    if id then
                        if alaAgent and alaAgent.item_name then itemName = alaAgent.item_name(id) end
                        if not itemName then local iname = GetItemInfo(id) if iname then itemName = iname end end
                    end
                    if not itemName then itemName = "ID:" .. tostring(id) end
                    segFragStr = segFragStr .. itemName .. "*" .. tostring(math.floor(qty + 0.5)) .. " "
                    fragTotals[id] = { name = itemName, qty = (fragTotals[id] and fragTotals[id].qty or 0) + qty }
                    if not fragOrderSet[id] then fragOrderSet[id] = true; table.insert(fragOrder, id) end
                end
                -- (We suppress the duplicate fragment list if materialsLine already covers it or just keep it as summary)
                -- Actually user wants to see it in materials. So I keep logic below for extra clarity if needed.
                -- if segFragStr ~= "" then materialsLine = materialsLine .. " | 碎片兑换: " .. segFragStr end
            elseif routeFragmentCountProvided and fragmentCount > 0 then
                routeUsesFragmentCount = true
            end

            local useAH = db and ((db.SellBackMethod == "ah" and not (db.AHSellBackBlacklist and seg.recipe.createdItemID and db.AHSellBackBlacklist[seg.recipe.createdItemID])) or (db.SellBackMethod == "vendor" and ((db.AHSellBackWhitelist and seg.recipe.createdItemID and db.AHSellBackWhitelist[seg.recipe.createdItemID]) or (db.UseDisenchantRecovery and L.IsDisenchantable(seg.recipe.createdItemID)))))
            local useDisenchant = useAH and db and db.UseDisenchantRecovery and seg.recipe.createdItemID and L.IsDisenchantable(seg.recipe.createdItemID)
            local bestSb = (db and db.UseDisenchantRecovery and L.GetBestSellBackPerItem and L.GetBestSellBackPerItem(seg.recipe, db)) or nil
            local sellback = (bestSb and bestSb > 0) and (bestSb * (seg.recipe.numMade or 1) * seg.totalCrafts) or (useAH and (seg.totalSellBackAH or 0) or (seg.totalSellBackVendor or 0))
            local segTotalCost = (seg.totalRecCost or 0) + goldMat
            local segGold = segTotalCost - sellback
            totalCostBeforeSellback = totalCostBeforeSellback + segTotalCost
            totalGold = totalGold + segGold
            totalFragments = totalFragments + fragmentCount
            local goldStr = CopperToGoldSigned(segGold)
            local fragCostStr = fragmentCount > 0 and (tostring(math.floor(fragmentCount + 0.5)) .. " 碎片") or "0 碎片"

            local rNameC = (seg.recipe.recipeName or seg.recipe.name) or "?"
            if not seg.recipe.isKnown then
                rNameC = "|cffffffff" .. rNameC .. "|r\n|cff888888(" .. (seg.recSource or "未知") .. ")|r"
            end
            cRecipe:SetText(rNameC)
            cRecPrice:SetText(CopperToGold(seg.totalRecCost or 0))

            local deVal, breakdown = nil, nil
            if L.GetDisenchantValueAndBreakdown and seg.recipe.createdItemID then
                deVal, breakdown = L.GetDisenchantValueAndBreakdown(seg.recipe.createdItemID)
            end
            local deLine = ""
            if useDisenchant and breakdown and #breakdown > 0 then
                local vendorBetter = (seg.totalSellBackVendor or 0) > (seg.totalSellBackAH or 0)
                local deLabel = vendorBetter and "|cffff4444[卖店优于分解]|r\n" or "分解期望/件:\n"
                local parts = {}
                for _, b in ipairs(breakdown) do
                    local q = (b.expectedQty and tonumber(b.expectedQty)) or 0
                    local displayName = (b.itemID and (GetItemInfo(b.itemID) or (db and db.IDToName and db.IDToName[b.itemID]))) or b.name or "?"
                    parts[#parts + 1] = string.format("%s x%.2f", displayName, q)
                end
                deLine = "\n|cff888888" .. deLabel .. table.concat(parts, "\n") .. "|r"
            end

            cMaterials:SetText(materialsLine)
            
            -- Always show both vendor and AH recovery (same as CSV); when disenchant, show actual disenchant total (use deVal, not bestSb which is max(vendor,de))
            local sellInfo = ("卖NPC: %s\nAH: %s"):format(
                CopperToGold(seg.totalSellBackVendor or 0),
                CopperToGold(seg.totalSellBackAH or 0)
            )
            if useDisenchant and deVal and type(deVal) == "number" and deVal > 0 then
                local totalDE = deVal * (seg.recipe.numMade or 1) * seg.totalCrafts
                sellInfo = sellInfo .. "\n分解: " .. CopperToGold(totalDE)
            end
            cSellback:SetText(sellInfo .. deLine)
            
            cProdCost:SetText(CopperToGold((seg.totalRecCost or 0) + goldMat))
            cNet:SetText(goldStr)
            cFrag:SetText(fragmentCount > 0 and (tostring(math.floor(fragmentCount+0.5))) or "0")

            local heights = {
                cRecipe:GetStringHeight(),
                cRecPrice:GetStringHeight(),
                cMaterials:GetStringHeight(),
                cSellback:GetStringHeight(),
                cProdCost:GetStringHeight(),
                cNet:GetStringHeight()
            }
            local currentHeight = 30
            for _, h in ipairs(heights) do if h > currentHeight then currentHeight = h end end
            row:SetHeight(currentHeight + 8)


            if seg.recipe.createdItemID then
                if ProfLevelHelperDB.SellBackMethod == "ah" then
                    local bl = ProfLevelHelperDB.AHSellBackBlacklist or {}
                    local isBlacklisted = bl[seg.recipe.createdItemID]
                    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    btn:SetSize(80, 18)
                    btn:SetPoint("LEFT", row, "TOPLEFT", colX[10], -14)
                    btn:SetText(isBlacklisted and "开启AH" or "屏蔽AH")
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
                    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    btn:SetSize(80, 18)
                    btn:SetPoint("LEFT", row, "TOPLEFT", colX[10], -14)
                    btn:SetText(isWhitelisted and "不按AH价格回血" or "按AH价格回血")
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
            y = y + currentHeight + 12
        end

        -- Build "要买的" in segment order: each unknown recipe immediately followed by its materials.
        local purchaseList = {}
        local addedRecipes = {}
        local materialAdded = {}
        for _, seg in ipairs(route) do
            if not seg.recipe.isKnown then
                local src = seg.recSource or seg.recipe.acqSource or ""
                local fromAHOrVendor = (src == "拍卖行购买" or src == "NPC 购买")
                if fromAHOrVendor then
                    local rName = (seg.recipe.recipeName or seg.recipe.name) or "?"
                    if rName ~= "?" and not addedRecipes[rName] then
                        addedRecipes[rName] = true
                        purchaseList[#purchaseList + 1] = { type = "recipe", name = rName }
                    end
                end
            end
            for _, r in ipairs(seg.recipe.reagents or {}) do
                local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
                if id and netBuyQtyMap[id] and not fragTotals[id] and not materialAdded[id] then
                    materialAdded[id] = true
                    local t = buyTotals[id]
                    purchaseList[#purchaseList + 1] = { type = "material", name = t and t.name or ("ID:" .. tostring(id)), qty = netBuyQtyMap[id] }
                end
            end
        end
        local buyLineStr = "要买的: "
        for _, e in ipairs(purchaseList) do
            if e.type == "recipe" then
                buyLineStr = buyLineStr .. e.name .. " "
            else
                buyLineStr = buyLineStr .. e.name .. "*" .. e.qty .. " "
            end
        end
        if buyLineStr == "要买的: " then buyLineStr = "要买的: 无" end
        local fragLineStr = "碎片兑换: "
        for _, id in ipairs(fragOrder) do
            local t = fragTotals[id]
            if t then fragLineStr = fragLineStr .. (t.name or ("ID:" .. tostring(id))) .. "*" .. t.qty .. " " end
        end
        if fragLineStr == "碎片兑换: " then
            if routeUsesFragmentCount and totalFragments > 0 then
                fragLineStr = "碎片兑换: 共 " .. tostring(math.floor(totalFragments + 0.5)) .. " 碎片 (路线实际使用)"
            else
                fragLineStr = "碎片兑换: 无"
            end
        end

        local buySummaryLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        table.insert(content.lines, buySummaryLine)
        buySummaryLine:SetPoint("TOPLEFT", 0, -(y + 10))
        buySummaryLine:SetJustifyH("LEFT")
        buySummaryLine:SetText(buyLineStr)
        buySummaryLine:SetWidth(scroll:GetWidth() - 20)
        buySummaryLine:Show()
        y = y + 10 + buySummaryLine:GetStringHeight()

        local fragSummaryLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        table.insert(content.lines, fragSummaryLine)
        fragSummaryLine:SetPoint("TOPLEFT", 0, -(y + 4))
        fragSummaryLine:SetJustifyH("LEFT")
        fragSummaryLine:SetText(fragLineStr)
        fragSummaryLine:SetWidth(scroll:GetWidth() - 20)
        fragSummaryLine:Show()
        y = y + 4 + fragSummaryLine:GetStringHeight()

        local sumLine = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        table.insert(content.lines, sumLine)
        sumLine:SetPoint("TOPLEFT", 0, -(y + 10))
        sumLine:SetJustifyH("LEFT")
        local totalFragStr = totalFragments > 0 and (tostring(math.floor(totalFragments + 0.5)) .. " 碎片") or "0 碎片"
        sumLine:SetText("============\n总计 总成本: " .. CopperToGold(totalCostBeforeSellback) .. "  净成本: " .. CopperToGoldSigned(totalGold) .. "  碎片: " .. totalFragStr .. "\n============")
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
    local function c2sSigned(c) if type(c) ~= "number" then return "0金0银0铜" end; if c < 0 then return "-" .. c2s(-c) end; return c2s(c) end

    local producedQtyMap = {}
    for _, seg in ipairs(data.route) do
        local cid = seg.recipe and seg.recipe.createdItemID
        if cid then
            local qty = (seg.recipe.numMade or 1) * seg.totalCrafts
            producedQtyMap[cid] = (producedQtyMap[cid] or 0) + qty
        end
    end
    local consumedQtyMap = {}
    for _, seg in ipairs(data.route) do
        for _, r in ipairs(seg.recipe.reagents or {}) do
            local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
            if id then
                consumedQtyMap[id] = (consumedQtyMap[id] or 0) + (r.count or 0) * seg.totalCrafts
            end
        end
    end
    local netBuyQtyMap = {}
    for id, consumed in pairs(consumedQtyMap) do
        local net = consumed - (producedQtyMap[id] or 0)
        if net > 0 then netBuyQtyMap[id] = math.ceil(net) end
    end
    local buyTotals = {}
    local fragTotals = {}
    local fragOrder = {}
    local exportFragTotals = {}
    local exportFragOrder = {}
    local exportFragOrderSet = {}

    local exportTotalGold = 0
    local exportTotalCost = 0
    local exportTotalFragments = 0
    local exportRouteUsesFragmentCount = false
    local bodyTxt = ""
    for _, seg in ipairs(data.route) do
        local rNameC = (seg.recipe.recipeName or seg.recipe.name) or "?"
        local reqStr = ""
        local fragStr = ""
        local useRouteFragmentCount = (type(seg.fragmentCount) == "number" and seg.fragmentCount >= 0)
        local fragmentCount = useRouteFragmentCount and seg.fragmentCount or 0
        local totalRefCost = 0
        local materialsListExport = {}
        local totalTieredCostExport = 0
        local tieredMaterialsListExport = {}
        for i, r in ipairs(seg.recipe.reagents or {}) do
            local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
            local itemName = r.name
            if not itemName and id then
                if alaAgent and alaAgent.item_name then itemName = alaAgent.item_name(id) end
                if not itemName then local iname = GetItemInfo(id) if iname then itemName = iname end end
            end
            if not itemName then itemName = "ID:" .. tostring(id or r.itemID) end
            local m = seg.materialDetails and seg.materialDetails[i]
            local totQty = (m and m.qty ~= nil) and m.qty or ((r.count or 0) * seg.totalCrafts)
            local unitPrice = (m and m.unitPrice and m.unitPrice > 0) and m.unitPrice or 0
            local tiersExport = seg.materialPriceTiers and id and seg.materialPriceTiers[id]
            if tiersExport and #tiersExport > 0 then
                local tierCost = 0
                for _, t in ipairs(tiersExport) do tierCost = tierCost + (t.price or 0) * (t.qty or 0) end
                totalTieredCostExport = totalTieredCostExport + tierCost
                tieredMaterialsListExport[#tieredMaterialsListExport + 1] = { itemName = itemName, tiers = tiersExport }
            else
                totalRefCost = totalRefCost + unitPrice * totQty
                materialsListExport[#materialsListExport + 1] = { itemName = itemName, totQty = totQty, unitPrice = unitPrice }
            end
            if not useRouteFragmentCount then
                local fragCost = (id and db.FragmentCosts and db.FragmentCosts[id] and fragVal > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                local ahCost = (id and db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                local vendorCost = (id and ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0) and ProfLevelHelper_VendorPrices[id] or 999999999
                local best = math.min(ahCost, vendorCost, fragCost)
                local useFrag = (fragCost < 999999999 and best == fragCost)
                if useFrag then
                    fragmentCount = fragmentCount + totQty * (db.FragmentCosts[id] or 0)
                    local fragUnit = (id and db.FragmentCosts and db.FragmentCosts[id] and fragVal > 0) and (db.FragmentCosts[id] * fragVal) or nil
                    local fp = fragUnit and ("(" .. c2s(fragUnit) .. ")") or ""
                    fragStr = fragStr .. itemName .. fp .. "*" .. totQty .. " "
                end
            end
            if id and not buyTotals[id] and not fragTotals[id] and not exportFragTotals[id] then
                local netQty = netBuyQtyMap[id]
                if netQty and netQty > 0 then
                    if useRouteFragmentCount then
                        buyTotals[id] = { name = itemName, qty = netQty }
                    else
                        local fragCost = (id and db.FragmentCosts and db.FragmentCosts[id] and fragVal > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                        local ahCost = (id and db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                        local vendorCost = (id and ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0) and ProfLevelHelper_VendorPrices[id] or 999999999
                        local best = math.min(ahCost, vendorCost, fragCost)
                        local useFrag = (fragCost < 999999999 and best == fragCost)
                        if useFrag then
                            if not exportFragOrderSet[id] then exportFragOrderSet[id] = true; table.insert(exportFragOrder, id) end
                            fragTotals[id] = { name = itemName, qty = netQty }
                        else
                            buyTotals[id] = { name = itemName, qty = netQty }
                        end
                    end
                end
            end
        end
        local goldMatExport = (seg.totalMatCost or 0) - fragmentCount * fragVal
        local scaleExport = (totalRefCost and totalRefCost > 0 and (goldMatExport - totalTieredCostExport) >= 0) and ((goldMatExport - totalTieredCostExport) / totalRefCost) or 1
        for _, mat in ipairs(tieredMaterialsListExport) do
            local parts = {}
            for _, t in ipairs(mat.tiers) do
                local pricePart = (t.price and t.price > 0) and ("(" .. c2s(t.price) .. ")") or ""
                parts[#parts + 1] = pricePart .. "*" .. (t.qty or 0)
            end
            reqStr = reqStr .. mat.itemName .. " " .. table.concat(parts, " ") .. " "
        end
        for _, mat in ipairs(materialsListExport) do
            local displayPrice = mat.unitPrice * scaleExport
            local pricePart = (displayPrice > 0) and ("(" .. c2s(displayPrice) .. ")") or ""
            reqStr = reqStr .. mat.itemName .. pricePart .. "*" .. mat.totQty .. " "
        end
        if reqStr == "" then reqStr = "无" end
        local materialsLine = reqStr
        if useRouteFragmentCount and seg.fragmentSources and next(seg.fragmentSources) then
            exportRouteUsesFragmentCount = true
            local segFragStr = ""
            for id, qty in pairs(seg.fragmentSources) do
                local itemName = (db and db.NameToID) and nil
                if not itemName and id then
                    if alaAgent and alaAgent.item_name then itemName = alaAgent.item_name(id) end
                    if not itemName then local iname = GetItemInfo(id) if iname then itemName = iname end end
                end
                if not itemName then itemName = "ID:" .. tostring(id) end
                segFragStr = segFragStr .. itemName .. "*" .. tostring(math.floor(qty + 0.5)) .. " "
                exportFragTotals[id] = { name = itemName, qty = (exportFragTotals[id] and exportFragTotals[id].qty or 0) + qty }
                if not exportFragOrderSet[id] then exportFragOrderSet[id] = true; table.insert(exportFragOrder, id) end
            end
            if segFragStr ~= "" then materialsLine = materialsLine .. " | 碎片兑换: " .. segFragStr end
        elseif useRouteFragmentCount and fragmentCount > 0 then
            exportRouteUsesFragmentCount = true
        elseif fragStr ~= "" then
            materialsLine = materialsLine .. " | 碎片兑换: " .. fragStr
        end

        local useAH = db and ((db.SellBackMethod == "ah" and not (db.AHSellBackBlacklist and seg.recipe.createdItemID and db.AHSellBackBlacklist[seg.recipe.createdItemID])) or (db.SellBackMethod == "vendor" and ((db.AHSellBackWhitelist and seg.recipe.createdItemID and db.AHSellBackWhitelist[seg.recipe.createdItemID]) or (db.UseDisenchantRecovery and L.IsDisenchantable(seg.recipe.createdItemID)))))
        local useDisenchant = useAH and db and db.UseDisenchantRecovery and seg.recipe.createdItemID and L.IsDisenchantable(seg.recipe.createdItemID)
        local bestSbExport = (db and db.UseDisenchantRecovery and L.GetBestSellBackPerItem and L.GetBestSellBackPerItem(seg.recipe, db)) or nil
        local sellback = (bestSbExport and bestSbExport > 0) and (bestSbExport * (seg.recipe.numMade or 1) * seg.totalCrafts) or (useAH and (seg.totalSellBackAH or 0) or (seg.totalSellBackVendor or 0))
        local segTotalCostExport = (seg.totalRecCost or 0) + goldMatExport
        local segGold = segTotalCostExport - sellback
        local fragCostStr = fragmentCount > 0 and (tostring(math.floor(fragmentCount + 0.5)) .. "碎片") or "0碎片"
        local acq = seg.recSource and ("来源:"..seg.recSource) or ""
        exportTotalCost = exportTotalCost + segTotalCostExport
        exportTotalGold = exportTotalGold + segGold
        exportTotalFragments = exportTotalFragments + fragmentCount

        local sellbackLabelExport = useDisenchant and "分解" or "AH"
        local deLineExport = ""
        if useDisenchant and L.GetDisenchantValueAndBreakdown and seg.recipe.createdItemID then
            local _, breakdownExport = L.GetDisenchantValueAndBreakdown(seg.recipe.createdItemID)
            if breakdownExport and #breakdownExport > 0 then
                local vendorBetterExport = (seg.totalSellBackVendor or 0) > (seg.totalSellBackAH or 0)
                local deLabelExport = vendorBetterExport and " 分解产物(卖店比分解更划算, 不建议分解)(期望/件):" or " 分解产物(期望/件):"
                local parts = {}
                for _, b in ipairs(breakdownExport) do
                    local q = (b.expectedQty and tonumber(b.expectedQty)) or 0
                    local displayName = (b.itemID and (GetItemInfo(b.itemID) or (db and db.IDToName and db.IDToName[b.itemID]))) or b.name or "?"
                    local price = (db and db.AHPrices and b.itemID and db.AHPrices[b.itemID]) and db.AHPrices[b.itemID] or 0
                    parts[#parts + 1] = string.format("%s(%s/个) x%.2f", displayName, c2s(price), q)
                end
                deLineExport = deLabelExport .. " " .. table.concat(parts, ", ")
            end
        end
        bodyTxt = bodyTxt .. string.format("[%d-%d] %s x%.0f次 | 配方:%s 制作(金钱):%s 制作(碎片):%s 回血(卖NPC:%s %s:%s) 净花费(金钱):%s 净花费(碎片):%s | %s - 材料: %s%s\n", seg.startSkill, seg.endSkill, rNameC, seg.totalCrafts, c2s(seg.totalRecCost), c2s(goldMatExport), fragCostStr, c2s(seg.totalSellBackVendor), sellbackLabelExport, c2s(seg.totalSellBackAH), c2sSigned(segGold), fragCostStr, acq, materialsLine, deLineExport)
    end

    local purchaseList = {}
    local addedRecipes = {}
    local materialAdded = {}
    for _, seg in ipairs(data.route) do
        if not seg.recipe.isKnown then
            local src = seg.recSource or seg.recipe.acqSource or ""
            if src == "拍卖行购买" or src == "NPC 购买" then
                local rName = (seg.recipe.recipeName or seg.recipe.name) or "?"
                if rName ~= "?" and not addedRecipes[rName] then
                    addedRecipes[rName] = true
                    purchaseList[#purchaseList + 1] = { type = "recipe", name = rName }
                end
            end
        end
        for _, r in ipairs(seg.recipe.reagents or {}) do
            local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
            if id and netBuyQtyMap[id] and not fragTotals[id] and not exportFragTotals[id] and not materialAdded[id] then
                materialAdded[id] = true
                local t = buyTotals[id]
                purchaseList[#purchaseList + 1] = { type = "material", name = t and t.name or ("ID:" .. tostring(id)), qty = netBuyQtyMap[id] }
            end
        end
    end
    local buyLineStr = "要买的: "
    for _, e in ipairs(purchaseList) do
        if e.type == "recipe" then buyLineStr = buyLineStr .. e.name .. " "
        else buyLineStr = buyLineStr .. e.name .. "*" .. e.qty .. " " end
    end
    if buyLineStr == "要买的: " then buyLineStr = "要买的: 无" end
    local fragLineStr = "碎片兑换: "
    local orderForFrag = (#exportFragOrder > 0) and exportFragOrder or fragOrder
    for _, id in ipairs(orderForFrag) do
        local t = exportFragTotals[id] or fragTotals[id]
        if t then fragLineStr = fragLineStr .. (t.name or ("ID:" .. tostring(id))) .. "*" .. t.qty .. " " end
    end
    if fragLineStr == "碎片兑换: " then
        if exportRouteUsesFragmentCount and exportTotalFragments > 0 then
            fragLineStr = "碎片兑换: 共 " .. tostring(math.floor(exportTotalFragments + 0.5)) .. " 碎片 (路线实际使用)"
        else
            fragLineStr = "碎片兑换: 无"
        end
    end

    local totalFragStr = exportTotalFragments > 0 and (tostring(math.floor(exportTotalFragments + 0.5)) .. "碎片") or "0碎片"
    
    -- CSV Generation
    local function escapeCSV(s)
        s = tostring(s or "")
        if s:find('[,"]') or s:find('\n') then
            s = '"' .. s:gsub('"', '""') .. '"'
        end
        return s
    end
    
    local csvLines = {}
    table.insert(csvLines, "冲级点数,配方名,配方价格,制作次数,材料,回血信息,制作成本,净成本,碎片消耗")
    
    local csvTotalQA = {}
    local csvTotalQF = {}
    local csvMatNames = {}
    
    for _, seg in ipairs(data.route) do
        -- Gather material details for CSV
        local matDetailStr = ""
        local useRouteFragmentCount = (type(seg.fragmentCount) == "number" and seg.fragmentCount >= 0)
        local fragmentCount = useRouteFragmentCount and seg.fragmentCount or 0
        local totalTieredCostSeg = 0
        local matInfos = {}
        for i, r in ipairs(seg.recipe.reagents or {}) do
            local id = r.itemID or (db and db.NameToID and db.NameToID[r.name])
            local itemName = r.name
            if not itemName and id then
                if alaAgent and alaAgent.item_name then itemName = alaAgent.item_name(id) end
                if not itemName then local iname = GetItemInfo(id) if iname then itemName = iname end end
            end
            if not itemName then itemName = "ID:" .. tostring(id or r.itemID) end
            local m = seg.materialDetails and seg.materialDetails[i]
            local totQty = (m and m.qty ~= nil) and m.qty or ((r.count or 0) * seg.totalCrafts)
            
            local qF, qA = 0, 0
            if useRouteFragmentCount then
                qF = (seg.fragmentSources and seg.fragmentSources[id]) or 0
                qA = totQty - qF
            else
                local fragCost = (id and db and db.FragmentCosts and db.FragmentCosts[id] and fragVal > 0) and (db.FragmentCosts[id] * fragVal) or 999999999
                local ahCost = (id and db.AHPrices and db.AHPrices[id] and db.AHPrices[id] > 0) and db.AHPrices[id] or 999999999
                local vendorCost = (id and ProfLevelHelper_VendorPrices and ProfLevelHelper_VendorPrices[id] and ProfLevelHelper_VendorPrices[id] > 0) and ProfLevelHelper_VendorPrices[id] or 999999999
                local best = math.min(ahCost, vendorCost, fragCost)
            if (fragCost < 999999999 and best == fragCost) then qF, qA = totQty, 0 else qF, qA = 0, totQty end
            end
            
            if qA > 0 or qF > 0 then csvMatNames[id] = itemName end
            csvTotalQA[id] = (csvTotalQA[id] or 0) + qA
            csvTotalQF[id] = (csvTotalQF[id] or 0) + qF
            
            if qF > 0 then
                local fPerItem = (id and db.FragmentCosts and db.FragmentCosts[id]) or 0
                matInfos[#matInfos+1] = itemName .. "(" .. (fPerItem * qF) .. "碎片)->总计" .. qF
            end
            if qA > 0 then
                local tiersExport = seg.materialPriceTiers and id and seg.materialPriceTiers[id]
                if tiersExport and #tiersExport > 0 then
                    local priceParts = {}
                    for _, t in ipairs(tiersExport) do priceParts[#priceParts+1] = c2s(t.price) .. "*" .. t.qty end
                    matInfos[#matInfos+1] = itemName .. "(" .. table.concat(priceParts, " + ") .. ")->总计" .. qA
                else
                    local unitPrice = (m and m.unitPrice and m.unitPrice > 0) and m.unitPrice or 0
                    -- In export we don't scale as easily without re-running segment logic, 
                    -- but scaleExport is usually 1 if data is consistent.
                    matInfos[#matInfos+1] = itemName .. "(" .. c2s(unitPrice) .. ")*" .. qA .. "->总计" .. qA
                end
            end
        end
        matDetailStr = table.concat(matInfos, "\n")
        
        local goldMatSeg = (seg.totalMatCost or 0) - fragmentCount * fragVal
        local useAH = db and ((db.SellBackMethod == "ah" and not (db.AHSellBackBlacklist and seg.recipe.createdItemID and db.AHSellBackBlacklist[seg.recipe.createdItemID])) or (db.SellBackMethod == "vendor" and ((db.AHSellBackWhitelist and seg.recipe.createdItemID and db.AHSellBackWhitelist[seg.recipe.createdItemID]) or (db.UseDisenchantRecovery and L.IsDisenchantable(seg.recipe.createdItemID)))))
        local useDisenchant = useAH and db and db.UseDisenchantRecovery and seg.recipe.createdItemID and L.IsDisenchantable(seg.recipe.createdItemID)
        local bestSbExport = (db and db.UseDisenchantRecovery and L.GetBestSellBackPerItem and L.GetBestSellBackPerItem(seg.recipe, db)) or nil
        local sellback = (bestSbExport and bestSbExport > 0) and (bestSbExport * (seg.recipe.numMade or 1) * seg.totalCrafts) or (useAH and (seg.totalSellBackAH or 0) or (seg.totalSellBackVendor or 0))
        local segGold = (seg.totalRecCost or 0) + goldMatSeg - sellback
        
        local sellbackInfo = "卖NPC:" .. c2s(seg.totalSellBackVendor or 0) .. "\n卖AH:" .. c2s(seg.totalSellBackAH or 0)
        if useDisenchant then
            local deVal = L.GetDisenchantValueAndBreakdown and L.GetDisenchantValueAndBreakdown(seg.recipe.createdItemID)
            if deVal and deVal > 0 then
                sellbackInfo = sellbackInfo .. "\n分解:" .. c2s(deVal * (seg.recipe.numMade or 1) * seg.totalCrafts)
            end
        end

        local csvRow = {
            ("[%d-%d]"):format(seg.startSkill, seg.endSkill),
            seg.recipe.recipeName or seg.recipe.name or "?",
            c2s(seg.totalRecCost or 0),
            seg.totalCrafts,
            matDetailStr,
            sellbackInfo,
            c2s((seg.totalRecCost or 0) + goldMatSeg),
            c2sSigned(segGold),
            fragmentCount > 0 and (tostring(math.floor(fragmentCount + 0.5))) or "0"
        }
        local escaped = {}
        for _, v in ipairs(csvRow) do table.insert(escaped, escapeCSV(v)) end
        table.insert(csvLines, table.concat(escaped, ","))
    end
    
    -- Aggregate all unique materials (buy + frag) for final summary row
    local buyIds = {}
    local fragIds = {}
    for id, qty in pairs(csvTotalQA) do if qty > 0 then table.insert(buyIds, id) end end
    for id, qty in pairs(csvTotalQF) do if qty > 0 then table.insert(fragIds, id) end end
    
    local function getCName(id) return csvMatNames[id] or ("ID:"..tostring(id)) end
    table.sort(buyIds, function(a, b) return getCName(a) < getCName(b) end)
    table.sort(fragIds, function(a, b) return getCName(a) < getCName(b) end)

    local buyLines = {}
    for _, id in ipairs(buyIds) do table.insert(buyLines, getCName(id) .. "*" .. csvTotalQA[id]) end
    local fragLines = {}
    for _, id in ipairs(fragIds) do table.insert(fragLines, getCName(id) .. "*" .. csvTotalQF[id]) end

    local buyStr = #buyLines > 0 and ("AH/NPC: " .. table.concat(buyLines, " | ")) or ""
    local fragStr = #fragLines > 0 and ("碎片兑换: " .. table.concat(fragLines, " | ")) or ""
    local totalMatSummary = ""
    if buyStr ~= "" and fragStr ~= "" then totalMatSummary = buyStr .. "\n" .. fragStr
    elseif buyStr ~= "" then totalMatSummary = buyStr
    elseif fragStr ~= "" then totalMatSummary = fragStr
    else totalMatSummary = "-" end

    -- Total Row
    local totalRow = {
        "总计",
        "-",
        "-",
        "-",
        totalMatSummary,
        "-",
        c2s(exportTotalCost),
        c2sSigned(exportTotalGold),
        tostring(math.floor(exportTotalFragments + 0.5))
    }
    local escapedTotal = {}
    for _, v in ipairs(totalRow) do table.insert(escapedTotal, escapeCSV(v)) end
    table.insert(csvLines, table.concat(escapedTotal, ","))

    local txt = table.concat(csvLines, "\n")

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

-- Show AH-derived fragment value table: for each item in FragmentCosts with AH price, value per fragment = (AH*0.95)/frags, sorted high to low.
function L.ShowFragmentValueTable()
    local fc = ProfLevelHelper_FragmentCosts
    local db = ProfLevelHelperDB
    if not fc or not db or not db.AHPrices or not next(db.AHPrices) then
        L.Print("请先扫描拍卖行，并确保 FragmentCosts.lua 中已配置物品。")
        return
    end
    local list = {}
    for itemID, fragPerUnit in pairs(fc) do
        if type(itemID) == "number" and type(fragPerUnit) == "number" and fragPerUnit > 0 then
            local ahPrice = db.AHPrices[itemID]
            if ahPrice and ahPrice > 0 then
                local valuePerFrag = math.floor(ahPrice * 0.95 / fragPerUnit + 0.5)
                local name = GetItemInfo(itemID) or (db.IDToName and db.IDToName[itemID]) or ("ID:" .. tostring(itemID))
                list[#list + 1] = { itemID = itemID, valuePerFrag = valuePerFrag, name = name, fragPerUnit = fragPerUnit }
            end
        end
    end
    table.sort(list, function(a, b) return a.valuePerFrag > b.valuePerFrag end)

    local f = L.FragmentValueTableFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        L.FragmentValueTableFrame = f
        f:SetSize(420, 380)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        if L.OptionsFrame then f:SetFrameLevel(L.OptionsFrame:GetFrameLevel() + 10) end
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("当前碎片价值 (AH价税后/片，从高到低)")
        f.title = title
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -36)
        scroll:SetPoint("BOTTOMRIGHT", -28, 44)
        f.scroll = scroll
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(scroll:GetWidth() - 20, 1)
        scroll:SetScrollChild(content)
        f.scrollContent = content
        local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        close:SetSize(80, 22)
        close:SetPoint("BOTTOMRIGHT", -12, 12)
        close:SetText("关闭")
        close:SetScript("OnClick", function() f:Hide() end)
        local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        copyBtn:SetSize(100, 22)
        copyBtn:SetPoint("BOTTOMLEFT", 12, 12)
        copyBtn:SetText("复制到剪贴板")
        copyBtn:SetScript("OnClick", function()
            local lst = f.currentList
            if not lst or #lst == 0 then return end
            local lines = { "【ProfLevelHelper】当前碎片价值 (AH价税后/片，从高到低) — " .. #lst .. " 种", "" }
            for _, row in ipairs(lst) do
                lines[#lines + 1] = string.format("%s  |  %d铜/片", row.name, row.valuePerFrag)
            end
            local txt = table.concat(lines, "\n")
            local cf = L.FragmentValueCopyFrame
            if not cf then
                cf = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                L.FragmentValueCopyFrame = cf
                cf:SetSize(450, 400)
                cf:SetPoint("CENTER")
                cf:SetFrameStrata("DIALOG")
                cf:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
                cf:SetBackdropColor(0, 0, 0, 0.95)
                cf:EnableMouse(true)
                cf:SetMovable(true)
                cf:RegisterForDrag("LeftButton")
                cf:SetScript("OnDragStart", cf.StartMoving)
                cf:SetScript("OnDragStop", cf.StopMovingOrSizing)
                local title = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                title:SetPoint("TOP", 0, -12)
                title:SetText("按下 Ctrl+C 复制以下文本")
                local eb = CreateFrame("EditBox", nil, cf)
                eb:SetPoint("TOPLEFT", 12, -36)
                eb:SetPoint("BOTTOMRIGHT", -12, 44)
                eb:SetMultiLine(true)
                eb:SetFontObject("ChatFontNormal")
                eb:SetAutoFocus(true)
                eb:SetScript("OnEscapePressed", function() cf:Hide() end)
                cf.editBox = eb
                local cClose = CreateFrame("Button", nil, cf, "UIPanelButtonTemplate")
                cClose:SetSize(80, 22)
                cClose:SetPoint("BOTTOM", 0, 12)
                cClose:SetText("关闭")
                cClose:SetScript("OnClick", function() cf:Hide() end)
            end
            cf.editBox:SetText(txt)
            cf.editBox:HighlightText()
            cf:Show()
        end)
        f.copyBtn = copyBtn
    end
    f.currentList = list
    local content = f.scrollContent
    content:SetHeight(1)
    for k, row in pairs(content) do
        if type(row) == "table" and row.Hide then row:Hide() end
    end
    local ROW_H = 18
    local y = 0
    for i, row in ipairs(list) do
        local line = content["fv_row_" .. i]
        if not line then
            line = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("TOPLEFT", 8, -y)
            line:SetJustifyH("LEFT")
            content["fv_row_" .. i] = line
        end
        local copper = row.valuePerFrag
        local str = string.format("%s  |  %d铜/片", row.name, copper)
        line:SetText(str)
        line:SetWidth(content:GetWidth() - 16)
        line:Show()
        y = y + ROW_H
    end
    content:SetHeight(math.max(1, y))
    for i = #list + 1, 500 do
        local line = content["fv_row_" .. i]
        if line then line:Hide() end
    end
    f.title:SetText("当前碎片价值 (AH价税后/片，从高到低) — " .. #list .. " 种")
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

local ok_ui, err_ui = pcall(function()
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
end)
if not ok_ui and err_ui then
    (L and L.Print or print)("|cffff0000[PLH UI.lua 加载时报错]|r " .. tostring(err_ui))
end

-- Scan button on Auction House frame (above the AH window) so user can scan without opening options.
local function CreateAHScanButton()
    if L.AHScanButtonOnAH or not AuctionFrame then return end
    LoadAddOn("Blizzard_AuctionUI")
    if not AuctionFrame then return end
    local btn = CreateFrame("Button", "ProfLevelHelperAHScanBtn", AuctionFrame, "UIPanelButtonTemplate")
    L.AHScanButtonOnAH = btn
    btn:SetSize(140, 22)
    btn:SetPoint("BOTTOM", AuctionFrame, "TOP", 0, 4)
    btn:SetText("ProfLevelHelper扫描")
    btn:SetScript("OnClick", function()
        if L.ScanAH then L.ScanAH() end
    end)
    -- Sync state when scan runs (same as options-panel button).
    L.ScanAHButton = L.ScanAHButton or btn
end

do
    local ahFrame = CreateFrame("Frame")
    ahFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    ahFrame:SetScript("OnEvent", function()
        local ok, err = pcall(function()
            CreateAHScanButton()
            if L.AHScanButtonOnAH and L.UpdateScanButtonState then
                L.UpdateScanButtonState()
            end
        end)
        if not ok and err then (L and L.Print or print)("|cffff0000[PLH AUCTION_HOUSE_SHOW]|r " .. tostring(err)) end
    end)
end
