# Kontrakt API Miary — v0.1

> Status: kontrakt projektowy opracowany na podstawie modelu danych v0.1, 16 listopada 2026 r. Właściciel zezwolił na przejście do kontraktu po opracowaniu modelu (ADR-015). Nie jest to opis uruchomionego serwera ani raport z testów backendu.

Specyfikacja maszynowa: [openapi.json](api/openapi.json), OpenAPI 3.1.0, wersja API `v1`, wersja dokumentu `0.1.0`. Zawiera dokładne schematy żądań i odpowiedzi, parametry, kody HTTP i przykłady. Ten dokument opisuje reguły zachowania, których sam JSON Schema nie wyegzekwuje. Oba dokumenty obowiązują razem.

Podstawa: [model danych](model-danych.md), [ustalenia właściciela](ustalenia-api-i-stany.md) i [rejestr decyzji](decyzje-projektowe.md). Publiczne DTO są widokami modelu; hashe poświadczeń, wewnętrzna kolejka telefonu i pełne rekordy techniczne serwera nie są udostępniane jako encje API.

## Reguły wspólne

- Własny serwer obsługuje `/v1`; bazowy host klient konfiguruje osobno. Docelowy transport to HTTPS, dane strukturalne to JSON UTF-8. `servers: /` w specyfikacji nie wskazuje istniejącego wdrożenia.
- Identyfikatory zasobów są UUID. `id` nowego profilu, planu i dziennika nadaje klient, co pozwala tworzyć powiązania offline. Właściciela ustala serwer z sesji; żądania nie przyjmują `account_id`.
- Daty zdarzeń są UTC w ISO 8601 z końcowym `Z`. `local_date` jest dniem `YYYY-MM-DD` w strefie konta. Historycznych dni nie przesuwamy po zmianie strefy.
- JSON number odpowiada logicznej liczbie dziesiętnej; kod rachunkowy nie powinien kumulować błędów reprezentacji zmiennoprzecinkowej. Precyzja bazy i zaokrąglanie nadal wynikną z projektu fizycznego i ADR-105.
- W odpowiedziach pola nieznane są obecne jako `null`; `0` jest znaną wartością. `[]` oznacza znany brak elementów. Osobny stan kompletności rozróżnia brak ekstrakcji od pustej listy.
- `PATCH`: pole pominięte pozostaje bez zmiany; `null` czyści tylko pole nullable. Żądanie wymaga przynajmniej jednej zmiany. Dodatkowe, niezdefiniowane pola żądań są odrzucane.
- Token dostępu: `Authorization: Bearer <token>`. Cudzy lub niedostępny prywatny zasób daje `404`, także gdy jego przepis źródłowy jest współdzielony.
- Każda odpowiedź ma `X-Request-Id`; bezpieczny komunikat błędu może być pokazany w UI. Klient nie pokazuje użytkownikowi surowych wyjątków, HTML proxy ani odpowiedzi dostawcy LLM.
- Klient powinien tolerować nowe opcjonalne pola odpowiedzi. Testy aktualnej wersji kontraktu sprawdzają zdefiniowane DTO, w tym granicę danych prywatnych.

## Operacje

Każdy typ danych wskazany w opisie operacji ma definicję w `components.schemas` specyfikacji. Poniższy indeks jest zgodny z jej ścieżkami.

