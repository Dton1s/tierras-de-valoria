extends Control
## Menú inicial. Login y registro usan Supabase Auth REST.
## Los ajustes se aplican a esta sesion; todavia no se guardan en disco.

@onready var base_panel: PanelContainer = %BasePanel
@onready var login_panel: PanelContainer = %LoginPanel
@onready var register_panel: PanelContainer = %RegisterPanel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var pages: VBoxContainer = %Pages
@onready var scroll: ScrollContainer = %Scroll
@onready var login_account: LineEdit = %LoginAccount
@onready var login_password: LineEdit = %LoginPassword
@onready var register_account: LineEdit = %RegisterAccount
@onready var register_email: LineEdit = %RegisterEmail
@onready var register_password: LineEdit = %RegisterPassword
@onready var login_status: Label = %LoginStatus
@onready var register_status: Label = %RegisterStatus
@onready var login_submit: Button = %LoginSubmit
@onready var register_submit: Button = %RegisterSubmit
@onready var google_login_button: Button = %GoogleLogin
@onready var google_register_button: Button = %GoogleRegister
@onready var master_volume: HSlider = %MasterVolume
@onready var music_volume: HSlider = %MusicVolume
@onready var sfx_volume: HSlider = %SFXVolume
@onready var window_mode: OptionButton = %WindowMode
@onready var _panels: Array[Control] = [base_panel, login_panel, register_panel, settings_panel]


func _ready() -> void:
	login_status.hide()
	register_status.hide()
	login_password.text_submitted.connect(_on_login_enter)
	register_password.text_submitted.connect(_on_register_enter)
	master_volume.value_changed.connect(_on_volume_changed.bind(&"Master", %MasterValue))
	music_volume.value_changed.connect(_on_volume_changed.bind(&"Music", %MusicValue))
	sfx_volume.value_changed.connect(_on_volume_changed.bind(&"SFX", %SFXValue))
	window_mode.item_selected.connect(_on_window_mode_selected)
	scroll.resized.connect(_resize_pages)
	_sync_settings()
	_resize_pages()
	_show_panel(base_panel)
	# Las señales de navegación ya están declaradas en MainMenu.tscn. Conecta
	# Supabase al final para que un fallo del autoload no deje la pantalla muda.
	if is_instance_valid(SupabaseManager) and not SupabaseManager.auth_completed.is_connected(_on_supabase_auth_completed):
		SupabaseManager.auth_completed.connect(_on_supabase_auth_completed)
	if is_instance_valid(SupabaseManager) and SupabaseManager.is_authenticated:
		_continue_to_camp.call_deferred()
	print("[MainMenu] Listo; botones de navegación conectados desde la escena.")


func _on_open_login_pressed() -> void:
	_show_panel(login_panel)


func _on_open_register_pressed() -> void:
	_show_panel(register_panel)


func _on_open_settings_pressed() -> void:
	_show_panel(settings_panel)


func _on_login_back_pressed() -> void:
	_show_panel(base_panel)


func _on_register_back_pressed() -> void:
	_show_panel(base_panel)


func _on_settings_back_pressed() -> void:
	_show_panel(base_panel)


func _show_panel(panel: Control) -> void:
	for current in _panels:
		current.hide()
	panel.show()
	scroll.scroll_vertical = 0
	# No conservar contrasenas al abandonar los formularios.
	if panel != login_panel:
		login_password.clear()
	if panel != register_panel:
		register_password.clear()
	var first_control: Control = %OpenLogin
	if panel == login_panel:
		first_control = login_account
	elif panel == register_panel:
		first_control = register_account
	elif panel == settings_panel:
		_sync_settings()
		first_control = master_volume
	first_control.grab_focus.call_deferred()


func _resize_pages() -> void:
	# El ancho procede del area disponible, no de coordenadas absolutas.
	# Scroll mantiene accesibles los controles cuando falta altura.
	pages.custom_minimum_size.x = minf(440.0, maxf(0.0, scroll.size.x - 16.0))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not base_panel.visible:
		_show_panel(base_panel)
		get_viewport().set_input_as_handled()


func _on_login_submit() -> void:
	var email := login_account.text.strip_edges()
	if email.is_empty() or login_password.text.is_empty():
		_show_auth_status(login_status, "Escribe tu correo y contraseña.", true)
		return
	if not email.contains("@"):
		_show_auth_status(login_status, "Escribe el correo electrónico de tu cuenta.", true)
		return
	login_status.hide()
	login_submit.disabled = true
	if not SupabaseManager.sign_in(email, login_password.text):
		login_submit.disabled = false


func _on_register_submit() -> void:
	var account_name := register_account.text.strip_edges()
	var email := register_email.text.strip_edges()
	var password := register_password.text
	if account_name.is_empty() or email.is_empty() or password.is_empty():
		_show_auth_status(register_status, "Completa el nombre de cuenta, el correo y la contraseña.", true)
		return
	register_status.hide()
	register_submit.disabled = true
	if not SupabaseManager.create_account(email, password, account_name):
		register_submit.disabled = false


