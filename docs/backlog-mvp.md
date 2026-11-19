# Backlog MVP Miary

Backlog wykonuje [plan wytwarzania](plan-wytwarzania.md) i pokrywa RF-M01–RF-M21 z [wymagań funkcjonalnych](wymagania_funkcjonalne_i_przypadki_uzycia.md) oraz wymogi zaliczeniowe z [wymagań projektu](wymagania.md). ID zadań są stabilne; można je skopiować do GitHub Issues przy użyciu [szablonów](szablony-zadan.md). Zależności oznaczają zadania wymagane do odbioru, nie zawsze do równoległego rozpoczęcia pracy nad interfejsem.

Priorytet wszystkich pozycji to P0 lub P1. Status początkowy: **do zrobienia**. `app/` jest szablonem Flutter z licznikiem, a `docs/prototyp-ui/` stanowi inspirację interfejsu i demonstrację, nie działającą implementację MVP. T-01 wybrał backend Python/FastAPI, PostgreSQL i wdrożenie on-premise oraz Androida jako jedyną platformę MVP; pozostałe nierozstrzygnięte decyzje wskazują właściwe zadania.

## Iteracja 0 — decyzje, kontrakt i repozytorium

### T-01 — Wybrać stos serwera, bazy i środowiska (P0)

- **Powiązanie:** G1; własny serwer i baza wymagane przez RF-M19, warunki zaliczenia.
- **Zależności:** brak.
- **Treść i produkt:** wybory właściciela projektu: Python/FastAPI, PostgreSQL, wdrożenie on-premise i aplikacja Flutter na Androida. Uzupełnić ADR o wersje i sposób uruchamiania, migracje, backup/odtworzenie, konfigurację bez sekretów oraz szkic katalogów.
- **Kryteria akceptacji:** wybory i ich konsekwencje zapisane w ADR; zdefiniowane minimalne środowisko czystego startu on-premise; Android wskazany jako platforma MVP; wersje szczegółowe lub jawne ograniczenia otwarte przypisane do zadań.
- **Test/dowód:** prototyp techniczny minimalnego endpointu FastAPI z PostgreSQL, migracją i testem albo udokumentowany plan jego wykonania; przegląd kontraktu klient–serwer.

### T-02 — Wybrać dopuszczalne źródła przepisów (P0)

- **Powiązanie:** G2, RF-M05, RF-M09, RF-M15.
- **Zależności:** brak.
- **Treść i produkt:** wybór AniaGotuje.pl jako podstawowego źródła przepisów zapisano w ADR-012 (2026-11-13). W pierwszej kolejności zweryfikować `aniagotuje.pl`; domeny `centrumrespo.pl`, `przepisy.pl`, `kwestiasmaku.com`, `zdrowe-odzywianie-przepisy.blogspot.com` z ADR-011 pozostają kandydatami uzupełniającymi. Przetestować parsowanie HTML, w tym metadanych i referencji do zdjęć; sprawdzić warunki, `robots.txt`, limity oraz prawa do retencji tekstu i pobierania mediów; uzupełnić ADR o wyniki próby.
- **Kryteria akceptacji:** udokumentowano strukturę reprezentatywnych stron i werdykt techniczny/prawny per domena. Bez licencji/zgody produkcyjnie przechowywane są tylko link i minimalne metadane; pełne teksty i pliki zdjęć nie są pobierane ani utrwalane. Niepotwierdzona domena jest wyłączona z produkcyjnego scrapingu.
- **Test/dowód:** fixture ekstrakcji HTML dla stron pełnych/niepełnych; zapis kontroli warunków i `robots.txt`, podstawy retencji, limitów, linków oraz daty przeglądu w ADR.

### T-03 — Wybrać bazę żywieniową i reguły przeliczeń (P0)

