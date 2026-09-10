__Config = {}

function __Config:init()
    local obj = {}

    setmetatable(obj, self)
    self.__index = self

    self:reset()
    return obj
end

function __Config:_checkScope(scope)
    if not scope then error("No scope prpvided") return end
    self.rootParameters[scope] = self.rootParameters[scope] or {}
    self.playerParameters[scope] = self.playerParameters[scope] or {}
end

function __Config:getRootValue(scope, parameter)
    self:_checkScope(scope)

    if parameter and type(parameter) == "string" then
        local oldValue = root.getConfiguration(parameter)

        if oldValue then
            root.setConfiguration(parameter, nil)

            if not self.rootParameters[scope][parameter] then
                self.rootParameters[scope][parameter] = oldValue
            end
        end

        return self.rootParameters[scope][parameter]
    else
        return nil
    end
end

function __Config:setRootValue(scope, parameter, value)
    self:_checkScope(scope)

    if parameter and type(parameter) == "string" then
        if root.getConfiguration(parameter) then
            root.setConfiguration(parameter, nil)
        end

        if not self.rootParameters[scope][parameter] or self.rootParameters[scope][parameter] ~= value then
            self.rootParameters[scope][parameter] = value
            self.pendingChanges = true
        end
    end
end

function __Config:getPlayerValue(scope, parameter)
    self:_checkScope(scope)

    if parameter and type(parameter) == "string" then
        local oldValue = player.getProperty(parameter)
        if oldValue then
            player.setProperty(parameter, nil)

            if not self.playerParameters[scope][parameter] then
                self.playerParameters[scope][parameter] = oldValue
            end
        end

        return self.playerParameters[scope][parameter]
    else
        return nil
    end
end

function __Config:setPlayerValue(scope, parameter, value)
    self:_checkScope(scope)

    if parameter and type(parameter) == "string" then
        if player.getProperty(parameter) then
            player.setProperty(parameter, nil)
        end

        if not self.playerParameters[scope][parameter] or self.playerParameters[scope][parameter] ~= value then
            self.playerParameters[scope][parameter] = value
            self.pendingChanges = true
        end
    end
end

function __Config:hasPendingChanges()
    return self.pendingChanges
end

function __Config:save()
    root.setConfiguration("SCC", self.rootParameters)
    player.setProperty("SCC", self.playerParameters)
    self.pendingChanges = false
end

function __Config:reset()
    self.pendingChanges = false
    self.rootParameters = root.getConfiguration("SCC") or {}
    self.playerParameters = player.getProperty("SCC") or {}
end