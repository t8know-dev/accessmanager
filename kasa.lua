-- =============================================================
--  kasa.lua  –  Komputer Kasy  (Komputer #1)
--
--  Peryferia (podłącz do tego komputera):
--    • Brass Depositor       – dowolna strona
--    • CC Printer            – dowolna strona
--    • Modem (wired/wireless)– strona z config.MODEM_SIDE
--    • Entity Detector       – strona z config.DETECTOR_SIDE (lub auto)
--    • Redstone Relay        – strona config.DEPOSITOR_RELAY_SIDE (wyjście → depositor)
--    • Kabel redstone        – strona config.DEPOSITOR_PULSE_SIDE (wejście ← depositor)
--
--  Zależności (umieść w tym samym folderze lub /):
--    • basalt.lua
--    • config.lua
--    • uuid.lua
-- =============================================================

local basalt = require("basalt")
local config = require("config")
local uuid   = require("uuid")

-- ──────────────────────────────────────────────────────────────
--  INICJALIZACJA PERYFERIÓW
-- ──────────────────────────────────────────────────────────────
local depositor = peripheral.find("brass_depositor")
    or error("Brass Depositor nie znaleziony!", 0)

local printer = peripheral.find("printer")
    or error("Printer nie znaleziony!", 0)

local modem = peripheral.wrap(config.MODEM_SIDE)
    or error("Modem nie znaleziony na stronie: " .. config.MODEM_SIDE, 0)

local detector
if config.DETECTOR_SIDE then
    detector = peripheral.wrap(config.DETECTOR_SIDE)
else
    detector = peripheral.find("entity_detector")
end
if not detector then
    error("Entity Detector nie znaleziony! Sprawdz polaczenia.", 0)
end

rednet.open(config.MODEM_SIDE)

-- Ustaw cenę na Depositorze
depositor.setTotalPrice(config.TICKET_PRICE_SPURS)

-- Zablokuj depositor domyślnie (relay ON → sygnał redstone → depositor zablokowany)
rs.setOutput(config.DEPOSITOR_RELAY_SIDE, true)

-- ──────────────────────────────────────────────────────────────
--  STAN APLIKACJI
-- ──────────────────────────────────────────────────────────────
local state = {
    status        = "idle",
    lastTicketKey = nil,
    lastNick      = nil,
    soldCount     = 0,
    logLines      = {},
    detectedNick  = nil,   -- nick wykryty przez entity detector
    purchasing    = false,
}

local cancelRequested = false

-- ──────────────────────────────────────────────────────────────
--  UI – BASALT
-- ──────────────────────────────────────────────────────────────
local main = basalt.getMainFrame()
main:setBackground(colors.black)

local W, H = term.getSize()

-- ── Nagłówek ─────────────────────────────────────────────────
main:addLabel()
    :setText(" " .. config.BASE_NAME .. " – KASA BILETOWA ")
    :setPosition(1, 1)
    :setSize(W, 1)
    :setBackground(colors.blue)
    :setForeground(colors.white)

-- ── Info cennik ──────────────────────────────────────────────
main:addLabel()
    :setText("Bilet jednorazowy: " .. config.TICKET_PRICE_SPURS .. " spur")
    :setPosition(2, 3)
    :setForeground(colors.yellow)

-- ── Status box ───────────────────────────────────────────────
local statusBox = main:addLabel()
    :setText("[ Oczekiwanie ]")
    :setPosition(2, 5)
    :setSize(W - 2, 1)
    :setForeground(colors.lime)

-- ── Wykryty gracz ────────────────────────────────────────────
main:addLabel()
    :setText("Wykryty gracz:")
    :setPosition(2, 7)
    :setForeground(colors.gray)

local detectedLabel = main:addLabel()
    :setText("(brak gracza w poblizu)")
    :setPosition(2, 8)
    :setSize(W - 2, 1)
    :setForeground(colors.orange)

-- ── Ostatni bilet ────────────────────────────────────────────
main:addLabel()
    :setText("Ostatni bilet:")
    :setPosition(2, 10)
    :setForeground(colors.gray)

local lastKeyLabel = main:addLabel()
    :setText("—")
    :setPosition(2, 11)
    :setSize(W - 2, 1)
    :setForeground(colors.cyan)

local lastNickLabel = main:addLabel()
    :setText("")
    :setPosition(2, 12)
    :setSize(W - 2, 1)
    :setForeground(colors.lightGray)

-- ── Log ──────────────────────────────────────────────────────
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

-- ── Licznik ──────────────────────────────────────────────────
local counterLabel = main:addLabel()
    :setText("Sprzedano: 0")
    :setPosition(2, H)
    :setForeground(colors.gray)

-- ── Przycisk KUP ─────────────────────────────────────────────
local buyBtn = main:addButton()
    :setText(" KUP BILET ")
    :setPosition(2, H - 3)
    :setSize(16, 3)
    :setBackground(colors.green)
    :setForeground(colors.white)

-- ── Przycisk PRZERWIJ (domyślnie ukryty) ─────────────────────
local cancelBtn = main:addButton()
    :setText(" PRZERWIJ ")
    :setPosition(W - 16, H - 3)
    :setSize(16, 3)
    :setBackground(colors.red)
    :setForeground(colors.white)
cancelBtn:hide()

-- ──────────────────────────────────────────────────────────────
--  POMOCNICZE FUNKCJE UI
-- ──────────────────────────────────────────────────────────────
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
    rs.setOutput(config.DEPOSITOR_RELAY_SIDE, false)
end

local function lockDepositor()
    rs.setOutput(config.DEPOSITOR_RELAY_SIDE, true)
end

-- ──────────────────────────────────────────────────────────────
--  ENTITY DETECTOR – wykryj najbliższego gracza
-- ──────────────────────────────────────────────────────────────
local function detectNearestPlayer()
    local ok, entities = pcall(function() return detector.getEntities() end)
    if not ok or type(entities) ~= "table" then return nil end

    local nearest, nearestDist = nil, math.huge
    for _, e in ipairs(entities) do
        if e.isPlayer then
            local dist = math.sqrt((e.x or 0)^2 + (e.y or 0)^2 + (e.z or 0)^2)
            if dist < nearestDist then
                nearestDist = dist
                nearest = e.name or "Nieznany"
            end
        end
    end
    return nearest
end

-- ──────────────────────────────────────────────────────────────
--  LOGIKA DRUKOWANIA BILETU
-- ──────────────────────────────────────────────────────────────
local function printTicket(key, nick)
    if printer.getPaperLevel() < 1 then
        return false, "Brak papieru w printerze!"
    end
    if printer.getInkLevel() < 1 then
        return false, "Brak tuszu w printerze!"
    end
    if not printer.newPage() then
        return false, "Nie mozna rozpoczac druku!"
    end

    local pw = printer.getPageSize()

    printer.setPageTitle(config.TICKET_TITLE)
    printer.setCursorPos(1, 1); printer.write(config.BASE_NAME)
    printer.setCursorPos(1, 2); printer.write(string.rep("=", pw))
    printer.setCursorPos(1, 3); printer.write("Gracz: " .. nick)
    printer.setCursorPos(1, 4); printer.write("Klucz:")
    printer.setCursorPos(1, 5); printer.write("  " .. key)

    local t = os.date("*t")
    local dateStr = string.format("%02d/%02d/%04d %02d:%02d",
        t.mday, t.month, t.year, t.hour, t.min)
    printer.setCursorPos(1, 6); printer.write("Data: " .. dateStr)
    printer.setCursorPos(1, 7); printer.write(string.rep("-", pw))
    printer.setCursorPos(1, 8); printer.write("Poloz na pedestalu")
    printer.setCursorPos(1, 9); printer.write("przy wejsciu do bazy")
    printer.setCursorPos(1, 11); printer.write("! BILET JEDNORAZOWY !")

    if not printer.endPage() then
        return false, "Nie mozna zakonczyc druku!"
    end
    return true, nil
end

-- ──────────────────────────────────────────────────────────────
--  LOGIKA REJESTRACJI W KOMPUTERZE WEJŚCIA
-- ──────────────────────────────────────────────────────────────
local function registerTicketAtEntry(key, nick)
    local payload = { key = key, nick = nick, time = os.time() }
    rednet.send(config.ENTRY_COMPUTER_ID, payload, config.PROTOCOL_REGISTER)
    local senderId, msg = rednet.receive(config.PROTOCOL_ACK, config.REDNET_TIMEOUT)
    if senderId == config.ENTRY_COMPUTER_ID and msg == "ok" then
        return true
    end
    return false
end

-- ──────────────────────────────────────────────────────────────
--  GŁÓWNA LOGIKA ZAKUPU
-- ──────────────────────────────────────────────────────────────
local function handlePurchase(nick)
    state.status = "waiting_payment"
    cancelRequested = false
    setBuyBtnEnabled(false)
    cancelBtn:show()

    -- Odblokuj depositor: relay OFF → brak sygnału redstone → depositor aktywny
    unlockDepositor()
    setStatus("Wloz " .. config.TICKET_PRICE_SPURS .. " spur do Depositora...", colors.yellow)
    addLog("Oczekiwanie na platnosc: " .. nick)

    -- Czekaj na puls redstone od Depositora (potwierdzenie płatności)
    -- lub na anulowanie, lub na timeout
    local paid = false
    local deadline = os.clock() + config.PAYMENT_TIMEOUT

    while os.clock() < deadline and not cancelRequested do
        if rs.getInput(config.DEPOSITOR_PULSE_SIDE) then
            paid = true
            break
        end
        os.sleep(0.05)
    end

    -- Zablokuj depositor z powrotem niezależnie od wyniku
    lockDepositor()
    cancelBtn:hide()

    if cancelRequested then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Zamowienie przerwane", colors.orange)
        addLog("Zamowienie przerwane")
        return
    end

    if not paid then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Timeout platnosci – sprobuj ponownie", colors.red)
        addLog("BLAD: brak platnosci w " .. config.PAYMENT_TIMEOUT .. "s")
        return
    end

    addLog("Platnosc potwierdzona!")

    -- Drukuj bilet
    state.status = "printing"
    setStatus("Drukowanie biletu...", colors.yellow)

    local key = uuid.generate()
    local printOk, printErr = printTicket(key, nick)
    if not printOk then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("Blad druku: " .. printErr, colors.red)
        addLog("BLAD druku: " .. printErr)
        return
    end

    addLog("Wydrukowano bilet dla: " .. nick)

    -- Wyślij do komputera wejścia
    state.status = "sending"
    setStatus("Rejestracja biletu...", colors.yellow)

    local regOk = registerTicketAtEntry(key, nick)
    if not regOk then
        state.status = "idle"
        setBuyBtnEnabled(true)
        setStatus("BLAD: brak polaczenia z wejsciem!", colors.red)
        addLog("BLAD: wejscie nie odpowiedzialo")
        addLog("Bilet wydrukowany ale NIE zarejestrowany!")
        return
    end

    -- Sukces
    state.soldCount     = state.soldCount + 1
    state.lastTicketKey = key
    state.lastNick      = nick
    state.status        = "idle"

    lastKeyLabel:setText(key)
    lastNickLabel:setText("Gracz: " .. nick)
    counterLabel:setText("Sprzedano: " .. state.soldCount)
    setBuyBtnEnabled(true)
    setStatus("Bilet sprzedany! Odbierz z printera.", colors.lime)
    addLog("OK: " .. key .. " dla " .. nick)
end

-- ──────────────────────────────────────────────────────────────
--  PODPIĘCIE PRZYCISKÓW
-- ──────────────────────────────────────────────────────────────
buyBtn:onClick(function()
    if state.status ~= "idle" then return end

    local nick = state.detectedNick
    if not nick then
        setStatus("Brak gracza w poblizu!", colors.red)
        addLog("Blad: nie wykryto gracza")
        return
    end

    basalt.schedule(function() handlePurchase(nick) end)
end)

cancelBtn:onClick(function()
    cancelRequested = true
end)

-- ──────────────────────────────────────────────────────────────
--  PETLA WYKRYWANIA GRACZA (tło)
-- ──────────────────────────────────────────────────────────────
basalt.schedule(function()
    while true do
        local nick = detectNearestPlayer()
        state.detectedNick = nick
        if nick then
            detectedLabel:setText(nick)
            detectedLabel:setForeground(colors.lime)
        else
            detectedLabel:setText("(brak gracza w poblizu)")
            detectedLabel:setForeground(colors.orange)
        end
        os.sleep(1)
    end
end)

-- ──────────────────────────────────────────────────────────────
--  START
-- ──────────────────────────────────────────────────────────────
setStatus("Gotowy do sprzedazy", colors.lime)
addLog("System kasy uruchomiony")
addLog("Cena: " .. config.TICKET_PRICE_SPURS .. " spur")

basalt.run()