| Metoda | Ścieżka | Cel |
| --- | --- | --- |
| `GET` | `/v1/capabilities` | Dostępne funkcje i parametry klienta |
| `POST` | `/v1/auth/register` | Rejestracja konta |
| `POST` | `/v1/auth/login` | Logowanie hasłem |
| `POST` | `/v1/auth/google` | Logowanie zweryfikowanym credential Google |
| `POST` | `/v1/auth/refresh` | Odnowienie dostępu do trwałej sesji |
| `POST` | `/v1/auth/logout` | Odwołanie bieżącej sesji |
| `GET` | `/v1/me` | Odczyt własnego konta |
| `POST` | `/v1/profile` | Utworzenie własnego profilu |
| `GET` | `/v1/profile` | Odczyt bieżącego własnego profilu |
| `PATCH` | `/v1/profile` | Aktualizacja własnego profilu |
| `DELETE` | `/v1/profile` | Usunięcie własnego profilu |
| `POST` | `/v1/recipe-searches` | Uruchomienie zadania wyszukiwania przepisów |
| `GET` | `/v1/recipe-searches/{id}` | Odczyt stanu i strony wyników |
| `POST` | `/v1/recipe-searches/{id}/cancel` | Żądanie anulowania wyszukiwania |
| `GET` | `/v1/recipes/{version_id}` | Odczyt wersji przepisu |
| `POST` | `/v1/recipes/{version_id}/variants` | Utworzenie prywatnej wersji przepisu |
| `GET` | `/v1/recipes/{version_id}/estimate` | Odczyt ostatniego dostępnego szacunku |
| `GET` | `/v1/estimates/{estimate_id}` | Odczyt konkretnego niemutowalnego szacunku |
| `GET` | `/v1/food-products` | Wyszukanie kandydatów produktów przez własny serwer |
| `GET` | `/v1/recipes/{version_id}/ingredients/{ingredient_id}/matches` | Odczyt kandydatów dopasowania składnika |
| `PATCH` | `/v1/recipes/{version_id}/ingredients/{ingredient_id}/match` | Wybór produktu i utworzenie nowego szacunku |
| `GET` | `/v1/plan` | Odczyt dnia: plan |
| `POST` | `/v1/plan/entries` | Utworzenie wpisu |
| `GET` | `/v1/plan/entries/{id}` | Odczyt konkretnego wpisu |
| `PATCH` | `/v1/plan/entries/{id}` | Aktualizacja wpisu |
| `DELETE` | `/v1/plan/entries/{id}` | Usunięcie wpisu |
| `GET` | `/v1/diary` | Odczyt dnia: dziennik |
| `POST` | `/v1/diary/entries` | Utworzenie wpisu |
| `GET` | `/v1/diary/entries/{id}` | Odczyt konkretnego wpisu |
| `PATCH` | `/v1/diary/entries/{id}` | Aktualizacja wpisu |
| `DELETE` | `/v1/diary/entries/{id}` | Usunięcie wpisu |
| `GET` | `/v1/operations/{operation_id}` | Sprawdzenie zastosowania własnej operacji |
| `GET` | `/v1/sync/changes` | Migawka początkowa lub przyrost zmian konta |
| `POST` | `/v1/labels/parse` | Opcjonalny OCR etykiety po stronie serwera |

## Sesja i konto

`GET /v1/capabilities` jest publiczny. Zwraca dostępność logowania Google i serwerowego OCR oraz parametry czasowe wyszukiwania. Jest konfiguracją funkcji, a nie dowodem dostępności dostawcy modelu lub źródła.

Logowanie hasłem/Google zwraca `AuthResult`: konto i `SessionTokens`. Serwer sam weryfikuje credential Google; zgodny email nie łączy kont automatycznie. `409 ACCOUNT_LINK_REQUIRED` opisuje sytuację wymagającą odrębnego przepływu. Polityka hasła, weryfikacji email i łączenia kont pozostaje w ADR-106; kontrakt rejestracji jawnie obsługuje `authenticated` z tokenami albo `verification_required` bez tokenów.

- Access token jest początkowo ważny 15 minut. `refresh_expires_at` ma `null`; sesja nie ma stałego terminu automatycznego wylogowania, ale może zostać odwołana.
- Po wygaśnięciu dostępu klient wykonuje jedno współdzielone odnowienie i ponawia pierwotne żądanie najwyżej raz z nowym tokenem. Dalsza odmowa odnowienia wymaga logowania.
- Brak sieci i `5xx` podczas odnowienia nie wylogowują ani nie kasują danych/kolejki. Odwołana sesja wstrzymuje wysyłanie i dostęp do danych konta; zachowane zmiany można wznowić dopiero po zalogowaniu na to samo konto.
- `revocation_token` jest oddzielnym poświadczeniem, uprawniającym wyłącznie do odwołania konkretnej sesji. `POST /v1/auth/logout` przyjmuje ten token i nie wymaga ważnego access tokenu. Powtórne odwołanie zwraca `204`.
- Po wylogowaniu offline klient usuwa access/refresh tokeny, a może zachować wyłącznie ticket odwołania, który nie pozwala zalogować się lub czytać danych. Odwołanie na serwerze pozostaje niepotwierdzone do czasu otrzymania odpowiedzi.
- Przy niewysłanych zmianach przed wylogowaniem użytkownik wybiera synchronizację teraz, powrót albo wylogowanie z ich usunięciem. Nieudana synchronizacja nie oznacza zgody na usunięcie.

