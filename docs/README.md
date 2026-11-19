# Dokumentacja projektu Miara

Miara to planowana aplikacja mobilna osobistego dietetyka AI. Ten katalog jest punktem wejścia do pracy projektowej, implementacji i odbioru MVP. **Źródłem zakresu** są [wymagania zaliczeniowe i opis MVP](wymagania.md) oraz [wymagania funkcjonalne i przypadki użycia](wymagania_funkcjonalne_i_przypadki_uzycia.md). Identyfikatory `RF-M01`–`RF-M21` odnoszą się do MVP; `RF-R01`–`RF-R05` opisują rozwój po MVP.

## Stan na 16 listopada 2026

- `app/` jest domyślnym projektem Flutter z licznikiem i jednym testem szablonowym. Nie realizuje jeszcze funkcji Miary.
- [Prototyp UI](prototyp-ui/README.md) pokazuje nawigację i przykładowe dane. Nie komunikuje się z serwerem, nie zapisuje danych i nie używa aparatu.
- Nie ma jeszcze backendu, własnej bazy, integracji z usługami zewnętrznymi ani CI/CD. W T-01 wybrano Python/FastAPI, PostgreSQL i wdrożenie on-premise; aplikacja MVP jest kierowana na Androida.
- Dokumenty poniżej są **projektem docelowym i planem wykonania**, nie opisem gotowej implementacji. Otwarte wybory zapisano w [rejestrze decyzji](decyzje-projektowe.md).
- [Rozmowa o API i stanach aplikacji](ustalenia-api-i-stany.md) rozstrzygnęła stały format danych, zadania wyszukiwania z limitem 5 minut, wyniki częściowe, sesję bez automatycznego wylogowania, zapisy offline, konflikty i stany UI. Wymagają teraz implementacji; OpenAPI i testy zgodności należą do T-05.
- Pierwszym krokiem T-05 jest [model danych v0.1](model-danych.md): encje, typy, relacje, migawki i reguły synchronizacji. Po jego przeglądzie doprecyzujemy formaty komunikacji i OpenAPI (ADR-014, 16 listopada). Model jest szkicem do omówienia, a nie wdrożonym schematem bazy.
- Na podstawie modelu opracowano [kontrakt API v0.1.0](kontrakt-api.md) i [specyfikację OpenAPI](api/openapi.json), zgodnie z poleceniem przejścia do kontraktu (ADR-015). [Instrukcja i wynik walidacji](api/README.md) rozdzielają sprawdzenie dokumentu od przyszłych testów działającego serwera.

## Mapa dokumentacji

| Potrzeba | Dokument |
| --- | --- |
| Cel produktu, granice MVP, miary odbioru | [Karta projektu](karta-projektu.md) |
| Funkcje i przypadki użycia | [Wymagania funkcjonalne](wymagania_funkcjonalne_i_przypadki_uzycia.md) |
| Jakość, bezpieczeństwo, wydajność, dostępność | [Wymagania niefunkcjonalne](wymagania-niefunkcjonalne.md) |
| Moduły i przepływy danych | [Architektura](architektura.md) |
| Encje, relacje i reguły trwałości | [Model danych](model-danych.md) |
| Granica aplikacja–serwer | [Kontrakt API](kontrakt-api.md) |
| Maszynowy kontrakt, przykłady i walidacja | [OpenAPI v0.1.0](api/README.md) |
| Przyjęte odpowiedzi o API, sesji, offline, konfliktach i stanach widoków | [Ustalenia API i stanów klienta](ustalenia-api-i-stany.md) |
| Strony z przepisami, baza żywieniowa, model AI, OCR | [Integracje zewnętrzne](integracje-zewnetrzne.md) |
| Wybory techniczne, założenia i kwestie otwarte | [Decyzje projektowe](decyzje-projektowe.md) |
| Kolejność prac, bramki i Definition of Done | [Plan wytwarzania](plan-wytwarzania.md) |
| Gotowy zakres prac MVP | [Backlog MVP](backlog-mvp.md) |
| Powtarzalne karty pracy | [Szablony zadań](szablony-zadan.md) |
| Wymaganie → zadanie → dowód | [Macierz śladowania](macierz-sladowania.md) |
| Testowanie logiki i widoków | [Plan testów jednostkowych](plan-testow-jednostkowych.md) |
| Testowanie współpracy modułów i przepływów | [Plan testów integracyjnych](plan-testow-integracyjnych.md) |
| Listy do odhaczenia podczas pracy i odbioru | [Checklisty](checklisty.md) |

## Jak z tego korzystać

1. Przed rozpoczęciem implementacji zamknij decyzje blokujące z [rejestru decyzji](decyzje-projektowe.md), zwłaszcza stos serwera, bazę danych, źródła przepisów i bazę żywieniową. Udokumentuj wybór i jego konsekwencje.
2. Bierz zadania z [backlogu](backlog-mvp.md) w kolejności zależności. Dla każdej karty użyj [szablonu](szablony-zadan.md), wpisz właściciela i dowód odbioru.
3. W PR pokaż powiązanie z `RF-Mxx`, testy, wynik checklisty i zmianę dokumentacji, jeśli kontrakt lub zachowanie się zmieniło.
4. Przy odbiorze MVP przejdź [macierz śladowania](macierz-sladowania.md) i [checklistę odbioru](checklisty.md). Sam status „zrobione” w backlogu nie zastępuje demonstracji funkcji.

## Zasada aktualizacji

Zmiana zachowania produktu aktualizuje wymaganie, kontrakt, test i zadanie w tym samym PR. Decyzje techniczne zapisujemy przed wdrożeniem rozwiązania, a wynik weryfikacji po wdrożeniu. Dane i wartości w prototypie pozostają demonstracyjne, dopóki nie zastąpią ich implementacje potwierdzone testami.
