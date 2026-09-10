require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

voicechat = SettingsPluginClass:new(
  { name = "voicechat" }
)


-- Settings
function voicechat:init()  
  self.enabled = root.getConfiguration("scc_voice_enabled") or false
  self.widget.setChecked("chkEnableDefault", self.enabled)
end

function voicechat:isAvailable()
  return not (root.assetOrigin and root.assetOrigin("/opensb/coconut.png") or xsb)
end

function voicechat:openVoiceSettings()
  chat.command("/voice")
end

function voicechat:binds()
  chat.command("/binds")
end

function voicechat:uninit()
  root.setConfiguration("scc_voice_enabled", voice.getSettings()["enabled"])
end