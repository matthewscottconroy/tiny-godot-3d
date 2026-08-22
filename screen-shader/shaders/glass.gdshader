shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// Refraction by reading the screen behind the surface.
//
// `hint_screen_texture` is the Godot 4 spelling, and the sampler flags matter:
// `filter_linear_mipmap` so the blur below has mipmaps to reach for, and
// `repeat_disable` so an offset that runs off the edge of the screen does not
// wrap the far side of the frame into the glass.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform float strength : hint_range(0.0, 0.2) = 0.05;
uniform float roughness_blur : hint_range(0.0, 4.0) = 0.0;
uniform float fresnel_power : hint_range(1.0, 8.0) = 5.0;
uniform vec3 tint : source_color = vec3(0.75, 0.9, 0.95);

void fragment() {
	// The normal in view space is the direction to bend in. A surface facing the
	// camera has no sideways normal and so bends nothing — which is why glass
	// looks like glass at its edges and like a window in the middle.
	vec2 offset = NORMAL.xy * strength;
	// Aspect correction, or the glass refracts further sideways than vertically
	// and the effect stretches when the window is resized.
	offset.x /= (VIEWPORT_SIZE.x / VIEWPORT_SIZE.y);

	vec2 uv = SCREEN_UV + offset;
	vec3 behind = textureLod(screen, uv, roughness_blur).rgb;

	// Schlick's approximation. Edge-on, everything is a mirror; face-on, glass
	// is nearly invisible.
	float facing = abs(dot(normalize(VIEW), normalize(NORMAL)));
	float rim = pow(1.0 - facing, fresnel_power);

	ALBEDO = mix(behind * tint, vec3(1.0), rim * 0.35);
	// depth_draw_never above, and this: the surface is a lens rather than an
	// object, so it must not write depth over what it is showing.
	ALPHA = 1.0;
}
