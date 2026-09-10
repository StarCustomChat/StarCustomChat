require "/interface/scripted/starcustomchat/plugin.lua"

afk = PluginClass:new(
  { name = "afk" }
)

function afk:init(chat)
  PluginClass.init(self, chat)

  self.timer = (root.getConfiguration("scc_afk_timer") or 0) * 60
  self.afkTime = self.timer
  self.afkActive = false
  self.forcedAfkTimer = 0

  self.effect = root.getConfiguration("scc_afk_effect") or "starchatafk"
  self.ignoreMouse = root.getConfiguration("scc_afk_ignore_mouse") or false

  -- On init, deactivate AFK by force
  --self:deactivateAFK(true)
  status.clearPersistentEffects("starchatafk")
  widget.setVisible("btnStartAfk", not root.getConfiguration("scc_afk_button_disabled"))

  status.setStatusProperty("afkcolor", self.customChat:getColor("afkcolor"):sub(2))

  self.buttonPressed = false
end

function afk:registerMessageHandlers()
  starcustomchat.utils.setMessageHandler("/afk", function(_, isLocal, data)
    if isLocal then
      self.forcedAfkTimer = self.forcedAfkTimer == 0 and self.afkIgnoreTime or 0
      self.buttonPressed = true
      self.afkTime = 0
      self:activateAFK()
    end
  end)
end

function afk:update(dt)

  if self.forcedAfkTimer > 0 then
    self.forcedAfkTimer = math.max(self.forcedAfkTimer - dt, 0)
    if self.putToSleep then
      player.emote("sleep")
    end
  else
    if (#input.events() > 0 and (input.events()[1].type ~= "MouseMove" or not self.ignoreMouse)) or (self.timer == 0 and not self.buttonPressed) then
      self.afkTime = self.timer
      self.buttonPressed = false
      self:deactivateAFK()
    elseif self.afkActive then
      self.afkTime = math.max(self.afkTime - dt, 0)
      if self.putToSleep then
        player.emote("sleep")
      end
    else
      self.afkTime = math.max(self.afkTime - dt, 0)
      if self.afkTime <= 0 then
        self:activateAFK()
      end
    end
  end

  if input.bindDown("starcustomchat", "enableAfk") then
    self.forcedAfkTimer = self.forcedAfkTimer == 0 and self.afkIgnoreTime or 0
    self.buttonPressed = true
    self.afkTime = 0
    self:activateAFK()
  end
end

function afk:onCustomButtonClick(btnName, data)
  if btnName == "btnStartAfk" then
    self.forcedAfkTimer = self.forcedAfkTimer == 0 and self.afkIgnoreTime or 0
    self.buttonPressed = true
    self.afkTime = 0
    self:activateAFK()
  end
end

function afk:activateAFK()
  if not self.afkActive then
    if self.mode == "effect" then
      status.addPersistentEffect("starchatafk", self.effect)
    end
    self.afkActive = true
  end
  
  if self.putToSleep then
    player.emote("sleep")
  end
end

function afk:deactivateAFK(force)
  if self.afkActive or force then
    if self.mode == "effect" then
      status.clearPersistentEffects("starchatafk")
      player.emote("idle")
    end
    self.afkActive = false
  end
end

function afk:onSettingsUpdate(data)
  self.timer = (root.getConfiguration("scc_afk_timer") or 0) * 60
  self.effect = root.getConfiguration("scc_afk_effect") or "starchatafk"
  widget.setVisible("btnStartAfk", not root.getConfiguration("scc_afk_button_disabled"))
  status.setStatusProperty("afkcolor", self.customChat:getColor("afkcolor"):sub(2))
  self.ignoreMouse = root.getConfiguration("scc_afk_ignore_mouse") or false
end

function afk:uninit()
  status.clearPersistentEffects("starchatafk")
end