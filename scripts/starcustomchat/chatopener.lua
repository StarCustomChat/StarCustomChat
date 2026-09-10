require "/interface/scripted/starcustomchat/chatbuilder.lua"
require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/scctimer.lua"

SCChatTimer = TimerKeeper.new()

local shared = getmetatable('').shared

if type(shared) ~= "table" then
  shared = {}
  getmetatable('').shared = shared
end

function init()
  self.isOpenSB = root.assetOrigin and root.assetOrigin("/opensb/coconut.png")

  self.chatUUID = sb.makeUuid()

  local reasonToNotStart = checkSEAndControls()

  if reasonToNotStart then
    local sewarningConfig = root.assetJson("/interface/scripted/starcustomchat/sewarning/sewarning.json")
    sewarningConfig.reason = reasonToNotStart
    player.interact("ScriptPane", sewarningConfig)
  else
    if not xsb then shared.setMessageHandler = message.setHandler end
  end

  message.setHandler("scc_uuid", localHandler(function() return self.chatUUID end))

  SCChatTimer:add(0.5, function() 
    if player.id() then
      world.sendEntityMessage(player.id(), "scc_reset_settings") 
    end
  end)
end

function checkSEAndControls()
  if not self.isOpenSB then
    return "se_osb_xsb_not_found"
  else
    if not world.loungingEntities then
      return "osb_xsb_version"
    end
  end
end


function update(dt)
  SCChatTimer:update(dt)
  promises:update()
end

function uninit()

end