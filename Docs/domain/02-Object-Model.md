# 02 — Object Model

## Pełna specyfikacja obiektów, własnych pól, szablonów, relacji i cyklu życia

**Wersja:** 0.2

**Status:** `accepted`

**Zależność:** [`01-Core-Domain-Model.md`](01-Core-Domain-Model.md)

**Priorytet:** krytyczny

> ## Status dokumentu
>
> | Pole | Wartosc |
> |---|---|
> | **Status** | `accepted` |
> | **Priorytet w hierarchii zrodel prawdy** | Szosty z 7 |
> | **Obowiazuje w zakresie** | pelna specyfikacja Object Engine: struktura obiektu, kategorie, typy, dynamiczne pola, sekcje, biblioteka pol, szablony, relacje, tagi, notatki, prywatnosc, statusy, archiwum, kosz, historia, duplikaty, walidacja, przypadki brzegowe, testy akceptacyjne |
> | **Nie obowiazuje w zakresie** | **§32 Import** - import CSV nie wchodzi do MVP (-> wydanie 1.1, R-16). Zapisane widoki i zaawansowane scalanie duplikatow - po MVP (§46) |
> | **Ostatni przeglad** | 2026-07-27 (Faza 0 / M0) |
> | **Rejestr rozbieznosci** | [`discrepancy-register.md`](../architecture/discrepancy-register.md) |
>
> Hierarchia zrodel prawdy: **07 dla kolejnosci, 08 dla zakresu, accepted ADR dla decyzji szczegolowych, nastepnie 06 > 05 > 04 > 03 > 02 > 01**.
> Pelne uzasadnienie: [`00-Analiza-i-Mapa-Realizacji.md`](../00-Analiza-i-Mapa-Realizacji.md), sekcja 8.


***

# 1. Cel dokumentu

Dokument definiuje Object Engine — najważniejszy mechanizm systemu.

Opisuje:

* strukturę obiektu,
* różnicę między osobą i kontem,
* kategorie oraz typy,
* własne pola,
* sekcje,
* szablony,
* pliki,
* relacje,
* tagi,
* terminy,
* historię,
* prywatność,
* archiwizację,
* kosz,
* trwałe usuwanie,
* wyszukiwanie,
* import,
* eksport,
* przygotowanie pod Home Assistant,
* reguły UX,
* model danych,
* API koncepcyjne,
* walidację,
* przypadki brzegowe.

***

# 2. Definicja obiektu

Obiekt jest uniwersalnym rekordem reprezentującym coś, o czym użytkownik chce przechowywać wiedzę.

Może reprezentować byt fizyczny, osobę, miejsce, usługę, dokument logiczny, projekt albo pojęcie.

Przykłady:

* Anna,
* dziecko,
* dr Kowalski,
* Figa,
* Toyota Corolla,
* laptop,
* lodówka,
* sypialnia,
* mieszkanie,
* ubezpieczyciel,
* polisa OC,
* remont kuchni,
* umowa internetu,
* czujnik temperatury,
* kamera wejściowa,
* łóżeczko dziecięce.

Obiekt nie musi odpowiadać osobnej tabeli w bazie. Wszystkie obiekty korzystają ze wspólnego rdzenia i dynamicznych właściwości.

***

# 3. Minimalna struktura obiektu

Minimalne pola systemowe:

|                |                                               |
| -------------- | --------------------------------------------- |
| `id`           | niezmienny identyfikator                      |
| `workspace_id` | właściciel danych                             |
| `name`         | nazwa widoczna                                |
| `status`       | active / archived / trashed                   |
| `created_by`   | konto tworzące                                |
| `created_at`   | data utworzenia                               |
| `updated_at`   | data ostatniej zmiany                         |
| `version`      | wersja optymistycznej kontroli współbieżności |

Pola opcjonalne:

| Pole               | Znaczenie                                    |
| ------------------ | -------------------------------------------- |
| `description`      | opis                                         |
| `category`         | kategoria wysokiego poziomu                  |
| `type_name`        | nazwa typu użytkowego                        |
| `template_id`      | szablon źródłowy                             |
| `owner_person_id`  | osoba odpowiedzialna                         |
| `primary_asset_id` | zdjęcie główne                               |
| `visibility`       | prywatność                                   |
| `archived_at`      | data archiwizacji                            |
| `trashed_at`       | data przeniesienia do kosza                  |
| `metadata`         | dane techniczne niebędące polami użytkownika |

Przykład:

