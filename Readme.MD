# Spaceship Game

This is a Godot multi-player "game" (more like a doll house) that uses WebRTC for communication to allow deploying it to HTML and playing it in a web browser.

Note that WebRTC requires a Websocket (or other) "signalling server". This code includes a GDScript based signalling server to allow for the entire project to run in Godot with no external services. Only the Server will run the signalling server.

OS Native based clients can also connect to the web based server and interact with web based players.

There is currently no concept of "lobbies" or "shards". Everyone just joins the same server.

## Known errors during build process
 - `ERROR: Index current_edited_scene = -1 is out of bounds (edited_scene.size() = 0).`
 Maybe it will get fixed in 4.2?
 see: https://github.com/godotengine/godot/issues/79944
 and: https://github.com/godotengine/godot/pull/79945

 - `ERROR: Viewport Texture must be set to use it.`
 see:  https://github.com/godotengine/godot/issues/66247
