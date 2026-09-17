shader_type spatial;
render_mode specular_disabled, cull_disabled;

// Reusable four-way terrain: vertex RGBA = grass / mineral soil / loam / litter.
uniform vec4 grass_color : source_color = vec4(0.561,0.612,0.447,1.0);
uniform vec4 mineral_color : source_color = vec4(0.631,0.663,0.608,1.0);
uniform vec4 loam_color : source_color = vec4(0.647,0.612,0.494,1.0);
uniform vec4 litter_color : source_color = vec4(0.49,0.541,0.424,1.0);
uniform bool toon_enabled = true;
uniform float variation_strength : hint_range(0.0,0.5) = 0.23;
uniform float transition_breakup : hint_range(0.0,0.4) = 0.12;
uniform float village_seam_x = -26.0;
uniform float seam_direction = 1.0;
varying vec3 world_position;
varying vec4 weights;

float hash2(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),f.x),f.y);
}
float landscape_noise(vec2 p) {
 return noise2(p)*0.57+noise2(p*2.13+vec2(31.7,13.2))*0.28+noise2(p*4.31+vec2(7.2,71.5))*0.15;
}
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 weights=COLOR;
}
void fragment() {
 vec2 p=world_position.xz;
 float seam=smoothstep(0.0,5.5,(village_seam_x-p.x)*seam_direction);
 float wide=landscape_noise(p*0.19);
 float mid=landscape_noise(p*0.83+vec2(17.0));
 float fine=noise2(p*9.7);
 vec4 w=max(weights,vec4(0.0));
 // Perturb only mixed edges; keep the authored interior material recognizable.
 float border=w.r*w.g*4.0;
 float breakup=(mid-0.5)*transition_breakup*border;
 w.r=max(0.0,w.r+breakup); w.g=max(0.0,w.g-breakup);
 w/=max(dot(w,vec4(1.0)),0.001);
 vec3 base=grass_color.rgb*w.r+mineral_color.rgb*w.g+loam_color.rgb*w.b+litter_color.rgb*w.a;
 float damp=smoothstep(0.53,0.79,wide)*smoothstep(0.31,0.74,mid);
 float exposed=smoothstep(0.53,0.78,mid)*(1.0-damp);
 base*=1.0+((wide-0.5)*0.8+(mid-0.5)*0.6+(fine-0.5)*0.19)*variation_strength*seam;
 base=mix(base,base*vec3(0.88,0.93,0.92),damp*0.45*seam);
 base=mix(base,base*vec3(1.055,1.032,0.982),exposed*0.45*seam);
 // Fine mineral grains and short, sparse weathering streaks.
 float grains=step(0.89,hash2(floor(p*17.0)));
 float grit=step(0.93,hash2(floor(p*11.3+17.0)));
 base*=1.0+(grains*0.07-grit*0.055)*seam;
 ALBEDO=base;
 ROUGHNESS=1.0;
}
void light() {
 float n=max(dot(NORMAL,LIGHT),0.0);
 float shade=toon_enabled ? floor(n*3.0+0.001)/3.0 : n;
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*shade*ATTENUATION/PI;
}
