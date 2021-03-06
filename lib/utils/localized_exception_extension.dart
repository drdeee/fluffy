import 'dart:io';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

extension LocalizedExceptionExtension on Object {
  String toLocalizedString(BuildContext context) {
    if (this is MatrixException) {
      switch ((this as MatrixException).error) {
        case MatrixError.M_FORBIDDEN:
          return L10n.of(context).noPermission;
        case MatrixError.M_LIMIT_EXCEEDED:
          return L10n.of(context).tooManyRequestsWarning;
        default:
          return (this as MatrixException).errorMessage;
      }
    }
    if (this is BadServerVersionsException) {
      final serverVersions = (this as BadServerVersionsException)
          .serverVersions
          .toString()
          .replaceAll('{', '"')
          .replaceAll('}', '"');
      final supportedVersions = (this as BadServerVersionsException)
          .supportedVersions
          .toString()
          .replaceAll('{', '"')
          .replaceAll('}', '"');
      return L10n.of(context)
          .badServerVersionsException(serverVersions, supportedVersions);
    }
    if (this is BadServerLoginTypesException) {
      final serverVersions = (this as BadServerLoginTypesException)
          .serverLoginTypes
          .toString()
          .replaceAll('{', '"')
          .replaceAll('}', '"');
      final supportedVersions = (this as BadServerLoginTypesException)
          .supportedLoginTypes
          .toString()
          .replaceAll('{', '"')
          .replaceAll('}', '"');
      return L10n.of(context)
          .badServerLoginTypesException(serverVersions, supportedVersions);
    }
    if (this is MatrixConnectionException || this is SocketException) {
      L10n.of(context).noConnectionToTheServer;
    }
    Logs().w('Something went wrong: ', this);
    return L10n.of(context).oopsSomethingWentWrong;
  }
}
