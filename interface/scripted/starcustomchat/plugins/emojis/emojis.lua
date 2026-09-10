require "/interface/scripted/starcustomchat/plugin.lua"

emojis = PluginClass:new(
  { name = "emojis" }
)

function emojis:init(chat)
  PluginClass.init(self, chat)

  if widget.active("lytEmojiList") then
    self:populateEmojiList(widget.getText("lytEmojiList.tbxSearch"))
  end

  self.searchText = widget.getText("lytEmojiList.tbxSearch")
end

function emojis:onCustomButtonClick(btnName, data)
  if btnName == "btnEmojiList" then
    widget.setVisible("lytEmojiList", not widget.active("lytEmojiList"))
    if widget.active("lytEmojiList") then
      self.customChat:blurInput()
      widget.focus("lytEmojiList.tbxSearch")
    else
        self.customChat:focusInput()
    end
    self:populateEmojiList(widget.getText("lytEmojiList.tbxSearch"))
  elseif btnName == "tbxSearch" then 
    self:searchEmoji()
  elseif btnName == "emojiListGroups" then 
    self:selectEmojiGroup()
  elseif self.emojiNullItems and self.emojiNullItems[btnName] then
    self:addEmoji(btnName)
  end
end

function emojis:onCustomButtonClick2(btnName, data)
  if btnName == "tbxSearch" then
    widget.setVisible("lytEmojiList", false)
    widget.setText("lytEmojiList.tbxSearch", "")
    widget.blur("lytEmojiList.tbxSearch")
    self.customChat:focusInput()
    self.searchText = ""
  end
end

function emojis:onTextboxEscape()
    if widget.active("lytEmojiList") then
      widget.setVisible("lytEmojiList", false)
      widget.blur("lytEmojiList.tbxSearch")
      self.customChat:focusInput()
      return true
    end
end

local function containsModifier(mods, modifier)
  for key, value in pairs(mods or {}) do
    if value == modifier or (key == modifier and value) then
      return true
    end
  end

  return false
end

local function matchesBind(event, bind)
  if event.type ~= "KeyDown" or not event.data or bind.type ~= "key" then
    return false
  end

  local eventMods = event.data.mods or {}
  local bindMods = bind.mods or {}

  if event.data.key ~= bind.value then
    return false
  end

  for _, modifier in ipairs(bindMods) do
    if not containsModifier(eventMods, modifier) then
      return false
    end
  end

  return true
end

function emojis:processEvents(events)
  local emojiBinds = input.getBinds("starcustomchat", "openEmojiPane")

  if self.customChat:hasFocusInput() then
    for _, event in ipairs(events) do
        for _, bind in ipairs(emojiBinds) do
        if matchesBind(event, bind) then
            self:onCustomButtonClick("btnEmojiList")
            return
        end
            end
        end
    end
end

