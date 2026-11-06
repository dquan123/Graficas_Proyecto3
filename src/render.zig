const std = @import("std");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const raster = @import("raster.zig");
const Camera = @import("camera.zig").Camera;
const vec = @import("vec3.zig");
const Vec3 = vec.Vec3;
const Vec2 = vec.Vec2;
const Model = @import("obj.zig").Model;
const Texture = @import("texture.zig").Texture;

/// Memoria de trabajo de draw_mesh, con espacio para los vértices del modelo más grande.
pub const Scratch = struct {
    cam: []Vec3, // posición de cada vértice en espacio de cámara
    normals: []Vec3, // normal de cada vértice en el mundo

    pub fn init(gpa: std.mem.Allocator, n: usize) !Scratch {
        return .{ .cam = try gpa.alloc(Vec3, n), .normals = try gpa.alloc(Vec3, n) };
    }
};

/// Añade al vértice de pantalla sus UV y su normal, ya divididos entre z.
fn with_attrs(base: raster.ScreenVertex, uv: Vec2, n: Vec3) raster.ScreenVertex {
    var s = base;
    s.u_z = uv.x * s.inv_z;
    s.v_z = uv.y * s.inv_z;
    s.nx_z = n.x * s.inv_z;
    s.ny_z = n.y * s.inv_z;
    s.nz_z = n.z * s.inv_z;
    return s;
}

/// Dibuja una ESFERA (el modelo debe ser de radio 1 centrado en el origen) con su centro en
/// `center`, escalada por `scale` y girada `rot_y` radianes sobre su eje vertical.
/// `light` null = el cuerpo brilla por sí mismo. Devuelve cuántos triángulos se dibujaron.
pub fn draw_mesh(
    fb: *Framebuffer,
    depth: *raster.DepthBuffer,
    cam: Camera,
    model: Model,
    center: Vec3,
    scale: f32,
    rot_y: f32,
    tex: Texture,
    light: ?raster.Light,
    scratch: Scratch,
) !usize {
    const n = model.positions.len;
    if (scratch.cam.len < n or scratch.normals.len < n) return error.ScratchTooSmall;

    const w: f32 = @floatFromInt(fb.width);
    const h: f32 = @floatFromInt(fb.height);
    const cos_r = @cos(rot_y);
    const sin_r = @sin(rot_y);

    // Modelo -> mundo -> cámara, una sola vez por vértice
    for (model.positions, 0..) |p, i| {
        // Giro sobre el eje Y, luego escala y posición
        const rotated = Vec3.init(p.x * cos_r + p.z * sin_r, p.y, -p.x * sin_r + p.z * cos_r);
        const world = rotated.scale(scale).add(center);
        scratch.cam[i] = cam.to_camera(world);
        // En una esfera, la normal de un punto es el vector del centro hacia ese punto
        scratch.normals[i] = rotated;
    }

    var drawn: usize = 0;
    for (model.faces) |f| {
        const pa = scratch.cam[f.a.pos];
        const pb = scratch.cam[f.b.pos];
        const pc = scratch.cam[f.c.pos];

        // Si algún vértice está demasiado cerca o detrás de la cámara, se descarta
        if (pa.z < cam.near or pb.z < cam.near or pc.z < cam.near) continue;

        // Back-face culling: los triángulos de frente dan producto punto > 0
        const normal = pb.sub(pa).cross(pc.sub(pa));
        if (normal.dot(pa) <= 0) continue;

        const sa = with_attrs(cam.project(pa, w, h), model.uvs[f.a.uv], scratch.normals[f.a.pos]);
        const sb = with_attrs(cam.project(pb, w, h), model.uvs[f.b.uv], scratch.normals[f.b.pos]);
        const sc = with_attrs(cam.project(pc, w, h), model.uvs[f.c.uv], scratch.normals[f.c.pos]);

        raster.fill_triangle(fb, depth, sa, sb, sc, tex, light);
        drawn += 1;
    }
    return drawn;
}
