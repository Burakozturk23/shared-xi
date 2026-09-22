import 'dart:async';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/rewarded_ad_models.dart';
import '../services/rewarded_ads_gateway.dart';
import '../services/rewarded_ads_player.dart';
import '../services/rewarded_ad_analytics.dart';
import 'pitch_ui.dart';

/// Optional result-only action. Game replay/back buttons live outside this card.
class RewardedCoinCard extends StatefulWidget {
  const RewardedCoinCard({
    super.key,
    required this.placement,
    this.gateway,
    this.player,
    this.pollInterval = const Duration(seconds: 2),
  });
  final String placement;
  final RewardedAdsGateway? gateway;
  final RewardedAdsPlayer? player;
  final Duration pollInterval;
  @override
  State<RewardedCoinCard> createState() => _RewardedCoinCardState();
}

class _RewardedCoinCardState extends State<RewardedCoinCard> {
  static bool _watchInProgress = false;
  late final _gateway = widget.gateway ?? FirebaseRewardedAdsGateway();
  late final _player = widget.player ?? AdMobRewardedAdsPlayer();
  RewardedAdStatus? _status;
  String? _ticketId;
  String? _requestId;
  String? _message;
  bool _busy = false;
  bool _test = false;
  bool _offeredLogged = false;
  @override
  void initState() {
    super.initState();
    if (_player.supported) unawaited(_refresh());
  }

  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  Future<void> _refresh() async {
    _update(() => _busy = true);
    try {
      final test = await _player.testMode;
      final status = await _gateway.status(ticketId: _ticketId);
      if (status.enabled && !_offeredLogged) {
        _offeredLogged = true;
        unawaited(
          RewardedAdAnalytics.log('reward_ad_offered', widget.placement),
        );
      }
      _update(() {
        _test = test;
        _status = status;
      });
      if (status.ticket != null) {
        final ticket = status.ticket!;
        if (ticket.credited || ticket.verified) {
          _finish(ticket);
        } else if (ticket.status == 'pending') {
          _update(() {
            _ticketId = ticket.id;
            _message =
                'Ödül doğrulanıyor. Oyuna devam edebilirsin; doğrulama tamamlanınca bonusun kaydedilir.';
          });
        } else {
          _ticketId = null;
          _requestId = null;
        }
      }
    } catch (_) {
      _update(
        () => _message =
            'Bonus bilgisi alınamadı. Oyuna devam edebilir veya tekrar deneyebilirsin.',
      );
    } finally {
      _update(() => _busy = false);
    }
  }

  void _finish(RewardedAdTicket ticket) {
    _update(() {
      _message = ticket.credited
          ? '${ticket.amount} Link Coin cüzdanına eklendi.'
          : '${ticket.amount} Link Coin kaydedildi. Bu misafir hesabını Google’a bağlayınca cüzdanına aktarılır.';
      _ticketId = null;
      _requestId = null;
    });
  }

