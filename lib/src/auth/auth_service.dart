import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:httpp/httpp.dart';
import 'package:logging/logging.dart';

import '../error/error_http.dart';
import '../error/error_model_rsp.dart';
import 'auth_controller.dart';
import 'auth_model.dart';
import 'auth_presenter.dart';
import 'auth_repository.dart';

class AuthService extends ChangeNotifier {
  final Logger _log = Logger('GoogleProviderService');

  static const String _redirectUri = "com.mytiki.app:/oauth";
  static const String _androidClientId =
      "240428403253-8bof2prkdatnsm8d2msgq2r81r12p5np.apps.googleusercontent.com";
  static const String _iosClientId =
      "240428403253-v4qk9lt2l07cc8am12gggocpbbsjdvl7.apps.googleusercontent.com";
  static const String _authorizationEndpoint =
      "https://accounts.google.com/o/oauth2/v2/auth";
  static const String _tokenEndpoint =
      "https://www.googleapis.com/oauth2/v4/token";
  static const List<String> _scopes = [
    "openid",
    "https://www.googleapis.com/auth/userinfo.profile",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send"
  ];

  static get _clientId => Platform.isIOS ? _iosClientId : _androidClientId;

  AuthModel model;
  late final AuthPresenter presenter;
  late final AuthController controller;

  final Function(AuthModel)? onLink;
  final Function(String?)? onUnlink;
  final Function(
      {String? accessToken,
      DateTime? accessExp,
      String? refreshToken,
      DateTime? refreshExp})? onRefresh;
  final HttppClient client;

  late final AuthRepository _repository;
  final FlutterAppAuth _appAuth;

  AuthService({Httpp? httpp, model, this.onLink, this.onUnlink, this.onRefresh})
      : model = model ?? AuthModel(),
        _appAuth = FlutterAppAuth(),
        client = httpp == null ? Httpp().client() : httpp.client() {
    presenter = AuthPresenter(this);
    controller = AuthController(this);
    _repository = AuthRepository();
  }

  Future<void> signIn() async {
    AuthorizationTokenResponse? tokenResponse =
        await _authorizeAndExchangeCode();
    if (tokenResponse != null) {
      _log.finest(
          "authorizeAndExchangeCode success - ${tokenResponse.tokenType}");
      model.token = tokenResponse.accessToken;
      model.accessTokenExp = tokenResponse.accessTokenExpirationDateTime;
      model.refreshToken = tokenResponse.refreshToken;
      await updateUserInfo(onSuccess: onLink);
      notifyListeners();
    }
  }

  Future<void> updateUserInfo({Function(AuthModel)? onSuccess}) async {
    await _repository.userInfo(
        accessToken: model.token!,
        client: client,
        onSuccess: (response) {
          model.displayName = response?.body?.jsonBody['name'];
          model.email = response?.body?.jsonBody['email'];
          model.isLinked = true;
          if (onSuccess != null) {
            onSuccess(model);
          }
        },
        onError: (err) {
          if (err is HttppResponse) {
            if (HttppUtils.isUnauthorized(err.statusCode)) {
              _log.warning('Unauthorized. Trying refresh');
              client.denyUntil(err.request!, () async {
                await refreshToken();
                err.request?.headers?.auth(model.token);
              });
            } else {
              ErrorModelRsp body = ErrorModelRsp.fromJson(err.body?.jsonBody);
              throw ErrorHttp(body);
            }
          } else {
            _log.severe(err);
            throw err;
          }
        });
  }

  Future<void> signOut() async {
    await _repository.revokeToken(accessToken: model.token!, client: client);
    if (onUnlink != null) {
      onUnlink!(model.email);
    }
    model = AuthModel();
    notifyListeners();
  }

  Future<void> refreshToken() async {
    try {
      TokenResponse tokenResponse = (await _appAuth.token(TokenRequest(
          _clientId, _redirectUri,
          serviceConfiguration: const AuthorizationServiceConfiguration(
              authorizationEndpoint: _authorizationEndpoint,
              tokenEndpoint: _tokenEndpoint),
          refreshToken: model.refreshToken,
          scopes: _scopes)))!;
      model.token = tokenResponse.accessToken;
      model.refreshToken = tokenResponse.refreshToken;
      if (onRefresh != null) {
        onRefresh!(
            accessToken: tokenResponse.accessToken,
            accessExp: tokenResponse.accessTokenExpirationDateTime,
            refreshToken: tokenResponse.refreshToken);
      }
    } catch (err) {
      _log.severe(err.toString());
      rethrow;
    }
  }

  Future<AuthorizationTokenResponse?> _authorizeAndExchangeCode() async {
    AuthorizationServiceConfiguration authConfig =
        const AuthorizationServiceConfiguration(
            authorizationEndpoint: _authorizationEndpoint,
            tokenEndpoint: _tokenEndpoint);
    List<String> providerScopes = _scopes;
    return await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(_clientId, _redirectUri,
          promptValues: null,
          serviceConfiguration: authConfig,
          scopes: providerScopes),
    );
  }
}