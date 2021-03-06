import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:podcast_player/image_handler.dart';
import 'package:podcast_player/utils.dart';
import 'package:podcast_player/widgets/episode_list_tile.dart';
import 'package:podcast_player/widgets/web_layout.dart';

import '../analyzer.dart';
import '../main.dart';

enum PopupMenu { rss }

class PodcastOverviewScreen extends StatefulWidget {
  const PodcastOverviewScreen({Key key, @required this.feedUrl})
      : super(key: key);

  final String feedUrl;

  @override
  _PodcastOverviewScreenState createState() => _PodcastOverviewScreenState();
}

class _PodcastOverviewScreenState extends State<PodcastOverviewScreen> {
  Podcast podcast;
  StreamSubscription<String> listener;
  String search;

  @override
  void initState() {
    podcast = podcasts[widget.feedUrl];
    listener = updateStream.stream.listen((_podcastUrl) {
      if (_podcastUrl == widget.feedUrl) {
        setState(() {
          podcast = podcasts[_podcastUrl];
        });
      } else if (_podcastUrl.startsWith('remove:')) {
        _podcastUrl = _podcastUrl.split('remove:')[1];
        if (_podcastUrl == widget.feedUrl) Navigator.of(context).pop();
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    listener.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Set<Episode> filteredEpisodes = Set();
    if (search != null)
      for (String eUrl in podcast.episodes) {
        final Episode episode = episodes[eUrl];

        if (episode.title.contains(search))
          filteredEpisodes.add(episode);
        else if (episode.description.contains(search))
          filteredEpisodes.add(episode);
      }

    final body = ListView(
      children: [
        PodcastHeaderWidget(
          title: podcast.title,
          author: podcast.author,
          description: podcast.description,
          image: podcast.img,
          url: podcast.url,
          link: podcast.link,
        ),
        Tooltip(
          message:
              'Unsubscribe from ${podcast.title.contains(' ') ? podcast.title.split(' ')[0] : podcast.title}',
          child: ElevatedButton(
            child: Text('Unsubscribe'),
            onPressed: //() => unsubscribePodcast(podcast.url),
                () {
              showDialog<void>(
                context: context,
                barrierDismissible: true, // user must tap button!
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Confirm Action'),
                    content: Text(
                        'Do you want to unsubscribe from ${podcast.title}?'),
                    actions: <Widget>[
                      FlatButton(
                        child: Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      FlatButton(
                        child: Text('Unsubscribe'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          unsubscribePodcast(podcast.url);
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    contentPadding: EdgeInsets.symmetric(horizontal: 15.0),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[100]
                        : Colors.white.withOpacity(0.045),
                  ),
                  onChanged: (keyword) => setState(() {
                    if (keyword.length == 0)
                      search = null;
                    else
                      search = keyword;
                  }),
                ),
              ),
              IconButton(icon: Icon(Icons.filter_list), onPressed: () {}),
            ],
          ),
        ),
        if (search == null)
          for (String episodeUrl in podcast.episodes)
            EpisodeListTile(episode: episodes[episodeUrl]),
        if (search != null)
          for (Episode episode in filteredEpisodes)
            EpisodeListTile(episode: episode),
      ],
    );
    final appBarTitle = Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            height: 38,
            child: OptimizedImage(url: podcast.img), //fit: BoxFit.contain,
          ),
        ),
        Expanded(
          child: Text(podcast.title),
        )
      ],
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: !kIsWeb ? appBarTitle : WebLayout(child: appBarTitle),
        actions: <Widget>[
          PopupMenuButton<PopupMenu>(
            onSelected: (PopupMenu result) {
              switch (result) {
                case PopupMenu.rss:
                  openLinkInBrowser(context, podcast.url);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<PopupMenu>>[
              const PopupMenuItem<PopupMenu>(
                value: PopupMenu.rss,
                child: Text('View RSS'),
              ),
            ],
          )
        ],
      ),
      body: !kIsWeb ? body : WebLayout(child: body),
    );
  }
}

const double padding = 17;

class PodcastHeaderWidget extends StatelessWidget {
  final String title, author, description, image, url, link;

  const PodcastHeaderWidget(
      {Key key,
      @required this.title,
      @required this.url,
      @required this.author,
      @required this.description,
      @required this.image,
      this.link})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    String displayUrl;
    if (link != null && link.contains('.')) {
      final split = link.split('.');
      String a = split[split.length - 2], b = split[split.length - 1];
      if (a.contains('/')) {
        var sA = a.split('/');
        a = sA[sA.length - 1];
      }
      if (b.contains('/')) b = b.split('/')[0];
      displayUrl = '$a.$b';
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  //color: Colors.red,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headline6,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          author,
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyText1
                                .color
                                .withOpacity(0.7),
                          ),
                        ),
                      ),
                      if (link != null && displayUrl != null)
                        Tooltip(
                          message: 'Open $displayUrl',
                          child: InkWell(
                            onTap: () => openLinkInBrowser(context, link),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayUrl,
                                  style: GoogleFonts.lexendDeca(
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.blue
                                        : Colors.white,
                                    fontSize: 13.4,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.open_in_new,
                                  size: 14,
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.blue
                                      : Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: SizedBox(
                  height: 110,
                  child: OptimizedImage(url: image),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
        Align(
          alignment: Alignment.centerLeft,
          child: ExpandableText(
            textSpan: TextSpan(
                text: description,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white.withOpacity(0.88),
                )),
            maxLines: 4,
            moreSpan: TextSpan(
                text: 'more',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.blue
                      : Colors.white,fontWeight: FontWeight.bold,
                )),
          ),
        ),
      ],
    );
  }
}

