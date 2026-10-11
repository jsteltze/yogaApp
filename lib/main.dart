import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:js_flutter/components/floating_action_button.dart';
import 'package:js_flutter/components/input_field.dart';
import 'package:js_flutter/components/no_data_tile.dart';
import 'package:js_flutter/components/popup_menu.dart';
import 'package:js_flutter/icons.dart';
import 'package:js_flutter/utils/dialog_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yoga_app/database.dart';
import 'package:yoga_app/video.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'globals.dart';
import 'intent_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  Globals.packageInfo = packageInfo;
  runApp(const YogaVideoApp());
}

class YogaVideoApp extends StatelessWidget {
  const YogaVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Globals.packageInfo.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: YogaVideoScreen(title: Globals.packageInfo.appName),
    );
  }
}

class YogaVideoScreen extends StatefulWidget {
  const YogaVideoScreen({super.key, required this.title});

  final String title;

  @override
  State<YogaVideoScreen> createState() => _YogaVideoScreenState();
}

class _YogaVideoScreenState extends State<YogaVideoScreen> {
  final Set<String> _selectedFilterTags = {};
  YoutubePlayerController? _controller;
  YogaVideo? _currentVideo;
  bool _isLoading = true;
  StreamSubscription? _textSub;
  final Database _database = Database();

  @override
  void initState() {
    super.initState();
    _database.loadData().then((_) {
      setState(() => _isLoading = false);
    });

    // Listen to share intents while app is open
    _textSub = init(_showVideoDialog);
  }

  List<YogaVideo> get _filteredVideos {
    if (_selectedFilterTags.isEmpty) {
      return _database.videos;
    }
    return _database.videos.where((video) {
      return video.tags.any((tag) => _selectedFilterTags.contains(tag));
    }).toList();
  }

  void _playVideo(YogaVideo video) {
    _controller?.close();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: video.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    setState(() {
      _currentVideo = video;
    });
  }

  void _selectRandomVideo() {
    final filtered = _filteredVideos;
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
                  _playVideo(winningVideo);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🎲 Selected: ${winningVideo.title}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
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

  @override
  void dispose() {
    _controller?.close();
    _textSub?.cancel();
    super.dispose();
  }

  void _showVideoDialog({YogaVideo? video, String? initialUrl}) {
    final isEditing = video != null;
    final urlController = TextEditingController(
      text: isEditing ? video.url : (initialUrl ?? ''),
    );
    final titleController = TextEditingController(
      text: isEditing ? video.title : '',
    );
    final inlineTagController = TextEditingController();
    Set<String> selectedTags = isEditing ? Set.from(video.tags) : {};
    List<String> localAvailableTags = List.from(_database.tags);
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
            'Select Tags',
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Invalid YouTube URL. Please check and try again.',
                ),
              ),
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

          setState(() {
            if (isEditing) {
              final index = _database.videos.indexWhere(
                (v) => v.id == video.id,
              );
              if (index != -1) {
                _database.videos[index] = YogaVideo(
                  id: video.id,
                  title: title,
                  url: url,
                  videoId: videoId,
                  tags: selectedTags.toList(),
                  thumbnailBase64: thumbBase64,
                );
              }
              if (_currentVideo?.id == video.id) {
                _currentVideo = _database.videos.firstWhere(
                  (v) => v.id == video.id,
                );
                if (_currentVideo!.videoId != video.videoId) {
                  _playVideo(_currentVideo!);
                }
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
              _database.videos.insert(0, newVideo);
            }

            for (var tag in localAvailableTags) {
              if (!_database.tags.contains(tag)) {
                _database.tags.add(tag);
              }
            }
          });
          _database.saveData();

          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _deleteVideo(YogaVideo video) {
    setState(() {
      _database.videos.removeWhere((v) => v.id == video.id);
      if (_currentVideo?.id == video.id) {
        _controller?.close();
        _controller = null;
        _currentVideo = null;
      }
    });
    _database.saveData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredVideos = _filteredVideos;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: Container(
          padding: const EdgeInsets.all(8),
          child: Image.asset('assets/yoga_logo.png'),
        ),
        title: FittedBox(fit: BoxFit.fitWidth, child: Text(widget.title)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Video Player Section at top if a video is selected
                if (_currentVideo != null && _controller != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      YoutubePlayer(controller: _controller!),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _currentVideo!.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _controller?.close();
                                setState(() {
                                  _controller = null;
                                  _currentVideo = null;
                                });
                              },
                              tooltip: 'Close player',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  )
                else
                  const SizedBox.shrink(),

                // Video List Header & Count
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Yoga Videos (${filteredVideos.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedFilterTags.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilterTags.clear();
                            });
                          },
                          child: const Text('Clear Filters'),
                        ),
                    ],
                  ),
                ),

                // Tag Filter Bar
                if (_database.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 2.0,
                    ),
                    child: SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _database.tags.map((tag) {
                          final isSelected = _selectedFilterTags.contains(tag);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedFilterTags.add(tag);
                                  } else {
                                    _selectedFilterTags.remove(tag);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),

                // Video List
                Expanded(
                  child: _database.videos.isEmpty
                      ? NoDataTile(
                          text: 'No YouTube videos added yet.',
                          icon: Icons.playlist_add,
                        )
                      : filteredVideos.isEmpty
                      ? NoDataTile(
                          text: 'No videos match the selected filters.',
                          icon: Icons.filter_alt_off,
                          actionButton: DialogAction(
                            title: 'Clear Filters',
                            onPressed: () {
                              setState(() {
                                _selectedFilterTags.clear();
                              });
                            },
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: filteredVideos.length,
                          itemBuilder: (context, index) {
                            final video = filteredVideos[index];
                            final isPlaying = _currentVideo?.id == video.id;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              elevation: isPlaying ? 4 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isPlaying
                                    ? BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
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
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  SizedBox(
                                                    width: 80,
                                                    height: 60,
                                                    child: const Icon(
                                                      Icons.videocam,
                                                    ),
                                                  ),
                                        ),
                                ),
                                title: Text(
                                  video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isPlaying
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isPlaying
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall!
                                          .copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                    ),
                                    if (video.tags.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4.0,
                                        runSpacing: 2.0,
                                        children: video.tags
                                            .map(
                                              (tag) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer
                                                      .withValues(alpha: 0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                        _showVideoDialog(video: video),
                                  ),
                                  DialogAction(
                                    title: 'Delete',
                                    icon: deleteIcon,
                                    isDestructive: true,
                                    onPressed: () => _deleteVideo(video),
                                  ),
                                ]),
                                onTap: () => _playVideo(video),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 16,
          children: [
            if (_database.videos.isNotEmpty)
              FloatingActionButton.extended(
                onPressed: _filteredVideos.isEmpty ? null : _selectRandomVideo,
                icon: const Icon(Icons.shuffle),
                label: const Text('Random Video'),
                tooltip: 'Select a random video from current filter',
              ),
            createFAB(context, 'Add Video', addIcon, _showVideoDialog),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
