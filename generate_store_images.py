#!/usr/bin/env python3
"""
Script para generar imágenes necesarias para Play Store y App Store
Genera todos los tamaños requeridos automáticamente desde el logo existente
"""

import os
from PIL import Image, ImageDraw, ImageFilter
import json

# Crear directorios de salida
output_base = "store_assets"
os.makedirs(output_base, exist_ok=True)
os.makedirs(f"{output_base}/google_play", exist_ok=True)
os.makedirs(f"{output_base}/app_store", exist_ok=True)

# Cargar logo
logo_path = "assets/logo.png"
if not os.path.exists(logo_path):
    print(f"Error: {logo_path} no encontrado")
    exit(1)

logo = Image.open(logo_path).convert("RGBA")
print(f"Logo cargado: {logo.size}")

def create_app_icon(logo, size, output_path, bg_color=(255, 255, 255, 255)):
    """Crear icono de app con fondo redondeado"""
    icon = Image.new("RGBA", (size, size), bg_color)

    # Redimensionar logo manteniendo aspecto
    ratio = min(size / logo.width, size / logo.height)
    new_size = int(logo.width * ratio * 0.85), int(logo.height * ratio * 0.85)
    logo_resized = logo.resize(new_size, Image.Resampling.LANCZOS)

    # Centrar logo en el cuadrado
    offset = ((size - logo_resized.width) // 2, (size - logo_resized.height) // 2)
    icon.paste(logo_resized, offset, logo_resized)

    # Redondear esquinas
    radius = int(size * 0.2)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (size, size)], radius=radius, fill=255)

    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    result.paste(icon, (0, 0), mask)

    result.convert("RGB").save(output_path, "PNG")
    print(f"✓ Creado: {output_path}")

