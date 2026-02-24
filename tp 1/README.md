# TP1 DevSecOps


## Partie 1
```bash
dreasy@Maxou-1668 tp 1 % ./scripts/process-logs.sh --dual logs # pour n'avoir que 2 lignes par "demandes"
=== 1) Extraire toutes les lignes contenant des erreurs ===
2025-11-20 01:21:15 - 192.168.1.28 - PUT /api/v1/products - Status 403
2025-11-20 01:21:15 - 172.16.0.1 - DELETE /api/v1/auth - Status 400

=== 2) Trouver toutes les tentatives d'accès refusées (auth) ===
2025-11-20 01:21:15 - user15 - 10.0.0.25 - Login failed
2025-11-20 01:21:15 - user17 - 192.168.1.23 - Invalid token

=== 3) Lister les IP les plus actives dans access.log ===
  15 10.0.0.26
  14 10.0.0.27

=== 4) Supprimer les lignes contenant le mot DEBUG ===
2025-11-20 01:21:15 [CRITICAL] - Timeout lors de la requ�te
2025-11-20 01:21:15 [WARN] - Fichier de configuration introuvable

=== 5) Remplacer 'password' par '*****' (masquage basique) ===
2025-11-20 01:21:15 - user15 - 172.16.0.19 - ***** expired
2025-11-20 01:21:15 - user3 - 10.0.0.12 - ***** expired

=== 6) Ajouter un préfixe [ANALYZED] à chaque ligne ===
[ANALYZED] 2025-11-20 01:21:15 - 172.16.0.11 - GET /api/v1/users - Status 201
[ANALYZED] 2025-11-20 01:21:15 - 192.168.1.28 - PUT /api/v1/products - Status 403

=== 7) Extraire la colonne 1 (timestamp) et 4 (IP) ===
2025-11-20 01:21:15 172.16.0.11
2025-11-20 01:21:15 192.168.1.28

=== 8) Compter le nombre d'erreurs par type ===
1080 [CRITICAL]
 972 [DEBUG]

=== 9) Trouver les fichiers modifiés dans les dernières 24h ===
/Users/dreasy/devsecops/logs/app.log 2026-02-24 09:59 #modifié manuellement pour le test

=== 10) Trouver tous les fichiers .log de plus de 10 Mo === # ( trop long a faire )

```
```bash
#process-logs.sh sans la logique de selection de dual ou all et les fichier de plus de 10 Mo.
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
```
[scripts/process-logs.sh](scripts/process-logs.sh)


## Partie 2
```docker
docker build -t api-notes .
docker run -p 8000:8000 api-notes
```

```bash
curl http://localhost:8000

{"message":"Hello Docker"}% 
```

[Dockerfile](Dockerfile)
```dockerfile
FROM python:3.12-slim 
# Utilisation d'une image versionnée pour éviter les mises à jour automatiques inattendues
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Réponses aux questions sécurité

### Quel risque existe-t-il à lancer un conteneur avec `--privileged` ?

Un conteneur lancé avec `--privileged` **désactive presque toutes les isolations** de sécurité :

- **Accès au kernel hôte** : le conteneur peut charger des modules kernel, accéder aux périphériques (`/dev`), et interagir directement avec le matériel.
- **Équivalence root** : les capacités Linux sont toutes accordées ; le conteneur peut faire tout ce que root peut faire sur l’hôte.
- **Échappement possible** : en cas de compromission, un attaquant peut sortir du conteneur et prendre le contrôle de l’hôte.
- **Pas de cgroups stricts** : les limites hardware comme le CPU, la ram et le disque peuvent être contournées.

**En pratique** : n’utiliser `--privileged` que pour des cas très spécifiques (debug, tests matériels) et jamais en production.

---

### Différence entre bind mount et volume Docker : impacts sécurité ?

| Critère | Bind mount | Volume Docker |
|---------|------------|---------------|
| **Emplacement** | Chemin arbitraire sur l’hôte | Géré par Docker (`/var/lib/docker/volumes/`) |
| **Propriété** | Fichiers créés avec l’UID du conteneur | Gérés par le daemon Docker |
| **Portabilité** | Dépend du chemin hôte | Indépendant de la machine |
| **Sécurité** | Risque d’exposition de fichiers sensibles | Meilleure isolation par défaut |

**Impacts sécurité :**

- **Bind mount** : risque d’exposer des répertoires sensibles (`/etc`, `/root`, etc.), de modifier des fichiers critiques de l’hôte, et de fuites de données si le chemin est mal choisi.
- **Volume Docker** : isolation plus forte, accès limité au système de fichiers hôte, et gestion des permissions par Docker.

**Recommandation** : privilégier les volumes Docker pour les données applicatives ; n’utiliser les bind mounts que pour des cas précis (configs, logs) avec des chemins contrôlés.


## Registry local 

```bash
# 1. Démarrer le registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2

