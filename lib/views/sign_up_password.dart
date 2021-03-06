import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:adaptive_page_layout/adaptive_page_layout.dart';
import 'package:email_validator/email_validator.dart';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/utils/get_client_secret.dart';
import 'package:fluffychat/views/ui/sign_up_password_ui.dart';

import 'package:fluffychat/views/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import '../utils/platform_infos.dart';

class SignUpPassword extends StatefulWidget {
  final MatrixFile avatar;
  final String username;
  final String displayname;
  const SignUpPassword(this.username, {this.avatar, this.displayname});
  @override
  SignUpPasswordController createState() => SignUpPasswordController();
}

class SignUpPasswordController extends State<SignUpPassword> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String passwordError;
  String emailError;
  bool loading = false;
  bool showPassword = true;

  void toggleShowPassword() => setState(() => showPassword = !showPassword);

  void signUpAction() async {
    final matrix = Matrix.of(context);
    if (passwordController.text.isEmpty) {
      setState(() => passwordError = L10n.of(context).pleaseEnterYourPassword);
    } else {
      setState(() => passwordError = emailError = null);
    }

    if (passwordController.text.isEmpty) {
      return;
    }

    try {
      setState(() => loading = true);
      if (emailController.text.isNotEmpty) {
        emailController.text = emailController.text.trim();
        if (!EmailValidator.validate(emailController.text)) {
          setState(() => emailError = L10n.of(context).invalidEmail);
          return;
        }
        matrix.currentClientSecret = getClientSecret(30);
        Logs().d('Request email token');
        matrix.currentThreepidCreds = await matrix.client.requestEmailToken(
          emailController.text,
          matrix.currentClientSecret,
          1,
        );
        if (OkCancelResult.ok !=
            await showOkCancelAlertDialog(
              context: context,
              message: L10n.of(context).weSentYouAnEmail,
              okLabel: L10n.of(context).confirm,
              cancelLabel: L10n.of(context).cancel,
            )) {
          matrix.currentClientSecret = matrix.currentThreepidCreds = null;
          setState(() => loading = false);
          return;
        }
      }
      final waitForLogin = matrix.client.onLoginStateChanged.stream.first;
      await matrix.client.uiaRequestBackground((auth) => matrix.client.register(
            username: widget.username,
            password: passwordController.text,
            initialDeviceDisplayName: PlatformInfos.clientName,
            auth: auth,
          ));
      if (matrix.currentClientSecret != null &&
          matrix.currentThreepidCreds != null) {
        Logs().d('Add third party identifier');
        await matrix.client.add3PID(
          matrix.currentClientSecret,
          matrix.currentThreepidCreds.sid,
        );
      }
      await waitForLogin;
    } catch (exception) {
      setState(() => emailError = exception.toString());
      return setState(() => loading = false);
    }
    await matrix.client.onLoginStateChanged.stream
        .firstWhere((l) => l == LoginState.logged);
    // tchncs.de
    try {
      await matrix.client
          .setDisplayName(matrix.client.userID, widget.displayname);
    } catch (exception) {
      AdaptivePageLayout.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).couldNotSetDisplayname)));
    }
    if (widget.avatar != null) {
      try {
        await matrix.client.setAvatar(widget.avatar);
      } catch (exception) {
        AdaptivePageLayout.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context).couldNotSetAvatar)));
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => SignUpPasswordUI(this);
}
