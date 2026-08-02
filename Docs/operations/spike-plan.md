# Plan wykonawczy Fazy 1 — E1, E2 oraz dwa tory E3

**Status:** `accepted` · **Milestone:** M3 · **Data:** 2026-07-27

**Podstawa:** `../07-Product-and-Delivery-Roadmap.md` §8 · `../08-MVP-Scope.md` §5 (decyzje G1) · `../00-Analiza-i-Mapa-Realizacji.md` Faza 1

---

# 0. Zasada nadrzędna tej fazy

> **E1, E2, E3A i E3B odpowiadają na różne pytania. Żaden nie zastępuje pozostałych.**

| Eksperyment | Cel | Rozstrzyga | Zależność |
|---|---|---|---|
| **E1 — Paperless 3.0.4 / Gotenberg / Valkey** | Czy komponent spełnia wymagania funkcjonalne i zasobowe | **Gate OS-1**, uzupełnienie **ADR-008** | Zweryfikowany baseline 3.0.4 i host źródłowy |
| **E2 — PoC ORM** | Który ORM udźwignie dynamiczne pola, transakcje, audit, FTS i migracje | **ADR-014** | **Niezależny od E1** — start od pierwszego dnia |
| **E3A — przenośność aplikacyjna** | Czy oficjalny eksport Paperless można zabezpieczyć i zaimportować na czystej instancji | Strategia wyjścia, część **Gate OS-2-LAB** | Dane z E1, czysty cel, klucze i kandydat backupu |
| **E3B — disaster recovery** | Czy surowy backup baz, mediów, assetów i konfiguracji odtwarza działający stack | **ADR-015**, część **Gate OS-2-LAB** | Dane z E1, fixture Core, czysty cel, klucze i kandydat backupu |

**Dlaczego to rozróżnienie ma znaczenie:** exporter/importer sprawdza przenośność kolekcji, ale nie dowodzi, że po utracie serwera można odtworzyć tę samą instancję z baz i mediów. Z kolei surowy restore nie dowodzi, że działa oficjalna strategia wyjścia z Paperless. Oba tory są wymagane, a pełny produkt jest ponownie walidowany dopiero w M17.

## 0.1. Charakter pracy

- **Izolowany katalog laboratoryjny.** Bez monorepo, bez CI, bez Caddy, bez pipeline'u wdrożeniowego. Te powstają dopiero w M9.
- **Baseline zachowujący strukturę oficjalnego Compose v3.0.4.** Referencje wszystkich obrazów są zastąpione jawnymi tagami i digestami; pliki override oraz wariantów ograniczają ekspozycję, ustawiają język polski i dodają wyłącznie izolowane fixture laboratorium. Broker pozostaje Valkey dostarczanym przez upstream v3.0.4.
- **Kod jest jednorazowy. Artefakty nie.** Patrz sekcja 5.
- **Nie budujemy adaptera.** `PaperlessAdapter` powstaje w M11, po zamknięciu kontraktu M6.
- **Nie optymalizujemy niczego.**
- **Eksport/import nie należy do `DocumentProvider`.** Używamy oficjalnych poleceń administracyjnych zgodnie z ADR-019.

## 0.2. Warunki startu — progresywne, nie globalne

### Start E1

- [x] Zakres MVP, decyzje G1 oraz polityka danych są zapisane.
- [x] Repozytoryjna część `BASELINE-3.0.4` z `lab-manifest.md` jest wykonana; Compose, override, tagi, digesty i instrukcje dotyczą wyłącznie 3.0.4.
- [ ] Na docelowym hoście zapisano digesty właściwe dla architektury i potwierdzono warunek `BASELINE-3.0.4`.
- [ ] Jedna izolowana maszyna Linux z Docker Engine/Compose jest gotowa.
- [ ] Bezpieczny `.env`, sekret Paperless, hasło PostgreSQL, konto administratora i token API są poza Git.
- [ ] Zestaw `DOC-01`…`DOC-10`, w tym rodzina `DOC-09A`…`DOC-09C`, jest skompletowany zgodnie z polityką danych.

### Start E2

- [x] Zapisane są wersje Node.js, PostgreSQL, Drizzle i Prisma.
- [x] Gotowy jest jeden wspólny schemat logiczny, zestaw danych i zestaw asercji.

### Start E3A/E3B

- [ ] Instancja źródłowa zawiera dane z E1, a fixture Core ma manifest liczników i checksum.
- [ ] Można utworzyć tymczasowy czysty cel Linux bez współdzielonych baz, wolumenów i katalogów źródła.
- [ ] Restic i Borg są dostępne w zapisanych wersjach; dla obu określono docelowy storage.
- [ ] Materiały odzyskiwania każdego kandydata mają dwie działające kopie out-of-band.

