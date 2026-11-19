import 'package:flutter/material.dart';

import 'api/api_client.dart';

const _paper = Color(0xFFF4EEE5);
const _paperBright = Color(0xFFFFFAF2);
const _ink = Color(0xFF2A2031);
const _muted = Color(0xFF706778);
const _orange = Color(0xFFFA6947);
const _yellow = Color(0xFFFFD859);
const _lilac = Color(0xFFD9C6E9);
const _line = Color(0xFFCFC2BB);

void main() => runApp(const MiaraApp());

class MiaraApp extends StatelessWidget {
  const MiaraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Miara',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(seedColor: _orange),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: _orange,
        selectionHandleColor: _orange,
      ),
    ),
    home: const _MiaraHome(),
  );
}

class _Recipe {
  const _Recipe({
    required this.name,
    required this.type,
    required this.art,
    required this.minutes,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    this.allergens = const [],
  });

  final String name;
  final String type;
  final _FoodArt art;
  final int minutes;
  final int kcal;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> ingredients;
  final List<String> allergens;
}

const _recipes = [
  _Recipe(
    name: 'Owsianka z malinami',
    type: 'Śniadanie',
    art: _FoodArt.oats,
    minutes: 12,
    kcal: 420,
    protein: 18,
    carbs: 56,
    fat: 13,
    ingredients: [
      'Płatki owsiane — 60 g',
      'Jogurt naturalny — 150 g',
      'Maliny — 80 g',
      'Nasiona chia — 10 g',
    ],
    allergens: ['mleko', 'gluten'],
  ),
  _Recipe(
    name: 'Bowl z tofu i ryżem',
    type: 'Obiad',
    art: _FoodArt.bowl,
    minutes: 25,
    kcal: 610,
    protein: 32,
    carbs: 72,
    fat: 21,
    ingredients: [
      'Tofu naturalne — 150 g',
      'Ryż — 80 g (suchy)',
      'Brokuł — 120 g',
      'Marchew — 80 g',
      'Oliwa — 10 g',
    ],
    allergens: ['soja'],
  ),
  _Recipe(
    name: 'Makaron z pomidorami',
    type: 'Obiad',
    art: _FoodArt.pasta,
    minutes: 20,
    kcal: 540,
    protein: 21,
    carbs: 73,
    fat: 17,
    ingredients: [
      'Makaron pełnoziarnisty — 80 g (suchy)',
      'Pomidory — 200 g',
      'Mozzarella — 60 g',
      'Oliwa — 8 g',
    ],
    allergens: ['gluten', 'mleko'],
  ),
  _Recipe(
    name: 'Sałatka z ciecierzycą',
    type: 'Kolacja',
    art: _FoodArt.salad,
    minutes: 15,
    kcal: 465,
    protein: 20,
    carbs: 48,
    fat: 19,
    ingredients: [
      'Ciecierzyca — 150 g',
      'Pomidor — 120 g',
      'Ogórek — 100 g',
      'Oliwa — 10 g',
      'Sok z cytryny — 10 ml',
    ],
  ),
];

class _MiaraHome extends StatefulWidget {
  const _MiaraHome();

  @override
  State<_MiaraHome> createState() => _MiaraHomeState();
}

