require "/scripts/messageutil.lua"
require "/scripts/scctimer.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/interface/StarboundTextboxInterface/animatedWidgets.lua"
require "/interface/scripted/starcustomchat/base/chat_class.lua"
require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"
require "/interface/scripted/starcustomchat/plugin.lua"
require "/interface/scripted/starcustomchat/chatbuilder.lua"
require "/interface/scripted/starcustomchat/base/contextmenu/contextmenu.lua"
require "/interface/scripted/starcustomchat/base/dmtab/dmtab.lua"
require "/interface/scripted/starcustomchat/base/commandpreview/commandpreview.lua"
require "/interface/scripted/starcustomchat/base/utils/config.lua"

ICChatTimer = TimerKeeper.new()

function init()
  Configuration = __Config:init()
  
  self.drawingCanvas = interface.bindCanvas("chatInterfaceCanvas")

  self.canvasName = "chatLog"
  self.highlightCanvasName = "cnvHighlightCanvas"
  self.topCanvasName = "cnvTopCanvas"

  self.chatWindowWidth = widget.getSize("saScrollArea")[1]

  local availableCommands = root.assetJson("/interface/scripted/starcustomchat/base/commands.config")

  local chatConfig = root.assetJson("/interface/scripted/starcustomchat/base/chat.config")

  self.chatUUID = nil

  local plugins = {}
  local localePluginConfig = {}
  local availableLocales = root.assetJson("/interface/scripted/starcustomchat/locales/locales.json")
  for _, localeConfig in ipairs(availableLocales) do
    localePluginConfig[localeConfig.code] = root.assetJson(string.format("/interface/scripted/starcustomchat/locales/%s.json", localeConfig.code))
  end


  -- Load plugins
  for i, pluginName in ipairs(config.getParameter("enabledPlugins", {})) do 
    local pluginConfig = root.assetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.script then
      require(pluginConfig.script)

      if not _ENV[pluginName] then
        sb.logError("Failed to load plugin %s", pluginName)
      else
        local classInstance = _ENV[pluginName]:new()
        table.insert(plugins, classInstance)
      end
    end

    if pluginConfig.baseConfigValues then
      chatConfig = sb.jsonMerge(chatConfig, pluginConfig.baseConfigValues)
    end

    if pluginConfig.commands then
      availableCommands = sb.jsonMerge(availableCommands, {[pluginName] = root.assetJson(pluginConfig.commands)})
    end

    for _, localeConfig in ipairs(availableLocales) do 
      local locale = localeConfig.code
      local localeFile = string.format("/interface/scripted/starcustomchat/plugins/%s/locales/%s.json", pluginName, locale)
      if root.assetOrigin(localeFile) then
        local translations = root.assetJson(localeFile)
        localePluginConfig[locale] = sb.jsonMerge(localePluginConfig[locale], translations)
      else
        sb.logWarn("The %s localization file is missing", localeFile)
      end
    end
  end

  self.runCallbackForPlugins = function(method, ...)
    return PluginClass:runCallbacks(plugins, method, ...)
  end

  starcustomchat.utils.buildLocale(localePluginConfig)

  chatConfig.fontSize = root.getConfiguration("icc_font_size") or chatConfig.fontSize

  self.chatSizeSettings = loadChatSizeSettings(chatConfig)
  if pane.setSize then
    applyChatSizeSettings(chatConfig, self.chatSizeSettings)
    applyWidgetSizeSettings(chatConfig)
  end

  local storedMessages = root.getConfiguration("icc_last_messages", jarray())

  for btn, isChecked in pairs(config.getParameter("selectedModes") or {}) do
    widget.setChecked(btn, isChecked)
  end

  local maxCharactersAllowed = root.getConfiguration("icc_max_allowed_characters") or 0

  local chatMode = root.getConfiguration("sccMode") or "modern"
  if chatMode ~= "compact" then chatMode = "modern" end

  self.customChat = StarCustomChat:create(self.canvasName, "cnvBackgroundCanvas", self.highlightCanvasName, self.topCanvasName,
    chatConfig, storedMessages, chatMode,
    config.getParameter("portraits"), config.getParameter("connectionToUuid"), config.getParameter("chatLineOffset"), maxCharactersAllowed, 
    sb.jsonMerge(config.getParameter("defaultColors"), root.getConfiguration("scc_custom_colors") or {}), self.runCallbackForPlugins)


  createTotallyFakeWidgets(chatConfig.wrapWidthFullMode, chatConfig.wrapWidthCompactMode, chatConfig.fontSize, self.customChat:getFont("chattext"))
  self.runCallbackForPlugins("init", self.customChat)
  localeChat()
  setSizes(chatConfig)

  self.lastCommand = root.getConfiguration("icc_last_command")

  self.commandPreview = CommandPreview:new(self.customChat, availableCommands)

  self.selectedMessage = nil
  self.sentMessages = root.getConfiguration("icc_my_messages") or jarray()
  self.sentMessagesLimit = 15
  self.currentSentMessage = nil
  self.recalledSentMessage = nil

  contextMenu_init(config.getParameter("contextMenuButtons"))

  local lastText = config.getParameter("lastInputMessage")
  if lastText and lastText ~= "" then
    self.customChat:setText(lastText)
    self.customChat:focusInput()
  end

  local currentMessageMode = config.getParameter("currentMessageMode") or root.getConfiguration("scc_message_mode")

  if currentMessageMode then
    widget.setSelectedOption("rgChatMode", currentMessageMode)
    widget.setFontColor("rgChatMode." .. currentMessageMode, chatConfig.modeColors[widget.getData("rgChatMode." .. currentMessageMode).mode])
  else
    widget.setSelectedOption("rgChatMode", 1)
    widget.setFontColor("rgChatMode.1", chatConfig.modeColors[widget.getData("rgChatMode.1").mode])
  end

  createPromiseFunction()

  self.customChat:drawBackground()
  self.customChat:processQueue()

  local storedHiddenMessages = config.getParameter("storedMessages") or {}

  for _, message in pairs(storedHiddenMessages) do 
    self.customChat:addMessage(message)
  end

  if config.getParameter("forceFocus") then
    self.customChat:focusInput()
  end

  self.customChat:setTextColor(self.customChat:getColor("chattext"))

  -- Apparently, we don't know on init if we're admin or not.
  starcustomchat.utils.runWhenPlayerReady(disableAdminModes)

  if (pane.setPosition or pane.setSize) and not self.drawingCanvas and interface.bindCanvas then
    bindChatInterfaceCanvas()
  end

  if pane.setPosition then
    widget.setVisible("btnMoveChat", true)
    ICChatTimer:add(0.1, function()
      local newPosition = root.getConfiguration("scc_chat_position") or {3, 5}
      pane.setPosition(newPosition)
    end)
  end

  if pane.setSize and pane.getSize and pane.getPosition then
    widget.setVisible("btnResizeChat", true)
  end

  if widget.getScrollOffset then
    widget.setButtonEnabled("lytLeftMenu.btnUp", true)
    widget.setButtonEnabled("lytLeftMenu.btnDown", true)
  end

  self.settingsInterface = buildSettingsInterface()

  self.DMTab = DMTab:new(self.customChat)
  self.DMTab:checkDMs(config.getParameter("DMingPlayerID"))

  startConfigurationTracking()
