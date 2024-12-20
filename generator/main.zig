const builtin = @import("builtin");
const std = @import("std");
const json = std.json;
const mem = std.mem;
const log = std.log;
const assert = std.debug.assert;

pub const std_options = std.Options{
    .log_level = if (builtin.mode == .Debug) log.Level.debug else log.Level.info,
    .logFn = coloredLog,
};

// Bitfields https://discord.com/channels/605571803288698900/1313510581671563335
// TODO: TVB добавить метод reader() который преобразует в std.reader

fn coloredLog(
    comptime level: log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const color = switch (level) {
        log.Level.debug => "\x1b[34m", // blue
        log.Level.info => "\x1b[32m", // green
        log.Level.warn => "\x1b[33m", // yellow
        log.Level.err => "\x1b[31m", // red
    };

    const reset = "\x1b[0m";
    const level_txt = switch (level) {
        log.Level.debug => "DEBUG",
        log.Level.info => "INFO",
        log.Level.warn => "WARN",
        log.Level.err => "ERROR",
    };

    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stderr);
    const writer = bw.writer();

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    nosuspend {
        writer.print(color ++ level_txt ++ reset ++ prefix2 ++ format ++ "\n", args) catch return;
        bw.flush() catch return;
    }
}

// nix develop -c zig build generate
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(gpa.deinit() != .leak) catch @panic("memory leak");
    const allocator = gpa.allocator();

    const filename = "wireshark-ast.json";
    const maxJsonSize = 100 * 1024 * 1024;
    const jsonSlice = try std.fs.cwd().readFileAlloc(allocator, filename, maxJsonSize);
    defer allocator.free(jsonSlice);

    var parsed = try std.json.parseFromSlice(AstDumpItem, allocator, jsonSlice, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    try parse(parsed.value, allocator);
}

fn parse(ast_data: AstDumpItem, allocator: mem.Allocator) !void {
    const inner = ast_data.inner orelse return;

    for (inner) |v| {
        const range = v.range orelse continue;

        if (v.isImplicit) {
            continue;
        }

        // Functions
        if (v.kind == .FunctionDecl) {
            const rloc = range.begin.expansionLoc;

            // Skip any external functions.
            if (!mem.startsWith(u8, rloc.file, "wireshark/")) {
                continue;
            }

            // Skip any wmem functions.
            if (mem.startsWith(u8, rloc.file, "wireshark/wsutil/wmem")) {
                continue;
            }

            if (!mem.startsWith(u8, v.name, "proto_tree_add_uint_bits_format_value")) {
                continue;
            }

            var funcData = try FunctionData.parse(allocator, v);
            defer funcData.deinit(allocator);
            log.info("Function: {}", .{funcData});
        }

        // Types
        // if (v.kind == .RecordDecl) {
        //     log.info("Record: {s} -> {?s} ({s}:{})", .{ v.name, v.qualType(), loc.file, loc.line });
        // }
        //
        // if (v.kind == .TypedefDecl) {
        //     log.info("Typedef: {s} -> {?s} ({s}:{})", .{ v.name, v.qualType(), loc.file, loc.line });
        // }
    }
}

