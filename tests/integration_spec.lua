package.path = "./?.lua;./src/?.lua;" .. package.path

local Json = require("src.json")
local Save = require("src.save")
local Content = require("src.content")
local Game = require("src.game")
local View = require("src.view")
local Input = require("src.input")
local Shop = require("src.shop")
local Rng = require("src.rng")
local Rules = require("src.rules")

local tests = {}
local function test(name, body) tests[#tests + 1] = { name = name, body = body } end
local function equal(actual, expected, message)
    if actual ~= expected then error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function truthy(value, message) if not value then error(message or "expected truthy", 2) end end

local function memoryStore(defs)
    defs = defs or Content.create()
    local storage = { files = {}, writeCount = 0, writeAttempts = {} }
    function storage:read(path)
        if self.failReadPath == path then return nil, "injected readback failure", "read_error" end
        if self.files[path] == nil then return nil, "not found", "missing" end
        return self.files[path]
    end
    function storage:write(path, data)
        self.writeCount = self.writeCount + 1
        self.writeAttempts[#self.writeAttempts + 1] = { path = path, data = data }
        if self.writeMode == "fail_before" then return nil, "injected write failure" end
        self.files[path] = data
        if self.writeMode == "fail_readback" then self.failReadPath = path end
        return true
    end
    local checkpoint = Save.new({ storage = storage, contentVersion = defs.version, engineTarget = "love-11.5",
        checksum = Save.loveSha256(love.data), checksumName = "sha256",
        validatePayload = Save.createLivePayloadValidator(defs),
        migrations = Save.createRun002Migrations(defs) })
    return storage, checkpoint
end

local function newGame(options)
    options = options or {}
    local defs = Content.create()
    local storage, checkpoint = memoryStore(defs)
    local identitySerial = 0
    local function identityProvider()
        identitySerial = identitySerial + 1
        return { runId = "integration-run-" .. identitySerial, shopSeed = options.shopSeed or (203 + identitySerial) }
    end
    return Game.new({ checkpointStore = checkpoint, defs = defs, identityProvider = identityProvider,
        quitCallback = options.quitCallback }), storage, checkpoint
end

local function generation(checkpoint) return assert(checkpoint:loadCheckpoint().generation) end

local function finishStartedWave(game, waveIndex, resultKind, resultReason)
    local run = game:getState().runState
    return game:_commitBattleCompletion({
        waveId = string.format("W%02d", waveIndex), waveIndex = waveIndex, tick = waveIndex * 10,
        resultKind = resultKind or "wave_complete", resultReason = resultReason,
        hp = run.hp, leaks = 0, towerInstances = run.towerInstances,
    })
end

local function completeWave(game, waveIndex, resultKind, resultReason)
    truthy(game:startWave(), "wave start failed: W" .. tostring(waveIndex))
    return finishStartedWave(game, waveIndex, resultKind, resultReason)
end

local function reachResult(game, resultKind, resultReason)
    for waveIndex = 1, 14 do truthy(completeWave(game, waveIndex)) end
    truthy(completeWave(game, 15, resultKind or "victory", resultReason or "boss_killed"))
end

local function prepareSixTowerShop(game, gold)
    local candidate = game:getState().runState
    local types = { "T02", "T03", "T04", "T01" }
    for instanceId = 3, 6 do
        candidate.towerInstances[#candidate.towerInstances + 1] = {
            instanceId = instanceId, typeId = types[instanceId - 2], paidGold = 0,
            patchIds = {}, placement = nil, charge = 0, activated = false,
        }
    end
    candidate.nextInstanceId = 7
    candidate.gold = gold or 50
    truthy(game:_applyDurableRun(candidate, "transaction"))
end

local function close(actual, expected, tolerance, message)
    if math.abs(actual - expected) > (tolerance or 1e-9) then
        error((message or "values not close") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assembledUi(game)
    local view = View.new(game.defs)
    local input = Input.new(game, view)
    local function findAction(actionType, predicate)
        for _, button in ipairs(view.buttons) do
            if button.action and button.action.type == actionType
                and (not predicate or predicate(button.action, button)) then
                return button
            end
        end
        return nil
    end
    local function clickButton(actionType, predicate)
        local button = assert(findAction(actionType, predicate), "missing button " .. actionType)
        local ww, wh = love.graphics.getDimensions()
        local viewport = view:viewport(ww, wh)
        return input:mousepressed(viewport.x + (button.x + button.w / 2) * viewport.scale,
            viewport.y + (button.y + button.h / 2) * viewport.scale, 1)
    end
    local function visibleText()
        local values = {}
        for _, item in ipairs(view.texts) do values[#values + 1] = item.value end
        return table.concat(values, "\n")
    end
    return view, input, findAction, clickButton, visibleText
end

local function findTowerById(run, instanceId)
    for _, tower in ipairs(run.towerInstances or {}) do
        if tower.instanceId == instanceId then return tower end
    end
    return nil
end

local function countPlacedTowers(run)
    local count = 0
    for _, tower in ipairs(run.towerInstances or {}) do if tower.placement then count = count + 1 end end
    return count
end

local function installEightTowerM05Fixture(game)
    local candidate = game:getState().runState
    candidate.towerInstances = {}
    local types = { "T01", "T02", "T03", "T04" }
    for instanceId = 1, 8 do
        candidate.towerInstances[#candidate.towerInstances + 1] = {
            instanceId = instanceId, typeId = types[((instanceId - 1) % #types) + 1],
            paidGold = instanceId <= 2 and 0 or 9, patchIds = instanceId == 7 and { "P_DAMAGE" } or {},
            placement = { x = instanceId - 1, y = 0 }, charge = instanceId / 10, activated = true,
        }
    end
    candidate.nextInstanceId = 9
    candidate.modules = { { moduleId = "M05", paidGold = 16, growth = 0 } }
    candidate.acquiredModuleIds.M05 = true
    candidate.gold = 20
    truthy(game:_applyDurableRun(candidate, "transaction"))
end

local function assertVisibleFits(view, label)
    for _, scale in ipairs({ 1, 2, 3 }) do
        for _, button in ipairs(view.buttons) do
            truthy(view:buttonLabelFits(button, scale),
                string.format("%s button overflow at %dx: %s", label, scale, button.label))
            truthy(button.x >= 0 and button.y >= 0 and button.x + button.w <= View.WIDTH
                and button.y + button.h <= View.HEIGHT,
                string.format("%s button outside logical screen: %s", label, button.label))
        end
        for _, text in ipairs(view.texts) do
            truthy(view:textBlockFits(text, scale),
                string.format("%s text overflow at %dx: %s", label, scale, text.value))
        end
    end
end

local function findModuleEntry(run, moduleId)
    for _, entry in ipairs(run.modules or {}) do
        local currentId = type(entry) == "table" and (entry.moduleId or entry.id) or entry
        if currentId == moduleId then return entry end
    end
    return nil
end

local function writeShaEnvelope(storage, path, envelopeGeneration, contentVersion, payload)
    local payloadJson = Json.encode(payload)
    local checksum = Save.loveSha256(love.data)
    storage.files[path] = Json.encode({
        schemaVersion = 1,
        generation = envelopeGeneration,
        contentVersion = contentVersion,
        engineTarget = "love-11.5",
        checksumAlgorithm = "sha256",
        payloadJson = payloadJson,
        payloadChecksum = checksum(payloadJson),
    })
end

local function installM06PurchaseFixture(game)
    installEightTowerM05Fixture(game)
    local candidate = game:getState().runState
    candidate.gold = 40
    candidate.shopState.offers.module = "M06"
    candidate.shopState.soldOut.module = false
    candidate.acquiredModuleIds.M06 = nil
    truthy(game:_applyDurableRun(candidate, "transaction"))
end

local function selectM06RecallPair(game, view, input, findAction, clickButton)
    view:draw(game:getState())
    truthy(clickButton("select_offer", function(action) return action.kind == "module" end))
    view:draw(game:getState())
    local mapTarget = assert(findAction("toggle_purchase_recall", function(action, button)
        return action.instanceId == 1 and button.hitOnly == true
    end), "M06 map recall target missing")
    local width, height = love.graphics.getDimensions()
    local viewport = view:viewport(width, height)
    truthy(input:mousepressed(viewport.x + (mapTarget.x + mapTarget.w / 2) * viewport.scale,
        viewport.y + (mapTarget.y + mapTarget.h / 2) * viewport.scale, 1))
    truthy(clickButton("inventory_page", function(action) return action.kind == "next" end))
    view:draw(game:getState())
    truthy(clickButton("toggle_purchase_recall", function(action, button)
        return action.instanceId == 7 and button.hitOnly ~= true
    end))
    equal(#game:getState().purchaseDraft.selectedRecallTowerIds, 2)
end

test("new run is committed with SHA-256 before SHOP is exposed", function()
    local game, storage, checkpoint = newGame()
    equal(game:getState().phase, "SHOP")
    local loaded = checkpoint:loadCheckpoint()
    equal(loaded.status, "valid")
    local envelope = Json.decode(storage.files[loaded.path])
    equal(envelope.checksumAlgorithm, "sha256")
    truthy(envelope.payloadChecksum:match("^sha256:%x+$"))
end)

test("weighted seeded shop is deterministic, pure, and excludes acquired modules", function()
    local game = newGame()
    local run = game:getState().runState
    local options = {
        visitId = "S-test", frozenUnlockPool = run.frozenUnlockPool,
        acquiredModuleIds = {}, rngState = Rng.new(204):getState(),
    }
    local before = Json.encode(options)
    local first = Shop.createVisit(game.defs, options)
    local second = Shop.createVisit(game.defs, options)
    equal(Json.encode(first), Json.encode(second))
    equal(Json.encode(options), before, "shop generation must not mutate its source")
    equal(first.offers.tower, "T02")
    equal(first.offers.patch, "P_DAMAGE")
    truthy(game.defs.modulesById[first.offers.module], "seeded module offer must reference current content")
    local offeredByFrozenPool = false
    for _, moduleId in ipairs(run.frozenUnlockPool.moduleIds) do
        if moduleId == first.offers.module then offeredByFrozenPool = true break end
    end
    truthy(offeredByFrozenPool, "seeded module offer must come from the frozen run pool")

    local excluded = Shop.createVisit(game.defs, {
        visitId = "S-empty-module", frozenUnlockPool = {
            towerIds = run.frozenUnlockPool.towerIds,
            patchIds = run.frozenUnlockPool.patchIds,
            moduleIds = { "M01" },
        }, acquiredModuleIds = { M01 = true }, rngState = Rng.new(204):getState(),
    })
    equal(excluded.offers.module, nil)
    equal(excluded.soldOut.module, true)
end)

test("S00 close/reopen keeps visit and patch purchase targets an instance", function()
    local game, _, checkpoint = newGame()
    local visitId = game:getState().runState.shopState.visitId
    equal(game:closeShop().status, "applied")
    truthy(game:getState().notice:find("다시 열", 1, true), "initial S00 may promise same-visit reopen")
    equal(game:reopenShop().status, "applied")
    equal(game:getState().runState.shopState.visitId, visitId)
    truthy(game:selectTower(2))
    local beforeGeneration = generation(checkpoint)
    truthy(game:selectOffer("patch"))
    local draft = game:getState().purchaseDraft
    equal(draft.targetInstanceId, 2)
    equal(draft.patchCountBefore, 0)
    equal(draft.patchCountAfter, 1)
    close(draft.before.damage, 12)
    close(draft.after.damage, 13.8)
    equal(generation(checkpoint), beforeGeneration, "preview must not save")
    truthy(game:confirmPurchase())
    local towers = game:getState().runState.towerInstances
    equal(#towers[1].patchIds, 0)
    equal(towers[2].patchIds[1], "P_DAMAGE")
end)

test("tower and module drafts expose detail while cancel is fully inert", function()
    local game, _, checkpoint = newGame()
    local fixture = game:getState().runState
    fixture.shopState.offers.module = "M01"
    fixture.shopState.soldOut.module = false
    fixture.acquiredModuleIds.M01 = nil
    truthy(game:_applyDurableRun(fixture, "transaction"))
    local initial = game:getState()
    local initialGeneration = generation(checkpoint)
    truthy(game:selectOffer("tower"))
    local towerDraft = game:getState().purchaseDraft
    equal(towerDraft.newInstanceId, 3)
    equal(towerDraft.cost, 9)
    equal(game:getState().runState.gold, initial.runState.gold)
    equal(generation(checkpoint), initialGeneration)
    truthy(game:cancelPurchase())
    equal(game:getState().purchaseDraft, nil)
    equal(game:getState().runState.shopState.offers.tower, initial.runState.shopState.offers.tower)
    equal(generation(checkpoint), initialGeneration)

    truthy(game:selectOffer("module"))
    local moduleDraft = game:getState().purchaseDraft
    equal(moduleDraft.offerId, "M01")
    equal(moduleDraft.slotBefore, 0)
    equal(moduleDraft.slotAfter, 1)
    equal(moduleDraft.slotCapacity, 4)
    truthy(moduleDraft.effect:find("공격속도", 1, true))
    equal(generation(checkpoint), initialGeneration)
    truthy(game:confirmPurchase())
    equal(game:getState().runState.modules[1].moduleId, "M01")
    equal(generation(checkpoint), initialGeneration + 1)
end)

test("patch draft requires a stable instance target and revalidates on confirm", function()
    local game, _, checkpoint = newGame()
    local initialGeneration = generation(checkpoint)
    truthy(game:selectOffer("patch"))
    local disabled = game:getState().purchaseDraft
    equal(disabled.enabled, false)
    equal(disabled.error, "tower_target_required")
    local confirmed, reason = game:confirmPurchase()
    equal(confirmed, false)
    equal(reason, "tower_target_required")
    equal(generation(checkpoint), initialGeneration)
    truthy(game:selectTower(1))
    equal(game:getState().purchaseDraft.targetInstanceId, 1)
    truthy(game:selectTower(2))
    equal(game:getState().purchaseDraft.targetInstanceId, 2, "target update must use instanceId")
    truthy(game:cancelPurchase())
    equal(game:getState().selectedTowerId, 2, "cancel must preserve the bound target selection")
    equal(game:getState().runState.gold, 12)
    equal(game:getState().runState.shopState.offers.patch, "P_DAMAGE")
    equal(generation(checkpoint), initialGeneration)
    truthy(game:selectOffer("patch"))
    truthy(game:confirmPurchase())
    equal(game:getState().runState.towerInstances[2].patchIds[1], "P_DAMAGE")
end)

test("durable placement invalidates a patch draft whose M01 preview became stale", function()
    local game, _, checkpoint = newGame()
    local funded = game:getState().runState
    funded.gold = 40
    funded.shopState.offers.module = "M01"
    funded.shopState.soldOut.module = false
    funded.acquiredModuleIds.M01 = nil
    truthy(game:_applyDurableRun(funded, "transaction"))
    truthy(game:selectOffer("module"))
    truthy(game:confirmPurchase()) -- M01
    truthy(game:selectOffer("tower"))
    truthy(game:confirmPurchase()) -- T02 instance #3

    game:selectTower(1)
    truthy(game:placeSelected(3, 2))
    game:selectTower(3)
    truthy(game:selectOffer("patch"))
    local draft = game:getState().purchaseDraft
    equal(draft.targetInstanceId, 3)
    local selectedRevision = draft.selectedAtRevision
    close(draft.before.attackRate, 4, 1e-9, "M01 must be inactive before different-type adjacency")

    truthy(game:placeSelected(3, 3))
    local afterPlacement = game:getState()
    truthy(afterPlacement.stateRevision > selectedRevision)
    local currentTargetStats = assert(require("src.rules").projectStats(game.defs,
        afterPlacement.runState, 3))
    close(currentTargetStats.attackRate, 4.8, 1e-9, "M01 must activate after durable adjacent placement")
    local generationAfterPlacement = generation(checkpoint)
    local goldAfterPlacement = afterPlacement.runState.gold
    local offerAfterPlacement = afterPlacement.runState.shopState.offers.patch
    local patchCountAfterPlacement = #afterPlacement.runState.towerInstances[3].patchIds

    local confirmed, reason = game:confirmPurchase()
    equal(confirmed, false)
    equal(reason, "stale_purchase_revision")
    local rejected = game:getState()
    equal(rejected.runState.gold, goldAfterPlacement)
    equal(rejected.runState.shopState.offers.patch, offerAfterPlacement)
    equal(#rejected.runState.towerInstances[3].patchIds, patchCountAfterPlacement)
    equal(generation(checkpoint), generationAfterPlacement)

    truthy(game:selectOffer("patch"), "player can explicitly regenerate a current preview")
    local refreshed = game:getState().purchaseDraft
    close(refreshed.before.attackRate, 4.8, 1e-9)
    truthy(game:confirmPurchase())
    equal(game:getState().runState.towerInstances[3].patchIds[1], "P_DAMAGE")
end)

test("reroll cost progresses 2 then 4 then 6 and is durable", function()
    local game, _, checkpoint = newGame()
    truthy(game:rerollShop())
    equal(game:getState().runState.gold, 10)
    truthy(game:rerollShop())
    equal(game:getState().runState.gold, 6)
    truthy(game:rerollShop())
    equal(game:getState().runState.gold, 0)
    equal(checkpoint:loadCheckpoint().payload.runState.shopState.rerollCount, 3)
end)

test("prepare placement, fixed tick, speed and focus pause use the integrated owners", function()
    local game = newGame()
    game:closeShop()
    game:selectTower(1)
    truthy(game:placeSelected(3, 2))
    truthy(game:startWave())
    game:update(1 / 120)
    equal(game:getState().battle.tick, 0)
    game:update(1 / 120)
    equal(game:getState().battle.tick, 1)
    truthy(game:setSpeed(2))
    game:onFocus(false)
    local tick = game:getState().battle.tick
    game:update(1)
    equal(game:getState().battle.tick, tick)
    game:onFocus(true)
    equal(game:getState().paused, true, "focus gain must not auto resume")
    truthy(game:resumeAll())
end)

local function startedGame(speed)
    local game = newGame()
    game:closeShop()
    game:selectTower(1)
    truthy(game:placeSelected(3, 2))
    truthy(game:startWave())
    truthy(game:setSpeed(speed or 1))
    return game
end

test("fixed-step debt is partition invariant and max-eight catch-up never drops ticks", function()
    local smooth1, chunky1 = startedGame(1), startedGame(1)
    for _ = 1, 60 do smooth1:update(1 / 60) end
    for _ = 1, 10 do chunky1:update(0.1) end
    equal(smooth1:getState().battle.tick, 60)
    equal(chunky1:getState().battle.tick, 60)

    local smooth2, chunky2 = startedGame(2), startedGame(2)
    for _ = 1, 60 do smooth2:update(1 / 60) end
    for _ = 1, 10 do chunky2:update(0.1) end
    equal(chunky2:getState().battle.tick, 80, "each update must execute at most eight steps")
    for _ = 1, 5 do chunky2:update(0) end
    equal(smooth2:getState().battle.tick, 120)
    equal(chunky2:getState().battle.tick, 120, "preserved debt must catch up without hidden skip")

    local stalled = startedGame(1)
    stalled:update(1)
    equal(stalled:getState().battle.tick, 8)
    close(stalled.accumulator, 1 - 8 / 60, 1e-9)
    stalled:update(0)
    equal(stalled:getState().battle.tick, 16)
    close(stalled.accumulator, 1 - 16 / 60, 1e-9)
end)

test("user pause and focus loss discard partial tick debt", function()
    local game = startedGame(1)
    game:update(0.01)
    truthy(game.accumulator > 0)
    truthy(game:togglePause())
    equal(game.accumulator, 0)
    truthy(game:togglePause())
    game:update(1 / 120)
    equal(game:getState().battle.tick, 0)
    game:update(1 / 120)
    equal(game:getState().battle.tick, 1)
    game:update(0.01)
    game:onFocus(false)
    equal(game.accumulator, 0)
    game:onFocus(true)
    truthy(game:resumeAll())
    game:update(1 / 120)
    equal(game:getState().battle.tick, 1)
end)

test("actual LÖVE input path maps integer-scaled mouse coordinates and captures UI before map", function()
    local game = newGame()
    local view = View.new(game.defs)
    local input = Input.new(game, view)
    view:draw(game:getState())
    local ww, wh = love.graphics.getDimensions()
    local viewport = view:viewport(ww, wh)
    local function click(logicalX, logicalY)
        return input:mousepressed(viewport.x + logicalX * viewport.scale + 1,
            viewport.y + logicalY * viewport.scale + 1, 1)
    end
    local function clickButton(actionType, kind)
        local button = assert(view:findButton(actionType, kind), "missing button " .. actionType)
        return click(button.x + button.w / 2, button.y + button.h / 2)
    end
    local function visibleText()
        local values = {}
        for _, item in ipairs(view.texts) do values[#values + 1] = item.value end
        return table.concat(values, "\n")
    end
    truthy(visibleText():find("먼저 무료 기본 포탑", 1, true), "initial action guidance must be visible")
    truthy(clickButton("select_tower"), "inventory button must consume input")
    view:draw(game:getState())
    truthy(visibleText():find("#1 선택", 1, true), "selection and placement guidance must be visible")
    truthy(click(View.MAP_X + 3 * View.CELL + 3, View.MAP_Y + 2 * View.CELL + 3))
    local placement = game:getState().runState.towerInstances[1].placement
    equal(placement.x, 3)
    equal(placement.y, 2)
    view:draw(game:getState())
    truthy(visibleText():find("첫 포탑 배치 완료", 1, true), "next free-tower action must be visible")
    truthy(clickButton("close_shop"), "shop close button must consume input")
    equal(game:getState().phase, "PREPARE")
    view:draw(game:getState())
    truthy(visibleText():find("W01 시작", 1, true), "prepare-to-start action must be visible")
    local lx = view:windowToLogical(viewport.x - 1, viewport.y, ww, wh)
    equal(lx, nil, "letterbox click must be rejected")
end)

test("actual UI purchase selection requires confirm and cancel preserves generation", function()
    local game, _, checkpoint = newGame()
    local view = View.new(game.defs)
    local input = Input.new(game, view)
    local ww, wh = love.graphics.getDimensions()
    local viewport = view:viewport(ww, wh)
    local function click(x, y)
        return input:mousepressed(viewport.x + x * viewport.scale + 1,
            viewport.y + y * viewport.scale + 1, 1)
    end
    local function clickButton(actionType, kind)
        local button = assert(view:findButton(actionType, kind), "missing button " .. actionType)
        return click(button.x + button.w / 2, button.y + button.h / 2)
    end
    local before = generation(checkpoint)
    view:draw(game:getState())
    truthy(clickButton("select_offer", "tower"), "tower offer must be captured")
    equal(game:getState().runState.gold, 12)
    equal(generation(checkpoint), before)
    view:draw(game:getState())
    truthy(clickButton("cancel_purchase"), "cancel must be captured")
    equal(game:getState().purchaseDraft, nil)
    equal(generation(checkpoint), before)
    view:draw(game:getState())
    truthy(clickButton("select_offer", "tower"))
    view:draw(game:getState())
    truthy(clickButton("confirm_purchase"), "confirm must be captured")
    equal(game:getState().runState.gold, 3)
    equal(generation(checkpoint), before + 1)
end)

test("Korean UI uses native-resolution glyphs and actionable labels fit all integer targets", function()
    local game = newGame()
    local fixture = game:getState().runState
    fixture.shopState.offers.module = "M01"
    fixture.shopState.soldOut.module = false
    fixture.acquiredModuleIds.M01 = nil
    truthy(game:_applyDurableRun(fixture, "transaction"))
    local view = View.new(game.defs)
    local function assertLocalLayout(label)
        for _, scale in ipairs({ 1, 2, 3 }) do
            local inventoryGuide = assert(view:findTextRole("inventory_guide"), "inventory guide text missing")
            local firstTower = assert(view:findButton("select_tower"), "first tower control missing")
            local guideBounds = view:textBlockBounds(inventoryGuide, scale)
            equal(guideBounds.lineCount, 1,
                string.format("%s inventory guide must remain one line at %dx", label, scale))
            truthy(guideBounds.bottom <= firstTower.y * scale,
                string.format("%s inventory guide overlaps first tower control at %dx", label, scale))
            local notice = assert(view:findTextRole("notice"), "notice text missing")
            local phaseHeader = assert(view:findTextRole("phase_header"), "phase header text missing")
            truthy(view:textBlockBounds(notice, scale).bottom <= view:textBlockBounds(phaseHeader, scale).top,
                string.format("%s notice overlaps panel first row at %dx", label, scale))
        end
    end
    view:draw(game:getState())
    truthy(view.fontInfo.hasKorean, "selected font must contain Korean glyphs")
    truthy(view.fontInfo.path and view.fontInfo.path:lower():find("malgun.ttf", 1, true),
        "Windows target must prefer malgun.ttf")
    for _, scale in ipairs({ 1, 2, 3 }) do
        for _, button in ipairs(view.buttons) do
            truthy(view:buttonLabelFits(button, scale),
                string.format("button label overflow at %dx: %s", scale, button.label))
        end
        for _, text in ipairs(view.texts) do
            truthy(view:textBlockFits(text, scale),
                string.format("text block overflow at %dx: %s", scale, text.value))
        end
    end
    assertLocalLayout("shop")
    local labels = {}
    for _, button in ipairs(view.buttons) do labels[#labels + 1] = button.label end
    local joined = table.concat(labels, "|")
    truthy(joined:find("속사 포탑 9G", 1, true))
    truthy(joined:find("출력 보강 4G", 1, true))
    truthy(joined:find("교차 배치 8G", 1, true))
    equal(joined:find("T02", 1, true), nil)
    equal(joined:find("P_DAMAGE", 1, true), nil)
    equal(joined:find("M01", 1, true), nil)
    local visible = {}
    for _, text in ipairs(view.texts) do visible[#visible + 1] = text.value end
    local visibleText = table.concat(visible, "|")
    truthy(visibleText:find("상점 · 생명", 1, true), "shop phase must use Korean primary label")
    equal(visibleText:find("SHOP · 생명", 1, true), nil)

    local expensiveReroll = game:getState()
    expensiveReroll.runState.shopState.rerollCount = 4
    expensiveReroll.rerollPreview = assert(require("src.rules").previewReroll(expensiveReroll.runState))
    view:draw(expensiveReroll)
    local reroll = assert(view:findButton("reroll"), "reroll control missing")
    equal(reroll.label, "바꾸기 10G")
    for _, scale in ipairs({ 1, 2, 3 }) do
        truthy(view:buttonLabelFits(reroll, scale), "10G+ reroll label must fit")
        local windowWidth, windowHeight = View.WIDTH * scale, View.HEIGHT * scale
        local viewport = view:viewport(windowWidth, windowHeight)
        local logicalX, logicalY = view:windowToLogical(
            viewport.x + (reroll.x + reroll.w / 2) * viewport.scale,
            viewport.y + (reroll.y + reroll.h / 2) * viewport.scale,
            windowWidth, windowHeight)
        local action = view:hitTest(logicalX, logicalY)
        equal(action and action.type, "reroll", "10G reroll click target missing at " .. tostring(scale) .. "x")
    end

    game:closeShop()
    truthy(game:selectTower(2))
    truthy(game:placeSelected(3, 2))
    view:draw(game:getState())
    assertLocalLayout("prepare with long notice")
    visible = {}
    for _, text in ipairs(view.texts) do visible[#visible + 1] = text.value end
    visibleText = table.concat(visible, "|")
    truthy(visibleText:find("전투 준비 · 생명", 1, true), "prepare phase must use Korean primary label")
    equal(visibleText:find("PREPARE · 생명", 1, true), nil)
end)

test("paused combat rejects mouse placement without queueing or delayed placement", function()
    local game = newGame()
    game:closeShop()
    game:selectTower(1)
    truthy(game:placeSelected(3, 2))
    game:selectTower(2)
    truthy(game:startWave())
    local view = View.new(game.defs)
    local input = Input.new(game, view)
    local ww, wh = love.graphics.getDimensions()
    local viewport = view:viewport(ww, wh)
    local function mapClick(x, y)
        view:draw(game:getState())
        return input:mousepressed(viewport.x + (View.MAP_X + x * View.CELL + 3) * viewport.scale + 1,
            viewport.y + (View.MAP_Y + y * View.CELL + 3) * viewport.scale + 1, 1)
    end
    truthy(input:keypressed("p", false))
    equal(mapClick(5, 7), false)
    equal(#game.pendingBattleCommands, 0)
    truthy(input:keypressed("p", false))
    game:update(1 / 60)
    equal(game:getState().battle.towerInstances[2].placement, nil)

    input:focus(false)
    equal(mapClick(5, 7), false)
    equal(#game.pendingBattleCommands, 0)
    input:focus(true)
    truthy(game:resumeAll())
    game:update(1 / 60)
    equal(game:getState().battle.towerInstances[2].placement, nil)
end)

test("live validator recovers older generation from correct-checksum semantic corruption", function()
    local game, storage, checkpoint = newGame()
    local valid = checkpoint:loadCheckpoint()
    local payload = valid.payload
    payload.runState.mapId = "MISSING"
    local payloadJson = Json.encode(payload)
    local target = valid.path == "save-a.json" and "save-b.json" or "save-a.json"
    storage.files[target] = Json.encode({ schemaVersion = 1, generation = valid.generation + 1,
        contentVersion = game.defs.version, engineTarget = "love-11.5", checksumAlgorithm = "sha256",
        payloadJson = payloadJson, payloadChecksum = Save.loveSha256(love.data)(payloadJson) })
    local loaded = checkpoint:loadCheckpoint()
    equal(loaded.status, "recovered")
    equal(loaded.payload.runState.mapId, "M01")
    local restored = Game.new({ checkpointStore = checkpoint, defs = game.defs })
    equal(restored:getState().runState.mapId, "M01")
    truthy(restored:getState().notice:find("복구", 1, true))
end)

test("W01-W15 progression opens data-driven shops and closes each visit on combat start", function()
    local game = newGame()
    local view = View.new(game.defs)
    local visits = { [3] = "S01", [6] = "S02", [9] = "S03", [12] = "S04" }
    game:closeShop()
    for waveIndex = 1, 3 do truthy(completeWave(game, waveIndex)) end
    local state = game:getState()
    equal(state.phase, "SHOP")
    equal(state.runState.shopState.visitId, "S01")
    view:draw(state)
    local shopText = {}
    for _, item in ipairs(view.texts) do shopText[#shopText + 1] = item.value end
    shopText = table.concat(shopText, "\n")
    truthy(shopText:find("W04", 1, true) and shopText:find("W05", 1, true)
        and shopText:find("W06", 1, true), "S01 must preview the next three real waves")

    equal(game:closeShop().status, "applied")
    equal(game:reopenShop().status, "applied")
    truthy(game:startWave())
    equal(game:getState().runState.shopState.accessOpen, false)
    local reopened, reopenReason = game:reopenShop()
    equal(reopened.status, "rejected")
    equal(reopenReason, nil)
    equal(reopened.error, "shop_visit_closed")
    truthy(finishStartedWave(game, 4))

    for waveIndex = 5, 14 do
        truthy(completeWave(game, waveIndex))
        if visits[waveIndex] then
            local shopState = game:getState()
            equal(shopState.phase, "SHOP")
            equal(shopState.runState.shopState.visitId, visits[waveIndex])
            equal(shopState.runState.shopState.accessOpen, true)
            equal(game:closeShop().status, "applied")
            equal(game:reopenShop().status, "applied")
        end
    end

    state = game:getState()
    equal(state.phase, "PREPARE")
    equal(state.runState.nextWaveIndex, 15)
    view:draw(state)
    local start = assert(view:findButton("start_wave"), "W15 start control missing")
    equal(start.enabled, true)
    equal(start.label, "W15 시작")
    truthy(game:toggleBossRules())
    view:draw(game:getState())
    local bossText = {}
    for _, item in ipairs(view.texts) do bossText[#bossText + 1] = item.value end
    bossText = table.concat(bossText, "\n")
    truthy(bossText:find("체력 1200", 1, true))
    truthy(bossText:find("패배 우선", 1, true))

    truthy(completeWave(game, 15, "victory", "boss_killed"))
    state = game:getState()
    equal(state.phase, "RESULT")
    equal(state.runState.result.kind, "victory")
    equal(state.runState.result.reason, "boss_killed")
end)

test("wave detail projects ordered schedules without changing run RNG pause or save", function()
    local game, _, checkpoint = newGame()
    game:closeShop()
    for waveIndex = 1, 3 do truthy(completeWave(game, waveIndex)) end
    local view = View.new(game.defs)
    local input = Input.new(game, view)
    local expected = {
        [4] = {
            { "G01", "A", "E02", 8, 0, 54, "고속" },
            { "G02", "B", "E04", 16, 120, 21, "군집" },
            { "G03", "A", "E01", 8, 360, 60, nil },
        },
        [5] = {
            { "G01", "A", "E03", 3, 0, 210, "고체력" },
            { "G02", "B", "E02", 8, 120, 54, "고속" },
            { "G03", "B", "E04", 16, 300, 18, "군집" },
        },
        [6] = {
            { "G01", "A", "E01", 12, 0, 48, nil },
            { "G02", "B", "E03", 3, 60, 180, "고체력" },
            { "G03", "A", "E04", 20, 300, 15, "군집" },
        },
        [15] = {
            { "G01", "A", "E05", 1, 0, 60, "보스" },
            { "G02", "B", "E01", 16, 60, 33, nil },
            { "G03", "A", "E04", 24, 180, 12, "군집" },
            { "G04", "B", "E02", 12, 300, 24, "고속" },
            { "G05", "A", "E03", 4, 240, 48, "고체력" },
        },
    }
    local function assertSchedule(index, state)
        local schedule = assert(view:waveSchedule(index))
        equal(#schedule.rows, #expected[index], "group count differs for W" .. index)
        for order, values in ipairs(expected[index]) do
            local row = schedule.rows[order]
            equal(row.order, order)
            equal(row.groupId, values[1])
            equal(row.entranceId, values[2])
            equal(row.enemyId, values[3])
            equal(row.count, values[4])
            equal(row.firstTick, values[5])
            equal(row.intervalTicks, values[6])
            equal(row.special, values[7])
        end
        assert(view:setWaveDetail(index, state))
        view:draw(state)
        local visibleRows = {}
        local legend = assert(view:findTextRole("wave_detail_legend"))
        truthy(legend.value:find("정의 순서", 1, true), "group ids must be labeled as definition order")
        local overlapNote = assert(view:findTextRole("wave_overlap_note"))
        truthy(overlapNote.value:find("서로 겹칠 수 있음", 1, true), "overlapping spawn schedules need explicit copy")
        for _, text in ipairs(view.texts) do
            if text.role == "wave_group" then visibleRows[#visibleRows + 1] = text end
        end
        equal(#visibleRows, #expected[index], "all ordered groups must be visible for W" .. index)
        for order, text in ipairs(visibleRows) do
            local values = expected[index][order]
            local enemyName = view:waveSchedule(index).rows[order].enemyName
            local exact = string.format("%s %s · %s×%d · %d/%dt", values[1], values[2],
                enemyName, values[4], values[5], values[6])
            truthy(text.value:find(exact, 1, true), "visible schedule lost exact fields: " .. exact)
            if values[7] then truthy(text.value:find("★" .. values[7], 1, true)) end
        end
        for _, scale in ipairs({ 1, 2, 3 }) do
            for _, button in ipairs(view.buttons) do
                truthy(view:buttonLabelFits(button, scale),
                    string.format("W%02d detail button overflow at %dx", index, scale))
            end
            for _, text in ipairs(view.texts) do
                truthy(view:textBlockFits(text, scale),
                    string.format("W%02d detail text overflow at %dx: %s", index, scale, text.value))
                if text.role == "wave_group" then
                    truthy(view:textBlockBounds(text, scale).bottom <= 242 * scale,
                        string.format("W%02d group overlaps panel boundary at %dx", index, scale))
                end
            end
        end
    end

    local shopState = game:getState()
    view:draw(shopState)
    for _, waveId in ipairs({ "W04", "W05", "W06" }) do
        truthy(view:findButton("wave_detail", waveId), "SHOP preview lacks " .. waveId .. " detail action")
    end
    local ww, wh = love.graphics.getDimensions()
    local viewport = view:viewport(ww, wh)
    local beforeRun = Json.encode(shopState.runState)
    local beforeGeneration = generation(checkpoint)
    local detailButton = assert(view:findButton("wave_detail", "W04"))
    truthy(input:mousepressed(viewport.x + (detailButton.x + detailButton.w / 2) * viewport.scale,
        viewport.y + (detailButton.y + detailButton.h / 2) * viewport.scale, 1))
    equal(Json.encode(game:getState().runState), beforeRun)
    equal(generation(checkpoint), beforeGeneration)
    view:draw(game:getState())
    local back = assert(view:findButton("wave_detail_back"), "detail must have an explicit back action")
    truthy(input:mousepressed(viewport.x + (back.x + back.w / 2) * viewport.scale,
        viewport.y + (back.y + back.h / 2) * viewport.scale, 1))
    equal(view:hasWaveDetail(), false)

    for index = 4, 6 do assertSchedule(index, game:getState()) end
    equal(generation(checkpoint), beforeGeneration, "W04-W06 detail browsing must not save")
    view:clearWaveDetail()
    for waveIndex = 4, 14 do truthy(completeWave(game, waveIndex)) end
    local prepare15 = game:getState()
    equal(prepare15.phase, "PREPARE")
    local generation15 = generation(checkpoint)
    assertSchedule(15, prepare15)
    local schedule15 = assert(view:waveSchedule(15))
    equal(schedule15.rows[4].firstTick, 300)
    equal(schedule15.rows[5].firstTick, 240)
    truthy(schedule15.rows[5].firstTick < schedule15.rows[4].firstTick,
        "definition order must not be mistaken for chronological spawn order")
    equal(Json.encode(game:getState().runState), Json.encode(prepare15.runState), "detail must not mutate PREPARE")
    equal(generation(checkpoint), generation15, "W15 detail browsing must not save")
    equal(game:getState().paused, false)
end)

test("RESULT new-run confirmation is cancellable and retries the exact durable draft", function()
    local game, storage, checkpoint = newGame()
    reachResult(game, "defeat", "boss_escaped")
    equal(game:getState().phase, "RESULT")
    local view = View.new(game.defs)
    view:draw(game:getState())
    truthy(view:findButton("request_new_run"), "RESULT must expose the new-run action")
    equal(view:findButton("start_wave"), nil)
    equal(view:findButton("select_offer"), nil)
    for _, button in ipairs(view.buttons) do
        if button.action.type == "select_tower" or button.action.type == "inventory_page" then
            equal(button.enabled, false, "RESULT inventory is read-only")
        end
    end
    local resultRunId = game:getState().runState.runId
    local resultGeneration = generation(checkpoint)
    local metaBefore = Json.encode(game:getState().metaState)

    truthy(game:requestNewRun())
    local cancelledRunId = game:getState().newRunDraft.runId
    equal(generation(checkpoint), resultGeneration, "request must be presentation-only")
    truthy(game:cancelNewRun())
    equal(game:getState().runState.runId, resultRunId)
    equal(generation(checkpoint), resultGeneration, "cancel must not save")

    truthy(game:requestNewRun())
    local retryRunId = game:getState().newRunDraft.runId
    truthy(retryRunId ~= cancelledRunId, "a cancelled identity must not be silently reused")
    storage.writeMode = "fail_before"
    local confirmed, reason = game:confirmNewRun()
    equal(confirmed, false)
    equal(reason, "injected write failure")
    equal(game:getState().phase, "SAVE_ERROR")
    equal(game:getState().runState.runId, resultRunId, "failed save must retain RESULT run")
    equal(game:getState().newRunDraft.runId, retryRunId, "retry must retain the exact draft")
    equal(generation(checkpoint), resultGeneration)

    storage.writeMode = nil
    equal(game:retrySave().status, "applied")
    local restarted = game:getState()
    equal(restarted.phase, "SHOP")
    equal(restarted.runState.runId, retryRunId)
    equal(restarted.runState.nextWaveIndex, 1)
    equal(restarted.newRunDraft, nil)
    equal(Json.encode(restarted.metaState), metaBefore, "new run must preserve meta progress")
end)

test("combat-start retry retains the pending wave across both repeated save failures", function()
    for _, mode in ipairs({ "fail_before", "fail_readback" }) do
        local game, storage, checkpoint = newGame()
        local beforeRun = Json.encode(game:getState().runState)
        local beforeGeneration = generation(checkpoint)
        local previousFiles = Content.clone(storage.files)
        storage.writeMode = mode
        equal(game:startWave(), false)
        equal(game:getState().phase, "SAVE_ERROR")
        equal(game.battle, nil, "failed start must not create a battle")
        equal(game.pendingSavePresentation.kind, "combat_start")
        equal(game.pendingSavePresentation.waveId, "W01")
        equal(Json.encode(game:getState().runState), beforeRun, "failed start must preserve committed run")
        for path, bytes in pairs(previousFiles) do
            equal(storage.files[path], bytes, "failed start must preserve the previous saved generation")
        end
        local pending = game.session.pending
        equal(game:retrySave().status, "save_error")
        equal(game.session.pending, pending, "repeat failure must retain the exact pending checkpoint")
        equal(game.battle, nil)
        equal(Json.encode(game:getState().runState), beforeRun)
        for path, bytes in pairs(previousFiles) do equal(storage.files[path], bytes) end
        game:update(1)
        equal(game.battle, nil, "failed retry must not advance combat")
        storage.writeMode, storage.failReadPath = nil, nil
        equal(game:retrySave().status, "applied")
        equal(game:getState().phase, "COMBAT")
        equal(game:getState().battle.waveId, "W01")
        equal(game:getState().battle.tick, 0)
        equal(game.pendingSavePresentation, nil)
        equal(generation(checkpoint), beforeGeneration + 1)
        truthy(game.notice:find("W01", 1, true))
        game:update(1 / 60)
        equal(game:getState().battle.tick, 1, "successful retry must advance the actual battle")
    end
end)

test("combat-start retry success cannot be repeated to recreate battle or write", function()
    local game, storage, checkpoint = newGame()
    storage.writeMode = "fail_before"
    equal(game:startWave(), false)
    storage.writeMode = nil
    equal(game:retrySave().status, "applied")
    game:update(1 / 60)
    local battle = game.battle
    local tick = game:getState().battle.tick
    local writes, committedGeneration = storage.writeCount, generation(checkpoint)
    equal(game:retrySave().status, "rejected")
    equal(game.battle, battle, "a duplicate retry must keep the same live battle")
    equal(game:getState().battle.tick, tick)
    equal(storage.writeCount, writes)
    equal(generation(checkpoint), committedGeneration)
    game:update(1 / 60)
    equal(game:getState().battle.tick, tick + 1)
end)

test("combat-start retry restores the actual later wave and committed tower setup", function()
    local game, storage, checkpoint = newGame()
    game:selectTower(1)
    truthy(game:placeSelected(3, 2))
    truthy(completeWave(game, 1))
    truthy(completeWave(game, 2))
    local before = game:getState().runState
    local towersBefore = Json.encode(before.towerInstances)
    local poolBefore = Json.encode(before.frozenUnlockPool)
    local beforeGeneration = generation(checkpoint)
    storage.writeMode = "fail_readback"
    equal(game:startWave(), false)
    equal(game.pendingSavePresentation.waveId, "W03")
    storage.writeMode, storage.failReadPath = nil, nil
    equal(game:retrySave().status, "applied")
    local state = game:getState()
    equal(state.battle.waveId, "W03")
    equal(state.runState.nextWaveIndex, 3)
    equal(state.battle.tick, 0)
    equal(Json.encode(state.runState.towerInstances), towersBefore)
    equal(Json.encode(state.runState.frozenUnlockPool), poolBefore)
    before.shopState.accessOpen = false
    equal(Json.encode(state.runState.shopState), Json.encode(before.shopState), "start must only close the existing shop access")
    equal(generation(checkpoint), beforeGeneration + 1)
    equal(game.purchaseDraft, nil)
    game:update(1 / 60)
    equal(game:getState().battle.tick, 1)
end)

test("combat-start retry UI recovers after safe-exit cancel and keeps abandon inert", function()
    for _, mode in ipairs({ "fail_before", "fail_readback" }) do
        local game, storage = newGame()
        local view, input, find, click, text = assembledUi(game)
        view:draw(game:getState())
        truthy(click("close_shop"))
        view:draw(game:getState())
        storage.writeMode = mode
        truthy(click("start_wave"))
        equal(game:getState().phase, "SAVE_ERROR")
        view:draw(game:getState())
        truthy(find("retry_save"))
        truthy(click("request_safe_exit"))
        view:draw(game:getState())
        truthy(click("cancel_safe_exit"))
        view:draw(game:getState())
        truthy(click("retry_save"))
        equal(game:getState().phase, "SAVE_ERROR")
        equal(game.battle, nil)
        storage.writeMode, storage.failReadPath = nil, nil
        view:draw(game:getState())
        truthy(click("retry_save"))
        view:draw(game:getState())
        equal(game:getState().phase, "COMBAT")
        equal(game:getState().battle.waveId, "W01")
        truthy(text():find("W01", 1, true))
        equal(find("retry_save"), nil)
        game:update(1 / 60)
        equal(game:getState().battle.tick, 1)
    end
    local quitCalls = 0
    local game, storage = newGame({ quitCallback = function() quitCalls = quitCalls + 1 end })
    storage.writeMode = "fail_before"
    equal(game:startWave(), false)
    local writes = storage.writeCount
    truthy(game:requestSafeExit())
    truthy(game:confirmSafeExit())
    equal(quitCalls, 1)
    equal(game.pendingSavePresentation, nil)
    equal(game.battle, nil)
    equal(game:getState().phase, "TITLE")
    equal(storage.writeCount, writes)
end)

test("SAVE_ERROR offers explicit warned exit without writing and preserves retry candidate", function()
    local quitCalls = 0
    local game, storage, checkpoint = newGame({ quitCallback = function(code)
        equal(code, 0)
        quitCalls = quitCalls + 1
    end })
    local requested, guardReason = game:requestSafeExit()
    equal(requested, false)
    equal(guardReason, "save_error_required")
    local confirmed, confirmGuard = game:confirmSafeExit()
    equal(confirmed, false)
    equal(confirmGuard, "save_error_required")

    storage.writeMode = "fail_before"
    truthy(game:selectOffer("tower"))
    local purchased, purchaseReason = game:confirmPurchase()
    equal(purchased, false)
    equal(purchaseReason, "save_failed")
    equal(game:getState().phase, "SAVE_ERROR")
    local failedGeneration = generation(checkpoint)
    local writesAfterFailure = storage.writeCount
    local view = View.new(game.defs)
    local input = Input.new(game, view)
    local ww, wh = love.graphics.getDimensions()
    local viewport = view:viewport(ww, wh)
    local function clickButton(actionType)
        local button = assert(view:findButton(actionType), "missing button " .. actionType)
        return input:mousepressed(viewport.x + (button.x + button.w / 2) * viewport.scale,
            viewport.y + (button.y + button.h / 2) * viewport.scale, 1)
    end
    local function assertFits(label)
        for _, scale in ipairs({ 1, 2, 3 }) do
            for _, button in ipairs(view.buttons) do
                truthy(view:buttonLabelFits(button, scale), label .. " button overflow: " .. button.label)
            end
            for _, text in ipairs(view.texts) do
                truthy(view:textBlockFits(text, scale), label .. " text overflow: " .. text.value)
            end
        end
    end
    local function assertSafeExitLayout(buttonType, hasDetail)
        local primary = assert(view:findTextRole("primary_guide"))
        local warning = assert(view:findTextRole("safe_exit_warning"))
        local button = assert(view:findButton(buttonType))
        for _, scale in ipairs({ 1, 2, 3 }) do
            truthy(view:textBlockBounds(primary, scale).bottom <= button.y * scale,
                "primary warning overlaps action at " .. scale .. "x")
            if hasDetail then
                local detail = assert(view:findTextRole("safe_exit_detail"))
                truthy(view:textBlockBounds(detail, scale).bottom <= button.y * scale,
                    "loss detail overlaps confirmation at " .. scale .. "x")
            else
                truthy((button.y + button.h) * scale <= view:textBlockBounds(warning, scale).top,
                    "loss warning overlaps default actions at " .. scale .. "x")
            end
        end
    end

    view:draw(game:getState())
    truthy(view:findButton("retry_save"))
    truthy(view:findButton("request_safe_exit"))
    local visible = {}
    for _, text in ipairs(view.texts) do visible[#visible + 1] = text.value end
    truthy(table.concat(visible, "\n"):find("미저장 변경 유실 가능", 1, true))
    assertFits("save error")
    assertSafeExitLayout("retry_save", false)
    truthy(clickButton("request_safe_exit"), "safe exit UI must capture the click")
    equal(storage.writeCount, writesAfterFailure)
    equal(generation(checkpoint), failedGeneration)
    view:draw(game:getState())
    truthy(game:getState().safeExitDraft)
    truthy(view:findButton("confirm_safe_exit"))
    truthy(view:findButton("cancel_safe_exit"))
    assertFits("safe exit confirmation")
    assertSafeExitLayout("confirm_safe_exit", true)
    truthy(clickButton("cancel_safe_exit"))
    equal(game:getState().safeExitDraft, false)
    equal(storage.writeCount, writesAfterFailure)

    view:draw(game:getState())
    truthy(clickButton("request_safe_exit"))
    view:draw(game:getState())
    truthy(clickButton("confirm_safe_exit"))
    equal(quitCalls, 1)
    equal(game:getState().phase, "TITLE")
    equal(storage.writeCount, writesAfterFailure, "abandon must not write")
    equal(generation(checkpoint), failedGeneration, "abandon must not change disk generation")

    local retryGame, retryStorage, retryCheckpoint = newGame()
    retryStorage.writeMode = "fail_before"
    truthy(retryGame:selectOffer("tower"))
    equal(retryGame:confirmPurchase(), false)
    local retryGeneration = generation(retryCheckpoint)
    truthy(retryGame:requestSafeExit())
    truthy(retryGame:cancelSafeExit())
    retryStorage.writeMode = nil
    equal(retryGame:retrySave().status, "applied")
    equal(generation(retryCheckpoint), retryGeneration + 1)
    equal(#retryGame:getState().runState.towerInstances, 3,
        "cancelled exit must leave the exact pending candidate retryable")
end)

test("seventh tower purchase selects and reveals once while failed paths preserve page", function()
    local function uiFor(game)
        local view = View.new(game.defs)
        local input = Input.new(game, view)
        local ww, wh = love.graphics.getDimensions()
        local viewport = view:viewport(ww, wh)
        local function clickButton(actionType, kind)
            local button = assert(view:findButton(actionType, kind), "missing button " .. actionType)
            return input:mousepressed(viewport.x + (button.x + button.w / 2) * viewport.scale,
                viewport.y + (button.y + button.h / 2) * viewport.scale, 1)
        end
        return view, input, clickButton
    end
    local function selectedButton(view, instanceId)
        for _, button in ipairs(view.buttons) do
            if button.action.type == "select_tower" and button.action.instanceId == instanceId then return button end
        end
        return nil
    end

    local game, _, checkpoint = newGame()
    prepareSixTowerShop(game, 50)
    truthy(game:selectTower(1))
    local view, _, clickButton = uiFor(game)
    view:draw(game:getState())
    equal(view:inventoryPageInfo(game:getState()).page, 1)
    truthy(clickButton("select_offer", "tower"))
    view:draw(game:getState())
    truthy(clickButton("confirm_purchase"))
    view:draw(game:getState())
    equal(game:getState().selectedTowerId, 7)
    equal(view:inventoryPageInfo(game:getState()).page, 2)
    local seventh = assert(selectedButton(view, 7), "purchased tower #7 must be visible")
    equal(seventh.selected, true)

    truthy(clickButton("inventory_page", "previous"))
    view:draw(game:getState())
    equal(view:inventoryPageInfo(game:getState()).page, 1,
        "manual paging must not be forced back every frame")
    equal(game:getState().selectedTowerId, 7)
    truthy(clickButton("select_offer", "module"))
    view:draw(game:getState())
    truthy(clickButton("confirm_purchase"))
    view:draw(game:getState())
    equal(game:getState().selectedTowerId, 7, "module purchase must not refocus")
    equal(view:inventoryPageInfo(game:getState()).page, 1)
    truthy(clickButton("select_offer", "patch"))
    view:draw(game:getState())
    truthy(clickButton("confirm_purchase"))
    view:draw(game:getState())
    equal(game:getState().selectedTowerId, 7, "patch purchase must keep its bound target")
    equal(view:inventoryPageInfo(game:getState()).page, 1)

    local cancelGame, _, cancelCheckpoint = newGame()
    prepareSixTowerShop(cancelGame, 50)
    truthy(cancelGame:selectTower(1))
    local cancelView, _, cancelClick = uiFor(cancelGame)
    cancelView:draw(cancelGame:getState())
    local cancelGeneration = generation(cancelCheckpoint)
    truthy(cancelClick("select_offer", "tower"))
    cancelView:draw(cancelGame:getState())
    truthy(cancelClick("cancel_purchase"))
    cancelView:draw(cancelGame:getState())
    equal(cancelGame:getState().selectedTowerId, 1)
    equal(cancelView:inventoryPageInfo(cancelGame:getState()).page, 1)
    equal(generation(cancelCheckpoint), cancelGeneration)

    local invalidGame, _, invalidCheckpoint = newGame()
    prepareSixTowerShop(invalidGame, 0)
    truthy(invalidGame:selectTower(1))
    local invalidView, _, invalidClick = uiFor(invalidGame)
    invalidView:draw(invalidGame:getState())
    local invalidGeneration = generation(invalidCheckpoint)
    truthy(invalidClick("select_offer", "tower"))
    local invalidConfirmed, invalidReason = invalidGame:confirmPurchase()
    equal(invalidConfirmed, false)
    equal(invalidReason, "insufficient_gold")
    invalidView:draw(invalidGame:getState())
    equal(invalidGame:getState().selectedTowerId, 1)
    equal(invalidView:inventoryPageInfo(invalidGame:getState()).page, 1)
    equal(generation(invalidCheckpoint), invalidGeneration)

    local retryGame, retryStorage, retryCheckpoint = newGame()
    prepareSixTowerShop(retryGame, 50)
    truthy(retryGame:selectTower(1))
    local retryView, _, retryClick = uiFor(retryGame)
    retryView:draw(retryGame:getState())
    local beforeFailureGeneration = generation(retryCheckpoint)
    retryStorage.writeMode = "fail_before"
    truthy(retryClick("select_offer", "tower"))
    retryView:draw(retryGame:getState())
    truthy(retryClick("confirm_purchase"), "failed confirm click must remain captured by UI")
    equal(retryGame:getState().phase, "SAVE_ERROR")
    equal(retryGame:getState().selectedTowerId, 1)
    equal(retryView:inventoryPageInfo(retryGame:getState()).page, 1)
    equal(generation(retryCheckpoint), beforeFailureGeneration)
    retryStorage.writeMode = nil
    retryView:draw(retryGame:getState())
    truthy(retryClick("retry_save"))
    retryView:draw(retryGame:getState())
    equal(retryGame:getState().selectedTowerId, 7)
    equal(retryView:inventoryPageInfo(retryGame:getState()).page, 2)
    equal(assert(selectedButton(retryView, 7)).selected, true)
end)

test("inventory pages, boss toggle and live battle HP use actual input and current state", function()
    local game = newGame()
    local candidate = game:getState().runState
    local types = { "T02", "T03", "T04", "T01" }
    for instanceId = 3, 10 do
        candidate.towerInstances[#candidate.towerInstances + 1] = {
            instanceId = instanceId, typeId = types[((instanceId - 3) % #types) + 1], paidGold = 0,
            patchIds = {}, placement = nil, charge = 0, activated = false,
        }
    end
    candidate.nextInstanceId = 11
    truthy(game:_applyDurableRun(candidate, "transaction"))
    local view = View.new(game.defs)
    local input = Input.new(game, view)
    local ww, wh = love.graphics.getDimensions()
    local viewport = view:viewport(ww, wh)
    local function clickButton(actionType, kind)
        local button = assert(view:findButton(actionType, kind), "missing button " .. actionType)
        return input:mousepressed(viewport.x + (button.x + button.w / 2) * viewport.scale,
            viewport.y + (button.y + button.h / 2) * viewport.scale, 1)
    end

    view:draw(game:getState())
    equal(view:inventoryPageInfo(game:getState()).pageCount, 2)
    truthy(clickButton("inventory_page", "next"))
    view:draw(game:getState())
    equal(view:inventoryPageInfo(game:getState()).page, 2)
    truthy(view:findButton("select_tower") ~= nil)
    truthy(game:selectTower(10))
    view:draw(game:getState())
    local selectedTen = view:findButton("select_tower")
    local foundTen = false
    for _, button in ipairs(view.buttons) do
        if button.action.type == "select_tower" and button.action.instanceId == 10 then
            foundTen = true
            equal(button.selected, true)
        end
    end
    truthy(foundTen, "page two must expose and retain instance #10 selection")

    truthy(clickButton("toggle_boss_rules"))
    equal(game:getState().bossRulesOpen, true)
    view:draw(game:getState())
    truthy(view:findButton("toggle_boss_rules").label:find("닫기", 1, true))
    truthy(clickButton("toggle_boss_rules"))

    game:closeShop()
    truthy(game:startWave())
    game.battle.hp = 7
    view:draw(game:getState())
    local header = assert(view:findTextRole("phase_header"))
    truthy(header.value:find("생명 7", 1, true), "combat header must prefer live battle HP")
    equal(header.value:find("생명 20", 1, true), nil)
end)

test("assembled tower management sells paid and free instances with patch-loss disclosure", function()
    local game, _, checkpoint = newGame()
    local candidate = game:getState().runState
    candidate.gold = 5
    candidate.towerInstances[#candidate.towerInstances + 1] = {
        instanceId = 3, typeId = "T02", paidGold = 9,
        patchIds = { "P_DAMAGE", "P_RATE" }, placement = { x = 3, y = 2 },
        charge = 0.75, activated = true,
    }
    candidate.nextInstanceId = 4
    truthy(game:_applyDurableRun(candidate, "transaction"))
    truthy(game:selectTower(3))
    local view, _, _, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    local beforeManage = Json.encode(game:getState().runState)
    truthy(clickButton("inventory_management", function(action) return action.kind == "open" end))
    equal(Json.encode(game:getState().runState), beforeManage, "management entry must not leak into map placement")
    view:draw(game:getState())
    truthy(visibleText():find("실지불 9G", 1, true))
    truthy(visibleText():find("판매 환급 4G", 1, true))
    truthy(visibleText():find("출력 보강/구동 보강", 1, true))
    truthy(visibleText():find("소멸", 1, true) and visibleText():find("환급되지", 1, true))
    assertVisibleFits(view, "tower management")

    local cancelGeneration = generation(checkpoint)
    local cancelRun = Json.encode(game:getState().runState)
    truthy(clickButton("begin_inventory_transaction", function(action) return action.kind == "sell_tower" end))
    view:draw(game:getState())
    truthy(visibleText():find("포탑 판매 확인", 1, true))
    truthy(visibleText():find("실지불 9G · 환급 4G", 1, true))
    truthy(clickButton("cancel_inventory_transaction"))
    equal(generation(checkpoint), cancelGeneration)
    equal(Json.encode(game:getState().runState), cancelRun)
    equal(game:getState().selectedTowerId, 3)

    view:draw(game:getState())
    truthy(clickButton("begin_inventory_transaction", function(action) return action.instanceId == 3 end))
    view:draw(game:getState())
    truthy(clickButton("confirm_inventory_transaction"))
    local sold = game:getState()
    equal(findTowerById(sold.runState, 3), nil)
    equal(sold.runState.gold, 9)
    equal(sold.selectedTowerId, nil)
    equal(generation(checkpoint), cancelGeneration + 1)
    equal(game.lastEvents[#game.lastEvents].patchCount, 2)
    equal(game.lastEvents[#game.lastEvents].refundGold, 4)

    local freeGame, _, freeCheckpoint = newGame()
    truthy(freeGame:selectTower(1))
    local freeView, _, _, freeClick, freeText = assembledUi(freeGame)
    freeView:draw(freeGame:getState())
    truthy(freeClick("inventory_management", function(action) return action.kind == "open" end))
    freeView:draw(freeGame:getState())
    truthy(freeText():find("실지불 0G", 1, true))
    truthy(freeText():find("판매 환급 0G", 1, true))
    truthy(freeText():find("무료 획득", 1, true))
    local freeGeneration = generation(freeCheckpoint)
    local freeGold = freeGame:getState().runState.gold
    truthy(freeClick("begin_inventory_transaction", function(action) return action.instanceId == 1 end))
    freeView:draw(freeGame:getState())
    truthy(freeText():find("환급 0G", 1, true))
    truthy(freeClick("confirm_inventory_transaction"))
    equal(freeGame:getState().runState.gold, freeGold)
    equal(findTowerById(freeGame:getState().runState, 1), nil)
    equal(generation(freeCheckpoint), freeGeneration + 1)
end)

test("assembled module management preserves acquired exclusion and confirms actual refund", function()
    local game, _, checkpoint = newGame()
    local candidate = game:getState().runState
    candidate.gold = 7
    candidate.modules = { { moduleId = "M01", paidGold = 9, growth = 3 } }
    candidate.acquiredModuleIds.M01 = true
    candidate.shopState.offers.module = nil
    candidate.shopState.soldOut.module = true
    truthy(game:_applyDurableRun(candidate, "transaction"))
    local offersBefore = Json.encode(game:getState().runState.shopState.offers)
    local rngBefore = Json.encode(game:getState().runState.shopState.rngState)
    local beforeGeneration = generation(checkpoint)
    local view, _, _, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    truthy(clickButton("inventory_management", function(action) return action.kind == "open" end))
    view:draw(game:getState())
    truthy(clickButton("inventory_management", function(action) return action.kind == "module" end))
    view:draw(game:getState())
    truthy(clickButton("select_managed_module", function(action) return action.moduleId == "M01" end))
    view:draw(game:getState())
    truthy(visibleText():find("실지불 9G · 판매 환급 4G", 1, true))
    truthy(visibleText():find("효과/성장 소멸", 1, true))
    truthy(visibleText():find("재획득 불가", 1, true))
    assertVisibleFits(view, "module management")
    truthy(clickButton("begin_inventory_transaction", function(action) return action.moduleId == "M01" end))
    view:draw(game:getState())
    truthy(visibleText():find("모듈 판매 확인", 1, true))
    truthy(visibleText():find("실지불 9G · 환급 4G", 1, true))
    truthy(clickButton("confirm_inventory_transaction"))
    local run = game:getState().runState
    equal(#run.modules, 0)
    equal(run.acquiredModuleIds.M01, true)
    equal(run.gold, 11)
    equal(Json.encode(run.shopState.offers), offersBefore)
    equal(Json.encode(run.shopState.rngState), rngBefore)
    equal(generation(checkpoint), beforeGeneration + 1)
end)

test("assembled SHOP and PREPARE recall keep tower identity while COMBAT rejects it", function()
    local shopGame, _, shopCheckpoint = newGame()
    local shopCandidate = shopGame:getState().runState
    local shopTower = assert(findTowerById(shopCandidate, 1))
    shopTower.paidGold = 5
    shopTower.patchIds = { "P_DAMAGE" }
    shopTower.placement = { x = 3, y = 2 }
    shopTower.charge = 0.625
    shopTower.activated = true
    truthy(shopGame:_applyDurableRun(shopCandidate, "transaction"))
    truthy(shopGame:selectTower(1))
    local shopView, _, _, shopClick = assembledUi(shopGame)
    shopView:draw(shopGame:getState())
    truthy(shopClick("inventory_management", function(action) return action.kind == "open" end))
    shopView:draw(shopGame:getState())
    local shopGeneration = generation(shopCheckpoint)
    truthy(shopClick("recall_tower", function(action) return action.instanceId == 1 end))
    local recalled = assert(findTowerById(shopGame:getState().runState, 1))
    equal(recalled.placement, nil)
    equal(recalled.paidGold, 5)
    equal(recalled.patchIds[1], "P_DAMAGE")
    close(recalled.charge, 0.625)
    equal(recalled.activated, true)
    equal(shopGame:getState().selectedTowerId, 1)
    equal(generation(shopCheckpoint), shopGeneration + 1)

    local prepareGame, _, prepareCheckpoint = newGame()
    truthy(prepareGame:selectTower(1))
    truthy(prepareGame:placeSelected(3, 2))
    truthy(prepareGame:closeShop().status == "applied")
    local prepareView, _, _, prepareClick, prepareText = assembledUi(prepareGame)
    prepareView:draw(prepareGame:getState())
    truthy(prepareText():find("무료 회수", 1, true))
    local prepareGeneration = generation(prepareCheckpoint)
    truthy(prepareClick("recall_tower", function(action) return action.instanceId == 1 end))
    equal(findTowerById(prepareGame:getState().runState, 1).placement, nil)
    equal(generation(prepareCheckpoint), prepareGeneration + 1)
    local prepareSale, prepareSaleReason = prepareGame:beginInventoryTransaction({ kind = "sell_tower", instanceId = 1 })
    equal(prepareSale, false)
    equal(prepareSaleReason, "shop_required")

    local combatGame, _, combatCheckpoint = newGame()
    truthy(combatGame:selectTower(1))
    truthy(combatGame:placeSelected(3, 2))
    truthy(combatGame:closeShop().status == "applied")
    truthy(combatGame:startWave())
    local combatGeneration = generation(combatCheckpoint)
    local commandsBefore = Json.encode(combatGame.pendingBattleCommands)
    local combatView = View.new(combatGame.defs)
    combatView:draw(combatGame:getState())
    equal(combatView:findButton("recall_tower"), nil)
    local recalledInCombat, combatReason = combatGame:recallTower(1)
    equal(recalledInCombat, false)
    equal(combatReason, "combat_recall_forbidden")
    local combatTowerSale, combatTowerReason = combatGame:beginInventoryTransaction({ kind = "sell_tower", instanceId = 1 })
    equal(combatTowerSale, false)
    equal(combatTowerReason, "shop_required")
    local combatModuleSale, combatModuleReason = combatGame:beginInventoryTransaction({ kind = "sell_module", moduleId = "M01" })
    equal(combatModuleSale, false)
    equal(combatModuleReason, "shop_required")
    truthy(findTowerById(combatGame:getState().runState, 1).placement ~= nil)
    equal(Json.encode(combatGame.pendingBattleCommands), commandsBefore)
    equal(generation(combatCheckpoint), combatGeneration)
end)

local managementBackCases = {
    {input="escape", name="assembled module management escape returns one layer and never commits"},
    {input="right_click", name="assembled module management right_click returns one layer and never commits"},
}
for _, backCase in ipairs(managementBackCases) do
    local backInput=backCase.input
    test(backCase.name, function()
        local game, storage, checkpoint = newGame()
        installEightTowerM05Fixture(game)
        truthy(game:selectTower(7))
        local view, input, findAction, clickButton = assembledUi(game)
        local function back()
            if backInput == "escape" then return input:keypressed("escape", false) end
            local ww, wh = love.graphics.getDimensions()
            local viewport = view:viewport(ww, wh)
            return input:mousepressed(viewport.x + 2, viewport.y + 2, 2)
        end
        view:draw(game:getState())
        truthy(clickButton("inventory_management", function(action) return action.kind == "open" end))
        view:draw(game:getState())
        truthy(clickButton("inventory_management", function(action) return action.kind == "module" end))
        view:draw(game:getState())
        truthy(clickButton("select_managed_module", function(action) return action.moduleId == "M05" end))
        view:draw(game:getState())
        truthy(clickButton("begin_inventory_transaction", function(action) return action.moduleId == "M05" end))
        view:draw(game:getState())
        truthy(clickButton("toggle_inventory_recall", function(action) return action.instanceId == 1 end))
        equal(#game:getState().transactionDraft.selectedRecallTowerIds, 1)
        local runBefore = Json.encode(game:getState().runState)
        local generationBefore, writesBefore = generation(checkpoint), storage.writeCount

        truthy(back(), "first back must cancel the pending sale and recall selection")
        equal(game:getState().transactionDraft, nil)
        equal(view:hasInventoryManagement(), true)
        equal(view.managedModuleId, "M05", "transaction cancellation must retain module detail")
        view:draw(game:getState())
        truthy(findAction("managed_module_back"), "module detail must remain rendered")

        truthy(back(), "second back must return from detail to the module list")
        equal(view.managedModuleId, nil)
        equal(view:hasInventoryManagement(), true, "detail back must retain the management list")
        equal(view.inventoryManagementTab, "module")
        view:draw(game:getState())
        truthy(findAction("select_managed_module", function(action) return action.moduleId == "M05" end),
            "module list must remain rendered")

        truthy(back(), "third back must return from management to SHOP")
        equal(view:hasInventoryManagement(), false)
        view:draw(game:getState())
        truthy(findAction("inventory_management", function(action) return action.kind == "open" end))
        equal(game:getState().phase, "SHOP")
        equal(game:getState().selectedTowerId, 7, "back must not cancel the underlying tower selection")
        equal(Json.encode(game:getState().runState), runBefore)
        equal(generation(checkpoint), generationBefore)
        equal(storage.writeCount, writesBefore, "navigation and draft cancellation must not save")
    end)
end

test("assembled M05 sale selects exact placed recalls across pages and one-layer back is inert", function()
    local game, _, checkpoint = newGame()
    installEightTowerM05Fixture(game)
    local view, input, findAction, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    truthy(clickButton("inventory_management", function(action) return action.kind == "open" end))
    view:draw(game:getState())
    truthy(clickButton("inventory_management", function(action) return action.kind == "module" end))
    view:draw(game:getState())
    truthy(clickButton("select_managed_module", function(action) return action.moduleId == "M05" end))
    view:draw(game:getState())
    truthy(clickButton("begin_inventory_transaction", function(action) return action.moduleId == "M05" end))
    local initialRun = Json.encode(game:getState().runState)
    local initialGeneration = generation(checkpoint)
    equal(game:getState().transactionDraft.requiredRecallCount, 2)

    local originalWidth, originalHeight = love.graphics.getDimensions()
    local ok, resizeError = pcall(function()
        love.window.setMode(480, 270, { resizable = true, minwidth = 480, minheight = 270 })
        view:draw(game:getState())
        assertVisibleFits(view, "M05 transaction 480")
        truthy(visibleText():find("회수 선택 0/2", 1, true))
        local mapTarget = assert(findAction("toggle_inventory_recall", function(action, button)
            return action.instanceId == 1 and button.hitOnly == true
        end), "map recall target missing")
        local viewport480 = view:viewport(480, 270)
        truthy(input:mousepressed(viewport480.x + (mapTarget.x + mapTarget.w / 2) * viewport480.scale,
            viewport480.y + (mapTarget.y + mapTarget.h / 2) * viewport480.scale, 1))
        equal(#game:getState().transactionDraft.selectedRecallTowerIds, 1)
        truthy(findTowerById(game:getState().runState, 1).placement ~= nil,
            "selection click must not leak into placement or recall before confirm")

        love.window.setMode(960, 540, { resizable = true, minwidth = 480, minheight = 270 })
        view:draw(game:getState())
        assertVisibleFits(view, "M05 transaction 960")
        truthy(clickButton("inventory_page", function(action) return action.kind == "next" end))
        view:draw(game:getState())
        truthy(clickButton("toggle_inventory_recall", function(action) return action.instanceId == 7 end))
        equal(#game:getState().transactionDraft.selectedRecallTowerIds, 2)

        love.window.setMode(1440, 810, { resizable = true, minwidth = 480, minheight = 270 })
        view:draw(game:getState())
        assertVisibleFits(view, "M05 transaction 1440")
        truthy(clickButton("toggle_inventory_recall", function(action) return action.instanceId == 8 end),
            "over-count click must still be captured by UI")
        equal(#game:getState().transactionDraft.selectedRecallTowerIds, 2,
            "exact-N selection must reject a third tower")
    end)
    love.window.setMode(originalWidth, originalHeight, { resizable = true, minwidth = 480, minheight = 270 })
    if not ok then error(resizeError, 0) end

    local layerWidth, layerHeight = love.graphics.getDimensions()
    local layerOk, layerError = pcall(function()
        love.window.setMode(800, 600, { resizable = true, minwidth = 480, minheight = 270 })
        view:draw(game:getState())
        local letterboxed = view:viewport(800, 600)
        truthy(letterboxed.x > 0 or letterboxed.y > 0, "800x600 must expose a letterbox margin")
        equal(input:mousepressed(1, 1, 2), false, "outside right-click must be rejected")
        truthy(game:getState().transactionDraft, "outside right-click must retain transaction draft")
        equal(view:hasInventoryManagement(), true)
        equal(Json.encode(game:getState().runState), initialRun)
        equal(generation(checkpoint), initialGeneration)

        truthy(input:mousepressed(letterboxed.x + 2, letterboxed.y + 2, 2),
            "inside right-click must cancel only the transaction layer")
        equal(game:getState().transactionDraft, nil)
        equal(view:hasInventoryManagement(), true)
        equal(Json.encode(game:getState().runState), initialRun)
        equal(generation(checkpoint), initialGeneration)

        equal(input:mousepressed(1, 1, 2), false,
            "outside right-click must not close the remaining management layer")
        equal(view:hasInventoryManagement(), true)
        truthy(input:mousepressed(letterboxed.x + 2, letterboxed.y + 2, 2),
            "second inside right-click must return to the module list")
        equal(view.managedModuleId, nil)
        equal(view:hasInventoryManagement(), true)
        equal(input:mousepressed(1, 1, 2), false, "outside right-click must retain the module list")
        equal(view:hasInventoryManagement(), true)
        truthy(input:mousepressed(letterboxed.x + 2, letterboxed.y + 2, 2),
            "third inside right-click must close management")
        equal(view:hasInventoryManagement(), false)
    end)
    love.window.setMode(layerWidth, layerHeight, { resizable = true, minwidth = 480, minheight = 270 })
    if not layerOk then error(layerError, 0) end

    view:draw(game:getState())
    truthy(clickButton("inventory_management", function(action) return action.kind == "open" end))
    view:draw(game:getState())
    truthy(clickButton("inventory_management", function(action) return action.kind == "module" end))
    view:draw(game:getState())
    truthy(clickButton("select_managed_module", function(action) return action.moduleId == "M05" end))
    view:draw(game:getState())
    truthy(clickButton("begin_inventory_transaction", function(action) return action.moduleId == "M05" end))
    view:draw(game:getState())
    truthy(clickButton("inventory_page", function(action) return action.kind == "previous" end))
    view:draw(game:getState())
    truthy(clickButton("toggle_inventory_recall", function(action) return action.instanceId == 1 end))
    truthy(clickButton("inventory_page", function(action) return action.kind == "next" end))
    view:draw(game:getState())
    truthy(clickButton("toggle_inventory_recall", function(action) return action.instanceId == 7 end))
    view:draw(game:getState())
    truthy(findAction("confirm_inventory_transaction").enabled)
    truthy(clickButton("confirm_inventory_transaction"))
    local committed = game:getState().runState
    equal(#committed.modules, 0)
    equal(committed.acquiredModuleIds.M05, true)
    equal(committed.gold, 28)
    equal(countPlacedTowers(committed), 6)
    equal(findTowerById(committed, 1).placement, nil)
    equal(findTowerById(committed, 7).placement, nil)
    equal(findTowerById(committed, 7).patchIds[1], "P_DAMAGE")
    equal(generation(checkpoint), initialGeneration + 1)
end)

test("inventory transaction cancel stale and write failure preserve committed state and retry exact candidate", function()
    local staleGame, _, staleCheckpoint = newGame()
    local staleCandidate = staleGame:getState().runState
    staleCandidate.towerInstances[1].paidGold = 9
    staleCandidate.towerInstances[1].patchIds = { "P_DAMAGE" }
    truthy(staleGame:_applyDurableRun(staleCandidate, "transaction"))
    truthy(staleGame:beginInventoryTransaction({ kind = "sell_tower", instanceId = 1 }))
    local concurrent = staleGame:getState().runState
    concurrent.gold = concurrent.gold + 1
    truthy(staleGame:_applyDurableRun(concurrent, "transaction"))
    local postConcurrentRun = Json.encode(staleGame:getState().runState)
    local postConcurrentGeneration = generation(staleCheckpoint)
    local staleConfirmed, staleReason = staleGame:confirmInventoryTransaction()
    equal(staleConfirmed, false)
    equal(staleReason, "stale_transaction_revision")
    equal(Json.encode(staleGame:getState().runState), postConcurrentRun)
    equal(generation(staleCheckpoint), postConcurrentGeneration)
    truthy(staleGame:cancelInventoryTransaction())

    local game, storage, checkpoint = newGame()
    local candidate = game:getState().runState
    candidate.gold = 3
    candidate.towerInstances[1].paidGold = 9
    candidate.towerInstances[1].patchIds = { "P_DAMAGE", "P_RATE" }
    truthy(game:_applyDurableRun(candidate, "transaction"))
    truthy(game:selectTower(1))
    local view, _, _, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    truthy(clickButton("inventory_management", function(action) return action.kind == "open" end))
    view:draw(game:getState())
    truthy(clickButton("begin_inventory_transaction", function(action) return action.instanceId == 1 end))
    local committedRun = Json.encode(game:getState().runState)
    local committedGeneration = generation(checkpoint)
    local offersBefore = Json.encode(game:getState().runState.shopState.offers)
    local rngBefore = Json.encode(game:getState().runState.shopState.rngState)
    storage.writeMode = "fail_before"
    view:draw(game:getState())
    truthy(clickButton("confirm_inventory_transaction"), "failed confirmation must be captured")
    equal(game:getState().phase, "SAVE_ERROR")
    equal(Json.encode(game:getState().runState), committedRun)
    equal(generation(checkpoint), committedGeneration)
    equal(Json.encode(game:getState().runState.shopState.offers), offersBefore)
    equal(Json.encode(game:getState().runState.shopState.rngState), rngBefore)
    local pending = assert(game.session.pending and game.session.pending.candidate, "prepared retry candidate missing")
    local pendingEnvelope = pending.encodedEnvelope
    local pendingTarget = pending.targetPath
    local pendingGeneration = pending.generation
    equal(pendingGeneration, committedGeneration + 1)
    view:draw(game:getState())
    truthy(visibleText():find("저장에 실패", 1, true))
    truthy(view:findButton("retry_save"))
    truthy(view:findButton("request_safe_exit"))
    assertVisibleFits(view, "inventory save error")

    storage.writeMode = nil
    truthy(clickButton("retry_save"))
    local retried = game:getState()
    equal(retried.phase, "SHOP")
    equal(findTowerById(retried.runState, 1), nil)
    equal(retried.runState.gold, 7)
    equal(generation(checkpoint), pendingGeneration)
    equal(storage.files[pendingTarget], pendingEnvelope, "retry must commit the exact prepared envelope")
    equal(Json.encode(retried.runState.shopState.offers), offersBefore)
    equal(Json.encode(retried.runState.shopState.rngState), rngBefore)
end)

test("synthetic generation 34 W07 restores read-only and commits sale only at generation 35", function()
    local game, storage, checkpoint = newGame()
    truthy(game:closeShop().status == "applied")
    for waveIndex = 1, 6 do truthy(completeWave(game, waveIndex)) end
    equal(game:getState().phase, "SHOP")
    equal(game:getState().runState.nextWaveIndex, 7)
    equal(game:getState().runState.shopState.visitId, "S02")
    local shaped = game:getState().runState
    shaped.hp = 17
    shaped.gold = 9
    shaped.towerInstances[1].paidGold = 10
    shaped.towerInstances[1].patchIds = { "P_DAMAGE" }
    truthy(game:_applyDurableRun(shaped, "transaction"))
    while generation(checkpoint) < 34 do
        truthy(game:_applyDurableRun(game:getState().runState, "transaction"))
    end
    equal(generation(checkpoint), 34)
    local generation34Path = checkpoint:loadCheckpoint().path
    local generation34Bytes = storage.files[generation34Path]
    local writesBeforeRestore = storage.writeCount
    local identityCalls = 0
    local restored = Game.new({ checkpointStore = checkpoint, defs = game.defs,
        identityProvider = function()
            identityCalls = identityCalls + 1
            return { runId = "must-not-create", shopSeed = 777 }
        end,
        quitCallback = function() error("quit must not run") end })
    equal(identityCalls, 0, "valid generation 34 restore must not create a new identity")
    equal(storage.writeCount, writesBeforeRestore, "restore must be read-only")
    equal(restored:getState().runState.nextWaveIndex, 7)
    equal(restored:getState().runState.hp, 17)
    equal(restored:getState().runState.gold, 9)
    local offersBefore = Json.encode(restored:getState().runState.shopState.offers)
    local rngBefore = Json.encode(restored:getState().runState.shopState.rngState)

    truthy(restored:beginInventoryTransaction({ kind = "sell_tower", instanceId = 1 }))
    equal(storage.writeCount, writesBeforeRestore, "preview must not write")
    truthy(restored:cancelInventoryTransaction())
    equal(storage.writeCount, writesBeforeRestore, "cancel must not write")
    equal(generation(checkpoint), 34)

    truthy(restored:beginInventoryTransaction({ kind = "sell_tower", instanceId = 1 }))
    truthy(restored:confirmInventoryTransaction())
    local loaded35 = checkpoint:loadCheckpoint()
    equal(loaded35.generation, 35)
    equal(loaded35.path, generation34Path == "save-a.json" and "save-b.json" or "save-a.json")
    equal(storage.files[generation34Path], generation34Bytes, "generation 35 must preserve generation 34 bytes")
    equal(loaded35.payload.runState.nextWaveIndex, 7)
    equal(loaded35.payload.runState.hp, 17)
    equal(loaded35.payload.runState.gold, 14)
    equal(findTowerById(loaded35.payload.runState, 1), nil)
    equal(Json.encode(loaded35.payload.runState.shopState.offers), offersBefore)
    equal(Json.encode(loaded35.payload.runState.shopState.rngState), rngBefore)
end)

test("Stage B starting24 plus earned M28 keeps migrated W07 six-module pool read-only", function()
    local game, storage, checkpoint = newGame()
    local tierCounts = { low = 0, mid = 0, high = 0 }
    for _, moduleDef in ipairs(game.defs.modules) do tierCounts[moduleDef.tier] = tierCounts[moduleDef.tier] + 1 end
    local defaultIds = Game.defaultUnlockPool(game.defs).moduleIds
    equal(#defaultIds, 24)
    local covered, expectedTiers = {}, { low = 0, mid = 0, high = 0 }
    local earnedIds = { "M12", "M14", "M15", "M16", "M28", "M31", "M41", "M42", "M43", "M46" }
    for _, ids in ipairs({ defaultIds, earnedIds }) do
        for _, id in ipairs(ids) do
            equal(covered[id], nil); covered[id] = true
            local moduleDef = assert(game.defs.modulesById[id])
            expectedTiers[moduleDef.tier] = expectedTiers[moduleDef.tier] + 1
        end
    end
    for _, moduleDef in ipairs(game.defs.modules) do equal(covered[moduleDef.id], true) end
    equal(#game.defs.modules, #defaultIds + #earnedIds)
    for tier, count in pairs(expectedTiers) do equal(tierCounts[tier], count) end
    equal(#game:getState().runState.frozenUnlockPool.moduleIds, 24)

    local payload = checkpoint:loadCheckpoint().payload
    local run = payload.runState
    run.contentVersion = "DR-RUN-002-r1"
    run.nextWaveIndex = 7
    run.completedWaveIds = Json.object()
    for index = 1, 6 do run.completedWaveIds[string.format("W%02d", index)] = true end
    run.modules = Json.array({ { moduleId = "M01", paidGold = 8, growth = 0 } })
    run.acquiredModuleIds = { M01 = true }
    run.frozenUnlockPool.moduleIds = Json.array({ "M01", "M02", "M05", "M17", "M25", "M26" })
    run.shopState.visitId = "S02"
    run.shopState.offers.module = "M02"
    run.shopState.soldOut.module = false
    payload.checkpointKind = "waveComplete"
    payload.resumeDescriptor.kind = "waveComplete"
    payload.resumeDescriptor.waveIndex = 7
    payload.transactionIdentity = nil
    storage.files = {}
    storage.writeCount = 0
    writeShaEnvelope(storage, "save-b.json", 34, "DR-RUN-002-r1", payload)
    local sourceBytes = storage.files["save-b.json"]
    local writesBefore = storage.writeCount
    local identityCalls = 0
    local restored = Game.new({ checkpointStore = checkpoint, defs = game.defs,
        identityProvider = function()
            identityCalls = identityCalls + 1
            return { runId = "must-not-create", shopSeed = 777 }
        end,
        quitCallback = function() error("quit must not run") end })
    local restoredRun = restored:getState().runState
    equal(identityCalls, 0)
    equal(storage.writeCount, writesBefore, "migration restore must not write")
    equal(generation(checkpoint), 34)
    equal(restoredRun.nextWaveIndex, 7)
    equal(restoredRun.contentVersion, game.defs.version)
    equal(Json.encode(restoredRun.frozenUnlockPool.moduleIds),
        Json.encode({ "M01", "M02", "M05", "M17", "M25", "M26" }))
    equal(storage.files["save-b.json"], sourceBytes)
end)

test("M06 zero-recall purchase still shows capacity placement and enabled confirmation", function()
    local game = newGame()
    local run = game:getState().runState
    run.gold = 40
    run.shopState.offers.module = "M06"
    run.shopState.soldOut.module = false
    run.acquiredModuleIds.M06 = nil
    truthy(game:_applyDurableRun(run, "transaction"))
    local view, _, findAction, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    truthy(clickButton("select_offer", function(action) return action.kind == "module" end))
    local draft = game:getState().purchaseDraft
    equal(draft.offerId, "M06")
    equal(draft.requiredRecallCount, 0)
    view:draw(game:getState())
    truthy(visibleText():find("수용량 6→4 · 배치 0 · 필요 회수 0", 1, true))
    truthy(visibleText():find("회수 없음 · 확인 후 수용량 적용", 1, true))
    equal(assert(findAction("confirm_purchase")).enabled, true)
    assertVisibleFits(view, "M06 zero recall")
end)

test("assembled M06 purchase recalls exact two across map and pages while preserving identity and patches", function()
    local game, _, checkpoint = newGame()
    installM06PurchaseFixture(game)
    local view, input, findAction, clickButton, visibleText = assembledUi(game)
    local generationBefore = generation(checkpoint)
    local rngBefore = Json.encode(game:getState().runState.shopState.rngState)
    local originalWidth, originalHeight = love.graphics.getDimensions()
    local ok, resizeError = pcall(function()
        love.window.setMode(480, 270, { resizable = true, minwidth = 480, minheight = 270 })
        selectM06RecallPair(game, view, input, findAction, clickButton)
        local draft = game:getState().purchaseDraft
        equal(draft.requiredRecallCount, 2)
        equal(Json.encode(draft.selectedRecallTowerIds), Json.encode({ 1, 7 }))
        truthy(findTowerById(game:getState().runState, 1).placement ~= nil)
        equal(findTowerById(game:getState().runState, 7).patchIds[1], "P_DAMAGE")
        view:draw(game:getState())
        truthy(visibleText():find("수용량 8→6 · 배치 8 · 필요 회수 2", 1, true))
        truthy(visibleText():find("선택 2/2 · 개체/패치 보존", 1, true))
        assertVisibleFits(view, "M06 purchase 480")
        for _, size in ipairs({ { 960, 540 }, { 1440, 810 } }) do
            love.window.setMode(size[1], size[2], { resizable = true, minwidth = 480, minheight = 270 })
            view:draw(game:getState())
            assertVisibleFits(view, "M06 purchase " .. tostring(size[1]))
        end
        truthy(clickButton("confirm_purchase"))
    end)
    love.window.setMode(originalWidth, originalHeight, { resizable = true, minwidth = 480, minheight = 270 })
    if not ok then error(resizeError, 0) end

    local committed = game:getState().runState
    truthy(findModuleEntry(committed, "M06"))
    truthy(findModuleEntry(committed, "M05"))
    equal(countPlacedTowers(committed), 6)
    equal(findTowerById(committed, 1).placement, nil)
    equal(findTowerById(committed, 7).placement, nil)
    equal(findTowerById(committed, 7).patchIds[1], "P_DAMAGE")
    equal(findTowerById(committed, 7).instanceId, 7)
    equal(committed.gold, 24)
    equal(committed.shopState.offers.module, nil)
    equal(committed.shopState.soldOut.module, true)
    equal(Json.encode(committed.shopState.rngState), rngBefore)
    equal(generation(checkpoint), generationBefore + 1)
end)

test("M06 purchase cancel stale and write failure keep the committed offer RNG and recall placements", function()
    local cancelGame, _, cancelCheckpoint = newGame()
    installM06PurchaseFixture(cancelGame)
    local cancelView, cancelInput, cancelFind, cancelClick = assembledUi(cancelGame)
    local cancelRun = Json.encode(cancelGame:getState().runState)
    local cancelGeneration = generation(cancelCheckpoint)
    selectM06RecallPair(cancelGame, cancelView, cancelInput, cancelFind, cancelClick)
    cancelView:draw(cancelGame:getState())
    truthy(cancelClick("cancel_purchase"))
    equal(Json.encode(cancelGame:getState().runState), cancelRun)
    equal(generation(cancelCheckpoint), cancelGeneration)

    local staleGame, _, staleCheckpoint = newGame()
    installM06PurchaseFixture(staleGame)
    local staleView, staleInput, staleFind, staleClick = assembledUi(staleGame)
    selectM06RecallPair(staleGame, staleView, staleInput, staleFind, staleClick)
    local concurrent = staleGame:getState().runState
    concurrent.gold = concurrent.gold + 1
    truthy(staleGame:_applyDurableRun(concurrent, "transaction"))
    local stableRun = Json.encode(staleGame:getState().runState)
    local stableGeneration = generation(staleCheckpoint)
    local staleCommitted, staleReason = staleGame:confirmPurchase()
    equal(staleCommitted, false)
    equal(staleReason, "stale_purchase_revision")
    equal(Json.encode(staleGame:getState().runState), stableRun)
    equal(generation(staleCheckpoint), stableGeneration)

    local retryGame, retryStorage, retryCheckpoint = newGame()
    installM06PurchaseFixture(retryGame)
    local retryView, retryInput, retryFind, retryClick = assembledUi(retryGame)
    local committedRun = Json.encode(retryGame:getState().runState)
    local committedGeneration = generation(retryCheckpoint)
    local offerBefore = Json.encode(retryGame:getState().runState.shopState.offers)
    local rngBefore = Json.encode(retryGame:getState().runState.shopState.rngState)
    selectM06RecallPair(retryGame, retryView, retryInput, retryFind, retryClick)
    retryStorage.writeMode = "fail_before"
    retryView:draw(retryGame:getState())
    truthy(retryClick("confirm_purchase"))
    equal(retryGame:getState().phase, "SAVE_ERROR")
    equal(Json.encode(retryGame:getState().runState), committedRun)
    equal(generation(retryCheckpoint), committedGeneration)
    equal(Json.encode(retryGame:getState().runState.shopState.offers), offerBefore)
    equal(Json.encode(retryGame:getState().runState.shopState.rngState), rngBefore)
    local pending = assert(retryGame.session.pending and retryGame.session.pending.candidate)
    local pendingEnvelope, pendingTarget, pendingGeneration = pending.encodedEnvelope, pending.targetPath, pending.generation
    retryStorage.writeMode = nil
    retryView:draw(retryGame:getState())
    truthy(retryClick("retry_save"))
    local retried = retryGame:getState().runState
    truthy(findModuleEntry(retried, "M06"))
    equal(countPlacedTowers(retried), 6)
    equal(findTowerById(retried, 7).patchIds[1], "P_DAMAGE")
    equal(Json.encode(retried.shopState.rngState), rngBefore)
    equal(generation(retryCheckpoint), pendingGeneration)
    equal(retryStorage.files[pendingTarget], pendingEnvelope)
end)

test("M29 M34 patch receipt and M30 M33 reroll receipt expose full price refund discount and growth", function()
    local patchGame, _, patchCheckpoint = newGame()
    local patchRun = patchGame:getState().runState
    patchRun.gold = 4
    patchRun.modules = {
        { moduleId = "M29", paidGold = 8, growth = 0 },
        { moduleId = "M34", paidGold = 12, growth = 0 },
    }
    patchRun.acquiredModuleIds.M29 = true
    patchRun.acquiredModuleIds.M34 = true
    patchRun.shopState.offers.patch = "P_DAMAGE"
    patchRun.shopState.soldOut.patch = false
    patchRun.shopState.refundUseCount = 0
    truthy(patchGame:_applyDurableRun(patchRun, "transaction"))
    truthy(patchGame:selectTower(1))
    local patchView, _, _, patchClick, patchText = assembledUi(patchGame)
    patchView:draw(patchGame:getState())
    truthy(patchClick("select_offer", function(action) return action.kind == "patch" end))
    local patchDraft = patchGame:getState().purchaseDraft
    equal(patchDraft.receiptPreview.paidGold, 4)
    equal(patchDraft.receiptPreview.refundGold, 1)
    equal(patchDraft.receiptPreview.netGold, 3)
    equal(patchDraft.growthPreview.before, 0)
    equal(patchDraft.growthPreview.after, 3)
    patchView:draw(patchGame:getState())
    truthy(patchText():find("정가4/환1/실3G", 1, true))
    local patchGeneration = generation(patchCheckpoint)
    truthy(patchClick("confirm_purchase"))
    local patched = patchGame:getState()
    equal(patched.runState.gold, 1)
    equal(patched.runState.shopState.refundUseCount, 1)
    equal(findModuleEntry(patched.runState, "M34").growth, 3)
    equal(findTowerById(patched.runState, 1).patchIds[1], "P_DAMAGE")
    equal(patched.lastReceipt.paidGold, 4)
    equal(patched.lastReceipt.refundGold, 1)
    equal(patched.lastReceipt.netGold, 3)
    equal(generation(patchCheckpoint), patchGeneration + 1)
    patchView:draw(patched)
    truthy(patchText():find("최근 패치 정가4/환급1/실지출3G", 1, true))
    truthy(patchText():find("환급1/2", 1, true))
    truthy(patchText():find("성장 0→3", 1, true))

    local poorGame, _, poorCheckpoint = newGame()
    local poorRun = poorGame:getState().runState
    poorRun.gold = 3
    poorRun.modules = {
        { moduleId = "M29", paidGold = 8, growth = 0 },
        { moduleId = "M34", paidGold = 12, growth = 0 },
    }
    poorRun.acquiredModuleIds.M29 = true
    poorRun.acquiredModuleIds.M34 = true
    poorRun.shopState.offers.patch = "P_DAMAGE"
    poorRun.shopState.soldOut.patch = false
    truthy(poorGame:_applyDurableRun(poorRun, "transaction"))
    truthy(poorGame:selectTower(1))
    local poorView, _, poorFind, poorClick, poorText = assembledUi(poorGame)
    local poorGeneration = generation(poorCheckpoint)
    poorView:draw(poorGame:getState())
    truthy(poorClick("select_offer", function(action) return action.kind == "patch" end))
    poorView:draw(poorGame:getState())
    equal(poorGame:getState().purchaseDraft.receiptPreview.netGold, 3)
    equal(poorGame:getState().purchaseDraft.enabled, false,
        "refund must not make a below-full-price purchase affordable")
    truthy(poorText():find("정가4G 필요/현재3G", 1, true))
    truthy(poorText():find("환1/실3G", 1, true))
    truthy(poorText():find("골드 부족", 1, true))
    equal(assert(poorFind("confirm_purchase")).enabled, false)
    assertVisibleFits(poorView, "M29 full-price block")
    equal(poorClick("confirm_purchase"), false, "disabled full-price purchase must not dispatch")
    local poorCommitted, poorReason = poorGame:confirmPurchase()
    equal(poorCommitted, false)
    equal(poorReason, "insufficient_gold")
    equal(poorGame:getState().runState.gold, 3)
    equal(poorGame:getState().runState.shopState.refundUseCount, 0)
    equal(findModuleEntry(poorGame:getState().runState, "M34").growth, 0)
    equal(generation(poorCheckpoint), poorGeneration)

    local rerollGame, _, rerollCheckpoint = newGame()
    local rerollRun = rerollGame:getState().runState
    rerollRun.gold = 0
    rerollRun.modules = {
        { moduleId = "M30", paidGold = 8, growth = 0 },
        { moduleId = "M33", paidGold = 12, growth = 0 },
    }
    rerollRun.acquiredModuleIds.M30 = true
    rerollRun.acquiredModuleIds.M33 = true
    rerollRun.shopState.rerollCount = 0
    rerollRun.shopState.firstRerollDone = false
    truthy(rerollGame:_applyDurableRun(rerollRun, "transaction"))
    local rerollView, _, _, rerollClick, rerollText = assembledUi(rerollGame)
    local rerollGeneration = generation(rerollCheckpoint)
    local rngBefore = Json.encode(rerollGame:getState().runState.shopState.rngState)
    rerollView:draw(rerollGame:getState())
    truthy(rerollText():find("실지불0G", 1, true))
    truthy(rerollClick("reroll"))
    local rerolled = rerollGame:getState()
    equal(rerolled.runState.gold, 0)
    equal(rerolled.runState.shopState.rerollCount, 1)
    equal(rerolled.runState.shopState.firstRerollDone, true)
    equal(findModuleEntry(rerolled.runState, "M33").growth, 3)
    truthy(Json.encode(rerolled.runState.shopState.rngState) ~= rngBefore)
    equal(rerolled.lastReceipt.nominalGold, 2)
    equal(rerolled.lastReceipt.discountGold, 2)
    equal(rerolled.lastReceipt.paidGold, 0)
    equal(rerolled.rerollPreview.nominalGold, 4)
    equal(rerolled.rerollPreview.paidGold, 4)
    equal(rerolled.rerollPreview.canCommit, false)
    equal(generation(rerollCheckpoint), rerollGeneration + 1)
    rerollView:draw(rerolled)
    truthy(rerollText():find("최근 리롤 명목2/할인2/지불0G", 1, true))
    truthy(rerollText():find("성장 0→3", 1, true))
    local afterFreeGeneration = generation(rerollCheckpoint)
    local afterFreeRng = Json.encode(rerolled.runState.shopState.rngState)
    equal(rerollClick("reroll"), false, "disabled reroll action must not dispatch")
    equal(generation(rerollCheckpoint), afterFreeGeneration)
    equal(Json.encode(rerollGame:getState().runState.shopState.rngState), afterFreeRng)
end)

test("M32 and M37 settle W14 normally but W15 result grants no settlement or growth", function()
    local game, _, checkpoint = newGame()
    for waveIndex = 1, 13 do truthy(completeWave(game, waveIndex)) end
    local run = game:getState().runState
    run.nextWaveIndex = 14
    run.completedWaveIds = Json.object()
    for index = 1, 13 do run.completedWaveIds[string.format("W%02d", index)] = true end
    run.gold = 0
    run.towerInstances[1].placement = { x = 0, y = 0 }
    run.towerInstances[2].placement = nil
    run.modules = {
        { moduleId = "M32", paidGold = 12, growth = 0 },
        { moduleId = "M37", paidGold = 8, growth = 0 },
    }
    run.acquiredModuleIds.M32 = true
    run.acquiredModuleIds.M37 = true
    truthy(game:_applyDurableRun(run, "transaction"))
    truthy(completeWave(game, 14))
    local afterW14 = game:getState()
    equal(afterW14.phase, "PREPARE")
    equal(afterW14.runState.nextWaveIndex, 15)
    equal(afterW14.lastReceipt.reward.moduleById.M32, 3)
    equal(afterW14.lastReceipt.reward.total, 12)
    equal(afterW14.runState.gold, 12)
    equal(findModuleEntry(afterW14.runState, "M37").growth, 3)

    local view, input, _, clickButton, visibleText = assembledUi(game)
    view:draw(afterW14)
    truthy(clickButton("open_module_status"))
    view:draw(game:getState())
    truthy(clickButton("select_status_module", function(action) return action.moduleId == "M32" end))
    view:draw(game:getState())
    truthy(visibleText():find("W15 최종전은 일반 정산 없음", 1, true))
    truthy(input:keypressed("escape", false))
    view:draw(game:getState())
    truthy(clickButton("select_status_module", function(action) return action.moduleId == "M37" end))
    view:draw(game:getState())
    truthy(visibleText():find("W15 승패는 성장 없음", 1, true))
    assertVisibleFits(view, "W15 module status")
    truthy(input:keypressed("escape", false))
    view:draw(game:getState())
    local beforeBossGeneration = generation(checkpoint)
    truthy(clickButton("start_wave"))
    truthy(finishStartedWave(game, 15, "victory", "boss_killed"))
    local result = game:getState()
    equal(result.phase, "RESULT")
    equal(result.runState.gold, 12)
    equal(findModuleEntry(result.runState, "M37").growth, 3)
    equal(result.lastReceipt, nil)
    equal(generation(checkpoint), beforeBossGeneration + 2,
        "W15 start and result must each commit without a settlement commit")
end)

test("conditional module details consume aggregate and selected identity projections", function()
    local game = newGame()
    local run = game:getState().runState
    run.towerInstances = {
        { instanceId = 1, typeId = "T01", paidGold = 0, patchIds = { "P_DAMAGE" },
            placement = { x = 0, y = 0 }, charge = 0, activated = false },
        { instanceId = 2, typeId = "T01", paidGold = 0, patchIds = { "P_DAMAGE" },
            placement = { x = 1, y = 0 }, charge = 0, activated = false },
        { instanceId = 3, typeId = "T02", paidGold = 9,
            patchIds = { "P_RATE", "P_RANGE", "P_OVERLOAD" },
            placement = { x = 3, y = 0 }, charge = 0, activated = false },
        { instanceId = 4, typeId = "T03", paidGold = 9, patchIds = {},
            placement = { x = 5, y = 0 }, charge = 0, activated = false },
    }
    run.nextInstanceId = 5
    run.modules = {
        { moduleId = "M07", paidGold = 8, growth = 0 },
        { moduleId = "M09", paidGold = 12, growth = 0 },
        { moduleId = "M10", paidGold = 8, growth = 0 },
        { moduleId = "M11", paidGold = 12, growth = 0 },
    }
    for _, entry in ipairs(run.modules) do run.acquiredModuleIds[entry.moduleId] = true end
    truthy(game:_applyDurableRun(run, "transaction"))
    truthy(game:closeShop().status == "applied")
    local view, _, findAction, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    local start = assert(findAction("start_wave"), "W01 start action missing")
    equal(start.enabled, true)
    truthy(clickButton("open_module_status"))

    local function openDetail(moduleId)
        view:draw(game:getState())
        truthy(clickButton("select_status_module", function(action) return action.moduleId == moduleId end))
        view:draw(game:getState())
        return visibleText()
    end
    local function backToList()
        truthy(clickButton("module_status_back"))
        view:draw(game:getState())
    end

    truthy(game:cancelSelection())
    local text = openDetail("M07")
    truthy(text:find("동종 상하좌우 충족 2/4기", 1, true))
    truthy(text:find("타워 선택 시 같은 종류 이웃 상세", 1, true))
    equal(assert(findAction("start_wave")).enabled, true)
    backToList()
    truthy(game:selectTower(1))
    text = openDetail("M07")
    truthy(text:find("선택 #1 · 이웃 #2", 1, true))
    backToList()

    truthy(game:cancelSelection())
    text = openDetail("M09")
    truthy(text:find("패치 3개 충족 1/4기", 1, true))
    backToList()
    truthy(game:selectTower(4))
    text = openDetail("M09")
    truthy(text:find("선택 #4 · 패치 0/3 · 미적용", 1, true))
    backToList()

    text = openDetail("M10")
    truthy(text:find("패치 0개 충족 1/4기", 1, true))
    truthy(text:find("선택 #4 · 패치 0개 · 적용", 1, true))
    backToList()

    truthy(game:selectTower(1))
    text = openDetail("M11")
    truthy(text:find("공유 패치 충족 2/4기", 1, true))
    truthy(text:find("출력 보강", 1, true))
    truthy(text:find("상대 #2", 1, true))
    assertVisibleFits(view, "conditional module aggregate detail")

    local leadGame = newGame()
    local leadRun = leadGame:getState().runState
    leadRun.towerInstances = Json.decode(Json.encode(run.towerInstances))
    leadRun.nextInstanceId = 5
    leadRun.modules = { { moduleId = "M13", paidGold = 12, growth = 0 } }
    leadRun.acquiredModuleIds.M13 = true
    truthy(leadGame:_applyDurableRun(leadRun, "transaction"))
    truthy(leadGame:closeShop().status == "applied")
    local leadView, _, leadFind, leadClick, leadText = assembledUi(leadGame)
    leadView:draw(leadGame:getState())
    truthy(leadClick("open_module_status"))
    leadView:draw(leadGame:getState())
    truthy(leadClick("select_status_module", function(action) return action.moduleId == "M13" end))
    leadView:draw(leadGame:getState())
    truthy(leadText():find("단독 최다 #3 · 패치 3개", 1, true))
    equal(assert(leadFind("start_wave")).enabled, true)

    local tied = leadGame:getState().runState
    findTowerById(tied, 1).patchIds = { "P_DAMAGE", "P_RATE", "P_RANGE" }
    truthy(leadGame:_applyDurableRun(tied, "transaction"))
    leadView:draw(leadGame:getState())
    truthy(leadText():find("최다 3개 동률 · #1,#3", 1, true))

    local none = leadGame:getState().runState
    for _, tower in ipairs(none.towerInstances) do tower.patchIds = {} end
    truthy(leadGame:_applyDurableRun(none, "transaction"))
    leadView:draw(leadGame:getState())
    truthy(leadText():find("배치 4기 · 패치 보유 대상 없음", 1, true))
    assertVisibleFits(leadView, "M13 sole tie none")
end)

test("growth cap displays maximum across detail reroll and patch draft without promising 30 to 30", function()
    local game = newGame()
    local run = game:getState().runState
    run.gold = 20
    run.modules = {
        { moduleId = "M33", paidGold = 12, growth = 30 },
        { moduleId = "M34", paidGold = 12, growth = 30 },
    }
    run.acquiredModuleIds.M33 = true
    run.acquiredModuleIds.M34 = true
    run.shopState.offers.patch = "P_DAMAGE"
    run.shopState.soldOut.patch = false
    truthy(game:_applyDurableRun(run, "transaction"))
    truthy(game:selectTower(1))
    local view, _, findAction, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    truthy(visibleText():find("성장 최대치", 1, true))
    truthy(visibleText():find("탐색 학습 현재30/30%p · 최대치", 1, true))
    equal(visibleText():find("성장30→30", 1, true), nil)
    truthy(clickButton("select_offer", function(action) return action.kind == "patch" end))
    view:draw(game:getState())
    truthy(visibleText():find("성장 최대치", 1, true))
    equal(visibleText():find("성장30→30", 1, true), nil)
    assertVisibleFits(view, "growth cap patch draft")
    truthy(clickButton("cancel_purchase"))
    truthy(game:closeShop().status == "applied")
    view:draw(game:getState())
    local start = assert(findAction("start_wave"), "W01 start action missing at cap")
    equal(start.enabled, true)
    truthy(clickButton("open_module_status"))
    view:draw(game:getState())
    truthy(clickButton("select_status_module", function(action) return action.moduleId == "M33" end))
    view:draw(game:getState())
    truthy(visibleText():find("현재 30/30%p · 최대치", 1, true))
    equal(visibleText():find("다음 성공 리롤 30%p", 1, true), nil)
    equal(assert(findAction("start_wave")).enabled, true)
    assertVisibleFits(view, "growth cap module detail")
end)

test("four long Korean module details fit and letterbox back closes one status layer at a time", function()
    local game = newGame()
    local run = game:getState().runState
    run.modules = {
        { moduleId = "M10", paidGold = 8, growth = 0 },
        { moduleId = "M18", paidGold = 12, growth = 0 },
        { moduleId = "M32", paidGold = 12, growth = 0 },
        { moduleId = "M37", paidGold = 8, growth = 3 },
    }
    run.acquiredModuleIds.M10 = true
    run.acquiredModuleIds.M18 = true
    run.acquiredModuleIds.M32 = true
    run.acquiredModuleIds.M37 = true
    truthy(game:_applyDurableRun(run, "transaction"))
    truthy(game:selectTower(1))
    truthy(game:closeShop().status == "applied")
    local view, input, _, clickButton, visibleText = assembledUi(game)
    local expected = {
        M10 = { "패치 0개" },
        M18 = { "적마다 최근 2초 피격 종류", "보장 DPS에는 합산하지 않음" },
        M32 = { "정산 기여 예상" },
        M37 = { "다음 생존 완료" },
    }
    local ok, resizeError = pcall(function()
        for _, size in ipairs({ { 480, 270 }, { 960, 540 }, { 1440, 810 } }) do
            love.window.setMode(size[1], size[2], { resizable = true, minwidth = 480, minheight = 270 })
            view:draw(game:getState())
            if not view:hasModuleStatus() then truthy(clickButton("open_module_status")) end
            view:draw(game:getState())
            for _, name in ipairs({ "무개조 운용", "집중 사격", "긴축 배당", "현장 학습" }) do
                truthy(visibleText():find(name, 1, true), "missing Korean module name: " .. name)
            end
            assertVisibleFits(view, "module status list " .. tostring(size[1]))
        end
        for _, moduleId in ipairs({ "M10", "M18", "M32", "M37" }) do
            view:draw(game:getState())
            truthy(clickButton("select_status_module", function(action) return action.moduleId == moduleId end))
            view:draw(game:getState())
            for _, detail in ipairs(expected[moduleId]) do
                truthy(visibleText():find(detail, 1, true),
                    "missing dynamic detail: " .. moduleId .. " / " .. detail)
            end
            assertVisibleFits(view, "module detail " .. moduleId)
            truthy(clickButton("module_status_back"))
        end

        love.window.setMode(800, 600, { resizable = true, minwidth = 480, minheight = 270 })
        view:draw(game:getState())
        truthy(clickButton("select_status_module", function(action) return action.moduleId == "M18" end))
        view:draw(game:getState())
        local letterbox = view:viewport(800, 600)
        truthy(letterbox.x > 0 or letterbox.y > 0)
        equal(input:mousepressed(1, 1, 2), false)
        equal(view:hasModuleStatus(), true)
        truthy(input:mousepressed(letterbox.x + 2, letterbox.y + 2, 2))
        equal(view:hasModuleStatus(), true, "first back closes detail only")
        truthy(input:mousepressed(letterbox.x + 2, letterbox.y + 2, 2))
        equal(view:hasModuleStatus(), false, "second back closes status panel")
    end)
    if not ok then error(resizeError, 0) end
end)

test("R7 Q06 Q09 W05 commits T05 once while current offers pool and future visits stay frozen", function()
    local game, _, checkpoint = newGame()
    for waveIndex = 1, 4 do truthy(completeWave(game, waveIndex)) end
    truthy(game:startWave())
    local before = game:getState()
    local pool = Json.encode(before.runState.frozenUnlockPool)
    local shop = Json.encode(before.runState.shopState)
    local gen = generation(checkpoint)
    truthy(finishStartedWave(game, 5))
    local after = game:getState()
    equal(after.phase, "PREPARE")
    equal(after.runState.nextWaveIndex, 6)
    equal(after.towerUnlockById.T05.permanentlyUnlocked, true)
    equal(after.towerUnlockById.T05.inCurrentRunPool, false)
    equal(after.towerUnlockById.T05.isCurrentOffer, false)
    equal(#after.newTowerUnlocks, 1)
    equal(after.newTowerUnlocks[1].towerId, "T05")
    equal(Json.encode(after.runState.frozenUnlockPool), pool)
    equal(Json.encode(after.runState.shopState), shop)
    equal(generation(checkpoint), gen + 1)
    local saved = checkpoint:loadCheckpoint().payload
    equal(saved.metaState.unlockedTowerIds[5], "T05")
    equal(saved.runState.completedWaveIds.W05, true)
    equal(saved.runState.nextWaveIndex, 6)
    local projected = game:getState()
    projected.towerUnlockById.T05.permanentlyUnlocked = false
    projected.towerUnlocks[1].condition = "tampered"
    equal(game:getState().towerUnlockById.T05.permanentlyUnlocked, true)
    local beforeReward = after.runState.gold
    equal(finishStartedWave(game, 5), false, "duplicate outside COMBAT must not commit")
    equal(game:getState().runState.gold, beforeReward)
    equal(generation(checkpoint), gen + 1)
    local expected = Shop.createVisit(game.defs, {
        visitId = "S02", frozenUnlockPool = after.runState.frozenUnlockPool,
        acquiredModuleIds = after.runState.acquiredModuleIds, rngState = after.runState.shopState.rngState,
    })
    truthy(completeWave(game, 6))
    equal(Json.encode(game:getState().runState.shopState), Json.encode(expected))
    truthy(game:rerollShop())
    equal(Json.encode(game:getState().runState.frozenUnlockPool), pool)
    local offered = game:getState().runState.shopState.offers.tower
    truthy(offered ~= "T05" and offered ~= "T06")
end)

test("R7 Q07 Q09 boss victory commits T06 without settlement and new-run cancel preserves rights", function()
    local game, _, checkpoint = newGame()
    for waveIndex = 1, 14 do truthy(completeWave(game, waveIndex)) end
    truthy(game:startWave())
    local before = game:getState()
    local gen = generation(checkpoint)
    truthy(finishStartedWave(game, 15, "victory", "boss_killed"))
    local result = game:getState()
    equal(result.phase, "RESULT")
    equal(result.runState.gold, before.runState.gold)
    equal(result.runState.completedWaveIds.W15, nil)
    equal(result.towerUnlockById.T06.permanentlyUnlocked, true)
    equal(result.towerUnlockById.T06.inCurrentRunPool, false)
    equal(result.newTowerUnlocks[1].towerId, "T06")
    equal(result.lastReceipt, nil)
    equal(generation(checkpoint), gen + 1)
    local committed = Json.encode(result.runState)
    truthy(game:requestNewRun())
    truthy(game:cancelNewRun())
    equal(Json.encode(game:getState().runState), committed)
    equal(generation(checkpoint), gen + 1)
    truthy(game:requestNewRun())
    truthy(game:confirmNewRun())
    local nextRun = game:getState()
    equal(#nextRun.runState.frozenUnlockPool.towerIds, 6)
    equal(nextRun.towerUnlockById.T05.inCurrentRunPool, true)
    equal(nextRun.towerUnlockById.T06.inCurrentRunPool, true)
    equal(#nextRun.newTowerUnlocks, 0)
    reachResult(game)
    equal(#game:getState().newTowerUnlocks, 0, "already-earned boss must not reannounce unlock")
end)

test("R7 Q08 completion failure keeps rights hidden and retries exact run plus meta once", function()
    for _, waveIndex in ipairs({ 5, 15 }) do
        for _, mode in ipairs({ "fail_before", "fail_readback" }) do
            local game, storage, checkpoint = newGame()
            for index = 1, waveIndex - 1 do truthy(completeWave(game, index)) end
            truthy(game:startWave())
            local before = game:getState()
            local gen = generation(checkpoint)
            local committedPath = checkpoint:loadCheckpoint().path
            local oldBytes = storage.files[committedPath]
            local towerId = waveIndex == 5 and "T05" or "T06"
            storage.writeMode = mode
            equal(finishStartedWave(game, waveIndex, waveIndex == 5 and "wave_complete" or "victory",
                waveIndex == 15 and "boss_killed" or nil), false)
            local failed = game:getState()
            equal(failed.phase, "SAVE_ERROR")
            equal(Json.encode(failed.runState), Json.encode(before.runState))
            equal(Json.encode(failed.metaState), Json.encode(before.metaState))
            equal(failed.towerUnlockById[towerId].permanentlyUnlocked, false)
            equal(#failed.newTowerUnlocks, 0)
            equal(failed.notice:find("영구 해금", 1, true), nil)
            equal(storage.files[committedPath], oldBytes)
            local pending = assert(game.session.pending.candidate)
            local encoded, target = pending.encodedEnvelope, pending.targetPath
            equal(pending.generation, gen + 1)
            truthy(game:requestSafeExit())
            truthy(game:cancelSafeExit())
            equal(failed.towerUnlockById[towerId].permanentlyUnlocked, false)
            storage.writeMode, storage.failReadPath = nil, nil
            equal(game:retrySave().status, "applied")
            equal(storage.files[target], encoded)
            equal(generation(checkpoint), gen + 1)
            local retried = game:getState()
            equal(retried.towerUnlockById[towerId].permanentlyUnlocked, true)
            equal(#retried.newTowerUnlocks, 1)
            truthy(retried.notice:find("영구 해금", 1, true))
            equal(game:retrySave().status, "rejected")
            equal(generation(checkpoint), gen + 1)
            equal(#game:getState().newTowerUnlocks, 1)
        end
    end
end)

test("R7 Q07 defeat never earns boss tower and Q09 new-run failure preserves committed RESULT pool", function()
    local game, storage, checkpoint = newGame()
    reachResult(game, "defeat", "boss_escaped")
    local before = game:getState()
    equal(before.towerUnlockById.T05.permanentlyUnlocked, true)
    equal(before.towerUnlockById.T06.permanentlyUnlocked, false)
    equal(#before.newTowerUnlocks, 0)
    local gen = generation(checkpoint)
    truthy(game:requestNewRun())
    storage.writeMode = "fail_before"
    equal(game:confirmNewRun(), false)
    local failed = game:getState()
    equal(failed.phase, "SAVE_ERROR")
    equal(Json.encode(failed.runState), Json.encode(before.runState))
    equal(Json.encode(failed.metaState), Json.encode(before.metaState))
    equal(#failed.runState.frozenUnlockPool.towerIds, 4)
    equal(failed.towerUnlockById.T05.inCurrentRunPool, false)
    storage.writeMode = nil
    equal(game:retrySave().status, "applied")
    equal(generation(checkpoint), gen + 1)
    equal(#game:getState().runState.frozenUnlockPool.towerIds, 5)
    equal(game:getState().towerUnlockById.T06.inCurrentRunPool, false)
end)

test("R7 Q11 S24 Game restore grants recorded W05 read-only with four-tower run until next game", function()
    local source, storage, checkpoint = newGame()
    for index = 1, 6 do truthy(completeWave(source, index)) end
    local payload = checkpoint:loadCheckpoint().payload
    payload.runState.contentVersion = "DR-MOD-S24-r1"
    payload.metaState.unlockedTowerIds = { "T01", "T02", "T03", "T04" }
    payload.metaState.unlockedModuleIds = {} -- A real S24 save cannot contain a later M28 right.
    storage.files = {}
    writeShaEnvelope(storage, "save-b.json", 34, "DR-MOD-S24-r1", payload)
    local bytes = storage.files["save-b.json"]
    local writes = storage.writeCount
    local restored = Game.new({ checkpointStore = checkpoint, defs = source.defs,
        identityProvider = function() return { runId = "r7-migrated-new", shopSeed = 501 } end })
    local state = restored:getState()
    equal(storage.writeCount, writes)
    equal(storage.files["save-b.json"], bytes)
    equal(generation(checkpoint), 34)
    equal(state.runState.nextWaveIndex, 7)
    equal(state.towerUnlockById.T05.permanentlyUnlocked, true)
    equal(state.towerUnlockById.T05.inCurrentRunPool, false)
    equal(#state.newTowerUnlocks, 0)
    truthy(state.notice:find("W07", 1, true))
    equal(Json.encode(state.runState.shopState), Json.encode(payload.runState.shopState))
    truthy(restored:closeShop().status == "applied")
    truthy(restored:startWave())
    equal(generation(checkpoint), 35)
    equal(storage.files["save-b.json"], bytes)
    truthy(finishStartedWave(restored, 7))
    for index = 8, 14 do truthy(completeWave(restored, index)) end
    truthy(completeWave(restored, 15, "defeat", "boss_escaped"))
    truthy(restored:requestNewRun())
    truthy(restored:confirmNewRun())
    equal(#restored:getState().runState.frozenUnlockPool.towerIds, 5)
end)

test("R7 Q14 earned towers use lawful seeded offers and durable independent instances", function()
    local defs = Content.create()
    local function ids(items)
        local result = {}
        for _, item in ipairs(items) do result[#result + 1] = item.id end
        table.sort(result)
        return result
    end
    local pool = { towerIds = ids(defs.towers), patchIds = ids(defs.patches), moduleIds = ids(defs.modules) }
    for _, towerId in ipairs({ "T05", "T06" }) do
        local seed
        for candidateSeed = 1, 10000 do
            local shop = Shop.createVisit(defs, { visitId = "S00", frozenUnlockPool = pool,
                acquiredModuleIds = {}, rngState = Rng.new(candidateSeed):getState() })
            if shop.offers.tower == towerId then seed = candidateSeed; break end
        end
        truthy(seed, "no lawful seeded offer found for " .. towerId)
        io.write("FIXTURE R7 Q14 ", towerId, " shopSeed=", tostring(seed), "\n")
        local game, _, checkpoint = newGame({ shopSeed = seed })
        equal(game:getState().towerUnlockById[towerId].permanentlyUnlocked, false)
        reachResult(game)
        truthy(game:requestNewRun())
        truthy(game:confirmNewRun())
        prepareSixTowerShop(game, 50)
        local before = game:getState()
        equal(before.runState.shopState.offers.tower, towerId)
        equal(before.towerUnlockById[towerId].isCurrentOffer, true)
        local gen = generation(checkpoint)
        local view, input, _, clickButton, visibleText = assembledUi(game)
        view:draw(before)
        truthy(clickButton("select_offer", function(action) return action.kind == "tower" end))
        view:draw(game:getState())
        equal(game:getState().purchaseDraft.offerId, towerId)
        equal(game:getState().purchaseDraft.cost, 12)
        truthy(view:findTextRole("tower_offer_stats"))
        truthy(view:findTextRole("tower_offer_role"))
        truthy(visibleText():find(towerId == "T05" and "저격 포탑" or "전격 포탑", 1, true))
        assertVisibleFits(view, "R7 " .. towerId .. " draft")
        truthy(input:keypressed("escape", false))
        equal(Json.encode(game:getState().runState), Json.encode(before.runState))
        equal(generation(checkpoint), gen)
        view:draw(game:getState())
        truthy(clickButton("select_offer", function(action) return action.kind == "tower" end))
        view:draw(game:getState())
        truthy(clickButton("confirm_purchase"))
        local after = game:getState()
        equal(after.runState.gold, 38)
        local instance = assert(findTowerById(after.runState, before.runState.nextInstanceId))
        equal(instance.typeId, towerId)
        equal(instance.paidGold, 12)
        equal(instance.placement, nil)
        equal(#instance.patchIds, 0)
        equal(after.selectedTowerId, instance.instanceId)
        equal(after.towerUnlockById[towerId].isCurrentOffer, false)
        equal(generation(checkpoint), gen + 1)
        view:draw(after)
        equal(view.inventoryPage, 2)
        truthy(visibleText():find("#7", 1, true))
        truthy(clickButton("inventory_management", function(action) return action.kind == "open" end))
        view:draw(game:getState())
        truthy(view:findTextRole("owned_tower_stats"))
        assertVisibleFits(view, "R7 seventh " .. towerId .. " owned")
    end
end)

test("R7 Q12 Q15 lookup separates locked permanent pool and offer and captures background input", function()
    local game, _, checkpoint = newGame()
    truthy(game:selectTower(1))
    local view, input, findAction, clickButton = assembledUi(game)
    local dimensions = love.graphics.getDimensions
    local ok, message = pcall(function()
        for _, size in ipairs({ { 480, 270 }, { 960, 540 }, { 1440, 810 }, { 800, 600 } }) do
            -- Isolate viewport math/font drawing without repeatedly recreating the OS window.
            love.graphics.getDimensions = function() return size[1], size[2] end
            view:draw(game:getState())
            local before = game:getState()
            local gen = generation(checkpoint)
            local page = view.inventoryPage
            local offerButton = assert(findAction("select_offer", function(action) return action.kind == "tower" end))
            truthy(clickButton("open_tower_unlocks"))
            view:draw(game:getState())
            for _, towerId in ipairs({ "T05", "T06" }) do
                truthy(view:findTextRole("tower_unlock_" .. towerId .. "_permanent").value:find("영구 잠김", 1, true))
                truthy(view:findTextRole("tower_unlock_" .. towerId .. "_pool").value:find("이번 판 후보 제외", 1, true))
                truthy(view:findTextRole("tower_unlock_" .. towerId .. "_condition"))
                truthy(view:findTextRole("tower_unlock_" .. towerId .. "_offer").value:find("현재 제안 없음", 1, true))
            end
            assertVisibleFits(view, "R7 lookup viewport " .. tostring(size[1]))
            local vp = view:viewport(size[1], size[2])
            truthy(input:mousepressed(vp.x + 12 * vp.scale, vp.y + 32 * vp.scale, 1))
            truthy(input:mousepressed(vp.x + (offerButton.x + 2) * vp.scale,
                vp.y + (offerButton.y + 2) * vp.scale, 1))
            equal(game:getState().purchaseDraft, nil)
            equal(Json.encode(game:getState().runState), Json.encode(before.runState))
            equal(game:getState().selectedTowerId, before.selectedTowerId)
            equal(view.inventoryPage, page)
            equal(generation(checkpoint), gen)
            if size[1] == 800 then
                equal(input:mousepressed(1, 1, 2), false)
                equal(view:hasTowerUnlocks(), true)
                truthy(input:mousepressed(vp.x + 2, vp.y + 2, 2))
            else truthy(input:keypressed("escape", false)) end
            equal(view:hasTowerUnlocks(), false)
            equal(game:getState().selectedTowerId, 1)
        end
    end)
    love.graphics.getDimensions = dimensions
    if not ok then error(message, 0) end
    for index = 1, 5 do truthy(completeWave(game, index)) end
    view:draw(game:getState())
    truthy(view:findTextRole("new_tower_unlock_feedback"))
    local start = assert(findAction("start_wave"))
    equal(start.enabled, true)
    truthy(clickButton("open_tower_unlocks"))
    view:draw(game:getState())
    truthy(view:findTextRole("tower_unlock_T05_permanent").value:find("영구 해금됨", 1, true))
    truthy(view:findTextRole("tower_unlock_T05_pool").value:find("이번 판 후보 제외", 1, true))
    truthy(clickButton("close_tower_unlocks"))
    view:draw(game:getState())
    equal(assert(findAction("start_wave")).enabled, true)
end)

test("R7 Q13 unlock feedback follows saved success while error and RESULT draft retain priority", function()
    local game, storage, checkpoint = newGame()
    local view, input, _, clickButton = assembledUi(game)
    for index = 1, 4 do truthy(completeWave(game, index)) end
    truthy(game:startWave())
    storage.writeMode = "fail_before"
    equal(finishStartedWave(game, 5), false)
    view:draw(game:getState())
    equal(view:findTextRole("new_tower_unlock_feedback"), nil)
    truthy(view:findButton("retry_save"))
    truthy(view:findButton("request_safe_exit"))
    equal(view:openTowerUnlocks(game:getState()), false)
    storage.writeMode = nil
    truthy(clickButton("retry_save"))
    view:draw(game:getState())
    truthy(view:findTextRole("new_tower_unlock_feedback"))
    assertVisibleFits(view, "R7 W05 retry feedback")
    for index = 6, 14 do truthy(completeWave(game, index)) end
    truthy(completeWave(game, 15, "victory", "boss_killed"))
    view:draw(game:getState())
    truthy(view:findTextRole("new_tower_unlock_feedback").value:find("전격 포탑", 1, true))
    assertVisibleFits(view, "R7 RESULT unlock")
    truthy(clickButton("open_tower_unlocks"))
    view:draw(game:getState())
    truthy(view:findTextRole("tower_unlock_T06_permanent").value:find("영구 해금됨", 1, true))
    truthy(input:keypressed("escape", false))
    view:draw(game:getState())
    local gen = generation(checkpoint)
    truthy(clickButton("request_new_run"))
    view:draw(game:getState())
    equal(view:openTowerUnlocks(game:getState()), false)
    truthy(input:keypressed("escape", false))
    equal(generation(checkpoint), gen)
    view:draw(game:getState())
    truthy(clickButton("request_new_run"))
    view:draw(game:getState())
    truthy(clickButton("confirm_new_run"))
    view:draw(game:getState())
    truthy(clickButton("open_tower_unlocks"))
    view:draw(game:getState())
    for _, towerId in ipairs({ "T05", "T06" }) do
        truthy(view:findTextRole("tower_unlock_" .. towerId .. "_permanent").value:find("영구 해금됨", 1, true))
        truthy(view:findTextRole("tower_unlock_" .. towerId .. "_pool").value:find("이번 판 후보 포함", 1, true))
    end
    assertVisibleFits(view, "R7 new-run unlocked pool")
end)

local function m28EligibleW03(game, gold, hp)
    for index = 1, 2 do truthy(completeWave(game, index)) end
    local candidate = game:getState().runState
    candidate.gold, candidate.hp = gold or 20, hp or candidate.hp
    truthy(game:_applyDurableRun(candidate, "transaction"))
end

local function m28Seed()
    local game = newGame()
    local pool = game:getState().runState.frozenUnlockPool
    pool.moduleIds[#pool.moduleIds + 1] = "M28"
    table.sort(pool.moduleIds)
    for seed = 1, 10000 do
        local visit = Shop.createVisit(game.defs, { visitId = "S00", frozenUnlockPool = pool,
            acquiredModuleIds = {}, rngState = Rng.new(seed):getState() })
        if visit.offers.module == "M28" then return seed, visit end
    end
    error("no seeded M28 offer")
end

local function m28OfferedGame()
    local seed, expected = m28Seed()
    local game, storage, checkpoint = newGame({ shopSeed = seed })
    m28EligibleW03(game)
    truthy(completeWave(game, 3))
    truthy(completeWave(game, 4, "defeat", "fixture_defeat"))
    truthy(game:requestNewRun())
    truthy(game:confirmNewRun())
    equal(game:getState().runState.shopState.offers.module, "M28")
    equal(Json.encode(game:getState().runState.shopState), Json.encode(expected))
    io.write("FIXTURE M28 T06 T07 shopSeed=", tostring(seed), " poolCount=25 actualOffer=M28\n")
    return game, storage, checkpoint
end

test("M28 T04 completion write/readback errors hide rights and retry exact checkpoint once", function()
    local expectedUnlockCopy, expectedFeedback
    for _, mode in ipairs({ "fail_before", "fail_readback" }) do
        local game, storage, checkpoint = newGame()
        m28EligibleW03(game)
        truthy(game:startWave())
        local before, gen = game:getState(), generation(checkpoint)
        local old = checkpoint:loadCheckpoint()
        local oldBytes = storage.files[old.path]
        storage.writeMode = mode
        equal(finishStartedWave(game, 3), false)
        local failed = game:getState()
        equal(failed.phase, "SAVE_ERROR")
        equal(Json.encode(failed.runState), Json.encode(before.runState))
        equal(Json.encode(failed.metaState), Json.encode(before.metaState))
        equal(failed.moduleUnlockById.M28.permanentlyUnlocked, false)
        equal(#failed.newModuleUnlocks, 0)
        equal(Json.encode(failed.lastReceipt), Json.encode(before.lastReceipt))
        equal(failed.notice:find("예치금 영구 해금", 1, true), nil)
        local view, _, _, _, visibleText = assembledUi(game)
        view:draw(failed)
        equal(view:findTextRole("new_tower_unlock_feedback"), nil)
        for _, token in ipairs({ "W03–W14 일반 생존 완료", "5G당 +1G", "다음 새 판 후보" }) do
            equal(failed.notice:find(token, 1, true), nil)
            equal(visibleText():find(token, 1, true), nil)
        end
        equal(storage.files[old.path], oldBytes)
        local attempt = storage.writeAttempts[#storage.writeAttempts]
        local envelope = Json.decode(attempt.data)
        equal(envelope.generation, gen + 1)
        local payload = Json.decode(envelope.payloadJson)
        equal(payload.metaState.unlockedModuleIds[1], "M28")
        equal(payload.runState.completedWaveIds.W03, true)
        storage.writeMode, storage.failReadPath = nil, nil
        equal(game:retrySave().status, "applied")
        equal(generation(checkpoint), gen + 1)
        equal(storage.files[attempt.path], attempt.data)
        local after = game:getState()
        equal(after.moduleUnlockById.M28.permanentlyUnlocked, true)
        equal(after.moduleUnlockById.M28.inCurrentRunPool, false)
        equal(#after.newModuleUnlocks, 1)
        equal(after.lastReceipt.reward.preRewardGold, 20)
        equal(after.runState.gold, 20 + after.lastReceipt.reward.total)
        view:draw(after)
        local feedback = assert(view:findTextRole("new_tower_unlock_feedback"))
        for _, token in ipairs({ "W03–W14 일반 생존 완료", "보상 전 20G 이상", "장착 정산 전 5G당 +1G",
            "최대 4G", "이번 판 제외", "다음 새 판 후보" }) do
            truthy(feedback.value:find(token, 1, true), "retry feedback missing " .. token)
            truthy(visibleText():find(token, 1, true), "retry visible copy missing " .. token)
        end
        for _, token in ipairs({ "W03–W14 일반 생존 완료", "보상 전 20G 이상", "장착 일반 정산 전 5G당 +1G",
            "최대 4G", "이번 판 제외", "다음 새 판부터 후보" }) do
            truthy(after.notice:find(token, 1, true), "saved retry notice missing " .. token)
        end
        local unlockCopy = after.notice:match("\n(.*)")
        expectedUnlockCopy, expectedFeedback = expectedUnlockCopy or unlockCopy, expectedFeedback or feedback.value
        equal(unlockCopy, expectedUnlockCopy)
        equal(feedback.value, expectedFeedback)
        assertVisibleFits(view, "M28 retry completion " .. mode)
        equal(finishStartedWave(game, 3), false)
        equal(generation(checkpoint), gen + 1)
        equal(#game:getState().newModuleUnlocks, 1)
        equal(game:getState().notice, after.notice)
        local reloaded = Game.new({ checkpointStore = checkpoint, defs = game.defs,
            identityProvider = function() return { runId = "m28-reload", shopSeed = 2 } end })
        equal(reloaded:getState().moduleUnlockById.M28.permanentlyUnlocked, true)
        equal(#reloaded:getState().newModuleUnlocks, 0)
        view:draw(reloaded:getState())
        equal(view:findTextRole("new_tower_unlock_feedback"), nil)
        equal(visibleText():find("W03–W14 일반 생존 완료", 1, true), nil)
        equal(generation(checkpoint), gen + 1)
        io.write("FIXTURE M28 T04 mode=", mode, " retryGeneration=", tostring(gen + 1), " exactPayload=true\n")
    end
end)

test("M28 T06 current pool and visits stay frozen while next-run cancel/error/retry use earned pool", function()
    local game, storage, checkpoint = newGame()
    m28EligibleW03(game)
    local before = game:getState().runState
    local expected = Shop.createVisit(game.defs, { visitId = "S01", frozenUnlockPool = before.frozenUnlockPool,
        acquiredModuleIds = before.acquiredModuleIds, rngState = before.shopState.rngState })
    truthy(completeWave(game, 3))
    local after = game:getState().runState
    equal(#after.frozenUnlockPool.moduleIds, 24)
    equal(Json.encode(after.frozenUnlockPool), Json.encode(before.frozenUnlockPool))
    equal(Json.encode(after.shopState), Json.encode(expected))
    truthy(completeWave(game, 4, "defeat", "fixture_defeat"))
    local result, gen = game:getState(), generation(checkpoint)
    truthy(game:requestNewRun())
    truthy(game:cancelNewRun())
    equal(Json.encode(game:getState().runState), Json.encode(result.runState))
    equal(generation(checkpoint), gen)
    truthy(game:requestNewRun())
    storage.writeMode = "fail_before"
    equal(game:confirmNewRun(), false)
    equal(Json.encode(game:getState().runState), Json.encode(result.runState))
    equal(game:getState().moduleUnlockById.M28.permanentlyUnlocked, true)
    storage.writeMode = nil
    equal(game:retrySave().status, "applied")
    equal(#game:getState().runState.frozenUnlockPool.moduleIds, 25)
    equal(game:getState().moduleUnlockById.M28.inCurrentRunPool, true)
    equal(#game:getState().runState.modules, 0)
    equal(#game:getState().newModuleUnlocks, 0)
    local seed, visit = m28Seed()
    local pool = game:getState().runState.frozenUnlockPool
    local deterministic = Shop.createVisit(game.defs, { visitId = "S00", frozenUnlockPool = pool,
        acquiredModuleIds = {}, rngState = Rng.new(seed):getState() })
    equal(Json.encode(deterministic), Json.encode(visit))
end)

test("M28 T07 seeded real offer purchase sale and acquired exclusion preserve permanent right", function()
    local game, _, checkpoint = m28OfferedGame()
    local view, input, _, clickButton, visibleText = assembledUi(game)
    local candidate = game:getState().runState
    candidate.gold = 11
    truthy(game:_applyDurableRun(candidate, "transaction"))
    view:draw(game:getState())
    truthy(clickButton("select_offer", function(a) return a.kind == "module" end))
    view:draw(game:getState())
    equal(game:getState().purchaseDraft.cost, 12)
    equal(view:findButton("confirm_purchase").enabled, false)
    truthy(visibleText():find("예치금", 1, true))
    assertVisibleFits(view, "M28 insufficient draft")
    truthy(input:keypressed("escape", false))
    candidate = game:getState().runState
    candidate.gold = 31
    truthy(game:_applyDurableRun(candidate, "transaction"))
    local before, gen = game:getState(), generation(checkpoint)
    truthy(game:selectOffer("module"))
    truthy(game:cancelPurchase())
    equal(generation(checkpoint), gen)
    equal(Json.encode(game:getState().runState), Json.encode(before.runState))
    truthy(game:selectOffer("module"))
    truthy(game:confirmPurchase())
    local purchased = game:getState()
    equal(purchased.runState.gold, 19)
    equal(findModuleEntry(purchased.runState, "M28").paidGold, 12)
    equal(purchased.runState.acquiredModuleIds.M28, true)
    equal(purchased.moduleStatusById.M28.estimatedGold, 3)
    equal(purchased.runState.shopState.soldOut.module, true)
    view:draw(purchased)
    truthy(view:openInventoryManagement("module"))
    truthy(view:selectManagedModule("M28"))
    view:draw(game:getState())
    truthy(visibleText():find("현재 19G", 1, true))
    assertVisibleFits(view, "M28 installed detail")
    truthy(game:beginInventoryTransaction({ kind = "sell_module", moduleId = "M28" }))
    view:draw(game:getState())
    assertVisibleFits(view, "M28 sale confirmation")
    truthy(game:confirmInventoryTransaction())
    equal(findModuleEntry(game:getState().runState, "M28"), nil)
    equal(game:getState().moduleStatusById.M28.estimatedGold, 0)
    equal(game:getState().moduleUnlockById.M28.permanentlyUnlocked, true)
    equal(game:getState().runState.acquiredModuleIds.M28, true)
    for _ = 1, 3 do
        truthy(game:rerollShop())
        truthy(game:getState().runState.shopState.offers.module ~= "M28")
    end
    truthy(completeWave(game, 1, "defeat", "fixture_defeat"))
    equal(game:getState().moduleUnlockById.M28.permanentlyUnlocked, true)
    truthy(game:requestNewRun())
    truthy(game:confirmNewRun())
    equal(game:getState().runState.shopState.offers.module, "M28")
    equal(game:getState().runState.acquiredModuleIds.M28, nil)
end)

test("M28 T08 actual Battle and Game update complete W03 and atomically unlock from original gold", function()
    local game, _, checkpoint = newGame({ shopSeed = 28 })
    m28EligibleW03(game, 20, 40)
    truthy(game:startWave())
    local battle, gen = game.battle, generation(checkpoint)
    for _ = 1, 6000 do
        if game:getState().phase ~= "COMBAT" then break end
        game:update(1 / 30)
    end
    local after = game:getState()
    equal(after.phase, "SHOP")
    equal(battle.result.kind, "wave_complete")
    equal(battle.observations.spawned, 22)
    equal(after.runState.hp, 18)
    equal(after.lastReceipt.reward.preRewardGold, 20)
    equal(after.lastReceipt.reward.moduleById.M28, 0)
    equal(after.moduleUnlockById.M28.permanentlyUnlocked, true)
    equal(generation(checkpoint), gen + 1)
    do
        local completionView, _, _, _, completionText = assembledUi(game)
        completionView:draw(after)
        local feedback = assert(completionView:findTextRole("new_tower_unlock_feedback"))
        for _, token in ipairs({ "예치금 해금 완료", "W03–W14 일반 생존 완료", "보상 전 20G 이상",
            "장착 정산 전 5G당 +1G", "최대 4G", "이번 판 제외", "다음 새 판 후보" }) do
            truthy(feedback.value:find(token, 1, true), "actual W03 feedback missing " .. token)
            truthy(completionText():find(token, 1, true), "actual W03 visible copy missing " .. token)
        end
        for _, token in ipairs({ "W03–W14 일반 생존 완료", "보상 전 20G 이상", "장착 일반 정산 전 5G당 +1G",
            "최대 4G", "이번 판 제외", "다음 새 판부터 후보" }) do
            truthy(after.notice:find(token, 1, true), "actual W03 saved notice missing " .. token)
        end
        assertVisibleFits(completionView, "M28 actual W03 completion feedback")
    end
    io.write("FIXTURE M28 T08 actualBattle wave=W03 spawned=22 tick=", tostring(battle.tick),
        " hp=18 prereward=20 unlock=M28 visibleReasonEffect=true\n")
    truthy(completeWave(game, 4, "defeat", "fixture_defeat"))
    truthy(game:requestNewRun())
    truthy(game:confirmNewRun())
    truthy(game:selectOffer("module"))
    truthy(game:confirmPurchase())
    local candidate = game:getState().runState
    candidate.gold = 19
    truthy(game:_applyDurableRun(candidate, "transaction"))
    truthy(game:closeShop().status == "applied")
    local view, _, _, clickButton, visibleText = assembledUi(game)
    view:draw(game:getState())
    truthy(clickButton("open_module_status"))
    view:selectStatusModule("M28")
    view:draw(game:getState())
    truthy(visibleText():find("현재 19G", 1, true))
    truthy(visibleText():find("이자 예상 +3G / 최대 4G", 1, true))
    assertVisibleFits(view, "M28 PREPARE projected interest")
    view:closeModuleStatus()
    truthy(game:startWave())
    view:draw(game:getState()) -- Runtime renders COMBAT and closes the previous PREPARE status layer.
    battle = game.battle
    for _ = 1, 6000 do
        if game:getState().phase ~= "COMBAT" then break end
        game:update(1 / 30)
    end
    after = game:getState()
    equal(after.phase, "PREPARE")
    equal(after.lastReceipt.reward.preRewardGold, 19)
    equal(after.lastReceipt.reward.moduleById.M28, 3)
    equal(after.lastReceipt.reward.moduleById.M31, 0)
    equal(after.lastReceipt.reward.total, 9)
    equal(after.runState.gold, 28)
    equal(#after.newModuleUnlocks, 0)
    view:draw(after)
    truthy(visibleText():find("최근 정산+9G · 전19G · 이자+3/예비+0G", 1, true))
    assertVisibleFits(view, "M28 actual W01 interest receipt")
    io.write("FIXTURE M28 T08 actualBattle wave=W01 spawned=", tostring(battle.observations.spawned),
        " tick=", tostring(battle.tick), " prereward=19 interest=3 delta=9\n")
end)

test("M28 T09 tabbed lookup text fit letterbox capture and draft/error back priority", function()
    local game, storage = newGame()
    local view, input, findAction, clickButton, visibleText = assembledUi(game)
    local before = game:getState()
    view:draw(before)
    truthy(clickButton("open_tower_unlocks"))
    view:draw(game:getState())
    truthy(clickButton("unlock_lookup_tab", function(a) return a.tab == "deposit" end))
    view:draw(game:getState())
    truthy(visibleText():find("영구 잠김", 1, true))
    truthy(visibleText():find("W03–W14", 1, true))
    truthy(visibleText():find("보상 전 20G", 1, true))
    truthy(visibleText():find("W15 제외", 1, true))
    truthy(visibleText():find("무료 지급/등장 보장 없음", 1, true))
    assertVisibleFits(view, "M28 locked lookup")
    equal(findAction("select_offer"), nil)
    equal(input:keypressed("return", false), false)
    for _, size in ipairs({ { 480, 270 }, { 960, 540 }, { 1440, 810 }, { 1100, 650 } }) do
        love.window.setMode(size[1], size[2], { resizable = true })
        view:draw(game:getState())
        local vp = view:viewport(size[1], size[2])
        truthy(input:mousepressed(vp.x + 35 * vp.scale, vp.y + 60 * vp.scale, 1))
        equal(Json.encode(game:getState().runState), Json.encode(before.runState))
        assertVisibleFits(view, "M28 lookup " .. size[1])
    end
    love.window.setMode(960, 540, { resizable = true })
    truthy(input:keypressed("escape", false))
    view:draw(game:getState())
    truthy(game:selectOffer("module"))
    equal(view:openTowerUnlocks(game:getState()), false)
    truthy(input:keypressed("escape", false))
    m28EligibleW03(game)
    truthy(completeWave(game, 3))
    for _, size in ipairs({ { 480, 270 }, { 960, 540 }, { 1440, 810 }, { 1100, 650 } }) do
        love.window.setMode(size[1], size[2], { resizable = true })
        view:draw(game:getState())
        local feedback = assert(view:findTextRole("new_tower_unlock_feedback"))
        for _, token in ipairs({ "W03–W14 일반 생존 완료", "보상 전 20G 이상", "5G당 +1G", "최대 4G",
            "이번 판 제외", "다음 새 판 후보" }) do
            truthy(feedback.value:find(token, 1, true), "completion viewport missing " .. token)
        end
        for _, scale in ipairs({ 1, 2, 3 }) do
            local bounds = view:textBlockBounds(feedback, scale)
            equal(bounds.lineCount, 3, "completion guide must remain three readable lines")
            truthy(bounds.top >= 72 * scale and bounds.bottom <= 112 * scale,
                "completion feedback exceeds existing guide height")
            truthy(view:textBlockBounds(view:findTextRole("notice"), scale).bottom <= 30 * scale,
                "completion header overlaps panel")
        end
        assertVisibleFits(view, "M28 completion feedback " .. size[1])
    end
    love.window.setMode(960, 540, { resizable = true })
    view:draw(game:getState())
    truthy(clickButton("open_tower_unlocks"))
    view:draw(game:getState())
    truthy(view:findTextRole("module_unlock_M28_permanent").value:find("영구 해금됨", 1, true))
    truthy(view:findTextRole("module_unlock_M28_pool").value:find("이번 판 후보 제외", 1, true))
    assertVisibleFits(view, "M28 earned excluded lookup")
    truthy(input:mousepressed(920, 490, 2))
    equal(view:hasTowerUnlocks(), false)
    view:draw(game:getState())
    truthy(game:selectOffer("tower"))
    view:draw(game:getState())
    equal(view:findTextRole("new_tower_unlock_feedback"), nil)
    equal(view:findTextRole("primary_guide").value:find("5G당 +1G", 1, true), nil)
    truthy(input:keypressed("escape", false))
    truthy(game:beginInventoryTransaction({ kind = "sell_tower", instanceId = 1 }))
    view:draw(game:getState())
    equal(view:findTextRole("new_tower_unlock_feedback"), nil)
    truthy(view:findTextRole("primary_guide").value:find("실지불·환급·손실", 1, true))
    truthy(input:keypressed("escape", false))
    view:openInventoryManagement("tower")
    view:draw(game:getState())
    equal(view:findTextRole("new_tower_unlock_feedback"), nil)
    truthy(view:findTextRole("primary_guide").value:find("보유 포탑·모듈", 1, true))
    truthy(input:keypressed("escape", false))
    view:draw(game:getState())
    truthy(view:findTextRole("new_tower_unlock_feedback"))
    local offered = m28OfferedGame()
    local offeredView, _, _, offeredClick = assembledUi(offered)
    offeredView:draw(offered:getState())
    truthy(offeredClick("open_tower_unlocks"))
    offeredView:setUnlockLookupTab("deposit")
    offeredView:draw(offered:getState())
    truthy(offeredView:findTextRole("module_unlock_M28_pool").value:find("이번 판 후보 포함", 1, true))
    truthy(offeredView:findTextRole("module_unlock_M28_offer").value:find("현재 상점 제안", 1, true))
    assertVisibleFits(offeredView, "M28 earned included offer lookup")
    truthy(game:startWave())
    storage.writeMode = "fail_before"
    equal(finishStartedWave(game, 4), false)
    view:draw(game:getState())
    equal(view:hasTowerUnlocks(), false)
    equal(view:openTowerUnlocks(game:getState()), false)
    equal(view:findTextRole("new_tower_unlock_feedback"), nil)
    truthy(view:findButton("retry_save"))
    assertVisibleFits(view, "M28 save error")
    storage.writeMode = nil
    equal(game:retrySave().status, "applied")
end)

local function m43EligibleW03(game, gold, hp)
    m28EligibleW03(game, gold or 20, hp)
    local candidate = game:getState().runState
    candidate.modules = { { moduleId = "M25", paidGold = 8, growth = 0 } }
    candidate.acquiredModuleIds.M25 = true
    if candidate.shopState.offers.module == "M25" then candidate.shopState.offers.module = "M02" end
    truthy(game:_applyDurableRun(candidate, "transaction"))
end

local function assertM43Guide(view, label)
    local guide = assert(view:findTextRole("new_tower_unlock_feedback"))
    local manual = {}
    for row in guide.value:gmatch("[^\n]+") do manual[#manual + 1] = row end
    equal(#manual, 3, label .. " manual rows")
    truthy(guide.size >= 8)
    for scale = 1, 3 do
        local font = view:_font(guide.size * scale)
        local _, wrapped = font:getWrap(guide.value, guide.width * scale)
        equal(#wrapped, 3, label .. " wrapped rows at " .. scale)
        local rowHeight = font:getHeight() * font:getLineHeight()
        local previousBottom
        for index, row in ipairs(manual) do
            local _, lines = font:getWrap(row, guide.width * scale)
            equal(#lines, 1, label .. " individual row " .. index)
            truthy(font:hasGlyphs(row), label .. " missing glyph")
            local top = guide.y * scale + (index - 1) * rowHeight
            local bottom = top + font:getHeight()
            if previousBottom then truthy(previousBottom <= top, label .. " overlapping rows") end
            truthy(bottom <= 112 * scale, label .. " guide bottom")
            previousBottom = bottom
        end
        local bounds = view:textBlockBounds(guide, scale)
        truthy(bounds.left >= 205 * scale and bounds.right <= 465 * scale and bounds.bottom <= 112 * scale)
        truthy(view:textBlockBounds(view:findTextRole("notice"), scale).bottom <= 30 * scale)
        for _, button in ipairs(view.buttons) do
            truthy(button.y + button.h <= guide.y or button.y >= 112 or button.x + button.w <= 205,
                label .. " guide overlaps button " .. button.label)
        end
    end
end

test("M43 T03 immutable combat modules reject purchase sale durable mutation and restore incomplete start", function()
    local game, _, checkpoint = newGame()
    m43EligibleW03(game, 19)
    truthy(game:startWave())
    local before, gen = game:getState(), generation(checkpoint)
    equal(game:selectOffer("module"), false)
    equal(game:beginInventoryTransaction({ kind = "sell_module", moduleId = "M25" }), false)
    local candidate = Content.clone(before.runState)
    candidate.modules = {}
    equal(game:_applyDurableRun(candidate, "transaction"), false)
    local events = assert(require("src.battle").step(game.battle, require("src.battle").FIXED_DT,
        { { type = "sell_module", moduleId = "M25" }, { type = "purchase_module", moduleId = "M01" } }))
    local rejected = 0
    for _, event in ipairs(events) do
        if event.type == "command_rejected" then
            equal(event.reason, "unsupported_battle_command")
            rejected = rejected + 1
        end
    end
    equal(rejected, 2)
    truthy(game:selectTower(1))
    truthy(game:placeSelected(0, 2))
    game:update(1 / 60)
    truthy(game:togglePause())
    game:onFocus(false)
    game:onFocus(true)
    truthy(game:resumeAll())
    equal(Json.encode(game.battle.run.modules), Json.encode(before.runState.modules))
    equal(game.battle.run.baseModuleSlots, before.runState.baseModuleSlots)
    equal(generation(checkpoint), gen)
    local restored = Game.new({ checkpointStore = checkpoint, defs = game.defs,
        identityProvider = function() return { runId = "m43-restore", shopSeed = 2 } end })
    equal(restored:getState().phase, "COMBAT")
    equal(restored:getState().paused, true)
    equal(restored:getState().moduleUnlockById.M43.permanentlyUnlocked, false)
    equal(Json.encode(restored.battle.run.modules), Json.encode(before.runState.modules))
    truthy(finishStartedWave(game, 3))
    equal(game:getState().moduleUnlockById.M43.permanentlyUnlocked, true)
    equal(game:getState().moduleUnlockById.M28.permanentlyUnlocked, false)
end)

test("M43 T06 T07 simultaneous completion errors hide both rights and retry exact payload once", function()
    for _, mode in ipairs({ "fail_before", "fail_readback" }) do
        local game, storage, checkpoint = newGame()
        m43EligibleW03(game)
        truthy(game:startWave())
        local before, gen = game:getState(), generation(checkpoint)
        storage.writeMode = mode
        equal(finishStartedWave(game, 3), false)
        local failed = game:getState()
        equal(Json.encode(failed.runState), Json.encode(before.runState))
        equal(Json.encode(failed.metaState), Json.encode(before.metaState))
        equal(#failed.newModuleUnlocks, 0)
        equal(failed.notice:find("영구 해금", 1, true), nil)
        local view = assembledUi(game)
        view:draw(failed)
        equal(view:findTextRole("new_tower_unlock_feedback"), nil)
        local attempt = storage.writeAttempts[#storage.writeAttempts]
        local envelope = Json.decode(attempt.data)
        local payload = Json.decode(envelope.payloadJson)
        equal(table.concat(payload.metaState.unlockedModuleIds, ","), "M28,M43")
        equal(envelope.generation, gen + 1)
        equal(game:retrySave().status, "save_error")
        equal(storage.writeAttempts[#storage.writeAttempts].data, attempt.data)
        equal(#game:getState().newModuleUnlocks, 0)
        storage.writeMode, storage.failReadPath = nil, nil
        equal(game:retrySave().status, "applied")
        equal(storage.writeAttempts[#storage.writeAttempts].data, attempt.data)
        equal(generation(checkpoint), gen + 1)
        local after = game:getState()
        equal(table.concat(after.metaState.unlockedModuleIds, ","), "M28,M43")
        equal(#after.newModuleUnlocks, 2)
        equal(after.newModuleUnlocks[1].moduleId, "M28")
        equal(after.newModuleUnlocks[2].moduleId, "M43")
        equal(after.runState.gold, before.runState.gold + after.lastReceipt.reward.total)
        equal(#after.runState.frozenUnlockPool.moduleIds, 24)
        view:draw(after)
        assertM43Guide(view, "atomic retry " .. mode)
        truthy(after.notice:find("보상 전 20G 이상", 1, true))
        truthy(after.notice:find("전투 내내 유지", 1, true))
        truthy(after.notice:find("최대 36%", 1, true))
        equal(finishStartedWave(game, 3), false)
        equal(generation(checkpoint), gen + 1)
        local reloaded = Game.new({ checkpointStore = checkpoint, defs = game.defs,
            identityProvider = function() return { runId = "m43-reload", shopSeed = 2 } end })
        equal(#reloaded:getState().metaState.unlockedModuleIds, 2)
        equal(#reloaded:getState().newModuleUnlocks, 0)
        io.write("FIXTURE M43 T07 mode=", mode, " exactPayload=true generation=", tostring(gen + 1), " rights=M28,M43\n")
    end
end)

test("M43 T10 next successful new run adds each confirmed id while old shops pool RNG stay frozen", function()
    for _, gold in ipairs({ 19, 20 }) do
        local game, storage, checkpoint = newGame()
        m43EligibleW03(game, gold)
        local before = game:getState().runState
        local expected = Shop.createVisit(game.defs, { visitId = "S01", frozenUnlockPool = before.frozenUnlockPool,
            acquiredModuleIds = before.acquiredModuleIds, rngState = before.shopState.rngState })
        truthy(completeWave(game, 3))
        equal(Json.encode(game:getState().runState.shopState), Json.encode(expected))
        equal(Json.encode(game:getState().runState.frozenUnlockPool), Json.encode(before.frozenUnlockPool))
        truthy(completeWave(game, 4, "defeat", "fixture_defeat"))
        local result, gen = game:getState(), generation(checkpoint)
        truthy(game:requestNewRun())
        truthy(game:cancelNewRun())
        equal(Json.encode(game:getState().runState), Json.encode(result.runState))
        truthy(game:requestNewRun())
        storage.writeMode = "fail_before"
        equal(game:confirmNewRun(), false)
        equal(Json.encode(game:getState().runState), Json.encode(result.runState))
        local attempt = storage.writeAttempts[#storage.writeAttempts]
        storage.writeMode = nil
        equal(game:retrySave().status, "applied")
        equal(storage.writeAttempts[#storage.writeAttempts].data, attempt.data)
        local run = game:getState().runState
        equal(#run.frozenUnlockPool.moduleIds, gold == 19 and 25 or 26)
        equal(#run.modules, 0)
        equal(run.baseModuleSlots, 4)
        equal(generation(checkpoint), gen + 1)
        equal(game:getState().moduleUnlockById.M43.inCurrentRunPool, true)
        local options = { visitId = "S00", frozenUnlockPool = run.frozenUnlockPool,
            acquiredModuleIds = {}, rngState = Rng.new(777):getState() }
        equal(Json.encode(Shop.createVisit(game.defs, options)), Json.encode(Shop.createVisit(game.defs, options)))
    end
end)

local function assertM43DraftProjection(view, draft, kind, label)
    local empty = assert(view:findTextRole("m43_draft_empty"), label .. " empty projection missing")
    local damage = assert(view:findTextRole("m43_draft_damage"), label .. " damage projection missing")
    equal(empty.value, string.format("여유 빈%d→%d", draft.spareCircuitBefore.emptySlots, draft.spareCircuitAfter.emptySlots))
    equal(damage.value, string.format("피해+%d→+%d%%", draft.spareCircuitBefore.bonusPercentPoints,
        draft.spareCircuitAfter.bonusPercentPoints))
    local x, y, w, bottom = kind == "purchase" and 379 or 399, kind == "purchase" and 223 or 217,
        kind == "purchase" and 80 or 60, kind == "purchase" and 243 or 239
    equal(empty.x, x); equal(empty.y, y); equal(empty.width, w)
    equal(damage.x, x); equal(damage.y, y + 10); equal(damage.width, w)
    local confirm = assert(view:findButton(kind == "purchase" and "confirm_purchase" or "confirm_inventory_transaction"))
    local cancel = assert(view:findButton(kind == "purchase" and "cancel_purchase" or "cancel_inventory_transaction"))
    equal(confirm.x, 211); equal(confirm.y, kind == "purchase" and 222 or 217)
    equal(confirm.w, kind == "purchase" and 92 or 104); equal(confirm.h, kind == "purchase" and 21 or 22)
    equal(cancel.x, kind == "purchase" and 309 or 321); equal(cancel.y, confirm.y)
    equal(cancel.w, kind == "purchase" and 64 or 72); equal(cancel.h, confirm.h)
    for scale = 1, 3 do
        local rects = {}
        for _, text in ipairs({ empty, damage }) do
            local font = view:_font(text.size * scale)
            local _, rows = font:getWrap(text.value, text.width * scale)
            equal(#rows, 1, label .. " row wraps at " .. scale)
            truthy(font:hasGlyphs(text.value), label .. " glyphs at " .. scale)
            truthy(font:getWidth(text.value) <= w * scale, label .. " actual width")
            local bounds = view:textBlockBounds(text, scale)
            truthy(bounds.bottom <= bottom * scale, label .. " actual bottom")
            rects[#rects + 1] = { x = text.x * scale, y = text.y * scale,
                w = font:getWidth(text.value), h = font:getHeight() }
        end
        truthy(rects[1].y + rects[1].h <= rects[2].y, label .. " projection rows overlap")
        local function overlaps(a, b)
            return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
        end
        for _, rect in ipairs(rects) do
            for _, button in ipairs(view.buttons) do
                truthy(not overlaps(rect, { x = button.x * scale, y = button.y * scale,
                    w = button.w * scale, h = button.h * scale }), label .. " projection overlaps button " .. button.label)
            end
            for _, text in ipairs(view.texts) do
                if text ~= empty and text ~= damage then
                    local font = view:_font(text.size * scale)
                    local _, rows = font:getWrap(text.value, text.width * scale)
                    for index, row in ipairs(rows) do
                        local width = font:getWidth(row)
                        local startX = text.x * scale
                        if text.align == "center" then startX = startX + (text.width * scale - width) / 2 end
                        if text.align == "right" then startX = startX + text.width * scale - width end
                        truthy(not overlaps(rect, { x = startX,
                            y = text.y * scale + (index - 1) * font:getHeight() * font:getLineHeight(),
                            w = width, h = font:getHeight() }), label .. " overlaps existing text " .. text.value)
                    end
                end
            end
        end
    end
end

local function m43DraftBranchChecks()
    local game, storage, checkpoint = newGame()
    m43EligibleW03(game, 19)
    truthy(completeWave(game, 3)); truthy(completeWave(game, 4, "defeat", "fixture_defeat"))
    truthy(game:requestNewRun()); truthy(game:confirmNewRun())
    local view, input, findAction, clickButton, visibleText = assembledUi(game)
    local base = game:getState().runState
    local function install(ids, placed, offer)
        local run = Content.clone(base)
        run.gold, run.modules, run.acquiredModuleIds, run.towerInstances = 200, {}, {}, {}
        for _, id in ipairs(ids) do
            run.modules[#run.modules + 1] = { moduleId = id, paidGold = game.defs.modulesById[id].price, growth = 0 }
            run.acquiredModuleIds[id] = true
        end
        for index = 1, math.max(2, placed) do
            run.towerInstances[#run.towerInstances + 1] = { instanceId = index,
                typeId = ({ "T01", "T02", "T03", "T04" })[(index - 1) % 4 + 1], paidGold = 9,
                patchIds = {}, placement = index <= placed and { x = index - 1, y = 0 } or nil,
                charge = 0, activated = index <= placed }
        end
        run.nextInstanceId = #run.towerInstances + 1
        run.shopState.offers.module, run.shopState.soldOut.module = offer or "M02", false
        truthy(game:_applyDurableRun(run, "transaction"))
    end
    local function drawUnchanged(label)
        local before, gen, writes = game:getState(), generation(checkpoint), storage.writeCount
        view:draw(before)
        equal(Json.encode(game:getState().runState), Json.encode(before.runState), label .. " draw run")
        equal(Json.encode(game:getState().metaState), Json.encode(before.metaState), label .. " draw meta")
        equal(generation(checkpoint), gen); equal(storage.writeCount, writes)
        assertVisibleFits(view, label)
    end
    local dimensions = love.graphics.getDimensions
    local ok, message = pcall(function()
        for _, size in ipairs({ { 480, 270 }, { 960, 540 }, { 1440, 810 }, { 800, 600 } }) do
            love.graphics.getDimensions = function() return size[1], size[2] end
            for _, placed in ipairs({ 6, 8 }) do
                install({ "M43", "M05" }, placed, "M06")
                truthy(game:selectOffer("module")); drawUnchanged("M43 M06 purchase " .. placed)
                local draft = game:getState().purchaseDraft
                equal(draft.requiredRecallCount, placed - 6)
                assertM43DraftProjection(view, draft, "purchase", "M06 " .. placed)
                truthy(visibleText():find("수용량 8→6", 1, true))
                truthy(visibleText():find("개체/패치 보존", 1, true) or visibleText():find("수용량 적용", 1, true))
                equal(view:findButton("confirm_purchase").enabled, placed == 6)
                if placed == 8 then
                    truthy(game:setPurchaseRecallSelection(1, true)); truthy(game:setPurchaseRecallSelection(2, true))
                    drawUnchanged("M06 selected recalls")
                    truthy(visibleText():find("선택 2/2", 1, true)); equal(view:findButton("confirm_purchase").enabled, true)
                    assertM43DraftProjection(view, game:getState().purchaseDraft, "purchase", "M06 selected")
                end
                local run, gen = game:getState().runState, generation(checkpoint)
                truthy(clickButton("cancel_purchase")); equal(Json.encode(game:getState().runState), Json.encode(run)); equal(generation(checkpoint), gen)
            end
            for _, offer in ipairs({ "M07", "M33" }) do
                install({ "M43" }, 0, offer)
                truthy(game:selectTower(1)); truthy(game:selectOffer("module")); drawUnchanged("ordinary " .. offer)
                local summary, detail = view:_moduleStatusLines(game:getState(), offer)
                truthy(visibleText():find(summary, 1, true)); if detail then truthy(visibleText():find(detail, 1, true)) end
                assertM43DraftProjection(view, game:getState().purchaseDraft, "purchase", offer)
                truthy(input:keypressed("escape", false)); equal(game:getState().purchaseDraft, nil)
            end
            for _, case in ipairs({ { { "M43", "M05" }, 8, "M05" }, { { "M43", "M01" }, 6, "M01" },
                { { "M43", "M05" }, 6, "M05" }, { { "M43", "M25" }, 0, "M43" } }) do
                install(case[1], case[2])
                truthy(game:beginInventoryTransaction({ kind = "sell_module", moduleId = case[3] }))
                drawUnchanged("sale " .. case[3] .. " placed " .. case[2])
                local draft = game:getState().transactionDraft
                assertM43DraftProjection(view, draft, "sale", "sale " .. case[3])
                truthy(visibleText():find("실지불", 1, true)); truthy(visibleText():find("환급", 1, true))
                truthy(visibleText():find("획득 기록 유지", 1, true) or visibleText():find("영구 해금 유지", 1, true))
                if draft.requiredRecallCount > 0 then
                    truthy(visibleText():find("수용량 8→6", 1, true)); equal(view:findButton("confirm_inventory_transaction").enabled, false)
                    truthy(game:setInventoryRecallSelection(1, true)); truthy(game:setInventoryRecallSelection(2, true))
                    drawUnchanged("sale selected"); truthy(visibleText():find("선택: #1,#2", 1, true) or visibleText():find("선택: #1, #2", 1, true))
                    equal(view:findButton("confirm_inventory_transaction").enabled, true)
                    assertM43DraftProjection(view, game:getState().transactionDraft, "sale", "sale selected")
                else truthy(visibleText():find("포탑 수용량", 1, true)) end
                local run, gen = game:getState().runState, generation(checkpoint)
                local vp = view:viewport(size[1], size[2])
                if size[1] == 800 then equal(input:mousepressed(1, 1, 2), false); truthy(input:mousepressed(vp.x + 2, vp.y + 2, 2))
                else truthy(input:keypressed("escape", false)) end
                equal(game:getState().transactionDraft, nil); equal(Json.encode(game:getState().runState), Json.encode(run)); equal(generation(checkpoint), gen)
            end
            install({}, 0, "M07"); truthy(game:selectTower(1)); truthy(game:selectOffer("module")); drawUnchanged("no M43")
            equal(view:findTextRole("m43_draft_empty"), nil); equal(view:findTextRole("m43_draft_damage"), nil)
            local summary, detail = view:_moduleStatusLines(game:getState(), "M07")
            truthy(visibleText():find(summary, 1, true)); truthy(visibleText():find(detail, 1, true)); truthy(game:cancelPurchase())
        end
        -- Invalid preview does not render an invented zero-after projection.
        install({ "M43" }, 0, "M06"); local run = game:getState().runState; run.gold = 0
        truthy(game:_applyDurableRun(run, "transaction")); truthy(game:selectOffer("module")); drawUnchanged("invalid preview")
        equal(view:findTextRole("m43_draft_empty"), nil); equal(view:findTextRole("m43_draft_damage"), nil)
        truthy(game:cancelPurchase())
    end)
    love.graphics.getDimensions = dimensions
    if not ok then error(message, 0) end
    io.write("FIXTURE C08 repair2 QF01-QF04 scale1/2/3 letterbox purchase/sale branches drawWrites=0 hitActionsPreserved=true\n")
end

test("M43 T11 seeded real offer price slot cancellation save retry sale and acquired exclusion", function()
    local game, storage, checkpoint = newGame()
    m43EligibleW03(game, 19)
    truthy(completeWave(game, 3))
    truthy(completeWave(game, 4, "defeat", "fixture_defeat"))
    truthy(game:requestNewRun()); truthy(game:confirmNewRun())
    local candidate = game:getState().runState
    local seed
    for value = 1, 10000 do
        local visit = Shop.createVisit(game.defs, { visitId = "S00", frozenUnlockPool = candidate.frozenUnlockPool,
            acquiredModuleIds = {}, rngState = Rng.new(value):getState() })
        if visit.offers.module == "M43" then seed, candidate.shopState = value, visit; break end
    end
    truthy(seed)
    candidate.gold = 11
    truthy(game:_applyDurableRun(candidate, "transaction"))
    truthy(game:selectOffer("module"))
    equal(game:getState().purchaseDraft.error, "insufficient_gold")
    equal(game:confirmPurchase(), false)
    truthy(game:cancelPurchase())
    candidate = game:getState().runState
    candidate.gold = 40
    candidate.modules = { { moduleId = "M25", paidGold = 8, growth = 0 } }
    candidate.acquiredModuleIds.M25 = true
    truthy(game:_applyDurableRun(candidate, "transaction"))
    truthy(game:selectOffer("module"))
    local draft = game:getState().purchaseDraft
    equal(draft.cost, 12)
    equal(draft.spareCircuitAfter.bonusPercentPoints, 24)
    local draftView = assembledUi(game)
    draftView:draw(game:getState())
    assertM43DraftProjection(draftView, draft, "purchase", "M43 own-slot purchase")
    local summary, detail = draftView:_moduleStatusLines(game:getState(), "M43")
    local hasSummary, hasDetail = false, false
    for _, text in ipairs(draftView.texts) do hasSummary = hasSummary or text.value == summary; hasDetail = hasDetail or text.value == detail end
    truthy(hasSummary); truthy(hasDetail)
    truthy(game:cancelPurchase())
    equal(game:getState().moduleStatusById.M43.bonusPercentPoints, 0)
    truthy(game:selectOffer("module"))
    storage.writeMode = "fail_before"
    equal(game:confirmPurchase(), false)
    equal(game:getState().moduleStatusById.M43.bonusPercentPoints, 0)
    local attempt = storage.writeAttempts[#storage.writeAttempts]
    storage.writeMode = nil
    equal(game:retrySave().status, "applied")
    equal(storage.writeAttempts[#storage.writeAttempts].data, attempt.data)
    equal(game:getState().runState.gold, 28)
    equal(findModuleEntry(game:getState().runState, "M43").paidGold, 12)
    equal(game:getState().moduleStatusById.M43.bonusPercentPoints, 24)
    truthy(game:beginInventoryTransaction({ kind = "sell_module", moduleId = "M25" }))
    equal(game:getState().transactionDraft.spareCircuitAfter.bonusPercentPoints, 36)
    truthy(game:confirmInventoryTransaction())
    truthy(game:beginInventoryTransaction({ kind = "sell_module", moduleId = "M43" }))
    equal(game:getState().transactionDraft.refundGold, 6)
    equal(game:getState().transactionDraft.spareCircuitAfter.bonusPercentPoints, 0)
    truthy(game:confirmInventoryTransaction())
    equal(game:getState().moduleUnlockById.M43.permanentlyUnlocked, true)
    equal(game:getState().runState.acquiredModuleIds.M43, true)
    equal(game:getState().moduleStatusById.M43.bonusPercentPoints, 0)
    for _ = 1, 3 do truthy(game:rerollShop()); truthy(game:getState().runState.shopState.offers.module ~= "M43") end
    io.write("FIXTURE M43 T11 actualOffer=M43 seed=", tostring(seed), " paid=12 refund=6 acquiredExcluded=true\n")
end)

test("M43 T12 real Battle Game completion with legal placement awards both rights atomically", function()
    local game, _, checkpoint = newGame({ shopSeed = 28 })
    m43EligibleW03(game, 20, 40)
    truthy(game:selectTower(1)); truthy(game:placeSelected(0, 2))
    truthy(game:startWave())
    local battle, gen = game.battle, generation(checkpoint)
    for _ = 1, 6000 do if game:getState().phase ~= "COMBAT" then break end; game:update(1 / 30) end
    local after = game:getState()
    equal(after.phase, "SHOP")
    equal(battle.result.kind, "wave_complete")
    equal(battle.observations.spawned, 22)
    truthy(after.runState.hp > 0)
    equal(after.lastReceipt.reward.moduleById.M25, 2)
    equal(table.concat(after.metaState.unlockedModuleIds, ","), "M28,M43")
    equal(generation(checkpoint), gen + 1)
    local view = assembledUi(game)
    view:draw(after); assertM43Guide(view, "actual W03")
    io.write("FIXTURE M43 T12 actualBattle W03 spawned=22 tick=", tostring(battle.tick),
        " hp=", tostring(after.runState.hp), " legalPlacement=true rights=M28,M43\n")
end)

test("M43 T13 three tabs viewport letterbox capture simultaneous feedback draft error and Back", function()
    m43DraftBranchChecks()
    local game, storage, checkpoint = newGame()
    local view, input, findAction, clickButton, visibleText = assembledUi(game)
    local dimensions = love.graphics.getDimensions
    local ok, message = pcall(function()
        for _, size in ipairs({ { 480, 270 }, { 960, 540 }, { 1440, 810 }, { 800, 600 } }) do
            love.graphics.getDimensions = function() return size[1], size[2] end
            view:draw(game:getState())
            local before, gen = game:getState(), generation(checkpoint)
            local offer = assert(findAction("select_offer", function(a) return a.kind == "module" end))
            truthy(clickButton("open_tower_unlocks")); view:draw(game:getState())
            for _, tab in ipairs({ "tower", "deposit", "spare" }) do truthy(clickButton("unlock_lookup_tab", function(a) return a.tab == tab end)); view:draw(game:getState()) end
            truthy(view:findTextRole("module_unlock_M43_permanent").value:find("영구 잠김", 1, true))
            truthy(view:findTextRole("module_unlock_M43_attempt").value:find("장착1개 이상 필요", 1, true))
            assertVisibleFits(view, "M43 locked lookup " .. size[1])
            local vp = view:viewport(size[1], size[2])
            truthy(input:mousepressed(vp.x + 12 * vp.scale, vp.y + 32 * vp.scale, 1))
            truthy(input:mousepressed(vp.x + (offer.x + 2) * vp.scale, vp.y + (offer.y + 2) * vp.scale, 1))
            equal(input:keypressed("return", false), false)
            equal(Json.encode(game:getState().runState), Json.encode(before.runState))
            equal(Json.encode(game:getState().metaState), Json.encode(before.metaState))
            equal(generation(checkpoint), gen)
            if size[1] == 800 then equal(input:mousepressed(1, 1, 2), false); truthy(input:mousepressed(vp.x + 2, vp.y + 2, 2))
            else truthy(input:keypressed("escape", false)) end
            equal(view:hasTowerUnlocks(), false)
        end
        m43EligibleW03(game)
        truthy(completeWave(game, 3))
        for _, size in ipairs({ { 480, 270 }, { 960, 540 }, { 1440, 810 } }) do
            love.graphics.getDimensions = function() return size[1], size[2] end
            view:draw(game:getState()); assertM43Guide(view, "combined " .. size[1]); assertVisibleFits(view, "combined")
        end
        truthy(clickButton("open_tower_unlocks")); view:draw(game:getState())
        truthy(clickButton("unlock_lookup_tab", function(a) return a.tab == "spare" end)); view:draw(game:getState())
        truthy(view:findTextRole("module_unlock_M43_permanent").value:find("영구 해금됨", 1, true))
        truthy(view:findTextRole("module_unlock_M43_pool").value:find("이번 판 후보 제외", 1, true))
        truthy(input:keypressed("escape", false)); view:draw(game:getState())
        truthy(clickButton("select_offer", function(a) return a.kind == "tower" end)); view:draw(game:getState())
        equal(view:findTextRole("new_tower_unlock_feedback"), nil)
        truthy(input:keypressed("escape", false))
        truthy(game:beginInventoryTransaction({ kind = "sell_module", moduleId = "M25" })); view:draw(game:getState())
        equal(view:findTextRole("new_tower_unlock_feedback"), nil)
        truthy(input:keypressed("escape", false))
        truthy(completeWave(game, 4))
        -- W05 preserves existing tower feedback together with newly earned modules.
        local triple = newGame()
        for index = 1, 4 do truthy(completeWave(triple, index)) end
        local run = triple:getState().runState
        run.gold, run.modules, run.acquiredModuleIds.M25 = 20, { { moduleId = "M25", paidGold = 8, growth = 0 } }, true
        truthy(triple:_applyDurableRun(run, "transaction")); truthy(completeWave(triple, 5))
        local tripleView = assembledUi(triple)
        tripleView:draw(triple:getState()); assertM43Guide(tripleView, "T05 M28 M43")
        truthy(tripleView:findTextRole("notice").value:find("저격 포탑", 1, true))
        truthy(game:startWave()); storage.writeMode = "fail_before"; equal(finishStartedWave(game, 5), false)
        view:draw(game:getState()); equal(view:findTextRole("new_tower_unlock_feedback"), nil)
        truthy(view:findButton("retry_save")); equal(view:openTowerUnlocks(game:getState()), false)
        storage.writeMode = nil; equal(game:retrySave().status, "applied")
    end)
    love.graphics.getDimensions = dimensions
    if not ok then error(message, 0) end
end)

local function m46WindowPoint(view,x,y)
    local w,h=love.graphics.getDimensions(); local v=view:viewport(w,h)
    return v.x+x*v.scale,v.y+y*v.scale
end

local function m46PrepareWave(game,index,hp,gold,withSpare)
    for wave=1,index-1 do
        local run=game:getState().runState; run.hp,run.gold=19,0
        truthy(game:_applyDurableRun(run,"transaction")); truthy(completeWave(game,wave))
    end
    local run=game:getState().runState; run.hp,run.gold=hp,gold or 0
    if withSpare then
        run.modules={{moduleId="M25",paidGold=8,growth=0}}; run.acquiredModuleIds.M25=true
        if run.shopState.offers.module=="M25" then run.shopState.offers.module="M02" end
    end
    truthy(game:_applyDurableRun(run,"transaction"))
end

local function m46EarnedOffer(hp)
    local game,storage,checkpoint=newGame(); m46PrepareWave(game,3,5,0,false)
    truthy(completeWave(game,3)); truthy(completeWave(game,4,"defeat","fixture_defeat"))
    truthy(game:requestNewRun()); truthy(game:confirmNewRun())
    local run=game:getState().runState; run.hp,run.gold=hp or 5,40
    for seed=1,10000 do
        local visit=Shop.createVisit(game.defs,{visitId="S00",frozenUnlockPool=run.frozenUnlockPool,
            acquiredModuleIds={},rngState=Rng.new(seed):getState()})
        if visit.offers.module=="M46" then run.shopState=visit; break end
    end
    equal(run.shopState.offers.module,"M46"); truthy(game:_applyDurableRun(run,"transaction"))
    return game,storage,checkpoint
end

test("M46 I01 both unlock routes commit freeze pool offers RNG and only successful NEW_RUN adds candidate", function()
    for _,route in ipairs({{3,5},{9,20}}) do
        local game,storage,checkpoint=newGame(); m46PrepareWave(game,route[1],route[2],0,false)
        local before=game:getState().runState
        local expected=Shop.createVisit(game.defs,{visitId=route[1]==3 and "S01" or "S03",
            frozenUnlockPool=before.frozenUnlockPool,acquiredModuleIds=before.acquiredModuleIds,rngState=before.shopState.rngState})
        truthy(completeWave(game,route[1]))
        local after=game:getState(); equal(table.concat(after.metaState.unlockedModuleIds,","),"M46")
        equal(Json.encode(after.runState.frozenUnlockPool),Json.encode(before.frozenUnlockPool))
        equal(Json.encode(after.runState.shopState),Json.encode(expected)); equal(#after.runState.modules,0)
        equal(after.moduleUnlockById.M46.inCurrentRunPool,false)
        truthy(completeWave(game,route[1]+1,"defeat","fixture_defeat"))
        local result,gen=game:getState(),generation(checkpoint)
        truthy(game:requestNewRun()); truthy(game:cancelNewRun())
        equal(Json.encode(game:getState().runState),Json.encode(result.runState))
        truthy(game:requestNewRun()); storage.writeMode="fail_before"; equal(game:confirmNewRun(),false)
        equal(Json.encode(game:getState().runState),Json.encode(result.runState))
        local attempt=storage.writeAttempts[#storage.writeAttempts]; storage.writeMode=nil
        equal(game:retrySave().status,"applied"); equal(storage.writeAttempts[#storage.writeAttempts].data,attempt.data)
        equal(generation(checkpoint),gen+1); equal(#game:getState().runState.frozenUnlockPool.moduleIds,25)
        equal(game:getState().moduleUnlockById.M46.inCurrentRunPool,true); equal(#game:getState().runState.modules,0)
        equal(game:getState().runState.acquiredModuleIds.M46,nil)
        io.write("FIXTURE M46 I01 wave=",tostring(route[1])," startHP=",tostring(route[2])," earned=M46 current24 next25 free=0\n")
    end
end)

test("M46 I02 three rights stay atomic through write readback repeated failures and announce once", function()
    for _,mode in ipairs({"fail_before","fail_readback"}) do
        local game,storage,checkpoint=newGame(); m46PrepareWave(game,3,5,20,true)
        truthy(game:startWave()); local before,gen=game:getState(),generation(checkpoint)
        local view=assembledUi(game); storage.writeMode=mode
        equal(finishStartedWave(game,3),false); local failed=game:getState()
        equal(Json.encode(failed.metaState),Json.encode(before.metaState)); equal(#failed.newModuleUnlocks,0)
        equal(failed.notice:find("영구 해금",1,true),nil); view:draw(failed)
        equal(view:findTextRole("new_tower_unlock_feedback"),nil); equal(view:findTextRole("module_unlock_common_feedback"),nil)
        local pending=assert(game.session.pending.candidate); local encoded=pending.encodedEnvelope
        local payload=Json.decode(Json.decode(encoded).payloadJson)
        equal(table.concat(payload.metaState.unlockedModuleIds,","),"M28,M43,M46")
        equal(game:retrySave().status,"save_error"); equal(storage.writeAttempts[#storage.writeAttempts].data,encoded)
        equal(#game:getState().newModuleUnlocks,0)
        storage.writeMode,storage.failReadPath=nil,nil; equal(game:retrySave().status,"applied")
        local after=game:getState(); equal(table.concat(after.metaState.unlockedModuleIds,","),"M28,M43,M46")
        equal(#after.newModuleUnlocks,3); equal(generation(checkpoint),gen+1)
        equal(after.moduleUnlockById.M46.inCurrentRunPool,false); equal(#after.runState.frozenUnlockPool.moduleIds,24)
        equal(finishStartedWave(game,3),false); equal(game:retrySave().status,"rejected"); equal(generation(checkpoint),gen+1)
        equal(#game:getState().newModuleUnlocks,3)
        local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,
            identityProvider=function() error("restore must not create run") end})
        equal(#restored:getState().newModuleUnlocks,0); equal(#restored:getState().metaState.unlockedModuleIds,3)
        truthy(completeWave(game,4,"defeat","fixture_defeat")); truthy(game:requestNewRun()); truthy(game:confirmNewRun())
        equal(#game:getState().runState.frozenUnlockPool.moduleIds,27); equal(#game:getState().runState.modules,0)
        io.write("FIXTURE M46 I02 mode=",mode," atomic3 exactRetry=true next27 announceOnce=true\n")
    end
end)

test("M46 I03 six legacy Game restores never write infer I46 or widen offers and next save upgrades", function()
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1"}
    for _,version in ipairs(versions) do
        local source,storage,checkpoint=newGame(); local payload=checkpoint:loadCheckpoint().payload
        local run=payload.runState; run.contentVersion,run.hp,run.gold=version,5,29
        run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={{moduleId="M01",paidGold=8,growth=0}}; run.acquiredModuleIds={M01=true}; run.shopState.offers.module="M02"
        payload.metaState.unlockedModuleIds={}
        if version=="DR-SLICE-001-r2" then run.developmentComplete=false; run.shopState.fixtureIndex=1 end
        if version=="DR-MOD-I28-r1" or version=="DR-MOD-I43-r1" then
            payload.metaState.unlockedModuleIds={"M28"}; run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M28"
            payload.metaState.unlockedTowerIds[#payload.metaState.unlockedTowerIds+1]="T05"
        end
        if version=="DR-MOD-I43-r1" then
            payload.metaState.unlockedModuleIds[2]="M43"; run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M43"
        end
        local shop,pool,modules=Json.encode(run.shopState),Json.encode(run.frozenUnlockPool),Json.encode(run.modules)
        storage.files={}; writeShaEnvelope(storage,"save-b.json",34,version,payload)
        local bytes,writes=storage.files['save-b.json'],storage.writeCount
        local game=Game.new({defs=source.defs,checkpointStore=checkpoint,identityProvider=function() return {runId="m46-next",shopSeed=901} end})
        local restored=game:getState(); equal(storage.writeCount,writes); equal(storage.files['save-b.json'],bytes)
        equal(restored.moduleUnlockById.M46.permanentlyUnlocked,false); equal(#restored.newModuleUnlocks,0)
        equal(Json.encode(restored.runState.shopState),shop); equal(Json.encode(restored.runState.frozenUnlockPool),pool)
        equal(Json.encode(restored.runState.modules),modules); equal(restored.runState.gold,29); equal(restored.runState.hp,5)
        equal(Json.encode(restored.metaState.unlockedModuleIds),Json.encode(payload.metaState.unlockedModuleIds))
        truthy(game:closeShop().status=="applied"); truthy(game:startWave()); equal(generation(checkpoint),35)
        local newest=checkpoint:loadCheckpoint(); equal(newest.payload.runState.contentVersion,game.defs.version)
        equal(Json.encode(newest.payload.runState.shopState.offers),Json.encode(payload.runState.shopState.offers))
        equal(Json.encode(newest.payload.runState.shopState.rngState),Json.encode(payload.runState.shopState.rngState))
        truthy(finishStartedWave(game,1,"defeat","fixture_defeat")); truthy(game:requestNewRun()); truthy(game:confirmNewRun())
        equal(#game:getState().runState.frozenUnlockPool.moduleIds,24+#payload.metaState.unlockedModuleIds)
        equal(game:getState().moduleUnlockById.M46.inCurrentRunPool,false)
        if #payload.metaState.unlockedModuleIds>0 then equal(game:getState().towerUnlockById.T05.permanentlyUnlocked,true) end
        io.write("FIXTURE M46 I03 legacy=",version," loadWrites=0 noInferI46=true saveUpgrade=true\n")
    end
end)

test("M46 I04 lawful purchase live Battle HP detail and sale UI keep permanent acquired history", function()
    local game,storage,checkpoint=m46EarnedOffer(6)
    truthy(game:selectTower(1)); truthy(game:placeSelected(0,2))
    local run=game:getState().runState; run.hp=5; truthy(game:_applyDurableRun(run,"transaction"))
    local view,input,_,click,text=assembledUi(game); view:draw(game:getState())
    truthy(click("select_offer",function(a) return a.kind=="module" end)); view:draw(game:getState())
    local draft=game:getState().purchaseDraft
    equal(draft.cost,12); equal(draft.slotBefore,0); equal(draft.slotAfter,1)
    equal(draft.emergencyBefore.bonusPercentPoints,0); equal(draft.emergencyAfter.bonusPercentPoints,40)
    truthy(view:findTextRole("m46_draft_effect").value:find("피해+0→+40%",1,true)); assertVisibleFits(view,"M46 purchase")
    truthy(input:keypressed("escape",false)); equal(game:getState().purchaseDraft,nil)
    truthy(game:selectOffer("module")); storage.writeMode="fail_before"; equal(game:confirmPurchase(),false)
    equal(game:getState().moduleStatusById.M46.installed,false)
    storage.writeMode=nil; equal(game:retrySave().status,"applied")
    equal(game:getState().runState.gold,28); equal(findModuleEntry(game:getState().runState,"M46").paidGold,12)
    equal(game:getState().moduleStatusById.M46.bonusPercentPoints,40)
    truthy(view:openInventoryManagement("module")); truthy(view:selectManagedModule("M46")); view:draw(game:getState())
    truthy(text():find("현재 HP5",1,true)); truthy(text():find("영구 해금 유지",1,true)); assertVisibleFits(view,"M46 installed")
    truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M46"})); view:draw(game:getState())
    truthy(view:findTextRole("m46_draft_effect").value:find("피해+40→+0%",1,true)); assertVisibleFits(view,"M46 sale")
    truthy(game:confirmInventoryTransaction()); equal(game:getState().runState.gold,34)
    equal(game:getState().moduleStatusById.M46.bonusPercentPoints,0); equal(game:getState().runState.acquiredModuleIds.M46,true)
    equal(game:getState().moduleUnlockById.M46.permanentlyUnlocked,true)
    for _=1,3 do truthy(game:rerollShop()); truthy(game:getState().runState.shopState.offers.module~="M46") end
    -- A second lawful run exercises Game's live Battle projection independently of the transaction fixture.
    local live=m46EarnedOffer(6); truthy(live:selectTower(1)); truthy(live:placeSelected(0,2))
    truthy(live:selectOffer("module")); truthy(live:confirmPurchase()); truthy(live:startWave())
    local battle=live.battle; battle.spawnSchedule,battle.nextSpawnIndex={},1
    local target=battle.enemies[1]; target.baseSpeed,target.hp,target.maxHp=0,1000,1000
    local leak=Content.clone(target); leak.enemyId,leak.spawnOrdinal,leak.s="leak",2,leak.totalLength
    battle.enemies[2],battle.enemyById.leak=leak,leak; battle.towers[1].charge=1
    live:update(1/60); local state=live:getState()
    equal(state.runState.hp,6); equal(state.battle.hp,5); equal(state.moduleStatusById.M46.currentHp,5)
    equal(state.moduleStatusById.M46.bonusPercentPoints,40)
    local liveView=assembledUi(live); liveView:draw(state)
    local summary=liveView:_moduleStatusLines(state,"M46"); truthy(summary:find("현재 HP5",1,true))
    equal(liveView:openTowerUnlocks(state),false)
end)

test("M46 I05 four locked earned offered lookup tabs own clicks and one layer Back without writes", function()
    for _,earned in ipairs({false,true}) do
        local game,storage,checkpoint
        if earned then game,storage,checkpoint=m46EarnedOffer(5) else game,storage,checkpoint=newGame() end
        local view,input,findAction,click,text=assembledUi(game); view:draw(game:getState())
        local before,writes,gen=game:getState(),storage.writeCount,generation(checkpoint)
        truthy(click("open_tower_unlocks")); view:draw(game:getState())
        for _,tab in ipairs({"tower","deposit","spare","emergency"}) do
            truthy(click("unlock_lookup_tab",function(a) return a.tab==tab end)); view:draw(game:getState())
        end
        truthy(text():find(earned and "영구 해금됨" or "영구 잠김",1,true))
        truthy(text():find("시작HP1–5·이번 누수0 또는 W09+완료HP20",1,true))
        truthy(text():find("현재HP1–5 배치 타워 피해+40%",1,true))
        truthy(text():find(earned and "이번 판 후보 포함" or "이번 판 후보 제외",1,true))
        if earned then truthy(text():find("현재 상점 제안에 있음",1,true)) end
        local blocked=findAction("select_offer",function(a) return a.kind=="module" end)
        if blocked then local vx,vy=m46WindowPoint(view,blocked.x+3,blocked.y+3); input:mousepressed(vx,vy,1) end
        equal(game:getState().purchaseDraft,nil); truthy(view:hasTowerUnlocks())
        equal(Json.encode(game:getState().runState),Json.encode(before.runState)); equal(Json.encode(game:getState().metaState),Json.encode(before.metaState))
        equal(storage.writeCount,writes); equal(generation(checkpoint),gen); assertVisibleFits(view,"M46 lookup")
        truthy(input:keypressed("escape",false)); equal(view:hasTowerUnlocks(),false)
        view:draw(game:getState()); truthy(click("open_tower_unlocks")); view:draw(game:getState())
        local x,y=m46WindowPoint(view,250,180); truthy(input:mousepressed(x,y,2)); equal(view:hasTowerUnlocks(),false)
        truthy(game:startWave()); view:draw(game:getState()); equal(view:openTowerUnlocks(game:getState()),false)
    end
end)

test("M46 I06 single triple and four name feedback actual fonts preserve approved guide geometry", function()
    local dimensions=love.graphics.getDimensions
    local ok,message=pcall(function()
        for _,triple in ipairs({false,true}) do
            local game,storage=newGame(); m46PrepareWave(game,triple and 5 or 3,5,triple and 20 or 0,triple)
            truthy(game:startWave()); storage.writeMode="fail_before"; equal(finishStartedWave(game,triple and 5 or 3),false)
            local view=assembledUi(game); view:draw(game:getState()); equal(view:findTextRole("new_tower_unlock_feedback"),nil)
            storage.writeMode=nil; equal(game:retrySave().status,"applied")
            for scale=1,3 do
                love.graphics.getDimensions=function() return 480*scale,270*scale end
                view:draw(game:getState()); assertVisibleFits(view,"M46 feedback")
                local guide=assert(view:findTextRole("new_tower_unlock_feedback")); equal(guide.x,211); equal(guide.y,73); equal(guide.size,8); equal(guide.width,248)
                truthy(guide.value:find("시작HP1~5·무누수 / W9+완료HP20",1,true)); truthy(guide.value:find("HP1~5 피해+40%",1,true))
                local _,rows=view:_font(guide.size*scale):getWrap(guide.value,guide.width*scale)
                equal(#rows,triple and 3 or 2)
                for row in guide.value:gmatch("[^\n]+") do truthy(view:_font(guide.size*scale):hasGlyphs(row)) end
                truthy(view:textBlockBounds(guide,scale).bottom<=112*scale)
                local common=view:findTextRole("module_unlock_common_feedback"); local notice=view:findTextRole("notice")
                if triple then
                    equal(common.x,211); equal(common.y,22); equal(common.size,8); equal(common.width,248)
                    truthy(view:textBlockBounds(common,scale).bottom<36*scale)
                    truthy(view:textBlockBounds(notice,scale).bottom<22*scale)
                    for _,name in ipairs({"저격 포탑","예치금","여유 회로","비상 출력"}) do truthy(notice.value:find(name,1,true)) end
                else equal(common,nil) end
                truthy(view:openTowerUnlocks(game:getState())); view:setUnlockLookupTab("emergency"); view:draw(game:getState())
                assertVisibleFits(view,"M46 emergency tab"); view:closeTowerUnlocks()
            end
        end
    end)
    love.graphics.getDimensions=dimensions
    if not ok then error(message,0) end
end)

local function m41PrepareWave(game, index, hp, gold)
    m46PrepareWave(game, index, hp or 19, gold or 0, false)
    local run = game:getState().runState
    run.modules = { { moduleId = "M03", paidGold = 10, growth = 0 }, { moduleId = "M08", paidGold = 10, growth = 0 } }
    run.acquiredModuleIds = { M03 = true, M08 = true }
    if run.shopState.offers.module == "M03" or run.shopState.offers.module == "M08" then run.shopState.offers.module = "M02" end
    truthy(game:_applyDurableRun(run, "transaction"))
end

local function m41Offer(game, id)
    local run = game:getState().runState
    for seed = 1, 10000 do
        local visit = Shop.createVisit(game.defs, { visitId = "S00", frozenUnlockPool = run.frozenUnlockPool,
            acquiredModuleIds = run.acquiredModuleIds, rngState = Rng.new(seed):getState() })
        if visit.offers.module == id then run.shopState = visit; break end
    end
    equal(run.shopState.offers.module, id)
    truthy(game:_applyDurableRun(run, "transaction"))
end

local function m41EarnedGame(offerId)
    local game, storage, checkpoint = newGame()
    m41PrepareWave(game, 6, 5, 20); truthy(completeWave(game, 6))
    truthy(completeWave(game, 7, "defeat", "fixture_defeat"))
    truthy(game:requestNewRun()); truthy(game:confirmNewRun())
    local run = game:getState().runState; run.hp, run.gold = 5, 100
    run.modules = { { moduleId = "M03", paidGold = 10, growth = 0 }, { moduleId = "M08", paidGold = 10, growth = 0 } }
    run.acquiredModuleIds = { M03 = true, M08 = true }
    if run.shopState.offers.module == "M03" or run.shopState.offers.module == "M08" then run.shopState.offers.module = "M02" end
    truthy(game:_applyDurableRun(run, "transaction")); m41Offer(game, offerId or "M41")
    return game, storage, checkpoint
end

test("M41 I01 actual Battle and Session preserve start mid composition across restore and forbidden writes", function()
    local game, storage, checkpoint = newGame(); m41PrepareWave(game, 6, 19, 0)
    truthy(game:selectTower(1)); truthy(game:placeSelected(0, 2)); truthy(game:startWave())
    local committed = Json.encode(game.session:getState().runState.modules)
    equal(game:selectOffer("module"), false)
    equal(game:beginInventoryTransaction({ kind = "sell_module", moduleId = "M03" }), false)
    local Battle = require("src.battle")
    local rejected = assert(Battle.step(game.battle, Battle.FIXED_DT, { { type = "sell_module", moduleId = "M03" } }))
    local sawRejection = false
    for _, event in ipairs(rejected) do if event.type == "command_rejected" then sawRejection = true end end
    truthy(sawRejection); equal(Json.encode(game.battle.run.modules), committed)
    local writes = storage.writeCount
    local restored = Game.new({ defs = game.defs, checkpointStore = checkpoint, identityProvider = function() error("restore identity") end })
    equal(storage.writeCount, writes); equal(restored:getState().phase, "COMBAT")
    equal(Json.encode(restored.session:getState().runState.modules), committed)
    truthy(restored:resumeAll())
    local battle = restored.battle; battle.spawnSchedule, battle.nextSpawnIndex = {}, 1
    for _, enemy in ipairs(battle.enemies) do enemy.alive = false end
    restored:update(Battle.FIXED_DT)
    equal(restored:getState().moduleUnlockById.M41.permanentlyUnlocked, true)
    equal(Json.encode(restored:getState().runState.modules), committed)
    equal(restored:getState().moduleUnlockById.M46.permanentlyUnlocked, false)

    local live = m41EarnedGame("M41")
    truthy(live:selectTower(1)); truthy(live:placeSelected(0, 2))
    truthy(live:selectOffer("module")); truthy(live:confirmPurchase()); truthy(live:startWave())
    battle = live.battle; battle.spawnSchedule, battle.nextSpawnIndex = {}, 1
    local enemy = battle.enemies[1]; enemy.baseSpeed, enemy.hp, enemy.maxHp = 0, 1000, 1000
    battle.towers[1].charge = 1; live:update(Battle.FIXED_DT)
    truthy(#battle.projectiles > 0)
    close(battle.projectiles[1].launchBaseDamage, 12 * (1 + 0.05 + 0.16))
    equal(#battle.run.modules, 3); equal(#live.session:getState().runState.modules, 3)
    io.write("FIXTURE M41 I01 committedMid2 restoreReadOnly actualBattleAdditive=true\n")
end)

test("M41 I02 four unlocks commit once after exact retry and enter only successful next run", function()
    for _, mode in ipairs({ "fail_before", "fail_readback" }) do
        local game, storage, checkpoint = newGame(); m41PrepareWave(game, 6, 5, 20)
        truthy(game:startWave()); local before, gen = game:getState(), generation(checkpoint)
        local expected = Shop.createVisit(game.defs, { visitId = "S02", frozenUnlockPool = before.runState.frozenUnlockPool,
            acquiredModuleIds = before.runState.acquiredModuleIds, rngState = before.runState.shopState.rngState })
        storage.writeMode = mode; equal(finishStartedWave(game, 6), false)
        equal(Json.encode(game:getState().metaState), Json.encode(before.metaState)); equal(#game:getState().newModuleUnlocks, 0)
        local encoded = game.session.pending.candidate.encodedEnvelope
        local payload = Json.decode(Json.decode(encoded).payloadJson)
        equal(table.concat(payload.metaState.unlockedModuleIds, ","), "M28,M41,M43,M46")
        equal(game:retrySave().status, "save_error"); equal(storage.writeAttempts[#storage.writeAttempts].data, encoded)
        storage.writeMode, storage.failReadPath = nil, nil; equal(game:retrySave().status, "applied")
        local after = game:getState(); equal(#after.newModuleUnlocks, 4); equal(generation(checkpoint), gen + 1)
        equal(table.concat(after.metaState.unlockedModuleIds, ","), "M28,M41,M43,M46")
        equal(Json.encode(after.runState.frozenUnlockPool), Json.encode(before.runState.frozenUnlockPool))
        equal(Json.encode(after.runState.shopState), Json.encode(expected)); equal(after.moduleUnlockById.M41.inCurrentRunPool, false)
        equal(finishStartedWave(game, 6), false); equal(game:retrySave().status, "rejected")
        local restored = Game.new({ defs = game.defs, checkpointStore = checkpoint, identityProvider = function() error("restore identity") end })
        equal(#restored:getState().newModuleUnlocks, 0); equal(generation(checkpoint), gen + 1)
        truthy(completeWave(game, 7, "defeat", "fixture_defeat")); truthy(game:requestNewRun())
        local result = game:getState(); local resultGen = generation(checkpoint)
        storage.writeMode = "fail_before"; equal(game:confirmNewRun(), false)
        equal(Json.encode(game:getState().runState), Json.encode(result.runState))
        local newBytes = storage.writeAttempts[#storage.writeAttempts].data
        storage.writeMode = nil; equal(game:retrySave().status, "applied")
        equal(storage.writeAttempts[#storage.writeAttempts].data, newBytes); equal(generation(checkpoint), resultGen + 1)
        equal(#game:getState().runState.frozenUnlockPool.moduleIds, #Game.defaultUnlockPool(game.defs).moduleIds + 4)
        equal(game:getState().moduleUnlockById.M41.inCurrentRunPool, true)
        equal(#game:getState().runState.modules, 0); equal(game:getState().runState.acquiredModuleIds.M41, nil)
        io.write("FIXTURE M41 I02 mode=", mode, " atomic4 exactRetry=true next28 free=0\n")
    end
end)

test("M41 I03 seven legacy Game restores keep pools offers rights and upgrade only on next checkpoint", function()
    local versions = { "DR-SLICE-001-r2", "DR-RUN-002-r1", "DR-MOD-S24-r1", "DR-TOWER-U2-r1", "DR-MOD-I28-r1", "DR-MOD-I43-r1", "DR-MOD-I46-r1" }
    for index, version in ipairs(versions) do
        local source, storage, checkpoint = newGame(); local payload = checkpoint:loadCheckpoint().payload
        local run = payload.runState; run.contentVersion, run.hp, run.gold = version, 5, 37
        run.frozenUnlockPool.moduleIds = { "M01", "M02", "M05", "M17", "M25", "M26" }
        run.modules = { { moduleId = "M01", paidGold = 8, growth = 0 } }; run.acquiredModuleIds = { M01 = true }
        run.shopState.offers.module = "M02"; payload.metaState.unlockedModuleIds = {}
        if index == 1 then run.developmentComplete = false; run.shopState.fixtureIndex = 1 end
        if index >= 5 then
            payload.metaState.unlockedModuleIds = { "M28" }; run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds + 1] = "M28"
            payload.metaState.unlockedTowerIds[#payload.metaState.unlockedTowerIds + 1] = "T05"
        end
        if index >= 6 then payload.metaState.unlockedModuleIds[2] = "M43"; run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds + 1] = "M43" end
        if index == 7 then
            payload.metaState.unlockedModuleIds[3] = "M46"; run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds + 1] = "M46"
            run.modules = { { moduleId = "M33", paidGold = 9, growth = 6 }, { moduleId = "M08", paidGold = 11, growth = 0 } }
            run.acquiredModuleIds = { M33 = true, M08 = true }
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds + 1] = "M33"
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds + 1] = "M08"
            run.nextWaveIndex, run.shopState.visitId = 7, "S02"; run.completedWaveIds = Json.object()
            for wave = 1, 6 do run.completedWaveIds[string.format("W%02d", wave)] = true end
            payload.checkpointKind, payload.resumeDescriptor.kind, payload.resumeDescriptor.waveIndex = "waveComplete", "waveComplete", 7
        end
        local shop, pool, modules, progress = Json.encode(run.shopState), Json.encode(run.frozenUnlockPool), Json.encode(run.modules), Json.encode(run.completedWaveIds)
        storage.files = {}; writeShaEnvelope(storage, "save-b.json", 34, version, payload)
        local bytes, writes = storage.files["save-b.json"], storage.writeCount
        local game = Game.new({ defs = source.defs, checkpointStore = checkpoint, identityProvider = function() return { runId = "m41-next", shopSeed = 901 } end })
        local restored = game:getState(); equal(storage.writeCount, writes); equal(storage.files["save-b.json"], bytes)
        equal(restored.moduleUnlockById.M41.permanentlyUnlocked, false); equal(#restored.newModuleUnlocks, 0)
        equal(Json.encode(restored.runState.shopState), shop); equal(Json.encode(restored.runState.frozenUnlockPool), pool)
        equal(Json.encode(restored.runState.modules), modules); equal(Json.encode(restored.runState.completedWaveIds), progress)
        equal(restored.runState.gold, 37); equal(restored.runState.hp, 5)
        equal(Json.encode(restored.metaState.unlockedModuleIds), Json.encode(payload.metaState.unlockedModuleIds))
        truthy(game:closeShop().status == "applied"); truthy(game:startWave()); equal(generation(checkpoint), 35)
        local newest = checkpoint:loadCheckpoint(); equal(newest.payload.runState.contentVersion, game.defs.version)
        local closedShop = Json.decode(shop); closedShop.accessOpen = false
        equal(Json.encode(newest.payload.runState.modules), modules); equal(Json.encode(newest.payload.runState.shopState), Json.encode(closedShop))
        truthy(finishStartedWave(game, run.nextWaveIndex, "defeat", "fixture_defeat"))
        truthy(game:requestNewRun()); truthy(game:confirmNewRun())
        equal(#game:getState().runState.frozenUnlockPool.moduleIds, #Game.defaultUnlockPool(game.defs).moduleIds + #payload.metaState.unlockedModuleIds)
        equal(game:getState().moduleUnlockById.M41.inCurrentRunPool, false)
        io.write("FIXTURE M41 I03 legacy=", version, " loadWrites=0 historicalMidNoInfer=true upgrade=true\n")
    end
end)

test("M41 I04 five lookup tabs and saved multi alerts preserve full detail and input ownership", function()
    local dimensions = love.graphics.getDimensions
    local ok, message = pcall(function()
        for _, earned in ipairs({ false, true }) do
            local game, storage, checkpoint
            if earned then game, storage, checkpoint = m41EarnedGame("M41") else game, storage, checkpoint = newGame() end
            local view, input, find, click, text = assembledUi(game)
            local before, writes, gen = game:getState(), storage.writeCount, generation(checkpoint)
            view:draw(before); truthy(click("open_tower_unlocks")); view:draw(game:getState())
            for _, tab in ipairs({ "tower", "deposit", "spare", "emergency", "midlink" }) do
                truthy(click("unlock_lookup_tab", function(action) return action.tab == tab end)); view:draw(game:getState())
                equal(view.unlockLookupTab, tab); assertVisibleFits(view, "M41 five lookup")
            end
            truthy(text():find("서로 다른 중가≥2종 · 시작부터 완료직전 유지", 1, true))
            truthy(text():find("자신 제외 중가당 배치 피해+8%p(최대32%)", 1, true))
            truthy(text():find(earned and "이번 판 후보 포함" or "이번 판 후보 제외", 1, true))
            if earned then truthy(text():find("현재 제안 있음", 1, true)) end
            local x, y = m46WindowPoint(view, 0, 2); input:mousepressed(x, y, 1)
            equal(storage.writeCount, writes); equal(generation(checkpoint), gen)
            equal(Json.encode(game:getState().runState), Json.encode(before.runState)); equal(game:getState().purchaseDraft, nil)
            truthy(input:keypressed("escape", false)); equal(view:hasTowerUnlocks(), false)
            view:draw(game:getState()); truthy(click("open_tower_unlocks")); view:draw(game:getState())
            x, y = m46WindowPoint(view, 250, 180); truthy(input:mousepressed(x, y, 2)); equal(view:hasTowerUnlocks(), false)
            truthy(game:startWave()); equal(view:openTowerUnlocks(game:getState()), false)
        end
        local game, storage = newGame(); m41PrepareWave(game, 6, 5, 20); truthy(game:startWave())
        storage.writeMode = "fail_before"; equal(finishStartedWave(game, 6), false)
        local view = assembledUi(game); view:draw(game:getState())
        equal(view:findTextRole("new_tower_unlock_feedback"), nil); equal(view:openTowerUnlocks(game:getState()), false)
        storage.writeMode = nil; equal(game:retrySave().status, "applied")
        equal(#game:getState().newModuleUnlocks, 4); equal(#game:getState().newTowerUnlocks, 0)
        for _, mode in ipairs({ "single", "four", "fiveStress" }) do
            local state = game:getState()
            if mode == "single" then state.newModuleUnlocks = { { moduleId = "M41" } } end
            if mode == "fiveStress" then state.newTowerUnlocks = { { towerId = "T05" } } end -- Display stress only: T05 is actually W05.
            for scale = 1, 3 do
                love.graphics.getDimensions = function() return 480 * scale, 270 * scale end
                view:closeTowerUnlocks(); view:draw(state); assertVisibleFits(view, "M41 alerts " .. mode)
                local guide = assert(view:findTextRole("new_tower_unlock_feedback")); equal(guide.size, 8); equal(guide.y, 73)
                local _, rows = view:_font(8 * scale):getWrap(guide.value, 248 * scale); truthy(#rows <= 3)
                truthy(view:textBlockBounds(guide, scale).bottom <= 112 * scale)
                truthy(view:textBlockBounds(view:findTextRole("module_unlock_common_feedback"), scale).bottom < 36 * scale)
                truthy(view:textBlockBounds(view:findTextRole("notice"), scale).bottom < 22 * scale)
                for row in guide.value:gmatch("[^\n]+") do truthy(view:_font(8 * scale):hasGlyphs(row)) end
                truthy(view:openTowerUnlocks(state)); equal(view.unlockLookupTab, "midlink"); view:draw(state)
                local tabs = 0
                for _, button in ipairs(view.buttons) do
                    if button.action.type == "unlock_lookup_tab" then tabs = tabs + 1; equal(button.w, button.action.tab == "deposit" and 32 or 22); equal(button.textSize, 9) end
                end
                equal(tabs, 11); assertVisibleFits(view, "M41 detail")
                local last = view:findTextRole("module_unlock_M41_next_run")
                truthy(view:textBlockBounds(last, scale).bottom <= 264 * scale)
            end
        end
    end)
    love.graphics.getDimensions = dimensions
    if not ok then error(message, 0) end
end)

test("M41 I05 transaction views show M41 and other mid before after cancel failure and sale history", function()
    local game, storage = m41EarnedGame("M41")
    truthy(game:selectTower(1)); truthy(game:placeSelected(0, 2))
    local view, input, find, click, text = assembledUi(game); local before = game:getState()
    view:draw(before); truthy(click("select_offer", function(action) return action.kind == "module" end)); view:draw(game:getState())
    local draft = game:getState().purchaseDraft; equal(draft.cost, 16)
    equal(draft.midLinkBefore.bonusPercentPoints, 0); equal(draft.midLinkAfter.bonusPercentPoints, 16)
    truthy(text():find("배치 피해+0→16%p", 1, true)); assertVisibleFits(view, "M41 purchase")
    local title, effect = view:findTextRole("m41_draft_title"), view:findTextRole("m41_draft_offer_effect")
    equal(title.y, 175); equal(effect.y, 189)
    for scale = 1, 3 do truthy(view:textBlockBounds(title, scale).bottom < effect.y * scale) end
    truthy(input:keypressed("escape", false)); equal(Json.encode(game:getState().runState), Json.encode(before.runState))
    truthy(game:selectOffer("module")); storage.writeMode = "fail_before"; equal(game:confirmPurchase(), false)
    equal(game:getState().moduleStatusById.M41.installed, false)
    storage.writeMode = nil; equal(game:retrySave().status, "applied")
    equal(game:getState().runState.gold, 84); equal(findModuleEntry(game:getState().runState, "M41").paidGold, 16)
    equal(game:getState().moduleStatusById.M41.bonusPercentPoints, 16)
    local managementBefore, managementWrites = game:getState(), storage.writeCount
    truthy(view:openInventoryManagement("module")); truthy(view:selectManagedModule("M41"))
    local dimensions = love.graphics.getDimensions
    local managementOk, managementError = pcall(function()
        for scale = 1, 3 do
            love.graphics.getDimensions = function() return 480 * scale, 270 * scale end
            view:draw(game:getState()) -- The actual draw also calls _renderTexts with this viewport/font scale.
            local saleButton = assert(find("begin_inventory_transaction", function(action) return action.moduleId == "M41" end))
            local rights, paid, detail
            for _, item in ipairs(view.texts) do
                if item.value == "판매 시 피해 0 · 영구 해금 유지 · 이번 판 재획득 불가" then rights = item end
                if item.value == "실지불 16G · 판매 환급 8G" then paid = item end
            end
            rights, paid = assert(rights), assert(paid)
            for _, item in ipairs(view.texts) do
                if item.x == paid.x and item.y == paid.y - 11 then detail = item end
            end
            detail = assert(detail)
            equal(rights.size, 8); equal(rights.y, 214); equal(saleButton.y, 226); equal(saleButton.y + saleButton.h, 246)
            truthy(view:textBlockBounds(detail, scale).bottom <= paid.y * scale, "M41 detail overlaps paid row")
            truthy(view:textBlockBounds(paid, scale).bottom <= rights.y * scale, "M41 paid row overlaps rights")
            truthy(view:textBlockBounds(rights, scale).bottom <= saleButton.y * scale, "M41 rights overlaps sale button")
            for _, item in ipairs(view.texts) do
                if item.x >= 198 and item.y >= 116 then
                    truthy(view:textBlockBounds(item, scale).bottom <= 264 * scale, "M41 management outside main panel")
                end
            end
            for _, button in ipairs(view.buttons) do
                if button.x >= 198 and button.y >= 116 then truthy(button.y + button.h <= 264) end
            end
            assertVisibleFits(view, "M41 management rights and sale")
            truthy(click("begin_inventory_transaction", function(action) return action.moduleId == "M41" end))
            equal(game:getState().transactionDraft.moduleId, "M41"); view:draw(game:getState())
            truthy(input:keypressed("escape", false)); equal(game:getState().transactionDraft, nil)
            equal(storage.writeCount, managementWrites)
            equal(Json.encode(game:getState().runState), Json.encode(managementBefore.runState))
            equal(Json.encode(game:getState().metaState), Json.encode(managementBefore.metaState))
        end
    end)
    love.graphics.getDimensions = dimensions
    if not managementOk then error(managementError, 0) end
    truthy(view:closeInventoryManagement())

    for _, id in ipairs({ "M17", "M46", "M33" }) do
        m41Offer(game, id); truthy(game:selectOffer("module")); view:draw(game:getState())
        draft = game:getState().purchaseDraft; equal(draft.midLinkBefore.bonusPercentPoints, 16); equal(draft.midLinkAfter.bonusPercentPoints, 24)
        truthy(text():find("배치 피해+16→24%p", 1, true)); assertVisibleFits(view, "M41 other mid purchase " .. id)
        if id == "M46" then truthy(text():find("현재HP5", 1, true)) end
        if id == "M33" then truthy(text():find("성장0/30%p", 1, true)) end
        truthy(game:confirmPurchase()); truthy(game:beginInventoryTransaction({ kind = "sell_module", moduleId = id })); view:draw(game:getState())
        truthy(text():find("배치 피해+24→16%p", 1, true)); truthy(text():find("권리/획득 기록 유지", 1, true))
        if id == "M46" then truthy(text():find("HP5", 1, true)) end
        if id == "M33" then truthy(text():find("현재 성장0/30%p", 1, true)) end
        assertVisibleFits(view, "M41 other mid sale " .. id); truthy(game:confirmInventoryTransaction())
        equal(game:getState().runState.acquiredModuleIds[id], true)
    end
    for _, id in ipairs({ "M25", "M06" }) do
        m41Offer(game, id); truthy(game:selectOffer("module")); draft = game:getState().purchaseDraft
        equal(draft.midLinkAfter.otherMidModuleCount, 2); equal(draft.midLinkAfter.bonusPercentPoints, 16)
        truthy(game:cancelPurchase())
    end
    truthy(game:beginInventoryTransaction({ kind = "sell_module", moduleId = "M41" })); view:draw(game:getState())
    equal(game:getState().transactionDraft.midLinkAfter.bonusPercentPoints, 0); truthy(text():find("배치 피해+16→0%p", 1, true))
    assertVisibleFits(view, "M41 self sale"); truthy(game:confirmInventoryTransaction())
    equal(game:getState().moduleStatusById.M41.bonusPercentPoints, 0); equal(game:getState().runState.acquiredModuleIds.M41, true)
    equal(game:getState().moduleUnlockById.M41.permanentlyUnlocked, true)
    local run = game:getState().runState
    for seed = 1, 100 do
        local visit = Shop.createVisit(game.defs, { visitId = "S01", frozenUnlockPool = run.frozenUnlockPool,
            acquiredModuleIds = run.acquiredModuleIds, rngState = Rng.new(seed):getState() })
        truthy(visit.offers.module ~= "M41")
    end
    io.write("FIXTURE M41 I05 purchase16 paidRefund8 additiveMidProjection saleHistory=true\n")
end)

local function m42Module(id, paid, growth)
    return { moduleId = id, paidGold = paid, growth = growth or 0 }
end

local function m42SetModules(run, modules)
    run.modules, run.acquiredModuleIds = Content.clone(modules), {}
    for _, entry in ipairs(modules) do run.acquiredModuleIds[entry.moduleId] = true end
    if run.acquiredModuleIds[run.shopState.offers.module] then run.shopState.offers.module = "M02" end
end

local function m42PrepareWave(game, index, modules, hp, gold)
    while game:getState().runState.nextWaveIndex < index do
        local run = game:getState().runState; run.hp, run.gold = 19, 0
        truthy(game:_applyDurableRun(run, "transaction"))
        truthy(completeWave(game, run.nextWaveIndex))
    end
    local run = game:getState().runState; run.hp, run.gold = hp or 5, gold or 20
    m42SetModules(run, modules); truthy(game:_applyDurableRun(run, "transaction"))
end

local function m42EarnedGame(offerId, modules)
    local game, storage, checkpoint = newGame()
    m42PrepareWave(game, 9, { m42Module("M03",20), m42Module("M08",20) })
    truthy(completeWave(game,9)); equal(#game:getState().newModuleUnlocks,5)
    truthy(completeWave(game,10,"defeat","fixture_defeat"))
    truthy(game:requestNewRun()); truthy(game:confirmNewRun())
    local run = game:getState().runState; run.hp, run.gold = 5,100
    m42SetModules(run, modules or { m42Module("M41",16),m42Module("M42",16),m42Module("M43",12) })
    truthy(game:_applyDurableRun(run,"transaction"))
    if offerId then m41Offer(game,offerId) end
    return game, storage, checkpoint
end

local function m42DrawBoundary(view, state, sale)
    local original = love.graphics.getDimensions
    local ok, message = pcall(function()
        for scale = 1,3 do
            love.graphics.getDimensions = function() return 480*scale,270*scale end
            view:draw(state); assertVisibleFits(view,"M42 actual draw")
            local roles = sale and {"m42_sale_offer_effect","m42_sale_paid","m41_draft_effect","m42_draft_effect","m42_sale_history","m42_sale_capacity","m42_sale_recall"}
                or {"m42_draft_title","m42_draft_offer_effect","m41_draft_effect","m42_draft_effect","m42_draft_detail"}
            local previous
            for _,role in ipairs(roles) do
                local item = view:findTextRole(role)
                if item then
                    truthy(item.size>=8); truthy(view:textBlockBounds(item,scale).bottom<=264*scale,role)
                    if previous then truthy(view:textBlockBounds(previous,scale).bottom<=item.y*scale,previous.role.." overlaps "..role) end
                    for row in item.value:gmatch("[^\n]+") do truthy(view:_font(item.size*scale):hasGlyphs(row),role.." glyph") end
                    previous=item
                end
            end
            local button
            for _,b in ipairs(view.buttons) do if b.action.type==(sale and "confirm_inventory_transaction" or "confirm_purchase") then button=b end end
            truthy(button); equal(button.y,242); truthy(button.y+button.h<=264)
            if previous then truthy(view:textBlockBounds(previous,scale).bottom<=button.y*scale,previous.role.." overlaps confirm") end
            for _,role in ipairs({"m43_draft_empty","m43_draft_damage"}) do
                local item=view:findTextRole(role)
                if item then truthy(item.size>=8);equal(view:textBlockBounds(item,scale).lineCount,1);truthy(view:textBlockBounds(item,scale).bottom<=264*scale,role) end
            end
        end
    end)
    love.graphics.getDimensions=original
    if not ok then error(message,0) end
end

local function m42ForScales(body)
    local original = love.graphics.getDimensions
    local ok,message = pcall(function()
        for scale=1,3 do
            love.graphics.getDimensions=function() return 480*scale,270*scale end
            body(scale)
        end
    end)
    love.graphics.getDimensions=original
    if not ok then error(message,0) end
end

test("M42 I01 actual Battle Session and restore keep committed paid assets and launch additive damage", function()
    local game,storage,checkpoint=newGame()
    m42PrepareWave(game,9,{m42Module("M03",20),m42Module("M08",20)},19,0)
    truthy(game:selectTower(1));truthy(game:placeSelected(0,2));truthy(game:startWave())
    local committed=Json.encode(game.session:getState().runState.modules)
    equal(game:selectOffer("module"),false)
    equal(game:beginInventoryTransaction({kind="sell_module",moduleId="M03"}),false)
    local Battle=require("src.battle")
    local events=Battle.step(game.battle,Battle.FIXED_DT,{{type="sell_module",moduleId="M03"}})
    local rejected=false;for _,e in ipairs(events) do if e.type=="command_rejected" then rejected=true end end
    truthy(rejected);equal(Json.encode(game.battle.run.modules),committed)
    local writes=storage.writeCount
    local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function() error("restore identity") end})
    equal(storage.writeCount,writes);equal(Json.encode(restored:getState().runState.modules),committed)
    equal(restored:getState().moduleUnlockById.M42.permanentlyUnlocked,false)
    truthy(restored:resumeAll());local battle=restored.battle;battle.spawnSchedule,battle.nextSpawnIndex={},1
    for _,enemy in ipairs(battle.enemies) do enemy.alive=false end
    restored:update(Battle.FIXED_DT)
    equal(restored:getState().moduleUnlockById.M42.permanentlyUnlocked,true)
    equal(Json.encode(restored:getState().runState.modules),committed)
    local live=m42EarnedGame(nil,{m42Module("M42",16),m42Module("M25",20)})
    truthy(live:selectTower(1));truthy(live:placeSelected(0,2));truthy(live:startWave())
    battle=live.battle;battle.spawnSchedule,battle.nextSpawnIndex={},1
    local enemy=battle.enemies[1];enemy.baseSpeed,enemy.hp,enemy.maxHp=0,1000,1000
    battle.towers[1].charge=1;live:update(Battle.FIXED_DT)
    truthy(#battle.projectiles>0);close(battle.projectiles[1].launchBaseDamage,12*1.10)
    local frozenDamage=battle.projectiles[1].launchBaseDamage
    battle.run.modules[2].paidGold=60
    close(battle.projectiles[1].launchBaseDamage,frozenDamage)
    equal(live.session:getState().runState.modules[2].paidGold,20)
end)

test("M42 I02 normal four and preserved five rights stay atomic and enter only successful next run", function()
    for _,normal in ipairs({false,true}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local game,storage,checkpoint=newGame()
        if normal then
            m42PrepareWave(game,3,{m42Module("M25",8)},19,0);truthy(completeWave(game,3))
            equal(game:getState().moduleUnlockById.M43.permanentlyUnlocked,true)
            m42PrepareWave(game,9,{m42Module("M03",12),m42Module("M08",12),m42Module("M17",12),m42Module("M06",16)})
        else m42PrepareWave(game,9,{m42Module("M03",20),m42Module("M08",20)}) end
        truthy(game:startWave());local before,gen=game:getState(),generation(checkpoint)
        local expected=Shop.createVisit(game.defs,{visitId="S03",frozenUnlockPool=before.runState.frozenUnlockPool,acquiredModuleIds=before.runState.acquiredModuleIds,rngState=before.runState.shopState.rngState})
        storage.writeMode=mode;equal(finishStartedWave(game,9),false)
        equal(Json.encode(game:getState().metaState),Json.encode(before.metaState));equal(#game:getState().newModuleUnlocks,0)
        local bytes=game.session.pending.candidate.encodedEnvelope
        local payload=Json.decode(Json.decode(bytes).payloadJson)
        equal(table.concat(payload.metaState.unlockedModuleIds,","),"M28,M41,M42,M43,M46")
        equal(game:retrySave().status,"save_error");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied")
        local after=game:getState();equal(#after.newModuleUnlocks,normal and 4 or 5);equal(generation(checkpoint),gen+1)
        equal(Json.encode(after.runState.frozenUnlockPool),Json.encode(before.runState.frozenUnlockPool))
        equal(Json.encode(after.runState.shopState),Json.encode(expected));equal(Json.encode(after.runState.modules),Json.encode(before.runState.modules))
        equal(after.moduleUnlockById.M42.inCurrentRunPool,false)
        local order={};for _,e in ipairs(after.newModuleUnlocks) do order[#order+1]=e.moduleId end
        equal(table.concat(order,","),normal and "M28,M41,M46,M42" or "M28,M41,M43,M46,M42")
        equal(game:retrySave().status,"rejected");equal(finishStartedWave(game,9),false)
        truthy(completeWave(game,10,"defeat","fixture_defeat"))
        local result=Json.encode(game:getState().runState);local resultGen=generation(checkpoint)
        truthy(game:requestNewRun());truthy(game:cancelNewRun());equal(Json.encode(game:getState().runState),result)
        truthy(game:requestNewRun());storage.writeMode="fail_before";equal(game:confirmNewRun(),false)
        equal(Json.encode(game:getState().runState),result);local newBytes=storage.writeAttempts[#storage.writeAttempts].data
        storage.writeMode=nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,newBytes)
        equal(generation(checkpoint),resultGen+1)
        equal(#game:getState().runState.frozenUnlockPool.moduleIds,#Game.defaultUnlockPool(game.defs).moduleIds+5)
        equal(game:getState().moduleUnlockById.M42.inCurrentRunPool,true);equal(#game:getState().runState.modules,0)
        equal(game:getState().runState.acquiredModuleIds.M42,nil)
    end end
end)

test("M42 I03 eight legacy Game restores never infer I42 and only new valid completion earns it", function()
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1"}
    for index,version in ipairs(versions) do
        local source,storage,checkpoint=newGame();local payload=checkpoint:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion,run.hp,run.gold=version,5,37
        run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        m42SetModules(run,{m42Module("M01",8)});run.shopState.offers.module="M02";payload.metaState.unlockedModuleIds={}
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then
            m42SetModules(run,{m42Module("M33",9,6),m42Module("M08",11)})
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33";run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M08"
            run.nextWaveIndex,run.shopState.visitId=7,"S02";run.completedWaveIds=Json.object()
            for w=1,6 do run.completedWaveIds[string.format("W%02d",w)]=true end
            payload.checkpointKind,payload.resumeDescriptor.kind,payload.resumeDescriptor.waveIndex="waveComplete","waveComplete",7
            if index>=4 then payload.metaState.unlockedTowerIds[#payload.metaState.unlockedTowerIds+1]="T05" end
        end
        local rights={};if index>=5 then rights[#rights+1]="M28" end;if index>=6 then rights[#rights+1]="M43" end;if index>=7 then rights[#rights+1]="M46" end;if index==8 then rights[#rights+1]="M41" end
        payload.metaState.unlockedModuleIds=rights
        for _,id in ipairs(rights) do run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=id end
        if index==8 then
            m42SetModules(run,{m42Module("M33",9,6),m42Module("M03",20),m42Module("M08",20)})
            run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M03"
            run.nextWaveIndex,run.shopState.visitId=10,"S03"
            for w=7,9 do run.completedWaveIds[string.format("W%02d",w)]=true end
            payload.resumeDescriptor.waveIndex=10
        end
        truthy(Save.createRun002Migrations(source.defs)[version].validatePayload(payload))
        local captured={};for _,key in ipairs({"shopState","frozenUnlockPool","modules","acquiredModuleIds","completedWaveIds"}) do captured[key]=Json.encode(run[key]) end
        storage.files={};writeShaEnvelope(storage,"save-b.json",34,version,payload)
        local bytes,writes=storage.files["save-b.json"],storage.writeCount
        local game=Game.new({defs=source.defs,checkpointStore=checkpoint,identityProvider=function() error("legacy restore identity") end})
        equal(storage.writeCount,writes);equal(storage.files["save-b.json"],bytes)
        local state=game:getState();equal(state.moduleUnlockById.M42.permanentlyUnlocked,false);equal(#state.newModuleUnlocks,0)
        for key,value in pairs(captured) do equal(Json.encode(state.runState[key]),value,version..key) end
        equal(state.runState.gold,37);equal(Json.encode(state.metaState.unlockedModuleIds),Json.encode(rights))
        truthy(game:closeShop().status=="applied");truthy(game:startWave());equal(generation(checkpoint),35)
        local nextPayload=checkpoint:loadCheckpoint().payload;equal(nextPayload.runState.contentVersion,game.defs.version)
        local closed=Json.decode(captured.shopState);closed.accessOpen=false
        equal(Json.encode(nextPayload.runState.shopState),Json.encode(closed))
        equal(Json.encode(nextPayload.runState.modules),captured.modules);equal(Json.encode(nextPayload.runState.frozenUnlockPool),captured.frozenUnlockPool)
        truthy(finishStartedWave(game,run.nextWaveIndex))
        equal(game:getState().moduleUnlockById.M42.permanentlyUnlocked,index==8)
        equal(game:getState().moduleUnlockById.M42.inCurrentRunPool,false)
        equal(select(2,Rules.previewModulePurchase(game.defs,game:getState().runState,"M42")),"module_not_in_frozen_pool")
    end
end)

test("M42 I04 six lookup tabs and asset management own input show full contracts and cancel read only", function()
    for _,earned in ipairs({false,true}) do
        local game,storage,checkpoint
        if earned then game,storage,checkpoint=m42EarnedGame("M42",{m42Module("M03",12)}) else game,storage,checkpoint=newGame() end
        local view,input,find,click,text=assembledUi(game);local before,writes,gen=game:getState(),storage.writeCount,generation(checkpoint)
        view:draw(before);truthy(click("open_tower_unlocks"));view:draw(game:getState())
        for _,tab in ipairs({"tower","deposit","spare","emergency","midlink","assetlink"}) do
            truthy(click("unlock_lookup_tab",function(a)return a.tab==tab end));view:draw(game:getState());equal(view.unlockLookupTab,tab)
        end
        for _,token in ipairs({"W09–14","실지불합≥40G","완료직전","자신 제외","내림·최대30%p","판매가/리롤/타워/패치","판매/패배 후 권리 유지"}) do truthy(text():find(token,1,true),token) end
        truthy(text():find(earned and "이번 판 후보 포함" or "이번 판 후보 제외",1,true))
        if earned then truthy(text():find("현재 제안 있음",1,true)) end
        m42ForScales(function(scale)
            view:draw(game:getState());assertVisibleFits(view,"M42 six tabs")
            local count=0;for _,b in ipairs(view.buttons) do if b.action.type=="unlock_lookup_tab" then count=count+1;equal(b.w,b.action.tab=="deposit" and 32 or 22);equal(b.textSize,9) end end;equal(count,11)
            local roles={"permanent","condition","effect","attempt","pool","offer","next_run"};local previous
            for _,role in ipairs(roles) do local t=assert(view:findTextRole("module_unlock_M42_"..role));if previous then truthy(view:textBlockBounds(previous,scale).bottom<=t.y*scale) end;previous=t end
            truthy(view:textBlockBounds(previous,scale).bottom<=264*scale)
        end)
        local x,y=m46WindowPoint(view,0,2);input:mousepressed(x,y,1)
        equal(storage.writeCount,writes);equal(generation(checkpoint),gen);equal(Json.encode(game:getState().runState),Json.encode(before.runState))
        truthy(input:keypressed("escape",false));equal(view:hasTowerUnlocks(),false)
        if earned then
            truthy(game:selectOffer("module"));equal(view:openTowerUnlocks(game:getState()),false);truthy(game:cancelPurchase())
            truthy(game:selectOffer("module"));truthy(game:confirmPurchase())
            view:draw(game:getState());truthy(view:openInventoryManagement("module"));truthy(view:selectManagedModule("M42"));view:draw(game:getState())
            local sale=assert(find("begin_inventory_transaction",function(a)return a.moduleId=="M42" end));equal(sale.y,226)
            truthy(click("begin_inventory_transaction",function(a)return a.moduleId=="M42" end));equal(game:getState().transactionDraft.moduleId,"M42")
            local state=Json.encode(game:getState().runState);writes=storage.writeCount
            truthy(input:keypressed("escape",false));equal(game:getState().transactionDraft,nil);equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),state)
        end
        truthy(game:startWave());equal(view:openTowerUnlocks(game:getState()),false)
    end
end)

test("M42 I05 multi link purchase sale and saved alerts preserve every changing effect and history", function()
    local game,storage=m42EarnedGame("M46")
    local view,input,find,click,text=assembledUi(game)
    truthy(game:selectOffer("module"));m42DrawBoundary(view,game:getState(),false)
    truthy(text():find("연동 중가1→2종",1,true));truthy(text():find("자산 지불28→40G",1,true));truthy(text():find("현재HP5",1,true))
    local before,writes=Json.encode(game:getState().runState),storage.writeCount
    truthy(input:keypressed("escape",false));equal(Json.encode(game:getState().runState),before);equal(storage.writeCount,writes)
    truthy(game:selectOffer("module"));storage.writeMode="fail_before";equal(game:confirmPurchase(),false)
    equal(Json.encode(game:getState().runState),before);equal(#game:getState().newModuleUnlocks,0)
    view:draw(game:getState());equal(view:findTextRole("new_tower_unlock_feedback"),nil)
    local bytes=game.session.pending.candidate.encodedEnvelope;storage.writeMode=nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
    equal(findModuleEntry(game:getState().runState,"M46").paidGold,12)
    for _,id in ipairs({"M46","M42","M41","M43"}) do
        truthy(game:beginInventoryTransaction({kind="sell_module",moduleId=id}));m42DrawBoundary(view,game:getState(),true)
        truthy(text():find("환급",1,true));truthy(text():find("권리/획득 유지",1,true));truthy(game:cancelInventoryTransaction())
    end
    truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M42"}));truthy(game:confirmInventoryTransaction())
    equal(game:getState().moduleStatusById.M42.bonusPercentPoints,0);equal(game:getState().moduleUnlockById.M42.permanentlyUnlocked,true)
    equal(game:getState().runState.acquiredModuleIds.M42,true)
    for _,id in ipairs({"M33","M28","M25","M06"}) do
        local current=m42EarnedGame(id,{m42Module("M42",16),m42Module("M41",16)})
        local ui=assembledUi(current);truthy(current:selectOffer("module"));m42DrawBoundary(ui,current:getState(),false)
        truthy(current:confirmPurchase());truthy(current:beginInventoryTransaction({kind="sell_module",moduleId=id}));m42DrawBoundary(ui,current:getState(),true)
        truthy(current:cancelInventoryTransaction())
    end
    local alert,save=newGame();m42PrepareWave(alert,9,{m42Module("M03",20),m42Module("M08",20)});truthy(alert:startWave())
    save.writeMode="fail_before";equal(finishStartedWave(alert,9),false)
    local ui=assembledUi(alert);ui:draw(alert:getState());equal(ui:findTextRole("new_tower_unlock_feedback"),nil)
    save.writeMode=nil;equal(alert:retrySave().status,"applied");equal(#alert:getState().newModuleUnlocks,5)
    for _,stress in ipairs({false,true}) do
        local state=alert:getState();if stress then state.newTowerUnlocks={{towerId="T05"}} end
        m42ForScales(function(scale)
            ui:closeTowerUnlocks();ui:draw(state);assertVisibleFits(ui,"M42 five/six alert")
            local guide=assert(ui:findTextRole("new_tower_unlock_feedback"));equal(guide.size,8);equal(guide.y,73)
            truthy(ui:textBlockBounds(guide,scale).lineCount<=3);truthy(ui:textBlockBounds(guide,scale).bottom<=112*scale)
            truthy(ui:textBlockBounds(ui:findTextRole("module_unlock_common_feedback"),scale).bottom<36*scale)
            truthy(ui:textBlockBounds(ui:findTextRole("notice"),scale).bottom<22*scale)
            truthy(ui:openTowerUnlocks(state));equal(ui.unlockLookupTab,"assetlink")
        end)
    end
end)

test("M42 I06 asset linked capacity transactions require exact recalls and preserve identities through cancel retry", function()
    for _,sale in ipairs({false,true}) do
        local modules={m42Module("M42",16)};if sale then modules[2]=m42Module("M05",8) end
        local game,storage=m42EarnedGame(not sale and "M06" or nil,modules)
        local run=game:getState().runState;run.towerInstances={};local count=sale and 8 or 6
        for i=1,count do run.towerInstances[i]={instanceId=i,typeId="T01",paidGold=i,patchIds={"P_DAMAGE"},placement={x=i-1,y=0},charge=0,activated=true} end
        run.nextInstanceId=count+1;truthy(game:_applyDurableRun(run,"transaction"))
        if not sale then m41Offer(game,"M06") end
        local before=Json.encode(game:getState().runState);local writes=storage.writeCount
        local view,input,find,click=assembledUi(game)
        local function begin() if sale then truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M05"})) else truthy(game:selectOffer("module")) end end
        begin();m42DrawBoundary(view,game:getState(),sale)
        local draft=sale and game:getState().transactionDraft or game:getState().purchaseDraft
        equal(draft.requiredRecallCount,2);equal(draft.canCommit,false)
        truthy(input:keypressed("escape",false));equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
        begin();view:draw(game:getState())
        for id=1,2 do local x,y=m46WindowPoint(view,View.MAP_X+(id-0.5)*View.CELL,View.MAP_Y+View.CELL/2);truthy(input:mousepressed(x,y,1));view:draw(game:getState()) end
        draft=sale and game:getState().transactionDraft or game:getState().purchaseDraft
        equal(#draft.selectedRecallTowerIds,2);equal(draft.canCommit,true);m42DrawBoundary(view,game:getState(),sale)
        storage.writeMode="fail_before"
        if sale then equal(game:confirmInventoryTransaction(),false) else equal(game:confirmPurchase(),false) end
        equal(Json.encode(game:getState().runState),before)
        local bytes=game.session.pending.candidate.encodedEnvelope;storage.writeMode=nil;equal(game:retrySave().status,"applied")
        equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
        local after=game:getState().runState
        equal(#after.towerInstances,count);equal(after.towerInstances[1].placement,nil);equal(after.towerInstances[2].placement,nil)
        for i=1,count do equal(after.towerInstances[i].instanceId,i);equal(after.towerInstances[i].patchIds[1],"P_DAMAGE");equal(after.towerInstances[i].paidGold,i) end
        equal(after.modules[1].paidGold,16)
        if sale then equal(after.acquiredModuleIds.M05,true) else equal(findModuleEntry(after,"M06").paidGold,16) end
    end
end)

local function m15PatchCurrent(game, placed)
    local run=game:getState().runState
    run.gold=run.gold+12
    for _,id in ipairs({"P_DAMAGE","P_RATE","P_RANGE"}) do run=assert(Rules.tryPurchasePatch(game.defs,run,1,id)) end
    truthy(game:_applyDurableRun(run,"transaction"))
    if placed then truthy(game:selectTower(1));truthy(game:placeSelected(0,2)) end
end

local function m15PrepareWave(game,index,modules,hp,gold,placed)
    m42PrepareWave(game,index,modules or {},hp or 19,gold or 0)
    m15PatchCurrent(game,placed~=false)
end

local function m15FinishActual(game)
    local Battle=require("src.battle");local battle=assert(game.battle)
    battle.spawnSchedule,battle.nextSpawnIndex={},1
    for _,enemy in ipairs(battle.enemies) do enemy.alive=false end
    game:update(Battle.FIXED_DT)
    return battle
end

local function m15Offer(game,id)
    local run=game:getState().runState;local selected
    for seed=1,3000 do
        local visit=Shop.createVisit(game.defs,{visitId=run.shopState.visitId,frozenUnlockPool=run.frozenUnlockPool,
            acquiredModuleIds=run.acquiredModuleIds,rngState=Rng.new(seed):getState()})
        if visit.offers.module==id then selected=visit break end
    end
    truthy(selected,"seeded offer missing "..id);run.shopState=selected
    truthy(game:_applyDurableRun(run,"transaction"))
end

local function m15EarnedGame(offer,modules)
    local game,storage,checkpoint=newGame()
    m15PrepareWave(game,9,{m42Module("M03",20),m42Module("M08",20)},5,20)
    truthy(completeWave(game,9));equal(#game:getState().newModuleUnlocks,6)
    truthy(completeWave(game,10,"defeat","fixture_defeat"))
    truthy(game:requestNewRun());truthy(game:confirmNewRun())
    local run=game:getState().runState;run.hp,run.gold=5,100
    m42SetModules(run,modules or {});truthy(game:_applyDurableRun(run,"transaction"))
    if offer then m15Offer(game,offer) end
    return game,storage,checkpoint
end

local function m15DrawBoundary(view,state,roles)
    m42ForScales(function(scale)
        view:draw(state);assertVisibleFits(view,"M15 actual View.draw")
        local previous
        for _,role in ipairs(roles or {}) do
            local item=assert(view:findTextRole(role),"missing "..role)
            local bounds=view:textBlockBounds(item,scale)
            truthy(item.size>=8);truthy(bounds.bottom<=264*scale,role)
            if previous then truthy(view:textBlockBounds(previous,scale).bottom<=item.y*scale,previous.role.." overlaps "..role) end
            for row in item.value:gmatch("[^\n]+") do truthy(view:_font(item.size*scale):hasGlyphs(row),role.." glyph") end
            previous=item
        end
    end)
end

test("M15 I01 actual Battle start late placement restore and commands prove I15 identity and faster launches", function()
    local Battle=require("src.battle")
    local late=newGame();m15PrepareWave(late,6,{},19,0,false)
    truthy(late:startWave());truthy(late:selectTower(1));truthy(late:placeSelected(0,2));late:update(Battle.FIXED_DT)
    truthy(late.battle.run.towerInstances[1].placement);equal(late.session:getState().runState.towerInstances[1].placement,nil)
    m15FinishActual(late);equal(late:getState().moduleUnlockById.M15.permanentlyUnlocked,false)
    local game,storage,checkpoint=newGame();m15PrepareWave(game,6,{},19,0)
    truthy(game:startWave());equal(game:placeSelected(1,2),false);equal(game:recallTower(1),false)
    equal(game:selectOffer("patch"),false);equal(game:selectOffer("module"),false)
    equal(game:beginInventoryTransaction({kind="sell_tower",instanceId=1}),false)
    equal(game.session:dispatch({type="APPLY_DURABLE",checkpoint={}}).status,"rejected")
    local events=Battle.step(game.battle,Battle.FIXED_DT,{{type="recall_tower",instanceId=1},{type="remove_tower",instanceId=1},
        {type="purchase_patch",instanceId=1,patchId="P_DAMAGE"},{type="sell_module",moduleId="M15"},{type="place_tower",instanceId=1,x=1,y=2}})
    local rejected=0;for _,event in ipairs(events) do if event.type=="command_rejected" then rejected=rejected+1 end end;equal(rejected,5)
    local writes=storage.writeCount;local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("restore cannot mint identity") end})
    equal(storage.writeCount,writes);equal(restored.battle.tick,0);restored:update(Battle.FIXED_DT);equal(restored.battle.tick,0)
    truthy(restored:resumeAll());truthy(restored:selectTower(2));truthy(restored:placeSelected(1,0));restored:update(Battle.FIXED_DT)
    local battle=m15FinishActual(restored);equal(battle.result.kind,"wave_complete")
    equal(restored:getState().moduleUnlockById.M15.permanentlyUnlocked,true)
    local slowRun=Content.clone(game.session:getState().runState);slowRun.modules={};slowRun.hp=20
    local fastRun=Content.clone(slowRun);fastRun.modules={m42Module("M15",12)}
    local shots,firstTicks,launches={},{},{}
    for index,run in ipairs({slowRun,fastRun}) do
        local live=assert(Battle.new(game.defs,run,"W06"));live.spawnSchedule,live.nextSpawnIndex={},1
        local enemy=live.enemies[1];enemy.baseSpeed,enemy.hp,enemy.maxHp=0,100000,100000
        live.towers[1].charge=0;local first
        for _=1,600 do
            local step=assert(Battle.step(live,Battle.FIXED_DT))
            for _,event in ipairs(step) do if event.type=="tower_fired" and event.instanceId==1 then
                first=first or event.tick;launches[index]=event.launchDamage
                local projectile=live.projectiles[#live.projectiles];truthy(projectile);equal(projectile.sourceTowerId,1)
                close(projectile.launchBaseDamage,event.launchDamage)
            end end
        end
        shots[index]=live.observations.shots;firstTicks[index]=assert(first)
    end
    truthy(shots[2]>shots[1]);truthy(firstTicks[2]<firstTicks[1]);close(launches[1],launches[2])
    io.write("FIXTURE M15 I01 actual cadence slow=",shots[1]," fast=",shots[2]," lateIdentityExcluded=true\n")
end)

test("M15 I02 nominal five and preserved six rights commit atomically and enter only successful next run", function()
    for _,normal in ipairs({true,false}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local game,storage,checkpoint=newGame()
        local modules=normal and {m42Module("M03",12),m42Module("M08",12),m42Module("M17",12),m42Module("M06",16)}
            or {m42Module("M03",20),m42Module("M08",20)}
        m15PrepareWave(game,9,modules,5,20);truthy(game:startWave())
        local before,gen=game:getState(),generation(checkpoint)
        local expectedShop=Shop.createVisit(game.defs,{visitId="S03",frozenUnlockPool=before.runState.frozenUnlockPool,
            acquiredModuleIds=before.runState.acquiredModuleIds,rngState=before.runState.shopState.rngState})
        storage.writeMode=mode;equal(finishStartedWave(game,9),false)
        equal(Json.encode(game:getState().metaState),Json.encode(before.metaState));equal(#game:getState().newModuleUnlocks,0)
        local bytes=game.session.pending.candidate.encodedEnvelope;equal(game:retrySave().status,"save_error")
        equal(game.session.pending.candidate.encodedEnvelope,bytes)
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied")
        local after=game:getState();equal(#after.newModuleUnlocks,normal and 5 or 6);equal(generation(checkpoint),gen+1)
        equal(after.moduleUnlockById.M15.permanentlyUnlocked,true);equal(after.moduleUnlockById.M15.inCurrentRunPool,false)
        equal(Json.encode(after.runState.frozenUnlockPool),Json.encode(before.runState.frozenUnlockPool))
        equal(Json.encode(after.runState.shopState),Json.encode(expectedShop));equal(Json.encode(after.runState.modules),Json.encode(before.runState.modules))
        local ids={};for _,event in ipairs(after.newModuleUnlocks) do ids[#ids+1]=event.moduleId end
        equal(table.concat(ids,","),normal and "M28,M41,M46,M42,M15" or "M28,M41,M43,M46,M42,M15")
        equal(game:retrySave().status,"rejected");equal(finishStartedWave(game,9),false)
        truthy(completeWave(game,10,"defeat","fixture_defeat"));local result=Json.encode(game:getState().runState)
        truthy(game:requestNewRun());truthy(game:cancelNewRun());equal(Json.encode(game:getState().runState),result)
        truthy(game:requestNewRun());storage.writeMode="fail_before";equal(game:confirmNewRun(),false)
        equal(Json.encode(game:getState().runState),result);local newBytes=game.session.pending.candidate.encodedEnvelope
        storage.writeMode=nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,newBytes)
        local run=game:getState().runState;equal(#run.frozenUnlockPool.moduleIds,normal and 29 or 30)
        equal(#run.modules,0);equal(run.acquiredModuleIds.M15,nil);equal(game:getState().moduleUnlockById.M15.inCurrentRunPool,true)
    end end
end)

test("M15 I03 nine legacy Game restores keep records and pools and earn I15 only from a new valid battle", function()
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1"}
    for index,version in ipairs(versions) do
        local game,storage,checkpoint=newGame()
        if index>1 then m15PrepareWave(game,6,{m42Module("M01",20)},19,0) else m15PatchCurrent(game,true) end
        local payload=checkpoint:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion=version;run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={m42Module("M01",20)};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02";run.shopState.soldOut.module=false
        payload.metaState.unlockedModuleIds={};if index<4 then payload.metaState.unlockedTowerIds={"T01","T02","T03","T04"} end
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then run.modules[2]=m42Module("M33",9,6);run.acquiredModuleIds.M33=true;run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33" end
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"}}) do if index>=entry[1] then
            payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2]
        end end
        assert(Save.createRun002Migrations(game.defs)[version].validatePayload(payload))
        storage.files={};writeShaEnvelope(storage,"save-b.json",34,version,payload)
        local writes=storage.writeCount;local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("legacy restore identity") end})
        local state=restored:getState();equal(storage.writeCount,writes);equal(state.moduleUnlockById.M15.permanentlyUnlocked,false);equal(#state.newModuleUnlocks,0)
        for _,key in ipairs({"modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(state.runState[key]),Json.encode(run[key]),version..key) end
        local pool=Json.encode(state.runState.frozenUnlockPool)
        truthy(restored:startWave());m15FinishActual(restored)
        equal(restored:getState().moduleUnlockById.M15.permanentlyUnlocked,index>1)
        equal(Json.encode(restored:getState().runState.frozenUnlockPool),pool)
        equal(restored:getState().moduleUnlockById.M15.inCurrentRunPool,false)
        equal(checkpoint:loadCheckpoint().payload.runState.contentVersion,game.defs.version)
    end
end)

test("M15 I04 seven lookup tabs and mixed management show full contracts and own input without writes", function()
    for _,earned in ipairs({false,true}) do
        local game,storage,checkpoint
        if earned then game,storage,checkpoint=m15EarnedGame("M15");m15PatchCurrent(game,true);truthy(game:selectOffer("module"));truthy(game:confirmPurchase())
        else game,storage,checkpoint=newGame() end
        local view,input,find,click,text=assembledUi(game);local before=Json.encode(game:getState().runState);local writes,gen=storage.writeCount,generation(checkpoint)
        view:draw(game:getState());truthy(click("open_tower_unlocks"));view:draw(game:getState())
        for _,tab in ipairs({"tower","deposit","spare","emergency","midlink","assetlink","mixed"}) do truthy(click("unlock_lookup_tab",function(a)return a.tab==tab end));view:draw(game:getState()) end
        local roles={};for _,role in ipairs({"permanent","condition","effect","attempt","pool","offer","next_run"}) do roles[#roles+1]="module_unlock_M15_"..role end
        m15DrawBoundary(view,game:getState(),roles)
        for _,token in ipairs({"중가12G","W06–14","같은 타워1기","서로 다른 패치3종","완료직전","늦은배치","미완료","중복","합산+20%p","무료 지급/등장 보장 없음","판매/패배 후 권리 유지"}) do truthy(text():find(token,1,true),token) end
        local count=0;for _,button in ipairs(view.buttons) do if button.action.type=="unlock_lookup_tab" then count=count+1;equal(button.textSize,9);truthy(button.x+button.w<=465);equal(button.w,button.action.tab=="deposit" and 32 or 22) end end;equal(count,11)
        local x,y=m46WindowPoint(view,0,2);input:mousepressed(x,y,1)
        equal(storage.writeCount,writes);equal(generation(checkpoint),gen);equal(Json.encode(game:getState().runState),before)
        truthy(input:keypressed("escape",false));equal(view:hasTowerUnlocks(),false)
        if earned then
            truthy(view:openInventoryManagement("module"));truthy(view:selectManagedModule("M15"));m15DrawBoundary(view,game:getState())
            truthy(text():find("선택#1 패치3종",1,true));truthy(text():find("속도1.38/+20%p",1,true))
            equal(assert(find("begin_inventory_transaction",function(a)return a.moduleId=="M15" end)).y,226)
            truthy(game:cancelSelection());view:draw(game:getState());truthy(text():find("선택 타워 없음",1,true))
            truthy(input:keypressed("escape",false));truthy(input:keypressed("escape",false))
        end
        truthy(game:startWave());equal(view:openTowerUnlocks(game:getState()),false)
    end
end)

test("M15 I05 selected mixed purchase sale previews preserve M41 M42 M43 effects and saved alert contracts", function()
    local game,storage=m15EarnedGame("M15",{m42Module("M41",16),m42Module("M42",16),m42Module("M43",12)})
    m15PatchCurrent(game,true);local view,input,find,click,text=assembledUi(game)
    local before,writes=Json.encode(game:getState().runState),storage.writeCount
    truthy(game:selectOffer("module"));local draft=game:getState().purchaseDraft
    equal(draft.cost,12);equal(draft.slotBefore,3);equal(draft.slotAfter,4);equal(draft.mixedTrade.afterStatus.bonusPercentPoints,20)
    m15DrawBoundary(view,game:getState(),{"m15_draft_title","m15_draft_offer_effect","m15_draft_links","m15_draft_selected","m15_draft_detail"})
    truthy(text():find("중가1→2종/+8→16%p",1,true));truthy(text():find("자산28→40G/+14→20%p",1,true))
    truthy(game:selectTower(2));equal(game:getState().purchaseDraft.mixedTrade.afterStatus.bonusPercentPoints,0)
    truthy(game:cancelSelection());equal(game:getState().purchaseDraft.mixedTrade.error,"tower_not_selected")
    truthy(game:selectTower(1));equal(game:getState().purchaseDraft.mixedTrade.afterStatus.bonusPercentPoints,20)
    equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
    truthy(input:keypressed("escape",false));equal(game:getState().purchaseDraft,nil)
    truthy(game:selectOffer("module"));truthy(game:confirmPurchase());equal(findModuleEntry(game:getState().runState,"M15").paidGold,12)
    truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M15"}))
    draft=game:getState().transactionDraft;equal(draft.refundGold,6);equal(draft.mixedTrade.beforeStatus.bonusPercentPoints,20);equal(draft.mixedTrade.afterStatus.bonusPercentPoints,0)
    m15DrawBoundary(view,game:getState(),{"m15_sale_offer_effect","m15_sale_paid","m15_draft_links","m15_draft_selected","m15_sale_history","m15_sale_capacity","m15_sale_recall"})
    truthy(text():find("자산40→28G",1,true));equal(draft.spareCircuitBefore.emptySlots,0);equal(draft.spareCircuitAfter.emptySlots,1)
    equal(game:selectTower(2),false);truthy(game:confirmInventoryTransaction());equal(game:getState().runState.acquiredModuleIds.M15,true)
    equal(game:getState().moduleUnlockById.M15.permanentlyUnlocked,true);equal(Rules.tryPurchaseModule(game.defs,game:getState().runState,"M15"),nil)
    local alert=newGame();m15PrepareWave(alert,9,{m42Module("M03",20),m42Module("M08",20)},5,20)
    truthy(completeWave(alert,9));local state=alert:getState();equal(#state.newModuleUnlocks,6)
    local alertView=assembledUi(alert);m15DrawBoundary(alertView,state)
    for _,name in ipairs({"혼합 개조","예치금","중가 연동","자산 연동","여유 회로","비상 출력"}) do
        local found=false;for _,item in ipairs(alertView.texts) do if item.value:find(name,1,true) then found=true end end;truthy(found,name)
    end
    local stress=Content.clone(state);stress.newTowerUnlocks={{type="tower_unlocked",towerId="T05",waveId="W05"}}
    m15DrawBoundary(alertView,stress);local guide=assert(alertView:findTextRole("primary_guide"));equal(alertView:textBlockBounds(guide,1).lineCount,3)
    local single=newGame();m15PrepareWave(single,6,{},19,0);truthy(completeWave(single,6));equal(#single:getState().newModuleUnlocks,1)
    local singleView=assembledUi(single);m15DrawBoundary(singleView,single:getState())
    local feedback=assert(singleView:_newTowerUnlockFeedback(single:getState()));truthy(feedback:find("W06–14",1,true));truthy(feedback:find("속도+20%p",1,true))
    io.write("FIXTURE M15 I05 actualSix=true syntheticSeven=true singleConditionAndEffect=true\n")
end)

test("M15 I06 mixed linked capacity drafts require exact recalls and refresh selected effects through cancel retry", function()
    for _,sale in ipairs({true,false}) do
        local game,storage=m15EarnedGame(nil,{m42Module("M05",16),m42Module("M15",12),m42Module("M42",16)})
        local run=game:getState().runState;run.towerInstances={}
        for id=1,8 do run.towerInstances[id]={instanceId=id,typeId="T01",paidGold=id,
            patchIds=id==1 and {"P_DAMAGE","P_RATE","P_RANGE"} or {"P_DAMAGE"},placement={x=id-1,y=0},charge=0,activated=true} end
        run.nextInstanceId=9;truthy(game:_applyDurableRun(run,"transaction"));truthy(game:selectTower(1))
        if not sale then m15Offer(game,"M06") end
        local before,writes=Json.encode(game:getState().runState),storage.writeCount
        local view,input=assembledUi(game)
        local function begin() if sale then truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M05"})) else truthy(game:selectOffer("module")) end end
        local function draft()local state=game:getState();return sale and state.transactionDraft or state.purchaseDraft end
        local function choose(id,value)if sale then return game:setInventoryRecallSelection(id,value) else return game:setPurchaseRecallSelection(id,value) end end
        begin();equal(draft().requiredRecallCount,2);equal(draft().canCommit,false);equal(draft().mixedTrade.after,nil)
        m15DrawBoundary(view,game:getState());truthy(input:keypressed("escape",false));equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
        begin();equal(choose(99),false);truthy(choose(1));equal(draft().mixedTrade.after,nil);truthy(choose(2))
        equal(draft().canCommit,true);equal(draft().mixedTrade.afterStatus.selectedTowerPlaced,false);equal(draft().mixedTrade.afterStatus.bonusPercentPoints,0)
        equal(choose(3),false);m15DrawBoundary(view,game:getState())
        storage.writeMode="fail_before";if sale then equal(game:confirmInventoryTransaction(),false) else equal(game:confirmPurchase(),false) end
        equal(Json.encode(game:getState().runState),before);local bytes=game.session.pending.candidate.encodedEnvelope
        storage.writeMode=nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
        local after=game:getState().runState;equal(after.towerInstances[1].placement,nil);equal(after.towerInstances[2].placement,nil)
        equal(#after.towerInstances,8);equal(#after.towerInstances[1].patchIds,3);equal(after.towerInstances[1].paidGold,1)
        equal(findModuleEntry(after,"M15").paidGold,12);equal(after.acquiredModuleIds.M15,true)
    end
end)

local M14_MID_PATCHES = {"P_OVERLOAD","P_OVERDRIVE","P_LONG_RANGE"}
local M14_HIGH_PATCHES = {"P_FOCUSED_BARRAGE","P_CONTINUOUS_AIM","P_HEAVY_AIM"}

local function m14PatchCurrent(game, placed, patches)
    patches = patches or M14_MID_PATCHES
    local run=game:getState().runState
    for _,id in ipairs(patches) do run.gold=run.gold+game.defs.patchesById[id].price end
    for _,id in ipairs(patches) do run=assert(Rules.tryPurchasePatch(game.defs,run,1,id)) end
    truthy(game:_applyDurableRun(run,"transaction"))
    if placed then truthy(game:selectTower(1));truthy(game:placeSelected(0,2)) end
end

local function m14PrepareWave(game,index,modules,hp,gold,placed,patches)
    m42PrepareWave(game,index,modules or {},hp or 19,gold or 0)
    m14PatchCurrent(game,placed~=false,patches)
end

local function m14Offer(game,id)
    local run=game:getState().runState;local selected,selectedSeed
    for seed=1,3000 do
        local visit=Shop.createVisit(game.defs,{visitId=run.shopState.visitId,frozenUnlockPool=run.frozenUnlockPool,
            acquiredModuleIds=run.acquiredModuleIds,rngState=Rng.new(seed):getState()})
        if visit.offers.module==id then selected,selectedSeed=visit,seed break end
    end
    truthy(selected,"seeded offer missing "..id);run.shopState=selected
    truthy(game:_applyDurableRun(run,"transaction"));io.write("FIXTURE M14 seeded offer ",id," seed=",selectedSeed,"\n")
end

local function m14EarnedGame(offer,modules)
    local game,storage,checkpoint=newGame()
    m14PrepareWave(game,9,{m42Module("M03",20),m42Module("M08",20)},5,20)
    truthy(completeWave(game,9));equal(#game:getState().newModuleUnlocks,7)
    truthy(completeWave(game,10,"defeat","fixture_defeat"))
    truthy(game:requestNewRun());truthy(game:confirmNewRun())
    local run=game:getState().runState;run.hp,run.gold=5,100
    m42SetModules(run,modules or {});truthy(game:_applyDurableRun(run,"transaction"))
    if offer then m14Offer(game,offer) end
    return game,storage,checkpoint
end

local function m14DrawBoundary(view,state,roles)
    m15DrawBoundary(view,state,roles)
    m42ForScales(function(scale)
        view:draw(state)
        local guide=assert(view:findTextRole("primary_guide"));truthy(view:textBlockBounds(guide,scale).bottom<=112*scale)
    end)
end

test("M14 I01 actual Battle start restore late placement and immutable patch commands prove I14 and launch damage", function()
    local Battle=require("src.battle")
    local late=newGame();m14PrepareWave(late,9,{},19,0,false)
    truthy(late:startWave());truthy(late:selectTower(1));truthy(late:placeSelected(0,2));late:update(Battle.FIXED_DT)
    truthy(late.battle.run.towerInstances[1].placement);equal(late.session:getState().runState.towerInstances[1].placement,nil)
    m15FinishActual(late);equal(late:getState().moduleUnlockById.M14.permanentlyUnlocked,false)
    local game,storage,checkpoint=newGame();m14PrepareWave(game,9,{},19,0)
    truthy(game:startWave());equal(game:placeSelected(1,2),false);equal(game:recallTower(1),false)
    equal(game:selectOffer("patch"),false);equal(game:selectOffer("module"),false)
    equal(game:beginInventoryTransaction({kind="sell_tower",instanceId=1}),false)
    equal(game.session:dispatch({type="APPLY_DURABLE",checkpoint={}}).status,"rejected")
    local events=Battle.step(game.battle,Battle.FIXED_DT,{{type="recall_tower",instanceId=1},{type="remove_tower",instanceId=1},
        {type="purchase_patch",instanceId=1,patchId="P_DAMAGE"},{type="sell_module",moduleId="M14"},{type="place_tower",instanceId=1,x=1,y=2}})
    local rejected=0;for _,event in ipairs(events) do if event.type=="command_rejected" then rejected=rejected+1 end end;equal(rejected,5)
    local writes=storage.writeCount
    local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("restore cannot mint identity") end})
    equal(storage.writeCount,writes);equal(restored.battle.tick,0);restored:update(Battle.FIXED_DT);equal(restored.battle.tick,0)
    truthy(restored:resumeAll());truthy(restored:selectTower(2));truthy(restored:placeSelected(1,0));restored:update(Battle.FIXED_DT)
    local battle=m15FinishActual(restored);equal(battle.result.kind,"wave_complete");equal(restored:getState().moduleUnlockById.M14.permanentlyUnlocked,true)
    local plain=Content.clone(game.session:getState().runState);plain.modules={};plain.hp=20;plain.towerInstances[1].patchIds=Content.clone(M14_HIGH_PATCHES)
    local boosted=Content.clone(plain);boosted.modules={m42Module("M14",12)}
    local shots,firstTicks,launches={},{},{}
    for index,run in ipairs({plain,boosted}) do
        local live=assert(Battle.new(game.defs,run,"W09"));live.spawnSchedule,live.nextSpawnIndex={},1
        local enemy=live.enemies[1];enemy.baseSpeed,enemy.hp,enemy.maxHp=0,100000,100000
        live.towers[1].charge=0
        for _=1,300 do
            local step=assert(Battle.step(live,Battle.FIXED_DT))
            for _,event in ipairs(step) do if event.type=="tower_fired" and event.instanceId==1 then
                firstTicks[index]=firstTicks[index] or event.tick;launches[index]=event.launchDamage
                local projectile=live.projectiles[#live.projectiles];truthy(projectile);equal(projectile.sourceTowerId,1)
                close(projectile.launchBaseDamage,event.launchDamage)
            end end
        end
        shots[index]=live.observations.shots
    end
    equal(shots[1],shots[2]);equal(firstTicks[1],firstTicks[2]);close(launches[2],launches[1]*1.24)
    close(launches[1],game.defs.towersById.T01.damage*1.4)
    io.write("FIXTURE M14 I01 actual launch plain=",launches[1]," boosted=",launches[2]," lateIdentityExcluded=true\n")
end)

test("M14 I02 nominal six and preserved seven rights commit once and enter only successful next run", function()
    for _,normal in ipairs({true,false}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local game,storage,checkpoint=newGame()
        local modules=normal and {m42Module("M03",12),m42Module("M08",12),m42Module("M17",12),m42Module("M06",16)}
            or {m42Module("M03",20),m42Module("M08",20)}
        if normal then
            m42PrepareWave(game,9,{},5,72)
            local bought=game:getState().runState
            for _,id in ipairs({"M03","M08","M17","M06"}) do bought=assert(Rules.tryPurchaseModule(game.defs,bought,id)) end
            equal(bought.gold,20);truthy(game:_applyDurableRun(bought,"transaction"));m14PatchCurrent(game,true)
        else m14PrepareWave(game,9,modules,5,20) end
        truthy(game:startWave())
        local before,gen=game:getState(),generation(checkpoint)
        local expectedShop=Shop.createVisit(game.defs,{visitId="S03",frozenUnlockPool=before.runState.frozenUnlockPool,
            acquiredModuleIds=before.runState.acquiredModuleIds,rngState=before.runState.shopState.rngState})
        storage.writeMode=mode;equal(finishStartedWave(game,9),false)
        equal(Json.encode(game:getState().metaState),Json.encode(before.metaState));equal(#game:getState().newModuleUnlocks,0)
        local bytes=game.session.pending.candidate.encodedEnvelope;equal(game:retrySave().status,"save_error")
        equal(game.session.pending.candidate.encodedEnvelope,bytes)
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied")
        local after=game:getState();equal(#after.newModuleUnlocks,normal and 6 or 7);equal(generation(checkpoint),gen+1)
        equal(after.moduleUnlockById.M15.permanentlyUnlocked,true);equal(after.moduleUnlockById.M14.permanentlyUnlocked,true);equal(after.moduleUnlockById.M15.inCurrentRunPool,false)
        equal(Json.encode(after.runState.frozenUnlockPool),Json.encode(before.runState.frozenUnlockPool))
        equal(Json.encode(after.runState.shopState),Json.encode(expectedShop));equal(Json.encode(after.runState.modules),Json.encode(before.runState.modules))
        local ids={};for _,event in ipairs(after.newModuleUnlocks) do ids[#ids+1]=event.moduleId end
        equal(table.concat(ids,","),normal and "M28,M41,M46,M42,M15,M14" or "M28,M41,M43,M46,M42,M15,M14")
        equal(game:retrySave().status,"rejected");equal(finishStartedWave(game,9),false)
        truthy(completeWave(game,10,"defeat","fixture_defeat"));local result=Json.encode(game:getState().runState)
        truthy(game:requestNewRun());truthy(game:cancelNewRun());equal(Json.encode(game:getState().runState),result)
        truthy(game:requestNewRun());storage.writeMode="fail_before";equal(game:confirmNewRun(),false)
        equal(Json.encode(game:getState().runState),result);local newBytes=game.session.pending.candidate.encodedEnvelope
        storage.writeMode=nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,newBytes)
        local run=game:getState().runState;equal(#run.frozenUnlockPool.moduleIds,normal and 30 or 31)
        equal(#run.modules,0);equal(run.acquiredModuleIds.M15,nil);equal(run.acquiredModuleIds.M14,nil);equal(game:getState().moduleUnlockById.M15.inCurrentRunPool,true);equal(game:getState().moduleUnlockById.M14.inCurrentRunPool,true)
    end end
end)

test("M14 I03 ten legacy Game restores stay read only and earn I14 only from a new valid battle", function()
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1","DR-MOD-I15-r1"}
    for index,version in ipairs(versions) do
        local game,storage,checkpoint=newGame()
        if index>1 then m14PrepareWave(game,9,{m42Module("M01",20)},19,0) else m14PatchCurrent(game,true) end
        local payload=checkpoint:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion=version;run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={m42Module("M01",20)};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02";run.shopState.soldOut.module=false
        payload.metaState.unlockedModuleIds={};if index<4 then payload.metaState.unlockedTowerIds={"T01","T02","T03","T04"} end
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then run.modules[2]=m42Module("M33",9,6);run.acquiredModuleIds.M33=true;run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33" end
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"},{10,"M15"}}) do if index>=entry[1] then
            payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2]
        end end
        if index==10 then run.modules[3]=m42Module("M15",9);run.acquiredModuleIds.M15=true end
        assert(Save.createRun002Migrations(game.defs)[version].validatePayload(payload))
        storage.files={};writeShaEnvelope(storage,"save-b.json",34,version,payload)
        local writes=storage.writeCount;local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("legacy restore identity") end})
        local state=restored:getState();equal(storage.writeCount,writes);equal(state.moduleUnlockById.M14.permanentlyUnlocked,false);equal(#state.newModuleUnlocks,0)
        for _,key in ipairs({"modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(state.runState[key]),Json.encode(run[key]),version..key) end
        local pool=Json.encode(state.runState.frozenUnlockPool)
        truthy(restored:startWave());m15FinishActual(restored)
        equal(restored:getState().moduleUnlockById.M14.permanentlyUnlocked,index>1)
        equal(Json.encode(restored:getState().runState.frozenUnlockPool),pool)
        equal(restored:getState().moduleUnlockById.M14.inCurrentRunPool,false)
        equal(checkpoint:loadCheckpoint().payload.runState.contentVersion,game.defs.version)
    end
end)

test("M14 I04 eight lookup tabs and maintenance management preserve full contracts and input ownership", function()
    local labels={tower="포탑",deposit="예치금",spare="여유",emergency="비상",midlink="중가",assetlink="자산",mixed="혼합",maintenance="고급",balanced="균등",shared="공용",reserve="예비"}
    local xs={205,227,259,281,303,325,347,369,391,413,435}
    for _,earned in ipairs({false,true}) do
        local game,storage,checkpoint
        if earned then
            game,storage,checkpoint=m14EarnedGame("M14")
            m14PatchCurrent(game,true,{"P_FOCUSED_BARRAGE","P_HEAVY_AIM"})
            truthy(game:selectOffer("module"));truthy(game:confirmPurchase())
        else game,storage,checkpoint=newGame() end
        local view,input,find,click,text=assembledUi(game)
        local before,writes,gen=Json.encode(game:getState().runState),storage.writeCount,generation(checkpoint)
        view:draw(game:getState());truthy(click("open_tower_unlocks"));view:draw(game:getState())
        local tabs={"tower","deposit","spare","emergency","midlink","assetlink","mixed","maintenance"}
        for _,tab in ipairs(tabs) do truthy(click("unlock_lookup_tab",function(a)return a.tab==tab end));view:draw(game:getState()) end
        local roles={};for _,role in ipairs({"permanent","condition","effect","attempt","pool","offer","next_run"}) do roles[#roles+1]="module_unlock_M14_"..role end
        m14DrawBoundary(view,game:getState(),roles)
        for _,token in ipairs({"중가12G","슬롯1","W09–14","같은 타워1기","정가합≥21G","7×3 가능","고가 불필요","완료직전","늦은배치","미완료","중복","피해+8%p","모듈 피해 합산","무료 지급/등장 보장 없음"}) do truthy(text():find(token,1,true),token) end
        m42ForScales(function(scale)
            view:draw(game:getState());local count=0
            for _,button in ipairs(view.buttons) do if button.action.type=="unlock_lookup_tab" then
                count=count+1;equal(button.label,labels[button.action.tab]);equal(button.x,xs[count]);equal(button.y,116)
                equal(button.w,button.action.tab=="deposit" and 32 or 22);equal(button.textSize,9);truthy(view:buttonLabelFits(button,scale));truthy(button.x+button.w<=465)
            end end;equal(count,11)
        end)
        local x,y=m46WindowPoint(view,0,2);input:mousepressed(x,y,1)
        equal(storage.writeCount,writes);equal(generation(checkpoint),gen);equal(Json.encode(game:getState().runState),before)
        truthy(input:keypressed("escape",false));equal(view:hasTowerUnlocks(),false)
        if earned then
            truthy(view:openInventoryManagement("module"));truthy(view:selectManagedModule("M14"));m14DrawBoundary(view,game:getState())
            truthy(text():find("선택#1 고가2개",1,true));truthy(text():find("피해20.88/+16%p",1,true))
            equal(assert(find("begin_inventory_transaction",function(a)return a.moduleId=="M14" end)).y,226)
            truthy(game:cancelSelection());view:draw(game:getState());truthy(text():find("선택 타워 없음",1,true))
            truthy(input:keypressed("escape",false));truthy(input:keypressed("escape",false))
        end
        truthy(game:startWave());equal(view:openTowerUnlocks(game:getState()),false)
    end
end)

test("M14 I05 maintenance buy sale and mixed previews show actual linked effects and saved alert contracts", function()
    local game,storage=m14EarnedGame("M14",{m42Module("M41",16),m42Module("M42",16),m42Module("M43",12)})
    m14PatchCurrent(game,true,{"P_FOCUSED_BARRAGE","P_HEAVY_AIM","P_RATE"})
    local view,input,find,click,text=assembledUi(game)
    local before,writes=Json.encode(game:getState().runState),storage.writeCount
    truthy(game:selectOffer("module"));local draft=game:getState().purchaseDraft
    equal(draft.cost,12);equal(draft.slotBefore,3);equal(draft.slotAfter,4);equal(draft.maintenanceTrade.afterMaintenanceStatus.bonusPercentPoints,16)
    m14DrawBoundary(view,game:getState(),{"m14_draft_title","m14_draft_offer_effect","m14_draft_links","m14_draft_selected","m14_draft_detail"})
    truthy(text():find("중가1→2종/+8→16%p",1,true));truthy(text():find("자산28→40G/+14→20%p",1,true))
    equal(view:openTowerUnlocks(game:getState()),false)
    truthy(game:selectTower(2));equal(game:getState().purchaseDraft.maintenanceTrade.afterMaintenanceStatus.bonusPercentPoints,0)
    truthy(game:cancelSelection());equal(game:getState().purchaseDraft.maintenanceTrade.error,"tower_not_selected");m14DrawBoundary(view,game:getState())
    equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
    truthy(game:selectTower(1));truthy(game:cancelPurchase());truthy(game:selectOffer("module"));truthy(game:confirmPurchase())
    local run=game:getState().runState;local entry=findModuleEntry(run,"M14");equal(entry.paidGold,12);entry.paidGold=9
    truthy(game:_applyDurableRun(run,"transaction"));truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M14"}))
    draft=game:getState().transactionDraft;equal(draft.paidGold,9);equal(draft.refundGold,4)
    m14DrawBoundary(view,game:getState(),{"m14_sale_offer_effect","m14_sale_paid","m14_draft_links","m14_draft_selected","m14_sale_history","m14_sale_capacity","m14_sale_recall"})
    local gold=game:getState().runState.gold;truthy(game:confirmInventoryTransaction())
    equal(game:getState().runState.gold,gold+4);equal(game:getState().runState.acquiredModuleIds.M14,true)
    equal(game:getState().moduleUnlockById.M14.permanentlyUnlocked,true);equal(Rules.tryPurchaseModule(game.defs,game:getState().runState,"M14"),nil)
    local mixed,mixedStorage=m14EarnedGame("M15",{m42Module("M14",12),m42Module("M41",16),m42Module("M42",16)})
    m14PatchCurrent(mixed,true,M14_HIGH_PATCHES);local mixedView=assembledUi(mixed)
    local mixedBefore,mixedWrites=Json.encode(mixed:getState().runState),mixedStorage.writeCount
    truthy(mixed:selectOffer("module"));draft=mixed:getState().purchaseDraft
    equal(draft.mixedTrade.beforeStatus.bonusPercentPoints,0);equal(draft.mixedTrade.afterStatus.bonusPercentPoints,20)
    equal(draft.maintenanceTrade.beforeMaintenanceStatus.bonusPercentPoints,24);equal(draft.maintenanceTrade.afterMaintenanceStatus.bonusPercentPoints,24)
    m14DrawBoundary(mixedView,mixed:getState());local guide=assert(mixedView:findTextRole("primary_guide")).value
    truthy(guide:find("M14+24→24%p",1,true));truthy(guide:find("M15+0→20%p",1,true));truthy(guide:find("피해",1,true));truthy(guide:find("속도",1,true))
    truthy(mixed:cancelPurchase());equal(mixedStorage.writeCount,mixedWrites);equal(Json.encode(mixed:getState().runState),mixedBefore)
    local refund=m14EarnedGame(nil,{m42Module("M29",8)})
    m14PatchCurrent(refund,false,{"P_OVERLOAD","P_OVERLOAD","P_OVERLOAD"})
    equal(refund:getState().runState.gold,102);equal(assert(Rules.patchInvestmentComposition(refund.defs,refund:getState().runState)).towerDetails[1].nominalPatchPrice,21)
    local single=newGame();m14PrepareWave(single,9,{},19,0,true,{"P_OVERLOAD","P_OVERLOAD","P_OVERLOAD"})
    truthy(completeWave(single,9));equal(#single:getState().newModuleUnlocks,1);equal(single:getState().newModuleUnlocks[1].moduleId,"M14")
    local singleView=assembledUi(single);m14DrawBoundary(singleView,single:getState())
    local feedback=assert(singleView:_newTowerUnlockFeedback(single:getState()));truthy(feedback:find("정가합≥21G",1,true));truthy(feedback:find("피해+8%p",1,true))
    local seven=newGame();m14PrepareWave(seven,9,{m42Module("M03",20),m42Module("M08",20)},5,20);truthy(completeWave(seven,9))
    local state=seven:getState();equal(#state.newModuleUnlocks,7);local sevenView=assembledUi(seven);m14DrawBoundary(sevenView,state)
    for _,name in ipairs({"예치금","중가 연동","여유 회로","비상 출력","자산 연동","혼합 개조","고급 정비"}) do truthy(sevenView:_newTowerUnlockFeedback(state):find(name,1,true)) end
    state.newTowerUnlocks={{towerId="T05"}};m14DrawBoundary(sevenView,state)
    truthy(sevenView:_newTowerUnlockFeedback(state):find("저격 포탑",1,true))
    io.write("FIXTURE M14 I05 nominalPrice21 refundNet19 actualSeven=true syntheticEight=true singleConditionAndEffect=true\n")
end)

test("M14 I06 exact capacity recalls cancel and retry atomically preserve patched identities and both bonuses", function()
    for _,sale in ipairs({true,false}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local modules=sale and {m42Module("M05",16),m42Module("M14",12),m42Module("M15",12),m42Module("M28",12)}
            or {m42Module("M14",12),m42Module("M15",12),m42Module("M28",12)}
        local game,storage=m14EarnedGame(nil,modules)
        local run=game:getState().runState;run.towerInstances={};local count=sale and 8 or 6
        for id=1,count do run.towerInstances[id]={instanceId=id,typeId="T01",paidGold=id,
            patchIds=id==1 and Content.clone(M14_HIGH_PATCHES) or {"P_DAMAGE"},placement={x=id-1,y=0},charge=0,activated=true} end
        run.nextInstanceId=count+1;truthy(game:_applyDurableRun(run,"transaction"));truthy(game:selectTower(1))
        if not sale then m14Offer(game,"M06") end
        local before,writes=Json.encode(game:getState().runState),storage.writeCount
        local view,input=assembledUi(game)
        local function begin()if sale then truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M05"})) else truthy(game:selectOffer("module")) end end
        local function draft()local state=game:getState();return sale and state.transactionDraft or state.purchaseDraft end
        local function choose(id,value)if sale then return game:setInventoryRecallSelection(id,value) else return game:setPurchaseRecallSelection(id,value) end end
        local required=2 -- M05: 8 to 6; M06: 6 to 4, both require two exact recalls
        begin();equal(draft().requiredRecallCount,required);equal(draft().canCommit,false);equal(draft().maintenanceTrade.after,nil);equal(draft().mixedTrade.after,nil)
        m14DrawBoundary(view,game:getState());truthy(input:keypressed("escape",false));equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
        begin();equal(choose(99),false);truthy(choose(1));equal(draft().maintenanceTrade.after,nil)
        for id=2,required do truthy(choose(id)) end
        equal(draft().canCommit,true);equal(draft().maintenanceTrade.afterMaintenanceStatus.selectedTowerPlaced,false)
        equal(draft().maintenanceTrade.afterMaintenanceStatus.bonusPercentPoints,0);equal(draft().mixedTrade.afterStatus.bonusPercentPoints,0)
        equal(choose(required+1),false);m14DrawBoundary(view,game:getState())
        local duplicate={1,1}
        if sale then equal(Rules.tryInventoryTransaction(game.defs,game:getState().runState,{phase="SHOP",kind="sell_module",moduleId="M05",recallTowerIds=duplicate}),nil)
        else equal(Rules.tryPurchaseModule(game.defs,game:getState().runState,"M06",duplicate),nil) end
        storage.writeMode=mode;if sale then equal(game:confirmInventoryTransaction(),false) else equal(game:confirmPurchase(),false) end
        equal(Json.encode(game:getState().runState),before);local bytes=game.session.pending.candidate.encodedEnvelope
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
        local after=game:getState().runState;equal(#after.towerInstances,count)
        for id=1,required do equal(after.towerInstances[id].placement,nil) end
        equal(#after.towerInstances[1].patchIds,3);equal(after.towerInstances[1].paidGold,1)
        equal(findModuleEntry(after,"M14").paidGold,12);equal(findModuleEntry(after,"M15").paidGold,12)
        equal(after.acquiredModuleIds.M14,true);equal(after.acquiredModuleIds.M15,true)
    end end
end)


local M12_RIGHTS={"M12","M14","M15","M28","M41","M42","M43","M46"}
local function m12Inventory(game,placed,total,patches,unpatchedIds,gold)
    local run=game:getState().runState;run.gold=1000
    while #run.towerInstances<total do run=assert(Rules.tryPurchaseTower(game.defs,run,"T01")) end
    for id=1,total do
        local tower=assert(findTowerById(run,id))
        local wanted=unpatchedIds and unpatchedIds[id] and 0 or #patches
        for index=#tower.patchIds+1,wanted do run=assert(Rules.tryPurchasePatch(game.defs,run,id,patches[index])) end
        if id<=placed and not findTowerById(run,id).placement then
            run=assert(Rules.tryPlaceTower(game.defs,run,run.mapId,id,id==1 and 0 or id-1,id==1 and 2 or 0,"prepare"))
        end
    end
    run.gold=gold or 100;truthy(game:_applyDurableRun(run,"transaction"));return game:getState().runState
end
local function m12PrepareWave(game,index,modules,hp,gold,placed,total,patches,unpatchedIds)
    m42PrepareWave(game,index,modules or {},hp or 19,gold or 0)
    return m12Inventory(game,placed or 3,total or 3,patches or {"P_DAMAGE"},unpatchedIds,gold or 0)
end
local function m12Offer(game,kind,id)
    local run=game:getState().runState;local selected,selectedSeed
    for seed=1,4000 do
        local visit=Shop.createVisit(game.defs,{visitId=run.shopState.visitId,frozenUnlockPool=run.frozenUnlockPool,
            acquiredModuleIds=run.acquiredModuleIds,rngState=Rng.new(seed):getState()})
        if visit.offers[kind]==id then selected,selectedSeed=visit,seed break end
    end
    truthy(selected,"M12 seeded offer missing "..id);run.shopState=selected
    truthy(game:_applyDurableRun(run,"transaction"));io.write("FIXTURE M12 seeded ",kind," offer ",id," seed=",selectedSeed,"\n")
end
local function m12EarnedGame(offer,modules)
    local game,storage,checkpoint=newGame()
    m12PrepareWave(game,9,{m42Module("M03",20),m42Module("M08",20)},5,20,3,3,M14_MID_PATCHES)
    truthy(game:startWave());m15FinishActual(game);equal(#game:getState().newModuleUnlocks,8)
    truthy(completeWave(game,10,"defeat","fixture_defeat"));truthy(game:requestNewRun());truthy(game:confirmNewRun())
    local run=game:getState().runState;run.hp,run.gold=5,100;m42SetModules(run,modules or {})
    truthy(game:_applyDurableRun(run,"transaction"));if offer then m12Offer(game,"module",offer) end
    return game,storage,checkpoint
end
local function m12DrawBoundary(view,state,roles)
    m15DrawBoundary(view,state,roles)
    m42ForScales(function(scale)
        view:draw(state);local guide=assert(view:findTextRole("primary_guide"))
        truthy(view:textBlockBounds(guide,scale).bottom<=112*scale,"M12 guide bottom")
    end)
end

test("M12 I01 actual Battle interval admits balanced late fourth but rejects late imbalance and late third start", function()
    local Battle=require("src.battle")
    for _,case in ipairs({{3,4,false,true},{3,4,true,false},{2,3,false,false},{3,3,false,true}}) do
        local game,storage,checkpoint=newGame()
        m12PrepareWave(game,6,{},19,0,case[1],case[2],{"P_DAMAGE"},case[3] and {[4]=true} or nil)
        truthy(game:startWave())
        if case[2]>case[1] then truthy(game:selectTower(case[2]));truthy(game:placeSelected(5,0));game:update(Battle.FIXED_DT) end
        equal(game:recallTower(1),false);equal(game:selectOffer("patch"),false)
        truthy(game:selectTower(1));equal(game:placeSelected(4,0),false)
        local rejected=Battle.step(game.battle,Battle.FIXED_DT,{{type="recall_tower",instanceId=1},{type="remove_tower",instanceId=1},
            {type="purchase_patch",instanceId=1,patchId="P_DAMAGE"},{type="sell_module",moduleId="M12"}})
        local count=0;for _,event in ipairs(rejected) do if event.type=="command_rejected" then count=count+1 end end;equal(count,4)
        m15FinishActual(game);equal(game:getState().moduleUnlockById.M12.permanentlyUnlocked,case[4])
    end
    local game,storage,checkpoint=newGame();m12PrepareWave(game,14,{},19,0)
    truthy(game:startWave());local writes=storage.writeCount
    local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("restore must not mint") end})
    equal(storage.writeCount,writes);restored:update(Battle.FIXED_DT);equal(restored.battle.tick,0)
    truthy(restored:resumeAll());m15FinishActual(restored);equal(restored:getState().moduleUnlockById.M12.permanentlyUnlocked,true)
end)

test("M12 I02 actual target boundary and late placement update range acquisition status and draw in the same tick", function()
    local Battle=require("src.battle")
    local game=m12EarnedGame(nil,{m42Module("M12",12)})
    m42PrepareWave(game,6,{m42Module("M12",12)},19,0)
    m12Inventory(game,2,3,{"P_DAMAGE"},{[3]=true},0)
    local run=game:getState().runState;run.towerInstances[2].placement={x=12,y=0};truthy(game:_applyDurableRun(run,"transaction"))
    truthy(game:selectTower(1));truthy(game:startWave());local live=game.battle
    live.spawnSchedule,live.nextSpawnIndex={},1
    local enemy=assert(live.enemies[1]);enemy.baseSpeed,enemy.hp,enemy.maxHp=0,100000,100000
    local active=assert(Rules.projectStats(game.defs,live.run,1));local plain=Content.clone(live.run);plain.modules={}
    local base=assert(Rules.projectStats(game.defs,plain,1));close(active.range,base.range*1.25)
    local boundary=math.sqrt(active.range*active.range-1)
    enemy.s=boundary-1e-5;truthy(Battle.selectTarget(live,live.towers[1],active));equal(Battle.selectTarget(live,live.towers[1],base),nil)
    enemy.s=boundary+1e-4;equal(Battle.selectTarget(live,live.towers[1],active),nil)
    enemy.s=math.sqrt(((base.range+active.range)/2)^2-1)
    live.towers[1].charge=1;game:update(Battle.FIXED_DT)
    equal(live.observations.shots,1);local projectile=assert(live.projectiles[1]);equal(projectile.sourceTowerId,1);equal(projectile.targetId,enemy.enemyId)
    local view=View.new(game.defs);view:draw(game:getState());truthy(view:findTextRole("m12_combat_range").value:find("+25%p",1,true))
    truthy(game:selectTower(3));truthy(game:placeSelected(5,0));truthy(game:selectTower(1));live.towers[1].charge=1
    game:update(Battle.FIXED_DT);equal(live.observations.shots,1);truthy(live.projectiles[1]);equal(live.projectiles[1].projectileId,projectile.projectileId)
    local state=game:getState();equal(state.moduleStatusById.M12.active,false);equal(state.moduleStatusById.M12.placedTowerCount,3)
    equal(state.moduleStatusById.M12.bonusPercentPoints,0);close(state.moduleStatusById.M12.selectedRange,base.range)
    view:draw(state);truthy(view:findTextRole("m12_combat_range").value:find("+0%p",1,true));equal(state.battle.tick,live.tick)
    local inactive=assert(Rules.projectStats(game.defs,live.run,1));close(inactive.damage,base.damage);close(inactive.attackRate,base.attackRate)
    equal(inactive.chainRange,base.chainRange)
    io.write("FIXTURE M12 I02 base=",base.range," active=",active.range," sameTick=",live.tick," acquisitionOFF=true\n")
end)

test("M12 I03 nominal seven and preserved eight rights commit once and enter only successful next run", function()
    for _,normal in ipairs({true,false}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local game,storage,checkpoint=newGame()
        local modules=normal and {m42Module("M03",12),m42Module("M08",12),m42Module("M17",12),m42Module("M06",16)}
            or {m42Module("M03",20),m42Module("M08",20)}
        m12PrepareWave(game,9,modules,5,20,3,3,M14_MID_PATCHES)
        truthy(game:startWave());local before,gen=game:getState(),generation(checkpoint)
        local expectedShop=Shop.createVisit(game.defs,{visitId="S03",frozenUnlockPool=before.runState.frozenUnlockPool,
            acquiredModuleIds=before.runState.acquiredModuleIds,rngState=before.runState.shopState.rngState})
        storage.writeMode=mode;m15FinishActual(game);equal(game:getState().phase,"SAVE_ERROR")
        equal(Json.encode(game:getState().metaState),Json.encode(before.metaState));equal(#game:getState().newModuleUnlocks,0)
        local bytes=game.session.pending.candidate.encodedEnvelope;equal(game:retrySave().status,"save_error")
        equal(game.session.pending.candidate.encodedEnvelope,bytes)
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied")
        local after=game:getState();equal(#after.newModuleUnlocks,normal and 7 or 8);equal(generation(checkpoint),gen+1)
        equal(after.moduleUnlockById.M12.permanentlyUnlocked,true);equal(after.moduleUnlockById.M12.inCurrentRunPool,false)
        equal(Json.encode(after.runState.frozenUnlockPool),Json.encode(before.runState.frozenUnlockPool));equal(Json.encode(after.runState.shopState),Json.encode(expectedShop))
        local ids={};for _,event in ipairs(after.newModuleUnlocks) do ids[#ids+1]=event.moduleId end
        equal(table.concat(ids,","),normal and "M28,M41,M46,M42,M15,M14,M12" or "M28,M41,M43,M46,M42,M15,M14,M12")
        equal(game:retrySave().status,"rejected");equal(finishStartedWave(game,9),false)
        truthy(completeWave(game,10,"defeat","fixture_defeat"));local result=Json.encode(game:getState().runState)
        truthy(game:requestNewRun());truthy(game:cancelNewRun());equal(Json.encode(game:getState().runState),result)
        truthy(game:requestNewRun());storage.writeMode="fail_before";equal(game:confirmNewRun(),false)
        equal(Json.encode(game:getState().runState),result);local newBytes=game.session.pending.candidate.encodedEnvelope
        storage.writeMode=nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,newBytes)
        local run=game:getState().runState;equal(#run.frozenUnlockPool.moduleIds,normal and 31 or 32)
        equal(#run.modules,0);equal(run.acquiredModuleIds.M12,nil);equal(game:getState().moduleUnlockById.M12.inCurrentRunPool,true)
        io.write("FIXTURE M12 simultaneous ",normal and "nominal-seven" or "preserved-eight"," one generation\n")
    end end
end)

test("M12 I04 eleven historical Game restores remain read only and earn I12 only from new supported battles", function()
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1","DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1","DR-MOD-I15-r1","DR-MOD-I14-r1"}
    for index,version in ipairs(versions) do
        local game,storage,checkpoint=newGame()
        if index>1 then m42PrepareWave(game,6,{m42Module("M01",20)},19,0) end
        m12Inventory(game,3,3,M14_MID_PATCHES,nil,0)
        local payload=checkpoint:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion=version;run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={m42Module("M01",20)};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02";run.shopState.soldOut.module=false
        payload.metaState.unlockedModuleIds={};if index<4 then payload.metaState.unlockedTowerIds={"T01","T02","T03","T04"} end
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then run.modules[2]=m42Module("M33",9,6);run.acquiredModuleIds.M33=true;run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33" end
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"},{10,"M15"},{11,"M14"}}) do if index>=entry[1] then
            payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2]
        end end
        if index>=10 then run.modules[3]=m42Module("M15",9);run.acquiredModuleIds.M15=true end
        if index==11 then run.modules[4]=m42Module("M14",9);run.acquiredModuleIds.M14=true end
        assert(Save.createRun002Migrations(game.defs)[version].validatePayload(payload))
        storage.files={};writeShaEnvelope(storage,"save-b.json",34,version,payload)
        local writes=storage.writeCount;local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("legacy cannot mint") end})
        local state=restored:getState();equal(storage.writeCount,writes);equal(state.moduleUnlockById.M12.permanentlyUnlocked,false);equal(#state.newModuleUnlocks,0)
        for _,key in ipairs({"modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(state.runState[key]),Json.encode(run[key]),version..key) end
        local pool=Json.encode(state.runState.frozenUnlockPool);truthy(restored:startWave());m15FinishActual(restored)
        equal(restored:getState().moduleUnlockById.M12.permanentlyUnlocked,index>1)
        equal(Json.encode(restored:getState().runState.frozenUnlockPool),pool);equal(restored:getState().moduleUnlockById.M12.inCurrentRunPool,false)
        equal(checkpoint:loadCheckpoint().payload.runState.contentVersion,game.defs.version)
    end
end)

test("M12 I05 nine lookup tabs and balanced management preserve contracts geometry and input ownership", function()
    local game,storage=newGame();local view,input,findAction=assembledUi(game);local writes=storage.writeCount
    view:draw(game:getState());truthy(view:openTowerUnlocks(game:getState()));truthy(view:setUnlockLookupTab("balanced"))
    local roles={};for _,suffix in ipairs({"permanent","condition","effect","attempt","pool","offer","next_run"}) do roles[#roles+1]="module_unlock_M12_"..suffix end
    m12DrawBoundary(view,game:getState(),roles)
    truthy(view:findTextRole(roles[2]).value:find("배치3기",1,true));truthy(view:findTextRole(roles[3]).value:find("배치2기",1,true))
    local tabs=0;for _,button in ipairs(view.buttons) do if button.action.type=="unlock_lookup_tab" then
        tabs=tabs+1;equal(button.textSize,9);equal(button.w,button.action.tab=="deposit" and 32 or 22)
        for scale=1,3 do truthy(view:buttonLabelFits(button,scale)) end
    end end;equal(tabs,11)
    for _,tab in ipairs({"tower","deposit","spare","emergency","midlink","assetlink","mixed","maintenance","balanced"}) do truthy(view:setUnlockLookupTab(tab));view:draw(game:getState()) end
    equal(input:mousepressed(-2,-2,1),false);equal(input:mousepressed(2,2,1),true);truthy(input:keypressed("escape",false));equal(view:hasTowerUnlocks(),false);equal(storage.writeCount,writes)
    game=m12EarnedGame(nil,{m42Module("M12",12)});m12Inventory(game,2,3,{"P_DAMAGE"},nil,100);truthy(game:selectTower(1))
    local state=game:getState();equal(state.moduleStatusById.M12.active,true);equal(state.moduleUnlockById.M12.currentAttemptQualifies,false)
    local managed=View.new(game.defs);truthy(managed:openInventoryManagement("module"));truthy(managed:selectManagedModule("M12"))
    m12DrawBoundary(managed,state);truthy(managed:_moduleStatusLines(state,"M12"):find("배치2기",1,true))
    truthy(game:selectTower(3));equal(game:getState().moduleStatusById.M12.bonusPercentPoints,0)
    truthy(game:closeShop());truthy(game:startWave());managed:draw(game:getState());equal(managed:hasTowerUnlocks(),false)
end)

test("M12 I06 balanced buy sale and patch previews show actual linked effects and saved alert contracts", function()
    local game,storage=m12EarnedGame("M12",{m42Module("M41",16),m42Module("M42",16),m42Module("M43",12)})
    m12Inventory(game,3,3,{"P_DAMAGE"},nil,100);truthy(game:selectTower(1));local before=Json.encode(game:getState().runState);local writes=storage.writeCount
    truthy(game:selectOffer("module"));local draft=game:getState().purchaseDraft;equal(draft.cost,12);equal(draft.slotAfter,4)
    equal(draft.balancedTrade.afterBalancedStatus.bonusPercentPoints,25);equal(draft.midLinkAfter.bonusPercentPoints,16)
    equal(draft.assetLinkAfter.otherModulePaidGold,40);equal(draft.spareCircuitAfter.bonusPercentPoints,0)
    local view=View.new(game.defs);m12DrawBoundary(view,game:getState(),{"m12_draft_title","m12_draft_offer_effect","m12_draft_links","m12_draft_selected","m12_draft_detail"})
    truthy(game:selectTower(2));equal(game:getState().purchaseDraft.balancedTrade.towerInstanceId,2);truthy(game:cancelSelection())
    equal(game:getState().purchaseDraft.balancedTrade.error,"tower_not_selected");truthy(game:cancelPurchase());equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
    truthy(game:selectTower(1));truthy(game:selectOffer("module"));truthy(game:confirmPurchase())
    local run=game:getState().runState;findModuleEntry(run,"M12").paidGold=9;truthy(game:_applyDurableRun(run,"transaction"))
    truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M12"}));equal(game:getState().transactionDraft.refundGold,4)
    m12DrawBoundary(view,game:getState(),{"m12_sale_offer_effect","m12_sale_paid","m12_draft_links","m12_draft_selected","m12_sale_history","m12_sale_capacity","m12_sale_recall"})
    truthy(game:confirmInventoryTransaction());equal(game:getState().moduleUnlockById.M12.permanentlyUnlocked,true)
    equal(Rules.tryPurchaseModule(game.defs,game:getState().runState,"M12"),nil)
    local patched=m12EarnedGame(nil,{m42Module("M12",12),m42Module("M29",12),m42Module("M34",12,6)})
    m12Inventory(patched,2,2,{"P_DAMAGE"},nil,100);truthy(patched:selectTower(1));m12Offer(patched,"patch","P_RANGE")
    truthy(patched:selectOffer("patch"));local p=patched:getState().purchaseDraft.balancedTrade
    equal(p.beforeBalancedStatus.bonusPercentPoints,25);equal(p.afterBalancedStatus.bonusPercentPoints,0)
    local actual=assert(Rules.tryPurchasePatch(patched.defs,patched:getState().runState,1,"P_RANGE"))
    close(p.after.range,Rules.projectStats(patched.defs,actual,1).range);m12DrawBoundary(View.new(patched.defs),patched:getState())
    truthy(patched:confirmPurchase());truthy(patched:selectTower(2));m12Offer(patched,"patch","P_RANGE");truthy(patched:selectOffer("patch"))
    equal(patched:getState().purchaseDraft.balancedTrade.afterBalancedStatus.bonusPercentPoints,25);truthy(patched:cancelPurchase())
    local coexist=m12EarnedGame("M12",{m42Module("M14",12),m42Module("M15",12),m42Module("M41",16)})
    m12Inventory(coexist,3,3,M14_HIGH_PATCHES,nil,100);truthy(coexist:selectTower(1));truthy(coexist:selectOffer("module"))
    local q=coexist:getState().purchaseDraft.balancedTrade;equal(q.afterMaintenanceStatus.bonusPercentPoints,24);equal(q.afterStatus.bonusPercentPoints,20)
    m12DrawBoundary(View.new(coexist.defs),coexist:getState())
    local alert=newGame();m12PrepareWave(alert,6,{},19,0);truthy(alert:startWave());m15FinishActual(alert)
    local single=alert:getState();equal(#single.newModuleUnlocks,1);local alertView=View.new(alert.defs);m12DrawBoundary(alertView,single)
    local feedback=assert(alertView:_newTowerUnlockFeedback(single));truthy(feedback:find("배치3기",1,true));truthy(feedback:find("장착2기",1,true))
    local actualEight=newGame();m12PrepareWave(actualEight,9,{m42Module("M03",20),m42Module("M08",20)},5,20,3,3,M14_MID_PATCHES)
    truthy(actualEight:startWave());m15FinishActual(actualEight);equal(#actualEight:getState().newModuleUnlocks,8);m12DrawBoundary(View.new(actualEight.defs),actualEight:getState())
    local synthetic=actualEight:getState();synthetic.newTowerUnlocks={{type="tower_unlocked",towerId="T05"}};local stress=View.new(actualEight.defs);m12DrawBoundary(stress,synthetic)
    truthy(stress:findTextRole("module_unlock_common_feedback").value:find("해금 상세",1,true))
    io.write("FIXTURE M12 synthetic-nine display-only=true checkpointReachability=false\n")
end)

test("M12 I07 exact recalls tower sales cancel and retry preserve identities and selected versus aggregate bonuses", function()
    for _,sale in ipairs({true,false}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local modules={m42Module("M12",12),m42Module("M14",12),m42Module("M15",12)}
        if sale then modules[4]=m42Module("M05",16) end
        local game,storage=m12EarnedGame(sale and nil or "M06",modules)
        local count=sale and 8 or 6;m12Inventory(game,count,count,M14_HIGH_PATCHES,nil,100);truthy(game:selectTower(1))
        local before,writes=Json.encode(game:getState().runState),storage.writeCount
        local function begin()if sale then truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M05"})) else truthy(game:selectOffer("module")) end end
        local function draft()local state=game:getState();return sale and state.transactionDraft or state.purchaseDraft end
        local function choose(id,value)if sale then return game:setInventoryRecallSelection(id,value) else return game:setPurchaseRecallSelection(id,value) end end
        begin();equal(draft().requiredRecallCount,2);equal(draft().balancedTrade.after,nil)
        m12DrawBoundary(View.new(game.defs),game:getState());if sale then truthy(game:cancelInventoryTransaction()) else truthy(game:cancelPurchase()) end
        equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
        begin();equal(choose(99),false);truthy(choose(1));equal(draft().balancedTrade.after,nil);truthy(choose(2))
        equal(draft().balancedTrade.afterBalancedStatus.bonusPercentPoints,0);equal(draft().balancedTrade.afterMaintenanceStatus.bonusPercentPoints,0)
        equal(draft().balancedTrade.afterStatus.bonusPercentPoints,0);equal(choose(3),false)
        local duplicate={1,1};if sale then equal(Rules.tryInventoryTransaction(game.defs,game:getState().runState,{phase="SHOP",kind="sell_module",moduleId="M05",recallTowerIds=duplicate}),nil)
        else equal(Rules.tryPurchaseModule(game.defs,game:getState().runState,"M06",duplicate),nil) end
        storage.writeMode=mode;if sale then equal(game:confirmInventoryTransaction(),false) else equal(game:confirmPurchase(),false) end
        equal(Json.encode(game:getState().runState),before);local bytes=game.session.pending.candidate.encodedEnvelope
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
        local after=game:getState().runState;equal(#after.towerInstances,count);equal(after.towerInstances[1].placement,nil);equal(#after.towerInstances[1].patchIds,3)
        equal(Rules.projectModuleStatus(game.defs,after,"M12",{towerInstanceId=3}).bonusPercentPoints,25)
    end end
    local recall=m12EarnedGame(nil,{m42Module("M12",12)});m12Inventory(recall,3,4,{"P_DAMAGE"},{[4]=true},100)
    truthy(recall:selectTower(1));truthy(recall:recallTower(1));equal(recall:getState().moduleStatusById.M12.active,true)
    truthy(recall:recallTower(2));equal(recall:getState().moduleStatusById.M12.active,false)
    local sold=m12EarnedGame(nil,{m42Module("M12",12)});m12Inventory(sold,4,4,{"P_DAMAGE"},{[4]=true},100);truthy(sold:selectTower(1))
    equal(sold:getState().moduleStatusById.M12.active,false);truthy(sold:beginInventoryTransaction({kind="sell_tower",instanceId=4}))
    equal(sold:getState().transactionDraft.balancedTrade.afterBalancedStatus.bonusPercentPoints,25);truthy(sold:confirmInventoryTransaction())
    equal(sold:getState().moduleStatusById.M12.active,true)
end)

local M16_RIGHTS={"M12","M14","M15","M16","M28","M41","M42","M43","M46"}
local M16_FLEET={{"P_OVERLOAD","P_OVERDRIVE","P_LONG_RANGE"},{"P_DAMAGE","P_RATE","P_DAMAGE"},{"P_DAMAGE","P_DAMAGE","P_DAMAGE"}}
local function m16Inventory(game,patchSets,placed,gold)
    local run=game:getState().runState;run.gold=1000
    while #run.towerInstances<#patchSets do run=assert(Rules.tryPurchaseTower(game.defs,run,"T01")) end
    for id,patches in ipairs(patchSets) do
        local tower=assert(findTowerById(run,id));equal(#tower.patchIds,0,"fresh inventory fixture required")
        for _,patch in ipairs(patches) do run=assert(Rules.tryPurchasePatch(game.defs,run,id,patch)) end
        if id<=placed then run=assert(Rules.tryPlaceTower(game.defs,run,run.mapId,id,id==1 and 0 or id-1,id==1 and 2 or 0,"prepare")) end
    end
    run.gold=gold or 100;truthy(game:_applyDurableRun(run,"transaction"));return game:getState().runState
end
local function m16Prepare(game,index,modules,hp,gold,patchSets,placed)
    m42PrepareWave(game,index,modules or {},hp or 19,gold or 0)
    return m16Inventory(game,patchSets or M16_FLEET,placed or #(patchSets or M16_FLEET),gold or 0)
end
local function m16EarnedGame(offer,modules)
    local game,storage,checkpoint=newGame()
    m16Prepare(game,12,{m42Module("M03",20),m42Module("M08",20)},20,20)
    truthy(game:startWave());m15FinishActual(game);equal(#game:getState().newModuleUnlocks,9)
    truthy(completeWave(game,13,"defeat","fixture_defeat"));truthy(game:requestNewRun());truthy(game:confirmNewRun())
    local run=game:getState().runState;run.hp,run.gold=5,100;m42SetModules(run,modules or {})
    truthy(game:_applyDurableRun(run,"transaction"));if offer then m12Offer(game,"module",offer) end
    return game,storage,checkpoint
end
local function m16Capture(name,view,game,scale,state)
    if not _G.M16_CAPTURE then return end
    if type(view)=="function" then view=view() end
    local before=Json.encode(game:getState())
    local storage=assert(game.session.checkpointStore.storage)
    local files,writes=Json.encode(storage.files),storage.writeCount
    _G.M16_CAPTURE(name,view,state or game:getState(),scale or 1,storage)
    equal(Json.encode(game:getState()),before,"capture must not mutate game/RNG/durable projection")
    equal(Json.encode(storage.files),files,"capture must not change memory save bytes")
    equal(storage.writeCount,writes,"capture must not write memory saves")
end
local function m16Boundary(view,state,roles)
    m12DrawBoundary(view,state,roles)
end

test("M16 I01 actual Battle interval rejects late fifth and admits late unpatched or duplicate deployment",function()
    local Battle=require("src.battle")
    for _,case in ipairs({
        {{{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD"},{"P_OVERDRIVE"}},false},
        {{{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD","P_OVERDRIVE"},{}},true},
        {{{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD","P_OVERDRIVE"},{"P_DAMAGE"}},true},
        {{{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD","P_OVERDRIVE"},{"P_LONG_RANGE"}},true},
    }) do
        local game=newGame();m16Prepare(game,9,{},19,0,case[1],2);truthy(game:startWave())
        truthy(game:selectTower(3));truthy(game:placeSelected(5,0));game:update(Battle.FIXED_DT)
        equal(game:recallTower(1),false);equal(game:selectOffer("patch"),false)
        truthy(game:selectTower(1));equal(game:placeSelected(4,0),false)
        local events=assert(Battle.step(game.battle,Battle.FIXED_DT,{{type="recall_tower",instanceId=1},
            {type="purchase_patch",instanceId=1,patchId="P_DAMAGE"},{type="sell_module",moduleId="M16"}}))
        local rejected=0;for _,e in ipairs(events) do if e.type=="command_rejected" then rejected=rejected+1 end end;equal(rejected,3)
        m15FinishActual(game);equal(game:getState().moduleUnlockById.M16.permanentlyUnlocked,case[2])
    end
    local game,storage,checkpoint=newGame();m16Prepare(game,14,{},19,0);truthy(game:startWave());local writes=storage.writeCount
    local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("restore must not mint") end})
    equal(storage.writeCount,writes);restored:update(Battle.FIXED_DT);equal(restored.battle.tick,0)
    truthy(restored:resumeAll());m15FinishActual(restored);equal(restored:getState().moduleUnlockById.M16.permanentlyUnlocked,true)
end)

test("M16 I02 live Battle shared union changes launch damage and selected display in the same tick",function()
    local Battle=require("src.battle")
    local game=m16EarnedGame(nil,{m42Module("M16",16)})
    m42PrepareWave(game,9,{m42Module("M16",16)},19,0)
    m16Inventory(game,{{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD","P_OVERDRIVE"},{"P_LONG_RANGE"}},2,0)
    truthy(game:selectTower(1));truthy(game:startWave());local live=game.battle
    local snapshot=Json.encode(game.session:getState().runState.towerInstances)
    live.spawnSchedule,live.nextSpawnIndex={},1;local enemy=assert(live.enemies[1]);enemy.baseSpeed,enemy.hp,enemy.maxHp=0,100000,100000
    for _,tower in ipairs(live.towers) do tower.charge=0 end;live.towers[1].charge=1
    local before=assert(Rules.projectStats(game.defs,live.run,1));game:update(Battle.FIXED_DT)
    local projectile=assert(live.projectiles[1]);close(projectile.launchBaseDamage,before.damage)
    local initialHp=enemy.hp;for _=1,30 do game:update(Battle.FIXED_DT);if enemy.hp<initialHp then break end end
    close(initialHp-enemy.hp,before.damage)
    truthy(game:selectTower(3));truthy(game:placeSelected(5,0));truthy(game:selectTower(1));live.towers[1].charge=1
    game:update(Battle.FIXED_DT);local after=assert(Rules.projectStats(game.defs,live.run,1))
    close(after.factors.moduleDamage,before.factors.moduleDamage+0.03)
    local last=live.projectiles[#live.projectiles];close(last.launchBaseDamage,after.damage)
    local state=game:getState();equal(state.moduleStatusById.M16.distinctPatchCount,6);close(state.moduleStatusById.M16.selectedDamage,after.damage)
    equal(state.moduleUnlockById.M16.distinctPatchCount,6);equal(Json.encode(game.session:getState().runState.towerInstances),snapshot)
    local view=View.new(game.defs);view:draw(state);truthy(view:_moduleStatusLines(state,"M16"):find("6종",1,true))
    io.write("FIXTURE M16 I02 actual launch->normal hit shared5->6 sameTick=",live.tick," startSnapshotUnchanged=true\n")
end)

test("M16 I03 nominal eight and preserved nine rights commit once and enter only successful next run",function()
    for _,normal in ipairs({true,false}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local game,storage,checkpoint=newGame()
        local modules=normal and {m42Module("M03",12),m42Module("M08",12),m42Module("M01",8),m42Module("M07",8)}
            or {m42Module("M03",20),m42Module("M08",20)}
        m16Prepare(game,12,modules,20,20);truthy(game:startWave());local before,gen=game:getState(),generation(checkpoint)
        local expectedShop=Shop.createVisit(game.defs,{visitId="S04",frozenUnlockPool=before.runState.frozenUnlockPool,
            acquiredModuleIds=before.runState.acquiredModuleIds,rngState=before.runState.shopState.rngState})
        storage.writeMode=mode;m15FinishActual(game);equal(game:getState().phase,"SAVE_ERROR")
        equal(Json.encode(game:getState().metaState),Json.encode(before.metaState));equal(#game:getState().newModuleUnlocks,0)
        local bytes=game.session.pending.candidate.encodedEnvelope;equal(game:retrySave().status,"save_error");equal(game.session.pending.candidate.encodedEnvelope,bytes)
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied");local after=game:getState()
        equal(#after.newModuleUnlocks,normal and 8 or 9);equal(generation(checkpoint),gen+1)
        equal(after.moduleUnlockById.M16.permanentlyUnlocked,true);equal(after.moduleUnlockById.M16.inCurrentRunPool,false)
        equal(Json.encode(after.runState.frozenUnlockPool),Json.encode(before.runState.frozenUnlockPool));equal(Json.encode(after.runState.shopState),Json.encode(expectedShop))
        if not normal then m16Capture("earned-excluded-480",function()local v=View.new(game.defs);v:openTowerUnlocks(after);v:setUnlockLookupTab("shared");return v end,game) end
        if not normal then local v=View.new(game.defs);m16Boundary(v,after);m16Capture("saved-nine-480",v,game) end
        equal(game:retrySave().status,"rejected");equal(finishStartedWave(game,12),false)
        truthy(completeWave(game,13,"defeat","fixture_defeat"));local result=Json.encode(game:getState().runState)
        truthy(game:requestNewRun());truthy(game:cancelNewRun());equal(Json.encode(game:getState().runState),result)
        truthy(game:requestNewRun());storage.writeMode="fail_before";equal(game:confirmNewRun(),false);equal(Json.encode(game:getState().runState),result)
        local newBytes=game.session.pending.candidate.encodedEnvelope;storage.writeMode=nil;equal(game:retrySave().status,"applied")
        equal(storage.writeAttempts[#storage.writeAttempts].data,newBytes);local run=game:getState().runState
        equal(#run.frozenUnlockPool.moduleIds,normal and 32 or 33);equal(#run.modules,0);equal(run.acquiredModuleIds.M16,nil)
        io.write("FIXTURE M16 I03 ",normal and "nominal-eight" or "preserved-nine"," controlled actual Battle completion; full-wave/S00-path unobserved\n")
    end end
end)

test("M16 I04 twelve historical Game restores are read only and earn I16 only from new supported battles",function()
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1",
        "DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1","DR-MOD-I15-r1","DR-MOD-I14-r1","DR-MOD-I12-r1"}
    for index,version in ipairs(versions) do
        local game,storage,checkpoint=newGame();if index>1 then m42PrepareWave(game,9,{m42Module("M01",20)},19,0) end
        m16Inventory(game,M16_FLEET,3,0);local payload=checkpoint:loadCheckpoint().payload;local run=payload.runState
        run.contentVersion=version;run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"}
        run.modules={m42Module("M01",20)};run.acquiredModuleIds={M01=true};run.shopState.offers.module="M02";run.shopState.soldOut.module=false
        payload.metaState.unlockedModuleIds={};if index<4 then payload.metaState.unlockedTowerIds={"T01","T02","T03","T04"} end
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        if index>=3 then run.modules[2]=m42Module("M33",9,6);run.acquiredModuleIds.M33=true;run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]="M33" end
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"},{10,"M15"},{11,"M14"},{12,"M12"}}) do if index>=entry[1] then
            payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2]
        end end
        assert(Save.createRun002Migrations(game.defs)[version].validatePayload(payload));storage.files={};writeShaEnvelope(storage,"save-b.json",34,version,payload)
        local writes=storage.writeCount;local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("legacy cannot mint") end})
        local state=restored:getState();equal(storage.writeCount,writes);equal(state.moduleUnlockById.M16.permanentlyUnlocked,false);equal(#state.newModuleUnlocks,0)
        for _,key in ipairs({"modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(state.runState[key]),Json.encode(run[key]),version..key) end
        truthy(restored:startWave());m15FinishActual(restored);equal(restored:getState().moduleUnlockById.M16.permanentlyUnlocked,index>1)
        equal(restored:getState().moduleUnlockById.M16.inCurrentRunPool,false)
    end
end)

test("M16 I05 ten lookup tabs and shared management preserve readable geometry and input ownership",function()
    local game,storage=newGame();local view,input,_,click=assembledUi(game);local writes=storage.writeCount
    local nine={{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD","P_OVERDRIVE","P_LONG_RANGE"},{"P_FOCUSED_BARRAGE","P_CONTINUOUS_AIM","P_HEAVY_AIM"},{}}
    m16Inventory(game,nine,3,100);writes=storage.writeCount
    truthy(view:openTowerUnlocks(game:getState()));truthy(view:setUnlockLookupTab("shared"))
    local roles={};for _,suffix in ipairs({"permanent","condition","effect","attempt","pool","offer","next_run"}) do roles[#roles+1]="module_unlock_M16_"..suffix end
    m16Boundary(view,game:getState(),roles);m16Capture("lookup-480",view,game);m16Capture("lookup-960",view,game,2)
    truthy(view:findTextRole(roles[2]).value:find("전투내내",1,true))
    local count=0;for _,button in ipairs(view.buttons) do if button.action.type=="unlock_lookup_tab" then
        count=count+1;equal(button.textSize,9);equal(button.w,button.action.tab=="deposit" and 32 or 22)
    end end;equal(count,11)
    for _,tab in ipairs({"tower","deposit","spare","emergency","midlink","assetlink","mixed","maintenance","balanced","shared","reserve"}) do
        view:draw(game:getState());truthy(click("unlock_lookup_tab",function(a)return a.tab==tab end));equal(view.unlockLookupTab,tab)
    end
    equal(input:mousepressed(-2,-2,1),false);equal(input:mousepressed(2,2,1),true);truthy(input:keypressed("escape",false));equal(storage.writeCount,writes)
    game=m16EarnedGame(nil,{m42Module("M16",16)});m16Inventory(game,nine,3,100)
    truthy(game:selectTower(4));local state=game:getState();equal(state.moduleStatusById.M16.aggregateBonusPercentPoints,27);equal(state.moduleStatusById.M16.bonusPercentPoints,0)
    local managed=View.new(game.defs);truthy(managed:openInventoryManagement("module"));truthy(managed:selectManagedModule("M16"));m16Boundary(managed,state)
    local detail=assert(managed:findTextRole("m16_management_detail"));truthy(detail.value:find("중량 조준",1,true))
    equal(assert(managed:findTextRole("m16_management_history")).size,8)
    truthy(managed:textBlockBounds(detail,1).bottom<=assert(managed:findTextRole("m16_management_paid")).y,"M16 longest IDs precede actual receipt")
    m16Capture("reserve-management-480",managed,game);truthy(game:cancelSelection());equal(game:getState().moduleStatusById.M16.aggregateBonusPercentPoints,27)
end)

test("M16 I06 shared buy sale and patch previews show actual aggregate selected and linked effects",function()
    local game,storage=m16EarnedGame("M16",{m42Module("M41",16),m42Module("M42",16),m42Module("M43",12)})
    m16Inventory(game,{{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD","P_OVERDRIVE"}},2,100);truthy(game:selectTower(1))
    local before,writes=Json.encode(game:getState().runState),storage.writeCount;truthy(game:selectOffer("module"));local draft=game:getState().purchaseDraft
    equal(draft.cost,16);equal(draft.sharedTrade.afterSharedAggregate.aggregateBonusPercentPoints,15);equal(draft.sharedTrade.afterSharedStatus.bonusPercentPoints,15)
    equal(draft.midLinkAfter.bonusPercentPoints,draft.midLinkBefore.bonusPercentPoints);equal(draft.assetLinkAfter.otherModulePaidGold,44)
    local view=View.new(game.defs);m16Boundary(view,game:getState(),{"m16_draft_title","m16_draft_effect","m16_draft_links","m16_draft_selected","m16_draft_detail"})
    m16Capture("module-buy-480",view,game);truthy(game:cancelSelection());equal(game:getState().purchaseDraft.sharedTrade.error,"tower_not_selected")
    equal(game:getState().purchaseDraft.sharedTrade.afterSharedAggregate.aggregateBonusPercentPoints,15);truthy(game:cancelPurchase())
    equal(Json.encode(game:getState().runState),before);equal(storage.writeCount,writes)
    truthy(game:selectTower(1));truthy(game:selectOffer("module"));truthy(game:confirmPurchase());local run=game:getState().runState
    findModuleEntry(run,"M16").paidGold=9;truthy(game:_applyDurableRun(run,"transaction"));truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M16"}))
    equal(game:getState().transactionDraft.refundGold,4);m16Boundary(view,game:getState());truthy(game:confirmInventoryTransaction())
    equal(game:getState().moduleUnlockById.M16.permanentlyUnlocked,true);equal(game:getState().runState.acquiredModuleIds.M16,true)
    local patched=m16EarnedGame(nil,{m42Module("M16",16),m42Module("M29",12),m42Module("M34",12,6)})
    m16Inventory(patched,{{"P_DAMAGE","P_RATE"},{"P_RANGE","P_OVERLOAD"},{}},2,100);truthy(patched:selectTower(1));m12Offer(patched,"patch","P_OVERDRIVE")
    truthy(patched:selectOffer("patch"));local p=patched:getState().purchaseDraft.sharedTrade
    equal(p.beforeSharedAggregate.distinctPatchCount,4);equal(p.afterSharedAggregate.distinctPatchCount,5)
    local actual=assert(Rules.tryPurchasePatch(patched.defs,patched:getState().runState,1,"P_OVERDRIVE"));close(p.after.damage,Rules.projectStats(patched.defs,actual,1).damage)
    m16Boundary(view,patched:getState());m16Capture("patch-buy-480",view,patched);truthy(patched:cancelPurchase())
    truthy(patched:selectTower(3));truthy(patched:selectOffer("patch"));equal(patched:getState().purchaseDraft.sharedTrade.afterSharedAggregate.distinctPatchCount,4);truthy(patched:cancelPurchase())
    local single=newGame();m16Prepare(single,9,{},19,0,{{"P_DAMAGE","P_RATE"},{"P_RANGE","P_OVERLOAD"},{"P_OVERDRIVE"}},3)
    truthy(single:startWave());m15FinishActual(single);equal(#single:getState().newModuleUnlocks,1);equal(single:getState().newModuleUnlocks[1].moduleId,"M16")
    local alert=View.new(single.defs);m16Boundary(alert,single:getState());m16Capture("single-alert-480",alert,single)
    local stress=game:getState();stress.newTowerUnlocks={{type="tower_unlocked",towerId="T05"}};stress.newModuleUnlocks={}
    for _,id in ipairs(M16_RIGHTS) do stress.newModuleUnlocks[#stress.newModuleUnlocks+1]={type="module_unlocked",moduleId=id,waveId="W12"} end
    m16Boundary(View.new(game.defs),stress);io.write("FIXTURE M16 synthetic-ten View-only checkpointReachability=false\n")
end)

test("M16 I07 exact recalls tower sales cancel stale and save retry preserve shared identities and checkpoint bytes",function()
    for _,sale in ipairs({true,false}) do for _,mode in ipairs({"fail_before","fail_readback"}) do
        local modules={m42Module("M16",16),m42Module("M14",12),m42Module("M15",12)};if sale then modules[4]=m42Module("M05",16) end
        local game,storage=m16EarnedGame(sale and nil or "M06",modules);local count=sale and 8 or 6;local sets={}
        for id=1,count do sets[id]=id==1 and {"P_RATE","P_RANGE","P_OVERLOAD"} or id==2 and {"P_OVERDRIVE"} or {"P_DAMAGE"} end
        m16Inventory(game,sets,count,100);truthy(game:selectTower(1));local before,writes=Json.encode(game:getState().runState),storage.writeCount
        local function begin()if sale then truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M05"})) else truthy(game:selectOffer("module")) end end
        local function draft()local state=game:getState();return sale and state.transactionDraft or state.purchaseDraft end
        local function choose(id)if sale then return game:setInventoryRecallSelection(id,true) else return game:setPurchaseRecallSelection(id,true) end end
        begin();equal(draft().requiredRecallCount,2);equal(draft().sharedTrade.afterSharedAggregate,nil)
        local view=View.new(game.defs);m16Boundary(view,game:getState());if sale and mode=="fail_before" then m16Capture("recall-insufficient-480",view,game) end
        if sale then truthy(game:cancelInventoryTransaction()) else truthy(game:cancelPurchase()) end;equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
        begin();equal(choose(99),false);truthy(choose(1));equal(draft().sharedTrade.after,nil);truthy(choose(2));equal(choose(3),false)
        equal(draft().sharedTrade.afterSharedAggregate.distinctPatchCount,1);equal(draft().sharedTrade.afterSharedStatus.bonusPercentPoints,0)
        m16Boundary(view,game:getState());if sale and mode=="fail_before" then m16Capture("recall-exact-480",view,game) end
        if sale then equal(Rules.tryInventoryTransaction(game.defs,game:getState().runState,{phase="SHOP",kind="sell_module",moduleId="M05",recallTowerIds={1,1}}),nil)
        else equal(Rules.tryPurchaseModule(game.defs,game:getState().runState,"M06",{1,1}),nil) end
        storage.writeMode=mode;if sale then equal(game:confirmInventoryTransaction(),false) else equal(game:confirmPurchase(),false) end
        equal(Json.encode(game:getState().runState),before);local bytes=game.session.pending.candidate.encodedEnvelope
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
        local after=game:getState().runState;equal(#after.towerInstances,count);equal(after.towerInstances[1].placement,nil);equal(#after.towerInstances[1].patchIds,3)
        equal(after.acquiredModuleIds.M16,true);equal(game:getState().moduleUnlockById.M16.permanentlyUnlocked,true)
    end end
    local game,_,checkpoint=m16EarnedGame(nil,{m42Module("M16",16)})
    m16Inventory(game,{{"P_DAMAGE","P_RATE","P_RANGE"},{"P_OVERLOAD","P_OVERDRIVE"},{"P_DAMAGE"}},3,100)
    truthy(game:selectTower(1));truthy(game:beginInventoryTransaction({kind="sell_tower",instanceId=1}));equal(game:getState().transactionDraft.sharedTrade.afterSharedAggregate.distinctPatchCount,3)
    local concurrent=game:getState().runState;concurrent.gold=101;truthy(game:_applyDurableRun(concurrent,"transaction"));local gen=generation(checkpoint)
    local ok,reason=game:confirmInventoryTransaction();equal(ok,false);equal(reason,"stale_transaction_revision");equal(generation(checkpoint),gen)
    truthy(game:cancelInventoryTransaction());truthy(game:beginInventoryTransaction({kind="sell_tower",instanceId=1}));truthy(game:confirmInventoryTransaction())
    equal(game:getState().selectedTowerId,nil);equal(game:getState().moduleStatusById.M16.distinctPatchCount,3)
end)

local M31_RIGHTS={"M12","M14","M15","M16","M28","M31","M41","M42","M43","M46"}
local function m31Prepare(game,index,modules,hp,gold)
    m16Prepare(game,index,modules,hp,gold)
    local run=game:getState().runState;run.gold=1000
    for _,id in ipairs({"T01","T04"}) do run=assert(Rules.tryPurchaseTower(game.defs,run,id)) end
    run.gold=gold or 0;truthy(game:_applyDurableRun(run,"transaction"));return game:getState().runState
end
local function m31Capture(name,view,game,scale)
    if not _G.M31_CAPTURE then return end
    local state=game:getState();local storage=game.session.checkpointStore.storage
    local bytes,files,writes=Json.encode(state),Json.encode(storage.files),storage.writeCount
    _G.M31_CAPTURE(name,view,state,scale or 1,storage)
    equal(Json.encode(game:getState()),bytes);equal(Json.encode(storage.files),files);equal(storage.writeCount,writes)
end
local function m31EarnedGame(offer,modules)
    local game,storage,checkpoint=newGame();m31Prepare(game,9,{m42Module("M03",20),m42Module("M08",20)},20,20)
    truthy(game:startWave());m15FinishActual(game);equal(#game:getState().newModuleUnlocks,10)
    truthy(completeWave(game,10,"defeat","fixture_defeat"));truthy(game:requestNewRun());truthy(game:confirmNewRun())
    local run=game:getState().runState;run.hp,run.gold=20,100;m42SetModules(run,modules or {});truthy(game:_applyDurableRun(run,"transaction"))
    if offer then m12Offer(game,"module",offer) end
    return game,storage,checkpoint
end

test("M31 I01 actual Battle placement reduces reserve income and invalidates lost last kind",function()
    local Battle=require("src.battle")
    for _,lost in ipairs({false,true}) do
        local game=newGame();m31Prepare(game,9,{},19,0)
        if not lost then local run=game:getState().runState;run.gold=100;run=assert(Rules.tryPurchaseTower(game.defs,run,"T04"));run.gold=0;truthy(game:_applyDurableRun(run,"transaction")) end
        truthy(game:startWave());local before=Json.encode(game.session:getState().runState.towerInstances)
        truthy(game:selectTower(5));truthy(game:placeSelected(7,0));game:update(Battle.FIXED_DT)
        equal(game:getState().moduleUnlockById.M31.reserveTypeCount,lost and 1 or 2)
        equal(Json.encode(game.session:getState().runState.towerInstances),before)
        equal(game:recallTower(5),false);equal(game:selectOffer("tower"),false)
        local events=assert(Battle.step(game.battle,Battle.FIXED_DT,{{type="recall_tower",instanceId=5},{type="sell_tower",instanceId=4},{type="purchase_tower",towerId="T02"}}))
        local rejected=0;for _,e in ipairs(events) do if e.type=="command_rejected" then rejected=rejected+1 end end;equal(rejected,3)
        m15FinishActual(game);equal(game:getState().moduleUnlockById.M31.permanentlyUnlocked,not lost)
    end
    local game,storage,checkpoint=m31EarnedGame(nil,{m42Module("M31",12)})
    m31Prepare(game,14,{m42Module("M31",12)},19,0);truthy(game:startWave());local writes=storage.writeCount
    local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("restore must not mint") end})
    equal(storage.writeCount,writes);truthy(restored:resumeAll());truthy(restored:selectTower(5));truthy(restored:placeSelected(7,0));restored:update(Battle.FIXED_DT)
    equal(restored:getState().moduleStatusById.M31.estimatedGold,1);m15FinishActual(restored)
    equal(restored:getState().lastReceipt.reward.moduleById.M31,1)
end)

test("M31 I02 ten preserved rights become visible only after identical checkpoint retry and next successful run",function()
    for _,mode in ipairs({"fail_before","fail_readback"}) do
        local game,storage,checkpoint=newGame();m31Prepare(game,9,{m42Module("M03",20),m42Module("M08",20)},20,20)
        truthy(game:startWave());local before=game:getState();local gen=generation(checkpoint)
        storage.writeMode=mode;m15FinishActual(game);equal(game:getState().phase,"SAVE_ERROR");equal(#game:getState().newModuleUnlocks,0)
        equal(Json.encode(game:getState().metaState),Json.encode(before.metaState));local bytes=game.session.pending.candidate.encodedEnvelope
        equal(game:retrySave().status,"save_error");equal(game.session.pending.candidate.encodedEnvelope,bytes)
        storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
        local after=game:getState();equal(generation(checkpoint),gen+1);equal(#after.newModuleUnlocks,10)
        equal(after.moduleUnlockById.M31.permanentlyUnlocked,true);equal(after.moduleUnlockById.M31.inCurrentRunPool,false)
        equal(Json.encode(after.runState.frozenUnlockPool),Json.encode(before.runState.frozenUnlockPool))
        local expectedShop=Shop.createVisit(game.defs,{visitId="S03",frozenUnlockPool=before.runState.frozenUnlockPool,
            acquiredModuleIds=before.runState.acquiredModuleIds,rngState=before.runState.shopState.rngState})
        equal(Json.encode(after.runState.shopState),Json.encode(expectedShop))
        if mode=="fail_before" then local v=View.new(game.defs);m16Boundary(v,after);m31Capture("saved-ten-480",v,game) end
        equal(game:retrySave().status,"rejected");equal(finishStartedWave(game,9),false)
        truthy(completeWave(game,10,"defeat","fixture_defeat"));local result=Json.encode(game:getState().runState)
        truthy(game:requestNewRun());truthy(game:cancelNewRun());equal(Json.encode(game:getState().runState),result)
        truthy(game:requestNewRun());storage.writeMode="fail_before";equal(game:confirmNewRun(),false);equal(Json.encode(game:getState().runState),result)
        local newBytes=game.session.pending.candidate.encodedEnvelope;storage.writeMode=nil;equal(game:retrySave().status,"applied")
        equal(storage.writeAttempts[#storage.writeAttempts].data,newBytes);local run=game:getState().runState
        equal(#run.frozenUnlockPool.moduleIds,34);equal(#run.modules,0);equal(run.acquiredModuleIds.M31,nil)
        io.write("FIXTURE M31 preserved-paid20+20 new W09 actual Battle completion readback ten rights; full-wave and S00-path unobserved\n")
    end
end)

test("M31 I03 current buy sale receipt lookup and single alert preserve minimum geometry and cancel save retry",function()
    local game,storage=m31EarnedGame("M31",{});local run=game:getState().runState;run.gold=100
    run=assert(Rules.tryPurchaseTower(game.defs,run,"T04"));truthy(game:_applyDurableRun(run,"transaction"))
    local view=View.new(game.defs);truthy(view:openTowerUnlocks(game:getState()));truthy(view:setUnlockLookupTab("reserve"))
    m16Boundary(view,game:getState());m31Capture("lookup-480",view,game);m31Capture("lookup-960",view,game,2)
    local count=0;for _,b in ipairs(view.buttons) do if b.action.type=="unlock_lookup_tab" then count=count+1;truthy(b.x+b.w<=480);truthy(view:_font(b.textSize):getWidth(b.label or b.text or "")<=b.w-4) end end;equal(count,11)
    truthy(view:closeTowerUnlocks());local before,writes=Json.encode(game:getState().runState),storage.writeCount
    truthy(game:selectOffer("module"));equal(game:getState().purchaseDraft.reserveBefore.estimatedGold,0);equal(game:getState().purchaseDraft.reserveAfter.estimatedGold,2)
    m16Boundary(view,game:getState());m31Capture("buy-480",view,game);truthy(game:cancelPurchase());equal(storage.writeCount,writes);equal(Json.encode(game:getState().runState),before)
    truthy(game:selectOffer("module"));storage.writeMode="fail_readback";equal(game:confirmPurchase(),false);equal(Json.encode(game:getState().runState),before)
    local bytes=game.session.pending.candidate.encodedEnvelope;storage.writeMode,storage.failReadPath=nil,nil;equal(game:retrySave().status,"applied");equal(storage.writeAttempts[#storage.writeAttempts].data,bytes)
    truthy(view:openInventoryManagement("module"));truthy(view:selectManagedModule("M31"));m16Boundary(view,game:getState());m31Capture("current-480",view,game)
    truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M31"}));equal(game:getState().transactionDraft.reserveBefore.estimatedGold,2);equal(game:getState().transactionDraft.reserveAfter.estimatedGold,0)
    view:closeInventoryManagement();m16Boundary(view,game:getState());m31Capture("sale-480",view,game);truthy(game:cancelInventoryTransaction())
    truthy(game:beginInventoryTransaction({kind="sell_module",moduleId="M31"}));storage.writeMode="fail_before";equal(game:confirmInventoryTransaction(),false)
    storage.writeMode=nil;equal(game:retrySave().status,"applied");equal(game:getState().moduleStatusById.M31.estimatedGold,0);equal(game:getState().runState.acquiredModuleIds.M31,true)
    equal(game:getState().moduleUnlockById.M31.permanentlyUnlocked,true)
    local single=newGame();m31Prepare(single,9,{},19,0,{});local candidate=single:getState().runState
    for _,t in ipairs(candidate.towerInstances) do t.patchIds={} end;truthy(single:_applyDurableRun(candidate,"transaction"));truthy(single:startWave());m15FinishActual(single)
    equal(#single:getState().newModuleUnlocks,1);equal(single:getState().newModuleUnlocks[1].moduleId,"M31")
    local v=View.new(single.defs);m16Boundary(v,single:getState());m31Capture("single-alert-480",v,single)
    local receipt=m31EarnedGame(nil,{m42Module("M31",12)});m31Prepare(receipt,11,{m42Module("M31",12)},19,0)
    truthy(receipt:startWave());m15FinishActual(receipt);equal(receipt:getState().lastReceipt.reward.moduleById.M31,2)
    v=View.new(receipt.defs);m16Boundary(v,receipt:getState());m31Capture("receipt-480",v,receipt)
end)

test("M31 I04 thirteen historical Game loads preserve bytes rights frozen pool and earn only new reserve battles",function()
    local versions={"DR-SLICE-001-r2","DR-RUN-002-r1","DR-MOD-S24-r1","DR-TOWER-U2-r1","DR-MOD-I28-r1","DR-MOD-I43-r1",
        "DR-MOD-I46-r1","DR-MOD-I41-r1","DR-MOD-I42-r1","DR-MOD-I15-r1","DR-MOD-I14-r1","DR-MOD-I12-r1","DR-MOD-I16-r1"}
    for index,version in ipairs(versions) do
        local game,storage,checkpoint=newGame()
        m31Prepare(game,index==1 and 1 or 9,{m42Module("M01",20)},19,0)
        local payload=checkpoint:loadCheckpoint().payload;local run=payload.runState;run.contentVersion=version
        run.frozenUnlockPool.moduleIds={"M01","M02","M05","M17","M25","M26"};run.shopState.offers.module="M02";run.shopState.soldOut.module=false
        payload.metaState.unlockedModuleIds={};if index<4 then payload.metaState.unlockedTowerIds={"T01","T02","T03","T04"} end
        if index==1 then run.developmentComplete=false;run.shopState.fixtureIndex=1 end
        for _,entry in ipairs({{5,"M28"},{6,"M43"},{7,"M46"},{8,"M41"},{9,"M42"},{10,"M15"},{11,"M14"},{12,"M12"},{13,"M16"}}) do if index>=entry[1] then
            payload.metaState.unlockedModuleIds[#payload.metaState.unlockedModuleIds+1]=entry[2];run.frozenUnlockPool.moduleIds[#run.frozenUnlockPool.moduleIds+1]=entry[2]
        end end
        assert(Save.createRun002Migrations(game.defs)[version].validatePayload(payload));storage.files={};writeShaEnvelope(storage,"save-b.json",34,version,payload)
        local writes,files=storage.writeCount,Json.encode(storage.files)
        local restored=Game.new({defs=game.defs,checkpointStore=checkpoint,identityProvider=function()error("legacy cannot mint") end})
        local state=restored:getState();equal(storage.writeCount,writes);equal(Json.encode(storage.files),files)
        equal(state.moduleUnlockById.M31.permanentlyUnlocked,false);equal(#state.newModuleUnlocks,0)
        equal(Json.encode(state.metaState.unlockedModuleIds),Json.encode(payload.metaState.unlockedModuleIds))
        for _,key in ipairs({"towerInstances","modules","frozenUnlockPool","shopState","acquiredModuleIds","completedWaveIds"}) do equal(Json.encode(state.runState[key]),Json.encode(run[key]),version..key) end
        truthy(restored:startWave());m15FinishActual(restored);equal(restored:getState().moduleUnlockById.M31.permanentlyUnlocked,index>1)
        equal(restored:getState().moduleUnlockById.M31.inCurrentRunPool,false)
    end
end)

test("M31 I05 reserve tower sales free recalls and exact capacity recalls project real income and reject stale trades",function()
    local game,storage,checkpoint=m31EarnedGame(nil,{m42Module("M31",12)})
    local run=game:getState().runState;run.gold=100;run=assert(Rules.tryPurchaseTower(game.defs,run,"T04"));truthy(game:_applyDurableRun(run,"transaction"))
    truthy(game:beginInventoryTransaction({kind="sell_tower",instanceId=3}));local draft=game:getState().transactionDraft
    equal(draft.reserveBefore.estimatedGold,2);equal(draft.reserveAfter.estimatedGold,1)
    local view=View.new(game.defs);m16Boundary(view,game:getState());truthy(view:findTextRole("m31_trade_income").value:find("2→1",1,true))
    local writes=storage.writeCount;truthy(game:cancelInventoryTransaction());equal(storage.writeCount,writes)
    run=game:getState().runState;run=assert(Rules.tryPlaceTower(game.defs,run,run.mapId,3,5,0,"prepare"));truthy(game:_applyDurableRun(run,"transaction"))
    equal(game:getState().moduleStatusById.M31.estimatedGold,1);truthy(game:recallTower(3));equal(game:getState().moduleStatusById.M31.estimatedGold,2)
    truthy(game:beginInventoryTransaction({kind="sell_tower",instanceId=3}));run=game:getState().runState;run.gold=101;truthy(game:_applyDurableRun(run,"transaction"))
    local gen=generation(checkpoint);local ok,reason=game:confirmInventoryTransaction();equal(ok,false);equal(reason,"stale_transaction_revision");equal(generation(checkpoint),gen)
    truthy(game:cancelInventoryTransaction())
    local exact=m31EarnedGame("M06",{m42Module("M31",12)})
    m16Inventory(exact,{{},{},{},{},{},{}},6,100)
    truthy(exact:selectOffer("module"));equal(exact:getState().purchaseDraft.requiredRecallCount,2);equal(exact:getState().purchaseDraft.reserveAfter,nil)
    truthy(exact:setPurchaseRecallSelection(1,true));equal(exact:getState().purchaseDraft.reserveAfter,nil)
    truthy(exact:setPurchaseRecallSelection(2,true));equal(exact:getState().purchaseDraft.reserveAfter.estimatedGold,1)
    truthy(exact:cancelPurchase());equal(exact:getState().moduleStatusById.M31.estimatedGold,0)
    local run=exact:getState().runState;run.nextWaveIndex=15;run.phase="PREPARE";truthy(exact:_applyDurableRun(run,"transaction"))
    truthy(exact:startWave());truthy(finishStartedWave(exact,15,"victory","boss_killed"));equal(exact:getState().lastReceipt,nil)
    equal(exact:getState().moduleStatusById.M31.estimatedGold,0)
end)

local failures = 0
for _, item in ipairs(tests) do
    local ok, message = pcall(item.body)
    if ok then io.write("PASS ", item.name, "\n") else failures = failures + 1; io.stderr:write("FAIL ", item.name, ": ", tostring(message), "\n") end
end
io.write(string.format('WORKFLOW SUITE {"schemaVersion":1,"suite":"integration","count":%d,"failures":%d}\n', #tests, failures))
if failures > 0 then error(tostring(failures) .. " integration tests failed") end
