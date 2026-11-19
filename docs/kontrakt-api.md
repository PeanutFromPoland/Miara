# Kontrakt API aplikacji — ustalenia MVP

> Status: zasady i zachowanie przyjęte 13 listopada 2026 r. w [rozmowie decyzyjnej](ustalenia-api-i-stany.md). Dotyczy własnego serwera Python/FastAPI i klienta Flutter Android. Serwer nie istnieje jeszcze w repozytorium, a prototyp działa bez API. Poniższy kontrakt jest projektem do implementacji; maszynową specyfikację OpenAPI i testy zgodności należy przygotować w T-05. Nazwy pól i techniczne reguły poniżej konkretyzują przyjęte decyzje.

## Reguły wspólne

- Transport: HTTPS; JSON UTF-8 dla danych strukturalnych. Daty zdarzeń w ISO 8601 UTC, dni planu i dziennika jako `YYYY-MM-DD` w strefie konta.
- Żądania prywatne: `Authorization: Bearer <token>`. Serwer pobiera `account_id` z sesji, nigdy z pola klienta. Brak lub nieważny token: `401`; cudzy zasób: `404`, bez ujawniania jego istnienia.
- Aktualizacja i usunięcie zawierają całkowitą `version` ostatniej potwierdzonej wersji; konflikt daje `409 VERSION_CONFLICT`. Pominięte pole `PATCH` pozostaje bez zmiany; jawne `null` usuwa wartość tylko w polach dopuszczających brak.
- Mutacje używają `Idempotency-Key` równego niezmiennemu UUID operacji. Klucz jest związany z kontem, metodą, ścieżką i treścią żądania. Odpowiedź utracona po zapisie nie uzasadnia nowego klucza. Inna treść z tym samym kluczem daje `409 IDEMPOTENCY_CONFLICT`.
- Nowe profile, wpisy planu i dziennika mają UUID nadany przez klienta; serwer zachowuje go i egzekwuje własność. Numer wersji nadaje serwer. Ochrona przed powtórzeniem obejmuje `POST`, `PATCH` i `DELETE`, także po restarcie serwera. Potwierdzenia operacji muszą być przechowywane tak długo, jak niepotwierdzony klient może je ponowić; sam upływ 30 dni cache nie może pozwolić na ponowne zastosowanie zmiany. W T-05 utrwalić schemat potwierdzeń i usunięć zgodny z tą regułą.
- Każda lista ma jawny limit, kursor strony i stabilną kolejność. Parametry wejścia są walidowane na serwerze; błędne pole daje `422` z nazwą pola.
- Jednostki występują w polach, nie w samej nazwie wartości. Pola nieznane mają `null`, a wynik niepełny ma `completeness: "partial"` oraz `missing`.
- Odpowiedź błędu ma wspólny kształt: `code`, `message`, `details?`, `request_id`. `message` jest bezpieczny do pokazania użytkownikowi; szczegóły techniczne pozostają w logach serwera. Nieudana integracja daje błąd lub wynik częściowy, nigdy fikcyjną liczbę.
- Kontrakt jest wersjonowany. Zmiana znaczenia istniejącego pola wymaga nowej wersji; nowe opcjonalne pole nie powinno łamać klienta.
- Wynik narzędzia LLM jest normalizowany i walidowany na serwerze. Flutter otrzymuje DTO kontraktu, a nie zależną od modelu surową odpowiedź.

## Sesja i profil