// TODO: extract to parser.zig
const FunctionData = struct {
    name: []const u8,
    is_no_return: bool = false,
    return_type: []const u8 = "",
    return_non_null: bool = false,
    is_variadic: bool = false,
    is_deprecated: bool = false,
    visability: []const u8,
    params: std.ArrayListUnmanaged(FunctionParamData) = .empty,
    doc_comment: ?[]const u8 = null,
    format_attr: ?FunctionFormatData = null,

    const Self = @This();

    pub fn parse(allocator: mem.Allocator, fnAstItem: AstDumpItem) !Self {
        var data = Self{
            .name = fnAstItem.name,
            .is_variadic = fnAstItem.variadic,
            .visability = fnAstItem.storageClass,
        };
        errdefer data.deinit(allocator);

        const inner = fnAstItem.inner orelse {
            log.warn("Function {s} has no inner", .{fnAstItem.name});
            return error.FunctionHasNoInner;
        };

        if (fnAstItem.qualType()) |qual_type| {
            const lp = mem.indexOf(u8, qual_type, "(").?;
            data.return_type = mem.trim(u8, qual_type[0..lp], " ");
        }

        for (inner) |item| {
            switch (item.kind) {
                .C11NoReturnAttr => {
                    data.is_no_return = true;
                },
                .ReturnsNonNullAttr => {
                    data.return_non_null = true;
                },
                .DeprecatedAttr => {
                    data.is_deprecated = true;
                },
                .FormatAttr => {
                    const r = item.range orelse unreachable;

                    const bloc = r.begin.expansionLoc;

                    var fp_buf: [std.fs.max_path_bytes]u8 = undefined;
                    const fp = try std.fs.realpath(bloc.file, &fp_buf);

                    const f = try std.fs.openFileAbsolute(fp, .{ .mode = .read_only });
                    defer f.close();

                    try f.seekTo(bloc.offset);

                    var buf: [64]u8 = undefined;
                    const formatAttr = try f.reader().readUntilDelimiterOrEof(&buf, ';');
                    const formatAttrUnwrap = formatAttr orelse unreachable;

                    // example: G_GNUC_PRINTF(1, 2);
                    // log.debug("{s}", .{formatAttrUnwrap});

                    // TODO: exract and add tests
                    const format_str_index = mem.indexOf(u8, formatAttrUnwrap, "(").? + 1;
                    const args_str_index = mem.indexOf(u8, formatAttrUnwrap, ",").? + 1;
                    const end_str_index = mem.indexOf(u8, formatAttrUnwrap, ")").?;

                    const format_str_num = mem.trim(u8, formatAttrUnwrap[format_str_index .. args_str_index - 1], " ");
                    const args_str_num = mem.trim(u8, formatAttrUnwrap[args_str_index..end_str_index], " ");

                    // log.debug("format: {s}, args: {s}", .{ format_str_num, args_str_num });

                    const format_index = std.fmt.parseInt(usize, format_str_num, 10) catch unreachable;
                    const args_index = std.fmt.parseInt(usize, args_str_num, 10) catch unreachable;

                    // TODO использовать для оверайда функции в zig стиль форматинга. G_GNUC_PRINTF(1, 2); где 1 это позиция format, 2 это позиция args.
                    data.format_attr = FunctionFormatData{
                        .format_index = format_index,
                        .args_index = args_index,
                    };
                },
                .ParmVarDecl => {
                    try data.params.append(allocator, try FunctionParamData.parse(item));
                },
                .FullComment => {
                    // TODO https://ziglang.org/documentation/master/#Comments
                    data.doc_comment = try parse_full_comment(allocator, item);
                },
                .VisibilityAttr => {},
                .WarnUnusedResultAttr => {},
                .CompoundStmt => {
                    // В основном такое только у Deprecated функций, поэтому можно просто игнорить.
                    log.warn("CompoundStmt: {s}", .{fnAstItem.name});
                }, // Функция имеет тело.

                else => {
                    log.warn("Unknown item: {}", .{item.kind});
                    continue;
                },
            }
        }

        return data;
    }

    pub fn deinit(self: *Self, allocator: mem.Allocator) void {
        self.params.deinit(allocator);

        if (self.doc_comment) |c| {
            allocator.free(c);
        }
    }

    pub fn format(
        self: Self,
        comptime fmt_empty: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        if (fmt_empty.len != 0) std.fmt.invalidFmtError(fmt_empty, self);

        try format_struct(self, out_stream, 0);
    }
};

