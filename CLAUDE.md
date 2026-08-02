# Instrukcje dla agenta

1. Przed rozpoczęciem pracy przeczytaj dokumentację w folderze `Docs`.

2. Zawsze bazuj na najnowszej dokumentacji projektu.

3. W przypadku rozbieżności stosuj źródło właściwe dla danego obszaru:

```text
07 — kolejność realizacji, milestone'y i bramy
08 — zakres MVP
accepted ADR — konkretna decyzja architektoniczna
06 — zachowanie i workflow
05 — komponenty OSS i granice integracji
04 → 03 → 02 → 01 — szczegóły historyczne i domenowe
```

4. Pliki 05–08 i zaakceptowane ADR-y są nadrzędne w swoim zakresie:
   - technologii,
   - architektury,
   - workflow,
   - integracji,
   - zakresu MVP,
   - kolejności realizacji.

5. Nie zmieniaj stosu technologicznego bez wyraźnego polecenia i nowego ADR.

6. Nie dodawaj nowych bibliotek, usług ani narzędzi, jeżeli obecne rozwiązania wystarczają.

7. Nie twórz funkcji spoza aktualnej fazy projektu.

8. Nie projektuj na zapas. Implementuj wyłącznie bieżące wymagania.

9. Zachowuj istniejące granice modułów oraz odpowiedzialności systemów.

10. Zewnętrzne systemy integruj przez porty i adaptery. Nie używaj bezpośrednio ich baz danych ani szczegółów implementacyjnych poza adapterem.

11. Dbaj przede wszystkim o:
    - brak utraty danych,
    - bezpieczeństwo,
    - poprawność uprawnień,
    - idempotencję,
    - obsługę błędów,
    - backup i restore.

12. Kod pisz prosto, czytelnie i bez zbędnych abstrakcji.

13. Używaj jednoznacznych nazw zgodnych ze słownikiem projektu.

14. Nie używaj `any`, magicznych wartości ani pustych bloków `catch`, jeżeli można tego uniknąć.

15. Komentarze w kodzie mają być krótkie i naturalne.

16. Komentuj głównie powód nietypowej decyzji, a nie oczywiste działanie kodu.

17. Nie pisz rozwlekłych komentarzy ani esejów w kodzie.

18. Nie komentuj każdej funkcji i każdej linii.

19. Odpowiadaj krótko, konkretnie i po ludzku.

20. Nie powtarzaj treści zadania i nie dodawaj długich wstępów.

21. Po wykonaniu zadania podaj jedynie:
    - co zostało zmienione,
    - jakie testy wykonano,
    - jakie problemy pozostały.

22. Nie deklaruj, że coś działa, jeżeli nie zostało uruchomione lub przetestowane.

23. Jeżeli dokumentacja jest niejednoznaczna:
    - najpierw sprawdź 07, 08, zaakceptowane ADR-y oraz pliki 05–06,
    - wybierz najmniejsze bezpieczne rozwiązanie, jeśli decyzja jest łatwo odwracalna,
    - przygotuj ADR, jeśli decyzja wpływa na architekturę lub jest trudna do cofnięcia.

24. Nie zmieniaj istniejącego kodu poza zakresem zadania bez wyraźnej potrzeby.

25. Każda zmiana musi być zgodna z aktualną fazą, dokumentacją i przyjętą architekturą.

26. Nie zapisuj w repozytorium:
    - rzeczywistych dokumentów testowych,
    - tokenów API,
    - haseł i plików `.env`,
    - kluczy szyfrujących backup,
    - surowych odpowiedzi zawierających dane osobowe.

27. Artefakty eksperymentów muszą być zanonimizowane zgodnie z `Docs/operations/spike-data-policy.md`.
