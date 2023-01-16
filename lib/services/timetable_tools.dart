import 'dart:io';

import 'package:teledart/telegram.dart';
import 'package:valyusha_robot/repeat_until_success.dart';
import 'package:valyusha_robot/services/logger.dart';
import 'package:valyusha_robot/services/chats_meneger.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:crypto/crypto.dart';

Future<String> getTimetableFileUrl(Logger outputLog) async {
  var baseUrl = 'https://www.mrk-bsuir.by/ru';
  var response;
  try {
    response = await http.get(Uri.parse(baseUrl));
  } catch (e) {
    await outputLog.log('When running GET request $e',
        status: RecordStatus.error);
    return '';
  }

  final successStatus = 200;
  if (response.statusCode == successStatus) {
    var document = parse(response.body);
    var element = document.getElementById('rasp');
    try {
      var timetableFileUrl = element.attributes['href'];
      return timetableFileUrl;
    } catch (e) {
      await outputLog.log('Get timetable file url is failed $e',
          status: RecordStatus.error);
    }
  }

  return '';
}

Future<bool> downloadTimetable(String fileNameToSave, Logger outputLog) async {
  final timetableUrl = await repeatUntilSuccess(() async {
    return getTimetableFileUrl(outputLog);
  });
  if (timetableUrl.isEmpty) {
    return false;
  }

  var response = await repeatUntilSuccess(() async {
    return await http.get(Uri.parse(timetableUrl));
  }, onCatch: (e) async {
    await outputLog.log(
      'Error of running GET request $e',
      status: RecordStatus.error,
    );
  });

  final successStatus = 200;
  if (response.statusCode == successStatus) {
    var fileToSave = File(fileNameToSave);
    if (!fileToSave.existsSync()) {
      fileToSave = await File(fileNameToSave).create(recursive: true);
    }
    await fileToSave.writeAsBytes(response.bodyBytes.toList());
    return true;
  }

  return false;
}

void convertPdfToPngs(Logger outputLog) async {
  var result = await Process.run('pdftoppm', [
    'timetables/timetable.pdf',
    'timetables/timetable',
    '-png',
    '-r',
    '79',
  ]);

  if (result.exitCode != 0) {
    await outputLog.log(
        'Exit code of pdftoppm is not 0: ${result.stdout} ${result.stderr}');
  }
}

Future<bool> compareTimetables(
    String first, String second, Logger outputLog) async {
  var firstMd5sum;
  var secondMd5sum;
  try {
    firstMd5sum = await _calculateMD5SumAsyncWithPlugin(first);
    secondMd5sum = await _calculateMD5SumAsyncWithPlugin(second);
  } catch (e) {
    await outputLog.log('When calculating MD5 sum $e',
        status: RecordStatus.error);
    return false;
  }

  return firstMd5sum == secondMd5sum;
}

Future<void> sendTimeTable(int chatId, Telegram telegram, Logger outputLog,
    ChatsMeneger chatsMeneger) async {
  if (chatsMeneger.isNotExists(chatId)) {
    await outputLog.log('Chat is not exists!', status: RecordStatus.error);
    return;
  }

  var page = chatsMeneger.getPage(chatId);
  var timetableImage = File('timetables/timetable-$page.png');
  if (!timetableImage.existsSync()) {
    await outputLog.log('File does not exists $timetableImage',
        status: RecordStatus.error);
    return;
  }

  var lastTimetableId = chatsMeneger.getLastTimeTableId(chatId);
  await repeatUntilSuccess<bool>(
    () async {
      return await telegram.deleteMessage(chatId, lastTimetableId);
    },
    onCatch: (e) async {
      await outputLog.log(
        'When deleting message $e',
        status: RecordStatus.error,
      );
    },
  );

  var photoMessage = await repeatUntilSuccess(
    () async {
      return await telegram.sendPhoto(chatId, timetableImage);
    },
    onCatch: (e) async {
      await outputLog.log('When sending message', status: RecordStatus.error);
    },
  );

  chatsMeneger.editLastTimetableId(chatId, photoMessage.message_id);
}

Future<Digest> _calculateMD5SumAsyncWithPlugin(String filePath) async {
  var hasher = md5;
  var file = File(filePath);

  if (!file.existsSync()) {
    throw 'File "$file" does not exist.';
  }

  var value = await hasher.bind(file.openRead()).first;
  return value;
}
