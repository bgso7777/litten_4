import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../config/app_config.dart';
import '../services/preferences_service.dart';
import '../widgets/ad_banner_widget.dart';
import 'home_screen.dart';
import 'recorder_screen.dart';
import 'writer_screen.dart';
import 'settings_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  String _subscriptionType = 'free';
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const RecorderScreen(),
    const WriterScreen(),
    const SettingsScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    _loadSubscriptionType();
  }
  
  Future<void> _loadSubscriptionType() async {
    final subscriptionType = PreferencesService.getSubscriptionType();
    setState(() {
      _subscriptionType = subscriptionType;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: _buildAppBarTitle(noteProvider),
            centerTitle: true,
            actions: _buildAppBarActions(noteProvider),
            elevation: 0,
          ),
          body: Column(
            children: [
              // 무료 사용자만 광고 배너 표시
              if (_subscriptionType == 'free' && AppConfig.showAdsForFreeUsers)
                const AdBannerWidget(),
              
              // 메인 콘텐츠
              Expanded(
                child: _screens[_currentIndex],
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: '홈',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.mic),
                label: '듣기',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.edit),
                label: '쓰기',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: '설정',
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 앱바 제목 생성
  Widget _buildAppBarTitle(NoteProvider noteProvider) {
    if (noteProvider.selectedNote != null) {
      return Text(
        noteProvider.selectedNote!.title,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    switch (_currentIndex) {
      case 0:
        return const Text('리튼');
      case 1:
        return const Text('듣기');
      case 2:
        return const Text('쓰기');
      case 3:
        return const Text('설정');
      default:
        return const Text('리튼');
    }
  }
  
  // 앱바 액션 버튼들 생성
  List<Widget> _buildAppBarActions(NoteProvider noteProvider) {
    final actions = <Widget>[];
    
    // 선택된 노트가 있을 때 파일 카운터 표시
    if (noteProvider.selectedNote != null) {
      final note = noteProvider.selectedNote!;
      
      // 오디오 파일 카운터
      if (note.audioFileCount > 0) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFileCountBadge(
              Icons.mic,
              note.audioFileCount,
              AppConfig.maxAudioFilesPerNoteForFree,
              Colors.red,
            ),
          ),
        );
      }
      
      // 쓰기 파일 카운터
      if (note.writingFileCount > 0) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFileCountBadge(
              Icons.edit,
              note.writingFileCount,
              AppConfig.maxTextFilesPerNoteForFree + 
              AppConfig.maxHandwritingFilesPerNoteForFree,
              Colors.blue,
            ),
          ),
        );
      }
    } else {
      // 전체 통계 표시
      final stats = noteProvider.usageStats;
      final totalNotes = stats['totalNotes'] ?? 0;
      
      if (totalNotes > 0) {
        actions.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFileCountBadge(
              Icons.folder,
              totalNotes,
              AppConfig.maxNotesForFree,
              Colors.green,
            ),
          ),
        );
      }
    }
    
    return actions;
  }
  
  // 파일 카운터 배지 위젯
  Widget _buildFileCountBadge(
    IconData icon,
    int count,
    int maxCount,
    Color color,
  ) {
    final isLimitReached = _subscriptionType == 'free' && count >= maxCount;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLimitReached ? Colors.orange : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLimitReached ? Colors.orange : color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isLimitReached ? Colors.white : color,
          ),
          const SizedBox(width: 4),
          Text(
            _subscriptionType == 'free' ? '$count/$maxCount' : '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isLimitReached ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}