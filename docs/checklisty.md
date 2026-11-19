# Checklisty wykonawcze i odbiór MVP

Checklisty odnoszą się do [wymagań](wymagania_funkcjonalne_i_przypadki_uzycia.md), [planu testów jednostkowych](plan-testow-jednostkowych.md) i [planu testów integracyjnych](plan-testow-integracyjnych.md). Każdy zaznaczony punkt musi mieć dowód w zadaniu, PR albo protokole odbioru. Puste pola oznaczają pracę do wykonania, nie stwierdzone braki konkretnej implementacji.

**Stan bazowy (2026-11-06):** istnieje szablon Fluttera z testem licznika oraz dokument wymagań. Backend, baza, CI/CD i funkcje dietetyka nie są jeszcze zaimplementowane. Dlatego checklisty MVP zaczynają się od stanu niezrealizowanego.

## 1. Checklista pojedynczego zadania

Identyfikator: `___` · właściciel: `___` · powiązane RF/PU: `___` · zależności: `___`

- [ ] Cel zadania i zachowanie użytkownika są opisane jednym lub dwoma zdaniami.
- [ ] Wskazano konkretne `RF-Mxx` i `PU-Mxx` oraz zakres MVP/rozwój.
- [ ] Kryteria akceptacji opisują przypadek poprawny, granicę i błąd, możliwe do sprawdzenia bez interpretacji.
- [ ] Ustalono kontrakt danych, walidację, źródło danych i zachowanie przy braku danych.
- [ ] Ustalono wpływ na uprawnienia, izolację kont i dane przechowywane na urządzeniu.
- [ ] Wskazano identyfikatory przypadków z planów testów oraz fixture; jeżeli brak, dopisano je.
- [ ] Implementacja i migracja (gdy dotyczy) są ukończone; brak danych nie jest zastępowany fikcyjnym wynikiem.
- [ ] Dodano testy jednostkowe, widgetowe lub integracyjne adekwatne do zmienionych granic modułów.
- [ ] Wykonano lokalne bramki dla istniejącego Fluttera: `flutter analyze` i `flutter test`; wynik zapisano.
- [ ] Sprawdzono ręcznie ścieżkę użytkownika na docelowym urządzeniu, jeśli zadanie dotyczy aparatu, uprawnień, offline lub UI.
- [ ] Zaktualizowano dokumentację, decyzję architektoniczną i zadania zależne, jeśli kontrakt lub zachowanie się zmieniło.
- [ ] W zadaniu zapisano wynik odbioru, dowód oraz pozostałe ograniczenia.

## 2. Checklista PR

PR: `___` · zadanie: `___` · reviewer: `___`

- [ ] Opis PR podaje cel, zakres zmian, powiązane RF/PU, sposób testowania i ryzyko.
- [ ] Zmiany są ograniczone do zadania; nie ma przypadkowych plików wygenerowanych, kluczy ani danych prywatnych.
- [ ] Kod i kontrakty są czytelne; błędy, timeouty i stany puste mają obsługę.
- [ ] Operacje na danych wymagają właściwej sesji i właściciela rekordu.
- [ ] Obliczenia kcal/B/W/T, jednostki, liczba porcji i niepełność szacunku są sprawdzone fixture.
- [ ] Zmiana planu nie tworzy wpisu dziennika, a wpis dziennika nie zmienia planu bez jawnej akcji.
- [ ] Wynik agenta i OCR wymagający potwierdzenia nie jest zapisywany automatycznie.
- [ ] Testy regresyjne odtwarzają poprawiany defekt, jeśli PR naprawia błąd.
- [ ] `dart format --output=none --set-exit-if-changed .`, `flutter analyze` i `flutter test` w `app/` przechodzą, jeśli PR zmienia Fluttera.
- [ ] Bramka backendu i migracje przechodzą, jeśli PR zmienia serwer lub bazę (polecenia dopisać po wyborze stosu).
- [ ] Reviewer sprawdził kryteria akceptacji i zapisał uwagi albo zatwierdzenie.

## 3. Checklista iteracji

Iteracja: `___` · cel: `___` · zakres zadań: `___`

### Planowanie

- [ ] Wybrano mały, działający fragment przepływu użytkownika i mierzalny wynik iteracji.
- [ ] Zależności są znane; decyzje otwarte mają właściciela i termin.
- [ ] Zadania mają identyfikatory, kolejność, kryteria odbioru, RF/PU i przypadki testowe.
- [ ] Przygotowano fixture, atrapę usług i dane dwóch kont potrzebne do testów.

