-- cashier.lua - Cashier Computer

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

do
    local opened = false
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "modem" then
            rednet.open(name)
            print("[CASHIER] Opened modem: " .. name .. " isOpen=" .. tostring(rednet.isOpen(name)))
            opened = true
        end
    end
    if not opened then
        error("[CASHIER] No modem found! Check connections.", 0)
    end
end

depositor.setTotalPrice(config.TICKET_PRICE_SPURS)
relayLock.setOutput(config.RELAY_DEPOSIT_LOCK_SIDE, true)

-- ─── Logging ────────────────────────────────────────────────
local LOG_FILE = "/cashier_log.txt"

local function writeLog(msg)
    local t = os.date("*t")
    local ts = string.format("[%04d-%02d-%02d %02d:%02d:%02d]",
        t.year, t.month, t.day, t.hour, t.min, t.sec)
    local line = ts .. " " .. msg
    local prev = term.redirect(term.native())
    print(line)
    term.redirect(prev)
    local f = fs.open(LOG_FILE, "a")
    if f then
        f.writeLine(line)
        f.close()
    end
end

-- ─── State ──────────────────────────────────────────────────
local state = {
    status       = "idle",
    soldCount    = 0,
    detectedNick = nil,
}

local cancelRequested = false

-- ─── GUI setup ──────────────────────────────────────────────
local main = basalt.getMainFrame()
main:setBackground(colors.black)

local W, H = term.getSize()

