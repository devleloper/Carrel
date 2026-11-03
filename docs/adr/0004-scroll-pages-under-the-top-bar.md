# 4. Scroll pages under the editor's top bar

- Status: accepted
- Date: 2026-11-03

## Context

[Part 2 of the proposal, 6.5](../proposal/02-design.md#редактор) keeps the editor's pages out from under the top
bar: the scroll area starts at the bar's lower edge and the bar stands on a strip of desk, instead of using the
scroll edge effect. The reasons were that lines written near the top would not show through the glass, that the
pen would not catch the bar's buttons, and that the labels on the glass would read the same over any handwriting.
The cost was about 60 pt of height that the standard iPadOS layout gives to content.

The owner decided that pages should continue under the bar, with the progressive blur that iPadOS 26 and later
draw under system bars, the way content does in the system apps.

## Decision

- Pages scroll under the top bar. The bar is a SwiftUI `safeAreaBar`, which registers with the scroll view beneath
  it, including the canvas's UIKit `UIScrollView`, so the system draws the scroll edge effect. The canvas sets
  `topEdgeEffect.style = .soft`: content fades out progressively under the controls. No blur or gradient of our own.
  The effect takes its height from the registered bar, not from the scroll view's safe area, which holds only the
  status bar. On the iPadOS 27 simulator it spans the status bar and the whole bar, and switching the canvas to the
  hard style moves its cutoff to the bar's lower edge, so the canvas's own edge effect is the one drawn.
- At rest the first page starts below the bar. The canvas ignores the safe area to reach under the bar, so the
  editor passes it the bar's measured height, and the scroll view adds it to its top content inset.
- The whole rectangle of the bar takes touches. A touch there never reaches the page, so the pen cannot start a
  stroke and a finger cannot start a scroll under the bar's buttons.

## Consequences

The page gains the height of the bar while scrolling, and the bar looks like the system bars in other apps. The
reasons in 6.5 are answered differently: the soft edge effect keeps the labels legible over handwriting, and the
bar's own hit area keeps the pen off its buttons and the page under it. Lines near the top of the visible area are
faded while they sit under the bar; scrolling brings them out.

The system decides how the effect looks, so it can change with iPadOS releases without a change here. The strip
of status bar above the bar still passes touches to the page, as it does in every scrolling app.
