extends Control
## Campamento inicial, onboarding y perfil persistente de Tierras de Valoria.

const BACKGROUND_PATH := "res://assets/sprites/environments/free-cartoon-forest-game-backgrounds__Cartoon_Forest_BG_01__e36fbfd52092.png"
const CAMP_CHEST_PATH := "res://assets/ui/Stylized_Game_Essentials_147_Icons__01_wooden_chest__ac7d7fa93e1e.png"
const CAMP_GACHA_PORTAL_PATH := "res://assets/ui/cartoon-game-icons-free-sampler-icons__anime_raid_portal__53dfbb1cbc8f.png"
const WELCOME_NPC_PATH := "res://assets/sprites/characters/Arcane Wizard__0 (2)__eb3d715bdd4d.png"
const THEME_PATH := "res://assets/ui/MainMenuTheme.tres"
const PLATFORMER_STAGE_SCRIPT = preload("res://scenes/game/CampPlatformerStage.gd")
const LOCAL_PROFILE_PATH := "user://valoria_profiles.cfg"
const MAX_AFK_SECONDS := 86400
const CURRENCY_ICON_PATHS := {
	"coins": "res://assets/ui/craftpix-net-482753-free-currency-loot-vector__18__68253f2b5e4f.png",
	"tickets": "res://assets/ui/craftpix-net-482753-free-currency-loot-vector__33__20ecf45c68d6.png",
	"diamonds": "res://assets/ui/craftpix-net-482753-free-currency-loot-vector__2__6bfcdf056721.png",
	"premium_tickets": "res://assets/ui/craftpix-net-482753-free-currency-loot-vector__41__ba79f3ee30be.png",
}
const PVE_GOBLIN_PATH := "res://assets/sprites/enemies/craftpix-net-228980-free-top-down-goblin-char__Front - Idle_000__00170a9b3881.png"
const PVE_GOBLIN_REGION := Rect2(124, 67, 233, 315)
const PVE_SMOKE_FRAME_PATHS := [
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_01__31c33869d8b7.png",
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_02__a988da989c6c.png",
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_03__c1ac2811e992.png",
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_04__db98ffcad609.png",
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_05__f620b61dbc34.png",
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_06__b69776d2cd64.png",
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_07__b425198513a4.png",
	"res://assets/vfx/craftpix-net-333631-free-cartoon-smoke-effect__Chemical Smoke_Frame_08__dc45696d9780.png",
]
const COMMON_HEROES := [
	{"id": "guardiana", "character_name": "Lyria", "name": "Guardiana del Alba", "description": "Firme en defensa, valiente en primera línea.", "portrait": "res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Idle_000__03a3950e139c.png", "portrait_region": Rect2(208, 185, 436, 565)},
	{"id": "espadachin", "character_name": "Eldric", "name": "Espadachín Errante", "description": "Su acero protege a quienes viajan a su lado.", "portrait": "res://assets/sprites/characters/Cartoon Characters by Rgs_dev__idle_1__0b2202b72ab3.png", "portrait_region": Rect2(163, 140, 189, 240)},
	{"id": "explorador", "character_name": "Naira", "name": "Exploradora del Bosque", "description": "Ágil y certera; conoce cada sendero oculto.", "portrait": "res://assets/sprites/characters/Cartoon Characters by Rgs_dev__idle_0__4fae79732974.png", "portrait_region": Rect2(154, 157, 250, 223)},
]
const RARE_HEROES := [
	{"id": "paladin_celeste", "name": "Paladín Celeste", "description": "Épico · Su juramento protege a los aliados.", "portrait": "res://assets/sprites/characters/craftpix-net-469596-free-chibi-valkyrie-chara__0_Valkyrie_Idle_000__c5cdd0b2bb71.png", "portrait_region": Rect2(221, 194, 403, 556)},
	{"id": "bruja_lunar", "name": "Bruja Lunar", "description": "Épica · Su magia atraviesa la oscuridad.", "portrait": "res://assets/sprites/characters/craftpix-net-787868-free-seer-chibi-character__0_Seer_Idle_000__6dd66ef60a1c.png", "portrait_region": Rect2(232, 200, 385, 551)},
]

enum Page { INTRO, NICKNAME, HERO, FAREWELL, CAMP, SETTINGS, GACHA, PVE, PVP, CHEST, BED }

var page := Page.INTRO
var profile: Dictionary = {}
var account_uid := ""
var account_name := "Aventurero"
var nickname_checked := false
var checked_nickname := ""
var profile_save_pending := false
var last_status := ""
var camp_operational := false

var status_label: Label
var page_host: CenterContainer
var page_scroll: ScrollContainer
var camp_world: Control
var camp_points: Control
var camp_modal_shade: ColorRect
var platformer_stage: Node2D
var currency_hud: Control
var currency_grid: GridContainer
var currency_labels: Dictionary = {}
var currency_icons: Dictionary = {}
var profile_name_label: Label
var profile_level_label: Label
var profile_portrait: TextureRect
var nickname_input: LineEdit
var nickname_feedback: Label
var nickname_button: Button
var hero_buttons: Array[Button] = []
var gacha_feedback: Label
var gacha_result_portrait: TextureRect
var google_link_button: Button
var pve_effect_timer: Timer
var pve_effect_frames: Array[Texture2D] = []
var pve_effect_frame_index := 0
func _ready() -> void:
	theme = load(THEME_PATH)
	# Construye el fondo y el estado de carga antes de leer metadatos remotos.
	# Así la escena nunca queda como un canvas vacío si el proveedor omite un campo.
	_build_interface()
	account_uid = str(SupabaseManager.current_user.get("id", ""))
	var metadata_value: Variant = SupabaseManager.current_user.get("user_metadata", {})
	var user_metadata: Dictionary = metadata_value if metadata_value is Dictionary else {}
	account_name = str(user_metadata.get("display_name", "")).strip_edges()
	if account_name.is_empty():
		account_name = str(SupabaseManager.current_user.get("email", "Aventurero"))
	if account_uid.is_empty():
		account_uid = "guest"
	get_viewport().size_changed.connect(_on_viewport_resized)
	_load_profile()
	SupabaseManager.profile_loaded.connect(_on_supabase_profile_loaded)
	SupabaseManager.profile_saved.connect(_on_supabase_profile_saved)
	SupabaseManager.auth_completed.connect(_on_supabase_auth_completed)
	_load_cloud_profile()
	if not SupabaseManager.transient_auth_notice.is_empty():
		_set_status(SupabaseManager.transient_auth_notice)
		SupabaseManager.transient_auth_notice = ""


