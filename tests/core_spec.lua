package.path = "./?.lua;./?/init.lua;" .. package.path

local Content = require("src.content")
local Rules = require("src.rules")
local Battle = require("src.battle")
local Shop = require("src.shop")

local tests = {}

local function test(name, body)
    tests[#tests + 1] = { name = name, body = body }
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function close(actual, expected, tolerance, message)
    if math.abs(actual - expected) > tolerance then
        error((message or "values are not close") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function containsEvent(events, eventType, predicate)
    for _, event in ipairs(events) do
        if event.type == eventType and (not predicate or predicate(event)) then return event end
    end
    return nil
end

local function oneTowerRun(defs, typeId, x, y, patchIds, modules)
    local run = Rules.newRun(defs, { modules = modules or {} })
    run.towerInstances = {
        {
            instanceId = 1, typeId = typeId, paidGold = 0,
            patchIds = patchIds or {}, placement = x and { x = x, y = y } or nil,
            charge = 0, activated = x ~= nil,
        },
    }
    run.nextInstanceId = 2
    return run
end

test("content validates full-run data while preserving W01-W03", function()
    local defs = Content.create()
    equal(#Content.validate(defs), 0)
    equal(Rules.newRun(defs).contentVersion, defs.version)
    local defaultIds = require("src.game").defaultUnlockPool(defs).moduleIds
    equal(#defaultIds, 24)
    local covered = {}
    for _, id in ipairs(defaultIds) do equal(covered[id], nil); covered[id] = true end
    local earnedIds = { "M12", "M14", "M15", "M16", "M31", "M28", "M41", "M42", "M43", "M46" }
    for _, id in ipairs(earnedIds) do
        equal(covered[id], nil); equal(defs.modulesById[id].id, id); covered[id] = true
    end
    for _, moduleDef in ipairs(defs.modules) do equal(covered[moduleDef.id], true) end
    equal(#defs.modules, #defaultIds + #earnedIds)
    equal(defs.capabilities.implementedModuleCount, #defaultIds + #earnedIds)
    equal(defs.capabilities.waveRange.last, 15)
    equal(defs.capabilities.fullModuleCatalog, false)
    equal(defs.mapsById.M01.routes[1].totalLength, 21)
    equal(defs.mapsById.M01.routes[2].totalLength, 20)
    equal(#defs.wavesById.W01.groups, 2)
    local totals, hitPoints = {}, {}
    for _, wave in ipairs(defs.waves) do
        local count, hp = 0, 0
        for _, group in ipairs(wave.groups) do
            count = count + group.count
            hp = hp + group.count * defs.enemiesById[group.enemyId].maxHp
        end
        totals[wave.id] = count
        hitPoints[wave.id] = hp
    end
    local expectedCounts = { 12, 24, 22, 32, 27, 35, 48, 28, 58, 56, 41, 62, 76, 80, 57 }
    local expectedHp = { 288, 276, 492, 368, 536, 748, 552, 912, 1038, 696, 1084, 1340, 824, 1840, 2328 }
    for index = 1, 15 do
        local waveId = string.format("W%02d", index)
        equal(totals[waveId], expectedCounts[index], waveId .. " count")
        equal(hitPoints[waveId], expectedHp[index], waveId .. " hp")
    end
    equal(defs.wavesById.W01.groups[1].intervalTicks, 84)
    equal(defs.wavesById.W02.groups[2].firstTick, 180)
    equal(defs.wavesById.W03.groups[3].intervalTicks, 21)
    local expectedEarlyGroups = {
        W01 = { "G01:A:E01:8:0:84", "G02:B:E01:4:480:84" },
        W02 = { "G01:A:E04:12:0:24", "G02:B:E02:6:180:72", "G03:A:E01:6:300:72" },
        W03 = { "G01:A:E03:2:0:360", "G02:B:E01:8:60:54", "G03:A:E04:12:360:21" },
    }
    for waveId, expected in pairs(expectedEarlyGroups) do
        for index, group in ipairs(defs.wavesById[waveId].groups) do
            local signature = table.concat({
                group.groupId, group.entranceId, group.enemyId, group.count,
                group.firstTick, group.intervalTicks,
            }, ":")
            equal(signature, expected[index], waveId .. " group " .. index .. " changed")
        end
    end
    equal(defs.enemiesById.E05.boss, true)
    equal(defs.enemiesById.E05.speedThresholdRatio, 0.5)
    equal(defs.towersById.T01.tier, "low")
    equal(defs.patchesById.P_OVERLOAD.tier, "mid")
    equal(defs.modulesById.M05.tier, "high")

    local synthetic = Content.create()
    local map = synthetic.mapsById.M01
    map.routes[#map.routes + 1] = {
        id = "R_C", totalLength = 15,
        points = { { x = 0, y = 3 }, { x = 13, y = 3 }, { x = 13, y = 5 } },
    }
    map.entrances[#map.entrances + 1] = { id = "C", routeId = "R_C" }
    equal(#Content.validate(synthetic), 0, "entrance count must be data driven")
end)

test("battle spawn logs use wave ticks and group order", function()
    local defs = Content.create()
    local expectedCounts = { W01 = 12, W02 = 24, W03 = 22 }
    for _, waveId in ipairs({ "W01", "W02", "W03" }) do
        local run = Rules.newRun(defs)
        run.towerInstances = {}
        run.hp = 1000
        local state = assert(Battle.new(defs, run, waveId))
        local spawned = {}
        while not state.result do
            local events = assert(Battle.step(state, Battle.FIXED_DT))
            for _, event in ipairs(events) do
                if event.type == "enemy_spawned" then spawned[#spawned + 1] = event end
            end
        end
        equal(#spawned, expectedCounts[waveId])
        equal(state.observations.spawned, expectedCounts[waveId])
        if waveId == "W03" then
            local at360 = {}
            for _, event in ipairs(spawned) do
                if event.tick == 360 then at360[#at360 + 1] = event.groupId end
            end
            equal(#at360, 2)
            equal(at360[1], "G01")
            equal(at360[2], "G03")
        end
    end
end)

test("placement rejects path, occupancy, capacity, and combat movement atomically", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    local candidate, _, reason = Rules.tryPlaceTower(defs, run, "M01", 1, 0, 1, "prepare")
    equal(candidate, nil)
    equal(reason, "path_cell")
    equal(run.towerInstances[1].placement, nil, "rejected placement mutated source")

    candidate = assert(Rules.tryPlaceTower(defs, run, "M01", 1, 3, 2, "prepare"))
    local occupied, _, occupiedReason = Rules.tryPlaceTower(defs, candidate, "M01", 2, 3, 2, "prepare")
    equal(occupied, nil)
    equal(occupiedReason, "occupied_cell")
    local moved, _, moveReason = Rules.tryPlaceTower(defs, candidate, "M01", 1, 3, 3, "combat")
    equal(moved, nil)
    equal(moveReason, "combat_move_forbidden")

    candidate.baseTowerCapacity = 1
    local capped, _, capReason = Rules.tryPlaceTower(defs, candidate, "M01", 2, 5, 4, "prepare")
    equal(capped, nil)
    equal(capReason, "tower_capacity")
end)

test("patches and fixture modules project deterministic stats", function()
    local defs = Content.create()
    equal(#defs.patches, 9)
    local run = oneTowerRun(defs, "T01", 3, 2, { "P_OVERLOAD", "P_RATE" }, { "M02", "M05" })
    local stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.damage, 12 * 1.45 * 1.10, 1e-9)
    close(stats.attackRate, 1.05, 1e-9)
    equal(Rules.towerCapacity(run), 8)

    run.towerInstances[#run.towerInstances + 1] = {
        instanceId = 2, typeId = "T02", paidGold = 0, patchIds = {},
        placement = { x = 4, y = 2 }, charge = 0, activated = true,
    }
    run.modules[#run.modules + 1] = "M01"
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.attackRate, 1.20 * 1.05, 1e-9, "M01 applies once for a different cardinal neighbor")
    close(stats.damage, 12 * 1.45 * 0.80, 1e-9, "M02 deactivates when a neighbor exists")
end)

test("purchase failures do not mutate source and patch cap is three", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.gold = 3
    local candidate, _, reason = Rules.tryPurchasePatch(defs, run, 1, "P_DAMAGE")
    equal(candidate, nil)
    equal(reason, "insufficient_gold")
    equal(run.gold, 3)
    equal(#run.towerInstances[1].patchIds, 0)

    run.gold = 100
    for _ = 1, 3 do run = assert(Rules.tryPurchasePatch(defs, run, 1, "P_DAMAGE")) end
    candidate, _, reason = Rules.tryPurchasePatch(defs, run, 1, "P_DAMAGE")
    equal(candidate, nil)
    equal(reason, "patch_limit")
end)

test("tower sale preview is inert and commit refunds paid gold while destroying patches", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.gold = 10
    run.nextInstanceId = 4
    run.towerInstances[#run.towerInstances + 1] = {
        instanceId = 3, typeId = "T02", paidGold = 9,
        patchIds = { "P_DAMAGE", "P_RATE" }, placement = { x = 3, y = 2 },
        charge = 0.75, activated = true,
    }
    run.shopState = { offers = { tower = "T03" }, rngState = { algorithm = "park-miller-v1", state = 123 } }

    local preview = assert(Rules.previewInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_tower", instanceId = 3,
    }))
    equal(preview.refundGold, 4)
    equal(preview.patchCount, 2)
    equal(preview.goldBefore, 10)
    equal(preview.goldAfter, 14)
    equal(preview.requiredRecallCount, 0)
    equal(#run.towerInstances, 3, "preview mutated source towers")
    equal(run.gold, 10, "preview mutated source gold")

    local sold, events = assert(Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_tower", instanceId = 3,
    }))
    equal(#sold.towerInstances, 2)
    equal(sold.gold, 14)
    equal(sold.nextInstanceId, 4, "sold instance ids must not be reused")
    equal(events[1].type, "tower_sold")
    equal(events[1].refundGold, 4)
    equal(events[1].patchCount, 2)
    equal(sold.shopState.offers.tower, "T03")
    equal(sold.shopState.rngState.state, 123)
    equal(#run.towerInstances, 3, "commit mutated source towers")

    local free, freeEvents = assert(Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_tower", instanceId = 1,
    }))
    equal(free.gold, 10)
    equal(freeEvents[1].refundGold, 0)
end)

test("module sale removes growth but retains acquired exclusion and supports legacy paid price", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.gold = 7
    run.modules = { { moduleId = "M01", paidGold = 8, growth = 5 } }
    run.shopState = { offers = { module = "M02" }, rngState = { algorithm = "park-miller-v1", state = 456 } }
    local sold, events = assert(Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M01",
    }))
    equal(sold.gold, 11)
    equal(#sold.modules, 0)
    equal(sold.acquiredModuleIds.M01, true)
    equal(events[1].type, "module_sold")
    equal(events[1].paidGold, 8)
    equal(events[1].refundGold, 4)
    equal(events[1].growth, 5)
    equal(sold.shopState.offers.module, "M02")
    equal(sold.shopState.rngState.state, 456)
    equal(#run.modules, 1, "module sale mutated source")
    equal(run.acquiredModuleIds.M01, nil)

    local legacy = Rules.newRun(defs, { modules = { "M17" }, acquiredModuleIds = { M17 = true } })
    local legacySold, legacyEvents = assert(Rules.tryInventoryTransaction(defs, legacy, {
        phase = "SHOP", kind = "sell_module", moduleId = "M17",
    }))
    equal(legacySold.gold, 18)
    equal(legacyEvents[1].paidGold, 12)
    equal(legacyEvents[1].refundGold, 6)

    local rejected, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "PREPARE", kind = "sell_module", moduleId = "M01",
    })
    equal(rejected, nil)
    equal(reason, "shop_required")
end)

test("manual recall is limited to SHOP or PREPARE and preserves tower identity state", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T02", 3, 2, { "P_DAMAGE" })
    local tower = run.towerInstances[1]
    tower.paidGold = 9
    tower.charge = 0.75
    tower.activated = true
    local recalled, events = assert(Rules.tryInventoryTransaction(defs, run, {
        phase = "PREPARE", kind = "recall_tower", instanceId = 1,
    }))
    equal(recalled.towerInstances[1].placement, nil)
    equal(recalled.towerInstances[1].instanceId, 1)
    equal(recalled.towerInstances[1].paidGold, 9)
    equal(recalled.towerInstances[1].patchIds[1], "P_DAMAGE")
    close(recalled.towerInstances[1].charge, 0.75, 1e-9)
    equal(recalled.towerInstances[1].activated, true)
    equal(events[1].type, "tower_recalled")
    equal(events[1].reason, "manual")
    assert(run.towerInstances[1].placement, "recall mutated source")

    local combat, _, combatReason = Rules.tryInventoryTransaction(defs, run, {
        phase = "COMBAT", kind = "recall_tower", instanceId = 1,
    })
    equal(combat, nil)
    equal(combatReason, "combat_recall_forbidden")
    local again, _, againReason = Rules.tryInventoryTransaction(defs, recalled, {
        phase = "SHOP", kind = "recall_tower", instanceId = 1,
    })
    equal(again, nil)
    equal(againReason, "tower_not_placed")
end)

test("inventory transaction rejects unknown targets and invalid phases without mutation", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    local beforeGold, beforeTowerCount = run.gold, #run.towerInstances
    local candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_tower", instanceId = 99,
    })
    equal(candidate, nil)
    equal(reason, "unknown_tower")
    candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M01",
    })
    equal(candidate, nil)
    equal(reason, "unknown_module")
    candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "PREPARE", kind = "sell_tower", instanceId = 1,
    })
    equal(candidate, nil)
    equal(reason, "shop_required")
    candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "TITLE", kind = "recall_tower", instanceId = 1,
    })
    equal(candidate, nil)
    equal(reason, "recall_phase_required")
    candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "unknown", instanceId = 1,
    })
    equal(candidate, nil)
    equal(reason, "unknown_transaction_kind")
    equal(run.gold, beforeGold)
    equal(#run.towerInstances, beforeTowerCount)
end)

local function capacityFixture(defs)
    local run = Rules.newRun(defs, {
        modules = { { moduleId = "M05", paidGold = 16, growth = 0 } },
        acquiredModuleIds = { M05 = true },
    })
    run.gold = 3
    run.towerInstances = {}
    for instanceId = 1, 9 do
        run.towerInstances[#run.towerInstances + 1] = {
            instanceId = instanceId, typeId = "T01", paidGold = 6, patchIds = {},
            placement = instanceId <= 8 and { x = instanceId, y = 0 } or nil,
            charge = instanceId / 10, activated = true,
        }
    end
    run.nextInstanceId = 10
    run.shopState = { offers = { module = nil }, rngState = { algorithm = "park-miller-v1", state = 789 } }
    return run
end

test("capacity shrink requires exact unique placed recalls and emits sorted recalls before sale", function()
    local defs = Content.create()
    local run = capacityFixture(defs)
    local preview = assert(Rules.previewInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M05",
    }))
    equal(preview.towerCapacityBefore, 8)
    equal(preview.towerCapacityAfter, 6)
    equal(preview.placedTowerCountAfter, 8)
    equal(preview.requiredRecallCount, 2)
    equal(preview.canCommit, false)
    equal(#preview.eligibleRecallTowerIds, 8)
    equal(#run.modules, 1, "preview removed source module")

    local candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M05",
    })
    equal(candidate, nil)
    equal(reason, "recall_selection_required")
    candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M05", recallTowerIds = { 1 },
    })
    equal(candidate, nil)
    equal(reason, "recall_count_mismatch")
    candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M05", recallTowerIds = { 1, 1 },
    })
    equal(candidate, nil)
    equal(reason, "duplicate_recall_target")
    candidate, _, reason = Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M05", recallTowerIds = { 1, 9 },
    })
    equal(candidate, nil)
    equal(reason, "recall_target_not_placed")

    local sold, events = assert(Rules.tryInventoryTransaction(defs, run, {
        phase = "SHOP", kind = "sell_module", moduleId = "M05", recallTowerIds = { 6, 2 },
    }))
    equal(Rules.towerCapacity(sold), 6)
    equal(#sold.modules, 0)
    equal(sold.gold, 11)
    equal(sold.acquiredModuleIds.M05, true)
    equal(events[1].type, "tower_recalled")
    equal(events[1].instanceId, 2)
    equal(events[1].reason, "capacity_adjustment")
    equal(events[2].type, "tower_recalled")
    equal(events[2].instanceId, 6)
    equal(events[3].type, "module_sold")
    equal(events[3].refundGold, 8)
    equal(sold.towerInstances[2].placement, nil)
    equal(sold.towerInstances[6].placement, nil)
    assert(run.towerInstances[2].placement and run.towerInstances[6].placement,
        "capacity transaction mutated source placements")
    equal(#run.modules, 1)
    equal(run.gold, 3)
    equal(sold.shopState.rngState.state, 789)
end)

test("capacity evaluator is direction-agnostic and rejects module-slot overflow", function()
    local defs = Content.create()
    local before = Rules.newRun(defs)
    before.towerInstances = {}
    for instanceId = 1, 6 do
        before.towerInstances[#before.towerInstances + 1] = {
            instanceId = instanceId, typeId = "T01", paidGold = 0, patchIds = {},
            placement = { x = instanceId, y = 0 }, charge = 0, activated = true,
        }
    end
    local proposed = Content.clone(before)
    proposed.baseTowerCapacity = 4
    local preview = assert(Rules.evaluateCapacityTransition(before, proposed, nil))
    equal(preview.requiredRecallCount, 2)
    local selected = assert(Rules.evaluateCapacityTransition(before, proposed, { 5, 2 }))
    equal(selected.selectedRecallTowerIds[1], 2)
    equal(selected.selectedRecallTowerIds[2], 5)

    proposed.modules = {
        "M01", "M02", "M05", "M17", "M25",
    }
    local invalid, reason = Rules.evaluateCapacityTransition(before, proposed, nil)
    equal(invalid, nil)
    equal(reason, "module_slots")
end)

test("route movement consumes corners and target choice uses remaining route", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T01", 7, 6)
    local state = assert(Battle.new(defs, run, "W01"))
    state.enemies = {
        { enemyId = 1, typeId = "E01", routeId = "R_A", s = 10, totalLength = 21, hp = 24, maxHp = 24, baseSpeed = 1, spawnOrdinal = 1, spawnTick = 0, alive = true },
        { enemyId = 2, typeId = "E01", routeId = "R_B", s = 10, totalLength = 20, hp = 24, maxHp = 24, baseSpeed = 1, spawnOrdinal = 2, spawnTick = 0, alive = true },
    }
    state.enemyById = { [1] = state.enemies[1], [2] = state.enemies[2] }
    state.spawnSchedule = {}
    state.nextSpawnIndex = 1
    local x, y = Battle.routePosition(defs.mapsById.M01.routes[1], 6)
    close(x, 4, 1e-9)
    close(y, 3, 1e-9)
    local target = Battle.selectTarget(state, state.towers[1], assert(Rules.projectStats(defs, state.run, 1)))
    equal(target.enemyId, 2, "shorter remaining route wins despite later spawn")

    state.enemies[2].s = 9
    target = Battle.selectTarget(state, state.towers[1], assert(Rules.projectStats(defs, state.run, 1)))
    equal(target.enemyId, 1, "remaining-distance tie uses spawn ordinal")
end)

test("4.6 attacks per second preserves fractional charge for 276 shots", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T02", 0, 2, { "P_RATE" })
    local state = assert(Battle.new(defs, run, "W01"))
    state.enemies[1].hp = 1000000000
    state.enemies[1].maxHp = 1000000000
    state.enemies[1].baseSpeed = 0
    for _ = 1, 3600 do
        local _, err = Battle.step(state, Battle.FIXED_DT)
        equal(err, nil)
    end
    equal(state.observations.shots, 276)
    close(state.towers[1].charge, 0, 1e-7)
end)

test("no-target charge caps at one and prepare recall preserves charge", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T02", 13, 0)
    local state = assert(Battle.new(defs, run, "W01"))
    for _ = 1, 60 do assert(Battle.step(state, Battle.FIXED_DT)) end
    close(state.towers[1].charge, 1, 1e-9)
    local recalled = assert(Rules.tryRecallTower(state.run, 1, "prepare"))
    close(recalled.towerInstances[1].charge, 1, 1e-9)
    local placed = assert(Rules.tryPlaceTower(defs, recalled, "M01", 1, 12, 4, "prepare"))
    close(placed.towerInstances[1].charge, 1, 1e-9)
end)

test("cold applies after its own damage and M17 boosts a later basic hit", function()
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = { "M17" } })
    run.towerInstances = {
        { instanceId = 1, typeId = "T04", paidGold = 0, patchIds = {}, placement = { x = 0, y = 2 }, charge = 0, activated = true },
        { instanceId = 2, typeId = "T01", paidGold = 0, patchIds = {}, placement = { x = 1, y = 2 }, charge = 0, activated = true },
    }
    local state = assert(Battle.new(defs, run, "W01"))
    state.enemies[1].hp = 1000
    state.enemies[1].maxHp = 1000
    state.enemies[1].baseSpeed = 0
    state.spawnSchedule = { state.spawnSchedule[1] }
    state.nextSpawnIndex = 2
    local damageEvents = {}
    for _ = 1, 75 do
        local events = assert(Battle.step(state, Battle.FIXED_DT))
        for _, event in ipairs(events) do
            if event.type == "enemy_damaged" then damageEvents[#damageEvents + 1] = event end
        end
    end
    local cold, basic
    for _, event in ipairs(damageEvents) do
        if event.sourceTowerId == 1 then cold = cold or event end
        if event.sourceTowerId == 2 then basic = basic or event end
    end
    close(cold.damage, 3, 1e-9, "first cold hit must not self-enable M17")
    close(basic.damage, 15.6, 1e-9, "later basic hit reads current slow state")
end)

