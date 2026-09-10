-- This function dinamically builds the chat interfaces based on the enabled and disabled modes

require "/scripts/util.lua"

function safeAssetJson(path)
  if root and root.assetJson then
    return root.assetJson(path)
  else
    -- OSB
    return assets.json(path)
  end
end

function safeImageSize(path)
  if root and root.imageSize then
    return root.imageSize(path)
  else
    -- OSB
    return assets.image(path):size()
  end
end

function getConfiguration(key)
  if root and root.getConfiguration then
    return root.getConfiguration(key)
  else
    return nil -- OSB does not have it yet
  end
end

function buildChatInterface()

  local function sortByPriority(tbl)
    table.sort(tbl, function(a, b) 
      local a_priority = a.priority or 999999
      local b_priority = b.priority or 999999
      return a_priority < b_priority
    end)
  end


  local baseInterface = safeAssetJson("/interface/scripted/starcustomchat/base/chatgui.json")
  local enabledPlugins = safeAssetJson("/scripts/starcustomchat/enabledplugins.json")
  local disabledModes = safeAssetJson("/scripts/starcustomchat/disabledmodes.json")

  -- Special case: calculate colors
  local defaultColors = safeAssetJson("/interface/scripted/starcustomchat/plugins/colors/colors.json")["parameters"]["items"]

  -- First, collect all the modes from the plugins
  local chatModes = {}
  baseInterface["chatModes"] = {}
  baseInterface["contextMenuButtons"] = {}
  baseInterface["enabledPlugins"] = {}
  baseInterface["defaultColors"] = {}
  for _, color in ipairs(defaultColors) do 
    baseInterface.defaultColors[color.name] = color.default
  end

  local leftMenuButtonPosition = {0, 0}

  for _, pluginName in ipairs(enabledPlugins) do 
    local pluginConfig = safeAssetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))
    table.insert(baseInterface["enabledPlugins"], pluginName)
    
    if pluginConfig.modes then
      for _, mode in ipairs(pluginConfig.modes) do
        if not disabledModes[mode.name] then
          table.insert(baseInterface["chatModes"], mode.name)
          table.insert(chatModes, mode)
        end
      end
    end

    if pluginConfig.contextMenuButtons then
      for _, btnConfig in ipairs(pluginConfig.contextMenuButtons) do
        table.insert(baseInterface["contextMenuButtons"], btnConfig)
      end
    end

    if pluginConfig.guiAddons then
      baseInterface["gui"] = sb.jsonMerge(baseInterface["gui"], pluginConfig.guiAddons)
    end

    for _, btnConfig in ipairs(pluginConfig.leftMenuButtons or {}) do
      btnConfig.type = "button"
      btnConfig.position = copy(leftMenuButtonPosition)
      baseInterface["gui"]["lytLeftMenu"]["children"]["saButtons"]["children"][btnConfig.name] = btnConfig
      leftMenuButtonPosition[2] = leftMenuButtonPosition[2] - 12
    end

    -- Fetching the default colors from the settings
    if pluginConfig.settingsPluginAddons then
      for basePlugName, newConfig in pairs(pluginConfig.settingsPluginAddons) do 
        if contains(enabledPlugins, basePlugName) and basePlugName == "colors" then
          for _, item in ipairs(newConfig["items"] or {}) do 
            baseInterface["defaultColors"][item.name] = item.default
          end
        end
      end
    end
  end

  -- Then sort the modes by tab priority
  sortByPriority(chatModes)

  -- Sort context menu items
  sortByPriority(baseInterface["contextMenuButtons"])

  -- Then add the modes to the radio group
  local tab_id = 1
  local toggle_id = 1

  local function modesThatHaveTabs(modes)
    local n = 0
    for _, mode in ipairs(modes) do 
      n = mode.has_tab and n + 1 or n 
    end
    return n 
  end

  local totalNModes = modesThatHaveTabs(chatModes)
  local tabWidth = safeImageSize("/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png")[1]

  for _, mode in ipairs(chatModes) do
    if mode.has_tab then
      table.insert(baseInterface["gui"]["rgChatMode"]["buttons"], {
        id = tab_id,
        baseImage = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png",
        hoverImage = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmode.png?brightness=30",
        baseImageChecked = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmodeselected.png",
        hoverImageChecked = "/interface/scripted/starcustomchat/base/images/tabmodes/chatmodeselected.png?brightness=30",
        pressedOffset = {0, 0},
        position = {(tab_id - 1) * tabWidth, 0},
        selected = tab_id == 1,
        data = {
          mode = mode.name,
          admin = mode.admin
        }
      })
      tab_id = tab_id + 1
    end

    if mode.has_toggle then
      local checked = true
      if mode.checked ~= nil then
          checked = mode.checked
      end

    
      baseInterface["gui"]["lytModeFilter"]["children"]["btnCk" .. mode.name] = {
        type = "button",
        checkable = true,
        checked = checked,
        position = {0, 15 * (toggle_id - 1)},
        pressedOffset = {0, 0},
        base = "/interface/scripted/starcustomchat/base/images/chatmode/chatmode.png:disabled",
        hover = "/interface/scripted/starcustomchat/base/images/chatmode/chatmode.png:disabled",
        baseImageChecked = "/interface/scripted/starcustomchat/base/images/chatmode/chatmode.png:enabled",
        hoverImageChecked = "/interface/scripted/starcustomchat/base/images/chatmode/chatmode.png:enabled",
        callback = "modeToggle",
        data = {
          mode = mode.name,
          tooltipMode = mode.name
        }
      }
      toggle_id = toggle_id + 1
    end

    baseInterface["gui"]["lytModeFilter"].size = {16, 16 * toggle_id}
  end
  return baseInterface
