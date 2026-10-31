extends Node2D
## Escenario horizontal del refugio. Las coordenadas están diseñadas sobre 1280x720
## y se escalan uniformemente para conservar la proporción en móvil y escritorio.

signal interaction_requested(kind: String, destination: Vector2)

const BASE_SIZE := Vector2(1280.0, 720.0)
const GREEN_FIELD_LAYERS := [
	"res://assets/sprites/environments/green_field_fkgcluster/PNG/00_sky.png",
	"res://assets/sprites/environments/green_field_fkgcluster/PNG/01_back.png",
	"res://assets/sprites/environments/green_field_fkgcluster/PNG/02_cloud1.png",
	"res://assets/sprites/environments/green_field_fkgcluster/PNG/03_cloud2.png",
	"res://assets/sprites/environments/green_field_fkgcluster/PNG/04_mid1.png",
	"res://assets/sprites/environments/green_field_fkgcluster/PNG/05_mid2.png",
	"res://assets/sprites/environments/green_field_fkgcluster/PNG/06_front.png",
]
const HOUSE_WALL := "res://assets/sprites/environments/medieval_village_intc2748/Medieval House/House_Wall.png"
const HOUSE_ROOF_LEFT := "res://assets/sprites/environments/medieval_village_intc2748/Medieval House/Roof_1.png"
const HOUSE_ROOF_RIGHT := "res://assets/sprites/environments/medieval_village_intc2748/Medieval House/Roof_2.png"
const HOUSE_DOOR := "res://assets/sprites/environments/medieval_village_intc2748/Medieval House/Wooden_Door.png"
const HOUSE_WINDOW := "res://assets/sprites/environments/medieval_village_intc2748/Medieval House/Window_1.png"
const CHEST_SHEET := "res://assets/sprites/props/animated_chests_admurin/Chests.png"
const BLACKSMITH_SHEET := "res://assets/sprites/characters/npcs/blacksmith_mattz/BLACKSMITH.png"
const GOBLIN_BLINK_SHEET := "res://assets/sprites/enemies/craftpix-net-228980-free-top-down-goblin-char__Front - Idle blinking__eafdf012a8f7.png"
const WARRIOR_IDLE_FRAMES := [
	"res://assets/sprites/characters/CartoonWarrior__IdleSword_01__9c2e6a25dbf0.png",
	"res://assets/sprites/characters/CartoonWarrior__IdleSword_02__08c74be03e78.png",
	"res://assets/sprites/characters/CartoonWarrior__IdleSword_03__724cb26754ed.png",
	"res://assets/sprites/characters/CartoonWarrior__IdleSword_04__6392e1b3f1f4.png",
]
const GROUND_LINE := 600.0
const INTERIOR_GROUND_LINE := 515.0
const HERO_RENDER_HEIGHT := 116.0
const ACTOR_RENDER_HEIGHT := 108.0


var world_root: Node2D
var hero: AnimatedSprite2D
var inside_house := false
var base_scale := 1.0
var active_hero_id := "guardiana"
var active_hero_texture: Texture2D
var movement_tween: Tween
var hero_bob_tween: Tween
var interaction_bounds: Array[Rect2] = []
var was_moving_with_keyboard := false


func _ready() -> void:
	world_root = Node2D.new()
	world_root.name = "PlatformerWorld"
	add_child(world_root)
	_build_world()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)


func _fit_to_viewport() -> void:
	if not is_instance_valid(world_root):
		return
	var viewport_size := get_viewport_rect().size
	base_scale = minf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	world_root.scale = Vector2.ONE * base_scale
	world_root.position = (viewport_size - BASE_SIZE * base_scale) * 0.5


func set_hero(hero_id: String) -> void:
	active_hero_id = hero_id
	if is_instance_valid(hero):
		hero.queue_free()
	if is_instance_valid(hero_bob_tween):
		hero_bob_tween.kill()
	hero = AnimatedSprite2D.new()
	hero.name = "PlayerHero"
	hero.sprite_frames = _make_hero_frames(hero_id, active_hero_texture)
	hero.animation = "idle"
	hero.scale = Vector2.ONE * HERO_RENDER_HEIGHT / maxf(1.0, hero.sprite_frames.get_frame_texture("idle", 0).get_size().y)
	hero.position = Vector2(565, GROUND_LINE - HERO_RENDER_HEIGHT * 0.5)
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(hero)
	hero.play("idle")
	_animate_hero_motion(false)
	# El héroe se dibuja delante de objetos y fondo, pero bajo los rótulos interactivos.
	hero.z_index = 20


