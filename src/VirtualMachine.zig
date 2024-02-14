const std = @import("std");
const io = std.io;
const mem = std.mem;

const Chunk = @import("./Chunk.zig");

const Self = @This();

chunk: Chunk,
ip: *Chunk.OpCode,
stack: std.ArrayList(u64),
allocator: mem.Allocator,

const ValueTag = enum(u8) {
    Uint = 1,
    Int = 2,
    Float = 3,
};

const Value = packed union {
    Uint: u64,
    Int: i64,
    Float: f64,
};

test "Value size" {
    try std.testing.expectEqual(@sizeOf(Value), 8);
}

pub fn init(allocator: mem.Allocator, chunk: Chunk) Self {
    if (chunk.opcodes.len == 0) {
        return std.debug.panic("Opcodes empty", .{});
    }
    var self = Self{
        .chunk = chunk,
        .ip = undefined,
        .stack = std.ArrayList(u64).init(allocator),
        .allocator = allocator,
    };
    self.ip = &self.chunk.opcodes[0];
    return self;
}

pub fn deinit(self: *const Self) void {
    self.chunk.deinit();
    self.stack.deinit();
}

pub fn eval(self: *Self) u64 {
    _ = self;
    return 0;
}

pub fn print(self: *const Self, writer: io.AnyWriter) !void {
    try writer.print("ip: ({x})\n", .{@intFromPtr(self.ip)});
    try self.ip.print(writer);

    try writer.print("stack:\n", .{});
    for (self.stack.items) |item| {
        try writer.print("    [{x:0>16}] {}\n", .{ item, item });
    }

    try self.chunk.print(writer);
}
