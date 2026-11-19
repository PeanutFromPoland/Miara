# Integracje zewnętrzne i ich granice

> Status: plan integracyjny dla MVP. Żadna z poniższych integracji nie jest jeszcze zaimplementowana. Wymagania źródłowe: [RF-M01–RF-M21](wymagania_funkcjonalne_i_przypadki_uzycia.md). AniaGotuje.pl wybrano jako podstawowe źródło przepisów w ADR-012 (13 listopada 2026); wcześniejszy przegląd kandydatów opisuje ADR-011. Dopuszczalność retencji treści i pobierania mediów nie została potwierdzona.

## Zasada wspólna

Własny serwer wywołuje sieciowe źródła przepisów, danych żywieniowych i modelu przez adaptery; aplikacja mobilna korzysta z adapterów systemowych aparatu i ewentualnie OCR. Adapter zwraca dane z identyfikatorem źródła, datą, jednostkami i statusem jakości albo jawny błąd. Logika domenowa nie zależy od formatu odpowiedzi konkretnego dostawcy. Atrapy i zestawy utrwalonych odpowiedzi umożliwiają testy bez sieci. Klucze i limity usług serwerowych pozostają po stronie serwera; klient mobilny otrzymuje tylko dane potrzebne do widoku.

| Integracja | Wejście | Wyjście i pochodzenie | Typowe awarie | Reakcja |
| --- | --- | --- | --- | --- |
| Publiczne przepisy i wyszukiwanie | Kryteria dania | URL, tytuł, data odczytu i dozwolone metadane; pola analityczne tylko przy potwierdzonej podstawie | Blokada, zmiana HTML, brak pól, duplikat | Pominąć niedozwolone źródło, oznaczyć luki, nie tworzyć fikcyjnego przepisu |
| Zewnętrzna baza żywieniowa/API | Nazwa i wariant produktu | ID produktu, jednostka odniesienia, kcal i makro, data/źródło | Limit, brak produktu, niejednoznaczny wariant, brak makro | Kandydaci do wyboru lub brak danych; częściowy szacunek |
| OpenAI API lub LM Studio | Zadanie ekstrakcji/dopasowania wraz z dozwolonym kontekstem | Ustrukturyzowana propozycja i uzasadnienie | Timeout, niepoprawny JSON, treść wymyślona, brak serwera | Walidacja schematu i źródła; błąd bez samoczynnej zmiany dostawcy |
| Google (logowanie opcjonalne) | Credential z klienta | Zweryfikowana tożsamość i własna sesja | Odmowa użytkownika, nieważny token, brak sieci | Czytelny błąd; brak utworzenia sesji |
| Aparat i OCR | Zdjęcie etykiety | Szkic odczytanych wartości i jednostki | Odmowa uprawnień, rozmycie, błędny odczyt | Ręczny wpis lub korekta; brak automatycznego zapisu |

## Publiczne przepisy

RF-M05 wymaga publicznie dostępnych stron, bez płatnego planu API z przepisami. W ramach T-02 sprawdzono reprezentatywne strony z `centrumrespo.pl`, `przepisy.pl`, `kwestiasmaku.com` oraz `zdrowe-odzywianie-przepisy.blogspot.com`. Publiczne HTML jest technicznie parsowalne: przykłady zawierają tytuł, składniki z ilościami, porcje, instrukcje, czas, a niekiedy wartości żywieniowe. Serwisy mogą pokazywać obrazy; to nie daje samo w sobie prawa do ich kopiowania. Szczegóły próby i decyzji są w [ADR-011](decyzje-projektowe.md).

