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
import 'package:yoga_app/video_card.dart';
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
  late List<YogaVideo> _currentlyListed = [];
  YoutubePlayerController? _controller;
  YogaVideo? _currentVideo;
  bool _isLoading = true;
  bool _showNoDataView = false;
  StreamSubscription? _textSub;
  final Database _database = Database();
  final listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _database.loadData().then((_) {
      setState(() {
        _isLoading = false;
        _currentlyListed = _database.videos.toList();
      });
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

  void _doFiltering() {
    print('currently Listed: ${_currentlyListed}');
    print('filtered: ${_filteredVideos}');

    if (listKey.currentState != null) {
      print("listKey is NOT null");

      // remove due to filter
      for (int i = 0; i < _currentlyListed.length; i++) {
        if (!_filteredVideos.contains(_currentlyListed[i])) {
          int index = _database.videos.indexOf(_currentlyListed[i]);
          print('remove Index $index');
          listKey.currentState?.removeItem(
            i,
            (context, animation) =>
                VideoCard(animation: animation, video: _database.videos[index]),
          );
          _currentlyListed.removeAt(i--);
        }
      }

      print('finished removing');

      // add due to filter
      for (int i = 0; i < _filteredVideos.length; i++) {
        if (!_currentlyListed.contains(_filteredVideos[i])) {
          print('insert item');
          listKey.currentState?.insertItem(0);
        }
      }

      _currentlyListed = _filteredVideos.toList();

      if (_currentlyListed.isEmpty) {
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showNoDataView = true;
            });
          }
        });
      }
    } else {
      print("listKey is null");
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showNoDataView = false;
            _doFiltering();
          });
        }
      });
    }
  }

  void _onSubmitted(YogaVideo video) {
    setState(() {});
    int newIndex = 0;
    listKey.currentState!.insertItem(newIndex);
    _currentlyListed.insert(newIndex, video);
  }

  List<YogaVideo> get _filteredVideos {
    if (_selectedFilterTags.isEmpty) {
      return _database.videos;
    }
    return _database.videos.where((video) {
      return (video.tags.any((tag) => _selectedFilterTags.contains(tag)));
    }).toList();
  }

  void _playVideo(YogaVideo video) {
    _controller?.close();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: video.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    setState(() {
      _currentVideo = video;
      _currentVideo?.count++;
      _currentVideo?.lastPlayed = DateTime.now();
    });
    _database.saveData();
  }

  @override
  void dispose() {
    _controller?.close();
    _textSub?.cancel();
    super.dispose();
  }

  void _deleteVideo(YogaVideo video) {
    int index = _database.videos.indexOf(video);
    _database.videos.removeAt(index);

    if (_currentVideo?.id == video.id) {
      setState(() {
        _controller?.close();
        _controller = null;
        _currentVideo = null;
      });
    }
    _database.saveData();
    _currentlyListed.remove(video);

    if (_currentlyListed.isEmpty) {
      return;
    }

    listKey.currentState!.removeItem(
      index,
      (context, animation) => VideoCard(animation: animation, video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noDataFiltered = NoDataTile(
      text: 'No videos match the selected filters.',
      icon: Icons.filter_alt_off,
      actionButton: DialogAction(
        title: 'Clear Filters',
        onPressed: (_) {
          setState(() {
            _selectedFilterTags.clear();
            _doFiltering();
          });
        },
      ),
    );

    return createScaffold(
      context: context,
      actions: [
        createPopupMenu([
          DialogAction(
            title: 'View Logs',
            icon: Icons.list_alt,
            onPressed: (_) => showLogsDialog(context),
          ),
          DialogAction(
            title: 'App Info',
            icon: Icons.info_outline,
            onPressed: (_) => showAppInfoDialog(context),
          ),
        ]),
      ],
      child: Column(
        children: [
          // Video Player Section at top if a video is selected
          AnimatedSwitcher(
            duration: Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                SizeTransition(sizeFactor: animation, child: child),
            child: _controller != null
                ? Column(
                    key: ValueKey<bool>(_currentVideo != null),
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
                : const SizedBox.shrink(),
          ),

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
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          'Your Yoga Videos (${_filteredVideos.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (_selectedFilterTags.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilterTags.clear();
                              _doFiltering();
                            });
                          },
                          child: Text('Clear Filters'),
                        ),
                    ],
                  ),

                  // Tag Filter Bar
                  if (_database.tags.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListViewScrollIndicator(
                        scrollDirection: .horizontal,
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
                                    _doFiltering();
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
                : _filteredVideos.isEmpty && _showNoDataView
                ? noDataFiltered
                : AnimatedList(
                    key: listKey,
                    initialItemCount: _showNoDataView
                        ? 0
                        : _database.videos.length,
                    itemBuilder: (context, index, animation) => VideoCard(
                      animation: animation,
                      video: _currentlyListed[index],
                      isPlaying:
                          _currentVideo?.id == _currentlyListed[index].id,
                      onEdit: (_) => showVideoDialog(
                        context,
                        _database,
                        _onSubmitted,
                        video: _currentlyListed[index],
                      ),
                      onDelete: (_) => _deleteVideo(_currentlyListed[index]),
                      onTap: () => _playVideo(_currentlyListed[index]),
                    ),
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
                        _selectedFilterTags,
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
