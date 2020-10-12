const std = @import("std");
usingnamespace std.os.windows;
usingnamespace std.os.windows.user32;
const k32 = std.os.windows.kernel32;

// TODO: GetMessageA shouldn't return bool, it should return BOOL

// TODO: Add these to std.os.windows.bits
const VOID = c_void;

// TODO: Add these to std.os.windows.kernel32
pub extern "kernel32" fn GetCommandLineW() callconv(.Stdcall) LPWSTR;

// TODO: Add these to std.os.windows.user32
extern "user32" fn BeginPaint(hWnd: HWND, lpPaint: LPPAINTSTRUCT) callconv(.Stdcall) HDC;
extern "user32" fn EndPaint(hWnd: HWND, lpPaint: LPPAINTSTRUCT) callconv(.Stdcall) BOOL;
extern "user32" fn GetClientRect(hWnd: HWND, lpRect: LPRECT) callconv(.Stdcall) BOOL;

const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]BYTE,
};

const LPPAINTSTRUCT = *PAINTSTRUCT;
const LPRECT = *RECT;

const WM_ACTIVATEAPP = 0x001c;
const WS_VISIBLE = 0x10000000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const CW_USEDEFAULT = -2147483648;


// TODO: Add these to std.os.windows.gdi32
extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.Stdcall) HDC;
extern "gdi32" fn DeleteObject(ho: HGDIOBJ) callconv(.Stdcall) BOOL;
extern "gdi32" fn CreateDIBSection(
    hdc: HDC,
    pbmi: *BITMAPINFO,
    iUsage: UINT,
    ppvBits: *?*VOID,
    hSection: ?HANDLE,
    offset: DWORD
) callconv(.Stdcall) ?HBITMAP;

extern "gdi32" fn StretchDIBits(
    hdc: HDC,
    xDest: c_int,
    yDest: c_int,
    DestWidth: c_int,
    DestHeight: c_int,
    xSrc: c_int,
    ySrc: c_int,
    SrcWidth: c_int,
    SrcHeight: c_int,
    lpBits: *VOID,
    lpbmi: *VOID,
    iUsage: UINT,
    rop: DWORD
) callconv(.Stdcall) c_int;

extern "gdi32" fn PatBlt(
    hdc: HDC,
    x: c_int,
    y: c_int,
    w: c_int,
    h: c_int,
    rop: DWORD
) callconv(.Stdcall) BOOL;

