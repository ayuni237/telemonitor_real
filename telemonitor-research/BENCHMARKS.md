# Relancer les analyses et les benchmarks

Chaque chiffre de la partie 2 (méthodologie) est produit par un script de `scripts/`. Les
protocoles sont déclarés dans `configs/` avant toute exécution, et le code testé se trouve
dans `src/telemonitor/`. Pour Docker, voir `C:\Projects\INFRA.md`.

## 1. Installation

Depuis le dossier `C:\Projects\telemonitor-research` :

```
python -m venv .venv
.venv\Scripts\activate            (Windows)   |   source .venv/bin/activate  (Linux/Mac)
pip install -e .[test,bench,serve]
python -m pytest                  (toute la suite de tests doit passer)
```

Un environnement virtuel (`.venv`) est conseillé : il évite de modifier le Python du système.

## 2. Données

| Données | Emplacement | Origine |
|---|---|---|
| Fiches de Douala (scénario D) | `cohortB_complete.csv` | transcription des fiches de surveillance |
| Consultations de Douala (scénario A) | `data/patient_data_REAL_DO_NOT_MODIFY.csv` | ne jamais modifier |
| Démo eICU 2.0.1 | `data/external/eicu-demo-2.0.1/` | https://physionet.org/content/eicu-crd-demo/2.0.1/ (accès libre) |

Pour la démo eICU, téléchargez au minimum `patient`, `diagnosis`, `pastHistory`,
`vitalAperiodic`, `vitalPeriodic`, `lab` (fichiers `.csv.gz`) et `SHA256SUMS.txt` dans ce
dossier. Le code vérifie les empreintes SHA-256 avant toute utilisation. Le dossier est
exclu de git.

La base eICU complète (benchmark définitif) exige un compte PhysioNet, la formation CITI
« Data or Specimens Only Research » et la signature de l'accord d'utilisation. Une fois
téléchargée, placez-la dans un dossier de même structure et pointez `DEMO` dans
`scripts/_common.py` vers ce dossier.

## 3. Les scripts, dans l'ordre de la méthodologie

| Script | Étape | Ce qu'il reproduit | Durée |
|---|---|---|---|
| `01_douala_audit.py` | 2 | description de la cohorte, contrôles qualité, chiffres terminaux (appareil électronique), incertitude des étiquettes (27 / 39 / 56 %), distributions → `out/audit_cohort.json` | secondes |
| `02_label_rules.py` | 1 | ancienne règle contre règle sourcée, variante plafonnée, 103 mesures reclassées si l'on utilise toutes les bandes NEWS2 → `out/label_rules.csv` | secondes |
| `03_pca_exploration.py` | — | analyse PCA exploratoire de l'ancien pipeline (≈ 7 dimensions effectives ; logistique sur 2 composantes ≈ XGBoost à 16 variables) | ≈ 5 min |
| `04_sample_size.py` | 4 | critères de Riley (Douala et démo eICU), parité avec `pmsampsize` (n = 662) ; option `--no-eicu` | ≈ 2 min |
| `05_eicu_cohort.py` | 4 | éligibilité eICU, harmonisation au rythme des fiches, échantillons et prévalences | ≈ 1 min |
| `06_benchmark.py` | 6–9 | benchmark imbriqué sur eICU et validation externe sur Douala → un dossier de run `out/runs/<tâche>_<délai>h_<id>/` (voir ci-dessous) | `--quick` : minutes ; complet : ≈ 12 h par tâche |
| `07_app_parity_fixture.py` | 11 | fixture de parité des niveaux pour l'app Flutter (`flutter test`) ; à relancer après toute modification des seuils | secondes |
| `08_figures.py` | — | retrace toutes les figures d'un run à partir de ses sauvegardes, sans recalcul → `<run>/figures/` (PDF, PNG et CSV des valeurs tracées) | secondes |
| `09_kappa_sample_size.py` | 2 | taille de l'échantillon à réétiqueter par le médecin : demi-largeur de l'IC du kappa pondéré ≤ 0,10 → ≈ 100 lectures (κ ≈ 0,75) à 150 (κ ≈ 0,6) | ≈ 1 min |
| `10_sensitivity_flags_slots.py` | 3–4 | sensibilité de n₀ du MAD (5 / 7 / 9 lectures signalées pour n₀ = 10 / 20 / 40) et de la tolérance des créneaux eICU (± 1 / 2 / 3 h → 645 / 1 356 / 1 983 échantillons glycémiques) ; option `--no-eicu` | ≈ 1 min |
| `12_state_comparison.py` | 10b | benchmark des 8 mesures de comparaison d'état (cosinus, euclidiennes, Manhattan, Chebyshev, Mahalanobis ; `configs/state_compare.yaml`) : AUROC pour le changement de niveau et la nouvelle alerte, développement eICU, contrôle externe Douala → `out/state_comparison.csv/.json`, échelles → `artifacts/state_scales.json`. Reporter ensuite la mesure retenue dans `configs/state_compare.yaml` (`status: selected`, `selected: <mesure>`) | ≈ 1 min |
| `11_export_model.py` | 11 | exporte le modèle retenu (famille de plus faible coût de sélection dans la recherche finale sur tout eICU) d'un run **complet** vers `artifacts\<tâche>\`, lu par le service et le worker ; refuse un run étiqueté avec d'autres seuils | secondes |

