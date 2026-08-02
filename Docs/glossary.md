# Glossary — słownik pojęć domenowych

**Status:** `accepted` · **Milestone:** M0 · **Data:** 2026-07-27

> To jest **jedyne miejsce definiujące pojęcia domenowe**. Kod, API, dokumentacja i rozmowy używają tych nazw. Nowe pojęcie trafia najpierw tutaj, potem do kodu.

---

## 1. Rozstrzygnięte kolizje terminologiczne

Cztery pojęcia były używane niejednoznacznie w dokumentach 01–07. Rozstrzygnięcia poniżej są wiążące.

| Kolizja | Rozstrzygnięcie |
|---|---|
| `DocumentRecord` (06 §11.2) vs `DocumentReference` / `DocumentProjection` (07 §9) | Trzy odrębne pojęcia: **`DocumentReference`** (tożsamość i stan w Core), **`DocumentProjection`** (skopiowane metadane z Paperless), **`ObjectDocumentLink`** (powiązanie z obiektem). `DocumentRecord` z 06 = `DocumentReference`. Nazwy `DocumentRecord` **nie używamy**. |
| `Asset` vs `plik` vs `dokument` (01 §16, 02 §17 vs 05 §28) | **`Document`** = zasób w pipeline Paperless (OCR, preview, search). **`Asset`** = zasób Core poza pipeline'em (avatar, zdjęcie obiektu, ikona, eksport). Nie są wymienne. |
| Tagi Core vs tagi Paperless (01 §18, 02 §19 vs 03 §14, 06 §20) | **Dwa osobne systemy** z jawnym, wybiórczym mapowaniem. Nie utożsamiamy ich. Użytkownik widzi wyłącznie tagi Core. |
| „Document Gateway" (03 §4, §13.1) vs `DocumentProvider` + `PaperlessAdapter` (05, 06, 07) | Obowiązuje **`DocumentProvider`** (port) i **`PaperlessAdapter`** (implementacja). „Document Gateway" to **alias historyczny tej samej odpowiedzialności**, nie osobny komponent. Nazwy **nie używamy**. |
| „Faza" z 01 §32 vs „Milestone" z 07 | Obowiązuje numeracja **M0–M22** z 07 oraz numeracja **Faza 0–8** z `00-Analiza-i-Mapa-Realizacji.md`, z jawnym mapowaniem w §9.2 tego dokumentu. |

---

## 2. Pojęcia domenowe

