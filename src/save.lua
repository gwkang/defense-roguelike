local Json = require("src.json")
local Rng = require("src.rng")
local Rules = require("src.rules")

local Save = {}
Save.__index = Save

local SLOT_PATHS = { "save-a.json", "save-b.json" }

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    setmetatable(result, getmetatable(value))
    seen[value] = result
    for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
    return result
end

local function adler32(value)
    -- Deterministic corruption check for non-LÖVE fixtures only; this is not cryptographic.
    local a, b = 1, 0
    for index = 1, #value do
        a = (a + value:byte(index)) % 65521
        b = (b + a) % 65521
    end
    return string.format("adler32-v1:%08x", b * 65536 + a)
end

local function validatePayloadShape(payload)
    if type(payload) ~= "table" then return nil, "payload must be an object" end
    if type(payload.metaState) ~= "table" then return nil, "payload.metaState must be an object" end
    if type(payload.runState) ~= "table" then return nil, "payload.runState must be an object" end
    if type(payload.checkpointKind) ~= "string" or payload.checkpointKind == "" then
        return nil, "payload.checkpointKind must be a non-empty string"
    end
    if type(payload.resumeDescriptor) ~= "table" then
        return nil, "payload.resumeDescriptor must be an object"
    end
    return true
end

local function indexById(items)
    local indexed = {}
    for _, item in ipairs(items or {}) do
        if type(item) == "table" and type(item.id) == "string" then indexed[item.id] = item end
    end
    return indexed
end

local function denseArray(value)
    if type(value) ~= "table" then return nil end
    local count, maximum = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then return nil end
        count = count + 1
        if key > maximum then maximum = key end
    end
    if count ~= maximum then return nil end
    return maximum
end

local function isInteger(value)
    return type(value) == "number" and value == value and value ~= math.huge
        and value ~= -math.huge and value == math.floor(value)
end

local function buildPathCells(map)
    local occupied = {}
    for _, route in ipairs(map.routes or {}) do
        for pointIndex = 2, #(route.points or {}) do
            local start = route.points[pointIndex - 1]
            local finish = route.points[pointIndex]
            local dx = finish.x == start.x and 0 or (finish.x > start.x and 1 or -1)
            local dy = finish.y == start.y and 0 or (finish.y > start.y and 1 or -1)
            local x, y = start.x, start.y
            occupied[x .. ":" .. y] = true
            while x ~= finish.x or y ~= finish.y do
                x, y = x + dx, y + dy
                occupied[x .. ":" .. y] = true
            end
        end
    end
    return occupied
end

local function validateIdArray(value, known, path)
    if value == nil then return true end
    local count = denseArray(value)
    if count == nil then return nil, path .. " must be a dense array" end
    local seen = {}
    for index = 1, count do
        local id = value[index]
        if type(id) ~= "string" or not known[id] then
            return nil, path .. " contains an unknown reference at index " .. index
        end
        if seen[id] then return nil, path .. " contains duplicate reference " .. id end
        seen[id] = true
    end
    return true
end

function Save.validatePayloadShape(payload)
    return validatePayloadShape(payload)
end

