const std = @import("std");
const io = std.io;
const mem = std.mem;

const Chunk = @import("./Chunk.zig");

const Self = @This();

chunk: Chunk,
ip: *Chunk.OpCode,
stack: std.ArrayList(u64),
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, chunk: Chunk) error{OpCodesEmpty}!Self {
    if (chunk.opcodes.len == 0) {
        return error.OpCodesEmpty;
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

pub fn from_bytes(allocator: mem.Allocator, reader: io.AnyReader) Chunk.DeserializeError!Self {
    const chunk = try Chunk.deserialize(allocator, reader);
    return init(allocator, chunk);
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
