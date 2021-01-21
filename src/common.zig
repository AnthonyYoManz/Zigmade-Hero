pub const Size = struct {
    w: i32,
    h: i32,

    pub fn init(w: i32, h: i32) Size {
        return Size{
            .w = w,
            .h = h,
        };
    }
};
