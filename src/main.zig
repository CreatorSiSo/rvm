const std = @import("std");
const io = std.io;
const debug = std.debug;
const log = std.log;
const mem = std.mem;
const Allocator = mem.Allocator;

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
            error.ReadVersion => scope.err("Could not read version", .{}),
            error.ReadLength => scope.err("Could not read length", .{}),
            error.ReadOpCode => scope.err("Could not read opcode", .{}),
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
    allocator: std.mem.Allocator,

    pub fn deinit(self: Self) void {
        self.allocator.free(self.opcodes);
    }

    const DeserializeError = error{
        ReadVersion,
        ReadLength,
        ReadOpCode,
    };
    pub fn deserialize(allocator: std.mem.Allocator, reader: io.AnyReader) DeserializeError!Self {
        const version = FormatVersion{
            .major = reader.readByte() catch return error.ReadVersion,
            .minor = reader.readByte() catch return error.ReadVersion,
            .patch = reader.readByte() catch return error.ReadVersion,
        };

        const len = reader.readInt(u16, std.builtin.Endian.big) catch {
            return error.ReadLength;
        };
        const opcodes = allocator.alloc(OpCode, len) catch {
            debug.panic("Out of memory", .{});
        };
        for (0..len) |i| {
            opcodes[i] = reader.readStructEndian(OpCode, std.builtin.Endian.big) catch {
                return error.ReadOpCode;
            };
        }

        return Module{
            .version = version,
            .opcodes = opcodes,
            .allocator = allocator,
        };
    }

    pub fn print(self: *const Self, writer: io.AnyWriter) !void {
        try writer.print("Version {}.{}.{}\n", self.version);
        try writer.print("opcodes:\n", .{});
        for (self.opcodes) |opcode| {
            try writer.print("    [{x:0>2}{x:0>6}] {s}, {}\n", .{
                @intFromEnum(opcode.kind),
                opcode.data,
                @tagName(opcode.kind),
                opcode.data,
            });
        }
    }
};

const OpCode = packed struct(u32) {
    kind: enum(u8) {
        /// Push value of constant with index `Self.data`
        LoadConstant = 0x01,
        /// Push value of `Self.data`
        LoadInline = 0x02,
    },
    data: u24,
};
