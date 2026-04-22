import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..loadData(),
      child: const MainApp(),
    ),
  );
}

// -------------------- THEME --------------------

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
  cardTheme: const CardTheme(
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
  dialogTheme: const DialogTheme(
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: steamDarkInk),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: steamDarkInk),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: steamCopper, width: 2),
    ),
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

// -------------------- SCRATCHPAD MODELS --------------------

enum DrawTool { pen, line, circle, square, eraser }

class DrawStroke {
  final DrawTool tool;
  final List<Offset> points; // scene coordinates
  final double width;

  DrawStroke({required this.tool, required this.points, required this.width});

  Map<String, dynamic> toJson() => {
        'tool': tool.index,
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'width': width,
      };

  factory DrawStroke.fromJson(Map<String, dynamic> json) => DrawStroke(
        tool: DrawTool.values[(json['tool'] as num).toInt()],
        points: (json['points'] as List)
            .map(
              (p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ),
            )
            .toList(growable: true),
        width: (json['width'] as num).toDouble(),
      );

  DrawStroke deepCopy() => DrawStroke(
        tool: tool,
        points: points.map((e) => Offset(e.dx, e.dy)).toList(growable: true),
        width: width,
      );
}

class DrawLayer {
  String name;
  List<DrawStroke> strokes;
  bool isVisible;

  DrawLayer({
    required this.name,
    List<DrawStroke>? strokes,
    this.isVisible = true,
  }) : strokes = strokes ?? <DrawStroke>[]; // IMPORTANT: growable list

  Map<String, dynamic> toJson() => {
        'name': name,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'isVisible': isVisible,
      };

  factory DrawLayer.fromJson(Map<String, dynamic> json) => DrawLayer(
        name: (json['name'] ?? 'Layer').toString(),
        strokes: (json['strokes'] as List? ?? const [])
            .map((s) => DrawStroke.fromJson(Map<String, dynamic>.from(s)))
            .toList(growable: true),
        isVisible: (json['isVisible'] as bool?) ?? true,
      );
}

// -------------------- TEST MODELS --------------------

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
        text: (json['text'] ?? '').toString(),
        options: (json['options'] as List? ?? const []).map((e) => e.toString()).toList(),
        correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
        selectedIndex: (json['selectedIndex'] is num) ? (json['selectedIndex'] as num).toInt() : null,
        timeTakenMs: (json['timeTakenMs'] as num?)?.toInt() ?? 0,
        isMarkedForReview: (json['isMarkedForReview'] as bool?) ?? false,
        visited: (json['visited'] as bool?) ?? false,
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
  String? scratchpadJson;

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
    this.scratchpadJson,
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
        'scratchpadJson': scratchpadJson,
      };

  factory TestModel.fromJson(Map<String, dynamic> json) => TestModel(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? 'Untitled').toString(),
        category: (json['category'] ?? 'Unsorted').toString(),
        subcategory: (json['subcategory'] ?? 'General').toString(),
        questions: (json['questions'] as List? ?? const [])
            .map((q) => Question.fromJson(Map<String, dynamic>.from(q)))
            .toList(growable: true),
        score: (json['score'] is num) ? (json['score'] as num).toInt() : null,
        isCompleted: (json['isCompleted'] as bool?) ?? false,
        totalTimeTakenMs: (json['totalTimeTakenMs'] as num?)?.toInt() ?? 0,
        allocatedTimeMs: (json['allocatedTimeMs'] as num?)?.toInt() ?? 3600000,
        remainingTimeMs: (json['remainingTimeMs'] as num?)?.toInt(),
        dateCompleted: (json['dateCompleted'] != null) ? DateTime.tryParse(json['dateCompleted'].toString()) : null,
        scratchpadJson: json['scratchpadJson']?.toString(),
      );
}

// -------------------- STATE --------------------

