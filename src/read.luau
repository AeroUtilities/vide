local function read<T>(value: T | () -> T): T
    if type(value) == "function" then
        return (value :: () -> T)()
    end
    return value :: T
end

return read
