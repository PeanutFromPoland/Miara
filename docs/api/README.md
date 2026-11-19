# Kontrakt OpenAPI Miary

Wersja dokumentu: **0.1.0**, 16 listopada 2026. Podstawa: [model v0.1](../model-danych.md). Opis zachowania i indeks operacji: [kontrakt API](../kontrakt-api.md).

| Plik | Rola |
| --- | --- |
| [openapi.json](openapi.json) | Specyfikacja OpenAPI 3.1.0: 34 operacje, 75 schematów i 79 przykładów. |
| [contract-cases.json](contract-cases.json) | 50 pozytywnych i negatywnych przypadków formatów danych. |
| [test_openapi.py](../../tests/contracts/test_openapi.py) | Walidacja standardu, odwołań, przykładów i przypadków. |
| [requirements.txt](../../tests/contracts/requirements.txt) | Przypięte zależności walidatora, osobne od zależności aplikacji. |

Przykłady są demonstracyjne. Nie są przepisami pozyskanymi ze źródła ani rzeczywistymi danymi żywieniowymi. Tokeny w przykładach są fikcyjne.

## Uruchomienie z katalogu projektu

```powershell
python -m pip install --target .tools/openapi-validation -r tests/contracts/requirements.txt
python -m unittest discover -s tests/contracts -v
```

Pakiety trafiają do ignorowanego katalogu `.tools/`; nie zmieniają zależności Fluttera ani przyszłego serwera. Po instalacji walidacja działa lokalnie, bez wywoływania LLM, źródeł przepisów lub API żywieniowego. Skrypt walidacji korzysta z lokalnego katalogu pakietów, jeżeli istnieje.

## Wynik i granice

16 listopada 2026: **10 testów walidacji zakończonych powodzeniem**. Sprawdzono 75 definicji, 79 przykładów, przykłady przypisane do operacji i 50 przypadków regresyjnych. Przypadki dotyczą m.in. null/zero, pól klienta, UUID, wersji, różnych źródeł dziennika, statusów wyszukiwania, kompletności i stron synchronizacji. Indeks operacji w opisie jest sprawdzany względem specyfikacji.

Nie uruchomiono backendu ani testów jego zachowania. Walidacja nie dowodzi izolacji kont w implementacji, poprawnego rachunku, transakcji, kolejki po restarcie lub dokładnie jednego skutku ponowionego zapisu. Te dowody należą do planu testów integracyjnych i implementacji T-05/T-08/T-17/T-23.

## Utrzymanie

| Model logiczny | Widok lub operacja publiczna |
| --- | --- |
| `Account`, `Session` | `Account`, `SessionTokens`; hashe pozostają na serwerze. |
| `NutritionProfile` | Osobne `ProfileCreate`, `ProfilePatch`, `Profile`. |
| `RecipeVersion` ze składnikami/krokami | `RecipeSummary` do karty i `RecipeDetail` do szczegółów. |
| `RecipeEstimate`, `EstimateContribution` | Szacunek po ID, ze źródłami i wkładami; prywatność jest sprawdzana oddzielnie. |
| `MealNutritionSnapshot` | Wynik serwera w planie/dzienniku; klient przesyła ilość i podstawę, a nie gotowe wyliczone sumy. |
| `LocalOperation` | Mutacje z `Idempotency-Key` i wersją; pełna kolejka pozostaje na urządzeniu. |
| `OperationReceipt` | Minimalne potwierdzenie przez `/v1/operations/{operation_id}`. |
| `AccountChange`, `ResourceDeletion` | `SyncChange` i `SyncPage`, bez ujawniania surowej sekwencji konta. |

Edytuj specyfikację, przykłady/przypadki i opis zachowania w jednym zadaniu. Po zmianie uruchom powyższe testy. Zmiana znaczenia istniejących pól wymaga wersjonowania kontraktu; klient powinien tolerować nowe opcjonalne pola odpowiedzi.

Nie dodawaj do publicznych DTO hashy poświadczeń, surowej odpowiedzi modelu ani technicznych danych cudzych kont. Opcjonalny endpoint OCR nie oznacza wyboru miejsca OCR — jego dostępność ogłasza capabilities.
