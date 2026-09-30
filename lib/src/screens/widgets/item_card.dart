/// `Card / Product` from the wireframe (B2OKp), reflowed from 232 wide to the two-column phone grid
/// M1 and M2 use (175 each, 12 apart, inside a 362 body).
///
/// The one thing this card must never omit is **why the item can be trusted**. UKO's whole proposition
/// is that a named shelf host looked at the thing; an item that is not on a shelf is an ordinary
/// stranger-to-stranger sale with no escrow behind it. Both are allowed to exist in the same grid, so
/// the card says which every time, rather than only badging the good case.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../../models.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.item, required this.onOpen});

  final ItemCard item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final off = item.discountPct;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(UkoRadius.md),
      child: Container(
        decoration: BoxDecoration(
          color: UkoColors.bg,
          borderRadius: BorderRadius.circular(UkoRadius.md),
          border: Border.all(color: UkoColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.38,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: UkoColors.surface2,
                    child: item.image.isEmpty
                        ? const Icon(Icons.image_outlined, color: UkoColors.borderStrong, size: 30)
                        : Image.network(item.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined,
                                color: UkoColors.borderStrong, size: 30)),
                  ),
                  if (off != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _tag('−$off%', UkoColors.secondary),
                    ),
                  if (item.boosted)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _tag('Boosted', UkoColors.primary),
                    ),
                  if (item.soldOut)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: const Text('Sold out',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // `Badge / Verified` in the wireframe — and its honest opposite.
                  Row(
                    children: [
                      Icon(
                        item.isVerified ? Icons.verified : Icons.person_outline,
                        size: 12,
                        color: item.isVerified ? UkoColors.success : UkoColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.trust,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: item.isVerified ? UkoColors.success : UkoColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.35, color: UkoColors.ink),
                  ),
                  const SizedBox(height: 6),
                  if (item.ratingCount > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, size: 11, color: UkoColors.warning),
                        const SizedBox(width: 3),
                        Text('${item.rating}',
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w700, color: UkoColors.ink)),
                        const SizedBox(width: 4),
                        Text('(${item.ratingCount})',
                            style: const TextStyle(fontSize: 10, color: UkoColors.muted)),
                      ],
                    )
                  else
                    const Text('No reviews yet',
                        style: TextStyle(fontSize: 10, color: UkoColors.muted)),
                  const SizedBox(height: 6),
                  Text(
                    item.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800, color: UkoColors.ink),
                  ),
                  if (item.oldAmount != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      ksh(item.oldAmount!),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: UkoColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (item.ward.isNotEmpty) item.ward,
                      if (item.soldCount > 0) '${item.soldCount} sold',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: UkoColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color colour) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}

/// The two-column grid M1's "Trending" and M2's results both use.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.items, required this.onOpen});

  final List<ItemCard> items;
  final void Function(ItemCard) onOpen;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // 175 wide × 334 tall in the wireframe's grid.
          childAspectRatio: 175 / 334,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => ProductCard(item: items[i], onOpen: () => onOpen(items[i])),
      );
}
