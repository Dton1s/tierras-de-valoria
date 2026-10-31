# Tierras de Valoria

Proyecto de RPG 2D por turnos desarrollado en Godot 4.7.2. Este directorio contiene el proyecto, el cliente Supabase y la exportación web estática.

## Backend y seguridad

- La autenticación usa Supabase Auth por REST: registro con correo y contraseña, inicio de sesión, renovación de sesión y cierre de sesión.
- El menú web también admite acceso y registro con Google mediante OAuth y PKCE. El primer acceso crea la cuenta de Supabase automáticamente. Desde Ajustes del campamento, una cuenta de correo ya autenticada puede enlazar su identidad de Google; el secreto OAuth de Google se configura solo en el panel de Supabase y nunca se incluye en el juego.
- `SupabaseManager` es un autoload. Guarda únicamente el refresh token en `user://valoria_supabase_session.cfg`; nunca guarda contraseñas ni imprime tokens.
- La URL y la **publishable key** pública están en `supabase_config.gd`. No añadas claves `sb_secret` ni `service_role` al juego, a GitHub ni a un archivo descargado por el navegador.
- Los perfiles y monedas están en `public.player_profiles`. RLS limita cada lectura y escritura a `auth.uid() = user_id`; un índice único sin distinción de mayúsculas protege los nicknames.

### Preparar Supabase

1. En el proyecto Supabase `lcksstixomutkuzwrdcc`, ejecuta [`supabase/migrations/20261031000000_player_profiles.sql`](supabase/migrations/20261031000000_player_profiles.sql) desde **SQL Editor**.
2. En **Authentication → Providers**, habilita el registro con correo y contraseña. Si la confirmación de correo está activa, el juego avisa al jugador que revise el email antes de iniciar sesión.
3. En **Authentication → Providers → Google**, configura el Client ID y el secreto de cliente, y comprueba que el callback de Supabase esté autorizado en Google Cloud. Habilita **Manual Linking** para que el botón de ajustes pueda vincular Google a una cuenta de correo ya iniciada.
4. En **Authentication → URL Configuration**, añade la URL publicada de GitHub Pages a las redirecciones permitidas (por ejemplo, `https://dton1s.github.io/tierras-de-valoria/`). El dominio debe coincidir con la URL desde la que se abre el juego.
5. Mantén RLS habilitado. La aplicación solo usa la publishable key y el JWT individual de cada usuario; no hace falta una clave de servidor.

## Estructura

```text
godot_assets/
├── assets/                       # Ilustraciones, personajes, UI, audio y fuentes
├── scenes/ui/MainMenu.tscn       # Registro, inicio de sesión y ajustes
├── scenes/ui/CampSelectionMenu.tscn
├── scenes/game/CampHub.tscn      # Onboarding, campamento, economía y perfil
├── scripts/autoload/
│   ├── SupabaseManager.gd        # Auth REST, sesión y perfiles REST
│   └── GameAudio.gd              # Música de fondo
├── supabase/migrations/          # Esquema y políticas RLS
├── web/godot_shell.html          # Portada de carga para exportación HTML5
├── scripts/export_web.ps1        # Exportación estática de recursos seleccionados
├── export_presets.cfg            # WebAssembly sin hilos; modo de export ligero
└── project.godot
```

## Exportar para GitHub Pages u otro hosting estático

Requisitos: Godot 4.7.2 y sus plantillas de exportación Web.

Desde PowerShell, en la carpeta `godot_assets/`:

```powershell
.\scripts\export_web.ps1
# O indica dónde está Godot:
.\scripts\export_web.ps1 -GodotPath 'C:\ruta\a\Godot_v4.7.2-stable_win64.exe'
```

El resultado queda en `build/web/`. El preset incluye las tres escenas de juego y las texturas, audio, fuente y efectos usados por ellas, en lugar de empaquetar toda la biblioteca descargada. Publica **el contenido** de `build/web/` como sitio estático. Para GitHub Pages, habilita Pages para el repositorio `Dton1s/tierras-de-valoria` y publica esa carpeta mediante tu flujo de Pages.

La shell de carga usa rutas relativas, mantiene la portada de Valoria y no necesita un servidor Node.

## Contenido del perfil

El perfil remoto guarda nickname, héroe inicial, nivel, experiencia, monedas, tickets, diamantes, invocaciones, héroes obtenidos y temporizadores AFK. Si Supabase no responde, el juego mantiene una copia local y muestra un mensaje; la disponibilidad global del nickname requiere conexión.

## Assets y estado del juego

La escena principal mantiene el onboarding del mago y el refugio interactivo del bosque: cama, cofre, accesos PvE/PvP y máquina Gacha. Combate, PvP y economía siguen siendo prototipos.

El inventario de recursos está en [`ASSET_AUDIT.md`](ASSET_AUDIT.md), con el manifiesto completo en [`organization_report.json`](organization_report.json).

## Claves Supabase expuestas

La clave `secret` y la clave `service_role` que se compartieron durante la configuración deben rotarse desde **Supabase → Project Settings → API Keys**. No se usan en este proyecto. Solo la publishable key destinada a clientes aparece en `supabase_config.gd`.
