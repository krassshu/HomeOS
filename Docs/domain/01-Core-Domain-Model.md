# 01 – Core Domain Model

# Fundament domowej platformy zarządzania informacjami, dokumentami i urządzeniami

**Wersja:** 0.3

**Status:** `accepted (domena) / deprecated (warstwa techniczna)`

**Zakres:** wizja produktu, model domenowy, granice systemu, moduły, role, bezpieczeństwo, roadmap

**Priorytet:** krytyczny

**Dokument nadrzędny:** dla domeny; nie dla technologii ani roadmapy

> ## Status dokumentu
>
> | Pole | Wartosc |
> |---|---|
> | **Status** | `accepted (domena) / deprecated (warstwa techniczna)` |
> | **Priorytet w hierarchii zrodel prawdy** | Najnizszy - 7 z 7 |
> | **Obowiazuje w zakresie** | wizja produktu, model domenowy, obiekt jako jednostka centralna, Workspace, rozdzial konta i osoby, role, cykl zycia, filozofia rozwoju, przypadki uzycia, kryteria sukcesu MVP |
> | **Nie obowiazuje w zakresie** | **§30 Architektura logiczna** i **§32 Roadmap** - zastapione przez 03, 05 i 07. §22 (OCR jako przyszlosc) - zastapione: OCR Paperless wchodzi do MVP. §36 (lista dokumentow) - zastapiona przez 07 §29 |
> | **Ostatni przeglad** | 2026-07-27 (Faza 0 / M0) |
> | **Rejestr rozbieznosci** | [`discrepancy-register.md`](../architecture/discrepancy-register.md) |
>
> Hierarchia zrodel prawdy: **07 dla kolejnosci, 08 dla zakresu, accepted ADR dla decyzji szczegolowych, nastepnie 06 > 05 > 04 > 03 > 02 > 01**.
> Pelne uzasadnienie: [`00-Analiza-i-Mapa-Realizacji.md`](../00-Analiza-i-Mapa-Realizacji.md), sekcja 8.


***

# 1. Cel dokumentu

Ten dokument definiuje fundament całego projektu. Jego zadaniem nie jest opisanie pojedynczego ekranu, tabeli bazy danych ani konkretnego frameworka. Ma ustalić wspólny sposób myślenia o systemie, tak aby kolejne moduły nie powstawały jako niezależne, niespójne aplikacje.

Dokument odpowiada na pytania:

* jaki problem ma rozwiązać aplikacja,
* kim jest jej użytkownik,
* co jest najważniejszą jednostką danych,
* czym różnią się konto, domownik, osoba i obiekt,
* jak organizowane są dokumenty,
* jak działa Workspace,
* jak zachować elastyczność bez budowania pełnej platformy no-code,
* w jaki sposób później podłączyć Home Assistant, kamery, kalendarze i AI,
* gdzie przebiega granica pierwszej wersji,
* czego świadomie nie implementujemy na początku,
* jakie zasady muszą obowiązywać w całym systemie.

Każdy przyszły dokument powinien być zgodny z tym modelem. Jeżeli rozwój produktu wymusi zmianę założeń, zmiana powinna zostać opisana jako świadoma decyzja architektoniczna, a nie jako przypadkowy wyjątek w kodzie.

***

# 2. Jednozdaniowa wizja

> System jest prywatnym, domowym centrum wiedzy i zarządzania, w którym osoby, rzeczy, miejsca, dokumenty, terminy i urządzenia są połączone w jeden czytelny model.

W pierwszej wersji system jest przede wszystkim cyfrowym segregatorem domu. W dalszych etapach może stać się domowym panelem operacyjnym, integrującym dokumenty, przypomnienia, Home Assistant, urządzenia Smart Home, kamery oraz lokalne AI.

***

# 3. Problem, który rozwiązujemy

Informacje związane z domem i rodziną są rozproszone:

