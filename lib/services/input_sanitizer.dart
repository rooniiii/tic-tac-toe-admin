/// Cleans free text before it is written to Firestore.
///
/// * Removes control characters (except new lines and tabs).
/// * Hard-limits the length, so oversized input never reaches the database
///   (the security rules enforce the same limits on the server).
///
/// Firestore has no query language built from strings, so SQL injection is
/// not possible; this is an extra layer for everything shown in the game.
class InputSanitizer {
  static final RegExp _controlChars =
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');

  static String clean(String input, {required int maxLength}) {
    var text = input.replaceAll(_controlChars, '').trim();
    if (text.length > maxLength) text = text.substring(0, maxLength);
    return text;
  }

  static bool isSafeHttpsUrl(String? value, {int maxLength = 500}) {
    if (value == null || value.isEmpty || value.length > maxLength) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
