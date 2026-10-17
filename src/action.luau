--* [[----------< constants >----------]]

local DEFAULT_PRIORITY = 1


--* [[----------< types >----------]]

type ActionCallback = (Instance) -> ()

type Action = {
    read priority: number,
    read callback: (Instance) -> ()
}

--* [[----------< action >----------]]

-- frozen and shared by every action and identity of this table
local action_metatable = table.freeze {}

local function is_action(v: any): boolean
    return getmetatable(v) == action_metatable
end



local function action(callback: ActionCallback, priority: number?): Action
    local a = setmetatable({
        priority = priority or DEFAULT_PRIORITY,
        callback = callback
    }, action_metatable)

    return table.freeze(a)
end

-- returned as a function so callers get both helpers with `local action, is_action = require "./action" ()`
return function()
    return action, is_action
end
