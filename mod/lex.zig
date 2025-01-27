const std = @import("std");
const design = @import("design.zig");

pub const Error = union(enum) {
    invalid_byte: usize,
    overflow: u32,
    unexpected_token: Token,
    duplicate_property: Token,

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
        .invalid_byte => |offset| @compileError(std.fmt.comptimePrint(
            "invalid byte '{}' (0x{x}) at offset {} of string: {s}",
            .{ std.zig.fmtEscapes(s[offset..][0..1]), s[offset], offset, s },
        )),
        .unexpected_token => |token| @compileError("unexpected token '" ++ s[token.start..token.end] ++ "' at offset " ++ std.fmt.comptimePrint("{}", .{token.start}) ++ " of string: " ++ s),
        .duplicate_property => |token| @compileError("duplicated property '" ++ s[token.start..token.end] ++ "'"),
    };
}

pub fn parseOps(comptime s: []const u8) [countOpsCt(s)]design.Op {
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
        .neg, .pos, .num, .eq, .semicolon => return out_err.set(.{
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
            const x, const offset = try parseBoundary(s, out_err, stroke_kind_token.end, .x);
            return .{
                .{ .op = .{ .stroke_vert = .{ .x = x } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else if (std.mem.eql(u8, stroke_kind_str, "horz")) {
            const y, const offset = try parseBoundary(s, out_err, stroke_kind_token.end, .y);
            return .{
                .{ .op = .{ .stroke_horz = .{ .y = y } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else if (std.mem.eql(u8, stroke_kind_str, "diag")) {
            @panic("todo");
        } else if (std.mem.eql(u8, stroke_kind_str, "dot")) {
            const x, var offset = try parseBoundary(s, out_err, stroke_kind_token.end, .x);
            const y, offset = try parseBoundary(s, out_err, offset, .y);
            return .{
                .{ .op = .{ .stroke_dot = .{ .x = x, .y = y } } },
                try expectToken(s, out_err, offset, .semicolon),
            };
        } else if (std.mem.eql(u8, stroke_kind_str, "curve")) {
            @panic("todo");
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
            clip.left, offset = try parseBoundary(s, out_err, eq.end, .x);
        } else if (std.mem.eql(u8, property, "right")) {
            if (clip.right != null) return out_err.set(.{ .duplicate_property = property_token });
            const eq = try nextToken(s, out_err, property_token.end);
            if (eq.kind != .eq) return out_err.set(.{ .unexpected_token = eq });
            clip.right, offset = try parseBoundary(s, out_err, eq.end, .x);
        } else if (std.mem.eql(u8, property, "top")) {
            if (clip.top != null) return out_err.set(.{ .duplicate_property = property_token });
            const eq = try nextToken(s, out_err, property_token.end);
            if (eq.kind != .eq) return out_err.set(.{ .unexpected_token = eq });
            clip.top, offset = try parseBoundary(s, out_err, eq.end, .y);
        } else if (std.mem.eql(u8, property, "bottom")) {
            if (clip.bottom != null) return out_err.set(.{ .duplicate_property = property_token });
            const eq = try nextToken(s, out_err, property_token.end);
            if (eq.kind != .eq) return out_err.set(.{ .unexpected_token = eq });
            clip.bottom, offset = try parseBoundary(s, out_err, eq.end, .y);
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
    comptime dimension: design.Dimension,
) error{Error}!struct { design.Boundary(dimension), usize } {
    const base_token = try nextToken(s, out_err, start);
    const base_token_str = s[base_token.start..base_token.end];

    const BoundaryBase = design.BoundaryBase(dimension);
    const base: BoundaryBase = blk: {
        inline for (std.meta.fields(BoundaryBase)) |field| {
            if (std.mem.eql(u8, base_token_str, field.name)) {
                break :blk @enumFromInt(field.value);
            }
        }
        return out_err.set(.{ .unexpected_token = base_token });
    };

    const between: ?design.Between(dimension) = null;
    var half_stroke_adjust: i8 = 0;

    const end = blk: {
        var offset = base_token.end;
        while (true) {
            _ = &offset;
            const mod_token = try nextToken(s, out_err, offset);
            switch (mod_token.kind) {
                .neg, .pos => {
                    if (half_stroke_adjust != 0) return out_err.set(.{ .unexpected_token = mod_token });
                    const num_token = try nextToken(s, out_err, mod_token.end);
                    switch (num_token.kind) {
                        .eof, .id, .neg, .pos, .eq, .semicolon => return out_err.set(.{ .unexpected_token = num_token }),
                        .num => {},
                    }
                    const num_str = s[num_token.start..num_token.end];
                    const num: u32 = std.fmt.parseInt(u32, num_str, 10) catch return out_err.set(.{ .unexpected_token = num_token });
                    if (mod_token.kind == .pos) {
                        half_stroke_adjust = std.math.cast(i8, num) orelse return out_err.set(.{ .overflow = num });
                    } else {
                        const num_i32 = std.math.cast(i32, num) orelse return out_err.set(.{ .overflow = num });
                        half_stroke_adjust = std.math.cast(i8, -num_i32) orelse return out_err.set(.{ .overflow = num });
                    }
                    offset = num_token.end;
                },
                .id => {
                    const mod_str = s[mod_token.start..mod_token.end];
                    if (std.mem.eql(u8, mod_str, "between")) {
                        @panic("todo");
                    }
                    break :blk offset;
                },
                .eof, .num, .eq => return out_err.set(.{ .unexpected_token = mod_token }),
                .semicolon => break :blk offset,
            }
        }
    };

    return .{
        .{
            .base = base,
            .between = between,
            .half_stroke_adjust = half_stroke_adjust,
        },
        end,
    };
}

const TokenKind = enum { eof, id, neg, pos, num, eq, semicolon };
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
            .semicolon => try writer.writeAll("character ';'"),
        }
    }
};

fn nextToken(s: []const u8, out_err: *Error, start: usize) error{Error}!Token {
    var offset = start;
    while (true) : (offset += 1) {
        if (offset >= s.len) return .{ .kind = .eof, .start = s.len, .end = s.len };
        return switch (s[offset]) {
            0...9 => out_err.set(.{ .invalid_byte = offset }),
            '\n' => continue,
            11, 12 => out_err.set(.{ .invalid_byte = offset }),
            '\r' => continue,
            14...31 => out_err.set(.{ .invalid_byte = offset }),
            ' ' => continue,
            '!'...'*' => out_err.set(.{ .invalid_byte = offset }),
            '+' => .{ .kind = .pos, .start = offset, .end = offset + 1 },
            ',' => out_err.set(.{ .invalid_byte = offset }),
            '-' => .{ .kind = .neg, .start = offset, .end = offset + 1 },
            '.', '/' => out_err.set(.{ .invalid_byte = offset }),
            '0'...'9' => .{ .kind = .num, .start = offset, .end = scan(s, offset + 1, isNumChar) },
            ':' => out_err.set(.{ .invalid_byte = offset }),
            ';' => .{ .kind = .semicolon, .start = offset, .end = offset + 1 },
            '<' => out_err.set(.{ .invalid_byte = offset }),
            '=' => .{ .kind = .eq, .start = offset, .end = offset + 1 },
            '>'...'@' => out_err.set(.{ .invalid_byte = offset }),
            'A'...'Z' => .{ .kind = .id, .start = offset, .end = scan(s, offset + 1, isIdChar) },
            '['...'`' => out_err.set(.{ .invalid_byte = offset }),
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
            .left = .{ .base = .center, .half_stroke_adjust = 1 },
            .right = .{ .base = .uppercase_right, .half_stroke_adjust = -3 },
            .top = .{ .base = .base },
        } } },
        (try parseOp("clip left=center+1 right=uppercase_right-3 top=base;", &err, 0)).?[0],
    );
    try std.testing.expectEqual(
        design.Op{ .op = .{ .stroke_vert = .{
            .x = .{ .base = .uppercase_left, .half_stroke_adjust = -100 },
        } } },
        (try parseOp("stroke vert uppercase_left-100;", &err, 0)).?[0],
    );
}
