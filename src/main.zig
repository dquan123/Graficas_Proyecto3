const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const load_obj = @import("obj.zig").load_obj;

const WIDTH: i32 = 800;
const HEIGHT: i32 = 600;

// Los modelos se meten dentro del programa al compilar (src/assets/)
const esfera_obj = @embedFile("assets/esfera.obj");
const nave_obj = @embedFile("assets/nave_espacial.obj");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const esfera = try load_obj(gpa, esfera_obj);
    const nave = try load_obj(gpa, nave_obj);

    std.debug.print("esfera: {d} v, {d} vt, {d} vn, {d} triangulos\n", .{
        esfera.positions.len, esfera.uvs.len, esfera.normals.len, esfera.faces.len,
    });
    std.debug.print("nave:   {d} v, {d} vt, {d} vn, {d} triangulos\n", .{
        nave.positions.len, nave.uvs.len, nave.normals.len, nave.faces.len,
    });

    rl.setTraceLogLevel(.warning);
    rl.initWindow(WIDTH, HEIGHT, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var fb = Framebuffer.init(WIDTH, HEIGHT, .black, .white);
    defer fb.deinit();

    while (!rl.windowShouldClose()) {
        try fb.swap_buffers();
    }
}