Exemples (depuis `C:\Projects\telemonitor-research`) :

```
python scripts\01_douala_audit.py
python scripts\04_sample_size.py --no-eicu
python scripts\06_benchmark.py --quick
python scripts\06_benchmark.py --tasks haemodynamic
python scripts\06_benchmark.py --tasks glycaemic --leads 0 12 36
python scripts\08_figures.py                 (dernier run)   |   --all   |   --run out\runs\<dossier>
```

Les deux tâches peuvent tourner en parallèle, dans deux terminaux.

### Dossier de run : les sauvegardes qui permettent de retracer les figures

Chaque run est enregistré dans `out\runs\<tâche>_<délai>h_<id>\`, où `<id>` est une empreinte
de ce qui détermine ses résultats : tâche, délai, candidats, configurations effectives,
empreintes des données.

| Fichier | Contenu |
|---|---|
| `manifest.json` | identité, entrées, sessions de calcul (date, version et état git du code, environnement Python, commande), progression, statut |
| `config\` | les configurations effectivement utilisées |
| `code\<version>\` | copie du code (`src\telemonitor`, `scripts\`) pour chaque version utilisée |
| `folds.csv` | résultats par pli externe et par modèle |
| `trials.csv` | tous les essais d'hyperparamètres : paramètres, mesures internes, coût, configuration retenue |
| `predictions\outer\r<répétition>_f<pli>\<modèle>.npz` | prédictions de chaque pli externe : échantillon, patient, niveau observé, probabilités |
| `external\` | prédictions Douala, mesures (`external.csv`), modèles finaux (`models\*.joblib`) |
| `summary.json`, `figures\` | synthèse finale ; figures retracées par `08_figures.py` |

Les fichiers sont écrits de façon atomique, et un pli n'est enregistré que lorsqu'il est complet.

**Reprise.** Un run interrompu se relance avec la **même commande** : même empreinte, donc même
dossier, et les plis déjà enregistrés sont conservés. Changer une configuration ou les données
crée un nouveau dossier, sans écraser l'ancien.

**Run long sous Windows**, une fenêtre par tâche avec les barres de progression (chemin absolu,
depuis n'importe quel dossier) :

```
powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\relancer_benchmarks.ps1
```

Le journal `out\runs\<run>\run.log` indique, pour chaque pli et chaque candidat, la durée et le
RPS externe. Fermer une fenêtre arrête le run ; la même commande le reprend.

## 4. Où modifier un choix

| Choix | Fichier | Remarque |
|---|---|---|
| Seuils d'étiquetage, variante de sensibilité | `configs/thresholds.yaml` | chaque règle cite sa source (clé de `references.bib`, vérifiée par les tests) |
| Poids de la fonction coût, seuils du bénéfice net | `configs/cost.yaml` | provisoires jusqu'à la réponse du médecin partenaire |
| Plis, répétitions, espaces de recherche, budgets | `configs/benchmark.yaml` | à fixer **avant** une exécution, puis à rapporter |
| Niveaux vert / jaune / rouge du service | `configs/serve.yaml` | provisoires |

## 5. Ancien pipeline (pour mémoire)

`train.py`, `features.py`, `TeleMonitor_model_REAL.ipynb` et les scripts `experiment*.py`
/ `verify_*.py` à la racine sont l'ancien pipeline. Ils ne servent plus qu'à reproduire
les chiffres antérieurs (par exemple : prévision à 0,425 contre 0,452 pour la persistance
avec `python train.py`). Les chiffres de `CALIBRATION.md`, `FINDINGS.md` et
`EXPERIMENTS.md` viennent de **données synthétiques** et ne doivent pas être présentés
comme des résultats. Les fichiers `out\benchmark_*.csv` du premier essai (19–20/10) ne
contiennent ni les essais ni les prédictions : ils ne permettent pas de retracer les figures.

## 6. Service local (FastAPI)

```
set TELEMONITOR_ARTIFACTS=artifacts          (dossier contenant haemodynamic/ et glycaemic/)
uvicorn telemonitor.serve.app:app --app-dir src --host 0.0.0.0 --port 8000
```

Pour que l'application l'utilise (émulateur Android ; `10.0.2.2` désigne la machine hôte) :

```
cd C:\Projects\telemonitor
flutter run --dart-define=RISK_API_URL=http://10.0.2.2:8000
```

Sans `RISK_API_URL`, l'application applique seulement la règle clinique (plancher), hors ligne.

`GET /health` et `POST /v1/risk` ; la documentation interactive est disponible sur
`http://127.0.0.1:8000/docs`. Pour la version web de l'application, autoriser son origine :
`set TELEMONITOR_CORS=http://localhost:5000`.