func move_hero_to(destination: Vector2, arrived: Callable) -> void:
	if not is_instance_valid(hero):
		if arrived.is_valid():
			arrived.call()
		return
	if is_instance_valid(movement_tween):
		movement_tween.kill()
	hero.rotation = 0.0
	hero.scale = _hero_render_scale()
	var floor_line := INTERIOR_GROUND_LINE if inside_house else GROUND_LINE
	var target := Vector2(clampf(destination.x, 52.0, BASE_SIZE.x - 52.0), floor_line - HERO_RENDER_HEIGHT * 0.5)
	hero.flip_h = target.x < hero.position.x
	hero.play("walk")
	_animate_hero_motion(true)
	was_moving_with_keyboard = false
	movement_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movement_tween.tween_property(hero, "position", target, maxf(0.3, hero.position.distance_to(target) / 300.0))
	movement_tween.finished.connect(func() -> void:
		if is_instance_valid(hero):
			hero.play("idle")
			_animate_hero_motion(false)
		if arrived.is_valid():
			arrived.call()
	)


func _process(delta: float) -> void:
	if not is_instance_valid(hero) or inside_house:
		return
	var direction := Input.get_axis("ui_left", "ui_right")
	if not is_zero_approx(direction):
		if is_instance_valid(movement_tween):
			movement_tween.kill()
		if not was_moving_with_keyboard:
			hero.play("walk")
			_animate_hero_motion(true)
		hero.position.x = clampf(hero.position.x + direction * 260.0 * delta, 52.0, BASE_SIZE.x - 52.0)
		hero.flip_h = direction < 0.0
		was_moving_with_keyboard = true
	elif was_moving_with_keyboard:
		hero.play("idle")
		_animate_hero_motion(false)
		was_moving_with_keyboard = false