def create_feature_graphic(logo, size, output_path, bg_color=(0, 118, 214)):
    """Crear gráfico destacado con logo centrado"""
    width, height = size
    graphic = Image.new("RGB", (width, height), bg_color)

    # Redimensionar logo
    ratio = min((width * 0.6) / logo.width, (height * 0.6) / logo.height)
    new_size = int(logo.width * ratio), int(logo.height * ratio)
    logo_resized = logo.resize(new_size, Image.Resampling.LANCZOS)

    # Centrar
    offset = ((width - logo_resized.width) // 2, (height - logo_resized.height) // 2)

    # Pegar logo
    bg_pil = Image.new("RGBA", graphic.size, (0, 0, 0, 0))
    bg_pil.paste(logo_resized, offset, logo_resized)

    graphic.paste(bg_pil, (0, 0), bg_pil)
    graphic.save(output_path, "JPEG", quality=95)
    print(f"✓ Creado: {output_path}")

def create_screenshot(size, output_path, app_name="E2v App"):
    """Crear screenshot de demostración"""
    width, height = size
    screenshot = Image.new("RGB", (width, height), (245, 245, 245))

    # Barra de estado
    draw = ImageDraw.Draw(screenshot)
    draw.rectangle([(0, 0), (width, 60)], fill=(0, 118, 214))

    # Contenido centrado
    color_accent = (0, 118, 214)

    # Redimensionar logo para screenshot
    ratio = min((width * 0.5) / logo.width, (height * 0.3) / logo.height)
    new_size = int(logo.width * ratio), int(logo.height * ratio)
    logo_resized = logo.resize(new_size, Image.Resampling.LANCZOS)
    offset = ((width - logo_resized.width) // 2, (height // 2 - logo_resized.height) // 2)

    screenshot_rgba = Image.new("RGBA", screenshot.size, (0, 0, 0, 0))
    screenshot_rgba.paste(logo_resized, offset, logo_resized)
    screenshot.paste(screenshot_rgba, (0, 0), screenshot_rgba)

    screenshot.save(output_path, "JPEG", quality=95)
    print(f"✓ Creado: {output_path}")

# GOOGLE PLAY STORE
print("\n📱 Generando imágenes para Google Play Store...")

# App Icon (512x512)
create_app_icon(logo, 512, f"{output_base}/google_play/icon_512.png", bg_color=(255, 255, 255, 255))

# Feature Graphic (1024x500)
create_feature_graphic(logo, (1024, 500), f"{output_base}/google_play/feature_graphic_1024x500.jpg")

# Screenshots (1080x1920) - 3 variaciones
for i in range(1, 4):
    create_screenshot((1080, 1920), f"{output_base}/google_play/screenshot_{i}_1080x1920.jpg")

# Promo Graphic (480x320)
create_feature_graphic(logo, (480, 320), f"{output_base}/google_play/promo_graphic_480x320.jpg")

# TV Banner (1280x720)
create_feature_graphic(logo, (1280, 720), f"{output_base}/google_play/tv_banner_1280x720.jpg")

# APP STORE (iOS)
print("\n🍎 Generando imágenes para App Store...")

# App Icon (1024x1024)
create_app_icon(logo, 1024, f"{output_base}/app_store/icon_1024.png", bg_color=(255, 255, 255, 255))

# Screenshots iPhone 6.7" (1242x2688)
for i in range(1, 4):
    create_screenshot((1242, 2688), f"{output_base}/app_store/screenshot_iphone_67_1242x2688_{i}.jpg")

# Screenshots iPhone 6.1" (1170x2532)
for i in range(1, 4):
    create_screenshot((1170, 2532), f"{output_base}/app_store/screenshot_iphone_61_1170x2532_{i}.jpg")

# Screenshots iPhone 5.5" (1080x1920)
for i in range(1, 4):
    create_screenshot((1080, 1920), f"{output_base}/app_store/screenshot_iphone_55_1080x1920_{i}.jpg")

# Screenshots iPad Pro 12.9" (2048x2732)
for i in range(1, 3):
    create_screenshot((2048, 2732), f"{output_base}/app_store/screenshot_ipad_129_2048x2732_{i}.jpg")

# Screenshots iPad Pro 11" (1668x2388)
for i in range(1, 3):
    create_screenshot((1668, 2388), f"{output_base}/app_store/screenshot_ipad_11_1668x2388_{i}.jpg")

# Generar documento de referencia
reference = {
    "app_name": "E2v App",
    "bundle_id": "bo.e2v.electropoint",
    "google_play": {
        "icon_512": "icon_512.png (obligatorio)",
        "feature_graphic_1024x500": "feature_graphic_1024x500.jpg (obligatorio, máx 1MB)",
        "screenshots_1080x1920": "Al menos 2, máx 8 (5-8 recomendado)",
        "promo_graphic_480x320": "promo_graphic_480x320.jpg (opcional)",
        "tv_banner": "tv_banner_1280x720.jpg (si es app de TV)"
    },
    "app_store": {
        "icon_1024": "icon_1024.png (obligatorio, sin esquinas redondeadas)",
        "screenshots": {
            "iphone_67_1242x2688": "1-5 screenshots (obligatorio)",
            "iphone_61_1170x2532": "1-5 screenshots (obligatorio)",
            "iphone_55_1080x1920": "1-5 screenshots (opcional)",
            "ipad_129_2048x2732": "1-5 screenshots (opcional)",
            "ipad_11_1668x2388": "1-5 screenshots (opcional)"
        }
    },
    "notes": {
        "google_play": [
            "Todos los gráficos en formato PNG o JPG",
            "Icono: 512x512, sin esquinas redondeadas (Google aplica)",
            "Feature graphic: sin texto o textos simples",
            "Screenshots: máximo 8, recomendado 5+",
            "Dimensiones exactas requeridas"
        ],
        "app_store": [
            "Icono de app: 1024x1024 sin esquinas redondeadas",
            "Screenshots: al menos 1 por dispositivo",
            "Formato: JPEG o PNG",
            "Texto sobre screenshots es recomendado para mostrar features",
            "iPad screenshots son opcionales pero mejoran conversión"
        ]
    }
}

with open(f"{output_base}/REFERENCE.json", "w") as f:
    json.dump(reference, f, indent=2)

print(f"\n✓ Referencia creada: {output_base}/REFERENCE.json")
print(f"\n📦 Todas las imágenes han sido generadas en: {output_base}/")
print(f"\n📋 Resumen:")
print(f"   - Google Play Store: 8 imágenes")
print(f"   - App Store: 14 imágenes")
print(f"   Total: 22 imágenes está listas para subir")