class AppState extends ChangeNotifier {
  List<TestModel> _tests = [];
  List<TestModel> get tests => _tests;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('app_data_steam');
    if (data == null || data.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(data);
      if (decoded is! List) return;
      _tests = decoded.map((e) => TestModel.fromJson(Map<String, dynamic>.from(e))).toList(growable: true);
      notifyListeners();
    } catch (_) {
      // If corrupt, do not crash the app.
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_tests.map((e) => e.toJson()).toList());
    await prefs.setString('app_data_steam', encoded);
  }

  /// Accepts:
  /// - List of tests JSON
  /// - Single test JSON object
  void importJson(String jsonString) {
    final raw = jsonString.trim();
    if (raw.isEmpty) throw FormatException('Empty payload');

    dynamic decoded = jsonDecode(raw);

    final List<dynamic> list = (decoded is List)
        ? decoded
        : (decoded is Map)
            ? [decoded]
            : throw FormatException('Root must be a List or Object');

    final incoming = list.map((e) => TestModel.fromJson(Map<String, dynamic>.from(e))).toList();

    // Merge by id (replace existing if same id).
    for (final t in incoming) {
      if (t.id.trim().isEmpty) {
        // Generate stable id if missing (avoid crashes later).
        t.id = 'import_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}';
      }
      final idx = _tests.indexWhere((x) => x.id == t.id);
      if (idx == -1) {
        _tests.add(t);
      } else {
        _tests[idx] = t;
      }
    }
    saveData();
    notifyListeners();
  }

  void updateTestCategory(String id, String newCat, String newSub) {
    final idx = _tests.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _tests[idx].category = newCat.trim().isEmpty ? 'Unsorted' : newCat.trim();
    _tests[idx].subcategory = newSub.trim().isEmpty ? 'General' : newSub.trim();
    saveData();
    notifyListeners();
  }

  void deleteTest(String id) {
    _tests.removeWhere((t) => t.id == id);
    saveData();
    notifyListeners();
  }

  void saveTestProgress(TestModel updatedTest) {
    final idx = _tests.indexWhere((t) => t.id == updatedTest.id);
    if (idx == -1) return;
    _tests[idx] = updatedTest;
    saveData();
    notifyListeners();
  }

  void resetData() {
    _tests.clear();
    saveData();
    notifyListeners();
  }
}

// -------------------- NAV --------------------

class DashboardNavigation extends StatefulWidget {
  const DashboardNavigation({super.key});

  @override
  State<DashboardNavigation> createState() => _DashboardNavigationState();
}

class _DashboardNavigationState extends State<DashboardNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    LibraryScreen(),
    StatsScreen(),
    ImportScreen(),
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

// -------------------- TEX RENDER (FIX: auto-height + fallback) --------------------

