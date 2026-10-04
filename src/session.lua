local Session = {}
Session.__index = Session

Session.PHASE = {
    TITLE = "TITLE",
    SHOP = "SHOP",
    PREPARE = "PREPARE",
    COMBAT = "COMBAT",
    RESULT = "RESULT",
    SAVE_ERROR = "SAVE_ERROR",
}

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

local function pauseList(reasons)
    local result = {}
    for reason, active in pairs(reasons) do
        if active then result[#result + 1] = reason end
    end
    table.sort(result)
    return result
end

local function result(status, fields)
    local value = fields or {}
    value.status = status
    return value
end

function Session.new(options)
    options = options or {}
    assert(type(options.checkpointStore) == "table", "checkpointStore required")
    assert(type(options.checkpointStore.loadCheckpoint) == "function"
        and type(options.checkpointStore.prepareCheckpoint) == "function"
        and type(options.checkpointStore.commitCandidate) == "function",
        "checkpointStore must provide loadCheckpoint, prepareCheckpoint and commitCandidate")

    return setmetatable({
        checkpointStore = options.checkpointStore,
        phase = Session.PHASE.TITLE,
        revision = 0,
        focused = true,
        pauseReasons = {},
        runState = nil,
        metaState = copy(options.metaState or {}),
        committedState = nil,
        saveError = nil,
        pending = nil,
        commandResults = {},
    }, Session)
end

function Session:getRevision()
    return self.revision
end

function Session:getState()
    return {
        phase = self.phase,
        stateRevision = self.revision,
        focused = self.focused,
        pauseReasons = pauseList(self.pauseReasons),
        paused = next(self.pauseReasons) ~= nil,
        runState = copy(self.runState),
        metaState = copy(self.metaState),
        saveError = copy(self.saveError),
    }
end

function Session:isPaused()
    return next(self.pauseReasons) ~= nil
end

function Session:canAdvanceTime()
    return self.phase == Session.PHASE.COMBAT and not self:isPaused()
end

function Session:_advanceRevision()
    self.revision = self.revision + 1
end

function Session:_remember(commandId, commandResult)
    self.commandResults[commandId] = copy(commandResult)
    return copy(commandResult)
end

function Session:_applyCheckpointPayload(payload, targetPhase)
    self.phase = targetPhase
    self.metaState = copy(payload.metaState)
    self.runState = copy(payload.runState)
    self.runState.phase = targetPhase
    self.saveError = nil
    self.pending = nil
    self.committedState = {
        phase = self.phase,
        metaState = copy(self.metaState),
        runState = copy(self.runState),
    }
    if targetPhase ~= Session.PHASE.COMBAT then
        self.pauseReasons = {}
    end
end

function Session:_durableTransition(command, targetPhase, allowedPhases)
    if not allowedPhases[self.phase] then
        return result("rejected", { error = "command not allowed in phase " .. self.phase })
    end
    if type(command.checkpoint) ~= "table" then
        return result("rejected", { error = "durable command requires checkpoint" })
    end

    local payload = copy(command.checkpoint)
    payload.runState = copy(payload.runState or {})
    payload.runState.phase = targetPhase
    local candidate, prepareResult = self.checkpointStore:prepareCheckpoint(payload)
    if not candidate then
        self.pending = { payload = payload, targetPhase = targetPhase, candidate = nil }
        self.saveError = copy(prepareResult)
        self.phase = Session.PHASE.SAVE_ERROR
        self.pauseReasons.saveError = true
        self:_advanceRevision()
        return result("save_error", { error = prepareResult.error, saveStatus = prepareResult.status,
            stateRevision = self.revision })
    end

    local commitResult = self.checkpointStore:commitCandidate(candidate)
    if commitResult.status ~= "committed" then
        self.pending = { payload = payload, targetPhase = targetPhase, candidate = candidate }
        self.saveError = copy(commitResult)
        self.phase = Session.PHASE.SAVE_ERROR
        self.pauseReasons.saveError = true
        self:_advanceRevision()
        return result("save_error", { error = commitResult.error, saveStatus = commitResult.status,
            generation = candidate.generation, stateRevision = self.revision })
    end

    self:_applyCheckpointPayload(payload, targetPhase)
    self:_advanceRevision()
    return result("applied", { phase = self.phase, generation = commitResult.generation,
        stateRevision = self.revision })
end

function Session:_retrySave()
    if self.phase ~= Session.PHASE.SAVE_ERROR or not self.pending then
        return result("rejected", { error = "no pending save" })
    end

    local candidate = self.pending.candidate
    if not candidate then
        local prepareResult
        candidate, prepareResult = self.checkpointStore:prepareCheckpoint(self.pending.payload)
        if not candidate then
            self.saveError = copy(prepareResult)
            return result("save_error", { error = prepareResult.error, saveStatus = prepareResult.status,
                stateRevision = self.revision })
        end
        self.pending.candidate = candidate
    end

    local commitResult = self.checkpointStore:commitCandidate(candidate)
    if commitResult.status ~= "committed" then
        self.saveError = copy(commitResult)
        return result("save_error", { error = commitResult.error, saveStatus = commitResult.status,
            generation = candidate.generation, stateRevision = self.revision })
    end

    local payload = self.pending.payload
    local targetPhase = self.pending.targetPhase
    self.pauseReasons.saveError = nil
    self:_applyCheckpointPayload(payload, targetPhase)
    self:_advanceRevision()
    return result("applied", { phase = self.phase, generation = commitResult.generation,
        stateRevision = self.revision, retried = true })
end

function Session:_restore()
    if self.phase ~= Session.PHASE.TITLE then
        return result("rejected", { error = "restore only allowed from TITLE" })
    end

    local loaded = self.checkpointStore:loadCheckpoint()
    if loaded.status == "missing" then
        return result("missing", { stateRevision = self.revision })
    end
    if loaded.status ~= "valid" and loaded.status ~= "recovered" and loaded.status ~= "migrated" then
        self.phase = Session.PHASE.SAVE_ERROR
        self.pauseReasons.saveError = true
        self.saveError = copy(loaded)
        self.pending = nil
        self:_advanceRevision()
        return result("save_error", { saveStatus = loaded.status, error = loaded.error,
            stateRevision = self.revision })
    end

    local payload = loaded.payload
    local targetPhase = payload.runState.phase
    if payload.checkpointKind == "combatStart" then
        targetPhase = Session.PHASE.COMBAT
    end
    if not Session.PHASE[targetPhase] or targetPhase == Session.PHASE.SAVE_ERROR then
        self.phase = Session.PHASE.SAVE_ERROR
        self.pauseReasons.saveError = true
        self.saveError = { status = "corrupt", error = "checkpoint contains invalid phase" }
        self:_advanceRevision()
        return result("save_error", { saveStatus = "corrupt", error = self.saveError.error,
            stateRevision = self.revision })
    end

    self.pauseReasons = {}
    self:_applyCheckpointPayload(payload, targetPhase)
    if payload.checkpointKind == "combatStart" then
        self.pauseReasons.restore = true
    end
    self:_advanceRevision()
    return result("restored", { phase = self.phase, loadStatus = loaded.status,
        generation = loaded.generation, paused = self:isPaused(), stateRevision = self.revision })
end

function Session:_handle(command)
    local commandType = command.type
    if commandType == "RESTORE" then return self:_restore() end
    if commandType == "NEW_RUN" then
        return self:_durableTransition(command, Session.PHASE.SHOP, { TITLE = true, RESULT = true })
    end
    if commandType == "APPLY_DURABLE" then
        return self:_durableTransition(command, self.phase, { SHOP = true, PREPARE = true })
    end
    if commandType == "CLOSE_SHOP" then
        if self.phase ~= Session.PHASE.SHOP then
            return result("rejected", { error = "CLOSE_SHOP requires SHOP" })
        end
        self.phase = Session.PHASE.PREPARE
        if self.runState then self.runState.phase = self.phase end
        self:_advanceRevision()
        return result("applied", { phase = self.phase, stateRevision = self.revision })
    end
    if commandType == "REOPEN_SHOP" then
        if self.phase ~= Session.PHASE.PREPARE then
            return result("rejected", { error = "REOPEN_SHOP requires PREPARE" })
        end
        if not self.runState or type(self.runState.shopState) ~= "table"
            or self.runState.shopState.accessOpen ~= true then
            return result("rejected", { error = "REOPEN_SHOP requires an open shop visit" })
        end
        self.phase = Session.PHASE.SHOP
        if self.runState then self.runState.phase = self.phase end
        self:_advanceRevision()
        return result("applied", { phase = self.phase, stateRevision = self.revision })
    end
    if commandType == "START_COMBAT" then
        return self:_durableTransition(command, Session.PHASE.COMBAT, { SHOP = true, PREPARE = true })
    end
    if commandType == "COMPLETE_WAVE" then
        local nextPhase = command.nextPhase
        if nextPhase ~= Session.PHASE.PREPARE and nextPhase ~= Session.PHASE.SHOP then
            return result("rejected", { error = "COMPLETE_WAVE nextPhase must be PREPARE or SHOP" })
        end
        return self:_durableTransition(command, nextPhase, { COMBAT = true })
    end
    if commandType == "FINISH_RUN" then
        return self:_durableTransition(command, Session.PHASE.RESULT, { COMBAT = true })
    end
    if commandType == "PAUSE" then
        if self.phase ~= Session.PHASE.COMBAT then return result("rejected", { error = "PAUSE requires COMBAT" }) end
        local reason = command.reason or "user"
        if type(reason) ~= "string" or reason == "" then return result("rejected", { error = "invalid pause reason" }) end
        if self.pauseReasons[reason] then return result("no_op", { stateRevision = self.revision }) end
        self.pauseReasons[reason] = true
        self:_advanceRevision()
        return result("applied", { paused = true, pauseReasons = pauseList(self.pauseReasons),
            stateRevision = self.revision })
    end
    if commandType == "FOCUS_LOST" then
        if self.phase ~= Session.PHASE.COMBAT then return result("rejected", { error = "FOCUS_LOST requires COMBAT" }) end
        self.focused = false
        local changed = not self.pauseReasons.focus
        self.pauseReasons.focus = true
        if changed then self:_advanceRevision() end
        return result(changed and "applied" or "no_op", { paused = true,
            pauseReasons = pauseList(self.pauseReasons), stateRevision = self.revision })
    end
    if commandType == "FOCUS_GAINED" then
        if self.phase ~= Session.PHASE.COMBAT then return result("rejected", { error = "FOCUS_GAINED requires COMBAT" }) end
        local changed = not self.focused
        self.focused = true
        if changed then self:_advanceRevision() end
        return result(changed and "applied" or "no_op", { paused = self:isPaused(),
            requiresExplicitResume = self.pauseReasons.focus == true, stateRevision = self.revision })
    end
    if commandType == "RESUME" then
        if self.phase ~= Session.PHASE.COMBAT then return result("rejected", { error = "RESUME requires COMBAT" }) end
        local reason = command.reason or "user"
        if reason == "focus" and not self.focused then
            return result("rejected", { error = "cannot resume focus pause while unfocused" })
        end
        if not self.pauseReasons[reason] then return result("no_op", { stateRevision = self.revision }) end
        self.pauseReasons[reason] = nil
        self:_advanceRevision()
        return result("applied", { paused = self:isPaused(), pauseReasons = pauseList(self.pauseReasons),
            stateRevision = self.revision })
    end
    if commandType == "RETRY_SAVE" then return self:_retrySave() end
    if commandType == "ABANDON_SAVE_ERROR" then
        if self.phase ~= Session.PHASE.SAVE_ERROR then
            return result("rejected", { error = "ABANDON_SAVE_ERROR requires SAVE_ERROR" })
        end
        self.phase = Session.PHASE.TITLE
        self.pauseReasons = {}
        self.runState = nil
        self.pending = nil
        self.saveError = nil
        self:_advanceRevision()
        return result("abandoned", { phase = self.phase, unsavedChangesLost = true,
            stateRevision = self.revision })
    end
    return result("rejected", { error = "unknown command type" })
end

function Session:dispatch(command)
    if type(command) ~= "table" then return result("rejected", { error = "command must be a table" }) end
    local commandId = command.commandId
    if type(commandId) ~= "string" or commandId == "" then
        return result("rejected", { error = "commandId required" })
    end
    if self.commandResults[commandId] then return copy(self.commandResults[commandId]) end
    if type(command.expectedStateRevision) ~= "number"
        or command.expectedStateRevision ~= math.floor(command.expectedStateRevision) then
        return self:_remember(commandId, result("rejected", { error = "integer expectedStateRevision required",
            stateRevision = self.revision }))
    end
    if command.expectedStateRevision ~= self.revision then
        return self:_remember(commandId, result("stale", { expectedStateRevision = command.expectedStateRevision,
            stateRevision = self.revision, requiresPreviewRefresh = true }))
    end

    local handled = self:_handle(command)
    handled.stateRevision = handled.stateRevision or self.revision
    return self:_remember(commandId, handled)
end

return Session
