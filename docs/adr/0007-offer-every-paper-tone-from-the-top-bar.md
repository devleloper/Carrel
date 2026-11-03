# 7. Offer every paper tone and choose paper from the top bar

- Status: accepted
- Date: 2026-11-03

## Context

[Part 2 of the proposal](../proposal/02-design.md) (6.2 and 6.5) plans White and Cream for the MVP and Linen
and Night for 1.0. Night waits for a check on a device: PencilKit converts ink colors for the dark appearance,
and the converted palette has to keep a contrast of at least 3:1 and the same distinctness before the tone is
offered. Paper is chosen in the new notebook sheet and, in the editor, from More. Thumbnails of Night pages are
to be rendered with `draw(in:frame:from:darkUserInterfaceStyle:)`.

The owner asked for Linen and Night now, and for a paper chooser that is easy to find and shows what each
choice looks like.

## Decision

- All four tones are offered in the new notebook sheet and in the editor. The stored format already had them.
- Pages on Night paper, their canvases, cached ink images, thumbnails and PDF pages use the dark appearance;
  pages on the light tones always use the light one, whatever the app's theme.
- Pages and thumbnails on Night paper carry the 1 pt white 8% edge that 6.2 asks for in the dark theme in the
  light theme as well. A page takes the appearance of its paper rather than of the desk, and on the light desk
  the faint edge disappears against the dark paper while the shadow separates the page.
- The editor's top bar gets a Paper button next to Pages. Its popover applies a tone or style to the current
  page and offers Use for All Pages. More no longer lists paper.
- Tones and styles are chosen from tiles of real paper drawn by `PaperRenderer`: a magnified corner of the page,
  because a whole page at tile size loses its rulings. The sheet and the popover share the chooser.
- Ink images are rendered with `image(from:scale:)` under a trait collection with the paper's appearance. The
  explicit `draw(in:frame:from:darkUserInterfaceStyle:)` is async, while the PDF renderer and the hand-off from
  a live canvas need the image synchronously.

## Consequences

Night ships before its contrast check on a device, so that check now gates the release instead of the feature:
if the converted palette falls below 3:1 on Night or loses distinctness, Night gets its own ink palette as the
proposal foresees, and changing an existing notebook to or from Night gets a warning.

The top bar carries one more button; on narrow windows it is the first candidate to move back into More. The
new notebook sheet no longer shows a whole-page preview, so the page size is chosen by name only.
