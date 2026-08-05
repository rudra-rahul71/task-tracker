import 'package:flutter/material.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';

class SnackbarService {
  BuildContext context;

  SnackbarService(this.context);

  void showSuccessSnackbar({required String message}) {
    AppBannerService.showSuccess(context, message);
  }

  void showErrorSnackbar({required String message}) {
    AppBannerService.showError(context, message);
  }
}
