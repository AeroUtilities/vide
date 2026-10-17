--* [[----------< modules >----------]]

local source = require "./source"
local derive = require "./derive"
local effect = require "./effect"
local switch = require "./switch"


--* [[----------< types >----------]]

type Array<T> = { T }
type Map<K, V> = { [K]: V }

-- read-only view: users pass plain functions, derives or sources, and get one back
type Getter<T> = () -> T

type Component<T, Obj> = (Getter<T>, Getter<boolean>) -> (Obj, ...number)
type Fallback<Obj> = (Getter<boolean>) -> (Obj, ...number)
type ShowOutput<Obj> = Getter<nil | Obj | Array<Obj>>


--* [[----------< show >----------]]

-- shows component when input is truthy; optional fallback when falsey
local function show<T, Obj>(
    input: Getter<T?>,
    component: Component<T, Obj>,
    fallback: Fallback<Obj>?
): ShowOutput<Obj>
    -- holds the last truthy value so the component still has data while present
    local filtered_input: source.Source<T> = source()

    effect(function()
        local value = input()
        if value then
            filtered_input(value)
        end
    end)

    local input_is_truthy = derive(function()
        return not not input()
    end)

    local cases: Map<boolean, Fallback<Obj>> = {
        [true] = function(present)
            return component(filtered_input, present)
        end,
    }

    if fallback then
        cases[false] = fallback
    end

    return switch(input_is_truthy)(cases)
end

return show