end

local function is_array(t)
  -- Simple check to guess if a table is being used as an array.
  -- This checks if the first key is an integer.
  -- It's a naive check but works for simple JSON arrays.
  local k, _ = next(t)
  return type(k) == "number"
end

function merge_json(t1, t2)
  if is_array(t1) and is_array(t2) then
      -- If both are arrays, concatenate them
      for _, v in ipairs(t2) do
          table.insert(t1, v)
      end
  elseif not is_array(t1) and not is_array(t2) then
      -- If both are objects, merge them
      for k, v in pairs(t2) do
          if type(v) == "table" and type(t1[k]) == "table" then
              -- Recursively merge tables
              merge_json(t1[k], v)
          else
              -- Set or overwrite the value
              t1[k] = v
          end
      end
  else
      -- If one is an array and the other is an object, this is an error
      error("Cannot merge an array with an object")
  end
  return t1
end


function buildSettingsInterface()
  local function mergeArrays(t1, t2)
    if t2 == nil then return t1 end
    for _,v in ipairs(t2) do 
      table.insert(t1, v)
    end
    return t1
  end

  local baseSettingsInterface = safeAssetJson("/interface/scripted/starcustomchatsettings/starcustomchatsettingsgui.json")

  local enabledPlugins = safeAssetJson("/scripts/starcustomchat/enabledplugins.json")

  local spinnerNames = {}
  baseSettingsInterface["translations"] = jarray()
  baseSettingsInterface["hintTranslations"] = jarray()


  for i, pluginName in ipairs(enabledPlugins) do 
    local pluginConfig = safeAssetJson(string.format("/interface/scripted/starcustomchat/plugins/%s/%s.json", pluginName, pluginName))

    if pluginConfig.settingsPage then
      local layoutWidget = {
        type = "layout",
        layoutType = "basic",
        rect = {0, 0, 500, 500},
        children = {},
        visible = i == 1
      }

      baseSettingsInterface["gui"]["lytPluginSettings"]["children"][pluginName] = copy(layoutWidget)
      local layout = baseSettingsInterface["gui"]["lytPluginSettings"]["children"][pluginName]

      layout["data"] = {
        pluginName = pluginName,
        priority = pluginConfig.settingsPage["priority"] or 99,
        base = pluginConfig.settingsPage["tabButtons"]["baseImage"],
        hover = pluginConfig.settingsPage["tabButtons"]["hoverImage"],
        baseImageChecked = pluginConfig.settingsPage["tabButtons"]["baseImageChecked"],
        hoverImageChecked = pluginConfig.settingsPage["tabButtons"]["hoverImageChecked"],
      }

      local function processWidgets(widgets, targetTable, pathPrefix)
        for widgetName, widgetConfig in pairs(widgets or {}) do
          local fullWidgetPath = pathPrefix .. "." .. widgetName

          if widgetConfig.translationKey then
            table.insert(baseSettingsInterface["translations"], {
              widget = fullWidgetPath,
              key = widgetConfig.translationKey
            })
          end

          if widgetConfig.hintTranslationKey then
            table.insert(baseSettingsInterface["hintTranslations"], {
              widget = fullWidgetPath,
              key = widgetConfig.hintTranslationKey
            })
          end

          -- Spinner, textbox, etc. processing remains the same...
          if widgetConfig.type == "spinner" then
            local callbackName = widgetConfig.callback or widgetName
            table.insert(spinnerNames, fullWidgetPath)
            widgetConfig.data = sb.jsonMerge(widgetConfig.data or {}, {
              actualPluginCallback = {
                pluginName = pluginName,
                callback = callbackName
              }
            })
            widgetConfig.callback = "_generalSpinnerCallback"
          elseif widgetConfig.type == "radioGroup" then
            for i, btn in ipairs(widgetConfig.buttons) do
              widgetConfig.buttons[i].data = sb.jsonMerge(btn.data or {}, {
                actualPluginCallback = {
                  pluginName = pluginName,
                  callback = widgetConfig.callback
                }
              })
            end
            widgetConfig.callback = "_generalCallback"
          elseif widgetConfig.callback and widgetConfig.callback ~= "null" then
            widgetConfig.data = sb.jsonMerge(widgetConfig.data or {}, {
              actualPluginCallback = {
                pluginName = pluginName,
                callback = widgetConfig.callback
              }
            })
            widgetConfig.callback = "_generalCallback"
          elseif widgetConfig.type == "canvas" and widgetConfig.captureMouseEvents then
            baseSettingsInterface["canvasClickCallbacks"][widgetName] = "_generalCanvasClick"
          elseif widgetConfig.type == "textbox" then
            widgetConfig.data = sb.jsonMerge(widgetConfig.data or {}, {
              actualPluginCallback = {
                pluginName = pluginName,
                callback = widgetConfig.callback ~= "null" and widgetConfig.callback or nil,
                enterKey = widgetConfig.enterKey,
                escapeKey = widgetConfig.escapeKey
              }
            })
            widgetConfig.callback = "_generalTextBoxCallback"
            widgetConfig.enterKey = "_generalTextBoxCallbackEnter"
            widgetConfig.escapeKey = "_generalTextBoxCallbackEscape"
          end

          targetTable[widgetName] = widgetConfig

          -- Recurse if this widget has children
          if widgetConfig.children then
            processWidgets(widgetConfig.children, widgetConfig.children, fullWidgetPath)
          end
        end
      end

    
      -- Initial call to process the top-level widgets
      processWidgets(pluginConfig.settingsPage["gui"], layout["children"], "lytPluginSettings." .. pluginName)
    end

    if pluginConfig.parameters then
      baseSettingsInterface["pluginParameters"][pluginName] = sb.jsonMerge(baseSettingsInterface["pluginParameters"][pluginName], pluginConfig.parameters)
    end

    if pluginConfig.settingsPluginAddons then
      for basePlugName, newConfig in pairs(pluginConfig.settingsPluginAddons) do 
        if contains(enabledPlugins, basePlugName) then
          baseSettingsInterface["pluginParameters"][basePlugName] = merge_json(baseSettingsInterface["pluginParameters"][basePlugName], newConfig)
        end
      end
    end
  end

  baseSettingsInterface["spinnerNames"] = copy(spinnerNames)
  return baseSettingsInterface
end