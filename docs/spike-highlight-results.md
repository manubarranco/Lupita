# Spike: OCR of a whole window (highlight mode)

Question: can Lupita read the whole window under the pointer fast enough to underline what it
knows while ⌃⌥⌘ is held? Script: [`scripts/ocr-window-bench.swift`](../scripts/ocr-window-bench.swift).
Same Vision configuration as `OCR.swift` (`es-ES` + `en-US`, no language correction).
Median of 5 runs after one warm-up, Apple Silicon, 2026-10-25. Captures are Retina windows taken
with `screencapture -l` (2× scale); they are not committed (they show private content).

## Time and words

| Capture | Pixels | Level | Median | Words |
|---|---|---|---|---|
| VS Code, window | 2940×1686 | accurate | 0.13 s | 332 |
| VS Code, window | 2940×1686 | fast | 0.05 s | 412 |
| VS Code, 1000×400 pt crop | 2000×800 | accurate | 0.10 s | 143 |
| VS Code, 1000×400 pt crop | 2000×800 | fast | 0.02 s | 194 |
| Claude, window | 2940×1666 | accurate | 0.10 s | 271 |
| Claude, window | 2940×1666 | fast | 0.03 s | 248 |
| Claude, 1000×400 pt crop | 2000×800 | accurate | 0.10 s | 85 |
| Claude, 1000×400 pt crop | 2000×800 | fast | 0.01 s | 75 |
| Chrome, window | 2940×1666 | accurate | 0.12 s | 266 |
| Chrome, window | 2940×1666 | fast | 0.03 s | 245 |
| Chrome, 1000×400 pt crop | 2000×800 | accurate | 0.09 s | 79 |
| Chrome, 1000×400 pt crop | 2000×800 | fast | 0.01 s | 74 |

## Do IDs survive? (`--ids`: 12 IDs drawn in Menlo at Retina)

IDs: `D23`, `L04`, `E2-S3`, `QL25`, `D6`, `D14`, `E2-S4`, `Q01`, `D006`.

| Text | Accurate | Fast |
|---|---|---|
| 11 pt, light | 12/12 | 11/12 |
| 13 pt, light | 12/12 | 9/12 (missed `Q01`) |
| 15 pt, light | 12/12 | 12/12 |
| 11, 13, 15 pt, dark | 12/12 each | 11/12, 12/12, 12/12 |

## Conclusion

The whole window fits: `.accurate` reads it in about 0.1 s, five times under the 0.5 s limit, so there is no need to restrict to the area near the pointer. `.fast` is quicker but dropped IDs in light text at 13 pt, so use `.accurate`.

## Caveats

- Times are Vision only. The ScreenCaptureKit capture of the window adds its own time (not measured here; the current strip capture is already inside the hold-to-look path).
- The real captures contained no IDs, so ID reading was tested on drawn text, not on real agent chats.
- The 0.5 s criterion holds with a wide margin, but busy windows (long diffs, dense terminals) were not in the sample.
