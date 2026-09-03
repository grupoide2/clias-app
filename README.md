# clias-app

Aplicación móvil de la paciente — **SISA** — del sistema **CLIAS**
(telemedicina — automuestreo de VPH, Universidad de Cuenca).

| | |
|---|---|
| Framework | Flutter (Android; iOS pendiente) |
| Package | `com.ucuenca.sisa` |
| Nombre en tienda | SISA - UCuenca |
| Push | Firebase Cloud Messaging |
| HTTP | paquete `http` hacia `clias-backend` |
| Navegación | `go_router` |
| Otros | `video_player` / `chewie` (videos), `mobile_scanner` (QR del dispositivo) |

## Funcionalidades

- Registro e inicio de sesión de la paciente (JWT).
- **Automuestreo de VPH:** formulario guiado tipo chat (offline, `assets/offline_form.json`),
  registro del dispositivo por QR o código manual, y confirmación con "Automuestreo completado".
- **Chatbot SISA** (Rasa): consultas sobre salud sexual y el proceso.
- Recursos educativos: videos y blogs.
- Notificaciones (resultado disponible, recordatorios) con fecha y hora de llegada.
- Seguimiento de tiempo de uso de app y de chatbot (métricas).

## Requisitos

- Flutter SDK (canal stable)
- `clias-backend` accesible
- Archivos de configuración/firma **no versionados** (ver abajo)

## Configuración

| Archivo | Estado | Nota |
|---|---|---|
| `lib/config/env.dart` | versionado | URL del backend / chatbot |
| `android/app/google-services.json` | versionado | config de cliente Firebase (no es secreto; viaja en el APK) |
| `android/key.properties` | **NO versionado** | credenciales del keystore de firma |
| `android/app/upload-keystore.jks` | **NO versionado** | keystore de subida a Play Store |

Para compilar una release firmada, coloca `key.properties` y `upload-keystore.jks`
según `android/app/build.gradle`.

## Ejecutar

```bash
flutter pub get
flutter run -d <device>            # desarrollo
flutter build appbundle --release  # AAB firmado para Play Store
```

## Estructura

```
lib/
  config/          Configuración (URLs)
  model/           Requests / responses / storage
  service/         Clientes HTTP y servicios (auth, sesión, notificaciones, recursos…)
  view/
    screens/       Pantallas
    widgets/       Componentes reutilizables
  utils/           Utilidades (tracker de uso, flags…)
assets/
  offline_form.json  Guion del formulario guiado de automuestreo
  videos/ images/    Media educativa
```

## Versionado de releases

`versionName+versionCode` en `pubspec.yaml`. Los AAB compilados se archivan fuera de
este repo (`clias-app-releases/`), no aquí.

## Relación con el resto de CLIAS

```
clias-backend   API REST + FCM
clias-chatbot   servicio del chat SISA
clias-admin     panel administrativo (otra app)
clias-docs      documentación del sistema
```
