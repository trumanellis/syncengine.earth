# Synchronicity Engine

## A Censorship-Resistant, Local-First Task Sharing Network

---

## The Vision

In a world of centralized platforms that harvest attention and data, **Synchronicity Engine** offers a different path: a peer-to-peer network for collaborative task sharing that works without servers, resists censorship, and puts privacy first.

We call tasks "quests" because that's what they are—conscious choices to manifest change in the world. When you share a quest with your network, it synchronizes automatically across all participants through encrypted gossip protocols. No central server sees your data. No corporation owns your productivity.

This is the infrastructure for a **sacred gifting economy**—where contributions flow freely between trusted peers, synchronized through the mesh, without intermediaries extracting value from every interaction.

---

## Core Principles

### Local-First
Your data lives on your device. The app works fully offline—create, edit, and complete quests anytime. When you reconnect, changes merge seamlessly with your network through conflict-free replicated data types (CRDTs).

### Censorship-Resistant
No mandatory coordination server. Relays help with NAT traversal but see only encrypted ciphertext. Your network topology is yours to define. No single point of failure or control.

### Quantum-Secure Identity
Every user identity is protected by hybrid cryptography: ML-DSA-65 (post-quantum lattice-based) combined with Ed25519 (classical elliptic curve). Your identity remains secure against both current and future threats.

### Gossip-Based Sync
All synchronization happens through iroh-gossip topics—multi-peer broadcast that naturally forms mesh networks. Late joiners catch up automatically. Offline peers receive updates when they return.

### Effortless Sharing
One tap to generate an invite link or QR code. One tap to join a shared realm. The complexity of P2P networking is invisible—what remains is simple, human collaboration.

---

## How It Works

### Realms
A **realm** is a shared space for quests. Think of it as a collaborative task list that exists across all participants' devices simultaneously.

- **Private realms** stay on your device—your personal space for sacred quests
- **Shared realms** synchronize across your trusted network through encrypted gossip

Each realm is an Automerge document—a CRDT that mathematically guarantees conflict-free merging when multiple people edit simultaneously, even offline.

### The Mesh
When you join a realm, your device subscribes to its gossip topic. Every change you make broadcasts to all other subscribers. Every change they make arrives at your device. The mesh self-organizes—no central coordinator required.

```
    [Your Device] ←→ [Peer A]
         ↕              ↕
    [Peer B] ←————→ [Peer C]
```

### Contacts & Trust
Build your network through direct peer connections. Exchange invite codes to establish mutual trust. Once connected, profile information syncs automatically, and you can message each other directly through the mesh.

### Encryption
Every sync message is encrypted with ChaCha20-Poly1305 using per-realm keys. Even if traffic passes through a relay for NAT traversal, the relay sees only ciphertext. Your quests remain private to your realm.

---

## The Aesthetic

Synchronicity Engine embodies a **minimal terminal** aesthetic—command-line precision meets sacred purpose.

