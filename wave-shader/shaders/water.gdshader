shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// The same sum of directional sines as scripts/wave_field.gd, in GLSL. Every
// parameter arrives as a uniform from WaveField.apply_to(), so the two copies
// cannot be configured differently — only written differently.

const int MAX_WAVES = 4;

uniform int wave_count = 3;
uniform float amplitudes[MAX_WAVES];
uniform float wavelengths[MAX_WAVES];
uniform float speeds[MAX_WAVES];
uniform vec2 directions[MAX_WAVES];
uniform float swell = 1.0;

// The clock is a parameter too. Using the built-in TIME would mean the shader
// and the GDScript that floats things on this water were reading two different
// clocks — they would drift, and pausing would move the water out from under
// everything. The CPU owns the time and sends it.
uniform float time = 0.0;

uniform vec4 shallow_colour : source_color = vec4(0.25, 0.55, 0.65, 1.0);
uniform vec4 deep_colour : source_color = vec4(0.05, 0.18, 0.32, 1.0);

float wave_height(vec2 position, float at) {
	float height = 0.0;
	for (int i = 0; i < MAX_WAVES; i++) {
		if (i >= wave_count) {
			break;
		}
		float k = TAU / wavelengths[i];
		float phase = dot(directions[i], position) * k + at * speeds[i] * k;
		height += sin(phase) * amplitudes[i];
	}
	return height * swell;
}

void vertex() {
	// Displace along the surface normal's axis. VERTEX is in model space, and
	// the plane lies in XZ, so the height goes straight into Y.
	VERTEX.y += wave_height(VERTEX.xz, time);

	// The normal has to move with the surface or the lighting stays flat and
	// the whole effect looks like a texture. Sampled either side, exactly as
	// WaveField.normal_at() does it.
	float step = 0.25;
	float dx = wave_height(VERTEX.xz + vec2(step, 0.0), time)
		- wave_height(VERTEX.xz - vec2(step, 0.0), time);
	float dz = wave_height(VERTEX.xz + vec2(0.0, step), time)
		- wave_height(VERTEX.xz - vec2(0.0, step), time);
	NORMAL = normalize(vec3(-dx, 2.0 * step, -dz));
}

void fragment() {
	// Steeper faces read as deeper water: cheap, and enough to see the shape.
	float facing = clamp(dot(NORMAL, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	ALBEDO = mix(deep_colour, shallow_colour, facing).rgb;
	ROUGHNESS = 0.15;
	METALLIC = 0.1;
}
