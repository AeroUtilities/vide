--* [[----------< modules >----------]]

local graph = require "./graph"


--* [[----------< graph >----------]]

local create_source_node = graph.create_source_node
local push_scope_as_child_of = graph.push_scope_as_child_of
local update_descendants = graph.update_descendants


--* [[----------< types >----------]]

-- a source is both a getter and a setter (call with 0 args to read, 1 arg to write)
export type Source<T> = (() -> T) & ((value: T) -> T)

-- source(initial) or source() with an implicit nil initial value
type CreateSource =
    (<T>(initial_value: T) -> Source<T>)
    & (<T>() -> Source<T>)


--* [[----------< source >----------]]

local function source<T>(initial_value: T): Source<T>
    local node = create_source_node(initial_value)

    local function update_source(...: T): T
        if select("#", ...) == 0 then
            -- read: track this source if called inside a reactive scope
            push_scope_as_child_of(node)
            return node.cache
        end

        local value = ... :: T

        -- skip update when the value is unchanged (tables only if frozen)
        if node.cache == value and (type(value) ~= "table" or table.isfrozen(value)) then
            return value
        end

        node.cache = value
        update_descendants(node)
        return value
    end

    return update_source
end

return source :: CreateSource
