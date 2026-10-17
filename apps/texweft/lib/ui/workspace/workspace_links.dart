import 'package:url_launcher/url_launcher.dart';

import 'workspace_view_model.dart';

Future<void> openWorkspaceLink(WorkspaceViewModel vm, String? href) async {
  if (href == null) return;
  if (href.startsWith('#')) {
    vm.followAnchor(href);
    return;
  }
  final uri = Uri.tryParse(href);
  if (uri != null && ['https', 'http', 'mailto'].contains(uri.scheme)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