local function createPayloadValidator(defs, mode)
    assert(type(defs) == "table", "definitions required")
    mode = mode or "current"
    local maps = defs.mapsById or indexById(defs.maps)
    local towers = defs.towersById or indexById(defs.towers)
    local patches = defs.patchesById or indexById(defs.patches)
    local modules = defs.modulesById or indexById(defs.modules)
    local waves = defs.wavesById or indexById(defs.waves)
    local currentShape = mode ~= "legacy"
    local towerUnlockShape = mode == "current"
        and (defs.version == "DR-TOWER-U2-r1" or defs.version == "DR-MOD-I28-r1"
            or defs.version == "DR-MOD-I43-r1" or defs.version == "DR-MOD-I46-r1"
            or defs.version == "DR-MOD-I41-r1" or defs.version == "DR-MOD-I42-r1" or defs.version == "DR-MOD-I15-r1"
            or defs.version == "DR-MOD-I14-r1" or defs.version == "DR-MOD-I12-r1" or defs.version == "DR-MOD-I16-r1" or defs.version == "DR-MOD-I31-r1")
    local moduleUnlockIds = mode == "current" and
        (defs.version == "DR-MOD-I31-r1" and { "M12", "M14", "M15", "M16", "M28", "M31", "M41", "M42", "M43", "M46" }
            or defs.version == "DR-MOD-I16-r1" and { "M12", "M14", "M15", "M16", "M28", "M41", "M42", "M43", "M46" }
            or defs.version == "DR-MOD-I12-r1" and { "M12", "M14", "M15", "M28", "M41", "M42", "M43", "M46" }
            or defs.version == "DR-MOD-I14-r1" and { "M14", "M15", "M28", "M41", "M42", "M43", "M46" }
            or defs.version == "DR-MOD-I15-r1" and { "M15", "M28", "M41", "M42", "M43", "M46" }
            or defs.version == "DR-MOD-I42-r1" and { "M28", "M41", "M42", "M43", "M46" }
            or defs.version == "DR-MOD-I41-r1" and { "M28", "M41", "M43", "M46" }
            or defs.version == "DR-MOD-I46-r1" and { "M28", "M43", "M46" }
            or defs.version == "DR-MOD-I43-r1" and { "M28", "M43" }
            or defs.version == "DR-MOD-I28-r1" and { "M28" } or {}) or {}
    local growthModules = { M33 = true, M34 = true, M37 = true }
    local maximumWaveIndex = 0
    for _, wave in pairs(waves) do
        if isInteger(wave.index) and wave.index > maximumWaveIndex then maximumWaveIndex = wave.index end
    end

    return function(payload)
        local shaped, shapeError = validatePayloadShape(payload)
        if not shaped then return nil, shapeError end

        local meta = payload.metaState
        local valid, validationError = validateIdArray(meta.unlockedTowerIds, towers, "metaState.unlockedTowerIds")
        if not valid then return nil, validationError end
        valid, validationError = validateIdArray(meta.unlockedModuleIds, modules, "metaState.unlockedModuleIds")
        if not valid then return nil, validationError end

        local run = payload.runState
        if type(run.runId) ~= "string" or run.runId == "" then return nil, "runState.runId must be a non-empty string" end
        if type(run.contentVersion) ~= "string" or run.contentVersion ~= defs.version then
            return nil, "runState.contentVersion does not match live definitions"
        end
        local phases = { TITLE = true, SHOP = true, PREPARE = true, COMBAT = true, RESULT = true }
        if type(run.phase) ~= "string" or not phases[run.phase] then return nil, "runState.phase is invalid" end
        local map = maps[run.mapId]
        if not map then return nil, "runState.mapId is unknown" end

        if not isInteger(run.nextWaveIndex) or run.nextWaveIndex < 1
            or run.nextWaveIndex > maximumWaveIndex + 1 then
            return nil, "runState.nextWaveIndex is outside the supported wave range"
        end
        for _, field in ipairs({ "gold", "hp", "baseTowerCapacity", "baseModuleSlots" }) do
            local value = run[field]
            if not isInteger(value) or value < 0 then
                return nil, "runState." .. field .. " must be a non-negative integer"
            end
        end

        local towerCount = denseArray(run.towerInstances)
        if towerCount == nil then return nil, "runState.towerInstances must be a dense array" end
        local instanceIds = {}
        local occupiedCells = {}
        local pathCells = buildPathCells(map)
        local maximumInstanceId = 0
        local placedCount = 0
        for index = 1, towerCount do
            local tower = run.towerInstances[index]
            if type(tower) ~= "table" then return nil, "runState.towerInstances contains a non-object" end
            if not isInteger(tower.instanceId) or tower.instanceId <= 0 then
                return nil, "tower instanceId must be a positive integer"
            end
            if instanceIds[tower.instanceId] then return nil, "duplicate tower instanceId" end
            instanceIds[tower.instanceId] = true
            maximumInstanceId = math.max(maximumInstanceId, tower.instanceId)
            if type(tower.typeId) ~= "string" or not towers[tower.typeId] then return nil, "tower typeId is unknown" end
            if not isInteger(tower.paidGold) or tower.paidGold < 0 then
                return nil, "tower paidGold must be a non-negative integer"
            end
            if type(tower.charge) ~= "number" or tower.charge ~= tower.charge
                or tower.charge == math.huge or tower.charge == -math.huge or tower.charge < 0 then
                return nil, "tower charge must be a finite non-negative number"
            end
            if type(tower.activated) ~= "boolean" then return nil, "tower activated must be boolean" end
            local patchCount = denseArray(tower.patchIds)
            if patchCount == nil then return nil, "tower patchIds must be a dense array" end
            if patchCount > 3 then return nil, "tower patch limit exceeded" end
            for patchIndex = 1, patchCount do
                if type(tower.patchIds[patchIndex]) ~= "string" or not patches[tower.patchIds[patchIndex]] then
                    return nil, "tower patchIds contains an unknown reference"
                end
            end
            if tower.placement ~= nil then
                if type(tower.placement) ~= "table" or not isInteger(tower.placement.x)
                    or not isInteger(tower.placement.y) then
                    return nil, "tower placement must contain integer coordinates"
                end
                local x, y = tower.placement.x, tower.placement.y
                if x < 0 or x >= map.width or y < 0 or y >= map.height then
                    return nil, "tower placement is outside map bounds"
                end
                local cell = x .. ":" .. y
                if pathCells[cell] then return nil, "tower placement overlaps a path cell" end
                if occupiedCells[cell] then return nil, "tower placements overlap" end
                occupiedCells[cell] = true
                placedCount = placedCount + 1
            end
        end
        if not isInteger(run.nextInstanceId) or run.nextInstanceId <= maximumInstanceId then
            return nil, "runState.nextInstanceId must be greater than every live instanceId"
        end

        local moduleCount = denseArray(run.modules)
        if moduleCount == nil then return nil, "runState.modules must be a dense array" end
        local installedModules = {}
        for index = 1, moduleCount do
            local entry = run.modules[index]
            if mode == "current" and type(entry) ~= "table" then
                return nil, "current module entries must be objects"
            end
            local moduleId = type(entry) == "table" and (entry.moduleId or entry.id) or entry
            if type(moduleId) ~= "string" or not modules[moduleId] then return nil, "installed module reference is unknown" end
            if installedModules[moduleId] then return nil, "duplicate installed module reference" end
            installedModules[moduleId] = true
            if type(entry) == "table" then
                for _, field in ipairs({ "paidGold", "growth" }) do
                    local value = entry[field]
                    if not isInteger(value) or value < 0 then
                        return nil, "module " .. field .. " must be a non-negative integer"
                    end
                end
                if mode == "current" and growthModules[moduleId]
                    and (entry.growth > 30 or entry.growth % 3 ~= 0) then
                    return nil, "module growth must be between 0 and 30 in steps of 3"
                end
            end
        end
        local moduleCapacity = Rules.moduleCapacity(run)
        if moduleCount > moduleCapacity then return nil, "installed module count exceeds baseModuleSlots" end
        local towerCapacity = Rules.towerCapacity(run)
        if placedCount > towerCapacity then return nil, "placed tower count exceeds current capacity" end

        if type(run.acquiredModuleIds) ~= "table" then return nil, "runState.acquiredModuleIds must be an object" end
        for moduleId, acquired in pairs(run.acquiredModuleIds) do
            if type(moduleId) ~= "string" or not modules[moduleId] or acquired ~= true then
                return nil, "runState.acquiredModuleIds contains an invalid reference"
            end
        end
        if type(run.completedWaveIds) ~= "table" then return nil, "runState.completedWaveIds must be an object" end
        for waveId, completed in pairs(run.completedWaveIds) do
            if type(waveId) ~= "string" or not waves[waveId] or completed ~= true then
                return nil, "runState.completedWaveIds contains an invalid wave reference"
            end
        end
        for _, field in ipairs({ "waveId", "currentWaveId" }) do
            if run[field] ~= nil and (type(run[field]) ~= "string" or not waves[run[field]]) then
                return nil, "runState." .. field .. " is an unknown wave reference"
            end
        end

        local shop = run.shopState
        if type(shop) ~= "table" then return nil, "runState.shopState must be an object" end
        if type(shop.visitId) ~= "string" or shop.visitId == "" then
            return nil, "shopState.visitId must be a non-empty string"
        end
        if not isInteger(shop.rerollCount) or shop.rerollCount < 0 then
            return nil, "shopState.rerollCount is invalid"
        end
        if mode == "legacy" then
            if not isInteger(shop.fixtureIndex) or shop.fixtureIndex < 1 then
                return nil, "shopState.fixtureIndex is invalid"
            end
        elseif shop.fixtureIndex ~= nil and (not isInteger(shop.fixtureIndex) or shop.fixtureIndex < 1) then
            return nil, "shopState.fixtureIndex is invalid"
        end
        if (currentShape and shop.refundUseCount == nil)
            or (shop.refundUseCount ~= nil and (not isInteger(shop.refundUseCount) or shop.refundUseCount < 0)) then
            return nil, "shopState.refundUseCount is invalid"
        end
        if type(shop.firstRerollDone) ~= "boolean" then return nil, "shopState.firstRerollDone must be boolean" end
        if type(shop.offers) ~= "table" then return nil, "shopState.offers must be an object" end
        local offerFamilies = { tower = towers, patch = patches, module = modules }
        for kind, offerId in pairs(shop.offers) do
            if not offerFamilies[kind] then return nil, "shopState.offers contains an unknown offer kind" end
            if type(offerId) ~= "string" or not offerFamilies[kind][offerId] then
                return nil, "shopState.offers contains an unknown " .. kind .. " reference"
            end
        end

        if currentShape then
            if type(shop.accessOpen) ~= "boolean" then return nil, "shopState.accessOpen must be boolean" end
            if type(shop.rngState) ~= "table" or shop.rngState.algorithm ~= "park-miller-v1"
                or not isInteger(shop.rngState.state) or shop.rngState.state <= 0
                or shop.rngState.state >= 2147483647 then
                return nil, "shopState.rngState is invalid"
            end
            if type(shop.soldOut) ~= "table" then return nil, "shopState.soldOut must be an object" end
            for _, kind in ipairs({ "tower", "patch", "module" }) do
                if type(shop.soldOut[kind]) ~= "boolean" then
                    return nil, "shopState.soldOut." .. kind .. " must be boolean"
                end
                if shop.soldOut[kind] and shop.offers[kind] ~= nil then
                    return nil, "shopState cannot have an offer for a sold-out kind"
                end
            end

            local pool = run.frozenUnlockPool
            if type(pool) ~= "table" then return nil, "runState.frozenUnlockPool must be an object" end
            local poolFamilies = {
                towerIds = towers,
                patchIds = patches,
                moduleIds = modules,
            }
            for field, known in pairs(poolFamilies) do
                local poolValid, poolError = validateIdArray(pool[field], known,
                    "runState.frozenUnlockPool." .. field)
                if not poolValid or pool[field] == nil then
                    return nil, poolError or ("runState.frozenUnlockPool." .. field .. " is required")
                end
            end
            for _, moduleId in ipairs(moduleUnlockIds) do
                local unlocked, pooled = false, false
                for _, id in ipairs(meta.unlockedModuleIds or {}) do if id == moduleId then unlocked = true end end
                for _, id in ipairs(pool.moduleIds) do if id == moduleId then pooled = true end end
                if pooled and not unlocked then return nil, "frozen module pool contains locked " .. moduleId end
                if shop.offers.module == moduleId or installedModules[moduleId] or run.acquiredModuleIds[moduleId] then
                    if not unlocked or not pooled then return nil, moduleId .. " reference requires permanent unlock and frozen pool" end
                end
                if installedModules[moduleId] and not run.acquiredModuleIds[moduleId] then
                    return nil, "installed " .. moduleId .. " must be recorded as acquired"
                end
                if shop.offers.module == moduleId and run.acquiredModuleIds[moduleId] then
                    return nil, "acquired " .. moduleId .. " cannot be offered again"
                end
            end
            if towerUnlockShape then
                if meta.unlockedTowerIds == nil then return nil, "metaState.unlockedTowerIds is required" end
                local unlocked, pooled = {}, {}
                for _, id in ipairs(meta.unlockedTowerIds) do unlocked[id] = true end
                for _, id in ipairs(pool.towerIds) do
                    if not unlocked[id] then return nil, "frozen tower pool contains a locked tower" end
                    pooled[id] = true
                end
                for _, id in ipairs({ "T01", "T02", "T03", "T04" }) do
                    if not unlocked[id] then return nil, "metaState is missing a starting tower" end
                    if not pooled[id] then return nil, "frozen tower pool is missing a starting tower" end
                end
                if shop.offers.tower and not pooled[shop.offers.tower] then
                    return nil, "tower offer is outside the frozen tower pool"
                end
                for _, tower in ipairs(run.towerInstances) do
                    if not pooled[tower.typeId] then return nil, "tower instance is outside the frozen tower pool" end
                end
                if run.completedWaveIds.W05 and (run.nextWaveIndex <= 5 or not unlocked.T05) then
                    return nil, "W05 completion is inconsistent with progress or T05 unlock"
                end
                if run.completedWaveIds.W15 then return nil, "W15 cannot be a normal wave completion" end
            end
            if type(run.unlockRunProgress) ~= "table" then
                return nil, "runState.unlockRunProgress must be an object"
            end

            if run.phase == "RESULT" then
                local runResult = run.result
                if type(runResult) ~= "table"
                    or (runResult.kind ~= "victory" and runResult.kind ~= "defeat")
                    or type(runResult.waveId) ~= "string" or not waves[runResult.waveId]
                    or not isInteger(runResult.tick) or runResult.tick < 0
                    or type(runResult.reason) ~= "string" or runResult.reason == "" then
                    return nil, "runState.result is invalid"
                end
                if towerUnlockShape and runResult.kind == "victory" then
                    local hasT06 = false
                    for _, id in ipairs(meta.unlockedTowerIds) do if id == "T06" then hasT06 = true end end
                    if runResult.waveId ~= "W15" or runResult.reason ~= "boss_killed"
                        or run.hp <= 0 or run.nextWaveIndex ~= 15 or not hasT06 then
                        return nil, "victory result is inconsistent with boss victory or T06 unlock"
                    end
                end
            elseif run.result ~= nil then
                return nil, "runState.result is only valid in RESULT"
            end
        end

        local descriptor = payload.resumeDescriptor
        if descriptor.waveId ~= nil and (type(descriptor.waveId) ~= "string" or not waves[descriptor.waveId]) then
            return nil, "resumeDescriptor.waveId is unknown"
        end
        if descriptor.waveIndex ~= nil and (not isInteger(descriptor.waveIndex)
            or descriptor.waveIndex < 1 or descriptor.waveIndex > maximumWaveIndex + 1) then
            return nil, "resumeDescriptor.waveIndex is invalid"
        end
        return true
    end
