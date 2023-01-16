import 'dart:async';
import 'dart:io' as io;

import 'package:dotenv/dotenv.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';
import 'package:valyusha_robot/repeat_until_success.dart';
import 'package:valyusha_robot/services/timetable_tools.dart';
import 'package:valyusha_robot/services/chats_meneger.dart';
import 'package:valyusha_robot/services/logger.dart';

import 'command_handler.dart';

class _HttpOverridesWithProxy extends io.HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String> environment) {
    return 'PROXY 185.199.229.156:7492';
  }
}

void main() async {
  io.HttpOverrides.global = _HttpOverridesWithProxy();
  var outputLog = Logger('output.log');
  await outputLog.log('PID of started process: ${io.pid}');
  ChatsMeneger chatsMeneger;
  try {
    chatsMeneger = ChatsMeneger('chats_data.json');
  } catch (e) {
    await outputLog.log('When creating ChatsMeneger $e.',
        status: RecordStatus.error);
    return;
  }

  var env = DotEnv()..load();

  final botToken = env['BOT_TOKEN'] ?? 'error';
  var telegram = Telegram(botToken);
  final botUsername = (await repeatUntilSuccess(
    () async {
      return telegram.getMe();
    },
    onCatch: (e) async {
      await outputLog.log(
        'Cannot get bot username',
        status: RecordStatus.error,
      );
    },
  ))
      .username;
  var teledart = TeleDart(botToken, Event(botUsername));

  var timeout = Duration(minutes: 5);
  var timer = Timer.periodic(
    timeout,
    (_) => checkTimetable(telegram, outputLog, chatsMeneger),
  );

  teledart.start();
  await outputLog.log('$botUsername is initialised');

  io.ProcessSignal.sigint.watch().listen((signal) async {
    teledart.stop();
    timer.cancel();
    await outputLog.log('Bot was stopped by user');
    io.exit(0);
  });

  await downloadTimetable('timetables/timetable.pdf', outputLog);
  convertPdfToPngs(outputLog);

  teledart.onMessage(keyword: 'start', entityType: 'bot_command').listen(
      (message) => onSubscribeCommand(message, outputLog, chatsMeneger));

  teledart
      .onMessage(keyword: 'help', entityType: 'bot_command')
      .listen((message) => onHelpCommand(message, outputLog));

  teledart
      .onMessage(keyword: 'page', entityType: 'bot_command')
      .listen((message) => onPageCommand(message, outputLog, chatsMeneger));

  teledart.onMessage(keyword: 'subscribe', entityType: 'bot_command').listen(
      (message) => onSubscribeCommand(message, outputLog, chatsMeneger));

  teledart
      .onMessage(keyword: 'unsubscribe', entityType: 'bot_command')
      .listen((message) => onUnsubscribeCommand(message, chatsMeneger));

  teledart.onMessage(keyword: 'timetable', entityType: 'bot_command').listen(
      (message) =>
          onTimetableCommand(message, telegram, outputLog, chatsMeneger));

  await checkTimetable(telegram, outputLog, chatsMeneger);
}

Future<void> checkTimetable(
    Telegram telegram, Logger outputLog, ChatsMeneger chatsMeneger) async {
  await downloadTimetable('timetables/new_timetable.pdf', outputLog);
  var isEqual = await compareTimetables(
      'timetables/timetable.pdf', 'timetables/new_timetable.pdf', outputLog);
  if (!isEqual) {
    await downloadTimetable('timetables/timetable.pdf', outputLog);
    convertPdfToPngs(outputLog);
    await chatsMeneger.forEachAsync((chat) async {
      var isSubscribed = chatsMeneger.getSubscribedStatus(chat['chat_id']);
      if (isSubscribed is bool && isSubscribed) {
        await sendTimeTable(chat['chat_id'], telegram, outputLog, chatsMeneger);
      }
    });
  }
}
