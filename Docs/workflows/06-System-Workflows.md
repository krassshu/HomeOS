# 06 — System Workflows and Processing Pipelines

## Procedury, stany, kolejność operacji, błędy i odzyskiwanie

**Wersja:** 0.5

**Status:** `accepted`

**Data:** 2026-07-27

**Zakres:** segregator MVP

> ## Status dokumentu
>
> | Pole | Wartosc |
> |---|---|
> | **Status** | `accepted` |
> | **Priorytet w hierarchii zrodel prawdy** | **Drugi z 7 - nadrzedny** |
> | **Obowiazuje w zakresie** | **wszystko** - kontrakt zachowania systemu: aktorzy, zasady procesowe, model statusu operacji, wszystkie procesy, 14 stanow dokumentu, duplikaty, reconciliation, circuit breaker, rate limiting, audit events, kody bledow, metryki, testy workflow |
> | **Nie obowiazuje w zakresie** | §26 Import masowy i §27 eksport uzytkownika sa kontraktami przyszlymi, poza MVP. §27 nie uprawnia Core do uruchamiania eksportera administracyjnego; granice utrzymaniowa definiuje ADR-019 |
> | **Ostatni przeglad** | 2026-07-28 (audyt gotowosci M3) |
> | **Rejestr rozbieznosci** | [`discrepancy-register.md`](../architecture/discrepancy-register.md) |
>
> Hierarchia zrodel prawdy: **07 dla kolejnosci, 08 dla zakresu, accepted ADR dla decyzji szczegolowych, nastepnie 06 > 05 > 04 > 03 > 02 > 01**.
> Pelne uzasadnienie: [`00-Analiza-i-Mapa-Realizacji.md`](../00-Analiza-i-Mapa-Realizacji.md), sekcja 8.


***

# 1. Cel

Dokument opisuje zachowanie systemu krok po kroku. Definiuje aktorów, komendy, stany, granice transakcji, zadania asynchroniczne, idempotencję, błędy, retry, kompensacje, audyt i kryteria zakończenia.

Nie jest opisem konkretnego kodu. Stanowi kontrakt zachowania, który później ma zostać odwzorowany w API, modelu danych, kolejkach i testach.

***

# 2. Aktorzy i systemy

## Aktorzy

* właściciel Workspace,
* administrator,
* członek,
* członek z ograniczonym dostępem,
* proces systemowy,
* operator infrastruktury.

## Systemy

* Web/PWA,
* Core API,
* Core DB,
* Valkey/BullMQ,
* Core Worker,
* Paperless Adapter,
* Paperless-ngx,
* Gotenberg,
* filesystem kwarantanny,
* backup runner,
* monitoring.

***

# 3. Zasady procesowe

## 3.1. Źródła prawdy

* Core DB — domena,
* Paperless — dokumenty i OCR,
* kolejka — mechanizm wykonawczy,
* audit — historia działań domenowych,
* log techniczny — diagnostyka.

## 3.2. Operacje ciężkie są asynchroniczne

Request HTTP nie oczekuje na OCR, konwersję, eksport, reconciliation ani pełne indeksowanie.

## 3.3. Idempotencja

Każda operacja możliwa do powtórzenia ma:

* `commandId`,
* idempotency key,
* stan w DB,
* kontrolę duplikatu,
* bezpieczny rezultat ponowienia.

## 3.4. Brak transakcji rozproszonej

Core DB i Paperless nie uczestniczą w jednej transakcji. Spójność zapewniają:

* zapis intencji,
* state machine,
* kolejka,
* retry,
* reconciliation,
* kompensacja.

## 3.5. Audit

Audit rejestruje aktora, Workspace, cel, czas UTC, rezultat, błąd, correlation
ID, sesję, urządzenie, rodzaj klienta i transport. Nie zawiera sekretów ani
całych treści dokumentów. Dokładne wartości zwykłych pól należą do historii
obiektu, a wartości wrażliwe są redagowane bez treści i bez skrótu.

***

# 4. Wspólny model statusu operacji

```
requested 
accepted 
queued 
running 
waiting_external 
succeeded 
failed_retryable 
failed_permanent 
cancel_requested 
cancelled 
compensation_required 
compensated
```

Nie każdy proces musi używać wszystkich stanów.

***

# 5. Bootstrap pierwszego użytkownika

## Warunek

System nie ma Workspace ani konta.

## Przebieg

