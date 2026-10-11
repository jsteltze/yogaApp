import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YogaVideo {
  final String id;
  final String title;
  final String url;
  final String videoId;
  final List<String> tags;
  final String? thumbnailBase64;

  YogaVideo({
    required this.id,
    required this.title,
    required this.url,
    required this.videoId,
    required this.tags,
    this.thumbnailBase64,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'videoId': videoId,
    'tags': tags,
    'thumbnailBase64': thumbnailBase64,
  };

  factory YogaVideo.fromJson(Map<String, dynamic> json) => YogaVideo(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    url: json['url'] ?? '',
    videoId: json['videoId'] ?? '',
    tags: List<String>.from(json['tags'] ?? []),
    thumbnailBase64: json['thumbnailBase64'],
  );

  static String? extractVideoId(String url) {
    final regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.group(2)!.length == 11) {
      return match.group(2);
    }
    return null;
  }

  String getThumbnailUrl() {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  Future<String?> downloadThumbnailAsBase64() async {
    try {
      final url = Uri.parse(getThumbnailUrl());
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      }
    } catch (e) {
      // Ignore network errors
    }
    return null;
  }

  void playVideo(YoutubePlayerController? controller) {
    controller?.close();
    controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }
}
