const std = @import("std");
usingnamespace std.os.windows;
usingnamespace std.os.windows.gdi32;
usingnamespace @import("bits.zig");

pub extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.Stdcall) HDC;
pub extern "gdi32" fn DeleteObject(ho: HGDIOBJ) callconv(.Stdcall) BOOL;
pub extern "gdi32" fn CreateDIBSection(hdc: HDC, pbmi: *BITMAPINFO, iUsage: UINT, ppvBits: *?*VOID, hSection: ?HANDLE, offset: DWORD) callconv(.Stdcall) ?HBITMAP;
pub extern "gdi32" fn StretchDIBits(hdc: HDC, xDest: c_int, yDest: c_int, DestWidth: c_int, DestHeight: c_int, xSrc: c_int, ySrc: c_int, SrcWidth: c_int, SrcHeight: c_int, lpBits: *VOID, lpbmi: *VOID, iUsage: UINT, rop: DWORD) callconv(.Stdcall) c_int;
pub extern "gdi32" fn PatBlt(hdc: HDC, x: c_int, y: c_int, w: c_int, h: c_int, rop: DWORD) callconv(.Stdcall) BOOL;

pub const BITMAPINFOHEADER = extern struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD,
};

pub const RGBQUAD = extern struct {
    rgbBlue: BYTE,
    rgbGreen: BYTE,
    rgbRed: BYTE,
    rgbReserved: BYTE,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

pub const HGDIOBJ = HANDLE;
pub const HBITMAP = HANDLE;
pub const PBITMAPINFOHEADER = *BITMAPINFOHEADER;
pub const PBITMAPINFO = *BITMAPINFO;
pub const LPBITMAPINFO = *BITMAPINFO;

pub const DIB_PAL_COLORS = 1;
pub const DIB_RGB_COLORS = 0;
pub const BI_RGB = 0;
pub const BI_RLE8 = 1;
pub const BI_RLE4 = 2;
pub const BI_BITFIELDS = 3;
pub const BI_JPEG = 4;
pub const BI_PNG = 5;

pub const BLACKNESS = 0x00000042;
pub const CAPTUREBLT = 0x40000000;
pub const DSTINVERT = 0x00550009;
pub const MERGECOPY = 0x00C000CA;
pub const MERGEPAINT = 0x00BB0226;
pub const NOMIRRORBITMAP = 0x80000000;
pub const NOTSRCCOPY = 0x00330008;
pub const NOTSRCERASE = 0x001100A6;
pub const PATCOPY = 0x00F00021;
pub const PATINVERT = 0x005A0049;
pub const PATPAINT = 0x00FB0A09;
pub const SRCAND = 0x008800C6;
pub const SRCCOPY = 0x00CC0020;
pub const SRCERASE = 0x00440328;
pub const SRCINVERT = 0x00660046;
pub const SRCPAINT = 0x00EE0086;
pub const WHITENESS = 0x00FF0062;
