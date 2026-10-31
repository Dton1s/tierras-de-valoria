extends Node
## Cliente REST ligero de Supabase Auth y la tabla player_profiles.

signal auth_completed(action: String, success: bool, result: Dictionary)
signal auth_state_changed(is_authenticated: bool, user: Dictionary)
signal profile_loaded(success: bool, profile: Dictionary, message: String)
signal profile_saved(success: bool, profile: Dictionary, message: String)

const CONFIG = preload("res://supabase_config.gd")
const AUTH_URL := CONFIG.PROJECT_URL + "/auth/v1"
const REST_URL := CONFIG.PROJECT_URL + "/rest/v1/player_profiles"
const SESSION_PATH := "user://valoria_supabase_session.cfg"
const REQUEST_TIMEOUT := 20.0
const GOOGLE_ACTIONS := ["google_login", "google_register"]

var is_busy := false
var is_authenticated := false
var access_token := ""
var refresh_token := ""
var current_user: Dictionary = {}
var transient_auth_notice := ""
var return_to_camp_hub_after_oauth := false

var _request: HTTPRequest
var _active_kind := ""
var _active_action := ""
var _pending_profile: Dictionary = {}
var _expires_at := 0
var _after_refresh := ""


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.timeout = REQUEST_TIMEOUT
	_request.use_threads = true
	# Supabase can return gzip data that Godot's web runtime fails to inflate.
	# Ask for an uncompressed response for profile reads and writes.
	_request.accept_gzip = false
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	if not _resume_google_oauth_callback():
		_restore_saved_session()


func _current_app_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var browser_window = JavaScriptBridge.get_interface("window")
	return str(browser_window.location.origin) + str(browser_window.location.pathname)


func _navigate_browser_to(destination: String) -> void:
	if not OS.has_feature("web"):
		return
	var browser_window = JavaScriptBridge.get_interface("window")
	browser_window.location.assign(destination)


func create_account(email: String, password: String, display_name: String) -> bool:
	return _start_auth_request("register", "/signup", {
		"email": email.strip_edges().to_lower(),
		"password": password,
		"data": {"display_name": display_name.strip_edges()},
	})


func sign_in(email: String, password: String) -> bool:
	return _start_auth_request("login", "/token?grant_type=password", {
		"email": email.strip_edges().to_lower(),
		"password": password,
	})


func sign_in_with_google(action: String) -> bool:
	if action not in GOOGLE_ACTIONS:
		auth_completed.emit(action, false, {"message": "Acción de Google no válida."})
		return false
	if is_busy:
		auth_completed.emit(action, false, {"message": "Ya hay una solicitud en curso. Espera un momento."})
		return false
	if not OS.has_feature("web"):
		auth_completed.emit(action, false, {"message": "El acceso con Google está disponible en la versión web del juego."})
		return false

	var app_url := _current_app_url()
	if not app_url.begins_with("https://") and not app_url.begins_with("http://localhost") and not app_url.begins_with("http://127.0.0.1"):
		auth_completed.emit(action, false, {"message": "Abre Valoria desde su dirección web para continuar con Google."})
		return false

	var verifier := _new_pkce_verifier()
	var challenge := _pkce_challenge(verifier)
	_save_pending_oauth(action, verifier)
	var authorize_url := AUTH_URL + "/authorize?provider=google"
	authorize_url += "&scopes=" + "openid email profile".uri_encode()
	authorize_url += "&redirect_to=" + app_url.uri_encode()
	authorize_url += "&code_challenge=" + challenge.uri_encode()
	authorize_url += "&code_challenge_method=s256"
	_navigate_browser_to(authorize_url)
	return true


func has_google_identity() -> bool:
	var identities: Variant = current_user.get("identities", [])
	if identities is Array:
		for identity in identities:
			if identity is Dictionary and str(identity.get("provider", "")).to_lower() == "google":
				return true
	var app_metadata: Dictionary = current_user.get("app_metadata", {})
	var providers: Variant = app_metadata.get("providers", [])
	if providers is Array:
		return providers.has("google")
	return false


