class StudyQuestion {
  const StudyQuestion({
    required this.question,
    required this.referenceAnswer,
  });

  final String question;
  final String referenceAnswer;

  factory StudyQuestion.fromJson(Map<String, dynamic> json) {
    return StudyQuestion(
      question: json['question'] as String? ?? '',
      referenceAnswer: json['referenceAnswer'] as String? ?? '',
    );
  }
}

class StudyResult {
  const StudyResult({
    required this.difficulty,
    required this.questions,
  });

  final String difficulty;
  final List<StudyQuestion> questions;

  factory StudyResult.fromJson(Map<String, dynamic> json) {
    final questionsList = json['questions'] as List<dynamic>? ?? [];
    return StudyResult(
      difficulty: json['difficulty'] as String? ?? 'basic',
      questions: questionsList
          .map((e) => StudyQuestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class HtmlEnhanceResult {
  const HtmlEnhanceResult({
    required this.title,
    required this.lead,
    required this.summary,
    this.rewrittenMarkdown = '',
    required this.sections,
    required this.keyConcepts,
    required this.questions,
  });

  final String title;
  final String lead;
  final String summary;
  final String rewrittenMarkdown;
  final List<HtmlEnhanceSection> sections;
  final List<HtmlEnhanceKeyConcept> keyConcepts;
  final List<HtmlEnhanceQuestion> questions;

  factory HtmlEnhanceResult.fromJson(Map<String, dynamic> json) {
    return HtmlEnhanceResult(
      title: json['title'] as String? ?? '',
      lead: json['lead'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      rewrittenMarkdown: json['rewrittenMarkdown'] as String? ?? '',
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((e) => HtmlEnhanceSection.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      keyConcepts: (json['keyConcepts'] as List<dynamic>? ?? [])
          .map((e) => HtmlEnhanceKeyConcept.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => HtmlEnhanceQuestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class HtmlEnhanceSection {
  const HtmlEnhanceSection({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  factory HtmlEnhanceSection.fromJson(Map<String, dynamic> json) {
    return HtmlEnhanceSection(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class HtmlEnhanceKeyConcept {
  const HtmlEnhanceKeyConcept({
    required this.term,
    required this.definition,
  });

  final String term;
  final String definition;

  factory HtmlEnhanceKeyConcept.fromJson(Map<String, dynamic> json) {
    return HtmlEnhanceKeyConcept(
      term: json['term'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
    );
  }
}

class HtmlEnhanceQuestion {
  const HtmlEnhanceQuestion({
    required this.q,
    required this.a,
  });

  final String q;
  final String a;

  factory HtmlEnhanceQuestion.fromJson(Map<String, dynamic> json) {
    return HtmlEnhanceQuestion(
      q: json['q'] as String? ?? '',
      a: json['a'] as String? ?? '',
    );
  }
}
