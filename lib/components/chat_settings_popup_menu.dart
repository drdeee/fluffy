import 'dart:async';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/utils/app_route.dart';
import 'package:fluffychat/views/chat_details.dart';
import 'package:fluffychat/views/chat_list.dart';
import 'package:flutter/material.dart';

import 'matrix.dart';

class ChatSettingsPopupMenu extends StatefulWidget {
  final Room room;
  final bool displayChatDetails;
  const ChatSettingsPopupMenu(this.room, this.displayChatDetails, {Key key})
      : super(key: key);

  @override
  _ChatSettingsPopupMenuState createState() => _ChatSettingsPopupMenuState();
}

class _ChatSettingsPopupMenuState extends State<ChatSettingsPopupMenu> {
  StreamSubscription notificationChangeSub;

  @override
  void dispose() {
    notificationChangeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    notificationChangeSub ??= Matrix.of(context)
        .client
        .onUserEvent
        .stream
        .where((u) => u.type == 'account_data' && u.eventType == "m.push_rules")
        .listen(
          (u) => setState(() => null),
        );
    List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[
      widget.room.pushRuleState == PushRuleState.notify
          ? const PopupMenuItem<String>(
              value: "mute",
              child: Text('Mute chat'),
            )
          : const PopupMenuItem<String>(
              value: "unmute",
              child: Text('Unmute chat'),
            ),
      const PopupMenuItem<String>(
        value: "leave",
        child: Text('Leave'),
      ),
    ];
    if (widget.displayChatDetails) {
      items.insert(
        0,
        const PopupMenuItem<String>(
          value: "details",
          child: Text('Chat details'),
        ),
      );
    }
    return PopupMenuButton(
      onSelected: (String choice) async {
        switch (choice) {
          case "leave":
            await Matrix.of(context)
                .tryRequestWithLoadingDialog(widget.room.leave());
            await Navigator.of(context).pushAndRemoveUntil(
                AppRoute.defaultRoute(context, ChatListView()),
                (Route r) => false);
            break;
          case "mute":
            await Matrix.of(context).tryRequestWithLoadingDialog(
                widget.room.setPushRuleState(PushRuleState.mentions_only));
            break;
          case "unmute":
            await Matrix.of(context).tryRequestWithLoadingDialog(
                widget.room.setPushRuleState(PushRuleState.notify));
            break;
          case "details":
            await Navigator.of(context).push(
              AppRoute.defaultRoute(
                context,
                ChatDetails(widget.room),
              ),
            );
            break;
        }
      },
      itemBuilder: (BuildContext context) => items,
    );
  }
}