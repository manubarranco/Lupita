# Lens behaviour — the magnifier as a character

The cursor lens stops being a generic SF Symbol and becomes Lupita's character: a
magnifying glass with two pill eyes and no mouth. The eyes carry all the expression.
Approved by Manu on 2026-10-24 (D17). The reference is the interactive prototype in
[`lens-prototype.html`](lens-prototype.html): open it in a browser and move the pointer.
The prototype's look, timings and size are the target.

## Size

The current lens (30 pt panel, 26 pt disc, 14 pt glyph) is too small for the eyes to read.
The target is the prototype's: lens ring about 35 pt across, about 42 pt including the
handle, eyes about 4 × 9 pt. The panel grows to fit; the elastic string keeps its values.

## Drawing

In a 100-unit box centred on the lens: ring radius 38, stroke 8, round caps; handle from
(28, 28) to (52, 52), pointing down-right; disc filled with the surface colour. Eyes are
pill rects 10 wide and 22 tall, centred at x = ±9. Rendered at scale 0.42.

## Script

| Moment | Gesture | Trigger |
|---|---|---|
| Appear | Eyes open while it fades in | Shortcut held, after the existing 150 ms delay |
| Following | Eyes look toward the pointer, whatever the direction (offset up to 7 units) | While the lens moves |
| Resting | Eyes look straight ahead (design A) | Lens speed under 18 pt/s for 0.35 s |
| Focused | Eyes narrow to 7 units, looking at the pointer (design D); no blinking | String stretched past 62 % of `maxDistance` (≈ 112 pt): hard direction changes |
| Blink | 0.15 s close and open | Every 2.2-5.2 s at random, never while focused |
| Disappear | Eyes close as it fades out | Shortcut released |

All eye changes ease (about 0.2-0.3 per frame towards the target), never snap.

## Reduce Motion

Sticks below-right of the pointer as today, eyes straight ahead, no blinking, no easing.

## After the shortcut fires (D18)

Approved by Manu on 2026-10-24. The lens stays on screen after the shortcut is released:

| Moment | Gesture | Ends |
|---|---|---|
| Searching | Narrowed eyes on the word, the string no longer pulls | When the answer is on screen (gives up after 5 s) |
| Found | On top of the tooltip, which shows at once: eyes stretch, a 6 pt hop, a blink | 0.4 s |
| Not found | Looks left, right, left, then narrows | 1.1 s |
| Moving | Glides to the tooltip's right side (left if it does not fit), eyes on the tooltip | On arrival |
| Reading | Sweeps the lines, one line lower every 0.9 s (found only) | 2.7 s |
| Waiting | Looks at the tooltip, blinks | When the tooltip closes: closes its eyes and goes |

Pressing the shortcut again picks the same lens back up. With Reduce Motion none of this
happens: the lens goes when the shortcut is released, as before. The "not known" notice
stays until a click or Esc, like the tooltip: closing on its own after 1.5 s, it went before
it could be read, with the lens covering it for most of that time. The prototype's three
phase 2 buttons are an earlier take on this; the table wins.

## Check

A screenshot of the real lens at 1× must show where the eyes look. If it does not, the
eyes or the offsets grow before anything else changes.
