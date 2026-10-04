import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'globals.dart';

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
}

class YogaVideoScreen extends StatefulWidget {
  const YogaVideoScreen({super.key, required this.title});

  final String title;

  @override
  State<YogaVideoScreen> createState() => _YogaVideoScreenState();
}

class _YogaVideoScreenState extends State<YogaVideoScreen> {
  List<YogaVideo> _videos = [];
  List<String> _availableTags = ['Morning', 'Stretch', 'Vinyasa', 'Relaxation', 'Beginner'];
  final Set<String> _selectedFilterTags = {};
  YoutubePlayerController? _controller;
  YogaVideo? _currentVideo;
  bool _isLoading = true;
  StreamSubscription? _textSub;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Listen to share intents while app is open
    _textSub = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final sharedText = value.first.path;
        if (sharedText.isNotEmpty) {
          _handleSharedText(sharedText);
        }
      }
    }, onError: (err) {
      // handle error
    });

    // Get share intent when app is launched from closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final sharedText = value.first.path;
        if (sharedText.isNotEmpty) {
          _handleSharedText(sharedText);
          ReceiveSharingIntent.instance.reset();
        }
      }
    });
  }

  void _handleSharedText(String text) {
    final videoId = _extractVideoId(text);
    if (videoId != null || text.contains('youtube.com') || text.contains('youtu.be')) {
      String urlToUse = text;
      final uriMatch = RegExp(r'https?://[^\s]+').firstMatch(text);
      if (uriMatch != null) {
        urlToUse = uriMatch.group(0)!;
      }
      _showVideoDialog(initialUrl: urlToUse);
    }
  }

  String? _extractVideoId(String url) {
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

  String _getThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  Future<String?> _downloadThumbnailAsBase64(String videoId) async {
    try {
      final url = Uri.parse(_getThumbnailUrl(videoId));
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return base64Encode(response.bodyBytes);
      }
    } catch (e) {
      // Ignore network errors
    }
    return null;
  }

  List<YogaVideo> get _filteredVideos {
    if (_selectedFilterTags.isEmpty) {
      return _videos;
    }
    return _videos.where((video) {
      return video.tags.any((tag) => _selectedFilterTags.contains(tag));
    }).toList();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load tags
    final String? tagsJson = prefs.getString('yoga_tags');
    if (tagsJson != null) {
      try {
        final List<dynamic> decodedTags = jsonDecode(tagsJson);
        _availableTags = decodedTags.map((e) => e.toString()).toList();
      } catch (e) {
        // use default
      }
    }

    // Load videos
    final String? videosJson = prefs.getString('yoga_videos');
    if (videosJson != null) {
      try {
        final List<dynamic> decodedVideos = jsonDecode(videosJson);
        setState(() {
          _videos = decodedVideos.map((item) => YogaVideo.fromJson(item)).toList();
        });
      } catch (e) {
        // handle error
      }
    }
    setState(() {
      _isLoading = false;
    });

    // Add default sample yoga video if list is empty for immediate usability
    if (_videos.isEmpty) {
      await _addDefaultVideo();
    } else {
      // Cache missing thumbnails in background for stored items
      for (var video in _videos) {
        if (video.thumbnailBase64 == null) {
          _downloadThumbnailAsBase64(video.videoId).then((base64Str) {
            if (base64Str != null) {
              setState(() {
                final index = _videos.indexWhere((v) => v.id == video.id);
                if (index != -1) {
                  _videos[index] = YogaVideo(
                    id: _videos[index].id,
                    title: _videos[index].title,
                    url: _videos[index].url,
                    videoId: _videos[index].videoId,
                    tags: _videos[index].tags,
                    thumbnailBase64: base64Str,
                  );
                }
              });
              _saveData();
            }
          });
        }
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedVideos = jsonEncode(_videos.map((v) => v.toJson()).toList());
    await prefs.setString('yoga_videos', encodedVideos);

    final String encodedTags = jsonEncode(_availableTags);
    await prefs.setString('yoga_tags', encodedTags);
  }

  Future<void> _addDefaultVideo() async {
    const defaultUrl = 'https://www.youtube.com/watch?v=v7AYKMP6rOE';
    final videoId = _extractVideoId(defaultUrl) ?? 'v7AYKMP6rOE';
    final thumbBase64 = await _downloadThumbnailAsBase64(videoId);
    final video = YogaVideo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Morning Yoga Stretch (Sample)',
      url: defaultUrl,
      videoId: videoId,
      tags: ['Morning', 'Stretch'],
      thumbnailBase64: thumbBase64,
    );
    setState(() {
      _videos.add(video);
    });
    await _saveData();
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    final titleController = TextEditingController(text: isEditing ? video.title : '');
    final inlineTagController = TextEditingController();
    Set<String> selectedTags = isEditing ? Set.from(video.tags) : {};
    List<String> localAvailableTags = List.from(_availableTags);
    bool isAddingTag = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit YouTube Video' : 'Add YouTube Video Link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    hintText: 'e.g. Vinyasa Flow 20 min',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube URL',
                    hintText: 'https://www.youtube.com/watch?v=...',
                  ),
                ),
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
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final url = urlController.text.trim();
                final videoId = _extractVideoId(url);
                if (videoId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid YouTube URL. Please check and try again.'),
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
                  thumbBase64 = await _downloadThumbnailAsBase64(videoId);
                }

                if (!context.mounted) return;

                setState(() {
                  if (isEditing) {
                    final index = _videos.indexWhere((v) => v.id == video.id);
                    if (index != -1) {
                      _videos[index] = YogaVideo(
                        id: video.id,
                        title: title,
                        url: url,
                        videoId: videoId,
                        tags: selectedTags.toList(),
                        thumbnailBase64: thumbBase64,
                      );
                    }
                    if (_currentVideo?.id == video.id) {
                      _currentVideo = _videos.firstWhere((v) => v.id == video.id);
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
                    _videos.insert(0, newVideo);
                  }

                  for (var tag in localAvailableTags) {
                    if (!_availableTags.contains(tag)) {
                      _availableTags.add(tag);
                    }
                  }
                });
                _saveData();

                Navigator.pop(context);
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteVideo(YogaVideo video) {
    setState(() {
      _videos.removeWhere((v) => v.id == video.id);
      if (_currentVideo?.id == video.id) {
        _controller?.close();
        _controller = null;
        _currentVideo = null;
      }
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredVideos = _filteredVideos;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                if (_availableTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                    child: SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _availableTags.map((tag) {
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
                  child: _videos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.playlist_add, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text(
                                'No YouTube videos added yet.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showVideoDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Video Link'),
                              ),
                            ],
                          ),
                        )
                      : filteredVideos.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.filter_alt_off, size: 64, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No videos match the selected filters.',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
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
                                              _getThumbnailUrl(video.videoId),
                                              width: 80,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Container(
                                                width: 80,
                                                height: 60,
                                                color: Colors.grey.shade300,
                                                child: const Icon(Icons.videocam, color: Colors.grey),
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
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        if (video.tags.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4.0,
                                            runSpacing: 2.0,
                                            children: video.tags
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
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showVideoDialog(video: video);
                                        } else if (value == 'delete') {
                                          _deleteVideo(video);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 20),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 20),
                                              SizedBox(width: 8),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      tooltip: 'More options',
                                    ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48), // balance left spacing
            FloatingActionButton.extended(
              onPressed: _filteredVideos.isEmpty ? null : _selectRandomVideo,
              icon: const Icon(Icons.shuffle),
              label: const Text('Random Video'),
              tooltip: 'Select a random video from current filter',
            ),
            FloatingActionButton(
              onPressed: () => _showVideoDialog(),
              tooltip: 'Add Video',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
