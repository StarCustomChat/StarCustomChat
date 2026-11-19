require "/interface/scripted/starcustomchat/plugins/media/scripts/png.lua"

SCCMediaGif = {}

local function invalid()
  error("Invalid or unsupported GIF", 0)
end

local function lzw(data, minimum, expected, checkpoint)
  if minimum < 2 or minimum > 8 then invalid() end
  local clear = 1 << minimum
  local dictionary, nextCode, bits, previous
  local offset, buffer, buffered, count = 1, 0, 0, 0
  local output, operations = {}, 0
  local function reset()
    checkpoint(clear)
    dictionary = {}
    for i = 0, clear - 1 do dictionary[i] = string.char(i) end
    nextCode, bits, previous = clear + 2, minimum + 1, nil
  end
  reset()
  local first = true
  while true do
    operations = operations + 1
    if operations == 256 then
      checkpoint(operations * 4)
      operations = 0
    end
    while buffered < bits do
      if offset > #data then invalid() end
      buffer = buffer | (data:byte(offset) << buffered)
      buffered, offset = buffered + 8, offset + 1
    end
    local code = buffer & ((1 << bits) - 1)
    buffer, buffered = buffer >> bits, buffered - bits
    if first and code ~= clear then invalid() end
    first = false
    if code == clear then
      reset()
    elseif code == clear + 1 then
      checkpoint(operations * 4)
      if count ~= expected then invalid() end
      return table.concat(output)
    else
      local entry = dictionary[code]
      if not entry and code == nextCode and previous then entry = previous .. previous:sub(1, 1) end
      if not entry or count + #entry > expected then invalid() end
      output[#output + 1], count = entry, count + #entry
      if previous and nextCode < 4096 then
        dictionary[nextCode] = previous .. entry:sub(1, 1)
        nextCode = nextCode + 1
        if nextCode == 1 << bits and bits < 12 then bits = bits + 1 end
      end
      previous = entry
    end
  end
end

-- Parse all frame descriptors before decoding any pixels.
local function parse(data)
  local offset = 7
  local function read(size)
    if offset + size - 1 > #data then invalid() end
    local value = data:sub(offset, offset + size - 1)
    offset = offset + size
    return value
  end
  local function byte() return read(1):byte() end
  local function blocks()
    local result = {}
    local size = byte()
    while size ~= 0 do
      result[#result + 1] = read(size)
      size = byte()
    end
    return table.concat(result)
  end
  local function palette(flags)
    if flags & 128 == 0 then return end
    local colors = {}
    for i = 0, (1 << ((flags & 7) + 1)) - 1 do colors[i] = read(3) .. "\255" end
    return colors
  end
  local width, height, flags, background = string.unpack("<I2I2BBB", read(7))
  if width == 0 or height == 0 then invalid() end
  local globalPalette = palette(flags)
  local result = {kind = "animation", size = {width, height}, frames = {}, duration = 0, plays = 1,
    background = globalPalette and globalPalette[background] or "\0\0\0\0"}
  local control = {}
  while true do
    local marker = byte()
    if marker == 0x3b then
      if #result.frames == 0 or offset ~= #data + 1 then invalid() end
      return result
    elseif marker == 0x21 then
      local label = byte()
      if label == 0xf9 then
        if byte() ~= 4 then invalid() end
        local packed, delay, transparent = string.unpack("<BI2B", read(4))
        if byte() ~= 0 or packed & 224 ~= 0 or (packed >> 2) & 7 > 3 then invalid() end
        control = {disposal = (packed >> 2) & 7, transparent = packed & 1 ~= 0 and transparent or nil,
          -- Match common GIF viewers for missing/zero/one-centisecond delays.
          delay = delay < 2 and 10 or delay}
      elseif label == 0xff then
        if byte() ~= 11 then invalid() end
        local application, payload = read(11), blocks()
        if application == "NETSCAPE2.0" or application == "ANIMEXTS1.0" then
          if #payload ~= 3 or payload:byte(1) ~= 1 then invalid() end
          local repeats = string.unpack("<I2", payload, 2)
          result.plays = repeats == 0 and 0 or repeats + 1
        end
      elseif label == 0x01 then
        -- Plain-text rendering is not an image frame and cannot be reproduced.
        invalid()
      else
        blocks() -- Comments and extensions unknown to this decoder.
      end
    elseif marker == 0x2c then
      local x, y, w, h, packed = string.unpack("<I2I2I2I2B", read(9))
      if w == 0 or h == 0 or x + w > width or y + h > height or packed & 24 ~= 0 then invalid() end
      local colors = palette(packed) or globalPalette
      if not colors then invalid() end
      local frame = {x = x, y = y, width = w, height = h, colors = colors, interlaced = packed & 64 ~= 0,
        disposal = control.disposal or 0, transparent = control.transparent,
        minimum = byte(), compressed = blocks()}
      if frame.minimum < 2 or frame.minimum > 8 then invalid() end
      result.duration = result.duration + (control.delay or 10)
      frame.endsAt = result.duration / 100
      result.frames[#result.frames + 1], control = frame, {}
    else
      invalid()
    end
  end
end

local transparentPixel = "\0\0\0\0"
local function render(result)
  -- A configured image size may be much larger than 64x64. Bound work inside
  -- every decoding/encoding loop, rather than treating a whole frame as a step.
  -- Weighted work units leave room for chat rendering and the other plugins in
  -- the same update; no engine instruction-limit changes or debug hooks needed.
  local workBudget = 65536
  local remaining = workBudget
  local function checkpoint(work)
    remaining = remaining - work
    if remaining <= 0 then
      remaining = workBudget
      coroutine.yield()
    end
  end
  local width, height = result.size[1], result.size[2]
  local canvas, paths = {}, {}
  local background = result.frames[1].transparent ~= nil and transparentPixel or result.background
  for i = 1, width * height do
    canvas[i] = background
    if i % 256 == 0 then checkpoint(256) end
  end
  checkpoint(width * height % 256)
  for index, frame in ipairs(result.frames) do
    local indices = lzw(frame.compressed, frame.minimum, frame.width * frame.height, checkpoint)
    local previous
    if frame.disposal == 3 then
      previous = {}
      for i, pixel in ipairs(canvas) do
        previous[i] = pixel
        if i % 256 == 0 then checkpoint(256) end
      end
      checkpoint(#canvas % 256)
    end
    local cursor = 1
    local function drawRow(y)
      for x = 0, frame.width - 1 do
        local index = indices:byte(cursor)
        cursor = cursor + 1
        if index ~= frame.transparent then
          local color = frame.colors[index]
          if not color then invalid() end
          canvas[(frame.y + y) * width + frame.x + x + 1] = color
        end
        if (x + 1) % 256 == 0 then checkpoint(256) end
      end
      checkpoint(frame.width % 256)
    end
    if frame.interlaced then
      for _, pass in ipairs({{0, 8}, {4, 8}, {2, 4}, {1, 2}}) do
        for y = pass[1], frame.height - 1, pass[2] do drawRow(y) end
      end
    else
      for y = 0, frame.height - 1 do drawRow(y) end
    end
    local pixels = table.concat(canvas)
    local path = paths[pixels] or SCCMediaPng.path(width, height, canvas, checkpoint)
    paths[pixels] = path
    if frame.disposal == 2 then
      local fill = frame.transparent ~= nil and transparentPixel or result.background
      for y = frame.y, frame.y + frame.height - 1 do
        for x = frame.x, frame.x + frame.width - 1 do
          canvas[y * width + x + 1] = fill
          if (x - frame.x + 1) % 256 == 0 then checkpoint(256) end
        end
        checkpoint(frame.width % 256)
      end
    elseif previous then
      canvas = previous
    end
    frame.colors, frame.compressed = nil, nil
    -- Publish only fully prepared frames, even when a step yields mid-frame.
    frame.path = path
    result.readyFrames = index
    if index < #result.frames then
      remaining = workBudget
      coroutine.yield()
    end
  end
  result.background = nil
end

function SCCMediaGif.inspect(data)
  local ok, result, reason = pcall(parse, data)
  if not ok then return nil, "gif_invalid" end
  if result then
    result.duration = result.duration / 100
    result.readyFrames, result.pending = 0, true
    result.decoder = coroutine.create(function() render(result) end)
  end
  return result, reason
end

-- Resume one bounded batch; a frame may need several batches. Invisible/history
-- entries need no pixel decoding. Callers only draw frames published as ready.
function SCCMediaGif.step(data)
  if not data.pending then return not data.failed end
  local ok = coroutine.resume(data.decoder)
  if not ok or coroutine.status(data.decoder) == "dead" then
    data.decoder, data.pending, data.failed = nil, false, not ok
  end
  return ok
end
