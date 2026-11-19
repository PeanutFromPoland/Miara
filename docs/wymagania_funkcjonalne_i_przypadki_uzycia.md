# Wymagania funkcjonalne i przypadki użycia — osobisty dietetyk AI

## 1. Cel i zakres

Dokument rozwija [wymagania projektu](wymagania.md). Aplikacja mobilna pomaga użytkownikowi planować posiłki zgodnie z celami żywieniowymi, preferencjami i ograniczeniami. Agent AI wyszukuje ogólnodostępne przepisy w sieci, dobiera dania i składniki oraz szacuje energię i makroskładniki na podstawie ilości składników i danych z zewnętrznej bazy żywieniowej. Użytkownik może ułożyć plan i zapisać faktycznie zjedzone posiłki.

Pozyskanie przepisów nie może wymagać płatnego planu API z przepisami. Wynik zależy od dostępności stron i jakości danych źródłowych; aplikacja pokazuje źródła oraz nie przedstawia szacunków jako pomiarów laboratoryjnych. Nie stawia diagnoz ani nie zastępuje porady dietetyka lub lekarza.

- **MVP** — funkcje konieczne w pierwszej działającej wersji.
- **Rozwój** — funkcje planowane po MVP.

## 2. Aktorzy i pojęcia

| Aktor lub komponent | Rola |
| --- | --- |
| Użytkownik | Określa cele, przegląda propozycje, układa plan i prowadzi dziennik posiłków. |
| Operator serwera | Wybiera dostawcę modelu AI podczas inicjalizacji serwera i podaje jego konfigurację. |
| Agent AI | Wyszukuje przepisy, porządkuje ich dane, dopasowuje składniki i wyjaśnia propozycje. |
| OpenAI API lub LM Studio | Wybrany dostawca modelu wykonuje zadania agenta AI wymagające modelu językowego. |
| Publiczne strony z przepisami | Dostarczają przepisów dostępnych bez płatnego planu API. |
| Zewnętrzna baza żywieniowa/API | Dostarcza wartości odżywczych produktów użytych w obliczeniach. |
| System operacyjny telefonu | Udostępnia aparat do odczytu etykiet produktów. |
| Własny serwer i baza danych | Przechowują konta, profile, plany i dzienniki oraz wykonują operacje CRUD. |
| Google | Opcjonalny dostawca logowania. |

**Profil żywieniowy** obejmuje cele dzienne, preferencje, wykluczenia i alergeny zadeklarowane przez użytkownika. **Przepis źródłowy** to dane odczytane ze strony wraz z adresem i datą odczytu. **Wartości szacowane** wynikają z przeliczenia ilości składników według danych przypisanych do produktów. **Plan posiłków** oznacza zamiar jedzenia; **dziennik** przechowuje to, co użytkownik potwierdził jako zjedzone. Te zbiory są rozdzielone.

**Dostawca modelu AI** oznacza miejsce przetwarzania zadań agenta wymagających modelu językowego: OpenAI API albo LM Studio. Nie zmienia źródła danych żywieniowych ani zasad wyliczania kcal i makroskładników.

## 3. Wymagania funkcjonalne — MVP

### 3.1. Konto i profil

| ID | Wymaganie | Kryterium spełnienia |
| --- | --- | --- |
| RF-M01 | Użytkownik może założyć konto i zalogować się hasłem albo przez Google. | Po poprawnym logowaniu widzi tylko własne dane; nieudane logowanie nie udostępnia profilu. |
| RF-M02 | Serwer uwierzytelnia żądania tokenem sesji; dostęp odnawia się automatycznie bez wymuszonego wylogowania po czasie, a użytkownik może wylogować się ręcznie. | Żądanie bez ważnego tokenu jest odrzucane, ale jego zwykłe wygaśnięcie uruchamia odnowienie. Brak sieci nie wylogowuje. Ręczne wylogowanie usuwa tokeny i dane konta; przy niewysłanych zmianach najpierw wymaga wyboru synchronizacji, powrotu lub ich usunięcia. |
| RF-M03 | Użytkownik może utworzyć, odczytać, edytować i usunąć profil żywieniowy. | Profil przechowuje co najmniej dzienny cel kcal, opcjonalne cele białka, węglowodanów i tłuszczu, liczbę posiłków, preferencje, produkty wykluczone i zadeklarowane alergeny; zmiany są trwałe. |
| RF-M04 | Użytkownik może określić kryteria wyszukiwania niezależnie od profilu. | Może podać nazwę dania, maksymalny czas, liczbę składników oraz zakres kcal i makroskładników na porcję; niewypełnione kryteria nie ograniczają wyników. |

