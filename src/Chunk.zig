const std = @import("std");
const io = std.io;
const mem = std.mem;
const Endian = std.builtin.Endian;
const debug = std.debug;
const panic = debug.panic;
const expect = std.testing.expect;

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
    OpCodesEmpty,
    ConstantLength,
    Constant,
};

pub const OpCode = union(enum(u8)) {
    /// Halt programm, result is at the top of the stack
    Halt = 0,
    /// Push value of `Self.data`
    LoadInline: u24 = 1,
    /// Push value of constant with index `Self.data`
    LoadConstant: u24 = 2,
    /// Push value of global with index `Self.data`
    LoadGlobal: u24 = 3,
    /// Relative jump
    Jump: i24 = 4,

    pub fn init(tag: u8, data: u24) OpCode {
        return switch (tag) {
            0 => OpCode.Halt,
            1 => OpCode{ .LoadInline = data },
            2 => OpCode{ .LoadConstant = data },
            3 => OpCode{ .LoadGlobal = data },
            4 => OpCode{ .Jump = @bitCast(data) },
            else => unreachable,
        };
    }

    pub fn serialize(self: OpCode) u32 {
        var result: u24 = 0;
        switch (self) {
            .Halt => {},
            .LoadConstant, .LoadGlobal, .LoadInline => |data| result = data,
            .Jump => |data| result = @bitCast(data),
        }
        // if (@import("builtin").target.cpu.arch.endian() == Endian.little) {
        //     result = @byteSwap(result);
        // }
        return (@as(u32, @intFromEnum(self)) << 24) | result;
    }

    pub fn print(self: OpCode, writer: io.AnyWriter) !void {
        try writer.print("    [{x:0>8}] {s}, ", .{
            self.serialize(),
            @tagName(self),
        });
        switch (self) {
            .Halt => {},
            .LoadInline, .LoadConstant, .LoadGlobal => |data| {
                try writer.print("{}", .{data});
            },
            .Jump => |data| {
                try writer.print("{}", .{data});
            },
        }
        try writer.writeAll("\n");
    }
};

test "OpCode size" {
    const opcode = OpCode{.Halt};
    try expect(@sizeOf(opcode) == 4);
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