**M3 może rozpocząć się po spełnieniu warunków E1 albo E2.** E3A/E3B są celowo przygotowywane później i nie blokują pierwszego uploadu ani PoC ORM. Profil 4 vCPU / 16 GB / 100 GB jest punktem odniesienia pomiarów, nie minimalnym warunkiem startu.

---

# 1. E1 — Paperless 3.0.4 / Gotenberg / Valkey

**Rozstrzyga:** Gate OS-1 i uzupełnienie ADR-008 (topologia Valkey)

## 1.1. Przygotowanie

| # | Krok | Zapisz |
|---|---|---|
| E1-01 | Potwierdzenie `BASELINE-3.0.4`; kontrola hosta, architektury, tagów i digestów wszystkich obrazów z `lab-manifest.md` | Manifest hosta oraz dowód, że webserver działa z `3.0.4@sha256:3838b9a4260d23acc5bb63aed407138435e70b56e5806f4baa350ca184e57582` |
| E1-02 | Uruchomienie baseline o strukturze oficjalnego Compose `postgres-tika` z taga `v3.0.4`, z przypiętymi obrazami i wersjonowanymi plikami laboratorium | Baseline 3.0.4, override, target, wariant Valkey, pełny wynik konfiguracji i różnice względem starego scaffoldu |
| E1-03 | Potwierdzenie wersji `3.0.4`; wygenerowanie tokenu API; weryfikacja uwierzytelnienia; otwarcie przeglądarki API pod `/api/schema/view/` i pobranie surowego OpenAPI z `/api/schema/` na **uruchomionej instancji 3.0.4** | Notatka o uwierzytelnieniu, odpowiedź wersji, plik OpenAPI i jego checksum |

Wyników, przykładów odpowiedzi, opcji konfiguracji ani zachowań z Paperless 2.x **nie przenosi się jako założeń**. Źródłem prawdy dla M3 jest zachowanie uruchomionego 3.0.4 i jego wygenerowany OpenAPI. Każda rozbieżność względem starego scaffoldu albo bieżącej dokumentacji upstream trafia do raportu i macierzy kompatybilności.

**Znana obserwacja startowa 3.0.4:** jawne `PAPERLESS_SEARCH_LANGUAGE` zatrzymuje inicjalizację błędem `AppRegistryNotReady`. Baseline nie ustawia tej zmiennej. E1 osobno sprawdza jakość wyszukiwania polskich treści przy OCR `pol` i zapisuje ograniczenie lub wymagany fallback.

## 1.1a. Rewalidacja kontraktu 3.0.4

Przed oceną funkcji trzeba:

- porównać listę usług, wolumenów, zmiennych i poleceń oficjalnego Compose v3.0.4 z dotychczasowym scaffoldem,
- potwierdzić endpoint schematu OpenAPI i zachować pełny plik ze wskazaniem wersji,
- ponownie zmapować wszystkie 10 operacji `DocumentProvider` na ścieżki, metody, pola, statusy i błędy 3.0.4,
- nie używać zapisanych odpowiedzi 2.x jako fixture bez ponownego pozyskania z 3.0.4,
- oznaczyć każde pole lub zachowanie usunięte, zmienione albo nowe w 3.0.4.

## 1.2. Ścieżka podstawowa

| # | Krok | Kryterium | Zapisz |
|---|---|---|---|
| E1-04 | Upload PDF tekstowego przez API; odczyt task status | Operacja dostępna, status czytelny | **Surowa odpowiedź API** |
| E1-05 | Weryfikacja OCR języka polskiego na **rzeczywistym skanie** | Dokument odnajdywalny po charakterystycznej frazie z treści | Fraza testowa i wynik |
| E1-06 | Pobranie metadata, thumbnail, original i archive PDF | Metadata, original i preview dostępne; thumbnail działa albo ma udokumentowany fallback | Zredagowane odpowiedzi |
| E1-07 | Search po treści OCR: dokładna fraza z polskimi znakami oraz osobna próba z literówką | Dokładna fraza odnajduje dokument; zachowanie literówki jest zmierzone, ale nie zakładane | Zapytania, wyniki i rozróżnienie obu prób |
| E1-08 | Tag, correspondent, document type przez API — odczyt i zapis | Operacje dostępne; kierunek zapisu potwierdzony | Odpowiedzi API |
| E1-08b | Health: dedykowany endpoint albo uwierzytelniony lekki request kontrolny | Jednoznaczne rozróżnienie `available` / `unavailable` | Endpoint, timeout i odpowiedź |

## 1.3. Formaty

