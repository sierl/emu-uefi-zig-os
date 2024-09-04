const std = @import("std");
const uefi = std.os.uefi;

const WriteError = error{
    /// The device reported an error while attempting to output the text.
    DeviceError,

    /// The output device’s mode is not currently in a defined text mode.
    Unsupported,

    /// This warning code indicates that some of the characters in the string could
    /// not be rendered and were skipped.
    WarnUnknownGlyph,

    InvalidUtf8,
};

const Writer = std.io.GenericWriter(void, WriteError, log_callback);

fn log_callback(context: void, bytes: []const u8) WriteError!usize {
    _ = context;
    return output_utf8(bytes);
}

pub fn output_utf8(bytes: []const u8) WriteError!usize {
    if (!std.unicode.utf8ValidateSlice(bytes)) {
        return WriteError.InvalidUtf8;
    }

    var utf8_iterator = std.unicode.Utf8View.initUnchecked(bytes).iterator();
    while (utf8_iterator.nextCodepoint()) |codepoint| {
        var utf16le: [3]u16 = .{ 0, 0, 0 };

        // Convert code point to utf16le string with null termination.
        if (codepoint < 0x10000) {
            utf16le = .{ @intCast(codepoint), 0, 0 };
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;

            utf16le = .{ high, low, 0 };
        }

        // Write the utf16le string to output console.
        const status = uefi.system_table.con_out.?.outputString(@ptrCast(&utf16le));
        switch (status) {
            .DeviceError => return WriteError.DeviceError,
            .Unsupported => return WriteError.Unsupported,
            .WarnUnknownGlyph => return WriteError.WarnUnknownGlyph,
            .Success => {},
            else => unreachable,
        }
    }

    return bytes.len;
}

/// Print text, ignoring the errors
pub fn print(comptime format: []const u8, args: anytype) void {
    std.fmt.format(Writer{ .context = {} }, format, args) catch return;
}

pub fn log_fn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;
    // const color = comptime switch (level) {
    //     .debug => "\x1b[32m",
    //     .info => "\x1b[36m",
    //     .warn => "\x1b[33m",
    //     .err => "\x1b[31m",
    // };

    // const prefix = color ++ @tagName(scope) ++ ":\x1b[0m ";
    // print(prefix ++ format ++ "\n", args);
    print(format ++ "\r\n", args);
}