### 3.2. Wyszukiwanie i przygotowanie przepisów

| ID | Wymaganie | Kryterium spełnienia |
| --- | --- | --- |
| RF-M05 | Agent wyszukuje publicznie dostępne strony z przepisami według kryteriów użytkownika. | Propozycje pochodzą ze stron dostępnych bez płatnej subskrypcji; agent usuwa duplikaty i dla każdej propozycji zachowuje tytuł, adres źródła i datę odczytu. |
| RF-M06 | Agent wyodrębnia z przepisu liczbę porcji, składniki, ilości, jednostki i dostępne informacje o czasie wykonania. | Brakujące lub niejednoznaczne pola są oznaczone; agent nie wymyśla ilości i nie traktuje braków jako wartości zerowych. |
| RF-M07 | Agent normalizuje nazwy składników i jednostki do postaci potrzebnej do obliczeń. | Konwersja do gramów lub mililitrów ma jawną podstawę; składnik bez określonej ilości pozostaje nieoszacowany, dopóki użytkownik go nie uzupełni. |
| RF-M08 | Agent może zaproponować zamianę lub zmianę ilości składnika zgodną z preferencjami użytkownika. | Propozycja wskazuje, co zmieniono; wartości odżywcze nowej wersji są przeliczane, a użytkownik zatwierdza ją przed dodaniem do planu. |
| RF-M09 | Aplikacja pokazuje przepis wraz z odnośnikiem do strony źródłowej i oznacza zmiany zaproponowane przez agenta. | Użytkownik może przejść do źródła; aplikacja nie przedstawia przerobionej wersji jako oryginału ani nie kopiuje całej treści strony bez podstawy do jej użycia. |

### 3.3. Szacowanie wartości i dobór posiłków

| ID | Wymaganie | Kryterium spełnienia |
| --- | --- | --- |
| RF-M10 | Aplikacja pobiera z zewnętrznej bazy żywieniowej/API dane produktów dopasowanych do składników przepisu. | Dla każdego dopasowania można wskazać produkt, źródło danych, jednostkę odniesienia i ilość; niejednoznaczne dopasowanie wymaga poprawki lub jest oznaczone jako niepewne. |
| RF-M11 | Aplikacja szacuje kcal, białko, węglowodany i tłuszcz dla całego przepisu oraz jednej porcji. | Wyliczenie sumuje wartości składników po przeliczeniu ich ilości i dzieli przez liczbę porcji; zmiana ilości lub liczby porcji aktualizuje wynik. |
| RF-M12 | Aplikacja pokazuje kompletność szacunku i pochodzenie danych. | Wskazuje składniki pominięte z braku ilości lub danych, datę pozyskania danych i oznaczenie „szacunek”; nie pokazuje niepełnej sumy jako pełnej wartości przepisu. |
| RF-M13 | Agent porządkuje propozycje względem celów, preferencji i kryteriów użytkownika oraz wyjaśnia kolejność. | Przy propozycji widoczne są użyte kryteria, wartości na porcję i niespełnione lub nieweryfikowalne warunki. |
| RF-M14 | Agent uwzględnia zadeklarowane alergeny i wykluczone produkty. | Rozpoznany wykluczony składnik eliminuje przepis z wyników zgodnych; przy niepełnym składzie lub niepewnej informacji o alergenach propozycja nie jest oznaczana jako bezpieczna ani zgodna. |
| RF-M15 | Aplikacja obsługuje brak dostępu do strony, bazy żywieniowej albo brak wyników. | Pokazuje przyczynę ograniczenia i pozwala zmienić zapytanie lub uzupełnić dane; nie prezentuje fikcyjnego przepisu ani wyliczenia. |

### 3.4. Plan, dziennik i aparat

