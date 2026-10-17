--* [[----------< constants >----------]]

local VERSION = { major = 0, minor = 4, patch = 1 }
local NIL = (nil :: any)


--* [[----------< modules >----------]]

local root = require "./root"
local mount = require "./mount"
local create = require "./create"
local apply = require "./apply"
local implicit_effect = require "./implicit_effect"
local source = require "./source"
local effect = require "./effect"
local derive = require "./derive"
local cleanup = require "./cleanup"
local untrack = require "./untrack"
local read = require "./read"
local batch = require "./batch"
local context = require "./context"
local switch = require "./switch"
local show = require "./show"
local indexes = require "./indexes"
local values = require "./values"
local spring, update_springs = require "./spring"()
local action = require "./action"()
local changed = require "./changed"
local _, update_timeouts = require "./timeout"()
local flags = require "./flags"


--* [[----------< types >----------]]

export type Source<T> = source.Source<T>
export type source<T> = Source<T>
export type Context<T> = context.Context<T>
export type context<T> = Context<T>
export type Instances = create.Instances
export type Properties<T> = create.Properties<T>
export type Children = implicit_effect.Children


--* [[----------< runtime >----------]]

local function step(dt: number)
    if debug.profilebegin then 
        debug.profilebegin("Vide: step") 
    end

    if debug.profilebegin then 
        debug.profilebegin("Vide: spring") 
    end
    update_springs(dt)
    if debug.profileend then 
        debug.profileend() 
    end

    if debug.profilebegin then 
        debug.profilebegin("Vide: scheduler") 
    end
    update_timeouts(dt)
    if debug.profileend then 
        debug.profileend() 
    end

    if debug.profileend then 
        debug.profileend() 
    end
end

local stepped = game and game:GetService("RunService").Heartbeat:Connect(function(dt: number)
    task.defer(step, dt)
end) :: RBXScriptConnection? -- cast to `RBXScriptConnection?` if game is available


--* [[----------< vide >----------]]

local vide = {
    version = VERSION,

    -- core
    root = root,
    mount = mount,
    create = create,
    source = source,
    effect = effect,
    derive = derive,
    switch = switch,
    show = show,
    indexes = indexes,
    values = values,

    -- util
    cleanup = cleanup,
    untrack = untrack,
    read = read,
    batch = batch,
    context = context,

    -- animations
    spring = spring,

    -- actions
    action = action,
    changed = changed,

    -- flags (resolved through the metatable below)
    strict = NIL :: boolean,
    defaults = NIL :: boolean,
    defer_nested_properties = NIL :: boolean,

    -- temporary
    apply = function(instance: Instance)
        return function(props: { [any]: any })
            apply(instance, props)
            return instance
        end
    end,

    -- runtime
    step = function(dt: number)
        if stepped then
            stepped:Disconnect()
            stepped = nil
        end
        step(dt)
    end,
}

setmetatable(vide :: any, {
    __index = function(_, key: string): boolean
        local flag = (flags :: any)[key]
        if flag == nil then
            error(`{key} is not a valid member of vide`, 0)
        end
        return flag
    end,

    __newindex = function(_, key: string, value: boolean)
        if (flags :: any)[key] == nil then
            error(`{key} is not a valid member of vide`, 0)
        end
        ;(flags :: any)[key] = value
    end,
})

return vide
