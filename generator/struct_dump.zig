const std = @import("std");
const log = std.log;

// FIXME: исправить отступы depth, то как проставляются и в params.items не верно отображаются.
pub fn format_struct(value: anytype, out_stream: anytype, depth: usize) !void {
  const anyType = @TypeOf(value);
  const type_info = @typeInfo(anyType);
  if (type_info != .@"struct") {
    @compileError("expected struct argument, found " ++ @typeName(anyType));
  }

  const fields_info = type_info.@"struct".fields;

  for (0..depth) |_| {
    _ = try out_stream.write(" ");
  }

  _ = try out_stream.write("{\n");

  @setEvalBranchQuota(2000000);
  inline for (fields_info) |field| {
    for (0..depth + 2) |_| {
      _ = try out_stream.write(" ");
    }

    _ = try out_stream.write(field.name ++ "(" ++ @typeName(field.type) ++ ") = ");

    try format_value(@field(value, field.name), out_stream, depth);

    _ = try out_stream.write(",\n");
  }

  for (0..depth) |_| {
    _ = try out_stream.write(" ");
  }

  _ = try out_stream.write("}");
}

pub fn format_value(value: anytype, out_stream: anytype, depth: usize) !void {
  const type_of = @TypeOf(value);
  const type_info = @typeInfo(type_of);
  switch (type_of) {
    []const u8 => {
      _ = try out_stream.write("\"");
      _ = try out_stream.write(value);
      _ = try out_stream.write("\"");
    },
    bool => {
      const v = if (value == true) "true" else "false";
      _ = try out_stream.write(v);
    },

    else => switch (type_info) {
      .array => {
        for (value) |v| {
          try format_value(v, out_stream, depth + 2);
        }
      },
      .pointer => |info| {
        switch (info.size) {
          .Many => {
            log.warn("Many: {}: {any}", .{ info, value });
          },
          .Slice => {
            for (0..depth) |_| {
              try out_stream.writeAll(" ");
            }

            try out_stream.writeAll("[\n");
            for (value) |elem| {
              for (0..depth + 4) |_| {
                try out_stream.writeAll(" ");
              }
              try format_value(elem, out_stream, depth + 2);
              try out_stream.writeAll(",\n");
            }
            try out_stream.writeAll("]");
          },
          .One => {
            log.warn("One: {}", .{info.child});
            // try format_value(info.child.*, out_stream, depth);
                    },
          else => {
            log.warn("Failed pointer size: {s}", .{info.size});
          },
        }
      },
      .int => {
        try std.fmt.formatInt(value, 10, .lower, .{}, out_stream);
      },
      .@"struct" => {
        if (@hasDecl(type_of, "format")) {
          try value.format("", .{}, out_stream);
          return;
        }

        try format_struct(value, out_stream, depth + 2);
      },
      .optional => {
        if (value) |u| {
          try format_value(u, out_stream, depth);
        } else {
          _ = try out_stream.write("null");
        }
      },
      else => log.warn("Failed format type: {s}", .{@typeName(type_of)}),
    },
  }
}
