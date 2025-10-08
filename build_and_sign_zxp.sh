#!/usr/bin/env bash
# build_and_sign_zxp.sh
# macOS bash script to bump manifest versions, ensure dev-mode, self-sign (if needed),
# and produce a .zxp for your Premiere CEP extension.
#
# Usage:
#   chmod +x build_and_sign_zxp.sh
#   ./build_and_sign_zxp.sh
#
# Notes:
# - Adjust ZXPSIGNCMD_PATH and EXTENSION_FOLDER if your paths differ.
# - This script targets a *per‑user* CEP install path by default. If you keep your
#   extension under /Library/... instead, change EXTENSION_FOLDER accordingly.

set -euo pipefail

# -----------------------------
# CONFIG
# -----------------------------
# ZXPSignCmd 4.1.3 binary
ZXPSIGNCMD_PATH="/Users/kevincburke/Documents/CEP-Resources-master/ZXPSignCMD/4.1.3/macOS/ZXPSignCmd"

# Your extension root (folder that contains index.html and CSXS/manifest.xml)
EXTENSION_FOLDER="/Library/Application Support/Adobe/CEP/extensions/com.blastframe"

# Where to write the signed .zxp
DOWNLOADS_DIR="$HOME/Downloads"

# Self-signed certificate location + password
CERT_FILE="/Users/kevincburke/Documents/StoryPen.p12"
CERT_PASSWORD="password"

# Timestamp server (prevents immediate signature expiry warnings)
TSA_URL="http://timestamp.digicert.com"

# CSXS dev mode versions to enable (most current Premiere uses CSXS.11)
CSXS_KEYS=(11 10 9)

