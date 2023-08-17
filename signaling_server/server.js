/* eslint-disable max-classes-per-file,camelcase */
/* eslint-disable no-param-reassign */
import crypto from 'crypto';
import { WebSocketServer } from 'ws';

const MAX_PEERS = 4096;
const MAX_LOBBIES = 1024;
const PORT = process.env.PORT || 9080;

const ALFNUM = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

const PING_INTERVAL = 10000;

const STR_HOST_DISCONNECTED = 'Room host has disconnected';
const STR_TOO_MANY_LOBBIES = 'Too many lobbies open, disconnecting';
const STR_LOBBY_DOES_NOT_EXISTS = 'Lobby does not exists';
const STR_LOBBY_IS_SEALED = 'Lobby is sealed';
const STR_INVALID_FORMAT = 'Invalid message format';
const STR_NEED_LOBBY = 'Invalid message when not in a lobby';
const STR_SERVER_ERROR = 'Server error, lobby not found';
const STR_INVALID_CMD = 'Invalid command';
const STR_TOO_MANY_PEERS = 'Too many peers connected';
const STR_INVALID_TRANSFER_MODE = 'Invalid transfer mode, must be text';

const CMD = {
  USER_INFO: 0,
  LOBBY_LIST: 1, // eslint-disable-line sort-keys
  PEER_CONNECT: 2, // eslint-disable-line sort-keys
  JOIN_LOBBY: 3, // eslint-disable-line sort-keys
  LEFT_LOBBY: 4,
  // PEER_DISCONNECT: 3, // eslint-disable-line sort-keys
  // OFFER: 4, // eslint-disable-line sort-keys
  CANDIDATE: 6, // eslint-disable-line sort-keys
  OFFER: 7,
  ANSWER: 8, // eslint-disable-line sort-keys
  ICE: 9,
  // SEAL: 7, // eslint-disable-line sort-keys
  GAME_STARTING: 10,
  HOST: 11,
  PING: 12,
  PONG: 13,
  SERVER: 14,
};

// TODO: Put this in a config file.
const serverPassword = 'CCppcqEB8qyv4CF8osuftzpCISuovk6R';
// TODO: Get this from the peer data directly?
let serverPeerInfo = {};

// We only keep one lobby, because we only have one server. This could change.
let theLobbyName = '';
// TODO: Currently we just join anyone to this lobby, but we should send them this name,
//       and have them join it, so they could in theory join a different one.

function randomInt(low, high) {
  return Math.floor(Math.random() * (high - low + 1) + low);
}

function randomId() {
  // must be between 1 and 2147483647
  // https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html#class-webrtcmultiplayerpeer-method-create-mesh
  return Math.abs(new Int32Array(crypto.randomBytes(4).buffer)[0]);
}

function randomSecret() {
  let out = '';
  for (let i = 0; i < 16; i++) {
    out += ALFNUM[randomInt(0, ALFNUM.length - 1)];
  }
  return out;
}

function ProtoMessage(type, id, data) {
  // For debugging:
  // console.log(`Sending ${JSON.stringify({
  // 	'type': type,
  // 	'id': id,
  // 	'data': data || '',
  // })}`);
  return JSON.stringify({
    type,
    id,
    data: data || '',
  });
}

const wss = new WebSocketServer({ port: PORT });

console.log(`Websocket Server listening on port ${PORT}`);

class ProtoError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

class Peer {
  constructor(id, ws) {
    this.id = id;
    this.ws = ws;
    this.lobby = '';
    // Close connection after 1 sec if client has not joined a lobby
    // TODO: Should I put this back?
    // this.timeout = setTimeout(() => {
    // 	if (!this.lobby) {
    // 		ws.close(4000, STR_NO_LOBBY);
    // 	}
    // }, NO_LOBBY_TIMEOUT);
  }
}

class Lobby {
  constructor(name, host, mesh) {
    this.name = name;
    this.host = host;
    this.mesh = mesh;
    this.peers = [];
    this.sealed = false;
    this.closeTimer = -1;
    this.gameInProgress = false;
  }

  flagGameStarted() {
    this.gameInProgress = true;
  }

