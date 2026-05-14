import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSelectedNoteKey = 'lastSelectedNoteId';

final selectedNoteIdProvider =
    NotifierProvider<SelectedNoteNotifier, String?>(SelectedNoteNotifier.new);

class SelectedNoteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = id;
    SharedPreferences.getInstance().then((prefs) {
      if (id != null) {
        prefs.setString(_kSelectedNoteKey, id);
      } else {
        prefs.remove(_kSelectedNoteKey);
      }
    });
  }

  Future<void> restoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kSelectedNoteKey);
    if (id != null) state = id;
  }
}
