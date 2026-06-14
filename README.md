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
├── bootstrap/
│   └── decypharr.sh
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
- Preserve simple `curl | bash` entrypoints via `bootstrap/`

## Current apps

- `decypharr`

## Using Decypharr

Run from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/decypharr.sh)"
```

The bootstrap script downloads the shared library files plus the Decypharr app entrypoint into a temporary directory, then runs it.

## Scaffolding a new app

Use the scaffold helper:

```bash
tools/new-app.sh myapp
```

It creates:

```text
apps/myapp/README.md
apps/myapp/ct/myapp.sh
apps/myapp/install/myapp-install.sh
bootstrap/myapp.sh
```

The generated files are prefilled with the app name so you can start editing immediately.
