library tekartik_midi_player_base;

import 'dart:async';
import 'dart:math';
import 'package:tekartik_midi/midi.dart';
import 'package:tekartik_midi/midi_file_player.dart';

abstract class MidiPlayerBase {
  int _fileIndex;

  bool fileMatches(int fileIndex) {
    return _fileIndex == fileIndex;
  }

  MidiFilePlayer _midiFilePlayer;
  //Stopwatch stopwatch;

  // True when play has started once already
  bool _isPaused = false;
  bool get isPaused => _isPaused;

  // True when play has started once already (true when paused)
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying && !_isPaused;

  // True when done
  bool _isDone = false;
  bool get isDone => _isDone;

  // null when not load yet
  Future _done;
  Future get done => _done;

  // Created when playing
  // killed on pause
  Completer _waitPlayNextCompleter;

  StreamController<PlayableEvent> _streamController;

  /// Send event when status change and every second
  StreamController<bool> playingController = StreamController();
  Stream<bool> playingStream;

  /// time to send the event before the real event occured
  int _preFillDuration = 200;
  int _timerResolution = 50;

  PlayableEvent _currentEvent;

  // timestamp is relative to _startNow;
  //num _startNow;

  num _nextRatio;

  num _lastPauseTime;
  num _nowDelta = 0; // delta from now, pausing increases delta

  num get currentTimestamp =>
      isPlaying ? (isPaused ? _lastPauseTime : _nowTimestamp) : null;

  Duration get currentTimestampDuration {
    num _now = currentTimestamp;
    if (_now != null) {
      return Duration(milliseconds: _now.toInt());
    }
    return null;
  }

  // estimation
  num nowToTimestamp([num now]) {
    if (now == null) {
      now = this.now;
    }
    return now;
    //return now - startNow - _nowDelta; // - _preFillDuration - _preFillDuration;
  }

  /// Send sound off to all channel
  void allSoundOff() {
    for (int i = 0; i < MidiEvent.channelCount; i++) {
      PlayableEvent playableEvent = PlayableEvent(
          nowToTimestamp(), ControlChangeEvent.newAllSoundOffEvent(i));
      playEvent(playableEvent);
    }
  }

  void allNotesOff() {
    for (int i = 0; i < MidiEvent.channelCount; i++) {
      PlayableEvent playableEvent = PlayableEvent(
          nowToTimestamp(), ControlChangeEvent.newAllSoundOffEvent(i));
      playEvent(playableEvent);
    }
  }

  void allReset() {
    for (int i = 0; i < MidiEvent.channelCount; i++) {
      PlayableEvent playableEvent = PlayableEvent(
          nowToTimestamp(), ControlChangeEvent.newAllResetEvent(i));
      playEvent(playableEvent);
    }
  }

  void panic() {
    //allSoundOff();
    //allReset();

    for (int j = 0; j < MidiEvent.noteCount; j++) {
      for (int i = 0; i < MidiEvent.channelCount; i++) {
        PlayableEvent playableEvent =
            PlayableEvent(nowToTimestamp(), NoteOffEvent(i, j, 0));
        playEvent(playableEvent);
      }
    }
  }

  // to override for MidiJs
  //void _prepareToPlay(MidiFile file) {}

  void _unload() {
    // unload the current file
    if (_streamController != null) {
      _streamController.close();
    }
  }

  void rawPause() {
    if (!isPaused) {
      _lastPauseTime = now;
      //stopwatch.stop();
      _isPaused = true;
      playingController.add(false);
    }

    //    if (_streamController != null) {
    //      _currentEvent = null;
    //      _streamController.close();
    //      _streamController = null;
    //      playingController.add(false);
    //    }
  }

  void resume([num time]) {
    num _now = time == null ? now : time;
    if (isPaused) {
      _nowDelta += _now - _lastPauseTime;
    }
    // TODO
    _midiFilePlayer.resume(_now);
    _isPlaying = true;
    _isPaused = false;
    //stopwatch.start();
    playingController.add(true);
    _currentEvent = _midiFilePlayer.next;
    _playNext();
  }

//  void _play(MidiFile file) {
//    _load(file);
//    //stopwatch = new Stopwatch()..start();
//    _midiFilePlayer.start(0 - _preFillDuration);
//
//    if (_nextRatio != null) {
//      _midiFilePlayer.setSpeedRatio(_nextRatio, now);
//      _nextRatio = null;
//    }
//
//    _startNow = now - _nowDelta;
//    devPrint('Starting ${formatTimestampMs(_startNow)}');
//    // Get first
//    _currentEvent = _midiFilePlayer.next;
//    _playNext();
//  }

  void load(MidiFile file) {
    // Pause current
    pause();

    // unload existing
    _unload();

    //_prepareToPlay(file);
    //_nowDelta = 0;
    //isPaused = true;
    //_isPlaying = true;
    //playingController.add(true);
//          Stream<PlayableEvent> stream = _play(file);
//          stream..listen((PlayableEvent event) {
//                playEvent(event);
//              }, onDone: () {
//                pause();
//                print('onDone');
//                player = null;
//              });
    _load(file);

    //});
  }

//  void play(MidiFile file) {
//    load(file).then((_) {
//      _play(file);
//
//    });
//
//  }

//  num get startNow {
//    if (_startNow == null) {
//      _startNow = now;
//    }
//    return _startNow;
//  }

