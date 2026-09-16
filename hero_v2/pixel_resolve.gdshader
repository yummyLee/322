shader_type canvas_item;
render_mode unshaded;
uniform vec2 pixel_grid = vec2(480.0,270.0);
uniform bool pixel_enabled = true;
uniform bool coverage_filter = true;
uniform bool occlusion_enabled = false;
uniform bool depth_ready = false;
uniform sampler2D environment_depth : filter_nearest, repeat_disable;
uniform sampler2D character_depth : filter_nearest, repeat_disable;
// Both cameras use the same projection and reverse-Z depth range.
uniform float depth_bias = 0.00002;
vec4 visible_sample(sampler2D source, vec2 uv) {
    vec4 color = texture(source, uv);
    if (occlusion_enabled) {
        if (!depth_ready) return vec4(0.0);
        float scene_z = texture(environment_depth, uv).r;
        float hero_z = texture(character_depth, uv).r;
        if (scene_z > hero_z + depth_bias) return vec4(0.0);
    }
    return color;
}
void fragment() {
    if (!pixel_enabled) {
        COLOR = visible_sample(TEXTURE,UV);
    } else {
        vec2 center = (floor(UV*pixel_grid)+vec2(0.5))/pixel_grid;
        if (coverage_filter) {
            // Four spatial samples per logical pixel. No history, blur pass or ghosting.
            vec2 q = vec2(0.25)/pixel_grid;
            COLOR = (visible_sample(TEXTURE,center+vec2(-q.x,-q.y))
                   + visible_sample(TEXTURE,center+vec2( q.x,-q.y))
                   + visible_sample(TEXTURE,center+vec2(-q.x, q.y))
                   + visible_sample(TEXTURE,center+vec2( q.x, q.y)))*0.25;
        } else {
            COLOR = visible_sample(TEXTURE,center);
        }
    }
}
