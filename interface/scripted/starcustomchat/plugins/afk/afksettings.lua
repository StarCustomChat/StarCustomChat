require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

afk = SettingsPluginClass:new(
  { name = "afk" }
)


-- Settings
function afk:init()

  self.settingsTimer = root.getConfiguration("scc_afk_timer") or 0
  self.widget.setText("lblAfkTimer", self.settingsTimer)
  self.widget.setData("lblAfkTimer", self.settingsTimer)

  self.widget.setChecked("btnDisableAfkButton", root.getConfiguration("scc_afk_button_disabled"))
  self.widget.setChecked("btnIgnoreMouse", root.getConfiguration("scc_afk_ignore_mouse"))

  local effect = root.getConfiguration("scc_afk_effect") or "starchatafk"

  for _, btn in ipairs(config.getParameter("gui")["lytPluginSettings"].children[self.name].children["rgAfkModes"].buttons) do
    if btn.data.effect == effect then
      self.widget.setSelectedOption("rgAfkModes", btn.id)
      return
    end
  end
end

afk.afkTimerSpinner = {}

function afk.afkTimerSpinner.up(self)
  local mins = tonumber(self.widget.getData("lblAfkTimer")) or 0
  mins = math.min(mins + 1, 5)
  self.widget.setText("lblAfkTimer", mins)
  self.widget.setData("lblAfkTimer", mins)
  root.setConfiguration("scc_afk_timer", tonumber(self.widget.getData("lblAfkTimer")) or 0)
  save()
end

function afk.afkTimerSpinner.down(self)
  local mins = tonumber(self.widget.getData("lblAfkTimer")) or 0
  mins = math.max(mins - 1, 0)
  self.widget.setText("lblAfkTimer", mins)
  self.widget.setData("lblAfkTimer", mins)
  root.setConfiguration("scc_afk_timer", tonumber(self.widget.getData("lblAfkTimer")) or 0)
  save()
end

function afk:disableAFKButton()
  root.setConfiguration("scc_afk_button_disabled", self.widget.getChecked("btnDisableAfkButton"))
  save()
end

function afk:toggleIgnoreMouse()
  root.setConfiguration("scc_afk_ignore_mouse", self.widget.getChecked("btnIgnoreMouse"))
  save()
end

function afk:selectAfkMode()
  local mode = self.widget.getSelectedData("rgAfkModes").effect
  root.setConfiguration("scc_afk_effect", mode)
  save()
end