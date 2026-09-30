/// `Card / Shelf` from the wireframe (U64ViG), on a phone.
///
/// A shelf is a real shop counter in a real ward, and the three things a buyer wants from this card
/// are whether it is open, how far it is, and how much it holds. The address is what gets him there;
/// the landmark is what actually gets him there, so it is not truncated away.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../../models.dart';

class ShelfCard extends StatelessWidget {
  const ShelfCard({super.key, required this.shelf, this.onBrowse});

  final Shelf shelf;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: UkoColors.bg,
          borderRadius: BorderRadius.circular(UkoRadius.md),
          border: Border.all(color: UkoColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: Container(
                color: UkoColors.surface2,
                child: shelf.image.isEmpty
                    ? const Icon(Icons.storefront_outlined,
                        color: UkoColors.borderStrong, size: 28)
                    : Image.network(shelf.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.storefront_outlined,
                            color: UkoColors.borderStrong, size: 28)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(shelf.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: UkoColors.ink)),
                      ),
                      UkoChip(shelf.isOpen ? 'Open' : 'Closed',
                          tone: shelf.isOpen ? UkoTone.success : UkoTone.neutral),
                    ],
                  ),
                  if (shelf.where.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(shelf.where,
                        style: const TextStyle(
                            fontSize: 11.5, height: 1.4, color: UkoColors.ink2)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (shelf.hours.isNotEmpty) ...[
                        const Icon(Icons.schedule, size: 12, color: UkoColors.muted),
                        const SizedBox(width: 4),
                        Text(shelf.hours,
                            style: const TextStyle(fontSize: 10.5, color: UkoColors.muted)),
                        const SizedBox(width: 10),
                      ],
                      if (shelf.itemsCount > 0) ...[
                        const Icon(Icons.inventory_2_outlined, size: 12, color: UkoColors.muted),
                        const SizedBox(width: 4),
                        Text('${shelf.itemsCount} items',
                            style: const TextStyle(fontSize: 10.5, color: UkoColors.muted)),
                      ],
                      const Spacer(),
                      if (shelf.distanceKm != null)
                        Text(km(shelf.distanceKm),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: UkoColors.primary)),
                    ],
                  ),
                  if (onBrowse != null) ...[
                    const SizedBox(height: 12),
                    AsyncButton(
                      label: 'See what is on it',
                      outlined: true,
                      onPressed: () async => onBrowse!(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