1. UI pyta Core o stan bootstrap.
2. Core zwraca `uninitialized`.
3. Użytkownik podaje imię, nazwisko, e-mail logowania i hasło; utworzenie
   korzenia gospodarstwa może dokończyć po wejściu na pulpit.
4. Core waliduje dane i hasło.
5. W jednej transakcji tworzy Account, Workspace, Membership z rolą `owner`,
   `Person Object`, powiązanie członkostwa z osobą i audit.
6. Tworzy sesję.
7. Core wylicza stan `household_required` z istnienia Workspace i pustego
   `household_object_id`; nie zapisuje osobnej flagi `initialized`.
8. Kolejna próba bootstrap jest odrzucana.

## Błędy

* równoczesne próby — unikalny constraint i blokada,
* błąd transakcji — brak częściowych rekordów,
* słabe hasło — brak zapisu.

## Kryterium sukcesu

Istnieje dokładnie jeden Workspace i jeden właściciel, aktywna sesja działa, a
wyliczony stan onboardingu to `household_required`.

***

# 6. Zaproszenie użytkownika

1. Uprawniony członek wybiera „Zaproś”.
2. Core sprawdza `membership.invite`.
3. Tworzy jednorazowy token z terminem ważności.
4. Invitation otrzymuje status `pending`.
5. Link jest kopiowany lokalnie; e-mail może dojść później.
6. Odbiorca otwiera link.
7. Core sprawdza token, Workspace, datę i status.
8. Odbiorca tworzy konto lub loguje się.
9. Core tworzy Membership.
10. Invitation → `accepted`.
11. Audit.

Stany:

```
pending 
accepted 
expired 
revoked
```

Ponowne użycie tokenu nie tworzy drugiego członkostwa.

***

# 7. Utworzenie obiektu

## Wejście

* nazwa,
* opcjonalny typ lub szablon,
* wartości pól,
* tagi,
* widoczność.

## Przebieg

1. UI pobiera szablony.
2. Użytkownik wybiera szablon lub pusty obiekt.
3. UI wysyła komendę z idempotency key.
4. Core sprawdza `object.create`.
5. Waliduje definicje i wartości pól.
6. W transakcji tworzy Object, wartości, tagi i audit.
7. Zwraca obiekt.

Szablon kopiuje sugestie. Nie tworzy obowiązkowej zależności obiektu od szablonu.

***

# 8. Edycja obiektu

Klient wysyła version lub ETag.

1. Odczytaj aktualną wersję.
2. Sprawdź uprawnienia.
3. Porównaj version.
4. Waliduj zmianę.
5. Zapisz atomowo.
6. Zwiększ version.
7. Zapisz audit diff.
8. Zwróć nowy ETag.

Konflikt daje `409 Conflict`, nie ciche nadpisanie.

***

# 9. Archiwizacja obiektu

1. Sprawdź uprawnienie.
2. Ustaw `archived_at`.
3. Usuń z domyślnych list.
4. Zachowaj relacje, dokumenty i historię.
5. Zawieś przypomnienia zgodnie z polityką.
6. Audit.

Przywrócenie nie musi automatycznie reaktywować przeterminowanych terminów bez decyzji użytkownika.

***

# 10. Kosz obiektu

1. Core analizuje dokumenty, relacje, przypomnienia i obiekty zależne.
2. UI pokazuje skutki.
3. Użytkownik potwierdza.
4. Core ustawia `trashed_at`.
5. Relacje są ukryte, nie niszczone.
6. Aktywne zadania są zawieszane.
7. Audit.

Trwałe usunięcie jest osobnym procesem administratora po okresie retencji.

***

# 11. Główny pipeline uploadu dokumentu

## 11.1. Cele

* plik nie trafia cały do RAM,
* klient szybko dostaje identyfikator,
* OCR działa w tle,
* retry nie tworzy duplikatów,
* awaria Paperless nie niszczy rekordu Core,
* miniatura pozostaje derivative dokumentu.

## 11.2. Faza A — inicjalizacja

1. Użytkownik wybiera plik i obiekt.
2. UI wysyła filename, size, MIME, object IDs, tagi i idempotency key.
3. API sprawdza sesję, permission, limity, wolne miejsce i typ.
4. Core tworzy DocumentRecord `pending_upload`.

> **Uwaga terminologiczna (M0):** `DocumentRecord` z tego dokumentu odpowiada encji **`DocumentReference`**
> w obowiązującym słowniku. Obok niej istnieją `DocumentProjection` (metadane z Paperless)
> i `ObjectDocumentLink` (powiązanie z obiektem). Patrz [`../glossary.md`](../glossary.md) §1.
5. API wydaje upload ID.

