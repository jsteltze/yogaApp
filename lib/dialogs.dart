import 'dart:math';

import 'package:flutter/material.dart';
import 'package:js_flutter/components/input_field.dart';
import 'package:js_flutter/utils/dialog_utils.dart';
import 'package:js_flutter/utils/snackbar_utils.dart';
import 'package:yoga_app/video.dart';

import 'database.dart';

void selectRandomVideo(
  BuildContext context,
  List<YogaVideo> filtered,
  Function playVideo,
) {
  if (filtered.isEmpty) return;

  final random = Random();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          int displayIndex = random.nextInt(filtered.length);
          final stopwatch = Stopwatch()..start();

          void roll() {
            if (stopwatch.elapsedMilliseconds < 3000) {
              if (Navigator.canPop(dialogContext)) {
                setDialogState(() {
                  displayIndex = random.nextInt(filtered.length);
                });
                Future.delayed(const Duration(milliseconds: 120), roll);
              }
            } else {
              final winningVideo = filtered[random.nextInt(filtered.length)];
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
                playVideo(winningVideo);
                showSnackbar(context, '🎲 Selected: ${winningVideo.title}');
              }
            }
          }

          // Kick off rolling animation
          Future.delayed(const Duration(milliseconds: 120), roll);

          final currentDisplayVideo = filtered[displayIndex];

          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  '🎲 Rolling for a random video...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentDisplayVideo.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

void showVideoDialog(
  BuildContext context,
  Database db,
  Function onSubmitted, {
  YogaVideo? video,
  String? initialUrl,
}) {
  final isEditing = video != null;
  final urlController = TextEditingController(
    text: isEditing ? video.url : (initialUrl ?? ''),
  );
  final titleController = TextEditingController(
    text: isEditing ? video.title : '',
  );
  final inlineTagController = TextEditingController();
  Set<String> selectedTags = isEditing ? Set.from(video.tags) : {};
  List<String> localAvailableTags = List.from(db.tags);
  bool isAddingTag = false;

  openDialog(
    context,
    title: isEditing ? 'Edit YouTube Video' : 'Add YouTube Video',
    titleIcon: Icons.video_library,
    child: (ctx, setDialogState, toggleMainAction) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputField('Title (optional)', titleController, isOptional: true),
        const SizedBox(height: 12),
        InputField('YouTube URL', urlController),
        const SizedBox(height: 16),
        const Text(
          'Select Tags                                                                            ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6.0,
          runSpacing: 4.0,
          children: [
            ...localAvailableTags.map((tag) {
              final isSelected = selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) {
                  setDialogState(() {
                    if (selected) {
                      selectedTags.add(tag);
                    } else {
                      selectedTags.remove(tag);
                    }
                  });
                },
              );
            }),
            if (isAddingTag)
              SizedBox(
                width: 120,
                height: 36,
                child: TextField(
                  controller: inlineTagController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Tag name',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (value) {
                    final newTag = value.trim();
                    if (newTag.isNotEmpty) {
                      setDialogState(() {
                        if (!localAvailableTags.contains(newTag)) {
                          localAvailableTags.add(newTag);
                        }
                        selectedTags.add(newTag);
                        inlineTagController.clear();
                        isAddingTag = false;
                      });
                    } else {
                      setDialogState(() {
                        isAddingTag = false;
                      });
                    }
                  },
                ),
              )
            else
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New Tag'),
                onPressed: () {
                  setDialogState(() {
                    isAddingTag = true;
                  });
                },
              ),
          ],
        ),
      ],
    ),
    mainAction: DialogAction(
      title: 'Save',
      onPressed: () async {
        final dialogContext = context;
        final url = urlController.text.trim();
        final videoId = YogaVideo.extractVideoId(url);
        if (videoId == null) {
          showSnackbar(
            context,
            'Invalid YouTube URL. Please check and try again.',
            true,
          );
          return;
        }
        final title = titleController.text.trim().isEmpty
            ? 'Yoga Video ($videoId)'
            : titleController.text.trim();

        // Download thumbnail as base64 for local storage
        String? thumbBase64 = isEditing ? video.thumbnailBase64 : null;
        if (!isEditing || video.videoId != videoId || thumbBase64 == null) {
          thumbBase64 = await video?.downloadThumbnailAsBase64();
        }

        if (!context.mounted) return;

        if (isEditing) {
          final index = db.videos.indexWhere((v) => v.id == video.id);
          if (index != -1) {
            db.videos[index] = YogaVideo(
              id: video.id,
              title: title,
              url: url,
              videoId: videoId,
              tags: selectedTags.toList(),
              thumbnailBase64: thumbBase64,
            );
            onSubmitted(db.videos[index]);
          }
        } else {
          final newVideo = YogaVideo(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            url: url,
            videoId: videoId,
            tags: selectedTags.toList(),
            thumbnailBase64: thumbBase64,
          );
          db.videos.insert(0, newVideo);
          onSubmitted(newVideo);
        }

        for (var tag in localAvailableTags) {
          if (!db.tags.contains(tag)) {
            db.tags.add(tag);
          }
        }
        db.saveData();

        if (!dialogContext.mounted) return;
        Navigator.pop(dialogContext);
      },
    ),
  );
}
