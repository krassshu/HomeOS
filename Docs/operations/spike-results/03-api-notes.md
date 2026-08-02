# Notatki API Paperless-ngx 3.0.4

**Status:** `in progress` · **Eksperyment:** E1 · **API:** v10

## E1-03 — uwierzytelnienie, wersja i OpenAPI

Wyniki pochodzą z działającej instancji laboratoryjnej Paperless-ngx, a nie z zachowania serii 2.x.

| Kontrola | Wynik |
|---|---|
| Obraz Paperless | `3.0.4@sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582` |
| Uwierzytelnienie | token API, odpowiedź `200` z `/api/documents/?page_size=1` |
| Nagłówek wersji API | `X-Api-Version: 10` |
| Nagłówek wersji serwera | `X-Version: 3.0.4` |
| `/api/` | `302 Found`, `Location: schema/view/` |
| Przeglądarka API | `/api/schema/view/` |
| Surowy schemat | `/api/schema/`, `Accept: application/vnd.oai.openapi; version=10` |
| Wersja formatu OpenAPI | `3.0.3` |
| `info.title` | `Paperless-ngx REST API` |
| `info.version` | `6.0.0 (10)` |
| Liczba ścieżek | `92` |
| SHA-256 schematu | `d3b41d94159dc88346f6cc31889764eb5d5d7e31b2c9c8b7685d7759e617e727` |

Wartość `info.version` opisuje wygenerowany kontrakt API. Nie jest wersją uruchomionego serwera; jej źródłem prawdy jest nagłówek `X-Version: 3.0.4` oraz przypięta referencja obrazu.

Surowy plik `paperless-ngx-3.0.4-openapi-v10.yaml`, odpowiedzi i nagłówki pozostają w ignorowanym przez Git katalogu `raw/`. Token, nagłówek `Authorization`, adres e-mail i inne sekrety nie są utrwalane w tym artefakcie.

## Pozostałe działania

Mapowanie operacji `DocumentProvider` oraz zredagowane przykłady odpowiedzi zostaną uzupełnione po wykonaniu E1-04…E1-08b. Do zamknięcia tej notatki wymagane jest ponowne sprawdzenie uploadu, task status, metadata, original, preview, thumbnail, search, edycji klasyfikacji, delete i health/fallback health.

## E1-04 — upload i task status

Upload `DOC-01`, syntetycznego PDF z warstwą tekstową, na `/api/documents/post_document/` zwrócił `200` i identyfikator zadania. Odczyt `/api/tasks/?task_id={uuid}` w API v10 zwrócił jeden rekord ze statusem `success`, typem `consume_file` i źródłem `api_upload`. Dokument został utworzony z ID `1` i odnaleziony przez `title_search`.

Obiekt zadania API v10 używa między innymi pól:

- `related_document_ids` zamiast oczekiwanego pola pojedynczego `related_document`,
- `result_data` zamiast `result`,
- `status` zapisanego małymi literami, na przykład `success`,
- `task_type` oraz `trigger_source`.

W E1-04 `related_document_ids` zawierało `[1]`, a `result_data.document_id` miało wartość `1`; oba wskazania zgadzały się z wynikiem wyszukania dokumentu. Zmierzony czas oczekiwania wyniósł `0,048051 s`, a czas wykonania `0,612652 s`.

Klient nie może zakładać struktury tasków z serii 2.x ani starszej wersji API. Powinien używać kontraktu v10 i zweryfikować zgodność identyfikatorów zwróconych w obu polach.

## E1-06 — dokument i metadata

Odczyt `/api/documents/1/` dla `DOC-01` potwierdził tytuł, nazwę oryginału i wyodrębnienie `284` znaków treści. Charakterystyczna fraza z polskimi znakami była obecna w polu `content`. Dokument tekstowy nie otrzymał archive PDF (`archive_file_name=null`); jest to weryfikowane dodatkowo przez endpoint metadata i pobranie plików.

Endpoint `/api/documents/{id}/metadata/` zwraca w API v10:

- `original_filename`, `original_mime_type`, `original_size`, `original_checksum`,
- `media_filename`, `original_metadata`,
- `has_archive_version`,
- `archive_media_filename`, `archive_size`, `archive_checksum`, `archive_metadata`,
- `lang`.

Dla `DOC-01` endpoint zwrócił `original_mime_type=application/pdf`, `original_size=15128`, `lang=pl` oraz `has_archive_version=false`. `original_checksum` był identyczny z SHA-256 pliku przed uploadem. Brak archive PDF dla tekstowego wejścia jest stanem oczekiwanym; preview oraz zachowanie fallbacku są sprawdzane osobno.

