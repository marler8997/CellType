const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.addModule("core", .{
        .root_source_file = b.path("core/mod.zig"),
    });

    const glyphs_mod = blk: {
        const exe = b.addExecutable(.{
            .name = "genglyphs",
            .root_source_file = b.path("codegen/genglyphs.zig"),
            .target = b.graph.host,
        });
        const run = b.addRunArtifact(exe);
        run.addFileArg(b.path("glyphs"));
        const glyphs_src = run.addOutputFileArg("glyphs.zig");
        break :blk b.createModule(.{
            .root_source_file = glyphs_src,
            .imports = &.{
                .{ .name = "core", .module = core_mod },
            },
        });
    };

    const render_imports = [_]std.Build.Module.Import{
        .{ .name = "core", .module = core_mod },
        .{ .name = "glyphs", .module = glyphs_mod },
    };
    const celltype_mod = b.addModule("celltype", .{
        .root_source_file = b.path("render/render.zig"),
        .imports = &render_imports,
    });

    {
        const exe = b.addExecutable(.{
            .name = "designer",
            .root_source_file = switch (target.result.os.tag) {
                .windows => b.path("designer/win32.zig"),
                else => b.path("designer/posix.zig"),
            },
            .target = target,
            .optimize = optimize,
            .win32_manifest = b.path("designer/win32.manifest"),
        });
        exe.root_module.addImport("celltype", celltype_mod);
        exe.subsystem = .Windows;

        switch (target.result.os.tag) {
            .windows => if (b.lazyDependency("win32", .{})) |win32_dep| {
                exe.root_module.addImport("win32", win32_dep.module("win32"));
            },
            else => {},
        }
        const install = b.addInstallArtifact(exe, .{});
        const run = b.addRunArtifact(exe);
        run.step.dependOn(&install.step);
        if (b.args) |args| {
            run.addArgs(args);
        }
        b.step("designer", "").dependOn(&run.step);
    }

    const test_step = b.step("test", "");
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{
        .root_source_file = b.path("core/lex.zig"),
    })).step);
    {
        const t = b.addTest(.{
            .root_source_file = b.path("render/PixelBoundary.zig"),
        });
        for (render_imports) |i| {
            t.root_module.addImport(i.name, i.module);
        }
        test_step.dependOn(&b.addRunArtifact(t).step);
    }
}