local function padCenter(text, w)
    local pad = math.max(0, math.floor((w - #text) / 2))
    return string.rep(" ", pad) .. text .. string.rep(" ", w - pad - #text)
end

-- Animated header (row 1)
local headerLabel = main:addLabel()
    :setText(padCenter("*** TICKETS ***", W))
    :setPosition(1, 1)
    :setSize(W, 1)
    :setBackground(colors.blue)
    :setForeground(colors.white)

-- Base name (row 2)
main:addLabel()
    :setText(padCenter(config.BASE_NAME, W))
    :setPosition(1, 2)
    :setSize(W, 1)
    :setBackground(colors.blue)
    :setForeground(colors.yellow)

-- Price (row 4)
main:addLabel()
    :setText("Single-use ticket: " .. config.TICKET_PRICE_SPURS .. " spur")
    :setPosition(2, 4)
    :setForeground(colors.yellow)

-- Status box with background highlight (row 6)
local statusBox = main:addLabel()
    :setText(padCenter("Waiting...", W))
    :setPosition(1, 6)
    :setSize(W, 1)
    :setBackground(colors.gray)
    :setForeground(colors.lime)

-- Player section (rows 8–9)
main:addLabel()
    :setText("Detected player:")
    :setPosition(2, 8)
    :setForeground(colors.gray)

local detectedLabel = main:addLabel()
    :setText("(no player nearby)")
    :setPosition(2, 9)
    :setSize(W - 2, 1)
    :setForeground(colors.orange)

-- Active ticket count from entry (row 11)
local activeLabel = main:addLabel()
    :setText("Tickets in queue: ?")
    :setPosition(2, 11)
    :setForeground(colors.gray)

-- Buttons
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

-- ─── Helpers ─────────────────────────────────────────────────
local function setStatus(msg, col, bg)
    statusBox:setText(padCenter(msg, W))
    statusBox:setForeground(col or colors.lime)
    statusBox:setBackground(bg or colors.gray)
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
    if printer.getPaperLevel() < 1 then return false, "No paper in printer!" end
    if printer.getInkLevel() < 1    then return false, "No ink in printer!"   end
    if not printer.newPage()        then return false, "Cannot start printing!" end

    local pw = printer.getPageSize()
    printer.setPageTitle(config.TICKET_TITLE)
    printer.setCursorPos(1, 1); printer.write(config.BASE_NAME)
    printer.setCursorPos(1, 2); printer.write(string.rep("=", pw))
    printer.setCursorPos(1, 3); printer.write("Player: " .. nick)
    printer.setCursorPos(1, 4); printer.write("Key:")
    printer.setCursorPos(1, 5); printer.write("  " .. key)
    local t = os.date("*t")
    local dateStr = string.format("%02d/%02d/%04d %02d:%02d", t.day, t.month, t.year, t.hour, t.min)
    printer.setCursorPos(1, 6); printer.write("Date: " .. dateStr)
    printer.setCursorPos(1, 7); printer.write(string.rep("-", pw))
    printer.setCursorPos(1, 8); printer.write("Place on pedestal")
    printer.setCursorPos(1, 9); printer.write("at the base entrance")
    printer.setCursorPos(1, 11); printer.write("! SINGLE-USE TICKET !")
    if not printer.endPage() then return false, "Cannot finish printing!" end
    return true, nil
end

local function checkEntryConnection()
    rednet.send(config.ENTRY_COMPUTER_ID, "ping", config.PROTOCOL_PING)
    local senderId, msg = rednet.receive(config.PROTOCOL_PONG, config.REDNET_TIMEOUT)
    return senderId == config.ENTRY_COMPUTER_ID and msg == "pong"
end

local function registerTicketAtEntry(key, nick)
    local payload = { key = key, nick = nick, time = os.time() }
    rednet.send(config.ENTRY_COMPUTER_ID, payload, config.PROTOCOL_REGISTER)
    local senderId, msg = rednet.receive(config.PROTOCOL_ACK, config.REDNET_TIMEOUT)
    return senderId == config.ENTRY_COMPUTER_ID and msg == "ok"
end

local function fetchActiveCount()
    rednet.send(config.ENTRY_COMPUTER_ID, "count", config.PROTOCOL_COUNT_REQUEST)
    local senderId, count = rednet.receive(config.PROTOCOL_COUNT_RESPONSE, config.REDNET_TIMEOUT)
    if senderId == config.ENTRY_COMPUTER_ID and type(count) == "number" then
        return count
    end
    return nil
end

local function refreshActiveLabel()
    local cnt = fetchActiveCount()
    activeLabel:setText("Tickets in queue: " .. (cnt ~= nil and tostring(cnt) or "?"))
end

-- ─── Purchase flow ───────────────────────────────────────────
local function handlePurchase(nick)
    state.status = "busy"
    setBuyBtnEnabled(false)
    setStatus("Checking connection...", colors.yellow, colors.gray)
    writeLog("Purchase started for: " .. nick)

    if not checkEntryConnection() then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("ERROR: entry unreachable!", colors.white, colors.red)
        writeLog("ERROR: entry unreachable for: " .. nick)
        return
    end

    state.status = "waiting_payment"
    cancelRequested = false
    cancelBtn:setVisible(true)
    unlockDepositor()
    setStatus("Insert " .. config.TICKET_PRICE_SPURS .. " spur into Depositor...", colors.yellow, colors.gray)
    writeLog("Waiting for payment: " .. nick)

    -- Wait for depositor to activate: relay must go HIGH before we start watching for LOW (paid)
    local activateDeadline = os.clock() + 3
    while os.clock() < activateDeadline do
        if relayPulse.getInput(config.RELAY_DEPOSIT_OUT_SIDE) then break end
        os.sleep(0.05)
    end
    if relayPulse.getInput(config.RELAY_DEPOSIT_OUT_SIDE) then
        lockDepositor()
        cancelBtn:setVisible(false)
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Depositor not ready!", colors.white, colors.red)
        writeLog("ERROR: depositor did not activate for: " .. nick)
        return
    end

    local paid = false
    local deadline = os.clock() + config.PAYMENT_TIMEOUT
    while os.clock() < deadline and not cancelRequested do
        if not relayPulse.getInput(config.RELAY_DEPOSIT_OUT_SIDE) then
            paid = true; break
        end
        os.sleep(0.05)
    end

    lockDepositor()
    cancelBtn:setVisible(false)

    if cancelRequested then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Order cancelled", colors.orange, colors.gray)
        writeLog("Order cancelled for: " .. nick)
        return
    end

    if not paid then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Payment timeout - try again", colors.white, colors.red)
        writeLog("ERROR: payment timeout for: " .. nick)
        return
    end

    writeLog("Payment confirmed for: " .. nick)
    state.status = "printing"
    setStatus("Printing ticket...", colors.yellow, colors.gray)

    local key = uuid.generate()
    local printOk, printErr = printTicket(key, nick)
    if not printOk then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Print error: " .. printErr, colors.white, colors.red)
        writeLog("ERROR printing for " .. nick .. ": " .. printErr)
        return
    end

    writeLog("Ticket printed for: " .. nick)
    state.status = "sending"
    setStatus("Registering ticket...", colors.yellow, colors.gray)

    if not registerTicketAtEntry(key, nick) then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("ERROR: entry did not respond!", colors.white, colors.red)
        writeLog("ERROR: entry ACK failed for " .. nick .. " - ticket NOT registered!")
        return
    end

    state.soldCount = state.soldCount + 1
    state.status    = "idle"
    refreshActiveLabel()
    setBuyBtnEnabled(true)
    setStatus("Ticket sold! Collect from pedestal.", colors.white, colors.lime)
    writeLog("SOLD: ticket for " .. nick .. " (session total: " .. state.soldCount .. ")")
end

-- ─── Button handlers ─────────────────────────────────────────
buyBtn:onClick(function()
    if state.status ~= "idle" then return end
    local nick = state.detectedNick
    if not nick then
        setStatus("No player nearby!", colors.white, colors.red)
        writeLog("Purchase attempt: no player detected")
        return
    end
    basalt.schedule(function() handlePurchase(nick) end)
end)

cancelBtn:onClick(function()
    cancelRequested = true
end)

-- ─── Background tasks ────────────────────────────────────────
-- Update detected player every second
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

-- Animated header: cycle frames to force Basalt re-render (setText triggers render)
basalt.schedule(function()
    local frames = {
        { bg = colors.blue,      fg = colors.white,  tx = "  * TICKETS *  " },
        { bg = colors.cyan,      fg = colors.yellow,  tx = "  ** TICKETS **  " },
        { bg = colors.lightBlue, fg = colors.white,  tx = "  *** TICKETS ***  " },
        { bg = colors.blue,      fg = colors.yellow, tx = "  >   TICKETS   <  " },
        { bg = colors.purple,    fg = colors.white,  tx = "  >>  TICKETS  <<  " },
        { bg = colors.blue,      fg = colors.cyan,   tx = "  >>> TICKETS <<<  " },
    }
    local i = 1
    while true do
        local f = frames[i]
        headerLabel:setBackground(f.bg)
        headerLabel:setForeground(f.fg)
        headerLabel:setText(padCenter(f.tx, W))
        i = (i % #frames) + 1
        os.sleep(0.5)
    end
end)

-- Fetch active ticket count from entry on startup
basalt.schedule(function() refreshActiveLabel() end)

-- ─── Startup ────────────────────────────────────────────────
setStatus("Ready for sale", colors.lime, colors.gray)
writeLog("=== CASHIER STARTUP === ID: " .. os.getComputerID()
    .. " | Entry ID: " .. config.ENTRY_COMPUTER_ID
    .. " | Price: " .. config.TICKET_PRICE_SPURS .. " spur")
writeLog("Peripherals: " .. table.concat(peripheral.getNames(), ", "))

basalt.run()
