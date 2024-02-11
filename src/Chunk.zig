const std = @import("std");
const io = std.io;
const mem = std.mem;
const Endian = std.builtin.Endian;
const debug = std.debug;
const panic = debug.panic;

const Self = @This();

version: FormatVersion,
opcodes: []OpCode,
constants: []u64,
allocator: mem.Allocator,

pub const FormatVersion = struct {
    major: u8,
    minor: u8,
    patch: u8,
};

pub const DeserializeError = error{
    Version,
    OpCodeLength,
    OpCode,
    ConstantLength,
    Constant,
};

pub const OpCode = packed struct(u32) {
    kind: enum(u8) {
        /// Halt programm, result is at the top of the stack
        Halt = 0x00,
        /// Push value of `Self.data`
        LoadInline = 0x01,
        /// Push value of constant with index `Self.data`
        LoadConstant = 0x02,
        /// Push value of global with index `Self.data`
        LoadGlobal = 0x03,
    },
    data: u24,

    pub fn print(self: OpCode, writer: io.AnyWriter) !void {
        try writer.print("    [{x:0>2}{x:0>6}] {s}, {}\n", .{
            @intFromEnum(self.kind),
            self.data,
            @tagName(self.kind),
            self.data,
        });
    }
};

pub fn deinit(self: *const Self) void {
    self.allocator.free(self.constants);
    self.allocator.free(self.opcodes);
}

pub fn deserialize(allocator: mem.Allocator, reader: io.AnyReader) DeserializeError!Self {
    return Self{
        .version = try deserialize_version(reader),
        .opcodes = try deserialize_opcodes(allocator, reader),
        .constants = try deserialize_constants(allocator, reader),
        .allocator = allocator,
    };
}

fn deserialize_version(reader: io.AnyReader) error{Version}!FormatVersion {
    const version = FormatVersion{
        .major = reader.readByte() catch return error.Version,
        .minor = reader.readByte() catch return error.Version,
        .patch = reader.readByte() catch return error.Version,
    };
    return version;
}

fn deserialize_opcodes(allocator: mem.Allocator, reader: io.AnyReader) error{ OpCodeLength, OpCode }![]OpCode {
    const opcode_len = reader.readInt(u16, Endian.big) catch {
        return error.OpCodeLength;
    };
    const opcodes = allocator.alloc(OpCode, opcode_len) catch {
        panic("Out of memory", .{});
    };
    for (0..opcode_len) |i| {
        opcodes[i] = reader.readStructEndian(OpCode, Endian.big) catch {
            return error.OpCode;
        };
    }
    return opcodes;
}

fn deserialize_constants(allocator: mem.Allocator, reader: io.AnyReader) error{ ConstantLength, Constant }![]u64 {
    const constants_len = reader.readInt(u16, Endian.big) catch {
        return error.ConstantLength;
    };
    const constants = allocator.alloc(u64, constants_len) catch {
        panic("Out of memory", .{});
    };
    for (0..constants_len) |i| {
        constants[i] = reader.readInt(u64, Endian.big) catch {
            return error.Constant;
        };
    }

    return constants;
}

pub fn print(self: *const Self, writer: io.AnyWriter) !void {
    // try writer.print("version: {}.{}.{}\n", self.version);

    try writer.print("opcodes:\n", .{});
    for (self.opcodes) |opcode| {
        try opcode.print(writer);
    }

    try writer.print("constants:\n", .{});
    for (self.constants) |constant| {
        try writer.print("    [{x:0>16}] {}\n", .{ constant, constant });
    }
}
