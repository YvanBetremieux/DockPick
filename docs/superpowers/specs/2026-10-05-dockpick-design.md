# DockPick — Design

Date : 2026-10-05
Statut : validé en conversation, en relecture

## 1. Objectif

Application macOS native (barre de menus) qui, lorsqu'on clique sur l'icône d'une application dans le Dock et que cette application a **au moins 2 fenêtres**, affiche sur l'écran cliqué une vue partagée de ses fenêtres (miniature + titre). Cliquer sur une case active la fenêtre choisie.

Distribution via GitHub Releases (repo public `YvanBetremieux/DockPick`), mises à jour via Sparkle 2.

### Critères de succès

- Clic Dock sur Chrome avec 4 fenêtres → grille 2×2 sur l'écran du curseur, en < 300 ms pour l'affichage des titres.
- Clic sur une case → la bonne fenêtre passe au premier plan selon le mode configuré.
- 0 fenêtre → comportement Dock normal (lancement). 1 fenêtre → comportement Dock normal.
- Une mise à jour vN → vN+1 via Sparkle conserve les permissions Accessibilité / Enregistrement d'écran.
- Aucun commit, tag ou release ne porte d'adresse papernest.

## 2. Contraintes

- macOS 14+ (Sonoma), Swift 6, SwiftUI + AppKit.
- Pas de compte Apple Developer : app signée avec un certificat auto-signé stable, non notarisée.
- Projet généré par XcodeGen (`project.yml` versionné, `.xcodeproj` ignoré).
- Interface en français.
- Identité Git : `Yvan Betremieux <yvan.betremieux@gmail.com>` en config locale du repo ; compte GitHub `YvanBetremieux`.

## 3. Architecture