class _MiaraHomeState extends State<_MiaraHome> {
  final ApiClient _api = ApiClient();
  int _tab = 0;
  int? _detailRecipe;
  String _filter = 'Wszystkie';
  String _query = '';
  int _target = 2000;
  final _queryController = TextEditingController();
  final _targetController = TextEditingController(text: '2000');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Set<String> _allergens = {};
  final List<int> _plan = [0, 1];
  final List<int> _diary = [0];
  List<RecipeSearchResult> _serverResults = [];
  List<String> _serverWarnings = [];
  String? _searchId;
  String? _searchOperationId;
  String? _searchOperationFingerprint;
  String? _cancelOperationId;
  String _serverStatus = 'Wyszukaj przepisy na serwerze';
  String? _serverError;
  bool _searchBusy = false;
  bool _showingPreviousResults = false;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _queryController.dispose();
    _targetController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _api.close();
    super.dispose();
  }

  int _total(List<int> entries, int Function(_Recipe) field) =>
      entries.fold(0, (sum, id) => sum + field(_recipes[id]));

  void _goTo(int tab) {
    setState(() {
      _detailRecipe = null;
      _tab = tab;
    });
    if (tab == 1 && _searchId != null && _searchBusy) {
      _pollSearch(_searchId!, ++_searchGeneration);
    }
  }

  Future<void> _searchOnServer(String value) async {
    _query = value.trim();
    if (_query.isEmpty) {
      setState(() {
        _serverError = 'Wpisz nazwę dania lub składnik.';
        _serverStatus = 'Brak wyszukiwania';
        _serverResults = [];
        _serverWarnings = [];
        _showingPreviousResults = false;
      });
      return;
    }
    if (_api.session == null) {
      setState(() {
        _serverError = 'Zaloguj się do serwera w zakładce Profil, aby wyszukiwać przepisy.';
        _serverStatus = 'Wymagane logowanie';
        _serverResults = [];
        _serverWarnings = [];
        _showingPreviousResults = false;
      });
      return;
    }

    final generation = ++_searchGeneration;
    final fingerprint = '$_query|$_filter';
    if (_searchOperationId == null ||
        _searchOperationFingerprint != fingerprint) {
      _searchOperationId = newOperationId();
      _searchOperationFingerprint = fingerprint;
    }
    _searchId = null;
    setState(() {
      _searchBusy = true;
      _serverError = null;
      _showingPreviousResults = _serverResults.isNotEmpty;
      _serverStatus = 'Wysyłanie żądania…';
    });

    try {
      final response = await _api.createRecipeSearch(
        query: _query,
        operationId: _searchOperationId!,
        maxTimeMinutes: _filter == 'Do 15 min' ? 15 : null,
        minProteinG: _filter == 'Więcej białka' ? 25 : null,
        vegetarianOnly: _filter == 'Roślinne' ? true : null,
      );
      if (!mounted || generation != _searchGeneration) return;
      _searchId = response['search_id'] as String?;
      if (_searchId == null) {
        throw const FormatException('Odpowiedź nie zawiera search_id.');
      }
      _searchOperationId = null;
      _searchOperationFingerprint = null;
      setState(() {
        _serverStatus = response['status'] as String? ?? 'pending';
      });
      await _pollSearch(_searchId!, generation);
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchBusy = false;
        _serverError = _apiErrorMessage(error);
        _serverStatus = 'Nie udało się rozpocząć wyszukiwania';
      });
    }
  }

  Future<void> _pollSearch(String searchId, int generation) async {
    var polls = 0;
    final started = DateTime.now();
    while (mounted && generation == _searchGeneration && _tab == 1) {
      if (polls > 0) {
        final delay = polls <= 10
            ? const Duration(seconds: 2)
            : const Duration(seconds: 5);
        await Future<void>.delayed(delay);
      }
      if (!mounted || generation != _searchGeneration || _tab != 1) return;
      try {
        final response = await _api.getRecipeSearch(searchId);
        if (!mounted || generation != _searchGeneration || _tab != 1) return;
        final status = response['status'] as String? ?? 'unknown';
        final parsedResults = (response['results'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  RecipeSearchResult.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        var nextCursor = response['next_cursor'] as String?;
        var pageCount = 0;
        while (nextCursor != null &&
            pageCount < 50 &&
            mounted &&
            generation == _searchGeneration &&
            _tab == 1) {
          final page = await _api.getRecipeSearch(searchId, cursor: nextCursor);
          if (!mounted || generation != _searchGeneration || _tab != 1) return;
          parsedResults.addAll(
            (page['results'] as List? ?? const []).whereType<Map>().map(
              (item) =>
                  RecipeSearchResult.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
          nextCursor = page['next_cursor'] as String?;
          pageCount++;
        }
        final parsedWarnings = (response['warnings'] as List? ?? const [])
            .map(
              (warning) => warning is Map
                  ? (warning['message'] ?? warning['code'] ?? warning)
                        .toString()
                  : warning.toString(),
            )
            .toList();
        final isFinal = const {
          'completed',
          'partial',
          'failed',
          'cancelled',
        }.contains(status);
        setState(() {
          _serverStatus = status;
          _serverResults = parsedResults;
          _showingPreviousResults = false;
          _serverWarnings = parsedWarnings;
          _serverError = _serverErrorFromSearch(response['error']);
          _searchBusy = !isFinal;
        });
        if (isFinal) return;
      } catch (error) {
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _serverError = _apiErrorMessage(error);
          _serverStatus =
              error is ApiException && error.code == 'SEARCH_EXPIRED'
              ? 'Zadanie wygasło'
              : 'Nie można odczytać stanu zadania';
          _searchBusy = true;
        });
        return;
      }
      polls++;
      if (DateTime.now().difference(started) > const Duration(minutes: 5)) {
        setState(() {
          _serverStatus = 'Przekroczono czas oczekiwania';
          _serverBusyFalse();
        });
        return;
      }
    }
  }

  void _serverBusyFalse() => _searchBusy = false;

  Future<void> _cancelSearch() async {
    final id = _searchId;
    if (id == null) return;
    setState(() {
      _serverError = null;
      _serverStatus = 'Wysyłanie prośby o anulowanie…';
    });
    try {
      _cancelOperationId ??= newOperationId();
      final response = await _api.cancelRecipeSearch(
        id,
        operationId: _cancelOperationId!,
      );
      if (!mounted) return;
      _cancelOperationId = null;
      setState(
        () => _serverStatus = response['status'] as String? ?? 'cancelling',
      );
      if (const {
        'cancelled',
        'completed',
        'partial',
        'failed',
      }.contains(_serverStatus)) {
        setState(() => _searchBusy = false);
      } else {
        _pollSearch(id, ++_searchGeneration);
      }
    } catch (error) {
      if (mounted) setState(() => _serverError = _apiErrorMessage(error));
    }
  }

  Future<void> _openServerRecipe(RecipeSearchResult item) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _orange)),
    );
    try {
      final details = await Future.wait([
        _api.getRecipe(item.recipeVersionId),
        _api.getRecipeEstimate(item.recipeVersionId),
      ]);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _paper,
        builder: (_) => _ServerRecipeDetails(
          searchResult: item,
          recipe: details[0],
          estimate: details[1],
        ),
      );
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showMessage(_apiErrorMessage(error));
      }
    }
  }

  Future<void> _loginToServer() async {
    try {
      await _api.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _passwordController.clear();
      setState(() {});
      _showMessage('Połączono z serwerem');
    } catch (error) {
      if (mounted) {
        setState(() {});
        _showMessage(_apiErrorMessage(error));
      }
    }
  }

  Future<void> _logoutFromServer() async {
    try {
      await _api.logout();
      if (mounted) {
        setState(() {
          _searchGeneration++;
          _searchId = null;
          _searchBusy = false;
          _serverResults = [];
          _serverWarnings = [];
          _showingPreviousResults = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {});
        _showMessage(_apiErrorMessage(error));
      }
    }
  }

  String _apiErrorMessage(Object error) => error is ApiException
      ? '${error.code}: ${error.message}${error.requestId == null ? '' : ' (ID: ${error.requestId})'}'
      : error is FormatException
      ? error.message
      : 'Wystąpił nieoczekiwany błąd komunikacji z serwerem.';

  String? _serverErrorFromSearch(Object? error) {
    if (error == null) return null;
    if (error is Map) {
      return error['message'] as String? ??
          error['code'] as String? ??
          'Wyszukiwanie zakończone błędem.';
    }
    return error.toString();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Widget _screen() {
    if (_detailRecipe case final recipeId?) {
      return _RecipeDetailScreen(
        recipe: _recipes[recipeId],
        hasConflict: _recipes[recipeId].allergens.any(_allergens.contains),
        onBack: () => setState(() => _detailRecipe = null),
        onAdd: () {
          if (_recipes[recipeId].allergens.any(_allergens.contains)) return;
          setState(() => _plan.add(recipeId));
          _showMessage('Posiłek dodany do planu');
          _goTo(2);
        },
      );
    }

    return switch (_tab) {
      0 => TodayScreen(
        plannedKcal: _total(_plan, (r) => r.kcal),
        eatenKcal: _total(_diary, (r) => r.kcal),
        target: _target,
        plannedMeals: _plan,
        onDiscover: () => _goTo(1),
        onPlan: () => _goTo(2),
      ),
      1 => DiscoverScreen(
        recipes: _serverResults,
        filter: _filter,
        queryController: _queryController,
        status: _serverStatus,
        error: _serverError,
        warnings: _serverWarnings,
        showingPreviousResults: _showingPreviousResults,
        isBusy: _searchBusy,
        hasSession: _api.session != null,
        onSearch: _searchOnServer,
        onFilter: (value) {
          setState(() => _filter = value);
          if (_query.isNotEmpty) _searchOnServer(_query);
        },
        onOpen: _openServerRecipe,
        onCancel: _cancelSearch,
        onRetry: () {
          if (_searchId != null &&
              _serverStatus != 'failed' &&
              _serverStatus != 'Zadanie wygasło') {
            _pollSearch(_searchId!, ++_searchGeneration);
          } else {
            if (_searchId != null) {
              _searchId = null;
              _searchOperationId = null;
              _searchOperationFingerprint = null;
            }
            _searchOnServer(_query);
          }
        },
      ),
      2 => PlanScreen(
        recipeIds: _plan,
        totalKcal: _total(_plan, (r) => r.kcal),
        target: _target,
        onDiscover: () => _goTo(1),
        onRemove: (id) => setState(() => _plan.removeAt(id)),
      ),
      3 => DiaryScreen(
        recipeIds: _diary,
        availableIds: _plan.where((id) => !_diary.contains(id)).toList(),
        totalKcal: _total(_diary, (r) => r.kcal),
        target: _target,
        onLog: (id) => setState(() => _diary.add(id)),
        onRemove: (id) => setState(() => _diary.removeAt(id)),
      ),
      _ => ProfileScreen(
        targetController: _targetController,
        target: _target,
        allergens: _allergens,
        emailController: _emailController,
        passwordController: _passwordController,
        session: _api.session,
        apiConfigured: _api.isConfigured,
        onLogin: _loginToServer,
        onLogout: _logoutFromServer,
        onSaveTarget: () {
          final value = int.tryParse(_targetController.text);
          if (value == null || value < 800 || value > 5000) {
            _showMessage('Wpisz cel od 800 do 5000 kcal');
            return;
          }
          setState(() => _target = value);
          _showMessage('Cel został zapisany');
        },
        onToggleAllergen: (value) => setState(() {
          if (!_allergens.add(value)) _allergens.remove(value);
        }),
      ),
    };
  }

  @override
  Widget build(BuildContext context) =>
      _AppFrame(selectedTab: _tab, onTabSelected: _goTo, child: _screen());
}

class _AppFrame extends StatelessWidget {
  const _AppFrame({
    required this.child,
    required this.selectedTab,
    required this.onTabSelected,
  });
  final Widget child;
  final int selectedTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          const _StatusBar(),
          Expanded(child: child),
          _BottomNavigation(
            selectedTab: selectedTab,
            onSelected: onTabSelected,
          ),
          Container(
            height: 17,
            color: _ink,
            alignment: Alignment.center,
            child: Container(
              width: 104,
              height: 4,
              decoration: BoxDecoration(
                color: _paperBright,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    color: _paper,
    padding: const EdgeInsets.fromLTRB(23, 10, 23, 0),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '9:41',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
        Text('●●●  ▰', style: TextStyle(fontSize: 10, letterSpacing: 1)),
      ],
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedTab,
    required this.onSelected,
  });
  final int selectedTab;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_outlined, 'Dziś'),
    (Icons.search, 'Odkrywaj'),
    (Icons.calendar_view_month_outlined, 'Plan'),
    (Icons.schedule_outlined, 'Dziennik'),
    (Icons.circle_outlined, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    color: _ink,
    child: Row(
      children: [
        for (var index = 0; index < _items.length; index++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(index),
              child: Container(
                height: 57,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: index == selectedTab
                          ? _orange
                          : Colors.transparent,
                      width: 4,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _items[index].$1,
                      size: 22,
                      color: index == selectedTab
                          ? _paperBright
                          : const Color(0xFFC7BAC8),
                    ),
                    Text(
                      _items[index].$2,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: index == selectedTab
                            ? _paperBright
                            : const Color(0xFFC7BAC8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.plannedKcal,
    required this.eatenKcal,
    required this.target,
    required this.plannedMeals,
    required this.onDiscover,
    required this.onPlan,
  });
  final int plannedKcal, eatenKcal, target;
  final List<int> plannedMeals;
  final VoidCallback onDiscover, onPlan;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 242),
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 25),
          color: _orange,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                right: 6,
                bottom: -64,
                child: Text(
                  '✳',
                  style: TextStyle(fontSize: 150, color: Color(0x332A2031)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Eyebrow('SOBĄ / 16 LISTOPADA'),
                  const SizedBox(height: 17),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Dziś jest\ndobry dzień\n'),
                        TextSpan(
                          text: 'na jedzenie.',
                          style: TextStyle(color: _paperBright),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 42,
                      height: .99,
                      letterSpacing: -2.5,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DailyLedger(
                plannedKcal: plannedKcal,
                eatenKcal: eatenKcal,
                target: target,
              ),
              const SizedBox(height: 15),
              const _MacroRow(),
              const SizedBox(height: 23),
              _ActionBanner(onTap: onDiscover),
              _SectionHeading(
                title: 'Na dziś zapisane',
                action: 'Cały plan ↗',
                onTap: onPlan,
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _ink, width: 2),
                    bottom: BorderSide(color: _ink, width: 2),
                  ),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < plannedMeals.length; index++)
                      _MealRow(
                        recipe: _recipes[plannedMeals[index]],
                        last: index == plannedMeals.length - 1,
                      ),
                    if (plannedMeals.isEmpty)
                      const _EmptyMessage(
                        'Plan jest pusty. Odkryj pierwszy przepis.',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const _InlineNote(
                'Wartości na ekranie są przykładowymi szacunkami, a cele makroskładników służą tylko do prezentacji układu.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DailyLedger extends StatelessWidget {
  const _DailyLedger({
    required this.plannedKcal,
    required this.eatenKcal,
    required this.target,
  });
  final int plannedKcal, eatenKcal, target;
  @override
  Widget build(BuildContext context) {
    final percent = target == 0
        ? 0
        : (plannedKcal * 100 ~/ target).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.only(top: 20, bottom: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _ink, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MonoText('01 / BILANS DNIA', size: 10),
              _MonoText('PLANOWANE', size: 10, color: _muted),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    _format(plannedKcal),
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 58,
                      height: .9,
                      letterSpacing: -4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'z ${_format(target)}\nkcal na dziś',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _ProgressBar(value: percent / 100, height: 10, color: _ink),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              '$percent% celu w planie · ${_format(eatenKcal)} kcal w dzienniku',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(
        child: _MacroValue(
          amount: '50 g',
          label: 'Białko',
          progress: .5,
          color: _orange,
        ),
      ),
      Expanded(
        child: _MacroValue(
          amount: '128 g',
          label: 'Węglowodany',
          progress: .51,
          color: _ink,
        ),
      ),
      Expanded(
        child: _MacroValue(
          amount: '34 g',
          label: 'Tłuszcze',
          progress: .51,
          color: Color(0xFF9470B0),
        ),
      ),
    ],
  );
}

class _MacroValue extends StatelessWidget {
  const _MacroValue({
    required this.amount,
    required this.label,
    required this.progress,
    required this.color,
  });
  final String amount, label;
  final double progress;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          amount,
          maxLines: 1,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 20,
            letterSpacing: -.8,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _muted, fontSize: 10),
        ),
        const SizedBox(height: 10),
        _ProgressBar(value: progress, height: 4, color: color),
      ],
    ),
  );
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 5, bottom: 23),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _yellow,
        border: Border.all(color: _ink, width: 2),
        boxShadow: const [BoxShadow(color: _ink, offset: Offset(5, 5))],
      ),
      child: const Row(
        children: [
          Text('↗', style: TextStyle(fontFamily: 'Georgia', fontSize: 30)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Co mogę dziś zjeść?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Odkryj przepis dopasowany do Ciebie',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          Text('→', style: TextStyle(fontSize: 22)),
        ],
      ),
    ),
  );
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.recipes,
    required this.filter,
    required this.queryController,
    required this.status,
    required this.error,
    required this.warnings,
    required this.showingPreviousResults,
    required this.isBusy,
    required this.hasSession,
    required this.onSearch,
    required this.onFilter,
    required this.onOpen,
    required this.onCancel,
    required this.onRetry,
  });
  final List<RecipeSearchResult> recipes;
  final String filter;
  final TextEditingController queryController;
  final String status;
  final String? error;
  final List<String> warnings;
  final bool showingPreviousResults;
  final bool isBusy, hasSession;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;
  final ValueChanged<RecipeSearchResult> onOpen;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StaticPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(
          eyebrow: '02 / ODKRYWAJ',
          title: 'Przepisy,\nktóre pasują.',
          accentLine: 1,
          subtitle: 'Otwórz, porównaj, wybierz po swojemu.',
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: _paperBright,
            border: Border.all(color: _ink, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: queryController,
                  onSubmitted: onSearch,
                  decoration: const InputDecoration(
                    hintText: 'Danie lub składnik',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    isDense: true,
                  ),
                ),
              ),
              InkWell(
                onTap: () => onSearch(queryController.text),
                child: Container(
                  color: _orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  child: const Text(
                    'Szukaj',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 15,
          children: [
            for (final item in [
              'Wszystkie',
              'Do 15 min',
              'Więcej białka',
              'Roślinne',
            ])
              InkWell(
                onTap: () => onFilter(item),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: filter == item ? _ink : _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      decoration: filter == item
                          ? TextDecoration.underline
                          : null,
                      decorationColor: _orange,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(11),
          color: _paperBright,
          child: Row(
            children: [
              if (isBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _orange,
                  ),
                ),
              if (isBusy) const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Serwer: $status',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isBusy)
                TextButton(onPressed: onCancel, child: const Text('Anuluj')),
            ],
          ),
        ),
        if (!hasSession)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: _InlineNote(
              'Zaloguj się w zakładce Profil, aby wysłać zapytanie do serwera.',
            ),
          ),
        if (error != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFFFE0D8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFF8A2F21),
                    fontSize: 12,
                  ),
                ),
                if (!isBusy)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onRetry,
                      child: const Text('Ponów'),
                    ),
                  ),
              ],
            ),
          ),
        if (warnings.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            color: _yellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ograniczenia wyników',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                ),
                for (final warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        if (showingPreviousResults)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: _InlineNote(
              'Poniżej są wcześniejsze wyniki; nowe wyszukiwanie jest w toku.',
            ),
          ),
        const SizedBox(height: 18),
        _MonoText(
          '${recipes.length} WYNIKÓW Z SERWERA',
          size: 10,
          color: _muted,
        ),
        const SizedBox(height: 13),
        for (var index = 0; index < recipes.length; index++)
          _ServerRecipeCard(
            result: recipes[index],
            index: index + 1,
            onTap: () => onOpen(recipes[index]),
          ),
        if (recipes.isEmpty &&
            !isBusy &&
            error == null &&
            const {'completed', 'partial'}.contains(status))
          const _EmptyMessage(
            'Wyszukiwanie zakończone. Serwer nie zwrócił pasujących przepisów.',
          ),
        if (recipes.isEmpty &&
            !isBusy &&
            error == null &&
            !const {'completed', 'partial'}.contains(status))
          const _EmptyMessage(
            'Wpisz danie lub składnik, aby wysłać wyszukiwanie do serwera.',
          ),
      ],
    ),
  );
}

