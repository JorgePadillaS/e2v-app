#!/usr/bin/env zsh
set -euo pipefail

# Script para eliminar los placeholders antiguos y commitear las copias archivadas.
# Úsalo desde la raíz del repo (se asume que este fichero está en ./scripts/).
# Cómo usar:
#   chmod +x ./scripts/remove_old_placeholders.sh
#   ./scripts/remove_old_placeholders.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILES=(
  "android/app/src/main/kotlin/com/evbol/e2v_app/MainActivity.kt"
  "android/app/src/main/kotlin/com/evbol/e2v_app/NfcHceService.kt"
)

# Mostrar estado y confirmar antes de ejecutar
echo "Repositorio: $REPO_ROOT"
echo "Archivos objetivo a eliminar del VCS:"
for f in "${FILES[@]}"; do
  echo "  - $f"
done

read "?Confirmas que quieres eliminar estos placeholders del control de versiones y commitear las copias archivadas? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Abortado por el usuario. No se realizaron cambios."
  exit 1
fi

# Eliminar cada archivo si existe
any_removed=false
for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "git rm '$f'"
    git rm "$f"
    any_removed=true
  else
    echo "No existe: $f (se omite)"
  fi
done

# Añadir los archivos archivados (si los quieres en el repo)
ARCHIVE_DIR="android/app/src/main/kotlin/old"
if [ -d "$ARCHIVE_DIR" ]; then
  echo "git add '$ARCHIVE_DIR'"
  git add "$ARCHIVE_DIR"
else
  echo "No se encontró el directorio de archivo: $ARCHIVE_DIR"
fi

# Crear commit solo si hay cambios
if git diff --cached --quiet; then
  echo "No hay cambios para commitear."
else
  echo "git commit -m 'Archive old Kotlin files and remove com.evbol.e2v_app placeholders'"
  git commit -m "Archive old Kotlin files and remove com.evbol.e2v_app placeholders"
  echo "git push"
  git push
fi

echo "Hecho. Revisa 'git log -n 5' o 'git status' para verificar."
