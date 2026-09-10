require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

charactervoice = SettingsPluginClass:new(
  { name = "charactervoice" }
)


-- Settings
function charactervoice:init()
  self.selectedSpecies = player.getProperty("scc_sound_species") or player.species()
  self.allRaceSounds = root.assetJson("/npcs/base.npctype")["scriptConfig"]["chatSounds"]

  -- Quick migration of the custom sounds
  local customSoundTable = player.getProperty("scc_charactervoice_custom")
  if customSoundTable and type(customSoundTable) == "string" then
    customSoundTable = {customSoundTable}
  elseif customSoundTable and type(customSoundTable) == "table" then
    local normalizedSoundTable = {}
    for i = 1, 3 do
      normalizedSoundTable[i] = customSoundTable[i] or customSoundTable[tostring(i)]
    end
    customSoundTable = normalizedSoundTable
  end

  self.customSoundsTable = customSoundTable or {}
  player.setProperty("scc_charactervoice_custom", util.values(self.customSoundsTable))

  if self.selectedSpecies ~= "custom" then
    self.selectedSpecies = self.allRaceSounds[self.selectedSpecies] and self.selectedSpecies or "human"

    self.soundsPool = self.allRaceSounds[self.selectedSpecies][player.gender()] 
  else
    self.soundsPool = customSoundTable or self.allRaceSounds["human"][player.gender()]
  end


  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  self.widget.setChecked("chkEnabled", self.soundsEnabled or false)

  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  self.widget.setChecked("chkEnabledWhisper", self.soundsWhispersEnabled or false)

  self.soundPitch = (player.getProperty("scc_sound_pitch") or 1)
  self.widget.setSliderRange("sldSoundPitch", 0, 20, 2)
  self.widget.setSliderValue("sldSoundPitch", self.soundPitch * 10)
  
  self.soundVolume = (player.getProperty("scc_sound_volume") or 1)
  self.widget.setSliderRange("sldVolumePitch", 0, 14, 2)
  self.widget.setSliderValue("sldVolumePitch", self.soundVolume * 10)
end

function charactervoice:openTab()
  local rawSoundList = root.assetsByExtension(".ogg")
  local soundList = {}
  
  -- Transform sound list to use combobox object format
  for _, soundPath in ipairs(rawSoundList) do
    local fileName = soundPath:match("([^/]+)$")
    soundList[soundPath] = {
      name = fileName,
      data = {displayPlainText = soundPath}
    }
  end

  self.comboboxes = {}
  for i = 1, 3 do 
    local ind = tostring(i)
    self.comboboxes["btnCustomSound" .. ind] = self:createCombobox(soundList, ind)

    local sound = self.customSoundsTable[i] or ""
    self.widget.setText("btnCustomSound" .. ind, sound:match("([^/]+)$") or "")
    self.widget.setButtonEnabled("btnRemove" .. ind, sound and sound ~= "")
  end
  
  self:populateScrollArea(self.allRaceSounds, self.selectedSpecies)
end

function charactervoice:createCombobox(soundList, ind)
  return Combobox:bind(self.layoutWidget .. "." .. "btnCustomSound" .. ind, soundList, function(sound, data)
    self:saveCustomSound(sound, data, ind)
  end, {
    filter = true,
    background = "/interface/scripted/starcustomchatsettings/images/combobox/large/backgroundFilter.png",
    listSchema = {
      listSelected = "/interface/scripted/starcustomchatsettings/images/combobox/large/listselected.png",
      listUnselected = "/interface/scripted/starcustomchatsettings/images/combobox/large/listunselected.png"
    },
    offset = {-50, 15},
    closeOnSelect = true,
    sortKeys = true
  })
end

function charactervoice:toggleCombobox(btnName)
  self.comboboxes[btnName]:toggle()
end

function charactervoice:populateScrollArea(allRaceSounds, selectedSpecies)
  self.widget.clearListItems("saSpecies.listItems")

  for speciesName, _ in pairs(allRaceSounds) do
    local li = self.widget.addListItem("saSpecies.listItems")
    self.widget.setText("saSpecies.listItems." .. li .. ".name", speciesName)
    self.widget.setData("saSpecies.listItems." .. li, speciesName)
    if speciesName == selectedSpecies then
      self.widget.setListSelected("saSpecies.listItems", li)
    end
  end