| ID | Wymaganie | Kryterium spełnienia |
| --- | --- | --- |
| RF-M16 | Użytkownik może dodać wybrany przepis i liczbę porcji do dziennego planu oraz zmienić lub usunąć wpis. | Plan jest trwały; suma planowanych kcal i makroskładników oraz odniesienie do celów aktualizują się po zmianie. |
| RF-M17 | Użytkownik może zapisać, poprawić i usunąć faktycznie zjedzony posiłek w dzienniku. | Wpis może powstać z planu lub ręcznie; suma spożycia jest liczona wyłącznie z wpisów dziennika. |
| RF-M18 | Użytkownik może sfotografować tabelę wartości odżywczych produktu i odczytać ją metodą OCR na potrzeby wpisu do dziennika. | Przed zapisem widzi i może poprawić odczytane wartości, jednostkę odniesienia i ilość; błędny odczyt nie jest zapisywany automatycznie. |
| RF-M19 | Własna baza danych trwale przechowuje profile, plany i dzienniki z pełnym CRUD. | Dla każdego zbioru można potwierdzić utworzenie, odczyt, aktualizację i usunięcie danych właściwego konta. |
| RF-M20 | Aplikacja przechowuje dane konta na telefonie, umożliwia lokalny CRUD profilu, planu i dziennika oraz synchronizuje trwałą kolejkę po uruchomieniu i odzyskaniu połączenia. | Offline pokazuje dane z czasem synchronizacji; zmiany są widoczne z oznaczeniem oczekiwania na wysłanie i przetrwają restart. Synchronizacja nie dubluje zapisów; konflikt rozstrzyga użytkownik, a niezależne wpisy wysyłają się dalej. Nowe wyszukiwanie LLM wymaga sieci. Brak cache i awaria mają odrębne stany. |

### 3.5. Inicjalizacja serwera i model AI

| ID | Wymaganie | Kryterium spełnienia |
| --- | --- | --- |
| RF-M21 | Podczas inicjalizacji serwera operator może wybrać miejsce przetwarzania zadań agenta AI: OpenAI API albo LM Studio. | Serwer przyjmuje wybór oraz dane połączenia wymagane przez wybranego dostawcę, sprawdza poprawność konfiguracji i kieruje wywołania modelu do wybranego miejsca. Przy brakującej lub błędnej konfiguracji zgłasza czytelny błąd inicjalizacji; nie przełącza dostawcy samoczynnie. |

## 4. Wymagania funkcjonalne — rozwój

| ID | Wymaganie | Kryterium spełnienia |
| --- | --- | --- |
| RF-R01 | Agent układa plan na kilka dni, uwzględniając różnorodność i cele dzienne. | Pokazuje sumy na każdy dzień i pozwala zamienić posiłek bez automatycznej zmiany dziennika spożycia. |
| RF-R02 | Aplikacja tworzy listę zakupów ze składników zaplanowanych posiłków. | Łączy porównywalne ilości, pozwala edytować i usuwać pozycje; nie zakłada wiedzy o produktach posiadanych przez użytkownika. |
| RF-R03 | Agent może oszacować koszt przepisu na podstawie ogólnodostępnych cen. | Dla każdej ceny pokazuje źródło, datę, walutę, jednostkę i ilość; brak ceny oznacza niepełny szacunek. |
| RF-R04 | Aplikacja może pokazać dodatkowe składniki odżywcze, jeśli dane źródłowe pozwalają na rzetelne przeliczenie. | Cukry, błonnik, tłuszcze nasycone, sód lub sól oraz inne frakcje są wyświetlane tylko wraz ze źródłem i metodą obliczenia; w przeciwnym razie widnieje „brak danych”. |
| RF-R05 | Użytkownik może ocenić przepis i zapisać własne poprawki, aby agent uwzględnił je w przyszłych propozycjach. | Zmiany preferencji wpływają na nowe wyniki i można je usunąć z profilu. |

## 5. Przypadki użycia — MVP

### PU-M01 — Założenie konta i ustawienie profilu

- **Aktor:** użytkownik; pomocniczo Google i własny serwer.
- **Warunek wstępny:** aplikacja jest uruchomiona.
- **Przebieg podstawowy:** 1. Użytkownik tworzy konto lub loguje się. 2. Podaje cel kcal, opcjonalne cele makroskładników, preferencje, wykluczenia i alergeny. 3. Sprawdza dane i zapisuje profil. 4. Serwer zapisuje dane właściwego konta.
- **Warianty:** nieudane logowanie → brak dostępu do danych; brak obowiązkowego celu kcal → wskazanie pola; późniejsza edycja lub usunięcie profilu → zapis zmian.
- **Wynik:** profil gotowy do wykorzystania przez agenta.
- **Wymagania:** RF-M01–RF-M03, RF-M19.