Profil jest zasobem pojedynczym konta, ale ma własne UUID. Dlatego `PATCH /v1/profile` zawiera `id` i `version`, a `DELETE /v1/profile` ma oba parametry w query. Opóźniona operacja dotycząca starego profilu nie może zmienić nowego profilu, nawet jeśli ma on ponownie `version=1`.

## Wyszukiwanie i stronicowanie

1. `POST /v1/recipe-searches` przyjmuje `SearchCreate` z kryteriami i `use_profile`; zwraca `202 SearchCreated`, `Location` i identyfikator zadania.
2. `GET /v1/recipe-searches/{id}` zwraca `SearchPage`: status, wyniki, ostrzeżenia, błąd i terminy. Odczyt zadania nie uruchamia ponownie narzędzia LLM.
3. Początkowo klient odpytuje co 2 sekundy przez 20 sekund, następnie co 5 sekund. Kończy odpytywanie po stanie końcowym, opuszczeniu widoku, utracie sieci lub przejściu w tło; zadanie nadal działa na serwerze.
4. Po powrocie klient sprawdza ten sam identyfikator. Wyraźne „Szukaj ponownie” po niepowodzeniu tworzy nowe zadanie i nową operację.

| Status | Znaczenie |
| --- | --- |
| `pending` / `running` | Oczekuje / trwa. Terminy zakończenia i retencji są jeszcze `null`. |
| `completed` | Poprawny koniec; pusta lista oznacza brak trafień. |
| `partial` | Koniec z dostępnymi wynikami i ostrzeżeniami o ograniczeniach. |
| `failed` | Koniec bez dostępnych wyników, z opisanym błędem wykonania. |
| `cancelling` | Żądanie anulowania przyjęte, przerwanie jeszcze niepotwierdzone. |
| `cancelled` | Serwer potwierdził anulowanie; wcześniejsze wyniki mogą pozostać do wglądu. |

Poprawny odczyt zadania zwraca `200`, również dla `status=failed`; błąd wykonania jest wtedy w `error`. Ograniczenie wyszukiwania nie jest tym samym co nieudane żądanie HTTP.

Limit zadania to początkowo 300 sekund od utworzenia, łącznie z kolejką i próbami serwera. Po przekroczeniu zadanie kończy się `partial` z wynikami albo `failed` z `SEARCH_TIMEOUT`. Konfiguracja jest jawna w capabilities i `deadline_at`; nie wyciągamy stanu zadania z lokalnego timeoutu HTTP.

Anulowanie: `POST .../cancel` z kluczem operacji daje `202` i `cancelling` albo `200` dla stanu końcowego. Klient czeka na potwierdzenie `cancelled`; brak sieci nie potwierdza anulowania. Wyścig z ukończeniem zwraca rzeczywisty stan końcowy.

Status zakończonego zadania i odnośniki wyników żyją 30 dni od `finished_at`; po retencji `410 SEARCH_EXPIRED`. Nie usuwa to wersji ani migawek potrzebnych do planu i dziennika.

Wszystkie listy mają `limit` 1–100 (domyślnie 20), `cursor` i stabilną kolejność. Pierwsza strona ustala migawkę listy; kursor kontynuuje tę samą migawkę, nie miesza pozycji z różnych chwil. Wyniki zadania mają dodatkowo `results_revision`. Jeśli migawka strony nie jest już dostępna, `410 PAGE_EXPIRED` każe pobrać pierwszą stronę tego samego zasobu, bez uruchamiania nowego zadania.

## Przepisy, produkty i szacunki

`RecipeSummary` jest kartą wyniku, a `RecipeDetail` szczegółem wersji. Dane narzędzia LLM są walidowane i normalizowane na serwerze. Brakujące składniki/kroki mają `null` oraz stan `missing`; lista znana, ale niepełna ma stan `partial`. Deklarowane wartości portalu mają odrębne `declared_nutrition` z podstawą np. na 100 g.

`RecipeEstimate` opisuje niemutowalny rachunek: `total`, `per_serving`, kompletność każdej wielkości, źródła i wkłady składników. `per_serving` jest `null`, gdy nie znamy liczby porcji. Wartość pominięta nie staje się zerem; `missing` nie może być oznaczone jako kompletna wartość.

