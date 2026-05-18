# Guía Completa: Subir E2v App a Play Store y App Store

Todas las imágenes han sido generadas automáticamente en la carpeta `store_assets/`

## 📦 Archivos Generados

### Google Play Store (`store_assets/google_play/`)
- **icon_512.png** - Icono de la app (512x512 px)
- **feature_graphic_1024x500.jpg** - Gráfico destacado en header (1024x500 px)
- **screenshot_1_1080x1920.jpg** - Screenshot 1 (1080x1920 px)
- **screenshot_2_1080x1920.jpg** - Screenshot 2 (1080x1920 px)
- **screenshot_3_1080x1920.jpg** - Screenshot 3 (1080x1920 px)
- **promo_graphic_480x320.jpg** - Gráfico promocional (480x320 px)
- **tv_banner_1280x720.jpg** - Banner para TV (1280x720 px)

### App Store (`store_assets/app_store/`)
- **icon_1024.png** - Icono para App Store (1024x1024 px)
- **screenshot_iphone_67_...** - 3 screenshots para iPhone 14 Pro Max (1242x2688 px)
- **screenshot_iphone_61_...** - 3 screenshots para iPhone 14 (1170x2532 px)
- **screenshot_iphone_55_...** - 3 screenshots para iPhone 8 Plus (1080x1920 px)
- **screenshot_ipad_129_...** - 2 screenshots para iPad Pro 12.9" (2048x2732 px)
- **screenshot_ipad_11_...** - 2 screenshots para iPad Pro 11" (1668x2388 px)

---

## 🔥 Paso a Paso: Google Play Store

### 1. Crear/Acceder a Google Play Console
1. Ir a https://play.google.com/console
2. Iniciar sesión con tu cuenta de Google
3. Si no tienes app, hacer clic en "Crear aplicación"
4. Elegir idioma y aceptar términos

### 2. Rellenar Información de la App

#### **Detalles de la Aplicación**
- Nombre de la app: `E2v App` (o `electropoint`)
- Descripción breve (80 caracteres máx): `Escanea y gestiona códigos QR`
- Descripción completa: Describe features principales
- Categoría: Herramientas o Utilidades
- Tipo de contenido: Aplicación

#### **Gráficos y Imágenes**

1. **Icono de la app** (512x512 px)
   - Subir: `store_assets/google_play/icon_512.png`
   - Formato: PNG
   - Debe ser cuadrado

2. **Gráfico destacado** (1024x500 px) - OBLIGATORIO
   - Subir: `store_assets/google_play/feature_graphic_1024x500.jpg`
   - Tamaño máximo: 1 MB
   - Debe mostrar la app claramente

3. **Screenshots** (1080x1920 px) - OBLIGATORIO
   - Subir: Al menos 2, máximo 8
   - Archivos: `store_assets/google_play/screenshot_1_1080x1920.jpg` etc.
   - Recomendado: 5-8 screenshots mostrando features

4. **Gráfico promocional** (480x320 px) - OPCIONAL
   - Archivo: `store_assets/google_play/promo_graphic_480x320.jpg`
   - Para promoción en Google Play

5. **Gráfico de video** (1280x720 px) - OPCIONAL
   - Archivo: `store_assets/google_play/tv_banner_1280x720.jpg`
   - Para aplicaciones con video promocional

### 3. Contenido de Clasificación

Rellenar cuestionario de clasificación de contenido:
- Violencia, contenido sexual, etc.: Seleccionar según corresponda
- Tu app: "No es de pago" / "Gratuita"

### 4. Información de Contacto
- Email de contacto: Tu email
- Sitio web: (opcional) Tu sitio web o redes sociales
- Política de privacidad: (requerido) URL a tu política

### 5. Build de la App

1. Ir a **Gestión de aplicaciones** → **Versiones**
2. Crear nuevo lanzamiento:
   - Seleccionar **Producción** (o **Testing** primero para beta)
   - Subir APK o AAB (Android App Bundle)
     - Generado con: `flutter build appbundle --release` o `flutter build apk --release`

### 6. Revisar y Enviar

1. Verificar que todos los campos obligatorios estén completos ✓
2. Hacer clic en **Enviar para revisión**
3. Google revisará en 24-48 horas típicamente

---

## 🍎 Paso a Paso: App Store (Apple)

### 1. Preparar Certificados (IMPORTANTE)

Si aún no lo has hecho:
1. Ir a https://developer.apple.com
2. Crear cuenta de desarrollo ($99/año)
3. En Certificados, Identificadores y Perfiles:
   - Crear Certificate Signing Request (CSR)
   - Crear Distribution Certificate
   - Crear App ID (bundle identifier: `bo.e2v.electropoint`)
   - Crear Provisioning Profile

Para Flutter:
```bash
flutter build ios --release
# O para hacer setup completo:
cd ios
pod install
cd ..
flutter build ios --release
```

Luego archivar en Xcode:
- Abrir Xcode: `open ios/Runner.xcworkspace`
- Seleccionar dispositivo: **Any iOS Device (arm64)**
- Product → Archive
- En Organizer, seleccionar archive → Distribute App

### 2. Acceder a App Store Connect
1. Ir a https://appstoreconnect.apple.com
2. Iniciar sesión con Apple ID
3. Ir a **Aplicaciones** → **Mi aplicación**

