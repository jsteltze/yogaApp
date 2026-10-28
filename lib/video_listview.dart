import 'package:flutter/material.dart';
import 'package:js_flutter/components/list_view_scroll_indicator.dart';
import 'package:yoga_app/video.dart';
import 'package:yoga_app/video_card.dart';

import 'database.dart';
import 'dialogs.dart';

Widget createListView(
  List<YogaVideo> filteredVideos,
  YogaVideo? currentVideo,
  Database db,
  Function onSubmitted,
  Function playVideo,
  Function deleteVideo,
  BuildContext context,
) {
  return ListViewScrollIndicator(
    child: ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredVideos.length,
      itemBuilder: (context, index) => VideoCard(
        video: filteredVideos[index],
        isPlaying: currentVideo?.id == filteredVideos[index].id,
        onEdit: () => showVideoDialog(
          context,
          db,
          onSubmitted,
          video: filteredVideos[index],
        ),
        onDelete: () => deleteVideo(filteredVideos[index]),
        onTap: () => playVideo(filteredVideos[index]),
      ),
    ),
  );
}
