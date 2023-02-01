const img = @import("init_image");

// .png images were copied from lvgl/demos/widgets/assets/
export const img_lvgl_logo = img.init(@embedFile("lvgl_logo.raw"));
export const img_demo_widgets_avatar = img.init(@embedFile("avatar.raw"));
export const img_clothes = img.init(@embedFile("clothes.raw"));