class _ServerRecipeCard extends StatelessWidget {
  const _ServerRecipeCard({
    required this.result,
    required this.index,
    required this.onTap,
  });
  final RecipeSearchResult result;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 5, bottom: 16),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _paperBright,
        border: Border.all(color: _ink, width: 2),
        boxShadow: const [BoxShadow(color: _ink, offset: Offset(4, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonoText(
            '№ ${index.toString().padLeft(2, '0')}',
            size: 10,
            color: _orange,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '≈ ${result.kcal?.toString() ?? '—'} kcal / porcję · białko ${result.proteinG?.toString() ?? '—'} g',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  children: [
                    if (result.completeness != null)
                      _Tag(result.completeness!.toUpperCase()),
                    if (result.matchStatus != null)
                      _Tag(
                        result.matchStatus!.toUpperCase(),
                        color: result.matchStatus == 'unverified'
                            ? _yellow
                            : _paperBright,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Szczegóły przepisu ›',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: _orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ServerRecipeDetails extends StatelessWidget {
  const _ServerRecipeDetails({
    required this.searchResult,
    required this.recipe,
    required this.estimate,
  });
  final RecipeSearchResult searchResult;
  final Map<String, dynamic> recipe, estimate;
  @override
  Widget build(BuildContext context) {
    final ingredients = recipe['ingredients'] as List?;
    final instructions = recipe['instructions'] as List?;
    final source = recipe['source'] is Map
        ? Map<String, dynamic>.from(recipe['source'] as Map)
        : const <String, dynamic>{};
    final perServing = estimate['estimate_per_serving'] is Map
        ? Map<String, dynamic>.from(estimate['estimate_per_serving'] as Map)
        : estimate;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .55,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(22),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    searchResult.title,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 28),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (source['url'] is String)
              SelectableText(
                source['url'] as String,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            const _SectionHeading(title: 'Wartości na porcję'),
            _MonoText(
              'kcal: ${perServing['kcal'] ?? 'brak'} · białko: ${perServing['protein_g'] ?? 'brak'} g · węglowodany: ${perServing['carbohydrate_g'] ?? 'brak'} g · tłuszcz: ${perServing['fat_g'] ?? 'brak'} g',
            ),
            if (perServing['completeness'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Tag(
                  'KOMPLETNOŚĆ: ${perServing['completeness']}'.toUpperCase(),
                ),
              ),
            const _SectionHeading(title: 'Składniki'),
            if (ingredients == null)
              const _InlineNote('Serwer nie zwrócił listy składników.'),
            if (ingredients != null)
              for (final item in ingredients)
                _IngredientRow(_ingredientLabel(item)),
            const _SectionHeading(title: 'Instrukcje'),
            if (instructions == null)
              const _InlineNote('Serwer nie zwrócił instrukcji.'),
            if (instructions != null)
              for (final step in instructions) _InstructionRow(step),
            if (recipe['missing'] is List) ...[
              const _SectionHeading(title: 'Brakujące dane'),
              for (final item in recipe['missing'] as List)
                _InlineNote(item.toString()),
            ],
          ],
        ),
      ),
    );
  }

  String _ingredientLabel(Object? item) {
    if (item is! Map) return item.toString();
    final map = Map<String, dynamic>.from(item);
    return '${map['name'] ?? 'Składnik'} · ${map['quantity'] ?? 'brak ilości'} ${map['unit'] ?? ''}';
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow(this.step);
  final Object? step;
  @override
  Widget build(BuildContext context) {
    final map = step is Map
        ? Map<String, dynamic>.from(step as Map)
        : const <String, dynamic>{};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '${map['position'] ?? '•'}. ${map['text'] ?? step}',
        style: const TextStyle(fontSize: 13, height: 1.45),
      ),
    );
  }
}

class _RecipeDetailScreen extends StatelessWidget {
  const _RecipeDetailScreen({
    required this.recipe,
    required this.hasConflict,
    required this.onBack,
    required this.onAdd,
  });
  final _Recipe recipe;
  final bool hasConflict;
  final VoidCallback onBack, onAdd;
  @override
  Widget build(BuildContext context) => _StaticPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Wróć do przepisów'),
          style: TextButton.styleFrom(
            foregroundColor: _ink,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _FoodIllustration(art: recipe.art, size: 190),
              const Positioned(
                top: 10,
                left: 10,
                child: _Tag('PRZEPIS DEMONSTRACYJNY', color: _yellow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        _PageTitle(
          eyebrow: 'PRZEPIS / ${recipe.type.toUpperCase()}',
          title: recipe.name,
          subtitle:
              'Przykładowy przepis z szacunkowymi wartościami odżywczymi.',
        ),
        const SizedBox(height: 17),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _Tag('${recipe.minutes} MIN'),
            const _Tag('1 PORCJA'),
            _Tag('${recipe.ingredients.length} SKŁADNIKI'),
            _Tag(
              hasConflict ? 'ZAWIERA WYKLUCZONY SKŁADNIK' : 'ZGODNY Z PROFILEM',
              color: hasConflict ? _orange : _paperBright,
            ),
          ],
        ),
        const SizedBox(height: 21),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _lilac,
            border: Border.all(color: _ink, width: 2),
            boxShadow: const [BoxShadow(color: _ink, offset: Offset(5, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MonoText('WARTOŚCI / 1 PORCJA', size: 10),
                  _MonoText('SZACUNEK', size: 10),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                '≈ ${recipe.kcal} kcal',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 43,
                  height: 1,
                  letterSpacing: -3,
                ),
              ),
              const Divider(color: _ink),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${recipe.protein} g\nBiałko'),
                  Text('${recipe.carbs} g\nWęglowodany'),
                  Text('${recipe.fat} g\nTłuszcz'),
                ],
              ),
            ],
          ),
        ),
        const _SectionHeading(title: 'Składniki', action: '1 porcja'),
        for (final ingredient in recipe.ingredients) _IngredientRow(ingredient),
        const SizedBox(height: 18),
        const _SourceNote(
          'Skąd te liczby?',
          'To przykładowe dane UI. W działającej aplikacji każda pozycja otrzyma link do przepisu, źródło wartości odżywczych, datę odczytu i oznaczenie braków danych.',
        ),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: hasConflict ? 'Niezgodny z profilem' : 'Dodaj do planu',
          onPressed: hasConflict ? null : onAdd,
        ),
      ],
    ),
  );
}

