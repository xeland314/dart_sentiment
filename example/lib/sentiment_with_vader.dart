import 'package:dart_sentiment/dart_sentiment.dart';

void main() {
  final sentiment = SentimentFactory.fromDartSentiment(
    french: fr,
    english: en,
    emojis: emojis,
    emoticons: emoticon,
  );

  print(sentiment.analysis("The cake she made was terrible 😐"));

  print(sentiment.analysis("The cake she made was terrible 😐"));

  print(sentiment.analysis(
    "I love cats, but I am allergic to them.",
  ));

  print(sentiment.analysis(
    "J'adore les chats, mais j'y suis allergique.",
  ));

  print(sentiment.analysis(
    "Le gâteau qu'elle a fait était horrible 😐",
  ));
}
