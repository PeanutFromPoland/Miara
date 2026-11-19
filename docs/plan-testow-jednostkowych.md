# Plan testów jednostkowych

## 1. Cel i stan projektu

Plan obejmuje wymagania MVP z [listy wymagań i przypadków użycia](wymagania_funkcjonalne_i_przypadki_uzycia.md). Test jednostkowy sprawdza jedną regułę domenową lub usługę w izolacji, bez sieci, prawdziwej bazy, aparatu i modelu AI. Testy muszą być powtarzalne: stałe dane wejściowe, kontrolowany czas, kontrolowana kolejność wyników i jawne atrapowe odpowiedzi zależności.

**Stan obecny (aktualizacja 2026-11-09):** `app/` jest szablonem Fluttera. `app/lib/main.dart` zawiera licznik, a `app/test/widget_test.dart` test licznika. Nie ma jeszcze kodu domenowego dietetyka, backendu ani testów opisanych niżej. Tabele są planem wykonania, a nie raportem zaliczonych testów. W `app/pubspec.yaml` są `flutter_test` i `flutter_lints`; backend wybrano jako Python/FastAPI z PostgreSQL (ADR-009), a testy jednostkowe serwera należy dopisać przy tworzeniu backendu. Lokalny Dart 3.10.7 nie spełnia wymogu `^3.13.7` z `app/pubspec.yaml`, więc uruchomienie obecnej bramki blokuje niezgodność SDK. Wymagana jest zgodna wersja Flutter/Dart i odtworzenie konfiguracji pakietów.

## 2. Organizacja

**Dostępna walidacja kontraktu (2026-11-16):** [testy OpenAPI](../tests/contracts/test_openapi.py) sprawdzają plik specyfikacji, przykłady i przypadki formatów danych. [Instrukcja i wynik](api/README.md) dotyczą wyłącznie kontraktu; nie zmieniają statusu planowanych poniżej testów domenowych J/W i nie wymagają Fluttera ani backendu.

- Czyste reguły w Dart umieszczać poza widgetami; ich testy w `app/test/domain/` lub w katalogu odpowiadającym przyjętej strukturze `lib/`.
- Testy usług aplikacyjnych używają atrap repozytorium, zegara, HTTP, OCR i dostawcy modelu. Atrapom przekazywać dane źródłowe, błędy i opóźnienia jawnie.
- Widgety testować osobno w `app/test/widgets/`: stan ładowania, wynik, błąd, dostępność kontrolek, walidacja i potwierdzenie przed zapisem. Nie zastępować tym testów reguł domenowych.
- Reguły backendu (uwierzytelnienie, własność danych, konfiguracja dostawcy) testować w jego wybranym później frameworku. Komendy i ścieżki backendu dopisać po wyborze stosu.
- Każdy defekt w kalkulacji, alergenach, izolacji kont lub utracie danych dostaje test regresyjny z najmniejszym możliwym przykładem.

## 3. Dane referencyjne

Fixture `NUT-01` do kalkulatora: 50 g płatków o wartościach na 100 g `370 kcal, B 13 g, W 60 g, T 7 g` oraz 200 ml mleka o wartościach na 100 ml `50 kcal, B 3,4 g, W 5 g, T 1,5 g`. Oczekiwana suma przepisu: `285 kcal, B 13,3 g, W 40 g, T 6,5 g`; przy dwóch porcjach: `142,5 kcal, B 6,65 g, W 20 g, T 3,25 g`. Wartości zaokrągla się dopiero przy prezentacji, według ustalonej decyzji projektowej. Nie wyliczać kcal ponownie z makroskładników, jeżeli źródło podało własną wartość energii.

Fixture `NUT-02`: składnik bez ilości, składnik bez dopasowania w bazie i nieznana liczba porcji. Oczekiwany wynik ma jawne braki; brakująca wartość nie staje się zerem, a niepełna suma nie jest oznaczona jako pełna.

Fixture `OCR-01`: etykieta podaje wartości „w 100 g” z przecinkiem dziesiętnym; użytkownik zjada 75 g. Fixture `OCR-02`: wartości „na porcję”, nieczytelna liczba lub brak jednostki. Odczyt wymaga korekty lub potwierdzenia; nie tworzy wpisu samoczynnie.

## 4. Przypadki testowe

Status każdego przypadku: **planowany**. Odpowiedzialny za zadanie dopisuje identyfikator testu automatycznego i wynik w PR.

