const std = @import("std");
const io = std.io;
const log = std.log;

const VirtualMachine = @import("./VirtualMachine.zig");

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

    const vm = VirtualMachine.from_bytes(allocator, stdin.any()) catch |err| {
        switch (err) {
            error.Version => scope.err("Could not read version", .{}),
            error.OpCodeLength => scope.err("Could not read opcodes length", .{}),
            error.OpCode => scope.err("Could not read opcode", .{}),
            error.ConstantLength => scope.err("Could not read constants length", .{}),
            error.Constant => scope.err("Could not read constant", .{}),
        }
        std.process.exit(1);
    };
    defer vm.deinit();

    try vm.print(stdout.any());
    try stdout_buffered.flush();
}
