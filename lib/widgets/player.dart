import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:podcast_player/image_handler.dart';

import 'package:podcast_player/main.dart';
import 'package:podcast_player/utils.dart';
import 'package:podcast_player/widgets/progress_slider_widget.dart';
import 'package:podcast_player/widgets/volume_slider.dart';

import '../analyzer.dart';

final ValueNotifier<Episode> currentlyPlaying = ValueNotifier(null);
final ValueNotifier<double> playerExpandProgress =
    ValueNotifier(playerMinHeight);

const double playerMinHeight = 70;
const double playerMaxHeight = 370;
const double miniplayerPercentage = 0.3;

class AudioControllerWidget extends StatefulWidget {
  final bool isMobile;

  const AudioControllerWidget({Key key, this.isMobile = true})
      : super(key: key);

  @override
  _AudioControllerWidgetState createState() => _AudioControllerWidgetState();
}

bool initialized = false;

Stream<int> positionUpdateStream =
    getProgressAsTimedStream(const Duration(seconds: 1)).asBroadcastStream();

Stream<int> getProgressAsTimedStream(final Duration duration) async* {
  await for (var _ in Stream.periodic(duration)) {
    final p = AudioService.playbackState;
    if (p != null && p.playing) yield p.currentPosition.inSeconds;
  }
}

class _AudioControllerWidgetState extends State<AudioControllerWidget> {
  bool isPlaying;
  Episode currentEpisode;
  FocusNode desktopSpaceNode = FocusNode();

