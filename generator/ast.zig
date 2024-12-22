const std = @import("std");
const json = std.json;
const mem = std.mem;
const log = std.log;

pub const Item = struct {
  id: []const u8 = "",
  kind: Kind = .Invalid,
  loc: ?Loc = null,
  range: ?Range = null,
  isImplicit: bool = false,
  name: []const u8 = "",
  mangledName: []const u8 = "",
  type: ?Type = null,
  storageClass: []const u8 = "", // extern, static, etc.
    variadic: bool = false, // Указывает на наличие "..." в параметрах функции.
    @"inline": bool = false,
  text: ?[]const u8 = null,
  param: ?[]const u8 = null,
  inner: ?[]Item = null,

  const Self = @This();

  pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    out_stream: anytype,
  ) !void {
    _ = options;
    if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
    try std.fmt.format(out_stream, "{{ .id = {s}, .kind = {}, .loc = {?}, .range = {?}, .isImplicit = {}, .name = {s}, .mangledName = {s}, .type = {?}, .storageClass = {s}, .variadic = {}, .inline = {}, .text = {?s}, .param = {?s}, .inner = {?any} }}", .{ self.id, self.kind, self.loc, self.range, self.isImplicit, self.name, self.mangledName, self.type, self.storageClass, self.variadic, self.@"inline", self.text, self.param, self.inner });
  }

  pub fn qualType(self: Self) ?[]const u8 {
    if (self.type) |t| {
      return t.qualType;
    }

    return null;
  }
};

pub const IncludedFrom = struct {
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
    try std.fmt.format(out_stream, "{{ .file = {s} }}", .{self.file});
  }
};

pub const Loc = struct {
  offset: u32 = 0,
  file: []const u8 = "",
  line: u32 = 0,
  col: u32 = 0,
  tok_len: u32 = 0,
  includedFrom: IncludedFrom = .{},

  const Self = @This();

  pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    out_stream: anytype,
  ) !void {
    _ = options;
    if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
    try std.fmt.format(out_stream, "{{ .offset = {}, .file = {s}, .line = {}, .col = {}, .tok_len = {}, .includedFrom = {} }}", .{ self.offset, self.file, self.line, self.col, self.tok_len, self.includedFrom });
  }
};

pub const RangeValue = struct {
  spellingLoc: Loc = .{},
  expansionLoc: Loc = .{},
};

pub const Range = struct {
  begin: RangeValue = .{},
  end: RangeValue = .{},
};

pub const Type = struct {
  qualType: ?[]const u8 = null,

  const Self = @This();

  pub fn format(
    self: Self,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    out_stream: anytype,
  ) !void {
    _ = options;
    if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
    try std.fmt.format(out_stream, "{{ .qualType = {?s} }}", .{self.qualType});
  }
};

pub const Kind = enum(u8) {
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