class PlanScreen extends StatelessWidget {
  const PlanScreen({
    super.key,
    required this.recipeIds,
    required this.totalKcal,
    required this.target,
    required this.onDiscover,
    required this.onRemove,
  });
  final List<int> recipeIds;
  final int totalKcal, target;
  final VoidCallback onDiscover;
  final ValueChanged<int> onRemove;
  @override
  Widget build(BuildContext context) => _StaticPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(
          eyebrow: '03 / PLAN',
          title: 'Ułóż swój\ndzień.',
          accentLine: 1,
          subtitle: 'Posiłki czekają tutaj. Ty decydujesz o kolejności.',
        ),
        const _WeekStrip(),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: _yellow,
            border: Border.all(color: _ink, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MonoText('ZAPLANOWANA ENERGIA', size: 10),
              const SizedBox(height: 10),
              Text(
                '${_format(totalKcal)} / ${_format(target)} kcal',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 28,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 14),
              _ProgressBar(
                value: target == 0 ? 0 : totalKcal / target,
                height: 8,
                color: _ink,
              ),
              const SizedBox(height: 10),
              const _MonoText('Wartości odżywcze są przykładowe', size: 9),
            ],
          ),
        ),
        _SectionHeading(
          title: 'Posiłki',
          action: 'Dodaj przepis +',
          onTap: onDiscover,
        ),
        for (var index = 0; index < recipeIds.length; index++)
          _PlanMeal(
            recipe: _recipes[recipeIds[index]],
            onRemove: () => onRemove(index),
          ),
        if (recipeIds.isEmpty)
          const _EmptyMessage(
            'Brak posiłków. Dodaj przepis z ekranu Odkrywaj.',
          ),
        const SizedBox(height: 15),
        const _InlineNote(
          'Plan pokazuje zamiar. Faktyczne spożycie zapisujesz osobno w Dzienniku.',
        ),
      ],
    ),
  );
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.recipeIds,
    required this.availableIds,
    required this.totalKcal,
    required this.target,
    required this.onLog,
    required this.onRemove,
  });
  final List<int> recipeIds, availableIds;
  final int totalKcal, target;
  final ValueChanged<int> onLog;
  final ValueChanged<int> onRemove;
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  int? _selected;
  @override
  Widget build(BuildContext context) {
    if (_selected != null && !widget.availableIds.contains(_selected)) {
      _selected = null;
    }
    _selected ??= widget.availableIds.isEmpty
        ? null
        : widget.availableIds.first;
    return _StaticPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PageTitle(
            eyebrow: '04 / DZIENNIK',
            title: 'Zjedzone.\nZapisane.',
            accentLine: 1,
            subtitle: 'Tu liczymy tylko to, co rzeczywiście zjedzono.',
          ),
          Container(
            margin: const EdgeInsets.only(top: 22),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _lilac,
              border: Border.all(color: _ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Dodaj z planu',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 19),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Tag('${widget.availableIds.length} DO ZAPISANIA'),
                  ],
                ),
                if (widget.availableIds.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_selected),
                    initialValue: _selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: _paperBright,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    items: [
                      for (final id in widget.availableIds)
                        DropdownMenuItem(
                          value: id,
                          child: Text(
                            _recipes[id].name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _selected = value),
                  ),
                  const SizedBox(height: 13),
                  _PrimaryButton(
                    label: 'Oznacz jako zjedzone',
                    onPressed: _selected == null
                        ? null
                        : () => widget.onLog(_selected!),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      widget.recipeIds.isEmpty
                          ? 'Dodaj posiłek z planu, aby zapisać go w dzienniku.'
                          : 'Wszystkie posiłki z planu zostały zapisane.',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SPOŻYCIE DZISIAJ',
                      style: TextStyle(
                        color: _muted,
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_format(widget.totalKcal)} kcal',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 38,
                          letterSpacing: -3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Tag('CEL ${_format(widget.target)} KCAL'),
            ],
          ),
          const SizedBox(height: 14),
          const _MacroRow(),
          const _SectionHeading(title: 'Zapisane posiłki'),
          for (var index = 0; index < widget.recipeIds.length; index++)
            _MealRow(
              recipe: _recipes[widget.recipeIds[index]],
              trailing: IconButton(
                onPressed: () => widget.onRemove(index),
                icon: const Icon(Icons.close, size: 19),
                tooltip: 'Usuń z dziennika',
              ),
            ),
          if (widget.recipeIds.isEmpty)
            const _EmptyMessage('Brak zapisanych posiłków.'),
          const SizedBox(height: 18),
          const _SourceNote(
            '',
            'Odczyt etykiety aparatem jest przewidziany w wymaganiach MVP. Rozpoznawanie obrazu wymaga osobnej implementacji.',
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.targetController,
    required this.target,
    required this.allergens,
    required this.emailController,
    required this.passwordController,
    required this.session,
    required this.apiConfigured,
    required this.onLogin,
    required this.onLogout,
    required this.onSaveTarget,
    required this.onToggleAllergen,
  });
  final TextEditingController targetController;
  final TextEditingController emailController, passwordController;
  final int target;
  final Set<String> allergens;
  final ApiSession? session;
  final bool apiConfigured;
  final VoidCallback onLogin, onLogout;
  final VoidCallback onSaveTarget;
  final ValueChanged<String> onToggleAllergen;
  @override
  Widget build(BuildContext context) => _StaticPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PageTitle(
          eyebrow: '05 / PROFIL',
          title: 'Twoja miara,\nTwoje zasady.',
          accentLine: 1,
          subtitle: 'Kilka wskazówek dla agenta. Zawsze możesz je zmienić.',
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          color: _paperBright,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Połączenie z serwerem',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 19),
              ),
              const SizedBox(height: 6),
              Text(
                apiConfigured
                    ? (session == null ? 'Nie zalogowano' : 'Sesja aktywna')
                    : 'Brak konfiguracji API_BASE_URL',
                style: TextStyle(
                  color: session == null ? _muted : const Color(0xFF356C46),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!apiConfigured)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: _InlineNote(
                    'Uruchom aplikację z --dart-define=API_BASE_URL=https://adres-serwera.',
                  ),
                ),
              if (apiConfigured && session == null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    filled: true,
                    fillColor: _paper,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Hasło',
                    filled: true,
                    fillColor: _paper,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 11),
                _PrimaryButton(label: 'Zaloguj do API', onPressed: onLogin),
              ],
              if (session != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Sesja ${session!.sessionId}',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 8),
                _PrimaryButton(label: 'Wyloguj z serwera', onPressed: onLogout),
              ],
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _InlineNote(
                  'Tokeny sesji są obecnie przechowywane tylko w pamięci aplikacji.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        const _MonoText('DZIENNY CEL ENERGII', size: 10),
        const SizedBox(height: 9),
        TextField(
          controller: targetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            filled: true,
            fillColor: _paperBright,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
            suffixText: 'kcal',
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Wpisz własny cel (800–5000 kcal). Prototyp nie wyznacza go medycznie.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 17),
        _PrimaryButton(label: 'Zapisz cel', onPressed: onSaveTarget),
        const _SectionHeading(title: 'Wykluczane składniki'),
        Text(
          'Wybierz składniki, których agent nie powinien oznaczać jako zgodnych z Twoim profilem.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const {
              'mleko': 'Mleko',
              'gluten': 'Gluten',
              'soja': 'Soja',
            }.entries)
              _ChoiceTag(
                label: item.value,
                active: allergens.contains(item.key),
                onTap: () => onToggleAllergen(item.key),
              ),
          ],
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: _yellow,
            border: Border(
              top: BorderSide(color: _ink, width: 2),
              bottom: BorderSide(color: _ink, width: 2),
            ),
          ),
          child: const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Uwaga o alergiach\n',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: 'Brak alergenu w odczytanym składzie nie potwierdza bezpieczeństwa potrawy. Wyniki z niepełnym składem trzeba traktować jako niepewne.',
                ),
              ],
            ),
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ),
        const _SectionHeading(title: 'Jak działa dobór?'),
        Text(
          'Agent wyszukuje publiczne przepisy, porównuje składniki z Twoimi ograniczeniami i szacuje wartości odżywcze z danych żywieniowych produktów. Pokazuje brakujące dane oraz źródła.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
        ),
      ],
    ),
  );
}

