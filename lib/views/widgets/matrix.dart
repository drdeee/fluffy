import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:adaptive_page_layout/adaptive_page_layout.dart';
import 'package:famedlysdk/encryption.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/utils/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/sentry_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_lock/flutter_app_lock.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:desktop_notifications/desktop_notifications.dart';

import '../../utils/beautify_string_extension.dart';
import '../../utils/localized_exception_extension.dart';
import '../../utils/famedlysdk_store.dart';
import '../key_verification_dialog.dart';
import '../../utils/platform_infos.dart';
import '../../config/app_config.dart';
import '../../config/setting_keys.dart';
import '../../utils/fluffy_client.dart';
import '../../utils/background_push.dart';

class Matrix extends StatefulWidget {
  static const String callNamespace = 'chat.fluffy.jitsi_call';

  final Widget child;

  final GlobalKey<AdaptivePageLayoutState> apl;

  final BuildContext context;

  final Client testClient;

  Matrix({
    this.child,
    @required this.apl,
    @required this.context,
    this.testClient,
    Key key,
  }) : super(key: key);

  @override
  MatrixState createState() => MatrixState();

  /// Returns the (nearest) Client instance of your application.
  static MatrixState of(BuildContext context) =>
      Provider.of<MatrixState>(context, listen: false);
}

class MatrixState extends State<Matrix> with WidgetsBindingObserver {
  FluffyClient client;
  Store store = Store();
  @override
  BuildContext get context => widget.context;

  BackgroundPush _backgroundPush;

  bool get testMode => widget.testClient != null;

  Map<String, dynamic> get shareContent => _shareContent;
  set shareContent(Map<String, dynamic> content) {
    _shareContent = content;
    onShareContentChanged.add(_shareContent);
  }

  Map<String, dynamic> _shareContent;

  final StreamController<Map<String, dynamic>> onShareContentChanged =
      StreamController.broadcast();

  File wallpaper;

  void _initWithStore() async {
    try {
      if (!testMode) await client.init();
      if (client.isLogged()) {
        final statusMsg = await store.getItem(SettingKeys.ownStatusMessage);
        if (statusMsg?.isNotEmpty ?? false) {
          Logs().v('Send cached status message: "$statusMsg"');
          await client.setPresence(
            client.userID,
            PresenceType.online,
            statusMsg: statusMsg,
          );
        }
      }
    } catch (e, s) {
      client.onLoginStateChanged.sink.addError(e, s);
      SentryController.captureException(e, s);
      rethrow;
    }
  }

  StreamSubscription onRoomKeyRequestSub;
  StreamSubscription onKeyVerificationRequestSub;
  StreamSubscription onJitsiCallSub;
  StreamSubscription onNotification;
  StreamSubscription<LoginState> onLoginStateChanged;
  StreamSubscription<UiaRequest> onUiaRequest;
  StreamSubscription<html.Event> onFocusSub;
  StreamSubscription<html.Event> onBlurSub;
  StreamSubscription<Presence> onOwnPresence;

  String _cachedPassword;
  String get cachedPassword {
    final tmp = _cachedPassword;
    _cachedPassword = null;
    return tmp;
  }

  set cachedPassword(String p) => _cachedPassword = p;

  String currentClientSecret;
  RequestTokenResponse currentThreepidCreds;

  void _onUiaRequest(UiaRequest uiaRequest) async {
    try {
      if (uiaRequest.state != UiaRequestState.waitForUser ||
          uiaRequest.nextStages.isEmpty) return;
      final stage = uiaRequest.nextStages.first;
      switch (stage) {
        case AuthenticationTypes.password:
          final input = cachedPassword ??
              (await showTextInputDialog(
                context: context,
                title: L10n.of(context).pleaseEnterYourPassword,
                okLabel: L10n.of(context).ok,
                cancelLabel: L10n.of(context).cancel,
                useRootNavigator: false,
                textFields: [
                  DialogTextField(
                    minLines: 1,
                    maxLines: 1,
                    obscureText: true,
                    hintText: '******',
                  )
                ],
              ))
                  ?.single;
          if (input?.isEmpty ?? true) return;
          return uiaRequest.completeStage(
            AuthenticationPassword(
              session: uiaRequest.session,
              user: client.userID,
              password: input,
              identifier: AuthenticationUserIdentifier(user: client.userID),
            ),
          );
        case AuthenticationTypes.emailIdentity:
          if (currentClientSecret == null || currentThreepidCreds == null) {
            return uiaRequest
                .cancel(Exception('This server requires an email address'));
          }
          final auth = AuthenticationThreePidCreds(
            session: uiaRequest.session,
            type: AuthenticationTypes.emailIdentity,
            threepidCreds: [
              ThreepidCreds(
                sid: currentThreepidCreds.sid,
                clientSecret: currentClientSecret,
              ),
            ],
          );
          currentThreepidCreds = currentClientSecret = null;
          return uiaRequest.completeStage(auth);
        case AuthenticationTypes.dummy:
          return uiaRequest.completeStage(
            AuthenticationData(
              type: AuthenticationTypes.dummy,
              session: uiaRequest.session,
            ),
          );
        default:
          await launch(
            client.homeserver.toString() +
                '/_matrix/client/r0/auth/$stage/fallback/web?session=${uiaRequest.session}',
          );
          if (OkCancelResult.ok ==
              await showOkCancelAlertDialog(
                message: L10n.of(context).pleaseFollowInstructionsOnWeb,
                context: context,
                useRootNavigator: false,
                okLabel: L10n.of(context).next,
                cancelLabel: L10n.of(context).cancel,
              )) {
            return uiaRequest.completeStage(
              AuthenticationData(session: uiaRequest.session),
            );
          } else {
            return uiaRequest.cancel();
          }
      }
    } catch (e, s) {
      Logs().e('Error while background UIA', e, s);
      return uiaRequest.cancel(e);
    }
  }

