require "/interface/scripted/starcustomchat/plugin.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

typing = PluginClass:new(
  { name = "typing" }
)

function typing:init(chat)
  PluginClass.init(self, chat)

  self.sendTypingIndicatorTime = 0
  self.addTypingEntityMessageName = "scc_add_typing_indicator"
  self.removeTypingEntityMessageName = "scc_remove_typing_indicator"
  
  self.indicatorImageSize = root.imageSize(self.overlayImage .. ":1")
  self.typingPlayers = {}
  self.typingFrameTime = 0

  self:onSettingsUpdate()

end

function typing:registerMessageHandlers()
  starcustomchat.utils.setMessageHandler( self.addTypingEntityMessageName, function(_, _, data)
    if not self.typingPlayers[data.connection] then
      data.time = 0
      self.typingPlayers[data.connection] = data
    else
      self.typingPlayers[data.connection].time = 0
    end
  end)

  starcustomchat.utils.setMessageHandler( self.removeTypingEntityMessageName, function(_, _, data)
    if self.typingPlayers[data.connection] then
      self.typingPlayers[data.connection] = nil
    end
  end)
end


function typing:buildTypingText(typingPlayers)
  local typingPlayerEntries = {}
  local localPosition = world.entityPosition(player.id())

  for connection, playerData in pairs(typingPlayers or {}) do
    local entityId = playerData.entityId or playerData.id

    if entityId and world.entityExists(entityId) or entityId == 0 then
      local entityPosition = world.entityPosition(entityId == 0 and player.id() or entityId)  -- if it's a server, the position of the server is the same as the player
      if entityPosition then
        local distance = world.magnitude(entityPosition, localPosition)
        table.insert(typingPlayerEntries, {
          name = self.customChat.callbackPlugins("resolvePlayerData", playerData).name or "Unknown",
          distance = distance,
          id = entityId
        })
      end
    end
  end

  table.sort(typingPlayerEntries, function(a, b)
    return a.distance < b.distance
  end)

  local typingPlayerCount = #typingPlayerEntries
  local typingPlayerNames = {}
  for _, entry in ipairs(typingPlayerEntries) do
    table.insert(typingPlayerNames, entry.name)
  end

  if typingPlayerCount == 0 then
    return nil
  elseif typingPlayerCount == 1 then
    return starcustomchat.utils.getTranslation("chat.typing.typing_one", typingPlayerNames[1])
  elseif typingPlayerCount < 4 then
    local firstNames = {}
    for i = 1, typingPlayerCount - 1 do
      table.insert(firstNames, typingPlayerNames[i])
    end
    return starcustomchat.utils.getTranslation("chat.typing.typing_few", table.concat(firstNames, ", "), typingPlayerNames[typingPlayerCount])
  end

  return starcustomchat.utils.getTranslation("chat.typing.typing_multiple")
end

function typing:onTextboxCallback()
  if self.sendTypingIndicatorTime <= 0 then
    local players = starcustomchat.utils.playersInRadius(self.playerRadius, true, true)

    for _, pl in ipairs(players) do 
      world.sendEntityMessage(pl, self.addTypingEntityMessageName, starcustomchat.utils.playerData())
    end

    self.sendTypingIndicatorTime = self.typingResendInterval
  end
end

function typing:preventTextboxCallback(message)
  local players = starcustomchat.utils.playersInRadius(self.playerRadius, true, true)
  
  for _, pl in ipairs(players) do 
    world.sendEntityMessage(pl, self.removeTypingEntityMessageName, starcustomchat.utils.playerData())
  end
end

function typing:onTextboxEscape(message)
  local players = starcustomchat.utils.playersInRadius(self.playerRadius, true, true)
  
  for _, pl in ipairs(players) do 
    world.sendEntityMessage(pl, self.removeTypingEntityMessageName, starcustomchat.utils.playerData())
  end
end

function typing:update(dt)

  -- Client part: resend interval for everyone
  self.sendTypingIndicatorTime = math.max(0, self.sendTypingIndicatorTime - dt)

  -- Server part: if the time runs out from the person, remove them from the list
  for playerConn, playerData in pairs(self.typingPlayers) do 
    self.typingPlayers[playerConn].time = self.typingPlayers[playerConn].time + dt

    if self.typingPlayers[playerConn].time > self.typingResendInterval * 2 then
      self.typingPlayers[playerConn] = nil
    end
  end

  if next(self.typingPlayers) ~= nil then
    self.typingFrameTime = self.typingFrameTime + dt
    local typingFrame = (math.floor(self.typingFrameTime / self.dotsSpeed) % self.overlayImageFrames) + 1

    -- Drawing part: we need to draw the message if the typing is here. It should ALWAYS be the last one, and only in modern mode
    if self.portraitDots and self.customChat.chatMode == "modern" then

      for i = #self.customChat.drawnMessageIndexes, 1, -1 do 
        local message = self.customChat.messages[self.customChat.drawnMessageIndexes[i]]

        if message.connection and self.typingPlayers[message.connection] and message.avatar 
          and self.customChat:isInsideChat(message, message.offset, 0, self.customChat.canvas:size()) 
          and message.mode ~= "CommandResult" then
          
          -- Copied from self.customChat:drawImage
          local size = portraitSizeFromBaseFont(self.customChat.config.fontSize)
          local offset
          if message.avatarOffset then
            offset = vec2.add(message.avatarOffset, self.customChat.config.iconImageOffset)
          else
            offset = vec2.add(self.customChat.config.iconImageOffset, {0, message.offset})
            offset[2] = offset[2] + message.height - self.customChat.config.spacings.name - (self.customChat.config.fontSize * 2) - 1
            if message.replyUUID then
              offset[2] = offset[2] - self.customChat.config.replyOffsetHeight * self.customChat.config.fontSize / 10
            end
          end
          self.customChat.topCanvas:drawImageRect(self.overlayImage .. ":" .. typingFrame, {0, 0, self.indicatorImageSize[1], self.indicatorImageSize[2]}, {offset[1], offset[2], offset[1] + size, offset[2] + size})
        end
      end
    end
    
    -- Text part
    if self.statusField then
      local typingText = self:buildTypingText(self.typingPlayers)
      if typingText then
        self.customChat:setInformationalText(typingText .. string.rep(".", typingFrame))
      else
        self.typingFrameTime = 0
        self.customChat:resetInformationalText()
      end
    end
  else
    self.typingFrameTime = 0
    self.customChat:resetInformationalText()
  end
end

function typing:onSettingsUpdate()
  self.portraitDots = root.getConfiguration("scc_typing_portrait")
  if self.portraitDots == nil then
    self.portraitDots = true
  end

  self.statusField = root.getConfiguration("scc_typing_status")
  if self.statusField == nil then
    self.statusField = true
  end
  self.customChat:resetInformationalText()
end