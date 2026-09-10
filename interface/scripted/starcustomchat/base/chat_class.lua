--[[
  Chat Class instance
]]

require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"


StarCustomChat = {
  messages = jarray(),
  drawnMessageIndexes = jarray(),
  -- Pixel offset applied to the newest drawn message. 0 means pinned to the bottom.
  lineOffset = 0,
  canvas = nil,
  highlightCanvas = nil,
  topCanvasWid = nil,
  totalHeight = 0,
  config = {},
  chatMode = "modern",
  savedPortraits = {},
  connectionToUuid = {},
  queueTimer = 0.5,
  queueTime = 0,
  lastWhisper = nil,
  maxCharactersAllowed = 0,
  defaultColors = {},
  callbackPlugins = function() end,
  timezoneOffset = 0,
  fontTable = {},
  textBox = nil
}

StarCustomChat.__index = StarCustomChat

function StarCustomChat:create (canvasWid, backgroundCanvasWid, highlightCanvasWid, topCanvasWid, config, messages, 
  chatMode, savedPortraits, connectionToUuid, lineOffset, maxCharactersAllowed, defaultColors, callbackPlugins)

  local o = {}
  setmetatable(o, self)
  self.__index = self

  o.messages = messages
  o.canvasName = canvasWid
  o.canvas = widget.bindCanvas(canvasWid)
  o.backgroundCanvas = widget.bindCanvas(backgroundCanvasWid)
  o.highlightCanvas = widget.bindCanvas(highlightCanvasWid)
  o.topCanvas = widget.bindCanvas(topCanvasWid)
  o.config = config
  o.chatMode = chatMode
  o.savedPortraits = savedPortraits or {}
  o.connectionToUuid = connectionToUuid or {}
  o.lineOffset = lineOffset or 0
  o.maxCharactersAllowed = maxCharactersAllowed
  o.callbackPlugins = callbackPlugins
  
  o.timezoneOffset = root.getConfiguration("scc_timezone_offset") or 0
  o.fontTable = root.getConfiguration("scc_custom_fonts") or {}
  o.colorTable = defaultColors
  local textboxSize = widget.getSize("imgTextbox")
  o.textBox = Textbox:setup("imgTextbox", {
    onChanged = textboxCallback,
    onEnterKey = textboxEnterKey,
    onEscapeKey = escapeTextbox,
    scroll = {
      scrollEnabled = true,
      scrollOffset = { -8, 0 },
      scrollGap = 1
    },
    tabInsertText = "",
    lineSpacing = 1,
    caretColor = {255, 255, 255, 255},
    rect = {2, 0, textboxSize[1] - 1, textboxSize[2]},
    maxHeight = 60,
    onSizeChange = function(newSize)
      local old = widget.getSize("imgTextbox")
      widget.setSize("imgTextbox", {old[1], newSize[2]})
      if setSizes then setSizes(o.config) end
      o:processQueue()
    end
  })
  
  return o
end

function StarCustomChat:drawBackground()
  self.backgroundCanvas:clear()
  if not widget.setImageStretchSet then
    self.backgroundCanvas:drawRect({0, 0, self.backgroundCanvas:size()[1], self.backgroundCanvas:size()[2]}, self:getColor("background"))
  else
    local color = self:getColor("background"):sub(2)
    widget.setImageStretchSet("background", {
      ["end"] = "/interface/scripted/starcustomchat/base/images/body/bodyheader.png?replace;FFFFFF01=" .. color,
      ["inner"] = "/interface/scripted/starcustomchat/base/images/body/bodyinner.png?replace;FFFFFF01=" .. color,
      ["begin"] = "/interface/scripted/starcustomchat/base/images/body/bodyfooter.png?replace;FFFFFF01=" .. color
    })
  end
end

