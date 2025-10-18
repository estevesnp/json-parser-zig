const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("json_parser_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_test = b.addTest(.{
        .root_module = b.addModule("tests", .{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_test = b.addRunArtifact(unit_test);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_test.step);

    const root_test = b.addTest(.{
        .root_module = mod,
    });

    const check_step = b.step("check", "Check project compiles");
    check_step.dependOn(&root_test.step);
}
