import 'package:test/test.dart';
import './duration.dart';

void main() {
  test("lexerString", () {
    expect(Duration.lexerString("1h"), equals(2));
    expect(Duration.lexerString("1h23m30s"), equals(8));
    expect(Duration.lexerString("109h23m30s15us"), equals(14));
    expect(Duration.lexerString("109h23m30s15us   "), equals(14));
    expect(Duration.lexerString("109h23m30s15ms10us"), equals(null));
    expect(Duration.lexerString("12non"), equals(null));
    expect(Duration.lexerString("12"), equals(null));
    expect(Duration.lexerString("0s"), equals(2));
    expect(Duration.lexerString("0s.12"), equals(2));
    expect(Duration.lexerString("0s   "), equals(2));
  });

  test("lexerString with substring", () {
    final str = "some 23h other";
    final substr = str.substring(5);
    expect(substr, equals("23h other"));
    expect(Duration.lexerString(substr), equals(3));
    expect(str.substring(5, 8), equals("23h"));
  });
}
