#!/bin/bash

REPO_DIR="./debug_analyse"
COLS=3

# Vérifie que le répertoire existe
verifier_repertoire() {
  if [ ! -d "$REPO_DIR" ]; then
    echo "[ERREUR] Répertoire $REPO_DIR introuvable."
    exit 1
  fi
}

# Charge tous les scripts .sh dans un tableau global
charger_scripts() {
  mapfile -d '' scripts < <(find "$REPO_DIR" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)
  nb_scripts=${#scripts[@]}
  if [ $nb_scripts -eq 0 ]; then
    echo "Aucun script .sh trouvé dans $REPO_DIR."
    exit 0
  fi
}

# Affiche le menu sous forme de tableau
afficher_menu() {
  echo "=== Menu Debug Analyse (auto) ==="
  local i=0
  for script in "${scripts[@]}"; do
    local num=$((i+1))
    local name=$(basename "$script")
    printf "%-4s %-27s" "[$num]" "$name"
    ((i++))
    if (( i % COLS == 0 )); then
      echo
    fi
  done
  if (( nb_scripts % COLS != 0 )); then
    echo
  fi
  echo "[0] Quitter"
  echo -n "Choisissez une option : "
}

# Exécute le script choisi
executer_script() {
  local index=$1
  local script="${scripts[$index]}"
  echo "=== Exécution de $(basename "$script") ==="
  bash "$script"
  echo "=== Fin de $(basename "$script") ==="
  echo
  read -p "Appuyez sur Entrée pour revenir au menu..."
}

# Boucle principale du menu
menu_principal() {
  while true; do
    afficher_menu
    read choix
    if [[ "$choix" =~ ^[0-9]+$ ]]; then
      if [ "$choix" -eq 0 ]; then
        echo "Au revoir !"
        exit 0
      elif [ "$choix" -ge 1 ] && [ "$choix" -le "$nb_scripts" ]; then
        executer_script $((choix-1))
      else
        echo "Option invalide."
      fi
    else
      echo "Veuillez entrer un nombre."
    fi
  done
}

# Programme principal
verifier_repertoire
charger_scripts
menu_principal
