/*
 * SimpleGraphic - Metal Shaders
 * Basic vertex and fragment shaders for 2D rendering
 */

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

// Vertex shader
vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.color = in.color;
    return out;
}

// Fragment shader
fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    if (tex.get_width() > 0) {
        float4 texColor = tex.sample(sam, in.texCoord);

        // For R8Unorm textures (glyph atlas), red channel is alpha
        if (texColor.r > 0.0 && texColor.g == 0.0 && texColor.b == 0.0) {
            float alpha = texColor.r;
            return float4(in.color.rgb, alpha * in.color.a);
        }

        // For RGBA textures (images) or dummy white texture, multiply by vertex color
        return texColor * in.color;
    }
    return in.color;
}
