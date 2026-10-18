## Bugfixes
Fixed a rare carsh on deleting messages.

## Features
Added the humanoidParameters command preview.
Added the media plugin for embedded GIFs, images and audio, with configurable size and duration limits, localized validation before sending, and Play/Stop controls.
Added embedded image support for custom portraits, frames, and stickers on supported OpenStarbound versions.
Added embedded audio support for custom character voice sounds on supported OpenStarbound versions.

## API
Added optional imageScale for message images and imageRect in onDrawMessage for image interactions.
Added onChatClose for plugins that need to clean up before the chat is hidden.
