const rl = @import("raylib");

pub const Texture = struct {
    width: i32,
    height: i32,
    pixels: []rl.Color, // fila por fila, empezando arriba a la izquierda

    /// Decodifica un PNG que ya está en memoria (por ejemplo, con @embedFile).
    /// Los pixeles se quedan en memoria mientras corre el programa.
    pub fn from_png(png: []const u8) !Texture {
        const img = try rl.loadImageFromMemory(".png", png);
        defer rl.unloadImage(img);
        const colors = try rl.loadImageColors(img);
        return .{ .width = img.width, .height = img.height, .pixels = colors };
    }

    /// Color de la textura en (u, v). u se repite; v se limita a [0, 1].
    pub fn sample(self: Texture, u: f32, v: f32) rl.Color {
        const uu = u - @floor(u); // wrap: 1.25 -> 0.25
        const vv = @max(0.0, @min(1.0, v));
        const fw: f32 = @floatFromInt(self.width);
        const fh: f32 = @floatFromInt(self.height);
        const x: usize = @intFromFloat(@min(uu * fw, fw - 1));
        // En el .obj v=0 es abajo; en la imagen la fila 0 es arriba
        const y: usize = @intFromFloat(@min((1.0 - vv) * fh, fh - 1));
        return self.pixels[y * @as(usize, @intCast(self.width)) + x];
    }
};
