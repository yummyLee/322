shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform bool outlines = true;
uniform bool highlights = true;
uniform float pixel_size : hint_range(1.0, 12.0, 1.0) = 1.0;
float depth_at(vec2 uv, mat4 inv_proj) {
 vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
 return -p.z / p.w;
}
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
 vec2 px = vec2(pixel_size) / VIEWPORT_SIZE;
 vec2 center_uv = min((floor(SCREEN_UV / px) + 0.5) * px, vec2(1.0) - 0.5 / VIEWPORT_SIZE);
 vec3 col = texture(screen_tex, center_uv).rgb;
 float d = depth_at(center_uv, INV_PROJECTION_MATRIX);
 vec3 n = texture(normal_tex, center_uv).rgb * 2.0 - 1.0;
 float edge = 0.0;
 float detail = 0.0;
 for (int i = 0; i < 4; i++) {
  vec2 dir = vec2(0.0);
  if (i == 0) { dir.x = 1.0; } else if (i == 1) { dir.x = -1.0; }
  else if (i == 2) { dir.y = 1.0; } else { dir.y = -1.0; }
  vec2 uv = center_uv + dir * px;
  float nd = depth_at(uv, INV_PROJECTION_MATRIX);
  vec3 nn = texture(normal_tex, uv).rgb * 2.0 - 1.0;
  edge = max(edge, step(0.22, nd - d));
  detail = max(detail, step(0.22, 1.0 - dot(n, nn)) * (1.0 - step(0.2, abs(nd - d))) * step(0.05, n.y - nn.y));
 }
 if (highlights) { col = mix(col, min(col * 1.3 + 0.04, vec3(1.0)), detail * 0.65); }
 if (outlines) { col = mix(col, col * vec3(0.42, 0.46, 0.57), edge * 0.8); }
 ALBEDO = col;
}
