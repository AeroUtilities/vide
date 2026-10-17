--* [[----------< global guards >----------]]

local typeof = if Instance then typeof else require "../test/mock".typeof :: never


--* [[----------< modules >----------]]

local flags = require "./flags"
local implicit_effect = require "./implicit_effect"
local _, is_action = require "./action"()


--* [[----------< types >----------]]

type Array<V> = { V }
type ArrayOrV<V> = {ArrayOrV<V>} | V
type Map<K, V> = { [K]: V }

type Listener = () -> ()
type ActionCallback = (Instance) -> ()
type Properties = Map<unknown, unknown>

type Cache = {
    -- event listeners to connect after properties are set
    events: Array<string | Listener>,

    -- actions to run after events are connected
    actions: Map<number, Array<ActionCallback>>,

    -- what to parent the instance to after running actions
    parent: unknown,

    -- cache to detect duplicate property setting at same nesting depth
    nested_debug: Map<number, Map<string, true> >,

    -- each nested layer occupies two indexes: 1. table ref 2. nested depth
    -- e.g. { t1 = { t3 = {} }, t2 = {} } -> { t1, 1, t2, 1, t3, 2 }
    nested_stack: { {} | number }
}


--* [[----------< cache >----------]]

-- a single cache is pooled and reused between apply calls to avoid allocations
local free_cache: Cache? = nil

-- table that creates an empty bucket the first time an index is read
local function create_lazy_bucket_map<B>(): Map<number, B>
    return setmetatable({}, {
        __index = function(self: Map<number, B>, index: number): B
            local bucket = {} :: B
            self[index] = bucket
            return bucket
        end,
    }) :: Map<number, B>
end



local function borrow_cache(): Cache
    if free_cache then
        local cache = free_cache
        free_cache = nil
        return cache
    end

    return {
        events = {},
        actions = create_lazy_bucket_map() :: Map<number, Array<ActionCallback>>,
        parent = nil,
        nested_debug = create_lazy_bucket_map() :: Map<number, Map<string, true>>,
        nested_stack = {},
    }
end



local function reset_cache(cache: Cache )
    table.clear(cache.events)
    for _, bucket in cache.actions do
        table.clear(bucket)
    end
    cache.parent = nil
    if flags.strict then table.clear(cache.nested_debug) end
    table.clear(cache.nested_stack)
end



local function return_cache(cache: Cache )
    free_cache = cache
end



--* [[----------< property processing >----------]]

local function process_properties(properties: Properties, instance: Instance, cache: Cache, depth: number)

    -- handles `Property = value` entries (string keys)
    local function process_name_property(instance: Instance, cache: Cache, property: string, value: unknown, depth: number)
        local target = instance :: any
        
        -- check for duplicate property assignment at nesting depth
        if flags.strict then 
            local seen = cache.nested_debug[depth]
            if seen[property] then
                error(`duplicate property {property} at depth {depth}`, 0)
            end
            seen[property] = true
        end
    
        if property == "Parent" then
            cache.parent = value
            return
        end
    
        -- plain values are assigned
        if type(value) ~= "function" then 
            target[property] = value
            return
        end
    
        -- functions are either events listeners or reactive property sources
        if typeof(target[property]) == "RBXScriptSignal" then
            table.insert(cache.events, property) -- add event name to buffer
            table.insert(cache.events, value :: Listener) -- add event listener to buffer
        else
            implicit_effect.property(instance, property, value :: () -> unknown) -- create implicit effect for property
        end
    end

    -- handles tables found at an index: actions, or nested property tables
    local function process_nested_table(instance: Instance, cache: Cache, nested: Properties, depth: number)
        if is_action(nested) then
            local action = nested :: any
            table.insert(cache.actions[action.priority], action.callback :: ActionCallback)
        elseif flags.defer_nested_properties then
            -- push table + depth to the stack, processed after the current layer
            table.insert(cache.nested_stack, nested)
            table.insert(cache.nested_stack, depth + 1)
        else
            process_properties(nested, instance, cache, depth + 1)
        end
    end

    -- handles array-style entries (number keys): children, actions, nested tables
    local function process_indexed_property(instance: Instance, cache: Cache, value: unknown, depth: number)
        local value_type = type(value)
    
        if value_type == "function" then
            implicit_effect.children(instance, value :: () -> ArrayOrV<Instance>)
        elseif value_type == "table" then
            process_nested_table(instance, cache, value :: Properties, depth)
        elseif value_type == "userdata" then
            local child = value :: Instance
            child.Parent = instance
        end
    end

    for key, value in properties do
        local key_type = type(key)

        if key_type == "string" then
            process_name_property(instance, cache, key :: string, value, depth)
        elseif key_type == "number" then
            process_indexed_property(instance, cache, value, depth)
        end
    end
end


-- processes the root table, then drains any deferred nested tables
local function process_all_properties(properties: Properties, instance: Instance, cache: Cache)
    local stack = cache.nested_stack
    local depth = 1
    local current: Properties? = properties

    while current do
        process_properties(current, instance, cache, depth)

        -- entries are pushed as (table, depth), so depth is popped first
        depth = table.remove(stack) :: number
        current = table.remove(stack) :: Properties?
    end
end



--* [[----------< post-processing >----------]]

local function connect_events(instance: Instance, events: Array<string | Listener>)
    local target = instance :: any

    for i = 1, #events, 2 do
        local eventName = events[i] :: string
        local listener = events[i + 1] :: Listener
        target[eventName]:Connect(listener)
    end
end



local function run_actions(instance: Instance, actions: Map<number, Array<ActionCallback>>)
    for _, bucket in actions do
        for _, callback in bucket do
            callback(instance)
        end
    end
end



local function apply_parent(instance: Instance, parent: unknown)
    if not parent then return end

    if type(parent) == "function" then
        implicit_effect.parent(instance, parent :: () -> Instance)
    else
        instance.Parent = parent :: Instance
    end
end



--* [[----------< apply >----------]]

-- applies table of nested properties to an instance using full vide semantics
local function apply<T>(instance: T & Instance, properties: Properties): T
    if not properties then
        error(`attempt to call a constructor returned by create() with no properties`)
    end

    local cache = borrow_cache()

    process_all_properties(properties, instance, cache)
    connect_events(instance, cache.events)
    run_actions(instance, cache.actions)
    apply_parent(instance, cache.parent)

    reset_cache(cache)
    return_cache(cache)

    return instance
end

return apply