| Metoda i ścieżka | Cel i minimalne dane | Sukces | Wymagania |
| --- | --- | --- | --- |
| `POST /v1/auth/register` | Adres email, hasło według przyjętej polityki | `201`, identyfikator konta i sesja lub krok weryfikacji | RF-M01 |
| `POST /v1/auth/login` | Email, hasło | `200`, token sesji i termin ważności | RF-M01–M02 |
| `POST /v1/auth/google` | Poświadczenie Google z klienta, które serwer musi sam zweryfikować | `200`, własna sesja po weryfikacji | RF-M01 |
| `POST /v1/auth/refresh` | Poświadczenie odnowienia własnej sesji | `200`, nowy token dostępu i termin jego ważności | RF-M02 |
| `POST /v1/auth/logout` | Bieżąca sesja | `204`, unieważnienie sesji zgodnie z polityką | RF-M02 |
| `GET /v1/me` | Dane minimalne zalogowanego konta | `200` | RF-M01–M02 |
| `POST /v1/profile` | Cele, preferencje, wykluczenia, alergeny | `201`, profil z `version` | RF-M03, RF-M19 |
| `GET /v1/profile` | Bez parametrów | `200` lub `404` gdy nie utworzono | RF-M03, RF-M19 |
| `PATCH /v1/profile` | Zmieniane pola i wersja | `200`, zaktualizowany profil | RF-M03, RF-M19 |
| `DELETE /v1/profile` | Wersja | `204` | RF-M03, RF-M19 |

Sesja nie ma stałego terminu automatycznego wylogowania. Techniczny punkt startowy: token dostępu ważny 15 minut, `session_id`, `access_token`, `access_expires_at` oraz odrębne `refresh_token` i `refresh_expires_at: null`. Poświadczenie odnowienia jest odwoływalne; serwer przechowuje jego bezpieczny skrót, a telefon tokeny w bezpiecznym magazynie Androida. Nie przyjęto limitu 7 ani 30 dni sesji.

Po wygaśnięciu dostępu klient odnawia go automatycznie i ponawia pierwotne żądanie najwyżej raz z nowym tokenem. Równoległe żądania współdzielą jedno odnowienie. Błąd sieci lub `5xx` przy odnowieniu nie wylogowuje i nie usuwa kolejki. Dopiero odmowa odnowienia z powodu nieważnej/odwołanej sesji wymaga logowania; do tego czasu niewysłane zmiany pozostają odizolowane i nie są wysyłane z sesją innego konta.

Przy wylogowaniu z niewysłanymi zmianami użytkownik wybiera synchronizację, powrót albo wylogowanie z ich usunięciem. Dopiero zakończona synchronizacja albo jawny wybór usunięcia pozwala wyczyścić dane. Wylogowanie lokalne działa również offline; odwołanie sesji na serwerze jest wtedy niepotwierdzone i nie wolno pokazywać go jako wykonane. Polityka haseł, weryfikacji adresu, łączenia Google z istniejącym kontem i usunięcia konta pozostaje osobnym zakresem ADR-106/111.

## Odkrywanie, przepis i szacunek

| Metoda i ścieżka | Cel i minimalne dane | Sukces | Wymagania |
| --- | --- | --- | --- |
| `POST /v1/recipe-searches` | Nazwa dania?, maksymalny czas?, maksymalna liczba składników?, zakres kcal/makro na porcję? | `202`, `search_id` i stan | RF-M04–M05, RF-M15 |
| `GET /v1/recipe-searches/{id}` | Status i wyniki stronicowane | `200`, jeden ze stanów opisanych poniżej | RF-M05, RF-M13–M15 |
| `POST /v1/recipe-searches/{id}/cancel` | Żądanie anulowania z kluczem idempotencji | `202` dla `cancelling` lub `200` dla stanu końcowego | RF-M05, RF-M15 |
| `GET /v1/recipes/{version_id}` | Wersja przepisu, URL źródła, data odczytu, składniki, luki, zmiany | `200` | RF-M06–M09 |
| `POST /v1/recipes/{version_id}/variants` | Proponowane lub zatwierdzone zmiany składników/porcji | `201`, nowa wersja z opisem zmian | RF-M08–M09 |
| `GET /v1/recipes/{version_id}/estimate` | Szacunek na całość i porcję, źródła, kompletność | `200`, także dla częściowego wyniku | RF-M10–M12 |
| `PATCH /v1/recipes/{version_id}/ingredients/{id}/match` | Wybór produktu lub korekta ilości/jednostki i wersja | `200`, nowy stan dopasowania/szacunku | RF-M07, RF-M10–M12 |

