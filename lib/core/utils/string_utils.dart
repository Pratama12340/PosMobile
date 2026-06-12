class StringUtils {
  static String getInitials(String name) {
    if (name.isEmpty) return "??";
    List<String> names = name.trim().split(' ');
    if (names.isEmpty) return "??";
    if (names.length == 1) {
      return names[0].isNotEmpty ? names[0].substring(0, 1).toUpperCase() : "?";
    }
    return (names[0][0] + names[1][0]).toUpperCase();
  }
}
