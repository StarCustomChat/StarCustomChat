require "/interface/scripted/starcustomchat/plugin.lua"

charactervoice = PluginClass:new(
  { name = "charactervoice" }
)

function charactervoice:init(chat)
  PluginClass.init(self, chat)

  self.allRaceSounds = root.assetJson("/npcs/base.npctype")["scriptConfig"]["chatSounds"]
  self:resetSoundPool()
  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  self.soundPitch = player.getProperty("scc_sound_pitch") or 1
  self.soundVolume = player.getProperty("scc_sound_volume") or 1
  status.addPersistentEffect("scctalking", "scctalking")
end

function charactervoice:resetSoundPool()
  local selectedSpecies = player.getProperty("scc_sound_species") or player.species()
  if selectedSpecies == "custom" then
    local customSound = player.getProperty("scc_charactervoice_custom")
    if customSound then
      self.soundsPool = type(customSound) == "string" and {customSound} or customSound
    end
  else
    local currentRaceSounds = self.allRaceSounds[selectedSpecies] or self.allRaceSounds["human"]

    self.soundsPool = currentRaceSounds[player.gender()]
  end
end

function charactervoice:onSendMessage(message)
  if message.mode ~= "Whisper" or self.soundsWhispersEnabled then
    self:playSound()
  end
end

function charactervoice:playSound()
  if self.soundsEnabled then
    local soundTable = {
      pool = self.soundsPool,
      pitch = self.soundPitch,
      volume = self.soundVolume,
      cutoffTime = self.cutoffTime
    }
    world.sendEntityMessage(player.id(), "sccTalkingSound", soundTable)
    player.emote("blabbering")
  end
end

function charactervoice:onProcessCommand(text)
  if string.sub(text, 1, 3) == "/w " and self.soundsWhispersEnabled then
    self:playSound()
  end
end

function charactervoice:onSettingsUpdate()
  self.soundsEnabled = player.getProperty("scc_sounds_enabled") or false
  self.soundsWhispersEnabled = player.getProperty("scc_sounds_whisper_enabled") or false
  self.soundPitch = player.getProperty("scc_sound_pitch") or 1
  self.soundVolume = player.getProperty("scc_sound_volume") or 1
  self:resetSoundPool()
end

function charactervoice:uninit()
  status.clearPersistentEffects("scctalking")
end