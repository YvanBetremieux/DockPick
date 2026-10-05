#!/usr/bin/env bash
# Crée une fois pour toutes l'identité de signature auto-signée « DockPick Self-Signed ».
# Une identité stable permet à macOS de conserver les autorisations entre les mises à jour.
set -euo pipefail

NAME="DockPick Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "✅ Identité « $NAME » déjà présente."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NAME
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

# LibreSSL système : produit un .p12 que `security import` accepte.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf"
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/identity.p12" -passout pass:dockpick

security import "$TMP/identity.p12" -k "$KEYCHAIN" -P dockpick -T /usr/bin/codesign
# Demande le mot de passe de session : marque le certificat comme fiable pour la signature de code.
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

security find-identity -v -p codesigning | grep "$NAME"
echo "✅ Identité « $NAME » créée."
