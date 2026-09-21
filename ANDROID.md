# Android — AAA škola

- Balíček: `cz.aaaskola.app`, název **AAA škola**, čeština, zdarma.
- Google Play: organizace **Stafio.cz**, účet `5191506570243272151`.
- První vydání: `1.0.0+2`; další vydání musí zvýšit číslo za `+`.
- Flutter 3.44.8, JDK z Android Studia, Android SDK dle Flutteru.
- API a katalog: `https://aaaskola.cz`. Přihlášené procvičování vyžaduje internet.

## Ověření a sestavení

`android/key.properties` je ignorovaný lokální soubor se stejným formátem jako
u ostatních Stafio Flutter aplikací: `storeFile`, `storePassword`, `keyAlias`,
`keyPassword`. Používá se fleet upload keystore a alias `upload`.
Hesla ani klíče nepatří do repozitáře. Release bez podepisovacích údajů selže.

```powershell
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter test integration_test/android_test.dart -d emulator-5554
flutter build appbundle --release
flutter build apk --release
```

Integrační test potřebuje spuštěný čistý Android emulátor a připojení k živému
katalogu. Ověří nativní zabezpečené úložiště, načtení tříd a zachování testu hosta
po novém vytvoření aplikace. Nezapisuje výsledky do účtu na serveru.
Serverové testy spouštěj příkazem `npm test` v `server/` pouze s dedikovanou
PostgreSQL databází, jejíž jméno končí `_test` — testy její účty mažou.

Výstupy jsou `build/app/outputs/bundle/release/app-release.aab` pro Play a
`build/app/outputs/flutter-apk/app-release.apk` pro přímou instalaci.
Ověř identifikátor, verzi a release podpis. Před uploadem archivuj balíčky
spolu s commitem zdroje a SHA-256 mimo repozitář.

## Vydání

Nejdříve vydej server s podporou mobilního přihlášení udržovaným příkazem
`scripts/aaaskola/deploy.cmd` v rodičovském workspace `stafio-app`.
Při prvním vydání vytvoř záznam AAA škola v Play Console pod Stafio.cz;
identifikátor aplikace po nahrání balíčku nelze měnit.

Použij zavedený postup Stafio pro **internal** track, fleet upload klíč a
existující Play publisher účet. Runbook rodičovského workspace:
`doc/app/stafio-frontend-flutter/deploy-android.md`.
První balíček a Play App Signing se inicializují v konzoli, další vydání
lze nahrávat stejným Publisher API helperem jako ostatní aplikace.
Po výdeji ověř aktivní versionCode a odkaz pro přihlášení testerů. Interní
testovací vydání není veřejné vydání do produkce.

Veřejné informace o údajích a žádosti o odstranění účtu jsou na
`https://aaaskola.cz/privacy` a dostupné z obrazovky účtu v aplikaci.
Před veřejným vydáním doplň v Play Console pravdivé údaje o cílovém věku,
obsahu a zpracování dat, hodnocení obsahu, popis a snímky aplikace.

## Přihlášení

Android otevře `/login` s náhodným stavem a SHA-256 otiskem jednorázového
ověřovacího tajemství. Po standardním Google přihlášení se vrátí na
`cz.aaaskola.app:/login` s kódem platným dvě minuty. `/api/auth/mobile`
vymění kód pouze jednou a pouze se správným tajemstvím za 30denní session.
V databázi se ukládají jen otisky kódů a tokenů. Není potřeba další Google
OAuth klient ani nový přístup k údajům Google účtu.

Mobilní klient posílá token výhradně na origin API, nepřeposílá jej při
přesměrování a při odhlášení jej odstraní. Zápisy vyžadují také CSRF token
dané session. Web nadále používá HttpOnly cookie a kontrolu originu.
Android zálohování je vypnuté, aby neobnovovalo staré přihlášení a postup.