Pobranie `/api/documents/1/download/?original=true` zwróciło `200`, `Content-Type: application/pdf`, `Content-Length: 15128`, wersje API/server `10`/`3.0.4` oraz bezpieczny `Content-Disposition: attachment`. Pobrany plik miał tę samą sumę SHA-256 i był identyczny bajt po bajcie z wejściem.

Przy `has_archive_version=false` endpoint `/preview/` zwrócił `200`, oryginalny PDF identyczny bajt po bajcie oraz `Content-Disposition: inline`. Jest to potwierdzony fallback preview dla tekstowego PDF bez archive version. Endpoint `/thumb/` zwrócił `200` i osobny obraz WebP `500×707`, `6068 B`, również jako `inline`.

## E1-07 — wyszukiwanie

Pełnotekstowe wyszukiwanie parametrem `query` dla dokładnej frazy `"obsługi tekstowego pliku PDF"` zwróciło jeden wynik: `DOC-01`, score `1,4384105205535889`, rank `1`. Ta sama fraza z celową literówką (`obsłógi`) zwróciła zero wyników. Dokładne wyszukiwanie polskiej treści działa bez jawnego `PAPERLESS_SEARCH_LANGUAGE`; tolerancja literówek nie jest zapewniana przez sprawdzony wariant i wymaga fallbacku Core opisanego w MVP.

## E1-08 — klasyfikacja

OPTIONS uruchomionego API v10 potwierdził, że dla tagu, korespondenta i typu dokumentu jedynym wymaganym polem przy tworzeniu jest `name`; `match` i `matching_algorithm`, a dla tagu również `color`, są opcjonalne. Trzy obiekty laboratoryjne utworzono przez `POST` z wynikiem `201`.

PATCH dokumentu zwrócił `200` i przypisał tag, korespondenta oraz typ dokumentu. Niezależny GET dokumentu potwierdził zachowanie wszystkich trzech identyfikatorów.

Niezależne GET tagu, korespondenta i typu dokumentu zwróciły `200`, oczekiwane nazwy, pusty `match` i domyślny `matching_algorithm=1`.

## E1-08b — health

OpenAPI 3.0.4 zawiera dedykowany `GET /api/status/`. Uwierzytelnione wywołanie z timeoutem zwróciło `200` w `1,072120 s`, `pngx_version=3.0.4`, PostgreSQL `OK`, Redis/Valkey `OK`, Celery `OK`, indeks `OK` i klasyfikator `OK`. Wywołanie bez tokenu zwróciło `401` i `WWW-Authenticate: Token`; endpoint nie jest publiczny.

`sanity_check_status=WARNING` z komunikatem o braku zadań sanity oznacza brak zarejestrowanego okresowego uruchomienia, a nie wykryte uszkodzenie. Ręcznie uruchomiony sanity checker laboratorium przeszedł bez problemów. Surowa odpowiedź statusu pozostaje poza Git, ponieważ ujawnia wewnętrzne adresy usług i identyfikator workera.

Algorytm kontrolny sprawdza transport, HTTP `200`, wersję `3.0.4` oraz stany DB, Valkey, Celery i indeksu. Dla działającej instancji zwrócił `available`; kontrola na nieużywanym porcie zwróciła błąd transportowy curl `7` i stan `unavailable`. Pozwala to odróżnić niedostępność od odpowiedzi zdrowej oraz od przyszłego stanu zdegradowanego przy HTTP `200`.

## E1-05 — polski OCR, próba wstępna

`DOC-02` był jednostronicowym obrazowym PDF A4 bez warstwy tekstowej, `3 506 235 B`. Materiał powstał przez przechwycenie syntetycznego tekstu z ekranu tabletu, dlatego sprawdza techniczny pipeline OCR, ale nie zamyka blokującej próby na rzeczywistej kartce.

Task `consume_file` zakończył się statusem `success`, utworzył dokument ID `2` i raportował `6,808236 s` wykonania. OCR `lang=pl` rozpoznał pełną frazę `"żółta ćma odpoczywa obok źródlanej rzeki"` oraz wszystkie sześć słów kontrolnych. Powstał archive PDF `61 629 B` z checksumą `6a13dceea7f4a895eaba90f813e1a41596f6c52350a03397fd87b81ffc6746c8`.

Orientacyjny pomiar z trzech próbek wykazał CPU peak `100,92%`, RAM webservera `676,20 MiB` idle i `749,40 MiB` peak. Cztery mierzone wolumeny wzrosły łącznie o `3 584 947 B`, czyli `1,022449×` rozmiaru wejścia. Pełne dane znajdują się w `02-resource-measurements.csv`.