| Pojęcie | Definicja | Właściciel danych | Źródło |
|---|---|---|---|
| **Workspace** | Techniczny właściciel danych jednego gospodarstwa domowego. Jedna instalacja i baza mają dokładnie jeden Workspace; granicą bezpieczeństwa jest instalacja, nie filtr tenantów. `workspace_id` nadaje serwer jako relację strukturalną, a klient go nie wybiera. | Core | 10 §M4-D02 |
| **Account** | Techniczna tożsamość z UUIDv7, znormalizowanym e-mailem logowania, hashem Argon2id i statusem `active` / `blocked` / `deletion_pending` / `deleted`. Nie przechowuje danych osoby ani roli. Po pełnym usunięciu pozostaje bezosobowy tombstone bez e-maila i credentialu. | Core | 01 §10.1, 10 §M4-D14, §M4-D20 |
| **Person Object** (obiekt osoby) | Obiekt kategorii `person` i źródło prawdy dla danych człowieka. Może istnieć bez konta. W jednym Workspace osoba ma najwyżej jedno aktywne konto; pełne usunięcie może nastąpić razem z kontem po manifeście zależności i potrójnym potwierdzeniu. | Core | 01 §10.2, 02 §4, 10 §M4-D14 |
| **PersonProfile** | Opcjonalne rozszerzenie 1:1 `Person Object`, bez osobnego ID i lifecycle. Przechowuje strukturalne imię, drugie imiona, nazwisko i nazwę preferowaną. Pozostałe dane osoby należą do typowanych `FieldValue`, a adres do relacji z `Place Object`. | Core | 10 §M4-D21 |
| **Membership** | Kontrolowany łącznik konta, singletonu Workspace i `Person Object`. Określa status, rolę, wyjątki uprawnień, datę dołączenia i zapraszającego. Konto łączy się z dokładnie jedną osobą w instalacji. | Core | 01 §10.3, 10 §M4-D14–D15 |
| **Role** | Systemowy rekord będący pakietem domyślnych uprawnień członkostwa: `owner`, `admin`, `member`, `restricted_member` albo `guest`. Role MVP są dostarczane migracją i nie są edytowalne przez API. Nie dają automatycznego dostępu do prywatnych obiektów ani wrażliwych wartości. | Core | 10 §M4-D15–D16 |
| **Permission** | Systemowy rekord pojedynczej dozwolonej czynności. Efektywny wynik łączy `RolePermission`, wyjątki członkostwa i osobne granty zasobów; jawne `deny` ma pierwszeństwo. | Core | 10 §M4-D15–D16 |
| **Invitation** | Jednorazowy token z terminem ważności. Cykl: `pending → accepted / expired / revoked`. Ponowne użycie tokenu nie tworzy drugiego członkostwa. | Core | 06 §6 |
| **Object** | Uniwersalny rekord reprezentujący cokolwiek, o czym użytkownik chce przechowywać wiedzę. **Wymagana wyłącznie nazwa.** Posiada `version` dla optimistic concurrency. | Core | 01 §4, 02 §2 |
| **Household Object** (obiekt gospodarstwa) | Widoczny korzeń HomeOS reprezentujący gospodarstwo domowe, nie nieruchomość. Wskazuje go `Workspace.household_object_id`. Pozostaje stabilny przy przeprowadzce; zwykła operacja nie może go archiwizować ani usuwać. | Core | 10 §M4-D03–D04 |
| **Place Object** (obiekt miejsca) | Fizyczny dom, mieszkanie, działka albo lokal. Gospodarstwo może mieszkać w wielu miejscach, posiadać je, najmować, wynajmować komuś, używać sezonowo albo nimi zarządzać; każde znaczenie jest osobną relacją. | Core | 02 §4, 10 §M4-D04 |
| **Category** | Kategoria systemowa obiektu: `person`, `animal`, `place`, `vehicle`, `device`, `service`, `organization`, `document_record`, `project`, `generic`. Służy do filtrowania, ikony, widoku i sugestii — **nie ogranicza pól**. | Core | 02 §5 |
| **Type** (`type_name`) | Nazwa użytkowa typu obiektu (Samochód, Lekarz rodzinny, Polisa). Użytkownik może wpisać własną. **Zmiana typu nie usuwa pól.** | Core | 02 §6 |
| **FieldDefinition** | Definicja opcjonalnego pola dynamicznego: etykieta, klucz techniczny, typ danych, sekcja, kolejność, rola (`suggested`, `identity_strong`, `identity_supporting`), wielowartościowość, walidacja, `searchable` i prezentacja. Sama definicja nie czyni pola warunkiem istnienia obiektu ani nie nadaje globalnej wrażliwości jego wartościom. | Core | 02 §8–§9, 10 §M4-D10, §M4-D12 |
| **FieldValue** | Konkretna wartość pola wraz ze źródłem (`user` / `import` / `integration` / `OCR` / `AI` / `system`), poziomem pewności, statusem zatwierdzenia i ochroną `normal` / `sensitive`. Wrażliwość oraz dostęp dotyczą tej wartości, nie całej definicji pola. | Core | 02 §10, §22, 10 §M4-D12 |
| **Sensitive FieldValue** (wartość wrażliwa) | Wartość domyślnie zamaskowana, z własnymi prawami odczytu, edycji i zarządzania dostępem. Nie trafia do zwykłego indeksu ani jawnej treści logów, błędów, powiadomień i audytu. Rola administratora ani relacja rodzinna nie nadaje automatycznie odczytu. | Core | 02 §22, 10 §M4-D12 |
| **Identity discriminator** (pole identyfikujące/rozróżniające) | Pole albo zestaw pól używany do odróżnienia egzemplarzy obiektu. Silny identyfikator, np. VIN lub numer seryjny, może samodzielnie odrzucić duplikat; słabsze dane, np. producent, model i lokalizacja, są oceniane łącznie. Nie jest tym samym co niezmienny `Object.id`. | Core | 08 §S-04, 10 §M4-D08 |
| **Field Library** (biblioteka pól) | Zbiór definicji pól Workspace zapobiegający duplikatom („Numer seryjny", „nr seryjny", „S/N"). System sugeruje istniejące pole, **nie blokując** decyzji użytkownika. | Core | 02 §11 |
| **Section** | Grupa pól w widoku obiektu (Podstawowe, Dane techniczne, Zakup i gwarancja, Kontakt, Zdrowie, Dokumenty, Notatki). | Core | 02 §12 |
| **Template** | Zestaw ustawień startowych: kategoria, ikona, pola, sekcje, sugerowane tagi, relacje i terminy. **Szablon miękki** — kopiuje sugestie i nie tworzy trwałej zależności obiektu od szablonu. Zmiana szablonu nie modyfikuje istniejących obiektów bez decyzji użytkownika. | Core | 02 §13 |
| **ClassificationSuggestion** | Niewiążąca propozycja kategorii, typu, szablonu i początkowych wartości. W MVP powstaje lokalnie z jawnych reguł i słowników; użytkownik zawsze ją zatwierdza lub zmienia. Przyszłe AI może dostarczać sugestie przez tę samą granicę, ale nie jest źródłem prawdy. | Core | 08 §S-06, 10 §M4-D09 |
| **Relation** | Połączenie dwóch obiektów: źródło, typ, cel, nazwa odwrotna, okres obowiązywania, status, notatka. **Zapisywana raz, prezentowana z obu stron.** Usunięcie relacji nie usuwa obiektów. | Core | 01 §17, 02 §18 |
| **Tag** (Core) | Lekki mechanizm organizacji należący do Workspace. Porównywanie bez uwzględniania wielkości liter, możliwość scalania i zmiany nazwy. **Nie jest tym samym co tag Paperless.** | Core | 02 §19 |
| **Tag** (Paperless) | Tag wewnętrznego modelu Paperless. Widoczny wyłącznie przez API Paperless. Mapowany na tagi Core **wybiórczo i jawnie** (np. `samochód` ↔ `ctx:vehicle`). | Paperless | 03 §14, 06 §20 |
| **Document** | Zasób przechodzący przez pipeline Paperless: oryginał binarny, archiwalny PDF, OCR, miniatura, indeks treści. **Binaria i treść należą do Paperless; kontekst i znaczenie do Core.** | Paperless (binaria) / Core (kontekst) | 03 §12, 05 §28 |
| **DocumentReference** | Rekord Core reprezentujący tożsamość i stan dokumentu, zawierający **stabilny identyfikator zewnętrzny** (external ID) oraz stan z 14-stanowej maszyny. | Core | 07 §9 |
| **DocumentProjection** | Skopiowane do Core metadane z Paperless (tytuł, typ, korespondent, checksum, daty) umożliwiające działanie Core przy niedostępnym Paperless. **Nie jest źródłem prawdy** — jest projekcją. | Core | 03 §13, 07 §9 |
| **ObjectDocumentLink** | Powiązanie dokumentu z obiektem. Relacja wiele-do-wielu: jeden dokument może być powiązany z wieloma obiektami. **Odpięcie nie usuwa pliku** używanego gdzie indziej. | Core | 06 §18–§19 |
| **Unassigned** (nieprzypisany) | Dokument bez aktywnych powiązań z obiektami. Widoczny na dedykowanej liście — **nigdy nie znika z systemu**. | Core | 02 §17.4, 06 §19 |
| **Asset** | Zasób Core **poza** pipeline'em dokumentowym: avatar, zdjęcie obiektu, ikona, eksport. Obsługiwany przez `ObjectStorageProvider` na lokalnym filesystemie. | Core | 03 §20, 05 §18 |
| **Reminder** | Termin na obiekcie lub dokumencie: data, timezone, wyprzedzenie, odbiorcy, powtarzalność, kanał, status (`zaplanowane` / `wysłane` / `odroczone` / `wykonane` / `anulowane`). W MVP: jednokrotny, snooze, complete, in-app. | Core | 01 §19, 02 §21, 07 §21 |
| **AuditEvent** | Trwałe zdarzenie domenowe: actor, workspace, target, timestamp UTC, correlation ID, result, sesja, urządzenie, klient i transport. Przechowuje strukturę działania, nie pełną kopię wartości. Sekrety i wartości wrażliwe są redagowane; dokładna historia zwykłej treści wygasa przy permanent delete. Audit domenowy nie może być wyłącznie logiem Docker. | Core | 06 §37, 10 §M4-D13 |
| **Archive** (archiwizacja) | `archived_at`. Zachowuje historię, pliki i relacje; ukrywa z domyślnych list; pozwala przywrócić. **Domyślna operacja dla rzeczy, które przestały być aktualne** — ważniejsza niż usunięcie. | Core | 01 §20.1, 02 §25 |
| **Trash** (kosz) | `trashed_at`. Etap przed trwałym usunięciem: retencja, podgląd zależności przed potwierdzeniem, relacje ukryte a nie niszczone, zawieszenie aktywnych zadań. | Core | 01 §20.2, 06 §10, §23 |
| **Permanent delete** | Trwałe usunięcie po okresie retencji, zatwierdzane przez administratora. Przebieg: `delete_pending` → job usuwający w Paperless → potwierdzenie braku → **tombstone i audit** → `deleted`. | Core + Paperless | 06 §23 |
| **Tombstone** | Rekord Core pozostający po trwale usuniętym dokumencie, umożliwiający audyt i reconciliation. | Core | 06 §23 |
| **Integration** / **IntegrationTask** / **integration_links** | Encje rezerwujące miejsce w modelu pod przyszłe integracje (provider, external_device_id, external_entity_ids, status, ostatnia synchronizacja, mapowanie funkcji). **W MVP wyłącznie schemat, bez implementacji funkcji.** | Core | 02 §34, 07 §9 |

---

## 3. Pojęcia techniczne i integracyjne

| Pojęcie | Definicja | Źródło |
|---|---|---|
| **DocumentProvider** | Port aplikacyjny Core opisujący 10 operacji REST: `ingest`, task status, metadata, original stream, preview stream, thumbnail, search, update mapped metadata, trash/delete, health. **Nie zawiera eksportu/importu. Definiowany przed adapterem** (M6 przed M11). | 03 §8, 05 §2.4, 07 §11, ADR-019 |
| **PaperlessAdapter** | Jedyna produkcyjna implementacja portu `DocumentProvider`. **Jedyne miejsce w systemie znające typy i URL-e Paperless.** | 07 §16 |
| **FakeDocumentProvider** | Implementacja portu na potrzeby testów i pracy równoległej nad pipeline'em uploadu. | 07 §16 |
| **Interfejs utrzymaniowy Paperless** | Oficjalne polecenia `document_exporter` i `document_importer` oraz procedury dump/backup/restore wykonywane przez operatora poza Core. Nie jest częścią `DocumentProvider`. | ADR-019 |
| **Quarantine** (kwarantanna) | Katalog tymczasowy, do którego streamowany jest plik przed przekazaniem do Paperless. Losowa nazwa wewnętrzna, oryginalna nazwa jako metadana, limit, retencja, brak wykonywania plików, **cleanup dopiero po potwierdzeniu**. | 04 §20, 06 §11.3 |
| **Reconciliation** | Okresowa naprawa spójności eventual consistency między Core a Paperless. Siedem klas rozjazdów: `core_pending_external_ready`, `core_ready_external_missing`, `metadata_drift`, `checksum_mismatch`, `orphan_external`, `orphan_core`, `duplicate_external_ref`. | 06 §22 |
| **Circuit breaker** | Mechanizm ochronny adaptera. Stany: `closed` / `open` / `half_open`. Po serii błędów system nie zalewa Paperless, pozostawia joby retryable i raportuje stan zdegradowany. | 06 §34 |
| **Idempotency key** / **commandId** | Klucze zapewniające, że powtórzenie operacji nie tworzy duplikatu. Worker odczytuje stan z DB przed działaniem; sukces zapisany → no-op. | 06 §3.3, §32 |
| **UUIDv7** | Standard identyfikatora trwałych encji Core, generowany przez PostgreSQL 18. Jest globalnie unikalny i uporządkowany czasowo, ale nie jest sekretem ani dowodem uprawnienia. Zewnętrzne identyfikatory integracji pozostają w osobnych polach. | 10 §M4-D18 |
| **Partial result** (`partial=true`) | Flaga odpowiedzi wyszukiwania oznaczająca, że jedno ze źródeł (zwykle Paperless) było niedostępne. UI pokazuje komunikat o częściowych wynikach — **nie pustą listę i nie błąd**. | 06 §21 |
| **Degraded mode** (tryb zdegradowany) | Stan, w którym awaria komponentu pomocniczego nie unieruchamia Core. Paperless niedostępny → działa logowanie, obiekty, relacje, tagi, projekcje i historia. | 04 §22 |
| **Gate OS-1 … OS-4** | Bramy oceny komponentu open source: **OS-1** API, **OS-2-LAB** restore laboratorium w M3, **OS-2** pełny restore produktu w M17, **OS-3-LAB** inwentarz licencji laboratorium w M3, **OS-3-RELEASE** pełna zgodność wydania w M22, **OS-4** wymienność. Brak eksportu, backupu lub akceptowalnej licencji **dyskwalifikuje komponent** niezależnie od punktacji. | 05 §29, §25 |
| **E1 / E2 / E3A / E3B** | Niezależnie oceniane tory Fazy 1: **E1** Paperless/Gotenberg/Valkey, **E2** PoC ORM, **E3A** przenośność exporter/importer, **E3B** disaster recovery baz i plików. Rozstrzygają odpowiednio Gate OS-1/topologię ADR-008, ADR-014 oraz wspólnie ADR-015/Gate OS-2-LAB. | `operations/spike-plan.md` |
| **G1 … G6** | Grupy decyzji blokujących, przypisane do bram: **G1** przed M3, **G2** przed M9, **G3** przed M10, **G4** przed M12, **G5** przed M13/M14, **G6** przed M17. | `00-Analiza-i-Mapa-Realizacji.md` §15 |

---

## 4. Pojęcia, których nie używamy

| Nazwa | Dlaczego | Zamiast tego |
|---|---|---|
| **Redis** | Zastąpiony przez Valkey (R-01, ADR-008) | `Valkey` |
| **Document Gateway** | Alias historyczny (R-17) | `DocumentProvider` + `PaperlessAdapter` |
| **DocumentRecord** | Niejednoznaczne (06 vs 07) | `DocumentReference` |
| **Plik** jako synonim dokumentu | Zaciera granicę Core/Paperless | `Document` albo `Asset` — zależnie od tego, o co chodzi |
| **Magazyn plików** jako komponent Core | Zastąpiony (R-02) | Paperless (binaria) + `ObjectStorageProvider` (assety Core) |
| **Wyszukiwarka** jako osobna usługa | Zastąpiona (R-08) | PostgreSQL FTS (Core) + Paperless search (dokumenty) |
| **Spike** w liczbie pojedynczej dla całej Fazy 1 | Sugeruje jeden eksperyment | `E1`, `E2`, `E3A`, `E3B` — niezależnie oceniane tory |

---

## 5. Zasada rozstrzygania nowych kolizji

1. Nowe pojęcie trafia **najpierw do tego dokumentu**, potem do kodu.
2. Kolizja terminologiczna między dokumentami jest **rozstrzygana tutaj**, a rozbieżność merytoryczna — w `architecture/discrepancy-register.md`.
3. Nazwa użyta w API i w kodzie musi odpowiadać nazwie z tego słownika.
4. Nazwa widoczna dla użytkownika **nigdy nie ujawnia komponentów wewnętrznych** — użytkownik nie widzi słów „Paperless" ani „Gotenberg" (07 §20).