func _animate_hero_motion(walking: bool) -> void:
	if not is_instance_valid(hero):
		return
	if is_instance_valid(hero_bob_tween):
		hero_bob_tween.kill()
	hero.offset = Vector2.ZERO
	var amplitude := 4.0 if walking else 1.5
	var step_duration := 0.15 if walking else 0.55
	hero_bob_tween = create_tween().set_loops()
	hero_bob_tween.tween_property(hero, "offset", Vector2(0, -amplitude), step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hero_bob_tween.tween_property(hero, "offset", Vector2.ZERO, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if inside_house or not is_instance_valid(hero):
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var world_position := world_root.to_local(get_global_mouse_position())
	for bounds in interaction_bounds:
		if bounds.has_point(world_position):
			return
	if world_position.y >= GROUND_LINE - HERO_RENDER_HEIGHT:
		move_hero_to(Vector2(world_position.x, hero.position.y), Callable())


func set_interior(enabled: bool) -> void:
	inside_house = enabled
	_build_world()


func _build_world() -> void:
	if is_instance_valid(movement_tween):
		movement_tween.kill()
	if is_instance_valid(hero_bob_tween):
		hero_bob_tween.kill()
	interaction_bounds.clear()
	for child in world_root.get_children():
		child.queue_free()
	hero = null
	if inside_house:
		_build_interior()
	else:
		_build_exterior()
	# Rebuild conserva las coordenadas lógicas aunque ocurra al cambiar de escena.
	call_deferred("_fit_to_viewport")


func _build_exterior() -> void:
	# Build the scene from the actual parallax layers and house sprites. The
	# promotional preview includes a castle wall and a baked-in floor, which
	# made the actors look like they were floating over a screenshot.
	for index in range(GREEN_FIELD_LAYERS.size() - 1):
		var layer := _add_sprite(str(GREEN_FIELD_LAYERS[index]), Vector2(640, 360), Vector2(4, 4), -40 + index)
		layer.name = "GreenFieldLayer%d" % index
	_add_walkable_ground()
	_add_cabin()
	_add_goblin()
	_add_knight()
	_add_gacha_forge()
	_add_blacksmith()
	_add_exterior_chest()
	_add_player()
	_add_interaction("door", Vector2(955, GROUND_LINE - 62.0), Vector2(90, 128), "Entrar en la casa", Vector2(855, GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -148.0)


func _add_walkable_ground() -> void:
	var earth := Polygon2D.new()
	earth.name = "WalkableEarth"
	earth.polygon = PackedVector2Array([Vector2(0, GROUND_LINE), Vector2(1280, GROUND_LINE), Vector2(1280, 720), Vector2(0, 720)])
	earth.color = Color("#765033")
	earth.z_index = 6
	world_root.add_child(earth)
	# The field pack supplies the grass edge and flowers; actors stand just in
	# front of it at the same baseline, so feet read clearly against the ground.
	var grass_edge := _add_sprite(str(GREEN_FIELD_LAYERS.back()), Vector2(640, 360), Vector2(4, 4), 8)
	grass_edge.name = "WalkableGrassEdge"


func _add_cabin() -> void:
	var wall := _add_sprite(HOUSE_WALL, Vector2(955, GROUND_LINE - 112), Vector2(2.1, 2.1), 10)
	wall.name = "CabinWall"
	var left_roof := _add_sprite(HOUSE_ROOF_LEFT, Vector2(895, GROUND_LINE - 230), Vector2(2.25, 2.25), 12)
	left_roof.name = "CabinRoofLeft"
	var right_roof := _add_sprite(HOUSE_ROOF_RIGHT, Vector2(1015, GROUND_LINE - 230), Vector2(2.25, 2.25), 12)
	right_roof.name = "CabinRoofRight"
	var door := _add_sprite(HOUSE_DOOR, Vector2(955, GROUND_LINE - 55), Vector2(1.55, 1.55), 14)
	door.name = "CabinDoor"
	var left_window := _add_sprite(HOUSE_WINDOW, Vector2(880, GROUND_LINE - 142), Vector2(1.45, 1.45), 14)
	left_window.name = "CabinLeftWindow"
	var right_window := _add_sprite(HOUSE_WINDOW, Vector2(1030, GROUND_LINE - 142), Vector2(1.45, 1.45), 14)
	right_window.name = "CabinRightWindow"


func _build_interior() -> void:
	var wall := ColorRect.new()
	wall.color = Color("#594034")
	wall.position = Vector2(0, 0)
	wall.size = BASE_SIZE
	wall.z_index = -10
	world_root.add_child(wall)
	var inner_wall := ColorRect.new()
	inner_wall.color = Color("#b68b5c")
	inner_wall.position = Vector2(80, 110)
	inner_wall.size = Vector2(992, 470)
	inner_wall.z_index = -9
	world_root.add_child(inner_wall)
	var floor := ColorRect.new()
	floor.color = Color("#72503a")
	floor.position = Vector2(80, 515)
	floor.size = Vector2(992, 95)
	floor.z_index = -8
	world_root.add_child(floor)
	_add_house_furniture()
	_add_player()
	_add_interaction("bed", Vector2(350, 490), Vector2(210, 120), "Cama · Experiencia AFK", Vector2(430, INTERIOR_GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -115.0)
	_add_interaction("chest", Vector2(790, 535), Vector2(116, 100), "Cofre · Recompensas AFK", Vector2(730, INTERIOR_GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -112.0)
	_add_interaction("door", Vector2(1010, 510), Vector2(100, 140), "Salir al campamento", Vector2(960, INTERIOR_GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -150.0)


func _add_blacksmith() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("work")
	frames.set_animation_speed("work", 7.0)
	frames.set_animation_loop("work", true)
	var sheet := load(BLACKSMITH_SHEET) as Texture2D
	if sheet != null:
		for index in range(7):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(index * 96, 0, 96, 96)
			frames.add_frame("work", atlas)
	var blacksmith := AnimatedSprite2D.new()
	blacksmith.name = "BlacksmithAtForge"
	blacksmith.sprite_frames = frames
	blacksmith.animation = "work"
	blacksmith.position = Vector2(745, GROUND_LINE - 50.0)
	blacksmith.scale = Vector2(1.08, 1.08)
	blacksmith.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blacksmith.z_index = 15
	world_root.add_child(blacksmith)
	blacksmith.play("work")
	_add_interaction("gacha", Vector2(700, GROUND_LINE - 52.0), Vector2(110, 132), "Forja de invocación", Vector2(620, GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -160.0)


func _add_goblin() -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "GoblinGuide"
	sprite.sprite_frames = _make_goblin_frames()
	sprite.animation = "idle"
	sprite.position = Vector2(145, GROUND_LINE - ACTOR_RENDER_HEIGHT * 0.5)
	sprite.scale = Vector2(0.37, 0.37)
	sprite.z_index = 15
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(sprite)
	sprite.play("idle")
	_animate_actor_bob(sprite, 3.0, 0.58)
	_add_interaction("pve", sprite.position, Vector2(100, 145), "Goblin · Aventura PvE", Vector2(230, GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -160.0)


func _animate_actor_bob(actor: Node2D, amplitude: float, half_cycle: float) -> void:
	var resting_position := actor.position
	var bob := create_tween().set_loops()
	bob.tween_property(actor, "position", resting_position + Vector2(0, -amplitude), half_cycle).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(actor, "position", resting_position, half_cycle).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_knight() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_loop("idle", true)
	for frame_path in WARRIOR_IDLE_FRAMES:
		var texture := load(str(frame_path)) as Texture2D
		if texture != null:
			frames.add_frame("idle", texture)
	var knight := AnimatedSprite2D.new()
	knight.name = "ArenaKnight"
	knight.sprite_frames = frames
	knight.animation = "idle"
	knight.position = Vector2(420, GROUND_LINE - ACTOR_RENDER_HEIGHT * 0.5)
	knight.scale = Vector2(2.8, 2.8)
	knight.z_index = 15
	knight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(knight)
	knight.play("idle")
	_add_interaction("pvp", knight.position, Vector2(102, 145), "Eldric · Arena PvP", Vector2(330, GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -160.0)


func _add_gacha_forge() -> void:
	var icon := load("res://assets/ui/cartoon-game-icons-free-sampler-icons__anime_raid_portal__53dfbb1cbc8f.png") as Texture2D
	var portal_height := 138.0
	var portal := _add_sprite_texture(icon, Vector2(700, GROUND_LINE - portal_height * 0.56), Vector2.ONE * portal_height / icon.get_size().y, 14)
	portal.name = "GachaPortal"


func _add_exterior_chest() -> void:
	var chest := AnimatedSprite2D.new()
	chest.name = "AnimatedCampChest"
	chest.sprite_frames = _make_chest_frames()
	chest.animation = "idle"
	chest.position = Vector2(1090, GROUND_LINE - 35.0)
	chest.scale = Vector2(2.05, 2.05)
	chest.z_index = 16
	chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(chest)
	chest.play("idle")
	_add_interaction("chest", chest.position, Vector2(120, 90), "Cofre · Recompensas", Vector2(980, GROUND_LINE - HERO_RENDER_HEIGHT * 0.5), -130.0)


func _add_house_furniture() -> void:
	# Cama sencilla de madera dentro de la casa y cofre animado del pack Animated Chests.
	var bed_frame := ColorRect.new()
	bed_frame.color = Color("#4a2b1c")
	bed_frame.position = Vector2(250, 480)
	bed_frame.size = Vector2(218, 76)
	bed_frame.z_index = 3
	world_root.add_child(bed_frame)
	var mattress := ColorRect.new()
	mattress.color = Color("#ead5a8")
	mattress.position = Vector2(260, 486)
	mattress.size = Vector2(198, 54)
	mattress.z_index = 4
	world_root.add_child(mattress)
	var pillow := ColorRect.new()
	pillow.color = Color("#fff1d2")
	pillow.position = Vector2(269, 491)
	pillow.size = Vector2(43, 32)
	pillow.z_index = 5
	world_root.add_child(pillow)
	var animated_chest := AnimatedSprite2D.new()
	animated_chest.name = "AnimatedRewardChest"
	animated_chest.sprite_frames = _make_chest_frames()
	animated_chest.animation = "idle"
	animated_chest.position = Vector2(790, 540)
	animated_chest.scale = Vector2(2.0, 2.0)
	animated_chest.z_index = 9
	animated_chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(animated_chest)
	animated_chest.play("idle")


func _add_player() -> void:
	set_hero(active_hero_id)
	if inside_house and is_instance_valid(hero):
		hero.position = Vector2(350, 485)
		hero.rotation = PI * 0.5
		hero.scale = _hero_render_scale() * 0.82


func _add_interaction(kind: String, at: Vector2, size: Vector2, label_text: String, player_destination: Vector2, label_offset_y: float = -155.0) -> void:
	interaction_bounds.append(Rect2(at - size * 0.5, size))
	var area := Area2D.new()
	area.name = "Interact_" + kind
	area.position = at
	area.input_pickable = true
	area.z_index = 40
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	area.add_child(collision)
	area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			interaction_requested.emit(kind, player_destination)
		elif event is InputEventScreenTouch and event.pressed:
			interaction_requested.emit(kind, player_destination)
	)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-100, label_offset_y)
	label.size = Vector2(200, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#fff0c9"))
	label.add_theme_color_override("font_outline_color", Color("#302014"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.hide()
	area.add_child(label)
	area.mouse_entered.connect(label.show)
	area.mouse_exited.connect(label.hide)
	world_root.add_child(area)


func _add_sprite(path: String, at: Vector2, sprite_scale: Vector2, layer: int) -> Sprite2D:
	var texture := load(path) as Texture2D
	return _add_sprite_texture(texture, at, sprite_scale, layer)


func _add_sprite_texture(texture: Texture2D, at: Vector2, sprite_scale: Vector2, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = sprite_scale
	sprite.z_index = layer
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(sprite)
	return sprite


func _atlas(path: String, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path) as Texture2D
	atlas.region = region
	return atlas


func _make_chest_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 5.0)
	frames.set_animation_loop("idle", true)
	var sheet := load(CHEST_SHEET) as Texture2D
	if sheet != null:
		for frame in range(5):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(frame * 48, 0, 48, 32)
			frames.add_frame("idle", atlas)
	return frames


func _make_goblin_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 7.0)
	frames.set_animation_loop("idle", true)
	var sheet := load(GOBLIN_BLINK_SHEET) as Texture2D
	if sheet != null:
		var frame_size := sheet.get_size().x / 4.0
		for frame_index in range(16):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2((frame_index % 4) * frame_size, floori(float(frame_index) / 4.0) * frame_size, frame_size, frame_size)
			frames.add_frame("idle", atlas)
	return frames


func _hero_render_scale() -> Vector2:
	if not is_instance_valid(hero) or hero.sprite_frames == null or hero.sprite_frames.get_frame_count("idle") == 0:
		return Vector2.ONE
	var frame := hero.sprite_frames.get_frame_texture("idle", 0)
	return Vector2.ONE * HERO_RENDER_HEIGHT / maxf(1.0, frame.get_size().y)


func _make_hero_frames(hero_id: String, selected_texture: Texture2D) -> SpriteFrames:
	var hero_frame := selected_texture
	if hero_frame == null:
		var paths := {
			"guardiana": "res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Idle_000__03a3950e139c.png",
			"espadachin": "res://assets/sprites/characters/Cartoon Characters by Rgs_dev__idle_1__0b2202b72ab3.png",
			"explorador": "res://assets/sprites/characters/Cartoon Characters by Rgs_dev__idle_0__4fae79732974.png",
		}
		var source := load(str(paths.get(hero_id, paths["guardiana"]))) as Texture2D
		if source != null and hero_id == "guardiana":
			hero_frame = _atlas(str(paths[hero_id]), Rect2(208, 185, 436, 565))
		elif source != null and hero_id == "espadachin":
			hero_frame = _atlas(str(paths[hero_id]), Rect2(163, 140, 189, 240))
		elif source != null:
			hero_frame = _atlas(str(paths.get(hero_id, paths["guardiana"])), Rect2(154, 157, 250, 223))
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", hero_frame)
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	frames.add_frame("walk", hero_frame)
	return frames
