const std = @import("std");
const k32 = std.os.windows.kernel32;
usingnamespace std.os.windows;
usingnamespace std.os.windows.user32;
usingnamespace @import("win32_extension.zig");

var running = false;

const resolutionWidth = 960;
const resolutionHeight = 540;

var bmpData: ?*VOID = null;
var bmpWidth: i32 = resolutionWidth;
var bmpHeight: i32 = resolutionHeight;
var bmpInfo = BITMAPINFO{
    .bmiHeader = BITMAPINFOHEADER{
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
    // Update bitmap info
    bmpWidth = w;
    bmpHeight = h;
    bmpInfo.bmiHeader = BITMAPINFOHEADER{
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

    // Free existing bitmap data
    if (bmpData != null) {
        _ = VirtualFree(bmpData, 0, MEM_RELEASE);
        bmpData = null;
    }

    // Alloc new bitmap data
    const bytesPerPixel = 4;
    const signedSize = bytesPerPixel * bmpWidth * bmpHeight;
    if (signedSize > 0) {
        const size = @intCast(usize, signedSize);
        bmpData = VirtualAlloc(null, size, MEM_COMMIT, PAGE_READWRITE) catch null;
    }

    // Write some nonsense to the new bitmap data
    fillBmp(0, 0, 0);
}

fn renderWeirdGradient(tick: usize) void {
    if (bmpData == null) {
        return;
    }

    const bytesPerPixel = 4;
    const bmpDataAddr = @ptrToInt(bmpData);
    const pitch = @intCast(usize, bmpWidth * bytesPerPixel);

    var rowIdx: usize = 0;
    var y: usize = 0;
    while (y < bmpHeight) : (y += 1) {
        var x: usize = 0;
        while (x < bmpWidth) : (x += 1) {
            const idx = rowIdx + x * bytesPerPixel;
            @intToPtr(*u8, bmpDataAddr + idx + 0).* = 0;
            @intToPtr(*u8, bmpDataAddr + idx + 1).* = 0;
            @intToPtr(*u8, bmpDataAddr + idx + 2).* = @intCast(u8, (tick +% (x ^ y)) & 0xFF);
            @intToPtr(*u8, bmpDataAddr + idx + 3).* = 255;
        }
        rowIdx += pitch;
    }
}

fn fillBmp(r: u8, g: u8, b: u8) void {
    if (bmpData == null) {
        return;
    }

    const bytesPerPixel = 4;
    const bmpDataAddr = @ptrToInt(bmpData);
    const pitch = @intCast(usize, bmpWidth * bytesPerPixel);

    var rowIdx: usize = 0;
    var y: usize = 0;
    while (y < bmpHeight) : (y += 1) {
        var x: usize = 0;
        while (x < bmpWidth) : (x += 1) {
            const idx = rowIdx + x * bytesPerPixel;
            @intToPtr(*u8, bmpDataAddr + idx + 0).* = b;
            @intToPtr(*u8, bmpDataAddr + idx + 1).* = g;
            @intToPtr(*u8, bmpDataAddr + idx + 2).* = r;
            @intToPtr(*u8, bmpDataAddr + idx + 3).* = 255;
        }
        rowIdx += pitch;
    }
}

fn win32UpdateWindow(dc: HDC, x: i32, y: i32, w: i32, h: i32) void {
    // Copy bitmap data to the screen
    if (bmpData != null) {
        _ = StretchDIBits(dc, 0, 0, w, h, // Dest
            0, 0, bmpWidth, bmpHeight, // Source
            bmpData.?, @ptrCast(*VOID, &bmpInfo), DIB_RGB_COLORS, SRCCOPY);
    }
}

fn win32WndProc(wnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.Stdcall) LRESULT {
    var result: LRESULT = null;

    switch (msg) {
        WM_PAINT => {
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
            var clientRect: RECT = undefined;
            _ = GetClientRect(wnd, &clientRect);
            const width = clientRect.right - clientRect.left;
            const height = clientRect.bottom - clientRect.top;
            win32ResizeDIBSection(width, height);
        },
        WM_DESTROY => {
            running = false;
        },
        WM_CLOSE => {
            running = false;
        },
        WM_QUIT => {
            running = false;
        },
        WM_ACTIVATEAPP => {},
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

pub fn wWinMain(instance: HINSTANCE, prevInstance: ?HINSTANCE, param: LPWSTR, cmdShow: INT) INT {
    const wnd_class_info = WNDCLASSEXA{
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

    const optional_wnd = CreateWindowExA(
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

    if (optional_wnd == null) {
        std.debug.warn("Failed to create window\n", .{});
        win32ErrorExit();
    }

    const wnd = optional_wnd.?;

    running = true;
    var tick: usize = 0;
    while (running) {
        var msg: MSG = undefined;
        while (PeekMessageA(&msg, wnd, 0, 0, PM_REMOVE)) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
        }

        // Update bitmap
        renderWeirdGradient(tick);
        tick +%= 1;

        // Render bitmap to screen
        if (GetDC(wnd)) |dc| {
            var clientRect: RECT = undefined;
            _ = GetClientRect(wnd, &clientRect);
            const wndWidth = clientRect.right - clientRect.left;
            const wndHeight = clientRect.bottom - clientRect.top;
            win32UpdateWindow(dc, 0, 0, wndWidth, wndHeight);
            _ = ReleaseDC(wnd, dc);
        }
    }

    return 0;
}
