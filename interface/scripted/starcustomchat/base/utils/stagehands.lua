
function starcustomchat.utils.sendMessageToStagehand(stagehandType, message, data, callback, errcallback)
  return coroutine.create(function()
      local totalTries = 600 -- That's basically 10 seconds

      while not player.id() or not world.entityPosition(player.id()) do
          coroutine.yield()
      end

      world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

      while totalTries > 0 do
          coroutine.yield()

          local playerPos = world.entityPosition(player.id())
          if not playerPos then break end

          for _, sh in ipairs(world.entityQuery(playerPos, 10, { includedTypes = {"stagehand"} })) do
              if world.stagehandType(sh) == stagehandType then
                  promises:add(world.sendEntityMessage(sh, message, data), callback, errcallback)
                  return
              end
          end

          totalTries = totalTries - 1
      end

      -- If we run out of retries, call error callback
      if errcallback then 
        errcallback("TIMEOUT") 
      end
  end)
end


function starcustomchat.utils.sendMessageToUniqueStagehand(stagehandType, message, data, callback, errcallback)

  local ensureSending = function ()
    promises:add(world.sendEntityMessage(stagehandType, message, data), function (result)
      if callback then
        callback(result)
      end
    end, ensureSending)
  end

  local ensureSpawning = function()
    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end

  promises:add(world.findUniqueEntity(stagehandType), ensureSending, function()
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType)

    promises:add(world.findUniqueEntity(stagehandType), ensureSending, ensureSpawning)
  end)
end

function starcustomchat.utils.createStagehandWithData(stagehandType, overrides)
  starcustomchat.utils.runWhenPlayerReady(function()
    world.spawnStagehand(world.entityPosition(player.id()), stagehandType, overrides)
  end)
end