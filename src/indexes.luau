--* [[----------< modules >----------]]

local branch = require "./branch"
local source = require "./source"
local effect = require "./effect"
local timeout = require "./timeout"()


--* [[----------< types >----------]]

type Array<T> = { T }
type Map<K, V> = { [K]: V }
type Source<T> = source.Source<T>

-- read-only view: users pass plain functions, derives or sources, and get one back
type Getter<T> = () -> T

type TimeoutHandle = {
    cancel: boolean,
}

type IndexScope<V, Obj> = {
    destroy: () -> (),
    object: Obj,
    value: V?,
    value_source: Source<V>,
    count: number,
    delay: number,
    present: Source<boolean>,
    timeout: TimeoutHandle?,
}


--* [[----------< indexes >----------]]

local function indexes<K, V, Obj>(
    input: Getter<Map<K, V>>,
    component: (Getter<V>, K, Getter<boolean>) -> (Obj, ...number)
): Getter<Array<Obj>>
    local update_count = 0
    local scopes: Map<K, IndexScope<V, Obj>> = {}

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

        -- create or update scopes
        for i, v in data do
            local scope = scopes[i]

            if scope == nil then
                local value_source = source(v)
                local present = source(false)

                local delay = nil :: number?
                local destroy, object = branch(function()
                    local object, t = component(value_source, i, present)
                    delay = t
                    return object
                end)

                present(true)

                children_need_update = true

                scopes[i] = {
                    destroy = destroy,
                    object = object,
                    value = v,
                    value_source = value_source,
                    count = count,
                    delay = delay or 0,
                    present = present,
                    timeout = nil,
                }
            else
                scope.count = count

                if scope.value ~= v then
                    if scope.timeout then -- index is back in the input; cancel destruction
                        scope.timeout.cancel = true
                        scope.timeout = nil
                        scope.present(true)
                    end

                    scope.value = v
                    scope.value_source(v)
                end
            end
        end

        -- destroy scopes whose indexes left the input table
        for i, scope in scopes do
            if scope.count < count then
                scope.present(false)

                if scope.delay == 0 then
                    scope.destroy()
                    scopes[i] = nil
                    children_need_update = true
                else
                    scope.value = nil -- so a later reappear hits the `scope.value ~= v` path
                    if scope.timeout == nil then
                        scope.timeout = timeout(scope.delay, function() -- todo: possible redundant updates
                            scope.destroy()
                            scopes[i] = nil
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

return indexes
