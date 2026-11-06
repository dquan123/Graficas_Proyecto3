const std = @import("std");
const rl = @import("raylib");
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Vec3 = @import("vec3.zig").Vec3;
const Camera = @import("camera.zig").Camera;
const DepthBuffer = @import("raster.zig").DepthBuffer;
const Texture = @import("texture.zig").Texture;
const draw_mesh = @import("render.zig").draw_mesh;
const Scratch = @import("render.zig").Scratch;
const Light = @import("raster.zig").Light;
const load_obj = @import("obj.zig").load_obj;
const system = @import("system.zig");
const Body = system.Body;
const stars_mod = @import("stars.zig");

const WIDTH: i32 = 800;
const HEIGHT: i32 = 600;
const FOV: f32 = 1.0472; // 60 grados en radianes
const NEAR: f32 = 0.1;
const AMBIENT: f32 = 0.10; // brillo mínimo del lado de noche

const MOUSE_SENSITIVITY: f32 = 0.0025;
const SPEED: f32 = 12.0; // unidades por segundo
const SPEED_FAST: f32 = 40.0; // con Shift
const STAR_COUNT: usize = 4000; //Estrellas
const COLLISION_MARGIN: f32 = 2.0; // distancia mínima entre la cámara y la superficie de un cuerpo

const Clock = std.Io.Clock.real;

// Modelos y texturas se meten dentro del programa al compilar (src/assets/)
const esfera_obj = @embedFile("assets/esfera.obj");
const sol_png = @embedFile("assets/sol.png");
const tierra_png = @embedFile("assets/tierra.png");
const luna_png = @embedFile("assets/luna.png");
const marte_png = @embedFile("assets/marte.png");
const jupiter_png = @embedFile("assets/jupiter.png");

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;

    const esfera = try load_obj(gpa, esfera_obj);
    const scratch = try Scratch.init(gpa, esfera.positions.len);

    rl.setTraceLogLevel(.warning);
    rl.initWindow(WIDTH, HEIGHT, "Space Travel");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    rl.disableCursor(); // atrapa el mouse para poder girar sin límite

    // Los cuerpos del sistema. El padre debe ir antes que sus hijos (la Luna después de la Tierra).
    const bodies = [_]Body{
        .{ .name = "Sol", .texture = try Texture.from_png(sol_png), .radius = 5.0, .orbit_radius = 0, .orbit_speed = 0, .orbit_phase = 0, .spin_speed = 0.2, .parent = null },
        .{ .name = "Tierra", .texture = try Texture.from_png(tierra_png), .radius = 2.2, .orbit_radius = 18, .orbit_speed = 0.35, .orbit_phase = 0.0, .spin_speed = 1.5, .parent = null },
        .{ .name = "Luna", .texture = try Texture.from_png(luna_png), .radius = 0.6, .orbit_radius = 4.2, .orbit_speed = 1.6, .orbit_phase = 1.0, .spin_speed = 1.6, .parent = 1 },
        .{ .name = "Marte", .texture = try Texture.from_png(marte_png), .radius = 1.6, .orbit_radius = 28, .orbit_speed = 0.25, .orbit_phase = 2.2, .spin_speed = 1.4, .parent = null },
        .{ .name = "Jupiter", .texture = try Texture.from_png(jupiter_png), .radius = 4.2, .orbit_radius = 44, .orbit_speed = 0.14, .orbit_phase = 4.0, .spin_speed = 2.5, .parent = null },
    };
    var positions: [bodies.len]Vec3 = undefined;

    var fb = Framebuffer.init(WIDTH, HEIGHT, .black, .white);
    defer fb.deinit();

    var depth = try DepthBuffer.init(gpa, WIDTH, HEIGHT);
    const stars = try stars_mod.generate(gpa, STAR_COUNT, 20261106);

    // Estado de la cámara: arriba y atrás del sistema, mirando hacia el Sol
    var cam_pos = Vec3.init(0, 32, 75);
    var yaw: f32 = 0;
    var pitch: f32 = -0.4;
    var warmup: u32 = 3; // cuadros iniciales en los que se ignora el mouse

    var time: f32 = 0;
    var dt: f32 = 0;
    var frame_start = Clock.now(init.io);
    var fps_time: f32 = 0;
    var fps_frames: u32 = 0;

    while (!rl.windowShouldClose()) {
        frame_start = Clock.now(init.io);
        defer {
            dt = @floatFromInt(frame_start.durationTo(Clock.now(init.io)).toNanoseconds());
            dt /= 1_000_000_000;
        }

        // Contador de FPS en la consola (una vez por segundo)
        fps_time += dt;
        fps_frames += 1;
        if (fps_time >= 1.0) {
            const fps = @as(f32, @floatFromInt(fps_frames)) / fps_time;
            std.debug.print("FPS: {d:.0}\n", .{fps});
            fps_time = 0;
            fps_frames = 0;
        }

        time += dt;
        system.update_positions(&bodies, time, &positions);

        // --- Cámara: mirar con el mouse ---
        const mouse = rl.getMouseDelta();
        if (warmup > 0) {
            warmup -= 1;
        } else {
            yaw += mouse.x * MOUSE_SENSITIVITY;
            pitch -= mouse.y * MOUSE_SENSITIVITY;
            pitch = @max(-1.5, @min(1.5, pitch));
        }

        // --- Cámara: moverse con el teclado ---
        const basis = Camera.from_angles(cam_pos, yaw, pitch, FOV, NEAR);
        var move = Vec3.init(0, 0, 0);
        if (rl.isKeyDown(.w)) move = move.add(basis.forward);
        if (rl.isKeyDown(.s)) move = move.sub(basis.forward);
        if (rl.isKeyDown(.d)) move = move.add(basis.right);
        if (rl.isKeyDown(.a)) move = move.sub(basis.right);
        if (rl.isKeyDown(.e)) move = move.add(Vec3.init(0, 1, 0));
        if (rl.isKeyDown(.q)) move = move.sub(Vec3.init(0, 1, 0));

        const speed: f32 = if (rl.isKeyDown(.left_shift)) SPEED_FAST else SPEED;
        const step = @min(dt, 0.05); // un tirón no debe lanzar la cámara lejos
        cam_pos = cam_pos.add(move.scale(speed * step));
        cam_pos = system.push_out(&bodies, &positions, cam_pos, COLLISION_MARGIN);

        const cam = Camera.from_angles(cam_pos, yaw, pitch, FOV, NEAR);

        // --- Dibujar ---
        fb.clear();
        depth.clear();
        stars_mod.draw_stars(&fb, cam, stars);

        // El Sol (cuerpo 0) brilla por sí mismo; los demás reciben su luz
        for (bodies, 0..) |b, i| {
            const light: ?Light = if (i == 0) null else .{
                .dir = positions[0].sub(positions[i]).normalize(),
                .ambient = AMBIENT,
            };
            _ = try draw_mesh(&fb, &depth, cam, esfera, positions[i], b.radius, b.spin_speed * time, b.texture, light, scratch);
        }
        try fb.swap_buffers();
    }
}
