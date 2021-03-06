import 'package:adaptive_page_layout/adaptive_page_layout.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/views/chat_details.dart';
import 'package:fluffychat/views/widgets/avatar.dart';
import 'package:fluffychat/views/widgets/matrix.dart';
import 'package:fluffychat/utils/fluffy_share.dart';

import 'package:famedlysdk/famedlysdk.dart';

import 'package:fluffychat/views/widgets/chat_settings_popup_menu.dart';
import 'package:fluffychat/views/widgets/content_banner.dart';
import 'package:fluffychat/views/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/views/widgets/list_items/participant_list_item.dart';
import 'package:fluffychat/utils/matrix_locals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix_link_text/link_text.dart';

import '../../utils/url_launcher.dart';

class ChatDetailsUI extends StatelessWidget {
  final ChatDetailsController controller;

  const ChatDetailsUI(this.controller, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final room =
        Matrix.of(context).client.getRoomById(controller.widget.roomId);
    if (room == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(),
          title: Text(L10n.of(context).oopsSomethingWentWrong),
        ),
        body: Center(
          child: Text(L10n.of(context).youAreNoLongerParticipatingInThisChat),
        ),
      );
    }

    controller.members.removeWhere((u) => u.membership == Membership.leave);
    final actualMembersCount =
        room.mInvitedMemberCount + room.mJoinedMemberCount;
    final canRequestMoreMembers =
        controller.members.length < actualMembersCount;
    return StreamBuilder(
        stream: room.onUpdate.stream,
        builder: (context, snapshot) {
          return Scaffold(
            body: NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) => <Widget>[
                SliverAppBar(
                  elevation: Theme.of(context).appBarTheme.elevation,
                  leading: BackButton(),
                  expandedHeight: 300.0,
                  floating: true,
                  pinned: true,
                  actions: <Widget>[
                    if (room.canonicalAlias?.isNotEmpty ?? false)
                      IconButton(
                        tooltip: L10n.of(context).share,
                        icon: Icon(Icons.share_outlined),
                        onPressed: () => FluffyShare.share(
                            AppConfig.inviteLinkPrefix + room.canonicalAlias,
                            context),
                      ),
                    ChatSettingsPopupMenu(room, false)
                  ],
                  title: Text(
                      room.getLocalizedDisplayname(
                          MatrixLocals(L10n.of(context))),
                      style: TextStyle(
                          color: Theme.of(context)
                              .appBarTheme
                              .textTheme
                              .headline6
                              .color)),
                  backgroundColor: Theme.of(context).appBarTheme.color,
                  flexibleSpace: FlexibleSpaceBar(
                    background: ContentBanner(room.avatar,
                        onEdit: room.canSendEvent('m.room.avatar')
                            ? controller.setAvatarAction
                            : null),
                  ),
                ),
              ],
              body: MaxWidthBody(
                child: ListView.builder(
                  itemCount: controller.members.length +
                      1 +
                      (canRequestMoreMembers ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) => i == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ListTile(
                              leading: room.canSendEvent('m.room.topic')
                                  ? CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .scaffoldBackgroundColor,
                                      foregroundColor: Colors.grey,
                                      radius: Avatar.defaultSize / 2,
                                      child: Icon(Icons.edit_outlined),
                                    )
                                  : null,
                              title: Text(
                                  '${L10n.of(context).groupDescription}:',
                                  style: TextStyle(
                                      color: Theme.of(context).accentColor,
                                      fontWeight: FontWeight.bold)),
                              subtitle: LinkText(
                                text: room.topic?.isEmpty ?? true
                                    ? L10n.of(context).addGroupDescription
                                    : room.topic,
                                linkStyle: TextStyle(color: Colors.blueAccent),
                                textStyle: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .color,
                                ),
                                onLinkTap: (url) =>
                                    UrlLauncher(context, url).launchUrl(),
                              ),
                              onTap: room.canSendEvent('m.room.topic')
                                  ? controller.setTopicAction
                                  : null,
                            ),
                            Divider(thickness: 1),
                            ListTile(
                              title: Text(
                                L10n.of(context).settings,
                                style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (room.canSendEvent('m.room.name'))
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  foregroundColor: Colors.grey,
                                  child: Icon(Icons.people_outlined),
                                ),
                                title: Text(
                                    L10n.of(context).changeTheNameOfTheGroup),
                                subtitle: Text(room.getLocalizedDisplayname(
                                    MatrixLocals(L10n.of(context)))),
                                onTap: controller.setDisplaynameAction,
                              ),
                            if (room.joinRules == JoinRules.public)
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  foregroundColor: Colors.grey,
                                  child: Icon(Icons.link_outlined),
                                ),
                                onTap: controller.editAliases,
                                title: Text(L10n.of(context).editRoomAliases),
                                subtitle: Text(
                                    (room.canonicalAlias?.isNotEmpty ?? false)
                                        ? room.canonicalAlias
                                        : L10n.of(context).none),
                              ),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).scaffoldBackgroundColor,
                                foregroundColor: Colors.grey,
                                child: Icon(Icons.insert_emoticon_outlined),
                              ),
                              title: Text(L10n.of(context).emoteSettings),
                              subtitle: Text(L10n.of(context).setCustomEmotes),
                              onTap: controller.goToEmoteSettings,
                            ),
                            PopupMenuButton(
                              onSelected: controller.setJoinRulesAction,
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<JoinRules>>[
                                if (room.canChangeJoinRules)
                                  PopupMenuItem<JoinRules>(
                                    value: JoinRules.public,
                                    child: Text(JoinRules.public
                                        .getLocalizedString(
                                            MatrixLocals(L10n.of(context)))),
                                  ),
                                if (room.canChangeJoinRules)
                                  PopupMenuItem<JoinRules>(
                                    value: JoinRules.invite,
                                    child: Text(JoinRules.invite
                                        .getLocalizedString(
                                            MatrixLocals(L10n.of(context)))),
                                  ),
                              ],
                              child: ListTile(
                                leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    foregroundColor: Colors.grey,
                                    child: Icon(Icons.public_outlined)),
                                title: Text(L10n.of(context)
                                    .whoIsAllowedToJoinThisGroup),
                                subtitle: Text(
                                  room.joinRules.getLocalizedString(
                                      MatrixLocals(L10n.of(context))),
                                ),
                              ),
                            ),
                            PopupMenuButton(
                              onSelected: controller.setHistoryVisibilityAction,
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<HistoryVisibility>>[
                                if (room.canChangeHistoryVisibility)
                                  PopupMenuItem<HistoryVisibility>(
                                    value: HistoryVisibility.invited,
                                    child: Text(HistoryVisibility.invited
                                        .getLocalizedString(
                                            MatrixLocals(L10n.of(context)))),
                                  ),
                                if (room.canChangeHistoryVisibility)
                                  PopupMenuItem<HistoryVisibility>(
                                    value: HistoryVisibility.joined,
                                    child: Text(HistoryVisibility.joined
                                        .getLocalizedString(
                                            MatrixLocals(L10n.of(context)))),
                                  ),
                                if (room.canChangeHistoryVisibility)
                                  PopupMenuItem<HistoryVisibility>(
                                    value: HistoryVisibility.shared,
                                    child: Text(HistoryVisibility.shared
                                        .getLocalizedString(
                                            MatrixLocals(L10n.of(context)))),
                                  ),
                                if (room.canChangeHistoryVisibility)
                                  PopupMenuItem<HistoryVisibility>(
                                    value: HistoryVisibility.worldReadable,
                                    child: Text(HistoryVisibility.worldReadable
                                        .getLocalizedString(
                                            MatrixLocals(L10n.of(context)))),
                                  ),
                              ],
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  foregroundColor: Colors.grey,
                                  child: Icon(Icons.visibility_outlined),
                                ),
                                title: Text(L10n.of(context)
                                    .visibilityOfTheChatHistory),
                                subtitle: Text(
                                  room.historyVisibility.getLocalizedString(
                                      MatrixLocals(L10n.of(context))),
                                ),
                              ),
                            ),
                            if (room.joinRules == JoinRules.public)
                              PopupMenuButton(
                                onSelected: controller.setGuestAccessAction,
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<GuestAccess>>[
                                  if (room.canChangeGuestAccess)
                                    PopupMenuItem<GuestAccess>(
                                      value: GuestAccess.canJoin,
                                      child: Text(
                                        GuestAccess.canJoin.getLocalizedString(
                                            MatrixLocals(L10n.of(context))),
                                      ),
                                    ),
                                  if (room.canChangeGuestAccess)
                                    PopupMenuItem<GuestAccess>(
                                      value: GuestAccess.forbidden,
                                      child: Text(
                                        GuestAccess.forbidden
                                            .getLocalizedString(
                                                MatrixLocals(L10n.of(context))),
                                      ),
                                    ),
                                ],
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    foregroundColor: Colors.grey,
                                    child: Icon(Icons.info_outline),
                                  ),
                                  title: Text(
                                      L10n.of(context).areGuestsAllowedToJoin),
                                  subtitle: Text(
                                    room.guestAccess.getLocalizedString(
                                        MatrixLocals(L10n.of(context))),
                                  ),
                                ),
                              ),
                            ListTile(
                              title: Text(L10n.of(context).editChatPermissions),
                              subtitle: Text(
                                  L10n.of(context).whoCanPerformWhichAction),
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).scaffoldBackgroundColor,
                                foregroundColor: Colors.grey,
                                child: Icon(Icons.edit_attributes_outlined),
                              ),
                              onTap: () => AdaptivePageLayout.of(context)
                                  .pushNamed('/rooms/${room.id}/permissions'),
                            ),
                            Divider(thickness: 1),
                            ListTile(
                              title: Text(
                                actualMembersCount > 1
                                    ? L10n.of(context).countParticipants(
                                        actualMembersCount.toString())
                                    : L10n.of(context).emptyChat,
                                style: TextStyle(
                                  color: Theme.of(context).accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            room.canInvite
                                ? ListTile(
                                    title: Text(L10n.of(context).inviteContact),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      radius: Avatar.defaultSize / 2,
                                      child: Icon(Icons.add_outlined),
                                    ),
                                    onTap: () => AdaptivePageLayout.of(context)
                                        .pushNamed('/rooms/${room.id}/invite'),
                                  )
                                : Container(),
                          ],
                        )
                      : i < controller.members.length + 1
                          ? ParticipantListItem(controller.members[i - 1])
                          : ListTile(
                              title: Text(L10n.of(context)
                                  .loadCountMoreParticipants(
                                      (actualMembersCount -
                                              controller.members.length)
                                          .toString())),
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).scaffoldBackgroundColor,
                                child: Icon(
                                  Icons.refresh,
                                  color: Colors.grey,
                                ),
                              ),
                              onTap: controller.requestMoreMembersAction,
                            ),
                ),
              ),
            ),
          );
        });
  }
}