end

function startConfigurationTracking()
    --Saving mechanism
  local function saveConfiguration()
    ICChatTimer:add(self.customChat.config.savingPeriod, function()
      if Configuration:hasPendingChanges() then
        Configuration:save()
      end
      saveConfiguration()
    end)
  end
  saveConfiguration()
end


function selectPlayer(...)
  return self.DMTab and self.DMTab:selectPlayer(...)
end

function disableAdminModes()
  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    if button.data.admin then
      widget.setButtonEnabled("rgChatMode." .. i, player.isAdmin())
    end
  end
end

function createPromiseFunction()
  -- Since in OSB chat is ready before the other scripts, we should pool ourself before we can actually use it
  function pullPromise()
    starcustomchat.utils.runWhenPlayerReady(function()
      promises:add(world.sendEntityMessage(player.id(), "scc_uuid"), function(uuid)
          if not self.chatUUID or self.chatUUID ~= uuid then
            prepareForCallbacks()
            self.chatUUID = uuid
          end
          pullPromise()
      end, function() 
        self.chatUUID = nil
        pullPromise()
      end)
    end)
  end
  
  pullPromise()
end

function prepareForCallbacks()
  local calbacksReady = registerCallbacks()
  
  if not calbacksReady then
    ICChatTimer:add(0.5, prepareForCallbacks)
    starcustomchat.utils.resetShared()
  end
end

function registerCallbacks()

  if not starcustomchat.utils.setMessageHandler then
    return false
  end
  
  starcustomchat.utils.setMessageHandler( "scc_reload_callbacks", localHandler(prepareForCallbacks))
  starcustomchat.utils.setMessageHandler( "scc_is_open", localHandler(function() return true end))


  starcustomchat.utils.setMessageHandler( "icc_request_player_portrait", simpleHandler(function()
    if player.id() and player.uniqueId() and world.entityExists(player.id()) then
      local portraitTable = player.getProperty("icc_custom_portrait")
      local portraitSelected = player.getProperty("icc_custom_portrait_selected")
      local portrait = nil
      local frameTable = root.getConfiguration("scc_custom_frames") or {}
      local frameSelected = player.getProperty("scc_custom_frame_selected")

      if portraitTable then
        if type(portraitTable) == "table" then
          portrait = portraitSelected and portraitSelected ~= 0 and portraitTable[portraitSelected or #portraitTable] or nil
        end
      end

      return {
        portrait = portrait or starcustomchat.utils.clearPortraitFromInvisibleLayers(world.entityPortrait(player.id(), "full")),
        type = "UPDATE_PORTRAIT",
        entityId = player.id(),
        connection = starcustomchat.utils.entityIdToConnection(player.id()),
        settings = player.getProperty("icc_portrait_settings") or {
          offset = self.customChat.config.defaultPortraitOffset,
          scale = self.customChat.config.defaultPortraitScale
        },
        uuid = player.uniqueId(),
        frame = frameTable[frameSelected]
      }
    end
  end))

  starcustomchat.utils.setMessageHandler("scc_add_message", simpleHandler(function(message)
    self.customChat:addMessage(message)
  end))

  starcustomchat.utils.setMessageHandler("icc_close_chat", localHandler(function(message)
    uninit()
    pane.dismiss()
  end))

  starcustomchat.utils.setMessageHandler("icc_send_player_portrait", simpleHandler(function(data)
    self.customChat:updatePortrait(data)
  end))

  starcustomchat.utils.setMessageHandler("scc_check_uuid", localHandler(function(uuid)
    if self.chatUUID ~= uuid then
      pane.dismiss()
    end
  end))

  starcustomchat.utils.setMessageHandler( "scc_set_settings", localHandler(function(data)
    if data.scope == "root" then
      Configuration:setRootValue(data.parameter, data.value)
    elseif data.scope == "player" then
      Configuration:setPlayerValue(data.parameter, data.value)
    else 
      sb.logError("Unknown scope: %s", data.scope)
      return
    end

    self.runCallbackForPlugins("onSettingsUpdate", data)
  end))

  starcustomchat.utils.setMessageHandler( "scc_reset_settings", localHandler(function(data)
    starcustomchat.utils.getLocale()
    createTotallyFakeWidgets(self.customChat.config.wrapWidthFullMode, 
      self.customChat.config.wrapWidthCompactMode, 
      root.getConfiguration("icc_font_size") or self.customChat.config.fontSize, 
      self.customChat:getFont("chattext")
    )
    self.runCallbackForPlugins("onSettingsUpdate", data)
    
    localeChat()
    self.customChat:resetChat()
  end))

  starcustomchat.utils.setMessageHandler( "scc_clear_history", localHandler(function(data)
    self.customChat:clearHistory()
  end))

  starcustomchat.utils.setMessageHandler( "/clearchat", localHandler(function(data)
    self.customChat:clearHistory()
  end))

  starcustomchat.utils.setMessageHandler( "/filter", localHandler(function(data)
    self.customChat:setFilter(data)
  end))

  starcustomchat.utils.setMessageHandler("scc_edit_message", function(_, _, data)
    local msgInd = self.customChat:findMessageByUUID(data.uuid)
    if msgInd then
      data.edited = true
      data = self.customChat.callbackPlugins("editMessage", data)
      local message = self.customChat.messages[msgInd]
      message.text = data.text
      message.mode = data.mode
      message.textHeight = nil

      if not message.edited then
        message.time = "^set;^lightgray;(" .. starcustomchat.utils.getTranslation("chat.message.edited") .. ")^reset; "
          .. (message.time or "")
        message.edited = true
        message.forceAvatar = true
      end

      local newUUID = self.customChat:calculateUUID(data)
      local oldUUID = message.uuid
      self.customChat:replaceUUID(oldUUID, newUUID)

      self.customChat:processQueue()
    end
  end)

  starcustomchat.utils.setMessageHandler("scc_stagehand_allowed_messages", simpleHandler(function(messageTypes)
    if messageTypes then
      self.runCallbackForPlugins("registerStagehandHandlers", starcustomchat.utils.listToSet(messageTypes))
    end
  end))

  starcustomchat.utils.setMessageHandler("scc_stagehand_commandlist", simpleHandler(function(commandList, pluginName)
    self.commandPreview:add({ [pluginName or "serverside"] = commandList })
  end))

  self.runCallbackForPlugins("registerMessageHandlers")
  self.runCallbackForPlugins("_requestStagehandHandlers")
  self.runCallbackForPlugins("_requestCommands")

  -- We should request the portraits (ours too) only after we are ready to accept them
  requestPortraits()
  Configuration:reset()
  return true
end

function requestPortraits()
  local messages = self.customChat:getMessages()
  local authors = {}

  -- First, gather the unique connections
  for _, msg in ipairs(messages) do
    local conn = msg.connection
    if conn and conn ~= 0 and not authors[conn] then
      authors[conn] = true
    end
  end

  for conn, _ in pairs(authors) do 
    self.customChat:requestPortrait(conn)
  end
end

function createTotallyFakeWidgets(wrapWidthFullMode, wrapWidthCompactMode, fontSize, font)
  pane.removeWidget("totallyFakeLabelFullMode")
  pane.removeWidget("totallyFakeLabelCompactMode")

  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidthFullMode,
    fontSize = fontSize,
    position = {-100, -100},
    font = font or nil
  }, "totallyFakeLabelFullMode")
  pane.addWidget({
    type = "label",
    wrapWidth = wrapWidthCompactMode,
    fontSize = fontSize,
    position = {-100, -100},
    font = font or nil
  }, "totallyFakeLabelCompactMode")
