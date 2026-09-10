CommandPreview = {}
CommandPreview.__index = CommandPreview

function CommandPreview:new(customChat, availableCommands)
  return setmetatable({
    customChat = customChat,
    availableCommands = availableCommands,
    entries = {},
    selected = 0,
    pingUsersAround = nil
  }, self)
end

function CommandPreview:add(newCommands)
  self.availableCommands = sb.jsonMerge(self.availableCommands, newCommands)
end

function CommandPreview:getDisplayText(entry)
  if type(entry) == "table" then
    return entry.name or entry.displayName or entry.data or entry.command or ""
  end

  return entry or ""
end

function CommandPreview:getInsertionText(entry)
  if type(entry) == "table" then
    if entry.entityId then
      return entry.displayName or entry.command or ""
    end
    return entry.command or entry.name or entry.data or entry.displayName or ""
  end

  return entry or ""
end

function CommandPreview:clear()
  self.entries = {}
  self.selected = 0
  widget.setVisible("lytCommandPreview", false)
  widget.setText("lblCommandPreview", "")
  widget.setData("lblCommandPreview", nil)
end

function CommandPreview:getPingPlayers()
  if not self.pingUsersAround then
    self.pingUsersAround = {}
    for _, entityId in ipairs(starcustomchat.utils.playersInRadius(nil, true, true)) do
      local playerData = {
        name = world.entityName(entityId),
        entityId = entityId,
        uuid = world.entityUniqueId(entityId)
      }
      local resolvedPlayerData = self.customChat.callbackPlugins("resolvePlayerData", playerData)
      local resolvedName = resolvedPlayerData and resolvedPlayerData.name or playerData.name or "Unknown"

      table.insert(self.pingUsersAround, {
        command = "@" .. playerData.name,
        displayName = "@" .. resolvedName,
        description = "chat.alerts.ping_user",
        entityId = entityId
      })
    end
  end

  return self.pingUsersAround
end

function CommandPreview:getEntries(text)
  if utf8.len(text) > 2 and string.sub(text, 1, 1) == "/" then
    self.pingUsersAround = nil
    return starcustomchat.utils.getCommands(self.availableCommands, text)
  elseif utf8.len(text) >= 1 and string.sub(text, 1, 1) == "@" then
    local entries = {}
    for _, entry in ipairs(self:getPingPlayers()) do
      if string.find(entry.command, text, 1, true) or string.find(entry.displayName, text, 1, true) then
        table.insert(entries, entry)
      end
    end
    return entries
  end

  self.pingUsersAround = nil
end

function CommandPreview:update(text)
  local entries = self:getEntries(text)
  if not entries or #entries == 0 then
    self:clear()
    return
  end

  self.entries = entries
  self.selected = math.max(self.selected % (#entries + 1), 1)
  local selectedEntry = entries[self.selected]

  widget.setVisible("lytCommandPreview", true)
  widget.setText("lblCommandPreview", self:getDisplayText(selectedEntry))
  widget.setData("lblCommandPreview", self:getInsertionText(selectedEntry))
  self.customChat:drawCommandPreview(entries, self.selected)
end

function CommandPreview:advanceSelection()
  self.selected = self.selected + 1
end

function CommandPreview:getSelectedInsertion(text)
  if widget.getData("lblCommandPreview") and widget.getData("lblCommandPreview") ~= "" and widget.getData("lblCommandPreview") ~= text then
    return widget.getData("lblCommandPreview")
  end
end

function CommandPreview:getPingTarget(text)
  for _, entry in ipairs(self:getPingPlayers()) do
    if entry.entityId and (entry.command == text or entry.displayName == text) then
      return entry.entityId, string.sub(entry.displayName or entry.command or "", 2)
    end
  end
end

function CommandPreview:reset()
  self.entries = {}
  self.selected = 0
  self.pingUsersAround = nil
end
