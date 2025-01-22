const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const celltype_mod = b.addModule("celltype", .{
        .root_source_file = b.path("mod/celltype.zig"),
    });

    {
        const exe = b.addExecutable(.{
            .name = "viewer",
            .root_source_file = switch (target.result.os.tag) {
                .windows => b.path("viewer/win32.zig"),
                else => b.path("viewer/posix.zig"),
            },
            .target = target,
            .optimize = optimize,
            .win32_manifest = b.path("viewer/win32.manifest"),
        });
        exe.root_module.addImport("celltype", celltype_mod);

        switch (target.result.os.tag) {
            .windows => if (b.lazyDependency("win32", .{})) |win32_dep| {
                exe.root_module.addImport("win32", win32_dep.module("win32"));
            },
            else => {},
        }
        const install = b.addInstallArtifact(exe, .{});
        const run = b.addRunArtifact(exe);
        run.step.dependOn(&install.step);
        b.step("viewer", "").dependOn(&run.step);
    }
}
