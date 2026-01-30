/*
 * SimpleGraphic - Metal Backend
 * Metal rendering implementation for macOS
 */

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>

#include "sg_internal.h"
#include <stdio.h>
#include <GLFW/glfw3.h>

#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3native.h>

/* ===== Metal Context ===== */

// Vertex structure for text rendering
typedef struct TextVertex {
    float position[2];
    float texCoord[2];
    float color[4];
} TextVertex;

typedef struct MetalContext {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    CAMetalLayer* metalLayer;
    id<MTLRenderPipelineState> pipelineState;
    id<MTLLibrary> library;
    id<MTLSamplerState> samplerState;

    // Frame resources
    id<MTLCommandBuffer> commandBuffer;
    id<MTLRenderCommandEncoder> renderEncoder;
    id<CAMetalDrawable> currentDrawable;

    // Text rendering
    id<MTLBuffer> textVertexBuffer;
    NSUInteger textVertexBufferSize;
    NSUInteger textVertexCount;
    id<MTLTexture> currentAtlasTexture;

    // Drawing state
    float clearColor[4];
    float drawColor[4];
} MetalContext;

/* ===== Forward Declarations ===== */

static bool metal_init(SGContext* ctx);
static void metal_shutdown(SGContext* ctx);
static void metal_begin_frame(SGContext* ctx);
static void metal_end_frame(SGContext* ctx);
static void metal_present(SGContext* ctx);
static void metal_set_clear_color(float r, float g, float b, float a);
static void metal_set_draw_color(float r, float g, float b, float a);
static void metal_set_viewport(int x, int y, int width, int height);
static void* metal_create_texture(int width, int height, const void* data);
static void metal_destroy_texture(void* texture);
static void metal_update_texture(void* texture, const void* data);
static void metal_draw_glyph(void* texture, int x, int y, int width, int height,
                             float u0, float v0, float u1, float v1,
                             float r, float g, float b, float a);

/* ===== Metal Shader Source ===== */

static const char* metalShaderSource = R"(
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

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler sam [[sampler(0)]]) {
    if (tex.get_width() > 0) {
        // For R8Unorm textures (glyph atlas), sample red channel for alpha
        float alpha = tex.sample(sam, in.texCoord).r;
        return float4(in.color.rgb, alpha * in.color.a);
    }
    return in.color;
}
)";

/* ===== Initialization ===== */

