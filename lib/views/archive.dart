import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/views/ui/archive_ui.dart';
import 'package:fluffychat/views/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

class Archive extends StatefulWidget {
  @override
  ArchiveController createState() => ArchiveController();
}

class ArchiveController extends State<Archive> {
  List<Room> archive;

  Future<List<Room>> getArchive(BuildContext context) async {
    if (archive != null) return archive;
    return await Matrix.of(context).client.archive;
  }

  void forgetAction(int i) => setState(() => archive.removeAt(i));

  void forgetAllAction() async {
    if (await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).areYouSure,
          okLabel: L10n.of(context).yes,
          cancelLabel: L10n.of(context).cancel,
          message: L10n.of(context).clearArchive,
          useRootNavigator: false,
        ) !=
        OkCancelResult.ok) {
      return;
    }
    await showFutureLoadingDialog(
      context: context,
      future: () async {
        while (archive.isNotEmpty) {
          Logs().v('Forget room ${archive.last.displayname}');
          await archive.last.forget();
          archive.removeLast();
        }
      },
    );
    setState(() => null);
  }

  @override
  Widget build(BuildContext context) => ArchiveUI(this);
}
