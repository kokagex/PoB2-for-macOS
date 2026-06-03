// pob_poolfix.c — macOS Metal memory-leak fix for PathOfBuilding (PoE2).
//
// SimpleGraphic.dylib's hand-rolled Metal backend installs no per-frame
// autoreleasepool anywhere (verified: no objc_autoreleasePoolPush import in the
// dylib or the luajit host). Every draw call (metal_draw_image / metal_draw_glyph
// make 6-7 objc_msgSend each) and every frame (metal_begin_frame) creates
// autoreleased Objective-C Metal objects (render command encoders, command
// buffers, drawables). With no pool to drain them they accumulate — measured at
// ~500MB in ~10s of active passive-tree manipulation — until VM exhaustion
// aborts the AMD Metal driver inside amdMtl_DeviceAcquireEncoderIdAddr.
//
// We cannot rebuild the dylib (rebuilds break the UI, root cause unknown) and a
// Lua-FFI drain crashes: draining from launch:OnFrame happens AFTER
// metal_begin_frame, so it frees the current frame's not-yet-ended encoder and
// Metal asserts in -[MTLCommandEncoder dealloc].
//
// Instead we interpose glfwPollEvents, which sg_window_poll_events (ProcessEvents)
// calls once per frame at the very TOP of the loop, BEFORE metal_begin_frame.
// At that point the previous frame is fully ended / committed / presented and the
// current frame's encoder does not exist yet, so popping the pool is safe. The
// pushed pool then scopes the whole frame (begin -> draw -> end -> present) and is
// drained at the next frame's poll. Injected via DYLD_INSERT_LIBRARIES; the dylib
// binary is untouched.

extern void *objc_autoreleasePoolPush(void);
extern void  objc_autoreleasePoolPop(void *pool);
extern void  glfwPollEvents(void);

static void *g_pob_pool = (void *)0;

static void pob_glfwPollEvents(void) {
	// Drain the previous frame's autoreleased Metal objects, then open a fresh
	// pool for this frame. Calling glfwPollEvents() here reaches the real glfw
	// implementation (dyld does not interpose the interposer's own reference).
	if (g_pob_pool) {
		objc_autoreleasePoolPop(g_pob_pool);
	}
	g_pob_pool = objc_autoreleasePoolPush();
	glfwPollEvents();
}

__attribute__((used)) static struct {
	const void *replacement;
	const void *replacee;
} _interpose_glfwPollEvents __attribute__((section("__DATA,__interpose"))) = {
	(const void *)(unsigned long)&pob_glfwPollEvents,
	(const void *)(unsigned long)&glfwPollEvents
};
