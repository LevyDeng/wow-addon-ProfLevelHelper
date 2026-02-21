--[[
  AH scan: store min price per itemID in ProfLevelHelperDB.AHPrices.
  Improved to mimic EasyAuction: uses a confirmation dialog, small chunk sizes, 
  and asynchronous item loading via Item:ContinueOnItemLoad to prevent skips and client freezes.
]]

local L = ProfLevelHelper

L.AHScanRunning = false
local CHUNK_SIZE = 50 
local BATCH_DELAY = 0.05

local waitingItems = {}
local processedIndexes = {}
local globalUpdatedCount = 0

StaticPopupDialogs["PROFLEVELHELPER_SCAN_CONFIRM"] = {
    text = "|cffff2020警告！|r\n\n本操作将自动全量扫描拍卖行所有物品！\n\n在扫描开始期间（向服务器请求完整数据列表时），游戏画面会发生短暂冻结，这是魔兽世界引擎的正常现象。\n\n此操作可能耗时数秒到十几秒，请确认你已准备好开始扫描。",
    button1 = "继续",
    button2 = "取消",
    OnAccept = function()
        L.StartAHScan()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function L.ScanAH()
    if not CanSendAuctionQuery or not CanSendAuctionQuery() then
        L.Print("当前无法进行全量扫描，请打开拍卖行界面并重试。")
        return
    end
    if L.AHScanRunning then
        L.Print("扫描已经在进行中，请耐心等待完成。")
        return
    end

    StaticPopup_Show("PROFLEVELHELPER_SCAN_CONFIRM")
end

function L.StartAHScan()
    local perFrame = ProfLevelHelperDB.scanPerFrame or CHUNK_SIZE
    if perFrame < 50 then perFrame = 50 elseif perFrame > 500 then perFrame = 200 end

    L.AHScanRunning = true
    L.AHScanStartTime = GetTime()
    L.ShowScanProgress()
    L.UpdateScanButtonState("请求中...")
    L.Print("拍卖行扫描已开始。正在发送请求...")

    waitingItems = {}
    processedIndexes = {}
    globalUpdatedCount = 0
    L.TempAHData = {} -- 用来暂存物品的所有单价与数量排列

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    eventFrame:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        if not L.AHScanRunning then return end
        local n = GetNumAuctionItems and GetNumAuctionItems("list") or 0
        if n > 0 then
            L.Print(string.format("收到服务器响应（共 %d 个物品），正在本地异步处理...", n))
            L.ProcessChunk(0, perFrame)
        else
            L.FinishScan()
            L.Print("拍卖行扫描结束，当前拍卖行没有物品。")
        end
    end)

    local function doQuery()
        QueryAuctionItems("", 0, 0, 0, false, 0, true, true, nil)
    end

    -- Ensure we are on Browse tab before query (matches EasyAuction safe query approach)
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
                L.Print("触发超时保护，当前列表已有数据，强制进入处理队列...")
                L.ProcessChunk(0, perFrame)
            else
                L.FinishScan()
                L.Print("向服务器请求超时，未获取到任何拍卖数据。")
            end
        end)
    end
end

local RETRY_DELAY = 1.0
local RETRY_TIMEOUT = 10.0

local function processItemData(i, itemId, name, count, buyout)
    if not L.AHScanRunning then return false end
    if not itemId or itemId <= 0 or not buyout or buyout <= 0 or not count or count <= 0 then return false end
    
    local db = ProfLevelHelperDB
    db.NameToID = db.NameToID or {}

    if name and name ~= "" then db.NameToID[name] = itemId end
    
    local unitPrice = buyout / count
    
    local itemData = L.TempAHData[itemId]
    if not itemData then
        itemData = { totalQ = 0, listings = {} }
        L.TempAHData[itemId] = itemData
    end
    itemData.totalQ = itemData.totalQ + count
    table.insert(itemData.listings, { price = unitPrice, count = count })
    
    processedIndexes[i] = true
    return true
end

