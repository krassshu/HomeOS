# 08 — MVP Scope

## Zamrożony zakres pierwszej wersji domowego segregatora

**Wersja:** 1.9 · **Status:** `accepted` · **Milestone:** M1 · **Data:** 2026-08-01

**Zmiana 1.9:** jedna instalacja posiada dokładnie jeden Workspace. Jest on
technicznym właścicielem danych nadawanym przez serwer, a nie wybieranym
kontekstem ani warunkiem autoryzacji. Utrwalono też role i reguły ownera.

**Podstawa:** `07-Product-and-Delivery-Roadmap.md` §2, §6 · **Nadrzędny wobec:** wszystkich decyzji zakresowych

---

# 1. Zasada zamrożenia

> **Nowa funkcja w czasie MVP musi zastąpić inną albo trafić do deferred list.**

Zakres poniżej jest zamknięty. Nie rozszerza się go „przy okazji", nie dodaje się funkcji odkrytych w trakcie implementacji i nie przenosi się pozycji z sekcji 3 do sekcji 2 bez świadomej wymiany.

Każde zadanie wchodzące do developmentu musi spełniać **Definition of Ready** (07 §31) i przynależeć do zakresu z sekcji 2.

---

# 2. Zakres MVP — co wchodzi

Osiemnaście pozycji. Każda ma user story, kryteria akceptacji i przypisany milestone.

## 2.1. Fundament tożsamości i przestrzeni

### S-01. Bootstrap pierwszego użytkownika · M10

**Jako** osoba instalująca system **chcę** utworzyć pierwsze konto **żeby** wejść do aplikacji i dokończyć konfigurację domu.

**Kryteria akceptacji:**
- System przed inicjalizacją zwraca stan `uninitialized`.
- Utworzenie konta, Workspace, członkostwa z rolą `owner` i wpisu audytu następuje **w jednej transakcji**.
- Po bootstrapie stan jest wyliczany jako `household_required`; nie istnieje
  mutowalne pole statusu onboardingu.
- Stan zmienia się na `completed` wyłącznie wtedy, gdy istnieje dokładnie jeden
  aktywny `Household Object` wskazany przez `Workspace.household_object_id`.
- Równoczesne lub ponowione utworzenie gospodarstwa nie tworzy dwóch korzeni.
- Po inicjalizacji kolejna próba bootstrapu jest odrzucana.
- Równoczesne próby bootstrapu nie tworzą dwóch Workspace'ów (unikalny constraint + blokada).
- Błąd transakcji nie pozostawia częściowych rekordów.
- Słabe hasło nie jest zapisywane.
- **Kryterium sukcesu:** istnieje dokładnie jeden Workspace i jeden właściciel,
  a wyliczony stan to `household_required`.

### S-02. Konta i zaproszenia · M10

**Jako** domownik z uprawnieniem **chcę** zaprosić członka rodziny **żeby** miał własne konto.

**Kryteria akceptacji:**
- Zaproszenie wymaga uprawnienia `membership.invite`.
- Token jest jednorazowy i ma termin ważności.
- Link jest kopiowany lokalnie; e-mail nie jest wymagany w MVP.
- Cykl statusów: `pending → accepted / expired / revoked`.
- **Ponowne użycie tokenu nie tworzy drugiego członkostwa.**
- Administrator może odebrać uprawnienie do zapraszania.
- Role MVP to `owner`, `admin`, `member`, `restricted_member` i `guest`;
  wyjątek `deny` członkostwa ma pierwszeństwo przed `allow`.
- Role i katalog uprawnień są systemowymi rekordami dostarczanymi migracją;
  API MVP nie pozwala tworzyć, edytować ani usuwać własnych ról.
- Wyjątki członkostwa oraz granty prywatnych obiektów i wrażliwych wartości są
  zapisane w osobnych, audytowanych tabelach z kluczami obcymi, nie w JSONB.
- Instalacja może mieć wielu ownerów, ale nie można zdegradować, zawiesić ani
  usunąć ostatniego aktywnego ownera. Rolę `owner` zmienia wyłącznie inny
  owner po ponownym uwierzytelnieniu.
- Konto jest łączone ze wskazanym istniejącym `Person Object` albo atomowo
  tworzy nową osobę; nie powstaje duplikat osoby.
- Strukturalne imię i nazwisko znajdują się w `PersonProfile`; pozostałe dane
  osobowe są typowanymi `FieldValue` i mogą być chronione pojedynczo.
- Adres osoby jest relacją historyczną do `Place Object`, a nie tekstową kopią
  w profilu. Wiele osób może wskazywać to samo miejsce.
- `Account` zawiera wyłącznie znormalizowany e-mail logowania, credential,
  status i techniczne znaczniki czasu; nie zawiera danych osoby ani roli.
- Lifecycle konta to `active <-> blocked -> deletion_pending -> deleted`.
  Ostatni stan jest nieodwracalnym tombstone bez e-maila i hasha hasła.
