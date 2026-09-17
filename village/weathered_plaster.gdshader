shader_type spatial;
render_mode specular_disabled;
uniform vec4 base_color : source_color = vec4(0.68,0.60,0.43,1.0);
uniform bool toon_enabled = true;
uniform float wear_strength = 0.65;
varying vec3 wp;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=vec2(wp.x+wp.z*0.71,wp.y);
 float broad=n(uv*vec2(1.3,1.9));
 float fleck=n(uv*vec2(6.5,8.0));
 float damp=(1.0-smoothstep(0.22,0.88+n(uv.xx*3.0)*0.3,wp.y));
 float run=(1.0-smoothstep(0.16,0.33,n(uv*vec2(8.0,0.5))))*0.2;
 vec3 col=base_color.rgb*(1.0+(broad-0.5)*0.24*wear_strength+(fleck-0.5)*0.09);
 col=mix(col,col*vec3(0.63,0.72,0.64),damp*wear_strength*0.65);
 col*=1.0-run*wear_strength;
 ALBEDO=col;ROUGHNESS=1.0;
}
void light(){float n=max(dot(NORMAL,LIGHT),0.0);float s=toon_enabled?floor(n*3.0+0.001)/3.0:n;DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*s*ATTENUATION/PI;}
