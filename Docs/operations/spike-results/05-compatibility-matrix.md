# Macierz kompatybilności Paperless-ngx 3.0.4

**Status:** `in progress` · **Eksperyment:** E1/E3 · **API:** v10 · **Ostatnia aktualizacja:** 2026-07-31

**Obraz:** `ghcr.io/paperless-ngx/paperless-ngx:3.0.4@sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582`

Wyniki dotyczą wyłącznie uruchomionego baseline'u 3.0.4. Nie dziedziczą odpowiedzi, pól ani zachowania z serii 2.x.

| Obszar | Próba | Wynik | Obserwacja 3.0.4 / API v10 |
|---|---|---|---|
| Uwierzytelnienie | token API na `/api/documents/` | PASS | `200`, `X-Api-Version: 10`, `X-Version: 3.0.4` |
| OpenAPI | surowy `/api/schema/` | PASS | OpenAPI 3.0.3, 92 ścieżki, checksum zapisana w `03-api-notes.md` |
| `ingest` | upload tekstowego PDF przez `/api/documents/post_document/` | PASS | `200`, zwrócony UUID zadania |
| task status | `/api/tasks/?task_id={uuid}` | PASS z uwagą | `status=success`; pola v10 to `related_document_ids` i `result_data`; dokument potwierdzony osobnym wyszukaniem |
| metadata | detail dokumentu i `/metadata/` dla tekstowego PDF | PASS | tekst wyodrębniony; charakterystyczna polska fraza obecna; pola metadata v10 zapisane w `03-api-notes.md` |
| original | `/download/?original=true` i porównanie bajtowe | PASS | `200`, PDF, attachment; rozmiar i SHA-256 zgodne z wejściem |
| preview/archive PDF | `/preview/` bez i z archive version | PASS | bez archive: oryginał jako fallback; po OCR: archive PDF; oba `inline` i zgodne checksumy |
| thumbnail | `/thumb/` dla tekstowego PDF i skanu OCR | PASS | oba `200`; osobne WebP 500×707 |
| search tekstu dokumentu | dokładne frazy tekstowego PDF i OCR oraz osobne literówki | PASS z ograniczeniem | dokładne frazy: po 1 wyniku; literówki: 0; fallback literówek pozostaje po stronie Core |
| klasyfikacja | create oraz PATCH tag/correspondent/document type | PASS | trzy POST `201`; PATCH `200`; przypisania zachowane po niezależnym GET dokumentu |
| delete | `DELETE` osobnego dokumentu jednorazowego `DOC-DEL-01` | PASS z uwagą | `204 No Content`, puste ciało; ponowny GET `404`; licznik dokumentów `-1`; usunięty rekord trafia do `/api/trash/` — to soft delete, nie natychmiastowe usunięcie plików |
| health/fallback health | uwierzytelniony `/api/status/` z timeoutem | PASS | `200`; wersja 3.0.4 oraz DB, Valkey, Celery, indeks i klasyfikator `OK`; bez tokenu `401` |
| konfiguracja | częściowo | PASS z obejściem | jawne `PAPERLESS_SEARCH_LANGUAGE` powoduje `AppRegistryNotReady`; baseline go nie ustawia |
| OCR polski | obrazowy PDF bez warstwy tekstowej, `lang=pl` | PASS wstępny | pełna fraza i 6/6 słów rozpoznane; archive PDF ma zgodną checksumę i warstwę tekstową; próba z ekranu nie zamyka wymaganej próby z papieru |
| mobilny PNG | fotografia 768×1024 bez EXIF/GPS | PASS z ograniczeniem | OCR, archive PDF i search polskiej frazy działają; metadata błędnie zwróciła `lang=de` dla treści EN/FR/PL |
| DOCX / Gotenberg | DOCX z tekstem, polskimi znakami i tabelą | PASS | Tika/Gotenberg `200`; tekst i checksumy poprawne; układ, polskie znaki i tabela potwierdzone wizualnie |
| XLSX / Gotenberg | XLSX z sześcioma formułami, tabelą i polskimi znakami | PASS | Tika/Gotenberg `200`; oryginał zgodny bajtowo, archive i preview zgodne, wynik `148,49 PLN` oraz tekst tabeli zachowane; układ potwierdzony wizualnie; `/thumb/` wymaga sprawdzonego wersjonowanego `Accept` |
| wielostronicowy OCR | czterostronicowy PDF rastrowy 200 dpi bez warstwy tekstowej | PASS wstępny | task `success`, `page_count=4`, archive 4/4 strony, preview = archive, thumbnail WebP 500×707; oryginał zgodny bajtowo; materiał rastrowy nie zamyka wymogu rzeczywistego skanu |
| segmentacja OCR a search | dokładne frazy z pierwszej i ostatniej strony `DOC-06` | PASS z ograniczeniem | ostatnia strona i inne frazy pierwszej strony odnalezione; jedna fraza pierwszej strony `0` wyników, bo OCR skleił dwa wyrazy — dokładne zapytanie frazowe jest wrażliwe na błąd segmentacji |
| uszkodzony PDF | obcięty strumień i zniszczony xref, kopia syntetycznego PDF | PASS | upload `200`, task `failure`, `related_document_ids: []`, żaden rekord nie powstał; worker `healthy`, `RestartCount=0`, kolejny request `200` |
| treść błędu taska | `result_data` przy `status=failure` | PASS z ograniczeniem | `error_type`, `error_message` i `traceback`; `error_message` ma pusty człon przyczyny (`InputFileError:`), a `traceback` ujawnia wewnętrzne ścieżki źródeł — wymaga filtrowania przed przekazaniem klientowi |
| duplikaty binarne | `DOC-09A` i binarnie identyczny `DOC-09B` przy `PAPERLESS_CONSUMER_DELETE_DUPLICATES=false` | PASS techniczny z istotnym ograniczeniem | duplikat wykryty tylko w logu workera; API zwraca `success` i tworzy **drugi rekord** o tej samej sumie; ani v10, ani `duplicate_documents` w v9 nie sygnalizują duplikatu w wariancie domyślnym |
| duplikaty — wariant odrzucania | `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true`, kontrolowane odtworzenie samego `webserver` | PASS z istotnym ograniczeniem kontraktu | żaden rekord nie powstał (`9` → `9`); task zakończył się `failure`; v10 `result_data: {"duplicate_of": 7, "duplicate_in_trash": false}` i `related_document_ids: [7]`; v9 `related_document: 7` oraz wypełnione `duplicate_documents`; pozytywnym wyróżnikiem duplikatu jest `result_data.duplicate_of`, nie sam brak pól błędu; zadanie Celery raportuje `succeeded`, a API `failure`; odpowiedź wskazuje **jeden** dokument, choć sumę dzielą dwa |
| duplikaty — pełny zbiór po sumie | filtr `GET /api/documents/?checksum__iexact=` | PASS | `count=2`, `ids=[8, 7]`, spójnie przed próbą i po niej; empirycznie potwierdzony fallback niezależny od wariantu konfiguracji; próba nie dowodzi, że jest to jedyna możliwa metoda |
| duplikat logiczny | `DOC-09C` — ponowny skan tej samej treści | BLOCKED | brak rzeczywistego ponownego skanu; nie wolno symulować innym plikiem |
| duży plik | `DOC-07` | BLOCKED | dokumentacja nie ustala progu „dużego pliku”; decyzja G4-03 należy do M8 (`14-API-Specification.md`) |
| polskie znaki | nazwa pliku, tytuł i treść `DOC-10` | PASS z uwagą | nazwa, tytuł (NFC) i treść zachowane w UTF-8; oryginał zgodny bajtowo; search frazy i `title__icontains` po polsku działają; `Content-Disposition` — `filename*` poprawny, ale `filename=` transliterowany do ASCII **ze stratą znaków** |
| kontrakt zadań v9 vs v10 | ten sam task odczytany z `version=9` i `version=10` | PASS z uwagą | v9 zwraca listę i pola `related_document`/`result`/`SUCCESS`; v10 zwraca obiekt stronicowany i pola `related_document_ids`/`result_data`/`success`; nagłówek odpowiedzi w obu wypadkach `X-Api-Version: 10` |
| endpointy binarne a `Accept` | `/download/`, `/preview/`, `/thumb/` z zadeklarowanym typem docelowym oraz z wersjonowanym nagłówkiem API | PASS ze sprawdzonym fallbackiem | **żaden z trzech endpointów nie ogłasza swojego typu wyjściowego**: `application/pdf; version=10` i `image/webp; version=10` dają `406`, natomiast `application/json; version=10` oraz `*/*` zwracają `200` z właściwym `Content-Type`; parametr `version` nie zmienia wyniku negocjacji |
| restart w trakcie OCR | odtworzenie samego `webserver` przy potwierdzonym stanie `started`, dwudziestostronicowy PDF rastrowy | **FAIL** | zadanie zostaje w stanie `started` **bez końca** (>15 min), dokument nie powstaje, plik znika ze scratch i consume; brak duplikatu, brak utraty istniejących dokumentów, sanity checker czysty; niedostępność API `26 s`, `healthy` po `44 s`; powtórzone dwukrotnie |
| limit pamięci brokera | izolowany Valkey z `maxmemory=3mb` | PASS | domyślna polityka `noeviction`; po limicie `OOM command not allowed when used memory > 'maxmemory'.`, `evicted_keys=0`, odczyt nadal działa; przy `allkeys-lru` ten sam scenariusz usuwa `51` kluczy **bez błędu** |
| kolejka BullMQ | sześć scenariuszy przy wspólnym i osobnym Valkey | PASS | `jobId` deduplikuje tylko dopóki job istnieje; po awarii workera dostawa jest **co najmniej jednokrotna** (2 wykonania); jeden skutek biznesowy zapewnia idempotentny zapis w Core; reconciliation odbudowuje usunięty job; zachowanie identyczne w obu topologiach |
| exporter | pełny `document_exporter ../export --compare-checksums` | PASS z uwagą | `27` plików, manifest obecny; **eksport obejmuje także pozycje kosza** — `10` rekordów `documents.document` przy `9` dokumentach aktywnych i `1` w koszu; kontrola kompletności musi porównywać sumę, nie samo `/documents/?count` |
| importer na pustej instancji | `document_importer` na 3.0.4 o tym samym digeście, cel bez wolumenów źródła | PASS | import w `3–4 s`; liczniki dokumentów, tagów, korespondentów i typów zgodne; wszystkie checksumy dokumentów odtworzone; wykonane osobno dla Restic i Borg |
| nowy token celu | usunięcie tokenów z importu i wygenerowanie nowego | PASS | cel działa bez jakiegokolwiek materiału uwierzytelniającego ze źródła |
| sanity checker po imporcie | `document_sanity_checker` na celu restore | PASS | `No issues detected` dla obu kandydatów, w E3A i w E3B |
| disaster recovery | logiczne dumpy obu baz, media, assety i konfiguracja odtworzone na czysty projekt | PASS | obie bazy odtworzone z `pg_dump -Fc`; media `25` plików; reconciliation Core ↔ Paperless `9/9` bez rozjazdu; checksumy assetów zgodne; otwieranie dokumentów, preview i OCR search działają |
| indeks wyszukiwania po DR | zestaw DR bez katalogu `data` Paperless | PASS | **ręczna przebudowa indeksu nie była potrzebna** — 3.0.4 odtworzyło indeks samodzielnie przy starcie; OCR search zwrócił trafienia bez `document_index reindex` |
| zamrożenie zapisów | zatrzymanie samego `webserver` na czas budowy zestawu DR | PASS | punkt spójności uzyskany w `38 s`; po odmrożeniu `healthy`, sanity czysty, liczba dokumentów niezmieniona |