-- Add custom option
  local li = self.widget.addListItem("saSpecies.listItems")
  self.widget.setText("saSpecies.listItems." .. li .. ".name", starcustomchat.utils.getTranslation("settings.plugins.charactervoice.customItem"))
  self.widget.setData("saSpecies.listItems." .. li, "custom")
  if selectedSpecies == "custom" then
    self.widget.setListSelected("saSpecies.listItems", li)
  end
end

function charactervoice:changeSpecies()
  local li = self.widget.getListSelected("saSpecies.listItems") 
  if li then
    local newSpecies = self.widget.getData("saSpecies.listItems." .. li)
    player.setProperty("scc_sound_species", newSpecies)

    for i = 1, 3 do 
      self.widget.setVisible("btnCustomSound" .. i, newSpecies == "custom")
      self.widget.setVisible("btnRemove" .. i, newSpecies == "custom")
    end

    self.soundsPool = newSpecies == "custom" and util.values(self.customSoundsTable) or self.allRaceSounds[newSpecies][player.gender()]
    save()
  end
end

function charactervoice:removeSound(btnName)
  local ind = tonumber(btnName:sub(-1))
  self.widget.setText("btnCustomSound" .. ind, "")
  self.customSoundsTable[ind] = nil
  player.setProperty("scc_charactervoice_custom", util.values(self.customSoundsTable))
  self.widget.setButtonEnabled("btnRemove" .. ind, false)
  save()
end

function charactervoice:saveCustomSound(sound, data, ind)
  ind = tonumber(ind)
  local customSound = data.displayPlainText or sound

  if customSound and customSound ~= "" then
    self.widget.setText("btnCustomSound" .. ind, customSound:match("([^/]+)$"))
    if root.assetOrigin(customSound) then
      self.customSoundsTable[ind] = customSound
      self.soundsPool = {customSound}
      self:playSound()
      self.soundsPool = util.values(self.customSoundsTable)
      player.setProperty("scc_charactervoice_custom", util.values(self.customSoundsTable))
      self.widget.setButtonEnabled("btnRemove" .. ind, true)
      save()
    else
      starcustomchat.utils.alert("settings.plugins.charactervoice.soundNotFound")
    end
  end
end

function charactervoice:enableCharacterVoice()
  self.soundsEnabled = self.widget.getChecked("chkEnabled")
  player.setProperty("scc_sounds_enabled", self.soundsEnabled)
  save()
end

function charactervoice:enableWhisperSounds()
  self.soundsWhispersEnabled = self.widget.getChecked("chkEnabledWhisper")
  player.setProperty("scc_sounds_whisper_enabled", self.soundsWhispersEnabled)
  save()
end

function charactervoice:playSound()
  local soundTable = {
    pool = self.soundsPool,
    pitch = self.soundPitch,
    volume = self.soundVolume,
    cutoffTime = self.cutoffTime
  }

  world.sendEntityMessage(player.id(), "sccTalkingSound", soundTable)
end

function charactervoice:setTalkingPitch()
  self.soundPitch = math.max(self.widget.getSliderValue("sldSoundPitch") / 10, 0.4)
  self.widget.setSliderValue("sldSoundPitch", self.soundPitch * 10)
  player.setProperty("scc_sound_pitch", self.soundPitch)
  save()
end

function charactervoice:setTalkingVolume()
  self.soundVolume = math.max(self.widget.getSliderValue("sldVolumePitch") / 10, 0.1)
  self.widget.setSliderValue("sldVolumePitch", self.soundVolume * 10)
  player.setProperty("scc_sound_volume", self.soundVolume)
  save()
end

function charactervoice:uninit()
  if self.comboboxes then
    for _, cmbx in pairs(self.comboboxes) do 
      if cmbx then
        cmbx:destroy()
      end
    end
  end

  for i, v in ipairs(self.soundsPool) do
    pane.stopAllSounds(v)
  end
end