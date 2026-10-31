# Auditoría de assets nuevos

Auditoría realizada el **30 de octubre de 2026**. Se revisaron los comprimidos añadidos a `../assets` desde las 19:10; el inventario detallado está en [`organization_report.json`](organization_report.json).

## Resultado

- **56 ZIP** encontrados, **52 paquetes únicos** y **4 copias exactas omitidas**. Los originales permanecen en `../assets`.
- Se extrajeron **19.811 PNG** (aprox. **2,16 GB**) a las carpetas del proyecto. La extracción de recursos permitidos acabó sin errores.
- El inventario de paquetes no encontró rutas internas que salieran del archivo. Se dejaron dentro de los ZIP los fuentes de edición y formatos ajenos al juego, como AI, EPS, PSD, SCML, Spine y UnityPackage, junto con licencias, documentos y metadatos.
- No aparecieron fuentes `.ttf`/`.otf` ni audio nuevo en estos paquetes.

| Carpeta | PNG nuevos | Contenido |
| --- | ---: | --- |
| `assets/sprites/characters/` | 3.180 | Valkyrie, Forest Ranger, Seer y Medieval Bandit |
| `assets/sprites/enemies/` | 12.630 | Golems, goblins, esqueletos, jefes, no muertos y otros enemigos |
| `assets/ui/` | 1.918 | Iconos de divisas, botín, habilidades, logros y equipo |
| `assets/vfx/` | 2.083 | Humo, fuego, agua, tajos, explosiones y efectos mágicos |
| `assets/audio/` | 0 | Los ZIP nuevos no incluyen audio compatible |

## Referencias conectadas

- **Héroes iniciales y Gacha:** Lyria usa el retrato Valkyrie. Las invocaciones comunes y especiales muestran el retrato obtenido.
- **HUD de divisas:** oro, tickets, diamantes y tickets especiales usan iconos del pack de botín vectorial.
- **Máquina Gacha:** el panel muestra un cofre ilustrado y los botones de invocación incluyen el icono de su divisa.
- **PvE:** la pantalla de expedición muestra una goblin del pack de enemigos y anima las ocho imágenes del humo químico como efecto de estado.
- El tema y la tipografía **Immortal** existentes siguen aplicándose a los textos y paneles.

## Licencias y límites

Se encontraron **87 archivos de licencia**; todos apuntan a la [licencia oficial de CraftPix](https://craftpix.net/file-licenses/). Su sección Freebie permite incluir recursos en juegos personales o comerciales, pero prohíbe redistribuir los archivos de arte como recursos reutilizables independientes. La publicación o entrega del juego debe mantener los assets integrados en el juego y no ofrecer su descarga individual.

La carpeta incluye los PNG extraídos para importación por Godot. Los archivos AI/EPS/PSD y los datos de animación originales siguen disponibles dentro de los ZIP de origen; no se importaron como recursos de runtime.
