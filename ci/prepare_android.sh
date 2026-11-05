#!/usr/bin/env bash
# Prépare l'export Android dans la CI (conteneur barichello/godot-ci) :
#   - modèles d'export, SDK, clé de debug, réglages éditeur
#   - clé d'importation Play Store si UPLOAD_KEYSTORE_BASE64 est fourni
#   - binaires Android des plugins AdMob et Google Play Billing
# Usage : ci/prepare_android.sh   (depuis la racine du projet ; GODOT_VERSION défini)
set -euo pipefail

: "${GODOT_VERSION:?GODOT_VERSION manquant}"
ADMOB_VERSION="v5.1.0"     # poingstudios/godot-admob-plugin
BILLING_VERSION="3.3.0"    # godot-sdk-integrations/godot-google-play-billing
MINOR="${GODOT_VERSION%.*}"

# --- Godot : modèles, SDK, clés ---
mkdir -p ~/.local/share/godot/export_templates ~/.config/godot
if [ -d "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" ] && [ "$HOME" != "/root" ]; then
  cp -r "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" ~/.local/share/godot/export_templates/
fi
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/lib/android-sdk}}"
echo "SDK Android : $SDK"

DKS="$HOME/debug.keystore"
[ -f "$DKS" ] || keytool -genkeypair -keystore "$DKS" -storepass android -alias androiddebugkey \
  -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"

for f in editor_settings-4.tres "editor_settings-${MINOR}.tres"; do
  cat > ~/.config/godot/$f <<EOS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "${JAVA_HOME:-}"
export/android/debug_keystore = "$DKS"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOS
done

ENV_OUT="${GITHUB_ENV:-/dev/null}"
{
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$DKS"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
} >> "$ENV_OUT"

if [ -n "${UPLOAD_KEYSTORE_BASE64:-}" ]; then
  KS="$HOME/upload.keystore"
  echo "$UPLOAD_KEYSTORE_BASE64" | base64 -d > "$KS"
  {
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS"
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_USER=${UPLOAD_KEY_ALIAS:?UPLOAD_KEY_ALIAS manquant}"
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=${UPLOAD_KEYSTORE_PASSWORD:?UPLOAD_KEYSTORE_PASSWORD manquant}"
  } >> "$ENV_OUT"
fi

# --- Téléchargement d'un asset de release GitHub (par motif de nom) ---
asset_url() { # $1 = owner/repo  $2 = tag  $3 = regex du nom
  local auth=()
  [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  curl -fsSL "${auth[@]}" "https://api.github.com/repos/$1/releases/tags/$2" \
    | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$3" | head -1
}

TMP="$(mktemp -d)"

# --- AdMob : binaires Android pour cette version de Godot ---
ADMOB_BIN="addons/admob/android/bin"
if [ ! -f "$ADMOB_BIN/package.gd" ]; then
  URL="$(asset_url poingstudios/godot-admob-plugin "$ADMOB_VERSION" "android-template-v${GODOT_VERSION}\.zip$")"
  [ -n "$URL" ] || { echo "::error::AdMob $ADMOB_VERSION : pas de binaire pour Godot $GODOT_VERSION"; exit 1; }
  echo "AdMob : $URL"
  curl -fsSL -o "$TMP/admob.zip" "$URL"
  mkdir -p "$ADMOB_BIN"
  unzip -oq "$TMP/admob.zip" -d "$ADMOB_BIN"
  test -f "$ADMOB_BIN/package.gd"
fi

# --- Google Play Billing : AAR debug et release ---
BILL="addons/GodotGooglePlayBilling"
if [ ! -d "$BILL/bin" ]; then
  URL="$(asset_url godot-sdk-integrations/godot-google-play-billing "$BILLING_VERSION" '\.zip$')"
  [ -n "$URL" ] || { echo "::error::Billing $BILLING_VERSION : asset introuvable"; exit 1; }
  echo "Billing : $URL"
  curl -fsSL -o "$TMP/billing.zip" "$URL"
  unzip -oq "$TMP/billing.zip" -d "$TMP/billing"
  SRC="$(dirname "$(find "$TMP/billing" -path '*/bin/release/*.aar' | head -1)")"
  [ -n "$SRC" ] && [ "$SRC" != "." ] || { echo "::error::AAR Billing introuvable dans l'archive"; find "$TMP/billing" | head -30; exit 1; }
  cp -r "$(dirname "$SRC")" "$BILL/bin"
  ls -R "$BILL/bin"
fi

rm -rf "$TMP"
echo "Préparation Android terminée."