### Zakończenie

- [ ] Wszystkie zadania zamknięte w iteracji mają dowód spełnienia kryteriów.
- [ ] Wykonano pełną bramkę Fluttera i bramkę backendu, jeżeli już istnieje.
- [ ] Wykonano odpowiednie scenariusze integracyjne oraz regresję zmienionych ścieżek.
- [ ] Pokazano działający przepływ na urządzeniu lub emulatorze, jeżeli zakres dotyczy aplikacji mobilnej.
- [ ] Defekty i ograniczenia zostały zapisane z priorytetem; krytyczne defekty nie przechodzą do kolejnej bramki.
- [ ] Zaktualizowano status RF/PU, plan kolejnej iteracji i decyzje architektoniczne.

## 4. Checklista wydania

Wersja: `___` · data: `___` · środowisko: `___` · osoba odbierająca: `___`

- [ ] Zakres wydania i lista ukończonych RF-M01–M21 są potwierdzone dowodami.
- [ ] CI/CD wykonuje formatowanie, analizę i testy Fluttera oraz testy serwera po jego utworzeniu; wersjonowany artefakt jest dostarczany lub wdrażany na środowisko testowe według udokumentowanego wyzwalacza.
- [ ] Wersja Flutter/Dart w CI spełnia ograniczenie SDK z `app/pubspec.yaml`; pakiety odtworzono z lockfile.
- [ ] Testy jednostkowe i integracyjne przechodzą na wersji przeznaczonej do wydania; zebrano raport.
- [ ] Migracje bazy od zera i z poprzedniej wersji są sprawdzone na kopii danych testowych.
- [ ] Konfiguracja OpenAI API albo LM Studio jest jawna; błędny wybór lub konfiguracja daje czytelny błąd bez cichego przełączenia.
- [ ] Sekrety są poza repozytorium i artefaktem aplikacji; tokeny oraz dane zdrowotne nie trafiają do logów.
- [ ] Dwa konta potwierdzają izolację profilu, planu i dziennika oraz odmowę żądań bez ważnej sesji.
- [ ] Na docelowym urządzeniu sprawdzono aparat, odmowę uprawnienia, OCR i korektę przed zapisem.
- [ ] Sprawdzono start offline z cache i bez cache, lokalny CRUD, restart z kolejką, powrót online bez duplikatów i wybór wersji przy konflikcie dwóch urządzeń.
- [ ] Zwykłe wygaśnięcie tokenu odnawia dostęp; brak sieci nie wylogowuje. Przy ręcznym wylogowaniu z kolejką sprawdzono synchronizację, powrót i jawne usunięcie niewysłanych zmian.
- [ ] Wyszukiwanie zachowuje identyfikator po rozłączeniu, ma limit 5 minut, potwierdzane anulowanie i rozróżnia pusty wynik, częściowy wynik oraz awarię.
- [ ] Sprawdzono awarie stron z przepisami, API żywieniowego i modelu AI; interfejs nie pokazuje fikcyjnych wyników.
- [ ] Przy każdym przepisie i szacunku widoczne są źródło, data oraz istotne braki; źródła dopuszczają planowany sposób użycia.
- [ ] Wykonano pomiar bazowy startu, cache, liczby żądań i pamięci na docelowym urządzeniu; odnotowano wynik.
- [ ] Gotowe są instrukcja uruchomienia, konfiguracji, backupu/odtworzenia oraz plan cofnięcia wydania.
- [ ] Protokół odbioru zawiera wersję, datę, wykonane scenariusze, wyniki, defekty i decyzję o wydaniu.

## 5. Kryteria odbioru MVP

Każda pozycja wymaga działającego przepływu w aplikacji, odpowiedniego testu z planów oraz wskazania dowodu. Statusy mogą być `nie rozpoczęto / w toku / zaliczone / zablokowane`; przed odbiorem MVP wszystkie RF-M01–M21 muszą mieć status `zaliczone` albo jawnie zatwierdzoną zmianę zakresu w wymaganiach.

