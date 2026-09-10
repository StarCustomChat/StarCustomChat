

function starcustomchat.utils.clearNick(nick)
  return string.gsub(nick, "%^#?%w+;", "")
end

function starcustomchat.utils.clearMetatags(text)
  return text:gsub("%^.-;", "")
end

function starcustomchat.utils.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1") 
end

function starcustomchat.utils.cropMessage(text, trimLength)
  return utf8.len(text) < trimLength and text or starcustomchat.utils.utf8Substring(text, 1, trimLength) .. "..."
end

function starcustomchat.utils.utf8Substring(inputString, startPos, endPos)
    -- Check if startPos is within the valid range
  startPos = math.min(startPos, endPos)
  
  endPos = math.min(endPos, utf8.len(inputString))

  -- Calculate the byte offsets for the start and end positions
  local byteStart = utf8.offset(inputString, startPos)
  local byteEnd = utf8.offset(inputString, endPos + 1) - 1

  -- Extract the substring
  local result = string.sub(inputString, byteStart, byteEnd)

  return result
end