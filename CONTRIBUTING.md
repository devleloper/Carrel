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
| Lint and hygiene checks (any swift-format finding fails) | `Scripts/lint.sh` |
| Domain and storage tests (seconds, no simulator) | `swift test --package-path Packages/CarrelKit` |
| App build, unit tests and UI tests on an iPad simulator | `Scripts/test.sh` |

CI runs the same checks on every push to `main`, on pull requests and on demand. It builds the package with
warnings as errors before testing it (`swift build --build-tests --package-path Packages/CarrelKit -Xswiftc
-warnings-as-errors`, then `swift test --skip-build`). Run `xcrun swift-format format --in-place --recursive
Carrel CarrelTests CarrelUITests Packages/CarrelKit` before committing to fix formatting automatically.

## Where things live

See [ARCHITECTURE.md](ARCHITECTURE.md). In short: storage and domain logic live in the `CarrelKit` package and
are tested on the Mac host; the app target holds SwiftUI screens, the UIKit writing surface and adapters to
Apple frameworks. The app target uses `MainActor` default isolation; the package does not.

## Code style

- Swift API Design Guidelines. Names say what a thing is or does; files are named after their primary type.
- Prefer concrete types. Introduce a protocol only for a real second implementation or a test seam that matters.
- Comments explain *why*: a platform constraint, a non-obvious decision, an invariant. Never restate the code.
- No `TODO` or `FIXME` in the code: open an issue instead. `Scripts/lint.sh` enforces this.
- `CarrelKit` never traps (`fatalError`, `precondition`, `try!`): damaged files must be recoverable. Also
  enforced by lint.
- New logic comes with Swift Testing tests: in the package when it does not need UIKit, otherwise in
  `CarrelTests`. A new user flow gets a UI test in `CarrelUITests`.
- Follow the design rules in [ARCHITECTURE.md](ARCHITECTURE.md#design-rules): one reason to change per type,
  abstractions only where they pay for themselves, no duplicated knowledge.
- Every user-facing string is localizable: `Text("…")`, `String(localized:)` or `LocalizedStringResource`.
  Xcode extracts them into `Carrel/Resources/Localizable.xcstrings` when it builds; English is the only
  language so far.
- Errors from anything that writes reach the user through the screen's `errorMessage` and `errorAlert`.

## Commits and branches

- Commits go straight to `main`, which must stay green. Keep each commit small and self-contained.
- Messages follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(editor): open the palette at the pen tip on squeeze`.
  Types: `feat`, `fix`, `perf`, `refactor`, `style`, `test`, `docs`, `build`, `ci`, `chore`, `revert`.
  Scopes: `app` (changes across the app target), `editor`, `library`, `settings`, `design`, `storage` (the
  package), `proposal` (the design documents in `docs/proposal`).
- Occasional branches use `spike/<topic>`, `release/<version>` or `hotfix/<topic>`.
- User-visible changes are added to the `Unreleased` section of [CHANGELOG.md](CHANGELOG.md) in the same commit.
- A non-trivial decision, or a departure from the [proposal](docs/proposal/README.md), gets the next record in
  [docs/adr](docs/adr), following [0001](docs/adr/0001-adopt-proposal-architecture.md).

## Definition of done

- Lint, package tests, unit tests and UI tests pass, without compiler warnings: CI treats them as errors.
- Nothing can lose writing: think through a crash at every await between a change and the disk.
- VoiceOver labels exist for new controls; Dynamic Type and Reduce Motion are respected.
- Editor changes are checked on a real iPad with Apple Pencil.

## Reporting a security issue

See [SECURITY.md](SECURITY.md).
