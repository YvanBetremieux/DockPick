# DockPick

Clic sur une icône du Dock → si l'app a au moins 2 fenêtres, DockPick affiche toutes ses fenêtres côte à côte (aperçu + titre) sur l'écran cliqué. Un clic sur une fenêtre l'ouvre.

## Installation

1. Télécharger `DockPick-x.y.z.dmg` depuis les [Releases](https://github.com/YvanBetremieux/DockPick/releases/latest).
2. Glisser **DockPick** dans **Applications**.
3. Premier lancement : clic droit sur DockPick › **Ouvrir** (l'app n'est pas notarisée par Apple).
   Ou : `xattr -dr com.apple.quarantine /Applications/DockPick.app`
4. Accorder **Accessibilité** (obligatoire) et **Enregistrement d'écran** (aperçus) via la fenêtre d'accueil.

Les mises à jour suivantes s'installent depuis le menu › **Rechercher les mises à jour…** ou automatiquement.

## Utilisation

| Fenêtres | Disposition |
|---|---|
| 2 | côte à côte |
| 3 | 3 colonnes |
| 4 | 2 × 2 |
| 5 | 3 + 2 |
| 6 | 3 × 2 |

Clavier : flèches + Entrée, touches 1–9, Échap pour fermer. ⌘/⌥-clic et double-clic sur le Dock gardent leur comportement normal.

## Développement

```bash
brew install xcodegen
scripts/setup-signing.sh   # une fois : certificat « DockPick Self-Signed »
scripts/test.sh            # tests unitaires
scripts/run.sh             # build Debug + lancement
```

Logs : `/usr/bin/log stream --predicate 'subsystem == "io.github.yvanbetremieux.DockPick"' --level debug`

## Publier une version

```bash
scripts/release.sh 0.2.0
```

Le script vérifie l'identité Git et le compte `gh`, compile et signe, crée le DMG et le zip, génère `appcast.xml` (Sparkle, clé du trousseau sous le compte `dockpick`) et publie la release GitHub.

## Checklist de vérification manuelle

- [ ] Chrome avec 2, 3, 4, 5, 6 fenêtres → bonne disposition, bons titres, aperçus.
- [ ] 1 fenêtre / app non lancée → comportement Dock normal.
- [ ] Finder (exclu par défaut) → comportement normal.
- [ ] ⌘-clic, ⌥-clic, clic droit, glisser sur le Dock → inchangés.
- [ ] Corbeille, dossiers du Dock → inchangés.
- [ ] Multi-écran : la vue s'ouvre sur l'écran cliqué ; « Agrandir » vise cet écran.
- [ ] Fenêtre réduite → badge, dé-réduite au clic.
- [ ] Les trois modes d'ouverture.
- [ ] Clavier : flèches, Entrée, 1–9, Échap ; re-clic sur l'icône ferme la vue.
- [ ] Autorisations refusées → onboarding, icône ⚠︎, pas d'interception.
- [ ] Mise à jour Sparkle vN → vN+1 : les autorisations sont conservées.
- [ ] Désinstallation : app à la Corbeille, plus dans Ouverture, autorisations retirées.
