# Proxmox Private Scripts

A private collection of Proxmox VE LXC installer scripts with a shared shell framework for reusable host-side and in-container setup logic.

## Repository layout

```text
.
├── apps/
│   └── decypharr/
│       ├── README.md
│       ├── ct/
│       │   └── decypharr.sh
│       └── install/
│           └── decypharr-install.sh
├── docs/
│   ├── conventions.md
│   └── structure.md
├── lib/
│   ├── common.sh
│   ├── github.sh
│   ├── lxc.sh
│   └── output.sh
├── templates/
│   ├── app-install-template.sh
│   └── ct-template.sh
└── tools/
    ├── new-app.sh
    └── validate.sh
```

## Design goals

- Keep each app self-contained under `apps/<app>/`
- Centralize reusable shell logic under `lib/`
- Make the repository easy to browse and extend
- Minimize copy/paste when adding new LXC installers

## Current apps

- `decypharr`

## Using Decypharr

Run from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/apps/decypharr/ct/decypharr.sh)"
```

## Next app workflow

Use the scaffold helper:

```bash
tools/new-app.sh myapp
```

Then fill in the generated files under `apps/myapp/`.