  void _load(MidiFile file) {
    _isDone = false;
    _isPlaying = false;
    _isPaused = false;
    _midiFilePlayer = MidiFilePlayer(file);
    //_startNow = null;

    _streamController = StreamController<PlayableEvent>(sync: true);

    _done = _streamController.stream
        .listen((PlayableEvent event) {
          playEvent(event);
        }, onDone: () {
          //pause();
        })
        .asFuture()
        .then((_) {
          //devPrint('onDone');
          //_midiFilePlayer = null;
          _isDone = true;
          _isPlaying = false;
        });
  }

//  void _play(MidiFile file) {
//    _load(file);
//    //stopwatch = new Stopwatch()..start();
//    player.start(0 - _preFillDuration);
//
//    _startNow = now - _nowDelta;
//    devPrint('Starting ${formatTimestampMs(_startNow)}');
//    // Get first
//    _currentEvent = player.next;
//    _playNext();
//  }

  num get currentSpeedRadio => _nextRatio; // ?

  void setNextSpeedRadio(num ratio) {
    _nextRatio = ratio;
  }

  void setSpeedRadio(num ratio) {
    if (_midiFilePlayer == null) {
      _nextRatio = ratio;
    } else {
      _midiFilePlayer.setSpeedRatio(ratio, now);
      //?
      _nextRatio = ratio;
    }
  }

  num get _nowTimestamp => nowToTimestamp();

  void _playNext() {
    if (_currentEvent == null || isPaused) {
      // Are we done
      if (!isPaused) {
        //TODO? Wait for all events to be played closing stream
        //int fileIndex = this._fileIndex;
        //new Future.
        _streamController.close();
      } else {
        pause();
      }
    } else {
      num nowTimestamp = _nowTimestamp; //stopwatch.elapsedMilliseconds;

      if (_currentEvent.timestamp < nowTimestamp) {
        //devPrint("## $now: $_currentEvent");
        _streamController.add(_currentEvent);
        _currentEvent = _midiFilePlayer.next;
        _playNext();
      } else {
        Completer nextCompleter = Completer.sync();
        _waitPlayNextCompleter = nextCompleter;
        Future.delayed(
            Duration(
                milliseconds:
                    (_currentEvent.timestamp - nowTimestamp + _timerResolution)
                        .toInt()), () {
          if (!nextCompleter.isCompleted) {
            nextCompleter.complete();
          }
          _waitPlayNextCompleter = null;
        });

        // This will be cancelled if _waitPlayNextCompleter has been complete with an error before
        nextCompleter.future.then((_) {
          _playNext();
        }, onError: (_) {
          //devPrint("was paused");
        });
      }
    }
  }

  num eventTimestampToOutputTimestamp(PlayableEvent event) {
    //return event.timestamp + _startNow + _nowDelta + _preFillDuration + _preFillDuration;
    return event.timestamp + _nowDelta + _preFillDuration + _preFillDuration;
  }

//  MidiFile _currentFile;
//  MidiFile get currentFile => _currentFile;
//  set currentFile(MidiFile currentFile_) {
//    _currentFile = currentFile_;
//    // to force duration recomputation
//    _currentFileDuration = null;
//    _currentFileDuration = null;
//  }
//  Duration _currentFileDuration;
//  Duration get currentFileDuration {
//    if (_currentFileDuration == null) {
//      if (currentFile != null) {
//        _currentFileDuration = getMidiFileDuration(currentFile);
//      }
//    }
//    return _currentFileDuration;
//  }

  /*

  num _currentFilePercent;

  // from 0 to 100
  num get currentFilePercent {

  }
  */

  // In milliseconds
  num get now;

  MidiPlayerBase(this.noteOnLastTimestamp);

  Set<NoteOnKey> noteOnKeys = Set();
  num noteOnLastTimestamp;

  // to implement
  void rawPlayEvent(PlayableEvent midiEvent) {}

  // must be overriden and called
  void playEvent(PlayableEvent event) {
    // first play it
    rawPlayEvent(event);

    MidiEvent midiEvent = event.midiEvent;

    // And Note on event and remove note off event (and note on with velocity 0)
    if (midiEvent is NoteOnEvent) {
      NoteOnKey key = NoteOnKey(midiEvent.channel, midiEvent.note);

      // save last timestamp to queue note off afterwards on pause
      if (noteOnLastTimestamp == null ||
          event.timestamp > noteOnLastTimestamp) {
        noteOnLastTimestamp = event.timestamp;
      }

      if (midiEvent.velocity > 0) {
        noteOnKeys.add(key);
      } else {
        noteOnKeys.remove(key);
      }
    } else if (midiEvent is NoteOffEvent) {
      NoteOnKey key = NoteOnKey(midiEvent.channel, midiEvent.note);
      noteOnKeys.remove(key);
    }
  }

  void pause() {
    if (isPlaying) {
      num nowTimestamp = nowToTimestamp();

      _midiFilePlayer.pause(nowTimestamp);

      // Kill pending _playNext)
      if (_waitPlayNextCompleter != null) {
        _waitPlayNextCompleter.completeError("paused");
        _waitPlayNextCompleter = null;
      }
      num timestamp = noteOnLastTimestamp;
      if (timestamp == null) {
        timestamp = nowTimestamp;
      } else {
        timestamp = max(nowToTimestamp(), timestamp);
      }
      //devPrint('###### $timestamp - ${nowToTimestamp()}/last: $noteOnLastTimestamp');
      // Clear the notes sent
      for (NoteOnKey key in noteOnKeys) {
        PlayableEvent event =
            PlayableEvent(timestamp, NoteOffEvent(key.channel, key.note, 0));
        //devPrint(event);
        rawPlayEvent(event);
      }
      noteOnKeys.clear();

      // then pause
      rawPause();
    }
  }

  num get totalDurationMs {
    return _midiFilePlayer.totalDurationMs;
  }

  num get currentAbsoluteMs {
    if (!_isPlaying) {
      return 0;
    }
    return _midiFilePlayer.timestampToAbsoluteMs(nowToTimestamp());
  }
}