- Blokada konta odcina sesje, urządzenia i peer WireGuard, ale nie usuwa osoby.
- Sesje są server-side: PostgreSQL przechowuje hash nieprzezroczystego tokenu
  i stan sesji, a Valkey może być wyłącznie cache. JWT i refresh tokeny nie są
  używane w MVP.
- Web używa host-only cookie `HttpOnly`, `Secure`, `SameSite` z ochroną CSRF;
  token nigdy nie trafia do URL ani pamięci dostępnej dla JavaScript.
- Użytkownik widzi swoje sesje i może natychmiast unieważnić wybrane urządzenie
  albo wszystkie pozostałe sesje.
- Usunięcie dostępu domyślnie zachowuje osobę. Pełne usunięcie konta i osoby
  jest osobnym procesem z manifestem zależności, retencją, ponownym
  uwierzytelnieniem i ochroną dokumentów współdzielonych.
- Ostatni aktywny owner musi najpierw przekazać własność albo uruchomić osobną procedurę
  likwidacji Workspace.
- Każda operacja zapisuje audit.

### S-03. Single Workspace UI · M10

**Jako** użytkownik **chcę** widzieć jeden dom **żeby** nie zajmować się pojęciem przestrzeni roboczych.

**Kryteria akceptacji:**
- UI nie zawiera przełącznika Workspace'ów.
- Instalacja i jej baza posiadają dokładnie jeden Workspace, wymuszony
  ograniczeniem singleton podczas bootstrapu.
- Model techniczny posiada `workspace_id` jako relację własności encji
  domenowych; wartość nadaje serwer i klient nie przekazuje jej w zwykłych
  komendach ani filtrach.
- Autoryzacja nie sprawdza „bieżącego Workspace” i zapytania nie wykonują
  filtracji tenantów, ponieważ drugi Workspace nie może istnieć w tej bazie.
- Kilka domów dodanych kiedyś w aplikacji klienckiej oznacza profile połączeń
  do niezależnych instalacji, a nie Workspace'y współdzielące bazę.

## 2.2. Object Engine

### S-04. Obiekty · M10

**Jako** użytkownik **chcę** utworzyć dowolny obiekt **żeby** opisać rzecz, osobę, miejsce lub usługę.

**Kryteria akceptacji:**
- Obiekt można utworzyć **podając wyłącznie nazwę**, jeżeli nie pozostawia to nierozstrzygniętego konfliktu z istniejącym obiektem.
- Kategoria i typ są opcjonalne; **zmiana typu nie usuwa pól**.
- Ten sam znormalizowany silny identyfikator egzemplarza, np. VIN albo numer seryjny, **odrzuca utworzenie** i wskazuje istniejący obiekt.
- Ta sama znormalizowana nazwa bez wiarygodnej informacji rozróżniającej zatrzymuje zapis; użytkownik otwiera istniejący obiekt albo uzupełnia nowy.
- Ta sama nazwa jest dozwolona, jeżeli pola identyfikujące lub rozróżniające wiarygodnie wskazują inny egzemplarz. Różnica wyłącznie w opisie nie wystarcza.
- Każdy obiekt ma niezmienny identyfikator wewnętrzny; dokumenty i relacje są wiązane przez identyfikator, nie przez nazwę.
- Edycja używa `version`; konflikt zwraca `409 Conflict`, **nie ciche nadpisanie**.
- Historia zmian jest domyślna.

### S-05. Dynamiczne pola · M10

**Jako** użytkownik **chcę** dodać własne pole **żeby** opisać obiekt po swojemu, bez zmiany kodu.

**Kryteria akceptacji:**
- Obsługiwanych 16 typów pól z 02 §8.2.
- Pole można dodać z poziomu widoku obiektu, bez przechodzenia do administracji.
- Biblioteka pól Workspace **sugeruje** istniejące pole przy podobnej etykiecie, nie blokując decyzji.
- Dynamiczne pola są opcjonalne dla istnienia obiektu; walidacja działa po podaniu wartości. Pole identyfikujące może być wymagane wyłącznie do rozstrzygnięcia konkretnego konfliktu duplikatu.
- Typy UI `relation` i `file` korzystają z osobnych encji `Relation`, `ObjectDocumentLink` lub `Asset`; nie zapisują powiązań ani binariów jako `FieldValue`.
- `sensitive` oznacza konkretny `FieldValue`, nie globalną `FieldDefinition`.
  Wartość jest maskowana, ma własne granty i nie trafia do zwykłego indeksu;
  szablon może tylko zasugerować ochronę nowej wartości.
- Walidacja zwraca błąd przypisany do pola, bez utraty wprowadzonych danych.

### S-06. Szablony · M10

**Jako** użytkownik **chcę** wybrać gotowy szablon **żeby** szybciej opisać typowy obiekt.

