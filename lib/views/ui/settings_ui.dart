import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:adaptive_page_layout/adaptive_page_layout.dart';
import 'package:fluffychat/views/widgets/sentry_switch_list_tile.dart';
import 'package:fluffychat/views/widgets/settings_switch_list_tile.dart';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/utils/beautify_string_extension.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/content_banner.dart';
import '../widgets/matrix.dart';
import '../../config/app_config.dart';
import '../../config/setting_keys.dart';
import '../settings.dart';

class SettingsUI extends StatelessWidget {
  final SettingsController controller;

  const SettingsUI(this.controller, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            <Widget>[
          SliverAppBar(
            leading: IconButton(
              icon: Icon(Icons.close_outlined),
              onPressed: () => AdaptivePageLayout.of(context).popUntilIsFirst(),
            ),
            expandedHeight: 300.0,
            floating: true,
            pinned: true,
            title: Text(L10n.of(context).settings),
            actions: [
              FutureBuilder(
                  future: controller.crossSigningCachedFuture,
                  builder: (context, snapshot) {
                    final needsBootstrap = Matrix.of(context)
                                .client
                                .encryption
                                ?.crossSigning
                                ?.enabled ==
                            false ||
                        snapshot.data == false;
                    final isUnknownSession =
                        Matrix.of(context).client.isUnknownSession;
                    final displayHeader = needsBootstrap || isUnknownSession;
                    if (!displayHeader) return Container();
                    return TextButton.icon(
                      icon: Icon(Icons.cloud, color: Colors.red),
                      label: Text(
                        L10n.of(context).chatBackup,
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: controller.firstRunBootstrapAction,
                    );
                  }),
            ],
            backgroundColor: Theme.of(context).appBarTheme.color,
            flexibleSpace: FlexibleSpaceBar(
              background: ContentBanner(controller.profile?.avatarUrl,
                  onEdit: controller.setAvatarAction),
            ),
          ),
        ],
        body: ListView(
          children: <Widget>[
            ListTile(
              title: Text(
                L10n.of(context).notifications,
                style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              trailing: Icon(Icons.notifications_outlined),
              title: Text(L10n.of(context).notifications),
              onTap: () => AdaptivePageLayout.of(context)
                  .pushNamed('/settings/notifications'),
            ),
            Divider(thickness: 1),
            ListTile(
              title: Text(
                L10n.of(context).chat,
                style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              title: Text(L10n.of(context).changeTheme),
              onTap: () =>
                  AdaptivePageLayout.of(context).pushNamed('/settings/style'),
              trailing: Icon(Icons.style_outlined),
            ),
            SettingsSwitchListTile(
              title: L10n.of(context).renderRichContent,
              onChanged: (b) => AppConfig.renderHtml = b,
              storeKey: SettingKeys.renderHtml,
              defaultValue: AppConfig.renderHtml,
            ),
            SettingsSwitchListTile(
              title: L10n.of(context).hideRedactedEvents,
              onChanged: (b) => AppConfig.hideRedactedEvents = b,
              storeKey: SettingKeys.hideRedactedEvents,
              defaultValue: AppConfig.hideRedactedEvents,
            ),
            SettingsSwitchListTile(
              title: L10n.of(context).hideUnknownEvents,
              onChanged: (b) => AppConfig.hideUnknownEvents = b,
              storeKey: SettingKeys.hideUnknownEvents,
              defaultValue: AppConfig.hideUnknownEvents,
            ),
            ListTile(
              title: Text(L10n.of(context).emoteSettings),
              onTap: () =>
                  AdaptivePageLayout.of(context).pushNamed('/settings/emotes'),
              trailing: Icon(Icons.insert_emoticon_outlined),
            ),
            Divider(thickness: 1),
            ListTile(
              title: Text(
                L10n.of(context).account,
                style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              trailing: Icon(Icons.edit_outlined),
              title: Text(L10n.of(context).editDisplayname),
              subtitle: Text(
                  controller.profile?.displayname ?? client.userID.localpart),
              onTap: controller.setDisplaynameAction,
            ),
            ListTile(
              trailing: Icon(Icons.phone_outlined),
              title: Text(L10n.of(context).editJitsiInstance),
              subtitle: Text(AppConfig.jitsiInstance),
              onTap: controller.setJitsiInstanceAction,
            ),
            ListTile(
              trailing: Icon(Icons.devices_other_outlined),
              title: Text(L10n.of(context).devices),
              onTap: () =>
                  AdaptivePageLayout.of(context).pushNamed('/settings/devices'),
            ),
            ListTile(
              trailing: Icon(Icons.block_outlined),
              title: Text(L10n.of(context).ignoredUsers),
              onTap: () =>
                  AdaptivePageLayout.of(context).pushNamed('/settings/ignore'),
            ),
            SentrySwitchListTile(),
            Divider(thickness: 1),
            ListTile(
              trailing: Icon(Icons.security_outlined),
              title: Text(
                L10n.of(context).changePassword,
              ),
              onTap: controller.changePasswordAccountAction,
            ),
            ListTile(
              trailing: Icon(Icons.email_outlined),
              title: Text(L10n.of(context).passwordRecovery),
              onTap: () =>
                  AdaptivePageLayout.of(context).pushNamed('/settings/3pid'),
            ),
            ListTile(
              trailing: Icon(Icons.exit_to_app_outlined),
              title: Text(L10n.of(context).logout),
              onTap: controller.logoutAction,
            ),
            ListTile(
              trailing: Icon(Icons.delete_forever_outlined),
              title: Text(
                L10n.of(context).deleteAccount,
                style: TextStyle(color: Colors.red),
              ),
              onTap: controller.deleteAccountAction,
            ),
            if (client.encryption != null) ...{
              Divider(thickness: 1),
              ListTile(
                title: Text(
                  L10n.of(context).security,
                  style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (PlatformInfos.isMobile)
                ListTile(
                  trailing: Icon(Icons.lock_outlined),
                  title: Text(L10n.of(context).appLock),
                  onTap: controller.setAppLockAction,
                ),
              ListTile(
                title: Text(L10n.of(context).yourPublicKey),
                onTap: () => showOkAlertDialog(
                  context: context,
                  title: L10n.of(context).yourPublicKey,
                  message: client.fingerprintKey.beautified,
                  okLabel: L10n.of(context).ok,
                  useRootNavigator: false,
                ),
                trailing: Icon(Icons.vpn_key_outlined),
              ),
              ListTile(
                title: Text(L10n.of(context).cachedKeys),
                trailing: Icon(Icons.wb_cloudy_outlined),
                subtitle: Text(
                    '${client.encryption.keyManager.enabled ? L10n.of(context).onlineKeyBackupEnabled : L10n.of(context).onlineKeyBackupDisabled}\n${client.encryption.crossSigning.enabled ? L10n.of(context).crossSigningEnabled : L10n.of(context).crossSigningDisabled}'),
                onTap: controller.bootstrapSettingsAction,
              ),
            },
            Divider(thickness: 1),
            ListTile(
              title: Text(
                L10n.of(context).about,
                style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => AdaptivePageLayout.of(context).pushNamed('/logs'),
            ),
            ListTile(
              trailing: Icon(Icons.help_outlined),
              title: Text(L10n.of(context).help),
              onTap: () => launch(AppConfig.supportUrl),
            ),
            ListTile(
              trailing: Icon(Icons.privacy_tip_outlined),
              title: Text(L10n.of(context).privacy),
              onTap: () => launch(AppConfig.privacyUrl),
            ),
            ListTile(
              trailing: Icon(Icons.link_outlined),
              title: Text(L10n.of(context).about),
              onTap: () => PlatformInfos.showDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}