end

function Save.createLivePayloadValidator(defs)
    return createPayloadValidator(defs, "current")
end

local SLICE_VERSION = "DR-SLICE-001-r2"
local RUN002_VERSION = "DR-RUN-002-r1"
local S24_VERSION = "DR-MOD-S24-r1"
local TOWER_U2_VERSION = "DR-TOWER-U2-r1"
local I28_VERSION = "DR-MOD-I28-r1"
local I43_VERSION = "DR-MOD-I43-r1"
local I46_VERSION = "DR-MOD-I46-r1"
local I41_VERSION = "DR-MOD-I41-r1"
local I42_VERSION = "DR-MOD-I42-r1"
local I15_VERSION = "DR-MOD-I15-r1"
local I14_VERSION = "DR-MOD-I14-r1"
local I12_VERSION = "DR-MOD-I12-r1"
local I16_VERSION = "DR-MOD-I16-r1"
local SLICE_IDS = {
    maps = { "M01" },
    enemies = { "E01", "E02", "E03", "E04" },
    towers = { "T01", "T02", "T03", "T04" },
    patches = {
        "P_DAMAGE", "P_RATE", "P_RANGE", "P_OVERLOAD", "P_OVERDRIVE", "P_LONG_RANGE",
        "P_FOCUSED_BARRAGE", "P_CONTINUOUS_AIM", "P_HEAVY_AIM",
    },
    modules = { "M01", "M02", "M05", "M17", "M25", "M26" },
    waves = { "W01", "W02", "W03" },
}
local RUN002_IDS = {
    maps = { "M01" },
    enemies = { "E01", "E02", "E03", "E04", "E05" },
    towers = { "T01", "T02", "T03", "T04" },
    patches = {
        "P_DAMAGE", "P_RATE", "P_RANGE", "P_OVERLOAD", "P_OVERDRIVE", "P_LONG_RANGE",
        "P_FOCUSED_BARRAGE", "P_CONTINUOUS_AIM", "P_HEAVY_AIM",
    },
    modules = { "M01", "M02", "M05", "M17", "M25", "M26" },
    waves = {
        "W01", "W02", "W03", "W04", "W05", "W06", "W07", "W08",
        "W09", "W10", "W11", "W12", "W13", "W14", "W15",
    },
}
local S24_IDS = copy(RUN002_IDS)
S24_IDS.modules = {
    "M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08", "M09", "M10", "M11", "M13",
    "M17", "M18", "M25", "M26", "M29", "M30", "M32", "M33", "M34", "M37", "M44", "M45",
}
local TOWER_U2_IDS = copy(S24_IDS)
TOWER_U2_IDS.towers = { "T01", "T02", "T03", "T04", "T05", "T06" }
local I28_IDS = copy(TOWER_U2_IDS)
I28_IDS.modules[#I28_IDS.modules + 1] = "M28"
local I43_IDS = copy(I28_IDS)
I43_IDS.modules[#I43_IDS.modules + 1] = "M43"
local I46_IDS = copy(I43_IDS)
I46_IDS.modules[#I46_IDS.modules + 1] = "M46"
local I41_IDS = copy(I46_IDS)
I41_IDS.modules[#I41_IDS.modules + 1] = "M41"
local I42_IDS = copy(I41_IDS)
I42_IDS.modules[#I42_IDS.modules + 1] = "M42"
local I15_IDS = copy(I42_IDS)
I15_IDS.modules[#I15_IDS.modules + 1] = "M15"
local I14_IDS = copy(I15_IDS)
I14_IDS.modules[#I14_IDS.modules + 1] = "M14"
local I12_IDS = copy(I14_IDS)
I12_IDS.modules[#I12_IDS.modules + 1] = "M12"
local I16_IDS = copy(I12_IDS)
I16_IDS.modules[#I16_IDS.modules + 1] = "M16"

local function definitionsById(defs, family)
    return defs[family .. "ById"] or indexById(defs[family])
end

local function selectDefinitions(defs, family, ids)
    local indexed = definitionsById(defs, family)
    local selected = Json.array()
    for _, id in ipairs(ids) do
        assert(indexed[id], "definitions are missing legacy " .. family .. " id " .. id)
        selected[#selected + 1] = indexed[id]
    end
    return selected
end

local function createVersionDefinitions(defs, version, versionIds)
    local selectedDefs = { version = version }
    for family, ids in pairs(versionIds) do
        selectedDefs[family] = selectDefinitions(defs, family, ids)
        selectedDefs[family .. "ById"] = indexById(selectedDefs[family])
    end
    return selectedDefs
end

local function legacyReferencesAreKnown(value, knownEnemies, seen)
    if type(value) == "string" then
        if value:match("^E%d%d$") and not knownEnemies[value] then
            return nil, "legacy payload contains an unknown enemy reference"
        end
        return true
    end
    if type(value) ~= "table" then return true end
    seen = seen or {}
    if seen[value] then return true end
    seen[value] = true
    for key, item in pairs(value) do
        local valid, validationError = legacyReferencesAreKnown(key, knownEnemies, seen)
        if not valid then return nil, validationError end
        valid, validationError = legacyReferencesAreKnown(item, knownEnemies, seen)
        if not valid then return nil, validationError end
    end
    return true
end

local function validateLegacyProgress(payload, legacyDefs)
    local run = payload.runState
    local shop = run.shopState
    local nextWave = run.nextWaveIndex
    local descriptor = payload.resumeDescriptor

    if type(run.developmentComplete) ~= "boolean"
        or run.developmentComplete ~= (nextWave == 4) then
        return nil, "legacy developmentComplete is inconsistent with progress"
    end
    if shop.visitId ~= "S00" and shop.visitId ~= "S01" then
        return nil, "legacy shop visitId is invalid"
    end
    for index = 1, 3 do
        local waveId = string.format("W%02d", index)
        local shouldBeComplete = index < nextWave
        if (run.completedWaveIds[waveId] == true) ~= shouldBeComplete then
            return nil, "legacy completedWaveIds is not a contiguous prefix"
        end
    end
    if descriptor.waveIndex ~= nextWave then
        return nil, "legacy resumeDescriptor.waveIndex must match nextWaveIndex"
    end
    if descriptor.kind ~= nil and descriptor.kind ~= payload.checkpointKind then
        return nil, "legacy resumeDescriptor.kind must match checkpointKind"
    end

    if run.phase == "SHOP" then
        if not ((nextWave == 1 and shop.visitId == "S00")
            or (nextWave == 4 and shop.visitId == "S01")) then
            return nil, "legacy SHOP progression is inconsistent"
        end
    elseif run.phase == "PREPARE" then
        local expectedVisit = nextWave == 4 and "S01" or "S00"
        if shop.visitId ~= expectedVisit then return nil, "legacy PREPARE visit is inconsistent" end
    elseif run.phase == "COMBAT" then
        if nextWave > 3 or payload.checkpointKind ~= "combatStart" or shop.visitId ~= "S00" then
            return nil, "legacy COMBAT progression is inconsistent"
        end
        local expectedWaveId = string.format("W%02d", nextWave)
        if run.waveId ~= nil and run.waveId ~= expectedWaveId then
            return nil, "legacy COMBAT waveId is inconsistent"
        end
        if run.currentWaveId ~= nil and run.currentWaveId ~= expectedWaveId then
            return nil, "legacy COMBAT currentWaveId is inconsistent"
        end
    elseif run.phase == "RESULT" then
        if nextWave > 3 or run.hp ~= 0 or payload.checkpointKind ~= "runResult"
            or shop.visitId ~= "S00" then
            return nil, "legacy RESULT must be an ordinary-wave defeat"
        end
    else
        return nil, "legacy phase was never durable"
    end

    return legacyReferencesAreKnown(payload, legacyDefs.enemiesById)
end

local function sortedDefinitionIds(defs, family)
    local ids = {}
    for id in pairs(definitionsById(defs, family)) do ids[#ids + 1] = id end
    table.sort(ids)
    return Json.array(ids)
end

function Save.createRun002Migrations(defs)
    assert(type(defs) == "table" and type(defs.version) == "string", "current definitions required")
    local sliceDefs = createVersionDefinitions(defs, SLICE_VERSION, SLICE_IDS)
    local run002Defs = createVersionDefinitions(defs, RUN002_VERSION, RUN002_IDS)
    local s24Defs = createVersionDefinitions(defs, S24_VERSION, S24_IDS)
    local towerU2Defs = createVersionDefinitions(defs, TOWER_U2_VERSION, TOWER_U2_IDS)
    local i28Defs = createVersionDefinitions(defs, I28_VERSION, I28_IDS)
    local i43Defs = createVersionDefinitions(defs, I43_VERSION, I43_IDS)
    local i46Defs = createVersionDefinitions(defs, I46_VERSION, I46_IDS)
    local i41Defs = createVersionDefinitions(defs, I41_VERSION, I41_IDS)
    local i42Defs = createVersionDefinitions(defs, I42_VERSION, I42_IDS)
    local i15Defs = createVersionDefinitions(defs, I15_VERSION, I15_IDS)
    local i14Defs = createVersionDefinitions(defs, I14_VERSION, I14_IDS)
    local i12Defs = createVersionDefinitions(defs, I12_VERSION, I12_IDS)
    local validateSliceShape = createPayloadValidator(sliceDefs, "legacy")
    local validateRun002 = createPayloadValidator(run002Defs, "run002")
    local validateS24 = createPayloadValidator(s24Defs, "current")
    local validateTowerU2 = createPayloadValidator(towerU2Defs, "current")
    local validateI28 = createPayloadValidator(i28Defs, "current")
    local validateI43 = createPayloadValidator(i43Defs, "current")
    local validateI46 = createPayloadValidator(i46Defs, "current")
    local validateI41 = createPayloadValidator(i41Defs, "current")
    local validateI42 = createPayloadValidator(i42Defs, "current")
    local validateI15 = createPayloadValidator(i15Defs, "current")
    local validateI14 = createPayloadValidator(i14Defs, "current")
    local validateI12 = createPayloadValidator(i12Defs, "current")
    local i16Defs = createVersionDefinitions(defs, I16_VERSION, I16_IDS)
    local validateI16 = createPayloadValidator(i16Defs, "current")
    local frozenPool = {
        towerIds = sortedDefinitionIds(run002Defs, "towers"),
        patchIds = sortedDefinitionIds(run002Defs, "patches"),
        moduleIds = sortedDefinitionIds(run002Defs, "modules"),
    }

    local function validateSlice(payload)
        local valid, validationError = validateSliceShape(payload)
        if not valid then return nil, validationError end
        return validateLegacyProgress(payload, sliceDefs)
    end

    local function normalizeModules(run, sourceDefs)
        local normalized = Json.array()
        for _, entry in ipairs(run.modules) do
            if type(entry) == "string" then
                local moduleDef = sourceDefs.modulesById[entry]
                normalized[#normalized + 1] = {
                    moduleId = entry,
                    paidGold = moduleDef.price,
                    growth = 0,
                }
            else
                normalized[#normalized + 1] = copy(entry)
            end
        end
        run.modules = normalized
    end

    local function restoreRecordedTowerUnlocks(migrated)
        local meta, run = migrated.metaState, migrated.runState
        meta.unlockedModuleIds = meta.unlockedModuleIds or Json.array()
        local unlocked = {}
        for _, id in ipairs(meta.unlockedTowerIds or {}) do unlocked[id] = true end
        for _, id in ipairs({ "T01", "T02", "T03", "T04" }) do unlocked[id] = true end
        if run.completedWaveIds.W05 == true then unlocked.T05 = true end
        local result = run.result
        if run.phase == "RESULT" and type(result) == "table" and result.kind == "victory"
            and result.waveId == "W15" and result.reason == "boss_killed" and run.hp > 0
            and run.nextWaveIndex == 15 then unlocked.T06 = true end
        local ids = Json.array()
        for id in pairs(unlocked) do ids[#ids + 1] = id end
        table.sort(ids)
        meta.unlockedTowerIds = ids
        return migrated
    end

    local function migrateSlice(payload, context)
        context = context or {}
        local migrated = copy(payload)
        local run = migrated.runState
        local shop = run.shopState
        run.contentVersion = defs.version
        normalizeModules(run, sliceDefs)
        run.developmentComplete = false
        run.frozenUnlockPool = run.frozenUnlockPool or copy(frozenPool)
        run.unlockRunProgress = run.unlockRunProgress or Json.object()
        shop.refundUseCount = shop.refundUseCount or 0
        shop.soldOut = shop.soldOut or {
            tower = shop.offers.tower == nil,
            patch = shop.offers.patch == nil,
            module = shop.offers.module == nil,
        }
        shop.accessOpen = (shop.visitId == "S00" and run.nextWaveIndex == 1
                and (run.phase == "SHOP" or run.phase == "PREPARE"))
            or (shop.visitId == "S01" and run.nextWaveIndex == 4
                and (run.phase == "SHOP" or run.phase == "PREPARE"))
        if shop.rngState == nil then
            local seedSource = table.concat({
                tostring(context.payloadChecksum or ""), run.runId, shop.visitId,
            }, "\0")
            shop.rngState = { algorithm = "park-miller-v1", state = Rng.seedFromString(seedSource) }
        end
        if run.phase == "RESULT" and run.result == nil then
            run.result = {
                kind = "defeat",
                waveId = string.format("W%02d", run.nextWaveIndex),
                tick = 0,
                reason = "legacy-migrated-defeat",
            }
        end
        return restoreRecordedTowerUnlocks(migrated)
    end

    local function migrateRun002(payload)
        local migrated = copy(payload)
        local run = migrated.runState
        run.contentVersion = defs.version
        normalizeModules(run, run002Defs)
        return restoreRecordedTowerUnlocks(migrated)
    end

    local function migrateS24(payload)
        local migrated = copy(payload)
        migrated.runState.contentVersion = defs.version
        return restoreRecordedTowerUnlocks(migrated)
    end

    local function migrateTowerU2(payload)
        local migrated = copy(payload)
        migrated.runState.contentVersion = defs.version
        migrated.metaState.unlockedModuleIds = migrated.metaState.unlockedModuleIds or Json.array()
        return migrated
    end

    return {
        [SLICE_VERSION] = {
            validatePayload = validateSlice,
            migrate = migrateSlice,
        },
        [RUN002_VERSION] = {
            validatePayload = validateRun002,
            migrate = migrateRun002,
        },
        [S24_VERSION] = {
            validatePayload = validateS24,
            migrate = migrateS24,
        },
        [TOWER_U2_VERSION] = { validatePayload = validateTowerU2, migrate = migrateTowerU2 },
        [I28_VERSION] = { validatePayload = validateI28, migrate = migrateTowerU2 },
        [I43_VERSION] = { validatePayload = validateI43, migrate = migrateTowerU2 },
        [I46_VERSION] = { validatePayload = validateI46, migrate = migrateTowerU2 },
        [I41_VERSION] = { validatePayload = validateI41, migrate = migrateTowerU2 },
        [I42_VERSION] = { validatePayload = validateI42, migrate = migrateTowerU2 },
        [I15_VERSION] = { validatePayload = validateI15, migrate = migrateTowerU2 },
        [I14_VERSION] = { validatePayload = validateI14, migrate = migrateTowerU2 },
        [I12_VERSION] = { validatePayload = validateI12, migrate = migrateTowerU2 },
        [I16_VERSION] = { validatePayload = validateI16, migrate = migrateTowerU2 },
    }
end

function Save.adler32(value)
    return adler32(value)
end

function Save.loveSha256(dataApi)
    assert(type(dataApi) == "table" and type(dataApi.hash) == "function"
        and type(dataApi.encode) == "function", "love.data-compatible API required")
    return function(value)
        local raw = dataApi.hash("sha256", value)
        return "sha256:" .. dataApi.encode("string", "hex", raw)
    end
end

function Save.loveFilesystemAdapter(filesystem)
    assert(type(filesystem) == "table" and type(filesystem.read) == "function"
        and type(filesystem.write) == "function", "love.filesystem-compatible API required")
    return {
        read = function(_, path)
            if type(filesystem.getInfo) == "function" and filesystem.getInfo(path) == nil then
                return nil, "not found", "missing"
            end
            local data, errorMessage = filesystem.read(path)
            if data == nil then return nil, errorMessage or "read failed", "error" end
            return data
        end,
        write = function(_, path, data)
            local ok, errorMessage = filesystem.write(path, data)
            if not ok then return nil, errorMessage or "write failed" end
            return true
        end,
    }
end

function Save.new(options)
    options = options or {}
    assert(type(options.storage) == "table", "storage adapter required")
    assert(type(options.storage.read) == "function" and type(options.storage.write) == "function",
        "storage adapter requires read and write")
    assert(type(options.contentVersion) == "string" and options.contentVersion ~= "",
        "contentVersion required")
    assert(type(options.engineTarget) == "string" and options.engineTarget ~= "",
        "engineTarget required")

    return setmetatable({
        storage = options.storage,
        codec = options.codec or Json,
        checksum = options.checksum or adler32,
        checksumName = options.checksumName or (options.checksum and "injected" or "adler32-v1-noncryptographic"),
        contentVersion = options.contentVersion,
        engineTarget = options.engineTarget,
        validatePayload = options.validatePayload or validatePayloadShape,
        migrations = options.migrations or {},
    }, Save)
end

function Save:_readSlot(path)
    local readOk, encoded, readError, readKind = pcall(self.storage.read, self.storage, path)
    if not readOk then
        return { path = path, status = "read_error", error = encoded }
    end
    if encoded == nil then
        return { path = path, status = readKind == "missing" and "missing" or "read_error", error = readError }
    end

    local decodedOk, envelope = pcall(self.codec.decode, encoded)
    if not decodedOk or type(envelope) ~= "table" then
        return { path = path, status = "corrupt", error = decodedOk and "envelope is not an object" or envelope }
    end

    local generation = envelope.generation
    if type(generation) ~= "number" or generation < 1 or generation ~= math.floor(generation) then
        return { path = path, status = "corrupt", error = "invalid generation" }
    end
    if type(envelope.payloadJson) ~= "string" or type(envelope.payloadChecksum) ~= "string"
        or type(envelope.checksumAlgorithm) ~= "string" or envelope.checksumAlgorithm == "" then
        return { path = path, status = "corrupt", generation = generation, error = "invalid payload fields" }
    end

    if envelope.checksumAlgorithm ~= self.checksumName then
        return { path = path, status = "unsupported", generation = generation,
            schemaVersion = envelope.schemaVersion, contentVersion = envelope.contentVersion,
            error = "unsupported checksum algorithm" }
    end

    local checksumOk, actualChecksum = pcall(self.checksum, envelope.payloadJson)
    if not checksumOk or actualChecksum ~= envelope.payloadChecksum then
        return { path = path, status = "corrupt", generation = generation, error = "checksum mismatch" }
    end

    if envelope.schemaVersion ~= 1 then
        return { path = path, status = "unsupported", generation = generation,
            schemaVersion = envelope.schemaVersion, contentVersion = envelope.contentVersion,
            error = "unsupported schema version" }
    end
    if envelope.engineTarget ~= self.engineTarget then
        return { path = path, status = "unsupported", generation = generation,
            schemaVersion = envelope.schemaVersion, contentVersion = envelope.contentVersion,
            error = "unsupported engine target" }
    end

    local payloadOk, payload = pcall(self.codec.decode, envelope.payloadJson)
    if not payloadOk then
        return { path = path, status = "corrupt", generation = generation, error = payload }
    end

    if envelope.contentVersion == self.contentVersion then
        local validationOk, valid, validationError = pcall(self.validatePayload, payload)
        if not validationOk or not valid then
            return { path = path, status = "corrupt", generation = generation,
                error = validationOk and validationError or valid }
        end
        return {
            path = path,
            status = "valid",
            generation = generation,
            envelope = envelope,
            payload = payload,
        }
    end

    local migration = self.migrations[envelope.contentVersion]
    if type(migration) ~= "table" or type(migration.validatePayload) ~= "function"
        or type(migration.migrate) ~= "function" then
        return { path = path, status = "unsupported", generation = generation,
            schemaVersion = envelope.schemaVersion, contentVersion = envelope.contentVersion,
            error = "unsupported content version" }
    end
    if type(payload.runState) ~= "table" or payload.runState.contentVersion ~= envelope.contentVersion then
        return { path = path, status = "corrupt", generation = generation,
            contentVersion = envelope.contentVersion, error = "payload content version does not match envelope" }
    end
    local legacyOk, legacyValid, legacyError = pcall(migration.validatePayload, payload)
    if not legacyOk or not legacyValid then
        return { path = path, status = "corrupt", generation = generation,
            contentVersion = envelope.contentVersion, error = legacyOk and legacyError or legacyValid }
    end
    local migrateOk, migrated, migrationError = pcall(migration.migrate, payload, {
        payloadChecksum = envelope.payloadChecksum,
        generation = generation,
        sourceContentVersion = envelope.contentVersion,
        targetContentVersion = self.contentVersion,
        engineTarget = envelope.engineTarget,
        path = path,
    })
    if not migrateOk or type(migrated) ~= "table" then
        return { path = path, status = "corrupt", generation = generation,
            contentVersion = envelope.contentVersion,
            error = migrateOk and (migrationError or "migration returned no payload") or migrated }
    end
    local currentOk, currentValid, currentError = pcall(self.validatePayload, migrated)
    if not currentOk or not currentValid then
        return { path = path, status = "corrupt", generation = generation,
            contentVersion = envelope.contentVersion,
            error = currentOk and currentError or currentValid }
    end
    return {
        path = path,
        status = "migrated",
        generation = generation,
        envelope = envelope,
        payload = migrated,
        sourcePayload = payload,
        sourceGeneration = generation,
        sourceContentVersion = envelope.contentVersion,
    }
end

function Save:_scan()
    return { self:_readSlot(SLOT_PATHS[1]), self:_readSlot(SLOT_PATHS[2]) }
end

local function newest(records, status)
    local selected
    for _, record in ipairs(records) do
        if record.status == status and (not selected
            or (record.generation or -1) > (selected.generation or -1)) then
            selected = record
        end
    end
    return selected
end

local function newestUsable(records)
    local selected
    for _, record in ipairs(records) do
        if (record.status == "valid" or record.status == "migrated")
            and (not selected or (record.generation or -1) > (selected.generation or -1)) then
            selected = record
        end
    end
    return selected
end

function Save:loadCheckpoint()
    local records = self:_scan()
    local readFailure = newest(records, "read_error")
    if readFailure then
        return { status = "error", path = readFailure.path, error = readFailure.error,
            slots = records }
    end
    local valid = newestUsable(records)
    local unsupported = newest(records, "unsupported")

    if unsupported and (not valid or unsupported.generation >= valid.generation) then
        return {
            status = "unsupported",
            generation = unsupported.generation,
            schemaVersion = unsupported.schemaVersion,
            contentVersion = unsupported.contentVersion,
            error = unsupported.error,
            slots = records,
        }
    end

    if valid then
        local degraded = false
        local issues = {}
        for _, record in ipairs(records) do
            if record.path ~= valid.path and record.status ~= "valid"
                and record.status ~= "migrated" and record.status ~= "missing" then
                degraded = true
                issues[#issues + 1] = { path = record.path, status = record.status, error = record.error,
                    generation = record.generation }
            elseif (record.status == "valid" or record.status == "migrated")
                and record.generation ~= valid.generation then
                -- Two healthy generations are the normal state, not recovery.
            end
        end
        return {
            status = valid.status == "migrated" and "migrated" or (degraded and "recovered" or "valid"),
            generation = valid.generation,
            path = valid.path,
            payload = copy(valid.payload),
            envelope = copy(valid.envelope),
            sourceGeneration = valid.sourceGeneration,
            sourceContentVersion = valid.sourceContentVersion,
            issues = issues,
            slots = records,
        }
    end

    local missingCount = 0
    for _, record in ipairs(records) do
        if record.status == "missing" then missingCount = missingCount + 1 end
    end
    if missingCount == #records then return { status = "missing", slots = records } end
    return { status = "corrupt", slots = records, error = "no valid checkpoint generation" }
end

function Save:prepareCheckpoint(payload)
    local validationOk, valid, validationError = pcall(self.validatePayload, payload)
    if not validationOk or not valid then
        return nil, { status = "failed", error = validationOk and validationError or valid }
    end

    local current = self:loadCheckpoint()
    if current.status == "unsupported" or current.status == "corrupt" or current.status == "error" then
        return nil, { status = current.status, error = current.error, load = current }
    end

    local generation = (current.generation or 0) + 1
    local targetPath
    if current.path == SLOT_PATHS[1] then
        targetPath = SLOT_PATHS[2]
    elseif current.path == SLOT_PATHS[2] then
        targetPath = SLOT_PATHS[1]
    else
        targetPath = SLOT_PATHS[1]
    end

    local encodeOk, payloadJson = pcall(self.codec.encode, payload)
    if not encodeOk then return nil, { status = "failed", error = payloadJson } end
    local checksumOk, payloadChecksum = pcall(self.checksum, payloadJson)
    if not checksumOk or type(payloadChecksum) ~= "string" then
        return nil, { status = "failed", error = checksumOk and "checksum must return a string" or payloadChecksum }
    end

    local envelope = {
        schemaVersion = 1,
        generation = generation,
        contentVersion = self.contentVersion,
        engineTarget = self.engineTarget,
        checksumAlgorithm = self.checksumName,
        payloadJson = payloadJson,
        payloadChecksum = payloadChecksum,
    }
    local envelopeOk, encodedEnvelope = pcall(self.codec.encode, envelope)
    if not envelopeOk then return nil, { status = "failed", error = encodedEnvelope } end

    return {
        generation = generation,
        targetPath = targetPath,
        payload = copy(payload),
        payloadChecksum = payloadChecksum,
        encodedEnvelope = encodedEnvelope,
        checksumName = self.checksumName,
    }
end

function Save:_candidateOnDisk(candidate)
    local record = self:_readSlot(candidate.targetPath)
    if record.status == "valid" and record.generation == candidate.generation
        and record.envelope.payloadChecksum == candidate.payloadChecksum then
        return true, record
    end
    return false, record
end

function Save:commitCandidate(candidate)
    if type(candidate) ~= "table" or type(candidate.encodedEnvelope) ~= "string"
        or type(candidate.targetPath) ~= "string" then
        return { status = "failed", error = "invalid prepared candidate" }
    end

    local writeCallOk, wrote, writeError = pcall(self.storage.write, self.storage,
        candidate.targetPath, candidate.encodedEnvelope)
    if not writeCallOk then
        writeError = wrote
        wrote = nil
    end
    if wrote then
        local committed, record = self:_candidateOnDisk(candidate)
        if committed then
            return { status = "committed", generation = candidate.generation,
                path = candidate.targetPath, payload = copy(record.payload) }
        end
        return { status = "failed", generation = candidate.generation,
            path = candidate.targetPath, error = "readback verification failed", readback = record }
    end

    local committed, record = self:_candidateOnDisk(candidate)
    if committed then
        return { status = "committed", generation = candidate.generation,
            path = candidate.targetPath, payload = copy(record.payload), recoveredAmbiguousWrite = true }
    end
    if record.status == "missing" or record.status == "corrupt" then
        return { status = "failed", generation = candidate.generation,
            path = candidate.targetPath, error = writeError or "write failed", readback = record }
    end
    return { status = "uncertain", generation = candidate.generation,
        path = candidate.targetPath, error = writeError or "write outcome uncertain", readback = record }
end

function Save:commitCheckpoint(payload)
    local candidate, prepareResult = self:prepareCheckpoint(payload)
    if not candidate then return prepareResult end
    return self:commitCandidate(candidate)
end

return Save
