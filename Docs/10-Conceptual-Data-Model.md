# 10 — Conceptual Data Model

## Model pojęciowy danych HomeOS

**Wersja:** 0.1 · **Status:** `draft` · **Milestone:** M4 · **Data:** 2026-08-01

**Podstawa:** [`07-Product-and-Delivery-Roadmap.md`](07-Product-and-Delivery-Roadmap.md) §9,
[`08-MVP-Scope.md`](08-MVP-Scope.md),
[`workflows/06-System-Workflows.md`](workflows/06-System-Workflows.md) oraz
[`glossary.md`](glossary.md).

> M4 rozpoczęto jako szkic roboczy. M3 pozostaje formalnie otwarte do czasu
> uzupełnienia testów rzeczywistych skanów i docelowego storage. Ten dokument
> nie jest jeszcze podstawą implementacji ani zamknięcia bramy M4.

---

# 1. Cel i granice

Dokument ma zdefiniować encje, odpowiedzialności, relacje, cykle życia,
invariants, retencję, przykładowe rekordy, politykę JSONB oraz wstępną
strategię indeksów. Model pozostaje pojęciowy: nie definiuje jeszcze tabel
Prisma, migracji ani fizycznego schematu PostgreSQL.

Brama M4 zostanie oceniona przez przejście 15 minimalnych procesów MVP z
[`workflows/06-System-Workflows.md`](workflows/06-System-Workflows.md) §41 bez
specjalnych obejść.

---

# 2. Rejestr rozstrzygnięć roboczych

Rozstrzygnięcia w tej sekcji zostały uzgodnione podczas analizy M4. Obowiązują
w ramach szkicu, lecz status całego dokumentu pozostaje `draft` do przejścia
bramy M4.

## M4-D01. Aktor operacji `create object`

Obiekt może utworzyć uwierzytelnione `Account`, które ma aktywne `Membership`
oraz efektywne uprawnienie `object.create` w tej instalacji.

Domyślnie:

| Rola lub stan | `object.create` |
|---|---:|
| owner Workspace | tak |
| administrator Workspace | tak |
| zwykły domownik | tak |
| ograniczony domownik | nie; uprawnienie nadaje administrator |
| gość | nie |
| konto zablokowane lub nieaktywne członkostwo | nie |
| operator infrastruktury | nie, jeśli nie ma osobnego konta HomeOS |

Administrator systemu operacyjnego nie jest domenowym użytkownikiem `root`.
Pierwszy użytkownik HomeOS otrzymuje rolę `owner`, której pakiet zawiera
uprawnienia administracyjne, ale pozostaje zwykłym `Account` podlegającym
regułom domenowym i auditowi.

## M4-D02. Jedna instalacja HomeOS i jeden Workspace

Jedna produkcyjna instalacja HomeOS i jej baza obsługują dokładnie jeden
Workspace domu. Workspace porządkuje własność danych, natomiast instalacja/VM
i jej baza stanowią rzeczywistą granicę bezpieczeństwa.

Niezależne domeny zaufania, na przykład dom i firma, używają osobnych
instalacji, VM, baz, dokumentów, sekretów i backupów. Osobny storage jest
zalecanym środkiem izolacji zależnym od profilu ryzyka. Wariant firmowy oraz
przełączanie między niezależnymi instalacjami są odłożone poza HomeOS MVP.

`workspace_id` pozostaje obowiązkową relacją techniczną w encjach domenowych,
ale nie jest wybieranym kontekstem użytkownika ani predykatem autoryzacji.
Singleton Workspace powstaje podczas bootstrapu, a jego identyfikator nadaje
serwer. Klient nie przesyła go w zwykłych komendach i zapytania nie wykonują
filtracji tenantów. Spójność relacji wymuszają klucze obce i ograniczenia bazy.

Model nie zamyka drogi do bardzo późnego wariantu hostowanego. API pozostaje
niezależne od transportu, a klient przechowuje profil połączenia z konkretną
instalacją. Tryb hostowany nie jest jednak drugim trybem bieżącego wdrożenia:
wymaga po publicznym wydaniu osobnego ADR, threat modelu, modelu tenantów,
izolacji baz, dokumentów, sekretów i backupów oraz nowej oceny prawnej. Nie
wolno uznać samego `workspace_id` i filtrowania wierszy za wystarczającą
izolację SaaS.

## M4-D03. Bootstrap i nieblokujący onboarding

Pierwszy krok wymaga:

- imienia,
- nazwiska,
- adresu e-mail,
- hasła spełniającego politykę bezpieczeństwa.

Jedna transakcja tworzy `Account`, `Workspace`, `Membership` z rolą `owner`,
`Person Object` pierwszego użytkownika, powiązanie członkostwa z osobą oraz
`AuditEvent`. Surowe hasło nie jest zapisywane. Awaria transakcji nie może
pozostawić częściowych rekordów.

Po tym kroku użytkownik może wejść na pulpit. Uzupełnienie dalszych danych
osobowych jest opcjonalne. Utworzenie korzenia gospodarstwa można czasowo odłożyć, ale
nie można go trwale pominąć: onboarding pozostaje niedokończony, a pulpit stale
pokazuje nieusuwalną zachętę do utworzenia gospodarstwa.

Minimalne stany konfiguracji:

```text
uninitialized
    -> household_required
    -> completed
```

Stan nie jest zapisywany w mutowalnej kolumnie. Core wylicza go z faktów:

| Stan | Warunek |
|---|---|
| `uninitialized` | singleton Workspace nie istnieje |
| `household_required` | Workspace istnieje, ale `household_object_id` jest pusty |
| `completed` | `household_object_id` wskazuje aktywny `Household Object` |

