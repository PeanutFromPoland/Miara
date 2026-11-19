# Plan wytwarzania Miary

## 1. Punkt wyjścia i cel

Miara ma być mobilną aplikacją wspierającą planowanie posiłków i prowadzenie dziennika, zgodnie z [wymaganiami funkcjonalnymi](wymagania_funkcjonalne_i_przypadki_uzycia.md). Wersja MVP obejmuje RF-M01–RF-M21. Funkcje RF-R01–RF-R05 pozostają w backlogu rozwoju po odbiorze MVP. Wyniki żywieniowe są **szacunkami**, a brak danych musi pozostać widoczny.

Stan repozytorium w dniu utworzenia planu: `app/` zawiera wygenerowany projekt Flutter z ekranem licznika i testem licznika; nie ma implementacji domenowej, serwera ani CI. `docs/prototyp-ui/` zawiera lokalny prototyp HTML/JS z danymi demonstracyjnymi. Zdalne repozytorium GitHub `origin` jest skonfigurowane, lecz bieżący Git śledzi tylko główny `README.md`; `app/` i `docs/` widnieją jako nieśledzone. Decyzją T-01 (2026-11-09) wybrano Python/FastAPI, PostgreSQL, wdrożenie on-premise oraz Androida jako platformę mobilną MVP. AniaGotuje.pl wybrano jako podstawowe źródło przepisów w ADR-012 (2026-11-13); warunki jego produkcyjnego użycia i wybór zewnętrznej bazy żywieniowej pozostają do rozstrzygnięcia.

13 listopada 2026 przyjęto [ustalenia API i stanów klienta](ustalenia-api-i-stany.md): stały JSON po walidacji narzędzia LLM, asynchroniczne wyszukiwanie z limitem 5 minut, trwałą sesję bez automatycznego wylogowania, CRUD offline z kolejką, ręczny wybór przy konflikcie i zachowanie danych w UI. Zasady odblokowują projektowanie modeli i klienta na atrapach; nie zastępują uruchomienia serwera, migracji i testów. Zakres T-23 obejmuje teraz zapisy offline, a nie tylko odczyt cache.

16 listopada 2026 przyjęto kolejność **model danych → przegląd → formaty komunikacji → OpenAPI** (ADR-014). Pierwszym produktem T-05 jest [wstępny model v0.1](model-danych.md) z typami, relacjami, migawkami i regułami offline. Wersje usług i wybór bazy żywieniowej nie blokują przygotowania tego szkicu; zostaną uwzględnione przy projekcie fizycznym i adapterach. OpenAPI opracowujemy na podstawie przejrzanego modelu.

Po poleceniu przejścia do kontraktu przygotowano [OpenAPI v0.1.0](api/openapi.json) i [opis jego reguł](kontrakt-api.md) (ADR-015). [Walidacja](api/README.md) sprawdza specyfikację i przykłady; migracje, implementacja serwera oraz testy rzeczywistego przepływu nadal należą do dalszej realizacji T-05 i zależnych zadań.

## 2. Produkty pracy

| Produkt | Minimalna zawartość | Gdzie utrzymywać |
| --- | --- | --- |
| Specyfikacja produktu | Wymagania, przypadki użycia, zakres MVP, ograniczenia i kryteria odbioru | `docs/` |
| Rejestr decyzji | Uzasadnienie wyborów, alternatywy, wpływ i warunki zmiany | `docs/decyzje/` po utworzeniu |
| Projekt techniczny | Granice komponentów, model danych, kontrakt API, przepływy i błędy | `docs/` |
| Kod i konfiguracja | Klient Flutter, serwer, migracje, przykładowa konfiguracja bez sekretów | `app/` i wybrany katalog serwera |
| Testy i dowody | Testy automatyczne, wyniki CI, scenariusze integracyjne, checklisty odbioru | Kod testów, `docs/` i GitHub Actions |
| Instrukcja uruchomienia | Wymagania środowiska, lokalny start, konfiguracja dostawców, migracje i demo | główny `README.md` lub `docs/` |

Dokumentację i kod zmienia się w tym samym zadaniu. Każda istotna zmiana zachowania aktualizuje powiązane wymaganie, kontrakt, test i instrukcję.

## 3. Bramki decyzji przed implementacją zależnych modułów

