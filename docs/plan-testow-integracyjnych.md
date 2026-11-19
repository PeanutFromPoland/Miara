# Plan testów integracyjnych

## 1. Cel i granice

Plan sprawdza współpracę aplikacji Flutter, własnego serwera i bazy, adapterów źródeł przepisów, zewnętrznej bazy żywieniowej, wybranego modelu AI oraz aparatu/OCR. Punktem odniesienia są [wymagania i przypadki użycia](wymagania_funkcjonalne_i_przypadki_uzycia.md). Integracja oznacza sprawdzenie rzeczywistych granic między modułami; test pojedynczej funkcji należy do [planu testów jednostkowych](plan-testow-jednostkowych.md).

**Stan obecny (2026-11-06):** w repozytorium jest szablon Fluttera z testem licznika. Nie ma serwera, bazy danych, zaimplementowanego [kontraktu API](kontrakt-api.md), katalogu `integration_test/`, konfiguracji CI, adapterów zewnętrznych ani implementacji aparatu/OCR. Wszystkie przypadki poniżej są **planowane**. Nie należy oznaczać ich jako wykonanych na podstawie testu szablonowego. Lokalny Dart 3.10.7 nie spełnia wymogu `^3.13.7` z `app/pubspec.yaml`, więc uruchomienie obecnej bramki blokuje niezgodność SDK. Wymagana jest zgodna wersja Flutter/Dart i odtworzenie konfiguracji pakietów.

## 2. Środowiska i dane

1. **CI, deterministyczne:** lokalna baza testowa z migracjami oraz lokalne atrapy HTTP dla źródeł przepisów, bazy żywieniowej i dostawcy AI. Każdy test ma własne konto i izolowany stan danych; klucze usług zewnętrznych nie są potrzebne.
2. **Android / emulator:** aplikacja Flutter połączona z serwerem testowym. Testy aparatu, uprawnień, OCR, przejścia offline/online i wylogowania wykonuje się na urządzeniu lub emulatorze Android. Po wdrożeniu dodać `integration_test` z Flutter SDK i odpowiednią konfigurację uruchamiania; obecnie jej nie ma. Android jest docelową platformą MVP (ADR-010).
3. **Kontrolowany smoke z usługami zewnętrznymi:** po wyborze dostawców i uzyskaniu konfiguracji sprawdzić pojedyncze rzeczywiste wywołanie, limity, zgodność licencji i format odpowiedzi. Nie stanowi ono codziennej bramki CI, ponieważ dostępność i treść usług mogą się zmieniać.
4. **Fixture:** konto A i konto B, różne profile, plan i dziennik, przepisy pełne i niepełne, produkt jednoznaczny i niejednoznaczny, etykieta czytelna i nieczytelna. W testach nie używać prawdziwych danych osobowych ani sekretów.

Przygotowując backend FastAPI i PostgreSQL, spisać ich wersje, schemat migracji, adresy środowisk testowych, kontrakt endpointów, sposób czyszczenia danych oraz polecenia uruchamiania. Polecenia serwera i wersje pozostają do ustalenia.

## 3. Przypadki: API, baza, sesja

Każdy przypadek obejmuje kod odpowiedzi, treść odpowiedzi, skutek w bazie i stan aplikacji. Dla operacji zmieniających dane należy potwierdzić trwałość przez ponowny odczyt, a nie tylko odpowiedź na zapis.

| ID | Scenariusz | Warunek zaliczenia | Wymagania |
| --- | --- | --- | --- |
| I-01 | Rejestracja, logowanie hasłem, opcjonalne logowanie Google po skonfigurowaniu, nieudane logowanie. | Powstaje właściwa sesja; nieudane logowanie nie ujawnia profilu. | RF-M01 |
| I-02 | Żądanie bez tokenu, z wygasłym tokenem dostępu, błąd sieci podczas odnowienia i odwołana sesja. | Serwer odrzuca nieważny dostęp; klient odnawia go automatycznie i ponawia żądanie najwyżej raz. Błąd sieci nie wylogowuje i nie kasuje kolejki; odwołanie wymaga logowania. | RF-M02 |
| I-03 | Konto A wykonuje create/read/update/delete profilu, a B próbuje odczytać i zmienić rekord A. | Każda operacja A jest trwała; B nie widzi ani nie zmienia danych A. | RF-M03, RF-M19 |
| I-04 | Formularz kryteriów wysyła częściowe i pełne zapytanie. | Puste kryteria nie zawężają wyników; filtr odpowiada wysłanym wartościom. | RF-M04 |
| I-05 | Konto A dodaje, zmienia i usuwa plan, potem dziennik; restart serwera między zapisem a odczytem. | Oba zbiory zachowują pełny CRUD, są trwałe i odrębne; konto B jest odizolowane. | RF-M16, RF-M17, RF-M19 |
| I-06 | Zapis z błędem walidacji lub awarią zależności w połowie operacji. | Nie powstaje częściowo zapisany rekord ani błędna suma; użytkownik widzi błąd. | RF-M16, RF-M17, RF-M19 |
| I-07 | Uruchomienie z cache, utrata i odzyskanie sieci, później wylogowanie. | Cache jest oznaczony jako możliwie nieaktualny, dane się odświeżają, po wylogowaniu dane konta nie są widoczne. | RF-M02, RF-M20 |