function emojis:populateEmojiList(search)
    if not self.emojiNullItems then
        self.emojiNullItems = {}
        self.scrollPositionOffsets = {}
        self.nullGroupListItem = nil
        
        local listTemplate = {
            type = "list",
            columns  = 11,
            callback = "customButtonCallback",
            position = {0, -2},
            schema = {
                selectedBG = "/assetmissing.png",
                unselectedBG = "/assetmissing.png",
                spacing = {0, 2},
                memberSize = {16, 16},
                listTemplate = {
                    emoji = {
                        type = "label",
                        value = "",
                        mouseTransparent = true,
                        fontSize = 12
                    }
                }
            }
        }
        local listPosition = listTemplate.position

        local emojiList = root.assetJson("/interface/scripted/starcustomchat/plugins/emojis/emojislist.json")
        local groupImage = "/interface/scripted/starcustomchat/plugins/emojis/interface/groups.png"

        widget.clearListItems("lytEmojiList.saGroups.emojiListGroups")

        for _, group in ipairs(emojiList) do
            
            local groupLi = widget.addListItem("lytEmojiList.saGroups.emojiListGroups")
            self.scrollPositionOffsets[groupLi] = copy(listPosition)

            
            
            widget.setImage("lytEmojiList.saGroups.emojiListGroups." .. groupLi .. ".emoji", groupImage .. ":" .. group.code)
            widget.setData("lytEmojiList.saGroups.emojiListGroups." .. groupLi, {
                displayText = "chat.emojis.groups." .. group.code
            })

            widget.removeChild("lytEmojiList.saAll", "lbl" .. group.code)
            widget.addChild("lytEmojiList.saAll", {
                type = "label",
                position = listPosition,
                value = starcustomchat.utils.getTranslation("chat.emojis.groups." .. group.code)
            }, "lbl" .. group.code)

            listTemplate.position = listPosition
            widget.removeChild("lytEmojiList.saAll", group.code)
            widget.addChild("lytEmojiList.saAll", listTemplate, group.code)

            local totalEmojis = 0
            for _, emoji in ipairs(group.emojis) do 
                if string.find(emoji.name, search) then
                    local emojiLi = widget.addListItem("lytEmojiList.saAll." .. group.code)
                    emoji.displayPlainText = ":" .. emoji.name .. ":"
                    widget.setText("lytEmojiList.saAll." .. group.code .. "." .. emojiLi .. ".emoji", emoji.emoji)
                    widget.setData("lytEmojiList.saAll." .. group.code .. "." .. emojiLi, emoji)
                    totalEmojis = totalEmojis + 1
                end
            end

            if totalEmojis == 0 then
                widget.removeChild("lytEmojiList.saAll", "lbl" .. group.code)
                widget.removeChild("lytEmojiList.saAll", group.code)
                self.scrollPositionOffsets[groupLi] = nil
            else
                local offset = {listPosition[1], listPosition[2] - widget.getSize("lytEmojiList.saAll." .. group.code)[2]}
                widget.setPosition("lytEmojiList.saAll." .. group.code, offset)

                listPosition[2] = listPosition[2] - widget.getSize("lytEmojiList.saAll." .. group.code)[2] - 16

                -- Add the nullptr in case we don't have widget.clearListSelected
                self.emojiNullItems[group.code] = {}
                if not widget.clearListSelected then
                    self.emojiNullItems[group.code] = widget.addListItem("lytEmojiList.saAll." .. group.code)
                    widget.setPosition("lytEmojiList.saAll." .. group.code .. "." .. self.emojiNullItems[group.code], {-400, -400})
                end
            end
        end
        

        self.nullGroupListItem = widget.addListItem("lytEmojiList.saGroups.emojiListGroups")
        widget.setPosition("lytEmojiList.saGroups.emojiListGroups." .. self.nullGroupListItem, {-400, -400})
    end
end

function emojis:addEmoji(listName)
    local li = widget.getListSelected("lytEmojiList.saAll." .. listName)
    if li then
        local data = widget.getData("lytEmojiList.saAll." .. listName .. "." .. li)
        if data and data.emoji then
            self.customChat:setText(self.customChat:getText() .. data.emoji .. (self.addSpaceAfterEmoji and " " or ""))
            if widget.clearListSelected then
                widget.clearListSelected("lytEmojiList.saAll." .. listName)
            else
                widget.setListSelected("lytEmojiList.saAll." .. listName, self.emojiNullItems[listName])
            end
            self.customChat:focusInput()
        end
    end
end

function emojis:onLocaleChange()
  if widget.setHint then
    widget.setHint("lytEmojiList.tbxSearch", starcustomchat.utils.getTranslation("settings.search"))
  end
end

function emojis:selectEmojiGroup()
    widget.setText("lytEmojiList.tbxSearch", "")
    
    local selectedGroup = widget.getListSelected("lytEmojiList.saGroups.emojiListGroups")

    if widget.setScrollOffset and selectedGroup then
        widget.setScrollOffset("lytEmojiList.saAll", vec2.add(widget.getMaxScrollPosition("lytEmojiList.saAll"), {0, self.scrollPositionOffsets[selectedGroup][2]}))
    end

    if widget.clearListSelected then
        widget.clearListSelected("lytEmojiList.saGroups.emojiListGroups")
    else
        widget.setListSelected("lytEmojiList.saGroups.emojiListGroups",  self.nullGroupListItem)
    end
end

function emojis:searchEmoji()
    local search = widget.getText("lytEmojiList.tbxSearch")
    if search ~= self.searchText then
        self.searchText = search
        self.emojiNullItems = nil
        self:populateEmojiList(search)
    end
end

function emojis:onSendMessage(message)
    widget.setVisible("lytEmojiList", false)
    return message
end

function emojis:onChatScroll(screenPosition)
  return widget.active("lytEmojiList") and widget.inMember("lytEmojiList", screenPosition)
end

function emojis:onCanvasClick(position, button, isButtonDown)
    if widget.active("lytEmojiList") then
      if not widget.hasFocus("lytEmojiList.tbxSearch") then
        widget.setVisible("lytEmojiList", false)
      end
      return true
    end
end