class ExpandableText extends StatefulWidget {
  final TextSpan textSpan;
  final TextSpan moreSpan;
  final int maxLines;

  const ExpandableText({
    Key key,
    this.textSpan,
    this.maxLines,
    this.moreSpan,
  })  : assert(textSpan != null),
        assert(maxLines != null),
        assert(moreSpan != null),
        super(key: key);

  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

extension _TextMeasurer on RichText {
  List<TextBox> measure(BuildContext context, Constraints constraints) {
    final renderObject = createRenderObject(context)..layout(constraints);
    return renderObject.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: text.toPlainText().length,
      ),
    );
  }
}

class _ExpandableTextState extends State<ExpandableText> {
  static const String _ellipsis = "\u2026\u0020";

  String get _lineEnding => "$_ellipsis${widget.moreSpan.text}";
  bool _isExpanded = false;

  GestureRecognizer get _tapRecognizer => TapGestureRecognizer()
    ..onTap = () {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final maxLines = widget.maxLines;

          final richText =
              Text.rich(widget.textSpan).build(context) as RichText;
          final boxes = richText.measure(context, constraints);

          if (boxes.length <= maxLines || _isExpanded) {
            return Tooltip(
              message: 'Collapse description',
              child: InkWell(
                  onTap: () => setState(() {
                        _isExpanded = false;
                      }),
                  child: Padding(
                    padding: const EdgeInsets.all(padding),
                    child: RichText(text: widget.textSpan),
                  )),
            );
          } else {
            final croppedText = _ellipsizeText(boxes);
            final ellipsizedText =
                _buildEllipsizedText(croppedText, _tapRecognizer);

            if (ellipsizedText.measure(context, constraints).length <=
                maxLines) {
              return ellipsizedText;
            } else {
              final fixedEllipsizedText = croppedText.substring(
                  0, croppedText.length - _lineEnding.length);
              return Tooltip(
                message: 'Expand description',
                child: InkWell(
                    onTap: () => setState(() {
                          _isExpanded = true;
                        }),
                    child: Padding(
                      padding: const EdgeInsets.all(padding),
                      child: _buildEllipsizedText(
                          fixedEllipsizedText, _tapRecognizer),
                    )),
              );
            }
          }
        },
      );

  String _ellipsizeText(List<TextBox> boxes) {
    final text = widget.textSpan.text;
    final maxLines = widget.maxLines;

    double _calculateLinesLength(List<TextBox> boxes) => boxes
        .map((box) => box.right - box.left)
        .reduce((acc, value) => acc += value);

    final requiredLength = _calculateLinesLength(boxes.sublist(0, maxLines));
    final totalLength = _calculateLinesLength(boxes);

    final requiredTextFraction = requiredLength / totalLength;
    return text.substring(0, (text.length * requiredTextFraction).floor());
  }

  RichText _buildEllipsizedText(String text, GestureRecognizer tapRecognizer) =>
      RichText(
        text: TextSpan(
          text: "$text$_ellipsis",
          style: widget.textSpan.style,
          children: [widget.moreSpan],
        ),
      );
}
