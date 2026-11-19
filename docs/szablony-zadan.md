# Szablony zadań Miary

Zadania w [backlogu MVP](backlog-mvp.md) używają stabilnych ID `T-01` itd. Przy przeniesieniu do GitHub Issues zachować ID w tytule. Jeden problem lub rezultat powinien mieć jednego właściciela odbioru; większe zadanie można rozbić na podzadania `T-xx.1`, zachowując powiązanie z RF. Nie usuwać pól „Testy” i „Dowody” nawet przy zadaniach dokumentacyjnych.

## 1. Funkcja użytkownika

```md
# [T-XX] Krótki rezultat widoczny dla użytkownika

Typ: funkcja | Priorytet: P0/P1/P2 | Iteracja: N | Status: do zrobienia/w toku/do przeglądu/zrobione
Wymagania: RF-Mxx, PU-Mxx | Zależności: T-yy | Właściciel: ...

## Kontekst i cel
Jako [aktor] chcę [czynność], aby [wartość].
Stan wyjściowy i ograniczenia: ...

## Zakres
- Zachowanie w głównej ścieżce: ...
- Stany puste, ładowania, błędu i braku danych: ...
- Poza zakresem tego zadania: ...

## Produkt pracy
- Ekran/endpoint/model/migracja/dokument: ...

## Kryteria akceptacji
1. Gdy [stan], po [akcji] otrzymuję [obserwowalny wynik].
2. Gdy [błąd lub niepełne dane], aplikacja [konkretny wynik].
3. Dane innego konta są niedostępne, jeśli zadanie dotyka danych konta.

## Testy i dowody
- Jednostkowe: [reguły i wartości brzegowe].
- Integracyjne: [granica klient–API/baza/adapter].
- Ręczne: [urządzenie lub środowisko, kroki i oczekiwany wynik].
- Dowód w PR: [nazwa testu, wynik CI, zrzut ekranu lub odpowiedź API bez danych prywatnych].

## Checklisty
- [ ] Zależności i decyzje zamknięte
- [ ] Implementacja i testy
- [ ] Komunikaty błędów i dostępność
- [ ] Kontrakt i dokumentacja zaktualizowane
- [ ] Przegląd kodu i zielone CI
```

## 2. Zadanie techniczne lub integracyjne

```md
# [T-XX] Konkretny komponent lub kontrakt

Typ: techniczne/integracja | Priorytet: P0/P1/P2 | Iteracja: N
Wymagania: RF-Mxx lub wymaganie zaliczeniowe | Zależności: T-yy

## Problem i granica odpowiedzialności
Co komponent przyjmuje, co zwraca i za co nie odpowiada: ...

## Kontrakt
- Wejście, wyjście, jednostki, identyfikatory i wersjonowanie: ...
- Błędy, timeout, ponowienie, limity i brak danych: ...
- Wymagania prywatności i logowania: ...

## Produkt pracy
- Kod, migracja, konfiguracja przykładowa, ADR, dokument API: ...

## Kryteria akceptacji
1. [Obserwowalny przypadek poprawny].
2. [Przypadek brzegowy i wynik].
3. [Niedostępna zależność i wynik].

## Testy i dowody
- Unit: ...
- Integracja/kontrakt: ...
- Sposób uruchomienia lokalnie i w CI: ...
- Dowód: ...

## Checklisty
- [ ] Brak sekretów w kodzie i logach
- [ ] Walidacja wejścia i jawne błędy
- [ ] Testy deterministyczne
- [ ] Kontrakt i instrukcja aktualne
```

## 3. Zadanie badawcze i decyzja (spike/ADR)

Stosować do T-01–T-04 i nowych niezamkniętych decyzji. Celem jest **decyzja z dowodami**, nie sama lista linków.

```md
# [T-XX] Wybór [obszar]

Typ: decyzja | Bramka: Gx | Termin decyzji: przed T-yy

## Pytanie
Jaka decyzja jest potrzebna i jakie zadania blokuje?

## Warianty
| Wariant | Zgodność z wymaganiami | Koszt/limity | Ryzyko | Dowód |
| --- | --- | --- | --- | --- |
| A | ... | ... | ... | ... |
| B | ... | ... | ... | ... |

## Próba
Dane wejściowe, przebieg, wynik i warunki powtórzenia: ...

## Decyzja
Wybrany wariant, uzasadnienie, konsekwencje, warunki ponownego otwarcia: ...

## Kryteria akceptacji i dowody
- [ ] Warianty sprawdzono na reprezentatywnych próbkach
- [ ] Limity, prawa użycia i koszty opisano tam, gdzie dotyczą
- [ ] ADR zaakceptowano i podlinkowano w zadaniach zależnych
- [ ] Otwarte ryzyka mają właściciela
```

## 4. Zadanie testowe lub odbiorowe

```md
# [T-XX] Weryfikacja [przepływ/granica]

Typ: test/odbiór | Wymagania: RF-Mxx | Zależności: T-yy

## Cel i środowisko
Wersja aplikacji, baza, urządzenie/emulator, stuby lub rzeczywiste usługi: ...

## Przypadki
| ID | Dane i stan początkowy | Kroki | Oczekiwany wynik | Poziom |
| --- | --- | --- | --- | --- |
| TC-... | ... | ... | ... | unit/integration/manual |

## Kryterium zakończenia
Wymienione przypadki przechodzą; porażki mają issue i decyzję o wydaniu.

## Dowody
Log CI, raport testów, zapis odpowiedzi API bez sekretów, zrzut ekranu: ...

## Checklisty
- [ ] Testy powtarzalne i niezależne
- [ ] Obejmuje sukces, błąd i granice danych
- [ ] Wymagania mają dowód
- [ ] Wynik i ewentualne defekty zapisane
```

## 5. Defekt

```md
# [BUG] Krótki opis obserwowanego błędu

Priorytet: P0/P1/P2 | Wymaganie: RF-Mxx | Wersja/środowisko: ...

## Kroki odtworzenia
1. ...
2. ...

Oczekiwane: ...
Rzeczywiste: ...
Dane testowe bez danych osobowych: ...
Wpływ i częstotliwość: ...

## Warunek zamknięcia
- [ ] Przyczyna poprawiona
- [ ] Dodano test regresyjny, jeżeli błąd można odtworzyć automatycznie
- [ ] Potwierdzono scenariusz na wskazanym środowisku
- [ ] Sprawdzono powiązane RF i przypadki użycia
```

## 6. Zasady priorytetu i statusów

`P0` oznacza zadanie blokujące przepływ MVP, bezpieczeństwo danych lub wymóg zaliczenia. `P1` oznacza wymagany element, który nie blokuje równoległej pracy. `P2` oznacza ulepszenie po MVP. Każde RF-M01–RF-M21 musi znaleźć się w P0/P1 przed odbiorem; przeniesienie go do P2 oznacza jawne zmniejszenie zakresu MVP i wymaga zmiany planu.

Status „zrobione” jest dozwolony dopiero po przejściu kryteriów, testów i Definition of Done z [planu wytwarzania](plan-wytwarzania.md). Samo zakończenie kodowania oznacza co najwyżej „do przeglądu”.
