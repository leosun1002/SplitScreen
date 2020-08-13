precision highp float;
uniform sampler2D Texture;
varying highp vec2 TextureCoordsVarying;

void main() {
    vec2 xy = TextureCoordsVarying.xy;
    float y = 0.0;
    float x = 0.0;
    if (xy.y <= 0.5) {
        y = xy.y + 0.5;
    } else {
        y = xy.y;
    }
    
    if (xy.x <= 0.5) {
        x = xy.x + 0.25;
    } else {
        x = xy.x - 0.25;
    }
    vec4 mask = texture2D(Texture, vec2(x,y));
    gl_FragColor = mask;

}