**Źródło podstawowe:** [AniaGotuje.pl](https://aniagotuje.pl/), wybrane przez właściciela projektu 13 listopada 2026 w [ADR-012](decyzje-projektowe.md#adr-012--aniagotujepl-jako-podstawowe-źródło-przepisów). Pierwszy adapter i próbki ekstrakcji dotyczą `aniagotuje.pl`. Zakres obejmuje dostępne składniki i ilości, instrukcje, czasy przygotowania i obróbki, porcje lub masę dania oraz deklarowane wartości odżywcze. Podstawę wartości (np. 100 g) zachowywać jawnie; nie zamieniać masy całego dania na liczbę porcji. Dane żywieniowe portalu są danymi źródłowymi i nie zastępują osobnej bazy do obliczeń z RF-M10–M12. Cztery domeny z ADR-011 pozostają kandydatami uzupełniającymi.

**Eksperyment techniczny:** obejmuje źródło podstawowe i kandydatów z ADR-011, tylko dla stron publicznych, które nie wymagają logowania ani obchodzenia zabezpieczeń. Dla każdego żądania sprawdzać aktualny `robots.txt`, warunki serwisu, ograniczenia techniczne i rozsądny limit częstotliwości. Natychmiast respektować odmowę, blokadę, `noindex`/inne sygnały i żądanie właściciela; nie obchodzić CAPTCHA, paywalla ani limitów. Przed produkcyjnym uruchomieniem ponownie zweryfikować dopuszczalność dla konkretnego celu i sposobu użycia.

**Przechowywanie i prezentacja:** bez indywidualnej licencji/zgody utrwalać wyłącznie kanoniczny URL, domenę, tytuł, datę odczytu i minimalne metadane potrzebne do deduplikacji/odtworzenia linku. Nie pobierać, hostować ani redystrybuować zdjęć; wyświetlać obraz tylko przez link do strony źródłowej albo po uzyskaniu zgody. Nie zachowywać pełnego tekstu przepisu ani instrukcji jako trwałej kopii. Pól składników i ilości używanych do wyliczeń nie wolno automatycznie traktować jako wolnych od ograniczeń: przed ich trwałym zapisem należy udokumentować licencję/zgodę albo potwierdzoną podstawę prawną i zakres dozwolonego użycia; w przeciwnym razie ograniczyć użycie do dozwolonego przetwarzania tymczasowego (jeżeli potwierdzone) lub pominąć źródło. Zawsze zachowywać źródło i link.

Adapter rozdziela odkrywanie adresu, pobranie strony i ekstrakcję pól. Preferuje jawne dane strukturalne, jeśli są dostępne i dozwolone. Ekstrakcję modelową uruchamia tylko dla niejednoznacznych pól; wynik modelu przechodzi walidację. Kanoniczny URL i odcisk techniczny odpowiedzi mogą służyć deduplikacji, ale nie mogą stać się pretekstem do archiwizacji treści objętej prawami. Każda propozycja zmian składników tworzy własną wersję z pochodzeniem i listą zmian (RF-M08–M09).

## Dane żywieniowe

Wyboru API należy dokonać po próbie na rzeczywistych polskich składnikach i produktach. Kryteria: licencja, limit, koszt, dostępność, pokrycie, jednostki, szczegółowość makro, wersjonowanie i możliwość przechowywania migawek. Lista próbna powinna obejmować produkty surowe i gotowe, różne odmiany, niejednoznaczne nazwy oraz braki wartości. Wynik próby i decyzja trafiają do [rejestru decyzji](decyzje-projektowe.md).

Zewnętrzna wartość ma obowiązkowe: identyfikator produktu, źródło, datę, podstawę (`per_amount`, `per_unit`) i status dopasowania. Przelicznik sztuk, łyżek i szklanek do g/ml wymaga osobnej podstawy. Obliczenia wykonuje własny moduł deterministyczny; model AI nie jest źródłem kcal. Czas cache musi wynikać z licencji i oczekiwanej aktualności danych. Przy braku API serwer nie podaje pełnego szacunku (RF-M10–M12, RF-M15).

## Dostawca modelu AI

Wybór **OpenAI API albo LM Studio** jest wymaganiem RF-M21 i następuje podczas inicjalizacji serwera przez operatora. Konfiguracja zawiera typ dostawcy, adres usługi, identyfikator modelu, poświadczenie jeśli wymagane, timeout i limit wywołań. Serwer waliduje kompletność i podstawową łączność konfiguracji. Błąd inicjalizacji jest jawny; serwer nie przełącza dostawcy samoczynnie. Operacje zależne od modelu zwracają błąd, gdy wybrany dostawca jest później niedostępny.

Adapter przyjmuje zadanie domenowe i zwraca wersjonowany schemat, niezależny od dostawcy. Odpowiedź modelu jest niezaufana: należy sprawdzić typy, zakresy, obecność źródeł i zgodność z materiałem wejściowym. Wyszukana strona nie może przez swoją treść zmienić instrukcji systemu ani skłonić serwera do ujawnienia sekretów. Do modelu trafia minimalny fragment przepisu; dane profilu są ograniczane do pól potrzebnych do zadania. Trzeba ustalić, które dane mogą opuszczać serwer przy wyborze OpenAI API, i opisać to użytkownikowi.

## Google, aparat i OCR

Serwer weryfikuje credential Google po stronie zaufanej, wiąże tożsamość z jednym kontem i wydaje własną sesję. Sam identyfikator przesłany przez klienta nie wystarcza do logowania. Zasady łączenia kont z tym samym adresem wymagają decyzji. Logowanie hasłem pozostaje ścieżką RF-M01.

Aparat telefonu spełnia wymóg użycia sensora. Użytkownik nadaje uprawnienie dopiero przy rozpoczęciu skanowania. Przy odmowie może wprowadzić dane ręcznie. OCR odczytuje co najmniej kcal, białko, węglowodany, tłuszcz oraz jednostkę odniesienia, ale każde pole może pozostać nieznane. Użytkownik poprawia wynik i podaje spożytą ilość przed utworzeniem wpisu w dzienniku. Miejsce wykonania OCR (urządzenie/serwer), retencja zdjęcia i przesyłanie obrazu są decyzjami otwartymi.

## Kontrole operacyjne i testowe

- Dla każdego adaptera: timeout, limit równoległości, kontrolowane ponowienia tylko dla bezpiecznych operacji, metryki błędów i możliwość wyłączenia wadliwego źródła.
- Dla każdej odpowiedzi: data pozyskania, źródło i wersja parsera/adaptera; dane zewnętrzne są walidowane, a niespójności logowane bez danych wrażliwych.
- Testy jednostkowe używają przypadków pustych, częściowych, niejednoznacznych i błędnych. Testy integracyjne używają kontrolowanych odpowiedzi oraz ograniczonego testu z dostawcą po wyborze usługi.
- Środowiska deweloperskie i CI nie wymagają prawdziwych sekretów. Testy z usługą zewnętrzną uruchamia się osobno, z limitami kosztu i oznaczeniem źródła.
- Zmiana warunków lub struktury źródła wymaga ponownego przeglądu adaptera i testów regresji; wynik użytkownika nadal pokazuje źródło i niepewność.

Powiązane dokumenty: [architektura](architektura.md), [model danych](model-danych.md), [kontrakt API](kontrakt-api.md).