String _htmlSafe(String input) {
  // For flutter_tex content: prevent HTML tags breaking render.
  // Keep it simple and predictable.
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

class SteamTeXBlock extends StatefulWidget {
  final String text;
  final bool isSelected;
  final bool isOption;
  final bool bold;

  const SteamTeXBlock(
    this.text, {
    super.key,
    this.isSelected = false,
    this.isOption = false,
    this.bold = false,
  });

  @override
  State<SteamTeXBlock> createState() => _SteamTeXBlockState();
}

class _SteamTeXBlockState extends State<SteamTeXBlock> {
  double _height = 42; // must be bounded for platform view
  bool _failed = false;

  @override
  void didUpdateWidget(covariant SteamTeXBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _height = 42;
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = _htmlSafe(widget.text);
    final color = widget.isSelected ? '#EADDCD' : '#2B1C10';
    final weight = (widget.bold || !widget.isOption) ? '700' : '400';
    final fontSize = widget.isOption ? '16px' : '20px';

    if (_failed) {
      return Text(
        widget.text,
        style: TextStyle(
          color: widget.isSelected ? steamParchment : steamDarkInk,
          fontWeight: (widget.bold || !widget.isOption) ? FontWeight.bold : FontWeight.normal,
          fontSize: widget.isOption ? 16 : 18,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: TeXView(
        renderingEngine: const TeXViewRenderingEngine.katex(),
        // If your flutter_tex version doesn't have these callbacks,
        // remove them and keep the fixed height (it will still render).
        onRenderFinished: (h) {
          final nh = (h is num) ? h.toDouble() : _height;
          final clamped = nh.isFinite ? nh.clamp(28.0, 2000.0) : _height;
          if (mounted && (clamped - _height).abs() > 2) {
            setState(() => _height = clamped);
          }
        },
        onError: (error) {
          if (mounted) setState(() => _failed = true);
        },
        loadingWidgetBuilder: (ctx) => const SizedBox.shrink(),
        child: TeXViewMarkdown(
          safe,
          style: TeXViewStyle.fromCSS(
            'color: $color; font-family: Georgia; font-weight: $weight; font-size: $fontSize; line-height: 1.2; padding: 0px; margin: 0px;',
          ),
        ),
        style: const TeXViewStyle(
          margin: TeXViewMargin.all(0),
          padding: TeXViewPadding.all(0),
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

// -------------------- LIBRARY --------------------

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tests = context.watch<AppState>().tests;
    final grouped = groupBy(tests, (TestModel t) => (t.category.trim().isEmpty ? 'Unsorted' : t.category));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Archives', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: tests.isEmpty
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: steamCopper, width: 2),
                  boxShadow: [steamShadow],
                  color: steamParchment,
                ),
                child: const Text(
                  'ARCHIVES EMPTY.\nINJECT JSON TO COMMENCE.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: grouped.entries.map((categoryEntry) {
                final subGrouped = groupBy(
                  categoryEntry.value,
                  (TestModel t) => (t.subcategory.trim().isEmpty ? 'General' : t.subcategory),
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(border: Border.all(color: steamDarkInk, width: 2), color: steamParchment),
                  child: ExpansionTile(
                    iconColor: steamCopper,
                    collapsedIconColor: steamDarkInk,
                    title: Text(
                      categoryEntry.key.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamDarkInk),
                    ),
                    children: subGrouped.entries.map((subEntry) {
                      return ExpansionTile(
                        title: Text(subEntry.key, style: const TextStyle(color: steamCopper, fontWeight: FontWeight.bold)),
                        children: subEntry.value.map((test) {
                          final inProgress = !test.isCompleted && test.remainingTimeMs < test.allocatedTimeMs;

                          return Container(
                            decoration: const BoxDecoration(border: Border(top: BorderSide(color: steamDarkInk, width: 1))),
                            child: ListTile(
                              leading: Icon(
                                test.isCompleted
                                    ? Icons.settings
                                    : (inProgress ? Icons.settings_applications : Icons.settings_outlined),
                                color: test.isCompleted ? steamGreen : (inProgress ? steamCopper : steamDarkInk),
                              ),
                              title: Text(test.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: test.isCompleted
                                  ? Text('Efficiency: ${test.score}/${test.questions.length}')
                                  : Text(inProgress ? 'Suspended - Resume' : 'Uninitialized'),
                              trailing: IconButton(
                                icon: const Icon(Icons.build, size: 20, color: steamDarkInk),
                                onPressed: () => _editTestCategory(context, test),
                              ),
                              onTap: () {
                                if (test.questions.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('TEST HAS NO QUESTIONS.'),
                                      backgroundColor: steamBlood,
                                    ),
                                  );
                                  return;
                                }
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

// -------------------- ACTIVE TEST --------------------

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
    // Work on a copy.
    _activeTest = TestModel.fromJson(widget.test.toJson());

    if (_activeTest.questions.isNotEmpty) {
      _activeTest.questions[0].visited = true;
    }
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_activeTest.questions.isEmpty) return;

      setState(() {
        if (_activeTest.remainingTimeMs > 0) {
          _activeTest.remainingTimeMs = math.max(0, _activeTest.remainingTimeMs - 1000);
          final idx = _currentIndex.clamp(0, _activeTest.questions.length - 1);
          _activeTest.questions[idx].timeTakenMs += 1000;
        } else {
          _timer?.cancel();
          _finishTest(autoSubmit: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _saveProgressOnExit() {
    context.read<AppState>().saveTestProgress(_activeTest);
  }

  void _goToQuestion(int index) {
    if (_activeTest.questions.isEmpty) return;
    final i = index.clamp(0, _activeTest.questions.length - 1);

    setState(() {
      _currentIndex = i;
      _activeTest.questions[_currentIndex].visited = true;
    });
    _pageController.jumpToPage(i);
  }

  void _finishTest({bool autoSubmit = false}) {
    if (!mounted) return;

    if (autoSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SYSTEM HALT. Auto-submitting...'), backgroundColor: steamBlood),
      );
    }

    int score = 0;
    int totalTime = 0;
    for (final q in _activeTest.questions) {
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
    final unanswered = _activeTest.questions.where((q) => q.selectedIndex == null).length;
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

  void _openScratchpad() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) {
        return ScratchpadOverlay(
          initialData: _activeTest.scratchpadJson,
          onSaveAndClose: (jsonResult) {
            setState(() => _activeTest.scratchpadJson = jsonResult);
            _saveProgressOnExit();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTest.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_activeTest.title)),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: steamCopper, width: 2), color: steamParchment),
            child: const Text('NO QUESTIONS AVAILABLE.', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    final remaining = _activeTest.remainingTimeMs;
    final hours = remaining ~/ 3600000;
    final minutes = (remaining % 3600000) ~/ 60000;
    final seconds = (remaining % 60000) ~/ 1000;
    final timeString = '${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: true,
      onPopInvoked: (_) => _saveProgressOnExit(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('SEQ ${_currentIndex + 1}/${_activeTest.questions.length}', style: const TextStyle(letterSpacing: 2)),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (remaining < 300000) ? steamBlood : steamParchment,
                  border: Border.all(color: steamBrass, width: 2),
                  boxShadow: [
                    if (remaining < 300000) const BoxShadow(color: steamBlood, blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom, size: 18, color: (remaining < 300000) ? steamBrass : steamDarkInk),
                    const SizedBox(width: 8),
                    Text(
                      timeString,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: (remaining < 300000) ? steamBrass : steamDarkInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.draw, color: steamBrass),
              tooltip: 'Scratchpad',
              onPressed: _openScratchpad,
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
          decoration: BoxDecoration(border: Border.all(color: steamCopper, width: 4)),
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

                    // IMPORTANT: avoid platform-view “unbounded height” problems
                    // by ensuring TeX widgets are bounded (SteamTeXBlock uses SizedBox height).
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
                            child: SteamTeXBlock(q.text, bold: true),
                          ),
                          const SizedBox(height: 32),
                          ...List.generate(q.options.length, (optIdx) {
                            final isSelected = q.selectedIndex == optIdx;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: InkWell(
                                onTap: () => setState(() => q.selectedIndex = optIdx),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? steamDarkInk : steamParchment,
                                    border: Border.all(
                                      color: isSelected ? steamBrass : steamDarkInk,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected ? [BoxShadow(color: steamBrass.withOpacity(0.5), blurRadius: 10)] : null,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                          style: const TextStyle(color: steamDarkInk, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: SteamTeXBlock(
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
                          const SizedBox(height: 100),
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
                child: const Row(
                  children: [
                    Text('ADVANCE', style: TextStyle(color: steamBrass, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 14, color: steamBrass),
                  ],
                ),
              )
            else
              FilledButton(
                onPressed: _confirmSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: steamGreen,
                  foregroundColor: steamParchment,
                  side: const BorderSide(color: steamBrass, width: 2),
                ),
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
                  const Text(
                    'NODE MAP',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: steamDarkInk, letterSpacing: 2),
                  ),
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

                  final isCurrent = i == _currentIndex;

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
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
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

// -------------------- SCRATCHPAD (FIXED: pinch zoom always, 2-finger pan, proper layers) --------------------

class ScratchpadOverlay extends StatefulWidget {
  final String? initialData;
  final Function(String?) onSaveAndClose;

  const ScratchpadOverlay({super.key, this.initialData, required this.onSaveAndClose});

  @override
  State<ScratchpadOverlay> createState() => _ScratchpadOverlayState();
}

class _ScratchpadOverlayState extends State<ScratchpadOverlay> {
  static const double _canvasSize = 3000;

  List<DrawLayer> _layers = [DrawLayer(name: 'Base Layer')];
  int _activeLayerIndex = 0;

  DrawTool _currentTool = DrawTool.pen;
  double _currentWidth = 3.0;

  // Transform state (viewport -> scene)
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _didInitView = false;

  // Multi-touch: scale/pan always with 2+ fingers (no toggle).
  bool _isTransforming = false;
  double _scaleStart = 1.0;
  Offset _offsetStart = Offset.zero;
  Offset _sceneFocalStart = Offset.zero;

  // Drawing pointers
  final Set<int> _pointersDown = <int>{};
  int? _drawingPointerId;
  int? _activeStrokeIndex; // index in active layer strokes for current stroke

  // Undo/redo per active layer
  final List<List<DrawStroke>> _undoStack = [];
  final List<List<DrawStroke>> _redoStack = [];

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null && widget.initialData!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.initialData!);
        if (decoded is List) {
          _layers = decoded.map((l) => DrawLayer.fromJson(Map<String, dynamic>.from(l))).toList(growable: true);
          if (_layers.isEmpty) _layers = [DrawLayer(name: 'Base Layer')];
          _activeLayerIndex = (_activeLayerIndex).clamp(0, _layers.length - 1);
        }
      } catch (_) {
        _layers = [DrawLayer(name: 'Base Layer')];
      }
    }
  }

  // ---- Transform helpers ----

  void _ensureInitialView(Size viewportSize) {
    if (_didInitView) return;
    _didInitView = true;

    // Center canvas in viewport.
    final dx = -(_canvasSize - viewportSize.width) / 2;
    final dy = -(_canvasSize - viewportSize.height) / 2;
    _offset = Offset(dx, dy);
    _scale = 1.0;
  }

  Offset _toScene(Offset viewportPoint) {
    return (viewportPoint - _offset) / _scale;
  }

  void _resetView(Size viewportSize) {
    setState(() {
      _didInitView = false;
      _ensureInitialView(viewportSize);
    });
  }

  // ---- Undo/Redo ----

  void _saveSnapshotForUndo() {
    final strokes = _layers[_activeLayerIndex].strokes.map((s) => s.deepCopy()).toList(growable: true);
    _undoStack.add(strokes);
    _redoStack.clear();
    if (_undoStack.length > 30) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final current = _layers[_activeLayerIndex].strokes.map((s) => s.deepCopy()).toList(growable: true);
    _redoStack.add(current);

    setState(() {
      _layers[_activeLayerIndex].strokes = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final current = _layers[_activeLayerIndex].strokes.map((s) => s.deepCopy()).toList(growable: true);
    _undoStack.add(current);

    setState(() {
      _layers[_activeLayerIndex].strokes = _redoStack.removeLast();
    });
  }

  // ---- Drawing ----

  void _cancelActiveStrokeIfAny() {
    if (_activeStrokeIndex == null) return;
    final layer = _layers[_activeLayerIndex];
    final idx = _activeStrokeIndex!;
    if (idx >= 0 && idx < layer.strokes.length) {
      layer.strokes.removeAt(idx);
    }
    _activeStrokeIndex = null;
    _drawingPointerId = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointersDown.add(event.pointer);

    // If second finger comes, stop drawing immediately (2-finger is reserved for transform).
    if (_pointersDown.length >= 2) {
      _cancelActiveStrokeIfAny();
      return;
    }

    if (!_layers[_activeLayerIndex].isVisible) return;
    if (_drawingPointerId != null) return;

    _drawingPointerId = event.pointer;

    _saveSnapshotForUndo();

    final scenePos = _toScene(event.localPosition);
    final layer = _layers[_activeLayerIndex];

    // Create stroke with growable points list.
    final pts = <Offset>[scenePos];
    final stroke = DrawStroke(tool: _currentTool, points: pts, width: _currentWidth);

    setState(() {
      _activeStrokeIndex = layer.strokes.length;
      layer.strokes.add(stroke);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointersDown.length >= 2) return; // transforms; not drawing
    if (_drawingPointerId == null || event.pointer != _drawingPointerId) return;
    if (_activeStrokeIndex == null) return;

    final layer = _layers[_activeLayerIndex];
    if (_activeStrokeIndex! < 0 || _activeStrokeIndex! >= layer.strokes.length) return;

    final stroke = layer.strokes[_activeStrokeIndex!];
    final scenePos = _toScene(event.localPosition);

    setState(() {
      if (stroke.tool == DrawTool.pen || stroke.tool == DrawTool.eraser) {
        stroke.points.add(scenePos);
      } else {
        if (stroke.points.length == 1) {
          stroke.points.add(scenePos);
        } else {
          stroke.points[1] = scenePos;
        }
      }
    });
  }

  void _onPointerUpOrCancel(int pointer) {
    _pointersDown.remove(pointer);
    if (pointer == _drawingPointerId) {
      _drawingPointerId = null;
      _activeStrokeIndex = null;
    }
  }

  // ---- Layer mgmt ----

  void _addLayer() {
    setState(() {
      _layers.add(DrawLayer(name: 'Layer ${_layers.length + 1}'));
      _activeLayerIndex = _layers.length - 1;
      _undoStack.clear();
      _redoStack.clear();
    });
  }

  void _clearActiveLayer() {
    _saveSnapshotForUndo();
    setState(() {
      _layers[_activeLayerIndex].strokes.clear();
    });
  }

  void _closeAndSave() {
    final jsonStr = jsonEncode(_layers.map((l) => l.toJson()).toList());
    widget.onSaveAndClose(jsonStr);
    Navigator.of(context).pop();
  }

  // ---- Transform gestures (2-finger pinch + pan) ----

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStart = _scale;
    _offsetStart = _offset;
    final focal = details.localFocalPoint;
    _sceneFocalStart = (focal - _offsetStart) / _scaleStart;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Only transform if 2+ fingers. Single finger is reserved for drawing.
    if (details.pointerCount < 2) return;

    if (!_isTransforming) {
      _isTransforming = true;
      _cancelActiveStrokeIfAny();
    }

    final newScale = (_scaleStart * details.scale).clamp(0.1, 10.0);
    final focal = details.localFocalPoint;
    final newOffset = focal - _sceneFocalStart * newScale;

    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isTransforming = false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (_) => _closeAndSave(),
      child: Scaffold(
        backgroundColor: steamParchment,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _closeAndSave),
          title: const Text('DIGITAL SCRATCHPAD', style: TextStyle(letterSpacing: 2)),
          actions: [
            LayoutBuilder(
              builder: (context, constraints) {
                return IconButton(
                  icon: const Icon(Icons.zoom_out_map),
                  tooltip: 'Reset View',
                  onPressed: () => _resetView(MediaQuery.of(context).size),
                );
              },
            ),
            IconButton(icon: const Icon(Icons.undo), onPressed: _undoStack.isNotEmpty ? _undo : null),
            IconButton(icon: const Icon(Icons.redo), onPressed: _redoStack.isNotEmpty ? _redo : null),
            Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.layers), onPressed: () => Scaffold.of(ctx).openEndDrawer())),
          ],
        ),
        endDrawer: _buildLayerManager(),
        body: Column(
          children: [
            // Toolbar
            Container(
              color: steamDarkInk,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _ToolButton(icon: Icons.edit, tool: DrawTool.pen, current: _currentTool, onTap: () => setState(() => _currentTool = DrawTool.pen)),
                  _ToolButton(icon: Icons.horizontal_rule, tool: DrawTool.line, current: _currentTool, onTap: () => setState(() => _currentTool = DrawTool.line)),
                  _ToolButton(icon: Icons.crop_square, tool: DrawTool.square, current: _currentTool, onTap: () => setState(() => _currentTool = DrawTool.square)),
                  _ToolButton(icon: Icons.circle_outlined, tool: DrawTool.circle, current: _currentTool, onTap: () => setState(() => _currentTool = DrawTool.circle)),
                  _ToolButton(icon: Icons.layers_clear, tool: DrawTool.eraser, current: _currentTool, onTap: () => setState(() => _currentTool = DrawTool.eraser)),
                  const Spacer(),
                  const Icon(Icons.line_weight, color: steamBrass, size: 16),
                  Expanded(
                    flex: 2,
                    child: Slider(
                      value: _currentWidth,
                      min: 1,
                      max: 24,
                      activeColor: steamBrass,
                      inactiveColor: steamParchment.withOpacity(0.3),
                      onChanged: (v) => setState(() => _currentWidth = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _ensureInitialView(Size(constraints.maxWidth, constraints.maxHeight));

                  return Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.55),
                      border: Border.all(color: steamCopper, width: 4),
                      boxShadow: [steamShadow],
                    ),
                    child: ClipRect(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: _onPointerDown,
                          onPointerMove: _onPointerMove,
                          onPointerUp: (e) => _onPointerUpOrCancel(e.pointer),
                          onPointerCancel: (e) => _onPointerUpOrCancel(e.pointer),
                          child: Transform(
                            transform: Matrix4.identity()
                              ..translate(_offset.dx, _offset.dy)
                              ..scale(_scale),
                            child: SizedBox(
                              width: _canvasSize,
                              height: _canvasSize,
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: ScratchpadPainter(layers: _layers),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildLayerManager() {
    return Drawer(
      backgroundColor: steamParchment,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: steamDarkInk, width: 4)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: steamDarkInk,
            width: double.infinity,
            child: const Text(
              'LAYER MANAGER',
              style: TextStyle(color: steamBrass, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: _addLayer, icon: const Icon(Icons.add), label: const Text('ADD'))),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _clearActiveLayer,
                    icon: const Icon(Icons.clear),
                    label: const Text('CLEAR'),
                    style: FilledButton.styleFrom(backgroundColor: steamBlood),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: steamCopper, thickness: 2),
          Expanded(
            child: ListView.builder(
              itemCount: _layers.length,
              itemBuilder: (ctx, i) {
                final layer = _layers[i];
                final isActive = i == _activeLayerIndex;
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: isActive ? steamBrass : Colors.transparent, width: 2),
                    color: isActive ? steamDarkInk.withOpacity(0.1) : null,
                  ),
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(layer.isVisible ? Icons.visibility : Icons.visibility_off, color: steamDarkInk),
                      onPressed: () {
                        setState(() {
                          layer.isVisible = !layer.isVisible;
                          if (!layer.isVisible && isActive) {
                            _cancelActiveStrokeIfAny();
                          }
                        });
                      },
                    ),
                    title: Text(layer.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                    trailing: _layers.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: steamBlood),
                            onPressed: () {
                              setState(() {
                                if (i == _activeLayerIndex) _cancelActiveStrokeIfAny();
                                _layers.removeAt(i);
                                _activeLayerIndex = _activeLayerIndex.clamp(0, _layers.length - 1);
                                _undoStack.clear();
                                _redoStack.clear();
                              });
                            },
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _cancelActiveStrokeIfAny();
                        _activeLayerIndex = i;
                        _undoStack.clear();
                        _redoStack.clear();
                      });
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final DrawTool tool;
  final DrawTool current;
  final VoidCallback onTap;

  const _ToolButton({required this.icon, required this.tool, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSel = tool == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSel ? steamCopper : Colors.transparent,
          border: Border.all(color: isSel ? steamBrass : Colors.transparent, width: 2),
          boxShadow: isSel ? [BoxShadow(color: steamBrass.withOpacity(0.6), blurRadius: 8)] : null,
        ),
        child: Icon(icon, color: isSel ? steamDarkInk : steamParchment),
      ),
    );
  }
}

class ScratchpadPainter extends CustomPainter {
  final List<DrawLayer> layers;
  ScratchpadPainter({required this.layers});

  @override
  void paint(Canvas canvas, Size size) {
    // IMPORTANT FIX:
    // Paint each layer into its own saveLayer so eraser only affects that layer,
    // not everything below.
    for (final layer in layers) {
      if (!layer.isVisible) continue;

      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

      for (final stroke in layer.strokes) {
        if (stroke.points.isEmpty) continue;

        final paint = Paint()
          ..color = (stroke.tool == DrawTool.eraser) ? Colors.transparent : steamDarkInk
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;

        if (stroke.tool == DrawTool.eraser) {
          paint.blendMode = BlendMode.clear;
        }

        if (stroke.points.length == 1) {
          canvas.drawCircle(stroke.points.first, stroke.width / 2, paint..style = PaintingStyle.fill);
        } else if (stroke.tool == DrawTool.pen || stroke.tool == DrawTool.eraser) {
          final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
          for (int i = 1; i < stroke.points.length; i++) {
            path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
          }
          canvas.drawPath(path, paint);
        } else {
          final start = stroke.points.first;
          final end = stroke.points.last;

          switch (stroke.tool) {
            case DrawTool.line:
              canvas.drawLine(start, end, paint);
              break;
            case DrawTool.square:
              canvas.drawRect(Rect.fromPoints(start, end), paint);
              break;
            case DrawTool.circle:
              final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
              final radius = (start - end).distance / 2;
              canvas.drawCircle(center, radius, paint);
              break;
            case DrawTool.pen:
            case DrawTool.eraser:
              break;
          }
        }
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ScratchpadPainter oldDelegate) => true;
}

// -------------------- RESULT SCREEN --------------------

class TestResultScreen extends StatelessWidget {
  final TestModel test;
  const TestResultScreen({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    final unattempted = test.questions.where((q) => q.selectedIndex == null).length;
    final correct = test.score ?? 0;
    final incorrect = test.questions.length - correct - unattempted;

    return Scaffold(
      appBar: AppBar(title: Text('TELEMETRY: ${test.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: steamBrass, width: 4),
              boxShadow: [steamShadow],
              color: steamDarkInk,
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  'SYSTEM EFFICIENCY',
                  style: TextStyle(color: steamBrass, fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  '$correct / ${test.questions.length}',
                  style: const TextStyle(color: steamParchment, fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ResultPill(title: 'OPTIMAL', count: correct, color: steamGreen),
                    _ResultPill(title: 'ERRORS', count: incorrect, color: steamBlood),
                    _ResultPill(title: 'VOID', count: unattempted, color: Colors.grey),
                  ],
                ),
                const Divider(height: 48, color: steamCopper, thickness: 2),
                Text(
                  'EXECUTION TIME: ${(test.totalTimeTakenMs / 60000).toStringAsFixed(1)} CYCLES (MINS)',
                  style: const TextStyle(color: steamBrass, fontFamily: 'Courier'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'NODE BREAKDOWN',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamDarkInk, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          ...test.questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;
            final isAttempted = q.selectedIndex != null;
            final isCorrect = isAttempted && (q.selectedIndex == q.correctIndex);

            final tileColor = isAttempted
                ? (isCorrect ? steamGreen.withOpacity(0.2) : steamBlood.withOpacity(0.2))
                : steamDarkInk.withOpacity(0.1);

            final icon = isAttempted ? (isCorrect ? Icons.check_circle : Icons.cancel) : Icons.remove_circle;
            final iconColor = isAttempted ? (isCorrect ? steamGreen : steamBlood) : steamDarkInk;

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
                        SteamTeXBlock(q.text, bold: true),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: isCorrect ? steamGreen : steamBlood, width: 2)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INPUT: ${isAttempted ? String.fromCharCode(65 + q.selectedIndex!) : 'NULL'}',
                                style: TextStyle(color: isCorrect ? steamGreen : steamBlood, fontWeight: FontWeight.bold),
                              ),
                              if (!isCorrect) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'REQUIRED OPTIMUM: ${String.fromCharCode(65 + q.correctIndex)}',
                                  style: const TextStyle(color: steamGreen, fontWeight: FontWeight.bold),
                                ),
                              ],
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

// -------------------- STATS SCREEN --------------------

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tests = context.watch<AppState>().tests.where((t) => t.isCompleted).toList(growable: false);

    if (tests.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('TELEMETRY')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border.all(color: steamCopper, width: 2), color: steamParchment),
            child: const Text(
              'INSUFFICIENT DATA.\nEXECUTE PROTOCOLS FIRST.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    int totalQuestions = 0;
    int totalCorrect = 0;
    int totalTimeMs = 0;
    final Map<String, Map<String, num>> categoryStats = {};

    for (final t in tests) {
      totalQuestions += t.questions.length;
      totalCorrect += t.score ?? 0;
      totalTimeMs += t.totalTimeTakenMs;

      final cat = t.category.trim().isEmpty ? 'Unsorted' : t.category.trim();
      categoryStats.putIfAbsent(cat, () => {'qs': 0, 'correct': 0, 'timeMs': 0});
      categoryStats[cat]!['qs'] = categoryStats[cat]!['qs']! + t.questions.length;
      categoryStats[cat]!['correct'] = categoryStats[cat]!['correct']! + (t.score ?? 0);
      categoryStats[cat]!['timeMs'] = categoryStats[cat]!['timeMs']! + t.totalTimeTakenMs;
    }

    final accuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0.0;
    final avgTimePerQuestion = totalQuestions > 0 ? (totalTimeMs / totalQuestions) / 1000 : 0.0;

    final sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) {
        final accA = a.value['qs']! > 0 ? a.value['correct']! / a.value['qs']! : 0.0;
        final accB = b.value['qs']! > 0 ? b.value['correct']! / b.value['qs']! : 0.0;
        return accA.compareTo(accB);
      });

    final weakest = sortedCategories.isNotEmpty ? sortedCategories.first.key : 'N/A';
    final strongest = sortedCategories.isNotEmpty ? sortedCategories.last.key : 'N/A';

    final List<BarChartGroupData> barGroups = [];
    final List<String> xLabels = [];
    int xIndex = 0;
    categoryStats.forEach((category, stats) {
      final catAcc = stats['qs']! > 0 ? (stats['correct']! / stats['qs']!) * 100 : 0.0;
      barGroups.add(
        BarChartGroupData(
          x: xIndex,
          barRods: [
            BarChartRodData(toY: catAcc, color: steamCopper, width: 20, borderRadius: BorderRadius.zero),
          ],
        ),
      );
      xLabels.add(category.length > 10 ? '${category.substring(0, 8)}..' : category);
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
                Expanded(
                  child: _StatCard(
                    title: 'GLOBAL ACCURACY',
                    value: '${accuracy.toStringAsFixed(1)}%',
                    icon: Icons.troubleshoot,
                    color: steamBrass,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'AVG CYCLE/NODE',
                    value: '${avgTimePerQuestion.toStringAsFixed(1)}s',
                    icon: Icons.timer,
                    color: steamCopper,
                  ),
                ),
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
                  const Text(
                    'SECTOR DIAGNOSTICS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamDarkInk, letterSpacing: 2),
                  ),
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
                                final i = val.toInt();
                                if (i >= 0 && i < xLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      xLabels[i],
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: steamDarkInk),
                                    ),
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
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(color: steamDarkInk.withOpacity(0.2), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            bottom: BorderSide(color: steamDarkInk, width: 2),
                            left: BorderSide(color: steamDarkInk, width: 2),
                          ),
                        ),
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: steamParchment),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: steamBrass, letterSpacing: 1)),
        ],
      ),
    );
  }
}

// -------------------- IMPORT --------------------

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DATA INJECTION SUCCESSFUL', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: steamGreen,
        ),
      );
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CORRUPT DATA: $e'), backgroundColor: steamBlood),
      );
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
              child: const Text(
                'WARNING: ENSURE DATA COMPLIES WITH STANDARD PROTOCOL BEFORE INJECTION.',
                style: TextStyle(color: steamBlood, fontWeight: FontWeight.bold),
              ),
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
