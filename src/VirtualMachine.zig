const std = @import("std");
const io = std.io;
const mem = std.mem;

const Chunk = @import("./Chunk.zig");
const OpCode = Chunk.OpCode;

const Self = @This();

chunk: Chunk,
ip: usize,
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
    return Self{
        .chunk = chunk,
        .ip = 0,
        .stack = std.ArrayList(u64).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *const Self) void {
    self.chunk.deinit();
    self.stack.deinit();
}

pub fn eval(self: *Self) !u64 {
    while (true) {
        const opcode = self.current_opcode();

        switch (opcode.tag) {
            OpCode.Tag.Halt => break,
            OpCode.Tag.LoadConstant => {
                const value = self.chunk.constants[opcode.data.uint];
                try self.stack.append(value);
            },
            OpCode.Tag.LoadGlobal => {},
            OpCode.Tag.Jump => {
                if (opcode.data.int < 0) {
                    self.ip -= @intCast(-opcode.data.int);
                } else {
                    self.ip += @intCast(opcode.data.int);
                }
                continue;
            },
        }

        self.ip += 1;
    }
    return self.stack.pop();
}

pub fn print(self: *const Self, writer: io.AnyWriter) !void {
    try writer.writeAll("Virtual Machine {\n");
    try writer.print("    ip: {}\n", .{self.ip});

    try writer.print("    constants:\n", .{});
    for (self.chunk.constants) |constant| {
        try writer.print("        [{x:0>16}] {}\n", .{ constant, constant });
    }

    try writer.print("    opcodes:\n", .{});
    for (0.., self.chunk.opcodes) |i, opcode| {
        try writer.writeAll(if (i == self.ip) "    --> " else "        ");
        try opcode.print(writer);
        try writer.writeAll("\n");
    }

    try writer.print("    stack:\n", .{});
    for (self.stack.items) |value| {
        try writer.print("        [{x:0>16}] {}\n", .{ value, value });
    }
    try writer.writeAll("}\n");
}

inline fn current_opcode(self: *const Self) Chunk.OpCode {
    return self.chunk.opcodes[self.ip];
}
