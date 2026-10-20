# Infrastructure TeleMonitor — guide de lancement

Toutes les commandes utilisent des **chemins absolus** : elles fonctionnent depuis n'importe
quel dossier. Deux façons de faire :
**A. sans Docker**, tout de suite, avec le Python installé sur Windows ;
**B. avec Docker**, une fois l'installation administrateur faite.

---

## A. Benchmarks sans Docker

Relance des deux tâches en processus détachés (les plis déjà enregistrés sont repris) :

```
powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\relancer_benchmarks.ps1
```

Suivre :

```
Get-Content C:\Projects\telemonitor-research\out\run_haemodynamic_0.log -Wait     # une ligne par candidat et par pli
Get-Content C:\Projects\telemonitor-research\out\run_haemodynamic_0.err -Tail 5   # barres de progression
```

Au premier plan, avec les barres en direct :

```
cd C:\Projects\telemonitor-research
python scripts\06_benchmark.py --tasks haemodynamic --leads 0
```

Arrêter un run détaché : `Stop-Process -Id <PID affiché au lancement>`. La même commande le reprend.

Chaque run est sauvegardé dans `C:\Projects\telemonitor-research\out\runs\<tâche>_<délai>h_<id>\`
(configurations, code, environnement, résultats par pli, tous les essais, toutes les
prédictions, modèles finaux). Les figures se retracent sans recalcul :

```
cd C:\Projects\telemonitor-research
python scripts\08_figures.py --all
```

Détail des sauvegardes : `C:\Projects\telemonitor-research\BENCHMARKS.md`.

---

## B. Docker

### Étape 1 — installation complète, en une fois (administrateur)

Ouvrez **PowerShell en tant qu'administrateur** (clic droit → Exécuter en tant
qu'administrateur), puis :

```
powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\0_installer_tout.ps1
```

Le script, journalisé dans `C:\Projects\infra\windows\install_log.txt` :

1. active la virtualisation dans le BIOS HP (désactivée aujourd'hui) via l'interface WMI du
   BIOS HP ; si le BIOS est protégé par un mot de passe, relancez avec
   `-BiosPassword 'votre_mot_de_passe'` ;
2. installe WSL2 ;
3. installe Docker Desktop 4.96.0 sans interaction (installateur officiel déjà téléchargé dans
   `C:\Users\ELITEBOOK 745G6\Downloads\docker-desktop\`, empreinte vérifiée) ;
4. ajoute votre compte au groupe `docker-users`.

Il ne redémarre pas l'ordinateur : **redémarrez vous-même** à la fin.

Si le journal indique que le BIOS n'a pas pu être modifié, faites-le à la main : redémarrez,
appuyez sur **F10** à l'écran HP, **Advanced → System Options** → cochez **Virtualization
Technology** (ou **SVM**), **F10** pour enregistrer.

Les étapes séparées restent disponibles :
`C:\Projects\infra\windows\1_installer_wsl.ps1` puis `C:\Projects\infra\windows\2_installer_docker.ps1`.

### Étape 2 — premier démarrage

Après le redémarrage, lancez **Docker Desktop** une fois (accepter les conditions ; usage
personnel et éducatif gratuit), puis dans un terminal normal :

```
docker run --rm hello-world
```

### Étape 3 — construire les images (une fois, ≈ 15–30 min, ≈ 8 Go)

```
cd C:\Projects
docker compose build research
docker compose build thesis      # TeX Live complet, image volumineuse
docker compose build app         # Flutter 3.44.2 + SDK Android
```

### Étape 4 — utiliser (depuis `C:\Projects`)

| Action | Commande |
|---|---|
| Tests de la recherche | `docker compose run --rm tests` |
| Un script d'analyse | `docker compose run --rm research python scripts/01_douala_audit.py` |
| Les deux benchmarks, en arrière-plan | `docker compose --profile bench up -d` |
| Suivre un benchmark (barres en direct) | `docker compose logs -f bench-haemodynamic` |
| Arrêter les benchmarks (reprise ensuite) | `docker compose --profile bench stop` |
| Benchmark d'une seule tâche, au premier plan | `docker compose run --rm research python scripts/06_benchmark.py --tasks glycaemic --leads 0` |
| H2 : horizons 24 h et 48 h | `docker compose run --rm research python scripts/06_benchmark.py --tasks haemodynamic --leads 12 36` |
| Retracer les figures de tous les runs | `docker compose run --rm research python scripts/08_figures.py --all` |
| Service de risque (FastAPI) | `docker compose up -d api` → http://localhost:8000/docs |
| Compiler le mémoire (PDF) | `docker compose run --rm thesis` |
| Tests et analyse de l'app Flutter | `docker compose run --rm app` |
| APK Android branchée sur le service | `docker compose run --rm app flutter build apk --dart-define=RISK_API_URL=http://10.0.2.2:8000` |
| Shell dans l'environnement de recherche | `docker compose run --rm research` |

Les dossiers des projets sont montés dans les conteneurs : données, sorties
(`telemonitor-research\out\`, dont les dossiers de run) et PDF restent sur Windows. Un run
commencé sans Docker se reprend avec Docker, et inversement : même empreinte, même dossier.

### Ce que chaque image contient

| Service | Image | Contenu |
|---|---|---|
| `research`, `tests`, `bench-*`, `api` | `telemonitor/research:0.2` | Python 3.10.11 et les versions exactes utilisées pour le mémoire (`telemonitor-research\requirements-docker.txt`), PyTorch CPU 2.12.0 |
| `thesis` | `telemonitor/thesis:0.1` | TeX Live (image officielle `texlive/texlive`), Biber, Python 3 pour `build.py` |
| `app` | `telemonitor/app:3.44.2` | Flutter 3.44.2 (même version qu'en développement) et SDK Android |

L'application s'exécute sur un téléphone ou un émulateur, hors Docker ; depuis l'émulateur
Android, elle appelle le service `api` à `http://10.0.2.2:8000`.
