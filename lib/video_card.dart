import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:js_flutter/components/badge.dart';
import 'package:js_flutter/components/popup_menu.dart';
import 'package:js_flutter/icons.dart';
import 'package:js_flutter/utils/datetimex.dart';
import 'package:js_flutter/utils/dialog_utils.dart';
import 'package:yoga_app/video.dart';

class VideoCard extends StatelessWidget {
  final YogaVideo video;
  final bool isPlaying;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const VideoCard({
    super.key,
    required this.video,
    required this.isPlaying,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tags = video.tags;
    tags.sort();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPlaying
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : .none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: video.thumbnailBase64 != null
              ? Image.memory(
                  base64Decode(video.thumbnailBase64!),
                  width: 80,
                  height: 60,
                  fit: .cover,
                )
              : Image.network(
                  video.getThumbnailUrl(),
                  width: 80,
                  height: 60,
                  fit: .cover,
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
          overflow: .ellipsis,
          style: TextStyle(
            fontWeight: isPlaying ? .bold : .normal,
            color: isPlaying ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: .start,
          children: [
            if (video.count > 0) ...[
              Divider(height: 5),
              MyBadge(
                'Views: ${video.count}',
                variant: .ghost,
                icon: Icon(
                  Icons.numbers,
                  color: Theme.of(context).colorScheme.secondary.withAlpha(100),
                  applyTextScaling: true,
                  size: 18,
                ),
              ),
            ],
            if (video.lastPlayed != null) ...[
              MyBadge(
                'Last played: ${video.lastPlayed!.toDayDiff()}',
                variant: .ghost,
                icon: Icon(
                  Icons.access_time,
                  color: Theme.of(context).colorScheme.secondary.withAlpha(100),
                  applyTextScaling: true,
                  size: 18,
                ),
              ),
              Divider(height: 5),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4.0,
                runSpacing: 2.0,
                children: tags.map((tag) => MyBadge(tag)).toList(),
              ),
            ],
          ],
        ),
        trailing: onEdit == null || onDelete == null
            ? null
            : createPopupMenu([
                DialogAction(
                  title: 'Edit',
                  icon: editIcon,
                  onPressed: (_) => onEdit,
                ),
                DialogAction(
                  title: 'Delete',
                  icon: deleteIcon,
                  isDestructive: true,
                  onPressed: (_) => onDelete,
                ),
              ]),
        onTap: onTap,
      ),
    );
  }
}
