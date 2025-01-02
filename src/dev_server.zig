const std = @import("std");

const mime = @import("mime");

pub fn main() !void {
    const addr = try std.net.Address.parseIp("127.0.0.1", 8001);
    var http_server = try addr.listen(.{ .reuse_address = true });

    const cwd = std.fs.cwd();

    var sfsfsfpath: [std.fs.max_path_bytes]u8 = undefined;
    const fullpath = try std.fs.realpath(".", &sfsfsfpath);
    std.debug.print("cwd: {s}\n", .{fullpath});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var per_request_arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer per_request_arena.deinit();

    std.debug.print("Serving on http://127.0.0.1:{d}\n", .{http_server.listen_address.getPort()});

    var read_buffer: [8000]u8 = undefined;
    accept: while (true) {
        const connection = try http_server.accept();
        defer connection.stream.close();

        var server = std.http.Server.init(connection, &read_buffer);
        while (server.state == .ready) {
            var request: std.http.Server.Request = server.receiveHead() catch |err| {
                std.debug.print("error: {s}\n", .{@errorName(err)});
                continue :accept;
            };

            const file_path = if (std.mem.eql(u8, request.head.target, "/")) "/index.html" else request.head.target;
            std.debug.assert(file_path[0] == '/');
            const cur_file = cwd.openFile(file_path[1..], .{}) catch |err| {
                std.log.err("could not open the request file {s} due to error {s}\n", .{ file_path, @errorName(err) });
                try request.respond("can't find that file", .{ .status = .not_found });
                continue :accept;
            };
            const contents = try cur_file.readToEndAlloc(per_request_arena.allocator(), std.math.maxInt(usize));
            defer per_request_arena.allocator().free(contents);
            const ext = std.fs.path.extension(std.fs.path.basename(file_path));
            const mime_type = extension_map.get(ext) orelse .@"application/octet-stream";
            try request.respond(contents, .{ .extra_headers = &.{
                .{ .name = "content-type", .value = @tagName(mime_type) },
            } });
        }
    }
}

/// The integer values backing these enum tags are not protected by the
/// semantic version of this package but the backing integer type is.
/// The tags are guaranteed to be sorted by name.
pub const Type = enum(u16) {
    @"application/epub+zip",
    @"application/gzip",
    @"application/java-archive",
    @"application/javascript",
    @"application/json",
    @"application/ld+json",
    @"application/msword",
    @"application/octet-stream",
    @"application/ogg",
    @"application/pdf",
    @"application/rtf",
    @"application/vnd.amazon.ebook",
    @"application/vnd.apple.installer+xml",
    @"application/vnd.mozilla.xul+xml",
    @"application/vnd.ms-excel",
    @"application/vnd.ms-fontobject",
    @"application/vnd.ms-powerpoint",
    @"application/vnd.oasis.opendocument.presentation",
    @"application/vnd.oasis.opendocument.spreadsheet",
    @"application/vnd.oasis.opendocument.text",
    @"application/vnd.openxmlformats-officedocument.presentationml.presentation",
    @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    @"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    @"application/vnd.rar",
    @"application/vnd.visio",
    @"application/wasm",
    @"application/x-7z-compressed",
    @"application/x-abiword",
    @"application/x-bzip",
    @"application/x-bzip2",
    @"application/x-cdf",
    @"application/x-csh",
    @"application/x-freearc",
    @"application/x-httpd-php",
    @"application/x-sh",
    @"application/x-shockwave-flash",
    @"application/x-tar",
    @"application/xhtml+xml",
    @"application/xml",
    @"application/zip",
    @"audio/aac",
    @"audio/midi",
    @"audio/mpeg",
    @"audio/ogg",
    @"audio/opus",
    @"audio/wav",
    @"audio/webm",
    @"font/otf",
    @"font/ttf",
    @"font/woff",
    @"font/woff2",
    @"image/bmp",
    @"image/gif",
    @"image/jpeg",
    @"image/png",
    @"image/svg+xml",
    @"image/tiff",
    @"image/vnd.microsoft.icon",
    @"image/webp",
    @"text/calendar",
    @"text/css",
    @"text/csv",
    @"text/html",
    @"text/plain",
    @"video/3gpp",
    @"video/3gpp2",
    @"video/mp2t",
    @"video/mp4",
    @"video/mpeg",
    @"video/ogg",
    @"video/quicktime",
    @"video/webm",
    @"video/x-msvideo",
};