static bool metal_init(SGContext* ctx) {
    if (!ctx) return false;

    printf("Metal: Initializing\n");

    // Create Metal context
    MetalContext* metal = (MetalContext*)calloc(1, sizeof(MetalContext));
    if (!metal) {
        fprintf(stderr, "Metal: Failed to allocate context\n");
        return false;
    }

    // Get Metal device
    metal->device = MTLCreateSystemDefaultDevice();
    if (!metal->device) {
        fprintf(stderr, "Metal: No Metal-capable device found\n");
        free(metal);
        return false;
    }

    printf("Metal: Using device: %s\n", [[metal->device name] UTF8String]);

    // Create command queue
    metal->commandQueue = [metal->device newCommandQueue];
    if (!metal->commandQueue) {
        fprintf(stderr, "Metal: Failed to create command queue\n");
        free(metal);
        return false;
    }

    // Compile shader library from source
    NSString* shaderSource = [NSString stringWithUTF8String:metalShaderSource];
    NSError* error = nil;
    metal->library = [metal->device newLibraryWithSource:shaderSource options:nil error:&error];
    if (!metal->library) {
        fprintf(stderr, "Metal: Failed to compile shaders: %s\n",
                [[error localizedDescription] UTF8String]);
        free(metal);
        return false;
    }
    printf("Metal: Shaders compiled successfully\n");

    // Get native window handle
    NSWindow* nsWindow = glfwGetCocoaWindow((GLFWwindow*)ctx->window);
    if (!nsWindow) {
        fprintf(stderr, "Metal: Failed to get Cocoa window\n");
        free(metal);
        return false;
    }

    // Create Metal layer
    metal->metalLayer = [CAMetalLayer layer];
    metal->metalLayer.device = metal->device;
    metal->metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metal->metalLayer.framebufferOnly = YES;

    // Set layer size
    CGSize drawableSize = CGSizeMake(ctx->width, ctx->height);
    metal->metalLayer.drawableSize = drawableSize;

    // Attach layer to window
    NSView* contentView = [nsWindow contentView];
    [contentView setWantsLayer:YES];
    [contentView setLayer:metal->metalLayer];

    // Initialize clear color
    metal->clearColor[0] = 0.0f;
    metal->clearColor[1] = 0.0f;
    metal->clearColor[2] = 0.0f;
    metal->clearColor[3] = 1.0f;

    metal->drawColor[0] = 1.0f;
    metal->drawColor[1] = 1.0f;
    metal->drawColor[2] = 1.0f;
    metal->drawColor[3] = 1.0f;

    // Create render pipeline state
    id<MTLFunction> vertexFunction = [metal->library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [metal->library newFunctionWithName:@"fragment_main"];

    if (!vertexFunction || !fragmentFunction) {
        fprintf(stderr, "Metal: Failed to load shader functions\n");
        free(metal);
        return false;
    }

    // Create vertex descriptor
    MTLVertexDescriptor* vertexDesc = [[MTLVertexDescriptor alloc] init];

    // Position (float2)
    vertexDesc.attributes[0].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[0].offset = 0;
    vertexDesc.attributes[0].bufferIndex = 0;

    // TexCoord (float2)
    vertexDesc.attributes[1].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[1].offset = 8;
    vertexDesc.attributes[1].bufferIndex = 0;

    // Color (float4)
    vertexDesc.attributes[2].format = MTLVertexFormatFloat4;
    vertexDesc.attributes[2].offset = 16;
    vertexDesc.attributes[2].bufferIndex = 0;

    // Layout
    vertexDesc.layouts[0].stride = sizeof(TextVertex);
    vertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDesc.layouts[0].stepRate = 1;

    MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexFunction = vertexFunction;
    pipelineDesc.fragmentFunction = fragmentFunction;
    pipelineDesc.vertexDescriptor = vertexDesc;
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    // Enable alpha blending
    pipelineDesc.colorAttachments[0].blendingEnabled = YES;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;

    metal->pipelineState = [metal->device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
    if (!metal->pipelineState) {
        fprintf(stderr, "Metal: Failed to create pipeline state: %s\n",
                [[error localizedDescription] UTF8String]);
        free(metal);
        return false;
    }

    // Create sampler state for texture filtering
    MTLSamplerDescriptor* samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    metal->samplerState = [metal->device newSamplerStateWithDescriptor:samplerDesc];

    // Allocate text vertex buffer (initial size: 10000 vertices)
    metal->textVertexBufferSize = 10000 * sizeof(TextVertex);
    metal->textVertexBuffer = [metal->device newBufferWithLength:metal->textVertexBufferSize
                                                         options:MTLResourceStorageModeShared];
    metal->textVertexCount = 0;

    // Store in renderer
    ctx->renderer->backend_data = metal;

    printf("Metal: Initialization complete\n");
    return true;
}

static void metal_shutdown(SGContext* ctx) {
    if (!ctx || !ctx->renderer) return;

    MetalContext* metal = (MetalContext*)ctx->renderer->backend_data;
    if (!metal) return;

    printf("Metal: Shutting down\n");

    // Release Metal objects (ARC will handle it)
    metal->commandQueue = nil;
    metal->device = nil;
    metal->metalLayer = nil;
    metal->pipelineState = nil;
    metal->library = nil;

    free(metal);
    ctx->renderer->backend_data = NULL;
}

static void metal_begin_frame(SGContext* ctx) {
    if (!ctx || !ctx->renderer) return;

    MetalContext* metal = (MetalContext*)ctx->renderer->backend_data;
    if (!metal) return;

    // Reset text vertex count
    metal->textVertexCount = 0;
    metal->currentAtlasTexture = nil;

    // Get next drawable
    metal->currentDrawable = [metal->metalLayer nextDrawable];
    if (!metal->currentDrawable) return;

    // Create command buffer
    metal->commandBuffer = [metal->commandQueue commandBuffer];

    // Create render pass descriptor
    MTLRenderPassDescriptor* renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPass.colorAttachments[0].texture = metal->currentDrawable.texture;
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(
        metal->clearColor[0],
        metal->clearColor[1],
        metal->clearColor[2],
        metal->clearColor[3]
    );

    // Create render command encoder (keep it open for drawing)
    metal->renderEncoder = [metal->commandBuffer renderCommandEncoderWithDescriptor:renderPass];
}

static void metal_end_frame(SGContext* ctx) {
    if (!ctx || !ctx->renderer) return;

    MetalContext* metal = (MetalContext*)ctx->renderer->backend_data;
    if (!metal || !metal->renderEncoder) return;

    // Flush any remaining text rendering
    if (metal->textVertexCount > 0 && metal->currentAtlasTexture) {
        [metal->renderEncoder setRenderPipelineState:metal->pipelineState];
        [metal->renderEncoder setVertexBuffer:metal->textVertexBuffer offset:0 atIndex:0];
        [metal->renderEncoder setFragmentTexture:metal->currentAtlasTexture atIndex:0];
        [metal->renderEncoder setFragmentSamplerState:metal->samplerState atIndex:0];
        [metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                                  vertexStart:0
                                  vertexCount:metal->textVertexCount];
        metal->textVertexCount = 0;
    }

    // End encoding
    [metal->renderEncoder endEncoding];
    metal->renderEncoder = nil;

    // Present drawable
    [metal->commandBuffer presentDrawable:metal->currentDrawable];
    [metal->commandBuffer commit];

    metal->commandBuffer = nil;
    metal->currentDrawable = nil;
}

static void metal_present(SGContext* ctx) {
    (void)ctx;
    // Already presented in begin_frame
}

static void metal_set_clear_color(float r, float g, float b, float a) {
    if (!g_ctx || !g_ctx->renderer) return;

    MetalContext* metal = (MetalContext*)g_ctx->renderer->backend_data;
    if (!metal) return;

    metal->clearColor[0] = r;
    metal->clearColor[1] = g;
    metal->clearColor[2] = b;
    metal->clearColor[3] = a;
}

static void metal_set_draw_color(float r, float g, float b, float a) {
    if (!g_ctx || !g_ctx->renderer) return;

    MetalContext* metal = (MetalContext*)g_ctx->renderer->backend_data;
    if (!metal) return;

    metal->drawColor[0] = r;
    metal->drawColor[1] = g;
    metal->drawColor[2] = b;
    metal->drawColor[3] = a;
}

static void metal_set_viewport(int x, int y, int width, int height) {
    (void)x; (void)y; (void)width; (void)height;
    // TODO: Implement viewport
}

static void* metal_create_texture(int width, int height, const void* data) {
    if (!g_ctx || !g_ctx->renderer) return NULL;

    MetalContext* metal = (MetalContext*)g_ctx->renderer->backend_data;
    if (!metal || !metal->device) return NULL;

    // Create texture descriptor for R8Unorm (single-channel grayscale)
    MTLTextureDescriptor* desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                    width:width
                                   height:height
                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModeManaged;

    // Create texture
    id<MTLTexture> texture = [metal->device newTextureWithDescriptor:desc];
    if (!texture) {
        fprintf(stderr, "Metal: Failed to create texture\n");
        return NULL;
    }

    // Upload initial data if provided
    if (data) {
        MTLRegion region = MTLRegionMake2D(0, 0, width, height);
        [texture replaceRegion:region
                   mipmapLevel:0
                     withBytes:data
                   bytesPerRow:width];
    }

    // Retain the texture to keep it alive
    return (__bridge_retained void*)texture;
}

static void metal_destroy_texture(void* texture) {
    if (!texture) return;

    // Release the retained texture
    id<MTLTexture> mtlTexture = (__bridge_transfer id<MTLTexture>)texture;
    mtlTexture = nil;
}

static void metal_update_texture(void* texture, const void* data) {
    if (!texture || !data) return;

    id<MTLTexture> mtlTexture = (__bridge id<MTLTexture>)texture;

    // Get texture dimensions
    NSUInteger width = [mtlTexture width];
    NSUInteger height = [mtlTexture height];

    // Update entire texture
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [mtlTexture replaceRegion:region
                  mipmapLevel:0
                    withBytes:data
                  bytesPerRow:width];
}

static void metal_draw_glyph(void* texture, int x, int y, int width, int height,
                             float u0, float v0, float u1, float v1,
                             float r, float g, float b, float a) {
    if (!g_ctx || !g_ctx->renderer || !texture) return;

    MetalContext* metal = (MetalContext*)g_ctx->renderer->backend_data;
    if (!metal || !metal->renderEncoder) return;

    id<MTLTexture> atlasTexture = (__bridge id<MTLTexture>)texture;

    // Flush batch if texture changed or buffer is full
    bool needFlush = (metal->currentAtlasTexture && metal->currentAtlasTexture != atlasTexture);
    bool bufferFull = (metal->textVertexCount + 6) * sizeof(TextVertex) > metal->textVertexBufferSize;

    if (needFlush || bufferFull) {
        if (metal->textVertexCount > 0 && metal->currentAtlasTexture) {
            [metal->renderEncoder setRenderPipelineState:metal->pipelineState];
            [metal->renderEncoder setVertexBuffer:metal->textVertexBuffer offset:0 atIndex:0];
            [metal->renderEncoder setFragmentTexture:metal->currentAtlasTexture atIndex:0];
            [metal->renderEncoder setFragmentSamplerState:metal->samplerState atIndex:0];
            [metal->renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                                      vertexStart:0
                                      vertexCount:metal->textVertexCount];
        }
        metal->textVertexCount = 0;
        metal->currentAtlasTexture = atlasTexture;
    }

    if (!metal->currentAtlasTexture) {
        metal->currentAtlasTexture = atlasTexture;
    }

    // Convert screen coordinates to NDC (normalized device coordinates)
    // Screen space: (0,0) = top-left, (width, height) = bottom-right
    // NDC: (-1, 1) = top-left, (1, -1) = bottom-right
    float screen_w = (float)g_ctx->width;
    float screen_h = (float)g_ctx->height;

    float x0_ndc = (x / screen_w) * 2.0f - 1.0f;
    float y0_ndc = 1.0f - (y / screen_h) * 2.0f;
    float x1_ndc = ((x + width) / screen_w) * 2.0f - 1.0f;
    float y1_ndc = 1.0f - ((y + height) / screen_h) * 2.0f;

    // Get vertex buffer pointer
    TextVertex* vertices = (TextVertex*)[metal->textVertexBuffer contents];
    NSUInteger idx = metal->textVertexCount;

    // Create two triangles for the quad
    // Triangle 1: top-left, bottom-left, bottom-right
    vertices[idx + 0].position[0] = x0_ndc;
    vertices[idx + 0].position[1] = y0_ndc;
    vertices[idx + 0].texCoord[0] = u0;
    vertices[idx + 0].texCoord[1] = v0;
    vertices[idx + 0].color[0] = r;
    vertices[idx + 0].color[1] = g;
    vertices[idx + 0].color[2] = b;
    vertices[idx + 0].color[3] = a;

    vertices[idx + 1].position[0] = x0_ndc;
    vertices[idx + 1].position[1] = y1_ndc;
    vertices[idx + 1].texCoord[0] = u0;
    vertices[idx + 1].texCoord[1] = v1;
    vertices[idx + 1].color[0] = r;
    vertices[idx + 1].color[1] = g;
    vertices[idx + 1].color[2] = b;
    vertices[idx + 1].color[3] = a;

    vertices[idx + 2].position[0] = x1_ndc;
    vertices[idx + 2].position[1] = y1_ndc;
    vertices[idx + 2].texCoord[0] = u1;
    vertices[idx + 2].texCoord[1] = v1;
    vertices[idx + 2].color[0] = r;
    vertices[idx + 2].color[1] = g;
    vertices[idx + 2].color[2] = b;
    vertices[idx + 2].color[3] = a;

    // Triangle 2: top-left, bottom-right, top-right
    vertices[idx + 3].position[0] = x0_ndc;
    vertices[idx + 3].position[1] = y0_ndc;
    vertices[idx + 3].texCoord[0] = u0;
    vertices[idx + 3].texCoord[1] = v0;
    vertices[idx + 3].color[0] = r;
    vertices[idx + 3].color[1] = g;
    vertices[idx + 3].color[2] = b;
    vertices[idx + 3].color[3] = a;

    vertices[idx + 4].position[0] = x1_ndc;
    vertices[idx + 4].position[1] = y1_ndc;
    vertices[idx + 4].texCoord[0] = u1;
    vertices[idx + 4].texCoord[1] = v1;
    vertices[idx + 4].color[0] = r;
    vertices[idx + 4].color[1] = g;
    vertices[idx + 4].color[2] = b;
    vertices[idx + 4].color[3] = a;

    vertices[idx + 5].position[0] = x1_ndc;
    vertices[idx + 5].position[1] = y0_ndc;
    vertices[idx + 5].texCoord[0] = u1;
    vertices[idx + 5].texCoord[1] = v0;
    vertices[idx + 5].color[0] = r;
    vertices[idx + 5].color[1] = g;
    vertices[idx + 5].color[2] = b;
    vertices[idx + 5].color[3] = a;

    metal->textVertexCount += 6;
}

/* ===== Renderer Creation ===== */

SGRenderer* sg_create_metal_renderer(void) {
    SGRenderer* renderer = (SGRenderer*)calloc(1, sizeof(SGRenderer));
    if (!renderer) return NULL;

    renderer->init = metal_init;
    renderer->shutdown = metal_shutdown;
    renderer->begin_frame = metal_begin_frame;
    renderer->end_frame = metal_end_frame;
    renderer->present = metal_present;
    renderer->set_clear_color = metal_set_clear_color;
    renderer->set_draw_color = metal_set_draw_color;
    renderer->set_viewport = metal_set_viewport;
    renderer->create_texture = metal_create_texture;
    renderer->destroy_texture = metal_destroy_texture;
    renderer->update_texture = metal_update_texture;
    renderer->draw_glyph = metal_draw_glyph;

    return renderer;
}
