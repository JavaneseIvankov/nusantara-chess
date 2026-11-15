shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.87, 0.77, 0.60, 1.0);
uniform vec4 vein_color : source_color = vec4(0.68, 0.56, 0.38, 1.0);
uniform bool is_wood_grain = false;
uniform float pattern_scale : hint_range(1.0, 20.0) = 6.5;
uniform float bump_strength : hint_range(0.0, 3.0) = 1.1;
uniform float base_roughness : hint_range(0.1, 1.0) = 0.45;
uniform float tile_seed = 0.0;

// Hash 2D deterministik tanpa tekstur eksternal
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 2D Value Noise halus
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian Motion (4 oktaf)
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

// Evaluasi tinggi permukaan prosedural (Kayu Jati vs Batu Andesit/Marmer)
float eval_height(vec2 uv) {
	vec2 p = uv * pattern_scale + vec2(tile_seed * 3.7, tile_seed * 1.9);
	float n = fbm(p);
	if (is_wood_grain) {
		// Pola cincin serat kayu jati
		float rings = sin((p.x * 2.2 + n * 5.5) * 3.14159);
		return 0.5 + 0.5 * rings;
	} else {
		// Pola urat marmer & pori batu candi
		float marble = abs(sin((p.x + p.y * 0.6 + n * 3.2) * 3.14159));
		return mix(n, marble, 0.55);
	}
}

void fragment() {
	// Gunakan koordinat dunia XZ agar pola menyambung alami dan tidak terdistorsi ketebalan petak
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 sample_uv = world_pos.xz;
	
	float h = eval_height(sample_uv);
	
	// Hitung gradien turunan hingga untuk Normal Map prosedural
	float eps = 0.008;
	float hx = eval_height(sample_uv + vec2(eps, 0.0));
	float hz = eval_height(sample_uv + vec2(0.0, eps));
	vec3 proc_normal = normalize(vec3((h - hx) * bump_strength, 1.0, (h - hz) * bump_strength));
	
	// Konversi normal dunia ke View Space Godot
	NORMAL = normalize((VIEW_MATRIX * vec4(proc_normal, 0.0)).xyz);
	
	// Campurkan warna dasar dan urat, serta variasi kilap (roughness)
	ALBEDO = mix(vein_color.rgb, base_color.rgb, smoothstep(0.15, 0.85, h));
	ROUGHNESS = clamp(base_roughness + (0.5 - h) * 0.25, 0.15, 0.95);
	METALLIC = 0.06;
}