const Vec3 = @import("vec3.zig").Vec3;
const ScreenVertex = @import("raster.zig").ScreenVertex;

pub const Camera = struct {
    position: Vec3,
    right: Vec3, // ejes de la cámara, cada uno de longitud 1
    up: Vec3,
    forward: Vec3,
    fov_y: f32, // campo de visión vertical, en radianes
    near: f32, // distancia mínima a la que se dibuja

    /// Cámara en `position` mirando hacia `target`.
    pub fn look_at(position: Vec3, target: Vec3, world_up: Vec3, fov_y: f32, near: f32) Camera {
        const forward = target.sub(position).normalize();
        const right = forward.cross(world_up).normalize();
        const up = right.cross(forward);
        return .{
            .position = position,
            .right = right,
            .up = up,
            .forward = forward,
            .fov_y = fov_y,
            .near = near,
        };
    }

    /// Mundo -> cámara: x a la derecha, y arriba, z = distancia hacia adelante.
    pub fn to_camera(self: Camera, p: Vec3) Vec3 {
        const d = p.sub(self.position);
        return Vec3.init(d.dot(self.right), d.dot(self.up), d.dot(self.forward));
    }

    /// Cámara -> pantalla (en píxeles). `p.z` debe ser > 0.
    pub fn project(self: Camera, p: Vec3, width: f32, height: f32) ScreenVertex {
        const scale = (height / 2.0) / @tan(self.fov_y / 2.0);
        return .{
            .x = width / 2.0 + p.x / p.z * scale,
            .y = height / 2.0 - p.y / p.z * scale, // Y se voltea
            .inv_z = 1.0 / p.z,
        };
    }
};
