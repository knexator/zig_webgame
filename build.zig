const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const actual_target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseSmall;
    // const optimize: std.builtin.OptimizeMode = .Debug;

    const exe = b.addExecutable(.{
        .name = "webgame_v0",
        .root_source_file = b.path("src/view.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });

    exe.global_base = 6560;
    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.export_memory = true;
    exe.stack_size = std.wasm.page_size;

    const webgame_install_dir = std.Build.InstallDir{ .custom = "dist" };
    const compile_wasm = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = webgame_install_dir },
    });
    b.getInstallStep().dependOn(&compile_wasm.step);
    const copy_static_files = b.addInstallDirectory(.{
        .install_dir = webgame_install_dir,
        .install_subdir = "",
        .source_dir = b.path("static"),
    });
    b.getInstallStep().dependOn(&copy_static_files.step);

    const generate_keycodes = b.addExecutable(.{
        .name = "generate_keycodes",
        .root_source_file = b.path("src/generate_keycodes_js.zig"),
        .target = b.graph.host,
    });
    const generate_keycodes_step = b.addRunArtifact(generate_keycodes);
    const output = generate_keycodes_step.addOutputFileArg("keycodes.js");
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(output, webgame_install_dir, "keycodes.js").step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/domain.zig"),
        .target = actual_target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const dev_server_exe = b.addExecutable(.{
        .name = "dev_server",
        .root_source_file = b.path("src/dev_server.zig"),
        .target = actual_target,
        .optimize = optimize,
    });
    dev_server_exe.root_module.addImport("mime", b.dependency("mime", .{
        .target = actual_target,
        .optimize = optimize,
    }).module("mime"));
    const run_dev_server = b.addRunArtifact(dev_server_exe);
    run_dev_server.step.dependOn(b.getInstallStep());
    run_dev_server.addArg(b.getInstallPath(webgame_install_dir, ""));
    const run_dev_server_step = b.step("dev", "Run the dev server");
    run_dev_server_step.dependOn(&run_dev_server.step);
}
