#!/usr/bin/env bats
# Tests des parties non interactives de carnet.
# Lancer : bats tests
# fzf est remplacé par un bouchon qui choisit la 1re ligne contenant $PICK.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    CARNET="$ROOT/bin/carnet"
    T="$(mktemp -d)"
    export CARNET_DIR="$T/docs" CARNET_TRASH_DIR="$T/trash" \
           CARNET_TEMPLATES_DIR="$T/templates" CARNET_BACKUP_DIR="$T/bk" \
           EDITOR=true CARNET_AUTOSYNC=0
    mkdir -p "$CARNET_DIR/daily" "$CARNET_DIR/infra"
}

teardown() {
    rm -rf "$T"
}

load_lib() {
    CARNET_ROOT="$ROOT"
    CARNET_BIN="$CARNET"
    for m in config platform utils core notes search trash links review git lexicon; do
        source "$ROOT/lib/$m"
    done
    _setup_shims
    sleep() { :; }
    fzf() { grep -m1 -F -- "${PICK:-}" || true; }
}

note() {  # note CHEMIN_RELATIF CONTENU
    mkdir -p "$(dirname "$CARNET_DIR/$1.md")"
    printf '%b' "$2" > "$CARNET_DIR/$1.md"
}

today() { date +%F; }

# ─── capture rapide / daily ───────────────────────────────────────────

@test "add : ajoute une ligne horodatée à la daily du jour" {
    run "$CARNET" add "premier point"
    [ "$status" -eq 0 ]
    grep -qE '^- [0-9]{2}:[0-9]{2} premier point$' "$CARNET_DIR/daily/$(today).md"
}

@test "add : texte multiligne depuis stdin, lignes suivantes indentées" {
    printf 'ligne1\nligne2\n' | "$CARNET" add
    grep -qE '^- [0-9:]{5} ligne1$' "$CARNET_DIR/daily/$(today).md"
    grep -q '^  ligne2$' "$CARNET_DIR/daily/$(today).md"
}

@test "add : refuse un texte vide" {
    run "$CARNET" add "   "
    [ "$status" -eq 1 ]
}

@test "daily : reprend les todos ouverts de la veille et les marque [>]" {
    note daily/2000-01-01 '# old\n- [ ] tâche A @2000-01-02\n- [x] faite\n- [ ]\n'
    load_lib
    f=$(_ensure_daily)
    grep -qF -- '- [ ] tâche A @2000-01-02' "$f"
    grep -qF '[← 2000-01-01](2000-01-01.md)' "$f"
    ! grep -qF 'faite' "$f"
    grep -qF -- '- [>] tâche A' "$CARNET_DIR/daily/2000-01-01.md"
    grep -qx -- '- \[ \]' "$CARNET_DIR/daily/2000-01-01.md"
}

# ─── tags ─────────────────────────────────────────────────────────────

@test "tags : formes liste et inline, correspondance exacte" {
    note infra/a '---\ntags:\n  - meeting\n  - devops\n---\n# a\n'
    note infra/b '---\ntags: [dev, "infra"]\n---\n# b\n'
    note c '---\ntags: []\n---\n# c\n'
    load_lib
    out=$(note_tags | sed "s|^$CARNET_DIR/||" | sort)
    [ "$out" = "$(printf 'infra/a.md\tdevops\ninfra/a.md\tmeeting\ninfra/b.md\tdev\ninfra/b.md\tinfra')" ]
}

# ─── todos ────────────────────────────────────────────────────────────

@test "todo : échéances d'abord, triées, retard signalé" {
    note x '- [ ] sans date\n- [ ] plus tard @2999-01-01\n- [ ] vieux @2000-01-01\n- [x] fait @1999-01-01\n'
    load_lib
    out=$(_todo_list | sed 's/\x1b\[[0-9;]*m//g')
    [ "$(sed -n 1p <<< "$out")" = "x.md:3:- [ ] vieux @2000-01-01  ⚠ en retard" ]
    [ "$(sed -n 2p <<< "$out")" = "x.md:2:- [ ] plus tard @2999-01-01" ]
    [ "$(sed -n 3p <<< "$out")" = "x.md:1:- [ ] sans date" ]
    [ "$(wc -l <<< "$out" | tr -d ' ')" = 3 ]
}

@test "todo : _toggle coche uniquement la ligne visée" {
    note x '- [ ] un\n- [ ] deux\n'
    "$CARNET" _toggle x.md 2
    [ "$(cat "$CARNET_DIR/x.md")" = "$(printf -- '- [ ] un\n- [x] deux')" ]
}

