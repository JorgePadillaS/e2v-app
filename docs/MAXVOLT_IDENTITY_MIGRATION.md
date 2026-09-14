# Identidad independiente de MaxVolt — preparación

Rama pendiente de configuración Firebase; todavía no es instalable.

- Android applicationId/namespace e iOS bundle ID: `net.maxvolt.app`.
- Paquete Dart: `maxvolt_app`.
- Retorno de pagos: `maxvolt://payment-complete`.
- Retirados archivos Firebase y cliente Google anteriores; recuperables en Git.
  Ningún recurso del proyecto remoto de ElectroPoint se ha eliminado.

## Para completar

Registrar Android e iOS como `net.maxvolt.app` en el nuevo proyecto y proporcionar
`google-services.json`, `GoogleService-Info.plist` y `firebase_options.dart`
generado por FlutterFire. Configurar el cliente OAuth Web mediante
`MAXVOLT_GOOGLE_WEB_CLIENT_ID` (dart-define), y el esquema iOS mediante
`MAXVOLT_GOOGLE_REVERSED_CLIENT_ID` en Xcode. Registrar las huellas SHA-1 y SHA-256
de las firmas Android de prueba y publicación. No compartir claves privadas.

Correo/contraseña se validan actualmente en el CMS, no en Firebase Auth. Se
conserva ese mecanismo para mantener cuentas, saldos e historial. Migrar cuentas
a Firebase Auth requiere un cambio adicional coordinado entre app y backend.

Actualizar en el CMS el cliente Google aceptado, el proyecto FCM y el puente
Firestore (`maxvolt_stations`), y los retornos de pagos al esquema MaxVolt.
Configurar Remote Config con claves `maxvolt_*` en el nuevo proyecto.

Los archivos previos no deben reutilizarse cambiando sus IDs a mano. La falta de
configuración bloquea intencionalmente la compilación Android y el inicio.
Pendientes análisis/pruebas Flutter, APK y pruebas de Google, FCM, Firestore,
Remote Config y pagos una vez recibidos los archivos reales.
