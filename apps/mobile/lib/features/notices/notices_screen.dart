import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/theme/spacing.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  List<dynamic> _notices = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/api/notices');

      if (response.statusCode == 200) {
        setState(() {
          _notices = response.data['data'] ?? [];
        });
      }
    } catch (_) {
      setState(() => _errorMessage = 'Failed to load notices & announcements.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showNoticeDetails(dynamic notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final attachments = notice['attachments'] as List? ?? [];

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: AppSpacing.paddingL,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    notice['title'] ?? 'Notice Announcement',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  AppSpacing.heightS,
                  Text(
                    'Published on: ${notice['createdAt']?.toString().split('T').first ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  AppSpacing.heightL,
                  Text(
                    notice['description'] ?? 'No content details provided.',
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                  if (attachments.isNotEmpty) ...[
                    AppSpacing.heightL,
                    const Divider(),
                    AppSpacing.heightM,
                    const Text(
                      'Attachments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    AppSpacing.heightS,
                    ...attachments.map((fileUrl) {
                      final filename = fileUrl.toString().split('/').last;
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(filename),
                        trailing: const Icon(Icons.download),
                        onTap: () {
                          // Trigger file downloader
                        },
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices & News'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      AppSpacing.heightM,
                      ElevatedButton(
                        onPressed: _fetchNotices,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notices.isEmpty
                  ? const Center(child: Text('No notices posted.'))
                  : RefreshIndicator(
                      onRefresh: _fetchNotices,
                      child: ListView.builder(
                        itemCount: _notices.length,
                        itemBuilder: (context, index) {
                          final notice = _notices[index];
                          final hasAttachments = (notice['attachments'] as List?)?.isNotEmpty ?? false;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: const Icon(Icons.campaign),
                              ),
                              title: Text(
                                notice['title'] ?? 'Notice',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                notice['description'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: hasAttachments ? const Icon(Icons.attach_file, size: 18) : null,
                              onTap: () => _showNoticeDetails(notice),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
