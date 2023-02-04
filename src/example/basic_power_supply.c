#include "basic_power_supply.h"
#include "../lvgl_input.h"

typedef struct {
    uint8_t num_digits, separator_pos;
} digit_format_t;

typedef struct {
    lv_obj_t* label;
    digit_format_t fmt;
    char text[8];
} reading_t;

typedef struct {
    lv_obj_t* p;
    uint8_t col, row;
} grid_opt_t;

typedef struct {
    int min, max;
    digit_format_t fmt;
    grid_opt_t grid;
    const char* title;
} spinbox_opt_t;

static lv_obj_t* voltage_target, * current_target;
static reading_t voltage_reading, current_reading;
static lv_obj_t* sw_output, * sw_fuse;

static void lv_spinbox_increment_event_cb(lv_event_t* e) {
    const lv_event_code_t code = lv_event_get_code(e);
    if(code == LV_EVENT_SHORT_CLICKED || code == LV_EVENT_LONG_PRESSED_REPEAT) {
        lv_obj_t* spinbox = (lv_obj_t*)lv_event_get_user_data(e);
        lv_spinbox_increment(spinbox);
    }
}

static void lv_spinbox_decrement_event_cb(lv_event_t* e) {
    const lv_event_code_t code = lv_event_get_code(e);
    if(code == LV_EVENT_SHORT_CLICKED || code == LV_EVENT_LONG_PRESSED_REPEAT) {
        lv_obj_t* spinbox = (lv_obj_t*)lv_event_get_user_data(e);
        lv_spinbox_decrement(spinbox);
    }
}

static void add_title_label(lv_obj_t* obj, const char* text) {
    lv_obj_t* const label = lv_label_create(lv_scr_act());
    lv_obj_set_style_text_font(label, &lv_font_montserrat_18, 0);
    lv_obj_align_to(label, obj, LV_ALIGN_OUT_TOP_LEFT, 0, -15);
    const lv_color_t light_grey = lv_color_make(160, 160, 160);
    lv_obj_set_style_text_color(label, light_grey, 0);
    lv_label_set_text_static(label, text);
}

#define VALUE_TILE_WIDTH 125

static lv_obj_t* add_spinbox(spinbox_opt_t opt) {
    lv_obj_t* const spinbox = lv_spinbox_create(opt.grid.p);
    lv_obj_set_style_text_font(spinbox, &lv_font_montserrat_32, 0);
    lv_obj_set_width(spinbox, VALUE_TILE_WIDTH);
    lv_obj_set_grid_cell(spinbox, LV_GRID_ALIGN_CENTER, opt.grid.col, 1, LV_GRID_ALIGN_CENTER, opt.grid.row, 1);
    lv_spinbox_set_range(spinbox, opt.min, opt.max);
    lv_spinbox_set_digit_format(spinbox, opt.fmt.num_digits, opt.fmt.separator_pos);
    const uint8_t cursor_at_first_decimal = opt.fmt.num_digits - 1 - opt.fmt.separator_pos;
    lv_spinbox_set_cursor_pos(spinbox, cursor_at_first_decimal);
    add_title_label(spinbox, opt.title);

    const lv_coord_t h = lv_obj_get_height(spinbox);
    lv_obj_t* const minus_btn = lv_btn_create(lv_scr_act());
    lv_obj_set_size(minus_btn, h, h);
    lv_obj_align_to(minus_btn, spinbox, LV_ALIGN_OUT_LEFT_MID, -20, 0);
    lv_obj_set_style_bg_img_src(minus_btn, LV_SYMBOL_MINUS, 0);
    lv_obj_add_event_cb(minus_btn, lv_spinbox_decrement_event_cb, LV_EVENT_ALL, spinbox);

    lv_obj_t* const plus_btn = lv_btn_create(lv_scr_act());
    lv_obj_set_size(plus_btn, h, h);
    lv_obj_align_to(plus_btn, spinbox, LV_ALIGN_OUT_RIGHT_MID, 20, 0);
    lv_obj_set_style_bg_img_src(plus_btn, LV_SYMBOL_PLUS, 0);
    lv_obj_add_event_cb(plus_btn, lv_spinbox_increment_event_cb, LV_EVENT_ALL, spinbox);

    lv_group_swap_obj(spinbox, minus_btn);
    return spinbox;
}

static void reading_set_nan(reading_t* a) {
    strcpy(a->text, "- - - -");
    lv_label_set_text_static(a->label, a->text);
}

static void add_reading(digit_format_t fmt, grid_opt_t grid, const char* title, reading_t* res) {
    res->fmt = fmt;
    lv_obj_t* const tile = lv_obj_create(grid.p);
    lv_obj_set_style_pad_all(tile, 11, 0);
    lv_obj_set_size(tile, LV_SIZE_CONTENT, LV_SIZE_CONTENT);
    lv_obj_set_width(tile, VALUE_TILE_WIDTH);
    lv_obj_set_grid_cell(tile, LV_GRID_ALIGN_CENTER, grid.col, 1, LV_GRID_ALIGN_CENTER, grid.row, 1);
    lv_obj_t* const label = lv_label_create(tile);
    res->label = label;
    lv_obj_set_style_text_font(label, &lv_font_montserrat_32, 0);
    reading_set_nan(res);
    add_title_label(tile, title);
}

static lv_obj_t* add_switch(grid_opt_t grid, const char* title) {
    lv_obj_t* const res = lv_switch_create(grid.p);
    lv_obj_set_grid_cell(res, LV_GRID_ALIGN_CENTER, grid.col, 1, LV_GRID_ALIGN_CENTER, grid.row, 1);
    add_title_label(res, title);
    return res;
}

static lv_obj_t* create_grid(void) {
    static lv_coord_t columns[] = { LV_GRID_FR(1), LV_GRID_FR(1), LV_GRID_TEMPLATE_LAST };
    static lv_coord_t rows[] = { LV_GRID_FR(38), LV_GRID_FR(38), LV_GRID_FR(24), LV_GRID_TEMPLATE_LAST };
    lv_obj_t* const grid = lv_obj_create(lv_scr_act());
    lv_obj_set_size(grid, LV_HOR_RES, LV_VER_RES);
    lv_obj_center(grid);
    lv_obj_set_grid_dsc_array(grid, columns, rows);
    return grid;
}

void create_basic_power_supply(void) {
    const digit_format_t voltage_fmt = { 4, 2 }, current_fmt = { 4, 1 };
    lv_obj_t* const grid = create_grid();
    lv_group_t* const group = lv_group_create();
    lv_group_set_default(group);
    voltage_target = add_spinbox((spinbox_opt_t){ .min = 0, .max = 3200, .fmt = voltage_fmt,
            .grid = { grid, 0, 0 }, .title = "set voltage" });
    current_target = add_spinbox((spinbox_opt_t){ .min = 1, .max = 5000, .fmt = current_fmt,
            .grid = { grid, 0, 1 }, .title = "set max current" });
    add_reading(voltage_fmt, (grid_opt_t){ grid, 1, 0 }, "voltage", &voltage_reading);
    add_reading(current_fmt, (grid_opt_t){ grid, 1, 1 }, "current", &current_reading);
    sw_fuse = add_switch((grid_opt_t){ grid, 0, 2 }, "fuse");
    sw_output = add_switch((grid_opt_t){ grid, 1, 2 }, "output");
    set_rotary_encoder_group(group);
}
