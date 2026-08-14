# Sari-Sari Store Inventory & Business App

Premium, offline-first mobile inventory and store management app for sari-sari stores. Built with **Flutter**, **Riverpod**, and **Drift (SQLite)** per your system plan.

## Features

- **Dashboard** — Today's sales, estimated profit, store health score, quick actions, recent activity
- **Inventory** — Product list with search, categories, stock status indicators
- **Add Product** — Camera/gallery photo, name, quantity, price, confirmation modal (no barcode)
- **Sales** — Fast new sale flow with cart, checkout, cash/change calculation
- **Restocking** — Add stock with optional purchase cost, confirmation step
- **Notifications** — In-app low stock, out of stock, and expiration alerts
- **Expenses** — Record business expenses with confirmation
- **Reports** — Daily/weekly/monthly sales, profit, expenses, charts, best sellers
- **Settings** — Store info, theme (light/dark/system), notification prefs, PIN/biometrics, backup/restore

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | Flutter (Material 3) |
| State | Riverpod |
| Database | Drift + SQLite |
| Fonts | Google Fonts (Inter) |
| Charts | fl_chart |

## Install on Android (Release)

Download the latest APK from **[GitHub Releases](https://github.com/betroyer/inventory_system/releases)**:

1. Open the release page on your phone or computer
2. Download `sari-sari-store-x.x.x.apk`
3. Open the file and allow **Install from unknown sources** if prompted
4. Launch **Sari-Sari Store**

### Publish a new release

1. Bump the version in `pubspec.yaml` (e.g. `1.0.1+2`)
2. Commit and push to `main`
3. Create and push a tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

GitHub Actions will build the APK and publish a release automatically.

## Getting Started (Development)

```bash
cd c:\app2
flutter pub get
dart run build_runner build
flutter run
```

Requires Flutter 3.x and an Android device/emulator (Android-first as specified in the plan).

## Project Structure

```
lib/
├── app/           # App shell, theme, navigation
├── core/          # Constants, utils, shared widgets
├── database/      # Drift tables, DAOs, migrations
├── features/      # dashboard, inventory, sales, reports, settings, ...
├── services/      # Settings, notifications, backup, stock alerts
└── shared/        # Providers, models, extensions
```

## Offline-First

All core functions work without internet. Data is stored locally in SQLite. Backup export/restore uses JSON files.

## Security

Optional local PIN lock and biometric unlock protect business records. No online authentication required for Version 1.

## Excluded (per plan)

Barcode scanning, online payments, customer accounts, multi-branch, cloud sync, AI.