end

function findButtonByMode(mode)
  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    if button.data.mode == mode then
      return i
    end
  end
  return -1
end

function localeChat()
  local hasFocus = self.customChat:hasFocusInput()

  local buttons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, button in ipairs(buttons) do
    local name = starcustomchat.utils.getTranslation("chat.modes." .. button.data.mode)
    widget.setText("rgChatMode." .. i, name)
  end

  self.customChat:resetHint()

  self.runCallbackForPlugins("onLocaleChange")


  if hasFocus then
    self.customChat:focusInput()
  end
end

function update(dt)

  ICChatTimer:update(dt)
  promises:update()
  animatedWidgets:update(dt)
  
  if self.drawingCanvas then self.drawingCanvas:clear() end

  self.customChat:clearHighlights()
  widget.setVisible("lytContext", false)

  checkTyping()
  checkCommandsPreview()
  processButtonEvents(dt)
  processLeftMenuButtons()

  if self.toggleMoveChat and pane.setPosition then
    local mousePosition = currentMousePosition()
    if mousePosition then
      local cursorPosition = vec2.sub(mousePosition, vec2.div(widget.getSize("btnMoveChat"), 2))
      pane.setPosition(vec2.sub(cursorPosition, widget.getPosition("btnMoveChat")))
    end
  end

  processChatResize()

  self.runCallbackForPlugins("update", dt)
end

function cursorOverride(screenPosition)
  if self.toggleResizeChat then
    return
  end

  processEvents(screenPosition)
  processContextMenu(screenPosition)

  self.runCallbackForPlugins("onCursorOverride", screenPosition)
end

function textboxCallback()
  self.runCallbackForPlugins("onTextboxCallback", self.customChat:getText())
end

function checkCommandsPreview()
  local text = self.customChat:getText()
  self.commandPreview:update(text)
end

function checkTyping()
  local text = self.customChat:getText()

  if not widget.setHint then
    widget.setVisible("lblTextboxHint", text == "")
  end

  if (self.customChat:hasFocusInput() or text ~= "" or self.runCallbackForPlugins("showDots") ) and not next(status.getPersistentEffects("starchatdots")) ~= nil then
    status.addPersistentEffect("starchatdots", "starchatdots")
  else
    status.clearPersistentEffects("starchatdots")
    self.currentSentMessage = nil
    self.recalledSentMessage = nil
  end
end

function defaultChatSizeSettings(chatParameters)
  local bodyWidth = chatParameters.chatBodyWidth or 270
  local paneWidthPadding = chatParameters.paneWidthPadding or 37
  local maxBodyHeight = chatParameters.maxChatBodyHeight or 400

  return {
    paneWidth = bodyWidth + paneWidthPadding,
    currentHeight = maxBodyHeight
  }
end

function normalizeChatSizeSettings(chatParameters, sizeSettings)
  local defaults = defaultChatSizeSettings(chatParameters)
  local paneWidthPadding = chatParameters.paneWidthPadding or 37
  local minPaneWidth = (chatParameters.minChatBodyWidth or 270) + paneWidthPadding
  local maxPaneWidth = (chatParameters.maxChatBodyWidth or 600) + paneWidthPadding
  local minBodyHeight = chatParameters.minChatBodyHeight or 90
  local maxBodyHeight = chatParameters.maxChatBodyHeight or 400

  local normalized = {
    paneWidth = math.floor(util.clamp(tonumber(sizeSettings.paneWidth) or defaults.paneWidth, minPaneWidth, maxPaneWidth) + 0.5),
    currentHeight = math.floor(util.clamp(tonumber(sizeSettings.currentHeight) or defaults.currentHeight, minBodyHeight, maxBodyHeight) + 0.5)
  }

  return normalized
