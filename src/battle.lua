local Content = require("src.content")
local Rules = require("src.rules")

local Battle = {}

local FIXED_DT = 1 / 60
local EPS_DISTANCE = 1e-9
local EPS_CHARGE = 1e-9

local function copy(value)
    return Content.clone(value)
end

local function sortedTowers(towers)
    local result = {}
    for _, tower in ipairs(towers or {}) do result[#result + 1] = tower end
    table.sort(result, function(left, right) return left.instanceId < right.instanceId end)
    return result
end

local function entranceRoutes(map)
    local routes = {}
    local routeById = {}
    for _, route in ipairs(map.routes) do routeById[route.id] = route end
    for _, entrance in ipairs(map.entrances) do routes[entrance.id] = routeById[entrance.routeId] end
    return routes
end

local function activeEnemyCount(state)
    local count = 0
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive then count = count + 1 end
    end
    return count
end

local function spawnEnemy(state, scheduled, events)
    local enemyDef = assert(state.defs.enemiesById[scheduled.enemyId])
    local route = assert(state.routesByEntrance[scheduled.entranceId])
    local enemy = {
        enemyId = state.nextEnemyId,
        typeId = enemyDef.id,
        routeId = route.id,
        s = 0,
        totalLength = route.totalLength,
        hp = enemyDef.maxHp,
        maxHp = enemyDef.maxHp,
        baseSpeed = enemyDef.speed,
        boss = enemyDef.boss == true,
        speedThresholdRatio = enemyDef.speedThresholdRatio,
        speedMultiplier = enemyDef.speedMultiplier,
        spawnOrdinal = state.nextSpawnOrdinal,
        spawnTick = scheduled.tick,
        alive = true,
        slowUntilTick = nil,
        slowRatio = 0,
        lastHitTickByTowerType = {},
    }
    state.nextEnemyId = state.nextEnemyId + 1
    state.nextSpawnOrdinal = state.nextSpawnOrdinal + 1
    state.enemies[#state.enemies + 1] = enemy
    state.enemyById[enemy.enemyId] = enemy
    state.observations.spawned = state.observations.spawned + 1
    events[#events + 1] = {
        type = "enemy_spawned", tick = scheduled.tick,
        enemyId = enemy.enemyId, enemyTypeId = enemy.typeId,
        groupId = scheduled.groupId,
        entranceId = scheduled.entranceId, routeId = enemy.routeId,
        spawnOrdinal = enemy.spawnOrdinal,
    }
end

local function spawnAtTick(state, tick, events)
    while state.nextSpawnIndex <= #state.spawnSchedule do
        local scheduled = state.spawnSchedule[state.nextSpawnIndex]
        if scheduled.tick ~= tick then break end
        spawnEnemy(state, scheduled, events)
        state.nextSpawnIndex = state.nextSpawnIndex + 1
    end
end

function Battle.routePosition(route, distance)
    local remaining = math.max(0, math.min(distance, route.totalLength))
    for index = 2, #route.points do
        local start = route.points[index - 1]
        local finish = route.points[index]
        local length = math.abs(finish.x - start.x) + math.abs(finish.y - start.y)
        if remaining <= length then
            if finish.x ~= start.x then
                local direction = finish.x > start.x and 1 or -1
                return start.x + direction * remaining, start.y
            end
            local direction = finish.y > start.y and 1 or -1
            return start.x, start.y + direction * remaining
        end
        remaining = remaining - length
    end
    local last = route.points[#route.points]
    return last.x, last.y
end

local function enemyPosition(state, enemy)
    return Battle.routePosition(state.routesById[enemy.routeId], enemy.s)
end

local function scheduleForWave(wave)
    local schedule = {}
    for groupOrder, group in ipairs(wave.groups) do
        for index = 0, group.count - 1 do
            schedule[#schedule + 1] = {
                tick = group.firstTick + index * group.intervalTicks,
                groupOrder = groupOrder,
                index = index,
                groupId = group.groupId,
                entranceId = group.entranceId,
                enemyId = group.enemyId,
            }
        end
    end
    table.sort(schedule, function(left, right)
        if left.tick ~= right.tick then return left.tick < right.tick end
        if left.groupOrder ~= right.groupOrder then return left.groupOrder < right.groupOrder end
        return left.index < right.index
    end)
    return schedule
end

function Battle.new(defs, run, waveId)
    local wave = defs.wavesById[waveId]
    if not wave then return nil, "unknown_wave" end
    local map = defs.mapsById[wave.mapId]
    if not map then return nil, "unknown_map" end
    local state = {
        defs = defs,
        run = copy(run),
        waveId = waveId,
        waveIndex = wave.index,
        map = map,
        tick = 0,
        hp = run.hp,
        spawnSchedule = scheduleForWave(wave),
        nextSpawnIndex = 1,
        nextSpawnOrdinal = 1,
        nextEnemyId = 1,
        nextProjectileId = 1,
        nextAttackId = 1,
        enemies = {},
        enemyById = {},
        projectiles = {},
        result = nil,
        bossRequired = wave.bossRequired == true,
        bossKilledThisTick = false,
        bossEscapedThisTick = false,
        hpZeroThisTick = false,
        observations = { spawned = 0, shots = 0, hits = 0, kills = 0, leaks = 0 },
        pendingEvents = {},
        routesByEntrance = entranceRoutes(map),
        routesById = {},
    }
    for _, route in ipairs(map.routes) do state.routesById[route.id] = route end
    state.towers = state.run.towerInstances
    spawnAtTick(state, 0, state.pendingEvents)
    return state, nil
end

local function applyCommands(state, commands, events)
    for _, command in ipairs(commands or {}) do
        if command.type == "place_tower" then
            local candidate, commandEvents, reason = Rules.tryPlaceTower(
                state.defs, state.run, state.map, command.instanceId, command.x, command.y, "combat"
            )
            if candidate then
                state.run = candidate
                state.towers = state.run.towerInstances
                for _, event in ipairs(commandEvents) do
                    event.tick = state.tick + 1
                    events[#events + 1] = event
                end
            else
                events[#events + 1] = {
                    type = "command_rejected", tick = state.tick + 1,
                    commandId = command.commandId, reason = reason,
                }
            end
        else
            events[#events + 1] = {
                type = "command_rejected", tick = state.tick + 1,
                commandId = command.commandId, reason = "unsupported_battle_command",
            }
        end
    end
end

local function expireSlows(state, tick)
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive and enemy.slowUntilTick and tick > enemy.slowUntilTick then
            enemy.slowUntilTick = nil
            enemy.slowRatio = 0
        end
    end
end

local function moveEnemies(state, tick)
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive and enemy.spawnTick < tick then
            local speedFactor = enemy.slowUntilTick and (1 - enemy.slowRatio) or 1
            if enemy.boss and enemy.speedThresholdRatio and enemy.speedMultiplier
                and enemy.hp < enemy.maxHp * enemy.speedThresholdRatio then
                speedFactor = speedFactor * enemy.speedMultiplier
            end
            enemy.s = math.min(enemy.totalLength, enemy.s + enemy.baseSpeed * speedFactor * FIXED_DT)
        end
    end
end

local function processLeaks(state, events)
    local leaking = {}
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive and enemy.s >= enemy.totalLength - EPS_DISTANCE then
            leaking[#leaking + 1] = enemy
        end
    end
    table.sort(leaking, function(left, right) return left.spawnOrdinal < right.spawnOrdinal end)
    for _, enemy in ipairs(leaking) do
        enemy.alive = false
        enemy.leaked = true
        state.observations.leaks = state.observations.leaks + 1
        if enemy.boss then
            state.bossEscapedThisTick = true
            events[#events + 1] = {
                type = "boss_escaped", tick = state.tick,
                enemyId = enemy.enemyId, hp = state.hp,
            }
        else
            state.hp = math.max(0, state.hp - 1)
            -- Only Battle's clone follows live HP; the committed combatStart stays intact.
            state.run.hp = state.hp
            if state.hp <= 0 then state.hpZeroThisTick = true end
            events[#events + 1] = {
                type = "enemy_leaked", tick = state.tick,
                enemyId = enemy.enemyId, hp = state.hp,
            }
        end
    end
end

local function squaredDistance(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

function Battle.selectTarget(state, tower, stats)
    if not tower.placement then return nil end
    local selected
    local rangeSquared = stats.range * stats.range
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive then
            local x, y = enemyPosition(state, enemy)
            if squaredDistance(tower.placement.x, tower.placement.y, x, y) <= rangeSquared + EPS_DISTANCE then
                local remaining = enemy.totalLength - enemy.s
                if not selected
                    or remaining < selected.remaining - EPS_DISTANCE
                    or (math.abs(remaining - selected.remaining) <= EPS_DISTANCE
                        and enemy.spawnOrdinal < selected.enemy.spawnOrdinal) then
                    selected = { enemy = enemy, remaining = remaining }
                end
            end
        end
    end
    return selected and selected.enemy or nil
end

local function moveProjectiles(state, events)
    local remaining, due = {}, {}
    table.sort(state.projectiles, function(left, right) return left.projectileId < right.projectileId end)
    for _, projectile in ipairs(state.projectiles) do
        local target = state.enemyById[projectile.targetId]
        if not target or not target.alive then
            events[#events + 1] = {
                type = "projectile_expired", tick = state.tick,
                projectileId = projectile.projectileId, reason = "target_missing",
            }
        else
            local targetX, targetY = enemyPosition(state, target)
            local dx, dy = targetX - projectile.x, targetY - projectile.y
            local distance = math.sqrt(dx * dx + dy * dy)
            local movement = projectile.speed * FIXED_DT
            if distance <= movement + EPS_DISTANCE then
                projectile.x, projectile.y = targetX, targetY
                due[#due + 1] = projectile
            else
                projectile.x = projectile.x + dx / distance * movement
                projectile.y = projectile.y + dy / distance * movement
                remaining[#remaining + 1] = projectile
            end
        end
    end
    state.projectiles = remaining
    return due
end

local function fireTowers(state, events)
    for _, tower in ipairs(sortedTowers(state.towers)) do
        if tower.placement then
            local stats, errorMessage = Rules.projectStats(state.defs, state.run, tower)
            assert(stats, errorMessage)
            assert(stats.attackRate > 0 and stats.attackRate < math.huge, "attack rate must be finite and positive")
            local charge = (tower.charge or 0) + stats.attackRate * FIXED_DT
            local target = Battle.selectTarget(state, tower, stats)
            if not target then
                tower.charge = math.min(1, charge)
            else
                while charge >= 1 - EPS_CHARGE and target do
                    local attackId = state.nextAttackId
                    state.nextAttackId = attackId + 1
                    local projectileId = state.nextProjectileId
                    state.nextProjectileId = projectileId + 1
                    state.projectiles[#state.projectiles + 1] = {
                        projectileId = projectileId,
                        sourceTowerId = tower.instanceId,
                        sourceTowerTypeId = tower.typeId,
                        targetId = target.enemyId,
                        x = tower.placement.x,
                        y = tower.placement.y,
                        speed = stats.projectileSpeed,
                        launchBaseDamage = stats.damage,
                        launchAttackId = attackId,
                        sourceKind = "normal",
                        behavior = stats.behavior,
                        blastRadius = stats.blastRadius,
                        chainRange = stats.chainRange,
                        chainHops = stats.chainHops,
                        chainFactor = stats.chainFactor,
                        slowRatio = stats.slowRatio,
                        slowTicks = stats.slowTicks,
                        createdTick = state.tick,
                    }
                    state.observations.shots = state.observations.shots + 1
                    events[#events + 1] = {
                        type = "tower_fired", tick = state.tick,
                        instanceId = tower.instanceId, targetId = target.enemyId,
                        projectileId = projectileId, attackId = attackId,
                        launchDamage = stats.damage,
                    }
                    charge = math.max(0, charge - 1)
                    target = Battle.selectTarget(state, tower, stats)
                end
                if not target then charge = math.min(1, charge) end
                tower.charge = charge
            end
        end
    end
end

local function applyDamage(state, projectile, enemy, multiplier, events, hitKind)
    if not enemy.alive then return false end
    local conditional = Rules.conditionalDamageMultiplier(state.run, enemy, state.tick)
    local damage = projectile.launchBaseDamage * multiplier * conditional
    local hpBefore = enemy.hp
    enemy.hp = enemy.hp - damage
    if projectile.sourceTowerTypeId then
        enemy.lastHitTickByTowerType = enemy.lastHitTickByTowerType or {}
        enemy.lastHitTickByTowerType[projectile.sourceTowerTypeId] = state.tick
    end
    state.observations.hits = state.observations.hits + 1
    events[#events + 1] = {
        type = "enemy_damaged", tick = state.tick,
        enemyId = enemy.enemyId, projectileId = projectile.projectileId,
        attackId = projectile.launchAttackId,
        sourceTowerId = projectile.sourceTowerId, sourceKind = projectile.sourceKind,
        hitKind = hitKind, damage = damage, hpBefore = hpBefore, hpAfter = math.max(0, enemy.hp),
    }
    if enemy.hp <= EPS_DISTANCE then
        enemy.hp = 0
        enemy.alive = false
        enemy.killed = true
        state.observations.kills = state.observations.kills + 1
        if enemy.boss then state.bossKilledThisTick = true end
        events[#events + 1] = {
            type = "enemy_killed", tick = state.tick,
            enemyId = enemy.enemyId, projectileId = projectile.projectileId,
            sourceTowerId = projectile.sourceTowerId, boss = enemy.boss == true,
        }
        return true
    end
    return false
end

local function processBombHit(state, projectile, target, events)
    local originX, originY = enemyPosition(state, target)
    local targets = { target }
    local radiusSquared = projectile.blastRadius * projectile.blastRadius
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive and enemy.enemyId ~= target.enemyId then
            local x, y = enemyPosition(state, enemy)
            if squaredDistance(originX, originY, x, y) <= radiusSquared + EPS_DISTANCE then
                targets[#targets + 1] = enemy
            end
        end
    end
    table.sort(targets, function(left, right)
        if left.enemyId == right.enemyId then return false end
        if left.enemyId == target.enemyId then return true end
        if right.enemyId == target.enemyId then return false end
        return left.spawnOrdinal < right.spawnOrdinal
    end)
    for _, enemy in ipairs(targets) do
        if state.bossKilledThisTick then break end
        applyDamage(state, projectile, enemy, 1, events, enemy.enemyId == target.enemyId and "primary" or "blast")
    end
end

local function selectChainTarget(state, originX, originY, range, hitIds)
    local selected
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive and not hitIds[enemy.enemyId] then
            local x, y = enemyPosition(state, enemy)
            local distance = squaredDistance(originX, originY, x, y)
            if distance <= range * range + EPS_DISTANCE then
                local remaining = enemy.totalLength - enemy.s
                if not selected or distance < selected.distance - EPS_DISTANCE
                    or (math.abs(distance - selected.distance) <= EPS_DISTANCE
                        and (remaining < selected.remaining - EPS_DISTANCE
                            or (math.abs(remaining - selected.remaining) <= EPS_DISTANCE
                                and enemy.spawnOrdinal < selected.enemy.spawnOrdinal))) then
                    selected = { enemy = enemy, distance = distance, remaining = remaining }
                end
            end
        end
    end
    return selected and selected.enemy or nil
end

local function processChainHit(state, projectile, target, events)
    local originX, originY = enemyPosition(state, target)
    local hitIds = { [target.enemyId] = true }
    applyDamage(state, projectile, target, 1, events, "primary")
    for hop = 1, projectile.chainHops do
        if state.bossKilledThisTick then break end
        local nextTarget = selectChainTarget(state, originX, originY, projectile.chainRange, hitIds)
        if not nextTarget then break end
        local nextX, nextY = enemyPosition(state, nextTarget)
        hitIds[nextTarget.enemyId] = true
        events[#events + 1] = {
            type = "chain_jump", tick = state.tick,
            projectileId = projectile.projectileId, attackId = projectile.launchAttackId,
            sourceTowerId = projectile.sourceTowerId, hop = hop,
            fromX = originX, fromY = originY, toX = nextX, toY = nextY,
            targetId = nextTarget.enemyId,
        }
        applyDamage(state, projectile, nextTarget, projectile.chainFactor ^ hop, events, "chain")
        originX, originY = nextX, nextY
    end
end

local function processHits(state, due, events)
    table.sort(due, function(left, right) return left.projectileId < right.projectileId end)
    for _, projectile in ipairs(due) do
        if state.bossKilledThisTick then break end
        local target = state.enemyById[projectile.targetId]
        if not target or not target.alive then
            events[#events + 1] = {
                type = "projectile_expired", tick = state.tick,
                projectileId = projectile.projectileId, reason = "target_missing",
            }
        elseif projectile.behavior == "bomb" then
            processBombHit(state, projectile, target, events)
        elseif projectile.behavior == "chain" then
            processChainHit(state, projectile, target, events)
        else
            local killed = applyDamage(state, projectile, target, 1, events, "primary")
            if projectile.behavior == "cold" and not killed and target.alive then
                target.slowRatio = math.max(target.slowRatio or 0, projectile.slowRatio)
                target.slowUntilTick = state.tick + projectile.slowTicks
                events[#events + 1] = {
                    type = "enemy_slowed", tick = state.tick,
                    enemyId = target.enemyId, ratio = target.slowRatio,
                    untilTick = target.slowUntilTick,
                }
            end
        end
    end
end

local function finishIfNeeded(state, events)
    if state.result then return end
    if state.hpZeroThisTick or state.hp <= 0 or state.bossEscapedThisTick then
        local reason = state.bossEscapedThisTick and "boss_escaped" or "hp_zero"
        state.result = { kind = "defeat", tick = state.tick, reason = reason }
        state.projectiles = {}
        events[#events + 1] = { type = "battle_defeated", tick = state.tick, reason = reason }
        return
    end
    if state.bossKilledThisTick then
        state.result = { kind = "victory", tick = state.tick, reason = "boss_killed" }
        state.projectiles = {}
        events[#events + 1] = { type = "battle_victory", tick = state.tick, reason = "boss_killed" }
        return
    end
    if not state.bossRequired and state.nextSpawnIndex > #state.spawnSchedule and activeEnemyCount(state) == 0 then
        state.result = { kind = "wave_complete", tick = state.tick }
        state.projectiles = {}
        events[#events + 1] = { type = "wave_completed", tick = state.tick, waveId = state.waveId }
    end
end

function Battle.step(state, dtFixed, commands)
    if state.result then return {}, "battle_finished" end
    if math.abs(dtFixed - FIXED_DT) > 1e-12 then return nil, "fixed_dt_required" end
    local events = state.pendingEvents
    state.pendingEvents = {}
    state.bossKilledThisTick = false
    state.bossEscapedThisTick = false
    state.hpZeroThisTick = false
    applyCommands(state, commands, events)
    local nextTick = state.tick + 1
    expireSlows(state, nextTick)
    spawnAtTick(state, nextTick, events)
    state.tick = nextTick
    moveEnemies(state, nextTick)
    processLeaks(state, events)
    local due = moveProjectiles(state, events)
    fireTowers(state, events)
    processHits(state, due, events)
    finishIfNeeded(state, events)
    return events, nil
end

function Battle.activeEnemies(state)
    local result = {}
    for _, enemy in ipairs(state.enemies) do
        if enemy.alive then
            local item = copy(enemy)
            item.x, item.y = enemyPosition(state, enemy)
            result[#result + 1] = item
        end
    end
    table.sort(result, function(left, right) return left.spawnOrdinal < right.spawnOrdinal end)
    return result
end

function Battle.snapshot(state)
    return {
        waveId = state.waveId,
        waveIndex = state.waveIndex,
        tick = state.tick,
        hp = state.hp,
        result = copy(state.result),
        observations = copy(state.observations),
        towerInstances = copy(state.towers),
        enemies = Battle.activeEnemies(state),
        projectiles = copy(state.projectiles),
    }
end

function Battle.summary(state)
    return {
        waveId = state.waveId,
        waveIndex = state.waveIndex,
        resultKind = state.result and state.result.kind or nil,
        resultReason = state.result and state.result.reason or nil,
        tick = state.tick,
        hp = state.hp,
        leaks = state.observations.leaks,
        kills = state.observations.kills,
        shots = state.observations.shots,
        hits = state.observations.hits,
        spawned = state.observations.spawned,
        towerInstances = copy(state.towers),
    }
end

Battle.FIXED_DT = FIXED_DT
Battle.EPS_DISTANCE = EPS_DISTANCE
Battle.EPS_CHARGE = EPS_CHARGE

return Battle
