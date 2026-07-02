# Bitewise op je iPhone testen (zonder Mac)

Je zit op Windows, dus je bouwt de iOS-app in de cloud (GitHub Actions, macOS-
runner) en installeert hem daarna op je iPhone. **Belangrijk vooraf:** een app op
een gewone iPhone zetten kan alléén met Apple-signing. Er zijn twee wegen:

| Weg | Kosten | Wie het past |
|-----|--------|--------------|
| **Sideloadly** + gratis Apple-ID | Gratis | Even snel zelf testen. Cert verloopt na **7 dagen** → wekelijks opnieuw sideloaden; max 3 apps. |
| **Apple Developer Program** + TestFlight | $99/jaar | Blijvend testen, ook door anderen. Makkelijkste op termijn. |

---

## Stap 1 — Zet de code op GitHub

1. Maak een **lege** repo aan op <https://github.com/new> (bv. `bitewise`,
   zonder README/gitignore aanvinken).
2. Koppel en push vanuit de projectmap:

```bash
git remote add origin https://github.com/<jouw-gebruikersnaam>/bitewise.git
git push -u origin master
```

> Je hebt al een commit lokaal, dus dit uploadt meteen alles. Bij het pushen vraagt
> Git om in te loggen (browser of Personal Access Token).

## Stap 2 — Laat GitHub de iOS-app bouwen

1. Open je repo op GitHub → tabblad **Actions**.
2. Kies de workflow **"iOS build (unsigned)"** → **Run workflow** (of hij start al
   automatisch door de push).
3. Wacht tot de run groen is (~10–15 min de eerste keer).
4. Open de voltooide run → onderaan bij **Artifacts** → download
   **`bitewise-ios-unsigned`**. Pak het zip uit → je hebt `app-unsigned.ipa`.

## Stap 3a — Installeren met Sideloadly (gratis)

1. Installeer **Sideloadly** (Windows): <https://sideloadly.io> — en **iTunes**
   (Apple USB-driver), als je die nog niet hebt.
2. Sluit je iPhone met USB aan en tik op **Vertrouwen** op het toestel.
3. Open Sideloadly → sleep `app-unsigned.ipa` erin → vul je **Apple-ID** in
   (een gratis account volstaat) → **Start**. Sideloadly signeert de app met een
   gratis ontwikkelaarscertificaat.
4. Op de iPhone: **Instellingen → Algemeen → VPN & apparaatbeheer** →
   tik op jouw Apple-ID → **Vertrouwen**.
5. Open **Bitewise**. Klaar.

> Beperkingen van de gratis route: de app werkt **7 dagen**, daarna opnieuw
> sideloaden. Camera-toestemming: bij de eerste scan tik je op "Sta toe".

## Stap 3b — Installeren via TestFlight (betaald, aanrader op termijn)

1. Word lid van het **Apple Developer Program** ($99/jaar).
2. Laat de build **gesigneerd** uploaden naar App Store Connect. Het handigst is
   **[Codemagic](https://codemagic.io)** (gratis minuten, Flutter-vriendelijke UI,
   regelt signing en TestFlight-upload voor je) — of breid deze GitHub-workflow uit
   met je signing-certificaten en `flutter build ipa` + upload.
3. Nodig jezelf uit in **TestFlight** en installeer de app via de TestFlight-app.

---

## Wat werkt er meteen, wat niet?

- **Onboarding, home + weekgrafiek, tracker, settings, favorieten** werken direct,
  ook zonder backend (lokale data).
- **Scanner → productdetail → SnackSwap** heeft Supabase nodig. De cloud-build
  draait zonder echte keys (local-only), dus scannen geeft dan "geen product
  gevonden". Wil je die flow testen, vul dan vóór de build `assets/env/env.json`
  in (of voeg de keys als GitHub Secret + build-stap toe) en laad het Supabase
  schema + `seed.sql`.

## Kan ik (Claude) dit voor je pushen?

Niet automatisch — daarvoor moet ik met jouw GitHub-account ingelogd zijn, en dat
is hier niet het geval. Stap 1 (de twee git-commando's) doe je dus zelf; de rest
loopt daarna vanzelf via GitHub Actions.