func _build_interface() -> void:
	var background := TextureRect.new()
	background.name = "ForestBackground"
	background.texture = load(BACKGROUND_PATH)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.07, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	camp_world = $CampWorld
	camp_points = $CampWorld/PointsOfInterest
	camp_modal_shade = $CampWorld/ModalShade
	camp_world.hide()
	camp_modal_shade.hide()

	var margin := MarginContainer.new()
	margin.name = "SafeArea"
	margin.z_index = 5
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen_width := get_viewport_rect().size.x
	var horizontal_margin := 14 if screen_width < 640.0 else 24
	margin.add_theme_constant_override("margin_left", horizontal_margin)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", horizontal_margin)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.name = "MainLayout"
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	currency_hud = _build_hud()
	currency_hud.hide()
	layout.add_child(currency_hud)
	page_scroll = ScrollContainer.new()
	page_scroll.name = "PageScroll"
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(page_scroll)
	page_host = CenterContainer.new()
	page_host.name = "PageHost"
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page_host)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 28
	status_label.hide()
	layout.add_child(status_label)


func _build_hud() -> Control:
	var hud := VBoxContainer.new()
	hud.name = "ValoriaHUD"
	hud.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	var screen_width := get_viewport_rect().size.x
	var compact := screen_width < 640.0
	header.name = "HUDHeader"
	header.add_theme_constant_override("separation", 8 if compact else 16)
	hud.add_child(header)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	brand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(brand)
	var logo := Label.new()
	logo.text = "TIERRAS DE VALORIA"
	logo.add_theme_font_size_override("font_size", 13 if compact else 20 if screen_width >= 800.0 else 16)
	logo.clip_text = false
	logo.add_theme_color_override("font_color", Color(1.0, 0.91, 0.68, 1.0))
	logo.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.035, 1.0))
	logo.add_theme_constant_override("outline_size", 4)
	brand.add_child(logo)
	var camp_subtitle := Label.new()
	camp_subtitle.text = "REFUGIO DEL BOSQUE"
	camp_subtitle.add_theme_font_size_override("font_size", 9 if compact else 10)
	camp_subtitle.add_theme_color_override("font_color", Color(0.95, 0.83, 0.58, 1.0))
	brand.add_child(camp_subtitle)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var profile_card := PanelContainer.new()
	profile_card.name = "PlayerProfile"
	profile_card.custom_minimum_size = Vector2(144, 42) if compact else Vector2(184, 48)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 5)
	profile_card.add_child(profile_row)
	profile_portrait = TextureRect.new()
	profile_portrait.custom_minimum_size = Vector2(26, 32) if compact else Vector2(32, 38)
	profile_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	profile_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_row.add_child(profile_portrait)
	var profile_copy := VBoxContainer.new()
	profile_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_copy.add_theme_constant_override("separation", 0)
	profile_row.add_child(profile_copy)
	profile_name_label = Label.new()
	profile_name_label.text = "Aventurero"
	profile_name_label.clip_text = true
	profile_copy.add_child(profile_name_label)
	profile_level_label = Label.new()
	profile_level_label.text = "Nivel 1 · Héroe"
	profile_level_label.add_theme_font_size_override("font_size", 9 if compact else 11)
	profile_level_label.add_theme_color_override("font_color", Color(0.34, 0.22, 0.14, 1.0))
	profile_copy.add_child(profile_level_label)
	var profile_settings := Button.new()
	profile_settings.text = "⚙"
	profile_settings.tooltip_text = "Ajustes de cuenta y juego"
	profile_settings.custom_minimum_size = Vector2(32, 30) if compact else Vector2(36, 34)
	profile_settings.add_theme_font_size_override("font_size", 18)
	profile_settings.pressed.connect(_open_settings)
	profile_row.add_child(profile_settings)
	header.add_child(profile_card)
	currency_grid = GridContainer.new()
	currency_grid.name = "CurrencyGrid"
	currency_grid.columns = 4 if screen_width >= 440.0 else 2
	currency_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	currency_grid.add_theme_constant_override("h_separation", 12 if screen_width >= 640.0 else 5)
	currency_grid.add_theme_constant_override("v_separation", 2)
	hud.add_child(currency_grid)
	var currencies := [
		["coins", "Oro"], ["tickets", "Tickets gacha"],
		["diamonds", "Diamantes"], ["premium_tickets", "Tickets especiales"],
	]
	for item in currencies:
		var badge := HBoxContainer.new()
		badge.custom_minimum_size = Vector2(70, 30) if screen_width >= 640.0 else Vector2(62, 28)
		badge.tooltip_text = str(item[1])
		badge.add_theme_constant_override("separation", 4)
		badge.alignment = BoxContainer.ALIGNMENT_BEGIN
		var badge_content := HBoxContainer.new()
		badge_content.add_theme_constant_override("separation", 4)
		badge_content.alignment = BoxContainer.ALIGNMENT_CENTER
		badge.add_child(badge_content)
		var icon := TextureRect.new()
		icon.texture = load(str(CURRENCY_ICON_PATHS[item[0]]))
		icon.custom_minimum_size = Vector2(22, 22) if screen_width >= 640.0 else Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_content.add_child(icon)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.text = "0"
		label.add_theme_font_size_override("font_size", 12 if screen_width >= 640.0 else 10)
		label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.75, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.03, 1.0))
		label.add_theme_constant_override("outline_size", 3)
		badge_content.add_child(label)
		currency_grid.add_child(badge)
		currency_labels[item[0]] = label
		currency_icons[item[0]] = icon
	return hud


func _panel(title: String, min_size := Vector2(440, 0)) -> Dictionary:
	var panel := PanelContainer.new()
	var available_width := maxf(280.0, get_viewport_rect().size.x - 52.0)
	panel.custom_minimum_size = Vector2(minf(min_size.x, available_width), min_size.y)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var margin := MarginContainer.new()
	var panel_margin := 14 if get_viewport_rect().size.x < 720.0 else 22
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, panel_margin)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	box.add_child(heading)
	return {"panel": panel, "box": box}


