# Rejestr decyzji projektowych

> Status: żywy rejestr. Odróżnia ustalenia wynikające z [wymagań](wymagania_funkcjonalne_i_przypadki_uzycia.md) od decyzji, których nie podjęto. ADR-009–010 dokumentują wybory T-01 z 9 listopada 2026 r.; ADR-011 przegląd źródeł z 9 listopada; ADR-012 wybór AniaGotuje.pl z 13 listopada. ADR-013, ADR-108 i ADR-112 oraz część sesyjna ADR-106 odzwierciedlają [rozmowę o API i stanach aplikacji](ustalenia-api-i-stany.md) z 13 listopada 2026 r. Decyzja przyjęta nie oznacza gotowego kodu lub zaliczonego testu.

## Jak podejmować i zapisywać decyzje

Każda decyzja ma właściciela, datę, porównane warianty, kryteria, dowody z krótkiej próby, konsekwencje oraz termin przeglądu. Statusy: **przyjęta**, **otwarta**, **zastąpiona**. Dla decyzji otwartej zadanie implementacyjne może przygotować adapter lub eksperyment, lecz nie powinno wbudowywać niezweryfikowanego dostawcy w logikę domenową. Gdy wybór zapadnie, należy uaktualnić [architekturę](architektura.md), [kontrakt API](kontrakt-api.md), testy i plan wytwarzania.

Szablon nowego wpisu:

```text
ID i tytuł:
Status / data / właściciel:
Problem i ograniczenia z RF:
Warianty:
Kryteria i dowody (próba, pomiar, licencja, koszt):
Decyzja i uzasadnienie:
Konsekwencje, ryzyka, zadania następcze:
Data przeglądu:
```

## Ustalenia przyjęte na podstawie wymagań

