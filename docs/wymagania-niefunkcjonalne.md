# Wymagania niefunkcjonalne i kryteria jakości

**Status:** projekt kryteriów odbioru. Wartości liczbowe oznaczone jako „do ustalenia” muszą zostać zatwierdzone po pomiarze bazowym na wskazanym urządzeniu i środowisku; nie są deklaracją obecnego działania. Dokument uzupełnia [wymagania funkcjonalne](wymagania_funkcjonalne_i_przypadki_uzycia.md).

| ID | Obszar | Wymaganie | Dowód odbioru |
| --- | --- | --- | --- |
| NFR-01 | Bezpieczeństwo konta | Każde żądanie danych użytkownika jest uwierzytelniane; autoryzacja sprawdza właściciela zasobu po stronie serwera. | Testy kont A/B, żądania bez tokenu, po wygaśnięciu i po wylogowaniu. |
| NFR-02 | Sekrety | Klucze API, hasła baz i dane dostawcy modelu nie trafiają do repozytorium, logów ani aplikacji mobilnej. | Przegląd konfiguracji, logów i PR; przykład konfiguracji zawiera wyłącznie nazwy pól. |
| NFR-03 | Dane lokalne | Token jest w bezpiecznym magazynie platformy; lokalna baza i trwała kolejka są odizolowane per konto. Wylogowanie usuwa je po rozstrzygnięciu niewysłanych zmian: synchronizuj, wróć lub usuń. | Konto A → zmiany offline → restart → wybór przy wylogowaniu → konto B; brak dostępu B do danych i kolejki A. |
| NFR-04 | Integralność | Plan i dziennik są odrębnymi zbiorami; nieudana operacja nie pozostawia częściowego zapisu. | Testy transakcji oraz sum po edycji/usunięciu. |
| NFR-05 | Pochodzenie danych | Przepis, dopasowanie produktu i szacunek zachowują źródło, datę odczytu oraz wersję lub migawkę użytych danych. | Przegląd API/rekordu i ekranu szczegółów. |
| NFR-06 | Wiarygodność obliczeń | Brak wartości i zero mają różne znaczenie; szacunek niepełny jest oznaczony i nie jest prezentowany jako pełna suma. | Testy tabelaryczne dla jednostek, porcji i braków. |
| NFR-07 | Odporność | Timeout, limit i niedostępność mają odrębne stany; częściowe wyniki pozostają oznaczone. Przejściowe błędy mają do 3 prób, odstępy 2 i 5 s, a zapisy stałe ID operacji. Limit zadania LLM wynosi 5 minut. Błąd sieci nie wylogowuje i nie usuwa kolejki. | Atrapy 404/429/5xx, timeout, utrata odpowiedzi po zapisie, restart kolejki i wznowienie tego samego zadania; brak podwójnego skutku i fikcyjnych danych. |
| NFR-08 | Dostępność | Podstawowe działania mają etykiety dostępności, czytelny fokus, komunikaty błędu przypisane do pola i działają przy powiększeniu tekstu. | Ręczny przegląd na docelowej platformie oraz testy widgetów. |
| NFR-09 | Prywatność | Rejestrujemy tylko dane potrzebne do działania MVP; logi i telemetria nie zawierają treści dziennika, profilu ani zdjęć etykiet. Retencja i usunięcie danych wymagają osobnej decyzji. | Przegląd modelu, logów, uprawnień i decyzji projektowych. |
| NFR-10 | Zasoby | Wyszukiwanie i dane żywieniowe korzystają z limitów, cache i deduplikacji. Aplikacja nie wykonuje ciągłych zapytań w tle bez potrzeby użytkownika. | Zapis pomiaru liczby żądań, czasu, pamięci i transferu dla scenariusza referencyjnego. |
| NFR-11 | Odtwarzalność | Nowa osoba uruchomi aplikację, serwer i testy na czystym środowisku według instrukcji, bez dostępu do prywatnych sekretów produkcyjnych. | Wykonanie instrukcji od zera w środowisku testowym. |
| NFR-12 | Jakość zmian | CI uruchamia formatowanie, analizę statyczną i automatyczne testy; PR ma powiązanie z wymaganiem i dowód. | Zielony przebieg CI oraz checklisty zadania i PR. |

## Scenariusz referencyjny do pomiaru zasobów

Na jednym zapisanym urządzeniu i łączu testowym: uruchomienie aplikacji po zalogowaniu, synchronizacja profilu/planów/dziennika, jedno wyszukiwanie z 10 kandydatami, otwarcie 3 szczegółów, dodanie posiłku do planu i dziennika. Zapisz model urządzenia, wersję systemu, typ sieci, rozmiar danych, liczbę żądań, czas odpowiedzi, transfer oraz szczytową pamięć. Cel liczbowy ustal w ADR po pierwszym pomiarze; potem porównuj każdą zmianę z tym samym scenariuszem. Nie zastępuj pomiaru ogólnym stwierdzeniem „minimalne zużycie zasobów”.

## Bramka jakości MVP

Wydanie przechodzi, gdy nie ma otwartych błędów blokujących przepływy `PU-M01`–`PU-M08`, scenariusze izolacji kont i błędów źródeł są sprawdzone, a wszystkie pozycje [checklisty odbioru](checklisty.md) mają dowód lub jawnie zaakceptowane ograniczenie. Cele liczbowe wydajności i retencję danych trzeba zamknąć w [rejestrze decyzji](decyzje-projektowe.md) przed tą bramką.