func _add_body(box: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 68
	box.add_child(label)
	return label


func _add_button(box: VBoxContainer, text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		button.theme_type_variation = "PrimaryButton"
	button.pressed.connect(callback)
	box.add_child(button)
	return button


func _show_page(new_page: Page, panel: Control) -> void:
	if is_instance_valid(pve_effect_timer):
		pve_effect_timer.stop()
	page = new_page
	if is_instance_valid(currency_hud):
		currency_hud.visible = camp_operational
	if is_instance_valid(status_label):
		status_label.visible = camp_operational
	if is_instance_valid(camp_world):
		camp_world.visible = camp_operational
	if is_instance_valid(camp_modal_shade):
		camp_modal_shade.visible = camp_operational
	if is_instance_valid(page_scroll):
		page_scroll.show()
	for child in page_host.get_children():
		child.queue_free()
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.96, 0.96)
	page_host.add_child(panel)
	call_deferred("_animate_panel_in", panel)


func _animate_panel_in(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22)


func _show_intro() -> void:
	_show_npc_dialogue(
		"Bienvenido a las Tierras de Valoria. La oscuridad cubre aldeas y caminos; necesitamos aventureros que ayuden a devolver la esperanza y la prosperidad.",
		"Cuéntame más",
		_on_intro_lore_one
	)


func _on_intro_lore_one() -> void:
	_show_npc_dialogue(
		"Hace siete noches, las estrellas se apagaron una a una. Con ellas se extinguieron los faros antiguos que mantenían a raya a las sombras.",
		"¿Qué ocurrió después?",
		_on_intro_lore_two
	)


func _on_intro_lore_two() -> void:
	_show_npc_dialogue(
		"Una niebla negra cubrió los caminos. Los aldeanos dicen que una grieta se abrió en las ruinas de la Corona y que algo despertó bajo sus piedras.",
		"¿Dónde empezamos?",
		_on_intro_lore_three
	)


func _on_intro_lore_three() -> void:
	_show_npc_dialogue(
		"Este campamento es la última llama segura del bosque. Nuestros exploradores vieron criaturas acercarse: tendremos que reunir aliados y despejar las rutas, paso a paso.",
		"Entiendo, mago",
		_on_intro_continue
	)


func _on_intro_continue() -> void:
	_show_npc_dialogue(
		"¡Ups! ¡Qué despistado soy! No te he preguntado cómo te llamas, joven aventurero.",
		"Decir mi nombre",
		_show_nickname
	)


func _show_npc_dialogue(message: String, action_text: String, action: Callable, dialogue_page: Page = Page.INTRO) -> void:
	var composition := HBoxContainer.new()
	composition.name = "WelcomeDialogue"
	var available_width := maxf(320.0, get_viewport_rect().size.x - 52.0)
	composition.custom_minimum_size = Vector2(minf(840.0, available_width), 360)
	composition.alignment = BoxContainer.ALIGNMENT_CENTER
	composition.add_theme_constant_override("separation", 22)

	var portrait_frame := CenterContainer.new()
	var portrait_width := minf(280.0, maxf(100.0, available_width * 0.31))
	portrait_frame.custom_minimum_size = Vector2(portrait_width, 320)
	var portrait := _make_npc_portrait()
	portrait.custom_minimum_size = Vector2(portrait_width - 8.0, 300)
	portrait_frame.add_child(portrait)
	composition.add_child(portrait_frame)

	var bubble := PanelContainer.new()
	bubble.name = "SpeechBubble"
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.custom_minimum_size = Vector2(maxf(200.0, available_width - portrait_width - 22.0), 240)
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.97, 0.92, 0.79, 0.97)
	bubble_style.border_color = Color(0.57, 0.37, 0.18, 0.96)
	bubble_style.set_border_width_all(3)
	bubble_style.set_corner_radius_all(22)
	bubble_style.shadow_color = Color(0.04, 0.07, 0.05, 0.36)
	bubble_style.shadow_size = 12
	bubble_style.shadow_offset = Vector2(0, 5)
	bubble_style.content_margin_left = 28
	bubble_style.content_margin_top = 24
	bubble_style.content_margin_right = 28
	bubble_style.content_margin_bottom = 24
	bubble.add_theme_stylebox_override("panel", bubble_style)
	var pointer := Polygon2D.new()
	pointer.polygon = PackedVector2Array([Vector2(-12, 120), Vector2(20, 104), Vector2(20, 136)])
	pointer.color = bubble_style.bg_color
	bubble.add_child(pointer)
	var bubble_content := VBoxContainer.new()
	bubble_content.add_theme_constant_override("separation", 18)
	bubble.add_child(bubble_content)
	var speaker := Label.new()
	speaker.text = "EL MAGO DEL CAMPAMENTO"
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker.add_theme_font_size_override("font_size", 17)
	bubble_content.add_child(speaker)
	var text := Label.new()
	text.text = message
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 20)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bubble_content.add_child(text)
	_add_button(bubble_content, action_text, action, true)
	composition.add_child(bubble)
	_show_page(dialogue_page, composition)


func _make_npc_portrait() -> TextureRect:
	var portrait := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(WELCOME_NPC_PATH)
	atlas.region = Rect2(0, 0, 256, 256)
	portrait.texture = atlas
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait


func _hero_portrait_texture(hero: Dictionary) -> Texture2D:
	var texture := load(str(hero.get("portrait", ""))) as Texture2D
	if texture == null:
		return null
	if hero.has("portrait_region"):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = hero["portrait_region"]
		return atlas
	return texture


func _show_nickname() -> void:
	var view := _panel("Elige tu nombre", Vector2(460, 0))
	_add_body(view.box, "Usa entre 4 y 12 letras o números, sin espacios ni símbolos.")
	nickname_input = LineEdit.new()
	nickname_input.placeholder_text = "Nombre de aventurero"
	nickname_input.max_length = 12
	nickname_input.text = str(profile.get("nickname", ""))
	nickname_input.text_changed.connect(_on_nickname_text_changed)
	nickname_input.text_submitted.connect(func(_text: String) -> void: _on_check_nickname())
	view.box.add_child(nickname_input)
	nickname_feedback = _add_body(view.box, "")
	nickname_feedback.custom_minimum_size.y = 32
	nickname_button = _add_button(view.box, "Comprobar nombre", _on_check_nickname, true)
	_add_button(view.box, "Volver", _on_intro_continue)
	_show_page(Page.NICKNAME, view.panel)
	nickname_input.grab_focus.call_deferred()


func _on_check_nickname() -> void:
	var nickname := nickname_input.text
	if not _valid_nickname(nickname):
		nickname_checked = false
		_set_nickname_feedback("El nombre debe tener de 4 a 12 letras o números.", true)
		return
	if nickname_checked and nickname == checked_nickname:
		_accept_nickname_and_choose_hero(nickname)
		return
	if not _save_session_nickname(nickname):
		_set_nickname_feedback("No se pudo guardar el nombre en este dispositivo. Comprueba el espacio disponible e inténtalo de nuevo.", true)
		return
	checked_nickname = nickname
	nickname_checked = true
	nickname_button.text = "Elegir nombre"
	_set_nickname_feedback("Nombre válido y guardado para esta sesión.")


