-- =============================================================
--  config.lua  -  Shared configuration for the ticket system
--  Copy this file to BOTH computers (cashier and entry)
-- =============================================================

local config = {}

-- ── Computer IDs ──────────────────────────────────────────────
config.KASA_COMPUTER_ID  = 391   -- computer_391 (cashier)
config.ENTRY_COMPUTER_ID = 388   -- computer_388 (entry)

-- ── Communication protocols ───────────────────────────────────
config.PROTOCOL_REGISTER = "ticket_register"   -- cashier -> entry: register ticket
config.PROTOCOL_ACK      = "ticket_ack"        -- entry -> cashier: acknowledgement

-- ── Modem sides (for rednet.open) ─────────────────────────────
config.KASA_MODEM_SIDE    = "right"   -- cashier modem (right side of computer)
config.WEJSCIE_MODEM_SIDE = "right"   -- entry modem (adjust to your setup)

-- ── Direct peripherals - CASHIER ──────────────────────────────
config.PRINTER_SIDE = "left"    -- printer connected directly on the left side of cashier
-- Cashier monitor: detected automatically via peripheral.find("monitor") - top

-- ── Network peripheral names - CASHIER ───────────────────────
-- Connected by cable to the modem on the right side of cashier (computer_391)
config.DEPOSITOR_NAME          = "Numismatics_Depositor_6"  -- coin depositor
config.RELAY_DEPOSIT_OUT_NAME  = "redstone_relay_30"        -- payment signal from depositor
config.RELAY_DEPOSIT_OUT_SIDE  = "top"                      -- input side of relay_30 (INVERTED signal: no signal = paid)
config.RELAY_DEPOSIT_LOCK_NAME = "redstone_relay_31"        -- depositor lock relay
config.RELAY_DEPOSIT_LOCK_SIDE = "left"                     -- output side of relay_31 -> to depositor

-- ── Network peripheral names - ENTRY ─────────────────────────
-- Connected by cable to the modem of entry computer (computer_388)
config.PEDESTAL_NAME    = "item_pedestal_3"    -- ticket pedestal at entry
config.RELAY_DOOR_NAME  = "redstone_relay_29"  -- door opening relay
config.RELAY_DOOR_SIDE1 = "top"                -- first output side of relay_29
config.RELAY_DOOR_SIDE2 = "bottom"             -- second output side of relay_29

-- ── Dump chest for used tickets (entry) ──────────────────────
-- If the chest is on the cable network - provide its network name, e.g. "minecraft:chest_5"
-- If connected directly to the entry computer - leave nil and set DUMP_CHEST_SIDE
config.DUMP_CHEST_NAME = nil      -- network name of chest (or nil)
config.DUMP_CHEST_SIDE = "left"   -- direct side (used when DUMP_CHEST_NAME == nil)

-- ── Payment ───────────────────────────────────────────────────
config.TICKET_PRICE_SPURS = 2     -- ticket price in spurs
config.PAYMENT_TIMEOUT    = 60    -- seconds to insert coins

-- ── Ticket ────────────────────────────────────────────────────
config.TICKET_TITLE = "Entry Ticket"
config.BASE_NAME    = "My Base"

-- ── Door ──────────────────────────────────────────────────────
config.DOOR_OPEN_SECONDS = 5      -- how long the door stays open

-- ── Timeouts ──────────────────────────────────────────────────
config.REDNET_TIMEOUT   = 10      -- seconds to wait for entry response
config.PEDESTAL_POLL_MS = 0.5     -- how often to check the pedestal (seconds)

return config