## 11.3. Faza B — transmisja

1. Klient streamuje plik.
2. API zapisuje go do kwarantanny.
3. Jednocześnie liczy SHA-256.
4. Kontroluje limit i timeout.
5. Porównuje rozmiar deklarowany z faktycznym.
6. Wykrywa typ po zawartości.
7. Status → `uploaded`.
8. Tworzy job ingestion.

## 11.4. Faza C — walidacja i skan

1. Worker sprawdza, czy job nadal jest potrzebny.
2. Waliduje plik.
3. Opcjonalnie wywołuje ClamAV.
4. Wynik:
   * clean → kontynuacja,
   * infected → `quarantined_security`,
   * scanner unavailable → retry lub fail-closed,
   * invalid → `failed_permanent`.

## 11.5. Faza D — Paperless

1. Worker wywołuje `DocumentProvider.ingest`.
2. Przekazuje minimalne metadane.
3. Zapisuje external task reference.
4. Status → `processing`.
5. Kwarantanna pozostaje do czasu potwierdzenia.

## 11.6. Faza E — oczekiwanie

Worker nie blokuje procesu. Tworzy poll job albo wykorzystuje wspierany mechanizm zdarzeniowy.

## 11.7. Faza F — finalizacja

1. Paperless zwraca document ID.
2. Worker pobiera metadane, checksum i informacje o derivative.
3. Core zapisuje external reference i projection.
4. Powiązania stają się aktywne.
5. Status → `ready`.
6. Audit sukcesu.
7. Cleanup kwarantanny.
8. UI widzi zmianę przez polling lub SSE.

```
sequenceDiagram actor U 
participant UI 
participant API 
participant Q as Quarantine 
participant DB 
participant B as BullMQ participant W 
participant P as Paperless 


U->>UI: wybiera plik 
UI->>API: initialize 
API->>DB: pending_upload 
API-->>UI: uploadId 
UI->>API: stream 
API->>Q: zapis + hash 
API->>DB: uploaded 
API->>B: ingest job 
API-->>UI: accepted 
B->>W: job 
W->>P: ingest 
P-->>W: taskRef 
W->>DB: processing 
W->>P: poll 
P-->>W: documentId 
W->>DB: ready + projection 
W->>Q: cleanup
```

***

# 12. Stany dokumentu

```
pending_upload 
uploading 
uploaded 
validating 
quarantined_security 
queued 
processing 
ready 
failed_retryable 
failed_permanent 
missing_external 
trashed 
delete_pending 
deleted
```

Każda zmiana stanu musi być walidowana przez state machine.

***

# 13. Duplikaty

Poziomy:

* identyczny plik — SHA-256,
* identyczna treść wykryta przez Paperless,
* podobny dokument — sugestia.

Przebieg:

1. Core wykrywa hash.
2. Sprawdza uprawnienia do istniejącego dokumentu.
3. Nie ujawnia istnienia prywatnego dokumentu.
4. Pozwala utworzyć nowe powiązanie albo odrzucić duplikat.
5. Audit.

Automatyczne usuwanie „podobnych” dokumentów jest zakazane.

***

# 14. Dokument Office

1. Standardowy upload.
2. Paperless wybiera parser.
3. Gotenberg/LibreOffice tworzy PDF.
4. Paperless przetwarza tekst/OCR.
5. Oryginał i derivative są zachowane zgodnie z konfiguracją.
6. UI pokazuje oryginał do pobrania i PDF do podglądu.

Błędy:

* format nieobsługiwany,
* uszkodzony dokument,
* timeout,
* brak fontu,
* plik chroniony hasłem.

***

# 15. Miniatura

1. UI żąda thumbnail.
2. Core sprawdza permission.
3. Adapter pobiera derivative z Paperless.
4. Core streamuje.
5. Brak miniatury daje placeholder, nie błąd całej karty.

Miniatura nie jest dodawana do galerii zdjęć.

***

# 16. Podgląd PDF

1. UI żąda preview.
2. Core autoryzuje.
3. Wybiera archive PDF lub original PDF.
4. Obsługuje Range Requests.
5. Streamuje bez pełnego buforowania.
6. PDF.js renderuje strony.
7. Brak bezpośredniego URL Paperless.

Hasła do PDF nie są zapisywane bez osobnej polityki.

***

# 17. Pobranie oryginału

