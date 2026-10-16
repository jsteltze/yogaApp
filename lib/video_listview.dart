import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:js_flutter/components/popup_menu.dart';
import 'package:js_flutter/icons.dart';
import 'package:js_flutter/utils/dialog_utils.dart';
import 'package:yoga_app/video.dart';

import 'database.dart';
import 'dialogs.dart';

ListView createListView(
  List<YogaVideo> filteredVideos,
  YogaVideo? currentVideo,
  Database db,
  Function onSubmitted,
  Function playVideo,
  Function deleteVideo,
  BuildContext context,
) {
  return ListView.builder(
    padding: const EdgeInsets.only(bottom: 80),
    itemCount: filteredVideos.length,
    itemBuilder: (context, index) {
      final video = filteredVideos[index];
      final tags = video.tags;
      tags.sort();
      final isPlaying = currentVideo?.id == video.id;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: isPlaying ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPlaying
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: video.thumbnailBase64 != null
                ? Image.memory(
                    base64Decode(video.thumbnailBase64!),
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    video.getThumbnailUrl(),
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => SizedBox(
                      width: 80,
                      height: 60,
                      child: const Icon(Icons.videocam),
                    ),
                  ),
          ),
          title: Text(
            video.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
              color: isPlaying ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                video.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4.0,
                  runSpacing: 2.0,
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          trailing: createPopupMenu([
            DialogAction(
              title: 'Edit',
              icon: editIcon,
              onPressed: () =>
                  showVideoDialog(context, db, onSubmitted, video: video),
            ),
            DialogAction(
              title: 'Delete',
              icon: deleteIcon,
              isDestructive: true,
              onPressed: () => deleteVideo(video),
            ),
          ]),
          onTap: () => playVideo(video),
        ),
      );
    },
  );
}
