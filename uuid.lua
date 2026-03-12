-- =============================================================
--  uuid.lua  –  Generator unikalnych identyfikatorów
--  Używany przez kasę do tworzenia ID biletu
-- =============================================================

local uuid = {}

-- Generuje unikalny klucz w formacie XXXX-XXXX-XXXX
-- Łączy os.time(), os.clock() i math.random dla unikalności
function uuid.generate()
    math.randomseed(os.time() + math.floor(os.clock() * 1000000))

    local function seg(len)
        local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- bez mylących znaków
        local s = ""
        for _ = 1, len do
            local idx = math.random(1, #chars)
            s = s .. chars:sub(idx, idx)
        end
        return s
    end

    return seg(4) .. "-" .. seg(4) .. "-" .. seg(4)
end

-- Sprawdza czy string wygląda jak poprawny UUID naszego formatu
function uuid.isValid(str)
    if type(str) ~= "string" then return false end
    return str:match("^%u%u%u%u%-%u%u%u%u%-%u%u%u%u$") ~= nil
        or str:match("^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") ~= nil
end

return uuid