1. Sprawdź `document.download_original`.
2. Zapisz audit dostępu, jeśli wymagany.
3. Pobierz stream z Paperless.
4. Nadaj bezpieczny filename.
5. `Content-Disposition: attachment`.
6. Token sesji nie znajduje się w URL.

***

# 18. Powiązanie dokumentu z obiektem

1. Użytkownik wybiera dokument i obiekt.
2. Core sprawdza dostęp do obu.
3. Waliduje typ relacji.
4. W transakcji tworzy link.
5. Aktualizuje search projection.
6. Audit.

Dokument może być powiązany z wieloma obiektami.

***

# 19. Odpięcie dokumentu

Odpięcie nie usuwa pliku.

1. Usuń lub dezaktywuj link.
2. Jeżeli nie ma linków, dokument trafia do „nieprzypisanych”.
3. Audit.

***

# 20. Synchronizacja tagów i metadanych

Core tagi i Paperless tagi są osobnymi systemami. Wybrane mapowania są jawne.

Zmiana w Core:

1. Zapisz intencję i `sync_pending`.
2. Worker aktualizuje Paperless.
3. Sukces → `synced`.
4. Błąd → retry.
5. Rozjazd → reconciliation/manual review.

***

# 21. Wyszukiwanie globalne

1. UI wysyła tekst, filtry i pagination.
2. Core normalizuje zapytanie.
3. Równolegle:
   * PostgreSQL Core,
   * Paperless API.
4. Wyniki są normalizowane.
5. Core filtruje uprawnienia.
6. Scala ranking.
7. Zwraca listę lub grupy.

Typy wyników:

```
object 
document 
person 
place 
reminder 
tag
```

Awaria Paperless:

* Core zwraca wyniki domenowe,
* odpowiedź ma `partial=true`,
* UI pokazuje komunikat o częściowych wynikach.

System nie może ujawnić tytułu, fragmentu OCR ani istnienia dokumentu bez permission.

***

# 22. Reconciliation

## Cel

Naprawa spójności eventual consistency.

## Kroki

1. Pobierz rekordy wymagające sprawdzenia.
2. Pobierz stan zewnętrzny.
3. Porównaj external ID, checksum, status, tytuł i obecność.
4. Napraw bezpieczne rozbieżności.
5. Niebezpieczne oznacz do ręcznej decyzji.
6. Zapisz raport.
7. Wyślij metryki i alert.

Klasy rozjazdów:

```
core_pending_external_ready 
core_ready_external_missing 
metadata_drift 
checksum_mismatch 
orphan_external 
orphan_core 
duplicate_external_ref
```

***

# 23. Kosz dokumentu

## Etap 1

1. UI pokazuje wszystkie powiązania.
2. Core ustawia `trashed`.
3. Dokument znika z domyślnych widoków.
4. Paperless nie jest jeszcze kasowany.
5. Rozpoczyna się retencja.

## Etap 2 — trwałe usunięcie

1. Administrator zatwierdza.
2. Core zapisuje `delete_pending`.
3. Job usuwa dokument w Paperless.
4. Potwierdza brak.
5. Core zachowuje tombstone i audit.
6. Status → `deleted`.

Jeżeli Paperless usunął dokument, a Core nie zapisał sukcesu, reconciliation finalizuje proces.

***

# 24. Przywrócenie z kosza

1. Sprawdź permission.
2. Ustaw aktywny status.
3. Przywróć widoczność linków.
4. Sprawdź external document.
5. Brak zewnętrznego pliku → `missing_external`.
6. Audit.

***

# 25. Przypomnienie

1. Użytkownik tworzy termin na obiekcie lub dokumencie.
2. Core zapisuje lokalny czas, timezone i politykę.
3. Scheduler wybiera due reminders.
4. Job tworzy notification.
5. UI pokazuje powiadomienie.
6. Acknowledgement, snooze lub complete zapisują audit.

Na MVP powiadomienia mogą być wyłącznie w aplikacji.

***

# 26. Import masowy

1. Administrator tworzy batch.
2. System skanuje manifest/katalog.
3. Waliduje liczbę, rozmiar i miejsce.
4. Tworzy rekordy `planned`.
5. Kolejka pracuje z ograniczoną współbieżnością.
6. Każdy plik przechodzi zwykły pipeline.
7. Batch agreguje success, duplicate, failed i skipped.
8. Powstaje raport.
9. Import można wznowić.

Import nie może omijać walidacji i audytu.

***

# 27. Eksport

