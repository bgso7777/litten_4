import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../models/note_model.dart';
import '../widgets/note_create_dialog.dart';
import '../widgets/note_list_item.dart';
import '../widgets/empty_state_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final filteredNotes = _searchQuery.isEmpty
            ? noteProvider.notes
            : noteProvider.searchNotes(_searchQuery);
        
        return Scaffold(
          body: Column(
            children: [
              // 검색 바
              if (noteProvider.notes.isNotEmpty) _buildSearchBar(),
              
              // 노트 목록
              Expanded(
                child: noteProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredNotes.isEmpty
                        ? _buildEmptyState(noteProvider)
                        : _buildNoteList(filteredNotes),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateNoteDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('리튼 생성'),
          ),
        );
      },
    );
  }
  
  // 검색 바 위젯
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '노트 검색...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }
  
  // 빈 상태 위젯
  Widget _buildEmptyState(NoteProvider noteProvider) {
    if (noteProvider.notes.isEmpty) {
      // 노트가 아예 없을 때
      return const EmptyStateWidget(
        icon: Icons.note_add,
        title: '첫 번째 리튼을 만들어보세요',
        subtitle: '음성, 텍스트, 필기를 하나의 공간에서\n통합 관리할 수 있습니다',
        actionText: '리튼 생성',
      );
    } else {
      // 검색 결과가 없을 때
      return EmptyStateWidget(
        icon: Icons.search_off,
        title: '검색 결과가 없습니다',
        subtitle: '"$_searchQuery"와 일치하는 노트를 찾을 수 없습니다',
        actionText: '검색어 지우기',
        onActionPressed: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
          });
        },
      );
    }
  }
  
  // 노트 목록 위젯
  Widget _buildNoteList(List<NoteModel> notes) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<NoteProvider>().refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NoteListItem(
              note: notes[index],
              onTap: () => _onNoteSelected(notes[index]),
              onDelete: () => _deleteNote(notes[index].id),
            ),
          );
        },
      ),
    );
  }
  
  // 노트 생성 다이얼로그 표시
  Future<void> _showCreateNoteDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const NoteCreateDialog(),
    );
    
    if (result == true) {
      // 노트가 생성되면 새로고침
      if (mounted) {
        await context.read<NoteProvider>().refresh();
      }
    }
  }
  
  // 노트 선택
  void _onNoteSelected(NoteModel note) {
    final noteProvider = context.read<NoteProvider>();
    noteProvider.selectNote(note.id);
    
    // 선택된 노트 피드백
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${note.title} 선택됨'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // 노트 삭제
  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노트 삭제'),
        content: const Text('이 노트를 삭제하시겠습니까?\n모든 파일이 함께 삭제됩니다.'),
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
    
    if (confirmed == true && mounted) {
      try {
        final success = await context.read<NoteProvider>().deleteNote(noteId);
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('노트가 삭제되었습니다'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('노트 삭제 실패: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}