func _on_nickname_text_changed(_text: String) -> void:
	nickname_checked = false
	if is_instance_valid(nickname_button):
		nickname_button.text = "Comprobar nombre"
		nickname_button.disabled = false


func _valid_nickname(nickname: String) -> bool:
	if nickname.length() < 4 or nickname.length() > 12:
		return false
	for character in nickname:
		var code := character.unicode_at(0)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)):
			return false
	return true


func _set_nickname_feedback(message: String, is_error := false) -> void:
	nickname_feedback.text = message
	nickname_feedback.add_theme_color_override("font_color", Color(0.65, 0.12, 0.09) if is_error else Color(0.12, 0.42, 0.18))


func _save_session_nickname(nickname: String) -> bool:
	var metadata := ConfigFile.new()
	metadata.load(LOCAL_PROFILE_PATH)
	if nickname.is_empty():
		if metadata.has_section_key("session_metadata", account_uid):
			metadata.erase_section_key("session_metadata", account_uid)
	else:
		metadata.set_value("session_metadata", account_uid, {"nickname": nickname})
	return metadata.save(LOCAL_PROFILE_PATH) == OK


func _accept_nickname_and_choose_hero(nickname: String) -> void:
	profile["nickname"] = nickname
	if not _save_local_profile():
		_set_nickname_feedback("No se pudo guardar el perfil local; inténtalo de nuevo.", true)
		return
	_show_npc_dialogue(
		"Gracias por confiarme tu nombre, %s. Ningún destino se enfrenta a solas: elige un compañero para el primer viaje; su valor será tan importante como su fuerza." % nickname,
		"Ver a los héroes",
		_show_hero_choice
	)


func _show_hero_choice() -> void:
	var view := _panel("Elige a tu primer héroe", Vector2(800, 0))
	_add_body(view.box, "Tres compañeros comunes esperan comenzar contigo esta aventura.")
	hero_buttons.clear()
	var cards := GridContainer.new()
	var viewport_width := get_viewport_rect().size.x
	cards.columns = 1 if viewport_width < 620.0 else 2 if viewport_width < 960.0 else 3
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	view.box.add_child(cards)
	var card_width := minf(220.0, maxf(180.0, (viewport_width - 100.0 - float(cards.columns - 1) * 12.0) / float(cards.columns)))
	for hero in COMMON_HEROES:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(card_width, 310)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 8)
		card.add_child(card_content)
		var character_name := Label.new()
		character_name.text = str(hero.get("character_name", ""))
		character_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		character_name.add_theme_font_size_override("font_size", 21)
		character_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(character_name)
		var hero_title := Label.new()
		hero_title.text = str(hero.get("name", ""))
		hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_title.add_theme_font_size_override("font_size", 16)
		hero_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(hero_title)
		var portrait_center := CenterContainer.new()
		var hero_portrait := TextureRect.new()
		hero_portrait.texture = _hero_portrait_texture(hero)
		hero_portrait.custom_minimum_size = Vector2(150, 132)
		hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		hero_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_center.add_child(hero_portrait)
		card_content.add_child(portrait_center)
		var hero_description := Label.new()
		hero_description.text = hero.description
		hero_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hero_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hero_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_content.add_child(hero_description)
		var button := _add_button(card_content, "Elegir héroe", _on_hero_choice_pressed.bind(str(hero.get("id", ""))), true)
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.custom_minimum_size.y = 46
		cards.add_child(card)
		hero_buttons.append(button)
	_show_page(Page.HERO, view.panel)


func _on_hero_choice_pressed(hero_id: String) -> void:
	for hero in COMMON_HEROES:
		if str(hero.get("id", "")) == hero_id:
			_on_hero_selected(hero)
			return
	push_warning("Se recibió una selección de héroe desconocida: %s" % hero_id)


func _on_hero_selected(hero: Dictionary) -> void:
	profile["nickname"] = checked_nickname
	profile["hero_id"] = hero.id
	profile["hero_name"] = hero.name
	profile["owned_heroes"] = [hero.id]
	profile["onboarding_complete"] = true
	profile["last_seen"] = int(Time.get_unix_time_from_system())
	_save_local_profile()
	_save_cloud_profile()
	_save_session_nickname("")
	_show_npc_dialogue(
		"¡Encantado, %s! Las Tierras de Valoria necesitan héroes como tú para combatir el mal y devolver la prosperidad. %s se unirá a tu viaje." % [checked_nickname, hero.name],
		"Entrar al campamento",
		_enter_camp,
		Page.FAREWELL
	)


func _enter_camp() -> void:
	_build_camp()


func _build_camp() -> void:
	camp_operational = true
	page = Page.CAMP
	for child in page_host.get_children():
		child.queue_free()
	currency_hud.show()
	page_scroll.hide()
	camp_modal_shade.hide()
	camp_world.show()
	camp_world.modulate = Color(1, 1, 1, 0)
	if camp_points.get_child_count() == 0:
		_populate_camp_world()
	var world_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	world_tween.tween_property(camp_world, "modulate", Color.WHITE, 0.34)
	_update_hud()
	_set_status("Refugio del Bosque · Saludos, %s. Las recompensas AFK se acumulan hasta 24 horas." % str(profile.get("nickname", account_name)))
	status_label.show()


func _on_viewport_resized() -> void:
	if is_instance_valid(currency_grid):
		var width := get_viewport_rect().size.x
		currency_grid.columns = 4 if width >= 440.0 else 2
		currency_grid.add_theme_constant_override("h_separation", 12 if width >= 640.0 else 5)
	if is_instance_valid(platformer_stage) and platformer_stage.has_method("_fit_to_viewport"):
		platformer_stage.call_deferred("_fit_to_viewport")


func _populate_camp_world() -> void:
	if is_instance_valid(platformer_stage):
		platformer_stage.queue_free()
	for child in camp_points.get_children():
		child.queue_free()
	platformer_stage = Node2D.new()
	platformer_stage.name = "PlatformerVillage"
	platformer_stage.set_script(PLATFORMER_STAGE_SCRIPT)
	# Configura el héroe antes de añadir el nodo: _ready() construye el escenario
	# y crea al personaje, así evitamos cargar dos veces todas sus texturas.
	platformer_stage.set("active_hero_id", str(_selected_hero().get("id", "guardiana")))
	camp_points.add_child(platformer_stage)
	platformer_stage.connect("interaction_requested", _on_platformer_interaction)


