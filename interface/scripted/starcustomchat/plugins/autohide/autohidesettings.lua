require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

autohide = SettingsPluginClass:new(
  { name = "autohide" }
)


-- Settings
function autohide:init()

  self.autohideTimer = root.getConfiguration("scc_autohide_timer") or 0
  self.widget.setText("lblAutohideTimer", self.autohideTimer)
  self.widget.setData("lblAutohideTimer", self.autohideTimer)

  self.widget.setData("autohideTimerSpinner.up", self.widget.getData("autohideTimerSpinner"))
  self.widget.setData("autohideTimerSpinner.down", self.widget.getData("autohideTimerSpinner"))
  self.widget.setChecked("chkIgnoreServerMessages", root.getConfiguration("scc_autohide_ignore_server_messages") or false)
  self.widget.setChecked("chkIgnoreInspectMessages", root.getConfiguration("scc_autohide_ignore_inspect_messages") or false)
end

autohide.autohideTimerSpinner = {}

function autohide.autohideTimerSpinner.up(self)
  local secs = tonumber(self.widget.getData("lblAutohideTimer")) or 0
  secs = math.min(secs + 5, 90)
  self.widget.setText("lblAutohideTimer", secs)
  self.widget.setData("lblAutohideTimer", secs)
  root.setConfiguration("scc_autohide_timer", tonumber(self.widget.getData("lblAutohideTimer")) or 0)
  save()
end

function autohide.autohideTimerSpinner.down(self)
  local secs = tonumber(self.widget.getData("lblAutohideTimer")) or 0
  secs = math.max(secs - 5, 0)
  self.widget.setText("lblAutohideTimer", secs)
  self.widget.setData("lblAutohideTimer", secs)
  root.setConfiguration("scc_autohide_timer", tonumber(self.widget.getData("lblAutohideTimer")) or 0)
  save()
end

function autohide:setIgnoreMessages()
  root.setConfiguration("scc_autohide_ignore_server_messages", self.widget.getChecked("chkIgnoreServerMessages"))
  root.setConfiguration("scc_autohide_ignore_inspect_messages", self.widget.getChecked("chkIgnoreInspectMessages"))
  save()
end