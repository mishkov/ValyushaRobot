import 'dart:convert';
import 'dart:io';

class ChatsMeneger {
  final String _dataFile;
  dynamic _chatsData;

  ChatsMeneger(this._dataFile) {
    final fileFormat = '.json';

    if (!_dataFile.endsWith(fileFormat)) {
      throw ChatsMenegerException(
          'File format is incorrect. Should be ".json"!');
    }

    var chatsDataFile = File(_dataFile);
    _chatsData = jsonDecode(chatsDataFile.readAsStringSync());

    if (_chatsData is! List) {
      throw ChatsMenegerException('Data file has no list of chats data!');
    }
  }

  // returns false if chat is not found
  bool editLastTimetableId(int chatId, int newLastTimetableId) =>
      _editField(chatId, 'last_timetable_id', newLastTimetableId);

  // returns false if chat is not found
  bool editPage(int chatId, int newPage) =>
      _editField(chatId, 'timetable_page', newPage);

  // returns false if chat is not found
  bool editSubscribedStatus(int chatId, bool subscribedStatus) =>
      _editField(chatId, 'is_subscribed', subscribedStatus);

  // returns -1 if chat is not found
  dynamic getPage(int chatId) => _getField(chatId, 'timetable_page');

  // returns -1 if chat is not found
  dynamic getLastTimeTableId(int chatId) =>
      _getField(chatId, 'last_timetable_id');

  // returns -1 if chat is not found
  dynamic getSubscribedStatus(int chatId) => _getField(chatId, 'is_subscribed');

  Future<void> forEachAsync(Future Function(dynamic) f) async {
    for (var chat in _chatsData) {
      await f(chat);
    }
  }

  bool isExists(chatId) =>
      _chatsData.indexWhere((chat) => chat['chat_id'] == chatId) >= 0;

  bool isNotExists(chatId) => !isExists(chatId);

  //returs false if chat already exists
  bool addChat(int chatId, {int page = 1, bool subsribedStatus = true}) {
    if (isNotExists(chatId)) {
      var chat = {
        'chat_id': chatId,
        'timetable_page': page,
        'last_timetable_id': -1,
        'is_subscribed': subsribedStatus,
      };

      _chatsData.add(chat);
      _saveChatsData();

      return true;
    } else {
      return false;
    }
  }

  // returns false if chat is not found
  bool _editField(int chatId, String field, dynamic newValue) {
    var chatIndex = _chatsData.indexWhere((chat) => chat['chat_id'] == chatId);

    if (chatIndex >= 0) {
      _chatsData[chatIndex][field] = newValue;
      _saveChatsData();
      return true;
    } else {
      return false;
    }
  }

  //returns true if data was saved without exceptions
  bool _saveChatsData() {
    try {
      var chatsDataFile = File(_dataFile);
      var jsonText = jsonEncode(_chatsData);
      chatsDataFile.writeAsString(jsonText);
      return true;
    } catch (e) {
      throw ChatsMenegerException('When saving chats data $e');
    }
  }

  // returns -1 if chat is not found
  dynamic _getField(int chatId, String field) {
    var chatIndex = _chatsData.indexWhere((chat) => chat['chat_id'] == chatId);
    const notFoundStatus = -1;

    if (chatIndex >= 0) {
      return _chatsData[chatIndex][field];
    } else {
      return notFoundStatus;
    }
  }
}

class ChatsMenegerException implements Exception {
  String cause;

  ChatsMenegerException(this.cause);

  @override
  String toString() => 'ChatsMenegerException:$cause';
}
