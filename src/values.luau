--* [[----------< modules >----------]]

local flags = require "./flags"
local branch = require "./branch"
local source = require "./source"
local effect = require "./effect"
local timeout = require "./timeout"()


--* [[----------< types >----------]]

type Array<T> = { T }
type Map<K, V> = { [K]: V }
type Source<T> = source.Source<T>

type TimeoutHandle = {
    cancel: boolean,
}

-- keyed by value (not index); each distinct value gets one scope
type ValueScope<K, Obj> = {
    destroy: () -> (),
    object: Obj,
    index: K?,
    index_source: Source<K>,
    count: number,
    delay: number,
    present: Source<boolean>,
    timeout: TimeoutHandle?,
}


--* [[----------< values >----------]]

local function values<K, V, Obj>(
    input: Source<Map<K, V>>,
    component: (V, Source<K>, Source<boolean>) -> (Obj, ...number)
): Source<Array<Obj>>
    local update_count = 0
    local scopes: Map<V, ValueScope<K, Obj>> = {}

    local output: Source<Array<Obj>> = source({} :: Array<Obj>)

    local function update_output()
        local objects = table.create(4)

        for _, scope in scopes do
            table.insert(objects, scope.object)
        end

        output(objects)
    end

    effect(function()
        local data = input()

        local count = update_count
        update_count += 1

        local children_need_update = false -- true if a scope is created or destroyed

        if flags.strict then
            local seen = {}
            for _, v in data do
                if seen[v] then
                    error("table source passed to `values()` contains duplicate values", 0)
                end
                seen[v] = true
            end
        end

        -- create or update scopes
        for i, v in data do
            local scope = scopes[v]

            if scope == nil then
                local index_source = source(i)
                local present = source(false)

                local delay = nil :: number?
                local destroy, object = branch(function()
                    local object, t = component(v, index_source, present)
                    delay = t
                    return object
                end)

                present(true)

                children_need_update = true

                scopes[v] = {
                    destroy = destroy,
                    object = object,
                    index = i,
                    index_source = index_source,
                    count = count,
                    delay = delay or 0,
                    present = present,
                    timeout = nil,
                }
            else
                scope.count = count

                if scope.index ~= i then
                    if scope.timeout then -- value is back in the input; cancel destruction
                        scope.timeout.cancel = true
                        scope.timeout = nil
                        scope.present(true)
                    end

                    scope.index = i
                    scope.index_source(i)
                end
            end
        end

        -- destroy scopes whose values left the input table
        for v, scope in scopes do
            if scope.count < count then
                scope.present(false)

                if scope.delay == 0 then
                    scope.destroy()
                    scopes[v] = nil
                    children_need_update = true
                else
                    scope.index = nil -- so a later reappear hits the `scope.index ~= i` path
                    if scope.timeout == nil then
                        scope.timeout = timeout(scope.delay, function() -- todo: possible redundant updates
                            scope.destroy()
                            scopes[v] = nil
                            update_output()
                        end)
                    end
                end
            end
        end

        if children_need_update then
            update_output()
        end
    end)

    return output
end

return values
