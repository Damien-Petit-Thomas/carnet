# carnet

Prise de notes markdown en ligne de commande : **fzf** pour choisir, **vim** (ou ton `$EDITOR`) pour écrire, **mkdocs** (optionnel) pour relire tes notes comme un site.

Un script bash, des fichiers markdown dans un dossier, rien d'autre : pas de base de données, pas de format propriétaire. Tes notes restent lisibles et versionnables avec git.

```
carnet                      menu interactif
carnet add "idée rapide"    ajout horodaté à la note du jour, sans ouvrir l'éditeur
carnet todo                 toutes les cases [ ] de toutes les notes, cochables
carnet caen                 ouvre la note la plus proche de « caen »
```

## Fonctionnalités

- **Daily** : une note par jour, qui reprend les todos non faits de la veille.
- **Capture rapide** : `carnet add "…"` ou `cmd | carnet add`.
- **Todos** : toutes les cases `- [ ]` de toutes les notes dans une liste ; `ctrl-x` coche ou décoche, `tab` permet d'en cocher plusieurs ; échéances `@2026-11-20` triées et signalées en retard.
- **Recherche** : plein texte (ripgrep), par tag (frontmatter YAML), récentes, par taille.
- **Templates** : fichiers markdown éditables avec `{{name}}`, `{{date}}`, `{{time}}`, `{{datetime}}`.
- **Triage** de `inbox/` et `wip/`, **revue hebdomadaire** des dailies.
- **Dans vim** : insérer un lien vers une note, voir ses backlinks, coller une image du presse-papier.
- **Corbeille** restaurable, favoris, sauvegardes, sync git.
- **mkdocs** : serveur local, abréviations et glossaire en infobulles sur tout le site.

## Installation

### Dépendances

| Outil | macOS (Homebrew) | Debian / Ubuntu |
|---|---|---|
| bash ≥ 4 | `brew install bash` | déjà présent |
| GNU find | `brew install findutils` | déjà présent |
| fzf ≥ 0.40 | `brew install fzf` | `apt install fzf` |
| ripgrep | `brew install ripgrep` | `apt install ripgrep` |
| bat | `brew install bat` | `apt install bat` |
| git, perl | déjà présents | déjà présents |

Optionnels : `mkdocs` + `mkdocs-material` (site), `pngpaste` (macOS) ou `wl-clipboard` / `xclip` (Linux) pour coller des images, `terminal-notifier` / `notify-send` pour les notifications.

### carnet

```bash
git clone https://github.com/Damien-Petit-Thomas/carnet.git ~/src/carnet
cd ~/src/carnet
./install.sh                 # liens dans ~/.local/bin et ~/.local/share/zsh/site-functions
```

Mise à jour : `git -C ~/src/carnet pull`. Désinstallation : `./install.sh --uninstall` (tes notes ne sont pas touchées).

Avec oh-my-zsh, pour la complétion :

```bash
ZSH_COMPLETION_DIR=~/.oh-my-zsh/custom/completions ./install.sh
rm -f ~/.zcompdump*; exec zsh
```

## Où sont les notes

Par défaut :

```
~/notes/
├── docs/            ← les notes (CARNET_DIR)
│   ├── daily/       ← une note par jour
│   ├── inbox/  wip/ ← à trier (carnet triage)
│   ├── includes/    ← abréviations et glossaire mkdocs
│   └── …            ← tes dossiers
├── templates/       ← templates (créés au premier usage)
├── trash/           ← corbeille
├── backup/          ← sauvegardes
└── mkdocs.yml       ← optionnel
```

Les dossiers sont créés au fil de l'usage. Pour un autre emplacement : `export CARNET_DIR=~/mes-notes`.

## Usage

`carnet help` liste toutes les commandes. Les principales :

| Commande | Effet |
|---|---|
| `carnet` | menu interactif |
| `carnet <query>` | ouvre la note la plus proche |
| `carnet new` | nouvelle note avec template |
| `carnet daily` | note du jour |
| `carnet add <texte>` | ajoute `- HH:MM texte` à la note du jour |
| `carnet todo` | todos (`ctrl-x` cocher/décocher, `tab` multi) |
| `carnet search` / `tags` / `recent` | recherches |
| `carnet triage` | trier `inbox/` et `wip/` |
| `carnet week [N]` | revue de la semaine |
| `carnet abbr` / `gloss` | abréviations / glossaire mkdocs |
| `carnet restore` | restaurer depuis la corbeille |
| `carnet sync` | git commit + push du dépôt de notes |
| `carnet serve` | site mkdocs local |

### Todos

```markdown
- [ ] tâche
- [ ] tâche avec échéance @2026-11-20
- [x] faite
- [>] reportée à la daily suivante
```

### Dans vim

Chargé automatiquement quand carnet ouvre vim (`<leader>` = `\` par défaut) :

| Touche | Effet |
|---|---|
| `\nl` | insérer un lien `[Titre](chemin/relatif.md)` vers une note |
| `\nb` | backlinks de la note courante |
| `\ni` | coller l'image du presse-papier dans `assets/` |
| `\nf` | favori |

Pour l'avoir aussi hors de carnet : `source ~/src/carnet/share/vim/carnet.vim` dans `~/.vimrc`.

### mkdocs (optionnel)

`carnet serve` lance `mkdocs serve` depuis le dossier parent de `CARNET_DIR`. Pour les abréviations et le glossaire en infobulles :

```yaml
docs_dir: docs
exclude_docs: |
  includes/
markdown_extensions:
  - abbr
  - pymdownx.snippets:
      auto_append:
        - docs/includes/abbreviations.md
        - docs/includes/glossary.md
```

## Configuration

| Variable | Défaut |
|---|---|
| `CARNET_DIR` | `~/notes/docs` |
| `CARNET_TEMPLATES_DIR` | `~/notes/templates` |
| `CARNET_TRASH_DIR` | `~/notes/trash` |
| `CARNET_TRASH_DAYS` | `30` |
| `CARNET_BACKUP_DIR` | `~/notes/backup` |
| `CARNET_AUTOSYNC` | `0` (`1` = commit + push en arrière-plan après chaque édition) |
| `MKDOCS_PORT` | `8000` |
| `EDITOR` | `vim` |

## Développement

```bash
bats tests          # tests (macOS et Linux, aussi lancés par la CI)
```

Le code est découpé par domaine dans `lib/` ; tout ce qui diffère entre macOS et Linux est dans `lib/platform`.

## Licence

MIT
