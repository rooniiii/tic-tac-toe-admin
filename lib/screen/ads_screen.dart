import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/ad_model.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/load_more_button.dart';

/// Manage the advertisements shown in the game with a countdown timer.
///
/// Gestures (each one also has a menu entry and a screen-reader action):
///   * swipe right  -> preview the ad / its image
///   * swipe left   -> delete (with confirmation)
///   * double-tap   -> pause / activate
///   * tap          -> edit
class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  static const int _pageSize = 25;

  final AdService _service = AdService();

  int _limit = _pageSize;
  late Stream<List<AdModel>> _adsStream;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _adsStream = _service.getAds(limit: _limit);
  }

  void _loadMore() {
    setState(() {
      _limit += _pageSize;
      _adsStream = _service.getAds(limit: _limit);
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _error(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _openForm([AdModel? ad]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AdFormDialog(ad: ad, service: _service),
    );
    if (saved == true) {
      _message(ad == null ? 'Ad created.' : 'Ad updated.');
    }
  }

  Future<void> _toggle(AdModel ad) async {
    if (_busyId != null) return;
    setState(() => _busyId = ad.id);
    try {
      await _service.setActive(ad, !ad.active);
      _message(ad.active ? '"${ad.title}" paused.' : '"${ad.title}" is live.');
    } catch (e) {
      _message('Update failed: ${_error(e)}');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<bool> _confirmDelete(AdModel ad) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Delete ad?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          '"${ad.title}" will be removed from the game. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _delete(AdModel ad) async {
    if (!await _confirmDelete(ad)) return;
    try {
      await _service.deleteAd(ad);
      _message('Ad deleted.');
    } catch (e) {
      _message('Delete failed: ${_error(e)}');
    }
  }

  void _preview(AdModel ad) {
    showDialog<void>(
      context: context,
      builder: (_) => _AdPreviewDialog(ad: ad),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _adCard(AdModel ad) {
    final busy = _busyId == ad.id;

    final card = Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ad.active
              ? AppTheme.neonCyan.withValues(alpha: 0.6)
              : Colors.white24,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openForm(ad),
        onDoubleTap: () => _toggle(ad),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ad.hasImage
                      ? Image.network(
                          ad.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                        )
                      : const _ImagePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    if (ad.message.isNotEmpty)
                      Text(
                        ad.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(Icons.timer_outlined, '${ad.countdownSeconds} s',
                            AppTheme.neonYellow),
                        _chip(
                          ad.active ? Icons.play_arrow : Icons.pause,
                          ad.active ? 'Live' : 'Paused',
                          ad.active ? Colors.greenAccent : Colors.white54,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'Ad actions',
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: AppTheme.surface,
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _openForm(ad);
                      case 'preview':
                        _preview(ad);
                      case 'toggle':
                        _toggle(ad);
                      case 'delete':
                        _delete(ad);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'preview', child: Text('Preview')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(ad.active ? 'Pause' : 'Activate'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: 'Ad ${ad.title}, ${ad.active ? 'live' : 'paused'}, '
          '${ad.countdownSeconds} second countdown',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Preview'): () => _preview(ad),
        CustomSemanticsAction(label: ad.active ? 'Pause' : 'Activate'): () =>
            _toggle(ad),
        const CustomSemanticsAction(label: 'Delete'): () => _delete(ad),
      },
      child: Dismissible(
        key: ValueKey('ad-${ad.id}'),
        background: _swipeBackground(
          alignment: Alignment.centerLeft,
          color: AppTheme.neonCyan,
          icon: Icons.image_search,
          label: 'Preview',
        ),
        secondaryBackground: _swipeBackground(
          alignment: Alignment.centerRight,
          color: Colors.redAccent,
          icon: Icons.delete,
          label: 'Delete',
        ),
        // The card always snaps back: the Firestore stream removes deleted
        // ads from the list itself.
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _preview(ad);
          } else {
            await _delete(ad);
          }
          return false;
        },
        child: card,
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.purple,
        icon: const Icon(Icons.add),
        label: const Text('NEW AD'),
      ),
      body: StreamBuilder<List<AdModel>>(
        stream: _adsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load ads: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan),
            );
          }

          final ads = snapshot.data!;
          final live = ads.where((a) => a.active).length;
          final canLoadMore = ads.length >= _limit;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: ads.length + 1 + (canLoadMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _Header(total: ads.length, live: live);
              }
              final i = index - 1;
              if (i == ads.length) {
                return LoadMoreButton(shown: ads.length, onPressed: _loadMore);
              }
              return _adCard(ads[i]);
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int total;
  final int live;

  const _Header({required this.total, required this.live});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total == 0 ? 'No ads yet' : '$total ads • $live live',
            style: const TextStyle(
              color: AppTheme.neonCyan,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live ads play in the game with a countdown before every 3rd '
            'level and as the reward ad for an extra Undo.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tip: swipe right to preview • swipe left to delete • '
            'double-tap to pause or activate.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.purple, AppTheme.neonPink]),
      ),
      child: const Icon(Icons.campaign, color: Colors.white),
    );
  }
}

/// Shows the ad roughly as players will see it.
class _AdPreviewDialog extends StatelessWidget {
  final AdModel ad;

  const _AdPreviewDialog({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.background,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'PREVIEW',
                    style: TextStyle(
                      color: AppTheme.neonYellow,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${ad.countdownSeconds} s countdown',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ad.hasImage
                      ? InteractiveViewer(
                          // Pinch / double-tap-drag to zoom the image.
                          child: Image.network(
                            ad.imageUrl,
                            fit: BoxFit.cover,
                            semanticLabel: ad.title,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                'Image could not be loaded.\nCheck the URL.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ),
                        )
                      : const _ImagePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ad.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.neonCyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (ad.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ad.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Create / edit form.
class _AdFormDialog extends StatefulWidget {
  final AdModel? ad;
  final AdService service;

  const _AdFormDialog({required this.ad, required this.service});

  @override
  State<_AdFormDialog> createState() => _AdFormDialogState();
}

class _AdFormDialogState extends State<_AdFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title =
      TextEditingController(text: widget.ad?.title ?? '');
  late final TextEditingController _message =
      TextEditingController(text: widget.ad?.message ?? '');
  late final TextEditingController _imageUrl =
      TextEditingController(text: widget.ad?.imageUrl ?? '');

  late int _seconds = (widget.ad?.countdownSeconds ?? AdModel.defaultCountdown)
      .clamp(AdModel.minCountdown, AdModel.maxCountdown);
  late bool _active = widget.ad?.active ?? true;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ad = widget.ad;
      if (ad == null) {
        await widget.service.createAd(
          title: _title.text,
          message: _message.text,
          imageUrl: _imageUrl.text,
          countdownSeconds: _seconds,
          active: _active,
        );
      } else {
        await widget.service.updateAd(
          ad,
          title: _title.text,
          message: _message.text,
          imageUrl: _imageUrl.text,
          countdownSeconds: _seconds,
          active: _active,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.ad != null;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      scrollable: true,
      title: Text(
        isEdit ? 'Edit Ad' : 'New Ad',
        style: const TextStyle(color: AppTheme.neonCyan),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                maxLength: AdModel.maxTitleLength,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _message,
                maxLength: AdModel.maxMessageLength,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _imageUrl,
                maxLength: AdModel.maxImageUrlLength,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Image URL (https, optional)',
                  counterText: '',
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return null;
                  final uri = Uri.tryParse(value);
                  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
                    return 'Enter a valid https:// link';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.neonYellow),
                  const SizedBox(width: 8),
                  Text(
                    'Countdown: $_seconds seconds',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  if (_seconds != AdModel.defaultCountdown)
                    TextButton(
                      onPressed: () =>
                          setState(() => _seconds = AdModel.defaultCountdown),
                      child: const Text('Reset to 15'),
                    ),
                ],
              ),
              Slider(
                value: _seconds.toDouble(),
                min: AdModel.minCountdown.toDouble(),
                max: AdModel.maxCountdown.toDouble(),
                divisions: AdModel.maxCountdown - AdModel.minCountdown,
                label: '$_seconds s',
                semanticFormatterCallback: (v) => '${v.round()} seconds',
                onChanged: (v) => setState(() => _seconds = v.round()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Live in the game'),
                subtitle: const Text(
                  'Paused ads are kept but not shown.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'SAVE' : 'CREATE'),
        ),
      ],
    );
  }
}
