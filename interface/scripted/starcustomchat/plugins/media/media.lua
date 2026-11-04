require "/interface/scripted/starcustomchat/plugin.lua"
require "/interface/scripted/starcustomchat/plugins/media/scripts/metadata.lua"
require "/scripts/rect.lua"

media = PluginClass:new({name = "media"})

function media:init(chat)
  PluginClass.init(self, chat)
  self.supported = type(sb.embedData) == "function" and type(root.assetData) == "function"
  -- Cache by message identity, including failed probes. Nothing derived from
  -- remote media (or any playback state) is trusted from saved chat history.
  self.cache = setmetatable({}, {__mode = "k"})
  self:loadSoundImages()
  for _, message in ipairs(chat.messages) do
    self:onReceiveMessage(message)
  end
end

function media:loadSoundImages()
  self.soundButtons = {}
  if not self.supported then return end
  for _, action in ipairs({"play", "stop"}) do
    local path = self.soundImages and self.soundImages[action]
    local ok, size = pcall(root.imageSize, path)
    if ok and size and size[1] > 0 and size[2] > 0 then
      self.soundButtons[action] = {image = path, size = size}
    end
  end
end

function media:getMedia(message, text)
  if not self.supported then return end
  text = text or message.text
  local cached = self.cache[message]
  if not cached or cached.text ~= text then
    local ok, value, reason = pcall(SCCMediaMetadata.inspect, text, self.maxImageSize, self.maxSoundDuration,
      self.maxGifFrames, self.maxGifDuration)
    cached = {text = text, value = ok and value or false, reason = ok and reason or nil}
    self.cache[message] = cached
  end
  return cached.value or nil, cached.reason
end

function media:preventTextboxCallback(message)
  local _, reason = self:getMedia(message)
  if reason == "image_too_large" then
    starcustomchat.utils.alert("media.image_too_large", self.maxImageSize[1], self.maxImageSize[2])
  elseif reason == "sound_too_long" then
    starcustomchat.utils.alert("media.sound_too_long", self.maxSoundDuration)
  elseif reason == "gif_too_many_frames" then
    starcustomchat.utils.alert("media.gif_too_many_frames", self.maxGifFrames)
  elseif reason == "gif_too_long" then
    starcustomchat.utils.alert("media.gif_too_long", self.maxGifDuration)
  elseif reason == "gif_invalid" then
    starcustomchat.utils.alert("media.gif_invalid")
  else
    return false
  end
  -- Abort before sending in any channel, leaving the draft available to edit.
  return true
end

function media:formatOutcomingMessage(message)
  if self:getMedia(message) then
    message.silent = true
    message.data = message.data or {}
    message.data.media = message.text
    message.text = "[media]"
  end
  return message
end

function media:formatIncomingMessage(message)
  local media = type(message.data) == "table" and message.data.media
  if type(media) == "string" and self:getMedia(message, media) then
    message.text = media
  end
  return message
end

function media:setMessageImage(message, text)
  local data = self:getMedia(message, text)
  local image, size, scale, interactive
  if data and data.kind == "image" then
    image, size, scale = data.path, data.size, 1
  elseif data and data.kind == "animation" then
    image = data.frames[data.frame or 1].path or "/assetmissing.png?multiply=ffffff00"
    size, scale = data.size, 1
  elseif data and data.kind == "sound" and self.soundButtons.play and self.soundButtons.stop then
    local playing = self.playing and self.playing.message == message
    local button = self.soundButtons[playing and "stop" or "play"]
    image, size, interactive = button.image, button.size, true
  end

  if image then
    if message.image ~= image or message.imageSize ~= size or message.imageScale ~= scale then
      message.textHeight = nil
    end
    message.image = image
    message.imageSize = size
    message.imageScale = scale -- Media images stay at native size; buttons scale like stickers.
    message.imageInteractive = interactive
    message.mediaType = data.kind
  else
    self:cleanMessage(message)
  end
end

function media:onReceiveMessage(message)
  self:setMessageImage(message)
end

function media:editMessage(message)
  -- SCC copies edited text into the existing history entry after this callback.
  -- Update that entry's derived image fields without replacing its other data.
  local index = self.customChat:findMessageByUUID(message.uuid)
  local stored = index and self.customChat.messages[index]
  if stored then
    if self.playing and self.playing.message == stored then self:stopSound() end
    self:setMessageImage(stored, message.text)
  end
  return message
end

function media:onDrawMessage(message, drawData)
  if not message.imageInteractive then return end
  local data = self:getMedia(message)
  if data and data.kind == "sound" then
    data.imageRect = drawData.imageRect
  end
end

