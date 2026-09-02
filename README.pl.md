# FS25 New Career Defaults

Niewielki mod skryptowy do **Farming Simulator 25**, który zmienia domyślny kalendarz nowo utworzonej standardowej kariery na **3 dni w miesiącu**, zachowując datę rozpoczęcia **1 sierpnia**.

## Domyślne działanie

Po włączeniu moda podczas tworzenia standardowej nowej kariery:

- kariera nadal rozpoczyna się **1 sierpnia**;
- HUD pokazuje **pierwszy dzień sierpnia**;
- ustawienie **Dni na miesiąc** zostaje od razu zmienione na **3**;
- wartość jest rejestrowana przez standardowy mechanizm ustawień savegame FS25;
- przeliczenie kalendarza wykonywane jest tylko podczas inicjalizacji;
- po inicjalizacji mod **nie wymusza stale** wartości 3 dni i gracz może później normalnie zmienić to ustawienie.

Mod jest przeznaczony do gry **jednoosobowej na PC**.

## Przyjęte założenia

Implementacja celowo zachowuje ostrożne kryteria działania.

### 1. Zmieniany jest tylko standardowy początkowy stan kalendarza FS25

Mod nie zmienia bezwarunkowo każdego savegame, w którym zostanie włączony.

W testach standardowa nowa kariera FS25 w momencie `Mission00.loadMission00Finished` miała następujące wartości:

```text
currentPeriod          = 6
currentDay             = 6
currentDayInPeriod     = 1
daysPerPeriod          = 1
plannedDaysPerPeriod   = 1
currentMonotonicDay    = 6
currentMonth           = nil
```

Przed wykonaniem zmian mod sprawdza istotne, już zainicjalizowane wartości.

`currentMonth` celowo nie bierze udziału w wykrywaniu nowej kariery, ponieważ na tym etapie ładowania FS25 może nadal mieć wartość `nil`. Do określenia sierpnia wystarcza `currentPeriod = 6`.

Dodanie do warunku `currentMonotonicDay = 6` zwiększa bezpieczeństwo: starsza kariera, która po kolejnych latach ponownie trafi na 1 sierpnia, nie zostanie uznana za nową tylko dlatego, że widoczny kalendarz wygląda podobnie.

### 2. Po zmianie długości miesiąca nadal musi być 1 sierpnia

Okresy sezonowe FS25 są numerowane od marca:

| Okres | Miesiąc |
| ---: | --- |
| 1 | marzec |
| 2 | kwiecień |
| 3 | maj |
| 4 | czerwiec |
| 5 | lipiec |
| 6 | sierpień |

Przy `3` dniach na okres pierwszy dzień sierpnia ma więc wartość:

```text
currentDay = (okres - 1) × dniNaOkres + dzieńWOkresie
currentDay = (6 - 1) × 3 + 1
currentDay = 16
```

Mod zmienia:

```text
currentDay:         6 -> 16
currentDayInPeriod: 1 -> 1
```

Wynikiem nadal jest **1 sierpnia**, ale już w kalendarzu z 3 dniami na miesiąc.

### 3. Powinien zostać użyty standardowy mechanizm ustawień FS25

Mod najpierw wywołuje:

```lua
mission:setPlannedDaysPerPeriod(3)
```

Dzięki temu FS25 rejestruje nową wartość jako normalne ustawienie savegame.

Ponieważ gra standardowo traktuje `plannedDaysPerPeriod` jako zmianę planowaną na przyszłość, mod następnie natychmiast synchronizuje odpowiednie wartości środowiska. Jest to wykonywane wyłącznie na nietkniętym początku nowej kariery, zanim rozgrywka zdąży się rozpocząć.

### 4. `timeAdjustment` musi odpowiadać nowej długości okresu

FS25 używa `environment.timeAdjustment` jako współczynnika normalizującego wybraną długość okresu.

Dla trzech dni w miesiącu mod ustawia więc:

```lua
environment.timeAdjustment = 1 / 3
```

### 5. `currentMonotonicDay` nie może być zmieniany

Mod celowo pozostawia bez zmian:

```lua
environment.currentMonotonicDay
```

