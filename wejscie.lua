-- =============================================================
--  wejscie.lua  –  Komputer przy Wejściu  (computer_388)
--
--  Peryferia:
--    • Modem (wired)        – strona config.WEJSCIE_MODEM_SIDE
--      └─ Item Pedestal     – config.PEDESTAL_NAME
--      └─ Redstone Relay    – config.RELAY_DOOR_NAME (otwieranie bramy)
--    • Skrzynia dump        – config.DUMP_CHEST_NAME (sieć) lub DUMP_CHEST_SIDE (bezpośrednio)
--    • Monitor (opcjonalny) – wykrywany przez peripheral.find
--
--  Zależności (umieść w tym samym folderze lub /):
--    • config.lua
--    • uuid.lua
--    • db.lua
-- =============================================================

local config = require("config")
local uuid   = require("uuid")
local db     = require("db")

-- ──────────────────────────────────────────────────────────────
--  INICJALIZACJA PERYFERIÓW
-- ──────────────────────────────────────────────────────────────
local pedestal = peripheral.wrap(config.PEDESTAL_NAME)
    or error("Item Pedestal nie znaleziony: " .. config.PEDESTAL_NAME, 0)

local dumpChest
if config.DUMP_CHEST_NAME then
    dumpChest = peripheral.wrap(config.DUMP_CHEST_NAME)
        or error("Skrzynia dump nie znaleziona: " .. config.DUMP_CHEST_NAME, 0)
else
    dumpChest = peripheral.wrap(config.DUMP_CHEST_SIDE)
        or error("Skrzynia dump nie znaleziona na stronie: " .. config.DUMP_CHEST_SIDE, 0)
end

-- Relay otwierania bramy (wejście ustawia OUTPUT)
local relayDoor = peripheral.wrap(config.RELAY_DOOR_NAME)
    or error("Relay (door) nie znaleziony: " .. config.RELAY_DOOR_NAME, 0)

local monitor = peripheral.find("monitor")
if monitor then
    monitor.setTextScale(1)
end

rednet.open(config.WEJSCIE_MODEM_SIDE)

-- ──────────────────────────────────────────────────────────────
--  BAZA DANYCH (plik lokalny)
-- ──────────────────────────────────────────────────────────────
db.load()

-- ──────────────────────────────────────────────────────────────
--  WYŚWIETLACZ MONITORA
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

    -- Nagłówek
    monitor.setBackgroundColor(colors.blue)
    for y = 1, 2 do
        monitor.setCursorPos(1, y)
        monitor.write(string.rep(" ", mw))
    end
    mCenter(1, config.BASE_NAME, colors.white, colors.blue)
    mCenter(2, "WEJSCIE", colors.yellow, colors.blue)

    monitor.setBackgroundColor(colors.black)

    -- Główna wiadomość
    mCenter(math.floor(mh / 2),     line1 or "", col or colors.white)
    mCenter(math.floor(mh / 2) + 1, line2 or "", colors.lightGray)

    -- Instrukcja na dole
    mCenter(mh - 1, "Poloz bilet na pedestalu", colors.gray)
    mCenter(mh,     "aby otworzyc wejscie",     colors.gray)
end

-- ──────────────────────────────────────────────────────────────
--  STEROWANIE DRZWIAMI
-- ──────────────────────────────────────────────────────────────
local function openDoor()
    relayDoor.setOutput(config.RELAY_DOOR_SIDE1, true)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE2, true)
    sleep(config.DOOR_OPEN_SECONDS)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE1, false)
    relayDoor.setOutput(config.RELAY_DOOR_SIDE2, false)
end

-- ──────────────────────────────────────────────────────────────
--  PARSOWANIE NBT BILETU
-- ──────────────────────────────────────────────────────────────
-- Printed Page w CC przechowuje tekst w NBT jako:
--   pages = [ "linia1\nlinia2\n..." ]
-- Szukamy linii z kluczem (format XXXX-XXXX-XXXX)
local function extractKeyFromNBT(rawNBT)
    if type(rawNBT) ~= "table" then return nil end

    -- rawNBT może być zagnieżdżoną tabelą
    local function searchTable(t, depth)
        if depth > 5 then return nil end
        for k, v in pairs(t) do
            if type(v) == "string" then
                -- Szukaj wzorca UUID w każdym stringu
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
--  NISZCZENIE BILETU (przeniesienie do dump chest)
-- ──────────────────────────────────────────────────────────────
local function destroyTicket()
    -- Pedestal ma inventory API – slot 1 to wystawiony przedmiot
    local pedestalName = peripheral.getName(pedestal)
    local dumpName     = peripheral.getName(dumpChest)

    -- Przesuń ze slot 1 pedestalu do skrzyni dump
    local moved = pedestal.pushItems(dumpName, 1)
    return moved > 0