Dzięki temu status nie może wskazywać `completed`, gdy korzeń gospodarstwa
faktycznie nie istnieje. `Workspace.household_object_id` może wskazać tylko
jeden obiekt. Ponowienie komendy z tym samym kluczem idempotencji zwraca już
utworzone gospodarstwo. Archiwizacja, zastąpienie lub trwałe usunięcie korzenia
nie jest zwykłą operacją i musi atomowo zachować invariant z M4-D04.

Testy obejmują wszystkie trzy wyniki, równoczesne próby utworzenia głównego
domu, rollback nieudanej transakcji oraz idempotentne ponowienie. Zmiana danych
osobowych, nazwy gospodarstwa albo miejsca zamieszkania nie zmienia stanu onboardingu.

## M4-D04. Gospodarstwo i miejsca zamieszkania

`Household Object` reprezentuje gospodarstwo domowe, a nie budynek. Jest
widocznym korzeniem HomeOS i po utworzeniu wskazuje go
`Workspace.household_object_id`. `Workspace` pozostaje niewidocznym
technicznym właścicielem danych.

Każdy fizyczny dom, mieszkanie, działka albo lokal jest osobnym `Place Object`.
Gospodarstwo może być równocześnie powiązane z wieloma miejscami. Znaczenia nie
są łączone w jeden status, lecz zapisane jako niezależne relacje:

- `resides_at` — gospodarstwo mieszka w miejscu; zawiera `valid_from`,
  opcjonalne `valid_to` oraz `is_primary`,
- `owns` — jest właścicielem,
- `rents_out` — wynajmuje miejsce komuś,
- `rents_from` — najmuje miejsce od kogoś,
- `uses_seasonally` — używa sezonowo,
- `manages` — zarządza miejscem.

Jedno miejsce może mieć kilka z tych relacji jednocześnie, np. gospodarstwo
jest właścicielem mieszkania i wynajmuje je komuś, lecz w nim nie mieszka.
Relacja własności ani najmu nie nadaje automatycznie statusu miejsca
zamieszkania.

Invariants:

1. Po zakończeniu onboardingu `Workspace.household_object_id` wskazuje
   dokładnie jeden aktywny `Household Object`.
2. Identyfikator gospodarstwa pozostaje stabilny; jego nazwa i pozostałe dane
   są edytowalne.
3. Gospodarstwo może mieć wiele aktywnych relacji `resides_at`, ale jeżeli ma
   co najmniej jedną, dokładnie jedna z nich jest oznaczona `is_primary`.
4. Przeprowadzka nie zastępuje gospodarstwa i nie nadpisuje historii. Zamyka
   poprzednią relację datą końcową, tworzy nową i atomowo zmienia miejsce główne.
5. Miejsca nieużywane obecnie pozostają zwykłymi aktywnymi, historycznymi albo
   zarchiwizowanymi obiektami wraz z dokumentami i rozliczeniami.
6. Korzenia gospodarstwa nie można archiwizować ani usuwać zwykłą operacją na
   obiekcie; wymaga to osobnej procedury likwidacji Workspace.

Interfejs może prezentować strukturę jak drzewo, ale model pozostaje grafem.
Obiekt może mieć wiele równoczesnych relacji i nie otrzymuje jednego
obowiązkowego rodzica.

## M4-D05. Wspólny lifecycle obiektów

Dom, miejsce, samochód, urządzenie, osoba i usługa korzystają z tego samego
cyklu życia:

```text
active
  -> archived -> active
  -> trashed  -> active
              -> delete_pending -> deleted
```

Archiwizacja jest domyślną operacją dla obiektu, który przestał być aktualny.
Zachowuje pola, dokumenty, assety, relacje i audit, ukrywa obiekt z domyślnych
widoków i pozwala go przywrócić. Relacje historyczne zachowują okres
obowiązywania. Dane właściwe dla starego miejsca lub sprzedanego samochodu
pozostają przy tym obiekcie.

Przykładowe powody archiwizacji: `sold`, `relocation`, `ended`, `given_away`,
`unused`, `duplicate`, `other`.

## M4-D06. Trwałe usunięcie i ochrona przed pomyłką

Trwałe usunięcie nie może być bezpośrednią operacją na aktywnym ani
zarchiwizowanym obiekcie. Wymaga trzech niezależnych bram:

1. przeniesienia do kosza po pokazaniu zależności,
2. upływu retencji i braku aktywnej blokady zachowania danych,
3. ponownego uwierzytelnienia administratora, wpisania nazwy lub wygenerowanej
   frazy oraz zaakceptowania końcowego zestawienia skutków.

Przed usunięciem system klasyfikuje dokumenty, assety, relacje, przypomnienia i
obiekty zależne. Powiązane obiekty nigdy nie są usuwane kaskadowo. Dokument
powiązany wyłącznie z usuwanym obiektem może zostać jawnie wybrany do usunięcia.
Dokument współdzielony jest domyślnie zachowywany, a jego usunięcie wymaga
osobnej decyzji pokazującej wszystkie pozostałe powiązania.

Usunięcie binariów w Paperless jest asynchroniczne. Obiekt pozostaje w
`delete_pending` do potwierdzenia wyniku; retry i reconciliation muszą być
idempotentne. Po zakończeniu pozostaje minimalny `TrashRecord`/tombstone oraz
`AuditEvent`, bez sekretów i pełnej treści usuniętych danych.

Trwałe usunięcie z aktywnego systemu nie modyfikuje historycznych backupów.
Dane wygasają w nich zgodnie z osobną retencją, co interfejs musi jawnie
zakomunikować przed potwierdzeniem.