- `/recipes/{version_id}/estimate` jest widokiem ostatniego dostępnego szacunku konta. Brak szacunku daje `404 ESTIMATE_NOT_AVAILABLE`.
- `/estimates/{estimate_id}` odtwarza konkretny historyczny szacunek; wynik wyszukiwania, plan i migawka wskazują przypięte ID.
- Prywatny wariant, wybór produktu i szacunek są autoryzowane niezależnie od dostępności przepisu źródłowego. Współdzielone źródło nie daje dostępu do cudzych obliczeń.
- Zmiana ilości, jednostki lub kroków tworzy nowy wariant przez `POST .../variants`. Nie nadpisuje składników źródła ani istniejących szacunków.
- Wybór produktu przez `PATCH .../match` przyjmuje tylko produkt i `base_estimate_id`. Zwraca nowy prywatny `RecipeEstimate`, zachowując historię. Podstawa musi odpowiadać bieżącemu widocznemu szacunkowi; `null` oznacza brak poprzedniego szacunku.
- Kandydatów można pobrać przez własny serwer, bez kluczy zewnętrznego dostawcy na telefonie. Wybór dostawcy nadal pozostaje w ADR-104.

Kompletność zadania wyszukiwania i kompletność wartości odżywczych są niezależne: poprawne wyszukiwanie może zwrócić przepis z częściowym szacunkiem.

## Plan i dziennik

`PlanCreate` przyjmuje UUID, dzień, wersję przepisu, przypięty szacunek lub `null` i liczbę porcji. Serwer buduje migawkę; klient nie wysyła właściciela ani gotowych sum. `recipe_estimate_id=null` zachowuje jawne braki, nie wybiera po cichu najnowszego szacunku.

Plan może wskazywać wersję `source` albo `approved`; wariant `proposal` wymaga zatwierdzenia. Szacunek musi dotyczyć tego samego przepisu i być dostępny dla konta. Zmiana wersji przepisu w `PlanPatch` wymaga jawnego podania `recipe_estimate_id` (może być `null`); nie przenosimy starego szacunku na inny przepis.

`DiaryCreate` ma dwa warianty:

- `origin=plan`: przypięty przepis/szacunek i faktyczna ilość; serwer tworzy odrębną migawkę. `plan_entry_id` może być `null`, jeżeli plan wcześniej usunięto, a zapis zachowuje dostępne, autoryzowane źródło posiłku.
- `origin=manual` lub `label`: nazwa, faktyczna ilość i potwierdzone `UserNutritionInput` na podaną ilość/jednostkę odniesienia. Źródło `manual`/`label` nadaje serwer; klient nie może deklarować pochodzenia z zewnętrznej bazy.

`DiaryPatch` nie zmienia `origin`. Korekta `nutrition_reference` dotyczy wyłącznie ręcznych/etykietowych danych. Zmiana ilości przelicza własną zachowaną podstawę, nie aktualne dane dostawcy. Brak wiarygodnego przelicznika pozostaje jawnym brakiem, a nie nową wymyśloną wartością.

Dzień planu i dziennika zwraca `items` i `totals`; suma obejmuje cały dzień z tej samej migawki `as_of`, nie tylko bieżącą stronę. Są to dwa odrębne podsumowania. Zmiana planu nie zmienia historii dziennika. Po usunięciu planu serwer usuwa jedynie powiązanie wpisów dziennika, zwiększa ich wersję i publikuje tę zmianę; wartości migawek pozostają bez zmian.

## Wersje, idempotencja i odzyskiwanie operacji

Każda mutacja zasobu domenowego wymaga `Idempotency-Key`: niezmiennego UUID operacji. Identyfikator jest związany z kontem, metodą, ścieżką, parametrami i treścią. Nie dotyczy to tworzenia/odnawiania sesji ani nieidempotentnego, opcjonalnego odczytu OCR.

Serwer sprawdza wcześniejsze zastosowanie operacji przed oceną aktualnej wersji zasobu. Zastosowanie zmiany, potwierdzenie operacji i wpisy w dzienniku zmian są jedną transakcją. Powtórzenie identycznej operacji odtwarza wynik, nawet jeśli później zasób zmienił wersję; inna treść pod tym samym kluczem daje `409 IDEMPOTENCY_CONFLICT`.

