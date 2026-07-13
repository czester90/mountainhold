shader_type spatial;

// Neutral inspection floor with a 1 m grid (bright line every 5 m).
// Grid is drawn in world space so it reads at true metric scale.

uniform vec3 base_color : source_color = vec3(0.20, 0.20, 0.22);
uniform vec3 line_color : source_color = vec3(0.33, 0.33, 0.37);
uniform vec3 major_color : source_color = vec3(0.55, 0.56, 0.62);

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = wpos.xz;

	vec2 d1 = abs(fract(g) - 0.5);
	float minor = min(d1.x, d1.y);

	vec2 d5 = abs(fract(g / 5.0) - 0.5) * 5.0;
	float major = min(d5.x, d5.y);

	float fw = fwidth(wpos.x) * 1.5 + 0.001;

	vec3 col = base_color;
	col = mix(line_color, col, smoothstep(0.0, fw, minor));
	col = mix(major_color, col, smoothstep(0.0, fw * 2.0, major));

	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
