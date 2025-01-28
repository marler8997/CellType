const std = @import("std");
const design = @import("design.zig");

pub const Error = union(enum) {
    invalid_char: usize,
    bad_number: Token,
    unexpected_token: Token,
    duplicate_property: Token,
    recursive_between: Token,

    pub fn set(self: *Error, value: Error) error{Error} {
        self.* = value;
        return error.Error;
    }
};
pub fn countOps(s: []const u8, out_err: *Error) error{Error}!usize {
    var op_count: usize = 0;
    var offset: usize = 0;
    while (offset < s.len) {
        _, offset = try parseOp(s, out_err, offset) orelse break;
        op_count += 1;
    }
    return op_count;
}

pub fn countOpsCt(comptime s: []const u8) usize {
    @setEvalBranchQuota(s.len * 1000);
    var err: Error = undefined;
    return countOps(s, &err) catch switch (err) {
        .invalid_char => |offset| @compileError(std.fmt.comptimePrint(
            "invalid byte '{}' (0x{x}) at offset {} of string: {s}",
            .{ std.zig.fmtEscapes(s[offset..][0..1]), s[offset], offset, s },
        )),
        .unexpected_token => |token| @compileError("unexpected token '" ++ s[token.start..token.end] ++ "' at offset " ++ std.fmt.comptimePrint("{}", .{token.start}) ++ " of string: " ++ s),
        .duplicate_property => |token| @compileError("duplicated property '" ++ s[token.start..token.end] ++ "'"),
        .overflow => |value| @compileError(std.fmt.comptimePrint("number overflow '{}'", .{value})),
    };
}

pub fn parseOps(comptime s: []const u8) ![countOpsCt(s)]design.Op {
    const op_count = comptime countOpsCt(s);
    var ops: [op_count]design.Op = undefined;
    var offset: usize = 0;
    for (&ops) |*op| {
        var err: Error = undefined;
        op.*, offset = try parseOp(s, &err, offset) orelse unreachable;
    }
    {
        var err: Error = undefined;
        _ = try expectToken(s, &err, offset, .eof);
    }
    return ops;
}

