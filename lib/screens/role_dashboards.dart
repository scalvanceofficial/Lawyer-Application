import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../help_support/screens/help_support_home_screen.dart';
import '../models/user_role.dart';
import '../models/consultation_request.dart';
import '../repositories/consultation_repository.dart';
import '../repositories/legal_taxonomy_repository.dart';
import '../repositories/lawyer_dashboard_repository.dart';
import '../services/auth_service.dart';
import '../services/app_error_message.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/subscription_gate.dart';
import '../widgets/client_portal_surface.dart';
import '../widgets/multi_select_form_field.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/register_fields.dart';
import 'legal_chat_screen.dart';
import 'notifications_screen.dart';
import 'cases/lawyer_case_requests_screen.dart';
import 'subscription_screen.dart';
import 'welcome_screen.dart';
import 'account_deletion_screen.dart';

const _ink = kInk;

final ButtonStyle _dashboardSectionButtonStyle = FilledButton.styleFrom(
  backgroundColor: Primary,
  foregroundColor: const Color(0xFF3A2117),
  minimumSize: const Size(0, 42),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
  shape: const StadiumBorder(),
);

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({super.key});

  @override
  State<LawyerDashboard> createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  ConsultationRequestStatus _requestStatus = ConsultationRequestStatus.pending;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  final _titles = const [
    'Aapke Lawyer',
    'User requests',
    'My reviews',
    'My profile',
    'Subscription',
    'NyaySaarthi',
    'Help & support',
    'About Aapke Lawyer',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.ensurePermissionOnEntry(context);
    });
    _notificationTapSubscription = NotificationService.onNotificationTap.listen(
      _openNotification,
    );
    final pendingNotification = NotificationService.consumePendingTap();
    if (pendingNotification != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNotification(pendingNotification),
      );
    }
  }

  void _openNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<UserProfile>(
    stream: AuthService.watchCurrentUserProfile(UserRole.lawyer),
    builder: (context, snapshot) {
      if (!snapshot.hasData && !snapshot.hasError) {
        return const _ProfileLoadingScaffold();
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _ProfileErrorScaffold(onRetry: () => setState(() {}));
      }
      return _buildDashboard(snapshot.data!);
    },
  );

  Widget _buildDashboard(UserProfile profile) => PopScope(
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _index != 0) setState(() => _index = 0);
    },
    child: Theme(
      data: ClientPortalSurface.theme(context),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF180B07),
        appBar: _index == 0
            ? null
            : AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  tooltip: 'Back to dashboard',
                  onPressed: () => setState(() => _index = 0),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Text(
                  _titles[_index],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _UserAvatar(profile: profile, radius: 18),
                  ),
                ],
              ),
        drawer: _index == 0
            ? _LawyerDrawer(
                profile: profile,
                index: _index,
                onSelected: (index) {
                  Navigator.pop(context);
                  setState(() => _index = index);
                },
                onLogout: _logout,
              )
            : null,
        body: ClientPortalSurface(
          child: SafeArea(
            child: _lawyerPage(
              _index,
              profile,
              requestStatus: _requestStatus,
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onOpenProfile: () => setState(() => _index = 3),
              onOpenRequests: (status) => setState(() {
                _requestStatus = status;
                _index = 1;
              }),
            ),
          ),
        ),
        bottomNavigationBar: _LawyerBottomNavigation(
          selectedIndex: _index,
          onSelected: (index) => setState(() => _index = index),
        ),
      ),
    ),
  );
}

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});
  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  int _index = 0;
  late Future<UserProfile> _profileFuture;
  final _titles = const [
    'Find an advocate',
    'My consultations',
    'Saved advocates',
    'My profile',
    'Subscription',
    'NyaySaarthi',
    'Help & support',
  ];

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService.currentUserProfile(UserRole.client);
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserProfile>(
    future: _profileFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _ProfileLoadingScaffold();
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return _ProfileErrorScaffold(
          onRetry: () => setState(() {
            _profileFuture = AuthService.currentUserProfile(UserRole.client);
          }),
        );
      }
      return _buildDashboard(snapshot.data!);
    },
  );

  Widget _buildDashboard(UserProfile profile) => Scaffold(
    backgroundColor: const Color(0xFFFFF8F2),
    appBar: AppBar(
      title: Text(
        _titles[_index],
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    drawer: _ClientDrawer(
      profile: profile,
      index: _index,
      onSelected: (index) {
        Navigator.pop(context);
        setState(() => _index = index);
      },
      onLogout: _logout,
    ),
    body: SafeArea(child: _clientPage(_index, profile)),
  );
}

class _LawyerDrawer extends StatelessWidget {
  const _LawyerDrawer({
    required this.profile,
    required this.index,
    required this.onSelected,
    required this.onLogout,
  });
  final UserProfile profile;
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: const Color(0xFF21110C),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
        children: [
          _DrawerHeader(
            profile: profile,
            subtitle: profile.expertise.isEmpty
                ? 'Advocate account'
                : profile.expertise,
          ),
          _drawerItem(Icons.home_outlined, 'Home', 0),
          _drawerItem(Icons.inbox_outlined, 'Requests', 1),
          _drawerItem(Icons.star_outline, 'Reviews', 2),
          _drawerItem(Icons.person_outline, 'My Profile', 3),
          _drawerItem(Icons.credit_card_outlined, 'Subscription', 4),
          _drawerItem(Icons.auto_awesome_outlined, 'NyaySaarthi', 5),
          _drawerItem(Icons.help_outline, 'Help & Support', 6),
          _drawerItem(Icons.info_outline, 'About', 7),
          const Divider(color: Colors.white24),
          const DeleteAccountButton(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: onLogout,
          ),
        ],
      ),
    ),
  );
  Widget _drawerItem(IconData icon, String label, int itemIndex) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: ListTile(
      selected: index == itemIndex,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: index == itemIndex
          ? const Icon(Icons.chevron_right, color: kBrown)
          : null,
      onTap: () => onSelected(itemIndex),
    ),
  );
}

