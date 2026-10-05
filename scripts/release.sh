#!/usr/bin/env bash
# Usage : scripts/release.sh 0.2.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
REPO="YvanBetremieux/DockPick"
GH_USER="YvanBetremieux"
GIT_EMAIL="yvan.betremieux@gmail.com"
IDENTITY="DockPick Self-Signed"
SPARKLE_ACCOUNT="dockpick"

fail() { echo "❌ $*" >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Usage : scripts/release.sh X.Y.Z"
[[ -z "$(git status --porcelain)" ]] || fail "L'arbre de travail n'est pas propre"
[[ "$(git branch --show-current)" == "main" ]] || fail "Il faut être sur main"
[[ "$(git config user.email)" == "$GIT_EMAIL" ]] || fail "git user.email doit être $GIT_EMAIL"
if git log --format='%ae%n%ce' | grep -qi papernest; then fail "Un commit contient une adresse papernest"; fi
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then fail "Le tag v$VERSION existe déjà"; fi
security find-identity -v -p codesigning | grep -q "$IDENTITY" || fail "Identité « $IDENTITY » absente : lancer scripts/setup-signing.sh"

PREVIOUS_GH_USER="$(gh api user --jq .login)"
restore_gh() {
  if [[ "$PREVIOUS_GH_USER" != "$GH_USER" ]]; then
    gh auth switch --hostname github.com --user "$PREVIOUS_GH_USER" >/dev/null 2>&1 || true
  fi
}
trap restore_gh EXIT
gh auth switch --hostname github.com --user "$GH_USER" >/dev/null
[[ "$(gh api user --jq .login)" == "$GH_USER" ]] || fail "Le compte gh actif n'est pas $GH_USER"

# Version
CURRENT_BUILD="$(sed -nE 's/^ *CURRENT_PROJECT_VERSION: "?([0-9]+)"?.*/\1/p' project.yml)"
BUILD=$((CURRENT_BUILD + 1))
sed -i '' -E "s/^( *MARKETING_VERSION: ).*/\1\"$VERSION\"/" project.yml
sed -i '' -E "s/^( *CURRENT_PROJECT_VERSION: ).*/\1\"$BUILD\"/" project.yml

# Build
rm -rf build/release
mkdir -p build/release/archives build/release/dmg
xcodegen generate --quiet
xcodebuild build -project DockPick.xcodeproj -scheme DockPick -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData -quiet
APP="build/DerivedData/Build/Products/Release/DockPick.app"
codesign --verify --deep --strict "$APP"
SIGNATURE="$(codesign -dv "$APP" 2>&1)"
[[ "$SIGNATURE" == *"Authority=$IDENTITY"* ]] || fail "L'app n'est pas signée avec « $IDENTITY »"

# Archives
ZIP="build/release/archives/DockPick-$VERSION.zip"
DMG="build/release/DockPick-$VERSION.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
cp -R "$APP" build/release/dmg/
ln -s /Applications build/release/dmg/Applications
hdiutil create -volname DockPick -srcfolder build/release/dmg -ov -format UDZO "$DMG" -quiet

# Appcast signé (clé EdDSA du trousseau, compte « dockpick »)
GENERATE_APPCAST="$(find build/DerivedData/SourcePackages/artifacts -type f -name generate_appcast -perm -u+x | head -1)"
[[ -n "$GENERATE_APPCAST" ]] || fail "generate_appcast introuvable"
"$GENERATE_APPCAST" --account "$SPARKLE_ACCOUNT" \
  --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
  --link "https://github.com/$REPO" \
  -o build/release/appcast.xml build/release/archives
grep -q "sparkle:edSignature" build/release/appcast.xml || fail "appcast.xml n'est pas signé"

# Git + release
git add project.yml
git commit -m "Release v$VERSION"
git tag -a "v$VERSION" -m "DockPick $VERSION"
git push origin main "v$VERSION"
gh release create "v$VERSION" --repo "$REPO" --title "DockPick $VERSION" --generate-notes \
  "$DMG" "$ZIP" build/release/appcast.xml
echo "✅ https://github.com/$REPO/releases/tag/v$VERSION"
