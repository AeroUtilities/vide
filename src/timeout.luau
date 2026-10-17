--* [[----------< types >----------]]

type Callback = () -> ()

type Handle = {
    t: number,
    fn: Callback,
    cancel: boolean,
}


--* [[----------< state >----------]]

local queue: { Handle } = {}


--* [[----------< timeout >----------]]

-- schedules fn to run after t seconds; set handle.cancel = true to abort
local function timeout(t: number, fn: Callback): Handle
    local handle: Handle = {
        t = t,
        fn = fn,
        cancel = false,
    }

    table.insert(queue, handle)
    return handle
end

local function update_timeouts(dt: number)
    for i = #queue, 1, -1 do
        local handle = queue[i]
        handle.t -= dt

        if handle.cancel or handle.t <= 0 then
            -- swap-remove
            queue[i] = queue[#queue]
            queue[#queue] = nil

            if not handle.cancel then
                handle.fn()
            end
        end
    end
end


--* [[----------< exports >----------]]

-- factory so lib can own a single queue + updater pair
return function()
    return timeout, update_timeouts
end
