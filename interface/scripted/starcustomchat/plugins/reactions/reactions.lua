require "/interface/scripted/starcustomchat/plugin.lua"
require "/scripts/rect.lua"

reactions = PluginClass:new(
  { name = "reactions" }
)

function reactions:init(chat)
  PluginClass.init(self, chat)

  self.stagehandEnabled = false
end

function reactions:registerStagehandHandlers(handlers)
  self.stagehandEnabled = handlers and handlers["addReaction"]
end

function reactions:contextMenuButtonFilter(buttonName, screenPosition, selectedMessage)
  if selectedMessage and buttonName == "add_reacton" then
    return selectedMessage.mode ~= "CommandResult"
  end
end

function reactions:registerMessageHandlers()
  starcustomchat.utils.setMessageHandler( "scc_add_reaction", function(_, _, data)
    local msgInd = self.customChat:findMessageByUUID(data.uuid)
    local reaction = data.reaction

    if not data.source and data.nickname then
      -- Old message, too bad
      data.source = {
        name = data.nickname,
        uuid = data.nickname
      }
    end

    if msgInd and data.source then
      -- Obfuscate the name if needed
      data.source.name = self.customChat.callbackPlugins("resolvePlayerData", data.source).name

      local message = self.customChat.messages[msgInd]
      message.reactions = message.reactions or {}

      for rInd, reactObj in ipairs(message.reactions) do
        if reactObj.reaction == reaction then
          reactObj.sources = reactObj.sources or {}

          local ind = 0
          -- Find if this react already has this source
          for sId, source in ipairs(reactObj.sources) do 
            if source.uuid == data.source.uuid then
              ind = sId
              break
            end
          end


          if ind ~= 0 then
            table.remove(message.reactions[rInd].sources, ind)
            if #message.reactions[rInd].sources == 0 then
              table.remove(message.reactions, rInd)
            end
          else
            data.source.name = self.customChat.callbackPlugins("resolvePlayerData", data.source).name
            table.insert(message.reactions[rInd].sources, data.source)
          end

          self.customChat:processQueue()
          return
        end
      end

      -- If it's a first reaction
      table.insert(message.reactions, {
        reaction = reaction,
        sources = {data.source}
      })
      self.customChat:processQueue()
    end
  end)
end

function reactions:contextMenuButtonClick(buttonName, selectedMessage)
  if selectedMessage and selectedMessage.uuid and buttonName == "add_reacton" then
    local selectEmojiPane = root.assetJson("/interface/scripted/starcustomchat/plugins/reactions/reactionselect/reactionselect.json")
    selectEmojiPane.messageUUID = selectedMessage.uuid
    selectEmojiPane.text = selectedMessage.text
    selectEmojiPane.nickname = selectedMessage.nickname
    selectEmojiPane.stagehandType = self.stagehandEnabled and self.stagehandType
    selectEmojiPane.textboxHint = starcustomchat.utils.getTranslation("settings.search")
    selectEmojiPane.allLabel = starcustomchat.utils.getTranslation("reactions.reactselect.all")
    selectEmojiPane.recentLabel = starcustomchat.utils.getTranslation("reactions.reactselect.recent")

    player.interact("ScriptPane", selectEmojiPane)
  end
end

function reactions:onMeasureMessage(message, drawData)
  if not message.reactions or not next(message.reactions) then
    return
  end

  for _, reactObj in ipairs(message.reactions) do
    -- Reactions from the old protocol do not contain their sources and cannot
    -- be displayed or interacted with.
    if not reactObj.sources then
      break
    end

    local reactionOffset = self.customChat.config.emotePanelHeight * self.customChat.config.fontSize / 10
    drawData.reactionOffset = reactionOffset
    drawData.bodyOffset = drawData.bodyOffset + reactionOffset
    drawData.bodyHeight = drawData.bodyHeight + reactionOffset
    drawData.height = drawData.height + reactionOffset
    return
  end

  message.reactions = nil
end

function reactions:onDrawMessage(message, drawData)
  if not drawData.reactionOffset then
    return
  end

  local chat = self.customChat
  local size = portraitSizeFromBaseFont(chat.config.fontSize)
  local xOffset = chat.chatMode == "modern" and chat.config.nameOffset[1] + size or chat.config.textOffsetCompactMode[1]
  local emojiStartOffset = vec2.add({xOffset, drawData.messageOffset}, chat.config.emotesOffset)

  for ind, reactObj in ipairs(message.reactions) do
    local reaction = reactObj.reaction

    if not reactObj.sources then
      break
    end

    if not root.assetOrigin(string.format("/emotes/%s.emote.png", reaction)) then
      reaction = "unknown"
      message.reactions[ind].reaction = "unknown"
    end

    chat.canvas:drawImage(string.format("/emotes/%s.emote.png", reaction),
      emojiStartOffset, 1 / 16 * chat.config.fontSize)

    local haveIReacted = false
    for _, source in ipairs(reactObj.sources) do
      if source.uuid == player.uniqueId() then
        haveIReacted = true
        break
      end
    end

    chat.canvas:drawText(#reactObj.sources, {
      position = vec2.add(emojiStartOffset, {chat.config.emoteNumberSpace * chat.config.fontSize / 10, 0}),
      horizontalAnchor = "left",
      verticalAnchor = "bottom",
      wrapWidth = chat.config.wrapWidthFullMode
    }, chat.config.fontSize - 1, haveIReacted and "cornflowerblue" or chat:getColor("chattext"))

    message.reactions[ind].position = copy(emojiStartOffset)
    emojiStartOffset[1] = emojiStartOffset[1] + chat.config.emoteSpacing * chat.config.fontSize / 10
  end
end

function reactions:onCreateTooltip(screenPosition)
  local selectedMessage = self.customChat:selectMessage(screenPosition)
  if selectedMessage and selectedMessage.reactions then

    for _, reactObj in ipairs (selectedMessage.reactions) do 
      if rect.contains(rect.withSize(reactObj.position, {16, 16}), self.customChat.topCanvas:mousePosition()) then
        local text = ":^yellow;" .. reactObj.reaction .. "^reset;: " 
        for i, source in ipairs(reactObj.sources) do
            text = text .. source.name
            if i < #reactObj.sources then
                text = text .. ", "
            end
        end
        return text
        
      end
    end
  end
end

function reactions:onCanvasClick(screenPosition, button, isButtonDown)
  if button == 0 and isButtonDown then
    local selectedMessage = self.customChat:selectMessage(screenPosition, true)
    if selectedMessage and selectedMessage.reactions then
      
      for _, reactObj in ipairs (selectedMessage.reactions) do 
        if rect.contains(rect.withSize(reactObj.position, {16, 16}), screenPosition) then
          local data = {
            reaction = reactObj.reaction,
            uuid = selectedMessage.uuid,
            source = {
              name = player.name(),
              uuid = player.uniqueId()
            }
          }
      
          if self.stagehandEnabled and self.stagehandType and self.stagehandType ~= "" then
            starcustomchat.utils.createStagehandWithData(self.stagehandType, {message = "addReaction", data = data})
          else
            for _, pl in ipairs(starcustomchat.utils.playersInRadius()) do 
              world.sendEntityMessage(pl, "scc_add_reaction", data)
            end
          end
          return true
        end
      end
    end
  end
end
