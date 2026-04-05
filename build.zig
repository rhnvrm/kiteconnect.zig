const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const websocket_dep = b.dependency("websocket", .{
        .target = target,
        .optimize = optimize,
    });
    const websocket_module = websocket_dep.module("websocket");

    const lib_module = b.addModule("kiteconnect", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "websocket", .module = websocket_module },
        },
    });

    // Build an installable library artifact while also exposing the module for test imports.
    const lib = b.addLibrary(.{
        .name = "kiteconnect",
        .root_module = lib_module,
        .linkage = .static,
    });
    _ = b.addInstallArtifact(lib, .{});

    const unit_test_module = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "websocket", .module = websocket_module },
        },
    });
    const unit_tests = b.addTest(.{
        .root_module = unit_test_module,
    });
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/smoke_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kiteconnect", .module = lib_module },
            },
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);

    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate API documentation");
    docs_step.dependOn(&docs_install.step);

    const examples_step = b.step("examples", "Compile runnable examples");
    addExample(b, examples_step, lib_module, target, optimize, "example-basic", "examples/basic_auth.zig", "Run the basic authenticated REST example");
    addExample(b, examples_step, lib_module, target, optimize, "example-advanced", "examples/advanced_rest.zig", "Run the broader REST showcase example");
    addExample(b, examples_step, lib_module, target, optimize, "example-ticker", "examples/ticker.zig", "Run the ticker/websocket example");
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    lib_module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    step_name: []const u8,
    root_source_path: []const u8,
    description: []const u8,
) void {
    const exe = b.addExecutable(.{
        .name = step_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kiteconnect", .module = lib_module },
            },
        }),
    });

    examples_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step(step_name, description);
    run_step.dependOn(&run_cmd.step);
}
