# Proxmox Private Scripts

A private collection of Proxmox VE LXC installer scripts with a shared shell framework for reusable host-side and in-container setup logic.

## Repository layout

```text
.
├── apps/
│   ├── decypharr/
│   │   ├── README.md
│   │   ├── ct/
│   │   │   └── decypharr.sh
│   │   └── install/
│   │       └── decypharr-install.sh
│   ├── jd2-pia/
│   │   ├── README.md
│   │   ├── ct/
│   │   │   └── jd2-pia.sh
│   │   └── install/
│   │       └── jd2-pia-install.sh
│   └── shelfmark/
│       ├── README.md
│       ├── ct/
│       │   └── shelfmark.sh
│       └── install/
│           └── shelfmark-install.sh
├── bootstrap/
│   ├── decypharr.sh
│   ├── jd2-pia.sh
│   └── shelfmark.sh
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
- Ensure in-container installers can run as standalone scripts after being copied into a container

## Current apps

- `decypharr`
- `jd2-pia`
- `shelfmark`

## Using Decypharr

Run from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/decypharr.sh?nocache=$(date +%s)")"
```

The bootstrap script downloads the shared library files plus the Decypharr app entrypoint into a temporary directory, then runs it. The `?nocache=$(date +%s)` query string busts GitHub's CDN cache, which can otherwise serve a stale copy for a few minutes after a push.

## Using JDownloader2 + PIA

Run from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/jd2-pia.sh?nocache=$(date +%s)")"
```

The bootstrap script downloads the shared library files plus the JDownloader2 + PIA app entrypoint into a temporary directory, then runs it. The `?nocache=$(date +%s)` query string busts GitHub's CDN cache, which can otherwise serve a stale copy for a few minutes after a push. See [apps/jd2-pia/README.md](apps/jd2-pia/README.md) for the post-install PIA login step and kill-switch caveats.

## Using Shelfmark

Run from a Proxmox VE shell:

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/obstruct-exit-emit/proxmox-private-scripts/main/bootstrap/shelfmark.sh?nocache=$(date +%s)")"
```

Unlike the other two apps, this one installs Docker and builds the app from source (cloning `obstruct-exit-emit/shelfmark` and running `docker compose up -d --build`) rather than running a precompiled binary or pulling a prebuilt image — see [apps/shelfmark/README.md](apps/shelfmark/README.md) for why.

The host-side entrypoint may copy a single install script into the container, so every file under `apps/<app>/install/` must be self-contained and must not depend on repo-relative `lib/` paths being present inside the container.

## Scaffolding a new app

Use the scaffold helper:

```bash
tools/new-app.sh <app-slug> [display-title] [port] [upstream-repo] [update-support]
```

Examples:

```bash
tools/new-app.sh radarr
tools/new-app.sh qbittorrent qBittorrent 8080 qbittorrent/qBittorrent true
tools/new-app.sh customapp "Custom App" 9000 owner/repo false
```

It creates:

```text
apps/myapp/README.md
apps/myapp/ct/myapp.sh
apps/myapp/install/myapp-install.sh
bootstrap/myapp.sh
```

The generated files are prefilled with:

- app slug
- display title
- default port
- upstream GitHub repo
- optional update-helper behavior
- a standalone in-container installer pattern that avoids repo-relative library dependencies
