precision highp float;
uniform sampler2D Texture;
varying highp vec2 TextureCoordsVarying;

void main() {
    vec2 xy = TextureCoordsVarying.xy;
    float y = 0.0;
    if (xy.y <= 1.0/3.0) {
        y = xy.y + 2.0 / 3.0;
    } else if (xy.y > 1.0/3.0 && xy.y <= 2.0/3.0){
        y = xy.y + 1.0 / 3.0;
    }else{
        y = xy.y;
    }
    vec4 mask = texture2D(Texture, vec2(xy.x,y));
    gl_FragColor = mask;

}