Wyszukiwanie API dokładnej frazy OCR zwróciło jeden wynik, dokument ID `2`, score `4,962573528289795`, rank `1`. Wariant z jedną literówką (`źrudlanej`) zwrócił zero wyników. Pobrany przez `/download/?original=false` archive PDF miał checksumę zgodną z metadata i zawierał przeszukiwalną pełną frazę OCR.

Preview dokumentu OCR zwrócił `200`, `Content-Disposition: inline` i plik o checksumie identycznej z archive PDF. Miniatura zwróciła `200` i osobny WebP `500×707`, `4302 B`. Tym samym 3.0.4 potwierdził dwa zachowania preview: fallback do oryginału bez archive version oraz wybór archive PDF po OCR.

## E1-09a — mobilny PNG

Oczyszczony z EXIF/GPS PNG `768×1024`, `1 040 729 B`, zachował identyczne piksele ze źródłem. Upload utworzył dokument ID `3`; task zakończył się statusem `success` w `3,157256 s`. OCR wyodrębnił tekst i utworzył archive PDF `83 426 B`. Mierzone wolumeny wzrosły o `1 161 507 B`, czyli `1,116051×` wejścia.

Źródło zawierało tekst angielski, francuski i polski, bez tekstu niemieckiego, natomiast metadata zwróciła `lang=de`. Pole `lang` nie może być uznane za wiarygodną klasyfikację języka dokumentu wielojęzycznego ani podstawę decyzji domenowej. Faktyczną użyteczność polskiej treści sprawdza osobny search po rozpoznanej frazie.

Search dokładnej polskiej frazy `"CYFROWY Z TECHNOLOGIĄ SMART 600V"` zwrócił wyłącznie dokument ID `3`. Wariant z literówką (`TECHNOLOGIO`) zwrócił zero wyników. Błędne `lang=de` nie uniemożliwiło indeksowania ani wyszukania polskiej treści.

## E1-09b/E1-10 — DOCX przez Tika i Gotenberg

Integralny DOCX OpenXML `8 540 B` został przyjęty przez API. Task zakończył się statusem `success`, utworzył dokument ID `4` i raportował `1,424921 s`. Log skorelowany identyfikatorem taska potwierdził wysłanie DOCX do Tika, konwersję do PDF oraz zakończenie procesu z kodem `0`. Niezależny log Gotenberga potwierdził `POST /forms/libreoffice/convert`, status `200`, klienta `gotenberg-client/0.14.0` i czas około `480,8 ms`.

Metadata zachowało MIME i checksumę oryginalnego DOCX oraz wskazało archive PDF `37 278 B`. Ekstrakcja zachowała charakterystyczną frazę, polskie znaki i wszystkie wartości tabeli. Kontrola wizualna preview potwierdziła poprawny nagłówek, polskie znaki, czytelną tabelę 2×3 i brak nakładania lub obcinania tekstu. Mierzone wolumeny wzrosły o `96 913 B`, czyli `11,348126×` małego wejścia.

## E1-09c/E1-10 — XLSX przez Tika i Gotenberg

Kontrolowany XLSX OpenXML `5 172 B` zawierał sześć rzeczywistych formuł, oczekiwaną sumę `148,49 PLN`, polskie znaki i frazę kontrolną. Przed uploadem przeszedł kontrolę integralności ZIP, odczyt formuł oraz round-trip XLSX bez błędów formuł. API zwróciło `200`; task `consume_file` zakończył się statusem `success`, utworzył dokument ID `5` i raportował `0,010634 s` oczekiwania oraz `1,694846 s` wykonania.

Log skorelowany identyfikatorem taska potwierdził wysłanie XLSX do Tika, przekazanie konwersji do PDF i zakończenie procesu z kodem `0`. Niezależny log Gotenberga potwierdził `POST /forms/libreoffice/convert`, status `200`, klienta `gotenberg-client/0.14.0`, `5 599 B` wejścia żądania i `49 708 B` wyjścia w około `714,6 ms`.