Wartość ta reprezentuje monotoniczną wewnętrzną oś czasu używaną m.in. przez system pogody. Celem moda jest zmiana sposobu reprezentacji kalendarza sezonowego, a nie przesuwanie wewnętrznego czasu świata gry.

## Jednorazowy znacznik inicjalizacji

Po zainicjalizowaniu kalendarza mod tworzy w savegame plik:

```text
newCareerDefaults.xml
```

Obecność znacznika zapobiega ponownemu wykonaniu inicjalizacji dla tego zapisu.

### Dlaczego plik jest zapisywany podczas zapisu gry

FS25 wykonuje zwykły zapis najpierw do katalogu tymczasowego:

```text
tempsavegame
```

a następnie przenosi gotowy zapis do właściwego katalogu `savegameN`.

Z tego powodu znacznik **nie jest tworzony podczas ładowania misji**. Mod zapisuje go w hooku `FSBaseMission.saveSavegame`, gdy `missionInfo.savegameDirectory` wskazuje właśnie na `tempsavegame`.

Dlatego podczas zapisu w logu może pojawić się ścieżka tymczasowa, natomiast po zakończeniu operacji plik prawidłowo znajduje się np. w:

```text
savegame1/newCareerDefaults.xml
```

Sam plik zawiera jedynie kilka informacyjnych atrybutów. Dla logiki moda istotne jest przede wszystkim jego istnienie.

## Hooki cyklu życia gry

Mod wykorzystuje trzy niewielkie hooki FS25:

| Hook | Zastosowanie |
| --- | --- |
| `Mission00.loadMission00Finished` | Wykrycie standardowej nowej kariery i inicjalizacja kalendarza |
| `FSBaseMission.saveSavegame` | Zapis znacznika w ramach normalnego zapisu gry |
| `FSBaseMission.delete` | Wyczyszczenie stanu tymczasowego przy opuszczaniu kariery |

Flaga oczekującego znacznika jest dodatkowo zerowana przy rozpoczęciu ładowania każdej misji. Zapobiega to sytuacji, w której nowa kariera zostanie utworzona, ale niezapisana, a następnie w tej samej sesji FS25 zostanie otwarty inny savegame.

## Pliki

```text
FS25_NewCareerDefaults/
├── modDesc.xml
├── NewCareerDefaults.lua
├── README.md
└── README.pl.md
```

W archiwum ZIP pliki te muszą znajdować się bezpośrednio w katalogu głównym archiwum.

## Instalacja

1. Skopiuj `FS25_NewCareerDefaults.zip` do katalogu `mods` Farming Simulator 25.
2. Uruchom Farming Simulator 25.
3. Utwórz **nową karierę**.
4. Włącz dla niej mod **New Career Defaults**.
5. Wejdź do gry.
6. W ustawieniach sprawdź, czy **Dni na miesiąc = 3**.
7. Sprawdź, czy HUD nadal pokazuje **pierwszy dzień sierpnia**.
8. Zapisz karierę przynajmniej raz.

Po zapisaniu w odpowiednim katalogu `savegameN` powinien znajdować się plik `newCareerDefaults.xml`.

## Oczekiwane wpisy w logu

Prawidłowa pierwsza inicjalizacja daje zwięzły wpis podobny do:

```text
Info: [FS25_NewCareerDefaults] New career initialized: 3 days/month, starting on August 1.
```

Po pierwszym normalnym zapisie:

```text
Info: [FS25_NewCareerDefaults] Initialization marker saved.
```

Ostrzeżenia są zapisywane tylko wtedy, gdy oczekiwane API FS25 lub ścieżka zapisu są niedostępne.

## Konfiguracja

Domyślna wartość znajduje się na początku pliku `NewCareerDefaults.lua`:

```lua
local DEFAULT_DAYS_PER_PERIOD = 3
```

Przeliczenie `currentDay` oraz wartość `timeAdjustment` są wyliczane automatycznie na podstawie tej liczby.

Po zmianie wartości warto również odpowiednio zmienić tekst opisu w `modDesc.xml` oraz dokumentacji.

## Istniejące savegame