  bool webHasFocus = true;

  void _showLocalNotification(EventUpdate eventUpdate) async {
    final roomId = eventUpdate.roomID;
    if (webHasFocus && client.activeRoomId == roomId) return;
    final room = client.getRoomById(roomId);
    if (room.notificationCount == 0) return;
    final event = Event.fromJson(eventUpdate.content, room);
    final title = room.getLocalizedDisplayname(MatrixLocals(L10n.of(context)));
    final body = event.getLocalizedBody(
      MatrixLocals(L10n.of(context)),
      withSenderNamePrefix:
          !room.isDirectChat || room.lastEvent.senderId == client.userID,
    );
    final icon = event.sender.avatarUrl?.getThumbnail(client,
            width: 64, height: 64, method: ThumbnailMethod.crop) ??
        room.avatar?.getThumbnail(client,
            width: 64, height: 64, method: ThumbnailMethod.crop);
    if (kIsWeb) {
      html.AudioElement()
        ..src = 'assets/assets/sounds/notification.wav'
        ..autoplay = true
        ..load();
      html.Notification(
        title,
        body: body,
        icon: icon.toString(),
      );
    } else if (Platform.isLinux) {
      await linuxNotifications.notify(
        title,
        body: body,
        replacesId: _linuxNotificationIds[roomId] ?? -1,
        appName: AppConfig.applicationName,
      );
    }
  }

