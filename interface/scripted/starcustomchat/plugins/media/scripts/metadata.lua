-- Read media metadata without starting audio playback. All entry points are
-- called through pcall by media.lua because chat data may be malformed.
require "/interface/scripted/starcustomchat/plugins/media/scripts/gif.lua"

SCCMediaMetadata = {}

local compression = {none = true, zlib = true, gzip = true, zstd = true}

local function binaryEnd(parts, index)
  if compression[parts[index]] then index = index + 1 end
  local payload = parts[index]
  if not payload or not payload:match("^[%w_-]+=?=?$") or #payload % 4 == 1 then return end
  if payload:find("=", 1, true) and #payload % 4 ~= 0 then return end
  return index + 1
end

function SCCMediaMetadata.path(text)
  if type(text) ~= "string" then return end
  local path = text:match("^%s*(.-)%s*$")
  if path:sub(1, 13) ~= "/opensb_data;" then return end

  local base, suffix = path:match("^([^?:]+)(.*)$")
  if suffix ~= "" and not (suffix:match("^:[%w_.%-]+$")
    or suffix:match("^:[%w_.%-]+%?%S+$") or suffix:match("^%?%S+$")) then return end

  local parts = {}
  for part in (base .. ";"):gmatch("(.-);") do table.insert(parts, part) end
  if parts[2] ~= "bin" and parts[2] ~= "image" then return end
  local nextPart = binaryEnd(parts, 3)
  if not nextPart then return end

  if parts[2] == "image" then
    if nextPart == #parts + 1 then
      -- The engine's image format requires frames. Plain PNG payloads can
      -- use the equivalent bin path for loading; the chat text stays intact.
      base = base:gsub("^/opensb_data;image;", "/opensb_data;bin;", 1)
      path = base .. suffix
    elseif parts[nextPart] == "framespath" then
      local frames = parts[nextPart + 1]
      if not frames or not frames:match("^/[^%s;]+$") then return end
      nextPart = nextPart + 2
    elseif parts[nextPart] == "frames" then
      local kind = parts[nextPart + 1]
      if kind == "text" and parts[nextPart + 2] and parts[nextPart + 2] ~= "" then
        nextPart = nextPart + 3
      elseif kind == "json" or kind == "bin" then
        nextPart = binaryEnd(parts, nextPart + 2)
      else
        return
      end
    else
      return
    end
  end
  if nextPart ~= #parts + 1 then return end
  return path, base, suffix
end

local function wavDuration(data)
  if #data < 44 or data:sub(1, 4) ~= "RIFF" or data:sub(9, 12) ~= "WAVE"
    or data:sub(13, 16) ~= "fmt " or string.unpack("<I4", data, 5) + 8 ~= #data then return end

  -- Match the PCM WAV layout accepted by OpenStarbound's audio loader.
  local fmtSize = string.unpack("<I4", data, 17)
  local format, channels, rate, byteRate, alignment, bits = string.unpack("<I2I2I4I4I2I2", data, 21)
  if fmtSize < 16 or format ~= 1 or channels == 0 or rate == 0 or bits ~= 16
    or alignment ~= channels * 2 or byteRate ~= rate * alignment then return end

  local offset = 21 + fmtSize
  if offset + 7 > #data or data:sub(offset, offset + 3) ~= "data" then return end
  local size = string.unpack("<I4", data, offset + 4)
  if size % alignment ~= 0 or offset + 7 + size > #data then return end
  return size / byteRate
end

local function oggDuration(data)
  local offset, duration, stream = 1, 0, nil
  local serials = {}
  while offset <= #data do
    if offset + 26 > #data or data:sub(offset, offset + 3) ~= "OggS"
      or data:byte(offset + 4) ~= 0 then return end
    local flags = data:byte(offset + 5)
    if flags > 7 then return end
    local low, high, serial, sequence = string.unpack("<I4I4I4I4", data, offset + 6)
    local count = data:byte(offset + 26)
    local payload = offset + 27 + count
    if payload - 1 > #data then return end
    local size = 0
    for i = offset + 27, payload - 1 do size = size + data:byte(i) end
    if payload + size - 1 > #data then return end

    if not stream then
      -- Each chained Vorbis stream has its own rate and end granule. Summing
      -- all streams prevents a short final stream from hiding a longer clip.
      if flags & 3 ~= 2 or sequence ~= 0 or serials[serial] or count == 0
        or data:byte(offset + 27) ~= 30 or size < 30
        or data:sub(payload, payload + 6) ~= "\1vorbis"
        or string.unpack("<I4", data, payload + 7) ~= 0
        or data:byte(payload + 11) == 0 or data:byte(payload + 29) ~= 1 then return end
      local rate = string.unpack("<I4", data, payload + 12)
      if rate == 0 then return end
      serials[serial] = true
      stream = {serial = serial, rate = rate, sequence = -1, samples = 0}
    elseif flags & 2 ~= 0 then
      return
    end
    if serial ~= stream.serial or sequence ~= stream.sequence + 1 then return end
    stream.sequence = sequence

    local unknownGranule = low == 0xffffffff and high == 0xffffffff
    if not unknownGranule then
      if high > 0x1fffff then return end -- outside exact integer range
      local samples = high * 4294967296 + low
      if samples < stream.samples then return end
      stream.samples = samples
    end
    if flags & 4 ~= 0 then
      if unknownGranule then return end
      duration = duration + stream.samples / stream.rate
      stream = nil
    end
    offset = payload + size
  end
  if stream then return end -- truncated stream, no end-of-stream page
  return duration
end

function SCCMediaMetadata.inspect(text, maxImageSize, maxSoundDuration, maxGifFrames, maxGifDuration)
  local path, base, suffix = SCCMediaMetadata.path(text)
  if not path then return end
  -- Explicitly allow embedded bytes for metadata only; never execute them.
  -- This also respects the engine's safe.allowRemoteAssets setting.
  local data = root.assetData(base, true)
  if data:sub(1, 6) == "GIF87a" or data:sub(1, 6) == "GIF89a" then
    -- A GIF carries its own frames; asset frame selectors/directives do not apply.
    if suffix ~= "" or not base:match("^/opensb_data;bin;") then return nil, "gif_invalid" end
    return SCCMediaGif.inspect(data, maxImageSize, maxGifFrames, maxGifDuration)
  end
  if data:sub(1, 8) == "\137PNG\13\10\26\10" then
    if #data < 33 or data:sub(13, 16) ~= "IHDR" then return end
    local width, height = string.unpack(">I4I4", data, 17)
    if width == 0 or height == 0 then return end
    if width > maxImageSize[1] or height > maxImageSize[2] then return nil, "image_too_large" end
    local size = root.assetImage(path):size()
    if size[1] <= 0 or size[2] <= 0 then return end
    if size[1] > maxImageSize[1] or size[2] > maxImageSize[2] then return nil, "image_too_large" end
    return {kind = "image", path = path, size = size}
  end

  -- Audio paths cannot contain image frames or processing directives.
  if suffix ~= "" or not base:match("^/opensb_data;bin;") then return end
  local duration
  if data:sub(1, 4) == "RIFF" then
    duration = wavDuration(data)
  elseif data:sub(1, 4) == "OggS" then
    duration = oggDuration(data)
  end
  if duration and duration > 0 then
    if duration > maxSoundDuration then return nil, "sound_too_long" end
    return {kind = "sound", path = path, duration = duration}
  end
end
