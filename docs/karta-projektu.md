# Karta projektu — Miara

**Status:** plan MVP. **Wersja dokumentu:** 1.2, 13 listopada 2026. **Źródło zakresu:** [wymagania](wymagania.md) i [przypadki użycia](wymagania_funkcjonalne_i_przypadki_uzycia.md).

## Problem i odbiorca

Użytkownik planujący posiłki musi dziś osobno szukać przepisów, interpretować składniki, sprawdzać wartości odżywcze i zapisywać spożycie. Miara łączy te czynności w jednej aplikacji mobilnej. Wyniki agenta są propozycjami z widocznym pochodzeniem danych i ograniczeniami szacunku; użytkownik decyduje o planie i potwierdza faktyczne spożycie.

Głównym odbiorcą jest osoba samodzielnie planująca codzienne posiłki. Operatorem jest osoba uruchamiająca serwer i wybierająca dostawcę modelu AI. Aplikacja nie wyznacza celu medycznego, nie diagnozuje i nie potwierdza bezpieczeństwa dania dla osoby z alergią.

## Cel MVP

Użytkownik może:

1. Założyć konto, zalogować się, ustawić profil, wykluczenia i kryteria wyszukiwania.
2. Otrzymać propozycje przepisów z publicznych stron, zobaczyć źródło, składniki, brakujące dane, szacunkowe kcal i makroskładniki oraz powód dopasowania.
3. Ułożyć plan na dzień i niezależnie prowadzić dziennik rzeczywiście zjedzonych posiłków.
4. Odczytać tabelę żywieniową aparatem, poprawić wynik OCR i dopiero wtedy zapisać wpis.
5. Obejrzeć ostatnie zapisane dane przy braku sieci i wylogować się z usunięciem lokalnych danych konta.

Własny serwer Python/FastAPI i baza PostgreSQL wdrożone on-premise zapewniają trwały CRUD profilu, planu i dziennika. Klient Flutter MVP działa na Androidzie. Zewnętrzne API dostarcza danych żywieniowych. Dostawca zadań AI jest wybierany przez operatora przy uruchomieniu serwera: OpenAI API albo LM Studio.

## Granice zakresu

| W MVP | Po MVP (`RF-R01`–`RF-R05`) |
| --- | --- |
| Plan na pojedynczy dzień, dziennik, źródła i kompletność szacunków, OCR etykiety | Plan na kilka dni, lista zakupów, szacowanie kosztów, dodatkowe składniki odżywcze, uczenie preferencji z ocen |

Prototyp [Miara](prototyp-ui/README.md) stanowi punkt odniesienia dla układu pięciu głównych ekranów i detalu przepisu. Nie przesądza technologii backendu, sposobu pobierania danych ani kompletności przepływów.

## Warunki sukcesu przy odbiorze

| Obszar | Dowód |
| --- | --- |
| Zakres | Każde `RF-M01`–`RF-M21` ma działającą demonstrację, test lub oba dowody opisane w [macierzy](macierz-sladowania.md). |
| Dane | CRUD profilu, planu i dziennika działa po restarcie serwera; konto A nie widzi danych konta B. |
| Wiarygodność | Każdy szacunek pokazuje źródło i kompletność; braki nie są zamieniane na zera; niepewny skład nie otrzymuje oznaczenia bezpieczeństwa alergicznego. |
| Stabilność | Błędy stron, bazy żywieniowej i modelu AI prowadzą do czytelnego stanu, bez fikcyjnych wyników. |
| Wytwarzanie | Kod jest w GitHub, CI uruchamia analizę i testy, a wynik przechodzi [checklistę wydania](checklisty.md). |
| Urządzenie | Aparat i OCR są pokazane na urządzeniu lub emulatorze obsługującym tę ścieżkę; odmowa uprawnień i ręczna korekta są sprawdzone. |
| Zasoby | Wykonano i zapisano pomiar czasu odpowiedzi, liczby wywołań zewnętrznych i zasobów aplikacji na wskazanym urządzeniu testowym; kryteria uzgodniono w [NFR](wymagania-niefunkcjonalne.md). |

## Najważniejsze ryzyka

| Ryzyko | Skutek | Działanie przed implementacją / kontrola |
| --- | --- | --- |
| Strony z przepisami blokują automatyczny odczyt lub zmieniają strukturę | Brak wyników albo błędne składniki | Wybór dopuszczonych źródeł, próbki i testy ekstrakcji; jawne pomijanie niedostępnych stron. |
| Baza żywieniowa słabo pokrywa polskie produkty | Niepełne oszacowania | Próbka reprezentatywnych składników i decyzja o źródle przed integracją. |
| Nieznane jednostki, ilości lub liczba porcji | Zafałszowane sumy | Reguły normalizacji, status niepełny i korekta przez użytkownika. |
| Niepełna informacja o alergenach | Niewłaściwe oznaczenie dania | Stan „niezweryfikowane”, testy negatywne, brak obietnicy bezpieczeństwa. |
| Zbyt szeroki MVP | Niedokończony przepływ podstawowy | Zależności w backlogu i bramki iteracji; funkcje `RF-Rxx` po odbiorze MVP. |

## Decyzje projektowe

Stos backendu i bazy, hosting oraz platforma MVP zostały wybrane w T-01; szczegóły uruchamiania on-premise i migracji pozostają do dopracowania. AniaGotuje.pl wybrano jako podstawowe źródło danych o przepisach 13 listopada 2026 (ADR-012). Nadal otwarte są warunki produkcyjnego pobierania i retencji treści źródeł, zewnętrzne API żywieniowe, jednostki i reguły obliczeń, sposób logowania przez Google, strategia synchronizacji oraz budżety wydajności. Właściciel i dowód każdej decyzji są w [rejestrze decyzji](decyzje-projektowe.md).