docker build -t api-notes tp 1/Dockerfile
docker tag api-notes localhost:5000/api-notes:latest
docker push localhost:5000/api-notes:latest
```

### Question de sécurité

#### Impact des vulnérabilités du kernel hôte malgré l’isolation des conteneurs

- Les conteneurs partagent le kernel de l’hôte avec les autres conteneurs et avec l’hôte lui‑même. Ils n’ont pas de kernel dédié comme les machines virtuelles.

**Conséquences :**
- Pas d’isolation au niveau kernel : une faille dans le kernel (ex. CVE sur les namespaces, cgroups, syscalls) peut permettre de sortir du conteneur et d’accéder à l’hôte ou aux autres conteneurs.
- Surface d’attaque commune : toute vulnérabilité du kernel (mémoire, pilotes, etc.) peut être exploitée depuis un conteneur.
- Impact en chaîne : un seul conteneur compromis peut suffire à compromettre l’hôte et les autres conteneurs.

#### Pourquoi les images Docker "latest" sont dangereuses ?

- Non reproductibilité : `latest` change à chaque build, on ne sait pas quelle version exacte est utilisée.
- Régression possible : une nouvelle version peut introduire des bugs ou des failles.
- Pas de traçabilité : difficile de savoir quelle image était en production lors d’un incident.
- Mises à jour non maîtrisées : un `docker pull` peut ramener une version différente sans contrôle.
- **Recommandation** : utiliser des tags explicites et versionnés (ex. `python:3.12-slim`, `nginx:1.25.2`).

#### Mise en place d’une "image signing" sécurisée

- L’objectif est de garantir l’intégrité et l’origine des images.

**Méthodes principales :**
- Docker Content Trust (DCT) : basé sur Notary, permet de signer les images avec des clés privées.
- Cosign (Sigstore) : signe les images avec des clés ou des identités OIDC (ex. GitHub Actions).
- Registries avec support natif : Docker Hub, Harbor, etc., peuvent vérifier les signatures.

**Étapes typiques :**
- Générer ou utiliser des clés de signature (ou OIDC).
- Signer les images au build : `cosign sign --key cosign.key image:tag`
- Configurer le registry pour ne déployer que des images signées.
- Vérifier les signatures avant pull : `cosign verify image:tag`

#### Stratégie pour un "minimal attack surface" dans une image conteneur
Principes :
| Pratique                 | Objectif                                                                                         |
|--------------------------|--------------------------------------------------------------------------------------------------|
| Image de base minimale   | alpine, slim, distroless pour réduire les paquets et outils disponibles                         |
| Utilisateur non-root     | Créer et utiliser un utilisateur dédié, éviter root                                             |
| Dépendances limitées     | Installer uniquement ce qui est nécessaire                                                      |
| Pas de shell inutile     | Images distroless sans shell pour limiter l’exécution de commandes                             |
| Tags versionnés          | Éviter latest, fixer les versions                                                              |
| Scan régulier            | Trivy, Snyk, etc. pour détecter les CVE                                                        |
| Couches en lecture seule | Monter les systèmes de fichiers en lecture seule quand c’est possible                          |
| Capacités réduites       | --cap-drop=ALL puis ajouter uniquement ce qui est requis                                       |



