

# Dart Sentiment

![Flutter Community: dart_sentiment](https://fluttercommunity.dev/_github/header/dart_sentiment)


![pub package](https://img.shields.io/pub/v/dart_sentiment.svg)      ![](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)


#### AFINN-based sentiment analysis for dart

Dart Sentiment is a dart package that uses  
the  [AFINN-165](https://github.com/fnielsen/afinn/blob/master/afinn/data/AFINN-en-165.txt)  
wordlist  
and  [Emoji Sentiment Ranking](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0144296)  
to perform  [sentiment analysis](https://en.wikipedia.org/wiki/Sentiment_analysis)  on arbitrary  
blocks of input text. Dart Sentiment provides several things:
- Provide Language support for English, Italian, French, German and Spanish.
- Provide support for various emojis and emoticons.
- Based on analysis of text, provide an integer value in the range -n to +n (see details below)
- **NEW:** VADER-like algorithm with negation handling, intensifiers, and multi-language support

## Installation
add following dependency to your `pubspec.yaml`
```yaml  
  
dependencies:    
   dart_sentiment: <latest-version>  
   
 ```   

## Example

### Basic Usage (Original AFINN Algorithm)
```dart

 import 'package:dart_sentiment/dart_sentiment.dart';    
 void main() {
 
	 final sentiment = Sentiment();    
    
	 print(sentiment.analysis("The cake she made was terrible 😐"));    
    
	 print(sentiment.analysis("The cake she made was terrible 😐", emoji: true));    
    
	 print(sentiment.analysis("I love cats, but I am allergic to them.",));    
    
	 print(sentiment.analysis("J'adore les chats, mais j'y suis allergique.",    
	 languageCode: LanguageCode.french));    
    
	print(sentiment.analysis("Le gâteau qu'elle a fait était horrible 😐",    
	emoji: true, languageCode: LanguageCode.french)); 

}  

```

### Advanced Usage (Optimized VADER-like Algorithm)

The new `OptimizedSentiment` class provides enhanced sentiment analysis with:
- **Negation handling**: Detects negations like "not", "no", "nunca" and inverts sentiment
- **Intensifiers**: Recognizes words that amplify sentiment (e.g., "very", "extremely", "muy")
- **Punctuation rules**: Exclamation marks and capitalization affect sentiment strength
- **Multi-language support**: Works with mixed-language text without language detection overhead
- **Batch processing**: Optimized for processing thousands of messages efficiently

```dart
import 'package:dart_sentiment/dart_sentiment.dart';
import 'package:dart_sentiment/optimized_sentiment.dart';

void main() {
  // Initialize with unified multi-language lexicon
  final sentiment = SentimentFactory.fromDartSentiment(
    spanish: es,        // Spanish lexicon
    english: en,        // English lexicon
    emojis: emojis,     // Emoji sentiment
    emoticons: emoticon, // Emoticon sentiment
    strategy: CollisionStrategy.average, // Handle word collisions
  );

  // Simple sentiment score (-1.0 to 1.0)
  double score = sentiment.getSentimentScore(
    "I don't like this! 😞"
  );
  print('Score: $score'); // Negative due to negation

  // Detailed analysis
  var result = sentiment.analysis(
    "Me gusta mucho! Very good 👍",
    includeTokens: true,
  );
  print(result);
  // {
  //   score: 0.85,
  //   comparative: 0.12,
  //   tokens: [me, gusta, mucho, very, good, 👍],
  //   positive: [[gusta, 2], [mucho, 0.8], [good, 3], [👍, 1]],
  //   negative: [],
  //   rawScore: 6.8,
  //   wordCount: 4
  // }

  // Batch processing for large datasets (e.g., 10k WhatsApp messages)
  List<String> messages = [
    "Great service!!!",
    "No me gustó nada",
    "Excelente producto 😊",
    // ... thousands more
  ];
  
  List<double> scores = sentiment.batchGetSentimentScore(messages);
  print('Processed ${scores.length} messages');

  // Dictionary statistics
  print(sentiment.getDictionaryStats());
  // {totalWords: 10234, positive: 4521, negative: 4102, neutral: 1611, ...}
}
```

### Collision Strategies

When combining multiple language lexicons, words may have different sentiment scores. Choose a strategy:

```dart
// Average scores (recommended for balanced analysis)
CollisionStrategy.average

// Use the most extreme score (more sensitive)
CollisionStrategy.max

// Use the first score found (language priority matters)
CollisionStrategy.first

// Use the least extreme score (conservative)
CollisionStrategy.conservative
```


### Function defination
Param | Description
-------- | ----- 
`String text` | Input phrase to analyze
`bool emoji = false` | Input emoji is present in the phrase to analyze
`LanguageCode languageCode = LanguageCode.english` |Language to use for sentiment analysis. ` LanguageCode { english, italian, french, german, spanish }`

#### OptimizedSentiment Class
Method | Parameters | Returns | Description
-------- | ----- | ----- | -----
`getSentimentScore` | `String text` | `double` | Fast sentiment score between -1.0 and 1.0
`analysis` | `String text, {bool includeTokens}` | `Map<String, dynamic>` | Detailed analysis with positive/negative words
`batchGetSentimentScore` | `List<String> texts` | `List<double>` | Process multiple texts efficiently
`batchAnalysis` | `List<String> texts, {bool includeTokens}` | `List<Map>` | Detailed analysis for multiple texts
`getDictionaryStats` | - | `Map<String, dynamic>` | Statistics about the loaded lexicon

## How it works

### AFINN (Original Algorithm)

AFINN is a list of words rated for valence with an integer between minus five (negative) and plus  
five (positive). Sentiment analysis is performed by cross-checking the string tokens (words, emojis)  
with the AFINN list and getting their respective scores. The comparative score is  
simply:  `sum of each token / number of tokens`. So for example let's take the following:

`I love cats, but I am allergic to them.`

That string results in the following:

```dart
{
    score: 1, 
	comparative: 0.1111111111111111,  
    tokens: [    
       "i",    
       "love",    
       "cats",    
       "but",    
       "i",    
       "am",    
       "allergic",    
       "to",    
       "them"    
    ],
    positive: [[love, 3]], 
    negative: [[allergic, 2]]
} 
``` 

### VADER-like Algorithm (OptimizedSentiment)

The optimized algorithm extends AFINN with additional rules inspired by VADER (Valence Aware Dictionary and sEntiment Reasoner):

1. **Negation Detection**: Words like "not", "no", "never", "nunca" invert and reduce the sentiment of the following word
2. **Intensifiers**: Words like "very", "extremely", "muy" amplify sentiment strength
3. **Punctuation Rules**: 
   - Multiple exclamation marks increase sentiment intensity (!! = 1.1x, !!! = 1.3x)
   - ALL CAPS text increases sentiment intensity by 1.2x
4. **Normalization**: Scores are normalized using square root of word count and clamped to [-1.0, 1.0]

Example:
```
"I don't like this!!!" 
→ "like" (positive) + negation ("don't") + intensifier (!!!)
→ Negative sentiment with high confidence
```

### Returned Objects

- **Score**: Normalized sentiment score (OptimizedSentiment: -1.0 to 1.0, Original: sum of values)
- **Comparative**: Comparative score of the input string
- **Tokens**: All the tokens like words or emojis found in the input string
- **Positive**: List of positive words in input string that were found in lexicon
- **Negative**: List of negative words in input string that were found in lexicon
- **RawScore**: (OptimizedSentiment only) Pre-normalized score
- **WordCount**: (OptimizedSentiment only) Number of sentiment-bearing words found

## Contribute

If you have any suggestions, improvements or issues, feel free to contribute to this project. You  
can either submit a new issue or propose a pull request. Direct your pull requests into the dev  
branch.

## License

Dart Sentiment is released under  
the  [MIT License](https://github.com/akashlilhare/dart_sentiment/blob/main/LICENSE)

## Credit

Dart Sentiment inspired by the Javascript  
package [sentiment](https://www.npmjs.com/package/sentiment)

## Contributors

### Original Author
**Akash Lilhare** - India based Flutter developer

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/akash-lilhare-739a80192)   [![Gmail](https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white)](mailto:akashlilhare14@gmail.com) [![Twitter](https://img.shields.io/badge/Twitter-1DA1F2?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/akash__lilhare) [![Website](https://img.shields.io/badge/website-000000?style=for-the-badge&logo=About.me&logoColor=white)](https://akash-lilhare.netlify.app)

### Contributors
**Christopher Villamarín (xeland314)** - Ecuador based developer
- Enhanced Spanish lexicon with additional sentiment words
- Implemented VADER-like algorithm with negation and intensifiers
- Added emoticon support and multi-language collision handling
- Optimized batch processing for large-scale message analysis

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/christopher-villamarin)   [![Gmail](https://img.shields.io/badge/Protonmail-0077B5?style=for-the-badge&logo=protonmail&logoColor=white)](mailto:christopher.villamarin@protonmail.com)[![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/xeland314) [![Website](https://img.shields.io/badge/website-000000?style=for-the-badge&logo=About.me&logoColor=white)](https://xeland314.github.io)