  final linuxNotifications =
      PlatformInfos.isLinux ? NotificationsClient() : null;
  final Map<String, int> _linuxNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initMatrix();
    if (PlatformInfos.isWeb) {
      initConfig().then((_) => initSettings());
    } else {
      initSettings();
    }
  }

  Future<void> initConfig() async {
    try {
      final configJsonString =
          utf8.decode((await http.get(Uri.parse('config.json'))).bodyBytes);
      final configJson = json.decode(configJsonString);
      AppConfig.loadFromJson(configJson);
    } catch (e, s) {
      Logs().v('[ConfigLoader] Failed to load config.json', e, s);
    }
  }

  LoginState loginState;

  void initMatrix() {
    // Display the app lock
    if (PlatformInfos.isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterSecureStorage().read(key: SettingKeys.appLockKey).then((lock) {
          if (lock?.isNotEmpty ?? false) {
            AppLock.of(context).enable();
            AppLock.of(context).showLockScreen();
          }
        });
      });
    }
    client = FluffyClient();
    LoadingDialog.defaultTitle = L10n.of(context).loadingPleaseWait;
    LoadingDialog.defaultBackLabel = L10n.of(context).close;
    LoadingDialog.defaultOnError = (Object e) => e.toLocalizedString(context);

    onRoomKeyRequestSub ??=
        client.onRoomKeyRequest.stream.listen((RoomKeyRequest request) async {
      final room = request.room;
      if (request.sender != room.client.userID) {
        return; // ignore share requests by others
      }
      final sender = room.getUserByMXIDSync(request.sender);
      if (await showOkCancelAlertDialog(
            context: context,
            useRootNavigator: false,
            title: L10n.of(context).requestToReadOlderMessages,
            message:
                '${sender.id}\n\n${L10n.of(context).device}:\n${request.requestingDevice.deviceId}\n\n${L10n.of(context).publicKey}:\n${request.requestingDevice.ed25519Key.beautified}',
            okLabel: L10n.of(context).verify,
            cancelLabel: L10n.of(context).deny,
          ) ==
          OkCancelResult.ok) {
        await request.forwardKey();
      }
    });
    onKeyVerificationRequestSub ??= client.onKeyVerificationRequest.stream
        .listen((KeyVerification request) async {
      var hidPopup = false;
      request.onUpdate = () {
        if (!hidPopup &&
            {KeyVerificationState.done, KeyVerificationState.error}
                .contains(request.state)) {
          Navigator.of(context, rootNavigator: true).pop('dialog');
        }
        hidPopup = true;
      };
      if (await showOkCancelAlertDialog(
            context: context,
            useRootNavigator: false,
            title: L10n.of(context).newVerificationRequest,
            message: L10n.of(context).askVerificationRequest(request.userId),
            okLabel: L10n.of(context).ok,
            cancelLabel: L10n.of(context).cancel,
          ) ==
          OkCancelResult.ok) {
        request.onUpdate = null;
        hidPopup = true;
        await request.acceptVerification();
        await KeyVerificationDialog(request: request).show(context);
      } else {
        request.onUpdate = null;
        hidPopup = true;
        await request.rejectVerification();
      }
    });
    _initWithStore();

    if (kIsWeb) {
      onFocusSub = html.window.onFocus.listen((_) => webHasFocus = true);
      onBlurSub = html.window.onBlur.listen((_) => webHasFocus = false);
    }
    onLoginStateChanged ??= client.onLoginStateChanged.stream.listen((state) {
      if (loginState != state) {
        loginState = state;
        widget.apl.currentState.pushNamedAndRemoveAllOthers('/');
      }
    });

    // Cache and resend status message
    onOwnPresence ??= client.onPresence.stream.listen((presence) {
      if (client.isLogged() &&
          client.userID == presence.senderId &&
          presence.presence?.statusMsg != null) {
        Logs().v('Update status message: "${presence.presence.statusMsg}"');
        store.setItem(
            SettingKeys.ownStatusMessage, presence.presence.statusMsg);
      }
    });

    onUiaRequest ??= client.onUiaRequest.stream.listen(_onUiaRequest);
    if (PlatformInfos.isWeb || PlatformInfos.isLinux) {
      client.onSync.stream.first.then((s) {
        html.Notification.requestPermission();
        onNotification ??= client.onEvent.stream
            .where((e) =>
                e.type == EventUpdateType.timeline &&
                [EventTypes.Message, EventTypes.Sticker, EventTypes.Encrypted]
                    .contains(e.content['type']) &&
                e.content['sender'] != client.userID)
            .listen(_showLocalNotification);
      });
    }

    if (PlatformInfos.isMobile) {
      _backgroundPush = BackgroundPush(client, context, widget.apl);
    }
  }

  bool _firstStartup = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logs().v('AppLifecycleState = $state');
    final foreground = state != AppLifecycleState.detached &&
        state != AppLifecycleState.paused;
    client.backgroundSync = foreground;
    client.syncPresence = foreground ? null : PresenceType.unavailable;
    client.requestHistoryOnLimitedTimeline = !foreground;
    if (_firstStartup) {
      _firstStartup = false;
      _backgroundPush?.setupPush();
    }
  }

  void initSettings() {
    if (store != null) {
      store.getItem(SettingKeys.jitsiInstance).then((final instance) =>
          AppConfig.jitsiInstance = instance ?? AppConfig.jitsiInstance);
      store.getItem(SettingKeys.wallpaper).then((final path) async {
        if (path == null) return;
        final file = File(path);
        if (await file.exists()) {
          wallpaper = file;
        }
      });
      store.getItem(SettingKeys.fontSizeFactor).then((value) =>
          AppConfig.fontSizeFactor =
              double.tryParse(value ?? '') ?? AppConfig.fontSizeFactor);
      store
          .getItemBool(SettingKeys.renderHtml, AppConfig.renderHtml)
          .then((value) => AppConfig.renderHtml = value);
      store
          .getItemBool(
              SettingKeys.hideRedactedEvents, AppConfig.hideRedactedEvents)
          .then((value) => AppConfig.hideRedactedEvents = value);
      store
          .getItemBool(
              SettingKeys.hideUnknownEvents, AppConfig.hideUnknownEvents)
          .then((value) => AppConfig.hideUnknownEvents = value);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    onRoomKeyRequestSub?.cancel();
    onKeyVerificationRequestSub?.cancel();
    onLoginStateChanged?.cancel();
    onOwnPresence?.cancel();
    onNotification?.cancel();
    onFocusSub?.cancel();
    onBlurSub?.cancel();
    _backgroundPush?.onLogin?.cancel();

    linuxNotifications.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider(
      create: (_) => this,
      child: widget.child,
    );
  }
}

class FixedThreepidCreds extends ThreepidCreds {
  FixedThreepidCreds({
    String sid,
    String clientSecret,
    String idServer,
    String idAccessToken,
  }) : super(
          sid: sid,
          clientSecret: clientSecret,
          idServer: idServer,
          idAccessToken: idAccessToken,
        );

  @override
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['sid'] = sid;
    data['client_secret'] = clientSecret;
    if (idServer != null) data['id_server'] = idServer;
    if (idAccessToken != null) data['id_access_token'] = idAccessToken;
    return data;
  }
}
