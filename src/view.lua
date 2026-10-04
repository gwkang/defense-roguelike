local View = {}
View.__index = View
local patchIdsText

View.WIDTH = 480
View.HEIGHT = 270
View.MAP_X = 8
View.MAP_Y = 30
View.CELL = 13

local C = {
    ink = { 0.10, 0.08, 0.08 }, cream = { 0.96, 0.89, 0.72 }, paper = { 0.82, 0.73, 0.55 },
    red = { 0.73, 0.20, 0.16 }, tomato = { 0.91, 0.36, 0.18 }, mustard = { 0.94, 0.69, 0.20 },
    mint = { 0.31, 0.62, 0.43 }, blue = { 0.25, 0.44, 0.55 }, panel = { 0.16, 0.12, 0.10 },
    guide = { 0.26, 0.20, 0.14 }, white = { 1, 1, 1 },
}

local TOWER_NAMES = { T01 = "기본 포탑", T02 = "속사 포탑", T03 = "폭격 포탑", T04 = "냉각 포탑",
    T05 = "저격 포탑", T06 = "전격 포탑" }
local PATCH_NAMES = {
    P_DAMAGE = "출력 보강", P_RATE = "구동 보강", P_RANGE = "조준 보강", P_OVERLOAD = "과부하",
    P_OVERDRIVE = "과속 구동", P_LONG_RANGE = "장거리 개조", P_FOCUSED_BARRAGE = "집중 포격",
    P_CONTINUOUS_AIM = "연속 조준", P_HEAVY_AIM = "중량 조준",
}
local MODULE_NAMES = {
    M16 = "공용 설계", M31 = "예비 보급",
    M01 = "교차 배치", M02 = "독립 운용", M03 = "다양성", M04 = "단일 편대",
    M05 = "분산 제어", M06 = "압축 제어", M07 = "동종 인접", M08 = "쌍두 체제",
    M09 = "완성형", M10 = "무개조 운용", M11 = "동일 설계", M13 = "일점 투자",
    M17 = "냉각 취약", M18 = "집중 사격", M25 = "보급 계약", M26 = "무결점 계약",
    M28 = "예치금", M29 = "부품 환급", M30 = "탐색 지원", M32 = "긴축 배당", M33 = "탐색 학습",
    M34 = "개조 학습", M37 = "현장 학습", M12 = "균등 투자", M14 = "고급 정비", M15 = "혼합 개조", M41 = "중가 연동", M42 = "자산 연동", M43 = "여유 회로", M44 = "절약 회로", M45 = "배수진", M46 = "비상 출력",
}
local MODULE_EFFECTS = {
    M01 = "다른 종류와 상하좌우 인접 시 공속 +20%",
    M02 = "주변 8칸에 다른 포탑이 없으면 피해 +30%",
    M03 = "배치한 서로 다른 타워 종류마다 피해 +5%",
    M04 = "배치 종류가 정확히 1종이면 공속 +35%",
    M05 = "수용량 +2 · 모든 포탑 피해 -20%",
    M06 = "수용량 -2 · 배치 타워 피해 +35%",
    M07 = "상하좌우 같은 종류 인접 시 공속 +20%",
    M08 = "배치 종류가 정확히 2종이면 공속 +25%",
    M09 = "패치 3개 타워 피해 +30%",
    M10 = "패치 없는 타워 공속 +25%",
    M11 = "다른 배치 타워와 패치 공유 시 피해 +20%",
    M13 = "패치 수 단독 최다 타워 피해 +40%",
    M17 = "둔화 중인 적에게 피해 +30%",
    M18 = "최근 2초 두 종류 이상 피격 적의 다음 피해 +25%",
    M25 = "생존 웨이브 정산 +2골드",
    M26 = "무누수 생존 웨이브 정산 +2골드",
    M28 = "일반 정산 전 5G당 이자 +1G · 최대 +4G",
    M41 = "자신 제외 중가당 배치 피해+8%p · 최대32%p",
    M12 = "배치2기 이상 · 모두 패치개수≥1 동일: 사거리+25%",
    M14 = "배치 타워별 고가 패치당 모듈 피해+8%p · 슬롯1",
    M15 = "패치3고유 배치 타워 모듈 속도+20%p · 슬롯1",
    M16 = "배치ID당 모듈피해+3%p · 최대27%p · 슬롯1",
    M42 = "자신 제외 지불4G당 배치 피해+2%p(내림/최대30%)",
    M43 = "빈 모듈 슬롯당 피해 +12% · 최대 +36%",
    M46 = "현재 HP1–5 배치 타워 피해 +40% · 회복/패배 방지 없음",
    M29 = "방문 중 첫 패치 구매 2회에 각각 1G 환급",
    M30 = "방문 중 첫 성공 리롤 명목가 -2G",
    M31 = "일반 정산 미배치 종류당+1G · 최대3G · 슬롯1",
    M32 = "생존 정산 시 빈 수용량당 +1G · 최대 +3G",
    M33 = "성공 리롤마다 피해 +3%p · 최대 +30%p",
    M34 = "성공 패치 구매마다 피해 +3%p · 최대 +30%p",
    M37 = "W01-W14 생존 완료마다 피해 +3%p · 최대 +30%p",
    M44 = "현재 골드 20G 이상이면 피해 +25%",
    M45 = "현재 골드 3G 이하이면 공속 +25%",
}
local ENEMY_NAMES = { E01 = "기본", E02 = "고속", E03 = "고체력", E04 = "군집", E05 = "보스" }
local ENEMY_SPECIAL = { E02 = "고속", E03 = "고체력", E04 = "군집", E05 = "보스" }

local PHASE_NAMES = {
    SHOP = "상점", PREPARE = "전투 준비", COMBAT = "전투", SAVE_ERROR = "저장 오류", RESULT = "결과",
}

local PURCHASE_ERROR_TEXT = {
    insufficient_gold = "정가를 낼 골드가 부족합니다",
    module_slots = "모듈 슬롯이 가득 찼습니다",
    recall_selection_required = "필요한 수만큼 회수 대상을 고르세요",
    tower_target_required = "패치를 적용할 타워를 먼저 고르세요",
    patch_limit = "선택 타워의 패치가 3/3입니다",
}

local function inside(x, y, rect)
    return x >= rect.x and y >= rect.y and x < rect.x + rect.w and y < rect.y + rect.h
end

local function setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function readFontData()
    for _, path in ipairs({ "C:/Windows/Fonts/malgun.ttf", "C:/Windows/Fonts/gulim.ttc" }) do
        local file = io.open(path, "rb")
        if file then
            local bytes = file:read("*a")
            file:close()
            return love.filesystem.newFileData(bytes, path:match("[^/]+$")), path
        end
    end
    return nil, nil
end

local function displayName(kind, id)
    if kind == "tower" then return TOWER_NAMES[id] or id end
    if kind == "patch" then return PATCH_NAMES[id] or id end
    if kind == "module" then return MODULE_NAMES[id] or id end
    return id
end

local function newMidLinkUnlock(state)
    if state.phase == "SAVE_ERROR" then return false end
    for _, event in ipairs(state.newModuleUnlocks or {}) do
        if event.moduleId == "M41" then return true end
    end
    return false
end

local function newAssetLinkUnlock(state)
    if state.phase == "SAVE_ERROR" then return false end
    for _, event in ipairs(state.newModuleUnlocks or {}) do
        if event.moduleId == "M42" then return true end
    end
    return false
end

local function newMixedUnlock(state)
    for _, event in ipairs(state.newModuleUnlocks or {}) do
        if event.moduleId == "M15" then return true end
    end
    return false
end

local function newMaintenanceUnlock(state)
    for _, event in ipairs(state.newModuleUnlocks or {}) do
        if event.moduleId == "M14" then return true end
    end
    return false
end

local function newBalancedUnlock(state)
    for _, event in ipairs(state.newModuleUnlocks or {}) do
        if event.moduleId == "M12" then return true end
    end
    return false
end

local function newSharedUnlock(state)
    for _, event in ipairs(state.newModuleUnlocks or {}) do
        if event.moduleId == "M16" then return true end
    end
    return false
end

local function newReserveUnlock(state)
    for _, event in ipairs(state.newModuleUnlocks or {}) do if event.moduleId == "M31" then return true end end
    return false
end

function View.new(defs)
    local self = setmetatable({ buttons = {}, texts = {}, fontCache = {},
        defs = assert(defs, "content definitions required"), inventoryPage = 1,
        waveDetailIndex = nil, selectionObserved = false, lastObservedSelectedTowerId = nil,
        inventoryManagementOpen = false, inventoryManagementTab = "tower",
        managedModuleId = nil, moduleStatusOpen = false, towerUnlocksOpen = false,
        unlockLookupTab = "tower" }, View)
    self.canvas = love.graphics.newCanvas(View.WIDTH, View.HEIGHT)
    self.canvas:setFilter("nearest", "nearest")
    self.fontData, self.fontPath = readFontData()
    local probe = self:_font(11)
    self.fontInfo = {
        label = self.fontPath and "Windows Korean font" or "LÖVE fallback font",
        path = self.fontPath,
        hasKorean = probe:hasGlyphs("가나다라마바사아자차카타파하"),
    }
    return self
end

function View:_font(pixelSize)
    pixelSize = math.max(1, math.floor(pixelSize + 0.5))
    if not self.fontCache[pixelSize] then
        self.fontCache[pixelSize] = self.fontData and love.graphics.newFont(self.fontData, pixelSize)
            or love.graphics.newFont(pixelSize)
    end
    return self.fontCache[pixelSize]
end

function View:viewport(windowWidth, windowHeight)
    local scale = math.max(1, math.floor(math.min(windowWidth / View.WIDTH, windowHeight / View.HEIGHT)))
    local width, height = View.WIDTH * scale, View.HEIGHT * scale
    return { scale = scale, x = math.floor((windowWidth - width) / 2), y = math.floor((windowHeight - height) / 2), w = width, h = height }
end

function View:windowToLogical(x, y, windowWidth, windowHeight)
    local viewport = self:viewport(windowWidth, windowHeight)
    if x < viewport.x or y < viewport.y or x >= viewport.x + viewport.w or y >= viewport.y + viewport.h then
        return nil, nil, "letterbox"
    end
    return math.floor((x - viewport.x) / viewport.scale), math.floor((y - viewport.y) / viewport.scale)
end

function View:mapCell(x, y)
    local mapWidth, mapHeight = 14 * View.CELL, 10 * View.CELL
    if x < View.MAP_X or y < View.MAP_Y or x >= View.MAP_X + mapWidth or y >= View.MAP_Y + mapHeight then return nil end
    return math.floor((x - View.MAP_X) / View.CELL), math.floor((y - View.MAP_Y) / View.CELL)
end