func link_google_identity() -> bool:
	if not is_authenticated:
		auth_completed.emit("google_link", false, {"message": "Inicia sesión antes de enlazar Google."})
		return false
	if has_google_identity():
		auth_completed.emit("google_link", false, {"message": "Esta cuenta ya está enlazada con Google."})
		return false
	if is_busy:
		auth_completed.emit("google_link", false, {"message": "Ya hay una solicitud en curso. Espera un momento."})
		return false
	if not OS.has_feature("web"):
		auth_completed.emit("google_link", false, {"message": "El enlace con Google está disponible en la versión web del juego."})
		return false
	if _session_needs_refresh():
		_after_refresh = "google_link"
		return _refresh_session()
	return _begin_google_identity_link()


func _begin_google_identity_link() -> bool:
	var app_url := _current_app_url()
	if not app_url.begins_with("https://") and not app_url.begins_with("http://localhost") and not app_url.begins_with("http://127.0.0.1"):
		auth_completed.emit("google_link", false, {"message": "Abre Valoria desde su dirección web para enlazar Google."})
		return false
	var verifier := _new_pkce_verifier()
	var challenge := _pkce_challenge(verifier)
	_save_pending_oauth("google_link", verifier)
	var authorize_url := AUTH_URL + "/user/identities/authorize?provider=google"
	authorize_url += "&skip_http_redirect=true"
	authorize_url += "&scopes=" + "openid email profile".uri_encode()
	authorize_url += "&redirect_to=" + app_url.uri_encode()
	authorize_url += "&code_challenge=" + challenge.uri_encode()
	authorize_url += "&code_challenge_method=s256"
	_active_kind = "oauth_link_authorize"
	_active_action = "google_link"
	is_busy = true
	return _request_json(authorize_url, HTTPClient.METHOD_GET, {}, true)


func sign_out() -> void:
	access_token = ""
	refresh_token = ""
	_expires_at = 0
	current_user.clear()
	is_authenticated = false
	transient_auth_notice = ""
	var saved_session := ConfigFile.new()
	saved_session.set_value("session", "refresh_token", "")
	saved_session.save(SESSION_PATH)
	auth_state_changed.emit(false, {})


func load_profile() -> bool:
	if not is_authenticated or str(current_user.get("id", "")).is_empty():
		profile_loaded.emit(false, {}, "Inicia sesión para sincronizar tu perfil.")
		return false
	if is_busy:
		profile_loaded.emit(false, {}, "Hay otra solicitud en curso. Inténtalo de nuevo en unos segundos.")
		return false
	if _session_needs_refresh():
		_after_refresh = "load_profile"
		return _refresh_session()
	return _send_profile_request("load_profile")


func save_profile(profile: Dictionary) -> bool:
	if not is_authenticated or str(current_user.get("id", "")).is_empty():
		profile_saved.emit(false, {}, "Inicia sesión para guardar el perfil en la nube.")
		return false
	if is_busy:
		return false
	_pending_profile = _to_database_profile(profile)
	_pending_profile["user_id"] = str(current_user["id"])
	if _session_needs_refresh():
		_after_refresh = "save_profile"
		return _refresh_session()
	return _send_profile_request("save_profile")


func _start_auth_request(action: String, endpoint: String, payload: Dictionary) -> bool:
	if is_busy:
		auth_completed.emit(action, false, {"message": "Ya hay una solicitud en curso. Espera un momento."})
		return false
	_active_action = action
	_active_kind = "auth"
	is_busy = true
	return _request_json(AUTH_URL + endpoint, HTTPClient.METHOD_POST, payload, false)


func _restore_saved_session() -> void:
	var config := ConfigFile.new()
	if config.load(SESSION_PATH) != OK:
		return
	refresh_token = str(config.get_value("session", "refresh_token", ""))
	if refresh_token.is_empty():
		return
	_active_action = "restore_session"
	_active_kind = "refresh_session"
	is_busy = true
	if not _request_json(AUTH_URL + "/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": refresh_token}, false):
		_clear_session()


