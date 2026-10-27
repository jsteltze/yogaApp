import 'dart:async';

import 'package:flutter/material.dart';
import 'package:js_flutter/components/app_layout.dart';
import 'package:js_flutter/components/floating_action_button.dart';
import 'package:js_flutter/components/list_view_scroll_indicator.dart';
import 'package:js_flutter/components/no_data_tile.dart';
import 'package:js_flutter/components/popup_menu.dart';
import 'package:js_flutter/components/view_header.dart';
import 'package:js_flutter/icons.dart';
import 'package:js_flutter/utils/dialog_utils.dart';
import 'package:js_flutter/utils/first_time.dart';
import 'package:yoga_app/database.dart';
import 'package:yoga_app/video.dart';
import 'package:yoga_app/video_listview.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'dialogs.dart';
import 'intent_handler.dart';

void main() async {
  initApp(YogaVideoScreen());
}

class YogaVideoScreen extends StatefulWidget {
  const YogaVideoScreen({super.key});

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
    _textSub = init(context, _database, _onSubmitted);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkFirstTime(
        () => showWelcomeDialog(
          context,
          Icons.video_collection_outlined,
          'Thank you for using the Yoga Video Manager App!\n\nA simple video manager for Yoga videos on Android.',
        ),
      );
    });
  }

  void _onSubmitted(YogaVideo video) {
    setState(() {
      //_currentVideo = video;
    });
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

  @override
  void dispose() {
    _controller?.close();
    _textSub?.cancel();
    super.dispose();
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
    return createScaffold(
      context: context,
      actions: [
        createPopupMenu([
          DialogAction(
            title: 'View Logs',
            icon: Icons.list_alt,
            onPressed: () => showLogsDialog(context),
          ),
          DialogAction(
            title: 'App Info',
            icon: Icons.info_outline,
            onPressed: () => showAppInfoDialog(context),
          ),
        ]),
      ],
      child: Column(
        children: [
          // Video Player Section at top if a video is selected
          if (_currentVideo != null && _controller != null)
            Column(
              crossAxisAlignment: .start,
              children: [
                YoutubePlayer(controller: _controller!),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _currentVideo!.title,
                          style: Theme.of(context).textTheme.titleMedium,
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
          if (_database.videos.isNotEmpty)
            ViewHeader(
              padding: EdgeInsets.all(0),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    crossAxisAlignment: .center,
                    children: [
                      Padding(
                        padding: EdgeInsetsGeometry.only(left: 16),
                        child: Text(
                          'Your Yoga Videos (${_filteredVideos.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilterTags.clear();
                          });
                        },
                        child: Text(
                          _selectedFilterTags.isEmpty ? '' : 'Clear Filters',
                        ),
                      ),
                    ],
                  ),

                  // Tag Filter Bar
                  if (_database.tags.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListViewScrollIndicator(
                        child: ListView(
                          scrollDirection: .horizontal,
                          children: _database.tags.map((tag) {
                            final isSelected = _selectedFilterTags.contains(
                              tag,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(
                                  tag,
                                  style: Theme.of(context).textTheme.labelSmall!
                                      .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                ),
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
                ],
              ),
            ),

          // Video List
          Expanded(
            child: _database.videos.isEmpty
                ? NoDataTile(
                    text: 'No videos added yet.',
                    icon: Icons.playlist_add,
                  )
                : _filteredVideos.isEmpty
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
                : createListView(
                    _filteredVideos,
                    _currentVideo,
                    _database,
                    _onSubmitted,
                    _playVideo,
                    _deleteVideo,
                    context,
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: .end,
          spacing: 16,
          children: [
            if (_database.videos.isNotEmpty)
              FloatingActionButton.extended(
                onPressed: _filteredVideos.isEmpty
                    ? null
                    : () => selectRandomVideo(
                        context,
                        _filteredVideos,
                        _playVideo,
                      ),
                icon: const Icon(Icons.shuffle),
                label: const Text('Random Video'),
                tooltip: 'Select a random video from current filter',
              ),
            createFAB(
              context,
              'Add Video',
              addIcon,
              () => showVideoDialog(context, _database, _onSubmitted),
            ),
          ],
        ),
      ),
      isLoading: _isLoading,
    );
  }
}
