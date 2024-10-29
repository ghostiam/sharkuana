const root = @import("root");
const std = @import("std");
const c = @cImport({
    @cInclude("epan/packet.h");
});

export const plugin_version: [root.pluginVersion.len:0]u8 = root.pluginVersion.*;
export const plugin_want_major: c_int = c.WIRESHARK_VERSION_MAJOR;
export const plugin_want_minor: c_int = c.WIRESHARK_VERSION_MINOR;

pub const PluginDesc = enum(u32) {
    Dissector = 1 << 0,
    FileType = 1 << 1,
    Codec = 1 << 2,
    Epan = 1 << 3,
    TapListener = 1 << 4,
    DFilter = 1 << 5,
};

export fn plugin_describe() u32 {
    return @intFromEnum(root.plugin_describe());
}

export fn plugin_register() void {
    wsLogger(.debug, .sharkuana, "Register plugin", .{});

    const plug = proto_plugin{
        .register_protoinfo = root.proto_register,
        .register_handoff = if (@hasDecl(root, "proto_reg_handoff")) root.proto_reg_handoff else null,
    };
    proto_register_plugin(&plug);
}

pub const TvBuff = opaque{
    pub fn capturedLength(tvb: *TvBuff) u32 {
        return tvb_captured_length(tvb);
    }
    extern fn tvb_captured_length(tvb: *TvBuff) c_uint;
};

pub const PacketInfo = extern struct {
    current_proto: *const u8,
    cinfo: *c.epan_column_info,
    presence_flags: u32,
    num: u32,
    abs_ts: std.posix.timeval
};

pub const ProtoTree = opaque {
    pub fn AddProtocolFormat(tree: *ProtoTree, fieldIndex: i32, tvb: *TvBuff, start: c_int, length: c_int, comptime format: []const u8, args: anytype) !*c.proto_item {
        const alloc = std.heap.page_allocator; // TODO: extract allocator.
        const msg = try std.fmt.allocPrintZ(alloc, format, args);
        defer alloc.free(msg);

        return proto_tree_add_protocol_format(tree, fieldIndex, tvb, start, length, msg);
    }
    extern fn proto_tree_add_protocol_format(tree: *ProtoTree, hfindex: i32, tvb: *TvBuff, start: c_int, length: c_int, format: [*:0]const u8, ...) *c.proto_item;
};


const proto_plugin = extern struct {
    register_protoinfo: ?*const fn () void,
    register_handoff: ?*const fn () void,
};
extern fn proto_register_plugin(plugin: *const proto_plugin) void;

pub const DissectorFn = *const fn (*TvBuff, *PacketInfo, *ProtoTree, ?*anyopaque) callconv(.C) i32;

pub const DissectorHandle = opaque {
    pub fn registerPostdissector(handle: *DissectorHandle) void {
        register_postdissector(handle);
    }
    extern fn register_postdissector(handle: *DissectorHandle) void;
};

pub const Proto = extern struct {
    id: i32,

    pub fn createDissectorHandle(proto: *Proto, dissector: DissectorFn) *DissectorHandle {
        return create_dissector_handle(dissector, proto.id);
    }
    extern fn create_dissector_handle(dissector: DissectorFn, proto: c_int) *DissectorHandle;
};

pub fn protoRegisterProtocol(name: [*:0]const u8, short_name: [*:0]const u8, filter_name: [*:0]const u8) Proto {
    return proto_register_protocol(name, short_name, filter_name);
}
extern fn proto_register_protocol(name: [*:0]const u8, short_name: [*:0]const u8, filter_name: [*:0]const u8) Proto;

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
