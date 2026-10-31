extends Node2D
## Escenario horizontal del refugio. Las coordenadas están diseñadas sobre 1152x720
## y se escalan uniformemente para conservar la proporción en móvil y escritorio.

signal interaction_requested(kind: String, destination: Vector2)

const BASE_SIZE := Vector2(1152.0, 720.0)
const GREEN_FIELD := "res://assets/sprites/environments/green_field_fkgcluster/PNG/"
const SIDE_TILES := "res://assets/sprites/environments/side_scroller_village_v2/Tiles/"
const MEDIEVAL := "res://assets/sprites/environments/medieval_village_intc2748/Medieval House/"
const CHEST_SHEET := "res://assets/sprites/props/animated_chests_admurin/Chests.png"
const BLACKSMITH_SHEET := "res://assets/sprites/characters/npcs/blacksmith_mattz/BLACKSMITH.png"

const RUN_FRAMES := {
	"guardiana": [
		"res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Walking_000__40f3482e3155.png",
		"res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Walking_001__5e37942bb2b8.png",
		"res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Walking_002__e3e7cd8c76bb.png",
		"res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Walking_003__8f426bcd31b7.png",
		"res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Walking_004__9e1fda4305e4.png",
		"res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Walking_005__a1ab222e2eb3.png",
	],
	"espadachin": [
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_0__11f302d8be96.png",
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_1__580aae8ae07b.png",
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_2__9f1916809126.png",
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_3__c2df0caeac93.png",
	],
	"explorador": [
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_0__638502635735.png",
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_1__a883e4d3311a.png",
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_2__28126e7c324a.png",
		"res://assets/sprites/characters/Cartoon Characters by Rgs_dev__run_3__e318a5e6fcac.png",
	],
}

var world_root: Node2D
var hero: AnimatedSprite2D
var inside_house := false
var base_scale := 1.0
var active_hero_id := "guardiana"


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
	hero = AnimatedSprite2D.new()
	hero.name = "PlayerHero"
	hero.sprite_frames = _make_hero_frames(hero_id)
	hero.animation = "walk"
	hero.position = Vector2(480, 558)
	hero.scale = Vector2(0.22, 0.22) if hero_id == "guardiana" else Vector2(0.40, 0.40)
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(hero)
	hero.play("idle")
	# El héroe se dibuja delante de objetos y fondo, pero bajo los rótulos interactivos.
	hero.z_index = 20


func move_hero_to(destination: Vector2, arrived: Callable) -> void:
	if not is_instance_valid(hero):
		if arrived.is_valid():
			arrived.call()
		return
	hero.flip_h = destination.x < hero.position.x
	hero.play("walk")
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hero, "position", destination, maxf(0.22, hero.position.distance_to(destination) / 260.0))
	tween.finished.connect(func() -> void:
		if is_instance_valid(hero):
			hero.play("idle")
		if arrived.is_valid():
			arrived.call()
	)


func set_interior(enabled: bool) -> void:
	inside_house = enabled
	_build_world()
	if is_instance_valid(hero):
		hero.position = Vector2(570, 560) if enabled else Vector2(480, 558)
		hero.play("idle")


func _build_world() -> void:
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
	_add_green_field_layer("00_sky.png", Vector2(576, 360), 0)
	_add_green_field_layer("01_back.png", Vector2(576, 360), 1)
	_add_green_field_layer("02_cloud1.png", Vector2(576, 330), 2)
	_add_green_field_layer("03_cloud2.png", Vector2(576, 345), 3)
	_add_green_field_layer("04_mid1.png", Vector2(576, 360), 4)
	_add_green_field_layer("05_mid2.png", Vector2(576, 385), 5)
	_add_exterior_house()
	_add_village_props()
	_add_ground()
	_add_blacksmith()
	_add_goblin()
	_add_knight()
	_add_gacha_forge()
	_add_player()
	_add_interaction("door", Vector2(850, 548), Vector2(95, 105), "Entrar en la casa")


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
	_add_interaction("bed", Vector2(350, 545), Vector2(210, 120), "Cama · Experiencia AFK")
	_add_interaction("chest", Vector2(790, 557), Vector2(116, 100), "Cofre · Recompensas AFK")
	_add_interaction("door", Vector2(1010, 540), Vector2(100, 140), "Salir al campamento")


func _add_green_field_layer(file_name: String, at: Vector2, layer: int) -> void:
	var texture := load(GREEN_FIELD + file_name) as Texture2D
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2(3.6, 3.6)
	sprite.centered = true
	sprite.z_index = layer - 20
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(sprite)


func _add_exterior_house() -> void:
	# Casa modular hecha con piezas originales del pack Medieval Village.
	var wall := _add_sprite(MEDIEVAL + "House_Wall.png", Vector2(850, 480), Vector2(2.4, 1.75), -2)
	wall.name = "HouseWall"
	_add_sprite(MEDIEVAL + "Roof_1.png", Vector2(850, 382), Vector2(1.55, 1.15), -1)
	_add_sprite(MEDIEVAL + "Roof_2.png", Vector2(850, 380), Vector2(1.55, 1.15), -1)
	_add_sprite(MEDIEVAL + "Wooden_Beam_1.png", Vector2(790, 448), Vector2(2.0, 2.0), 0)
	_add_sprite(MEDIEVAL + "Wooden_Beam-2.png", Vector2(910, 448), Vector2(2.0, 2.0), 0)
	_add_sprite(MEDIEVAL + "Wooden_Door.png", Vector2(850, 528), Vector2(1.4, 1.4), 2)
	_add_sprite(MEDIEVAL + "Window_1.png", Vector2(920, 477), Vector2(1.35, 1.35), 2)


