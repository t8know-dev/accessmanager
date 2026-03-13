-- entry.lua - Entry Computer (computer_388)

local config = require("config")
local uuid   = require("uuid")
local db     = require("db")
local wl     = require("whitelist")

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

local monitor = peripheral.wrap(config.ENTRY_MONITOR_NAME)
if monitor then
    monitor.setTextScale(2)
end

do
    local opened = false
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "modem" then
            rednet.open(name)
            print("[ENTRY] Opened modem: " .. name .. " (isOpen=" .. tostring(rednet.isOpen(name)) .. ")")
            opened = true
        end
    end
    if not opened then
        error("[ENTRY] No modem found! Check connections.", 0)
    end
end
db.load()
wl.load()

local function monDraw(state)
    if not monitor then return end
    local w, h = monitor.getSize()

    local bg
    if state == "ok" then
        bg = colors.green
    elseif state == "reject" then
        bg = colors.red
    else
        bg = colors.black
    end

    local old = term.redirect(monitor)
    paintutils.drawFilledBox(1, 1, w, h, bg)
    term.redirect(old)
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
        monDraw("reject")
        sleep(2)
        monDraw("idle")
        return
    end

    monDraw("idle")

    local key = nil
    if item.rawNBT then
        key = extractKeyFromNBT(item.rawNBT)
    end
    if not key and item.displayName then
        key = item.displayName:match("([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])")
    end

    if not key then
        monDraw("reject")
        sleep(3)
        monDraw("idle")
        return
    end

    local entry = db.getTicket(key)

    if not entry or entry.used then
        monDraw("reject")
        sleep(3)
        monDraw("idle")
        return
    end

    -- Single-use: mark as used before opening door
    db.markUsed(key)
    db.save()
    local ok, err = pcall(destroyTicket)
    if not ok then
        print("[ENTRY] Warning: could not move ticket to dump chest: " .. tostring(err))
    end

    monDraw("ok")
    openDoor()

    monDraw("idle")
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

            monDraw("idle")
            sleep(2)
            monDraw("idle")
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

local function listenForWhitelistChecks()
    while true do
        local senderId, msg = rednet.receive(config.PROTOCOL_WHITELIST_CHECK)
        if senderId == config.KASA_COMPUTER_ID and type(msg) == "string" then
            local trusted = wl.isWhitelisted(msg)
            print(string.format("[ENTRY] Whitelist check: nick=%s result=%s", msg, tostring(trusted)))
            rednet.send(senderId, trusted, config.PROTOCOL_WHITELIST_RESPONSE)
        end
    end
end

local function listenForCountRequests()
    while true do
        local senderId, msg = rednet.receive(config.PROTOCOL_COUNT_REQUEST)
        if senderId == config.KASA_COMPUTER_ID and msg == "count" then
            rednet.send(senderId, db.count(), config.PROTOCOL_COUNT_RESPONSE)
        end
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
print("[ENTRY] Computer ID: " .. os.getComputerID())
print("[ENTRY] Cashier ID in config: " .. config.KASA_COMPUTER_ID)
print("[ENTRY] Peripherals: " .. table.concat(peripheral.getNames(), ", "))
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        print("[ENTRY] Modem '" .. name .. "' isOpen=" .. tostring(rednet.isOpen(name)))
    end
end
print("[ENTRY] Tickets in database: " .. db.count())

monDraw("idle")

parallel.waitForAll(
    scanPedestal,
    listenForRegistrations,
    listenForPings,
    listenForCountRequests,
    listenForWhitelistChecks
)
