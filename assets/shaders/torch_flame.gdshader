shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;
uniform vec4 root_color : source_color = vec4(1.0, 0.84, 0.38, 1.0);
uniform vec4 tongue_color : source_color = vec4(1.0, 0.32, 0.035, 1.0);
varying float lift;

void vertex() {
	lift = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float tip = lift * lift;
	float t = TIME * 5.7 + phase;
	VERTEX.x += (sin(t + lift * 3.8) * 0.22 + sin(t * 1.79) * 0.08) * tip;
	VERTEX.z += cos(t * 0.96 + lift * 4.0) * 0.21 * tip;
	VERTEX.y *= 1.0 + 0.16 * sin(t * 1.23);
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(root_color.rgb, tongue_color.rgb, smoothstep(0.05, 0.91, lift)) * 2.0;
	ALPHA = (1.0 - rim) * (1.0 - smoothstep(0.44, 1.0, lift)) * 0.78;
}
