require "/interface/scripted/starcustomchat/plugin.lua"

voicechat = PluginClass:new(
  { name = "voicechat" }
)

function voicechat:init()
  local isEnabled = voice.getSettings()["enabled"]
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
    self:setEnabled(isChecked)
  end
end