# `ux/` — architektura informacji i interfejs

**Stan:** katalog utworzony w M0; dokumenty powstają just-in-time.

| Dokument | Powstaje przed bramą | Faza | Zawartość |
|---|---|---|---|
| `17-UX-Information-Architecture.md` | **M15** | Faza 6 (szkic sitemap od Fazy 3) | Sitemap 12 widoków, wireframes, formularze, error states, responsive rules, accessibility checklist |

## Dlaczego dopiero w Fazie 6

UX Information Architecture opisuje **wszystkie stany, które interfejs musi pokazać**: 14 stanów dokumentu, partial results, `missing_external`, dokumenty nieprzypisane, kosz z zależnościami, tryb zdegradowany przy awarii Paperless. Te stany istnieją dopiero po zamknięciu Fazy 5. Projektowanie IA wcześniej oznaczałoby projektowanie ekranów dla stanów, które jeszcze nie istnieją.

## Dwanaście widoków MVP (07 §20)

Home · Search · Objects · Object Detail · Documents · Upload · Processing · Unassigned · Trash · Members · Settings · System Health

## Zasady UX obowiązujące od początku

- Proste słownictwo; widoczne statusy.
- **Brak nazw `Paperless` i `Gotenberg` w interfejsie użytkownika.**
- Mobile-first upload.
- Dostępność: obsługa klawiatury, kontrast, etykiety, brak informacji przekazywanej wyłącznie kolorem.
- Dobre empty states i **recovery actions** przy błędach.
- Brak ślepych toastów jako jedynej informacji o wyniku operacji.

**Poza zakresem MVP:** pełny design system (07 §36).
