## Bugfixes
Fixed hightlighting messages when the cursor is not at the chat pane.
Fixed the portraits not being requested on join.
Fixed the DM character icon being misplaced if sprites are not 43x43.
Moved the language button in settings lower in z level.
Cleaned up the Fonts layouts.
Fixed the avatar preview not encapsulating the whole avatar
Fixed the command preview layout overlapping with the submenu.
Fixed the commands from one mod overriding the other one.
Fixed the 'edited' label always showing up as '???' if SCCRP is not installed.
Fixed the pgUp/pgDown and react chatArea scrolling not being consistent.
Fixed the context menu popping up when the cursor is not actually within.
Fixed the duplicating of entries for messages that are sent from chat history.
Changed the notification of the ping to show the displayName instead of the actual nickname.
Fixed the exploit of spamming the reactions by changing your name.
Fixed the chat not showing the whole first message if it's too long.
Changed the pinged functionality - it now uses the entityId, not the player name.
Fixed the whisper messages to different people being merged into one block (not drawing the avatar and nickname).

## Features
MULTILINE TEXTBOX!! Thanks D.
CHAT RESIZING.
Added the /filter command to filter the messages in the chat by text or nickname.
CommandPreview now enlarges to fit the longer descriptions.
Deleted BiggerChat.
Added the emojies window (left menu button).
The sent messages are now trimmed from the beginning and the end. Does not remove spaces in between.
Last message scroll is now triggered by Alt + Up/Down.
Smoothed out the change of the chat size.
Font names are now sorted by name.
Added the /afk command. Does the same as the corresponding button.
CharacterVoice: Added volume slider.
CharacterVoice: The sounds are now picked from the list of all the sounds.
CharacterVoice: Added the ability to pick up to three Custom sounds.
ModeSounds: The sounds are now picked from the list of all the sounds.
Reacts added: gem, 100.
Added Belarus language support - thank you, Ender!
Added the typing indicator.
Moved the server messages to "CommandResult" mode.

## API
New functions to set, get text and focus of the input textbox.
New plugin method for editting the messages.
New method to parse the input events.
Moved the settings images to a separate folder.
The server can now pass a list of its supported commands dynamically.
Moved the images around internally.
New callback hooks for widgets. Useful when one widget can contain multiple callbacks (i.e. textbox)
New method to resolve the player names and data. Useful when you want to change their names in DM tab etc
New callbacks for calculating the message height and drawing the message in the queue.
New callback to set the dots showing up above the character.