| Bramka | Decyzja i dowód | Blokuje |
| --- | --- | --- |
| G1: stos serwera | Python/FastAPI, PostgreSQL, on-premise i Android jako platforma MVP wybrane; pozostało ustalić wersje, migracje, backup/odtworzenie oraz minimalne środowisko uruchomieniowe. | Uruchomienie serwera, fizyczne migracje i CI serwera; nie blokuje wstępnego modelu logicznego. |
| G2: przepisy | AniaGotuje.pl jest źródłem podstawowym (ADR-012); wcześniejszą listę kandydatów i próbę HTML dokumentuje ADR-011. W pierwszej kolejności zweryfikować adapter `aniagotuje.pl`; produkcyjny odczyt i retencja treści wymagają potwierdzenia podstawy/licencji per domena (ADR-103). | Produkcyjny scraping, ekstrakcję i trwałe przechowywanie pól przepisu/mediów. |
| G3: wartości żywieniowe | Wybrane API/baza, licencja, limity, pokrycie typowych polskich składników, jednostki odniesienia, polityka cache i przykłady niejednoznacznych dopasowań. | Adapter danych, normalizację i kalkulator. |
| G4: dane i prywatność | Reguły sesji, cache, zapisów offline i konfliktów przyjęte (ADR-106 w części sesji, ADR-108, ADR-112). Pozostaje wykonać schematy i kontrakt, doprecyzować rejestrację/powiązanie kont oraz pełną retencję danych serwera. | Pozostałe decyzje dotyczą konta i danych rzeczywistych; przyjęte modele klienta, stany sieciowe i kolejkę można projektować bez ponownego wyboru wariantów. |
| G5: model AI | Kontrakt adaptera dla OpenAI API i LM Studio, pola konfiguracji, sprawdzenie połączenia, obsługa błędów i limitów. Operator wybiera dostawcę przy starcie; brak samoczynnego przełączania. | Orkiestrację agenta i testy obu konfiguracji. |

W bramkach G2 i G3 wynikiem może być również stwierdzenie, że kandydat nie spełnia wymagań. Wtedy należy wybrać inne źródło przed rozpoczęciem zależnej implementacji. Wybór nie może opierać się wyłącznie na działaniu pojedynczego przykładu.

## 4. Sekwencja iteracji

Iteracje wyznaczają kolejność zależności, a nie deklarację czasu. Zespół przypisuje terminy dopiero po oszacowaniu zadań i dostępności osób. Każda iteracja kończy się krótkim pokazem oraz przejściem odpowiednich checklist.

| Iteracja | Zadania z [backlogu](backlog-mvp.md) | Działający przyrost i bramka wyjścia |
| --- | --- | --- |
| 0. Ustalenia | T-01–T-06 | Zamknięte G1–G4, kontrakt API i model danych, repozytorium obejmuje kod/dokumenty, CI uruchamia testy szablonu. G1 ma wybrane technologie i platformę; szczegóły uruchomienia on-premise są udokumentowane. |
| 1. Konto i profil | T-07–T-11 | Konfiguracja modelu AI, rejestracja/logowanie, profil z trwałym CRUD, połączony klient Flutter. Test izolacji kont i błędów sesji. G5 zamknięta. |
| 2. Przepisy i liczby | T-12–T-18 | Pobranie dozwolonego przepisu, ekstrakcja, dopasowanie składników, szacunek i ekran z pochodzeniem oraz brakami. Weryfikacja na próbkach z G2/G3. |
| 3. Plan i dziennik | T-19–T-21 | Trwały plan i niezależny dziennik z sumami i pełnym CRUD. Przejście kluczowego przepływu użytkownika. |
| 4. Aparat i synchronizacja | T-22–T-23 | Potwierdzanie OCR przed zapisem, ręczne wprowadzenie, odczyt cache offline i czyszczenie danych po wylogowaniu. |
| 5. Odbiór | T-24–T-26 | Pełny zestaw testów, pomiar zasobów, powtarzalne wdrożenie i demonstracja RF-M01–RF-M21. |

Prace nad klientem i serwerem w ramach iteracji mogą iść równolegle po ustaleniu kontraktu. Testy jednostkowe i integracyjne powstają wraz z funkcją; T-24 scala je i zamyka luki pokrycia, a nie odkłada testowanie na koniec.

## 5. Przepływ pojedynczego zadania

1. Utworzyć zadanie z [szablonu](szablony-zadan.md), podając ID wymagania, zależności, wynik pracy, kryteria i testy.
2. Przed rozpoczęciem potwierdzić gotowość: zamknięte bramki i zależności, dostępne próbki danych, uzgodniony kontrakt, brak blokujących pytań.
3. Wprowadzić najmniejszy użyteczny przekrój pionowy. Kod domenowy oddzielić od interfejsów do sieci, bazy, OCR i modelu, aby można było testować go bez usług zewnętrznych.
4. Dodać testy właściwe dla zmiany i sprawdzić scenariusze błędu, brak danych, granice ilości oraz izolację kont tam, gdzie ma zastosowanie.
5. Zaktualizować dokumenty i instrukcję uruchomienia. Umieścić w PR dowody uruchomienia oraz wskazać zrealizowane RF.
6. Przeprowadzić przegląd kodu, przejść CI i checklistę Definition of Done. Dopiero wtedy zamknąć zadanie.

