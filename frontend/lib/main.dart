import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'board.dart';
import 'theme/app_theme.dart';
import 'theme/game_backdrop.dart';
import 'widgets/glass_card.dart';
import 'widgets/premium_button.dart';
import 'widgets/turn_timer.dart';
import 'widgets/custom_dice.dart';
import 'game/premium_board.dart';
import 'game/reference_game_scene.dart';
import 'game/player_hud.dart';
import 'game/game_menu_sheet.dart';
import 'game/match_result_modal.dart';
import 'shop/shop_screen.dart';
import 'shop/inventory_screen.dart';
import 'wallet_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFFFAED),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const LudoClub());
}

String playerName(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return 'Ludo player';
  if (value.startsWith('Guest_') && value.length >= 10) {
    return 'Player ${value.substring(6, 10).toUpperCase()}';
  }
  if (RegExp(r'^Player_[a-f0-9]{20}$').hasMatch(value)) {
    return 'Club Player';
  }
  return value;
}

String skinName(dynamic id) {
  final words = id?.toString().split('_').skip(1).toList() ?? [];
  if (words.isEmpty) return 'Classic';
  return words
      .map(
        (word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class LudoClub extends StatefulWidget {
  const LudoClub({super.key});
  @override
  State<LudoClub> createState() => _LudoClubState();
}

class _LudoClubState extends State<LudoClub> {
  final api = Api();
  bool loading = true;
  final navigatorKey = GlobalKey<NavigatorState>();

  void sessionChanged() {
    if (!loading && api.user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    api.addListener(sessionChanged);
    api.restore().whenComplete(() {
      if (mounted) setState(() => loading = false);
    });
  }

  @override
  void dispose() {
    api.removeListener(sessionChanged);
    api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    title: 'Ludo Club',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.brightTheme,
    themeMode: ThemeMode.light,
    builder:
        (context, child) =>
            GameBackdrop(child: child ?? const SizedBox.shrink()),
    home:
        loading
            ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.15),
                      ),
                      child: const Icon(
                        Icons.casino_rounded,
                        size: 72,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: AppColors.gold),
                    const SizedBox(height: 20),
                    const Text(
                      'LUDO CLUB MULTIPLAYER',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 16,
                      ),
                    ),
                    if (api.sessionError != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          api.sessionError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.ruby),
                        ),
                      ),
                      TextButton(
                        onPressed: api.restore,
                        child: const Text(
                          'Retry Connection',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
            : api.user == null
            ? ConnectionScreen(api: api)
            : ClubHome(api: api),
  );
}

Future<void> runTask(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(color: AppColors.ink),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceDark,
        ),
      );
    }
  }
}

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  String hint = '',
  bool multiline = false,
  bool obscure = false,
}) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: multiline ? 4 : 1,
            obscureText: obscure,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        ),
  );
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return value;
}

Future<bool> confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Are you sure?'),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
    ) ??
    false;

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 64,
                color: AppColors.ruby,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to connect to Ludo Club',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (api.sessionError != null)
                Text(
                  api.sessionError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
              const SizedBox(height: 20),
              PremiumButton(label: 'Retry connection', onPressed: api.restore),
            ],
          ),
        ),
      ),
    ),
  );
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.api});
  final Api api;
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    await runTask(context, () async {
      await widget.api.adminLogin(email.text, password.text);
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administrator sign in')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Admin email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => busy ? null : submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Please wait…' : 'Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget retry(dynamic error, VoidCallback onRetry) => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    children: [
      Text('$error'),
      const SizedBox(height: 12),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  ),
);