Après un benchmark complet : `python scripts\11_export_model.py`, puis redémarrer le service.
Sans artefact, le service applique seulement la règle (plancher).

## 7. Worker local : les fonctions serveur du chapitre 4

`src/telemonitor/serve/worker.py`, réglages dans `configs/worker.yaml` (délais provisoires). À
chaque cycle (60 s), pour chaque patient :

| Fonction | Ce qu'elle fait |
|---|---|
| Contrôle de la mesure | drapeau qualité (`quality.py`) écrit sur chaque nouvelle lecture |
| Escalade | lecture jaune ou rouge → événement « règle » (même identifiant que celui écrit par le téléphone : jamais de doublon) |
| Score | dernière lecture → règle + modèle (même code que l'API) ; un modèle qui relève le niveau → événement « modèle » |
| Notification | chaque nouvel événement, une fois : rouge → patient et clinicien ; jaune → patient ; jamais de consigne de dose |
| Non-transmission | pas de lecture depuis la période de contrôle → événement et rappel au patient |
| Âge de la file | événement ouvert trop longtemps (rouge 4 h, jaune 72 h) → transmis au remplaçant nommé par le clinicien, tous deux notifiés |
| Verdict | événement fermé → le patient est informé de la revue |

Les lectures et événements de plus de 24 h trouvés au premier lancement sont marqués sans être
notifiés (pas d'avalanche). Le SMS de secours n'est pas construit.

Il faut une clé de compte de service Firebase (console Firebase → Paramètres du projet →
Comptes de service → Générer une nouvelle clé privée), enregistrée dans
`secrets\service-account.json` (dossier exclu de git ; ne jamais la partager). Dans un
environnement virtuel (firebase-admin exige une autre version de httpx que d'autres outils
installés sur cette machine) :

```
python -m venv .venv
.venv\Scripts\activate
pip install -e .[serve,worker]
python -m telemonitor.serve.worker --credentials secrets\service-account.json --once    (un cycle, pour tester)
python -m telemonitor.serve.worker --credentials secrets\service-account.json           (en continu)
```

Avec Docker : `docker compose --profile worker up -d worker`.
