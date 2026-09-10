require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

typing = SettingsPluginClass:new(
  { name = "typing" }
)


-- Settings
function typing:init()
  self.portraitDots = root.getConfiguration("scc_typing_portrait")
  if self.portraitDots == nil then
    self.portraitDots = true
  end

  self.statusField = root.getConfiguration("scc_typing_status")
  if self.statusField == nil then
    self.statusField = true
  end
end

function typing:openTab()
    self.widget.setChecked("chkPlayerPortraits", self.portraitDots)
    self.widget.setChecked("chkTypingStatus", self.statusField)
end

function typing:setStatusEnabled()
  self.statusField = self.widget.getChecked("chkTypingStatus")
  root.setConfiguration("scc_typing_status", self.statusField)
  save()
end

function typing:setPortraitDotsEnabled()
  self.portraitDots = self.widget.getChecked("chkPlayerPortraits")
  root.setConfiguration("scc_typing_portrait", self.portraitDots)
  save()
end