Żądanie `POST /v1/recipe-searches` przesyła JSON z wymaganym niepustym `query` oraz opcjonalnymi filtrami `max_time_minutes`, `max_ingredients`, `min_kcal_per_serving`, `max_kcal_per_serving`, `min_protein_g_per_serving` i `vegetarian_only`. Klient pomija filtry, których użytkownik nie ustawił. Idempotency key identyfikuje utworzenie zadania.

Wyszukiwanie jest zadaniem asynchronicznym. `POST` zwraca `202` z `search_id`, `status`, `created_at` i `deadline_at`. Stan i strony wyników mają `search_id`, `status`, `results`, `next_cursor`, `warnings`, `error`, `finished_at` i `expires_at`; brak błędu lub kursora oznacza `null`. Serwer zapisuje URL i datę odczytu, nie udaje, że proponowana przez agenta wersja pochodzi ze strony.

| Stan | Znaczenie i zachowanie klienta |
| --- | --- |
| `pending` | Zadanie czeka na wykonanie. |
| `running` | Zadanie jest przetwarzane; wyniki mogą pojawiać się stopniowo. |
| `completed` | Przetwarzanie zakończone; `results: []` oznacza brak trafień. |
| `partial` | Stan końcowy: część wyszukiwania zawiodła lub przekroczyła czas, ale dostępne są wyniki i ostrzeżenia. |
| `failed` | Stan końcowy: awaria uniemożliwiła uzyskanie wyników; `error` opisuje przyczynę. |
| `cancelling` | Serwer przyjął żądanie anulowania, ale nie potwierdził jeszcze zakończenia pracy. |
| `cancelled` | Serwer potwierdził anulowanie zadania; wcześniejsze dostępne wyniki mogą pozostać do wglądu. |

- Limit serwera wynosi 300 sekund od utworzenia zadania, łącznie z oczekiwaniem i próbami po stronie serwera. Po limicie zadanie ma `partial` z ostrzeżeniem o czasie albo `failed` z kodem `SEARCH_TIMEOUT`. Parametr jest konfigurowalny i wymaga pomiaru.
- Klient odpytuje co 2 sekundy przez pierwsze 20 sekund, potem co 5 sekund. Odpytywanie ustaje po stanie końcowym, opuszczeniu obserwowanego widoku, utracie połączenia lub przejściu w tło; zadanie nadal działa.
- Po powrocie klient odczytuje ten sam `search_id`. Utrata połączenia lub timeout pojedynczego HTTP nie oznacza niepowodzenia całego zadania. Ponowienie utworzenia po utracie odpowiedzi zachowuje ten sam klucz operacji.
- Wyjście z ekranu nie anuluje zadania. „Anuluj” wymaga połączenia; brak odpowiedzi nie potwierdza anulowania. Jeśli zadanie już się zakończyło, serwer zwraca rzeczywisty stan końcowy zamiast zmieniać go w `cancelled`.
- Status zakończonego zadania i odnośniki do wyników są przechowywane 30 dni od zakończenia; usunięte zadanie daje `410 SEARCH_EXPIRED`. Retencja zadania nie usuwa wersji potrzebnych do planu/dziennika ani ich migawek.
- `partial` zadania opisuje przebieg wyszukiwania. `completeness: "partial"` szacunku opisuje braki wartości odżywczych; są to niezależne stany.

Wersja źródłowa przepisu może być współdzielona, ale wariant i poprawki użytkownika są prywatne. Serwer sprawdza własność przy `GET /v1/recipes/{version_id}`, tworzeniu wariantu, korekcie dopasowania i pobraniu szacunku oraz filtruje wyniki wyszukiwania. Przekazanie cudzego `version_id` do planu nie daje dostępu do wariantu.

Minimalny fragment wyniku wyszukiwania:

