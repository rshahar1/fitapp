#!/usr/bin/env bash
# Creates a release keystore OUTSIDE the repo and writes android/key.properties.
# Run interactively in your own terminal. Usage: tool/make_release_keystore.sh [keystore-path]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="${1:-$HOME/keys/fitapp-release.jks}"
ALIAS="fitapp"
PROPS="$REPO_ROOT/android/key.properties"

if [[ -x "$HOME/development/jdk-17/Contents/Home/bin/keytool" ]]; then
  KEYTOOL="$HOME/development/jdk-17/Contents/Home/bin/keytool"
elif command -v keytool >/dev/null 2>&1; then
  KEYTOOL="$(command -v keytool)"
elif [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/keytool" ]]; then
  KEYTOOL="$JAVA_HOME/bin/keytool"
else
  echo "keytool not found (install a JDK or set JAVA_HOME)." >&2
  exit 1
fi

if [[ -e "$KEYSTORE" ]]; then
  echo "Refusing to overwrite existing keystore: $KEYSTORE" >&2
  exit 1
fi
if [[ -e "$PROPS" ]]; then
  echo "Refusing to overwrite existing $PROPS" >&2
  exit 1
fi

mkdir -p "$(dirname "$KEYSTORE")"
KEYSTORE="$(cd "$(dirname "$KEYSTORE")" && pwd)/$(basename "$KEYSTORE")"

read -r -p "Certificate name (CN) [FitApp]: " CN
CN="${CN:-FitApp}"
if [[ "$CN" == *[,=\\+\<\>\#\;\"]* ]]; then
  echo "Name must not contain , = + < > # ; \" or backslash." >&2
  exit 1
fi

read -r -s -p "Keystore password (min 8 chars): " PW1; echo
read -r -s -p "Repeat password: " PW2; echo
if [[ "$PW1" != "$PW2" ]]; then
  echo "Passwords do not match." >&2
  exit 1
fi
if [[ ${#PW1} -lt 8 ]]; then
  echo "Password must be at least 8 characters." >&2
  exit 1
fi

export FITAPP_STOREPASS="$PW1"
"$KEYTOOL" -genkeypair -v \
  -keystore "$KEYSTORE" -storetype JKS \
  -alias "$ALIAS" -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=$CN" \
  -storepass:env FITAPP_STOREPASS -keypass:env FITAPP_STOREPASS

umask 077
{
  echo "storeFile=$KEYSTORE"
  echo "storePassword=$PW1"
  echo "keyAlias=$ALIAS"
  echo "keyPassword=$PW1"
} > "$PROPS"
chmod 600 "$PROPS"
echo "Wrote $PROPS (git-ignored)."

echo
echo "Release certificate SHA-1:"
"$KEYTOOL" -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass:env FITAPP_STOREPASS | grep -E 'SHA1' || true
unset FITAPP_STOREPASS PW1 PW2

cat <<MSG

Next steps:
  1. BACK UP $KEYSTORE and its password somewhere safe (password manager + offline copy).
     If you lose either, you can never ship updates to installed apps.
  2. Add the SHA-1 above as an Android OAuth client (package com.fitapp.app) in
     Google Cloud Console > APIs & Services > Credentials, or Google sign-in fails in release builds.
  See docs/release.md.
MSG