Metadata zachowało MIME `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, rozmiar i checksumę oryginału. Pobrany oryginał miał identyczny SHA-256. Archive PDF był jednostronicowym A4, miał `49 708 B` i checksumę zgodną z metadata. Ekstrakcja tekstu z archive PDF potwierdziła frazę kontrolną, polskie znaki, wszystkie trzy wiersze tabeli oraz obliczony wynik `148,49 PLN`. Preview miał checksumę identyczną z archive PDF. Miniatura była obrazem WebP `500×707`, `12 340 B`.

Wywołanie `/thumb/` z `Accept: image/webp` zwróciło `406`, natomiast to samo uwierzytelnione wywołanie z używanym w laboratorium `Accept: application/json; version=10` zwróciło `200`, `Content-Type: image/webp`, `X-Api-Version: 10` i `X-Version: 3.0.4`. Klient nie powinien zakładać, że deklarowanie docelowego typu obrazu w `Accept` jest obsługiwane przez ten endpoint; wersjonowany nagłówek API pozostaje sprawdzonym wariantem.

Powtórzona kontrola na dokumencie ID `7` objęła również wariant łączący typ docelowy z wersją API i objęła wszystkie trzy endpointy binarne. Zmierzone odpowiedzi 3.0.4:

| Endpoint | `Accept` | HTTP | `Content-Type` | Rozmiar |
|---|---|---:|---|---:|
| `/thumb/` | `image/webp` | `406` | `application/json` | `57 B` |
| `/thumb/` | `image/webp; version=10` | `406` | `application/json` | `57 B` |
| `/thumb/` | `application/json; version=10` | `200` | `image/webp` | `8 490 B` |
| `/thumb/` | `*/*` | `200` | `image/webp` | `8 490 B` |
| `/preview/` | `application/pdf` | `406` | `application/json` | `57 B` |
| `/preview/` | `application/pdf; version=10` | `406` | `application/json` | `57 B` |
| `/preview/` | `application/json; version=10` | `200` | `application/pdf` | `24 232 B` |
| `/preview/` | `*/*` | `200` | `application/pdf` | `24 232 B` |
| `/download/?original=true` | `application/pdf` | `406` | `application/json` | `57 B` |
| `/download/?original=true` | `application/pdf; version=10` | `406` | `application/json` | `57 B` |
| `/download/?original=true` | `application/json; version=10` | `200` | `application/pdf` | `24 232 B` |
| `/download/?original=true` | `*/*` | `200` | `application/pdf` | `24 232 B` |

Jest to zachowanie ogólne, nie właściwość samej miniatury: **żaden z trzech endpointów binarnych nie ogłasza swojego typu wyjściowego jako akceptowanego**, choć dokładnie takim typem odpowiada. Dodanie parametru `version` nie zmienia wyniku negocjacji. Klient musi wysyłać wersjonowany nagłówek API (`application/json; version=10`) albo `*/*` i dopiero z odpowiedzi odczytać rzeczywisty `Content-Type`.

Konsekwencja dla M4/M6: `DocumentProjection` i kontrakt `DocumentProvider` nie mogą zakładać, że deklaracja typu docelowego w `Accept` jest wspierana przy pobieraniu oryginału, preview i miniatury. Harness E1 wykonuje i zapisuje próbę wariantu docelowego, a wynik kontroli opiera na sprawdzonym fallbacku.

Automatyczna kontrola E1-09c i techniczna część E1-10 mają wynik PASS. Kontrola wizualna preview potwierdziła pojedynczą stronę, kompletny nagłówek, czytelną tabelę, wynik `148,49 PLN`, sekcję kontroli formuł i nieobciętą linię z polskimi znakami. Tym samym próba XLSX jest zamknięta pełnym wynikiem PASS.

## E1-09d — wielostronicowy dokument rastrowy, próba wstępna

`DOC-06` był czterostronicowym PDF A4 200 dpi bez warstwy tekstowej, `837 164 B`, `0` znaków tekstu przed OCR. Materiał powstał przez rasteryzację syntetycznego tekstu w laboratorium, więc sprawdza wydajność i poprawność wielostronicowego OCR, ale **nie zamyka wymagania reprezentatywności rzeczywistego skanu**. Wymóg z `01-test-document-manifest.md` pozostaje otwarty razem z `DOC-02`.

Task `consume_file` zakończył się statusem `success`, utworzył dokument ID `6`, raportował `0,053229 s` oczekiwania i `3,995292 s` wykonania. Metadata zwróciła `original_size=837164`, `original_checksum` zgodny z wejściem, `has_archive_version=true`, `archive_size=693601`, `archive_checksum=189089141e2d3d995b701d723b28c6a40144a69db6be92e71e905dee7d4d8197` i `lang=pl`. Detail dokumentu zwrócił `page_count=4` oraz `2182` znaki treści.

Kontrola liczby stron: wejście `4` strony, archive PDF `4` strony (`Producer: pikepdf 10.2.0`, A4 595,44 × 842,04 pt). Pobrany oryginał był identyczny bajt po bajcie z wejściem. Preview miał checksumę identyczną z archive PDF. Miniatura to WebP `500×707`, `19 328 B`.

Pomiar z 40 próbek co około sekundę: CPU peak `389,24%` na hoście 4 vCPU, RAM webservera `894,30 MiB` idle i `1 099,78 MiB` peak, czyli przyrost `205,48 MiB`. Cztery mierzone wolumeny wzrosły o `1 620 595 B`, czyli `1,935815×` rozmiaru wejścia; sam archive PDF to `0,828513×`, a miniatura `0,023087×`.

**Zachowanie OCR istotne dla wyszukiwania:** tekst rozpoznany na stronie pierwszej zawierał sklejenie sąsiednich wyrazów (`KONTROLA ALFA` → `KONTROLAALFA`). Dokładna fraza kontrolna pierwszej strony zwróciła `0` wyników, natomiast ta sama fraza z uwzględnieniem sklejenia zwróciła dokument `6` ze score `4,6755`. Inna fraza z pierwszej strony (`"Niniejszy protokol opisuje przebieg proby laboratoryjnej"`) zwróciła dokument `6` ze score `6,2430`, a fraza z ostatniej strony ze score `5,1993`. Pierwsza i ostatnia strona są więc przeszukiwalne, ale **pojedynczy błąd segmentacji OCR wystarcza, by dokładne zapytanie frazowe nie zwróciło dokumentu**. Potwierdza to potrzebę fallbacku wyszukiwania po stronie Core, opisanego już przy E1-07.

## E1-11b — uszkodzony PDF

`DOC-08` powstał jako kopia syntetycznego `DOC-09A` z obciętym strumieniem i zniszczoną tablicą xref; `13 354 B`, MIME nadal `application/pdf`, `pdfinfo` zgłasza `Couldn't find trailer dictionary`. Żaden istniejący fixture nie został zmodyfikowany.