**Kryteria akceptacji:**
- Szablon **kopiuje sugestie** i nie tworzy trwałej zależności obiektu od szablonu.
- Każde pole z szablonu można usunąć, zmienić nazwę lub pominąć.
- Szablon może wskazać pola silnie identyfikujące oraz pola rozróżniające egzemplarze; dowolna różnica w danych nie jest automatycznie dowodem odrębnego obiektu.
- Lokalny mechanizm reguł i słowników może na podstawie nazwy zasugerować kategorię, typ, szablon oraz początkowe wartości, ale użytkownik zawsze zatwierdza albo zmienia sugestię.
- Niejednoznaczne dopasowanie pokazuje wybór, a brak dopasowania pozostawia poprawny obiekt bez typu. Mechanizm nie używa AI w MVP.
- Kategoria nie narzuca pól. Szablon jedynie proponuje pola, których niewypełnienie nie blokuje utworzenia poza informacją wymaganą do rozstrzygnięcia konfliktu duplikatu.
- System nie tworzy automatycznie tagu, który tylko powtarza kategorię lub typ; tagi służą klasyfikacji poprzecznej.
- **Zmiana szablonu nie modyfikuje istniejących obiektów** bez decyzji użytkownika.
- Usunięcie szablonu nie usuwa obiektów.

### S-07. Relacje · M10

**Jako** użytkownik **chcę** połączyć obiekty **żeby** zbudować kontekst.

**Kryteria akceptacji:**
- Relacja jest **zapisywana raz i prezentowana z obu stron**.
- Typ relacji ma nazwę odwrotną.
- Duplikat relacji jest wykrywany.
- Relacja obiektu do samego siebie jest zabroniona.
- Usunięcie relacji nie usuwa obiektów; archiwizacja obiektu zachowuje relacje.
- Relacja do obiektu w koszu jest widoczna jako zerwana lub oczekująca.

## 2.3. Dokumenty

### S-08. Dokumenty i upload · M12

**Jako** użytkownik **chcę** dodać dokument do obiektu **żeby** mieć go w kontekście.

**Kryteria akceptacji:**
- Plik jest **streamowany**, nigdy nie trafia w całości do RAM.
- Checksum SHA-256 liczony w locie; typ wykrywany po zawartości, nie po rozszerzeniu.
- Przed przyjęciem sprawdzane są: sesja, uprawnienie, limit rozmiaru, **wolne miejsce** i typ.
- Klient szybko otrzymuje identyfikator; OCR działa w tle.
- **Restart workera nie tworzy duplikatu.**
- **Plik nie ginie** — kwarantanna pozostaje do czasu potwierdzenia przez Paperless.
- Kwarantanna jest czyszczona po finalizacji.
- Jeden dokument może być powiązany z wieloma obiektami; **odpięcie nie usuwa pliku** używanego gdzie indziej.
- Dokument bez powiązań trafia na listę „nieprzypisane" — nie znika.

### S-09. Paperless OCR · M12

**Jako** użytkownik **chcę**, żeby treść dokumentu była rozpoznana **żeby** móc go później znaleźć.

**Kryteria akceptacji:**
- OCR wykonuje Paperless; Core **nie uruchamia własnego OCR**.
- OCR działa dla języka polskiego na rzeczywistych skanach.
- Dokumenty Office przechodzą przez Gotenberg w pipeline Paperless.
- Status przetwarzania jest widoczny i zrozumiały dla użytkownika.
- **Awaria Paperless daje czytelny stan**, nie błąd 500 i nie ciszę.

### S-10. Thumbnail i preview · M12

**Jako** użytkownik **chcę** zobaczyć dokument bez pobierania **żeby** szybko sprawdzić, czy to ten właściwy.

**Kryteria akceptacji:**
- Miniatura jest derivative z Paperless, pobieranym przez Core po autoryzacji.
- **Brak miniatury daje placeholder, nie błąd całej karty.**
- Podgląd renderuje PDF.js, ze strumieniowaniem i obsługą Range Requests.
- **Frontend nigdy nie zna URL-a Paperless.**
- Pobranie oryginału wymaga uprawnienia `document.download_original`, zapisuje audit i zwraca `Content-Disposition: attachment`.
- Token sesji nie występuje w URL.

## 2.4. Odnajdywanie i organizacja

### S-11. Wyszukiwanie · M13

**Jako** użytkownik **chcę** znaleźć dokument po nazwie obiektu lub po treści **żeby** nie przeglądać list.

**Kryteria akceptacji:**
- Wyniki pochodzą z dwóch źródeł: PostgreSQL FTS (Core) i Paperless search (treść OCR).
- **Filtrowanie uprawnieniami następuje po stronie Core, przed zwróceniem wyniku** — nigdy w UI.
- **System nie ujawnia tytułu, fragmentu OCR ani istnienia dokumentu bez uprawnienia.**
- Polskie znaki i literówki są obsługiwane dla wyników Core przez `unaccent` i `pg_trgm`. Dla treści OCR z Paperless wymagane jest wyszukiwanie charakterystycznej frazy; tolerancja literówek jest mierzona osobno i nie jest zakładana bez wyniku E1.
- Awaria Paperless zwraca wyniki domenowe z flagą `partial=true` i komunikatem — **nie pustą listę i nie błąd**.
- Typy wyników: `object`, `document`, `person`, `place`, `reminder`, `tag`.