## M4-D07. Granica zwykłego `create object`

`Object` jest korzeniem spójności zwykłej operacji tworzenia. Każde udane
`create object` tworzy co najmniej `Object` oraz `AuditEvent`.

Opcjonalnie ta sama transakcja:

- wykorzystuje istniejące albo jawnie tworzy nowe `FieldDefinition`,
- zapisuje początkowe `FieldValue`,
- wykorzystuje istniejące albo jawnie tworzy nowe `Tag`,
- zapisuje powiązania obiektu z tagami.

Podobna nazwa pola lub tagu powoduje sugestię użycia istniejącego elementu,
nie automatyczne scalenie. Awaria dowolnego elementu tej granicy wycofuje całą
transakcję; nie może pozostać częściowo utworzony obiekt.

Zwykłe `create object` nie tworzy `Account`, `Membership`, `Workspace`,
dokumentów, przypomnień, innych obiektów ani relacji do innych obiektów.
Utworzenie `Person Object` nie tworzy konta. Bootstrap pierwszej osoby i
utworzenie `Household Object` są osobnymi komendami domenowymi z dodatkowymi
skutkami opisanymi w M4-D03 oraz M4-D04.

Relacje są zapisywane osobną operacją po zwróceniu identyfikatora nowego
obiektu, nawet jeżeli UI zbiera je na tym samym ekranie. Niepowodzenie relacji
nie usuwa poprawnie utworzonego obiektu. Upload dokumentu i utworzenie
`ObjectDocumentLink` również stanowią osobny, asynchroniczny proces; awaria
Paperless nie wycofuje obiektu.

`Template` kopiuje sugestie i nie pozostaje obowiązkową zależnością. Ewentualna
informacja o użytym szablonie ma charakter pochodzenia/audytu, nie więzi cyklu
życia obiektu z szablonem.

## M4-D08. Dane wymagane i wykrywanie duplikatów

Zwykłe `create object` wymaga od użytkownika wyłącznie `name`, jeżeli nie
pozostawia to nierozstrzygniętego konfliktu z istniejącym obiektem. System
uzupełnia co najmniej `id`, `workspace_id`, `status`, `visibility`,
`created_by`, `created_at`, `updated_at` i początkową `version`. Żądanie ma
osobne `idempotency_key` i `correlation_id`, które nie są polami obiektu.

Nazwa nie jest identyfikatorem obiektu. Dokumenty, relacje i pozostałe
odwołania wykorzystują niezmienny `Object.id`. Detekcja duplikatów działa
wewnątrz instalacji według siły dowodu:

1. ten sam znormalizowany silny identyfikator egzemplarza odrzuca zapis,
2. ta sama znormalizowana nazwa bez danych rozróżniających zatrzymuje zapis,
3. ta sama nazwa z wiarygodnie różnymi danymi jest dozwolona,
4. różnica wyłącznie w swobodnym opisie nie dowodzi odrębności.

Szablon lub typ wskazuje pola silnie identyfikujące i zestawy słabszych pól
rozróżniających. Przykłady silne to VIN, numer seryjny, IMEI albo numer umowy;
przykłady łączne to producent, model i lokalizacja. Dokładna macierz dla typów
powstanie wraz ze słownikiem encji i szablonów.

Zwykły `Person Object` może powstać z samą nazwą. Bootstrap konta pozostaje
wyjątkiem i wymaga imienia, nazwiska, e-maila oraz hasła. `Household Object`
wymaga tylko nazwy; fizyczny adres należy do osobnego `Place Object`.

## M4-D09. Deterministyczne sugestie klasyfikacji

MVP wykorzystuje lokalne, jawne reguły i słowniki do wygenerowania
`ClassificationSuggestion`: propozycji kategorii, typu, szablonu oraz
początkowych wartości. Użytkownik zawsze zatwierdza lub zmienia wynik.
Niejednoznaczność prowadzi do wyboru, a brak dopasowania pozostawia poprawny
obiekt bez typu.

Kategoria nie narzuca pól. Szablon kopiuje opcjonalne sugestie i może wskazać
pola identyfikujące lub rozróżniające. System nie tworzy automatycznie tagu,
który powtarza kategorię albo typ; tagi opisują przekroje takie jak `rodzinny`,
`leasing` lub `do_sprzedania`.

AI pozostaje poza MVP. W przyszłości może dostarczać propozycje przez tę samą
granicę, ale nie zatwierdza danych i nie jest źródłem prawdy.

## M4-D10. Dane opcjonalne i granice ich przechowywania

Dane opcjonalne są rozdzielone według znaczenia, a nie umieszczane w jednym
uniwersalnym polu:

1. typowane właściwości rdzenia `Object`, takie jak opis, kategoria, typ,
   widoczność, osoba odpowiedzialna, ikona i zdjęcie główne,
2. elastyczne atrybuty jako `FieldDefinition` oraz `FieldValue`,
3. powiązania obiektów jako `Relation`,
4. dokumenty jako `DocumentReference`, `DocumentProjection` i
   `ObjectDocumentLink`, a pozostałe media jako `Asset`,
5. klasyfikacja poprzeczna jako `Tag`.

Hierarchia podpowiedzi ma postać `Category -> Type -> Template -> suggested
fields`. Kategoria nie narzuca pól, a szablon jedynie kopiuje propozycje.
Dynamiczne pola nie są obowiązkowe dla istnienia obiektu i są walidowane po
podaniu wartości. Pole oznaczone `identity_strong` albo
`identity_supporting` może być potrzebne wyłącznie do rozstrzygnięcia
konkretnego konfliktu duplikatu.