## 4. Przypadki: przepisy, odżywianie i AI

W CI odpowiedzi serwisów zewnętrznych są zapisanymi fixture obsługiwanymi przez atrapy HTTP. Test należy wykonać również dla `timeout`, błędu serwera, `429`, pustej odpowiedzi i zmiany formatu istotnego pola.

| ID | Scenariusz | Warunek zaliczenia | Wymagania |
| --- | --- | --- | --- |
| I-08 | Wyszukiwanie dwóch publicznych stron z powielonym przepisem. | Duplikat jest usunięty, wynik zachowuje tytuł, źródło i datę odczytu. | RF-M05 |
| I-09 | Odczyt przepisu z pełnymi i niepełnymi składnikami, porcjami oraz czasem. | Wyodrębnione dane są poprawne; brak ilości i niejednoznaczność są jawne. | RF-M06 |
| I-10 | Normalizacja g/kg/ml oraz składnika bez przelicznika. | Kalkulacja wykorzystuje tylko uzasadnione konwersje, reszta pozostaje nieoszacowana. | RF-M07 |
| I-11 | Agent proponuje zamianę składnika; użytkownik zatwierdza ją w aplikacji. | Źródłowy przepis i URL zostają zachowane, zmiana jest oznaczona, wartości są przeliczone. | RF-M08, RF-M09 |
| I-12 | Dopasowanie składników do API żywieniowego: wynik jednoznaczny, wiele kandydatów, brak i błąd usługi. | Zapisano produkt, źródło, jednostkę i ilość; niepewność wymaga korekty lub oznaczenia. | RF-M10, RF-M15 |
| I-13 | Cały przepis i porcja są obliczane po zmianie ilości lub liczby porcji. | Sumy kcal/B/W/T są zgodne z fixture z planu jednostkowego. | RF-M11 |
| I-14 | Jeden składnik nie ma danych, drugi nie ma ilości. | Interfejs pokazuje niepełność, pominięte składniki, datę i źródło; nie przedstawia sumy jako pełnej. | RF-M12 |
| I-15 | Ranking dla profilu i kryteriów, w tym przepis niezgodny oraz niepełny. | Kolejność ma wyjaśnienie; widoczne są warunki niespełnione i nieweryfikowalne. | RF-M13 |
| I-16 | Przepis z alergenem, wykluczonym produktem i niepełnym składem. | Nie jest oznaczony jako zgodny ani bezpieczny przy niepewności. | RF-M14 |
| I-17 | Brak wyników, niedostępna strona, niedostępne API odżywcze. | Widać przyczynę i możliwość zmiany zapytania lub uzupełnienia danych; brak fikcyjnych danych. | RF-M15 |
| I-18 | Start serwera z wybranym OpenAI API lub LM Studio, potem błędna konfiguracja i awaria dostawcy. | Wywołania trafiają do wybranego adaptera; błędna konfiguracja blokuje start, awaria nie przełącza dostawcy. | RF-M21 |

## 5. Przypadki: urządzenie i pełne ścieżki

