# Správa tříd, předmětů a zadání

Obsah se upravuje v PostgreSQL. Pro kontrolu formátu a transakční zápis používej
JSON import: chyba vrátí celou dávku zpět, existující ID aktualizuje položku,
vynechané položky ponechá. Import nenasazuje ani nerestartuje web.

## Import z Windows

Ze workspace `stafio-app` s přihlášeným GitHub CLI:

```powershell
scripts\aaaskola\import-content.cmd -ContentPath C:\cesta\obsah.json -Check
scripts\aaaskola\import-content.cmd -ContentPath C:\cesta\obsah.json
```

`-Check` provede validaci proti skutečné databázi a transakci vrátí zpět.
`-WhatIf` pouze lokálně ověří JSON a zobrazí plán. Skript používá existující
`maintenance.yml`, současnou image aplikace a dočasnou službu s Docker secret.
Službu a její konfiguraci po importu odstraní. Dávka má nejvýše 16 KB;
větší soubor rozděl na více samostatných JSON dokumentů. Do souborů patří pouze
veřejný učební obsah, nikoliv hesla nebo osobní údaje.

Po úspěchu obnov nabídku na [aaaskola.cz](https://aaaskola.cz/).
Stav a přesná zadání vrací [API nabídky](https://aaaskola.cz/api/catalog).

## Přidání matematického příkladu

Soubor `obsah.json`:

```json
{
  "courses": [{
    "grade": 3,
    "subject": "math",
    "items": [{
      "id": "3-math-notebook-80-plus-17",
      "data": {
        "group": "additionSubtraction",
        "heading": "SČÍTÁNÍ A ODČÍTÁNÍ",
        "beforeAnswer": "80 + 17 =",
        "afterAnswer": "",
        "answer": 97,
        "instruction": "Napiš výsledek a potvrď ho."
      }
    }]
  }]
}
```

Výsledek se zadává do mezery mezi `beforeAnswer` a `afterAnswer`. Například
`beforeAnswer: "7 ×"`, `afterAnswer: "= 21"`, `answer: 3` procvičuje doplňování.
`answer` musí být nezáporné celé číslo, které se vejde do `maxDigits` kurzu
(1–7 číslic). Správnost výpočtu musí ověřit autor obsahu; import kontroluje formát.
`group` zařazuje příklad do společného mixu; stejná skupina dostává stejný prostor
bez ohledu na počet uložených příkladů. `heading` je její zobrazený název.
Volitelná `verification` se ukáže po správné odpovědi.

Vícekrokový řetězec používá `nextStep` obsahující další objekt stejného formátu,
maximálně 10 kroků. Dokončení se započítá až po posledním kroku.

## Nová třída a předmět se slovíčky

```json
{
  "grades": [{"id": 4, "name": "4. třída", "sortOrder": 6}],
  "subjects": [{
    "id": "german", "slug": "nemcina", "name": "Němčina",
    "kind": "vocabulary", "answerLanguage": "německy"
  }],
  "courses": [{
    "grade": 4, "subject": "german", "description": "Slovíčka o domově",
    "sourceTitle": "Vlastní slovíčka", "sortOrder": 1,
    "items": [{
      "id": "4-german-house",
      "data": {
        "english": "Haus", "czech": "dům", "topic": "Domov", "page": 1,
        "alternatives": ["das Haus"]
      }
    }]
  }]
}
```

Pole `english` je historický název pro výraz v cílovém jazyce; může obsahovat
jiný jazyk. `answerLanguage` tvoří pokyn „Napiš německy“. `alternatives` jsou další
uznávané odpovědi. `page` označuje stránku zdroje; pro vlastní obsah může být 0.
Adresa kurzu se sestaví jako `/#/4-trida/nemcina`.

## Úpravy a skrytí

- ID zadání je jedinečné v celé databázi. Stejné ID aktualizuje zadání; nelze ho
  přesunout k jinému kurzu. Nové ID přidá další položku.
- Pro doplnění do existujícího kurzu stačí `grade`, `subject`, `items`.
  Vynechaná metadata kurzu se zachovají; uvedená se aktualizují.
- Třídy a předměty se aktualizují podle ID; při jejich importu uveď celou definici.
  Typ existujícího předmětu nelze změnit. Nižší `sortOrder` se zobrazuje výše.
- `active: false` u třídy, předmětu, kurzu nebo položky ji skryje z nabídky.
  Při úpravě položky posílej i celé `data`. Obnovení provede `active: true`.
- Neodstraňuj kurzy s výsledky. Skrytí zachová historii i dodatečné odeslání
  rozpracovaných odpovědí; přehled ukazuje také archivované kurzy.
- Importovaný soubor není úplnou náhradou databáze. Neuvedený obsah se nemaže.
  Před hromadnou opravou zachovej původní data nebo vytvoř zálohu.

## Lokální import a přímé SQL

V adresáři `server/` se správnými `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`
a `PGPASSWORD_FILE` lze spustit `node import-content.js --check < obsah.json`
a poté `node import-content.js < obsah.json` (shell Bash/CMD).
Heslo nepatří do zdrojů ani do obsahu. Import používá aplikační roli bez superuser práv.

Přímé SQL změny tabulek jsou také ihned viditelné přes API, ale obcházejí validaci
struktury zadání. Schéma je v `server/catalog.sql`; formát JSON musí odpovídat
výše uvedeným příkladům. Výchozí `server/content-seed.json` neupravuj jako způsob
změny již běžící databáze: migrace se podruhé nespouští.
