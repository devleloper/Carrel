# Contributing

## Toolchain

- Xcode 27 or later (Apple silicon Mac, macOS Tahoe 26.6 or later)
- An iPad with iPadOS 27 for anything that touches writing; the simulator cannot judge Apple Pencil latency

There are no third-party dependencies, so the project builds right after cloning.

## Getting started

1. Open `Carrel.xcodeproj`.
2. To run on your iPad, create `Config/Local.xcconfig` (it is git-ignored) with your team:
   ```
   DEVELOPMENT_TEAM = ABCDE12345
   ```
3. Choose the `Carrel` scheme and run. Debug builds install as **Carrel** with the bundle ID
   `dev.devlet.notebook.dev`, next to any release build, so experiments never touch real notebooks.

## Commands

| What | Command |
|---|---|
| Lint and hygiene checks | `Scripts/lint.sh` |
| Domain and storage tests (seconds, no simulator) | `swift test --package-path Packages/CarrelKit` |
| App build and UI tests on an iPad simulator | `Scripts/test.sh` |

CI runs the same three commands on every push to `main`.

## Where things live

See [ARCHITECTURE.md](ARCHITECTURE.md). In short: storage and domain logic live in the `CarrelKit` package and
are tested on the Mac host; the app target holds SwiftUI screens, the UIKit writing surface and adapters to
Apple frameworks. The app target uses `MainActor` default isolation; the package does not.

## Code style

- Swift API Design Guidelines. Names say what a thing is or does; files are named after their primary type.
- Prefer concrete types. Introduce a protocol only for a real second implementation or a test seam that matters.
- Comments explain *why*: a platform constraint, a non-obvious decision, an invariant. Never restate the code.
- No `TODO` or `FIXME` in the code: open an issue instead. `Scripts/lint.sh` enforces this.
- `NotebookData` never traps (`fatalError`, `try!`): damaged files must be recoverable. Also enforced by lint.
- New logic in the package comes with Swift Testing tests. A new user flow gets a UI test.
- Every user-facing string goes through the String Catalog (`Text("…")`, `String(localized:)`).

## Commits and branches

- Commits go straight to `main`, which must stay green. Keep each commit small and self-contained.
- Messages follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(editor): open the palette at the pen tip on squeeze`.
  Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`.
  Scopes: `editor`, `library`, `storage`, `settings`, `design`, `ci`, `docs`.
- Occasional branches use `spike/<topic>`, `release/<version>` or `hotfix/<topic>`.
- User-visible changes are added to the `Unreleased` section of [CHANGELOG.md](CHANGELOG.md) in the same commit.

## Definition of done

- Lint, package tests and UI tests pass.
- Nothing can lose writing: think through a crash at every await between a change and the disk.
- VoiceOver labels exist for new controls; Dynamic Type and Reduce Motion are respected.
- Editor changes are checked on a real iPad with Apple Pencil.

## Reporting a security issue

See [SECURITY.md](SECURITY.md).