Widget pager(int page, bool hasMore, ValueChanged<int> onChange) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    IconButton(
      onPressed: page > 0 ? () => onChange(page - 1) : null,
      icon: const Icon(Icons.arrow_back),
    ),
    Text('Page ${page + 1}'),
    IconButton(
      onPressed: hasMore ? () => onChange(page + 1) : null,
      icon: const Icon(Icons.arrow_forward),
    ),
  ],
);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.api});
  final Api api;
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String section = 'analytics';
  int page = 0;
  late Future<dynamic> data;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    final path =
        section == 'settings'
            ? '/admin/settings/payment'
            : '/admin/$section?page=$page';
    data = widget.api.call(path);
  }

  Future<void> update(String path, Map<String, dynamic> body) async {
    final reason = await askText(
      context,
      'Reason for this action',
      hint: 'At least 5 characters',
      multiline: true,
    );
    if (reason == null || !mounted) return;
    await runTask(context, () async {
      await widget.api.call(
        '/admin/$path',
        method: 'PUT',
        body: {...body, 'reason': reason},
      );
      if (mounted) setState(load);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Club administration'),
      actions: [
        IconButton(
          onPressed: () => setState(load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        DropdownButton<String>(
          value: section,
          isExpanded: true,
          items:
              [
                    'analytics',
                    'games',
                    'users',
                    'deposits',
                    'withdrawals',
                    'disputes',
                    'settings',
                    'audit',
                  ]
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.toUpperCase()),
                    ),
                  )
                  .toList(),
          onChanged:
              (v) => setState(() {
                section = v!;
                page = 0;
                load();
              }),
        ),
        FutureBuilder<dynamic>(
          future: data,
          builder: (context, s) {
            if (s.hasError) {
              return retry(s.error, () => setState(load));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (section == 'analytics' || section == 'settings') {
              if (s.data is! Map) {
                return const Center(child: CircularProgressIndicator());
              }
              final d = s.data as Map;
              if (section == 'analytics') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final key in [
                          'users',
                          'activeGames',
                          'completedGames',
                          'queued',
                          'pendingDeposits',
                          'pendingWithdrawals',
                          'disputes',
                        ])
                          statTile('${d[key] ?? 0}', key),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: const Text('Vodafone Cash Receiving Number'),
                    subtitle: Text('${d['vodafoneCashReceivingNumber']}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final number = await askText(
                          context,
                          'Edit receiving number',
                          initial: '${d['vodafoneCashReceivingNumber']}',
                        );
                        if (number == null) return;
                        await update('settings/payment', {
                          'vodafoneCashReceivingNumber': number,
                        });
                      },
                      child: const Text('Edit receiving number'),
                    ),
                  ),
                ],
              );
            }
            if (s.data is! List) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = s.data as List;
            return Column(
              children: [
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text('No records on this page.'),
                  ),
                for (final r in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (section == 'deposits') ...[
                            Text(
                              'Deposit ${r['_id']} · ${egp(r['amountMinor'])}',
                            ),
                            Text(
                              'Status: ${r['status']} · Ref: ${r['transferReference']}',
                            ),
                            if (r['status'] == 'PENDING')
                              Row(
                                children: [
                                  TextButton(
                                    onPressed:
                                        () => update(
                                          'deposits/${r['_id']}/approve',
                                          {},
                                        ),
                                    child: const Text(
                                      'Approve verified transfer',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => update(
                                          'deposits/${r['_id']}/reject',
                                          {},
                                        ),
                                    child: const Text('Reject deposit'),
                                  ),
                                ],
                              ),
                          ],
                          if (section == 'users') ...[
                            Text(
                              '${r['username']} · ${r['email']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(r['isActive'] ? 'active' : 'banned'),
                          ],
                        ],
                      ),
                    ),
                  ),
                pager(
                  page,
                  rows.length == 50,
                  (v) => setState(() {
                    page = v;
                    load();
                  }),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

Widget statTile(String value, String label) => Container(
  width: 135,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0x12277C69),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26),
      ),
      Text(label),
    ],
  ),
);

class PlayerSettingsScreen extends StatelessWidget {
  const PlayerSettingsScreen({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('GAME SETTINGS')),
    body: ListenableBuilder(
      listenable: api,
      builder:
          (context, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: api.soundEnabled,
                      onChanged: api.setSound,
                      title: const Text('Sound effects'),
                      secondary: const Icon(Icons.volume_up_rounded),
                    ),
                    SwitchListTile(
                      value: api.hapticsEnabled,
                      onChanged: api.setHaptics,
                      title: const Text('Haptic feedback'),
                      secondary: const Icon(Icons.vibration_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: ListTile(
                  leading: Icon(
                    api.online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: api.online ? AppColors.emerald : AppColors.ruby,
                  ),
                  title: Text(
                    api.online ? 'Connected to the club' : 'Reconnecting',
                  ),
                  subtitle: const Text(
                    'Your game is restored from the server after reconnecting.',
                  ),
                ),
              ),
            ],
          ),
    ),
  );
}

class ClubHome extends StatefulWidget {
  const ClubHome({super.key, required this.api});
  final Api api;

  @override
  State<ClubHome> createState() => _ClubHomeState();
}

class _ClubHomeState extends State<ClubHome> {
  int tab = 0;
  bool busy = false;
  Timer? poll;

  Api get api => widget.api;