- **Powiązanie:** G3, RF-M07, RF-M10–RF-M12.
- **Zależności:** brak.
- **Treść i produkt:** ocenić kandydatów API pod kątem licencji, limitów, jednostek, pokrycia typowych polskich składników i danych o kcal/makro; ustalić tabelę pewnych przeliczników, zasady masy surowej/gotowej i brakujących ilości; zapisać ADR i próbki.
- **Kryteria akceptacji:** wybrany dostawca daje identyfikowalny produkt, jednostkę odniesienia i źródło; reguły nie zamieniają nieznanej ilości w zero; niejednoznaczne dopasowanie ma przewidziany stan korekty.
- **Test/dowód:** próba na co najmniej pięciu składnikach, w tym miara objętościowa i brak dopasowania; udokumentowany wynik i ograniczenia.

### T-04 — Ustalić ochronę danych i reguły synchronizacji (P0)

- **Powiązanie:** G4, RF-M01–RF-M03, RF-M19–RF-M20.
- **Zależności:** T-01.
- **Treść i produkt:** zrealizować przyjęte [ustalenia API i stanów klienta](ustalenia-api-i-stany.md): trwała sesja bez automatycznego wylogowania, CRUD profilu/planu/dziennika offline, cache i trwała kolejka, wybór przy konflikcie i wylogowaniu z niewysłanymi zmianami. Doprecyzować pozostałe kwestie konta i pełnej retencji danych serwera (ADR-106/111).
- **Kryteria akceptacji:** każda kategoria danych ma właściciela i zasady usunięcia; konflikt nie nadpisuje automatycznie lokalnej lub serwerowej wersji; niewysłane zmiany nie giną po restarcie, błędzie ani odmowie odnowienia sesji.
- **Test/dowód:** przegląd scenariuszy „dwa konta na urządzeniu”, „utrata sieci” i „zmiana danych na drugim urządzeniu”.

### T-05 — Opracować model danych, następnie kontrakt API (P0)

- **Powiązanie:** RF-M01–RF-M04, RF-M10–RF-M12, RF-M16–RF-M20.
- **Zależności:** przyjęte zasady T-01 i T-04; T-03 doprecyzuje adapter i rachunek, ale nie blokuje wstępnego modelu niezależnego od dostawcy.
- **Kolejność (ADR-014, 2026-11-16):** model logiczny → przegląd encji, relacji i reguł → mapowanie na schemat bazy i klasy domenowe → widoki/polecenia API → OpenAPI. Schemat bazy nie musi mieć gotowej migracji przed rozpoczęciem opisu API.
- **Etap modelu:** [model v0.1](model-danych.md) obejmuje typy i braki danych, encje konta/profilu, przepisy i warianty, historię dopasowań, migawki i wkłady szacunku, oddzielny plan/dziennik, wyszukiwanie oraz trwałą kolejkę offline. Produkt wstępny opracowano 16 listopada; wymaga przeglądu, a nie deklaracji gotowej bazy.
- **Etap kontraktu:** po przeglądzie modelu uzgodnić [dotychczasowy szkic API](kontrakt-api.md) z modelem i przygotować OpenAPI z dokładnymi schematami, walidacją, błędami, paginacją i przykładami. Przyjęte zasady ADR-112 pozostają podstawą; publiczne DTO nie są kopiami wszystkich encji bazy.
- **Stan etapu kontraktu (2026-11-16):** na polecenie właściciela opracowano [OpenAPI v0.1.0](api/openapi.json), opis reguł i testy pliku kontraktu (ADR-015). Obejmują sesję, przepisy, plan/dziennik, potwierdzenia operacji oraz odczyt zmian/usunięć konta. Migracja startowa i sprawdzenie na rzeczywistym serwerze pozostają do wykonania; całe T-05 nie jest zamknięte.
- **Kryteria akceptacji:** każda encja ma tożsamość, właściciela i reguły relacji; plan i dziennik mają osobne migawki; zmiana dopasowania nie nadpisuje historii szacunku; synchronizacja zachowuje ID, wersje i potwierdzenia operacji. Dopiero na tej podstawie kontrakt określa formaty, w tym rozróżnienie `null` i `0`.
- **Test/dowód:** najpierw przegląd modelu na przepływach przepis → szacunek → plan → dziennik i zmiany offline → konflikt/ponowienie; później migracja startowa, przykłady żądań/odpowiedzi i test zgodności klient–serwer. Scenariusz opisany w modelu nie jest jeszcze zaliczonym testem implementacji.

