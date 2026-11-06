const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Vec3 = @import("vec3.zig").Vec3;
const Camera = @import("camera.zig").Camera;
const DepthBuffer = @import("raster.zig").DepthBuffer;
const Texture = @import("texture.zig").Texture;
const draw_mesh = @import("render.zig").draw_mesh;
const load_obj = @import("obj.zig").load_obj;

const WIDTH: i32 = 800;
const HEIGHT: i32 = 600;

const Clock = std.Io.Clock.real;

// Modelos y texturas se meten dentro del programa al compilar (src/assets/)
const esfera_obj = @embedFile("assets/esfera.obj");
const tierra_png = @embedFile("assets/tierra.png");

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;

    const esfera = try load_obj(gpa, esfera_obj);
    const scratch = try gpa.alloc(Vec3, esfera.positions.len);

    rl.setTraceLogLevel(.warning);
    rl.initWindow(WIDTH, HEIGHT, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const tierra = try Texture.from_png(tierra_png);

    var fb = Framebuffer.init(WIDTH, HEIGHT, .black, .white);
    defer fb.deinit();

    var depth = try DepthBuffer.init(gpa, WIDTH, HEIGHT);

    // Cámara en (0, 0, 6) mirando al origen; FOV de 60 grados (1.0472 rad)
    const cam = Camera.look_at(Vec3.init(0, 0, 6), Vec3.init(0, 0, 0), Vec3.init(0, 1, 0), 1.0472, 0.1);

    var angle: f32 = 0;
    var dt: f32 = 0;
    var frame_start = Clock.now(init.io);
    var fps_time: f32 = 0;
    var fps_frames: u32 = 0;

    while (!rl.windowShouldClose()) {
        frame_start = Clock.now(init.io);
        defer {
            dt = @floatFromInt(frame_start.durationTo(Clock.now(init.io)).toNanoseconds());
            dt /= 1_000_000_000;
        }

        // Contador de FPS en la consola (una vez por segundo)
        fps_time += dt;
        fps_frames += 1;
        if (fps_time >= 1.0) {
            const fps = @as(f32, @floatFromInt(fps_frames)) / fps_time;
            std.debug.print("FPS: {d:.0}\n", .{fps});
            fps_time = 0;
            fps_frames = 0;
        }

        angle += dt * 0.6; // radianes por segundo

        fb.clear();
        depth.clear();
        _ = try draw_mesh(&fb, &depth, cam, esfera, Vec3.init(0, 0, 0), 2.0, angle, tierra, scratch);
        try fb.swap_buffers();
    }
}