> **POZA MVP zgodnie z 08 §3.** Poniższy przepływ opisuje przyszły eksport danych użytkownika, nie backup ani eksport utrzymaniowy Paperless. Core **nie uruchamia** `document_exporter`. Operacje utrzymaniowe wykonuje operator poza aplikacją zgodnie z ADR-019. Przed implementacją eksportu użytkownika wymagany jest osobny kontrakt zakresu, uprawnień, retencji i limitów.

Eksport obejmuje:

* obiekty,
* pola,
* relacje,
* tagi,
* dokumenty,
* metadane,
* mapowania,
* manifest checksum.

Przebieg:

1. Użytkownik składa żądanie.
2. Core tworzy job.
3. Ustala logiczny punkt czasu.
4. Pobiera dane Core.
5. Pobiera wyłącznie dokumenty, do których użytkownik ma uprawnienia, przez aplikacyjny `DocumentProvider`; nie używa eksportera administracyjnego.
6. Buduje manifest.
7. Liczy checksum.
8. Opcjonalnie szyfruje.
9. Udostępnia czasowy download.
10. Cleanup po retencji.

***

# 28. Backup

1. Backup runner uzyskuje lock operacyjny.
2. Zapisuje manifest wersji.
3. Wykonuje dump Core DB.
4. Wykonuje dump Paperless DB.
5. Kopiuje media w spójnym punkcie.
6. Kopiuje konfigurację.
7. Repozytorium backupu szyfruje i deduplikuje.
8. Weryfikuje snapshot.
9. Zapisuje rezultat.
10. Alarmuje przy błędzie.
11. Zwalnia lock.

***

# 29. Pełny restore

1. Ogłoś maintenance.
2. Zabezpiecz bieżący stan.
3. Przygotuj zgodny, czysty stack.
4. Odtwórz konfigurację i oddzielny pakiet sekretów przy użyciu materiałów odzyskiwania przechowywanych out-of-band.
5. Odtwórz media.
6. Odtwórz Paperless DB.
7. Odtwórz Core DB.
8. Uruchom Paperless.
9. Uruchom Core.
10. Wykonaj reconciliation.
11. Sprawdź liczniki.
12. Otwórz próbkę dokumentów.
13. Sprawdź OCR search.
14. Sprawdź checksum.
15. Zamknij incydent.

Restore kończy się po walidacji biznesowej, nie po starcie kontenerów.

***

# 30. Aktualizacja Paperless

1. Przeczytaj release notes.
2. Uruchom contract tests na staging.
3. Wykonaj backup.
4. Zatrzymaj ingestion.
5. Poczekaj na bezpieczne zakończenie jobów.
6. Zaktualizuj przypięty obraz.
7. Uruchom migracje Paperless.
8. Uruchom contract testy REST: auth, upload, status, metadata, thumbnail/fallback, original, preview, search, update metadata, delete i health/fallback.
9. Oddzielnie wykonaj smoke test `document_exporter`/`document_importer` z poziomu operacyjnego.
10. Wznów worker.
11. Reconciliation.
12. Obserwacja.
13. Release record.

***

# 31. Aktualizacja Core

1. CI.
2. Test migracji.
3. Backup.
4. Maintenance/read-only, jeśli potrzebne.
5. Migracja DB.
6. Rollout API.
7. Rollout worker.
8. Rollout web.
9. Smoke tests.
10. Queue health.
11. Reconciliation.
12. Monitoring.

***

# 32. Awaria workera

BullMQ może dostarczyć job ponownie. Worker:

1. odczytuje command ID,
2. sprawdza stan DB,
3. jeżeli sukces już zapisany — no-op,
4. jeżeli istnieje external ref — nie wysyła ponownie bez sprawdzenia,
5. kontynuuje od bezpiecznego kroku,
6. zapisuje heartbeat,
7. po limicie prób ustawia failed state i alert.

***

# 33. Awaria między Paperless a Core

Scenariusz:

* Paperless utworzył dokument,
* worker zmarł przed zapisem external ID.

Ochrona:

* correlation metadata, jeśli API pozwala,
* zapis task reference,
* reconciliation po task reference,
* deduplikacja checksum,
* manual review w sytuacji niejednoznacznej.

***

# 34. Circuit breaker

Stany:

```
closed 
open 
half_open
```

Po serii błędów system:

* nie zalewa Paperless,
* pozostawia joby retryable,
* raportuje degraded state,
* po cooldown wykonuje próbę kontrolną.

***

# 35. Rate limiting

Dotyczy:

* login,
* invitation accept,
* upload init,
* search,
* download,
* admin endpoints.