func _on_platformer_interaction(kind: String, destination: Vector2) -> void:
	if not is_instance_valid(platformer_stage):
		return
	var arrived := func() -> void:
		match kind:
			"pve": _open_pve()
			"pvp": _open_pvp()
			"gacha": _open_gacha()
			"chest": _open_chest_rewards()
			"bed": _open_bed_rewards()
			"door":
				var entering := not bool(platformer_stage.get("inside_house"))
				platformer_stage.call("set_interior", entering)
				_set_status("Has entrado en la casa del refugio." if entering else "Has vuelto al campamento exterior.")
	platformer_stage.call("move_hero_to", destination, arrived)


func _add_location_hotspot(title: String, subtitle: String, visual: Control, callback: Callable, anchor: Vector2, hotspot_size := Vector2(176, 148)) -> void:
	var button := Button.new()
	button.name = title.replace(" ", "")
	button.tooltip_text = "%s\n%s" % [title, subtitle]
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = hotspot_size
	button.anchor_left = anchor.x
	button.anchor_right = anchor.x
	button.anchor_top = anchor.y
	button.anchor_bottom = anchor.y
	button.offset_left = -hotspot_size.x * 0.5
	button.offset_right = hotspot_size.x * 0.5
	button.offset_top = -hotspot_size.y * 0.5
	button.offset_bottom = hotspot_size.y * 0.5
	button.pivot_offset = hotspot_size * 0.5
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	button.mouse_entered.connect(_animate_hotspot.bind(button, true))
	button.mouse_exited.connect(_animate_hotspot.bind(button, false))
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)
	visual.custom_minimum_size.y = hotspot_size.y - 30.0
	visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(visual)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12 if hotspot_size.x > 140.0 else 9)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.11, 0.08, 0.04, 1.0))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.clip_text = false
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.custom_minimum_size.x = hotspot_size.x - 8.0
	stack.add_child(title_label)
	camp_points.add_child(button)


func _make_sprite_visual(texture: Texture2D, dimensions: Vector2) -> Control:
	var world_scale := clampf(minf(get_viewport_rect().size.x / 1152.0, get_viewport_rect().size.y / 720.0), 0.62, 1.0)
	var scaled_dimensions := dimensions * world_scale
	var frame := CenterContainer.new()
	frame.custom_minimum_size = scaled_dimensions + Vector2(12, 8)
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.custom_minimum_size = scaled_dimensions
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sprite)
	return frame


func _make_bed_visual(hero_texture: Texture2D, compact := false) -> Control:
	var bed_visual := Control.new()
	var world_scale := clampf(minf(get_viewport_rect().size.x / 1152.0, get_viewport_rect().size.y / 720.0), 0.62, 1.0)
	var bed_size := (Vector2(76, 48) if compact else Vector2(118, 64)) * world_scale
	bed_visual.custom_minimum_size = bed_size
	var bed := ColorRect.new()
	bed.color = Color(0.30, 0.16, 0.08, 1.0)
	bed.custom_minimum_size = bed_size
	bed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed_visual.add_child(bed)
	var mattress := ColorRect.new()
	mattress.color = Color(0.91, 0.77, 0.54, 1.0)
	mattress.position = Vector2(5, 5) * world_scale
	mattress.size = bed_size - Vector2(10, 14) * world_scale
	mattress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed_visual.add_child(mattress)
	var pillow := ColorRect.new()
	pillow.color = Color(1.0, 0.92, 0.73, 1.0)
	pillow.position = Vector2(10, 10) * world_scale
	pillow.size = Vector2(22, bed_size.y / world_scale - 24) * world_scale
	pillow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed_visual.add_child(pillow)
	var sleeper := TextureRect.new()
	sleeper.texture = hero_texture
	sleeper.custom_minimum_size = (Vector2(32, 40) if compact else Vector2(46, 56)) * world_scale
	sleeper.position = Vector2(29, 4) * world_scale
	sleeper.size = sleeper.custom_minimum_size
	sleeper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sleeper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sleeper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sleeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed_visual.add_child(sleeper)
	var sleep_letters := Label.new()
	sleep_letters.text = "Z z"
	sleep_letters.position = Vector2(bed_size.x - 20 * world_scale, -8 * world_scale)
	sleep_letters.add_theme_font_size_override("font_size", 15 if not compact else 11)
	sleep_letters.add_theme_color_override("font_color", Color(1.0, 0.92, 0.66, 1.0))
	sleep_letters.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.05, 1.0))
	sleep_letters.add_theme_constant_override("outline_size", 3)
	sleep_letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed_visual.add_child(sleep_letters)
	return bed_visual


func _make_gacha_machine_visual(compact := false) -> Control:
	var world_scale := clampf(minf(get_viewport_rect().size.x / 1152.0, get_viewport_rect().size.y / 720.0), 0.62, 1.0)
	var machine := CenterContainer.new()
	machine.custom_minimum_size = (Vector2(72, 70) if compact else Vector2(110, 96)) * world_scale
	machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portal_icon := TextureRect.new()
	portal_icon.texture = load(CAMP_GACHA_PORTAL_PATH)
	portal_icon.custom_minimum_size = (Vector2(68, 68) if compact else Vector2(92, 92)) * world_scale
	portal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portal_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine.add_child(portal_icon)
	return machine


func _pve_enemy_texture() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(PVE_GOBLIN_PATH)
	atlas.region = PVE_GOBLIN_REGION
	return atlas


func _selected_hero() -> Dictionary:
	var hero_id := str(profile.get("hero_id", ""))
	for hero in COMMON_HEROES:
		if str(hero.get("id", "")) == hero_id:
			return hero
	for hero in RARE_HEROES:
		if str(hero.get("id", "")) == hero_id:
			return hero
	return COMMON_HEROES[0]


func _animate_hotspot(button: Button, entering: bool) -> void:
	if not is_instance_valid(button):
		return
	var target_scale := Vector2(1.06, 1.06) if entering else Vector2.ONE
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.14)


func _claim_coins() -> void:
	var amount := _offline_reward("coins", 2)
	if amount <= 0:
		_build_camp()
		_set_status("El cofre aún no tiene oro nuevo. Vuelve más tarde.")
		return
	profile["coins"] = int(profile.get("coins", 0)) + amount
	profile["last_coin_claim"] = int(Time.get_unix_time_from_system())
	_save_and_refresh()
	_build_camp()
	_set_status("Has recogido %d monedas de oro." % amount)


