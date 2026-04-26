# Eidolon Archive

A lightweight Aura Kingdom Eidolon Archive app that:

- downloads latest combo data from AuraKingdom-DB
- rebuilds a local static page with icons and category totals
- opens as a desktop-like app window on Windows
- can be hosted as a static website (for example, GitHub Pages)

This project uses updated data from AuraKingdom-DB and is also inspired by the Eidolon Archive by Xilla:

https://ak-eido-archive.carrd.co/

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