* dokumenty papierowe znajdują się w segregatorach,
* skany leżą w losowych folderach,
* faktury są w poczcie,
* dokumentacja medyczna jest podzielona między PDF-y, aplikacje i papier,
* dane lekarzy są w kontaktach albo notatkach,
* informacje o zwierzęciu są w książeczce zdrowia,
* polisy i gwarancje mają terminy, o których łatwo zapomnieć,
* instrukcje urządzeń są na stronach producentów,
* urządzenia Smart Home działają w kilku aplikacjach,
* kamery mają osobne panele,
* kalendarz nie zna kontekstu dokumentów i przedmiotów,
* wyszukiwarka systemowa nie rozumie, że faktura dotyczy konkretnej lodówki,
* członkowie rodziny nie zawsze wiedzą, gdzie znaleźć potrzebną informację.

Problemem nie jest tylko brak miejsca na pliki. Problemem jest brak kontekstu, relacji i jednego punktu dostępu.

Plik o nazwie `scan_0032.pdf` ma niewielką wartość. Ten sam plik staje się użyteczny, gdy system wie, że:

* jest polisą OC,
* dotyczy konkretnego samochodu,
* obowiązuje od określonej daty,
* wygasa w określonym terminie,
* powinien wygenerować przypomnienie,
* należy do rodziny,
* zastępuje poprzednią polisę,
* może być znaleziony z poziomu samochodu, właściciela, ubezpieczyciela, daty lub wyszukiwarki.

System ma zatem przechowywać nie tylko dane, lecz także ich znaczenie.

***

# 4. Główna zasada domenowa

Najważniejszą jednostką systemu jest **obiekt**.

Obiekt reprezentuje dowolny element życia, o którym użytkownik chce przechowywać informacje.

Przykłady:

* domownik,
* dziecko,
* lekarz,
* weterynarz,
* pies,
* samochód,
* komputer,
* lodówka,
* łóżeczko dziecięce,
* pokój,
* mieszkanie,
* polisa,
* umowa,
* dostawca internetu,
* router,
* czujnik,
* roleta,
* kamera,
* projekt remontowy,
* konto usługowe,
* dowolna rzecz utworzona przez użytkownika.

Obiekt może mieć:

* nazwę,
* opis,
* kategorię,
* własne pola,
* zdjęcie,
* pliki,
* notatki,
* terminy,
* przypomnienia,
* tagi,
* relacje z innymi obiektami,
* historię zmian,
* prywatność,
* status cyklu życia,
* w przyszłości powiązanie z Home Assistant albo inną integracją.

Obiekt może istnieć z samą nazwą. Wszystkie pozostałe informacje są opcjonalne.

***

# 5. Czym system jest

System jest:

* cyfrowym segregatorem gospodarstwa domowego,
* katalogiem domowników i rzeczy,
* repozytorium dokumentów,
* miejscem przechowywania wiedzy o domu,
* prostym systemem przypomnień,
* warstwą kontekstową nad plikami,
* przyszłym panelem integrującym Home Assistant,
* prywatnym i samodzielnie hostowanym rozwiązaniem,
* systemem rozwijanym etapami,
* narzędziem dla zwykłego użytkownika, a nie tylko administratora IT.

***

# 6. Czym system nie jest

W pierwszym etapie system nie jest:

* publicznym SaaS-em,
* pełnym ERP,
* CRM-em,
* korporacyjnym DMS-em,
* pełną platformą no-code,
* konkurencją dla Home Assistant,
* własnym systemem NVR pisanym od zera,
* autonomicznym agentem AI,
* systemem księgowym,
* systemem medycznym,
* systemem bankowym,
* zamiennikiem całego ekosystemu Google lub Apple,
* platformą zaprojektowaną od razu dla tysięcy organizacji.

Model może być na tyle uniwersalny, aby kiedyś obsłużyć małą firmę albo JDG, ale pierwszym i głównym przypadkiem użycia pozostaje dom.

***

# 7. Filozofia rozwoju

Projekt powinien być rozwijany według zasady:

> Najpierw rozwiązujemy konkretny problem domowy. Dopiero później dodajemy kolejne warstwy.

Kolejność:

1. Obiekty.
2. Pliki.
3. Własne pola.
4. Relacje.
5. Wyszukiwanie.
6. Archiwum i historia.
7. Terminy oraz przypomnienia.
8. Backup i bezpieczeństwo.
9. Integracje kalendarzowe.
10. Home Assistant.
11. Kamery.
12. OCR i AI.
13. Zaawansowane automatyzacje.

