const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Vec3 = @import("vec3.zig").Vec3;
const Camera = @import("camera.zig").Camera;
const DepthBuffer = @import("raster.zig").DepthBuffer;
const draw_mesh = @import("render.zig").draw_mesh;
const load_obj = @import("obj.zig").load_obj;

const WIDTH: i32 = 800;
const HEIGHT: i32 = 600;

// Los modelos se meten dentro del programa al compilar (src/assets/)
const esfera_obj = @embedFile("assets/esfera.obj");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const esfera = try load_obj(gpa, esfera_obj);
    const scratch = try gpa.alloc(Vec3, esfera.positions.len);

    rl.setTraceLogLevel(.warning);
    rl.initWindow(WIDTH, HEIGHT, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var fb = Framebuffer.init(WIDTH, HEIGHT, .black, .white);
    defer fb.deinit();

    var depth = try DepthBuffer.init(gpa, WIDTH, HEIGHT);
    depth.clear();

    // Cámara en (0, 0, 6) mirando al origen; FOV de 60 grados (1.0472 rad)
    const cam = Camera.look_at(Vec3.init(0, 0, 6), Vec3.init(0, 0, 0), Vec3.init(0, 1, 0), 1.0472, 0.1);

    // Esfera chica y cercana primero, grande y lejana después
    try draw_mesh(&fb, &depth, cam, esfera, Vec3.init(0.9, 0.3, 3.0), 0.7, scratch);
    try draw_mesh(&fb, &depth, cam, esfera, Vec3.init(0, 0, 0), 2.0, scratch);

    while (!rl.windowShouldClose()) {
        try fb.swap_buffers();
    }
}