func _claim_xp() -> void:
	var amount := _offline_reward("xp", 1)
	if amount <= 0:
		_build_camp()
		_set_status("La cama aún no ha acumulado experiencia nueva. Vuelve más tarde.")
		return
	profile["xp"] = int(profile.get("xp", 0)) + amount
	profile["hero_level"] = 1 + floori(float(profile["xp"]) / 100.0)
	profile["last_xp_claim"] = int(Time.get_unix_time_from_system())
	_save_and_refresh()
	_build_camp()
	_set_status("%s ha ganado %d de experiencia." % [str(profile.get("hero_name", "Tu héroe")), amount])


func _open_chest_rewards() -> void:
	var amount := _offline_reward("coins", 2)
	var view := _panel("Cofre del Alba", Vector2(490, 0))
	var chest_icon := TextureRect.new()
	chest_icon.texture = load(CAMP_CHEST_PATH)
	chest_icon.custom_minimum_size = Vector2(100, 94)
	chest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var icon_center := CenterContainer.new()
	icon_center.add_child(chest_icon)
	view.box.add_child(icon_center)
	_add_body(view.box, "El cofre guarda las monedas que tus exploradores han reunido mientras descansabas.\n\nRecompensa disponible: %d de oro" % amount)
	var claim := _add_button(view.box, "Recoger oro", _claim_coins, true)
	claim.disabled = amount <= 0
	if amount <= 0:
		claim.text = "Aún no hay oro nuevo"
	_add_button(view.box, "Volver al refugio", _build_camp)
	_show_page(Page.CHEST, view.panel)


func _open_bed_rewards() -> void:
	var amount := _offline_reward("xp", 1)
	var hero := _selected_hero()
	var view := _panel("Lecho del héroe", Vector2(520, 0))
	var portrait := TextureRect.new()
	portrait.texture = _hero_portrait_texture(hero)
	portrait.custom_minimum_size = Vector2(98, 100)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var portrait_center := CenterContainer.new()
	portrait_center.add_child(portrait)
	view.box.add_child(portrait_center)
	var xp_total := int(profile.get("xp", 0))
	var hero_level := int(profile.get("hero_level", 1))
	_add_body(view.box, "%s descansa en el piso superior y recupera fuerzas.\n\nNivel %d · %d EXP acumulada\nAl volver: +%d EXP" % [str(hero.get("character_name", hero.get("name", "Héroe"))), hero_level, xp_total, amount])
	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = float(xp_total % 100)
	progress.show_percentage = false
	progress.custom_minimum_size.y = 18
	view.box.add_child(progress)
	var claim := _add_button(view.box, "Recoger experiencia", _claim_xp, true)
	claim.disabled = amount <= 0
	if amount <= 0:
		claim.text = "Aún no hay EXP nueva"
	_add_button(view.box, "Volver al refugio", _build_camp)
	_show_page(Page.BED, view.panel)


func _offline_reward(kind: String, rate_per_minute: int) -> int:
	var claim_key := "last_coin_claim" if kind == "coins" else "last_xp_claim"
	var elapsed := mini(MAX_AFK_SECONDS, maxi(0, int(Time.get_unix_time_from_system()) - int(profile.get(claim_key, profile.get("last_seen", Time.get_unix_time_from_system())))))
	return floori(float(elapsed) / 60.0) * rate_per_minute


func _open_pve() -> void:
	var view := _panel("Aventura PvE", Vector2(700, 0))
	_add_body(view.box, "Las sombras han llegado al bosque. Reconoce al enemigo antes de preparar la expedición.")
	var encounter := HBoxContainer.new()
	encounter.add_theme_constant_override("separation", 20)
	var goblin_center := CenterContainer.new()
	goblin_center.custom_minimum_size = Vector2(190, 190)
	var goblin_texture := TextureRect.new()
	var goblin_atlas := AtlasTexture.new()
	goblin_atlas.atlas = load(PVE_GOBLIN_PATH)
	goblin_atlas.region = PVE_GOBLIN_REGION
	goblin_texture.texture = goblin_atlas
	goblin_texture.custom_minimum_size = Vector2(145, 176)
	goblin_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	goblin_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goblin_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	goblin_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goblin_center.add_child(goblin_texture)
	encounter.add_child(goblin_center)
	var enemy_info := VBoxContainer.new()
	enemy_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var enemy_name := Label.new()
	enemy_name.text = "Duende del bosque"
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_name.add_theme_font_size_override("font_size", 21)
	enemy_info.add_child(enemy_name)
	var enemy_description := Label.new()
	enemy_description.text = "Criatura común · acecha los caminos del bosque."
	enemy_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_info.add_child(enemy_description)
	var effect_caption := Label.new()
	effect_caption.text = "Nube tóxica"
	effect_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_info.add_child(effect_caption)
	var effect_center := CenterContainer.new()
	var smoke_preview := TextureRect.new()
	smoke_preview.custom_minimum_size = Vector2(130, 84)
	smoke_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	smoke_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	smoke_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	smoke_preview.texture = load(PVE_SMOKE_FRAME_PATHS[0])
	smoke_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_center.add_child(smoke_preview)
	enemy_info.add_child(effect_center)
	encounter.add_child(enemy_info)
	view.box.add_child(encounter)
	var stage_heading := Label.new()
	stage_heading.text = "Elige una fase"
	stage_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view.box.add_child(stage_heading)
	var stages := GridContainer.new()
	stages.columns = 1 if get_viewport_rect().size.x < 620.0 else 3
	stages.add_theme_constant_override("h_separation", 8)
	stages.add_theme_constant_override("v_separation", 8)
	view.box.add_child(stages)
	for stage in ["Sendero velado", "Ruinas del arroyo", "Claro de los ecos"]:
		var stage_button := Button.new()
		stage_button.text = stage
		stage_button.theme_type_variation = "PrimaryButton" if stage == "Sendero velado" else "Button"
		stage_button.pressed.connect(_on_stage_selected.bind(stage))
		stage_button.custom_minimum_size = Vector2(0, 54)
		stages.add_child(stage_button)
	_add_button(view.box, "Volver al campamento", _build_camp)
	_show_page(Page.PVE, view.panel)
	pve_effect_frames.clear()
	for frame_path in PVE_SMOKE_FRAME_PATHS:
		var frame := load(frame_path) as Texture2D
		if frame != null:
			pve_effect_frames.append(frame)
	pve_effect_frame_index = 0
	if is_instance_valid(pve_effect_timer):
		pve_effect_timer.queue_free()
	pve_effect_timer = Timer.new()
	pve_effect_timer.wait_time = 0.11
	pve_effect_timer.timeout.connect(_advance_pve_effect.bind(smoke_preview))
	add_child(pve_effect_timer)
	pve_effect_timer.start()


