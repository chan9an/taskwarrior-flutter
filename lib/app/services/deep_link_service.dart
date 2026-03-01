import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:taskwarrior/app/modules/home/views/add_task_bottom_sheet_new.dart';
import 'package:taskwarrior/app/modules/home/controllers/home_controller.dart';
import 'package:taskwarrior/app/routes/app_pages.dart';

class DeepLinkService extends GetxService {
  late AppLinks _appLinks;
  String? queuedUri;

  Future<void> init() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        queuedUri = initialUri.toString();
        debugPrint('🔗 INITIAL LINK QUEUED: $queuedUri');
      }
    } catch (e) {
      debugPrint('Deep link init error (safe to ignore on unsupported platforms): $e');
    }

    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 LINK RECEIVED: $uri');
      _handleWidgetUri(uri);
    });
  }

  void _handleWidgetUri(Uri uri) {
    if (Get.isRegistered<HomeController>()) {
      _executeAction(uri, Get.find<HomeController>());
    } else {
      debugPrint("⏳ HomeController not ready. Queuing action.");
      queuedUri = uri.toString();
    }
  }

  void consumePendingActions(HomeController controller) {
    if (queuedUri != null) {
      debugPrint("🚀 Executing queued action...");
      _executeAction(Uri.parse(queuedUri!), controller);
      queuedUri = null;
    }
  }

  void _executeAction(Uri uri, HomeController controller) {
    final bool isTaskChampion = controller.taskchampion.value;
    final bool isReplica = controller.taskReplica.value;

    if (uri.host == "cardclicked") {
      if (uri.queryParameters["uuid"] != null &&
          uri.queryParameters["uuid"] != "NO_TASK" &&
          !isTaskChampion &&
          !isReplica) {
        String uuid = uri.queryParameters["uuid"] as String;
        Get.toNamed(Routes.DETAIL_ROUTE, arguments: ["uuid", uuid]);
      }
    } else if (uri.host == "addclicked") {
      if (Get.context != null) {
        Get.dialog(
          Material(
            child: AddTaskBottomSheet(
              homeController: controller,
              forTaskC: isTaskChampion,
              forReplica: isReplica,
            ),
          ),
        );
      }
    }
  }
}