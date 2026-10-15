local root = require "./root"
local apply = require "./apply"

type Destructor = () -> ()
type Component<T> = () -> T

type Mount = (<T>(component: Component<T>, target: Instance) -> Destructor) & ((component: () -> ()) -> Destructor)

local function mount<T>(component: Component<T>, target: Instance?): Destructor
    return root(function()
        local result = component()
        if target then apply(target, { result }) end
    end)
end

return mount :: Mount