function L.ProcessChunk(startIndex, perFrame)
    if not L.AHScanRunning or not GetNumAuctionItems then return end
    local num = GetNumAuctionItems("list")
    if num == 0 then
        L.FinishScan()
        return
    end

    -- Handle when we've reached the end of the base index iteration
    if startIndex >= num then
        local hasWaiting = false
        local waitingCount = 0
        for idx, _ in pairs(waitingItems) do
            if not processedIndexes[idx] then
                hasWaiting = true 
                waitingCount = waitingCount + 1
            end
        end
        
        if hasWaiting then
            L.UpdateScanProgress(num, num, GetTime() - (L.AHScanStartTime or GetTime()), string.format("等待异步物品缓存加速中... (%d 当前未加载)", waitingCount))
            C_Timer.After(0.5, function()
                if L.AHScanRunning then L.ProcessChunk(startIndex, perFrame) end
            end)
            return
        end
        
        -- Fully completed
        L.FinishScan()
        return
    end

    perFrame = perFrame or CHUNK_SIZE
    local endIdx = math.min(startIndex + perFrame, num)

    -- GetAuctionItemInfo return order: name, texture, count, ..., buyout(10th), ..., itemID(17th)
    for i = startIndex + 1, endIdx do
        if not processedIndexes[i] then
            local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemId = GetAuctionItemInfo("list", i)
            local link = GetAuctionItemLink("list", i)
            
            if itemId and itemId > 0 and buyout and count and count > 0 then
                local safeName = link and select(1, GetItemInfo(link)) or name
                
                if safeName and safeName ~= "" then
                    -- Synchronous process success
                    if processItemData(i, itemId, safeName, count, buyout) then
                        globalUpdatedCount = globalUpdatedCount + 1
                    end
                else
                    -- Asynchronous tracking needed
                    if not waitingItems[i] then
                        waitingItems[i] = {
                            itemId = itemId, count = count, buyout = buyout, retry = 0, startTime = GetTime()
                        }
                        if Item and Item.CreateFromItemID then
                            local item = Item:CreateFromItemID(itemId)
                            item:ContinueOnItemLoad(function()
                                C_Timer.After(0, function()
                                    local ref = waitingItems[i]
                                    if ref and L.AHScanRunning then
                                        local loadedLink = GetAuctionItemLink("list", i)
                                        local loadedName = loadedLink and select(1, GetItemInfo(loadedLink)) or name
                                        if loadedName and loadedName ~= "" then
                                            if processItemData(i, ref.itemId, loadedName, ref.count, ref.buyout) then
                                                globalUpdatedCount = globalUpdatedCount + 1
                                            end
                                            waitingItems[i] = nil
                                            processedIndexes[i] = true
                                        end
                                    end
                                end)
                            end)
                        end
                    end
                end
            else
                -- Not a valid auction item, just skip
                processedIndexes[i] = true
            end
        end
    end
    
    -- Cleanup strictly timed-out items that refuse to load
    local now = GetTime()
    for idx, ref in pairs(waitingItems) do
        if not processedIndexes[idx] and (now - ref.startTime > RETRY_TIMEOUT) then
            waitingItems[idx] = nil
            processedIndexes[idx] = true
        end
    end

    L.UpdateScanProgress(endIdx, num, GetTime() - (L.AHScanStartTime or GetTime()))

    if endIdx <= num then
        if C_Timer and C_Timer.After then
            C_Timer.After(BATCH_DELAY, function()
                if L.AHScanRunning then
                    L.ProcessChunk(endIdx, perFrame)
                end
            end)
        end
    end
end

function L.FinishScan()
    local db = ProfLevelHelperDB
    db.AHPrices = db.AHPrices or {}
    
    local pct = db.IgnoredOutlierPercent
    if pct == nil then pct = 0.10 end -- default: ignore bottom 10% (outlier low prices)
    if pct > 1 then pct = pct / 100 end -- normalize if saved as e.g. 10 instead of 0.10
    pct = math.max(0, math.min(1, pct))
    
    L.Print("扫描完成，正在利用百分位过滤算法结算各物品基准价...")
    globalUpdatedCount = 0
    
    if L.TempAHData then
        for itemId, data in pairs(L.TempAHData) do
            if not data.listings or #data.listings == 0 then
                -- skip items with no valid listings (defensive)
            else
                -- sort by unit price ascending
                table.sort(data.listings, function(a, b) return (a.price or 0) < (b.price or 0) end)
                
                local firstPrice = data.listings[1] and data.listings[1].price
                if firstPrice == nil or type(firstPrice) ~= "number" then
                    -- skip invalid first listing
                else
                    -- benchmark: price at (pct * totalQ) quantity percentile
                    local totalQ = data.totalQ or 0
                    if totalQ <= 0 then totalQ = 1 end
                    local targetQ = math.max(1, math.ceil(totalQ * pct))
                    local accum = 0
                    local finalPrice = firstPrice
                    
                    for _, list in ipairs(data.listings) do
                        accum = accum + (list.count or 0)
                        if list.price ~= nil and type(list.price) == "number" and accum >= targetQ then
                            finalPrice = list.price
                            break
                        end
                    end
                    
                    finalPrice = math.floor(finalPrice + 0.5)
                    if type(finalPrice) == "number" and finalPrice >= 0 then
                        local prev = db.AHPrices[itemId]
                        if not prev or finalPrice ~= prev then
                            db.AHPrices[itemId] = finalPrice
                            globalUpdatedCount = globalUpdatedCount + 1
                        end
                    end
                end
            end
        end
    end
    L.TempAHData = nil
    
    L.AHScanRunning = false
    L.HideScanProgress()
    L.UpdateScanButtonState()
    L.Print(string.format("全量扫描并结算圆满结束！当前记录了 %d 种物品的价格 (新增/更新: %d, 极低价过滤比例: %d%%)。", 
        L.TableCount(db.AHPrices), globalUpdatedCount, math.floor((pct or 0) * 100)))
end

function L.TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function L.OnMerchantShow()
    ProfLevelHelper.RecordVendorPrices()
end

