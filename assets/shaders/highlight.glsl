extern vec3 highlightColor;
extern vec2 stepSize;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 texColor = Texel(texture, texture_coords);
    
    // If the pixel itself has color, draw it normally
    if (texColor.a > 0.0) {
        return texColor * color;
    }

    // Check neighbors to create an outline/glow effect
    float alpha = 0.0;
    alpha += Texel(texture, texture_coords + vec2(stepSize.x, 0.0)).a;
    alpha += Texel(texture, texture_coords + vec2(-stepSize.x, 0.0)).a;
    alpha += Texel(texture, texture_coords + vec2(0.0, stepSize.y)).a;
    alpha += Texel(texture, texture_coords + vec2(0.0, -stepSize.y)).a;
    
    // Diagonals for smoother outline
    alpha += Texel(texture, texture_coords + vec2(stepSize.x, stepSize.y)).a * 0.7;
    alpha += Texel(texture, texture_coords + vec2(-stepSize.x, -stepSize.y)).a * 0.7;
    alpha += Texel(texture, texture_coords + vec2(stepSize.x, -stepSize.y)).a * 0.7;
    alpha += Texel(texture, texture_coords + vec2(-stepSize.x, stepSize.y)).a * 0.7;

    if (alpha > 0.0) {
        return vec4(highlightColor, min(1.0, alpha)) * color;
    }

    return texColor;
}
