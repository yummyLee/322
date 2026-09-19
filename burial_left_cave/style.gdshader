shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform vec4 base_color : source_color = vec4(0.5,0.5,0.4,1);
uniform bool toon_enabled = true;
// Cave floors use broad, continuous variation.  High-frequency hash dots make
// the ground read like a tiled point texture at the game's pixel scale.
uniform float grain = 0.028;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float broad_a = sin(world_position.x*0.47 + world_position.z*0.19);
 float broad_b = cos(world_position.x*0.21 - world_position.z*0.53);
 float broad = broad_a*0.55 + broad_b*0.45;
 ALBEDO = base_color.rgb*(1.0+broad*grain);
 EMISSION = base_color.rgb * 0.10;
 ROUGHNESS = 1.0;
}
void light() {
 float n = max(dot(NORMAL,LIGHT),0.0);
 float shade = toon_enabled ? floor(n*3.0+0.001)/3.0 : n;
 DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*shade*ATTENUATION/PI;
}
