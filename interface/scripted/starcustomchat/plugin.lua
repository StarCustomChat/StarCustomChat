-- base.lua

PluginClass = {
  name = "",
  styleResolvingCallbacks = {
    formatIncomingMessage = true,
    formatOutcomingMessage = true,
    editMessage = true
  }
}

function PluginClass:new(obj)
    local obj = obj or {}
    setmetatable(obj, self)
    self.__index = self

    if not obj.name or obj.name == "" then
      error("SCC: Plugin with the empty name is being registered")
      return
    end

    obj.getRootValue = function(...)
      return Configuration:getRootValue(obj.name, ...)
    end
    obj.getPlayerValue = function(...)
      return Configuration:getPlayerValue(obj.name, ...)
    end
    obj.setRootValue = function(...)
      return Configuration:setRootValue(obj.name, ...)
    end
    obj.setPlayerValue = function(...)
      return Configuration:setPlayerValue(obj.name, ...)
    end
    return obj
end

function PluginClass:init(chat)
  self.customChat = chat
  self:_loadConfig()
end

function PluginClass:_loadConfig()
  local parms = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", self.name, self.name)).parameters
  if parms then
    for name, value in pairs(parms) do 
      self[name] = value
    end
  end
end

function PluginClass:_requestStagehandHandlers()
  if self.stagehandType and self.stagehandType ~= "" then
    starcustomchat.utils.runWhenPlayerReady(function()
      starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "requestHandlers", data = {playerId = player.id()}})
    end)
  end
end

function PluginClass:_requestCommands()
  if self.stagehandType and self.stagehandType ~= "" then
    starcustomchat.utils.runWhenPlayerReady(function()
      starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "requestCommands", data = {playerId = player.id()}})
    end)
  end
end

function PluginClass:runCallbacks(plugins, method, ...)
  local result = nil
  for _, plugin in ipairs(plugins) do
    result = plugin[method](plugin, ...) or result
  end
  if self.styleResolvingCallbacks[method] then
    result = starcustomchat.utils.resolveStyleStack(result)
  end
  return result
end

function PluginClass:update(dt)

end

function PluginClass:processEvents(events)

end

function PluginClass:openSettings(settingsConfig)
  return settingsConfig
end

function PluginClass:registerMessageHandlers()

end

function PluginClass:onChatScroll(screenPosition)
  return false
end

function PluginClass:onCanvasClick(screenPosition, button, isButtonDown)
  return false
end

function PluginClass:addCustomCommandPreview(availableCommands, substr)

end

function PluginClass:resolvePlayerData(playerData)
  return playerData
end

function PluginClass:onSendMessage(message)

end

function PluginClass:onReceiveMessage(message)

end

function PluginClass:onModeChange(mode)

end

function PluginClass:onModeToggle(mode, isChecked)

end

function PluginClass:onTextboxCallback(chatText)

end

function PluginClass:afterTextboxPressed()

end

function PluginClass:preventTextboxCallback(message)
  return false
end

function PluginClass:onTextboxEscape()
  -- Do nothing
  return false
end

function PluginClass:onTextboxEnter(message)
  -- Do nothing
  return false
end

function PluginClass:formatIncomingMessage(message)
  return message
end

function PluginClass:formatOutcomingMessage(message)
  return message
end

function PluginClass:editMessage(message)
  return self:formatIncomingMessage(message)
end

--[[
  Called after the base text/image height is known but before the message is
  drawn. Plugins may reserve space by mutating drawData:
    bodyOffset: shifts the base text/image down
    bodyHeight: height before the avatar and bottom decorations
    height: final message height
]]
function PluginClass:onMeasureMessage(message, drawData)

end

-- Called for visible messages after their final offset and height are known.
function PluginClass:onDrawMessage(message, drawData)

end

function PluginClass:onSettingsUpdate(data)

end

function PluginClass:onLocaleChange()

end

function PluginClass:onCursorOverride(screenPosition)
  
end

function PluginClass:onCreateTooltip(screenPosition)
  
end

function PluginClass:onProcessCommand(text)
  return false
end

function PluginClass:onCustomButtonClick(buttonName, data)

end

function PluginClass:onCustomButtonClick2(buttonName, data)

end

function PluginClass:onCustomButtonClick3(buttonName, data)

end

function PluginClass:onSubMenuReopen(type)

end

function PluginClass:onSubMenuClose()

end

function PluginClass:registerStagehandHandlers(messageTypes)

end

function PluginClass:cleanMessage(message)

end

function PluginClass:showDots()
  return false
end

function PluginClass:uninit()

end

--[[
  Context menu
]]
function PluginClass:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  return false
end

function PluginClass:contextMenuReset()

end

function PluginClass:contextMenuButtonClick(buttonName, selectedMessage)

end