Upload zwrócił `200` i UUID zadania — Paperless nie odrzuca uszkodzonego pliku na etapie HTTP. Task zakończył się statusem `failure` po `0,225974 s`, z `related_document_ids: []`. Liczba dokumentów przed i po próbie wynosiła `6`; **pozornie poprawny dokument nie powstał**. Jest to oczekiwane odrzucenie wejścia, a nie awaria Paperless.

Struktura `result_data` przy błędzie w API v10:

- `error_type` — nazwa klasy wyjątku, tutaj `ConsumerError`,
- `error_message` — `"DOC-08.pdf: Error occurred while consuming document DOC-08.pdf: InputFileError: "`,
- `traceback` — pełny ślad stosu Pythona.

Dwie obserwacje kontraktu dla Core:

1. `error_message` zawiera nazwę pliku wejściowego i **pusty człon przyczyny** (`InputFileError:` bez treści). Sam komunikat nie nadaje się na komunikat użytkownika i nie identyfikuje jednoznacznie klasy błędu.
2. `result_data.traceback` **ujawnia wewnętrzne ścieżki źródeł** (`/usr/src/paperless/src/...`, `/usr/local/lib/python3.12/site-packages/...`). Nie zawiera sekretów ani ścieżek hosta, ale nie może być przekazywany klientowi bez filtrowania. Ścieżka pliku roboczego w `/tmp` pojawia się dodatkowo w logu workera.

Po trwałym błędzie worker pozostał zdrowy: `RestartCount=0`, stan `running`, health `healthy`. Kolejny lekki uwierzytelniony request `GET /api/status/` zwrócił `200` w `1,027828 s` z DB, Valkey, Celery i indeksem `OK`.

## E1-11c — duplikat binarny

`DOC-09A` (`24 232 B`, PDF z warstwą tekstową) utworzył dokument ID `7`, task `success` w `0,606017 s`, `has_archive_version=false`. `DOC-09B` był kopią binarnie identyczną — ten sam SHA-256 `20e91ad2…`, potwierdzony dodatkowo przez `cmp`.

Przy konfiguracji laboratorium `PAPERLESS_CONSUMER_DELETE_DUPLICATES=false` (wartość potwierdzona w uruchomionej instancji, a nie założona):

- upload zwrócił `200` i UUID zadania,
- task zakończył się statusem `success` w `0,639460 s`,
- **powstał drugi rekord dokumentu ID `8`** o tej samej sumie `checksum`,
- liczba dokumentów wzrosła z `7` do `8`,
- wyszukiwanie wspólnej frazy zwróciło oba dokumenty, `8` i `7`, z identycznym score `8,6063`.

Duplikat **został wykryty**, ale wyłącznie w logu workera: `[WARNING] [paperless.consumer] Consuming duplicate DOC-09B.pdf: 1 existing document(s) share the same content.` Nazwa ustawienia i miejsce decyzji potwierdzone w źródle uruchomionego 3.0.4 (`documents/consumer.py::pre_check_duplicate`, `paperless/settings/__init__.py`), nie przeniesione z serii 2.x.

