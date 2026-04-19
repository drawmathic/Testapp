import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:collection/collection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState()..loadData(),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
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

  Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    this.selectedIndex,
    this.timeTakenMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
        'selectedIndex': selectedIndex,
        'timeTakenMs': timeTakenMs,
      };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        text: json['text'],
        options: List<String>.from(json['options']),
        correctIndex: json['correctIndex'],
        selectedIndex: json['selectedIndex'],
        timeTakenMs: json['timeTakenMs'] ?? 0,
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
    this.dateCompleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'subcategory': subcategory,
        'questions': questions.map((q) => q.toJson()).toList(),
        'score': score,
        'isCompleted': isCompleted,
        'totalTimeTakenMs': totalTimeTakenMs,
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
        dateCompleted: json['dateCompleted'] != null ? DateTime.parse(json['dateCompleted']) : null,
      );
}

// --- STATE MANAGEMENT ---

class AppState extends ChangeNotifier {
  List<TestModel> _tests = [];
  List<TestModel> get tests => _tests;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('app_data');
    if (data != null) {
      final List decoded = jsonDecode(data);
      _tests = decoded.map((e) => TestModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_tests.map((e) => e.toJson()).toList());
    await prefs.setString('app_data', encoded);
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

  void completeTest(TestModel updatedTest) {
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_books), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.data_object), label: 'Import JSON'),
        ],
      ),
    );
  }
}

// --- LIBRARY SCREEN (Category Organization) ---

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tests = context.watch<AppState>().tests;
    final grouped = groupBy(tests, (TestModel t) => t.category);

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: tests.isEmpty
          ? const Center(child: Text('No tests found. Import JSON to begin.'))
          : ListView(
              children: grouped.entries.map((categoryEntry) {
                final subGrouped = groupBy(categoryEntry.value, (TestModel t) => t.subcategory);
                return ExpansionTile(
                  title: Text(categoryEntry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: subGrouped.entries.map((subEntry) {
                    return ExpansionTile(
                      title: Text(subEntry.key),
                      children: subEntry.value.map((test) {
                        return ListTile(
                          leading: Icon(
                            test.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: test.isCompleted ? Colors.green : Colors.grey,
                          ),
                          title: Text(test.title),
                          subtitle: test.isCompleted
                              ? Text('Score: ${test.score}/${test.questions.length}')
                              : const Text('Pending'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editTestCategory(context, test),
                          ),
                          onTap: () {
                            if (!test.isCompleted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTestScreen(test: test)));
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => TestResultScreen(test: test)));
                            }
                          },
                          onLongPress: () {
                            context.read<AppState>().deleteTest(test.id);
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
    );
  }

  void _editTestCategory(BuildContext context, TestModel test) {
    final catCtrl = TextEditingController(text: test.category);
    final subCtrl = TextEditingController(text: test.subcategory);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Organize Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
            TextField(controller: subCtrl, decoration: const InputDecoration(labelText: 'Subcategory')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<AppState>().updateTestCategory(test.id, catCtrl.text, subCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
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
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Deep copy for mutation safely
    _activeTest = TestModel.fromJson(widget.test.toJson());
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stopwatch.stop();
    _timer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    _activeTest.questions[_currentIndex].timeTakenMs += _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();

    if (_currentIndex < _activeTest.questions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    } else {
      _finishTest();
    }
  }

  void _finishTest() {
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

    context.read<AppState>().completeTest(_activeTest);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TestResultScreen(test: _activeTest)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_activeTest.title} - Q${_currentIndex + 1}/${_activeTest.questions.length}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          )
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        itemCount: _activeTest.questions.length,
        itemBuilder: (context, index) {
          final q = _activeTest.questions[index];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(q.text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                ...List.generate(q.options.length, (optIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          q.selectedIndex = optIdx;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: q.selectedIndex == optIdx ? Theme.of(context).colorScheme.primary : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: q.selectedIndex == optIdx ? Theme.of(context).colorScheme.primaryContainer : null,
                        ),
                        child: Text(q.options[optIdx], style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                FilledButton(
                  onPressed: q.selectedIndex != null ? _nextQuestion : null,
                  child: Text(index == _activeTest.questions.length - 1 ? 'Finish' : 'Next'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- RESULT SCREEN ---

class TestResultScreen extends StatelessWidget {
  final TestModel test;
  const TestResultScreen({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results: ${test.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Score', style: Theme.of(context).textTheme.titleLarge),
                  Text('${test.score} / ${test.questions.length}', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 8),
                  Text('Total Time: ${(test.totalTimeTakenMs / 1000).toStringAsFixed(1)}s'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Question Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          ...test.questions.asMap().entries.map((entry) {
            int idx = entry.key;
            Question q = entry.value;
            bool isCorrect = q.selectedIndex == q.correctIndex;
            return Card(
              color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: ListTile(
                leading: Icon(isCorrect ? Icons.check : Icons.close, color: isCorrect ? Colors.green : Colors.red),
                title: Text(q.text),
                subtitle: Text('Your answer: ${q.selectedIndex != null ? q.options[q.selectedIndex!] : 'None'}\nCorrect answer: ${q.options[q.correctIndex]}'),
                trailing: Text('${(q.timeTakenMs / 1000).toStringAsFixed(1)}s'),
              ),
            );
          }),
        ],
      ),
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
        appBar: AppBar(title: const Text('Statistics')),
        body: const Center(child: Text('Complete tests to see statistics.')),
      );
    }

    int totalQuestions = 0;
    int totalCorrect = 0;
    int totalTimeMs = 0;

    for (var t in tests) {
      totalQuestions += t.questions.length;
      totalCorrect += t.score ?? 0;
      totalTimeMs += t.totalTimeTakenMs;
    }

    double accuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0;
    double avgTimePerQuestion = totalQuestions > 0 ? (totalTimeMs / totalQuestions) / 1000 : 0;

    final grouped = groupBy(tests, (TestModel t) => t.category);
    List<BarChartGroupData> barGroups = [];
    int xIndex = 0;
    List<String> xLabels = [];

    grouped.forEach((category, catTests) {
      int cTotal = 0;
      int cCorrect = 0;
      for (var t in catTests) {
        cTotal += t.questions.length;
        cCorrect += t.score ?? 0;
      }
      double catAcc = cTotal > 0 ? (cCorrect / cTotal) * 100 : 0;
      barGroups.add(BarChartGroupData(x: xIndex, barRods: [
        BarChartRodData(toY: catAcc, color: Colors.blueAccent, width: 16, borderRadius: BorderRadius.circular(4))
      ]));
      xLabels.add(category);
      xIndex++;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Overall Accuracy', value: '${accuracy.toStringAsFixed(1)}%')),
                Expanded(child: _StatCard(title: 'Avg Time / Question', value: '${avgTimePerQuestion.toStringAsFixed(1)}s')),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Category Accuracy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
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
                              child: Text(xLabels[val.toInt()], style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import Successful')));
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid JSON: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Tests')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Paste JSON array here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.download),
              label: const Text('Import Data'),
            ),
            TextButton(
              onPressed: () => context.read<AppState>().resetData(),
              child: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}
