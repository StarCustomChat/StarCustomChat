require "/interface/scripted/starcustomchat/plugin.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

reply = PluginClass:new(
  { name = "reply" }
)

function reply:init(chat)
  PluginClass.init(self, chat)

  self.replyingToMessage = config.getParameter("replyingToMessage")

  if self.replyingToMessage then
    local targetName = starcustomchat.utils.getTranslation("chat.reply.recipient", self.replyingToMessage.displayName or self.replyingToMessage.nickname)
    self.customChat:openSubMenu("reply", targetName, self:cropMessage(targetName, string.gsub(self.replyingToMessage.text, "\n", "    ")))
  end
  self.messagesToReply = {}

  self.highlightMessageInd = nil
  self.desaturateTime = 0

  self.stagehandEnabled = false
end

function reply:registerStagehandHandlers(handlers)
  self.stagehandEnabled = handlers and handlers["addReply"]
end

function reply:registerMessageHandlers()
  starcustomchat.utils.setMessageHandler( "scc_add_relpy", function(_, _, data)
    if data and data.originalMessageUUID  then
      local oldMessageInd = self.customChat:findMessageByUUID(data.originalMessageUUID)
      local newMessageInd = self.customChat:findMessageByUUID(data.newMessageUUID)

      if newMessageInd and oldMessageInd then
        self.customChat.messages[newMessageInd].replyUUID = data.originalMessageUUID
        self.customChat:processQueue()
      elseif oldMessageInd then
        self.messagesToReply[data.newMessageUUID] = data.originalMessageUUID
      end
    end
  end)
end

function reply:onReceiveMessage(message)
  if self.messagesToReply[message.uuid] or (message.data and message.data.replyUUID) then
    message.replyUUID = self.messagesToReply[message.uuid] or message.data.replyUUID
    self.messagesToReply[message.uuid] = nil
  end
end

function reply:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  if selectedMessage and buttonName == "reply" then
    return selectedMessage.mode ~= "CommandResult" and selectedMessage.mode ~= "Whisper"
  end
end

function reply:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage and selectedMessage.uuid and buttonName == "reply" then
    self.replyingToMessage = selectedMessage
    local targetName = starcustomchat.utils.getTranslation("chat.reply.recipient", selectedMessage.displayName or selectedMessage.nickname)
    self.customChat:openSubMenu("reply", targetName, self:cropMessage(targetName, string.gsub(selectedMessage.text, "\n", "    ")))
    self.customChat:focusInput()
  end
end

function reply:onMeasureMessage(message, drawData)
  local previousMessageIndex = message.replyUUID and self.customChat:findMessageByUUID(message.replyUUID)
  if not previousMessageIndex then
    return
  end

  local replyOffset = self.customChat.config.replyOffsetHeight * self.customChat.config.fontSize / 10
  drawData.reply = {
    previousMessageIndex = previousMessageIndex,
    height = replyOffset
  }
  drawData.height = drawData.height + replyOffset
end

function reply:onDrawMessage(message, drawData)
  local replyData = drawData.reply
  if not replyData then
    return
  end

  local chat = self.customChat
  local previousMessage = chat.messages[replyData.previousMessageIndex]
  if not previousMessage then
    return
  end

  local size = portraitSizeFromBaseFont(chat.config.fontSize)
  local xOffset = chat.chatMode == "modern" and chat.config.nameOffset[1] + size or chat.config.textOffsetCompactMode[1]
  local replyStartOffset = vec2.add({
    xOffset,
    drawData.messageOffset + drawData.bodyHeight + drawData.avatarOffset
  }, chat.config.replyImageOffset)

  chat.canvas:drawImage("/interface/scripted/starcustomchat/plugins/reply/reply.png",
    replyStartOffset, 1 / 8 * chat.config.fontSize)

  local croppedText = string.format("%s: %s", previousMessage.displayName or previousMessage.nickname,
    starcustomchat.utils.cropMessage(starcustomchat.utils.clearMetatags(previousMessage.text), chat.canvas:size()[1] // 10))

  chat.canvas:drawText(string.gsub(croppedText, "\n", "    "), {
    position = vec2.add(replyStartOffset, {size / 2, 0}),
    horizontalAnchor = "left",
    verticalAnchor = "bottom"
  }, chat.config.fontSize / 1.2, chat:getColor("replytext"), nil, chat:getFont("chattext"))
end

function reply:cropMessage(targetName, text)
  local cleanText = starcustomchat.utils.clearMetatags(text)
  local cleanTargetName = starcustomchat.utils.clearMetatags(targetName)
  local finalText = cleanTargetName .. cleanText
  return utf8.len(finalText) < self.trimLength and cleanText or starcustomchat.utils.utf8Substring(cleanText, 1, self.trimLength - utf8.len(cleanTargetName)) .. "..."
end

function reply:onSubMenuClose()
  if self.replyingToMessage then
    self.replyingToMessage = nil
  end
end

function reply:onTextboxEnter()
  if self.replyingToMessage then
    local mode = widget.getSelectedData("rgChatMode").mode
    local nickname = player.name()

    local futureMessage = self.customChat.callbackPlugins("formatOutcomingMessage", {
      text = self.customChat:getText(),
      connection = starcustomchat.utils.entityIdToConnection(player.id()),
      mode = mode,
      nickname = nickname
    })

    local dataToSend = {
      originalMessageUUID = self.replyingToMessage.uuid,
      newMessageUUID = self.customChat:calculateUUID({
        connection = starcustomchat.utils.entityIdToConnection(player.id()), text = futureMessage.text, 
        mode = mode, nickname = nickname
      }) 
    }

    if self.stagehandEnabled and self.stagehandType and self.stagehandType ~= "" then
      starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "addReply", data = dataToSend})
    else
      for _, pl in ipairs(starcustomchat.utils.playersInRadius(self.messageRadius)) do 
        world.sendEntityMessage(pl, "scc_add_relpy", dataToSend)
      end
    end

    self.customChat:closeSubMenu()
    return false
  end
