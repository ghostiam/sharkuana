const std = @import("std");
const log = std.log.scoped(.sharkuana);

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const options = .{};

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }

    const options_module = options_step.createModule();

    const m = b.addModule("root", .{
        .root_source_file = b.path("src/sharkuana.zig"),
        .imports = &.{
            .{ .name = "sharkuana_options", .module = options_module },
        },
        .optimize = optimize,
    });
    addLibsTo(b, m, target.result);
    m.addIncludePath(b.path("src"));
}

pub fn addLibraryPathsTo(compile_step: *std.Build.Step.Compile) void {
    const b = compile_step.step.owner;
    const target = compile_step.rootModuleTarget();

    addLibsTo(b, compile_step, target);
}

pub fn addLibsTo(b: *std.Build, compile_step: anytype, target: std.Target) void {
    const ws_dep = b.dependency("wireshark", .{});

    compile_step.addIncludePath(ws_dep.path(""));
    compile_step.addIncludePath(ws_dep.path("include"));
    compile_step.addIncludePath(ws_dep.path("epan"));
    compile_step.addIncludePath(ws_dep.path("wsutil"));

    // TODO: generate ws_version.h file and put in plugin include path instead build wireshark libs?
    compile_step.addIncludePath(ws_dep.path("build"));

    switch (target.os.tag) {
        .macos => {
            // TODO: glib as dependency?
            compile_step.addIncludePath(.{ .cwd_relative = "/opt/homebrew/lib/glib-2.0/include" }); // contains glibconfig.h
            compile_step.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include/glib-2.0" });

            compile_step.addObjectFile(ws_dep.path("build/run/libwireshark.dylib"));
            compile_step.addObjectFile(ws_dep.path("build/run/libwsutil.dylib"));
        },
        else => {},
    }
}