```
{ 
"id": "obj_01JCAR",
 "workspaceId": "ws_home",
 "name": "Toyota Corolla",
 "category": "vehicle",
 "typeName": "Samochód",
 "description": "Samochód rodzinny",
 "status": "active",
 "visibility": "workspace",
 "ownerPersonId": "obj_anna",
 "templateId": "tpl_car",
 "primaryAssetId": "asset_photo",
 "createdBy": "acc_piotr",
 "createdAt": "2026-07-27T10:00:00Z",
 "updatedAt": "2026-07-27T10:15:00Z",
 "version": 4 
}
```

***

# 4. Konto a obiekt osoby

## 4.1. Konto

Konto:

* loguje się,
* ma sesje,
* ma e-mail,
* ma uprawnienia,
* wykonuje akcje,
* może zostać zablokowane.

## 4.2. Obiekt osoby

Obiekt osoby:

* reprezentuje człowieka,
* przechowuje informacje,
* posiada dokumenty,
* ma relacje,
* może istnieć bez konta.

## 4.3. Zasady

* Jedno konto może być połączone z jednym obiektem osoby w danym Workspace.
* Obiekt osoby może nie mieć konta.
* Konto po odłączeniu nie usuwa obiektu osoby.
* Konto nie powinno być przepinane do innej osoby bez procedury administracyjnej i audytu.
* Dziecko może później otrzymać konto połączone z istniejącym obiektem.
* Lekarz, weterynarz i kontakt serwisowy są obiektami osób bez członkostwa.

***

# 5. Kategorie

Kategorie systemowe:

* `person`,
* `animal`,
* `place`,
* `vehicle`,
* `device`,
* `service`,
* `organization`,
* `document_record`,
* `project`,
* `generic`.

Kategoria służy do:

* filtrowania,
* ustawienia ikony,
* dobrania podstawowego widoku,
* sugestii szablonów,
* integracji.

Kategoria nie blokuje własnych pól.

***

# 6. Typ obiektu

Typ jest nazwą użytkową.

Przykłady:

* Samochód,
* Motocykl,
* Laptop,
* Lekarz rodzinny,
* Weterynarz,
* Polisa,
* Umowa,
* Pokój,
* Roleta,
* Czujnik,
* Własny typ.

Użytkownik może:

* wybrać istniejący typ,
* wpisać nowy,
* zapisać typ jako szablon,
* zmienić typ istniejącego obiektu.

Zmiana typu nie może automatycznie usuwać pól.

***

# 7. Nazwa, opis, ikona i zdjęcie

## 7.1. Nazwa

* jedyne wymagane pole użytkowe,
* nie jest globalnym kluczem unikalnym,
* powinna mieć limit długości,
* może zawierać znaki narodowe.

System normalizuje nazwę na potrzeby porównania. Taka sama nazwa bez
wiarygodnej informacji rozróżniającej zatrzymuje zapis i wskazuje istniejący
obiekt. Taka sama nazwa pozostaje dozwolona dla różnych egzemplarzy, jeżeli
pole lub zestaw pól identyfikujących/rozróżniających potwierdza różnicę.

Ten sam silny identyfikator egzemplarza, np. VIN albo numer seryjny, odrzuca
utworzenie. Różnica wyłącznie w opisie nie wystarcza do uznania obiektu za
odrębny. Dokumenty i relacje wskazują niezmienny `Object.id`, nigdy nazwę.

## 7.2. Opis

Opis jest opcjonalny, może obsługiwać podstawowy Markdown.

## 7.3. Ikona

Źródła:

* ikona kategorii,
* ikona szablonu,
* emoji,
* ikona wybrana przez użytkownika.

## 7.4. Zdjęcie główne

Może być:

* załadowanym zdjęciem,
* miniaturą pliku,
* obrazem pobranym z integracji,
* zdjęciem urządzenia.

***

# 8. Dynamiczne pola

## 8.1. Definicja

Dynamiczne pole składa się z definicji i wartości.

Definicja określa:

* etykietę,
* klucz techniczny,
* typ danych,
* sekcję,
* kolejność,
* rolę pola (`suggested`, `identity_strong`, `identity_supporting`),
* wielowartościowość,
* walidację,
* prywatność,
* indeksowanie,
* sposób prezentacji.

Dynamiczne pole nie jest warunkiem istnienia obiektu. System waliduje jego
format dopiero wtedy, gdy użytkownik poda wartość. Wyjątkiem procesowym jest
nierozstrzygnięty konflikt duplikatu: zapis może wymagać uzupełnienia pola
identyfikującego albo rozróżniającego, lecz pole nie staje się przez to
globalnie obowiązkowe dla wszystkich obiektów danego typu.

