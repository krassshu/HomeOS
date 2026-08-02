# Harness E1 — kontrakt API Paperless-ngx

Odtwarzalne skrypty eksperymentu E1. Zastępują jednorazowe skrypty sesyjne, które
powstawały w ignorowanym katalogu `raw/` i nie były trwałym artefaktem.

Skrypty są narzędziem laboratoryjnym, nie kodem produktu. Nie należą do
`PaperlessAdapter` ani do żadnego modułu Core.

## 1. Wymagania

Na hoście uruchamiającym skrypty:

- `bash` 4+, `docker` z wtyczką `compose`, `curl`, `python3`, `sha256sum`, `cmp`,
- dostęp do gniazda Dockera dla projektu Compose laboratorium,
- działające laboratorium M3 w wariancie `source/shared`,
- Paperless osiągalny pod `http://127.0.0.1:8000` (port przypięty do loopbacku).

Generator fixture wymaga dodatkowo Pillow, fpdf2, img2pdf i poppler — te
biblioteki są obecne w obrazie Paperless, dlatego `gen-fixtures.sh` uruchamia
generator **wewnątrz kontenera**, a nie na hoście.

## 2. Bezpieczne przekazanie tokenu

Token nigdy nie trafia do argumentów polecenia, logów ani plików wyników.
Skrypty budują plik konfiguracyjny `curl` o uprawnieniach `0600` i czytają go
przez `curl -K`, więc token nie pojawia się w `ps`.

Źródła tokenu w kolejności sprawdzania:

| Sposób | Ustawienie |
|---|---|
| zmienna środowiskowa | `PAPERLESS_API_TOKEN=...` |
| chroniony plik | `PAPERLESS_TOKEN_FILE=/ścieżka/do/pliku` — musi mieć `0600` i zawierać sam token |
| instancja laboratoryjna | `M3_ALLOW_CONTAINER_TOKEN=1` — jednorazowy odczyt z uruchomionego kontenera |

Trzeci wariant jest wygodą laboratorium i wymaga jawnego włączenia. Plik
konfiguracyjny `curl` jest usuwany przez `shred` w trapie `EXIT`, również po błędzie.

Nie zapisuj tokenu w repozytorium ani w plikach `*.example`.

## 3. Wariant laboratorium

Domyślnie skrypty pracują na wariancie `source/shared`, czyli dokładnie na
zestawie Compose:

```text
compose.baseline.yaml + compose.override.yaml + compose.source.yaml + compose.valkey-shared.yaml
--env-file .env.source
```

Sterowanie zmiennymi środowiskowymi:

| Zmienna | Domyślnie | Znaczenie |
|---|---|---|
| `M3_PROJECT` | `homeos-m3-source` | projekt Compose |
| `M3_TARGET` | `source` | `source` albo `restore` |
| `M3_VALKEY` | `shared` | `shared` albo `split` |
| `M3_WEBSERVER` | `${M3_PROJECT}-webserver-1` | kontener webservera |
| `M3_API` | `http://127.0.0.1:8000/api` | bazowy adres API |
| `M3_API_VERSION` | `10` | wersja nagłówka `Accept` |
| `M3_RAW_DIR` | `./raw` | katalog wyników surowych |
| `M3_PROTECTED_DOCS` | `1 2 3 4 5 6 7 8 9` | dokumenty, których nie wolno usuwać |
| `M3_EXPECT_PROJECT` | `homeos-m3-source` | próg bezpieczeństwa dla `M3_PROJECT` |

Każdy skrypt odmawia pracy, jeżeli `M3_PROJECT` różni się od `M3_EXPECT_PROJECT`
albo jeżeli wskazany kontener należy do innego projektu Compose. Zmiana celu
wymaga świadomego ustawienia obu zmiennych.

## 4. Skrypty

| Plik | Rola |
|---|---|
| `common.sh` | wspólne helpery: token, wywołania API, odpytywanie zadań, straż projektu i dokumentów chronionych, złożenie polecenia Compose |
| `gen-fixtures.py` | generator wyłącznie syntetycznych fixture; uruchamiany w kontenerze |
| `gen-fixtures.sh` | wrapper: generuje fixture w kontenerze i kopiuje je na host; domyślnie odmawia nadpisania |
| `api-checks.sh` | kontrole kontraktu API: status, wersja, OpenAPI, upload, zadanie, dokument, pobrania, wyszukiwanie, filtr po sumie kontrolnej |
| `preflight.sh` (katalog wyżej) | audyt i preflight M3: host, kontenery, digesty, porty, liczniki, sanity, wersje narzędzi, cztery warianty `docker compose config` |
| `duplicate-test.sh` | zachowanie przy ponownym przesłaniu tego samego pliku, w obu wariantach `CONSUMER_DELETE_DUPLICATES` |
| `validate-results.sh` | walidacja wyników: poprawność JSON, stany końcowe zadań, skan sekretów w artefaktach tekstowych, spójność pliku pomiarów |

