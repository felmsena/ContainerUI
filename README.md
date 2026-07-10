# ContainerUI

A native macOS app for managing [Apple Container](https://github.com/apple/container) — run, inspect, and monitor lightweight macOS VMs from a clean SwiftUI interface.

[![CI](https://github.com/felmsena/ContainerUI/actions/workflows/ci.yml/badge.svg)](https://github.com/felmsena/ContainerUI/actions/workflows/ci.yml)
![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What is it?

Apple Container is a command-line tool that lets you run lightweight Linux containers natively on Apple Silicon. ContainerUI wraps it in a native macOS app so you can manage everything visually — no terminal required for day-to-day use.

## Features

- **Containers** — list, run, start, stop, restart, and remove containers
- **Images** — browse local images with contextual icons, pull from Docker Hub, prune unused
- **Volumes** — create, inspect, and delete volumes with mount hint snippets
- **Registry** — curated catalog of popular images (Postgres, Redis, Nginx, etc.) with Docker Hub stats; also search Docker Hub directly
- **Stats** — live CPU, memory, and network stats per container
- **Logs** — tail container logs with line count selector and filter
- **System** — service status, disk usage, and version info
- **Menu bar** — quick access to running containers without opening the main window
- **Onboarding** — step-by-step install guide when Apple Container is not detected

## Prerequisites

| Requirement | Version |
|---|---|
| macOS | 14 Sonoma or later |
| Apple Silicon | M1 or newer |
| [Homebrew](https://brew.sh) | any recent version |
| [Apple Container](https://github.com/apple/container) | latest |

> Apple Container only runs on Apple Silicon Macs.

### Install Apple Container

```bash
brew tap apple/apple
brew install container
container system start
```

## Installation

### Option 1 — Build from source (recommended)

```bash
# Clone the repo
git clone https://github.com/felmsena/ContainerUI.git
cd ContainerUI/ContainerUI

# Build and launch
make run
```

### Option 2 — Build manually with Swift

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
├── App/              Entry point and root view
├── Models/           Data types (ContainerInfo, ImageInfo, VolumeInfo, …)
├── Services/         ContainerService + extensions (images, volumes, system)
├── Sheets/           Modal sheets (RunContainerSheet)
├── Utilities/        FlowLayout, shared formatCount helper
└── Views/
    ├── Components/   Shared UI components (SectionCard, KeyValueRow)
    ├── Containers/   Container list, detail, logs, stats, info tabs
    ├── Images/       Images list with contextual icons
    ├── MenuBar/      Menu bar popover
    ├── Registry/     Curated catalog + Docker Hub search
    ├── Settings/     App preferences
    ├── Sidebar/      Navigation sidebar
    ├── System/       System stats and logs
    └── Volumes/      Volume list and detail
```

## License

MIT — see [LICENSE](LICENSE) for details.