func _resume_google_oauth_callback() -> bool:
	if not OS.has_feature("web"):
		return false
	var browser_window = JavaScriptBridge.get_interface("window")
	var current_url := str(browser_window.location.href)
	var query_start := current_url.find("?")
	if query_start < 0:
		return false
	var query := current_url.substr(query_start + 1)
	var fragment_start := query.find("#")
	if fragment_start >= 0:
		query = query.substr(0, fragment_start)
	var params := _parse_url_params(query)
	if not params.has("code") and not params.has("error"):
		return false

	var pending := ConfigFile.new()
	pending.load(SESSION_PATH)
	var action := str(pending.get_value("oauth", "action", "google_login"))
	var verifier := str(pending.get_value("oauth", "verifier", ""))
	_clear_pending_oauth()
	var clean_url := str(browser_window.location.origin) + str(browser_window.location.pathname)
	browser_window.history.replaceState(JavaScriptBridge.create_object("Object"), str(browser_window.document.title), clean_url)

	if params.has("error"):
		var oauth_error := str(params.get("error_description", params.get("error", "error desconocido")))
		oauth_error = oauth_error.replace("+", " ").uri_decode()
		if str(params.get("error", "")) == "access_denied":
			oauth_error = "Has cancelado el acceso con Google."
		if action == "google_link":
			return_to_camp_hub_after_oauth = true
			transient_auth_notice = "No se completó el enlace con Google: %s" % oauth_error
			_restore_saved_session()
		call_deferred("_emit_google_oauth_failure", action, oauth_error)
		return true
	if verifier.is_empty():
		call_deferred("_emit_google_oauth_failure", action, "No se encontró la verificación temporal de Google. Vuelve a intentarlo.")
		return true

	_active_kind = "auth"
	_active_action = action
	is_busy = true
	_request_json(AUTH_URL + "/token?grant_type=pkce", HTTPClient.METHOD_POST, {
		"auth_code": str(params.get("code", "")),
		"code_verifier": verifier,
	}, false)
	return true


func _emit_google_oauth_failure(action: String, message: String) -> void:
	auth_completed.emit(action, false, {"message": message})


func _parse_url_params(query: String) -> Dictionary:
	var result := {}
	for pair in query.split("&", false):
		var separator := pair.find("=")
		if separator < 0:
			continue
		var key := pair.substr(0, separator).uri_decode()
		var value := pair.substr(separator + 1).replace("+", " ").uri_decode()
		result[key] = value
	return result


func _new_pkce_verifier() -> String:
	var crypto := Crypto.new()
	return Marshalls.raw_to_base64(crypto.generate_random_bytes(32)).replace("+", "-").replace("/", "_").trim_suffix("=")


func _pkce_challenge(verifier: String) -> String:
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(verifier.to_utf8_buffer())
	return Marshalls.raw_to_base64(hash_context.finish()).replace("+", "-").replace("/", "_").trim_suffix("=")


func _save_pending_oauth(action: String, verifier: String) -> void:
	var config := ConfigFile.new()
	config.load(SESSION_PATH)
	config.set_value("oauth", "action", action)
	config.set_value("oauth", "verifier", verifier)
	config.save(SESSION_PATH)


func _clear_pending_oauth() -> void:
	var config := ConfigFile.new()
	config.load(SESSION_PATH)
	config.set_value("oauth", "action", "")
	config.set_value("oauth", "verifier", "")
	config.save(SESSION_PATH)


func _refresh_session() -> bool:
	if refresh_token.is_empty():
		return _fail_profile_after_refresh("La sesión ha caducado. Inicia sesión de nuevo para sincronizar tu progreso.")
	if is_busy:
		return false
	_active_action = "refresh_session"
	_active_kind = "refresh_session"
	is_busy = true
	if not _request_json(AUTH_URL + "/token?grant_type=refresh_token", HTTPClient.METHOD_POST, {"refresh_token": refresh_token}, false):
		_clear_session()
		return false
	return true


func _send_profile_request(kind: String) -> bool:
	_active_kind = kind
	_active_action = kind
	is_busy = true
	var user_id := str(current_user.get("id", ""))
	if kind == "load_profile":
		var url := REST_URL + "?select=*&user_id=eq." + user_id.uri_encode()
		return _request_json(url, HTTPClient.METHOD_GET, {}, true)
	var url := REST_URL + "?on_conflict=user_id"
	return _request_json(url, HTTPClient.METHOD_POST, _pending_profile, true, ["Prefer: resolution=merge-duplicates,return=representation"])


