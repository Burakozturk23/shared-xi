import 'package:flutter/material.dart';

import '../models/economy_models.dart';
import '../services/economy_service.dart';

class WalletBalanceChip extends StatelessWidget {
  final bool compact;

  const WalletBalanceChip({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EconomyWallet>(
      stream: EconomyService.watchWallet(),
      builder: (context, snapshot) {
        final wallet = snapshot.data ?? EconomyWallet.empty;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 8,
            vertical: compact ? 8 : 6,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 12,
              vertical: compact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  size: compact ? 18 : 20,
                  color: const Color(0xFFFFB300),
                ),
                const SizedBox(width: 5),
                Text(
                  '${wallet.coins}',
                  style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
