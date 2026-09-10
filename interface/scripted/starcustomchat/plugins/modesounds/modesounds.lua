require "/interface/scripted/starcustomchat/plugin.lua"

modesounds = PluginClass:new(
  { name = "modesounds" }
)

function modesounds:init(chat)
  PluginClass.init(self, chat)

  self.modeSoundTable = root.getConfiguration("scc_mode_sounds") or {}
end

function modesounds:openSettings(settingsInterface)
  settingsInterface.chatModes = config.getParameter("chatModes", {})
end

function modesounds:onSettingsUpdate()
  self.modeSoundTable = root.getConfiguration("scc_mode_sounds") or {}
end

function modesounds:onReceiveMessage(message)
  if message.mode and self.modeSoundTable[message.mode] then
    local sound = self.modeSoundTable[message.mode]
    if sound and message.connection ~= starcustomchat.utils.entityIdToConnection(player.id()) then
      pane.playSound(sound)
      timers:add(self.cutoffTime, function()
        pane.stopAllSounds(sound)
      end)
    end
  end
  return message
end