shader_type spatial;

// Four materials mixed by the weights baked into the mesh's vertex colours.
//
// The weights come from the CPU — scripts/splat.gd — so the game and the shader
// agree about what the ground is made of. A footstep sound that disagrees with
// what the player can see is worse than no footstep sound.

uniform vec3 sand : source_color = vec3(0.76, 0.70, 0.50);
uniform vec3 grass : source_color = vec3(0.30, 0.45, 0.22);
uniform vec3 rock : source_color = vec3(0.42, 0.40, 0.38);
uniform vec3 snow : source_color = vec3(0.92, 0.94, 0.97);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	// COLOR carries the four weights: sand, grass, rock, snow. They were
	// normalised on the way in, so this is a weighted average rather than a sum
	// that can exceed one and blow out the highlights.
	vec3 ground = sand * COLOR.r + grass * COLOR.g + rock * COLOR.b + snow * COLOR.a;

	// A little variation by height, so a large flat area of one material is not
	// a large flat area of one colour.
	float shade = 1.0 - tint_strength * 0.5 + tint_strength * fract(VERTEX.y * 0.35);
	ALBEDO = ground * shade;
	ROUGHNESS = mix(0.95, 0.6, COLOR.b);
}
