
bool listEquals(List a, List b) {
  if (a.length != b.length) return false;

  for (int i = 0; i < a.length; i++) {
    final ai = a[i];
    final bi = b[i];

    if (ai is List && bi is List) {
      if (!listEquals(ai, bi)) {
        return false;
      }
    } else if (ai is Map && bi is Map) {
      if (!mapEquals(ai, bi)) {
        return false;
      }
    } else if (ai != bi) {
      return false;
    }
  }

  return true;
}

bool mapEquals(Map a, Map b) {
  if (a.length != b.length) return false;

  for (final key in a.keys) {
    if (!b.containsKey(key)) {
      return false;
    }
    final av = a[key];
    final bv = b[key];

    if (av is List && bv is List) {
      if (!listEquals(av, bv)) {
        return false;
      }
    } else if (av is Map && bv is Map) {
      if (!mapEquals(av, bv)) {
        return false;
      }
    } else if (av != bv) {
      return false;
    }
  }

  return true;
}