// FIXME: исправить отступы depth, то как проставляются и в params.items не верно отображаются.
fn format_struct(value: anytype, out_stream: anytype, depth: usize) !void {
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

fn format_value(value: anytype, out_stream: anytype, depth: usize) !void {
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

fn parse_full_comment(allocator: mem.Allocator, item: AstDumpItem) ![]const u8 {
    const inner = item.inner orelse unreachable;

    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();

    for (inner) |v| {
        try parse_comment(&buf, v);
    }

    return buf.toOwnedSlice();
}

fn parse_comment(buf: *std.ArrayList(u8), item: AstDumpItem) !void {
    switch (item.kind) {
        .TextComment => {
            if (item.text) |t| {
                const v = mem.trim(u8, t, " ");
                if (v.len == 0) return;

                try buf.appendSlice(v);
                try buf.append('\n');
            }
        },
        .ParagraphComment => {
            if (item.inner) |inner| {
                for (inner) |v| {
                    try parse_comment(buf, v);
                }
            }
        },
        .BlockCommandComment => {
            try buf.append('@');
            try buf.appendSlice(item.name);
            try buf.append(' ');

            if (item.inner) |inner| {
                for (inner) |v| {
                    try parse_comment(buf, v);
                }
            }
        },
        .ParamCommandComment => {
            if (item.param) |p| {
                try buf.append('@');
                try buf.appendSlice(p);
                try buf.append(' ');
            }

            if (item.inner) |inner| {
                for (inner) |v| {
                    try parse_comment(buf, v);
                }
            }
        },
        else => {
            log.warn("Unknown comment item: {}", .{item.kind});
        },
    }
}

const FunctionFormatData = struct {
    format_index: usize,
    args_index: usize,
};

const FunctionParamData = struct {
    raw: []const u8,
    name: []const u8,
    type: []const u8,
    is_pointer: bool,
    is_const: bool,

    const Self = @This();

    pub fn parse(item: AstDumpItem) !Self {
        const qual_type = item.qualType() orelse unreachable;
        var raw_type: []const u8 = qual_type;
        const is_pointer = qual_type[qual_type.len - 1] == '*';
        const is_const = mem.startsWith(u8, qual_type, "const ");

        if (is_const) {
            raw_type = raw_type["const ".len..];
        }
        if (is_pointer) {
            raw_type = raw_type[0 .. raw_type.len - 1];
        }

        raw_type = mem.trim(u8, raw_type, " ");

        return .{
            .raw = qual_type,
            .name = item.name,
            .type = raw_type,
            .is_pointer = is_pointer,
            .is_const = is_const,
        };
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);

        var buf: ["*".len + "const ".len]u8 = undefined;
        var w = std.io.fixedBufferStream(&buf);
        if (self.is_pointer) {
            _ = try w.write("*");
        }
        if (self.is_const) {
            _ = try w.write("const ");
        }
        const prefix = w.buffer[0..w.pos];

        try std.fmt.format(out_stream, "{?s}: {s}{s}", .{ self.name, prefix, self.type });
    }
};

const AstDumpItem = struct {
    id: []const u8 = "",
    kind: Kind = .Invalid,
    loc: ?AstDumpLoc = null,
    range: ?AstDumpRange = null,
    isImplicit: bool = false,
    name: []const u8 = "",
    mangledName: []const u8 = "",
    type: ?AstDumpType = null,
    storageClass: []const u8 = "", // extern, static, etc.
    variadic: bool = false, // Указывает на наличие "..." в параметрах функции.
    @"inline": bool = false,
    text: ?[]const u8 = null,
    param: ?[]const u8 = null,
    inner: ?[]AstDumpItem = null,

    const Self = @This();

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        try std.fmt.format(out_stream, ".id = {s}, .kind = {}, .loc = {?}, .range = {?}, .isImplicit = {}, .name = {s}, .mangledName = {s}, .type = {?}, .storageClass = {s}, .variadic = {}, .inline = {}, .text = {?s}, .param = {?s}, .inner = {?any}", .{ self.id, self.kind, self.loc, self.range, self.isImplicit, self.name, self.mangledName, self.type, self.storageClass, self.variadic, self.@"inline", self.text, self.param, self.inner });
    }

    pub fn qualType(self: Self) ?[]const u8 {
        if (self.type) |t| {
            return t.qualType;
        }

        return null;
    }
};

