#!/usr/bin/env python3
"""
Script para añadir texto personalizado a screenshots
Mejora la conversión mostrando features principales
"""

import os
from PIL import Image, ImageDraw, ImageFont

def add_text_to_screenshot(input_path, output_path, title, subtitle=""):
    """
    Añade texto a un screenshot

    Args:
        input_path: Ruta del screenshot original
        output_path: Ruta de salida
        title: Texto principal (grande)
        subtitle: Texto secundario (más pequeño)
    """

    img = Image.open(input_path)
    width, height = img.size
    draw = ImageDraw.Draw(img)

    # Intentar cargar fuente del sistema
    try:
        # macOS
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", int(height * 0.08))
        subtitle_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", int(height * 0.05))
    except:
        try:
            # Linux/Fallback
            title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(height * 0.08))
            subtitle_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", int(height * 0.05))
        except:
            # Usar fuente por defecto
            title_font = ImageFont.load_default()
            subtitle_font = ImageFont.load_default()

    # Colores
    text_color = (255, 255, 255)  # Blanco
    shadow_color = (0, 0, 0)  # Negro para sombra

    # Posición
    y_offset = int(height * 0.15)

    # Dibujar sombra para título
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2

    # Sombra (offset 2 pixeles)
    draw.text((title_x + 2, y_offset + 2), title, font=title_font, fill=shadow_color)
    # Texto principal
    draw.text((title_x, y_offset), title, font=title_font, fill=text_color)

    # Subtítulo si existe
    if subtitle:
        y_offset_sub = y_offset + int(height * 0.1)
        subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
        subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
        subtitle_x = (width - subtitle_width) // 2

        # Sombra
        draw.text((subtitle_x + 2, y_offset_sub + 2), subtitle, font=subtitle_font, fill=shadow_color)
        # Texto
        draw.text((subtitle_x, y_offset_sub), subtitle, font=subtitle_font, fill=text_color)

    img.save(output_path, "JPEG", quality=95)
    print(f"✓ Creado: {output_path}")

# Definir textos para cada screenshot
screenshots_config = [
    {
        "name": "1",
        "title": "Escanea Instantáneamente",
        "subtitle": "Código QR en segundos"
    },
    {
        "name": "2",
        "title": "Gestiona tu Historial",
        "subtitle": "Acceso rápido a tus códigos"
    },
    {
        "name": "3",
        "title": "100% Seguro",
        "subtitle": "Sin anuncios ni rastreo"
    }
]

# Crear directorio de screenshots con texto
output_dir_gp = "store_assets/google_play/with_text"
output_dir_as = "store_assets/app_store/with_text"
os.makedirs(output_dir_gp, exist_ok=True)
os.makedirs(output_dir_as, exist_ok=True)

print("📱 Procesando screenshots de Google Play Store con texto...\n")

# Google Play Screenshots (1080x1920)
for config in screenshots_config:
    input_file = f"store_assets/google_play/screenshot_{config['name']}_1080x1920.jpg"
    output_file = f"{output_dir_gp}/screenshot_{config['name']}_1080x1920_with_text.jpg"

    if os.path.exists(input_file):
        add_text_to_screenshot(
            input_file,
            output_file,
            config['title'],
            config['subtitle']
        )
    else:
        print(f"⚠️  Archivo no encontrado: {input_file}")

print("\n🍎 Procesando screenshots de App Store con texto...\n")

# iPhone 6.7" Screenshots
for config in screenshots_config:
    input_file = f"store_assets/app_store/screenshot_iphone_67_1242x2688_{config['name']}.jpg"
    output_file = f"{output_dir_as}/screenshot_iphone_67_1242x2688_{config['name']}_with_text.jpg"

    if os.path.exists(input_file):
        add_text_to_screenshot(
            input_file,
            output_file,
            config['title'],
            config['subtitle']
        )

# iPhone 6.1" Screenshots
for config in screenshots_config:
    input_file = f"store_assets/app_store/screenshot_iphone_61_1170x2532_{config['name']}.jpg"
    output_file = f"{output_dir_as}/screenshot_iphone_61_1170x2532_{config['name']}_with_text.jpg"

    if os.path.exists(input_file):
        add_text_to_screenshot(
            input_file,
            output_file,
            config['title'],
            config['subtitle']
        )

print(f"\n✓ Screenshots con texto generados en:")
print(f"   - {output_dir_gp}/")
print(f"   - {output_dir_as}/")
print(f"\n💡 Estos screenshots con texto mejoran la conversión")
print(f"   Usa estos en lugar de los originales para mejor marketing")