# ─── templates ────────────────────────────────────────────────────────

@test "templates : copiés au premier usage, variables remplacées" {
    load_lib
    _templates > /dev/null
    [ -f "$CARNET_TEMPLATES_DIR/meeting.md" ]
    [ "$(_templates | head -1)" = "default" ]
    out=$(_apply_template incident "Panne DB")
    grep -qx '# Panne DB' <<< "$out"
    grep -qE '^date: [0-9-]{10} [0-9]{2}:[0-9]{2}$' <<< "$out"
    ! grep -q '{{' <<< "$out"
}

@test "templates : template utilisateur ajouté" {
    load_lib
    _ensure_templates
    printf '# {{name}} — {{date}}\n' > "$CARNET_TEMPLATES_DIR/perso.md"
    _templates | grep -qx perso
    [ "$(_apply_template perso X)" = "# X — $(today)" ]
}

# ─── corbeille ────────────────────────────────────────────────────────

@test "corbeille : delete garde l'arborescence, restore remet en place" {
    note infra/a '# a\n'
    load_lib
    echo infra/a > "$favorites"
    echo y | delete_note infra/a
    [ ! -f "$CARNET_DIR/infra/a.md" ]
    [ ! -s "$favorites" ]
    [ "$(_trash_entries | cut -d/ -f2-)" = "infra/a" ]
    PICK="infra/a" restore_note
    [ -f "$CARNET_DIR/infra/a.md" ]
    [ -z "$(_trash_entries)" ]
}

@test "corbeille : restore refuse d'écraser une note existante" {
    note a '# v1\n'
    load_lib
    echo y | delete_note a
    note a '# v2\n'
    PICK="a" restore_note
    grep -qx '# v2' "$CARNET_DIR/a.md"
    [ -n "$(_trash_entries)" ]
}

@test "corbeille : purge au-delà de CARNET_TRASH_DAYS" {
    load_lib
    mkdir -p "$trashdir/vieux" "$trashdir/recent"
    touch -t 200001010000 "$trashdir/vieux"
    purge_trash
    [ ! -d "$trashdir/vieux" ]
    [ -d "$trashdir/recent" ]
}

# ─── renommage / déplacement ──────────────────────────────────────────

@test "rename : refuse un nom existant, suit les favoris sinon" {
    note infra/a '# a\n'
    note infra/b '# b\n'
    load_lib
    echo infra/a > "$favorites"
    echo b | rename_note infra/a
    [ -f "$CARNET_DIR/infra/a.md" ]
    rename_note infra/a <<< c
    [ -f "$CARNET_DIR/infra/c.md" ]
    [ "$(cat "$favorites")" = "infra/c" ]
    [ "$last_note" = "infra/c" ]
}

# ─── liens ────────────────────────────────────────────────────────────

@test "lien : chemin relatif et titre de la note cible" {
    note infra/cible '# Ma cible\n'
    note daily/src '# src\n'
    load_lib
    out=$(PICK="infra/cible" pick_link "$CARNET_DIR/daily/src.md")
    [ "$out" = "[Ma cible](../infra/cible.md)" ]
}

@test "lien : chemin avec espace entre chevrons" {
    note "infra/note avec espace" '# E\n'
    note src '# src\n'
    load_lib
    out=$(PICK="infra/note avec espace" pick_link "$CARNET_DIR/src.md")
    [ "$out" = "[E](<infra/note avec espace.md>)" ]
}

@test "backlinks : résout les chemins relatifs, ignore les homonymes" {
    note infra/cible '# c\n'
    note other/cible '# homonyme\n'
    note daily/j1 'voir [c](../infra/cible.md)\n'
    note daily/j2 'voir [h](../other/cible.md)\n'
    note infra/voisin 'texte\n[c](cible.md#section)\n'
    load_lib
    out=$(_backlinks_of "$CARNET_DIR/infra/cible.md" | cut -d: -f1,2 | sort)
    [ "$out" = "$(printf 'daily/j1.md:1\ninfra/voisin.md:2')" ]
}

# ─── revue hebdo ──────────────────────────────────────────────────────

