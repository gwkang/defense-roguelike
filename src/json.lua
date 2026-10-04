local json = {}
local NULL_MT = { __jsonNull = true, __tostring = function() return "null" end }
json.null = setmetatable({}, NULL_MT)
local ARRAY_MT = { __jsonShape = "array" }
local OBJECT_MT = { __jsonShape = "object" }

function json.array(value)
    return setmetatable(value or {}, ARRAY_MT)
end

function json.object(value)
    return setmetatable(value or {}, OBJECT_MT)
end

local ESCAPES = {
    ['"'] = '\\"',
    ['\\'] = '\\\\',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

local function escapeString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        return ESCAPES[char] or string.format("\\u%04x", char:byte())
    end) .. '"'
end

local function tableShape(value)
    local taggedShape = getmetatable(value) and getmetatable(value).__jsonShape
    if taggedShape == "array" then
        local maximum = 0
        for key in pairs(value) do
            if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
                error("tagged JSON arrays require positive integer keys", 3)
            end
            if key > maximum then maximum = key end
        end
        for index = 1, maximum do
            if value[index] == nil then error("JSON arrays cannot contain holes", 3) end
        end
        return "array", maximum
    elseif taggedShape == "object" then
        return "object"
    end
    local count = 0
    local maximum = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return "object"
        end
        count = count + 1
        if key > maximum then maximum = key end
    end
    if count == maximum then return "array", maximum end
    if count == 0 then return "object", 0 end
    error("JSON arrays cannot contain holes", 3)
end