`relation` i `file` mogą być typami kontrolek w formularzu, lecz zapisują
wyspecjalizowane encje, nie `FieldValue`. Przypomnienia również pozostają
osobną encją i cyklem życia.

Wartość pochodząca z reguły, integracji lub przyszłego AI zachowuje źródło,
poziom pewności i stan zatwierdzenia. Po zatwierdzeniu nadal można odtworzyć
jej pochodzenie; sugestia nie staje się automatycznie źródłem prawdy.

JSONB służy wyłącznie wersjonowanym danym technicznym, pochodzeniu sugestii
lub nieznormalizowanemu ładunkowi integracji. Nie przechowuje zwykłych danych
użytkownika, identyfikatorów egzemplarzy, relacji, tagów, powiązań dokumentów,
sekretów ani wartości wymagających wyszukiwania lub integralności referencyjnej.

## M4-D11. Invariants zwykłego `create object`

Przed i po każdej próbie utworzenia obiektu obowiązują następujące zasady:

1. aktor ma aktywne `Membership` i efektywne `object.create`,
2. serwer przypisuje identyfikator jedynego Workspace; klient go nie wybiera,
3. obiekt ma techniczną relację do singletonu Workspace; jego `id` oraz
   `workspace_id` są niezmienne,
4. poprawny obiekt ma niepustą nazwę, początkowy status `active`, widoczność,
   autora, timestamps oraz początkową `version`,
5. wykorzystane definicje pól, typy, tagi i wartości pochodzą z tej instalacji
   oraz spełniają klucze obce, reguły typu i wielowartościowości,
6. zapis nie kończy się sukcesem z nierozstrzygniętym konfliktem duplikatu,
7. `Object`, początkowe wartości, powiązania tagów i `AuditEvent` zapisują się
   atomowo albo nie zapisuje się żaden z nich,
8. ponowienie tego samego `idempotency_key` zwraca wcześniejszy wynik i nie
   tworzy drugiego obiektu ani drugiego audytu sukcesu,
9. sugestia klasyfikacji lub wartości staje się danymi dopiero po zatwierdzeniu,
10. operacja nie tworzy ukrytych kont, dokumentów, relacji, przypomnień ani
    innych obiektów.

Domyślna widoczność obiektu to `workspace`. Użytkownik może wybrać `private`;
dokładne role, jawne granty oraz przyszły wariant `restricted` definiuje M5.
Brak `Household Object` podczas niedokończonego onboardingu nie narusza invariants
zwykłego `create object`.

Każda instalacja/VM ma jeden niezależny Workspace. Dodanie wielu serwerów do
aplikacji klienckiej oznacza zapisanie osobnych profili połączeń, a nie
przełączanie Workspace w jednej bazie. Tworzenie obiektu, wyszukiwanie
duplikatów i uprawnienia działają w instalacji, z którą klient nawiązał
połączenie. Przenoszenie danych wymaga osobnej, jawnej operacji
eksportu/importu i pozostaje poza tym procesem.

## M4-D12. Wrażliwość konkretnej wartości

`sensitive` jest właściwością konkretnego `FieldValue`, nie globalnego
`FieldDefinition`. Dwie wartości korzystające z definicji „PESEL” mogą mieć
inne zasady dostępu. Szablon może zasugerować ochronę nowej wartości, ale nie
zmienia istniejących wartości ani całej biblioteki pól.

Zwykła wartość dziedziczy widoczność obiektu. Wartość wrażliwa ma własne
uprawnienia odczytu, edycji i zarządzania dostępem. Jest domyślnie zamaskowana,
nie trafia do zwykłego indeksu ani do treści logów, powiadomień i błędów.
Ujawnienie, zmiana oraz nadanie lub odebranie dostępu pozostawiają audit bez
zapisania jawnej wartości.

Administrator Workspace nie otrzymuje automatycznie odczytu wartości
wrażliwej. Relacja rodzinna również nie nadaje takiego dostępu. Dla pola osoby
bez powiązanego konta dostępem zarządza jawnie upoważniony opiekun lub twórca
wartości. Po powiązaniu osoby z aktywnym kontem osoba otrzymuje kontrolę nad
własnymi wartościami i może odebrać wcześniejszy grant. Rodzic może zatem znać
PESEL dziecka bez uzyskania przez dziecko dostępu do PESEL-u rodzica.

Dokładna reprezentacja grantów, kolejność reguł allow/deny i testy trudnych
przypadków należą do M5 `Permissions and Privacy`; M4 utrwala semantykę i
granice danych.

## M4-D13. Audit i historia `create object`

Udane `create object` zapisuje dokładnie jeden `AuditEvent` w tej samej
transakcji co obiekt. Zdarzenie zawiera co najmniej:

- niezmienny identyfikator aktora; czytelna etykieta pochodzi z zachowanej
  osoby albo z pseudonimu po pełnym usunięciu jej danych,
- Workspace, typ i identyfikator celu oraz snapshot nazwy obiektu,
- czas UTC, wynik, `correlation_id` i `idempotency_key`,
- identyfikator sesji i urządzenia oraz nazwę urządzenia,
- rodzaj klienta: `web`, `mobile` albo `desktop`,
- transport: obecnie `lan` albo `wireguard`,
- strefę źródłową i adres sieciowy zaobserwowany przez zaufaną warstwę wejścia.

System nie korzysta z zewnętrznej geolokalizacji IP. Interfejs prezentuje
źródło jako lokalną konsolę, domowy LAN, samodzielny WireGuard albo `unknown`.
Ewentualny przyszły transport `hosted` wymaga osobnej decyzji opisanej w
M4-D02; nie jest automatycznym fallbackiem.

