shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.08, 0.11, 0.14);
uniform vec3 deep_color : source_color = vec3(0.03, 0.05, 0.07);
uniform float base_roughness : hint_range(0.01, 0.25) = 0.038;
uniform float water_specular : hint_range(0.0, 1.0) = 0.58;

uniform float micro_wave_amp : hint_range(0.0, 0.1) = 0.014;
uniform float micro_wave_speed : hint_range(0.0, 2.0) = 0.12;

uniform vec2 ripple_center_0 = vec2(0.02, 0.20);   // Isabela front foot
uniform vec2 ripple_center_1 = vec2(-0.06, -0.22); // Isabela rear foot
uniform vec2 ripple_center_2 = vec2(-1.55, -2.40); // SK_Droid_Small
uniform vec2 ripple_center_3 = vec2(1.75, -2.85);  // SK_Droid_Tall
uniform float ripple_amp : hint_range(0.0, 0.2) = 0.045;
uniform float ripple_freq : hint_range(1.0, 40.0) = 18.0;
uniform float ripple_speed : hint_range(0.0, 10.0) = 2.6;
uniform float ripple_radius : hint_range(0.2, 6.0) = 1.65;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 concentric_grad(vec2 p, vec2 center, float t) {
	vec2 d = p - center;
	float dist = length(d);
	if (dist < 0.04 || dist > ripple_radius) {
		return vec2(0.0);
	}
	float atten = (1.0 - smoothstep(0.15, ripple_radius, dist)) * smoothstep(0.04, 0.12, dist);
	float phase = dist * ripple_freq - t * ripple_speed;
	float deriv = cos(phase) * ripple_freq * ripple_amp * atten;
	return (d / dist) * deriv;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME;

	// Multi-directional micro-wave normal derivatives
	vec2 grad = vec2(0.0);
	float p1 = p.x * 3.1 + p.y * 2.4 + t * micro_wave_speed * 6.0;
	float p2 = p.x * -2.7 + p.y * 3.8 - t * micro_wave_speed * 5.2;
	float p3 = p.x * 6.4 + p.y * -5.1 + t * micro_wave_speed * 8.4;
	grad += vec2(3.1, 2.4) * cos(p1) * micro_wave_amp * 0.45;
	grad += vec2(-2.7, 3.8) * cos(p2) * micro_wave_amp * 0.35;
	grad += vec2(6.4, -5.1) * cos(p3) * micro_wave_amp * 0.20;

	// Concentric radial ripples around Isabela's feet and both droids
	grad += concentric_grad(p, ripple_center_0, t);
	grad += concentric_grad(p, ripple_center_1, t + 0.35);
	grad += concentric_grad(p, ripple_center_2, t + 0.80);
	grad += concentric_grad(p, ripple_center_3, t + 1.25);

	vec3 world_n = normalize(vec3(-grad.x, 1.0, -grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep_color, shallow_color, fresnel);
	METALLIC = 0.0;
	SPECULAR = water_specular;
	ROUGHNESS = clamp(base_roughness + length(grad) * 0.12, 0.02, 0.15);
}
