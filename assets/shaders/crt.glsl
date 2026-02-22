extern float time;

// 1. Geometric Barrel Distortion
vec2 curveUVs(vec2 uv) {
    // Map UVs to [-1, 1]
    uv = uv * 2.0 - 1.0;
    // Calculate distance squared from center
    vec2 offset = abs(uv.yx) / vec2(5.0, 5.0); // Curve intensity
    uv = uv + uv * offset * offset;
    // Remap back to [0, 1]
    uv = uv * 0.5 + 0.5;
    return uv;
}

// Pseudo-random noise function
float nrand(vec2 n) {
    return fract(sin(dot(n.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    // Apply curvature
    vec2 uvs = curveUVs(texture_coords);

    // 2. Chromatic Aberration (Color Bleed)
    // Distance from center pushes pixels further apart at the edges
    vec2 center_dist = uvs - 0.5;
    float spread = length(center_dist) * 0.003; 

    // Sample Red, Green, Blue slightly separated horizontally
    float r = Texel(texture, uvs - vec2(spread, 0.0)).r;
    float g = Texel(texture, uvs).g;
    float b = Texel(texture, uvs + vec2(spread, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // 3. Scanlines
    // Apply based on un-curved screen pixels to completely prevent Moiré interference swirls
    // A soft, low-frequency sine wave ensures it never hits the display Nyquist limit
    float scanline = sin(screen_coords.y * 1.5) * 0.05;
    col -= scanline;

    // 4. Signal Noise (Static Grain)
    // Fast moving TV static added globally
    float noise = (nrand(uvs * time) - 0.5) * 0.05;
    col += noise;

    // 5. RGB Aperture Grille (Shadow Mask)
    // Create physical sub-pixel striping: [R, G, B] pattern alternating on X axis
    // Use raw 1:1 screen_coords to map directly to physical monitor pixels
    float maskP = mod(screen_coords.x, 3.0);
    vec3 grille = vec3(1.0);
    
    // Dim the sub-pixels depending on the column index to simulate hardware phosphor stripes
    if(maskP < 1.0) grille = vec3(1.0, 0.7, 0.7);       // Red subpixel emphasis
    else if(maskP < 2.0) grille = vec3(0.7, 1.0, 0.7);  // Green subpixel emphasis
    else grille = vec3(0.7, 0.7, 1.0);                  // Blue subpixel emphasis

    // Multiply true image color by physical phosphor mask
    col *= grille;

    // Slightly brighten overall image so the mask and scanlines don't crush visibility
    col *= 1.15;

    // 6. Tube Border
    // Calculate distance mathematically for a flawless, anti-aliased TV-tube fade to black
    // It fades from 1.0 to 0.0 over the extreme outer 2% edge of the TV
    vec2 border = smoothstep(vec2(0.5), vec2(0.48), abs(center_dist));
    col *= border.x * border.y;

    return vec4(col, 1.0) * color;
}