class _PlanMeal extends StatelessWidget {
  const _PlanMeal({required this.recipe, required this.onRemove});
  final _Recipe recipe;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: _MonoText(recipe.type.toUpperCase(), size: 10, color: _muted),
      ),
      Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: _ink),
            bottom: BorderSide(color: _ink),
          ),
        ),
        child: _MealRow(
          recipe: recipe,
          subtitle: '1 porcja · ${recipe.kcal} kcal',
          trailing: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 19),
            tooltip: 'Usuń z planu',
          ),
        ),
      ),
    ],
  );
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.recipe,
    this.subtitle,
    this.last = false,
    this.trailing,
  });
  final _Recipe recipe;
  final String? subtitle;
  final bool last;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 65),
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: last ? _ink : _line, width: last ? 2 : 1),
      ),
    ),
    child: Row(
      children: [
        _FoodIllustration(art: recipe.art, circular: true, size: 43),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle ?? '${recipe.type} · ${recipe.minutes} min',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing ?? _MonoText('${recipe.kcal} kcal', size: 10),
      ],
    ),
  );
}

enum _FoodArt { oats, bowl, pasta, salad }

class _FoodIllustration extends StatelessWidget {
  const _FoodIllustration({
    required this.art,
    this.circular = false,
    this.size = 110,
  });
  final _FoodArt art;
  final bool circular;
  final double size;
  Color get _background => switch (art) {
    _FoodArt.oats => const Color(0xFFC9A27A),
    _FoodArt.bowl => const Color(0xFFB7C688),
    _FoodArt.pasta => const Color(0xFFCF8152),
    _FoodArt.salad => const Color(0xFFE0C982),
  };
  Color get _accent => switch (art) {
    _FoodArt.oats => const Color(0xFFB34248),
    _FoodArt.bowl => const Color(0xFF79A46B),
    _FoodArt.pasta => const Color(0xFFE4B665),
    _FoodArt.salad => const Color(0xFF6C9A63),
  };
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _background,
      shape: circular ? BoxShape.circle : BoxShape.rectangle,
      border: Border.all(color: _ink, width: circular ? 2 : 0),
    ),
    child: Center(
      child: Container(
        width: size * .68,
        height: size * .68,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5DC),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: .18),
              offset: const Offset(0, 4),
              blurRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * .5,
            height: size * .5,
            decoration: BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 4),
            ),
          ),
        ),
      ),
    ),
  );
}

