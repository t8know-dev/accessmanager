-- cashier.lua - Cashier Computer (computer_391)

local config = require("config")
local uuid   = require("uuid")

local kasaMonitor = peripheral.find("monitor")
if kasaMonitor then
    kasaMonitor.setTextScale(0.5)
    term.redirect(kasaMonitor)
end

local basalt = require("basalt")

local depositor = peripheral.wrap(config.DEPOSITOR_NAME)
    or error("Depositor not found: " .. config.DEPOSITOR_NAME, 0)

local printer = peripheral.wrap(config.PRINTER_SIDE)
    or error("Printer not found on side: " .. config.PRINTER_SIDE, 0)

local relayLock = peripheral.wrap(config.RELAY_DEPOSIT_LOCK_NAME)
    or error("Relay (lock) not found: " .. config.RELAY_DEPOSIT_LOCK_NAME, 0)

local relayPulse = peripheral.wrap(config.RELAY_DEPOSIT_OUT_NAME)
    or error("Relay (pulse) not found: " .. config.RELAY_DEPOSIT_OUT_NAME, 0)

local detector = peripheral.find("entity_detector")
if not detector then
    error("Entity Detector not found! Check connections.", 0)
end

rednet.open(config.KASA_MODEM_SIDE)
depositor.setTotalPrice(config.TICKET_PRICE_SPURS)
relayLock.setOutput(config.RELAY_DEPOSIT_LOCK_SIDE, true)

local state = {
    status        = "idle",
    lastTicketKey = nil,
    lastNick      = nil,
    soldCount     = 0,
    logLines      = {},
    detectedNick  = nil,
    purchasing    = false,
}

local cancelRequested = false

local main = basalt.getMainFrame()
main:setBackground(colors.black)

local W, H = term.getSize()

main:addLabel()
    :setText(" " .. config.BASE_NAME .. " - TICKET BOOTH ")
    :setPosition(1, 1)
    :setSize(W, 1)
    :setBackground(colors.blue)
    :setForeground(colors.white)

main:addLabel()
    :setText("Single-use ticket: " .. config.TICKET_PRICE_SPURS .. " spur")
    :setPosition(2, 3)
    :setForeground(colors.yellow)

local statusBox = main:addLabel()
    :setText("[ Waiting ]")
    :setPosition(2, 5)
    :setSize(W - 2, 1)
    :setForeground(colors.lime)

main:addLabel()
    :setText("Detected player:")
    :setPosition(2, 7)
    :setForeground(colors.gray)

local detectedLabel = main:addLabel()
    :setText("(no player nearby)")
    :setPosition(2, 8)
    :setSize(W - 2, 1)
    :setForeground(colors.orange)

main:addLabel()
    :setText("Last ticket:")
    :setPosition(2, 10)
    :setForeground(colors.gray)

local lastKeyLabel = main:addLabel()
    :setText("-")
    :setPosition(2, 11)
    :setSize(W - 2, 1)
    :setForeground(colors.cyan)

local lastNickLabel = main:addLabel()
    :setText("")
    :setPosition(2, 12)
    :setSize(W - 2, 1)
    :setForeground(colors.lightGray)

main:addLabel()
    :setText("Log:")
    :setPosition(2, 14)
    :setForeground(colors.gray)

local logLabels = {}
for i = 1, 3 do
    logLabels[i] = main:addLabel()
        :setText("")
        :setPosition(2, 14 + i)
        :setSize(W - 2, 1)
        :setForeground(colors.lightGray)
end

local counterLabel = main:addLabel()
    :setText("Sold: 0")
    :setPosition(2, H)
    :setForeground(colors.gray)

local buyBtn = main:addButton()
    :setText(" BUY TICKET ")
    :setPosition(2, H - 3)
    :setSize(16, 3)
    :setBackground(colors.green)
    :setForeground(colors.white)

local cancelBtn = main:addButton()
    :setText(" CANCEL ")
    :setPosition(W - 16, H - 3)
    :setSize(16, 3)
    :setBackground(colors.red)
    :setForeground(colors.white)
cancelBtn:setVisible(false)

local function addLog(msg)
    local t = os.date("*t")
    local entry = string.format("[%02d:%02d] %s", t.hour, t.min, msg)
    table.insert(state.logLines, 1, entry)
    if #state.logLines > 3 then table.remove(state.logLines) end
    for i, lbl in ipairs(logLabels) do
        lbl:setText(state.logLines[i] or "")
    end
end

local function setStatus(msg, col)
    statusBox:setText("[ " .. msg .. " ]")
    statusBox:setForeground(col or colors.lime)
end

local function setBuyBtnEnabled(enabled)
    if enabled then
        buyBtn:setBackground(colors.green):setForeground(colors.white)
    else
        buyBtn:setBackground(colors.gray):setForeground(colors.lightGray)
    end
end

local function unlockDepositor()
    relayLock.setOutput(config.RELAY_DEPOSIT_LOCK_SIDE, false)
end

local function lockDepositor()
    relayLock.setOutput(config.RELAY_DEPOSIT_LOCK_SIDE, true)
end

