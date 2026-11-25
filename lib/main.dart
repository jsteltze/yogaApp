import 'dart:async';

import 'package:js_flutter/components/app_layout.dart';
import 'package:js_flutter/components/badge.dart';
import 'package:js_flutter/components/floating_action_button.dart';
import 'package:js_flutter/components/list.dart';
import 'package:js_flutter/components/no_data_tile.dart';
import 'package:js_flutter/components/popup_menu.dart';
import 'package:js_flutter/components/view_header.dart';
import 'package:js_flutter/icons.dart';
import 'package:js_flutter/utils/dialog_utils.dart';
import 'package:js_flutter/utils/first_time.dart';
import 'package:material_ui/material_ui.dart' hide DismissAction;
import 'package:yoga_app/database.dart';
import 'package:yoga_app/video.dart';
import 'package:yoga_app/video_card.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
  final GlobalKey<MyListState<YogaVideo>> list =
      GlobalKey<MyListState<YogaVideo>>();

  @override
  void initState() {
    super.initState();
    _database.loadData().then((_) {
      setState(() {
        _isLoading = false;
      });
    });

    // Listen to share intents while app is open
    _textSub = init(context, _database, _onAddedNew);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkFirstTime(
        () => showWelcomeDialog(
          context,
          'Thank you for using the Yoga Video Manager App!\n\nA simple video manager for Yoga videos on Android.',
        ),
      );
    });
  }

  void _onAddedNew(YogaVideo video) {
    list.currentState?.insert(video);
    setState(() {});
  }

  void _onEdited(YogaVideo video) {
    list.currentState?.edit(video);
  }

  List<YogaVideo> get _filtered {
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

  void _deleteVideo(YogaVideo video, {DismissDirection? dismiss}) {
    if (_currentVideo?.id == video.id) {
      setState(() {
        _controller?.close();
        _controller = null;
        _currentVideo = null;
      });
    }

    list.currentState?.remove(video, dismiss: dismiss);
    setState(() {
      _database.videos.remove(video);
      _database.saveData();
    });
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
            list.currentState?.doFiltering(_filtered);
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
              headerTitle: 'YOUR YOGA VIDEOS:',
              headerWidgets: [
                MyBadge(
                  _filtered.length.toString(),
                  icon: Icon(
                    _selectedFilterTags.isEmpty
                        ? null
                        : Icons.filter_alt_outlined,
                    applyTextScaling: true,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimary
                        .withValues(alpha: 0.6),
                  ),
                  variant: .primary,
                ),
              ],
              extensionWidgets: [
                Padding(
                  padding: .symmetric(horizontal: 15),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Text(
                          'Filter Tags:',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (_selectedFilterTags.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFilterTags.clear();
                                list.currentState?.doFiltering(_filtered);
                              });
                            },
                            child: Text('Clear Filters'),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_database.tags.isNotEmpty)
                  MyList.of(
                    fixedHeight: 40,
                    orientation: .horizontal,
                    items: _database.tags.map((tag) {
                      final isSelected = _selectedFilterTags.contains(tag);
                      return Padding(
                        padding: EdgeInsetsGeometry.only(right: 8),
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
                              list.currentState?.doFiltering(_filtered);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),

          // Video List
          Expanded(
            child: _database.videos.isEmpty
                ? NoDataTile(
                    text: 'No videos added yet.',
                    icon: Icons.playlist_add,
                  )
                : MyList<YogaVideo>(
                    key: list,
                    initialItems: _database.videos,
                    itemBuilder: (video) => VideoCard(
                      video: video,
                      isPlaying: _currentVideo?.id == video.id,
                      onEdit: (_, {item}) => showVideoDialog(
                        context,
                        _database,
                        _onEdited,
                        video: video,
                      ),
                      onDelete: (_, {item}) => _deleteVideo(video),
                      onTap: () => _playVideo(video),
                    ),
                    onDismissedPrimary: DismissAction(
                      title: 'delete',
                      isDestructive: true,
                      icon: deleteIcon,
                      onDismissed: (item) =>
                          _deleteVideo(item, dismiss: .startToEnd),
                    ),
                    noDataTile: noDataFiltered,
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
                onPressed: _filtered.isEmpty
                    ? null
                    : () => selectRandomVideo(
                        context,
                        _filtered,
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
              () => showVideoDialog(context, _database, _onAddedNew),
            ),
          ],
        ),
      ),
      isLoading: _isLoading,
    );
  }
}
