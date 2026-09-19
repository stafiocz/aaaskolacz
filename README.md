# AAA škola

Samostatná Flutter aplikace pro hravé procvičování počítání a cizích jazyků.
Ikonu tvoří budova školy s hodinami a nápisem AAA, otevřená učebnice ABC / 123
a usměvavá zlatá hvězdička na zeleném pozadí. Název se zobrazuje jako **AAA škola** v kulatém písmu
Nunito se třemi barevnými A.

Cílová doména aplikace: [aaaskola.cz](https://aaaskola.cz/).

Na úvodu je rozcestník **7. třída → Angličtina**, **5. třída → Matematika / Angličtina**
a **3. třída → Matematika**.
Z předmětu se lze vrátit na výběr předmětů a tříd.

## Testy, chyby a rozpracované kolo

Matematika, čeština a slovíčka mají kola po 15 úlohách (u slovníku s méně
položkami začíná kolo jejich počtem). Po každé chybě se zobrazí řešení a tlačítko
**Pokračovat**. Stejná úloha se vrátí po třech dalších zadáních. Zároveň se
přidá **jedna nová úloha navíc**: dvě chyby prodlouží kolo z 15 na 17 úloh.
Chyba při opakování i anglické **Nevím** prodlužují kolo stejným způsobem.
Na konci kola, kdy zbývá méně úloh, přijde opakování po těch zbývajících.

Kolo končí až po správném dokončení všech původních i přidaných úloh.
Chybný početní řetězec a česká úloha se opakují od prvního kroku; čeština
vždy vyžaduje správné písmeno i zdůvodnění. Počítadlo ukazuje dokončené úlohy,
celkový počet, chyby i přidané úlohy. Denní cíl zůstává 15 příkladů a 15
různých slovíček; přidané úlohy se běžně započítávají do historie.

Přihlášený účet má každé kolo v `practice_tests` v PostgreSQL, zvlášť pro třídu
a předmět. Odchod, obnovení stránky, další karta, odhlášení ani půlnoc nemění
aktuální zadání, frontu oprav ani prodloužení. Další kolo lze založit až po
dokončení stávajícího. Host má stejný postup uložený v daném prohlížeči.
Smazání úložiště může vymazat postup hosta, účet má postup v databázi.

`POST /api/{math,spelling,vocabulary}/exercise` vrací aktuální zadání a pokrok;
`newRound: true` založí nové kolo pouze po dokončení předchozího.
`POST /api/{math,spelling,vocabulary}/answer` ověří odpověď a atomicky uloží
výsledek, frontu i případnou další úlohu. ID pokusu zajišťuje, že opakované
odeslání při výpadku nepřidá chybu ani úlohu dvakrát. Číslo opakování `revision`
a krok chrání před zastaralou odpovědí z jiné karty.

Zadání v kole jsou uložená jako snímky, úpravy katalogu je nemění. Migrace
převezme již rozpracované matematické a české zadání včetně aktuálního kroku.
Přihlášené zkoušení vyžaduje spojení se serverem. Při výpadku se samo nepřepne
na nové zadání hosta; odpověď lze bezpečně odeslat znovu.

## 3. třída — Matematika

Procvičování automaticky míchá všechny typy příkladů:

- **Násobilka:** násobení čísel 1–9.
- **Dělení:** dělení beze zbytku, dělitel 1–9, výsledek 0–10.
- **Závorky:** sčítání a odčítání do 100, například `59 − (23 + 7) = ?`.
  Čísla, mezivýsledek i výsledek jsou nezáporné a nejvýše 100.
- **Doplň násobení:** například `7 × ? = 21`, chybějící číslo 0–10.
- **Doplň dělení:** například `12 : ? = 4`, chybějící dělitel 1–9.

Každý příklad má jednoznačnou celočíselnou odpověď. Nikdy se nedělí nulou.
Mix obsahuje také 24 příkladů na sčítání a odčítání do 100 z fotografií sešitu
ze 17. září. Výsledky se počítají z operandů, nepřebírají chybné odpovědi z fotek.
Základní kolo vybírá vyvážený mix typů. Opravy zachovávají původní zadání. Oblasti se ručně nevybírají.

- Náhodný příklad, velká klávesnice na displeji a kontrola odpovědi.
- Po chybě se zobrazí správná odpověď; příklad se zařadí k pozdějšímu opakování.
- Po správné odpovědi se zobrazí pochvala a tlačítko **Další příklad**.
- Počítadlo vyřešených příkladů platí pro uložené kolo napříč typy cvičení.
- Další příklad vymaže předchozí odpověď.
- **C** smaže celou odpověď, **⌫** poslední číslici.
- Fungují také číslice na fyzické klávesnici, Enter, Backspace a Delete/Escape.

## 5. třída — Matematika

Mix na `/#/5-trida/matematika` vychází z fotografií pracovního sešitu
**Miliony – opakování**, strany 4–8. Míchá databázový zásobník příkladů podobné obtížnosti:

- Sčítání a odčítání stovek, tisíců a milionů, nejvýše do 9 000 000.
  Po správné odpovědi se zobrazí zkouška opačnou operací.
- Násobení jednociferným číslem, včetně dvojciferných čísel a násobků deseti
  do 1 200. Dělení jednociferným číslem beze zbytku s podílem do 99.
- Násobení a dělení čísly 10, 100 a 1 000 i dalšími násobky deseti.
- Doplňování činitelů, dělence, dělitele a podílu. Pokyn pojmenuje hledané číslo.
- Početní řetězce se dvěma navazujícími kroky. Body se přičítají až za celý
  dokončený řetězec; chyba vrací celý řetězec k pozdějšímu opakování.

Základní kolo vyváženě střídá všech osm typů, opravy se vracejí ve frontě.
Všechny výsledky jsou nezáporná celá čísla, dělení je přesné a bez nulového
dělitele. Čísla mají oddělené tisíce; klávesnice na displeji i fyzická klávesnice
přijmou až sedm číslic. Procvičování 3. třídy si ponechává vlastní rozsahy a mix.

## 5. třída — Angličtina

Slovíčka a krátké fráze pocházejí z dodaných fotografií stran 4–21,
**Introduction** a **Unit 1: Me!**. Přepis s českými překlady, stránkami a
uznávanými variantami je v databázi; výchozí přepis je v `tool/vocabulary_grade5_seed.dart`. Obsahuje školní potřeby,
barvy, čísla, činnosti, pocity, rodinu, země a národnosti, měsíce, dny,
školní předměty, čas a slovíčka ze závěrečných stran o vlajkách a slunečních hodinách.
Opakovaná fotografie strany 16 a opakování již uvedených slov nevytvářejí duplicity.

Procvičování je na `/#/5-trida/anglictina`. Používá stejný postup níže jako
7. třída, ale vlastní slovník. Témata se míchají automaticky.

## 7. třída — Čeština

Na `/#/7-trida/cestina` je mix 28 míst k doplnění z fotografie pracovního
listu z 15. září. Každé zadání ukazuje celou větu s jednou mezerou:

1. Žák doplní `i`, `í`, `y`, `ý` nebo `a` (ve větě „Auta jela“).
2. Po správném písmenu vybere zdůvodnění: shodu s podmětem, nebo vzor,
   pád a číslo podstatného jména. Pořadí možností se při přidělení promíchá.
3. Teprve správné zdůvodnění dokončí úlohu a zobrazí celé vysvětlení.

Chyba vrátí celou úlohu k pozdějšímu opakování a přidá jednu další. Server ukládá rozpracovanou úlohu včetně
pořadí možností; návrat, obnovení stránky, další karta ani nové přihlášení
nevylosují jiné zadání. Host má rozpracovaný krok uložený v prohlížeči.
Historie češtiny počítá odpovědi v obou krocích a jednu dokončenou úlohu
až po obou správných odpovědích. Čeština nemění denní cíle matematiky a slovíček.

Migrace `spelling-v1` jednorázově přidá předmět, kurz a `server/spelling-seed.json`.
Další úlohy lze importovat do databáze; postup a formát jsou v [CONTENT.md](CONTENT.md).
Pravidla shody odpovídají [Internetové jazykové příručce ÚJČ](https://prirucka.ujc.cas.cz/?id=600),
včetně zvláštního případu „děti viděly“. Písmena i důvody ověřuje server.

## 7. třída — Angličtina

Slovíčka a fráze pocházejí z dodaných fotografií stran 4–7, **Introduction A: New
friends** a **B: The exchange students**. Ruční přepis a české překlady jsou v
`tool/vocabulary_seed.dart`; za běhu se načítají z databáze. U každé položky je téma, zdrojová stránka a případné další
uznávané odpovědi. V aplikaci lze otevřít přehled všech slovíček.

### Jak se procvičuje angličtina v obou třídách

- Kolo začíná 15 položkami napříč tématy (nebo počtem dostupných slovíček, je-li menší).
  Chyby ho prodlužují. Výběr upřednostňuje dosud nezvládnutá slovíčka.
- Kartička ukáže anglický výraz; dítě si vybaví český význam a odhalí překlad.
- Po kartičkách následuje zkoušení v náhodném pořadí: české zadání a psaná anglická
  odpověď. Lze také začít rovnou zkoušením.
- Chyba nebo **Nevím** zobrazí správnou odpověď, vrátí položku po třech dalších
  zadáních a přidá jedno slovíčko navíc. Kolo skončí po správném napsání všech
  výrazů. Výsledek ukáže dokončené úlohy a počet chyb a přidaných slovíček.
- Kontrola toleruje velká písmena, mezery, spojovníky, typografické apostrofy
  a koncovou interpunkci; běžné alternativy jsou uvedené přímo ve slovníku.
- Průběh kola se uchovává i po obnovení stránky nebo návratu na předměty.
  Dnes zvládnutá slovíčka se při výběru dalšího kola vynechají, dokud zbývají jiná.

Procvičování funguje i bez účtu. Na webu lze přes Google ukládat výsledky;
Nabídka a obsah se načítají z databáze. Procvičování hosta se
vyhodnocuje lokálně, přihlášené testy přiděluje a ověřuje server.
Při otevření aplikace je potřeba připojení k internetu.

## Obsah v databázi

Třídy (`school_grades`), předměty (`school_subjects`), jejich přiřazení
(`school_courses`) a jednotlivá zadání (`practice_items.data`, JSONB) jsou
v PostgreSQL. Web načítá aktivní nabídku přes `GET /api/catalog` bez cache.
Nová třída, předmět nebo zadání se projeví po obnovení stránky či tlačítkem
**Obnovit nabídku** na úvodu. Rozpracované cvičení používá již načtený obsah.

Podporované typy předmětů jsou `math` (číselná odpověď, případně návazné kroky),
`vocabulary` (kartičky a psaný překlad) a `spelling` (písmeno a zdůvodnění).
Přidání obsahu těchto typů nevyžaduje
novou verzi. Zcela nový způsob zkoušení vyžaduje doplnění aplikace.

První migrace `catalog-v1` vloží `server/content-seed.json` **pouze jednou**:
324 matematických zadání pro 3. třídu (včetně všech 24 z fotografií), 480 pro
5. třídu, 341 slovíček pro 5. třídu a 138 pro 7. třídu. Další start ani vydání
nepřepisuje změněný obsah. Migrace zachovává účty, přihlášení i historii výsledků.
Matematika projde náhodně všechny skupiny, v každé postupně celý zásobník;
teprve pak položky opakuje. Každá skupina tak dostane stejný prostor v mixu.

Přidávání a úpravy popisuje [CONTENT.md](CONTENT.md). Původní slovníky a
generátory v `tool/` slouží pouze k vytvoření výchozí migrace příkazem
`dart run tool/export_content.dart`; nejsou součástí nabídky běžící aplikace.

## Přihlášení a denní výsledky

### Denní úkoly

Každý účet má denní cíl **15 správně napsaných slovíček** a **15 správně
dokončených příkladů**, společný napříč třídami. Ukazatele jsou na úvodu,
ve výběru předmětů a u příslušného procvičování. Po dosažení cíle se zobrazí
**Splněno!**; procvičovat lze dál a historie uchová i výsledky nad cílem.

Chyby a prohlížení kartiček se do cíle nepočítají. Oprava chyby se započítá,
matematický řetězec až po posledním kroku. Stejné slovíčko (ID zadání) se za den
započítá jen jednou, i při novém kole či opětovném přihlášení. U starších výsledků
bez ID slovíčka se použije počet dokončených úloh zachovaný v historii.

`GET /api/daily-goals` odvozuje pokrok z uložených odpovědí přihlášeného účtu;
žádný denní úkol se nemusí ručně zakládat. Nový den začíná o půlnoci v
`Europe/Prague`, včetně změn letního času. Aplikace obnovuje pokrok po uložení,
při návratu do aplikace, každou minutu a o půlnoci. Neodeslané odpovědi se
započítají až po úspěšném uložení do svého původního dne. Host vidí cíle,
pro ukládání jejich plnění se musí přihlásit.

### Historie výsledků

Na úvodu je **Přihlásit se přes Google** a po přihlášení **Moje výsledky**.
Přehled pro každý den zvoleného měsíce odděluje třídy a předměty:

- Správné a chybné potvrzené odpovědi včetně oprav; anglické **Nevím** je chyba.
- Počet dokončených příkladů; dvoukrokový řetězec se započítá až celý.
- Počet zvládnutých slovíček v kolech. Kartičky bez zkoušení se nezapočítávají.
- Dny bez procvičování jsou také vidět. Den se určuje v `Europe/Prague`.

Údaje patří přihlášenému Google účtu (stabilní Google `sub`). Pro samostatné
výsledky každého dítěte použijte jeho vlastní účet. API ověřuje Google ID token,
nonce, původ požadavku, serverovou session a CSRF token. Session trvá 30 dní,
cookie je HttpOnly/Secure/SameSite=Lax a v databázi je jen hash session tokenu.
Ukládá se jméno, e-mail, výsledky a odeslané odpovědi včetně překladů slovíček.
Google token se neukládá. Odpovědi v nových testech vyhodnocuje server;
staré čekající výsledky zůstávají kompatibilní s původním API.

Čekající odpovědi ze starších verzí se uloží do prohlížeče pod ID účtu a při výpadku se opakují
se stejným ID bez dvojího započítání. Po opětovném přihlášení stejným účtem se
odešlou i po obnovení stránky. Jinému účtu se nepřiřadí. Čas odpovědi vychází
z hodin zařízení; nesmí být více než pět minut v budoucnosti. Smazání dat
prohlížeče smaže dosud neodeslané odpovědi. Host se zpětně k účtu nepřiřazuje.
Nativní Android/iOS verze zatím používají procvičování bez účtu.

### Nastavení Google

V [Google Cloud](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid)
vytvořte OAuth klienta typu **Webová aplikace**, s Authorized JavaScript origins
`https://aaaskola.cz`. Nastavte také publikum a obrazovku souhlasu aplikace.
V testovacím režimu přidejte zamýšlené uživatele mezi testery.
Client ID zapište do `GOOGLE_CLIENT_ID` v infrastrukturním `products/aaaskola.yml`
a vydejte stejným postupem jako aplikaci. Client ID je veřejný identifikátor;
client secret tato integrace nepotřebuje. Bez Client ID tlačítko zůstává neaktivní.

## Spuštění

Vyžaduje Flutter s Dartem 3.12.2 nebo novějším.

```powershell
flutter pub get
flutter build web --release --no-web-resources-cdn
# Pak spusťte Node server podle části Lokální kontejner níže.
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
služba `products-aaaskola_web`. Node 24 obsluhuje Flutter web i API na portu 8080;
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

Nejdříve připravte PostgreSQL 17 a prázdnou databázi vlastněnou aplikační rolí
bez superuser oprávnění. Pro Node nebo kontejner nastavte `PGHOST`, `PGPORT`,
`PGDATABASE`, `PGUSER`, `PGPASSWORD_FILE` (případně lokálně `PGPASSWORD`),
`APP_ORIGIN` a volitelně `GOOGLE_CLIENT_ID`. Hesla nepatří do Gitu.

Po `flutter build web --release --no-web-resources-cdn` spusťte v `server/`
`npm ci` a `npm start`. Server poskytuje frontend i API na portu 8080, takže
`APP_ORIGIN=http://localhost:8080` umožní lokální vývoj bez cross-origin požadavků.
Testy serveru (`npm test`) vyžadují vlastní databázi s názvem končícím `_test`;
její tabulky mažou. CI ji vytváří izolovaně. `GET /healthz` ověřuje i DB spojení.

Produkční PostgreSQL nemá veřejný port. Hesla jsou Docker secrets, aplikační
role není superuser. Data `aaaskola_postgres_data` a zálohy `aaaskola_postgres_backups`
leží na jediném uzlu označeném `aaaskola.data=true`; označení se nesmí přesunout
bez přenosu dat. Záloha `pg_dump` vzniká každých 24 hodin, uchovává se 30 dní.
Oba svazky jsou lokální: zálohy chrání před logickou chybou, pro ztrátu celého
uzlu je nutná samostatná kopie mimo uzel. Podrobnosti obnovy jsou v deploy návodu.
