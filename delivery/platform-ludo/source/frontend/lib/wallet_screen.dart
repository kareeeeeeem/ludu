import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';

String egp(dynamic minor) {
  final value = minor is int ? minor : (minor as num?)?.toInt() ?? 0;
  final absolute = value.abs();
  return '${value < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')} EGP';
}

int? parseEgp(String input) {
  final text = input.trim();
  if (!RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final major = int.tryParse(parts.first);
  if (major == null || major > 10000000) return null;
  final minor = parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0;
  final result = major * 100 + minor;
  return result > 0 && result <= 1000000000 ? result : null;
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.api});
  final Api api;
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<List<dynamic>> activity;
  late Future<Map<String, dynamic>> config;
  bool sending = false;

  Future<Map<String, dynamic>> stableRequest(
    String key,
    Map<String, dynamic> fields,
  ) async {
    final saved = await widget.api.storage.read(key: key);
    Map<String, dynamic>? previous;
    try {
      if (saved != null) {
        previous = Map<String, dynamic>.from(jsonDecode(saved));
      }
    } catch (_) {
      previous = null;
    }
    final previousFields = previous?['fields'];
    final id =
        previousFields != null &&
                jsonEncode(previousFields) == jsonEncode(fields)
            ? previous!['requestId'] as String
            : const Uuid().v4();
    await widget.api.storage.write(
      key: key,
      value: jsonEncode({'fields': fields, 'requestId': id}),
    );
    return {...fields, 'requestId': id};
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    config = widget.api
        .call('/wallet/config')
        .then((v) => Map<String, dynamic>.from(v));
    activity = Future.wait([
      widget.api.call('/wallet/transactions'),
      widget.api.call('/wallet/deposits'),
      widget.api.call('/wallet/withdrawals'),
    ]);
  }

  Future<Map<String, String>?> fields(
    String title,
    List<String> labels, {
    String? message,
  }) async {
    final controllers = {
      for (final label in labels) label: TextEditingController(),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(message),
                    ),
                  for (final label in labels)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: controllers[label],
                        keyboardType:
                            label.contains('Amount') || label.contains('phone')
                                ? TextInputType.phone
                                : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: label,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(ctx, {
                      for (final entry in controllers.entries)
                        entry.key: entry.value.text.trim(),
                    }),
                child: const Text('Submit'),
              ),
            ],
          ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
    return result;
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> submit(Future<void> Function() task) async {
    if (sending) return;
    setState(() => sending = true);
    try {
      await task();
      await widget.api.refresh();
      if (mounted) setState(reload);
    } catch (e) {
      message(e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> deposit() async {
    Map<String, dynamic> settings;
    try {
      settings = Map<String, dynamic>.from(
        await widget.api.call('/wallet/config'),
      );
    } catch (e) {
      message('Could not refresh receiving number: $e');
      return;
    }
    final receiving = settings['receivingPhone'] as String?;
    if (receiving == null || receiving.isEmpty) {
      message('Vodafone Cash receiving number is not configured yet.');
      return;
    }
    final input = await fields(
      'Vodafone Cash deposit request',
      [
        'Amount (EGP)',
        'Sender phone',
        'Transfer reference',
        'Transfer details (optional)',
      ],
      message:
          settings['localDemo'] == true
              ? 'LOCAL DEMO ONLY: $receiving is not a phone number. Do not send any real money. Use a test reference; admin review credits local test value only.'
              : 'Transfer to $receiving externally, then submit your actual transfer reference. A request is not a credit; an admin must verify receipt.',
    );
    if (input == null) return;
    final amount = parseEgp(input['Amount (EGP)'] ?? '');
    final phone = input['Sender phone'] ?? '';
    final reference = input['Transfer reference'] ?? '';
    if (amount == null ||
        !RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone) ||
        reference.length < 4) {
      message('Check amount, Egyptian mobile number, and transfer reference.');
      return;
    }
    await submit(() async {
      const key = 'pendingDepositRequest';
      final body = await stableRequest(key, {
        'amountMinor': amount,
        'senderPhone': phone,
        'transferReference': reference,
        'note': input['Transfer details (optional)'] ?? '',
      });
      final result = await widget.api.call(
        '/wallet/deposits',
        method: 'POST',
        body: body,
      );
      await widget.api.storage.delete(key: key);
      message(
        'Deposit request ${result['status']}. Your balance has not been credited.',
      );
    });
  }

  Future<void> withdraw() async {
    final input = await fields(
      'Vodafone Cash withdrawal request',
      ['Amount (EGP)', 'Vodafone Cash phone'],
      message:
          'Funds will be reserved. An admin must send the transfer manually and mark it paid.',
    );
    if (input == null) return;
    final amount = parseEgp(input['Amount (EGP)'] ?? '');
    final phone = input['Vodafone Cash phone'] ?? '';
    if (amount == null || !RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone)) {
      message('Enter a valid amount and Egyptian mobile number.');
      return;
    }
    await submit(() async {
      const key = 'pendingWithdrawalRequest';
      final body = await stableRequest(key, {
        'amountMinor': amount,
        'phone': phone,
      });
      final result = await widget.api.call(
        '/wallet/withdrawals',
        method: 'POST',
        body: body,
      );
      await widget.api.storage.delete(key: key);
      message('Withdrawal ${result['status']}. This does not mean paid.');
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.api,
    builder:
        (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Your wallet',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              egp(widget.api.user?['availableMinor']),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const Text('Available'),
            Text('${egp(widget.api.user?['reservedMinor'])} reserved'),
            const SizedBox(height: 18),
            FutureBuilder<Map<String, dynamic>>(
              future: config,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Configuration unavailable: ${snapshot.error}');
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          sending || snapshot.data!['depositAvailable'] != true
                              ? null
                              : deposit,
                      icon: const Icon(Icons.add),
                      label: const Text('Deposit request · Vodafone Cash'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF126C58),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (snapshot.data!['depositAvailable'] != true)
                      const Text(
                        'Deposit requests unavailable until a receiving number is configured.',
                      ),
                    if (snapshot.data!['localDemo'] == true)
                      const Text(
                        'LOCAL DEMO MODE · no real Vodafone Cash transfer or verified funds.',
                      ),
                    OutlinedButton.icon(
                      onPressed: sending ? null : withdraw,
                      icon: const Icon(Icons.outbox),
                      label: const Text('Withdrawal request · Vodafone Cash'),
                    ),
                    const Text(
                      'External Vodafone Cash transfers and verification are manual in this release.',
                    ),
                  ],
                );
              },
            ),
            if (sending) const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Text('ACTIVITY', style: Theme.of(context).textTheme.titleMedium),
            FutureBuilder<List<dynamic>>(
              future: activity,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text('${snapshot.error}'),
                      TextButton(
                        onPressed: () => setState(reload),
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final transactions = snapshot.data![0] as List;
                final deposits = snapshot.data![1] as List;
                final withdrawals = snapshot.data![2] as List;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TRANSACTIONS'),
                    if (transactions.isEmpty)
                      const ListTile(title: Text('No transactions yet')),
                    for (final item in transactions)
                      ListTile(
                        title: Text(
                          '${item['type']} · ${egp(item['amountMinor'])}',
                        ),
                        subtitle: Text(
                          '${item['status']} · ${item['createdAt']}\n${item['reference']}',
                        ),
                      ),
                    const Text('DEPOSIT REQUESTS'),
                    if (deposits.isEmpty)
                      const ListTile(title: Text('No deposit requests')),
                    for (final item in deposits)
                      ListTile(
                        title: Text(
                          '${egp(item['amountMinor'])} · ${item['status']}',
                        ),
                        subtitle: Text(
                          '${item['transferReference']} · ${item['createdAt']}',
                        ),
                      ),
                    const Text('WITHDRAWAL REQUESTS'),
                    if (withdrawals.isEmpty)
                      const ListTile(title: Text('No withdrawal requests')),
                    for (final item in withdrawals)
                      ListTile(
                        title: Text(
                          '${egp(item['amountMinor'])} · ${item['status']}',
                        ),
                        subtitle: Text(
                          '${item['phone']} · ${item['createdAt']}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
  );
}
