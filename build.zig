const std = @import("std");
const log = std.log.scoped(.sharkuana);

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // const sharkuana_module = b.addModule("root", .{
    //     .root_source_file = b.path("src/sharkuana.zig"),
    //     .optimize = optimize,
    //     .target = target,
    // });
    // addLibsTo(b, sharkuana_module, target.result);
    // sharkuana_module.linkSystemLibrary("glib-2.0", .{});

    const sharkuana_lib = b.addSharedLibrary(.{
        .name = "sharkuana",
        .root_source_file = b.path("src/sharkuana.zig"),
        .target = target,
        .optimize = optimize,
    });
    addLibraryPathsTo(sharkuana_lib);
    b.installArtifact(sharkuana_lib);

    // ZLS magic: https://zigtools.org/zls/guides/build-on-save/
    const sharkuana_lib_check = b.addSharedLibrary(.{
        .name = "sharkuana_check",
        .root_source_file = b.path("src/sharkuana.zig"),
        .target = target,
        .optimize = optimize,
    });
    const check_step = b.step("check", "Check if foo compiles");
    check_step.dependOn(&sharkuana_lib_check.step);
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