| ID | Reguła i dane graniczne | Oczekiwany wynik | Wymagania |
| --- | --- | --- | --- |
| J-01 | Rejestracja i logowanie: poprawne oraz błędne dane wejściowe, puste hasło; jednostka walidacji po wyborze mechanizmu kont. | Błędy pól są jawne; błędne dane nie tworzą sesji. | RF-M01 |
| J-02 | Token dostępu ważny, wygasły i uszkodzony, odnowienie sesji, błąd sieci i odwołana sesja; atrapowy zegar. | Wygasły dostęp odnawia się automatycznie bez stałego limitu sesji; błąd sieci nie wylogowuje ani nie kasuje kolejki. Odwołana sesja wymaga logowania, a dane innych kont pozostają odizolowane. | RF-M02 |
| J-03 | Profil: brak celu kcal, wartości ujemne lub zerowe tam, gdzie niedozwolone, opcjonalne makra, lista wykluczeń i alergenów. | Niepoprawny profil jest odrzucony; poprawny zachowuje wszystkie pola bez utraty danych. | RF-M03 |
| J-04 | Kryteria wyszukiwania: brak pól, granice czasu, liczby składników oraz zakresów kcal i makr. | Puste pole nie filtruje; odwrócone lub niepoprawne zakresy dają czytelny błąd. | RF-M04 |
| J-05 | Dwa wyniki z tym samym źródłem i różnymi wariantami adresu; wynik bez tytułu. | Duplikaty są usuwane według ustalonej reguły; zapisane są tytuł, URL i data odczytu albo jawny brak. | RF-M05 |
| J-06 | Ekstrakcja fixture przepisu: porcje, składniki, ilość, jednostka, czas; pole niejednoznaczne. | Pola rozpoznane trafiają do struktury danych, pozostałe dostają stan „nieznane”; agent nie dopowiada ilości. | RF-M06 |
| J-07 | Przeliczenie `0,5 kg → 500 g`, `200 ml`, jednostka sztukowa bez uzgodnionego przelicznika. | Tylko uzasadniona konwersja jest wykonywana; nieznany przelicznik blokuje szacunek danego składnika. | RF-M07 |
| J-08 | Zamiana składnika albo ilości w kopii przepisu. | Oryginał i źródło pozostają dostępne; zmiana jest oznaczona, a wynik odżywczy przeliczony po akceptacji. | RF-M08, RF-M09 |
| J-09 | Dopasowanie składnika do jednoznacznego, wielu oraz żadnego produktu w bazie. | Wynik zachowuje produkt, źródło, ilość i jednostkę; wariant niejednoznaczny wymaga poprawki lub oznaczenia. | RF-M10 |
| J-10 | Kalkulacja fixture `NUT-01`, zmiana ilości jednego składnika i liczby porcji. | Dokładne sumy całości i jednej porcji odpowiadają danym wejściowym; po zmianie są ponownie obliczone. | RF-M11 |
| J-11 | Fixture `NUT-02`; starsza data pobrania danych; brak jednego makroskładnika. | Wynik wskazuje pominięte składniki, kompletność, źródło i datę; brak nie jest zerem ani pełną sumą. | RF-M12 |
| J-12 | Ranking: zgodność z celem, czasem i preferencją; remis oraz nieweryfikowalne kryterium. | Kolejność jest deterministyczna, a uzasadnienie wymienia spełnione, niespełnione i nieweryfikowalne warunki. | RF-M13 |
| J-13 | Rozpoznany alergen, synonim produktu wykluczonego i niepełna lista składników. | Przepis nie dostaje oznaczenia zgodności; przy niepewności brak deklaracji bezpieczeństwa. | RF-M14 |
| J-14 | Brak wyników, timeout strony, błąd API żywieniowego. | Powstaje jawny stan błędu lub pusty wynik, bez fikcyjnego przepisu i wartości. | RF-M15 |
| J-15 | Dodanie, zmiana porcji i usunięcie pozycji z planu; pozycja o niepełnych danych. | Sumy planu i różnica względem celu się aktualizują; niepełność pozostaje widoczna. | RF-M16 |
| J-16 | Wpis dziennika z planu i ręczny, poprawka, usunięcie; niezjedzony posiłek z planu. | Suma spożycia obejmuje wyłącznie dziennik, niezależnie od planu. | RF-M17 |
| J-17 | Parsowanie `OCR-01` i `OCR-02`, polskie przecinki, `100 g` wobec „na porcję”, brak jednostki. | Wartości są poprawnie skalowane dopiero po potwierdzeniu; niepewny odczyt wymaga korekty. | RF-M18 |
| J-18 | Operacje repozytorium w pamięci: create/read/update/delete, brak rekordu, obcy właściciel. | Zmiany odnoszą się do właściwego konta; brak rekordu i cudzy rekord nie dają danych. | RF-M19 |
| J-19 | Start offline z cache i bez cache, lokalny CRUD profilu/planu/dziennika, restart i odzyskanie sieci. | Widoczny czas synchronizacji i lokalne zmiany; trwała kolejka przeżywa restart, a odświeżenie nie nadpisuje operacji oczekujących. | RF-M20 |
| J-20 | Konfiguracja `OpenAI API`, `LM Studio`, brak wyboru, błędny adres lub klucz; awaria wybranego dostawcy. | Powstaje jeden wskazany adapter albo jawny błąd; brak automatycznego przełączenia. | RF-M21 |
| J-21 | Odpytywanie zadania: pierwsze 20 s, dalszy czas, limit 300 s, stan końcowy i przejście w tło; atrapowy zegar. | Interwały 2/5 s; klient wstrzymuje odpytywanie, ale nie anuluje zadania. Powrót odczytuje ten sam identyfikator; limit daje partial albo failed. | RF-M05, RF-M15 |
| J-22 | Trwała kolejka: zależne create/update/delete, lokalne ID, utrata odpowiedzi, 3 próby i błędy 422/409. | Nie powstają duplikaty; klucz i treść ponowienia są stałe; odstępy wynoszą 2 i 5 s; walidacja i konflikt nie są automatycznie ponawiane. | RF-M16–RF-M20 |
| J-23 | Dwie wersje wpisu, usunięcie na serwerze, konflikt jednego wpisu przy niezależnym drugim. | Lokalne zmiany są zachowane; użytkownik wybiera wersję; niezależne operacje nie są blokowane. | RF-M19, RF-M20 |
| J-24 | Wylogowanie z kolejką: synchronizuj, wróć, usuń; błąd synchronizacji; czyszczenie cache po 30 dniach. | Bez wyboru zmiany nie giną; nieudana synchronizacja nie prowadzi do usunięcia. Czyszczenie nie usuwa przepisów potrzebnych wpisom lub kolejce. | RF-M02, RF-M20 |

