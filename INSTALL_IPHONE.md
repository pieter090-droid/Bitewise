# Bitewise op iPhone installeren

## Een unsigned IPA bouwen

1. Voeg in GitHub onder **Settings → Secrets and variables → Actions** de repository secrets `SUPABASE_URL` en `SUPABASE_ANON_KEY` toe. Gebruik uitsluitend de publieke anon key; gebruik nooit een `service_role`, `sb_secret_...` of andere geheime Supabase-key in de app.
2. Ga naar **GitHub → Actions → iOS build → Run workflow** en start de workflow.
3. Open de voltooide workflow-run en download het artifact **`bitewise-ios-unsigned`**.
4. Pak het artifact uit en installeer `app-unsigned.ipa` via [Sideloadly](https://sideloadly.io). Sideloadly signeert de app met je Apple-ID voordat deze op je iPhone wordt gezet.

Bij de eerste scan vraagt iOS om cameratoegang. Sta die toe om productbarcodes te scannen.

## Camera scannen

Voor een echte camera-barcode-scan moet je de geïnstalleerde iOS-app gebruiken. De webversie in Safari op iPhone blijft door browserbeperkingen zoeken en handmatige barcode-invoer gebruiken.