function StarCustomChat:addMessage(msg)

  local function formatMessage(message)

    if message.mode == "RadioMessage" and message.portrait then
      message.portrait = message.portrait .. self.config.radioMessageCropDirective
    end

    message = self.callbackPlugins("formatIncomingMessage", message)

    if not message or ((not message.text or message.text == "") and not message.image) then return nil end

    if not message.nickname then
      message.nickname = "Unknown"
    end

    if not message.portrait or message.portrait == '' then
      message.portrait = self:getUnknownPortrait(message.connection)
    end

    if not message.text or message.text == "" and not message.image then return nil end

    if message.connection == 0 then
      for _, settings in ipairs(self.config.serverTextSpecific) do 
        if string.find(message.text, settings.text) then
          if settings.icon then
            message.portrait = settings.icon
          end
          if settings.nickname then
            message.nickname = starcustomchat.utils.getTranslation(settings.nickname)
          end
          break
        end
      end
    else
      if message.mode == "Whisper" then
        if self.lastWhisper and message.text == self.lastWhisper.text then
          message.recipient = self.lastWhisper.recipient
          self.lastWhisper = nil
        end
      end

      self:requestPortrait(message.connection)
      
    end
    return message
  end

  if msg.connection then
    msg.uuid = self:calculateUUID(msg)
    msg = formatMessage(msg)
    if msg then
      table.insert(self.messages, msg)
      if #self.messages > self.config.chatHistoryLimit then
        table.remove(self.messages, 1)
      end
      self.callbackPlugins("onReceiveMessage", msg)
      self:processQueue()
    end
  end
end

function StarCustomChat:setFilter(data)
  if not data or (string.gsub(data, "^%s*(.-)%s*$", "%1")) == "" then
    self.filter = nil
    self:resetHint()
  else
    self.filter = data
    self:setHint(starcustomchat.utils.getTranslation("chat.textbox.hint.filter", self.filter))
  end
  self:processQueue()
end

function StarCustomChat:getColor(type)
  return self.colorTable[type] and "#" .. self.colorTable[type] or self.config.defaultColor
end

function StarCustomChat:calculateUUID(message)
  return util.hashString(message.connection .. (message.text or ""))
end

function StarCustomChat:findMessageByUUID(uuid)
  for i = #self.messages, 1, -1 do 
    if self.messages[i].uuid and self.messages[i].uuid == uuid then 
      return i 
    end
  end
end

function StarCustomChat:findMessagesByConnection(connection)
  local messagesByConnection = {}

  for i = #self.messages, 1, -1 do 
    if self.messages[i].connection and self.messages[i].connection == connection then 
      table.insert(messagesByConnection, self.messages[i])
    end
  end
  
  return messagesByConnection
end

function StarCustomChat:replaceUUID(oldUUID, newUUID)
  if oldUUID and newUUID then
    local oldMessageInd = self:findMessageByUUID(oldUUID)
    for i, message in ipairs(self.messages) do 
      if message.replyUUID == oldUUID then
        self.messages[i].replyUUID = newUUID
      end
    end
    self.messages[oldMessageInd].uuid = newUUID
  end
end

function StarCustomChat:deleteMessage(uuid)
  local ind = self:findMessageByUUID(uuid)
  if ind then
    table.remove(self.messages, ind)
    self:processQueue()
  end
end

function StarCustomChat:setSubMenuTexts(hint, text)
  widget.setText("lytSubMenu.lblHint", hint)
  widget.setPosition("lytSubMenu.lblText", vec2.add(widget.getPosition("lytSubMenu.lblHint"), {widget.getSize("lytSubMenu.lblHint")[1] + 3, 0}))
  widget.setText("lytSubMenu.lblText", text)
end

function StarCustomChat:openSubMenu(type, hint, text)
  self.submenuType = type
  if widget.active("lytSubMenu") then
    self.callbackPlugins("onSubMenuReopen", type)
  end
  self:setSubMenuTexts(hint, text)
  widget.setVisible("lytSubMenu", true)
  if setSizes then setSizes(self.config) end
end

function StarCustomChat:getSubMenuType()
  return self.submenuType
end

function StarCustomChat:closeSubMenu()
  self.submenuType = nil
  if widget.active("lytSubMenu") then
    widget.setVisible("lytSubMenu", false)
    if setSizes then setSizes(self.config) end
  end
end

