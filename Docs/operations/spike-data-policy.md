# Polityka danych i sekretów Fazy 1

**Status:** `accepted` · **Milestone:** M3 · **Data:** 2026-07-28

**Podstawa:** `../08-MVP-Scope.md` §5 · `spike-plan.md` · ADR-019

---

## 1. Cel

Eksperymenty używają dokumentów o jakości zbliżonej do rzeczywistych, surowych odpowiedzi API, eksportów i zaszyfrowanych repozytoriów backupu. Ten materiał może zawierać dane osobowe lub sekrety. Niniejsza polityka określa, co wolno utrwalać i commitować.

## 2. Klasy danych

| Klasa | Przykłady | Git | Miejsce |
|---|---|---|---|
| Publiczna | plan, zanonimizowany raport, macierz bez danych osób | Dozwolony | `Docs/operations/spike-results/` |
| Wrażliwa | rzeczywiste próbki, pełne odpowiedzi API, eksport Paperless | Zabroniony | katalog `lab-data/` poza Git |
| Sekretna | token API, hasła DB, pliki `.env`, klucz Restic/Borg | Zabroniony | menedżer haseł lub szyfrowany nośnik poza repozytorium |
| Pochodna zanonimizowana | metryki, zredagowane JSON, checksumy bez nazw osób | Dozwolony po przeglądzie | `Docs/operations/spike-results/` |

## 3. Dokumenty testowe

1. Używaj dokumentów własnych albo materiału, na którego użycie właściciel wyraził zgodę.
2. Usuń lub zamaskuj numery PESEL, rachunków, polis, adresy, podpisy, kody QR i identyfikatory klientów, jeżeli nie są cechą testowaną.
3. Zachowaj jakość skanu, układ, język i typowe artefakty OCR.
4. Manifest używa identyfikatorów `DOC-01`…`DOC-10`; nie zawiera nazw osób ani nazw plików źródłowych.
5. Pliki znajdują się w `lab-data/documents/`, które jest ignorowane przez Git.

## 4. Odpowiedzi API i logi

- Tokeny, ciasteczka, nagłówki `Authorization`, adresy e-mail i treść OCR są redagowane przed zapisem w repozytorium.
- Surowe, niezredagowane odpowiedzi trafiają do `Docs/operations/spike-results/raw/`, ignorowanego przez Git.
- Do trwałego artefaktu trafia zredagowany przykład z zachowaną strukturą pól.
- Logi nie mogą zawierać zawartości dokumentu ani sekretów.

## 5. Konfiguracja i klucze

- Commitujemy wyłącznie pliki `*.example` i manifest digestów.
- Rzeczywiste `.env`, hasła DB i token API pozostają poza Git.
- Klucz repozytorium backupu ma dwie kopie poza samym repozytorium backupu.
- Materiały odzyskiwania są wymagane dopiero przed pierwszym backupem E3A/E3B, nie przed E1 ani E2.
- Druga kopia materiałów odzyskiwania musi zostać faktycznie użyta w E3B-10; samo jej istnienie nie wystarcza.
- Raport zapisuje identyfikator kopii klucza i wynik testu, nigdy wartość klucza.

## 6. Retencja

- Niezanonimizowane dane laboratoryjne są usuwane po zaakceptowaniu raportu Fazy 1, chyba że właściciel świadomie zatwierdzi ich dalsze przechowywanie.
- Zanonimizowany zestaw regresyjny może pozostać poza Git do ponawiania testów.
- Eksporty i repozytoria testowe są usuwane po potwierdzonym restore i zapisaniu metryk.

## 7. Kontrola przed commitem

- [ ] Brak dokumentów binarnych i eksportów
- [ ] Brak `.env`, tokenów, kluczy i haseł
- [ ] Odpowiedzi API zredagowane
- [ ] Nazwy plików nie identyfikują osób
- [ ] Manifest zawiera wyłącznie pseudonimy i cechy testowe
- [ ] `git status` nie pokazuje katalogów prywatnych
