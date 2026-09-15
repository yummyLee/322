shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
void fragment() {
    ALBEDO = base_color.rgb;
    EMISSION = base_color.rgb * 0.32;
    ROUGHNESS = 1.0;
}
void light() {
    float n = dot(NORMAL, LIGHT);
    float band = n > 0.65 ? 1.0 : (n > 0.15 ? 0.78 : 0.46);
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * mix(0.45, 1.0, ATTENUATION) / PI;
}
