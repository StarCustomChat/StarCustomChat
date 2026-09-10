require "/interface/scripted/starcustomchat/plugin.lua"

stickers = PluginClass:new(
  { name = "stickers" }
)

function stickers:init(chat)
  PluginClass.init(self, chat)
  self.savedStickers = root.getConfiguration("scc_saved_stickers") or {}
    
  self.stagehandEnabled = false
end

function stickers:registerStagehandHandlers(handlers)
  self.stagehandEnabled = handlers and handlers["sendSticker"]
end

function stickers:onProcessCommand(text)
  local stripped = text:gsub("/", ""):gsub(" ", "")
  if stripped and stripped ~= "" and self.savedStickers[stripped] then

    local message = {
      image = self.savedStickers[stripped],
      mode = widget.getSelectedData("rgChatMode").mode,
      connection = starcustomchat.utils.entityIdToConnection(player.id()),
      nickname = player.name(),
      text = stripped
    }

    if message.mode == "Whisper" then
        local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
        if not li then 
          starcustomchat.utils.alert("chat.alerts.dm_not_found")
          return true
        end
  
        local data = widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
        if not world.entityExists(data.id) then starcustomchat.utils.alert("chat.alerts.dm_not_found") return end
        world.sendEntityMessage(data.id, "scc_add_message", message)
        world.sendEntityMessage(player.id(), "scc_add_message", message)
    elseif message.mode == "Party" then
      if self.stagehandEnabled and self.stagehandType and self.stagehandType ~= "" then
        starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "sendSticker", data = message, players = util.map(player.teamMembers(), function(p) return p.entity end)})
      else
        for _, pl in ipairs(player.teamMembers()) do 
          world.sendEntityMessage(pl.entity, "scc_add_message", message)
        end
      end
    else
      if self.stagehandEnabled and self.stagehandType and self.stagehandType ~= "" then
        starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "sendSticker", data = message})
      else
        for _, pl in ipairs(starcustomchat.utils.playersInRadius()) do 
          world.sendEntityMessage(pl, "scc_add_message", message)
        end
      end
    end
    return true
  end
  return false
end


function stickers:addCustomCommandPreview(availableCommands, substr)
  for name, _ in pairs(self.savedStickers) do 
    if string.find("/" .. name, substr, nil, true) then
      table.insert(availableCommands, {
        name = "/" .. name,
        color = "stickercommands",
        data = "/" .. name
      })
    end
  end
end


function stickers:onReceiveMessage(message)
  if message and (message.image and string.find(message.image, "^/%w+%.png"))
    or (message.text and string.find(message.text, "^/%w+%.png")) then

    local imageSize = starcustomchat.utils.safeImageSize(message.image or message.text)
    if imageSize then
      if imageSize[1] > self.maxSize[1] or imageSize[2] > self.maxSize[2] then
        starcustomchat.utils.alert("settings.mainchat.alerts.size_error")
      else
        message.image = message.image or message.text
        message.imageSize = imageSize
      end
    end
  end
end

function stickers:onCreateTooltip(screenPosition)
  local selectedMessage = self.customChat:selectMessage(screenPosition)
  if selectedMessage and selectedMessage.image then
    return starcustomchat.utils.getTranslation("stickers.name_preview", selectedMessage.text)
  end
end

function stickers:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  if selectedMessage and buttonName == "save_sticker" then
    return selectedMessage.image and not self.savedStickers[selectedMessage.text]
  end
end

function stickers:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage and buttonName == "save_sticker" and selectedMessage.image then
    local name = selectedMessage.text
    if name then
      if self.savedStickers[name] then
        starcustomchat.utils.alert("settings.plugins.stickers.alerts.already_exists")
        return
      else
        starcustomchat.utils.alert("chat.commands.alerts.saved", name)
        self.savedStickers[name] = selectedMessage.image
        root.setConfiguration("scc_saved_stickers", self.savedStickers)
      end
    end
  end
end

function stickers:onSettingsUpdate()
  self.savedStickers = root.getConfiguration("scc_saved_stickers") or {}
end