### S-12. Tagi i klasyfikacja · M10, M14

**Jako** użytkownik **chcę** otagować obiekty i dokumenty **żeby** filtrować je poprzecznie do typów.

**Kryteria akceptacji:**
- Tagi należą do Workspace, porównywane bez uwzględniania wielkości liter.
- Tagi można scalać i zmieniać ich nazwę.
- **Tagi Core i tagi Paperless są osobnymi systemami** z jawnym, wybiórczym mapowaniem.
- Użytkownik widzi wyłącznie tagi Core.
- Rozjazd synchronizacji jest wykrywany przez reconciliation.

## 2.5. Cykl życia

### S-13. Archiwum · M10, M14

**Jako** użytkownik **chcę** zarchiwizować rzecz, której już nie mam **żeby** zniknęła z list, ale została w historii.

**Kryteria akceptacji:**
- Archiwizacja **zachowuje historię, pliki i relacje**.
- Obiekt znika z domyślnych list i można go przywrócić.
- Przypomnienia są zawieszane zgodnie z polityką; system pyta, czy je pozostawić.
- Przywrócenie **nie reaktywuje automatycznie przeterminowanych terminów** bez decyzji użytkownika.
- Rejestrowany jest autor i opcjonalny powód.

### S-14. Kosz i trwałe usunięcie · M10, M14

**Jako** użytkownik **chcę** móc cofnąć przypadkowe usunięcie **żeby** nie stracić danych.

**Kryteria akceptacji:**
- Przed usunięciem system pokazuje **skutki**: pliki, relacje, przypomnienia, zasoby współdzielone.
- Relacje są ukrywane, nie niszczone; aktywne zadania zawieszane.
- Kosz ma retencję **dłuższą niż cykl backupu**.
- Trwałe usunięcie wymaga zatwierdzenia administratora, przebiega przez `delete_pending` i pozostawia **tombstone i audit**.
- Przywrócenie dokumentu, którego brak w Paperless, daje stan `missing_external` — **nie błąd**.
- Reconciliation finalizuje przypadek „Paperless usunął, Core nie zapisał sukcesu".

### S-15. Przypomnienia · M16

**Jako** użytkownik **chcę** dostać przypomnienie o kończącej się polisie **żeby** nie przegapić terminu.

**Kryteria akceptacji:**
- Termin można ustawić na obiekcie i na dokumencie.
- Przypomnienie **jednokrotne**, z możliwością snooze i complete.
- Powiadomienie **wyłącznie w aplikacji** (in-app).
- Czas zapisywany z timezone; kontenery w UTC, prezentacja w Europe/Warsaw.
- **Przypomnienie nie przesuwa się przy zmianie czasu (DST).**
- Usunięcie pola daty pyta, co zrobić z przypomnieniem.
- **Scenariusz akceptacyjny:** polisa, przegląd auta i szczepienie mają poprawne terminy.

## 2.6. Zaufanie i dostęp

### S-16. Audit podstawowy · M10

**Jako** administrator **chcę** wiedzieć, kto co zrobił **żeby** móc odtworzyć bieg zdarzeń.

**Kryteria akceptacji:**
- Rejestrowanych co najmniej 19 zdarzeń z 06 §37: 16 bazowych oraz 3
  obowiązkowe zdarzenia bezpieczeństwa wartości wrażliwej. Katalog rozszerza
  się jawnie wraz z modelowaniem pozostałych procesów MVP.
- Każde zawiera: actor, workspace, target, timestamp, correlation ID, result.
- Audit zapisuje także sesję, urządzenie, rodzaj klienta, transport `lan` /
  `wireguard`, strefę źródłową i adres zaobserwowany przez zaufany gateway.
- **Audit nie zawiera sekretów ani całych treści dokumentów.**
- Dokładne wartości zwykłe należą do historii obiektu, a nie trwałego audytu.
  Wartości wrażliwe są zawsze redagowane, bez treści i bez skrótu.
- Archiwum i kosz zachowują historię wartości. Trwałe usunięcie usuwa jej
  treść, pozostawiając audit struktury operacji oraz tombstone.
- Po usunięciu konta zachowana osoba może dostarczać czytelną nazwę historyczną.
  Po pełnym usunięciu osoby pozostaje niezmienny identyfikator i pseudonim, bez
  imienia, nazwiska i e-maila.
- **Audit domenowy nie jest wyłącznie logiem Docker.**

### S-17. Backup i restore · M10 (Core DB), M17 (produkcyjnie)

**Jako** operator **chcę** móc odtworzyć system po utracie sprzętu **żeby** rodzina nie straciła dokumentów.

