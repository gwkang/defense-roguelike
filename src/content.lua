local Content = {}

local function copy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
        result[copy(key, seen)] = copy(item, seen)
    end
    return result
end

local function mapById(items)
    local result = {}
    for _, item in ipairs(items) do
        result[item.id] = item
    end
    return result
end

local definitions = {
    version = "DR-MOD-I31-r1",
    fixedDt = 1 / 60,
    capabilities = {
        scope = "development-full-run",
        waveRange = { first = 1, last = 15 },
        shopAfterWaveIndices = { 3, 6, 9, 12 },
        resultKinds = { "victory", "defeat" },
        bossRules = true,
        fullModuleCatalog = false,
        implementedTowerCount = 6,
        implementedPatchCount = 9,
        implementedModuleCount = 34,
    },
    maps = {
        {
            id = "M01",
            revision = 1,
            width = 14,
            height = 10,
            exit = { x = 13, y = 5 },
            entrances = {
                { id = "A", routeId = "R_A" },
                { id = "B", routeId = "R_B" },
            },
            routes = {
                {
                    id = "R_A",
                    totalLength = 21,
                    points = {
                        { x = 0, y = 1 }, { x = 4, y = 1 },
                        { x = 4, y = 5 }, { x = 10, y = 5 },
                        { x = 10, y = 7 }, { x = 13, y = 7 },
                        { x = 13, y = 5 },
                    },
                },
                {
                    id = "R_B",
                    totalLength = 20,
                    points = {
                        { x = 0, y = 8 }, { x = 6, y = 8 },
                        { x = 6, y = 5 }, { x = 10, y = 5 },
                        { x = 10, y = 7 }, { x = 13, y = 7 },
                        { x = 13, y = 5 },
                    },
                },
            },
        },
    },
    enemies = {
        { id = "E01", name = "basic", maxHp = 24, speed = 1.00 },
        { id = "E02", name = "fast", maxHp = 12, speed = 1.60 },
        { id = "E03", name = "durable", maxHp = 120, speed = 0.65 },
        { id = "E04", name = "swarm", maxHp = 5, speed = 1.20 },
        {
            id = "E05", name = "boss", maxHp = 1200, speed = 0.60,
            boss = true, speedThresholdRatio = 0.50, speedMultiplier = 1.20,
        },
    },
    towers = {
        {
            id = "T01", name = "basic", tier = "low", price = 6, damage = 12,
            attackRate = 1.0, range = 3.0, projectileSpeed = 12,
            behavior = "single",
        },
        {
            id = "T02", name = "rapid", tier = "mid", price = 9, damage = 5,
            attackRate = 4.0, range = 2.5, projectileSpeed = 16,
            behavior = "single",
        },
        {
            id = "T03", name = "bomb", tier = "mid", price = 9, damage = 18,
            attackRate = 1 / 1.8, range = 3.0, projectileSpeed = 8,
            behavior = "bomb", blastRadius = 0.9,
        },
        {
            id = "T04", name = "cold", tier = "low", price = 6, damage = 3,
            attackRate = 1.0, range = 2.8, projectileSpeed = 12,
            behavior = "cold", slowRatio = 0.25, slowTicks = 90,
        },
        {
            id = "T05", name = "sniper", tier = "high", price = 12, damage = 60,
            attackRate = 1 / 3, range = 5, projectileSpeed = 24,
            behavior = "single",
        },
        {
            id = "T06", name = "electric", tier = "high", price = 12, damage = 14,
            attackRate = 1 / 1.2, range = 3, projectileSpeed = 20,
            behavior = "chain", chainRange = 1.6, chainHops = 2, chainFactor = 0.7,
        },
    },
    patches = {
        { id = "P_DAMAGE", name = "output_boost", tier = "low", price = 4, damage = 0.15, rate = 0, range = 0 },
        { id = "P_RATE", name = "drive_boost", tier = "low", price = 4, damage = 0, rate = 0.15, range = 0 },
        { id = "P_RANGE", name = "aim_boost", tier = "low", price = 4, damage = 0, rate = 0, range = 0.15 },
        { id = "P_OVERLOAD", name = "overload", tier = "mid", price = 7, damage = 0.45, rate = -0.10, range = 0 },
        { id = "P_OVERDRIVE", name = "overdrive", tier = "mid", price = 7, damage = 0, rate = 0.45, range = -0.10 },
        { id = "P_LONG_RANGE", name = "long_range", tier = "mid", price = 7, damage = -0.10, rate = 0, range = 0.45 },
        { id = "P_FOCUSED_BARRAGE", name = "focused_barrage", tier = "high", price = 10, damage = 0.25, rate = 0.25, range = -0.10 },
        { id = "P_CONTINUOUS_AIM", name = "continuous_aim", tier = "high", price = 10, damage = -0.10, rate = 0.25, range = 0.25 },
        { id = "P_HEAVY_AIM", name = "heavy_aim", tier = "high", price = 10, damage = 0.25, rate = -0.10, range = 0.25 },
    },
    modules = {
        { id = "M01", name = "cross_placement", tier = "low", price = 8 },
        { id = "M02", name = "independent_operation", tier = "low", price = 8 },
        { id = "M03", name = "diversity", tier = "mid", price = 12 },
        { id = "M04", name = "single_formation", tier = "mid", price = 12 },
        { id = "M05", name = "distributed_control", tier = "high", price = 16 },
        { id = "M06", name = "compressed_control", tier = "high", price = 16 },
        { id = "M07", name = "same_type_adjacency", tier = "low", price = 8 },
        { id = "M08", name = "dual_system", tier = "mid", price = 12 },
        { id = "M09", name = "completed_form", tier = "mid", price = 12 },
        { id = "M10", name = "unmodified_operation", tier = "low", price = 8 },
        { id = "M11", name = "identical_design", tier = "mid", price = 12 },
        { id = "M13", name = "focused_investment", tier = "mid", price = 12 },
        { id = "M12", name = "balanced_investment", tier = "mid", price = 12 },
        { id = "M14", name = "advanced_maintenance", tier = "mid", price = 12 },
        { id = "M15", name = "mixed_modification", tier = "mid", price = 12 },
        { id = "M16", name = "shared_design", tier = "high", price = 16 },
        { id = "M31", name = "reserve_supply", tier = "mid", price = 12 },
        { id = "M17", name = "cold_vulnerability", tier = "mid", price = 12 },
        { id = "M18", name = "focused_fire", tier = "mid", price = 12 },
        { id = "M25", name = "supply_contract", tier = "low", price = 8 },
        { id = "M26", name = "flawless_contract", tier = "low", price = 8 },
        { id = "M28", name = "deposit", tier = "mid", price = 12 },
        { id = "M41", name = "mid_link", tier = "high", price = 16 },
        { id = "M42", name = "asset_link", tier = "high", price = 16 },
        { id = "M43", name = "spare_circuit", tier = "mid", price = 12 },
        { id = "M46", name = "emergency_output", tier = "mid", price = 12 },
        { id = "M29", name = "parts_refund", tier = "low", price = 8 },
        { id = "M30", name = "exploration_support", tier = "low", price = 8 },
        { id = "M32", name = "austerity_dividend", tier = "mid", price = 12 },
        {
            id = "M33", name = "exploration_learning", tier = "mid", price = 12,
            growthStep = 3, growthCap = 30,
        },
        {
            id = "M34", name = "modification_learning", tier = "mid", price = 12,
            growthStep = 3, growthCap = 30,
        },
        {
            id = "M37", name = "field_learning", tier = "low", price = 8,
            growthStep = 3, growthCap = 30,
        },
        { id = "M44", name = "savings_circuit", tier = "mid", price = 12 },
        { id = "M45", name = "last_stand", tier = "mid", price = 12 },
    },
    waves = {
        {
            id = "W01", index = 1, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E01", count = 8, firstTick = 0, intervalTicks = 84 },
                { groupId = "G02", entranceId = "B", enemyId = "E01", count = 4, firstTick = 480, intervalTicks = 84 },
            },
        },
        {
            id = "W02", index = 2, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E04", count = 12, firstTick = 0, intervalTicks = 24 },
                { groupId = "G02", entranceId = "B", enemyId = "E02", count = 6, firstTick = 180, intervalTicks = 72 },
                { groupId = "G03", entranceId = "A", enemyId = "E01", count = 6, firstTick = 300, intervalTicks = 72 },
            },
        },
        {
            id = "W03", index = 3, mapId = "M01", opensShopAfter = true, shopVisitId = "S01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E03", count = 2, firstTick = 0, intervalTicks = 360 },
                { groupId = "G02", entranceId = "B", enemyId = "E01", count = 8, firstTick = 60, intervalTicks = 54 },
                { groupId = "G03", entranceId = "A", enemyId = "E04", count = 12, firstTick = 360, intervalTicks = 21 },
            },
        },
        {
            id = "W04", index = 4, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E02", count = 8, firstTick = 0, intervalTicks = 54 },
                { groupId = "G02", entranceId = "B", enemyId = "E04", count = 16, firstTick = 120, intervalTicks = 21 },
                { groupId = "G03", entranceId = "A", enemyId = "E01", count = 8, firstTick = 360, intervalTicks = 60 },
            },
        },
        {
            id = "W05", index = 5, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E03", count = 3, firstTick = 0, intervalTicks = 210 },
                { groupId = "G02", entranceId = "B", enemyId = "E02", count = 8, firstTick = 120, intervalTicks = 54 },
                { groupId = "G03", entranceId = "B", enemyId = "E04", count = 16, firstTick = 300, intervalTicks = 18 },
            },
        },
        {
            id = "W06", index = 6, mapId = "M01", opensShopAfter = true, shopVisitId = "S02",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E01", count = 12, firstTick = 0, intervalTicks = 48 },
                { groupId = "G02", entranceId = "B", enemyId = "E03", count = 3, firstTick = 60, intervalTicks = 180 },
                { groupId = "G03", entranceId = "A", enemyId = "E04", count = 20, firstTick = 300, intervalTicks = 15 },
            },
        },
        {
            id = "W07", index = 7, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E02", count = 12, firstTick = 0, intervalTicks = 42 },
                { groupId = "G02", entranceId = "B", enemyId = "E04", count = 24, firstTick = 120, intervalTicks = 15 },
                { groupId = "G03", entranceId = "A", enemyId = "E01", count = 12, firstTick = 300, intervalTicks = 42 },
            },
        },
        {
            id = "W08", index = 8, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E03", count = 4, firstTick = 0, intervalTicks = 132 },
                { groupId = "G02", entranceId = "B", enemyId = "E02", count = 12, firstTick = 120, intervalTicks = 39 },
                { groupId = "G03", entranceId = "B", enemyId = "E01", count = 12, firstTick = 300, intervalTicks = 42 },
            },
        },
        {
            id = "W09", index = 9, mapId = "M01", opensShopAfter = true, shopVisitId = "S03",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E04", count = 30, firstTick = 0, intervalTicks = 12 },
                { groupId = "G02", entranceId = "B", enemyId = "E03", count = 4, firstTick = 60, intervalTicks = 108 },
                { groupId = "G03", entranceId = "A", enemyId = "E02", count = 14, firstTick = 240, intervalTicks = 27 },
                { groupId = "G04", entranceId = "B", enemyId = "E01", count = 10, firstTick = 420, intervalTicks = 42 },
            },
        },
        {
            id = "W10", index = 10, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E01", count = 16, firstTick = 0, intervalTicks = 36 },
                { groupId = "G02", entranceId = "B", enemyId = "E02", count = 16, firstTick = 60, intervalTicks = 27 },
                { groupId = "G03", entranceId = "A", enemyId = "E04", count = 24, firstTick = 180, intervalTicks = 15 },
            },
        },
        {
            id = "W11", index = 11, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E03", count = 5, firstTick = 0, intervalTicks = 90 },
                { groupId = "G02", entranceId = "B", enemyId = "E01", count = 16, firstTick = 120, intervalTicks = 36 },
                { groupId = "G03", entranceId = "A", enemyId = "E04", count = 20, firstTick = 300, intervalTicks = 12 },
            },
        },
        {
            id = "W12", index = 12, mapId = "M01", opensShopAfter = true, shopVisitId = "S04",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E03", count = 6, firstTick = 0, intervalTicks = 72 },
                { groupId = "G02", entranceId = "B", enemyId = "E02", count = 16, firstTick = 60, intervalTicks = 24 },
                { groupId = "G03", entranceId = "A", enemyId = "E04", count = 28, firstTick = 180, intervalTicks = 12 },
                { groupId = "G04", entranceId = "B", enemyId = "E01", count = 12, firstTick = 420, intervalTicks = 36 },
            },
        },
        {
            id = "W13", index = 13, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E02", count = 20, firstTick = 0, intervalTicks = 21 },
                { groupId = "G02", entranceId = "B", enemyId = "E04", count = 40, firstTick = 60, intervalTicks = 9 },
                { groupId = "G03", entranceId = "A", enemyId = "E01", count = 16, firstTick = 300, intervalTicks = 30 },
            },
        },
        {
            id = "W14", index = 14, mapId = "M01",
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E03", count = 8, firstTick = 0, intervalTicks = 48 },
                { groupId = "G02", entranceId = "B", enemyId = "E01", count = 20, firstTick = 60, intervalTicks = 30 },
                { groupId = "G03", entranceId = "A", enemyId = "E02", count = 20, firstTick = 180, intervalTicks = 18 },
                { groupId = "G04", entranceId = "B", enemyId = "E04", count = 32, firstTick = 300, intervalTicks = 9 },
            },
        },
        {
            id = "W15", index = 15, mapId = "M01", bossRequired = true,
            groups = {
                { groupId = "G01", entranceId = "A", enemyId = "E05", count = 1, firstTick = 0, intervalTicks = 60 },
                { groupId = "G02", entranceId = "B", enemyId = "E01", count = 16, firstTick = 60, intervalTicks = 33 },
                { groupId = "G03", entranceId = "A", enemyId = "E04", count = 24, firstTick = 180, intervalTicks = 12 },
                { groupId = "G04", entranceId = "B", enemyId = "E02", count = 12, firstTick = 300, intervalTicks = 24 },
                { groupId = "G05", entranceId = "A", enemyId = "E03", count = 4, firstTick = 240, intervalTicks = 48 },
            },
        },
    },
}