end

function loadChatSizeSettings(chatParameters)
  local stored = root.getConfiguration("scc_chat_size") or {}
  if type(stored) ~= "table" then
    stored = {}
  end

  local defaults = defaultChatSizeSettings(chatParameters)
  return normalizeChatSizeSettings(chatParameters, {
    paneWidth = stored.paneWidth or stored[1] or defaults.paneWidth,
    currentHeight = stored.currentHeight or defaults.currentHeight
  })
end

function applyChatSizeSettings(chatParameters, sizeSettings)
  local paneWidthPadding = chatParameters.paneWidthPadding or 37
  local bodyWidth = math.max(1, sizeSettings.paneWidth - paneWidthPadding)

  chatParameters.chatBodyWidth = bodyWidth
  chatParameters.currentChatHeight = sizeSettings.currentHeight
  chatParameters.wrapWidthFullMode = math.max(30, bodyWidth - (chatParameters.wrapWidthFullModePadding or 45))
  chatParameters.wrapWidthCompactMode = math.max(30, bodyWidth - (chatParameters.wrapWidthCompactModePadding or 10))
  chatParameters.textBoxDefaultSize = {bodyWidth, chatParameters.textBoxDefaultSize and chatParameters.textBoxDefaultSize[2] or 13}
end

function setWidgetWidth(widgetName, width)
  local size = nil
  local success = pcall(function()
    size = widget.getSize(widgetName)
  end)

  if success and size then
    widget.setSize(widgetName, {width, size[2]})
  end
end

function setResizableWidgetWidths(chatParameters, sizes)
  local bodyWidth = chatParameters.chatBodyWidth or widget.getSize(self.canvasName)[1]
  local bodyLeft = widget.getPosition("imgTextbox")[1]
  local bodyRight = bodyLeft + bodyWidth

  setWidgetWidth("imgTextbox", bodyWidth)
  setWidgetWidth("lytSubMenu", bodyWidth)
  setWidgetWidth("lytSubMenu.background", bodyWidth)
  setWidgetWidth("lytNotification", bodyWidth)
  setWidgetWidth("lytNotification.background", bodyWidth)
  setWidgetWidth("lytNotification.lblNotification", bodyWidth)
  setWidgetWidth("lytCommandPreview", bodyWidth)
  setWidgetWidth("lytCommandPreview.imgBackground", math.max(1, bodyWidth - 1))
  setWidgetWidth("lytCommandPreview.imgStretchDescription", bodyWidth)
  setWidgetWidth("background", bodyWidth)
  setWidgetWidth("backgroundImage", bodyWidth)
  setWidgetWidth("frameImage", bodyWidth)
  setWidgetWidth(self.canvasName, bodyWidth)
  setWidgetWidth(self.highlightCanvasName, bodyWidth)
  setWidgetWidth("cnvBackgroundCanvas", bodyWidth)
  setWidgetWidth("saScrollArea", bodyWidth)

  if self.customChat and self.customChat.textBox then
    self.customChat.textBox:setSize(widget.getSize("imgTextbox"))
  end

  -- Resize and reposition mode buttons
  local modeButtons = config.getParameter("gui")["rgChatMode"]["buttons"]
  
  self.modeImageSize = self.modeImageSize or root.imageSize("/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png")

  if modeButtons and #modeButtons > 0 then
    local rgChatModePos = widget.getPosition("rgChatMode")
    local modeFilterWidth = widget.getSize("lytModeFilter")[1]
    local availableWidthForModes = math.max(1, bodyRight - rgChatModePos[1])
    local buttonWidth = availableWidthForModes / #modeButtons
    local diffDirectives = string.format("?scalenearest=%s;1", buttonWidth / self.modeImageSize[2] )
    
    for i, btn in ipairs(modeButtons) do
      local newPosition = {(i - 1) * buttonWidth, 0}
      widget.setPosition("rgChatMode." .. i, newPosition)
      widget.setButtonImages("rgChatMode." .. i, {
        base = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png" .. diffDirectives,
        hover = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png?brightness=30" .. diffDirectives,
        pressed = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmodeselected.png" .. diffDirectives
      })
      widget.setButtonCheckedImages("rgChatMode." .. i, {
        base = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png" .. diffDirectives,
        hover = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png?brightness=30" .. diffDirectives,
        pressed = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmodeselected.png" .. diffDirectives
      })
      widget.setSize("rgChatMode." .. i, {buttonWidth, widget.getSize("rgChatMode." .. i)[2]})
    end
  end

  widget.setPosition("lytModeFilter", {bodyRight, widget.getPosition("lytModeFilter")[2]})
  widget.setPosition("btnMoveChat", {bodyRight, widget.getPosition("btnMoveChat")[2]})

  if sizes then
    local resizeButtonSize = widget.getSize("btnResizeChat")
    widget.setPosition("btnResizeChat", {bodyRight, math.max(0, sizes.fullSize[2] - resizeButtonSize[2])})
  else
    widget.setPosition("btnResizeChat", {bodyRight, widget.getPosition("btnResizeChat")[2]})
  end

  widget.setPosition("lytSubMenu.resetEditLayout", {math.max(0, bodyWidth - 15), widget.getPosition("lytSubMenu.resetEditLayout")[2]})
end

function applyWidgetSizeSettings(chatParameters)
  setResizableWidgetWidths(chatParameters)
  local sizes = getSizes(chatParameters)
  setResizableWidgetWidths(chatParameters, sizes)

  if pane.setSize then
    pane.setSize(sizes.fullSize)
  end
end