```json
{
  "recipe_version_id": "rv_123",
  "title": "Przykładowe danie",
  "source": { "url": "https://example.org/przepis", "retrieved_at": "2026-11-06T10:00:00Z" },
  "estimate_per_serving": {
    "kcal": 420,
    "protein_g": 24.5,
    "carbohydrate_g": null,
    "fat_g": 12.0,
    "completeness": "partial",
    "missing": ["ilość składnika 2", "węglowodany dla produktu 3"]
  },
  "match": { "status": "unverified", "reasons": ["niepełny skład"] }
}
```

Przykład jest ilustracją formatu, a nie danymi żywieniowymi. `status: "unverified"` nie oznacza zgodności przy alergii. Każdy wynik rankingu powinien podać kryteria użyte, niespełnione i nieweryfikowalne (RF-M13–M14).

### Stały model przepisu

Karta wyniku zawiera pola z przykładu: `recipe_version_id`, `title`, `source`, `estimate_per_serving` i `match`. `GET /v1/recipes/{version_id}` rozszerza je o poniższe pola. Nieznane dane są obecne jako `null`; pusta lista oznacza ustalony brak elementów, a nie nieudaną ekstrakcję.

| Pole | Typ i znaczenie |
| --- | --- |
| `recipe_version_id`, `title` | Niepuste ciągi znaków; serwer identyfikuje wersję i tytuł przed pokazaniem karty. |
| `source` | Obiekt `url`, `domain`, `retrieved_at`; pochodzenie jest zachowane także po zmianach. |
| `ingredients` | Lista lub `null`; element: `id`, `name`, `quantity` (number lub null), `unit` (string lub null), `normalized_quantity` (number lub null), `normalized_unit` (g, ml lub null), `conversion_basis` (string lub null), `review_state`. |
| `instructions` | Lista kroków `{position, text}` lub `null`, wyłącznie w zakresie dopuszczonym dla źródła. |
| `servings`, `total_mass_g` | Dodatnie liczby lub `null`. Masa dania nie jest liczbą porcji. |
| `prep_time_minutes`, `cook_time_minutes` | Nieujemne liczby lub `null`; czas przygotowania i obróbki są osobnymi polami. |
| `declared_nutrition` | Obiekt lub `null`: `per_amount`, `per_unit`, `kcal`, `protein_g`, `carbohydrate_g`, `fat_g`, `source`. Deklaracja portalu zachowuje podstawę np. 100 g. |
| `estimate_total`, `estimate_per_serving` | Obiekt lub `null`: nullable kcal i makro, `completeness`, `missing`, `calculated_at`, `calculation_version`, `sources`. Wartość na porcję wymaga znanej liczby porcji. |
| `missing` | Lista braków `{field, reason}`; ścieżka pola pozwala wskazać konkretny składnik lub informację. |
| `changes`, `match` | Lista jawnych zmian względem źródła oraz status dopasowania z uzasadnieniami. |

Niepełny przepis może pozostać w wynikach. Nieznana ilość, jednostka lub liczba porcji blokuje tylko obliczenia wymagające tej informacji; nie wolno uzupełniać jej zgadywaniem. Zakres użycia instrukcji i innych treści nadal wynika z ADR-103.

## Plan i dziennik

| Metoda i ścieżka | Cel i minimalne dane | Sukces | Wymagania |
| --- | --- | --- | --- |
| `GET /v1/plan?date=YYYY-MM-DD` | Wpisy i suma planowanych wartości na dany dzień | `200` | RF-M16, RF-M19 |
| `POST /v1/plan/entries` | Data, `recipe_version_id`, liczba porcji | `201`, wpis i migawka szacunku | RF-M16, RF-M19 |
| `PATCH /v1/plan/entries/{id}` | Data/porcje/wersja przepisu, `version` | `200`, nowy wpis | RF-M16, RF-M19 |
| `DELETE /v1/plan/entries/{id}` | `version` | `204` | RF-M16, RF-M19 |
| `GET /v1/diary?date=YYYY-MM-DD` | Wpisy i suma faktycznego spożycia | `200` | RF-M17, RF-M19 |
| `POST /v1/diary/entries` | Źródło `plan` lub `manual`/`label`, faktyczna ilość, potwierdzone wartości | `201`, wpis | RF-M17–M19 |
| `PATCH /v1/diary/entries/{id}` | Korekta ilości/wartości, `version` | `200`, nowy wpis | RF-M17, RF-M19 |
| `DELETE /v1/diary/entries/{id}` | `version` | `204` | RF-M17, RF-M19 |