**Kryteria akceptacji:**
- Backup obejmuje: Core DB, dane i dokumenty Paperless, assety Core oraz konfigurację. Niezbędne sekrety aplikacyjne są przechowywane w oddzielnym, szyfrowanym pakiecie odzyskiwania.
- Kopie baz i mediów pochodzą ze **spójnego punktu w czasie** z manifestem.
- Repozytorium jest szyfrowane i deduplikowane; klucz repozytorium, passphrase eksportu i klucz pakietu odzyskiwania mają **minimum dwie bezpieczne kopie out-of-band**. Żaden sekret nie może istnieć wyłącznie w backupie, do którego jest potrzebny.
- Obowiązuje reguła 3-2-1; kopia poza głównym serwerem.
- **Brama bezwzględna:** na czystej maszynie odtworzono stack, zalogowano się, otwarto dokumenty, wykonano OCR search, sprawdzono relacje i **zweryfikowano checksum**.
- Pełny restore testowany **co najmniej kwartalnie**.
- Brak świeżego backupu generuje alert.

### S-18. LAN i samodzielny WireGuard · M18

**Jako** domownik **chcę** korzystać z aplikacji w domu oraz po bezpośrednim,
prywatnym połączeniu spoza domu **żeby** mieć dostęp bez publicznego wystawienia
HomeOS i bez obcego pośrednika.

**Kryteria akceptacji:**
- Caddy jest **jedynym punktem wejścia**; TLS obowiązuje także w LAN.
- Żadna usługa wewnętrzna nie ma publicznego portu.
- **Brak port forwarding aplikacji i brak UPnP dla serwera.**
- WireGuard jest jedyną wspieraną drogą dostępu zdalnego; aktywację można
  pominąć, ale nie zastępuje się jej publicznym endpointem, Tailscale ani
  zewnętrznym relayem.
- Każde urządzenie ma osobny klucz i ograniczone trasy. MVP obsługuje ręczny
  klient WireGuard, procedurę dodania urządzenia i procedurę zgubionego telefonu.
- Brak osiągalnego publicznego IPv4/IPv6 jest raportowany jako blokada dostępu
  zdalnego, bez automatycznego fallbacku przez cudzy serwer.
- Sesję zgubionego urządzenia można unieważnić.

---

# 3. Poza zakresem MVP — non-goals

Pozycje jawnie wykluczone (07 §6). Ich dodanie wymaga **wymiany** za inną pozycję z sekcji 2 albo przeniesienia do deferred list.

| Obszar | Pozycja | Dlaczego poza MVP |
|---|---|---|
| Produkt | **AI** | Wymaga dojrzałych danych, uprawnień i audytu. AI nigdy nie jest source of truth |
| Produkt | **Home Assistant** | Osobny bounded context; model przygotowany (`integration_links`), funkcja nie |
| Produkt | **Kamery** | Wideo i lokalizacja wymagają szczególnej ochrony; osobny bounded context |
| Produkt | **Energia** | Najdalej odsunięty moduł techniczny |
| Produkt | **Geolokalizacja** | Brak use case w segregatorze |
| Produkt | **Kalendarz zewnętrzny** (Google, Apple, CalDAV) | Wydanie 1.2 — Calendar Foundation |
| Produkt | **Import CSV i import masowy** | Wydanie 1.1 (R-16); kontrakt zachowania istnieje w 06 §26 |
| Produkt | **Saved searches** | Wydanie 1.1 |
| Produkt | **Przypomnienia cykliczne i wielokanałowe** | Wydanie 1.1 (R-15) |
| Produkt | **Aplikacja natywna** | Lokalny web/PWA powstaje pierwszy; późniejsza aplikacja mobilna osadzi WireGuard |
| Produkt | **Pełny design system** | 07 §36 — jawnie zakazany w MVP |
| Infrastruktura | **Publiczna chmura / publiczny hosting** | Model local-first |
| Infrastruktura | **Multi-tenant SaaS** | Jeden Workspace dla gospodarstwa (R-11) |
| Infrastruktura | **Kubernetes** | Jedna maszyna, jeden operator |
| Komponenty | **OpenSearch / Meilisearch** | PostgreSQL FTS + Paperless search wystarczają (R-08) |
| Komponenty | **MinIO** | Lokalny filesystem za portem (R-09) |
| Komponenty | **Keycloak / Authentik** | Własny auth + port `IdentityProvider` (R-10) |
| Komponenty | **Kafka, Temporal, RabbitMQ** | BullMQ + Valkey wystarczają |
| Komponenty | **ClamAV** | Punkt integracyjny istnieje w pipeline; implementacja po MVP |
| Komponenty | **Prometheus / Grafana / Loki** | Etap 1 monitoringu wystarcza (R-18) |
| Komponenty | **Własny OCR** | Jedna funkcja, jeden właściciel — OCR należy do Paperless (R-03) |
| Architektura | **Mikroserwisy** | Monolit modułowy (R-06) |
| Architektura | **GraphQL, event sourcing, service mesh** | Brak use case |
| Bezpieczeństwo | **MFA / passkeys** | Wydanie 1.1; auth przygotowany do MFA |
| Bezpieczeństwo | **SSO / zewnętrzny IdP** | Po MVP |
| Bezpieczeństwo | **Air-gap** | Tylko jako twarde wymaganie; znacznie zwiększa koszt operacyjny |

