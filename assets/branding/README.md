# AAA škola – název, ikona a logo

Zobrazovaný název značky je **AAA škola**. Doména a technický identifikátor
zůstávají `aaaskola.cz` a `aaaskola`.

Ikona zobrazuje budovu školy s hodinami a výrazným nápisem **AAA**, otevřenou
učebnici **ABC / 123** a menší usměvavou zlatou hvězdičku. Wordmark používá kulaté písmo Nunito;
tři A mají tmavě zelenou, světlejší zelenou a zlatou barvu, slovo „škola“ je tmavé.
Písmo se dodává lokálně spolu s aplikací a licencí SIL OFL v `assets/fonts/OFL.txt`.
Zdroj písma: https://github.com/google/fonts/tree/main/ofl/nunito.

## Soubory

- `aaaskola-icon-v3-source.png`: upravený originál z imagegen.
- `aaaskola-icon-v3.png`: aktuální ikona 1024 × 1024 px.
- `aaaskola-icon-v3-128.png`: aktuální ikona v záhlaví aplikace.
- `aaaskola-icon-v3-preview.png`: náhled 256 × 256 px.
- `aaaskola-icon-v3-prompt.txt`: přesný editační prompt pro verzi 3.
- `aaaskola-wordmark.svg` a `.png`: samostatný stylizovaný nápis.
- `aaaskola-logo.svg` a `.png`: kompletní logo s ikonou a nápisem.
- SVG obsahují písmo převedené na křivky; kompletní logo má obrázek vložený přímo uvnitř.
- Původní ikony včetně verze 2 zůstávají zachované.
- Platformní velikosti jsou vyexportované do `android/app/src/main/res/`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/` a `web/`.

## Vytvoření

Použit vestavěný nástroj `image_gen`, nikoli API/CLI. Platformní kopie vznikly pouze změnou rozměrů, bez dalších výtvarných úprav.

### Školní motiv (verze 3)

Editační předloha: `aaaskola-icon-v2.png`. Nová verze staví do popředí školní
budovu a učebnici: písmena připomínají jazyky, čísla počítání. Hvězdička zůstává
menším maskotem. [Přesný prompt](aaaskola-icon-v3-prompt.txt).

### Původní generační prompt před přejmenováním aplikace

Use case: logo-brand. Asset type: production mobile app launcher icon for a Czech children's learning app called Umík, covering mathematics and English/German vocabulary. Generate ONE square 1024x1024 icon asset, no mockup. Design a memorable friendly little golden-yellow rounded four-point star mascot with two dark simple dot eyes and a tiny warm smile, rising just above a very simple open ivory book. The star should be the clear main subject, with the open book as one bold compact supporting shape at its lower edge. Contemporary polished flat vector-like illustration, very clean rounded geometry, few large shapes, crisp edges, minimal subtle shading only, friendly to primary-school children yet refined. Palette: solid deep forest green #226552 edge-to-edge background, golden yellow #F5C857 star, warm ivory #FFF9E9 book, very restrained pale mint page accent, dark green eyes. Balanced centered composition; the complete mascot and book fit comfortably inside the central 65 percent of the square so circular launcher masks will not clip anything. The solid green background must reach all four corners; no rounded outer rectangle baked into the image, no border, no transparent margins, no perspective. No text at all, no letters, no numerals, no mathematical symbols, no flags, no watermark, no additional decorative stars, no owl. Readable and recognizable at 32 pixels. Render only the final icon.


### Prompt pro upravenou ikonu AAA (verze 2)

Vestavěný imagegen; editační předloha: `aaaskola-icon.png`.

Use case: precise-object-edit / logo-brand refinement. Input image 1 is the EDIT TARGET: the existing approved mobile app icon. Refine this exact icon for the Czech learning brand AAA škola. Preserve the same recognizable smiling golden star mascot, its friendly dark-green eyes and smile, the simple ivory open book, the forest-green edge-to-edge square background and the warm clean illustration style. Main change: integrate exactly THREE large, bold, rounded uppercase letters "AAA" into the open book's front-facing ivory pages, clearly readable as one compact word across the book. This must feel like a deliberate brand monogram printed on the book, not a small caption or an extra floating badge. Use solid dark forest green for all three A letters for strong contrast. Make the page faces just slightly taller and simplify page layers if needed to give the AAA lettering a calm clean space; move or reduce the star only slightly if needed. The face remains prominent and fully unobstructed. Exact text in the icon: "AAA", three identical uppercase Latin A characters, no other text. The A letters should each have a clearly visible counter and crossbar. This is an app icon, not a presentation board: render only ONE complete square production icon, no phone mockup, no wordmark alongside, no border, no baked rounded outer corners, no extra symbols or characters. All important artwork stays within a safe circle covering the central 80 percent of the image, with generous green margin for platform cropping. Strong, simple, clean forms that remain readable at small sizes; gently reduce excessive gloss or texture. Color family: green #226552, golden yellow #F5C857, ivory #FFF9E9. Keep the identity recognizable while making its association with AAA unmistakable.
