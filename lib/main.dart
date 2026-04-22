import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
      title: 'Exam Prep App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
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
  int allocatedTimeMs; // Default total time given for the test
  int remainingTimeMs; // State for pause/resume
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
    this.allocatedTimeMs = 3600000, // Default 60 mins
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

  void saveTestProgress(TestModel updatedTest) {
    final idx = _tests.indexWhere((t) => t.id == updatedTest.id);
    if (idx != -1) {
      _tests[idx] = updatedTest;
      saveData();
      notifyListeners(); // Update UI in Library to show "Resume"
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
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.data_object), label: 'Import JSON'),
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
      appBar: AppBar(title: const Text('Exam Library')),
      body: tests.isEmpty
          ? const Center(child: Text('No tests found. Import JSON to begin.'))
          : ListView(
              children: grouped.entries.map((categoryEntry) {
                final subGrouped = groupBy(categoryEntry.value, (TestModel t) => t.subcategory);
                return ExpansionTile(
                  title: Text(categoryEntry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  children: subGrouped.entries.map((subEntry) {
                    return ExpansionTile(
                      title: Text(subEntry.key),
                      children: subEntry.value.map((test) {
                        bool inProgress = !test.isCompleted && test.remainingTimeMs < test.allocatedTimeMs;
                        
                        return ListTile(
                          leading: Icon(
                            test.isCompleted ? Icons.check_circle : (inProgress ? Icons.timelapse : Icons.radio_button_unchecked),
                            color: test.isCompleted ? Colors.green : (inProgress ? Colors.orange : Colors.grey),
                          ),
                          title: Text(test.title),
                          subtitle: test.isCompleted
                              ? Text('Score: ${test.score}/${test.questions.length}')
                              : Text(inProgress ? 'In Progress - Resume' : 'Not Attempted'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
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
                            _confirmDelete(context, test.id);
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

  void _confirmDelete(BuildContext context, String testId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Test?'),
        content: const Text('This will permanently delete this test and its statistics.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AppState>().deleteTest(testId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Deep copy to manipulate without accidentally finalizing until saved
    _activeTest = TestModel.fromJson(widget.test.toJson());
    
    // Mark first question as visited
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time is up! Auto-submitting...'), backgroundColor: Colors.red));
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
        title: const Text('Submit Test?'),
        content: Text(unanswered > 0 ? 'You have $unanswered unanswered questions.\nAre you sure you want to submit?' : 'Ready to submit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finishTest();
            },
            child: const Text('Submit'),
          )
        ],
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
      onPopInvoked: (didPop) {
         _saveProgressOnExit(); // Save on hardware back button
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Q${_currentIndex + 1} / ${_activeTest.questions.length}'),
          actions: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (_activeTest.remainingTimeMs < 300000) ? Colors.red.withOpacity(0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 18, color: (_activeTest.remainingTimeMs < 300000) ? Colors.red : null),
                    const SizedBox(width: 4),
                    Text(
                      timeString,
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: (_activeTest.remainingTimeMs < 300000) ? Colors.red : null
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.grid_view),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                tooltip: 'Question Explorer',
              ),
            ),
          ],
        ),
        endDrawer: _buildQuestionExplorer(),
        body: Column(
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
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(q.text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        ...List.generate(q.options.length, (optIdx) {
                          bool isSelected = q.selectedIndex == optIdx;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: InkWell(
                              onTap: () => setState(() => q.selectedIndex = optIdx),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.2),
                                      child: Text(
                                        String.fromCharCode(65 + optIdx), // A, B, C, D
                                        style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : Colors.black, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(q.options[optIdx], style: const TextStyle(fontSize: 16))),
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
    );
  }

  Widget _buildBottomNavigation() {
    final q = _activeTest.questions[_currentIndex];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _currentIndex > 0 ? () => _goToQuestion(_currentIndex - 1) : null,
              icon: const Icon(Icons.arrow_back_ios, size: 14),
              label: const Text('Prev'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: q.isMarkedForReview ? Colors.purple.withOpacity(0.2) : null,
                foregroundColor: q.isMarkedForReview ? Colors.purple : null,
              ),
              onPressed: () {
                setState(() => q.isMarkedForReview = !q.isMarkedForReview);
              },
              icon: const Icon(Icons.flag),
              label: Text(q.isMarkedForReview ? 'Unmark' : 'Mark Review'),
            ),
            if (_currentIndex < _activeTest.questions.length - 1)
              TextButton(
                onPressed: () => _goToQuestion(_currentIndex + 1),
                child: const Row(children: [Text('Next'), SizedBox(width: 4), Icon(Icons.arrow_forward_ios, size: 14)]),
              )
            else
              FilledButton(
                onPressed: _confirmSubmit,
                child: const Text('Submit'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionExplorer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Questions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context); // close drawer
                      _confirmSubmit();
                    },
                    child: const Text('Submit'),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            // Legend
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LegendItem(color: Colors.green, text: 'Answered'),
                  _LegendItem(color: Colors.red, text: 'Unanswered'),
                  _LegendItem(color: Colors.purple, text: 'Marked'),
                  _LegendItem(color: Colors.grey.shade300, text: 'Not Visited', isLight: true),
                ],
              ),
            ),
            const Divider(height: 1),
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
                  Color bgColor = Colors.grey.shade300;
                  Color textColor = Colors.black;

                  if (q.isMarkedForReview) {
                    bgColor = Colors.purple;
                    textColor = Colors.white;
                  } else if (q.selectedIndex != null) {
                    bgColor = Colors.green;
                    textColor = Colors.white;
                  } else if (q.visited) {
                    bgColor = Colors.red;
                    textColor = Colors.white;
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
                        shape: BoxShape.circle,
                        border: isCurrent ? Border.all(color: Colors.blueAccent, width: 3) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: TextStyle(color: textColor, fontWeight: isCurrent ? FontWeight.bold : null)),
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  final bool isLight;
  const _LegendItem({required this.color, required this.text, this.isLight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: isLight ? Colors.grey.shade700 : null)),
      ],
    );
  }
}

// --- RESULT SCREEN ---

class TestResultScreen extends StatelessWidget {
  final TestModel test;
  const TestResultScreen({super.key, required this.test});

  @override
  Widget build(BuildContext context) {
    int unattempted = test.questions.where((q) => q.selectedIndex == null).length;
    int incorrect = test.questions.length - (test.score ?? 0) - unattempted;

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
                  Text('Overall Score', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${test.score} / ${test.questions.length}', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ResultPill(title: 'Correct', count: test.score ?? 0, color: Colors.green),
                      _ResultPill(title: 'Incorrect', count: incorrect, color: Colors.red),
                      _ResultPill(title: 'Unattempted', count: unattempted, color: Colors.grey),
                    ],
                  ),
                  const Divider(height: 32),
                  Text('Time Taken: ${(test.totalTimeTakenMs / 60000).toStringAsFixed(1)} Mins'),
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
            bool isAttempted = q.selectedIndex != null;

            Color tileColor = isAttempted ? (isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)) : Colors.grey.withOpacity(0.1);
            IconData icon = isAttempted ? (isCorrect ? Icons.check_circle : Icons.cancel) : Icons.remove_circle;
            Color iconColor = isAttempted ? (isCorrect ? Colors.green : Colors.red) : Colors.grey;

            return Card(
              color: tileColor,
              child: ExpansionTile(
                leading: Icon(icon, color: iconColor),
                title: Text('Q${idx + 1}. ${q.text}', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('Time: ${(q.timeTakenMs / 1000).toStringAsFixed(1)}s'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Text('Your Answer: ${isAttempted ? q.options[q.selectedIndex!] : 'None'}', style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (!isCorrect) Text('Correct Answer: ${q.options[q.correctIndex]}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Container(
          margin: const EdgeInsets.top: 4,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
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
        appBar: AppBar(title: const Text('Advanced Analytics')),
        body: const Center(child: Text('Complete tests to see your performance statistics.')),
      );
    }

    int totalQuestions = 0;
    int totalCorrect = 0;
    int totalTimeMs = 0;

    // Advanced category tracking
    Map<String, Map<String, num>> categoryStats = {};

    for (var t in tests) {
      totalQuestions += t.questions.length;
      totalCorrect += t.score ?? 0;
      totalTimeMs += t.totalTimeTakenMs;

      if (!categoryStats.containsKey(t.category)) {
        categoryStats[t.category] = {'qs': 0, 'correct': 0, 'timeMs': 0};
      }
      categoryStats[t.category]!['qs'] = categoryStats[t.category]!['qs']! + t.questions.length;
      categoryStats[t.category]!['correct'] = categoryStats[t.category]!['correct']! + (t.score ?? 0);
      categoryStats[t.category]!['timeMs'] = categoryStats[t.category]!['timeMs']! + t.totalTimeTakenMs;
    }

    double accuracy = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0;
    double avgTimePerQuestion = totalQuestions > 0 ? (totalTimeMs / totalQuestions) / 1000 : 0;

    // Sort categories by accuracy for Strong/Weak insights
    var sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) {
        double accA = a.value['qs']! > 0 ? a.value['correct']! / a.value['qs']! : 0;
        double accB = b.value['qs']! > 0 ? b.value['correct']! / b.value['qs']! : 0;
        return accA.compareTo(accB); // Ascending: Weakest first
      });

    String weakest = sortedCategories.first.key;
    String strongest = sortedCategories.last.key;

    List<BarChartGroupData> barGroups = [];
    int xIndex = 0;
    List<String> xLabels = [];

    categoryStats.forEach((category, stats) {
      double catAcc = stats['qs']! > 0 ? (stats['correct']! / stats['qs']!) * 100 : 0;
      barGroups.add(BarChartGroupData(x: xIndex, barRods: [
        BarChartRodData(toY: catAcc, color: Colors.blueAccent, width: 20, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)))
      ]));
      xLabels.add(category.length > 8 ? '${category.substring(0, 6)}..' : category);
      xIndex++;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Overview Cards
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Overall Accuracy', value: '${accuracy.toStringAsFixed(1)}%', icon: Icons.troubleshoot, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Avg Time / Q', value: '${avgTimePerQuestion.toStringAsFixed(1)}s', icon: Icons.timer, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(title: 'Strongest', value: strongest, icon: Icons.trending_up, color: Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(title: 'Weakest', value: weakest, icon: Icons.trending_down, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Category Accuracy Graph', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text('In-Depth Category Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ...categoryStats.entries.map((e) {
              double acc = e.value['qs']! > 0 ? (e.value['correct']! / e.value['qs']!) * 100 : 0;
              double time = e.value['qs']! > 0 ? (e.value['timeMs']! / e.value['qs']!) / 1000 : 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${acc.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: acc > 70 ? Colors.green : (acc > 40 ? Colors.orange : Colors.red))),
                            const Text('Accuracy', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${time.toStringAsFixed(1)}s', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Avg Time', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                  hintText: 'Paste JSON array here...\n\nExample Format:\n[\n  {\n    "id": "1",\n    "title": "Mock Test 1",\n    "category": "Physics",\n    "subcategory": "Mechanics",\n    "allocatedTimeMs": 3600000,\n    "questions": [\n      {\n        "text": "What is Newton\\'s second law?",\n        "options": ["F=ma", "E=mc^2", "v=u+at", "W=Fs"],\n        "correctIndex": 0\n      }\n    ]\n  }\n]',
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
              onPressed: () {
                context.read<AppState>().resetData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data cleared')));
              },
              child: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}
