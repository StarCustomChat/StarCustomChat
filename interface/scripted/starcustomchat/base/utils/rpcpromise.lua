-- RPC Promise Mock
RPCPromise = {}

function RPCPromise:new(o)
  local obj = o or {}
  obj.hasSucceeded = false
  obj.processingTime = 0

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function RPCPromise:finished()
end

function RPCPromise:succeeded()
  return self.hasSucceeded
end

function RPCPromise:result()
  return nil
end

PlayerExistsPromise = RPCPromise:new()

function PlayerExistsPromise:finished()
  if player.id() and world.entityPosition(player.id()) then 
    self.hasSucceeded = true; 
    return true 
  end
end