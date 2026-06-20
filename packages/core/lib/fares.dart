const Map<String, Map<String, int>> _shareTable = {
  'A': {'A': 10, 'B': 10, 'C': 10, 'D': 10, 'E': 15},
  'B': {'A': 10, 'B': 10, 'C': 10, 'D': 10, 'E': 12},
  'C': {'A': 10, 'B': 10, 'C': 10, 'D': 10, 'E': 10},
  'D': {'A': 10, 'B': 10, 'C': 10, 'D': 10, 'E': 10},
  'E': {'A': 15, 'B': 12, 'C': 10, 'D': 10, 'E': 10},
};

const Map<String, Map<String, int>> _reserveTable = {
  'A': {'A': 20, 'B': 25, 'C': 25, 'D': 30, 'E': 35},
  'B': {'A': 25, 'B': 20, 'C': 25, 'D': 25, 'E': 30},
  'C': {'A': 25, 'B': 25, 'C': 20, 'D': 25, 'E': 25},
  'D': {'A': 30, 'B': 25, 'C': 25, 'D': 20, 'E': 25},
  'E': {'A': 35, 'B': 30, 'C': 25, 'D': 25, 'E': 20},
};

/// Returns the fare in rupees. mode = 'reserve' or 'share'.
/// Night surcharge (+₹5) applies 21:00–06:00.
int getFare(String from, String to, String mode, bool isNight) {
  final table = mode == 'reserve' ? _reserveTable : _shareTable;
  final base = table[from]?[to] ?? 10;
  return base + (isNight ? 5 : 0);
}

bool isNightTime(DateTime dt) {
  final h = dt.hour;
  return h >= 21 || h < 6;
}