| # | Krok | Format | Cecha testowana |
|---|---|---|---|
| E1-09a | Upload | JPG lub PNG | OCR ze zdjęcia, upload mobilny |
| E1-09b | Upload | DOCX | Pipeline Gotenberg |
| E1-09c | Upload | XLSX | Pipeline Gotenberg, format tabelaryczny |
| E1-09d | Upload | Wielostronicowy skan | Wydajność OCR, archive PDF |
| E1-10 | Weryfikacja | DOCX/XLSX | **Czy faktycznie przechodzą przez Gotenberg w pipeline Paperless** |
| E1-11a | Upload | Duży plik | Streaming, timeout, RAM |
| E1-11b | Upload | Uszkodzony PDF | Obsługa błędu permanentnego |
| E1-11c | Upload | `DOC-09A` — oryginał, `DOC-09B` — kopia binarnie identyczna, `DOC-09C` — ponowny skan tej samej treści | Osobno zapisane zachowanie duplikatu binarnego i logicznego |

Dla `DOC-09B` należy zapisać odpowiedź uploadu, task status, ewentualne wskazanie istniejącego dokumentu i zachowanie zarówno przy domyślnej konfiguracji 3.0.4, jak i przy wspieranym w 3.0.4 ustawieniu odrzucania duplikatów. Nazwy ani semantyki ustawienia nie wolno kopiować z 2.x bez potwierdzenia. E1 opisuje faktyczne zachowanie Paperless 3.0.4. Bezpieczna odpowiedź Core, która nie ujawni prywatnego dokumentu osobie bez uprawnień, pozostaje kontraktem M5/M6.

## 1.4. Pomiary

| # | Pomiar | Jednostka | Kiedy |
|---|---|---|---|
| E1-12a | RAM idle | MB | Stack uruchomiony, brak obciążenia |
| E1-12b | **RAM peak** | MB | W trakcie OCR wielostronicowego skanu |
| E1-12c | CPU podczas OCR | % / rdzenie | W trakcie OCR |
| E1-12d | Czas OCR | s | Per dokument, dla każdego formatu |
| E1-12e | Przyrost dysku | MB i **mnożnik** względem rozmiaru wejściowego | Po każdym uploadzie |
| E1-12f | Rozmiar derivative | MB | archive PDF + thumbnail |

> **Po kroku E1-12 można przygotować E3A/E3B** — instancja ma dane; start nadal wymaga fixture, czystego celu, narzędzi i kluczy z §0.2.

## 1.5. Zachowania awaryjne i Valkey

| # | Krok | Kryterium |
|---|---|---|
| E1-13 | Restart Paperless w trakcie przetwarzania | Dokument nie ginie; przetwarzanie wznawia się lub kończy czytelnym błędem |
| E1-14 | Kontrolowane osiągnięcie limitu pamięci Valkey w izolowanym brokerze | Zachowanie przewidywalne, brak cichej utraty zadania; po teście broker jest odtwarzany |
| E1-15a | Pomiar Paperless: RAM i liczba kluczy w brokerze | Bazowe zużycie Paperless |
| E1-15b-A | Ten sam `jobId`, gdy poprzedni job nadal istnieje | Drugi job jest ignorowany; zapisany stan i liczba wykonań |
| E1-15b-B | Ten sam `jobId` po `removeOnComplete` | Wynik pokazuje, że identyfikator może zostać użyty ponownie po usunięciu poprzedniego joba |
| E1-15b-C | Niegrzeczny restart workera w trakcie aktywnej operacji | Zadanie wraca do obsługi albo kończy się czytelnym błędem |
| E1-15b-D | Wymuszenie scenariusza `stalled` i ponownego wykonania | Udokumentowana co najmniej jednokrotna dostawa; brak założenia exactly-once |
| E1-15b-E | Dwa wykonania tej samej intencji przy idempotentnym zapisie do fixture Core | Dokładnie jeden skutek domenowy |
| E1-15b-F | Usunięcie joba przy pozostawieniu trwałej intencji, następnie reconciliation | Brakujący job zostaje odbudowany; to test architektury Core + kolejka, nie samego BullMQ |
| E1-15c | Te same próby przy wspólnym i osobnym brokerze | Dane do decyzji o topologii oraz wpływie awarii |
| E1-16 | Test delete przez API | Operacja dostępna; skutki zweryfikowane |

**Rozstrzygnięcie topologii Valkey (uzupełnienie ADR-008):** jedna instancja z osobnymi bazami/prefiksami czy dwie osobne instancje Paperless/Core BullMQ. Kryteria: zmierzone zużycie RAM, izolacja awarii, możliwość niezależnego restartu, brak kolizji kluczy i koszt operacyjny. Pomiar wyłącznie na Paperless nie wystarcza — E1-15b i E1-15c są obowiązkowe.