class _StaticPage extends StatelessWidget {
  const _StaticPage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 35),
    child: child,
  );
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 23),
    child: Row(
      children: [
        _DayCell('Pn', '16', selected: true),
        _DayCell('Wt', '17'),
        _DayCell('Śr', '18'),
        _DayCell('Cz', '19'),
        _DayCell('Pt', '20'),
        _DayCell('So', '21'),
        _DayCell('Nd', '22'),
      ],
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell(this.day, this.date, {this.selected = false});
  final String day, date;
  final bool selected;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      color: selected ? _orange : Colors.transparent,
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              color: selected ? _ink : _muted,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            date,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.accentLine,
  });
  final String eyebrow, title;
  final String? subtitle;
  final int? accentLine;
  @override
  Widget build(BuildContext context) {
    final lines = title.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(eyebrow),
        Text.rich(
          TextSpan(
            children: [
              for (var index = 0; index < lines.length; index++) ...[
                if (index > 0) const TextSpan(text: '\n'),
                TextSpan(
                  text: lines[index],
                  style: index == accentLine
                      ? const TextStyle(color: _orange)
                      : null,
                ),
              ],
            ],
          ),
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 39,
            height: .99,
            letterSpacing: -2.2,
            color: _ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 13),
          Text(
            subtitle!,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.45),
          ),
        ],
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 23,
              height: 1,
              letterSpacing: -1.1,
            ),
          ),
        ),
        if (action != null) const SizedBox(width: 12),
        if (action != null)
          InkWell(
            onTap: onTap,
            child: Text(
              action!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: _orange,
              ),
            ),
          ),
      ],
    ),
  );
}

