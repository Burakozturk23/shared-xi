import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/community_models.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';

class CommunityCenterPage extends StatefulWidget {
  const CommunityCenterPage({super.key});

  @override
  State<CommunityCenterPage> createState() => _CommunityCenterPageState();
}

class _CommunityCenterPageState extends State<CommunityCenterPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _modeController = TextEditingController();

  late final TabController _tabController;

  CommunityRequestCategory _category = CommunityRequestCategory.suggestion;
  List<CommunityRequest> _requests = const <CommunityRequest>[];

  bool _booting = true;
  bool _loadingHistory = false;
  bool _submitting = false;
  String? _bootError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _modeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await AuthService.ensureSignedIn();
      await _loadRequests(showSpinner: false);
    } catch (error) {
      _bootError = _friendlyError(error);
    }

    if (!mounted) return;
    setState(() => _booting = false);
  }

  Future<void> _loadRequests({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _loadingHistory = true;
        _historyError = null;
      });
    }

    try {
      final items = await CommunityService.listMine();

      if (!mounted) return;
      setState(() {
        _requests = items;
        _historyError = null;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = _friendlyError(error);
        _loadingHistory = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _submitting = true);

    try {
      await CommunityService.submit(
        category: _category,
        subject: _subjectController.text,
        message: _messageController.text,
        contextTag: 'community_center',
        modeId: _showsModeField ? _modeController.text : '',
      );

      if (!mounted) return;

      setState(() {
        _submitting = false;
        _subjectController.clear();
        _messageController.clear();
        _modeController.clear();
      });

      await _loadRequests(showSpinner: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Talebin alındı. Durumunu Taleplerim sekmesinden takip edebilirsin.',
          ),
        ),
      );

      _tabController.animateTo(1);
    } catch (error) {
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  bool get _showsModeField {
    return _category == CommunityRequestCategory.bugReport ||
        _category == CommunityRequestCategory.matchmakingIssue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Topluluk Merkezi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Yeni Talep'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Taleplerim'),
          ],
        ),
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : _bootError != null
          ? _BootError(
              message: _bootError!,
              onRetry: () {
                setState(() {
                  _booting = true;
                  _bootError = null;
                });
                _bootstrap();
              },
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildSubmitTab(), _buildHistoryTab()],
            ),
    );
  }

  Widget _buildSubmitTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        _IntroCard(
          accountLabel: AuthService.isGoogleAccount
              ? 'Google hesabınla gönderiyorsun.'
              : 'Misafir profilinle gönderiyorsun.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Ne hakkında yazıyorsun?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CommunityRequestCategory.values
              .map((category) {
                final selected = category == _category;

                return ChoiceChip(
                  selected: selected,
                  avatar: Icon(_categoryIcon(category), size: 18),
                  label: Text(category.label),
                  onSelected: (_) {
                    if (_submitting) return;
                    setState(() => _category = category);
                  },
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subjectController,
                enabled: !_submitting,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Konu',
                  hintText: 'Kısaca ne olduğunu yaz',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 4) {
                    return 'Konu en az 4 karakter olmalı.';
                  }
                  if (length > 80) {
                    return 'Konu en fazla 80 karakter olabilir.';
                  }
                  return null;
                },
              ),
              if (_showsModeField) ...[
                const SizedBox(height: 6),
                TextFormField(
                  controller: _modeController,
                  enabled: !_submitting,
                  maxLength: 64,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Mod / bağlam (isteğe bağlı)',
                    hintText: 'Örn. Online Grid, Vs Bot, eşleşme ekranı',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageController,
                enabled: !_submitting,
                minLines: 6,
                maxLines: 10,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Mesaj',
                  hintText:
                      'Sorunu, önerini veya ihtiyacını mümkün olduğunca açık anlat.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 10) {
                    return 'Mesaj en az 10 karakter olmalı.';
                  }
                  if (length > 2000) {
                    return 'Mesaj en fazla 2000 karakter olabilir.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Gönderiliyor…' : 'Gönder'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Kötüye kullanımı önlemek için 15 dakikada en fazla 5, '
          'bir günde en fazla 20 talep gönderebilirsin.',
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Başka bir oyuncuyu şikâyet etme ve moderasyon işlemleri bu '
          'formdan ayrı tutulur.',
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null && _requests.isEmpty) {
      return _HistoryError(message: _historyError!, onRetry: _loadRequests);
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 80),
            Icon(Icons.inbox_outlined, size: 56),
            SizedBox(height: 14),
            Text(
              'Henüz talebin yok',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Öneri, hata bildirimi veya yardım talebi gönderdiğinde '
              'durumunu burada görebilirsin.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        itemCount: _requests.length + (_historyError == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _requests.length) {
            return _InlineError(
              message: _historyError!,
              onRetry: _loadRequests,
            );
          }

          return _RequestCard(request: _requests[index]);
        },
      ),
    );
  }

  static IconData _categoryIcon(CommunityRequestCategory category) {
    switch (category) {
      case CommunityRequestCategory.suggestion:
        return Icons.lightbulb_outline_rounded;
      case CommunityRequestCategory.bugReport:
        return Icons.bug_report_outlined;
      case CommunityRequestCategory.help:
        return Icons.help_outline_rounded;
      case CommunityRequestCategory.matchmakingIssue:
        return Icons.sync_problem_rounded;
      case CommunityRequestCategory.feedback:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  static String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'Çok fazla talep gönderdin. Biraz sonra tekrar dene.';
        case 'unauthenticated':
          return 'Oturum hazırlanamadı. Tekrar dene.';
        case 'invalid-argument':
          return 'Gönderim alanlarını kontrol edip tekrar dene.';
        default:
          final message = error.message?.trim() ?? '';
          if (message.isNotEmpty) return message;
      }
    }

    if (error is ArgumentError) {
      final message = error.message?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;
    }

    return 'İşlem tamamlanamadı. İnternet bağlantını kontrol edip tekrar dene.';
  }
}