function getSizes(chatParameters)
  local canvasSize = {chatParameters.chatBodyWidth or widget.getSize(self.canvasName)[1], widget.getSize(self.canvasName)[2]}
  local dmPlayersSize = widget.getSize("lytCharactersToDM.background")

  local modeHeight = chatParameters.currentChatHeight or (chatParameters.maxChatBodyHeight or 400)

  local submenuHeight = (widget.active("lytSubMenu") and widget.getSize("lytSubMenu")[2]) or 0
  local textboxHeight = widget.getSize("imgTextbox")[2] 

  local bodyHeight = math.max(modeHeight - submenuHeight -  textboxHeight, 1)

  local buttonsSize = self.modeImageSize[2]
  local paneWidthPadding = chatParameters.paneWidthPadding or math.max(0, pane.getSize()[1] - canvasSize[1])

  return {
    fullHeight = {canvasSize[1], modeHeight + 2},
    canvasSize = {canvasSize[1], bodyHeight + 2},
    dmPlayersSize = {dmPlayersSize[1], math.max(modeHeight - widget.getPosition("lytCharactersToDM")[2], 1)},
    dmPlayersSASize = {dmPlayersSize[1] + 10, math.max(modeHeight - widget.getPosition("lytCharactersToDM")[2], 1)},
    submenuHeight = submenuHeight,
    textboxHeight = textboxHeight,
    fullSize = {canvasSize[1] + paneWidthPadding, bodyHeight + submenuHeight + textboxHeight + buttonsSize + 2}
  }
end

function setSizes(chatParameters, smooth)
  local sizes = getSizes(chatParameters)
  local speed = chatParameters.chatSizeChangeSpeed

  if pane.setSize then
    if smooth then
      animatedWidgets:add(AnimatedWidget:setPaneSize(sizes.fullSize, speed))
    else
      pane.setSize(sizes.fullSize)
    end
  end

  setResizableWidgetWidths(chatParameters, sizes)

  widget.setPosition("lytSubMenu", vec2.add(widget.getPosition("imgTextbox"), {0, widget.getSize("imgTextbox")[2]}))
  widget.setPosition("lytNotification", vec2.add(widget.getPosition("lytSubMenu"), {0, sizes.submenuHeight}))

  local canvasTopOffset = sizes.submenuHeight
  local canvasBasePosition = vec2.add(widget.getPosition("lytSubMenu"), {0, canvasTopOffset})
  widget.setPosition(self.canvasName, canvasBasePosition)
  widget.setPosition("saScrollArea", canvasBasePosition)
  widget.setPosition(self.highlightCanvasName, canvasBasePosition)
  widget.setPosition(self.topCanvasName, canvasBasePosition)
  widget.setPosition("lytCommandPreview", canvasBasePosition)
  widget.setPosition("backgroundImage", canvasBasePosition)
  widget.setPosition("background", canvasBasePosition)
  widget.setPosition("frameImage", canvasBasePosition)

  widget.setSize(self.canvasName, sizes.canvasSize)
  widget.setSize(self.highlightCanvasName, sizes.canvasSize)
  widget.setSize(self.topCanvasName, sizes.canvasSize)
  widget.setSize("cnvBackgroundCanvas", sizes.canvasSize)
  widget.setSize("saScrollArea", sizes.canvasSize)
  widget.setSize("lytCommandPreview", sizes.canvasSize)
  widget.setSize("lytCommandPreview.imgBackground", {sizes.canvasSize[1], widget.getSize("lytSubMenu")[2]})
  widget.setSize("lytSubMenu", {sizes.canvasSize[1], widget.getSize("lytSubMenu")[2]})
  widget.setSize("lytSubMenu.background", {sizes.canvasSize[1], widget.getSize("lytSubMenu")[2]})

  if smooth then
    animatedWidgets:add(AnimatedWidget:bind("background"):setSize(sizes.canvasSize, speed))
    animatedWidgets:add(AnimatedWidget:bind("backgroundImage"):setSize(sizes.canvasSize, speed))
    animatedWidgets:add(AnimatedWidget:bind("frameImage"):setSize(sizes.canvasSize, speed), function()
        widget.setSize(self.canvasName, sizes.canvasSize)
        widget.setSize(self.highlightCanvasName, sizes.canvasSize)
        widget.setSize(self.topCanvasName, sizes.canvasSize)
        widget.setSize("cnvBackgroundCanvas", sizes.canvasSize)
    end)
    
    animatedWidgets:add(AnimatedWidget:bind("lytCharactersToDM"):setSize(sizes.dmPlayersSASize, speed))
    animatedWidgets:add(AnimatedWidget:bind("lytCharactersToDM.saPlayers"):setSize(sizes.dmPlayersSASize, speed))
    animatedWidgets:add(AnimatedWidget:bind("lytCharactersToDM.background"):setSize(sizes.dmPlayersSize, speed))
  else
    widget.setSize("background", sizes.canvasSize)
    widget.setSize("backgroundImage", sizes.canvasSize)
    widget.setSize("frameImage", sizes.canvasSize)
    widget.setSize("lytCharactersToDM", sizes.dmPlayersSASize)
    widget.setSize("lytCharactersToDM.background", sizes.dmPlayersSize)
    widget.setSize("lytCharactersToDM.saPlayers", sizes.dmPlayersSASize)
  end

  if self.customChat then
    self.customChat:drawBackground()
    self.customChat:updateTextboxMaxHeight()
  end
end

function modeHeightFromPaneSize(paneSize, chatParameters)
  return paneSize[2] - self.modeImageSize[2] - 2
end

function chatSizeSettingsFromPaneSize(paneSize)
  local settings = copy(self.chatSizeSettings or defaultChatSizeSettings(self.customChat.config))
  settings.paneWidth = paneSize[1]
  settings.currentHeight = modeHeightFromPaneSize(paneSize, self.customChat.config)

  return normalizeChatSizeSettings(self.customChat.config, settings)
end

function saveChatSizeSettings()
  if self.chatSizeSettings and pane.setSize then
    root.setConfiguration("scc_chat_size", self.chatSizeSettings)
  end
end

