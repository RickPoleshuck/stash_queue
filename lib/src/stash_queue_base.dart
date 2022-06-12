import 'dart:convert';

import 'package:stash/stash_api.dart';
import 'package:stash_file/stash_file.dart';

///
class FifoQueue {
  static const pointerKey = 'ptr';

  FifoQueue._create();

  late Vault<String> _vault;

  Future<void> _init(String storePath, String name) async {
    final store = await newFileLocalVaultStore(path: storePath);
    _vault = await store.vault<String>(name: name);
  }

  static Future<FifoQueue> create(String storePath, String vaultName) async {
    var stashQueue = FifoQueue._create();
    await stashQueue._init(storePath, vaultName);
    return stashQueue;
  }

  Future<int> get size async {
    var ptrRecord = await _getPtrRecord();
    return ptrRecord.size;
  }

  // potentially slow as all files are removed
  Future<void> erase() async {
    while(await size != 0) {
      await get();
    }
  }

  // clear is fast but leaves orphan files
  Future<void> clear() async {
    await _putPtrRecord(PtrRecord(0, 0));
  }

  Future<void> put(String value) async {
    var ptrRecord = await _getPtrRecord();
    await _vault.put(ptrRecord.end.toString(), value);
    ptrRecord.end++;
    await _putPtrRecord(ptrRecord);
  }

  Future<String> get() async {
    var ptrRecord = await _getPtrRecord();
    if (ptrRecord.size <= 0) {
      throw RangeError('FIFO queue is empty');
    }
    String result = await _vault.getAndRemove(ptrRecord.start.toString()) ?? '';
    ptrRecord.start++;
    await _putPtrRecord(ptrRecord);
    return result;
  }

  Future<void> _putPtrRecord(PtrRecord ptrRecord) async {
    await _vault.put(pointerKey, jsonEncode(ptrRecord.toJson()));
    return;
  }

  Future<PtrRecord> _getPtrRecord() async {
    var ptrRecord = await _vault.get(pointerKey);
    ptrRecord ??= '{"size": 0, "start": 0, "end": 0}';
    PtrRecord result = PtrRecord.fromJson(jsonDecode(ptrRecord));
    if (result.size == 0) {
      // don't keep increasing pointers unnecessarily
      result.start = result.end = 0;
    }
    return result;
  }
}

class PtrRecord {
  int start;
  int end;
  get size => end - start;
  PtrRecord(this.start, this.end);

  PtrRecord.fromJson(Map<String, dynamic> json)
      : start = json['start'],
        end = json['end'];

  Map<String, dynamic> toJson() {
    return {
      'size': size,
      'start': start,
      'end': end,
    };
  }
}
