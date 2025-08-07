import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../services/audio_service.dart';
import '../models/note_model.dart';
import '../l10n/app_localizations.dart';
import '../widgets/empty_state_widget.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final AudioService _audioService = AudioService();
  
  @override
  Widget build(BuildContext context) {
    debugPrint('RecorderScreen build() 호출됨');
    
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final audioService = context.watch<AudioService>();
        
        return Scaffold(
          body: const Center(
            child: Text(
              '녹음된 오디오가 없습니다\n하단의 +듣기 버튼을 눌러\n첫 번째 녹음을 시작하세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _startRecording(audioService, noteProvider),
            icon: Icon(audioService.recordingState == RecordingState.recording 
                ? Icons.stop 
                : Icons.mic),
            label: Text(audioService.recordingState == RecordingState.recording 
                ? '녹음 정지' 
                : '+듣기'),
            backgroundColor: audioService.recordingState == RecordingState.recording 
                ? Colors.red 
                : null,
          ),
        );
      },
    );
  }

  // 녹음 시작 메서드
  Future<void> _startRecording(AudioService audioService, NoteProvider noteProvider) async {
    debugPrint('_startRecording 호출됨');
    
    try {
      // 선택된 노트가 없으면 첫 번째 노트를 선택
      if (noteProvider.selectedNote == null && noteProvider.notes.isNotEmpty) {
        noteProvider.selectNote(noteProvider.notes.first.id);
      }
      
      // 노트가 없으면 에러 메시지 표시
      if (noteProvider.selectedNote == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('먼저 홈 탭에서 리튼을 생성해주세요'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 녹음 상태에 따라 동작 결정
      if (audioService.recordingState == RecordingState.idle) {
        // 새 녹음 시작
        final success = await audioService.startRecording();
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('녹음을 시작했습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('녹음을 시작할 수 없습니다. 마이크 권한을 확인해주세요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (audioService.recordingState == RecordingState.recording) {
        // 녹음 정지 및 저장
        final note = noteProvider.selectedNote!;
        final audioFile = await audioService.stopRecording(note.id);
        
        if (audioFile != null) {
          final success = await noteProvider.addFileToNote(note.id, audioFile);
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('녹음이 저장되었습니다: ${audioFile.name}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('녹음 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('녹음 중 오류가 발생했습니다: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}