BullMQ zapewnia wykonanie co najmniej jednokrotne w warunkach awarii; `jobId` deduplikuje tylko tak długo, jak job istnieje w kolejce. Dlatego wynik E1-15b jest poprawny wyłącznie wtedy, gdy trwały stan Core, idempotencja i reconciliation ograniczają efekt biznesowy do jednego.

## 1.6. Przygotowanie interfejsu utrzymaniowego

| # | Krok | Kryterium |
|---|---|---|
| E1-17 | Potwierdzenie dostępności i składni `document_exporter`, `document_importer` oraz sanity checkera w 3.0.4 | Polecenia i opcje zapisane z uruchomionej instancji 3.0.4; bez pełnego restore |
| E1-18 | Zapisanie granicy operacyjnej z ADR-019 | Eksporter nie jest wywoływany przez Core ani `DocumentProvider` |

Pełny eksport/import odbywa się w E3A. E1 nie czeka na czysty cel restore ani klucze backupowe.

## 1.7. Gate OS-1 — kryteria zamknięcia E1

| Kryterium | Próg | Status |
|---|---|---|
| Siedem operacji blokujących `DocumentProvider` działa przez REST | Blokujące | ☑ |
| Trzy operacje ostrzegawcze działają albo mają przetestowany fallback | Blokujące na poziomie kontraktu | ☑ (miniatura, preview i oryginał przez sprawdzony wersjonowany `Accept`) |
| OCR polski pozwala odnaleźć dokument po frazie z treści | Blokujące | ☐ potwierdzone wyłącznie na materiale syntetycznym |
| Zasoby mieszczą się w profilu sprzętowym | Ostrzegawcze | ☑ |
| Inwentarz licencji laboratorium kompletny i zaakceptowany | Blokujące (Gate OS-3-LAB) | ☑ |
| Brak krytycznego ograniczenia | Blokujące | ☑ **E1-13 pozostaje FAIL, ale nie spełnia definicji krytycznego ograniczenia z 08 §G1-02** — wymagane operacje REST działają, a E3A i E3B przeszły; jest obowiązkowym wymaganiem odporności integracji M4/M6/M11/M12 |

**Stan na 2026-07-31: Gate OS-1 nie przechodzi.** Brakuje blokującego potwierdzenia OCR na rzeczywistych skanach. E1-13 jest zachowany jako wynik FAIL eksperymentu, ale zgodnie z przyjętą definicją nie dyskwalifikuje Paperless: wszystkie wymagane operacje REST działają, a E3A i E3B przeszły w całości dla obu kandydatów. Wynik wiąże M4/M6/M11/M12 obowiązkiem trwałej intencji, tymczasowego stagingu wejścia, timeoutu, bezpiecznego retry i reconciliation. Szczegóły w [`spike-results/10-decisions-and-gates.md`](spike-results/10-decisions-and-gates.md).

**Jeżeli gate nie przechodzi z powodu krytycznego ograniczenia z 08 §G1-02:** dopiero wtedy porównujemy alternatywne DMS — Mayan EDMS, Docspell, Teedy (05 §5.8). Brakujący materiał dowodowy najpierw uzupełniamy; nie jest sam w sobie podstawą zmiany DMS.

---

# 2. E2 — PoC ORM

**Rozstrzyga:** ADR-014 · **Zależność:** brak — może biec od pierwszego dnia fazy · **Bez udziału Paperless**

## 2.1. Zakres identyczny dla obu kandydatów

Porównanie jest uczciwe tylko wtedy, gdy oba PoC obejmują dokładnie ten sam zakres.

Przed pierwszą próbą należy zapisać wersje Node.js, PostgreSQL, Drizzle i Prisma. Oba PoC używają tej samej wersji PostgreSQL, identycznego modelu logicznego, tego samego zestawu danych wejściowych i tych samych asercji. Czas implementacji nie jest kryterium, jeżeli jeden kandydat był wcześniej znany wykonawcy.

| # | Próba | Co sprawdza |
|---|---|---|
| E2-01 | **Dynamiczne pola w modelu hybrydowym** — rdzeń obiektu w kolumnach, definicje w tabelach, wartości typowane lub JSONB | Czy ORM nie zmusza do obejść przy modelu hybrydowym |
| E2-02 | **Transakcja** obejmująca obiekt, wartości pól, tagi i wpis audytu | Czy transakcje są czytelne i niezawodne |
| E2-03 | **Audit z diff** przy edycji obiektu | Czy da się zbudować bez sięgania po wewnętrzne API ORM |
| E2-04 | **Indeksy FTS** — GIN, `pg_trgm`, `unaccent` | **Ile raw SQL jest konieczne** |
| E2-05 | **Migracja na pustej i wypełnionej bazie**; dla zmiany odwracalnej `up → down → up`, dla nieodwracalnej sprawdzony plan naprawy/odtworzenia | Czy zmiana schematu i odzyskanie po błędzie są bezpieczne |
| E2-06 | `pg_dump`/restore wspólnego zestawu danych, następnie kontrola schematu, historii migracji i uruchomienie tych samych asercji ORM | Czy adapter i migracje pozostają zgodne z odtworzoną bazą; **nie ocenia jakości ORM jako narzędzia backupowego** |
| E2-07 | **Optimistic concurrency** — pole `version`, konflikt zwraca błąd | Czy da się zaimplementować bez obejść |

