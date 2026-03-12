-- db.lua - File-based ticket store. Format per line: KEY|NICK|TIME

local db = {}

local DB_FILE = "/tickets.db"
local tickets = {}

function db.load()
    if not fs.exists(DB_FILE) then tickets = {}; return end

    local f = fs.open(DB_FILE, "r")
    if not f then tickets = {}; return end

    local content = f.readAll()
    f.close()

    tickets = {}
    if content and content ~= "" then
        for line in content:gmatch("[^\n]+") do
            local key, nick, time = line:match("^([^|]+)|([^|]+)|([^|]+)$")
            if key and nick then
                tickets[key] = { nick = nick, time = tonumber(time) or 0 }
            end
        end
    end
end

function db.save()
    -- Build full content in memory first, then write atomically
    local lines = {}
    for key, entry in pairs(tickets) do
        table.insert(lines, key .. "|" .. entry.nick .. "|" .. tostring(entry.time))
    end
    local content = table.concat(lines, "\n")
    if #lines > 0 then content = content .. "\n" end

    local f = fs.open(DB_FILE, "w")
    if not f then
        print("[DB] ERROR: Cannot open " .. DB_FILE .. " for writing!")
        return false
    end
    f.write(content)
    f.flush()
    f.close()
    print("[DB] Saved " .. #lines .. " ticket(s) to " .. DB_FILE
        .. " (" .. #content .. " bytes)")
    return true
end

function db.addTicket(key, nick, time)
    tickets[key] = { nick = nick, time = time or os.time() }
end

function db.getTicket(key)
    return tickets[key]
end

function db.removeTicket(key)
    tickets[key] = nil
end

function db.count()
    local n = 0
    for _ in pairs(tickets) do n = n + 1 end
    return n
end

function db.listAll()
    local list = {}
    for key, entry in pairs(tickets) do
        table.insert(list, { key = key, nick = entry.nick, time = entry.time })
    end
    return list
end

function db.clear()
    tickets = {}
end

return db