## 8.2. Typy pól MVP

### Tekst krótki

Przykłady:

* VIN,
* model,
* numer seryjny.

### Tekst długi

Przykłady:

* historia napraw,
* zalecenia lekarza.

### Liczba

Przykłady:

* przebieg,
* pojemność,
* wzrost.

### Liczba z jednostką

Przykłady:

* 16 GB,
* 120 m²,
* 36,6 °C.

Jednostka powinna być przechowywana osobno.

### Data

Przykłady:

* data zakupu,
* data urodzenia,
* koniec gwarancji.

### Data i czas

Przykłady:

* wizyta,
* odbiór serwisowy.

### Tak/Nie

Przykłady:

* aktywna gwarancja,
* urządzenie przenośne.

### Lista jednokrotna

Przykład: stan techniczny.

### Lista wielokrotna

Przykład: obsługiwane protokoły.

### E-mail

Walidowany, klikalny.

### Telefon

Format przechowywany w możliwie znormalizowanej postaci.

### URL

Bezpieczne linkowanie.

### Adres

Może początkowo być tekstem złożonym, później strukturą.

### Relacja

Kontrolka pozwalająca wybrać inny obiekt. Wynik jest zapisywany jako osobna
encja `Relation`, a nie jako `FieldValue`.

### Plik

Kontrolka załącznika albo zestawu załączników. Dokument jest zapisywany przez
`DocumentReference` i `ObjectDocumentLink`, a pozostałe media przez `Asset`;
binaria ani ich powiązania nie są `FieldValue`.

### Sekret / dane wrażliwe

Domyślnie zamaskowane i zabezpieczone dodatkowymi regułami.

## 8.3. Typy przyszłe

* lokalizacja,
* waluta,
* zakres dat,
* formuła,
* dane z integracji,
* stan Home Assistant,
* kod QR,
* kod kreskowy.

***

# 9. Struktura definicji pola

```
{ 
  "id": "fld_vin", 
  "workspaceId": "ws_home", 
  "label": "VIN", 
  "key": "vin", 
  "dataType": "text", 
  "role": "identity_strong", 
  "suggested": true, 
  "multiple": false, 
  "searchable": true, 
  "placeholder": "17 znaków", 
  "helpText": "Numer identyfikacyjny pojazdu", 
  "validation": { 
    "minLength": 17, 
    "maxLength": 17, 
    "pattern": "^[A-HJ-NPR-Z0-9]{17}$" 
  }, 
  "display": { 
    "sectionId": "technical", 
    "order": 10 
  } 
}
```

***

# 10. Wartość pola

```
{ 
  "id": "val_01", 
  "objectId": "obj_car", 
  "fieldDefinitionId": "fld_vin", 
  "valueText": "JTDBR32E123456789", 
  "source": "user", 
  "confidence": null, 
  "approved": true, 
  "protection": "normal", 
  "updatedBy": "acc_piotr", 
  "updatedAt": "2026-07-27T10:15:00Z" 
 }
```

Źródło:

* user,
* import,
* integration,
* OCR,
* AI,
* system.

Dla OCR i AI:

* poziom pewności,
* źródłowy plik,
* fragment źródłowy,
* status zatwierdzenia.

***

# 11. Biblioteka pól

Aby uniknąć chaosu, Workspace może posiadać bibliotekę definicji pól.

Przykład: jedno pole „Numer seryjny” może być używane w wielu szablonach.

Korzyści:

* spójne nazwy,
* wspólna walidacja,
* lepsze wyszukiwanie,
* mniej duplikatów.

System powinien wykrywać podobne etykiety:

* Numer seryjny,
* nr seryjny,
* S/N.

Może sugerować użycie istniejącego pola, ale nie blokować własnej decyzji użytkownika.

***

# 12. Sekcje

Pola są organizowane w sekcje.

Przykłady:

* Podstawowe,
* Dane techniczne,
* Zakup i gwarancja,
* Kontakt,
* Zdrowie,
* Dokumenty,
* Integracje,
* Notatki.

Sekcja zawiera:

* ID,
* nazwę,
* opis,
* kolejność,
* stan domyślnego rozwinięcia.

Użytkownik może:

* dodawać sekcje,
* zmieniać kolejność,
* przenosić pola,
* ukrywać puste sekcje.

***

# 13. Szablony

## 13.1. Definicja

