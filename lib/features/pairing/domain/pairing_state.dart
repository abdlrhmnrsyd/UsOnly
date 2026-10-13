import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/auth_state.dart';
import '../data/pairing_repository.dart';

final pairingRepositoryProvider = Provider<PairingRepository>((ref) {
  return PairingRepository();
});

class PairingState {
  final bool isLoading;
  final String? activeCode;
  final String? coupleId;
  final DateTime? expiresAt;
  final String? error;
  final String? pairedPartnerUid;

  const PairingState({
    this.isLoading = false,
    this.activeCode,
    this.coupleId,
    this.expiresAt,
    this.error,
    this.pairedPartnerUid,
  });

  PairingState copyWith({
    bool? isLoading,
    String? activeCode,
    String? coupleId,
    DateTime? expiresAt,
    String? error,
    String? pairedPartnerUid,
  }) {
    return PairingState(
      isLoading: isLoading ?? this.isLoading,
      activeCode: activeCode ?? this.activeCode,
      coupleId: coupleId ?? this.coupleId,
      expiresAt: expiresAt ?? this.expiresAt,
      error: error,
      pairedPartnerUid: pairedPartnerUid ?? this.pairedPartnerUid,
    );
  }
}

class PairingNotifier extends Notifier<PairingState> {
  StreamSubscription? _coupleSubscription;

  @override
  PairingState build() {
    ref.onDispose(() {
      _coupleSubscription?.cancel();
    });
    return const PairingState();
  }

  Future<void> createCode() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ref.read(pairingRepositoryProvider).createPairingCode(
            creatorUid: user.uid,
          );

      final coupleId = res['coupleId'] as String;
      final expires = res['expiresAt'] != null ? DateTime.parse(res['expiresAt'] as String) : null;

      state = PairingState(
        isLoading: false,
        activeCode: res['code'] as String?,
        coupleId: coupleId,
        expiresAt: expires,
      );

      // Listen to couple space changes to automatically detect when partner connects!
      _listenToCoupleConnection(coupleId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to generate connection code: ${e.toString()}',
      );
    }
  }

  void _listenToCoupleConnection(String coupleId) {
    _coupleSubscription?.cancel();
    _coupleSubscription = ref
        .read(pairingRepositoryProvider)
        .watchCoupleSpace(coupleId)
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data != null && data['status'] == 'active') {
        final members = List<String>.from(data['memberUids'] as List);
        final currentUid = ref.read(authStateProvider).user?.uid;
        final partner = members.firstWhere((id) => id != currentUid, orElse: () => '');

        ref.read(authStateProvider.notifier).setCoupleId(coupleId);
        state = state.copyWith(pairedPartnerUid: partner);
      }
    });
  }

  Future<void> simulatePartnerConnection() async {
    final coupleId = state.coupleId;
    final user = ref.read(authStateProvider).user;
    if (coupleId == null || user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(pairingRepositoryProvider).simulatePartnerConnection(
            coupleId: coupleId,
            creatorUid: user.uid,
          );
      ref.read(authStateProvider.notifier).setCoupleId(coupleId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal mensimulasikan koneksi: ${e.toString()}',
      );
    }
  }

  Future<bool> redeemCode(String code) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ref.read(pairingRepositoryProvider).redeemPairingCode(
            joiningUid: user.uid,
            rawCode: code,
          );

      final coupleId = res['coupleId'] as String?;
      if (coupleId != null) {
        ref.read(authStateProvider.notifier).setCoupleId(coupleId);
      }

      state = PairingState(
        isLoading: false,
        coupleId: coupleId,
        pairedPartnerUid: res['partnerUid'] as String?,
      );
      return true;
    } catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final pairingStateProvider = NotifierProvider<PairingNotifier, PairingState>(PairingNotifier.new);
