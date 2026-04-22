import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:collection/collection.dart';
import 'package:flutter_tex/flutter_tex.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState()..loadData(),
      child: const MainApp(),
    ),
  );
}

// --- STEAMPUNK THEME CONSTANTS ---
const Color steamParchment = Color(0xFFEADDCD);
const Color steamDarkInk = Color(0xFF2B1C10);
const Color steamCopper = Color(0xFFB87333);
const Color steamBrass = Color(0xFFD4AF37);
const Color steamBlood = Color(0xFF8B0000);
const Color steamGreen = Color(0xFF2E4A2E);

final steamShadow = BoxShadow(
  color: steamCopper.withOpacity(0.5),
  blurRadius: 12,
  spreadRadius: 2,
  offset: const Offset(0, 0),
);

final steamTheme = ThemeData(
  scaffoldBackgroundColor: steamParchment,
  colorScheme: const ColorScheme.light(
    primary: steamCopper,
    secondary: steamBrass,
    surface: steamParchment,
    onSurface: steamDarkInk,
    error: steamBlood,
  ),
  useMaterial3: true,
  fontFamily: 'Georgia',
  cardTheme: const CardThemeData(
    color: steamParchment,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    margin: EdgeInsets.all(8),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: steamDarkInk,
      foregroundColor: steamBrass,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      elevation: 5,
      shadowColor: steamCopper,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: steamCopper,
      foregroundColor: steamDarkInk,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: steamDarkInk,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: steamParchment,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(color: steamCopper, width: 2),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: steamDarkInk,
    foregroundColor: steamBrass,
    elevation: 10,
    shadowColor: steamCopper,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: steamDarkInk)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: steamDarkInk)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: steamCopper, width: 2)),
    filled: true,
    fillColor: steamParchment,
  ),
);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SteamPrep Engine',
      theme: steamTheme,
      home: const DashboardNavigation(),
    );
  }
}

// --- MODELS ---

class Question {
  String text;
  List<String> options;
  int correctIndex;
  int? selectedIndex;
  int timeTakenMs;
  bool isMarkedForReview;
  bool visited;

  Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.selectedIndex,
    this.timeTakenMs = 0,
    this.isMarkedForReview = false,
    this.visited = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        'selectedIndex': selectedIndex,
        'timeTakenMs': timeTakenMs,
        'isMarkedForReview': isMarkedForReview,
        'visited': visited,
      };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        text: json['text'],
        options: List<String>.from(json['options']),
        correctIndex: json['correctIndex'],
        selectedIndex: json['selectedIndex'],
        timeTakenMs: json['timeTakenMs'] ?? 0,
        isMarkedForReview: json['isMarkedForReview'] ?? false,
        visited: json['visited'] ?? false,
      );
}

class TestModel {
  String id;
  String title;
  String category;
  String subcategory;
  List<Question> questions;
  int? score;
  bool isCompleted;
  int totalTimeTakenMs;
  int allocatedTimeMs;
  int remainingTimeMs;
  DateTime? dateCompleted;

  TestModel({
    required this.id,
    required this.title,
    required this.category,
    required this.subcategory,
    required this.questions,
    this.score,
    this.isCompleted = false,
    this.totalTimeTakenMs = 0,
    this.allocatedTimeMs = 3600000,
    int? remainingTimeMs,
    this.dateCompleted,
  }) : remainingTimeMs = remainingTimeMs ?? allocatedTimeMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'subcategory': subcategory,
        'questions': questions.map((q) => q.toJson()).toList(),
        'score': score,
        'isCompleted': isCompleted,
        'totalTimeTakenMs': totalTimeTakenMs,
        'allocatedTimeMs': allocatedTimeMs,
        'remainingTimeMs': remainingTimeMs,
        'dateCompleted': dateCompleted?.toIso8601String(),
      };

  factory TestModel.fromJson(Map<String, dynamic> json) => TestModel(
        id: json['id'],
        title: json['title'],
        category: json['category'],
        subcategory: json['subcategory'],
        questions: (json['questions'] as List).map((q) => Question.fromJson(q)).toList(),
        score: json['score'],
        isCompleted: json['isCompleted'] ?? false,
        totalTimeTakenMs: json['totalTimeTakenMs'] ?? 0,
        allocatedTimeMs: json['allocatedTimeMs'] ?? 3600000,
        remainingTimeMs: json['remainingTimeMs'],
        dateCompleted: json['dateCompleted'] != null ? DateTime.parse(json['dateCompleted']) : null,
      );
}

