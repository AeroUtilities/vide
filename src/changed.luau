--* [[----------< modules >----------]]

local action = require "./action"()
local cleanup = require "./cleanup"


--* [[----------< types >----------]]

type ChangedCallback<T> = (T) -> ()


--* [[----------< changed >----------]]

local function changed<T>(property: string, callback: ChangedCallback<T>)
    return action(function(instance)
        local target = instance :: any
        local connection = instance:GetPropertyChangedSignal(property):Connect(function()
            callback(target[property])
        end)

        cleanup(function()
            connection:Disconnect()
        end)

        callback(target[property])
    end)
end

return changed
