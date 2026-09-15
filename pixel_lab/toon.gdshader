shader_type spatial;
render_mode specular_disabled;
uniform vec4 base_color : source_color = vec4(0.4, 0.6, 0.3, 1.0);
uniform bool toon_enabled = true;
void fragment() { ALBEDO = base_color.rgb; ROUGHNESS = 1.0; }
void light() {
 float n = max(dot(NORMAL, LIGHT), 0.0);
 float shade = toon_enabled ? floor(n * 3.0 + 0.001) / 3.0 : n;
 DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade * ATTENUATION / PI;
}
