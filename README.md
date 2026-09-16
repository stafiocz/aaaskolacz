# AAA škola

Samostatná Flutter aplikace pro hravé procvičování počítání a cizích jazyků.
Ikonu tvoří budova školy s hodinami a nápisem AAA, otevřená učebnice ABC / 123
a usměvavá zlatá hvězdička na zeleném pozadí. Název se zobrazuje jako **AAA škola** v kulatém písmu
Nunito se třemi barevnými A.

Cílová doména aplikace: [aaaskola.cz](https://aaaskola.cz/).

Procvičování automaticky míchá všechny typy příkladů:

- **Násobilka:** násobení čísel 1–9.
- **Dělení:** dělení beze zbytku, dělitel 1–9, výsledek 0–10.
- **Závorky:** sčítání a odčítání do 100, například `59 − (23 + 7) = ?`.
  Čísla, mezivýsledek i výsledek jsou nezáporné a nejvýše 100.
- **Doplň násobení:** například `7 × ? = 21`, chybějící číslo 0–10.
- **Doplň dělení:** například `12 : ? = 4`, chybějící dělitel 1–9.

Každý příklad má jednoznačnou celočíselnou odpověď. Nikdy se nedělí nulou.
Každá pětice obsahuje všechny typy v náhodném pořadí; stejný typ nenásleduje
hned po sobě ani na přechodu mezi pěticemi. Oblasti se ručně nevybírají.
Anglická a německá slovíčka jsou plánovaným rozšířením.

- Náhodný příklad, velká klávesnice na displeji a kontrola odpovědi.
- Po chybě zůstane stejný příklad; první nová číslice nahradí chybnou odpověď.
- Po správné odpovědi se zobrazí pochvala a tlačítko **Další příklad**.
- Počítadlo vyřešených příkladů platí pro aktuální spuštění napříč typy cvičení.
- Další příklad automaticky změní typ cvičení a vymaže předchozí odpověď.
- **C** smaže celou odpověď, **⌫** poslední číslici.
- Fungují také číslice na fyzické klávesnici, Enter, Backspace a Delete/Escape.

Není potřeba účet ani backend. Mobilní aplikace počítá příklady lokálně.

## Spuštění

Vyžaduje Flutter s Dartem 3.12.2 nebo novějším.

```powershell
flutter pub get
flutter run -d chrome
```

Pro Android připojte telefon s povoleným laděním USB nebo spusťte emulátor
a vyberte jej pomocí `flutter run`. iOS projekt je připraven pro spuštění
na macOS s Xcode; není zde ověřený.

## Kontrola a sestavení

```powershell
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

Webový výstup vzniká v `build/web`, Android APK v
`build/app/outputs/flutter-apk/app-debug.apk`.

## Docker Swarm

Produkční web běží na **https://aaaskola.cz/** ve stacku `products-aaaskola`,
služba `products-aaaskola_web`. Kontejner nginx poslouchá na portu 8080;
HTTPS a certifikát Let's Encrypt zajišťuje společný Traefik přes síť `servers`.
DNS záznam A pro `aaaskola.cz` musí směřovat na `77.78.90.63`.

Sestavení používá Flutter **3.44.8** a image `stafio/aaaskolacz:sha-<commit>`.
Workflow v tomto repozitáři kontroluje kód, testy i všechny soubory obsluhované
kontejnerem. Volá se z infrastrukturního repozitáře, kde jsou uloženy přístupy
k Docker Hubu a Swarmu.

### Vydání

Ze Stafio workspace použijte udržovaný deploy skript:

```powershell
scripts\aaaskola\deploy.cmd
```

Parametr `-WhatIf` ověří vstupy bez změn. Skript očekává čistý a pushnutý
`main` této aplikace v `../aaaskolacz` vedle workspace; jiné umístění přijímá
přes `-RepoPath`. Připne image, commitne a pushne infrastrukturní konfiguraci,
počká na Actions a ověří veřejné HTTPS, zdrojové SHA i faviconu.
[Podrobný postup](https://github.com/stafiocz/stafio-app/blob/main/scripts/aaaskola/README.md).

Ruční postup odpovídající skriptu:

1. Commitněte a pushněte zdroje do `main` a zjistěte celé SHA commitu.
2. V repozitáři [infrsastructure-ds](https://github.com/stafiocz/infrsastructure-ds)
   nastavte v `products/aaaskola.yml` image `stafio/aaaskolacz:sha-<commit>`.
   Commitněte a pushněte s `[no-ticket] [skip ci]` — sestavení zajistí další krok.
3. Spusťte workflow **Release AAA skola** s parametrem `source` nastaveným na SHA:

   ```powershell
   gh workflow run release-aaaskola.yml -R stafiocz/infrsastructure-ds -f source=<cele-SHA>
   ```

Workflow sestaví a ověří image, porovná ji s pinem ve stacku a vydá pouze
`products-aaaskola`, připnutou na digest. První nasazení i další aktualizace
používají stejný postup. Služba má kontrolu dostupnosti, při aktualizaci
nejdřív spustí novou instanci a při selhání provede rollback.

Po vydání ověřte `https://aaaskola.cz/healthz`, SHA v `/release.json`
a zadání správné i chybné odpovědi v prohlížeči.

### Rollback

Přes existující infrastrukturní workflow `maintenance.yml` spusťte
`sudo docker service rollback products-aaaskola_web`. Vraťte také pin image
v `products/aaaskola.yml` a commitněte ho s `[no-ticket] [skip ci]`.
První nasazení nemá předchozí verzi; případné odstranění se týká pouze
stacku `products-aaaskola`.

### Lokální kontejner

```powershell
flutter build web --release --no-web-resources-cdn
docker build -t aaaskola .
docker run --rm -p 8080:8080 aaaskola
```
