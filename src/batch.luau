local flags = require "./flags"
local graph = require "./graph"

local function batch(setter: () -> ())
    local already_batching = flags.batch
    local from: number

    if not already_batching then
        flags.batch = true
        from = graph.get_update_queue_length()
    end

    local err: string?
    local ok = xpcall(setter, function(e)
        err = debug.traceback(tostring(e), 2)
    end)

    if not already_batching then
        flags.batch = false
        graph.flush_update_queue(from)
    end

    if not ok then error(`error occured while batching updates: {err}`, 0) end
end

return batch