## 5. Testy widgetów powiązane z przypadkami użycia

| ID | Widok / interakcja | Oczekiwany wynik | Powiązanie |
| --- | --- | --- | --- |
| W-01 | Logowanie i edycja profilu z błędnymi polami. | Błędy przy właściwych polach, brak zapisu do czasu poprawy. | PU-M01, RF-M01–M03 |
| W-02 | Wyniki wyszukiwania, źródło przepisu, oznaczenie zmian i braków. | URL jest dostępny, zmiany i niekompletne szacunki są czytelne. | PU-M02–M03, RF-M05–M15 |
| W-03 | Plan oraz dziennik po dodaniu, edycji i usunięciu. | Dwa odrębne podsumowania; zmiana jednego nie zmienia drugiego. | PU-M04–M05, RF-M16–M17 |
| W-04 | Ekran OCR z błędnym odczytem i odmową uprawnienia. | Ręczna korekta i wpis są możliwe, bez automatycznego zapisu odczytu. | PU-M06, RF-M18 |
| W-05 | Ekran offline z cache i bez cache, odnowienie dostępu, odwołanie sesji i wylogowanie z kolejką. | Odrębne komunikaty, brak automatycznego wylogowania przy błędzie sieci; wybór losu niewysłanych zmian przy wylogowaniu. | PU-M07, RF-M02, RF-M20 |
| W-06 | Pierwsze ładowanie, odświeżanie, lokalny zapis, błąd, konflikt i nowe wyszukiwanie przy starych wynikach. | Dane i formularz pozostają; zmiana ma oznaczenie oczekiwania na synchronizację; stare wyniki są oznaczone i nie nadpisują nowego zadania. Brak fikcyjnego procentu wyszukiwania. | RF-M05, RF-M15, RF-M20 |

## 6. Kryteria zaliczenia i uruchamianie

1. Dla zmienionej reguły istnieje test poprawnego przypadku, granicy i istotnego błędu. Test wykrywa zmianę wyniku reguły, nie tylko wykonanie metody.
2. Krytyczne reguły `RF-M10–M14`, `RF-M16–M18` oraz izolacja danych `RF-M02/M19` mają deterministyczne fixture i regresję każdego znalezionego defektu.
3. Testy nie korzystają z prawdziwych kluczy, kont użytkowników ani zewnętrznych usług. Czas i odpowiedzi zależności są kontrolowane.
4. W PR zapisano ID przypadków, wynik i pozostałe ograniczenia. Próg pokrycia kodu ustalić dopiero po wydzieleniu kodu domenowego; samo pokrycie linii nie zastępuje sprawdzenia wyniku.

Polecenia dla **obecnego projektu Flutter**, uruchamiane w `app/` po zapewnieniu zgodnego SDK:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Polecenia backendu oraz jego bramkę testową należy dopisać po wyborze technologii i utworzeniu serwera. Obecny test licznika jest jedynie testem szablonu; nie potwierdza wymagań MVP.
