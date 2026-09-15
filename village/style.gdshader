shader_type spatial;
render_mode specular_disabled;
uniform vec4 base_color : source_color = vec4(0.5,0.5,0.4,1);
uniform bool toon_enabled = true;
uniform float grain = 0.075;
varying vec3 world_position;
float hash3(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float fine = hash3(floor(world_position*13.0));
 float patches = hash3(floor(world_position*3.0));
 ALBEDO = base_color.rgb*(1.0+(fine-0.5)*grain+(patches-0.5)*grain*0.55);
 ROUGHNESS = 1.0;
}
void light() {
 float n = max(dot(NORMAL,LIGHT),0.0);
 float shade = toon_enabled ? floor(n*3.0+0.001)/3.0 : n;
 DIFFUSE_LIGHT += ALBEDO*LIGHT_COLOR*shade*ATTENUATION/PI;
}
