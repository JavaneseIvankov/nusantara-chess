shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 rim_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform float fresnel_power : hint_range(1.0, 8.0) = 2.8;
uniform float intensity : hint_range(0.0, 5.0) = 1.6;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.5;

void fragment() {
	// Hitung sudut pandang terhadap normal permukaan (Efek Fresnel)
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);
	
	// Denyut halus berbasis waktu
	float pulse = 0.78 + 0.22 * sin(TIME * pulse_speed);
	
	ALBEDO = rim_color.rgb * intensity * pulse;
	ALPHA = fresnel * rim_color.a;
}