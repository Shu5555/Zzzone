class StringConverter {
  // Full-width Katakana to Full-width Hiragana conversion
  static String katakanaToHiragana(String text) {
    return text.split('').map((char) {
      final code = char.codeUnitAt(0);
      // Check if the character is within the Katakana range (ァ to ヶ)
      if (code >= 0x30A1 && code <= 0x30F6) {
        // Convert to Hiragana by subtracting the Unicode offset
        return String.fromCharCode(code - 0x60);
      }
      return char;
    }).join('');
  }
}