---

# 4. Deferred list

Rejestr pozycji odłożonych świadomie, z przypisanym wydaniem. **Każda nowa funkcja zgłoszona w trakcie MVP trafia tutaj**, chyba że wymienia pozycję z sekcji 2.

| Pozycja | Wydanie | Warunek podjęcia |
|---|---|---|
| Lepszy bulk import, import CSV | 1.1 | Zamknięte MVP 1.0 |
| Ulepszone templates (dziedziczenie) | 1.1 | — |
| Saved searches | 1.1 | — |
| Rozszerzony audit | 1.1 | — |
| MFA / passkeys | 1.1 | — |
| Rozszerzone powiadomienia (e-mail, push) | 1.1 | — |
| Widok terminów, iCal export | 1.2 | — |
| CalDAV / Google / Apple Calendar | 1.2+ | Po iCal export |
| Home Assistant — adapter i mapowanie | 2.x | Dojrzałe dane i uprawnienia |
| Kamery — integracja NVR | 3.x | Osobny bounded context |
| Energia — falowniki, liczniki | 4.x | — |
| AI — semantic search, summaries | 5.x | Dojrzałe dane, uprawnienia i audit |
| ClamAV | po MVP | Decyzja o koszcie RAM i sygnatur |
| Prometheus / Grafana / Loki | po MVP | Po wejściu realnych danych |
| MinIO | bezterminowo | Realna potrzeba S3 + nowy ADR |
| Meilisearch / OpenSearch | bezterminowo | **Mierzalny** problem wydajności lub trafności + nowy ADR |
| Keycloak / Authentik | bezterminowo | Potrzeba SSO/MFA organizacyjnego + nowy ADR |
| Aplikacja mobilna z osadzonym WireGuard | po MVP 1.x | Stabilny lokalny web, kontrakt urządzeń i provisioning WireGuard z M18 |
| Aplikacja desktopowa | później | Potwierdzona potrzeba ponad web i ręczny klient WireGuard |
| Wariant hostowany HomeOS | po publicznym wydaniu | Osobny ADR, threat model, model tenantów oraz izolacja baz, dokumentów, sekretów i backupów |
| Rozdzielenie Valkey na dwie instancje | po pomiarze | Wynik E1 w Fazie 1 |
| SSE zamiast pollingu | po MVP | Polling okazuje się niewystarczający |

---

# 5. Decyzje G1 — warunkujące eksperymenty Fazy 1

Pięć decyzji, bez których Faza 1 nie daje rozstrzygnięcia. Zamknięte w M1.

## G1-01. Zakres testów Paperless

Eksperyment **E1** obejmuje dokładnie następujące próby (07 §8):

**Operacje REST API:** token API · upload · task status · metadata · original · preview/archive PDF · thumbnail · search po treści OCR · aktualizacja tag/correspondent/document type · delete · health/fallback health.

**Operacje utrzymaniowe poza REST API i poza E1:** E3A sprawdza oficjalny `document_exporter`/`document_importer`, a E3B — dump PostgreSQL, backup mediów i restore disaster recovery. Rozdzielenie wynika z ADR-019.

**Uruchomienie:** baseline zachowujący strukturę oficjalnego Compose `postgres-tika` z taga `v3.0.4`, ale zastępujący jego referencje obrazów jawnymi tagami i digestami, oraz wersjonowane pliki override i wariantów ograniczające ekspozycję i dodające wyłącznie elementy laboratorium. Oficjalny Compose 3.0.4 używa już Valkey; nie przenosi się starego obejścia brokera z 2.x.

**Formaty/scenariusze (10):** PDF tekstowy · skan PDF · JPG/PNG · DOCX · XLSX · wielostronicowy skan · duży plik · uszkodzony PDF · rodzina duplikatu `DOC-09A`/`09B`/`09C` · dokument z polskimi znakami.

**Zachowania awaryjne:** restart Paperless w trakcie przetwarzania · zapełniony broker Valkey.

**Pomiary:** RAM idle i peak · CPU OCR · czas OCR · przyrost dysku · rozmiar derivative.

**Poza zakresem E1:** optymalizacja czegokolwiek · konfiguracja produkcyjna · budowa adaptera · zmiana kodu lub obrazu Paperless. Dopuszczalna jest wyłącznie konfiguracja wymagana przez oficjalny wariant `postgres-tika`, język polski, pinowanie obrazów i izolację laboratorium.

## G1-02. Kryteria akceptacji

