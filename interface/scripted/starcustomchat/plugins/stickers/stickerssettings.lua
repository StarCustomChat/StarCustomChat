require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

stickers = SettingsPluginClass:new(
  { name = "stickers" }
)


-- Settings
function stickers:init()
  self.savedStickers = root.getConfiguration("scc_saved_stickers") or {}
end

function stickers:openTab()
  self.stickerIndexes = {}

  self.widget.registerMemberCallback("saSavedStickers.listStickers", "removeSticker", function(_, data)
    self:removeSticker(_, data)
  end)

  self:populateList()
end

function stickers:populateList(search)
  self.widget.clearListItems("saSavedStickers.listStickers") 
  self.stickerIndexes = {}
  for name, image in pairs(self.savedStickers) do 
    if not search or string.find(name, search, nil, true) then
      self:addStickerToList(name, image)
    end
  end
end

function stickers:addStickerToList(name, image)
  local li = self.widget.addListItem("saSavedStickers.listStickers")
  table.insert(self.stickerIndexes, li)
  self.widget.setImage("saSavedStickers.listStickers." .. li .. ".sticker", image)
  self.widget.setText("saSavedStickers.listStickers." .. li .. ".name", name)
  self.widget.setData("saSavedStickers.listStickers." .. li, {
    name = name,
    image = image
  })
end

function stickers:addSticker()
  local directives = self.widget.getText("tbxStickerDirectives")
  local name = self.widget.getText("tbxStickerName")
  if not directives or directives == "" or not name or name == "" then
    starcustomchat.utils.alert("settings.plugins.stickers.alerts.name_error")
    return
  end

  if self.savedStickers[name] then
    starcustomchat.utils.alert("settings.plugins.stickers.alerts.already_exists")
    return
  end

  local newImage = "/assetmissing.png" .. directives

  local imageSize = starcustomchat.utils.safeImageSize(newImage)
  if imageSize then
    if imageSize[1] > self.maxSize[1] or imageSize[2] > self.maxSize[2] then
      starcustomchat.utils.alert("settings.plugins.stickers.alerts.size_error", self.maxSize[1], self.maxSize[2])
      self.widget.setText("tbxStickerDirectives", "")
      return
    end

    self.savedStickers[name] = newImage
    self:addStickerToList(name, newImage)
    self.widget.setText("tbxStickerDirectives", "")
    self.widget.setText("tbxStickerName", "")
    save()
  else
    starcustomchat.utils.alert("settings.plugins.stickers.alerts.image_error")
    self.widget.setText("tbxStickerDirectives", "")
  end
end

function stickers:searchSticker()
  local text = self.widget.getText("tbxStickerSearch")
  self:populateList(text)
end

function stickers:removeSticker()

  local li = self.widget.getListSelected("saSavedStickers.listStickers")
  if li then
    local data = self.widget.getData("saSavedStickers.listStickers." .. li)

    local dialogConfig = {
      paneLayout = "/interface/windowconfig/simpleconfirmation.config:paneLayout",
      icon = self.savedStickers[data.name] or "/assetmissing.png",
      title = starcustomchat.utils.getTranslation("settings.plugins.stickers.dialogs.remove.title"),
      subtitle = starcustomchat.utils.getTranslation("settings.plugins.stickers.dialogs.remove.subtitle"),
      message = starcustomchat.utils.getTranslation("settings.plugins.stickers.dialogs.remove.message", data.name),
      okCaption = starcustomchat.utils.getTranslation("settings.plugins.stickers.dialogs.remove.ok"),
      cancelCaption = starcustomchat.utils.getTranslation("settings.plugins.stickers.dialogs.remove.cancel")
    }

    promises:add(player.confirm(dialogConfig), function(confirmed)
      if confirmed then
        local ind = index(self.stickerIndexes, li)
        if ind then
          self.widget.removeListItem("saSavedStickers.listStickers", ind - 1)
          self.savedStickers[data.name] = nil
          table.remove(self.stickerIndexes, ind)
          save()
        end
      end
    end)
  end
end

function stickers:onStickerSelected()
  local li = self.widget.getListSelected("saSavedStickers.listStickers")
  if li then
    --pass
  end
end

function stickers:uninit()
  root.setConfiguration("scc_saved_stickers", self.savedStickers)
end