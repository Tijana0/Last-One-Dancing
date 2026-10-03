# Last One Dancing

**Last One Dancing** is a remote multiplayer game built in **Godot 4** during a Global Game Jam. Players connect to a host, enter the same game session, interact with the world, and compete to be the last player standing.

The project was built as a team game-jam project, with a strong focus on getting real-time multiplayer working reliably within a short development cycle.

**Download:** https://tiliavenice.itch.io/last-one-dancing  
Available for **Windows** and **macOS**.

## Team & contributions

Last One Dancing was built collaboratively during the game jam. The responsibilities overlapped, but the main areas of contribution were:

| Team member | Main contributions |
| --- | --- |
| **Tijana Mijatović** | Networking lead, development, and integration — multiplayer synchronization and game-state systems, player/gameplay systems, item and inventory logic, boss/victory flow, debugging, Git workflows, merges, and integration across the project. |
| **Diana Ivanova** | Development and animation integration — multiplayer-authoritative player movement, networked NPCs and AI, combat-related systems, mask/sprite integration, and directional character animations. |
| **Hajar Rhachi** | Lobby/UI and gameplay integration — lobby and loading flow, early NetworkManager integration, game-room scene work, character spritesheets/animation work, and start/win/lose screen assets. |
| **Angelina Hess** | Art and visual assets — created most of the game's artwork and visual assets. |

My primary responsibility was the **multiplayer/networking and integration side of the project**, alongside broader gameplay and systems work. I also handled much of the Git/version-control coordination needed to bring the team's work together during the jam.

## Multiplayer features

- Host and client connection flow using Godot's ENet multiplayer API
- Player registration and disconnect handling
- Network-authoritative player instances
- RPC-based synchronization between peers
- Synchronized NPC and pickup spawning
- Shared game-state events and win-condition flow
- Multiplayer lobby and scene transitions

## Tech stack

- **Godot 4.6**
- **GDScript**
- **ENet multiplayer**
- **Git / GitHub**

## Networking architecture

The project uses a host-authoritative approach for shared game state.

```
Host
├── creates ENet server
├── tracks connected players
├── spawns shared NPCs/items
└── broadcasts game-state events
        ↓ RPC
Clients
├── register with the host
├── receive synchronized entities
└── control their own player authority
```

The `NetworkManager` handles connection setup, player registration, disconnects, and player spawning. Shared gameplay events are synchronized through RPCs, while server-side checks are used for state that should be controlled by the host.

## Selected implementation details

### Player registration

When a client connects, it registers its multiplayer ID and player name with the host. Existing player information is then synchronized so newly connected clients can build the same player state.

### Multiplayer authority

Each player node is assigned authority based on its network ID. This keeps local player control separate from remote player instances.

### Shared world state

NPCs and pickups are created by the server and spawned across peers through RPC calls, reducing the chance of different clients creating conflicting versions of the game state.

## Running the project

1. Install **Godot 4.6**.
2. Clone the repository and open `project.godot`.
3. Run one instance and choose the host option.
4. Run another instance and join using the host's IP address.

The multiplayer manager uses **UDP port 7777**, so the port must be reachable between the participating machines.

## Project structure

```
scripts/
├── managers/
│   ├── network_manager.gd
│   └── game_manager.gd
├── player.gd
├── npc.gd
└── ...

scenes/       # Menus and gameplay scenes
prefabs/      # Reusable player, NPC, and item scenes
assets/       # Game assets
```

---

Built as a collaborative game-jam project. This repository highlights my work with multiplayer networking, integration, and team-based development.
