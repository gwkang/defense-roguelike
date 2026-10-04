local Content = require("src.content")
local Rng = require("src.rng")

local Shop = {}

local KINDS = {
    { kind = "tower", poolField = "towerIds", defsField = "towersById" },
    { kind = "patch", poolField = "patchIds", defsField = "patchesById" },
    { kind = "module", poolField = "moduleIds", defsField = "modulesById" },
}
local TIER_ORDER = { "low", "mid", "high" }
local TIER_WEIGHT = { low = 60, mid = 30, high = 10 }

local function copy(value)
    return Content.clone(value)
end

local function candidates(defs, options, spec)
    local byTier = { low = {}, mid = {}, high = {} }
    local acquired = options.acquiredModuleIds or {}
    for _, id in ipairs(options.frozenUnlockPool[spec.poolField] or {}) do
        local def = defs[spec.defsField][id]
        if def and not (spec.kind == "module" and acquired[id]) then
            byTier[def.tier][#byTier[def.tier] + 1] = id
        end
    end
    for _, tier in ipairs(TIER_ORDER) do table.sort(byTier[tier]) end
    return byTier
end

local function drawOffer(rng, byTier)
    local totalWeight = 0
    for _, tier in ipairs(TIER_ORDER) do
        if #byTier[tier] > 0 then totalWeight = totalWeight + TIER_WEIGHT[tier] end
    end
    if totalWeight == 0 then return nil end
    local roll = rng:drawInteger(1, totalWeight)
    local selectedTier
    for _, tier in ipairs(TIER_ORDER) do
        if #byTier[tier] > 0 then
            roll = roll - TIER_WEIGHT[tier]
            if roll <= 0 then selectedTier = tier break end
        end
    end
    local tierCandidates = assert(byTier[selectedTier])
    return tierCandidates[rng:drawInteger(1, #tierCandidates)]
end

local function rollOffers(defs, options)
    assert(type(options) == "table", "shop options required")
    assert(type(options.frozenUnlockPool) == "table", "frozenUnlockPool required")
    assert(type(options.rngState) == "table", "rngState required")
    local rng = Rng.new(1)
    assert(rng:setState(options.rngState))
    local offers, soldOut = {}, {}
    for _, spec in ipairs(KINDS) do
        local offer = drawOffer(rng, candidates(defs, options, spec))
        offers[spec.kind] = offer
        soldOut[spec.kind] = offer == nil
    end
    return offers, soldOut, rng:getState()
end

function Shop.createVisit(defs, options)
    assert(type(options.visitId) == "string" and options.visitId ~= "", "visitId required")
    local offers, soldOut, nextRngState = rollOffers(defs, options)
    return {
        visitId = options.visitId,
        offers = offers,
        soldOut = soldOut,
        rerollCount = 0,
        refundUseCount = 0,
        firstRerollDone = false,
        rngState = nextRngState,
        accessOpen = true,
    }
end

function Shop.reroll(defs, shopState, options)
    assert(type(shopState) == "table", "shopState required")
    options = copy(options or {})
    options.rngState = shopState.rngState
    local offers, soldOut, nextRngState = rollOffers(defs, options)
    local candidate = copy(shopState)
    candidate.offers = offers
    candidate.soldOut = soldOut
    candidate.rerollCount = (candidate.rerollCount or 0) + 1
    candidate.firstRerollDone = true
    candidate.rngState = nextRngState
    return candidate
end

return Shop