function StarCustomChat:requestPortrait(connection, overwrite)
  local entityId = starcustomchat.utils.connectionToEntityId(connection)
  local uuid = world.entityUniqueId(entityId) or self.connectionToUuid[tostring(connection)]

  self.connectionToUuid[tostring(connection)] = uuid

  if uuid and (not self.savedPortraits[uuid] or overwrite) then
    if entityId and world.entityExists(entityId) then
      promises:add(world.sendEntityMessage(entityId, "icc_request_player_portrait"), function(data)
        self:updatePortrait(data)
      end, function()
        self.connectionToUuid[tostring(connection)] = uuid
        self.savedPortraits[uuid] = {
          portrait = world.entityExists(entityId) and starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(entityId, "full")) or {},
          settings = {
            offset = self.config.defaultPortraitOffset,
            scale = self.config.defaultPortraitScale
          }
        }
        self:processQueue()
      end)
    end
  end
end

function StarCustomChat:updatePortrait(data)
  self.savedPortraits[data.uuid] = data
  self.savedPortraits[data.uuid].portrait = starcustomchat.utils.clearPortraitFromInvisibleLayers(self.savedPortraits[data.uuid].portrait)

  self.connectionToUuid[tostring(data.connection)] = data.uuid
  self:processQueue()
end

function StarCustomChat:clearHistory()
  self.messages = jarray()
  self:processQueue()
end

function StarCustomChat:resetChat()
  local newChatSize = root.getConfiguration("icc_font_size") or self.config.fontSize
  local maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0
  local newChatMode = root.getConfiguration("sccMode") or "modern"
  
  if newChatSize ~= self.config.fontSize or maxCharactersAllowed ~= self.maxCharactersAllowed or self.chatMode ~= newChatMode then
    self.recalculateHeight = true
  end

  self.chatMode = newChatMode
  self.config.fontSize = newChatSize
  self.maxCharactersAllowed  = maxCharactersAllowed
  self.colorTable = sb.jsonMerge(self.colorTable, root.getConfiguration("scc_custom_colors") or {})
  self:setTextColor(self:getColor("chattext"))

  self:requestPortrait(starcustomchat.utils.entityIdToConnection(player.id()), true)

  self:drawBackground()
  self:processQueue()
end

function StarCustomChat:setInformationalText(text)
  local shouldShow = text and text ~= ""
  if widget.active("lytNotification") ~= shouldShow then
    widget.setVisible("lytNotification", shouldShow)
    self:processQueue()
  end
  widget.setText("lytNotification.lblNotification", text and "^font=hobo_i;" .. text or "")
end

function StarCustomChat:resetInformationalText()
  if widget.active("lytNotification") then
    widget.setVisible("lytNotification", false)
    self:processQueue()
  end
  widget.setText("lytNotification.lblNotification", "")
end

-- Textbox callbacks
function StarCustomChat:setText(text)
  self.textBox:setText(text)
end

function StarCustomChat:getText()
  return self.textBox:getText()
end

function StarCustomChat:blurInput()
  self.textBox:blur()
end

function StarCustomChat:focusInput()
  self.textBox:focus()
end

function StarCustomChat:hasFocusInput()
  return self.textBox:hasFocus()
end

function StarCustomChat:setHint(hint)
   self.textBox:setHint(hint)
end

function StarCustomChat:resetHint()
   self.textBox:setHint(starcustomchat.utils.getTranslation("chat.textbox.hint"))
end

function StarCustomChat:setTextColor(color)
  self.textBox:setTextColor(color)
end

function StarCustomChat:ignoreInputFrame()
  self.textBox:setIgnoreInputFrame(true)
end

function StarCustomChat:setMaxHeight(height)
  self.textBox:setMaxHeight(height)
end

---@public
function StarCustomChat:updateTextboxMaxHeight()
  if not pane.getSize then
    return
  end
  local maxHeight = math.floor(pane.getSize()[2] * self.config.textboxMaxHeighSize)
  
  -- Ensure a reasonable minimum
  maxHeight = math.max(maxHeight, self.config.minChatBodyHeight * self.config.textboxMaxHeighSize)
  
  self:setMaxHeight(maxHeight)
