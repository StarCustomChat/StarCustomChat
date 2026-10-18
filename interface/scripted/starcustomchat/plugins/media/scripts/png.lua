-- Encode decoded GIF frames as ordinary embedded PNG assets. This deliberately
-- uses only Lua and the existing bin asset format, without newer image APIs.
SCCMediaPng = {}

local crcTable = {}
for byte = 0, 255 do
  local crc = byte
  for _ = 1, 8 do
    crc = (crc >> 1) ~ (crc & 1 ~= 0 and 0xedb88320 or 0)
  end
  crcTable[byte] = crc
end

local function chunk(kind, data, checkpoint)
  local body, crc = kind .. data, 0xffffffff
  for offset = 1, #body, 1024 do
    local last = math.min(offset + 1023, #body)
    for i = offset, last do
      crc = (crc >> 8) ~ crcTable[(crc ~ body:byte(i)) & 255]
    end
    checkpoint(last - offset + 1)
  end
  return string.pack(">I4", #data) .. body .. string.pack(">I4", crc ~ 0xffffffff)
end

local function deflate(data, checkpoint)
  local blocks, a, b = {"\120\1"}, 1, 0
  for offset = 1, #data, 65535 do
    local block = data:sub(offset, offset + 65534)
    blocks[#blocks + 1] = string.pack("<I1I2I2", offset + #block > #data and 1 or 0, #block, #block ~ 65535) .. block
    for start = 1, #block, 1024 do
      local last = math.min(start + 1023, #block)
      for i = start, last do
        a = (a + block:byte(i)) % 65521
        b = (b + a) % 65521
      end
      checkpoint(last - start + 1)
    end
  end
  blocks[#blocks + 1] = string.pack(">I4", (b << 16) | a)
  return table.concat(blocks)
end

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local pairs64 = {}
for i = 0, 4095 do
  pairs64[i] = alphabet:sub((i >> 6) + 1, (i >> 6) + 1) .. alphabet:sub((i & 63) + 1, (i & 63) + 1)
end
local function base64(data, checkpoint)
  local result = {}
  for offset = 1, #data, 3072 do
    local last = math.min(offset + 3071, #data)
    for i = offset, last, 3 do
      local a, b, c = data:byte(i, i + 2)
      local value = (a << 16) | ((b or 0) << 8) | (c or 0)
      local quad = pairs64[value >> 12] .. pairs64[value & 4095]
      result[#result + 1] = quad:sub(1, c and 4 or b and 3 or 2)
    end
    checkpoint(last - offset + 1)
  end
  return table.concat(result)
end

function SCCMediaPng.path(width, height, pixels, checkpoint)
  checkpoint = checkpoint or function() end
  local rows = {}
  for y = 0, height - 1 do
    rows[#rows + 1] = "\0" .. table.concat(pixels, "", y * width + 1, (y + 1) * width)
    checkpoint(width)
  end
  local png = "\137PNG\13\10\26\10"
    .. chunk("IHDR", string.pack(">I4I4BBBBB", width, height, 8, 6, 0, 0, 0), checkpoint)
    .. chunk("IDAT", deflate(table.concat(rows), checkpoint), checkpoint) .. chunk("IEND", "", checkpoint)
  return "/opensb_data;bin;" .. base64(png, checkpoint)
end
