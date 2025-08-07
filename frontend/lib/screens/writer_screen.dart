import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../services/drawing_service.dart';
import '../services/subscription_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/upgrade_dialog.dart';
import '../config/app_config.dart';

class WriterScreen extends StatefulWidget {
  const WriterScreen({super.key});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        // 선택된 노트가 있는지 확인
        if (noteProvider.selectedNote == null) {
          return const EmptyStateWidget(
            icon: Icons.folder_open,
            title: '리튼을 선택하세요',
            subtitle: '홈 탭에서 리튼을 선택하거나\n새로 생성해주세요',
          );
        }
        
        final note = noteProvider.selectedNote!;
        
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
              
              // 탭 바
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.text_fields),
                    text: '텍스트',
                  ),
                  Tab(
                    icon: Icon(Icons.draw),
                    text: '필기',
                  ),
                  Tab(
                    icon: Icon(Icons.image),
                    text: '파일',
                  ),
                ],
              ),
              
              // 탭 내용
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTextTab(note),
                    _buildHandwritingTab(note),
                    _buildFileTab(note),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 텍스트 탭 내용
  Widget _buildTextTab(note) {
    final textFiles = note.files.where((file) => file.type.name == 'text').toList();
    
    return textFiles.isEmpty
        ? EmptyStateWidget(
            icon: Icons.text_fields,
            title: '텍스트 파일이 없습니다',
            subtitle: '새 텍스트를 작성해보세요',
            actionText: '텍스트 추가',
            onActionPressed: _addTextFile,
          )
        : Column(
            children: [
              // 기존 텍스트 파일 목록
              if (textFiles.isNotEmpty) ...[
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: textFiles.length,
                    itemBuilder: (context, index) {
                      final file = textFiles[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.text_fields, color: Colors.white),
                          ),
                          title: Text(file.name),
                          subtitle: Text(
                            '${file.content.length} 자 • ${_formatDate(file.updatedAt)}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editTextFile(file.id);
                              } else if (value == 'delete') {
                                _deleteFile(file.id);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('편집'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('삭제', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _editTextFile(file.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              // 추가 버튼
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: Consumer<SubscriptionService>(
                    builder: (context, subscriptionService, child) {
                      final canAddText = subscriptionService.canUseFeature('unlimited_files') ||
                          note.getFileCount(FileType.text) < AppConfig.maxTextFilesPerNoteForFree;
                      
                      return FilledButton.icon(
                        onPressed: canAddText ? _addTextFile : () => _showUpgradeDialog('텍스트'),
                        icon: const Icon(Icons.add),
                        label: const Text('텍스트 추가'),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
  }
  
  // 필기 탭 내용
  Widget _buildHandwritingTab(note) {
    final handwritingFiles = note.files.where((file) => file.type.name == 'handwriting').toList();
    
    return handwritingFiles.isEmpty
        ? EmptyStateWidget(
            icon: Icons.draw,
            title: '필기 파일이 없습니다',
            subtitle: '새 필기를 시작해보세요',
            actionText: '필기 추가',
            onActionPressed: _addHandwritingFile,
          )
        : Column(
            children: [
              // 기존 필기 파일 목록
              if (handwritingFiles.isNotEmpty) ...[
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: handwritingFiles.length,
                    itemBuilder: (context, index) {
                      final file = handwritingFiles[index];
                      return Card(
                        child: InkWell(
                          onTap: () => _editHandwritingFile(file.id),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: file.filePath != null 
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(file.filePath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 48,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.gesture,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  file.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatDate(file.updatedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              // 추가 버튼
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: Consumer<SubscriptionService>(
                    builder: (context, subscriptionService, child) {
                      final canAddHandwriting = subscriptionService.canUseFeature('unlimited_files') ||
                          note.getFileCount(FileType.handwriting) < AppConfig.maxHandwritingFilesPerNoteForFree;
                      
                      return FilledButton.icon(
                        onPressed: canAddHandwriting ? _addHandwritingFile : () => _showUpgradeDialog('필기'),
                        icon: const Icon(Icons.add),
                        label: const Text('필기 추가'),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
  }
  
  // 파일 탭 내용
  Widget _buildFileTab(note) {
    return const EmptyStateWidget(
      icon: Icons.upload_file,
      title: '파일 변환 기능',
      subtitle: 'PDF, DOC, PPT 파일을\n이미지로 변환하여 주석 추가\n(곧 지원 예정)',
    );
  }
  
  void _addTextFile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('텍스트 에디터는 곧 구현될 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _editTextFile(String fileId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('텍스트 편집 기능은 곧 구현될 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  Future<void> _addHandwritingFile() async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final note = noteProvider.selectedNote;
    
    if (note == null) return;

    // 무료 버전 제한 확인
    if (note.getFileCount(FileType.handwriting) >= AppConfig.maxHandwritingFilesPerNoteForFree) {
      _showUpgradeDialog('필기');
      return;
    }

    // 그리기 화면으로 이동
    final result = await Navigator.of(context).push<FileModel>(
      MaterialPageRoute(
        builder: (context) => DrawingScreen(noteId: note.id),
      ),
    );

    // 새 필기 파일이 생성되면 노트에 추가
    if (result != null) {
      final success = await noteProvider.addFileToNote(note.id, result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('필기가 저장되었습니다: ${result.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('필기 저장에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  Future<void> _editHandwritingFile(String fileId) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final note = noteProvider.selectedNote;
    
    if (note == null) return;

    // 파일 찾기
    final file = note.files.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw Exception('파일을 찾을 수 없습니다'),
    );

    if (file.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파일 경로를 찾을 수 없습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 이미지 뷰어 또는 편집 옵션 표시
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('보기'),
              onTap: () {
                Navigator.of(context).pop();
                _viewHandwritingFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('주석 추가'),
              onTap: () async {
                Navigator.of(context).pop();
                await _addAnnotationToFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteHandwritingFile(fileId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewHandwritingFile(FileModel file) {
    if (file.filePath == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(file.name),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(file.filePath!),
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '이미지를 불러올 수 없습니다',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addAnnotationToFile(FileModel file) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final note = noteProvider.selectedNote;
    
    if (note == null || file.filePath == null) return;

    // 주석 추가 화면으로 이동
    final result = await Navigator.of(context).push<FileModel>(
      MaterialPageRoute(
        builder: (context) => DrawingScreen(
          noteId: note.id,
          existingImagePath: file.filePath!,
        ),
      ),
    );

    // 새 주석 파일이 생성되면 노트에 추가
    if (result != null) {
      final success = await noteProvider.addFileToNote(note.id, result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('주석이 추가되었습니다: ${result.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteHandwritingFile(String fileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('필기 삭제'),
        content: const Text('이 필기를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final note = noteProvider.selectedNote;
      
      if (note != null) {
        // 파일 찾기
        final file = note.files.firstWhere((f) => f.id == fileId);
        
        // 그리기 서비스에서 파일 삭제
        if (file.filePath != null) {
          await Provider.of<DrawingService>(context, listen: false)
              .deleteDrawingFile(fileId, file.filePath!);
        }

        // 노트에서 파일 제거
        final success = await noteProvider.removeFileFromNote(note.id, fileId);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('필기가 삭제되었습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
  
  void _deleteFile(String fileId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('파일 삭제 기능은 곧 구현될 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showUpgradeDialog(String fileType) {
    UpgradeDialog.show(
      context,
      featureName: '무제한 $fileType 파일',
      specificBenefits: [
        '무제한 $fileType 파일 추가',
        '광고 완전 제거',
        '클라우드 동기화',
        '우선 고객 지원',
      ],
    );
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