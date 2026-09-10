require "/interface/scripted/starcustomchat/plugin.lua"

autohide = PluginClass:new(
  { name = "autohide" }
)

function autohide:init(chat)
  PluginClass.init(self, chat)

  self.timer = (root.getConfiguration("scc_autohide_timer") or 0)
  self.autohideTime = self.timer
  self.ignoreServerMessages = root.getConfiguration("scc_autohide_ignore_server_messages") or false
  self.ignoreInspectMessages = root.getConfiguration("scc_autohide_ignore_inspect_messages") or false
end

function autohide:onCursorOverride()
  self.autohideTime = self.timer
end

function autohide:update(dt)
  if self.timer > 0 and self.autohideTime <= 0 then
    closeChat()
    self.autohideTime = self.timer
  end
  self.autohideTime = self.customChat:hasFocusInput() and self.timer or math.max(self.autohideTime - dt, 0)
end

function isInspecting(message)
  local handHeldItem = player.primaryHandItem()
  local inspecting = handHeldItem and handHeldItem.name and handHeldItem.name == "inspectionmode"

  return message.connection == starcustomchat.utils.entityIdToConnection(player.id()) and message.mode == "RadioMessage" and inspecting
end

function autohide:onReceiveMessage(message)
  if message.connection and (message.connection == 0 and not self.ignoreServerMessages) or (message.connection ~= 0 and not (self.ignoreInspectMessages and isInspecting(message))) then
    self.autohideTime = self.timer
    pane.show()
  end
end

function autohide:onSettingsUpdate(data)
  self.timer = (root.getConfiguration("scc_autohide_timer") or 0)
  self.autohideTime = self.timer
  self.ignoreServerMessages = root.getConfiguration("scc_autohide_ignore_server_messages") or false
  self.ignoreInspectMessages = root.getConfiguration("scc_autohide_ignore_inspect_messages") or false
end