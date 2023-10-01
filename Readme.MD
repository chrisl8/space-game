You can play the game right now at https://voidshipephemeral.space

# Space Game - A 3D Online Space

It is closer to a "doll house" than a game at the moment.  
There isn't really much here yet, but you can see it all live.  I will continue to deploy my work as I expand it.  
All the source is MIT licensed, so you can use this to help make your own game and copy code as much as you like.

# Play the Game Now!

Go to https://voidshipephemeral.space where the game is up and running live now.  
This is the preferred method.

## Binary Releases
There is no reason to use these, as the website above is the primary target release and should always work, but if you want to download the game and run it locally, you can:

[Download the latest Windows Binary Release Here](https://voidshipephemeral.space/release/Space-Game-Windows-Binary.zip)  
or  
[Download the latest Linux Binary Release Here](https://voidshipephemeral.space/release/Space-Game-Linux-Binary.tar.gz)  

You will probably have to tell Windows to allow the binary to run as it is unsigned.  
Use Alt+F4 to close the game if it seems like it won't let you out.  

These releases still connect to and depend on the server.

# About the Code

This is a Godot multi-player "game" (more like a doll house) that uses WebSocket for communication to allow creating a Web build and playing it in a web browser.

## Goals
This is entirely a hobby project for me, with no desire to monetize it, so there is no target for a launch or desire to publish with a big game distributor. I'm just having fun here.

## Target Architecture
My primary target is HTML export, because I find that the best way to get new people to try out my work. It only takes them a few seconds or minutes at most to be in my game and see what is there. It is also super easy for them to come back and see updates.

## Character Controller
The Character Controller is a Rigid Body controller where the user's input all causes physics inputs to the body. This is not the typical way that a character controller works in a 3D game, and has many draw-backs, however it works perfectly for my goals here.  
All of the code for the Character Controller is based on the [FreeFlyFall's RigidBodyController](https://github.com/FreeFlyFall/RigidBodyController) although I have modified it a lot to fit my goals.

## Networking
This code currently uses WebSocket communication to communicate between the clients and the server. I find this to be the most reliable form of networking for HTML clients at the moment.  
In theory WebRTC would be faster and lower latency, but it is highly complex to create connections and my experience is that in Server->Client setup, WebRTC connections silently die consistently after some time.

### OS Native Builds

Native Windows and Linux clients can also connect to the web-based server and interact with web-based players.

### Etc.

There is currently no concept of "lobbies" or "shards." Everyone just joins the same server.

#### WebRTC Experiments
**You do not need to do this!**  
At one time I tried WebRTC, and the WebRTC code still exists, but it is not currently functioning.  
If someone wanted to try using WebRTC, you must make some code changes which are documented at the top of `startup.gd`.  
My experience is that WebRTC connections silently stop sending data after 5 or 10 minutes, rendering players in a "read only" mode with no way to detect or fix it.

# Development

## There Must Always be Two
In the Godot Editor, you must set Debug-> Run Multiple Instances to at least two (2) or more.

When a Debug build (in the Editor) is run, the first instance always automatically sets itself as a Server.

You then must have a second instance to actually play the game in or even see the game play.

## Server Camera

The primary scene has a camera in it that is never seen by players. It is there so that the server instance, as seen when run from the Godot Editor, can have a meaningful view, and you can tell if the server is working and that players are spawning into the server.

## Debug Server

When a Debug build (in the Editor) is run, the code also defaults to using your local host as the Server, which is how the 2nd, 3rd, etc. instances of the game find the first instance and know it is the Server.



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

So the Server will always be an OS Native build, either Windows or Linux should work.

### Server Location in Production
The client has the server URL hard coded.

To make your own instance, you must edit the URL in the code before building.

## Deploy

### Cause a Build to act as a Server
A release build, when run, will assume that it is a client.

You must pass command line arguments to an instance when running it to force it to be a Server.

Use the arguments `--headless -- server` just like that. Be careful with the spacing, as there is a space between `--` and `server` to signify that `server` is being passed into the Godot code, not used by the Godot engine.

The script I use is at `export-helpers\server\run-space-game-server.sh` which is always up-to-date, so use that as an example for running the server. Note that this one us used on Linux, so it has the `.x86_64` extension on the built file, but you can edit the name. The important part is the arguments after the binary name.

If you are running the server on a host with a screen and video card, you do not have to include the `--headless` part. The server will display the camera in the primary scene, which can be interesting and assist with debugging client connections and network interactions.

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

The primary reason for proxying instead of just opening a direct port is that Nginx can now provide SSL for Websocket using the same certificate as the rest of the site.  

Some other important ingredients are:
 - The Cross-Origin- headers that are required.
 - The proxy timeouts are set long so that it doesn't arbitrarily cut us off.
 - There are some lines there to attempt to forward the "real ip" of the client to the Godot Engine, so it can get the IP if it wants to.

This example is not using SSL and is running on port 80, which is how you would start,  
then I suggest using letsencrypt to then set up SSL certificates using certbot.  
https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/

### My Deploy Script
TODO: Copy it into this repo and explain it.

# Help

The best place to get help with Godot in real time is the [Godot Discord Server](https://godotengine.org/community/) because it is fast, live, and there are always many people there who are smarter than me.  

If you would like to ask questions or talk about this code specifically jump over to the Discussions tab at the top and start a new thread. I'll see it and try to respond as soon as I have time. I'm always happy to chat about my code.