func _add_village_props() -> void:
	var objects_path := "res://assets/sprites/environments/medieval_village_intc2748/Objects/"
	_add_sprite(objects_path + "Wooden_Fence.png", Vector2(1005, 548), Vector2(2.0, 2.0), 2)
	_add_sprite(objects_path + "Wooden_Barrel.png", Vector2(750, 550), Vector2(1.8, 1.8), 3)
	_add_sprite(objects_path + "Tree_Stump.png", Vector2(540, 545), Vector2(1.7, 1.7), 2)
	_add_sprite(objects_path + "Stone.png", Vector2(112, 556), Vector2(1.8, 1.8), 2)


func _add_ground() -> void:
	var ground_files := [
		"Platformer - Ground 01.png", "Platformer - Ground 02.png", "Platformer - Ground 03.png",
		"Platformer - Ground 04.png", "Platformer - Ground 05.png", "Platformer - Ground 06.png",
		"Platformer - Ground 07.png", "Platformer - Ground 08.png", "Platformer - Ground 09.png",
	]
	for index in range(9):
		var texture := load(SIDE_TILES + ground_files[index]) as Texture2D
		if texture == null:
			continue
		var tile := Sprite2D.new()
		tile.texture = texture
		tile.position = Vector2(64 + index * 128, 650)
		tile.z_index = 8
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		world_root.add_child(tile)


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
	blacksmith.position = Vector2(628, 548)
	blacksmith.scale = Vector2(1.45, 1.45)
	blacksmith.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blacksmith.z_index = 15
	world_root.add_child(blacksmith)
	blacksmith.play("work")
	_add_sprite("res://assets/sprites/props/side_scroller_village_v2/Bonfire.png", Vector2(650, 560), Vector2(0.55, 0.55), 12)
	_add_interaction("gacha", Vector2(628, 550), Vector2(110, 130), "Forja de invocación")


func _add_goblin() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _atlas("res://assets/sprites/enemies/craftpix-net-228980-free-top-down-goblin-char__Front - Idle_000__00170a9b3881.png", Rect2(124, 67, 233, 315))
	sprite.position = Vector2(180, 548)
	sprite.scale = Vector2(0.45, 0.45)
	sprite.z_index = 15
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(sprite)
	_add_interaction("pve", Vector2(180, 548), Vector2(100, 140), "Goblin · Aventura PvE")


func _add_knight() -> void:
	var portrait := _atlas("res://assets/sprites/characters/Cartoon Characters by Rgs_dev__idle_1__0b2202b72ab3.png", Rect2(163, 140, 189, 240))
	_add_sprite_texture(portrait, Vector2(370, 548), Vector2(0.42, 0.42), 15)
	_add_interaction("pvp", Vector2(370, 548), Vector2(100, 140), "Eldric · Arena PvP")


func _add_gacha_forge() -> void:
	var icon := load("res://assets/ui/cartoon-game-icons-free-sampler-icons__anime_raid_portal__53dfbb1cbc8f.png") as Texture2D
	_add_sprite_texture(icon, Vector2(625, 475), Vector2(0.78, 0.78), 14)


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
	animated_chest.position = Vector2(790, 560)
	animated_chest.scale = Vector2(2.2, 2.2)
	animated_chest.z_index = 9
	animated_chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_root.add_child(animated_chest)
	animated_chest.play("idle")


func _add_player() -> void:
	set_hero(active_hero_id)


func _add_interaction(kind: String, at: Vector2, size: Vector2, label_text: String) -> void:
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
			interaction_requested.emit(kind, at + Vector2(0, 8))
		elif event is InputEventScreenTouch and event.pressed:
			interaction_requested.emit(kind, at + Vector2(0, 8))
	)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-90, -78)
	label.size = Vector2(180, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#fff0c9"))
	label.add_theme_color_override("font_outline_color", Color("#302014"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(label)
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


func _make_hero_frames(hero_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 9.0)
	frames.set_animation_loop("walk", true)
	var paths: Array = RUN_FRAMES.get(hero_id, RUN_FRAMES["guardiana"])
	if hero_id == "guardiana":
		paths = _valkyrie_walk_paths()
	for path in paths:
		var whole_texture := load(str(path)) as Texture2D
		if whole_texture == null:
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = whole_texture
		atlas.region = Rect2(112, 110, 300, 390) if hero_id != "guardiana" else Rect2(145, 135, 620, 650)
		frames.add_frame("walk", atlas)
	if frames.get_frame_count("walk") == 0:
		frames.add_frame("walk", load("res://assets/sprites/characters/Cartoon Characters by Rgs_dev__idle_1__0b2202b72ab3.png") as Texture2D)
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", frames.get_frame_texture("walk", 0))
	return frames


func _valkyrie_walk_paths() -> Array[String]:
	var paths: Array[String] = []
	var source_directory := "res://assets/sprites/characters"
	var files := DirAccess.get_files_at(source_directory)
	files.sort()
	for frame_index in range(24):
		var prefix := "craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Walking_%03d__" % frame_index
		for file_name in files:
			if file_name.begins_with(prefix) and file_name.ends_with(".png"):
				paths.append(source_directory.path_join(file_name))
				break
	return paths
