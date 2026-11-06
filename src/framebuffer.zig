const rl = @import("raylib");

pub const Framebuffer = struct {
    width: i32,
    height: i32,
    color_buff: rl.Image,
    background_color: rl.Color,
    current_color: rl.Color,
    texture: ?rl.Texture = null,

    pub fn init(width: i32, height: i32, background_color: ?rl.Color, draw_color: ?rl.Color) Framebuffer {
        const bg_color = background_color orelse rl.Color.black;
        const color = draw_color orelse rl.Color.white;
        return .{
            .color_buff = rl.genImageColor(width, height, bg_color),
            .width = width,
            .height = height,
            .background_color = bg_color,
            .current_color = color,
        };
    }

    pub fn deinit(self: *Framebuffer) void {
        if (self.texture) |texture| rl.unloadTexture(texture);
        rl.unloadImage(self.color_buff);
    }

    pub fn clear(self: *Framebuffer) void {
        self.color_buff.clearBackground(self.background_color);
    }

    pub fn set_pixel(self: *Framebuffer, x: i32, y: i32) !void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return error.BadCoordinates;
        self.color_buff.drawPixel(x, y, self.current_color);
    }

    pub fn set_background_color(self: *Framebuffer, color: rl.Color) void {
        self.background_color = color;
    }

    pub fn set_current_color(self: *Framebuffer, color: rl.Color) void {
        self.current_color = color;
    }

    pub fn render_to_file(self: Framebuffer, filename: []const u8) !void {
        if (!self.color_buff.exportToFile(@ptrCast(filename))) return error.CouldntWriteFile;
    }

    pub fn swap_buffers(self: *Framebuffer) !void {
        // La imagen vive en RAM (CPU); para dibujarla la GPU la necesita como textura (VRAM).
        // Liberamos la textura del frame anterior para no gastar VRAM de más.
        if (self.texture) |old| rl.unloadTexture(old);

        const texture = try rl.loadTextureFromImage(self.color_buff);
        self.texture = texture;

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.drawTexture(texture, 0, 0, .white);
    }
};