@test "week : agrège faits / ouverts et le contenu des dailies" {
    load_lib
    monday=$(_week_monday 0)
    note "daily/$monday" "---\ntags:\n  - daily\n---\n\n# $monday\n\n## todo\n\n- [x] fini\n- [ ] reste\n\n## notes\n\n- 10:00 réunion\n"
    out=$(_week_report "$monday")
    grep -qF '## ✓ done (1)' <<< "$out"
    grep -qF '## ☐ open (1)' <<< "$out"
    grep -qF "## $monday" <<< "$out"
    grep -qF '### notes' <<< "$out"
    grep -qF -- '- 10:00 réunion' <<< "$out"
}

# ─── CLI ──────────────────────────────────────────────────────────────

@test "cli : help et requête floue" {
    note "infra/note avec espace" '# x\n'
    run "$CARNET" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"carnet triage"* ]]
    run "$CARNET" espace
    [ "$status" -eq 0 ]
    run "$CARNET" zzzzzz
    [ "$status" -eq 1 ]
}

@test "cli : _fav bascule depuis un chemin absolu" {
    note a '# a\n'
    run "$CARNET" _fav "$CARNET_DIR/a.md"
    [[ "$output" == *"added"* ]]
    [ "$(cat "$CARNET_DIR/.favorites")" = "a" ]
    run "$CARNET" _fav "$CARNET_DIR/a.md"
    [[ "$output" == *"removed"* ]]
}

# ─── todos : session ──────────────────────────────────────────────────

@test "todo : case cochée pendant la session reste visible avec ✓" {
    note x '- [ ] un\n- [x] ancien\n- [ ] deux\n'
    load_lib
    export CARNET_TODO_SESSION="$T/session"
    : > "$CARNET_TODO_SESSION"
    toggle_todo x.md 3
    out=$(_todo_list | sed 's/\x1b\[[0-9;]*m//g')
    [ "$out" = "$(printf 'x.md:1:- [ ] un\nx.md:3:- [x] deux  ✓ fait')" ]
}

@test "todo : _toggle_list bascule plusieurs lignes, 2e passage annule" {
    note x '- [ ] un\n- [ ] deux\n'
    printf 'x.md:1:- [ ] un\nx.md:2:- [ ] deux\n' > "$T/sel"
    "$CARNET" _toggle_list "$T/sel"
    [ "$(cat "$CARNET_DIR/x.md")" = "$(printf -- '- [x] un\n- [x] deux')" ]
    "$CARNET" _toggle_list "$T/sel"
    [ "$(cat "$CARNET_DIR/x.md")" = "$(printf -- '- [ ] un\n- [ ] deux')" ]
}

# ─── abréviations / glossaire ─────────────────────────────────────────

@test "abbr : ajout trié, fichier dans includes/" {
    "$CARNET" abbr SLA "Service Level Agreement"
    "$CARNET" abbr FLS "Field Level Security"
    [ "$(cat "$CARNET_DIR/includes/abbreviations.md")" = "$(printf '*[FLS]: Field Level Security\n*[SLA]: Service Level Agreement')" ]
}

@test "abbr : remplacement seulement si confirmé" {
    "$CARNET" abbr FLS "v1"
    echo n | "$CARNET" abbr FLS "v2"
    grep -qx '\*\[FLS\]: v1' "$CARNET_DIR/includes/abbreviations.md"
    echo y | "$CARNET" abbr FLS "v2"
    grep -qx '\*\[FLS\]: v2' "$CARNET_DIR/includes/abbreviations.md"
    [ "$(wc -l < "$CARNET_DIR/includes/abbreviations.md" | tr -d ' ')" = 1 ]
}

@test "gloss : terme multi-mots dans glossary.md" {
    "$CARNET" gloss "flux ETL" "Chaîne d'import des données"
    grep -qx "\*\[flux ETL\]: Chaîne d'import des données" "$CARNET_DIR/includes/glossary.md"
}

# ─── portabilité ──────────────────────────────────────────────────────

@test "date_shift : mois, année, passage à l'heure d'hiver" {
    load_lib
    [ "$(date_shift 2026-10-31 1)" = "2026-11-01" ]
    [ "$(date_shift 2026-01-01 -1)" = "2025-12-31" ]
    [ "$(date_shift 2026-10-24 7)" = "2026-10-31" ]
    [ "$(date_shift 2026-11-09 0 %G-W%V)" = "2026-W46" ]
}

@test "lancement via lien symbolique" {
    ln -s "$CARNET" "$T/lien"
    run "$T/lien" version
    [ "$status" -eq 0 ]
    [[ "$output" == "carnet "* ]]
}
