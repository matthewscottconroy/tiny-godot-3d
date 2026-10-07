shader_type spatial;

// The same surface drawn two ways, so the difference is the demo.
//
// `use_triplanar = false` takes the mesh's own UVs, which this terrain derives
// from world X and Z — the ordinary way to texture a heightmap, and fine until
// the ground stands up. A vertical face has almost no extent in X or Z, so a
// sliver of the pattern is smeared down the whole height of it.
//
// `use_triplanar = true` ignores UV entirely and projects the pattern three
// times from world position — along X, along Y, along Z — then blends the three
// by how much the surface faces each axis. The wall is drawn by a projection
// that can see its height, so there is nothing to stretch.
//
// The blend weights are the same arithmetic as scripts/triplanar_mapping.gd,
// deliberately: the CPU and the shader have to agree about which projection is
// in charge, or anything the game decides from it disagrees with what is drawn.

uniform bool use_triplanar = true;
uniform float texture_scale : hint_range(0.05, 2.0) = 0.35;
uniform float sharpness : hint_range(1.0, 16.0) = 4.0;
uniform vec3 tint_a : source_color = vec3(0.82, 0.76, 0.64);
uniform vec3 tint_b : source_color = vec3(0.32, 0.30, 0.28);

varying vec3 world_position;
varying vec3 world_normal;

// A checker, computed rather than sampled. The collection ships no texture
// assets, and a checker is the honest choice anyway: stretching is obvious in
// it, where a noise texture hides it.
float checker(vec2 uv) {
	vec2 cell = floor(uv);
	return mod(cell.x + cell.y, 2.0);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float pattern;

	if (use_triplanar) {
		// Each projection drops the axis it looks along. Reading world position
		// rather than UV is the whole mechanism.
		float x_face = checker(world_position.zy * texture_scale);
		float y_face = checker(world_position.xz * texture_scale);
		float z_face = checker(world_position.xy * texture_scale);

		vec3 w = pow(abs(world_normal), vec3(sharpness));
		w /= max(w.x + w.y + w.z, 0.0001);

		pattern = x_face * w.x + y_face * w.y + z_face * w.z;
	} else {
		pattern = checker(UV * texture_scale * 16.0);
	}

	ALBEDO = mix(tint_b, tint_a, pattern);
	ROUGHNESS = 0.9;
}