Szablon jest zestawem ustawień startowych.

Zawiera:

* nazwę,
* kategorię,
* sugerowany typ,
* ikonę,
* pola,
* oznaczenie pól silnie identyfikujących i rozróżniających,
* sekcje,
* sugerowane tagi,
* sugerowane relacje,
* sugerowane terminy.

## 13.2. Typy szablonów

* systemowe,
* Workspace,
* utworzone przez użytkownika,
* skopiowane z obiektu.

## 13.3. Szablon miękki

Po utworzeniu obiektu pola są kopiowane lub wiązane w sposób umożliwiający niezależną edycję.

Zmiana szablonu nie powinna nieoczekiwanie modyfikować istniejących obiektów.

Aktualizacja szablonu może oferować:

* zastosuj tylko do nowych obiektów,
* zaproponuj aktualizację istniejących,
* nie zmieniaj istniejących.

## 13.4. Sugestia klasyfikacji

W MVP lokalne reguły i słowniki mogą na podstawie nazwy zaproponować kategorię,
typ, szablon i początkowe wartości. Użytkownik zawsze zatwierdza albo zmienia
sugestię. Niejednoznaczne dopasowanie pokazuje wybór, a brak dopasowania nie
blokuje utworzenia obiektu bez typu.

Mechanizm nie używa AI w MVP. Kategoria nie narzuca pól; dopasowany szablon
proponuje pola opcjonalne. System nie tworzy automatycznie tagu powtarzającego
kategorię lub typ.

## 13.5. Przykładowe szablony MVP

### Osoba

* imię,
* nazwisko,
* data urodzenia,
* telefon,
* e-mail,
* adres,
* kontakt awaryjny.

### Samochód

* marka,
* model,
* rok,
* VIN,
* numer rejestracyjny,
* przebieg,
* data przeglądu,
* koniec polisy.

### Zwierzę

* gatunek,
* rasa,
* data urodzenia,
* numer chipa,
* weterynarz,
* data szczepienia.

### Urządzenie

* producent,
* model,
* numer seryjny,
* data zakupu,
* gwarancja,
* lokalizacja.

### Lekarz

* specjalizacja,
* telefon,
* e-mail,
* adres,
* godziny przyjęć.

***

# 14. Tworzenie obiektu

## 14.1. Szybki tryb

1. Nazwa.
2. Opcjonalny typ.
3. Zapis.

## 14.2. Tryb rozszerzony

1. Wybór szablonu.
2. Nazwa.
3. Kategoria i typ.
4. Pola.
5. Zdjęcie.
6. Pliki.
7. Relacje.
8. Termin.
9. Prywatność.
10. Zapis.

## 14.3. Zapis szkicu

Obiekt może być zapisany jako szkic, jeśli formularz jest niekompletny.

***

# 15. Edycja obiektu

Edycja powinna obsługiwać:

* autosave albo jawny zapis,
* kontrolę konfliktów,
* historię zmian,
* cofnięcie ostatnich zmian w rozsądnym zakresie,
* dodawanie pól bez przechodzenia do administracji,
* zmianę kolejności.

Współbieżność:

* pole `version`,
* ostrzeżenie przy konflikcie,
* możliwość porównania zmian.

***

# 16. Widok obiektu

Proponowany układ:

1. Nagłówek: nazwa, ikona, status, szybkie akcje.
2. Informacje podstawowe.
3. Sekcje pól.
4. Pliki.
5. Relacje.
6. Terminy.
7. Notatki.
8. Historia.
9. Integracje.

Widok powinien ukrywać puste sekcje i prezentować najważniejsze informacje bez przewijania przez pusty formularz.

***

# 17. Pliki

## 17.1. Powiązanie

Obiekt i plik łączy rekord przypięcia.

Jeden plik może być przypięty do wielu obiektów.

## 17.2. Role pliku

* dokument,
* zdjęcie,
* instrukcja,
* faktura,
* gwarancja,
* polisa,
* wynik badania,
* załącznik ogólny.

## 17.3. Upload

Wymagania:

* pasek postępu,
* obsługa kilku plików,
* walidacja rozmiaru,
* walidacja typu,
* checksum,
* retry,
* anulowanie,
* informacja o błędzie.

## 17.4. Pliki osierocone

Plik bez przypięcia jest dozwolony, ale powinien być widoczny na liście „Do uporządkowania”.

***

# 18. Relacje

## 18.1. Model

Relacja:

* źródło,
* typ,
* cel,
* nazwa odwrotna,
* okres obowiązywania,
* status,
* notatka.

## 18.2. Typy relacji

Systemowe przykłady:

* posiada / należy do,
* opiekuje się / jest pod opieką,
* znajduje się w / zawiera,
* dotyczy / ma powiązanie,
* jest lekarzem / jest pacjentem,
* jest rodzicem / jest dzieckiem,
* jest częścią / składa się z.

Użytkownik może stworzyć własny typ.

## 18.3. Zasady

* brak relacji obiektu do samego siebie, chyba że wyraźnie dozwolone,
* wykrywanie duplikatów,
* usunięcie relacji nie usuwa obiektów,
* archiwizacja obiektu zachowuje relacje,
* relacje historyczne mogą mieć daty.

***

# 19. Tagi

Tag:

* należy do Workspace,
* ma nazwę,
* opcjonalny opis,
* opcjonalną ikonę.

Zasady:

* porównywanie bez uwzględniania wielkości liter,
* możliwość scalenia,
* możliwość zmiany nazwy,
* brak automatycznego usuwania obiektów po usunięciu tagu.

***

# 20. Notatki

Obiekt może mieć:

* jedną notatkę główną,
* wiele wpisów dziennika.

Wpis dziennika:

* autor,
* data,
* treść,
* załączniki,
* opcjonalny typ.

Przykłady:

* naprawa,
* wizyta,
* obserwacja,
* zakup,
* serwis.

***

# 21. Terminy i przypomnienia

Termin może pochodzić z:

* pola daty,
* oddzielnego rekordu,
* dokumentu,
* integracji.

Przypomnienie zawiera:

* datę,
* odbiorców,
* wyprzedzenie,
* powtarzalność,
* kanał,
* status.

Statusy:

* zaplanowane,
* wysłane,
* odroczone,
* wykonane,
* anulowane.

Usunięcie pola daty powinno zapytać, co zrobić z przypomnieniem.

***

# 22. Prywatność

Widoczność całego obiektu określa, kto może go otworzyć. Domyślna wartość to
`workspace`; użytkownik może wybrać `private`. Dokładne role, granty i wariant
`restricted` definiuje model Permissions and Privacy.

Ochrona wartości pola jest niezależna od widoczności obiektu. `sensitive`
należy do konkretnego `FieldValue`, nie do globalnego `FieldDefinition`.
Wartości tej samej definicji w różnych obiektach mogą mieć odmienne listy
dostępu.

Wartość wrażliwa:

* jest domyślnie zamaskowana,
* ma jawne prawa odczytu, edycji i zarządzania dostępem,
* nie staje się dostępna administratorowi ani krewnemu wyłącznie z powodu roli
  lub relacji rodzinnej,
* nie ujawnia treści w indeksie, logach, powiadomieniach, błędach ani audycie,
* rejestruje w audycie ujawnienie, zmianę oraz zmianę dostępu.

Szablon może zasugerować ochronę nowej wartości, ale nie zmienia globalnie
definicji ani istniejących wartości.

Przykłady danych wrażliwych:

* dokumentacja medyczna,
* PESEL,
* skany dokumentów,
* dane finansowe,
* hasła i sekrety.

***

# 23. Własność i odpowiedzialność

`owner_person_id` oznacza osobę odpowiedzialną lub głównego właściciela obiektu.

Nie jest to równoznaczne z prawami dostępu.

Obiekt może mieć wielu właścicieli przez relacje.

Przykład:

* samochód należy do Anny i Piotra,
* `owner_person_id` może wskazywać osobę odpowiedzialną za dokumenty,
* relacje opisują współwłasność.

***

# 24. Statusy

Minimalny model:

* `active`,
* `archived`,
* `trashed`.

Opcjonalny status użytkowy może być osobnym polem:

* sprawny,
* w naprawie,
* sprzedany,
* pożyczony.

Nie należy mieszać cyklu życia rekordu ze stanem biznesowym.

***

# 25. Archiwizacja

Archiwizacja:

* nie usuwa danych,
* zachowuje pliki,
* zachowuje relacje,
* ukrywa z aktywnych widoków,
* może wyłączyć przypomnienia po pytaniu,
* rejestruje autora i powód.

Opcjonalny powód:

* sprzedany,
* oddany,
* wyprowadzka,
* zakończony,
* duplikat,
* nieużywany,
* inny.

***

# 26. Kosz

Kosz przechowuje:

* obiekt,
* pola,
* pliki przez powiązania,
* relacje,
* historię.