class _IntroCard extends StatelessWidget {
  final String accountLabel;

  const _IntroCard({required this.accountLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.forum_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Oyunu birlikte geliştirelim',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Öneri, hata, yardım veya eşleşme sorununu buradan iletebilirsin.',
                  ),
                  const SizedBox(height: 7),
                  Text(
                    accountLabel,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final CommunityRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, request.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _categoryIcon(request.category),
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    request.subject,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    request.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              request.category.label,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (request.modeId.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Bağlam: ${request.modeId}',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              request.message,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.35),
            ),
            const SizedBox(height: 12),
            Text(
              _formatTimestamp(request.createdAt),
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(CommunityRequestCategory category) {
    switch (category) {
      case CommunityRequestCategory.suggestion:
        return Icons.lightbulb_outline_rounded;
      case CommunityRequestCategory.bugReport:
        return Icons.bug_report_outlined;
      case CommunityRequestCategory.help:
        return Icons.help_outline_rounded;
      case CommunityRequestCategory.matchmakingIssue:
        return Icons.sync_problem_rounded;
      case CommunityRequestCategory.feedback:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  static Color _statusColor(
    BuildContext context,
    CommunityRequestStatus status,
  ) {
    switch (status) {
      case CommunityRequestStatus.open:
        return Theme.of(context).colorScheme.primary;
      case CommunityRequestStatus.reviewing:
        return Colors.orange;
      case CommunityRequestStatus.resolved:
        return Colors.green;
      case CommunityRequestStatus.closed:
        return Theme.of(context).hintColor;
    }
  }

  static String _formatTimestamp(int milliseconds) {
    if (milliseconds <= 0) return 'Tarih yok';

    final value = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}.${two(value.month)}.${value.year} · '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _BootError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BootError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Topluluk Merkezi açılamadı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final String message;
  final Future<void> Function({bool showSpinner}) onRetry;

  const _HistoryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Talepler yüklenemedi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => onRetry(showSpinner: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final Future<void> Function({bool showSpinner}) onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: () => onRetry(showSpinner: true),
              child: const Text('Yenile'),
            ),
          ],
        ),
      ),
    );
  }
}
