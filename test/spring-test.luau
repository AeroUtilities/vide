--[[
    Finite spring integration test (replaces the old infinite ANSI bar demo).
    The previous version looped forever and relied on "\27[H\27[2J", which most
    IDE terminals do not honor as a full clear.
]]

local testkit = require "./testkit"
local TEST, CASE, CHECK, FINISH = testkit.test()

local vide = require "../../vide"
local root = vide.root
local source = vide.source
local spring = vide.spring
local step = vide.step

local MAX = 40
local MIN = 10
local PERIOD = 1
local DAMPING = 0.3
local DT = 1 / 30

TEST("spring visual replacement", function()
    do CASE "moves toward toggled targets and settles"
        local destroy, input, output = root(function()
            local input = source(MAX)
            local output = spring(input, PERIOD, DAMPING)
            return input, output
        end)

        CHECK(output() == MAX)

        -- drive toward MIN for a few seconds of simulated time
        input(MIN)
        local previous = output()
        local moved = false

        for _ = 1, 30 do -- ~1s at 30fps
            step(DT)
            local current = output()
            if current ~= previous then
                moved = true
            end
            if current < previous then
                -- springing down toward MIN
                previous = current
            else
                previous = current
            end
        end

        CHECK(moved)
        CHECK(output() < MAX)
        CHECK(output() > MIN - 1) -- still above / near the lower target while settling

        -- finish the motion
        step(10)
        CHECK(math.abs(output() - MIN) < 0.01)

        -- toggle back up and settle at MAX
        input(MAX)
        step(10)
        CHECK(math.abs(output() - MAX) < 0.01)

        destroy()
    end

    do CASE "config impulse changes output on next spring step"
        local destroy, input, output, control = root(function()
            local input = source(20)
            local output, control = spring(input, PERIOD, DAMPING)
            return input, output, control
        end)

        CHECK(output() == 20)

        control { impulse = 5 }
        step(DT)
        CHECK(output() ~= 20)

        destroy()
    end
end)

FINISH()