  @override
  void initState() {
    desktopSpaceNode.requestFocus();
    currentlyPlaying.addListener(() {
      Episode wasCurrentEp;
      setState(() {
        wasCurrentEp = currentEpisode;
        currentEpisode = currentlyPlaying.value;
      });
      if (currentEpisode == null)
        saveCurrentEpisode(null);
      else
        saveCurrentEpisode(currentEpisode.audioUrl);
//TODO
      if (currentEpisode == null) return;
      if (wasCurrentEp == null) {
        startAudioService();
      } else {
        Future.delayed(Duration(seconds: 0)).then((_) async {
          AudioService.addQueueItem(MediaItem(
            id: currentEpisode.audioUrl,
            //params["audio_url"],
            album:
                '${Duration(seconds: currentEpisode.duration.inSeconds - episodeStates[currentEpisode.audioUrl].value).inMinutes}min left',
            title: currentEpisode.title,
            artist: podcasts[currentEpisode.podcastUrl].title,
            duration: currentEpisode.duration,
            artUri:
                '${Uri.file((await DefaultCacheManager().getSingleFile(podcasts[currentEpisode.podcastUrl].img)).path)}',
            extras: {
              "starting_point":
                  episodeStates[currentEpisode.audioUrl].value ?? 0,
              "download_path":
                  episodeDownloadInfo.containsKey(currentEpisode.audioUrl)
                      ? (await getApplicationSupportDirectory()).path +
                          Platform.pathSeparator +
                          episodeDownloadInfo[currentEpisode.audioUrl].filename
                      : null,
            },
          ));
          addToHistory(currentEpisode.audioUrl);
        });
      }
    });
    AudioService.playbackStateStream.listen((proState) {
      if (proState != null) {
        if (proState.processingState == AudioProcessingState.connecting)
          setState(() {
            isPlaying = null;
          });
        else {
          var p = proState.playing;
          if (p != isPlaying)
            setState(() {
              isPlaying = p;
            });
        }
      }
      if (proState == null ||
          proState.processingState == AudioProcessingState.stopped)
        currentlyPlaying.value = null;
    });

    getProgressAsTimedStream(Duration(seconds: 5)).listen((value) {
      if (currentEpisode != null)
        saveEpisodeState(currentEpisode.audioUrl, value);
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (currentEpisode == null) return Container(height: 0);

    final durationStream = AudioService.currentMediaItemStream.map((mediaItem) {
      if (mediaItem != null) return mediaItem.duration.inSeconds;
    });
    final img = OptimizedImage(url: podcasts[currentEpisode.podcastUrl].img);
    final text = Text(currentEpisode.title);
    final buttonPlay = isPlaying == null
        ? Container()
        : IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              isPlaying ? AudioService.pause() : AudioService.play();
              setState(() {
                isPlaying = !isPlaying;
              });
            },
          );
    final buttonSkipForward = IconButton(
      icon: Icon(Icons.forward_30),
      iconSize: 33,
      onPressed: () {
        AudioService.fastForward();
      },
    );
    final buttonSkipBackwards = IconButton(
      icon: Icon(Icons.replay_10),
      iconSize: 33,
      onPressed: () {
        AudioService.rewind();
      },
    );

    if (!widget.isMobile)
      return SizedBox(
        height: 90,
        child: RawKeyboardListener(
          onKey: (keyEvent) {
            //Space
            if (keyEvent.logicalKey.keyId != 32) return;

            desktopSpaceNode.unfocus();
            Future.delayed(Duration(milliseconds: 500))
                .then((value) => desktopSpaceNode.requestFocus());

            if (isPlaying)
              AudioService.pause();
            else if (!isPlaying) AudioService.play();
          },
          focusNode: desktopSpaceNode,
          child: Column(
            verticalDirection: VerticalDirection.up,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: img,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Container()),
                            Expanded(child: text),
                            Expanded(
                                child: StreamBuilder(
                              stream: positionUpdateStream,
                              builder: (_, progressSnapshot) {
                                if (!progressSnapshot.hasData)
                                  return Container();
                                return Row(
                                  children: [
                                    Text(progressString(progressSnapshot.data)),
                                    const Text(' / -'),
                                    StreamBuilder(
                                      stream: durationStream,
                                      builder: (_, durationSnapshot) =>
                                          !durationSnapshot.hasData
                                              ? Container()
                                              : Text(durationLeftString(
                                                  durationSnapshot.data,
                                                  progressSnapshot.data)),
                                    ),
                                  ],
                                );
                              },
                            )),
                          ],
                        ),
                      ],
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buttonSkipBackwards,
                          buttonPlay,
                          buttonSkipForward,
                        ],
                      ), //buttonPlay,
                    ),
                    Expanded(
                      child: VolumeSlider(),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 5,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackShape: CustomTrackShape(),
                  ),
                  child: Slider(
                    value: 0.2,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ],
          ),
        ),
      );

    return Miniplayer(
      minHeight: playerMinHeight,
      maxHeight: playerMaxHeight,
      valueNotifier: playerExpandProgress,
      onDismissed: () {
        currentlyPlaying.value = null;
        AudioService.stop();
      },
      builder: (height, percentage) {
        final bool miniplayer = percentage < miniplayerPercentage;
        final double width = MediaQuery.of(context).size.width;
        final maxImgSize = width * 0.4;

        final progressIndicator = AudioProgressSlider(
          progressStream: positionUpdateStream,
          durationStream: durationStream,
          miniplayer: miniplayer,
        );

        if (!miniplayer) {
          //Declare additional widgets (eg. SkipButton) and variables

          var percentageExpandedPlayer = percentageFromValueInRange(
              min: playerMaxHeight * miniplayerPercentage + playerMinHeight,
              max: playerMaxHeight,
              value: height);
          if (percentageExpandedPlayer < 0) percentageExpandedPlayer = 0;
          final paddingVertical = valueFromPercentageInRange(
              min: 0, max: 10, percentage: percentageExpandedPlayer);
          final double heightWithoutPadding = height - paddingVertical * 2;
          final double imageSize = heightWithoutPadding > maxImgSize
              ? maxImgSize
              : heightWithoutPadding;
          final paddingLeft = valueFromPercentageInRange(
                min: 0,
                max: width - imageSize,
                percentage: percentageExpandedPlayer,
              ) /
              2;

          final buttonPlayExpanded = isPlaying == null
              ? Container()
              : IconButton(
                  icon: Icon(isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled),
                  iconSize: 50,
                  onPressed: () {
                    isPlaying ? AudioService.pause() : AudioService.play();
                    setState(() {
                      isPlaying = !isPlaying;
                    });
                  },
                );

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              /*borderRadius:  BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                ),*/
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: paddingLeft,
                          top: paddingVertical,
                          bottom: paddingVertical),
                      child: SizedBox(
                        height: imageSize,
                        child: img,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 33),
                      child: Opacity(
                        opacity: percentageExpandedPlayer > 1
                            ? 1
                            : percentageExpandedPlayer < 0
                                ? 0
                                : percentageExpandedPlayer,
                        child: Column(
                          children: [
                            text,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                buttonSkipBackwards,
                                buttonPlayExpanded,
                                buttonSkipForward
                              ],
                            ),
                            progressIndicator,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        //Miniplayer
        final percentageMiniplayer = percentageFromValueInRange(
            min: playerMinHeight,
            max: playerMaxHeight * miniplayerPercentage + playerMinHeight,
            value: height);
        var elementOpacity = 1 - 1 * percentageMiniplayer;
        if (elementOpacity > 1) elementOpacity = 1;
        if (elementOpacity < 0) elementOpacity = 0;
        final prgressIndicatorHeight = 4 - 4 * percentageMiniplayer;

        return Material(
          child: Container(
            decoration: BoxDecoration(
              boxShadow: <BoxShadow>[
                BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0.0, 4))
              ],
              color: Theme.of(context).canvasColor,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxImgSize),
                        child: img,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Opacity(
                            opacity: elementOpacity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 22,
                                  child: Marquee(
                                    text: currentEpisode.title,
                                    blankSpace: 20,
                                    pauseAfterRound: Duration(seconds: 5),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyText2
                                        .copyWith(fontSize: 16),
                                  ),
                                ),
                                Text(
                                  podcasts[currentEpisode.podcastUrl].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyText2
                                              .color
                                              .withOpacity(0.55)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Opacity(
                          opacity: elementOpacity,
                          child: buttonPlay,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: prgressIndicatorHeight,
                  child: Opacity(
                    opacity: elementOpacity,
                    child: progressIndicator,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void startAudioService() async {
    print('aaa');
    //TODO: Necessary?
    //await AudioService.stop();
    //Future.delayed(Duration(milliseconds: 500));

    print('bbb');
    await AudioService.start(
      backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
      androidNotificationChannelName: 'Audio Service Demo',
      androidStopForegroundOnPause: true,
      androidNotificationColor: 0xFFFFFFFF,
      androidNotificationIcon: 'mipmap/ic_launcher',
      params: {
        "audio_url": currentEpisode.audioUrl,
        "title": currentEpisode.title,
        "duration": currentEpisode.duration.inSeconds,
        "artist": podcasts[currentEpisode.podcastUrl].title,
        //"album":'${Duration(seconds: currentEpisode.duration.inSeconds - episodeStates[currentEpisode.audioUrl].value).inMinutes}min left',
        "img":
            '${Uri.file((await DefaultCacheManager().getSingleFile(podcasts[currentEpisode.podcastUrl].img)).path)}',
        "starting_point": episodeStates[currentEpisode.audioUrl].value ?? 0,
        "auto_start": !firstEpisodeLoadedFromSP,
        "download_path":
            episodeDownloadInfo.containsKey(currentEpisode.audioUrl)
                ? (await getApplicationSupportDirectory()).path +
                    Platform.pathSeparator +
                    episodeDownloadInfo[currentEpisode.audioUrl].filename
                : null,
        'audio_behaviour': getSetting('audio_behaviour') ?? 0,
        //currentEpisode.autoStart
      },
      androidEnableQueue: true,
    );
    addToHistory(currentEpisode.audioUrl);
    firstEpisodeLoadedFromSP = false;
  }
}

// NOTE: Your entrypoint MUST be a top-level function.
void _audioPlayerTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

const MediaControl playControl = MediaControl(
  androidIcon: 'drawable/play',
  label: 'Play',
  action: MediaAction.play,
);
const MediaControl pauseControl = MediaControl(
  androidIcon: 'drawable/pause',
  label: 'Pause',
  action: MediaAction.pause,
);
const MediaControl skipBackwardsControl = MediaControl(
  androidIcon: 'drawable/backwards_10',
  label: 'SkipBackwards',
  action: MediaAction.rewind,
);
const MediaControl skipForwardControl = MediaControl(
  androidIcon: 'drawable/forward_30',
  label: 'SkipForward',
  action: MediaAction.fastForward,
);
const MediaControl stopControl = MediaControl(
  androidIcon: 'drawable/ic_action_stop',
  label: 'Stop',
  action: MediaAction.stop,
);

const controlsPaused = [
  skipBackwardsControl,
  playControl,
  skipForwardControl,
  stopControl
];
const controlsPlaying = [
  skipBackwardsControl,
  pauseControl,
  skipForwardControl,
  stopControl
];

class AudioPlayerTask extends BackgroundAudioTask {
  Map<String, int> settings = Map();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Episode currentEpisode;
  MediaItem _mediaItem;
  var cache;

  //StreamSubscription notificationRefreshStreamSubscription; //TODO
  //Stream notificationRefreshStream;
  bool _cancelUpdateRefresh = false;

  StreamSubscription<AudioPlaybackEvent> _eventSubscription;
  StreamSubscription<AudioPlaybackState> _playerStateSubscription;

  void refreshNotification() async {
    if (_cancelUpdateRefresh) return;

    await updateNotificationDuration();

    Future.delayed(Duration(minutes: 1)).then((value) => refreshNotification());
  }

  Future<void> updateNotificationDuration() async {
    int duration = (await _audioPlayer.durationFuture).inMinutes -
        _audioPlayer.playbackEvent.position.inMinutes;

    setMediaItem(album: duration < 0 ? 'Completed' : '${duration}min left');
  }

  @override
  Future<void> onStart(final Map<String, dynamic> params) async {
    /*notificationRefreshStream = functionAsRepeatedStream(() {
      print('working');
    }, Duration(seconds: 2), Random().nextInt(1000));
*/
    /*_playerStateSubscription = _audioPlayer.playbackStateStream
        .where((state) => state == AudioPlaybackState.completed)
        .listen((state) {
      _handlePlaybackCompleted();
    });*/
    _playerStateSubscription = _audioPlayer.playbackStateStream.listen((state) {
      print('asf: ' + state.toString());
      if (state == AudioPlaybackState.completed) _handlePlaybackCompleted();
    });

    _eventSubscription = _audioPlayer.playbackEventStream.listen((event) {
      final bufferingState =
          event.buffering ? AudioProcessingState.buffering : null;
      switch (event.state) {
        case AudioPlaybackState.paused:
          AudioServiceBackground.setState(
              controls: controlsPaused,
              processingState: bufferingState ?? AudioProcessingState.ready,
              playing: false,
              position: event.position);

          break;
        case AudioPlaybackState.playing:
          AudioServiceBackground.setState(
              controls: controlsPlaying,
              processingState: bufferingState ?? AudioProcessingState.ready,
              playing: true,
              position: event.position);

          break;
        case AudioPlaybackState.connecting:
          AudioServiceBackground.setState(
              controls: [],
              processingState: AudioProcessingState.connecting,
              playing: false,
              position: event.position);

          break;
        default:
          break;
      }
    });

    setMediaItem(
      id: params["audio_url"],
      album: "Buffering...",
      title: params["title"],
      artist: params["artist"],
      duration: Duration(seconds: params["duration"]),
      artUri: params["img"],
    );

    if (params['download_path'] == null)
      await _audioPlayer.setUrl(params["audio_url"]);
    else
      await _audioPlayer.setFilePath(params["download_path"]);

    skipToStartingPoint(params["starting_point"] ?? 0);

    setMediaItem(duration: await _audioPlayer.durationFuture);

    //notificationRefreshStreamSubscription =
    //    notificationRefreshStream.listen((_) {});
    _cancelUpdateRefresh = false;
    refreshNotification();

    if (params["auto_start"] == false) {
      AudioServiceBackground.setState(
          controls: controlsPaused,
          processingState: AudioProcessingState.ready,
          playing: false);
    } else
      await _audioPlayer.play();

    settings.putIfAbsent('audio_behaviour', () => params['audio_behaviour']);
  }

  @override
  Future<void> onPlay() async {
    print(_audioPlayer.position.isNegative);

    // Start playing audio.
    _audioPlayer.play();

    _cancelUpdateRefresh = false;
    refreshNotification();
    /* if (notificationRefreshStreamSubscription != null)
      notificationRefreshStreamSubscription.cancel();
    notificationRefreshStreamSubscription = null;
    notificationRefreshStreamSubscription =
        notificationRefreshStream.listen((_) {});*/
  }

  @override
  Future<void> onPause() async {
    // Pause the audio.
    _audioPlayer.pause();

    _cancelUpdateRefresh = true;
    /* //TODO: Make it work
    if (notificationRefreshStreamSubscription != null)
      notificationRefreshStreamSubscription.cancel();*/
  }

  @override
  Future<void> onStop() async {
    // Stop playing audio.
    _audioPlayer.stop();
    // Broadcast that we've stopped.
    await AudioServiceBackground.setState(
        controls: [],
        playing: false,
        processingState: AudioProcessingState.stopped);

    currentlyPlaying.value = null;
    _eventSubscription.cancel();
    _playerStateSubscription.cancel();

    _cancelUpdateRefresh = true;
    /*if (notificationRefreshStreamSubscription != null)
      notificationRefreshStreamSubscription.cancel();*/
    // Shut down this background task
    await super.onStop();
  }

  @override
  Future<void> onSeekTo(Duration position) async {
    await _audioPlayer.seek(position);

    await updateNotificationDuration();

    super.onSeekTo(position);
  }

  @override
  Future<void> onFastForward() async {
    await _seekRelative(Duration(seconds: 30));
  }

  @override
  Future<void> onRewind() async {
    await _seekRelative(Duration(seconds: -10));
  }

  Future<void> _seekRelative(Duration offset) async {
    var newPosition = _audioPlayer.playbackEvent.position + offset;
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > _mediaItem.duration) newPosition = _mediaItem.duration;
    await _audioPlayer.seek(_audioPlayer.playbackEvent.position + offset);

    await updateNotificationDuration();
  }

  @override
  Future<void> onAddQueueItem(MediaItem mediaItem) async {
    final int startingPoint = mediaItem.extras["starting_point"] ?? 0;
    final String filePath = mediaItem.extras["download_path"];

    await _audioPlayer.stop();

    if (filePath == null)
      await _audioPlayer.setUrl(mediaItem.id);
    else
      await _audioPlayer.setFilePath(filePath);

    _mediaItem = mediaItem;
    setMediaItem(duration: await _audioPlayer.durationFuture);

    skipToStartingPoint(startingPoint);

    await _audioPlayer.play();
  }

  @override
  Future onCustomAction(String name, arguments) async {
    switch (name) {
      case 'volume':
        if (arguments is double) _audioPlayer.setVolume(arguments);

        break;
    }
  }

  void playPause() {
    if (AudioServiceBackground.state.playing)
      onPause();
    else
      onPlay();
  }

  @override
  Future<void> onClick(MediaButton button) async {
    playPause();
  }

  /*// Handle a phone call or other interruption -> read settings
  @override
  Future<void> onAudioFocusLost(AudioInterruption interruption) async {
    var opt = settings['audio_behaviour'];
    print('AUDIO FOCUS LIS $opt');
    switch (opt) {
      case 1:
        _audioPlayer.setVolume(0.5);
        return;
      case 2:
        if (AudioServiceBackground.state.playing) onPause();
        return;
    }
  }

  // Normalize volume when focus gained again + settings option 1.
  @override
  Future<void> onAudioFocusGained(AudioInterruption interruption) async {
    if (getSetting('audio_behaviour') ?? 0 == 1) _audioPlayer.setVolume(1);
  }*/

  Stream functionAsRepeatedStream(
      Function function, Duration duration, int n) async* {
    /*while (true) {
      yield function();
      await Future.delayed(duration);
    }*/
    await for (var _ in Stream.periodic(duration)) {
      print('rand num: ' + n.toString());
      function();
    }
  }

  void setMediaItem(
      {final String id,
      final String album,
      final String title,
      final String artist,
      final String artUri,
      final Duration duration}) {
    _mediaItem = MediaItem(
      id: id ?? _mediaItem.id,
      album: album ?? _mediaItem.album,
      title: title ?? _mediaItem.title,
      artist: artist ?? _mediaItem.artist,
      duration: duration ?? _mediaItem.duration ?? Duration(hours: 1),
      artUri: artUri ?? _mediaItem.artUri,
    );

    //AudioServiceBackground.me
    AudioServiceBackground.setMediaItem(_mediaItem);
  }

  void _handlePlaybackCompleted() {
    print('complete');
    _cancelUpdateRefresh = true; //TODO: recall
    setMediaItem(album: 'Completed');

    // Stop playing audio.
    _audioPlayer.stop();
    // Broadcast that we've stopped.
    AudioServiceBackground.setState(
        controls: controlsPaused,
        playing: false,
        processingState: AudioProcessingState.ready);
  }

  //Must be called after setUrl
  void skipToStartingPoint(final int startingPoint) async {
    int duration = (await _audioPlayer.durationFuture).inSeconds;
    if (startingPoint < duration && startingPoint > 0)
      _audioPlayer.seek(Duration(seconds: startingPoint));
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  Rect getPreferredRect({
    @required RenderBox parentBox,
    Offset offset = Offset.zero,
    @required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = 3;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
