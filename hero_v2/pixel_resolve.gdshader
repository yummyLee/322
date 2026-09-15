shader_type canvas_item;
render_mode unshaded;
uniform vec2 pixel_grid = vec2(480.0,270.0);
uniform bool pixel_enabled = true;
uniform bool coverage_filter = true;
void fragment() {
    if (!pixel_enabled) {
        COLOR = texture(TEXTURE,UV);
    } else {
        vec2 center = (floor(UV*pixel_grid)+vec2(0.5))/pixel_grid;
        if (coverage_filter) {
            // Four spatial samples per logical pixel. No history, blur pass or ghosting.
            vec2 q = vec2(0.25)/pixel_grid;
            COLOR = (texture(TEXTURE,center+vec2(-q.x,-q.y))
                   + texture(TEXTURE,center+vec2( q.x,-q.y))
                   + texture(TEXTURE,center+vec2(-q.x, q.y))
                   + texture(TEXTURE,center+vec2( q.x, q.y)))*0.25;
        } else {
            COLOR = texture(TEXTURE,center);
        }
    }
}