- `PATCH` wymaga `version` w body; `DELETE` ma `version` w query i nie ma body. Brak zgodności daje `409 VERSION_CONFLICT`.
- Sukces mutacji ma `X-Operation-Id`; odtworzone potwierdzenie może mieć `Idempotency-Replayed: true`. Odtworzona odpowiedź potwierdza zastosowanie historycznej operacji, nie musi być najnowszym stanem zasobu.
- `GET /v1/operations/{operation_id}` daje potwierdzenie z wersją zastosowania. `404` oznacza brak trwale zastosowanej operacji na chwilę odczytu; można powtórzyć ten sam klucz i treść. `409 OPERATION_IN_PROGRESS` każe dalej czekać, bez tworzenia nowej operacji.
- `410 RESOURCE_DELETED` jest dostępne tylko dla właściciela znanego usuniętego zasobu; cudzego ID nie odróżniamy od nieistniejącego (`404`).
- Potwierdzenia i rezerwacje wykorzystanych ID muszą chronić również po długim offline i restarcie serwera. 30 dni historii wyszukiwania/cache nie jest terminem dopuszczającym ponowne wykonanie operacji. Szczegóły fizycznej retencji nadal wymagają ADR-111 zgodnego z tą gwarancją.

Przy konflikcie klient zachowuje lokalną zmianę, pobiera bieżący zasób i pokazuje wybór wersji. Zastosowanie zmian lokalnych do nowej bazy jest nową operacją z aktualną wersją, nie obejściem kontroli. Odtworzenie usuniętego wpisu wymaga wyraźnego wyboru i nowego ID. Konflikt wstrzymuje tylko dany zasób i jego zależności.

## Synchronizacja offline

`GET /v1/sync/changes` uzupełnia zwykłe odczyty zasobów o pewne wykrywanie zmian i usunięć na innych urządzeniach. Obejmuje profil, plan i dziennik; nie przesyła tokenów, zdjęć ani całej historii wyszukiwań.

1. Bez kursora serwer ustala spójną migawkę konta z granicą zmian i zwraca `mode=snapshot`.
2. `next_cursor` kontynuuje tę samą migawkę/partię. Dopiero końcowa strona ma `next_cursor=null` i niepusty `sync_cursor` do kolejnego odczytu.
3. Podanie `sync_cursor` zwraca `mode=delta`: zmiany `upsert` i `delete` po zapamiętanej granicy. Granica końca partii jest stała przez jej stronicowanie; zmiany późniejsze trafią do następnej partii.
4. Klient trwale zapisuje dane i kursor razem. Nie przedstawia niekompletnej migawki początkowej jako pełnej; dane pobierane etapowo nie nadpisują lokalnego widoku oczekujących operacji.
5. Wygasły/niedostępny kursor daje `410 SYNC_CURSOR_EXPIRED`; klient pobiera pełną migawkę ponownie, zachowując lokalną kolejkę, wersje bazowe i znaczniki lokalnych usunięć.

Kursory są nieprzezroczyste, przypisane do konta i nie dają dostępu innemu kontu. Powtórzenie tej samej strony nie zmienia wyniku jej migawki. Klient nie wylicza kursora ze znacznika czasu; serwer potrzebuje monotonicznego porządku zmian, żeby nie zgubić równoczesnych zapisów.

Lokalna zmiana i kolejka są jedną transakcją. Wysyłanie startuje po uruchomieniu/powrocie aplikacji, odzyskaniu sieci lub ręcznym ponowieniu. Nowe wpisy mają stałe UUID; zależne operacje czekają na potwierdzenie utworzenia zasobów. Dopiero ustalona wysyłana treść dostaje niezmienny klucz ponowień.

Potwierdzenie operacji najpierw uzgadnia lokalną wersję i zależności, dopiero potem pozwala usunąć element kolejki. Pobrana wersja serwerowa jest oddzielona od lokalnej. Konto B nie widzi danych ani kolejki A. Dla UI pozostają stany `pending`, `syncing`, `conflict`, `error`, `synced`.

Cache obejmuje profil, pobrane wpisy, ostatnie wyniki i otwarte przepisy. Dane konta pozostają do wylogowania. Podręczne wyniki/przepisy można usuwać po 30 dniach, jeśli nie są potrzebne do wpisów ani kolejki. Pamięć danych żywieniowych dostawcy i treści źródłowych nadal podlega osobnym regułom.

