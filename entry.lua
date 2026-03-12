-- =============================================================
--  entry.lua  -  Entry Computer  (computer_388)
--
--  Peripherals:
--    * Modem (wired)        - side config.WEJSCIE_MODEM_SIDE
--      L- Item Pedestal     - config.PEDESTAL_NAME
--      L- Redstone Relay    - config.RELAY_DOOR_NAME (door opening)
--    * Dump chest           - config.DUMP_CHEST_NAME (network) or DUMP_CHEST_SIDE (direct)
--    * Monitor (optional)   - detected via peripheral.find
--
--  Dependencies (place in the same folder or /):
--    * config.lua
--    * uuid.lua
--    * db.lua
-- =============================================================

local config = require("config")
local uuid   = require("uuid")
local db     = require("db")

-- ──────────────────────────────────────────────────────────────
--  PERIPHERAL INITIALISATION
-- ──────────────────────────────────────────────────────────────
local pedestal = peripheral.wrap(config.PEDESTAL_NAME)
    or error("Item Pedestal not found: " .. config.PEDESTAL_NAME, 0)

local dumpChest
if config.DUMP_CHEST_NAME then
    dumpChest = peripheral.wrap(config.DUMP_CHEST_NAME)
        or error("Dump chest not found: " .. config.DUMP_CHEST_NAME, 0)
else
    dumpChest = peripheral.wrap(config.DUMP_CHEST_SIDE)
        or error("Dump chest not found on side: " .. config.DUMP_CHEST_SIDE, 0)
end

-- Relay for door opening (entry computer sets OUTPUT)
local relayDoor = peripheral.wrap(config.RELAY_DOOR_NAME)
    or error("Relay (door) not found: " .. config.RELAY_DOOR_NAME, 0)

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(1)
end

rednet.open(config.WEJSCIE_MODEM_SIDE)

-- ──────────────────────────────────────────────────────────────
--  DATABASE (local file)
-- ──────────────────────────────────────────────────────────────
db.load()