App `LSUIElement` (pas d'icône Dock), une icône dans la barre de menus.

### Composants

| Composant | Responsabilité | Dépend de |
|---|---|---|
| `DockClickMonitor` | `CGEventTap` sur `leftMouseDown` / `leftMouseUp`. Hit-test AX (`AXUIElementCopyElementAtPosition`) ; si l'élément appartient au process `com.apple.dock` avec le rôle `AXDockItem`, lit `AXURL` → bundle id → `NSRunningApplication`. Consulte `ClickPolicy`. Si interception : avale le mouseDown **et** le mouseUp associé. Réactive le tap sur `tapDisabledByTimeout` / `tapDisabledByUserInput`. | AX, `ClickPolicy`, `WindowCatalog` |
| `ClickPolicy` | Fonction pure : `(enabled, excludedBundleIDs, bundleID, windowCount) → .passThrough \| .showPicker`. Règle : intercepter si activé, non exclu, `windowCount >= 2`. | — |
| `WindowCatalog` | Liste les fenêtres d'une app via AX (`kAXWindowsAttribute` : titre, `AXMinimized`, position, taille, sous-rôle) et les rapproche des `CGWindowID` (`_AXUIElementGetWindow`, repli sur correspondance frame/titre via `CGWindowListCopyWindowInfo`). Filtre : sous-rôle `AXStandardWindow` uniquement ; réduites et autres Spaces selon réglages. Le filtrage est une fonction pure sur un modèle `WindowInfo`. | AX, CoreGraphics, `Settings` |
| `ThumbnailProvider` | Captures ponctuelles via ScreenCaptureKit (`SCShareableContent` + `SCScreenshotManager.captureImage`) à l'ouverture de la vue, en parallèle. Repli : icône de l'app si permission absente, mode « titres seuls », ou fenêtre non capturable (réduite). | ScreenCaptureKit, `Settings` |
| `GridLayout` | Fonction pure : `(count, containerRect, margin, spacing) → [CGRect]`. | — |
| `OverlayController` | `NSPanel` non activant, borderless, niveau `.popUpMenu`, sur l'écran contenant le curseur, fond assombri + flou (`NSVisualEffectView`). Contenu SwiftUI. Ferme sur Échap, clic hors case, ou nouveau clic sur la même icône Dock. | `GridLayout`, `ThumbnailProvider` |
| `WindowActivator` | Dé-réduit si besoin (`AXMinimized = false`), `AXRaise`, `NSRunningApplication.activate`. Puis selon `openMode` : `.focus` (rien de plus), `.maximize` (position/taille AX = `visibleFrame` de l'écran cliqué), `.fullScreen` (`AXFullScreen = true`). | AX, `Settings` |
| `PermissionsManager` | `AXIsProcessTrustedWithOptions`, `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`. Onboarding au premier lancement ; ouverture des panneaux Réglages Système (`x-apple.systempreferences:`). Re-vérifie périodiquement tant que l'Accessibilité manque, puis démarre le monitor. | — |
| `Settings` | Couche typée sur `UserDefaults`, `ObservableObject`. | — |
| `UpdaterController` | Encapsule `SPUStandardUpdaterController` de Sparkle. | Sparkle |
| `Uninstaller` | Désinstallation (voir §5). | `SMAppService`, `Settings` |

### Flux principal

```
mouseDown sur le Dock
  → hit-test AX → AXDockItem ? sinon passer
  → app en cours d'exécution ? sinon passer (lancement normal)
  → WindowCatalog.windows(app) (synchrone, AX, rapide)
  → ClickPolicy → passThrough : renvoyer l'événement
                → showPicker  : avaler mouseDown (+ mouseUp suivant),
                                dispatch main : OverlayController.show(windows, screen)
  → affichage immédiat titres + icônes ; miniatures injectées à l'arrivée
  → clic sur une case (ou Entrée / 1–6) → WindowActivator → fermeture overlay
```

Le callback de l'event tap doit rester court (macOS désactive les taps lents) : le hit-test AX et le comptage de fenêtres sont faits dans le callback avec un timeout AX court (`AXUIElementSetMessagingTimeout` ~0,1 s) ; tout le reste est asynchrone.

### Cas limites

- Accessibilité refusée : monitor inactif, icône barre de menus avec badge d'alerte, menu « Autoriser l'accessibilité… ».
- Enregistrement d'écran refusé : mode titres seuls de fait.
- Fenêtre fermée pendant l'affichage : case retirée au moment de l'activation (échec AX → on rafraîchit la liste ; si < 2, on ferme et on active l'app).
- App qui ne répond pas à AX (timeout) : passer l'événement (ne jamais bloquer le Dock).
- Clic droit / clic prolongé sur le Dock : non interceptés (seul le clic gauche simple l'est).

## 4. Interface

### Grille

| Fenêtres | Disposition |
|---|---|
| 2 | 2 colonnes |
| 3 | 3 colonnes |
| 4 | 2 × 2 |
| 5 | 3 en haut, 2 en bas centrés |
| 6 | 3 × 2 |
| 7+ | lignes de 4 colonnes, dernière ligne centrée |

Zone utile : `visibleFrame` de l'écran avec marge de 48 pt, espacement 24 pt. Lignes de hauteur égale ; les cases d'une ligne incomplète gardent la largeur des cases des lignes pleines et sont centrées.

### Case

Miniature au ratio d'origine, centrée (aspect fit), coins arrondis ; en dessous icône de l'app + titre (une ligne, troncature au milieu). Badge « Réduite » si minimisée. Survol : bordure d'accent + léger zoom (1,03). Clavier : flèches pour naviguer, Entrée pour ouvrir, 1–9 pour sélection directe, Échap pour fermer.

### Barre de menus

- Activer DockPick (coche)
- Rechercher les mises à jour…
- Réglages…  (⌘,)
- Quitter DockPick (⌘Q)

### Réglages (fenêtre SwiftUI à onglets)

| Onglet | Réglage | Défaut |
|---|---|---|
| Général | Activé | oui |
| | Lancer au démarrage (`SMAppService.mainApp`) | non |
| | Action à l'ouverture : Focus seul / Agrandir sur l'écran / Plein écran macOS | Focus seul |
| Affichage | Aperçus en direct / Titres seuls | Aperçus |
| | Inclure les fenêtres réduites | oui |
| | Inclure les fenêtres des autres Spaces | non |
| Apps exclues | Liste éditable (sélecteur d'apps via `NSOpenPanel` sur /Applications) | `com.apple.finder` |
| Mises à jour | Vérifier automatiquement (quotidien) | oui |
| | Installer automatiquement | non |
| | Bouton « Rechercher maintenant », version courante | — |
| Autorisations | État Accessibilité / Enregistrement d'écran + boutons vers Réglages Système | — |
| Avancé | Bouton « Désinstaller DockPick… » | — |

## 5. Distribution et mises à jour

### Identité Git / GitHub

- `git config user.email yvan.betremieux@gmail.com` et `user.name "Yvan Betremieux"` en local au repo.
- Remote : `https://github.com/YvanBetremieux/DockPick.git` ; `gh auth switch --user YvanBetremieux` avant toute opération distante.
- `release.sh` refuse de continuer si `gh api user --jq .login` ≠ `YvanBetremieux` ou si `git config user.email` ≠ l'adresse gmail.

### Signature

- `scripts/setup-signing.sh` (une fois) : crée un certificat auto-signé de signature de code « DockPick Self-Signed » dans le trousseau de session.
- Build signé avec cette identité, hardened runtime, entitlements minimaux (pas de sandbox : l'event tap global et AX l'exigent).
- Identité stable → exigence désignée stable → les autorisations TCC survivent aux mises à jour.

### Sparkle

- Sparkle 2 via Swift Package Manager.
- `SUFeedURL` = `https://github.com/YvanBetremieux/DockPick/releases/latest/download/appcast.xml`.
- `SUPublicEDKey` dans `Info.plist` ; clé privée EdDSA dans le trousseau (`generate_keys`, une fois).
- Les réglages « vérifier / installer automatiquement » pilotent `automaticallyChecksForUpdates` / `automaticallyDownloadsUpdates`.

### `scripts/release.sh <version>`

1. Vérifs : arbre propre, branche `main`, compte `gh` et email Git corrects, tag inexistant.
2. Met à jour `MARKETING_VERSION` et incrémente `CURRENT_PROJECT_VERSION` dans `project.yml`.
3. `xcodegen generate` puis `xcodebuild -configuration Release` (archive), signature avec l'identité auto-signée.
4. `ditto -c -k --keepParent` → `DockPick-<version>.zip` ; `hdiutil` → `DockPick-<version>.dmg` (app + lien /Applications).
5. `generate_appcast` (Sparkle) sur le dossier des zips → `appcast.xml` dont les URLs pointent vers les assets de la release.
6. Commit « Release v<version> », tag `v<version>`, push, `gh release create v<version>` avec DMG, zip, `appcast.xml` et notes générées.

### Première installation

Télécharger le DMG depuis Releases, glisser dans Applications, premier lancement par clic droit → Ouvrir (ou `xattr -dr com.apple.quarantine /Applications/DockPick.app`). Documenté dans le README.

### Désinstallation

Confirmation → `SMAppService.mainApp.unregister()` → suppression du domaine `UserDefaults` → `tccutil reset Accessibility <bundle id>` et `tccutil reset ScreenCapture <bundle id>` → déplacement de l'app dans la Corbeille (`NSWorkspace.recycle`) → quitter.

## 6. Tests

### Unitaires (XCTest, cible `DockPickTests`)

- `GridLayout` : 1 à 8 fenêtres, plusieurs tailles d'écran ; aucune case hors zone, aucun chevauchement, centrage des lignes incomplètes, disposition attendue pour 2/3/4/5/6.
- `ClickPolicy` : toutes les combinaisons activé / exclu / nombre de fenêtres.
- Filtrage `WindowCatalog` sur des `WindowInfo` simulés : sous-rôles, réduites, autres Spaces.
- `Settings` : valeurs par défaut, persistance (suite `UserDefaults` dédiée).

### Vérification manuelle (checklist dans le README)

Chrome 2→6 fenêtres ; multi-écran (vue sur l'écran du clic) ; fenêtres réduites ; app exclue ; app non lancée ; permissions refusées ; trois modes d'ouverture ; navigation clavier ; mise à jour Sparkle v0.1.0 → v0.1.1 avec permissions conservées ; désinstallation.

## 7. Hors périmètre (v1)

Notarisation Apple, CI GitHub Actions, localisation autre que le français, raccourci clavier global, prévisualisation au survol du Dock.
