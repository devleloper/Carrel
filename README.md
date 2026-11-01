# Carrel

[![CI](https://github.com/devleloper/notebook/actions/workflows/ci.yml/badge.svg)](https://github.com/devleloper/notebook/actions/workflows/ci.yml)

A native iPadOS notebook for handwritten notes: a quiet, cozy place to write with Apple Pencil, built for lectures and study first.

> **Status:** MVP in development (0.1.0). Carrel is the working name.

## Principles

- **The page comes first.** Writing tools stay out of the way; nothing sits on the paper while you write.
- **Your notes are safe.** Every page is saved crash-safely on the device, with snapshots and backups you can restore.
- **Fast at any size.** A notebook with hundreds of pages or a 1000-page PDF opens and scrolls without waiting.
- **The basics are never behind a subscription.** Writing, organizing and getting your notes out of the app are not paywalled.
- **AI is optional.** The app is complete without it, and nothing leaves the device unless you turn it on.

## Platform

- iPadOS 27 or later, Apple Pencil (Pencil Pro features where available)
- Swift 6, SwiftUI, PencilKit
- No third-party runtime dependencies

## Building

Open `Carrel.xcodeproj` in Xcode 27 and run the `Carrel` scheme. There are no third-party dependencies.
[CONTRIBUTING.md](CONTRIBUTING.md) covers signing for a device, tests and conventions.

## Documentation

- [Architecture](ARCHITECTURE.md): layers, modules, files on disk, saving and recovery.
- [Product proposal](docs/proposal/README.md) (in Russian): concept, features and priorities, UI/UX, architecture, roadmap and risks.

## License

The source code is available under the [MIT License](LICENSE).
