--* [[----------< types >----------]]

-- order of Read<T> matters: () -> T comes first so that T | () -> T is treated as () -> T | T
type Read<T> = () -> T | T


--* [[----------< read >----------]]

-- returns value as-is, or calls it when given a source / thunk
local function read<T>(value: Read<T>): T
    if type(value) == "function" then
        return value()
    end

    return value :: T
end

return read
