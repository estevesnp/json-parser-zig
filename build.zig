const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("json_parser_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lexer_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/Lexer.zig"),
        .target = target,
        .optimize = optimize,
    });

    const parser_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/Parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    const json_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/json.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lexer_unit_tests = b.addRunArtifact(lexer_unit_tests);
    const run_parser_unit_tests = b.addRunArtifact(parser_unit_tests);
    const run_json_unit_tests = b.addRunArtifact(json_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lexer_unit_tests.step);
    test_step.dependOn(&run_parser_unit_tests.step);
    test_step.dependOn(&run_json_unit_tests.step);

    const root_test = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_root_test = b.addRunArtifact(root_test);

    const check_step = b.step("check", "Check application compiles");
    check_step.dependOn(&run_root_test.step);
}