func _request_json(url: String, method: HTTPClient.Method, payload: Dictionary, use_user_token: bool, extra_headers: PackedStringArray = []) -> bool:
	var headers := PackedStringArray([
		"apikey: " + CONFIG.PUBLISHABLE_KEY,
		"Content-Type: application/json",
		"Authorization: Bearer " + (access_token if use_user_token else CONFIG.PUBLISHABLE_KEY),
	])
	for header in extra_headers:
		headers.append(header)
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var error := _request.request(url, headers, method, body)
	if error != OK:
		var message := "No se pudo iniciar la conexión con Supabase (código %d)." % error
		_finish_request_failure(message)
		return false
	return true


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response: Variant = _parse_response(body)
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_request_failure("No se pudo conectar con Supabase. Comprueba tu conexión e inténtalo de nuevo.")
		return
	if response_code < 200 or response_code >= 300:
		_finish_request_failure(_friendly_error(response, response_code))
		return
	match _active_kind:
		"auth":
			if _active_action == "register" and str(response.get("access_token", "")).is_empty():
				var confirm_message := "Cuenta creada. Revisa tu correo para confirmar la dirección y después inicia sesión."
				_clear_busy()
				auth_completed.emit("register", true, {"needs_confirmation": true, "message": confirm_message})
				return
			_complete_auth(response, _active_action)
		"refresh_session":
			if str(response.get("access_token", "")).is_empty():
				var failed_action := _active_action
				_clear_session()
				_clear_busy()
				if failed_action == "restore_session":
					auth_state_changed.emit(false, {})
				else:
					_fail_profile_after_refresh("La sesión caducó. Inicia sesión otra vez para sincronizar tu progreso.")
				return
			_complete_auth(response, "restore_session" if _active_action == "restore_session" else "refresh_session")
			_resume_after_refresh()
		"load_profile":
			var loaded_profile := _response_first_row(response)
			_clear_busy()
			profile_loaded.emit(true, loaded_profile, "")
		"save_profile":
			var saved_profile := _response_first_row(response)
			if saved_profile.is_empty():
				saved_profile = _pending_profile.duplicate(true)
			_clear_busy()
			_pending_profile.clear()
			profile_saved.emit(true, saved_profile, "")
		"oauth_link_authorize":
			var authorize_url := str(response.get("url", ""))
			_clear_busy()
			if not authorize_url.begins_with("https://"):
				auth_completed.emit("google_link", false, {"message": "Supabase no devolvió una dirección segura para enlazar Google."})
				return
			_navigate_browser_to(authorize_url)


func _complete_auth(response: Dictionary, action: String) -> void:
	var session_user: Dictionary = response.get("user", {})
	access_token = str(response.get("access_token", ""))
	refresh_token = str(response.get("refresh_token", ""))
	_expires_at = int(Time.get_unix_time_from_system()) + int(response.get("expires_in", 3600))
	if access_token.is_empty() or session_user.is_empty():
		_clear_busy()
		_clear_session()
		auth_completed.emit(action, false, {"message": "Supabase no devolvió una sesión válida."})
		return
	current_user = {
		"id": str(session_user.get("id", "")),
		"email": str(session_user.get("email", "")),
		"user_metadata": session_user.get("user_metadata", {}),
		"app_metadata": session_user.get("app_metadata", {}),
		"identities": session_user.get("identities", []),
	}
	is_authenticated = true
	_save_session()
	if action == "refresh_session":
		_clear_busy()
		auth_state_changed.emit(true, current_user.duplicate(true))
		return
	_clear_busy()
	# No expongas access/refresh tokens a las escenas ni a la consola.
	auth_completed.emit(action, true, current_user.duplicate(true))
	auth_state_changed.emit(true, current_user.duplicate(true))
	if action == "restore_session" and transient_auth_notice.is_empty():
		transient_auth_notice = "Sesión de Supabase restaurada."


func _resume_after_refresh() -> void:
	var next_action := _after_refresh
	_after_refresh = ""
	if next_action.is_empty():
		return
	if next_action == "load_profile":
		_send_profile_request("load_profile")
	elif next_action == "save_profile":
		_send_profile_request("save_profile")
	elif next_action == "google_link":
		_begin_google_identity_link()


func _session_needs_refresh() -> bool:
	return _expires_at > 0 and _expires_at <= int(Time.get_unix_time_from_system()) + 90


func _to_database_profile(source: Dictionary) -> Dictionary:
	var fields := ["nickname", "hero_id", "hero_name", "onboarding_complete", "hero_level", "coins", "tickets", "diamonds", "premium_tickets", "xp", "summons", "owned_heroes", "last_seen", "last_coin_claim", "last_xp_claim"]
	var result := {}
	for field in fields:
		if source.has(field):
			result[field] = source[field]
	return result


