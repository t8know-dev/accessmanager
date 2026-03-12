-- =============================================================
--  config.lua  –  Wspólna konfiguracja systemu biletowego
--  Skopiuj ten plik na OBA komputery (kasa i wejście)
-- =============================================================

local config = {}

-- ── Sieć Rednet ──────────────────────────────────────────────
config.MODEM_SIDE        = "top"      -- strona modemu na obu komputerach
config.ENTRY_COMPUTER_ID = 2          -- ID komputera przy wejściu
config.KASA_COMPUTER_ID  = 1          -- ID komputera kasy

-- ── Protokoły komunikacji ─────────────────────────────────────
config.PROTOCOL_REGISTER  = "ticket_register"   -- kasa → wejście: zarejestruj bilet
config.PROTOCOL_ACK       = "ticket_ack"        -- wejście → kasa: potwierdzenie

-- ── Płatność ─────────────────────────────────────────────────
config.TICKET_PRICE_SPURS = 2         -- cena biletu w spurach

-- ── Brass Depositor + Redstone Relay ─────────────────────────
-- Relay podłączony do wejścia redstone Depositora.
-- Kasa wystawia HIGH → relay → Depositor zablokowany.
-- Kasa wystawia LOW  → relay → Depositor odblokowany (akceptuje monety).
config.DEPOSITOR_RELAY_SIDE  = "left"   -- strona wyjścia redstone kasy → relay → depositor
-- Wyjście redstone Depositora podłączone bezpośrednio do wejścia kasy.
-- Depositor wysyła puls HIGH po przyjęciu zapłaty.
config.DEPOSITOR_PULSE_SIDE  = "right"  -- strona wejścia redstone kasy ← depositor
config.PAYMENT_TIMEOUT       = 60       -- sekund na wrzucenie monet

-- ── Entity Detector ──────────────────────────────────────────
-- Ustaw stronę, jeśli detector jest podłączony po konkretnej stronie,
-- lub zostaw nil żeby użyć peripheral.find("entity_detector").
config.DETECTOR_SIDE         = nil      -- np. "back", lub nil

-- ── Bilet ────────────────────────────────────────────────────
config.TICKET_TITLE       = "Bilet Wstepu"
config.BASE_NAME          = "Moja Baza"

-- ── Drzwi ────────────────────────────────────────────────────
config.DOOR_OPEN_SECONDS  = 5         -- jak długo drzwi pozostają otwarte

-- ── Timeouty ─────────────────────────────────────────────────
config.REDNET_TIMEOUT     = 10        -- sekund na odpowiedź od wejścia
config.PEDESTAL_POLL_MS   = 0.5       -- co ile sekund sprawdzamy pedestal

return config