## 2.2. Kryterium rozstrzygające

Najpierw obowiązują warunki **pass/fail**: poprawne E2-01…E2-07, atomowa transakcja, wykryty konflikt wersji, zgodność schematu/migracji po odtworzeniu PostgreSQL oraz brak importów ORM w domenie. Kandydat niespełniający któregokolwiek warunku odpada. Szybkość, kompresja i ergonomia samego backupu nie wpływają na wynik ORM.

Kandydatów, którzy przeszli warunki blokujące, ocenia się w skali 0–5:

| Wymiar | Waga | Reguła |
|---|---:|---|
| Ekspresyjność PostgreSQL i liczba uzasadnionych obejść/raw SQL | 30% | Mniej nieczytelnych obejść = lepiej; sam raw SQL nie jest wadą, jeżeli jest jawny i przetestowany |
| Bezpieczeństwo i ergonomia migracji | 25% | Liczy się zachowanie na bazie z danymi i ścieżka odzyskania |
| Sprzężenie domeny i testowalność | 20% | Domena nie importuje ORM; adapter persistence jest wymienny |
| Bezpieczeństwo typów | 15% | Błędy schematu i zapytań są wykrywane możliwie wcześnie |
| Diagnostyka i ergonomia pracy | 10% | Czytelne zapytania, błędy, logowanie SQL i utrzymanie |

Wynik to suma `ocena/5 × waga`. Przy remisie wygrywa kandydat o niższym ryzyku migracyjnym; jeżeli nadal jest remis, obowiązuje domyślny kierunek z ADR-014.

Punktacja opisuje dopasowanie techniczne badanego baseline. Jeżeli obaj
kandydaci przejdą wszystkie warunki blokujące, ostateczny ADR może dodatkowo
uwzględnić pominięte wcześniej ryzyko długoterminowego utrzymania upstream,
ale musi zachować pierwotny wynik punktowy i jawnie uzasadnić decyzję
właściciela projektu. Nie wolno po wyniku potajemnie zmieniać wag.

| Kandydat | Zalety | Wady |
|---|---|---|
| **Drizzle** | Blisko SQL, mocne typowanie, mniejsza abstrakcja, dobre dopasowanie do PostgreSQL | Mniej gotowych wzorców, wymaga dyscypliny |
| **Prisma** | Bardzo dobry DX, generowane typy, szybki start | Czasem ogranicza zaawansowany PostgreSQL, raw SQL dla części indeksów |

**MikroORM i TypeORM są odradzane** — ryzyko niejawnych zapytań i sprzężenia domeny z ORM (03 §10).

## 2.3. Zamknięcie E2

- [x] Oba PoC wykonane w **identycznym** zakresie E2-01…E2-07
- [x] Zapisane wersje środowiska, identyczny schemat, dane i asercje
- [x] Wszystkie warunki pass/fail przechodzą albo kandydat jest jawnie odrzucony
- [x] Policzona liczba miejsc wymagających raw SQL/obejścia i opisana ich jakość
- [x] Wypełniona macierz punktowa z uzasadnieniem każdej oceny
- [x] **ADR-014 przeniesiony do `accepted`** z uzasadnieniem opartym na wyniku PoC, **nie na wrażeniach z E1**

---

# 3. E3 — przenośność i disaster recovery

**Rozstrzyga:** strategię wyjścia, ADR-015 i Gate OS-2-LAB · **Zależność:** instancja z danymi E1, jawny fixture Core oraz wymagania E3 z §0.2. Nie zastępuje pełnego restore produktu w M17.

## 3.0. Fixture i reguły porównania

Fixture jest testowym artefaktem laboratorium, nie projektem modelu M4. Zawiera:

- osobną bazę PostgreSQL `core_fixture`,
- rekordy `document_link(external_id, checksum)` wskazujące dokumenty z E1,
- rekordy `asset(path, checksum)` oraz co najmniej dwa pliki w katalogu assetów,
- manifest wersji, liczników i checksum zapisany przed backupem.