| ID | Scenariusz | Warunek zaliczenia | Wymagania / przypadki użycia |
| --- | --- | --- | --- |
| I-19 | Aparat: zgoda, odmowa uprawnienia, nieczytelna etykieta i korekta OCR przed zapisem. | Użytkownik może poprawić jednostkę, wartości i ilość; brak automatycznego zapisu błędnego odczytu, dostępny wpis ręczny. | RF-M18, PU-M06 |
| I-20 | Rejestracja → profil → wyszukanie → ocena źródła i szacunku → plan → potwierdzenie spożycia → dziennik. | Dwa odrębne podsumowania są poprawne i trwałe po ponownym uruchomieniu. | PU-M01–M05, RF-M01–M17, RF-M19 |
| I-21 | Tryb offline: CRUD profilu/planu/dziennika, utworzenie dziennika z lokalnego planu, restart aplikacji i powrót online. | Zmiany i zależności pozostają w kolejce, widoki od razu je uwzględniają, synchronizacja nie dubluje wpisów i uzgadnia sumy z serwerem. | PU-M07, RF-M02, RF-M20 |
| I-22 | Operator uruchamia serwer kolejno z każdym dostawcą AI i z konfiguracją błędną. | Każdy poprawny wybór działa, błąd jest czytelny, nie ma cichego fallbacku. | PU-M08, RF-M21 |
| I-23 | `202 + search_id`, rozłączenie, opuszczenie ekranu, powrót, anulowanie i wyścig anulowania z zakończeniem. | Nie powstaje drugie zadanie; wyjście nie anuluje; anulowanie jest pokazane dopiero po potwierdzeniu. Końcowy stan nie zmienia się w fikcyjne anulowanie. | RF-M05, RF-M15 |
| I-24 | Zadanie przekracza 5 minut; dostępne są wyniki lub ich brak; później mija 30 dni retencji. | Częściowe wyniki mają ostrzeżenie, brak wyników z awarii daje failed, poprawne zero trafień jest completed. Po retencji zadanie daje 410; plan i dziennik zachowują dane. | RF-M05, RF-M15, RF-M20 |
| I-25 | Serwer stosuje zapis, odpowiedź ginie, klient i serwer są restartowane, a kolejka ponawia ten sam zapis/edycję/usunięcie. | Dokładnie jeden skutek; stały identyfikator operacji i kontrola wersji. Długie offline lub wygaśnięcie cache nie umożliwiają ponownego zastosowania zmiany. | RF-M16–RF-M20 |
| I-26 | Dwa urządzenia zmieniają ten sam wpis lub jedno go usuwa; równolegle istnieją niezależne operacje. | Konflikt zachowuje lokalne zmiany i wymaga wyboru; ponowne zastosowanie używa aktualnej wersji, a niezależne operacje przechodzą. | RF-M19, RF-M20 |
| I-27 | Wylogowanie z niewysłanymi zmianami: synchronizacja udana/nieudana, powrót, usunięcie; potem konto B i ponowne A. | Kolejka nie ginie bez wyboru, brak synchronizacji nie udaje sukcesu; konto B nie widzi danych A. Po odwołaniu sesji zachowane zmiany można wznowić wyłącznie na tym samym koncie. | RF-M02, RF-M20 |
| I-28 | Początkowa migawka konta z wieloma stronami, równoczesne zmiany na drugim urządzeniu, przyrost z usunięciami i wygaśnięcie kursora. | Brak luk między migawką i deltą; powtórzona strona jest stabilna, a kursor i dane są utrwalane razem. Reset kursora zachowuje lokalną kolejkę i nie udaje pełnych danych po częściowej migawce. | RF-M19, RF-M20 |
| I-29 | Wylogowanie offline, usunięcie access/refresh tokenów, późniejsze wysłanie wyłącznie ticketu odwołania. | Ticket może tylko odwołać swoją sesję; nie służy do logowania/odczytu. Ponowne odwołanie jest bezpieczne, a inna sesja/konto nie zostaje odwołane. | RF-M02, RF-M20 |
| I-30 | Żądania i odpowiedzi działającego serwera porównane z OpenAPI, także błędy FastAPI, prywatny szacunek dla współdzielonego przepisu i próba zaplanowania proposal. | Odpowiedzi realizują DTO i format błędu; cudzy szacunek jest niedostępny, a propozycja wymaga zatwierdzenia. Samo przejście walidacji pliku specyfikacji nie zalicza tego scenariusza. | RF-M01–RF-M20 |

## 6. Dodatkowe sprawdzenia jakości

- **Bezpieczeństwo danych:** powtórzyć odczyt i zmianę profilu, planu oraz dziennika tokenem drugiego konta. Sprawdzić brak tokenów, haseł, zdjęć etykiet i pełnych danych profilu w logach.
- **Migracje:** utworzyć bazę od zera i z poprzedniego schematu; po migracji istniejące rekordy i powiązania kont są zachowane. Dodać test każdej migracji schematu po powstaniu backendu.
- **Odporność:** timeout, ponowienie zapytania, `429` i brak sieci nie mogą powodować podwójnego zapisu planu/dziennika ani fikcyjnej wartości odżywczej.
- **Zasoby:** mierzyć czas startu, wielkość cache, liczbę żądań dla jednego wyszukiwania i zużycie pamięci na urządzeniu docelowym. Progi ustalić po pierwszym pomiarze bazowym, zgodnie z wymaganiem minimalnego zużycia zasobów.
- **Źródła:** przy rzeczywistym smoke potwierdzić, że wybrane strony i API dopuszczają planowany sposób użycia oraz że link, data i zakres braków są pokazane użytkownikowi.

## 7. Bramka wykonania i raport

Przypadek jest zaliczony po zapisaniu środowiska, wersji aplikacji i serwera, danych testowych, kroków, oczekiwanego i rzeczywistego wyniku oraz identyfikatora dowodu (log bez danych wrażliwych, zrzut ekranu albo wynik CI). Defekt ma odtwarzalny scenariusz i test regresyjny. W PR należy wypisać przypadki wykonane automatycznie i ręcznie oraz te zablokowane wraz z powodem.

Po zapewnieniu zgodnego SDK na obecnym stanie repozytorium można wykonać tylko istniejącą bramkę Fluttera, w `app/`:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Polecenia integracyjne backendu, uruchamianie bazy i emulatora oraz workflow CI należy dopisać po implementacji tych elementów. Testy z prawdziwymi usługami uruchamiać osobno od deterministycznej bramki PR.
