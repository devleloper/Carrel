# 2. Run CI as one workflow with UI tests on every push

- Status: accepted
- Date: 2026-11-03

## Context

The CI plan in [part 3 of the proposal](../proposal/03-architecture.md) has three workflows: `lint.yml` on
Ubuntu, `ci.yml` with the `Unit` test plan, and `nightly.yml` with the `UI` and `Sanitizers` plans. It also
expects a `commit-msg` hook in `.githooks`, `xcbeautify` for the build log, Xcode pinned through
`DEVELOPER_DIR`, and weekly Dependabot updates.

The project has one committer who pushes straight to `main`, two UI tests and no pull request review. A broken
UI flow found the next night would already sit under several commits.

## Decision

- One workflow, `.github/workflows/ci.yml`, with two jobs on the `xcode-27` runner: `Lint` (`Scripts/lint.sh`)
  and the package tests followed by `Scripts/test.sh`, which runs the unit and UI tests.
- UI tests, including the accessibility audits, run on every push instead of nightly, so a commit that breaks a
  flow is red itself.
- Lint uses swift-format from the Xcode toolchain on the same runner, so CI and a developer's Mac run the same
  formatter version.
- The scheme selects the tests; there are no test plans, no Thread Sanitizer run and no coverage report yet.
- `Scripts/test.sh` repeats the compiler errors and warnings at the end of the log instead of piping it through
  `xcbeautify`, which would be a third-party tool.
- Xcode is the runner image's default for `xcode-27`; the job prints its version.
- There is no `commit-msg` hook; commit messages are checked by hand.
- Actions are pinned by commit SHA with a version comment, as planned. Dependabot proposes updates monthly: the
  workflow uses two actions, and a weekly cadence would mostly produce noise.

## Consequences

A push takes about 14 minutes to verify instead of a few, and pushing several commits at once verifies only the
last one, because the workflow cancels runs in progress for the same branch. The app test job allows
45 minutes, since the same commit's test step has taken anywhere from 4 to 12 minutes on the runner.

This decision is revisited when any of these happens: the UI suite makes a push run noticeably slower (then UI
tests move to a nightly workflow with test plans), a second contributor arrives (then the `commit-msg` hook and
a message check in lint), or a data race is suspected in code that runs off the main actor (then the
`Sanitizers` plan).
