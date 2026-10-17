--* [[----------< constants >----------]]

-- checked in this order on plain tables and userdata
local CLEANUP_METHODS = { "destroy", "disconnect", "Destroy", "Disconnect" }


--* [[----------< global guards >----------]]

local typeof = if Instance then typeof else require "../test/mock".typeof :: never


--* [[----------< modules >----------]]

local graph = require "./graph"


--* [[----------< types >----------]]

type Destroyable = { destroy: (any) -> () } | { Destroy: (any) -> () }
type Disconnectable = { disconnect: (any) -> () } | { Disconnect: (any) -> () }

-- every kind of value cleanup() accepts
type CleanupFunction =  ( (callback: () -> ()) -> () ) 
    & ( (thread: thread) -> () ) 
    & ( (instance: Destroyable) -> () ) 
    & ( (connection: Disconnectable) -> () ) 
    & ( (instance: Instance) -> () ) 
    & ( (connection: RBXScriptConnection) -> () )
    & ( () -> () )


--* [[----------< graph >----------]]

local get_scope = graph.get_scope
local push_cleanup = graph.push_cleanup


--* [[----------< cleanup >----------]]

-- turns a destroyable / disconnectable object into a plain cleanup callback
local function create_cleanup_callback(object: any): () -> ()
    if typeof(object) == "RBXScriptConnection" then
        return function() 
            object:Disconnect()
        end
    end

    if type(object) == "thread" then
        return function()
            task.cancel(object)
        end
    end

    if typeof(object) == "Instance" then
        return function()
            object:Destroy()
        end
    end

    -- anything else must be a table or userdata exposing one of the cleanup methods
    local object_type = typeof(object)
    if 
        object_type ~= "table" 
        and object_type ~= "userdata" 
    then
        error(`cannot cleanup given object`)
    end

    for _, method in CLEANUP_METHODS do
        if typeof(object[method]) == "function" then
            return function()
                object[method]()
            end
        end
    end

    error(`cannot cleanup given object`)
end



local function cleanup(value: unknown)
    local scope = get_scope()
    assert(scope,`cannot cleanup outside a stable or reactive scope`)

    if typeof(value) == "function" then
        push_cleanup(scope, value :: () -> ())
    else
        push_cleanup(scope, create_cleanup_callback(value))
    end
end


return cleanup :: CleanupFunction
