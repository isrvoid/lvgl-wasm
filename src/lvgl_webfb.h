#pragma once

#include <stdbool.h>
#include <stdint.h>

void init_lvgl(void* fb, uint32_t w, uint32_t h);
uint32_t lvgl_change_index(void);
void create_lvgl_gui(void); // implemented by the project

typedef struct {
    int32_t x;
    int32_t y;
    int32_t encoder_pos;
    bool is_pressed;
    bool is_encoder_pressed;
} input_device_data_t;

extern input_device_data_t input_device_data;

// LVGL declarations
void lv_tick_inc(uint32_t);
uint32_t lv_timer_handler(void);
