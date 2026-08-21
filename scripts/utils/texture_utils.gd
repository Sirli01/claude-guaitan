class_name TextureUtils
## 纹理生成工具 — 提供圆形/锥形灯光纹理的共享生成方法
## 避免在 level_base.gd、npc_base.gd 等多处重复实现

## 生成圆形渐变纹理（用于 PointLight2D）
## [param size] 纹理尺寸（像素）
## [return] 圆形渐变 ImageTexture
static func make_circle_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for x in size:
		for y in size:
			var dist := Vector2(x - half, y - half).length() / half
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

## 生成锥形渐变纹理（用于 NPC 手机灯光等方向性光源）
## [param size] 纹理尺寸（像素）
## [param angle_deg] 锥形角度（度）
## [return] 锥形渐变 ImageTexture
static func make_cone_texture(size: int, angle_deg: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	var angle_rad := deg_to_rad(angle_deg / 2.0)
	for x in size:
		for y in size:
			var dx := x - half
			var dy := y - half
			var dist := Vector2(dx, dy).length() / half
			var pixel_angle := atan2(abs(dx), -dy)
			var in_cone := pixel_angle < angle_rad and dy < 0
			var falloff := clampf(1.0 - dist, 0.0, 1.0)
			var cone_falloff := clampf(1.0 - pixel_angle / angle_rad, 0.0, 1.0) if in_cone else 0.0
			var alpha := falloff * cone_falloff * 0.85
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