// --- STATE MANAGEMENT ---

class AppState extends ChangeNotifier {
  List<TestModel> _tests = [];
  List<TestModel> get tests => _tests;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('app_data_steam');
    if (data != null) {
      try {
        final List decoded = jsonDecode(data);
        _tests = decoded.map((e) => TestModel.fromJson(e)).toList();
        notifyListeners();
      } catch (e) {
        // Fallback for corrupted data
        _tests = [];
      }
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_tests.map((e) => e.toJson()).toList());
    await prefs.setString('app_data_steam', encoded);
  }

  void importJson(String jsonString) {
    try {
      final List decoded = jsonDecode(jsonString);
      final newTests = decoded.map((e) => TestModel.fromJson(e)).toList();
      _tests.addAll(newTests);
      saveData();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void updateTestCategory(String id, String newCat, String newSub) {
    final idx = _tests.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tests[idx].category = newCat;
      _tests[idx].subcategory = newSub;
      saveData();
      notifyListeners();
    }
  }

  void deleteTest(String id) {
    _tests.removeWhere((t) => t.id == id);
    saveData();
    notifyListeners();
  }

  void saveTestProgress(TestModel updatedTest) {
    final idx = _tests.indexWhere((t) => t.id == updatedTest.id);
    if (idx != -1) {
      _tests[idx] = updatedTest;
      saveData();
      notifyListeners();
    }
  }

  void resetData() {
    _tests.clear();
    saveData();
    notifyListeners();
  }
}

// --- UI / SCREENS ---

class DashboardNavigation extends StatefulWidget {
  const DashboardNavigation({super.key});

  @override
  State<DashboardNavigation> createState() => _DashboardNavigationState();
}

class _DashboardNavigationState extends State<DashboardNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const LibraryScreen(),
    const StatsScreen(),
    const ImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: steamDarkInk,
        indicatorColor: steamCopper,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books, color: steamBrass),
            selectedIcon: Icon(Icons.library_books, color: steamDarkInk),
            label: 'Archives',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics, color: steamBrass),
            selectedIcon: Icon(Icons.analytics, color: steamDarkInk),
            label: 'Telemetry',
          ),
          NavigationDestination(
            icon: Icon(Icons.data_object, color: steamBrass),
            selectedIcon: Icon(Icons.data_object, color: steamDarkInk),
            label: 'Inject Data',
          ),
        ],
      ),
    );
  }
}

// --- LIBRARY SCREEN ---

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tests = context.watch<AppState>().tests;
    final grouped = groupBy(tests, (TestModel t) => t.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Archives', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: tests.isEmpty
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(border: Border.all(color: steamCopper, width: 2), boxShadow: [steamShadow], color: steamParchment),
                child: const Text('ARCHIVES EMPTY.\nINJECT JSON TO COMMENCE.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: grouped.entries.map((categoryEntry) {
                final subGrouped = groupBy(categoryEntry.value, (TestModel t) => t.subcategory);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(border: Border.all(color: steamDarkInk, width: 2), color: steamParchment),
                  child: ExpansionTile(
                    iconColor: steamCopper,
                    collapsedIconColor: steamDarkInk,
                    title: Text(categoryEntry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamDarkInk)),
                    children: subGrouped.entries.map((subEntry) {
                      return ExpansionTile(
                        title: Text(subEntry.key, style: const TextStyle(color: steamCopper, fontWeight: FontWeight.bold)),
                        children: subEntry.value.map((test) {
                          bool inProgress = !test.isCompleted && test.remainingTimeMs < test.allocatedTimeMs;

                          return Container(
                            decoration: const BoxDecoration(border: Border(top: BorderSide(color: steamDarkInk, width: 1))),
                            child: ListTile(
                              leading: Icon(
                                test.isCompleted ? Icons.settings : (inProgress ? Icons.settings_applications : Icons.settings_outlined),
                                color: test.isCompleted ? steamGreen : (inProgress ? steamCopper : steamDarkInk),
                              ),
                              title: Text(test.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: test.isCompleted ? Text('Efficiency: ${test.score}/${test.questions.length}') : Text(inProgress ? 'Suspended - Resume' : 'Uninitialized'),
                              trailing: IconButton(
                                icon: const Icon(Icons.build, size: 20, color: steamDarkInk),
                                onPressed: () => _editTestCategory(context, test),
                              ),
                              onTap: () {
                                if (!test.isCompleted) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTestScreen(test: test)));
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => TestResultScreen(test: test)));
                                }
                              },
                              onLongPress: () => _confirmDelete(context, test.id),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _confirmDelete(BuildContext context, String testId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PURGE RECORD?'),
        content: const Text('This action will permanently eradicate the selected data from the engine.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ABORT')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: steamBlood),
            onPressed: () {
              context.read<AppState>().deleteTest(testId);
              Navigator.pop(ctx);
            },
            child: const Text('PURGE'),
          )
        ],
      ),
    );
  }

  void _editTestCategory(BuildContext context, TestModel test) {
    final catCtrl = TextEditingController(text: test.category);
    final subCtrl = TextEditingController(text: test.subcategory);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reconfigure Sectors'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Primary Sector')),
            const SizedBox(height: 12),
            TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Sub-Sector')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () {
              context.read<AppState>().updateTestCategory(test.id, catCtrl.text, subCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('COMMIT'),
          )
        ],
      ),
    );
  }
}

