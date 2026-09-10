require "/interface/scripted/starcustomchat/base/starcustomchatutils.lua"
require "/scripts/util.lua"

function init()
  self.maxLength = 50

  self.emojiList = root.assetJson("/interface/scripted/starcustomchat/plugins/reactions/reactionlist.json")
  self.stagehandType = config.getParameter("stagehandType")

  self.recentReactions = root.getConfiguration("scc_most_recent_reactions") or {}
  clearRecentReactions()

  if not next(self.recentReactions) then
    widget.removeChild("sa_All", "listRecent")
    widget.removeChild("sa_All", "lbl_Recent")
  else
    widget.setText("sa_All.lbl_Recent", config.getParameter("recentLabel"))
    populateReacts(nil, "sa_All.listRecent", touchRecentReaction(self.recentReactions, nil, 10).items)
  end

  populateReacts(nil, "sa_All.listAll", self.emojiList)

  pane.setTitle(getTitle(config.getParameter("text")), config.getParameter("nickname"))
  widget.setImage("icon", string.format("/emotes/%s.emote.png", self.emojiList[math.random(#self.emojiList)]))

  if widget.setHint then
    widget.setHint("tbxSearch", config.getParameter("textboxHint"))
  end

  widget.setText("sa_All.lbl_All", config.getParameter("allLabel"))

  widget.focus("tbxSearch")
end

function getTitle(text)
  local cleanText = starcustomchat.utils.clearMetatags(text)
  return utf8.len(cleanText) > self.maxLength and starcustomchat.utils.utf8Substring(cleanText, 1, self.maxLength) .. "..." or text
end

function populateReacts(search, widgetName, emojiList)
  widget.clearListItems(widgetName)

  for k, emoji in ipairs(emojiList) do 

    local reactionName = type(emoji) == "string" and emoji or emoji.id
    if not search or string.find(reactionName, search, nil, true) then
      local li = widget.addListItem(widgetName)
      widget.setImage(widgetName .. "." .. li .. ".emoji", string.format("/emotes/%s.emote.png", reactionName))
      widget.setData(widgetName .. "." .. li, reactionName)
      widget.setData(widgetName .. "." .. li .. ".emoji", reactionName)
    end
  end
end

function searchEmoji()
  populateReacts(widget.getText("tbxSearch"), "sa_All.listAll", self.emojiList)
  populateReacts(widget.getText("tbxSearch"), "sa_All.listRecent", touchRecentReaction(self.recentReactions, nil, 10).items)
end

function onEmojiSelect(listName)
  local li = widget.getListSelected("sa_All." .. listName)
  if li then
    local selectedReaction = widget.getData("sa_All." .. listName .. "." .. li)
    local data = {
      reaction = selectedReaction,
      uuid = config.getParameter("messageUUID"),
      source = {
        name = player.name(),
        uuid = player.uniqueId()
      }
    }

    
    if self.stagehandType and self.stagehandType ~= "" then
      world.spawnStagehand(world.entityPosition(player.id()), self.stagehandType, {message = "addReaction", data = data})
    else
      for _, pl in ipairs(starcustomchat.utils.playersInRadius()) do 
        world.sendEntityMessage(pl, "scc_add_reaction", data)
      end
    end

    self.recentReactions = touchRecentReaction(self.recentReactions, selectedReaction, 10)
    root.setConfiguration("scc_most_recent_reactions", self.recentReactions) 

    pane.dismiss()
  end
end

function hasEmoji(e)
  for _, emoji in ipairs(self.emojiList) do 
    if e == emoji then
      return true
    end
  end
  return false
end

function touchRecentReaction(recent, reactionId, limit)
  local function findIndexById(items, id)
    for i = 1, #items do
      if items[i].id == id then return i end
    end
    return nil
  end

  local function nextTick(recent)
    recent.tick = (recent.tick or 0) + 1
    return recent.tick
  end

  local function sortAndTrim(recent, limit)
    limit = limit or 10

    table.sort(recent.items, function(a, b)
      if a.count ~= b.count then return a.count > b.count end
      local la, lb = a.last or 0, b.last or 0
      if la ~= lb then return la > lb end
      return a.id < b.id
    end)

    while #recent.items > limit do
      table.remove(recent.items)
    end
  end


  recent = recent or {}
  recent.items = recent.items or {}

  if reactionId then
    local t = nextTick(recent)
    local idx = findIndexById(recent.items, reactionId)

    if idx then
      local it = recent.items[idx]
      it.count = (it.count or 0) + 1
      it.last  = t
    else
      table.insert(recent.items, { id = reactionId, count = 1, last = t })
    end
  end

  sortAndTrim(recent, limit)
  return recent
end

function clearRecentReactions()
  -- remove any recent entries that are no longer available in the master list
  if not self.recentReactions or not self.recentReactions.items then return end

  local filtered = {}
  for _, emoji in ipairs(self.recentReactions.items) do
    if hasEmoji(emoji.id) then
      table.insert(filtered, emoji)
    end
  end
  self.recentReactions.items = filtered
end


function createTooltip(screenPosition)
  local wid = widget.getChildAt(screenPosition)
  if wid then
    local data = widget.getData(wid:sub(2))
    if data then return data end
  end
end