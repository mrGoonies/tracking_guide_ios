# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado del proyecto

App iOS en SwiftUI (Xcode 26.5) para los transportistas de Irritec Logística, cliente de la API REST de Tracking Guide. Sin dependencias SPM. Todavía no hay target de tests, linter ni formateador.

- Target único: `guide-ios` (solo iPhone), bundle id `com.irritec.guide`, nombre visible "Irritec Guias", deployment target iOS 18.0 (las APIs más nuevas requieren `if #available`).
- Firma automática con el team `YT74GHW9X5`.

## Comandos

Requiere Xcode 26.5 o superior (`/Applications/Xcode.app`).

```sh
# Compilar para simulador
xcodebuild -project guide-ios.xcodeproj -scheme guide-ios \
  -destination 'generic/platform=iOS Simulator' build

# Listar simuladores disponibles
xcrun simctl list devices available
```

El scheme `guide-ios` es autogenerado (no está compartido en `xcshareddata`). No hay tests: si se añade un target de tests, habrá que compartir el scheme para usar `xcodebuild test` / `-only-testing:<Target>/<Clase>/<método>`.

## Configuración del proyecto que afecta al código

- **Grupos sincronizados con el sistema de archivos** (`PBXFileSystemSynchronizedRootGroup`, objectVersion 77): cualquier archivo creado dentro de `guide-ios/` entra al target automáticamente. No hace falta (ni conviene) editar `project.pbxproj` para añadir archivos fuente o recursos.
- **Sin `Info.plist` físico** (`GENERATE_INFOPLIST_FILE = YES`): las claves se definen como build settings `INFOPLIST_KEY_*` en `project.pbxproj` en ambas configuraciones Debug y Release. Ya están definidos `INFOPLIST_KEY_NSCameraUsageDescription` y `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (la app solo debe usar cifrado exento, p. ej. HTTPS).
- **Concurrencia**: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` y `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Todo tipo/función es `@MainActor` por defecto; el trabajo fuera del hilo principal debe marcarse explícitamente con `nonisolated` o `@concurrent`.
- **Swift language mode 5** (`SWIFT_VERSION = 5.0`), no Swift 6 estricto.
- **`MemberImportVisibility` activado**: hay que importar explícitamente cada módulo cuyos miembros se usan en un archivo (no basta con que otro archivo lo importe).
- **Recursos tipados**: se generan símbolos Swift para el asset catalog (`Color.accent`, `ImageResource`) y para los String Catalogs (`STRING_CATALOG_GENERATE_SYMBOLS`). No hay String Catalog todavía.
- **Idioma base español** (`developmentRegion = es`): los textos de la interfaz se escriben en español directamente en el código. Si se vuelve a `en`, iOS mostrará en inglés la UI del sistema (cámara, galería).

## Arquitectura

- **API** (`guide-ios/API/`): `APIClient` habla con `AppConfig.apiBaseURL` (`https://tracking-guide.onrender.com/api/v1/`, las rutas DRF llevan `/` final). Añade `Authorization: Bearer` y, ante un 401, renueva los tokens con `auth/refresh/` una sola vez y reintenta; las renovaciones concurrentes se comparten porque el refresh rota. Si el refresh falla por algo que no sea la red (401 o 5xx) llama a `onSesionExpirada` y se vuelve al login. A 2026-10-28 `auth/refresh/` responde 500 en producción con cualquier token (bug del backend), así que la sesión dura lo que el token de acceso (8 h).
- **Modelos** (`Models.swift`): se decodifican con `JSONDecoder.api` (snake_case → camelCase, fechas ISO 8601 con zona, con o sin microsegundos, o solo fecha a medianoche local). Los campos `estado` son `String`; `EstadoGuia` se usa solo para mostrar y para las transiciones (`GuiaDetalle.transiciones`, que vienen de `proximos_estados` del servidor).
- **Errores** (`APIError`): se mapean por código HTTP a mensajes en español. Usar `error.esCancelacion` para no mostrar errores de tareas canceladas.
- **Sesión** (`Auth/`): `SessionStore` (`@Observable`, inyectado con `.environment` en `guide_iosApp`) decide entre login y lista en `ContentView`. Los tokens JWT van en el Keychain (`TokenStore`), nunca en UserDefaults. Un login con `es_transportista: false` se rechaza sin guardar tokens.
- **Vistas** (`Views/`): `GuiasListView` (filtro por estado, búsqueda local, pull-to-refresh) → `GuiaDetailView` → `CambiarEstadoView` (sheet). Para `entregada`/`rechazada` la API exige `foto_guia` (1) y `fotos_cliente` (≥1) en `multipart/form-data`; las fotos se reducen a 2048 px en JPEG con `ImageProcessing.jpegParaSubir` (`@concurrent`, fuera del MainActor). Cámara con `CameraPicker` (UIKit), galería con `PhotosPicker`.

## Producto y distribución

App interna de seguimiento de envíos para empleados: login con cuentas del backend existente, consulta de envíos y subida de imágenes (cámara y galería) a la API. Se distribuye como Unlisted App en App Store Connect (oculta en búsquedas, se instala por enlace).

- Para la galería usar `PhotosPicker`, que no requiere `NSPhotoLibraryUsageDescription`; si se añade otro acceso a fotos, hay que añadir esa clave.
- App Review necesita una cuenta demo que funcione contra el backend.