end

function StarCustomChat:getMessages()
  return self.messages
end

function StarCustomChat:processCommand(text)

  if not self.callbackPlugins("onProcessCommand", text) then
    local commandResult = chat.command(text) or {}

    for _, line in ipairs(commandResult) do 
      self:addMessage({
        connection = 0,
        mode = "CommandResult",
        text = line,
        tooltip = starcustomchat.utils.cropMessage(text, self.config.commandHintCharacterLimit)
      })
    end
    return commandResult
  end
end

function StarCustomChat:sendMessage(message)
  if message.text == "" then return end

  message.connection = message.connection or starcustomchat.utils.entityIdToConnection(player.id())
  message.nickname = message.nickname or player.name()

  self.callbackPlugins("onSendMessage", message)
end

function portraitSizeFromBaseFont(font)
  return math.floor(font * 2.5)
end

function StarCustomChat:drawCommandPreview(commands, selected)

  local result = ""
  local n = #commands

  for j = 0, n - 1 do
    local i = (selected + j - 1) % n + 1
    if type(commands[i]) == "table" then
      local previewText = commands[i].name or commands[i].displayName or commands[i].data or commands[i].command or ""
      result = result .. "^" .. (j == 0 and self:getColor(commands[i].color or "commandselecttext") or self:getColor("chattext")) .. ";" .. previewText .. " "
    else
      result = result .. "^" .. (j == 0 and self:getColor("commandselecttext") or self:getColor("chattext")) .. ";" .. commands[i] .. " "
    end
  end

  widget.setText("lytCommandPreview.lblCommandPreview", result)

  local backgroundSize = widget.getSize("lytCommandPreview.imgStretchDescription")
  if commands[selected].description then
    widget.setText("lytCommandPreview.lblDescription", starcustomchat.utils.hasTranslation(commands[selected].description) and
      starcustomchat.utils.getTranslation(commands[selected].description) or commands[selected].description)

    
    widget.setSize("lytCommandPreview.imgStretchDescription", {backgroundSize[1], widget.getSize("lytCommandPreview.lblDescription")[2] + 7})
  else
    widget.setText("lytCommandPreview.lblDescription", "")
    widget.setSize("lytCommandPreview.imgStretchDescription", {backgroundSize[1], 0})
  end
end

function StarCustomChat:getUnknownPortrait(connection)
  return string.format(self.config.unknownPortraits, connection % self.config.numberOfUnknownPortraits)
end

