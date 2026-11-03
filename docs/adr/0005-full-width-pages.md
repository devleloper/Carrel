# 5. Show pages at the full width of the window

- Status: accepted
- Date: 2026-11-03

## Context

[Part 2 of the proposal](../proposal/02-design.md) lays the editor's pages on the desk: at the fit-to-width zoom a
page sits between desk margins with the level-1 shadow (6.5, "Холст"), and the zoom limits were left to a
prototype. 6.6 relies on those margins: Apple Pencil swipes from the bottom corners of the screen take a screenshot
or open Quick Note, apps cannot turn them off, and in a wide window at fit-to-width the corners were meant to land
on the desk rather than on paper.

The owner decided that a page should fill the window by default and that its frame should appear only when zooming
out.

## Decision

- At the default zoom, fit to width, the widest page spans the window edge to edge: no desk beside it, no border,
  no shadow. A narrower page in the same notebook, such as a portrait page among landscape ones, stays centred and
  keeps its edges and shadow, because the desk shows beside it.
- Consecutive pages are separated by a 12 pt strip of desk, also above the first page and below the last. A hairline
  or a shadow would sit on the paper of both pages and read as a ruled line; a gap of the desk colour reads as the
  end of a sheet, and at 12 pt it costs about 1% of an A4 page's height at full width. Paper close to the desk
  colour, such as a dark tone on the dark desk, may need a stronger separation.
- Zoom runs from 50% to 400% of fit-to-width. Pinching out below 100% puts the pages on the desk, centred, with
  their edges and level-1 shadow. When a zoom ends, the pages are laid out again at the new scale so ink is sharp,
  and the spot of paper at the centre of the screen stays there. A pinch that ends within 5% of fit-to-width settles
  exactly at it, so the borderless page is never left with slivers of desk or a few points of sideways scrolling.
- With Only Draw with Apple Pencil on, a double tap with a finger switches between fit-to-width and 200% and keeps
  the tapped spot under the finger, animated unless Reduce Motion is on. With drawing by finger it stays off, as 6.6
  says, since it could not be told apart from two dots.
- The owner accepts that Apple Pencil swipes from the bottom corners now start on paper at the default zoom.

## Consequences

More of the screen is paper, and writing reaches the window's edges. A swipe from a bottom corner meant for a
screenshot or Quick Note can begin on a page, and the writing surface no longer keeps the corners clear as 6.6
planned; whether such a swipe leaves a mark before the system takes it has to be checked on a device. The palette
floats over the page instead of over the desk margin.
