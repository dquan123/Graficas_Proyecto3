const Vec3 = @import("vec3.zig").Vec3;
const Texture = @import("texture.zig").Texture;

pub const Body = struct {
    name: []const u8,
    texture: Texture,
    radius: f32, // tamaño (la esfera base tiene radio 1)
    orbit_radius: f32, // distancia al cuerpo que orbita
    orbit_speed: f32, // radianes por segundo
    orbit_phase: f32, // ángulo inicial de la órbita
    spin_speed: f32, // giro sobre su propio eje, radianes por segundo
    parent: ?usize, // índice del cuerpo que orbita; null = el origen
};

/// Calcula la posición de cada cuerpo en el instante `time`.
/// Los padres deben aparecer antes que sus hijos en `bodies`.
pub fn update_positions(bodies: []const Body, time: f32, out: []Vec3) void {
    for (bodies, 0..) |b, i| {
        const center = if (b.parent) |p| out[p] else Vec3.init(0, 0, 0);
        const angle = b.orbit_phase + b.orbit_speed * time;
        out[i] = center.add(Vec3.init(@cos(angle) * b.orbit_radius, 0, @sin(angle) * b.orbit_radius));
    }
}