function StarCustomChat:drawIcon(target, nickname, messageOffset, color, time, recipient)
  local function drawModeIcon(offset)
    local frameSize = root.imageSize(self.config.icons.frame)
    local squareSize = self.config.modeIndicatorSize
    self.canvas:drawRect({offset[1] - squareSize - 1, offset[2], offset[1] - 1, offset[2] + portraitSizeFromBaseFont(self.config.fontSize) - squareSize}, color)
  end

  local function drawImage(image, offset)
    local frameSize = starcustomchat.utils.safeImageSize(image)
    if frameSize then
      local size = portraitSizeFromBaseFont(self.config.fontSize)
      self.canvas:drawImageRect(image, {0, 0, frameSize[1], frameSize[2]}, {offset[1], offset[2], offset[1] + size, offset[2] + size})
    end
  end

  local function drawPortrait(portrait, messageOffset, cropArea, portraitSettings, color, customFrame)
    local offset = vec2.add(self.config.portraitImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)
    local size = portraitSizeFromBaseFont(self.config.fontSize)

    if type(portrait) == "string" then
      drawImage(portrait, offset)
    else
      for _, layer in ipairs(portrait) do
        if portraitSettings then
          local currentScale = portraitSettings.scale * (size / 70)
          local currentOffset = vec2.floor(vec2.mul(portraitSettings.offset, (size / 70)))
          local imageSize = root.imageSize(layer.image)
  
          -- This monstrocity exists because drawImageRect can't be fixed
          local imageOffset = {0, 0}
  
          local cropX1, cropX2, cropY1, cropY2 = 0, imageSize[1], 0, imageSize[2]
          
          if portraitSettings.scale > 1 then
            cropX2 = 70 // portraitSettings.scale
            cropY2 = 70 // portraitSettings.scale
          end
  
          if portraitSettings.offset[1] > 0 then
            imageOffset[1] = portraitSettings.offset[1] / portraitSettings.scale
            cropX2 = math.floor(cropX2 - portraitSettings.offset[1] / portraitSettings.scale)
          else
            cropX1 = - portraitSettings.offset[1] // portraitSettings.scale
            cropX2 = math.min(math.floor(cropX2 - portraitSettings.offset[1] / portraitSettings.scale), imageSize[2])
          end
  
          if portraitSettings.offset[2] > 0 then
            imageOffset[2] = portraitSettings.offset[2] / portraitSettings.scale
            cropY2 = math.floor(cropY2 - portraitSettings.offset[2] / portraitSettings.scale)
          else
            cropY1 = - portraitSettings.offset[2] // portraitSettings.scale
            cropY2 = math.min(math.floor(cropY2 - portraitSettings.offset[2] / portraitSettings.scale), imageSize[2])
          end
  
          if (cropX2 - cropX1 > 0 and cropY2 - cropY1 > 0) then
            self.canvas:drawImage(layer.image .. string.format("?crop;%d;%d;%d;%d", 
                cropX1, 
                cropY1, 
                cropX2, 
                cropY2
              ), 
              vec2.add(offset, imageOffset), currentScale)
          end
        else
          self.canvas:drawImageRect(layer.image, cropArea or self.config.portraitCropArea, {offset[1], offset[2], offset[1] + size, offset[2] + size})
        end
      end
    end
    drawModeIcon(offset)
    drawImage(customFrame or self.config.icons.frame, offset)
  end



  if type(target) == "number" then
    local entityId = starcustomchat.utils.connectionToEntityId(target)

    local uuid = (world.entityExists(entityId) and world.entityUniqueId(entityId)) or self.connectionToUuid[tostring(target)]

    if uuid and self.savedPortraits[uuid] then
      drawPortrait(self.savedPortraits[uuid].portrait, messageOffset, self.savedPortraits[uuid].cropArea, self.savedPortraits[uuid].settings, color, self.savedPortraits[uuid].frame)
    else
      local offset = vec2.add(self.config.iconImageOffset, messageOffset)
      drawImage(self.config.icons.empty, offset)
      drawImage(self:getUnknownPortrait(target), offset)
      drawModeIcon(offset)
      drawImage(self.config.icons.frame, offset)
    end
  elseif type(target) == "string" then
    local offset = vec2.add(self.config.iconImageOffset, messageOffset)
    drawImage(self.config.icons.empty, offset)
    drawImage(target, offset)
    drawModeIcon(offset)
    drawImage(self.config.icons.frame, offset)
  end
  
  local size = portraitSizeFromBaseFont(self.config.fontSize)
  local nameOffset = vec2.add(self.config.nameOffset, {size, size})
  nameOffset = vec2.add(nameOffset, messageOffset)

  if recipient or nickname then

    self.canvas:drawText(recipient and "-> " .. recipient or nickname, {
      position = nameOffset,
      horizontalAnchor = "left", -- left, mid, right
      verticalAnchor = "top" -- top, mid, bottom
    }, self.config.fontSize + 1, (color or self:getColor("chattext")), nil, self:getFont("chattext"))
  end

  if time then
    local timePosition = {self.canvas:size()[1] - self.config.timeOffset[1], nameOffset[2] + self.config.timeOffset[2]}
    self.canvas:drawText(time, {
      position = timePosition,
      horizontalAnchor = "right", -- left, mid, right
      verticalAnchor = "top" -- top, mid, bottom
    }, self.config.fontSize - 1, self:getColor("timetext"), nil, self:getFont("timetext"))
  end
end

