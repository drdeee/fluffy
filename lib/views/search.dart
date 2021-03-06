import 'dart:async';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:adaptive_page_layout/adaptive_page_layout.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/views/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'ui/search_ui.dart';

class Search extends StatefulWidget {
  final String alias;

  const Search({Key key, this.alias}) : super(key: key);

  @override
  SearchController createState() => SearchController();
}

class SearchController extends State<Search> {
  final TextEditingController controller = TextEditingController();
  Future<PublicRoomsResponse> publicRoomsResponse;
  String lastServer;
  Timer _coolDown;
  String genericSearchTerm;

  void search(String query) async {
    setState(() => null);
    _coolDown?.cancel();
    _coolDown = Timer(
      Duration(milliseconds: 500),
      () => setState(() {
        genericSearchTerm = query;
        publicRoomsResponse = null;
        searchUser(context, controller.text);
      }),
    );
  }

  Future<String> _joinRoomAndWait(
    BuildContext context,
    String roomId,
    String alias,
  ) async {
    if (Matrix.of(context).client.getRoomById(roomId) != null) {
      return roomId;
    }
    final newRoomId = await Matrix.of(context)
        .client
        .joinRoom(alias?.isNotEmpty ?? false ? alias : roomId);
    await Matrix.of(context)
        .client
        .onRoomUpdate
        .stream
        .firstWhere((r) => r.id == newRoomId);
    return newRoomId;
  }

  void joinGroupAction(PublicRoom room) async {
    if (await showOkCancelAlertDialog(
          context: context,
          okLabel: L10n.of(context).joinRoom,
          title: '${room.name} (${room.numJoinedMembers ?? 0})',
          message: room.topic ?? L10n.of(context).noDescription,
          cancelLabel: L10n.of(context).cancel,
          useRootNavigator: false,
        ) ==
        OkCancelResult.cancel) {
      return;
    }
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => _joinRoomAndWait(
        context,
        room.roomId,
        room.canonicalAlias ?? room.aliases.first,
      ),
    );
    if (success.error == null) {
      await AdaptivePageLayout.of(context)
          .pushNamedAndRemoveUntilIsFirst('/rooms/${success.result}');
    }
  }

  String server;

  void setServer() async {
    final newServer = await showTextInputDialog(
        title: L10n.of(context).changeTheHomeserver,
        context: context,
        okLabel: L10n.of(context).ok,
        cancelLabel: L10n.of(context).cancel,
        useRootNavigator: false,
        textFields: [
          DialogTextField(
            prefixText: 'https://',
            hintText: Matrix.of(context).client.homeserver.host,
            initialText: server,
            keyboardType: TextInputType.url,
          )
        ]);
    if (newServer == null) return;
    setState(() {
      server = newServer.single;
    });
  }

  String currentSearchTerm;
  List<Profile> foundProfiles = [];

  void searchUser(BuildContext context, String text) async {
    if (text.isEmpty) {
      setState(() {
        foundProfiles = [];
      });
    }
    currentSearchTerm = text;
    if (currentSearchTerm.isEmpty) return;
    final matrix = Matrix.of(context);
    UserSearchResult response;
    try {
      response = await matrix.client.searchUserDirectory(text, limit: 10);
    } catch (_) {}
    foundProfiles = List<Profile>.from(response?.results ?? []);
    if (foundProfiles.isEmpty && text.isValidMatrixId && text.sigil == '@') {
      foundProfiles.add(Profile.fromJson({
        'displayname': text.localpart,
        'user_id': text,
      }));
    }
    setState(() {});
  }

  @override
  void initState() {
    genericSearchTerm = widget.alias;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => SearchUI(this);
}
