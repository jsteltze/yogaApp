import 'dart:async';

import 'package:js_flutter/components/app_layout.dart';
import 'package:js_flutter/components/floating_action_button.dart';
import 'package:js_flutter/components/list.dart';
import 'package:js_flutter/components/no_data_tile.dart';
import 'package:js_flutter/components/popup_menu.dart';
import 'package:js_flutter/components/view_header.dart';
import 'package:js_flutter/icons.dart';
import 'package:js_flutter/utils/dialog_utils.dart';
import 'package:js_flutter/utils/first_time.dart';
import 'package:material_ui/material_ui.dart';
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
    if (listKey.currentState != null) {
      // remove due to filter
      for (int i = 0; i < _currentlyListed.length; i++) {
        if (!_filteredVideos.contains(_currentlyListed[i])) {
          listKey.currentState?.removeItem(
            i,
            (_, anim) => VideoCard(animation: anim, video: _currentlyListed[i]),
          );
          _currentlyListed.removeAt(i--);
        }
      }

      // add due to filter
      for (int i = 0; i < _filteredVideos.length; i++) {
        if (!_currentlyListed.contains(_filteredVideos[i])) {
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
      // listKey.currentState is null so there was currently no
      // list displayed -> re-call _doFiltering
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
      return (_selectedFilterTags.every((tag) => video.tags.contains(tag)));
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
    _database.videos.remove(video);

    if (_currentVideo?.id == video.id) {
      setState(() {
        _controller?.close();
        _controller = null;
        _currentVideo = null;
      });
    }
    _database.saveData();

    listKey.currentState?.removeItem(
      _currentlyListed.indexOf(video),
      (context, animation) => VideoCard(animation: animation, video: video),
    );

    setState(() {
      _currentlyListed.remove(video);
    });

    if (_currentlyListed.isEmpty && _selectedFilterTags.isNotEmpty) {
      // show NoDataTile when filter result is empty
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showNoDataView = true;
          });
        }
      });
    }
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
                        child: Row(
                          spacing: 10,
                          children: [
                            Text(
                              'YOUR YOGA VIDEOS:',
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                            MyBadge(
                              _filtered.length.toString(),
                              icon: Icon(
                                _selectedFilterTags.isEmpty
                                    ? null
                                    : Icons.filter_alt_outlined,
                                applyTextScaling: true,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.6),
                              ),
                              variant: .outline,
                            ),
                          ],
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
                    MyList.of(
                      fixedHeight: 40,
                      orientation: .horizontal,
                      items: _database.tags.map((tag) {
                        final isSelected = _selectedFilterTags.contains(tag);
                        return FilterChip(
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
                        );
                      }).toList(),
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
                : MyList.animated(
                    listKey: listKey,
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