  join(peer) {
    peer.lobby = this.name;
    // const assigned = this.getPeerId(peer);
    // Tell them who the host is
    peer.ws.send(
      ProtoMessage(CMD.HOST, serverPeerInfo.id, serverPeerInfo.user_name),
    );
    // peer.ws.send(ProtoMessage(CMD.ID, assigned, this.mesh ? 'true' : ''));
    peer.ws.send(ProtoMessage(CMD.JOIN_LOBBY, 0, `LOBBY_NAME${this.name}`));
    // TODO: Loop over lobby users and send them all to each other like so:
    this.peers.forEach((p) => {
      p.ws.send(
        ProtoMessage(
          CMD.JOIN_LOBBY,
          peer.id,
          `NEW_JOINED_USER_NAME${peer.user_name}`,
        ),
      );
      peer.ws.send(
        ProtoMessage(CMD.JOIN_LOBBY, p.id, `EXISTING_USER_NAME${p.user_name}`),
      );
    });
    // this.peers.forEach((p) => {
    // 	p.ws.send(ProtoMessage(CMD.PEER_CONNECT, assigned));
    // 	peer.ws.send(ProtoMessage(CMD.PEER_CONNECT, this.getPeerId(p)));
    // });
    this.peers.push(peer);
  }

  leave(peer) {
    const idx = this.peers.findIndex((p) => peer === p);
    if (idx === -1) {
      return false;
    }
    this.peers.forEach((p) => {
      if (peer.id === this.host) {
        // Room host disconnected, must close.
        p.ws.close(4000, STR_HOST_DISCONNECTED);
      } else {
        // Notify peer disconnect.
        p.ws.send(ProtoMessage(CMD.LEFT_LOBBY, peer.id, peer.user_name));
      }
    });
    this.peers.splice(idx, 1);
    if (peer.id === this.host && this.closeTimer >= 0) {
      // We are closing already.
      clearTimeout(this.closeTimer);
      this.closeTimer = -1;
    }
    return peer.id === this.host;
  }
}

const lobbies = new Map();
let peersCount = 0;

function lobbyListString() {
  let returnString = '';
  if (lobbies.size > 0) {
    lobbies.forEach((p) => {
      if (returnString !== '') {
        returnString += ' ';
      }
      returnString += p.name;
    });
  }
  return returnString;
}

wss.broadcast = function broadcast(msg) {
  wss.clients.forEach((client) => {
    client.send(msg);
  });
};

function sendGameStartMessage(peer) {
  // Generate '***' delimited list of peers and send it to everyone.
  let peerListString = '';
  lobbies.get(peer.lobby).peers.forEach((p) => {
    if (peerListString !== '') {
      peerListString += '***';
    }
    peerListString += p.id;
  });
  if (peerListString !== '') {
    // Send lobby peer list to all members
    lobbies.get(peer.lobby).peers.forEach((p) => {
      console.log('sendGameStartMessage', p.id);
      p.ws.send(ProtoMessage(CMD.GAME_STARTING, 0, peerListString));
    });
  }
  /*
  var current_lobby = find_lobby_by_peer(peer)
  if current_lobby:
    var all_peer_ids : String = ""
    for player in current_lobby.peers:
      all_peer_ids += str(player.id) + "***"

    for player in current_lobby.peers:
      player.send_msg(Message.GAME_STARTING, 0 , all_peer_ids)
   */
}

function joinLobby(peer, pLobby, mesh, isServer = true) {
  let newLobby;
  // Peer must not yet be in a lobby
  if (peer.lobby !== '') {
    console.error(
      `${peer.id} tried to join ${pLobby} when they were already in lobby ${peer.lobby}`,
    );
    return;
    // throw new ProtoError(4000, STR_ALREADY_IN_LOBBY);
  }
  let lobbyName = pLobby;
  if (lobbyName === '') {
    if (lobbies.size >= MAX_LOBBIES) {
      throw new ProtoError(4000, STR_TOO_MANY_LOBBIES);
    }
    lobbyName = randomSecret();
    lobbies.set(lobbyName, new Lobby(lobbyName, peer.id, mesh));
    console.log(`Peer ${peer.id} created lobby ${lobbyName}`);
    console.log(`Open lobbies: ${lobbies.size}`);
    newLobby = true;
  }
  const lobby = lobbies.get(lobbyName);
  if (!lobby) {
    throw new ProtoError(4000, STR_LOBBY_DOES_NOT_EXISTS);
  }
  if (lobby.sealed) {
    throw new ProtoError(4000, STR_LOBBY_IS_SEALED);
  }
  console.log(
    `Peer ${peer.id} joining lobby ${lobbyName} ` +
      `with ${lobby.peers.length} peers`,
  );
  if (isServer) {
    theLobbyName = lobbyName;
    console.log(`${lobbyName} is the Server lobby now.`);
    console.log(`${peer.id} joined as the Server.`);
    serverPeerInfo.id = peer.id;
    serverPeerInfo.user_name = peer.user_name;
  }
  lobby.join(peer);
  if (newLobby) {
    // Send lobby list to everyone again with new lobby.
    wss.broadcast(ProtoMessage(CMD.LOBBY_LIST, 0, lobbyListString()));
  }
  // If the game is already in progress, tell this new player to start the game now
  if (lobby.gameInProgress) {
    sendGameStartMessage(peer);
  }
}