test("bomb damages the primary first and every alive enemy inside radius", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T03", 0, 2)
    run.towerInstances[1].charge = 1
    local state = assert(Battle.new(defs, run, "W01"))
    local first = state.enemies[1]
    first.hp, first.maxHp, first.baseSpeed = 100, 100, 0
    local second = Content.clone(first)
    second.enemyId = 2
    second.spawnOrdinal = 2
    second.s = 0.5
    state.enemies[#state.enemies + 1] = second
    state.enemyById[2] = second
    state.spawnSchedule = { state.spawnSchedule[1] }
    state.nextSpawnIndex = 2
    local hits = {}
    for _ = 1, 20 do
        local events = assert(Battle.step(state, Battle.FIXED_DT))
        for _, event in ipairs(events) do
            if event.type == "enemy_damaged" then hits[#hits + 1] = event end
        end
    end
    equal(#hits, 2)
    equal(hits[1].hitKind, "primary")
    equal(hits[2].hitKind, "blast")
    close(hits[1].damage, 18, 1e-9)
    close(hits[2].damage, 18, 1e-9)
    assert(first.lastHitTickByTowerType.T03, "bomb primary hit was not recorded")
    assert(second.lastHitTickByTowerType.T03, "bomb blast hit was not recorded")
end)

test("a projectile whose target dies expires instead of retargeting", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T01", 0, 2)
    local state = assert(Battle.new(defs, run, "W01"))
    state.projectiles = {
        { projectileId = 1, sourceTowerTypeId = "T01", targetId = 1,
            x = 0, y = 2, speed = 12, launchBaseDamage = 12, behavior = "single" },
    }
    state.enemies[1].alive = false
    state.nextProjectileId = 2
    local events = assert(Battle.step(state, Battle.FIXED_DT))
    local expired = containsEvent(events, "projectile_expired", function(event)
        return event.projectileId == 1 and event.reason == "target_missing"
    end)
    assert(expired, "missing target expiration event")
    equal(next(state.enemies[1].lastHitTickByTowerType), nil,
        "expired projectile must not create hit history")
    local snapshot = Battle.snapshot(state)
    snapshot.towerInstances[1].charge = 99
    assert(state.towers[1].charge ~= 99, "view snapshot exposed mutable battle internals")
end)

test("leaks complete W01 once, while hp zero defeats once", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.towerInstances = {}
    run.hp = 100
    local state = assert(Battle.new(defs, run, "W01"))
    local completionCount = 0
    while not state.result do
        local events = assert(Battle.step(state, Battle.FIXED_DT))
        for _, event in ipairs(events) do if event.type == "wave_completed" then completionCount = completionCount + 1 end end
    end
    equal(state.result.kind, "wave_complete")
    equal(state.tick, 1932)
    equal(state.observations.leaks, 12)
    equal(completionCount, 1)

    run.hp = 1
    local defeated = assert(Battle.new(defs, run, "W01"))
    local defeatCount = 0
    while not defeated.result do
        local events = assert(Battle.step(defeated, Battle.FIXED_DT))
        for _, event in ipairs(events) do if event.type == "battle_defeated" then defeatCount = defeatCount + 1 end end
    end
    equal(defeated.result.kind, "defeat")
    equal(defeatCount, 1)
    local events, err = Battle.step(defeated, Battle.FIXED_DT)
    equal(#events, 0)
    equal(err, "battle_finished")
end)

test("same-tick ordinary leaks clamp hp at zero for result persistence", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.hp = 1
    run.towerInstances = {}
    local state = assert(Battle.new(defs, run, "W01"))
    local first = state.enemies[1]
    first.s = first.totalLength
    first.baseSpeed = 0
    local second = Content.clone(first)
    second.enemyId = 2
    second.spawnOrdinal = 2
    state.enemies = { first, second }
    state.enemyById = { [1] = first, [2] = second }
    state.spawnSchedule = {}
    state.nextSpawnIndex = 1

    local events = assert(Battle.step(state, Battle.FIXED_DT))
    equal(state.result.kind, "defeat")
    equal(state.result.reason, "hp_zero")
    equal(state.hp, 0, "battle hp must remain valid after multiple same-tick leaks")
    equal(Battle.summary(state).hp, 0)
    local reduced = assert(Rules.reduceCompletion(defs, run, Battle.summary(state)))
    equal(reduced.hp, 0, "persisted result hp must satisfy the current save validator")
    local leakCount, defeatCount = 0, 0
    for _, event in ipairs(events) do
        if event.type == "enemy_leaked" then leakCount = leakCount + 1 end
        if event.type == "battle_defeated" then defeatCount = defeatCount + 1 end
    end
    equal(leakCount, 2)
    equal(defeatCount, 1)
end)

test("completion reward includes M25/M26 and is idempotent", function()
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = { "M25", "M26" } })
    local summary = {
        waveId = "W03", resultKind = "wave_complete", hp = 20,
        leaks = 0, towerInstances = Content.clone(run.towerInstances),
    }
    local completed, events = assert(Rules.reduceCompletion(defs, run, summary))
    equal(completed.gold, 31)
    equal(events[1].reward.total, 19)
    local duplicate, duplicateEvents = assert(Rules.reduceCompletion(defs, completed, summary))
    equal(duplicate.gold, 31)
    equal(duplicateEvents[1].type, "completion_duplicate")
end)

test("section reward applies only to ordinary W3 W6 W9 W12 completions", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    for _, index in ipairs({ 3, 6, 9, 12 }) do
        equal(Rules.completionReward(run, index, 1).section, 6, "section reward at wave " .. index)
    end
    for _, index in ipairs({ 1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 15 }) do
        equal(Rules.completionReward(run, index, 1).section, 0, "no section reward at wave " .. index)
    end
end)

test("acquired module cannot be bought again when no longer installed", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.gold = 100
    run.acquiredModuleIds.M01 = true
    local candidate, _, reason = Rules.tryPurchaseModule(defs, run, "M01")
    equal(candidate, nil)
    equal(reason, "duplicate_module")
    equal(run.gold, 100)
end)

test("boss speed boost begins strictly below half hp on the next movement tick", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.towerInstances = {}
    local state = assert(Battle.new(defs, run, "W15"))
    state.spawnSchedule = { state.spawnSchedule[1] }
    state.nextSpawnIndex = 2
    local boss = state.enemies[1]
    boss.hp = 600
    local before = boss.s
    assert(Battle.step(state, Battle.FIXED_DT))
    close(boss.s - before, 0.60 / 60, 1e-9)
    boss.hp = 599
    before = boss.s
    assert(Battle.step(state, Battle.FIXED_DT))
    close(boss.s - before, 0.60 * 1.20 / 60, 1e-9)
    equal(state.result, nil, "spawn exhaustion must not complete W15 while boss lives")
end)

local function makeDueProjectile(projectileId, enemy, damage)
    return {
        projectileId = projectileId,
        sourceTowerId = 99,
        sourceTowerTypeId = "T01",
        targetId = enemy.enemyId,
        x = 0, y = 1, speed = 120,
        launchBaseDamage = damage,
        launchAttackId = projectileId,
        sourceKind = "normal", behavior = "single",
    }
end

test("M18 records actual hits after damage and uses projectile order within one tick", function()
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = { "M18" } })
    run.towerInstances = {}
    local state = assert(Battle.new(defs, run, "W01"))
    state.spawnSchedule = { state.spawnSchedule[1] }
    state.nextSpawnIndex = 2
    local enemy = state.enemies[1]
    enemy.hp, enemy.maxHp, enemy.baseSpeed = 1000, 1000, 0
    local first = makeDueProjectile(1, enemy, 10)
    first.sourceTowerTypeId = "T01"
    local second = makeDueProjectile(2, enemy, 10)
    second.sourceTowerTypeId = "T02"
    local third = makeDueProjectile(3, enemy, 10)
    third.sourceTowerTypeId = "T01"
    state.projectiles = { third, first, second }
    state.nextProjectileId = 4

    local events = assert(Battle.step(state, Battle.FIXED_DT))
    local damages = {}
    for _, event in ipairs(events) do
        if event.type == "enemy_damaged" then damages[#damages + 1] = event.damage end
    end
    equal(#damages, 3)
    close(damages[1], 10, 1e-9)
    close(damages[2], 10, 1e-9,
        "the second distinct type is recorded only after its own damage")
    close(damages[3], 12.5, 1e-9,
        "the later same-tick hit sees two previously recorded types")
    equal(enemy.lastHitTickByTowerType.T01, 1)
    equal(enemy.lastHitTickByTowerType.T02, 1)
end)

test("M18 battle history includes tick 120 excludes 121 and resets with a new battle", function()
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = { "M18" } })
    run.towerInstances = {}

    local included = assert(Battle.new(defs, run, "W01"))
    included.spawnSchedule = { included.spawnSchedule[1] }
    included.nextSpawnIndex = 2
    included.tick = 120
    included.enemies[1].hp, included.enemies[1].maxHp, included.enemies[1].baseSpeed = 100, 100, 0
    included.enemies[1].lastHitTickByTowerType = { T01 = 1, T02 = 2 }
    local shot = makeDueProjectile(1, included.enemies[1], 8)
    shot.sourceTowerTypeId = "T03"
    included.projectiles = { shot }
    local includedEvents = assert(Battle.step(included, Battle.FIXED_DT))
    local includedDamage = assert(containsEvent(includedEvents, "enemy_damaged"))
    close(includedDamage.damage, 10, 1e-9, "a hit exactly 120 ticks old remains active")

    local excluded = assert(Battle.new(defs, run, "W01"))
    excluded.spawnSchedule = { excluded.spawnSchedule[1] }
    excluded.nextSpawnIndex = 2
    excluded.tick = 120
    excluded.enemies[1].hp, excluded.enemies[1].maxHp, excluded.enemies[1].baseSpeed = 100, 100, 0
    excluded.enemies[1].lastHitTickByTowerType = { T01 = 0, T02 = 2 }
    shot = makeDueProjectile(1, excluded.enemies[1], 8)
    shot.sourceTowerTypeId = "T03"
    excluded.projectiles = { shot }
    local excludedEvents = assert(Battle.step(excluded, Battle.FIXED_DT))
    local excludedDamage = assert(containsEvent(excludedEvents, "enemy_damaged"))
    close(excludedDamage.damage, 8, 1e-9, "a hit 121 ticks old is excluded")

    local reset = assert(Battle.new(defs, run, "W01"))
    equal(next(reset.enemies[1].lastHitTickByTowerType), nil,
        "combat start must not restore transient hit history")
end)

test("boss kill wins immediately and suppresses later same-tick damage", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.towerInstances = {}
    local state = assert(Battle.new(defs, run, "W15"))
    state.spawnSchedule = { state.spawnSchedule[1] }
    state.nextSpawnIndex = 2
    local boss = state.enemies[1]
    boss.hp = 1
    local ordinary = Content.clone(boss)
    ordinary.enemyId = 2
    ordinary.typeId = "E01"
    ordinary.boss = false
    ordinary.hp, ordinary.maxHp, ordinary.baseSpeed = 24, 24, 0
    ordinary.spawnOrdinal = 2
    state.enemies[#state.enemies + 1] = ordinary
    state.enemyById[2] = ordinary
    state.projectiles = {
        makeDueProjectile(1, boss, 1),
        makeDueProjectile(2, ordinary, 24),
    }
    local events = assert(Battle.step(state, Battle.FIXED_DT))
    equal(state.result.kind, "victory")
    equal(state.result.reason, "boss_killed")
    equal(ordinary.hp, 24, "later damage must stop after boss kill")
    assert(containsEvent(events, "battle_victory", function(event) return event.reason == "boss_killed" end))
    local summary = Battle.summary(state)
    equal(summary.resultKind, "victory")
    equal(summary.resultReason, "boss_killed")
end)

test("same-tick hp zero beats boss kill", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.hp = 1
    run.towerInstances = {}
    local state = assert(Battle.new(defs, run, "W15"))
    state.spawnSchedule = { state.spawnSchedule[1] }
    state.nextSpawnIndex = 2
    local boss = state.enemies[1]
    boss.hp = 1
    local leaker = Content.clone(boss)
    leaker.enemyId = 2
    leaker.typeId = "E01"
    leaker.boss = false
    leaker.hp, leaker.maxHp, leaker.baseSpeed = 24, 24, 0
    leaker.routeId, leaker.totalLength, leaker.s = "R_B", 20, 20
    leaker.spawnOrdinal = 2
    state.enemies[#state.enemies + 1] = leaker
    state.enemyById[2] = leaker
    state.projectiles = { makeDueProjectile(1, boss, 1) }
    assert(Battle.step(state, Battle.FIXED_DT))
    equal(state.result.kind, "defeat")
    equal(state.result.reason, "hp_zero")
    equal(state.bossKilledThisTick, true)
end)

test("boss escape defeats without ordinary hp damage", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.towerInstances = {}
    local state = assert(Battle.new(defs, run, "W15"))
    state.spawnSchedule = { state.spawnSchedule[1] }
    state.nextSpawnIndex = 2
    state.enemies[1].s = state.enemies[1].totalLength
    assert(Battle.step(state, Battle.FIXED_DT))
    equal(state.result.kind, "defeat")
    equal(state.result.reason, "boss_escaped")
    equal(state.hp, 20)
end)

test("victory and defeat reduction persist run.result without normal reward", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    local victory, victoryEvents = assert(Rules.reduceCompletion(defs, run, {
        waveId = "W15", resultKind = "victory", resultReason = "boss_killed",
        tick = 75, hp = 7, leaks = 2, towerInstances = run.towerInstances,
    }))
    equal(victory.result.kind, "victory")
    equal(victory.result.reason, "boss_killed")
    equal(victory.result.tick, 75)
    equal(victory.gold, 12)
    equal(victory.completedWaveIds.W15, nil)
    equal(victoryEvents[1].type, "run_victory")

    local defeat, defeatEvents = assert(Rules.reduceCompletion(defs, run, {
        waveId = "W15", resultKind = "defeat", resultReason = "boss_escaped",
        tick = 90, hp = 20, leaks = 1, towerInstances = run.towerInstances,
    }))
    equal(defeat.result.kind, "defeat")
    equal(defeat.result.reason, "boss_escaped")
    equal(defeat.gold, 12)
    equal(defeat.completedWaveIds.W15, nil)
    equal(defeatEvents[1].type, "battle_defeated")

    local invalid, _, reason = Rules.reduceCompletion(defs, run, {
        waveId = "W15", resultKind = "wave_complete", tick = 91,
        hp = 20, leaks = 0, towerInstances = run.towerInstances,
    })
    equal(invalid, nil)
    equal(reason, "boss_result_required")
    equal(run.gold, 12)
end)

test("stage B formation modules use placed types cardinal neighbors and exact conditions", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T01", 1, 1, {}, { "M03", "M07", "M08" })
    run.towerInstances[#run.towerInstances + 1] = {
        instanceId = 2, typeId = "T01", paidGold = 0, patchIds = {},
        placement = { x = 2, y = 1 }, charge = 0, activated = true,
    }
    run.towerInstances[#run.towerInstances + 1] = {
        instanceId = 3, typeId = "T02", paidGold = 0, patchIds = {},
        placement = { x = 4, y = 4 }, charge = 0, activated = true,
    }
    local stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleDamage, 1.10, 1e-9)
    close(stats.factors.moduleRate, 1.45, 1e-9)

    run.modules = { "M04", "M07" }
    run.towerInstances[3].typeId = "T01"
    run.towerInstances[2].placement = { x = 2, y = 2 }
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleRate, 1.35, 1e-9, "diagonal same-type tower is not cardinal")
    run.towerInstances[2].placement = { x = 2, y = 1 }
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleRate, 1.55, 1e-9)

    run.modules = { "M03" }
    for _, tower in ipairs(run.towerInstances) do tower.placement = nil end
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleDamage, 1, 1e-9, "owned but unplaced types do not count")
end)

test("stage B patch formation growth and gold thresholds compose in module layer", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T01", 1, 1,
        { "P_DAMAGE", "P_RATE", "P_RANGE" }, { "M09", "M11", "M13" })
    run.towerInstances[#run.towerInstances + 1] = {
        instanceId = 2, typeId = "T02", paidGold = 0, patchIds = { "P_DAMAGE" },
        placement = { x = 4, y = 4 }, charge = 0, activated = true,
    }
    local stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleDamage, 1.90, 1e-9)
    run.towerInstances[2].patchIds = { "P_DAMAGE", "P_RATE", "P_RANGE" }
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleDamage, 1.50, 1e-9, "M13 deactivates on a tie")

    run.towerInstances[1].patchIds = {}
    run.modules = { "M10" }
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleRate, 1.25, 1e-9)

    run.modules = {
        { moduleId = "M33", paidGold = 12, growth = 27 },
        { moduleId = "M34", paidGold = 12, growth = 30 },
        { moduleId = "M37", paidGold = 8, growth = 3 },
        "M44", "M45",
    }
    run.gold = 20
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleDamage, 1.85, 1e-9)
    close(stats.factors.moduleRate, 1, 1e-9)
    run.gold = 19
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleDamage, 1.60, 1e-9, "M44 starts at exactly 20 gold")
    close(stats.factors.moduleRate, 1, 1e-9)
    run.gold = 3
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleDamage, 1.60, 1e-9)
    close(stats.factors.moduleRate, 1.25, 1e-9)
    run.gold = 4
    stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.factors.moduleRate, 1, 1e-9, "M45 stops above 3 gold")
end)

test("M18 conditional damage reads enemy-local 120 tick history without mutation", function()
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = { "M17", "M18" } })
    local enemy = {
        slowUntilTick = 121,
        lastHitTickByTowerType = { T01 = 0, T02 = 1 },
    }
    close(Rules.conditionalDamageMultiplier(run, enemy, 120), 1.55, 1e-9)
    close(Rules.conditionalDamageMultiplier(run, enemy, 121), 1.30, 1e-9,
        "a hit 121 ticks old is excluded")
    equal(enemy.lastHitTickByTowerType.T01, 0)
    equal(enemy.lastHitTickByTowerType.T02, 1)
    enemy.lastHitTickByTowerType = { T01 = 120 }
    close(Rules.conditionalDamageMultiplier(run, enemy, 120), 1.30, 1e-9,
        "multiple instances of one type still count as one type")
end)

test("M06 purchase reuses exact-N recalls and commits sorted events atomically", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.gold = 100
    run.towerInstances = {}
    for instanceId = 1, 7 do
        run.towerInstances[#run.towerInstances + 1] = {
            instanceId = instanceId, typeId = "T01", paidGold = 0, patchIds = { "P_DAMAGE" },
            placement = instanceId <= 6 and { x = instanceId, y = 0 } or nil,
            charge = instanceId / 10, activated = true,
        }
    end
    run.nextInstanceId = 8
    run.shopState = { visitId = "S02", offers = {}, rerollCount = 0,
        refundUseCount = 0, firstRerollDone = false,
        rngState = { algorithm = "park-miller-v1", state = 77 } }
    local preview = assert(Rules.previewModulePurchase(defs, run, "M06"))
    equal(preview.towerCapacityBefore, 6)
    equal(preview.towerCapacityAfter, 4)
    equal(preview.requiredRecallCount, 2)
    equal(preview.canCommit, false)

    local candidate, _, reason = Rules.tryPurchaseModule(defs, run, "M06")
    equal(candidate, nil)
    equal(reason, "recall_selection_required")
    candidate, _, reason = Rules.tryPurchaseModule(defs, run, "M06", { 1 })
    equal(candidate, nil)
    equal(reason, "recall_count_mismatch")
    candidate, _, reason = Rules.tryPurchaseModule(defs, run, "M06", { 1, 1 })
    equal(candidate, nil)
    equal(reason, "duplicate_recall_target")
    candidate, _, reason = Rules.tryPurchaseModule(defs, run, "M06", { 1, 7 })
    equal(candidate, nil)
    equal(reason, "recall_target_not_placed")

    local purchased, events = assert(Rules.tryPurchaseModule(defs, run, "M06", { 6, 2 }))
    equal(Rules.towerCapacity(purchased), 4)
    equal(purchased.gold, 84)
    equal(purchased.towerInstances[2].placement, nil)
    equal(purchased.towerInstances[6].placement, nil)
    equal(events[1].type, "tower_recalled")
    equal(events[1].instanceId, 2)
    equal(events[2].instanceId, 6)
    equal(events[3].type, "module_purchased")
    equal(events[3].moduleId, "M06")
    close(assert(Rules.projectStats(defs, purchased, 1)).factors.moduleDamage, 1.35, 1e-9)
    equal(run.gold, 100)
    equal(#run.modules, 0)
    assert(run.towerInstances[2].placement and run.towerInstances[6].placement)
    equal(run.shopState.rngState.state, 77)

    local offset = Rules.newRun(defs, { modules = { "M05", "M06" } })
    equal(Rules.towerCapacity(offset), 6, "M05 and M06 capacity modifiers offset")
end)

test("M29 refunds only two fully affordable patches and M34 grows once per success", function()
    local defs = Content.create()
    local price = defs.patchesById.P_DAMAGE.price
    local run = oneTowerRun(defs, "T01", 1, 1, {}, {
        "M29", { moduleId = "M34", paidGold = 12, growth = 27 },
    })
    run.shopState = { visitId = "S02", offers = {}, rerollCount = 0,
        refundUseCount = 0, firstRerollDone = false,
        rngState = { algorithm = "park-miller-v1", state = 99 } }
    run.gold = price - 1
    local failed, _, reason = Rules.tryPurchasePatch(defs, run, 1, "P_DAMAGE")
    equal(failed, nil)
    equal(reason, "insufficient_gold")
    equal(run.shopState.refundUseCount, 0)

    run.gold = price
    local first, firstEvents = assert(Rules.tryPurchasePatch(defs, run, 1, "P_DAMAGE"))
    equal(first.gold, 1)
    equal(first.shopState.refundUseCount, 1)
    equal(firstEvents[1].type, "patch_purchased")
    equal(firstEvents[1].paidGold, price)
    equal(firstEvents[1].refundGold, 1)
    equal(firstEvents[2].type, "module_refund_applied")
    equal(firstEvents[3].type, "module_growth_changed")
    equal(first.modules[2].growth, 30)
    first.gold = price
    local second, secondEvents = assert(Rules.tryPurchasePatch(defs, first, 1, "P_RATE"))
    equal(second.shopState.refundUseCount, 2)
    equal(secondEvents[2].type, "module_refund_applied")
    equal(#secondEvents, 2, "growth at cap emits no duplicate event")
    second.gold = price
    local third, thirdEvents = assert(Rules.tryPurchasePatch(defs, second, 1, "P_RANGE"))
    equal(third.shopState.refundUseCount, 2)
    equal(thirdEvents[1].refundGold, 0)
    equal(#thirdEvents, 1)
    equal(run.gold, price)
    equal(run.modules[2].growth, 27)
end)

test("M30 free first reroll and M33 growth use supplied next shop without touching source", function()
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = {
        "M30", { moduleId = "M33", paidGold = 12, growth = 27 },
    } })
    run.gold = 0
    run.shopState = { visitId = "S03", offers = { tower = "T01" }, rerollCount = 0,
        refundUseCount = 0, firstRerollDone = false,
        rngState = { algorithm = "park-miller-v1", state = 10 } }
    local receipt = assert(Rules.previewReroll(run))
    equal(receipt.nominalGold, 2)
    equal(receipt.discountGold, 2)
    equal(receipt.paidGold, 0)
    equal(receipt.canCommit, true)
    local nextShop = Content.clone(run.shopState)
    nextShop.rerollCount = 1
    nextShop.firstRerollDone = true
    nextShop.offers.tower = "T02"
    nextShop.rngState.state = 11
    local applied, events = assert(Rules.tryApplyReroll(defs, run, nextShop))
    equal(applied.gold, 0)
    equal(applied.shopState.rerollCount, 1)
    equal(applied.modules[2].growth, 30)
    equal(events[1].type, "reroll_paid")
    equal(events[2].type, "shop_rerolled")
    equal(events[3].type, "module_growth_changed")
    equal(run.shopState.rerollCount, 0)
    equal(run.shopState.rngState.state, 10)
    equal(nextShop.rngState.state, 11)
    local nextReceipt = assert(Rules.previewReroll(applied))
    equal(nextReceipt.nominalGold, 4)
    equal(nextReceipt.discountGold, 0)
    equal(nextReceipt.canCommit, false)
    local acquiredLate = Content.clone(run)
    acquiredLate.gold = 10
    acquiredLate.shopState.rerollCount = 1
    acquiredLate.shopState.firstRerollDone = true
    local lateReceipt = assert(Rules.previewReroll(acquiredLate))
    equal(lateReceipt.nominalGold, 4)
    equal(lateReceipt.discountGold, 0, "buying M30 after the first reroll grants no retroactive discount")
    local invalid, _, invalidReason = Rules.tryApplyReroll(defs, run, run.shopState)
    equal(invalid, nil)
    equal(invalidReason, "invalid_next_shop_state")
end)

test("M32 settlement snapshots empty capacity and M37 grows after ordinary reward only", function()
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = {
        "M25", "M32", { moduleId = "M37", paidGold = 8, growth = 27 },
    } })
    run.towerInstances = {}
    for instanceId = 1, 3 do
        run.towerInstances[#run.towerInstances + 1] = {
            instanceId = instanceId, typeId = "T01", paidGold = 0, patchIds = {},
            placement = { x = instanceId, y = 0 }, charge = 0, activated = true,
        }
    end
    local reward = Rules.previewSettlement(defs, run, 3, 1)
    equal(reward.moduleById.M25, 2)
    equal(reward.moduleById.M32, 3)
    equal(reward.modules, 5)
    equal(reward.total, 17)
    local fiveOfEight = Content.clone(run)
    fiveOfEight.modules[#fiveOfEight.modules + 1] = "M05"
    for instanceId = 4, 5 do
        fiveOfEight.towerInstances[#fiveOfEight.towerInstances + 1] = {
            instanceId = instanceId, typeId = "T01", paidGold = 0, patchIds = {},
            placement = { x = instanceId, y = 0 }, charge = 0, activated = true,
        }
    end
    equal(Rules.previewSettlement(defs, fiveOfEight, 4, 1).moduleById.M32, 3)
    local fourOfFour = Content.clone(run)
    fourOfFour.baseTowerCapacity = 4
    fourOfFour.towerInstances[#fourOfFour.towerInstances + 1] = {
        instanceId = 4, typeId = "T01", paidGold = 0, patchIds = {},
        placement = { x = 4, y = 0 }, charge = 0, activated = true,
    }
    equal(Rules.previewSettlement(defs, fourOfFour, 4, 1).moduleById.M32, 0)
    local completed, events = assert(Rules.reduceCompletion(defs, run, {
        waveId = "W03", resultKind = "wave_complete", hp = 20, leaks = 1,
        towerInstances = Content.clone(run.towerInstances),
    }))
    equal(completed.gold, 29)
    equal(completed.modules[3].growth, 30)
    equal(events[1].type, "wave_reward")
    equal(events[2].type, "module_growth_changed")
    local duplicate, duplicateEvents = assert(Rules.reduceCompletion(defs, completed, {
        waveId = "W03", resultKind = "wave_complete", hp = 20, leaks = 1,
        towerInstances = Content.clone(run.towerInstances),
    }))
    equal(duplicate.modules[3].growth, 30)
    equal(duplicateEvents[1].type, "completion_duplicate")
    local victory = assert(Rules.reduceCompletion(defs, run, {
        waveId = "W15", resultKind = "victory", resultReason = "boss_killed",
        tick = 1, hp = 20, leaks = 0, towerInstances = Content.clone(run.towerInstances),
    }))
    equal(victory.gold, 12)
    equal(victory.modules[3].growth, 27)
end)

