import 'package:flutter/material.dart';

import 'web_embed_view_stub.dart'
    if (dart.library.html) 'web_embed_view_web.dart' as platform_impl;

class PlatformEmbedViewWidget extends StatefulWidget {
  final String embedUrl;

  const PlatformEmbedViewWidget({
    super.key,
    required this.embedUrl,
  });

  @override
  State<PlatformEmbedViewWidget> createState() => _PlatformEmbedViewWidgetState();
}

class _PlatformEmbedViewWidgetState extends State<PlatformEmbedViewWidget> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'embed-player-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return platform_impl.buildPlatformEmbedView(
      viewId: _viewId,
      embedUrl: widget.embedUrl,
    );
  }
}
