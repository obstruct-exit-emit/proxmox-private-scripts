# Repository structure

This repository is organized for fast exploration and low-friction script authoring.

## Principles

1. **Apps live in `apps/`**
   - Every app gets its own directory.
   - Host-side and in-container logic stay together.

2. **Reusable logic lives in `lib/`**
   - Output helpers
   - GitHub/release helpers
   - LXC lifecycle helpers
   - Shared shell utilities

3. **Templates live in `templates/`**
   - Use these as a starting point for new installers.

4. **Utility scripts live in `tools/`**
   - Scaffolding
   - Validation
   - Repo maintenance

## App layout

Each app should follow this structure:

```text
apps/<app>/
├── README.md
├── ct/
│   └── <app>.sh
└── install/
    └── <app>-install.sh
```

## Naming conventions

- App directory: lowercase, hyphen-free where practical
- Host installer: `apps/<app>/ct/<app>.sh`
- In-container installer: `apps/<app>/install/<app>-install.sh`
- Shared library files: grouped by concern under `lib/`
