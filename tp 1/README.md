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


## Partie 3
1) Sécuriser une pipeline CI/CD signifie mettre en place des contrôles pour empêcher l’exécution de code malveillant, protéger les secrets, valider l’intégrité des artefacts, contrôler qui a accès à quoi, et garantir que seuls des exécutables sûrs et autorisés sont produits et déployés. Les risques majeurs incluent la compromission des clés/secrets, l’injection de code dans les builds, la fuite d’informations sensibles et la contamination de l’environnement de production.

2) Le pipeline CI/CD fait partie de la surface d’attaque car il a accès au code source, aux secrets, aux serveurs de production et peut déployer automatiquement des applications. Si compromis, un attaquant peut injecter du code malveillant ou accéder à des ressources critiques via le pipeline.

3) Un runner partagé exécute des jobs pour plusieurs projets/utilisateurs, tandis qu’un runner dédié ne sert qu’à un projet ou à une équipe donnée. C’est important pour la sécurité car un runner partagé peut être utilisé comme vecteur pour attaquer d’autres projets, alors qu’un runner dédié limite la propagation et l’exposition.

4) Si un runner peut exécuter du code venant d’une MR/PR non validée, un attaquant pourrait exécuter du code malveillant sur l’infrastructure de CI, exfiltrer des secrets, altérer les artefacts ou compromettre la chaîne de production.

5) Pour isoler les jobs et éviter l’exécution de code malveillant entre pipelines, on utilise des environnements jetables (sandbox, conteneurs éphémères, VM), on configure des droits/privilèges minimums et on sépare clairement les secrets et ressources entre jobs.

6) Pour garantir qu’une image Docker est fiable, utiliser des images officielles et versionnées, vérifier leur signature (image signing), scanner les images contre les CVE connues, et ne prendre une image que depuis des sources approuvées ou d’un registre audité.

7) Utiliser "latest" comme tag Docker est risqué car rien ne garantit que la version utilisée reste la même dans le temps : on perd reproductibilité, on peut subir des régressions ou des vulnérabilités non anticipées.

8) Un SBOM ("Software Bill Of Materials") liste toutes les dépendances incluses dans une application/image. L’intégrer dans le pipeline permet de garder la traçabilité, de vérifier les licences et de simplifier les audits de sécurité (et les réponses aux alertes vulnérabilités).

9) SAST (Static Application Security Testing) analyse le code source pour trouver des failles de sécurité, tandis que SCA (Software Composition Analysis) analyse les dépendances (librairies tierces) et leurs vulnérabilités connues. Les deux sont nécessaires : le SAST couvre le code de l’équipe, le SCA ce qui vient de l’extérieur.

10) Un SAST doit être exécuté dès le début du pipeline (lors du push ou de la MR/PR), pour corriger tôt. Un SCA doit être exécuté à chaque modification de dépendance, idéalement à chaque build aussi, pour détecter les nouvelles vulnérabilités publiées.

11) Quand un scan SCA détecte une vulnérabilité dans une dépendance critique, il faut évaluer sa gravité, chercher un correctif/patch, mettre à jour la dépendance si possible, et appliquer un plan d’atténuation (désactiver la fonctionnalité, restreindre les accès) si la correction est impossible immédiatement.

12) Pour sécuriser un container registry en entreprise : forcer l’authentification, limiter l’accès (RBAC), activer la vérification des signatures, scanner les images uploadées (anti-malware et CVE), supprimer les images obsolètes, et auditer les logs d’accès.

13) Il faut scanner les images Docker avant le build (pour vérifier la base) et après le build (pour l’image complète) afin de garantir qu’aucune vulnérabilité majeure ou artefact risqué n’a été introduit pendant la phase d’assemblage.

14) On peut intégrer la sécurité dans le pipeline sans trop ralentir les équipes en automatisant les scans (SAST/SCA rapides), en configurant des seuils de blocage pertinents, et en produisant des alertes actionnables plutôt que des blocages systématiques.

15) Pour détecter et bloquer les dépendances non approuvées : définir une liste de dépendances autorisées et désapprouvées, utiliser les outils SCA avec une politique stricte, et automatiser le blocage du build en cas de détection d’une dépendance non approuvée.