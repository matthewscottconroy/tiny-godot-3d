class_name Volumetrics
extends RefCounted

## Fog with light in it: how thick, how far, and what it costs.
##
## Distance fog is a colour blended in by depth — cheap, and it cannot have a
## light shaft in it, because nothing is actually *there*. Volumetric fog fills a
## froxel grid in front of the camera, marches light through it, and produces
## shafts, glows and haze that respond to the lights in the scene.
##
## It also has a reputation for doing nothing at all when switched on, and the
## reasons are always the same three:
##
##   * **Forward+ only.** The Mobile and Compatibility renderers do not have it.
##     No warning, no fallback: the checkbox is simply ignored.
##   * **The lights have to opt in.** `light_volumetric_fog_energy` is zero-ish
##     by default on a light that has not been told about fog, and a shaft needs
##     a light that is contributing to the fog volume.
##   * **The volume ends.** `volumetric_fog_length` is how far the froxel grid
##     reaches — 64 metres by default. Beyond it there is no fog at all, and the
##     seam is visible on anything larger than a room.
##
## The arithmetic here is the physical model the renderer approximates, kept
## where the game can use it: how far you can see, and what density gets you the
## visibility you wanted.

## How much light survives this much fog over this distance, 0..1.
##
## Beer-Lambert. Extinction is exponential, not linear, which is why doubling
## the density does far more than halve the visibility.
static func transmittance(density: float, distance: float) -> float:
	return exp(-maxf(density, 0.0) * maxf(distance, 0.0))


## How far you can see before only `threshold` of the light gets through.
##
## The number to design with: "you can see 40 metres" is a decision, and density
## is what implements it.
static func visibility(density: float, threshold: float = 0.05) -> float:
	if density <= 0.0:
		return INF
	return -log(clampf(threshold, 0.0001, 0.9999)) / density


## The density that gives you that visibility.
##
## The inverse, and the one you actually want: pick the distance the level
## should read at, and let this choose the number.
static func density_for(visible_distance: float, threshold: float = 0.05) -> float:
	if visible_distance <= 0.0:
		return INF
	return -log(clampf(threshold, 0.0001, 0.9999)) / visible_distance


## Fog that thins with height, as a multiplier on the base density.
##
## Ground mist rather than a uniform soup. `falloff` is the height over which it
## drops to about a third.
static func height_density(base: float, height: float, floor_height: float = 0.0,
		falloff: float = 6.0) -> float:
	if falloff <= 0.0:
		return base if height <= floor_height else 0.0
	return base * exp(-maxf(height - floor_height, 0.0) / falloff)


## Is any of this going to be drawn?
##
## Volumetric fog is a Forward+ feature. On Mobile or Compatibility the setting
## is ignored silently, which is the single commonest reason it "does not work".
static func supported(rendering_method: String) -> bool:
	return rendering_method == "forward_plus"


## How much of the froxel grid a distance uses, 0..1, or above 1 for beyond it.
##
## Past the end of the volume there is no fog at all. On anything bigger than a
## room the seam is visible, and the fix is the length rather than the density.
static func within_volume(distance: float, volume_length: float) -> float:
	if volume_length <= 0.0:
		return INF
	return distance / volume_length


## Roughly how many froxels the volume costs at this detail.
##
## Not an engine number — an order of magnitude, so "make the fog denser" and
## "make the fog reach further" can be told apart before profiling.
static func froxel_count(resolution: Vector2i, depth_slices: int) -> int:
	return maxi(resolution.x, 1) * maxi(resolution.y, 1) * maxi(depth_slices, 1)
