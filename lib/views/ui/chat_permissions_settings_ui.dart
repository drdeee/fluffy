import 'package:fluffychat/views/chat_permissions_settings.dart';
import 'package:fluffychat/views/widgets/list_items/permission_list_tile.dart';
import 'package:fluffychat/views/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/views/widgets/matrix.dart';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:famedlysdk/famedlysdk.dart';

class ChatPermissionsSettingsUI extends StatelessWidget {
  final ChatPermissionsSettingsController controller;

  const ChatPermissionsSettingsUI(this.controller, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: Text(L10n.of(context).editChatPermissions),
      ),
      body: MaxWidthBody(
        withScrolling: true,
        child: StreamBuilder(
          stream: controller.onChanged,
          builder: (context, _) {
            final room =
                Matrix.of(context).client.getRoomById(controller.widget.roomId);
            final powerLevelsContent = Map<String, dynamic>.from(
                room.getState(EventTypes.RoomPowerLevels).content);
            final powerLevels = Map<String, dynamic>.from(powerLevelsContent)
              ..removeWhere((k, v) => !(v is int));
            final eventsPowerLevels =
                Map<String, dynamic>.from(powerLevelsContent['events'] ?? {})
                  ..removeWhere((k, v) => !(v is int));
            return Column(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var entry in powerLevels.entries)
                      PermissionsListTile(
                        permissionKey: entry.key,
                        permission: entry.value,
                        onTap: () => controller.editPowerLevel(
                            context, entry.key, entry.value),
                      ),
                    Divider(thickness: 1),
                    ListTile(
                      title: Text(
                        L10n.of(context).notifications,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Builder(builder: (context) {
                      final key = 'rooms';
                      final int value = powerLevelsContent
                              .containsKey('notifications')
                          ? powerLevelsContent['notifications']['rooms'] ?? 0
                          : 0;
                      return PermissionsListTile(
                        permissionKey: key,
                        permission: value,
                        category: 'notifications',
                        onTap: () => controller.editPowerLevel(
                            context, key, value,
                            category: 'notifications'),
                      );
                    }),
                    Divider(thickness: 1),
                    ListTile(
                      title: Text(
                        L10n.of(context).configureChat,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (eventsPowerLevels != null)
                      for (var entry in eventsPowerLevels.entries)
                        PermissionsListTile(
                          permissionKey: entry.key,
                          category: 'events',
                          permission: entry.value,
                          onTap: () => controller.editPowerLevel(
                              context, entry.key, entry.value,
                              category: 'events'),
                        ),
                    if (room.canSendEvent(EventTypes.RoomTombstone)) ...{
                      Divider(thickness: 1),
                      FutureBuilder<ServerCapabilities>(
                        future: room.client.getCapabilities(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }
                          final String roomVersion = room
                                  .getState(EventTypes.RoomCreate)
                                  .content['room_version'] ??
                              '1';

                          return ListTile(
                            title: Text(
                                '${L10n.of(context).roomVersion}: $roomVersion'),
                            onTap: () =>
                                controller.updateRoomAction(snapshot.data),
                          );
                        },
                      ),
                    },
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