### PU-M02 — Wyszukanie przepisów w sieci

- **Aktor:** użytkownik; pomocniczo agent AI i publiczne strony z przepisami.
- **Warunek wstępny:** użytkownik ma profil i połączenie z siecią.
- **Przebieg podstawowy:** 1. Użytkownik wpisuje danie lub wybiera kryteria. 2. Agent wyszukuje dostępne przepisy. 3. Odczytuje składniki, ilości, porcje i czas oraz usuwa duplikaty wyników. 4. Pokazuje propozycje z odnośnikami do źródeł i brakami danych.
- **Warianty:** brak wyników → zmiana kryteriów; strona niedostępna lub zabrania automatycznego odczytu → pominięcie źródła; brak ilości składnika → oznaczenie niepewności i możliwość poprawki.
- **Wynik:** lista przepisów źródłowych możliwych do oceny względem profilu.
- **Wymagania:** RF-M04–RF-M07, RF-M09, RF-M15.

### PU-M03 — Oszacowanie wartości i wybór posiłku

- **Aktor:** użytkownik; pomocniczo agent AI i zewnętrzna baza żywieniowa/API.
- **Warunek wstępny:** dostępny jest przepis ze składnikami i liczbą porcji.
- **Przebieg podstawowy:** 1. Agent dopasowuje składniki do produktów w bazie żywieniowej. 2. Przelicza ilości i sumuje wartości na porcję. 3. Porównuje wynik z celami i ograniczeniami. 4. Użytkownik ogląda źródła, obliczenia i powody kolejności propozycji. 5. Może zatwierdzić proponowaną zmianę składnika lub ilości.
- **Warianty:** niejednoznaczny produkt → korekta dopasowania; brak danych lub ilości → niepełny szacunek; wykluczony składnik → brak oznaczenia zgodności; niedostępne API → komunikat bez fikcyjnych wartości.
- **Wynik:** użytkownik wybiera przepis, znając ograniczenia oszacowania.
- **Wymagania:** RF-M08, RF-M10–RF-M15.

### PU-M04 — Zaplanowanie posiłków na dzień

- **Aktor:** użytkownik.
- **Warunek wstępny:** wybrano przepis z możliwym do obliczenia szacunkiem.
- **Przebieg podstawowy:** 1. Użytkownik wybiera dzień i liczbę porcji. 2. Dodaje przepis do planu. 3. Aplikacja pokazuje sumę planowanych kcal i makroskładników oraz różnicę względem celów. 4. Użytkownik może zmienić porcję, zamienić posiłek lub usunąć wpis.
- **Warianty:** niepełne dane przepisu → suma jest oznaczona jako niepełna; anulowanie → plan pozostaje bez zmian.
- **Wynik:** zapisany plan dnia.
- **Wymagania:** RF-M11, RF-M12, RF-M16, RF-M19.

### PU-M05 — Zapisanie spożytego posiłku

- **Aktor:** użytkownik.
- **Warunek wstępny:** użytkownik jest zalogowany.
- **Przebieg podstawowy:** 1. Użytkownik wybiera posiłek z planu lub dodaje go ręcznie. 2. Potwierdza faktyczną porcję i wartości. 3. Zapisuje wpis w dzienniku. 4. Aplikacja aktualizuje sumę spożycia, niezależną od sumy planu.
- **Warianty:** posiłku nie zjedzono → brak wpisu; błędna ilość → poprawka przed zapisem; edycja lub usunięcie wpisu → ponowne przeliczenie sumy.
- **Wynik:** dziennik odzwierciedla potwierdzone spożycie.
- **Wymagania:** RF-M17, RF-M19.

### PU-M06 — Odczyt etykiety do dziennika

- **Aktor:** użytkownik; pomocniczo aparat i OCR.
- **Warunek wstępny:** użytkownik chce ręcznie dodać spożyty produkt.
- **Przebieg podstawowy:** 1. Fotografuje tabelę wartości odżywczych. 2. Aplikacja pokazuje odczytane kcal i makroskładniki wraz z jednostką odniesienia. 3. Użytkownik poprawia odczyt, podaje zjedzoną ilość i zatwierdza wpis.
- **Warianty:** brak dostępu do aparatu lub nieczytelna etykieta → ręczne wprowadzenie; brak wartości → pole pozostaje nieznane, a nie zerowe; anulowanie → brak wpisu.
- **Wynik:** potwierdzony produkt trafia do dziennika.
- **Wymagania:** RF-M17–RF-M19.

