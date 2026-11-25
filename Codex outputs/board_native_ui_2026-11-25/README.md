# Stage 2: native board pixels and restored choice window

Supersedes Stage 1 UI fitting.

- Board zoom is strictly 1.0; there is no automatic downscaling. Board generation and tile geometry are unchanged.
- Full-size Choose one option cards, dimming, Hide and Show are restored. Showing or hiding the window never changes the board transform.
- Board and troop textures share one origin; troop corners are not rounded independently.
- Resources and questions sit lower. The two gaps around resources are 2 logical pixels. Hand hover lift is 2 pixels; the hand clears the counters when lifted. Empty font leading was removed without changing glyph size.
- The top of the board reserves space for spies. End Turn and its timer moved up by 2 logical pixels.
- Deploy for VP sits beside the counters and does not consume vertical space or move the board.
- Player rows retain full text lines; cells retain the complete 12-pixel advance for two digits and a 2-pixel column gap. The column fits four two-digit trophy counts at the normal font size.

Checks: seeds 122319638 and 1795618768, English/Russian, 2/4 players: 748 and 746 checks passed; native bounds: eight other 2/3/4-player boards fit; player UI: 119 passed; localization: 268 passed; choice protocol: 25 passed. Full suite: 3209 passed, 1 existing generation time failure for seed 42 (6 second budget). No map generator changes.

The PNGs show synthetic regression views with troops and spies placed for visibility; the choice window also uses synthetic options.