Gałęzie robocze i PR są domyślnym sposobem integracji. Nazwę gałęzi powiązać z ID zadania, np. `codex/T-13-kalkulator`. Nie umieszczać kluczy API, tokenów, zdjęć prywatnych etykiet ani danych użytkowników w repozytorium lub logach CI. Zewnętrzne wywołania w testach automatycznych zastępować kontrolowanymi fixture lub testowymi serwerami; osobne testy kontraktowe uruchamiać w świadomie przygotowanym środowisku.

## 6. Standard jakości i odbioru

**Definition of Ready:** zadanie ma jednoznaczny rezultat, zakres i powiązanie z RF; zależności są zamknięte; wybrano dane wejściowe i oczekiwany wynik; wiadomo, jak sprawdzić scenariusz poprawny i błędny.

**Definition of Done:** kod i migracje są przeglądnięte; testy jednostkowe i wymagane integracyjne są w CI; wszystkie kryteria akceptacji mają dowód; komunikaty o błędach i brakach danych są zrozumiałe; dokumentacja/kontrakt są aktualne; sekrety i dane osobowe nie trafiają do repozytorium; zmiana działa w środowisku wskazanym w instrukcji.

Szczególne reguły domenowe:

- `brak danych` nie jest równy zeru. Niepełna suma pozostaje oznaczona jako niepełna.
- Wartości kcal i makroskładników wynikają z jawnych ilości i źródeł, a nie z odpowiedzi modelu językowego.
- Niepewna informacja o składzie lub alergenach nie daje statusu „bezpieczne”.
- Plan oznacza zamiar, dziennik potwierdzone spożycie. Ich sum nie miesza się.
- OCR i zamiany zaproponowane przez agenta wymagają zatwierdzenia użytkownika.
- Niedostępność strony, API żywieniowego albo modelu skutkuje błędem lub ograniczonym wynikiem z wyjaśnieniem, nigdy danymi wymyślonymi.

## 7. Ryzyka i kontrola zakresu

| Ryzyko | Wczesny sygnał | Reakcja |
| --- | --- | --- |
| Strony z przepisami nie pozwalają na automatyczny odczyt lub zmieniają strukturę | Błędy ekstrakcji na próbkach, ograniczenia warunków użycia | Zmienić źródło w G2, ograniczyć obsługiwany zbiór stron, utrzymywać fixture i pokazywać brak wyniku. |
| API żywieniowe ma słabe dopasowanie polskich produktów | Wysoki odsetek ręcznych korekt | Zmienić dostawcę w G3 lub wymagać zatwierdzenia dopasowania; nie wypełniać luk zgadywaniem. |
| Model językowy zwraca niepełne lub niezgodne struktury | Błędy walidacji odpowiedzi | Walidować strukturę, nie używać modelu do rachunków, zachować ślad źródłowy. |
| Zakres MVP jest zbyt duży na dostępny czas | Nieprzechodzące bramki lub rosnące zależności | Najpierw ukończyć przekrój: konto → przepis → szacunek → plan → dziennik; zakres rozwoju pozostawić po odbiorze MVP. Nie oznaczać RF-M01–M21 jako spełnionych bez implementacji. |
| Prywatność i synchronizacja kont | Dane poprzedniego konta widoczne po wylogowaniu | Test izolacji, czyszczenia cache i odmowy dostępu w każdej iteracji. |

Zmiana decyzji projektowej wymaga aktualizacji ADR, kontraktu, dotkniętych zadań i testów. Każde RF ma być powiązane z zadaniem oraz scenariuszem testowym; mapę utrzymuje dokument śladowania.

## 8. Warunki wydania MVP

MVP jest gotowe do demonstracji, gdy RF-M01–RF-M21 mają działającą implementację i dowód odbioru, CI jest zielone na aktualnym kodzie, baza przechodzi migracje od zera, da się uruchomić aplikację według instrukcji, a checklisty testów jednostkowych, integracyjnych i odbioru są podpisane wynikiem. Ograniczenia danych źródłowych i znane błędy są opisane. Funkcje rozwojowe nie są warunkiem wydania MVP.
