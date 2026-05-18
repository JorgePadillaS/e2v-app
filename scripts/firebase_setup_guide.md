# Firebase Google Sign-In Setup para bo.e2v.electropoint

## Error Actual
```
com.google.android.gms.common.api.ApiException: 10 (DEVELOPER_ERROR)
```

**Causa**: La app Android con package `bo.e2v.electropoint` no está registrada en Firebase o faltan las huellas digitales.

---

## Solución Step-by-Step

### PASO 1: Abre Firebase Console
1. Ve a https://console.firebase.google.com
2. Selecciona proyecto: **"electropoint-8c3d1"**

### PASO 2: Verifica/Crea la app Android
1. En el menú izquierdo, selecciona **"Configuración del proyecto"** (ícono de engranaje)
2. Ve a la pestaña **"Apps"**
3. **Busca si existe** una app Android:
   - Si existe **"com.evbol.e2v_app"** → Debes eliminarla o crear una nueva
   - Si existe **"bo.e2v.electropoint"** → Avanza al PASO 3
   - Si NO existe ninguna → Crea una nueva

#### Para crear/editar la app Android:
- Haz clic en **"Agregar app"** o edita la existente
- **Nombre del paquete de Android**: `bo.e2v.electropoint`
- **Alias del depurador** (opcional): `bo.e2v.electropoint`
- **Alias de la clave de firma** (opcional): `upload`

### PASO 3: Registra las huellas SHA
En Firebase Console, dentro de la configuración de la app Android:

1. Busca la sección **"Huella digital SHA"** (o **"Certificate fingerprints"**)
2. Haz clic en **"Agregar huella"** o **"Add fingerprint"**
3. Añade **AMBAS**:

```
SHA-1:   5E:66:B3:6A:83:FC:72:2E:3A:62:46:9F:53:C2:84:52:19:1C:B0:B7
SHA-256: A3:C9:26:29:89:7C:40:18:CF:71:F8:F1:BD:A8:FC:DE:F6:20:2B:CB:D9:A7:C2:5E:B3:86:4A:D2:F8:49:DC:A2
```

4. Guarda/cierra y **espera 5-10 minutos** a que Firebase procese los cambios.

### PASO 4: Descarga el nuevo google-services.json
1. En la misma pantalla de la app Android, haz clic en **"Descargar google-services.json"** (o similar)
2. Se descargará automáticamente

### PASO 5: Reemplaza en el repo
1. Copia el contenido del nuevo `google-services.json` (que descargaste)
2. Reemplaza `/Users/julio/Documents/GitHub/e2v/android/app/google-services.json` con el nuevo
3. O avísame y lo haré automáticamente

### PASO 6: Limpia, compila y prueba
```bash
cd /Users/julio/Documents/GitHub/e2v
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run -d <device_id>
```

---

## Notas Importantes

- **Error 10 solo desaparece cuando**:
  - ✅ El package `bo.e2v.electropoint` está registrado en Firebase
  - ✅ Las huellas SHA están configuradas
  - ✅ El `google-services.json` es reciente (descargado tras registrar las huellas)

- **Si aún falla después de estos pasos**:
  - Abre la consola del emulador/dispositivo: `flutter logs`
  - Busca líneas que digan `GoogleSignIn` o `PlayServicesVersion`
  - Comparte los logs conmigo

---

## Verificación Rápida (Local en tu Máquina)

Si quieres ver qué huellas necesita tu keystore:
```bash
cd /Users/julio/Documents/GitHub/e2v/android/app
# Para debug keystore (si no está configurado el upload en key.properties):
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Para upload keystore:
keytool -list -v -keystore upload-keystore.jks -alias upload
```


