precision highp float;
uniform sampler2D Texture;
varying highp vec2 TextureCoordsVarying;

void main() {
    vec2 xy = TextureCoordsVarying.xy;
    float y = 0.0;
    if (xy.y <= 0.5) {
        y = xy.y + 0.5;
    } else {
        y = xy.y;
    }
    vec4 mask = texture2D(Texture, vec2(xy.x,y));
    gl_FragColor = mask;

}
