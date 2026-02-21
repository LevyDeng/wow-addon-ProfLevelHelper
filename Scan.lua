--[[
  AH scan: store min price per itemID in ProfLevelHelperDB.AHPrices.
  Pattern follows EasyAuction: one-shot AUCTION_ITEM_LIST_UPDATE, batch processing with
  delay between chunks (scanPerFrame items, then C_Timer.After(0.05) next chunk), 5s fallback.
  Vendor scan: record vendor prices when at merchant (RecipeCost.RecordVendorPrices).
]]

local L = ProfLevelHelper

L.AHScanRunning = false
local CHUNK_SIZE = 100  -- items per batch; 50-200 recommended (EasyAuction uses 50-200)
local BATCH_DELAY = 0.05  -- seconds between chunks to keep UI responsive

function L.ScanAH()
    if not CanSendAuctionQuery or not CanSendAuctionQuery() then
        L.Print("Cannot query AH now. Open auction house and try again.")
        return
    end
    if L.AHScanRunning then
        L.Print("Scan already in progress.")
        return
    end

    local perFrame = ProfLevelHelperDB.scanPerFrame or CHUNK_SIZE
    if perFrame < 50 then perFrame = 50 elseif perFrame > 500 then perFrame = 200 end

    L.AHScanRunning = true
    L.Print("AH scan started. Processing in batches...")

    -- One-shot event: when list arrives, run processor exactly once (like EasyAuction).
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    eventFrame:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        if not L.AHScanRunning then return end
        local n = GetNumAuctionItems and GetNumAuctionItems("list") or 0
        if n > 0 then
            ProcessChunk(1, 0, perFrame)
        else
            L.AHScanRunning = false
            L.Print("AH scan done. No items in list.")
        end
    end)

    local function doQuery()
        -- getAll=true, exactMatch=true. Use 0/false for Classic compatibility.
        QueryAuctionItems("", 0, 0, 0, false, 0, true, true, nil)
    end

    -- Ensure we are on Browse tab before query (EasyAuction does this).
    if AuctionFrame and AuctionFrame:IsShown() and AuctionFrameBrowse and not AuctionFrameBrowse:IsShown() then
        if AuctionFrameTab1 and AuctionFrameTab1.Click then
            AuctionFrameTab1:Click()
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if L.AHScanRunning and AuctionFrameBrowse and AuctionFrameBrowse:IsShown() then
                    doQuery()
                end
            end)
        else
            doQuery()
        end
    else
        doQuery()
    end

    -- Fallback: if event never fires within 5s but list has data, start processing anyway.
    if C_Timer and C_Timer.After then
        C_Timer.After(5, function()
            if not L.AHScanRunning then return end
            local n = GetNumAuctionItems and GetNumAuctionItems("list") or 0
            if n > 0 then
                eventFrame:UnregisterAllEvents()
                ProcessChunk(1, 0, perFrame)
            else
                L.AHScanRunning = false
                L.Print("AH scan timed out. No data received.")
            end
        end)
    end
end

-- Process one chunk of items; then schedule next chunk after BATCH_DELAY (like EasyAuction).
function ProcessChunk(startIndex, totalUpdated, perFrame)
    if not L.AHScanRunning or not GetNumAuctionItems then return end
    local num = GetNumAuctionItems("list")
    if num == 0 then
        L.AHScanRunning = false
        local db = ProfLevelHelperDB
        L.Print("AH scan done. Total items: " .. (db.AHPrices and L.TableCount(db.AHPrices) or 0))
        return
    end

    perFrame = perFrame or CHUNK_SIZE
    local db = ProfLevelHelperDB
    db.AHPrices = db.AHPrices or {}
    db.NameToID = db.NameToID or {}
    local endIdx = math.min(startIndex + perFrame - 1, num)
    local updated = totalUpdated or 0

    -- GetAuctionItemInfo return order (match EasyAuction): name, texture, count, ..., buyout(10th), ..., itemID(17th)
    for i = startIndex, endIdx do
        local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemId =
            GetAuctionItemInfo("list", i)
        if itemId and itemId > 0 then
            if name and name ~= "" then db.NameToID[name] = itemId end
            local price = (buyout and buyout > 0) and buyout or nil
            if price and count and count > 0 then
                local unitPrice = math.floor(price / count + 0.5)
                local prev = db.AHPrices[itemId]
                if not prev or unitPrice < prev then
                    db.AHPrices[itemId] = unitPrice
                    updated = updated + 1
                end
            end
        end
    end

    local nextStart = endIdx + 1
    if nextStart <= num then
        if C_Timer and C_Timer.After then
            C_Timer.After(BATCH_DELAY, function()
                if L.AHScanRunning then
                    ProcessChunk(nextStart, updated, perFrame)
                end
            end)
        else
            local f = L.AHScanScanFrame or CreateFrame("Frame")
            L.AHScanScanFrame = f
            f.nextIndex = nextStart
            f.updated = updated
            f.perFrame = perFrame
            f:SetScript("OnUpdate", function(frame)
                frame:SetScript("OnUpdate", nil)
                if L.AHScanRunning then
                    ProcessChunk(frame.nextIndex, frame.updated, frame.perFrame)
                end
            end)
        end
    else
        L.AHScanRunning = false
        L.Print("AH scan done. " .. updated .. " prices updated. Total items: " .. L.TableCount(db.AHPrices))
    end
end

function L.TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function L.OnMerchantShow()
    ProfLevelHelper.RecordVendorPrices()
end
