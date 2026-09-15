# Identidad independiente de MaxVolt — preparación

Configuración Android/iOS recibida e integrada para `maxvolt-ac105`.
`firebase_options.dart` deriva de ambos archivos para `net.maxvolt.app`.

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

Los archivos actualizados incluyen OAuth Web e iOS. Integrados cliente Web,
iosClientId y esquema REVERSED_CLIENT_ID. El JSON no contiene cliente Android
de tipo 1 con certificado. Registrar las huellas SHA-1/SHA-256 de la APK de
prueba en Firebase y validar el acceso en teléfono. CI imprime el certificado
de cada APK: los runners efímeros pueden generar firmas debug distintas entre
compilaciones. La firma de publicación deberá mantenerse estable y registrarse
por separado. No se ha probado un login real ni modificado el backend.
Compilación y pruebas se registran en el PR. FCM, Firestore, Remote Config,
retorno de pagos y compilación iOS requieren validación de integración.
