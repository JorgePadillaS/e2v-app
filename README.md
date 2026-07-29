# e2v Mobile Application

Aplicación móvil desarrollada en Flutter para la red de estaciones de carga de vehículos eléctricos **e2v**. Permite a los usuarios ubicar conectores de carga en tiempo real, gestionar su saldo/monedero virtual, iniciar/supervisar sesiones de carga (mediante QR o NFC) y administrar sus datos personales y vehículos.

---

## 🚀 Características Principales

* 🗺️ **Mapa Interactivo de Estaciones**: Visualización de puntos de carga en tiempo real mediante `flutter_map` y OpenStreetMap, con filtrado por estado y disponibilidad.
* 💳 **Gestión de Saldo y Monedero**: Recargas de crédito rápidas y seguras con pasarela de pago integrada y procesamiento de deep links (`e2vapp://`).
* ⚡ **Inicio de Carga Flexible**:
  * Escaneo de código QR a través de la cámara (`mobile_scanner`).
  * Validación aproximando un tag NFC en los puntos compatibles (`nfc_manager`).
* 📊 **Monitoreo en Tiempo Real**: Seguimiento en tiempo real de potencia (kW), energía consumida (kWh) y estado de la transacción mediante **WebSockets** (Pusher / Laravel Echo) y **Firebase Cloud Messaging**.
* 🚗 **Administración de Vehículos**: Registro de marcas, modelos, años y placas para facturación e impuestos.
* 📄 **Facturación y Cumplimiento**: Registro de NIT / Razón Social y opciones para cumplimiento de privacidad y GDPR.

---

## 🛠️ Tecnologías y Librerías Utilizadas

* **Framework**: Flutter (Dart SDK ^3.7.0)
* **Gestión de Estado**: `flutter_riverpod` (^2.6.1)
* **Peticiones HTTP**: `dio` (^5.8.0)
* **Navegación / Mapas**: `flutter_map` (^8.0.0), `latlong2`, `geolocator`
* **Realtime & WebSockets**: `pusher_channels_flutter`, `laravel_echo`, `cloud_firestore`
* **Escaneo & NFC**: `mobile_scanner`, `nfc_manager`
* **Notificaciones & Push**: `firebase_core`, `firebase_messaging`, `firebase_remote_config`
* **Autenticación**: Email/Password y Google Sign-In (`google_sign_in`)
* **Iconografía y Diseño**: `lucide_icons_flutter`, `google_fonts`, `flex_color_scheme`
* **Deep Linking**: `app_links` (`e2vapp://payment-complete`)

---

## 🏗️ Estructura del Proyecto

```
lib/
├── firebase_options.dart   # Configuración de Firebase
├── main.dart               # Punto de entrada de la aplicación
└── src/
    ├── app.dart            # Configuración de MaterialApp y Providers base
    ├── core/               # Módulos reutilizables del sistema
    │   ├── config/         # Branding, configuración remota y constantes
    │   ├── network/        # Clientes HTTP y WebSocket
    │   ├── services/       # Servicios de geolocalización, NFC y notificaciones
    │   └── ui/             # Componentes visuales globales y widgets compartidos
    └── features/           # Arquitectura orientada a características
        ├── auth/           # Login, Registro, Recuperación y Perfil de Usuario
        └── mobile/         # Mapa de estaciones, Escáner QR/NFC, Billetera y Cargas
```

---

## 📋 Requisitos Previos

Antes de ejecutar o compilar la aplicación, asegúrate de contar con:

1. **Flutter SDK** instalado (versión 3.29.0 o superior).
2. **Android Studio** / **Xcode** para emular o compilar en dispositivos Android/iOS.
3. Dispositivo físico o emulador configurado con soporte para Google Play Services.

---

## 💻 Instalación y Ejecución

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/julioperedodmc/e2v.git
   cd e2v
   ```

2. **Instalar las dependencias:**
   ```bash
   flutter pub get
   ```

3. **Ejecutar en modo desarrollo:**
   ```bash
   flutter run
   ```

4. **Ejecutar pruebas unitarias / de widgets:**
   ```bash
   flutter test
   ```

---

## 📱 Compilación para Producción

### Android (APK / App Bundle)
```bash
flutter build apk --release
# O para Google Play Store:
flutter build appbundle --release
```

### iOS (IPA)
```bash
flutter build ipa --release
```

---

## 📄 Licencia

Propiedad privada de **e2v**. Todos los derechos reservados.
