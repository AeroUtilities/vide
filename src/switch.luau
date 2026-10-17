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

type Component<Obj> = (Getter<boolean>) -> (Obj, ...number)

type TimeoutHandle = {
    cancel: boolean,
}

type SwitchScope<Obj> = {
    destroy: () -> (),
    object: Obj,
    delay: number,
    present: Source<boolean>,
    timeout: TimeoutHandle?,
}

type SwitchOutput<Obj> = Getter<nil | Obj | Array<Obj>>


--* [[----------< switch >----------]]

local function switch_map<K, Obj>(
    input: Getter<K>,
    map: Map<K, Component<Obj>>
): SwitchOutput<Obj>
    local scopes: Map<K, SwitchScope<Obj>> = {}

    local output: Source<nil | Obj | Array<Obj>> = source(nil :: nil | Obj | Array<Obj>)

    local function update_output()
        local objects = {}

        for _, scope in scopes do
            table.insert(objects, scope.object)
        end

        output(
            if objects[2] then objects
            elseif objects[1] then objects[1]
            else nil
        )
    end

    effect(function()
        local key: K? = input()

        -- destroy (or queue destroy) scopes that are not the active key
        for k, scope in scopes do
            if k == key then
                continue
            end

            scope.present(false)

            if scope.delay == 0 then
                scope.destroy()
                scopes[k] = nil
            elseif scope.timeout == nil then
                scope.timeout = timeout(scope.delay, function()
                    scope.destroy()
                    scopes[k] = nil
                    update_output()
                end)
            end
        end

        -- create or revive the scope for the active key
        if key == nil then
            update_output()
            return
        end

        local scope = scopes[key]

        if scope then
            scope.present(true)

            if scope.timeout then
                scope.timeout.cancel = true
                scope.timeout = nil
            end
        else
            local component = map[key]

            if component ~= nil then
                if type(component) ~= "function" then
                    error("map must map a value to a function", 0)
                end

                local present = source(false)

                local delay = nil :: number?
                local destroy, object = branch(function()
                    local object, t = component(present)
                    delay = t
                    return object
                end)

                present(true)

                scopes[key] = {
                    destroy = destroy,
                    object = object,
                    delay = delay or 0,
                    present = present,
                    timeout = nil,
                }
            end
        end

        update_output()
    end)

    return output
end

local function switch<K, Obj>(input: Getter<K>): (map: Map<K, Component<Obj>>) -> SwitchOutput<Obj>
    return function(map)
        return switch_map(input, map)
    end
end

return switch
