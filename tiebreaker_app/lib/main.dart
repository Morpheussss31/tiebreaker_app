import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TiebreakerApp());
}

class TiebreakerApp extends StatelessWidget {
  const TiebreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Scenario Tiebreaker Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0B1F),
        primaryColor: Colors.cyanAccent,
      ),
      home: const HomeScreen(),
    );
  }
}

// --- Data Model ---
class AIAnalysisResult {
  final List<String> entities;
  final Map<String, List<String>> pros;
  final Map<String, List<String>> cons;
  final String betterReason;
  final String winner;

  AIAnalysisResult({
    required this.entities,
    required this.pros,
    required this.cons,
    required this.betterReason,
    required this.winner,
  });

  Map<String, dynamic> toJson() => {
    'entities': entities,
    'pros': pros,
    'cons': cons,
    'betterReason': betterReason,
    'winner': winner,
  };

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) => AIAnalysisResult(
    entities: List<String>.from(json['entities']),
    pros: (json['pros'] as Map).map((k, v) => MapEntry(k as String, List<String>.from(v))),
    cons: (json['cons'] as Map).map((k, v) => MapEntry(k as String, List<String>.from(v))),
    betterReason: json['betterReason'],
    winner: json['winner'],
  );
}

// --- AI Service ---
class AIAnalysisService {
  static const String _apiKey = 'AIzaSyCVdB-Qe7ME5jhStV_xngVfcvXGJtPVptw';

  static Future<AIAnalysisResult> analyzeWithGemini(String scenario) async {
    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

    final prompt = """
    Scenario: $scenario
    Analyze the options in this scenario. 
    
    IMPORTANT: Use EXACTLY 'Pros_1:', 'Cons_1:', 'Pros_2:', 'Cons_2:' as labels for the options in the order they appear.
    
    Format:
    Entities: OptionName1, OptionName2
    Winner: The exact name of the winner
    Pros_1: Highlight: Explanation | Highlight: Explanation
    Cons_1: Highlight: Explanation | Highlight: Explanation
    Pros_2: Highlight: Explanation | Highlight: Explanation
    Cons_2: Highlight: Explanation | Highlight: Explanation
    Reason: Detailed explanation.
    """;

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final text = response.text ?? "";

      String entitiesRaw = _parseField(text, "Entities:");
      List<String> entities = entitiesRaw.split(',').map((e) => e.trim()).toList();

      String winner = _parseField(text, "Winner:").trim();

      Map<String, List<String>> prosMap = {};
      Map<String, List<String>> consMap = {};

      for (int i = 0; i < entities.length; i++) {
        String entityName = entities[i];
        int index = i + 1;
        prosMap[entityName] = _parseList(text, "Pros_$index:");
        consMap[entityName] = _parseList(text, "Cons_$index:");
      }

      String reason = _parseField(text, "Reason:");

      final result = AIAnalysisResult(
        entities: entities,
        pros: prosMap,
        cons: consMap,
        betterReason: reason,
        winner: winner != "N/A" ? winner : (entities.isNotEmpty ? entities[0] : "AI Choice"),
      );

      _saveToHistory(result);
      return result;
    } catch (e) {
      throw Exception("AI Analysis Failed: $e");
    }
  }

  static String _parseField(String text, String field) {
    final cleanText = text.replaceAll('*', '');
    if (!cleanText.contains(field)) return "N/A";
    final startIndex = cleanText.indexOf(field) + field.length;
    final remainingText = cleanText.substring(startIndex);

    final nextLabels = ["Entities:", "Winner:", "Pros_1:", "Cons_1:", "Pros_2:", "Cons_2:", "Reason:"];
    int nearestIndex = remainingText.length;
    for (var label in nextLabels) {
      int idx = remainingText.indexOf(label);
      if (idx != -1 && idx < nearestIndex) nearestIndex = idx;
    }

    return remainingText.substring(0, nearestIndex).trim();
  }

  static List<String> _parseList(String text, String field) {
    String raw = _parseField(text, field);
    if (raw == "N/A" || raw.isEmpty || raw.length < 5) return ["Sinusuri pa ang detalye..."];
    return raw.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static Future<void> _saveToHistory(AIAnalysisResult result) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('analysis_history') ?? [];
    history.insert(0, jsonEncode(result.toJson()));
    if (history.length > 10) history.removeLast();
    await prefs.setStringList('analysis_history', history);
  }
}

// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController scenarioController = TextEditingController();
  bool isLoading = false;

  void decide() async {
    if (scenarioController.text.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final result = await AIAnalysisService.analyzeWithGemini(scenarioController.text);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(result: result)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Background3D(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, size: 60, color: Colors.cyanAccent),
                  const Text("AI TIEBREAKER", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: scenarioController,
                          maxLines: null,
                          style: const TextStyle(fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: "Input the Scenario Here...",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : decide,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("ANALYZE NOW", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    child: const Text("View History Log", style: TextStyle(color: Colors.white70)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Result Screen ---
class ResultScreen extends StatefulWidget {
  final AIAnalysisResult result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String _activeTab = 'summary';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Background3D(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _tabButton('SUMMARY', 'summary'),
                        const SizedBox(width: 10),
                        _tabButton('PROS & CONS', 'proscons'),
                        const SizedBox(width: 10),
                        _tabButton('SWOT', 'swot'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildContent(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white54),
                    label: const Text("BACK", style: TextStyle(color: Colors.white54)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, String tabKey) {
    bool isActive = _activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.cyanAccent : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.cyanAccent : Colors.white10),
          boxShadow: isActive ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case 'summary':
        return _buildSummary();
      case 'proscons':
        return _buildProsCons();
      case 'swot':
        return _buildSWOT();
      default:
        return _buildSummary();
    }
  }

  Widget _buildSummary() {
    return Column(
      children: [
        const Center(child: Text("AI RECOMMENDATION", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2, fontWeight: FontWeight.bold))),
        const SizedBox(height: 10),
        Center(
          child: Text(widget.result.winner.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(height: 30),
        const Align(alignment: Alignment.centerLeft, child: Text("SUMMARY & REASONING", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))),
        const SizedBox(height: 10),
        GlassContainer(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(widget.result.betterReason, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  Widget _buildProsCons() {
    return Column(
      children: widget.result.entities.map((entity) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entity.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
              const SizedBox(height: 10),
              GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _sectionTitle("STRENGTHS", Colors.greenAccent),
                      ...widget.result.pros[entity]!.map((p) => _buildPoint(p)),
                      const Divider(color: Colors.white10, height: 30),
                      _sectionTitle("WEAKNESSES", Colors.orangeAccent),
                      ...widget.result.cons[entity]!.map((c) => _buildPoint(c)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSWOT() {
    return Column(
      children: [
        const Text("SWOT COMPARISON", style: TextStyle(color: Colors.cyanAccent, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ...widget.result.entities.map((entity) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: GlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(entity.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _swotMiniBox("STRENGTHS", widget.result.pros[entity]!, Colors.greenAccent)),
                        const SizedBox(width: 10),
                        Expanded(child: _swotMiniBox("WEAKNESSES", widget.result.cons[entity]!, Colors.orangeAccent)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildPoint(String text) {
    final parts = text.split(':');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
          children: [
            const TextSpan(text: "• ", style: TextStyle(color: Colors.cyanAccent)),
            if (parts.length > 1) TextSpan(text: "${parts[0].trim()}: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: parts.length > 1 ? parts.sublist(1).join(':').trim() : text),
          ],
        ),
      ),
    );
  }

  Widget _swotMiniBox(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        ...items.take(2).map((item) => Text(
          "• ${item.split(':')[0]}",
          style: const TextStyle(fontSize: 11, color: Colors.white54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )),
      ],
    );
  }
}

// --- History Screen ---
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<AIAnalysisResult>> _getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('analysis_history') ?? [];
    return history.map((e) => AIAnalysisResult.fromJson(jsonDecode(e))).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History Log"), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          const Background3D(),
          FutureBuilder<List<AIAnalysisResult>>(
            future: _getHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No history log found."));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassContainer(
                      child: ListTile(
                        leading: const Icon(Icons.history, color: Colors.cyanAccent),
                        title: Text("Winner: ${item.winner}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Options: ${item.entities.join(' vs ')}"),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(result: item))),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- UI HELPERS ---
class GlassContainer extends StatelessWidget {
  final Widget child;
  const GlassContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}

class Background3D extends StatelessWidget {
  const Background3D({super.key});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: -100, right: -50, child: _blob(220, Colors.deepPurple)),
        Positioned(bottom: -100, left: -50, child: _blob(220, Colors.cyanAccent)),
      ],
    );
  }

  Widget _blob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.25)),
  );
}