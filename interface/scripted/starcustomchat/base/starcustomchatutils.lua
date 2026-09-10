local shared = getmetatable('').shared

if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

starcustomchat = {
  utils = {},
  locale = {},
  currentLocale = "en",
  defaultLocale = "en"
}

require "/interface/scripted/starcustomchat/base/utils/textstyle.lua"
require "/interface/scripted/starcustomchat/base/utils/stagehands.lua"
require "/interface/scripted/starcustomchat/base/utils/rpcpromise.lua"
require "/interface/scripted/starcustomchat/base/utils/strings.lua"

function starcustomchat.utils.setSharedValue(key, value)
  starcustomchat.utils.resetShared()
  shared[key] = value
  starcustomchat.shared = shared
end

function starcustomchat.utils.getSharedValue(key)
  starcustomchat.utils.resetShared()
  return starcustomchat.shared[key]
end

function starcustomchat.utils.resetShared()
  if type(shared) ~= "table" then
    shared = {}
    getmetatable('').shared = shared
  end

  shared = getmetatable('').shared
  starcustomchat.shared = shared

  starcustomchat.utils.setMessageHandler = _ENV["message"] and _ENV["message"].setHandler or shared.setMessageHandler
end

function starcustomchat.utils.getVersion(path)
  if root.assetSourceMetadata then
    local assetPath = root.assetOrigin(path or "/interface/scripted/starcustomchat/base/chatgui.json")
    if assetPath then
      local metadata = root.assetSourceMetadata(assetPath)
      if metadata then
        return metadata.version
      end
    end
  end
end

function starcustomchat.utils.getLocale()
  starcustomchat.currentLocale = root.getConfiguration("scclocale") or starcustomchat.defaultLocale
  return starcustomchat.currentLocale
end


function starcustomchat.utils.buildLocale(fullLocalizationTable)
  starcustomchat.currentLocale = starcustomchat.utils.getLocale()
  starcustomchat.locale = copy(fullLocalizationTable)
end

function starcustomchat.utils.hasTranslation(key)
  return not not (starcustomchat.locale[starcustomchat.currentLocale][key] or starcustomchat.locale[starcustomchat.defaultLocale][key])
end

function starcustomchat.utils.getTranslation(key, ...)
  local translation = starcustomchat.locale[starcustomchat.currentLocale][key] or starcustomchat.locale[starcustomchat.defaultLocale][key]
  if not translation then
    sb.logWarn("Can't get transaction of key: %s", key)
    return "???"
  else
    return ... and string.format(translation, ...) or translation
  end
end

function starcustomchat.utils.alert(key, ...)
  local text = starcustomchat.utils.getTranslation(key)
  interface.queueMessage(... and string.format(text, ...) or text)
end

function starcustomchat.utils.saveMessage(message)
  if self.recalledSentMessage == message then
    self.recalledSentMessage = nil
    self.currentSentMessage = nil
    return
  end

  self.recalledSentMessage = nil
  table.insert(self.sentMessages, message)

  if #self.sentMessages > self.sentMessagesLimit then
    table.remove(self.sentMessages, 1)
  end
  self.currentSentMessage = #self.sentMessages
end

function starcustomchat.utils.getCommands(allCommands, substr)
  local availableCommands = {}

  local function addCommandToList(command, data, description, displayName)
    if string.find(command, substr, nil, true) then
      table.insert(availableCommands, {
        name = displayName or command,
        description = description,
        data = data,
        color = nil
      })
    end
  end

  local function runThroughCommands(commType, commandList, prefix, level)
    for _, comm in ipairs(commandList) do
      if type(comm) == "string" then
          addCommandToList(prefix .. comm, comm, nil, prefix .. comm)
      elseif type(comm) == "table" then
        if not comm.admin or player.isAdmin() then
          local fullCommand = prefix .. comm.command
          addCommandToList(fullCommand, comm.command, comm.description, comm.displayName or comm.name or fullCommand)
          if string.find(substr, fullCommand .. " ", 1, true) then
            runThroughCommands(commType, comm.subcommands or {}, fullCommand .. " ", level + 1)
          end
        end
      end
    end
  end

  for commType, commlist in pairs(allCommands) do
    if (not string.find(commType, "admin") or player.isAdmin()) then
        runThroughCommands(commType, commlist, "", 0)
    end
  end

  self.runCallbackForPlugins("addCustomCommandPreview", availableCommands, substr)

  --table.sort(availableCommands, function(a, b) return a.name:upper() < b.name:upper() end)
  return availableCommands
