import 'dart:io';

import 'package:teledart/telegram.dart';
import 'package:valyusha_robot/services/logger.dart';
import 'package:valyusha_robot/services/chats_meneger.dart';

import 'package:valyusha_robot/services/timetable_tools.dart';

void onHelpCommand(dynamic message, Logger outputLog) {
  var helpFile;
  try {
    helpFile = File('set_up_bot/description.txt');
  } catch (e) {
    outputLog.log('Error of reading description file $e',
        status: RecordStatus.error);
  }
  helpFile.readAsString().then((help) => message.reply(help));
}

void onPageCommand(
    dynamic message, Logger outputLog, ChatsMeneger chatsMeneger) async {
  final lengthOfCommand = 6;
  String substringToParse;
  try {
    substringToParse = message.text.substring(lengthOfCommand);
  } catch (e) {
    await outputLog.log(e.toString(), status: RecordStatus.error);
    message.reply('Неверный формат страницы!');
    return;
  }

  var value;
  try {
    value = int.parse(substringToParse);

    if (6 < value || value < 1) {
      throw 'Number of page is not in range 1..6!';
    }
  } catch (e) {
    await outputLog.log('Error of parsing number of page $e',
        status: RecordStatus.error);
    message.reply('Неверный формат страницы!');
    return;
  }

  var isChatFound = chatsMeneger.editPage(message.chat.id, value);
  if (isChatFound) {
    message.reply('Теперь я буду присылать тебе $value лист с расписанием!');
  } else {
    message.reply('Тебя нет в базе данных!');
    return;
  }
}

void onSubscribeCommand(
    dynamic message, Logger outputLog, ChatsMeneger chatsMeneger) async {
  var isChatFound = chatsMeneger.editSubscribedStatus(message.chat.id, true);
  if (!isChatFound) {
    try {
      chatsMeneger.addChat(message.chat.id);
    } catch (e) {
      await outputLog.log(e.toString(), status: RecordStatus.error);
    }
  }
  message.reply('Теперь ты подписан на объявления.');
}

void onUnsubscribeCommand(dynamic message, ChatsMeneger chatsMeneger) {
  chatsMeneger.editSubscribedStatus(message.chat.id, false);
  message.reply('Теперь ты отписан от объявлений.');
}

void onTimetableCommand(dynamic message, Telegram telegram, Logger outputLog,
    ChatsMeneger chatsMeneger) async {
  if (chatsMeneger.isNotExists(message.chat.id)) {
    message.reply('Тебя нет в базе данных!');
  } else {
    await sendTimeTable(message.chat.id, telegram, outputLog, chatsMeneger);
  }
}
