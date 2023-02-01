#include <lvgl.h>

#undef LV_USE_DEMO_WIDGETS
#define LV_USE_DEMO_WIDGETS 1
#include "../demos/widgets/lv_demo_widgets.c"

void create_lvgl_gui(void) {
    lv_demo_widgets();
}
