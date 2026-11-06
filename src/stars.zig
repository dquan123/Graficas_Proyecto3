const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Vec3 = @import("vec3.zig").Vec3;
const Camera = @import("camera.zig").Camera;

/// Una estrella: solo una dirección en el cielo (vector unitario), sin distancia.
pub const Star = struct {
    dir: Vec3,
    level: u8, // brillo (gris)
    big: bool, // si se dibuja de 2x2 píxeles
};

/// Crea `count` estrellas repartidas uniformemente por toda la esfera celeste.
pub fn generate(gpa: std.mem.Allocator, count: usize, seed: u64) ![]Star {
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const stars = try gpa.alloc(Star, count);
    for (stars) |*s| {
        // z uniforme en [-1, 1] y un ángulo al azar: reparto uniforme sobre la esfera
        const z = rand.float(f32) * 2.0 - 1.0;
        const phi = rand.float(f32) * 2.0 * std.math.pi;
        const r = @sqrt(1.0 - z * z);
        s.* = .{
            .dir = Vec3.init(r * @cos(phi), r * @sin(phi), z),
            .level = 80 + rand.uintLessThan(u8, 176), // de 80 a 255
            .big = rand.float(f32) < 0.08,
        };
    }
    return stars;
}

/// Dibuja las estrellas. Usa solo la orientación de la cámara, no su posición:
/// las estrellas están "en el infinito".
pub fn draw_stars(fb: *Framebuffer, cam: Camera, stars: []const Star) void {
    const w: f32 = @floatFromInt(fb.width);
    const h: f32 = @floatFromInt(fb.height);
    const scale = (h / 2.0) / @tan(cam.fov_y / 2.0);

    for (stars) |s| {
        // Dirección de la estrella medida con los ejes de la cámara
        const z = s.dir.dot(cam.forward);
        if (z <= 0.01) continue; // detrás de la cámara
        const x = s.dir.dot(cam.right);
        const y = s.dir.dot(cam.up);

        const sx = w / 2.0 + x / z * scale;
        const sy = h / 2.0 - y / z * scale;
        if (sx < 0 or sy < 0 or sx >= w - 1 or sy >= h - 1) continue; // fuera de pantalla

        const px: i32 = @intFromFloat(sx);
        const py: i32 = @intFromFloat(sy);
        const color = rl.Color{ .r = s.level, .g = s.level, .b = s.level, .a = 255 };
        fb.put_pixel(px, py, color);
        if (s.big) {
            fb.put_pixel(px + 1, py, color);
            fb.put_pixel(px, py + 1, color);
            fb.put_pixel(px + 1, py + 1, color);
        }
    }
}
