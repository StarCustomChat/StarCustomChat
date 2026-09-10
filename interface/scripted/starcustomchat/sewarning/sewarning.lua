function init()
  self.reason = config.getParameter("reason")
  local locales = root.assetJson("/interface/scripted/starcustomchat/locales/locales.json")
  self.localeConfigs = {}
  for _, conf in ipairs(locales) do 
    self.localeConfigs[conf.code] = root.assetJson(string.format("/interface/scripted/starcustomchat/locales/%s.json", conf.code))
  end

  populateLanguagesList()
  setTexts()
end

function populateLanguagesList()
  widget.clearListItems("lytSelectLanguage.saLanguages.listLanguages")
  local selectedLocale = "en"

  for locale, localeConfig in pairs(self.localeConfigs) do 
    local flagImage = "/interface/scripted/starcustomchatsettings/images/flags/" .. locale .. ".png"
    local li = widget.addListItem("lytSelectLanguage.saLanguages.listLanguages")

    if li then
      widget.setImage("lytSelectLanguage.saLanguages.listLanguages." .. li .. ".language", flagImage)
      widget.setData("lytSelectLanguage.saLanguages.listLanguages." .. li .. ".language", {
        lang = locale,
        displayPlainText = localeConfig.name
      })
      widget.setData("lytSelectLanguage.saLanguages.listLanguages." .. li, {
        lang = locale,
        displayPlainText = localeConfig.name
      })

      if locale == selectedLocale then
        widget.setListSelected("lytSelectLanguage.saLanguages.listLanguages", li)
      end
    end
  end
end

function toggleLanguageSelection()
  widget.setVisible("lytSelectLanguage", not widget.active("lytSelectLanguage"))
end

function setLanguage()
  local li = widget.getListSelected("lytSelectLanguage.saLanguages.listLanguages")
  if li then
    local data = widget.getData("lytSelectLanguage.saLanguages.listLanguages." .. li)
    self.selectedLocale = data.lang
    setTexts()
    widget.setButtonImages("btnLanguage", {
      base = "/interface/scripted/starcustomchatsettings/images/flags/" .. data.lang .. ".png?border=1;000F",
      hover = "/interface/scripted/starcustomchatsettings/images/flags/" .. data.lang .. ".png?brightness=90?border=1;000F"
    })
    widget.setVisible("lytSelectLanguage", false)
  end
end

function setTexts()
  widget.setText("btnChangeLocale", self.localeConfigs[self.selectedLocale]["name"])
  widget.setText("close", self.localeConfigs[self.selectedLocale]["greeting.close"])
  widget.setText("text", self.localeConfigs[self.selectedLocale]["greeting." .. self.reason] or self.localeConfigs[self.selectedLocale]["greetings.unknown"])
end