# ContainerUI

A native macOS app for managing [Apple Container](https://github.com/apple/container) — run, inspect, and monitor lightweight macOS VMs from a clean SwiftUI interface.

[![CI](https://github.com/felmsena/ContainerUI/actions/workflows/ci.yml/badge.svg)](https://github.com/felmsena/ContainerUI/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/felmsena/ContainerUI)](https://github.com/felmsena/ContainerUI/releases/latest)
![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What is it?

Apple Container is a command-line tool that lets you run lightweight Linux containers natively on Apple Silicon. ContainerUI wraps it in a native macOS app so you can manage everything visually — no terminal required for day-to-day use.

## Features

- **Containers** — run, start, stop, restart, kill, remove and duplicate containers; ⌘-click for bulk actions, ↑/↓ to navigate
- **Run sheet** — ports, env vars and `.env` files, volumes, network, command/entrypoint, workdir, user, x86 images via Rosetta, `--rm`, read-only, init, SSH agent forwarding — with a copyable command preview
- **Logs** — follow container output live, VM boot logs, filter, and system logs by time range
- **Shell & files** — run commands inside a container, open a Terminal shell, copy files in/out, export the filesystem
- **Images** — browse with contextual icons, pull with live progress, delete, prune unused (never Apple's system images)
- **Volumes** — create, inspect and delete, with the containers that mount each one
- **Networks** — create (custom subnet or host-only), inspect, delete and prune networks
- **Registry** — curated catalog of popular images with Docker Hub stats, plus Docker Hub search
- **Build** — build from a Dockerfile/Containerfile with a streaming log, and manage the BuildKit builder's CPUs/memory
- **Groups** — compose-lite: define multi-container groups in YAML and bring them up/down in dependency order
- **Activity** — every build, pull and group run in one place, with progress and cancel
- **Stats** — live CPU/memory dashboard across containers, per-container charts, disk usage and versions
- **Command palette** — `⌘K` to jump anywhere or run actions (start/stop, run, pull, create…)
- **Menu bar** — quick access to running containers without opening the main window
- **Also** — update checks, configurable notifications, local DNS domains, registry logins, light/dark themes, English and Spanish

## Prerequisites

| Requirement | Version |
|---|---|
| macOS | 14 Sonoma or later |
| Apple Silicon | M1 or newer |
| [Apple Container](https://github.com/apple/container) | 1.4 or later |

> Apple Container only runs on Apple Silicon Macs.

### Install Apple Container

Install the signed package from the [Apple Container releases](https://github.com/apple/container/releases) (it installs to `/usr/local/bin`), or with Homebrew (`/opt/homebrew/bin`) — ContainerUI finds either, and you can point it at another path in Settings. Then start the services:

```bash
container system start
```

## Installation

### Option 1 — Download a release (fastest)

Download the latest `ContainerUI-vX.Y.Z.zip` from the [Releases page](https://github.com/felmsena/ContainerUI/releases/latest), unzip, and drag `ContainerUI.app` into `/Applications`.

> The app is ad-hoc signed (no Apple notarization), so macOS Gatekeeper will block the first launch. Right-click the app → **Open** → **Open** to bypass it once.

### Option 2 — Build from source

```bash
# Clone the repo
git clone https://github.com/felmsena/ContainerUI.git
cd ContainerUI/ContainerUI

# Build and launch
make run
```

### Option 3 — Build manually with Swift

```bash
cd ContainerUI/ContainerUI
swift build
make build
open ContainerUI.app
```

## Building

| Command | Description |
|---|---|
| `make build` | Debug build + packages `ContainerUI.app` |
| `make run` | Build and launch the app |
| `make release` | Release build |
| `make clean` | Remove build artifacts and `.app` |
| `make clear-cache` | Clear macOS icon cache (useful if the app icon doesn't appear) |

## Project Structure

```
Sources/ContainerUI/
├── App/              Entry point, root view and AppState (navigation)
├── Models/           Data types (ContainerInfo, ImageInfo, VolumeInfo, …)
├── Services/         ContainerService + extensions, CLI argument builders, process runner, background jobs
├── Sheets/           Modal sheets (RunContainerSheet)
├── Utilities/        Theme (design tokens), WindowChrome, FlowLayout, formatCount
└── Views/
    ├── Components/   Shared UI components (SectionCard, KeyValueRow, BrandControls)
    ├── Build/        Image build view with live log streaming
    ├── Containers/   Container list, detail, logs, stats, info tabs
    ├── Groups/       Compose-lite multi-container groups
    ├── Images/       Images list with contextual icons
    ├── Networks/     Network list, detail and creation
    ├── MenuBar/      Menu bar popover
    ├── Registry/     Curated catalog + Docker Hub search
    ├── Search/       Command palette (⌘K)
    ├── Settings/     App preferences
    ├── Sidebar/      Navigation sidebar
    ├── System/       System stats and logs
    └── Volumes/      Volume list and detail
```

## License

MIT — see [LICENSE](LICENSE) for details.