Fixture nie zawiera encji Workspace, permissions, relacji ani kodu produkcyjnego.

Restic i Borg nie tworzą same logicznego dumpa PostgreSQL ani nie koordynują spójności aplikacji. Porównanie zachowuje dla obu:

- ten sam źródłowy zestaw danych i manifest,
- ten sam host źródłowy oraz tryb zamrożenia zapisów,
- ten sam poziom izolacji, porównywalną sieć i przepustowość,
- ten sam obraz czystego celu restore i te same kryteria sukcesu.

Backend nie musi być technicznie identyczny. Każdy kandydat jest testowany z realnym planowanym storage; różnica w obsłudze storage jest częścią wyniku. Po każdej próbie cel jest usuwany albo cofany do tego samego czystego snapshotu.

Materiały umożliwiające restore — hasło/klucz repozytorium, passphrase eksportera i niezbędne sekrety — mają dwie działające kopie **out-of-band** i nie istnieją wyłącznie w backupie, do którego są potrzebne.

## 3.1. E3A — przenośność aplikacyjna Paperless

E3A odpowiada na pytanie: **czy kolekcję można przenieść wspieranym interfejsem administracyjnym Paperless?**

| # | Krok | Kryterium |
|---|---|---|
| E3A-01 | Zatrzymanie przyjmowania nowych dokumentów i oczekiwanie na zakończenie aktywnych zadań | Manifest potwierdza stan bez aktywnych operacji |
| E3A-02 | Pełny `document_exporter` 3.0.4 z opcjami potwierdzonymi w E1-17 i kontrolą checksum | Eksport zawiera dane, oryginały, archive files, miniatury i manifest; nie stosuje opcji pomijających dane/pliki |
| E3A-03 | Obliczenie checksum i zapis niezmiennej kopii eksportu przez badanego kandydata | Restic i Borg otrzymują kopię tego samego eksportu |
| E3A-04 | Kontrola integralności repozytorium, przerwanie jednego backupu i bezpieczne wznowienie/powtórzenie | Brak utraty poprzednich poprawnych snapshotów; wynik czytelny |
| E3A-05 | Restore eksportu na czysty cel; uruchomienie pustej instancji **3.0.4 z tym samym digestem**; `document_importer` 3.0.4 | Import nie korzysta z bazy ani wolumenów źródła |
| E3A-06 | Wygenerowanie nowego tokenu API; przebudowa indeksu, jeżeli wymaga jej 3.0.4 | Token z eksportu nie jest wymagany do działania celu |
| E3A-07 | Uruchomienie oficjalnego sanity checkera Paperless | Brak brakujących/uszkodzonych oryginałów, archive files i miniaturek; checksumy poprawne |
| E3A-08 | Walidacja biznesowa: liczniki, metadane, tagi, korespondenci, typy, otwarcie dokumentów i OCR search | Kolekcja jest użyteczna, nie tylko zaimportowana |

Kroki E3A-03…E3A-08 wykonuje się osobno dla Restic i Borg na każdorazowo czystym celu.

## 3.2. E3B — disaster recovery baz i plików

E3B odpowiada na pytanie: **czy po utracie serwera można odtworzyć działający stack z backupu operacyjnego?**

| # | Krok | Kryterium |
|---|---|---|
| E3B-01 | Zablokowanie nowych zapisów; oczekiwanie na zakończenie zadań; zatrzymanie usług zapisujących | Punkt spójności i czas przerwy są zapisane |
| E3B-02 | Logiczny dump PostgreSQL Paperless oraz `core_fixture` | Dumpy kończą się sukcesem i mają zapisane wersje narzędzi |
| E3B-03 | Kopia katalogu mediów Paperless, assetów Core, konfiguracji bez sekretów i manifestu | Nie kopiuje się aktywnych plików bazy danych ani niespójnych wolumenów |
| E3B-04 | Checksum kompletnego, zamrożonego zestawu DR; backup przez badanego kandydata | Kandydaci otrzymują kopię tego samego zestawu |
| E3B-05 | Kontrola integralności; przerwanie jednego backupu; ponowienie; test retencji/prune najpierw w dry-run, a potem na jednorazowej kopii repozytorium | Poprzedni poprawny restore point pozostaje dostępny; liczba snapshotów po retencji jest zgodna z polityką |
| E3B-06 | Restore plików i obu baz na czysty cel; uruchomienie **Paperless 3.0.4 z tym samym digestem** | Cel nie korzysta ze źródłowych wolumenów, baz ani katalogów |
| E3B-07 | Oficjalny sanity checker 3.0.4 oraz kontrole baz | Brak uszkodzeń i brakujących plików; test DR nie uruchamia migracji z 2.x ani do nowszej wersji |
| E3B-08 | Reconciliation fixture Core ↔ Paperless oraz walidacja external IDs | Wszystkie zamierzone powiązania są zgodne albo mają jednoznaczny raport rozjazdu |
| E3B-09 | Walidacja biznesowa: otwarcie dokumentów, OCR search, checksum dokumentów i assetów | Restore kończy się sprawdzeniem danych, nie samym startem kontenerów |
| E3B-10 | Odtworzenie pojedynczego pliku oraz ponowne otwarcie repozytorium z drugiej kopii klucza | Oba scenariusze działają i są opisane w runbooku |