### PU-M07 — Odczyt danych bez połączenia i wylogowanie

- **Aktor:** użytkownik; pomocniczo własny serwer.
- **Warunek wstępny:** wcześniej zalogowano się na urządzeniu.
- **Przebieg podstawowy:** 1. Aplikacja pokazuje lokalne dane z czasem synchronizacji. 2. Użytkownik może zmieniać profil, plan i dziennik także offline; zmiany trafiają do trwałej kolejki. 3. Po odzyskaniu połączenia aplikacja odnawia dostęp w razie potrzeby i synchronizuje operacje bez duplikatów. 4. Konflikt wymaga wyboru użytkownika. 5. Ręczne wylogowanie usuwa tokeny i dane konta, po rozstrzygnięciu losu niewysłanych zmian.
- **Warianty:** brak sieci → oznaczenie nieaktualności i oczekujących zmian; wygasły token dostępu → automatyczne odnowienie bez wylogowania; odwołana sesja → ponowne logowanie bez cichego kasowania niewysłanych zmian; brak cache → „Brak danych na urządzeniu”; wylogowanie z kolejką → synchronizuj, wróć lub wyloguj z usunięciem zmian.
- **Wynik:** dane konta są dostępne zgodnie ze stanem sesji i połączenia.
- **Wymagania:** RF-M02, RF-M20.

### PU-M08 — Wybór miejsca przetwarzania zadań AI przy uruchomieniu serwera

- **Aktor:** operator serwera; pomocniczo OpenAI API albo LM Studio.
- **Warunek wstępny:** serwer jest przygotowany do inicjalizacji.
- **Przebieg podstawowy:** 1. Operator wybiera OpenAI API albo LM Studio i podaje wymagane dane połączenia. 2. Serwer sprawdza konfigurację. 3. Serwer uruchamia agenta z wybranym dostawcą modelu. 4. Zadania agenta wymagające modelu są kierowane do wybranego miejsca przetwarzania.
- **Warianty:** brak wyboru lub błędne dane połączenia → czytelny błąd inicjalizacji; niedostępność wybranego dostawcy → błąd bez samoczynnego przełączenia na drugiego dostawcę.
- **Wynik:** serwer korzysta z wybranego dostawcy modelu AI.
- **Wymagania:** RF-M21.

## 6. Przypadki użycia — rozwój

### PU-R01 — Ułożenie planu na kilka dni i przygotowanie zakupów

- **Aktor:** użytkownik; pomocniczo agent AI.
- **Warunek wstępny:** zapisano profil i przepisy możliwe do zaplanowania.
- **Przebieg podstawowy:** 1. Użytkownik wskazuje dni. 2. Agent proponuje różnorodne posiłki i sumy dzienne. 3. Użytkownik poprawia plan. 4. Aplikacja tworzy edytowalną listę składników do zakupu.
- **Warianty:** nieznana ilość składnika → pozycja wymaga uzupełnienia; brak danych do porównania jednostek → pozycje pozostają osobno.
- **Wynik:** zapisany plan i lista zakupów wynikająca z wybranych przepisów.
- **Wymagania:** RF-R01, RF-R02.

### PU-R02 — Porównanie kosztów i dodatkowych wartości

- **Aktor:** użytkownik; pomocniczo agent AI i publiczne źródła danych.
- **Warunek wstępny:** istnieją propozycje przepisów.
- **Przebieg podstawowy:** 1. Użytkownik wybiera porównanie kosztu lub dodatkowych składników odżywczych. 2. Agent pobiera dostępne ceny lub dane odżywcze. 3. Pokazuje wynik, źródła, daty i zakres braków.
- **Warianty:** brak porównywalnej ceny lub składnika odżywczego → widoczny brak danych bez zastępowania wymyśloną wartością.
- **Wynik:** użytkownik porównuje wyłącznie wartości o znanej podstawie.
- **Wymagania:** RF-R03, RF-R04.

### PU-R03 — Ocena przepisu i zapamiętanie preferencji

