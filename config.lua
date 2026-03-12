-- config.lua - Shared configuration. Copy to BOTH computers.

local config = {}

config.KASA_COMPUTER_ID  = 391   -- cashier computer
config.ENTRY_COMPUTER_ID = 388   -- entry computer

config.PROTOCOL_REGISTER = "ticket_register"
config.PROTOCOL_ACK      = "ticket_ack"

config.KASA_MODEM_SIDE    = "right"
config.WEJSCIE_MODEM_SIDE = "right"

config.PRINTER_SIDE = "left"

-- Cashier network peripherals (wired to modem on right side of computer_391)
config.DEPOSITOR_NAME          = "Numismatics_Depositor_6"
config.RELAY_DEPOSIT_OUT_NAME  = "redstone_relay_30"
config.RELAY_DEPOSIT_OUT_SIDE  = "top"    -- INVERTED: no signal = paid
config.RELAY_DEPOSIT_LOCK_NAME = "redstone_relay_31"
config.RELAY_DEPOSIT_LOCK_SIDE = "left"

-- Entry network peripherals (wired to modem of computer_388)
config.PEDESTAL_NAME    = "item_pedestal_3"
config.RELAY_DOOR_NAME  = "redstone_relay_29"
config.RELAY_DOOR_SIDE1 = "top"
config.RELAY_DOOR_SIDE2 = "bottom"

-- Dump chest: set DUMP_CHEST_NAME for network, or DUMP_CHEST_SIDE for direct connection
config.DUMP_CHEST_NAME = nil
config.DUMP_CHEST_SIDE = "left"

config.TICKET_PRICE_SPURS = 2
config.PAYMENT_TIMEOUT    = 60   -- seconds

config.TICKET_TITLE = "Entry Ticket"
config.BASE_NAME    = "My Base"

config.DOOR_OPEN_SECONDS = 5
config.REDNET_TIMEOUT    = 10
config.PEDESTAL_POLL_MS  = 0.5

return config
