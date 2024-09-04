const std = @import("std");
const output = @import("output.zig");

const uefi = std.os.uefi;
const log = std.log.scoped(.loader);

/// Standard Library Options
pub const std_options = .{
    .log_level = .debug,
    .logFn = output.log_fn,
};

fn hang() noreturn {
    while (true) {
        std.atomic.spinLoopHint();
    }
}

const utf16le = std.unicode.utf8ToUtf16LeStringLiteral;

fn get_key() uefi.protocol.SimpleTextInput.Key.Input {
    const con_in = uefi.system_table.con_in.?;
    const boot_services = uefi.system_table.boot_services.?;

    var index: usize = undefined;
    _ = boot_services.waitForEvent(1, @ptrCast(&con_in.wait_for_key), &index);

    std.debug.assert(index != 0);

    var key: uefi.protocol.SimpleTextInput.Key.Input = undefined;
    _ = con_in.readKeyStroke(&key);
    return key;
}

pub fn panic(message: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    @setCold(true);

    _ = uefi.system_table.con_out.?.outputString(utf16le("Loader Panic!\r\n"));
    _ = output.output_utf8(message) catch {};
    _ = uefi.system_table.con_out.?.outputString(utf16le("\r\n"));

    hang();
}

pub fn main() void {
    const con_out = uefi.system_table.con_out.?;

    _ = con_out.reset(false);
    _ = con_out.setAttribute(uefi.protocol.SimpleTextOutput.white | uefi.protocol.SimpleTextOutput.background_black);

    _ = con_out.clearScreen();

    _ = con_out.outputString(utf16le("Hello, world\r\n"));
    _ = con_out.outputString(utf16le("hoho\r\n"));

    log.debug("heheheh", .{});

    var max_columns: usize = undefined;
    var max_rows: usize = undefined;
    _ = con_out.queryMode(con_out.mode.mode, &max_columns, &max_rows);

    log.debug("Mode: {any}", .{con_out.mode.*});
    log.debug("max columns: {}", .{max_columns});
    log.debug("max rows: {}", .{max_rows});

    log.debug("Enter something: ", .{});
    const key = get_key();
    log.debug("Key: {any}", .{key});

    hang();
}