- **Aktor:** użytkownik.
- **Warunek wstępny:** użytkownik otworzył propozycję przepisu.
- **Przebieg podstawowy:** 1. Użytkownik ocenia przepis albo zapisuje własną poprawkę. 2. Aplikacja aktualizuje preferencje konta. 3. Agent uwzględnia tę informację przy kolejnych propozycjach.
- **Warianty:** usunięcie oceny lub poprawki → informacja przestaje wpływać na przyszłe wyniki.
- **Wynik:** propozycje odzwierciedlają zapamiętane wybory użytkownika.
- **Wymagania:** RF-R05.

## 7. Przyjęte ustalenia i decyzje otwarte

### 7.1. Przyjęte ustalenia

1. Główną funkcją aplikacji jest osobisty dietetyk AI: wyszukiwanie przepisów, dobór posiłków, planowanie i dziennik spożycia.
2. Agent przeszukuje publiczne strony zamiast polegać na płatnym planie API z przepisami. Przy automatycznym odczycie respektuje warunki korzystania ze źródeł i ich ograniczenia techniczne; podaje link do przepisu.
3. Wartości odżywcze są szacowane z ilości składników i danych zewnętrznej bazy. Wynik na porcję wymaga znanej liczby porcji. Braki i niepewność pozostają widoczne.
4. Rozpoznany alergen lub wykluczony produkt wyklucza oznaczenie przepisu jako zgodnego. Brak informacji o składzie nie jest potwierdzeniem bezpieczeństwa.
5. Plan i dziennik są odrębne. Zapisanie planu nie oznacza spożycia posiłku.
6. Własny serwer przechowuje dane kont, profili, planów i dzienników. Zewnętrzna baza żywieniowa/API spełnia wymaganie użycia zewnętrznego API; aparat używany do OCR etykiety spełnia wymaganie użycia sensora.
7. Dostawcę modelu AI wybiera operator podczas inicjalizacji serwera: OpenAI API albo LM Studio. Wybór dotyczy zadań agenta wymagających modelu językowego, a nie źródła danych żywieniowych.
8. Własne API zwraca stały JSON po walidacji wyniku narzędzia LLM. Wyszukiwanie jest zadaniem z identyfikatorem, limitem 5 minut i odpytywaniem stanu; wyniki częściowe pozostają dostępne z ostrzeżeniem. Stan zadania i odnośniki do wyników są zachowane przez 30 dni od zakończenia.
9. Sesja nie kończy się automatycznie po czasie. Offline obejmuje odczyt i zmiany profilu, planu i dziennika z trwałą kolejką; konflikty rozstrzyga użytkownik. Szczegóły przyjęto 13 listopada 2026 w [ustaleniach API i stanów klienta](ustalenia-api-i-stany.md).

### 7.2. Decyzje otwarte przed implementacją

1. **Źródła przepisów:** wybrać wyszukiwarkę i zbiór stron dopuszczających automatyczny odczyt, ustalić limity zapytań, sposób obsługi zmian struktury stron i zakres przechowywania treści.
2. **Baza żywieniowa:** wybrać dostępne API, sprawdzić licencję, limity oraz pokrycie polskich produktów i składników.
3. **Obliczenia:** ustalić tabelę przeliczników jednostek i reguły dla składników bez ilości, strat przy obróbce oraz różnic między masą surową a gotową.
4. **Konto i prywatność:** doprecyzować rejestrację, weryfikację email, łączenie tożsamości Google i hasła oraz pełną retencję danych serwera. Trwałość sesji, lokalny cache i wybór użytkownika przy konflikcie są już przyjęte.
5. **Alergeny:** ustalić słownik składników i reguły oznaczania niepewności; automatyczna klasyfikacja nie powinna gwarantować bezpieczeństwa przy alergii.

## 8. Wymagania projektowe poza zakresem funkcjonalnym

[Wymagania zaliczeniowe](wymagania.md) obejmują także testy jednostkowe, repozytorium GitHub, CI/CD, implementację we Flutterze, React Native albo Kotlinie oraz ograniczanie zużycia zasobów. Ich spełnienie należy sprawdzić osobno. Dane profilu i dziennika wymagają ochrony na serwerze i urządzeniu; agent powinien ograniczać liczbę zapytań sieciowych oraz ponownie wykorzystywać aktualne, dozwolone dane źródłowe.