**Istotna obserwacja kontraktu domyślnego:** przy `PAPERLESS_CONSUMER_DELETE_DUPLICATES=false` API nie sygnalizuje duplikatu w żaden sposób. Obiekt zadania w v10 nie ma pola o duplikacie, a `result_data` zawiera wyłącznie `{"document_id": 8}`. Klient REST nie może w tym wariancie odróżnić duplikatu binarnego od nowego dokumentu.

Wariant odrzucania duplikatów został wykonany osobno i opisany w E1-11d.

## E1-11d — wariant odrzucania duplikatów

Próba wykonana przez kontrolowaną zmianę jednej zmiennej środowiskowej i odtworzenie **wyłącznie** usługi `webserver`. Obraz, digest, porty, topologia i pozostałe ustawienia pozostały bez zmian; pięć pozostałych kontenerów nie zostało odtworzonych (identyczne identyfikatory przed i po). Konfiguracja została przywrócona bezpośrednio po próbie.

### 1. Zachowanie przy `PAPERLESS_CONSUMER_DELETE_DUPLICATES=false`

Opisane w E1-11c: powstaje drugi rekord dokumentu, task kończy się statusem `success`, a `result_data` zawiera wyłącznie `{"document_id": 8}`. API nie sygnalizuje duplikatu w żaden sposób.

### 2. Zachowanie przy `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true`

Wysłano kopię `DOC-09A` pod nazwą `DOC-09B-REJECT-TRUE.pdf`, potwierdzoną przed uploadem jako identyczną sumą SHA-256 oraz przez `cmp`.

| Kontrola | Wynik |
|---|---|
| Upload | `200`, `0,288919 s`, zwrócony UUID zadania |
| Stan końcowy zadania | `failure`, osiągnięty przy drugim odpytaniu |
| Czas oczekiwania / wykonania | `0,005599 s` / `0,030266 s` |
| Liczba dokumentów przed i po | `9` → `9`, delta `0` |
| Dokumenty o wspólnej sumie | `[8, 7]` przed i po próbie |
| Dokumenty ID `7` i `8` | nadal `200` |
| Kosz | bez zmian, `1` pozycja (ID `10`) |
| Zdrowie workera | `RestartCount=0`, `running`, `healthy`; kolejny `/api/status/` `200`, DB/Valkey/Celery/indeks `OK` |

**Żaden nowy rekord nie powstał.** Odrzucenie nastąpiło w preflightcie konsumenta, przed utworzeniem dokumentu.

Log workera skorelowany identyfikatorem zadania:

```text
[WARNING] [paperless.consumer] [5710ddd1] Consuming duplicate DOC-09B-REJECT-TRUE.pdf: 2 existing document(s) share the same content.
[ERROR]   [paperless.consumer] [5710ddd1] Not consuming DOC-09B-REJECT-TRUE.pdf: It is a duplicate of HomeOS M3 DOC-09A base (#7)
[INFO]    [paperless.tasks]    [5710ddd1] ConsumerPreflightPlugin rejected duplicate: DOC-09B-REJECT-TRUE.pdf
[INFO]    [celery.app.trace]   Task documents.tasks.consume_file[5710ddd1-…] succeeded in 0.0306s: {'duplicate_of': 7, 'duplicate_in_trash': False}
```

**Rozbieżność warstw:** zadanie Celery zakończyło się *powodzeniem* (`succeeded`), a API raportuje ten sam rekord jako `failure`. Klient nie może wnioskować o awarii z samego statusu — odrzucony duplikat wygląda w API tak samo jak trwały błąd wejścia z E1-11b i wymaga rozróżnienia po zawartości `result_data`.

Odrzucenie **nie usunęło pliku źródłowego** przekazanego przez API; ustawienie dotyczy roboczej kopii konsumenta, a nie wejścia klienta.

### 3. Różnice API v9 i v10

Ten sam rekord zadania odczytany dwoma wersjami nagłówka `Accept`. W obu wypadkach odpowiedź ma `X-Api-Version: 10` i `X-Version: 3.0.4`.

