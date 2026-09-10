require "/interface/scripted/starcustomchat/plugin.lua"

voicechat = PluginClass:new(
  { name = "voicechat" }
)

function voicechat:init()
  local isEnabled = root.getConfiguration("scc_voice_enabled") or false
  widget.setChecked("lytModeFilter.btnCkVoice", isEnabled)

  self:setEnabled(isEnabled)
end

function voicechat:setEnabled(enabled)
  -- Avoid audio stutters by checking and setting voice settings efficiently
  local voiceSettings = voice.getSettings()
  voiceSettings["enabled"] = enabled
  voice.mergeSettings(voiceSettings)
end


function voicechat:onModeToggle(button, isChecked)
  if button == "btnCkVoice" then
    root.setConfiguration("scc_voice_enabled", isChecked)
    self:setEnabled(isChecked)
  end
end