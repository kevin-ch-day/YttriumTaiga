# Data Schemas

This directory is the machine-readable source for core CSV contracts.

- `manifest.csv` maps tracked CSV files to schema header files.
- `*.header` files contain the exact expected header row for a CSV artifact.
- Generated runtime artifacts are documented here even when they are gitignored.

Validate tracked schemas with:

```bash
Scripts/ccdc_schema_check.py
```

The repo-level validator also runs this check:

```bash
Scripts/ccdc_validate.sh
```