function View:_text(value, x, y, width, align, size, color)
    local text = { value = tostring(value or ""), x = x, y = y, width = width,
        align = align or "left", size = size or 11, color = color or C.cream }
    self.texts[#self.texts + 1] = text
    return text
end

function View:_button(x, y, w, h, label, action, enabled, selected, textSize)
    textSize = textSize or 11
    local rect = { x = x, y = y, w = w, h = h, label = label, action = action,
        enabled = enabled ~= false, selected = selected == true, textSize = textSize }
    self.buttons[#self.buttons + 1] = rect
    setColor(rect.selected and C.mint or (rect.enabled and C.mustard or C.paper), rect.enabled and 1 or 0.45)
    love.graphics.rectangle("fill", x, y, w, h)
    setColor(rect.selected and C.cream or C.ink)
    love.graphics.setLineWidth(rect.selected and 2 or 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    love.graphics.setLineWidth(1)
    self:_text(label, x + 2, y + math.max(2, math.floor((h - textSize - 2) / 2)), w - 4, "center", textSize,
        rect.selected and C.white or C.ink)
    return rect
end

function View:_hitArea(x, y, w, h, action, enabled)
    local rect = { x = x, y = y, w = w, h = h, label = "", action = action,
        enabled = enabled ~= false, hitOnly = true }
    self.buttons[#self.buttons + 1] = rect
    return rect
end

function View:findButton(actionType, kind)
    for _, button in ipairs(self.buttons) do
        if button.action and button.action.type == actionType and (kind == nil or button.action.kind == kind) then
            return button
        end
    end
    return nil
end

function View:buttonLabelFits(button, viewportScale)
    return self:_font((button.textSize or 11) * viewportScale):getWidth(button.label) <= math.max(0, (button.w - 4) * viewportScale)
end

function View:textBlockFits(text, viewportScale)
    local bounds = self:textBlockBounds(text, viewportScale)
    return bounds.left >= 0 and bounds.right <= View.WIDTH * viewportScale
        and bounds.bottom <= View.HEIGHT * viewportScale
end

function View:textBlockBounds(text, viewportScale)
    local font = self:_font(text.size * viewportScale)
    local width = (text.width or (View.WIDTH - text.x)) * viewportScale
    local _, lines = font:getWrap(text.value, width)
    return {
        left = text.x * viewportScale,
        top = text.y * viewportScale,
        right = (text.x + (text.width or (View.WIDTH - text.x))) * viewportScale,
        bottom = text.y * viewportScale + #lines * font:getHeight(),
        lineCount = #lines,
    }
end

function View:findTextRole(role)
    for _, text in ipairs(self.texts) do
        if text.role == role or text.extraRole == role then return text end
    end
    return nil
end

function View:openTowerUnlocks(state)
    if not state or (state.phase ~= "SHOP" and state.phase ~= "PREPARE" and state.phase ~= "RESULT")
        or state.purchaseDraft or state.transactionDraft or state.newRunDraft or state.safeExitDraft
        or state.bossRulesOpen or self:hasWaveDetail() then return false end
    self.towerUnlocksOpen = true
    if newMidLinkUnlock(state) then self.unlockLookupTab = "midlink" end
    if newAssetLinkUnlock(state) then self.unlockLookupTab = "assetlink" end
    if newMixedUnlock(state) then self.unlockLookupTab = "mixed" end
    if newMaintenanceUnlock(state) then self.unlockLookupTab = "maintenance" end
    if newBalancedUnlock(state) then self.unlockLookupTab = "balanced" end
    if newSharedUnlock(state) then self.unlockLookupTab = "shared" end
    if newReserveUnlock(state) then self.unlockLookupTab = "reserve" end
    return true
end

function View:closeTowerUnlocks()
    if not self.towerUnlocksOpen then return false end
    self.towerUnlocksOpen = false
    return true
end

function View:hasTowerUnlocks()
    return self.towerUnlocksOpen == true
end

function View:setUnlockLookupTab(tab)
    if not self.towerUnlocksOpen or (tab ~= "tower" and tab ~= "deposit" and tab ~= "spare" and tab ~= "emergency" and tab ~= "midlink" and tab ~= "assetlink" and tab ~= "mixed" and tab ~= "maintenance" and tab ~= "balanced" and tab ~= "shared" and tab ~= "reserve") then return false end
    self.unlockLookupTab = tab
    return true
end

function View:_towerStatsLine(towerId)
    local tower = self.defs.towersById[towerId]
    if not tower then return "" end
    return string.format("기본 피해 %g · 간격 %.1f초 · 사거리 %g칸", tower.damage,
        1 / tower.attackRate, tower.range)
end

function View:_towerRoleLine(towerId)
    if towerId == "T05" then return "긴 사거리·강한 한 발 · 느린 기본 간격" end
    if towerId == "T06" then return "연쇄 최대 2회 · 1.6칸 · 피해 70%→49%" end
    return nil
end

function View:_newTowerUnlockFeedback(state)
    if state.phase == "SAVE_ERROR" then return nil end
    local names = {}
    for _, event in ipairs(state.newTowerUnlocks or {}) do
        names[#names + 1] = displayName("tower", event.towerId)
    end
    local depositUnlocked, spareUnlocked, emergencyUnlocked = false, false, false
    for _, event in ipairs(state.newModuleUnlocks or {}) do
        names[#names + 1] = displayName("module", event.moduleId)
        if event.moduleId == "M28" then depositUnlocked = true end
        if event.moduleId == "M43" then spareUnlocked = true end
        if event.moduleId == "M46" then emergencyUnlocked = true end
    end
    if #names == 0 then return nil end
    if newReserveUnlock(state) and #names == 1 then
        return "예비 보급: W09–14 생존 · 미배치2종 이상 내내"
            .. "\n장착: 일반 정산 미배치 종류당+1G · 최대3G"
            .. "\n이번 판 제외 · 다음 성공 새 판 후보"
    end
    if newSharedUnlock(state) and #names == 1 then
        return "공용 설계: W09–14 생존 · 배치 ID≥5종 내내"
            .. "\n장착: ID당 피해+3%p/최대27 · 중복1종/예비 제외"
            .. "\n이번 판 제외 · 다음 성공 새 판 후보"
    end
    if newBalancedUnlock(state) and #names == 1 then
        return "균등 투자: W06–14 생존 · 배치3기 이상 전투 내내"
            .. "\n모두 패치개수≥1 동일 · 장착2기 이상 사거리+25%"
            .. "\n이번 판 제외 · 다음 성공 새 판 후보"
    end
    if newMaintenanceUnlock(state) and #names == 1 then
        return "고급 정비: W09–14 생존 · 시작부터 정가합≥21G 타워"
            .. "\n장착: 해당 배치 타워 고가 패치당 피해+8%p"
            .. "\n이번 판 제외 · 다음 성공 새 판 후보"
    end
    if newMixedUnlock(state) and #names == 1 then
        return "혼합 개조: W06–14 생존 · 시작부터 패치3종 타워"
            .. "\n장착: 해당 배치 타워 모듈 속도+20%p"
            .. "\n이번 판 제외 · 다음 성공 새 판 후보"
    end
    if newMidLinkUnlock(state) or newAssetLinkUnlock(state) or newMixedUnlock(state) or newMaintenanceUnlock(state) or newBalancedUnlock(state) or newSharedUnlock(state) or newReserveUnlock(state) then
        local rows = {}
        local groupSize = #names >= 10 and 4 or (#names >= 9 and 3 or (#names >= 7 and 4 or 3))
        for first = 1, #names, groupSize do
            local row = {}
            for index = first, math.min(first + groupSize - 1, #names) do row[#row + 1] = names[index] end
            rows[#rows + 1] = table.concat(row, " · ")
        end
        if #names >= 9 then return table.concat(rows, "\n"), "각 조건·효과: 해금 상세 · 다음 성공 새 판 후보" end
        rows[#rows + 1] = "각 조건·효과: 해금 상세"
        return table.concat(rows, "\n"), "이번 판 후보 제외 · 다음 새 판부터 후보"
    end
    if emergencyUnlocked then
        local rows = {}
        if depositUnlocked then rows[#rows + 1] = "예치금: 정산 전≥20G · 장착 이자+1G/5G(최대4G)" end
        if spareUnlocked then rows[#rows + 1] = "여유: 장착≥1·빈칸≥2 전투 내내 · 장착 피해+12%/빈칸(최대36%)" end
        rows[#rows + 1] = "비상: 시작HP1~5·무누수 / W9+완료HP20 · HP1~5 피해+40%"
        if not (depositUnlocked and spareUnlocked) then
            rows[#rows + 1] = "W03–14 생존 완료 · 이번 판 제외/다음 새 판 후보"
        end
        return table.concat(rows, "\n"), depositUnlocked and spareUnlocked
            and "W03–14 생존 완료 · 이번 판 제외/다음 새 판 후보" or nil
    end
    if depositUnlocked and spareUnlocked then
        return "예치금: 정산 전≥20G · 장착 이자+1G/5G(최대4G)"
            .. "\n여유: 장착≥1·빈칸≥2 전투 내내 · 장착 피해+12%/빈칸(최대36%)"
            .. "\nW03–14 생존 완료 · 이번 판 제외/다음 새 판 후보"
    elseif spareUnlocked then
        return "여유 회로 영구 해금 · 장착≥1·빈칸≥2 전투 내내"
            .. "\n장착 시 빈칸당 피해+12% · 최대36%"
            .. "\nW03–14 생존 완료 · 이번 판 제외/다음 새 판 후보"
    end
    if depositUnlocked then
        return table.concat(names, "/") .. " 해금 완료 · 이번 판 제외"
            .. "\nW03–W14 일반 생존 완료 · 보상 전 20G 이상"
            .. "\n장착 정산 전 5G당 +1G · 최대 4G · 다음 새 판 후보"
    end
    return table.concat(names, "/") .. " 해금 완료\n이번 판 제외 · 다음 새 판부터 후보"
end

function View:_drawTowerUnlocks(state, x, y)
    local tabs = {
        { "tower", "포탑", 0, 24 }, { "deposit", "예치금", 25, 34 },
        { "spare", "여유", 60, 24 }, { "emergency", "비상", 85, 24 },
        { "midlink", "중가", 110, 24 }, { "assetlink", "자산", 135, 24 },
        { "mixed", "혼합", 160, 24 }, { "maintenance", "고급", 185, 24 },
        { "balanced", "균등", 210, 24 }, { "shared", "공용", 235, 24 },
        { "reserve", "예비", 0, 22 },
    }
    local tabX = 0
    for _, tab in ipairs(tabs) do
        tab[3], tab[4] = tabX, tab[1] == "deposit" and 32 or 22
        tabX = tabX + tab[4]
        self:_button(x + tab[3], y, tab[4], 20, tab[2], { type = "unlock_lookup_tab", tab = tab[1] }, true,
            self.unlockLookupTab == tab[1], 9)
    end
    y = y + 25
    if self.unlockLookupTab == "reserve" then
        local status = state.moduleUnlockById.M31
        local lines = {
            { "permanent", 0, "M31 예비 보급 · 중가12G · 슬롯1 · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "condition", 14, "해금: W09–14 일반 생존 완료\n미배치 서로 다른2종 이상을 전투 내내 유지" },
            { "effect", 40, "장착: 일반 정산 미배치 종류당+1G · 최대3G" },
            { "attempt", 54, status.observationError and "예비 기록 확인 불가 · 완료 인정 불가" or string.format("현재 미배치%d종 · 배치로1종이 되면 제외", status.reserveTypeCount or 0) },
            { "pool", 80, status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨" or "이번 판 후보 제외 · 다음 성공 새 판 후보" },
            { "offer", 94, status.isCurrentOffer and "현재 제안 있음 · 무료 지급/등장 보장 없음" or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", 108, "동종 여러 기는1종 · 판매/패배 후 권리 유지" },
        }
        for _, line in ipairs(lines) do self:_text(line[3], x+6, y+line[2], 248, "left", 8, C.cream).role = "module_unlock_M31_" .. line[1] end
        return
    end
    if self.unlockLookupTab == "shared" then
        local status = state.moduleUnlockById.M16
        local attempt = status.observationError and "배치 ID 확인 불가 · 완료 인정 불가"
            or string.format("현재 배치%d기 · ID%d종 · 새 W09–14 완료 필요", status.placedTowerCount or 0, status.distinctPatchCount or 0)
        local lines = {
            { "permanent", 0, 9, "M16 공용 설계 · 고가16G · 슬롯1 · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "condition", 14, 8, "해금: W09–14 일반 생존 · 전투내내 배치ID≥5\n중복1종/예비 제외 · 늦은5종 실패" },
            { "effect", 38, 8, "장착: 배치ID당 모듈피해+3%p · 최대27%p" },
            { "attempt", 51, 8, attempt },
            { "ids", 63, 8, "배치 패치: " .. (status.observationError and "확인 불가" or patchIdsText(status.distinctPatchIds)) },
            { "pool", 86, 8, status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨" or "이번 판 후보 제외 · 다음 성공 새 판 후보" },
            { "offer", 99, 8, status.isCurrentOffer and "현재 제안 있음 · 무료 지급/등장 보장 없음" or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", 112, 8, "패치 불이익 유지 · 판매/패배 후 권리 유지" },
        }
        for _, line in ipairs(lines) do
            self:_text(line[4], x+6, y+line[2], 248, "left", line[3], C.cream).role = "module_unlock_M16_" .. line[1]
        end
        return
    end
    if self.unlockLookupTab == "balanced" then
        local status = state.moduleUnlockById.M12
        local attempt = status.observationError and "시작 조건 확인 불가 · 완료 인정 불가"
            or string.format("현재 배치%d기 · %s · 새 W06–14 완료 필요", status.placedTowerCount or 0,
                status.allPlacedPositiveAndEqual and string.format("패치%d개씩", status.commonPatchCount) or "균등 양수 아님")
        local lines = {
            { "permanent", 0, 9, "M12 균등 투자 · 중가12G · 슬롯1 · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "condition", 14, 8, "해금: W06–14 일반 생존 완료 · 배치3기 이상\n모두 같은 패치 개수≥1 · 전투 내내 유지\n동일 패치ID 가능 · 무패치 후기 배치 실패" },
            { "effect", 49, 8, "장착: 배치2기 이상 · 모두 같은 패치 개수≥1\n배치 타워 사거리+25% · 기존 패치/모듈 합산" },
            { "attempt", 73, 8, attempt },
            { "pool", 86, 8, status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨" or "이번 판 후보 제외 · 다음 성공 새 판 후보" },
            { "offer", 99, 8, status.isCurrentOffer and "현재 제안 있음 · 무료 지급/등장 보장 없음" or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", 112, 8, "판매/패배 후 권리 유지 · 새 판 재추첨" },
        }
        for _, line in ipairs(lines) do
            self:_text(line[4], x+6, y+line[2], 248, "left", line[3], C.cream).role = "module_unlock_M12_" .. line[1]
        end
        return
    end
    if self.unlockLookupTab == "maintenance" then
        local status = state.moduleUnlockById.M14
        local attempt = status.observationError and "시작 조건 확인 불가 · 완료 인정 불가"
            or string.format("현재 충족 타워%d기 · 새 W09–14 생존 완료 필요", status.qualifyingTowerCount or 0)
        local lines = {
            { "permanent", 0, 9, "M14 고급 정비 · 중가12G · 슬롯1 · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "condition", 14, 8, "해금: W09–14 일반 생존 완료 · 같은 타워1기\n정가합≥21G(7×3 가능) · 시작부터 완료직전 배치\n늦은배치·패배·미완료·보스·중복 제외" },
            { "effect", 49, 8, "장착: 배치 타워별 고가 패치당 피해+8%p\n모듈 피해 합산 · 중복 각각 · 해금 고가 불필요" },
            { "attempt", 73, 8, attempt },
            { "pool", 86, 8, status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨" or "이번 판 후보 제외 · 다음 성공 새 판 후보" },
            { "offer", 99, 8, status.isCurrentOffer and "현재 제안 있음 · 무료 지급/등장 보장 없음" or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", 112, 8, "판매/패배 후 권리 유지 · 새 판 재추첨" },
        }
        for _, line in ipairs(lines) do
            self:_text(line[4], x + 6, y + line[2], 248, "left", line[3], C.cream).role = "module_unlock_M14_" .. line[1]
        end
        return
    end
    if self.unlockLookupTab == "mixed" then
        local status = state.moduleUnlockById.M15
        local attempt = status.observationError and "시작 조건 확인 불가 · 완료 인정 불가"
            or string.format("현재 충족 타워%d기 · 새 W06–14 생존 완료 필요", status.qualifyingTowerCount or 0)
        local lines = {
            { "permanent", 0, 9, "M15 혼합 개조 · 중가12G · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "condition", 14, 8, "해금: W06–14 일반 생존 완료 · 같은 타워1기\n서로 다른 패치3종 · 시작부터 완료직전 배치\n늦은배치·패배·미완료·보스·중복 제외" },
            { "effect", 49, 8, "장착: 서로 다른 패치3종인 배치 타워만\n기존 모듈 속도 합산+20%p · 중복패치 제외" },
            { "attempt", 73, 8, attempt },
            { "pool", 86, 8, status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨" or "이번 판 후보 제외 · 다음 성공 새 판 후보" },
            { "offer", 99, 8, status.isCurrentOffer and "현재 제안 있음 · 무료 지급/등장 보장 없음" or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", 112, 8, "판매/패배 후 권리 유지 · 새 판 재추첨" },
        }
        for _, line in ipairs(lines) do
            self:_text(line[4], x + 6, y + line[2], 248, "left", line[3], C.cream).role = "module_unlock_M15_" .. line[1]
        end
        return
    end
    if self.unlockLookupTab == "assetlink" then
        local status = state.moduleUnlockById.M42
        local amount = status.installedPaidGold
        local attempt = amount and string.format("현재 실지불합%d/40G · W09–14 완료 필요", amount)
            or "현재 지불 기록 확인 불가 · 완료 인정 불가"
        local lines = {
            { "permanent", 0, 9, "M42 자산 연동 · 고가16G · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "condition", 14, 8, "해금: W09–14 일반 생존 완료\n장착 실지불합≥40G · 시작부터 완료직전 유지\nW01–08·W15·패배·미완료·중복 제외" },
            { "effect", 49, 8, "자신 제외 장착 지불4G당 배치 피해+2%p\n내림·최대30%p · 판매가/리롤/타워/패치 제외" },
            { "attempt", 73, 8, attempt },
            { "pool", 86, 8, status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨" or "이번 판 후보 제외 · 다음 성공 새 판 후보" },
            { "offer", 99, 8, status.isCurrentOffer and "현재 제안 있음 · 무료 지급/등장 보장 없음" or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", 112, 8, "판매/패배 후 권리 유지 · 새 판 재추첨" },
        }
        for _, line in ipairs(lines) do
            self:_text(line[4], x + 6, y + line[2], 248, "left", line[3], C.cream).role = "module_unlock_M42_" .. line[1]
        end
        return
    end
    if self.unlockLookupTab == "midlink" then
        local status = state.moduleUnlockById.M41
        local attempt = status.currentAttemptQualifies and "구성 충족 · 완료 필요" or "2종 장착 필요"
        local lines = {
            { "permanent", 0, 9, "M41 중가 연동 · 고가16G · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "condition", 14, 8, "해금: W06–14 일반 생존 완료\n서로 다른 중가≥2종 · 시작부터 완료직전 유지\nW01–05·W15·패배·미완료·중복 제외" },
            { "effect", 49, 8, "자신 제외 중가당 배치 피해+8%p(최대32%)\n타 효과 복사/곱연산·영구스탯 변경 없음" },
            { "attempt", 73, 8, string.format("현재 중가%d종 · %s", status.installedMidModuleCount or 0, attempt) },
            { "pool", 86, 8, status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨" or "이번 판 후보 제외 · 다음 새 판부터" },
            { "offer", 99, 8, status.isCurrentOffer and (state.phase == "RESULT" and "이번 판 제안에 있음 · 새 판은 별도 추첨" or "현재 제안 있음 · 상점에서 선택") or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", 112, 8, "판매/패배 후 권리 유지 · 새 판 재추첨" },
        }
        for _, line in ipairs(lines) do
            self:_text(line[4], x + 6, y + line[2], 248, "left", line[3], C.cream).role = "module_unlock_M41_" .. line[1]
        end
        return
    end
    if self.unlockLookupTab == "emergency" then
        local status = state.moduleUnlockById.M46
        local lines = {
            { "permanent", "M46 비상 출력 · 중급 12G · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "effect", "장착: 현재HP1–5 배치 타워 피해+40%" },
            { "condition", "해금: W03–W14 일반 생존 완료\n시작HP1–5·이번 누수0 또는 W09+완료HP20" },
            { "attempt", "W01/02·W15·패배·미완료·중복 제외" },
            { "pool", status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨"
                or "이번 판 후보 제외 · 해금 후 다음 새 판부터" },
            { "offer", status.isCurrentOffer and "현재 상점 제안에 있음 · 상점에서 선택"
                or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", "판매/패배 후 권리 유지 · 회복/패배 방지 없음" },
        }
        local rowY = y
        for _, line in ipairs(lines) do
            self:_text(line[2], x + 6, rowY, 248, "left", 9, C.cream).role = "module_unlock_M46_" .. line[1]
            rowY = rowY + (line[1] == "condition" and 27 or 15)
        end
        return
    end
    if self.unlockLookupTab == "spare" then
        local status = state.moduleUnlockById.M43
        local attempt = status.currentAttemptQualifies and "조건 충족·완료 필요"
            or (status.installedModuleCount == 0 and "장착1개 이상 필요" or "빈칸2개 이상 필요")
        local lines = {
            { "permanent", "M43 여유 회로 · 중급 12G · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "effect", "장착 효과: 빈칸당 피해 +12% · 최대 +36%" },
            { "condition", "해금: W03–W14 일반 생존 완료\n장착≥1·빈칸≥2를 전투 내내 유지" },
            { "attempt", string.format("장착%d · 실제 빈칸%d/%d · %s", status.installedModuleCount,
                status.emptySlots, status.moduleCapacity, attempt) },
            { "pool", status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨"
                or "이번 판 후보 제외 · 해금 후 다음 새 판부터" },
            { "offer", status.isCurrentOffer and "현재 상점 제안에 있음 · 상점에서 선택"
                or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", "판매/패배 후 영구 해금 유지 · 새 판 재추첨" },
        }
        local rowY = y
        for _, line in ipairs(lines) do
            self:_text(line[2], x + 6, rowY, 248, "left", 9, C.cream).role = "module_unlock_M43_" .. line[1]
            rowY = rowY + (line[1] == "condition" and 27 or 15)
        end
        return
    end
    if self.unlockLookupTab == "deposit" then
        local status = state.moduleUnlockById.M28
        local lines = {
            { "permanent", "M28 예치금 · 중급 12G · " .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김") },
            { "effect", "효과: 정산 전 5G당 +1G · 최대 +4G" },
            { "condition", "해금: W03–W14 일반 생존 완료\n보상 전 20G 이상 · W15 제외" },
            { "attempt", "현재 20G 이상이어도 유효 완료가 필요" },
            { "pool", status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨"
                or "이번 판 후보 제외 · 해금 후 다음 새 판부터" },
            { "offer", status.isCurrentOffer and "현재 상점 제안에 있음 · 상점에서 선택"
                or "현재 제안 없음 · 무료 지급/등장 보장 없음" },
            { "next_run", "판매/패배 후 영구 해금 유지 · 새 판 재추첨" },
        }
        local rowY = y
        for _, line in ipairs(lines) do
            self:_text(line[2], x + 6, rowY, 248, "left", 9, C.cream).role = "module_unlock_M28_" .. line[1]
            rowY = rowY + (line[1] == "condition" and 27 or 15)
        end
        return
    end
    for index, status in ipairs(state.towerUnlocks or {}) do
        local rowY = y + (index - 1) * 63
        setColor(C.guide)
        love.graphics.rectangle("fill", x, rowY, 260, 59)
        local permanent = self:_text((status.name or displayName("tower", status.towerId)) .. " · "
            .. (status.permanentlyUnlocked and "영구 해금됨" or "영구 잠김"),
            x + 6, rowY + 3, 248, "left", 10, status.permanentlyUnlocked and C.mint or C.cream)
        permanent.role = "tower_unlock_" .. status.towerId .. "_permanent"
        local pool = self:_text(status.inCurrentRunPool and "이번 판 후보 포함 · 등장은 추첨"
            or "이번 판 후보 제외 · 해금 후 다음 새 판부터", x + 6, rowY + 18, 248, "left", 9, C.mustard)
        pool.role = "tower_unlock_" .. status.towerId .. "_pool"
        local condition = self:_text("조건: " .. tostring(status.condition), x + 6, rowY + 31, 248, "left", 9, C.paper)
        condition.role = "tower_unlock_" .. status.towerId .. "_condition"
        local offer = self:_text(status.isCurrentOffer and (state.phase == "RESULT"
            and "이번 판 제안에 있음 · 새 판은 별도 추첨"
            or "현재 상점 제안에 있음 · 상점에서 선택")
            or "현재 제안 없음 · 무료 지급/등장 보장 없음", x + 6, rowY + 44, 248, "left", 8, C.paper)
        offer.role = "tower_unlock_" .. status.towerId .. "_offer"
    end
end

function View:openInventoryManagement(tab)
    self.inventoryManagementOpen = true
    self.inventoryManagementTab = tab == "module" and "module" or "tower"
    if self.inventoryManagementTab ~= "module" then self.managedModuleId = nil end
    self.waveDetailIndex = nil
    return true
end

function View:closeInventoryManagement()
    if not self.inventoryManagementOpen then return false end
    self.inventoryManagementOpen = false
    self.inventoryManagementTab = "tower"
    self.managedModuleId = nil
    return true
end

function View:hasInventoryManagement()
    return self.inventoryManagementOpen == true
end

function View:selectManagedModule(moduleId)
    self.inventoryManagementOpen = true
    self.inventoryManagementTab = "module"
    self.managedModuleId = moduleId
    return true
end

function View:clearManagedModule()
    self.managedModuleId = nil
    return true
end

function View:openModuleStatus()
    self.moduleStatusOpen = true
    self.managedModuleId = nil
    self.waveDetailIndex = nil
    return true
end

function View:selectStatusModule(moduleId)
    self.moduleStatusOpen = true
    self.managedModuleId = moduleId
    return true
end

function View:closeModuleStatus()
    if not self.moduleStatusOpen then return false end
    if self.managedModuleId then
        self.managedModuleId = nil
        return true
    end
    self.moduleStatusOpen = false
    return true
end

function View:hasModuleStatus()
    return self.moduleStatusOpen == true
end

function View:inventoryPageInfo(state)
    local run = state and state.runState
    local towers = state and state.battle and state.battle.towerInstances or (run and run.towerInstances) or {}
    local pageCount = math.max(1, math.ceil(#towers / 6))
    self.inventoryPage = math.max(1, math.min(self.inventoryPage or 1, pageCount))
    return {
        page = self.inventoryPage,
        pageCount = pageCount,
        total = #towers,
        firstIndex = (self.inventoryPage - 1) * 6 + 1,
        lastIndex = math.min(#towers, self.inventoryPage * 6),
    }
end

function View:setInventoryPage(page, state)
    self.inventoryPage = math.max(1, math.floor(tonumber(page) or 1))
    if state then return self:inventoryPageInfo(state) end
    return { page = self.inventoryPage }
end

function View:waveSchedule(index)
    local wave = self.defs.wavesById[string.format("W%02d", tonumber(index) or -1)]
    if not wave then return nil, "unknown_wave" end
    local rows = {}
    for order, group in ipairs(wave.groups or {}) do
        rows[#rows + 1] = {
            order = order, groupId = group.groupId, entranceId = group.entranceId,
            enemyId = group.enemyId, enemyName = ENEMY_NAMES[group.enemyId] or group.enemyId,
            count = group.count, firstTick = group.firstTick, intervalTicks = group.intervalTicks,
            special = ENEMY_SPECIAL[group.enemyId],
        }
    end
    return { index = wave.index, waveId = wave.id, bossRequired = wave.bossRequired == true, rows = rows }
end

function View:_waveDetailAllowed(index, state)
    if not state or not state.runState then return false end
    local nextIndex = state.runState.nextWaveIndex or 1
    if state.phase == "SHOP" then return index >= nextIndex and index <= nextIndex + 2 end
    return state.phase == "PREPARE" and index == nextIndex
end

function View:setWaveDetail(index, state)
    index = tonumber(index)
    if not index or not self:waveSchedule(index) then return nil, "unknown_wave" end
    if state and not self:_waveDetailAllowed(index, state) then return nil, "wave_detail_unavailable" end
    self.waveDetailIndex = index
    return self:waveSchedule(index)
end

function View:clearWaveDetail()
    self.waveDetailIndex = nil
    return true
end

function View:hasWaveDetail()
    return self.waveDetailIndex ~= nil
end

function View:_activeWaveDetail(state)
    if not self.waveDetailIndex then return nil end
    if not self:_waveDetailAllowed(self.waveDetailIndex, state) then
        self.waveDetailIndex = nil
        return nil
    end
    return self:waveSchedule(self.waveDetailIndex)
end

function View:_waveSummary(index, detailed)
    local wave = self.defs.wavesById[string.format("W%02d", index)]
    if not wave then return nil end
    local total, counts, order = 0, {}, {}
    for _, group in ipairs(wave.groups or {}) do
        total = total + group.count
        if not counts[group.enemyId] then order[#order + 1] = group.enemyId; counts[group.enemyId] = 0 end
        counts[group.enemyId] = counts[group.enemyId] + group.count
    end
    local parts = {}
    for _, enemyId in ipairs(order) do
        parts[#parts + 1] = string.format("%s%d", ENEMY_NAMES[enemyId] or enemyId, counts[enemyId])
    end
    if detailed then
        return string.format("%s %d마리 · %s", wave.id, total, table.concat(parts, "/"))
    end
    return string.format("%s %d · %s", wave.id, total, table.concat(parts, "/"))
end

function View:_wavePreview(index)
    local schedule = self:waveSchedule(index)
    if not schedule then return nil end
    local total, names, seen, hasSpecial = 0, {}, {}, false
    for _, row in ipairs(schedule.rows) do
        total = total + row.count
        if not seen[row.enemyId] then names[#names + 1] = row.enemyName; seen[row.enemyId] = true end
        hasSpecial = hasSpecial or row.special ~= nil
    end
    return string.format("%s %d명 · %s%s", schedule.waveId, total, table.concat(names, "/"),
        hasSpecial and " ★" or "")
end

function View:_waveTotal(index)
    local wave = self.defs.wavesById[string.format("W%02d", index)]
    local total = 0
    for _, group in ipairs(wave and wave.groups or {}) do total = total + group.count end
    return total
end

function View:_drawMap(state)
    local run = state.runState
    local map = run and self.defs.mapsById[run.mapId or "M01"]
    if not map then return end
    setColor(C.cream)
    love.graphics.rectangle("fill", View.MAP_X, View.MAP_Y, map.width * View.CELL, map.height * View.CELL)
    setColor(C.paper)
    for y = 0, map.height do
        love.graphics.line(View.MAP_X, View.MAP_Y + y * View.CELL, View.MAP_X + map.width * View.CELL, View.MAP_Y + y * View.CELL)
    end
    for x = 0, map.width do
        love.graphics.line(View.MAP_X + x * View.CELL, View.MAP_Y, View.MAP_X + x * View.CELL, View.MAP_Y + map.height * View.CELL)
    end
    for routeIndex, route in ipairs(map.routes) do
        setColor(routeIndex == 1 and C.tomato or C.blue)
        love.graphics.setLineWidth(5)
        for index = 2, #route.points do
            local a, b = route.points[index - 1], route.points[index]
            love.graphics.line(View.MAP_X + a.x * View.CELL + View.CELL / 2,
                View.MAP_Y + a.y * View.CELL + View.CELL / 2,
                View.MAP_X + b.x * View.CELL + View.CELL / 2,
                View.MAP_Y + b.y * View.CELL + View.CELL / 2)
        end
    end
    love.graphics.setLineWidth(1)
    local towers = state.battle and state.battle.towerInstances or run.towerInstances
    local transaction, recallAction = self:_recallSelection(state)
    local eligible, chosen = {}, {}
    for _, instanceId in ipairs(transaction and transaction.eligibleRecallTowerIds or {}) do eligible[instanceId] = true end
    for _, instanceId in ipairs(transaction and transaction.selectedRecallTowerIds or {}) do chosen[instanceId] = true end
    for _, tower in ipairs(towers or {}) do
        if tower.placement then
            local cx = View.MAP_X + tower.placement.x * View.CELL + View.CELL / 2
            local cy = View.MAP_Y + tower.placement.y * View.CELL + View.CELL / 2
            setColor(chosen[tower.instanceId] and C.mustard
                or (tower.instanceId == state.selectedTowerId and C.mustard or C.mint))
            love.graphics.rectangle("fill", cx - 5, cy - 5, 10, 10)
            self:_text(tostring(tower.instanceId), cx - 5, cy - 6, 10, "center", 9, C.ink)
            if transaction and transaction.requiredRecallCount > 0 and eligible[tower.instanceId] then
                setColor(chosen[tower.instanceId] and C.white or C.red)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", cx - 6, cy - 6, 12, 12)
                love.graphics.setLineWidth(1)
                self:_hitArea(cx - 7, cy - 7, 14, 14,
                    { type = recallAction, instanceId = tower.instanceId,
                        selected = not chosen[tower.instanceId] }, true)
            elseif self.inventoryManagementOpen and state.phase == "SHOP" and not transaction then
                self:_hitArea(cx - 7, cy - 7, 14, 14,
                    { type = "select_tower", instanceId = tower.instanceId }, true)
            end
        end
    end
    for _, enemy in ipairs(state.battle and state.battle.enemies or {}) do
        setColor(C.red)
        love.graphics.circle("fill", View.MAP_X + enemy.x * View.CELL + View.CELL / 2,
            View.MAP_Y + enemy.y * View.CELL + View.CELL / 2, 3)
    end
end

function View:_selectedTower(state)
    local towers = state.battle and state.battle.towerInstances or (state.runState and state.runState.towerInstances) or {}
    for _, tower in ipairs(towers) do if tower.instanceId == state.selectedTowerId then return tower end end
    return nil
end

local function findTower(run, instanceId)
    for _, tower in ipairs(run and run.towerInstances or {}) do
        if tower.instanceId == instanceId then return tower end
    end
    return nil
end

local function moduleEntry(run, moduleId)
    for _, entry in ipairs(run and run.modules or {}) do
        local id = type(entry) == "table" and (entry.moduleId or entry.id) or entry
        if id == moduleId then return entry end
    end
    return nil
end

local function moduleIdOf(entry)
    return type(entry) == "table" and (entry.moduleId or entry.id) or entry
end

local function findEvent(events, eventType, moduleId)
    for _, event in ipairs(events or {}) do
        if event.type == eventType and (moduleId == nil or event.moduleId == moduleId) then return event end
    end
    return nil
end

local function instanceIdsText(ids)
    local values = {}
    for _, instanceId in ipairs(ids or {}) do values[#values + 1] = "#" .. tostring(instanceId) end
    return #values > 0 and table.concat(values, ",") or "없음"
end

patchIdsText = function(ids)
    local values = {}
    for _, patchId in ipairs(ids or {}) do values[#values + 1] = displayName("patch", patchId) end
    return #values > 0 and table.concat(values, "/") or "없음"
end

local function growthChangeText(growth)
    if not growth then return nil end
    local before, after, cap = growth.before or 0, growth.after or 0, growth.cap or 0
    if cap > 0 and before >= cap then return "성장 최대치" end
    return string.format("성장%d→%d", before, after)
end

function View:_moduleStatusLines(state, moduleId)
    local status = state.moduleStatusById and state.moduleStatusById[moduleId]
    if not status then return "현재 상태 정보 없음", nil end
    local selected = state.selectedTowerId
    local run = state.runState or {}
    local nextWave = run.nextWaveIndex or 1
    if moduleId == "M16" then
        if status.observationError then return "배치 ID 확인 불가 · 실제 기여0", "알려진 패치/개체 기록 확인 필요" end
        local aggregate = string.format("%s · 배치%d기/ID%d종 · 전체+%d%%p", status.installed and "장착" or "미장착",
            status.placedTowerCount, status.distinctPatchCount, status.aggregateBonusPercentPoints)
        local ids = "배치 패치: " .. patchIdsText(status.distinctPatchIds)
        if not status.selectedTowerInstanceId then return aggregate, "선택 타워 없음 · 실제 피해 확인 불가\n" .. ids end
        return aggregate, string.format("선택#%d %s · 피해%.2f/+%d%%p", status.selectedTowerInstanceId,
            status.selectedTowerPlaced and "배치" or "예비", status.selectedDamage or 0, status.bonusPercentPoints) .. "\n" .. ids
    elseif moduleId == "M12" then
        if status.observationError then return "조건 확인 불가 · 실제 기여0", "모든 배치 타워의 알려진 패치 개수 확인 필요" end
        local aggregate = string.format("%s · 배치%d기 · %s", status.installed and "장착" or "미장착", status.placedTowerCount,
            status.allPlacedPositiveAndEqual and string.format("패치%d개씩", status.commonPatchCount) or "균등 양수 아님")
        if not status.selectedTowerInstanceId then return aggregate, "선택 타워 없음 · 효과2기/해금3기 구분" end
        return aggregate, string.format("선택#%d 패치%d개 · %s · 사거리%.2f/+%d%%p", status.selectedTowerInstanceId,
            status.selectedPatchCount or 0, status.selectedTowerPlaced and "배치" or "미배치", status.selectedRange or 0, status.bonusPercentPoints)
    elseif moduleId == "M14" then
        if status.observationError then return "조건 확인 불가 · 실제 기여0", "정가/등급 기록 확인 필요" end
        local aggregate = string.format("%s · 고가패치 효과%d/배치%d기", status.installed and "장착" or "미장착",
            status.qualifyingTowerCount, status.placedTowerCount)
        if not status.selectedTowerInstanceId then return aggregate, "선택 타워 없음 · 기존 패치 중첩 유지" end
        return aggregate, string.format("선택#%d 고가%d개 · 정가합%dG · %s · 피해%.2f/+%d%%p", status.selectedTowerInstanceId,
            status.selectedHighGradePatchCount, status.selectedNominalPatchPrice or 0, status.selectedTowerPlaced and "배치" or "미배치",
            status.selectedDamage or 0, status.bonusPercentPoints)
    elseif moduleId == "M15" then
        if status.observationError then return "조건 확인 불가 · 실제 기여0", "기존 패치 중첩 효과 유지" end
        local aggregate = string.format("%s · 조건충족%d/배치%d기", status.installed and "장착" or "미장착",
            status.qualifyingTowerCount, status.placedTowerCount)
        if not status.selectedTowerInstanceId then return aggregate, "선택 타워 없음 · 기존 패치 중첩 유지" end
        return aggregate, string.format("선택#%d 패치%d종 · %s · 속도%.2f/+%d%%p", status.selectedTowerInstanceId,
            status.selectedDistinctPatchCount, status.selectedTowerPlaced and "배치" or "미배치",
            status.selectedAttackRate or 0, status.bonusPercentPoints)
    elseif moduleId == "M42" then
        if status.observationError then return "지불 기록 확인 불가 · 실제 기여0", "정가/환급으로 추정하지 않음" end
        return string.format("다른 장착 실지불%dG · 배치 피해+%d%%p/%d%%p", status.otherModulePaidGold or 0,
            status.bonusPercentPoints or 0, status.cap or 30),
            (status.placedTowerCount or 0) == 0 and "현재 배치 없음 · 실제 기여0" or "자신 제외 · 기록값 내림 · 배치 타워만 적용"
    elseif moduleId == "M41" then
        return string.format("자신 제외 중가%d종 · 배치 피해+%d%%p/%d%%p", status.otherMidModuleCount or 0,
            status.bonusPercentPoints or 0, status.cap or 32),
            (status.placedTowerCount or 0) == 0 and "현재 배치 없음 · 실제 기여0"
                or "배치 타워만 적용 · 자신/비중가 제외"
    elseif moduleId == "M03" then
        return string.format("현재 배치 종류 %d종 · 피해 +%d%%", status.distinctPlacedTypeCount or 0,
            status.bonusPercentPoints or 0)
    elseif moduleId == "M04" then
        return string.format("현재 배치 종류 %d종 · 정확히 1종일 때 적용", status.distinctPlacedTypeCount or 0)
    elseif moduleId == "M06" then
        return string.format("현재 타워 수용량 %d · 배치 타워 피해 +%d%%", status.towerCapacity or 0,
            status.bonusPercentPoints or 35)
    elseif moduleId == "M07" then
        local summary = string.format("동종 상하좌우 충족 %d/%d기", status.qualifyingTowerCount or 0,
            status.placedTowerCount or 0)
        if not selected then return summary, "타워 선택 시 같은 종류 이웃 상세" end
        local detail = status.selectedTowerQualifies
            and string.format("선택 #%d · 이웃 %s", selected, instanceIdsText(status.sameTypeCardinalNeighborIds))
            or string.format("선택 #%d · 조건 미충족", selected)
        return summary, detail
    elseif moduleId == "M08" then
        return string.format("현재 배치 종류 %d종 · 정확히 2종일 때 적용", status.distinctPlacedTypeCount or 0)
    elseif moduleId == "M09" then
        local summary = string.format("패치 3개 충족 %d/%d기", status.qualifyingTowerCount or 0,
            status.placedTowerCount or 0)
        if not selected then return summary, "타워 선택 시 패치 수 상세" end
        return summary, string.format("선택 #%d · 패치 %d/3 · %s", selected, status.patchCount or 0,
            status.selectedTowerQualifies and "적용" or "미적용")
    elseif moduleId == "M10" then
        local summary = string.format("패치 0개 충족 %d/%d기", status.qualifyingTowerCount or 0,
            status.placedTowerCount or 0)
        if not selected then return summary, "타워 선택 시 패치 수 상세" end
        return summary, string.format("선택 #%d · 패치 %d개 · %s", selected, status.patchCount or 0,
            status.selectedTowerQualifies and "적용" or "미적용")
    elseif moduleId == "M11" then
        local summary = string.format("공유 패치 충족 %d/%d기", status.qualifyingTowerCount or 0,
            status.placedTowerCount or 0)
        if not selected then return summary, "타워 선택 시 공유 패치/상대 상세" end
        if not status.selectedTowerQualifies then return summary, string.format("선택 #%d · 공유 없음", selected) end
        return summary, string.format("선택 #%d · %s · 상대 %s", selected,
            patchIdsText(status.sharedPatchIds), instanceIdsText(status.sharedWithTowerIds))
    elseif moduleId == "M13" then
        local summary
        if status.patchLeadState == "sole_highest" then
            summary = string.format("단독 최다 #%d · 패치 %d개", status.soleHighestTowerId,
                status.soleHighestPatchCount or 0)
        elseif status.patchLeadState == "tie" then
            summary = string.format("최다 %d개 동률 · %s", status.highestPatchCount or 0,
                instanceIdsText(status.highestPatchTowerIds))
        else
            summary = string.format("배치 %d기 · 패치 보유 대상 없음", status.placedTowerCount or 0)
        end
        if not selected then return summary, "타워 선택 시 대상 여부 상세" end
        return summary, string.format("선택 #%d · 패치 %d개 · %s", selected, status.patchCount or 0,
            status.selectedTowerQualifies and "단독 최다" or "대상 아님")
    elseif moduleId == "M18" then
        if state.phase == "COMBAT" then
            return string.format("적별 조건 충족 %d/%d · 다음 피격만 +25%%",
                status.qualifiedEnemyCount or 0, status.activeEnemyCount or 0), "전역 DPS가 아닌 적별 최근 2초 이력"
        end
        return "적마다 최근 2초 피격 종류를 전투 중 판정", "준비 화면의 보장 DPS에는 합산하지 않음"
    elseif moduleId == "M31" then
        return string.format("미배치 서로 다른%d종 · 정산 예상+%dG/최대3G", status.reserveTypeCount or 0, status.estimatedGold or 0),
            status.observationError and "예비 기록 확인 불가 · 기여0" or status.ordinarySettlement
                and "일반 생존 완료 시 현재 예비 기준 · 판매하면0" or "W15/결과는 일반 정산 없음 · 권리 유지"
    elseif moduleId == "M28" then
        return string.format("정산 전 기준 현재 %dG · 이자 예상 +%dG / 최대 4G",
            status.preRewardGold or 0, status.estimatedGold or 0),
            status.ordinarySettlement and "일반 생존 완료 시 지급 · 판매하면 이자 0"
                or "W15/결과는 일반 정산 없음 · 영구 해금 유지"
    elseif moduleId == "M43" then
        return string.format("슬롯 %d/%d · 빈칸 %d · 피해 +%d%%/36%%",
            status.installedModuleCount or 0, status.moduleCapacity or 4,
            status.emptySlots or 0, status.bonusPercentPoints or 0),
            status.installed and "자신도 슬롯1개 사용 · 배치 타워에 적용" or "미장착 효과0 · 자신도 슬롯1개 사용"
    elseif moduleId == "M46" then
        return string.format("현재 HP%d · 조건1–5 · %s · 피해+%d%%", status.currentHp or 0,
            status.active and "활성" or "비활성", status.bonusPercentPoints or 0),
            string.format("배치%d기만 적용 · 미장착/미배치0 · 회복/패배 방지 없음", status.placedTowerCount or 0)
    elseif moduleId == "M29" then
        local paid = status.nextPatchPaidGold
        local receipt = paid and string.format("다음 패치 정가 %dG · 환급 %dG · 실지출 %dG", paid,
            status.nextPatchRefundGold or 0, status.nextPatchNetGold or paid) or "현재 패치 상품 없음"
        return string.format("이번 방문 환급 %d/2 사용 · %d회 남음", status.refundUseCount or 0,
            status.refundRemaining or 0), receipt
    elseif moduleId == "M30" then
        return string.format("리롤 명목 %dG · 할인 %dG · 실지불 %dG", status.nominalGold or 0,
            status.discountGold or 0, status.paidGold or 0),
            status.firstRerollDone and "이번 방문 첫 성공 리롤 사용 완료" or "이번 방문 첫 성공에 할인 적용"
    elseif moduleId == "M32" then
        if nextWave >= 15 then
            return string.format("수용량 %d · 배치 %d · 빈칸 %d", status.towerCapacity or 0,
                status.placedTowerCount or 0, status.emptySlots or 0), "W15 최종전은 일반 정산 없음"
        end
        return string.format("수용량 %d · 배치 %d · 빈칸 %d", status.towerCapacity or 0,
            status.placedTowerCount or 0, status.emptySlots or 0),
            string.format("다음 생존 정산 기여 예상 +%dG", status.estimatedGold or 0)
    elseif moduleId == "M33" or moduleId == "M34" or moduleId == "M37" then
        local current, nextValue, cap = status.growth or 0, status.nextGrowth or 0, status.cap or 0
        local atCap = cap > 0 and current >= cap
        if moduleId == "M37" and nextWave >= 15 then
            return string.format("현재 피해 성장 %d/%d%%p%s", current, cap, atCap and " · 최대치" or ""),
                "W15 승패는 성장 없음 · 판매/새 판에서 소멸"
        end
        local cause = moduleId == "M33" and "다음 성공 리롤" or moduleId == "M34" and "다음 성공 패치" or "다음 생존 완료"
        return atCap and string.format("현재 %d/%d%%p · 최대치", current, cap)
            or string.format("현재 %d/%d%%p · %s %d%%p", current, cap, cause, nextValue),
            "판매 또는 새 판에서 성장 소멸"
    elseif moduleId == "M44" then
        return string.format("현재 골드 %d/%dG · 조건 %s", status.currentGold or 0, status.threshold or 20,
            (status.currentGold or 0) >= (status.threshold or 20) and "충족" or "미충족")
    elseif moduleId == "M45" then
        return string.format("현재 골드 %dG · %dG 이하 조건 %s", status.currentGold or 0, status.threshold or 3,
            (status.currentGold or 0) <= (status.threshold or 3) and "충족" or "미충족")
    end
    return status.installed and "장착 중 · 효과 조건은 전투/배치 상태에 따라 적용" or "구매하면 장착 효과가 적용됩니다.", nil
end

function View:_receiptLine(state)
    local receipt = state.lastReceipt
    if not receipt then return nil end
    local growth = findEvent(state.lastEvents, "module_growth_changed")
    local suffix = growth and string.format(" · 성장 %d→%d", growth.before or 0, growth.after or 0) or ""
    if receipt.kind == "patch" then
        local use = findEvent(state.lastEvents, "module_refund_applied", "M29")
        return string.format("최근 패치 정가%d/환급%d/실지출%dG%s%s", receipt.paidGold or receipt.gold or 0,
            receipt.refundGold or 0, receipt.netGold or receipt.paidGold or 0,
            use and string.format(" · 환급%d/2", use.useCount or 0) or "", suffix)
    elseif receipt.kind == "reroll" then
        return string.format("최근 리롤 명목%d/할인%d/지불%dG%s", receipt.nominalGold or 0,
            receipt.discountGold or 0, receipt.paidGold or 0, suffix)
    elseif receipt.kind == "module" then
        return string.format("최근 모듈 구매 %dG", receipt.paidGold or receipt.gold or 0)
    elseif receipt.kind == "settlement" and receipt.reward then
        return string.format("최근 정산+%dG · 전%dG · 이자+%d/예비+%dG%s", receipt.reward.total or 0,
            receipt.reward.preRewardGold or 0, receipt.reward.moduleById.M28 or 0, receipt.reward.moduleById.M31 or 0, suffix)
    end
    return nil
end

function View:_recallSelection(state)
    local draft = state.transactionDraft
    if draft and (draft.requiredRecallCount or 0) > 0 then return draft, "toggle_inventory_recall" end
    draft = state.purchaseDraft
    if draft and draft.kind == "module" and (draft.requiredRecallCount or 0) > 0 then
        return draft, "toggle_purchase_recall"
    end
    return nil, nil
end

function View:_modulePaidGold(run, moduleId)
    local entry = moduleEntry(run, moduleId)
    local def = self.defs.modulesById[moduleId]
    return type(entry) == "table" and entry.paidGold or (def and def.price or 0)
end

function View:_syncSelectedTowerPage(state)
    local selectedId = state.selectedTowerId
    if self.selectionObserved and selectedId == self.lastObservedSelectedTowerId then return end
    self.selectionObserved = true
    self.lastObservedSelectedTowerId = selectedId
    if not selectedId then return end
    local towers = state.battle and state.battle.towerInstances
        or (state.runState and state.runState.towerInstances) or {}
    for index, tower in ipairs(towers) do
        if tower.instanceId == selectedId then
            self.inventoryPage = math.ceil(index / 6)
            return
        end
    end
end

function View:_drawInventory(state)
    local run = state.runState
    local towers = state.battle and state.battle.towerInstances or (run and run.towerInstances) or {}
    self:_syncSelectedTowerPage(state)
    local selected = self:_selectedTower(state)
    local transaction, recallAction = self:_recallSelection(state)
    local eligible, chosen = {}, {}
    for _, instanceId in ipairs(transaction and transaction.eligibleRecallTowerIds or {}) do eligible[instanceId] = true end
    for _, instanceId in ipairs(transaction and transaction.selectedRecallTowerIds or {}) do chosen[instanceId] = true end
    local guide
    if transaction and transaction.requiredRecallCount > 0 then
        guide = string.format("%s회수 %d/%d · 패치 보존",
            state.purchaseDraft == transaction and "구매" or "판매",
            #(transaction.selectedRecallTowerIds or {}), transaction.requiredRecallCount)
    elseif selected then
        guide = selected.placement and string.format("#%d 선택 · 배치됨 (%s)", selected.instanceId,
            state.phase == "COMBAT" and "전투 중 이동 불가" or "준비 중 이동 가능")
            or string.format("#%d 선택 · 밝은 빈칸을 클릭하세요", selected.instanceId)
    elseif run and run.shopState and run.shopState.visitId == "S00" and (run.nextWaveIndex or 1) == 1 then
        guide = "① 무료 타워 → ② 빈칸 배치"
    else
        guide = "보유 타워 선택 · 빈칸 배치"
    end
    local guideText = self:_text(guide, 8, 160, 182, "left", 10, selected and C.mustard or C.cream)
    guideText.role = "inventory_guide"
    local page = self:inventoryPageInfo(state)
    local interactive = state.phase ~= "RESULT" and state.phase ~= "SAVE_ERROR"
    local x, y = 8, 176
    for index = page.firstIndex, page.lastIndex do
        local tower = towers[index]
        local action = { type = "select_tower", instanceId = tower.instanceId }
        local enabled = interactive and not transaction
        local selectedRow = tower.instanceId == state.selectedTowerId
        if transaction and transaction.requiredRecallCount > 0 and eligible[tower.instanceId] then
            action = { type = recallAction, instanceId = tower.instanceId,
                selected = not chosen[tower.instanceId] }
            enabled = true
            selectedRow = chosen[tower.instanceId] == true
        end
        self:_button(x, y, 87, 18, string.format("#%d %s", tower.instanceId, TOWER_NAMES[tower.typeId] or tower.typeId),
            action, enabled, selectedRow)
        x = x + 91
        if x > 100 then x, y = 8, y + 21 end
    end
    self:_button(8, 240, 45, 20, "이전", { type = "inventory_page", kind = "previous", page = page.page - 1 }, interactive and page.page > 1)
    self:_text(string.format("%d/%d · 총%d기", page.page, page.pageCount, page.total), 56, 244, 83, "center", 9, C.paper)
    self:_button(142, 240, 48, 20, "다음", { type = "inventory_page", kind = "next", page = page.page + 1 }, interactive and page.page < page.pageCount)
end

function View:_primaryGuide(state)
    local run, phase = state.runState, state.phase
    if self.towerUnlocksOpen and phase ~= "SAVE_ERROR" then
        return "해금 조회 · 영구 상태와 이번 판 후보\n닫기 / Esc / 우클릭으로 돌아갑니다."
    end
    local unlockFeedback = self:_newTowerUnlockFeedback(state)
    if phase == "PREPARE" and unlockFeedback then return unlockFeedback end
    if phase == "SHOP" then
        local trade = state.purchaseDraft or state.transactionDraft
        if trade and trade.sharedTrade then return self:_sharedTradeGuide(state) end
        if trade and self:_hasBalancedDraft(state, trade) then return self:_balancedTradeGuide(state) end
        if trade and self:_hasMaintenanceDraft(state, trade) then return self:_maintenanceTradeGuide(state) end
        if state.purchaseDraft and (state.purchaseDraft.requiredRecallCount or 0) > 0 then
            local draft = state.purchaseDraft
            return string.format("압축 제어 구매 회수 선택 %d/%d\n개체와 부착 패치는 그대로 보존됩니다.",
                #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount)
        end
        if state.transactionDraft then
            local draft = state.transactionDraft
            if (draft.requiredRecallCount or 0) > 0 then
                return string.format("판매 전 회수할 배치 포탑 선택 %d/%d\n정확한 수를 고른 뒤 판매를 확인하세요.",
                    #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount)
            end
            return "실지불·환급·손실을 확인하세요.\n저장 성공 전에는 보유 상태가 바뀌지 않습니다."
        end
        if self.inventoryManagementOpen then
            return "보유 포탑·모듈을 관리합니다.\n판매는 확인, 배치 포탑 회수는 무료입니다."
        end
        if #(state.newModuleUnlocks or {}) > 0 and not state.purchaseDraft and unlockFeedback then
            return unlockFeedback
        end
        if not (run.shopState and run.shopState.visitId == "S00" and (run.nextWaveIndex or 1) == 1) then
            local last = math.min((run.nextWaveIndex or 1) + 2,
                self.defs.capabilities and self.defs.capabilities.waveRange.last or #self.defs.waves)
            return string.format("%s · 다음 W%02d-W%02d 확인\n거래 후 상점을 접고 준비하세요.",
                run.shopState and run.shopState.visitId or "상점", run.nextWaveIndex or 1, last)
        end
        local placed, total = 0, #(run and run.towerInstances or {})
        for _, tower in ipairs(run and run.towerInstances or {}) do if tower.placement then placed = placed + 1 end end
        if placed == 0 then return "먼저 무료 기본 포탑을 골라\n지도 밝은 빈칸에 배치하세요." end
        if placed < math.min(2, total) then return "첫 포탑 배치 완료!\n두 번째 무료 포탑도 배치해 보세요." end
        return "무료 포탑 배치 완료.\n상점을 접고 전투를 준비하세요."
    elseif phase == "PREPARE" then
        local index = run and run.nextWaveIndex or 1
        return string.format("다음 W%02d 정보를 확인하고\n[W%02d 시작]을 누르세요.", index, index)
    elseif phase == "COMBAT" then
        if state.paused then return "전투가 멈췄습니다.\n[명시적으로 재개]해야 움직입니다." end
        return "전투 진행 중 · 1배/2배 전환 가능\n미배치 타워만 새로 놓을 수 있습니다."
    elseif phase == "SAVE_ERROR" then
        if state.safeExitDraft then
            return "미저장 변경 유실 가능\n종료를 확인하거나 취소하세요."
        end
        return "저장에 실패했습니다.\n재시도하거나 안전 종료를 선택하세요."
    elseif phase == "RESULT" then
        local result = run and run.result
        return result and result.kind == "victory"
            and "최종 보스 처치 · 승리 저장 완료\n새 판은 확인 후 시작합니다."
            or "방어 실패 결과 저장 완료\n새 판은 확인 후 시작합니다."
    end
    return ""
end

function View:_offerLabel(kind, id)
    if not id then return "품절" end
    local defs = kind == "tower" and self.defs.towersById or kind == "patch" and self.defs.patchesById or self.defs.modulesById
    return string.format("%s %dG", displayName(kind, id), defs[id] and defs[id].price or 0)
end

function View:_drawSpareCircuitProjection(draft, x, y, width)
    local before, after = draft.spareCircuitBefore, draft.spareCircuitAfter
    if type(before) ~= "table" or type(after) ~= "table"
        or not (before.installed == true or after.installed == true) then return end
    for _, status in ipairs({ before, after }) do
        if type(status.emptySlots) ~= "number" or status.emptySlots < 0 or status.emptySlots % 1 ~= 0
            or type(status.bonusPercentPoints) ~= "number" or status.bonusPercentPoints < 0
            or status.bonusPercentPoints > 36 or status.bonusPercentPoints % 1 ~= 0 then return end
    end
    self:_text(string.format("여유 빈%d→%d", before.emptySlots, after.emptySlots),
        x, y, width, "left", 7, C.mustard).role = "m43_draft_empty"
    self:_text(string.format("피해+%d→+%d%%", before.bonusPercentPoints, after.bonusPercentPoints),
        x, y + 10, width, "left", 7, C.mustard).role = "m43_draft_damage"
end

function View:_drawEmergencyProjection(draft, x, y, width)
    local before, after = draft.emergencyBefore, draft.emergencyAfter
    if type(before) ~= "table" or type(after) ~= "table" then return end
    self:_text(string.format("HP%d · 조건1~5 · %s→%s · 피해+%d→+%d%%", before.currentHp,
        before.active and "활성" or "비활성", after.active and "활성" or "비활성",
        before.bonusPercentPoints, after.bonusPercentPoints), x, y, width, "left", 8, C.mustard).role = "m46_draft_effect"
end

function View:_hasMidLinkDraft(draft)
    local id = draft.moduleId or draft.offerId
    if id == "M41" then return true end
    local def = self.defs.modulesById[id]
    local before, after = draft.midLinkBefore, draft.midLinkAfter
    return def and def.tier == "mid" and before and after and (before.installed or after.installed) or false
end

function View:_drawMidLinkProjection(draft, x, y)
    local before, after = draft.midLinkBefore, draft.midLinkAfter
    if not before or not after then
        self:_text("구매 확인 불가 · 현재 효과는 유지됩니다", x, y, 248, "left", 8, C.mustard).role = "m41_draft_effect"
        return
    end
    self:_text(string.format("연동 중가%d→%d종 · 배치 피해+%d→%d%%p", before.otherMidModuleCount,
        after.otherMidModuleCount, before.bonusPercentPoints, after.bonusPercentPoints),
        x, y, 248, "left", 8, C.mustard).role = "m41_draft_effect"
end

function View:_drawMidLinkPurchase(state, x, y)
    local draft = state.purchaseDraft
    self:_text(string.format("%s · %dG · 슬롯 %d→%d/%d", displayName("module", draft.offerId), draft.cost,
        draft.slotBefore, draft.slotAfter, draft.slotCapacity), x + 6, y + 1, 248, "left", 10, C.cream).role = "m41_draft_title"
    local effect = draft.offerId == "M46" and "HP1–5 배치 피해+40% · 회복/패배 방지 없음"
        or MODULE_EFFECTS[draft.offerId] or draft.effect
    self:_text(effect, x + 6, y + 15, 248, "left", 8, C.paper).role = "m41_draft_offer_effect"
    self:_drawMidLinkProjection(draft, x + 6, y + 27)
    local detail
    if draft.error then detail = PURCHASE_ERROR_TEXT[draft.error] or tostring(draft.error)
    elseif draft.offerId == "M46" then
        detail = string.format("현재HP%d · 비상+%d→%d%%", draft.emergencyBefore.currentHp,
            draft.emergencyBefore.bonusPercentPoints, draft.emergencyAfter.bonusPercentPoints)
    elseif draft.offerId == "M31" then
        detail = string.format("미배치%d종 · 예비%d→%dG/최대3G", draft.reserveAfter.reserveTypeCount or 0, draft.reserveBefore.estimatedGold, draft.reserveAfter.estimatedGold)
    elseif draft.offerId == "M28" then
        local status = state.moduleStatusById.M28
        detail = string.format("정산 전%dG · 이자0→%dG(최대4G)", status.preRewardGold, math.min(4, math.floor(status.preRewardGold / 5)))
    elseif draft.offerId == "M33" or draft.offerId == "M34" then
        local status = state.moduleStatusById[draft.offerId]
        detail = string.format("성장%d/%d%%p · 판매/새 판에서0", status.growth, status.cap)
    elseif draft.offerId == "M41" then detail = "자신·비중가 제외 · 배치 타워에만 적용"
    else detail = self:_moduleStatusLines(state, draft.offerId) end
    self:_text(detail, x + 6, y + 38, 248, "left", 8, draft.error and C.tomato or C.paper).role = "m41_draft_detail"
    self:_button(x + 6, y + 50, 92, 21, "구매 확인", { type = "confirm_purchase" }, draft.enabled)
    self:_button(x + 104, y + 50, 64, 21, "취소", { type = "cancel_purchase" }, true)
    self:_drawSpareCircuitProjection(draft, x + 174, y + 49, 80)
end

function View:_drawMidLinkSale(state, x, y)
    local draft = state.transactionDraft
    self:_text("모듈 판매 확인", x + 6, y + 5, 248, "left", 11, C.cream)
    local effect = displayName("module", draft.moduleId) .. " · " .. (MODULE_EFFECTS[draft.moduleId] or "")
    if draft.moduleId == "M46" then
        effect = string.format("비상 출력 · HP%d · HP1–5 배치 피해+40%%", draft.emergencyBefore.currentHp)
    elseif draft.moduleId == "M33" or draft.moduleId == "M34" then
        local status = state.moduleStatusById[draft.moduleId]
        effect = string.format("%s · 현재 성장%d/%d%%p\n%s", displayName("module", draft.moduleId),
            status.growth, status.cap, MODULE_EFFECTS[draft.moduleId])
    elseif draft.moduleId == "M31" then
        local status = state.moduleStatusById.M31
        effect = string.format("예비 보급 · 미배치%d종 · 예상+%d→0G", status.reserveTypeCount or 0, status.estimatedGold or 0)
    elseif draft.moduleId == "M28" then
        local status = state.moduleStatusById.M28
        effect = string.format("예치금 · 정산 전%dG · 현재 이자+%dG\n5G당+1G · 최대4G · 판매 뒤0", status.preRewardGold, status.estimatedGold)
    end
    self:_text(effect, x + 6, y + 22, 248, "left", 8, C.paper).role = "m41_sale_offer_effect"
    self:_text(string.format("실지불%dG · 환급%dG · 골드%d→%d", draft.paidGold, draft.refundGold,
        draft.goldBefore, draft.goldAfter), x + 6, y + 47, 248, "left", 8, C.cream)
    self:_drawMidLinkProjection(draft, x + 6, y + 60)
    self:_text("효과/성장 소멸 · 권리/획득 기록 유지 · 재획득 불가", x + 6, y + 73, 248, "left", 8, C.tomato).role = "m41_sale_history"
    self:_text(string.format("배치%d기 · 포탑 수용량%d→%d", draft.placedTowerCountAfter or draft.placedTowerCountBefore,
        draft.towerCapacityBefore, draft.towerCapacityAfter), x + 6, y + 86, 248, "left", 8, C.paper)
    self:_button(x + 6, y + 101, 104, 22, "판매 확인", { type = "confirm_inventory_transaction" }, draft.canCommit)
    self:_button(x + 116, y + 101, 72, 22, "전체 취소", { type = "cancel_inventory_transaction" }, true)
    self:_drawSpareCircuitProjection(draft, x + 194, y + 101, 60)
end

function View:_hasAssetLinkDraft(state, draft)
    local id = draft.moduleId or draft.offerId
    local current = state.moduleStatusById and state.moduleStatusById.M42
    return id == "M42" or current and current.installed
        or draft.assetLinkBefore and draft.assetLinkBefore.installed
        or draft.assetLinkAfter and draft.assetLinkAfter.installed or false
end

function View:_drawAssetLinkProjection(draft, x, y)
    local before, after = draft.assetLinkBefore, draft.assetLinkAfter
    if not before or not after or before.observationError or after.observationError then
        self:_text("지불 전후 확인 불가 · 현재 효과 유지", x, y, 248, "left", 8, C.mustard).role = "m42_draft_effect"
        return
    end
    self:_text(string.format("자산 지불%d→%dG · 배치 피해+%d→%d%%p", before.otherModulePaidGold,
        after.otherModulePaidGold, before.bonusPercentPoints, after.bonusPercentPoints),
        x, y, 248, "left", 8, C.mustard).role = "m42_draft_effect"
end

function View:_drawAssetSpareProjection(draft, x, y, width)
    local before, after = draft.spareCircuitBefore, draft.spareCircuitAfter
    if not before or not after or not (before.installed or after.installed)
        or before.emptySlots == after.emptySlots and before.bonusPercentPoints == after.bonusPercentPoints then return end
    self:_text(string.format("빈칸%d→%d", before.emptySlots, after.emptySlots), x, y, width, "left", 8, C.mustard).role = "m43_draft_empty"
    self:_text(string.format("피해+%d→%d%%", before.bonusPercentPoints, after.bonusPercentPoints), x, y + 12, width, "left", 8, C.mustard).role = "m43_draft_damage"
end

function View:_assetTradeEffect(state, id, sale)
    if id == "M46" then
        local status = state.moduleStatusById.M46
        return "HP1–5 배치 피해+40% · 회복/패배 방지 없음"
            .. (sale and string.format("\n현재HP%d · 비상+%d→0%%", status.currentHp, status.bonusPercentPoints) or "")
    end
    local effect = MODULE_EFFECTS[id] or "효과 정보 없음"
    local status = state.moduleStatusById[id]
    if sale and status and (id == "M33" or id == "M34" or id == "M37") then
        return string.format("%s · 성장%d/%d%%p\n%s", displayName("module", id), status.growth, status.cap, effect)
    end
    if sale and id == "M31" then
        return string.format("예비 보급 · 미배치%d종 · 예상+%d→0G", status.reserveTypeCount or 0, status.estimatedGold or 0)
    end
    if sale and id == "M28" then
        return string.format("예치금 · 5G당 이자+1G/최대4G\n정산 전%dG · 이자+%dG · 판매 뒤0", status.preRewardGold, status.estimatedGold)
    end
    return sale and (displayName("module", id) .. " · " .. effect) or effect
end

function View:_assetPurchaseDetail(state, draft)
    if draft.error and draft.error ~= "recall_selection_required" then
        return PURCHASE_ERROR_TEXT[draft.error] or tostring(draft.error)
    end
    local id = draft.offerId
    if id == "M31" then return string.format("미배치%d종 · 예비%d→%dG/최대3G", draft.reserveAfter.reserveTypeCount or 0,
        draft.reserveBefore.estimatedGold, draft.reserveAfter.estimatedGold) end
    if id == "M16" then return "중복ID1종 · 예비 제외 · 패치 불이익/기존 합산 유지" end
    if id == "M12" then return "모든 배치 양수 균등 · 효과2기/해금3기 · 기존 패치 유지" end
    if id == "M14" then return "해당 배치 타워만 · 고가 중복 각각 · 기존 패치 중첩 유지" end
    if id == "M15" then return "해당 타워만 · 기존 패치 중첩 유지" end
    if id == "M06" or id == "M05" or (draft.requiredRecallCount or 0) > 0 then
        return string.format("수용량%d→%d · 배치%d · 회수%d/%d · 개체/패치 유지",
            draft.towerCapacityBefore or 0, draft.towerCapacityAfter or 0, draft.placedTowerCountBefore or 0,
            #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount or 0)
    elseif id == "M46" then
        local before, after = draft.emergencyBefore, draft.emergencyAfter
        return string.format("현재HP%d · 비상 피해+%d→%d%%", before.currentHp, before.bonusPercentPoints, after.bonusPercentPoints)
    elseif id == "M28" then
        return string.format("정산 전%dG · 이자%d→%dG(최대4G)", draft.depositAfter.preRewardGold,
            draft.depositBefore.estimatedGold, draft.depositAfter.estimatedGold)
    elseif id == "M33" or id == "M34" or id == "M37" then
        local status = state.moduleStatusById[id]
        return string.format("성장%d/%d%%p · 판매/새 판에서0", status.growth, status.cap)
    end
    return "기록 실지불 기준 · 배치 타워만 · 자신 제외"
end

function View:_drawAssetLinkPurchase(state, x, y)
    local draft = state.purchaseDraft
    self:_text(string.format("%s · %dG · 슬롯%d→%d/%d", displayName("module", draft.offerId), draft.cost,
        draft.slotBefore, draft.slotAfter, draft.slotCapacity), x + 6, y + 1, 248, "left", 10, C.cream).role = "m42_draft_title"
    self:_text(self:_assetTradeEffect(state, draft.offerId, false), x + 6, y + 15, 248, "left", 8, C.paper).role = "m42_draft_offer_effect"
    local before, after = draft.midLinkBefore, draft.midLinkAfter
    if before and after and (before.installed or after.installed)
        and (before.otherMidModuleCount ~= after.otherMidModuleCount or before.bonusPercentPoints ~= after.bonusPercentPoints) then
        self:_drawMidLinkProjection(draft, x + 6, y + 27)
    end
    self:_drawAssetLinkProjection(draft, x + 6, y + 40)
    self:_text(self:_assetPurchaseDetail(state, draft), x + 6, y + 53, 248, "left", 8,
        draft.error and C.tomato or C.paper).role = "m42_draft_detail"
    self:_button(x + 6, y + 68, 92, 21, "구매 확인", { type = "confirm_purchase" }, draft.enabled)
    self:_button(x + 104, y + 68, 64, 21, "취소", { type = "cancel_purchase" }, true)
    self:_drawAssetSpareProjection(draft, x + 174, y + 66, 86)
end

function View:_drawAssetLinkSale(state, x, y)
    local draft = state.transactionDraft
    self:_text("모듈 판매 확인", x + 6, y + 5, 248, "left", 11, C.cream)
    self:_text(self:_assetTradeEffect(state, draft.moduleId, true), x + 6, y + 22, 248, "left", 8, C.paper).role = "m42_sale_offer_effect"
    self:_text(string.format("실지불%dG · 환급%dG · 골드%d→%d", draft.paidGold, draft.refundGold,
        draft.goldBefore, draft.goldAfter), x + 6, y + 47, 248, "left", 8, C.cream).role = "m42_sale_paid"
    local before, after = draft.midLinkBefore, draft.midLinkAfter
    if before and after and (before.installed or after.installed)
        and (before.otherMidModuleCount ~= after.otherMidModuleCount or before.bonusPercentPoints ~= after.bonusPercentPoints) then
        self:_drawMidLinkProjection(draft, x + 6, y + 60)
    end
    self:_drawAssetLinkProjection(draft, x + 6, y + 73)
    self:_text("효과/성장 소멸 · 권리/획득 유지 · 재획득 불가", x + 6, y + 86, 248, "left", 8, C.tomato).role = "m42_sale_history"
    self:_text(string.format("수용량%d→%d · 배치%d · 회수%d/%d", draft.towerCapacityBefore, draft.towerCapacityAfter,
        draft.placedTowerCountBefore, #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount),
        x + 6, y + 99, 248, "left", 8, C.paper).role = "m42_sale_capacity"
    local errorText = draft.error and PURCHASE_ERROR_TEXT[draft.error]
    self:_text(errorText or "지도에서 정확 선택 · 개체/패치 유지 · 전체 취소 가능", x + 6, y + 112, 248, "left", 8,
        errorText and C.tomato or C.paper).role = "m42_sale_recall"
    self:_button(x + 6, y + 126, 104, 21, "판매 확인", { type = "confirm_inventory_transaction" }, draft.canCommit)
    self:_button(x + 116, y + 126, 72, 21, "전체 취소", { type = "cancel_inventory_transaction" }, true)
    self:_drawAssetSpareProjection(draft, x + 194, y + 124, 60)
end

function View:_hasMixedDraft(state, draft)
    local id = draft and (draft.offerId or draft.moduleId)
    local current = state.moduleStatusById and state.moduleStatusById.M15
    return id == "M15" or current and current.installed or false
end

function View:_drawMixedLinkedProjection(draft, x, y, role)
    local rows = {}
    local before, after = draft.midLinkBefore, draft.midLinkAfter
    if before and after and (before.installed or after.installed) then
        rows[#rows + 1] = string.format("중가%d→%d종/+%d→%d%%p", before.otherMidModuleCount,
            after.otherMidModuleCount, before.bonusPercentPoints, after.bonusPercentPoints)
    end
    before, after = draft.assetLinkBefore, draft.assetLinkAfter
    if before and after and (before.installed or after.installed) then
        if before.observationError or after.observationError then rows[#rows + 1] = "자산 기록 확인 불가"
        else rows[#rows + 1] = string.format("자산%d→%dG/+%d→%d%%p", before.otherModulePaidGold,
            after.otherModulePaidGold, before.bonusPercentPoints, after.bonusPercentPoints) end
    end
    self:_text(#rows > 0 and table.concat(rows, " · ") or draft.error and "연동 전후 확인 불가 · 현재 효과 유지" or "다른 연동 변화 없음", x, y, 248, "left", 8, C.mustard).role = role or "m15_draft_links"
end

function View:_drawMixedSelectedProjection(draft, x, y)
    local projection = draft.mixedTrade
    local text
    if not projection or projection.error == "tower_not_selected" then
        text = "선택 타워 없음 · 선택하면 속도 전후 확인"
    elseif not projection.after then
        local recallPending = projection.error == "recall_selection_required" or projection.error == "recall_count_mismatch"
        text = recallPending and "정확 회수 선택 후 속도 확인" or "속도 전후 확인 불가 · 현재 효과 유지"
    else
        text = string.format("선택#%d 패치%d종 · 속도%.2f→%.2f(+%d→%d%%p)", projection.towerInstanceId,
            projection.beforeStatus.selectedDistinctPatchCount, projection.before.attackRate, projection.after.attackRate,
            projection.beforeStatus.bonusPercentPoints, projection.afterStatus.bonusPercentPoints)
    end
    self:_text(text, x, y, 248, "left", 8, C.mustard).role = "m15_draft_selected"
end

function View:_drawMixedPurchase(state, x, y)
    local draft = state.purchaseDraft
    self:_text(string.format("%s · %dG · 슬롯%d→%d/%d", displayName("module", draft.offerId), draft.cost,
        draft.slotBefore, draft.slotAfter, draft.slotCapacity), x + 6, y + 1, 248, "left", 10, C.cream).role = "m15_draft_title"
    self:_text(self:_assetTradeEffect(state, draft.offerId, false), x + 6, y + 15, 248, "left", 8, C.paper).role = "m15_draft_offer_effect"
    self:_drawMixedLinkedProjection(draft, x + 6, y + 27)
    self:_drawMixedSelectedProjection(draft, x + 6, y + 40)
    self:_text(self:_assetPurchaseDetail(state, draft), x + 6, y + 53, 248, "left", 8,
        draft.error and C.tomato or C.paper).role = "m15_draft_detail"
    self:_button(x + 6, y + 68, 92, 21, "구매 확인", { type = "confirm_purchase" }, draft.enabled)
    self:_button(x + 104, y + 68, 64, 21, "취소", { type = "cancel_purchase" }, true)
    self:_drawAssetSpareProjection(draft, x + 174, y + 66, 86)
end

function View:_drawMixedSale(state, x, y)
    local draft = state.transactionDraft
    self:_text("모듈 판매 확인", x + 6, y + 5, 248, "left", 11, C.cream)
    self:_text(self:_assetTradeEffect(state, draft.moduleId, true), x + 6, y + 22, 248, "left", 8, C.paper).role = "m15_sale_offer_effect"
    self:_text(string.format("실지불%dG · 환급%dG · 골드%d→%d", draft.paidGold, draft.refundGold,
        draft.goldBefore, draft.goldAfter), x + 6, y + 47, 248, "left", 8, C.cream).role = "m15_sale_paid"
    self:_drawMixedLinkedProjection(draft, x + 6, y + 60)
    self:_drawMixedSelectedProjection(draft, x + 6, y + 73)
    self:_text("효과/성장 소멸 · 권리/획득 유지 · 재획득 불가", x + 6, y + 86, 248, "left", 8, C.tomato).role = "m15_sale_history"
    self:_text(string.format("수용량%d→%d · 배치%d · 회수%d/%d", draft.towerCapacityBefore, draft.towerCapacityAfter,
        draft.placedTowerCountBefore, #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount),
        x + 6, y + 99, 248, "left", 8, C.paper).role = "m15_sale_capacity"
    local errorText = draft.error and PURCHASE_ERROR_TEXT[draft.error]
    self:_text(errorText or "지도에서 정확 선택 · 개체/패치 유지 · 전체 취소 가능", x + 6, y + 112, 248, "left", 8,
        errorText and C.tomato or C.paper).role = "m15_sale_recall"
    self:_button(x + 6, y + 126, 104, 21, "판매 확인", { type = "confirm_inventory_transaction" }, draft.canCommit)
    self:_button(x + 116, y + 126, 72, 21, "전체 취소", { type = "cancel_inventory_transaction" }, true)
    self:_drawAssetSpareProjection(draft, x + 194, y + 124, 60)
end

function View:_hasMaintenanceDraft(state, draft)
    local id = draft and (draft.offerId or draft.moduleId)
    local current = state.moduleStatusById and state.moduleStatusById.M14
    return id == "M14" or current and current.installed or false
end

function View:_drawMaintenanceSelectedProjection(draft, x, y)
    local projection = draft.maintenanceTrade
    local text
    if not projection or projection.error == "tower_not_selected" then
        text = "선택 타워 없음 · 선택하면 실제 피해 전후 확인"
    elseif not projection.after then
        local pending = projection.error == "recall_selection_required" or projection.error == "recall_count_mismatch"
        text = pending and "정확 회수 선택 후 피해 확인" or "피해 전후 확인 불가 · 현재 효과 유지"
    else
        local before, after = projection.beforeMaintenanceStatus, projection.afterMaintenanceStatus
        text = string.format("선택#%d 고가%d개 · 피해%.2f→%.2f(+%d→%d%%p)", projection.towerInstanceId,
            before.selectedHighGradePatchCount, projection.before.damage, projection.after.damage,
            before.bonusPercentPoints, after.bonusPercentPoints)
    end
    self:_text(text, x, y, 248, "left", 8, C.mustard).role = "m14_draft_selected"
end

function View:_maintenanceTradeGuide(state)
    local draft = state.purchaseDraft or state.transactionDraft
    local projection = draft and draft.maintenanceTrade
    local required, chosen = draft.requiredRecallCount or 0, #(draft.selectedRecallTowerIds or {})
    local heading = required > 0 and string.format("정확 회수%d/%d · 개체/패치 유지 · 취소 가능", chosen, required)
        or "저장 확인 후 적용 · 취소 시 보유 상태 유지"
    if not projection or projection.error == "tower_not_selected" then
        return heading .. "\n선택 타워 없음 · 실제 피해/속도 확인 불가"
    end
    if not projection.after then
        return heading .. "\n전후 확인 불가 · 현재 효과 유지\n정확 회수/오류를 확인한 뒤 진행하세요."
    end
    local before, after = projection.beforeMaintenanceStatus, projection.afterMaintenanceStatus
    local summary = string.format("#%d 고가%d · 피해%.2f→%.2f · 속도%.2f→%.2f", projection.towerInstanceId,
        before.selectedHighGradePatchCount, projection.before.damage, projection.after.damage,
        projection.before.attackRate, projection.after.attackRate)
    local bonuses = string.format("M14+%d→%d%%p · M15+%d→%d%%p · 회수%d/%d", before.bonusPercentPoints,
        after.bonusPercentPoints, projection.beforeStatus.bonusPercentPoints, projection.afterStatus.bonusPercentPoints,
        chosen, required)
    return heading .. "\n" .. summary .. "\n" .. bonuses
end

function View:_drawMaintenancePurchase(state, x, y)
    local draft = state.purchaseDraft
    self:_text(string.format("%s · %dG · 슬롯%d→%d/%d", displayName("module", draft.offerId), draft.cost,
        draft.slotBefore, draft.slotAfter, draft.slotCapacity), x + 6, y + 1, 248, "left", 10, C.cream).role = "m14_draft_title"
    self:_text(self:_assetTradeEffect(state, draft.offerId, false), x + 6, y + 15, 248, "left", 8, C.paper).role = "m14_draft_offer_effect"
    self:_drawMixedLinkedProjection(draft, x + 6, y + 27, "m14_draft_links")
    self:_drawMaintenanceSelectedProjection(draft, x + 6, y + 40)
    self:_text(self:_assetPurchaseDetail(state, draft), x + 6, y + 53, 248, "left", 8,
        draft.error and C.tomato or C.paper).role = "m14_draft_detail"
    self:_button(x + 6, y + 68, 92, 21, "구매 확인", { type = "confirm_purchase" }, draft.enabled)
    self:_button(x + 104, y + 68, 64, 21, "취소", { type = "cancel_purchase" }, true)
    self:_drawAssetSpareProjection(draft, x + 174, y + 66, 86)
end

function View:_drawMaintenanceSale(state, x, y)
    local draft = state.transactionDraft
    self:_text("모듈 판매 확인", x + 6, y + 5, 248, "left", 11, C.cream)
    self:_text(self:_assetTradeEffect(state, draft.moduleId, true), x + 6, y + 22, 248, "left", 8, C.paper).role = "m14_sale_offer_effect"
    self:_text(string.format("실지불%dG · 환급%dG · 골드%d→%d", draft.paidGold, draft.refundGold,
        draft.goldBefore, draft.goldAfter), x + 6, y + 47, 248, "left", 8, C.cream).role = "m14_sale_paid"
    self:_drawMixedLinkedProjection(draft, x + 6, y + 60, "m14_draft_links")
    self:_drawMaintenanceSelectedProjection(draft, x + 6, y + 73)
    self:_text("효과/성장 소멸 · 권리/획득 유지 · 재획득 불가", x + 6, y + 86, 248, "left", 8, C.tomato).role = "m14_sale_history"
    self:_text(string.format("수용량%d→%d · 배치%d · 회수%d/%d", draft.towerCapacityBefore, draft.towerCapacityAfter,
        draft.placedTowerCountBefore, #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount),
        x + 6, y + 99, 248, "left", 8, C.paper).role = "m14_sale_capacity"
    local errorText = draft.error and PURCHASE_ERROR_TEXT[draft.error]
    self:_text(errorText or "지도에서 정확 선택 · 개체/패치 유지 · 전체 취소 가능", x + 6, y + 112, 248, "left", 8,
        errorText and C.tomato or C.paper).role = "m14_sale_recall"
    self:_button(x + 6, y + 126, 104, 21, "판매 확인", { type = "confirm_inventory_transaction" }, draft.canCommit)
    self:_button(x + 116, y + 126, 72, 21, "전체 취소", { type = "cancel_inventory_transaction" }, true)
    self:_drawAssetSpareProjection(draft, x + 194, y + 124, 60)
end


function View:_sharedTradeGuide(state)
    local draft = state.purchaseDraft or state.transactionDraft
    local projection = draft.sharedTrade
    local before, after = projection.beforeSharedAggregate, projection.afterSharedAggregate
    if not before or before.observationError then return "공용 ID 확인 불가 · 현재 상태 유지\n정확 회수/오류 확인 · 취소 가능" end
    local head = after and string.format("공용 ID%d→%d종 / 전체+%d→%d%%p", before.distinctPatchCount,
        after.distinctPatchCount, before.aggregateBonusPercentPoints, after.aggregateBonusPercentPoints)
        or string.format("공용 ID%d종 / 전체+%d%%p · 전후 확인 불가", before.distinctPatchCount, before.aggregateBonusPercentPoints)
    if projection.error == "tower_not_selected" then return head .. "\n선택 타워 없음 · 실제 피해 전후 확인 불가\n저장 확인 후 적용 · 취소 시 보유 상태 유지" end
    if not projection.after then return head .. "\n정확 회수/오류 확인 · 현재 효과 유지\n개체/패치 유지 · 전체 취소 가능" end
    local selected = string.format("선택#%d 피해%.2f→%.2f · 회수%d/%d", projection.towerInstanceId,
        projection.before.damage, projection.after.damage, #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount or 0)
    local links = string.format("M12+%d→%d · M14+%d→%d · M15+%d→%d%%p",
        projection.beforeBalancedStatus.bonusPercentPoints, projection.afterBalancedStatus.bonusPercentPoints,
        projection.beforeMaintenanceStatus.bonusPercentPoints, projection.afterMaintenanceStatus.bonusPercentPoints,
        projection.beforeStatus.bonusPercentPoints, projection.afterStatus.bonusPercentPoints)
    return head .. "\n" .. selected .. "\n" .. links
end

function View:_drawSharedSelectedProjection(draft, x, y)
    local projection, text = draft.sharedTrade
    if projection.error == "tower_not_selected" then text = "선택 타워 없음 · 실제 피해 전후 확인 불가"
    elseif not projection.after then text = "피해 전후 확인 불가 · 정확 회수/오류 확인"
    else text = string.format("#%d 피해%.2f→%.2f · 공용+%d→%d%%p", projection.towerInstanceId,
        projection.before.damage, projection.after.damage, projection.beforeSharedStatus.bonusPercentPoints,
        projection.afterSharedStatus.bonusPercentPoints) end
    self:_text(text, x, y, 248, "left", 8, C.mustard).role = "m16_draft_selected"
end

function View:_drawSharedPurchase(state, x, y)
    local draft = state.purchaseDraft
    self:_text(string.format("%s · %dG · 슬롯%d→%d/%d", displayName("module", draft.offerId), draft.cost,
        draft.slotBefore, draft.slotAfter, draft.slotCapacity), x+6, y+1, 248, "left", 10, C.cream).role = "m16_draft_title"
    self:_text(self:_assetTradeEffect(state, draft.offerId, false), x+6, y+15, 248, "left", 8, C.paper).role = "m16_draft_effect"
    self:_drawMixedLinkedProjection(draft, x+6, y+27, "m16_draft_links")
    self:_drawSharedSelectedProjection(draft, x+6, y+40)
    self:_text(self:_assetPurchaseDetail(state, draft), x+6, y+53, 248, "left", 8,
        draft.error and C.tomato or C.paper).role = "m16_draft_detail"
    self:_button(x+6, y+68, 92, 21, "구매 확인", { type="confirm_purchase" }, draft.enabled)
    self:_button(x+104, y+68, 64, 21, "취소", { type="cancel_purchase" }, true)
    self:_drawAssetSpareProjection(draft, x+174, y+66, 86)
end

function View:_drawSharedSale(state, x, y)
    local draft = state.transactionDraft
    self:_text("모듈 판매 확인", x+6, y+5, 248, "left", 11, C.cream)
    self:_text(self:_assetTradeEffect(state, draft.moduleId, true), x+6, y+22, 248, "left", 8, C.paper).role = "m16_sale_effect"
    self:_text(string.format("실지불%dG · 환급%dG · 골드%d→%d", draft.paidGold, draft.refundGold, draft.goldBefore, draft.goldAfter),
        x+6, y+47, 248, "left", 8, C.cream).role = "m16_sale_paid"
    self:_drawMixedLinkedProjection(draft, x+6, y+60, "m16_draft_links")
    self:_drawSharedSelectedProjection(draft, x+6, y+73)
    self:_text("효과 소멸 · 권리/획득 유지 · 재획득 불가", x+6, y+86, 248, "left", 8, C.tomato).role = "m16_sale_history"
    self:_text(string.format("수용량%d→%d · 배치%d · 회수%d/%d", draft.towerCapacityBefore, draft.towerCapacityAfter,
        draft.placedTowerCountBefore, #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount), x+6, y+99, 248, "left", 8, C.paper)
    self:_text("정확 회수/오류 확인 · 개체/패치 유지 · 전체 취소", x+6, y+112, 248, "left", 8, C.paper)
    self:_button(x+6, y+126, 104, 21, "판매 확인", { type="confirm_inventory_transaction" }, draft.canCommit)
    self:_button(x+116, y+126, 72, 21, "전체 취소", { type="cancel_inventory_transaction" }, true)
    self:_drawAssetSpareProjection(draft, x+194, y+124, 60)
end

function View:_hasBalancedDraft(state, draft)
    return draft ~= nil and draft.balancedTrade ~= nil
end

function View:_drawBalancedSelectedProjection(draft, x, y)
    local projection, text = draft.balancedTrade
    if not projection or projection.error == "tower_not_selected" then
        text = "선택 타워 없음 · 실제 사거리 전후 확인 불가"
    elseif not projection.after then
        text = "사거리 전후 확인 불가 · 정확 회수/오류 확인"
    else
        text = string.format("#%d 사거리%.2f→%.2f · 피해%.2f→%.2f", projection.towerInstanceId,
            projection.before.range, projection.after.range, projection.before.damage, projection.after.damage)
    end
    self:_text(text, x, y, 248, "left", 8, C.mustard).role = "m12_draft_selected"
end

function View:_balancedTradeGuide(state)
    local draft = state.purchaseDraft or state.transactionDraft
    local projection = draft and draft.balancedTrade
    local required, chosen = draft.requiredRecallCount or 0, #(draft.selectedRecallTowerIds or {})
    local heading = required > 0 and string.format("정확 회수%d/%d · 개체/패치 유지 · 취소 가능", chosen, required)
        or "저장 확인 후 적용 · 취소 시 보유 상태 유지"
    if not projection or projection.error == "tower_not_selected" then
        return heading .. "\n선택 타워 없음 · 실제 사거리 전후 확인 불가"
    end
    if not projection.after then return heading .. "\n전후 확인 불가 · 현재 효과 유지\n정확 회수/오류를 확인한 뒤 진행하세요." end
    local summary = string.format("#%d 사거리%.2f→%.2f · 속도%.2f→%.2f", projection.towerInstanceId,
        projection.before.range, projection.after.range, projection.before.attackRate, projection.after.attackRate)
    local bonuses = string.format("M12+%d→%d · M14+%d→%d · M15+%d→%d%%p",
        projection.beforeBalancedStatus.bonusPercentPoints, projection.afterBalancedStatus.bonusPercentPoints,
        projection.beforeMaintenanceStatus.bonusPercentPoints, projection.afterMaintenanceStatus.bonusPercentPoints,
        projection.beforeStatus.bonusPercentPoints, projection.afterStatus.bonusPercentPoints)
    return heading .. "\n" .. summary .. "\n" .. bonuses
end

function View:_drawBalancedPurchase(state, x, y)
    local draft = state.purchaseDraft
    self:_text(string.format("%s · %dG · 슬롯%d→%d/%d", displayName("module", draft.offerId), draft.cost,
        draft.slotBefore, draft.slotAfter, draft.slotCapacity), x+6, y+1, 248, "left", 10, C.cream).role = "m12_draft_title"
    self:_text(self:_assetTradeEffect(state, draft.offerId, false), x+6, y+15, 248, "left", 8, C.paper).role = "m12_draft_offer_effect"
    self:_drawMixedLinkedProjection(draft, x+6, y+27, "m12_draft_links")
    self:_drawBalancedSelectedProjection(draft, x+6, y+40)
    self:_text(self:_assetPurchaseDetail(state, draft), x+6, y+53, 248, "left", 8,
        draft.error and C.tomato or C.paper).role = "m12_draft_detail"
    self:_button(x+6, y+68, 92, 21, "구매 확인", { type="confirm_purchase" }, draft.enabled)
    self:_button(x+104, y+68, 64, 21, "취소", { type="cancel_purchase" }, true)
    self:_drawAssetSpareProjection(draft, x+174, y+66, 86)
end

function View:_drawBalancedSale(state, x, y)
    local draft = state.transactionDraft
    self:_text("모듈 판매 확인", x+6, y+5, 248, "left", 11, C.cream)
    self:_text(self:_assetTradeEffect(state, draft.moduleId, true), x+6, y+22, 248, "left", 8, C.paper).role = "m12_sale_offer_effect"
    self:_text(string.format("실지불%dG · 환급%dG · 골드%d→%d", draft.paidGold, draft.refundGold, draft.goldBefore, draft.goldAfter),
        x+6, y+47, 248, "left", 8, C.cream).role = "m12_sale_paid"
    self:_drawMixedLinkedProjection(draft, x+6, y+60, "m12_draft_links")
    self:_drawBalancedSelectedProjection(draft, x+6, y+73)
    self:_text("효과 소멸 · 권리/획득 유지 · 재획득 불가", x+6, y+86, 248, "left", 8, C.tomato).role = "m12_sale_history"
    self:_text(string.format("수용량%d→%d · 배치%d · 회수%d/%d", draft.towerCapacityBefore, draft.towerCapacityAfter,
        draft.placedTowerCountBefore, #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount), x+6, y+99, 248, "left", 8, C.paper).role = "m12_sale_capacity"
    local errorText = draft.error and PURCHASE_ERROR_TEXT[draft.error]
    self:_text(errorText or "지도에서 정확 선택 · 개체/패치 유지 · 전체 취소 가능", x+6, y+112, 248, "left", 8,
        errorText and C.tomato or C.paper).role = "m12_sale_recall"
    self:_button(x+6, y+126, 104, 21, "판매 확인", { type="confirm_inventory_transaction" }, draft.canCommit)
    self:_button(x+116, y+126, 72, 21, "전체 취소", { type="cancel_inventory_transaction" }, true)
    self:_drawAssetSpareProjection(draft, x+194, y+124, 60)
end

function View:_drawDraft(state, x, y)
    local draft = state.purchaseDraft
    if not draft then return end
    setColor(C.guide)
    local balancedTrade = draft.kind == "module" and (draft.offerId == "M12" or (self:_hasBalancedDraft(state, draft) and not self:_hasMaintenanceDraft(state, draft) and not self:_hasMixedDraft(state, draft)))
    local maintenanceTrade = draft.kind == "module" and self:_hasMaintenanceDraft(state, draft)
    local mixedTrade = draft.kind == "module" and self:_hasMixedDraft(state, draft)
    local assetTrade = draft.kind == "module" and self:_hasAssetLinkDraft(state, draft)
    love.graphics.rectangle("fill", x, y, 260, (draft.sharedTrade and draft.kind == "module" or balancedTrade or maintenanceTrade or mixedTrade or assetTrade) and 90 or 72)
    if draft.sharedTrade and draft.kind == "module" then self:_drawSharedPurchase(state, x, y) return end
    if balancedTrade then self:_drawBalancedPurchase(state, x, y) return end
    if maintenanceTrade then self:_drawMaintenancePurchase(state, x, y) return end
    if mixedTrade then self:_drawMixedPurchase(state, x, y) return end
    if assetTrade then self:_drawAssetLinkPurchase(state, x, y) return end
    if draft.kind == "module" and self:_hasMidLinkDraft(draft) then
        self:_drawMidLinkPurchase(state, x, y)
        return
    end
    if draft.kind == "tower" then
        self:_text(string.format("%s · %d골드", displayName("tower", draft.offerId), draft.cost), x + 6, y + 3, 248, "left", 10, C.cream)
        self:_text(string.format("새 타워 #%d · 구매 뒤 미배치 목록에 추가", draft.newInstanceId), x + 6, y + 18, 248, "left", 9, C.paper)
        if draft.offerId == "T05" or draft.offerId == "T06" then
            self:_text(self:_towerStatsLine(draft.offerId), x + 6, y + 29, 248, "left", 8, C.cream).role = "tower_offer_stats"
            self:_text(self:_towerRoleLine(draft.offerId), x + 6, y + 39, 248, "left", 7, C.paper).role = "tower_offer_role"
        end
    elseif draft.kind == "module" then
        self:_text(string.format("%s · %dG · 슬롯 %d→%d/%d", displayName("module", draft.offerId), draft.cost,
            draft.slotBefore, draft.slotAfter, draft.slotCapacity), x + 6, y + 2, 248, "left", 10, C.cream)
        self:_text(MODULE_EFFECTS[draft.offerId] or draft.effect, x + 6, y + 15, 248, "left", 8, C.paper)
        if draft.offerId == "M06" then
            self:_text(string.format("수용량 %d→%d · 배치 %d · 필요 회수 %d", draft.towerCapacityBefore or 0,
                draft.towerCapacityAfter or 0, draft.placedTowerCountBefore or 0,
                draft.requiredRecallCount or 0), x + 6, y + 27, 248, "left", 8, C.mustard)
            local recallNote
            if draft.error == "insufficient_gold" then
                recallNote = "정가 골드 부족 · 개체/패치 보존"
            elseif (draft.requiredRecallCount or 0) > 0 then
                recallNote = string.format("선택 %d/%d · 개체/패치 보존",
                    #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount)
            else
                recallNote = "회수 없음 · 확인 후 수용량 적용"
            end
            self:_text(recallNote, x + 6, y + 38, 248, "left", 8,
                draft.error == "insufficient_gold" and C.tomato or C.cream)
        elseif (draft.requiredRecallCount or 0) > 0 then
            self:_text(string.format("수용량 %d→%d · 배치 %d · 회수 %d/%d", draft.towerCapacityBefore or 0,
                draft.towerCapacityAfter or 0, draft.placedTowerCountBefore or 0,
                #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount), x + 6, y + 27, 248, "left", 8, C.mustard)
            local recallNote = draft.error == "insufficient_gold"
                and "개체·패치 보존 · 정가 골드 부족"
                or "개체·패치 보존 · 정확히 필요한 수 선택"
            self:_text(recallNote, x + 6, y + 38, 248, "left", 8,
                draft.error == "insufficient_gold" and C.tomato or C.cream)
        else
            local statusLine, statusDetail = self:_moduleStatusLines(state, draft.offerId)
            if draft.offerId == "M46" and draft.emergencyBefore then
                self:_drawEmergencyProjection(draft, x + 6, y + 28, 248)
            elseif draft.offerId == "M31" then
                self:_text(string.format("미배치%d종 · 예비%d→%dG/최대3G", draft.reserveAfter.reserveTypeCount or 0,
                    draft.reserveBefore.estimatedGold, draft.reserveAfter.estimatedGold), x+6, y+28, 248, "left", 8, C.mustard).role = "m31_buy_preview"
            else
                self:_text(statusLine, x + 6, y + 28, 248, "left", 8, C.mustard)
            end
            if statusDetail and not draft.error then self:_text(statusDetail, x + 6, y + 39, 248, "left", 7, C.paper) end
        end
    elseif draft.kind == "patch" and draft.before and draft.after then
        local target = self:_selectedTower(state)
        self:_text(string.format("%s · %dG → #%d %s", displayName("patch", draft.offerId), draft.cost,
            draft.targetInstanceId, target and (TOWER_NAMES[target.typeId] or target.typeId) or "타워"), x + 6, y + 2, 248, "left", 10, C.cream)
        self:_text(string.format("피해 %.1f→%.1f · 속도 %.2f→%.2f", draft.before.damage, draft.after.damage,
            draft.before.attackRate, draft.after.attackRate), x + 6, y + 15, 248, "left", 8, C.paper)
        self:_text(string.format("패치 %d→%d/3 · 사거리 %.2f→%.2f", draft.patchCountBefore, draft.patchCountAfter,
            draft.before.range, draft.after.range), x + 6, y + 26, 248, "left", 8, C.paper)
        local receipt, growth = draft.receiptPreview, draft.growthPreview
        if receipt then
            local refundStatus = state.moduleStatusById and state.moduleStatusById.M29
            local receiptLine
            if draft.error == "insufficient_gold" then
                receiptLine = string.format("정가%dG 필요/현재%dG · 환%d/실%dG · 골드 부족", receipt.paidGold or 0,
                    state.runState and state.runState.gold or 0, receipt.refundGold or 0, receipt.netGold or 0)
            else
                receiptLine = string.format("정가%d/환%d/실%dG%s%s", receipt.paidGold or 0,
                    receipt.refundGold or 0, receipt.netGold or 0,
                    refundStatus and refundStatus.installed and string.format(" · 환급사용%d/2", refundStatus.refundUseCount or 0) or "",
                    growth and (" · " .. growthChangeText(growth)) or "")
            end
            self:_text(receiptLine,
                x + 6, y + 37, 248, "left", 7, C.mustard)
        end
    else
        self:_text("구매 확인 불가 · " .. tostring(draft.error), x + 6, y + 5, 248, "left", 11, C.tomato)
        if draft.kind == "patch" then self:_text("아래 보유 타워에서 적용 대상을 먼저 고르세요.", x + 6, y + 22, 248, "left", 10, C.paper) end
    end
    if draft.error and draft.kind == "module" and (draft.requiredRecallCount or 0) == 0 then
        self:_text(PURCHASE_ERROR_TEXT[draft.error] or tostring(draft.error), x + 6, y + 39, 248, "left", 7, C.tomato)
    end
    self:_button(x + 6, y + 48, 92, 21, "구매 확인", { type = "confirm_purchase" }, draft.enabled)
    self:_button(x + 104, y + 48, 64, 21, "취소", { type = "cancel_purchase" }, true)
    if draft.kind == "module" then self:_drawSpareCircuitProjection(draft, x + 174, y + 49, 80) end
end

function View:_drawTransactionDraft(state, x, y)
    local draft, run = state.transactionDraft, state.runState
    if not draft or not run then return end
    setColor(C.guide)
    local balancedTrade = draft.kind == "sell_module" and (draft.moduleId == "M12" or (self:_hasBalancedDraft(state, draft) and not self:_hasMaintenanceDraft(state, draft) and not self:_hasMixedDraft(state, draft)))
    local maintenanceTrade = draft.kind == "sell_module" and self:_hasMaintenanceDraft(state, draft)
    local mixedTrade = draft.kind == "sell_module" and self:_hasMixedDraft(state, draft)
    local assetTrade = draft.kind == "sell_module" and self:_hasAssetLinkDraft(state, draft)
    love.graphics.rectangle("fill", x, y, 260, (draft.sharedTrade and draft.kind == "sell_module" or balancedTrade or maintenanceTrade or mixedTrade or assetTrade) and 148 or 126)
    if draft.sharedTrade and draft.kind == "sell_module" then self:_drawSharedSale(state, x, y) return end
    if balancedTrade then self:_drawBalancedSale(state, x, y) return end
    if maintenanceTrade then self:_drawMaintenanceSale(state, x, y) return end
    if mixedTrade then self:_drawMixedSale(state, x, y) return end
    if assetTrade then self:_drawAssetLinkSale(state, x, y) return end

    if draft.kind == "sell_module" and self:_hasMidLinkDraft(draft) then
        self:_drawMidLinkSale(state, x, y)
        return
    end

    if draft.kind == "sell_tower" then
        local tower = findTower(run, draft.instanceId)
        local towerName = tower and displayName("tower", tower.typeId) or displayName("tower", draft.typeId)
        self:_text("포탑 판매 확인", x + 6, y + 5, 248, "left", 11, C.cream)
        self:_text(string.format("#%d %s · %s", draft.instanceId or 0, towerName,
            tower and tower.placement and "배치됨" or "미배치"), x + 6, y + 22, 248, "left", 10, C.paper)
        self:_text(string.format("실지불 %dG · 환급 %dG · 골드 %d→%d", draft.paidGold or 0,
            draft.refundGold or 0, draft.goldBefore or run.gold, draft.goldAfter or run.gold),
            x + 6, y + 38, 248, "left", 9, C.cream)
        local patchNames = {}
        for _, patchId in ipairs(tower and tower.patchIds or {}) do
            patchNames[#patchNames + 1] = displayName("patch", patchId)
        end
        self:_text(string.format("결합 패치 %d개%s", draft.patchCount or #patchNames,
            #patchNames > 0 and (" · " .. table.concat(patchNames, "/")) or ""),
            x + 6, y + 53, 248, "left", 8, C.paper)
        self:_text((draft.paidGold or 0) == 0 and "무료 획득 · 환급 0G · 판매 시 패치 소멸"
            or "판매 시 결합 패치 소멸 · 패치 환급 없음", x + 6, y + 68, 248, "left", 9, C.tomato)
    elseif draft.kind == "sell_module" then
        local moduleName = displayName("module", draft.moduleId)
        self:_text("모듈 판매 확인", x + 6, y + 5, 248, "left", 11, C.cream)
        self:_text(moduleName .. " · " .. (MODULE_EFFECTS[draft.moduleId] or "효과 정보 없음"),
            x + 6, y + 22, 248, "left", 8, C.paper)
        local statusLine = self:_moduleStatusLines(state, draft.moduleId)
        if draft.moduleId == "M46" then self:_drawEmergencyProjection(draft, x + 6, y + 35, 248)
        elseif draft.moduleId == "M31" then
            self:_text(string.format("미배치%d종 · 예비%d→%dG/최대3G", draft.reserveBefore.reserveTypeCount or 0,
                draft.reserveBefore.estimatedGold, draft.reserveAfter and draft.reserveAfter.estimatedGold or 0), x+6, y+35, 248, "left", 8, C.mustard).role = "m31_sale_preview"
        else self:_text(statusLine, x + 6, y + 35, 248, "left", 8, C.mustard) end
        self:_text(string.format("실지불 %dG · 환급 %dG · 골드 %d→%d", draft.paidGold or 0,
            draft.refundGold or 0, draft.goldBefore or run.gold, draft.goldAfter or run.gold),
            x + 6, y + 48, 248, "left", 8, C.cream)
        self:_text(draft.moduleId == "M28" and "이자 0 · 영구 해금 유지 · 이번 판 재획득 불가"
            or (draft.moduleId == "M43" or draft.moduleId == "M46") and "피해 0 · 영구 해금 유지 · 이번 판 재획득 불가"
            or (draft.growth or 0) > 0 and string.format("성장 %d%%p 소멸 · 획득 기록 유지 · 재획득 불가", draft.growth)
            or "효과 소멸 · 획득 기록 유지 · 재등장/재획득 불가",
            x + 6, y + 61, 248, "left", 8, C.tomato)
    end

    if (draft.requiredRecallCount or 0) > 0 then
        self:_text(string.format("수용량 %d→%d · 배치 %d기 · 회수 선택 %d/%d",
            draft.towerCapacityBefore or 0, draft.towerCapacityAfter or 0,
            draft.placedTowerCountAfter or draft.placedTowerCountBefore or 0,
            #(draft.selectedRecallTowerIds or {}), draft.requiredRecallCount),
            x + 6, y + 78, 248, "left", 9, C.mustard)
        local ids = {}
        for _, instanceId in ipairs(draft.selectedRecallTowerIds or {}) do ids[#ids + 1] = "#" .. instanceId end
        self:_text(#ids > 0 and ("선택: " .. table.concat(ids, ", ")) or "좌측 배치 포탑에서 정확한 수를 고르세요.",
            x + 6, y + 92, 248, "left", 8, C.paper)
    elseif draft.kind == "sell_tower" and draft.reserveBefore and draft.reserveBefore.installed then
        self:_text(string.format("미배치%d→%d종 · 예비 정산%d→%dG", draft.reserveBefore.reserveTypeCount or 0,
            draft.reserveAfter.reserveTypeCount or 0, draft.reserveBefore.estimatedGold, draft.reserveAfter.estimatedGold),
            x+6, y+80, 248, "left", 8, C.mustard).role = "m31_trade_income"
    elseif draft.kind == "sell_module" then
        self:_text(string.format("배치 %d기 · 포탑 수용량 %d→%d",
            draft.placedTowerCountAfter or draft.placedTowerCountBefore or 0,
            draft.towerCapacityBefore or 0, draft.towerCapacityAfter or 0), x + 6, y + 80, 248, "left", 9, C.paper)
    end

    self:_button(x + 6, y + 101, 104, 22, "판매 확인", { type = "confirm_inventory_transaction" }, draft.canCommit)
    self:_button(x + 116, y + 101, 72, 22, "전체 취소", { type = "cancel_inventory_transaction" }, true)
    if draft.kind == "sell_module" then self:_drawSpareCircuitProjection(draft, x + 194, y + 101, 60) end
end

function View:_drawTowerManagement(state, x, y)
    local run = state.runState
    local tower = self:_selectedTower(state)
    if not tower then
        self:_text("좌측 보유 목록이나 지도에서 포탑을 선택하세요.", x + 6, y + 4, 248, "left", 10, C.paper)
        self:_text("판매는 확인이 필요하며, 배치 포탑 회수는 무료입니다.", x + 6, y + 24, 248, "left", 9, C.cream)
        return
    end
    local patchNames = {}
    for _, patchId in ipairs(tower.patchIds or {}) do patchNames[#patchNames + 1] = displayName("patch", patchId) end
    local paid = tower.paidGold or 0
    self:_text(string.format("#%d %s · %s", tower.instanceId, displayName("tower", tower.typeId),
        tower.placement and "배치됨" or "미배치"), x + 6, y + 4, 248, "left", 11, C.cream)
    self:_text(string.format("실지불 %dG · 판매 환급 %dG%s", paid, math.floor(paid / 2),
        paid == 0 and " · 무료 획득" or ""), x + 6, y + 21, 248, "left", 9, C.paper)
    self:_text(string.format("패치 %d개%s", #(tower.patchIds or {}),
        #patchNames > 0 and (" · " .. table.concat(patchNames, "/")) or ""),
        x + 6, y + 36, 248, "left", 8, C.paper)
    local advanced = tower.typeId == "T05" or tower.typeId == "T06"
    if advanced then
        self:_text(self:_towerStatsLine(tower.typeId), x + 6, y + 48, 248, "left", 8, C.cream).role = "owned_tower_stats"
        self:_text(self:_towerRoleLine(tower.typeId), x + 6, y + 60, 248, "left", 8, C.paper).role = "owned_tower_role"
    end
    self:_text(#patchNames > 0 and "판매하면 패치가 소멸하며 환급되지 않습니다."
        or "판매는 포탑 인스턴스를 제거합니다.", x + 6, y + (advanced and 72 or 51), 248, "left", 8,
        #patchNames > 0 and C.tomato or C.paper)
    self:_button(x + 6, y + (advanced and 87 or 71), 104, 22, "판매 미리보기",
        { type = "begin_inventory_transaction", kind = "sell_tower", instanceId = tower.instanceId }, true)
    self:_button(x + 116, y + (advanced and 87 or 71), 104, 22, tower.placement and "무료 회수" or "이미 미배치",
        { type = "recall_tower", instanceId = tower.instanceId }, tower.placement ~= nil)
end

function View:_drawModuleManagement(state, x, y)
    local run = state.runState
    local selected = self.managedModuleId and moduleEntry(run, self.managedModuleId) or nil
    if self.managedModuleId and not selected then self.managedModuleId = nil end
    if selected then
        local moduleId = moduleIdOf(selected)
        local paid = self:_modulePaidGold(run, moduleId)
        self:_button(x + 6, y + 2, 62, 18, "목록", { type = "managed_module_back" }, true)
        self:_text(displayName("module", moduleId), x + 74, y + 5, 176, "left", 11, C.cream)
        self:_text(MODULE_EFFECTS[moduleId] or "효과 정보 없음", x + 6, y + (moduleId == "M16" and 22 or 24), 248, "left", 8, C.paper)
        local statusLine, statusDetail = self:_moduleStatusLines(state, moduleId)
        self:_text(statusLine, x + 6, y + (moduleId == "M16" and 33 or 37), 248, "left", 8, C.mustard)
        if statusDetail then self:_text(statusDetail, x + 6, y + (moduleId == "M16" and 44 or 48), 248, "left", (moduleId == "M12" or moduleId == "M14" or moduleId == "M15" or moduleId == "M16" or moduleId == "M41" or moduleId == "M42") and 8 or 7, C.paper).role = moduleId == "M16" and "m16_management_detail" or nil end
        self:_text(string.format("실지불 %dG · 판매 환급 %dG", paid, math.floor(paid / 2)),
            x + 6, y + (moduleId == "M16" and 77 or 59), 248, "left", 8, C.cream).role = moduleId == "M16" and "m16_management_paid" or nil
        self:_text(moduleId == "M28" and "판매 시 이자 0 · 영구 해금 유지 · 이번 판 재획득 불가"
            or moduleId == "M12" and "판매 시 사거리 기여0 · 권리/획득 유지 · 재획득 불가"
            or moduleId == "M16" and "판매 시 피해 기여0 · 권리/획득 유지 · 재획득 불가"
            or moduleId == "M14" and "판매 시 피해 기여0 · 권리/획득 유지 · 재획득 불가"
            or moduleId == "M15" and "판매 시 속도 기여0 · 권리/획득 유지 · 재획득 불가"
            or (moduleId == "M41" or moduleId == "M42" or moduleId == "M43" or moduleId == "M46") and "판매 시 피해 0 · 영구 해금 유지 · 이번 판 재획득 불가"
            or "판매 시 효과/성장 소멸 · 획득 기록 유지 · 재획득 불가",
            x + 6, y + (moduleId == "M16" and 88 or 70), 248, "left", (moduleId == "M12" or moduleId == "M14" or moduleId == "M15" or moduleId == "M16" or moduleId == "M41" or moduleId == "M42") and 8 or 7, C.tomato).role = moduleId == "M16" and "m16_management_history" or nil
        self:_button(x + 6, y + (moduleId == "M16" and 100 or (moduleId == "M12" or moduleId == "M14" or moduleId == "M15" or moduleId == "M41" or moduleId == "M42") and 82 or 80), 118, 20, "판매 미리보기",
            { type = "begin_inventory_transaction", kind = "sell_module", moduleId = moduleId }, true)
        return
    end

    local modules = run and run.modules or {}
    if #modules == 0 then
        self:_text("설치된 모듈이 없습니다.", x + 6, y + 5, 248, "left", 10, C.paper)
        return
    end
    self:_text("설치 모듈 · 선택하면 실제 환급과 제거 효과를 확인", x + 6, y + 3, 248, "left", 9, C.paper)
    for index, entry in ipairs(modules) do
        local moduleId = moduleIdOf(entry)
        local paid = self:_modulePaidGold(run, moduleId)
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        self:_button(x + 6 + column * 126, y + 22 + row * 25, 120, 21,
            string.format("%s +%dG", displayName("module", moduleId), math.floor(paid / 2)),
            { type = "select_managed_module", moduleId = moduleId }, true)
    end
end

function View:_drawInventoryManagement(state, x, y)
    setColor(C.guide)
    love.graphics.rectangle("fill", x, y, 260, 126)
    self:_button(x + 6, y + 5, 72, 20, "구매로", { type = "inventory_management", kind = "back" }, true)
    self:_button(x + 84, y + 5, 78, 20, "포탑 관리", { type = "inventory_management", kind = "tower" }, true,
        self.inventoryManagementTab == "tower")
    self:_button(x + 168, y + 5, 78, 20, "모듈 관리", { type = "inventory_management", kind = "module" }, true,
        self.inventoryManagementTab == "module")
    if self.inventoryManagementTab == "module" then
        self:_drawModuleManagement(state, x, y + 28)
    else
        self:_drawTowerManagement(state, x, y + 28)
    end
end

function View:_drawPrepareModuleStatus(state, x, y)
    local run = state.runState
    setColor(C.guide)
    love.graphics.rectangle("fill", x, y, 260, self.managedModuleId == "M16" and 108 or 96)
    local selected = self.managedModuleId and moduleEntry(run, self.managedModuleId) or nil
    if self.managedModuleId and not selected then self.managedModuleId = nil end
    if selected then
        local moduleId = moduleIdOf(selected)
        self:_button(x + 6, y + 3, 62, 18, "목록", { type = "module_status_back" }, true)
        self:_text(displayName("module", moduleId), x + 74, y + 6, 176, "left", 10, C.cream)
        self:_text(MODULE_EFFECTS[moduleId] or "효과 정보 없음", x + 6, y + 25, 248, "left", 8, C.paper)
        local statusLine, statusDetail = self:_moduleStatusLines(state, moduleId)
        self:_text(statusLine, x + 6, y + 40, 248, "left", 8, C.mustard)
        if statusDetail then self:_text(statusDetail, x + 6, y + 54, 248, "left", 8, C.paper) end
        self:_text("시작 행동은 위에 유지 · Esc/오른쪽 클릭: 목록", x + 6, y + (moduleId == "M16" and 87 or 75), 248, "left", 8, C.paper)
        return
    end
    self:_button(x + 6, y + 3, 62, 18, "닫기", { type = "module_status_back" }, true)
    self:_text("장착 모듈 상태 · 하나를 선택하세요", x + 74, y + 6, 176, "left", 9, C.cream)
    local modules = run and run.modules or {}
    if #modules == 0 then
        self:_text("장착된 모듈이 없습니다.", x + 6, y + 34, 248, "left", 10, C.paper)
        return
    end
    for index, entry in ipairs(modules) do
        local moduleId = moduleIdOf(entry)
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        self:_button(x + 6 + column * 126, y + 27 + row * 25, 120, 21,
            displayName("module", moduleId), { type = "select_status_module", moduleId = moduleId }, true)
    end
    self:_text("현재 조건·다음 성장·정산 예상은 Game 상태를 표시", x + 6, y + 80, 248, "left", 7, C.paper)
end

function View:_drawBossRules(x, y)
    local boss, bossWave
    for _, enemy in ipairs(self.defs.enemies or {}) do if enemy.boss then boss = enemy break end end
    for _, wave in ipairs(self.defs.waves or {}) do if wave.bossRequired then bossWave = wave break end end
    setColor(C.guide)
    love.graphics.rectangle("fill", x, y, 260, 126)
    self:_text(string.format("%s 최종 보스 · %s", bossWave and bossWave.id or "보스", ENEMY_NAMES[boss and boss.id] or "보스"),
        x + 6, y + 5, 248, "left", 11, C.cream)
    if boss then
        local threshold = boss.maxHp * boss.speedThresholdRatio
        self:_text(string.format("체력 %d · 기본 속도 %.2f칸/초", boss.maxHp, boss.speed),
            x + 6, y + 23, 248, "left", 10, C.paper)
        self:_text(string.format("HP %d 미만: 다음 이동부터 속도 ×%.2f", threshold, boss.speedMultiplier),
            x + 6, y + 40, 248, "left", 10, C.cream)
    end
    self:_text("처치 즉시 승리 · 출구 도달 즉시 패배", x + 6, y + 59, 248, "left", 10, C.cream)
    self:_text("같은 tick HP0 또는 탈출은 패배 우선", x + 6, y + 77, 248, "left", 10, C.tomato)
    self:_text("열람은 시간·RNG·골드에 영향 없음", x + 6, y + 99, 248, "left", 9, C.paper)
end

function View:_drawWaveDetail(schedule, x, y)
    setColor(C.guide)
    love.graphics.rectangle("fill", x, y, 260, 126)
    self:_button(x + 6, y + 5, 72, 20, "돌아가기", { type = "wave_detail_back" }, true)
    self:_text(schedule.waveId .. " 원본 편성", x + 84, y + 8, 166, "left", 11, C.cream)
    local legend = self:_text("정의 순서 · 입구 · 적×수 · 시작/간격(tick)", x + 6, y + 29, 248, "left", 8, C.paper)
    legend.role = "wave_detail_legend"
    local overlapNote = self:_text("※ 그룹별 출현 시간은 서로 겹칠 수 있음", x + 6, y + 40, 248, "left", 8, C.paper)
    overlapNote.role = "wave_overlap_note"
    for order, row in ipairs(schedule.rows) do
        local label = string.format("%s %s · %s×%d · %d/%dt%s", row.groupId, row.entranceId,
            row.enemyName, row.count, row.firstTick, row.intervalTicks,
            row.special and (" ★" .. row.special) or "")
        local line = self:_text(label, x + 6, y + 52 + (order - 1) * 14, 248, "left", 8,
            row.special and C.mustard or C.cream)
        line.role = "wave_group"
        line.waveIndex = schedule.index
        line.groupOrder = order
    end
end

local function resultReason(result)
    if not result then return "결과 정보 없음" end
    if result.reason == "boss_killed" then return "최종 보스 처치" end
    if result.reason == "boss_escaped" then return "보스 출구 도달" end
    if result.reason == "hp_zero" then return "생명 0" end
    return tostring(result.reason)
end

function View:_drawPanel(state)
    local run, phase = state.runState, state.phase
    if (phase ~= "SHOP" and phase ~= "PREPARE" and phase ~= "RESULT")
        or state.purchaseDraft or state.transactionDraft or state.newRunDraft or state.safeExitDraft
        or state.bossRulesOpen or self:hasWaveDetail() then self.towerUnlocksOpen = false end
    if phase ~= "SHOP" then
        self.inventoryManagementOpen = false
        self.inventoryManagementTab = "tower"
    end
    if phase ~= "PREPARE" then self.moduleStatusOpen = false end
    if not self.inventoryManagementOpen and not self.moduleStatusOpen then self.managedModuleId = nil end
    setColor(C.panel)
    love.graphics.rectangle("fill", 198, 30, 274, 234)
    local hp = state.battle and state.battle.hp or (run and run.hp or "-")
    local phaseHeader = self:_text(string.format("%s · 생명 %s · 골드 %s", PHASE_NAMES[phase] or phase,
        hp, run and run.gold or "-"), 205, 36, 260, "left", 11, C.cream)
    phaseHeader.role = "phase_header"
    self:_text(string.format("%d배속%s", state.speed, state.paused and " · 일시정지" or ""), 205, 52,
        self.towerUnlocksOpen and 80 or 160, "left", 10, state.paused and C.tomato or C.paper)
    local canLookup = (phase == "SHOP" or phase == "PREPARE" or phase == "RESULT")
        and not state.purchaseDraft and not state.transactionDraft and not state.newRunDraft
        and not state.safeExitDraft and not state.bossRulesOpen and not self:hasWaveDetail()
    if canLookup then
        self:_button(292, 48, 84, 20, self.towerUnlocksOpen and "해금 닫기" or (newMidLinkUnlock(state) or newAssetLinkUnlock(state) or newMixedUnlock(state) or newMaintenanceUnlock(state) or newBalancedUnlock(state) or newSharedUnlock(state)) and "해금 상세" or "해금 조회",
            { type = self.towerUnlocksOpen and "close_tower_unlocks" or "open_tower_unlocks" }, true, self.towerUnlocksOpen)
    end
    if phase ~= "SAVE_ERROR" and not self.towerUnlocksOpen then
        self:_button(380, 48, 85, 20, state.bossRulesOpen and "보스 닫기" or "보스 규칙",
            { type = "toggle_boss_rules" }, true)
    end
    setColor(C.guide)
    love.graphics.rectangle("fill", 205, 72, 260, 40)
    local guideValue = self:_primaryGuide(state)
    local moduleFeedback = #(state.newModuleUnlocks or {}) > 0
        and guideValue == self:_newTowerUnlockFeedback(state)
    local _, commonFeedback = self:_newTowerUnlockFeedback(state)
    if moduleFeedback and commonFeedback then
        self:_text(commonFeedback, 211, 22, 248, "left", 8, C.paper).role = "module_unlock_common_feedback"
    end
    local sharedDraft = (state.purchaseDraft or state.transactionDraft) and (state.purchaseDraft or state.transactionDraft).sharedTrade
    local spareFeedback = sharedDraft ~= nil or moduleFeedback and (newMidLinkUnlock(state) or newAssetLinkUnlock(state) or newMixedUnlock(state) or guideValue:find("빈칸", 1, true) ~= nil
        or guideValue:find("비상:", 1, true) ~= nil or newMaintenanceUnlock(state) or newBalancedUnlock(state) or newSharedUnlock(state))
        or ((state.purchaseDraft or state.transactionDraft) and (self:_hasMaintenanceDraft(state, state.purchaseDraft or state.transactionDraft) or self:_hasBalancedDraft(state, state.purchaseDraft or state.transactionDraft)))
    local primaryGuide = self:_text(guideValue, 211, spareFeedback and 73 or 75, 248, "left",
        spareFeedback and 8 or moduleFeedback and 9 or 10, C.cream)
    primaryGuide.role = "primary_guide"
    if not self.towerUnlocksOpen and ((phase == "PREPARE" and self:_newTowerUnlockFeedback(state))
        or (phase == "SHOP" and moduleFeedback)) then
        primaryGuide.extraRole = "new_tower_unlock_feedback"
    end

    local waveDetail = not state.bossRulesOpen and self:_activeWaveDetail(state) or nil
    if self.towerUnlocksOpen then
        self:_drawTowerUnlocks(state, 205, 116)
    elseif state.bossRulesOpen and phase ~= "SAVE_ERROR" then
        self:_drawBossRules(205, 116)
    elseif waveDetail then
        self:_drawWaveDetail(waveDetail, 205, 116)
    elseif phase == "SHOP" and run and run.shopState then
        local shop = run.shopState
        if state.transactionDraft then
            self:_drawTransactionDraft(state, 205, 116)
        elseif self.inventoryManagementOpen then
            self:_drawInventoryManagement(state, 205, 116)
        else
            self:_text("구매는 선택사항", 205, 115, 120, "left", 9, C.paper)
            self:_button(205, 126, 84, 21, self:_offerLabel("tower", shop.offers.tower), { type = "select_offer", kind = "tower" }, shop.offers.tower ~= nil, false, 9)
            self:_button(293, 126, 84, 21, self:_offerLabel("patch", shop.offers.patch), { type = "select_offer", kind = "patch" }, shop.offers.patch ~= nil, false, 9)
            self:_button(381, 126, 84, 21, self:_offerLabel("module", shop.offers.module), { type = "select_offer", kind = "module" }, shop.offers.module ~= nil, false, 9)
            local reroll = state.rerollPreview or {}
            self:_button(205, 151, 96, 21, "바꾸기 " .. tostring(reroll.paidGold or "-") .. "G",
                { type = "reroll" }, reroll.canCommit ~= false)
            self:_button(305, 151, 76, 21, "상점 접기", { type = "close_shop" }, true)
            self:_button(385, 151, 80, 21, "보유 관리", { type = "inventory_management", kind = "open" }, state.purchaseDraft == nil)
            if state.purchaseDraft then
                self:_drawDraft(state, 205, 174)
            else
                local growth = state.moduleStatusById and state.moduleStatusById.M33
                local growthSuffix = growth and growth.installed
                    and ((growth.cap or 0) > 0 and (growth.growth or 0) >= growth.cap
                        and " · 성장 최대치"
                        or string.format(" · 성장%d→%d", growth.growth or 0, growth.nextGrowth or 0)) or ""
                local rerollLine = string.format("리롤 명목%dG - 할인%dG = 실지불%dG%s%s",
                    reroll.nominalGold or 0, reroll.discountGold or 0, reroll.paidGold or 0,
                    growthSuffix, reroll.canCommit == false and " · 잔액 부족" or "")
                self:_text(rerollLine, 205, 174, 260, "left", 7,
                    reroll.canCommit == false and C.tomato or C.paper)
                local receiptLine = self:_receiptLine(state)
                local secondary = receiptLine
                if not secondary and growth and growth.installed then
                    secondary = (growth.cap or 0) > 0 and (growth.growth or 0) >= growth.cap
                        and string.format("탐색 학습 현재%d/%d%%p · 최대치", growth.growth or 0, growth.cap or 0)
                        or string.format("탐색 학습 현재%d/%d%%p · 성공 시 %d%%p",
                            growth.growth or 0, growth.cap or 0, growth.nextGrowth or 0)
                end
                if secondary then self:_text(secondary, 205, 185, 260, "left", 7, C.mustard) end
                for offset = 0, 2 do
                    local index = (run.nextWaveIndex or 1) + offset
                    local summary = self:_wavePreview(index)
                    if summary then
                        self:_text(summary, 205, 197 + offset * 17, 202, "left", 8, C.cream)
                        self:_button(411, 194 + offset * 17, 54, 17, "상세",
                            { type = "wave_detail", kind = string.format("W%02d", index), index = index }, true)
                    end
                end
            end
        end
    elseif phase == "PREPARE" then
        local index = run and run.nextWaveIndex or 1
        local last = self.defs.capabilities and self.defs.capabilities.waveRange.last or #self.defs.waves
        local canStart = run and index <= last and self.defs.wavesById[string.format("W%02d", index)] ~= nil
        self:_button(205, 120, 100, 24, canStart and string.format("W%02d 시작", index) or "웨이브 없음",
            { type = "start_wave" }, canStart)
        local canReopen = run and run.shopState and run.shopState.accessOpen == true
        self:_button(309, 120, 100, 24,
            run and run.shopState and (run.shopState.visitId .. " 열기") or "상점 닫힘",
            { type = "reopen_shop" }, canReopen)
        self:_button(413, 120, 52, 24, "모듈",
            { type = self.moduleStatusOpen and "module_status_back" or "open_module_status" }, true,
            self.moduleStatusOpen)
        if self.moduleStatusOpen then
            self:_drawPrepareModuleStatus(state, 205, 149)
        else
            local selectedTower = self:_selectedTower(state)
            if selectedTower then
                self:_text(string.format("선택 #%d %s · %s", selectedTower.instanceId,
                    displayName("tower", selectedTower.typeId), selectedTower.placement and "배치됨" or "미배치"),
                    205, 153, 154, "left", 9, C.cream)
                self:_button(363, 149, 102, 21, selectedTower.placement and "무료 회수" or "이미 미배치",
                    { type = "recall_tower", instanceId = selectedTower.instanceId }, selectedTower.placement ~= nil)
                if selectedTower.typeId == "T05" or selectedTower.typeId == "T06" then
                    self:_text(self:_towerStatsLine(selectedTower.typeId), 205, 169, 260, "left", 8, C.paper).role = "owned_tower_stats"
                    self:_text(self:_towerRoleLine(selectedTower.typeId), 205, 231, 260, "left", 8, C.paper).role = "owned_tower_role"
                end
            else
                self:_text("포탑을 선택하면 무료 회수 상태를 확인할 수 있습니다.", 205, 154, 260, "left", 8, C.paper)
            end
            self:_text(self:_waveSummary(index, true) or "다음 웨이브 없음", 205, 180, 260, "left", 9, C.cream)
            if canStart then
                self:_button(205, 204, 92, 20, "편성 상세", { type = "wave_detail",
                    kind = string.format("W%02d", index), index = index }, true)
            end
            self:_text("경로칸 배치 금지 · 예고는 실제 콘텐츠 집계", 303, 208, 162, "left", 8, C.paper)
            local receiptLine = self:_receiptLine(state)
            if receiptLine and not (selectedTower and (selectedTower.typeId == "T05" or selectedTower.typeId == "T06")) then
                self:_text(receiptLine, 205, 229, 260, "left", 7, C.mustard)
            end
        end
    elseif phase == "COMBAT" then
        self:_button(205, 120, 70, 24, "1배속", { type = "speed", speed = 1 }, true)
        self:_button(281, 120, 70, 24, "2배속", { type = "speed", speed = 2 }, true)
        self:_button(357, 120, 108, 24, state.paused and "명시적으로 재개" or "일시정지", { type = state.paused and "resume" or "pause" }, true)
        local battle = state.battle
        self:_text(string.format("W%02d · %d틱 · 적 %d · 미출현 %d", battle and battle.waveIndex or 0,
            battle and battle.tick or 0, battle and #battle.enemies or 0,
            battle and math.max(0, self:_waveTotal(battle.waveIndex) - battle.observations.spawned) or 0),
            205, 154, 260, "left", 10, C.cream)
        local balanced = state.moduleStatusById and state.moduleStatusById.M12
        if balanced and balanced.installed then
            local text = balanced.observationError and "균등 투자: 조건 확인 불가 · 기여0"
                or string.format("균등 투자 · 배치%d기 · %s · 선택 사거리%.2f/+%d%%p", balanced.placedTowerCount,
                    balanced.active and "활성" or "비활성", balanced.selectedRange or 0, balanced.bonusPercentPoints)
            self:_text(text, 205, 190, 260, "left", 8, C.mustard).role = "m12_combat_range"
        end
        self:_text("P 정지 · 1/2 배속 · 포커스 복귀는 자동 재개 안 함", 205, 176, 260, "left", 9, C.paper)
    elseif phase == "SAVE_ERROR" then
        if state.safeExitDraft then
            local warning = self:_text("미저장 변경 유실 가능", 205, 120, 260, "left", 13, C.tomato)
            warning.role = "safe_exit_warning"
            local detail = self:_text("마지막 정상 저장은 보존되지만 현재 후보는 폐기됩니다.", 205, 145, 260, "left", 9, C.paper)
            detail.role = "safe_exit_detail"
            self:_button(205, 170, 118, 24, "종료 확인", { type = "confirm_safe_exit" }, true)
            self:_button(329, 170, 90, 24, "취소", { type = "cancel_safe_exit" }, true)
        else
            self:_button(205, 120, 118, 24, "저장 재시도", { type = "retry_save" }, true)
            self:_button(329, 120, 118, 24, "안전 종료", { type = "request_safe_exit" }, true)
            local warning = self:_text("미저장 변경 유실 가능 · 종료 전 확인 필요", 205, 154, 260, "left", 10, C.tomato)
            warning.role = "safe_exit_warning"
            self:_text("저장 확인 전 결과는 적용되지 않았습니다.", 205, 174, 260, "left", 9, C.paper)
        end
    elseif phase == "RESULT" then
        local result = run and run.result
        self:_text(result and result.kind == "victory" and "승리" or "패배", 205, 121, 80, "left", 15,
            result and result.kind == "victory" and C.mustard or C.tomato)
        self:_text(resultReason(result), 205, 145, 260, "left", 11, C.cream)
        local feedback = self:_newTowerUnlockFeedback(state)
        if feedback then
            self:_text(feedback, 205, 162, 260, "left", 9, C.mint).role = "new_tower_unlock_feedback"
        end
        local actionY = feedback and 198 or 171
        if state.newRunDraft then
            self:_text("새 판을 저장한 뒤 시작합니다.", 205, feedback and 194 or 166, 260, "left", 9, C.paper)
            self:_button(205, feedback and 214 or 185, 118, 24, "새 판 확인", { type = "confirm_new_run" }, true)
            self:_button(329, feedback and 214 or 185, 90, 24, "취소", { type = "cancel_new_run" }, true)
        else
            self:_button(205, actionY, 118, 24, "새 판", { type = "request_new_run" }, true)
        end
    end
    if not (phase == "SHOP" and (state.purchaseDraft or state.transactionDraft or self.inventoryManagementOpen))
        and not state.bossRulesOpen and not waveDetail and not self.towerUnlocksOpen then
        local first = self.defs.capabilities and self.defs.capabilities.waveRange.first or 1
        local last = self.defs.capabilities and self.defs.capabilities.waveRange.last or #self.defs.waves
        local implemented = #self.defs.modules
        self:_text(string.format("개발: W%02d-W%02d · 포탑 6종 · 모듈 %d/48 · 추가모듈/아트 후속", first, last, implemented),
            205, 247, 260, "left", 8, C.paper)
    end
end

function View:_renderTexts(viewport)
    love.graphics.setScissor(viewport.x, viewport.y, viewport.w, viewport.h)
    for _, text in ipairs(self.texts) do
        love.graphics.setFont(self:_font(text.size * viewport.scale))
        setColor(text.color)
        local x, y = viewport.x + text.x * viewport.scale, viewport.y + text.y * viewport.scale
        if text.width then love.graphics.printf(text.value, x, y, text.width * viewport.scale, text.align)
        else love.graphics.print(text.value, x, y) end
    end
    love.graphics.setScissor()
end

function View:draw(state)
    self.buttons, self.texts = {}, {}
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(C.ink)
    self:_text("주방 합류로", 8, 6, 180, "left", 15, C.cream)
    local noticeValue = state.notice or ""
    if newMidLinkUnlock(state) or newAssetLinkUnlock(state) or newMixedUnlock(state) or newMaintenanceUnlock(state) or newBalancedUnlock(state) or newSharedUnlock(state) then
        noticeValue = string.format("%s 완료 · 모듈%d종 영구 해금", state.newModuleUnlocks[1].waveId, #state.newModuleUnlocks)
    elseif #(state.newModuleUnlocks or {}) > 0 and noticeValue:find("\n", 1, true) then
        -- The existing guide shows the full saved unlock reason/effect; keep the header compact.
        noticeValue = (noticeValue:match("^[^%.]*%.") or noticeValue:match("^[^\n]*"))
        local names = {}
        for _, event in ipairs(state.newTowerUnlocks or {}) do names[#names + 1] = displayName("tower", event.towerId) end
        for _, event in ipairs(state.newModuleUnlocks or {}) do names[#names + 1] = displayName("module", event.moduleId) end
        if state.moduleUnlockById.M43 and #(state.newModuleUnlocks or {}) > 0
            and (state.notice:find("여유 회로 영구 해금", 1, true)
                or state.notice:find("비상 출력 영구 해금", 1, true)) then
            noticeValue = string.format("%s 완료 · %s 해금 완료.", state.newModuleUnlocks[1].waveId, table.concat(names, "·"))
        else
            noticeValue = noticeValue .. " " .. table.concat(names, "·") .. " 해금 완료."
        end
    end
    local notice = self:_text(noticeValue, 198, 7, 274, "right", 10, C.paper)
    notice.role = "notice"
    self:_drawMap(state)
    self:_drawInventory(state)
    self:_drawPanel(state)
    love.graphics.setCanvas()

    local viewport = self:viewport(love.graphics.getDimensions())
    love.graphics.clear(0.025, 0.02, 0.02, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, viewport.x, viewport.y, 0, viewport.scale, viewport.scale)
    self:_renderTexts(viewport)
end

function View:hitTest(x, y)
    for index = #self.buttons, 1, -1 do
        local button = self.buttons[index]
        if button.enabled and inside(x, y, button)
            and (not self.towerUnlocksOpen or button.action.type == "close_tower_unlocks"
                or button.action.type == "unlock_lookup_tab") then return button.action end
    end
    return nil
end

return View