Wspólne kody wyjścia:

| Kod | Znaczenie |
|---|---|
| `0` | wszystko przeszło |
| `1` | błąd wykonania |
| `2` | błąd użycia |
| `3` | niespełniony warunek wstępny |
| `4` | kontrola nie przeszła |
| `5` | odmowa: nieoczekiwany projekt albo dokument chroniony |

Każdy skrypt ma `--help`.

### Powtarzalność fixture

Sprawdzone przez dwa niezależne przebiegi generatora:

| Fixture | Powtarzalność |
|---|---|
| `DOC-09A.pdf`, `DOC-09B.pdf` | bajtowa — `24 232 B`, `20e91ad2…` |
| `DOC-10-zażółć-gęślą-jaźń.pdf` | bajtowa — `23 981 B`, `89f36121…` |
| `DOC-DEL-01.pdf` | bajtowa — `23 507 B`, `d793a4a0…` |
| `DOC-08.pdf` | bajtowa — `13 354 B`, powstaje z kopii `DOC-09A` |
| `DOC-06.pdf` | **tylko rozmiar i układ** — `837 164 B`, `4` strony |

`DOC-06` nie jest powtarzalny bajtowo, ponieważ `img2pdf` osadza datę utworzenia
i losowy identyfikator dokumentu. Porównuj go po rozmiarze i liczbie stron, nie
po sumie SHA-256. Pozostałe pliki mają stałą datę utworzenia ustawioną w kodzie,
dlatego ich sumy zgadzają się z manifestem.

## 5. Miejsca zapisu wyników

Wyniki surowe trafiają do katalogu `M3_RAW_DIR` (domyślnie `./raw`), tworzonego
idempotentnie z uprawnieniami `0700`. Katalog wyników i fixture binarne
**nie należą do Git**:

- surowe odpowiedzi API i nagłówki — poza repozytorium,
- wygenerowane pliki PDF, PNG, DOCX i XLSX — poza repozytorium,
- do dokumentacji trafiają wyłącznie zanonimizowane pomiary i obserwacje.

Pełny traceback z `result_data` może pozostać wyłącznie w wynikach surowych.
Skrypty skracają go w podsumowaniach, ponieważ ujawnia wewnętrzne ścieżki źródeł.

## 6. Które testy powodują kontrolowany restart

| Polecenie | Restart |
|---|---|
| `api-checks.sh` (dowolne podpolecenie) | brak |
| `validate-results.sh` | brak |
| `gen-fixtures.sh` | brak |
| `duplicate-test.sh --mode current` | brak |
| `duplicate-test.sh --mode keep` | **odtwarza kontener `webserver`** |
| `duplicate-test.sh --mode reject` | **odtwarza kontener `webserver`** |

Restart dotyczy wyłącznie usługi `webserver`, przez
`up -d --no-deps --force-recreate webserver`. Zwykły `restart` nie wystarcza,
ponieważ zmiana środowiska wymaga odtworzenia kontenera.

Baza danych, Valkey, Tika, Gotenberg i `core_fixture_db` nie są odtwarzane.
Żaden skrypt nie wykonuje `down`, `down -v`, `reset` ani operacji na wolumenach.

Zmierzony czas niedostępności webservera przy odtworzeniu wynosił około `40 s`
do pierwszej odpowiedzi `200` i około `37 s` do stanu `healthy`.

## 7. Procedura rollbacku

Tryby `keep` i `reject` skryptu `duplicate-test.sh`:

1. wykonują prywatną kopię pliku środowiska poza Git, z uprawnieniami `0600`,
2. podmieniają wartość istniejącego klucza, nie dodając drugiego wystąpienia,
3. odtwarzają wyłącznie `webserver` i czekają na `healthy` maksymalnie
   `--timeout` sekund (domyślnie `180`),
4. **w trapie `EXIT`** przywracają pierwotny plik, ponownie odtwarzają
   `webserver`, czekają na `healthy` i wypisują obraz, `RestartCount`, health
   oraz przypisanie portu.

Rollback wykonuje się także po błędzie testu i po przerwaniu, i ma pierwszeństwo
przed zbieraniem wyników. Prywatna kopia środowiska jest na końcu usuwana przez
`shred`. Jeżeli rollback nie doprowadzi kontenera do stanu `healthy`, skrypt
wypisuje `WYMAGANA INTERWENCJA RĘCZNA` — wtedy trzeba sprawdzić plik środowiska
i stan usługi ręcznie, zanim uruchomi się cokolwiek innego.