Trwały audit i historia treści są rozdzielone. Historia obiektu przechowuje
dokładne stare i nowe wartości zwykłych pól przez czas życia obiektu, także w
archiwum i koszu. `AuditEvent` przechowuje strukturę zmiany, ale nie staje się
drugą kopią pełnej treści. Wartości wrażliwe są zawsze redagowane: audit
zapisuje ujawnienie, zmianę lub zmianę dostępu bez wartości i bez jej skrótu.

Trwałe usunięcie usuwa wartości oraz historię ich treści. Pozostają
`AuditEvent` i tombstone mówiące kto, co i kiedy zrobił oraz jakie pola uległy
zmianie, lecz nie pozwalające odtworzyć usuniętych danych. Odrzucenia istotne
domenowo lub bezpieczeństwowo, np. brak uprawnienia albo konflikt duplikatu,
otrzymują wynik i kod przyczyny bez ujawniania obcego celu. Zwykły błąd
formatu formularza należy do ograniczonych logów technicznych, nie do trwałej
historii domenowej.

## M4-D14. Granica `Account`, `Membership` i `Person Object`

`Account` przechowuje wyłącznie tożsamość techniczną: e-mail logowania, hash
hasła, status, dane odzyskiwania, sesje i urządzenia. `Person Object` jest
źródłem prawdy dla imienia, nazwiska, daty urodzenia, telefonu, adresu i innych
danych człowieka. `Membership` łączy konto z osobą i przechowuje uczestnictwo,
rolę oraz uprawnienia w Workspace.

Nie ma automatycznej synchronizacji tych samych danych w obie strony. Nazwa
wyświetlana konta jest odczytywana z powiązanej osoby. `Account.login_email`
służy logowaniu i odzyskiwaniu konta; kontaktowy e-mail osoby jest niezależnym,
opcjonalnym `FieldValue`. Zmiana jednego nie zmienia drugiego bez jawnej,
osobno audytowanej decyzji użytkownika.

Tworzenie konta wykorzystuje istniejący `Person Object`, jeżeli użytkownik
wskaże właściwą osobę. W przeciwnym razie jedna transakcja tworzy `Account`,
`Person Object`, `Membership`, ich powiązanie i `AuditEvent`. Utworzenie samej
osoby nigdy nie tworzy konta. W jednej instalacji konto łączy się z dokładnie
jedną osobą, a osoba może mieć najwyżej jedno aktywne konto.

Blokada konta jest odwracalna: kończy sesje, odcina urządzenia oraz peer
WireGuard i nie zmienia osoby. Usunięcie konta oferuje dwa jawne warianty:

1. usunięcie dostępu z zachowaniem `Person Object` — wariant domyślny,
2. usunięcie konta, osoby i jej ściśle powiązanych danych — osobna operacja
   destrukcyjna.

Drugi wariant przenosi osobę do kosza, pokazuje manifest zależności i korzysta
z retencji, ponownego uwierzytelnienia oraz potrójnej bramy z M4-D06. Może
usunąć pola osoby, dane kontaktowe i wrażliwe, prywatne notatki, assety,
przypomnienia oraz — po osobnym potwierdzeniu — dokumenty powiązane wyłącznie z
tą osobą. Nie usuwa kaskadowo domu, pojazdów, innych obiektów, współdzielonych
dokumentów ani drugich końców relacji; wymagają odpięcia, zmiany opiekuna lub
zachowania.

Ostatni aktywny owner nie może usunąć konta bez przekazania własności albo
osobnej procedury likwidacji całego Workspace. Po usunięciu samego konta audit może
wyświetlać nazwę zachowanej osoby. Po pełnym usunięciu osoby pozostaje wyłącznie
`account_id`/`actor_id` oraz pseudonim w rodzaju `Usunięty użytkownik #A7F2`,
bez imienia, nazwiska i e-maila.

## M4-D15. Role, uprawnienia i lifecycle członkostwa

`Role` jest nazwanym pakietem domyślnych uprawnień, `Permission` pojedynczą
dozwoloną czynnością, a `Membership` uczestnictwem konta w instalacji wraz z
rolą i wyjątkami. MVP ma pięć stałych ról:

| Rola | Tworzenie obiektów | Zapraszanie | Zarządzanie rolami | Trwałe usuwanie | Audit |
|---|---:|---:|---:|---:|---:|
| `owner` | tak | tak | tak | tak | tak |
| `admin` | tak | tak | role poza `owner` | po jawnym nadaniu | tak |
| `member` | tak | nie | nie | nie | nie |
| `restricted_member` | nie | nie | nie | nie | nie |
| `guest` | nie | nie | nie | nie | nie |

Efektywne uprawnienia powstają z pakietu roli, wyjątków `allow`/`deny` na
`Membership` oraz jawnych grantów do konkretnego zasobu albo wrażliwej
wartości. `Deny` ma pierwszeństwo przed `allow`. Przed oceną uprawnień system
sprawdza wyłącznie, czy konto nie jest zablokowane, członkostwo jest aktywne,
a sesja jest ważna. Nie istnieje sprawdzenie „zasób należy do bieżącego
Workspace”, ponieważ instalacja i baza mają tylko jeden Workspace.

Rola `owner` ani `admin` nie daje automatycznie dostępu do prywatnego obiektu
lub wrażliwego `FieldValue`. Dostęp do nich wynika z właściciela wartości oraz
jawnych grantów zgodnych z M4-D12.

Zaproszenie i członkostwo mają odrębne cykle życia. `Invitation` przechodzi
`pending -> accepted / expired / revoked`; akceptacja atomowo tworzy aktywne
`Membership`. Członkostwo przechodzi `active <-> suspended`, a następnie do
końcowego `left` albo `removed`. Zawieszone i zakończone członkostwo nie daje
żadnych uprawnień.

