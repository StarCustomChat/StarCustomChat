DMTab = {}
DMTab.__index = DMTab

function DMTab:new(customChat)
  widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")
  return setmetatable({
    contacts = {},
    DMTimer = 2,
    ignoreSettingList = nil,
    customChat = customChat or {}
  }, self)
end

function DMTab:checkDMs(dmingTo)
  if widget.getSelectedData("rgChatMode").mode == "Whisper" then
    self:populateList(dmingTo)
  else
    self.contacts = {}
    widget.clearListItems("lytCharactersToDM.saPlayers.lytPlayers")
  end
  ICChatTimer:add(self.DMTimer, function() self:checkDMs() end)
end

function DMTab:populateList(dmingTo)
  local function drawCharacters(players, toRemovePlayers)
    local mode =  "avatar" -- #players > 7 and "letter" or "avatar"

    local idTable = {}  -- This table will store only the 'id' values

    if #player.teamMembers() ~= 0 then
      table.insert(idTable, "PARTY")
    end

    -- Add the party button
    if #player.teamMembers() ~= 0 then
      if index(self.contacts, "PARTY") == 0 then
        local li = widget.addListItem("lytCharactersToDM.saPlayers.lytPlayers")
        self:drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", self.customChat.config.dmListPartyIcon)
        widget.setData("lytCharactersToDM.saPlayers.lytPlayers." .. li, {
          displayText = "chat.modes.Party",
          id = "PARTY"
        })

        table.insert(self.contacts, "PARTY")

        if dmingTo == "PARTY" then
          self.ignoreSettingList = true
          widget.setListSelected("lytCharactersToDM.saPlayers.lytPlayers", li)
        end
      end
    end

    for _, player in ipairs(players) do
      table.insert(idTable, player.id)

      if index(self.contacts, player.id) == 0 and player.data then
        local li = widget.addListItem("lytCharactersToDM.saPlayers.lytPlayers")
        if mode == "letter" or not player.data.portrait then
          local trimmedName = starcustomchat.utils.utf8Substring(starcustomchat.utils.clearNick(player.name), 1, 2)
          trimmedName = utf8.len(trimmedName) == 1 and trimmedName .. " " or (utf8.len(trimmedName) == 0 and "  ") or trimmedName
          self:drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", trimmedName)
        elseif player.data.portrait then
          self:drawIcon("lytCharactersToDM.saPlayers.lytPlayers." .. li .. ".contactAvatar", player.data.portrait)
        end

        widget.setData("lytCharactersToDM.saPlayers.lytPlayers." .. li, {
          id = player.id,
          displayPlainText = player.name
        })

        table.insert(self.contacts, player.id)

        if dmingTo and dmingTo == player.id then
          self.ignoreSettingList = true
          widget.setListSelected("lytCharactersToDM.saPlayers.lytPlayers", li)
        end
      end
    end


    if toRemovePlayers then
      for i, id in ipairs(self.contacts) do
        if index(idTable, id) == 0 then
          self.ignoreSettingList = true
          widget.removeListItem("lytCharactersToDM.saPlayers.lytPlayers", i - 1)
          table.remove(self.contacts, i)
        end
      end
    end
  end

  local playersAround = {}

  if player.id() and world.entityPosition(player.id()) then
    for _, player in ipairs(starcustomchat.utils.playersInRadius(40)) do
      table.insert(playersAround, {
        id = player,
        name = self.customChat.callbackPlugins("resolvePlayerData", {
          name = world.entityName(player),
          entityId = player,
          uuid = world.entityUniqueId(player)
        }).name or "Unknown",
        data = {
          portrait = world.entityPortrait(player, "full")
        }
      })
    end
  end

  drawCharacters(playersAround, true)
end

function DMTab:selectPlayer(...)
  if not self.ignoreSettingList then
    self.customChat:focusInput()
  end

  self.ignoreSettingList = nil
end

function DMTab:drawIcon(canvasName, args)
	local playerCanvas = widget.bindCanvas(canvasName)
  playerCanvas:clear()

  if type(args) == "number" then
    local playerPortrait = world.entityPortrait(args, "full")
    for _, layer in ipairs(playerPortrait) do
      playerCanvas:drawImage(layer.image, {7, 2}, 1, nil, true)
    end
  elseif type(args) == "table" then
    for _, layer in ipairs(args) do
      local size = starcustomchat.utils.safeImageSize(layer.image)
      playerCanvas:drawImage(layer.image, {7, 2}, 1, nil, true)
    end
  elseif type(args) == "string" and utf8.len(args) == 2 then
    playerCanvas:drawText(args, {
      position = {8, 3},
      horizontalAnchor = "mid", -- left, mid, right
      verticalAnchor = "bottom", -- top, mid, bottom
      wrapWidth = nil -- wrap width in pixels or nil
    }, self.customChat.config.fontSize + 1)
  elseif type(args) == "string" then
    playerCanvas:drawImage(args, {-1, 0})
  end
end


function DMTab:selectedPlayer()
  local li = widget.getListSelected("lytCharactersToDM.saPlayers.lytPlayers")
  if li then
    return widget.getData("lytCharactersToDM.saPlayers.lytPlayers." .. li)
  end
end