### T-06 — Uporządkować GitHub i uruchomić CI (P0)

- **Powiązanie:** wymagania zaliczeniowe GitHub, CI/CD i testy jednostkowe.
- **Zależności:** T-01 dla poleceń serwera; część Flutter można zacząć wcześniej.
- **Treść i produkt:** objąć kod i dokumenty kontrolą wersji, ustalić `.gitignore`, instrukcję startu i przykładową konfigurację bez sekretów; dodać workflow PR dla formatowania, statycznej analizy, testów Flutter i po wyborze stosu także serwera/integracji. Dodać wyzwalany tagiem lub zatwierdzonym scaleniem etap dostarczenia wersjonowanego artefaktu albo wdrożenia na środowisko testowe oraz opisać sposób cofnięcia.
- **Kryteria akceptacji:** nowy klon może przejść instrukcję uruchomienia; PR z celowo psującym się testem nie przechodzi; sekrety nie są zapisane w repozytorium; wynik CI i ślad dostarczenia artefaktu są widoczne w GitHub.
- **Test/dowód:** link lub zrzut udanego i nieudanego przebiegu CI, próbnego dostarczenia wersjonowanego artefaktu, wynik `git status`, wykonanie instrukcji na czystym środowisku.

## Iteracja 1 — konto i profil

### T-07 — Uruchomić serwer z wyborem OpenAI API albo LM Studio (P0)

- **Powiązanie:** G5, RF-M21.
- **Zależności:** T-01, T-06.
- **Treść i produkt:** zbudować szkielet serwera i wspólny interfejs adaptera modelu; operator podaje wybranego dostawcę i dane połączenia przy starcie, a serwer weryfikuje konfigurację i używa tylko wybranego adaptera.
- **Kryteria akceptacji:** oba warianty mają udokumentowane pola konfiguracji; brak wyboru, klucza lub niedostępny endpoint daje czytelny błąd; nie następuje ciche przełączenie na innego dostawcę; klucze nie pojawiają się w logach.
- **Test/dowód:** test konfiguracji obu wariantów z atrapami połączeń, test błędnego startu i instrukcja lokalna.

### T-08 — Zaimplementować konto, logowanie i sesję (P0)

- **Powiązanie:** RF-M01–RF-M02.
- **Zależności:** T-04, T-05, T-06.
- **Treść i produkt:** rejestracja/logowanie hasłem i przez Google, weryfikacja tokenu na chronionych endpointach, wylogowanie i bezpieczne przechowywanie danych uwierzytelniających po stronie klienta.
- **Kryteria akceptacji:** użytkownik uzyskuje dostęp tylko do własnych danych; błędne hasło, nieważny token i brak tokenu nie ujawniają profilu; wylogowanie usuwa lokalną sesję i dane podręczne konta.
- **Test/dowód:** unit dla walidacji i stanu sesji; integracja rejestracja → logowanie → chronione żądanie → wylogowanie; test Google na środowisku testowym i odmowa żądania dla obcego konta.

### T-09 — Zaimplementować CRUD profilu żywieniowego (P0)

- **Powiązanie:** RF-M03, RF-M19.
- **Zależności:** T-05, T-08.
- **Treść i produkt:** endpointy i warstwa danych dla celu kcal, opcjonalnych makroskładników, liczby posiłków, preferencji, wykluczeń i zadeklarowanych alergenów.
- **Kryteria akceptacji:** utworzenie, odczyt, aktualizacja i usunięcie profilu są trwałe; niepoprawne wartości są odrzucane; dwa konta nie mogą czytać ani zmieniać swoich profili nawzajem.
- **Test/dowód:** unit walidacji; integracyjne cztery operacje CRUD i test izolacji na dwóch kontach.

### T-10 — Zastąpić licznik powłoką Flutter Miary (P1)

