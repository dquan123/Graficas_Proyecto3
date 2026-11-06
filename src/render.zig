const Framebuffer = @import("framebuffer.zig").Framebuffer;
const raster = @import("raster.zig");
const Camera = @import("camera.zig").Camera;
const Vec3 = @import("vec3.zig").Vec3;
const Model = @import("obj.zig").Model;
const Texture = @import("texture.zig").Texture;

/// Dibuja un modelo con su centro en `center`, escalado por `scale` y girado
/// `rot_y` radianes sobre su eje vertical. Devuelve cuántos triángulos se dibujaron.
/// `scratch` es memoria de trabajo: debe tener espacio para todos los vértices del modelo.
pub fn draw_mesh(
    fb: *Framebuffer,
    depth: *raster.DepthBuffer,
    cam: Camera,
    model: Model,
    center: Vec3,
    scale: f32,
    rot_y: f32,
    tex: Texture,
    scratch: []Vec3,
) !usize {
    if (scratch.len < model.positions.len) return error.ScratchTooSmall;

    const w: f32 = @floatFromInt(fb.width);
    const h: f32 = @floatFromInt(fb.height);
    const cos_r = @cos(rot_y);
    const sin_r = @sin(rot_y);

    // Modelo -> mundo -> cámara, una sola vez por vértice
    for (model.positions, 0..) |p, i| {
        // Giro sobre el eje Y, luego escala y posición
        const rotated = Vec3.init(p.x * cos_r + p.z * sin_r, p.y, -p.x * sin_r + p.z * cos_r);
        const world = rotated.scale(scale).add(center);
        scratch[i] = cam.to_camera(world);
    }

    var drawn: usize = 0;
    for (model.faces) |f| {
        const pa = scratch[f.a.pos];
        const pb = scratch[f.b.pos];
        const pc = scratch[f.c.pos];

        // Si algún vértice está demasiado cerca o detrás de la cámara, se descarta
        if (pa.z < cam.near or pb.z < cam.near or pc.z < cam.near) continue;

        // Back-face culling: los triángulos de frente dan producto punto > 0
        const normal = pb.sub(pa).cross(pc.sub(pa));
        if (normal.dot(pa) <= 0) continue;

        // Proyección + coordenadas de textura divididas entre z
        var sa = cam.project(pa, w, h);
        var sb = cam.project(pb, w, h);
        var sc = cam.project(pc, w, h);
        const uva = model.uvs[f.a.uv];
        const uvb = model.uvs[f.b.uv];
        const uvc = model.uvs[f.c.uv];
        sa.u_z = uva.x * sa.inv_z;
        sa.v_z = uva.y * sa.inv_z;
        sb.u_z = uvb.x * sb.inv_z;
        sb.v_z = uvb.y * sb.inv_z;
        sc.u_z = uvc.x * sc.inv_z;
        sc.v_z = uvc.y * sc.inv_z;

        raster.fill_triangle(fb, depth, sa, sb, sc, tex);
        drawn += 1;
    }
    return drawn;
}
