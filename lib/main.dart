import 'dart:ui' as prefix0;

import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter/widgets.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: NotesScreen.name,
      onGenerateRoute: (settings) {
        if (settings.name == NotesScreen.name) {
            return MaterialPageRoute(
              builder: (context) => NotesScreen()
            );
        } else if (settings.name == PresentationPage.routeName) {
            String notes = settings.arguments;
            var notEmptyLines = notes
                .split("\n")
                .where((line) => line.replaceAll(' ', '').isNotEmpty);
            var presentation = notEmptyLines
                .map((point) => Point(point, 10))
                .toList();
            return MaterialPageRoute(
              builder: (context) => PresentationPage(presentation)
            );
        }
        return null;
      },
    );
  }
}

class Point {
  String text = '';
  int seconds = 10;

  Point(this.text, this.seconds);

  factory Point.empty() => Point('', 10);
}

class NotesScreen extends StatefulWidget {
  static const name = 'notes';
  NotesScreenState createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  String notes;

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes')
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            TextField(
              onChanged: (value) => setState(() => notes = value),
              maxLines: null,
            ),
            MaterialButton(
              onPressed: () {
                Navigator.pushNamed(
                    context,
                    PresentationPage.routeName,
                    arguments: notes
                );
              },
              color: Colors.blue,
              child: Text('Present'),
            )
          ],
        )
      )
    );
  }
}

enum PresentationState { ready, presenting, stopped }

class PresentationPage extends StatefulWidget {
  static const routeName = 'presentation';
  final List<Point> _keyPoints;

  PresentationPage(this._keyPoints);
  PresentationPageState createState() => PresentationPageState();
}

class PresentationPageState extends State<PresentationPage> with TickerProviderStateMixin {
  List<Point> _keyPoints;
  PresentationState _state = PresentationState.ready;

  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _keyPoints = widget._keyPoints;
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void resetAnimationController() {
    var seconds = durationOfFirst(_keyPoints.length);
    _controller?.dispose();
    _controller = AnimationController(
        duration: Duration(seconds: seconds),
        upperBound: seconds.toDouble(),
        vsync: this
    );
  }

  void startPresentation() {
    setState(() {
      _controller.addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed)
          setState(() {
            _state = PresentationState.stopped;
          });
      });
      _controller.forward();
      _state = PresentationState.presenting;
    });
  }

  int durationOfFirst(int index) =>
      _keyPoints.take(index).fold(0, (acc, keyPoint) => acc + keyPoint.seconds);

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Presentation'),
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    return Column(
        children: <Widget>[
          headerBuild(),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: keyPoints().toList(),
            ),
          ),
        ]
    );
  }

  Widget headerBuild() {
    return Row(
      children: <Widget>[
        Spacer(),
        AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget child) {
              var duration = Duration(seconds: durationOfFirst(_keyPoints.length));
              var elapsed = Duration(seconds: _controller.value.floor());
              var remaining = duration - elapsed;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${remaining.inMinutes % 60}m ${remaining.inSeconds % 60}s',
                  style: TextStyle(
                      fontSize: 40
                  ),
                ),
              );
            }
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.refresh),
                iconSize: 30,
                color: Colors.grey,
                onPressed: () =>
                    setState(() {
                      _controller.reset();
                      _state = PresentationState.ready;
                    }),
              ),
              if (
              _state == PresentationState.ready
                  || _state == PresentationState.stopped)
                IconButton(
                    color: Colors.green,
                    iconSize: 50,
                    icon: Icon(Icons.play_circle_outline),
                    onPressed: startPresentation
                ),
              if (_state == PresentationState.presenting)
                IconButton(
                  color: Colors.red,
                  iconSize: 50,
                  icon: Icon(Icons.pause_circle_outline),
                  onPressed: () => setState(() {
                    _state = PresentationState.stopped;
                    _controller.stop();
                  }),
                ),
            ],
          )
        ),
      ],
    );
  }

  Widget keyPointBuild(int index, Point keyPoint) {
    const unitHeight = 60;

    var actionMenu =
        Row(
          children: <Widget>[
            OutlineButton(
                color: Colors.grey,
                onPressed: () {
                  setState(() {
                    var point = _keyPoints[index];
                    if (point.seconds > 10) {
                      point.seconds = point.seconds - 10;
                      resetAnimationController();
                    }
                  });
                },
                child: Text('-10s')
            ),
            Padding(padding: EdgeInsets.all(8)),
            OutlineButton(
                color: Colors.grey,
                onPressed: () {
                  setState(() {
                    _keyPoints[index].seconds = _keyPoints[index].seconds + 10;
                    resetAnimationController();
                  });
                },
                child: Text('+10s')
            ),
          ],
        );

    return AnimatedBuilder(
        animation: _controller,
        child: Container(
          height: unitHeight * (keyPoint.seconds / 10),
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Text(keyPoint.text)),
              if (_state == PresentationState.ready)
                actionMenu,
            ],
          ),
        ),
        builder: (BuildContext context, Widget child) {
          var keyPointRunningFor =
              _controller.value - durationOfFirst(index).toDouble();
          var elapsedForKeyPoint =
              max(0, min(keyPoint.seconds.toDouble(), keyPointRunningFor));
          return Stack(children: <Widget>[
            Container(
              alignment: Alignment.topCenter,
              height: unitHeight.toDouble() * (elapsedForKeyPoint / 10),
              color: Colors.blue,
            ),
            child,
          ]);
        });
  }

  Iterable<Widget> keyPoints() sync* {
    for (var index in Iterable.generate(_keyPoints.length)) {
      var keyPoint = _keyPoints[index];
      yield Card(
        key: Key(index.toString()),
        margin: EdgeInsets.all(5),
        clipBehavior: Clip.hardEdge,
        child: keyPointBuild(index, keyPoint),
      );
    }
  }

}
