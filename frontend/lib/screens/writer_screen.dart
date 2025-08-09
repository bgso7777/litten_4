import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'dart:typed_data';
import 'dart:io';
import 'dart:html' as html;
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:uuid/uuid.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../services/drawing_service.dart';
import '../services/subscription_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/upgrade_dialog.dart';
import '../config/app_config.dart';
import 'text_editor_screen.dart';
import 'pdf_to_image_screen.dart';
import 'image_viewer_screen.dart';

class WriterScreen extends StatefulWidget {
  final Function({String? noteId, FileModel? existingFile})? onShowTextEditor;
  
  const WriterScreen({super.key, this.onShowTextEditor});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  // 필기 상태 관리
  bool _isDrawingMode = false;
  List<List<Offset>> _drawingPaths = [];
  List<Offset> _currentPath = [];
  Color _penColor = Colors.blue;
  double _penWidth = 3.0;
  
  // 이미지 편집 상태 관리
  FileModel? _selectedImageForEdit;
  bool _isEditingImage = false;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        return Scaffold(
          body: _buildBody(noteProvider),
          floatingActionButton: _buildFloatingActionButtons(noteProvider),
        );
      },
    );
  }

  // UI 본문 구성
  Widget _buildBody(NoteProvider noteProvider) {
    final selectedNote = noteProvider.selectedNote;
    
    // 선택된 노트가 없는 경우
    if (selectedNote == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '선택된 리튼이 없습니다\n아래 버튼을 눌러 파일을 추가하면\n"이름없는 리튼"이 자동으로 생성됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.blue, size: 20),
                Text(' 텍스트', style: TextStyle(color: Colors.blue)),
                SizedBox(width: 20),
                Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                Text(' PDF', style: TextStyle(color: Colors.red)),
              ],
            ),
          ],
        ),
      );
    }

    // 텍스트와 PDF 파일 목록 가져오기
    final textFiles = selectedNote.files.where((file) => file.type == FileType.text).toList();
    final pdfFiles = selectedNote.files.where((file) => file.type == FileType.handwriting || file.type == FileType.convertedImage).toList();
    
    // 이미지 편집 모드인 경우
    if (_isEditingImage && _selectedImageForEdit != null) {
      return _buildImageEditingArea(_selectedImageForEdit!);
    }
    
    // 파일이 없는 경우 - 필기 영역 제공
    if (textFiles.isEmpty && pdfFiles.isEmpty) {
      return _buildDrawingArea();
    }

    // 파일 목록 표시
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.edit_note, color: Colors.green),
              SizedBox(width: 8),
              Text(
                '작성된 파일 (${textFiles.length + pdfFiles.length}개)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        // 파일 목록
        Expanded(
          child: ListView(
            children: [
              // 텍스트 파일들
              if (textFiles.isNotEmpty) ...[
                _buildSectionHeader('텍스트 문서', Icons.text_fields, Colors.blue),
                ...textFiles.map((file) => _buildTextFileItem(file)),
                SizedBox(height: 16),
              ],
              // PDF/필기 파일들
              if (pdfFiles.isNotEmpty) ...[
                _buildSectionHeader('PDF 및 필기', Icons.picture_as_pdf, Colors.red),
                ...pdfFiles.map((file) => _buildPdfFileItem(file)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Floating Action Buttons
  Widget _buildFloatingActionButtons(NoteProvider noteProvider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: "pdf",
          onPressed: () => _addPdfFile(noteProvider),
          backgroundColor: Colors.red,
          icon: Icon(Icons.picture_as_pdf, color: Colors.white),
          label: Text('+PDF', style: TextStyle(color: Colors.white)),
        ),
        SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: "text",
          onPressed: () => _addTextFile(noteProvider),
          backgroundColor: Colors.blue,
          icon: Icon(Icons.text_fields, color: Colors.white),
          label: Text('+텍스트', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // 섹션 헤더
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              margin: EdgeInsets.only(left: 12),
              color: color.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // 텍스트 파일 아이템
  Widget _buildTextFileItem(FileModel file) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.text_fields, color: Colors.white),
        ),
        title: Text(
          file.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${file.content.length} 자',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '생성: ${_formatDateTime(file.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editTextFile(file),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteTextFile(file),
            ),
          ],
        ),
        onTap: () => _editTextFile(file),
      ),
    );
  }

  // PDF 파일 아이템
  Widget _buildPdfFileItem(FileModel file) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.picture_as_pdf, color: Colors.white),
        ),
        title: Text(
          file.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.type == FileType.handwriting ? 'PDF 필기' : '변환된 이미지',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              '생성: ${_formatDateTime(file.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.green),
              onPressed: () => _viewPdfFile(file),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deletePdfFile(file),
            ),
          ],
        ),
        onTap: () => _handlePdfFileClick(file),
      ),
    );
  }

  // 텍스트 파일 추가
  Future<void> _addTextFile(NoteProvider noteProvider) async {
    try {
      // 인라인 텍스트 에디터를 사용할 수 있는 경우
      if (widget.onShowTextEditor != null) {
        // 항상 "기본리튼" 생성하고 그곳에 저장
        final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
        if (defaultNote == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('리튼 생성에 실패했습니다'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // 인라인 텍스트 에디터 열기
        widget.onShowTextEditor!(noteId: noteProvider.selectedNote?.id);
        return;
      }
      
      // 기존 방식 (새 창으로 이동)
      final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
      if (defaultNote == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리튼 생성에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final note = noteProvider.selectedNote!;
      
      // 텍스트 에디터로 이동
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TextEditorScreen(noteId: note.id),
        ),
      );
      
      if (result == true) {
        // 파일이 추가되면 UI 새로고침
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('텍스트 파일이 저장되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('텍스트 파일 추가 중 오류가 발생했습니다: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // PDF 파일 추가
  Future<void> _addPdfFile(NoteProvider noteProvider) async {
    try {
      // 항상 "기본리튼" 생성하고 그곳에 저장
      final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
      if (defaultNote == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리튼 생성에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      file_picker.FilePickerResult? result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (kIsWeb) {
          // 웹에서는 bytes 사용
          if (file.bytes != null) {
            await _processPdfFile(file.bytes!, file.name, noteProvider);
          }
        } else {
          // 네이티브에서는 path 사용
          if (file.path != null) {
            final fileBytes = await File(file.path!).readAsBytes();
            await _processPdfFile(fileBytes, file.name, noteProvider);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 파일을 불러오는 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // PDF 파일 처리 - 직접 이미지로 저장
  Future<void> _processPdfFile(Uint8List fileBytes, String fileName, NoteProvider noteProvider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF를 이미지로 변환 중...'),
          ],
        ),
      ),
    );

    try {
      // PDF Blob URL 생성 (PDF 내용을 그대로 사용)
      final blob = html.Blob([fileBytes], 'application/pdf');
      final pdfUrl = html.Url.createObjectUrl(blob);
      
      // 현재 시간으로 파일명 생성
      final now = DateTime.now();
      final pdfFileName = fileName.replaceAll('.pdf', '') + 
          ' ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      // PDF 파일로 저장 (type을 pdfWithDrawing으로 설정하여 필기 가능한 PDF로 구분)
      final pdfFile = FileModel(
        id: Uuid().v4(),
        noteId: noteProvider.selectedNote!.id,
        type: FileType.convertedImage, // 필기 가능한 PDF로 분류
        name: pdfFileName,
        content: '',
        filePath: pdfUrl, // PDF Blob URL을 저장
        createdAt: now,
        updatedAt: now,
        metadata: {
          'originalType': 'pdf',
          'originalFileName': fileName,
          'fileSize': fileBytes.length,
          'platform': 'web',
          'isPdf': true, // PDF 파일임을 명시
          'mimeType': 'application/pdf',
        },
      );
      
      await noteProvider.addFileToNote(noteProvider.selectedNote!.id, pdfFile);
      
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pdfFileName}이(가) 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF 처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 텍스트 파일 편집
  void _editTextFile(FileModel file) async {
    // 인라인 텍스트 에디터를 사용할 수 있는 경우
    if (widget.onShowTextEditor != null) {
      widget.onShowTextEditor!(noteId: file.noteId, existingFile: file);
      return;
    }
    
    // 기존 방식 (새 창으로 이동)
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TextEditorScreen(
          noteId: file.noteId,
          existingFile: file,
        ),
      ),
    );
    
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('텍스트 파일이 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // PDF 파일 클릭 처리
  void _handlePdfFileClick(FileModel file) {
    if (file.type == FileType.convertedImage) {
      // 변환된 이미지인 경우 편집 모드로 전환
      _loadImageForEditing(file);
    } else {
      // 기존 PDF 파일은 뷰어로 열기
      _viewPdfFile(file);
    }
  }
  
  // 이미지 편집 모드로 전환
  void _loadImageForEditing(FileModel file) {
    setState(() {
      _selectedImageForEdit = file;
      _isEditingImage = true;
      
      // 기존 필기 데이터 로드
      _drawingPaths.clear();
      _currentPath.clear();
      
      if (file.metadata?['drawingPaths'] != null) {
        try {
          final pathsData = file.metadata!['drawingPaths'] as List;
          _drawingPaths = pathsData.map((pathData) {
            final path = (pathData as List).map((point) {
              return Offset(point['x'].toDouble(), point['y'].toDouble());
            }).toList();
            return path;
          }).toList();
          
          if (file.metadata!['penColor'] != null) {
            _penColor = Color(file.metadata!['penColor']);
          }
          if (file.metadata!['penWidth'] != null) {
            _penWidth = file.metadata!['penWidth'].toDouble();
          }
        } catch (e) {
          debugPrint('필기 데이터 로드 실패: $e');
        }
      }
    });
  }

  // PDF 파일 보기
  void _viewPdfFile(FileModel file) {
    if (file.filePath == null) return;
    
    if (kIsWeb) {
      // 웹에서는 Blob URL로 표시
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            imageUrl: file.filePath!,
            fileName: file.name,
            isWeb: true,
            fileModel: file, // 필기 기능을 위해 파일 모델 전달
          ),
        ),
      );
    } else {
      // 네이티브에서는 파일 경로로 표시
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            imagePath: file.filePath!,
            fileName: file.name,
            isWeb: false,
            fileModel: file, // 필기 기능을 위해 파일 모델 전달
          ),
        ),
      );
    }
  }

  // 텍스트 파일 삭제
  void _deleteTextFile(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('텍스트 파일 삭제'),
        content: Text('"${file.name}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final success = await noteProvider.removeFileFromNote(file.noteId, file.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.name}"이(가) 삭제되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // PDF 파일 삭제
  void _deletePdfFile(FileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF 파일 삭제'),
        content: Text('"${file.name}"을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // 파일 삭제
      if (file.filePath != null) {
        if (!kIsWeb) {
          try {
            await File(file.filePath!).delete();
          } catch (e) {
            debugPrint('파일 삭제 실패: $e');
          }
        }
      }
      
      final success = await noteProvider.removeFileFromNote(file.noteId, file.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.name}"이(가) 삭제되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 날짜 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  // 필기 영역 빌드
  Widget _buildDrawingArea() {
    return Column(
      children: [
        // 필기 도구 모음
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.draw, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    '자유 필기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  // 저장 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? _saveDrawing : null,
                    icon: Icon(Icons.save),
                    label: Text('저장'),
                  ),
                  SizedBox(width: 8),
                  // 지우기 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? _clearDrawing : null,
                    icon: Icon(Icons.clear),
                    label: Text('지우기'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('펜 색상: ', style: TextStyle(fontSize: 14)),
                  // 펜 색상 선택
                  _buildColorButton(Colors.blue),
                  _buildColorButton(Colors.red),
                  _buildColorButton(Colors.green),
                  _buildColorButton(Colors.orange),
                  _buildColorButton(Colors.black),
                  Spacer(),
                  Text('마우스나 터치로 자유롭게 그리세요', 
                       style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
        // 필기 캔버스
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.white,
            child: Stack(
              children: [
                // 배경 가이드
                if (_drawingPaths.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gesture, size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text('이 영역에서 자유롭게 필기하세요',
                             style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                // 그리기 캔버스
                GestureDetector(
                  onPanStart: _startDrawing,
                  onPanUpdate: _updateDrawing,
                  onPanEnd: _endDrawing,
                  child: CustomPaint(
                    painter: DrawingPainter(_drawingPaths, _currentPath, _penColor, _penWidth),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // 펜 색상 버튼
  Widget _buildColorButton(Color color) {
    return GestureDetector(
      onTap: () => setState(() => _penColor = color),
      child: Container(
        width: 24,
        height: 24,
        margin: EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _penColor == color ? Colors.grey[800]! : Colors.grey[400]!,
            width: _penColor == color ? 2 : 1,
          ),
        ),
      ),
    );
  }
  
  // 그리기 시작
  void _startDrawing(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }
  
  // 그리기 업데이트
  void _updateDrawing(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }
  
  // 그리기 종료
  void _endDrawing(DragEndDetails details) {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _drawingPaths.add(List.from(_currentPath));
        _currentPath.clear();
      });
    }
  }
  
  // 그림 저장
  Future<void> _saveDrawing() async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // 기본리튼 생성 또는 선택
      final defaultNote = await noteProvider.createDefaultNoteIfNeeded();
      if (defaultNote == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('리튼 생성에 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 그림 데이터를 JSON으로 변환
      final drawingData = {
        'paths': _drawingPaths.map((path) => 
          path.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList()
        ).toList(),
        'color': _penColor.value,
        'width': _penWidth,
      };
      
      final now = DateTime.now();
      final fileName = '필기 ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      
      final drawingFile = FileModel(
        id: const Uuid().v4(),
        noteId: noteProvider.selectedNote!.id,
        type: FileType.handwriting,
        name: fileName,
        content: jsonEncode(drawingData), // 그림 데이터를 JSON으로 저장
        createdAt: now,
        updatedAt: now,
        metadata: {
          'type': 'drawing',
          'pathCount': _drawingPaths.length,
          'platform': 'web',
        },
      );
      
      await noteProvider.addFileToNote(noteProvider.selectedNote!.id, drawingFile);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fileName}이(가) 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // 그리기 영역 지우기
      _clearDrawing();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('필기 저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 그리기 지우기
  void _clearDrawing() {
    setState(() {
      _drawingPaths.clear();
      _currentPath.clear();
    });
  }
  
  // 이미지 편집 영역 빌드
  Widget _buildImageEditingArea(FileModel imageFile) {
    return Column(
      children: [
        // 편집 도구 모음
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // 뒤로가기 버튼
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditingImage = false;
                        _selectedImageForEdit = null;
                      });
                    },
                    icon: Icon(Icons.arrow_back),
                    tooltip: '목록으로 돌아가기',
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.edit, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    '${imageFile.name} 편집',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  // 저장 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? () => _saveImageDrawing(imageFile) : null,
                    icon: Icon(Icons.save),
                    label: Text('저장'),
                  ),
                  SizedBox(width: 8),
                  // 지우기 버튼
                  ElevatedButton.icon(
                    onPressed: _drawingPaths.isNotEmpty ? _clearDrawing : null,
                    icon: Icon(Icons.clear),
                    label: Text('지우기'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('펜 색상: ', style: TextStyle(fontSize: 14)),
                  // 펜 색상 선택
                  _buildColorButton(Colors.red),
                  _buildColorButton(Colors.blue),
                  _buildColorButton(Colors.green),
                  _buildColorButton(Colors.orange),
                  _buildColorButton(Colors.black),
                  Spacer(),
                  Text('마우스나 터치로 이미지에 필기하세요', 
                       style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
        // 이미지와 필기 캔버스
        Expanded(
          child: Stack(
            children: [
              // 배경 PDF 또는 이미지
              if (imageFile.filePath != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: _buildBackgroundContent(imageFile),
                  ),
                ),
              
              // 필기 레이어
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: _startImageDrawing,
                  onPanUpdate: _updateImageDrawing,
                  onPanEnd: _endImageDrawing,
                  child: CustomPaint(
                    painter: DrawingPainter(_drawingPaths, _currentPath, _penColor, _penWidth),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 이미지 편집용 필기 시작
  void _startImageDrawing(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }
  
  // 이미지 편집용 필기 업데이트
  void _updateImageDrawing(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }
  
  // 이미지 편집용 필기 종료
  void _endImageDrawing(DragEndDetails details) {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _drawingPaths.add(List.from(_currentPath));
        _currentPath.clear();
      });
    }
  }
  
  // 배경 콘텐츠 빌드 (PDF 또는 이미지)
  Widget _buildBackgroundContent(FileModel file) {
    final isPdf = file.metadata?['isPdf'] == true;
    
    if (kIsWeb) {
      if (isPdf) {
        // PDF 파일인 경우 iframe으로 표시
        final viewType = 'pdf-viewer-${file.id}-${DateTime.now().millisecondsSinceEpoch}';
        _registerPdfViewer(viewType, file.filePath!);
        
        return HtmlElementView(
          key: ValueKey(viewType),
          viewType: viewType,
        );
      } else {
        // 일반 이미지 파일
        return Image.network(
          file.filePath!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget('이미지를 불러올 수 없습니다');
          },
        );
      }
    } else {
      // 네이티브에서는 파일 경로로 표시
      return Image.file(
        File(file.filePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('파일을 불러올 수 없습니다');
        },
      );
    }
  }
  
  // 오류 위젯
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
  
  // PDF 뷰어 등록
  void _registerPdfViewer(String viewType, String pdfUrl) {
    try {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = pdfUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..setAttribute('type', 'application/pdf');
          
          debugPrint('PDF iframe 생성 완료: $viewType');
          return iframe;
        },
      );
    } catch (e) {
      debugPrint('PDF 뷰어 등록 실패: $e');
    }
  }

  // 이미지 필기 저장
  Future<void> _saveImageDrawing(FileModel imageFile) async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      
      // 필기 데이터를 메타데이터에 저장
      final updatedMetadata = Map<String, dynamic>.from(imageFile.metadata ?? {});
      updatedMetadata['drawingPaths'] = _drawingPaths.map((path) => 
        path.map((offset) => {'x': offset.dx, 'y': offset.dy}).toList()
      ).toList();
      updatedMetadata['penColor'] = _penColor.value;
      updatedMetadata['penWidth'] = _penWidth;
      updatedMetadata['lastEditTime'] = DateTime.now().toIso8601String();
      
      final updatedFile = imageFile.copyWith(
        metadata: updatedMetadata,
        updatedAt: DateTime.now(),
      );
      
      await noteProvider.updateFileInNote(imageFile.noteId, updatedFile);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('필기가 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// 그리기 페인터 클래스
class DrawingPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final List<Offset> currentPath;
  final Color color;
  final double strokeWidth;
  
  DrawingPainter(this.paths, this.currentPath, this.color, this.strokeWidth);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    // 완성된 경로들 그리기
    for (final path in paths) {
      if (path.length > 1) {
        final drawPath = Path();
        drawPath.moveTo(path[0].dx, path[0].dy);
        
        for (int i = 1; i < path.length; i++) {
          drawPath.lineTo(path[i].dx, path[i].dy);
        }
        
        canvas.drawPath(drawPath, paint);
      } else if (path.length == 1) {
        // 단일 점 그리기
        canvas.drawCircle(path[0], strokeWidth / 2, paint..style = PaintingStyle.fill);
      }
    }
    
    // 현재 그리고 있는 경로 그리기
    if (currentPath.length > 1) {
      final drawPath = Path();
      drawPath.moveTo(currentPath[0].dx, currentPath[0].dy);
      
      for (int i = 1; i < currentPath.length; i++) {
        drawPath.lineTo(currentPath[i].dx, currentPath[i].dy);
      }
      
      canvas.drawPath(drawPath, paint);
    } else if (currentPath.length == 1) {
      canvas.drawCircle(currentPath[0], strokeWidth / 2, paint..style = PaintingStyle.fill);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}