func _advance_pve_effect(preview: TextureRect) -> void:
	if pve_effect_frames.is_empty() or not is_instance_valid(preview):
		return
	pve_effect_frame_index = (pve_effect_frame_index + 1) % pve_effect_frames.size()
	preview.texture = pve_effect_frames[pve_effect_frame_index]


func _on_stage_selected(stage_name: String) -> void:
	_set_status("%s: la expedición se está preparando; el combate por turnos llegará en la siguiente fase." % stage_name)


func _open_pvp() -> void:
	var view := _panel("Arena de Valoria", Vector2(540, 0))
	var knight := TextureRect.new()
	knight.texture = _hero_portrait_texture(COMMON_HEROES[1])
	knight.custom_minimum_size = Vector2(106, 112)
	knight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	knight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	knight.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var knight_center := CenterContainer.new()
	knight_center.add_child(knight)
	view.box.add_child(knight_center)
	_add_body(view.box, "Eldric custodia el círculo de duelo. Entrena con otros aventureros y demuestra el temple de tu escuadrón.")
	var unavailable := _add_button(view.box, "Arena PvP · Próximamente", _on_pvp_queue_pressed)
	unavailable.disabled = true
	_add_button(view.box, "Volver al refugio", _build_camp, true)
	_show_page(Page.PVP, view.panel)


func _on_pvp_queue_pressed() -> void:
	_set_status("El emparejamiento PvP llegará en una próxima actualización.")


func _open_gacha() -> void:
	var view := _panel("Máquina Gacha", Vector2(500, 0))
	var introduction := HBoxContainer.new()
	introduction.add_theme_constant_override("separation", 16)
	var chest_center := CenterContainer.new()
	chest_center.custom_minimum_size = Vector2(110, 110)
	var portal := TextureRect.new()
	portal.texture = load(CAMP_GACHA_PORTAL_PATH)
	portal.custom_minimum_size = Vector2(96, 96)
	portal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chest_center.add_child(portal)
	introduction.add_child(chest_center)
	var gacha_copy := Label.new()
	gacha_copy.text = "Invoca héroes con tickets o diamantes. Cada compañero conseguido se guarda en tu colección."
	gacha_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gacha_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gacha_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	introduction.add_child(gacha_copy)
	view.box.add_child(introduction)
	gacha_feedback = _add_body(view.box, "")
	gacha_feedback.custom_minimum_size.y = 30
	gacha_result_portrait = TextureRect.new()
	gacha_result_portrait.custom_minimum_size = Vector2(104, 104)
	gacha_result_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gacha_result_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gacha_result_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gacha_result_portrait.texture = _hero_portrait_texture(COMMON_HEROES[0])
	gacha_result_portrait.hide()
	var result_center := CenterContainer.new()
	result_center.add_child(gacha_result_portrait)
	view.box.add_child(result_center)
	var common_button := _add_button(view.box, "Invocación común · 1 ticket", _summon.bind("tickets"), true)
	common_button.icon = load(CURRENCY_ICON_PATHS["tickets"])
	common_button.icon_max_width = 28
	var premium_button := _add_button(view.box, "Invocación especial · 1 ticket", _summon.bind("premium_tickets"))
	premium_button.icon = load(CURRENCY_ICON_PATHS["premium_tickets"])
	premium_button.icon_max_width = 28
	var diamond_button := _add_button(view.box, "Invocación con diamantes · 100", _summon.bind("diamonds"))
	diamond_button.icon = load(CURRENCY_ICON_PATHS["diamonds"])
	diamond_button.icon_max_width = 28
	_add_button(view.box, "Volver al campamento", _build_camp)
	_show_page(Page.GACHA, view.panel)


func _summon(currency: String) -> void:
	var cost := 100 if currency == "diamonds" else 1
	if int(profile.get(currency, 0)) < cost:
		var currency_name := "diamantes" if currency == "diamonds" else "esencias" if currency == "premium_tickets" else "tickets"
		gacha_feedback.text = "No tienes %s suficientes." % currency_name
		return
	profile[currency] = int(profile[currency]) - cost
	var pool: Array = COMMON_HEROES if currency == "tickets" else RARE_HEROES
	var hero: Dictionary = pool[randi() % pool.size()]
	var owned: Array = profile.get("owned_heroes", [])
	var is_duplicate: bool = owned.has(str(hero.get("id", "")))
	if not is_duplicate:
		owned.append(hero.id)
		profile["owned_heroes"] = owned
	else:
		profile["coins"] = int(profile.get("coins", 0)) + 50
	profile["summons"] = int(profile.get("summons", 0)) + 1
	_save_and_refresh()
	gacha_feedback.text = "¡Invocación épica! %s se une a tu colección.%s" % [hero.name, " Repetido: recibes 50 monedas." if is_duplicate else ""]
	if is_instance_valid(gacha_result_portrait):
		gacha_result_portrait.texture = _hero_portrait_texture(hero)
		gacha_result_portrait.show()


func _open_settings() -> void:
	var view := _panel("Cuenta y ajustes", Vector2(480, 0))
	_add_body(view.box, "Aventurero: %s\nCuenta Supabase: %s\nID: %s" % [str(profile.get("nickname", account_name)), str(SupabaseManager.current_user.get("email", "")), account_uid])
	var google_linked := SupabaseManager.has_google_identity()
	_add_body(view.box, "Cuenta de Google: %s" % ("Enlazada" if google_linked else "Sin enlazar"))
	google_link_button = _add_button(view.box, "Google enlazado ✓" if google_linked else "Enlazar con Google", _on_google_link_pressed, not google_linked)
	google_link_button.disabled = google_linked or not SupabaseManager.is_authenticated
	_add_audio_slider(view.box, "Volumen general", &"Master")
	_add_audio_slider(view.box, "Música", &"Music")
	_add_audio_slider(view.box, "Efectos", &"SFX")
	_add_button(view.box, "Cerrar sesión", _sign_out)
	_add_button(view.box, "Volver al campamento", _build_camp, true)
	_show_page(Page.SETTINGS, view.panel)


