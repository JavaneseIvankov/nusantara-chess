shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.84, 0.75, 0.59, 1.0);
uniform vec4 vein_color : source_color = vec4(0.69, 0.62, 0.48, 1.0);
uniform bool is_wood_grain = false;
uniform float pattern_scale = 3.2;
uniform float bump_strength = 0.28;
uniform float base_roughness = 0.55;
uniform float tile_seed = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float height_at(vec2 uv) {
	vec2 p = uv * pattern_scale + vec2(tile_seed * 3.7, tile_seed * 1.9);
	float cloud = 0.64 * noise2(p) + 0.26 * noise2(2.15 * p) + 0.1 * noise2(4.55 * p);
	float hairline = pow(1.0 - abs(sin((p.x + 0.71 * p.y + 2.5 * cloud) * 1.28)), 11.0);
	float grain = 0.5 + 0.5 * sin(p.x * 13.0 + cloud * 4.0 + p.y * 0.6);
	return is_wood_grain ? mix(cloud, grain, 0.19) : mix(cloud, 1.0 - hairline, 0.20);
}

void fragment() {
	vec2 p = local_pos.xz;
	float h = height_at(p);
	float speckle = noise2(p * 105.0 + vec2(tile_seed));
	float edge_distance = max(abs(p.x), abs(p.y));
	float inner_border = 1.0 - smoothstep(0.002, 0.008, abs(edge_distance - 0.455));
	vec2 corner_uv = abs(p) - vec2(0.399);
	float diamond = 1.0 - smoothstep(0.003, 0.008, abs(abs(corner_uv.x) + abs(corner_uv.y) - 0.027));
	float corner_dot = 1.0 - smoothstep(0.004, 0.01, length(corner_uv));
	float top = step(0.9, local_normal.y);
	vec3 stone = mix(vein_color.rgb, base_color.rgb, h) * (0.985 + 0.04 * speckle);
	vec3 trim = mix(vein_color.rgb, vec3(0.62, 0.43, 0.23), 0.25);
	ALBEDO = mix(stone, trim, top * clamp(inner_border * 0.32 + diamond * 0.38 + corner_dot * 0.6, 0.0, 1.0));
	ALBEDO *= mix(0.71, 1.0, 1.0 - smoothstep(0.487, 0.5, edge_distance));
	if (top > 0.5) {
		float dx = h - height_at(p + vec2(0.007, 0.0));
		float dz = h - height_at(p + vec2(0.0, 0.007));
		vec3 n = normalize(vec3(dx * bump_strength, 1.0, dz * bump_strength));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
	ROUGHNESS = clamp(base_roughness + (0.55 - h) * 0.18, 0.25, 0.97);
	SPECULAR = 0.39;
}
