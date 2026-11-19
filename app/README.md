# Miara — aplikacja Flutter

Klient API opisany w `../docs/kontrakt-api.md`. Backend FastAPI znajduje się w `../server`.

## Uruchomienie na emulatorze Androida

Komendy Fluttera uruchamiaj w katalogu `app`, gdzie znajduje się `pubspec.yaml`:

```powershell
cd app
flutter doctor -v
flutter pub get
flutter emulators
# Jeśli żaden emulator jeszcze nie działa:
flutter emulators --launch Medium_Phone
flutter devices
flutter run -d emulator-5554
```

`Medium_Phone` i `emulator-5554` to identyfikatory na tym komputerze. Jeśli lista
pokazuje inne, użyj ich w poleceniach. W VS Code otwartym na katalogu TeMo
wybierz emulator jako urządzenie i konfigurację **Miara — Flutter**, a następnie F5.

Do sprawdzenia kodu i ekranów:

```powershell
flutter analyze
flutter test
```

### Windows i OneDrive

Gdy projekt znajduje się w OneDrive, Gradle przechowuje pliki robocze Androida
w `%LOCALAPPDATA%\Miara\build\<identyfikator-projektu>`. Zapobiega to błędom
`cleanMergeDebugAssets / Unable to delete directory`, gdy synchronizowane katalogi
otrzymują atrybut `ReadOnly`. Gotowe APK/AAB są kopiowane do `app/build/app/outputs`,
gdzie oczekuje ich Flutter. Zwykłe `flutter run` i uruchamianie przez F5 nadal działają.
Poza OneDrive używany jest standardowy katalog `build`.

## Adres serwera

Adres API podaj przy uruchomieniu lub kompilacji przez `API_BASE_URL`:

```powershell
flutter run --dart-define=API_BASE_URL=https://adres-twojego-serwera
```

Serwer musi być dostępny z urządzenia. Kontrakt wymaga HTTPS.

Przy lokalnym debugowaniu uruchom backend według `../server/README.md`, a potem:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

W emulatorze `10.0.2.2` wskazuje komputer gospodarza; `localhost` wskazuje sam
emulator ([dokumentacja Androida](https://developer.android.com/studio/run/emulator-networking-address)).
Konfiguracja VS Code **Miara — Android + lokalne API** przekazuje ten adres.
Wariant debug dopuszcza HTTP dla `10.0.2.2`, `127.0.0.1` i `localhost`;
wydanie produkcyjne wymaga HTTPS. Sam interfejs uruchomi się bez API, ale
logowanie i wyszukiwanie na serwerze wymagają działającego backendu.

W zakładce **Profil** można zalogować się do API. W zakładce **Odkrywaj** aplikacja tworzy zadanie wyszukiwania, odpytuje jego status i pobiera szczegóły wybranego przepisu. Błędy serwera są pokazywane wraz z kodem żądania, jeśli serwer go zwróci.

`ApiClient` udostępnia również wywołania profilu, planu i dziennika. Te ekrany nadal używają danych demonstracyjnych; synchronizacja CRUD/offline nie jest jeszcze podłączona. Token sesji jest obecnie przechowywany tylko w pamięci procesu.