Mod jest przeznaczony do inicjalizowania nowej kariery i nie wykonuje celowej migracji dowolnych istniejących zapisów.

Savegame zawierający `newCareerDefaults.xml` jest zawsze pozostawiany bez zmian.

Finalne wykrywanie wymaga również początkowego `currentMonotonicDay = 6`, dzięki czemu normalna starsza kariera nie zostanie pomylona z nową.

Istnieje jedna ścieżka naprawcza: jeżeli savegame ma dokładnie początkowy stan kalendarza utworzony już przez wcześniejszą wersję moda, ale nie ma pliku znacznika, kalendarz nie jest ponownie zmieniany. Przy następnym zapisie zostanie jedynie odtworzony `newCareerDefaults.xml`.

## Usunięcie moda

Po wykonaniu pierwszego zapisu FS25 sam przechowuje wybraną wartość `plannedDaysPerPeriod`. Usunięcie moda nie wymaga przywracania kalendarza do jednego dnia na miesiąc.

Plik `newCareerDefaults.xml` jest bez moda całkowicie nieaktywny. Można go pozostawić w savegame albo ręcznie usunąć po trwałym usunięciu moda.

## Uwagi dotyczące zgodności

- Farming Simulator 25
- mod skryptowy na PC
- przeznaczony do gry jednoosobowej
- nie wymaga specjalizacji pojazdów
- nie zawiera kodu zależnego od mapy
- nie zależy od `environment.currentMonth`
- nie zmienia `currentMonotonicDay`

## Historia zmian

### 1.0.0.4 — wersja finalna

- Oczyszczono i uporządkowano kod źródłowy.
- Dodano wyczerpujące komentarze opisujące model kalendarza FS25 i przyjęte hooki cyklu życia.
- Dodano `currentMonotonicDay = 6` do sygnatury standardowej nowej kariery, ograniczając ryzyko fałszywego rozpoznania starego savegame.
- Flaga tymczasowa `markerPending` jest zerowana przy każdym ładowaniu misji.
- Dodano zerowanie stanu przy `FSBaseMission.delete`, dzięki czemu niezapisana kariera nie może pozostawić oczekującego znacznika dla innego savegame w tej samej sesji gry.
- Ograniczono diagnostyczne wpisy logu do zwięzłych komunikatów produkcyjnych i ostrzeżeń.
- Dodano pełną dokumentację angielską i polską.

### 1.0.0.3 — poprawka trwałości znacznika

- Przeniesiono tworzenie znacznika z etapu ładowania misji do `FSBaseMission.saveSavegame`.
- Znacznik jest prawidłowo tworzony w `tempsavegame`, a następnie przenoszony przez FS25 do końcowego `savegameN`.
- Dodano obsługę zapisów już zainicjalizowanych przez wcześniejszą wersję testową, ale pozbawionych znacznika.
- W grze potwierdzono fizyczną obecność pliku w końcowym katalogu savegame.

### 1.0.0.2 — poprawka wykrywania kalendarza

- Usunięto `environment.currentMonth` z kryterium nowej kariery po stwierdzeniu w testach, że w `Mission00.loadMission00Finished` ma jeszcze wartość `nil`.
- Do identyfikacji wykorzystano `currentPeriod = 6` oraz pozostałe dostępne wartości kalendarza.
- W grze potwierdzono:
  - `3` dni na miesiąc w ustawieniach;
  - zachowanie 1 sierpnia w HUD;
  - `currentDay = 16`;
  - `timeAdjustment = 1/3`;
  - brak zmiany `currentMonotonicDay`.

### 1.0.0.1 — wersja diagnostyczna cyklu życia

- Zastąpiono pierwotne podejście z listenerem bezpośrednim hookiem `Mission00.loadMission00Finished`.
- Dodano szczegółowe logowanie pozwalające poznać faktyczny początkowy stan kalendarza FS25.

### 1.0.0.0 — pierwszy prototyp

- Pierwsza implementacja automatycznego ustawienia 3 dni na miesiąc dla nowej kariery FS25.
- Pierwsza wersja przeliczenia kalendarza i koncepcji znacznika.
