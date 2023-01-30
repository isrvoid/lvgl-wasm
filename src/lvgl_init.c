#include <lvgl.h>

static lv_disp_draw_buf_t disp_buffer;
static lv_disp_drv_t disp_driver;
static lv_disp_t* p_disp;

static uint32_t frame_count;

static void flush_cb(lv_disp_drv_t*, const lv_area_t*, lv_color_t*) {
    ++frame_count;
    lv_disp_flush_ready(&disp_driver);
}

uint32_t lvgl_frame_count(void) {
    return frame_count;
}

void init_lvgl(uint32_t w, uint32_t h, uint32_t fb_adr) {
    lv_init();
    lv_disp_draw_buf_init(&disp_buffer, (void*) fb_adr, NULL, w * h);
    lv_disp_drv_init(&disp_driver);
    disp_driver.hor_res = w;
    disp_driver.ver_res = h;
    disp_driver.draw_buf = &disp_buffer;
    disp_driver.direct_mode = 1;
    disp_driver.flush_cb = flush_cb;
    p_disp = lv_disp_drv_register(&disp_driver);
}