| Cecha | `version=9` | `version=10` |
|---|---|---|
| Kształt odpowiedzi | lista JSON | obiekt stronicowany `count`/`results` |
| Status | `FAILURE` | `failure` |
| Powiązanie z dokumentem | `related_document: 7` | `related_document_ids: [7]` |
| Wynik strukturalny | brak `result_data` | `result_data: {"duplicate_of": 7, "duplicate_in_trash": false}` |
| Wynik tekstowy | `result: "Not consuming: It is a duplicate of document #7"` | brak `result` |
| Pole duplikatu | `duplicate_documents: [{"id": 7, "title": "…", "deleted_at": null}]` | pole nie występuje |
| Nazwa zadania | `task_name: consume_file`, `type: manual_task` | `task_type: consume_file`, `task_type_display`, `trigger_source` |
| `error_type` / `error_message` | pole nie występuje | **pole nie występuje** |
| `traceback` | brak | brak |

Obie reprezentacje niosą komplet informacji, ale w różnej formie. `duplicate_documents` w v9 — puste przy `false` — przy `true` jest **wypełnione** i dodatkowo zawiera tytuł oraz `deleted_at`. Pola `duplicate_of` i `duplicate_in_trash` przewidziane w źródle 3.0.4 zostały potwierdzone empirycznie, ale **wyłącznie w `result_data` reprezentacji v10**, a nie jako pola najwyższego poziomu obiektu zadania.

W przeciwieństwie do trwałego błędu wejścia z E1-11b odrzucony duplikat **nie zawiera `error_type`, `error_message` ani `traceback`**. Pozytywnym i najpewniejszym rozróżnieniem jest jednak obecność liczbowego `result_data.duplicate_of` wraz z boolowskim `duplicate_in_trash`; sam brak pól błędu nie wystarcza do sklasyfikowania dowolnego `failure` jako duplikatu.

### 4. Czy istniejący dokument można ustalić z odpowiedzi

Tak. W v10 identyfikator jest podany dwukrotnie i zgodnie: `related_document_ids: [7]` oraz `result_data.duplicate_of: 7`. W v9 podany jest jako `related_document: 7` i w `duplicate_documents[0].id`. Informacja o koszu jest jednoznaczna: `duplicate_in_trash: false` w v10, `deleted_at: null` w v9.

**Ograniczenie kontraktu:** odpowiedź wskazuje **jeden** istniejący dokument, mimo że log workera stwierdził `2 existing document(s) share the same content`. W tej próbie był to dokument `7`, ale pojedynczy przebieg nie ustala stabilnej reguły wyboru; klient nie może zakładać najniższego ani najwyższego ID. Pełnej rodziny duplikatów nie da się odczytać z samej odpowiedzi zadania.

### 5. Czy potrzebny jest fallback po sumie kontrolnej

Do ustalenia **pojedynczego** dokumentu bazowego — nie. Do ustalenia **pełnego zbioru** dokumentów o tej samej treści — tak.

Filtr `GET /api/documents/?checksum__iexact={sha256}` został sprawdzony i działa: dla sumy `20e91ad2…` zwrócił `count=2`, `ids=[8, 7]`, spójnie przed próbą i po niej. Jest to empirycznie potwierdzony fallback niezależny od wariantu konfiguracji. Próba nie dowodzi, że jest to jedyny możliwy sposób uzyskania kompletu duplikatów.

### 6. Konsekwencja dla przyszłego `PaperlessAdapter`

Zachowanie zależy od ustawienia po stronie Paperless, którego adapter nie kontroluje, dlatego adapter musi obsłużyć oba warianty:

1. Nie traktować `status=failure` jako awarii. Najpierw sprawdzić `result_data.duplicate_of`; jego obecność oznacza odrzucony duplikat, a nie błąd.
2. Klasyfikować odrzucony duplikat pozytywnie po `result_data.duplicate_of` i `duplicate_in_trash`; obecność `error_type` / `error_message` oznacza trwały błąd wejścia. Nie klasyfikować na podstawie samego statusu ani samego braku pól błędu.
3. Używać kontraktu v10 i `result_data`; nie parsować tekstowego `result` z v9.
4. Przy `false` API nie sygnalizuje duplikatu w ogóle — wykrycie wymaga porównania sumy kontrolnej po stronie Core przed uploadem albo po nim.
5. Do pełnego zbioru duplikatów używać `checksum__iexact`, bo odpowiedź zadania wskazuje tylko jeden dokument.

Decyzja o tym, czy deduplikacja należy do Core, czy do adaptera, **pozostaje nierozstrzygnięta**: wynik pokazuje, że Paperless potrafi odrzucić duplikat binarny i zwrócić użyteczny wskaźnik, ale nie pokrywa duplikatu logicznego (`DOC-09C`, wciąż BLOCKED) ani pełnej rodziny duplikatów. Żaden ADR nie jest tą próbą zmieniany.

## Kontrakt zadań: `version=9` a `version=10`