Suma planu i suma dziennika są wyliczane oddzielnie. Wpis dziennika utworzony z planu przechowuje `plan_entry_id` i własną migawkę faktycznej ilości; późniejsza zmiana lub usunięcie planu nie zmienia historii spożycia. Serwer zwraca `partial` i listę braków, gdy przynajmniej jedna składowa sumy nie ma danych.

## Etykieta i synchronizacja

`POST /v1/labels/parse` jest **opcjonalnym** endpointem tylko wtedy, gdy wybrano OCR po stronie serwera. Zwraca szkic pól (`per_amount`, `per_unit`, kcal, makro, `uncertain_fields`) i nigdy nie tworzy wpisu dziennika. Przy OCR na urządzeniu szkic pozostaje lokalny, a dopiero potwierdzone dane trafiają do `POST /v1/diary/entries`. Zdjęcie jest przesyłane i przechowywane wyłącznie w zakresie ustalonej decyzji o prywatności (RF-M18).

W MVP klient synchronizuje zasoby osobno przez ich endpointy; dodatkowy `GET /v1/sync-state` nie jest wymagany. Offline działa CRUD profilu, planu i dziennika na danych dostępnych na urządzeniu. Nowe wyszukiwanie i serwerowe OCR wymagają połączenia.

Zmiana lokalna i wpis do trwałej kolejki powstają atomowo. Widok od razu uwzględnia zmianę z oznaczeniem „Oczekuje na synchronizację”. Po starcie, powrocie aplikacji na pierwszy plan, odzyskaniu łączności lub ręcznym odświeżeniu klient odnawia sesję w razie potrzeby, pobiera aktualny stan bez nadpisywania lokalnych zmian i wysyła operacje w kolejności ich zależności. Potwierdzenie serwera uzgadnia wersję i sumy.

Konflikt daje `409 VERSION_CONFLICT`; aplikacja pobiera stan bieżący, zachowuje obie wersje i pozwala wybrać wersję serwera lub ponownie zastosować lokalne zmiany do najnowszej wersji. Wybranie lokalnej wersji nie omija kontroli wersji. Dla usuniętego na serwerze wpisu odtworzenie wymaga wyraźnego wyboru i nowego ID. Konflikt blokuje tylko dany zasób i zależne operacje.

Cache obejmuje profil, pobrane wpisy planu/dziennika, ostatnie wyniki i otwarte przepisy. Dane konta pozostają do wylogowania. Wyniki i przepisy można usuwać po 30 dniach, jeśli nie są potrzebne do wpisów lub kolejki. Cache, operacje i czas synchronizacji są przypisane do konta. Pobrana lista nie może przywrócić lokalnie usuniętego, jeszcze niewysłanego wpisu.

### Ponowienia i timeouty

- Maksymalnie 3 próby łącznie dla przejściowych błędów odczytów i idempotentnych zapisów; odstępy 2 i 5 sekund. `Retry-After` przy `429`/`503` ma pierwszeństwo i nie powoduje aktywnego oczekiwania w UI.
- Timeout transportu nie jest limitem zadania LLM. Techniczne wartości początkowe dla zwykłego HTTP: 5 sekund na zestawienie połączenia i 20 sekund na odpowiedź, konfigurowalne i do zweryfikowania przy implementacji.
- Nie ponawiamy automatycznie `422`, konfliktów `409`, cudzych/brakujących zasobów `404`, wygasłego zadania `410` ani błędów certyfikatu. `401` uruchamia opisaną procedurę odnowienia sesji, a nie zwykłą pętlę ponowień.
- Po limicie prób klient zachowuje formularz i kolejkę oraz pokazuje „Ponów”. Powrót sieci może rozpocząć nową serię synchronizacji. Nie nakładamy na siebie odpytywania zadania i kilku niezależnych pętli retry; połączenie z siecią nie oznacza automatycznie dostępności serwera.
- Ponowne uruchomienie zakończonego niepowodzeniem wyszukiwania jest nowym zadaniem dopiero po świadomym „Szukaj ponownie”. Ponowne sprawdzenie stanu istniejącego zadania nie tworzy nowego zadania.