| Wymiar | Próg | Konsekwencja niespełnienia |
|---|---|---|
| **Kompletność REST API** | Siedem operacji blokujących `DocumentProvider` działa; dla trzech operacji ostrzegawczych potwierdzono działanie albo zdefiniowany fallback | **Blokujące** — Gate OS-1 nie przechodzi bez operacji blokujących lub bez jawnego fallbacku |
| **OCR polski** | Rozpoznanie na rzeczywistych skanach pozwala odnaleźć dokument po charakterystycznej frazie z jego treści | **Blokujące dla wartości produktu** — wymaga decyzji o alternatywie lub o obniżeniu obietnicy |
| **E3A — przenośność 3.0.4** | Pełny eksport zawiera pliki i metadane oraz został zaimportowany do pustej instancji 3.0.4 z tym samym digestem; nowy token, sanity checker, dokumenty i OCR działają | **Blokujące** — brak strategii wyjścia dyskwalifikuje komponent (05 §25) |
| **E3B — disaster recovery 3.0.4** | Na czystym celu z Paperless 3.0.4 i tym samym digestem odtworzono obie bazy, media, assety i konfigurację; sanity checker, reconciliation, external IDs i checksumy przechodzą | **Blokujące** — Gate OS-2-LAB nie przechodzi |
| **RAM peak** | Stack laboratoryjny mieści się w 16 GB z udokumentowanym zapasem dla nieuruchomionych jeszcze usług Core; pomiar nie jest dowodem zużycia pełnego produktu | **Ostrzegawcze** — decyzja o sprzęcie, zapasie RAM albo limicie współbieżności OCR |
| **Czas OCR** | Akceptowalny dla typowego dokumentu domowego przy pracy w tle | **Ostrzegawcze** — wpływa na UX statusu, nie na architekturę |
| **Przyrost dysku** | Znany i przewidywalny mnożnik względem rozmiaru wejściowego | **Ostrzegawcze** — wpływa na planowanie pojemności i progi alertów |
| **Licencja** | Inwentarz obrazów i narzędzi laboratorium zawiera źródło, wersję/digest i licencję; GPLv3 i prywatny model użycia są zapisane; brak niezaakceptowanej licencji | **Blokujące dla M3** — Gate OS-3-LAB; pełny SBOM/notices i ocena sposobu dystrybucji należą do OS-3-RELEASE w M22 |

**Definicja krytycznego ograniczenia:** brak którejkolwiek z operacji blokujących, niemożność przejścia E3A lub niemożność przejścia E3B. Jedno takie ograniczenie unieważnia decyzję o Paperless albo wybór narzędzia backupu.

## G1-03. Reprezentatywne dokumenty

**Zasada:** próbki reprezentują rzeczywistą jakość skanów, ale nie mogą ujawniać danych osób bez ich świadomej zgody. Preferowane są dokumenty własne zanonimizowane lub przygotowane przez właściciela na podstawie rzeczywistych materiałów. Czyste PDF-y wygenerowane programowo nie mogą być jedyną próbką OCR.

| # | Typ | Cecha testowana |
|---|---|---|
| 1 | PDF tekstowy (np. faktura z e-maila) | Ścieżka bez OCR |
| 2 | Skan PDF (np. polisa ze skanera) | OCR polski na rzeczywistej jakości |
| 3 | JPG lub PNG (np. zdjęcie paragonu telefonem) | Upload mobilny, OCR ze zdjęcia |
| 4 | DOCX | Pipeline Gotenberg |
| 5 | XLSX | Pipeline Gotenberg, format tabelaryczny |
| 6 | Wielostronicowy skan (np. umowa) | Wydajność OCR, archive PDF |
| 7 | Duży plik | Streaming, timeout, RAM |
| 8 | Uszkodzony PDF | Obsługa błędu permanentnego |
| 9 | Rodzina duplikatu: `DOC-09A` oryginał, `DOC-09B` kopia identyczna bajtowo, `DOC-09C` ponowny skan tej samej treści | Duplikat binarny i logiczny; odpowiedź API/task; zachowanie domyślne i przy odrzucaniu duplikatów |
| 10 | Dokument z polskimi znakami w treści i w nazwie | `unaccent`, kodowanie, wyszukiwanie |

**Manifest** tego zestawu (co, jakie cechy, skąd pochodzi) jest jednym z siedmiu artefaktów trwałych Fazy 1.

Dokumenty binarne nie trafiają do Git. Manifest używa pseudonimów, nie pełnych nazw i danych osób. Tokeny, sekrety, klucze backupu i odpowiedzi API zawierające dane są redagowane zgodnie z [`operations/spike-data-policy.md`](operations/spike-data-policy.md).

## G1-04. Wymagane operacje API

Dziesięć operacji aplikacyjnych, które musi pokryć port `DocumentProvider` (07 §11). Każda ma odpowiadający test w E1. Eksport/import nie należy do tego portu; jest interfejsem utrzymaniowym z ADR-019.

