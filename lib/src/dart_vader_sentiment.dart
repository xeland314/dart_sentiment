import 'dart:math' as math;

/// Optimized Sentiment Analyzer (VADER-like implementation)
/// Multi-language support without language detection overhead
class OptimizedSentiment {
// Conjuntos de negaciones (español, inglés, francés, portugués, italiano, alemán)
  static const Set<String> _negations = {
    // Español (Existente)
    "no",
    "nunca",
    "jamás",
    "ni",
    "tampoco",
    "nada",
    "nadie",
    "ninguno",
    "ninguna",
    "ningún",
    "ni siquiera",
    "en absoluto",
    "de ninguna manera",
    "en modo alguno",
    "para nada",
    "ni mucho menos",

    // Inglés (Existente)
    "not",
    "never",
    "neither",
    "nor",
    "nobody",
    "nothing",
    "nowhere",
    "none",
    "hardly",
    "scarcely",
    "barely",
    "rarely",
    "seldom",
    "don't",
    "doesn't",
    "didn't",
    "won't",
    "wouldn't",
    "can't",
    "couldn't",
    "shouldn't",
    "isn't",
    "aren't",
    "wasn't",
    "weren't",
    "haven't",
    "hasn't",
    "hadn't",
    "mustn't",
    "mightn't",
    "shan't",

    // Francés (Français) 🇫🇷
    "ne", // Partícula negativa principal (usar sola es común en chats)
    "pas", // "no" (después del verbo: ne...pas)
    "jamais", // "nunca"
    "rien", // "nada"
    "personne", // "nadie"
    "aucun", // "ninguno"
    "aucune", // "ninguna"
    "guère", // "apenas/casi no"
    "nulle part", // "en ninguna parte"
    "point", // Forma antigua de "pas" (ocasionalmente usada)

    // Portugués (Português) 🇵🇹🇧🇷
    "não", // "no"
    "nem", // "ni"
    "ninguém", // "nadie"
    "nenhum", // "ninguno"
    "nenhuma", // "ninguna"
    "tão pouco", // "tampoco" (también "tampouco")
    "quase não", // "casi no"

    // Italiano (Italiano) 🇮🇹
    "non", // "no"
    "mai", // "nunca"
    "niente", // "nada"
    "nulla", // "nada" (formal)
    "nessuno", // "nadie/ninguno"
    "neppure", // "ni siquiera"
    "neanche", // "ni siquiera"
    "nemmeno", // "ni siquiera"
    "appena", // "apenas/recién" (puede tener sentido de negación)

    // Alemán (Deutsch) 🇩🇪
    "nicht", // "no/no es"
    "nie", // "nunca"
    "kein", // "ninguno" (masculino/neutro)
    "keine", // "ninguna" (femenino)
    "niemand", // "nadie"
    "nichts", // "nada"
    "kaum", // "apenas"
    "selten", // "raramente"
    "weder", // "ni" (en la construcción weder... noch)
  };

  // Patrón de tokenización (palabras y caracteres no-palabra)
  static final RegExp _tokenPattern = RegExp(r'(\w+|[^\s\w])');

  // Diccionario unificado (multi-idioma)
  final Map<String, double> _unifiedLexicon;

  OptimizedSentiment({
    required Map<String, double> unifiedLexicon,
  }) : _unifiedLexicon = unifiedLexicon;

  /// Constructor para combinar múltiples diccionarios
  /// Maneja colisiones promediando scores (estrategia conservadora)
  factory OptimizedSentiment.fromMultipleLexicons(
    List<Map<String, double>> lexicons, {
    CollisionStrategy strategy = CollisionStrategy.average,
  }) {
    final unified = <String, double>{};
    final collisions = <String, List<double>>{};

    // Primera pasada: detectar colisiones
    for (final lexicon in lexicons) {
      for (final entry in lexicon.entries) {
        if (unified.containsKey(entry.key)) {
          collisions.putIfAbsent(entry.key, () => [unified[entry.key]!]);
          collisions[entry.key]!.add(entry.value);
        } else {
          unified[entry.key] = entry.value;
        }
      }
    }

    // Segunda pasada: resolver colisiones
    for (final entry in collisions.entries) {
      final word = entry.key;
      final scores = entry.value;

      switch (strategy) {
        case CollisionStrategy.average:
          unified[word] = scores.reduce((a, b) => a + b) / scores.length;
          break;
        case CollisionStrategy.max:
          unified[word] = scores.reduce((a, b) => a.abs() > b.abs() ? a : b);
          break;
        case CollisionStrategy.first:
          // Ya está asignado el primero, no hacer nada
          break;
        case CollisionStrategy.conservative:
          // Usar el score más cercano a 0 (menos extremo)
          unified[word] = scores.reduce((a, b) => a.abs() < b.abs() ? a : b);
          break;
      }
    }

    return OptimizedSentiment(unifiedLexicon: unified);
  }

