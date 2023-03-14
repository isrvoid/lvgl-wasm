#include "lvgl_webfb.h"
#include "../lvgl/lvgl.h"

static lv_disp_drv_t disp_drv;
static lv_indev_t* encoder_indev;
static uint32_t change_index;

static void flush_cb(lv_disp_drv_t*, const lv_area_t*, lv_color_t*) {
    ++change_index;
    lv_disp_flush_ready(&disp_drv);
}

uint32_t lvgl_change_index(void) {
    return change_index;
}

static void init_display(void* fb, uint32_t w, uint32_t h) {
    static lv_disp_draw_buf_t disp_buffer;
    lv_disp_draw_buf_init(&disp_buffer, fb, NULL, w * h);
    lv_disp_drv_init(&disp_drv);
    disp_drv.draw_buf = &disp_buffer;
    disp_drv.flush_cb = flush_cb;
    disp_drv.hor_res = w;
    disp_drv.ver_res = h;
    disp_drv.direct_mode = 1;
    lv_disp_t* p_disp = lv_disp_drv_register(&disp_drv);
    assert(p_disp);
}

input_device_data_t input_device_data;

static void pointer_device_cb(lv_indev_drv_t*, lv_indev_data_t* data) {
    data->point.x = input_device_data.x;
    data->point.y = input_device_data.y;
    data->state = input_device_data.is_pressed ? LV_INDEV_STATE_PRESSED : LV_INDEV_STATE_RELEASED;
}

static void rotary_encoder_cb(lv_indev_drv_t*, lv_indev_data_t* data) {
    static int32_t prev_pos;
    const int32_t pos = input_device_data.encoder_pos;
    data->enc_diff = (int16_t)(pos - prev_pos);
    prev_pos = pos;
    data->state = input_device_data.is_encoder_pressed ? LV_INDEV_STATE_PRESSED : LV_INDEV_STATE_RELEASED;
}

static void init_pointer_device(void) {
    static lv_indev_drv_t drv;
    lv_indev_drv_init(&drv);
    drv.type = LV_INDEV_TYPE_POINTER;
    drv.read_cb = pointer_device_cb;
    lv_indev_t* indev = lv_indev_drv_register(&drv);
    assert(indev);
}

static void init_rotary_encoder(void) {
    static lv_indev_drv_t drv;
    lv_indev_drv_init(&drv);
    drv.type = LV_INDEV_TYPE_ENCODER;
    drv.read_cb = rotary_encoder_cb;
    encoder_indev = lv_indev_drv_register(&drv);
    assert(encoder_indev);
}

static void init_input(void) {
    init_rotary_encoder();
    init_pointer_device();
}

void init_lvgl(void* fb, uint32_t w, uint32_t h) {
    lv_init();
    init_display(fb, w, h);
    init_input();
}

// int return to match the default signature and avoid 'wasm validation error',
// in case the project calls it without prior declaration
int set_rotary_encoder_group(lv_group_t* group) {
    assert(encoder_indev);
    lv_indev_set_group(encoder_indev, group);
    return 0;
}
