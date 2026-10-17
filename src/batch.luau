--* [[----------< modules >----------]]

local flags = require "./flags"
local graph = require "./graph" 


--* [[----------< types >----------]]

type Setter = (...any) -> any
type Traceback = (string?) -> string


--* [[----------< batch >----------]]

-- runs setter with graph updates queued, then flushes them once it finishes
-- nested calls piggyback on the outermost batch, which is the one that flushes
local function batch(setter: Setter)
    local already_batching = flags.batch
    local queue_start: number? = nil
    local traceback = debug.traceback :: Traceback

    if not already_batching then
        flags.batch = true
        queue_start = graph.get_update_queue_length()
    end

    local ok, err = xpcall(setter, traceback)

    -- flush before rethrowing so a failed setter can't leave updates stuck in the queue
    if not already_batching then
        flags.batch = false
        graph.flush_update_queue(queue_start :: number)
    end

    if not ok then 
        error(`error occured while batching updates: {err}`, 0) 
    end
end

return batch