pub fn parseOp(s: []const u8, out_err: *Error, start: usize) error{Error}!?struct { design.Op, usize } {
    const op_kind_token = try nextToken(s, out_err, start);
    switch (op_kind_token.kind) {
        .eof => return null,
        .id => {},
        .neg, .pos, .num, .eq, .open_paren, .close_paren, .semicolon => return out_err.set(.{
            .unexpected_token = op_kind_token,
        }),
    }
    const op_kind_token_str = s[op_kind_token.start..op_kind_token.end];
    if (std.mem.eql(u8, op_kind_token_str, "clip")) {
        const clip, const offset = try parseClip(s, out_err, op_kind_token.end);
        return .{ .{ .op = .{ .clip = clip } }, offset };
    }

    if (std.mem.eql(u8, op_kind_token_str, "stroke")) {
        const stroke_kind_token = try nextToken(s, out_err, op_kind_token.end);
        const stroke_kind_str = s[stroke_kind_token.start..stroke_kind_token.end];
        if (false) {
            //
        } else if (std.mem.eql(u8, stroke_kind_str, "vert")) {
            const x, const offset = try parseBoundary(s, out_err, stroke_kind_token.end, .top_level, .x);
            return .{
                .{ .op = .{ .stroke_vert = .{ .x = x } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else if (std.mem.eql(u8, stroke_kind_str, "horz")) {
            const y, const offset = try parseBoundary(s, out_err, stroke_kind_token.end, .top_level, .y);
            return .{
                .{ .op = .{ .stroke_horz = .{ .y = y } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else if (std.mem.eql(u8, stroke_kind_str, "diag")) {
            const x0, var offset = try parseBoundary(s, out_err, stroke_kind_token.end, .top_level, .x);
            const y0, offset = try parseBoundary(s, out_err, offset, .top_level, .y);
            const x1, offset = try parseBoundary(s, out_err, offset, .top_level, .x);
            const y1, offset = try parseBoundary(s, out_err, offset, .top_level, .y);
            return .{
                .{ .op = .{ .stroke_diag = .{
                    .a = .{ .x = x0, .y = y0 },
                    .b = .{ .x = x1, .y = y1 },
                } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else if (std.mem.eql(u8, stroke_kind_str, "dot")) {
            const x, var offset = try parseBoundary(s, out_err, stroke_kind_token.end, .top_level, .x);
            const y, offset = try parseBoundary(s, out_err, offset, .top_level, .y);
            return .{
                .{ .op = .{ .stroke_dot = .{ .x = x, .y = y } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else if (std.mem.eql(u8, stroke_kind_str, "curve")) {
            const x0, var offset = try parseBoundary(s, out_err, stroke_kind_token.end, .top_level, .x);
            const y0, offset = try parseBoundary(s, out_err, offset, .top_level, .y);
            const x1, offset = try parseBoundary(s, out_err, offset, .top_level, .x);
            const y1, offset = try parseBoundary(s, out_err, offset, .top_level, .y);
            const x2, offset = try parseBoundary(s, out_err, offset, .top_level, .x);
            const y2, offset = try parseBoundary(s, out_err, offset, .top_level, .y);
            return .{
                .{ .op = .{ .stroke_curve = .{
                    .start = .{ .x = x0, .y = y0 },
                    .control = .{ .x = x1, .y = y1 },
                    .end = .{ .x = x2, .y = y2 },
                } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else return out_err.set(.{ .unexpected_token = stroke_kind_token });
    }
    return out_err.set(.{ .unexpected_token = op_kind_token });
}

fn parseClip(
    s: []const u8,
    out_err: *Error,
    start: usize,
) error{Error}!struct { design.Clip, usize } {
    var offset = start;
    var clip: design.Clip = .{};
    while (true) {
        const property_token = try nextToken(s, out_err, offset);
        if (property_token.kind == .semicolon)
            return .{ clip, property_token.end };

        const property = s[property_token.start..property_token.end];
        if (false) {
            //
        } else if (std.mem.eql(u8, property, "left")) {
            if (clip.left != null) return out_err.set(.{ .duplicate_property = property_token });
            const eq = try nextToken(s, out_err, property_token.end);
            if (eq.kind != .eq) return out_err.set(.{ .unexpected_token = eq });
            clip.left, offset = try parseBoundary(s, out_err, eq.end, .top_level, .x);
        } else if (std.mem.eql(u8, property, "right")) {
            if (clip.right != null) return out_err.set(.{ .duplicate_property = property_token });
            const eq = try nextToken(s, out_err, property_token.end);
            if (eq.kind != .eq) return out_err.set(.{ .unexpected_token = eq });
            clip.right, offset = try parseBoundary(s, out_err, eq.end, .top_level, .x);
        } else if (std.mem.eql(u8, property, "top")) {
            if (clip.top != null) return out_err.set(.{ .duplicate_property = property_token });
            const eq = try nextToken(s, out_err, property_token.end);
            if (eq.kind != .eq) return out_err.set(.{ .unexpected_token = eq });
            clip.top, offset = try parseBoundary(s, out_err, eq.end, .top_level, .y);
        } else if (std.mem.eql(u8, property, "bottom")) {
            if (clip.bottom != null) return out_err.set(.{ .duplicate_property = property_token });
            const eq = try nextToken(s, out_err, property_token.end);
            if (eq.kind != .eq) return out_err.set(.{ .unexpected_token = eq });
            clip.bottom, offset = try parseBoundary(s, out_err, eq.end, .top_level, .y);
        } else if (std.mem.eql(u8, property, "count")) {
            @panic("todo");
        } else return out_err.set(.{ .unexpected_token = property_token });
    }
}

fn expectToken(
    s: []const u8,
    out_err: *Error,
    start: usize,
    expect: TokenKind,
) error{Error}!usize {
    const token = try nextToken(s, out_err, start);
    if (token.kind != expect) return out_err.set(.{ .unexpected_token = token });
    return token.end;
}

fn parseBoundary(
    s: []const u8,
    out_err: *Error,
    start: usize,
    context: enum { top_level, inside_between },
    comptime dimension: design.Dimension,
) error{Error}!struct { design.Boundary(dimension), usize } {
    const base_token = try nextToken(s, out_err, start);
    const base_token_str = s[base_token.start..base_token.end];

    const BoundaryBase = design.BoundaryBase(dimension);
    if (std.mem.eql(u8, base_token_str, "between")) {
        if (context == .inside_between) return out_err.set(.{ .recursive_between = base_token });
        const open_paren_end = try expectToken(s, out_err, base_token.end, .open_paren);
        const from, const from_end = try parseBoundary(s, out_err, open_paren_end, .inside_between, dimension);
        const to, const to_end = try parseBoundary(s, out_err, from_end, .inside_between, dimension);

        const num_token = try nextToken(s, out_err, to_end);
        if (num_token.kind != .num) return out_err.set(.{ .unexpected_token = num_token });
        const num_str = s[num_token.start..num_token.end];

        const num_f32 = std.fmt.parseFloat(f32, num_str) catch return out_err.set(.{ .bad_number = num_token });
        const close_paren_end = try expectToken(s, out_err, num_token.end, .close_paren);
        return .{
            .{
                .value = from.value,
                .between = .{ .to = to.value, .ratio = num_f32 },
            },
            close_paren_end,
        };
    }
    inline for (std.meta.fields(BoundaryBase)) |field| {
        if (std.mem.eql(u8, base_token_str, field.name)) {
            const adjust, const offset = try parseAdjust(s, out_err, base_token.end);
            return .{
                .{
                    .value = .{ .base = @enumFromInt(field.value), .adjust = adjust },
                    .between = null,
                },
                offset,
            };
        }
    }
    return out_err.set(.{ .unexpected_token = base_token });
}

fn parseAdjust(
    s: []const u8,
    out_err: *Error,
    start: usize,
) error{Error}!struct { i8, usize } {
    const mod_token = try nextToken(s, out_err, start);
    switch (mod_token.kind) {
        .neg, .pos => {
            const num_token = try nextToken(s, out_err, mod_token.end);
            switch (num_token.kind) {
                .eof, .id, .neg, .pos, .eq, .open_paren, .close_paren, .semicolon => return out_err.set(.{ .unexpected_token = num_token }),
                .num => {},
            }
            const num_str = s[num_token.start..num_token.end];
            const num: u32 = std.fmt.parseInt(u32, num_str, 10) catch return out_err.set(.{ .unexpected_token = num_token });
            const adjust: i8 = blk: {
                if (mod_token.kind == .pos) {
                    break :blk std.math.cast(i8, num) orelse return out_err.set(.{ .bad_number = num_token });
                }
                const num_i32 = std.math.cast(i32, num) orelse return out_err.set(.{ .bad_number = num_token });
                break :blk std.math.cast(i8, -num_i32) orelse return out_err.set(.{ .bad_number = num_token });
            };
            return .{ adjust, num_token.end };
        },
        else => return .{ 0, start },
    }
}

const TokenKind = enum { eof, id, neg, pos, num, eq, open_paren, close_paren, semicolon };
const Token = struct {
    kind: TokenKind,
    start: usize,
    end: usize,
    pub fn fmt(self: Token, s: []const u8) TokenFmt {
        return .{ .token = self, .s = s };
    }
};
pub const TokenFmt = struct {
    token: Token,
    s: []const u8,
    pub fn format(
        self: TokenFmt,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (self.token.kind) {
            .eof => try writer.writeAll("EOF"),
            .id => try writer.print("identifier '{s}'", .{self.s[self.token.start..self.token.end]}),
            .neg => try writer.writeAll("character '-'"),
            .pos => try writer.writeAll("character '-'"),
            .num => try writer.print("number '{s}'", .{self.s[self.token.start..self.token.end]}),
            .eq => try writer.writeAll("character '='"),
            .open_paren => try writer.writeAll("character '('"),
            .close_paren => try writer.writeAll("character ')'"),
            .semicolon => try writer.writeAll("character ';'"),
        }
    }
};

fn nextToken(s: []const u8, out_err: *Error, start: usize) error{Error}!Token {
    var offset = start;
    while (true) : (offset += 1) {
        if (offset >= s.len) return .{ .kind = .eof, .start = s.len, .end = s.len };
        return switch (s[offset]) {
            0...9 => out_err.set(.{ .invalid_char = offset }),
            '\n' => continue,
            11, 12 => out_err.set(.{ .invalid_char = offset }),
            '\r' => continue,
            14...31 => out_err.set(.{ .invalid_char = offset }),
            ' ' => continue,
            '!'...'\'' => out_err.set(.{ .invalid_char = offset }),
            '(' => .{ .kind = .open_paren, .start = offset, .end = offset + 1 },
            ')' => .{ .kind = .close_paren, .start = offset, .end = offset + 1 },
            '*' => out_err.set(.{ .invalid_char = offset }),
            '+' => .{ .kind = .pos, .start = offset, .end = offset + 1 },
            ',' => out_err.set(.{ .invalid_char = offset }),
            '-' => .{ .kind = .neg, .start = offset, .end = offset + 1 },
            '.', '/' => out_err.set(.{ .invalid_char = offset }),
            '0'...'9' => .{ .kind = .num, .start = offset, .end = scan(s, offset + 1, isNumChar) },
            ':' => out_err.set(.{ .invalid_char = offset }),
            ';' => .{ .kind = .semicolon, .start = offset, .end = offset + 1 },
            '<' => out_err.set(.{ .invalid_char = offset }),
            '=' => .{ .kind = .eq, .start = offset, .end = offset + 1 },
            '>'...'@' => out_err.set(.{ .invalid_char = offset }),
            'A'...'Z' => .{ .kind = .id, .start = offset, .end = scan(s, offset + 1, isIdChar) },
            '['...'`' => out_err.set(.{ .invalid_char = offset }),
            'a'...'z' => .{ .kind = .id, .start = offset, .end = scan(s, offset + 1, isIdChar) },
            '{'...255 => @panic("todo"),
        };
    }
}

fn scan(s: []const u8, start: usize, while_true: fn (u8) bool) usize {
    var offset = start;
    while (offset < s.len and while_true(s[offset])) : (offset += 1) {}
    return offset;
}

fn isIdChar(c: u8) bool {
    return switch (c) {
        '_', 'a'...'z' => true,
        else => false,
    };
}

fn isNumChar(c: u8) bool {
    return switch (c) {
        '.' => true,
        '0'...'9' => true,
        else => false,
    };
}

fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ', '\r', '\n' => true,
        else => false,
    };
}

test {
    var err: Error = undefined;
    try std.testing.expectEqual(
        design.Op{ .op = .{ .clip = .{
            .left = .{ .value = .{ .base = .center, .adjust = 1 } },
            .right = .{ .value = .{ .base = .uppercase_right, .adjust = -3 } },
            .top = .{ .value = .{ .base = .base } },
        } } },
        (try parseOp("clip left=center+1 right=uppercase_right-3 top=base;", &err, 0)).?[0],
    );
    try std.testing.expectEqual(
        design.Op{ .op = .{ .stroke_vert = .{
            .x = .{ .value = .{ .base = .uppercase_left, .adjust = -100 } },
        } } },
        (try parseOp("stroke vert uppercase_left-100;", &err, 0)).?[0],
    );
    try std.testing.expectEqual(
        design.Op{ .op = .{ .stroke_horz = .{
            .y = .{ .value = .{ .base = .base, .adjust = 0 } },
        } } },
        (try parseOp("stroke horz base;", &err, 0)).?[0],
    );
    try std.testing.expectEqual(
        design.Op{ .op = .{ .stroke_diag = .{
            .a = .{ .x = .{ .value = .{ .base = .uppercase_left, .adjust = -1 } }, .y = .{ .value = .{ .base = .base } } },
            .b = .{ .x = .{ .value = .{ .base = .uppercase_right, .adjust = 1 } }, .y = .{ .value = .{ .base = .uppercase_top } } },
        } } },
        (try parseOp("stroke diag uppercase_left-1 base uppercase_right+1 uppercase_top;", &err, 0)).?[0],
    );

    try std.testing.expectEqual(
        design.Op{ .op = .{ .stroke_vert = .{ .x = .{
            .value = .{ .base = .center, .adjust = -3 },
            .between = .{ .to = .{ .base = .uppercase_right, .adjust = 5 }, .ratio = 0.5 },
        } } } },
        (try parseOp("stroke vert between(center-3 uppercase_right+5 0.5);", &err, 0)).?[0],
    );
    try std.testing.expectEqual(
        design.Op{ .op = .{ .stroke_curve = .{
            .start = .{
                .x = .{ .value = .{ .base = .uppercase_left } },
                .y = .{ .value = .{ .base = .uppercase_center } },
            },
            .control = .{
                .x = .{ .value = .{ .base = .center } },
                .y = .{ .value = .{ .base = .base } },
            },
            .end = .{
                .x = .{ .value = .{ .base = .uppercase_right } },
                .y = .{ .value = .{ .base = .uppercase_top } },
            },
        } } },
        (try parseOp(
            \\stroke curve
            \\    uppercase_left uppercase_center
            \\    center base
            \\    uppercase_right uppercase_top
            \\;
        , &err, 0)).?[0],
    );
}
