# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estado del proyecto

App iOS en SwiftUI recién creada desde la plantilla de Xcode 26.5: solo existe `guide_iosApp` (punto de entrada `@main`) que muestra `ContentView`. No hay target de tests, dependencias SPM, linter ni formateador configurados todavía.

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
- **Recursos tipados**: se generan símbolos Swift para el asset catalog (`Color.accent`, `ImageResource`) y para los String Catalogs (`STRING_CATALOG_GENERATE_SYMBOLS`). Las cadenas localizables deben ir en un `.xcstrings`.

## Producto y distribución

App interna de seguimiento de envíos para empleados: login con cuentas del backend existente, consulta de envíos y subida de imágenes (cámara y galería) a la API. Se distribuye como Unlisted App en App Store Connect (oculta en búsquedas, se instala por enlace).

- Para la galería usar `PhotosPicker`, que no requiere `NSPhotoLibraryUsageDescription`; si se añade otro acceso a fotos, hay que añadir esa clave.
- App Review necesita una cuenta demo que funcione contra el backend.
