# `api/` — kontrakt API

**Stan:** katalog utworzony w M0; dokumenty powstają just-in-time.

| Dokument | Powstaje przed bramą | Faza | Zawartość |
|---|---|---|---|
| `12-Document-Integration-Contract.md` | **M6** | Faza 2 | Port `DocumentProvider` z 10 operacjami REST, timeout, retry classification, idempotency, error mapping, correlation, contract tests, mock provider, compatibility matrix wersji, fallbacki thumbnail/metadata update/health i mechanizm odczytu statusu. Eksport/import pozostaje interfejsem utrzymaniowym z ADR-019. Rozstrzyga **G4-04** |
| `13-Search-Specification.md` | **M7** | Faza 2 | PostgreSQL FTS, `pg_trgm`, `unaccent`, Paperless search, agregacja, ranking, permissions, partial results, filtry, paginacja, highlighting, polskie znaki, 7 scenariuszy. Rozstrzyga **G5-02, G5-05, G5-06, G5-07** |
| `14-API-Specification.md` | **M8** | Faza 2 | REST `/api/v1`, OpenAPI, paginacja, katalog 13 błędów domenowych, idempotency, ETag/version, async operation resource, streaming, correlation ID, limity uploadu. Rozstrzyga **G4-02, G4-03, G4-05** |

## Kolejność bram

```
M4 → M5 → M6 → M7 → M8 → M9
```

Milestone'y mogą nakładać się czasowo w fazie szkicowania, ale **bramy zamykane są w tej kolejności**. Zamknięcie M6 przed M5 albo M8 przed M4–M7 jest błędem (ryzyko RY-29).

**Brama M6:** pozostałe moduły nie znają endpointów ani typów Paperless.
**Brama M8:** frontend można zaprojektować bez wiedzy o bazie danych i o Paperless.
