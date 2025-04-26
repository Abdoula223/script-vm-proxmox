#######################################################################################################
#         Abdoulaye Diallo                                                                            #
#         agabdoulaye16@gmail.com                                                                     #
#######################################################################################################
#!/bin/bash

# === Configuration ===
CLUSTER_A_IP="192.168.75.129"                  # IP d'un nœud du Cluster A
TARGET_NODE_HOSTNAME="pve-1"                   # Hôte où ce script tourne (Cluster B)
PBS_STORAGE_NAME_ON_PVE="pbs-backup"           # Nom du stockage PBS ajouté dans Cluster B
TARGET_STORAGE="local-lvm"                     # Storage cible pour la restauration
CRITICAL_GUESTS=("ct/100")                     # LXC ou VM à restaurer (format "ct/ID" ou "vm/ID")
LOG_FILE="/var/log/pbs_failover_local.log"     # Fichier de log

# === Initialisation du Logging ===
exec > >(tee -a "$LOG_FILE") 2>&1
echo -e "\n=== Exécution du script le $(date) sur $(hostname) ==="

# === Vérification du bon nœud ===
CURRENT_NODE=$(hostname)
if [ "$CURRENT_NODE" != "$TARGET_NODE_HOSTNAME" ]; then
    echo "ERREUR: Ce script doit tourner sur '$TARGET_NODE_HOSTNAME', pas sur '$CURRENT_NODE'."
    exit 1
fi

# Vérifier si PBS est accessible sur ce nœud
if ! pvesm status --storage "$PBS_STORAGE_NAME_ON_PVE" | grep -q 'active.*1'; then
    echo "ERREUR: Le stockage PBS '$PBS_STORAGE_NAME_ON_PVE' n'est pas actif sur ce nœud."
    exit 1
fi

# === Fonction: Vérifie la connectivité de Cluster A ===
check_cluster_a_availability() {
    echo "🕓 $(date) — Début du processus de vérification du Cluster A"
    if ping -c 3 -W 2 "$CLUSTER_A_IP" >/dev/null 2>&1; then
        echo "✅ Cluster A ($CLUSTER_A_IP) est joignable (ping OK)"
        return 0
    else
        echo "❌ Cluster A ($CLUSTER_A_IP) est injoignable"
        return 1
    fi
}

# === Fonction: Restauration automatique depuis PBS ===
restore_guest() {
    local guest_id_full="$1"             # Ex: "ct/100"
    local guest_type="${guest_id_full%%/*}" # ct ou vm
    local guest_id="${guest_id_full#*/}"    # 100

    echo "🔄 Restauration de la $guest_type $guest_id à partir de PBS..."

    # Obtenir le dernier snapshot PBS
    local backup_volume=$(pvesm list "$PBS_STORAGE_NAME_ON_PVE" | grep "backup/${guest_id_full}/" | sort -rk1 | head -n1 | awk '{print $1}')

    if [ -z "$backup_volume" ]; then
        echo "❌ Aucune sauvegarde trouvée pour $guest_id_full dans $PBS_STORAGE_NAME_ON_PVE."
        return 1
    fi

    echo "📦 Dernier backup trouvé : $backup_volume"

    local restore_cmd=""
    local start_cmd=""

    if [ "$guest_type" == "ct" ]; then
        restore_cmd="pct restore $guest_id $backup_volume --storage $TARGET_STORAGE --unique 1"
        start_cmd="pct start $guest_id"
    elif [ "$guest_type" == "vm" ]; then
        restore_cmd="qm restore $guest_id $backup_volume --storage $TARGET_STORAGE --unique 1"
        start_cmd="qm start $guest_id"
    else
        echo "❌ Type inconnu pour $guest_id_full"
        return 1
    fi

    echo "▶️ Commande: $restore_cmd"
    if eval "$restore_cmd"; then
        echo "✅ $guest_type $guest_id restauré avec succès."
        echo "🚀 Démarrage de $guest_type $guest_id..."
        if eval "$start_cmd"; then
            echo "✅ $guest_type $guest_id démarré."
            return 0
        else
            echo "⚠️ Échec du démarrage pour $guest_type $guest_id."
            return 1
        fi
    else
        echo "❌ Restauration échouée pour $guest_id_full."
        return 1
    fi
}

# === Logique principale ===
main() {
    if check_cluster_a_availability; then
        echo "ℹ️ Cluster A est UP. Aucune restauration nécessaire."
        exit 0
    fi

    echo "🚨 Cluster A est DOWN. Début du processus de failover automatique."
    echo "‼️ Vérifiez manuellement qu’il ne s'agit pas d'un faux positif (risque de split-brain)."

    local overall_success=true
    for guest in "${CRITICAL_GUESTS[@]}"; do
        echo -e "\n🔧 Traitement de $guest"
        if ! restore_guest "$guest"; then
            echo "❌ Échec de restauration de $guest"
            overall_success=false
        fi
    done

    if $overall_success; then
        echo "🎉 Tous les invités ont été restaurés avec succès."
        exit 0
    else
        echo "⚠️ Une ou plusieurs restaurations ont échoué. Consultez les logs."
        exit 1
    fi
}

# === Exécution ===
main