-- ──────────────────────────────────────────────────────────────
--  MONITOR DISPLAY
-- ──────────────────────────────────────────────────────────────
local function monDraw(line1, line2, col)
    if not monitor then return end
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    local mw, mh = monitor.getSize()

    local function mCenter(y, text, fg, bg)
        monitor.setBackgroundColor(bg or colors.black)
        monitor.setTextColor(fg or colors.white)
        monitor.setCursorPos(math.max(1, math.floor((mw - #text) / 2) + 1), y)
        monitor.write(text)
    end

    -- Header
    monitor.setBackgroundColor(colors.blue)
    for y = 1, 2 do
        monitor.setCursorPos(1, y)
        monitor.write(string.rep(" ", mw))
    end
    mCenter(1, config.BASE_NAME, colors.white, colors.blue)
    mCenter(2, "ENTRY", colors.yellow, colors.blue)

    monitor.setBackgroundColor(colors.black)

    -- Main message
    mCenter(math.floor(mh / 2),     line1 or "", col or colors.white)
    mCenter(math.floor(mh / 2) + 1, line2 or "", colors.lightGray)

    -- Instruction at bottom
    mCenter(mh - 1, "Place ticket on pedestal", colors.gray)
    mCenter(mh,     "to open the entry",        colors.gray)
end

-- ──────────────────────────────────────────────────────────────
--  DOOR CONTROL
-- ──────────────────────────────────────────────────────────────
local function openDoor()
    relayDoor.setOutput(config.RELAY_DOOR_SIDE1, true)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE2, true)
    sleep(config.DOOR_OPEN_SECONDS)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE1, false)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE2, false)
end

-- ──────────────────────────────────────────────────────────────
--  TICKET NBT PARSING
-- ──────────────────────────────────────────────────────────────
-- Printed Page in CC stores text in NBT as:
--   pages = [ "line1\nline2\n..." ]
-- We look for a line containing the key (format XXXX-XXXX-XXXX)
local function extractKeyFromNBT(rawNBT)
    if type(rawNBT) ~= "table" then return nil end

    -- rawNBT can be a nested table
    local function searchTable(t, depth)
        if depth > 5 then return nil end
        for k, v in pairs(t) do
            if type(v) == "string" then
                -- Search for UUID pattern in every string
                local found = v:match("([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])")
                if found then return found end
            elseif type(v) == "table" then
                local res = searchTable(v, depth + 1)
                if res then return res end
            end
        end
        return nil
    end

    return searchTable(rawNBT, 0)
end

-- ──────────────────────────────────────────────────────────────
--  TICKET DESTRUCTION (move to dump chest)
-- ──────────────────────────────────────────────────────────────
local function destroyTicket()
    -- Pedestal has inventory API - slot 1 is the displayed item
    local pedestalName = peripheral.getName(pedestal)
    local dumpName     = peripheral.getName(dumpChest)

    -- Move from pedestal slot 1 to dump chest
    local moved = pedestal.pushItems(dumpName, 1)
    return moved > 0
end

-- ──────────────────────────────────────────────────────────────
--  TICKET VERIFICATION
-- ──────────────────────────────────────────────────────────────
local function verifyAndProcess()
    -- Check if something is on the pedestal
    local item = pedestal.getItemDetail(1)
    if not item then return end

    -- Check item type (Printed Page from CC:Tweaked)
    if not item.name:find("printed") and not item.name:find("computercraft") then
        monDraw("! WRONG ITEM !", "This is not a ticket", colors.red)
        sleep(2)
        monDraw("Waiting...", "Place ticket on pedestal")
        return
    end

    monDraw("Verifying...", "", colors.yellow)

    -- Extract key from NBT
    local key = nil
    if item.rawNBT then
        key = extractKeyFromNBT(item.rawNBT)
    end

    -- Fallback: try displayName or tag
    if not key and item.displayName then
        key = item.displayName:match("([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])")
    end

    if not key then
        monDraw("! INVALID !", "No key found in ticket", colors.red)
        sleep(3)
        monDraw("Waiting...", "Place ticket on pedestal")
        return
    end

    -- Check in database
    local entry = db.getTicket(key)

    if not entry then
        monDraw("! REJECTED !", "Key: " .. key, colors.red)
        sleep(3)
        monDraw("Waiting...", "Place ticket on pedestal")
        return
    end

    -- Valid ticket - remove from database (single-use!)
    db.removeTicket(key)
    db.save()

    -- Remove physical ticket from pedestal
    local destroyed = destroyTicket()

    -- Open door
    monDraw("ENTRY OPEN", "Welcome, " .. entry.nick .. "!", colors.lime)

    -- Open door (blocks for DOOR_OPEN_SECONDS)
    openDoor()

    monDraw("Waiting...", "Place ticket on pedestal")
end

-- ──────────────────────────────────────────────────────────────
--  LISTEN FOR TICKET REGISTRATIONS (from cashier)
-- ──────────────────────────────────────────────────────────────
local function listenForRegistrations()
    while true do
        local senderId, msg, protocol = rednet.receive(config.PROTOCOL_REGISTER, 1)

        if senderId == config.KASA_COMPUTER_ID
            and protocol == config.PROTOCOL_REGISTER
            and type(msg) == "table"
            and msg.key and msg.nick
        then
            -- Register ticket in database
            db.addTicket(msg.key, msg.nick, msg.time)
            db.save()

            -- Send ACK
            rednet.send(senderId, "ok", config.PROTOCOL_ACK)

            -- Show on monitor briefly
            monDraw("New ticket!", "For: " .. msg.nick, colors.cyan)
            sleep(2)
            monDraw("Waiting...", "Place ticket on pedestal")
        end
    end
end

-- ──────────────────────────────────────────────────────────────
--  PEDESTAL SCAN LOOP
-- ──────────────────────────────────────────────────────────────
local function scanPedestal()
    while true do
        local item = pedestal.getItemDetail(1)
        if item then
            verifyAndProcess()
        end
        sleep(config.PEDESTAL_POLL_MS)
    end
end

-- ──────────────────────────────────────────────────────────────
--  START
-- ──────────────────────────────────────────────────────────────
print("[ENTRY] System started")
print("[ENTRY] Tickets in database: " .. db.count())
print("[ENTRY] Waiting for tickets and registrations...")

monDraw("Waiting...", "Place ticket on pedestal")

-- Run both loops in parallel
parallel.waitForAll(
    scanPedestal,
    listenForRegistrations
)
