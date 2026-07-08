# ContainerUI

Native macOS GUI (SwiftUI, SPM executable target, macOS 14+, Apple Silicon) for [Apple Container](https://github.com/apple/container). It shells out to the `container` CLI at `/opt/homebrew/bin/container` — there is no API/SDK layer.

## Commands

```bash
swift build                                # build
make run                                   # build + package .app + launch
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test   # run tests
```

`swift test` fails with "no such module 'XCTest'" under CommandLineTools — always set `DEVELOPER_DIR` to Xcode as above.

## Architecture

- Everything under `Sources/ContainerUI/` compiles as one module; subfolders are organizational only, no imports needed between files.
- `ContainerService` (`Services/`) is the single `@MainActor ObservableObject` injected as `@EnvironmentObject` everywhere. Feature areas live in extensions: `+Images`, `+Volumes`, `+System`.
- All CLI calls go through `ContainerService.shell(_:)`. Output is parsed by `static nonisolated` parsers (`parseContainerList`, `parseImageList`, …) — keep new parsers `nonisolated` so tests can call them without actor hops.
- UI: `ContentView` owns a 3-column `NavigationSplitView`; sidebar sections are the `SidebarItem` enum. List views take a `@Binding` selection; detail views render in the third column keyed by `.id(...)`.
- Shared UI helpers: `Views/Components/SharedComponents.swift`, `Utilities/` (`formatCount`, `FlowLayout`). `imageIcon(for:)` in `ImagesView.swift` is module-internal on purpose — reused by `ImageDetailView`.

## Conventions

- **Never add `Co-Authored-By: Claude` (or any AI trailer) to commits.** Owner's explicit rule.
- Zero external SPM dependencies. Apple frameworks only (Swift Charts is OK). Exceptions require owner approval first.
- One commit per logical change, English imperative messages.
- Add tests in `Tests/ContainerUITests/` for any new parsing or model logic; run tests before committing.
- Fixed-width column parsers are position-sensitive: test fixtures must align data rows to the exact header offsets (count characters — an off-by-one space shifts every field).

## Releases

Push a tag to publish — everything else is automated by `.github/workflows/release.yml` (tests → release build → package `.app` → zip → GitHub Release):

```bash
git tag v0.2.0 && git push origin v0.2.0
```

CI (`ci.yml`) runs build + tests on every push/PR to `main`. App is ad-hoc signed (no notarization); users bypass Gatekeeper with right-click → Open.

## Roadmap

`ROADMAP.md` (kept local, not committed — see `.gitignore`) is the prioritized work plan. When asked to "continue development", read it, implement the next unchecked item, mark it `[x]`, commit, push.