### Colors of the Field
- **Void Black** (#0a0a0a) — The canvas of potential
- **Moss Green** (#7cb87c) — Growth, status, vitality
- **Cyan Aether** (#00d4aa) — Connection, synchronization, the digital
- **Gold** (#d4af37) — Sacred terms, titles, importance

### Typography
- **Cormorant Garamond** for headings—elegant serif connecting to timeless wisdom
- **JetBrains Mono** for body text—precise monospace honoring the terminal heritage

### Sacred Language
We choose words deliberately:
- "Manifest quest" rather than "create task"
- "Field resonating" rather than "connected"
- "Synchronicities are forming" rather than "loading"
- "Enter the Field" rather than "login"

Language shapes perception. Our terminology reminds users they're participating in something meaningful—not just managing a to-do list.

---

## Technical Architecture

### The Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **P2P Transport** | iroh 0.95 | QUIC-based networking, NAT traversal, relay support |
| **Gossip Protocol** | iroh-gossip | Multi-peer broadcast, topic subscription |
| **CRDT Engine** | Automerge 0.7 | Conflict-free document synchronization |
| **Storage** | redb | Embedded, single-file, crash-safe persistence |
| **Cryptography** | ChaCha20-Poly1305, ML-DSA-65, Ed25519 | Encryption and quantum-safe signatures |
| **UI Framework** | Dioxus 0.6 | Pure Rust, native desktop rendering |
| **Runtime** | Tokio | Async Rust for concurrent networking |

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                      Dioxus UI Layer                         │
│         (78 components, minimal terminal aesthetic)          │
├──────────────────────────────────────────────────────────────┤
│                    syncengine-core                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Engine    │  │  Identity   │  │   ContactManager    │  │
│  │ (orchestrator)│  │ (quantum-safe)│  │ (peer relationships)│  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ GossipSync  │  │   Crypto    │  │    BlobManager      │  │
│  │ (P2P mesh)  │  │ (encryption)│  │ (P2P file transfer) │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Storage (redb + Automerge)                 │ │
│  └─────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────┤
│                      iroh Network Layer                      │
│        (QUIC transport, gossip topics, relay support)        │
└──────────────────────────────────────────────────────────────┘
```

### Identity Model

Each user generates a hybrid keypair on first launch:

```
Ed25519 (64 bytes)     — Fast classical signatures
ML-DSA-65 (3293 bytes) — Post-quantum lattice-based signatures
DID = blake3(ed25519_pub || mldsa_pub)
```

Both signature schemes must verify for any message to be accepted. This provides security against both classical computers and future quantum computers.

### Sync Protocol

Our custom protocol optimizes for mesh topologies:

1. **Changes** — Broadcast new Automerge changes (small, frequent)
2. **Heads** — Periodic announcements of document state (peer discovery)
3. **SyncRequest** — Request targeted sync from specific peer (late joiners)
4. **SyncMessage** — Automerge protocol messages (catch-up)

This hybrid approach ensures immediate propagation of new changes while allowing efficient catch-up for peers who were offline.

---

## Current Status

### What's Built

**Core Infrastructure**
- 13,000+ lines of core library code
- Complete P2P sync layer with gossip mesh topology
- Hybrid quantum-secure identity system
- Per-realm ChaCha20-Poly1305 encryption
- redb persistence with Automerge documents

**Features**
- Create and manage private and shared realms
- Add, complete, and delete quests (tasks)
- Real-time synchronization across mesh network
- Contact system with invite codes
- Direct peer-to-peer messaging
- Profile sync with avatar support
- P2P blob transfers for images

**User Interface**
- 78 Dioxus components
- 5 main pages (Landing, Field, Network, Profile, Realm View)
- Command palette (⌘K)
- Keyboard shortcuts
- Responsive layout with realm selector
- Minimal terminal aesthetic

**Developer Tools**
- Lua-driven scenario runner for multi-instance testing
- JSONL structured logging
- CLI wrapper for scripted operations
- MCP server for AI integration

### What's Next

**Phase 3: Enhanced Experience**
- Mobile builds (iOS and Android)
- Encrypted storage at-rest
- Advanced privacy controls
- Desktop app distribution (installers)

**Phase 4: Ecosystem Growth**
- Public relay network
- Enhanced offline resilience
- Rich media in quests
- Realm templates and sharing

---

## Why This Matters

The tools we use shape how we think and collaborate. Centralized platforms train us to accept surveillance, seek engagement metrics, and cede control of our creative output.

Synchronicity Engine offers infrastructure for a different way of working together:

- **Your data stays yours** — Local-first means no platform owns your quests
- **Your network is yours** — Peer-to-peer means no intermediary can disconnect you
- **Your identity is sovereign** — Quantum-secure cryptography means your digital self persists beyond any company's lifecycle
- **Your collaboration is private** — End-to-end encryption means your shared work is visible only to participants

This is technology in service of human agency—tools that amplify rather than extract, connect rather than surveil, empower rather than addict.

---

## The Sacred Dimension

We call this the "Synchronicity Engine" because synchronicities—meaningful coincidences—emerge naturally when people align their quests and work together. The technology enables the magic; it doesn't manufacture it.

When you "enter the field," you're joining a network of peers with shared purpose. When you "manifest a quest," you're declaring what you want to create. When the "field resonates," your contribution is propagating through the mesh.

The sacred language isn't decoration—it's a reminder that productivity tools can serve deeper purposes than quarterly metrics. Every quest you create is a vote for the world you want to build.

---

## Join the Field

Synchronicity Engine is open source and actively developed. The core is complete. The vision is clear. The field is forming.

**For Developers**
- Pure Rust codebase with clean architecture
- Well-documented APIs and protocols
- Comprehensive test scenarios
- Contributor-friendly workspace

**For Early Adopters**
- Desktop app for macOS, Linux, Windows
- Full P2P functionality today
- Mobile coming soon

**For the Curious**
- Explore the design philosophy
- Study the architecture decisions
- Join the conversation about decentralized collaboration

---

## Technical Specifications

### Protocols
- **Transport**: QUIC via iroh
- **Sync**: Custom gossip protocol over iroh-gossip
- **Documents**: Automerge CRDT
- **Encryption**: ChaCha20-Poly1305 (AEAD)
- **Signatures**: Hybrid ML-DSA-65 + Ed25519

### Cryptographic Parameters
- **Realm Keys**: 256-bit random
- **Ed25519**: 256-bit private, 256-bit public
- **ML-DSA-65**: NIST Level 3 security (post-quantum)
- **Blake3**: 256-bit hash output

### Network
- **NAT Traversal**: QUIC hole punching + relay fallback
- **Discovery**: Bootstrap peers + gossip propagation
- **Topology**: Self-organizing mesh per realm

### Storage
- **Database**: redb (embedded, single-file)
- **Documents**: Automerge binary format
- **Blobs**: Content-addressed via Blake3

---

## Glossary

| Term | Meaning |
|------|---------|
| **Quest** | A task or action you want to manifest |
| **Realm** | A shared space containing quests |
| **Field** | The network of connected peers |
| **Gossip** | Multi-peer message broadcast protocol |
| **CRDT** | Conflict-free Replicated Data Type |
| **DID** | Decentralized Identifier (your cryptographic identity) |
| **Mesh** | Self-organizing peer-to-peer network topology |

---

*Synchronicity Engine — Where quests synchronize across the mesh.*
