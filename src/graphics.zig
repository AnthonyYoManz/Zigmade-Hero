const std = @import("std");
const k32 = std.os.windows.kernel32;
usingnamespace std.os.windows;
usingnamespace std.os.windows.user32;

usingnamespace @import("common.zig");
usingnamespace @import("win32_extension.zig");

pub const Colour = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn rgb(r: u8, g: u8, b: u8) Colour {
        return Colour{
            .r = r,
            .g = g,
            .b = b,
            .a = 255,
        };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Colour {
        return Colour{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

pub const Bitmap = struct {
    data: ?*VOID,
    width: i32,
    height: i32,
    bytes_per_pixel: i32,
    info: BITMAPINFO,

    pub fn withSize(size: Size) Bitmap {
        return Bitmap{
            .data = null,
            .width = size.w,
            .height = size.h,
            .info = BITMAPINFO{
                .bmiHeader = BITMAPINFOHEADER{
                    .biSize = @sizeOf(BITMAPINFOHEADER),
                    .biWidth = size.w,
                    .biHeight = -size.h,
                    .biPlanes = 1,
                    .biBitCount = 32,
                    .biCompression = BI_RGB,
                    .biSizeImage = 0,
                    .biXPelsPerMeter = 0,
                    .biYPelsPerMeter = 0,
                    .biClrUsed = 0,
                    .biClrImportant = 0,
                },
                .bmiColors = undefined,
            },
            .bytes_per_pixel = 4,
        };
    }
};

pub fn win32ResizeBmp(bmp: *Bitmap, new_size: Size) void {
    // Update bitmap info
    bmp.width = new_size.w;
    bmp.height = new_size.h;
    bmp.info.bmiHeader.biWidth = new_size.w;
    bmp.info.bmiHeader.biHeight = -new_size.h;

    // Free existing bitmap data
    if (bmp.data != null) {
        _ = VirtualFree(bmp.data, 0, MEM_RELEASE);
        bmp.data = null;
    }

    // Alloc new bitmap data
    const signed_size = bmp.bytes_per_pixel * bmp.width * bmp.height;
    if (signed_size > 0) {
        const size = @intCast(usize, signed_size);
        bmp.data = VirtualAlloc(null, size, MEM_COMMIT, PAGE_READWRITE) catch null;
    }

    // Write some default value to the new bitmap data
    fillBmp(bmp, Colour.rgb(0, 0, 0));
}

pub fn renderWeirdGradient(bmp: *Bitmap, tick: usize) void {
    if (bmp.data == null) {
        return;
    }

    const data_addr = @ptrToInt(bmp.data);
    const pitch = @intCast(usize, bmp.width * bmp.bytes_per_pixel);

    var rowIdx: usize = 0;
    var y: usize = 0;
    while (y < bmp.height) : (y += 1) {
        var x: usize = 0;
        while (x < bmp.width) : (x += 1) {
            const idx = rowIdx + x * @intCast(usize, bmp.bytes_per_pixel);
            @intToPtr(*u8, data_addr + idx + 0).* = 0;
            @intToPtr(*u8, data_addr + idx + 1).* = 0;
            @intToPtr(*u8, data_addr + idx + 2).* = @intCast(u8, (tick +% (x ^ y)) & 0xFF);
            @intToPtr(*u8, data_addr + idx + 3).* = 255;
        }
        rowIdx += pitch;
    }
}

fn fillBmp(bmp: *Bitmap, colour: Colour) void {
    if (bmp.data == null) {
        return;
    }

    const data_addr = @ptrToInt(bmp.data);
    const pitch = @intCast(usize, bmp.width * bmp.bytes_per_pixel);

    var rowIdx: usize = 0;
    var y: usize = 0;
    while (y < bmp.height) : (y += 1) {
        var x: usize = 0;
        while (x < bmp.width) : (x += 1) {
            const idx = rowIdx + x * @intCast(usize, bmp.bytes_per_pixel);
            @intToPtr(*u8, data_addr + idx + 0).* = colour.r;
            @intToPtr(*u8, data_addr + idx + 1).* = colour.g;
            @intToPtr(*u8, data_addr + idx + 2).* = colour.b;
            @intToPtr(*u8, data_addr + idx + 3).* = colour.a;
        }
        rowIdx += pitch;
    }
}

pub fn win32PresentBufferToWindow(bmp: *Bitmap, dc: HDC, dst_size: Size) void {
    // Copy bitmap data to the screen
    if (bmp.data != null) {
        _ = StretchDIBits(dc, 0, 0, dst_size.w, dst_size.h, // Dest
            0, 0, bmp.width, bmp.height, // Source
            bmp.data.?, @ptrCast(*VOID, &bmp.info), DIB_RGB_COLORS, SRCCOPY);
    }
}