  /// Análisis de sentimiento optimizado
  /// Retorna un score normalizado entre -1.0 y 1.0
  double getSentimentScore(String text) {
    if (text.isEmpty) return 0.0;

    final lowerText = text.toLowerCase();
    double score = 0.0;
    int count = 0;
    bool negated = false;
    double intensifierFactor = 1.0;

    // Tokenización
    final tokens =
        _tokenPattern.allMatches(lowerText).map((m) => m.group(0)!).toList();

    // Procesamiento de tokens
    for (final token in tokens) {
      // 1. Detección de negaciones
      if (_negations.contains(token)) {
        negated = true;
        continue;
      }

      // 2. Detección de intensificadores
      final lexiconScore = _unifiedLexicon[token];
      if (lexiconScore != null && lexiconScore.abs() < 1.0) {
        intensifierFactor += lexiconScore.abs();
        continue;
      }

      // 3. Detección de sentimiento
      if (lexiconScore != null && lexiconScore != 0.0) {
        double wordScore = lexiconScore;

        // Aplicar intensificación
        wordScore *= intensifierFactor;

        // Aplicar negación (invierte y reduce impacto)
        if (negated) {
          wordScore *= -0.75; // -1.0 * 0.75
        }

        score += wordScore;
        count++;

        // Reset de modificadores
        negated = false;
        intensifierFactor = 1.0;
      }
    }

    // 4. Reglas de puntuación/mayúsculas (VADER-like)
    double multiplier = 1.0;

    // Exclamaciones
    if (text.contains('!!!')) {
      multiplier *= 1.3;
    } else if (text.contains('!!')) {
      multiplier *= 1.1;
    }

    // Mayúsculas (GRITAR)
    if (text == text.toUpperCase() && text.length > 5) {
      multiplier *= 1.2;
    }

    score *= multiplier;

    // 5. Normalización
    if (count == 0) return 0.0;

    final normalized = score / math.sqrt(count.toDouble());
    return normalized.clamp(-1.0, 1.0);
  }

  /// Análisis detallado con información adicional
  /// Compatible con la interfaz original de dart_sentiment
  Map<String, dynamic> analysis(String text, {bool includeTokens = false}) {
    if (text.isEmpty) {
      return {
        'score': 0.0,
        'comparative': 0.0,
        'tokens': <String>[],
        'positive': <List>[],
        'negative': <List>[],
      };
    }

    final lowerText = text.toLowerCase();
    double score = 0.0;
    int count = 0;
    bool negated = false;
    double intensifierFactor = 1.0;

    final tokens =
        _tokenPattern.allMatches(lowerText).map((m) => m.group(0)!).toList();

    final positive = <List<dynamic>>[];
    final negative = <List<dynamic>>[];

    for (final token in tokens) {
      if (_negations.contains(token)) {
        negated = true;
        continue;
      }

      final lexiconScore = _unifiedLexicon[token];
      if (lexiconScore != null && lexiconScore.abs() < 1.0) {
        intensifierFactor += lexiconScore.abs();
        continue;
      }

      if (lexiconScore != null && lexiconScore != 0.0) {
        final originalScore = lexiconScore;
        double wordScore = lexiconScore;

        wordScore *= intensifierFactor;

        if (negated) {
          wordScore *= -0.75;
        }

        score += wordScore;
        count++;

        // Registrar palabras positivas/negativas
        if (wordScore > 0) {
          positive.add([token, originalScore]);
        } else {
          negative.add([token, originalScore]);
        }

        negated = false;
        intensifierFactor = 1.0;
      }
    }

    // Multiplicadores de puntuación
    double multiplier = 1.0;
    if (text.contains('!!!')) {
      multiplier *= 1.3;
    } else if (text.contains('!!')) {
      multiplier *= 1.1;
    }
    if (text == text.toUpperCase() && text.length > 5) {
      multiplier *= 1.2;
    }

    score *= multiplier;

    // Normalización
    final normalized = count > 0
        ? (score / math.sqrt(count.toDouble())).clamp(-1.0, 1.0)
        : 0.0;

    return {
      'score': normalized,
      'comparative': tokens.isNotEmpty ? normalized / tokens.length : 0.0,
      'tokens': includeTokens ? tokens : <String>[],
      'positive': positive,
      'negative': negative,
      'rawScore': score,
      'wordCount': count,
    };
  }

