-- =============================================================
--  db.lua  -  Ticket Database (for Entry computer)
--
--  Stores valid ticket keys in a file on disk.
--  Tickets are single-use - removed from the database after use.
-- =============================================================

local db = {}

local DB_FILE = "tickets.db"

-- Internal ticket table: { [key] = { nick, time } }
local tickets = {}

-- ── Load database from file ───────────────────────────────────
function db.load()
    if not fs.exists(DB_FILE) then
        tickets = {}
        return
    end

    local f = fs.open(DB_FILE, "r")
    if not f then
        tickets = {}
        return
    end

    local content = f.readAll()
    f.close()

    if content and content ~= "" then
        -- Simple format: one line = one ticket
        -- FORMAT: KEY|NICK|TIME
        tickets = {}
        for line in content:gmatch("[^\n]+") do
            local key, nick, time = line:match("^([^|]+)|([^|]+)|([^|]+)$")
            if key and nick then
                tickets[key] = {
                    nick = nick,
                    time = tonumber(time) or 0,
                }
            end
        end
    else
        tickets = {}
    end
end

-- ── Save database to file ─────────────────────────────────────
function db.save()
    local f = fs.open(DB_FILE, "w")
    if not f then
        printError("[DB] Cannot save database!")
        return false
    end

    for key, entry in pairs(tickets) do
        f.writeLine(key .. "|" .. entry.nick .. "|" .. tostring(entry.time))
    end

    f.close()
    return true
end

-- ── Add ticket ────────────────────────────────────────────────
function db.addTicket(key, nick, time)
    tickets[key] = {
        nick = nick,
        time = time or os.time(),
    }
end

-- ── Get ticket (or nil if not found) ─────────────────────────
function db.getTicket(key)
    return tickets[key]
end

-- ── Remove ticket (after use) ─────────────────────────────────
function db.removeTicket(key)
    tickets[key] = nil
end

-- ── Count tickets in database ─────────────────────────────────
function db.count()
    local n = 0
    for _ in pairs(tickets) do n = n + 1 end
    return n
end

-- ── List all tickets (for debugging) ─────────────────────────
function db.listAll()
    local list = {}
    for key, entry in pairs(tickets) do
        table.insert(list, {
            key  = key,
            nick = entry.nick,
            time = entry.time,
        })
    end
    return list
end

-- ── Clear all tickets ─────────────────────────────────────────
function db.clear()
    tickets = {}
end

return db
