// assets/shaders/clouds.glsl
extern vec2 cameraPos;
extern vec2 cloudScroll;
extern float scale;
extern vec2 torchPos;
extern float torchRadius;

// Simple 2D noise
vec2 hash( vec2 p ) {
    p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p ) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

    vec2  i = floor( p + (p.x+p.y)*K1 );
    vec2  a = p - i + (i.x+i.y)*K2;
    float m = step( a.y, a.x ); 
    vec2  o = vec2( m, 1.0 - m );
    vec2  b = a - o + K2;
    vec2  c = a - 1.0 + 2.0*K2;
    vec3  h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
    vec3  n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
    return dot( n, vec3(70.0) );
}

float fbm(vec2 x) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    // Rotate to reduce axial bias
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
    for (int i = 0; i < 4; ++i) {
        v += a * noise(x);
        x = rot * x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    // Real world coordinate is the physical screen coordinate plus the camera position.
    vec2 worldPos = screen_coords + cameraPos;
    
    // Add time scrolling for panning the clouds
    vec2 noisePos = worldPos + cloudScroll;

    float n = fbm(noisePos * scale);
    
    // Remap noise from [-1, 1] roughly to [0, 1]
    n = n * 0.5 + 0.5;
    
    // Thresholding and smoothing
    // Only keep the 'cloudy' peaks, make them wider
    float density = smoothstep(0.35, 0.60, n);
    
    // Calculate distance to torch in world space
    float dTorch = distance(worldPos, torchPos);
    
    // Smoothly fade out the cloud shadow near the torch
    float torchMask = smoothstep(torchRadius * 0.4, torchRadius * 1.5, dTorch);
    
    // Multiplicatively mask the density, removing clouds under torch light
    density *= torchMask;
    
    // Cloud color: deep dark dramatic shadow
    vec4 cloudColor = vec4(0.04, 0.05, 0.1, density * 0.80);
    
    return cloudColor * color;
}
