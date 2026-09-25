# Rajasthan map art

The map landmarks are original geometry authored with Blender 4.5.3. Their
silhouette layering and atmospheric colors take broad inspiration from the
provided reference; its architecture, layout and artwork are not reproduced.

## Editable source

`art_sources/rajasthan_landmarks.blend` contains a separate scene for each asset:

- `moon_palace`: rose-stone terraced waterfront palace with amber windows.
- `desert_observatory`: sandstone palace crowning Registan's fort.
- `caravan_gate`: arched gateway with copper-roofed pavilions.
- `oasis_pavilion`: open pavilion beside the oasis.
- `brass_lantern`: reusable emissive lantern.
- `flight_terrace`: open flying roof with low forward parapets.

`build_map_art.py` rebuilds the source and the material-batched GLBs in
`assets/map_art`. Run it with Blender's `--background --python` arguments.
Godot uses the GLBs; Blender is not needed to play the game.

## Maps

Registan retains its moving caravan, drifting thermals and dust devils, with
an expanded fort skyline, new gate, carved oasis basin, and more readable fill
lighting. Jaipur Night is a separate selectable map with a lake, illuminated
palace, layered surrounding hills, moon and stars, rooftop lanterns, and
neighborhoods on the shore. Both provide player/rival roofs and rocket pads.

## Local verification

Set `KITE_MAP` to `registan` or `jaipur_night`.

- Run Godot with `--headless --editor --import` after rebuilding models.
- `--script tools/preview_maps.gd` captures vista, terrace and landmark views
  in `art_previews/` and updates the map's selection thumbnail. With
  `--headless`, it checks only map spawn and collision contracts.
- `--script tools/smoke_maps.gd --quit-after 1000` exercises the actual game
  scene, character and map selection, and four seconds of kite battle. In a
  rendered run it also captures the map menu and gameplay.
- Redirect `APPDATA` to `.tools/test_userdata` for smoke tests to isolate the
  test profile from the player's saved profile. Use an explicit `--log-file`
  inside `.tools` when running with restricted filesystem permissions.

The two water treatments use inexpensive animated stylized glints, not
screen-space reflections. Lantern meshes emit light visually; only the two
playable rooftops use local point lights to keep rendering cost bounded.
