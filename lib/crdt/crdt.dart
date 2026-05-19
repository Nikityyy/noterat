/// Represents a single character node in the CRDT document sequence.
class CrdtChar {
  final String id; // Unique ID formatted as "$clientId:$timestamp:$idx"
  final String position; // Fractional index string used for sorting
  final String value; // The character value itself
  final bool isDeleted; // Tombstone indicator
  final String userId; // The ID of the user who authored this character

  CrdtChar({
    required this.id,
    required this.position,
    required this.value,
    this.isDeleted = false,
    required this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position,
        'value': value,
        'isDeleted': isDeleted,
        'userId': userId,
      };

  factory CrdtChar.fromJson(Map<String, dynamic> json) => CrdtChar(
        id: json['id'] as String,
        position: json['position'] as String,
        value: json['value'] as String,
        isDeleted: json['isDeleted'] as bool? ?? false,
        userId: json['userId'] as String? ?? '',
      );
}

/// String-based fractional indexing for placing nodes between other nodes.
class FractionalIndex {
  static const String minChar = 'a';
  static const String maxChar = 'z';

  /// Generates a position string lexicographically between [before] and [after].
  static String getBetween(String? before, String? after) {
    // If before and after are invalidly ordered, return fallback position
    if (before != null && after != null && before.compareTo(after) >= 0) {
      return before + 'm';
    }

    final String b = before ?? 'a';
    final String a = after ?? '{'; // '{' is 'z' + 1 lexicographically

    int len = 0;
    while (true) {
      final int charBefore = len < b.length ? b.codeUnitAt(len) : 97; // 'a'
      final int charAfter = len < a.length ? a.codeUnitAt(len) : 123; // '{'

      if (charBefore == charAfter) {
        len++;
        continue;
      }

      if (charAfter - charBefore > 1) {
        // Space available: choose the midpoint
        final int mid = charBefore + (charAfter - charBefore) ~/ 2;
        return b.substring(0, len) + String.fromCharCode(mid);
      } else {
        // No space (e.g. 'a' and 'b').
        // If we are at the end of before, we can append a middle character 'm' (109)
        if (len + 1 >= b.length) {
          return b + 'm';
        }
        len++;
      }
    }
  }
}

/// The local document model containing all CRDT character nodes.
class CrdtDoc {
  final Map<String, CrdtChar> _chars = {};

  CrdtDoc();

  /// Gets all character nodes sorted by position string and then by unique ID.
  List<CrdtChar> get sortedChars {
    final list = _chars.values.toList();
    list.sort((c1, c2) {
      final cmp = c1.position.compareTo(c2.position);
      if (cmp != 0) return cmp;
      return c1.id.compareTo(c2.id); // Tie-breaker
    });
    return list;
  }

  /// Gets only active (non-deleted) characters.
  List<CrdtChar> get activeChars {
    return sortedChars.where((c) => !c.isDeleted).toList();
  }

  /// Returns the current plaintext representation of the document.
  String get text {
    return activeChars.map((c) => c.value).join();
  }

  /// Merges a list of new character nodes into the local state.
  void applyChanges(List<CrdtChar> newChars) {
    for (final c in newChars) {
      final existing = _chars[c.id];
      if (existing == null) {
        _chars[c.id] = c;
      } else {
        // If it already exists, tombstones are sticky (once deleted, always deleted)
        if (c.isDeleted && !existing.isDeleted) {
          _chars[c.id] = CrdtChar(
            id: existing.id,
            position: existing.position,
            value: existing.value,
            isDeleted: true,
            userId: existing.userId,
          );
        }
      }
    }
  }

  /// Inserts a string of characters at a specific index in the visible text.
  /// Returns the list of created CrdtChar nodes to be synchronized.
  List<CrdtChar> insert(int index, String value, String userId, String clientId) {
    final active = activeChars;
    final String? beforePos = index > 0 ? active[index - 1].position : null;
    final String? afterPos = index < active.length ? active[index].position : null;

    final updates = <CrdtChar>[];
    String lastPos = beforePos ?? '';

    for (int i = 0; i < value.length; i++) {
      final charVal = value[i];
      final nextPos = FractionalIndex.getBetween(
        lastPos.isEmpty ? null : lastPos,
        afterPos,
      );
      final id = '$clientId:${DateTime.now().microsecondsSinceEpoch}:$i';
      final newChar = CrdtChar(
        id: id,
        position: nextPos,
        value: charVal,
        isDeleted: false,
        userId: userId,
      );
      _chars[id] = newChar;
      updates.add(newChar);
      lastPos = nextPos;
    }
    return updates;
  }

  /// Marks character nodes as deleted (tombstone) starting at a specific index.
  /// Returns the list of updated CrdtChar nodes to be synchronized.
  List<CrdtChar> delete(int index, int count, String userId) {
    final active = activeChars;
    final updates = <CrdtChar>[];
    for (int i = 0; i < count; i++) {
      final targetIdx = index + i;
      if (targetIdx < active.length) {
        final c = active[targetIdx];
        final updatedChar = CrdtChar(
          id: c.id,
          position: c.position,
          value: c.value,
          isDeleted: true,
          userId: userId,
        );
        _chars[c.id] = updatedChar;
        updates.add(updatedChar);
      }
    }
    return updates;
  }

  void clear() {
    _chars.clear();
  }

  Map<String, dynamic> toJson() => {
        'chars': _chars.values.map((c) => c.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    _chars.clear();
    if (json['chars'] != null) {
      for (final item in json['chars']) {
        final c = CrdtChar.fromJson(item as Map<String, dynamic>);
        _chars[c.id] = c;
      }
    }
  }
}

/// Helper class describing text edit diffs.
class TextDiff {
  final int start;
  final int end; // End index in original string
  final String inserted;
  TextDiff(this.start, this.end, this.inserted);

  @override
  String toString() => 'TextDiff(start: $start, end: $end, inserted: "$inserted")';
}

/// Calculates the difference between two strings.
TextDiff calculateDiff(String oldText, String newText) {
  int start = 0;
  while (start < oldText.length && start < newText.length && oldText[start] == newText[start]) {
    start++;
  }

  int oldEnd = oldText.length;
  int newEnd = newText.length;
  while (oldEnd > start && newEnd > start && oldText[oldEnd - 1] == newText[newEnd - 1]) {
    oldEnd--;
    newEnd--;
  }

  return TextDiff(start, oldEnd, newText.substring(start, newEnd));
}