Instalacja może mieć wielu ownerów, ale zawsze co najmniej jednego aktywnego.
Tylko aktywny owner po ponownym uwierzytelnieniu może nadać lub odebrać rolę
`owner`; ostatniego ownera nie można zdegradować, usunąć ani zawiesić.
Administrator może zarządzać rolami niższymi od `owner` i ich wyjątkami, ale
nie może zmieniać ownerów ani likwidować Workspace.

## M4-D16. Fizyczna reprezentacja uprawnień

Uprawnienia nie są przechowywane w JSONB ani w polu z listą. Model wykorzystuje
znormalizowane encje:

| Encja | Odpowiedzialność |
|---|---|
| `Role` | pięć wersjonowanych rekordów systemowych: `owner`, `admin`, `member`, `restricted_member`, `guest` |
| `Permission` | katalog atomowych kluczy, np. `object.create` i `membership.invite` |
| `RolePermission` | domyślny pakiet uprawnień danej roli |
| `MembershipPermissionOverride` | jawne `allow` albo `deny` dla jednego członkostwa i uprawnienia |
| `ObjectAccessGrant` | grant konkretnego członkostwa do prywatnego obiektu |
| `FieldValueAccessGrant` | grant konkretnego członkostwa do wrażliwego `FieldValue` |

`Membership` wskazuje jeden rekord `Role`. Złożone ograniczenia unikalności
zapobiegają dwóm wpisom dla tej samej pary członkostwo–uprawnienie albo
członkostwo–zasób–uprawnienie. `ObjectAccessGrant` i
`FieldValueAccessGrant` są oddzielne, dzięki czemu baza zachowuje prawdziwe
klucze obce; model nie używa polimorficznego `resource_type + resource_id`.

Role, katalog uprawnień i pakiety domyślne są dostarczane wersjonowaną migracją
i nie mogą być edytowane ani usuwane przez API MVP. Administrator zmienia
wyłącznie rolę członkostwa oraz dozwolone wyjątki. Własne role pozostają
odłożone, ale później mogą korzystać z tych samych `RolePermission` bez zmiany
modelu grantów.

Każda zmiana roli, wyjątku lub grantu jest atomowa i audytowana. Odebranie
dostępu obowiązuje natychmiast; cache autoryzacji, jeśli powstanie, musi zostać
unieważniony w tej samej operacji. Końcowy algorytm zachowuje kolejność z
M4-D15: blokada konta lub nieaktywne członkostwo odrzuca operację, a następnie
jawne `deny` wygrywa z każdym `allow`.

## M4-D17. Sesje server-side

MVP nie używa JWT ani pary access/refresh token. Po poprawnym uwierzytelnieniu
Core generuje kryptograficznie losowy, nieprzewidywalny token sesji. Surowa
wartość jest zwracana klientowi tylko raz; PostgreSQL przechowuje jej hash i
rekord `Session` zawierający co najmniej konto, urządzenie, czas utworzenia,
ostatnią aktywność, wygaśnięcie bezczynności, wygaśnięcie bezwzględne oraz czas
i przyczynę unieważnienia.

Przeglądarka otrzymuje token w host-only cookie `HttpOnly`, `Secure`,
`SameSite`, bez wartości w URL i bez dostępu JavaScript. Żądania zmieniające
stan dodatkowo przechodzą ochronę CSRF i kontrolę `Origin`. Przyszły klient
mobilny lub desktopowy używa tego samego rodzaju nieprzezroczystej sesji jako
Bearer tokenu przechowywanego w systemowym Keychain/Keystore, nie w zwykłych
preferencjach aplikacji.

PostgreSQL jest źródłem prawdy dla sesji. Valkey może przyspieszać odczyt, ale
utrata albo wyczyszczenie cache nie może utworzyć ważnej sesji, cofnąć revoke
ani stać się jedyną kopią danych sesyjnych. Dokładne okresy bezczynności i
ważności bezwzględnej definiuje polityka bezpieczeństwa M5.

Token jest obracany po logowaniu, ponownym uwierzytelnieniu i operacji
podwyższenia uprawnień. Wylogowanie, blokada konta, zakończenie członkostwa,
odebranie urządzenia albo peer WireGuard unieważniają właściwe sesje ze
skutkiem natychmiastowym. Każda operacja autoryzowana ponownie ocenia aktualny
stan konta, członkostwa i uprawnień; ważna sesja nie utrwala dawnych praw.

Użytkownik widzi listę własnych sesji i urządzeń oraz może zakończyć wybraną
albo wszystkie poza bieżącą. Utworzenie, rotacja, użycie mechanizmu ponownego
uwierzytelnienia, wylogowanie, revoke i odrzucenie wygasłej sesji są audytowane
bez zapisywania surowego tokenu lub jego wartości możliwej do ponownego użycia.

## M4-D18. Standard identyfikatorów Core

Trwałe encje Core używają PostgreSQL `uuid` generowanego jako UUIDv7. Wartość
powstaje po stronie bazy (`uuidv7()` w PostgreSQL 18), a Prisma mapuje ją jako
`@db.Uuid` z domyślną wartością `dbgenerated("uuidv7()")`. Dotyczy to między
innymi Workspace, Account, Session, Membership, Object, Relation,
FieldDefinition, FieldValue, DocumentReference, Asset i AuditEvent.

