--* [[----------< modules >----------]]

local graph = require "./graph"


--* [[----------< types >----------]]

type Destroy = () -> ()
type Callback<T> = () -> T
type Traceback = (string?) -> string


--* [[----------< graph >----------]]

local create_node = graph.create_node
local push_scope = graph.push_scope
local pop_scope = graph.pop_scope
local destroy = graph.destroy
local get_scope = graph.get_scope


--* [[----------< branch >----------]]

-- runs fn inside a new child node of the current scope
-- returns a function that destroys the branch, followed by fn's result
local function branch<T>(fn: Callback<T>): (Destroy, T)
    local current = get_scope()
    local traceback = debug.traceback :: Traceback

    if not current then
        error(`cannot use branch() outside a stable or reactive scope`, 0)
    end

    local parent = current.owner
    if not parent then
        error(`current scope is not owned by a scope`, 0)
    end

    local node = create_node(parent, false, false)
    local destroy_branch = function()
        destroy(node)
    end

    push_scope(node)
    local ok, result = xpcall(fn, traceback)
    pop_scope()

    -- destroy the node if the function fails
    if not ok then
        destroy_branch()
        error(`error while running branch():\n\n{result}`, 0)
    end

    return destroy_branch, result
end

return branch