System powinien być rozszerzalny, ale nie może być nadmiernie skomplikowany „na przyszłość”.

***

# 8. Zasada prostego interfejsu

Użytkownik nie powinien projektować bazy danych.

Typowy przepływ:

1. Kliknij „Dodaj domownika” albo „Dodaj obiekt”.
2. Wpisz nazwę.
3. Opcjonalnie wybierz gotowy szablon.
4. Dodaj własne pola.
5. Załącz pliki.
6. Dodaj relacje.
7. Dodaj termin lub przypomnienie.
8. Zapisz.

System może oferować szablony, ale użytkownik zawsze może:

* usunąć sugerowane pole,
* zmienić jego nazwę,
* dodać nowe pole,
* pominąć pole,
* utworzyć obiekt bez szablonu,
* zapisać własny układ jako szablon.

Elastyczność nie może wymagać znajomości pojęć technicznych.

***

# 9. Workspace

## 9.1. Definicja

Workspace jest logiczną przestrzenią danych jednego gospodarstwa domowego.

Zawiera:

* konta i członkostwa,
* obiekty osób,
* pozostałe obiekty,
* pliki,
* pola,
* szablony,
* relacje,
* tagi,
* przypomnienia,
* historię,
* ustawienia,
* integracje.

## 9.2. Zakres MVP

Jedna instalacja i jej baza mają dokładnie jeden Workspace — dom. Nie istnieje
„aktywny Workspace”, wybór Workspace ani przełączanie go w ramach serwera.

Model techniczny posiada `workspace_id` jako relację strukturalną, aby:

* wskazać technicznego właściciela rekordu,
* wymuszać spójność kluczami obcymi,
* zachować jednoznaczny eksport i restore.

Identyfikator jedynego Workspace nadaje serwer. Klient nie wybiera go ani nie
przesyła w zwykłych komendach.

## 9.3. Granica bezpieczeństwa instalacji

Każdy rekord domenowy należy do singletonu Workspace bezpośrednio albo przez
jednoznaczną relację. Nie jest to mechanizm izolacji tenantów: drugi Workspace
nie może istnieć w tej bazie, więc autoryzacja nie sprawdza przynależności
zasobu do „bieżącego Workspace”.

Granicą bezpieczeństwa jest instalacja wraz z bazą, dokumentami, sekretami i
backupem. Kolejne profile aplikacji łączą się z niezależnymi serwerami.

***

# 10. Konto, osoba i członkostwo

Te trzy pojęcia muszą być oddzielone.

## 10.1. Konto

Konto jest techniczną tożsamością służącą do:

* logowania,
* uwierzytelniania,
* zarządzania sesją,
* odbierania zaproszeń,
* wykonywania działań,
* otrzymywania powiadomień.

Konto posiada między innymi:

* identyfikator,
* e-mail,
* dane uwierzytelniania,
* status,
* preferencje,
* sesje,
* ustawienia bezpieczeństwa.

## 10.2. Obiekt osoby

Obiekt osoby opisuje człowieka.

Może reprezentować:

* domownika,
* dziecko bez konta,
* członka dalszej rodziny,
* lekarza,
* weterynarza,
* opiekuna,
* kontakt serwisowy.

Może mieć:

* dane kontaktowe,
* dokumenty,
* notatki,
* dokumentację medyczną,
* relacje rodzinne,
* terminy,
* przypomnienia.

## 10.3. Członkostwo

Członkostwo łączy konto z Workspace.

Określa:

* status członka,
* rolę,
* uprawnienia,
* datę dołączenia,
* osobę zapraszającą,
* powiązany obiekt osoby.

## 10.4. Dlaczego rozdzielenie jest konieczne

* Noworodek może być obiektem osoby bez konta.
* Lekarz jest osobą, ale nie jest użytkownikiem aplikacji.
* Dziecko może później otrzymać konto powiązane z istniejącym obiektem.
* Domownik może stracić dostęp po wyprowadzce, ale jego historyczny obiekt pozostaje.
* Konto może zostać zablokowane bez usuwania dokumentów człowieka.