// --- ACTIVE TEST SCREEN ---

class ActiveTestScreen extends StatefulWidget {
  final TestModel test;
  const ActiveTestScreen({super.key, required this.test});

  @override
  State<ActiveTestScreen> createState() => _ActiveTestScreenState();
}

class _ActiveTestScreenState extends State<ActiveTestScreen> {
  late PageController _pageController;
  late TestModel _activeTest;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _activeTest = TestModel.fromJson(widget.test.toJson());

    if (_activeTest.questions.isNotEmpty) {
      _activeTest.questions[0].visited = true;
    }

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_activeTest.remainingTimeMs > 0) {
          _activeTest.remainingTimeMs -= 1000;
          _activeTest.questions[_currentIndex].timeTakenMs += 1000;
        } else {
          _timer?.cancel();
          _finishTest(autoSubmit: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _saveProgressOnExit() {
    context.read<AppState>().saveTestProgress(_activeTest);
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentIndex = index;
      _activeTest.questions[_currentIndex].visited = true;
    });
    _pageController.jumpToPage(index);
  }

  void _finishTest({bool autoSubmit = false}) {
    if (autoSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SYSTEM HALT. Auto-submitting...'), backgroundColor: steamBlood));
    }

    int score = 0;
    int totalTime = 0;
    for (var q in _activeTest.questions) {
      if (q.selectedIndex == q.correctIndex) score++;
      totalTime += q.timeTakenMs;
    }
    _activeTest.score = score;
    _activeTest.totalTimeTakenMs = totalTime;
    _activeTest.isCompleted = true;
    _activeTest.dateCompleted = DateTime.now();

    context.read<AppState>().saveTestProgress(_activeTest);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TestResultScreen(test: _activeTest)));
  }

  void _confirmSubmit() {
    int unanswered = _activeTest.questions.where((q) => q.selectedIndex == null).length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('INITIATE SUBMISSION?'),
        content: Text(unanswered > 0 ? 'Warning: $unanswered nodes unlinked.\nProceed?' : 'All nodes linked. Ready to commit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ABORT')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finishTest();
            },
            child: const Text('COMMIT'),
          )
        ],
      ),
    );
  }

  Widget _buildSteampunkTeX(String text, {bool isSelected = false, bool isOption = false}) {
    final color = isSelected ? '#EADDCD' : '#2B1C10';
    final weight = isOption ? 'normal' : 'bold';
    final fontSize = isOption ? 16 : 20;

    return TeXView(
      child: TeXViewDocument(
        '''<div style="color: $color; font-family: Georgia, serif; font-weight: $weight; font-size: ${fontSize}px; line-height: 1.6;">
             $text
           </div>''',
      ),
      style: const TeXViewStyle(
        backgroundColor: 'transparent',
        padding: TeXViewPadding.all(4),
        margin: TeXViewMargin.all(0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int hours = _activeTest.remainingTimeMs ~/ 3600000;
    int minutes = (_activeTest.remainingTimeMs % 3600000) ~/ 60000;
    int seconds = (_activeTest.remainingTimeMs % 60000) ~/ 1000;
    String timeString = '${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) => _saveProgressOnExit(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('SEQ ${_currentIndex + 1}/${_activeTest.questions.length}', style: const TextStyle(letterSpacing: 2)),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (_activeTest.remainingTimeMs < 300000) ? steamBlood : steamParchment,
                  border: Border.all(color: steamBrass, width: 2),
                  boxShadow: [if (_activeTest.remainingTimeMs < 300000) BoxShadow(color: steamBlood, blurRadius: 10, spreadRadius: 2)],
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom, size: 18, color: (_activeTest.remainingTimeMs < 300000) ? steamBrass : steamDarkInk),
                    const SizedBox(width: 8),
                    Text(
                      timeString,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: (_activeTest.remainingTimeMs < 300000) ? steamBrass : steamDarkInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.account_tree),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
          ],
        ),
        endDrawer: _buildQuestionExplorer(),
        body: Container(
          decoration: BoxDecoration(
            border: Border.all(color: steamCopper, width: 4),
          ),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentIndex = idx;
                      _activeTest.questions[_currentIndex].visited = true;
                    });
                  },
                  itemCount: _activeTest.questions.length,
                  itemBuilder: (context, index) {
                    final q = _activeTest.questions[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: steamParchment,
                              border: Border.all(color: steamDarkInk, width: 2),
                              boxShadow: [steamShadow],
                            ),
                            child: _buildSteampunkTeX(q.text),
                          ),
                          const SizedBox(height: 32),
                          ...List.generate(q.options.length, (optIdx) {
                            bool isSelected = q.selectedIndex == optIdx;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: InkWell(
                                onTap: () => setState(() => q.selectedIndex = optIdx),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? steamDarkInk : steamParchment,
                                    border: Border.all(color: isSelected ? steamBrass : steamDarkInk, width: isSelected ? 3 : 1),
                                    boxShadow: isSelected ? [BoxShadow(color: steamBrass.withOpacity(0.5), blurRadius: 10)] : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected ? steamBrass : Colors.transparent,
                                          border: Border.all(color: steamDarkInk, width: 2),
                                        ),
                                        child: Text(
                                          String.fromCharCode(65 + optIdx),
                                          style: TextStyle(color: isSelected ? steamDarkInk : steamDarkInk, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildSteampunkTeX(
                                          q.options[optIdx],
                                          isSelected: isSelected,
                                          isOption: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final q = _activeTest.questions[_currentIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: steamDarkInk,
        border: Border(top: BorderSide(color: steamBrass, width: 3)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null,
              icon: const Icon(Icons.arrow_back_ios, size: 14, color: steamBrass),
              label: const Text('REVERT', style: TextStyle(color: steamBrass, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: q.isMarkedForReview ? steamCopper : steamParchment,
                foregroundColor: steamDarkInk,
                side: BorderSide(color: q.isMarkedForReview ? steamBrass : steamDarkInk, width: 2),
                shadowColor: q.isMarkedForReview ? steamBrass : null,
                elevation: q.isMarkedForReview ? 10 : 0,
              ),
              onPressed: () => setState(() => q.isMarkedForReview = !q.isMarkedForReview),
              icon: const Icon(Icons.flag),
              label: Text(q.isMarkedForReview ? 'FLAGGED' : 'FLAG'),
            ),
            if (_currentIndex < _activeTest.questions.length - 1)
              TextButton(
                onPressed: () => _goToQuestion(_currentIndex + 1),
                child: const Row(children: [Text('ADVANCE', style: TextStyle(color: steamBrass, fontWeight: FontWeight.bold)), SizedBox(width: 8), Icon(Icons.arrow_forward_ios, size: 14, color: steamBrass)]),
              )
            else
              FilledButton(
                onPressed: _confirmSubmit,
                style: FilledButton.styleFrom(backgroundColor: steamGreen, foregroundColor: steamParchment, side: const BorderSide(color: steamBrass, width: 2)),
                child: const Text('SUBMIT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionExplorer() {
    return Drawer(
      backgroundColor: steamParchment,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: steamDarkInk, width: 4)),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('NODE MAP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: steamDarkInk, letterSpacing: 2)),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmSubmit();
                    },
                    style: FilledButton.styleFrom(backgroundColor: steamDarkInk, foregroundColor: steamBrass),
                    child: const Text('COMMIT'),
                  )
                ],
              ),
            ),
            const Divider(color: steamCopper, thickness: 2),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _activeTest.questions.length,
                itemBuilder: (ctx, i) {
                  final q = _activeTest.questions[i];
                  Color bgColor = Colors.transparent;
                  Color borderColor = steamDarkInk;
                  Color textColor = steamDarkInk;

                  if (q.isMarkedForReview) {
                    bgColor = steamCopper;
                    textColor = steamParchment;
                  } else if (q.selectedIndex != null) {
                    bgColor = steamGreen;
                    textColor = steamParchment;
                  } else if (q.visited) {
                    bgColor = steamBlood;
                    textColor = steamParchment;
                  }

                  bool isCurrent = i == _currentIndex;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _goToQuestion(i);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: isCurrent ? steamBrass : borderColor, width: isCurrent ? 4 : 2),
                        boxShadow: isCurrent ? [BoxShadow(color: steamBrass.withOpacity(0.8), blurRadius: 10)] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- RESULT SCREEN ---

class TestResultScreen extends StatelessWidget {
  final TestModel test;
  const TestResultScreen({super.key, required this.test});

  Widget _buildSteampunkTeX(String text) {
    return TeXView(
      child: TeXViewDocument(
        '''<div style="color: #2B1C10; font-family: Georgia, serif; font-weight: bold; font-size: 18px; line-height: 1.6;">
             $text
           </div>''',
      ),
      style: const TeXViewStyle(
        backgroundColor: 'transparent',
        padding: TeXViewPadding.all(4),
        margin: TeXViewMargin.all(0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int unattempted = test.questions.where((q) => q.selectedIndex == null).length;
    int incorrect = test.questions.length - (test.score ?? 0) - unattempted;

    return Scaffold(
      appBar: AppBar(title: Text('TELEMETRY: ${test.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(border: Border.all(color: steamBrass, width: 4), boxShadow: [steamShadow], color: steamDarkInk),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text('SYSTEM EFFICIENCY', style: TextStyle(color: steamBrass, fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('${test.score} / ${test.questions.length}', style: const TextStyle(color: steamParchment, fontSize: 48, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ResultPill(title: 'OPTIMAL', count: test.score ?? 0, color: steamGreen),
                    _ResultPill(title: 'ERRORS', count: incorrect, color: steamBlood),
                    _ResultPill(title: 'VOID', count: unattempted, color: Colors.grey),
                  ],
                ),
                const Divider(height: 48, color: steamCopper, thickness: 2),
                Text('EXECUTION TIME: ${(test.totalTimeTakenMs / 60000).toStringAsFixed(1)} CYCLES (MINS)', style: const TextStyle(color: steamBrass, fontFamily: 'Courier')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('NODE BREAKDOWN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamDarkInk, letterSpacing: 2)),
          const SizedBox(height: 12),
          ...test.questions.asMap().entries.map((entry) {
            int idx = entry.key;
            Question q = entry.value;
            bool isCorrect = q.selectedIndex == q.correctIndex;
            bool isAttempted = q.selectedIndex != null;

            Color tileColor = isAttempted ? (isCorrect ? steamGreen.withOpacity(0.2) : steamBlood.withOpacity(0.2)) : steamDarkInk.withOpacity(0.1);
            IconData icon = isAttempted ? (isCorrect ? Icons.check_circle : Icons.cancel) : Icons.remove_circle;
            Color iconColor = isAttempted ? (isCorrect ? steamGreen : steamBlood) : steamDarkInk;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(border: Border.all(color: steamDarkInk, width: 2), color: tileColor),
              child: ExpansionTile(
                iconColor: steamDarkInk,
                leading: Icon(icon, color: iconColor),
                title: Text('NODE ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: steamDarkInk)),
                subtitle: Text('Time: ${(q.timeTakenMs / 1000).toStringAsFixed(1)}s', style: const TextStyle(fontFamily: 'Courier')),
                children: [
                  Container(
                    color: steamParchment,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSteampunkTeX(q.text),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: isCorrect ? steamGreen : steamBlood, width: 2)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('INPUT: ${isAttempted ? String.fromCharCode(65 + q.selectedIndex!) : 'NULL'}', style: TextStyle(color: isCorrect ? steamGreen : steamBlood, fontWeight: FontWeight.bold)),
                              if (!isCorrect) ...[
                                const SizedBox(height: 8),
                                Text('REQUIRED OPTIMUM: ${String.fromCharCode(65 + q.correctIndex)}', style: const TextStyle(color: steamGreen, fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _ResultPill({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24)),
        )
      ],
    );
  }
}

// --- STATS SCREEN ---

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tests = context.watch<AppState>().tests.where((t) => t.isCompleted).toList();
    if (tests.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('TELEMETRY')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border.all(color: steamCopper, width: 2), color: steamParchment),
            child: const Text('INSUFFICIENT DATA.\nEXECUTE PROTOCOLS FIRST.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    int totalQuestions = 0;
    int totalCorrect = 0;
    int totalTimeMs = 0;

    Map<String, Map<String, num>> categoryStats = {};

    for (var t in tests) {
      totalQuestions += t.questions.length;
      totalCorrect += t.score ?? 0;
      totalTimeMs += t.totalTimeTakenMs;

      if (!categoryStats.containsKey(t.category)) categoryStats[t.category] = {'qs': 0, 'correct': 0, 'timeMs': 0};
      categoryStats[t.category]!['qs'] = categoryStats[t.category]!['qs']! + t.questions.length;
      categoryStats[t.category]!['correct'] = categoryStats[t.category]!['correct']! + (t.score ?? 0);
      categoryStats[t.category]!['timeMs'] = categoryStats[t.category]!['timeMs']! + t.totalTimeTakenMs;
    }

    double accuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0;
    double avgTimePerQuestion = totalQuestions > 0 ? (totalTimeMs / totalQuestions) / 1000 : 0;

    var sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) {
        double accA = a.value['qs']! > 0 ? a.value['correct']! / a.value['qs']! : 0;
        double accB = b.value['qs']! > 0 ? b.value['correct']! / b.value['qs']! : 0;
        return accA.compareTo(accB);
      });

    String weakest = sortedCategories.first.key;
    String strongest = sortedCategories.last.key;

    List<BarChartGroupData> barGroups = [];
    int xIndex = 0;
    List<String> xLabels = [];

    categoryStats.forEach((category, stats) {
      double catAcc = stats['qs']! > 0 ? (stats['correct']! / stats['qs']!) * 100 : 0;
      barGroups.add(BarChartGroupData(x: xIndex, barRods: [
        BarChartRodData(toY: catAcc, color: steamCopper, width: 20, borderRadius: BorderRadius.zero)
      ]));
      xLabels.add(category.length > 8 ? '${category.substring(0, 6)}..' : category);
      xIndex++;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('GLOBAL TELEMETRY', style: TextStyle(letterSpacing: 2))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _StatCard(title: 'GLOBAL ACCURACY', value: '${accuracy.toStringAsFixed(1)}%', icon: Icons.troubleshoot, color: steamBrass)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'AVG CYCLE/NODE', value: '${avgTimePerQuestion.toStringAsFixed(1)}s', icon: Icons.timer, color: steamCopper)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'OPTIMAL SECTOR', value: strongest, icon: Icons.trending_up, color: steamGreen)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'CRITICAL SECTOR', value: weakest, icon: Icons.trending_down, color: steamBlood)),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: steamDarkInk, width: 2), color: steamParchment),
              child: Column(
                children: [
                  const Text('SECTOR DIAGNOSTICS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamDarkInk, letterSpacing: 2)),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                if (val.toInt() >= 0 && val.toInt() < xLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(xLabels[val.toInt()], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: steamDarkInk)),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: steamDarkInk.withOpacity(0.2), strokeWidth: 1)),
                        borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: steamDarkInk, width: 2), left: BorderSide(color: steamDarkInk, width: 2))),
                        barGroups: barGroups,
                      ),
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: steamDarkInk,
        border: Border.all(color: steamBrass, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamParchment), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: steamBrass, letterSpacing: 1)),
        ],
      ),
    );
  }
}

// --- IMPORT SCREEN ---

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _controller = TextEditingController();

  void _import() {
    try {
      context.read<AppState>().importJson(_controller.text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DATA INJECTION SUCCESSFUL', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: steamGreen));
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CORRUPT DATA: $e'), backgroundColor: steamBlood));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DATA INJECTION', style: TextStyle(letterSpacing: 2))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: steamDarkInk,
              child: const Text('WARNING: ENSURE DATA COMPLIES WITH STANDARD PROTOCOL BEFORE INJECTION.', style: TextStyle(color: steamBlood, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: steamBrass, width: 2), boxShadow: [steamShadow]),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'Courier', color: steamDarkInk),
                  decoration: const InputDecoration(
                    hintText: 'RAW JSON HERE...',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: true,
                    fillColor: steamParchment,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.download),
              label: const Text('INJECT SEQUENCE', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(20)),
            ),
          ],
        ),
      ),
    );
  }
}
