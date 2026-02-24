#!/bin/bash
# TP1 Partie 1 - Traitement des logs (grep, sed, awk, find)
# Usage: ./process-logs.sh [options] [chemin_logs]
# Options: --all (tout afficher) | --dual (2 lignes par catégorie)

LOGS_DIR=""
MODE="default"  # default | dual | all

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --dual)
      MODE="dual"
      shift
      ;;
    *)
      if [[ -z "$LOGS_DIR" ]]; then
        LOGS_DIR="$1"
      fi
      shift
      ;;
  esac
done

# Répertoire du script et racine du projet (absolus)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOGS_DIR="${LOGS_DIR:-$PROJECT_ROOT/logs}"
# Chemin relatif → absolu par rapport à la racine du projet
[[ "$LOGS_DIR" != /* ]] && LOGS_DIR="$PROJECT_ROOT/$LOGS_DIR"
cd "$PROJECT_ROOT" || exit 1

if [[ ! -d "$LOGS_DIR" ]]; then
  echo "Erreur: dossier logs introuvable: $LOGS_DIR" >&2
  echo "Usage: $0 [--all|--dual] [chemin_logs]" >&2
  exit 1
fi

apply_limit() {
  local n="$1"
  case "$MODE" in
    all)   cat ;;
    dual)  head -n 2 ;;
    *)     head -n "$n" ;;
  esac
}

echo "=== 1) Extraire toutes les lignes contenant des erreurs ==="
grep -h -E '\[ERROR\]|\[CRITICAL\]|Status (4[0-9][0-9]|5[0-9][0-9])' "$LOGS_DIR"/*.log 2>/dev/null | apply_limit 20
[[ "$MODE" == "default" ]] && echo "..."

echo ""
echo "=== 2) Trouver toutes les tentatives d'accès refusées (auth) ==="
grep -h -E 'Access denied|Login failed|Invalid token|Too many attempts|Password expired' "$LOGS_DIR/auth.log" 2>/dev/null | apply_limit 20
[[ "$MODE" == "default" ]] && echo "..."

echo ""
echo "=== 3) Lister les IP les plus actives dans access.log ==="
awk -F' - ' '{print $2}' "$LOGS_DIR/access.log" 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | apply_limit 15

echo ""
echo "=== 4) Supprimer les lignes contenant le mot DEBUG ==="
grep -v 'DEBUG' "$LOGS_DIR/app.log" 2>/dev/null | apply_limit 10
[[ "$MODE" == "default" ]] && echo "..."

echo ""
echo "=== 5) Remplacer 'password' par '*****' (masquage basique) ==="
sed 's/[Pp]assword/*****/g' "$LOGS_DIR/auth.log" 2>/dev/null | grep -E '\*\*\*\*\*' | apply_limit 5
[[ "$MODE" == "default" ]] && echo "..."

echo ""
echo "=== 6) Ajouter un préfixe [ANALYZED] à chaque ligne ==="
sed 's/^/[ANALYZED] /' "$LOGS_DIR/access.log" 2>/dev/null | apply_limit 5
[[ "$MODE" == "default" ]] && echo "..."

echo ""
echo "=== 7) Extraire la colonne 1 (timestamp) et 4 (IP) ==="
awk '{print $1" "$2, $4}' "$LOGS_DIR/access.log" 2>/dev/null | apply_limit 10

echo ""
echo "=== 8) Compter le nombre d'erreurs par type ==="
grep -ohE '\[(ERROR|CRITICAL|WARN|INFO|DEBUG)\]' "$LOGS_DIR/app.log" 2>/dev/null | sort | uniq -c | sort -rn | apply_limit 10

echo ""
echo "=== 9) Trouver les fichiers modifiés dans les dernières 24h ==="
find "$LOGS_DIR" -type f -mtime -1 2>/dev/null | while read -r f; do
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f '%N %Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null
  else
    stat -c '%n %y' "$f" 2>/dev/null | sed 's/\.[0-9]* .*//'
  fi
done | apply_limit 20

echo ""
echo "=== 10) Trouver tous les fichiers .log de plus de 10 Mo ==="
find . -name "*.log" -size +10M 2>/dev/null | apply_limit 20
[[ "$MODE" == "default" ]] && ! find . -name "*.log" -size +10M 2>/dev/null | grep -q . && echo "(aucun fichier .log > 10 Mo dans ce projet)"