Ten sam zasób zadania odczytany z dwoma wersjami nagłówka `Accept` zwraca dwie różne reprezentacje. Odpowiedź w obu przypadkach ma nagłówek `X-Api-Version: 10`.

| Cecha | `version=9` | `version=10` |
|---|---|---|
| Kształt odpowiedzi | lista JSON | obiekt stronicowany `count`/`results` |
| Powiązanie z dokumentem | `related_document` (pojedyncza wartość) | `related_document_ids` (lista) |
| Wynik | `result` — tekst `"Success. New document id 8 created"` | `result_data` — obiekt, tutaj `{"document_id": 8}` |
| Status | `SUCCESS` (wielkie litery) | `success` (małe litery) |
| Nazwa zadania | `task_name`, `type` | `task_type`, `task_type_display`, `trigger_source` |
| Pole duplikatu | `duplicate_documents` obecne, ale **puste** dla potwierdzonego duplikatu binarnego | pole nie występuje |

Obecność `duplicate_documents` w v9 nie jest więc użytecznym źródłem informacji o duplikacie przy tej konfiguracji. Klient Core musi korzystać z v10 i nie może polegać na tekstowym polu `result`.

Powyższe porównanie dotyczy wariantu domyślnego (`false`). Przy `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` obie reprezentacje wyglądają inaczej i `duplicate_documents` **jest** wypełnione — zestawienie w sekcji E1-11d.

## E1-10 — polskie znaki w nazwie, tytule i treści

`DOC-10` był jednostronicowym PDF z warstwą tekstową, `23 981 B`, o nazwie pliku `DOC-10-zażółć-gęślą-jaźń.pdf` i tytule zawierającym polskie znaki oraz półpauzę. Treść zawierała pełny zestaw `Ą Ć Ę Ł Ń Ó Ś Ź Ż`, odpowiedniki małe oraz pangram kontrolny.

- Upload zwrócił `200`; task `success` w `0,538478 s`; dokument ID `9`.
- `input_data.filename` zadania zachował nazwę w UTF-8 bez zniekształcenia.
- Metadata zwróciła `original_filename` identyczną z nazwą wejściową, `original_size=23981`, `original_checksum` zgodny z wejściem, `has_archive_version=false` (wejście miało już warstwę tekstową).
- Detail dokumentu zwrócił tytuł w formie znormalizowanej NFC oraz `375` znaków treści; wszystkie cztery kontrolowane ciągi z polskimi znakami były obecne w `content`.
- Pobrany oryginał był identyczny bajt po bajcie z wejściem.
- Wyszukiwanie dokładnych fraz `"PROTOKÓŁ KODOWANIA HOMEOS DZIESIĘĆ"` oraz `"Pchnąć w tę łódź jeża lub ośm skrzyń fig"` zwróciło wyłącznie dokument `9`. Filtr `title__icontains=zażółć` również zwrócił wyłącznie dokument `9`.

**Obserwacja `Content-Disposition`:** odpowiedź zawiera dwie formy nazwy. Forma `filename*=utf-8''…` jest poprawna i po zdekodowaniu odtwarza pełną nazwę z polskimi znakami. Forma `filename="…"` jest transliterowana do ASCII **ze stratą znaków**: `zażółć gęślą jaźń` staje się `zazoc gesla jazn`, a półpauza znika, pozostawiając podwójną spację. Klient pobierający oryginał musi używać `filename*`; oparcie się na `filename=` powoduje utratę znaków narodowych.

## E1-16 — delete

Próbę wykonano na osobnym dokumencie jednorazowym `DOC-DEL-01` (ID `10`, checksum `d793a4a0…`). Dokumenty `1`–`5` nie były używane w tej próbie, a skrypt odmawia usunięcia identyfikatora z zakresu chronionego.

- `DELETE /api/documents/10/` zwrócił `204 No Content` w `0,103526 s`, z pustym ciałem odpowiedzi.
- Ponowny `GET /api/documents/10/` zwrócił `404`.
- Liczba dokumentów spadła z `10` do `9`.
- `GET /api/trash/` zwrócił `1` pozycję: ID `10` z `deleted_at`. **Delete w 3.0.4 jest przeniesieniem do kosza, nie natychmiastowym usunięciem plików.** Kosz celowo nie został opróżniony.
- Dokumenty `1`–`5` oraz `6`–`9` pozostały dostępne (`200` dla każdego z zakresu chronionego).

Operacja `trash / delete` z listy blokujących operacji `DocumentProvider` jest tym samym potwierdzona, z zastrzeżeniem że semantyka to soft delete i pełne usunięcie wymaga osobnej operacji na koszu.
