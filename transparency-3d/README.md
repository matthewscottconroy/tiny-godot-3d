# Transparency

<!-- tags: camera, ui, component, shows-its-working -->

Why transparent objects draw in the wrong order, and the three ways out: sorting, scissor, and hash.

## Purpose

Opaque geometry sorts itself. The depth buffer keeps the nearest fragment and
the order things arrive in does not matter.

Transparency has no such luxury: a translucent surface must be blended *over*
whatever is behind it, so it has to be drawn afterwards. The renderer therefore
sorts transparent objects back to front — and everything that goes wrong with
transparency follows from two facts about that sort.

**It is per object, not per pixel.** Two transparent objects that intersect
cannot be ordered at all. Whichever is drawn second wins along the whole
overlap, and no amount of sorting fixes it.

**It sorts by depth, not by distance.** An object off to one side can be further
away in a straight line while being nearer along the view direction. Sort by
`distance_to()` and the order changes as the camera turns, so the picture
flickers between two arrangements with nothing moving.

## Controls

| Key | Action |
|-----|--------|
| 1 | Alpha blend — correct colours, ordering problems |
| 2 | Alpha scissor — hard edges, no ordering problems |
| 3 | Alpha hash — dithered, no ordering problems |
| S | Force an explicit draw order with `render_priority` |
| Space | Pause the orbit |

The readout counts pairs of panes that overlap in depth. Those are the ones no
order can fix — switch to scissor and they resolve, because each pixel is then
opaque or absent.

## How It Works

**Depth, not distance.** `AlphaSorter.depth_of()` projects a point onto the
camera's view direction. That is what the renderer sorts by, and it is stable as
the camera turns; a straight-line distance is not.

**`render_priority` overrides the depth sort.** Godot sorts transparent
materials by priority first and depth second. Use it only for what depth cannot
express — a windscreen that must always draw over the dashboard behind it, a
world-space UI panel. It is a signed byte, so a long list has to clamp rather
than wrap; wrapping sends the last objects to the front.

**Alpha scissor makes the problem go away.** Each pixel is either drawn fully or
not at all, so the material writes depth and sorts itself per pixel. Hard edges
are the price. For foliage, chain-link fences and anything with a cut-out shape,
that is not a price at all — it is what you wanted.

**Alpha hash is scissor with a dither.** Still per-pixel and depth-writing, but
the threshold is randomised so partial transparency reads as noise rather than a
hard edge. It wants temporal antialiasing to look right, and with it, it is the
cheapest way to have soft transparency that still sorts.

**Transparent surfaces usually want two sides.** A single-sided quad disappears
when you walk around it, which looks exactly like a sorting bug and is not one.
Every pane here sets `cull_mode = CULL_DISABLED`, and the suite checks it.

## Key Godot APIs

| API | Purpose |
|-----|---------|
| `BaseMaterial3D.transparency` | Disabled, alpha, alpha scissor, alpha hash |
| `BaseMaterial3D.alpha_scissor_threshold` | Where the cut-out edge falls |
| `BaseMaterial3D.render_priority` | Forcing a draw order the depth sort cannot express |
| `BaseMaterial3D.cull_mode` | Two-sided transparency |
| `GeometryInstance3D.material_override` | A material per instance, sharing one mesh |
| `MeshInstance3D.get_aabb()` | The bounds the depth-range test works from |

## Files

| File | What it holds |
|------|---------------|
| `scripts/alpha_sorter.gd` | The `AlphaSorter` component: depth, ordering, priorities, and the unsortable test |
| `scripts/main.gd` | Demo driver: the three modes, and applying an order |
| `scenes/main.tscn` | Four panes and one crossing them, each with its own material |
| `tests/test_logic.gd` | Headless test suite — including the real materials |

## Use as a building block

**Copy:** `scripts/alpha_sorter.gd` — the `AlphaSorter` type. `scripts/main.gd`
is the demo driver and is not needed.

**Public API**
- `AlphaSorter.depth_of(point, camera_position, camera_forward) -> float`
- `AlphaSorter.back_to_front(points, camera_position, camera_forward) -> Array[int]`
- `AlphaSorter.priorities(count, first_drawn_first := true) -> Array[int]`
- `AlphaSorter.depth_ranges_overlap(a: AABB, b: AABB, camera_position, camera_forward) -> bool`

**Integrate**
1. Let the renderer sort. Reach for `render_priority` only when you can name the
   pair that is coming out wrong, and set it for those objects rather than for
   all of them.
2. Use `depth_ranges_overlap()` in a debug view to *find* the pairs that cannot
   be sorted. Once you know which they are, the fix is nearly always to change
   the geometry or the material mode, not the order.
3. Default to alpha scissor for anything with a cut-out silhouette, and keep
   blending for glass, water and smoke, where the whole surface is translucent.

**Notes**
- `class_name AlphaSorter` is global to the project — rename it if you already
  define that type.
- Sorting is per *object*, so splitting one big transparent mesh into several
  smaller ones can genuinely improve the ordering. It also multiplies the draw
  calls, which is the trade.
- `depth_ranges_overlap()` uses axis-aligned bounds, so it is conservative: it
  reports some pairs that would in fact sort. That is the right way round for a
  warning.

## Related demos

- [screen-shader](../screen-shader) — A shader that reads the screen behind it — refraction, fresnel, and the thing it cannot see.
- [wave-shader](../wave-shader) — A water surface displaced in a shader, with the same wave maths in GDScript so things can float on it.
- [camera-framing](../camera-framing) — A camera that keeps several things on screen at once — the RTS and party-game problem, as arithmetic.
- [level-streaming](../level-streaming) — Loading and freeing chunks around a moving player, with the keep-radius that stops them thrashing at a boundary.

<sub>Generated by `tools/build_index.py` from shared APIs and [learning path](../docs/LEARNING_PATHS.md) adjacency.</sub>

