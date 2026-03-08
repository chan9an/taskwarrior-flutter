import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:taskwarrior/app/modules/home/views/add_task_bottom_sheet_new.dart';
import 'package:taskwarrior/app/modules/home/controllers/home_controller.dart';
import 'package:taskwarrior/app/routes/app_pages.dart';

class DeepLinkService extends GetxService {
  late AppLinks _appLinks;
  Uri? _queuedUri;
  Uri? get queuedUri => _queuedUri;

  final QuickActions _quickActions = const QuickActions();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> init() async {
    _appLinks = AppLinks();

    await _initQuickActions();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _queuedUri = initialUri;
        debugPrint('🔗 INITIAL LINK QUEUED: $_queuedUri');
      }
    } catch (e) {
      debugPrint('Deep link init error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('🔗 LINK RECEIVED: $uri');
      _handleWidgetUri(uri);
    }, onError: (err) {
      debugPrint('🔗 LINK STREAM ERROR: $err');
    });
  }

  Future<void> _initQuickActions() async {
    await _quickActions.initialize((String shortcutType) {
      debugPrint("⚡ SHORTCUT RECEIVED: $shortcutType");
      if (shortcutType == 'shortcut_add_task') {
        _handleWidgetUri(Uri.parse('taskwarrior://addclicked'));
      } else if (shortcutType == 'shortcut_reports') {
        _handleWidgetUri(Uri.parse('taskwarrior://reports'));
      }
    });

    await _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'shortcut_add_task',
        localizedTitle: 'Add Task',
        icon: 'plus',
      ),
      const ShortcutItem(
        type: 'shortcut_reports',
        localizedTitle: 'Reports',
        icon: 'report',
      ),
    ]);
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }

  void _handleWidgetUri(Uri uri) {
    if (Get.isRegistered<HomeController>()) {
      _executeAction(uri, Get.find<HomeController>());
    } else {
      debugPrint("⏳ HomeController not ready. Queuing action.");
      _queuedUri = uri;
    }
  }

  void consumePendingActions(HomeController controller) {
    if (_queuedUri != null) {
      debugPrint("🚀 Executing queued action...");
      _executeAction(_queuedUri!, controller);
      _queuedUri = null;
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
    } else if (uri.host == "reports") {
      if (Get.context != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.toNamed(Routes.REPORTS);
        });
      }
    }
  }
}
