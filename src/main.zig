const std = @import("std");
const io = std.io;
const print = std.debug.print;
const Tuple = std.meta.Tuple;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    const stdin_file = io.getStdIn().reader();
    var stdin_buffered = io.bufferedReader(stdin_file);
    const stdin = stdin_buffered.reader();

    // const stdout_file = io.getStdOut().writer();
    // var stdout_buffered = io.bufferedWriter(stdout_file);
    // const stdout = stdout_buffered.writer();

    const version = try parse_version(@TypeOf(stdin), stdin);
    print("Version {}.{}.{}\n", version);

    const len = try stdin.readInt(u64, std.builtin.Endian.big);
    const bytes = try stdin.readAllAlloc(allocator, len);
    print("Read {} bytes\n", .{bytes.len});

    for (bytes) |byte| {
        print("{}\n", .{byte});
    }
}

const FormatVersion = Tuple(&.{ u8, u8, u8 });

fn parse_version(comptime Reader: type, input: Reader) !FormatVersion {
    const major = try input.readByte();
    const minor = try input.readByte();
    const patch = try input.readByte();
    return .{ major, minor, patch };
}

const Module = struct {};
