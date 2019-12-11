import 'dart:ui' as prefix0;

import 'package:flutter/material.dart';
import 'dart:math';

void main() => runApp(App());

class App extends StatefulWidget {
  @override
  AppState createState() => AppState();
}

class KeyPoint {
  String text = '';
  int seconds = 10;

  KeyPoint(this.text, this.seconds);

  factory KeyPoint.empty() => KeyPoint('', 10);
}

enum KeyPointsState { adding, ready, presenting, stopped }

class AppState extends State<App> with TickerProviderStateMixin {
  List<KeyPoint> _keyPoints = [];
  KeyPoint _newKeyPoint;
  KeyPointsState _state = KeyPointsState.ready;

  AnimationController _controller;

  static const unitHeight = 60;

  @override
  void initState() {
    super.initState();
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
            _state = KeyPointsState.stopped;
          });
      });
      _controller.forward();
      _state = KeyPointsState.presenting;
    });
  }

  int durationOfFirst(int index) =>
      _keyPoints.take(index).fold(0, (acc, keyPoint) => acc + keyPoint.seconds);

  Widget keyPointBuild(int index, KeyPoint keyPoint) {
    var actionMenu =
        Row(
          children: <Widget>[
            MaterialButton(
                color: Colors.grey,
                onPressed: () {
                  if (_state != KeyPointsState.adding) {
                    setState(() {
                      var point = _keyPoints[index];
                      if (point.seconds > 10) {
                        point.seconds = point.seconds - 10;
                        resetAnimationController();
                      }
                    });
                  }
                },
                child: Text('-10s')
            ),
            Padding(padding: EdgeInsets.all(8)),
            MaterialButton(
                color: Colors.grey,
                onPressed: () {
                  if (_state != KeyPointsState.adding) {
                    setState(() {
                      _keyPoints[index].seconds = _keyPoints[index].seconds + 10;
                      resetAnimationController();
                    });
                  }
                },
                child: Text('+10s')
            ),
            Padding(padding: EdgeInsets.all(8)),
            IconButton(
                onPressed: () {
                  setState(() {
                    _keyPoints.removeAt(index);
                  });
                },
                icon: Icon(Icons.delete)
            )
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
              if (_state == KeyPointsState.ready)
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
      yield GestureDetector(
        key: Key(index.toString()),
        onTap: () => setState(() {
          if (_state != KeyPointsState.adding) {
            _keyPoints[index].seconds = _keyPoints[index].seconds + 10;
            resetAnimationController();
          }
        }),
        child: Card(
          margin: EdgeInsets.all(5),
          clipBehavior: Clip.hardEdge,
          child: keyPointBuild(index, keyPoint),
        ),
      );
    }
  }

  void saveNewKeyPoint() {
    setState(() {
      _keyPoints.add(_newKeyPoint);
      _newKeyPoint = null;
      _state = KeyPointsState.ready;
      resetAnimationController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keypoint Timer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
          appBar: AppBar(
              title: Text(
                'Key Points Timer',
                style: TextStyle(),
              )
          ),
          floatingActionButton: _state != KeyPointsState.ready
              ? null
              : FloatingActionButton(
                  backgroundColor: Colors.blue,
                  onPressed: () {
                    setState(() {
                      _newKeyPoint = KeyPoint.empty();
                      _state = KeyPointsState.adding;
                    });
                  },
                  child: Icon(Icons.add),
                ),
          body: Column(children: <Widget>[
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
                child: ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        _keyPoints.insert(newIndex, _keyPoints[oldIndex]);
                        _keyPoints.removeAt(oldIndex);
                      });
                    },
                    children: keyPoints().toList()),
              ),
              if (_state == KeyPointsState.adding)
                TextFormField(
                  key: Key(_keyPoints.length.toString()),
                  initialValue: _newKeyPoint.text,
                  onChanged: (newValue) =>
                      setState(() => _newKeyPoint.text = newValue),
                  onEditingComplete: saveNewKeyPoint,
                  autofocus: true,
                ),
              if (_state == KeyPointsState.ready)
                MaterialButton(
                  color: Colors.green,
                  child: Text('Start'),
                  onPressed: startPresentation
                ),
              if (_state == KeyPointsState.presenting)
                MaterialButton(
                  color: Colors.red,
                  child: Text('Stop'),
                  onPressed: () => setState(() {
                    _state = KeyPointsState.stopped;
                    _controller.stop();
                  }),
                ),
              if (_state == KeyPointsState.stopped)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    MaterialButton(
                        color: Colors.green,
                        child: Text('Start'),
                        onPressed: startPresentation
                    ),
                    Padding(padding: EdgeInsets.all(10)),
                    MaterialButton(
                        color: Colors.red,
                        child: Text('Reset'),
                        onPressed: () =>
                            setState(() {
                              _controller.reset();
                              _state = KeyPointsState.ready;
                            })
                    )
                  ]
                ),
            ]),
          ),
    );
  }
}
