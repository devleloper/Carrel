# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Library with folders, favorites, search by title and a Trash that keeps notebooks and pages for 30 days.
- New notebook sheet with 12 covers, six paper styles in White and Cream, A4, Letter and A4 Landscape.
- Editor with a vertical stream of pages, pinch to zoom, and a next page that appears with the first stroke.
- Palette with three favorite pens, highlighter, eraser and lasso; tap a selected tool again for its settings.
- Tool settings with three widths for every tool, four ink types and a custom color for pens, and an eraser that
  removes whole strokes or erases pixels.
- Watercolor and crayon inks under More in the palette, next to the ruler.
- Apple Pencil Pro squeeze and double tap open a compact palette at the pen tip.
- Autosave: at most five seconds of writing at risk if the app crashes, nothing when it goes to the background.
- Recovery of damaged or missing pages from the previous version, with the damaged file kept aside.
- The editor closes only once everything is saved, and shows why when a save fails.
- Notebooks that can't be opened are reported in the library; their files are left untouched.
- Page overview with duplicate, reorder, delete and restore.
- PDF export and a one-file library backup that can be restored from Settings.
- Pages scroll under the editor's top bar, which softly fades them out beneath its controls.
- Undo and Redo in the top bar are dimmed when there is nothing to undo or redo.
- Pages fill the width of the window; pinch out to 50% to see them on the desk, or in to 400%.
- With Only Draw with Apple Pencil on, a double tap with a finger switches between the full width and 200%.
- View menu Zoom In (⌘+), Zoom Out (⌘−) and Fit Width (⌘0) in the editor; Fit Width returns to the full width
  after a pinch.

### Fixed

- A tap on the editor's top bar beside its buttons no longer scrolls the page or draws on it, with a finger or
  Apple Pencil.
- A pinch on the pages no longer closes the editor without waiting for the save.
- The palette at the pen tip opens beside the pen instead of further down the page, and never under the top bar.
