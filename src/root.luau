--* [[----------< modules >----------]]

local graph = require "./graph"


--* [[----------< types >----------]]

type Destroy = () -> ()
type Traceback = (string?) -> string
type RootFn<T...> = (destroy: Destroy) -> T...
type Root = <T...>(fn: RootFn<T...>) -> (Destroy, T...)


--* [[----------< graph >----------]]

local create_node = graph.create_node
local push_scope = graph.push_scope
local pop_scope = graph.pop_scope
local destroy_node = graph.destroy


--* [[----------< state >----------]]

-- strong refs so root nodes are not collected while alive
local refs: { [graph.Node<any>]: true } = {}


--* [[----------< root >----------]]

-- creates a stable root scope; returns a destroyer plus any values returned by fn
local function root<T...>(fn: RootFn<T...>): (Destroy, T...)
    local node = create_node(false, false, false)
    local traceback = debug.traceback :: Traceback

    refs[node] = true

    local function destroy()
        if not refs[node] then
            error("root already destroyed", 0)
        end

        refs[node] = nil
        destroy_node(node)
    end

    push_scope(node)

    local result = { xpcall(fn, traceback, destroy) }

    pop_scope()

    if not result[1] then
        destroy()
        error(`error while running root():\n\n{result[2]}`, 0)
    end

    return destroy, unpack(result :: any, 2)
end

return root :: Root
