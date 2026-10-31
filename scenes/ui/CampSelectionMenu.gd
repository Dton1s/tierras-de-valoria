extends Control
## Menú de campamento con perfil, ajustes y sesión de Supabase.

@onready var camp_panel: PanelContainer = %CampPanel
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var session_feedback: Label = %SessionFeedback
@onready var account_name: Label = %AccountName
@onready var account_email: Label = %AccountEmail
@onready var account_id: Label = %AccountId
@onready var settings_account_name: Label = %SettingsAccountName
@onready var settings_account_email: Label = %SettingsAccountEmail
@onready var settings_account_id: Label = %SettingsAccountId
@onready var master_volume: HSlider = %MasterVolume
@onready var music_volume: HSlider = %MusicVolume
@onready var sfx_volume: HSlider = %SFXVolume
@onready var window_mode: OptionButton = %WindowMode


func _ready() -> void:
	%EnterHubButton.pressed.connect(_on_enter_hub_pressed)
	%OpenSettingsButton.pressed.connect(_show_settings)
	%DisconnectButton.pressed.connect(_on_disconnect_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%SettingsBackButton.pressed.connect(_show_camp)
	master_volume.value_changed.connect(_on_volume_changed.bind(&"Master", %MasterValue))
	music_volume.value_changed.connect(_on_volume_changed.bind(&"Music", %MusicValue))
	sfx_volume.value_changed.connect(_on_volume_changed.bind(&"SFX", %SFXValue))
	window_mode.item_selected.connect(_on_window_mode_selected)
	_sync_account_info()
	_sync_settings()
	_show_transient_login_feedback()
	%EnterHubButton.grab_focus.call_deferred()


func _sync_account_info() -> void:
	var user := SupabaseManager.current_user
	var metadata: Dictionary = user.get("user_metadata", {})
	var display_name := str(metadata.get("display_name", "")).strip_edges()
	var email := str(user.get("email", ""))
	if display_name.is_empty():
		display_name = email if not email.is_empty() else "Aventurero"
	var id_text := "ID de cuenta: %s" % str(user.get("id", "No disponible"))
	account_name.text = display_name
	account_email.text = email
	account_email.visible = not email.is_empty()
	account_id.text = id_text
	settings_account_name.text = display_name
	settings_account_email.text = email
	settings_account_email.visible = not email.is_empty()
	settings_account_id.text = id_text


func _show_transient_login_feedback() -> void:
	if SupabaseManager.transient_auth_notice.is_empty():
		session_feedback.hide()
		return
	session_feedback.text = SupabaseManager.transient_auth_notice
	session_feedback.show()
	SupabaseManager.transient_auth_notice = ""
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 12.0
	add_child(timer)
	timer.timeout.connect(_clear_transient_login_feedback)
	timer.start()


func _clear_transient_login_feedback() -> void:
	session_feedback.text = ""
	session_feedback.hide()


func _show_camp() -> void:
	settings_panel.hide()
	camp_panel.show()
	%EnterHubButton.grab_focus.call_deferred()


func _show_settings() -> void:
	_sync_account_info()
	_sync_settings()
	camp_panel.hide()
	settings_panel.show()
	%SettingsBackButton.grab_focus.call_deferred()


func _on_enter_hub_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/game/CampHub.tscn")
	if error != OK:
		push_error("No se pudo abrir el campamento de Tierras de Valoria (%d)." % error)


func _on_disconnect_pressed() -> void:
	SupabaseManager.sign_out()
	var scene_error := get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	if scene_error != OK:
		push_error("No se pudo volver al menú principal (código %d)." % scene_error)


func _on_quit_pressed() -> void:
	get_tree().quit()


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