- **Powiązanie:** interfejs dla RF-M03–RF-M04, RF-M16–RF-M18; prototyp UI.
- **Zależności:** T-05 dla modeli widoku.
- **Treść i produkt:** nawigacja Dziś/Odkrywaj/Plan/Dziennik/Profil, podstawowe komponenty wizualne według `docs/prototyp-ui/`, stany ładowania, puste i błędów oraz dostępne etykiety elementów.
- **Kryteria akceptacji:** każda karta jest osiągalna; powrót z detalu zachowuje kontekst; układ mieści się na małym ekranie i przy większym tekście; nie pokazuje danych demonstracyjnych jako rzeczywistych.
- **Test/dowód:** testy widgetów nawigacji i stanów; ręczny przegląd na emulatorze/urządzeniu.

### T-11 — Połączyć mobilne konto i profil z API (P0)

- **Powiązanie:** RF-M01–RF-M03, RF-M20.
- **Zależności:** T-08–T-10.
- **Treść i produkt:** ekrany rejestracji/logowania/profilu, walidacja formularza, odczyt i aktualizacja profilu, stan sesji i wylogowanie.
- **Kryteria akceptacji:** profil zapisany przez klienta jest widoczny po ponownym uruchomieniu; błędna sesja prowadzi do logowania; po wylogowaniu dane poprzedniego konta nie są widoczne.
- **Test/dowód:** testy widgetów formularzy; integracja klient–testowe API dla zapisu, błędu walidacji i wylogowania.

## Iteracja 2 — przepisy, dane i szacunki

### T-12 — Dodać adapter zewnętrznej bazy żywieniowej (P0)

- **Powiązanie:** RF-M10, RF-M15; wymóg zewnętrznego API.
- **Zależności:** T-03, T-05, T-06.
- **Treść i produkt:** klient wybranego API, mapowanie odpowiedzi na identyfikator produktu, jednostkę odniesienia, kcal i makro, datę oraz źródło; timeout, limity i cache zgodny z licencją.
- **Kryteria akceptacji:** sukces, brak produktu, wiele kandydatów, limit i niedostępność API mają osobne wyniki; niejednoznaczność nie jest rozstrzygana bez podstawy; źródło jest zachowane.
- **Test/dowód:** unit mapowania fixture; test kontraktowy adaptera z atrapą API; kontrolowana próba rzeczywistego API według G3.

### T-13 — Zbudować normalizację i kalkulator wartości (P0)

- **Powiązanie:** RF-M07, RF-M11–RF-M12.
- **Zależności:** T-03, T-12.
- **Treść i produkt:** deterministyczne przeliczenie ilości składników na jednostki odniesienia, sumowanie kcal/białka/węglowodanów/tłuszczu, wynik całego przepisu i na porcję oraz stopień kompletności.
- **Kryteria akceptacji:** zmiana ilości lub porcji zmienia wynik według jawnej formuły; brak ilości, nieznany przelicznik i brak produktu są wykazane osobno; niepełna suma jest opisana jako niepełna, nigdy jako pełna.
- **Test/dowód:** testy tabelaryczne dla gramów, mililitrów, porcji, zaokrągleń, zera, braku danych i zmiany liczby porcji; porównanie ręcznego rachunku na przykładowym przepisie.

### T-14 — Wyszukiwać dozwolone publiczne przepisy (P0)

- **Powiązanie:** RF-M04–RF-M05, RF-M09, RF-M15.
- **Zależności:** T-02, T-05.
- **Treść i produkt:** adapter wyszukiwania wybranych źródeł, kryteria nazwy/czasu/liczby składników/kcal/makro tam, gdzie dane pozwalają, deduplikacja po kanonicznym URL i tytule, link i data odczytu.
- **Kryteria akceptacji:** nieobsługiwane lub niedozwolone źródło jest pomijane; brak wyników i awaria źródła mają różne komunikaty; niewypełnione kryterium nie zawęża wyników; nie trzeba płatnego API przepisów.
- **Test/dowód:** test filtrów i deduplikacji na fixture; integracja z atrapą źródła dla timeoutu i pustego wyniku.

### T-15 — Ekstrahować i walidować przepis źródłowy (P0)

