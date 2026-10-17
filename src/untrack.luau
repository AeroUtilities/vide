--* [[----------< modules >----------]]

local graph = require "./graph"


--* [[----------< types >----------]]

type Traceback = (string?) -> string
type Untrack =
    (<T>(fn: () -> T) -> T)
    & ((fn: () -> ()) -> ())


--* [[----------< graph >----------]]

local get_scope = graph.get_scope


--* [[----------< untrack >----------]]

-- runs fn without tracking source reads in the current reactive scope
local function untrack<T>(source: () -> T): T
    local scope = get_scope()

    if not scope then
        return source()
    end

    -- sources are only tracked when the scope node has an effect
    local effect = scope.effect
    scope.effect = false

    local traceback = debug.traceback :: Traceback
    local ok, result = xpcall(source, traceback)

    scope.effect = effect

    if not ok then
        error(result, 0)
    end

    return result :: T
end

return untrack :: Untrack
