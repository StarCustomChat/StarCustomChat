function contextMenu_init(buttonsConfig)
  self.contextMenu = {}
  self.contextMenu.buttonConfigs = {}
  self.contextMenu.dotsSize = root.imageSize(config.getParameter("gui")["lytContext"]["children"]["dots"]["base"])

  -- track hover/selection state so heavy layout work runs only when needed
  self.contextMenu.isInContext = false
  self.contextMenu.lastSelectedUUID = nil
  self.contextMenu.pressedParents = {}
  self.contextMenu.keepDotsUntilExit = false
  self.contextMenu.preserveCompoundMenu = false

  local position = {0, 0}

  widget.removeAllChildren("lytContext")
  widget.addChild("lytContext", config.getParameter("gui")["lytContext"]["children"]["dots"], "dots")

  local function addContextMenuButton(buttonConfig, parent) 
    local buttonSize = root.imageSize(buttonConfig["base"])
    local buttonName = buttonConfig.name

    widget.addChild("lytContext", {
      type = "button",
      base = buttonConfig["base"],
      hover = buttonConfig["hover"],
      callback = "contextMenuButtonClick",
      visible = false,
      data = {
        displayText = buttonConfig["tooltip"]
      }
    }, buttonName)

    table.insert(self.contextMenu.buttonConfigs, {
      name = buttonName,
      size = buttonSize,
      parent = parent,
      hasChildren = not not buttonConfig.contains
    })

    if buttonConfig.contains then
      for _, childConfig in ipairs(buttonConfig.contains) do 
        addContextMenuButton(childConfig, buttonName)
      end
    end
  end

  for _, btnConfig in ipairs(buttonsConfig) do 
    addContextMenuButton(btnConfig, nil)
  end
end

function rebuildContextMenu(screenPosition)
  local layoutSize = {0, self.contextMenu.dotsSize[2]}

  for _, btnConfig in ipairs(self.contextMenu.buttonConfigs) do
    local buttonName = btnConfig.name

    if (not self.contextMenu.pressedParents[buttonName])
    and (not btnConfig.parent or self.contextMenu.pressedParents[btnConfig.parent])
    and self.runCallbackForPlugins("contextMenuButtonFilter", buttonName, screenPosition, self.selectedMessage) then
      widget.setPosition("lytContext." .. buttonName, {layoutSize[1], 0})
      widget.setVisible("lytContext." .. buttonName, true)
      layoutSize[1] = layoutSize[1] + btnConfig.size[1]
    else
      widget.setVisible("lytContext." .. buttonName, false)
      widget.setPosition("lytContext." .. buttonName, {0, 0})
    end
  end
  widget.setVisible("lytContext.dots", false)
  widget.setSize("lytContext", layoutSize)

  self.contextMenu.lastSelectedUUID = self.selectedMessage and self.selectedMessage.uuid or nil
  self.contextMenu.rebuildMenu = nil
end

function resetContextMenu()
  self.runCallbackForPlugins("contextMenuReset")

  widget.setVisible("lytContext.dots", true)
  for _, btnConfig in ipairs(self.contextMenu.buttonConfigs) do
    widget.setVisible("lytContext." .. btnConfig.name, false)
  end

  widget.setSize("lytContext", self.contextMenu.dotsSize)
  self.contextMenu.lastSelectedUUID = nil
  self.contextMenu.pressedParents = {}
  self.contextMenu.rebuildMenu = nil
end

function processContextMenu(screenPosition)
  self.contextMenu.lastScreenPosition = screenPosition

  -- Clear selection if the selected message was deleted
  if self.selectedMessage and not self.customChat:findMessageByUUID(self.selectedMessage.uuid) then
    self.selectedMessage = nil
  end

  widget.setVisible("lytContext", not not self.selectedMessage)

  if not widget.inMember("lytContext", screenPosition) or not self.selectedMessage then
    self.selectedMessage = self.customChat:selectMessage(screenPosition)
  end

  if self.selectedMessage then
    self.customChat:highlightMessage(self.selectedMessage)
  end

  -- determine current hover / selection identity
  local inContext = widget.inMember("lytContext", screenPosition)

  local prevSelectedUUID = self.contextMenu.lastSelectedUUID
  local selectedUUID = self.selectedMessage and self.selectedMessage.uuid or nil

  if inContext then
    -- only rebuild the visible buttons/layout if selection changed or we just started hovering
    if not self.contextMenu.keepDotsUntilExit
    and (selectedUUID ~= prevSelectedUUID or inContext ~= self.contextMenu.isInContext or self.contextMenu.rebuildMenu) then
      rebuildContextMenu(screenPosition)
    end
  else
    -- only run reset once when we stop hovering
    if self.contextMenu.isInContext then
      if self.contextMenu.preserveCompoundMenu then
        self.contextMenu.preserveCompoundMenu = false
      else
        self.contextMenu.keepDotsUntilExit = false
        resetContextMenu()
      end
    end
  end

  setLayoutPosition()
  self.contextMenu.isInContext = inContext
end

function setLayoutPosition()
  if self.selectedMessage then
  
    local canvasPosition = widget.getPosition(self.highlightCanvasName)
    local xOffset = canvasPosition[1] + widget.getSize(self.highlightCanvasName)[1] - widget.getSize("lytContext")[1]
    local yOffset = self.selectedMessage.offset + self.selectedMessage.height + canvasPosition[2]
    local newOffset = vec2.add({xOffset, yOffset}, self.customChat.config.contextMenuOffset)

    -- And now we don't want the context menu to fly away somewhere else: we always want to draw it within the canvas. Add padding
    local canvasTop = self.customChat.canvas:size()[2] + widget.getPosition(self.canvasName)[2]
    local menuSize = widget.getSize("lytContext")
    newOffset[1] = math.max(canvasPosition[1], math.min(newOffset[1], canvasPosition[1] + widget.getSize(self.highlightCanvasName)[1] - menuSize[1]))
    newOffset[2] = math.max(canvasPosition[2], math.min(newOffset[2], canvasTop - menuSize[2]) - 2)
    widget.setPosition("lytContext", newOffset)
  end
end

function contextMenuButtonClick(buttonName)
  local pressedButtonConf = util.find(self.contextMenu.buttonConfigs, function(conf) return conf.name == buttonName end)

  -- Weird case for when we have no configuration of the button we've pressed.
  if not pressedButtonConf then
    return
  end

  self.contextMenu.pressedParents = {}
  if pressedButtonConf.hasChildren then
    self.contextMenu.pressedParents[buttonName] = true
  end

  
  self.runCallbackForPlugins("contextMenuButtonClick", buttonName, self.selectedMessage)

  if pressedButtonConf.hasChildren then
    self.contextMenu.keepDotsUntilExit = false
    self.contextMenu.preserveCompoundMenu = true
    rebuildContextMenu(self.contextMenu.lastScreenPosition)
    setLayoutPosition()
  else
    self.contextMenu.keepDotsUntilExit = true
    resetContextMenu()
  end
end
