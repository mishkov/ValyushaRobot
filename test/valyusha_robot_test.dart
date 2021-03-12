import 'package:valyusha_robot/services/chats_meneger.dart';

void main() async {}

void testChatsMeneger() {
  var chatsMeneger;
  try {
    chatsMeneger = ChatsMeneger('chas_data.json');
  } catch (e) {
    print(e);
  }
  chatsMeneger.editLastTimetableId(2, 4);
}