## Kody błędów domenowych

| Kod | Znaczenie | Zachowanie klienta |
| --- | --- | --- |
| `VALIDATION_ERROR` | Błędne pole, zakres lub jednostka | Pokazać pole do poprawy |
| `UNAUTHENTICATED` | Brak lub wygaśnięcie sesji | Przejść do logowania; usunąć dane sesyjne zgodnie z polityką |
| `VERSION_CONFLICT` | Dane zmieniły się na serwerze | Pobrać aktualne dane i rozstrzygnąć konflikt |
| `IDEMPOTENCY_CONFLICT` | Identyfikator operacji użyty z inną treścią | Zatrzymać operację; nie nadpisywać ani nie ponawiać automatycznie |
| `RATE_LIMITED` | Limit żądań (`429`) | Uwzględnić `Retry-After` i zachować dane |
| `SEARCH_TIMEOUT` | Zadanie przekroczyło 5 minut | Pokazać błąd albo ostrzeżenie wraz z dostępnymi wynikami |
| `SEARCH_EXPIRED` | Zakończone zadanie usunięte po retencji (`410`) | Pokazać wygaśnięcie historii; umożliwić nowe wyszukiwanie |
| `SOURCE_UNAVAILABLE` | Strona przepisu niedostępna lub niedozwolona | Pokazać ograniczenie i inne wyniki |
| `NUTRITION_UNAVAILABLE` | API żywieniowe nie odpowiada | Zachować brak danych, pozwolić ponowić |
| `MODEL_UNAVAILABLE` | Skonfigurowany dostawca modelu nie odpowiada | Pokazać błąd bez automatycznej zmiany dostawcy |
| `INSUFFICIENT_DATA` | Brak ilości, porcji lub dopasowania | Wskazać brakujące pola; nie wyliczać pełnej wartości |

Brak sieci, timeout i nieudane połączenie z serwerem są stanami transportu po stronie klienta, nie odpowiedziami JSON otrzymanymi od serwera. Nie należy mylić ich z `MODEL_UNAVAILABLE`, gdy klient poprawnie połączył się z API, ale serwer zgłosił problem wykonania zadania. Prawidłowy `GET` zadania zwraca `200` także dla `status: "failed"`; błąd wykonania jest wtedy w polu `error`.

## Stany widoków

| Sytuacja | Zachowanie |
| --- | --- |
| Pierwsze pobranie bez cache | Widoczny stan ładowania. |
| Odświeżanie z danymi | Zachować dane i pokazać dyskretny wskaźnik odświeżania. |
| Offline z cache | Pokazać dane, informację o braku połączenia i ostatniej synchronizacji. |
| Offline bez cache | „Brak danych na urządzeniu”; nie pokazywać fikcyjnych rekordów. |
| Zapis lokalny | Natychmiastowy widok zmiany i stan „Oczekuje na synchronizację”. |
| Synchronizacja, konflikt, błąd | Osobne stany `syncing`, `conflict`, `error`; zachować lokalne zmiany i formularze. |
| Wyszukiwanie | Pokazać rzeczywisty stan zadania i możliwość anulowania; bez fikcyjnego procentu. |
| Nowe zapytanie przy starych wynikach | Zachować kontekst, ale wyraźnie oznaczyć wcześniejsze wyniki; spóźniona odpowiedź starego zadania nie zastępuje nowego wyszukiwania. |

Kontrakt należy utrwalić w OpenAPI i sprawdzać testami kontraktowymi między serwerem a Flutterem. Konfiguracja adresu serwera jest oddzielona od kodu domenowego i może korzystać z testowego API lub atrap do czasu uruchomienia backendu.
