# Macierz śladowania wymagań MVP

Ta macierz łączy [wymagania funkcjonalne](wymagania_funkcjonalne_i_przypadki_uzycia.md), [zadania](backlog-mvp.md) i zaplanowane przypadki z [testów jednostkowych](plan-testow-jednostkowych.md) oraz [integracyjnych](plan-testow-integracyjnych.md). `J` oznacza test jednostkowy, `W` test widgetu, `I` test integracyjny. **Wszystkie statusy są początkowo „planowane”**: istniejące `app/test/widget_test.dart` sprawdza tylko szablonowy licznik Fluttera.

| Wymaganie | Zadania realizujące | Planowane dowody testowe | Przypadek użycia | Status / wynik wykonania |
| --- | --- | --- | --- | --- |
| RF-M01 Konto i logowanie | T-08, T-11 | J-01, W-01, I-01, I-20 | PU-M01 | planowane / — |
| RF-M02 Sesja i wylogowanie | T-08, T-11, T-23 | J-02, J-24, W-05, I-02, I-07, I-27, I-29 | PU-M01, PU-M07 | planowane / — |
| RF-M03 CRUD profilu | T-09, T-11 | J-03, W-01, I-03, I-20 | PU-M01 | planowane / — |
| RF-M04 Kryteria wyszukiwania | T-14, T-17, T-18 | J-04, I-04, I-20 | PU-M02 | planowane / — |
| RF-M05 Publiczne przepisy | T-02, T-14, T-17 | J-05, J-21, W-06, I-08, I-20, I-23, I-24 | PU-M02 | planowane / — |
| RF-M06 Ekstrakcja przepisu | T-15 | J-06, I-09, I-20 | PU-M02 | planowane / — |
| RF-M07 Normalizacja składników | T-03, T-13, T-15 | J-07, I-10, I-20 | PU-M02 | planowane / — |
| RF-M08 Zatwierdzane zmiany | T-16, T-18 | J-08, I-11, I-20 | PU-M03 | planowane / — |
| RF-M09 Źródło i oznaczenie zmian | T-02, T-14, T-15, T-18 | J-08, W-02, I-11 | PU-M02, PU-M03 | planowane / — |
| RF-M10 Zewnętrzna baza żywieniowa | T-03, T-12 | J-09, I-12, I-20 | PU-M03 | planowane / — |
| RF-M11 Wyliczenie całości i porcji | T-03, T-13, T-18 | J-10, I-13, I-20 | PU-M03, PU-M04 | planowane / — |
| RF-M12 Kompletność i pochodzenie | T-03, T-13, T-18 | J-11, W-02, I-14, I-20 | PU-M03, PU-M04 | planowane / — |
| RF-M13 Ranking z uzasadnieniem | T-16, T-18 | J-12, I-15, I-20 | PU-M03 | planowane / — |
| RF-M14 Alergeny i wykluczenia | T-16, T-18 | J-13, I-16, I-20 | PU-M03 | planowane / — |
| RF-M15 Stany awarii i brak wyników | T-12, T-14, T-17, T-18 | J-14, J-21, W-06, I-17, I-23, I-24 | PU-M02, PU-M03 | planowane / — |
| RF-M16 CRUD planu dziennego | T-19, T-21, T-23 | J-15, J-22, J-23, W-03, I-05, I-20, I-21, I-25, I-26 | PU-M04 | planowane / — |
| RF-M17 CRUD dziennika | T-20, T-21, T-22, T-23 | J-16, J-22, J-23, W-03, I-05, I-20, I-21, I-25, I-26 | PU-M05, PU-M06 | planowane / — |
| RF-M18 Aparat i OCR | T-22 | J-17, W-04, I-19 | PU-M06 | planowane / — |
| RF-M19 Własna baza i pełny CRUD | T-05, T-09, T-19, T-20, T-23 | J-18, J-22, J-23, I-03, I-05, I-06, I-25, I-26 | PU-M01, PU-M04–PU-M06 | planowane / — |
| RF-M20 Zapisy offline i synchronizacja | T-04, T-11, T-23 | J-19, J-22–J-24, W-05, W-06, I-07, I-21, I-25–I-30 | PU-M07 | planowane / — |
| RF-M21 Wybór dostawcy AI | T-07, T-17 | J-20, I-18, I-22 | PU-M08 | planowane / — |

## Wymagania zaliczeniowe i jakość

| Warunek | Zadanie | Dowód do uzupełnienia | Status |
| --- | --- | --- | --- |
| Flutter | T-10, T-11, T-18, T-21–T-23 | Uruchomiona aplikacja na wskazanym urządzeniu i testy widgetów | planowane |
| Zewnętrzne API | T-03, T-12 | Wywołanie wybranej bazy żywieniowej i zachowane źródło danych | planowane |
| Własna baza z CRUD | T-05, T-09, T-19, T-20 | I-03, I-05, I-06 na bazie testowej i po restarcie | planowane |
| Sensor | T-22 | I-19 z aparatem na urządzeniu | planowane |
| Testy jednostkowe | T-24 i zadania funkcjonalne | J-01–J-24, raport CI | planowane |
| GitHub i CI/CD | T-06 | Repozytorium z kodem i dokumentami, zielony oraz celowo nieudany przebieg CI | planowane |
| Minimalne zużycie zasobów | T-25 | Pomiar według [scenariusza NFR](wymagania-niefunkcjonalne.md) | planowane |

## Aktualizacja przy realizacji

Po scaleniu zadania zastąp „planowane / —” statusem `w toku`, `zaliczone` lub `zablokowane` i wstaw identyfikator testu oraz dowód (PR/CI/protokół). Dowód musi wskazywać wynik wykonania na określonej wersji; sama nazwa testu z planu nie wystarcza. Zmiana wymagania wymaga jednoczesnej korekty zadania, testu i tej macierzy. `T-24` zamyka luki śladowania, `T-26` potwierdza całość przy odbiorze.
