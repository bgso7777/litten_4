import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../config/app_config.dart';

class NoteListItem extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  
  const NoteListItem({
    super.key,
    required this.note,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Icon(
            Icons.folder,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                note.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildFileBadges(context),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.previewText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note.previewText,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatDate(note.updatedAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete' && onDelete != null) {
              onDelete!();
            }
          },
          itemBuilder: (context) => [
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
          child: const Icon(Icons.more_vert),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  Widget _buildFileBadges(BuildContext context) {
    final badges = <Widget>[];
    
    // 오디오 파일 배지
    if (note.audioFileCount > 0) {
      badges.add(_buildFileBadge(
        context,
        Icons.mic,
        note.audioFileCount,
        Colors.red,
      ));
    }
    
    // 쓰기 파일 배지
    if (note.writingFileCount > 0) {
      badges.add(_buildFileBadge(
        context,
        Icons.edit,
        note.writingFileCount,
        Colors.blue,
      ));
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges
          .expand((badge) => [badge, const SizedBox(width: 4)])
          .take(badges.length * 2 - 1)
          .toList(),
    );
  }
  
  Widget _buildFileBadge(
    BuildContext context,
    IconData icon,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      // 오늘
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // 어제
      return '어제';
    } else if (difference.inDays < 7) {
      // 일주일 이내
      return '${difference.inDays}일 전';
    } else {
      // 그 이상
      return '${date.month}/${date.day}';
    }
  }
}