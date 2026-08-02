# Manifest dokumentów testowych M3

**Status:** `in progress` · **Eksperyment:** E1 · **Polityka danych:** `../spike-data-policy.md`

Manifest używa wyłącznie pseudonimów. Pliki binarne, ich oryginalne nazwy oraz dane osób pozostają poza Git.

| ID | Typ | Pochodzenie | Cecha testowana | SHA-256 wejścia | Status |
|---|---|---|---|---|---|
| `DOC-01` | jednostronicowy PDF z warstwą tekstową | syntetyczny, przygotowany na potrzeby laboratorium | upload bez wymaganego OCR, task status, podstawowe endpointy dokumentu | `d7545fdcc3d14e3bcdd54f7072d9f12f1ea5972e846b2ecc6a5281421a9e808c` | PASS; dokument ID `1`, task `success`, oryginał zgodny bajtowo, preview fallback i thumbnail poprawne, dokładna fraza wyszukiwania odnaleziona |
| `DOC-02` | obrazowy PDF, jedna strona A4 | syntetyczny tekst sfotografowany/zeskanowany z ekranu tabletu | wstępna kontrola polskiego OCR; nie zastępuje końcowej próby z papieru | `b491f7f0c0b9da803bd74b5b6537d3f13305f9093abb96d931b39653e392940c` | próba wstępna PASS; 3 506 235 B, brak tekstu przed OCR, pełna fraza rozpoznana |
| `DOC-03` | PNG 768×1024 RGB | fotografia niespersonalizowanego, wielojęzycznego opakowania; bezstratnie oczyszczona z EXIF | upload mobilny, OCR ze zdjęcia | `283603782d45d1ccec1ebec685479ccd9708f9288d15854ee4729e478b8774ca` | PASS techniczny; 1 040 729 B; brak EXIF/GPS; metadata błędnie podała `lang=de` |
| `DOC-04` | DOCX / Microsoft Word OpenXML | syntetyczny dokument z tekstem, polskimi znakami i tabelą | konwersja przez Tika/Gotenberg, tekst i układ PDF | `8a10e011435529b332fbea84ffd5b2214add64da7f629de2a5cc18324e7d880f` | PASS; Tika i Gotenberg potwierdzone logami, tekst/search poprawne, układ i tabela zweryfikowane wizualnie |
| `DOC-05` | XLSX / Microsoft Excel OpenXML | syntetyczny, wygenerowany bez udziału Numbers | konwersja przez Gotenberg, układ tabeli, sześć rzeczywistych formuł i polskie znaki | `37f0c681d7e6083c03b034b24e981df95887f9d82a279ccd6498fb037183dfc0` | PASS; Tika/Gotenberg potwierdzone logami, suma `148,49 PLN`, tekst i polskie znaki zachowane, archive/preview/thumbnail poprawne, układ potwierdzony wizualnie |
| `DOC-06` | czterostronicowy PDF wyłącznie rastrowy, A4 200 dpi | syntetyczny; tekst wyrenderowany do rastra w laboratorium, **nie jest skanem papieru** | wydajność OCR wielostronicowego i archive PDF | `9fa4780194f8a21565493fc189148dec5e798e3fb7e4d27537d756e785ac2159` | próba wstępna PASS; 837 164 B, 0 znaków tekstu przed OCR, archive 4/4 strony; jedna fraza kontrolna niewyszukiwalna przez sklejenie wyrazów przez OCR |
| `DOC-07` | duży plik | brak | streaming, timeout i zużycie RAM | — | BLOCKED: dokumentacja nie ustala progu „dużego pliku”; decyzja G4-03 należy do M8 |
| `DOC-08` | uszkodzony PDF | kopia syntetycznego `DOC-09A` z obciętym strumieniem i zniszczoną tablicą xref | trwały błąd wejścia | `4e3cb6f2956440f890bf826af3eca7e757d401edec65f04adb3f867f2b8de9fc` | PASS; task `failure`, żaden rekord dokumentu nie powstał |
| `DOC-09A` | jednostronicowy PDF z warstwą tekstową | syntetyczny, wygenerowany w laboratorium | dokument bazowy rodziny duplikatu | `20e91ad20f20a817407b67a485fe161bcfb4f0c8bf3b4e23bbafde4dc4ef292d` | PASS; dokument ID `7` |
| `DOC-09B` | kopia binarnie identyczna z `DOC-09A` | `cp` z `DOC-09A` | duplikat binarny | `20e91ad20f20a817407b67a485fe161bcfb4f0c8bf3b4e23bbafde4dc4ef292d` | PASS; przy `PAPERLESS_CONSUMER_DELETE_DUPLICATES=false` powstał drugi rekord ID `8`; przy `true` (`DOC-09B-REJECT-TRUE`, ta sama suma) rekord nie powstał, a task wskazał `duplicate_of: 7` |
| `DOC-09C` | ponowny skan treści `DOC-09A` | brak | duplikat logiczny przy innych bajtach | — | BLOCKED: brak rzeczywistego ponownego skanu |
| `DOC-10` | jednostronicowy PDF z warstwą tekstową; polskie znaki w nazwie, tytule i treści | syntetyczny, wygenerowany w laboratorium | kodowanie i wyszukiwanie | `89f36121a6383ea49d89fc3e459a0f6511f5b473bcf6182e70e6cb25d110cc96` | PASS; dokument ID `9` |
| `DOC-DEL-01` | jednostronicowy PDF z warstwą tekstową | syntetyczny, wygenerowany w laboratorium wyłącznie do próby delete | operacja delete przez API | `d793a4a0e8ab7b3717166aa1df7678ab3d0f5fc7bd4fda2af831d7c24060b4cd` | PASS; dokument ID `10` utworzony i usunięty przez API |

`DOC-06`, `DOC-08`, `DOC-09A`, `DOC-09B`, `DOC-10` i `DOC-DEL-01` powstały 2026-07-30 skryptem laboratoryjnym z użyciem bibliotek dostępnych w obrazie `3.0.4`. Materiał jest w całości syntetyczny i nie zawiera danych osobowych. Żaden istniejący fixture nie został zmodyfikowany; `DOC-08` jest kopią `DOC-09A`, a nie `DOC-01`.

Generator został przeniesiony do trwałego artefaktu `lab/harness/e1/gen-fixtures.py`. Dwa niezależne przebiegi potwierdziły, że `DOC-08`, `DOC-09A`, `DOC-09B`, `DOC-10` i `DOC-DEL-01` odtwarzają się **bajtowo identycznie** z sumami zapisanymi w tym manifeście. `DOC-06` odtwarza się z tym samym rozmiarem `837 164 B`, układem i liczbą stron, ale **nie bajtowo** — `img2pdf` osadza datę utworzenia i losowy identyfikator dokumentu, więc jego SHA-256 zmienia się między przebiegami. Porównuj `DOC-06` po rozmiarze i liczbie stron.

## Kontrola przed zakończeniem E1

- [x] Wszystkie pliki mają zapisany SHA-256 przed uploadem.
- [ ] Końcowa próba `DOC-02`, `DOC-03` i `DOC-06` zachowuje reprezentatywne artefakty rzeczywistej kartki lub zdjęcia; bieżący `DOC-02` z ekranu tabletu oraz rastrowy `DOC-06` są tylko próbami wstępnymi.
- [x] `DOC-09A` i `DOC-09B` mają identyczny SHA-256.
- [ ] `DOC-09C` ma inny SHA-256, ale przedstawia tę samą treść co `DOC-09A`.
- [x] Manifest nie zawiera nazw osób, nazw plików źródłowych ani treści dokumentów.