func _response_first_row(response: Variant) -> Dictionary:
	if response is Array and not response.is_empty() and response[0] is Dictionary:
		return response[0]
	if response is Dictionary:
		return response
	return {}


func _parse_response(body: PackedByteArray) -> Variant:
	if body.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}
	return json.data


func _friendly_error(response: Variant, response_code: int) -> String:
	var data: Dictionary = response if response is Dictionary else {}
	var code := str(data.get("error_code", data.get("code", "")))
	var detail := str(data.get("message", data.get("msg", data.get("error_description", ""))))
	var normalized := (code + " " + detail).to_lower()
	if normalized.contains("manual_linking_disabled"):
		return "El enlace de identidades está desactivado en Supabase. Activa Manual Linking en la configuración de autenticación."
	if normalized.contains("identity_already_exists"):
		return "Esta cuenta de Google ya está enlazada con otra cuenta de Valoria."
	if normalized.contains("identity already exists"):
		return "Esta cuenta de Google ya está enlazada."
	if code == "23505" or detail.to_lower().contains("player_profiles_nickname") or detail.to_lower().contains("nickname") and detail.to_lower().contains("duplicate"):
		return "Ese nickname ya está en uso. Elige otro para continuar."
	normalized = (code + " " + detail).to_lower()
	if normalized.contains("invalid login credentials") or normalized.contains("invalid_credentials"):
		return "Correo o contraseña incorrectos."
	if normalized.contains("user already registered"):
		return "Ese correo ya tiene una cuenta. Inicia sesión."
	if normalized.contains("password should be at least") or normalized.contains("weak_password"):
		return "La contraseña debe tener al menos 6 caracteres."
	if normalized.contains("email not confirmed"):
		return "Confirma tu correo desde el enlace que te enviamos antes de iniciar sesión."
	if response_code == 429:
		return "Hay demasiados intentos. Espera un poco y vuelve a probar."
	if response_code >= 500:
		return "Supabase no está disponible ahora mismo. Inténtalo de nuevo más tarde."
	if detail.is_empty():
		return "Supabase devolvió un error HTTP %d." % response_code
	return "Supabase: %s" % detail


func _finish_request_failure(message: String) -> void:
	var failed_kind := _active_kind
	var failed_action := _active_action
	var after_refresh := _after_refresh
	_clear_busy()
	if failed_kind == "auth":
		auth_completed.emit(failed_action, false, {"message": message})
	elif failed_kind == "load_profile":
		profile_loaded.emit(false, {}, message)
	elif failed_kind == "save_profile":
		_pending_profile.clear()
		profile_saved.emit(false, {}, message)
	elif failed_kind == "oauth_link_authorize":
		auth_completed.emit("google_link", false, {"message": message})
	elif failed_kind == "refresh_session":
		_clear_session()
		if failed_action == "restore_session":
			auth_state_changed.emit(false, {})
		elif after_refresh == "load_profile" or after_refresh == "save_profile":
			_fail_profile_after_refresh("No se pudo renovar la sesión. Inicia sesión de nuevo para sincronizar el perfil.")
		elif after_refresh == "google_link":
			auth_completed.emit("google_link", false, {"message": "No se pudo renovar la sesión. Vuelve a iniciar sesión antes de enlazar Google."})


func _fail_profile_after_refresh(message: String) -> bool:
	var action := _after_refresh
	_after_refresh = ""
	if action == "load_profile":
		profile_loaded.emit(false, {}, message)
	elif action == "save_profile":
		profile_saved.emit(false, {}, message)
	elif action == "google_link":
		auth_completed.emit("google_link", false, {"message": message})
	return false


func _save_session() -> void:
	var config := ConfigFile.new()
	config.set_value("session", "refresh_token", refresh_token)
	config.save(SESSION_PATH)


func _clear_session() -> void:
	access_token = ""
	refresh_token = ""
	_expires_at = 0
	current_user.clear()
	is_authenticated = false
	var config := ConfigFile.new()
	config.set_value("session", "refresh_token", "")
	config.save(SESSION_PATH)


func _clear_busy() -> void:
	_active_kind = ""
	_active_action = ""
	is_busy = false