Uruchamiając wariant restartujący przez SSH, warto odłączyć proces od sesji
(`setsid nohup ... &`), żeby zerwanie połączenia nie przerwało skryptu przed
rollbackiem.

## 8. Które testy nadal wymagają fizycznych fixture

Generator tworzy wyłącznie materiał syntetyczny. Część wymagań E1 nie może być
nim zamknięta i pozostaje otwarta:

| Wymaganie | Stan |
|---|---|
| `DOC-02` — jednostronicowy skan rzeczywistej kartki | otwarte; obecny materiał powstał przez przechwycenie tekstu z ekranu |
| `DOC-06` — wielostronicowy skan rzeczywistego dokumentu | otwarte; obecny materiał powstał przez rasteryzację tekstu |
| `DOC-03` — zdjęcie z rzeczywistego aparatu telefonu | częściowo; sprawdzony PNG był przygotowany w laboratorium |

Próby oparte na tych fixture sprawdzają pipeline techniczny, ale nie zamykają
wymagania reprezentatywności. Szczegóły w `Docs/operations/spike-results/01-test-document-manifest.md`.

## 9. Zakres artefaktu

Ten katalog pokrywa **wyłącznie E1**. Artefakt nr 4 nie jest ukończony:
skrypty **E3A** (eksport i import) oraz **E3B** (restore do czystego środowiska)
pozostają osobnymi, jeszcze nieprzygotowanymi częściami. Nie oznaczaj artefaktu
nr 4 jako zamkniętego, dopóki obie części nie powstaną.

Harness E2 (BullMQ i PoC ORM) jest niezależny i mieszka w `lab/harness/` oraz `lab/e2/`.

## 10. Przykłady

```sh
cd lab/harness/e1
export M3_ALLOW_CONTAINER_TOKEN=1
export M3_RAW_DIR=../../../lab-data/e1-raw

# Kontrole tylko do odczytu
./api-checks.sh status
./api-checks.sh version
./api-checks.sh document --id 7
./api-checks.sh search --query "SYGNATURA DUPLIKATU ALFA BRAVO 2026"
./api-checks.sh checksum --sha256 20e91ad2...

# Generowanie syntetycznych fixture
./gen-fixtures.sh --out ../../../lab-data/fixtures --only text,duplicate

# Duplikat bez zmiany konfiguracji
./duplicate-test.sh --file ../../../lab-data/fixtures/DOC-09A.pdf --mode current

# Wariant odrzucania: kontrolowany restart webservera i automatyczny rollback
./duplicate-test.sh \
  --file ../../../lab-data/fixtures/DOC-09A.pdf \
  --mode reject --expect-doc 7 --title "E1-11d próba duplikatu"

# Walidacja wyników i pliku pomiarów
./validate-results.sh --csv ../../../Docs/operations/spike-results/02-resource-measurements.csv
```

`api-checks.sh upload` i `api-checks.sh all` tworzą trwały rekord dokumentu,
jeżeli Paperless przyjmie plik. `duplicate-test.sh --mode keep` również może
utworzyć kolejny rekord. Pozostałe przykłady powyżej niczego nie zapisują w API.

Generator nie nadpisuje istniejących fixture. Świadome zastąpienie plików o tych
samych nazwach wymaga opcji `--overwrite`. Odmowa działa w obu warstwach:
`gen-fixtures.sh` sprawdza katalog docelowy na hoście, a `gen-fixtures.py`
odmawia pracy w niepustym katalogu wyjściowym (kod wyjścia `5`), więc również
bezpośrednie uruchomienie generatora w kontenerze nie skasuje istniejących
plików.

### Endpointy binarne i negocjacja `Accept`

`api-checks.sh download` wykonuje dla `/download/`, `/preview/` i `/thumb/` po
dwie próby. Najpierw wariant docelowy — odpowiednio `application/pdf; version=10`
i `image/webp; version=10` — który w 3.0.4 zwraca `406`, a potem sprawdzony
fallback `Accept: application/json; version=10`, który zwraca `200` z właściwym
`Content-Type`. Obie odpowiedzi trafiają do wyników surowych, a kontrola
przechodzi wtedy, gdy zawartość jest osiągalna którymkolwiek wariantem i ma
oczekiwany typ. Żaden z tych endpointów nie ogłasza swojego typu wyjściowego
jako akceptowanego. Pomiary są w
`Docs/operations/spike-results/03-api-notes.md`.