class _MonoText extends StatelessWidget {
  const _MonoText(this.text, {this.size = 10, this.color = _ink});
  final String text;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'monospace',
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: .25,
      color: color,
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.height,
    required this.color,
  });
  final double value, height;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: SizedBox(
      height: height,
      child: Stack(
        children: [
          Container(color: const Color(0xFFDED5CD)),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: Container(color: color),
          ),
        ],
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color = _paperBright});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: _ink),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ChoiceTag extends StatelessWidget {
  const _ChoiceTag({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: _Tag(label.toUpperCase(), color: active ? _orange : _paperBright),
  );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: '↳ ',
            style: TextStyle(color: _orange, fontWeight: FontWeight.w900),
          ),
          TextSpan(text: label),
        ],
      ),
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class _InlineNote extends StatelessWidget {
  const _InlineNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: _muted, fontSize: 11, height: 1.5));
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(25),
    color: _paperBright,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
    ),
  );
}

class _SourceNote extends StatelessWidget {
  const _SourceNote(this.title, this.text);
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: const BoxDecoration(
      color: Color(0xFFEBE3DC),
      border: Border(left: BorderSide(color: _orange, width: 4)),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          if (title.isNotEmpty)
            TextSpan(
              text: '$title\n',
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          TextSpan(text: text),
        ],
      ),
      style: const TextStyle(
        color: Color(0xFF625967),
        fontSize: 11,
        height: 1.5,
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .5 : 1,
    child: InkWell(
      onTap: onPressed,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: _orange,
          border: Border.all(color: _ink, width: 2),
          boxShadow: const [BoxShadow(color: _ink, offset: Offset(4, 4))],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    ),
  );
}

String _format(int value) => value.toString().replaceAllMapped(
  RegExp(r'(?<=\d)(?=(\d{3})+$)'),
  (_) => ' ',
);
