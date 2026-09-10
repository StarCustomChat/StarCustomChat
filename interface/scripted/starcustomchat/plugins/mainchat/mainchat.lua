require "/interface/scripted/starcustomchat/plugin.lua"

mainchat = PluginClass:new(
  { name = "mainchat" }
)

function mainchat:init(chat)
  PluginClass.init(self, chat)
  self.ReplyTimer = 5
  self.ReplyTime = 0

  self.pressedDelete = false
  local DMIngToUUID = config.getParameter("DMingTo")

  if DMIngToUUID then
    self.DMingTo = self.customChat:findMessageByUUID(DMIngToUUID)
    if self.DMingTo then
      self.customChat:openSubMenu("DMs", starcustomchat.utils.getTranslation("chat.dming.hint"), self.DMingTo.displayName or self.DMingTo.nickname)
    end
  end

  self.previewPortraits = root.getConfiguration("scc_preview_portraits") or true
  self.previewPlayerCanvas = widget.bindCanvas("lblPortraitPreview.playerCanvas")
  self.backImageSize = root.imageSize("/interface/scripted/starcustomchat/base/icons/empty.png")
end

function mainchat:registerMessageHandlers()

  starcustomchat.utils.setMessageHandler( "scc_ping", function(_, _, playerData)
    local resolvedPlayerData = self.customChat.callbackPlugins("resolvePlayerData", playerData)
    starcustomchat.utils.alert("chat.alerts.was_pinged", resolvedPlayerData.name)
    if type(self.pingSound) == "table" then
      pane.playSound(self.pingSound[math.random(1, #self.pingSound)])
    else
      pane.playSound(self.pingSound)
    end
  end)
end

function mainchat:onLocaleChange()
  if self.DMingTo then
    self.customChat:setSubMenuTexts(starcustomchat.utils.getTranslation("chat.dming.hint"), self.DMingTo.displayName or self.DMingTo.nickname)
  end
end

function mainchat:formatOutcomingMessage(message)
  message.text = message.text:gsub("\\n", "\n")
  return message
end

local function isMouseOverPortrait(screenPosition, message)
  local messageOffset = message.offset
  local messageHeight = message.height

  local offset = vec2.add(widget.getPosition("chatLog"), self.customChat.config.portraitImageOffset)
  offset = vec2.add(offset, pane.getPosition())

  if message.replyUUID then
    offset = vec2.sub(offset, {0, self.customChat.config.replyOffsetHeight * self.customChat.config.fontSize / 10})
  end

  local size = portraitSizeFromBaseFont(self.customChat.config.fontSize)
  offset[2] = offset[2] + messageHeight - size

  local portraitRect = {offset[1], offset[2] + messageOffset, offset[1] + size, offset[2] + messageOffset + size}
  return rect.contains(portraitRect, screenPosition)
end


function mainchat:onCursorOverride(screenPosition)
  local selectedMessage = self.customChat:selectMessage(screenPosition)
  if self.previewPortraits and selectedMessage and selectedMessage.connection and 
    (self.customChat.connectionToUuid[tostring(selectedMessage.connection)] or selectedMessage.mode == "RadioMessage" and selectedMessage.portrait) then
    
    local uuid = self.customChat.connectionToUuid[tostring(selectedMessage.connection)]

    if isMouseOverPortrait(screenPosition, selectedMessage) and ((selectedMessage.mode == "RadioMessage" and selectedMessage.portrait) or self.customChat.savedPortraits[uuid]) then
      local portrait = self.customChat.savedPortraits[uuid] and self.customChat.savedPortraits[uuid].portrait or selectedMessage.portrait
      
      if type(portrait) == "string" then
        self.previewPlayerCanvas:clear()

        local portraitSize = starcustomchat.utils.safeImageSize(portrait)
        if portraitSize then
          widget.setImageScale("lblPortraitPreview.background", portraitSize[1] / self.backImageSize[1] * self.customChat.config.portraitPreviewSize )

          widget.setImageScale("lblPortraitPreview.portrait", self.customChat.config.portraitPreviewSize )
          widget.setImage("lblPortraitPreview.portrait", portrait)
          local frame = self.customChat.savedPortraits[uuid] and self.customChat.savedPortraits[uuid].frame or "/interface/scripted/starcustomchat/base/icons/frame.png"

          widget.setImageScale("lblPortraitPreview.frame", portraitSize[1] / root.imageSize(frame)[1] * self.customChat.config.portraitPreviewSize )
          widget.setImage("lblPortraitPreview.frame", frame)

        end
      else--if table
        self.previewPlayerCanvas:clear()
        widget.setImage("lblPortraitPreview.portrait", "")
        widget.setImageScale("lblPortraitPreview.background", self.customChat.config.defaultPortraitScale )
        widget.setImage("lblPortraitPreview.frame", "/interface/scripted/starcustomchat/base/icons/frame.png")
        widget.setImageScale("lblPortraitPreview.frame", self.customChat.config.defaultPortraitScale )

        for _, layer in ipairs(portrait) do
          self.previewPlayerCanvas:drawImage(layer.image, 
            self.customChat.savedPortraits[uuid].settings and self.customChat.savedPortraits[uuid].settings.offset or self.customChat.config.defaultPortraitOffset, 
            self.customChat.savedPortraits[uuid].settings and self.customChat.savedPortraits[uuid].settings.scale or self.customChat.config.defaultPortraitScale)
        end
      end

        local layoutPosition = screenPosition
        if pane.getPosition then
          layoutPosition = vec2.sub(layoutPosition, pane.getPosition())
        end
        
        if layoutPosition[2] > widget.getSize("chatLog")[2] * self.customChat.config.portraitFlipCanvasPart then
          layoutPosition[2] = layoutPosition[2] - widget.getSize("lblPortraitPreview.background")[2]
        end


        widget.setPosition("lblPortraitPreview", layoutPosition)
        widget.setVisible("lblPortraitPreview", true)
    end
  end
end

function mainchat:update(dt)
  local id = findButtonByMode("Party")
  if #player.teamMembers() == 0 then
    widget.setButtonEnabled("rgChatMode." .. id, false)
    if widget.getSelectedData("rgChatMode").mode == "Party" then
      widget.setSelectedOption("rgChatMode", 1)
    end
  else
    widget.setButtonEnabled("rgChatMode." .. id, true)
  end

  self.ReplyTime = math.max(self.ReplyTime - dt, 0)

  widget.setVisible("lblPortraitPreview", false)
end

function mainchat:getTime(timezoneOffset)
  if os.date then
    local time = os.date("*t")
    return string.format("%02d:%02d", time.hour, time.min)
  else
    local timestamp = os.time()
    -- Adjust timestamp by timezone offset (in seconds)
    local adjusted = timestamp + (timezoneOffset * 3600)

    local secondsInDay = adjusted % 86400
    local hour = math.floor(secondsInDay / 3600)
    local minute = math.floor((secondsInDay % 3600) / 60)

    return string.format("%02d:%02d", hour, minute)
  end
end


function mainchat:formatIncomingMessage(message)
  if message.mode == "CommandResult" then
    message.portrait = self.modeIcons.console
    message.nickname = "Console"
    message.color = self.customChat:getColor("servertext")
  elseif message.mode == "RadioMessage" then
    message.portrait = message.portrait or self.modeIcons.server
    message.nickname = message.nickname or "Server"
  elseif message.mode == "Whisper" or message.mode == "Local" or message.mode == "Broadcast" or message.mode == "Party" or message.mode == "World" then
    if message.connection == 0 then
      message.portrait = message.portrait or self.modeIcons.server
      message.nickname = message.nickname or "Server"
      message.mode = "CommandResult"
      message.color = self.customChat:getColor("servertext")
    else
      message.portrait = message.portrait and message.portrait ~= "" and message.portrait or message.connection
      message.nickname = message.nickname or ""
    end
  end

  message.time = self:getTime(self.customChat.timezoneOffset)
  message.text = message.text:gsub("\\n", "\n")
  return message
end

function mainchat:onSendMessage(message)
  if message.mode == "Broadcast" or message.mode == "Local" or message.mode == "Party" then
    chat.send(message.text, message.mode, not message.silent, message.data)
  end
end

function mainchat:onModeChange(mode)
  widget.setVisible("lytCharactersToDM", mode == "Whisper")
end

--[[
  Context menu items
]]

function mainchat:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)

  if selectedMessage then
    if buttonName == "copy_menu" then
      return not selectedMessage.image
    elseif buttonName == "copy_noformatting" then
      return true
    elseif buttonName == "copy" then
      return true
    elseif buttonName == "delete" or buttonName == "confirm_delete" or buttonName == "cancel_delete" then
      return true
    elseif buttonName == "dm" then
      return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" and selectedMessage.nickname
    elseif buttonName == "ping" then
      return selectedMessage and selectedMessage.connection ~= 0 and selectedMessage.mode ~= "CommandResult" and selectedMessage.nickname
        and starcustomchat.utils.connectionToEntityId(selectedMessage.connection) ~= player.id()
    elseif buttonName == "collapse" then
      local allowCollapse = self.customChat.maxCharactersAllowed ~= 0 and selectedMessage.isLong

      if allowCollapse then
        widget.setButtonImages("lytContext.collapse", {
          base = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:base", selectedMessage.collapsed and "uncollapse" or "collapse"),
          hover = string.format("/interface/scripted/starcustomchat/base/contextmenu/%s.png:hover", selectedMessage.collapsed and "uncollapse" or "collapse")
        })
        widget.setData("lytContext.collapse", {
          displayText = string.format("chat.commands.%s", selectedMessage.collapsed and "uncollapse" or "collapse")
        })
      end
    
      return widget.inMember("lytContext", screenPosition) and allowCollapse
    end
  end
end

function mainchat:onTextboxEscape()
  if self.DMingTo then
    self.customChat:closeSubMenu()
    if self.customChat:getText() == "" then
      self.customChat:blurInput()
    end
    self.DMingTo = nil
    return true
  end
end

function mainchat:onTextboxEnter(message)
  if self.DMingTo then
    self.customChat:closeSubMenu()

    message.mode = "Whisper"
    message.whisperData = {
      displayPlainText = self.DMingTo.nickname,
      id = starcustomchat.utils.connectionToEntityId(self.DMingTo.connection)
    }
    self.DMingTo = nil
    return false
  end

  if string.sub(message.text, 1, 1) == "@" then
    if message.pingTarget then
      self:ping(message.pingTarget.entityId, message.pingTarget.name)
      return true
    end

    local name = string.sub(message.text, 2, string.len(message.text)):gsub("%s+$", "")
    local function getResolvedPlayerName(entityId)
      local playerData = {
        name = world.entityName(entityId),
        entityId = entityId,
        uuid = world.entityUniqueId(entityId)
      }
      local resolvedPlayerData = self.customChat.callbackPlugins("resolvePlayerData", playerData)
      return resolvedPlayerData and resolvedPlayerData.name or playerData.name or "Unknown"
    end

    if string.len(message.text) > 1 then
      local entityId = tonumber(name)
      if entityId and world.entityExists(entityId) then
        self:ping(entityId, getResolvedPlayerName(entityId))
        return true
      end

      for _, pl in ipairs(starcustomchat.utils.playersInRadius()) do 
        if name == world.entityName(pl) then
          self:ping(pl, getResolvedPlayerName(pl))
          return true
        end
      end
    end

    starcustomchat.utils.alert("chat.alerts.ping_failed", name)
    return true
  end
end

function mainchat:onSubMenuReopen(type)
  if type ~= "DMs" then
    self.DMingTo = nil
  end
end

function mainchat:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage then
    if buttonName == "copy" then
        clipboard.setText(selectedMessage.text)
        starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
    elseif buttonName == "copy_noformatting" then
        clipboard.setText(starcustomchat.utils.clearMetatags(selectedMessage.text))
        starcustomchat.utils.alert("chat.alerts.copied_to_clipboard")
    elseif buttonName == "dm" then
      self.DMingTo = selectedMessage
      self.customChat:openSubMenu("DMs", starcustomchat.utils.getTranslation("chat.dming.hint"), selectedMessage.displayName or selectedMessage.nickname)
      self.customChat:focusInput()

    elseif buttonName == "ping" then
      local target = starcustomchat.utils.connectionToEntityId(selectedMessage.connection)
      self:ping(target, selectedMessage.displayName or selectedMessage.nickname)

    elseif buttonName == "collapse" then
      self.customChat:collapseMessage({0, selectedMessage.offset + 1})
    elseif buttonName == "confirm_delete" then
      self.customChat:deleteMessage(selectedMessage.uuid)
    end
  end
end

function mainchat:ping(entityId, name)
  if self.ReplyTime > 0 then
    starcustomchat.utils.alert("chat.alerts.cannot_ping_time", math.ceil(self.ReplyTime))
  else
    if entityId == player.id() then
      starcustomchat.utils.alert("chat.alerts.cannot_ping_yourself")
    else
      promises:add(world.sendEntityMessage(entityId, "scc_ping", starcustomchat.utils.playerData()), function()
        starcustomchat.utils.alert("chat.alerts.pinged", name)
      end, function()
        starcustomchat.utils.alert("chat.alerts.ping_failed", name)
      end)

      self.ReplyTime = self.ReplyTimer
    end
  end
end

function mainchat:onSubMenuClose()
  if self.DMingTo then
    self.DMingTo = nil
    if self.customChat:getText() ~= "" then
      self.customChat:focusInput()
    end
  end
end

function mainchat:onCreateTooltip(screenPosition)
  local selectedMessage = self.customChat:selectMessage(screenPosition)
  
  if selectedMessage and selectedMessage and selectedMessage.tooltip then
    return starcustomchat.utils.hasTranslation(selectedMessage.tooltip) and starcustomchat.utils.getTranslation(selectedMessage.tooltip)
      or selectedMessage.tooltip
  end
end

function mainchat:onSettingsUpdate()
  self.customChat.timezoneOffset = root.getConfiguration("scc_timezone_offset") or 0
  self.previewPortraits = root.getConfiguration("scc_preview_portraits" or true)
end

function mainchat:onReceiveMessage(message)
  if message.mode == "CommandResult" then
    if type(message.text) == "table" then
      message.text = table.concat(message.text, " ")
    end
    sb.logInfo("CommandResult: %s", message.text)
  else
    if message.nickname then
      sb.logInfo("Chat: <%s> %s", message.displayName or message.nickname, message.text)
    else
      sb.logInfo("Chat: %s", message.text)
    end
  end
end

function mainchat:cleanMessage(message)
  message.whisperData = nil
  message.offset = nil
  message.textHeight = nil
  message.collapsed = nil
  message.height = nil
end