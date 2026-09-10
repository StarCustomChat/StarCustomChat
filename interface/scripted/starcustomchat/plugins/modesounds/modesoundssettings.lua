require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

modesounds = SettingsPluginClass:new(
  { name = "modesounds" }
)


-- Settings
function modesounds:init()
  self.modeSoundTable = root.getConfiguration("scc_mode_sounds") or {}
end

function modesounds:openTab()
  self.soundList = {}
  self.soundListItems = {}

  local sounds = root.assetsByExtension(".ogg")

  table.sort(sounds)

  for _, sound in ipairs(sounds) do
    local name = sound:match("(/[^/]+/[^/]+)$") or sound
    table.insert(self.soundList, {
      name = name:match("([^/]+)$"),
      data = {
        sound = sound,
        displayPlainText = name 
      }
    })
  end

  self:populateScrollArea("saSounds", self.soundList, nil)
  self:populateModesScrollArea()
end

function modesounds:populateModesScrollArea()
  self.selectedModeListItem = nil
  local modeList = {}
  for _, mode in pairs(config.getParameter("chatModes", {})) do
    table.insert(modeList, {
      name = starcustomchat.utils.getTranslation("chat.modes." .. mode) or mode,
      data = mode
    })
  end

  self:populateScrollArea("saModes", modeList, nil, function(name, data, li)
    if self.modeSoundTable[data] then
      self.widget.setFontColor("saModes.listItems." .. li .. ".name", "blue")
    end
  end)
end

function modesounds:onLocaleChange()
  self:populateModesScrollArea()
  self.widget.setButtonEnabled("btnClear", false)
  self:populateScrollArea("saSounds", self.soundList)
end

function modesounds:stopSounds()
  if self.modeSoundTable[self.selectedMode] then 
    pane.stopAllSounds(self.modeSoundTable[self.selectedMode])
  end
end

function modesounds:changeMode()
  self:stopSounds()

  self.widget.setVisible("saSounds", true)
  self.widget.setVisible("tbxFilter", true)

  self.selectedModeListItem = self.widget.getListSelected("saModes.listItems")
  if self.selectedModeListItem then
    self.selectedMode = self.widget.getData("saModes.listItems." .. self.selectedModeListItem)
  end

  self.widget.setVisible("btnClear", true)
  self.widget.setButtonEnabled("btnClear", false)
  
  -- Update selected sound without refilling the list
  local selectedSound = self.modeSoundTable[self.selectedMode]
  if selectedSound and self.soundListItems[selectedSound] then
    self.widget.setListSelected("saSounds.listItems", self.soundListItems[selectedSound])
    self.widget.setButtonEnabled("btnClear", true)
  else
    if widget.clearListSelected then
      self.widget.clearListSelected("saSounds.listItems")
    end
  end
end

function modesounds:populateScrollArea(scrollArea, items, selectedItem, callback, filter)
  self.widget.clearListItems(scrollArea .. ".listItems")

  for _, item in ipairs(items or {}) do
    if not filter or string.find(item.name, filter) then
      local li = self.widget.addListItem(scrollArea .. ".listItems")
      self.widget.setText(scrollArea .. ".listItems" .. "." .. li .. ".name", item.name)
      self.widget.setData(scrollArea .. ".listItems" .. "." .. li, item.data)
      
      -- Store li for sounds to avoid refilling the list later
      if scrollArea == "saSounds" then
        self.soundListItems[item.data] = li
      end
      
      if selectedItem and item.data == selectedItem then
        self.widget.setListSelected(scrollArea .. ".listItems", li)
        self.widget.setButtonEnabled("btnClear", true)
      end

      if callback then
        callback(item.name, item.data, li)
      end
    end
  end
end

function modesounds:searchSound()
  self:populateScrollArea("saSounds", self.soundList, self.modeSoundTable[self.selectedMode], nil, self.widget.getText("tbxFilter"))
end

function modesounds:setModeSound()
  self:stopSounds()
  local li = self.widget.getListSelected("saSounds.listItems")
  if li then
    local sound = self.widget.getData("saSounds.listItems." .. li).sound
    if sound then
      pane.playSound(sound)
      self.modeSoundTable[self.selectedMode] = sound
      self.widget.setButtonEnabled("btnClear", true)
      if self.selectedModeListItem then
        self.widget.setFontColor("saModes.listItems." .. self.selectedModeListItem .. ".name", "blue")
      end
    else
      self.modeSoundTable[self.selectedMode] = nil
      if self.selectedModeListItem then
        self.widget.setFontColor("saModes.listItems." .. self.selectedModeListItem .. ".name", "white")
      end
    end
  end
  root.setConfiguration("scc_mode_sounds", self.modeSoundTable)
  save()
end

function modesounds:clearModeSound()
  self:stopSounds()
  if self.selectedMode then
    self.widget.setButtonEnabled("btnClear", false)
    self.modeSoundTable[self.selectedMode] = nil
    if self.selectedModeListItem then
      self.widget.setFontColor("saModes.listItems." .. self.selectedModeListItem .. ".name", "white")
    end
    root.setConfiguration("scc_mode_sounds", self.modeSoundTable)
    save()
    self.widget.setListSelected("saSounds.listItems", 0)
  end
end

function modesounds:uninit()
  self:stopSounds()
end