| # | Operacja | Test w E1 | Konsekwencja braku |
|---|---|---|---|
| 1 | `ingest` | Upload przez API | **Blokujące** |
| 2 | task status | Odczyt statusu przetwarzania | **Blokujące** |
| 3 | metadata | Pobranie metadanych dokumentu | **Blokujące** |
| 4 | original stream | Pobranie oryginału | **Blokujące** |
| 5 | preview stream | Pobranie archive PDF | **Blokujące** |
| 6 | thumbnail | Pobranie miniatury | Ostrzegawcze — możliwy placeholder |
| 7 | search | Wyszukiwanie po treści OCR | **Blokujące** |
| 8 | update mapped metadata | Zmiana tagu / correspondent / document type | Ostrzegawcze — mapowanie może być jednokierunkowe |
| 9 | trash / delete | Usunięcie dokumentu | **Blokujące** |
| 10 | health | Sprawdzenie dostępności | Ostrzegawcze — dopuszczalny uwierzytelniony lekki request zamiast dedykowanego endpointu |

**Operacje blokujące Gate OS-1:** `ingest`, task status, metadata, original stream, preview stream, search, trash/delete.  
**Operacje z obowiązkowym fallbackiem:** thumbnail → placeholder; update mapped metadata → mapowanie jednokierunkowe; health → lekki request kontrolny. Brak zarówno operacji, jak i zdefiniowanego fallbacku blokuje bramę.

## G1-05. Oczekiwany model eksportu i restore

Eksport/import jest wykonywany oficjalnymi poleceniami administracyjnymi Paperless, poza `DocumentProvider`.

**Eksport uznajemy za wystarczający, gdy zawiera:**
- oryginały dokumentów,
- archiwalne PDF (lub możliwość ich odtworzenia),
- metadane techniczne wraz z identyfikatorami zewnętrznymi,
- tagi, korespondentów i typy dokumentów,
- informację pozwalającą odtworzyć powiązanie z rekordami Core (external ID lub checksum),

**oraz gdy import tego eksportu do czystej instancji odtwarza dokumenty w stanie użytecznym.** Eksport, którego nie zaimportowano z powrotem, nie jest zweryfikowany.

**Restore laboratoryjny M3 ma dwa obowiązkowe tory:**

1. **E3A — przenośność:** pełny eksport Paperless 3.0.4 jest zabezpieczony przez kandydata, odtworzony i zaimportowany do pustej instancji 3.0.4 z tym samym digestem; po wygenerowaniu nowego tokenu przechodzą sanity checker, otwieranie dokumentów i OCR search.
2. **E3B — disaster recovery:** po zamrożeniu zapisów logiczne dumpy obu baz, media Paperless, assety Core, konfiguracja i manifest są zabezpieczone przez kandydata, a następnie odtworzone na czystym celu z Paperless 3.0.4 i tym samym digestem.
3. Po E3B sanity checker i reconciliation przechodzą, external IDs wskazują istniejące dokumenty, a checksumy dokumentów i assetów zgadzają się z manifestem.
4. E3A i E3B są wykonywane osobno dla Restic i Borg. Wybrany kandydat musi przejść oba tory.

Fixture Core w M3 nie jest produkcyjnym modelem danych. Zawiera wyłącznie minimalne rekordy potrzebne do testu spójności: `external_id`, checksum dokumentu, ścieżkę assetu i checksum assetu. Pełny restore produktu z logowaniem i relacjami pozostaje bramą bezwzględną M17.

Restore kończy się **walidacją biznesową, nie startem kontenerów** (06 §29).

---

# 6. Metryki sukcesu MVP

## 6.1. Użytkowe (07 §33)

- Dokument można dodać w kilku prostych krokach.
- Większość dokumentów można znaleźć przez wyszukiwarkę.
- Status przetwarzania jest zrozumiały.
- **Nie trzeba otwierać interfejsu Paperless.**
- Użytkownik rozumie powiązanie dokumentu z obiektem.

## 6.2. Techniczne

- Brak utraty danych po restartach.
- Retry nie duplikuje.
- Restore działa.
- Backup jest świeży.
- Awaria Paperless nie wyłącza Core.
- Krytyczne testy E2E są stabilne.

## 6.3. Operacyjne

- Aktualizacja ma runbook.
- Brak miejsca generuje alert.
- Operator zna stan systemu.
- Sekrety można rotować.

---

# 7. Release criteria (07 §26)

MVP 1.0 może zostać wydane wyłącznie gdy **wszystkie** poniższe są spełnione:

- [ ] Zero znanych błędów utraty danych
- [ ] Wykonany pełny restore test na wydawanej wersji
- [ ] Krytyczne testy E2E przechodzą i są stabilne
- [ ] Dokumentacja operatora gotowa
- [ ] Release notes
- [ ] SBOM
- [ ] `THIRD_PARTY_NOTICES.md`
- [ ] Rollback plan

Lista jest **zamknięta**. Wszystko poza nią trafia do wydania 1.1.
