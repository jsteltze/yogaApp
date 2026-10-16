import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:yoga_app/video.dart';

import 'database.dart';
import 'dialogs.dart';

StreamSubscription init(
  BuildContext ctx,
  Database database,
  Function onSubmitted,
) {
  // Get share intent when app is launched from closed state
  ReceiveSharingIntent.instance.getInitialMedia().then((
    List<SharedMediaFile> value,
  ) {
    if (value.isNotEmpty) {
      final sharedText = value.first.path;
      if (sharedText.isNotEmpty) {
        _handleSharedText(sharedText, ctx, database, onSubmitted);
        ReceiveSharingIntent.instance.reset();
      }
    }
  });

  return ReceiveSharingIntent.instance.getMediaStream().listen(
    (List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final sharedText = value.first.path;
        if (sharedText.isNotEmpty) {
          _handleSharedText(sharedText, ctx, database, onSubmitted);
        }
      }
    },
    onError: (err) {
      // handle error
    },
  );
}

void _handleSharedText(
  String text,
  BuildContext ctx,
  Database database,
  Function onSubmitted,
) {
  final videoId = YogaVideo.extractVideoId(text);
  if (videoId != null ||
      text.contains('youtube.com') ||
      text.contains('youtu.be')) {
    String urlToUse = text;
    final uriMatch = RegExp(r'https?://[^\s]+').firstMatch(text);
    if (uriMatch != null) {
      urlToUse = uriMatch.group(0)!;
    }
    showVideoDialog(ctx, database, onSubmitted, initialUrl: urlToUse);
  }
}