local function encodeValue(value, stack)
    local valueType = type(value)
    if valueType == "nil" or value == json.null
        or (valueType == "table" and getmetatable(value) and getmetatable(value).__jsonNull) then
        return "null"
    end
    if valueType == "boolean" then return value and "true" or "false" end
    if valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("JSON cannot encode non-finite numbers", 3)
        end
        return string.format("%.17g", value)
    end
    if valueType == "string" then return escapeString(value) end
    if valueType ~= "table" then
        error("JSON cannot encode " .. valueType, 3)
    end
    if stack[value] then error("JSON cannot encode cyclic tables", 3) end
    stack[value] = true

    local shape, length = tableShape(value)
    local parts = {}
    if shape == "array" then
        for index = 1, length do
            parts[index] = encodeValue(value[index], stack)
        end
        stack[value] = nil
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local keys = {}
    for key in pairs(value) do
        if type(key) ~= "string" then
            error("JSON object keys must be strings", 3)
        end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for index, key in ipairs(keys) do
        parts[index] = escapeString(key) .. ":" .. encodeValue(value[key], stack)
    end
    stack[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

function json.encode(value)
    return encodeValue(value, {})
end

local function utf8(codepoint)
    if codepoint <= 0x7f then
        return string.char(codepoint)
    elseif codepoint <= 0x7ff then
        return string.char(0xc0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
    elseif codepoint <= 0xffff then
        return string.char(0xe0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
    end
    return string.char(0xf0 + math.floor(codepoint / 0x40000),
        0x80 + (math.floor(codepoint / 0x1000) % 0x40),
        0x80 + (math.floor(codepoint / 0x40) % 0x40), 0x80 + (codepoint % 0x40))
end

local function parser(source)
    local position = 1
    local length = #source

    local function fail(message)
        error(string.format("invalid JSON at byte %d: %s", position, message), 0)
    end

    local function skipSpace()
        while position <= length and source:sub(position, position):match("[ \t\r\n]") do
            position = position + 1
        end
    end

    local parseValue

    local function parseString()
        position = position + 1
        local parts = {}
        local start = position
        while position <= length do
            local byte = source:byte(position)
            if byte == 34 then
                parts[#parts + 1] = source:sub(start, position - 1)
                position = position + 1
                return table.concat(parts)
            elseif byte == 92 then
                parts[#parts + 1] = source:sub(start, position - 1)
                local escape = source:sub(position + 1, position + 1)
                local simple = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
                if simple[escape] then
                    parts[#parts + 1] = simple[escape]
                    position = position + 2
                elseif escape == "u" then
                    local hex = source:sub(position + 2, position + 5)
                    if not hex:match("^%x%x%x%x$") then fail("bad unicode escape") end
                    local codepoint = tonumber(hex, 16)
                    position = position + 6
                    if codepoint >= 0xd800 and codepoint <= 0xdbff then
                        if source:sub(position, position + 1) ~= "\\u" then fail("missing low surrogate") end
                        local lowHex = source:sub(position + 2, position + 5)
                        local low = tonumber(lowHex, 16)
                        if not low or low < 0xdc00 or low > 0xdfff then fail("bad low surrogate") end
                        codepoint = 0x10000 + (codepoint - 0xd800) * 0x400 + (low - 0xdc00)
                        position = position + 6
                    elseif codepoint >= 0xdc00 and codepoint <= 0xdfff then
                        fail("unexpected low surrogate")
                    end
                    parts[#parts + 1] = utf8(codepoint)
                else
                    fail("bad escape")
                end
                start = position
            elseif byte < 32 then
                fail("control character in string")
            else
                position = position + 1
            end
        end
        fail("unterminated string")
    end

    local function parseNumber()
        local start = position
        if source:sub(position, position) == "-" then position = position + 1 end
        local first = source:sub(position, position)
        if first == "0" then
            position = position + 1
            if source:sub(position, position):match("%d") then fail("leading zero") end
        elseif first:match("[1-9]") then
            repeat position = position + 1 until not source:sub(position, position):match("%d")
        else
            fail("bad number")
        end
        if source:sub(position, position) == "." then
            position = position + 1
            if not source:sub(position, position):match("%d") then fail("missing fraction digits") end
            repeat position = position + 1 until not source:sub(position, position):match("%d")
        end
        local exponent = source:sub(position, position)
        if exponent == "e" or exponent == "E" then
            position = position + 1
            local sign = source:sub(position, position)
            if sign == "+" or sign == "-" then position = position + 1 end
            if not source:sub(position, position):match("%d") then fail("missing exponent digits") end
            repeat position = position + 1 until not source:sub(position, position):match("%d")
        end
        local token = source:sub(start, position - 1)
        local value = tonumber(token)
        if not value then fail("number out of range") end
        return value
    end

    local function parseArray()
        position = position + 1
        skipSpace()
        local result = json.array()
        if source:sub(position, position) == "]" then
            position = position + 1
            return result
        end
        while true do
            result[#result + 1] = parseValue()
            skipSpace()
            local char = source:sub(position, position)
            if char == "]" then
                position = position + 1
                return result
            elseif char ~= "," then
                fail("expected ',' or ']'")
            end
            position = position + 1
            skipSpace()
        end
    end

    local function parseObject()
        position = position + 1
        skipSpace()
        local result = json.object()
        if source:sub(position, position) == "}" then
            position = position + 1
            return result
        end
        while true do
            if source:sub(position, position) ~= '"' then fail("expected object key") end
            local key = parseString()
            if result[key] ~= nil then fail("duplicate object key") end
            skipSpace()
            if source:sub(position, position) ~= ":" then fail("expected ':'") end
            position = position + 1
            skipSpace()
            result[key] = parseValue()
            skipSpace()
            local char = source:sub(position, position)
            if char == "}" then
                position = position + 1
                return result
            elseif char ~= "," then
                fail("expected ',' or '}'")
            end
            position = position + 1
            skipSpace()
        end
    end

    parseValue = function()
        skipSpace()
        local char = source:sub(position, position)
        if char == '"' then return parseString() end
        if char == "{" then return parseObject() end
        if char == "[" then return parseArray() end
        if char == "-" or char:match("%d") then return parseNumber() end
        if source:sub(position, position + 3) == "true" then position = position + 4; return true end
        if source:sub(position, position + 4) == "false" then position = position + 5; return false end
        if source:sub(position, position + 3) == "null" then position = position + 4; return json.null end
        fail("unexpected token")
    end

    local value = parseValue()
    skipSpace()
    if position <= length then fail("trailing content") end
    return value
end

function json.decode(source)
    if type(source) ~= "string" then error("JSON input must be a string", 2) end
    return parser(source)
end

return json
