# MaxVolt Orbit — Flutter implementation

Base: `app-sector-31`, commit `b9f4664`. Design approved in the conversation.

## Delivered behavior

- Native Material 3 themes using the supplied MaxVolt palette and bundled logos, including Android and iOS icons. Theme selection is persisted in secure storage; no font download is required for the app theme. Alro font files were not supplied; platform typography is used.
- Header wallet (app balance only) and account gear. Bottom navigation: Mapa, Cargar, Historial. Existing registration, profile, vehicles, payment validation and notifications remain accessible.
- Real map, search, combined connector/availability filters, OSM attribution, location fallback, connector details and navigation to the station. Missing prices and telemetry are never replaced with example data.
- Live charge ring only for valid vehicle SoC, energy/power/cost from the API, stale-connection warning, hold-to-stop plus confirmation. The stop response is a request acknowledgement, not evidence that the connector is safe to unplug.
- History and session receipt use actual API records. A completion receipt opens only after the backend confirms `Completed`.
- Wallet distinguishes app and physical-card balances; existing Libélula checkout and fiscal-data workflow remain in place.

## Domain and deployment prerequisites

Default API: `https://maxvolt.net/api/v1/mobile/`.

Optional Firebase Remote Config keys are now namespaced:

- `maxvolt_apiBaseUrl`
- `maxvolt_wsHost`
- `maxvolt_reverbKey`
- `maxvolt_disclaimerUrl`

Legacy keys cannot override these defaults. HTTPS endpoints are limited to maxvolt.net and its subdomains. Existing Firebase project identifiers and application IDs have not been changed; changing them would require the corresponding Firebase registrations and signing configuration. Firestore station updates use `maxvolt_stations`; the API is refreshed every 30 seconds as fallback. Configure the CMS bridge/rules for this collection when enabling realtime updates.

Configure backend HTTPS, APP_URL, public asset URLs, payment notification URL, and legal URLs for MaxVolt. Both `e2vapp://payment-complete` and `maxvolt://payment-complete` are registered for compatibility. The API route contracts still come from the supplied CMS repository. In that snapshot `/wallet/history/download` was missing: the existing download entry still requires that backend route. The CMS security findings from the review (unverified topup and stop authorization) are separate backend changes and must be resolved before production rollout.

The Android application ID remains `bo.e2v.chargestation`; retain the existing signing identity to update installed applications. No production configuration, data, payment or charger was modified from this workspace.

## Validation

Dart source syntax was parsed/formatted locally. Full local Flutter setup was blocked by automatic approval review when dependency initialization attempted an instance-metadata request; that command was not retried.

`MaxVolt Flutter validation` runs analysis, widget/state tests and a debug APK build in an isolated GitHub-hosted runner with read-only repository permissions and no production secrets. Its result is the source of truth for build status. The debug APK is for testing, not store publication. Android/iOS device testing of camera, location, payments, deep links and actual charger transitions remains required. iOS compilation requires macOS/Xcode.

Tests cover combined connector filters, domain protection, retention of an active session on failures, distinct wallet balances, null SoC/narrow layouts in both themes, and hold-to-stop.