function resizeChatToPaneSize(paneSize)
  if not pane.setSize or not paneSize then
    return
  end

  local oldWidth = self.customChat.config.chatBodyWidth
  self.chatSizeSettings = chatSizeSettingsFromPaneSize(paneSize)
  applyChatSizeSettings(self.customChat.config, self.chatSizeSettings)
  setSizes(self.customChat.config)

  if oldWidth ~= self.customChat.config.chatBodyWidth then
    createTotallyFakeWidgets(
      self.customChat.config.wrapWidthFullMode,
      self.customChat.config.wrapWidthCompactMode,
      self.customChat.config.fontSize,
      self.customChat:getFont("chattext")
    )
    self.customChat.recalculateHeight = true
  end

  self.customChat:processQueue()
end

function bindChatInterfaceCanvas()
  if not self.drawingCanvas and interface.bindCanvas then
    pcall(function()
      self.drawingCanvas = interface.bindCanvas("chatInterfaceCanvas")
    end)
  end

  return self.drawingCanvas
end

function currentMousePosition()
  if not self.drawingCanvas then
    bindChatInterfaceCanvas()
  end

  if self.drawingCanvas and self.drawingCanvas.mousePosition then
    return self.drawingCanvas:mousePosition()
  end

  if input.mousePosition then
    return input.mousePosition()
  end
end

function processChatResize()
  if not self.toggleResizeChat or not pane.setSize or not pane.getPosition then
    return
  end

  local mousePosition = currentMousePosition()
  if not mousePosition then
    return
  end

  local resizeCursorOffset = self.resizeCursorOffset or {0, 0}
  local desiredPaneSize = vec2.add(vec2.sub(mousePosition, pane.getPosition()), resizeCursorOffset)
  desiredPaneSize = {math.floor(desiredPaneSize[1] + 0.5), math.floor(desiredPaneSize[2] + 0.5)}

  if not self.lastRequestedChatSize or desiredPaneSize[1] ~= self.lastRequestedChatSize[1] or desiredPaneSize[2] ~= self.lastRequestedChatSize[2] then
    self.lastRequestedChatSize = desiredPaneSize
    resizeChatToPaneSize(desiredPaneSize)
  end
end

function canvasClickEvent(position, button, isButtonDown)
  if self.runCallbackForPlugins("onCanvasClick", position, button, isButtonDown) then
    return
  end

  if self.toggleMoveChat or self.toggleResizeChat then
    widget.blur(self.canvasName)
    widget.blur(self.highlightCanvasName)
    widget.blur(self.topCanvasName)
    return
  end
  
  if button == 0 and isButtonDown then    
    local minBodyHeight = self.customChat.config.minChatBodyHeight
    local maxBodyHeight = self.customChat.config.maxChatBodyHeight
    local heightLeeway = 15
    
    -- Get current height
    local currentHeight = self.chatSizeSettings.currentHeight
    
    -- If at max height (with leeway), set to min, otherwise set to max
    local newHeight = (currentHeight >= maxBodyHeight - heightLeeway) and minBodyHeight or maxBodyHeight
    
    self.chatSizeSettings.currentHeight = newHeight
    
    self.lastRequestedChatSize = {self.chatSizeSettings.paneWidth, self.chatSizeSettings.currentHeight}
    resizeChatToPaneSize(self.lastRequestedChatSize)
    self.customChat:processQueue()
  end

  -- Defocus from the canvases or we can never leave lol :D
  widget.blur(self.canvasName)
  widget.blur(self.highlightCanvasName)
  widget.blur(self.topCanvasName)
end

function processEvents(screenPosition)
  for _, event in ipairs(input.events()) do
    if widget.inMember("saScrollArea", screenPosition) then
      if event.type == "MouseWheel"  then

        if not self.runCallbackForPlugins("onChatScroll", screenPosition) then
          if input.key("LCtrl") then
            local newChatSize = math.min(math.max(self.customChat.config.fontSize + event.data.mouseWheel, 6), 10)
            if newChatSize ~= self.customChat.config.fontSize then
              self.customChat.recalculateHeight = true
            end
            self.customChat.config.fontSize = newChatSize

            root.setConfiguration("icc_font_size", self.customChat.config.fontSize)
            createTotallyFakeWidgets(self.customChat.config.wrapWidthFullMode, self.customChat.config.wrapWidthCompactMode, self.customChat.config.fontSize, self.customChat:getFont("chattext"))
            self.customChat:processQueue()
          else
            local lineHeight = self.customChat.config.fontSize + self.customChat.config.spacings.lines
            self.customChat:offsetCanvas(event.data.mouseWheel * -lineHeight * (input.key("LShift") and 2 or 1))
          end
        end
      elseif event.type == "KeyDown" then
        self.customChat:ignoreInputFrame()
        if event.data.key == "PageUp" then
          self.customChat:offsetCanvas(-self.chatSizeSettings.currentHeight)
        elseif event.data.key == "PageDown" then
          self.customChat:offsetCanvas(self.chatSizeSettings.currentHeight)
        elseif event.data.key == "End" then
          self.customChat:resetCanvasOffset()
        end
      end
    end
  end
end