func _on_google_link_pressed() -> void:
	_set_status("Conectando la cuenta con Google…")
	if is_instance_valid(google_link_button):
		google_link_button.disabled = true
	SupabaseManager.link_google_identity()


func _on_supabase_auth_completed(action: String, success: bool, result: Dictionary) -> void:
	if action != "google_link":
		return
	if is_instance_valid(google_link_button):
		google_link_button.disabled = success or SupabaseManager.has_google_identity()
	if success:
		_set_status("Tu cuenta de Google se ha enlazado correctamente.")
	else:
		_set_status(str(result.get("message", "No se pudo enlazar Google.")))


func _add_audio_slider(parent: VBoxContainer, title: String, bus_name: StringName) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 144
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		slider.value = 0 if AudioServer.is_bus_mute(bus_index) else db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
	slider.value_changed.connect(_on_audio_setting_changed.bind(bus_name))
	row.add_child(slider)
	parent.add_child(row)


func _on_audio_setting_changed(value: float, bus_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, is_zero_approx(value))
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value / 100.0, 0.0001)))


func _sign_out() -> void:
	SupabaseManager.sign_out()
	var error := get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	if error != OK:
		push_error("No se pudo volver al menú principal (%d)." % error)


func _save_and_refresh() -> void:
	_update_hud()
	_save_local_profile()
	_save_cloud_profile()


func _update_hud() -> void:
	for key in currency_labels:
		currency_labels[key].text = _format_number(int(profile.get(key, 0)))
	if is_instance_valid(profile_name_label):
		var nickname := str(profile.get("nickname", account_name)).strip_edges()
		profile_name_label.text = nickname if not nickname.is_empty() else account_name
	if is_instance_valid(profile_level_label):
		profile_level_label.text = "Nivel %d · %s" % [int(profile.get("hero_level", 1)), str(profile.get("hero_name", "Aventurero"))]
	if is_instance_valid(profile_portrait):
		profile_portrait.texture = _hero_portrait_texture(_selected_hero())


func _format_number(value: int) -> String:
	if value >= 1000000:
		return "%.1f M" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1f K" % (float(value) / 1000.0)
	return str(value)


func _profile_defaults() -> Dictionary:
	return {"nickname": "", "hero_id": "", "hero_name": "", "onboarding_complete": false,
		"hero_level": 1, "coins": 500, "tickets": 10, "diamonds": 100, "premium_tickets": 1, "xp": 0, "summons": 0,
		"owned_heroes": [], "last_seen": int(Time.get_unix_time_from_system()), "last_coin_claim": int(Time.get_unix_time_from_system()),
		"last_xp_claim": int(Time.get_unix_time_from_system())}


func _load_profile() -> void:
	profile = _profile_defaults()
	var config := ConfigFile.new()
	if config.load(LOCAL_PROFILE_PATH) == OK:
		var stored: Variant = config.get_value("profiles", account_uid, {})
		if stored is Dictionary:
			for key in stored:
				profile[key] = stored[key]
	_apply_session_metadata()
	_update_hud()


func _apply_session_metadata() -> void:
	if not str(profile.get("nickname", "")).is_empty():
		return
	var metadata := ConfigFile.new()
	if metadata.load(LOCAL_PROFILE_PATH) != OK:
		return
	var session_data: Variant = metadata.get_value("session_metadata", account_uid, {})
	if session_data is Dictionary and not str(session_data.get("nickname", "")).is_empty():
		profile["nickname"] = str(session_data["nickname"])


func _save_local_profile() -> bool:
	var config := ConfigFile.new()
	config.load(LOCAL_PROFILE_PATH)
	config.set_value("profiles", account_uid, profile)
	var error := config.save(LOCAL_PROFILE_PATH)
	if error != OK:
		push_warning("No se pudo guardar la caché local del perfil (%d)." % error)
	return error == OK


func _load_cloud_profile() -> void:
	if account_uid == "guest" or not SupabaseManager.is_authenticated:
		_set_status("No hay sesión de Supabase. El perfil se guardará en este dispositivo.")
		_begin_onboarding_or_camp()
		return
	if not SupabaseManager.load_profile() and not SupabaseManager.is_busy:
		_set_status("No se pudo solicitar el perfil remoto. Se usará la copia local.")
		_begin_onboarding_or_camp()


func _on_supabase_profile_loaded(success: bool, cloud_profile: Dictionary, message: String) -> void:
	if success:
		if cloud_profile.is_empty():
			_set_status("Perfil nuevo. El nickname y el progreso se sincronizarán con Supabase.")
		else:
			for key in cloud_profile:
				if profile.has(key):
					profile[key] = cloud_profile[key]
			_set_status("")
		_save_local_profile()
		_update_hud()
		_begin_onboarding_or_camp()
		return
	_set_status("No se pudo sincronizar con Supabase: %s. Se usará la copia local." % message)
	_begin_onboarding_or_camp()


func _begin_onboarding_or_camp() -> void:
	if bool(profile.get("onboarding_complete", false)):
		var elapsed := mini(MAX_AFK_SECONDS, maxi(0, int(Time.get_unix_time_from_system()) - int(profile.get("last_seen", Time.get_unix_time_from_system()))))
		if elapsed >= 60:
			_set_status("Has vuelto al campamento. Se han acumulado recompensas AFK.")
		_build_camp()
	else:
		_show_intro()


func _save_cloud_profile() -> void:
	if account_uid == "guest" or not SupabaseManager.is_authenticated:
		return
	if SupabaseManager.is_busy:
		profile_save_pending = true
		return
	if not SupabaseManager.save_profile(profile):
		profile_save_pending = SupabaseManager.is_busy
		if not SupabaseManager.is_busy:
			_set_status("El progreso está guardado localmente, pero Supabase no pudo recibirlo.")


func _on_supabase_profile_saved(success: bool, saved_profile: Dictionary, message: String) -> void:
	if success:
		for key in saved_profile:
			if profile.has(key):
				profile[key] = saved_profile[key]
		_save_local_profile()
	else:
		_set_status("Progreso guardado localmente. No se pudo sincronizar con Supabase: %s" % message)
	if profile_save_pending and not SupabaseManager.is_busy:
		call_deferred("_flush_pending_cloud_save")


func _flush_pending_cloud_save() -> void:
	if not profile_save_pending or SupabaseManager.is_busy:
		return
	profile_save_pending = false
	_save_cloud_profile()


func _set_status(message: String) -> void:
	last_status = message
	if is_instance_valid(status_label):
		status_label.text = message

