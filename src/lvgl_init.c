#include <lvgl.h>

static lv_disp_drv_t disp_drv;
static lv_indev_drv_t indev_drv;

static uint32_t frame_count;

static void flush_cb(lv_disp_drv_t*, const lv_area_t*, lv_color_t*) {
    ++frame_count;
    lv_disp_flush_ready(&disp_drv);
}

uint32_t lvgl_frame_count(void) {
    return frame_count;
}

static void init_display(uint32_t w, uint32_t h, uint32_t fb_adr) {
    static lv_disp_draw_buf_t disp_buffer;
    lv_disp_draw_buf_init(&disp_buffer, (void*)fb_adr, NULL, w * h);
    lv_disp_drv_init(&disp_drv);
    disp_drv.draw_buf = &disp_buffer;
    disp_drv.flush_cb = flush_cb;
    disp_drv.hor_res = w;
    disp_drv.ver_res = h;
    disp_drv.direct_mode = 1;
    lv_disp_t* p_disp = lv_disp_drv_register(&disp_drv);
    assert(p_disp);
}

struct {
    int32_t x;
    int32_t y;
    bool is_pressed;
} input_device_data;

static void input_cb(lv_indev_drv_t*, lv_indev_data_t* data) {
    data->point.x = input_device_data.x;
    data->point.y = input_device_data.y;
    data->state = input_device_data.is_pressed ? LV_INDEV_STATE_PRESSED : LV_INDEV_STATE_RELEASED;
}

static void init_input(void) {
    lv_indev_drv_init(&indev_drv);
    indev_drv.type = LV_INDEV_TYPE_POINTER;
    indev_drv.read_cb = input_cb;
    lv_indev_t* p_indev = lv_indev_drv_register(&indev_drv);
    assert(p_indev);
}

void init_lvgl(uint32_t w, uint32_t h, uint32_t fb_adr) {
    lv_init();
    init_display(w, h, fb_adr);
    init_input();
}
