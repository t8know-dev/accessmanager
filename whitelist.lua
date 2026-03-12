-- whitelist.lua - Trusted player list. One nickname per line in /whitelist.txt
-- Lines starting with # are comments. Names are case-insensitive.

local wl = {}

local WL_FILE = "/whitelist.txt"
local names = {}

function wl.load()
    names = {}
    if not fs.exists(WL_FILE) then
        print("[WHITELIST] " .. WL_FILE .. " not found, whitelist is empty")
        return
    end
    local f = fs.open(WL_FILE, "r")
    if not f then return end
    local content = f.readAll()
    f.close()
    local count = 0
    for line in content:gmatch("[^\n]+") do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" and not name:match("^#") then
            names[name:lower()] = true
            count = count + 1
        end
    end
    print("[WHITELIST] Loaded " .. count .. " trusted player(s)")
end

function wl.isWhitelisted(nick)
    if type(nick) ~= "string" then return false end
    return names[nick:lower()] == true
end

return wl
