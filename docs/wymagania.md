# Wymagania na zaliczenie projektu

- [ ] Wykorzystanie zewnętrznego API
- [ ] Wykorzystanie pełnego CRUD we własnej bazie danych
- [ ] Wykorzystanie min. jednego sensora np. BT, GPS, higrometr, termometr, akcelerometr, smartwatche, itp.
- [ ] Testy jednostkowe
- [ ] Github
- [ ] CI/CD
- [ ] Flutter/React Native/Kotlin
- [ ] Minimalne zużycie zasobów

## Aplikacja

### MVP

Aplikacja pełni rolę osobistego dietetyka AI. Użytkownik określa cele żywieniowe, preferencje i wykluczenia. Agent wyszukuje ogólnodostępne przepisy w sieci, dobiera dania i składniki do profilu oraz szacuje kcal i makroskładniki na podstawie ilości składników i danych z zewnętrznej bazy żywieniowej. Użytkownik układa dzienny plan posiłków i zapisuje faktyczne spożycie w dzienniku. Aparat telefonu pozwala odczytać tabelę wartości odżywczych produktu do ręcznego wpisu. Profile, plany i dzienniki są przechowywane we własnej bazie danych.

Pozyskanie przepisów nie wymaga płatnego planu API z przepisami. Przy każdej propozycji i wartości szacowanej aplikacja pokazuje źródło oraz braki danych.

### Dodatkowe funkcje

- Planowanie posiłków na kilka dni.
- Lista zakupów tworzona ze składników zaplanowanych przepisów.
- Szacowanie kosztu przepisów z publicznych cen.
- Prezentacja dodatkowych składników odżywczych, gdy dostępne są odpowiednie dane.
- Uczenie preferencji na podstawie ocen i poprawek użytkownika.

## Uszczegółowienie

Pełna lista wymagań funkcjonalnych i przypadków użycia: [wymagania_funkcjonalne_i_przypadki_uzycia.md](wymagania_funkcjonalne_i_przypadki_uzycia.md).
