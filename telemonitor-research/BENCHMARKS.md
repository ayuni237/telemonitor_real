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

**Run long sous Windows**, détaché de la fenêtre (chemin absolu, depuis n'importe quel dossier) :

```
powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\relancer_benchmarks.ps1
Get-Content C:\Projects\telemonitor-research\out\run_haemodynamic_0.log -Wait
```

Le journal `out\run_<tâche>_0.log` indique, pour chaque pli et chaque candidat, la durée et le
RPS externe ; `out\run_<tâche>_0.err` contient les barres de progression.

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
`http://127.0.0.1:8000/docs`.
