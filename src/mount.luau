--* [[----------< modules >----------]]

local root = require "./root"
local apply = require "./apply"


--* [[----------< types >----------]]

type Destroy = () -> ()
type Component<T> = () -> T

-- mount(component, target) — result is applied as a child of target
type MountWithTarget = <T>(component: Component<T>, target: Instance) -> Destroy

-- mount(component) — run the component in a root with no host instance
type MountWithoutTarget = (component: Component<unknown>) -> Destroy

type Mount = MountWithTarget & MountWithoutTarget


--* [[----------< mount >----------]]

-- runs component inside a root; if target is given, parents the result under it
local function mount<T>(component: Component<T>, target: Instance?): Destroy
    return root(function()
        local result = component()
        if target then
            apply(target, { result })
        end
    end)
end

return mount :: Mount
