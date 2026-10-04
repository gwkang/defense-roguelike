local Content = require("src.content")
local Rules = require("src.rules")
local Battle = require("src.battle")
local Save = require("src.save")
local Session = require("src.session")
local Shop = require("src.shop")
local Rng = require("src.rng")

local Game = {}
Game.__index = Game

local MODULE_EFFECTS = {
    M01 = "서로 다른 종류 상하좌우 인접 시 공격속도 +20%",
    M02 = "주변 8칸에 다른 타워가 없으면 피해 +30%",
    M03 = "배치한 서로 다른 타워 종류당 피해 +5%",
    M04 = "배치 종류가 정확히 1종이면 공격속도 +35%",
    M05 = "타워 수용량 +2, 모든 타워 피해 -20%",
    M06 = "타워 수용량 -2, 배치 타워 피해 +35%",
    M07 = "상하좌우 같은 종류 인접 시 공격속도 +20%",
    M08 = "배치 종류가 정확히 2종이면 공격속도 +25%",
    M09 = "패치 3개인 타워 피해 +30%",
    M10 = "패치가 없는 타워 공격속도 +25%",
    M11 = "다른 배치 타워와 패치를 공유하면 피해 +20%",
    M13 = "패치 수가 단독 최다인 타워 피해 +40%",
    M17 = "둔화 중인 적에게 피해 +30%",
    M18 = "최근 2초 두 종류 이상에게 맞은 적에게 피해 +25%",
    M25 = "생존 웨이브 정산 +2골드",
    M26 = "무누수 생존 웨이브 정산 +2골드",
    M28 = "일반 생존 정산 전 5G당 이자 +1G · 최대 +4G · W15 제외",
    M29 = "상점 방문마다 첫 패치 구매 2회에 각각 1골드 환급",
    M30 = "상점 방문의 첫 리롤 비용 2골드 할인",
    M31 = "일반 생존 정산 미배치 종류당+1G · 최대3G · 슬롯1",
    M32 = "완료 시 빈 타워 수용량당 +1골드, 최대 +3",
    M33 = "성공한 리롤마다 피해 +3%p, 최대 +30%",
    M34 = "패치 구매 완료마다 피해 +3%p, 최대 +30%",
    M37 = "생존 웨이브 완료마다 피해 +3%p, 최대 +30%",
    M41 = "자신 제외 중가당 배치 피해 +8%p · 최대 +32%p",
    M12 = "배치2기 이상 · 모두 패치개수≥1 동일: 사거리+25%",
    M14 = "배치 타워별 고가 패치당 모듈 피해+8%p · 슬롯1",
    M15 = "패치3고유 배치 타워 모듈 속도+20%p · 슬롯1",
    M16 = "배치 패치 ID당 모듈 피해+3%p · 최대27%p · 슬롯1",
    M42 = "자신 제외 지불4G당 배치 피해+2%p · 내림/최대30%p",
    M43 = "장착 시 빈 모듈 슬롯당 피해 +12% · 최대 +36%",
    M46 = "현재 HP1–5 배치 타워 피해 +40% · 회복/패배 방지 없음",
    M44 = "현재 골드 20 이상이면 피해 +25%",
    M45 = "현재 골드 3 이하이면 공격속도 +25%",
}

local DISPLAY_NAMES = {
    M16 = "공용 설계", M31 = "예비 보급",
    T01 = "기본 포탑", T02 = "속사 포탑", T03 = "폭격 포탑", T04 = "냉각 포탑",
    T05 = "저격 포탑", T06 = "전격 포탑",
    P_DAMAGE = "출력 보강", P_RATE = "구동 보강", P_RANGE = "조준 보강", P_OVERLOAD = "과부하",
    P_OVERDRIVE = "과속 구동", P_LONG_RANGE = "장거리 개조", P_FOCUSED_BARRAGE = "집중 포격",
    P_CONTINUOUS_AIM = "연속 조준", P_HEAVY_AIM = "중량 조준",
    M01 = "교차 배치", M02 = "독립 운용", M05 = "분산 제어", M17 = "냉각 취약",
    M03 = "다양성", M04 = "단일 편대", M06 = "압축 제어", M07 = "동종 인접",
    M08 = "쌍두 체제", M09 = "완성형", M10 = "무개조 운용", M11 = "동일 설계",
    M13 = "일점 투자", M18 = "집중 사격", M25 = "보급 계약", M26 = "무결점 계약",
    M28 = "예치금", M29 = "부품 환급", M30 = "탐색 지원", M32 = "긴축 배당", M33 = "탐색 학습",
    M34 = "개조 학습", M37 = "현장 학습", M12 = "균등 투자", M14 = "고급 정비", M15 = "혼합 개조", M41 = "중가 연동", M42 = "자산 연동", M43 = "여유 회로", M44 = "절약 회로", M45 = "배수진", M46 = "비상 출력",
}

local REASON_KO = {
    insufficient_gold = "골드가 부족합니다", path_cell = "색 경로에는 배치할 수 없습니다",
    occupied_cell = "이미 타워가 있는 칸입니다", outside_map = "지도 밖에는 배치할 수 없습니다",
    tower_capacity = "타워 수용량이 가득 찼습니다", combat_move_forbidden = "전투 중 배치된 타워는 이동할 수 없습니다",
    patch_limit = "이 타워의 패치가 3/3입니다", module_slots = "모듈 슬롯이 가득 찼습니다",
    tower_target_required = "패치를 적용할 타워를 먼저 선택하세요",
    unknown_tower = "대상 타워를 찾을 수 없습니다", unknown_module = "대상 모듈을 찾을 수 없습니다",
    tower_not_placed = "배치된 타워만 회수할 수 있습니다", recall_selection_required = "회수할 타워를 선택하세요",
    recall_count_mismatch = "필요한 수만큼 타워를 선택하세요", duplicate_recall_target = "같은 타워를 중복 선택할 수 없습니다",
    recall_target_not_placed = "배치된 타워만 수용량 조정 대상으로 선택할 수 있습니다",
    stale_purchase_revision = "상태가 바뀌어 구매를 다시 선택해야 합니다",
    tower_not_in_frozen_pool = "이번 판의 타워 후보에 없는 종류입니다",
    module_not_in_frozen_pool = "이번 판의 모듈 후보에 없는 종류입니다",
}

local function copy(value)
    return Content.clone(value)
end

local function defaultMeta()
    return { unlockedTowerIds = { "T01", "T02", "T03", "T04" }, unlockedModuleIds = {}, developmentFixture = true }
end

