# Eidolon Archive

A static Aura Kingdom Eidolon Archive website that:

- downloads latest combo data from AuraKingdom-DB
- rebuilds a local static page with icons and category totals
- can be hosted as a static website (for example, GitHub Pages)

This project uses updated data from AuraKingdom-DB and is also inspired by the Eidolon Archive by Xilla:

https://ak-eido-archive.carrd.co/

## Repository

Official GitHub repository:

https://github.com/gramorn/updated-eidolon-archive-searcher.git

## Features

- Automatic data fetch from source page
- Local icon cache in `assets/eidolons`
- Automatically regenerated Excel template with the current Eidolon list
- Search filter for combos
- Category grouping with combined totals
- Additional guides for Eidolons, dungeons, and character progression

## Project Structure

- `index.html`: static website shown to users
- `assets/eidolons`: cached eidolon icons
<<<<<<< HEAD
- `assets/icons`: cached guide icons
- `atualizar_eidolons.ps1`: fetches latest data and regenerates `index.html`
=======
- `atualizar_eidolons.ps1`: fetches latest data and regenerates `index.html` and the Eidolon stars Excel template
- `EidolonApp.ps1`: desktop launcher with update check prompt
- `Iniciar.vbs`: silent launcher for `EidolonApp.ps1`
>>>>>>> 74ec9173706d2a993a79f1f3fc10ac1863ad7805
- `version.txt`: current combo-count version used by updater

## Website

The site is static and can be served directly from `index.html`. No desktop app or installation is required.

## Updating site data

To fetch the latest data and regenerate the site locally, use Windows PowerShell 5.1 or later:

```powershell
./atualizar_eidolons.ps1
```
