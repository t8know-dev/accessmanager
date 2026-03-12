-- =============================================================
--  db.lua  –  Baza Danych Biletów (dla komputera Wejście)
--
--  Przechowuje ważne klucze biletów w pliku JSON na dysku.
--  Bilet jest jednorazowy – po użyciu jest usuwany z bazy.
-- =============================================================

local db = {}

local DB_FILE = "tickets.db"

-- Wewnętrzna tablica biletów: { [key] = { nick, time } }
local tickets = {}

-- ── Wczytaj bazę z pliku ──────────────────────────────────────
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
        -- Prosty format: jedna linia = jeden bilet
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

-- ── Zapisz bazę do pliku ──────────────────────────────────────
function db.save()
    local f = fs.open(DB_FILE, "w")
    if not f then
        printError("[DB] Nie mozna zapisac bazy danych!")
        return false
    end

    for key, entry in pairs(tickets) do
        f.writeLine(key .. "|" .. entry.nick .. "|" .. tostring(entry.time))
    end

    f.close()
    return true
end

-- ── Dodaj bilet ───────────────────────────────────────────────
function db.addTicket(key, nick, time)
    tickets[key] = {
        nick = nick,
        time = time or os.time(),
    }
end

-- ── Pobierz bilet (lub nil jeśli nie istnieje) ────────────────
function db.getTicket(key)
    return tickets[key]
end

-- ── Usuń bilet (po użyciu) ────────────────────────────────────
function db.removeTicket(key)
    tickets[key] = nil
end

-- ── Ile biletów w bazie ───────────────────────────────────────
function db.count()
    local n = 0
    for _ in pairs(tickets) do n = n + 1 end
    return n
end

-- ── Lista wszystkich biletów (do debugowania) ─────────────────
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

-- ── Wyczyść wszystkie bilety ──────────────────────────────────
function db.clear()
    tickets = {}
end

return db
