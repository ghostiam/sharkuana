const std = @import("std");
const log = std.log.scoped(.sharkuana);

// nix develop -c zig build && cp zig-out/lib/libsharkuana.dylib ~/.local/lib/wireshark/plugins/4-4/epan/libsharkuana.so && /Applications/Wireshark.app/Contents/MacOS/Wireshark --log-domains sharkuana --log-level noisy
pub const std_options = std.Options{
    // Set wireshark logger.
    .logFn = wsLogger,
};

const version = "1.2.3";

pub export const plugin_version: [version.len:0]u8 = version.*;
pub export const plugin_want_major: c_int = 4;
pub export const plugin_want_minor: c_int = 4;

fn proto_register_zig() void {
    const proto_my_plugin = proto_register_protocol("Wireshark Hello Plugin ZIG", "Hello WS ZIG", "hello_ws_zig");
    log.debug("Proto: {}", .{proto_my_plugin});
}
extern fn proto_register_protocol(name: [*:0]const u8, short_name: [*:0]const u8, filter_name: [*:0]const u8) c_int;

pub export fn plugin_register() void {
    log.info("Hello from ZIG plugin_register", .{});

    const plug: proto_plugin = proto_plugin{
        .register_protoinfo = proto_register_zig,
        .register_handoff = null,
    };
    proto_register_plugin(&plug);
}
pub const proto_plugin = extern struct {
    register_protoinfo: ?*const fn () void,
    register_handoff: ?*const fn () void = null,
};
extern fn proto_register_plugin(plugin: [*c]const proto_plugin) void;

// Logger

pub fn wsLogger(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const wsLvl = switch (level) {
        .debug => enum_ws_log_level.LOG_LEVEL_DEBUG,
        .info => enum_ws_log_level.LOG_LEVEL_INFO,
        .warn => enum_ws_log_level.LOG_LEVEL_WARNING,
        .err => enum_ws_log_level.LOG_LEVEL_ERROR,
    };

    const alloc = std.heap.page_allocator; // TODO: extract allocator.
    const msg = std.fmt.allocPrintZ(alloc, format, args) catch {
        return;
    };
    defer alloc.free(msg);

    ws_log(@tagName(scope), wsLvl, msg);
}

const enum_ws_log_level = enum(c_uint) {
    LOG_LEVEL_NONE = 0,
    LOG_LEVEL_NOISY = 1,
    LOG_LEVEL_DEBUG = 2,
    LOG_LEVEL_INFO = 3,
    LOG_LEVEL_MESSAGE = 4,
    LOG_LEVEL_WARNING = 5,
    LOG_LEVEL_CRITICAL = 6,
    LOG_LEVEL_ERROR = 7,
    LOG_LEVEL_ECHO = 8,
};
extern fn ws_log(domain: [*]const u8, level: enum_ws_log_level, format: [*c]const u8, ...) void;