Kroki E3B-04…E3B-10 wykonuje się osobno dla Restic i Borg na każdorazowo czystym celu.

## 3.3. Obowiązkowe kontrole właściwe dla narzędzia

- **Restic:** `check --read-data` dla pełnej kontroli danych repozytorium oraz rzeczywisty restore całego zestawu i pojedynczego pliku.
- **Borg:** kontrola repozytorium zgodna z używaną wersją oraz rzeczywisty `extract` całego zestawu i pojedynczego pliku; `--dry-run` nie zastępuje extract.
- **Oba:** test zachowania po przerwaniu, odczyt z drugiej kopii materiałów odzyskiwania, retencja i prune na jednorazowym repozytorium, czas/RTO, rozmiar, diagnostyka błędów i liczba manualnych kroków.

## 3.4. Kryteria porównania

Warunkiem wejścia do punktacji jest pełne przejście **E3A i E3B** oraz kontroli integralności. Kandydat niespełniający któregokolwiek warunku odpada. Pozostałych ocenia się w skali 0–5:

| Kryterium | Waga | Restic | Borg |
|---|---:|---:|---:|
| Poprawność i powtarzalność E3A + E3B | 35% | | |
| Integralność repozytorium i diagnostyka uszkodzeń | 15% | | |
| Zachowanie po przerwaniu i zachowanie poprawnych restore points | 10% | | |
| Obsługa kluczy i odtworzenie z drugiej kopii | 10% | | |
| Retencja, prune i odtworzenie pojedynczego pliku | 10% | | |
| Dopasowanie do docelowego storage off-host i RTO | 10% | | |
| Prostota, audytowalność i diagnostyka runbooka | 10% | | |

Czas backupu i rozmiar po deduplikacji są pomiarami pomocniczymi; nie przeważają nad poprawnością. Przy remisie wygrywa kandydat lepiej obsługujący faktyczny storage off-host. Brak rozstrzygnięcia pozostawia ADR-015 w statusie `proposed`.

## 3.5. Gate OS-2-LAB

| Kryterium | Status |
|---|---|
| E3A: pełny eksport 3.0.4 z wymuszonym punktem spójności zaimportowano na pustej instancji 3.0.4 z tym samym digestem | ☑ dla obu — punkt spójności wymuszony i udowodniony w powtórzonym przebiegu |
| E3A: nowy token, sanity checker, otwieranie dokumentów i OCR search działają | ☑ dla obu |
| E3B: odtworzono obie bazy, media, assety i konfigurację na czystym celu | ☑ dla obu |
| E3B: sanity checker oraz reconciliation przechodzą | ☑ dla obu |
| External IDs, liczniki i checksumy zgadzają się z manifestem | ☑ dla obu |
| Oba tory wykonano dla Restic i Borg; wybrany kandydat przeszedł wszystkie kryteria blokujące | ☑ dla obu |

**Stan na 2026-07-31: Gate OS-2-LAB zamknięty w zakresie laboratoryjnym.** E3B przeszedł wcześniej, a E3A powtórzono dla Restica i Borga poprawionym harness’em: źródłowy `webserver` był zatrzymany (stan `exited`) przez całe okno eksportu, eksporter działał w jednorazowym kontenerze bez publikowanych portów, a liczba dokumentów przed i po oknie jest identyczna (`9`/`9`). Wszystkie `46` kontroli przebiegu zakończyło się wynikiem OK. Storage pozostaje symulowany na dysku hosta, więc gate potwierdza poprawność procedur laboratoryjnych, **nie gotowość produkcyjną** — pełna walidacja restore produktu jest bramą M17.

## 3.6. Zamknięcie E3

- [x] E3A i E3B wykonane **dla obu kandydatów, do końca**, na każdorazowo czystym celu — E3B kompletne; E3A powtórzony 2026-07-31 z wymuszonym punktem spójności
- [ ] **ADR-015 przeniesiony do `accepted`** — pozostaje `proposed`: kryterium dopasowania do docelowego storage 4 TB nie zostało ocenione, bo dyski nie zostały dostarczone; rekomendacja wstępna to Restic
- [x] Procedury zapisane jako podstawa przyszłego `18-Backup-and-Restore-Runbook.md` — skrypty w `lab/harness/e3/`, wyniki w [`spike-results/08-e3-backup-report.md`](spike-results/08-e3-backup-report.md)

