import 'dart:io';

enum RecordStatus { info, error, warning }

class Logger {
  static final Map<String, Logger> _loggers = {};

  final String _outputFileName;

  factory Logger(String outputFileName) => _loggers.putIfAbsent(
      outputFileName, () => Logger._internal(outputFileName));

  Logger._internal(this._outputFileName);

  Future<bool> log(String record, {status = RecordStatus.info}) async {
    var outputFile = File(_outputFileName);
    var recordFormated =
        '${DateTime.now().toString()}:${status.toString().split('.')[1]}:$record\n';
    await outputFile.writeAsString(recordFormated, mode: FileMode.append);
    return true;
  }
}
