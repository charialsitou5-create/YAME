import 'package:flutter_test/flutter_test.dart';
import 'package:yame/services/error_reporter.dart';

void main() {
  tearDown(ErrorReporter.resetForTest);

  test('report forwards error, stack and context to the sink', () {
    Object? gotError;
    StackTrace? gotStack;
    String? gotContext;
    ErrorReporter.sinkOverride = (e, s, c) {
      gotError = e;
      gotStack = s;
      gotContext = c;
    };
    final st = StackTrace.current;
    ErrorReporter.report('boom', st, context: 'ctx');
    expect(gotError, 'boom');
    expect(gotStack, st);
    expect(gotContext, 'ctx');
  });

  test('report never throws, even if the sink throws', () {
    ErrorReporter.sinkOverride = (_, _, _) => throw StateError('x');
    expect(() => ErrorReporter.report('e', null), returnsNormally);
  });

  test('report without sink in debug/tests does not need Firebase', () {
    expect(() => ErrorReporter.report('e', null, context: 'c'), returnsNormally);
  });
}