# -----------------------------
# HELPERS
# -----------------------------
msg(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
die(){ echo -e "\033[1;31m[ERR ]\033[0m $*"; exit 1; }

require(){ command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

# Escape replacement string for sed (BSD/mac compatible)
sed_inplace(){
  local file="$1"; shift
  # shellcheck disable=SC2145
  sed -E -i.bak "$@" "$file"
}

bump_patch(){
  local ver="$1"
  if [[ "$ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    local MAJ="${BASH_REMATCH[1]}" MIN="${BASH_REMATCH[2]}" PAT="${BASH_REMATCH[3]}"
    echo "${MAJ}.${MIN}.$((PAT+1))"
  else
    die "Not a semver (x.y.z): '$ver'"
  fi
}

# -----------------------------
# PRECHECKS
# -----------------------------
[[ -x "$ZXPSIGNCMD_PATH" ]] || die "ZXPSignCmd not found or not executable at: $ZXPSIGNCMD_PATH"
[[ -d "$EXTENSION_FOLDER" ]] || die "Extension folder not found: $EXTENSION_FOLDER"
[[ -f "$EXTENSION_FOLDER/CSXS/manifest.xml" ]] || die "manifest.xml not found under $EXTENSION_FOLDER/CSXS"

require grep
require sed
require awk

MANIFEST_FILE="$EXTENSION_FOLDER/CSXS/manifest.xml"

# -----------------------------
# ENABLE DEV MODE (loads unsigned panels from file system)
# -----------------------------
for key in "${CSXS_KEYS[@]}"; do
  defaults write "com.adobe.CSXS.$key" PlayerDebugMode -int 1 || true
done
msg "Enabled PlayerDebugMode for CSXS: ${CSXS_KEYS[*]} (restart Premiere if running)."

# -----------------------------
# READ CURRENT IDS/VERSIONS FROM MANIFEST
# -----------------------------
# Example target lines:
#   <ExtensionManifest ExtensionBundleId="com.blastframe" ExtensionBundleVersion="1.0.0" ...>
#   <Extension Id="com.blastframe.panel" Version="1.0.0"/>

EXT_LINE=$(grep -oE '<Extension Id="[^"]+" Version="[0-9]+\.[0-9]+\.[0-9]+"' "$MANIFEST_FILE" | head -n1 || true)
[[ -n "$EXT_LINE" ]] || die "Could not locate <Extension Id=... Version=...> line in manifest."

EXTENSION_ID=$(echo "$EXT_LINE" | sed -E 's/^<Extension Id="([^"]+)".*/\1/')
EXT_VER=$(echo "$EXT_LINE" | sed -E 's/.*Version="([0-9]+\.[0-9]+\.[0-9]+)"/\1/')

BUNDLE_VER=$(grep -oE 'ExtensionBundleVersion="[0-9]+\.[0-9]+\.[0-9]+"' "$MANIFEST_FILE" | head -n1 | sed -E 's/.*="([0-9]+\.[0-9]+\.[0-9]+)"/\1/' || true)
[[ -n "$BUNDLE_VER" ]] || die "Could not read ExtensionBundleVersion from manifest."

msg "Extension Id:   $EXTENSION_ID"
msg "Extension Ver:  $EXT_VER"
msg "Bundle Version: $BUNDLE_VER"

# -----------------------------
# BUMP PATCH VERSIONS
# -----------------------------
NEW_EXT_VER=$(bump_patch "$EXT_VER")
NEW_BUNDLE_VER=$(bump_patch "$BUNDLE_VER")

msg "Bumping versions: $EXT_VER → $NEW_EXT_VER, $BUNDLE_VER → $NEW_BUNDLE_VER"

# Update ExtensionBundleVersion
sed_inplace "$MANIFEST_FILE" "s/ExtensionBundleVersion=\"$BUNDLE_VER\"/ExtensionBundleVersion=\"$NEW_BUNDLE_VER\"/g"

# Update the specific <Extension Id="..." Version="x.y.z">
sed_inplace "$MANIFEST_FILE" "s/(<Extension Id=\"$EXTENSION_ID\" Version=\")$EXT_VER(\")/\1$NEW_EXT_VER\2/"

# Optionally also bump the top-level ExtensionBundleName Version (schema version) —
# we intentionally do NOT touch it (it's 'Version="7.0"').

# -----------------------------
# CERTIFICATE (create if missing)
# -----------------------------
if [[ ! -f "$CERT_FILE" ]]; then
  warn "Certificate missing; creating a new self‑signed cert at $CERT_FILE"
  # ZXPSignCmd 4.1.3 syntax: -selfSignedCert <country> <state> <org> <commonName> <password> <output.p12> [-validityDays N]
  "$ZXPSIGNCMD_PATH" -selfSignedCert US NC "Blastframe" "Blastframe Dev Cert" "$CERT_PASSWORD" "$CERT_FILE" -validityDays 3650
  msg "Self‑signed certificate created."
fi

# -----------------------------
# SIGN → .ZXP
# -----------------------------
BASENAME_SAFE=$(echo "$EXTENSION_ID" | tr '/:' '__')
ZXP_OUT="$DOWNLOADS_DIR/${BASENAME_SAFE}-${NEW_EXT_VER}.zxp"

msg "Signing extension folder → $ZXP_OUT"
"$ZXPSIGNCMD_PATH" -sign "$EXTENSION_FOLDER" "$ZXP_OUT" "$CERT_FILE" "$CERT_PASSWORD" -tsa "$TSA_URL"

# Verify signature
msg "Verifying ZXP signature..."
"$ZXPSIGNCMD_PATH" -verify "$ZXP_OUT" >/dev/null && msg "Signature OK: $ZXP_OUT"

# -----------------------------
# DONE
# -----------------------------
msg "Build successful. ZXP: $ZXP_OUT"
msg "Tip: Install with ZXP Installer, or keep developing from the file‑system path."

# Optional: auto-open ZXP Installer if installed
if [[ -d "/Applications/ZXP Installer.app" ]]; then
  open -a "/Applications/ZXP Installer.app" "$ZXP_OUT" || true
fi
    echo "manifest.xml not found at $MANIFEST_FILE"
fi
echo "Starting CEP build process for BlastframePremiereProPanel..."
echo "----------------------------------------"

# Navigate to the parent directory of the extension folder to package it correctly.
cd "$(dirname "$EXTENSION_FOLDER")" || { echo "Error: Parent directory not found."; exit 1; }

echo "Cleaning up old .zip and .zxp files in $DOWNLOADS_DIR..."
rm -f "$ZIP_FILE" "$ZXP_FILE"

# Create a self-signed certificate if one doesn't exist at CERT_FILE path.
if [ ! -f "$CERT_FILE" ]; then
    echo "Certificate not found at $CERT_FILE. Creating a new self-signed certificate..."
    "${ZXPSIGNCMD_PATH}" -selfSignedCert "US" "CA" "BlastFrame" "BlastframePremiereProPanel_DevCert" "${CERT_PASSWORD}" "$CERT_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create certificate. Exiting."
        exit 1
    fi
    echo "Certificate created successfully: $CERT_FILE"
fi


echo "Creating a clean zip archive in $DOWNLOADS_DIR, excluding build.sh..."
zip -r "${ZIP_FILE}" "BlastframePremiereProPanel_CEP" -x "BlastframePremiereProPanel_CEP/build.sh" "BlastframePremiereProPanel/build.sh"


echo "Packaging and signing the extension to $DOWNLOADS_DIR..."
"${ZXPSIGNCMD_PATH}" -sign "BlastframePremiereProPanel_CEP" "${ZXP_FILE}" "$CERT_FILE" "${CERT_PASSWORD}"

# Delete the zip after zxp creation
if [ -f "$ZIP_FILE" ]; then
    rm "$ZIP_FILE"
    echo "Deleted zip archive: $ZIP_FILE"
fi

# Check the exit code of the last command to see if it was successful.
if [ $? -eq 0 ]; then
    echo "----------------------------------------"
    echo "Build successful!"
    echo "Your signed extension is located at: ${ZXP_FILE}"
    echo "You can now share this .zxp file or install it with a tool like ZXPInstaller."
    
    # Attempt to open the signed .zxp with ZXP Installer
    echo "Attempting to open the signed .zxp with ZXP Installer: ${ZXP_FILE}"
    ZXP_INSTALLER_APP="/Applications/ZXP Installer.app"
    if [ -d "$ZXP_INSTALLER_APP" ]; then
        open -a "$ZXP_INSTALLER_APP" "$ZXP_FILE" >/dev/null 2>&1 && echo "ZXP Installer launched." || echo "Failed to launch ZXP Installer."
    else
        echo "ZXP Installer not found at $ZXP_INSTALLER_APP"
        echo "Please install ZXP Installer or open the .zxp file manually: ${ZXP_FILE}"
    fi
    
        # Start a simple static server for the panel and open it in the browser
        echo "Starting dev static server for panel..."
        cd "$EXTENSION_FOLDER/panel" || true

        # Kill any existing BlastframePremiereProPanel static servers started by this script
        for PIDFILE in /tmp/BlastframePremiereProPanel_http_*.pid; do
            if [ -f "$PIDFILE" ]; then
                OLDPID=$(cat "$PIDFILE" 2>/dev/null || true)
                # try to extract port from filename
                OLDPORT=$(echo "$PIDFILE" | sed -E 's/.*BlastframePremiereProPanel_http_([0-9]+)\.pid$/\1/')
                if [ -n "$OLDPID" ] && kill -0 "$OLDPID" >/dev/null 2>&1; then
                    # ensure the process looks like a python http.server
                    CMD=$(ps -p "$OLDPID" -o args= 2>/dev/null || true)
                    if echo "$CMD" | grep -q "http.server"; then
                        echo "Killing existing BlastframePremiereProPanel server (PID $OLDPID, port ${OLDPORT})..."
                        kill "$OLDPID" >/dev/null 2>&1 || true
                        sleep 0.2
                        if kill -0 "$OLDPID" >/dev/null 2>&1; then
                            kill -9 "$OLDPID" >/dev/null 2>&1 || true
                        fi
                    else
                        echo "Found pidfile $PIDFILE but process $OLDPID is not http.server; skipping kill."
                    fi
                fi
                rm -f "$PIDFILE"
                # also remove the associated log file if present
                if [ -n "$OLDPORT" ]; then
                    rm -f "/tmp/BlastframePremiereProPanel_http_${OLDPORT}.log"
                fi
            fi
        done

        PORT=8000
        while lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; do
            PORT=$((PORT+1))
            if [ $PORT -gt 8100 ]; then
                echo "ERROR: no free port found in 8000-8100"; break
            fi
        done
        if [ $PORT -le 8100 ]; then
            echo "Using port $PORT for static server"
            python3 -m http.server "$PORT" >/tmp/BlastframePremiereProPanel_http_${PORT}.log 2>&1 &
            PID=$!
            echo $PID > /tmp/BlastframePremiereProPanel_http_${PORT}.pid
            sleep 0.5
            open "http://localhost:$PORT/index.html" || true
            echo "SERVER_PID=$PID PORT=$PORT LOG=/tmp/BlastframePremiereProPanel_http_${PORT}.log PIDFILE=/tmp/BlastframePremiereProPanel_http_${PORT}.pid"
        fi
else
    echo "----------------------------------------"
    echo "Build failed. Check the logs for errors."
    exit 1
fi

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Deploy built CSXS and panel folders into system CEP extensions (overwrites target)
# -----------------------------------------------------------------------------
# TARGET_EXT="/Library/Application Support/Adobe/CEP/extensions/BlastframePremiereProPanel"

# echo "Deploying built CSXS and panel to $TARGET_EXT (requires sudo)..."
# # Ensure the parent directory exists
# sudo mkdir -p "$(dirname "$TARGET_EXT")"
# # Create target folder if missing
# sudo mkdir -p "$TARGET_EXT"

# if [ -d "$EXTENSION_FOLDER/CSXS" ]; then
#     echo "Replacing CSXS..."
#     sudo rm -rf "$TARGET_EXT/CSXS"
#     sudo cp -R "$EXTENSION_FOLDER/CSXS" "$TARGET_EXT/"
#     if [ $? -ne 0 ]; then
#         echo "Error copying CSXS to $TARGET_EXT"
#     else
#         echo "CSXS deployed."
#     fi
# fi

# if [ -d "$EXTENSION_FOLDER/panel" ]; then
#     echo "Replacing panel..."
#     sudo rm -rf "$TARGET_EXT/panel"
#     sudo cp -R "$EXTENSION_FOLDER/panel" "$TARGET_EXT/"
#     if [ $? -ne 0 ]; then
#         echo "Error copying panel to $TARGET_EXT"
#     else
#         echo "panel deployed."
#     fi
# fi

echo "Deployment complete."
