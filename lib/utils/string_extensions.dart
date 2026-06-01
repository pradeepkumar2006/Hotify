extension StringCapitalize on String {
  /// Returns the string with the first character of each word capitalized.
  /// Example: "hello world" -> "Hello World"
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : ''))
        .join(' ');
  }

  /// Returns the string with only the first character capitalized.
  /// Example: "hello" -> "Hello"
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + (length > 1 ? substring(1) : '');
  }
}
