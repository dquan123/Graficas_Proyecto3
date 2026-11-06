const std = @import("std");
const vec = @import("vec3.zig");
const Vec3 = vec.Vec3;
const Vec2 = vec.Vec2;

/// Una esquina de una cara: índices (desde 0) a posición, UV y normal.
pub const Corner = struct { pos: usize, uv: usize, normal: usize };

/// Un triángulo. Las caras de más de 3 vértices se parten en varios de estos.
pub const Face = struct { a: Corner, b: Corner, c: Corner };

pub const Model = struct {
    positions: []Vec3,
    uvs: []Vec2,
    normals: []Vec3,
    faces: []Face,
};

/// Convierte un número del .obj (que cuenta desde 1) a índice desde 0, validando rango.
fn parse_index(part: ?[]const u8, count: usize) !usize {
    const text = part orelse return error.MissingUvOrNormal;
    if (text.len == 0) return error.MissingUvOrNormal;
    const n = try std.fmt.parseInt(usize, text, 10);
    if (n == 0 or n > count) return error.BadFaceIndex;
    return n - 1;
}

/// Lee una esquina con formato "pos/uv/normal", por ejemplo "47/1/1".
fn parse_corner(token: []const u8, n_pos: usize, n_uv: usize, n_nor: usize) !Corner {
    var parts = std.mem.splitScalar(u8, token, '/');
    const p = try parse_index(parts.next(), n_pos);
    const t = try parse_index(parts.next(), n_uv);
    const n = try parse_index(parts.next(), n_nor);
    return .{ .pos = p, .uv = t, .normal = n };
}

/// Lee el contenido de un .obj (ya en memoria). Usa v, vt, vn y f.
/// Las caras con más de 3 vértices se triangulan en abanico.
pub fn load_obj(gpa: std.mem.Allocator, text: []const u8) !Model {
    var positions: std.ArrayList(Vec3) = .empty;
    var uvs: std.ArrayList(Vec2) = .empty;
    var normals: std.ArrayList(Vec3) = .empty;
    var faces: std.ArrayList(Face) = .empty;
    errdefer {
        positions.deinit(gpa);
        uvs.deinit(gpa);
        normals.deinit(gpa);
        faces.deinit(gpa);
    }

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        // Quita espacios y el '\r' de los finales de línea de Windows
        const line = std.mem.trim(u8, raw, " \t\r");

        if (std.mem.startsWith(u8, line, "v ")) {
            var tok = std.mem.tokenizeScalar(u8, line[2..], ' ');
            const x = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadVertex);
            const y = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadVertex);
            const z = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadVertex);
            try positions.append(gpa, Vec3.init(x, y, z));
        } else if (std.mem.startsWith(u8, line, "vt ")) {
            var tok = std.mem.tokenizeScalar(u8, line[3..], ' ');
            const u = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadUv);
            const v = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadUv);
            try uvs.append(gpa, Vec2.init(u, v));
        } else if (std.mem.startsWith(u8, line, "vn ")) {
            var tok = std.mem.tokenizeScalar(u8, line[3..], ' ');
            const x = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadNormal);
            const y = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadNormal);
            const z = try std.fmt.parseFloat(f32, tok.next() orelse return error.BadNormal);
            try normals.append(gpa, Vec3.init(x, y, z));
        } else if (std.mem.startsWith(u8, line, "f ")) {
            var tok = std.mem.tokenizeScalar(u8, line[2..], ' ');
            var corners: [64]Corner = undefined;
            var n: usize = 0;
            while (tok.next()) |t| {
                if (n == corners.len) return error.FaceTooBig;
                corners[n] = try parse_corner(t, positions.items.len, uvs.items.len, normals.items.len);
                n += 1;
            }
            if (n < 3) return error.BadFace;

            // Abanico: (c0, c1, c2), (c0, c2, c3), (c0, c3, c4), ...
            var i: usize = 1;
            while (i + 1 < n) : (i += 1) {
                try faces.append(gpa, .{ .a = corners[0], .b = corners[i], .c = corners[i + 1] });
            }
        }
    }

    return .{
        .positions = try positions.toOwnedSlice(gpa),
        .uvs = try uvs.toOwnedSlice(gpa),
        .normals = try normals.toOwnedSlice(gpa),
        .faces = try faces.toOwnedSlice(gpa),
    };
}