const AstDumpIncludedFrom = struct {
    file: []const u8 = "",

    const Self = @This();

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        try std.fmt.format(out_stream, ".file = {s}", .{self.file});
    }
};
const AstDumpLoc = struct {
    offset: u32 = 0,
    file: []const u8 = "",
    line: u32 = 0,
    col: u32 = 0,
    tok_len: u32 = 0,
    includedFrom: AstDumpIncludedFrom = .{},

    const Self = @This();

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
        try std.fmt.format(out_stream, ".offset = {}, .file = {s}, .line = {}, .col = {}, .tok_len = {}, .includedFrom = {}", .{ self.offset, self.file, self.line, self.col, self.tok_len, self.includedFrom });
    }
};

const AstDumpRangeValue = struct {
    spellingLoc: AstDumpLoc = .{},
    expansionLoc: AstDumpLoc = .{},
};

const AstDumpRange = struct {
    begin: AstDumpRangeValue = .{},
    end: AstDumpRangeValue = .{},
};

const AstDumpType = struct {
    qualType: ?[]const u8 = null,
};

const Kind = enum(u8) {
    Invalid,
    //
    AlignedAttr,
    AllocAlignAttr,
    AllocSizeAttr,
    AlwaysInlineAttr,
    ArraySubscriptExpr,
    ArtificialAttr,
    AsmLabelAttr,
    AttributedType,
    AvailabilityAttr,
    BinaryOperator,
    BlockCommandComment,
    BreakStmt,
    BuiltinAttr,
    BuiltinType,
    C11NoReturnAttr,
    CStyleCastExpr,
    CallExpr,
    CharacterLiteral,
    ColdAttr,
    CompoundAssignOperator,
    CompoundStmt,
    ConditionalOperator,
    ConstAttr,
    ConstantArrayType,
    ConstantExpr,
    DeclRefExpr,
    DeclStmt,
    DeprecatedAttr,
    DiagnoseIfAttr,
    DoStmt,
    ElaboratedType,
    EnumConstantDecl,
    EnumDecl,
    EnumType,
    FieldDecl,
    ForStmt,
    FormatArgAttr,
    FormatAttr,
    FullComment,
    FunctionDecl,
    FunctionProtoType,
    GNUInlineAttr,
    IfStmt,
    ImplicitCastExpr,
    InlineCommandComment,
    IntegerLiteral,
    MemberExpr,
    ModeAttr,
    NoEscapeAttr,
    NoThrowAttr,
    NonNullAttr,
    OverloadableAttr,
    PackedAttr,
    ParagraphComment,
    ParamCommandComment,
    ParenExpr,
    ParenType,
    ParmVarDecl,
    PassObjectSizeAttr,
    PointerType,
    PredefinedExpr,
    PureAttr,
    QualType,
    RecordDecl,
    RecordType,
    RestrictAttr,
    ReturnStmt,
    ReturnsNonNullAttr,
    ReturnsTwiceAttr,
    SentinelAttr,
    StmtExpr,
    StringLiteral,
    SwiftAttrAttr,
    TextComment,
    TranslationUnitDecl,
    TypedefDecl,
    TypedefType,
    UnaryExprOrTypeTraitExpr,
    UnaryOperator,
    UnusedAttr,
    VarDecl,
    VerbatimBlockComment,
    VerbatimBlockLineComment,
    VerbatimLineComment,
    VisibilityAttr,
    WarnUnusedResultAttr,
    WeakAttr,
    WhileStmt,

    pub fn jsonParse(allocator: mem.Allocator, source: *json.Scanner, options: json.ParseOptions) !Kind {
        var name: []const u8 = undefined;

        switch (try source.nextAlloc(allocator, options.allocate.?)) {
            .string, .allocated_string => |value| {
                name = value;
            },
            else => return error.UnexpectedToken,
        }

        return std.meta.stringToEnum(Kind, name) orelse {
            log.err("Invalid enum tag: {s}", .{name});
            return .Invalid;
        };
    }
};
