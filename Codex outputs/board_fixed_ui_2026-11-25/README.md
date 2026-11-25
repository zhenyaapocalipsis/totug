# Stage 1: fixed board and readable player table

Superseded by [Stage 2: native pixels and restored choice window](../board_native_ui_2026-11-25/README.md).

- Board seed: 122319638. The board has a permanent rectangle above a 104 px action strip. Showing a question, hiding it, or enabling Deploy for VP does not change that rectangle.
- Long questions and Explore/Lamia scroll inside the action strip. Choose one uses labeled buttons below the board.
- Played cards enter below the board and travel to the feed along the bottom, then up its column.
- Player names and numbers use separate complete lines. Numeric columns have wider cells and gaps; the right column is 20 px wider. Market cards keep their 58 x 84 size; vertical empty gaps were reclaimed for the table.
- Fitting avoids an abrupt 50% board scale caused by rounding down to whole physical pixels. Nearest filtering remains enabled.

Validation: fixed layout 176/176, localization 268/268, rigid board 27/27, network 168/168. Full suite result recorded in the chat; seed 42 exceeds the existing 6 second generation budget (about 20 seconds). Core map generation is unchanged.