***

# 11. Pierwszy użytkownik i zapraszanie

## 11.1. Pierwsza konfiguracja

Pierwsza osoba kończąca onboarding:

* tworzy Workspace,
* tworzy pierwszy obiekt osoby,
* zostaje administratorem gospodarstwa,
* może zapraszać kolejnych członków,
* może konfigurować instalację.

Nie należy traktować jej jako nieusuwalnego obiektu „root” w domenie rodzinnej.

## 11.2. Administrator instalacji a administrator domu

Warto rozróżnić:

* **administrator instalacji** — aktualizacje, backup, integracje, serwer,
* **administrator Workspace** — członkowie, ustawienia, dane,
* **domownik** — codzienna praca.

Jedna osoba może pełnić wszystkie role.

## 11.3. Zaproszenia

Przepływ:

1. Domownik podaje e-mail.
2. Wybiera lub tworzy obiekt osoby.
3. Określa rolę.
4. System tworzy jednorazowe zaproszenie.
5. Zaproszona osoba ustawia logowanie.
6. Konto zostaje połączone z członkostwem i obiektem osoby.

## 11.4. Czy każdy może zapraszać?

W zaufanej rodzinie domyślnie dorośli domownicy mogą mieć takie prawo.

Nie powinno ono być jednak bezwarunkowe. Administrator musi móc je odebrać, na przykład dziecku, gościowi albo kontu tymczasowemu.

***

# 12. Role i uprawnienia

System ma być prosty, ale nie może ignorować prywatności.

## 12.1. Administrator gospodarstwa

Może:

* zarządzać członkami,
* zmieniać ustawienia,
* tworzyć i edytować obiekty,
* archiwizować i usuwać,
* zarządzać integracjami,
* wykonywać eksport,
* konfigurować backup,
* przeglądać audit techniczny.

## 12.2. Domownik

Może domyślnie:

* tworzyć obiekty,
* edytować dostępne obiekty,
* dodawać pliki,
* tworzyć przypomnienia,
* archiwizować,
* korzystać z wyszukiwarki,
* zapraszać, jeśli ma odpowiednie uprawnienie.

## 12.3. Ograniczony domownik

Przeznaczony na przykład dla dziecka.

Może:

* widzieć wybrane dane,
* zarządzać własnymi rzeczami,
* dodawać własne pliki,
* nie ma dostępu do dokumentów wrażliwych,
* nie usuwa trwale,
* nie zarządza integracjami.

## 12.4. Gość

Dostęp ograniczony i opcjonalnie czasowy.

## 12.5. Widoczność danych

Minimalne poziomy:

* wszyscy w Workspace,
* wybrani członkowie,
* tylko właściciel,
* administratorzy.

Prywatność powinna działać co najmniej na poziomie obiektu i pliku.

> **Doprecyzowanie M4:** powyższa lista opisuje możliwe zakresy widoczności,
> a nie automatyczne prawo administratora do każdej treści. Ochrona danych
> wrażliwych działa na poziomie konkretnego `FieldValue`; rola administratora
> ani relacja rodzinna sama nie nadaje odczytu. Obowiązuje 10 §M4-D12.

***

# 13. Obiekt

## 13.1. Minimalny obiekt

Każdy obiekt ma:

* ID,
* Workspace,
* nazwę,
* status,
* autora,
* datę utworzenia,
* datę modyfikacji.

## 13.2. Elementy opcjonalne

* opis,
* kategoria,
* typ,
* zdjęcie,
* właściciel,
* własne pola,
* pliki,
* tagi,
* relacje,
* daty,
* przypomnienia,
* widoczność,
* notatki,
* integracje.

## 13.3. Typy i kategorie

Kategoria pomaga organizować system, ale nie ogranicza danych.

Przykładowe kategorie:

* osoba,
* zwierzę,
* miejsce,
* pojazd,
* urządzenie,
* usługa,
* organizacja,
* dokument logiczny,
* projekt,
* obiekt ogólny.

Typ jest nazwą użytkową, na przykład:

* samochód,
* laptop,
* lekarz,
* polisa,
* lodówka,
* łóżeczko,
* roleta.

***

# 14. Dynamiczne pola

Dynamiczne pola pozwalają opisywać dowolne obiekty bez zmiany kodu.

Przykłady:

**Samochód**

* VIN,
* numer rejestracyjny,
* przebieg,
* rozmiar opon.

**Komputer**

* procesor,
* RAM,
* numer seryjny,
* system operacyjny.

**Zwierzę**

* numer chipa,
* rasa,
* data szczepienia.

**Lekarz**

* specjalizacja,
* telefon,
* adres,
* godziny przyjęć.

Obsługiwane typy pól w MVP:

* tekst krótki,
* tekst długi,
* liczba,
* liczba z jednostką,
* data,
* data i czas,
* tak/nie,
* lista,
* wielokrotny wybór,
* e-mail,
* telefon,
* URL,
* adres,
* relacja,
* plik,
* wartość wrażliwa.

***

# 15. Szablony

Szablon to zestaw podpowiedzi dla nowego obiektu.

Może zawierać:

* kategorię,
* nazwę typu,
* ikonę,
* sugerowane pola,
* sekcje,
* sugerowane relacje,
* sugerowane terminy.

Szablon nie jest sztywnym schematem.

Użytkownik może:

* zmienić każde pole,
* usunąć je,
* dodać własne,
* zapisać zmodyfikowany układ jako nowy szablon,
* utworzyć obiekt bez szablonu.

***

# 16. Pliki i zasoby

Plik jest zasobem cyfrowym, który może być przypięty do obiektu.

Typy zasobów:

* PDF,
* zdjęcie,
* wideo,
* audio,
* dokument biurowy,
* archiwum,
* link,
* skan,
* raport.

Jeden plik może być przypięty do kilku obiektów.

Przykład: faktura za urządzenie może być powiązana z:

* urządzeniem,
* projektem remontowym,
* sklepem,
* gwarancją.

Usunięcie jednego powiązania nie może usuwać pliku używanego gdzie indziej.

***

# 17. Relacje

Relacja łączy dwa obiekty.

Przykłady:

* Anna posiada Toyotę.
* Toyota należy do Anny.
* Figa jest pod opieką Anny.
* Dr Kowalski jest lekarzem Anny.
* Router znajduje się w gabinecie.
* Polisa dotyczy samochodu.
* Czujnik jest zamontowany w sypialni.

Relacja zawiera:

* obiekt źródłowy,
* typ relacji,
* obiekt docelowy,
* opcjonalny okres obowiązywania,
* notatkę,
* status.

Relacja powinna być zapisywana raz i prezentowana z obu stron.

***

# 18. Tagi i klasyfikacja

Tagi są lekkim mechanizmem organizacji.

Przykłady:

* zdrowie,
* samochód,
* pilne,
* gwarancja,
* podatki,
* dziecko,
* remont.

Tagi nie zastępują typów ani relacji.

System powinien:

* sugerować istniejące tagi,
* unikać duplikatów różniących się wielkością liter,
* pozwalać łączyć tagi,
* umożliwiać filtrowanie.

***

# 19. Terminy i przypomnienia

Pole daty nie musi automatycznie tworzyć przypomnienia.

Użytkownik może wybrać:

* brak przypomnienia,
* przypomnij raz,
* przypomnij wielokrotnie,
* przypomnij wybranym osobom,
* przypomnienie cykliczne.

Przykłady:

* koniec ubezpieczenia,
* termin szczepienia,
* przegląd samochodu,
* koniec gwarancji,
* wizyta lekarska,
* wymiana filtra,
* odnowienie usługi.

W przyszłości terminy mogą synchronizować się z kalendarzem Google, Apple lub CalDAV.

Źródłem prawdy dla terminu domenowego powinien pozostać system.

***

# 20. Cykl życia obiektu

Stany:

* aktywny,
* zarchiwizowany,
* w koszu,
* trwale usunięty.

## 20.1. Archiwizacja

Archiwizacja jest domyślną operacją dla rzeczy, które przestały być aktualne.