local function sortedIds(items)
    local ids = {}
    for _, item in ipairs(items or {}) do ids[#ids + 1] = item.id end
    table.sort(ids)
    return ids
end

local function containsId(ids, targetId)
    for _, id in ipairs(ids or {}) do
        if id == targetId then return true end
    end
    return false
end

local function frozenPool(defs, meta)
    local towerIds, moduleIds = {}, {}
    for _, id in ipairs(sortedIds(defs.towers)) do
        if containsId(meta.unlockedTowerIds, id) then towerIds[#towerIds + 1] = id end
    end
    for _, id in ipairs(sortedIds(defs.modules)) do
        if (id ~= "M12" and id ~= "M14" and id ~= "M15" and id ~= "M16" and id ~= "M31" and id ~= "M28" and id ~= "M41" and id ~= "M42" and id ~= "M43" and id ~= "M46") or containsId(meta.unlockedModuleIds, id) then
            moduleIds[#moduleIds + 1] = id
        end
    end
    return {
        towerIds = towerIds,
        patchIds = sortedIds(defs.patches),
        moduleIds = moduleIds,
    }
end

function Game.defaultUnlockPool(defs)
    return frozenPool(defs, defaultMeta())
end

local function productionIdentityProvider()
    local nonce = 0
    return function()
        nonce = nonce + 1
        assert(love and love.data and love.math and love.timer, "LÖVE identity APIs required")
        local source = table.concat({ tostring(os.time()), tostring(love.timer.getTime()),
            tostring(love.math.random()), tostring(nonce) }, ":")
        local raw = love.data.hash("sha256", source)
        local hex = love.data.encode("string", "hex", raw)
        return { runId = "run-" .. hex, shopSeed = Rng.seedFromString(hex .. ":shop") }
    end
end

function Game.new(options)
    options = options or {}
    local defs = options.defs or Content.create()
    local store = options.checkpointStore
    if not store then
        assert(love and love.filesystem and love.data, "LÖVE filesystem/data are required")
        store = Save.new({
            storage = Save.loveFilesystemAdapter(love.filesystem),
            contentVersion = defs.version,
            engineTarget = "love-11.5",
            checksum = Save.loveSha256(love.data),
            checksumName = "sha256",
            validatePayload = Save.createLivePayloadValidator(defs),
            migrations = Save.createRun002Migrations(defs),
        })
    end
    local self = setmetatable({
        defs = defs,
        store = store,
        session = Session.new({ checkpointStore = store, metaState = defaultMeta() }),
        battle = nil,
        selectedTowerId = nil,
        speed = 1,
        accumulator = 0,
        commandSerial = 0,
        pendingBattleCommands = {},
        purchaseDraft = nil,
        transactionDraft = nil,
        newRunDraft = nil,
        safeExitDraft = false,
        pendingSavePresentation = nil,
        bossRulesOpen = false,
        notice = "",
        lastEvents = {},
        lastReceipt = nil,
        smoke = options.smoke == true,
        identityProvider = options.identityProvider or productionIdentityProvider(),
        quitCallback = options.quitCallback or function(code) love.event.quit(code or 0) end,
    }, Game)
    self:_restoreOrCreate()
    return self
end

function Game:_commandId(prefix)
    self.commandSerial = self.commandSerial + 1
    return string.format("%s:%d", prefix, self.commandSerial)
end

function Game:_checkpoint(run, kind, candidateMeta)
    return {
        metaState = copy(candidateMeta or self.session:getState().metaState or defaultMeta()),
        checkpointKind = kind,
        runState = copy(run),
        resumeDescriptor = { kind = kind, waveIndex = run.nextWaveIndex },
        transactionIdentity = self:_commandId("checkpoint"),
    }
end

function Game:_dispatch(command)
    command.commandId = command.commandId or self:_commandId(command.type:lower())
    command.expectedStateRevision = self.session:getRevision()
    local result = self.session:dispatch(command)
    if result.status == "save_error" then
        self.notice = "저장 실패: 저장 재시도 전에는 진행할 수 없습니다."
    end
    return result
end

function Game:_buildNewRun(identity)
    assert(type(identity) == "table" and type(identity.runId) == "string"
        and type(identity.shopSeed) == "number", "identityProvider must return runId and shopSeed")
    local run = Rules.newRun(self.defs, { runId = identity.runId })
    run.phase = Session.PHASE.SHOP
    run.frozenUnlockPool = frozenPool(self.defs, self.session:getState().metaState or defaultMeta())
    run.unlockRunProgress = {}
    run.shopState = Shop.createVisit(self.defs, {
        visitId = "S00",
        frozenUnlockPool = run.frozenUnlockPool,
        acquiredModuleIds = run.acquiredModuleIds,
        rngState = Rng.new(identity.shopSeed):getState(),
    })
    run.developmentComplete = false
    return run
end

function Game:_newRun()
    local run = self:_buildNewRun(self.identityProvider())
    local result = self:_dispatch({ type = "NEW_RUN", checkpoint = self:_checkpoint(run, "runStart") })
    if result.status == "applied" then
        self.notice = "무료 기본 포탑 2기를 선택해 지도 밝은 빈칸에 배치하세요."
    end
    return result
end

function Game:_restoreOrCreate()
    local restored = self:_dispatch({ type = "RESTORE" })
    if restored.status == "missing" then
        return self:_newRun()
    end
    if restored.status == "restored" then
        local state = self.session:getState()
        if state.phase == Session.PHASE.COMBAT then
            local waveId = string.format("W%02d", state.runState.nextWaveIndex or 1)
            self.battle = assert(Battle.new(self.defs, state.runState, waveId))
            self.notice = "전투 시작 저장에서 복원했습니다. 명시적으로 재개하세요."
        else
            if restored.loadStatus == "migrated" then
                self.notice = string.format("이전 저장을 이어받았습니다. W%02d 진행과 이번 판 후보를 보존했습니다.",
                    state.runState.nextWaveIndex or 1)
            else
                self.notice = restored.loadStatus == "recovered" and "이전 저장 세대를 복구했습니다." or "저장을 불러왔습니다."
            end
        end
    end
    return restored
end

function Game:getState()
    local state = self.session:getState()
    state.selectedTowerId = self.selectedTowerId
    state.speed = self.speed
    state.notice = self.notice
    state.purchaseDraft = copy(self.purchaseDraft)
    state.transactionDraft = copy(self.transactionDraft)
    state.newRunDraft = self.newRunDraft and { runId = self.newRunDraft.run.runId } or nil
    state.safeExitDraft = self.safeExitDraft == true
    state.bossRulesOpen = self.bossRulesOpen
    state.moduleFixtureLabel = string.format("모듈 개발 subset %d/48", #(self.defs.modules or {}))
    state.deferredLabel = string.format("미구현: 추가 모듈 %d종/해금 · 고난도 · 정식 아트", 48 - #(self.defs.modules or {}))
    state.battle = self.battle and Battle.snapshot(self.battle) or nil
    state.lastEvents = copy(self.lastEvents)
    state.lastReceipt = copy(self.lastReceipt)
    state.moduleStatusById = {}
    local run = state.runState
    state.towerUnlocks = {}
    state.towerUnlockById = {}
    state.newTowerUnlocks = {}
    state.newModuleUnlocks = {}
    state.moduleUnlockById = {
        M31 = {
            moduleId = "M31", name = DISPLAY_NAMES.M31,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M31"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M31"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M31"
                and not run.shopState.soldOut.module or false,
            condition = "W09–W14 일반 생존 완료 · 미배치 타워 서로 다른2종 이상 전투 내내 · 배치로1종이 되면 제외",
        },
        M16 = {
            moduleId = "M16", name = DISPLAY_NAMES.M16,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M16"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M16"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M16"
                and not run.shopState.soldOut.module or false,
            condition = "W09–W14 일반 생존 완료 · 배치 패치 ID≥5종을 전투 내내 · 중복1종/예비 제외 · 늦은5종 실패",
        },
        M12 = {
            moduleId = "M12", name = DISPLAY_NAMES.M12,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M12"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M12"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M12"
                and not run.shopState.soldOut.module or false,
            condition = "W06–W14 일반 생존 완료 · 배치3기 이상 모두 같은 양의 패치 개수를 전투 내내 유지 · 동일ID 가능 · 무패치 후기 배치/패배/미완료/보스/중복 제외",
        },
        M14 = {
            moduleId = "M14", name = DISPLAY_NAMES.M14,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M14"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M14"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M14"
                and not run.shopState.soldOut.module or false,
            condition = "W09–W14 일반 생존 완료 · 패치 정가합21G 이상인 같은 타워1기를 시작부터 완료직전 배치 · 중가7×3 가능/고가 불필요",
        },
        M15 = {
            moduleId = "M15", name = DISPLAY_NAMES.M15,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M15"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M15"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M15"
                and not run.shopState.soldOut.module or false,
            condition = "W06–W14 일반 생존 완료 · 같은 패치3고유 배치 타워1기를 전투 내내 유지",
        },
        M28 = {
            moduleId = "M28", name = DISPLAY_NAMES.M28,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M28"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M28"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M28"
                and not run.shopState.soldOut.module or false,
            condition = "W03–W14 일반 생존 완료 · 보상 전 20G 이상",
        },
        M41 = {
            moduleId = "M41", name = DISPLAY_NAMES.M41,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M41"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M41"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M41"
                and not run.shopState.soldOut.module or false,
            condition = "W06–W14 일반 생존 완료 · 서로 다른 중가2종 이상을 전투 내내 장착",
        },
        M42 = {
            moduleId = "M42", name = DISPLAY_NAMES.M42,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M42"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M42"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M42"
                and not run.shopState.soldOut.module or false,
            condition = "W09–W14 일반 생존 완료 · 장착 실지불합40G 이상을 전투 내내 유지",
        },
        M43 = {
            moduleId = "M43", name = DISPLAY_NAMES.M43,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M43"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M43"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M43"
                and not run.shopState.soldOut.module or false,
            condition = "W03–W14 일반 생존 완료 · 장착1개 이상·빈칸2개 이상을 전투 내내 유지",
        },
        M46 = {
            moduleId = "M46", name = DISPLAY_NAMES.M46,
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedModuleIds, "M46"),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.moduleIds, "M46"),
            isCurrentOffer = run and run.shopState and run.shopState.offers.module == "M46"
                and not run.shopState.soldOut.module or false,
            condition = "W03–W14 일반 생존 완료 · 시작HP1–5·이번 누수0 또는 W09+완료HP20",
        },
    }
    if run then
        local reserve, reserveError = Rules.reserveComposition(self.defs, self.battle and self.battle.run or run)
        state.moduleUnlockById.M31.reserveTypeCount = reserve and reserve.count or nil
        state.moduleUnlockById.M31.observationError = reserveError
        state.moduleUnlockById.M31.currentAttemptQualifies = reserve ~= nil and reserve.count >= 2
        local shared, sharedError = Rules.sharedPatchComposition(self.defs, self.battle and self.battle.run or run)
        state.moduleUnlockById.M16.distinctPatchIds = shared and copy(shared.distinctPatchIds) or nil
        state.moduleUnlockById.M16.distinctPatchCount = shared and shared.distinctPatchCount or nil
        state.moduleUnlockById.M16.placedTowerCount = shared and shared.placedTowerCount or nil
        state.moduleUnlockById.M16.observationError = sharedError
        state.moduleUnlockById.M16.currentAttemptQualifies = shared ~= nil and shared.unlockQualifies
        local balanced, balancedError = Rules.balancedPatchComposition(self.defs, self.battle and self.battle.run or run)
        state.moduleUnlockById.M12.placedTowerCount = balanced and balanced.placedTowerCount or nil
        state.moduleUnlockById.M12.commonPatchCount = balanced and balanced.commonPatchCount or nil
        state.moduleUnlockById.M12.allPlacedPositiveAndEqual = balanced and balanced.allPlacedPositiveAndEqual or false
        state.moduleUnlockById.M12.observationError = balancedError
        state.moduleUnlockById.M12.currentAttemptQualifies = balanced ~= nil and balanced.unlockQualifies
        local investment, investmentError = Rules.patchInvestmentComposition(self.defs, run)
        state.moduleUnlockById.M14.qualifyingTowerCount = investment and investment.qualifyingTowerCount or nil
        state.moduleUnlockById.M14.qualifyingTowerIds = investment and copy(investment.qualifyingTowerIds) or nil
        state.moduleUnlockById.M14.observationError = investmentError
        state.moduleUnlockById.M14.currentAttemptQualifies = investment ~= nil and investment.qualifyingTowerCount > 0
        local mixed, mixedError = Rules.mixedPatchComposition(self.defs, run)
        state.moduleUnlockById.M15.qualifyingTowerCount = mixed and mixed.qualifyingTowerCount or nil
        state.moduleUnlockById.M15.qualifyingTowerIds = mixed and copy(mixed.qualifyingTowerIds) or nil
        state.moduleUnlockById.M15.observationError = mixedError
        state.moduleUnlockById.M15.currentAttemptQualifies = mixed ~= nil and mixed.qualifyingTowerCount > 0
        local assets, assetError = Rules.modulePurchaseValue(self.defs, run)
        state.moduleUnlockById.M42.installedPaidGold = assets and assets.paidGoldTotal or nil
        state.moduleUnlockById.M42.observationError = assetError
        state.moduleUnlockById.M42.currentAttemptQualifies = assets ~= nil and assets.paidGoldTotal >= 40
        local composition = Rules.midModuleComposition(self.defs, run)
        state.moduleUnlockById.M41.installedMidModuleCount = composition.count
        state.moduleUnlockById.M41.installedMidModuleIds = composition.moduleIds
        state.moduleUnlockById.M41.currentAttemptQualifies = composition.qualifies
        local slots = Rules.moduleSlots(run)
        for key, value in pairs(slots) do state.moduleUnlockById.M43[key] = value end
        state.moduleUnlockById.M43.currentAttemptQualifies = slots.installedModuleCount >= 1 and slots.emptySlots >= 2
    end
    for _, towerId in ipairs({ "T05", "T06" }) do
        local status = {
            towerId = towerId, name = DISPLAY_NAMES[towerId],
            permanentlyUnlocked = containsId(state.metaState and state.metaState.unlockedTowerIds, towerId),
            inCurrentRunPool = containsId(run and run.frozenUnlockPool and run.frozenUnlockPool.towerIds, towerId),
            isCurrentOffer = run and run.shopState and run.shopState.offers.tower == towerId
                and not run.shopState.soldOut.tower or false,
            condition = towerId == "T05" and "W05 생존 완료 → W06 도달" or "W15 보스 첫 승리",
        }
        state.towerUnlocks[#state.towerUnlocks + 1] = status
        state.towerUnlockById[towerId] = status
    end
    if state.phase ~= Session.PHASE.SAVE_ERROR then
        for _, event in ipairs(self.lastEvents) do
            if event.type == "tower_unlocked" then state.newTowerUnlocks[#state.newTowerUnlocks + 1] = copy(event) end
            if event.type == "module_unlocked" then state.newModuleUnlocks[#state.newModuleUnlocks + 1] = copy(event) end
        end
    end
    if run then
        local projectionRun = self.battle and self.battle.run or run
        local context = { towerInstanceId = self.selectedTowerId }
        if run.shopState and run.shopState.offers then context.patchId = run.shopState.offers.patch end
        if self.battle then
            context.enemies = self.battle.enemies
            context.tick = self.battle.tick
        end
        for _, moduleDef in ipairs(self.defs.modules or {}) do
            local status = assert(Rules.projectModuleStatus(self.defs, projectionRun, moduleDef.id, context))
            state.moduleStatusById[moduleDef.id] = status
        end
        if run.shopState then state.rerollPreview = assert(Rules.previewReroll(run)) end
    end
    return state
end

function Game:_applyDurableRun(candidate, kind)
    local result = self:_dispatch({ type = "APPLY_DURABLE", checkpoint = self:_checkpoint(candidate, kind) })
    return result.status == "applied", result
end

function Game:selectTower(instanceId)
    if self.transactionDraft then return false, "transaction_draft_active" end
    local state = self.session:getState()
    if state.phase == Session.PHASE.RESULT or state.phase == Session.PHASE.SAVE_ERROR then
        return false, "selection_phase"
    end
    local run = state.runState
    for _, tower in ipairs((run and run.towerInstances) or {}) do
        if tower.instanceId == instanceId then
            self.selectedTowerId = instanceId
            self.notice = string.format("%s #%d 선택 · 패치 %d/3 · 지도 밝은 빈칸을 클릭하세요.",
                DISPLAY_NAMES[tower.typeId] or tower.typeId, instanceId, #(tower.patchIds or {}))
            if self.purchaseDraft and self.purchaseDraft.kind == "patch" then self:selectOffer("patch") end
            if self.purchaseDraft and self.purchaseDraft.kind == "module" then self:_refreshMixedTradeProjection(self.purchaseDraft, false) end
            return true
        end
    end
    self.notice = "선택할 수 없는 타워입니다."
    return false
end

function Game:cancelSelection()
    if self.transactionDraft then return false, "transaction_draft_active" end
    self.selectedTowerId = nil
    if self.purchaseDraft and self.purchaseDraft.kind == "module" then self:_refreshMixedTradeProjection(self.purchaseDraft, false) end
    self.notice = "선택을 취소했습니다."
    return true
end

local function findTower(run, instanceId)
    for _, tower in ipairs(run.towerInstances or {}) do
        if tower.instanceId == instanceId then return tower end
    end
    return nil
end

local function findEvent(events, eventType)
    for _, event in ipairs(events or {}) do
        if event.type == eventType then return event end
    end
    return nil
end

local function receiptFromEvents(kind, events)
    local eventType = ({
        patch = "patch_purchased",
        module = "module_purchased",
        reroll = "reroll_paid",
        settlement = "wave_reward",
    })[kind]
    local event = eventType and findEvent(events, eventType) or nil
    if not event then return nil end
    local receipt = copy(event)
    receipt.kind = kind
    return receipt
end

local function transactionRequest(draft, phase)
    return {
        phase = phase,
        kind = draft.kind,
        instanceId = draft.instanceId,
        moduleId = draft.moduleId,
        recallTowerIds = copy(draft.selectedRecallTowerIds or {}),
    }
end

function Game:_refreshMixedTradeProjection(draft, sale)
    local run = self.session:getState().runState
    local target = draft.offerId or draft.moduleId
    local mixed = target == "M15" or Rules.projectModuleStatus(self.defs, run, "M15").installed
    local maintenance = target == "M14" or Rules.projectModuleStatus(self.defs, run, "M14").installed
    local balanced = target == "M12" or Rules.projectModuleStatus(self.defs, run, "M12").installed
    local shared = target == "M16" or Rules.projectModuleStatus(self.defs, run, "M16").installed
    local reserveProposed
    if sale then reserveProposed = Rules.tryInventoryTransaction(self.defs, run, transactionRequest(draft, draft.phase))
    else reserveProposed = Rules.tryPurchaseModule(self.defs, run, draft.offerId, draft.selectedRecallTowerIds or {}) end
    draft.reserveBefore = Rules.projectModuleStatus(self.defs, run, "M31")
    draft.reserveAfter = reserveProposed and Rules.projectModuleStatus(self.defs, reserveProposed, "M31") or nil
    draft.mixedTrade, draft.maintenanceTrade, draft.balancedTrade, draft.sharedTrade = nil, nil, nil, nil
    if not mixed and not maintenance and not balanced and not shared then return end
    local selectedId = sale and draft.projectionTowerId or self.selectedTowerId
    local projection
    if selectedId == nil then
        projection = { error = "tower_not_selected" }
    else
        local proposed, _, reason
        if sale then
            proposed, _, reason = Rules.tryInventoryTransaction(self.defs, run, transactionRequest(draft, draft.phase))
        else
            proposed, _, reason = Rules.tryPurchaseModule(self.defs, run, draft.offerId, draft.selectedRecallTowerIds or {})
        end
        if not proposed then
            local context = { towerInstanceId = selectedId }
            projection = { towerInstanceId = selectedId, before = Rules.projectStats(self.defs, run, selectedId),
                beforeStatus = Rules.projectModuleStatus(self.defs, run, "M15", context),
                beforeMaintenanceStatus = Rules.projectModuleStatus(self.defs, run, "M14", context),
                beforeBalancedStatus = Rules.projectModuleStatus(self.defs, run, "M12", context), error = reason }
        else
            local projectionError
            projection, projectionError = Rules.projectTradeTowerStats(self.defs, run, proposed, selectedId)
            projection = projection or { towerInstanceId = selectedId, error = projectionError }
        end
    end
    if mixed then draft.mixedTrade = copy(projection) end
    if maintenance then draft.maintenanceTrade = copy(projection) end
    if balanced then draft.balancedTrade = copy(projection) end
    if shared then
        local proposed, _, reason
        if sale then proposed, _, reason = Rules.tryInventoryTransaction(self.defs, run, transactionRequest(draft, draft.phase))
        else proposed, _, reason = Rules.tryPurchaseModule(self.defs, run, draft.offerId, draft.selectedRecallTowerIds or {}) end
        projection.beforeSharedAggregate = Rules.projectModuleStatus(self.defs, run, "M16")
        projection.afterSharedAggregate = proposed and Rules.projectModuleStatus(self.defs, proposed, "M16") or nil
        if not proposed then projection.error = reason end
        draft.sharedTrade = copy(projection)
    end
end

function Game:_refreshBalancedPatchProjection(draft)
    local run = self.session:getState().runState
    local balanced = Rules.projectModuleStatus(self.defs, run, "M12").installed
    local shared = Rules.projectModuleStatus(self.defs, run, "M16").installed
    if not balanced and not shared then return end
    local selectedId = draft.targetInstanceId
    local proposed, _, reason = Rules.tryPurchasePatch(self.defs, run, selectedId, draft.offerId)
    if not proposed then
        if balanced then draft.balancedTrade = { error = reason, towerInstanceId = selectedId } end
        if shared then draft.sharedTrade = { error = reason, towerInstanceId = selectedId } end
        return
    end
    local projection, projectionError = Rules.projectTradeTowerStats(self.defs, run, proposed, selectedId)
    if balanced then draft.balancedTrade = projection or { error = projectionError, towerInstanceId = selectedId } end
    if shared then
        projection = projection or { error = projectionError, towerInstanceId = selectedId }
        projection.beforeSharedAggregate = Rules.projectModuleStatus(self.defs, run, "M16")
        projection.afterSharedAggregate = Rules.projectModuleStatus(self.defs, proposed, "M16")
        draft.sharedTrade = copy(projection)
    end
end

function Game:beginInventoryTransaction(request)
    if self.transactionDraft then return false, "transaction_draft_active" end
    if type(request) ~= "table" then return false, "invalid_transaction_request" end
    local state = self.session:getState()
    local ruleRequest = {
        phase = state.phase,
        kind = request.kind,
        instanceId = request.instanceId,
        moduleId = request.moduleId,
    }
    local preview, reason = Rules.previewInventoryTransaction(self.defs, state.runState, ruleRequest)
    if not preview then
        self.notice = "거래 미리보기 실패: " .. (REASON_KO[reason] or tostring(reason))
        return false, reason
    end

    local draft = copy(preview)
    draft.phase = state.phase
    draft.selectedAtRevision = state.stateRevision
    draft.targetId = preview.instanceId or preview.moduleId
    draft.selectedRecallTowerIds = {}
    draft.canCommit = draft.requiredRecallCount == 0
    self.purchaseDraft = nil
    draft.projectionTowerId = self.selectedTowerId
    self.transactionDraft = draft
    self:_refreshMixedTradeProjection(draft, true)
    if draft.requiredRecallCount > 0 then
        self.notice = string.format("거래를 완료하려면 배치 타워 %d기를 회수 대상으로 선택하세요.",
            draft.requiredRecallCount)
    else
        self.notice = string.format("판매 미리보기: 환급 %d골드. 확인 전에는 저장이나 자원이 바뀌지 않습니다.",
            draft.refundGold or 0)
    end
    return true, nil
end

function Game:setInventoryRecallSelection(instanceId, selected)
    local draft = self.transactionDraft
    if not draft then return false, "transaction_draft_required" end
    local state = self.session:getState()
    if draft.selectedAtRevision ~= state.stateRevision or draft.phase ~= state.phase then
        self.notice = "거래 선택 실패: 상태가 바뀌었습니다. 현재 상태에서 거래를 다시 시작하세요."
        return false, "stale_transaction_revision"
    end
    if not containsId(draft.eligibleRecallTowerIds, instanceId) then
        return false, "recall_target_not_placed"
    end

    local chosen = containsId(draft.selectedRecallTowerIds, instanceId)
    if selected == nil then selected = not chosen end
    if selected and not chosen then
        if #(draft.selectedRecallTowerIds or {}) >= draft.requiredRecallCount then
            return false, "recall_count_mismatch"
        end
        draft.selectedRecallTowerIds[#draft.selectedRecallTowerIds + 1] = instanceId
        table.sort(draft.selectedRecallTowerIds)
    elseif not selected and chosen then
        for index, id in ipairs(draft.selectedRecallTowerIds) do
            if id == instanceId then
                table.remove(draft.selectedRecallTowerIds, index)
                break
            end
        end
    end
    draft.canCommit = #draft.selectedRecallTowerIds == draft.requiredRecallCount
    self:_refreshMixedTradeProjection(draft, true)
    self.notice = string.format("수용량 조정 타워 %d/%d기 선택.",
        #draft.selectedRecallTowerIds, draft.requiredRecallCount)
    return true, nil
end

function Game:cancelInventoryTransaction()
    if not self.transactionDraft then return false, "transaction_draft_required" end
    self.transactionDraft = nil
    self.notice = "거래 미리보기를 취소했습니다. 골드·보유품·배치는 바뀌지 않았습니다."
    return true, nil
end

function Game:confirmInventoryTransaction()
    local draft = self.transactionDraft
    if not draft then return false, "transaction_draft_required" end
    local state = self.session:getState()
    if draft.selectedAtRevision ~= state.stateRevision or draft.phase ~= state.phase then
        self.notice = "거래 확인 실패: 상태가 바뀌었습니다. 현재 상태에서 거래를 다시 시작하세요."
        return false, "stale_transaction_revision"
    end

    local candidate, events, reason = Rules.tryInventoryTransaction(self.defs, state.runState,
        transactionRequest(draft, state.phase))
    if not candidate then
        self.notice = "거래 확인 실패: " .. (REASON_KO[reason] or tostring(reason))
        return false, reason
    end

    local committed, applyResult = self:_applyDurableRun(candidate, "transaction")
    self.transactionDraft = nil
    if committed then
        self.pendingSavePresentation = nil
        self.lastEvents = events or {}
        if draft.kind == "sell_tower" and self.selectedTowerId == draft.instanceId then
            self.selectedTowerId = nil
        end
        self.notice = draft.kind == "recall_tower"
            and string.format("타워 #%d 회수 저장 완료.", draft.instanceId)
            or string.format("저장 확인 후 판매 완료: %d골드 환급.", draft.refundGold or 0)
    elseif applyResult and applyResult.status == "save_error" then
        self.pendingSavePresentation = {
            kind = "inventory_transaction",
            transactionKind = draft.kind,
            targetId = draft.targetId,
            recallTowerIds = copy(draft.selectedRecallTowerIds),
        }
    end
    return committed, committed and nil or "save_failed"
end

function Game:recallTower(instanceId)
    if self.transactionDraft then return false, "transaction_draft_active" end
    local state = self.session:getState()
    local request = { phase = state.phase, kind = "recall_tower", instanceId = instanceId }
    local candidate, events, reason = Rules.tryInventoryTransaction(self.defs, state.runState, request)
    if not candidate then
        self.notice = "회수 실패: " .. (REASON_KO[reason] or tostring(reason))
        return false, reason
    end

    local committed, applyResult = self:_applyDurableRun(candidate, "transaction")
    if committed then
        self.pendingSavePresentation = nil
        self.lastEvents = events or {}
        self.notice = string.format("타워 #%d 회수 저장 완료.", instanceId)
    elseif applyResult and applyResult.status == "save_error" then
        self.pendingSavePresentation = {
            kind = "inventory_transaction",
            transactionKind = "recall_tower",
            targetId = instanceId,
            recallTowerIds = {},
        }
    end
    return committed, committed and nil or "save_failed"
end

function Game:selectOffer(kind)
    if self.transactionDraft then return false, "transaction_draft_active" end
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.SHOP then return false, "shop_required" end
    local run = state.runState
    local offer = run.shopState and run.shopState.offers and run.shopState.offers[kind]
    if not offer then return false, "sold_out" end
    local draft = { kind = kind, offerId = offer, cost = 0, enabled = true,
        visitId = run.shopState.visitId, selectedAtRevision = state.stateRevision }
    if kind == "tower" then
        local def = self.defs.towersById[offer]
        draft.cost = def.price
        draft.newInstanceId = run.nextInstanceId
        draft.detail = string.format("새 타워 #%d / %s", draft.newInstanceId, def.name)
    elseif kind == "module" then
        local def = self.defs.modulesById[offer]
        draft.cost = def.price
        draft.slotBefore = #(run.modules or {})
        draft.slotAfter = draft.slotBefore + 1
        draft.slotCapacity = Rules.moduleCapacity(run)
        draft.effect = MODULE_EFFECTS[offer] or def.name
        local preview, previewReason = Rules.previewModulePurchase(self.defs, run, offer)
        if not preview then
            draft.enabled, draft.canCommit, draft.error = false, false, previewReason
        else
            draft.towerCapacityBefore = preview.towerCapacityBefore
            draft.towerCapacityAfter = preview.towerCapacityAfter
            draft.placedTowerCountBefore = preview.placedTowerCountBefore
            draft.placedTowerCountAfter = preview.placedTowerCountAfter
            draft.requiredRecallCount = preview.requiredRecallCount
            draft.eligibleRecallTowerIds = copy(preview.eligibleRecallTowerIds)
            draft.spareCircuitBefore = copy(preview.spareCircuitBefore)
            draft.spareCircuitAfter = copy(preview.spareCircuitAfter)
            draft.emergencyBefore = copy(preview.emergencyBefore)
            draft.emergencyAfter = copy(preview.emergencyAfter)
            draft.midLinkBefore = copy(preview.midLinkBefore)
            draft.midLinkAfter = copy(preview.midLinkAfter)
            draft.assetLinkBefore = copy(preview.assetLinkBefore)
            draft.assetLinkAfter = copy(preview.assetLinkAfter)
            draft.reserveBefore = copy(preview.reserveBefore)
            draft.reserveAfter = copy(preview.reserveAfter)
            draft.depositBefore = copy(preview.depositBefore)
            draft.depositAfter = copy(preview.depositAfter)
            draft.sharedBefore = copy(preview.sharedBefore)
            draft.sharedAfter = copy(preview.sharedAfter)
            draft.selectedRecallTowerIds = {}
            draft.canCommit = preview.requiredRecallCount == 0
            draft.enabled = draft.canCommit
            if not draft.canCommit then draft.error = "recall_selection_required" end
        end
    elseif kind == "patch" then
        local def = self.defs.patchesById[offer]
        draft.cost = def.price
        draft.targetInstanceId = self.selectedTowerId
        local target = self.selectedTowerId and findTower(run, self.selectedTowerId) or nil
        if not target then
            draft.enabled, draft.error = false, "tower_target_required"
        elseif #(target.patchIds or {}) >= 3 then
            draft.enabled, draft.error = false, "patch_limit"
        else
            draft.patchCountBefore = #(target.patchIds or {})
            draft.patchCountAfter = draft.patchCountBefore + 1
            draft.before = assert(Rules.projectStats(self.defs, run, target.instanceId))
            local previewRun = copy(run)
            local previewTarget = assert(findTower(previewRun, target.instanceId))
            previewTarget.patchIds[#previewTarget.patchIds + 1] = offer
            draft.after = assert(Rules.projectStats(self.defs, previewRun, target.instanceId))
            local refund = assert(Rules.projectModuleStatus(self.defs, run, "M29", { patchId = offer }))
            draft.receiptPreview = {
                paidGold = def.price,
                refundGold = refund.nextPatchRefundGold or 0,
                netGold = def.price - (refund.nextPatchRefundGold or 0),
            }
            local growth = assert(Rules.projectModuleStatus(self.defs, run, "M34", {
                towerInstanceId = target.instanceId,
            }))
            draft.growthPreview = {
                moduleId = "M34", before = growth.growth,
                after = growth.nextGrowth, cap = growth.cap,
            }
        end
    else
        return false, "unknown_offer_kind"
    end
    if run.gold < draft.cost then
        draft.enabled, draft.canCommit, draft.error = false, false, "insufficient_gold"
    end
    self.purchaseDraft = draft
    if kind == "module" then self:_refreshMixedTradeProjection(draft, false) end
    if kind == "patch" then self:_refreshBalancedPatchProjection(draft) end
    self.notice = draft.enabled and "구매 미리보기입니다. 확인 전에는 저장이나 자원이 바뀌지 않습니다."
        or "구매 확인 불가: " .. (REASON_KO[draft.error] or tostring(draft.error))
    return true
end

function Game:setPurchaseRecallSelection(instanceId, selected)
    local draft = self.purchaseDraft
    if not draft or draft.kind ~= "module" or (draft.requiredRecallCount or 0) <= 0 then
        return false, "purchase_recall_selection_required"
    end
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.SHOP or draft.selectedAtRevision ~= state.stateRevision
        or not state.runState.shopState or state.runState.shopState.visitId ~= draft.visitId
        or state.runState.shopState.offers.module ~= draft.offerId then
        self.notice = "구매 선택 실패: 상태가 바뀌었습니다. 현재 상품을 다시 선택하세요."
        return false, "stale_purchase_revision"
    end
    if not containsId(draft.eligibleRecallTowerIds, instanceId) then
        return false, "recall_target_not_placed"
    end

    local chosen = containsId(draft.selectedRecallTowerIds, instanceId)
    if selected == nil then selected = not chosen end
    if selected and not chosen then
        if #draft.selectedRecallTowerIds >= draft.requiredRecallCount then
            return false, "recall_count_mismatch"
        end
        draft.selectedRecallTowerIds[#draft.selectedRecallTowerIds + 1] = instanceId
        table.sort(draft.selectedRecallTowerIds)
    elseif not selected and chosen then
        for index, id in ipairs(draft.selectedRecallTowerIds) do
            if id == instanceId then table.remove(draft.selectedRecallTowerIds, index) break end
        end
    end
    draft.canCommit = #draft.selectedRecallTowerIds == draft.requiredRecallCount
    self:_refreshMixedTradeProjection(draft, false)
    draft.enabled = draft.canCommit
    draft.error = draft.canCommit and nil or "recall_selection_required"
    self.notice = string.format("모듈 구매 수용량 조정 타워 %d/%d기 선택.",
        #draft.selectedRecallTowerIds, draft.requiredRecallCount)
    return true, nil
end

function Game:cancelPurchase()
    if not self.purchaseDraft then return false, "no_purchase_draft" end
    self.purchaseDraft = nil
    self.notice = "구매 미리보기를 취소했습니다. 골드·상품·대상은 바뀌지 않았습니다."
    return true
end

function Game:closeShop()
    if self.transactionDraft then return { status = "rejected", error = "transaction_draft_active" } end
    self.purchaseDraft = nil
    local result = self:_dispatch({ type = "CLOSE_SHOP" })
    if result.status == "applied" then
        local run = self.session:getState().runState
        self.notice = run.shopState and run.shopState.accessOpen
            and string.format("상점을 접었습니다. %s 방문은 다음 전투 전까지 다시 열 수 있습니다.", run.shopState.visitId)
            or "상점을 접었습니다. 배치를 확인하세요."
    end
    return result
end

function Game:reopenShop()
    local run = self.session:getState().runState
    if not run or not run.shopState or not run.shopState.accessOpen then
        self.notice = "전투를 시작한 상점 방문은 다시 열 수 없습니다."
        return { status = "rejected", error = "shop_visit_closed" }
    end
    local result = self:_dispatch({ type = "REOPEN_SHOP" })
    if result.status == "applied" then self.notice = "같은 " .. run.shopState.visitId .. " 방문을 다시 열었습니다." end
    return result
end

function Game:confirmPurchase()
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.SHOP then return false, "shop_required" end
    local run = state.runState
    local draft = self.purchaseDraft
    if not draft then return false, "purchase_draft_required" end
    if draft.selectedAtRevision ~= state.stateRevision then
        self.notice = "구매 확인 실패: 상태가 바뀌었습니다. 현재 상태에서 상품을 다시 선택하세요."
        return false, "stale_purchase_revision"
    end
    if not draft.enabled then
        self.notice = "구매 확인 불가: " .. (REASON_KO[draft.error] or tostring(draft.error))
        return false, draft.error
    end
    local kind, offer = draft.kind, draft.offerId
    if not run.shopState or run.shopState.visitId ~= draft.visitId
        or not run.shopState.offers or run.shopState.offers[kind] ~= offer then
        self.notice = "구매 확인 실패: 상품 상태가 바뀌었습니다."
        return false, "stale_purchase_draft"
    end
    local candidate, events, reason
    if kind == "tower" then
        candidate, events, reason = Rules.tryPurchaseTower(self.defs, run, offer)
    elseif kind == "patch" then
        if not draft.targetInstanceId or self.selectedTowerId ~= draft.targetInstanceId then
            self.notice = "구매 확인 실패: 패치 대상이 바뀌었습니다."
            return false, "stale_patch_target"
        end
        candidate, events, reason = Rules.tryPurchasePatch(self.defs, run, draft.targetInstanceId, offer)
    elseif kind == "module" then
        candidate, events, reason = Rules.tryPurchaseModule(
            self.defs, run, offer, copy(draft.selectedRecallTowerIds or {}))
    else
        return false, "unknown_offer_kind"
    end
    if not candidate then
        self.notice = "구매 실패: " .. (REASON_KO[reason] or tostring(reason))
        return false, reason
    end
    candidate.shopState.offers[kind] = nil
    candidate.shopState.soldOut[kind] = true
    local committed, applyResult = self:_applyDurableRun(candidate, "transaction")
    self.purchaseDraft = nil
    if committed then
        self.pendingSavePresentation = nil
        self.lastEvents = copy(events or {})
        self.lastReceipt = receiptFromEvents(kind, events)
        if kind == "tower" then self.selectedTowerId = draft.newInstanceId end
        self.notice = "저장 확인 후 구매 완료: " .. (DISPLAY_NAMES[offer] or offer)
    elseif applyResult and applyResult.status == "save_error" then
        self.pendingSavePresentation = {
            kind = "purchase", purchaseKind = kind, offerId = offer,
            instanceId = draft.newInstanceId,
            events = copy(events or {}), receipt = receiptFromEvents(kind, events),
        }
    end
    return committed, committed and nil or "save_failed"
end

-- Compatibility entry point deliberately selects a draft; it never purchases in one click.
function Game:purchase(kind)
    return self:selectOffer(kind)
end

function Game:rerollShop()
    if self.transactionDraft then return false, "transaction_draft_active" end
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.SHOP then return false, "shop_required" end
    local run = state.runState
    local receipt, previewReason = Rules.previewReroll(run)
    if not receipt then return false, previewReason end
    if not receipt.canCommit then
        self.notice = string.format("리롤 실패: %d골드가 필요합니다.", receipt.paidGold)
        return false, "insufficient_gold"
    end
    local nextShopState = Shop.reroll(self.defs, run.shopState, {
        frozenUnlockPool = run.frozenUnlockPool,
        acquiredModuleIds = run.acquiredModuleIds,
    })
    local candidate, events, reason = Rules.tryApplyReroll(self.defs, run, nextShopState)
    if not candidate then return false, reason end
    local committed, applyResult = self:_applyDurableRun(candidate, "transaction")
    self.purchaseDraft = nil
    if committed then
        self.pendingSavePresentation = nil
        self.lastEvents = copy(events or {})
        self.lastReceipt = receiptFromEvents("reroll", events)
        local nextNominal = 2 + 2 * (candidate.shopState.rerollCount or 0)
        self.notice = string.format("상품 바꾸기 %d골드 저장 완료. 다음 명목 비용 %d골드",
            receipt.paidGold, nextNominal)
    elseif applyResult and applyResult.status == "save_error" then
        self.pendingSavePresentation = {
            kind = "reroll", events = copy(events or {}),
            receipt = receiptFromEvents("reroll", events),
        }
    end
    return committed, committed and nil or "save_failed"
end

function Game:placeSelected(x, y)
    if self.transactionDraft then return false, "transaction_draft_active" end
    if not self.selectedTowerId then return false, "tower_not_selected" end
    local state = self.session:getState()
    if state.phase == Session.PHASE.COMBAT then
        if self.session:isPaused() then
            self.notice = "정지 중에는 전투 배치를 변경할 수 없습니다. 명시적으로 재개하세요."
            return false, "combat_paused"
        end
        local selected
        for _, tower in ipairs(self.battle and self.battle.run.towerInstances or {}) do
            if tower.instanceId == self.selectedTowerId then selected = tower break end
        end
        if selected and selected.placement then
            self.notice = "전투 중에는 이미 배치한 타워를 이동할 수 없습니다."
            return false, "combat_move_forbidden"
        end
        self.pendingBattleCommands[#self.pendingBattleCommands + 1] = {
            type = "place_tower", commandId = self:_commandId("battle-place"),
            instanceId = self.selectedTowerId, x = x, y = y,
        }
        self.notice = "전투 틱에 미배치 타워 설치를 예약했습니다."
        return true
    end
    if state.phase ~= Session.PHASE.PREPARE and state.phase ~= Session.PHASE.SHOP then
        return false, "placement_phase"
    end
    local candidate, _, reason = Rules.tryPlaceTower(self.defs, state.runState, state.runState.mapId,
        self.selectedTowerId, x, y, "prepare")
    if not candidate then
        self.notice = "배치 실패: " .. (REASON_KO[reason] or tostring(reason))
        return false, reason
    end
    local committed = self:_applyDurableRun(candidate, "transaction")
    if committed then
        local current = self.session:getState().runState
        local firstVisit = current.shopState and current.shopState.visitId == "S00"
            and (current.nextWaveIndex or 1) == 1
        self.notice = firstVisit
            and string.format("타워 #%d 배치 완료 · 다른 무료 타워를 선택하거나 상점을 접으세요.", self.selectedTowerId)
            or string.format("타워 #%d 배치 저장 완료.", self.selectedTowerId)
    end
    return committed, committed and nil or "save_failed"
end

function Game:_startCommittedBattle(waveId)
    self.battle = assert(Battle.new(self.defs, self.session:getState().runState, waveId))
    self.purchaseDraft = nil
    self.accumulator = 0
end

function Game:startWave()
    if self.transactionDraft then return false, "transaction_draft_active" end
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.PREPARE and state.phase ~= Session.PHASE.SHOP then return false, "prepare_required" end
    local index = state.runState.nextWaveIndex or 1
    local maximum = self.defs.capabilities and self.defs.capabilities.waveRange.last or #self.defs.waves
    local waveId = string.format("W%02d", index)
    if index > maximum or not self.defs.wavesById[waveId] then
        self.notice = "시작할 다음 웨이브가 없습니다."
        return false, "wave_unavailable"
    end
    local candidate = copy(state.runState)
    if candidate.shopState then candidate.shopState.accessOpen = false end
    local result = self:_dispatch({ type = "START_COMBAT", checkpoint = self:_checkpoint(candidate, "combatStart") })
    if result.status ~= "applied" then
        if result.status == "save_error" then
            self.pendingSavePresentation = { kind = "combat_start", waveId = waveId }
        end
        return false, result.error or result.status
    end
    self:_startCommittedBattle(waveId)
    self.notice = waveId .. " 시작 저장 완료."
    return true
end

local function unlockNotice(events)
    local notices = {}
    for _, event in ipairs(events or {}) do
        if event.type == "tower_unlocked" then
            notices[#notices + 1] = (DISPLAY_NAMES[event.towerId] or event.towerId)
                .. " 영구 해금! 다음 새 판부터 추첨 후보에 포함됩니다."
        elseif event.type == "module_unlocked" then
            local detail = event.moduleId == "M31"
                and " 영구 해금! W09–W14 일반 생존 완료 · 미배치 서로 다른2종 이상 전투 내내."
                    .. " 장착: 일반 정산 미배치 종류당+1G · 최대3G · 슬롯1. 이번 판 제외 · 다음 성공 새 판 후보."
                or event.moduleId == "M16"
                and " 영구 해금! W09–W14 일반 생존 완료 · 배치 패치 ID≥5종을 전투 내내 유지."
                    .. " 중복1종/예비 제외. 장착: 배치 ID당 모듈 피해+3%p · 최대27%p · 슬롯1. 다음 성공 새 판 후보."
                or event.moduleId == "M12"
                and " 영구 해금! W06–W14 일반 생존 완료 · 배치3기 이상 모두 같은 양의 패치 개수를 전투 내내 유지."
                    .. " 동일 패치ID 가능. 장착: 배치2기 이상 모두 같은 양의 패치 개수이면 배치 타워 사거리+25% · 슬롯1. 다음 성공 새 판 후보."
                or event.moduleId == "M14"
                and " 영구 해금! W09–W14 일반 생존 완료 · 정가합21G 이상인 같은 타워를 시작부터 완료직전 배치."
                    .. " 중가7×3 가능/고가 불필요. 장착 시 해당 배치 타워 고가 패치당 모듈 피해+8%p · 슬롯1. 다음 성공 새 판 후보."
                or event.moduleId == "M15"
                and " 영구 해금! W06–W14 일반 생존 완료 · 서로 다른 패치3종인 같은 타워를 시작부터 완료직전 배치."
                    .. " 장착 시 해당 배치 타워 모듈 속도 합산+20%p. 다음 성공 새 판부터 추첨 후보."
                or event.moduleId == "M42"
                and " 영구 해금! W09–W14 일반 생존 완료 · 장착 실지불합40G 이상을 전투 내내 유지."
                    .. " 자신 제외 지불4G당 배치 피해+2%p · 내림/최대30%p. 이번 판 제외 · 다음 새 판부터 후보."
                or event.moduleId == "M41"
                and " 영구 해금! W06–W14 일반 생존 완료 · 서로 다른 중가2종 이상을 전투 내내 장착."
                    .. " 자신 제외 중가당 배치 피해 +8%p · 최대32%p. 이번 판 제외 · 다음 새 판부터 후보."
                or event.moduleId == "M46"
                and " 영구 해금! W03–W14 일반 생존 완료 · 시작HP1–5·이번 누수0 또는 W09+완료HP20."
                    .. " 장착 현재 HP1–5 배치 타워 피해 +40%. 이번 판 제외 · 다음 새 판부터 후보."
                or event.moduleId == "M43"
                and " 영구 해금! W03–W14 일반 생존 완료 · 장착1개 이상·빈칸2개 이상을 전투 내내 유지."
                    .. " 장착 시 빈칸당 피해 +12% · 최대 36%. 이번 판 제외 · 다음 새 판부터 후보."
                or " 영구 해금! W03–W14 일반 생존 완료 · 보상 전 20G 이상."
                    .. " 장착 일반 정산 전 5G당 +1G · 최대 4G. 이번 판 제외 · 다음 새 판부터 후보."
            notices[#notices + 1] = "\n" .. (DISPLAY_NAMES[event.moduleId] or event.moduleId) .. detail
        end
    end
    return #notices > 0 and (" " .. table.concat(notices, " ")) or ""
end

function Game:_commitBattleCompletion(summary)
    local state = self.session:getState()
    local current = state.runState
    local candidate, events, reason = Rules.reduceCompletion(self.defs, current, summary)
    if not candidate then return false, reason end
    local candidateMeta, unlockEvents = Rules.reduceTowerUnlocks(state.metaState, current, candidate, summary, events)
    for _, event in ipairs(unlockEvents) do events[#events + 1] = event end
    local moduleUnlockEvents
    candidateMeta, moduleUnlockEvents = Rules.reduceModuleUnlocks(self.defs, candidateMeta, current, candidate, summary, events)
    for _, event in ipairs(moduleUnlockEvents) do events[#events + 1] = event end
    local nextPhase
    if summary.resultKind == "defeat" or summary.resultKind == "victory" then
        local result = self:_dispatch({ type = "FINISH_RUN", checkpoint = self:_checkpoint(candidate, "runResult", candidateMeta) })
        if result.status == "applied" then
            self.pendingSavePresentation = nil
            self.lastEvents = copy(events or {})
            self.lastReceipt = nil
            self.notice = (summary.resultKind == "victory"
                and "최종 보스를 처치했습니다. 승리 결과가 저장되었습니다."
                or "방어 실패. 결과가 저장되었습니다.") .. unlockNotice(events)
        elseif result.status == "save_error" then
            self.pendingSavePresentation = {
                kind = "run_result", resultKind = summary.resultKind,
                events = copy(events or {}), receipt = nil,
            }
        end
        self.battle = nil
        return result.status == "applied", result.error
    end
    local wave = assert(self.defs.wavesById[summary.waveId])
    if wave.opensShopAfter then
        local previousRngState = assert(current.shopState and current.shopState.rngState,
            "completed run requires prior shop rng state")
        candidate.shopState = Shop.createVisit(self.defs, {
            visitId = assert(wave.shopVisitId),
            frozenUnlockPool = candidate.frozenUnlockPool,
            acquiredModuleIds = candidate.acquiredModuleIds,
            rngState = previousRngState,
        })
        nextPhase = Session.PHASE.SHOP
    else
        nextPhase = Session.PHASE.PREPARE
    end
    local result = self:_dispatch({ type = "COMPLETE_WAVE", nextPhase = nextPhase,
        checkpoint = self:_checkpoint(candidate, "waveComplete", candidateMeta) })
    if result.status == "applied" then
        self.pendingSavePresentation = nil
        self.lastEvents = copy(events or {})
        self.lastReceipt = receiptFromEvents("settlement", events)
        self.notice = (wave.opensShopAfter
            and string.format("%s 완료 저장 확인. %s 상점에서 다음 3웨이브를 준비하세요.",
                summary.waveId, wave.shopVisitId)
            or string.format("%s 완료 저장 확인. 다음 웨이브를 준비하세요.", summary.waveId)) .. unlockNotice(events)
        self.battle = nil
    elseif result.status == "save_error" then
        self.pendingSavePresentation = {
            kind = "wave_completion", waveId = summary.waveId,
            opensShopAfter = wave.opensShopAfter == true,
            events = copy(events or {}), receipt = receiptFromEvents("settlement", events),
        }
    end
    return result.status == "applied", result.error
end

function Game:update(dt)
    if not self.battle or not self.session:canAdvanceTime() then return end
    self.accumulator = self.accumulator + dt * self.speed
    local steps = 0
    while self.accumulator + 1e-12 >= Battle.FIXED_DT and self.battle and not self.battle.result and steps < 8 do
        local commands = self.pendingBattleCommands
        self.pendingBattleCommands = {}
        local events, reason = Battle.step(self.battle, Battle.FIXED_DT, commands)
        if not events then error(reason) end
        self.lastEvents = events
        self.accumulator = self.accumulator - Battle.FIXED_DT
        if math.abs(self.accumulator) < 1e-12 then self.accumulator = 0 end
        steps = steps + 1
    end
    if self.battle and self.battle.result then
        self:_commitBattleCompletion(Battle.summary(self.battle))
    end
end

function Game:setSpeed(speed)
    if speed ~= 1 and speed ~= 2 then return false end
    self.speed = speed
    self.notice = tostring(speed) .. "배속"
    return true
end

function Game:togglePause()
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.COMBAT then return false end
    local userPaused = false
    for _, reason in ipairs(state.pauseReasons) do if reason == "user" then userPaused = true end end
    if not userPaused then self.accumulator = 0 end
    local result = self:_dispatch({ type = userPaused and "RESUME" or "PAUSE", reason = "user" })
    self.notice = userPaused and "수동 일시정지를 해제했습니다." or "수동 일시정지"
    return result.status == "applied" or result.status == "no_op"
end

function Game:resumeAll()
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.COMBAT then return false end
    for _, reason in ipairs(state.pauseReasons) do
        if reason ~= "saveError" then self:_dispatch({ type = "RESUME", reason = reason }) end
    end
    self.notice = self.session:canAdvanceTime() and "명시적으로 전투를 재개했습니다." or "남은 정지 사유가 있습니다."
    return self.session:canAdvanceTime()
end

function Game:onFocus(focused)
    local state = self.session:getState()
    if state.phase ~= Session.PHASE.COMBAT then return end
    if not focused and state.focused then self.accumulator = 0 end
    self:_dispatch({ type = focused and "FOCUS_GAINED" or "FOCUS_LOST" })
    self.notice = focused and "포커스 복귀: 자동 재개하지 않습니다." or "포커스 이탈로 정지했습니다."
end

function Game:toggleBossRules()
    local phase = self.session:getState().phase
    if phase == Session.PHASE.SAVE_ERROR or phase == Session.PHASE.TITLE then return false end
    self.bossRulesOpen = not self.bossRulesOpen
    self.notice = self.bossRulesOpen and "보스 규칙을 열었습니다." or "보스 규칙을 닫았습니다."
    return true
end

function Game:requestNewRun()
    if self.session:getState().phase ~= Session.PHASE.RESULT then return false, "result_required" end
    if self.newRunDraft then return true end
    local run = self:_buildNewRun(self.identityProvider())
    self.newRunDraft = { run = run, checkpoint = self:_checkpoint(run, "runStart") }
    self.notice = "새 판을 시작하면 현재 결과 화면으로 돌아올 수 없습니다. 확인하거나 취소하세요."
    return true
end

function Game:cancelNewRun()
    if not self.newRunDraft then return false, "new_run_draft_required" end
    self.newRunDraft = nil
    self.notice = "새 판 시작을 취소했습니다. 저장된 결과는 그대로입니다."
    return true
end

function Game:confirmNewRun()
    if self.session:getState().phase ~= Session.PHASE.RESULT then return false, "result_required" end
    if not self.newRunDraft then return false, "new_run_draft_required" end
    local result = self:_dispatch({ type = "NEW_RUN", checkpoint = self.newRunDraft.checkpoint })
    if result.status == "applied" then
        self.newRunDraft = nil
        self.purchaseDraft = nil
        self.transactionDraft = nil
        self.selectedTowerId = nil
        self.battle = nil
        self.accumulator = 0
        self.pendingBattleCommands = {}
        self.bossRulesOpen = false
        self.lastEvents = {}
        self.lastReceipt = nil
        self.notice = "새 판 저장 완료. 무료 기본 포탑 2기를 배치하세요."
        return true
    end
    return false, result.error or result.status
end

function Game:retrySave()
    local pendingPresentation = self.pendingSavePresentation
    local result = self:_dispatch({ type = "RETRY_SAVE" })
    if result.status == "applied" then
        local state = self.session:getState()
        if state.phase == Session.PHASE.SHOP and self.newRunDraft then
            self.newRunDraft = nil
            self.purchaseDraft = nil
            self.transactionDraft = nil
            self.selectedTowerId = nil
            self.battle = nil
            self.accumulator = 0
            self.pendingBattleCommands = {}
            self.bossRulesOpen = false
            self.lastEvents = {}
            self.lastReceipt = nil
        elseif state.phase == Session.PHASE.COMBAT
            and pendingPresentation and pendingPresentation.kind == "combat_start" then
            self:_startCommittedBattle(pendingPresentation.waveId)
        elseif pendingPresentation and pendingPresentation.kind == "purchase" then
            if pendingPresentation.purchaseKind == "tower" then
                self.selectedTowerId = pendingPresentation.instanceId
            end
            self.lastEvents = copy(pendingPresentation.events or {})
            self.lastReceipt = copy(pendingPresentation.receipt)
        elseif pendingPresentation and pendingPresentation.kind == "inventory_transaction" then
            if pendingPresentation.transactionKind == "sell_tower"
                and self.selectedTowerId == pendingPresentation.targetId then
                self.selectedTowerId = nil
            end
        elseif pendingPresentation and pendingPresentation.kind == "reroll" then
            self.lastEvents = copy(pendingPresentation.events or {})
            self.lastReceipt = copy(pendingPresentation.receipt)
        elseif pendingPresentation and pendingPresentation.kind == "wave_completion" then
            self.lastEvents = copy(pendingPresentation.events or {})
            self.lastReceipt = copy(pendingPresentation.receipt)
            self.battle = nil
        elseif pendingPresentation and pendingPresentation.kind == "run_result" then
            self.lastEvents = copy(pendingPresentation.events or {})
            self.lastReceipt = nil
            self.battle = nil
        end
        self.pendingSavePresentation = nil
        self.safeExitDraft = false
        self.notice = "저장 재시도 성공."
            .. (pendingPresentation and pendingPresentation.kind == "combat_start"
                and (" " .. pendingPresentation.waveId .. " 시작 저장 완료.") or "")
            .. unlockNotice(pendingPresentation and pendingPresentation.events)
    end
    return result
end

function Game:requestSafeExit()
    if self.session:getState().phase ~= Session.PHASE.SAVE_ERROR then return false, "save_error_required" end
    self.safeExitDraft = true
    self.notice = "종료하면 미저장 변경이 유실될 수 있습니다. 종료를 확인하거나 취소하세요."
    return true
end

function Game:cancelSafeExit()
    if not self.safeExitDraft then return false, "safe_exit_draft_required" end
    self.safeExitDraft = false
    self.notice = "안전 종료를 취소했습니다. 같은 저장 후보를 다시 시도할 수 있습니다."
    return true
end

function Game:confirmSafeExit()
    if self.session:getState().phase ~= Session.PHASE.SAVE_ERROR then return false, "save_error_required" end
    if not self.safeExitDraft then return false, "safe_exit_draft_required" end
    local result = self:_dispatch({ type = "ABANDON_SAVE_ERROR" })
    if result.status ~= "abandoned" then return false, result.error or result.status end
    self.safeExitDraft = false
    self.pendingSavePresentation = nil
    self.purchaseDraft = nil
    self.transactionDraft = nil
    self.newRunDraft = nil
    self.battle = nil
    self.pendingBattleCommands = {}
    self.notice = "미저장 변경을 폐기하고 종료합니다."
    self.quitCallback(0)
    return true
end

return Game
