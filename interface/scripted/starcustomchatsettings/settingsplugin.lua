-- Settings callbacks
SettingsPluginClass = {
  name = ""
}

function SettingsPluginClass:new(obj)
  local obj = obj or {}
  setmetatable(obj, self)
  self.__index = self

      -- Wrap the widget table for this instance
  local originalWidget = widget
  obj.widget = setmetatable({}, {
    __index = function(_, funcName)
      return function(widName, ...)
        local fullWidName = obj.layoutWidget .. "." .. widName
        return originalWidget[funcName](fullWidName, ...)
      end
    end
  })

  obj:_loadConfig()
  obj.getRootValue = function(...)
    return Configuration:getRootValue(obj.name, ...)
  end
  obj.getPlayerValue = function(...)
    return Configuration:getPlayerValue(obj.name, ...)
  end
  obj.setRootValue = function(parameter, value)
    world.sendEntityMessage(player.id(), "scc_set_settings", {
      pluginName = obj.name,
      scope = "root",
      parameter = parameter,
      value = value
    })
  end
  obj.setPlayerValue = function(...)
    world.sendEntityMessage(player.id(), "scc_set_settings", {
      pluginName = obj.name,
      scope = "player",
      parameter = parameter,
      value = value
    })
  end
  return obj
end

-- Warning: it is called BEFORE the init.
function SettingsPluginClass:isAvailable()
  return true
end

function SettingsPluginClass:_loadConfig()
  local parms = config.getParameter("pluginParameters")[self.name]
  if parms then
    for name, value in pairs(parms) do 
      self[name] = value
    end
  end
  self.chatConfig = config.getParameter("chatConfig")
  self.layoutWidget = "lytPluginSettings." .. self.name
end

function SettingsPluginClass:init()
  
end

function SettingsPluginClass:__openTab()
  if not self.opened then
    self.opened = true
    return self:openTab()
  end
end

function SettingsPluginClass:openTab()

end

function SettingsPluginClass:update(dt)
  
end

function SettingsPluginClass:_callback(callbackInfo, widgetName, widgetData)
  if callbackInfo and callbackInfo.pluginName and callbackInfo.pluginName == self.name and self[callbackInfo.callback] then
    widgetData["actualPluginCallback"] = nil
    self[callbackInfo.callback](self, widgetName, widgetData)
  end
end

function SettingsPluginClass:_textBoxCallback(callbackInfo, widgetName, widgetData, callbackType)
  if callbackInfo and callbackInfo.pluginName and callbackInfo.pluginName == self.name then
    widgetData["actualPluginCallback"] = nil
    if self[callbackInfo[callbackType]] then
      self[callbackInfo[callbackType]](self, widgetName, widgetData)
    end
  end
end

function SettingsPluginClass:_spinner_callback(callbackInfo, direction, widgetName, widgetData)
  if callbackInfo and callbackInfo.pluginName and callbackInfo.pluginName == self.name and self[callbackInfo.callback] then
    widgetData["actualPluginCallback"] = nil
    self[callbackInfo.callback][direction](self, widgetName, widgetData)
  end
end

function SettingsPluginClass:_canvasClick(position, button, isDown)
  if self["clickCanvasCallback"] then
    self["clickCanvasCallback"](self, position, button, isDown)
  end
end

function SettingsPluginClass:onLocaleChange(localeConfig)
  
end

function SettingsPluginClass:cursorOverride(screenPosition)
  
end

function SettingsPluginClass:save(localeConfig)

end

function SettingsPluginClass:uninit()

end