Widok kosza pokazuje:

* datę usunięcia,
* osobę,
* termin trwałego usunięcia,
* zależności,
* możliwość przywrócenia.

***

# 27. Trwałe usuwanie

Przed usunięciem:

* policz pliki,
* policz relacje,
* sprawdź współdzielone zasoby,
* anuluj przypomnienia,
* pokaż skutki,
* wymagaj potwierdzenia.

Dla danych krytycznych można wymagać ponownego uwierzytelnienia.

***

# 28. Historia

Historia obiektu obejmuje:

* utworzenie,
* zmianę danych,
* zmianę widoczności,
* dodanie/usunięcie pola,
* zmianę wartości,
* pliki,
* relacje,
* terminy,
* archiwizację,
* kosz,
* przywrócenie.

Dokładne stare i nowe wartości zwykłych pól należą do historii obiektu, nie do
trwałego `AuditEvent`. Historia jest zachowywana w archiwum i koszu, a usuwana
wraz z treścią podczas trwałego usunięcia. Audit pozostawia wtedy strukturę
operacji oraz tombstone.

Wartość wrażliwa nigdy nie trafia do audytu ani historii jako jawna treść lub
skrót. Rejestrowany jest wyłącznie rodzaj działania, np. zmiana, ujawnienie,
nadanie albo odebranie dostępu.

***

# 29. Wyszukiwanie i indeksowanie

Indeksowane:

* nazwa,
* opis,
* typ,
* kategoria,
* tagi,
* tekstowe wartości pól,
* nazwy plików,
* notatki.

Pola mogą mieć flagę `searchable`.

Wartości oznaczone `sensitive` nie są umieszczane w zwykłym indeksie treści.

***

# 30. Sortowanie i filtrowanie

Sortowanie:

* nazwa,
* ostatnia zmiana,
* data utworzenia,
* najbliższy termin,
* typ.

Filtrowanie:

* kategoria,
* typ,
* status,
* tag,
* właściciel,
* prywatność,
* posiada pliki,
* posiada termin,
* zintegrowany z Home Assistant.

Widoki zapisane mogą być funkcją późniejszą.

***

# 31. Duplikaty

System może wykrywać potencjalne duplikaty po:

* nazwie,
* numerze seryjnym,
* VIN,
* identycznym pliku,
* podobnych polach.

Działania:

* zignoruj,
* połącz,
* scal wybrane dane,
* zachowaj oba.

Scalanie musi być audytowane i odwracalne w bezpiecznym zakresie.

***

# 32. Import

> **POZA ZAKRESEM MVP (07 §6)** - import CSV i import masowy przesuniete do wydania 1.1 (R-16).
> Kontrakt zachowania importu masowego pozostaje aktualny w `workflows/06-System-Workflows.md` §26
> jako specyfikacja do pozniejszej implementacji.

MVP może obsługiwać:

* import CSV,
* upload plików,
* później import folderów.

Import CSV powinien:

* mapować kolumny do pól,
* tworzyć nowe pola,
* pokazywać podgląd,
* wykrywać błędy,
* pozwalać anulować,
* raportować wynik.

***

# 33. Eksport

Eksport pojedynczego obiektu:

* JSON,
* Markdown lub PDF jako raport,
* paczka plików.

Eksport Workspace:

* obiekty,
* definicje pól,
* wartości,
* relacje,
* tagi,
* notatki,
* terminy,
* pliki,
* manifest checksum.

***

# 34. Home Assistant

Obiekt urządzenia może mieć powiązanie integracyjne.

Rekord integracji:

* provider,
* external\_device\_id,
* external\_entity\_ids,
* status,
* ostatnia synchronizacja,
* mapowanie funkcji.

Zasady:

* dane opisowe należą do Core,
* stan urządzenia należy do Home Assistant,
* usunięcie integracji nie usuwa obiektu,
* usunięcie obiektu nie musi usuwać urządzenia z HA,
* użytkownik decyduje o zachowaniu.

***

# 35. API koncepcyjne

Przykładowe operacje:

```
POST /workspaces/{id}/objects 
GET /workspaces/{id}/objects 
GET /objects/{id} PATCH /objects/{id} 
POST /objects/{id}/archive 
POST /objects/{id}/restore 
DELETE /objects/{id} 
POST /objects/{id}/fields 
PATCH /objects/{id}/fields/{fieldId} 
POST /objects/{id}/assets 
POST /objects/{id}/relations 
GET /objects/{id}/history
```

API powinno:

* sprawdzać Workspace,
* sprawdzać uprawnienia,
* używać idempotency key dla wybranych operacji,
* obsługiwać wersję rekordu,
* zwracać czytelne błędy.

***

# 36. Proponowany model tabel

Koncepcyjnie:

* `objects`,
* `object_categories`,
* `object_types`,
* `field_definitions`,
* `field_values`,
* `object_sections`,
* `templates`,
* `template_fields`,
* `assets`,
* `object_assets`,
* `relations`,
* `relation_types`,
* `tags`,
* `object_tags`,
* `notes`,
* `reminders`,
* `audit_events`,
* `integration_links`.

Dynamiczne pola można implementować przez:

* EAV,
* JSONB,
* model hybrydowy.

Preferowany kierunek: model hybrydowy.

* rdzeń obiektu w normalnych kolumnach,
* definicje pól w tabeli,
* wartości użytkowe w typowanych rekordach `FieldValue`,
* indeksowane pola wybrane osobno.

JSONB jest dopuszczalny wyłącznie dla wersjonowanych danych technicznych,
pochodzenia sugestii lub ładunku integracji, którego struktury Core nie jest
właścicielem. Nie przechowuje się w nim zwykłych pól użytkownika,
identyfikatorów egzemplarzy, relacji, tagów, powiązań dokumentów, sekretów ani
danych wymagających wyszukiwania i reguł integralności.

Ostateczna decyzja należy do dokumentu bazy danych.

***

# 37. Walidacja

Walidacja obejmuje:

* długości,
* format,
* zakres liczbowy,
* dozwolone opcje,
* liczbę wartości,
* reguły pola identyfikującego przy rozstrzyganiu konfliktu duplikatu,
* unikalność w określonym zakresie.

Błąd powinien być:

* czytelny,
* przypisany do pola,
* możliwy do naprawienia,
* bez utraty wprowadzonych danych.

***

# 38. Bezpieczeństwo

Object Engine musi zapobiegać:

* odczytowi obcego Workspace,
* zmianie pól bez uprawnień,
* uploadowi niebezpiecznych plików,
* wstrzyknięciom,
* XSS w notatkach,
* wyciekom danych w historii,
* przypadkowemu trwałemu usunięciu,
* eskalacji roli przez pole formularza,
* manipulacji identyfikatorami integracji.

***

# 39. UX

Zasady:

* szybkie dodawanie,
* brak obowiązkowych zbędnych pól,
* gotowe szablony,
* własne pola w tym samym widoku,
* jasna różnica między archiwizacją i usunięciem,
* wyraźne stany prywatności,
* podgląd pliku bez opuszczania obiektu,
* dobre działanie na telefonie,
* nieukrywanie krytycznych akcji w nieczytelnych menu.

***

# 40. Przypadki brzegowe

## Obiekt bez typu

Dozwolony.

## Obiekt bez plików

Dozwolony.

## Obiekt o tej samej nazwie

Bez wiarygodnej informacji rozróżniającej zapis jest zatrzymany. Inny egzemplarz
o tej samej nazwie jest dozwolony po wskazaniu danych rozróżniających. Ten sam
silny identyfikator odrzuca utworzenie i wskazuje istniejący obiekt.

## Usunięty szablon

Istniejące obiekty pozostają.

## Usunięta definicja pola

Wartości powinny zostać zarchiwizowane albo wymagać decyzji.

## Usunięty użytkownik

Jeżeli usunięto tylko konto, historia może wyświetlać nazwę zachowanego obiektu
osoby. Jeżeli usunięto również osobę i jej dane, pozostaje niezmienny
identyfikator oraz pseudonim, bez imienia, nazwiska i e-maila.

## Plik przypięty do kilku obiektów

Nie jest usuwany po odpięciu z jednego.

## Obiekt osoby z aktywnym kontem

Nie może być trwale usunięty przez zwykłe `delete object`. Wymaga procesu
usunięcia konta i osoby: rozwiązania członkostwa, manifestu zależności,
retencji, ponownego uwierzytelnienia i potrójnej bramy. Inne obiekty i
dokumenty współdzielone nie są usuwane kaskadowo.

## Archiwalny obiekt z przypomnieniem

System pyta, czy przypomnienie pozostawić.

## Relacja do obiektu w koszu

Powinna być widoczna jako zerwana lub oczekująca na przywrócenie.

***

# 41. Testy akceptacyjne MVP