function StarCustomChat:offsetCanvas(offset)
  if not offset then return end

    
  if #self.drawnMessageIndexes > 0 and offset < 0 then
    local firstMessage = self.messages[self.drawnMessageIndexes[1]]
    local remainingOffset = firstMessage.offset + firstMessage.height

    if remainingOffset <= 0 then
      return
    end

    offset = math.max(offset, -remainingOffset)
  end

  local lineOffset = math.min(self.lineOffset + offset, 0)
  if lineOffset ~= self.lineOffset then
    self.lineOffset = lineOffset
    self:processQueue()
  end
end

function StarCustomChat:scrollToMessage(ind, targetY)
  local message = self.messages[ind]
  if not message or not message.offset or not message.height then
    return
  end

  targetY = targetY or 0
  self:offsetCanvas(targetY - message.offset - message.height)
end

  
function StarCustomChat:isInsideChat(message, messageOffset, addSpacing, canvasSize)
  return (self.chatMode == "modern" and message.avatar) and (messageOffset + message.height + addSpacing >= 0 and messageOffset <= canvasSize[2]) 
    or (messageOffset + message.height >= 0 and messageOffset <= canvasSize[2])
end

function StarCustomChat:resetCanvasOffset()
  self.lineOffset = 0
  self:processQueue()
end


function StarCustomChat:highlightMessage(message, color)
  for i = #self.drawnMessageIndexes, 1, -1 do 
    if message.uuid == self.messages[self.drawnMessageIndexes[i]].uuid then
      local y1, y2 = message.offset, message.offset + message.height + self.config.spacings.messages
      if self:isInsideChat(message, message.offset, self.config.spacings.name + self.config.fontSize + 1, self.canvas:size()) then
        self.highlightCanvas:drawRect({2, y1, self.highlightCanvas:size()[1] - 2, y2}, color or self.config.highlightColor)
      end
      return
    end
  end
end

function StarCustomChat:clearHighlights()
  self.highlightCanvas:clear()
  self.topCanvas:clear()
end

function StarCustomChat:collapseMessage(position)
  local pos = position or self.highlightCanvas:mousePosition()

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    if message.offset and pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
      self.messages[self.drawnMessageIndexes[i]].collapsed = not self.messages[self.drawnMessageIndexes[i]].collapsed
      self.messages[self.drawnMessageIndexes[i]].textHeight = nil
      self:processQueue()
    end
  end
end

function StarCustomChat:selectMessage(position, isCanvasPosition)
  if not position then return end

  local pos = position
  if not isCanvasPosition then
    if not widget.inMember("cnvHighlightCanvas", position) then return end
    pos = self.highlightCanvas:mousePosition()
  end

  if not pos then return end

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    if message.offset and pos[2] > (message.offset or 0) and pos[2] <= message.offset + message.height + self.config.spacings.messages  then
      return message
    end
  end
end

function filterMessages(messages, filter)
  local drawnMessageIndexes = {}

  for i, message in ipairs(messages) do 
    --filter messages by mode availability
    local mode = message.mode
    
    if mode
      and (widget.active("lytModeFilter.btnCk" .. mode) == nil or widget.getChecked("lytModeFilter.btnCk" .. mode))
      and (
        not filter
        or (message.text and string.find(utf8.lower(message.text), utf8.lower(filter), 1, true))
        or (message.nickname and string.find(utf8.lower(message.nickname), utf8.lower(filter), 1, true))
      )
    then
      table.insert(drawnMessageIndexes, i)
    end
  end
  return drawnMessageIndexes
end

function createNameForCompactMode(name, color, text, time, timeColor, timeFont)
  local timeString = time and string.format("^%s;^font=%s;[%s]^reset; ", timeColor, timeFont, time) or ""
  local formattedString = string.format(" %s^reset;<^%s;%s^reset;>: %s", timeString, color, name, text)

  return formattedString
end

function cutStringFromEnd(toCollapse, inputString, MAX)
  local is_long = utf8.len(inputString) > MAX
  if toCollapse and is_long then
      local offset = utf8.offset(inputString, MAX + 1)
      return string.sub(inputString, 1, offset - 1) .. "^gray;...", is_long, true
  else
      return inputString, is_long, false
  end
