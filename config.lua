-- =============================================================
--  config.lua  –  Wspólna konfiguracja systemu biletowego
--  Skopiuj ten plik na OBA komputery (kasa i wejście)
-- =============================================================

local config = {}

-- ── IDs komputerów ────────────────────────────────────────────
config.KASA_COMPUTER_ID  = 391   -- computer_391 (kasa)
config.ENTRY_COMPUTER_ID = 388   -- computer_388 (wejście)

-- ── Protokoły komunikacji ─────────────────────────────────────
config.PROTOCOL_REGISTER = "ticket_register"   -- kasa → wejście: zarejestruj bilet
config.PROTOCOL_ACK      = "ticket_ack"        -- wejście → kasa: potwierdzenie

-- ── Strony modemów (do rednet.open) ───────────────────────────
config.KASA_MODEM_SIDE    = "right"   -- modem kasy (prawa strona komputera)
config.WEJSCIE_MODEM_SIDE = "right"   -- modem wejścia (dostosuj do swojego setupu)

-- ── Peryferia bezpośrednie – KASA ─────────────────────────────
config.PRINTER_SIDE = "left"    -- drukarka podłączona bezpośrednio z lewej strony kasy
-- Monitor kasy: wykrywany automatycznie przez peripheral.find("monitor") – góra (top)

-- ── Nazwy peryferiów sieciowych – KASA ───────────────────────
-- Podłączone kablem do modemu po prawej stronie kasy (computer_391)
config.DEPOSITOR_NAME          = "Numismatics_Depositor_6"  -- wpłatomat monet
config.RELAY_DEPOSIT_OUT_NAME  = "redstone_relay_30"        -- sygnał zapłaty od depositora
config.RELAY_DEPOSIT_OUT_SIDE  = "top"                      -- strona wejścia relay_30 (sygnał INVERTED: brak sygnału = zapłacono)
config.RELAY_DEPOSIT_LOCK_NAME = "redstone_relay_31"        -- blokowanie depositora
config.RELAY_DEPOSIT_LOCK_SIDE = "left"                     -- strona wyjścia relay_31 → do depositora

-- ── Nazwy peryferiów sieciowych – WEJŚCIE ────────────────────
-- Podłączone kablem do modemu komputera wejścia (computer_388)
config.PEDESTAL_NAME    = "item_pedestal_3"    -- pedestal na bilet przy wejściu
config.RELAY_DOOR_NAME  = "redstone_relay_29"  -- otwieranie bramy
config.RELAY_DOOR_SIDE1 = "top"                -- pierwsza strona wyjścia relay_29
config.RELAY_DOOR_SIDE2 = "bottom"             -- druga strona wyjścia relay_29

-- ── Skrzynia na zużyte bilety (wejście) ──────────────────────
-- Jeśli skrzynia jest w sieci kablowej – podaj jej nazwę sieciową, np. "minecraft:chest_5"
-- Jeśli podłączona bezpośrednio do komputera wejścia – zostaw nil i ustaw DUMP_CHEST_SIDE
config.DUMP_CHEST_NAME = nil      -- nazwa sieciowa skrzyni (lub nil)
config.DUMP_CHEST_SIDE = "left"   -- strona bezpośrednia (używana gdy DUMP_CHEST_NAME == nil)

-- ── Płatność ─────────────────────────────────────────────────
config.TICKET_PRICE_SPURS = 2     -- cena biletu w spurach
config.PAYMENT_TIMEOUT    = 60    -- sekund na wrzucenie monet

-- ── Bilet ────────────────────────────────────────────────────
config.TICKET_TITLE = "Bilet Wstepu"
config.BASE_NAME    = "Moja Baza"

-- ── Drzwi ────────────────────────────────────────────────────
config.DOOR_OPEN_SECONDS = 5      -- jak długo brama pozostaje otwarta

-- ── Timeouty ─────────────────────────────────────────────────
config.REDNET_TIMEOUT   = 10      -- sekund na odpowiedź od wejścia
config.PEDESTAL_POLL_MS = 0.5     -- co ile sekund sprawdzamy pedestal

return config