function processButtonEvents(dt)

  if self.customChat:hasFocusInput() then
    for _, event in ipairs(input.events()) do
      if event.type == "KeyDown" then
        local lShift = event.data.mods and (event.data.mods.LShift or index(event.data.mods, "LShift") ~= 0)
        local rShift = event.data.mods and (event.data.mods.RShift or index(event.data.mods, "RShift") ~= 0)
        local lCtrl = event.data.mods and (event.data.mods.LCtrl or index(event.data.mods, "LCtrl") ~= 0)
        local rCtrl = event.data.mods and (event.data.mods.RCtrl or index(event.data.mods, "RCtrl") ~= 0)
        local lAlt = event.data.mods and (event.data.mods.LAlt or index(event.data.mods, "LAlt") ~= 0)
        local rAlt = event.data.mods and (event.data.mods.RAlt or index(event.data.mods, "RAlt") ~= 0)
        local shiftPressed = lShift or rShift
        local ctrlPressed = lCtrl or rCtrl
        local altPressed = lAlt or rAlt

        if event.data.key == "Tab" then
          self.commandPreview:advanceSelection()
        elseif event.data.key == "Up" and altPressed then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.max(self.currentSentMessage - 1, 1) or #self.sentMessages
            self.recalledSentMessage = self.sentMessages[self.currentSentMessage]
            self.customChat:setText(self.recalledSentMessage)
          end
          self.customChat:ignoreInputFrame()
        elseif event.data.key == "Down" and altPressed then
          if #self.sentMessages > 0 then
            self.currentSentMessage = self.currentSentMessage and math.min(self.currentSentMessage + 1, #self.sentMessages) or #self.sentMessages
            self.recalledSentMessage = self.sentMessages[self.currentSentMessage]
            self.customChat:setText(self.recalledSentMessage)
          end
          self.customChat:ignoreInputFrame()
        end
      end
    end
  end


  if input.bindDown("starcustomchat", "repeatcommand") and self.lastCommand then
    self.customChat:processCommand(self.lastCommand)
  end

  self.runCallbackForPlugins("processEvents", input.events())
end

function processLeftMenuButtons()
  if widget.getScrollOffset and widget.getMaxScrollPosition then
    local currentOffset = widget.getScrollOffset("lytLeftMenu.saButtons")

    widget.setButtonEnabled("lytLeftMenu.btnDown", currentOffset[2] > 0)
    widget.setButtonEnabled("lytLeftMenu.btnUp", currentOffset[2] < widget.getMaxScrollPosition("lytLeftMenu.saButtons")[2])
  end
end

function scrollLeftMenuUp()
  if widget.getScrollOffset and widget.setScrollOffset then
    local currentOffset = widget.getScrollOffset("lytLeftMenu.saButtons")
    widget.setScrollOffset("lytLeftMenu.saButtons", vec2.add(currentOffset, {0, self.customChat.config.scrollAreaButtonMove}))
  end
end

function scrollLeftMenuDown()
  if widget.getScrollOffset and widget.setScrollOffset then
    local currentOffset = widget.getScrollOffset("lytLeftMenu.saButtons")
    widget.setScrollOffset("lytLeftMenu.saButtons", vec2.add(currentOffset, {0, -self.customChat.config.scrollAreaButtonMove}))
  end
end

function escapeTextbox()

  if not self.runCallbackForPlugins("onTextboxEscape") then
    self.recalledSentMessage = nil
    self.customChat:setText("")
    self.customChat:blurInput()
  end
end

function sendMessageToBeSent(text, mode)
  mode = mode or widget.getSelectedData("rgChatMode").mode
  -- Add trim
  text = starcustomchat.utils.trim(text)

  local message = {
    text = text,
    mode = mode
  }

  local pingEntityId, pingName = self.commandPreview:getPingTarget(text)
  if pingEntityId then
    message.pingTarget = {
      entityId = pingEntityId,
      name = pingName
    }
  end

  if self.runCallbackForPlugins("preventTextboxCallback", message) then
    return
  end

  local selectedInsertion = self.commandPreview:getSelectedInsertion(text)

  if string.sub(text, 1, 1) == "/" and not string.find(text, "^/%w+%.png") then
    if string.len(text) == 1 then
      self.recalledSentMessage = nil
      self.customChat:setText("")
      self.customChat:blurInput()
      return
    end

    if selectedInsertion then
      self.recalledSentMessage = nil
      self.customChat:setText(selectedInsertion .. " ")
      self.commandPreview:reset()
      return
    else
      self.customChat:processCommand(text)
      self.lastCommand = text
      starcustomchat.utils.saveMessage(text)
    end
  elseif string.sub(text, 1, 1) == "@" and selectedInsertion then
      self.recalledSentMessage = nil
      self.customChat:setText(selectedInsertion .. " ")
      self.commandPreview:reset()
      return
  
  elseif not self.runCallbackForPlugins("onTextboxEnter", message) then 
    if message.mode == "Whisper" then

      local data = message.whisperData or self.DMTab:selectedPlayer()
      if not data then starcustomchat.utils.alert("chat.alerts.dm_not_specified") return end


      local function sendWhisperToPlayer(targetName, targetId)
        
        -- Let's start sending SEMs by default
          message.connection = starcustomchat.utils.entityIdToConnection(player.id())
          message.nickname = player.name()
          message = self.runCallbackForPlugins("formatOutcomingMessage", message)
          self.runCallbackForPlugins("onSendMessage", message)
          
          promises:add(world.sendEntityMessage(targetId, "scc_add_message", message), function() 
            if targetId ~= player.id() then
              local oldUUID = self.customChat:calculateUUID(message)
              local msgInd = self.customChat:findMessageByUUID(oldUUID)
              if msgInd and self.customChat.messages[msgInd].mode == "Whisper" then
                local oldDisplayName = self.customChat.messages[msgInd].displayName or self.customChat.messages[msgInd].nickname
                self.customChat.messages[msgInd].displayName = oldDisplayName .. ", " .. targetName
                self.customChat:processQueue()
              else
                message.displayName = "-> " .. targetName
                world.sendEntityMessage(player.id(), "scc_add_message", message)
              end
            end
          end, function() 
            local whisper = string.find(targetName, "%s") and "/w \"" .. targetName .. "\" " .. message.text 
              or "/w " .. targetName .. " " .. message.text

            self.customChat:processCommand(whisper)
            self.customChat.lastWhisper = {
              recipient = targetName,
              text = message.text
            }
          end)

      end

      if data.id then
        starcustomchat.utils.saveMessage(message.text)

        -- Player ID situation
        if type(data.id) == "number" then

          local whisperName = data.displayPlainText or ""
          sendWhisperToPlayer(whisperName, data.id)
        -- Party whisper
        elseif data.id == "PARTY" then
          for _, teamMember in ipairs(player.teamMembers()) do 
            if teamMember.entity ~= player.id() then
              sendWhisperToPlayer(teamMember.name, teamMember.entity)
            end
          end
        end
      end

    else
      starcustomchat.utils.saveMessage(message.text)
      message = self.runCallbackForPlugins("formatOutcomingMessage", message)
      sendMessage(message)
    end
  end
  self.recalledSentMessage = nil
  self.customChat:setText("")
  self.customChat:blurInput()
  self.runCallbackForPlugins("afterTextboxPressed", message)
end

function textboxEnterKey()
  local text = self.customChat:getText()

  if text == "" then
    self.customChat:setText("")
    self.customChat:blurInput()
    return
  end

  sendMessageToBeSent(text, mode)
end

function sendMessage(message)
  self.customChat:sendMessage(message)
end

function setMode(id, data)
  local modeButtons = config.getParameter("gui")["rgChatMode"]["buttons"]
  for i, btn in ipairs(modeButtons) do
    widget.setFontColor("rgChatMode." .. i, self.customChat.config.unselectedModeColor)
  end
  widget.setFontColor("rgChatMode." .. id, self.customChat.config.modeColors[data.mode])

  self.runCallbackForPlugins("onModeChange", data.mode)
  root.setConfiguration("scc_message_mode", id)
end

function modeToggle(button, isChecked)
  self.runCallbackForPlugins("onModeToggle", button, widget.getChecked(button))
  self.customChat:processQueue()
end

function toBottom()
  self.customChat:resetCanvasOffset()
end

function openSettings()
  Configuration:save()
  local chatConfigInterface = self.settingsInterface
  chatConfigInterface.enabledPlugins = config.getParameter("enabledPlugins", {})
  chatConfigInterface.chatConfig = self.customChat.config
  chatConfigInterface.localizationTable = starcustomchat.locale

  chatConfigInterface = self.runCallbackForPlugins("openSettings", chatConfigInterface)
  player.interact("ScriptPane", chatConfigInterface)
end

function createTooltip(screenPosition)
  if widget.getChildAt(screenPosition) then
    local w = widget.getChildAt(screenPosition)

    local wData = widget.getData(w:sub(2))
    if wData and type(wData) == "table" then
      if wData.tooltipMode then
        return wData.mode and starcustomchat.utils.getTranslation("chat.modes." .. wData.mode) or wData.tooltipMode
      elseif wData.displayPlainText then
        return wData.displayPlainText
      elseif wData.displayText then
        return starcustomchat.utils.getTranslation(wData.displayText, wData.displayParams)
      end
    end
  end

  return self.runCallbackForPlugins("onCreateTooltip", screenPosition)
end

-- Custom callbacks, in case we need several under one button (i.e. textbox)

function customButtonCallback(buttonName, data)
  self.runCallbackForPlugins("onCustomButtonClick", buttonName, data)
end

function customButtonCallback2(buttonName, data)
  self.runCallbackForPlugins("onCustomButtonClick2", buttonName, data)
end

function customButtonCallback3(buttonName, data)
  self.runCallbackForPlugins("onCustomButtonClick3", buttonName, data)
end

function closeSubMenu()
  self.customChat:closeSubMenu()
  self.runCallbackForPlugins("onSubMenuClose", buttonName, data)
  self.customChat:processQueue()
end

function toggleChatMovement()
  self.toggleMoveChat = widget.getChecked("btnMoveChat")
  widget.setVisible("saScrollArea", not self.toggleMoveChat)

  if self.toggleMoveChat then
    self.toggleResizeChat = false
    widget.setChecked("btnResizeChat", false)
  end
end

function toggleChatResize()
  self.toggleResizeChat = widget.getChecked("btnResizeChat")
  widget.setVisible("saScrollArea", not self.toggleResizeChat)

  if self.toggleResizeChat then
    self.toggleMoveChat = false
    widget.setChecked("btnMoveChat", false)
    self.selectedMessage = nil
    widget.setVisible("lytContext", false)

    local mousePosition = currentMousePosition()
    if mousePosition and pane.getPosition and pane.getSize then
      self.resizeCursorOffset = vec2.sub(pane.getSize(), vec2.sub(mousePosition, pane.getPosition()))
    else
      self.resizeCursorOffset = {0, 0}
    end
  else
    self.resizeCursorOffset = nil
    self.lastRequestedChatSize = nil
    saveChatSizeSettings()
    self.customChat:processQueue()
  end
end

function saveEverythingDude()
  -- Save messages and last command
  local messages = self.customChat:getMessages()
  for _, message in ipairs(messages) do 
    self.runCallbackForPlugins("cleanMessage", message)
  end
  root.setConfiguration("icc_last_messages", messages)
  root.setConfiguration("icc_last_command", self.lastCommand)
  root.setConfiguration("icc_my_messages", util.toList(self.sentMessages))
  root.setConfiguration("scc_chat_position", pane.getPosition and pane.getPosition() or nil)
  saveChatSizeSettings()
end

function closeChat()
  pane.hide()
end

-- OpenStarbound chat
function startChat()
  pane.show()
  self.customChat:focusInput()
  chat.setInput("")
end

function startCommand()
  pane.show()
  self.customChat:setText("/")
  self.customChat:focusInput()
  chat.setInput("")
end

function convertToChatMessage(oldMessage)
  local newMessage = {}
  newMessage.text = oldMessage.text
  newMessage.connection = oldMessage.fromConnection
  newMessage.mode = oldMessage.context.mode
  newMessage.nickname = oldMessage.fromNick
  newMessage.portrait = oldMessage.portrait
  newMessage.data = oldMessage.data
  return newMessage
end

function addMessages(messages, showPane) 
  for _, message in ipairs(messages) do
    local message = convertToChatMessage(message)
    self.customChat:addMessage(message)
  end
end

function uninit()
  local text = self.customChat:getText()
  if not self.reopening and text and text ~= "" then
    clipboard.setText(text)
  end

  saveEverythingDude()
  widget.setSize("imgTextbox", self.customChat.config.textBoxDefaultSize)
  
  status.clearPersistentEffects("starchatdots")
  self.runCallbackForPlugins("uninit")
  Configuration:save()
end


-- Required to be at the very bottom
require("/interface/StarboundTextboxInterface/textarea/scripts/textbox.lua")