- **Powiązanie:** RF-M06–RF-M07, RF-M09.
- **Zależności:** T-14.
- **Treść i produkt:** wydobycie liczby porcji, składników, ilości, jednostek i czasu; przechowanie URL, daty odczytu i pól niejednoznacznych; rozdzielenie oryginału od późniejszych zmian agenta.
- **Kryteria akceptacji:** brakujące pola pozostają nieznane; nieznana liczba porcji blokuje wiarygodny wynik na porcję; aplikacja nie kopiuje pełnej treści źródła bez podstawy.
- **Test/dowód:** fixture przepisów pełnych, niepełnych i zmienionej struktury strony; test walidacji struktury i zachowania źródła.

### T-16 — Filtrować, porządkować i proponować zmiany (P0)

- **Powiązanie:** RF-M08, RF-M13–RF-M14.
- **Zależności:** T-07, T-09, T-13, T-15.
- **Treść i produkt:** reguły wykluczania rozpoznanych alergenów/produktów, status niepewności przy niepełnym składzie, ranking według profilu i kryteriów z wyjaśnieniem; agent może zaproponować zamianę lub zmianę ilości w osobnej wersji przepisu.
- **Kryteria akceptacji:** wykluczony składnik nie dostaje statusu zgodności; niepewny skład nie jest opisany jako bezpieczny; propozycja wskazuje dokładną zmianę i ponownie liczy wartości; zapis do planu wymaga zatwierdzenia wersji.
- **Test/dowód:** jednostkowe przypadki alergenów, brakującego składu, punktacji i zamiany; integracja adaptera modelu z walidacją struktury odpowiedzi i odmową wymyślonych ilości.

### T-17 — Udostępnić przepływ wyszukiwania w API (P0)

- **Powiązanie:** RF-M04–RF-M15, RF-M21.
- **Zależności:** T-12–T-16.
- **Treść i produkt:** endpoint przyjmujący kryteria, uruchamiający wyszukiwanie, ekstrakcję, dopasowanie, kalkulację i ranking; zwraca źródła, kompletność, powody kolejności oraz jawne błędy zależności.
- **Kryteria akceptacji:** klient dostaje spójny wynik także dla częściowych danych; nie otrzymuje fikcyjnego przepisu ani wartości po awarii; logi nie zawierają sekretów lub zbędnych danych profilu.
- **Test/dowód:** integracja całego przepływu na fixture i atrapach usług dla sukcesu, pustego wyniku, timeoutu strony, braku produktu i błędu modelu.

### T-18 — Zbudować ekrany Odkrywaj i szczegóły przepisu (P0)

- **Powiązanie:** RF-M04, RF-M09, RF-M12–RF-M15.
- **Zależności:** T-10, T-17.
- **Treść i produkt:** formularz kryteriów, lista propozycji i detal ze składnikami, czasem, kcal/makro na porcję, linkiem źródłowym, datą, zmianami agenta, brakami danych i powodami rankingu.
- **Kryteria akceptacji:** użytkownik widzi, które wartości są szacowane i niepełne; może poprawić wymagające potwierdzenia dane; stany pusty/błąd/ładowanie są czytelne; przepis niepewny nie dostaje etykiety bezpieczny.
- **Test/dowód:** testy widgetów wszystkich stanów i akcji; ręczny przegląd przepływu na urządzeniu.

## Iteracja 3 — plan i dziennik

### T-19 — Zaimplementować trwały plan dzienny (P0)

- **Powiązanie:** RF-M16, RF-M19.
- **Zależności:** T-05, T-08, T-13, T-17.
- **Treść i produkt:** CRUD pozycji planu z dniem, przepisem/wersją, liczbą porcji i migawką szacunku, sumami planowanymi oraz odniesieniem do celów profilu.
- **Kryteria akceptacji:** dodanie, odczyt, zmiana i usunięcie są trwałe; suma przelicza się po każdej operacji; brak wartości zachowuje status niepełnej sumy; nie ma dostępu do planu cudzego konta.
- **Test/dowód:** unit sumowania; integracyjne CRUD z bazą, test dwóch kont i brakujących wartości.

### T-20 — Zaimplementować niezależny dziennik spożycia (P0)

