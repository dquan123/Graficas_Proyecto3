const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const raster = @import("raster.zig");
const Camera = @import("camera.zig").Camera;
const Vec3 = @import("vec3.zig").Vec3;
const Model = @import("obj.zig").Model;

/// Color distinto por triángulo (solo para depurar la forma).
fn face_color(i: usize) rl.Color {
    const r: u8 = @truncate(i *% 37);
    const g: u8 = @truncate(i *% 91);
    const b: u8 = @truncate(i *% 53);
    return .{ .r = 90 + r % 160, .g = 90 + g % 160, .b = 90 + b % 160, .a = 255 };
}

/// Dibuja un modelo con su centro en `center` y escalado por `scale`.
/// `scratch` es memoria de trabajo: debe tener espacio para todos los vértices del modelo.
pub fn draw_mesh(
    fb: *Framebuffer,
    depth: *raster.DepthBuffer,
    cam: Camera,
    model: Model,
    center: Vec3,
    scale: f32,
    scratch: []Vec3,
) !void {
    if (scratch.len < model.positions.len) return error.ScratchTooSmall;

    const w: f32 = @floatFromInt(fb.width);
    const h: f32 = @floatFromInt(fb.height);

    // Modelo -> mundo -> cámara, una sola vez por vértice
    for (model.positions, 0..) |p, i| {
        const world = p.scale(scale).add(center);
        scratch[i] = cam.to_camera(world);
    }

    for (model.faces, 0..) |f, i| {
        const pa = scratch[f.a.pos];
        const pb = scratch[f.b.pos];
        const pc = scratch[f.c.pos];

        // Si algún vértice está demasiado cerca o detrás de la cámara, se descarta
        if (pa.z < cam.near or pb.z < cam.near or pc.z < cam.near) continue;

        raster.fill_triangle(
            fb,
            depth,
            cam.project(pa, w, h),
            cam.project(pb, w, h),
            cam.project(pc, w, h),
            face_color(i),
        );
    }
}
