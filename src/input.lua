local Input = {}
Input.__index = Input

function Input.new(game, view)
    return setmetatable({ game = game, view = view }, Input)
end

function Input:_perform(action)
    if action.type == "open_tower_unlocks" then return self.view:openTowerUnlocks(self.game:getState()) end
    if action.type == "close_tower_unlocks" then return self.view:closeTowerUnlocks() end
    if action.type == "unlock_lookup_tab" then return self.view:setUnlockLookupTab(action.tab) end
    if self.view:hasTowerUnlocks() then return false end
    if action.type == "select_tower" then return self.game:selectTower(action.instanceId) end
    if action.type == "select_offer" then return self.game:selectOffer(action.kind) end
    if action.type == "confirm_purchase" then return self.game:confirmPurchase() end
    if action.type == "cancel_purchase" then return self.game:cancelPurchase() end
    if action.type == "inventory_management" then
        if action.kind == "back" then return self.view:closeInventoryManagement() end
        return self.view:openInventoryManagement(action.kind == "module" and "module" or "tower")
    end
    if action.type == "select_managed_module" then return self.view:selectManagedModule(action.moduleId) end
    if action.type == "managed_module_back" then return self.view:clearManagedModule() end
    if action.type == "begin_inventory_transaction" then
        return self.game:beginInventoryTransaction({
            kind = action.kind, instanceId = action.instanceId, moduleId = action.moduleId,
        })
    end
    if action.type == "toggle_inventory_recall" then
        return self.game:setInventoryRecallSelection(action.instanceId, action.selected)
    end
    if action.type == "toggle_purchase_recall" then
        return self.game:setPurchaseRecallSelection(action.instanceId, action.selected)
    end
    if action.type == "confirm_inventory_transaction" then return self.game:confirmInventoryTransaction() end
    if action.type == "cancel_inventory_transaction" then return self.game:cancelInventoryTransaction() end
    if action.type == "recall_tower" then return self.game:recallTower(action.instanceId) end
    if action.type == "reroll" then return self.game:rerollShop() end
    if action.type == "close_shop" then return self.game:closeShop() end
    if action.type == "reopen_shop" then return self.game:reopenShop() end
    if action.type == "start_wave" then return self.game:startWave() end
    if action.type == "speed" then return self.game:setSpeed(action.speed) end
    if action.type == "pause" then return self.game:togglePause() end
    if action.type == "resume" then return self.game:resumeAll() end
    if action.type == "retry_save" then return self.game:retrySave() end
    if action.type == "request_safe_exit" then return self.game:requestSafeExit() end
    if action.type == "cancel_safe_exit" then return self.game:cancelSafeExit() end
    if action.type == "confirm_safe_exit" then return self.game:confirmSafeExit() end
    if action.type == "toggle_boss_rules" then return self.game:toggleBossRules() end
    if action.type == "wave_detail" then return self.view:setWaveDetail(action.index, self.game:getState()) ~= nil end
    if action.type == "wave_detail_back" then return self.view:clearWaveDetail() end
    if action.type == "open_module_status" then return self.view:openModuleStatus() end
    if action.type == "select_status_module" then return self.view:selectStatusModule(action.moduleId) end
    if action.type == "module_status_back" then return self.view:closeModuleStatus() end
    if action.type == "inventory_page" then self.view:setInventoryPage(action.page, self.game:getState()); return true end
    if action.type == "request_new_run" then return self.game:requestNewRun() end
    if action.type == "cancel_new_run" then return self.game:cancelNewRun() end
    if action.type == "confirm_new_run" then return self.game:confirmNewRun() end
    return false
end

function Input:mousepressed(windowX, windowY, button)
    if button ~= 1 and button ~= 2 then return false end
    local ww, wh = love.graphics.getDimensions()
    local x, y = self.view:windowToLogical(windowX, windowY, ww, wh)
    if not x then return false end
    if button == 2 then
        local state = self.game:getState()
        if self.view:hasTowerUnlocks() then self.view:closeTowerUnlocks()
        elseif state.safeExitDraft then self.game:cancelSafeExit()
        elseif state.newRunDraft then self.game:cancelNewRun()
        elseif state.transactionDraft then self.game:cancelInventoryTransaction()
        elseif state.purchaseDraft then self.game:cancelPurchase()
        elseif state.bossRulesOpen then self.game:toggleBossRules()
        elseif self.view:hasWaveDetail() then self.view:clearWaveDetail()
        elseif self.view:hasModuleStatus() then self.view:closeModuleStatus()
        elseif self.view:hasInventoryManagement() then
            if self.view.managedModuleId then self.view:clearManagedModule()
            else self.view:closeInventoryManagement() end
        elseif state.phase == "RESULT" or state.phase == "SAVE_ERROR" then return false
        else self.game:cancelSelection() end
        return true
    end
    local action = self.view:hitTest(x, y)
    if action then
        self:_perform(action)
        return true -- UI capture: never leak this click into the map.
    end
    local state = self.game:getState()
    if self.view:hasTowerUnlocks() then return true end -- Lookup owns the pointer; never place or select behind it.
    if state.purchaseDraft and (state.purchaseDraft.requiredRecallCount or 0) > 0 then
        return true -- Exact-N recall selection owns the pointer until confirm/cancel.
    end
    local cellX, cellY = self.view:mapCell(x, y)
    if cellX then return self.game:placeSelected(cellX, cellY) end
    return false
end

function Input:keypressed(key, isRepeat)
    if isRepeat then return false end
    if self.view:hasTowerUnlocks() then
        if key == "escape" then return self.view:closeTowerUnlocks() end
        -- Preserve the existing speed/pause helper keys; they do not select or purchase.
        if key ~= "1" and key ~= "2" and key ~= "p" then return false end
    end
    if key == "1" then return self.game:setSpeed(1) end
    if key == "2" then return self.game:setSpeed(2) end
    if key == "p" then return self.game:togglePause() end
    if key == "escape" then
        local state = self.game:getState()
        if state.safeExitDraft then self.game:cancelSafeExit(); return true end
        if state.newRunDraft then self.game:cancelNewRun(); return true end
        if state.transactionDraft then self.game:cancelInventoryTransaction(); return true end
        if state.purchaseDraft then self.game:cancelPurchase(); return true end
        if state.bossRulesOpen then self.game:toggleBossRules(); return true end
        if self.view:hasWaveDetail() then self.view:clearWaveDetail(); return true end
        if self.view:hasModuleStatus() then self.view:closeModuleStatus(); return true end
        if self.view:hasInventoryManagement() then
            if self.view.managedModuleId then self.view:clearManagedModule()
            else self.view:closeInventoryManagement() end
            return true
        end
        if state.phase == "RESULT" or state.phase == "SAVE_ERROR" then return false end
        if state.selectedTowerId then self.game:cancelSelection(); return true end
        if state.phase == "COMBAT" then return self.game:togglePause() end
    end
    return false
end

function Input:focus(focused)
    self.game:onFocus(focused)
end

return Input
