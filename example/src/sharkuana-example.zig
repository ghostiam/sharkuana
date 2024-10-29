// zig build && cp zig-out/lib/libsharkuana-example.dylib  ~/.local/lib/wireshark/plugins/4-4/epan/libsharkuana-example.so && /Applications/Wireshark.app/Contents/MacOS/Wireshark --log-domains sharkuana,sharkuana_example --log-level noisy

const std = @import("std");
const log = std.log.scoped(.sharkuana_example);
const shark = @import("sharkuana");

// This line causes the compiler to export functions from the library.
comptime {
    _ = shark;
}

pub const std_options = .{
    // Set wireshark logger.
    .logFn = shark.wsLogger,
};

pub const wiresharkPlugin = shark.Plugin{
    .version = "1.2.3-example",
    .plugin_describe = .Dissector,
    .protocol = .{
        .name = "Sharkuana example protocol plugin",
        .short_name = "Sharkuana example",
        .filter_name = "sharkuana_example",
    },
    .dissector = .{
        .name = "dissector_name",
        .description = "Dissector description",
        .handler = dissect_zig,
    },
};

fn dissect_zig(tvb: *shark.TvBuff, pinfo: *shark.PacketInfo, tree: *shark.ProtoTree, proto: shark.Proto) shark.DissectorError!i32 {
    const num = pinfo.num;

    log.info("num: {}", .{num});

    _ = tree.AddProtocolFormat(proto.id, tvb, 0, -1, "This is Sharkuana example version {s}, a Wireshark postdissector plugin prototype", .{wiresharkPlugin.version}) catch {};

    return @intCast(tvb.capturedLength());
}
