local Content = require("src.content")

local Rules = {}

local function copy(value)
    return Content.clone(value)
end

local function findTower(run, instanceId)
    for _, tower in ipairs(run.towerInstances or {}) do
        if tower.instanceId == instanceId then
            return tower
        end
    end
    return nil
end

local function hasModule(run, moduleId)
    for _, module in ipairs(run.modules or {}) do
        if module == moduleId or module.moduleId == moduleId or module.id == moduleId then
            return true
        end
    end
    return false
end

local function countPlaced(run, ignoredInstanceId)
    local count = 0
    for _, tower in ipairs(run.towerInstances or {}) do
        if tower.instanceId ~= ignoredInstanceId and tower.placement then
            count = count + 1
        end
    end
    return count
end

local function placedTowerIds(run)
    local result = {}
    for _, tower in ipairs(run.towerInstances or {}) do
        if tower.placement then result[#result + 1] = tower.instanceId end
    end
    table.sort(result)
    return result
end

local function findModule(run, moduleId)
    for index, entry in ipairs(run.modules or {}) do
        local currentId = type(entry) == "table" and (entry.moduleId or entry.id) or entry
        if currentId == moduleId then return entry, index end
    end
    return nil, nil
end

-- Installed IDs are stable throughout COMBAT; definitions own their tiers.
local function midModuleIds(defs, run, ignoredId)
    local seen, ids = {}, {}
    for _, entry in ipairs(run.modules or {}) do
        local id = type(entry) == "table" and (entry.moduleId or entry.id) or entry
        local def = defs.modulesById and defs.modulesById[id]
        if id ~= ignoredId and def and def.tier == "mid" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

function Rules.midModuleComposition(defs, run)
    local ids = midModuleIds(defs, run)
    return { moduleIds = ids, count = #ids, qualifies = #ids >= 2 }
end

local function midLinkBonus(defs, run)
    return hasModule(run, "M41") and math.min(32, 8 * #midModuleIds(defs, run, "M41")) or 0
end

local function denseArrayCount(value)
    if type(value) ~= "table" then return nil end
    local count, maximum = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return nil end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then return nil end
    return count
end

-- Recorded payments belong to installed objects. A partial or estimated sum
-- cannot prove either the committed combat condition or the live effect.
function Rules.modulePurchaseValue(defs, run, excludedModuleId)
    local modules = type(run) == "table" and run.modules or nil
    if denseArrayCount(modules) == nil then return nil, "invalid_module_array" end
    local total, seen, ids = 0, {}, {}
    for _, entry in ipairs(modules) do
        if type(entry) ~= "table" then return nil, "invalid_module_entry" end
        local id = entry.moduleId or entry.id
        if not id or not defs.modulesById[id] then return nil, "unknown_module" end
        if seen[id] then return nil, "duplicate_module" end
        local paid = entry.paidGold
        if type(paid) ~= "number" or paid < 0 or paid == math.huge or paid % 1 ~= 0 then
            return nil, "invalid_module_paid_gold"
        end
        seen[id] = true
        if id ~= excludedModuleId then
            total = total + paid
            if total == math.huge then return nil, "invalid_module_paid_gold" end
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return { paidGoldTotal = total, moduleIds = ids }, nil
end

local function assetLinkBonus(defs, run)
    local value = Rules.modulePurchaseValue(defs, run, "M42")
    return value and hasModule(run, "M42") and math.min(30, math.floor(value.paidGoldTotal / 4) * 2) or 0
end

local function mixedTowerDetail(defs, tower)
    if type(tower) ~= "table" or type(tower.instanceId) ~= "number" or tower.instanceId <= 0
        or tower.instanceId % 1 ~= 0 or tower.instanceId == math.huge then return nil, "invalid_tower_identity" end
    if not defs.towersById[tower.typeId] then return nil, "unknown_tower_type" end
    local count = denseArrayCount(tower.patchIds)
    if count == nil or count > 3 then return nil, "invalid_mixed_patch_array" end
    local ids, counts = {}, {}
    for index = 1, count do
        local id = tower.patchIds[index]
        if type(id) ~= "string" or not defs.patchesById[id] then return nil, "unknown_mixed_patch" end
        if not counts[id] then ids[#ids + 1] = id end
        counts[id] = (counts[id] or 0) + 1
    end
    table.sort(ids)
    local placement = tower.placement
    if placement ~= nil and (type(placement) ~= "table" or type(placement.x) ~= "number"
        or type(placement.y) ~= "number" or placement.x % 1 ~= 0 or placement.y % 1 ~= 0
        or math.abs(placement.x) == math.huge or math.abs(placement.y) == math.huge) then
        return nil, "invalid_mixed_placement"
    end
    return { instanceId = tower.instanceId, typeId = tower.typeId, placed = placement ~= nil,
        placement = copy(placement), distinctPatchIds = ids, distinctPatchCount = #ids, patchCounts = counts,
        qualifies = placement ~= nil and #ids == 3 }, nil
end

-- COMBAT permits only placement of existing reserves. Their distinct type
-- set can only shrink; validating all immutable identities proves the interval.
function Rules.reserveComposition(defs, run)
    if type(run) ~= "table" or denseArrayCount(run.towerInstances) == nil then
        return nil, "invalid_reserve_tower_array"
    end
    local result = { typeIds = {}, count = 0, towerDetails = {} }
    local seenTypes = {}
    for _, tower in ipairs(run.towerInstances) do
        local detail, reason = mixedTowerDetail(defs, tower)
        if not detail then return nil, reason end
        if result.towerDetails[detail.instanceId] then return nil, "duplicate_tower_identity" end
        result.towerDetails[detail.instanceId] = detail
        if not detail.placed and not seenTypes[detail.typeId] then
            seenTypes[detail.typeId] = true
            result.typeIds[#result.typeIds + 1] = detail.typeId
        end
    end
    table.sort(result.typeIds)
    result.count = #result.typeIds
    return result, nil
end

local function sameReserveIdentity(first, second)
    if not second or first.typeId ~= second.typeId then return false end
    for id, count in pairs(first.patchCounts) do
        if second.patchCounts[id] ~= count then return false end
    end
    for id, count in pairs(second.patchCounts) do
        if first.patchCounts[id] ~= count then return false end
    end
    return true
end

local function sameReservePlacement(first, second)
    if first.placed ~= second.placed then return false end
    return not first.placed or first.placement.x == second.placement.x and first.placement.y == second.placement.y
end

function Rules.reserveStartProof(defs, beforeRun, candidateRun, summary)
    local wave = type(summary) == "table" and defs.wavesById[summary.waveId]
    if type(beforeRun) ~= "table" or type(candidateRun) ~= "table" or not wave
        or beforeRun.phase ~= "COMBAT" or beforeRun.nextWaveIndex ~= wave.index
        or type(beforeRun.runId) ~= "string" or beforeRun.runId == "" or beforeRun.runId ~= candidateRun.runId
        or summary.waveIndex ~= nil and summary.waveIndex ~= wave.index
        or summary.resultKind ~= "wave_complete" or type(summary.hp) ~= "number" or summary.hp <= 0 then
        return nil, "missing_start_proof"
    end
    local start, startError = Rules.reserveComposition(defs, beforeRun)
    if not start then return nil, startError end
    local finish, finishError = Rules.reserveComposition(defs, { towerInstances = summary.towerInstances })
    if not finish then return nil, finishError end
    local candidate, candidateError = Rules.reserveComposition(defs, candidateRun)
    if not candidate then return nil, candidateError end
    if #beforeRun.towerInstances ~= #summary.towerInstances or #beforeRun.towerInstances ~= #candidateRun.towerInstances then
        return nil, "reserve_inventory_changed"
    end
    for id, first in pairs(start.towerDetails) do
        local ending, proposed = finish.towerDetails[id], candidate.towerDetails[id]
        if not sameReserveIdentity(first, ending) or not sameReserveIdentity(first, proposed)
            or not sameReservePlacement(ending, proposed)
            or first.placed and not sameReservePlacement(first, ending) then
            return nil, "reserve_identity_changed"
        end
    end
    return { qualifies = start.count >= 2 and finish.count >= 2,
        startingTypeIds = copy(start.typeIds), maintainedTypeIds = copy(finish.typeIds), count = finish.count }, nil
end

function Rules.mixedPatchComposition(defs, run)
    if type(defs) ~= "table" or type(run) ~= "table" then return nil, "invalid_mixed_run" end
    local count = denseArrayCount(run.towerInstances)
    if count == nil then return nil, "invalid_mixed_tower_array" end
    local observation = { qualifyingTowerIds = {}, qualifyingTowerCount = 0, towerDetails = {} }
    for index = 1, count do
        local detail, reason = mixedTowerDetail(defs, run.towerInstances[index])
        if not detail then return nil, reason end
        if observation.towerDetails[detail.instanceId] then return nil, "duplicate_tower_identity" end
        observation.towerDetails[detail.instanceId] = detail
        if detail.qualifies then observation.qualifyingTowerIds[#observation.qualifyingTowerIds + 1] = detail.instanceId end
    end
    table.sort(observation.qualifyingTowerIds)
    observation.qualifyingTowerCount = #observation.qualifyingTowerIds
    return observation, nil
end

local function sameMixedIdentity(start, ending)
    if not ending or start.typeId ~= ending.typeId or not ending.placed
        or start.placement.x ~= ending.placement.x or start.placement.y ~= ending.placement.y
        or #start.distinctPatchIds ~= #ending.distinctPatchIds then return false end
    for _, id in ipairs(start.distinctPatchIds) do
        if start.patchCounts[id] ~= ending.patchCounts[id] then return false end
    end
    return true
end

function Rules.mixedPatchStartProof(defs, beforeRun, candidateRun, summary)
    local wave = type(summary) == "table" and defs.wavesById[summary.waveId]
    if type(beforeRun) ~= "table" or type(candidateRun) ~= "table" or not wave
        or beforeRun.phase ~= "COMBAT" or beforeRun.nextWaveIndex ~= wave.index
        or type(beforeRun.runId) ~= "string" or beforeRun.runId == "" or beforeRun.runId ~= candidateRun.runId
        or summary.waveIndex ~= nil and summary.waveIndex ~= wave.index
        or summary.resultKind ~= "wave_complete" or type(summary.hp) ~= "number" or summary.hp <= 0 then
        return nil, "missing_start_proof"
    end
    local start, startError = Rules.mixedPatchComposition(defs, beforeRun)
    if not start then return nil, startError end
    local finish, finishError = Rules.mixedPatchComposition(defs, { towerInstances = summary.towerInstances })
    if not finish then return nil, finishError end
    local candidate, candidateError = Rules.mixedPatchComposition(defs, candidateRun)
    if not candidate then return nil, candidateError end
    local maintained = {}
    -- COMBAT may place a previously unplaced tower. Only identities qualifying in
    -- the committed start snapshot can prove the full interval; charge is mutable.
    for _, id in ipairs(start.qualifyingTowerIds) do
        local detail = start.towerDetails[id]
        if sameMixedIdentity(detail, finish.towerDetails[id]) and sameMixedIdentity(detail, candidate.towerDetails[id]) then
            maintained[#maintained + 1] = id
        end
    end
    return { qualifies = #maintained > 0, qualifyingStartTowerIds = copy(start.qualifyingTowerIds), maintainedTowerIds = maintained }, nil
end

local function investmentTowerDetail(defs, tower)
    local detail, reason = mixedTowerDetail(defs, tower)
    if not detail then return nil, reason end
    local nominal, highCount = 0, 0
    for _, id in ipairs(tower.patchIds) do
        local patch = defs.patchesById[id]
        if type(patch.price) ~= "number" or patch.price < 0 or patch.price % 1 ~= 0
            or patch.price == math.huge then return nil, "invalid_patch_nominal_price" end
        if patch.tier ~= "low" and patch.tier ~= "mid" and patch.tier ~= "high" then
            return nil, "invalid_patch_tier"
        end
        nominal = nominal + patch.price
        if nominal == math.huge then return nil, "invalid_patch_nominal_price" end
        if patch.tier == "high" then highCount = highCount + 1 end
    end
    detail.nominalPatchPrice, detail.highGradePatchCount = nominal, highCount
    detail.qualifies = detail.placed and nominal >= 21
    return detail, nil
end

function Rules.patchInvestmentComposition(defs, run)
    if type(defs) ~= "table" or type(run) ~= "table" then return nil, "invalid_investment_run" end
    local count = denseArrayCount(run.towerInstances)
    if count == nil then return nil, "invalid_investment_tower_array" end
    local result = { qualifyingTowerIds = {}, qualifyingTowerCount = 0, towerDetails = {} }
    for index = 1, count do
        local detail, reason = investmentTowerDetail(defs, run.towerInstances[index])
        if not detail then return nil, reason end
        if result.towerDetails[detail.instanceId] then return nil, "duplicate_tower_identity" end
        result.towerDetails[detail.instanceId] = detail
        if detail.qualifies then result.qualifyingTowerIds[#result.qualifyingTowerIds + 1] = detail.instanceId end
    end
    table.sort(result.qualifyingTowerIds)
    result.qualifyingTowerCount = #result.qualifyingTowerIds
    return result, nil
end

function Rules.patchInvestmentStartProof(defs, beforeRun, candidateRun, summary)
    local wave = type(summary) == "table" and defs.wavesById[summary.waveId]
    if type(beforeRun) ~= "table" or type(candidateRun) ~= "table" or not wave
        or beforeRun.phase ~= "COMBAT" or beforeRun.nextWaveIndex ~= wave.index
        or type(beforeRun.runId) ~= "string" or beforeRun.runId == "" or beforeRun.runId ~= candidateRun.runId
        or summary.waveIndex ~= nil and summary.waveIndex ~= wave.index
        or summary.resultKind ~= "wave_complete" or type(summary.hp) ~= "number" or summary.hp <= 0 then
        return nil, "missing_start_proof"
    end
    local start, startError = Rules.patchInvestmentComposition(defs, beforeRun)
    if not start then return nil, startError end
    local finish, finishError = Rules.patchInvestmentComposition(defs, { towerInstances = summary.towerInstances })
    if not finish then return nil, finishError end
    local candidate, candidateError = Rules.patchInvestmentComposition(defs, candidateRun)
    if not candidate then return nil, candidateError end
    local maintained = {}
    -- Only identities qualifying in the durable start can prove the interval.
    -- COMBAT permits new placements but never edits existing patched identities.
    for _, id in ipairs(start.qualifyingTowerIds) do
        local detail = start.towerDetails[id]
        if sameMixedIdentity(detail, finish.towerDetails[id]) and sameMixedIdentity(detail, candidate.towerDetails[id]) then
            maintained[#maintained + 1] = id
        end
    end
    return { qualifies = #maintained > 0, qualifyingStartTowerIds = copy(start.qualifyingTowerIds), maintainedTowerIds = maintained }, nil
end


-- Count physical known patch entries, including repeated IDs. A malformed
-- inventory is an observation error, never a partially qualifying deployment.
function Rules.balancedPatchComposition(defs, run)
    if type(defs) ~= "table" or type(run) ~= "table" then return nil, "invalid_balanced_run" end
    local count = denseArrayCount(run.towerInstances)
    if count == nil then return nil, "invalid_balanced_tower_array" end
    local result = { placedTowerIds = {}, placedTowerCount = 0, towerDetails = {}, allPlacedPositiveAndEqual = false }
    local common, equalCounts = nil, true
    for index = 1, count do
        local tower = run.towerInstances[index]
        local detail, reason = mixedTowerDetail(defs, tower)
        if not detail then return nil, reason end
        if result.towerDetails[detail.instanceId] then return nil, "duplicate_tower_identity" end
        detail.patchCount = denseArrayCount(tower.patchIds)
        result.towerDetails[detail.instanceId] = detail
        if detail.placed then
            result.placedTowerIds[#result.placedTowerIds + 1] = detail.instanceId
            if common == nil then common = detail.patchCount elseif common ~= detail.patchCount then equalCounts = false end
        end
    end
    table.sort(result.placedTowerIds)
    result.placedTowerCount = #result.placedTowerIds
    result.commonPatchCount = equalCounts and common or nil
    result.allPlacedPositiveAndEqual = equalCounts and common ~= nil and common > 0
    result.unlockQualifies = result.placedTowerCount >= 3 and result.allPlacedPositiveAndEqual
    result.effectQualifies = result.placedTowerCount >= 2 and result.allPlacedPositiveAndEqual
    return result, nil
end

local function sameBalancedPatches(start, ending)
    if not ending or start.typeId ~= ending.typeId or start.patchCount ~= ending.patchCount then return false end
    for _, id in ipairs(start.distinctPatchIds) do
        if start.patchCounts[id] ~= ending.patchCounts[id] then return false end
    end
    return true
end

local function sameBalancedPlacement(first, second)
    if first.placed ~= second.placed then return false end
    return not first.placed or first.placement.x == second.placement.x and first.placement.y == second.placement.y
end

function Rules.balancedPatchStartProof(defs, beforeRun, candidateRun, summary)
    local wave = type(summary) == "table" and defs.wavesById[summary.waveId]
    if type(beforeRun) ~= "table" or type(candidateRun) ~= "table" or not wave
        or beforeRun.phase ~= "COMBAT" or beforeRun.nextWaveIndex ~= wave.index
        or type(beforeRun.runId) ~= "string" or beforeRun.runId == "" or beforeRun.runId ~= candidateRun.runId
        or summary.waveIndex ~= nil and summary.waveIndex ~= wave.index
        or summary.resultKind ~= "wave_complete" or type(summary.hp) ~= "number" or summary.hp <= 0 then
        return nil, "missing_start_proof"
    end
    local start, reason = Rules.balancedPatchComposition(defs, beforeRun)
    if not start then return nil, reason end
    local finish; finish, reason = Rules.balancedPatchComposition(defs, { towerInstances = summary.towerInstances })
    if not finish then return nil, reason end
    local candidate; candidate, reason = Rules.balancedPatchComposition(defs, candidateRun)
    if not candidate then return nil, reason end
    local maintained, identitiesValid = {}, true
    -- Allowed combat writers only add placement to an existing unplaced tower.
    -- They never change inventory identities/patches or remove a placed tower.
    for id, detail in pairs(start.towerDetails) do
        local ending, saved = finish.towerDetails[id], candidate.towerDetails[id]
        if not sameBalancedPatches(detail, ending) or not sameBalancedPatches(detail, saved)
            or not sameBalancedPlacement(ending, saved)
            or detail.placed and not sameBalancedPlacement(detail, ending) then
            identitiesValid = false
        elseif detail.placed then maintained[#maintained + 1] = id end
    end
    for id in pairs(finish.towerDetails) do if not start.towerDetails[id] then identitiesValid = false end end
    for id in pairs(candidate.towerDetails) do if not start.towerDetails[id] then identitiesValid = false end end
    table.sort(maintained)
    local qualifies = identitiesValid and start.unlockQualifies and finish.unlockQualifies and candidate.unlockQualifies
        and finish.commonPatchCount == start.commonPatchCount and candidate.commonPatchCount == start.commonPatchCount
    return { qualifies = qualifies, startingPlacedTowerIds = copy(start.placedTowerIds), maintainedTowerIds = maintained,
        commonPatchCount = start.commonPatchCount, endingPlacedTowerCount = finish.placedTowerCount }, nil
end

function Rules.sharedPatchComposition(defs, run)
    if type(defs) ~= "table" or type(defs.towersById) ~= "table" or type(defs.patchesById) ~= "table"
        or type(run) ~= "table" then return nil, "invalid_shared_run" end
    local count = denseArrayCount(run.towerInstances)
    if count == nil then return nil, "invalid_shared_tower_array" end
    local result = { distinctPatchIds = {}, distinctPatchCount = 0, placedTowerIds = {},
        placedTowerCount = 0, towerDetails = {} }
    local seen = {}
    for index = 1, count do
        local tower = run.towerInstances[index]
        local detail, reason = mixedTowerDetail(defs, tower)
        if not detail then return nil, reason end
        if result.towerDetails[detail.instanceId] then return nil, "duplicate_tower_identity" end
        detail.patchCount = denseArrayCount(tower.patchIds)
        result.towerDetails[detail.instanceId] = detail
        if detail.placed then
            result.placedTowerIds[#result.placedTowerIds + 1] = detail.instanceId
            for _, id in ipairs(detail.distinctPatchIds) do
                if not seen[id] then
                    seen[id] = true
                    result.distinctPatchIds[#result.distinctPatchIds + 1] = id
                end
            end
        end
    end
    table.sort(result.distinctPatchIds)
    table.sort(result.placedTowerIds)
    result.distinctPatchCount, result.placedTowerCount = #result.distinctPatchIds, #result.placedTowerIds
    result.unlockQualifies = result.distinctPatchCount >= 5
    return result, nil
end

function Rules.sharedPatchStartProof(defs, beforeRun, candidateRun, summary)
    local wave = type(summary) == "table" and defs.wavesById[summary.waveId]
    if type(beforeRun) ~= "table" or type(candidateRun) ~= "table" or not wave
        or beforeRun.phase ~= "COMBAT" or beforeRun.nextWaveIndex ~= wave.index
        or type(beforeRun.runId) ~= "string" or beforeRun.runId == "" or beforeRun.runId ~= candidateRun.runId
        or summary.waveIndex ~= wave.index or summary.resultKind ~= "wave_complete"
        or type(summary.hp) ~= "number" or summary.hp <= 0 or summary.hp ~= summary.hp
        or summary.hp == math.huge then return nil, "missing_start_proof" end
    local start, reason = Rules.sharedPatchComposition(defs, beforeRun)
    if not start then return nil, reason end
    local finish; finish, reason = Rules.sharedPatchComposition(defs, { towerInstances = summary.towerInstances })
    if not finish then return nil, reason end
    local candidate; candidate, reason = Rules.sharedPatchComposition(defs, candidateRun)
    if not candidate then return nil, reason end
    local maintained, identitiesValid = {}, true
    -- COMBAT can only place an existing reserve. Patches and starting placements
    -- cannot change, so a valid starting union is a lower bound for every tick.
    for id, detail in pairs(start.towerDetails) do
        local ending, saved = finish.towerDetails[id], candidate.towerDetails[id]
        if not sameBalancedPatches(detail, ending) or not sameBalancedPatches(detail, saved)
            or not sameBalancedPlacement(ending, saved)
            or detail.placed and not sameBalancedPlacement(detail, ending) then
            identitiesValid = false
        elseif detail.placed then maintained[#maintained + 1] = id end
    end
    for id in pairs(finish.towerDetails) do if not start.towerDetails[id] then identitiesValid = false end end
    for id in pairs(candidate.towerDetails) do if not start.towerDetails[id] then identitiesValid = false end end
    table.sort(maintained)
    return { qualifies = identitiesValid and start.unlockQualifies and finish.unlockQualifies and candidate.unlockQualifies,
        startingDistinctPatchIds = copy(start.distinctPatchIds), startingDistinctPatchCount = start.distinctPatchCount,
        endingDistinctPatchIds = copy(finish.distinctPatchIds), endingDistinctPatchCount = finish.distinctPatchCount,
        maintainedStartTowerIds = maintained }, nil
end

function Rules.projectTradeTowerStats(defs, beforeRun, proposedRun, towerInstanceId)
    if towerInstanceId == nil then return nil, "tower_not_selected" end
    if type(beforeRun) ~= "table" or type(beforeRun.towerInstances) ~= "table" then
        return nil, "invalid_trade_before_run"
    end
    if type(proposedRun) ~= "table" or type(proposedRun.towerInstances) ~= "table" then
        return nil, "invalid_trade_proposed_run"
    end
    local before, beforeError = Rules.projectStats(defs, beforeRun, towerInstanceId)
    if not before then return nil, beforeError end
    local after, afterError = Rules.projectStats(defs, proposedRun, towerInstanceId)
    if not after then return nil, afterError end
    local context = { towerInstanceId = towerInstanceId }
    return { towerInstanceId = towerInstanceId, before = before, after = after,
        beforeStatus = Rules.projectModuleStatus(defs, beforeRun, "M15", context),
        afterStatus = Rules.projectModuleStatus(defs, proposedRun, "M15", context),
        beforeMaintenanceStatus = Rules.projectModuleStatus(defs, beforeRun, "M14", context),
        afterMaintenanceStatus = Rules.projectModuleStatus(defs, proposedRun, "M14", context),
        beforeBalancedStatus = Rules.projectModuleStatus(defs, beforeRun, "M12", context),
        afterBalancedStatus = Rules.projectModuleStatus(defs, proposedRun, "M12", context),
        beforeSharedStatus = Rules.projectModuleStatus(defs, beforeRun, "M16", context),
        afterSharedStatus = Rules.projectModuleStatus(defs, proposedRun, "M16", context) }, nil
end

local function buildPathCells(map)
    local occupied = {}
    for _, route in ipairs(map.routes or {}) do
        for pointIndex = 2, #route.points do
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

local function resolveMap(defs, mapOrId)
    if type(mapOrId) == "table" then return mapOrId end
    return defs.mapsById and defs.mapsById[mapOrId] or nil
end

local function surroundingTower(run, tower, cardinalOnly, predicate)
    if not tower.placement then return false end
    for _, other in ipairs(run.towerInstances or {}) do
        if other.instanceId ~= tower.instanceId and other.placement then
            local dx = math.abs(other.placement.x - tower.placement.x)
            local dy = math.abs(other.placement.y - tower.placement.y)
            local isNeighbor = cardinalOnly and (dx + dy == 1)
                or (not cardinalOnly and dx <= 1 and dy <= 1 and dx + dy > 0)
            if isNeighbor and (not predicate or predicate(other)) then
                return true
            end
        end
    end
    return false
end

local function moduleGrowth(run, moduleId)
    local entry = findModule(run, moduleId)
    return type(entry) == "table" and (entry.growth or 0) or 0
end

local function placedTypeCount(run)
    local seen, count = {}, 0
    for _, tower in ipairs(run.towerInstances or {}) do
        if tower.placement and not seen[tower.typeId] then
            seen[tower.typeId] = true
            count = count + 1
        end
    end
    return count
end

local function sharesPatchWithPlacedTower(run, tower)
    local own = {}
    for _, patchId in ipairs(tower.patchIds or {}) do own[patchId] = true end
    if next(own) == nil then return false end
    for _, other in ipairs(run.towerInstances or {}) do
        if other.instanceId ~= tower.instanceId and other.placement then
            for _, patchId in ipairs(other.patchIds or {}) do
                if own[patchId] then return true end
            end
        end
    end
    return false
end

local function placedTowers(run)
    local result = {}
    for _, tower in ipairs(run.towerInstances or {}) do
        if tower.placement then result[#result + 1] = tower end
    end
    table.sort(result, function(left, right) return left.instanceId < right.instanceId end)
    return result
end

local function qualifyingPlacedTowerIds(run, predicate)
    local ids = {}
    local placed = placedTowers(run)
    for _, tower in ipairs(placed) do
        if predicate(tower) then ids[#ids + 1] = tower.instanceId end
    end
    return ids, #placed
end

local function sameTypeCardinalNeighborIds(run, tower)
    local ids = {}
    if not tower or not tower.placement then return ids end
    for _, other in ipairs(run.towerInstances or {}) do
        if other.instanceId ~= tower.instanceId and other.placement and other.typeId == tower.typeId then
            local dx = math.abs(other.placement.x - tower.placement.x)
            local dy = math.abs(other.placement.y - tower.placement.y)
            if dx + dy == 1 then ids[#ids + 1] = other.instanceId end
        end
    end
    table.sort(ids)
    return ids
end

local function sharedPatchDetail(run, tower)
    local own, patchIds, counterpartIds, matches = {}, {}, {}, {}
    for _, patchId in ipairs((tower and tower.patchIds) or {}) do own[patchId] = true end
    local seenPatch, seenCounterpart, seenMatch = {}, {}, {}
    if tower and tower.placement then
        for _, other in ipairs(run.towerInstances or {}) do
            if other.instanceId ~= tower.instanceId and other.placement then
                for _, patchId in ipairs(other.patchIds or {}) do
                    if own[patchId] then
                        if not seenPatch[patchId] then
                            seenPatch[patchId] = true
                            patchIds[#patchIds + 1] = patchId
                        end
                        if not seenCounterpart[other.instanceId] then
                            seenCounterpart[other.instanceId] = true
                            counterpartIds[#counterpartIds + 1] = other.instanceId
                        end
                        local matchKey = tostring(patchId) .. ":" .. tostring(other.instanceId)
                        if not seenMatch[matchKey] then
                            seenMatch[matchKey] = true
                            matches[#matches + 1] = {
                                patchId = patchId, counterpartInstanceId = other.instanceId,
                            }
                        end
                    end
                end
            end
        end
    end
    table.sort(patchIds)
    table.sort(counterpartIds)
    table.sort(matches, function(left, right)
        if left.patchId ~= right.patchId then return left.patchId < right.patchId end
        return left.counterpartInstanceId < right.counterpartInstanceId
    end)
    return {
        sharedPatchIds = patchIds,
        counterpartInstanceIds = counterpartIds,
        matches = matches,
    }
end

local function patchLeadSummary(run)
    local highestPatchCount, highestPatchTowerIds = 0, {}
    local placed = placedTowers(run)
    for _, tower in ipairs(placed) do
        local patchCount = #(tower.patchIds or {})
        if patchCount > highestPatchCount then
            highestPatchCount = patchCount
            highestPatchTowerIds = { tower.instanceId }
        elseif patchCount == highestPatchCount and patchCount > 0 then
            highestPatchTowerIds[#highestPatchTowerIds + 1] = tower.instanceId
        end
    end
    local soleHighestTowerId = highestPatchCount > 0 and #highestPatchTowerIds == 1
        and highestPatchTowerIds[1] or nil
    local state = soleHighestTowerId and "sole_highest"
        or (highestPatchCount > 0 and "tie" or "none")
    return {
        placedTowerCount = #placed,
        highestPatchCount = highestPatchCount,
        highestPatchTowerIds = highestPatchTowerIds,
        soleHighestTowerId = soleHighestTowerId,
        state = state,
    }
end

local function hasUniquePatchLead(run, tower)
    local patchCount = #(tower.patchIds or {})
    if patchCount == 0 then return false end
    for _, other in ipairs(run.towerInstances or {}) do
        if other.instanceId ~= tower.instanceId and other.placement
            and #(other.patchIds or {}) >= patchCount then
            return false
        end
    end
    return true
end

local function recentHitTypeCount(enemy, tick)
    local count = 0
    for _, lastTick in pairs((enemy and enemy.lastHitTickByTowerType) or {}) do
        if type(lastTick) == "number" and lastTick <= tick and tick - lastTick <= 120 then
            count = count + 1
        end
    end
    return count
end

local function applyModuleGrowth(defs, candidate, moduleId, cause)
    local entry, index = findModule(candidate, moduleId)
    if not entry then return nil end
    local moduleDef = defs.modulesById and defs.modulesById[moduleId]
    if not moduleDef or not moduleDef.growthStep or not moduleDef.growthCap then return nil end
    if type(entry) ~= "table" then
        entry = { moduleId = moduleId, paidGold = moduleDef.price, growth = 0 }
        candidate.modules[index] = entry
    end
    local before = entry.growth or 0
    local after = math.min(moduleDef.growthCap, before + moduleDef.growthStep)
    entry.growth = after
    if after == before then return nil end
    return {
        type = "module_growth_changed", moduleId = moduleId,
        before = before, after = after, delta = after - before,
        cap = moduleDef.growthCap, cause = cause,
    }
end

function Rules.newRun(defs, options)
    options = options or {}
    local mapId = options.mapId or "M01"
    assert(defs.mapsById[mapId], "unknown mapId")
    return {
        runId = options.runId or "local-run",
        contentVersion = defs.version,
        mapId = mapId,
        nextWaveIndex = 1,
        gold = 12,
        hp = 20,
        baseTowerCapacity = 6,
        baseModuleSlots = 4,
        towerInstances = {
            { instanceId = 1, typeId = "T01", paidGold = 0, patchIds = {}, placement = nil, charge = 0, activated = false },
            { instanceId = 2, typeId = "T01", paidGold = 0, patchIds = {}, placement = nil, charge = 0, activated = false },
        },
        modules = copy(options.modules or {}),
        acquiredModuleIds = copy(options.acquiredModuleIds or {}),
        completedWaveIds = {},
        nextInstanceId = 3,
    }
end

function Rules.towerCapacity(run)
    return (run.baseTowerCapacity or 6)
        + (hasModule(run, "M05") and 2 or 0)
        - (hasModule(run, "M06") and 2 or 0)
end

function Rules.moduleCapacity(run)
    return run.baseModuleSlots or 4
end

function Rules.moduleSlots(run)
    local capacity, installed = Rules.moduleCapacity(run), #(run.modules or {})
    return { moduleCapacity = capacity, installedModuleCount = installed,
        emptySlots = math.max(0, capacity - installed) }
end

local function spareCircuitBonus(run)
    return hasModule(run, "M43") and math.min(36, 12 * Rules.moduleSlots(run).emptySlots) or 0
end

function Rules.applyModuleGrowth(defs, run, moduleId, cause)
    local moduleDef = defs.modulesById and defs.modulesById[moduleId]
    if not moduleDef then return nil, nil, "unknown_module" end
    if not moduleDef.growthStep or not moduleDef.growthCap then
        return nil, nil, "module_has_no_growth"
    end
    if not hasModule(run, moduleId) then return nil, nil, "module_not_installed" end
    local candidate = copy(run)
    local event = applyModuleGrowth(defs, candidate, moduleId, cause)
    return candidate, event, nil
end

function Rules.evaluateCapacityTransition(beforeRun, proposedRun, recallTowerIds)
    if type(beforeRun) ~= "table" or type(proposedRun) ~= "table" then
        return nil, "invalid_capacity_transition"
    end

    local eligibleRecallTowerIds = placedTowerIds(proposedRun)
    local decision = {
        towerCapacityBefore = Rules.towerCapacity(beforeRun),
        towerCapacityAfter = Rules.towerCapacity(proposedRun),
        moduleCapacityBefore = Rules.moduleCapacity(beforeRun),
        moduleCapacityAfter = Rules.moduleCapacity(proposedRun),
        placedTowerCountBefore = #placedTowerIds(beforeRun),
        placedTowerCountAfter = #eligibleRecallTowerIds,
        installedModuleCountBefore = #(beforeRun.modules or {}),
        installedModuleCountAfter = #(proposedRun.modules or {}),
        eligibleRecallTowerIds = eligibleRecallTowerIds,
        selectedRecallTowerIds = {},
    }
    decision.requiredRecallCount = math.max(0,
        decision.placedTowerCountAfter - decision.towerCapacityAfter)

    if decision.installedModuleCountAfter > decision.moduleCapacityAfter then
        return nil, "module_slots"
    end
    if recallTowerIds == nil then return decision, nil end

    local selectedCount = denseArrayCount(recallTowerIds)
    if selectedCount == nil then return nil, "invalid_recall_selection" end
    if decision.requiredRecallCount > 0 and selectedCount == 0 then
        return nil, "recall_selection_required"
    end
    if selectedCount ~= decision.requiredRecallCount then
        return nil, "recall_count_mismatch"
    end

    local selected = {}
    for _, instanceId in ipairs(recallTowerIds) do
        if selected[instanceId] then return nil, "duplicate_recall_target" end
        local tower = findTower(proposedRun, instanceId)
        if not tower or not tower.placement then return nil, "recall_target_not_placed" end
        selected[instanceId] = true
        decision.selectedRecallTowerIds[#decision.selectedRecallTowerIds + 1] = instanceId
    end
    table.sort(decision.selectedRecallTowerIds)
    return decision, nil
end

function Rules.validatePlacement(defs, run, mapOrId, instanceId, x, y)
    local map = resolveMap(defs, mapOrId)
    if not map then return false, "unknown_map" end
    local tower = findTower(run, instanceId)
    if not tower then return false, "unknown_tower" end
    if type(x) ~= "number" or type(y) ~= "number" or x % 1 ~= 0 or y % 1 ~= 0 then
        return false, "placement_must_be_integer_cell"
    end
    if x < 0 or x >= map.width or y < 0 or y >= map.height then
        return false, "outside_map"
    end
    if buildPathCells(map)[x .. ":" .. y] then
        return false, "path_cell"
    end
    for _, other in ipairs(run.towerInstances or {}) do
        if other.instanceId ~= instanceId and other.placement and other.placement.x == x and other.placement.y == y then
            return false, "occupied_cell"
        end
    end
    if not tower.placement and countPlaced(run) >= Rules.towerCapacity(run) then
        return false, "tower_capacity"
    end
    return true
end

function Rules.tryPlaceTower(defs, run, mapOrId, instanceId, x, y, mode)
    local current = findTower(run, instanceId)
    if not current then return nil, nil, "unknown_tower" end
    if mode == "combat" and current.placement then
        return nil, nil, "combat_move_forbidden"
    end
    local valid, reason = Rules.validatePlacement(defs, run, mapOrId, instanceId, x, y)
    if not valid then return nil, nil, reason end
    local candidate = copy(run)
    local tower = assert(findTower(candidate, instanceId))
    tower.placement = { x = x, y = y }
    tower.activated = true
    return candidate, { { type = "tower_placed", instanceId = instanceId, x = x, y = y } }, nil
end

function Rules.tryRecallTower(run, instanceId, mode)
    if mode == "combat" then return nil, nil, "combat_recall_forbidden" end
    local current = findTower(run, instanceId)
    if not current then return nil, nil, "unknown_tower" end
    local candidate = copy(run)
    findTower(candidate, instanceId).placement = nil
    return candidate, { { type = "tower_recalled", instanceId = instanceId } }, nil
end

local function buildInventoryProposal(defs, run, request)
    if type(defs) ~= "table" or type(run) ~= "table" or type(request) ~= "table" then
        return nil, nil, "invalid_transaction_request"
    end
    local kind = request.kind
    if kind ~= "sell_tower" and kind ~= "sell_module" and kind ~= "recall_tower" then
        return nil, nil, "unknown_transaction_kind"
    end
    if kind == "sell_tower" or kind == "sell_module" then
        if request.phase ~= "SHOP" then return nil, nil, "shop_required" end
    elseif request.phase == "COMBAT" then
        return nil, nil, "combat_recall_forbidden"
    elseif request.phase ~= "SHOP" and request.phase ~= "PREPARE" then
        return nil, nil, "recall_phase_required"
    end

    local candidate = copy(run)
    local detail = { kind = kind, refundGold = 0 }
    if kind == "sell_tower" then
        local target = findTower(run, request.instanceId)
        if not target then return nil, nil, "unknown_tower" end
        local paidGold = target.paidGold
        if type(paidGold) ~= "number" or paidGold < 0 or paidGold % 1 ~= 0 then
            return nil, nil, "invalid_paid_gold"
        end
        local candidateTarget
        for index, tower in ipairs(candidate.towerInstances or {}) do
            if tower.instanceId == request.instanceId then
                candidateTarget = tower
                table.remove(candidate.towerInstances, index)
                break
            end
        end
        assert(candidateTarget, "candidate tower missing")
        detail.instanceId = request.instanceId
        detail.typeId = target.typeId
        detail.paidGold = paidGold
        detail.refundGold = math.floor(paidGold / 2)
        detail.patchCount = #(target.patchIds or {})
        candidate.gold = candidate.gold + detail.refundGold
    elseif kind == "sell_module" then
        local entry, index = findModule(run, request.moduleId)
        local moduleDef = defs.modulesById and defs.modulesById[request.moduleId]
        if not entry or not moduleDef then return nil, nil, "unknown_module" end
        local paidGold
        if type(entry) == "table" then
            paidGold = entry.paidGold
            if type(paidGold) ~= "number" or paidGold < 0 or paidGold % 1 ~= 0 then
                return nil, nil, "invalid_paid_gold"
            end
        else
            paidGold = moduleDef.price
        end
        table.remove(candidate.modules, index)
        candidate.acquiredModuleIds = candidate.acquiredModuleIds or {}
        candidate.acquiredModuleIds[request.moduleId] = true
        detail.moduleId = request.moduleId
        detail.paidGold = paidGold
        detail.refundGold = math.floor(paidGold / 2)
        detail.growth = type(entry) == "table" and (entry.growth or 0) or 0
        candidate.gold = candidate.gold + detail.refundGold
    else
        local target = findTower(run, request.instanceId)
        if not target then return nil, nil, "unknown_tower" end
        if not target.placement then return nil, nil, "tower_not_placed" end
        local candidateTarget = assert(findTower(candidate, request.instanceId))
        candidateTarget.placement = nil
        detail.instanceId = request.instanceId
        detail.typeId = target.typeId
    end
    return candidate, detail, nil
end

function Rules.previewInventoryTransaction(defs, run, request)
    local proposed, detail, reason = buildInventoryProposal(defs, run, request)
    if not proposed then return nil, reason end
    local decision, capacityReason = Rules.evaluateCapacityTransition(run, proposed, nil)
    if not decision then return nil, capacityReason end
    for key, value in pairs(detail) do decision[key] = copy(value) end
    decision.goldBefore = run.gold
    decision.goldAfter = proposed.gold
    if request.kind == "sell_module" then
        decision.spareCircuitBefore = Rules.projectModuleStatus(defs, run, "M43")
        decision.spareCircuitAfter = Rules.projectModuleStatus(defs, proposed, "M43")
        decision.emergencyBefore = Rules.projectModuleStatus(defs, run, "M46")
        decision.emergencyAfter = Rules.projectModuleStatus(defs, proposed, "M46")
        decision.midLinkBefore = Rules.projectModuleStatus(defs, run, "M41")
        decision.midLinkAfter = Rules.projectModuleStatus(defs, proposed, "M41")
        decision.assetLinkBefore = Rules.projectModuleStatus(defs, run, "M42")
        decision.assetLinkAfter = Rules.projectModuleStatus(defs, proposed, "M42")
        decision.depositBefore = Rules.projectModuleStatus(defs, run, "M28")
        decision.depositAfter = Rules.projectModuleStatus(defs, proposed, "M28")
        decision.sharedBefore = Rules.projectModuleStatus(defs, run, "M16")
        decision.sharedAfter = Rules.projectModuleStatus(defs, proposed, "M16")
    end
    decision.reserveBefore = Rules.projectModuleStatus(defs, run, "M31")
    decision.reserveAfter = Rules.projectModuleStatus(defs, proposed, "M31")
    decision.canCommit = decision.requiredRecallCount == 0
    return decision, nil
end

function Rules.tryInventoryTransaction(defs, run, request)
    local proposed, detail, reason = buildInventoryProposal(defs, run, request)
    if not proposed then return nil, nil, reason end
    local recallTowerIds = request.recallTowerIds or {}
    local decision, capacityReason = Rules.evaluateCapacityTransition(run, proposed, recallTowerIds)
    if not decision then return nil, nil, capacityReason end

    local events = {}
    for _, instanceId in ipairs(decision.selectedRecallTowerIds) do
        assert(findTower(proposed, instanceId)).placement = nil
        events[#events + 1] = {
            type = "tower_recalled", instanceId = instanceId, reason = "capacity_adjustment",
        }
    end
    if detail.kind == "sell_tower" then
        events[#events + 1] = {
            type = "tower_sold", instanceId = detail.instanceId, typeId = detail.typeId,
            paidGold = detail.paidGold, refundGold = detail.refundGold,
            patchCount = detail.patchCount,
        }
    elseif detail.kind == "sell_module" then
        events[#events + 1] = {
            type = "module_sold", moduleId = detail.moduleId,
            paidGold = detail.paidGold, refundGold = detail.refundGold,
            growth = detail.growth,
        }
    else
        events[#events + 1] = {
            type = "tower_recalled", instanceId = detail.instanceId, reason = "manual",
        }
    end
    return proposed, events, nil
end

function Rules.projectStats(defs, run, towerOrInstanceId)
    local tower
    if type(towerOrInstanceId) == "table" then
        tower = towerOrInstanceId
    elseif type(towerOrInstanceId) == "number" then
        tower = findTower(run, towerOrInstanceId)
    elseif type(towerOrInstanceId) == "string" then
        tower = { instanceId = -1, typeId = towerOrInstanceId, patchIds = {}, placement = nil }
    end
    if not tower then return nil, "unknown_tower" end
    local towerDef = defs.towersById[tower.typeId]
    if not towerDef then return nil, "unknown_tower_type" end

    local patchDamage, patchRate, patchRange = 0, 0, 0
    for _, patchId in ipairs(tower.patchIds or {}) do
        local patch = defs.patchesById[patchId]
        if not patch then return nil, "unknown_patch:" .. tostring(patchId) end
        patchDamage = patchDamage + (patch.damage or 0)
        patchRate = patchRate + (patch.rate or 0)
        patchRange = patchRange + (patch.range or 0)
    end

    local moduleDamage, moduleRate, moduleRange = 0, 0, 0
    local conditions = {}
    local deployed = tower.placement ~= nil
    local distinctTypes = placedTypeCount(run)
    if hasModule(run, "M05") then moduleDamage = moduleDamage - 0.20 end
    if hasModule(run, "M02") and deployed and not surroundingTower(run, tower, false) then
        moduleDamage = moduleDamage + 0.30
        conditions[#conditions + 1] = "M02"
    end
    if hasModule(run, "M01") and deployed and surroundingTower(run, tower, true, function(other)
        return other.typeId ~= tower.typeId
    end) then
        moduleRate = moduleRate + 0.20
        conditions[#conditions + 1] = "M01"
    end
    if hasModule(run, "M03") and deployed then
        moduleDamage = moduleDamage + 0.05 * distinctTypes
        conditions[#conditions + 1] = "M03"
    end
    if hasModule(run, "M04") and deployed and distinctTypes == 1 then
        moduleRate = moduleRate + 0.35
        conditions[#conditions + 1] = "M04"
    end
    if hasModule(run, "M06") and deployed then
        moduleDamage = moduleDamage + 0.35
        conditions[#conditions + 1] = "M06"
    end
    if hasModule(run, "M07") and deployed and surroundingTower(run, tower, true, function(other)
        return other.typeId == tower.typeId
    end) then
        moduleRate = moduleRate + 0.20
        conditions[#conditions + 1] = "M07"
    end
    if hasModule(run, "M08") and deployed and distinctTypes == 2 then
        moduleRate = moduleRate + 0.25
        conditions[#conditions + 1] = "M08"
    end
    if hasModule(run, "M09") and deployed and #(tower.patchIds or {}) == 3 then
        moduleDamage = moduleDamage + 0.30
        conditions[#conditions + 1] = "M09"
    end
    if hasModule(run, "M10") and deployed and #(tower.patchIds or {}) == 0 then
        moduleRate = moduleRate + 0.25
        conditions[#conditions + 1] = "M10"
    end
    if hasModule(run, "M11") and deployed and sharesPatchWithPlacedTower(run, tower) then
        moduleDamage = moduleDamage + 0.20
        conditions[#conditions + 1] = "M11"
    end
    if hasModule(run, "M13") and deployed and hasUniquePatchLead(run, tower) then
        moduleDamage = moduleDamage + 0.40
        conditions[#conditions + 1] = "M13"
    end
    if deployed then
        for _, moduleId in ipairs({ "M33", "M34", "M37" }) do
            local growth = moduleGrowth(run, moduleId)
            if growth > 0 then
                moduleDamage = moduleDamage + growth / 100
                conditions[#conditions + 1] = moduleId
            end
        end
    end
    if hasModule(run, "M41") and deployed then
        moduleDamage = moduleDamage + midLinkBonus(defs, run) / 100
        conditions[#conditions + 1] = "M41"
    end
    if hasModule(run, "M12") and deployed then
        local observation, reason = Rules.balancedPatchComposition(defs, run)
        if not observation then return nil, reason end
        if observation.effectQualifies then
            moduleRange = moduleRange + 0.25
            conditions[#conditions + 1] = "M12"
        end
    end
    if hasModule(run, "M16") and deployed then
        local observation, reason = Rules.sharedPatchComposition(defs, run)
        if not observation then return nil, reason end
        if observation.distinctPatchCount > 0 then
            moduleDamage = moduleDamage + math.min(27, 3 * observation.distinctPatchCount) / 100
            conditions[#conditions + 1] = "M16"
        end
    end
    if hasModule(run, "M14") and deployed then
        local detail, reason = investmentTowerDetail(defs, tower)
        if not detail then return nil, reason end
        if detail.highGradePatchCount > 0 then
            moduleDamage = moduleDamage + 0.08 * detail.highGradePatchCount
            conditions[#conditions + 1] = "M14"
        end
    end
    if hasModule(run, "M15") and deployed then
        local detail, reason = mixedTowerDetail(defs, tower)
        if not detail then return nil, reason end
        if detail.qualifies then
            moduleRate = moduleRate + 0.20
            conditions[#conditions + 1] = "M15"
        end
    end
    if hasModule(run, "M42") and deployed then
        moduleDamage = moduleDamage + assetLinkBonus(defs, run) / 100
        conditions[#conditions + 1] = "M42"
    end
    if hasModule(run, "M43") and deployed then
        moduleDamage = moduleDamage + spareCircuitBonus(run) / 100
        conditions[#conditions + 1] = "M43"
    end
    if hasModule(run, "M46") and deployed and run.hp >= 1 and run.hp <= 5 then
        moduleDamage = moduleDamage + 0.40
        conditions[#conditions + 1] = "M46"
    end
    if hasModule(run, "M44") and deployed and (run.gold or 0) >= 20 then
        moduleDamage = moduleDamage + 0.25
        conditions[#conditions + 1] = "M44"
    end
    if hasModule(run, "M45") and deployed and (run.gold or 0) <= 3 then
        moduleRate = moduleRate + 0.25
        conditions[#conditions + 1] = "M45"
    end
    if hasModule(run, "M17") then conditions[#conditions + 1] = "M17_on_slowed_target" end
    if hasModule(run, "M18") then conditions[#conditions + 1] = "M18_on_recent_type_hits" end

    local damageFactor = math.max(0.1, 1 + patchDamage) * math.max(0.1, 1 + moduleDamage)
    local rateFactor = math.max(0.1, 1 + patchRate) * math.max(0.1, 1 + moduleRate)
    local rangeFactor = math.max(0.1, 1 + patchRange) * math.max(0.1, 1 + moduleRange)
    return {
        damage = towerDef.damage * damageFactor,
        attackRate = towerDef.attackRate * rateFactor,
        range = towerDef.range * rangeFactor,
        projectileSpeed = towerDef.projectileSpeed,
        behavior = towerDef.behavior,
        blastRadius = towerDef.blastRadius,
        chainRange = towerDef.chainRange,
        chainHops = towerDef.chainHops,
        chainFactor = towerDef.chainFactor,
        slowRatio = towerDef.slowRatio,
        slowTicks = towerDef.slowTicks,
        factors = {
            patchDamage = 1 + patchDamage,
            patchRate = 1 + patchRate,
            patchRange = 1 + patchRange,
            moduleDamage = 1 + moduleDamage,
            moduleRate = 1 + moduleRate,
            moduleRange = 1 + moduleRange,
        },
        conditions = conditions,
    }
end

function Rules.conditionalDamageMultiplier(run, enemy, tick)
    local bonus = 0
    if hasModule(run, "M17") and enemy and enemy.slowUntilTick and tick <= enemy.slowUntilTick then
        bonus = bonus + 0.30
    end
    if hasModule(run, "M18") and recentHitTypeCount(enemy, tick) >= 2 then
        bonus = bonus + 0.25
    end
    return math.max(0.1, 1 + bonus)
end

function Rules.tryPurchaseTower(defs, run, typeId)
    local towerDef = defs.towersById[typeId]
    if not towerDef then return nil, nil, "unknown_tower_type" end
    local towerIds = run.frozenUnlockPool and run.frozenUnlockPool.towerIds or {}
    local inPool = false
    for _, unlockedTypeId in ipairs(towerIds) do
        if unlockedTypeId == typeId then inPool = true break end
    end
    if not inPool then return nil, nil, "tower_not_in_run_pool" end
    if run.gold < towerDef.price then return nil, nil, "insufficient_gold" end
    local candidate = copy(run)
    candidate.gold = candidate.gold - towerDef.price
    local instanceId = candidate.nextInstanceId
    candidate.nextInstanceId = instanceId + 1
    candidate.towerInstances[#candidate.towerInstances + 1] = {
        instanceId = instanceId, typeId = typeId, paidGold = towerDef.price,
        patchIds = {}, placement = nil, charge = 0, activated = false,
    }
    return candidate, { { type = "tower_purchased", instanceId = instanceId, typeId = typeId, gold = towerDef.price } }, nil
end

function Rules.tryPurchasePatch(defs, run, instanceId, patchId)
    local tower = findTower(run, instanceId)
    local patch = defs.patchesById[patchId]
    if not tower then return nil, nil, "unknown_tower" end
    if not patch then return nil, nil, "unknown_patch" end
    if #(tower.patchIds or {}) >= 3 then return nil, nil, "patch_limit" end
    if run.gold < patch.price then return nil, nil, "insufficient_gold" end
    local candidate = copy(run)
    candidate.gold = candidate.gold - patch.price
    local target = assert(findTower(candidate, instanceId))
    target.patchIds[#target.patchIds + 1] = patchId
    local refundGold = 0
    local useCount
    if hasModule(candidate, "M29") and candidate.shopState
        and (candidate.shopState.refundUseCount or 0) < 2 then
        candidate.shopState.refundUseCount = (candidate.shopState.refundUseCount or 0) + 1
        useCount = candidate.shopState.refundUseCount
        refundGold = 1
        candidate.gold = candidate.gold + refundGold
    end
    local events = { {
        type = "patch_purchased", instanceId = instanceId, patchId = patchId,
        gold = patch.price, paidGold = patch.price, refundGold = refundGold,
        netGold = patch.price - refundGold,
    } }
    if refundGold > 0 then
        events[#events + 1] = {
            type = "module_refund_applied", moduleId = "M29",
            visitId = candidate.shopState.visitId, useCount = useCount,
            refundGold = refundGold,
        }
    end
    local growthEvent = applyModuleGrowth(defs, candidate, "M34", "patch_purchased")
    if growthEvent then events[#events + 1] = growthEvent end
    return candidate, events, nil
end

local function buildModulePurchaseProposal(defs, run, moduleId)
    local moduleDef = defs.modulesById[moduleId]
    if not moduleDef then return nil, nil, "unknown_module" end
    if moduleId == "M12" or moduleId == "M14" or moduleId == "M15" or moduleId == "M16" or moduleId == "M31" or moduleId == "M28" or moduleId == "M41" or moduleId == "M42" or moduleId == "M43" or moduleId == "M46" then
        local pooled = false
        for _, id in ipairs(run.frozenUnlockPool and run.frozenUnlockPool.moduleIds or {}) do
            if id == moduleId then pooled = true end
        end
        if not pooled then return nil, nil, "module_not_in_frozen_pool" end
    end
    if hasModule(run, moduleId) or (run.acquiredModuleIds or {})[moduleId] then
        return nil, nil, "duplicate_module"
    end
    if #(run.modules or {}) >= Rules.moduleCapacity(run) then return nil, nil, "module_slots" end
    if run.gold < moduleDef.price then return nil, nil, "insufficient_gold" end
    local candidate = copy(run)
    candidate.gold = candidate.gold - moduleDef.price
    candidate.modules = candidate.modules or {}
    candidate.modules[#candidate.modules + 1] = { moduleId = moduleId, paidGold = moduleDef.price, growth = 0 }
    candidate.acquiredModuleIds = candidate.acquiredModuleIds or {}
    candidate.acquiredModuleIds[moduleId] = true
    return candidate, moduleDef, nil
end

function Rules.previewModulePurchase(defs, run, moduleId)
    local proposed, moduleDef, reason = buildModulePurchaseProposal(defs, run, moduleId)
    if not proposed then return nil, reason end
    local decision, capacityReason = Rules.evaluateCapacityTransition(run, proposed, nil)
    if not decision then return nil, capacityReason end
    decision.moduleId = moduleId
    decision.paidGold = moduleDef.price
    decision.goldBefore = run.gold
    decision.goldAfter = proposed.gold
    decision.spareCircuitBefore = Rules.projectModuleStatus(defs, run, "M43")
    decision.spareCircuitAfter = Rules.projectModuleStatus(defs, proposed, "M43")
    decision.emergencyBefore = Rules.projectModuleStatus(defs, run, "M46")
    decision.emergencyAfter = Rules.projectModuleStatus(defs, proposed, "M46")
    decision.midLinkBefore = Rules.projectModuleStatus(defs, run, "M41")
    decision.midLinkAfter = Rules.projectModuleStatus(defs, proposed, "M41")
    decision.assetLinkBefore = Rules.projectModuleStatus(defs, run, "M42")
    decision.assetLinkAfter = Rules.projectModuleStatus(defs, proposed, "M42")
    decision.depositBefore = Rules.projectModuleStatus(defs, run, "M28")
    decision.depositAfter = Rules.projectModuleStatus(defs, proposed, "M28")
    decision.sharedBefore = Rules.projectModuleStatus(defs, run, "M16")
    decision.sharedAfter = Rules.projectModuleStatus(defs, proposed, "M16")
    decision.reserveBefore = Rules.projectModuleStatus(defs, run, "M31")
    decision.reserveAfter = Rules.projectModuleStatus(defs, proposed, "M31")
    decision.canCommit = decision.requiredRecallCount == 0
    return decision, nil
end

function Rules.tryPurchaseModule(defs, run, moduleId, recallTowerIds)
    local proposed, moduleDef, reason = buildModulePurchaseProposal(defs, run, moduleId)
    if not proposed then return nil, nil, reason end
    local decision, capacityReason = Rules.evaluateCapacityTransition(run, proposed, recallTowerIds or {})
    if not decision then return nil, nil, capacityReason end
    local events = {}
    for _, instanceId in ipairs(decision.selectedRecallTowerIds) do
        assert(findTower(proposed, instanceId)).placement = nil
        events[#events + 1] = {
            type = "tower_recalled", instanceId = instanceId, reason = "capacity_adjustment",
        }
    end
    events[#events + 1] = {
        type = "module_purchased", moduleId = moduleId,
        gold = moduleDef.price, paidGold = moduleDef.price,
    }
    return proposed, events, nil
end

function Rules.previewReroll(run)
    if type(run) ~= "table" or type(run.shopState) ~= "table" then
        return nil, "shop_state_required"
    end
    local rerollCount = run.shopState.rerollCount
    if type(rerollCount) ~= "number" or rerollCount < 0 or rerollCount % 1 ~= 0 then
        return nil, "invalid_reroll_count"
    end
    local nominalGold = 2 + 2 * rerollCount
    local discountGold = hasModule(run, "M30") and not run.shopState.firstRerollDone
        and math.min(2, nominalGold) or 0
    local paidGold = nominalGold - discountGold
    return {
        visitId = run.shopState.visitId,
        rerollCountBefore = rerollCount,
        rerollCountAfter = rerollCount + 1,
        firstRerollDone = run.shopState.firstRerollDone == true,
        nominalGold = nominalGold,
        discountGold = discountGold,
        paidGold = paidGold,
        goldBefore = run.gold,
        goldAfter = run.gold - paidGold,
        canCommit = run.gold >= paidGold,
    }, nil
end

function Rules.tryApplyReroll(defs, run, nextShopState)
    local receipt, reason = Rules.previewReroll(run)
    if not receipt then return nil, nil, reason end
    if not receipt.canCommit then return nil, nil, "insufficient_gold" end
    if type(nextShopState) ~= "table"
        or nextShopState.visitId ~= run.shopState.visitId
        or nextShopState.rerollCount ~= run.shopState.rerollCount + 1
        or nextShopState.firstRerollDone ~= true then
        return nil, nil, "invalid_next_shop_state"
    end
    local candidate = copy(run)
    candidate.gold = candidate.gold - receipt.paidGold
    candidate.shopState = copy(nextShopState)
    local events = {
        {
            type = "reroll_paid", visitId = receipt.visitId,
            nominalGold = receipt.nominalGold, discountGold = receipt.discountGold,
            paidGold = receipt.paidGold,
        },
        {
            type = "shop_rerolled", visitId = receipt.visitId,
            rerollCount = nextShopState.rerollCount,
        },
    }
    local growthEvent = applyModuleGrowth(defs, candidate, "M33", "shop_rerolled")
    if growthEvent then events[#events + 1] = growthEvent end
    return candidate, events, nil
end

function Rules.projectModuleStatus(defs, run, moduleId, context)
    local moduleDef = defs.modulesById and defs.modulesById[moduleId]
    if not moduleDef then return nil, "unknown_module" end
    context = context or {}
    local installed = hasModule(run, moduleId)
    local growth = moduleGrowth(run, moduleId)
    local status = {
        moduleId = moduleId,
        installed = installed,
        active = false,
        bonusKind = "none",
        bonusPercentPoints = 0,
        growth = growth,
        cap = moduleDef.growthCap or 0,
        conditionCode = "passive",
        nextReset = (moduleDef.growthCap and "sale_or_new_run" or "none"),
        saleLosesGrowth = moduleDef.growthCap ~= nil,
    }
    local tower = context.tower
    if not tower and context.towerInstanceId then tower = findTower(run, context.towerInstanceId) end
    local deployed = tower and tower.placement ~= nil
    local distinctTypes = placedTypeCount(run)

    if moduleId == "M03" then
        status.bonusKind, status.conditionCode = "damage", "distinct_placed_types"
        status.distinctPlacedTypeCount = distinctTypes
        status.bonusPercentPoints = 5 * distinctTypes
        status.active = installed and deployed and distinctTypes > 0
    elseif moduleId == "M04" then
        status.bonusKind, status.conditionCode = "attack_rate", "exactly_one_placed_type"
        status.distinctPlacedTypeCount = distinctTypes
        status.bonusPercentPoints = 35
        status.active = installed and deployed and distinctTypes == 1
    elseif moduleId == "M06" then
        status.bonusKind, status.conditionCode = "damage_and_capacity", "deployed_tower"
        status.bonusPercentPoints = 35
        status.towerCapacity = Rules.towerCapacity(run)
        status.active = installed and deployed
    elseif moduleId == "M07" then
        local qualifyingIds, placedCount = qualifyingPlacedTowerIds(run, function(item)
            return #sameTypeCardinalNeighborIds(run, item) > 0
        end)
        local selectedNeighborIds = sameTypeCardinalNeighborIds(run, tower)
        status.bonusKind, status.conditionCode = "attack_rate", "cardinal_same_type_neighbor"
        status.placedTowerCount = placedCount
        status.qualifyingTowerCount = #qualifyingIds
        status.qualifyingTowerIds = qualifyingIds
        status.selectedTowerId = tower and tower.instanceId or nil
        status.selectedTowerQualifies = tower ~= nil and #selectedNeighborIds > 0 or false
        status.sameTypeCardinalNeighborCount = #selectedNeighborIds
        status.sameTypeCardinalNeighborIds = selectedNeighborIds
        status.bonusPercentPoints = 20
        status.active = installed and status.selectedTowerQualifies
    elseif moduleId == "M08" then
        status.bonusKind, status.conditionCode = "attack_rate", "exactly_two_placed_types"
        status.distinctPlacedTypeCount = distinctTypes
        status.bonusPercentPoints = 25
        status.active = installed and deployed and distinctTypes == 2
    elseif moduleId == "M09" then
        local patchCount = tower and #(tower.patchIds or {}) or 0
        local qualifyingIds, placedCount = qualifyingPlacedTowerIds(run, function(item)
            return #(item.patchIds or {}) == 3
        end)
        status.bonusKind, status.conditionCode = "damage", "exactly_three_patches"
        status.placedTowerCount = placedCount
        status.qualifyingTowerCount = #qualifyingIds
        status.qualifyingTowerIds = qualifyingIds
        status.selectedTowerId = tower and tower.instanceId or nil
        status.selectedTowerQualifies = tower ~= nil and patchCount == 3 or false
        status.patchCount = patchCount
        status.bonusPercentPoints = 30
        status.active = installed and status.selectedTowerQualifies
    elseif moduleId == "M10" then
        local patchCount = tower and #(tower.patchIds or {}) or 0
        local qualifyingIds, placedCount = qualifyingPlacedTowerIds(run, function(item)
            return #(item.patchIds or {}) == 0
        end)
        status.bonusKind, status.conditionCode = "attack_rate", "zero_patches"
        status.placedTowerCount = placedCount
        status.qualifyingTowerCount = #qualifyingIds
        status.qualifyingTowerIds = qualifyingIds
        status.selectedTowerId = tower and tower.instanceId or nil
        status.selectedTowerQualifies = tower ~= nil and patchCount == 0 or false
        status.patchCount = patchCount
        status.bonusPercentPoints = 25
        status.active = installed and status.selectedTowerQualifies
    elseif moduleId == "M11" then
        local sharingByTower, qualifyingIds = {}, {}
        local placed = placedTowers(run)
        for _, item in ipairs(placed) do
            local detail = sharedPatchDetail(run, item)
            if #detail.sharedPatchIds > 0 then
                qualifyingIds[#qualifyingIds + 1] = item.instanceId
                sharingByTower[#sharingByTower + 1] = {
                    instanceId = item.instanceId,
                    sharedPatchIds = detail.sharedPatchIds,
                    counterpartInstanceIds = detail.counterpartInstanceIds,
                    matches = detail.matches,
                }
            end
        end
        local selectedDetail = sharedPatchDetail(run, tower)
        status.bonusKind, status.conditionCode = "damage", "shared_patch_with_placed_tower"
        status.placedTowerCount = #placed
        status.qualifyingTowerCount = #qualifyingIds
        status.qualifyingTowerIds = qualifyingIds
        status.sharingByTower = sharingByTower
        status.selectedTowerId = tower and tower.instanceId or nil
        status.selectedTowerQualifies = tower ~= nil and #selectedDetail.sharedPatchIds > 0 or false
        status.sharedPatchCount = #selectedDetail.sharedPatchIds
        status.sharedPatchIds = selectedDetail.sharedPatchIds
        status.sharedWithTowerIds = selectedDetail.counterpartInstanceIds
        status.sharedMatches = selectedDetail.matches
        status.bonusPercentPoints = 20
        status.active = installed and status.selectedTowerQualifies
    elseif moduleId == "M13" then
        local patchCount = tower and #(tower.patchIds or {}) or 0
        local lead = patchLeadSummary(run)
        local qualifyingIds = lead.soleHighestTowerId and { lead.soleHighestTowerId } or {}
        status.bonusKind, status.conditionCode = "damage", "strict_patch_count_lead"
        status.placedTowerCount = lead.placedTowerCount
        status.qualifyingTowerCount = #qualifyingIds
        status.qualifyingTowerIds = qualifyingIds
        status.highestPatchCount = lead.highestPatchCount
        status.highestPatchTowerIds = lead.highestPatchTowerIds
        status.soleHighestTowerId = lead.soleHighestTowerId
        status.soleHighestPatchCount = lead.soleHighestTowerId and lead.highestPatchCount or nil
        status.patchLeadState = lead.state
        status.selectedTowerId = tower and tower.instanceId or nil
        status.selectedTowerQualifies = tower ~= nil
            and tower.instanceId == lead.soleHighestTowerId or false
        status.patchCount = patchCount
        status.bonusPercentPoints = 40
        status.active = installed and status.selectedTowerQualifies
    elseif moduleId == "M18" then
        local qualified, activeCount = 0, 0
        for _, enemy in ipairs(context.enemies or {}) do
            if enemy.alive ~= false then
                activeCount = activeCount + 1
                if recentHitTypeCount(enemy, context.tick or 0) >= 2 then qualified = qualified + 1 end
            end
        end
        status.active = nil
        status.bonusKind, status.conditionCode = "conditional_damage", "per_enemy_hit_history"
        status.bonusPercentPoints = 25
        status.qualifiedEnemyCount = qualified
        status.activeEnemyCount = activeCount
    elseif moduleId == "M31" then
        local observation, reason = Rules.reserveComposition(defs, run)
        status.bonusKind, status.conditionCode, status.cap = "settlement_gold", "distinct_unplaced_tower_types", 3
        status.observationError = reason
        status.reserveTypeIds = observation and copy(observation.typeIds) or nil
        status.reserveTypeCount = observation and observation.count or nil
        status.ordinarySettlement = (run.nextWaveIndex or 1) <= 14 and run.phase ~= "RESULT" and run.hp > 0
        status.estimatedGold = installed and status.ordinarySettlement and observation and math.min(3, observation.count) or 0
        status.active = status.estimatedGold > 0
    elseif moduleId == "M28" then
        status.bonusKind, status.conditionCode = "settlement_gold", "pre_reward_gold_per_five"
        status.preRewardGold, status.goldPerInterest, status.cap = run.gold, 5, 4
        status.ordinarySettlement = (run.nextWaveIndex or 1) <= 14 and run.phase ~= "RESULT" and run.hp > 0
        status.estimatedGold = installed and status.ordinarySettlement and math.min(4, math.floor(run.gold / 5)) or 0
        status.active = status.estimatedGold > 0
    elseif moduleId == "M41" then
        status.bonusKind, status.conditionCode = "damage", "other_installed_mid_modules"
        status.otherMidModuleIds = midModuleIds(defs, run, "M41")
        status.otherMidModuleCount = #status.otherMidModuleIds
        status.bonusPercentPoints, status.cap = midLinkBonus(defs, run), 32
        status.placedTowerCount = countPlaced(run)
        status.active = installed and status.otherMidModuleCount > 0 and status.placedTowerCount > 0
        status.selectedTowerQualifies = deployed == true and installed and status.otherMidModuleCount > 0
    elseif moduleId == "M12" then
        local observation, reason = Rules.balancedPatchComposition(defs, run)
        local detail = observation and tower and observation.towerDetails[tower.instanceId]
        status.bonusKind, status.conditionCode, status.cap = "range", "all_deployed_equal_positive_patch_count", 25
        status.observationError = reason
        status.placedTowerCount = observation and observation.placedTowerCount or 0
        status.commonPatchCount = observation and observation.commonPatchCount or nil
        status.allPlacedPositiveAndEqual = observation and observation.allPlacedPositiveAndEqual or false
        status.active = installed and observation ~= nil and observation.effectQualifies
        status.selectedTowerInstanceId = tower and tower.instanceId or nil
        status.selectedTowerPlaced = detail and detail.placed or false
        status.selectedPatchCount = detail and detail.patchCount or nil
        status.selectedTowerQualifies = status.active and detail ~= nil and detail.placed
        status.bonusPercentPoints = status.selectedTowerQualifies and 25 or 0
        local stats = detail and Rules.projectStats(defs, run, tower.instanceId)
        status.selectedRange = stats and stats.range or nil
    elseif moduleId == "M16" then
        local observation, reason = Rules.sharedPatchComposition(defs, run)
        local detail = observation and tower and observation.towerDetails[tower.instanceId]
        status.bonusKind, status.conditionCode, status.cap = "damage", "distinct_deployed_patch_ids", 27
        status.observationError = reason
        status.distinctPatchIds = observation and copy(observation.distinctPatchIds) or nil
        status.distinctPatchCount = observation and observation.distinctPatchCount or nil
        status.placedTowerCount = observation and observation.placedTowerCount or nil
        status.potentialBonusPercentPoints = observation and math.min(27, 3 * observation.distinctPatchCount) or 0
        status.active = installed and observation ~= nil and observation.distinctPatchCount > 0
        status.aggregateBonusPercentPoints = status.active and status.potentialBonusPercentPoints or 0
        status.selectedTowerInstanceId = tower and tower.instanceId or nil
        status.selectedTowerPlaced = detail and detail.placed or false
        status.selectedTowerQualifies = status.active and detail ~= nil and detail.placed
        status.bonusPercentPoints = status.selectedTowerQualifies and status.aggregateBonusPercentPoints or 0
        local stats = detail and Rules.projectStats(defs, run, tower.instanceId)
        status.selectedDamage = stats and stats.damage or nil
    elseif moduleId == "M14" then
        local observation, reason = Rules.patchInvestmentComposition(defs, run)
        local detail = observation and tower and observation.towerDetails[tower.instanceId]
        status.bonusKind, status.conditionCode, status.cap = "damage", "placed_high_grade_patch_count", 24
        status.observationError = reason
        status.qualifyingTowerIds = {}
        status.placedTowerCount = 0
        if observation then
            for id, item in pairs(observation.towerDetails) do
                if item.placed then status.placedTowerCount = status.placedTowerCount + 1 end
                if item.placed and item.highGradePatchCount > 0 then status.qualifyingTowerIds[#status.qualifyingTowerIds + 1] = id end
            end
            table.sort(status.qualifyingTowerIds)
        end
        status.qualifyingTowerCount = #status.qualifyingTowerIds
        status.selectedTowerInstanceId = tower and tower.instanceId or nil
        status.selectedHighGradePatchCount = detail and detail.highGradePatchCount or 0
        status.selectedNominalPatchPrice = detail and detail.nominalPatchPrice or nil
        status.selectedTowerPlaced = detail and detail.placed or false
        status.selectedTowerQualifies = installed and detail ~= nil and detail.placed and detail.highGradePatchCount > 0 or false
        status.bonusPercentPoints = status.selectedTowerQualifies and detail.highGradePatchCount * 8 or 0
        status.active = installed and status.qualifyingTowerCount > 0
        local stats = detail and Rules.projectStats(defs, run, tower.instanceId)
        status.selectedDamage = stats and stats.damage or nil
    elseif moduleId == "M15" then
        local observation, reason = Rules.mixedPatchComposition(defs, run)
        local detail = observation and tower and observation.towerDetails[tower.instanceId]
        status.bonusKind, status.conditionCode, status.cap = "attack_rate", "placed_three_distinct_patch_ids", 20
        status.observationError = reason
        status.qualifyingTowerIds = observation and copy(observation.qualifyingTowerIds) or {}
        status.qualifyingTowerCount = observation and observation.qualifyingTowerCount or 0
        status.placedTowerCount = countPlaced(run)
        status.selectedTowerInstanceId = tower and tower.instanceId or nil
        status.selectedDistinctPatchCount = detail and detail.distinctPatchCount or 0
        status.selectedTowerPlaced = detail and detail.placed or false
        status.selectedTowerQualifies = installed and detail ~= nil and detail.qualifies or false
        status.bonusPercentPoints = status.selectedTowerQualifies and 20 or 0
        status.active = installed and status.qualifyingTowerCount > 0
        local stats = detail and Rules.projectStats(defs, run, tower.instanceId)
        status.selectedAttackRate = stats and stats.attackRate or nil
    elseif moduleId == "M42" then
        local value, reason = Rules.modulePurchaseValue(defs, run, "M42")
        status.bonusKind, status.conditionCode = "damage", "other_installed_recorded_paid_gold"
        status.otherModulePaidGold = value and value.paidGoldTotal or nil
        status.observationError = reason
        status.bonusPercentPoints, status.cap = assetLinkBonus(defs, run), 30
        status.placedTowerCount = countPlaced(run)
        status.active = installed and value ~= nil and status.bonusPercentPoints > 0 and status.placedTowerCount > 0
        status.selectedTowerQualifies = deployed == true and status.active
    elseif moduleId == "M43" then
        for key, value in pairs(Rules.moduleSlots(run)) do status[key] = value end
        status.bonusKind, status.conditionCode = "damage", "empty_module_slots"
        status.bonusPercentPoints, status.cap = spareCircuitBonus(run), 36
        status.active = installed and status.emptySlots > 0
        status.selectedTowerQualifies = deployed == true
    elseif moduleId == "M46" then
        status.bonusKind, status.conditionCode = "damage", "current_hp_one_to_five"
        status.currentHp, status.minimumHp, status.maximumHp = run.hp, 1, 5
        status.hpQualifies = run.hp >= 1 and run.hp <= 5
        status.placedTowerCount = countPlaced(run)
        status.active = installed and status.hpQualifies and status.placedTowerCount > 0
        status.bonusPercentPoints = status.active and 40 or 0
        status.selectedTowerQualifies = deployed == true and status.hpQualifies
    elseif moduleId == "M29" then
        local useCount = run.shopState and (run.shopState.refundUseCount or 0) or 0
        local remaining = math.max(0, 2 - useCount)
        local patch = context.patchId and defs.patchesById[context.patchId] or nil
        local paid = patch and patch.price or context.patchPrice
        local refund = installed and remaining > 0 and paid and paid > 0 and 1 or 0
        status.bonusKind, status.conditionCode = "gold_refund", "first_two_patch_purchases_per_visit"
        status.refundUseCount, status.refundRemaining = useCount, remaining
        status.nextPatchPaidGold, status.nextPatchRefundGold = paid, refund
        status.nextPatchNetGold = paid and (paid - refund) or nil
        status.active = installed and remaining > 0
    elseif moduleId == "M30" then
        status.bonusKind, status.conditionCode = "reroll_discount", "first_successful_reroll_per_visit"
        if run.shopState then
            local receipt = assert(Rules.previewReroll(run))
            status.firstRerollDone = run.shopState.firstRerollDone == true
            status.nominalGold = receipt.nominalGold
            status.discountGold = receipt.discountGold
            status.paidGold = receipt.paidGold
            status.active = installed and not status.firstRerollDone
        end
    elseif moduleId == "M32" then
        local placed = countPlaced(run)
        local capacity = Rules.towerCapacity(run)
        local empty = math.max(0, capacity - placed)
        status.bonusKind, status.conditionCode = "settlement_gold", "empty_placed_capacity"
        status.towerCapacity, status.placedTowerCount, status.emptySlots = capacity, placed, empty
        status.estimatedGold = installed and math.min(3, empty) or 0
        status.active = installed and empty > 0
    elseif moduleId == "M33" or moduleId == "M34" or moduleId == "M37" then
        local causes = { M33 = "successful_reroll", M34 = "successful_patch_purchase", M37 = "ordinary_wave_complete" }
        status.bonusKind, status.conditionCode = "damage_growth", causes[moduleId]
        status.bonusPercentPoints = growth
        status.nextGrowth = math.min(moduleDef.growthCap or 0, growth + (moduleDef.growthStep or 0))
        status.active = installed and deployed and growth > 0
    elseif moduleId == "M44" then
        status.bonusKind, status.conditionCode = "damage", "gold_at_least_20"
        status.currentGold, status.threshold = run.gold, 20
        status.bonusPercentPoints = 25
        status.active = installed and deployed and run.gold >= 20
    elseif moduleId == "M45" then
        status.bonusKind, status.conditionCode = "attack_rate", "gold_at_most_3"
        status.currentGold, status.threshold = run.gold, 3
        status.bonusPercentPoints = 25
        status.active = installed and deployed and run.gold <= 3
    else
        status.active = installed
    end
    return status, nil
end

function Rules.previewSettlement(defs, run, waveIndex, leaks)
    local base = 6
    local flawless = leaks == 0 and 3 or 0
    local section = (waveIndex == 3 or waveIndex == 6 or waveIndex == 9 or waveIndex == 12) and 6 or 0
    local preRewardGold = run.gold
    local moduleById = { M25 = 0, M26 = 0, M28 = 0, M31 = 0, M32 = 0 }
    if hasModule(run, "M25") then moduleById.M25 = 2 end
    if hasModule(run, "M26") and leaks == 0 then moduleById.M26 = 2 end
    if hasModule(run, "M28") and waveIndex >= 1 and waveIndex <= 14 and run.hp > 0 then
        moduleById.M28 = math.min(4, math.floor(preRewardGold / 5))
    end
    local reserve = defs and Rules.reserveComposition(defs, run)
    if hasModule(run, "M31") and waveIndex >= 1 and waveIndex <= 14 and run.hp > 0 then
        -- completionReward's historical no-definitions wrapper still counts valid
        -- domain towers; production settlement supplies definitions for validation.
        local types = {}
        if not defs then for _, tower in ipairs(run.towerInstances or {}) do if not tower.placement then types[tower.typeId] = true end end end
        local count = reserve and reserve.count or 0
        if not defs then for _ in pairs(types) do count = count + 1 end end
        moduleById.M31 = math.min(3, count)
    end
    local placedTowerCount = countPlaced(run)
    local towerCapacity = Rules.towerCapacity(run)
    local emptyTowerSlots = math.max(0, towerCapacity - placedTowerCount)
    if hasModule(run, "M32") then moduleById.M32 = math.min(3, emptyTowerSlots) end
    local moduleIncome = moduleById.M25 + moduleById.M26 + moduleById.M28 + moduleById.M31 + moduleById.M32
    return {
        base = base,
        flawless = flawless,
        section = section,
        modules = moduleIncome,
        total = base + flawless + section + moduleIncome,
        moduleById = moduleById,
        preRewardGold = preRewardGold,
        reserveTypeCount = reserve and reserve.count or nil,
        towerCapacity = towerCapacity,
        placedTowerCount = placedTowerCount,
        emptyTowerSlots = emptyTowerSlots,
    }
end

function Rules.completionReward(run, waveIndex, leaks)
    return Rules.previewSettlement(nil, run, waveIndex, leaks)
end

function Rules.reduceCompletion(defs, run, summary)
    local candidate = copy(run)
    candidate.hp = summary.hp
    candidate.towerInstances = copy(summary.towerInstances or candidate.towerInstances)
    local events = {}
    if summary.resultKind == "defeat" or summary.resultKind == "victory" then
        candidate.result = {
            kind = summary.resultKind,
            waveId = summary.waveId,
            tick = summary.tick,
            reason = summary.resultReason,
        }
        events[#events + 1] = {
            type = summary.resultKind == "victory" and "run_victory" or "battle_defeated",
            waveId = summary.waveId,
            tick = summary.tick,
            reason = summary.resultReason,
        }
        return candidate, events, nil
    end
    if summary.resultKind ~= "wave_complete" then
        return nil, nil, "battle_not_complete"
    end
    if not summary.hp or summary.hp <= 0 then return nil, nil, "battle_not_survived" end
    if candidate.completedWaveIds[summary.waveId] then
        events[#events + 1] = { type = "completion_duplicate", waveId = summary.waveId }
        return candidate, events, nil
    end
    local wave = defs.wavesById[summary.waveId]
    if not wave then return nil, nil, "unknown_wave" end
    if wave.bossRequired then return nil, nil, "boss_result_required" end
    local reward = Rules.previewSettlement(defs, candidate, wave.index, summary.leaks or 0)
    candidate.gold = candidate.gold + reward.total
    candidate.completedWaveIds[summary.waveId] = true
    candidate.nextWaveIndex = math.max(candidate.nextWaveIndex or 1, wave.index + 1)
    events[#events + 1] = { type = "wave_reward", waveId = summary.waveId, reward = reward }
    local growthEvent = applyModuleGrowth(defs, candidate, "M37", "wave_complete")
    if growthEvent then events[#events + 1] = growthEvent end
    return candidate, events, nil
end

function Rules.reduceTowerUnlocks(metaState, beforeRun, candidateRun, summary, completionEvents)
    local meta = copy(metaState)
    local unlockEvents = {}
    local towerId
    if summary and summary.hp and summary.hp > 0 then
        if summary.resultKind == "wave_complete" and summary.waveId == "W05"
            and not (beforeRun.completedWaveIds or {}).W05
            and (candidateRun.completedWaveIds or {}).W05
            and (candidateRun.nextWaveIndex or 0) >= 6 then
            for _, event in ipairs(completionEvents or {}) do
                if event.type == "wave_reward" and event.waveId == "W05" then
                    towerId = "T05"
                    break
                end
            end
        elseif summary.resultKind == "victory" and summary.waveId == "W15"
            and summary.resultReason == "boss_killed"
            and not beforeRun.result
            and candidateRun.result and candidateRun.result.kind == "victory"
            and candidateRun.result.waveId == "W15"
            and candidateRun.result.reason == "boss_killed" then
            for _, event in ipairs(completionEvents or {}) do
                if event.type == "run_victory" and event.waveId == "W15"
                    and event.reason == "boss_killed" then
                    towerId = "T06"
                    break
                end
            end
        end
    end
    if towerId then
        meta.unlockedTowerIds = meta.unlockedTowerIds or {}
        for _, id in ipairs(meta.unlockedTowerIds) do
            if id == towerId then return meta, unlockEvents end
        end
        meta.unlockedTowerIds[#meta.unlockedTowerIds + 1] = towerId
        table.sort(meta.unlockedTowerIds)
        unlockEvents[1] = { type = "tower_unlocked", towerId = towerId, waveId = summary.waveId }
    end
    return meta, unlockEvents
end

function Rules.reduceModuleUnlocks(defs, metaState, beforeRun, candidateRun, summary, completionEvents)
    local meta, unlockEvents = copy(metaState), {}
    meta.unlockedModuleIds = meta.unlockedModuleIds or {}
    local wave = summary and defs.wavesById[summary.waveId]
    if not wave or wave.bossRequired or wave.index < 3 or wave.index > 14
        or summary.resultKind ~= "wave_complete" or not summary.hp or summary.hp <= 0
        or (beforeRun.completedWaveIds or {})[wave.id]
        or not (candidateRun.completedWaveIds or {})[wave.id]
        or (candidateRun.nextWaveIndex or 0) < wave.index + 1 then return meta, unlockEvents end
    local reward
    for _, event in ipairs(completionEvents or {}) do
        if event.type == "wave_reward" and event.waveId == wave.id and event.reward then
            reward = event.reward
            break
        end
    end
    if not reward then return meta, unlockEvents end
    local unlocked = {}
    for _, id in ipairs(meta.unlockedModuleIds) do unlocked[id] = true end
    local function unlock(id, qualified)
        if qualified and not unlocked[id] then
            meta.unlockedModuleIds[#meta.unlockedModuleIds + 1] = id
            unlockEvents[#unlockEvents + 1] = { type = "module_unlocked", moduleId = id, waveId = wave.id }
        end
    end
    unlock("M28", beforeRun.gold >= 20 and reward.preRewardGold == beforeRun.gold)
    unlock("M41", wave.index >= 6 and Rules.midModuleComposition(defs, beforeRun).qualifies)
    -- COMBAT's allowed writers never change modules/baseModuleSlots. The committed
    -- combatStart snapshot therefore proves these counts throughout the wave.
    local slots = Rules.moduleSlots(beforeRun)
    unlock("M43", slots.installedModuleCount >= 1 and slots.emptySlots >= 2)
    unlock("M46", (beforeRun.hp >= 1 and beforeRun.hp <= 5 and summary.leaks == 0)
        or (wave.index >= 9 and summary.hp == 20))
    local assets = Rules.modulePurchaseValue(defs, beforeRun)
    unlock("M42", wave.index >= 9 and assets ~= nil and assets.paidGoldTotal >= 40)
    local mixedProof = wave.index >= 6 and Rules.mixedPatchStartProof(defs, beforeRun, candidateRun, summary)
    unlock("M15", mixedProof ~= nil and mixedProof ~= false and mixedProof.qualifies)
    local investmentProof = wave.index >= 9 and Rules.patchInvestmentStartProof(defs, beforeRun, candidateRun, summary)
    unlock("M14", investmentProof ~= nil and investmentProof ~= false and investmentProof.qualifies)
    local balancedProof = wave.index >= 6 and Rules.balancedPatchStartProof(defs, beforeRun, candidateRun, summary)
    unlock("M12", balancedProof ~= nil and balancedProof ~= false and balancedProof.qualifies)
    local sharedProof = wave.index >= 9 and Rules.sharedPatchStartProof(defs, beforeRun, candidateRun, summary)
    unlock("M16", sharedProof ~= nil and sharedProof ~= false and sharedProof.qualifies)
    local reserveProof = wave.index >= 9 and Rules.reserveStartProof(defs, beforeRun, candidateRun, summary)
    unlock("M31", reserveProof ~= nil and reserveProof ~= false and reserveProof.qualifies)
    table.sort(meta.unlockedModuleIds)
    return meta, unlockEvents
end

return Rules
