#!/bin/sh
# echo -e "\033[0;34mdart test lib/src/lexer/lexer_test.dart \033[0m"
# dart test lib/src/lexer/lexer_test.dart

# echo -e "\n\033[0;34mdart test lib/src/parser/parser_test.dart \033[0m"
# dart test lib/src/parser/parser_test.dart

# echo -e "\n\033[0;34mdart test lib/src/evaluator/evaluator_test.dart \033[0m"
# dart test lib/src/evaluator/evaluator_test.dart

echo -e "\n\033[0;34mdart test lib/src/lexer/lexer_test.dart lib/src/parser/parser_test.dart lib/src/evaluator/evaluator_test.dart lib/src/schema/schema_test.dart lib/src/types/duration/duration_test.dart\033[0m"
dart test lib/src/lexer/lexer_test.dart lib/src/parser/parser_test.dart lib/src/evaluator/evaluator_test.dart lib/src/schema/schema_test.dart lib/src/types/duration/duration_test.dart