UUIDv7 daje globalną unikalność potrzebną przy eksporcie i restore, a dzięki
uporządkowaniu czasowemu ogranicza losowe zapisy indeksu w porównaniu z UUIDv4.
Przybliżony czas zawarty w UUIDv7 nie jest traktowany jako sekret. Każdy odczyt
nadal wymaga autoryzacji; identyfikator nigdy nie pełni roli tokenu dostępu.

Wyjątki są jawne:

- stabilne klucze katalogowe, np. `owner` lub `object.create`, pozostają
  unikalnymi kluczami biznesowymi obok UUIDv7, nie zamiast niego,
- czyste tabele łącznikowe mogą używać klucza złożonego, jeżeli relacja nie ma
  własnego lifecycle, historii ani odwołań zewnętrznych,
- identyfikatory Paperless, jego task UUID i inne identyfikatory integracji są
  przechowywane w polach `external_id`/`external_task_id` wraz z nazwą
  providera; nigdy nie zastępują ID Core,
- `idempotency_key`, token sesji, token zaproszenia i `correlation_id` mają
  osobne znaczenie i nie są identyfikatorami encji.

API przedstawia UUID w kanonicznym zapisie tekstowym. Nie używa sekwencyjnych
`serial`/`bigint` jako publicznych identyfikatorów i nie przyjmuje ID klienta
dla nowo tworzonych encji, poza osobno zaprojektowanym przyszłym trybem
offline/importu.

## M4-D19. Minimalny rekord `Workspace`

`Workspace` jest niewidocznym singletonem technicznym i nie ma własnej nazwy.
Nazwa widoczna jako np. „Dom Kowalskich” należy do `Household Object`.
Minimalny rekord zawiera:

| Pole | Typ pojęciowy | Reguła |
|---|---|---|
| `id` | UUIDv7 | primary key, generowany przez PostgreSQL |
| `singleton_key` | boolean | zawsze `true`, `UNIQUE` oraz `CHECK (singleton_key = true)` |
| `household_object_id` | UUIDv7 nullable | unikalny FK do `Object`; `RESTRICT` dla zwykłego usunięcia |
| `default_timezone` | IANA timezone | wymagane ustawienie instalacji, np. `Europe/Warsaw` |
| `default_locale` | BCP 47 | wymagane ustawienie instalacji, np. `pl-PL` |
| `version` | integer | start `1`, zwiększany przy każdej zmianie |
| `created_at` | timestamptz UTC | ustawiane przez bazę |
| `updated_at` | timestamptz UTC | aktualizowane przy zmianie |

Połączenie stałej wartości, `UNIQUE` i `CHECK` uniemożliwia utworzenie drugiego
rekordu także przy wyścigu dwóch transakcji. `household_object_id` jest puste
po bootstrapie i ustawiane atomowo podczas utworzenia korzenia gospodarstwa.
Ograniczenie FK oraz autoryzowana procedura zapobiegają przypadkowemu usunięciu
korzenia. Szczegółowa migracja musi dodatkowo potwierdzić, że wskazany Object
należy do tej instalacji i ma rolę `household`.

`Workspace` celowo nie przechowuje `name`, `owner_id`, `onboarding_status`,
listy ustawień JSONB ani własnego `workspace_id`. Ownerzy wynikają z aktywnych
Membership, onboarding z faktów opisanych w M4-D03, a nowe istotne ustawienia
otrzymują typowane kolumny lub dedykowaną encję.

`default_timezone` i `default_locale` nie są kolejnymi obowiązkowymi danymi
osobowymi. Instalator lub klient proponuje wartości, zapis następuje podczas
bootstrapu, a owner może je później zmienić z optimistic concurrency i auditem.

## M4-D20. Minimalny rekord `Account`

`Account` reprezentuje wyłącznie techniczną możliwość uwierzytelnienia. Nie
przechowuje imienia, nazwiska, daty urodzenia, adresu, roli ani bezpośredniego
powiązania z osobą. Minimalny rekord zawiera:

| Pole | Typ pojęciowy | Reguła |
|---|---|---|
| `id` | UUIDv7 | primary key |
| `login_email` | email nullable | znormalizowany, unikalny; `NULL` dopiero po pełnym usunięciu |
| `password_hash` | text nullable | pełny hash Argon2id w formacie PHC; `NULL` po usunięciu |
| `status` | enum | `active`, `blocked`, `deletion_pending`, `deleted` |
| `password_changed_at` | timestamptz | wymagane dla aktywnego credentialu |
| `blocked_at` | timestamptz nullable | ustawione tylko dla `blocked` |
| `blocked_reason_code` | ograniczony kod nullable | bez swobodnej prywatnej notatki |
| `deletion_requested_at` | timestamptz nullable | ustawione dla `deletion_pending` |
| `deleted_at` | timestamptz nullable | ustawione tylko dla `deleted` |
| `version` | integer | start `1`, optimistic concurrency |
| `created_at` | timestamptz UTC | ustawiane przez bazę |
| `updated_at` | timestamptz UTC | aktualizowane przy zmianie |

`login_email` jest przy zapisie przycinany i normalizowany do małych liter, a
unikalność obowiązuje dla wszystkich niepustych wartości. Aktywne, zablokowane
i oczekujące na usunięcie konto musi mieć e-mail oraz poprawny hash PHC.
Ograniczenia `CHECK` wiążą status z właściwymi timestampami. Surowe hasło nie
może trafić do bazy, audytu, logu, kolejki ani telemetrycznego kontekstu błędu.

Lifecycle ma postać:

```text
active <-> blocked
   |          |
   +----> deletion_pending ----> deleted
                 |
                 +----> anulowanie i powrót do poprzedniego stanu
```

`Invitation` nie jest stanem konta: konto powstaje dopiero przy zaakceptowaniu
zaproszenia. Poprzedni stan, manifest zależności i potwierdzenia procesu
usuwania należą do `DeletionRequest`, nie do kolejnych pól `Account`.

