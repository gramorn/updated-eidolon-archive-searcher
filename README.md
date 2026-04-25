# Eidolon Archive

A lightweight Aura Kingdom Eidolon Archive app that:

- downloads latest combo data from AuraKingdom-DB
- rebuilds a local static page with icons and category totals
- opens as a desktop-like app window on Windows
- can be hosted as a static website (for example, GitHub Pages)

## Repository

Official GitHub repository:

https://github.com/gramorn/updated-eidolon-archive-searcher.git

## Features

- Automatic data fetch from source page
- Local icon cache in `assets/eidolons`
- Search filter for combos
- Category grouping with combined totals
- Simple desktop launcher for Windows (Edge app mode)

## Project Structure

- `index.html`: generated static page shown to users
- `assets/eidolons`: cached eidolon icons
- `atualizar_eidolons.ps1`: fetches latest data and regenerates `index.html`
- `EidolonApp.ps1`: desktop launcher with update check prompt
- `Iniciar.vbs`: silent launcher for `EidolonApp.ps1`
- `version.txt`: current combo-count version used by updater

## Requirements

- Windows PowerShell 5.1 or later
- Internet connection for update runs
- Microsoft Edge (for app window mode)

## Local Usage

### 1. Regenerate data and page

```powershell
./atualizar_eidolons.ps1
```

### 2. Open desktop app

Double-click `Iniciar.vbs`

Or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "EidolonApp.ps1"
```

## Publish as Static Site

You can host this project for free on GitHub Pages.

Basic steps:

1. Push this repository to GitHub.
2. Enable Pages in repository settings.
3. Deploy from branch `main`, folder `/ (root)`.

Note: `EidolonApp.ps1` and `Iniciar.vbs` are local desktop helpers. They do not run in a hosted browser environment.

## Automatic Updates in GitHub

This repository includes a GitHub Actions workflow in `.github/workflows/update-eidolons.yml`.

It can:

- run manually
- run daily on schedule
- regenerate `index.html` and `version.txt`
- commit and push updates when changes are detected

After enabling Actions and Pages, your hosted site can stay up to date automatically.

## License

MIT License. See `LICENSE`.
