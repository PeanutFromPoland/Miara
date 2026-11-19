# Ustalenia API aplikacji i stanów klienta

> Rozmowa decyzyjna zakończona 13 listopada 2026 r. Właściciel decyzji: właściciel projektu. Poniżej zapisano odpowiedzi dotyczące wszystkich siedmiu obszarów oraz doprecyzowań wyszukiwania i offline. Powiązane dokumenty: [kontrakt API](kontrakt-api.md), [model danych](model-danych.md), [rejestr decyzji](decyzje-projektowe.md). Przyjęcie decyzji nie oznacza implementacji ani zaliczenia testów.

## Zakres

API oznacza własny serwer aplikacji (Python/FastAPI), z którym komunikuje się Flutter na Androidzie. Serwer zwraca m.in. przepisy pozyskane przez narzędzie LLM. Wybór zewnętrznego dostawcy danych żywieniowych jest osobnym zagadnieniem.

## 1. Format danych — przyjęte

- Serwer zwraca jeden ustalony format JSON niezależny od struktury odpowiedzi narzędzia LLM.
- Serwer przekształca i waliduje wynik narzędzia przed udostępnieniem go aplikacji.
- Zakres przepisu obejmuje składniki, ilości, instrukcje, czas, porcje lub masę dania, wartości odżywcze i link do źródła, o ile dane są dostępne i dopuszczone do użycia zgodnie z decyzjami dotyczącymi źródła.
- Brakujące informacje mają wartość `null` i jawne oznaczenie braków. Brak nie jest zerem; nie odrzucamy przepisu wyłącznie dlatego, że ma niepełne informacje.
- Nazwy pól, typy i przykłady opisuje kontrakt API. Maszynowa specyfikacja OpenAPI i testy zgodności są produktami zadania T-05, nie kolejną decyzją o formacie danych.

## 2. Przebieg wyszukiwania — przyjęte

- Serwer tworzy zadanie wyszukiwania i od razu zwraca jego identyfikator.
- Aplikacja sprawdza stan krótkimi zapytaniami do serwera.
- Po chwilowej utracie połączenia aplikacja odczytuje stan tego samego zadania, zamiast ponownie uruchamiać LLM.
- Opuszczenie ekranu lub utrata sieci nie anuluje zadania na serwerze.
- Przycisk „Anuluj” wysyła wyraźne żądanie przerwania; aplikacja potwierdza anulowanie dopiero po odpowiedzi serwera. Brak sieci nie jest potwierdzeniem anulowania.
- Maksymalny czas jednego zadania na serwerze wynosi 5 minut. Jest to konfigurowalny parametr startowy, wymagający późniejszego pomiaru.
- Aplikacja odpytuje co 2 sekundy przez pierwsze 20 sekund, następnie co 5 sekund. Odpytywanie ustaje, gdy aplikacja przechodzi w tło; samo zadanie nadal działa.
- Po przekroczeniu limitu czasu serwer kończy zadanie wynikiem częściowym albo błędem, zależnie od dostępnych wyników.
- Serwer przechowuje status zakończonego zadania i odnośniki do wyników przez 30 dni. Usunięcie zadania nie usuwa przepisów potrzebnych do planu lub dziennika ani migawek zapisanych wpisów.

## 3. Znaczenie wyników i błędów — przyjęte

- Prawidłowo zakończone wyszukiwanie bez trafień oznacza brak wyników, nie błąd.
- Gdy część wyszukiwania zawiedzie, ale dostępne są wyniki, aplikacja pokazuje je wraz z ostrzeżeniem o ograniczeniach.
- Gdy awaria uniemożliwia uzyskanie wyników, aplikacja pokazuje błąd z możliwością ponowienia.
- Błąd części integracji nie przerywa automatycznie całego wyszukiwania. Nie tworzymy danych zastępczych.

## 4. Sesja użytkownika — przyjęte

- Odpowiedź właściciela: „Bez wylogowywania”. Interpretacja przedstawiona w rozmowie: brak automatycznego wylogowania wyłącznie z powodu upływu czasu.
- Odrzucono proponowany stały limit 30 dni od logowania. Sesja odnawia się bez takiego limitu.
- Krótki czas ważności tokenu dostępu nie oznacza zakończenia sesji; klient odnawia dostęp automatycznie. Szczegóły techniczne zostaną opisane w kontrakcie.
- Brak sieci nie wylogowuje użytkownika. Ręczne wylogowanie pozostaje dostępne; odwołana przez serwer sesja wymaga ponownego logowania.
- Nie oznacza to usunięcia funkcji wylogowania ani obowiązku akceptowania przez serwer odwołanych poświadczeń.

