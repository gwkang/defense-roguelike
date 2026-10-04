package.path = "./?.lua;./src/?.lua;" .. package.path

local mode = "game"
for _, value in ipairs(arg or {}) do
    if value == "--test" then mode = "test" end
    if value == "--smoke" then mode = "smoke" end
end

local game, view, input
local smokeElapsed = 0

local function runTests()
    io.stdout:setvbuf("no")
    local originalQuit = love.event.quit
    local requestedFailure
    love.event.quit = function(code)
        if code ~= nil and code ~= 0 then
            requestedFailure = requestedFailure or tostring(code)
        end
    end
    local failures = 0
    for _, path in ipairs({ "tests/core_spec.lua", "tests/session_spec.lua", "tests/integration_spec.lua" }) do
        requestedFailure = nil
        io.write("RUN ", path, "\n")
        local ok, message = pcall(dofile, path)
        if not ok or requestedFailure then
            failures = failures + 1
            io.stderr:write("FAIL ", path, ": ",
                not ok and tostring(message) or ("suite requested failing exit " .. requestedFailure), "\n")
        end
    end
    love.event.quit = originalQuit
    io.write(string.format("TEST SUITE: %d file failures\n", failures))
    originalQuit(failures > 0 and 1 or 0)
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    if mode == "test" then return runTests() end
    if mode == "smoke" then love.filesystem.setIdentity("defense-roguelike-first-slice-smoke") end
    local Game = require("src.game")
    local View = require("src.view")
    local Input = require("src.input")
    game = Game.new({ smoke = mode == "smoke" })
    view = View.new(game.defs)
    input = Input.new(game, view)
end

function love.update(dt)
    if not game then return end
    game:update(dt)
    if mode == "smoke" then
        smokeElapsed = smokeElapsed + dt
        if smokeElapsed >= 0.35 then
            io.write("SMOKE PASS: boot, save readback, update and render completed\n")
            love.event.quit(0)
        end
    end
end

function love.draw()
    if view and game then view:draw(game:getState()) end
end

function love.mousepressed(x, y, button)
    if input then input:mousepressed(x, y, button) end
end

function love.keypressed(key, _, isRepeat)
    if input then input:keypressed(key, isRepeat) end
end

function love.focus(focused)
    if input then input:focus(focused) end
end