local function conditionalProjectionFixture(defs)
    local run = Rules.newRun(defs, { modules = { "M07", "M09", "M10", "M11", "M13" } })
    run.towerInstances = {
        { instanceId = 1, typeId = "T01", paidGold = 0, patchIds = { "P_DAMAGE" },
            placement = { x = 1, y = 1 }, charge = 0, activated = true },
        { instanceId = 2, typeId = "T01", paidGold = 0,
            patchIds = { "P_DAMAGE", "P_RATE", "P_RANGE" },
            placement = { x = 2, y = 1 }, charge = 0, activated = true },
        { instanceId = 3, typeId = "T02", paidGold = 0, patchIds = {},
            placement = { x = 4, y = 4 }, charge = 0, activated = true },
        { instanceId = 4, typeId = "T03", paidGold = 0,
            patchIds = { "P_OVERLOAD", "P_OVERDRIVE", "P_LONG_RANGE" },
            placement = { x = 5, y = 4 }, charge = 0, activated = true },
    }
    return run
end

test("conditional module status exposes formation aggregates without a selected tower", function()
    local defs = Content.create()
    local run = conditionalProjectionFixture(defs)
    local m07 = assert(Rules.projectModuleStatus(defs, run, "M07"))
    equal(m07.placedTowerCount, 4)
    equal(m07.qualifyingTowerCount, 2)
    equal(m07.qualifyingTowerIds[1], 1)
    equal(m07.qualifyingTowerIds[2], 2)
    equal(m07.selectedTowerId, nil)
    equal(m07.active, false, "no selected tower keeps common active false")

    local m09 = assert(Rules.projectModuleStatus(defs, run, "M09"))
    equal(m09.qualifyingTowerCount, 2)
    equal(m09.qualifyingTowerIds[1], 2)
    equal(m09.qualifyingTowerIds[2], 4)
    equal(m09.active, false)
    local m10 = assert(Rules.projectModuleStatus(defs, run, "M10"))
    equal(m10.qualifyingTowerCount, 1)
    equal(m10.qualifyingTowerIds[1], 3)
    equal(m10.active, false)

    local m11 = assert(Rules.projectModuleStatus(defs, run, "M11"))
    equal(m11.placedTowerCount, 4)
    equal(m11.qualifyingTowerCount, 2)
    equal(m11.qualifyingTowerIds[1], 1)
    equal(m11.qualifyingTowerIds[2], 2)
    equal(m11.sharingByTower[1].instanceId, 1)
    equal(m11.sharingByTower[1].sharedPatchIds[1], "P_DAMAGE")
    equal(m11.sharingByTower[1].counterpartInstanceIds[1], 2)
    equal(m11.sharingByTower[1].matches[1].patchId, "P_DAMAGE")
    equal(m11.sharingByTower[1].matches[1].counterpartInstanceId, 2)
    equal(m11.active, false)

    local m13 = assert(Rules.projectModuleStatus(defs, run, "M13"))
    equal(m13.patchLeadState, "tie")
    equal(m13.highestPatchCount, 3)
    equal(m13.highestPatchTowerIds[1], 2)
    equal(m13.highestPatchTowerIds[2], 4)
    equal(m13.soleHighestTowerId, nil)
    equal(m13.qualifyingTowerCount, 0)
    equal(m13.active, false)
end)

test("conditional module status keeps aggregate truth beside selected and inactive details", function()
    local defs = Content.create()
    local run = conditionalProjectionFixture(defs)
    table.remove(run.towerInstances[4].patchIds)

    local selectedShared = assert(Rules.projectModuleStatus(defs, run, "M11", { towerInstanceId = 1 }))
    equal(selectedShared.selectedTowerId, 1)
    equal(selectedShared.selectedTowerQualifies, true)
    equal(selectedShared.sharedPatchIds[1], "P_DAMAGE")
    equal(selectedShared.sharedWithTowerIds[1], 2)
    equal(selectedShared.qualifyingTowerCount, 2)
    equal(selectedShared.active, true)

    local selectedNeighbor = assert(Rules.projectModuleStatus(defs, run, "M07", { towerInstanceId = 1 }))
    equal(selectedNeighbor.selectedTowerQualifies, true)
    equal(selectedNeighbor.qualifyingTowerCount, 2)
    equal(selectedNeighbor.active, true)

    local selectedInactive = assert(Rules.projectModuleStatus(defs, run, "M07", { towerInstanceId = 3 }))
    equal(selectedInactive.selectedTowerQualifies, false)
    equal(selectedInactive.sameTypeCardinalNeighborCount, 0)
    equal(selectedInactive.qualifyingTowerCount, 2)
    equal(selectedInactive.active, false,
        "aggregate count must not replace selected-tower active semantics")

    local selectedComplete = assert(Rules.projectModuleStatus(defs, run, "M09", { towerInstanceId = 2 }))
    equal(selectedComplete.selectedTowerQualifies, true)
    equal(selectedComplete.patchCount, 3)
    equal(selectedComplete.qualifyingTowerCount, 1)
    equal(selectedComplete.active, true)

    local selectedZeroPatch = assert(Rules.projectModuleStatus(defs, run, "M10", { towerInstanceId = 3 }))
    equal(selectedZeroPatch.selectedTowerQualifies, true)
    equal(selectedZeroPatch.patchCount, 0)
    equal(selectedZeroPatch.active, true)
    local sole = assert(Rules.projectModuleStatus(defs, run, "M13", { towerInstanceId = 2 }))
    equal(sole.patchLeadState, "sole_highest")
    equal(sole.soleHighestTowerId, 2)
    equal(sole.soleHighestPatchCount, 3)
    equal(sole.selectedTowerQualifies, true)
    equal(sole.active, true)

    local nonqualifyingM09 = assert(Rules.projectModuleStatus(defs, run, "M09", { towerInstanceId = 3 }))
    equal(nonqualifyingM09.selectedTowerQualifies, false)
    equal(nonqualifyingM09.qualifyingTowerCount, 1)
    equal(nonqualifyingM09.active, false)
    local nonqualifyingM10 = assert(Rules.projectModuleStatus(defs, run, "M10", { towerInstanceId = 1 }))
    equal(nonqualifyingM10.selectedTowerQualifies, false)
    equal(nonqualifyingM10.qualifyingTowerCount, 1)
    equal(nonqualifyingM10.active, false)
    local nonqualifyingM11 = assert(Rules.projectModuleStatus(defs, run, "M11", { towerInstanceId = 3 }))
    equal(nonqualifyingM11.selectedTowerQualifies, false)
    equal(nonqualifyingM11.qualifyingTowerCount, 2)
    equal(nonqualifyingM11.active, false)
    local nonqualifyingM13 = assert(Rules.projectModuleStatus(defs, run, "M13", { towerInstanceId = 4 }))
    equal(nonqualifyingM13.selectedTowerQualifies, false)
    equal(nonqualifyingM13.soleHighestTowerId, 2)
    equal(nonqualifyingM13.active, false)

    local inactive = Content.clone(run)
    inactive.towerInstances[2].placement = { x = 2, y = 2 }
    inactive.towerInstances[1].patchIds = { "P_DAMAGE" }
    inactive.towerInstances[2].patchIds = { "P_RATE" }
    inactive.towerInstances[3].patchIds = { "P_OVERLOAD" }
    inactive.towerInstances[4].patchIds = { "P_RANGE" }
    equal(assert(Rules.projectModuleStatus(defs, inactive, "M07")).qualifyingTowerCount, 0)
    equal(assert(Rules.projectModuleStatus(defs, inactive, "M09")).qualifyingTowerCount, 0)
    equal(assert(Rules.projectModuleStatus(defs, inactive, "M10")).qualifyingTowerCount, 0)
    equal(assert(Rules.projectModuleStatus(defs, inactive, "M11")).qualifyingTowerCount, 0)
    local tied = assert(Rules.projectModuleStatus(defs, inactive, "M13"))
    equal(tied.patchLeadState, "tie")
    equal(tied.qualifyingTowerCount, 0)
    for _, tower in ipairs(inactive.towerInstances) do tower.patchIds = {} end
    local none = assert(Rules.projectModuleStatus(defs, inactive, "M13"))
    equal(none.patchLeadState, "none")
    equal(none.highestPatchCount, 0)
end)

test("module status and explicit growth projections are immutable at boundaries", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T01", 1, 1, {}, {
        "M29", "M30", "M32", { moduleId = "M33", paidGold = 12, growth = 27 }, "M44",
    })
    run.gold = 20
    run.shopState = { visitId = "S04", offers = {}, rerollCount = 0,
        refundUseCount = 1, firstRerollDone = false,
        rngState = { algorithm = "park-miller-v1", state = 55 } }
    local refund = assert(Rules.projectModuleStatus(defs, run, "M29", { patchId = "P_DAMAGE" }))
    equal(refund.refundUseCount, 1)
    equal(refund.refundRemaining, 1)
    equal(refund.nextPatchRefundGold, 1)
    local settlement = assert(Rules.projectModuleStatus(defs, run, "M32"))
    equal(settlement.towerCapacity, 6)
    equal(settlement.placedTowerCount, 1)
    equal(settlement.estimatedGold, 3)
    local savings = assert(Rules.projectModuleStatus(defs, run, "M44", { towerInstanceId = 1 }))
    equal(savings.active, true)
    local growth = assert(Rules.projectModuleStatus(defs, run, "M33", { towerInstanceId = 1 }))
    equal(growth.growth, 27)
    equal(growth.nextGrowth, 30)
    local grown, growthEvent = assert(Rules.applyModuleGrowth(defs, run, "M33", "fixture"))
    equal(grown.modules[4].growth, 30)
    equal(growthEvent.delta, 3)
    local capped, cappedEvent = assert(Rules.applyModuleGrowth(defs, grown, "M33", "fixture"))
    equal(capped.modules[4].growth, 30)
    equal(cappedEvent, nil, "growth at cap is an inert candidate without an event")
    equal(run.modules[4].growth, 27)
    equal(run.shopState.refundUseCount, 1)
    equal(run.shopState.rngState.state, 55)
end)