  /// Versión batch para procesar múltiples textos
  /// Optimizada para grandes volúmenes (como 100k mensajes de WhatsApp)
  List<double> batchGetSentimentScore(List<String> texts) {
    return texts.map((text) => getSentimentScore(text)).toList();
  }

  /// Versión batch con análisis completo
  List<Map<String, dynamic>> batchAnalysis(
    List<String> texts, {
    bool includeTokens = false,
  }) {
    return texts
        .map((text) => analysis(text, includeTokens: includeTokens))
        .toList();
  }

  /// Obtener estadísticas del diccionario unificado
  Map<String, dynamic> getDictionaryStats() {
    final positive = _unifiedLexicon.values.where((v) => v > 0).length;
    final negative = _unifiedLexicon.values.where((v) => v < 0).length;
    final neutral = _unifiedLexicon.values.where((v) => v == 0).length;

    return {
      'totalWords': _unifiedLexicon.length,
      'positive': positive,
      'negative': negative,
      'neutral': neutral,
      'avgScore': _unifiedLexicon.values.reduce((a, b) => a + b) /
          _unifiedLexicon.length,
    };
  }
}

/// Estrategias para manejar colisiones entre diccionarios
enum CollisionStrategy {
  /// Promediar los scores (conservador, recomendado)
  average,

  /// Usar el score más extremo (más sensible)
  max,

  /// Usar el primer valor encontrado (orden de diccionarios importa)
  first,

  /// Usar el score menos extremo (muy conservador)
  conservative,
}

/// Factory para crear instancias con diferentes configuraciones
class SentimentFactory {
  /// Crear analizador combinando diccionarios de dart_sentiment
  ///
  /// Ejemplo:
  /// ```dart
  /// final sentiment = SentimentFactory.fromDartSentiment(
  ///   spanish: es,    // del paquete dart_sentiment
  ///   english: en,
  ///   emojis: emojis,
  ///   emoticons: emoticon,
  /// );
  /// ```
  static OptimizedSentiment fromDartSentiment({
    Map<dynamic, num>? spanish,
    Map<dynamic, num>? english,
    Map<dynamic, num>? french,
    Map<dynamic, num>? german,
    Map<dynamic, num>? italian,
    Map<dynamic, num>? emojis,
    Map<dynamic, num>? emoticons,
    CollisionStrategy strategy = CollisionStrategy.average,
  }) {
    final lexicons = <Map<String, double>>[];

    // Convertir y agregar cada diccionario
    void addLexicon(Map<dynamic, num>? source) {
      if (source != null) {
        final converted = <String, double>{};
        for (final entry in source.entries) {
          converted[entry.key.toString().toLowerCase()] =
              entry.value.toDouble();
        }
        lexicons.add(converted);
      }
    }

    addLexicon(spanish);
    addLexicon(english);
    addLexicon(french);
    addLexicon(german);
    addLexicon(italian);
    addLexicon(emojis);
    addLexicon(emoticons);

    return OptimizedSentiment.fromMultipleLexicons(
      lexicons,
      strategy: strategy,
    );
  }

  /// Crear analizador con diccionario personalizado pre-unificado
  static OptimizedSentiment fromUnifiedLexicon(
    Map<String, double> lexicon,
  ) {
    return OptimizedSentiment(unifiedLexicon: lexicon);
  }
}