| ID | Ustalenie | Podstawa | Konsekwencja |
| --- | --- | --- | --- |
| ADR-001 | Klient mobilny powstaje we Flutterze; repozytorium ma startowy projekt w `app/`. | [Wymagania zaliczeniowe](wymagania.md), istniejący `app/pubspec.yaml` | Ekran licznika w `app/lib/main.dart` jest szablonem do zastąpienia. |
| ADR-002 | Własny serwer i własna baza przechowują konta, profile, plany i dzienniki; dla trzech ostatnich jest pełny CRUD. | RF-M01–M03, RF-M16–M19 | Serwer egzekwuje własność zasobów. |
| ADR-003 | Plan i dziennik są oddzielne; plan nie potwierdza spożycia. | RF-M16–M17, PU-M04–M05 | Osobne encje i sumy. |
| ADR-004 | Wartości kcal i makro są obliczane z ilości składników i zewnętrznej bazy żywieniowej. Braki są jawne. | RF-M10–M12 | AI nie dostarcza „gotowych” liczb bez podstawy. |
| ADR-005 | Przepisy pochodzą z publicznych stron dostępnych bez płatnego planu API z przepisami; przy wyniku widać link i zmiany. | RF-M05–M09 | Potrzebny przegląd źródeł oraz ograniczeń użycia. |
| ADR-006 | Operator przy starcie serwera wybiera OpenAI API albo LM Studio. Błędna konfiguracja daje błąd, bez automatycznego przełączenia. | RF-M21 | Jeden adapter domenowy i walidacja konfiguracji. |
| ADR-007 | OCR etykiety daje szkic do korekty; zapis następuje po potwierdzeniu użytkownika. | RF-M18 | Aparat jest sensorem MVP, a obraz nie tworzy automatycznie wpisu. |
| ADR-008 | Rozpoznany alergen/wykluczenie eliminuje oznaczenie zgodności; brak danych nie potwierdza bezpieczeństwa. | RF-M14 | Wynik ma stan niezweryfikowany. |
| ADR-009 | Backend MVP: Python z FastAPI; własna baza danych: PostgreSQL; wdrożenie serwera i bazy on-premise. | Wybór właściciela projektu w ramach T-01, 9 listopada 2026 | Serwer i PostgreSQL działają w środowisku zarządzanym przez zespół; przygotować instrukcję lokalnego uruchomienia, konfigurację bez sekretów, migracje, backup i odtworzenie. Szczegóły systemu operacyjnego, kontenerów i lokalizacji wdrożenia pozostają do ustalenia. |
| ADR-010 | Pierwszą platformą mobilną MVP jest Android; klient pozostaje we Flutterze. | Wybór właściciela projektu w ramach T-01, 9 listopada 2026 | CI, konfiguracja aparatu/OCR, testy, instalator i demonstracja skupiają się na Androidzie; inne platformy nie są kryterium odbioru MVP. |
| ADR-011 | Źródła do prototypowej ekstrakcji: `centrumrespo.pl`, `przepisy.pl`, `kwestiasmaku.com` i `zdrowe-odzywianie-przepisy.blogspot.com`. Scraping HTML jest technicznie wykonalny dla publicznych stron z przepisami, ale wolno utrwalać domyślnie tylko URL, tytuł i niezbędne metadane. Pełne teksty przepisów i obrazy wymagają uprzedniej licencji/zgody; do tego czasu treści źródłowe prezentujemy przez link. | Przegląd stron, przykładów HTML, regulaminów/oznaczeń praw autorskich i `robots.txt` 9 listopada 2026; wybór właściciela projektu w ramach T-02. `robots.txt` nie udało się odczytać w tej weryfikacji i wymaga sprawdzenia bezpośrednio przed implementacją/uruchomieniem. | Zastosować allowlistę domen, sprawdzać warunki i `robots.txt` przed każdym źródłem, pobierać z limitem i identyfikacją klienta. Nie kopiować ani hostować zdjęć; nie przechowywać pełnych instrukcji. Dla analizy obliczeniowej utrwalać tylko pola niezbędne i krótkotrwałe po potwierdzeniu podstawy prawnej; w innym przypadku wymagać licencji/zgody lub pominąć źródło. Okresowo ponawiać przegląd praw i struktury. |
| ADR-012 | Podstawowym źródłem danych o przepisach jest [AniaGotuje.pl](https://aniagotuje.pl/). Pozostałe domeny z ADR-011 pozostają kandydatami uzupełniającymi. | Przyjęta 13 listopada 2026; właściciel: właściciel projektu. Wybór po porównaniu bezpłatnych serwisów i przeglądzie przykładowego przepisu. | W pierwszej kolejności przygotować adapter i próbki ekstrakcji dla `aniagotuje.pl`; zakres danych obejmuje dostępne składniki, ilości, instrukcje, czasy, porcje lub masę dania oraz wartości odżywcze z jednostką odniesienia. Nadal obowiązują zasady użycia z ADR-011 i otwarty ADR-103; wybór zewnętrznej bazy żywieniowej pozostaje w ADR-104. |

### ADR-012 — AniaGotuje.pl jako podstawowe źródło przepisów

- **Status / data / właściciel:** przyjęta / 13 listopada 2026 / właściciel projektu.
- **Problem i ograniczenia:** RF-M05–M09 wymagają publicznych przepisów z widocznym źródłem. Potrzebne są możliwie szczegółowe dane bez płatnego planu API z przepisami.
- **Porównane warianty:** AniaGotuje, Kuchnia Lidla, Moje Wypieki, Kwestia Smaku, RecipeTin Eats, Serious Eats, Budget Bytes, Sally’s Baking, King Arthur Baking i The Woks of Life; wcześniejszą listę kandydatów dokumentuje ADR-011.
- **Kryteria i dowody:** bezpłatny dostęp do treści przepisu, język polski, gramatury, opis etapów, czasy, informacje o porcji lub masie dania i wartości odżywcze. W przeglądzie serwisów w rozmowie projektowej sprawdzono m.in. [lazanię](https://aniagotuje.pl/przepis/lazania): zawiera składniki z ilościami, instrukcje ze zdjęciami pomocniczymi, czas przygotowania i pieczenia, wymiary formy, tryb piekarnika, masę gotowego dania oraz kcal i makroskładniki na 100 g. Przegląd treści nie jest testem adaptera ani potwierdzeniem warunków automatycznego pobierania i retencji.
- **Decyzja i uzasadnienie:** przyjmujemy `aniagotuje.pl` jako podstawowe źródło danych o przepisach ze względu na szczegółowość opisów, polskie nazwy składników i dostępność danych ilościowych. Pozostałe źródła mają rolę uzupełniającą.
- **Konsekwencje i zadania następcze:** w T-02 i T-14 priorytet otrzymuje adapter AniaGotuje. Brakujące pola pozostają jawnie nieznane; masa całego dania nie jest liczbą porcji, a wartości na 100 g nie są wartościami na porcję. Wartości deklarowane przez portal zachowują źródło i podstawę odniesienia; obliczenia dla składników i zmienionych przepisów nadal realizują ADR-004 oraz osobna baza żywieniowa wybierana w ADR-104. Zasady retencji tekstu i obrazów z ADR-011 oraz weryfikacja z ADR-103 pozostają obowiązujące.
- **Termin przeglądu:** przed implementacją adaptera i uruchomieniem pobierania; ponownie po zmianie struktury strony lub warunków użycia.

### Próbka weryfikacyjna T-02 (9 listopada 2026, ADR-011)

| Domena | Przykład HTML i pola widoczne w treści | Warunki/oznaczenia sprawdzone | Wniosek |
| --- | --- | --- | --- |
| `centrumrespo.pl` | [Kaszotto z kurczakiem i warzywami](https://centrumrespo.pl/przepisy/kaszotto-kurczakiem-warzywami/): składniki z gramaturą, wartości na porcję, instrukcje, czas, obrazy. | Regulamin stwierdza, że treści serwisu i materiały mogą należeć do RESPO lub podmiotów trzecich i podlegają prawu autorskiemu; samo przeglądanie publiczne nie stanowi licencji na kopiowanie. | Parsowalne; zdjęcia i pełny przepis wyłączyć z pobierania/retencji do czasu licencji lub zgody. |
| `przepisy.pl` | [Danie pełne warzyw i tofu](https://www.przepisy.pl/przepis/danie-pelne-warzyw-i-tofu): składniki i karta przepisu; serwis opisuje też fotografie, instrukcje i multimedia. | Regulamin wiąże licencję Unilever z pracami wgranymi przez użytkowników na potrzeby portalu; nie daje licencji naszej aplikacji do kopiowania innych treści. | Parsowalne; brak potwierdzonej licencji dla aplikacji. Zachować link/metadane; treści i zdjęcia dopiero po zgodzie. |
| `kwestiasmaku.com` | [Sernik dyniowy](https://www.kwestiasmaku.com/przepis/sernik-dyniowy-nowy): składniki, instrukcje i fotografia. | Stopka strony wprost informuje „Kopiowanie i rozpowszechnianie bez zgody [...] zabronione”. | Parsowalne, lecz pełne scrapowanie/archiwizacja i zdjęcia wymagają zgody; bez zgody tylko link i minimalne metadane. |
| `zdrowe-odzywianie-przepisy.blogspot.com` | [Odmień swoje kanapki – zrób pastę!](https://zdrowe-odzywianie-przepisy.blogspot.com/2014/02/odmien-swoje-kanapki-zrob-paste.html): składniki, instrukcje, wartości żywieniowe; strona ma również obrazy. | Nie odnaleziono jawnej licencji ani warunków przyznających prawa do dalszego użycia; brak widocznej zgody nie jest licencją. `robots.txt` wymaga ponownej kontroli bezpośredniej. | Parsowalne, ale utrwalanie/wyświetlanie skopiowanej treści i zdjęć wymaga zgody lub potwierdzonej podstawy prawnej; do tego czasu tylko link/metadane. |

## Decyzje przyjęte w rozmowie o API (13 listopada 2026)

| ID | Status / właściciel | Decyzja i konsekwencje |
| --- | --- | --- |
| ADR-013 | Przyjęta / właściciel projektu | Serwer normalizuje i waliduje dane narzędzia LLM do stałego JSON. Braki pozostają `null`. Wyniki częściowe mają ostrzeżenia, brak trafień różni się od awarii. Odświeżanie zachowuje dane, lokalny zapis od razu zmienia widok z oznaczeniem oczekiwania na synchronizację, a błąd nie kasuje formularza. |
| ADR-106 — sesje | Przyjęta w tym zakresie / właściciel projektu | Brak automatycznego wylogowania po upływie czasu. Token dostępu odnawia się automatycznie, bez stałego limitu sesji 7/30 dni. Utrata sieci nie wylogowuje. Ręczne wylogowanie i odwołanie sesji pozostają obsługiwane. Kwestie rejestracji i łączenia kont poniżej pozostają otwarte. |
| ADR-108 | Przyjęta / właściciel projektu | CRUD profilu, planu i dziennika offline, trwała kolejka operacji i synchronizacja po odzyskaniu sieci. Cache obejmuje również ostatnie wyniki i otwarte przepisy. Konflikt rozstrzyga użytkownik; pozostałe niezależne operacje są wysyłane dalej. Niewysłanych zmian nie kasujemy bez wyboru przy wylogowaniu. |
| ADR-112 | Przyjęta — zasady kontraktu / właściciel projektu | REST/JSON `/v1`, stałe DTO i wspólny format błędów. Wyszukiwanie: `202 + search_id`, odpytywanie co 2 s przez pierwsze 20 s, potem co 5 s; limit zadania 5 minut. Wyjście z ekranu nie anuluje; anulowanie wymaga potwierdzenia serwera. Historia zakończonych zadań: 30 dni. Mutacje są idempotentne i kontrolują wersję; 3 próby łącznie, odstępy 2 i 5 s. OpenAPI i testy zgodności pozostają produktami T-05. |

- **Porównane warianty:** stały lub zależny od LLM JSON, odrzucanie niepełnych przepisów, jedno długie żądanie lub zadanie asynchroniczne, różne zasady anulowania, limity 1/3/5 minut, sesja 7/30 dni lub bez automatycznego wylogowania, offline tylko do odczytu lub także do zapisu, ręczne i automatyczne rozstrzyganie konfliktów, ponowienia samych odczytów lub także zabezpieczonych zapisów, różne okresy retencji zadań.
- **Podstawa i dowód:** odpowiedzi właściciela zapisane w [ustaleniach](ustalenia-api-i-stany.md). Są dowodem decyzji produktowych, a nie próbą techniczną. Nie wykonano jeszcze pomiaru czasu ani implementacji synchronizacji.
- **Retencja lokalna:** profil i pobrane wpisy pozostają do wylogowania. Podręczne przepisy i wyniki można usuwać po 30 dniach, jeśli nie są potrzebne do wpisów lub operacji. Nie zmienia to zasad źródeł ani retencji danych rzeczywistych z ADR-111.
- **Zadania następcze:** T-04 utrwala sesje i synchronizację, T-05 dostarcza schematy i OpenAPI, T-08/T-11 sesję klient–serwer, T-10 stany widoków, T-17 zadania wyszukiwania, T-23 bazę lokalną i kolejkę. Aktualizacji wymagają plany testów; ich przypadki nadal mają status planowany.
- **Termin przeglądu:** przy pierwszym działającym przepływie klient–serwer, po pomiarach i przed odbiorem MVP; ponownie po zmianie zasad synchronizacji lub kontraktu.

## ADR-014 — najpierw model danych, następnie OpenAPI

- **Status / data / właściciel:** przyjęta / 16 listopada 2026 / właściciel projektu.
- **Problem:** zbyt wczesne doprecyzowanie formatów HTTP może utrwalić nieprzejrzane relacje i braki modelu domenowego. Potrzebny jest najpierw wspólny opis danych aplikacji.
- **Warianty:** równoległe rozpisywanie modelu i szczegółowego OpenAPI albo wstępny model z przeglądem przed specyfikacją transportu.
- **Decyzja i podstawa:** zgodnie ze wskazaniem właściciela najpierw opracowujemy model danych przynajmniej w wersji wstępnej, a następnie formaty komunikacji i OpenAPI. Przyjęte 13 listopada reguły zachowania aplikacji pozostają podstawą modelu.
- **Produkt:** [model v0.1](model-danych.md): encje i obiekty wartości, typy, relacje, własność danych, historia szacunków, odrębne migawki planu/dziennika oraz kolejka i znaczniki usunięcia dla offline.
- **Konsekwencje:** T-05 ma następujące etapy: model → przegląd → mapowanie na bazę i klasy domenowe → DTO/kontrakt → OpenAPI. Wstępny model nie wymaga wyboru konkretnego API żywieniowego, ORM ani uruchomienia serwera. Szczegóły fizyczne oraz kontrakt mogą później rozwijać model iteracyjnie.
- **Dowód i ograniczenia:** polecenie właściciela i przygotowany dokument. v0.1 jest propozycją do przeglądu; nie oznacza zatwierdzenia wszystkich nowych pól i stanów technicznych, wykonania migracji ani zaliczenia testów bazy.
- **Termin przeglądu:** przed utrwaleniem schematu bazy i przygotowaniem maszynowego OpenAPI.

## ADR-015 — kontrakt v0.1.0 na podstawie modelu v0.1

- **Status / data / właściciel:** przyjęta / 16 listopada 2026 / właściciel projektu.
- **Podstawa:** po przygotowaniu modelu właściciel polecił przejść do kontraktu. To upoważnia do doprecyzowania komunikacji na tej podstawie, bez oczekiwania na fizyczną migrację bazy.
- **Produkt:** [OpenAPI 3.1.0, kontrakt v0.1.0](api/openapi.json), [opis reguł](kontrakt-api.md), przykłady i [walidacja](api/README.md).
- **Warianty i decyzje techniczne:** osobne DTO od encji bazy, `version` w PATCH i query DELETE, UUID operacji w `Idempotency-Key`, minimalne potwierdzenie zastosowania operacji, pełna migawka/przyrost zmian z kursorem i znacznikami usunięcia. Stronicowanie samych widoków dnia nie wystarcza do pewnego wykrywania usunięć na innych urządzeniach.
- **Doprecyzowanie modelu:** `AccountChange` utrwala porządek zmian konta, a osobny token odwołania sesji umożliwia odwołanie po wylogowaniu offline bez zachowywania tokenu logowania. Wpis dziennika ma własną nazwę. Dopasowanie produktu tworzy szacunek, natomiast zmiana ilości składnika tworzy wersję przepisu.
- **Zakres i ograniczenia:** serwerowe OCR jest opcjonalne i ogłaszane przez capabilities; wybór OCR i dostawców nie jest zamknięty. Polityki konta/retencji nadal wymagają odpowiednich ADR. Nie utworzono backendu ani nie dowiedziono jego transakcji/autoryzacji.
- **Dowód:** walidacja standardu, definicji, odwołań, przykładów i przypadków formatów danych. Przyszłe testy implementacji muszą wykazać opisane gwarancje.
- **Termin przeglądu:** przy implementacji pierwszego przepływu klient–serwer i każdej zmianie schematu danych.

## Decyzje otwarte przed implementacją odpowiednich etapów

| ID | Pytanie i moment rozstrzygnięcia | Warianty do porównania | Kryteria i dowód wymagany do zamknięcia |
| --- | --- | --- | --- |
| ADR-101 | Wersje Pythona/FastAPI, układ katalogów backendu, ASGI, konfiguracja i sposób uruchamiania usługi — przed pierwszym endpointem | Wspierane wersje Pythona/FastAPI; proces lokalny lub kontenery | Minimalny endpoint z walidacją i testem; czysty start w docelowym on-premise środowisku oraz CI; konfiguracja bez sekretów. |
| ADR-102 | Wersja PostgreSQL, narzędzie migracji, backup i odtworzenie — przed CRUD profilu | Wspierane wersje PostgreSQL i narzędzia migracji | Próba relacji profil–plan–dziennik, migracja na pustej bazie i aktualizacja, kopia i odtworzenie w on-premise środowisku. |
| ADR-103 | Konkretna podstawa prawna retencji niezbędnych pól ekstrakcji, limity pobierania i automatyzacja wyszukiwania — przed produkcyjnym RF-M05 | Licencja/zgoda, zgodne wykorzystanie linkowanych metadanych, ręcznie ograniczony indeks, wyłączenie źródła | Udokumentowana zgoda/licencja lub potwierdzona podstawa, przegląd robots.txt/warunków, limity i retencja; bez tego źródło nie jest indeksowane w produkcji. |
| ADR-104 | Dostawca zewnętrznych danych żywieniowych — przed RF-M10 | Publiczne API/bazy spełniające licencję i wymagane pola | Test pokrycia polskich produktów, jednostek i makro, liczba niejednoznacznych trafień, limit, cena, prawo do cache. |
| ADR-105 | Zasady przeliczania i zaokrąglania — przed kalkulatorem RF-M11 | Tabele konwersji jednostek, masa surowa/gotowa, sposób obsługi strat | Zestaw referencyjnych przykładów policzonych ręcznie, jawne źródła przeliczników i reguła częściowych wyników. |
| ADR-106 — konto | Rejestracja i powiązanie tożsamości — przed RF-M01; polityka trwałej sesji przyjęta powyżej | Polityka hasła i weryfikacji email, jawne łączenie Google z kontem hasłowym | Test rejestracji, izolacji kont i powiązania tożsamości. Implementacja sesji musi dodatkowo wykazać automatyczne odnowienie, odwołanie oraz bezpieczne przechowywanie tokenu. |
| ADR-107 | Miejsce OCR i los zdjęcia — przed RF-M18 | OCR na urządzeniu lub serwerze; brak zapisu obrazu albo ograniczona retencja | Próba na polskich etykietach, jakość odczytu, koszt, prywatność, praca offline i uprawnienia aparatu. |
| ADR-109 | Słownik alergenów i niepewność — przed rankingiem RF-M14 | Reguły jawnych składników oraz ich synonimów, manualna weryfikacja | Zestaw przypadków z alergenami ukrytymi i brakami składu; zero fałszywych deklaracji „bezpieczne” na próbce. |
| ADR-110 | Budżety wydajności i zasobów — przed stabilizacją MVP | Progi czasu, transferu, pamięci, baterii i kosztu wywołań | Pomiar na urządzeniu docelowym i typowym połączeniu; limit zaakceptowany przez zespół. |
| ADR-111 | Retencja i prywatność — przed zapisem danych rzeczywistych | Okresy dla profili, dzienników, zdjęć, cache i logów | Mapa danych, przepływ do dostawców, procedura usunięcia i kopii zapasowej, tekst informacji dla użytkownika. |

## Kolejność rozstrzygnięć

Zgodnie z ADR-014 pierwszym krokiem T-05 jest model danych v0.1 i jego przegląd; dopiero potem doprecyzowanie formatów API i OpenAPI. Równolegle można dopracować środowisko ADR-101–102 i pozostałe kwestie konta z ADR-106. Przyjętych zasad zachowania sieci, wyszukiwania i offline nie trzeba wybierać ponownie. Dla przepisów ADR-012 wskazuje AniaGotuje.pl, a ADR-103 nadal dotyczy produkcyjnego użycia źródła. ADR-104–105 odblokowują rachunek, ADR-109 oznaczenie zgodności, ADR-107 aparat. ADR-108 wymaga realizacji lokalnej bazy, kolejki i testów konfliktów. ADR-110–111 wymagają pomiarów oraz pełnych zasad przed odbiorem MVP. Każdy wybór dostawcy trafia także do [integracji zewnętrznych](integracje-zewnetrzne.md).
