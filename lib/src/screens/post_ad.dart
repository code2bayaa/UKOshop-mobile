/// M7 · Post Ad.
///
/// The wireframe has six sections; on a phone they are four, because "price & variants" and "photos"
/// belong next to the thing they describe and "boost" is a purchase decision that does not belong in
/// the middle of writing an advert.
///
/// **Photos are not optional here in practice.** A shelf host is about to check this item against what
/// the seller wrote, and a buyer is about to part with money for it; an advert with no picture fails
/// both. The camera is on the phone, which is most of the reason posting an ad belongs on one.
///
/// What this screen deliberately does *not* do is decide anything about shelves or money. Which shelf
/// takes the item, what UKO charges to list it, whether a rider has to fetch it — all of that is the
/// API's, and it is worked out after the ad exists.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../auth.dart';
import '../config.dart';

class PostAdScreen extends StatefulWidget {
  const PostAdScreen({super.key, required this.api, required this.auth});

  final ShopApi api;
  final ShopAuth auth;

  @override
  State<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends State<PostAdScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _oldPrice = TextEditingController();
  final _stock = TextEditingController(text: '1');
  final _weight = TextEditingController();
  final _ward = TextEditingController();

  String _condition = 'New';
  List<TakenPhoto> _photos = const [];
  String _error = '';
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _ward.text = widget.auth.me?.ward ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _brand,
      _price,
      _oldPrice,
      _stock,
      _weight,
      _ward
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready =>
      _title.text.trim().length >= 4 &&
      _description.text.trim().length >= 10 &&
      (double.tryParse(_price.text.trim()) ?? 0) > 0 &&
      _photos.isNotEmpty;

  /// What is still missing, in the order it is worth fixing. Better than a disabled button with no
  /// explanation.
  String get _missing {
    if (_title.text.trim().length < 4) return 'Give it a title a buyer would search for.';
    if (_description.text.trim().length < 10) {
      return 'Describe it — condition, size, what is included.';
    }
    if ((double.tryParse(_price.text.trim()) ?? 0) <= 0) return 'Set a price.';
    if (_photos.isEmpty) return 'Add at least one photo.';
    return '';
  }

  Future<void> _post() async {
    setState(() {
      _posting = true;
      _error = '';
    });
    try {
      final amount = double.parse(_price.text.trim());
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'brand': _brand.text.trim(),
        'condition': _condition.toLowerCase(),
        'min_amount': amount,
        'max_amount': amount,
        if ((double.tryParse(_oldPrice.text.trim()) ?? 0) > 0)
          'old_amount': double.parse(_oldPrice.text.trim()),
        'stock': int.tryParse(_stock.text.trim()) ?? 1,
        if ((double.tryParse(_weight.text.trim()) ?? 0) > 0)
          'weight_kg': double.parse(_weight.text.trim()),
        'ward': _ward.text.trim(),
        'county': widget.auth.me?.county ?? '',
        'images': _photos.map((p) => p.path).toList(),
      };
      final created = await widget.api.postItem(body);
      if (!mounted) return;
      Navigator.pop(context);
      showUkoMessage(
        context,
        'Posted · ${asText(created['title'], _title.text.trim())} is live. Take it to a shelf to get '
        'it verified.',
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Post an ad')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const UkoNotice(
              'Write it, then take it to a shelf in your ward. A host checks it against what you '
              'wrote — that check is what lets buyers pay through UKO instead of meeting a stranger.',
              tone: UkoTone.primary,
              title: 'How selling works',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 14),

            UkoPanel(
              title: 'What are you selling?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Chronograph leather watch, sapphire glass, 42mm',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Condition, size, what is included, anything a buyer would ask.',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _brand,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Brand (optional)'),
                  ),
                  const SizedBox(height: 14),
                  const Text('CONDITION',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: UkoColors.muted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in const ['New', 'Used'])
                        ChoiceChip(
                          label: Text(c, style: const TextStyle(fontSize: 12)),
                          selected: _condition == c,
                          onSelected: (_) => setState(() => _condition = c),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            UkoPanel(
              title: 'Price and stock',
              subtitle: 'UKO keeps ${Config.sellerCommissionPct}% when it sells — 15 points to the '
                  'shelf that holds and checks it, 5 to UKO.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Price', prefixText: 'KSh '),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _oldPrice,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Was (optional)', prefixText: 'KSh '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'How many'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _weight,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Weight (kg)', hintText: 'For delivery'),
                        ),
                      ),
                    ],
                  ),
                  if ((double.tryParse(_price.text.trim()) ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    UkoNotice(
                      'At ${ksh(double.parse(_price.text.trim()))} you would receive about '
                      '${ksh(double.parse(_price.text.trim()) * (100 - Config.sellerCommissionPct) / 100)} '
                      'per sale.',
                      tone: UkoTone.neutral,
                      icon: Icons.calculate_outlined,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            UkoPanel(
              title: 'Photos',
              subtitle: 'The host checks the item against these, and the buyer decides from them.',
              child: PhotoField(
                api: widget.api.client,
                photos: _photos,
                onChanged: (p) => setState(() => _photos = p),
                label: 'Photos of the item',
                hint: 'Every angle, and anything that is not perfect. Honest photos get fewer '
                    'returns.',
                max: 8,
                role: 'item',
              ),
            ),
            const SizedBox(height: 14),

            UkoPanel(
              title: 'Where it is',
              subtitle: 'Your ward decides which shelves can take it.',
              child: TextField(
                controller: _ward,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ward'),
              ),
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 14),
              UkoNotice(_error, tone: UkoTone.danger),
            ],

            const SizedBox(height: 18),
            AsyncButton(
              label: 'Post this ad',
              icon: Icons.publish_outlined,
              enabled: _ready && !_posting,
              onPressed: _ready && !_posting ? _post : null,
            ),
            if (!_ready) ...[
              const SizedBox(height: 8),
              Text(_missing,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: UkoColors.muted)),
            ],
          ],
        ),
      );
}
