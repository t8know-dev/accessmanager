-- config.lua - Shared configuration. Copy to BOTH computers.

local config = {}

config.KASA_COMPUTER_ID  = 796   -- cashier computer
config.ENTRY_COMPUTER_ID = 797   -- entry computer

config.PROTOCOL_REGISTER = "ticket_register"
config.PROTOCOL_ACK      = "ticket_ack"
config.PROTOCOL_PING     = "ticket_ping"
config.PROTOCOL_PONG     = "ticket_pong"

config.KASA_MODEM_SIDE    = "right"
config.WEJSCIE_MODEM_SIDE = "left"

config.PRINTER_NAME = "printer_6"

-- Cashier network peripherals (wired to modem on right side of computer_391)
config.DEPOSITOR_NAME          = "Numismatics_Depositor_7"
config.MONITOR_NAME            = "monitor_933"
config.RELAY_DEPOSIT_OUT_NAME  = "redstone_relay_32"
config.RELAY_DEPOSIT_OUT_SIDE  = "top"    -- INVERTED: no signal = paid
config.RELAY_DEPOSIT_LOCK_NAME = "redstone_relay_33"
config.RELAY_DEPOSIT_LOCK_SIDE = "top"

-- Entry network peripherals (wired to modem of computer_388)
config.PEDESTAL_NAME    = "item_pedestal_5"
config.ENTRY_MONITOR_NAME = "monitor_930"
config.RELAY_DOOR_NAME  = "redstone_relay_34"
config.RELAY_DOOR_SIDE1 = "left"
config.RELAY_DOOR_SIDE2 = "right"

-- Dump chest: set DUMP_CHEST_NAME for network, or DUMP_CHEST_SIDE for direct connection
config.ENTITY_DETECTOR_NAME = "entity_detector_10"
config.DUMP_CHEST_NAME = 'minecraft:chest_39'
config.DUMP_CHEST_SIDE = nil

config.TICKET_PRICE_SPURS = 2
config.PAYMENT_TIMEOUT    = 60   -- seconds

config.TICKET_TITLE = "Thajiggaman's base ticket"
config.BASE_NAME    = "Thajiggman's base"

config.PROTOCOL_COUNT_REQUEST  = "ticket_count_req"
config.PROTOCOL_COUNT_RESPONSE = "ticket_count_resp"

config.PROTOCOL_WHITELIST_CHECK    = "ticket_wl_check"
config.PROTOCOL_WHITELIST_RESPONSE = "ticket_wl_resp"

config.DOOR_OPEN_SECONDS             = 5
config.REDNET_TIMEOUT                = 10
config.PEDESTAL_POLL_MS              = 0.5
config.POST_PURCHASE_DISPLAY_SECONDS = 5

return config
