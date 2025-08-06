import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/empty_state_widget.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        // 선택된 노트가 있는지 확인
        if (noteProvider.selectedNote == null) {
          return EmptyStateWidget(
            icon: Icons.folder_open,
            title: '리튼을 선택하세요',
            subtitle: '홈 탭에서 리튼을 선택하거나\n새로 생성해주세요',
            actionText: '홈으로 이동',
            onActionPressed: () {
              // 홈 탭으로 이동하는 로직은 MainTabScreen에서 처리
            },
          );
        }
        
        final note = noteProvider.selectedNote!;
        final audioFiles = note.files.where((file) => file.type.name == 'audio').toList();
        
        return Scaffold(
          body: Column(
            children: [
              // 선택된 노트 정보
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (note.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 오디오 파일 목록
              Expanded(
                child: audioFiles.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.mic_none,
                        title: '녹음된 오디오가 없습니다',
                        subtitle: '하단의 녹음 버튼을 눌러\n첫 번째 녹음을 시작하세요',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: audioFiles.length,
                        itemBuilder: (context, index) {
                          final file = audioFiles[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                child: const Icon(
                                  Icons.audio_file,
                                  color: Colors.red,
                                ),
                              ),
                              title: Text(file.name),
                              subtitle: Text(
                                '${_formatDuration(file.audioDuration)} • ${_formatDate(file.createdAt)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () => _playAudio(file.id),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteAudioFile(file.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('삭제'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              
              // 녹음 컨트롤 패널
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // 녹음 시간 표시
                    Text(
                      '00:00',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 녹음 버튼들
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 일시정지 버튼
                        FloatingActionButton(
                          heroTag: "pause",
                          onPressed: null, // TODO: 일시정지 기능
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.pause, color: Colors.grey),
                        ),
                        
                        // 메인 녹음 버튼
                        FloatingActionButton.large(
                          heroTag: "record",
                          onPressed: _startRecording,
                          backgroundColor: Colors.red,
                          child: const Icon(Icons.mic, color: Colors.white, size: 32),
                        ),
                        
                        // 정지 버튼
                        FloatingActionButton(
                          heroTag: "stop",
                          onPressed: null, // TODO: 정지 기능
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.stop, color: Colors.grey),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 상태 표시
                    Text(
                      '녹음을 시작하려면 마이크 버튼을 누르세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _startRecording() {
    // TODO: 녹음 시작 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('녹음 기능은 곧 구현될 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _playAudio(String fileId) {
    // TODO: 오디오 재생 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('재생 기능은 곧 구현될 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _deleteAudioFile(String fileId) {
    // TODO: 오디오 파일 삭제 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('파일 삭제 기능은 곧 구현될 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '어제';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}