end

function starcustomchat.utils.runWhenPlayerReady(callback)
  promises:add(PlayerExistsPromise:new(), callback, function()
    starcustomchat.utils.runWhenPlayerReady(callback)
  end)
end

function starcustomchat.utils.listToSet(list)
  local set = {}
  for _,v in ipairs(list) do
    set[v] = true
  end
  return set
end

function starcustomchat.utils.clearPortraitFromInvisibleLayers(portrait)
  if portrait and type(portrait) == "table" then
    local filteredPortrait = {}
    for _, layer in ipairs(portrait) do 
      local imageSize = root.imageSize(layer.image)
      if layer.image and not vec2.eq(imageSize, {0, 0}) and not string.find(layer.image, "?crop.?0;0;0") and not string.match(layer.image, "^?multiply.?000;?$") then
        
        -- Set the idle emote
        if string.find(layer.image, "/emote.png") then
          layer.image = string.gsub(layer.image, ":%w+%.%d", ":idle.1")
        end

        if vec2.eq(imageSize, {85, 85}) then
          layer.image = layer.image .. "?crop;21;21;85;85"
        end
        table.insert(filteredPortrait, layer)
      end
    end

    return filteredPortrait
  end

  return portrait
end


function starcustomchat.utils.drawCircle(center, radius, color, sections)
  sections = sections or 20

  for i = 1, sections do
    local startAngle = math.pi * 2 / sections * (i-1)
    local endAngle = math.pi * 2 / sections * i
    local startLine = vec2.add(center, {radius * math.cos(startAngle), radius * math.sin(startAngle)})
    local endLine = vec2.add(center, {radius * math.cos(endAngle), radius * math.sin(endAngle)})

    if not self.drawingCanvas then
      self.drawingCanvas = interface.bindCanvas("chatInterfaceCanvas")
    end

    self.drawingCanvas:drawLine(vec2.div(camera.worldToScreen(startLine), interface.scale()), vec2.div(camera.worldToScreen(endLine), interface.scale()), color)

  end
end

function starcustomchat.utils.safeImageSize(image)
  if image and type(image) == "string" and image ~= "" then
    local imageSize
    if pcall(function() imageSize = root.imageSize(image) end) then
      if imageSize[1] == 0 or imageSize[2] == 0 then
        return nil
      end
      return imageSize
    else
      return nil
    end
  end

  return nil
end

function starcustomchat.utils.playersInRadius(radius, ignoreUs, nearest)
  radius = radius or 100
  return world.playerQuery(world.entityPosition(player.id()), radius, {
    withoutEntityId = ignoreUs and player.id() or nil,
    order = nearest and "nearest"
  } or nil)
end

function starcustomchat.utils.playerData()
  return {
    entityId = player.id(),
    uuid = player.uniqueId(),
    name = player.name(),
    connection = starcustomchat.utils.entityIdToConnection(player.id())
  }
end

function starcustomchat.utils.entityIdToConnection(entityId)
  return entityId // -65536
end

function starcustomchat.utils.connectionToEntityId(connection)
  return connection * -65536
end


-- Utility function: return the index of a value in the given array
function index(tab, value)
  for k, v in ipairs(tab) do
    if v == value then return k end
  end
  return 0
end