  Future<void> _poll(RewardedAdTicket ticket) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final status = await _gateway.status(ticketId: ticket.id);
      _update(() => _status = status);
      if (status.ticket?.credited == true || status.ticket?.verified == true) {
        _finish(status.ticket!);
        if (!status.pro) {
          unawaited(
            RewardedAdAnalytics.log(
              'reward_ad_completed',
              widget.placement,
              reward: status.ticket!.amount,
            ),
          );
        }
        if (status.ticket!.credited) {
          unawaited(
            RewardedAdAnalytics.coinEarned(
              widget.placement,
              status.ticket!.amount,
              pro: status.pro,
            ),
          );
        }
        return;
      }
      if (!mounted) return; // the server retains and settles this independently
      await Future<void>.delayed(widget.pollInterval);
    }
    _update(
      () => _message =
          'Doğrulama bekleniyor. Oyuna devam edebilirsin; tekrar reklam izlemen gerekmiyor.',
    );
  }

  Future<void> _watch() async {
    if (_busy || _watchInProgress || _status == null) return;
    _watchInProgress = true;
    _update(() {
      _busy = true;
      _message = 'Bonus hazırlanıyor…';
    });
    LoadedRewardedAd? ad;
    RewardedAdTicket? ticket;
    var earned = false;
    try {
      final fresh = await _gateway.status();
      _update(() => _status = fresh);
      if (fresh.ticket?.status == 'pending') {
        _update(() {
          _ticketId = fresh.ticket!.id;
          _message =
              'Önceki reklamın doğrulaması bekleniyor. Tekrar reklam izlemen gerekmiyor.';
        });
        return;
      }
      if (!fresh.enabled) throw StateError('Bonuslar şu anda kapalı.');
      final testing = _test && !fresh.pro;
      if (!testing && fresh.remaining < 1) {
        throw StateError('Bugünkü bonusların tamamlandı.');
      }
      if (!fresh.pro) {
        if (!testing && fresh.testingOnly) {
          throw StateError('Reklam bağlantısı henüz hazır değil.');
        }
        _update(() => _message = 'Reklam yükleniyor…');
        ad = await _player.load();
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      if (!testing) {
        _requestId ??= List.generate(
          16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        ticket = await _gateway.prepare(widget.placement, _requestId!);
        _ticketId = ticket.id;
        if (ticket.credited || ticket.verified) {
          // Includes Pro and retries whose original response was interrupted.
          await _poll(ticket);
          return;
        }
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) {
        if (ticket != null) await _gateway.cancel(ticket.id);
        return;
      }
      earned = await ad!.show(
        ticket,
        onStarted: () {
          unawaited(
            RewardedAdAnalytics.log('reward_ad_started', widget.placement),
          );
        },
      );
      if (testing) {
        _update(
          () => _message = earned
              ? 'Test reklamı tamamlandı. Bu önizlemede gerçek coin verilmez.'
              : 'Test reklamı kapatıldı. Oyuna devam edebilirsin.',
        );
      } else if (earned) {
        _update(
          () => _message = 'Reklam tamamlandı. Ödül sunucuda doğrulanıyor…',
        );
        await _poll(ticket!);
      } else {
        await _gateway.cancel(ticket!.id);
        _ticketId = null;
        _requestId = null;
        _update(
          () => _message = 'Reklam tamamlanmadı. Bonus hakkın kullanılmadı.',
        );
      }
    } catch (error) {
      if (!earned && ticket != null) {
        try {
          await _gateway.cancel(ticket.id);
        } catch (_) {}
        _ticketId = null;
        _requestId = null;
      }
      _update(
        () => _message = earned
            ? 'Doğrulama bekleniyor. Doğrulanan bonusun bağlantı kurulunca kaydedilir.'
            : error is FirebaseFunctionsException
            ? (error.message ?? 'Bonus şu anda alınamıyor. Tekrar dene.')
            : error is StateError
            ? error.message.toString()
            : 'Reklam yüklenemedi. Daha sonra tekrar dene.',
      );
      unawaited(
        RewardedAdAnalytics.log(
          'reward_ad_failed',
          widget.placement,
          reason: earned ? 'verification_pending' : 'unavailable',
        ),
      );
    } finally {
      try {
        await ad?.dispose();
      } catch (_) {
        // A native cleanup failure must not hold the global watch lock.
      } finally {
        _watchInProgress = false;
        _update(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_player.supported) return const SizedBox.shrink();
    final s = _status;
    if (s != null && !s.enabled && _ticketId == null) {
      return const SizedBox.shrink();
    }
    final testing = _test && s?.pro != true;
    final hasPending = _ticketId != null;
    final ready =
        s != null && (testing || s.pro || !s.testingOnly) && s.remaining > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.redeem_outlined, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s?.pro == true ? 'Pro günlük bonusu' : 'İsteğe bağlı bonus',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              testing
                  ? 'Test reklamı · Gerçek coin verilmez'
                  : s == null
                  ? 'Bonus bilgisi yükleniyor…'
                  : '${s.amount} Link Coin · Bugün ${s.remaining}/${s.dailyLimit} bonus kaldı',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_message!)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : hasPending || s == null
                    ? _refresh
                    : (ready || testing)
                    ? _watch
                    : null,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        s?.pro == true
                            ? Icons.redeem_outlined
                            : Icons.play_circle_outline,
                      ),
                label: Text(
                  _busy
                      ? 'Bekleniyor…'
                      : hasPending
                      ? 'Ödülü kontrol et'
                      : s == null
                      ? 'Tekrar dene'
                      : testing
                      ? 'Test reklamını izle'
                      : s.pro
                      ? '${s.amount} Link Coin al'
                      : s.testingOnly
                      ? 'Bonus henüz hazır değil'
                      : s.remaining < 1
                      ? 'Bugünkü bonuslar tamamlandı'
                      : 'Reklam izle · ${s.amount} Link Coin',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