end

function StarCustomChat:getTextSize(text, fontSize)
  -- Get amount of lines in the message and its length
  local labelToCheck = self.chatMode == "modern" and "totallyFakeLabelFullMode" or "totallyFakeLabelCompactMode"

  if fontSize then
    createTotallyFakeWidgets(self.config.wrapWidthFullMode, self.config.wrapWidthCompactMode, fontSize, self:getFont("chattext"))
  end
  widget.setText(labelToCheck, text)
  local sizeOfText = widget.getSize(labelToCheck)
  widget.setText(labelToCheck, "")
  if fontSize then -- Return back to default
    createTotallyFakeWidgets(self.config.wrapWidthFullMode, self.config.wrapWidthCompactMode, self.config.fontSize, self:getFont("chattext"))
  end

  return sizeOfText
end

function StarCustomChat:getFont(name)
  return self.fontTable[name] or "hobo"
end

function StarCustomChat:setFonts(fontTable)
  if fontTable then
    self.fontTable = fontTable

    createTotallyFakeWidgets(
      self.config.wrapWidthFullMode,
      self.config.wrapWidthCompactMode,
      self.config.fontSize,
      self:getFont("chattext")
    )

    self.recalculateHeight = true
    --self.textBox:setFont(self:getFont("chattext"))
    self:processQueue()
  end
end