## Błędy i stany sieciowe

Stały format: `code`, `message`, `details` (obiekt lub `null`), `request_id`. Szczegóły walidacji są w `details.field_errors`; konflikt może wskazywać typ/ID zasobu i aktualną wersję. Specyfikacja zawiera pełny enum kodów i przykłady dla poszczególnych statusów HTTP.

Backend FastAPI musi mapować także własne błędy walidacji do tego formatu; domyślna odpowiedź z samym `detail` nie realizuje kontraktu.

| HTTP | Przykładowe znaczenie |
| --- | --- |
| `401` | Nieważny access token albo odrzucone poświadczenie odnowienia; klient rozróżnia etap i kod. |
| `404` | Zasób niedostępny/brak; również ochrona prywatnych danych. |
| `409` | Wersja, inna treść operacji, zależność, zastąpiony profil lub operacja nadal wykonywana. |
| `410` | Usunięcie zasobu albo wygaśnięcie kursora/zadania; kod określa dalszą akcję. |
| `422` | Niepoprawne pola lub reguły domeny. |
| `429` | Limit; klient uwzględnia `Retry-After`. |
| `503` | Niedostępność lub wyłączona funkcja. |
| `500` | Nieoczekiwany błąd bez ujawniania szczegółów implementacji. |

Dla przejściowych błędów odczytów i idempotentnych zapisów są maksymalnie 3 próby łącznie, przerwy 2 i 5 sekund; `Retry-After` ma pierwszeństwo. Wartości początkowe transportu: 5 sekund na połączenie i 20 sekund na odpowiedź. Nie są limitem całego wyszukiwania.

`422`, konflikty, niedostępne zasoby, wygasłe kursory i błędy certyfikatu nie uruchamiają zwykłej pętli retry. `401` ma procedurę odnowienia sesji. Klient obsługuje także timeout, DNS, brak sieci i niepoprawną odpowiedź proxy bez JSON; nie udaje wtedy, że otrzymał domenowy błąd serwera. Po limicie prób zachowuje formularz i kolejkę oraz pokazuje „Ponów”. Polling i retry nie mogą tworzyć nakładających się pętli.

## OCR i stany widoków

`POST /v1/labels/parse` jest jawnie oznaczony w OpenAPI jako opcjonalny (`x-feature-gate=server_ocr`). `capabilities.features.server_ocr=false` oznacza brak tej funkcji; kontrakt nie przesądza wyboru OCR na urządzeniu lub serwerze. Endpoint przyjmuje zdjęcie, zwraca szkic z polami niepewnymi i nigdy nie tworzy wpisu dziennika. Przesyłanie/retencja zdjęć wymaga rozstrzygnięcia ADR-107/111.

Pierwsze pobranie bez danych pokazuje ładowanie. Odświeżanie zachowuje dane. Offline pokazuje cache i datę synchronizacji, a brak cache — „Brak danych na urządzeniu”. Lokalny zapis aktualizuje widok z „Oczekuje na synchronizację”. Błąd nie usuwa formularza ani zmian. Przy nowym zapytaniu stare wyniki są oznaczone, a spóźniona odpowiedź nie zastępuje aktywnego zadania. Postęp wyszukiwania pokazuje rzeczywisty status, bez fikcyjnego procentu.

## Zakres weryfikacji

[Testy kontraktu](../tests/contracts/test_openapi.py) sprawdzają standard OpenAPI, lokalne odwołania, przykłady żądań/odpowiedzi, formaty błędów i [przypadki regresyjne](api/contract-cases.json). [Instrukcja walidacji](api/README.md) opisuje uruchamianie i ograniczenia.

Warunki między polami, które da się wyrazić w JSON Schema, są zakodowane, m.in. brak wartości na porcję przy nieznanej liczbie porcji i brak zamiany `missing` na zero. Weryfikacja strefy IANA, min <= max zakresu, zgodności ID między zasobami, autoryzacji, rachunku, atomowości i odtwarzania operacji wymaga testów działającego backendu. Samo przejście walidacji specyfikacji nie dowodzi ich implementacji.

Format standardu opisuje [OpenAPI 3.1.0](https://spec.openapis.org/oas/v3.1.0.html). Pozostałe otwarte decyzje konta, źródeł i OCR są w rejestrze; ten kontrakt konkretyzuje komunikację bez wybierania tych dostawców.
