import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoga_app/video.dart';

class Database {
  List<YogaVideo> videos = [];
  List<String> tags = [];

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load tags
    final String? tagsJson = prefs.getString('yoga_tags');
    if (tagsJson != null) {
      try {
        final List<dynamic> decodedTags = jsonDecode(tagsJson);
        tags = decodedTags.map((e) => e.toString()).toList();
      } catch (e) {
        // use default
      }
    }

    // Load videos
    final String? videosJson = prefs.getString('yoga_videos');
    if (videosJson != null) {
      try {
        final List<dynamic> decodedVideos = jsonDecode(videosJson);
        videos = decodedVideos.map((item) => YogaVideo.fromJson(item)).toList();
      } catch (e) {
        // handle error
      }
    }

    // Cache missing thumbnails in background for stored items
    for (var video in videos) {
      if (video.thumbnailBase64 == null) {
        video.downloadThumbnailAsBase64().then((base64Str) {
          if (base64Str != null) {
            final index = videos.indexWhere((v) => v.id == video.id);
            if (index != -1) {
              videos[index] = YogaVideo(
                id: videos[index].id,
                title: videos[index].title,
                url: videos[index].url,
                videoId: videos[index].videoId,
                tags: videos[index].tags,
                thumbnailBase64: base64Str,
              );
            }
          }
          saveData();
        });
      }
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedVideos = jsonEncode(
      videos.map((v) => v.toJson()).toList(),
    );
    await prefs.setString('yoga_videos', encodedVideos);

    final String encodedTags = jsonEncode(tags);
    await prefs.setString('yoga_tags', encodedTags);
  }
}