---

# 4. Domknięcie fazy

| # | Krok |
|---|---|
| F1-01 | Spisanie raportu spike'a: wyniki E1, E2, E3A i E3B osobno |
| F1-02 | Macierz zgodności REST — pokrycie 10 operacji `DocumentProvider` i 3 fallbacków |
| F1-03 | Profil zasobowy — weryfikacja lub korekta założenia 8/16 GB RAM |
| F1-04 | Zapisanie **siedmiu artefaktów trwałych** (sekcja 5) |
| F1-05 | Domknięcie **ADR-014** (z E2), **ADR-015** (z E3A/E3B) i **ADR-016** (z OS-3-LAB); zapis potwierdzenia ADR-019 |
| F1-06 | Uzupełnienie **ADR-008** o rozstrzygniętą topologię Valkey |
| F1-07 | Formalna ocena **Gate OS-1**, **Gate OS-2-LAB** i **Gate OS-3-LAB**; zapis, że OS-3-RELEASE pozostaje bramą M22 |

---

# 5. Artefakty trwałe

> **Kod spike'a jest jednorazowy. Jego wyniki nie.**
>
> To, że eksperyment nie staje się kodem produkcyjnym, nie oznacza, że jego rezultaty mają zniknąć. Poniższe siedem artefaktów jest **wejściem dla M4 i M6**, punktem odniesienia przy każdej aktualizacji Paperless (RY-13) oraz bazą do powtórzenia eksperymentu przy zmianie wersji.

| # | Artefakt | Zawartość | Wykorzystanie |
|---|---|---|---|
| 1 | **Manifest plików testowych** | Jakie dokumenty, jakie cechy testują, skąd pochodzą | Powtórzenie eksperymentu; zestaw wejściowy dla pilota (Faza 8) |
| 2 | **Wyniki pomiarów** | RAM idle i peak, CPU OCR, czas OCR, przyrost dysku i mnożnik, rozmiar derivative | Progi alertów (M19), planowanie pojemności, weryfikacja profilu sprzętowego |
| 3 | **Notatki o API wraz ze zredagowanymi odpowiedziami** | Faktyczne struktury odpowiedzi REST; niezredagowane próbki poza Git | **Podstawa do zaprojektowania `DocumentProjection` w M4** i kontraktu w M6 |
| 4 | **Skrypty testujące upload, E3A i E3B** | Kod jednorazowy, ale odtwarzalny; ścieżki portability i DR są rozdzielone | Powtórzenie testu przy aktualizacji Paperless |
| 5 | **Macierz kompatybilności** | Paperless 3.0.4 + digest × 10 operacji REST × fallbacki × konfiguracja × OCR × exporter/importer × E3B | Kontrolowane aktualizacje (RY-13); wejście do compatibility matrix w M11 |
| 6 | **Raport decyzji i bram** | Uzasadnienie ADR-014, ADR-015, ADR-016 i topologii ADR-008; potwierdzenie ADR-019; oceny OS-1, OS-2-LAB i OS-3-LAB wraz z inwentarzem licencji | Warunki ponownej analizy w ADR-ach; dowód zamknięcia M3 |
| 7 | **Konfiguracja do powtórzenia eksperymentu** | Compose, wersje, tagi, digesty, zmienne środowiskowe | Odtworzenie laboratorium w dowolnym momencie |

**Miejsce docelowe:** `spike-results/` (artefakty 1–3, 5–7) oraz izolowany katalog narzędziowy laboratorium (artefakt 4). Dane prywatne i surowe odpowiedzi pozostają poza Git zgodnie ze `spike-data-policy.md`.

**Brak któregokolwiek z siedmiu artefaktów blokuje bramę wyjścia Fazy 1.**

---

# 6. Czego w tej fazie nie robimy

- Nie budujemy monorepo, CI, Caddy ani pipeline'u wdrożeniowego — to M9.
- Nie budujemy `PaperlessAdapter` — to M11, po zamknięciu kontraktu M6.
- Nie projektujemy modelu danych — to M4, **po** tym eksperymencie.
- Nie modyfikujemy kodu ani obrazu Paperless. Baseline zachowuje ustawienia oficjalnego Compose v3.0.4 poza obowiązkowym przypięciem referencji obrazów; pozostałe różnice są jawne w plikach override i wariantów.
- Nie optymalizujemy niczego.
- Nie przekształcamy kodu spike'a w kod produkcyjny.
