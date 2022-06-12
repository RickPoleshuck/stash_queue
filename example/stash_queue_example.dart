import 'package:stash_queue/stash_queue.dart';

void main() async {
  var fifo = await FifoQueue.create('/directory', 'vaultName');
  int size = await fifo.size;
  print('fifo: $size');
}