Po `deleted` `login_email`, `password_hash`, powód blokady i pozostałe dane
credentialu są usuwane. Pozostają `id`, status, znaczniki czasu i bezosobowy
tombstone potrzebny do integralności audytu. Rekord nie może ponownie przejść
do stanu aktywnego ani otrzymać nowego credentialu.

Rola i wyjątki dostępu należą do `Membership`; dane człowieka do powiązanego
`Person Object`; próby logowania do ograniczonego mechanizmu rate limitingu i
audytu. `last_login_at` nie jest duplikowane, ponieważ wynika z sesji i zdarzeń.
Konto nie otrzymuje `workspace_id`: w singletonowej instalacji uczestnictwo i
powiązanie z osobą wyraża `Membership`.

## M4-D21. `Person Object` i `PersonProfile`

Osoba jest zwykłym `Object` kategorii `person`, dzięki czemu korzysta ze
wspólnego lifecycle, dokumentów, assetów, relacji, wyszukiwania, pól i audytu.
Opcjonalne rozszerzenie jeden-do-jednego `PersonProfile` przechowuje wyłącznie
strukturalne części nazwy:

| Pole | Typ pojęciowy | Reguła |
|---|---|---|
| `object_id` | UUIDv7 | jednocześnie PK i FK do `Object` kategorii `person` |
| `first_name` | text nullable | wymagane przed połączeniem osoby z kontem |
| `middle_names` | text nullable | opcjonalne |
| `last_name` | text nullable | wymagane przed połączeniem osoby z kontem |
| `preferred_name` | text nullable | opcjonalna nazwa używana w UI |

Profil nie ma osobnego identyfikatora, lifecycle ani `version`. Zmiana profilu
zwiększa `Object.version`, zapisuje historię i aktualizuje projekcję
`Object.name` w tej samej transakcji. Nazwa wyświetlana powstaje kolejno z
`preferred_name`, imienia i nazwiska albo — dla niepełnego profilu — nazwy
wpisanej podczas tworzenia obiektu. Nie są to dwa niezależne źródła prawdy.

Zwykły `Person Object` może powstać tylko z nazwą i bez `PersonProfile`.
Utworzenie albo połączenie `Account` wymaga wcześniej strukturalnego imienia i
nazwiska. `PersonProfile` nie przechowuje `account_id`, loginu, roli, hasła,
sesji ani uprawnień; powiązanie prowadzi przez `Membership`.

Pozostałe dane osoby są typowanymi `FieldValue`, między innymi data urodzenia,
PESEL, telefon, kontaktowy e-mail, obywatelstwo, numer dokumentu i informacje
medyczne. Pozwala to chronić każdą konkretną wartość oddzielnym oznaczeniem
`sensitive` i grantami z M4-D12, bez globalnego ukrywania definicji pola.

Adres nie jest kopiowany do profilu jako tekst. Osoba wskazuje `Place Object`
relacją `resides_at` z `valid_from`, opcjonalnym `valid_to` i `is_primary`.
Może mieć wiele aktualnych miejsc zamieszkania, ale przy co najmniej jednym
dokładnie jedna aktywna relacja jest główna. Wiele osób może wskazywać to samo
miejsce. Zmiana adresu zamyka poprzednią relację i zachowuje historię.

Klient może zasugerować główne miejsce gospodarstwa, lecz użytkownik jawnie
zatwierdza relację. System nie kopiuje adresu ani nie tworzy trudnego do
odwrócenia dziedziczenia. Widoczność podstawowej tożsamości wynika z ochrony
całego `Person Object`; indywidualna ochrona pozostałych danych działa na
poziomie `FieldValue`.

---

# 3. Analiza procesu `create object`

## 3.1. Postęp uzgodnień

| Punkt | Zakres | Status |
|---:|---|---|
| 1 | aktor operacji | zamknięty — M4-D01 |
| 2 | singleton Workspace i granica instalacji | zamknięty — M4-D02 |
| 3 | encje istniejące, bootstrap, gospodarstwo, miejsca i lifecycle | zamknięty — M4-D03…M4-D06 |
| 4 | encje tworzone przez zwykłe `create object` | zamknięty — M4-D07 |
| 5 | dane wymagane i konflikt duplikatu | zamknięty — M4-D08…M4-D09 |
| 6 | dane opcjonalne | zamknięty — M4-D10 |
| 7 | invariants operacji | zamknięty — M4-D11…M4-D12 |
| 8 | audit | zamknięty — M4-D13 |

## 3.2. Encje wymagane przed zwykłym `create object`

Przed wykonaniem operacji istnieją:

- zainicjalizowany `Workspace`,
- uwierzytelnione `Account`,
- aktywne `Membership`,
- efektywne uprawnienie `object.create`.

Obiekt osoby właściciela powstaje podczas bootstrapu. Fizyczny obiekt miejsca
zamieszkania nie jest technicznym warunkiem utworzenia kolejnego obiektu.
`Household Object` jest wymagany do zakończenia onboardingu, ale jego czasowy
brak nie blokuje pulpitu ani zwykłych operacji.

---

# 4. Otwarte zagadnienia

- dokładne pola i lifecycle wszystkich 20 encji M4,
- pełny katalog kluczy `Permission` i macierz testów trudnych kombinacji
  roli, wyjątków oraz grantów,
- konfigurowalne okresy retencji i blokady zachowania danych,
- dokładny manifest skutków trwałego usunięcia,
- polityka usuwania dokumentów współdzielonych oraz assetów,
- pozostałe 14 procesów MVP.