| Obszar | Co należy pokazać przy odbiorze | RF / PU | Status / dowód |
| --- | --- | --- | --- |
| Konto i sesja | Rejestracja/logowanie, Google po konfiguracji, błędne logowanie, odmowa bez tokenu, wylogowanie. | RF-M01–M02, PU-M01, PU-M07 | `___` |
| Profil i kryteria | Pełny CRUD profilu, cele i wykluczenia; niezależne kryteria wyszukiwania. | RF-M03–M04, PU-M01–M02 | `___` |
| Przepisy | Publiczne źródła, deduplikacja, ekstrakcja porcji/składników/ilości/czasu, normalizacja, oznaczenie zmian i link. | RF-M05–M09, PU-M02–M03 | `___` |
| Szacowanie | Dopasowanie produktów z zewnętrznego API, przeliczenie kcal i makr, suma całości/porcji, kompletność i pochodzenie. | RF-M10–M12, PU-M03 | `___` |
| Dobór i błędy | Ranking z uzasadnieniem, wykluczenie alergenów, niepewność i jawna obsługa niedostępności usług. | RF-M13–M15, PU-M02–M03 | `___` |
| Plan i dziennik | Trwały, oddzielny CRUD obu zbiorów; poprawne sumy planu i faktycznego spożycia. | RF-M16–M17, RF-M19, PU-M04–M05 | `___` |
| Aparat i OCR | Zdjęcie tabeli wartości, korekta jednostki i odczytu, potwierdzenie przed zapisem, wpis ręczny przy błędzie. | RF-M18, PU-M06 | `___` |
| Synchronizacja | CRUD offline z trwałą kolejką, oznaczenie stanu, brak duplikatów, wybór przy konflikcie i wylogowaniu z niewysłanymi zmianami. | RF-M20, PU-M07 | `___` |
| Serwer AI | Wybór OpenAI API albo LM Studio przy starcie, walidacja konfiguracji, brak samoczynnego fallbacku. | RF-M21, PU-M08 | `___` |
| Wymagania zaliczeniowe | Flutter, własna baza z CRUD, zewnętrzne API, aparat jako sensor, testy jednostkowe, GitHub, CI/CD i pomiar zasobów. | [Wymagania zaliczeniowe](wymagania.md) | `___` |

Wydania nie odbiera się na podstawie samego wyglądu ekranów lub zielonego testu licznika. Wynik ma wynikać z danych zapisanych i odczytanych ponownie, izolacji kont, sprawdzonych błędów oraz testów na rzeczywistych granicach systemu.

## 6. Checklisty wykonania testów

### Test jednostkowy

ID z [planu jednostkowego](plan-testow-jednostkowych.md): `___` · RF/PU: `___` · środowisko i wersja SDK: `___`

- [ ] Przygotowano stałą fixture, kontrolowany zegar i atrapy zależności; zapisano dane wejściowe oraz oczekiwany wynik.
- [ ] Uruchomiono przypadek sukcesu, graniczny i błędu; wynik testu rzeczywiście sprawdza regułę.
- [ ] Zapisano polecenie, wynik (`zaliczony / niezaliczony / zablokowany`) i datę wykonania.
- [ ] Dołączono dowód: wynik CI lub lokalny log bez danych wrażliwych.
- [ ] Dla niezaliczonego testu zapisano defekt z krokami odtworzenia; dla poprawki dodano regresję.

### Test integracyjny

ID z [planu integracyjnego](plan-testow-integracyjnych.md): `___` · RF/PU: `___` · środowisko, wersja aplikacji/serwera/bazy: `___`

- [ ] Uruchomiono izolowaną bazę testową i właściwe migracje; przygotowano konta A/B, fixture oraz atrapy usług albo udokumentowane środowisko smoke.
- [ ] Zapisano kroki i oczekiwany skutek po obu stronach granicy (UI/API/baza/urządzenie).
- [ ] Uruchomiono przypadek sukcesu i błędu, w tym niedostępność zależności lub odmowę dostępu, jeśli dotyczy.
- [ ] Potwierdzono zapis ponownym odczytem, izolację kont i brak fikcyjnych danych tam, gdzie dotyczy.
- [ ] Zapisano wynik (`zaliczony / niezaliczony / zablokowany`), polecenie lub sekwencję ręczną oraz datę.
- [ ] Dołączono dowód: wynik CI, log bez danych wrażliwych lub zrzut ekranu urządzenia.
- [ ] Dla niezaliczonego przypadku zapisano defekt, stan danych i kroki odtworzenia; po naprawie wykonano regresję.
