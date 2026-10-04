package.path = "./src/?.lua;" .. package.path
io.stdout:setvbuf("no")

local Json = require("json")
local Rng = require("rng")
local Save = require("save")
local Session = require("session")
local Content = require("src.content")
local Rules = require("src.rules")
local Game = require("src.game")

local LIVE_DEFS = Content.create()
local RUN002_VERSION = "DR-RUN-002-r1"
local S24_VERSION = "DR-MOD-S24-r1"
local STARTING_TOWERS = Json.array({ "T01", "T02", "T03", "T04" })
local RUN002_MODULE_IDS = Json.array({ "M01", "M02", "M05", "M17", "M25", "M26" })

local function definitionIds(family)
    if family == "modules" then
        return Json.array(Game.defaultUnlockPool(LIVE_DEFS).moduleIds)
    end
    local ids = {}
    for _, definition in ipairs(LIVE_DEFS[family] or {}) do
        ids[#ids + 1] = definition.id
    end
    table.sort(ids)
    return Json.array(ids)
end

local tests = {}

local function test(name, body)
    tests[#tests + 1] = { name = name, body = body }
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function truthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function contains(values, wanted)
    for _, value in ipairs(values) do if value == wanted then return true end end
    return false
end

local function MemoryStorage()
    local storage = {
        files = {},
        writeMode = nil,
        readErrors = {},
        writes = 0,
        writeAttempts = {},
    }
    function storage:read(path)
        if self.readErrors[path] then return nil, "injected read failure", "error" end
        if self.files[path] == nil then return nil, "not found", "missing" end
        return self.files[path]
    end
    function storage:write(path, data)
        self.writes = self.writes + 1
        self.writeAttempts[#self.writeAttempts + 1] = { path = path, data = data }
        if self.writeMode == "fail_before" then return nil, "injected write failure" end
        if self.writeMode == "fail_after" then
            self.files[path] = data
            return nil, "injected ambiguous write"
        end
        if self.writeMode == "corrupt" then
            self.files[path] = data:sub(1, math.max(1, #data - 3))
            return true
        end
        self.files[path] = data
        return true
    end
    return storage
end

local function checkpoint(phase, kind, marker)
    return {
        metaState = { unlockedTowerIds = Json.array({ "T01" }), marker = marker },
        checkpointKind = kind,
        runState = {
            runId = "run-1",
            phase = phase,
            nextWaveIndex = 1,
            gold = 12,
            rngState = { algorithm = "park-miller-v1", state = 17 },
        },
        resumeDescriptor = { kind = kind },
        transactionIdentity = marker and ("tx:" .. marker) or nil,
    }
end

local function newSave(storage)
    return Save.new({
        storage = storage,
        contentVersion = "slice-r2",
        engineTarget = "love-11.5",
        checksum = Save.adler32,
        checksumName = "adler32-v1-test-fixture",
    })
end

local function liveCheckpoint(phase, kind, marker)
    local run = Rules.newRun(LIVE_DEFS, { runId = "live-run" })
    run.phase = phase
    run.frozenUnlockPool = {
        towerIds = Json.decode(Json.encode(STARTING_TOWERS)),
        patchIds = definitionIds("patches"),
        moduleIds = definitionIds("modules"),
    }
    run.unlockRunProgress = Json.object()
    run.shopState = {
        visitId = "S00",
        fixtureIndex = 1,
        offers = { tower = "T02", patch = "P_DAMAGE", module = "M01" },
        soldOut = { tower = false, patch = false, module = false },
        rerollCount = 0,
        refundUseCount = 0,
        firstRerollDone = false,
        rngState = { algorithm = "park-miller-v1", state = 17 },
        accessOpen = phase == "SHOP" or phase == "PREPARE",
    }
    return {
        metaState = { unlockedTowerIds = { "T01", "T02", "T03", "T04" }, unlockedModuleIds = {} },
        checkpointKind = kind,
        runState = run,
        resumeDescriptor = { kind = kind, waveIndex = run.nextWaveIndex },
        transactionIdentity = marker and ("tx:" .. marker) or nil,
    }
end

local function currentW07Checkpoint(marker)
    local payload = liveCheckpoint("SHOP", "waveComplete", marker or "generation-34")
    local run = payload.runState
    run.nextWaveIndex = 7
    run.gold = 9
    run.hp = 17
    run.completedWaveIds = Json.object()
    for index = 1, 6 do run.completedWaveIds[string.format("W%02d", index)] = true end
    run.towerInstances[1].paidGold = 10
    run.towerInstances[1].patchIds = Json.array({ "P_DAMAGE" })
    run.towerInstances[1].charge = 0.5
    run.modules = Json.array({ { moduleId = "M01", paidGold = 8, growth = 0 } })
    run.acquiredModuleIds = { M01 = true }
    run.shopState.visitId = "S02"
    payload.metaState.unlockedModuleIds = Json.array({ "M01", "M05" })
    payload.metaState.unlockedTowerIds[#payload.metaState.unlockedTowerIds + 1] = "T05"
    payload.resumeDescriptor.waveIndex = 7
    return payload
end

local function run002W07Checkpoint(marker)
    local payload = currentW07Checkpoint(marker or "run002-generation-34")
    payload.runState.contentVersion = RUN002_VERSION
    payload.metaState.unlockedTowerIds = Json.decode(Json.encode(STARTING_TOWERS))
    payload.runState.frozenUnlockPool.moduleIds = Json.array({
        "M01", "M02", "M05", "M17", "M25", "M26",
    })
    return payload
end

local function withPlacedTowerCount(payload, wantedCount)
    local run = payload.runState
    run.modules[#run.modules + 1] = { moduleId = "M05", paidGold = 12, growth = 0 }
    run.acquiredModuleIds.M05 = true
    while #run.towerInstances < wantedCount do
        local instanceId = run.nextInstanceId
        run.towerInstances[#run.towerInstances + 1] = {
            instanceId = instanceId,
            typeId = "T01",
            paidGold = 4,
            patchIds = Json.array(),
            placement = nil,
            charge = 0,
            activated = false,
        }
        run.nextInstanceId = instanceId + 1
    end

    local map = assert(LIVE_DEFS.mapsById[run.mapId])
    for _, tower in ipairs(run.towerInstances) do
        if not tower.placement then
            local placed
            for y = 0, map.height - 1 do
                for x = 0, map.width - 1 do
                    local candidate = Rules.tryPlaceTower(LIVE_DEFS, run, run.mapId,
                        tower.instanceId, x, y, "prepare")
                    if candidate then
                        run = candidate
                        placed = true
                        break
                    end
                end
                if placed then break end
            end
            truthy(placed, "fixture must find a valid placement cell")
        end
    end
    payload.runState = run
    return payload
end

local function newRun002Save(storage, checksum, checksumName)
    return Save.new({
        storage = storage,
        contentVersion = LIVE_DEFS.version,
        engineTarget = "love-11.5",
        checksum = checksum or Save.adler32,
        checksumName = checksumName or "adler32-v1-test-fixture",
        validatePayload = Save.createLivePayloadValidator(LIVE_DEFS),
        migrations = Save.createRun002Migrations(LIVE_DEFS),
    })
end

local function newValidatedSave(storage)
    return newRun002Save(storage)
end

local function writeLiveEnvelope(storage, path, generation, payload)
    local payloadJson = Json.encode(payload)
    storage.files[path] = Json.encode({
        schemaVersion = 1,
        generation = generation,
        contentVersion = LIVE_DEFS.version,
        engineTarget = "love-11.5",
        checksumAlgorithm = "adler32-v1-test-fixture",
        payloadJson = payloadJson,
        payloadChecksum = Save.adler32(payloadJson),
    })
end

local function legacyCheckpoint(phase, nextWaveIndex)
    local payload = liveCheckpoint(phase, phase == "COMBAT" and "combatStart"
        or (phase == "RESULT" and "runResult" or "waveComplete"), "legacy")
    local run = payload.runState
    run.contentVersion = "DR-SLICE-001-r2"
    run.nextWaveIndex = nextWaveIndex
    run.hp = phase == "RESULT" and 0 or 17
    run.gold = 9
    run.completedWaveIds = Json.object()
    for index = 1, math.min(nextWaveIndex - 1, 3) do
        run.completedWaveIds[string.format("W%02d", index)] = true
    end
    run.modules = Json.array({ "M01" })
    run.acquiredModuleIds = { M01 = true }
    run.towerInstances[1].patchIds = Json.array({ "P_DAMAGE" })
    run.developmentComplete = nextWaveIndex == 4
    run.frozenUnlockPool = nil
    run.unlockRunProgress = nil
    run.result = nil
    run.shopState.visitId = nextWaveIndex == 4 and "S01" or "S00"
    run.shopState.soldOut = nil
    run.shopState.refundUseCount = nil
    run.shopState.rngState = nil
    run.shopState.accessOpen = nil
    payload.metaState.marker = "legacy-meta"
    payload.metaState.unlockedModuleIds = Json.array({ "M01" })
    payload.resumeDescriptor = { kind = payload.checkpointKind, waveIndex = nextWaveIndex }
    return payload
end

local function writeEnvelope(storage, path, generation, contentVersion, payload, checksum, checksumName)
    local payloadJson = Json.encode(payload)
    storage.files[path] = Json.encode({
        schemaVersion = 1,
        generation = generation,
        contentVersion = contentVersion,
        engineTarget = "love-11.5",
        checksumAlgorithm = checksumName,
        payloadJson = payloadJson,
        payloadChecksum = checksum(payloadJson),
    })
    return payloadJson
end

local function s24Checkpoint(marker)
    local payload = currentW07Checkpoint(marker)
    payload.runState.contentVersion = S24_VERSION
    payload.metaState.unlockedTowerIds = Json.decode(Json.encode(STARTING_TOWERS))
    payload.metaState.marker = marker
    return payload
end

local function bossResultCheckpoint(kind, hp, reason)
    local payload = s24Checkpoint("old-boss-result")
    local run = payload.runState
    run.phase, run.nextWaveIndex, run.hp = "RESULT", 15, hp
    for index = 1, 14 do run.completedWaveIds[string.format("W%02d", index)] = true end
    run.result = { kind = kind, waveId = "W15", tick = 800, reason = reason }
    run.shopState.accessOpen = false
    payload.checkpointKind = "runResult"
    payload.resumeDescriptor = { kind = "runResult", waveIndex = 15 }
    return payload
end

test("tower unlock validator rejects corrupt pools, offers, instances and recorded rights", function()
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    local mutations = {
        function(p) p.metaState.unlockedTowerIds = nil end,
        function(p) p.metaState.unlockedTowerIds[5] = "T01" end,
        function(p) p.metaState.unlockedTowerIds[5] = "T99" end,
        function(p) p.runState.frozenUnlockPool.towerIds[5] = "T05" end,
        function(p) p.runState.shopState.offers.tower = "T05" end,
        function(p) p.runState.towerInstances[1].typeId = "T06" end,
        function(p) p.runState.completedWaveIds.W05 = true; p.runState.nextWaveIndex = 6 end,
        function(p) p.runState.completedWaveIds.W15 = true end,
    }
    for index, mutate in ipairs(mutations) do
        local payload = liveCheckpoint("SHOP", "runStart", "tower-corrupt-" .. index)
        mutate(payload)
        equal(validator(payload), nil, "tower corruption case " .. index)
    end
    local valid = liveCheckpoint("SHOP", "runStart", "both-unlocked")
    valid.metaState.unlockedTowerIds = definitionIds("towers")
    valid.runState.frozenUnlockPool.towerIds = definitionIds("towers")
    valid.runState.shopState.offers.tower = "T06"
    valid.runState.towerInstances[1].typeId = "T05"
    truthy(validator(valid), "unlocked pool members may be offered and owned")
    local completed = currentW07Checkpoint("restored-right")
    truthy(validator(completed), "newly unlocked T05 stays outside the old frozen pool")
    completed.runState.nextWaveIndex = 5
    equal(validator(completed), nil, "completed W05 cannot precede W06 progress")
end)

test("tower validator binds victory to living W15 boss result and committed T06", function()
    local payload = bossResultCheckpoint("victory", 17, "boss_killed")
    payload.runState.contentVersion = LIVE_DEFS.version
    payload.metaState.unlockedTowerIds = definitionIds("towers")
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    truthy(validator(payload))
    for _, mutate in ipairs({
        function(p) p.runState.hp = 0 end,
        function(p) p.runState.result.waveId = "W14" end,
        function(p) p.runState.result.reason = "hp_zero" end,
        function(p) p.runState.nextWaveIndex = 14 end,
        function(p) table.remove(p.metaState.unlockedTowerIds, 6) end,
    }) do
        local invalid = Json.decode(Json.encode(payload))
        mutate(invalid)
        equal(validator(invalid), nil)
    end
end)

test("S24 generation34 migrates recorded W05 once without writes or snapshot changes", function()
    local storage = MemoryStorage()
    local original = s24Checkpoint("s24-g34")
    original.runState.modules = Json.array({ { moduleId = "M33", paidGold = 12, growth = 12 } })
    original.runState.acquiredModuleIds = { M33 = true }
    writeEnvelope(storage, "save-b.json", 34, S24_VERSION, original,
        Save.adler32, "adler32-v1-test-fixture")
    local bytes = storage.files["save-b.json"]
    local save = newValidatedSave(storage)
    local first, second = save:loadCheckpoint(), save:loadCheckpoint()
    equal(first.status, "migrated")
    equal(first.sourceContentVersion, S24_VERSION)
    equal(first.generation, 34)
    equal(Json.encode(first.payload), Json.encode(second.payload))
    equal(storage.writes, 0)
    equal(storage.files["save-b.json"], bytes)
    local expectedRun = Json.decode(Json.encode(original.runState))
    expectedRun.contentVersion = LIVE_DEFS.version
    equal(Json.encode(first.payload.runState), Json.encode(expectedRun), "only run version changes")
    truthy(contains(first.payload.metaState.unlockedTowerIds, "T05"))
    equal(contains(first.payload.metaState.unlockedTowerIds, "T06"), false)
    equal(first.payload.metaState.marker, "s24-g34")
    equal(Json.encode(first.payload.metaState.unlockedModuleIds), Json.encode(original.metaState.unlockedModuleIds))
end)

test("S24 migration never infers unlock from progress or a different older run", function()
    local storage = MemoryStorage()
    local older = bossResultCheckpoint("victory", 17, "boss_killed")
    older.runState.runId = "older-winning-run"
    writeEnvelope(storage, "save-a.json", 33, S24_VERSION, older,
        Save.adler32, "adler32-v1-test-fixture")
    local latest = s24Checkpoint("no-W05-record")
    latest.runState.runId = "latest-run"
    latest.runState.completedWaveIds.W05 = nil
    writeEnvelope(storage, "save-b.json", 34, S24_VERSION, latest,
        Save.adler32, "adler32-v1-test-fixture")
    local loaded = newValidatedSave(storage):loadCheckpoint()
    equal(loaded.status, "migrated")
    equal(loaded.payload.runState.runId, "latest-run")
    equal(Json.encode(loaded.payload.metaState.unlockedTowerIds), Json.encode(STARTING_TOWERS))
    equal(storage.writes, 0)
end)

test("old boss result restores T06 only from valid recorded victory", function()
    for _, sourceVersion in ipairs({ S24_VERSION, RUN002_VERSION }) do
    for _, case in ipairs({
        { "victory", 17, "boss_killed", "migrated", true },
        { "defeat", 0, "hp_zero", "migrated", false },
        { "victory", 0, "boss_killed", "corrupt", false },
        { "victory", 17, "hp_zero", "corrupt", false },
    }) do
        local storage = MemoryStorage()
        local payload = bossResultCheckpoint(case[1], case[2], case[3])
        payload.runState.contentVersion = sourceVersion
        if sourceVersion == RUN002_VERSION then payload.runState.frozenUnlockPool.moduleIds = RUN002_MODULE_IDS end
        writeEnvelope(storage, "save-b.json", 34, sourceVersion, payload,
            Save.adler32, "adler32-v1-test-fixture")
        local loaded = newValidatedSave(storage):loadCheckpoint()
        equal(loaded.status, case[4])
        if loaded.payload then equal(contains(loaded.payload.metaState.unlockedTowerIds, "T06"), case[5]) end
        equal(storage.writes, 0)
    end
    end
end)

test("S24 legacy validation rejects future towers and modules before migration", function()
    for _, mutate in ipairs({
        function(p) p.metaState.unlockedTowerIds[5] = "T05" end,
        function(p) p.runState.shopState.offers.tower = "T06" end,
        function(p) p.runState.frozenUnlockPool.towerIds[5] = "T05" end,
        function(p) p.runState.towerInstances[1].typeId = "T06" end,
        function(p) p.runState.frozenUnlockPool.moduleIds[#p.runState.frozenUnlockPool.moduleIds + 1] = "M48" end,
    }) do
        local storage = MemoryStorage()
        local payload = s24Checkpoint("fixed-s24")
        mutate(payload)
        writeEnvelope(storage, "save-b.json", 34, S24_VERSION, payload,
            Save.adler32, "adler32-v1-test-fixture")
        equal(newValidatedSave(storage):loadCheckpoint().status, "corrupt")
        equal(storage.writes, 0)
    end
end)

test("migrated tower rights persist only on subsequent exact successful generation35 retry", function()
    local storage = MemoryStorage()
    writeEnvelope(storage, "save-b.json", 34, S24_VERSION, s24Checkpoint("retry-rights"),
        Save.adler32, "adler32-v1-test-fixture")
    local oldBytes = storage.files["save-b.json"]
    local save = newValidatedSave(storage)
    local session = Session.new({ checkpointStore = save })
    equal(session:dispatch({ commandId = "restore-rights", expectedStateRevision = 0, type = "RESTORE" }).status, "restored")
    local checkpoint = save:loadCheckpoint().payload
    checkpoint.checkpointKind, checkpoint.transactionIdentity = "transaction", "rights-followup"
    storage.writeMode = "fail_before"
    local failed = session:dispatch({ commandId = "persist-rights", expectedStateRevision = 1,
        type = "APPLY_DURABLE", checkpoint = checkpoint })
    equal(failed.status, "save_error")
    equal(failed.generation, 35)
    local attempt = storage.writeAttempts[1].data
    equal(storage.files["save-b.json"], oldBytes)
    equal(save:loadCheckpoint().generation, 34)
    storage.writeMode = nil
    equal(session:dispatch({ commandId = "retry-rights", expectedStateRevision = 2, type = "RETRY_SAVE" }).status, "applied")
    equal(storage.writeAttempts[2].data, attempt)
    local loaded = save:loadCheckpoint()
    equal(loaded.status, "valid")
    equal(loaded.generation, 35)
    equal(loaded.payload.runState.contentVersion, LIVE_DEFS.version)
    truthy(contains(loaded.payload.metaState.unlockedTowerIds, "T05"))
    equal(Json.encode(loaded.payload.runState.frozenUnlockPool.towerIds), Json.encode(STARTING_TOWERS))
    equal(storage.files["save-b.json"], oldBytes)
end)

test("new completion rights and progress commit together only after exact retry", function()
    for _, case in ipairs({ { "W05", 5, "wave_complete", nil, "T05" },
        { "W15", 15, "victory", "boss_killed", "T06" } }) do
        local storage = MemoryStorage()
        local before = liveCheckpoint("COMBAT", "combatStart", "before-" .. case[1])
        before.runState.nextWaveIndex = case[2]
        for index = 1, case[2] - 1 do before.runState.completedWaveIds[string.format("W%02d", index)] = true end
        if case[2] == 15 then before.metaState.unlockedTowerIds[5] = "T05" end
        before.runState.shopState.accessOpen = false
        before.resumeDescriptor.waveIndex = case[2]
        local save = newValidatedSave(storage)
        equal(save:commitCheckpoint(before).status, "committed")
        local session = Session.new({ checkpointStore = save })
        equal(session:dispatch({ commandId = "restore-" .. case[1], expectedStateRevision = 0, type = "RESTORE" }).status, "restored")
        local summary = { waveId = case[1], resultKind = case[3], resultReason = case[4], hp = 17, tick = 800, leaks = 0 }
        local after, events = Rules.reduceCompletion(LIVE_DEFS, before.runState, summary)
        local meta = Rules.reduceTowerUnlocks(before.metaState, before.runState, after, summary, events)
        local candidate = Json.decode(Json.encode(before))
        candidate.runState, candidate.metaState = after, meta
        candidate.runState.phase = case[3] == "victory" and "RESULT" or "PREPARE"
        candidate.checkpointKind = case[3] == "victory" and "runResult" or "waveComplete"
        candidate.resumeDescriptor = { kind = candidate.checkpointKind, waveIndex = after.nextWaveIndex }
        storage.writeMode = "fail_before"
        local failed = session:dispatch({ commandId = "complete-" .. case[1], expectedStateRevision = 1,
            type = case[3] == "victory" and "FINISH_RUN" or "COMPLETE_WAVE", nextPhase = "PREPARE", checkpoint = candidate })
        equal(failed.status, "save_error")
        equal(contains(session:getState().metaState.unlockedTowerIds, case[5]), false)
        equal(Json.encode(session:getState().runState), Json.encode(before.runState))
        local bytes = storage.writeAttempts[2].data
        candidate.metaState.unlockedTowerIds = STARTING_TOWERS
        storage.writeMode = nil
        equal(session:dispatch({ commandId = "retry-" .. case[1], expectedStateRevision = 2, type = "RETRY_SAVE" }).status, "applied")
        equal(storage.writeAttempts[3].data, bytes)
        truthy(contains(session:getState().metaState.unlockedTowerIds, case[5]))
        equal(Json.encode(session:getState().runState.frozenUnlockPool.towerIds), Json.encode(STARTING_TOWERS))
        local loaded = save:loadCheckpoint()
        equal(loaded.generation, 2)
        equal(Json.encode(loaded.payload.metaState), Json.encode(session:getState().metaState))
        equal(Json.encode(loaded.payload.runState), Json.encode(session:getState().runState))
    end
end)

test("JSON is canonical data-only and preserves explicit empty arrays", function()
    local encoded = Json.encode({ z = 2, a = Json.array(), text = "한글" })
    equal(encoded, '{"a":[],"text":"한글","z":2}')
    local decoded = Json.decode(encoded)
    equal(Json.encode(decoded), encoded)
    local ok = pcall(Json.decode, "return { hacked = true }")
    equal(ok, false, "Lua source must not be accepted as JSON")
end)

test("RNG state is deterministic, injectable and round-trippable", function()
    local first = Rng.new(1234)
    local second = Rng.new(1234)
    for _ = 1, 8 do equal(first:drawInteger(1, 99), second:drawInteger(1, 99)) end
    local snapshot = first:getState()
    local expected = first:drawInteger(10, 20)
    local restored = Rng.new(1)
    truthy(restored:setState(snapshot))
    equal(restored:drawInteger(10, 20), expected)
end)

test("string-derived RNG seeds are stable and remain in the Park-Miller domain", function()
    local first = Rng.seedFromString("sha256:abc\0run-1\0S01")
    local second = Rng.seedFromString("sha256:abc\0run-1\0S01")
    equal(first, second)
    truthy(first > 0 and first < 2147483647)
    truthy(first ~= Rng.seedFromString("sha256:def\0run-1\0S01"))
end)

test("LÖVE RandomGenerator adapter keeps opaque state with engine version", function()
    local fake = { state = "opaque:1" }
    function fake:random(lo) self.state = "opaque:2"; return lo end
    function fake:getState() return self.state end
    function fake:setState(state) self.state = state end
    local adapter = Rng.fromLove(fake, "11.5")
    local initial = adapter:getState()
    equal(initial.engineVersion, "11.5")
    equal(adapter:drawInteger(3, 7), 3)
    truthy(adapter:setState(initial))
    equal(adapter:getState().state, "opaque:1")
    local ok, errorMessage = adapter:setState({ algorithm = "love-random-generator",
        engineVersion = "12.0", state = "opaque:1" })
    equal(ok, nil)
    equal(errorMessage, "rng engine version mismatch")
end)

test("two generations read back and a corrupt latest generation recovers older data", function()
    local storage = MemoryStorage()
    local save = newSave(storage)
    local one = save:commitCheckpoint(checkpoint("SHOP", "runStart", "one"))
    equal(one.status, "committed")
    equal(one.generation, 1)
    local two = save:commitCheckpoint(checkpoint("PREPARE", "transaction", "two"))
    equal(two.status, "committed")
    equal(two.generation, 2)
    storage.files["save-b.json"] = storage.files["save-b.json"] .. "damage"
    local loaded = save:loadCheckpoint()
    equal(loaded.status, "recovered")
    equal(loaded.generation, 1)
    equal(loaded.payload.metaState.marker, "one")
end)

test("future schema blocks downgrade even when an older valid generation exists", function()
    local storage = MemoryStorage()
    local save = newSave(storage)
    equal(save:commitCheckpoint(checkpoint("SHOP", "runStart", "one")).status, "committed")
    local payloadJson = Json.encode(checkpoint("PREPARE", "transaction", "future"))
    storage.files["save-b.json"] = Json.encode({
        schemaVersion = 2,
        generation = 2,
        contentVersion = "slice-r2",
        engineTarget = "love-11.5",
        checksumAlgorithm = "adler32-v1-test-fixture",
        payloadJson = payloadJson,
        payloadChecksum = Save.adler32(payloadJson),
    })
    local loaded = save:loadCheckpoint()
    equal(loaded.status, "unsupported")
    equal(loaded.generation, 2)
    equal(storage.files["save-a.json"] ~= nil, true, "older source must be preserved")
end)

test("write failure keeps the previous generation and ambiguous success is discovered by readback", function()
    local storage = MemoryStorage()
    local save = newSave(storage)
    equal(save:commitCheckpoint(checkpoint("SHOP", "runStart", "one")).status, "committed")
    storage.writeMode = "fail_before"
    local candidate = assert(save:prepareCheckpoint(checkpoint("COMBAT", "combatStart", "two")))
    local failed = save:commitCandidate(candidate)
    equal(failed.status, "failed")
    equal(save:loadCheckpoint().generation, 1)
    storage.writeMode = "fail_after"
    local committed = save:commitCandidate(candidate)
    equal(committed.status, "committed")
    equal(committed.recoveredAmbiguousWrite, true)
    equal(save:loadCheckpoint().generation, 2)
end)

test("read errors are explicit and never treated as an empty profile", function()
    local storage = MemoryStorage()
    storage.readErrors["save-a.json"] = true
    local loaded = newSave(storage):loadCheckpoint()
    equal(loaded.status, "error")
end)

test("live validator preserves base shape and accepts current first-slice checkpoint phases", function()
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    for _, scenario in ipairs({
        { phase = "TITLE", kind = "runStart" },
        { phase = "SHOP", kind = "runStart" },
        { phase = "COMBAT", kind = "combatStart" },
        { phase = "PREPARE", kind = "waveComplete" },
    }) do
        local valid, validationError = validator(liveCheckpoint(scenario.phase, scenario.kind, scenario.kind))
        truthy(valid, validationError)
    end
    local valid, validationError = validator({})
    equal(valid, nil)
    truthy(type(validationError) == "string")
end)

test("live validator rejects unknown definition references", function()
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    local cases = {
        function(payload) payload.runState.mapId = "M_UNKNOWN" end,
        function(payload) payload.runState.towerInstances[1].typeId = "T_UNKNOWN" end,
        function(payload) payload.runState.towerInstances[1].patchIds = { "P_UNKNOWN" } end,
        function(payload) payload.runState.modules = { { moduleId = "M_UNKNOWN", paidGold = 0, growth = 0 } } end,
        function(payload) payload.runState.completedWaveIds = { W_UNKNOWN = true } end,
        function(payload) payload.runState.shopState.offers.tower = "T_UNKNOWN" end,
    }
    for index, mutate in ipairs(cases) do
        local payload = liveCheckpoint("SHOP", "runStart", "unknown-" .. index)
        mutate(payload)
        local valid = validator(payload)
        equal(valid, nil, "unknown reference case " .. index .. " must fail")
    end
end)

test("live validator rejects invalid identities arrays quantities and placements", function()
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    local cases = {
        function(payload) payload.runState.towerInstances[2].instanceId = 1 end,
        function(payload) payload.runState.towerInstances[1].instanceId = 0 end,
        function(payload) payload.runState.towerInstances[1].patchIds = { "P_DAMAGE", "P_RATE", "P_RANGE", "P_OVERLOAD" } end,
        function(payload) payload.runState.towerInstances[1].patchIds = { unexpected = "P_DAMAGE" } end,
        function(payload) payload.runState.modules = { "M01", "M01" } end,
        function(payload) payload.runState.acquiredModuleIds = { "M01", "M01" } end,
        function(payload) payload.runState.gold = -1 end,
        function(payload) payload.runState.hp = 1.5 end,
        function(payload) payload.runState.nextInstanceId = 2 end,
        function(payload) payload.runState.towerInstances[1].placement = { x = -1, y = 0 } end,
        function(payload)
            payload.runState.towerInstances[1].placement = { x = 1, y = 0 }
            payload.runState.towerInstances[2].placement = { x = 1, y = 0 }
        end,
        function(payload) payload.runState.towerInstances[1].placement = { x = 0, y = 1 } end,
    }
    for index, mutate in ipairs(cases) do
        local payload = liveCheckpoint("SHOP", "runStart", "invalid-" .. index)
        mutate(payload)
        local valid = validator(payload)
        equal(valid, nil, "semantic corruption case " .. index .. " must fail")
    end
end)

test("current validator enforces object module entries and growth steps for learning modules", function()
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    for _, growth in ipairs({ 4, 31 }) do
        local payload = liveCheckpoint("SHOP", "runStart", "growth-" .. growth)
        payload.runState.modules = Json.array({ { moduleId = "M33", paidGold = 12, growth = growth } })
        payload.runState.acquiredModuleIds = { M33 = true }
        local valid = validator(payload)
        equal(valid, nil, "invalid learning growth must fail")
    end

    local validPayload = liveCheckpoint("SHOP", "runStart", "growth-30")
    validPayload.runState.modules = Json.array({ { moduleId = "M33", paidGold = 12, growth = 30 } })
    validPayload.runState.acquiredModuleIds = { M33 = true }
    truthy(validator(validPayload))

    local stringPayload = liveCheckpoint("SHOP", "runStart", "current-string")
    stringPayload.runState.modules = Json.array({ "M01" })
    stringPayload.runState.acquiredModuleIds = { M01 = true }
    equal(validator(stringPayload), nil, "current saves must use normalized module objects")
end)

test("checksummed semantic corruption recovers prior valid generation", function()
    local mutations = {
        function(payload) payload.runState.towerInstances[1].typeId = "T_UNKNOWN" end,
        function(payload) payload.runState.towerInstances[2].instanceId = 1 end,
    }
    for index, mutate in ipairs(mutations) do
        local storage = MemoryStorage()
        local save = newValidatedSave(storage)
        equal(save:commitCheckpoint(liveCheckpoint("SHOP", "runStart", "valid")).status, "committed")
        local corrupt = liveCheckpoint("PREPARE", "transaction", "corrupt-" .. index)
        mutate(corrupt)
        writeLiveEnvelope(storage, "save-b.json", 2, corrupt)
        local loaded = save:loadCheckpoint()
        equal(loaded.status, "recovered")
        equal(loaded.generation, 1)
        equal(loaded.issues[1].status, "corrupt")
    end
end)

test("checksummed invalid quantity is explicit corrupt without an older generation", function()
    local storage = MemoryStorage()
    local payload = liveCheckpoint("SHOP", "runStart", "bad-quantity")
    payload.runState.gold = -1
    writeLiveEnvelope(storage, "save-a.json", 1, payload)
    local loaded = newValidatedSave(storage):loadCheckpoint()
    equal(loaded.status, "corrupt")
    equal(loaded.error, "no valid checkpoint generation")
end)

test("checksummed missing gold or hp recovers and preserves the older valid generation", function()
    for _, field in ipairs({ "gold", "hp" }) do
        local storage = MemoryStorage()
        local save = newValidatedSave(storage)
        equal(save:commitCheckpoint(liveCheckpoint("SHOP", "runStart", "valid-" .. field)).status, "committed")
        local olderBytes = storage.files["save-a.json"]
        local missing = liveCheckpoint("PREPARE", "transaction", "missing-" .. field)
        missing.runState[field] = nil
        writeLiveEnvelope(storage, "save-b.json", 2, missing)
        local loaded = save:loadCheckpoint()
        equal(loaded.status, "recovered", "missing " .. field .. " must reject latest generation")
        equal(loaded.generation, 1)
        equal(loaded.issues[1].status, "corrupt")
        equal(storage.files["save-a.json"], olderBytes, "older valid generation must remain byte-identical")
    end
end)

test("generation 34 W07 migration, transaction preview and cancel are write-free", function()
    local storage = MemoryStorage()
    local payload = run002W07Checkpoint("generation-34-preview")
    writeEnvelope(storage, "save-b.json", 34, RUN002_VERSION, payload,
        Save.adler32, "adler32-v1-test-fixture")
    local originalBytes = storage.files["save-b.json"]
    local save = newValidatedSave(storage)

    local loaded = save:loadCheckpoint()
    equal(loaded.status, "migrated")
    equal(loaded.generation, 34)
    equal(loaded.path, "save-b.json")
    equal(loaded.payload.runState.nextWaveIndex, 7)
    equal(loaded.payload.runState.shopState.visitId, "S02")
    equal(loaded.payload.runState.contentVersion, LIVE_DEFS.version)
    equal(Json.encode(loaded.payload.runState.frozenUnlockPool.moduleIds), Json.encode(RUN002_MODULE_IDS))
    equal(loaded.payload.runState.hp, payload.runState.hp)
    equal(loaded.payload.runState.gold, payload.runState.gold)
    equal(Json.encode(loaded.payload.runState.towerInstances), Json.encode(payload.runState.towerInstances))
    equal(Json.encode(loaded.payload.runState.modules), Json.encode(payload.runState.modules))
    truthy(contains(loaded.payload.metaState.unlockedTowerIds, "T05"), "recorded W05 restores T05")
    equal(Json.encode(loaded.payload.metaState.unlockedModuleIds), Json.encode(payload.metaState.unlockedModuleIds))
    equal(Json.encode(loaded.payload.runState.shopState.offers), Json.encode(payload.runState.shopState.offers))
    equal(Json.encode(loaded.payload.runState.shopState.rngState), Json.encode(payload.runState.shopState.rngState))
    equal(loaded.payload.runState.shopState.refundUseCount, payload.runState.shopState.refundUseCount)
    equal(loaded.payload.runState.shopState.firstRerollDone, payload.runState.shopState.firstRerollDone)
    equal(storage.writes, 0, "loading the current generation must not write")

    local beforeRun = Json.encode(loaded.payload.runState)
    local preview, previewError = Rules.previewInventoryTransaction(LIVE_DEFS,
        loaded.payload.runState, { phase = "SHOP", kind = "sell_tower", instanceId = 1 })
    truthy(preview, previewError)
    equal(preview.refundGold, 5)
    equal(Json.encode(loaded.payload.runState), beforeRun, "preview must not mutate the loaded run")
    equal(storage.writes, 0, "preview must not write")

    -- Cancelling discards the transient preview; persistence remains at generation 34.
    local afterCancel = save:loadCheckpoint()
    equal(afterCancel.generation, 34)
    equal(storage.writes, 0, "cancel must not write")
    equal(storage.files["save-b.json"], originalBytes)
    equal(Json.encode(afterCancel.payload.runState.shopState.offers),
        Json.encode(payload.runState.shopState.offers))
    equal(Json.encode(afterCancel.payload.runState.shopState.rngState),
        Json.encode(payload.runState.shopState.rngState))
end)

test("shared rule capacities reject an invalid transaction before generation 34 is written", function()
    local storage = MemoryStorage()
    local payload = withPlacedTowerCount(currentW07Checkpoint("generation-34-capacity"), 7)
    equal(Rules.towerCapacity(payload.runState), 8)
    writeLiveEnvelope(storage, "save-b.json", 34, payload)
    local originalBytes = storage.files["save-b.json"]
    local save = newValidatedSave(storage)
    equal(save:loadCheckpoint().generation, 34)

    local invalidTowerCapacity = Json.decode(Json.encode(payload))
    table.remove(invalidTowerCapacity.runState.modules, 2)
    invalidTowerCapacity.checkpointKind = "transaction"
    invalidTowerCapacity.resumeDescriptor.kind = "transaction"
    invalidTowerCapacity.transactionIdentity = "trade:sell-module:M05"
    equal(Rules.towerCapacity(invalidTowerCapacity.runState), 6)
    local candidate, rejected = save:prepareCheckpoint(invalidTowerCapacity)
    equal(candidate, nil)
    equal(rejected.status, "failed")
    truthy(tostring(rejected.error):find("placed tower count exceeds current capacity", 1, true))

    local invalidModuleCapacity = Json.decode(Json.encode(payload))
    invalidModuleCapacity.runState.baseModuleSlots = 1
    local moduleCandidate, moduleRejected = save:prepareCheckpoint(invalidModuleCapacity)
    equal(moduleCandidate, nil)
    equal(moduleRejected.status, "failed")
    truthy(tostring(moduleRejected.error):find("installed module count exceeds baseModuleSlots", 1, true))

    local invalidM06Capacity = withPlacedTowerCount(currentW07Checkpoint("m06-capacity"), 5)
    invalidM06Capacity.runState.modules[2] = { moduleId = "M06", paidGold = 16, growth = 0 }
    invalidM06Capacity.runState.acquiredModuleIds.M05 = nil
    invalidM06Capacity.runState.acquiredModuleIds.M06 = true
    equal(Rules.towerCapacity(invalidM06Capacity.runState), 4)
    local m06Candidate, m06Rejected = save:prepareCheckpoint(invalidM06Capacity)
    equal(m06Candidate, nil)
    equal(m06Rejected.status, "failed")
    truthy(tostring(m06Rejected.error):find("placed tower count exceeds current capacity", 1, true))

    equal(storage.writes, 0, "semantic capacity failure must happen before storage.write")
    equal(storage.files["save-b.json"], originalBytes)
    equal(save:loadCheckpoint().generation, 34)
end)

test("generation 34 write failure retries the exact prepared generation 35 candidate", function()
    local storage = MemoryStorage()
    local payload = run002W07Checkpoint("generation-34-retry")
    writeEnvelope(storage, "save-b.json", 34, RUN002_VERSION, payload,
        Save.adler32, "adler32-v1-test-fixture")
    local generation34Bytes = storage.files["save-b.json"]
    local save = newValidatedSave(storage)
    local session = Session.new({ checkpointStore = save })
    local restored = session:dispatch({ commandId = "restore-g34", expectedStateRevision = 0,
        type = "RESTORE" })
    equal(restored.status, "restored")
    equal(restored.loadStatus, "migrated")
    equal(restored.generation, 34)
    equal(storage.writes, 0)

    local state = session:getState()
    local proposedRun, events, transactionError = Rules.tryInventoryTransaction(LIVE_DEFS,
        state.runState, { phase = "SHOP", kind = "sell_tower", instanceId = 1 })
    truthy(proposedRun, transactionError)
    equal(events[1].type, "tower_sold")
    local transaction = Json.decode(Json.encode(save:loadCheckpoint().payload))
    transaction.runState = proposedRun
    transaction.checkpointKind = "transaction"
    transaction.resumeDescriptor = { kind = "transaction", waveIndex = 7 }
    transaction.transactionIdentity = "trade:sell-tower:1"

    storage.writeMode = "fail_before"
    local failed = session:dispatch({ commandId = "trade-fail", expectedStateRevision = 1,
        type = "APPLY_DURABLE", checkpoint = transaction })
    equal(failed.status, "save_error")
    equal(failed.generation, 35)
    equal(storage.writes, 1)
    equal(storage.writeAttempts[1].path, "save-a.json")
    local firstAttempt = storage.writeAttempts[1].data
    equal(save:loadCheckpoint().generation, 34)
    equal(storage.files["save-b.json"], generation34Bytes)

    storage.writeMode = nil
    local retried = session:dispatch({ commandId = "trade-retry", expectedStateRevision = 2,
        type = "RETRY_SAVE" })
    equal(retried.status, "applied")
    equal(retried.generation, 35)
    equal(retried.retried, true)
    equal(storage.writes, 2)
    equal(storage.writeAttempts[2].path, "save-a.json")
    equal(storage.writeAttempts[2].data, firstAttempt,
        "retry must submit the exact prepared envelope bytes")

    local loaded = save:loadCheckpoint()
    equal(loaded.status, "valid")
    equal(loaded.generation, 35)
    equal(loaded.path, "save-a.json")
    equal(#loaded.payload.runState.towerInstances, 1)
    equal(loaded.payload.transactionIdentity, "trade:sell-tower:1")
    equal(Json.encode(loaded.payload.runState.shopState.offers),
        Json.encode(payload.runState.shopState.offers))
    equal(Json.encode(loaded.payload.runState.shopState.rngState),
        Json.encode(payload.runState.shopState.rngState))
    local envelope = Json.decode(storage.files["save-a.json"])
    equal(envelope.schemaVersion, 1)
    equal(envelope.contentVersion, LIVE_DEFS.version)
    equal(storage.files["save-b.json"], generation34Bytes,
        "successful generation 35 must preserve generation 34")
end)

test("run002 migration preserves the W07 visit snapshot and normalizes old module strings", function()
    local storage = MemoryStorage()
    local payload = run002W07Checkpoint("run002-string-module")
    payload.runState.modules = Json.array({
        { moduleId = "M01", paidGold = 7, growth = 6 },
        "M05",
    })
    payload.runState.acquiredModuleIds = { M01 = true, M05 = true }
    payload.metaState.unlockedModuleIds = Json.array({ "M01", "M05" })
    local preservedOffers = Json.encode(payload.runState.shopState.offers)
    local preservedRng = Json.encode(payload.runState.shopState.rngState)
    local expectedMeta = Json.decode(Json.encode(payload.metaState))
    expectedMeta.unlockedTowerIds[#expectedMeta.unlockedTowerIds + 1] = "T05"
    local preservedMeta = Json.encode(expectedMeta)
    writeEnvelope(storage, "save-b.json", 34, RUN002_VERSION, payload,
        Save.adler32, "adler32-v1-test-fixture")

    local loaded = newRun002Save(storage):loadCheckpoint()
    equal(loaded.status, "migrated")
    equal(loaded.sourceContentVersion, RUN002_VERSION)
    equal(loaded.generation, 34)
    equal(storage.writes, 0)
    local run = loaded.payload.runState
    equal(run.contentVersion, LIVE_DEFS.version)
    equal(Json.encode(run.frozenUnlockPool.moduleIds), Json.encode(RUN002_MODULE_IDS))
    equal(Json.encode(run.shopState.offers), preservedOffers)
    equal(Json.encode(run.shopState.rngState), preservedRng)
    equal(run.shopState.rerollCount, payload.runState.shopState.rerollCount)
    equal(run.shopState.refundUseCount, payload.runState.shopState.refundUseCount)
    equal(run.shopState.firstRerollDone, payload.runState.shopState.firstRerollDone)
    equal(Json.encode(loaded.payload.metaState), preservedMeta)
    equal(run.modules[1].moduleId, "M01")
    equal(run.modules[1].paidGold, 7)
    equal(run.modules[1].growth, 6)
    equal(run.modules[2].moduleId, "M05")
    equal(run.modules[2].paidGold, LIVE_DEFS.modulesById.M05.price)
    equal(run.modules[2].growth, 0)
end)

test("known r2 generations migrate read-only with actual progress and stable RNG", function()
    local storage = MemoryStorage()
    local checksum = love and love.data and Save.loveSha256(love.data) or Save.adler32
    local checksumName = love and love.data and "sha256" or "adler32-v1-test-fixture"
    local older = legacyCheckpoint("PREPARE", 4)
    older.runState.hp = 18
    local latest = legacyCheckpoint("PREPARE", 4)
    local preserved = {
        hp = latest.runState.hp,
        gold = latest.runState.gold,
        towers = Json.encode(latest.runState.towerInstances),
        acquired = Json.encode(latest.runState.acquiredModuleIds),
        completed = Json.encode(latest.runState.completedWaveIds),
        meta = Json.encode(latest.metaState),
        offers = Json.encode(latest.runState.shopState.offers),
        rerollCount = latest.runState.shopState.rerollCount,
    }
    writeEnvelope(storage, "save-a.json", 27, "DR-SLICE-001-r2", older, checksum, checksumName)
    local latestJson = writeEnvelope(storage, "save-b.json", 28, "DR-SLICE-001-r2", latest,
        checksum, checksumName)
    local expectedSeed = Rng.seedFromString(table.concat({
        checksum(latestJson), latest.runState.runId, latest.runState.shopState.visitId,
    }, "\0"))
    local writesBefore = storage.writes
    local save = newRun002Save(storage, checksum, checksumName)
    local loaded = save:loadCheckpoint()
    equal(loaded.status, "migrated")
    equal(loaded.generation, 28)
    equal(loaded.sourceGeneration, 28)
    equal(loaded.sourceContentVersion, "DR-SLICE-001-r2")
    equal(#loaded.slots, 2)
    equal(storage.writes, writesBefore, "migration load must not write")
    local run = loaded.payload.runState
    equal(run.contentVersion, LIVE_DEFS.version)
    equal(run.developmentComplete, false)
    equal(run.shopState.accessOpen, true)
    equal(run.shopState.rngState.state, expectedSeed)
    equal(run.hp, preserved.hp)
    equal(run.gold, preserved.gold)
    equal(Json.encode(run.towerInstances), preserved.towers)
    equal(run.modules[1].moduleId, "M01")
    equal(run.modules[1].paidGold, LIVE_DEFS.modulesById.M01.price)
    equal(run.modules[1].growth, 0)
    equal(Json.encode(run.acquiredModuleIds), preserved.acquired)
    equal(Json.encode(run.completedWaveIds), preserved.completed)
    equal(Json.encode(loaded.payload.metaState), preserved.meta)
    equal(Json.encode(run.shopState.offers), preserved.offers)
    equal(run.shopState.rerollCount, preserved.rerollCount)
    equal(Json.encode(run.frozenUnlockPool.moduleIds), Json.encode(RUN002_MODULE_IDS))
    equal(save:loadCheckpoint().payload.runState.shopState.rngState.state, expectedSeed,
        "repeated loads must derive the same state without drawing")
    equal(storage.writes, writesBefore)
end)

test("run002 validator is fixed to its six-module pool before direct migration", function()
    local storage = MemoryStorage()
    local payload = run002W07Checkpoint("run002-new-id-corrupt")
    payload.runState.modules = Json.array({ { moduleId = "M06", paidGold = 16, growth = 0 } })
    payload.runState.acquiredModuleIds = { M06 = true }
    writeEnvelope(storage, "save-b.json", 34, RUN002_VERSION, payload,
        Save.adler32, "adler32-v1-test-fixture")
    local loaded = newRun002Save(storage):loadCheckpoint()
    equal(loaded.status, "corrupt")
    equal(storage.writes, 0)
end)

test("legacy validator is fixed to W01-W03 and rejects future progress or references", function()
    for _, mutate in ipairs({
        function(payload) payload.runState.nextWaveIndex = 5; payload.resumeDescriptor.waveIndex = 5 end,
        function(payload) payload.runState.nextWaveIndex = 15; payload.resumeDescriptor.waveIndex = 15 end,
        function(payload) payload.resumeDescriptor.enemyId = "E05" end,
    }) do
        local storage = MemoryStorage()
        local payload = legacyCheckpoint("PREPARE", 4)
        mutate(payload)
        writeEnvelope(storage, "save-a.json", 1, "DR-SLICE-001-r2", payload,
            Save.adler32, "adler32-v1-test-fixture")
        local loaded = newRun002Save(storage):loadCheckpoint()
        equal(loaded.status, "corrupt")
    end

    local storage = MemoryStorage()
    local payload = legacyCheckpoint("PREPARE", 4)
    writeEnvelope(storage, "save-a.json", 1, "DR-SLICE-001-r2", payload,
        Save.adler32, "adler32-v1-test-fixture")
    equal(newRun002Save(storage):loadCheckpoint().status, "migrated", "legacy nextWaveIndex 4 must pass")
end)

test("legacy checksum and semantic validation precede migration and unknown higher versions block downgrade", function()
    local storage = MemoryStorage()
    local legacy = legacyCheckpoint("PREPARE", 4)
    writeEnvelope(storage, "save-a.json", 27, "DR-SLICE-001-r2", legacy,
        Save.adler32, "adler32-v1-test-fixture")
    local unknown = liveCheckpoint("PREPARE", "waveComplete", "future")
    writeEnvelope(storage, "save-b.json", 28, "DR-RUN-999-r1", unknown,
        Save.adler32, "adler32-v1-test-fixture")
    local save = newRun002Save(storage)
    local blocked = save:loadCheckpoint()
    equal(blocked.status, "unsupported")
    equal(blocked.generation, 28)
    equal(storage.writes, 0)

    storage.files["save-b.json"] = nil
    local encoded = Json.decode(storage.files["save-a.json"])
    encoded.payloadChecksum = "adler32-v1:00000000"
    storage.files["save-a.json"] = Json.encode(encoded)
    equal(save:loadCheckpoint().status, "corrupt", "checksum mismatch must never enter migration")
    equal(storage.writes, 0)
end)

test("commands are idempotent and stale previews do not mutate state", function()
    local storage = MemoryStorage()
    local session = Session.new({ checkpointStore = newSave(storage) })
    local command = {
        commandId = "new-run",
        expectedStateRevision = 0,
        type = "NEW_RUN",
        checkpoint = checkpoint("SHOP", "runStart", "new"),
    }
    local applied = session:dispatch(command)
    equal(applied.status, "applied")
    equal(applied.stateRevision, 1)
    equal(storage.writes, 1)
    local duplicate = session:dispatch(command)
    equal(duplicate.status, "applied")
    equal(duplicate.stateRevision, 1)
    equal(storage.writes, 1, "duplicate command must not write again")

    local stale = session:dispatch({ commandId = "stale", expectedStateRevision = 0, type = "CLOSE_SHOP" })
    equal(stale.status, "stale")
    equal(session:getState().phase, "SHOP")
    local replay = session:dispatch({ commandId = "stale", expectedStateRevision = 1, type = "CLOSE_SHOP" })
    equal(replay.status, "stale", "same commandId must return its first result")
    equal(session:getState().phase, "SHOP")
end)

test("Session restores migrated checkpoints without rewriting their source generation", function()
    local storage = MemoryStorage()
    local legacy = legacyCheckpoint("PREPARE", 4)
    writeEnvelope(storage, "save-a.json", 28, "DR-SLICE-001-r2", legacy,
        Save.adler32, "adler32-v1-test-fixture")
    local session = Session.new({ checkpointStore = newRun002Save(storage) })
    local restored = session:dispatch({ commandId = "restore-migrated", expectedStateRevision = 0,
        type = "RESTORE" })
    equal(restored.status, "restored")
    equal(restored.loadStatus, "migrated")
    equal(restored.generation, 28)
    equal(restored.phase, "PREPARE")
    equal(session:getState().runState.nextWaveIndex, 4)
    equal(storage.writes, 0)
end)

test("NEW_RUN is limited to TITLE or RESULT and retries the exact RESULT draft", function()
    local storage = MemoryStorage()
    local session = Session.new({ checkpointStore = newSave(storage) })
    session:dispatch({ commandId = "initial", expectedStateRevision = 0, type = "NEW_RUN",
        checkpoint = checkpoint("SHOP", "runStart", "initial") })
    local denied = session:dispatch({ commandId = "denied", expectedStateRevision = 1, type = "NEW_RUN",
        checkpoint = checkpoint("SHOP", "runStart", "denied") })
    equal(denied.status, "rejected")
    equal(session:getState().phase, "SHOP")

    session:dispatch({ commandId = "start-result", expectedStateRevision = 1, type = "START_COMBAT",
        checkpoint = checkpoint("COMBAT", "combatStart", "combat") })
    session:dispatch({ commandId = "finish-result", expectedStateRevision = 2, type = "FINISH_RUN",
        checkpoint = checkpoint("RESULT", "runResult", "committed-result") })
    local committedResult = Json.encode(session:getState().runState)
    local committedMeta = Json.encode(session:getState().metaState)
    local draft = checkpoint("SHOP", "runStart", "next-run")
    draft.runState.runId = "new-run-fixed-id"
    storage.writeMode = "fail_before"
    local failed = session:dispatch({ commandId = "new-from-result", expectedStateRevision = 3,
        type = "NEW_RUN", checkpoint = draft })
    equal(failed.status, "save_error")
    equal(session:getState().phase, "SAVE_ERROR")
    equal(Json.encode(session:getState().runState), committedResult,
        "failed NEW_RUN must retain the committed RESULT run")
    equal(Json.encode(session:getState().metaState), committedMeta,
        "failed NEW_RUN must retain the committed RESULT meta")

    draft.runState.runId = "mutated-after-dispatch"
    draft.metaState.marker = "mutated-after-dispatch"
    storage.writeMode = nil
    local retried = session:dispatch({ commandId = "retry-new-run", expectedStateRevision = 4,
        type = "RETRY_SAVE" })
    equal(retried.status, "applied")
    equal(retried.phase, "SHOP")
    local restored = newSave(storage):loadCheckpoint().payload
    equal(restored.runState.runId, "new-run-fixed-id")
    equal(restored.runState.phase, "SHOP")
    equal(restored.metaState.marker, "next-run")
end)

test("SHOP can close and reopen without changing its visit, and combat can end at RESULT", function()
    local storage = MemoryStorage()
    local session = Session.new({ checkpointStore = newSave(storage) })
    local initial = checkpoint("SHOP", "runStart", "new")
    initial.runState.shopState = { visitId = "visit-7", offers = Json.array({ "T01" }), accessOpen = true }
    session:dispatch({ commandId = "new", expectedStateRevision = 0, type = "NEW_RUN", checkpoint = initial })
    local closed = session:dispatch({ commandId = "close", expectedStateRevision = 1, type = "CLOSE_SHOP" })
    equal(closed.phase, "PREPARE")
    local reopened = session:dispatch({ commandId = "reopen", expectedStateRevision = 2, type = "REOPEN_SHOP" })
    equal(reopened.phase, "SHOP")
    equal(session:getState().runState.shopState.visitId, "visit-7")
    equal(storage.writes, 1, "closing and reopening the same visit is not a durable mutation")
    session:dispatch({ commandId = "start", expectedStateRevision = 3, type = "START_COMBAT",
        checkpoint = checkpoint("COMBAT", "combatStart", "start") })
    local finished = session:dispatch({ commandId = "finish", expectedStateRevision = 4, type = "FINISH_RUN",
        checkpoint = checkpoint("RESULT", "runResult", "result") })
    equal(finished.status, "applied")
    equal(session:getState().phase, "RESULT")
end)

test("REOPEN_SHOP rejects missing or closed access without mutating committed state", function()
    for _, accessOpen in ipairs({ false, "missing" }) do
        local storage = MemoryStorage()
        local session = Session.new({ checkpointStore = newSave(storage) })
        local initial = checkpoint("SHOP", "runStart", "guard-" .. tostring(accessOpen))
        initial.runState.shopState = { visitId = "visit-guard", offers = Json.array({ "T01" }) }
        if accessOpen ~= "missing" then initial.runState.shopState.accessOpen = accessOpen end
        session:dispatch({ commandId = "guard-new-" .. tostring(accessOpen), expectedStateRevision = 0,
            type = "NEW_RUN", checkpoint = initial })
        session:dispatch({ commandId = "guard-close-" .. tostring(accessOpen), expectedStateRevision = 1,
            type = "CLOSE_SHOP" })
        local before = session:getState()
        local generation = newSave(storage):loadCheckpoint().generation
        local rejected = session:dispatch({ commandId = "guard-reopen-" .. tostring(accessOpen),
            expectedStateRevision = 2, type = "REOPEN_SHOP" })
        equal(rejected.status, "rejected")
        equal(rejected.error, "REOPEN_SHOP requires an open shop visit")
        local after = session:getState()
        equal(after.phase, "PREPARE")
        equal(after.stateRevision, before.stateRevision)
        equal(Json.encode(after.runState), Json.encode(before.runState))
        equal(Json.encode(after.metaState), Json.encode(before.metaState))
        equal(newSave(storage):loadCheckpoint().generation, generation)
        equal(storage.writes, 1)
    end
end)

test("REOPEN_SHOP rejects visits closed by combat or restored closed checkpoints", function()
    local storage = MemoryStorage()
    local session = Session.new({ checkpointStore = newSave(storage) })
    local initial = checkpoint("SHOP", "runStart", "combat-close")
    initial.runState.shopState = { visitId = "visit-combat", accessOpen = true }
    session:dispatch({ commandId = "combat-new", expectedStateRevision = 0,
        type = "NEW_RUN", checkpoint = initial })
    session:dispatch({ commandId = "combat-close", expectedStateRevision = 1, type = "CLOSE_SHOP" })
    local combat = checkpoint("COMBAT", "combatStart", "combat")
    combat.runState.shopState = { visitId = "visit-combat", accessOpen = false }
    session:dispatch({ commandId = "combat-start", expectedStateRevision = 2,
        type = "START_COMBAT", checkpoint = combat })
    local prepared = checkpoint("PREPARE", "waveComplete", "prepared")
    prepared.runState.shopState = { visitId = "visit-combat", accessOpen = false }
    session:dispatch({ commandId = "combat-complete", expectedStateRevision = 3,
        type = "COMPLETE_WAVE", nextPhase = "PREPARE", checkpoint = prepared })
    local beforeCombatReopen = session:getState()
    local combatGeneration = newSave(storage):loadCheckpoint().generation
    local combatRejected = session:dispatch({ commandId = "combat-reopen", expectedStateRevision = 4,
        type = "REOPEN_SHOP" })
    equal(combatRejected.status, "rejected")
    equal(Json.encode(session:getState().runState), Json.encode(beforeCombatReopen.runState))
    equal(session:getRevision(), beforeCombatReopen.stateRevision)
    equal(newSave(storage):loadCheckpoint().generation, combatGeneration)

    local restoreStorage = MemoryStorage()
    local closed = checkpoint("PREPARE", "waveComplete", "restore-closed")
    closed.runState.shopState = { visitId = "visit-restored", accessOpen = false }
    equal(newSave(restoreStorage):commitCheckpoint(closed).status, "committed")
    local restoredSession = Session.new({ checkpointStore = newSave(restoreStorage) })
    restoredSession:dispatch({ commandId = "closed-restore", expectedStateRevision = 0, type = "RESTORE" })
    local beforeRestoreReopen = restoredSession:getState()
    local restoredGeneration = newSave(restoreStorage):loadCheckpoint().generation
    local restoredRejected = restoredSession:dispatch({ commandId = "restored-reopen", expectedStateRevision = 1,
        type = "REOPEN_SHOP" })
    equal(restoredRejected.status, "rejected")
    equal(restoredSession:getState().phase, "PREPARE")
    equal(restoredSession:getRevision(), beforeRestoreReopen.stateRevision)
    equal(Json.encode(restoredSession:getState().runState), Json.encode(beforeRestoreReopen.runState))
    equal(Json.encode(restoredSession:getState().metaState), Json.encode(beforeRestoreReopen.metaState))
    equal(newSave(restoreStorage):loadCheckpoint().generation, restoredGeneration)
end)

test("pause reasons compose and focus gain never auto-resumes combat", function()
    local storage = MemoryStorage()
    local session = Session.new({ checkpointStore = newSave(storage) })
    session:dispatch({ commandId = "new", expectedStateRevision = 0, type = "NEW_RUN",
        checkpoint = checkpoint("SHOP", "runStart", "new") })
    session:dispatch({ commandId = "start", expectedStateRevision = 1, type = "START_COMBAT",
        checkpoint = checkpoint("COMBAT", "combatStart", "start") })
    session:dispatch({ commandId = "pause", expectedStateRevision = 2, type = "PAUSE", reason = "user" })
    session:dispatch({ commandId = "blur", expectedStateRevision = 3, type = "FOCUS_LOST" })
    local gained = session:dispatch({ commandId = "focus", expectedStateRevision = 4, type = "FOCUS_GAINED" })
    equal(gained.requiresExplicitResume, true)
    equal(session:canAdvanceTime(), false)
    local state = session:getState()
    truthy(contains(state.pauseReasons, "focus"))
    truthy(contains(state.pauseReasons, "user"))
    session:dispatch({ commandId = "resume-focus", expectedStateRevision = 5, type = "RESUME", reason = "focus" })
    equal(session:canAdvanceTime(), false, "user pause must remain")
    session:dispatch({ commandId = "resume-user", expectedStateRevision = 6, type = "RESUME", reason = "user" })
    equal(session:canAdvanceTime(), true)
end)

test("SAVE_ERROR blocks mutation and retry commits the exact prepared candidate once", function()
    local storage = MemoryStorage()
    local session = Session.new({ checkpointStore = newSave(storage) })
    session:dispatch({ commandId = "new", expectedStateRevision = 0, type = "NEW_RUN",
        checkpoint = checkpoint("SHOP", "runStart", "new") })
    session:dispatch({ commandId = "start", expectedStateRevision = 1, type = "START_COMBAT",
        checkpoint = checkpoint("COMBAT", "combatStart", "start") })
    storage.writeMode = "fail_before"
    local failed = session:dispatch({ commandId = "complete", expectedStateRevision = 2,
        type = "COMPLETE_WAVE", nextPhase = "PREPARE",
        checkpoint = checkpoint("PREPARE", "waveComplete", "complete") })
    equal(failed.status, "save_error")
    equal(failed.generation, 3)
    equal(session:getState().phase, "SAVE_ERROR")
    local blocked = session:dispatch({ commandId = "blocked", expectedStateRevision = 3, type = "CLOSE_SHOP" })
    equal(blocked.status, "rejected")
    storage.writeMode = nil
    local retried = session:dispatch({ commandId = "retry", expectedStateRevision = 3, type = "RETRY_SAVE" })
    equal(retried.status, "applied")
    equal(retried.generation, 3)
    equal(session:getState().phase, "PREPARE")
    equal(newSave(storage):loadCheckpoint().payload.metaState.marker, "complete")
end)

test("combat-start restore is paused and corrupt saves do not silently reset", function()
    local storage = MemoryStorage()
    local save = newSave(storage)
    equal(save:commitCheckpoint(checkpoint("COMBAT", "combatStart", "start")).status, "committed")
    local restoredSession = Session.new({ checkpointStore = save })
    local restored = restoredSession:dispatch({ commandId = "restore", expectedStateRevision = 0, type = "RESTORE" })
    equal(restored.status, "restored")
    equal(restored.phase, "COMBAT")
    equal(restored.paused, true)
    equal(restoredSession:canAdvanceTime(), false)
    truthy(contains(restoredSession:getState().pauseReasons, "restore"))

    storage.files["save-a.json"] = "not json"
    storage.files["save-b.json"] = "also not json"
    local corruptSession = Session.new({ checkpointStore = newSave(storage) })
    local corrupt = corruptSession:dispatch({ commandId = "restore-corrupt", expectedStateRevision = 0,
        type = "RESTORE" })
    equal(corrupt.status, "save_error")
    equal(corrupt.saveStatus, "corrupt")
    equal(corruptSession:getState().phase, "SAVE_ERROR")
end)

test("M28 T05 four frozen legacy versions load without writes or retroactive M28", function()
    local cases = {
        { "DR-SLICE-001-r2", legacyCheckpoint("PREPARE", 4) },
        { RUN002_VERSION, run002W07Checkpoint("m28-old-run002") },
        { S24_VERSION, s24Checkpoint("m28-old-s24") },
        { "DR-TOWER-U2-r1", currentW07Checkpoint("m28-old-r7") },
    }
    for _, case in ipairs(cases) do
        local storage = MemoryStorage()
        local original = case[2]
        original.runState.contentVersion = case[1]
        original.runState.gold = 99
        if case[1] == "DR-TOWER-U2-r1" then original.metaState.unlockedTowerIds[6] = "T06" end
        original.metaState.unlockedModuleIds = nil
        writeEnvelope(storage, "save-b.json", 34, case[1], original, Save.adler32, "adler32-v1-test-fixture")
        local bytes = storage.files["save-b.json"]
        local save = newValidatedSave(storage)
        local first, second = save:loadCheckpoint(), save:loadCheckpoint()
        equal(first.status, "migrated", case[1])
        equal(storage.writes, 0)
        equal(storage.files["save-b.json"], bytes)
        equal(Json.encode(first.payload), Json.encode(second.payload))
        equal(#first.payload.metaState.unlockedModuleIds, 0)
        equal(contains(first.payload.runState.frozenUnlockPool.moduleIds, "M28"), false)
        equal(contains(first.payload.runState.frozenUnlockPool.moduleIds, "M43"), false)
        if case[1] ~= "DR-SLICE-001-r2" then
            local expected = Json.decode(Json.encode(original.runState))
            expected.contentVersion = LIVE_DEFS.version
            equal(Json.encode(first.payload.runState), Json.encode(expected), "snapshot preservation " .. case[1])
        end
        equal(save:commitCheckpoint(first.payload).status, "committed")
        local persisted = save:loadCheckpoint()
        equal(persisted.generation, 35)
        equal(persisted.payload.runState.contentVersion, LIVE_DEFS.version)
        equal(storage.files["save-b.json"], bytes)
        io.write("FIXTURE M28 T05 version=", case[1], " loadWrites=0 nextGeneration=35\n")
    end
end)

test("M28 T05 frozen R7 retains tower invariants and rejects future module references", function()
    local version = "DR-TOWER-U2-r1"
    for index, mutate in ipairs({
        function(p) p.metaState.unlockedTowerIds = STARTING_TOWERS end,
        function(p) p.runState.nextWaveIndex = 5 end,
        function(p) p.runState.completedWaveIds.W15 = true end,
        function(p) p.runState.shopState.offers.tower = "T06" end,
        function(p) p.runState.towerInstances[1].typeId = "T06" end,
        function(p) p.runState.frozenUnlockPool.moduleIds[25] = "M28" end,
        function(p) p.runState.shopState.offers.module = "M28" end,
        function(p) p.runState.modules = { { moduleId = "M28", paidGold = 12, growth = 0 } } end,
        function(p) p.runState.acquiredModuleIds.M28 = true end,
        function(p) p.metaState.unlockedModuleIds = { "M28" } end,
        function(p)
            p.runState.phase, p.runState.nextWaveIndex = "RESULT", 15
            p.runState.result = { kind = "victory", waveId = "W15", tick = 5, reason = "boss_killed" }
        end,
    }) do
        local storage = MemoryStorage()
        local payload = currentW07Checkpoint("m28-r7-invalid")
        payload.runState.contentVersion = version
        mutate(payload)
        writeEnvelope(storage, "save-b.json", 34, version, payload, Save.adler32, "adler32-v1-test-fixture")
        equal(newValidatedSave(storage):loadCheckpoint().status, "corrupt", "frozen R7 invalid " .. index)
        equal(storage.writes, 0)
    end
end)

test("M28 T05 current validator guards rights pool offers installed and acquired independently", function()
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    local starting = liveCheckpoint("SHOP", "runStart")
    starting.metaState.unlockedModuleIds = nil
    truthy(validator(starting), "optional module rights default to empty")
    local permanent = liveCheckpoint("SHOP", "runStart")
    permanent.metaState.unlockedModuleIds = { "M28" }
    truthy(validator(permanent), "earned M28 may stay outside this frozen run")
    for index, mutate in ipairs({
        function(p) p.metaState.unlockedModuleIds = { "M28", "M28" } end,
        function(p) p.metaState.unlockedModuleIds = { "M99" } end,
        function(p) p.metaState.unlockedModuleIds = { [2] = "M28" } end,
        function(p) p.runState.frozenUnlockPool.moduleIds[25] = "M28" end,
        function(p) p.runState.shopState.offers.module = "M28" end,
        function(p) p.runState.modules = { { moduleId = "M28", paidGold = 12, growth = 0 } } end,
        function(p) p.runState.acquiredModuleIds.M28 = true end,
    }) do
        local invalid = liveCheckpoint("SHOP", "runStart")
        mutate(invalid)
        equal(validator(invalid), nil, "current M28 invalid " .. index)
    end
    local lawful = Json.decode(Json.encode(permanent))
    lawful.runState.frozenUnlockPool.moduleIds[#lawful.runState.frozenUnlockPool.moduleIds + 1] = "M28"
    lawful.runState.shopState.offers.module = "M28"
    truthy(validator(lawful))
    lawful.runState.shopState.offers.module = nil
    lawful.runState.shopState.soldOut.module = true
    lawful.runState.modules = { { moduleId = "M28", paidGold = 12, growth = 0 } }
    lawful.runState.acquiredModuleIds.M28 = true
    truthy(validator(lawful))
    lawful.metaState.unlockedModuleIds = {}
    equal(validator(lawful), nil)
end)

test("M43 T08 I28 locked unlocked installed sold and frozen pools migrate with load writes zero", function()
    for _, variant in ipairs({ "locked", "excluded", "offer", "installed", "sold" }) do
        local payload = currentW07Checkpoint("i28-" .. variant)
        payload.runState.contentVersion = "DR-MOD-I28-r1"
        local run = payload.runState
        run.gold = 99
        payload.metaState.unlockedModuleIds = variant == "locked" and {} or { "M28" }
        if variant ~= "locked" and variant ~= "excluded" then
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds + 1] = "M28"
        end
        if variant == "offer" then run.shopState.offers.module = "M28" end
        if variant == "installed" or variant == "sold" then
            run.acquiredModuleIds.M28 = true
            if variant == "installed" then run.modules[#run.modules + 1] = { moduleId = "M28", paidGold = 12, growth = 0 } end
        end
        local storage = MemoryStorage()
        writeEnvelope(storage, "save-b.json", 34, "DR-MOD-I28-r1", payload, Save.adler32, "adler32-v1-test-fixture")
        local bytes = storage.files["save-b.json"]
        local save = newValidatedSave(storage)
        local loaded = save:loadCheckpoint()
        equal(loaded.status, "migrated", variant)
        equal(storage.writes, 0)
        equal(storage.files["save-b.json"], bytes)
        local expected = Json.decode(Json.encode(payload))
        expected.runState.contentVersion = LIVE_DEFS.version
        equal(Json.encode(loaded.payload), Json.encode(expected), "I28 whole payload preservation " .. variant)
        equal(contains(loaded.payload.metaState.unlockedModuleIds, "M43"), false)
        equal(save:commitCheckpoint(loaded.payload).status, "committed")
        equal(save:loadCheckpoint().payload.runState.contentVersion, LIVE_DEFS.version)
        equal(storage.files["save-b.json"], bytes)
        io.write("FIXTURE M43 T08 version=DR-MOD-I28-r1 variant=", variant, " loadWrites=0 snapshotExact=true\n")
    end
end)

test("M43 T09 frozen I28 rejects every future M43 reference without disk mutation", function()
    local mutators = {
        function(p) p.metaState.unlockedModuleIds = { "M43" } end,
        function(p) p.runState.frozenUnlockPool.moduleIds[25] = "M43" end,
        function(p) p.runState.shopState.offers.module = "M43" end,
        function(p) p.runState.modules = { { moduleId = "M43", paidGold = 12, growth = 0 } } end,
        function(p) p.runState.acquiredModuleIds.M43 = true end,
    }
    for index, mutate in ipairs(mutators) do
        local payload = currentW07Checkpoint("future-m43")
        payload.runState.contentVersion = "DR-MOD-I28-r1"
        mutate(payload)
        local storage = MemoryStorage()
        writeEnvelope(storage, "save-b.json", 34, "DR-MOD-I28-r1", payload, Save.adler32, "adler32-v1-test-fixture")
        local bytes = storage.files["save-b.json"]
        equal(newValidatedSave(storage):loadCheckpoint().status, "corrupt", "future reference " .. index)
        equal(storage.writes, 0)
        equal(storage.files["save-b.json"], bytes)
    end
end)

test("M43 T09 current M28 M43 rights pool acquisition and tower guards stay active", function()
    local validator = Save.createLivePayloadValidator(LIVE_DEFS)
    for _, id in ipairs({ "M28", "M43" }) do
        local excluded = currentW07Checkpoint("excluded-right")
        excluded.metaState.unlockedModuleIds = { id }
        truthy(validator(excluded))
        local pooled = Json.decode(Json.encode(excluded))
        pooled.runState.frozenUnlockPool.moduleIds[#pooled.runState.frozenUnlockPool.moduleIds + 1] = id
        pooled.runState.shopState.offers.module = id
        truthy(validator(pooled))
        local installed = Json.decode(Json.encode(pooled))
        installed.runState.shopState.offers.module = "M02"
        installed.runState.modules[#installed.runState.modules + 1] = { moduleId = id, paidGold = 12, growth = 0 }
        installed.runState.acquiredModuleIds[id] = true
        truthy(validator(installed))
        for index, mutate in ipairs({
            function(p) p.metaState.unlockedModuleIds = {} end,
            function(p) table.remove(p.runState.frozenUnlockPool.moduleIds) end,
            function(p) p.runState.acquiredModuleIds[id] = nil end,
            function(p) p.runState.shopState.offers.module = id end,
            function(p) p.metaState.unlockedModuleIds = { id, id } end,
            function(p) p.metaState.unlockedModuleIds = { [2] = id } end,
            function(p) p.metaState.unlockedModuleIds = { "M99" } end,
            function(p) p.runState.baseModuleSlots = 1 end,
            function(p)
                p.runState.modules[2] = { moduleId = "M33", paidGold = 12, growth = 31 }
                p.runState.acquiredModuleIds.M33 = true
            end,
        }) do
            local invalid = Json.decode(Json.encode(installed))
            mutate(invalid)
            equal(validator(invalid), nil, id .. " guard " .. index)
            -- JSON cannot represent a Lua hole. Serialize its explicit null form
            -- after verifying the sparse Lua array, and reject that on disk too.
            if index == 6 then invalid.metaState.unlockedModuleIds = Json.array({ Json.null, id }) end
            local storage = MemoryStorage()
            writeLiveEnvelope(storage, "save-b.json", 34, invalid)
            local bytes = storage.files["save-b.json"]
            equal(newValidatedSave(storage):loadCheckpoint().status, "corrupt")
            equal(storage.writes, 0)
            equal(storage.files["save-b.json"], bytes)
        end
    end
    for _, version in ipairs({ "DR-TOWER-U2-r1", "DR-MOD-I28-r1", "DR-MOD-I43-r1" }) do
        local payload = currentW07Checkpoint("tower-guard")
        payload.runState.contentVersion = version
        payload.metaState.unlockedTowerIds = { "T02", "T03", "T04", "T05" }
        local storage = MemoryStorage()
        writeEnvelope(storage, "save-b.json", 34, version, payload, Save.adler32, "adler32-v1-test-fixture")
        equal(newValidatedSave(storage):loadCheckpoint().status, "corrupt", version .. " starting tower guard")
        equal(storage.writes, 0)
    end
end)

local failures = 0
for _, item in ipairs(tests) do
    local ok, failure = pcall(item.body)
    if ok then
        io.write("PASS ", item.name, "\n")
    else
        failures = failures + 1
        io.stderr:write("FAIL ", item.name, ": ", tostring(failure), "\n")
    end
end

io.write(string.format('WORKFLOW SUITE {"schemaVersion":1,"suite":"session","count":%d,"failures":%d}\n', #tests, failures))
if love and love.event then
    love.event.quit(failures > 0 and 1 or 0)
elseif failures > 0 then
    os.exit(1)
end