Przykłady:

* sprzedany komputer,
* stare łóżeczko,
* samochód po sprzedaży,
* były lekarz,
* członek rodziny po wyprowadzce.

Archiwizacja:

* zachowuje historię,
* zachowuje pliki,
* zachowuje relacje,
* ukrywa obiekt z głównych list,
* pozwala go przywrócić.

## 20.2. Kosz

Kosz jest etapem przed trwałym usunięciem.

Powinien mieć:

* retencję,
* przywracanie,
* podgląd zależności,
* informację o liczbie plików i relacji.

## 20.3. Trwałe usunięcie

Wymaga jawnego potwierdzenia.

System pokazuje:

* pliki,
* relacje,
* przypomnienia,
* historię,
* zasoby współdzielone.

***

# 21. Historia i audit

Każda istotna zmiana zostawia ślad:

* kto,
* kiedy,
* co zmienił,
* jaka była poprzednia wartość,
* jaka jest nowa wartość,
* skąd pochodzi zmiana.

Przykładowe zdarzenia:

* utworzono obiekt,
* dodano pole,
* zmieniono wartość,
* dołączono plik,
* usunięto relację,
* zarchiwizowano,
* przywrócono,
* zaproszono użytkownika,
* zmieniono uprawnienia.

***

# 22. Wyszukiwanie

MVP wyszukuje po:

* nazwie,
* typie,
* kategorii,
* tagach,
* wartościach tekstowych,
* notatkach,
* nazwach plików.

Filtry:

* status,
* właściciel,
* typ,
* tag,
* data,
* obiekty z plikami,
* obiekty z terminami,
* archiwalne.

Przyszłość:

* OCR,
* pełny tekst dokumentów,
* wyszukiwanie semantyczne,
* pytania naturalne.

***

# 23. Dashboard

Dashboard powinien być prosty.

Elementy MVP:

* szybkie dodawanie,
* ostatnie obiekty,
* ostatnie pliki,
* najbliższe terminy,
* skróty do domowników,
* ważne ostrzeżenia,
* ostatnia aktywność.

Przyszłość:

* status domu,
* kontrolki Smart Home,
* kamery,
* sugestie AI,
* automatyzacje.

***

# 24. Home Assistant

Home Assistant pozostaje silnikiem Smart Home.

Odpowiada za:

* integracje urządzeń,
* stany encji,
* komunikację,
* sceny,
* automatyzacje.

Projekt odpowiada za:

* reprezentację urządzenia jako obiektu,
* dokumentację,
* faktury,
* gwarancję,
* lokalizację,
* relacje,
* wspólny panel,
* uproszczone sterowanie.

Mapowanie:

```
Obiekt w systemie ↕ Rekord integracji ↕ Device w Home Assistant ↕ Encje Home Assistant
```

Nie każda encja musi być osobnym obiektem.

***

# 25. Kamery

Moduł kamer powinien integrować istniejący system, na przykład NVR lub Frigate.

Potencjalne funkcje:

* lista kamer,
* podgląd,
* zdarzenia,
* detekcja,
* lokalizacja,
* retencja,
* dostęp per użytkownik.

Wideo i lokalizacja wymagają szczególnej ochrony.

***

# 26. AI

AI jest dodatkiem, nie fundamentem.

Może:

* wykonywać OCR,
* sugerować typ dokumentu,
* wyciągać daty,
* sugerować obiekt docelowy,
* streszczać,
* wyszukiwać semantycznie,
* proponować przypomnienia,
* odpowiadać na pytania.

Zasady:

* użytkownik zatwierdza krytyczne dane,
* AI nie jest źródłem prawdy,
* odpowiedzi wskazują źródła,
* dane wrażliwe nie są domyślnie wysyłane do chmury,
* AI nie usuwa trwale,
* AI nie wykonuje ryzykownych automatyzacji fizycznych bez zabezpieczeń.

***

# 27. Bezpieczeństwo

System może zawierać dane medyczne, dokumenty tożsamości, finanse i monitoring.

Minimum:

* TLS,
* bezpieczne hasła,
* MFA w późniejszej fazie,
* kontrola sesji,
* izolacja Workspace,
* kontrola dostępu,
* audit,
* szyfrowane backupy,
* bezpieczne sekrety,
* limity uploadu,
* skanowanie typów plików,
* ochrona przed path traversal,
* walidacja danych,
* ochrona CSRF i XSS,
* ograniczenie prób logowania.

***

# 28. Backup i odzyskiwanie

Backup jest funkcją podstawową, nie dodatkiem.

Musi obejmować:

* bazę danych,
* pliki,
* ustawienia,
* konfigurację integracji,
* niezbędne klucze.

System powinien:

* pokazywać stan ostatniego backupu,
* ostrzegać o błędach,
* wspierać backup lokalny i zewnętrzny,
* umożliwiać test odtworzenia,
* dokumentować procedurę disaster recovery.

***

# 29. Wymagania niefunkcjonalne

## 29.1. Wydajność

Docelowo płynna praca przy:

* tysiącach obiektów,
* dziesiątkach tysięcy plików,
* kilku lub kilkunastu użytkownikach,
* setkach urządzeń Smart Home.

## 29.2. Niezawodność

* transakcyjne zapisy,
* integralność plików,
* odporność na restart,
* retry dla zadań w tle,
* brak utraty danych przy błędzie integracji.

## 29.3. Dostępność

* responsywność,
* obsługa klawiatury,
* kontrast,
* etykiety,
* czytelne błędy,
* brak krytycznych informacji przekazywanych wyłącznie kolorem.

## 29.4. Przenośność

Eksport powinien zawierać:

* obiekty,
* pola,
* relacje,
* tagi,
* notatki,
* pliki,
* terminy.

Format powinien być otwarty.

***

# 30. Architektura logiczna

> **SUPERSEDED BY 03 / 05** - diagram ponizej jest zapisem historycznym.
> Nieaktualne: `FS[(Magazyn plikow)]` jako komponent Core (-> Paperless jest wlascicielem binariow, R-02),
> `S[Wyszukiwarka]` jako osobny silnik (-> PostgreSQL FTS + Paperless search, R-08),
> `OCR[OCR / AI]` w workerze (-> OCR nalezy do Paperless i wchodzi do MVP, R-03).
> Obowiazujacy obraz: `architecture/05-Open-Source-Architecture.md` §30 oraz `00-Analiza-i-Mapa-Realizacji.md` §5.

```
flowchart LR 
  UI[Web / PWA / Mobile] --> API[Core API] 
  API --> DB[(Relacyjna baza danych)] 
  API --> FS[(Magazyn plików)] 
  API --> Q[Kolejka zadań] 
  Q --> W[Worker] 
  API --> S[Wyszukiwarka] 
  API --> I[Adaptery integracji] 
  I --> HA[Home Assistant] 
  I --> C[Kalendarze] 
  W --> OCR[OCR / AI]
```

Pierwsza wersja może być monolitem modułowym. Nie ma potrzeby budowania mikroserwisów.

***

# 31. Przykładowe scenariusze

## 31.1. Samochód

* tworzenie z szablonu,
* własne pola,
* polisa,
* faktury,
* przypomnienie,
* relacja z właścicielem,
* archiwizacja po sprzedaży.

## 31.2. Dokumentacja medyczna

* obiekt osoby,
* obiekt lekarza,
* relacja lekarz–pacjent,
* prywatne pliki,
* terminy wizyt,
* wyszukiwanie,
* przyszły OCR.

## 31.3. Zwierzę

* dane chipa,
* weterynarz,
* szczepienia,
* dokumenty,
* przypomnienia.

## 31.4. Komputer

* własne pola,
* faktura,
* gwarancja,
* przypisanie do dziecka,
* edycja przez właściciela,
* archiwizacja po sprzedaży.

***

# 32. Roadmap

> **SUPERSEDED BY 07** - obowiazuje roadmapa M0-M22 z `07-Product-and-Delivery-Roadmap.md` (R-13).
> Roznice: OCR wchodzi do MVP (nie do fazy 5); backup jest brama MVP (nie faza jakosci);
> synchronizacja kalendarzy wychodzi z MVP do wydania 1.2.