  void onApiChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    api.addListener(onApiChange);
    poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (api.user?['activeGame'] == 'queue') {
        api.refresh().catchError((Object _) {});
      }
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    api.removeListener(onApiChange);
    super.dispose();
  }

  Future<void> play(String mode) async {
    var stakeMinor = 0;

    final capacity = await showModalBottomSheet<int>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SELECT TABLE SIZE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mode == 'practice'
                        ? 'Free practice · No ranking or points'
                        : 'Free match · Play for ranking',
                    style: const TextStyle(color: AppColors.gold),
                  ),
                  const SizedBox(height: 20),
                  PremiumButton(
                    label: '2 PLAYERS · DUEL',
                    icon: Icons.person_rounded,
                    onPressed: () => Navigator.pop(ctx, 2),
                  ),
                  const SizedBox(height: 12),
                  PremiumButton(
                    label: '4 PLAYERS (FULL TABLE)',
                    icon: Icons.groups_rounded,
                    gradient: AppColors.emeraldGradient,
                    textColor: Colors.white,
                    onPressed: () => Navigator.pop(ctx, 4),
                  ),
                ],
              ),
            ),
          ),
    );
    if (capacity == null || !mounted) return;

    if (mode != 'practice' && api.user?['platformPlayer'] == true) {
      final modes = await api.call('/v1/game/modes');
      final tiers =
          (modes['entryTiers'] as List)
              .where(
                (tier) =>
                    tier['available'] == true &&
                    (tier['capacities'] as List).contains(capacity),
              )
              .map<int>((tier) => tier['points'] as int)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      final selected = await showModalBottomSheet<int>(
        context: context,
        builder:
            (ctx) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('SELECT ENTRY POINTS')),
                  for (final points in tiers)
                    ListTile(
                      title: Text(
                        points == 0
                            ? 'Free match'
                            : '$points platform points per player',
                      ),
                      subtitle:
                          points > 0
                              ? const Text(
                                'Points are reserved when the full match starts',
                              )
                              : null,
                      onTap: () => Navigator.pop(ctx, points),
                    ),
                ],
              ),
            ),
      );
      if (selected == null || !mounted) return;
      stakeMinor = selected;
    }

    setState(() => busy = true);
    await runTask(context, () async {
      final path =
          mode == 'quick'
              ? '/matchmaking/queue'
              : mode == 'practice'
              ? '/games/practice'
              : '/rooms/create';
      final data = await api.call(
        path,
        method: 'POST',
        body: {'capacity': capacity, 'stakeMinor': stakeMinor},
      );
      if (mode != 'quick') {
        api.acceptGame(data);
      }
      await api.refresh();
      if (mounted && api.game != null && api.user?['activeGame'] != 'queue') {
        openGame();
      }
    });
    if (mounted) setState(() => busy = false);
  }

  void openGame() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => GameScreen(api: api)),
    ).then((_) {
      if (api.user != null) {
        api.refresh().catchError((Object _) {});
      }
    });
  }

  Future<void> join() async {
    final code = await askText(
      context,
      'Join Private Table',
      hint: 'Enter 10-character Room Code',
    );
    if (code == null || !mounted) return;
    await runTask(context, () async {
      api.acceptGame(
        await api.call('/rooms/join', method: 'POST', body: {'code': code}),
      );
      await api.refresh();
      if (mounted) openGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = api.user!;
    final displayName = playerName(
      user['displayName']?.toString().isNotEmpty == true
          ? user['displayName']
          : user['username'],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('LUDO CLUB'),
        actions: [
          IconButton(
            onPressed: () => api.returnToPlatform().catchError((Object _) {}),
            icon: const Icon(Icons.exit_to_app_rounded),
            tooltip: 'Return to platform',
          ),
          IconButton(
            onPressed: () => runTask(context, api.refresh),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          // HOME TAB
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // User header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2),
                    ),
                    child: Text(
                      user['avatar'] ?? '🎲',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: AppColors.emerald,
                              size: 8,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Online',
                              style: TextStyle(
                                color: AppColors.mutedInk,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Original decorative illustration; all game actions remain server driven.
              Container(
                height: 248,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFF5BE),
                      Color(0xFFFFDB83),
                      Color(0xFFFFAF72),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: .45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: .14),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -44,
                      top: -32,
                      bottom: -35,
                      width: 260,
                      child: Image.asset(
                        'assets/illustrations/ludo_hero.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 24,
                      bottom: 20,
                      right: 118,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR TABLE AWAITS',
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xDDFFE29B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                'ROLL INTO\nTHE FUN',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 27,
                                  height: 1.03,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed:
                                user['activeGame'] == null
                                    ? () => play('quick')
                                    : openGame,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('PLAY NOW'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              GlassCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: AppColors.gold,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user['available'] == true
                            ? '${user['points'] ?? 0} Platform Points'
                            : 'Platform points unavailable',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => tab = 2),
                      child: const Text('SHOP'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Hero PLAY NOW
              if (user['activeGame'] == 'queue')
                GlassCard(
                  borderColor: AppColors.gold,
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.gold),
                      const SizedBox(height: 16),
                      const Text(
                        'SEARCHING FOR MATCH...',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connecting with opponents near your rating',
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed:
                            () => runTask(context, () async {
                              await api.call(
                                '/matchmaking/queue',
                                method: 'DELETE',
                              );
                              await api.refresh();
                            }),
                        child: const Text('CANCEL SEARCH'),
                      ),
                    ],
                  ),
                )
              else if (user['activeGame'] != null)
                PremiumButton(
                  label: 'RETURN TO ACTIVE MATCH',
                  icon: Icons.play_circle_fill_rounded,
                  onPressed: openGame,
                )
              else
                PremiumButton(
                  label: 'QUICK MATCH',
                  icon: Icons.bolt_rounded,
                  onPressed: () => play('quick'),
                ),

              const SizedBox(height: 24),

              const Text(
                'GAME MODES',
                style: TextStyle(
                  color: AppColors.mutedInk,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _modeCard(
                      icon: Icons.people_outline_rounded,
                      title: 'Private Room',
                      subtitle: 'Play with friends',
                      badge: 'FREE',
                      onTap: () => play('private'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _modeCard(
                      icon: Icons.key_rounded,
                      title: 'Join Room',
                      subtitle: 'Enter room code',
                      badge: 'CODE',
                      onTap: join,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _modeCard(
                icon: Icons.smart_toy_outlined,
                title: 'Practice Mode',
                subtitle: 'Improve your tactics against AI bots',
                badge: 'FREE',
                onTap: () => play('practice'),
              ),

              const SizedBox(height: 24),
              const Text(
                'YOUR STATS',
                style: TextStyle(
                  color: AppColors.mutedInk,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statTile('${user['games'] ?? 0}', 'Games'),
                  _statTile('${user['wins'] ?? 0}', 'Wins'),
                  _statTile('${user['rating'] ?? 1000}', 'Rating'),
                  _statTile('${user['bestStreak'] ?? 0}', 'Best Streak'),
                ],
              ),
            ],
          ),

          // PLAY TAB (Full Matchmaking Hub)
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'MATCHMAKING HUB',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (user['activeGame'] == 'queue') ...[
                GlassCard(
                  child: Column(
                    children: [
                      const Text(
                        'SEARCHING FOR MATCH...',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed:
                            () => runTask(context, () async {
                              await api.call(
                                '/matchmaking/queue',
                                method: 'DELETE',
                              );
                              await api.refresh();
                            }),
                        child: const Text('CANCEL SEARCH'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (user['activeGame'] != null) ...[
                PremiumButton(
                  label: 'RETURN TO MATCH',
                  icon: Icons.play_arrow_rounded,
                  onPressed: openGame,
                ),
                const SizedBox(height: 16),
              ],
              PremiumButton(
                label: 'QUICK MATCH',
                icon: Icons.flash_on_rounded,
                onPressed:
                    user['activeGame'] == null ? () => play('quick') : null,
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: 'CREATE PRIVATE TABLE',
                icon: Icons.add_circle_outline_rounded,
                gradient: AppColors.emeraldGradient,
                textColor: Colors.white,
                onPressed:
                    user['activeGame'] == null ? () => play('private') : null,
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: 'PRACTICE VS BOTS',
                icon: Icons.smart_toy_rounded,
                gradient: AppColors.darkCardGradient,
                textColor: AppColors.ink,
                onPressed:
                    user['activeGame'] == null ? () => play('practice') : null,
              ),
            ],
          ),

          // SHOP TAB
          ShopScreen(api: api),

          // PROFILE TAB
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 3),
                      ),
                      child: Text(
                        user['avatar'] ?? '🎲',
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'ID: ${user['id']}',
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('${user['wins'] ?? 0} WINS')),
                        Chip(label: Text('${user['losses'] ?? 0} LOSSES')),
                        Chip(label: Text('RATING ${user['rating'] ?? 1000}')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Token: ${skinName((user['equipped'] as Map?)?['token'])} · Dice: ${skinName((user['equipped'] as Map?)?['dice'])}',
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (user['platformPlayer'] != true)
                          OutlinedButton.icon(
                            onPressed:
                                () => runTask(context, () async {
                                  final name = await askText(
                                    context,
                                    'Edit Display Name',
                                    initial: displayName,
                                  );
                                  if (name == null) return;
                                  await api.call(
                                    '/auth/me',
                                    method: 'PATCH',
                                    body: {'displayName': name},
                                  );
                                  await api.refresh();
                                }),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Edit Name'),
                          ),
                        if (user['platformPlayer'] != true)
                          const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => InventoryScreen(api: api),
                              ),
                            );
                          },
                          icon: const Icon(Icons.inventory_2_rounded, size: 16),
                          label: const Text('Inventory'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.history_rounded,
                  color: AppColors.gold,
                ),
                title: const Text('Match History'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DataScreen(api: api, kind: 'history'),
                      ),
                    ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.leaderboard_rounded,
                  color: AppColors.emerald,
                ),
                title: const Text('Leaderboard'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder:
                            (_) => DataScreen(api: api, kind: 'leaderboard'),
                      ),
                    ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.query_stats_rounded,
                  color: AppColors.gold,
                ),
                title: const Text('Verified statistics'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DataScreen(api: api, kind: 'stats'),
                      ),
                    ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.settings_rounded,
                  color: AppColors.ink,
                ),
                title: const Text('Settings'),
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PlayerSettingsScreen(api: api),
                      ),
                    ),
              ),
              if (user['role'] == 'admin' && user['platformPlayer'] != true)
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.gold,
                  ),
                  title: const Text('Club administration'),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AdminScreen(api: api),
                        ),
                      ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.gold.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.gold),
            label: 'HOME',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(
              Icons.sports_esports_rounded,
              color: AppColors.gold,
            ),
            label: 'PLAY',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(
              Icons.shopping_bag_rounded,
              color: AppColors.gold,
            ),
            label: 'SHOP',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.gold),
            label: 'PROFILE',
          ),
        ],
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.gold, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: AppColors.emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.gold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.api});
  final Api api;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? clock;
  bool busy = false;
  int seconds = 30;
  final chatInput = TextEditingController();

  Api get api => widget.api;

  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final deadline = api.game?['state']?['deadline'];
          seconds =
              deadline == null
                  ? 0
                  : ((deadline -
                              DateTime.now().millisecondsSinceEpoch -
                              api.serverOffset) /
                          1000)
                      .ceil()
                      .clamp(0, 30)
                      .toInt();
        });
      }
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    chatInput.dispose();
    super.dispose();
  }

  void _openChat() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .56,
              child: Column(
                children: [
                  const Text(
                    'TABLE CHAT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: api,
                      builder:
                          (context, _) => ListView(
                            children: [
                              for (final message in api.chats)
                                ListTile(
                                  title: Text(
                                    playerName(message['username']),
                                    style: const TextStyle(
                                      color: AppColors.goldLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text('${message['message']}'),
                                ),
                            ],
                          ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: chatInput,
                          maxLength: 280,
                          decoration: const InputDecoration(
                            hintText: 'Say something friendly',
                            counterText: '',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send',
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.gold,
                        ),
                        onPressed:
                            () => runTask(sheetContext, () async {
                              final value = chatInput.text.trim();
                              if (value.isEmpty || api.game == null) return;
                              final sent = await api.call(
                                '/games/${api.game!['id']}/chat',
                                method: 'POST',
                                body: {'message': value},
                              );
                              api.acceptChat(sent);
                              chatInput.clear();
                            }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> action(String type, {int? token}) async {
    setState(() => busy = true);
    await runTask(context, () async {
      await api.action(type, tokenIndex: token);
      if (api.hapticsEnabled) await HapticFeedback.lightImpact();
      if (api.soundEnabled) await SystemSound.play(SystemSoundType.click);
    });
    if (mounted) setState(() => busy = false);
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => GameMenuSheet(
            soundEnabled: api.soundEnabled,
            hapticsEnabled: api.hapticsEnabled,
            onToggleSound: () => api.setSound(!api.soundEnabled),
            onToggleHaptics: () => api.setHaptics(!api.hapticsEnabled),
            onForfeit: () async {
              if (!mounted || api.game?['status'] != 'active') return;
              final hasStake = (api.game?['stakeMinor'] as num? ?? 0) > 0;
              final confirmed = await confirm(
                context,
                hasStake
                    ? 'Are you sure you want to forfeit this match? Your stake will be handled according to match rules.'
                    : 'Are you sure you want to forfeit this match?',
              );
              if (confirmed && mounted && api.game?['status'] == 'active') {
                await action('forfeit');
              }
            },
            onReportProblem: () async {
              final msg = await askText(
                context,
                'Report Problem',
                hint: 'Describe issue',
              );
              if (msg != null && mounted) {
                await api.call(
                  '/games/${api.game!['id']}/disputes',
                  method: 'POST',
                  body: {'message': msg},
                );
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: api,
    builder: (context, _) {
      final g = api.game;
      if (g == null) {
        return const Scaffold(body: Center(child: Text('No game selected')));
      }
      final s = g['state'] as Map<String, dynamic>?;
      final waiting = g['status'] == 'waiting';
      final active = g['status'] == 'active';
      final completed = g['status'] == 'completed';
      final me = api.user?['id'];
      final turnIndex = s?['turn'] as int? ?? 0;
      final players = (s?['players'] as List?) ?? [];
      final myTurn =
          active &&
          s != null &&
          players.isNotEmpty &&
          players[turnIndex]['id'] == me;
      final diceValue = s?['lastDice'] as int? ?? 0;
      final canRoll = myTurn && s['phase'] == 'roll';
      final legalMoves = (g['legalMoves'] as List?) ?? [];

      final equipped =
          (api.user?['equipped'] as Map?)?.cast<String, String>() ?? {};
      final turnEquipment =
          players.isNotEmpty && turnIndex < players.length
              ? players[turnIndex]['equipped'] as Map?
              : null;
      final diceTheme =
          turnEquipment?['dice']?.toString() ??
          equipped['dice'] ??
          'dice_classic';
      final boardTheme = equipped['board'] ?? 'board_classic';
      final tokenTheme = equipped['token'] ?? 'token_classic';

      if (active && s != null) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Color(0xFF164778),
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF174A7C),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF164778),
            body: SafeArea(
              child: ReferenceGameScene(
                state: s,
                legal: legalMoves,
                me: me?.toString(),
                points: api.user?['points'],
                seconds: seconds,
                canRoll: canRoll,
                busy: busy,
                online: api.online,
                diceValue: diceValue,
                diceTheme: diceTheme,
                boardTheme: boardTheme,
                tokenTheme: tokenTheme,
                onRoll: () => action('roll'),
                onMove:
                    myTurn && !busy
                        ? (idx) => action('move', token: idx)
                        : null,
                onMenu: _openMenu,
                onChat: _openChat,
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(
            waiting
                ? 'ROOM CODE: ${g['code']}'
                : completed
                ? 'MATCH COMPLETED'
                : 'LUDO MATCH',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
          ),
          actions: [
            Icon(
              api.online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              semanticLabel: api.online ? 'Connected' : 'Reconnecting',
              color: api.online ? AppColors.emerald : AppColors.ruby,
              size: 19,
            ),
            IconButton(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Table chat',
            ),
            IconButton(
              onPressed: _openMenu,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(
                      label: Text('${g['mode']}'.toUpperCase()),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(
                        (g['stakeMinor'] ?? 0) == 0
                            ? 'FREE MATCH'
                            : api.user?['platformPlayer'] == true
                            ? 'ENTRY ${g['stakeMinor']} POINTS'
                            : 'ENTRY ${egp(g['stakeMinor'])}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    if ((g['platformFinance']?['policy']?['winnerPoints'] ??
                            0) >
                        0)
                      Chip(
                        label: Text(
                          'WINNER ${g['platformFinance']['policy']['winnerPoints']} POINTS',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if ((g['prizePoolMinor'] ?? 0) > 0)
                      Chip(
                        label: Text('POOL ${egp(g['prizePoolMinor'])}'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (players.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < players.length; i++)
                        SizedBox(
                          width:
                              (MediaQuery.of(context).size.width - 40) /
                                  (players.length > 2 ? 2 : players.length) -
                              8,
                          child: PlayerHudCard(
                            name: playerName(players[i]['name'] ?? 'P${i + 1}'),
                            colorKey: players[i]['color'] ?? 'red',
                            avatar: i == 0 ? '🎲' : '🤖',
                            isCurrentTurn: turnIndex == i && active,
                            isMe: players[i]['id'] == me,
                            isEliminated: players[i]['eliminated'] == true,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),

                Expanded(
                  child: Center(
                    child:
                        active && s != null
                            ? PremiumBoard(
                              state: s,
                              legal: legalMoves,
                              onToken:
                                  myTurn && !busy
                                      ? (idx) => action('move', token: idx)
                                      : null,
                              boardTheme: boardTheme,
                              tokenTheme: tokenTheme,
                            )
                            : waiting
                            ? SingleChildScrollView(
                              child: GlassCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.casino_rounded,
                                      color: AppColors.gold,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'PRIVATE TABLE',
                                      style: TextStyle(
                                        color: AppColors.goldLight,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.7,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${g['members']?.length ?? 0} / ${g['capacity']} players',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (g['stakeMinor'] ?? 0) == 0
                                          ? 'FREE MATCH'
                                          : api.user?['platformPlayer'] == true
                                          ? 'Entry ${g['stakeMinor']} points per player'
                                          : 'Entry ${egp(g['stakeMinor'])} per player',
                                      style: const TextStyle(
                                        color: AppColors.goldLight,
                                      ),
                                    ),
                                    if (g['platformFinance'] != null)
                                      Text(
                                        'Funding: ${g['platformFinance']['state']}',
                                        style: const TextStyle(
                                          color: AppColors.mutedInk,
                                        ),
                                      ),
                                    if ((g['stakeMinor'] ?? 0) > 0 &&
                                        api.user?['platformPlayer'] != true)
                                      Text(
                                        'Full table pool: ${egp((g['stakeMinor'] as int) * (g['capacity'] as int))}',
                                        style: const TextStyle(
                                          color: AppColors.mutedInk,
                                        ),
                                      ),
                                    const SizedBox(height: 14),
                                    for (
                                      var i = 0;
                                      i < (g['members'] as List).length;
                                      i++
                                    )
                                      ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          backgroundColor: playerColors.values
                                              .elementAt(i),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          playerName((g['names'] as List)[i]),
                                        ),
                                        trailing: Text(
                                          g['members'][i] == g['host']
                                              ? 'HOST'
                                              : 'JOINED',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.goldLight,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    SelectableText(
                                      '${g['code']}',
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: '${g['code']}'),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Room code copied'),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.copy_rounded),
                                      label: const Text('COPY INVITE CODE'),
                                    ),
                                    if (g['host'] == me)
                                      FilledButton.icon(
                                        onPressed:
                                            (g['members'] as List).length ==
                                                        g['capacity'] &&
                                                    !busy &&
                                                    g['platformFinance'] == null
                                                ? () => runTask(
                                                  context,
                                                  () async {
                                                    api.acceptGame(
                                                      await api.call(
                                                        '/games/${g['id']}/start',
                                                        method: 'POST',
                                                      ),
                                                    );
                                                  },
                                                )
                                                : null,
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                        ),
                                        label: const Text('START MATCH'),
                                      ),
                                    TextButton(
                                      onPressed:
                                          () => runTask(context, () async {
                                            await api.call(
                                              '/games/${g['id']}/leave',
                                              method: 'POST',
                                            );
                                            await api.refresh();
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                            }
                                          }),
                                      child: Text(
                                        g['host'] == me
                                            ? 'CLOSE ROOM'
                                            : 'LEAVE ROOM',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : MatchResultModal(
                              isWin: s?['winner'] == me,
                              winnerName:
                                  s?['winner'] == null
                                      ? 'None'
                                      : playerName(
                                        players.cast<Map>().firstWhere(
                                          (p) => p['id'] == s?['winner'],
                                          orElse: () => {'name': 'Winner'},
                                        )['name'],
                                      ),
                              stakeMinor: g['stakeMinor'] ?? 0,
                              prizePoolMinor: g['prizePoolMinor'] ?? 0,
                              pointsMode: api.user?['platformPlayer'] == true,
                              winnerPoints:
                                  g['platformFinance']?['policy']?['winnerPoints'] ??
                                  0,
                              settlementStatus:
                                  g['platformFinance']?['state']?.toString(),
                              onPlayAgain: () => Navigator.pop(context),
                              onBackHome: () => Navigator.pop(context),
                            ),
                  ),
                ),

                const SizedBox(height: 12),

                if (active)
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AnimatedDice(
                              value: diceValue,
                              isRolling: busy,
                              size: 56,
                              diceTheme: diceTheme,
                              onTap:
                                  canRoll && !busy
                                      ? () => action('roll')
                                      : null,
                            ),
                            TurnTimerRing(secondsRemaining: seconds),
                            PremiumButton(
                              label:
                                  MediaQuery.sizeOf(context).width < 400
                                      ? (canRoll ? 'ROLL' : 'WAIT')
                                      : (canRoll ? 'ROLL DICE' : 'WAITING'),
                              height: 48,
                              isFullWidth: false,
                              onPressed:
                                  canRoll && !busy
                                      ? () => action('roll')
                                      : null,
                            ),
                          ],
                        ),
                        if (myTurn &&
                            s['phase'] == 'move' &&
                            legalMoves.isNotEmpty)
                          SizedBox(
                            height: 42,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final token in legalMoves)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: 8,
                                      top: 5,
                                    ),
                                    child: ActionChip(
                                      label: Text('MOVE ${token + 1}'),
                                      onPressed:
                                          busy
                                              ? null
                                              : () => action(
                                                'move',
                                                token: token as int,
                                              ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class DataScreen extends StatefulWidget {
  const DataScreen({
    super.key,
    required this.api,
    required this.kind,
    this.embedded = false,
  });
  final Api api;
  final String kind;
  final bool embedded;

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  late Future<dynamic> data;
  int page = 0;
  String period = 'all';
  String mode = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    data = widget.api.call(switch (widget.kind) {
      'history' =>
        '/games/history?page=$page${mode == 'all' ? '' : '&mode=$mode'}',
      'leaderboard' => '/stats/leaderboard?period=$period',
      _ => '/stats/user',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.embedded
              ? null
              : AppBar(title: Text(widget.kind.toUpperCase())),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(load);
          await data;
        },
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (widget.kind == 'history')
              DropdownButton<String>(
                value: mode,
                isExpanded: true,
                items:
                    ['all', 'quick', 'private', 'practice']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.toUpperCase()),
                          ),
                        )
                        .toList(),
                onChanged:
                    (v) => setState(() {
                      mode = v!;
                      page = 0;
                      load();
                    }),
              ),
            if (widget.kind == 'leaderboard')
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All time')),
                    ButtonSegment(value: 'week', label: Text('7 days')),
                    ButtonSegment(value: 'month', label: Text('30 days')),
                  ],
                  selected: {period},
                  onSelectionChanged:
                      (v) => setState(() {
                        period = v.first;
                        load();
                      }),
                ),
              ),
            const SizedBox(height: 16),
            FutureBuilder<dynamic>(
              future: data,
              builder: (context, snap) {
                if (snap.hasError) {
                  return retry(snap.error, () => setState(load));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (widget.kind == 'stats') {
                  final stats = snap.data as Map;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final key in [
                        'games',
                        'wins',
                        'losses',
                        'rating',
                        'bestStreak',
                      ])
                        statTile('${stats[key] ?? 0}', key),
                      statTile(
                        '${(((stats['winRate'] as num?) ?? 0) * 100).round()}%',
                        'win rate',
                      ),
                    ],
                  );
                }
                final rows = snap.data as List;
                if (rows.isEmpty) {
                  return const GlassCard(
                    child: Text(
                      'Nothing here yet. Finish a game to get started.',
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: GlassCard(
                          onTap:
                              widget.kind == 'history'
                                  ? () {
                                    final row = rows[i];
                                    if (row['initial'] != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder:
                                              (_) => ReplayScreen(
                                                api: widget.api,
                                                id: row['id'],
                                              ),
                                        ),
                                      );
                                    } else {
                                      widget.api.loadGame(row['id']).then((_) {
                                        if (context.mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder:
                                                  (_) => GameScreen(
                                                    api: widget.api,
                                                  ),
                                            ),
                                          );
                                        }
                                      });
                                    }
                                  }
                                  : null,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    i.isEven
                                        ? AppColors.emerald
                                        : AppColors.violet,
                                child: Text(
                                  widget.kind == 'history' ? '🎲' : '${i + 1}',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.kind == 'history'
                                          ? (rows[i]['names'] as List)
                                              .map(playerName)
                                              .join(' · ')
                                          : '${rows[i]['avatar'] ?? '🎲'} ${playerName(rows[i]['displayName'] ?? rows[i]['username'])}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      widget.kind == 'history'
                                          ? '${rows[i]['mode']} · ${rows[i]['status']}'
                                          : '${rows[i]['wins']} wins · Rating ${rows[i]['rating']}',
                                      style: const TextStyle(
                                        color: AppColors.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.kind == 'history')
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.gold,
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.kind == 'history')
                      pager(
                        page,
                        rows.length == 25,
                        (v) => setState(() {
                          page = v;
                          load();
                        }),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key, required this.api, required this.id});
  final Api api;
  final String id;
  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late final Future<dynamic> data;
  int step = 0;
  @override
  void initState() {
    super.initState();
    data = widget.api.call('/games/${widget.id}/replay');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MATCH REPLAY')),
    body: FutureBuilder<dynamic>(
      future: data,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final initial = snap.data['initial'];
        if (initial == null) {
          return const Center(
            child: Text('This room ended before play began.'),
          );
        }
        final events = snap.data['events'] as List;
        final states = [initial, ...events.map((e) => e['state'])];
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            PremiumBoard(state: Map<String, dynamic>.from(states[step])),
            const SizedBox(height: 18),
            Text(
              step == 0
                  ? 'Starting positions'
                  : '${events[step - 1]['action']['type']} · Move $step',
              textAlign: TextAlign.center,
            ),
            Slider(
              value: step.toDouble(),
              max: (states.length - 1).toDouble().clamp(1, double.infinity),
              divisions: states.length > 1 ? states.length - 1 : null,
              onChanged:
                  states.length > 1
                      ? (v) => setState(() => step = v.round())
                      : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: step > 0 ? () => setState(() => step--) : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                Text('$step / ${states.length - 1}'),
                IconButton(
                  onPressed:
                      step < states.length - 1
                          ? () => setState(() => step++)
                          : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