Musi istnieć bezpieczna procedura odzyskania administratora.

***

# 36. Anulowanie

## Przed wysłaniem do Paperless

* usuń kwarantannę,
* status `cancelled`.

## W trakcie Paperless

* `cancel_requested`,
* próba anulowania, jeśli wspierana,
* ewentualna kompensacja.

## Po sukcesie

To już proces kosza/usunięcia.

***

# 37. Audit events

```
workspace.created 
membership.invited 
membership.accepted 
object.created 
object.updated 
object.archived 
document.upload.requested 
document.upload.completed 
document.processing.failed 
document.linked 
document.downloaded 
document.trashed 
document.deleted 
backup.completed 
restore.completed 
integration.reconciled
sensitive_value.revealed
sensitive_value.access_granted
sensitive_value.access_revoked
```

Pierwsze 16 pozycji stanowi bazowy audit domenowy. Trzy zdarzenia
`sensitive_value.*` są obowiązkowym audytem bezpieczeństwa wynikającym z
ochrony konkretnego `FieldValue`; nie zawierają jego treści ani skrótu.
Jest to katalog minimalny rozszerzany jawnie wraz z modelowaniem pozostałych
procesów, między innymi blokady i usunięcia konta.

Audit zawiera actor, workspace, target, timestamp, correlation, result, sesję,
urządzenie, klienta (`web` / `mobile` / `desktop`), transport (`lan` /
`wireguard`) oraz źródło zaobserwowane przez zaufany gateway.

Audit jest trwały, lecz nie przechowuje pełnej kopii stanu domeny. Historia
obiektu zachowuje dokładne zwykłe wartości do trwałego usunięcia. Dla wartości
wrażliwych zapisuje się wyłącznie rodzaj operacji. Po permanent delete zostaje
struktura zdarzeń i tombstone, bez treści usuniętych wartości.

***

# 38. Kody błędów domenowych

```
UPLOAD_TOO_LARGE 
UNSUPPORTED_FILE_TYPE 
FILE_CORRUPTED 
DUPLICATE_DOCUMENT 
MALWARE_DETECTED 
DOCUMENT_PROVIDER_UNAVAILABLE 
DOCUMENT_PROCESSING_TIMEOUT 
DOCUMENT_NOT_FOUND_EXTERNAL 
SEARCH_PARTIAL 
VERSION_CONFLICT 
INSUFFICIENT_PERMISSION 
STORAGE_LOW 
BACKUP_STALE
```

UI nie pokazuje surowych wyjątków.

***

# 39. Metryki

* upload bytes i duration,
* queue wait,
* ingestion duration,
* OCR duration,
* failure rate,
* retries,
* reconciliation drift,
* duplicate rate,
* thumbnail latency,
* Core search latency,
* Paperless search latency,
* backup age,
* restore duration.

***

# 40. Testy workflow

## Happy path

* PDF tekstowy,
* skan,
* DOCX,
* duży PDF,
* polskie znaki,
* wiele powiązań.

## Błędy

* Paperless down,
* Valkey down,
* DB down,
* brak miejsca,
* zerwane połączenie,
* restart workera,
* timeout Gotenberg,
* uszkodzony PDF,
* duplicate,
* brak permission,
* konflikt edycji.

## Recovery

* retry,
* restart,
* reconciliation,
* restore,
* ponowny upload z tym samym idempotency key.

***

# 41. Minimalne procesy MVP

1. bootstrap,
2. login,
3. create object,
4. edit object,
5. upload PDF,
6. status processing,
7. thumbnail,
8. preview,
9. link/unlink,
10. global search,
11. trash/restore,
12. permanent delete admin,
13. reconciliation,
14. backup,
15. full restore.

***

# 42. Checklist workflow przed kodem

Każdy proces musi mieć:

* właściciela danych,
* diagram,
* statusy,
* uprawnienia,
* audit,
* timeout,
* retry,
* idempotencję,
* kryterium sukcesu,
* błąd permanentny,
* recovery,
* test E2E.

***

# 43. Decyzja końcowa

Najważniejszy pionowy przepływ:

```
obiekt 
→ upload 
→ kwarantanna 
→ kolejka 
→ Paperless 
→ OCR 
→ projekcja Core 
→ powiązanie 
→ podgląd 
→ wyszukiwanie 
→ backup 
→ restore
```

Dopóki nie działa niezawodnie i nie przechodzi pełnego restore, nie należy dodawać dużych modułów platformy.
