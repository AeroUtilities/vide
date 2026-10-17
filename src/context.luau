--* [[----------< constants >----------]]

-- stored in place of nil so a context explicitly set to nil still counts as found
local NIL_SYMBOL = newproxy()


--* [[----------< modules >----------]]

local graph = require "./graph"


--* [[----------< types >----------]]

type Node<T> = graph.Node<T>

export type Context<T> = (() -> T) & (<U>(T, () -> U) -> U)


--* [[----------< graph >----------]]
local create_node = graph.create_node
local get_scope = graph.get_scope
local push_scope = graph.push_scope
local pop_scope = graph.pop_scope
local set_context = graph.set_context


--* [[----------< state >----------]]

-- incremented for every context() call, used as that context's key in a scope's context table
local context_count = 0


--* [[----------< helper functions >----------]]

local function handle_error(err: string): string
    return debug.traceback(err, 3)
end



-- walks up the scope tree and returns the first value stored for this context id
-- returns nil if no scope has one, or NIL_SYMBOL if it was explicitly set to nil
local function find_stored_value(scope: Node<unknown>? | false, id: number): unknown
    while scope do
        local ctx = scope.context
        local value = if ctx 
            then (ctx :: { unknown })[id]
            else nil

        if value ~= nil then 
            return value 
        end

        scope = scope.owner
    end

    return nil
end



local function get_context_value(id: number, has_default: boolean, default_value: unknown): any
    local stored = find_stored_value(get_scope(), id)

    if stored ~= nil then
        return if stored ~= NIL_SYMBOL 
            then stored
            else nil
    end

    if has_default then
        return default_value
    else
        error("attempt to get context when no context is set and no default context is set", 0)
    end
end



-- runs component inside a new child scope that holds the given context value
local function run_in_context(scope: Node<unknown>, id: number, value: unknown, component: () -> unknown): any
    local new_scope = create_node(scope, false, false)
    local value_symbol = if value == nil 
        then NIL_SYMBOL
        else value
    
    set_context(new_scope, id, value_symbol)

    push_scope(new_scope)
    local ok, result = xpcall(component, handle_error)
    pop_scope()

    if not ok then
        error(`error while running context:\n\n{result}`, 0)
    end

    return result
    
end


--* [[----------< context >----------]]

local function context<T>(...: T): Context<T>
    context_count += 1
    local id = context_count

    local has_default = select("#", ...) > 0
    local default_value = ...

    -- no arguments gets the value, (value, component) sets it for the duration of component
    local function accessor(...: any): any
        if select("#", ...) == 0 then
            return get_context_value(id, has_default, default_value)
        end
        
        local scope = get_scope()
        assert(scope, `cannot access context outside a stable or reactive scope`)

        local value, component = ...

        return run_in_context(scope, id, value, component)
    end

    return accessor :: Context<T>
end

return context
