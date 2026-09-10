# Custom chat
Starbound mod for replacing an old and boring chat with a flashy new and customazible piece of experience.
Brought to you with love by Degranon


# Functionality

Custom chat provides you with several in-built functions like these:

 - Localization: currently supports English and Russian languages
 - Two Discord inspired modes: full and compact
 - Quick and easy DM tab
 - Collapsing of long messages
 - Ability to copy messages
 - Message channel filtration
 - Command autofill (press **TAB** to scroll through)
 - Plugin system that allows you to expand the functionality even more!
![Full avatar mode](https://i.imgur.com/yLO8qWg.png)
![Short mode with disabled commands showcase](https://i.imgur.com/oXtXDp7.png)
# Prerequirements
This mod requires [OpenStarbound](https://github.com/OpenStarbound/OpenStarbound) 0.1.8+.

# Controls

 - **Mousewheel**: scroll chat up / down
 - **Ctrl** + **Mousewheel**: change font size
 - **Shift** + **Mousewheel**: scroll up / down twice as fast
 - **Alt** + **Up**/**Down**: scroll through last sent messages
 - **P** (default, change in /binds): repeat last command

# Plugins
The base mod already includes several plugins within. They are disabled by default and require patching the **/scripts/starcustomchat/enabledplugins.json** file. For example:

    [  {"op": "add", "path": "/-", "value": "oocchat" },   { "op": "add", "path": "/-", "value": "proximitychat" } ]
If you want to create your own plugins - which I strongly recommend you to do! - you can look at the configuration there.


### Stagehand configuration

#### Patch files
Several plugins can benefit from creating a server-side stagehand to log the messages, change them, filter etc etc.

First, you need to create a server-specific patch for your own server and distribute it among your players. The patch could be a simple mod that has patch files like the following:

| Plugin                  | Patch Path                                                                        | Stagehand Message Type Data | Player Message Handler |
|-------------------------|-----------------------------------------------------------------------------------|-----------------------------|------------------------|
| Edit Message (SCCRRP)   | /interface/scripted/starcustomchat/plugins/editmessage/editmessage.json.patch     | editMessage                 | scc_edit_message       |
| Proximity Chat (SCCRRP) | /interface/scripted/starcustomchat/plugins/proximitychat/proximitychat.json.patch | sendProxyMessage            | scc_add_message        |
| Reactions               | /interface/scripted/starcustomchat/plugins/reactions/reactions.json.patch         | addReaction                 | scc_add_reaction       |
| Reply                   | /interface/scripted/starcustomchat/plugins/reply/reply.json.patch                 | addReply                    | scc_add_relpy          |
| Stickers                | /interface/scripted/starcustomchat/plugins/stickers/stickers.json.patch           | sendSticker                 | scc_add_message        |
| Languages               | /interface/scripted/starcustomchat/plugins/languages/languages.json               | retrieveLanguages           | scc_rp_languages       |

*The language file may now include a `transformation` section with a rules
list, allowing servers to finely control how text degrades as characters
learn a language.*

The contains of the patch files are identical:

```diff
[
  { "op": "replace", "path": "/parameters/stagehandType", "value": "STAGEHAND_NAME"}
]
```

#### Stagehand scripts

Since we only want to send the data and forgive about it, there's no need to spawn a long-living stagehand. Instead, we create a new stagehand with some data in its config.
For example, when we send the proximity chat message, we create a new stagehand with `stagehandType` type and the following data:

```json
{
  "message": "sendProxyMessage",
  "data": {
    "proximityRadius": "<Proximity radius set by the user>",
    "time": "<Planet time>",
    // Common message data
  }
}
```

Each `message` sent to the stagehand usually means that we'll hope that the stagehand will send us the entity message described in the far right column of the table above - and then die, since it's done its purpose. For example:

```lua
function init()
  local purpose = config.getParameter("message")
  local data = config.getParameter("data")

  if purpose == "sendProxyMessage" then
    logProximityMessage()
    sendProximityMessage(data, data.proximityRadius)
  elseif

    -- All the other stuff
  end
  stagehand.die() -- We don't need it anymore
end
```

In order for the plugins to understand that this stagehand supports their message, the following code must be enabled on the SH:
```lua
if purpose == "requestHandlers" then
  if data and data.playerId then
    world.sendEntityMessage(data.playerId, "scc_stagehand_allowed_messages", {"here", "is", "a", "list", "of", "supported", "messages"})
    stagehand.die()
  end
end
```

Since SCC 2.0.0, the servers can also pass the command list in the format of `commands.config` to the client. For that, the stagehand parameter should be described in the plugin (see above).

```lua
if purpose == "requestCommands" then
  if data and data.playerId and world.entityExists(data.playerId) then
    world.sendEntityMessage(data.playerId, "scc_stagehand_commandlist", {
      { command = "/myNewCommand", description = "New server command" },
      { command = "/compoundCommand", description = "Main command", subcommands = {
        option1, option2
      } }
    }, "MyNewPlugin") -- The name of the plugin is optional.
    stagehand.die()
  end
end
```

# External support

If you don't want to create a whole plugin just to bring some commands to the preview, you can create a custom file with the `.starcustomchat.commands` extention wherever in your mod. The sytax for the commands is the same:

```json
[
  { 
    "command": "/myFirstCustomCommands", 
    "description": "Some description", 
    "subcommands": [
      "option1", "option2", "option3", {
          "command": "chest",
          "description": "Subcommand description",
          "subcommands": ["suboption1", "suboption2", "suboption3"]
      }
    ] 
  }
]
```

# Contributors

* @Degranon - main author
* @Novaenia - OpenStarbound support
* @FezzedOne - xStarbound suppport

## Localization

* @degranon - Russian
* @hansby - Spanish
* @hydra_idryliah - French
* @helgo - German
* @crviii - Dutch
* @masorad - Italian
* @muro_o - Portuguese (Brazilian)
* @ifanel - Ukrainian
* @fragcunt - Polish
* @storyshifty - Belarus

# Contact me
If you have bug reports, suggestions or other ideas, you can contact me on Discord (@Degranon) or join [my Discord server](https://discord.gg/gnu8xRjS9p)
