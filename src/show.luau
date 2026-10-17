--* [[----------< modules >----------]]

local source = require "./source"
local derive = require "./derive"
local effect = require "./effect"
local switch = require "./switch"
local read = require "./read"


--* [[----------< types >----------]]

type Array<T> = { T }
type Map<K, V> = { [K]: V }
type Source<T> = source.Source<T>

type Present = Source<boolean>
type Component<T, Obj> = (Source<T>, Present) -> (Obj, ...number)
type Fallback<Obj> = (Present) -> (Obj, ...number)
type ShowOutput<Obj> = Source<nil | Obj | Array<Obj>>


--* [[----------< show >----------]]

-- shows component when input is truthy; optional fallback when falsey
local function show<T, Obj>(
    input: Source<T?>,
    component: Component<T, Obj>,
    fallback: Fallback<Obj>?
): ShowOutput<Obj>
    -- holds the last truthy value so the component still has data while present
    local filtered_input = source()

    effect(function()
        -- read() disambiguates Source get vs set under the new solver
        local value = read(input)
        if value then
            filtered_input(value)
        end
    end)

    local input_is_truthy = derive(function()
        return not not read(input)
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
