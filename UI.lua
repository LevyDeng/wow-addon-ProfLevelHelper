--[[
  UI: options (holiday recipes), result list frame.
]]

local L = ProfLevelHelper

function L.OpenOptions()
    if L.OptionsFrame and L.OptionsFrame:IsShown() then
        L.OptionsFrame:Hide()
        return
    end
    local f = L.OptionsFrame or CreateFrame("Frame", "ProfLevelHelperOptions", UIParent)
    L.OptionsFrame = f
    f:SetSize(320, 120)
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

    local cb = f.checkHoliday or CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 24, -44)
    cb:SetChecked(ProfLevelHelperDB.IncludeHolidayRecipes)
    cb:SetScript("OnClick", function()
        ProfLevelHelperDB.IncludeHolidayRecipes = cb:GetChecked()
    end)
    f.checkHoliday = cb
    local cbLabel = cb.label or cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText("Include holiday/seasonal recipes")
    cb.label = cbLabel

    local close = f.closeBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 22)
    close:SetPoint("BOTTOM", 0, 16)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn = close

    f:Show()
end

function L.ShowResultList()
    local includeHoliday = ProfLevelHelperDB.IncludeHolidayRecipes
    local result, profName, currentSkill = L.BuildLevelingTable(includeHoliday)
    if not result or #result == 0 then
        L.Print(profName and ("No recipes to show for " .. profName .. " at skill " .. tostring(currentSkill)) or "Open profession window first.")
        return
    end

    if L.ResultFrame and L.ResultFrame:IsShown() then
        L.ResultFrame:Hide()
        return
    end

    local f = L.ResultFrame or CreateFrame("Frame", "ProfLevelHelperResult", UIParent)
    L.ResultFrame = f
    f:SetSize(420, 380)
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
    title:SetText(profName and (profName .. " (skill " .. tostring(currentSkill) .. ") - Cheapest first") or "Leveling list")
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
        if not c or c == 0 then return "0g" end
        local g = math.floor(c / 10000)
        local s = math.floor((c % 10000) / 100)
        local co = c % 100
        if g > 0 then return g .. "g" .. s .. "s" .. co .. "c"
        elseif s > 0 then return s .. "s" .. co .. "c"
        else return co .. "c" end
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
        line:SetText(("%d. %s  | chance %.0f%%  | cost: %s  (recipe: %s)"):format(
            i, r.name or "?", (r.chance or 0) * 100, CopperToGold(r.costPerSkillPoint), CopperToGold(r.recipeCost)))
        line:SetWidth(scroll:GetWidth() - 24)
        y = y + lineHeight
    end
    content:SetHeight(y)

    local close = f.closeBtn or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 22)
    close:SetPoint("BOTTOM", 0, 12)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    f.closeBtn = close

    f:Show()
end
