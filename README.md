# AAA škola

Samostatná Flutter aplikace pro hravé procvičování počítání a cizích jazyků.
Ikonu tvoří usměvavá zlatá hvězdička nad otevřenou knihou s písmeny AAA
na zeleném pozadí. Název se zobrazuje jako **AAA škola** v kulatém písmu
Nunito se třemi barevnými A.

Cílová doména aplikace: [aaaskola.cz](https://aaaskola.cz/).

První verze procvičuje násobení čísel 1–9. Anglická a německá slovíčka
jsou plánovaným rozšířením.

- Náhodný příklad, velká klávesnice na displeji a kontrola odpovědi.
- Po chybě zůstane stejný příklad; první nová číslice nahradí chybnou odpověď.
- Po správné odpovědi se zobrazí pochvala a tlačítko **Další příklad**.
- Počítadlo vyřešených příkladů platí pro aktuální spuštění.
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
