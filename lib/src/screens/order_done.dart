/// The fourth step of the wireframe's stepper: Done.
///
/// One job — tell him the money is held and give him the code he will need. A confirmation screen that
/// only says "thank you" wastes the one moment he is certain to be looking.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../api.dart';
import '../models.dart';
import 'orders_tab.dart';
import 'widgets/chrome.dart';

class OrderDoneScreen extends StatefulWidget {
  const OrderDoneScreen({super.key, required this.api, required this.orderId});

  final ShopApi api;
  final int orderId;

  @override
  State<OrderDoneScreen> createState() => _OrderDoneScreenState();
}

class _OrderDoneScreenState extends State<OrderDoneScreen> {
  Order? _order;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await widget.api.order(widget.orderId);
      if (mounted) setState(() => _order = o);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: const Text('Order placed'), automaticallyImplyLeading: false),
      body: Column(
        children: [
          const CheckoutStepper(step: 3),
          Expanded(
            child: o == null
                ? Center(
                    child: _error.isEmpty
                        ? const CircularProgressIndicator()
                        : UkoEmpty(
                            icon: Icons.error_outline,
                            title: 'Could not load the order',
                            subtitle: _error),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      const Center(
                        child: Icon(Icons.check_circle, size: 56, color: UkoColors.success),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text('Paid · ${o.orderNo}',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800, color: UkoColors.ink)),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'UKO is holding your money until the item is in your hands.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, height: 1.5, color: UkoColors.ink2),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (o.codeToGive.isNotEmpty)
                        UkoPanel(
                          title: 'Keep this code',
                          subtitle: o.codeLabel,
                          borderColor: UkoColors.secondary,
                          child: Text(
                            o.codeToGive.split('').join('  '),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: UkoColors.secondary600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      UkoPanel(
                        title: 'What happens now',
                        child: Text(
                          o.deliveryOption == 'pickup' || o.deliveryOption == 'shelf_run'
                              ? 'The shelf checks and photographs your items, then holds them for you. '
                                  'Bring your ID and read out the code above.'
                              : 'The shelf checks and photographs your items, hands them to a rider, and '
                                  'you can follow him from your orders. Read the code out when he arrives.',
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.55, color: UkoColors.ink2),
                        ),
                      ),
                      const SizedBox(height: 22),
                      AsyncButton(
                        label: 'Follow this order',
                        icon: Icons.local_shipping_outlined,
                        onPressed: () async {
                          await Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    TrackingScreen(api: widget.api, orderId: o.id)),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      AsyncButton(
                        label: 'Back to shopping',
                        outlined: true,
                        onPressed: () async =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
