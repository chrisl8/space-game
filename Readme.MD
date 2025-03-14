You can play the game right now at [https://voidshipephemeral.space](https://voidshipephemeral.space)

# Space Game - A 3D Online Space

It is closer to a "doll house" than a game at the moment.  
There isn't really much here yet, but you can see it all live.  I will continue to deploy my work as I expand it.  
All the source is MIT licensed, so you can use this to help make your own game and copy code as much as you like.

# Play the Game Now!

Go to [https://voidshipephemeral.space](https://voidshipephemeral.space) where the game is up and running live now!  
This is the preferred method to play the game.

## Binary Releases
The website above is the primary target release and should always work, but these local binary builds will provide higher quality rendering and a better input experience if you want to try them:

[Download the latest Windows Binary Release Here](https://voidshipephemeral.space/release/space-game-Windows-Binary.zip)  
or  
[Download the latest Linux Binary Release Here](https://voidshipephemeral.space/release/space-game-Linux-Binary.tar.gz)  
or  
[Download the latest MacOS Binary Release Here](https://voidshipephemeral.space/release/space-game-MacOS-Binary.dmg)  

You will probably have to tell Windows to allow the binary to run as it is unsigned.  

Press the "Esc" key to free your mouse from the window.

In Windows use Alt+F4 to close the game if it seems like it won't let you out.  

These releases still connect to and depend on the server. You will be part of the same multiplayer game as web connected clients, but with the "benefit" of running a native client on your computer instead of running it inside of a browser.

# About the Code

This is a Godot multi-player "game" (more like a doll house) that uses WebSocket for communication to allow creating a Web build and playing it in a web browser.

## Goals
This is entirely a hobby project for me, with no desire to monetize it, so there is no target for a launch or desire to publish with a big game distributor. I'm just having fun here.

## Target Architecture
My primary target is HTML export, because I find that the best way to get new people to try out my work. It only takes them a few seconds or minutes at most to be in my game and see what is there. It is also super easy for them to come back and see updates.

## Character Controller
The Character Controller is a Rigid Body controller where the user's input all causes physics inputs to the body. This is not the typical way that a character controller works in a 3D game, and has many draw-backs, however it works perfectly for my goals here.  
The code for the Character Controller is based on the [FreeFlyFall's RigidBodyController](https://github.com/FreeFlyFall/RigidBodyController) although I have modified it a lot to fit my goals.

## Networking
This code currently uses WebSocket communication to communicate between the clients and the server. I find this to be the most reliable form of networking for HTML clients at the moment.  
In theory WebRTC would be faster and lower latency, but it is highly complex to create connections and my experience is that in Server->Client setup, WebRTC connections silently die consistently after some time.

### OS Native Builds

Native Windows and Linux clients can also connect to the web-based server and interact with web-based players.

### Etc.

There is currently no concept of "lobbies" or "shards." Everyone just joins the same server.

# Development

## Godot Version

I am using Godot 4.2 at the moment, but whatever is listed in `projects.godot` is clearly the correct one.

## There Must Always be Two
In the Godot Editor, you must set Debug-> Run Multiple Instances to at least two (2) or more.

When a Debug build (in the Editor) is run, the first instance always automatically sets itself as a Server.

You then must have a second instance to actually play the game in or even see the game play.

## Server Camera

The primary scene has a camera in it that is never seen by players. It is there so that the server instance, as seen when run from the Godot Editor, can have a meaningful view, and you can tell if the server is working and that players are spawning into the server.

## Debug Server

When a Debug build (in the Editor) is run, the code also defaults to using your local host as the Server, which is how the 2nd, 3rd, etc. instances of the game find the first instance and know it is the Server.

## DebugDraw

You may see some commented out calls to `DebugDraw3D` in my code.  
[DebugDraw](https://github.com/DmitriySalnikov/godot_debug_draw_3d) is an amazing tool for debugging, but I didn't want it cluttering up my repo or releases.  
If you want to use `DebugDraw3D` yourself during debugging you will have to download it yourself.

 - Go to https://github.com/DmitriySalnikov/godot_debug_draw_3d/releases and download the latest release
 - Unzip it somewhere
 - Place the **contents** if the `addons` folder (named `debug_draw_3d`) into the `addons` folder of this game

 Now you will be able to use the `DebugDraw3D` commands during development and debugging.  

 Be aware that if you attempt to build a Web release with any `DebugDraw3D` calls still in the code it will probably fail. This shouldn't affect debugging or platform native builds though.  
 Comment out any `DebugDraw3D` calls before committing code and before making production builds.


# Production
## Build
### Known errors during build
 - `ERROR: Index current_edited_scene = -1 is out of bounds (edited_scene.size() = 0).`
 Maybe it will get fixed in 4.2?
 see: https://github.com/godotengine/godot/issues/79944
 and: https://github.com/godotengine/godot/pull/79945

 - `ERROR: Viewport Texture must be set to use it.`
 see:  https://github.com/godotengine/godot/issues/66247

### OS Native and Web
To deploy, you **must** build at least one OS Native build as the browser-based Web version cannot host the Server.

So the Server will always be an OS Native build, either Windows or Linux works fine.

### Server Location in Production
The client has the server URL hard coded.

To make your own instance, you must edit the URL in the code before building.

## Deploy

### Cause a Build to act as a Server
A release build, when run, will assume that it is a client.

You must pass command line arguments to an instance when running it to force it to be a Server.

Use the arguments `--headless -- server` just like that. Be careful with the spacing, as there is a space between `--` and `server` to signify that `server` is being passed into the Godot code, not used by the Godot engine.

The script I use is at `export-helpers\server\run-server.sh` which is always up-to-date, so use that as an example for running the server. Note that this one us used on Linux, so it has the `.x86_64` extension on the built file, but you can edit the name. The important part is the arguments after the binary name.

If you are running the server on a host with a screen and video card, you do not have to include the `--headless` part. The server will display the camera in the primary scene, which can be interesting and assist with debugging client connections and network interactions.

Note that there is absolutely no difference between a server and a client build or the code. Every client can in theory be a server. Only these command line arguments cause an instance to take on the server role.

### Nginx Setup
You need to serve the files up via a web server to allow users to download and run the game in the browser.  
You also need to open up the server's websocket listener to the network.  

I typically do both of these with Nginx on a Digital Ocean droplet.  

Here is my nginx config:
```
server {
    root /home/chrisl8/space-game/web;
    server_name voidshipephemeral.space;

    location ~* .(png|ico|gif|jpg|jpeg|css|js|html|webmanifest|map|mp3|ogg|svg|xml|pck|wasm)$ {
      try_files $uri $uri/ =404;
      add_header 'Cross-Origin-Opener-Policy' 'same-origin';
      add_header 'Cross-Origin-Embedder-Policy' 'require-corp';
    }

    location /server/ {
        proxy_pass http://localhost:9090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-NginX-Proxy true;
        proxy_ssl_session_reuse off;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    listen 80;
    listen [::]:80;
}
```

Note that the game itself, the server instance, must be running on the same server as Nginx and listening on port 9090 (which is also hard coded in the code at the moment).

Notice that it is serving a list of file types directly if you ask for them, so it will respond to requests for the files users need.  
Then notice that if someone goes to /server/ it proxies their connection to the local 9090 port that your Godot game instance runs on.  

The primary reason for proxying instead of just opening a direct port is that Nginx can now provide a secure SSL connection for Websocket using the same certificate as the rest of the site. Web browsers get cranky if you do not use SSL or if you try to connect to a non-SSL Websocket from an HTTPS loaded site. 

Some other important ingredients are:
 - The Cross-Origin- headers that are required.
 - The proxy timeouts are set long so that it doesn't arbitrarily cut us off.
 - There are some lines there to attempt to forward the "real ip" of the client to the Godot Engine, so it can get the IP if it wants to.

This example is not using SSL and is running on port 80, which is how you would start,  
then I suggest using letsencrypt to then set up SSL certificates using certbot.  
https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/

### My Deploy Script

Under `export-helpers` there is a script called `deployGame.sh` which I use for deploying this game to my server.  
I've included it in this repository in case it may be useful as an example to others for how to run Godot to build games from a script and various tidbits on how to package up games for deploying on the web.  
It is necessarily somewhat custom to my use case, but it does use command line parameters for all of the personal settings, so anyone can use it.  
Run the script with no parameters, or look at the top of it to see how to use it.  

There are also other scripts in folders under `export-helpers` that are used for various deploy tasks.  
`run-server.sh` - Runs the server.
`restart-server.sh` - Runs the game with a special command line that tells it to call the server and ask it to shut down gracefully.

# Help

The best place to get help with Godot in real time is the [Godot Discord Server](https://godotengine.org/community/) because it is fast, live, and there are always many people there who are smarter than me.  

If you would like to ask questions or talk about this code specifically jump over to the [Discussions](https://github.com/chrisl8/space-game/discussions) tab at the top and start a new thread. I'll see it and try to respond as soon as I have time. I'm always happy to chat about my code.

# Attributions
Doctor Who Script excerpts from http://www.chakoteya.net/DoctorWho/
