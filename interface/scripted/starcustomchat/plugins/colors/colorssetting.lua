require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"
require "/interface/scripted/starcustomchatsettings/colorpicker/widget.lua"

colors = SettingsPluginClass:new(
  { name = "colors" }
)

function colors:init(chat)
  self.picker = colorpicker.new(self.layoutWidget .. ".cnvColorPicker")
  self.currentColor = ""
  self.coursorCanvas = self.widget.bindCanvas("coursorCanvas")
  local defaultColors = {}

  self:addModeItems()

  for _, color in ipairs(self.items) do 
    defaultColors[color.name] = color.default
  end

  self.colors = sb.jsonMerge(defaultColors, root.getConfiguration("scc_custom_colors") or {})
end

function colors:addModeItems()
  local modeColors = self.chatConfig.modeColors or {}
  local disabledModes = root.assetJson("/scripts/starcustomchat/disabledmodes.json")
  local modes = {}
  for mode in pairs(modeColors) do
    if mode ~= "default" then modes[mode] = true end
  end
  for _, mode in ipairs(config.getParameter("chatModes", {})) do
    modes[mode] = true
  end

  local sortedModes = {}
  for mode in pairs(modes) do
    if not disabledModes[mode] then table.insert(sortedModes, mode) end
  end
  table.sort(sortedModes)

  for _, mode in ipairs(sortedModes) do
    table.insert(self.items, {
      name = "mode." .. mode,
      label = "chat.modes." .. mode,
      mode = mode,
      default = colorpicker.toHex(modeColors[mode] or modeColors.default or "white")
    })
  end
end

function colors:populateList()
  self.widget.clearListItems("saScrollArea.listItems")
  self.currentListItem = nil
  self.currentItemName = nil
  self.widget.setVisible("btnDropToDefault", false)


  for _, item in ipairs(self.items) do 
    local li = self.widget.addListItem("saScrollArea.listItems")
    local newListItem = self.layoutWidget .. ".saScrollArea.listItems." .. li

    local label = item.mode and not starcustomchat.utils.hasTranslation(item.label)
      and item.mode or starcustomchat.utils.getTranslation(item.label)
    if item.mode then label = starcustomchat.utils.getTranslation("settings.colors.mode", label) end
    widget.setText(newListItem .. ".name", label)
    widget.setFontColor(newListItem .. ".name", "#" .. (self.colors[item.name] or item.default))
    widget.setData(newListItem, {
      defaultColor = item.default,
      name = item.name
    })
  end
end

function colors:openTab()
  self:populateList()
end

function colors:onLocaleChange()
  if self.opened then self:populateList() end
end

function colors:changedColorItem()
  local selectedItem = self.widget.getListSelected("saScrollArea.listItems")
  if selectedItem then
    local data = self.widget.getData("saScrollArea.listItems." .. selectedItem)
    self.currentListItem = selectedItem
    self.currentItemName = data.name
    self.picker:setColor(self.colors[self.currentItemName] or data.defaultColor)
    self.currentColor = self.picker:hex()
    self:updatePreview()
    self.widget.setVisible("btnDropToDefault", true)
  end
end

function colors:updatePreview()
  self.widget.setFontColor("saScrollArea.listItems." .. self.currentListItem .. ".name", "#" .. self.currentColor)
  self.widget.setImage("previewImage", "/interface/scripted/starcustomchatsettings/colorpicker/previewcolor.png?replace;FFFF=" .. self.currentColor)
end

function colors:cursorOverride()
  if input.mouseUp("MouseLeft") and self.picker.down then
    self.picker.down = false
  end
end

function colors:update()
  self.coursorCanvas:clear()
  if widget.active(self.layoutWidget) and self.currentListItem then
    self.picker:update()
    if self.currentColor ~= self.picker:hex() then
      self.currentColor = self.picker:hex()

      self.colors[self.currentItemName] = self.currentColor
      root.setConfiguration("scc_custom_colors", self.colors)
      save()
      self:updatePreview()
    end

    self.coursorCanvas:drawImage("/interface/easel/spectrumcursor.png", vec2.sub(self.picker.color_mouse, 3), 1)
    self.coursorCanvas:drawImage("/interface/easel/spectrumcursor.png", vec2.sub(self.picker.alpha_mouse, 3), 1)
  end
end

function colors:dropToDefault()
  if self.currentListItem then
    local defaultColor = self.widget.getData("saScrollArea.listItems." .. self.currentListItem).defaultColor
    self.picker:setColor(defaultColor)
    self.currentColor = self.picker:hex()
    self.colors[self.currentItemName] = self.currentColor
    root.setConfiguration("scc_custom_colors", self.colors)
    save()
    self:updatePreview()
  end
end

function colors:clickCanvasCallback(position, button, isDown)
  if widget.active(self.layoutWidget) then
    if button == 0 then
      self.picker.down = isDown
      self.widget.blur("cnvColorPicker")
    end
  end
end
