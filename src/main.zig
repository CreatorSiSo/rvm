const std = @import("std");
const io = std.io;
const debug = std.debug;
const panic = debug.panic;
const log = std.log;
const mem = std.mem;
const Allocator = mem.Allocator;
const Endian = std.builtin.Endian;

pub fn main() !void {
    const scope = log.scoped(.main);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stdin_file = io.getStdIn().reader();
    var stdin_buffered = io.bufferedReader(stdin_file);
    const stdin = stdin_buffered.reader();

    const stdout_file = io.getStdOut().writer();
    var stdout_buffered = io.bufferedWriter(stdout_file);
    const stdout = stdout_buffered.writer();

    const module = Module.deserialize(allocator, stdin.any()) catch |err| {
        switch (err) {
            error.Version => scope.err("Could not read version", .{}),
            error.OpCodeLength => scope.err("Could not read opcodes length", .{}),
            error.OpCode => scope.err("Could not read opcode", .{}),
            error.ConstantLength => scope.err("Could not read constants length", .{}),
            error.Constant => scope.err("Could not read constant", .{}),
        }
        std.process.exit(1);
    };
    defer module.deinit();
    try module.print(stdout.any());

    try stdout_buffered.flush();
}

const FormatVersion = struct {
    major: u8,
    minor: u8,
    patch: u8,
};

const Module = struct {
    const Self = @This();

    /// Version of the binary format the Module was deserialized from
    version: FormatVersion,
    opcodes: []OpCode,
    constants: []u64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Self) void {
        self.allocator.free(self.opcodes);
        self.allocator.free(self.constants);
    }

    const DeserializeError = error{
        Version,
        OpCodeLength,
        OpCode,
        ConstantLength,
        Constant,
    };
    pub fn deserialize(allocator: std.mem.Allocator, reader: io.AnyReader) DeserializeError!Self {
        const version = FormatVersion{
            .major = reader.readByte() catch return error.Version,
            .minor = reader.readByte() catch return error.Version,
            .patch = reader.readByte() catch return error.Version,
        };

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

        return Module{
            .version = version,
            .opcodes = opcodes,
            .constants = constants,
            .allocator = allocator,
        };
    }

    pub fn print(self: *const Self, writer: io.AnyWriter) !void {
        try writer.print("version: {}.{}.{}\n", self.version);
        try writer.print("opcodes:\n", .{});
        for (self.opcodes) |opcode| {
            try writer.print("    [{x:0>2}{x:0>6}] {s}, {}\n", .{
                @intFromEnum(opcode.kind),
                opcode.data,
                @tagName(opcode.kind),
                opcode.data,
            });
        }
        try writer.print("constants:\n", .{});
        for (self.constants) |constant| {
            try writer.print("    [{x:0>16}] {}\n", .{ constant, constant });
        }
    }
};

const OpCode = packed struct(u32) {
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
};