## 5. Cache i zakres offline — przyjęte

- Wybrano odczyt i zmiany offline, synchronizowane po odzyskaniu połączenia.
- Odrzucono wariant ograniczający offline do samego odczytu.
- Wymagana jest trwała lokalna kolejka operacji i obsługa konfliktów. Lokalny zapis nie oznacza potwierdzenia operacji przez serwer.
- Na telefonie przechowujemy profil, wszystkie pobrane wpisy planu i dziennika, ostatnie wyniki wyszukiwania i otwarte szczegóły przepisów.
- Pobrane dane profilu, planu i dziennika pozostają dostępne do wylogowania. Podręczne wyniki i przepisy można usuwać po 30 dniach, jeżeli nie są potrzebne do wpisów planu lub dziennika ani niewysłanych operacji. Jest to zakres lokalnej pamięci podręcznej; nie rozstrzyga retencji danych na serwerze ani uprawnień do treści źródłowych.
- Nowe wyszukiwanie przez LLM wymaga połączenia; offline można przeglądać wcześniej pobrane wyniki i przepisy.
- Przy ręcznym wylogowaniu z niewysłanymi zmianami aplikacja pokazuje ich liczbę i oferuje: synchronizację teraz, powrót do aplikacji albo wylogowanie z jawnym usunięciem zmian. Bez wyboru użytkownika niewysłane zmiany nie są kasowane. Gdy synchronizacja jest niemożliwa lub nieudana, nie traktujemy jej jako zakończonej i nie usuwamy zmian.

## 6. Ponowienia i konflikty zapisów — przyjęte

- Przy konflikcie tego samego profilu lub wpisu użytkownik wybiera wersję.
- Aplikacja zachowuje niewysłane zmiany i pobiera aktualną wersję z serwera; nie nadpisuje jej automatycznie.
- Konflikt blokuje synchronizację danego zasobu i operacji od niego zależnych, a pozostałe niezależne wpisy synchronizują się dalej.
- Przejściowe błędy odczytów i zabezpieczonych zapisów uruchamiają maksymalnie 3 próby łącznie, z odstępami 2 i 5 sekund.
- Po wyczerpaniu prób aplikacja pokazuje komunikat i przycisk „Ponów”. Niewysłane zmiany pozostają w kolejce; po odzyskaniu połączenia synchronizacja rusza ponownie.
- Stały identyfikator operacji zapobiega podwójnemu zapisowi przy ponowieniu, także gdy poprzednia odpowiedź zaginęła.
- Nie ponawiamy automatycznie błędnych danych ani konfliktów wersji.

## 7. Stany ładowania i zachowanie ekranów — przyjęte

- Pierwsze pobranie bez danych pokazuje stan ładowania.
- Odświeżanie zachowuje widoczne dane; błąd nie usuwa formularza ani niewysłanych zmian.
- Offline aplikacja pokazuje dane podręczne z datą synchronizacji, a brak cache oznacza komunikat „Brak danych na urządzeniu”.
- Lokalny zapis od razu aktualizuje widok i ma oznaczenie „Oczekuje na synchronizację”. Potwierdzony zapis serwerowy ma osobny stan.
- Wyszukiwanie pokazuje rzeczywisty stan zadania bez zmyślonego procentu postępu.

## Dalsza praca

Decyzje odblokowały projektowanie modeli klienta i kontraktu. 16 listopada przygotowano model v0.1, a następnie na polecenie właściciela [OpenAPI v0.1.0](api/openapi.json) i [opis kontraktu](kontrakt-api.md). Nadal trzeba zbudować serwer, lokalną bazę i kolejkę oraz sprawdzić zgodność implementacji testami. Walidacja pliku OpenAPI nie jest takim dowodem. Osobnymi otwartymi zagadnieniami są m.in. dostawca danych żywieniowych, szczegółowe reguły obliczeń, OCR oraz warunki produkcyjnego użycia źródeł. Nie zostały rozstrzygnięte w rozmowie z 13 listopada.
