require "/scripts/messageutil.lua"
require "/scripts/scctimer.lua"

function init()
  self.soundName = "ouch"
  message.setHandler("sccTalkingSound", localHandler(sccTalkingSound))
end

function update(dt)
  timers:update(dt)
end

function sccTalkingSound(soundData)
  timers:clear()
  
  if type(soundData) == "string" then
    animator.setSoundPool(self.soundName, {soundData})
    animator.setSoundVolume(self.soundName, 1)
    animator.setSoundPitch(self.soundName, 1)
  elseif type(soundData) == "table" then
    animator.setSoundPool(self.soundName, soundData.pool or {})
    animator.setSoundVolume(self.soundName, soundData.volume or 1)
    animator.setSoundPitch(self.soundName, soundData.pitch or 1)
  end
  animator.playSound(self.soundName)
  timers:add(soundData.cutoffTime, function()
    animator.stopAllSounds(self.soundName)
  end)
end

function uninit()

end