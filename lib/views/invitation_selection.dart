import 'dart:async';

import 'package:adaptive_page_layout/adaptive_page_layout.dart';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/views/ui/invitation_selection_ui.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:fluffychat/views/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../utils/localized_exception_extension.dart';

class InvitationSelection extends StatefulWidget {
  final String roomId;
  const InvitationSelection(this.roomId, {Key key}) : super(key: key);

  @override
  InvitationSelectionController createState() =>
      InvitationSelectionController();
}

class InvitationSelectionController extends State<InvitationSelection> {
  TextEditingController controller = TextEditingController();
  String currentSearchTerm;
  bool loading = false;
  List<Profile> foundProfiles = [];
  Timer coolDown;

  Future<List<User>> getContacts(BuildContext context) async {
    final client = Matrix.of(context).client;
    final room = client.getRoomById(widget.roomId);
    final participants = await room.requestParticipants();
    participants.removeWhere(
      (u) => ![Membership.join, Membership.invite].contains(u.membership),
    );
    final contacts = <User>[];
    final userMap = <String, bool>{};
    for (var i = 0; i < client.rooms.length; i++) {
      final roomUsers = client.rooms[i].getParticipants();

      for (var j = 0; j < roomUsers.length; j++) {
        if (userMap[roomUsers[j].id] != true &&
            participants.indexWhere((u) => u.id == roomUsers[j].id) == -1) {
          contacts.add(roomUsers[j]);
        }
        userMap[roomUsers[j].id] = true;
      }
    }
    contacts.sort(
      (a, b) => a.calcDisplayname().toLowerCase().compareTo(
            b.calcDisplayname().toLowerCase(),
          ),
    );
    return contacts;
  }

  void inviteAction(BuildContext context, String id) async {
    final room = Matrix.of(context).client.getRoomById(widget.roomId);
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => room.invite(id),
    );
    if (success.error == null) {
      AdaptivePageLayout.of(context).showSnackBar(SnackBar(
          content: Text(L10n.of(context).contactHasBeenInvitedToTheGroup)));
    }
  }

  void searchUserWithCoolDown(String text) async {
    coolDown?.cancel();
    coolDown = Timer(
      Duration(seconds: 1),
      () => searchUser(context, text),
    );
  }

  void searchUser(BuildContext context, String text) async {
    coolDown?.cancel();
    if (text.isEmpty) {
      setState(() => foundProfiles = []);
    }
    currentSearchTerm = text;
    if (currentSearchTerm.isEmpty) return;
    if (loading) return;
    setState(() => loading = true);
    final matrix = Matrix.of(context);
    UserSearchResult response;
    try {
      response = await matrix.client.searchUserDirectory(text, limit: 10);
    } catch (e) {
      AdaptivePageLayout.of(context).showSnackBar(
          SnackBar(content: Text((e as Object).toLocalizedString(context))));
      return;
    } finally {
      setState(() => loading = false);
    }
    setState(() {
      foundProfiles = List<Profile>.from(response.results);
      if (text.isValidMatrixId &&
          foundProfiles.indexWhere((profile) => text == profile.userId) == -1) {
        setState(() => foundProfiles = [
              Profile.fromJson({'user_id': text}),
            ]);
      }
      final participants = Matrix.of(context)
          .client
          .getRoomById(widget.roomId)
          .getParticipants()
          .where((user) =>
              [Membership.join, Membership.invite].contains(user.membership))
          .toList();
      foundProfiles.removeWhere((profile) =>
          participants.indexWhere((u) => u.id == profile.userId) != -1);
    });
  }

  @override
  Widget build(BuildContext context) => InvitationSelectionUI(this);
}