function media:cleanMessage(message)
  if not message.mediaType then return end
  message.image = nil
  message.imageSize = nil
  message.imageScale = nil
  message.imageInteractive = nil
  message.mediaType = nil
  message.textHeight = nil
end

function media:stopSound()
  if self.playing then
    local playing = self.playing
    pane.stopAllSounds(playing.path)
    self.playing = nil
    self:setMessageImage(playing.message)
  end
end

function media:playSound(message, data)
  self:stopSound()
  local ok = pcall(pane.playSound, data.path, 0, 1)
  if ok then
    self.playing = {message = message, path = data.path, remaining = data.duration, text = message.text}
    self:setMessageImage(message)
  else
    starcustomchat.utils.alert("media.playback_error")
  end
  self.customChat:processQueue()
end

function media:soundAt(position, message)
  local size = self.customChat.canvas:size()
  if not position or position[1] < 0 or position[2] < 0 or position[1] >= size[1] or position[2] >= size[2] then return end
  local data = message and message.imageInteractive and self:getMedia(message)
  if not data or data.kind ~= "sound" then return end
  if data.imageRect and rect.contains(data.imageRect, position) then
    return data, self.playing and self.playing.message == message and "stop" or "play"
  end
end

function media:onCanvasClick(position, button, isButtonDown)
  if button ~= 0 then return false end
  local message = self.customChat:selectMessage(position, true)
  local data, action = self:soundAt(position, message)
  if not data then return false end
  if isButtonDown then
    if action == "play" then
      self:playSound(message, data)
    elseif self.playing and self.playing.message == message then
      self:stopSound()
      self.customChat:processQueue()
    end
  end
  return true
end

function media:onCreateTooltip(screenPosition)
  local message = self.customChat:selectMessage(screenPosition)
  local data, action = self:soundAt(self.customChat.topCanvas:mousePosition(), message)
  if data then
    return starcustomchat.utils.getTranslation("media." .. action, data.duration)
  end
end

function media:update(dt)
  local redraw = false
  local displayed = not pane.isDisplayed or pane.isDisplayed()
  if self.playing then
    self.playing.remaining = self.playing.remaining - dt
    local present = false
    for _, message in ipairs(self.customChat.messages) do
      if message == self.playing.message and message.text == self.playing.text then
        present = true
        break
      end
    end
    if self.playing.remaining <= 0 or not present or not displayed then
      self:stopSound()
      redraw = true
    end
  end

  -- Decode at most one bounded GIF batch per update, sharing work between visible
  -- messages. Pause playback when the next frame has not been prepared yet.
  if displayed then
    local chat = self.customChat
    local spacing = chat.config.spacings.name + chat.config.fontSize + 1
    local animations, pending, firstFrame = {}, {}
    for _, index in ipairs(chat.drawnMessageIndexes or {}) do
      local message = chat.messages[index]
      if message and message.mediaType == "animation" and message.offset
        and chat:isInsideChat(message, message.offset, spacing, chat.canvas:size()) then
        local data = self:getMedia(message)
        if data and data.kind == "animation" then
          local entry = {message = message, data = data}
          animations[#animations + 1] = entry
          if data.pending then
            pending[#pending + 1] = entry
            if data.readyFrames == 0 then firstFrame = entry end
          end
        end
      end
    end
    if #pending > 0 then
      self.decodeIndex = (self.decodeIndex or 0) % #pending + 1
      local entry = firstFrame or pending[self.decodeIndex]
      if not SCCMediaGif.step(entry.data) then
        self.cache[entry.message].value, self.cache[entry.message].reason = false, "gif_invalid"
        self:cleanMessage(entry.message)
        redraw = true
      end
    end
    for _, entry in ipairs(animations) do
      local message, data = entry.message, entry.data
      if not data.failed and data.readyFrames > 0 then
        local elapsed = (data.elapsed or 0) + dt
        local frame = #data.frames
        if data.plays == 0 or elapsed < data.duration * data.plays then
          local phase = elapsed % data.duration
          local low, high = 1, #data.frames
          while low < high do
            local middle = (low + high) // 2
            if phase < data.frames[middle].endsAt then high = middle else low = middle + 1 end
          end
          frame = low
        end
        if data.frames[frame].path then
          data.frame, data.elapsed = frame, elapsed
        end
        -- The first ready frame replaces the transparent loading placeholder.
        local image = data.frames[data.frame or 1].path
        if message.image ~= image then message.image, redraw = image, true end
      end
    end
  end
  -- Frame sizes are constant, so retain layout and redraw only once.
  if redraw then self.customChat:processQueue() end
end

function media:onChatClose()
  if self.playing then
    self:stopSound()
    self.customChat:processQueue()
  end
end

function media:uninit()
  self:stopSound()
end
