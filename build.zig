const std = @import("std");
const log = std.log.scoped(.sharkuana);

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    //      ┌──────────────────────────────────────────────────────────┐
    //      │                        SHARKUANA                         │
    //      └──────────────────────────────────────────────────────────┘

    // const sharkuana_module = b.addModule("root", .{
    //     .root_source_file = b.path("src/sharkuana.zig"),
    //     .optimize = optimize,
    //     .target = target,
    // });
    // addLibsTo(b, sharkuana_module, target.result);
    // sharkuana_module.linkSystemLibrary("glib-2.0", .{});

    const sharkuana_lib_name = "sharkuana";

    // Library
    const sharkuana_lib = b.addSharedLibrary(.{
        .name = sharkuana_lib_name,
        .root_source_file = b.path("src/sharkuana.zig"),
        .target = target,
        .optimize = optimize,
    });
    addLibraryPathsTo(sharkuana_lib);
    b.installArtifact(sharkuana_lib);

    // Check
    const sharkuana_lib_check = b.addSharedLibrary(.{
        .name = sharkuana_lib_name ++ "_check",
        .root_source_file = sharkuana_lib.root_module.root_source_file,
        .target = target,
        .optimize = optimize,
    });

    //      ┌──────────────────────────────────────────────────────────┐
    //      │                        GENERATOR                         │
    //      └──────────────────────────────────────────────────────────┘

    const generator_exe_name = "generator";

    // Generate
    const generator_exe = b.addExecutable(.{
        .name = generator_exe_name,
        .root_source_file = b.path("generator/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(generator_exe);

    const generate_cmd = b.addRunArtifact(generator_exe);
    const generate_step = b.step("generate", "Run bindings generator");
    generate_step.dependOn(&generate_cmd.step);

    // Test
    const generator_test = b.addTest(.{
        .name = generator_exe_name ++ "_test",
        .root_source_file = generator_exe.root_module.root_source_file.?,
        .target = target,
        .optimize = optimize,
    });
    const run_generator_tests = b.addRunArtifact(generator_test);

    // Check
    const generator_exe_check = b.addExecutable(.{
        .name = generator_exe_name ++ "_check",
        .root_source_file = generator_exe.root_module.root_source_file,
        .target = target,
        .optimize = optimize,
    });

    //      ┌──────────────────────────────────────────────────────────┐
    //      │                        CHECK STEP                        │
    //      └──────────────────────────────────────────────────────────┘

    // ZLS magic: https://zigtools.org/zls/guides/build-on-save/
    const check_step = b.step("check", "Check if foo compiles");
    check_step.dependOn(&sharkuana_lib_check.step);
    check_step.dependOn(&generator_exe_check.step);

    //      ┌──────────────────────────────────────────────────────────┐
    //      │                        TEST STEP                         │
    //      └──────────────────────────────────────────────────────────┘

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_generator_tests.step);
}

pub fn addLibraryPathsTo(compile_step: *std.Build.Step.Compile) void {
    const b = compile_step.step.owner;
    const target = compile_step.rootModuleTarget();
    addLibsTo(b, compile_step, target);

    compile_step.linkSystemLibrary("glib-2.0");
}

pub fn addLibsTo(b: *std.Build, compile_step: anytype, target: std.Target) void {
    const ws_dep = b.dependency("wireshark", .{});

    switch (target.os.tag) {
        .macos => {
            compile_step.addObjectFile(ws_dep.path("build-Darwin/run/libwireshark.dylib"));
            compile_step.addObjectFile(ws_dep.path("build-Darwin/run/libwsutil.dylib"));
        },
        .linux, .freebsd => {
            compile_step.addObjectFile(ws_dep.path("build-Linux/run/libwireshark.so"));
            compile_step.addObjectFile(ws_dep.path("build-Linux/run/libwsutil.so"));
        },
        .windows => {
            compile_step.addObjectFile(ws_dep.path("build-Windows/run/libwireshark.dll"));
            compile_step.addObjectFile(ws_dep.path("build-Windows/run/libwsutil.dll"));
        },
        else => @panic("unsupported OS"),
    }
}
