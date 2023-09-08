You can play the game right now at https://voidshipephemeral.space

# Space Game - A 3D Online Space

It is closer to a "doll house" than a game at the moment.  
There isn't really much here yet, but you can see it all live.  I will continue to deploy my work as I expand it.  
All of the source is MIT licensed, so you can use this to help make your own game and copy code as much as you like.

# Play the Game Now!

Go to https://voidshipephemeral.space where the game is up and running live now.  
This is the preferred method.

## Binary Releases
There is no reason to use these, as the web site above is the primary target release and should always work, but if you want to download the game and run it locally, you can:

[Download the latest Windows Binary Release Here](https://voidshipephemeral.space/release/Space-Game-Windows-Binary.zip)  
or  
[Download the latest Linux Binary Release Here](https://voidshipephemeral.space/release/Space-Game-Linux-Binary.tar.gz)  

You will probably have to tell Windows to allow the binary to run as it is unsigned.  
Use Alt+F4 to close the game if it seems like it won't let you out.  

These releases still connect to and depend on the server.

# About the Code

This is a Godot multi-player "game" (more like a doll house) that uses WebRTC for communication to allow creating a Web build and playing it in a web browser.

### WebRTC
https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html

WebRTC requires a "signalling server" for the games instances to find each other, as WebRTC alone has no "listener". This code includes a GDScript Websocket signalling server to allow for the entire project to run in Godot with no external services and no non-Godot dependencies. The Server instance of the game automatically starts the Signalling Server, and the non-server instances connect to it. Only the Server will run the signalling server.

### OS Native Builds

OS Native based clients can also connect to the web based server and interact with web based players.

### Etc.

There is currently no concept of "lobbies" or "shards". Everyone just joins the same server.

# Development

## There Must Always be Two
In the Godot Editor you must set Debug-> Run Multiple Instances to at least two (2) or more.

When a Debug build (in the Editor) is run, the first instance always automatically sets itself as a Server.

You then must have a second instance to actually play the game in or even see the game play.

## Server Camera

The primary scene has a camera in it that is never seen by players. It is there so that the server instance, as seen when run from the Godot Editor, can have a meaningful view and you can tell if the server is working and that players are spawning into the server.

## Debug Server

When a Debug build (in the Editor) is run, the code also defaults to using your local host as the Server, which is how the 2nd, 3rd, etc. instances of the game find the first instance and know it is the Server.



# Production
## Build
### Known errors during build process
 - `ERROR: Index current_edited_scene = -1 is out of bounds (edited_scene.size() = 0).`
 Maybe it will get fixed in 4.2?
 see: https://github.com/godotengine/godot/issues/79944
 and: https://github.com/godotengine/godot/pull/79945

 - `ERROR: Viewport Texture must be set to use it.`
 see:  https://github.com/godotengine/godot/issues/66247

### OS Native and Web
To deploy you **must** build at least one OS Native build as the browser based Web version cannot host the Signalling Server.

So the Server will always be an OS Native build, either Windows or Linux should work.

### Server Location in Production
The client has the server URL hard coded.

To make your own instance you must edit the URL in the code before building.

## Deploy

### Cause a Build to act as a Server
A release build, when run, will assume that it is a client.

You must pass command line arguments to an instance when running it to force it to be a Server.

Use the arguments `--headless -- server` just like that. Be careful with the spacing, as there is a space between `--` and `server` to signify that `server` is being passed into the Godot code, not used by the Godot engine.

The script I use is at `export-helpers\server\run-space-game-server.sh` which is always up to date, so use that as an example for running the server. Note that this one us used on Linux, so it has the `.x86_64` extension on the built file, but you can edit the name. The important part is the arguments after the binary name.

If you are running the server on a host with a screen and video card, you do not have to include the `--headless` part. The server will display the camera in the primary scene, which can be interesting and assist with debugging client connections and network interactions.

### Nginx Setup
TODO: Document this.

### My Deploy Script
TODO: Copy it into this repo and explain it.