local function detectNearestPlayer()
    local ok, entities = pcall(function() return detector.nearbyEntities() end)
    if not ok or type(entities) ~= "table" then return nil end

    local nearest, nearestDist = nil, math.huge
    for _, e in ipairs(entities) do
        if e.isPlayer then
            local dist = math.sqrt((e.x or 0)^2 + (e.y or 0)^2 + (e.z or 0)^2)
            if dist < nearestDist then
                nearestDist = dist
                nearest = e.name or "Unknown"
            end
        end
    end
    return nearest
end

local function printTicket(key, nick)
    if printer.getPaperLevel() < 1 then
        return false, "No paper in printer!"
    end
    if printer.getInkLevel() < 1 then
        return false, "No ink in printer!"
    end
    if not printer.newPage() then
        return false, "Cannot start printing!"
    end

    local pw = printer.getPageSize()

    printer.setPageTitle(config.TICKET_TITLE)
    printer.setCursorPos(1, 1); printer.write(config.BASE_NAME)
    printer.setCursorPos(1, 2); printer.write(string.rep("=", pw))
    printer.setCursorPos(1, 3); printer.write("Player: " .. nick)
    printer.setCursorPos(1, 4); printer.write("Key:")
    printer.setCursorPos(1, 5); printer.write("  " .. key)

    local t = os.date("*t")
    local dateStr = string.format("%02d/%02d/%04d %02d:%02d",
        t.mday, t.month, t.year, t.hour, t.min)
    printer.setCursorPos(1, 6); printer.write("Date: " .. dateStr)
    printer.setCursorPos(1, 7); printer.write(string.rep("-", pw))
    printer.setCursorPos(1, 8); printer.write("Place on pedestal")
    printer.setCursorPos(1, 9); printer.write("at the base entrance")
    printer.setCursorPos(1, 11); printer.write("! SINGLE-USE TICKET !")

    if not printer.endPage() then
        return false, "Cannot finish printing!"
    end
    return true, nil
end

local function registerTicketAtEntry(key, nick)
    local payload = { key = key, nick = nick, time = os.time() }
    rednet.send(config.ENTRY_COMPUTER_ID, payload, config.PROTOCOL_REGISTER)
    local senderId, msg = rednet.receive(config.PROTOCOL_ACK, config.REDNET_TIMEOUT)
    if senderId == config.ENTRY_COMPUTER_ID and msg == "ok" then
        return true
    end
    return false
end

local function handlePurchase(nick)
    state.status = "waiting_payment"
    cancelRequested = false
    setBuyBtnEnabled(false)
    cancelBtn:setVisible(true)

    unlockDepositor()
    setStatus("Insert " .. config.TICKET_PRICE_SPURS .. " spur into Depositor...", colors.yellow)
    addLog("Waiting for payment: " .. nick)

    -- INVERTED signal: no signal on relay input means payment received
    local paid = false
    local deadline = os.clock() + config.PAYMENT_TIMEOUT

    while os.clock() < deadline and not cancelRequested do
        if not relayPulse.getInput(config.RELAY_DEPOSIT_OUT_SIDE) then
            paid = true
            break
        end
        os.sleep(0.05)
    end

    lockDepositor()
    cancelBtn:setVisible(false)

    if cancelRequested then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Order cancelled", colors.orange)
        addLog("Order cancelled")
        return
    end

    if not paid then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Payment timeout - try again", colors.red)
        addLog("ERROR: no payment within " .. config.PAYMENT_TIMEOUT .. "s")
        return
    end

    addLog("Payment confirmed!")

    state.status = "printing"
    setStatus("Printing ticket...", colors.yellow)

    local key = uuid.generate()
    local printOk, printErr = printTicket(key, nick)
    if not printOk then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Print error: " .. printErr, colors.red)
        addLog("ERROR printing: " .. printErr)
        return
    end

    addLog("Printed ticket for: " .. nick)

    state.status = "sending"
    setStatus("Registering ticket...", colors.yellow)

    local regOk = registerTicketAtEntry(key, nick)
    if not regOk then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("ERROR: no connection to entry!", colors.red)
        addLog("ERROR: entry did not respond")
        addLog("Ticket printed but NOT registered!")
        return
    end

    state.soldCount     = state.soldCount + 1
    state.lastTicketKey = key
    state.lastNick      = nick
    state.status        = "idle"

    lastKeyLabel:setText(key)
    lastNickLabel:setText("Player: " .. nick)
    counterLabel:setText("Sold: " .. state.soldCount)
    setBuyBtnEnabled(true)
    setStatus("Ticket sold! Collect from printer.", colors.lime)
    addLog("OK: " .. key .. " for " .. nick)
end

buyBtn:onClick(function()
    if state.status ~= "idle" then return end

    local nick = state.detectedNick
    if not nick then
        setStatus("No player nearby!", colors.red)
        addLog("Error: no player detected")
        return
    end

    basalt.schedule(function() handlePurchase(nick) end)
end)

cancelBtn:onClick(function()
    cancelRequested = true
end)

-- Background loop: update detected player every second
basalt.schedule(function()
    while true do
        local nick = detectNearestPlayer()
        state.detectedNick = nick
        if nick then
            detectedLabel:setText(nick)
            detectedLabel:setForeground(colors.lime)
        else
            detectedLabel:setText("(no player nearby)")
            detectedLabel:setForeground(colors.orange)
        end
        os.sleep(1)
    end
end)

setStatus("Ready for sale", colors.lime)
addLog("Cashier system started")
addLog("Price: " .. config.TICKET_PRICE_SPURS .. " spur")

basalt.run()
