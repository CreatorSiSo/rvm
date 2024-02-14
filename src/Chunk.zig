const std = @import("std");
const io = std.io;
const mem = std.mem;
const Endian = std.builtin.Endian;
const debug = std.debug;
const panic = debug.panic;
const testing = std.testing;

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
    pub const Tag = enum(u8) {
        /// Halt programm, result is at the top of the stack
        Halt = 0,
        /// Push value of constant with index `Self.data`
        LoadConstant = 1,
        /// Push value of global with index `Self.data`
        LoadGlobal = 2,
        /// Relative jump
        Jump = 3,
    };
    pub const Data = packed union {
        uint: u24,
        int: i24,
        bytes: packed struct(u24) { first: u8, second: u8, third: u8 },
    };

    tag: Tag,
    data: Data,

    pub fn init(tag: u8, data: u24) OpCode {
        return OpCode{
            .tag = @enumFromInt(tag),
            .data = Data{ .uint = data },
        };
    }

    pub fn serialize(self: OpCode) u32 {
        // if (@import("builtin").target.cpu.arch.endian() == Endian.little) {
        //     result = @byteSwap(result);
        // }
        return (@as(u32, @intFromEnum(self.tag)) << 24) | self.data.uint;
    }

    pub fn print(self: OpCode, writer: io.AnyWriter) !void {
        try writer.print("[{x:0>8}] {s}", .{
            self.serialize(),
            @tagName(self.tag),
        });
        switch (self.tag) {
            .Halt => {},
            .LoadConstant, .LoadGlobal => {
                try writer.print(", {}", .{self.data.uint});
            },
            .Jump => {
                try writer.print(", {}", .{self.data.int});
            },
        }
    }
};

test "OpCode size" {
    try testing.expect(@sizeOf(OpCode) == 4);
}

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
        opcodes[i] = OpCode.init(
            reader.readByte() catch
                return error.OpCode,
            reader.readInt(u24, Endian.big) catch
                return error.OpCode,
        );
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
