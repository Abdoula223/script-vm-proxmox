# script-vm-proxmox
# 🔁 Proxmox Failover Script avec Proxmox Backup Server (PBS)

Ce script permet une restauration automatique de conteneurs LXC ou VMs critiques depuis un **Proxmox Backup Server (PBS)** vers un autre cluster Proxmox (Cluster B), en cas d'indisponibilité du Cluster A.

---

## 📦 Fonctionnalités

- Détection automatique de la perte de connectivité du Cluster A
- Restauration automatique depuis la dernière sauvegarde PBS disponible
- Supporte les conteneurs (`ct/ID`) et machines virtuelles (`vm/ID`)
- Écriture des logs dans `/var/log/pbs_failover_local.log`
- Restauration locale sur un nœud précis (`TARGET_NODE_HOSTNAME`)

---

## ⚙️ Configuration

Le fichier `t.sh` contient ces variables à personnaliser :

```bash
CLUSTER_A_IP="192.168.75.129"             # IP d'un nœud critique du Cluster A
TARGET_NODE_HOSTNAME="pve-1"              # Nom d'hôte du nœud de secours (Cluster B)
PBS_STORAGE_NAME_ON_PVE="pbs-backup"      # Nom du stockage PBS dans PVE
TARGET_STORAGE="local-lvm"                # Nom du stockage cible pour la restauration
CRITICAL_GUESTS=("ct/100")                # Liste des invités critiques à restaurer
# script-vm-proxmox