const BITMAPINFOHEADER = extern struct {
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

const RGBQUAD = extern struct {
    rgbBlue: BYTE,
    rgbGreen: BYTE,
    rgbRed: BYTE,
    rgbReserved: BYTE,
};

const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

const HGDIOBJ = HANDLE;
const HBITMAP = HANDLE;
const PBITMAPINFOHEADER = *BITMAPINFOHEADER;
const PBITMAPINFO = *BITMAPINFO;
const LPBITMAPINFO = *BITMAPINFO;

const DIB_PAL_COLORS = 1;
const DIB_RGB_COLORS = 0;
const BI_RGB = 0;
const BI_RLE8 = 1;
const BI_RLE4 = 2;
const BI_BITFIELDS = 3;
const BI_JPEG = 4;
const BI_PNG = 5;

const BLACKNESS = 0x00000042;
const CAPTUREBLT = 0x40000000;
const DSTINVERT = 0x00550009;
const MERGECOPY = 0x00C000CA;
const MERGEPAINT = 0x00BB0226;
const NOMIRRORBITMAP = 0x80000000;
const NOTSRCCOPY = 0x00330008;
const NOTSRCERASE = 0x001100A6;
const PATCOPY = 0x00F00021;
const PATINVERT = 0x005A0049;
const PATPAINT = 0x00FB0A09;
const SRCAND = 0x008800C6;
const SRCCOPY = 0x00CC0020;
const SRCERASE = 0x00440328;
const SRCINVERT = 0x00660046;
const SRCPAINT = 0x00EE0086;
const WHITENESS = 0x00FF0062;

// Actual code from now on :)
var running = false;

const resolutionWidth = 960;
const resolutionHeight = 540;

var bmpData: ?*VOID = null;
var bmpWidth: i32 = resolutionWidth;
var bmpHeight: i32 = resolutionHeight;
var bmpInfo = BITMAPINFO {
    .bmiHeader = BITMAPINFOHEADER {
        .biSize = @sizeOf(BITMAPINFOHEADER),
        .biWidth = resolutionWidth,
        .biHeight = resolutionHeight,
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
};

fn win32ResizeDIBSection(w: i32, h: i32) void {
    bmpWidth = w;
    bmpHeight = h;
    bmpInfo.bmiHeader = BITMAPINFOHEADER {
        .biSize = @sizeOf(BITMAPINFOHEADER),
        .biWidth = bmpWidth,
        .biHeight = -bmpHeight,
        .biPlanes = 1,
        .biBitCount = 32,
        .biCompression = BI_RGB,
        .biSizeImage = 0,
        .biXPelsPerMeter = 0,
        .biYPelsPerMeter = 0,
        .biClrUsed = 0,
        .biClrImportant = 0,
    };

    if (bmpData != null) {
        std.debug.warn("\tFreeing bitmap\n", .{});
        _ = VirtualFree(bmpData, 0, MEM_RELEASE);
        bmpData = null;
    }

    std.debug.warn("\tAllocating bitmap\n", .{});
    const bytesPerPixel = 4;
    const signedSize = bytesPerPixel * bmpWidth * bmpHeight;
    if (signedSize > 0) {
        const size = @intCast(usize, signedSize);
        bmpData = VirtualAlloc(null, size, MEM_COMMIT, PAGE_READWRITE) catch null;
    }

    if (bmpData != null) {
        const bmpDataAddr = @ptrToInt(bmpData);
        const pitch = @intCast(usize, bmpWidth * bytesPerPixel);
        var y: usize = 0;
        while (y < bmpHeight) : (y += 1) {
            var rowIdx = y * pitch;
            var x: usize = 0;
            while (x < bmpWidth) : (x += 1) {
                const idx = rowIdx + x * bytesPerPixel;
                const bluePtr = @intToPtr(*u8, bmpDataAddr + idx + 0);
                const greenPtr = @intToPtr(*u8, bmpDataAddr + idx + 1);
                const redPtr = @intToPtr(*u8, bmpDataAddr + idx + 2);

                redPtr.* = 164;
                greenPtr.* = 48;
                bluePtr.* = 233;
            }
        }
    }
}

fn win32UpdateWindow(dc: HDC, x: i32, y: i32, w: i32, h: i32) void {
    if (bmpData != null) {
        std.debug.warn("\tBlitting bitmap\n", .{});
        _ = StretchDIBits(
            dc,
            0, 0, w, h, // Dest
            0, 0, bmpWidth, bmpHeight, // Source
            bmpData.?,
            @ptrCast(*VOID, &bmpInfo),
            DIB_RGB_COLORS,
            SRCCOPY
        );
    }
}

fn win32WndProc(wnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.Stdcall) LRESULT {
    var result: LRESULT = null;

    switch (msg) {
        WM_PAINT => {
            std.debug.warn("WM_PAINT\n", .{});
            var paint: PAINTSTRUCT = undefined;
            const dc = BeginPaint(wnd, &paint);

            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const width = paint.rcPaint.right - x;
            const height = paint.rcPaint.bottom - y;

            _ = PatBlt(dc, x, y, width, height, BLACKNESS);
            win32UpdateWindow(dc, x, y, width, height);

            _ = EndPaint(wnd, &paint);
        },
        WM_SIZE => {
            std.debug.warn("WM_SIZE\n", .{});

            var clientRect: RECT = undefined;
            _ = GetClientRect(wnd, &clientRect);
            const width = clientRect.right - clientRect.left;
            const height = clientRect.bottom - clientRect.top;
            win32ResizeDIBSection(width, height);
        },
        WM_DESTROY => {
            std.debug.warn("WM_DESTROY\n", .{});
            running = false;
        },
        WM_CLOSE => {
            std.debug.warn("WM_CLOSE\n", .{});
            running = false;
        },
        WM_ACTIVATEAPP => {
            std.debug.warn("WM_ACTIVATEAPP\n", .{});
        },
        else => {
            result = DefWindowProcA(wnd, msg, wParam, lParam);
        },
    }

    return result;
}

fn win32ErrorExit() void {
    const err = k32.GetLastError();
    var buf16: [256]u16 = undefined;
    var buf8: [256]u8 = undefined;

    const len = k32.FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, null, err, (1 << 10) | 0, &buf16, buf16.len / @sizeOf(TCHAR), null);
    _ = std.unicode.utf16leToUtf8(&buf8, buf16[0..len]) catch unreachable;

    std.debug.warn("\t{}\n", .{buf8[0..len]});
    k32.ExitProcess(@bitCast(u16, err));
}

pub fn main() !void {
    const hInstance = std.os.windows.kernel32.GetModuleHandleA(null);
    const lpCmdLine = GetCommandLineW();

    // There's no (documented) way to get the nCmdShow parameter, so we're
    // using this fairly standard default.
    const nCmdShow = std.os.windows.user32.SW_SHOW;

    _ = wWinMain(
        @ptrCast(HINSTANCE, hInstance),
        null,
        lpCmdLine,
        nCmdShow
    );
}

fn wWinMain(instance: HINSTANCE, prevInstance: ?HINSTANCE, param: LPWSTR, cmdShow: INT) INT {
    const wnd_class_info = WNDCLASSEXA {
        .cbSize = @sizeOf(WNDCLASSEXA),
        .style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = win32WndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "Zigmade Hero",
        .hIconSm = null,
    };

    const wnd_class = RegisterClassExA(&wnd_class_info);
    if (wnd_class == 0) {
        std.debug.warn("Failed to register window class\n", .{});
        win32ErrorExit();
    }

    const wnd = CreateWindowExA(
        0,
        "Zigmade Hero",
        "Zigmade Hero",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        resolutionWidth,
        resolutionHeight,
        null,
        null,
        instance,
        null,
    );

    if (wnd == null) {
        std.debug.warn("Failed to create window\n", .{});
        win32ErrorExit();
    }

    running = true;
    while (running) {
        var msg: MSG = undefined;
        const msgResult = GetMessageA(&msg, wnd, 0, 0);
        if (msgResult) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
        } else {
            running = false;
        }
    }

    return 0;
}
