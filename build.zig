const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("json_parser_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_test_files = [_][]const u8{
        "src/Lexer.zig",
        "src/Parser.zig",
        "src/json.zig",
    };

    const test_step = b.step("test", "Run unit tests");

    for (unit_test_files) |test_file| {
        const unit_test = b.addTest(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });

        const run_test = b.addRunArtifact(unit_test);

        test_step.dependOn(&run_test.step);
    }

    const root_test = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_root_test = b.addRunArtifact(root_test);

    const check_step = b.step("check", "Check project compiles");
    check_step.dependOn(&run_root_test.step);
}
