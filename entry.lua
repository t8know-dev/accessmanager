-- entry.lua - Entry Computer (computer_388)

local config = require("config")
local uuid   = require("uuid")
local db     = require("db")

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

local relayDoor = peripheral.wrap(config.RELAY_DOOR_NAME)
    or error("Relay (door) not found: " .. config.RELAY_DOOR_NAME, 0)

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(1)
end

rednet.open(config.WEJSCIE_MODEM_SIDE)
db.load()

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

    monitor.setBackgroundColor(colors.blue)
    for y = 1, 2 do
        monitor.setCursorPos(1, y)
        monitor.write(string.rep(" ", mw))
    end
    mCenter(1, config.BASE_NAME, colors.white, colors.blue)
    mCenter(2, "ENTRY", colors.yellow, colors.blue)

    monitor.setBackgroundColor(colors.black)
    mCenter(math.floor(mh / 2),     line1 or "", col or colors.white)
    mCenter(math.floor(mh / 2) + 1, line2 or "", colors.lightGray)
    mCenter(mh - 1, "Place ticket on pedestal", colors.gray)
    mCenter(mh,     "to open the entry",        colors.gray)
end

local function openDoor()
    relayDoor.setOutput(config.RELAY_DOOR_SIDE1, true)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE2, true)
    sleep(config.DOOR_OPEN_SECONDS)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE1, false)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE2, false)
end

-- Recursively search NBT table for a XXXX-XXXX-XXXX key pattern
local function extractKeyFromNBT(rawNBT)
    if type(rawNBT) ~= "table" then return nil end

    local function searchTable(t, depth)
        if depth > 5 then return nil end
        for k, v in pairs(t) do
            if type(v) == "string" then
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

local function destroyTicket()
    local dumpName = peripheral.getName(dumpChest)
    local moved = pedestal.pushItems(dumpName, 1)
    return moved > 0
end

local function verifyAndProcess()
    local item = pedestal.getItemDetail(1)
    if not item then return end

    if not item.name:find("printed") and not item.name:find("computercraft") then
        monDraw("! WRONG ITEM !", "This is not a ticket", colors.red)
        sleep(2)
        monDraw("Waiting...", "Place ticket on pedestal")
        return
    end

    monDraw("Verifying...", "", colors.yellow)

    local key = nil
    if item.rawNBT then
        key = extractKeyFromNBT(item.rawNBT)
    end
    if not key and item.displayName then
        key = item.displayName:match("([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])")
    end

    if not key then
        monDraw("! INVALID !", "No key found in ticket", colors.red)
        sleep(3)
        monDraw("Waiting...", "Place ticket on pedestal")
        return
    end

    local entry = db.getTicket(key)

    if not entry then
        monDraw("! REJECTED !", "Key: " .. key, colors.red)
        sleep(3)
        monDraw("Waiting...", "Place ticket on pedestal")
        return
    end

    -- Single-use: remove from DB before opening door
    db.removeTicket(key)
    db.save()
    destroyTicket()

    monDraw("ENTRY OPEN", "Welcome, " .. entry.nick .. "!", colors.lime)
    openDoor()

    monDraw("Waiting...", "Place ticket on pedestal")
end

local function listenForRegistrations()
    while true do
        local senderId, msg, protocol = rednet.receive(config.PROTOCOL_REGISTER, 1)

        if senderId == config.KASA_COMPUTER_ID
            and protocol == config.PROTOCOL_REGISTER
            and type(msg) == "table"
            and msg.key and msg.nick
        then
            print(string.format("[ENTRY] Register: key=%s nick=%s from=%d",
                tostring(msg.key), tostring(msg.nick), senderId))
            db.addTicket(msg.key, msg.nick, msg.time)
            db.save()
            print("[ENTRY] Saved to DB, sending ACK...")
            rednet.send(senderId, "ok", config.PROTOCOL_ACK)
            print("[ENTRY] ACK sent")

            monDraw("New ticket!", "For: " .. msg.nick, colors.cyan)
            sleep(2)
            monDraw("Waiting...", "Place ticket on pedestal")
        end
    end
end

local function listenForPings()
    while true do
        local senderId, msg = rednet.receive(config.PROTOCOL_PING)
        print(string.format("[ENTRY] Ping from %d, sending pong", senderId))
        rednet.send(senderId, "pong", config.PROTOCOL_PONG)
    end
end

local function scanPedestal()
    while true do
        local item = pedestal.getItemDetail(1)
        if item then
            verifyAndProcess()
        end
        sleep(config.PEDESTAL_POLL_MS)
    end
end

print("[ENTRY] System started")
print("[ENTRY] Tickets in database: " .. db.count())

monDraw("Waiting...", "Place ticket on pedestal")

parallel.waitForAll(
    scanPedestal,
    listenForRegistrations,
    listenForPings
)
