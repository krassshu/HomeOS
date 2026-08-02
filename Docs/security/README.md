# `security/` — bezpieczeństwo

**Stan:** katalog utworzony w M0; dokumenty powstają just-in-time.

| Dokument | Powstaje przed bramą | Faza | Zawartość |
|---|---|---|---|
| `11-Permissions-and-Privacy.md` | **M5** | Faza 2 | Macierz ról, macierz zasób × akcja, reguły dziedziczenia, deny rules, test matrix, rozstrzygnięcie 7 trudnych przypadków, polityka retencji kosza. Rozstrzyga decyzje **G3-02, G3-03, G3-04** i **G5-01, G5-03, G5-04, G5-08** |
| `15-Threat-Model.md` | **M18** | Faza 7 (szkic od Fazy 3) | 8 threat actors, powierzchnia ataku, TLS, WireGuard, firewall, secrets, rate limits, nagłówki, limity uploadu, container hardening, dependency scan, session revocation, owner recovery |

## Siedem trudnych przypadków do rozstrzygnięcia w M5 (07 §10)

1. Dokument powiązany z obiektem publicznym **i** prywatnym.
2. Użytkownik zna identyfikator zasobu, do którego nie ma uprawnień.
3. Wyszukiwanie bez uprawnienia do części wyników.
4. Prywatny duplikat — jak poinformować o duplikacie, **nie ujawniając istnienia** prywatnego dokumentu.
5. Usunięty członek gospodarstwa.
6. Utrata konta właściciela.
7. Dokument medyczny członka rodziny.

**Brama M5:** żaden endpoint dokumentowy nie opiera bezpieczeństwa wyłącznie na frontendzie.
