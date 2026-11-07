const std = @import("std");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const raster = @import("raster.zig");
const Camera = @import("camera.zig").Camera;
const vec = @import("vec3.zig");
const Vec3 = vec.Vec3;
const Vec2 = vec.Vec2;
const Model = @import("obj.zig").Model;
const Texture = @import("texture.zig").Texture;

/// Memoria de trabajo para dibujar, con espacio para los vértices del modelo más grande.
pub const Scratch = struct {
    cam: []Vec3, // posición de cada vértice en espacio de cámara
    normals: []Vec3, // normal de cada vértice en el mundo (esferas)
    world: []Vec3, // posición de cada vértice en el mundo (nave)

    pub fn init(gpa: std.mem.Allocator, n: usize) !Scratch {
        return .{
            .cam = try gpa.alloc(Vec3, n),
            .normals = try gpa.alloc(Vec3, n),
            .world = try gpa.alloc(Vec3, n),
        };
    }
};

/// Hacia dónde apuntan, en el mundo, los ejes "derecha", "arriba" y "adelante" de un objeto.
pub const Frame = struct { right: Vec3, up: Vec3, forward: Vec3 };

/// Dónde y cómo se coloca un modelo en el mundo.
pub const Pose = struct { origin: Vec3, frame: Frame, scale: f32 };

/// Cómo está orientado un modelo en su propio espacio: su centro, hacia dónde
/// apunta su nariz y cuál es su "arriba". `nose` y `top` deben ser perpendiculares y unitarios.
pub const ModelAxes = struct { center: Vec3, nose: Vec3, top: Vec3 };

/// Centro de la caja que contiene todos los vértices.
pub fn bbox_center(positions: []const Vec3) Vec3 {
    var lo = positions[0];
    var hi = positions[0];
    for (positions) |p| {
        lo = Vec3.init(@min(lo.x, p.x), @min(lo.y, p.y), @min(lo.z, p.z));
        hi = Vec3.init(@max(hi.x, p.x), @max(hi.y, p.y), @max(hi.z, p.z));
    }
    return lo.add(hi).scale(0.5);
}

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

/// Dibuja un modelo cualquiera (la nave) colocado según `pose`, con sombreado plano por triángulo.
/// `axes` dice cómo está orientado el modelo en su propio espacio.
pub fn draw_ship(
    fb: *Framebuffer,
    depth: *raster.DepthBuffer,
    cam: Camera,
    model: Model,
    axes: ModelAxes,
    pose: Pose,
    tex: Texture,
    light: ?raster.Light,
    scratch: Scratch,
) !usize {
    const n = model.positions.len;
    if (scratch.cam.len < n or scratch.world.len < n) return error.ScratchTooSmall;

    const w: f32 = @floatFromInt(fb.width);
    const h: f32 = @floatFromInt(fb.height);

    // "Derecha" del modelo, a partir de su nariz y su arriba
    const right_m = axes.nose.cross(axes.top);

    for (model.positions, 0..) |p, i| {
        // Coordenadas del vértice en los ejes de la nave (derecha, arriba, adelante)
        const q = p.sub(axes.center);
        const a = q.dot(right_m) * pose.scale;
        const b = q.dot(axes.top) * pose.scale;
        const c = q.dot(axes.nose) * pose.scale;

        // Esos mismos ejes, pero como están orientados en el mundo
        const world = pose.origin
            .add(pose.frame.right.scale(a))
            .add(pose.frame.up.scale(b))
            .add(pose.frame.forward.scale(c));
        scratch.world[i] = world;
        scratch.cam[i] = cam.to_camera(world);
    }

    var drawn: usize = 0;
    for (model.faces) |f| {
        const pa = scratch.cam[f.a.pos];
        const pb = scratch.cam[f.b.pos];
        const pc = scratch.cam[f.c.pos];

        if (pa.z < cam.near or pb.z < cam.near or pc.z < cam.near) continue;

        // Back-face culling
        const cam_normal = pb.sub(pa).cross(pc.sub(pa));
        if (cam_normal.dot(pa) <= 0) continue;

        // Normal real del triángulo, en el mundo, para la luz
        const wa = scratch.world[f.a.pos];
        const wb = scratch.world[f.b.pos];
        const wc = scratch.world[f.c.pos];
        const normal_w = wb.sub(wa).cross(wc.sub(wa)).normalize();

        const sa = with_attrs(cam.project(pa, w, h), model.uvs[f.a.uv], normal_w);
        const sb = with_attrs(cam.project(pb, w, h), model.uvs[f.b.uv], normal_w);
        const sc = with_attrs(cam.project(pc, w, h), model.uvs[f.c.uv], normal_w);

        raster.fill_triangle(fb, depth, sa, sb, sc, tex, light);
        drawn += 1;
    }
    return drawn;
}