- **Powiązanie:** RF-M17, RF-M19.
- **Zależności:** T-05, T-08, T-19.
- **Treść i produkt:** CRUD wpisów rzeczywiście spożytych posiłków, wpis z planu oraz ręczny, ilość faktyczna, wartości i źródło danych; suma dziennika niezależna od planu.
- **Kryteria akceptacji:** samo dodanie planu nie zwiększa spożycia; edycja/usunięcie wpisu zmienia tylko sumę dziennika; wpis ręczny jest trwały; dane innych kont są niedostępne.
- **Test/dowód:** unit sumy planu i dziennika; integracyjne CRUD obu typów wpisu oraz izolacja kont.

### T-21 — Połączyć ekrany Dziś, Plan i Dziennik z API (P0)

- **Powiązanie:** RF-M16–RF-M17.
- **Zależności:** T-11, T-18–T-20.
- **Treść i produkt:** widoki planu i dziennika, dodawanie przepisu/porcji, korekta/usuwanie, potwierdzenie posiłku z planu, osobne sumy na ekranie Dziś.
- **Kryteria akceptacji:** użytkownik może przejść od propozycji do planu i zapisu spożycia; po odświeżeniu widzi zapisane dane; planowane i zjedzone wartości są wyraźnie rozdzielone.
- **Test/dowód:** testy widgetów stanów i sum; integracja klient–API dla pełnego przepływu oraz ręczny pokaz na urządzeniu.

## Iteracja 4 — aparat i dane lokalne

### T-22 — Odczytywać etykietę aparatem i potwierdzać wpis (P0)

- **Powiązanie:** RF-M18, RF-M17; wymóg użycia sensora.
- **Zależności:** T-20–T-21.
- **Treść i produkt:** uzyskanie zdjęcia tabeli wartości odżywczych z aparatu telefonu, OCR, formularz wartości na określoną jednostkę i faktycznej ilości, ręczna alternatywa przy błędzie lub odmowie uprawnienia.
- **Kryteria akceptacji:** OCR nigdy nie zapisuje wpisu automatycznie; użytkownik widzi i może poprawić wszystkie odczytane wartości, jednostkę odniesienia i ilość; brak odczytu pozostaje pusty, nie zerowy; zapis trafia do dziennika dopiero po potwierdzeniu.
- **Test/dowód:** unit parsera wartości i przeliczenia ilości; integracja z atrapą OCR; ręczny test aparatu na urządzeniu dla czytelnej i nieczytelnej etykiety oraz odmowy uprawnienia.

### T-23 — Dodać lokalną bazę, zapisy offline i synchronizację (P0)

- **Powiązanie:** RF-M20, RF-M02.
- **Zależności:** T-04, T-11, T-21.
- **Treść i produkt:** trwała lokalna baza i kolejka CRUD profilu, planu i dziennika; cache ostatnich wyników i otwartych przepisów; lokalne identyfikatory, zależności operacji, kontrola wersji i deduplikacja. Zmiana i kolejka powstają atomowo. Po starcie i powrocie sieci wznowić synchronizację; wdrożyć wybór wersji przy konflikcie i wybór losu niewysłanych zmian przy wylogowaniu.
- **Kryteria akceptacji:** offline można tworzyć, edytować i usuwać dostępne dane z oznaczeniem oczekiwania; restart nie gubi zmian; utrata odpowiedzi nie dubluje wpisów; konflikt nie blokuje niezależnych zasobów; odświeżenie nie nadpisuje lokalnych operacji. Brak cache ma osobny komunikat; konto B nie widzi danych ani kolejki A. Retencja cache jest zgodna z ADR-108.
- **Test/dowód:** unit kolejki, cache i łączenia lokalnego stanu; integracja online → zmiany offline → restart → online, utrata odpowiedzi po zapisie, dwa urządzenia, odnowienie i odwołanie sesji oraz wszystkie wybory przy wylogowaniu z kolejką.

## Iteracja 5 — weryfikacja i wydanie

### T-24 — Zamknąć plan testów i śladowanie wymagań (P0)