local function shopPool(defs, moduleIds)
    local pool = { towerIds = {}, patchIds = {}, moduleIds = moduleIds or {} }
    for _, tower in ipairs(defs.towers) do pool.towerIds[#pool.towerIds + 1] = tower.id end
    for _, patch in ipairs(defs.patches) do pool.patchIds[#pool.patchIds + 1] = patch.id end
    return pool
end

test("shop new visits reset counters and keep legacy six-module pools frozen", function()
    local defs = Content.create()
    local legacyIds = { "M01", "M02", "M05", "M17", "M25", "M26" }
    local frozen = shopPool(defs, legacyIds)
    local options = {
        visitId = "S01",
        frozenUnlockPool = frozen,
        acquiredModuleIds = {},
        rngState = { algorithm = "park-miller-v1", state = 12345 },
    }
    local first = Shop.createVisit(defs, options)
    local replay = Shop.createVisit(defs, options)
    equal(first.offers.tower, replay.offers.tower)
    equal(first.offers.patch, replay.offers.patch)
    equal(first.offers.module, replay.offers.module)
    equal(first.rngState.state, replay.rngState.state)
    equal(first.rerollCount, 0)
    equal(first.refundUseCount, 0)
    equal(first.firstRerollDone, false)
    equal(first.accessOpen, true)
    equal(options.rngState.state, 12345, "visit creation mutated its RNG input")
    local legacy = {}
    for _, id in ipairs(legacyIds) do legacy[id] = true end
    assert(legacy[first.offers.module], "legacy frozen pool offered a Stage B module")

    local allAcquired = {}
    for _, id in ipairs(legacyIds) do allAcquired[id] = true end
    local exhausted = Shop.createVisit(defs, {
        visitId = "S02", frozenUnlockPool = frozen,
        acquiredModuleIds = allAcquired, rngState = first.rngState,
    })
    equal(exhausted.offers.module, nil)
    equal(exhausted.soldOut.module, true)
    equal(exhausted.refundUseCount, 0)
    equal(exhausted.firstRerollDone, false)
end)

test("shop reroll is deterministic and preserves visit-owned refund state without economy logic", function()
    local defs = Content.create()
    local frozen = shopPool(defs, {
        "M01", "M02", "M03", "M04", "M05", "M06",
        "M07", "M08", "M09", "M10", "M11", "M13",
        "M17", "M18", "M25", "M26", "M29", "M30",
        "M32", "M33", "M34", "M37", "M44", "M45",
    })
    local visit = Shop.createVisit(defs, {
        visitId = "S03", frozenUnlockPool = frozen, acquiredModuleIds = {},
        rngState = { algorithm = "park-miller-v1", state = 67890 },
    })
    visit.refundUseCount = 2
    visit.accessOpen = false
    local sourceOffer = visit.offers.tower
    local sourceRng = visit.rngState.state
    local options = { frozenUnlockPool = frozen, acquiredModuleIds = { M01 = true } }
    local first = Shop.reroll(defs, visit, options)
    local replay = Shop.reroll(defs, visit, options)
    equal(first.offers.tower, replay.offers.tower)
    equal(first.offers.patch, replay.offers.patch)
    equal(first.offers.module, replay.offers.module)
    equal(first.rngState.state, replay.rngState.state)
    equal(first.visitId, "S03")
    equal(first.rerollCount, 1)
    equal(first.refundUseCount, 2)
    equal(first.firstRerollDone, true)
    equal(first.accessOpen, false)
    equal(first.paidGold, nil)
    equal(first.refundGold, nil)
    equal(first.growth, nil)
    equal(visit.rerollCount, 0)
    equal(visit.firstRerollDone, false)
    equal(visit.refundUseCount, 2)
    equal(visit.offers.tower, sourceOffer)
    equal(visit.rngState.state, sourceRng)
end)

test("closing and reopening one shop visit preserves offers RNG and both counters", function()
    local defs = Content.create()
    local visit = Shop.createVisit(defs, {
        visitId = "S04",
        frozenUnlockPool = shopPool(defs, { "M01", "M02", "M05", "M17", "M25", "M26" }),
        acquiredModuleIds = {},
        rngState = { algorithm = "park-miller-v1", state = 24680 },
    })
    visit.refundUseCount = 1
    visit.firstRerollDone = true
    local closed = Content.clone(visit)
    closed.accessOpen = false
    local reopened = Content.clone(closed)
    reopened.accessOpen = true
    equal(reopened.visitId, visit.visitId)
    equal(reopened.offers.tower, visit.offers.tower)
    equal(reopened.offers.patch, visit.offers.patch)
    equal(reopened.offers.module, visit.offers.module)
    equal(reopened.rngState.state, visit.rngState.state)
    equal(reopened.rerollCount, visit.rerollCount)
    equal(reopened.refundUseCount, 1)
    equal(reopened.firstRerollDone, true)
end)

local function chainFixture(specs, modules, damage)
    local defs = Content.create()
    local run = Rules.newRun(defs, { modules = modules or {} })
    run.towerInstances = {}
    local state = assert(Battle.new(defs, run, "W01"))
    state.spawnSchedule, state.nextSpawnIndex, state.pendingEvents = {}, 1, {}
    state.enemies, state.enemyById = {}, {}
    for index, spec in ipairs(specs) do
        local enemy = {
            enemyId = index, typeId = "E01", routeId = spec.routeId or "R_A",
            s = spec.s or 0, totalLength = spec.totalLength or 21,
            hp = spec.hp or 100, maxHp = 100, baseSpeed = 0,
            spawnOrdinal = spec.ordinal or index, spawnTick = 0, alive = spec.alive ~= false,
            boss = spec.boss, slowUntilTick = spec.slowUntilTick, slowRatio = 0,
            lastHitTickByTowerType = spec.history or {},
        }
        state.enemies[index], state.enemyById[index] = enemy, enemy
    end
    local x, y = Battle.routePosition(state.routesById[state.enemies[1].routeId], state.enemies[1].s)
    state.projectiles = { {
        projectileId = 1, sourceTowerId = 99, sourceTowerTypeId = "T06", targetId = 1,
        x = x, y = y, speed = 20, launchBaseDamage = damage or 14,
        launchAttackId = 7, sourceKind = "normal", behavior = "chain",
        chainRange = 1.6, chainHops = 2, chainFactor = 0.7,
    } }
    return state
end

local function damageEvents(events)
    local result = {}
    for _, event in ipairs(events) do
        if event.type == "enemy_damaged" then result[#result + 1] = event end
    end
    return result
end

test("R7 Q01 T05 T06 definitions cadence flight and initial target range", function()
    local defs = Content.create()
    equal(#defs.towers, 6)
    equal(defs.capabilities.implementedTowerCount, 6)
    for _, case in ipairs({ { "T05", 60, 180, 5, 24 }, { "T06", 14, 72, 3, 20 } }) do
        local id, damage, ticks, range, speed = unpack(case)
        equal(defs.towersById[id].tier, "high")
        equal(defs.towersById[id].price, 12)
        local run = oneTowerRun(defs, id, 0, 2)
        local stats = assert(Rules.projectStats(defs, run, 1))
        close(stats.damage, damage, 1e-9)
        close(stats.attackRate, 60 / ticks, 1e-9)
        equal(stats.range, range)
        equal(stats.projectileSpeed, speed)
        local state = assert(Battle.new(defs, run, "W01"))
        state.spawnSchedule, state.nextSpawnIndex = {}, 1
        local enemy = state.enemies[1]
        enemy.baseSpeed, enemy.hp = 0, 1000
        state.towers[1].placement = { x = range, y = 1 }
        equal(Battle.selectTarget(state, state.towers[1], stats), enemy)
        state.towers[1].placement.x = range + 1e-6
        equal(Battle.selectTarget(state, state.towers[1], stats), nil)
        state.towers[1].placement = { x = 0, y = 2 }
        for tick = 1, ticks - 1 do
            local events = assert(Battle.step(state, Battle.FIXED_DT))
            equal(containsEvent(events, "tower_fired"), nil)
        end
        local events = assert(Battle.step(state, Battle.FIXED_DT))
        equal(assert(containsEvent(events, "tower_fired")).tick, ticks)
        equal(#state.projectiles, 1)
        equal(state.projectiles[1].y, 2, "new shot cannot move in creation tick")
        assert(Battle.step(state, Battle.FIXED_DT))
        close(state.projectiles[1].y, 2 - speed / 60, 1e-9)
        for _ = 1, 10 do
            events = assert(Battle.step(state, Battle.FIXED_DT))
            local hit = containsEvent(events, "enemy_damaged")
            if hit then close(hit.damage, damage, 1e-9) break end
        end
        close(enemy.hp, 1000 - damage, 1e-9)
    end
end)

test("R7 Q02 chain two hops share tick projectile attack and use hit position", function()
    local state = chainFixture({ { s = 0 }, { s = 1.6 }, { s = 3.2 }, { s = 4.0 } })
    local hits = damageEvents(assert(Battle.step(state, Battle.FIXED_DT)))
    equal(#hits, 3)
    for index, expected in ipairs({ 14, 9.8, 6.86 }) do
        equal(hits[index].enemyId, index)
        equal(hits[index].tick, 1)
        equal(hits[index].projectileId, 1)
        equal(hits[index].attackId, 7)
        close(hits[index].damage, expected, 1e-9)
    end
    equal(hits[1].hitKind, "primary")
    equal(hits[2].hitKind, "chain")
    equal(#state.projectiles, 0)
    equal(state.enemies[4].hp, 100)
end)

test("R7 Q03 chain boundary nearest exit progress and spawn ties", function()
    local included = chainFixture({ { s = 0 }, { s = 1.6 } })
    equal(#damageEvents(assert(Battle.step(included, Battle.FIXED_DT))), 2)
    local excluded = chainFixture({ { s = 0 }, { s = 1.6 + 1e-6 } })
    equal(#damageEvents(assert(Battle.step(excluded, Battle.FIXED_DT))), 1)
    -- Same hit coordinates with distinct remaining-route distances isolate the tie rule.
    local state = chainFixture({
        { s = 9 }, { s = 9.5, totalLength = 30 },
        { s = 10, ordinal = 4 }, { s = 10, ordinal = 3 },
        { s = 10, totalLength = 20, ordinal = 5 },
    })
    local hits = damageEvents(assert(Battle.step(state, Battle.FIXED_DT)))
    equal(hits[2].enemyId, 2, "nearest wins even with more distance to exit")
    equal(hits[3].enemyId, 5, "next jump reevaluates and shorter exit wins distance tie")
    state = chainFixture({ { s = 0 }, { s = 1, ordinal = 5 }, { s = 1, ordinal = 3 } })
    hits = damageEvents(assert(Battle.step(state, Battle.FIXED_DT)))
    equal(hits[2].enemyId, 3, "spawn order breaks full tie")
    equal(hits[3].enemyId, 2, "never hits a previous target again")
end)

test("R7 Q04 chain missing target dead origins boss stop and defeat priority", function()
    for _, missingKind in ipairs({ "dead", "leaked" }) do
        local state = chainFixture({ { s = missingKind == "leaked" and 21 or 0 }, { s = 1 } })
        if missingKind == "dead" then state.enemies[1].alive = false end
        local events = assert(Battle.step(state, Battle.FIXED_DT))
        equal(#damageEvents(events), 0)
        assert(containsEvent(events, "projectile_expired", function(e) return e.reason == "target_missing" end))
    end
    local state = chainFixture({ { s = 0, hp = 1 }, { s = 1.6, hp = 1 }, { s = 3.2 } })
    equal(#damageEvents(assert(Battle.step(state, Battle.FIXED_DT))), 3)
    equal(state.enemies[1].alive, false)
    equal(state.enemies[2].alive, false)
    state = chainFixture({ { s = 0 }, { s = 1, hp = 1, boss = true }, { s = 2 } })
    equal(#damageEvents(assert(Battle.step(state, Battle.FIXED_DT))), 2)
    equal(state.result.kind, "victory")
    equal(state.enemies[3].hp, 100)
    state = chainFixture({ { s = 0 }, { s = 1, hp = 1, boss = true }, { s = 21 } })
    state.hp = 1
    assert(Battle.step(state, Battle.FIXED_DT))
    equal(state.bossKilledThisTick, true)
    equal(state.result.kind, "defeat")
    equal(state.result.reason, "hp_zero")
end)

test("R7 Q05 chain patches preserve jump constants and conditional damage is per target", function()
    local defs = Content.create()
    local run = oneTowerRun(defs, "T06", 0, 2, { "P_DAMAGE", "P_RATE", "P_RANGE" })
    local stats = assert(Rules.projectStats(defs, run, 1))
    close(stats.damage, 14 * 1.15, 1e-9)
    close(stats.attackRate, 1.15 / 1.2, 1e-9)
    close(stats.range, 3 * 1.15, 1e-9)
    equal(stats.chainRange, 1.6)
    equal(stats.chainHops, 2)
    equal(stats.chainFactor, 0.7)
    local state = chainFixture({
        { s = 0 }, { s = 1, slowUntilTick = 100 },
        { s = 2, history = { T01 = 0, T02 = 0 } },
    }, { "M17", "M18" }, stats.damage)
    local hits = damageEvents(assert(Battle.step(state, Battle.FIXED_DT)))
    close(hits[1].damage, 16.1, 1e-9)
    close(hits[2].damage, 16.1 * 0.7 * 1.3, 1e-9)
    close(hits[3].damage, 16.1 * 0.49 * 1.25, 1e-9)
    local extra = chainFixture({ { s = 0 }, { s = 1 } })
    extra.projectiles[1].behavior, extra.projectiles[1].sourceKind = "single", "extra"
    equal(#damageEvents(assert(Battle.step(extra, Battle.FIXED_DT))), 1,
        "existing additional single shots do not copy chain behavior")
end)

test("R7 Q06 W05 unlock is pure valid event gated and idempotent", function()
    local defs, meta = Content.create(), { unlockedTowerIds = { "T01", "T02", "T03", "T04" }, unlockedModuleIds = { "M01" }, custom = { keep = 7 } }
    local before = Rules.newRun(defs)
    local summary = { waveId = "W05", resultKind = "wave_complete", hp = 17, leaks = 0 }
    local candidate, events = assert(Rules.reduceCompletion(defs, before, summary))
    local unlocked, unlockEvents = Rules.reduceTowerUnlocks(meta, before, candidate, summary, events)
    equal(#unlocked.unlockedTowerIds, 5)
    equal(unlocked.unlockedTowerIds[5], "T05")
    equal(unlockEvents[1].towerId, "T05")
    equal(unlockEvents[1].waveId, "W05")
    equal(#meta.unlockedTowerIds, 4)
    equal(before.completedWaveIds.W05, nil)
    equal(unlocked.custom.keep, 7)
    equal(unlocked.unlockedModuleIds[1], "M01")
    equal(candidate.nextWaveIndex, 6)
    local duplicate, duplicateEvents = Rules.reduceCompletion(defs, candidate, summary)
    local again, newEvents = Rules.reduceTowerUnlocks(unlocked, candidate, duplicate, summary, duplicateEvents)
    equal(#again.unlockedTowerIds, 5)
    equal(#newEvents, 0)
    for _, variant in ipairs({
        { waveId = "W04", resultKind = "wave_complete", hp = 17 },
        { waveId = "W06", resultKind = "wave_complete", hp = 17 },
        { waveId = "W05", resultKind = "wave_complete", hp = 0 },
        { waveId = "W05", resultKind = "defeat", hp = 17 },
        { waveId = "W05", resultKind = "running", hp = 17 },
    }) do
        local unchanged, denied = Rules.reduceTowerUnlocks(meta, before, candidate, variant, events)
        equal(#unchanged.unlockedTowerIds, 4)
        equal(#denied, 0)
    end
    equal(#select(2, Rules.reduceTowerUnlocks(meta, before, candidate, summary, {})), 0)
end)

test("R7 Q07 boss unlock requires valid first W15 victory and no settlement", function()
    local defs = Content.create()
    local meta = { unlockedTowerIds = { "T01", "T02", "T03", "T04" } }
    local before = Rules.newRun(defs)
    local summary = { waveId = "W15", resultKind = "victory", resultReason = "boss_killed", hp = 1, tick = 100 }
    local candidate, events = Rules.reduceCompletion(defs, before, summary)
    equal(candidate.gold, before.gold)
    equal(candidate.completedWaveIds.W15, nil)
    equal(containsEvent(events, "wave_reward"), nil)
    local unlocked, unlockEvents = Rules.reduceTowerUnlocks(meta, before, candidate, summary, events)
    equal(unlocked.unlockedTowerIds[5], "T06")
    equal(unlockEvents[1].type, "tower_unlocked")
    equal(#select(2, Rules.reduceTowerUnlocks(unlocked, before, candidate, summary, events)), 0)
    equal(#select(2, Rules.reduceTowerUnlocks(meta, candidate, candidate, summary, events)), 0)
    for _, field in ipairs({ "hp", "waveId", "resultReason", "resultKind" }) do
        local invalid = Content.clone(summary)
        invalid[field] = ({ hp = 0, waveId = "W14", resultReason = "boss_escaped", resultKind = "defeat" })[field]
        equal(#select(2, Rules.reduceTowerUnlocks(meta, before, candidate, invalid, events)), 0)
    end
    equal(#select(2, Rules.reduceTowerUnlocks(meta, before, candidate, summary, {})), 0)
end)

test("R7 Q10 frozen tower pool rejects locked purchases atomically", function()
    local defs = Content.create()
    local run = Rules.newRun(defs)
    run.gold = 100
    run.frozenUnlockPool = { towerIds = { "T01", "T02", "T03", "T04" } }
    for _, id in ipairs({ "T05", "T06" }) do
        local candidate, _, reason = Rules.tryPurchaseTower(defs, run, id)
        equal(candidate, nil)
        equal(reason, "tower_not_in_run_pool")
        equal(run.gold, 100)
        equal(run.nextInstanceId, 3)
        equal(#run.towerInstances, 2)
        run.frozenUnlockPool.towerIds[#run.frozenUnlockPool.towerIds + 1] = id
        candidate = assert(Rules.tryPurchaseTower(defs, run, id))
        equal(candidate.gold, 88)
        equal(candidate.towerInstances[3].typeId, id)
        equal(candidate.towerInstances[3].paidGold, 12)
    end
    local _, _, reason = Rules.tryPurchaseTower(defs, run, "T99")
    equal(reason, "unknown_tower_type")
end)

test("M28 T01 I28 uses new survived W03-W14 and pre-reward gold boundary", function()
    local defs = Content.create()
    for _, case in ipairs({ { 2, 20, false }, { 3, 19, false }, { 3, 20, true }, { 14, 20, true } }) do
        local before = Rules.newRun(defs)
        before.gold, before.nextWaveIndex = case[2], case[1]
        local waveId = string.format("W%02d", case[1])
        local summary = { waveId = waveId, resultKind = "wave_complete", hp = 20, leaks = 0 }
        local after, events = Rules.reduceCompletion(defs, before, summary)
        local meta, unlocks = Rules.reduceModuleUnlocks(defs, {}, before, after, summary, events)
        equal(meta.unlockedModuleIds[1] == "M28", case[3])
        equal(#unlocks, (case[3] and 1 or 0) + (case[1] == 14 and 1 or 0))
        equal(events[1].reward.preRewardGold, case[2])
        equal(before.gold, case[2])
        local _, missing = Rules.reduceModuleUnlocks(defs, {}, before, after, summary, {})
        equal(#missing, 0, "completed id alone is not evidence")
        local again, duplicates = Rules.reduceCompletion(defs, after, summary)
        local _, duplicateUnlocks = Rules.reduceModuleUnlocks(defs, {}, after, again, summary, duplicates)
        equal(#duplicateUnlocks, 0)
        equal(again.gold, after.gold)
        local _, repeated = Rules.reduceModuleUnlocks(defs, meta, before, after, summary, events)
        equal(#repeated, 0)
    end
end)

test("M28 T02 no boss defeat incomplete or zero-hp ordinary reward or unlock", function()
    local defs = Content.create()
    local before = Rules.newRun(defs, { modules = { "M28" } })
    before.gold = 25
    for _, summary in ipairs({
        { waveId = "W15", resultKind = "victory", resultReason = "boss_killed", hp = 20 },
        { waveId = "W15", resultKind = "defeat", resultReason = "boss_escaped", hp = 20 },
        { waveId = "W03", resultKind = "defeat", resultReason = "hp_zero", hp = 0 },
    }) do
        local after, events = Rules.reduceCompletion(defs, before, summary)
        local meta, unlocks = Rules.reduceModuleUnlocks(defs, {}, before, after, summary, events)
        equal(after.gold, 25)
        equal(after.completedWaveIds[summary.waveId], nil)
        equal(#unlocks, 0)
        equal(#meta.unlockedModuleIds, 0)
    end
    equal(Rules.reduceCompletion(defs, before, { waveId = "W03", resultKind = "wave_complete", hp = 0 }), nil)
    equal(Rules.reduceCompletion(defs, before, { waveId = "W03", hp = 20 }), nil)
    equal(Rules.previewSettlement(defs, before, 15, 0).moduleById.M28, 0)
end)

test("M28 T03 ordinary interest uses one pre-reward snapshot without combat damage", function()
    local defs = Content.create()
    equal(defs.modulesById.M28.tier, "mid")
    equal(defs.modulesById.M28.price, 12)
    for _, waveIndex in ipairs({ 1, 2, 3, 14 }) do
        for _, case in ipairs({ { 0, 0 }, { 4, 0 }, { 5, 1 }, { 19, 3 }, { 20, 4 }, { 25, 4 } }) do
            local run = Rules.newRun(defs, { modules = { "M25", "M26", "M28", "M32" } })
            run.gold = case[1]
            local reward = Rules.previewSettlement(defs, run, waveIndex, 0)
            equal(reward.preRewardGold, case[1])
            equal(reward.moduleById.M28, case[2])
            equal(reward.modules, 2 + 2 + case[2] + 3)
            local candidate, events = Rules.reduceCompletion(defs, run,
                { waveId = string.format("W%02d", waveIndex), resultKind = "wave_complete", hp = run.hp, leaks = 0 })
            equal(candidate.gold - run.gold, reward.total)
            equal(events[1].reward.moduleById.M28, case[2])
        end
    end
    local without = oneTowerRun(defs, "T01", 2, 2)
    local with = Content.clone(without)
    with.modules = { "M28" }
    equal(Rules.projectStats(defs, with, with.towerInstances[1]).damage,
        Rules.projectStats(defs, without, without.towerInstances[1]).damage)
    local run = Rules.newRun(defs)
    run.gold = 20
    local _, reason = Rules.previewModulePurchase(defs, run, "M28")
    equal(reason, "module_not_in_frozen_pool")
    local candidate, _, buyReason = Rules.tryPurchaseModule(defs, run, "M28")
    equal(candidate, nil)
    equal(buyReason, "module_not_in_frozen_pool")
end)

test("M43 T01 T02 I43 uses actual combat-start occupied and empty slots only on new ordinary completion", function()
    local defs = Content.create()
    for _, waveIndex in ipairs({ 2, 3, 14, 15 }) do
        for capacity = 3, 6 do
            for count = 0, 4 do
                local ids = { "M25", "M26", "M01", "M02" }
                local modules = {}
                for i = 1, count do modules[i] = ids[i] end
                local before = Rules.newRun(defs, { modules = modules })
                before.gold, before.baseModuleSlots = 19, capacity
                local summary = { waveId = string.format("W%02d", waveIndex),
                    resultKind = waveIndex == 15 and "victory" or "wave_complete",
                    resultReason = waveIndex == 15 and "boss_killed" or nil, hp = 20, leaks = 0 }
                local candidate, events = assert(Rules.reduceCompletion(defs, before, summary))
                local meta, unlocks = Rules.reduceModuleUnlocks(defs, {}, before, candidate, summary, events)
                local expected = waveIndex >= 3 and waveIndex <= 14 and count >= 1 and capacity - count >= 2
                equal(#unlocks, (expected and 1 or 0) + (waveIndex == 14 and 1 or 0), "wave/capacity/count " .. waveIndex .. "/" .. capacity .. "/" .. count)
                equal(meta.unlockedModuleIds[1], expected and "M43" or waveIndex == 14 and "M46" or nil)
                equal(#before.modules, count)
                equal(before.baseModuleSlots, capacity)
            end
        end
    end
end)

test("M43 T01 T06 independent I28 I43 evaluators reject missing event duplicate and incomplete proof", function()
    local defs = Content.create()
    local before = Rules.newRun(defs, { modules = { "M25" } })
    before.gold = 20
    local summary = { waveId = "W03", resultKind = "wave_complete", hp = 20, leaks = 0 }
    local candidate, events = Rules.reduceCompletion(defs, before, summary)
    for _, old in ipairs({ {}, { "M28" }, { "M43" }, { "M28", "M43" } }) do
        local meta, unlocks = Rules.reduceModuleUnlocks(defs, { unlockedModuleIds = old }, before, candidate, summary, events)
        equal(table.concat(meta.unlockedModuleIds, ","), "M28,M43")
        equal(#unlocks, 2 - #old)
        if #old == 0 then equal(unlocks[1].moduleId, "M28"); equal(unlocks[2].moduleId, "M43") end
        equal(#select(2, Rules.reduceModuleUnlocks(defs, meta, before, candidate, summary, events)), 0)
    end
    for _, case in ipairs({
        { summary, {} },
        { { waveId = "W03", resultKind = "running", hp = 20 }, events },
        { { waveId = "W03", resultKind = "defeat", hp = 0 }, events },
        { { waveId = "W03", resultKind = "wave_complete", hp = 0 }, events },
        { summary, { { type = "wave_reward", waveId = "W02", reward = events[1].reward } } },
    }) do equal(#select(2, Rules.reduceModuleUnlocks(defs, {}, before, candidate, case[1], case[2])), 0) end
    local incomplete = Content.clone(candidate)
    incomplete.completedWaveIds.W03 = nil
    equal(#select(2, Rules.reduceModuleUnlocks(defs, {}, before, incomplete, summary, events)), 0)
    local duplicate, duplicateEvents = Rules.reduceCompletion(defs, candidate, summary)
    equal(#select(2, Rules.reduceModuleUnlocks(defs, {}, candidate, duplicate, summary, duplicateEvents)), 0)
    local unqualified = Content.clone(before)
    unqualified.modules = {}
    candidate.modules = { "M25" } -- End-state slots cannot qualify the start snapshot.
    equal(#select(2, Rules.reduceModuleUnlocks(defs, { unlockedModuleIds = { "M28" } }, unqualified, candidate, summary, events)), 0)
    before.gold = 19
    candidate, events = Rules.reduceCompletion(defs, before, summary)
    equal(Rules.reduceModuleUnlocks(defs, {}, before, candidate, summary, events).unlockedModuleIds[1], "M43")
end)

test("M43 T04 own-slot cap additive damage patch layer and purchase sale projections agree", function()
    local defs = Content.create()
    equal(defs.modulesById.M43.price, 12)
    local ids = { "M43", "M25", "M26", "M01" }
    for count = 0, 4 do
        local modules = {}
        for i = 1, count do modules[i] = ids[i] end
        local run = oneTowerRun(defs, "T01", 0, 2, {}, modules)
        local bonus = count == 0 and 0 or (4 - count) * 12
        local status = Rules.projectModuleStatus(defs, run, "M43", { towerInstanceId = 1 })
        equal(status.emptySlots, 4 - count)
        equal(status.installedModuleCount, count)
        equal(status.moduleCapacity, 4)
        equal(status.bonusPercentPoints, bonus)
        equal(status.cap, 36)
        equal(status.saleLosesGrowth, false)
        close(Rules.projectStats(defs, run, 1).damage, 12 * (1 + bonus / 100), 1e-9)
        run.towerInstances[1].placement = nil
        close(Rules.projectStats(defs, run, 1).damage, 12, 1e-9)
    end
    local run = oneTowerRun(defs, "T01", 0, 2, { "P_DAMAGE" }, { "M43", "M44" })
    run.gold = 20
    close(Rules.projectStats(defs, run, 1).damage, 12 * 1.15 * 1.49, 1e-9)
    run.baseModuleSlots = 6
    equal(Rules.projectModuleStatus(defs, run, "M43").bonusPercentPoints, 36)
    run = oneTowerRun(defs, "T01", 0, 2, {}, { "M25" })
    run.gold, run.frozenUnlockPool = 40, { moduleIds = { "M25", "M43", "M26" } }
    local preview = assert(Rules.previewModulePurchase(defs, run, "M43"))
    equal(preview.spareCircuitBefore.bonusPercentPoints, 0)
    equal(preview.spareCircuitAfter.emptySlots, 2)
    equal(preview.spareCircuitAfter.bonusPercentPoints, 24)
    run = assert(Rules.tryPurchaseModule(defs, run, "M43"))
    preview = assert(Rules.previewModulePurchase(defs, run, "M26"))
    equal(preview.spareCircuitBefore.bonusPercentPoints, 24)
    equal(preview.spareCircuitAfter.bonusPercentPoints, 12)
    run = assert(Rules.tryPurchaseModule(defs, run, "M26"))
    for _, id in ipairs({ "M25", "M43" }) do
        preview = assert(Rules.previewInventoryTransaction(defs, run, { phase = "SHOP", kind = "sell_module", moduleId = id }))
        equal(preview.spareCircuitBefore.bonusPercentPoints, 12)
        equal(preview.spareCircuitAfter.bonusPercentPoints, id == "M43" and 0 or 24)
    end
    run.frozenUnlockPool.moduleIds = { "M25" }
    equal(select(2, Rules.previewModulePurchase(defs, run, "M43")), "module_not_in_frozen_pool")
end)

test("M43 T05 real Battle firing projectile and hit preserve additive module damage", function()
    local defs = Content.create()
    for _, case in ipairs({ { {}, 12 }, { { "M43" }, 16.32 }, { { "M43", "M44" }, 17.88 } }) do
        local run = oneTowerRun(defs, "T01", 0, 2, {}, case[1])
        run.gold = 20
        local state = assert(Battle.new(defs, run, "W01"))
        state.enemies[1].hp, state.enemies[1].maxHp, state.enemies[1].baseSpeed = 1000, 1000, 0
        state.spawnSchedule, state.nextSpawnIndex = { state.spawnSchedule[1] }, 2
        local fired, hit, projectileDamage
        for _ = 1, 90 do
            local events = assert(Battle.step(state, Battle.FIXED_DT))
            fired = fired or containsEvent(events, "tower_fired")
            if state.projectiles[1] then projectileDamage = projectileDamage or state.projectiles[1].launchBaseDamage end
            hit = hit or containsEvent(events, "enemy_damaged")
            if hit then break end
        end
        close(assert(fired).launchDamage, case[2], 1e-9)
        close(assert(projectileDamage), case[2], 1e-9)
        close(assert(hit).damage, case[2], 1e-9)
        close(state.enemies[1].hp, 1000 - case[2], 1e-9)
    end
end)

test("M46 C01 I46 boundaries use committed start HP actual leaks and new ordinary completion", function()
    local defs = Content.create()
    local cases = {
        {1,1,1,0,false}, {2,5,5,0,false}, {3,1,1,0,true}, {3,5,5,0,true},
        {3,6,5,0,false}, {3,5,4,1,false}, {8,20,20,0,false}, {9,20,19,0,false},
        {9,20,20,0,true}, {14,20,20,1,true}, {14,5,4,0,true}, {15,1,1,0,false},
        {3,1,0,0,false}, {9,20,20,0,false,"defeat"}, {3,1,1,0,false,"incomplete"},
    }
    for _, case in ipairs(cases) do
        local before = Rules.newRun(defs)
        before.hp, before.gold, before.nextWaveIndex = case[2], 0, case[1]
        local summary = {waveId=string.format("W%02d",case[1]), hp=case[3], leaks=case[4],
            resultKind=case[6] or "wave_complete"}
        local after, events = Rules.reduceCompletion(defs, before, summary)
        local meta, unlocks = Rules.reduceModuleUnlocks(defs, {}, before, after, summary, events)
        equal(table.concat(meta.unlockedModuleIds, ","), case[5] and "M46" or "")
        equal(#unlocks, case[5] and 1 or 0)
        equal(before.hp, case[2], "unlock evaluation changed combatStart HP")
        equal(#select(2, Rules.reduceModuleUnlocks(defs, {}, before, after, summary, {})), 0)
        equal(#select(2, Rules.reduceModuleUnlocks(defs, meta, before, after, summary, events)), 0)
        if after then
            local again, duplicates = Rules.reduceCompletion(defs, after, summary)
            equal(#select(2, Rules.reduceModuleUnlocks(defs, {}, after, again, summary, duplicates)), 0)
        end
    end
end)

test("M46 C02 live HP installed deployment and additive patch module damage stay distinct", function()
    local defs = Content.create()
    equal(defs.modulesById.M46.price,12); equal(defs.modulesById.M46.tier,"mid")
    for _, hp in ipairs({0,1,5,6}) do
        for _, placed in ipairs({false,true}) do
            for _, installed in ipairs({false,true}) do
                local run = oneTowerRun(defs,"T01",placed and 0 or nil,2,{"P_DAMAGE"},
                    installed and {"M43","M44","M46"} or {"M43","M44"})
                run.hp, run.gold = hp,20
                local stats = assert(Rules.projectStats(defs,run,1))
                local expected = placed and (installed and 0.12 or 0.24)+0.25 or 0
                if placed and installed and hp>=1 and hp<=5 then expected=expected+0.40 end
                close(stats.damage,12*1.15*(1+expected),1e-9)
                local status = assert(Rules.projectModuleStatus(defs,run,"M46",{towerInstanceId=1}))
                equal(status.active,installed and placed and hp>=1 and hp<=5)
                equal(status.bonusPercentPoints,status.active and 40 or 0)
                equal(run.hp,hp,"projection healed HP")
            end
        end
    end
end)

test("M46 C03 actual Battle leak updates live clone before fire and HP zero still loses", function()
    local defs = Content.create()
    for _, hp in ipairs({6,1}) do
        local run=oneTowerRun(defs,"T01",0,2,{}, {"M46"}); run.hp=hp
        local battle=assert(Battle.new(defs,run,"W01"))
        battle.spawnSchedule,battle.nextSpawnIndex={},1
        local target=battle.enemies[1]; target.hp,target.maxHp,target.baseSpeed=1000,1000,0
        local leak=Content.clone(target); leak.enemyId,leak.spawnOrdinal,leak.s="leak",2,leak.totalLength
        battle.enemies[2],battle.enemyById.leak=leak,leak
        battle.towers[1].charge=1
        local events=assert(Battle.step(battle,Battle.FIXED_DT))
        equal(battle.hp,hp-1); equal(battle.run.hp,hp-1); equal(run.hp,hp)
        local shot=assert(containsEvent(events,"tower_fired"))
        close(shot.launchDamage,hp==6 and 16.8 or 12,1e-9)
        equal(Rules.projectModuleStatus(defs,battle.run,"M46").bonusPercentPoints,hp==6 and 40 or 0)
        if hp==1 then
            equal(battle.result.kind,"defeat"); equal(battle.result.reason,"hp_zero")
            equal(#battle.projectiles,0)
        else
            local projectile=assert(battle.projectiles[1]); close(projectile.launchBaseDamage,16.8,1e-9)
            -- The next projectile retains its launch damage even after HP changes.
            battle.hp,battle.run.hp=6,6
            local hit
            for _=1,90 do hit=hit or containsEvent(assert(Battle.step(battle,Battle.FIXED_DT)),"enemy_damaged"); if hit then break end end
            close(assert(hit).damage,16.8,1e-9)
        end
    end
    local bossRun=oneTowerRun(defs,"T01",0,2,{}, {"M46"}); bossRun.hp=5
    local boss=assert(Battle.new(defs,bossRun,"W15")); boss.spawnSchedule,boss.nextSpawnIndex={},1
    local enemy=boss.enemies[1]; enemy.boss,enemy.s=true,enemy.totalLength
    assert(Battle.step(boss,Battle.FIXED_DT)); equal(boss.result.reason,"boss_escaped"); equal(boss.hp,5)
end)

test("M46 C04 transaction projections rights guards and six old Save versions preserve state", function()
    local Save,Json,Game=require("src.save"),require("src.json"),require("src.game")
    local defs=Content.create()
    local run=oneTowerRun(defs,"T01",0,2,{},{}); run.hp,run.gold=5,40
    run.frozenUnlockPool={moduleIds={"M46"}}
    local draft=assert(Rules.previewModulePurchase(defs,run,"M46"))
    equal(draft.emergencyBefore.bonusPercentPoints,0); equal(draft.emergencyAfter.bonusPercentPoints,40)
    local bought=assert(Rules.tryPurchaseModule(defs,run,"M46")); equal(#bought.modules,1)
    local sale=assert(Rules.previewInventoryTransaction(defs,bought,{kind="sell_module",moduleId="M46",phase="SHOP"}))
    equal(sale.emergencyBefore.bonusPercentPoints,40); equal(sale.emergencyAfter.bonusPercentPoints,0)
    local sold=assert(Rules.tryInventoryTransaction(defs,bought,{kind="sell_module",moduleId="M46",phase="SHOP"}))
    equal(sold.acquiredModuleIds.M46,true); equal(sold.hp,5)
    equal(select(2,Rules.previewModulePurchase(defs,sold,"M46")),"duplicate_module")
    for _, version in ipairs({"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1"}) do
        local storage={files={},writes=0}
        function storage:read(path) return self.files[path],nil,self.files[path] and nil or "missing" end
        function storage:write(path,bytes) self.writes=self.writes+1; self.files[path]=bytes; return true end
        local checkpoint=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",
            checksum=Save.adler32,checksumName="adler32",validatePayload=Save.createLivePayloadValidator(defs),
            migrations=Save.createRun002Migrations(defs)})
        Game.new({defs=defs,checkpointStore=checkpoint,identityProvider=function() return {runId="m46-old",shopSeed=204} end})
        local payload=assert(checkpoint:loadCheckpoint().payload); local old=payload.runState
        old.contentVersion,old.hp,old.gold=version,5,37
        local early=version=="DR-SLICE-001-r2" or version=="DR-RUN-002-r1"
        old.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        old.shopState.offers.module="M02"
        old.modules={{moduleId="M01",paidGold=8,growth=0}}; old.acquiredModuleIds={M01=true}
        payload.metaState.unlockedModuleIds={}
        if version=="DR-SLICE-001-r2" then old.developmentComplete=false; old.shopState.fixtureIndex=1 end
        if not early then
            old.modules[2]={moduleId="M33",paidGold=12,growth=6}; old.acquiredModuleIds.M33=true
            old.frozenUnlockPool.moduleIds[#old.frozenUnlockPool.moduleIds+1]="M33"
            old.nextWaveIndex,old.shopState.visitId=7,"S02"
            old.completedWaveIds=Json.object()
            if version=="DR-TOWER-U2-r1" or version=="DR-MOD-I28-r1" or version=="DR-MOD-I43-r1" then
                payload.metaState.unlockedTowerIds[#payload.metaState.unlockedTowerIds+1]="T05"
            end
            for i=1,6 do old.completedWaveIds[string.format("W%02d",i)]=true end
            payload.checkpointKind,payload.resumeDescriptor.kind,payload.resumeDescriptor.waveIndex="waveComplete","waveComplete",7
        end
        if version=="DR-MOD-I28-r1" or version=="DR-MOD-I43-r1" then
            payload.metaState.unlockedModuleIds={"M28"}; old.frozenUnlockPool.moduleIds[#old.frozenUnlockPool.moduleIds+1]="M28"
        end
        if version=="DR-MOD-I43-r1" then
            payload.metaState.unlockedModuleIds[2]="M43"; old.frozenUnlockPool.moduleIds[#old.frozenUnlockPool.moduleIds+1]="M43"
        end
        local frozen,shop,modules,progress=Json.encode(old.frozenUnlockPool),Json.encode(old.shopState),Json.encode(old.modules),Json.encode(old.completedWaveIds)
        local json=Json.encode(payload)
        local bytes=Json.encode({schemaVersion=1,generation=34,contentVersion=version,engineTarget="love-11.5",
            checksumAlgorithm="adler32",payloadJson=json,payloadChecksum=Save.adler32(json)})
        storage.files={['save-b.json']=bytes}; local writes=storage.writes
        local loaded=checkpoint:loadCheckpoint(); equal(loaded.status,"migrated",version)
        equal(storage.writes,writes); equal(storage.files['save-b.json'],bytes)
        local restored=loaded.payload.runState
        equal(restored.hp,5); equal(restored.gold,37); equal(Json.encode(restored.modules),modules)
        equal(Json.encode(restored.shopState),shop); equal(Json.encode(restored.completedWaveIds),progress)
        equal(Json.encode(restored.frozenUnlockPool),frozen)
        equal(Json.encode(loaded.payload.metaState.unlockedModuleIds),Json.encode(payload.metaState.unlockedModuleIds))
        local bad=Content.clone(loaded.payload); bad.runState.frozenUnlockPool.moduleIds[#bad.runState.frozenUnlockPool.moduleIds+1]="M46"
        equal(Save.createLivePayloadValidator(defs)(bad),nil,"locked M46 pool accepted")
        bad=Content.clone(loaded.payload); bad.runState.shopState.offers.module="M46"
        equal(Save.createLivePayloadValidator(defs)(bad),nil,"locked M46 offer accepted")
    end
end)

test("M41 C01 I41 requires distinct mid modules throughout new survived W06-W14", function()
    local defs, Json = Content.create(), require("src.json")
    local function qualifies(index, modules, kind, hp)
        local before = Rules.newRun(defs, {modules=modules})
        before.nextWaveIndex, before.gold = index, 0
        local summary = {waveId=string.format("W%02d",index),resultKind=kind or "wave_complete",hp=hp or 19,leaks=1,
            resultReason=kind=="victory" and "boss_killed" or "fixture_defeat"}
        local after,events=Rules.reduceCompletion(defs,before,summary)
        if not after then return false end
        local meta,unlocks=Rules.reduceModuleUnlocks(defs,{},before,after,summary,events)
        return containsEvent(unlocks,"module_unlocked",function(e) return e.moduleId=="M41" end)~=nil,
            before,after,summary,events,meta
    end
    for _,case in ipairs({{5,false},{6,true},{14,true},{15,false}}) do
        equal(qualifies(case[1],{"M03","M08"},case[1]==15 and "victory" or nil),case[2])
    end
    for _,modules in ipairs({{}, {"M03"}, {"M03","M03"}, {"M25","M06"}, {"M41","M03"}, {"M03","M99"}}) do
        equal(qualifies(6,modules),false)
    end
    equal(qualifies(6,{{moduleId="M03",paidGold=1,growth=0},{moduleId="M08",paidGold=999,growth=0}}),true)
    equal(qualifies(6,{"M03","M08"},"defeat",0),false)
    equal(qualifies(6,{"M03","M08"},"wave_complete",0),false)
    equal(qualifies(6,{"M03","M08"},"incomplete",19),false)
    local _,before,after,summary,events,meta=qualifies(6,{"M03","M08"})
    local source=Json.encode(before)
    equal(#select(2,Rules.reduceModuleUnlocks(defs,{},before,after,summary,{})),0)
    local without=Content.clone(after); without.completedWaveIds.W06=nil
    equal(#select(2,Rules.reduceModuleUnlocks(defs,{},before,without,summary,events)),0)
    local _,again=Rules.reduceModuleUnlocks(defs,meta,before,after,summary,events); equal(#again,0)
    local duplicated,duplicateEvents=Rules.reduceCompletion(defs,after,summary)
    equal(#select(2,Rules.reduceModuleUnlocks(defs,{},after,duplicated,summary,duplicateEvents)),0)
    local lateBefore=Content.clone(before); lateBefore.modules={"M03"}
    local lateMeta=Rules.reduceModuleUnlocks(defs,{},lateBefore,after,summary,events)
    equal(lateMeta.unlockedModuleIds[1],"M43", "completion-only module addition granted I41")
    equal(Json.encode(before),source)
end)

test("M41 C02 damage is additive and excludes self nonmid and undeployed towers", function()
    local defs,Json=Content.create(),require("src.json")
    equal(defs.modulesById.M41.tier,"high"); equal(defs.modulesById.M41.price,16)
    local definition=Json.encode(defs)
    for count=0,5 do
        local ids={"M08","M09","M17","M18","M32"}
        local modules={"M41"}; for i=1,count do modules[#modules+1]=ids[i] end
        local run=oneTowerRun(defs,"T01",0,2,{},modules); run.baseModuleSlots=6
        local stats=Rules.projectStats(defs,run,1)
        close(stats.damage,12*(1+math.min(32,8*count)/100),1e-9)
        local status=Rules.projectModuleStatus(defs,run,"M41",{towerInstanceId=1})
        equal(status.otherMidModuleCount,count); equal(status.bonusPercentPoints,math.min(32,8*count))
        equal(status.active,count>0); equal(status.selectedTowerQualifies,count>0)
        run.towerInstances[1].placement=nil
        close(Rules.projectStats(defs,run,1).damage,12,1e-9)
        equal(Rules.projectModuleStatus(defs,run,"M41",{towerInstanceId=1}).selectedTowerQualifies,false)
        equal(Rules.projectModuleStatus(defs,run,"M41").active,false)
    end
    local run=oneTowerRun(defs,"T01",0,2,{"P_DAMAGE"},{{moduleId="M41",paidGold=16,growth=0},
        {moduleId="M33",paidGold=12,growth=6},"M43","M46"})
    run.hp=5
    local bytes=Json.encode(run); local stats=Rules.projectStats(defs,run,1)
    -- Three other mid IDs (24), growth (6), no empty slot, low-HP effect (40).
    close(stats.damage,12*1.15*1.70,1e-9); close(stats.factors.moduleDamage,1.70,1e-9)
    close(stats.attackRate,1,1e-9); close(stats.range,3,1e-9); equal(Json.encode(run),bytes)
    local default=oneTowerRun(defs,"T01",0,2,{}, {"M41","M08","M17","M18"})
    equal(Rules.moduleSlots(default).emptySlots,0); equal(Rules.projectModuleStatus(defs,default,"M41").bonusPercentPoints,24)
    local duplicates=oneTowerRun(defs,"T01",0,2,{}, {"M41","M08",{moduleId="M08"},"M99","M25"})
    equal(Rules.projectModuleStatus(defs,duplicates,"M41").otherMidModuleCount,1)
    close(Rules.projectStats(defs,duplicates,1).damage,12*1.08,1e-9)
    table.remove(duplicates.modules,1); close(Rules.projectStats(defs,duplicates,1).damage,12,1e-9)
    equal(Json.encode(defs),definition)
end)

test("M41 C03 purchase and sale project mid link without mutating run or rights", function()
    local defs,Json=Content.create(),require("src.json")
    local run=oneTowerRun(defs,"T01",0,2,{}, {"M08"}); run.gold=80
    run.frozenUnlockPool={moduleIds={"M08","M41","M17","M25","M06"}}
    run.acquiredModuleIds={M08=true}
    local bytes=Json.encode(run)
    local draft=assert(Rules.previewModulePurchase(defs,run,"M41"))
    equal(draft.midLinkBefore.bonusPercentPoints,0); equal(draft.midLinkAfter.bonusPercentPoints,8)
    equal(draft.paidGold,16); equal(draft.moduleCapacityAfter,4); equal(draft.installedModuleCountAfter,2)
    equal(Json.encode(run),bytes)
    local bought=assert(Rules.tryPurchaseModule(defs,run,"M41")); equal(bought.gold,64)
    equal(bought.modules[2].paidGold,16); equal(bought.acquiredModuleIds.M41,true)
    local mid=assert(Rules.previewModulePurchase(defs,bought,"M17"))
    equal(mid.midLinkBefore.bonusPercentPoints,8); equal(mid.midLinkAfter.bonusPercentPoints,16)
    for _,id in ipairs({"M25","M06"}) do
        local other=assert(Rules.previewModulePurchase(defs,bought,id))
        equal(other.midLinkAfter.otherMidModuleCount,1); equal(other.midLinkAfter.bonusPercentPoints,8)
    end
    local installed=assert(Rules.tryPurchaseModule(defs,bought,"M17"))
    local sale=assert(Rules.previewInventoryTransaction(defs,installed,{phase="SHOP",kind="sell_module",moduleId="M17"}))
    equal(sale.midLinkBefore.bonusPercentPoints,16); equal(sale.midLinkAfter.bonusPercentPoints,8)
    local selfSale=assert(Rules.previewInventoryTransaction(defs,installed,{phase="SHOP",kind="sell_module",moduleId="M41"}))
    equal(selfSale.refundGold,8); equal(selfSale.midLinkAfter.bonusPercentPoints,0)
    local sold=assert(Rules.tryInventoryTransaction(defs,installed,{phase="SHOP",kind="sell_module",moduleId="M41"}))
    equal(sold.acquiredModuleIds.M41,true); equal(select(2,Rules.previewModulePurchase(defs,sold,"M41")),"duplicate_module")
    equal(select(2,Rules.previewInventoryTransaction(defs,installed,{phase="COMBAT",kind="sell_module",moduleId="M41"})),"shop_required")
    local bad=Content.clone(run); bad.frozenUnlockPool.moduleIds={"M08"}
    equal(select(2,Rules.previewModulePurchase(defs,bad,"M41")),"module_not_in_frozen_pool")
    bad=Content.clone(run); bad.gold=15
    equal(select(2,Rules.previewModulePurchase(defs,bad,"M41")),"insufficient_gold")
    bad=Content.clone(run); bad.baseModuleSlots=1
    equal(select(2,Rules.previewModulePurchase(defs,bad,"M41")),"module_slots")
    equal(Json.encode(run),bytes)
end)

test("M41 C04 validators preserve seven historical versions and reject illicit M41 references", function()
    local Save,Json,Game=require("src.save"),require("src.json"),require("src.game")
    local defs=Content.create(); local migrations=Save.createRun002Migrations(defs)
    for _,version in ipairs({"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1"}) do
        local storage={files={},writes=0}
        function storage:read(path) return self.files[path],nil,self.files[path] and nil or "missing" end
        function storage:write(path,bytes) self.writes=self.writes+1;self.files[path]=bytes;return true end
        local save=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",checksum=Save.adler32,
            checksumName="adler32",validatePayload=Save.createLivePayloadValidator(defs),migrations=migrations})
        Game.new({defs=defs,checkpointStore=save,identityProvider=function() return {runId="m41-legacy",shopSeed=204} end})
        local payload=save:loadCheckpoint().payload; local run=payload.runState
        run.contentVersion,run.hp,run.gold=version,5,37
        run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.shopState.offers.module="M02"; run.modules={{moduleId="M01",paidGold=8,growth=0}}; run.acquiredModuleIds={M01=true}
        payload.metaState.unlockedModuleIds={}
        if version=="DR-SLICE-001-r2" then run.shopState.fixtureIndex=1 end
        local later=version=="DR-MOD-I28-r1" or version=="DR-MOD-I43-r1" or version=="DR-MOD-I46-r1"
        if later then
            payload.metaState.unlockedTowerIds[#payload.metaState.unlockedTowerIds+1]="T05"
            payload.metaState.unlockedModuleIds={"M28"};run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M28"
        end
        if version=="DR-MOD-I43-r1" or version=="DR-MOD-I46-r1" then
            payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]="M43"
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M43"
        end
        if version=="DR-MOD-I46-r1" then
            payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]="M46"
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M46"
            run.modules[2]={moduleId="M33",paidGold=9,growth=6}; run.acquiredModuleIds.M33=true
            run.modules[3]={moduleId="M08",paidGold=11,growth=0};run.acquiredModuleIds.M08=true
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33"
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M08"
            run.nextWaveIndex,run.shopState.visitId=7,"S02";run.completedWaveIds=Json.object()
            for i=1,6 do run.completedWaveIds[string.format("W%02d",i)]=true end
            payload.checkpointKind,payload.resumeDescriptor.kind,payload.resumeDescriptor.waveIndex="waveComplete","waveComplete",7
        end
        assert(migrations[version].validatePayload(payload))
        local bad=Content.clone(payload);bad.runState.shopState.offers.module="M41"
        equal(migrations[version].validatePayload(bad),nil,"historical M41 accepted")
        local frozen,shop,modules,progress,rights=Json.encode(run.frozenUnlockPool),Json.encode(run.shopState),Json.encode(run.modules),Json.encode(run.completedWaveIds),Json.encode(payload.metaState.unlockedModuleIds)
        local json=Json.encode(payload);local bytes=Json.encode({schemaVersion=1,generation=34,contentVersion=version,
            engineTarget="love-11.5",checksumAlgorithm="adler32",payloadJson=json,payloadChecksum=Save.adler32(json)})
        storage.files={['save-b.json']=bytes};local writes=storage.writes
        local loaded=save:loadCheckpoint();equal(loaded.status,"migrated",version);equal(storage.writes,writes)
        equal(storage.files['save-b.json'],bytes);equal(loaded.payload.runState.gold,37);equal(loaded.payload.runState.hp,5)
        equal(Json.encode(loaded.payload.runState.frozenUnlockPool),frozen);equal(Json.encode(loaded.payload.runState.shopState),shop)
        equal(Json.encode(loaded.payload.runState.modules),modules);equal(Json.encode(loaded.payload.runState.completedWaveIds),progress)
        equal(Json.encode(loaded.payload.metaState.unlockedModuleIds),rights)
        local current=Content.clone(loaded.payload); local valid=Save.createLivePayloadValidator(defs)
        current.metaState.unlockedModuleIds[#current.metaState.unlockedModuleIds+1]="M41"
        assert(valid(current)) -- Earned right, current frozen pool unchanged.
        local pooled=Content.clone(current);pooled.runState.frozenUnlockPool.moduleIds[#pooled.runState.frozenUnlockPool.moduleIds+1]="M41"
        assert(valid(pooled));pooled.runState.shopState.offers.module="M41";assert(valid(pooled))
        local unlawful=Content.clone(loaded.payload);unlawful.runState.frozenUnlockPool.moduleIds[#unlawful.runState.frozenUnlockPool.moduleIds+1]="M41"
        equal(valid(unlawful),nil)
        unlawful=Content.clone(current);unlawful.runState.shopState.offers.module="M41";equal(valid(unlawful),nil)
        pooled.runState.shopState.offers.module="M02";pooled.runState.modules[#pooled.runState.modules+1]={moduleId="M41",paidGold=16,growth=0}
        equal(valid(pooled),nil);pooled.runState.acquiredModuleIds.M41=true;assert(valid(pooled))
        pooled.runState.shopState.offers.module="M41";equal(valid(pooled),nil)
    end
end)

local function m42Entry(id, paid, growth)
    return { moduleId = id, paidGold = paid, growth = growth or 0 }
end

test("M42 C01 paid module value and I42 completion reject invalid ambiguous and historical evidence", function()
    local defs, Json = Content.create(), require("src.json")
    local function qualifies(index, modules, change)
        local before = Rules.newRun(defs, { modules = modules, gold = 0, hp = 19 })
        before.nextWaveIndex = index
        local summary = { waveId = string.format("W%02d", index), resultKind = "wave_complete", hp = 19, leaks = 1 }
        local after, events = Rules.reduceCompletion(defs, before, summary)
        if change then change(before, after, summary, events) end
        local meta, unlocked = Rules.reduceModuleUnlocks(defs, { unlockedModuleIds = {} }, before, after, summary, events)
        return containsEvent(unlocked, "module_unlocked", function(e) return e.moduleId == "M42" end) ~= nil, meta
    end
    for _, paid in ipairs({ 0, 39, 40, 41 }) do
        local modules = { m42Entry("M03", paid), m42Entry("M08", 0) }
        local run = Rules.newRun(defs, { modules = modules })
        local encoded = Json.encode(run)
        equal(assert(Rules.modulePurchaseValue(defs, run)).paidGoldTotal, paid)
        equal(Json.encode(run), encoded)
        for _, index in ipairs({ 8, 9, 14, 15 }) do equal(qualifies(index, modules), paid >= 40 and index >= 9 and index <= 14) end
    end
    local modules = { m42Entry("M03", 20), m42Entry("M08", 20) }
    for _, change in ipairs({
        function(_, _, s) s.resultKind = "defeat" end,
        function(_, _, s) s.hp = 0 end,
        function(_, a) a.completedWaveIds.W09 = nil end,
        function(b) b.completedWaveIds.W09 = true end,
        function(_, a) a.nextWaveIndex = 9 end,
        function(_, _, _, e) for i = #e, 1, -1 do table.remove(e, i) end end,
        function(b) b.modules[1].paidGold = 0 end,
    }) do equal(qualifies(9, modules, change), false) end
    local _, preserved = qualifies(9, modules)
    equal(table.concat(preserved.unlockedModuleIds, ","), "M41,M42,M43")
    -- Only nominal producer purchases have the two-module <=32 bound.
    for _, left in ipairs(defs.modules) do for _, right in ipairs(defs.modules) do
        if left.id ~= right.id then
            equal(qualifies(9, { m42Entry(left.id, left.price), m42Entry(right.id, right.price) }), false)
        end
    end end
    for _, invalid in ipairs({ "M03", {}, { moduleId = "M99", paidGold = 40 }, { moduleId = "M03", paidGold = -1 },
        { id = "M03", paidGold = 0.5 }, { id = "M03", paidGold = math.huge }, { id = "M03", paidGold = 0/0 } }) do
        local value, reason = Rules.modulePurchaseValue(defs, { modules = { invalid, m42Entry("M08", 40) } })
        equal(value, nil); assert(reason)
        equal(qualifies(9, { invalid, m42Entry("M08", 40) }), false)
    end
    equal(Rules.modulePurchaseValue(defs, { modules = { m42Entry("M03", 40), m42Entry("M03", 40) } }), nil)
    equal(Rules.modulePurchaseValue(defs, { modules = { [2] = m42Entry("M03", 40) } }), nil)
    local self = { modules = { m42Entry("M42", 16), { id = "M03", paidGold = 24 } } }
    equal(Rules.modulePurchaseValue(defs, self).paidGoldTotal, 40)
    equal(Rules.modulePurchaseValue(defs, self, "M42").paidGoldTotal, 24)
    self.modules[1].paidGold = nil; equal(Rules.modulePurchaseValue(defs, self, "M42"), nil)
end)

test("M42 C02 asset damage floors recorded self excluded value and stays additive deployed only", function()
    local defs = Content.create()
    equal(defs.modulesById.M42.tier, "high"); equal(defs.modulesById.M42.price, 16)
    for _, paid in ipairs({ 0, 3, 4, 7, 8, 48, 59, 60, 64 }) do
        local run = oneTowerRun(defs, "T01", 0, 2, {}, { m42Entry("M42", 999), m42Entry("M25", paid) })
        run.gold = 999; run.towerInstances[1].paidGold = 999
        local expected = math.min(30, math.floor(paid / 4) * 2)
        local status = assert(Rules.projectModuleStatus(defs, run, "M42", { towerInstanceId = 1 }))
        equal(status.otherModulePaidGold, paid); equal(status.bonusPercentPoints, expected); equal(status.cap, 30)
        close(Rules.projectStats(defs, run, 1).damage, 12 * (1 + expected/100), 1e-9)
        run.towerInstances[1].placement = nil
        close(Rules.projectStats(defs, run, 1).damage, 12, 1e-9); equal(Rules.projectModuleStatus(defs, run, "M42").active, false)
        run.modules[1].paidGold = nil
        equal(Rules.projectModuleStatus(defs, run, "M42").bonusPercentPoints, 0)
    end
    local nominal = oneTowerRun(defs, "T01", 0, 2, {}, { m42Entry("M42", 16), m42Entry("M06", 16), m42Entry("M13", 16), m42Entry("M41", 16) })
    equal(Rules.projectModuleStatus(defs, nominal, "M42").bonusPercentPoints, 24)
    -- Current valid records may reach the cap within base4; no legacy pool expansion.
    local recorded = Content.clone(nominal)
    for i = 2, 4 do recorded.modules[i].paidGold = 20 end
    recorded.frozenUnlockPool = { moduleIds = { "M06", "M13", "M41", "M42" } }
    recorded.acquiredModuleIds = { M06 = true, M13 = true, M41 = true, M42 = true }
    equal(Rules.moduleSlots(recorded).moduleCapacity, 4)
    equal(Rules.projectModuleStatus(defs, recorded, "M42").bonusPercentPoints, 30)
    recorded.baseModuleSlots = 6
    recorded.modules[#recorded.modules+1] = m42Entry("M08", 20)
    equal(Rules.projectModuleStatus(defs, recorded, "M42").bonusPercentPoints, 30)
    local linked = oneTowerRun(defs, "T01", 0, 2, { "P_DAMAGE" }, { m42Entry("M42",16), m42Entry("M41",16), m42Entry("M43",12), m42Entry("M46",12) })
    linked.hp = 5
    close(Rules.projectStats(defs, linked, 1).factors.moduleDamage, 1 + 0.20 + 0.16 + 0.40, 1e-9)
    close(Rules.projectStats(defs, linked, 1).damage, 12 * 1.15 * 1.76, 1e-9)
    table.remove(linked.modules,1)
    equal(Rules.projectModuleStatus(defs, linked, "M42").bonusPercentPoints, 0)
end)

test("M42 C03 purchase sale projections preserve paid history other effects and exact capacity contracts", function()
    local defs, Json = Content.create(), require("src.json")
    local run = oneTowerRun(defs,"T01",0,2,{}, {m42Entry("M03",20),m42Entry("M41",16),m42Entry("M43",12)})
    run.gold,run.hp = 100,5; run.frozenUnlockPool = {moduleIds = {"M03","M41","M42","M43","M46","M28","M06"}}
    run.acquiredModuleIds = {M03=true,M41=true,M43=true}
    local before = Json.encode(run)
    local buy = assert(Rules.previewModulePurchase(defs,run,"M42"))
    equal(buy.assetLinkBefore.bonusPercentPoints,0); equal(buy.assetLinkAfter.otherModulePaidGold,48)
    equal(buy.assetLinkAfter.bonusPercentPoints,24); equal(buy.spareCircuitAfter.bonusPercentPoints,0)
    equal(Json.encode(run),before)
    local bought = assert(Rules.tryPurchaseModule(defs,run,"M42")); equal(bought.modules[4].paidGold,16)
    local sale = assert(Rules.previewInventoryTransaction(defs,bought,{phase="SHOP",kind="sell_module",moduleId="M03"}))
    equal(sale.paidGold,20); equal(sale.refundGold,10); equal(sale.assetLinkAfter.otherModulePaidGold,28)
    equal(sale.midLinkBefore.otherMidModuleCount,2); equal(sale.midLinkAfter.otherMidModuleCount,1)
    local selfSale = assert(Rules.previewInventoryTransaction(defs,bought,{phase="SHOP",kind="sell_module",moduleId="M42"}))
    equal(selfSale.assetLinkAfter.bonusPercentPoints,0)
    local sold = assert(Rules.tryInventoryTransaction(defs,bought,{phase="SHOP",kind="sell_module",moduleId="M42"}))
    equal(sold.acquiredModuleIds.M42,true); equal(select(2,Rules.previewModulePurchase(defs,sold,"M42")),"duplicate_module")
    equal(select(2,Rules.previewInventoryTransaction(defs,bought,{phase="COMBAT",kind="sell_module",moduleId="M42"})),"shop_required")
    local empty = Content.clone(run);empty.modules={};empty.acquiredModuleIds={};empty.gold=0
    equal(select(2,Rules.previewModulePurchase(defs,empty,"M42")),"insufficient_gold")
    empty.gold=100;empty.frozenUnlockPool.moduleIds={}
    equal(select(2,Rules.previewModulePurchase(defs,empty,"M42")),"module_not_in_frozen_pool")
    local deposit = Content.clone(sold);deposit.gold=17;deposit.modules={m42Entry("M42",16)};deposit.acquiredModuleIds={M42=true}
    local dep = assert(Rules.previewModulePurchase(defs,deposit,"M28"))
    equal(dep.depositBefore.estimatedGold,0); equal(dep.depositAfter.preRewardGold,5); equal(dep.depositAfter.estimatedGold,1)
    local capacity = Content.clone(deposit);capacity.gold=100;capacity.towerInstances={}
    for i=1,6 do capacity.towerInstances[i]={instanceId=i,typeId="T01",paidGold=0,patchIds={"P_DAMAGE"},placement={x=i,y=0}} end
    local preview=assert(Rules.previewModulePurchase(defs,capacity,"M06"));equal(preview.requiredRecallCount,2);equal(preview.canCommit,false)
    equal(select(3,Rules.tryPurchaseModule(defs,capacity,"M06",{1})),"recall_count_mismatch")
    local changed=assert(Rules.tryPurchaseModule(defs,capacity,"M06",{1,2}))
    equal(changed.towerInstances[1].placement,nil);equal(changed.towerInstances[1].patchIds[1],"P_DAMAGE")
    equal(changed.modules[2].paidGold,16);equal(preview.assetLinkAfter.otherModulePaidGold,16)
end)

test("M42 C04 Save validates five rights and preserves eight historical module versions", function()
    local Save,Json,Game=require("src.save"),require("src.json"),require("src.game")
    local defs=Content.create();local migrations=Save.createRun002Migrations(defs)
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1"}
    for index,version in ipairs(versions) do
        local storage={files={},writes=0}
        function storage:read(path) return self.files[path],nil,self.files[path] and nil or "missing" end
        function storage:write(path,bytes) self.writes=self.writes+1;self.files[path]=bytes;return true end
        local save=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",checksum=Save.adler32,checksumName="adler32",validatePayload=Save.createLivePayloadValidator(defs),migrations=migrations})
        Game.new({defs=defs,checkpointStore=save,identityProvider=function() return {runId="m42-legacy",shopSeed=204} end})
        local payload=save:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion,run.hp,run.gold=version,5,37
        run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={m42Entry("M01",8)};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02"
        payload.metaState.unlockedModuleIds={}
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then
            run.modules[2]=m42Entry("M33",9,6);run.acquiredModuleIds.M33=true
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33"
        end
        if index>=5 then payload.metaState.unlockedModuleIds={"M28"};run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M28" end
        if index>=6 then payload.metaState.unlockedModuleIds[2]="M43";run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M43" end
        if index>=7 then payload.metaState.unlockedModuleIds[3]="M46";run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M46" end
        if index==8 then payload.metaState.unlockedModuleIds[4]="M41";run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M41" end
        assert(migrations[version].validatePayload(payload))
        local bad=Content.clone(payload);bad.runState.frozenUnlockPool.moduleIds[#bad.runState.frozenUnlockPool.moduleIds+1]="M42"
        if version=="DR-SLICE-001-r2" then
            equal(Save.createLivePayloadValidator(defs)(migrations[version].migrate(bad)),nil)
        else equal(migrations[version].validatePayload(bad),nil) end
        local offer=Content.clone(payload);offer.runState.shopState.offers.module="M42"
        equal(migrations[version].validatePayload(offer),nil)
        bad=Content.clone(payload);bad.metaState.unlockedModuleIds[#bad.metaState.unlockedModuleIds+1]="M42";equal(migrations[version].validatePayload(bad),nil)
        local json=Json.encode(payload);local bytes=Json.encode({schemaVersion=1,generation=34,contentVersion=version,engineTarget="love-11.5",checksumAlgorithm="adler32",payloadJson=json,payloadChecksum=Save.adler32(json)})
        storage.files={['save-b.json']=bytes};local writes=storage.writes
        local loaded=save:loadCheckpoint();equal(loaded.status,"migrated",version);equal(storage.writes,writes)
        for _,key in ipairs({"frozenUnlockPool","shopState","modules","completedWaveIds","acquiredModuleIds"}) do equal(Json.encode(loaded.payload.runState[key]),Json.encode(run[key]),version..key) end
        equal(loaded.payload.runState.gold,37);equal(Json.encode(loaded.payload.metaState.unlockedModuleIds),Json.encode(payload.metaState.unlockedModuleIds))
        local current=Content.clone(loaded.payload);current.metaState.unlockedModuleIds[#current.metaState.unlockedModuleIds+1]="M42"
        local valid=Save.createLivePayloadValidator(defs);assert(valid(current))
        current.runState.frozenUnlockPool.moduleIds[#current.runState.frozenUnlockPool.moduleIds+1]="M42"
        current.runState.modules[#current.runState.modules+1]=m42Entry("M42",16);equal(valid(current),nil)
        current.runState.acquiredModuleIds.M42=true;assert(valid(current))
        for _,paid in ipairs({-1,0.5,math.huge}) do local invalid=Content.clone(current);invalid.runState.modules[#invalid.runState.modules].paidGold=paid;equal(valid(invalid),nil) end
        current.runState.modules[#current.runState.modules].paidGold=60;assert(valid(current))
    end
end)

local function m15CoreRun(defs, patches, placed, modules)
    local run = oneTowerRun(defs, "T01", placed and 0 or nil, 0, patches or {}, modules)
    run.phase, run.nextWaveIndex, run.gold, run.hp = "COMBAT", 6, 20, 5
    return run
end

local function m15CoreCompletion(defs, before)
    local summary = { waveId = string.format("W%02d", before.nextWaveIndex), waveIndex = before.nextWaveIndex,
        resultKind = "wave_complete", hp = before.hp, leaks = 0, towerInstances = Content.clone(before.towerInstances) }
    local candidate, events = Rules.reduceCompletion(defs, before, summary)
    return candidate, events, summary
end

test("M15 C01 mixed patch observation and I15 require maintained committed start identity and valid new completion", function()
    local defs, Json = Content.create(), require("src.json")
    local distinct = { "P_DAMAGE", "P_RATE", "P_RANGE" }
    for _, case in ipairs({ { {},true,0 }, { {"P_DAMAGE","P_RATE"},true,0 },
        { {"P_RATE","P_RATE","P_RATE"},true,0 }, { {"P_RATE","P_RATE","P_DAMAGE"},true,0 },
        { distinct,false,0 }, { distinct,true,1 } }) do
        local run = m15CoreRun(defs, case[1], case[2]); local bytes = Json.encode(run)
        equal(assert(Rules.mixedPatchComposition(defs,run)).qualifyingTowerCount,case[3]); equal(Json.encode(run),bytes)
    end
    local run = m15CoreRun(defs,distinct,true)
    run.towerInstances[2] = {instanceId=2,typeId="T02",patchIds={"P_RATE","P_RATE","P_RATE"},placement={x=1,y=0},charge=0}
    run.nextInstanceId = 3
    local after,events,summary = m15CoreCompletion(defs,run)
    equal(assert(Rules.mixedPatchStartProof(defs,run,after,summary)).qualifies,true)
    summary.towerInstances[1].charge = 0.75; after.towerInstances[1].charge = 0.9
    equal(assert(Rules.mixedPatchStartProof(defs,run,after,summary)).qualifies,true)
    for _, mutate in ipairs({
        function(r) r.towerInstances=nil end,
        function(r) r.towerInstances[1].patchIds=nil end,
        function(r) r.towerInstances[1].patchIds={ [1]="P_DAMAGE",[3]="P_RATE" } end,
        function(r) r.towerInstances[1].patchIds[1]="unknown" end,
        function(r) r.towerInstances[2].instanceId=1 end,
        function(r) r.towerInstances[1].placement=false end,
    }) do local bad=Content.clone(run);mutate(bad);equal(Rules.mixedPatchComposition(defs,bad),nil) end
    local function earns(index, mutate)
        local b=Content.clone(run);b.nextWaveIndex=index
        local a,e,s=m15CoreCompletion(defs,b);if not a then return false end
        if mutate then mutate(b,a,s,e) end
        local _,unlocks=Rules.reduceModuleUnlocks(defs,{unlockedModuleIds={}},b,a,s,e)
        return containsEvent(unlocks,"module_unlocked",function(event)return event.moduleId=="M15" end)~=nil
    end
    for _,index in ipairs({5,6,14,15}) do equal(earns(index),index>=6 and index<=14) end
    for _,mutate in ipairs({
        function(b) b.phase="PREPARE" end, function(b) b.runId=nil end,
        function(b) b.nextWaveIndex=7 end, function(_,a) a.runId="other" end,
        function(_,_,s) s.waveIndex=7 end, function(_,_,s) s.towerInstances=nil end,
        function(_,_,s) s.resultKind="defeat" end, function(_,_,s) s.hp=0 end,
        function(b) b.completedWaveIds.W06=true end, function(_,a) a.completedWaveIds.W06=nil end,
        function(_,a) a.nextWaveIndex=6 end, function(_,_,_,e) for i=#e,1,-1 do table.remove(e,i) end end,
        function(b) b.towerInstances[1].placement=nil end,
        function(_,a,s) a.towerInstances[1].placement=nil;s.towerInstances[1].placement=nil end,
        function(_,a,s) a.towerInstances[1].instanceId=3;s.towerInstances[1].instanceId=3 end,
        function(_,a,s) a.towerInstances[1].placement.x=2;s.towerInstances[1].placement.x=2 end,
        function(_,a,s) a.towerInstances[1].patchIds[1]="P_OVERLOAD";s.towerInstances[1].patchIds[1]="P_OVERLOAD" end,
    }) do equal(earns(6,mutate),false) end
    local second=Content.clone(run);second.towerInstances[2].patchIds=Content.clone(distinct)
    local a,e,s=m15CoreCompletion(defs,second);a.towerInstances[1].placement=nil;s.towerInstances[1].placement=nil
    equal(assert(Rules.mixedPatchStartProof(defs,second,a,s)).qualifies,true)
    local proof=assert(Rules.mixedPatchStartProof(defs,second,a,s));proof.maintainedTowerIds[1]=99
    equal(second.towerInstances[2].instanceId,2)
end)

test("M15 C02 mixed rate stays additive per deployed tower and preserves duplicate patch layering without M15", function()
    local defs=Content.create();equal(defs.modulesById.M15.tier,"mid");equal(defs.modulesById.M15.price,12)
    local run=m15CoreRun(defs,{"P_DAMAGE","P_RATE","P_RANGE"},true,{"M01","M45"});run.gold=3
    run.towerInstances[2]={instanceId=2,typeId="T02",patchIds={"P_RATE","P_RATE","P_RATE"},placement={x=1,y=0},charge=0}
    run.towerInstances[3]={instanceId=3,typeId="T01",patchIds={"P_DAMAGE","P_RATE"},placement={x=4,y=0},charge=0}
    run.towerInstances[4]={instanceId=4,typeId="T01",patchIds={"P_DAMAGE","P_RATE","P_RANGE"},charge=0}
    local original={};for id=1,4 do original[id]=assert(Rules.projectStats(defs,run,id)) end
    run.modules[#run.modules+1]="M15"
    local stats=assert(Rules.projectStats(defs,run,1))
    close(stats.factors.moduleRate,1.65,1e-9);close(stats.factors.patchRate,1.15,1e-9)
    close(stats.attackRate,defs.towersById.T01.attackRate*1.15*1.65,1e-9)
    for id=2,4 do
        stats=assert(Rules.projectStats(defs,run,id));close(stats.attackRate,original[id].attackRate,1e-9)
        equal(assert(Rules.projectModuleStatus(defs,run,"M15",{towerInstanceId=id})).bonusPercentPoints,0)
    end
    close(original[2].factors.patchRate,1.45,1e-9)
    local status=assert(Rules.projectModuleStatus(defs,run,"M15",{towerInstanceId=3}))
    equal(status.active,true);equal(status.selectedTowerQualifies,false);equal(status.selectedDistinctPatchCount,2)
    equal(assert(Rules.projectModuleStatus(defs,run,"M15")).bonusPercentPoints,0)
    table.remove(run.modules);for id=1,4 do close(assert(Rules.projectStats(defs,run,id)).attackRate,original[id].attackRate,1e-9) end
    local stacked=m15CoreRun(defs,{"P_RATE","P_RATE","P_RATE"},true,{"M09","M11"})
    local baseline=assert(Rules.projectStats(defs,stacked,1));stacked.modules[#stacked.modules+1]="M15"
    local same=assert(Rules.projectStats(defs,stacked,1));close(same.attackRate,baseline.attackRate,1e-9);close(same.damage,baseline.damage,1e-9)
end)

test("M15 C03 mixed trade projections use selected tower and preserve linked paid slots exact recalls and history", function()
    local defs,Game,Json=Content.create(),require("src.game"),require("src.json")
    local run=m15CoreRun(defs,{"P_DAMAGE","P_RATE","P_RANGE"},true)
    run.phase,run.gold,run.frozenUnlockPool="SHOP",100,Game.defaultUnlockPool(defs)
    run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M15"
    run.modules={{moduleId="M41",paidGold=16,growth=0},{moduleId="M42",paidGold=16,growth=0},{moduleId="M43",paidGold=12,growth=0}}
    run.acquiredModuleIds={M41=true,M42=true,M43=true};local bytes=Json.encode(run)
    local preview=assert(Rules.previewModulePurchase(defs,run,"M15"));equal(preview.paidGold,12)
    equal(preview.midLinkBefore.bonusPercentPoints,8);equal(preview.midLinkAfter.bonusPercentPoints,16)
    equal(preview.assetLinkBefore.otherModulePaidGold,28);equal(preview.assetLinkAfter.otherModulePaidGold,40)
    equal(preview.spareCircuitBefore.bonusPercentPoints,12);equal(preview.spareCircuitAfter.bonusPercentPoints,0)
    local bought=assert(Rules.tryPurchaseModule(defs,run,"M15"));local projection=assert(Rules.projectTradeTowerStats(defs,run,bought,1))
    close(projection.before.attackRate,1.15,1e-9);close(projection.after.attackRate,1.38,1e-9)
    equal(projection.afterStatus.bonusPercentPoints,20);equal(Rules.projectTradeTowerStats(defs,run,bought,nil),nil)
    local sold=assert(Rules.tryInventoryTransaction(defs,bought,{phase="SHOP",kind="sell_module",moduleId="M15"}))
    equal(sold.gold,bought.gold+6);equal(sold.acquiredModuleIds.M15,true)
    equal(assert(Rules.projectTradeTowerStats(defs,bought,sold,1)).afterStatus.bonusPercentPoints,0)
    equal(Rules.tryPurchaseModule(defs,sold,"M15"),nil);equal(Json.encode(run),bytes)
    projection.afterStatus.qualifyingTowerIds[1]=99;equal(bought.towerInstances[1].instanceId,1)
    local poor=Content.clone(run);poor.gold=0;equal(Rules.tryPurchaseModule(defs,poor,"M15"),nil)
end)

test("M15 C04 Save validates six rights and preserves nine historical versions without inferring I15", function()
    local Save,Json,Game=require("src.save"),require("src.json"),require("src.game")
    local defs=Content.create();local migrations=Save.createRun002Migrations(defs)
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1"}
    for index,version in ipairs(versions) do
        local storage={files={},writes=0}
        function storage:read(path)return self.files[path],nil,self.files[path] and nil or "missing" end
        function storage:write(path,bytes)self.writes=self.writes+1;self.files[path]=bytes;return true end
        local save=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",checksum=Save.adler32,checksumName="adler32",validatePayload=Save.createLivePayloadValidator(defs),migrations=migrations})
        Game.new({defs=defs,checkpointStore=save,identityProvider=function()return {runId="m15-legacy",shopSeed=204} end})
        local payload=save:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion,run.gold=version,37;run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={{moduleId="M01",paidGold=20,growth=0}};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02"
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then run.modules[2]={moduleId="M33",paidGold=9,growth=6};run.acquiredModuleIds.M33=true;run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33" end
        payload.metaState.unlockedModuleIds={}
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"}}) do
            if index>=entry[1] then payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2] end
        end
        assert(migrations[version].validatePayload(payload))
        for _,field in ipairs({"pool","offer","install","acquired","right"}) do
            local bad=Content.clone(payload)
            if field=="pool" then bad.runState.frozenUnlockPool.moduleIds[#bad.runState.frozenUnlockPool.moduleIds+1]="M15"
            elseif field=="offer" then bad.runState.shopState.offers.module="M15"
            elseif field=="install" then bad.runState.modules[#bad.runState.modules+1]={moduleId="M15",paidGold=12,growth=0}
            elseif field=="acquired" then bad.runState.acquiredModuleIds.M15=true
            else bad.metaState.unlockedModuleIds[#bad.metaState.unlockedModuleIds+1]="M15" end
            local accepted=migrations[version].validatePayload(bad)
            if accepted then equal(Save.createLivePayloadValidator(defs)(migrations[version].migrate(bad)),nil,version..field)
            else equal(accepted,nil,version..field) end
        end
        local json=Json.encode(payload);storage.files={['save-b.json']=Json.encode({schemaVersion=1,generation=34,contentVersion=version,engineTarget="love-11.5",checksumAlgorithm="adler32",payloadJson=json,payloadChecksum=Save.adler32(json)})}
        local writes=storage.writes;local loaded=save:loadCheckpoint();equal(loaded.status,"migrated");equal(storage.writes,writes)
        for _,key in ipairs({"modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(loaded.payload.runState[key]),Json.encode(run[key])) end
        equal(Json.encode(loaded.payload.metaState.unlockedModuleIds),Json.encode(payload.metaState.unlockedModuleIds))
        local current=Content.clone(loaded.payload);current.metaState.unlockedModuleIds[#current.metaState.unlockedModuleIds+1]="M15"
        current.runState.frozenUnlockPool.moduleIds[#current.runState.frozenUnlockPool.moduleIds+1]="M15"
        current.runState.modules[#current.runState.modules+1]={moduleId="M15",paidGold=12,growth=0};current.runState.acquiredModuleIds.M15=true
        assert(Save.createLivePayloadValidator(defs)(current))
    end
    equal(#Game.defaultUnlockPool(defs).moduleIds,24);equal(#defs.modules,34)
end)

local function m14CoreRun(defs, patches, placed, modules)
    local run = Rules.newRun(defs, { runId = "m14-core", modules = modules or {} })
    run.runId, run.phase, run.nextWaveIndex, run.hp, run.gold = "m14-core", "COMBAT", 9, 19, 0
    run.towerInstances = {{instanceId=1,typeId="T01",paidGold=0,patchIds=Content.clone(patches),
        placement=placed and {x=0,y=2} or nil,charge=0,activated=placed==true}}
    run.nextInstanceId = 2
    return run
end

local function m14CoreCompletion(defs, before)
    local summary = {waveId=string.format("W%02d",before.nextWaveIndex),waveIndex=before.nextWaveIndex,
        resultKind="wave_complete",hp=before.hp,leaks=0,towerInstances=Content.clone(before.towerInstances)}
    local candidate, events = Rules.reduceCompletion(defs,before,summary)
    return candidate, events, summary
end

test("M14 C01 nominal patch investment requires one maintained committed start tower and valid new completion", function()
    local defs, Json = Content.create(), require("src.json")
    local mid = {"P_OVERLOAD","P_OVERDRIVE","P_LONG_RANGE"}
    local cases = {
        {{},true,0,0}, {{"P_FOCUSED_BARRAGE","P_HEAVY_AIM"},true,20,0},
        {mid,true,21,1}, {{"P_OVERLOAD","P_OVERLOAD","P_OVERLOAD"},true,21,1},
        {{"P_FOCUSED_BARRAGE","P_OVERLOAD","P_DAMAGE"},true,21,1},
        {{"P_FOCUSED_BARRAGE","P_HEAVY_AIM","P_RATE"},true,24,1}, {mid,false,21,0},
    }
    for _,case in ipairs(cases) do
        local run=m14CoreRun(defs,case[1],case[2]);local bytes=Json.encode(run)
        local observed=assert(Rules.patchInvestmentComposition(defs,run))
        equal(observed.towerDetails[1].nominalPatchPrice,case[3]);equal(observed.qualifyingTowerCount,case[4]);equal(Json.encode(run),bytes)
    end
    local repeated=m14CoreRun(defs,{"P_OVERLOAD","P_OVERLOAD","P_OVERLOAD"},true)
    equal(assert(Rules.mixedPatchComposition(defs,repeated)).qualifyingTowerCount,0)
    local split=m14CoreRun(defs,{"P_OVERLOAD","P_OVERDRIVE"},true)
    split.towerInstances[2]={instanceId=2,typeId="T02",patchIds={"P_LONG_RANGE"},placement={x=1,y=0},charge=0}
    equal(assert(Rules.patchInvestmentComposition(defs,split)).qualifyingTowerCount,0)
    local run=m14CoreRun(defs,mid,true)
    for _,mutate in ipairs({
        function(r)r.towerInstances=nil end,function(r)r.towerInstances=false end,
        function(r)r.towerInstances[1].patchIds=nil end,function(r)r.towerInstances[1].patchIds=false end,
        function(r)r.towerInstances[1].patchIds={[1]="P_OVERLOAD",[3]="P_OVERDRIVE"} end,
        function(r)r.towerInstances[1].patchIds[1]="unknown" end,function(r)r.towerInstances[1].placement=false end,
        function(r)r.towerInstances[2]=Content.clone(r.towerInstances[1]) end,
    }) do local bad=Content.clone(run);mutate(bad);local result,reason=Rules.patchInvestmentComposition(defs,bad);equal(result,nil);equal(type(reason),"string") end
    local badDefs=Content.clone(defs);badDefs.patchesById.P_OVERLOAD.price=false
    equal(Rules.patchInvestmentComposition(badDefs,run),nil)
    badDefs=Content.clone(defs);badDefs.patchesById.P_OVERLOAD.tier="unknown";equal(Rules.patchInvestmentComposition(badDefs,run),nil)
    local function earns(index,mutate)
        local before=Content.clone(run);before.nextWaveIndex=index
        local after,events,summary=m14CoreCompletion(defs,before);if not after then return false end
        if mutate then mutate(before,after,summary,events) end
        local _,unlocks=Rules.reduceModuleUnlocks(defs,{unlockedModuleIds={}},before,after,summary,events)
        return containsEvent(unlocks,"module_unlocked",function(e)return e.moduleId=="M14" end)~=nil
    end
    for _,index in ipairs({8,9,14,15}) do equal(earns(index),index>=9 and index<=14) end
    for _,mutate in ipairs({
        function(b)b.phase="PREPARE" end,function(b)b.runId=nil end,function(_,a)a.runId="other" end,
        function(b)b.nextWaveIndex=10 end,function(_,_,s)s.waveIndex=10 end,function(_,_,s)s.towerInstances=nil end,
        function(_,_,s)s.resultKind="defeat" end,function(_,_,s)s.hp=0 end,
        function(b)b.completedWaveIds.W09=true end,function(_,a)a.completedWaveIds.W09=nil end,
        function(_,a)a.nextWaveIndex=9 end,function(_,_,_,e)for i=#e,1,-1 do table.remove(e,i) end end,
        function(b)b.towerInstances[1].placement=nil end,
        function(_,a,s)a.towerInstances[1].placement=nil;s.towerInstances[1].placement=nil end,
        function(_,a,s)a.towerInstances[1].instanceId=3;s.towerInstances[1].instanceId=3 end,
        function(_,a,s)a.towerInstances[1].placement.x=2;s.towerInstances[1].placement.x=2 end,
        function(_,a,s)a.towerInstances[1].patchIds[1]="P_HEAVY_AIM";s.towerInstances[1].patchIds[1]="P_HEAVY_AIM" end,
    }) do equal(earns(9,mutate),false) end
    local after,events,summary=m14CoreCompletion(defs,run)
    summary.towerInstances[1].charge=0.75;after.towerInstances[1].charge=0.9
    equal(assert(Rules.patchInvestmentStartProof(defs,run,after,summary)).qualifies,true)
    local second=Content.clone(run);second.towerInstances[2]=Content.clone(second.towerInstances[1]);second.towerInstances[2].instanceId=2
    second.towerInstances[2].placement={x=1,y=0}
    after,events,summary=m14CoreCompletion(defs,second);after.towerInstances[1].placement=nil;summary.towerInstances[1].placement=nil
    local proof=assert(Rules.patchInvestmentStartProof(defs,second,after,summary));equal(proof.qualifies,true);equal(proof.maintainedTowerIds[1],2)
    proof.maintainedTowerIds[1]=99;equal(second.towerInstances[2].instanceId,2)
end)

test("M14 C02 high grade patch damage adds per deployed tower and preserves patch and M15 layers", function()
    local defs=Content.create();equal(defs.modulesById.M14.tier,"mid");equal(defs.modulesById.M14.price,12)
    for count=0,3 do
        local patches={};for i=1,count do patches[i]="P_FOCUSED_BARRAGE" end
        local run=m14CoreRun(defs,patches,true,{"M02","M09"});local baseline=assert(Rules.projectStats(defs,run,1))
        run.modules[#run.modules+1]="M14";local stats=assert(Rules.projectStats(defs,run,1))
        close(stats.factors.moduleDamage,baseline.factors.moduleDamage+0.08*count,1e-9)
        close(stats.damage,defs.towersById.T01.damage*(1+0.25*count)*(baseline.factors.moduleDamage+0.08*count),1e-9)
        close(stats.attackRate,baseline.attackRate,1e-9);close(stats.range,baseline.range,1e-9)
        equal(assert(Rules.projectModuleStatus(defs,run,"M14",{towerInstanceId=1})).bonusPercentPoints,count*8)
        run.towerInstances[1].placement=nil;equal(assert(Rules.projectModuleStatus(defs,run,"M14",{towerInstanceId=1})).bonusPercentPoints,0)
    end
    local run=m14CoreRun(defs,{"P_FOCUSED_BARRAGE","P_HEAVY_AIM"},true,{"M14"})
    run.towerInstances[2]={instanceId=2,typeId="T02",patchIds={"P_OVERLOAD","P_OVERDRIVE","P_LONG_RANGE"},placement={x=7,y=0},charge=0}
    run.towerInstances[3]={instanceId=3,typeId="T01",patchIds={"P_FOCUSED_BARRAGE","P_HEAVY_AIM","P_CONTINUOUS_AIM"},charge=0}
    equal(assert(Rules.patchInvestmentComposition(defs,run)).towerDetails[1].qualifies,false)
    local status=assert(Rules.projectModuleStatus(defs,run,"M14",{towerInstanceId=1}));equal(status.active,true);equal(status.bonusPercentPoints,16)
    status=assert(Rules.projectModuleStatus(defs,run,"M14",{towerInstanceId=2}));equal(status.active,true);equal(status.selectedTowerQualifies,false);equal(status.bonusPercentPoints,0)
    equal(assert(Rules.projectModuleStatus(defs,run,"M14")).selectedTowerInstanceId,nil)
    equal(assert(Rules.projectModuleStatus(defs,run,"M14",{towerInstanceId=3})).bonusPercentPoints,0)
    run=m14CoreRun(defs,{"P_FOCUSED_BARRAGE","P_HEAVY_AIM","P_CONTINUOUS_AIM"},true,{"M15"})
    local before=assert(Rules.projectStats(defs,run,1));run.modules[#run.modules+1]="M14"
    local after=assert(Rules.projectStats(defs,run,1));close(after.factors.moduleDamage,before.factors.moduleDamage+0.24,1e-9)
    close(after.factors.moduleRate,1.20,1e-9);close(after.attackRate,before.attackRate,1e-9)
end)

test("M14 C03 selected maintenance trade projections preserve recorded paid links recalls and ownership", function()
    local defs,Game,Json=Content.create(),require("src.game"),require("src.json")
    local run=m14CoreRun(defs,{"P_FOCUSED_BARRAGE","P_HEAVY_AIM","P_RATE"},true)
    local function absentProposal(proposal)
        local ok, projected, reason = pcall(Rules.projectTradeTowerStats, defs, run, proposal, 1)
        assert(ok, "invalid proposal must return an error without throwing")
        equal(projected,nil);assert(type(reason)=="string" and reason~="")
    end
    absentProposal(nil);absentProposal(false);absentProposal({});absentProposal({towerInstances=false})
    local ok, projected, reason = pcall(Rules.projectTradeTowerStats, defs, false, run, 1)
    assert(ok);equal(projected,nil);assert(type(reason)=="string" and reason~="")
    run.phase,run.gold,run.frozenUnlockPool="SHOP",100,Game.defaultUnlockPool(defs)
    for _,id in ipairs({"M14","M15","M28","M41","M42","M43","M46"}) do run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=id end
    run.modules={{moduleId="M41",paidGold=16,growth=0},{moduleId="M42",paidGold=16,growth=0},{moduleId="M43",paidGold=12,growth=0}}
    run.acquiredModuleIds={M41=true,M42=true,M43=true};local bytes=Json.encode(run)
    local preview=assert(Rules.previewModulePurchase(defs,run,"M14"));equal(preview.paidGold,12)
    equal(preview.midLinkBefore.bonusPercentPoints,8);equal(preview.midLinkAfter.bonusPercentPoints,16)
    equal(preview.assetLinkBefore.otherModulePaidGold,28);equal(preview.assetLinkAfter.otherModulePaidGold,40)
    equal(preview.spareCircuitBefore.bonusPercentPoints,12);equal(preview.spareCircuitAfter.bonusPercentPoints,0)
    local bought=assert(Rules.tryPurchaseModule(defs,run,"M14"));local p=assert(Rules.projectTradeTowerStats(defs,run,bought,1))
    equal(p.beforeMaintenanceStatus.bonusPercentPoints,0);equal(p.afterMaintenanceStatus.bonusPercentPoints,16)
    equal(p.afterStatus.bonusPercentPoints,0);equal(Rules.projectTradeTowerStats(defs,run,bought,nil),nil)
    local recorded=Content.clone(bought);recorded.modules[4].paidGold=9
    local sold,events=Rules.tryInventoryTransaction(defs,recorded,{phase="SHOP",kind="sell_module",moduleId="M14"});assert(sold)
    equal(sold.gold,recorded.gold+4);equal(sold.acquiredModuleIds.M14,true)
    equal(assert(Rules.projectTradeTowerStats(defs,recorded,sold,1)).afterMaintenanceStatus.bonusPercentPoints,0)
    equal(Rules.tryPurchaseModule(defs,sold,"M14"),nil);equal(Json.encode(run),bytes)
    p.afterMaintenanceStatus.qualifyingTowerIds[1]=99;equal(bought.towerInstances[1].instanceId,1)
    local poor=Content.clone(run);poor.gold=0;equal(Rules.tryPurchaseModule(defs,poor,"M14"),nil)
    local both=Content.clone(run);both.modules[3]={moduleId="M14",paidGold=12,growth=0};both.acquiredModuleIds={M41=true,M42=true,M14=true}
    local mixed=assert(Rules.tryPurchaseModule(defs,both,"M15"));p=assert(Rules.projectTradeTowerStats(defs,both,mixed,1))
    equal(p.beforeMaintenanceStatus.bonusPercentPoints,16);equal(p.afterMaintenanceStatus.bonusPercentPoints,16)
    equal(p.beforeStatus.bonusPercentPoints,0);equal(p.afterStatus.bonusPercentPoints,20)
    close(p.after.attackRate,p.before.attackRate+defs.towersById.T01.attackRate*p.before.factors.patchRate*0.20,1e-9)
end)
test("M14 C04 current seven rights and ten historical versions preserve records without retrospective I14", function()
    local Save,Json,Game=require("src.save"),require("src.json"),require("src.game")
    local defs=Content.create();local migrations=Save.createRun002Migrations(defs)
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1","DR-MOD-I15-r1"}
    for index,version in ipairs(versions) do
        local storage={files={},writes=0}
        function storage:read(path)return self.files[path],nil,self.files[path] and nil or "missing" end
        function storage:write(path,bytes)self.writes=self.writes+1;self.files[path]=bytes;return true end
        local save=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",checksum=Save.adler32,checksumName="adler32",validatePayload=Save.createLivePayloadValidator(defs),migrations=migrations})
        Game.new({defs=defs,checkpointStore=save,identityProvider=function()return {runId="m15-legacy",shopSeed=204} end})
        local payload=save:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion,run.gold=version,37;run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={{moduleId="M01",paidGold=20,growth=0}};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02"
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then run.modules[2]={moduleId="M33",paidGold=9,growth=6};run.acquiredModuleIds.M33=true;run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33" end
        payload.metaState.unlockedModuleIds={}
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"},{10,"M15"}}) do
            if index>=entry[1] then payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2] end
        end
        assert(migrations[version].validatePayload(payload))
        for _,field in ipairs({"pool","offer","install","acquired","right"}) do
            local bad=Content.clone(payload)
            if field=="pool" then bad.runState.frozenUnlockPool.moduleIds[#bad.runState.frozenUnlockPool.moduleIds+1]="M14"
            elseif field=="offer" then bad.runState.shopState.offers.module="M14"
            elseif field=="install" then bad.runState.modules[#bad.runState.modules+1]={moduleId="M14",paidGold=12,growth=0}
            elseif field=="acquired" then bad.runState.acquiredModuleIds.M14=true
            else bad.metaState.unlockedModuleIds[#bad.metaState.unlockedModuleIds+1]="M14" end
            local accepted=migrations[version].validatePayload(bad)
            if accepted then equal(Save.createLivePayloadValidator(defs)(migrations[version].migrate(bad)),nil,version..field)
            else equal(accepted,nil,version..field) end
        end
        local json=Json.encode(payload);storage.files={['save-b.json']=Json.encode({schemaVersion=1,generation=34,contentVersion=version,engineTarget="love-11.5",checksumAlgorithm="adler32",payloadJson=json,payloadChecksum=Save.adler32(json)})}
        local writes=storage.writes;local loaded=save:loadCheckpoint();equal(loaded.status,"migrated");equal(storage.writes,writes)
        for _,key in ipairs({"modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(loaded.payload.runState[key]),Json.encode(run[key])) end
        equal(Json.encode(loaded.payload.metaState.unlockedModuleIds),Json.encode(payload.metaState.unlockedModuleIds))
        local current=Content.clone(loaded.payload);current.metaState.unlockedModuleIds[#current.metaState.unlockedModuleIds+1]="M14"
        current.runState.frozenUnlockPool.moduleIds[#current.runState.frozenUnlockPool.moduleIds+1]="M14"
        current.runState.modules[#current.runState.modules+1]={moduleId="M14",paidGold=12,growth=0};current.runState.acquiredModuleIds.M14=true
        assert(Save.createLivePayloadValidator(defs)(current))
    end
    equal(#Game.defaultUnlockPool(defs).moduleIds,24);equal(#defs.modules,34)
end)


local function m12CoreRun(defs, placedCount, patchCount, totalCount, modules)
    local run = Rules.newRun(defs, { runId="m12-core", modules=modules or {} })
    run.runId,run.phase,run.nextWaveIndex,run.hp,run.gold="m12-core","COMBAT",6,19,20
    run.towerInstances={}
    for id=1,totalCount or placedCount do
        local patches={};for index=1,patchCount do patches[index]="P_RANGE" end
        run.towerInstances[id]={instanceId=id,typeId="T01",paidGold=0,patchIds=patches,
            placement=id<=placedCount and {x=id-1,y=0} or nil,charge=0,activated=id<=placedCount}
    end
    run.nextInstanceId=#run.towerInstances+1
    return run
end

test("M12 C01 positive equal patch counts and maintained start deployment prove only valid new I12", function()
    local defs,Json=Content.create(),require("src.json")
    for _,case in ipairs({{0,0,false,false},{2,1,false,true},{3,1,true,true},{3,0,false,false},{3,3,true,true}}) do
        local run=m12CoreRun(defs,case[1],case[2]);local bytes=Json.encode(run)
        local observation=assert(Rules.balancedPatchComposition(defs,run))
        equal(observation.unlockQualifies,case[3]);equal(observation.effectQualifies,case[4])
        equal(Json.encode(run),bytes);observation.placedTowerIds[1]=99;equal(Json.encode(run),bytes)
    end
    local run=m12CoreRun(defs,3,1,4)
    local function earns(index,mutate)
        local before=Content.clone(run);before.nextWaveIndex=index
        local summary={waveId=string.format("W%02d",index),waveIndex=index,resultKind="wave_complete",hp=19,leaks=0,towerInstances=Content.clone(before.towerInstances)}
        local candidate,events=Rules.reduceCompletion(defs,before,summary);if not candidate then return false end
        if mutate then mutate(before,candidate,summary,events) end
        local _,unlocks=Rules.reduceModuleUnlocks(defs,{unlockedModuleIds={}},before,candidate,summary,events)
        return containsEvent(unlocks,"module_unlocked",function(e)return e.moduleId=="M12" end)~=nil
    end
    for _,index in ipairs({5,6,14,15}) do equal(earns(index),index>=6 and index<=14) end
    equal(earns(6,function(_,a,s)a.towerInstances[4].placement={x=5,y=0};s.towerInstances[4].placement={x=5,y=0} end),true)
    for _,mutate in ipairs({
        function(b)b.towerInstances[3].placement=nil end,
        function(_,a,s)a.towerInstances[4].patchIds={};s.towerInstances[4].patchIds={};a.towerInstances[4].placement={x=5,y=0};s.towerInstances[4].placement={x=5,y=0} end,
        function(b,a,s)b.towerInstances[4].patchIds={};a.towerInstances[4].patchIds={};s.towerInstances[4].patchIds={};a.towerInstances[4].placement={x=5,y=0};s.towerInstances[4].placement={x=5,y=0} end,
        function(_,a,s)a.towerInstances[1].placement=nil;s.towerInstances[1].placement=nil end,
        function(_,a,s)a.towerInstances[1].placement.x=5;s.towerInstances[1].placement.x=5 end,
        function(_,a,s)a.towerInstances[1].patchIds={"P_RATE"};s.towerInstances[1].patchIds={"P_RATE"} end,
        function(b)b.phase="PREPARE" end,function(b)b.runId=nil end,function(_,a)a.runId="other" end,
        function(_,_,s)s.waveIndex=7 end,function(_,_,s)s.towerInstances=nil end,
        function(_,_,s)s.resultKind="defeat" end,function(_,_,s)s.hp=0 end,
        function(b)b.completedWaveIds.W06=true end,function(_,a)a.completedWaveIds.W06=nil end,
        function(_,a)a.nextWaveIndex=6 end,function(_,_,_,e)for i=#e,1,-1 do table.remove(e,i) end end,
    }) do equal(earns(6,mutate),false) end
    for _,mutate in ipairs({function(r)r.towerInstances=nil end,function(r)r.towerInstances=false end,
        function(r)r.towerInstances[2]=nil end,function(r)r.towerInstances[1].patchIds=nil end,
        function(r)r.towerInstances[1].patchIds=false end,function(r)r.towerInstances[1].patchIds={[1]="P_RANGE",[3]="P_RANGE"} end,
        function(r)r.towerInstances[1].patchIds[1]="unknown" end,function(r)r.towerInstances[1].placement=false end,
        function(r)r.towerInstances[2].instanceId=1 end}) do
        local bad=Content.clone(run);mutate(bad);local observed,reason=Rules.balancedPatchComposition(defs,bad)
        equal(observed,nil);equal(type(reason),"string")
    end
    local unequal=Content.clone(run);unequal.towerInstances[2].patchIds={"P_RANGE","P_RANGE"}
    equal(assert(Rules.balancedPatchComposition(defs,unequal)).effectQualifies,false)
    local summary={waveId="W06",waveIndex=6,resultKind="wave_complete",hp=19,towerInstances=Content.clone(run.towerInstances)}
    local candidate=assert(Rules.reduceCompletion(defs,run,summary));summary.towerInstances[1].charge=0.8;candidate.towerInstances[1].charge=0.2
    local proof=assert(Rules.balancedPatchStartProof(defs,run,candidate,summary));equal(proof.qualifies,true);equal(#proof.maintainedTowerIds,3)
end)

test("M12 C02 balanced deployed range adds to module layer and preserves patch damage rate and ownership", function()
    local defs,Json=Content.create(),require("src.json")
    equal(defs.modulesById.M12.price,12);equal(defs.modulesById.M12.tier,"mid")
    for count=0,3 do
        local run=m12CoreRun(defs,2,count,3,{"M14","M15"});local before=assert(Rules.projectStats(defs,run,1))
        run.modules[#run.modules+1]="M12";local bytes=Json.encode(run);local stats=assert(Rules.projectStats(defs,run,1))
        close(stats.range,defs.towersById.T01.range*(1+defs.patchesById.P_RANGE.range*count)*(count>0 and 1.25 or 1),1e-9)
        close(stats.damage,before.damage,1e-9);close(stats.attackRate,before.attackRate,1e-9)
        equal(stats.factors.moduleRange,count>0 and 1.25 or 1);equal(Json.encode(run),bytes)
        equal(Rules.projectModuleStatus(defs,run,"M12",{towerInstanceId=1}).bonusPercentPoints,count>0 and 25 or 0)
        equal(Rules.projectModuleStatus(defs,run,"M12",{towerInstanceId=3}).bonusPercentPoints,0)
        equal(Rules.projectModuleStatus(defs,run,"M12").selectedTowerInstanceId,nil)
    end
    local run=m12CoreRun(defs,3,3,3,{"M12","M14","M15"})
    for _,tower in ipairs(run.towerInstances) do tower.patchIds={"P_FOCUSED_BARRAGE","P_HEAVY_AIM","P_CONTINUOUS_AIM"} end
    local plain=Content.clone(run);table.remove(plain.modules,1)
    local a,b=assert(Rules.projectStats(defs,plain,1)),assert(Rules.projectStats(defs,run,1))
    close(b.range,a.range*1.25,1e-9);close(b.damage,a.damage,1e-9);close(b.attackRate,a.attackRate,1e-9)
    equal(Rules.projectModuleStatus(defs,run,"M14",{towerInstanceId=1}).bonusPercentPoints,24)
    equal(Rules.projectModuleStatus(defs,run,"M15",{towerInstanceId=1}).bonusPercentPoints,20)
    run.towerInstances[2].patchIds={[2]="P_RANGE"}
    equal(Rules.projectStats(defs,run,1),nil);equal(Rules.projectModuleStatus(defs,run,"M12",{towerInstanceId=1}).active,false)
end)

test("M12 C03 actual selected trade and patch proposals preserve range links recalls paid and aliases", function()
    local defs,Game,Json=Content.create(),require("src.game"),require("src.json")
    local run=m12CoreRun(defs,3,1,3);run.phase,run.gold,run.frozenUnlockPool="SHOP",100,Game.defaultUnlockPool(defs)
    for _,id in ipairs({"M12","M14","M15","M28","M41","M42","M43","M46"}) do run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=id end
    run.modules={{moduleId="M41",paidGold=16,growth=0},{moduleId="M42",paidGold=16,growth=0},{moduleId="M43",paidGold=12,growth=0}}
    run.acquiredModuleIds={M41=true,M42=true,M43=true};local bytes=Json.encode(run)
    local preview=assert(Rules.previewModulePurchase(defs,run,"M12"));equal(preview.paidGold,12)
    equal(preview.midLinkBefore.bonusPercentPoints,8);equal(preview.midLinkAfter.bonusPercentPoints,16)
    equal(preview.assetLinkBefore.otherModulePaidGold,28);equal(preview.assetLinkAfter.otherModulePaidGold,40)
    equal(preview.spareCircuitBefore.bonusPercentPoints,12);equal(preview.spareCircuitAfter.bonusPercentPoints,0)
    local bought=assert(Rules.tryPurchaseModule(defs,run,"M12"));local p=assert(Rules.projectTradeTowerStats(defs,run,bought,1))
    equal(p.beforeBalancedStatus.bonusPercentPoints,0);equal(p.afterBalancedStatus.bonusPercentPoints,25)
    close(p.after.range,p.before.range*1.25,1e-9);equal(Json.encode(run),bytes)
    p.afterBalancedStatus.placedTowerCount=99;equal(#bought.towerInstances,3)
    local patched=assert(Rules.tryPurchasePatch(defs,bought,1,"P_RANGE"));p=assert(Rules.projectTradeTowerStats(defs,bought,patched,2))
    equal(p.beforeBalancedStatus.bonusPercentPoints,25);equal(p.afterBalancedStatus.bonusPercentPoints,0)
    local recorded=Content.clone(bought);recorded.modules[4].paidGold=9
    local sold=assert(Rules.tryInventoryTransaction(defs,recorded,{phase="SHOP",kind="sell_module",moduleId="M12"}))
    equal(sold.gold,recorded.gold+4);equal(sold.acquiredModuleIds.M12,true);equal(Rules.tryPurchaseModule(defs,sold,"M12"),nil)
    equal(Rules.projectTradeTowerStats(defs,run,bought,nil),nil)
    local recalled=assert(Rules.tryRecallTower(bought,1,"prepare"));p=assert(Rules.projectTradeTowerStats(defs,bought,recalled,1))
    equal(p.afterBalancedStatus.bonusPercentPoints,0);equal(Rules.projectModuleStatus(defs,recalled,"M12",{towerInstanceId=2}).bonusPercentPoints,25)
end)

test("M12 C04 current eight rights and eleven historical sources preserve records without retrospective I12", function()
    local Save,Json,Game=require("src.save"),require("src.json"),require("src.game")
    local defs=Content.create();local migrations=Save.createRun002Migrations(defs)
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1","DR-MOD-I15-r1","DR-MOD-I14-r1"}
    for index,version in ipairs(versions) do
        local storage={files={},writes=0}
        function storage:read(path)return self.files[path],nil,self.files[path] and nil or "missing" end
        function storage:write(path,bytes)self.writes=self.writes+1;self.files[path]=bytes;return true end
        local save=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",checksum=Save.adler32,checksumName="adler32",validatePayload=Save.createLivePayloadValidator(defs),migrations=migrations})
        Game.new({defs=defs,checkpointStore=save,identityProvider=function()return {runId="m15-legacy",shopSeed=204} end})
        local payload=save:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion,run.gold=version,37;run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={{moduleId="M01",paidGold=20,growth=0}};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02"
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then run.modules[2]={moduleId="M33",paidGold=9,growth=6};run.acquiredModuleIds.M33=true;run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33" end
        payload.metaState.unlockedModuleIds={}
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"},{10,"M15"},{11,"M14"}}) do
            if index>=entry[1] then payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2] end
        end
        assert(migrations[version].validatePayload(payload))
        for _,field in ipairs({"pool","offer","install","acquired","right"}) do
            local bad=Content.clone(payload)
            if field=="pool" then bad.runState.frozenUnlockPool.moduleIds[#bad.runState.frozenUnlockPool.moduleIds+1]="M12"
            elseif field=="offer" then bad.runState.shopState.offers.module="M12"
            elseif field=="install" then bad.runState.modules[#bad.runState.modules+1]={moduleId="M12",paidGold=12,growth=0}
            elseif field=="acquired" then bad.runState.acquiredModuleIds.M12=true
            else bad.metaState.unlockedModuleIds[#bad.metaState.unlockedModuleIds+1]="M12" end
            local accepted=migrations[version].validatePayload(bad)
            if accepted then equal(Save.createLivePayloadValidator(defs)(migrations[version].migrate(bad)),nil,version..field)
            else equal(accepted,nil,version..field) end
        end
        local json=Json.encode(payload);storage.files={['save-b.json']=Json.encode({schemaVersion=1,generation=34,contentVersion=version,engineTarget="love-11.5",checksumAlgorithm="adler32",payloadJson=json,payloadChecksum=Save.adler32(json)})}
        local writes=storage.writes;local loaded=save:loadCheckpoint();equal(loaded.status,"migrated");equal(storage.writes,writes)
        for _,key in ipairs({"modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(loaded.payload.runState[key]),Json.encode(run[key])) end
        equal(Json.encode(loaded.payload.metaState.unlockedModuleIds),Json.encode(payload.metaState.unlockedModuleIds))
        local current=Content.clone(loaded.payload);current.metaState.unlockedModuleIds[#current.metaState.unlockedModuleIds+1]="M12"
        current.runState.frozenUnlockPool.moduleIds[#current.runState.frozenUnlockPool.moduleIds+1]="M12"
        current.runState.modules[#current.runState.modules+1]={moduleId="M12",paidGold=12,growth=0};current.runState.acquiredModuleIds.M12=true
        assert(Save.createLivePayloadValidator(defs)(current))
    end
    equal(#Game.defaultUnlockPool(defs).moduleIds,24);equal(#defs.modules,34)
end)


local M16_PATCHES = {"P_DAMAGE","P_RATE","P_RANGE","P_OVERLOAD","P_OVERDRIVE","P_LONG_RANGE",
    "P_FOCUSED_BARRAGE","P_CONTINUOUS_AIM","P_HEAVY_AIM"}
local function m16CoreRun(defs, count, modules)
    local run = Rules.newRun(defs, {runId="m16-core",modules=modules or {}})
    run.runId,run.phase,run.nextWaveIndex,run.hp,run.gold="m16-core","COMBAT",9,19,100
    run.towerInstances={}
    for index=1,math.max(1,math.ceil(count/3)) do
        local tower={instanceId=index,typeId="T01",paidGold=0,patchIds={},placement={x=index-1,y=0},charge=0,activated=true}
        for p=(index-1)*3+1,math.min(index*3,count) do tower.patchIds[#tower.patchIds+1]=M16_PATCHES[p] end
        run.towerInstances[index]=tower
    end
    run.nextInstanceId=#run.towerInstances+1
    return run
end
local function m16CoreCompletion(defs,before)
    local summary={waveId=string.format("W%02d",before.nextWaveIndex),waveIndex=before.nextWaveIndex,
        resultKind="wave_complete",hp=before.hp,leaks=0,towerInstances=Content.clone(before.towerInstances)}
    local after,events=Rules.reduceCompletion(defs,before,summary)
    return after,events,summary
end

test("M16 C01 deployed distinct union and maintained committed identities gate only new I16",function()
    local defs,Json=Content.create(),require("src.json")
    for _,count in ipairs({0,1,4,5,9}) do
        local run=m16CoreRun(defs,count);local bytes=Json.encode(run)
        local observation=assert(Rules.sharedPatchComposition(defs,run))
        equal(observation.distinctPatchCount,count);equal(observation.unlockQualifies,count>=5)
        observation.distinctPatchIds[1]="changed";equal(Json.encode(run),bytes)
    end
    local run=m16CoreRun(defs,5)
    run.towerInstances[2].patchIds[3]="P_DAMAGE"
    run.towerInstances[3]={instanceId=3,typeId="T01",patchIds={"P_LONG_RANGE"},charge=0}
    equal(assert(Rules.sharedPatchComposition(defs,run)).distinctPatchCount,5)
    local function earns(index,mutate)
        local before=Content.clone(run);before.nextWaveIndex=index
        local after,events,summary=m16CoreCompletion(defs,before)
        if not after then return false end
        if mutate then mutate(before,after,summary,events) end
        local _,unlocks=Rules.reduceModuleUnlocks(defs,{unlockedModuleIds={}},before,after,summary,events)
        return containsEvent(unlocks,"module_unlocked",function(e)return e.moduleId=="M16" end)~=nil
    end
    for _,index in ipairs({8,9,14,15}) do equal(earns(index),index>=9 and index<=14) end
    for _,mutate in ipairs({
        function(b)b.phase="PREPARE" end,function(b)b.runId=nil end,function(_,a)a.runId="other" end,
        function(_,_,s)s.waveIndex=nil end,function(_,_,s)s.towerInstances=nil end,
        function(_,_,s)s.resultKind="defeat" end,function(_,_,s)s.hp=0 end,
        function(b)b.completedWaveIds.W09=true end,function(_,a)a.completedWaveIds.W09=nil end,
        function(_,a)a.nextWaveIndex=9 end,function(_,_,_,e)for i=#e,1,-1 do table.remove(e,i) end end,
        function(_,a,s)a.towerInstances[1].placement=nil;s.towerInstances[1].placement=nil end,
        function(_,a,s)a.towerInstances[1].placement.x=9;s.towerInstances[1].placement.x=9 end,
        function(_,a,s)a.towerInstances[1].patchIds[1]="P_LONG_RANGE";s.towerInstances[1].patchIds[1]="P_LONG_RANGE" end,
        function(_,a,s)table.remove(a.towerInstances,3);table.remove(s.towerInstances,3) end,
        function(_,a,s)a.towerInstances[3].instanceId=4;s.towerInstances[3].instanceId=4 end,
        function(_,a)a.towerInstances[1].placement.x=9 end,
    }) do equal(earns(9,mutate),false) end
    local after,_,summary=m16CoreCompletion(defs,run)
    for _,patches in ipairs({{}, {"P_DAMAGE"}, {"P_LONG_RANGE"}}) do
        local before=Content.clone(run);before.towerInstances[3].patchIds=Content.clone(patches)
        after,_,summary=m16CoreCompletion(defs,before)
        after.towerInstances[3].placement={x=5,y=0};summary.towerInstances[3].placement={x=5,y=0}
        after.towerInstances[1].charge=0.7;summary.towerInstances[1].charge=0.9
        equal(assert(Rules.sharedPatchStartProof(defs,before,after,summary)).qualifies,true)
    end
    local late=m16CoreRun(defs,4);late.towerInstances[3]={instanceId=3,typeId="T01",patchIds={"P_OVERDRIVE"},charge=0}
    after,_,summary=m16CoreCompletion(defs,late);after.towerInstances[3].placement={x=5,y=0};summary.towerInstances[3].placement={x=5,y=0}
    equal(assert(Rules.sharedPatchStartProof(defs,late,after,summary)).qualifies,false)
    for _,mutate in ipairs({
        function(r)r.towerInstances=nil end,function(r)r.towerInstances=false end,
        function(r)r.towerInstances[2]=nil;r.towerInstances[3]={} end,
        function(r)r.towerInstances[1].patchIds=false end,function(r)r.towerInstances[1].patchIds={[1]="P_DAMAGE",[3]="P_RATE"} end,
        function(r)r.towerInstances[1].patchIds[1]="unknown" end,function(r)r.towerInstances[1].instanceId=0/0 end,
        function(r)r.towerInstances[1].instanceId=math.huge end,function(r)r.towerInstances[2].instanceId=1 end,
        function(r)r.towerInstances[1].placement={x=math.huge,y=0} end,function(r)r.towerInstances[1].placement=false end,
        function(r)r.towerInstances[3].patchIds={"unknown"} end,
    }) do local bad=Content.clone(run);mutate(bad);local value,reason=Rules.sharedPatchComposition(defs,bad);equal(value,nil);equal(type(reason),"string") end
end)

test("M16 C02 shared damage is additive capped deployed only and preserves patch penalties",function()
    local defs=Content.create();equal(defs.modulesById.M16.price,16);equal(defs.modulesById.M16.tier,"high")
    for count=0,9 do
        local run=m16CoreRun(defs,count,{"M02","M09"});local before=assert(Rules.projectStats(defs,run,1))
        run.modules[#run.modules+1]="M16";local after=assert(Rules.projectStats(defs,run,1))
        close(after.factors.moduleDamage,before.factors.moduleDamage+math.min(27,count*3)/100,1e-9)
        close(after.damage,defs.towersById.T01.damage*after.factors.patchDamage*after.factors.moduleDamage,1e-9)
        close(after.attackRate,before.attackRate,1e-9);close(after.range,before.range,1e-9)
        local status=Rules.projectModuleStatus(defs,run,"M16",{towerInstanceId=1})
        equal(status.bonusPercentPoints,count*3);equal(status.distinctPatchCount,count)
        equal(Rules.projectModuleStatus(defs,run,"M16").bonusPercentPoints,0)
    end
    local run=m16CoreRun(defs,9,{"M12","M14","M15"})
    local before=assert(Rules.projectStats(defs,run,1));run.modules[#run.modules+1]="M16"
    local after=assert(Rules.projectStats(defs,run,1));close(after.factors.moduleDamage,before.factors.moduleDamage+0.27,1e-9)
    close(after.attackRate,before.attackRate,1e-9);close(after.range,before.range,1e-9)
    run.towerInstances[4]={instanceId=4,typeId="T01",patchIds={"P_DAMAGE","P_DAMAGE","P_DAMAGE"},charge=0}
    local reserve=Rules.projectModuleStatus(defs,run,"M16",{towerInstanceId=4})
    equal(reserve.aggregateBonusPercentPoints,27);equal(reserve.bonusPercentPoints,0)
    run.towerInstances[1].patchIds={"P_OVERLOAD","P_OVERLOAD","P_OVERLOAD"};run.towerInstances[2].patchIds={};run.towerInstances[3].patchIds={}
    local repeated=assert(Rules.projectStats(defs,run,1));equal(Rules.projectModuleStatus(defs,run,"M16").distinctPatchCount,1)
    local plain=Content.clone(run);table.remove(plain.modules,4);local base=assert(Rules.projectStats(defs,plain,1))
    close(repeated.factors.patchDamage,base.factors.patchDamage,1e-9);close(repeated.factors.moduleDamage,base.factors.moduleDamage+0.03,1e-9)
    run.towerInstances[4].patchIds={"unknown"};local status=Rules.projectModuleStatus(defs,run,"M16")
    equal(status.distinctPatchCount,nil);equal(type(status.observationError),"string");equal(Rules.projectStats(defs,run,1),nil)
end)

test("M16 C03 purchase patch sale recall proposals preserve shared and linked projections without aliases",function()
    local defs,Game,Json=Content.create(),require("src.game"),require("src.json")
    local run=m16CoreRun(defs,5);run.phase,run.frozenUnlockPool="SHOP",Game.defaultUnlockPool(defs)
    for _,id in ipairs({"M16","M41","M42","M43"}) do run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=id end
    run.modules={{moduleId="M41",paidGold=16,growth=0},{moduleId="M42",paidGold=16,growth=0},{moduleId="M43",paidGold=12,growth=0}}
    run.acquiredModuleIds={M41=true,M42=true,M43=true};local bytes=Json.encode(run)
    local preview=assert(Rules.previewModulePurchase(defs,run,"M16"));equal(preview.paidGold,16)
    equal(preview.midLinkBefore.bonusPercentPoints,8);equal(preview.midLinkAfter.bonusPercentPoints,8)
    equal(preview.assetLinkAfter.otherModulePaidGold,44);equal(preview.spareCircuitAfter.bonusPercentPoints,0)
    local bought=assert(Rules.tryPurchaseModule(defs,run,"M16"));equal(bought.gold,84);equal(bought.acquiredModuleIds.M16,true)
    local projection=assert(Rules.projectTradeTowerStats(defs,run,bought,1));equal(projection.afterSharedStatus.bonusPercentPoints,15)
    projection.afterSharedStatus.distinctPatchIds[1]="changed";equal(Json.encode(run),bytes)
    local recorded=Content.clone(bought);recorded.modules[4].paidGold=9
    local sold=assert(Rules.tryInventoryTransaction(defs,recorded,{phase="SHOP",kind="sell_module",moduleId="M16"}))
    equal(sold.gold,recorded.gold+4);equal(sold.acquiredModuleIds.M16,true);equal(Rules.tryPurchaseModule(defs,sold,"M16"),nil)
    local missing=Content.clone(run);table.remove(missing.frozenUnlockPool.moduleIds,25);equal(Rules.tryPurchaseModule(defs,missing,"M16"),nil)
    bought.modules={"M16"};local patched=assert(Rules.tryPurchasePatch(defs,bought,2,"P_LONG_RANGE"))
    equal(Rules.projectModuleStatus(defs,patched,"M16").aggregateBonusPercentPoints,18)
    local duplicate=assert(Rules.tryPurchasePatch(defs,bought,2,"P_DAMAGE"));equal(Rules.projectModuleStatus(defs,duplicate,"M16").aggregateBonusPercentPoints,15)
    local recalled=assert(Rules.tryRecallTower(bought,1,"shop"));equal(Rules.projectModuleStatus(defs,recalled,"M16").distinctPatchCount,2)
    local towerSold=assert(Rules.tryInventoryTransaction(defs,bought,{phase="SHOP",kind="sell_tower",instanceId=1}))
    equal(Rules.projectModuleStatus(defs,towerSold,"M16").aggregateBonusPercentPoints,6)
    equal(Rules.projectTradeTowerStats(defs,bought,nil,1),nil)
end)

test("M16 C04 nine current rights and twelve frozen historical sources reject future M16 without inference",function()
    local Save,Json,Game=require("src.save"),require("src.json"),require("src.game")
    local defs=Content.create();local migrations=Save.createRun002Migrations(defs);local count=0
    for version,migration in pairs(migrations) do
        if version ~= "DR-MOD-I16-r1" then
        count=count+1
        local storage={files={}}
        function storage:read(path)return self.files[path],nil,self.files[path] and nil or "missing" end
        function storage:write(path,bytes)self.files[path]=bytes;return true end
        local save=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",checksum=Save.adler32,
            checksumName="adler32",validatePayload=Save.createLivePayloadValidator(defs),migrations=migrations})
        Game.new({defs=defs,checkpointStore=save,identityProvider=function()return {runId="legacy-m16",shopSeed=204} end})
        local payload=save:loadCheckpoint().payload;local run=payload.runState;run.contentVersion=version
        run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={{moduleId="M01",paidGold=20,growth=0}};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02"
        payload.metaState.unlockedModuleIds={}
        if version=="DR-SLICE-001-r2" then run.shopState.fixtureIndex=1;run.developmentComplete=false end
        assert(migration.validatePayload(payload),version)
        for _,mutate in ipairs({
            function(p)p.metaState.unlockedModuleIds={"M16"} end,
            function(p)p.runState.frozenUnlockPool.moduleIds[#p.runState.frozenUnlockPool.moduleIds+1]="M16" end,
            function(p)p.runState.shopState.offers.module="M16" end,
            function(p)p.runState.modules[2]={moduleId="M16",paidGold=16,growth=0} end,
            function(p)p.runState.acquiredModuleIds.M16=true end,
        }) do local future=Content.clone(payload);mutate(future);local accepted=migration.validatePayload(future)
            if accepted then equal(Save.createLivePayloadValidator(defs)(migration.migrate(future)),nil,version.." future M16")
            else equal(accepted,nil,version.." future M16") end
        end
        local before=Json.encode(payload);local migrated=assert(migration.migrate(payload))
        equal(Json.encode(payload),before);equal(migrated.runState.contentVersion,defs.version)
        equal(migrated.metaState.unlockedModuleIds[1],nil);equal(migrated.runState.modules[1].paidGold,20)
    end
    end
    equal(count,12);equal(#Game.defaultUnlockPool(defs).moduleIds,24);equal(#defs.modules,34)
end)

local function m31Run(defs, types, modules)
    local run=Rules.newRun(defs,{modules=modules or {}})
    run.phase,run.nextWaveIndex,run.gold,run.hp="COMBAT",9,20,20
    run.towerInstances={}
    for id,typeId in ipairs(types) do run.towerInstances[id]={instanceId=id,typeId=typeId,paidGold=6,patchIds={},charge=0,
        placement=id==1 and {x=0,y=2} or nil} end
    run.nextInstanceId=#types+1
    return run
end
local function m31Complete(defs,run,index)
    index=index or run.nextWaveIndex
    local summary={waveId=string.format("W%02d",index),waveIndex=index,resultKind="wave_complete",hp=20,leaks=0,tick=90,
        towerInstances=Content.clone(run.towerInstances)}
    local candidate,events=Rules.reduceCompletion(defs,run,summary)
    return candidate,events,summary
end

test("M31 C01 distinct reserve income adds to receipts and ordinary survival boundaries",function()
    local defs=Content.create();equal(defs.modulesById.M31.tier,"mid");equal(defs.modulesById.M31.price,12)
    for _,types in ipairs({{"T01"},{"T01","T01","T01"},{"T01","T01","T02"},{"T01","T01","T02","T03","T04"}}) do
        local run=m31Run(defs,types,{"M25","M26","M28","M31"});local reserve=assert(Rules.reserveComposition(defs,run))
        for _,index in ipairs({1,9,14,15}) do
            run.nextWaveIndex=index
            local reward=Rules.previewSettlement(defs,run,index,0)
            equal(reward.moduleById.M31,index<15 and math.min(3,reserve.count) or 0)
            equal(reward.modules,2+2+(index<15 and 4 or 0)+reward.moduleById.M31)
            equal(reward.total,reward.base+reward.flawless+reward.section+reward.modules)
            equal(Rules.projectModuleStatus(defs,run,"M31").estimatedGold,reward.moduleById.M31)
        end
    end
    local run=m31Run(defs,{"T01","T01","T02"},{"M31"});local candidate,events,summary=m31Complete(defs,run)
    equal(events[1].reward.moduleById.M31,2);equal(candidate.gold,37)
    local duplicate,dupEvents=Rules.reduceCompletion(defs,candidate,summary);equal(duplicate.gold,candidate.gold);equal(dupEvents[1].type,"completion_duplicate")
    for _,kind in ipairs({"defeat","victory"}) do summary.resultKind=kind;summary.resultReason="fixture";local result,es=Rules.reduceCompletion(defs,run,summary)
        equal(result.gold,run.gold);equal(containsEvent(es,"wave_reward"),nil) end
    summary.resultKind="unfinished";equal(Rules.reduceCompletion(defs,run,summary),nil)
end)

test("M31 C02 interval proof excludes lost kinds and illegal identity placement or patch mutation",function()
    local defs=Content.create();local run=m31Run(defs,{"T01","T01","T02","T01"})
    local candidate,events,summary=m31Complete(defs,run)
    equal(assert(Rules.reserveStartProof(defs,run,candidate,summary)).qualifies,true)
    candidate.towerInstances[4].placement={x=5,y=0};summary.towerInstances[4].placement={x=5,y=0}
    equal(assert(Rules.reserveStartProof(defs,run,candidate,summary)).qualifies,true)
    candidate.towerInstances[3].placement={x=6,y=0};summary.towerInstances[3].placement={x=6,y=0}
    equal(assert(Rules.reserveStartProof(defs,run,candidate,summary)).qualifies,false)
    for _,mutate in ipairs({
        function(a,s)a.towerInstances[1].placement=nil;s.towerInstances[1].placement=nil end,
        function(a,s)a.towerInstances[1].placement.x=7;s.towerInstances[1].placement.x=7 end,
        function(a,s)a.towerInstances[2].typeId="T04";s.towerInstances[2].typeId="T04" end,
        function(a,s)a.towerInstances[2].patchIds={"P_RATE"};s.towerInstances[2].patchIds={"P_RATE"} end,
        function(a,s)table.remove(a.towerInstances,4);table.remove(s.towerInstances,4) end,
        function(a,s)a.towerInstances[4].instanceId=5;s.towerInstances[4].instanceId=5 end,
        function(a)a.towerInstances[2].placement={x=8,y=0} end,
        function(a,s)a.towerInstances[5]=Content.clone(a.towerInstances[4]);a.towerInstances[5].instanceId=5;s.towerInstances[5]=Content.clone(a.towerInstances[5]) end,
    }) do candidate,events,summary=m31Complete(defs,run);mutate(candidate,summary);equal(Rules.reserveStartProof(defs,run,candidate,summary),nil) end
    for _,index in ipairs({8,9,14}) do run.nextWaveIndex=index;candidate,events,summary=m31Complete(defs,run)
        local meta=Rules.reduceModuleUnlocks(defs,{unlockedModuleIds={}},run,candidate,summary,events)
        local earned=false;for _,id in ipairs(meta.unlockedModuleIds) do if id=="M31" then earned=true end end;equal(earned,index>=9) end
    candidate,events,summary=m31Complete(defs,run);summary.towerInstances=nil;equal(Rules.reserveStartProof(defs,run,candidate,summary),nil)
end)

test("M31 C03 historical I16 and all earlier migrations reject future reserve rights without inferred unlock",function()
    local defs=Content.create();local Save=require("src.save");local Json=require("src.json");local Game=require("src.game")
    local count=0
    for version,migration in pairs(Save.createRun002Migrations(defs)) do
        count=count+1;local storage={files={}};function storage:read(p)return self.files[p],"missing","missing" end;function storage:write(p,b)self.files[p]=b;return true end
        local save=Save.new({storage=storage,contentVersion=defs.version,engineTarget="love-11.5",checksum=Save.loveSha256(love.data),validatePayload=Save.createLivePayloadValidator(defs)})
        Game.new({defs=defs,checkpointStore=save,identityProvider=function()return {runId="m31-history",shopSeed=204} end})
        local payload=save:loadCheckpoint().payload;payload.runState.contentVersion=version;payload.runState.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"};payload.runState.shopState.offers.module="M02"
        if version=="DR-SLICE-001-r2" then payload.runState.shopState.fixtureIndex=1;payload.runState.developmentComplete=false end
        assert(migration.validatePayload(payload),version)
        local before=Json.encode(payload);local migrated=assert(migration.migrate(payload));equal(Json.encode(payload),before)
        equal(migrated.metaState.unlockedModuleIds[1],nil);equal(migrated.runState.contentVersion,defs.version)
        for _,mutate in ipairs({function(p)p.metaState.unlockedModuleIds={"M31"} end,
            function(p)p.runState.frozenUnlockPool.moduleIds[#p.runState.frozenUnlockPool.moduleIds+1]="M31" end,
            function(p)p.runState.shopState.offers.module="M31" end,
            function(p)p.runState.modules={{moduleId="M31",paidGold=12,growth=0}};p.runState.acquiredModuleIds.M31=true end}) do
            local bad=Content.clone(payload);mutate(bad);local accepted=migration.validatePayload(bad)
            if accepted then equal(Save.createLivePayloadValidator(defs)(migration.migrate(bad)),nil) else equal(accepted,nil) end
        end
    end
    equal(count,13);equal(#Game.defaultUnlockPool(defs).moduleIds,24);equal(#defs.modules,34)
end)

local failed = 0
for _, item in ipairs(tests) do
    local ok, message = pcall(item.body)
    if ok then
        io.write("PASS ", item.name, "\n")
    else
        failed = failed + 1
        io.stderr:write("FAIL ", item.name, ": ", tostring(message), "\n")
    end
end

io.write(string.format('WORKFLOW SUITE {"schemaVersion":1,"suite":"core","count":%d,"failures":%d}\n', #tests, failed))
if failed > 0 then
    error(tostring(failed) .. " core tests failed")
end