## Faza 0 — dokumentacja

* Core Domain,
* Object Model,
* File Model,
* Workspace,
* uprawnienia,
* backup,
* UX.

## Faza 1 — cyfrowy segregator

* instalacja,
* logowanie,
* Workspace,
* domownicy,
* obiekty,
* pola,
* pliki,
* tagi,
* relacje,
* wyszukiwanie,
* archiwum,
* kosz,
* terminy.

## Faza 2 — jakość

* wersjonowanie,
* prywatność,
* backup i restore,
* PWA,
* powiadomienia,
* synchronizacja kalendarzy.

## Faza 3 — Home Assistant

* połączenie,
* import,
* mapowanie,
* statusy,
* sterowanie,
* sceny.

## Faza 4 — monitoring

* kamery,
* zdarzenia,
* detekcja,
* retencja.

## Faza 5 — AI

* OCR,
* ekstrakcja,
* semantyczne wyszukiwanie,
* asystent.

***

# 33. Decyzje architektoniczne

1. Obiekt jest główną jednostką domeny.
2. Konto i osoba są oddzielne.
3. Workspace jest granicą danych.
4. Szablony są miękkie.
5. Własne pola są dynamiczne.
6. Archiwizacja jest ważniejsza niż usunięcie.
7. Plik może należeć do kilku obiektów.
8. Historia jest domyślna.
9. Home Assistant nie jest przepisywany.
10. AI jest opcjonalne.
11. MVP jest zoptymalizowane pod jeden dom.
12. Technicznie dopuszczamy wiele Workspace’ów.
13. Uprawnienia są rodzinne, ale realne.
14. Backup jest częścią produktu.
15. Monolit modułowy jest preferowany na start.

***

# 34. Ryzyka

* rozrost zakresu,
* chaos własnych pól,
* zbyt puste formularze,
* zbyt sztywne szablony,
* niejasne uprawnienia,
* brak backupu,
* zbyt duża zależność od AI,
* próba zastąpienia Home Assistant,
* zbyt wczesne mikroserwisy,
* brak czytelnej historii usuwania.

Każde ryzyko powinno mieć test, ograniczenie albo decyzję projektową.

***

# 35. Kryteria sukcesu MVP

MVP jest użyteczne, gdy rodzina może:

* utworzyć konta,
* dodać osoby,
* utworzyć dowolny obiekt,
* dodać własne pole,
* przypiąć dokument,
* znaleźć dokument,
* połączyć obiekty,
* ustawić termin,
* zarchiwizować rzecz,
* odzyskać ją z kosza,
* kontrolować prywatność,
* wykonać backup.

***

# 36. Dokumenty następne

> **SUPERSEDED BY 07 §29** - obowiazuje lista 13 dokumentow z roadmapy, z zasada just-in-time (R-14).

1. `02-Object-Model.md`
2. `03-Workspace-and-Membership.md`
3. `04-Asset-and-File-Management.md`
4. `05-Relations-and-Tags.md`
5. `06-Reminders-and-Calendar.md`
6. `07-Permissions-and-Privacy.md`
7. `08-Search.md`
8. `09-Backup-and-Restore.md`
9. `10-Home-Assistant-Integration.md`
10. `11-Cameras-and-Monitoring.md`
11. `12-AI-and-OCR.md`
12. `13-API.md`
13. `14-Database.md`
14. `15-UX-Flows.md`
15. `16-Security-Threat-Model.md`

***

# 37. Podsumowanie

Projekt ma zacząć jako użyteczny cyfrowy segregator domu, a nie jako nieskończona platforma.

Fundament:

```
Workspace 
├── Konta 
├── Członkostwa 
├── Obiekty osób 
├── Pozostałe obiekty 
├── Własne pola 
├── Pliki 
├── Relacje 
├── Tagi 
├── Terminy 
├── Historia 
└── Integracje
```

Najważniejsza zasada:

> Budujemy rozwiązanie dla realnych problemów jednej rodziny, zachowując rozszerzalność modelu, ale odkładając złożoność do momentu, gdy jest naprawdę potrzebna.