end

function reply:onSendMessage(message)
  if self.replyingToMessage then
    message.data = message.data or {}
    message.data.replyUUID = self.replyingToMessage.uuid

    self.replyingToMessage = nil
  end
end

function reply:onTextboxEscape()
  if self.replyingToMessage then
    self.customChat:closeSubMenu()
    self.replyingToMessage = nil
    return false
  end
end

function lerpColor(hex1, hex2, t)
  local function hexToRGBA(hex)
      local r, g, b, a = hex:match("#?(..)(..)(..)(..)")
      return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a, 16)
  end

  local function rgbaToHex(r, g, b, a)
      return string.format("#%02x%02x%02x%02x", r, g, b, a)
  end

  if 1 - t < 0.000001 then return hex2 end

  local r1, g1, b1, a1 = hexToRGBA(hex1)
  local r2, g2, b2, a2 = hexToRGBA(hex2)
  
  local r = r1 + (r2 - r1) * t
  local g = g1 + (g2 - g1) * t
  local b = b1 + (b2 - b1) * t
  local a = a1 + (a2 - a1) * t
  
  return rgbaToHex(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
end

function reply:update(dt)
  if self.replyingToMessage then
    self.customChat:highlightMessage(self.replyingToMessage, self.highlightReplyColor)
  end

  if self.highlightMessageInd then
    local newColor = lerpColor(self.highlightReplyColor, "#00000000", self.desaturateTime / self.desaturateTimer)

    self.customChat:highlightMessage(self.customChat.messages[self.highlightMessageInd], newColor)
    self.desaturateTime = self.desaturateTime + dt 
    if newColor == "#00000000" then
      self.highlightMessageInd = nil
      self.desaturateTime = 0 
    end
  end
end

function reply:onSubMenuReopen(type)
  if type ~= "reply" then
    self.replyingToMessage = nil
  end
end

function reply:onCanvasClick(screenPosition, button, isButtonDown)
  if button ~= 0 or not isButtonDown then
    return false
  end

  local selectedMessage = self.customChat:selectMessage(screenPosition, true)
  if not selectedMessage or not selectedMessage.replyUUID then
    return false
  end

  local clickPosition = screenPosition
  local clickY = clickPosition[2] - selectedMessage.offset
  local replyOffsetHeight = self.customChat.config.replyOffsetHeight * self.customChat.config.fontSize / 10
  if selectedMessage.height - clickY >= replyOffsetHeight then
    return false
  end

  local originalMessageInd = self.customChat:findMessageByUUID(selectedMessage.replyUUID)
  if not originalMessageInd then
    return false
  end

  local originalMessage = self.customChat.messages[originalMessageInd]
  local displayName = originalMessage.displayName or originalMessage.nickname
  local cleanText = starcustomchat.utils.clearMetatags(originalMessage.text)
  local croppedText = string.format("%s: %s", displayName,
    starcustomchat.utils.cropMessage(cleanText, self.customChat.canvas:size()[1] // 10))

  local textSize = self.customChat:getTextSize(croppedText, self.customChat.config.fontSize / 1.2)
  if not textSize then
    return false
  end

  local size = portraitSizeFromBaseFont(self.customChat.config.fontSize)
  local xOffset = self.customChat.chatMode == "modern"
    and self.customChat.config.nameOffset[1] + size
    or self.customChat.config.textOffsetCompactMode[1]

  local replyStartOffset = xOffset + self.customChat.config.replyImageOffset[1]
  local clickX = clickPosition[1]

  if clickX >= replyStartOffset and clickX <= replyStartOffset + size / 2 + textSize[1] then
    local targetIsInsideChat = originalMessage.offset and originalMessage.height
      and self.customChat:isInsideChat(
        originalMessage,
        originalMessage.offset,
        self.customChat.config.spacings.name + self.customChat.config.fontSize + 1,
        self.customChat.canvas:size()
      )

    if not targetIsInsideChat then
      self.customChat:scrollToMessage(originalMessageInd, clickPosition[2])
    end

    self.desaturateTime = 0
    self.highlightMessageInd = originalMessageInd
    return true
  end

  return false
end