func _on_google_login_pressed() -> void:
	_start_google_auth("google_login", login_status, google_login_button)


func _on_google_register_pressed() -> void:
	_start_google_auth("google_register", register_status, google_register_button)


func _start_google_auth(action: String, status: Label, button: Button) -> void:
	status.hide()
	button.disabled = true
	if not SupabaseManager.sign_in_with_google(action):
		button.disabled = false


func _on_supabase_auth_completed(action: String, success: bool, result: Dictionary) -> void:
	var is_register_action := action in ["register", "google_register"]
	var status: Label = register_status if is_register_action else login_status
	login_submit.disabled = SupabaseManager.is_busy
	register_submit.disabled = SupabaseManager.is_busy
	google_login_button.disabled = SupabaseManager.is_busy
	google_register_button.disabled = SupabaseManager.is_busy
	if success:
		if bool(result.get("needs_confirmation", false)):
			_show_auth_status(status, str(result.get("message", "Cuenta creada. Confirma tu correo y luego inicia sesión.")), false)
			return
		var user: Dictionary = result.get("user", result)
		var metadata: Dictionary = user.get("user_metadata", {})
		var username := str(metadata.get("display_name", ""))
		var email := str(user.get("email", ""))
		var account_name := username if not username.is_empty() else email
		_show_auth_status(status, "Autenticación correcta.\n%s" % account_name, false)
		print("[Supabase] Autenticación correcta. Usuario: %s" % account_name)
	else:
		_show_auth_status(status, str(result.get("message", "No se pudo completar la autenticación.")), true)
		print("[Supabase] Error de autenticación: %s" % str(result.get("message", "Error desconocido")))
	if action == "google_link" and success:
		SupabaseManager.return_to_camp_hub_after_oauth = false
		SupabaseManager.transient_auth_notice = "Tu cuenta de Google se ha enlazado correctamente."
		_continue_to_hub()
		return
	if action == "restore_session" and success and SupabaseManager.return_to_camp_hub_after_oauth:
		SupabaseManager.return_to_camp_hub_after_oauth = false
		_continue_to_hub()
		return
	if action in ["login", "register", "google_login", "google_register", "restore_session"] and success:
		login_password.clear()
		register_password.clear()
		SupabaseManager.transient_auth_notice = (
			"Bienvenido a Valoria, %s" % _get_user_display_name(result)
		)
		_continue_to_camp()


func _get_user_display_name(user: Dictionary) -> String:
	var account: Dictionary = user.get("user", user)
	var metadata: Dictionary = account.get("user_metadata", {})
	var display_name := str(metadata.get("display_name", metadata.get("full_name", metadata.get("name", "")))).strip_edges()
	if display_name.is_empty():
		display_name = str(account.get("email", ""))
	return display_name


func _continue_to_camp() -> void:
	if get_tree().current_scene != self:
		return
	var scene_error := get_tree().change_scene_to_file("res://scenes/ui/CampSelectionMenu.tscn")
	if scene_error != OK:
		SupabaseManager.transient_auth_notice = ""
		_show_auth_status(login_status, "La cuenta se inició, pero no se pudo abrir el campamento.", true)


func _continue_to_hub() -> void:
	var scene_error := get_tree().change_scene_to_file("res://scenes/game/CampHub.tscn")
	if scene_error != OK:
		SupabaseManager.transient_auth_notice = ""
		_show_auth_status(login_status, "La cuenta se enlazó, pero no se pudo abrir el campamento.", true)


func _show_auth_status(label: Label, message: String, is_error: bool) -> void:
	label.text = message
	label.add_theme_color_override(
		"font_color",
		Color(0.62, 0.13, 0.10, 1) if is_error else Color(0.14, 0.38, 0.19, 1)
	)
	label.show()


func _on_login_enter(_text: String) -> void:
	_on_login_submit()


func _on_register_enter(_text: String) -> void:
	_on_register_submit()


func _sync_settings() -> void:
	_sync_volume(master_volume, %MasterValue, &"Master")
	_sync_volume(music_volume, %MusicValue, &"Music")
	_sync_volume(sfx_volume, %SFXValue, &"SFX")
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	window_mode.select(0 if fullscreen else 1)


func _sync_volume(slider: HSlider, value_label: Label, bus_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var volume := 0.0 if AudioServer.is_bus_mute(bus_index) else db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
	slider.set_value_no_signal(volume)
	value_label.text = "%d %%" % roundi(slider.value)


func _on_volume_changed(value: float, bus_name: StringName, value_label: Label) -> void:
	value_label.text = "%d %%" % roundi(value)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, is_zero_approx(value))
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value / 100.0, 0.0001)))


func _on_window_mode_selected(index: int) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if index == 0 else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

