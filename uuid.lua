-- =============================================================
--  uuid.lua  -  Unique identifier generator
--  Used by the cashier to create ticket IDs
-- =============================================================

local uuid = {}

-- Generates a unique key in the format XXXX-XXXX-XXXX
-- Combines os.time(), os.clock() and math.random for uniqueness
function uuid.generate()
    math.randomseed(os.time() + math.floor(os.clock() * 1000000))

    local function seg(len)
        local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- no ambiguous characters
        local s = ""
        for _ = 1, len do
            local idx = math.random(1, #chars)
            s = s .. chars:sub(idx, idx)
        end
        return s
    end

    return seg(4) .. "-" .. seg(4) .. "-" .. seg(4)
end

-- Checks whether a string looks like a valid UUID in our format
function uuid.isValid(str)
    if type(str) ~= "string" then return false end
    return str:match("^%u%u%u%u%-%u%u%u%u%-%u%u%u%u$") ~= nil
        or str:match("^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") ~= nil
end

return uuid
