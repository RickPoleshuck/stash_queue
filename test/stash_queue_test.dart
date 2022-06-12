import 'package:stash_queue/stash_queue.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final String test1 = 'this is first push';
    final String test2 = 'this is second push';
    final String test3 = 'this is third push';
    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () async {
      final fifo = await FifoQueue.create('/tmp/fifo', 'test');
      await fifo.clear();
      int size = await fifo.size;
      expect(size, 0);

      await fifo.put(test1);
      expect(await fifo.size, 1);

      String result = await fifo.get();
      expect(result, test1);
      expect(await fifo.size, 0);

      await fifo.put(test1);
      await fifo.put(test2);
      await fifo.put(test3);

      expect(await fifo.size, 3);
      result = await fifo.get();
      expect(result, test1);
      expect(await fifo.size, 2);
      result = await fifo.get();
      result = await fifo.get();
      try {
        result = await fifo.get();
        fail('expected exception');
      } catch (e) {
        print(e);
      }
    });
  });
}
