class AnalysisResult {
  final List<String> prosA;
  final List<String> consA;
  final List<String> prosB;
  final List<String> consB;
  final String swotSummary;

  AnalysisResult({
    required this.prosA,
    required this.consA,
    required this.prosB,
    required this.consB,
    required this.swotSummary,
  });
}

class AIAnalysisService {
  static AnalysisResult generate(String a, String b) {
    // Dito natin nilalagay ang logic na parang AI
    String optionA = a.toLowerCase();
    String optionB = b.toLowerCase();

    // Default values
    List<String> pA = ["Reliable", "Proven Track Record"];
    List<String> cA = ["Higher Cost", "Traditional Approach"];
    List<String> pB = ["Innovative", "Cost-Effective"];
    List<String> cB = ["Riskier", "Less Experience"];
    String summary = "Both options have unique strengths. $a offers stability while $b brings a fresh perspective.";

    // Custom logic base sa keywords
    if (optionA.contains('career') || optionB.contains('business')) {
      pA = ["Stable Income", "Professional Growth", "Benefits"];
      cA = ["Fixed Hours", "Limited Creative Control"];
      pB = ["Unlimited Income", "Flexible Time", "Ownership"];
      cB = ["Financial Risk", "High Stress", "No Fixed Salary"];
      summary = "A choice between Security (Career) and Freedom (Business).";
    }
    else if (optionA.contains('iphone') || optionB.contains('android')) {
      pA = ["Premium Build", "High Resale Value", "Ecosystem"];
      cA = ["Expensive", "Closed System"];
      pB = ["Customizable", "Diverse Hardware", "Better File Management"];
      cB = ["Frequent Price Drop", "Inconsistent Updates"];
      summary = "Iphone leads in luxury, while Android dominates in flexibility.";
    }

    return AnalysisResult(
      prosA: pA,
      consA: cA,
      prosB: pB,
      consB: cB,
      swotSummary: summary,
    );
  }
}