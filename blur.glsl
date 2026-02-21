extern vec2 direction;
extern float radius;

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec4 sum = vec4(0.0);
    vec2 tc = texture_coords;
    
    float totalWeight = 0.0;
    const float steps = 20.0; // 41 total samples guarantees perfect smoothness
    
    // Spread the blur variance (sigma) relative to the radius
    float sigma = max(radius / 3.0, 0.1); 
    
    for (float i = -steps; i <= steps; i++) {
        // Offset mapping from interval [-steps, steps] directly into [-radius, radius]
        float offset = (i / steps) * radius;
        
        // Standard Gaussian bell curve math
        float weight = exp(-(offset * offset) / (2.0 * sigma * sigma));
        
        sum += Texel(texture, tc + offset * direction) * weight;
        totalWeight += weight;
    }
    
    return (sum / totalWeight) * color;
}