local function appendError(errors, path, message)
    errors[#errors + 1] = { path = path, message = message }
end

local function routeLength(route)
    local length = 0
    for index = 2, #route.points do
        local previous = route.points[index - 1]
        local current = route.points[index]
        length = length + math.abs(current.x - previous.x) + math.abs(current.y - previous.y)
    end
    return length
end

local function validateTiers(errors, path, items)
    local allowed = { low = true, mid = true, high = true }
    for _, item in ipairs(items or {}) do
        if not allowed[item.tier] then
            appendError(errors, path .. "." .. tostring(item.id) .. ".tier", "must be low, mid, or high")
        end
    end
end

function Content.validate(defs)
    local errors = {}
    if type(defs) ~= "table" then
        return { { path = "definitions", message = "must be a table" } }
    end

    local enemies = mapById(defs.enemies or {})
    local maps = mapById(defs.maps or {})
    local towerIds = mapById(defs.towers or {})
    local patchIds = mapById(defs.patches or {})
    local moduleIds = mapById(defs.modules or {})
    if next(towerIds) == nil then appendError(errors, "towers", "at least one tower is required") end
    if next(patchIds) == nil then appendError(errors, "patches", "at least one patch is required") end
    if next(moduleIds) == nil then appendError(errors, "modules", "at least one module is required") end
    validateTiers(errors, "towers", defs.towers)
    validateTiers(errors, "patches", defs.patches)
    validateTiers(errors, "modules", defs.modules)

    for _, map in ipairs(defs.maps or {}) do
        local routeIds = {}
        for _, route in ipairs(map.routes or {}) do
            local path = "maps." .. tostring(map.id) .. ".routes." .. tostring(route.id)
            if routeIds[route.id] then appendError(errors, path, "duplicate route id") end
            routeIds[route.id] = route
            if not route.points or #route.points < 2 then
                appendError(errors, path, "route requires at least two points")
            else
                for pointIndex, point in ipairs(route.points) do
                    if point.x < 0 or point.x >= map.width or point.y < 0 or point.y >= map.height then
                        appendError(errors, path .. ".points." .. pointIndex, "point is outside map bounds")
                    end
                    if pointIndex > 1 then
                        local previous = route.points[pointIndex - 1]
                        if previous.x ~= point.x and previous.y ~= point.y then
                            appendError(errors, path .. ".points." .. pointIndex, "segment must be orthogonal")
                        elseif previous.x == point.x and previous.y == point.y then
                            appendError(errors, path .. ".points." .. pointIndex, "segment must have positive length")
                        end
                    end
                end
                if math.abs(routeLength(route) - route.totalLength) > 1e-9 then
                    appendError(errors, path .. ".totalLength", "does not match point geometry")
                end
                local last = route.points[#route.points]
                if last.x ~= map.exit.x or last.y ~= map.exit.y then
                    appendError(errors, path, "route must end at map exit")
                end
            end
        end
        local entranceIds = {}
        for _, entrance in ipairs(map.entrances or {}) do
            local path = "maps." .. tostring(map.id) .. ".entrances." .. tostring(entrance.id)
            if entranceIds[entrance.id] then appendError(errors, path, "duplicate entrance id") end
            entranceIds[entrance.id] = true
            if not routeIds[entrance.routeId] then appendError(errors, path, "unknown route id") end
        end
    end

    for _, wave in ipairs(defs.waves or {}) do
        local map = maps[wave.mapId]
        local entranceIds = {}
        if map then
            for _, entrance in ipairs(map.entrances or {}) do entranceIds[entrance.id] = true end
        else
            appendError(errors, "waves." .. tostring(wave.id) .. ".mapId", "unknown map id")
        end
        local groupIds = {}
        for _, group in ipairs(wave.groups or {}) do
            local path = "waves." .. tostring(wave.id) .. ".groups." .. tostring(group.groupId)
            if groupIds[group.groupId] then appendError(errors, path, "duplicate group id") end
            groupIds[group.groupId] = true
            if not entranceIds[group.entranceId] then appendError(errors, path, "unknown entrance id") end
            if not enemies[group.enemyId] then appendError(errors, path, "unknown enemy id") end
            if type(group.count) ~= "number" or group.count <= 0 or group.count % 1 ~= 0 then
                appendError(errors, path .. ".count", "must be a positive integer")
            end
            if type(group.firstTick) ~= "number" or group.firstTick < 0 or group.firstTick % 1 ~= 0 then
                appendError(errors, path .. ".firstTick", "must be a non-negative integer")
            end
            if type(group.intervalTicks) ~= "number" or group.intervalTicks <= 0 or group.intervalTicks % 1 ~= 0 then
                appendError(errors, path .. ".intervalTicks", "must be a positive integer")
            end
        end
    end
    return errors
end

function Content.create()
    local result = copy(definitions)
    result.mapsById = mapById(result.maps)
    result.enemiesById = mapById(result.enemies)
    result.towersById = mapById(result.towers)
    result.patchesById = mapById(result.patches)
    result.modulesById = mapById(result.modules)
    result.wavesById = mapById(result.waves)
    return result
end

function Content.clone(value)
    return copy(value)
end

return Content
