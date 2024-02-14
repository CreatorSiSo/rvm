const std = @import("std");
const io = std.io;
const log = std.log;

const VirtualMachine = @import("./VirtualMachine.zig");
const Chunk = @import("./Chunk.zig");

pub fn main() !void {
    const scope = log.scoped(.main);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stdin_buffered = io.bufferedReader(io.getStdIn().reader());
    const stdin = stdin_buffered.reader();

    var stdout_buffered = io.bufferedWriter(io.getStdOut().writer());
    // const stdout = stdout_buffered.writer();

    var stderr_buffered = io.bufferedWriter(io.getStdErr().writer());
    const stderr = stderr_buffered.writer();

    const chunk = Chunk.deserialize(allocator, stdin.any()) catch |err| {
        switch (err) {
            error.Version => scope.err("Could not read version", .{}),
            error.OpCodeLength => scope.err("Could not read opcodes length", .{}),
            error.OpCode => scope.err("Could not read opcode", .{}),
            error.ConstantLength => scope.err("Could not read constants length", .{}),
            error.Constant => scope.err("Could not read constant", .{}),
        }
        std.process.exit(1);
    };

    var vm = VirtualMachine.init(allocator, chunk);
    defer vm.deinit();

    try vm.print(stderr.any());
    const result = try vm.eval();
    try vm.print(stderr.any());
    try stderr.print("\nresult: {}\n", .{result});

    try stdout_buffered.flush();
    try stderr_buffered.flush();
}

// Without this no test outside of main.zig get run
test {
    std.testing.refAllDecls(@This());
}
