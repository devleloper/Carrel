# 6. Let the palette collapse and dock to either edge, and ship the art inks now

- Status: accepted
- Date: 2026-11-03

## Context

[Part 2 of the proposal](../proposal/02-design.md) (6.3, 6.5, 6.6) describes the palette as a vertical capsule
fixed to the leading edge of the window, or the trailing edge for a left-handed writer. It collapses into a
single button only in windows narrower than 500 pt. More holds the ruler, with the ribbon and the art inks
planned for 1.0. The palette at the pen tip opens to the left of the tip, or to the right for a left-handed
writer.

The owner asked for a palette that folds away on request in any window and can be moved, and for the art inks to
be available from the start. The watercolor and crayon inks need no
work beyond a menu entry: PencilKit ships them on every system Carrel supports, and their strokes stay within
the `PKContentVersion.version5` ceiling.

## Decision

- The palette collapses into one glass button that shows the tool in hand whenever the writer chooses, in any
  window size, and expands again on a tap. The choice is remembered.
- A drag docks the palette to the nearer edge of the window, which is also remembered. VoiceOver and Switch
  Control get an action that moves it to the other edge.
- The docked side replaces a separate handedness setting: the palette at the pen tip opens toward the same side,
  so docking the palette on the right also moves the pen-tip palette out from under a left hand.
- Watercolor and crayon come forward from 1.0 as tools under More, with the same settings as a pen apart from
  the ink type. The ribbon stays in 1.0.
- The palette at the pen tip grows out of the tip with a spring, scaling from 0.3 around the tip point, and
  shrinks back into it, instead of the `glassEffectTransition(.materialize)` with a 0.9 to 1 scale in 6.7. The
  palette is 24 pt away from the tip, and only a transition anchored at the tip answers where it came from.
  Under Reduce Motion it fades, as 6.7 asks.

## Consequences

- There is no handedness switch in Settings; the side the writer puts the palette on is the only input. If a
  writer wants the palette on one side and the pen-tip palette on the other, that needs a setting later.
- The automatic changes for narrow and short windows in 6.3 (a horizontal capsule, a popover from one button)
  are not built yet; collapsing by hand covers the same need until they are.
- The pen-tip transition is ours rather than the system's, so it does not change with later Liquid Glass
  updates; it is checked on device with the rest of the editor's motion.
- Art ink strokes can be in notebooks from the first release, so the PDF export and the page thumbnails must
  render them, and the device check of each release includes a page drawn with them.