function parseMsg(peer, msg) {
  let json = null;
  try {
    json = JSON.parse(msg);
  } catch (e) {
    console.error(STR_INVALID_FORMAT, 197);
    console.error(msg);
    throw new ProtoError(4000, STR_INVALID_FORMAT);
  }

  const type = typeof json.type === 'number' ? Math.floor(json.type) : -1;
  const id = typeof json.id === 'number' ? Math.floor(json.id) : -1;
  const data = typeof json.data === 'string' ? json.data : '';

  if (type < 0 || id < 0) {
    console.error(STR_INVALID_FORMAT, 207);
    console.error(msg);
    throw new ProtoError(4000, STR_INVALID_FORMAT);
  }

  // PING
  if (type === CMD.PING) {
    peer.ws.send(ProtoMessage(CMD.PONG));
    return;
  }

  // Everybody does this first
  if (type === CMD.USER_INFO) {
    const dataObject = JSON.parse(data);
    if (dataObject.isServer && dataObject.serverPassword === serverPassword) {
      // Setting the ID to 1 has a real affect on how Godot processes the connections for this user.
      // I'm not sure if this is good or bad or what yet though.
      // At the moment, nobody will connect to a "client" with an ID of 1, so it is bad.
      //peer.id = 1;
      console.log(`Setting ${dataObject.name} ID to ${peer.id} as the server.`);
    }
    peer.ws.send(ProtoMessage(CMD.USER_INFO, peer.id, dataObject.name));
    peer.user_name = dataObject.name;
    console.log(
      `User name received! Received name ${dataObject.name} for peer ID ${peer.id}`,
    );
    return;
  }

  // SERVER
  // TODO: handle case of server attempting to "join" when server already exists
  if (type === CMD.SERVER) {
    if (data !== serverPassword) {
      console.error('Invalid server password received.');
      throw new ProtoError(4000, 'Invalid server password');
    }
    joinLobby(peer, '', true, true);
    return;
  }

  // Lobby joining for clients.
  if (type === CMD.JOIN_LOBBY) {
    if (!theLobbyName) {
      console.error('Client connection attempt when no server is connected');
      throw new ProtoError(
        4000,
        'Server is not up yet. Please try again in a moment.',
      );
    }
    joinLobby(peer, theLobbyName, true, false);
    return;
  }

  if (type === CMD.LOBBY_LIST) {
    peer.ws.send(ProtoMessage(CMD.LOBBY_LIST, 0, lobbyListString()));
    return;
  }

  if (type === CMD.GAME_STARTING) {
    if (serverPeerInfo.id === peer.id) {
      console.log(`Game Start requested from ${peer.id}`);
      sendGameStartMessage(peer);
      const lobby = lobbies.get(peer.lobby);
      lobby.flagGameStarted();
    } else {
      console.error('Non-server peer requested to start game.');
    }
    return;
  }

  if (type === CMD.OFFER) {
    // Offers come in from Godot games and are forwarded to others via this server.
    const str_arr = data.split('***');
    const send_to_id = Number(str_arr[2]);
    // Check if the recipient ID is in our lobby.
    let found;
    lobbies.get(peer.lobby).peers.forEach((p) => {
      if (p.id === send_to_id) {
        found = true;
        console.log(`Sending OFFER from ${peer.id} to ${p.id}`);
        p.ws.send(ProtoMessage(CMD.OFFER, peer.id, data));
      }
    });
    if (!found) {
      console.error(
        `ERROR: OFFER received for ${send_to_id} in lobby ${peer.lobby}, but ID do not match with any peer!`,
      );
    }
    /*
		var receiver_peer = find_peer_by_id(send_to_id)
		if receiver_peer:
			receiver_peer.send_msg(type, peer.id, data)
			print("Sending received OFFER! to peer %d" %peer.id)
			return true
		else:
			print()
			return false
		 */
    return;
  }

  if (type === CMD.ANSWER) {
    // Offers come in from Godot games and are forwarded to others via this server.
    const str_arr = data.split('***');
    const send_to_id = Number(str_arr[2]);
    // Check if the recipient ID is in our lobby.
    let found;
    lobbies.get(peer.lobby).peers.forEach((p) => {
      if (p.id === send_to_id) {
        found = true;
        // console.log(`Sending ANSWER from ${peer.id} to ${p.id}`);
        p.ws.send(ProtoMessage(CMD.ANSWER, peer.id, data));
      }
    });
    if (!found) {
      console.error(
        `ERROR: ANSWER received for ${send_to_id} in lobby ${peer.lobby}, but ID do not match with any peer!`,
      );
    }
    return;
  }

  if (type === CMD.ICE) {
    // Offers come in from Godot games and are forwarded to others via this server.
    const str_arr = data.split('***');
    const send_to_id = Number(str_arr[3]);
    // Check if the recipient ID is in our lobby.
    let found;
    lobbies.get(peer.lobby).peers.forEach((p) => {
      if (p.id === send_to_id) {
        found = true;
        // console.log(`Sending ICE from ${peer.id} to ${p.id}`);
        p.ws.send(ProtoMessage(CMD.ICE, peer.id, data));
      }
    });
    if (!found) {
      console.error(
        `ERROR: ICE received for ${send_to_id} in lobby ${peer.lobby}, but ID do not match with any peer!`,
      );
    }
    return;
  }

  if (!peer.lobby) {
    console.error(STR_NEED_LOBBY, 219);
    console.error(msg);
    throw new ProtoError(4000, STR_NEED_LOBBY);
  }
  const lobby = lobbies.get(peer.lobby);
  if (!lobby) {
    console.error(STR_SERVER_ERROR, 225);
    throw new ProtoError(4000, STR_SERVER_ERROR);
  }

  console.error(' -', STR_INVALID_CMD, 383);
  console.error(msg);
  throw new ProtoError(4000, STR_INVALID_CMD);
}