/// Maps file extension to mime type.
pub const extension_map = std.StaticStringMap(Type).initComptime(.{
    .{ ".aac", .@"audio/aac" },
    .{ ".abw", .@"application/x-abiword" },
    .{ ".arc", .@"application/x-freearc" },
    .{ ".avi", .@"video/x-msvideo" },
    .{ ".azw", .@"application/vnd.amazon.ebook" },
    .{ ".bin", .@"application/octet-stream" },
    .{ ".bmp", .@"image/bmp" },
    .{ ".bz", .@"application/x-bzip" },
    .{ ".bz2", .@"application/x-bzip2" },
    .{ ".cda", .@"application/x-cdf" },
    .{ ".csh", .@"application/x-csh" },
    .{ ".css", .@"text/css" },
    .{ ".csv", .@"text/csv" },
    .{ ".doc", .@"application/msword" },
    .{ ".docx", .@"application/vnd.openxmlformats-officedocument.wordprocessingml.document" },
    .{ ".eot", .@"application/vnd.ms-fontobject" },
    .{ ".epub", .@"application/epub+zip" },
    .{ ".gz", .@"application/gzip" },
    .{ ".gif", .@"image/gif" },
    .{ ".htm", .@"text/html" },
    .{ ".html", .@"text/html" },
    .{ ".ico", .@"image/vnd.microsoft.icon" },
    .{ ".ics", .@"text/calendar" },
    .{ ".jar", .@"application/java-archive" },
    .{ ".jpg", .@"image/jpeg" },
    .{ ".jpeg", .@"image/jpeg" },
    .{ ".js", .@"application/javascript" },
    .{ ".json", .@"application/json" },
    .{ ".jsonld", .@"application/ld+json" },
    .{ ".mid", .@"audio/midi" },
    .{ ".mjs", .@"application/javascript" },
    .{ ".mov", .@"video/quicktime" },
    .{ ".mp3", .@"audio/mpeg" },
    .{ ".mp4", .@"video/mp4" },
    .{ ".mpeg", .@"video/mpeg" },
    .{ ".mpkg", .@"application/vnd.apple.installer+xml" },
    .{ ".odp", .@"application/vnd.oasis.opendocument.presentation" },
    .{ ".ods", .@"application/vnd.oasis.opendocument.spreadsheet" },
    .{ ".odt", .@"application/vnd.oasis.opendocument.text" },
    .{ ".oga", .@"audio/ogg" },
    .{ ".ogv", .@"video/ogg" },
    .{ ".ogx", .@"application/ogg" },
    .{ ".opus", .@"audio/opus" },
    .{ ".otf", .@"font/otf" },
    .{ ".png", .@"image/png" },
    .{ ".pdf", .@"application/pdf" },
    .{ ".php", .@"application/x-httpd-php" },
    .{ ".ppt", .@"application/vnd.ms-powerpoint" },
    .{ ".pptx", .@"application/vnd.openxmlformats-officedocument.presentationml.presentation" },
    .{ ".rar", .@"application/vnd.rar" },
    .{ ".rtf", .@"application/rtf" },
    .{ ".sh", .@"application/x-sh" },
    .{ ".svg", .@"image/svg+xml" },
    .{ ".swf", .@"application/x-shockwave-flash" },
    .{ ".tar", .@"application/x-tar" },
    .{ ".tiff", .@"image/tiff" },
    .{ ".ts", .@"video/mp2t" },
    .{ ".ttf", .@"font/ttf" },
    .{ ".txt", .@"text/plain" },
    .{ ".vsd", .@"application/vnd.visio" },
    .{ ".wasm", .@"application/wasm" },
    .{ ".wav", .@"audio/wav" },
    .{ ".weba", .@"audio/webm" },
    .{ ".webm", .@"video/webm" },
    .{ ".webp", .@"image/webp" },
    .{ ".woff", .@"font/woff" },
    .{ ".woff2", .@"font/woff2" },
    .{ ".xhtml", .@"application/xhtml+xml" },
    .{ ".xls", .@"application/vnd.ms-excel" },
    .{ ".xlsx", .@"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" },
    .{ ".xml", .@"application/xml" },
    .{ ".xul", .@"application/vnd.mozilla.xul+xml" },
    .{ ".zip", .@"application/zip" },
    .{ ".3gp", .@"video/3gpp" },
    .{ ".3g2", .@"video/3gpp2" },
    .{ ".7z", .@"application/x-7z-compressed" },
});
