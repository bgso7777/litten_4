import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';
import 'local_storage_service.dart';

enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
}

enum PlaybackState {
  idle,
  playing,
  paused,
  stopped,
}

class AudioService extends ChangeNotifier {
  AudioService();

  final Record _recorder = Record();
  final AudioPlayer _player = AudioPlayer();
  final LocalStorageService _storageService = LocalStorageService();
  final Uuid _uuid = const Uuid();

  // 녹음 상태
  RecordingState _recordingState = RecordingState.idle;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _currentRecordingPath;

  // 재생 상태
  PlaybackState _playbackState = PlaybackState.idle;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  String? _currentPlayingFileId;

  // Getters
  RecordingState get recordingState => _recordingState;
  Duration get recordingDuration => _recordingDuration;
  PlaybackState get playbackState => _playbackState;
  Duration get playbackDuration => _playbackDuration;
  Duration get playbackPosition => _playbackPosition;
  String? get currentPlayingFileId => _currentPlayingFileId;

  bool get isRecording => _recordingState == RecordingState.recording;
  bool get isPaused => _recordingState == RecordingState.paused;
  bool get isPlaying => _playbackState == PlaybackState.playing;

  @override
  void dispose() {
    _stopRecording();
    _stopPlayback();
    _recorder.dispose();
    _player.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  // 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('마이크 권한 요청 실패: $e');
      return false;
    }
  }

  // 녹음 시작
  Future<bool> startRecording() async {
    try {
      // 권한 확인
      if (!await requestMicrophonePermission()) {
        debugPrint('마이크 권한이 필요합니다');
        return false;
      }

      // 진행 중인 재생 중단
      if (_playbackState != PlaybackState.idle) {
        await _stopPlayback();
      }

      // 녹음 파일 경로 생성
      final audioDir = await _storageService.getAudioDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${audioDir.path}/$fileName';

      // 녹음 설정 (Record 패키지는 기본 설정 사용)

      // 녹음 시작
      await _recorder.start(path: filePath);

      _currentRecordingPath = filePath;
      _recordingState = RecordingState.recording;
      _recordingDuration = Duration.zero;

      // 타이머 시작
      _startRecordingTimer();

      notifyListeners();
      debugPrint('녹음 시작: $filePath');
      return true;
    } catch (e) {
      debugPrint('녹음 시작 실패: $e');
      return false;
    }
  }

  // 녹음 일시정지
  Future<bool> pauseRecording() async {
    try {
      if (_recordingState != RecordingState.recording) return false;

      await _recorder.pause();
      _recordingState = RecordingState.paused;
      _recordingTimer?.cancel();

      notifyListeners();
      debugPrint('녹음 일시정지');
      return true;
    } catch (e) {
      debugPrint('녹음 일시정지 실패: $e');
      return false;
    }
  }

  // 녹음 재개
  Future<bool> resumeRecording() async {
    try {
      if (_recordingState != RecordingState.paused) return false;

      await _recorder.resume();
      _recordingState = RecordingState.recording;
      _startRecordingTimer();

      notifyListeners();
      debugPrint('녹음 재개');
      return true;
    } catch (e) {
      debugPrint('녹음 재개 실패: $e');
      return false;
    }
  }

  // 녹음 정지 및 저장
  Future<FileModel?> stopRecording(String noteId, {String? customName}) async {
    try {
      if (_recordingState == RecordingState.idle) return null;

      final recordingPath = await _recorder.stop();
      _stopRecordingTimer();

      if (recordingPath == null || _currentRecordingPath == null) {
        debugPrint('녹음 파일을 찾을 수 없습니다');
        return null;
      }

      // 파일 크기 확인
      final file = File(recordingPath);
      if (!await file.exists()) {
        debugPrint('녹음 파일이 존재하지 않습니다');
        return null;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        debugPrint('녹음 파일이 비어있습니다');
        await file.delete();
        return null;
      }

      // FileModel 생성
      final now = DateTime.now();
      final fileName = customName ?? '녹음 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      final audioFile = FileModel(
        id: _uuid.v4(),
        noteId: noteId,
        type: FileType.audio,
        name: fileName,
        content: '',
        filePath: recordingPath,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'duration': _recordingDuration.inSeconds.toDouble(),
          'fileSize': fileSize,
          'sampleRate': 44100,
          'bitRate': 128000,
        },
      );

      _recordingState = RecordingState.idle;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;

      notifyListeners();
      debugPrint('녹음 완료: ${audioFile.name}, 길이: ${_recordingDuration.inSeconds}초');
      return audioFile;
    } catch (e) {
      debugPrint('녹음 정지 실패: $e');
      await _stopRecording();
      return null;
    }
  }

  // 강제 녹음 중단
  Future<void> _stopRecording() async {
    try {
      if (_recordingState != RecordingState.idle) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('녹음 중단 실패: $e');
    } finally {
      _recordingState = RecordingState.idle;
      _recordingDuration = Duration.zero;
      _stopRecordingTimer();
      _currentRecordingPath = null;
      notifyListeners();
    }
  }

  // 오디오 재생 시작
  Future<bool> playAudio(FileModel audioFile) async {
    try {
      // 현재 재생 중인 파일이 있다면 중단
      if (_playbackState != PlaybackState.idle) {
        await _stopPlayback();
      }

      // 파일 존재 확인
      if (audioFile.filePath == null) {
        debugPrint('오디오 파일 경로가 없습니다');
        return false;
      }

      final file = File(audioFile.filePath!);
      if (!await file.exists()) {
        debugPrint('오디오 파일을 찾을 수 없습니다: ${audioFile.filePath}');
        return false;
      }

      // 재생 시작
      await _player.play(DeviceFileSource(audioFile.filePath!));

      _currentPlayingFileId = audioFile.id;
      _playbackState = PlaybackState.playing;
      _playbackDuration = Duration(seconds: audioFile.audioDuration.round());

      // 재생 상태 리스너 등록
      _setupPlaybackListeners();

      notifyListeners();
      debugPrint('오디오 재생 시작: ${audioFile.name}');
      return true;
    } catch (e) {
      debugPrint('오디오 재생 실패: $e');
      return false;
    }
  }

  // 재생 일시정지
  Future<bool> pausePlayback() async {
    try {
      if (_playbackState != PlaybackState.playing) return false;

      await _player.pause();
      _playbackState = PlaybackState.paused;

      notifyListeners();
      debugPrint('재생 일시정지');
      return true;
    } catch (e) {
      debugPrint('재생 일시정지 실패: $e');
      return false;
    }
  }

  // 재생 재개
  Future<bool> resumePlayback() async {
    try {
      if (_playbackState != PlaybackState.paused) return false;

      await _player.resume();
      _playbackState = PlaybackState.playing;

      notifyListeners();
      debugPrint('재생 재개');
      return true;
    } catch (e) {
      debugPrint('재생 재개 실패: $e');
      return false;
    }
  }

  // 재생 정지
  Future<void> stopPlayback() async {
    await _stopPlayback();
  }

  // 재생 위치 변경
  Future<bool> seekTo(Duration position) async {
    try {
      if (_playbackState == PlaybackState.idle) return false;

      await _player.seek(position);
      _playbackPosition = position;

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('재생 위치 변경 실패: $e');
      return false;
    }
  }

  // 재생 중단 (내부용)
  Future<void> _stopPlayback() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('재생 중단 실패: $e');
    } finally {
      _playbackState = PlaybackState.idle;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
      _currentPlayingFileId = null;
      notifyListeners();
    }
  }

  // 녹음 타이머 시작
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
      notifyListeners();
    });
  }

  // 녹음 타이머 정지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  // 재생 리스너 설정
  void _setupPlaybackListeners() {
    // 재생 완료 리스너
    _player.onPlayerComplete.listen((_) {
      _playbackState = PlaybackState.stopped;
      _playbackPosition = Duration.zero;
      _currentPlayingFileId = null;
      notifyListeners();
    });

    // 재생 위치 리스너
    _player.onPositionChanged.listen((position) {
      _playbackPosition = position;
      notifyListeners();
    });

    // 재생 길이 리스너
    _player.onDurationChanged.listen((duration) {
      _playbackDuration = duration;
      notifyListeners();
    });
  }

  // 오디오 파일 삭제
  Future<bool> deleteAudioFile(String fileId, String filePath) async {
    try {
      // 현재 재생 중인 파일이면 중단
      if (_currentPlayingFileId == fileId) {
        await _stopPlayback();
      }

      // 파일 삭제
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      debugPrint('오디오 파일 삭제 완료: $filePath');
      return true;
    } catch (e) {
      debugPrint('오디오 파일 삭제 실패: $e');
      return false;
    }
  }

  // 재생 진행률 (0.0 - 1.0)
  double get playbackProgress {
    if (_playbackDuration.inMilliseconds == 0) return 0.0;
    return _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds;
  }

  // 녹음 가능 시간 확인 (최대 60분)
  bool get canContinueRecording {
    return _recordingDuration.inMinutes < 60;
  }
}