wss.on('connection', (ws, req) => {
  const remoteIp = req.headers['x-real-ip'] || req.socket.remoteAddress;
  console.log(`New connection from ${remoteIp}`);
  if (peersCount >= MAX_PEERS) {
    ws.close(4000, STR_TOO_MANY_PEERS);
    return;
  }
  peersCount++;
  const id = randomId();
  const peer = new Peer(id, ws);
  ws.on('message', (data, isBinary) => {
    // ws version 8 passes a buffer instead of a string
    const message = isBinary ? data : data.toString();
    if (typeof message !== 'string') {
      ws.close(4000, STR_INVALID_TRANSFER_MODE);
      return;
    }
    try {
      parseMsg(peer, message);
    } catch (e) {
      const code = e.code || 4000;
      console.error(
        `Error parsing message from ${id}: ${code} ${e.message}\n\t${message}`,
      );
      // TODO: I don't think closing the connection is the right thing to do,
      //       but it might be sometimes?
      // ws.close(code, e.message);
    }
  });
  ws.on('close', (code, reason) => {
    // TODO: If server leaves, wipe the server lobby name, and kick everyone out.
    peersCount--;
    console.log(
      `Connection with peer ${peer.id} closed ` +
        `with reason ${code}: ${reason}`,
    );
    if (
      peer.lobby &&
      lobbies.has(peer.lobby) &&
      lobbies.get(peer.lobby).leave(peer)
    ) {
      lobbies.delete(peer.lobby);
      if (theLobbyName === peer.lobby) {
        console.log('Server lobby deleted.');
        theLobbyName = '';
        serverPeerInfo = {};
      }
      console.log(`Deleted lobby ${peer.lobby}`);
      console.log(`Open lobbies: ${lobbies.size}`);
      peer.lobby = '';
    }
    if (peer.timeout >= 0) {
      clearTimeout(peer.timeout);
      peer.timeout = -1;
    }
  });
  ws.on('error', (error) => {
    console.error(error);
  });
});

// Ping all clients periodically using the built in Websocket ping feature to help prevent timeouts.
// It also helps to extend the timeout on any proxy like nginx, which may shut you down.
// This is important because once the games connect to each other, then need this websocket to exist
// for seeing new peers join, but otherwise they never talk over it.
setInterval(() => {
  // eslint-disable-line no-unused-vars
  wss.clients.forEach((ws) => {
    ws.ping();
  });
}, PING_INTERVAL);
