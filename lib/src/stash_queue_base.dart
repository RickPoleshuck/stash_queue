import 'dart:convert';
import 'dart:io';

import 'package:stash/stash_api.dart';
import 'package:stash_file/stash_file.dart';

///
class FifoQueue {
  static const pointerKey = 'ptr';

  FifoQueue._create();

  late Vault<String> _vault;
  late RandomAccessFile _fileLock;

  Future<void> _init(String storePath, String name) async {
    final store = await newFileLocalVaultStore(path: storePath);
    _vault = await store.vault<String>(name: name);
    _fileLock = File('$storePath/$name/lock').openSync(mode: FileMode.write);
  }

  static Future<FifoQueue> create(String storePath, String vaultName) async {
    var stashQueue = FifoQueue._create();
    await stashQueue._init(storePath, vaultName);
    return stashQueue;
  }

  Future<int> get size async {
    try {
      _fileLock.lockSync(FileLock.exclusive);
      var ptrRecord = await _getPtrRecord();
      return ptrRecord.size;
    } finally {
      _fileLock.unlockSync();
    }
  }

  // potentially slow as all files are removed
  Future<void> erase() async {
    try {
      _fileLock.lockSync(FileLock.exclusive);
      while (await size != 0) {
        await get();
      }
    } finally {
      _fileLock.unlockSync();
    }
  }

  // clear is fast but leaves orphan files
  Future<void> clear() async {
    try {
      _fileLock.lockSync(FileLock.blockingExclusive);
      PtrRecord ptrRecord = await _getPtrRecord();
      if (ptrRecord.size > 0) {
        await _putPtrRecord(PtrRecord(0, 0));
      }
    } finally {
      _fileLock.unlockSync();
    }
  }

  Future<void> put(String value) async {
    try {
      _fileLock.lockSync(FileLock.blockingExclusive);
      var ptrRecord = await _getPtrRecord();
      await _vault.put(ptrRecord.end.toString(), value);
      ptrRecord.end++;
      await _putPtrRecord(ptrRecord);
    } finally {
      _fileLock.unlockSync();
    }
  }

  Future<String> get() async {
    try {
      _fileLock.lockSync(FileLock.exclusive);
      var ptrRecord = await _getPtrRecord();
      if (ptrRecord.size <= 0) {
        throw RangeError('FIFO queue is empty');
      }
      String result = await _vault.getAndRemove(ptrRecord.start.toString()) ?? '';
      ptrRecord.start++;
      await _putPtrRecord(ptrRecord);
      return result;
    } finally {
      _fileLock.unlockSync();
    }
  }

  Future<void> _putPtrRecord(PtrRecord ptrRecord) async {
    await _vault.put(pointerKey, jsonEncode(ptrRecord.toJson()));
    return;
  }

  Future<PtrRecord> _getPtrRecord() async {
    var ptrStr = await _vault.get(pointerKey);
    ptrStr ??= '{"s": 0, "e": 0}';
    PtrRecord ptrRecord = PtrRecord.fromJson(jsonDecode(ptrStr));
    if (ptrRecord.size == 0) {
      // don't keep increasing pointers unnecessarily
      ptrRecord.start = ptrRecord.end = 0;
    }
    return ptrRecord;
  }
}

class PtrRecord {
  int start;
  int end;

  get size => end - start;

  PtrRecord(this.start, this.end);

  PtrRecord.fromJson(Map<String, dynamic> json)
      : start = json['s'],
        end = json['e'];

  Map<String, dynamic> toJson() {
    return {
      's': start,
      'e': end,
    };
  }
}
