local Rng = {}
Rng.__index = Rng

local LoveRng = {}
LoveRng.__index = LoveRng

local MODULUS = 2147483647
local MULTIPLIER = 16807
local SEED_MODULUS = MODULUS - 1

local function normalizeSeed(seed)
    local numeric = tonumber(seed)
    if not numeric then
        error("rng seed must be numeric", 3)
    end

    numeric = math.floor(numeric) % MODULUS
    if numeric <= 0 then
        numeric = numeric + MODULUS - 1
    end
    return numeric
end

function Rng.new(seed)
    return setmetatable({
        algorithm = "park-miller-v1",
        state = normalizeSeed(seed or 1),
    }, Rng)
end

function Rng.seedFromString(value)
    assert(type(value) == "string", "seed source must be a string")
    local seed = 0
    for index = 1, #value do
        -- 131 * (MODULUS - 2) remains exactly representable by Lua's double numbers.
        seed = (seed * 131 + value:byte(index)) % SEED_MODULUS
    end
    return seed + 1
end

function Rng:drawInteger(lo, hi)
    if type(lo) ~= "number" or type(hi) ~= "number"
        or lo ~= math.floor(lo) or hi ~= math.floor(hi) or lo > hi then
        error("drawInteger requires integer bounds with lo <= hi", 2)
    end

    self.state = (self.state * MULTIPLIER) % MODULUS
    local width = hi - lo + 1
    return lo + (self.state % width)
end

function Rng:getState()
    return {
        algorithm = self.algorithm,
        state = self.state,
    }
end

function Rng:setState(snapshot)
    if type(snapshot) ~= "table" or snapshot.algorithm ~= self.algorithm then
        return nil, "unsupported rng state"
    end
    if type(snapshot.state) ~= "number" or snapshot.state ~= math.floor(snapshot.state)
        or snapshot.state <= 0 or snapshot.state >= MODULUS then
        return nil, "invalid rng state"
    end

    self.state = snapshot.state
    return true
end

function Rng:clone()
    local copy = Rng.new(1)
    copy.state = self.state
    return copy
end

function Rng.fromLove(generator, engineVersion)
    assert(type(generator) == "table" or type(generator) == "userdata",
        "LÖVE RandomGenerator required")
    assert(type(generator.random) == "function" and type(generator.getState) == "function"
        and type(generator.setState) == "function", "RandomGenerator API is incomplete")
    assert(type(engineVersion) == "string" and engineVersion ~= "", "engineVersion required")
    return setmetatable({
        generator = generator,
        algorithm = "love-random-generator",
        engineVersion = engineVersion,
    }, LoveRng)
end

function LoveRng:drawInteger(lo, hi)
    if type(lo) ~= "number" or type(hi) ~= "number"
        or lo ~= math.floor(lo) or hi ~= math.floor(hi) or lo > hi then
        error("drawInteger requires integer bounds with lo <= hi", 2)
    end
    return self.generator:random(lo, hi)
end

function LoveRng:getState()
    return {
        algorithm = self.algorithm,
        engineVersion = self.engineVersion,
        state = self.generator:getState(),
    }
end

function LoveRng:setState(snapshot)
    if type(snapshot) ~= "table" or snapshot.algorithm ~= self.algorithm then
        return nil, "unsupported rng state"
    end
    if snapshot.engineVersion ~= self.engineVersion then
        return nil, "rng engine version mismatch"
    end
    if type(snapshot.state) ~= "string" then return nil, "invalid rng state" end
    local ok, failure = pcall(self.generator.setState, self.generator, snapshot.state)
    if not ok then return nil, failure end
    return true
end

return Rng
