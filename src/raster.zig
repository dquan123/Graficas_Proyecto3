const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Texture = @import("texture.zig").Texture;
const Vec3 = @import("vec3.zig").Vec3;

/// Un vértice ya en pantalla: posición en píxeles, inv_z = 1 / (distancia a la cámara),
/// y los atributos (UV y normal) ya divididos entre z, para interpolarlos con perspectiva correcta.
pub const ScreenVertex = struct {
    x: f32,
    y: f32,
    inv_z: f32,
    u_z: f32 = 0,
    v_z: f32 = 0,
    nx_z: f32 = 0,
    ny_z: f32 = 0,
    nz_z: f32 = 0,
};

/// La luz del Sol sobre un cuerpo.
/// `dir`: vector unitario que apunta HACIA la luz. `ambient`: brillo mínimo (0 a 1).
pub const Light = struct { dir: Vec3, ambient: f32 };

/// Guarda, por cada píxel, qué tan cerca está lo último que se pintó (1/z; mayor = más cerca).
pub const DepthBuffer = struct {
    width: i32,
    height: i32,
    data: []f32,

    pub fn init(gpa: std.mem.Allocator, width: i32, height: i32) !DepthBuffer {
        const n: usize = @intCast(width * height);
        return .{ .width = width, .height = height, .data = try gpa.alloc(f32, n) };
    }

    /// 0 = infinitamente lejos. Se llama al inicio de cada cuadro.
    pub fn clear(self: *DepthBuffer) void {
        @memset(self.data, 0);
    }
};

/// Convierte un valor decimal a un píxel entero dentro de [0, max].
fn to_px(v: f32, max: f32) i32 {
    return @intFromFloat(@max(0.0, @min(max, v)));
}

/// Multiplica un color por un brillo (0 = negro, 1 = igual).
fn shade(c: rl.Color, k: f32) rl.Color {
    const kk = @max(0.0, @min(1.0, k));
    return .{
        .r = @intFromFloat(@as(f32, @floatFromInt(c.r)) * kk),
        .g = @intFromFloat(@as(f32, @floatFromInt(c.g)) * kk),
        .b = @intFromFloat(@as(f32, @floatFromInt(c.b)) * kk),
        .a = c.a,
    };
}

/// Rellena un triángulo con una textura, respetando el z-buffer.
/// Si `light` es null, el cuerpo brilla con su textura completa (como el Sol).
pub fn fill_triangle(
    fb: *Framebuffer,
    depth: *DepthBuffer,
    a: ScreenVertex,
    b: ScreenVertex,
    c: ScreenVertex,
    tex: Texture,
    light: ?Light,
) void {
    // Área (con signo) del triángulo completo
    const area = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    if (area == 0) return; // triángulo degenerado
    const inv_area = 1.0 / area;

    // Caja contenedora, limitada a la pantalla
    const fw: f32 = @floatFromInt(fb.width);
    const fh: f32 = @floatFromInt(fb.height);
    const min_x = to_px(@floor(@min(a.x, @min(b.x, c.x))), fw - 1);
    const max_x = to_px(@ceil(@max(a.x, @max(b.x, c.x))), fw - 1);
    const min_y = to_px(@floor(@min(a.y, @min(b.y, c.y))), fh - 1);
    const max_y = to_px(@ceil(@max(a.y, @max(b.y, c.y))), fh - 1);

    const width: usize = @intCast(fb.width);

    var y = min_y;
    while (y <= max_y) : (y += 1) {
        const py = @as(f32, @floatFromInt(y)) + 0.5; // centro del píxel
        var x = min_x;
        while (x <= max_x) : (x += 1) {
            const px = @as(f32, @floatFromInt(x)) + 0.5;

            // Coordenadas baricéntricas: área del sub-triángulo opuesto / área total
            const wa = ((b.x - px) * (c.y - py) - (b.y - py) * (c.x - px)) * inv_area;
            const wb = ((px - a.x) * (c.y - a.y) - (py - a.y) * (c.x - a.x)) * inv_area;
            const wc = ((b.x - a.x) * (py - a.y) - (b.y - a.y) * (px - a.x)) * inv_area;
            if (wa < 0 or wb < 0 or wc < 0) continue; // fuera del triángulo

            // 1/z se interpola linealmente con las baricéntricas
            const inv_z = wa * a.inv_z + wb * b.inv_z + wc * c.inv_z;

            const idx = @as(usize, @intCast(y)) * width + @as(usize, @intCast(x));
            if (inv_z > depth.data[idx]) { // más cerca que lo que ya había
                depth.data[idx] = inv_z;

                // UV con perspectiva correcta: (u/z) / (1/z)
                const u = (wa * a.u_z + wb * b.u_z + wc * c.u_z) / inv_z;
                const v = (wa * a.v_z + wb * b.v_z + wc * c.v_z) / inv_z;
                var color = tex.sample(u, v);

                // Luz difusa: brillo = ambiente + (1 - ambiente) * max(0, N · L)
                if (light) |l| {
                    const nx = (wa * a.nx_z + wb * b.nx_z + wc * c.nx_z) / inv_z;
                    const ny = (wa * a.ny_z + wb * b.ny_z + wc * c.ny_z) / inv_z;
                    const nz = (wa * a.nz_z + wb * b.nz_z + wc * c.nz_z) / inv_z;
                    const len = @sqrt(nx * nx + ny * ny + nz * nz);
                    var diffuse: f32 = 0;
                    if (len > 0) {
                        diffuse = @max(0.0, (nx * l.dir.x + ny * l.dir.y + nz * l.dir.z) / len);
                    }
                    color = shade(color, l.ambient + (1.0 - l.ambient) * diffuse);
                }

                fb.put_pixel(x, y, color);
            }
        }
    }
}
