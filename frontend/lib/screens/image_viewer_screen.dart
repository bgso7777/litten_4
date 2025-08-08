import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:html' show AnchorElement, document;

class ImageViewerScreen extends StatefulWidget {
  final String? imageUrl;      // 웹에서 사용 (Blob URL)
  final String? imagePath;     // 네이티브에서 사용 (파일 경로)
  final String fileName;
  final bool isWeb;
  
  const ImageViewerScreen({
    super.key,
    this.imageUrl,
    this.imagePath,
    required this.fileName,
    required this.isWeb,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _validateImage();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _shareImage,
            icon: Icon(Icons.share),
            tooltip: '공유',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('정보'),
                  ],
                ),
              ),
              if (widget.isWeb)
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('다운로드'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      backgroundColor: Colors.black,
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              '이미지 로딩 중...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              '이미지를 불러올 수 없습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('돌아가기'),
            ),
          ],
        ),
      );
    }
    
    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: _buildImage(),
      ),
    );
  }
  
  Widget _buildImage() {
    if (widget.isWeb && widget.imageUrl != null) {
      // 웹에서는 Blob URL 사용
      return Image.network(
        widget.imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _errorMessage = '웹 이미지 로드 실패: $error';
              _isLoading = false;
            });
          });
          return SizedBox.shrink();
        },
      );
    } else if (!widget.isWeb && widget.imagePath != null) {
      // 네이티브에서는 파일 경로 사용
      return Image.file(
        File(widget.imagePath!),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _errorMessage = '파일 이미지 로드 실패: $error';
              _isLoading = false;
            });
          });
          return SizedBox.shrink();
        },
      );
    } else {
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 48,
                color: Colors.grey[400],
              ),
              SizedBox(height: 8),
              Text(
                '이미지 경로가 없습니다',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  // 이미지 유효성 검사
  Future<void> _validateImage() async {
    try {
      if (widget.isWeb) {
        if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
          throw Exception('웹 이미지 URL이 제공되지 않았습니다');
        }
        if (!widget.imageUrl!.startsWith('blob:') && !widget.imageUrl!.startsWith('http')) {
          throw Exception('유효하지 않은 이미지 URL입니다');
        }
      } else {
        if (widget.imagePath == null || widget.imagePath!.isEmpty) {
          throw Exception('이미지 파일 경로가 제공되지 않았습니다');
        }
        final file = File(widget.imagePath!);
        if (!await file.exists()) {
          throw Exception('이미지 파일이 존재하지 않습니다: ${widget.imagePath}');
        }
      }
      
      // 유효성 검사 통과
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // 메뉴 액션 처리
  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        _showImageInfo();
        break;
      case 'download':
        _downloadImage();
        break;
    }
  }
  
  // 이미지 정보 다이얼로그
  void _showImageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('이미지 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('파일명', widget.fileName),
            _buildInfoRow('타입', widget.isWeb ? '웹 이미지' : '로컬 이미지'),
            if (widget.isWeb && widget.imageUrl != null)
              _buildInfoRow('URL', widget.imageUrl!.length > 50 
                  ? '${widget.imageUrl!.substring(0, 50)}...' 
                  : widget.imageUrl!),
            if (!widget.isWeb && widget.imagePath != null)
              _buildInfoRow('경로', widget.imagePath!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
  
  // 이미지 공유
  void _shareImage() {
    // TODO: 실제 공유 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('공유 기능은 추후 구현 예정입니다'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // 이미지 다운로드 (웹 전용)
  void _downloadImage() {
    if (!widget.isWeb || widget.imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('다운로드할 수 없습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // 웹에서 다운로드 트리거
      if (kIsWeb) {
        final anchor = document.createElement('a') as AnchorElement;
        anchor.href = widget.imageUrl!;
        anchor.download = widget.fileName;
        anchor.click();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('다운로드가 시작되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('다운로드 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}