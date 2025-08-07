import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';
import '../services/local_storage_service.dart';
import '../services/web_storage_service.dart';

class NoteProvider extends ChangeNotifier {
  final List<NoteModel> _notes = [];
  final LocalStorageService _storageService = LocalStorageService();
  NoteModel? _selectedNote;
  bool _isLoading = false;
  
  // 웹 환경 여부
  bool get _isWeb => kIsWeb;
  
  // Getters
  List<NoteModel> get notes => _notes;
  NoteModel? get selectedNote => _selectedNote;
  bool get isLoading => _isLoading;
  int get noteCount => _notes.length;
  
  // UUID 생성기
  final _uuid = const Uuid();
  
  NoteProvider() {
    _loadNotes();
  }
  
  // 노트 목록 로드
  Future<void> _loadNotes() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final loadedNotes = _isWeb 
          ? await WebStorageService.loadNotes()
          : await _storageService.loadNotes();
      
      _notes.clear();
      _notes.addAll(loadedNotes);
      
      // 첫 실행 시 샘플 리튼 생성
      if (_notes.isEmpty) {
        await _createSampleNotes();
      }
      
      // 최신 순으로 정렬
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('노트 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 샘플 노트 생성
  Future<void> _createSampleNotes() async {
    try {
      // 첫 번째 샘플 노트: 강의-화-교양
      await createNote(
        '강의-화-교양', 
        description: '교양 강의 노트 공간입니다. 음성 녹음과 필기를 함께 활용해보세요.',
        bypassLimit: true,
      );
      
      // 두 번째 샘플 노트: 회의-주간
      await createNote(
        '회의-주간', 
        description: '주간 회의 내용을 기록하는 공간입니다. 중요한 결정사항을 놓치지 마세요.',
        bypassLimit: true,
      );
      
      debugPrint('샘플 노트 생성 완료: 강의-화-교양, 회의-주간');
    } catch (e) {
      debugPrint('샘플 노트 생성 실패: $e');
    }
  }
  
  // 노트 생성
  Future<NoteModel?> createNote(String title, {String description = '', bool bypassLimit = false}) async {
    // 무료 버전 제한 확인 (샘플 노트 생성 시는 제외)
    if (!bypassLimit && _notes.length >= AppConfig.maxNotesForFree) {
      throw Exception('무료 버전에서는 최대 ${AppConfig.maxNotesForFree}개의 노트만 생성할 수 있습니다.');
    }
    
    final now = DateTime.now();
    final note = NoteModel(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? '새 노트' : title.trim(),
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );
    
    try {
      if (_isWeb) {
        await WebStorageService.saveNote(note);
      } else {
        await _storageService.saveNote(note);
      }
      _notes.insert(0, note);
      notifyListeners();
      return note;
    } catch (e) {
      debugPrint('노트 생성 실패: $e');
      return null;
    }
  }
  
  // 노트 업데이트
  Future<bool> updateNote(NoteModel updatedNote) async {
    final index = _notes.indexWhere((note) => note.id == updatedNote.id);
    if (index == -1) return false;
    
    final noteWithUpdatedTime = updatedNote.copyWith(
      updatedAt: DateTime.now(),
    );
    
    try {
      if (_isWeb) {
        await WebStorageService.saveNote(noteWithUpdatedTime);
      } else {
        await _storageService.saveNote(noteWithUpdatedTime);
      }
      _notes[index] = noteWithUpdatedTime;
      
      // 최신 순으로 정렬
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      if (_selectedNote?.id == updatedNote.id) {
        _selectedNote = noteWithUpdatedTime;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('노트 업데이트 실패: $e');
      return false;
    }
  }
  
  // 노트 삭제
  Future<bool> deleteNote(String noteId) async {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) return false;
    
    try {
      if (_isWeb) {
        await WebStorageService.deleteNote(noteId);
      } else {
        await _storageService.deleteNote(noteId);
      }
      _notes.removeAt(index);
      
      if (_selectedNote?.id == noteId) {
        _selectedNote = null;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('노트 삭제 실패: $e');
      return false;
    }
  }
  
  // 노트 선택
  void selectNote(String? noteId) {
    if (noteId == null) {
      _selectedNote = null;
    } else {
      _selectedNote = _notes.firstWhere(
        (note) => note.id == noteId,
        orElse: () => _selectedNote!,
      );
    }
    notifyListeners();
  }
  
  // 노트에 파일 추가
  Future<bool> addFileToNote(String noteId, FileModel file) async {
    final noteIndex = _notes.indexWhere((note) => note.id == noteId);
    if (noteIndex == -1) return false;
    
    final note = _notes[noteIndex];
    
    // 무료 버전 제한 확인
    if (file.type == FileType.audio && !note.canAddAudioFile()) {
      throw Exception('무료 버전에서는 노트당 최대 ${AppConfig.maxAudioFilesPerNoteForFree}개의 오디오 파일만 추가할 수 있습니다.');
    }
    
    if ((file.type == FileType.text || file.type == FileType.handwriting) && 
        !note.canAddWritingFile()) {
      throw Exception('무료 버전에서는 노트당 텍스트 ${AppConfig.maxTextFilesPerNoteForFree}개, 필기 ${AppConfig.maxHandwritingFilesPerNoteForFree}개만 추가할 수 있습니다.');
    }
    
    final updatedFiles = List<FileModel>.from(note.files)..add(file);
    final updatedNote = note.copyWith(
      files: updatedFiles,
      updatedAt: DateTime.now(),
    );
    
    return await updateNote(updatedNote);
  }
  
  // 노트에서 파일 제거
  Future<bool> removeFileFromNote(String noteId, String fileId) async {
    final noteIndex = _notes.indexWhere((note) => note.id == noteId);
    if (noteIndex == -1) return false;
    
    final note = _notes[noteIndex];
    final updatedFiles = note.files.where((file) => file.id != fileId).toList();
    
    final updatedNote = note.copyWith(
      files: updatedFiles,
      updatedAt: DateTime.now(),
    );
    
    try {
      // 파일 삭제
      if (_isWeb) {
        await WebStorageService.deleteFile(fileId);
      } else {
        await _storageService.deleteFile(fileId);
      }
      return await updateNote(updatedNote);
    } catch (e) {
      debugPrint('파일 삭제 실패: $e');
      return false;
    }
  }
  
  // 노트에서 파일 업데이트
  Future<bool> updateFileInNote(String noteId, FileModel updatedFile) async {
    final noteIndex = _notes.indexWhere((note) => note.id == noteId);
    if (noteIndex == -1) return false;
    
    final note = _notes[noteIndex];
    final fileIndex = note.files.indexWhere((file) => file.id == updatedFile.id);
    if (fileIndex == -1) return false;
    
    final updatedFiles = List<FileModel>.from(note.files);
    updatedFiles[fileIndex] = updatedFile.copyWith(updatedAt: DateTime.now());
    
    final updatedNote = note.copyWith(
      files: updatedFiles,
      updatedAt: DateTime.now(),
    );
    
    return await updateNote(updatedNote);
  }
  
  // ID로 노트 찾기
  NoteModel? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // 검색
  List<NoteModel> searchNotes(String query) {
    if (query.trim().isEmpty) return _notes;
    
    final lowercaseQuery = query.toLowerCase();
    return _notes.where((note) {
      return note.title.toLowerCase().contains(lowercaseQuery) ||
             note.description.toLowerCase().contains(lowercaseQuery) ||
             note.files.any((file) => 
               file.name.toLowerCase().contains(lowercaseQuery) ||
               file.content.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }
  
  // 사용량 통계
  Map<String, int> get usageStats {
    final stats = <String, int>{
      'totalNotes': _notes.length,
      'totalAudioFiles': 0,
      'totalTextFiles': 0,
      'totalHandwritingFiles': 0,
      'totalConvertedImages': 0,
    };
    
    for (final note in _notes) {
      stats['totalAudioFiles'] = stats['totalAudioFiles']! + note.audioFileCount;
      for (final file in note.files) {
        switch (file.type) {
          case FileType.text:
            stats['totalTextFiles'] = stats['totalTextFiles']! + 1;
            break;
          case FileType.handwriting:
            stats['totalHandwritingFiles'] = stats['totalHandwritingFiles']! + 1;
            break;
          case FileType.convertedImage:
            stats['totalConvertedImages'] = stats['totalConvertedImages']! + 1;
            break;
          case FileType.audio:
            // 이미 위에서 계산됨
            break;
        }
      }
    }
    
    return stats;
  }
  
  // 새로고침
  Future<void> refresh() async {
    await _loadNotes();
  }
}