1. Utworzenie obiektu z samą nazwą.
2. Utworzenie z szablonu.
3. Dodanie własnego pola.
4. Zmiana typu bez utraty danych.
5. Dodanie pliku.
6. Przypięcie tego samego pliku do dwóch obiektów.
7. Utworzenie relacji.
8. Wyszukanie po własnym polu.
9. Ustawienie prywatności.
10. Archiwizacja.
11. Przywrócenie.
12. Przeniesienie do kosza.
13. Odzyskanie z kosza.
14. Trwałe usunięcie.
15. Konflikt równoczesnej edycji.
16. Próba wykonania operacji bez wymaganego uprawnienia.
17. Eksport obiektu.
18. Utworzenie konta dla istniejącego obiektu dziecka.
19. Odłączenie konta bez usunięcia osoby.
20. Mapowanie urządzenia Home Assistant w fazie integracyjnej.

***

# 42. Kryteria Definition of Done

Object Engine jest gotowy do MVP, gdy:

* można utworzyć obiekt bez kodowania nowego typu,
* można użyć szablonu,
* można dodać własne pole,
* można dołączyć pliki,
* można utworzyć relacje,
* można wyszukać obiekt,
* działa prywatność,
* działa historia,
* działa archiwum,
* działa kosz,
* trwałe usunięcie jest bezpieczne,
* dane są izolowane przez Workspace,
* eksport jest możliwy,
* podstawowe testy są automatyczne.

***

# 43. Przykład kompletny — samochód

```
{ 
  "object": { 
    "id": "obj_car", 
    "name": "Toyota Corolla", 
    "category": "vehicle", 
    "typeName": "Samochód", 
    "status": "active", 
    "visibility": "workspace" 
  }, 
  "fields": { 
    "marka": "Toyota", 
    "model": "Corolla", 
    "vin": "JTDBR32E123456789", 
    "rejestracja": "WA 12345", 
    "przebieg": { 
      "value": 125000, 
      "unit": "km" 
    }, 
    "koniecPolisy": "2027-04-15" 
  }, 
  "relations": [ 
    { 
      "type": "owned_by", 
      "target": "obj_anna" 
    } 
  ], 
  "assets": [ 
    "asset_registration", 
    "asset_policy", 
    "asset_invoice" 
  ], 
  "reminders": [
    { 
      "sourceField": "koniecPolisy", 
      "offsetDays": 30 
    } 
  ] 
}
```

***

# 44. Przykład kompletny — osoba i lekarz

Osoba:

* nazwa: Anna Kowalska,
* kategoria: osoba,
* konto: połączone,
* prywatność: właściciel i administrator,
* pliki: wyniki badań,
* relacja: lekarz rodzinny,
* termin: kolejna wizyta.

Lekarz:

* nazwa: dr Jan Kowalski,
* typ: lekarz rodzinny,
* telefon,
* adres,
* godziny,
* relacja do Anny,
* brak konta.

***

# 45. Przykład kompletny — komputer dziecka

* obiekt: „Komputer Kuby”,
* typ: komputer,
* właściciel: Kuba,
* pola: procesor, RAM, karta graficzna, numer seryjny,
* pliki: faktura, gwarancja,
* termin: koniec gwarancji,
* uprawnienia: Kuba może edytować, nie może trwale usunąć,
* po sprzedaży: archiwizacja z powodem „sprzedany”.

***

# 46. Dalszy rozwój Object Engine

Po MVP:

* dziedziczenie szablonów,
* masowa edycja,
* zapisane widoki,
* formuły,
* automatyczne pola,
* OCR,
* AI,
* reguły,
* integracje,
* import z Home Assistant,
* wersjonowanie całego obiektu,
* zaawansowane scalenie duplikatów,
* publiczne linki z wygasaniem,
* obsługa offline.

***

# 47. Podsumowanie

Object Engine musi zapewnić równowagę pomiędzy prostotą i elastycznością.

Użytkownik powinien móc w ciągu kilkunastu sekund stworzyć dowolny obiekt, a później stopniowo go rozbudowywać.

Najważniejsze zasady:

1. Obiekt wymaga tylko nazwy.
2. Typ pomaga, ale nie ogranicza.
3. Szablon podpowiada, ale nie narzuca.
4. Pola są dynamiczne.
5. Konto i osoba są odrębne.
6. Pliki mogą być współdzielone między obiektami.
7. Relacje budują kontekst.
8. Archiwizacja zachowuje historię.
9. Trwałe usuwanie jest świadome.
10. Model przygotowuje integracje, ale nie komplikuje MVP.