function StarCustomChat:processQueue()
  self.canvas:clear()
  self.totalHeight = 0
  self.drawnMessageIndexes = filterMessages(self.messages, self.filter)

  for i = #self.drawnMessageIndexes, 1, -1 do 
    local message = self.messages[self.drawnMessageIndexes[i]]
    local messageMode = message.mode

    if not message.nickname then
      message.nickname = "Unknown"
    end

    if not message.portrait or message.portrait == '' then
      message.portrait = self:getUnknownPortrait(message.connection)
    end
    
    -- If the message should contain an avatar and name:
    local prevDrawnMessage = self.messages[self.drawnMessageIndexes[i - 1]]
    message.avatar = 
      i == 1 or (
        message.connection ~= prevDrawnMessage.connection or 
        message.mode ~= prevDrawnMessage.mode or 
        message.nickname ~= prevDrawnMessage.nickname or 
        message.displayName ~= prevDrawnMessage.displayName or 
        message.portrait ~= prevDrawnMessage.portrait or 
        message.forceAvatar
      )


    local text = self.chatMode == "modern" and message.text 
      or createNameForCompactMode(message.displayName or message.nickname, 
        self.config.modeColors[messageMode] or self.config.modeColors.default, 
        message.text, message.time, self:getColor("timetext"), self:getFont("timetext"))

    if self.maxCharactersAllowed ~= 0 then
      local toCheckLength = message.collapsed == nil and true or message.collapsed
      text, message.isLong, message.collapsed = cutStringFromEnd(toCheckLength, text, self.maxCharactersAllowed)
      if toCheckLength then
        message.textHeight = nil
      end
    else
      message.collapsed = nil
    end

    if not message.textHeight or self.recalculateHeight then
      local sizeOfText = message.imageSize and vec2.div(message.imageSize, 10 / self.config.fontSize) or self:getTextSize(text)

      if not sizeOfText then return end 

      message.height = sizeOfText[2]
      message.textHeight = message.height
    else
      message.height = message.textHeight
    end

    -- Calculate message offset
    local messageOffset = self.lineOffset + self.config.notificationHeight

    if i ~= #self.drawnMessageIndexes then
      messageOffset = self.messages[self.drawnMessageIndexes[i + 1]].offset + self.messages[self.drawnMessageIndexes[i + 1]].height + self.config.spacings.messages
    end

    -- Plugins reserve any space their decorations need before this message is drawn.
    -- bodyOffset shifts the built-in text/image down, while bodyHeight is the height
    -- occupied before the avatar and bottom decorations.
    local drawData = {
      messageOffset = messageOffset,
      bodyOffset = 0,
      bodyHeight = message.height,
      height = message.height
    }
    self.callbackPlugins("onMeasureMessage", message, drawData)

    local avatarOffset = self.chatMode == "modern" and message.avatar
      and self.config.spacings.name + self.config.fontSize + 1
      or 0
    drawData.avatarOffset = avatarOffset
    drawData.height = drawData.height + avatarOffset
    local messageBodyHeight = drawData.bodyHeight
    message.height = messageBodyHeight

    -- Draw the actual message unless it's outside of drawing area
    if self.chatMode == "modern" then
      if self:isInsideChat(message, messageOffset, self.config.spacings.name + self.config.fontSize + 1, self.canvas:size()) then
        local size = portraitSizeFromBaseFont(self.config.fontSize)
        local nameOffset = vec2.add(self.config.nameOffset, {size, size})


        if message.image then
          self.canvas:drawImage(message.image, {nameOffset[1], messageOffset + drawData.bodyOffset}, 1 / 10 * self.config.fontSize)
        else
          self.canvas:drawText(text, {
            position = {nameOffset[1], messageOffset + drawData.bodyOffset},
            horizontalAnchor = "left", -- left, mid, right
            verticalAnchor = "bottom", -- top, mid, bottom
            wrapWidth = self.config.wrapWidthFullMode -- wrap width in pixels or nil
          }, self.config.fontSize, message.color or self:getColor("chattext"), nil, self:getFont("chattext"))
        end



        if message.avatar then
          local offset = {0, messageOffset + self.config.textOffsetFullMode[2] + messageBodyHeight - self.config.fontSize}
          message.avatarOffset = offset
          self:drawIcon(message.portrait, message.displayName or message.nickname, offset, self.config.modeColors[messageMode], 
            message.time, message.recipient)
        end
      end
    
    else -- compact mode
      if self:isInsideChat(message, messageOffset, 0, self.canvas:size()) then
        local offset = vec2.add(self.config.textOffsetCompactMode, {0, messageOffset})        
        
        if not message.image then
          self.canvas:drawText(text, {
            position = {offset[1], offset[2] + drawData.bodyOffset},
            horizontalAnchor = "left", -- left, mid, right
            verticalAnchor = "bottom", -- top, mid, bottom
            wrapWidth = self.config.wrapWidthCompactMode -- wrap width in pixels or nil
          }, self.config.fontSize, message.color or self:getColor("chattext"), nil, self:getFont("chattext"))

        else
          local text = createNameForCompactMode(message.displayName or message.nickname, 
          self.config.modeColors[messageMode] or self.config.modeColors.default, 
            "", message.time, self:getColor("timetext"), self:getFont("timetext"))
          
          self.canvas:drawText(text, {
            position = {offset[1], offset[2] + drawData.bodyOffset},
            horizontalAnchor = "left", -- left, mid, right
            verticalAnchor = "bottom", -- top, mid, bottom
            wrapWidth = self.config.wrapWidthCompactMode -- wrap width in pixels or nil
          }, self.config.fontSize, message.color or self:getColor("chattext"), nil, self:getFont("chattext"))

          local nameWidth = self:getTextSize(text)
          self.canvas:drawImage(message.image, {offset[1] + nameWidth[1], offset[2] + drawData.bodyOffset}, 1 / 10 * self.config.fontSize)
        end

        if message.avatar then
          local squareSize = self.config.modeIndicatorSize
          local iconOffset = vec2.add(offset, {-1, message.height + self.config.spacings.name - 1})
          self.canvas:drawRect({iconOffset[1], iconOffset[2], iconOffset[1] + squareSize, iconOffset[2] - self.config.fontSize + 2}, self.config.modeColors[messageMode])
        end
      end
    end

    message.height = drawData.height
    message.offset = messageOffset
    self.totalHeight = self.totalHeight + message.height
    self.messages[self.drawnMessageIndexes[i]] = message

    if self:isInsideChat(message, messageOffset, self.config.spacings.name + self.config.fontSize + 1, self.canvas:size()) then
      self.callbackPlugins("onDrawMessage", message, drawData)
    end
  end

  self.recalculateHeight = nil
end
