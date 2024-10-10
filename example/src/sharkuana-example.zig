const std = @import("std");
const log = std.log.scoped(.sharkuana_example);
const shark = @import("sharkuana");

// This line causes the compiler to export functions from the library.
comptime { _ = shark; }

pub const std_options = .{
    // Set wireshark logger.
    .logFn = shark.wsLogger,
};

// zig build && cp zig-out/lib/libsharkuana-example.dylib  ~/.local/lib/wireshark/plugins/4-4/epan/libsharkuana-example.so && /Applications/Wireshark.app/Contents/MacOS/Wireshark --log-domains sharkuana,sharkuana_example --log-level noisy
pub const pluginVersion = "1.2.3";

pub fn proto_reg_handoff() void {
    log.info("proto_reg_handoff_zig", .{});
}

var proto: shark.Proto = undefined;

pub fn proto_register() void {
    log.info("proto_register_zig", .{});

    proto = shark.protoRegisterProtocol("Sharkuana example protocol plugin", "Sharkuana example", "sharkuana_example");
    const handler = proto.createDissectorHandle(dissect_zig);
    handler.registerPostdissector();
}

pub fn plugin_describe() shark.PluginDesc {
    return .Epan;
}

fn dissect_zig(tvb: ?*shark.tvbuff_t, pinfo: ?*shark.PacketInfo, tree: shark.ProtoTree, _: ?*anyopaque) callconv(.C) c_int {
    const num = pinfo.?.*.num;

    log.info("num: {}", .{num});

    _ = tree.AddProtocolFormat(proto, tvb.?, 0, -1, "This is Sharkuana example version {s}, a Wireshark postdissector plugin prototype", .{pluginVersion}) catch {};

    return @intCast(shark.tvb_captured_length(tvb.?));
}