### 3. Crear Nueva Aplicación
1. Hacer clic en **+** (Nueva app)
2. Seleccionar:
   - Plataforma: **iOS**
   - Nombre: `E2v App`
   - ID en Bundle: `bo.e2v.electropoint`
   - SKU: `e2v.app.001` (único)
   - Acceso completo: Permitir

### 4. Rellenar Información
En **Información de la app**:
- Nombre de la app: `E2v App`
- ID en Bundle primario: `bo.e2v.electropoint`
- Categoría: Utilidades
- Subcategoría: (opcional)

### 5. Agregar Iconos e Imágenes

En **Iconos de la app**:
- Subir: `store_assets/app_store/icon_1024.png`
- Tamaño: 1024x1024 px

En **Screenshots** (añadir para cada tamaño de dispositivo):

#### iPhone 6.7" (Pro Max)
- Tamaño: 1242x2688 px
- Subir: `store_assets/app_store/screenshot_iphone_67_1242x2688_1.jpg`
- Etc. (hasta 5)

#### iPhone 6.1" (Standard)
- Tamaño: 1170x2532 px
- Subir: `store_assets/app_store/screenshot_iphone_61_1170x2532_1.jpg`
- Etc. (hasta 5)

#### iPhone 5.5" (Opcional)
- Tamaño: 1080x1920 px
- Subir: `store_assets/app_store/screenshot_iphone_55_1080x1920_1.jpg`

#### iPad (Opcional, pero Recomendado)
- iPad Pro 12.9": 2048x2732 px → `screenshot_ipad_129_...`
- iPad Pro 11": 1668x2388 px → `screenshot_ipad_11_...`

### 6. Descripción y Palabras Clave

**Descripción de la app** (4000 caracteres máx):
```
E2v App es la solución perfecta para gestionar y escanear códigos QR 
de forma rápida y segura. 

Características:
✓ Escanea códigos QR al instante
✓ Gestiona tu historial
✓ Compartir códigos
✓ Interfaz intuitiva
✓ Sin anuncios
```

**Palabras clave** (100 caracteres total):
```
QR, escanear, código QR, scanner
```

**URL de soporte**: Tu URL de soporte (obligatorio)

**URL de política de privacidad**: Tu política de privacidad (obligatorio)

### 7. Información de Precio y Distribución

**Precio**:
- Seleccionar: **Gratuita** (o tu precio)

**Disponibilidad**:
- Seleccionar países donde distribuir
- Recomendado: Todos

**Información de contacto de la app**:
- Email: Tu email de contacto

### 8. Calificación por Edad

Rellenar cuestionario:
- Preguntas sobre violencia, lenguaje, etc.
- Tu app probablemente sea **4+**

### 9. Subir Build

1. En **Versión de la app** → **Build**
2. Hacer clic en **+**
3. Si no has generado build:
   ```bash
   flutter build ios --release
   cd ios
   xcodebuild -workspace Runner.xcworkspace \
     -scheme Runner \
     -configuration Release \
     -derivedDataPath build \
     -archivePath build/Runner.xcarchive \
     archive
   ```
4. Desde Xcode Organizer → Distribuir App → App Store Connect

### 10. Información de Contacto del Equipo
- Nombre: Tu nombre
- Email: Tu email
- Teléfono: (opcional)

### 11. Revisar y Enviar
1. Verificar todas las secciones ✓
2. Hacer clic en **Enviar para revisión**
3. Apple revisa en 24-48 horas típicamente

---

## 📋 Verificación Previa

Antes de enviar a ambas tiendas, verifica:

### Google Play
- [ ] Icono 512x512 subido
- [ ] Feature graphic 1024x500 subido
- [ ] Al menos 2 screenshots (máx 8)
- [ ] Descripción completa sin typos
- [ ] Términos y políticas aceptados
- [ ] Build (APK/AAB) subido y probado

### App Store
- [ ] Icono 1024x1024 subido
- [ ] Screenshots para al menos 2 tamaños de iPhone
- [ ] Descripción y palabras clave rellenadas
- [ ] Política de privacidad completa
- [ ] Build archivado y distribuido
- [ ] Clasificación por edad completada

---

## ⚠️ Notas Importantes

1. **Certificados iOS**: Necesitas cuenta de desarrollador Apple ($99/año)
2. **Política de Privacidad**: REQUERIDA en ambas tiendas
3. **Google Play**: Primeros 30 minutos de prueba intensa, después opcional pago de $25 one-time
4. **Screenshots adicionales**: Aumentan conversión. Muestra features principales
5. **Descripciones**: Escribe para usuarios, no para buscadores
6. **Actualizaciones**: Ambas tiendas permiten actualizar sin nueva revisión (típicamente)

---

## 📸 Mejoras Adicionales (Recomendadas)

Para mejorar conversión:

1. **Añadir texto a screenshots** usando Figma o design tool:
   - "Escanea al instante"
   - "Gestiona tu historial"
   - "Seguro y rápido"

2. **Video promocional** (30-60 seg):
   - Muestra la app en acción
   - Disponible en ambas tiendas

3. **A/B Testing** de screenshots:
   - Prueba diferentes versiones
   - Monitorea conversión

---

## 🚀 Próximos Pasos

1. Personalizar screenshots con texto (recomendado)
2. Preparar datos de cuenta de desarrollador
3. Subir a Google Play primero (más rápido)
4. Luego a App Store
5. Monitorear reviews y ratings

¡Buena suerte! 🎉