- **Powiązanie:** RF-M01–RF-M21; wymóg testów jednostkowych.
- **Zależności:** T-07–T-23.
- **Treść i produkt:** zebrać mapę RF → zadanie → przypadek testowy → wynik; uzupełnić luki testów jednostkowych i integracyjnych, scenariusze awarii dostawców, izolacji danych i regresji; uruchomić je w CI.
- **Kryteria akceptacji:** każde RF-M01–RF-M21 ma przynajmniej jeden dowód weryfikacji; krytyczne reguły rachunkowe, alergeny, autoryzacja i rozdzielenie planu/dziennika mają automatyczne testy; porażki są przypisane do defektów.
- **Test/dowód:** raport CI, lista testów, wypełnione checklisty i macierz śladowania; nie uznawać samej obecności testu za dowód jego przejścia.

### T-25 — Zmierzyć zasoby i przygotować diagnostykę (P1)

- **Powiązanie:** wymaganie minimalnego zużycia zasobów, RF-M15, RF-M20.
- **Zależności:** T-17, T-21–T-23.
- **Treść i produkt:** ustalić mierzalny budżet czasu/transferu/liczby wywołań dla wyszukiwania i synchronizacji, profilować aplikację oraz serwer, wdrożyć limity, timeouty, cache zgodny z licencją i zwięzłe logi błędów bez danych prywatnych.
- **Kryteria akceptacji:** pomiary bazowe i po optymalizacji są zapisane na tym samym scenariuszu; zbędne ponowne zapytania są wyeliminowane; niedostępność usługi nie blokuje aplikacji bez końca; odchylenia od budżetu są opisane.
- **Test/dowód:** powtarzalny scenariusz profilowania, raport zużycia i test timeoutu/ponowienia.

### T-26 — Przygotować wydanie i demonstrację MVP (P0)

- **Powiązanie:** RF-M01–RF-M21, wszystkie wymagania zaliczeniowe.
- **Zależności:** T-06–T-25.
- **Treść i produkt:** instrukcja instalacji klienta i serwera, konfiguracja dostawców bez sekretów, migracja od pustej bazy, lista ograniczeń, scenariusz demonstracji konta → profilu → przepisu → szacunku → planu → dziennika → OCR → offline.
- **Kryteria akceptacji:** osoba bez wcześniejszej konfiguracji projektu może uruchomić system według instrukcji; demo pokazuje pełny CRUD, zewnętrzne API, aparat, oba warianty konfiguracji AI, GitHub i zielone CI; każdy niespełniony punkt jest jawnie zapisany jako luka, nie jako wykonany.
- **Test/dowód:** próba instalacji od zera, zapis przebiegu demo, aktualna macierz RF i podpisane checklisty odbioru.

## Pokrycie wymagań i następny zakres

| Wymaganie | Zadania główne |
| --- | --- |
| RF-M01–RF-M02 | T-08, T-11, T-23 |
| RF-M03 | T-09, T-11 |
| RF-M04 | T-14, T-17, T-18 |
| RF-M05 | T-02, T-14, T-17 |
| RF-M06 | T-15 |
| RF-M07 | T-03, T-13, T-15 |
| RF-M08 | T-16 |
| RF-M09 | T-02, T-14–T-15, T-18 |
| RF-M10 | T-03, T-12 |
| RF-M11–RF-M12 | T-03, T-13, T-18 |
| RF-M13–RF-M14 | T-16, T-18 |
| RF-M15 | T-12, T-14, T-17–T-18 |
| RF-M16 | T-19, T-21 |
| RF-M17 | T-20–T-22 |
| RF-M18 | T-22 |
| RF-M19 | T-05, T-09, T-19–T-20 |
| RF-M20 | T-04, T-11, T-23 |
| RF-M21 | T-07, T-17 |
| GitHub, CI/CD, unit, zasoby | T-06, T-24–T-26 |

Po odbiorze MVP utworzyć osobne zadania dla RF-R01 (plan wielodniowy), RF-R02 (lista zakupów), RF-R03 (koszty), RF-R04 (dodatkowe składniki odżywcze) i RF-R05 (uczenie preferencji). Nie są zależnościami dla T-26.