end

-- ──────────────────────────────────────────────────────────────
--  WERYFIKACJA BILETU
-- ──────────────────────────────────────────────────────────────
local function verifyAndProcess()
    -- Sprawdź czy coś jest na pedestalu
    local item = pedestal.getItemDetail(1)
    if not item then return end

    -- Sprawdź typ przedmiotu (Printed Page z CC:Tweaked)
    if not item.name:find("printed") and not item.name:find("computercraft") then
        monDraw("! ZLY PRZEDMIOT !", "To nie jest bilet", colors.red)
        sleep(2)
        monDraw("Oczekiwanie...", "Poloz bilet na pedestalu")
        return
    end

    monDraw("Weryfikacja...", "", colors.yellow)

    -- Wyciągnij klucz z NBT
    local key = nil
    if item.rawNBT then
        key = extractKeyFromNBT(item.rawNBT)
    end

    -- Fallback: spróbuj z displayName lub tag
    if not key and item.displayName then
        key = item.displayName:match("([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])")
    end

    if not key then
        monDraw("! NIEPRAWIDLOWY !", "Brak klucza w bilecie", colors.red)
        sleep(3)
        monDraw("Oczekiwanie...", "Poloz bilet na pedestalu")
        return
    end

    -- Sprawdź w bazie danych
    local entry = db.getTicket(key)

    if not entry then
        monDraw("! ODRZUCONY !", "Klucz: " .. key, colors.red)
        sleep(3)
        monDraw("Oczekiwanie...", "Poloz bilet na pedestalu")
        return
    end

    -- Bilet ważny – usuń z bazy (jednorazowy!)
    db.removeTicket(key)
    db.save()

    -- Usuń fizyczny bilet z pedestalu
    local destroyed = destroyTicket()

    -- Otwórz drzwi
    monDraw("WEJSCIE OTWARTE", "Witaj, " .. entry.nick .. "!", colors.lime)

    -- Otwórz drzwi (blokuje przez DOOR_OPEN_SECONDS)
    openDoor()

    monDraw("Oczekiwanie...", "Poloz bilet na pedestalu")
end

-- ──────────────────────────────────────────────────────────────
--  NASŁUCHIWANIE NA REJESTRACJĘ BILETÓW (z kasy)
-- ──────────────────────────────────────────────────────────────
local function listenForRegistrations()
    while true do
        local senderId, msg, protocol = rednet.receive(config.PROTOCOL_REGISTER, 1)

        if senderId == config.KASA_COMPUTER_ID
            and protocol == config.PROTOCOL_REGISTER
            and type(msg) == "table"
            and msg.key and msg.nick
        then
            -- Zarejestruj bilet w bazie
            db.addTicket(msg.key, msg.nick, msg.time)
            db.save()

            -- Wyślij ACK
            rednet.send(senderId, "ok", config.PROTOCOL_ACK)

            -- Pokaż na monitorze chwilowo
            monDraw("Nowy bilet!", "Dla: " .. msg.nick, colors.cyan)
            sleep(2)
            monDraw("Oczekiwanie...", "Poloz bilet na pedestalu")
        end
    end
end

-- ──────────────────────────────────────────────────────────────
--  PĘTLA SKANOWANIA PEDESTALU
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
print("[WEJSCIE] System uruchomiony")
print("[WEJSCIE] Biletow w bazie: " .. db.count())
print("[WEJSCIE] Czekam na bilety i rejestracje...")

monDraw("Oczekiwanie...", "Poloz bilet na pedestalu")

-- Uruchom obie pętle równolegle
parallel.waitForAll(
    scanPedestal,
    listenForRegistrations
)