class _LawyerBottomNavigation extends StatelessWidget {
  const _LawyerBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  static const _pages = [0, 1, 2, 5];

  @override
  Widget build(BuildContext context) {
    final selected = _pages.contains(selectedIndex)
        ? _pages.indexOf(selectedIndex)
        : 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF21110C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? const Color(0xFF4A2B1B)
                    : Colors.white,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? Primary
                    : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          child: NavigationBar(
            height: 68,
            selectedIndex: selected,
            onDestinationSelected: (value) => onSelected(_pages[value]),
            backgroundColor: Colors.transparent,
            indicatorColor: Primary,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.inbox_outlined),
                selectedIcon: Icon(Icons.inbox_rounded),
                label: 'Requests',
              ),
              NavigationDestination(
                icon: Icon(Icons.star_outline),
                selectedIcon: Icon(Icons.star_rounded),
                label: 'Reviews',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'NyaySaarthi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientDrawer extends StatelessWidget {
  const _ClientDrawer({
    required this.profile,
    required this.index,
    required this.onSelected,
    required this.onLogout,
  });
  final UserProfile profile;
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: ListView(
        children: [
          _DrawerHeader(profile: profile, subtitle: 'User account'),
          _item(Icons.search, 'Find an advocate', 0),
          _item(Icons.calendar_month_outlined, 'My consultations', 1),
          _item(Icons.bookmark_outline, 'Saved advocates', 2),
          _item(Icons.person_outline, 'My profile', 3),
          _item(Icons.credit_card_outlined, 'Subscription', 4),
          _item(Icons.auto_awesome_outlined, 'NyaySaarthi', 5),
          _item(Icons.help_outline, 'Help & Support', 6),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: onLogout,
          ),
        ],
      ),
    ),
  );
  Widget _item(IconData icon, String name, int i) => ListTile(
    selected: index == i,
    selectedTileColor: const Color(0xFFE8F2FF),
    leading: Icon(icon, color: index == i ? Colors.blue : kHint),
    title: Text(name),
    onTap: () => onSelected(i),
  );
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.profile, required this.subtitle});
  final UserProfile profile;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [kBrownDark, kBrownLight]),
      borderRadius: BorderRadius.circular(18),
    ),
    padding: const EdgeInsets.all(22),
    child: Row(
      children: [
        _UserAvatar(profile: profile, radius: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                profile.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _lawyerPage(
  int index,
  UserProfile profile, {
  required ConsultationRequestStatus requestStatus,
  required VoidCallback onMenu,
  required VoidCallback onOpenProfile,
  required ValueChanged<ConsultationRequestStatus> onOpenRequests,
}) => switch (index) {
  0 => _LawyerHome(
    profile: profile,
    onMenu: onMenu,
    onOpenProfile: onOpenProfile,
    onOpenRequests: onOpenRequests,
  ),
  1 => LawyerCaseRequestsScreen(initialStatus: requestStatus),
  2 => const _ReviewsPage(),
  3 => _LawyerProfile(profile: profile),
  4 => SubscriptionScreen(
    role: UserRole.lawyer,
    profile: profile,
    embedded: true,
  ),
  5 => SubscriptionGate(
    role: UserRole.lawyer,
    profile: profile,
    child: const LegalChatScreen(),
  ),
  6 => const _SupportPage(),
  _ => const _AboutPage(),
};

Widget _clientPage(int index, UserProfile profile) => switch (index) {
  0 => _ClientHome(profile: profile),
  1 => const _ConsultationsPage(),
  2 => const _SavedLawyersPage(),
  3 => _ClientProfile(profile: profile),
  4 => SubscriptionScreen(
    role: UserRole.client,
    profile: profile,
    embedded: true,
  ),
  5 => SubscriptionGate(
    role: UserRole.client,
    profile: profile,
    child: const LegalChatScreen(),
  ),
  _ => const _SupportPage(),
};

class _LawyerHome extends StatelessWidget {
  const _LawyerHome({
    required this.profile,
    required this.onMenu,
    required this.onOpenProfile,
    required this.onOpenRequests,
  });
  final UserProfile profile;
  final VoidCallback onMenu;
  final VoidCallback onOpenProfile;
  final ValueChanged<ConsultationRequestStatus> onOpenRequests;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<ConsultationRequest>>(
    stream: ConsultationRepository().watchLawyerRequests(),
    builder: (context, requestSnapshot) => StreamBuilder<List<LawyerReview>>(
      stream: LawyerDashboardRepository().watchReviews(),
      builder: (context, reviewSnapshot) {
        final error = requestSnapshot.error ?? reviewSnapshot.error;
        if (error != null) {
          return Center(
            child: Text(
              'Dashboard could not be loaded: ${appErrorMessage(error)}',
            ),
          );
        }
        final requests = requestSnapshot.data ?? const <ConsultationRequest>[];
        final reviews = reviewSnapshot.data ?? const <LawyerReview>[];
        final pending = requests
            .where((item) => item.status == ConsultationRequestStatus.pending)
            .length;
        final accepted = requests
            .where((item) => item.status == ConsultationRequestStatus.accepted)
            .length;
        final completed = requests
            .where((item) => item.status == ConsultationRequestStatus.completed)
            .length;
        final rejected = requests
            .where((item) => item.status == ConsultationRequestStatus.rejected)
            .length;
        final average = reviews.isEmpty
            ? 'New'
            : (reviews.fold<int>(0, (sum, item) => sum + item.rating) /
                      reviews.length)
                  .toStringAsFixed(1);
        return _Scrollable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onMenu,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .12),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Open menu',
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .12),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: 'Notifications',
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'My profile',
                    child: InkWell(
                      onTap: onOpenProfile,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _UserAvatar(profile: profile, radius: 22),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Hello, ${profile.displayName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Manage your legal practice',
                style: TextStyle(color: Color(0xFFEADFD8), fontSize: 15),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 190),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF875535), Color(0xFF2D1710)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -12,
                      top: -18,
                      child: Icon(
                        Icons.balance_rounded,
                        size: 142,
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Primary.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'YOUR LEGAL PRACTICE',
                            style: TextStyle(
                              color: Primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Welcome back,\n${profile.displayName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.expertise.isEmpty
                                    ? 'Professional practice overview'
                                    : profile.expertise,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFEADFD8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    average,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Primary.withValues(alpha: .14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_outlined,
                          color: Primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Requests overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: _dashboardSectionButtonStyle,
                    onPressed: () =>
                        onOpenRequests(ConsultationRequestStatus.pending),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DashboardStatusCard(
                      count: pending,
                      label: 'New',
                      icon: Icons.inbox_outlined,
                      color: Colors.orange,
                      onTap: () =>
                          onOpenRequests(ConsultationRequestStatus.pending),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashboardStatusCard(
                      count: accepted,
                      label: 'Accepted',
                      icon: Icons.verified_outlined,
                      color: Colors.green,
                      onTap: () =>
                          onOpenRequests(ConsultationRequestStatus.accepted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DashboardStatusCard(
                      count: completed,
                      label: 'Completed',
                      icon: Icons.task_alt_outlined,
                      color: Colors.blueGrey,
                      onTap: () =>
                          onOpenRequests(ConsultationRequestStatus.completed),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashboardStatusCard(
                      count: rejected,
                      label: 'Rejected',
                      icon: Icons.cancel_outlined,
                      color: Colors.redAccent,
                      onTap: () =>
                          onOpenRequests(ConsultationRequestStatus.rejected),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Recent requests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (requests.isEmpty)
                const _DashboardEmptyState()
              else
                ...requests
                    .take(3)
                    .map(
                      (request) => _RecentDashboardRequest(
                        request: request,
                        onTap: () => onOpenRequests(request.status),
                      ),
                    ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Availability',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: _dashboardSectionButtonStyle,
                    onPressed: () => _showAvailabilityDialog(context, profile),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xE638241C),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: profile.availability.isEmpty
                    ? const Text(
                        'No working days selected.',
                        style: TextStyle(color: Color(0xFFD8C8BE)),
                      )
                    : Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: profile.availability
                            .map(
                              (day) => Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: Text(day),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ClientHome extends StatelessWidget {
  const _ClientHome({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) => _Scrollable(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${profile.displayName}',
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Find the right legal help with confidence.',
          style: TextStyle(color: kHint),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _UserAvatar(profile: profile, radius: 30),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      profile.displayEmail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kHint),
                    ),
                    Text(
                      profile.displayAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search by legal issue or court',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Popular legal services',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _ServiceChip('Family law', Icons.family_restroom),
            _ServiceChip('Property', Icons.home_work_outlined),
            _ServiceChip('Criminal', Icons.gavel),
            _ServiceChip('Corporate', Icons.business_center_outlined),
          ],
        ),
        const SizedBox(height: 25),
        const Text(
          'Recommended for you',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const _LawyerCard(
          name: 'Adv. Priya Sharma',
          specialty: 'Family & Civil Law · 9 years',
          rating: '4.8',
        ),
      ],
    ),
  );
}

class _ReviewsPage extends StatelessWidget {
  const _ReviewsPage();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<LawyerReview>>(
    stream: LawyerDashboardRepository().watchReviews(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text(
            'Reviews could not be loaded: ${appErrorMessage(snapshot.error!)}',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final reviews = snapshot.data!;
      final average = reviews.isEmpty
          ? 0.0
          : reviews.fold<int>(0, (sum, item) => sum + item.rating) /
                reviews.length;
      return _Scrollable(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Metric(
              value: reviews.isEmpty
                  ? 'No rating'
                  : '${average.toStringAsFixed(1)} / 5',
              label:
                  'Based on ${reviews.length} user review${reviews.length == 1 ? '' : 's'}',
              icon: Icons.star,
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent reviews',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
            ),
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              const Text(
                'No reviews yet.',
                style: TextStyle(color: Color(0xFFD8C8BE)),
              )
            else
              ...reviews.map(
                (review) => _ReviewCard(
                  name: review.clientName,
                  text: review.review,
                  rating: review.rating,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _LawyerProfile extends StatelessWidget {
  const _LawyerProfile({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) => StreamBuilder<UserProfile>(
    stream: AuthService.watchCurrentUserProfile(UserRole.lawyer),
    initialData: profile,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text(appErrorMessage(snapshot.error!)));
      }
      final liveProfile = snapshot.data ?? profile;
      return _Scrollable(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _UserAvatar(profile: liveProfile, radius: 48)),
            const SizedBox(height: 14),
            Center(
              child: Text(
                liveProfile.displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Center(
              child: Text(
                liveProfile.barCouncilId.isEmpty
                    ? liveProfile.displayEmail
                    : 'Bar Council ID · ${liveProfile.barCouncilId}',
                style: const TextStyle(color: Color(0xFFD8C8BE)),
              ),
            ),
            const SizedBox(height: 26),
            _ProfileInfo(
              label: 'Area of expertise',
              value: liveProfile.expertise.isEmpty
                  ? 'Not provided'
                  : liveProfile.expertise,
            ),
            _ProfileInfo(
              label: 'Court of practice',
              value: liveProfile.courts.isEmpty
                  ? 'Not provided'
                  : liveProfile.courts,
            ),
            _ProfileInfo(
              label: 'Experience',
              value: liveProfile.experience.isEmpty
                  ? 'Not provided'
                  : '${liveProfile.experience} years',
            ),
            _ProfileInfo(label: 'Email', value: liveProfile.displayEmail),
            _ProfileInfo(label: 'Phone', value: liveProfile.displayPhone),
            _ProfileInfo(
              label: 'Date of birth',
              value: liveProfile.dateOfBirth.isEmpty
                  ? 'Not provided'
                  : liveProfile.dateOfBirth,
            ),
            _ProfileInfo(
              label: 'Bio',
              value: liveProfile.bio.isEmpty ? 'Not provided' : liveProfile.bio,
            ),
            const SizedBox(height: 16),
            _PrimaryAction(
              label: 'Edit advocate information',
              icon: Icons.edit_outlined,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: const Color(0xFF352019),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => _EditLawyerProfileDialog(profile: liveProfile),
              ),
            ),
            const DeleteAccountButton(),
          ],
        ),
      );
    },
  );
}

Future<void> _showAvailabilityDialog(
  BuildContext context,
  UserProfile profile,
) async {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final selected = profile.availability.toSet();
  final initialSelection = profile.availability.toSet();
  final value = await showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final hasChanges =
            !selected.containsAll(initialSelection) ||
            !initialSelection.containsAll(selected);
        return AlertDialog(
          title: const Text('Manage availability'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days
                .map(
                  (day) => FilterChip(
                    label: Text(day),
                    selected: selected.contains(day),
                    onSelected: (enabled) => setState(
                      () => enabled ? selected.add(day) : selected.remove(day),
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: hasChanges ? () => Navigator.pop(dialogContext) : null,
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: hasChanges && selected.isNotEmpty
                  ? () => Navigator.pop(dialogContext, selected.toList())
                  : null,
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
  if (value == null || !context.mounted) return;
  try {
    await LawyerDashboardRepository().updateAvailability(value);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Availability updated.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
    }
  }
}

class _EditLawyerProfileDialog extends StatefulWidget {
  const _EditLawyerProfileDialog({required this.profile});
  final UserProfile profile;
  @override
  State<_EditLawyerProfileDialog> createState() =>
      _EditLawyerProfileDialogState();
}

class _EditLawyerProfileDialogState extends State<_EditLawyerProfileDialog> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _address = TextEditingController(text: widget.profile.address);
  late final _dob = TextEditingController(text: widget.profile.dateOfBirth);
  late final _gender = TextEditingController(text: widget.profile.gender);
  late final _bio = TextEditingController(text: widget.profile.bio);
  late final _barId = TextEditingController(text: widget.profile.barCouncilId);
  late final Set<String> _expertise = _values(widget.profile.expertise);
  late final Set<String> _courts = _values(widget.profile.courts);
  final LegalTaxonomyRepository _taxonomy = LegalTaxonomyRepository();
  late final _experience = TextEditingController(
    text: widget.profile.experience,
  );
  bool _saving = false;
  String? _error;
  Uint8List? _imageBytes;

  bool get _hasChanges =>
      _imageBytes != null ||
      _name.text.trim() != widget.profile.name.trim() ||
      _address.text.trim() != widget.profile.address.trim() ||
      _dob.text.trim() != widget.profile.dateOfBirth.trim() ||
      _gender.text.trim() != widget.profile.gender.trim() ||
      _bio.text.trim() != widget.profile.bio.trim() ||
      _barId.text.trim() != widget.profile.barCouncilId.trim() ||
      _experience.text.trim() != widget.profile.experience.trim() ||
      !_sameValues(_expertise, _values(widget.profile.expertise)) ||
      !_sameValues(_courts, _values(widget.profile.courts));

  static bool _sameValues(Set<String> first, Set<String> second) =>
      first.length == second.length && first.containsAll(second);

  List<TextEditingController> get _controllers => [
    _name,
    _address,
    _dob,
    _gender,
    _bio,
    _barId,
    _experience,
  ];

  @override
  void initState() {
    super.initState();
    for (final item in _controllers) {
      item.addListener(_fieldChanged);
    }
  }

  void _fieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final item in _controllers) {
      item.removeListener(_fieldChanged);
      item.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Required' : null;
  String? _number(String? value) =>
      (int.tryParse(value?.trim() ?? '') ?? -1) < 0
      ? 'Enter a valid number'
      : null;
  static Set<String> _values(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false) || _saving) return;
    if (widget.profile.imageUrl.isEmpty && _imageBytes == null) {
      setState(() => _error = 'Please add a profile photo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LawyerDashboardRepository().updateProfile({
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'location': _address.text.trim(),
        'dob': _dob.text.trim(),
        'gender': _gender.text.trim(),
        'bio': _bio.text.trim(),
        'barid': _barId.text.trim(),
        'aoe': _expertise.toList(growable: false),
        'court': _courts.toList(growable: false),
        'experience': int.parse(_experience.text.trim()),
      });
      if (_imageBytes != null) {
        await LawyerDashboardRepository().updateProfileImage(_imageBytes!);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final bytes = result?.files.firstOrNull?.bytes;
      if (result != null && bytes == null) {
        throw StateError('The selected image could not be read.');
      }
      if (bytes != null && mounted) setState(() => _imageBytes = bytes);
    } catch (error) {
      if (mounted) setState(() => _error = appErrorMessage(error));
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int lines = 1,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      validator: number ? _number : _required,
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      10,
      18,
      12 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Edit profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Form(
              key: _key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProfileAvatar(
                      imageBytes: _imageBytes,
                      imageUrl: widget.profile.imageUrl,
                      onTap: _saving ? null : _pickImage,
                      isRequired: true,
                      compact: true,
                    ),

                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: widget.profile.displayEmail,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email (cannot change)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: widget.profile.displayPhone,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Phone (cannot change)',
                        isDense: true,
                      ),
                    ),
                    _field('Name', _name),
                    _field('Address / location', _address, lines: 2),
                    _field('Date of birth', _dob),
                    _field('Gender', _gender),
                    _field('Bar Council ID', _barId),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: StreamBuilder<List<String>>(
                        stream: _taxonomy.watchAreasOfExpertise(),
                        builder: (context, snapshot) => MultiSelectFormField(
                          label: 'Areas of expertise',
                          options: snapshot.data ?? const [],
                          selected: _expertise,
                          loading:
                              snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData,
                          errorText: snapshot.hasError
                              ? 'Unable to load live expertise values'
                              : null,
                          onChanged: (values) => setState(() {
                            _expertise
                              ..clear()
                              ..addAll(values);
                          }),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: CourtField(
                        value: _courts,
                        onChanged: (values) => setState(() {
                          _courts
                            ..clear()
                            ..addAll(values);
                        }),
                      ),
                    ),
                    _field('Experience in years', _experience, number: true),
                    _field('Bio', _bio, lines: 3),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving || !_hasChanges ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClientProfile extends StatelessWidget {
  const _ClientProfile({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) => _Scrollable(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _UserAvatar(profile: profile, radius: 48)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            profile.displayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 25),
        _ProfileInfo(label: 'Email', value: profile.displayEmail),
        _ProfileInfo(label: 'Phone', value: profile.displayPhone),
        _ProfileInfo(label: 'Address', value: profile.displayAddress),
        _ProfileInfo(
          label: 'Date of birth',
          value: profile.dateOfBirth.isEmpty
              ? 'Not provided'
              : profile.dateOfBirth,
        ),
        _ProfileInfo(
          label: 'Gender',
          value: profile.gender.isEmpty ? 'Not provided' : profile.gender,
        ),
        _PrimaryAction(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          onTap: () {},
        ),
        const DeleteAccountButton(),
      ],
    ),
  );
}

class _SupportPage extends StatelessWidget {
  const _SupportPage();
  @override
  Widget build(BuildContext context) => const HelpSupportHomeScreen();
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();
  @override
  Widget build(BuildContext context) => _Scrollable(
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.balance, size: 64, color: Colors.white),
        SizedBox(height: 16),
        Text(
          'Aapke Lawyer',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 14),
        Text(
          'Your legal companion for discovering, connecting with, and managing trusted legal assistance.',
          style: TextStyle(fontSize: 18, height: 1.5),
        ),
        SizedBox(height: 28),
        Text(
          'For users',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 8),
        Text(
          'Find legal professionals, compare profiles, and request consultations.',
        ),
        SizedBox(height: 20),
        Text(
          'For advocates',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 8),
        Text(
          'Build a professional presence, manage requests, and serve users efficiently.',
        ),
        SizedBox(height: 32),
        Text('Version 1.0.0', style: TextStyle(color: Color(0xFFD8C8BE))),
      ],
    ),
  );
}

class _ConsultationsPage extends StatelessWidget {
  const _ConsultationsPage();
  @override
  Widget build(BuildContext context) => _Scrollable(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your upcoming consultations',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        const _AppointmentCard(
          name: 'Adv. Priya Sharma',
          matter: 'Property consultation',
          time: 'Thursday · 11:30 AM',
        ),
        const SizedBox(height: 12),
        const Text(
          'Past consultations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const _AppointmentCard(
          name: 'Adv. Arjun Kapoor',
          matter: 'Document review',
          time: '12 Jul 2026',
        ),
      ],
    ),
  );
}

class _SavedLawyersPage extends StatelessWidget {
  const _SavedLawyersPage();
  @override
  Widget build(BuildContext context) => _Scrollable(
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved advocates',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 16),
        _LawyerCard(
          name: 'Adv. Priya Sharma',
          specialty: 'Family & Civil Law · 9 years',
          rating: '4.8',
        ),
        SizedBox(height: 12),
        _LawyerCard(
          name: 'Adv. Arjun Kapoor',
          specialty: 'Corporate Law · 11 years',
          rating: '4.7',
        ),
      ],
    ),
  );
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.profile, required this.radius});

  final UserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: Colors.white,
    child: ClipOval(
      child: profile.imageUrl.isEmpty
          ? Icon(Icons.person, color: kBrown, size: radius * 1.15)
          : Image.network(
              profile.imageUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.person, color: kBrown, size: radius * 1.15),
            ),
    ),
  );
}

class _ProfileLoadingScaffold extends StatelessWidget {
  const _ProfileLoadingScaffold();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: kBrown)),
  );
}

class _ProfileErrorScaffold extends StatelessWidget {
  const _ProfileErrorScaffold({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: kBrown, size: 52),
            const SizedBox(height: 16),
            const Text(
              'Unable to load your profile. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(padding: const EdgeInsets.all(20), child: child);
}

class _DashboardStatusCard extends StatelessWidget {
  const _DashboardStatusCard({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final int count;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xE638241C),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: .18)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD8C8BE),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}

class _RecentDashboardRequest extends StatelessWidget {
  const _RecentDashboardRequest({required this.request, required this.onTap});
  final ConsultationRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (request.status) {
      ConsultationRequestStatus.pending => Colors.orange,
      ConsultationRequestStatus.accepted => Colors.green,
      ConsultationRequestStatus.completed => Colors.blueGrey,
      ConsultationRequestStatus.rejected => Colors.redAccent,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      color: const Color(0xE638241C),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .1),
          child: const Icon(Icons.gavel_outlined, color: Colors.white),
        ),
        title: Text(
          request.caseTitle.isEmpty ? 'Legal consultation' : request.caseTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${request.clientName} • ${request.category}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            request.status.name,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xE638241C),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white24),
    ),
    child: const Column(
      children: [
        Icon(Icons.inbox_outlined, size: 32, color: Colors.white),
        SizedBox(height: 8),
        Text('No consultation requests yet.'),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xE638241C),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: Color(0xFFD8C8BE))),
      ],
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.name,
    required this.matter,
    required this.time,
  });
  final String name, matter, time;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFE5CF),
        child: Icon(Icons.person, color: kBrown),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('$matter\n$time'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.text,
    required this.rating,
  });
  final String name, text;
  final int rating;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(name),
      subtitle: Text(text),
      trailing: Text(
        '$rating ★',
        style: const TextStyle(
          color: Colors.amber,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFD8C8BE),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const Divider(height: 22),
      ],
    ),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: kBrown,
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18, color: kBrown),
    label: Text(label),
    padding: const EdgeInsets.all(9),
  );
}

class _LawyerCard extends StatelessWidget {
  const _LawyerCard({
    required this.name,
    required this.specialty,
    required this.rating,
  });
  final String name, specialty, rating;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: const CircleAvatar(
        radius: 28,
        backgroundColor: kBrown,
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(specialty),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 19),
          Text(rating),
        ],
      ),
    ),
  );
}
