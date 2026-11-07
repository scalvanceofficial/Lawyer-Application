import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/lawyer_directory_profile.dart';
import '../help_support/screens/help_support_home_screen.dart';
import '../models/consultation_request.dart';
import '../models/legal_case.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../repositories/case_repository.dart';
import '../repositories/consultation_repository.dart';
import '../services/auth_service.dart';
import '../services/app_error_message.dart';
import '../services/lawyer_directory_service.dart';
import '../services/notification_service.dart';
import '../services/saved_lawyers_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_background.dart';
import '../widgets/client_portal_surface.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/subscription_gate.dart';
import '../widgets/app_select_field.dart';
import 'client/find_lawyer_page.dart';
import 'client/my_consultations_page.dart';
import 'client/my_profile_page.dart';
import 'client/saved_lawyers_page.dart';
import 'cases/case_booking_screen.dart';
import 'legal_chat_screen.dart';
import 'notifications_screen.dart';
import 'subscription_screen.dart';
import 'welcome_screen.dart';
import 'account_deletion_screen.dart';

final ButtonStyle _dashboardSectionButtonStyle = FilledButton.styleFrom(
  backgroundColor: Primary,
  foregroundColor: const Color(0xFF3A2117),
  minimumSize: const Size(0, 42),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
  shape: const StadiumBorder(),
);

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  final Set<String> _savedLawyerIds = {};
  late Future<UserProfile> _profile;
  StreamSubscription<Set<String>>? _savedLawyersSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;

  static const _titles = [
    'Aapke Lawyer',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.ensurePermissionOnEntry(context);
    });
    _profile = AuthService.currentUserProfile(UserRole.client);
    _notificationTapSubscription = NotificationService.onNotificationTap.listen(
      _openNotification,
    );
    final pendingNotification = NotificationService.consumePendingTap();
    if (pendingNotification != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNotification(pendingNotification),
      );
    }
    try {
      _savedLawyersSubscription = SavedLawyersService.watchSavedLawyerIds()
          .listen(
            (ids) {
              if (!mounted) return;
              setState(() {
                _savedLawyerIds
                  ..clear()
                  ..addAll(ids);
              });
            },
            onError: (Object error) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            },
          );
    } catch (_) {
      // The profile loader will handle an expired authentication session.
    }
  }

  @override
  void dispose() {
    _savedLawyersSubscription?.cancel();
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  void _openNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
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
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'We could not load your user profile.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() {
                      _profile = AuthService.currentUserProfile(
                        UserRole.client,
                      );
                    }),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return _dashboard(snapshot.data!);
    },
  );

  Widget _dashboard(UserProfile profile) => PopScope(
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _index != 0) setState(() => _index = 0);
    },
    child: Theme(
      data: ClientPortalSurface.theme(context),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF180B07),
        extendBody: _index == 0,
        appBar: _index == 0
            ? null
            : AppBar(
                automaticallyImplyLeading: _index == 0,
                leading: _index == 0
                    ? null
                    : IconButton(
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
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: kSurfaceWarm,
                      backgroundImage: profile.imageUrl.isEmpty
                          ? null
                          : NetworkImage(profile.imageUrl),
                      child: profile.imageUrl.isEmpty
                          ? const Icon(
                              Icons.person_outline,
                              color: kBrown,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
        drawer: _ClientDrawer(
          profile: profile,
          selectedIndex: _index,
          onSelected: (index) {
            Navigator.pop(context);
            setState(() => _index = index);
          },
          onLogout: _logout,
        ),
        body: _index == 0
            ? AuthBackground(
                overlay: .84,
                child: SafeArea(
                  bottom: false,
                  child: ClientOverviewPage(
                    profile: profile,
                    savedCount: _savedLawyerIds.length,
                    onNavigate: (index) => setState(() => _index = index),
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
              )
            : ClientPortalSurface(child: SafeArea(child: _page(profile))),
        bottomNavigationBar: _ClientBottomNavigation(
          selectedIndex: _index,
          onSelected: (index) => setState(() => _index = index),
        ),
      ),
    ),
  );

  Widget _page(UserProfile profile) => switch (_index) {
    0 => ClientOverviewPage(
      profile: profile,
      savedCount: _savedLawyerIds.length,
      onNavigate: (index) => setState(() => _index = index),
      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
    ),
    1 => ClientFindLawyerPage(
      savedLawyerIds: _savedLawyerIds,
      onSavedChanged: _toggleSaved,
    ),
    2 => const MyConsultationsPage(),
    3 => ClientSavedLawyersPage(
      savedLawyerIds: _savedLawyerIds,
      onSavedChanged: _toggleSaved,
    ),
    4 => ClientMyProfilePage(profile: profile),
    5 => SubscriptionScreen(
      role: UserRole.client,
      profile: profile,
      embedded: true,
    ),
    6 => SubscriptionGate(
      role: UserRole.client,
      profile: profile,
      child: const LegalChatScreen(),
    ),
    _ => const HelpSupportHomeScreen(),
  };

  Future<void> _toggleSaved(String lawyerId) async {
    final wasSaved = _savedLawyerIds.contains(lawyerId);
    try {
      if (wasSaved) {
        await SavedLawyersService.remove(lawyerId);
      } else {
        final added = await SavedLawyersService.save(lawyerId);
        if (!added && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Already saved.')));
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved ? 'Advocate removed from saved.' : 'Advocate saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class ClientOverviewPage extends StatelessWidget {
  const ClientOverviewPage({
    super.key,
    required this.profile,
    required this.savedCount,
    required this.onNavigate,
    required this.onMenu,
  });

  final UserProfile profile;
  final int savedCount;
  final ValueChanged<int> onNavigate;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<LegalCase>>(
    stream: CaseRepository().watchClientCases(),
    builder: (context, caseSnapshot) =>
        StreamBuilder<List<ConsultationRequest>>(
          stream: ConsultationRepository().watchClientRequests(),
          builder: (context, requestSnapshot) {
            final cases = caseSnapshot.data ?? const <LegalCase>[];
            final requests =
                requestSnapshot.data ?? const <ConsultationRequest>[];
            final pending = requests
                .where(
                  (item) => item.status == ConsultationRequestStatus.pending,
                )
                .length;
            final active = cases
                .where(
                  (item) =>
                      item.isActive && item.status != LegalCaseStatus.completed,
                )
                .length;
            final completed = cases
                .where((item) => item.status == LegalCaseStatus.completed)
                .length;
            return _buildOverview(
              context,
              pending: pending,
              active: active,
              completed: completed,
            );
          },
        ),
  );

  Widget _buildOverview(
    BuildContext context, {
    required int pending,
    required int active,
    required int completed,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
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
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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
              onTap: () => onNavigate(4),
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: kSurfaceWarm,
                backgroundImage: profile.imageUrl.isEmpty
                    ? null
                    : NetworkImage(profile.imageUrl),
                child: profile.imageUrl.isEmpty
                    ? const Icon(Icons.person_outline, color: kBrown, size: 24)
                    : null,
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
        'Your trusted legal companion',
        style: TextStyle(color: Color(0xFFEADFD8), fontSize: 15),
      ),
      const SizedBox(height: 20),
      Container(
        height: 190,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF9B653D).withValues(alpha: .9),
              const Color(0xFF2D1710).withValues(alpha: .96),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
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
              right: -10,
              top: -14,
              child: Icon(
                Icons.balance_rounded,
                size: 138,
                color: Colors.white.withValues(alpha: .09),
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
                    color: const Color(0xFFE8C8A7).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'LEGAL SUPPORT, SIMPLIFIED',
                    style: TextStyle(
                      color: Color(0xFFE8C8A7),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The right legal help,\nright when you need it.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => onNavigate(1),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Find your advocate',
                        style: TextStyle(
                          color: Color(0xFFE8C8A7),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFFE8C8A7),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _OverviewHeading(
        title: 'Your legal activity',
        action: 'View cases',
        onAction: () => onNavigate(2),
      ),
      const SizedBox(height: 10),
      GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.45,
        children: [
          _ActivityCard(
            icon: Icons.hourglass_top_rounded,
            value: '$pending',
            label: 'Pending',
            onTap: () => onNavigate(2),
          ),
          _ActivityCard(
            icon: Icons.work_outline,
            value: '$active',
            label: 'Active',
            onTap: () => onNavigate(2),
          ),
          _ActivityCard(
            icon: Icons.task_alt_outlined,
            value: '$completed',
            label: 'Completed',
            onTap: () => onNavigate(2),
          ),
          _ActivityCard(
            icon: Icons.bookmark_outline,
            value: '$savedCount',
            label: 'Saved',
            onTap: () => onNavigate(3),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Legal services',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 10),
      GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
        children: [
          _QuickAction(
            icon: Icons.person_search_outlined,
            label: 'Find advocate',
            onTap: () => onNavigate(1),
          ),
          _QuickAction(
            icon: Icons.add_circle_outline,
            label: 'New case',
            onTap: () => onNavigate(1),
          ),
          _QuickAction(
            icon: Icons.calendar_month_outlined,
            label: 'My cases',
            onTap: () => onNavigate(2),
          ),
          _QuickAction(
            icon: Icons.auto_awesome_outlined,
            label: 'NyaySaarthi',
            onTap: () => onNavigate(6),
          ),
          _QuickAction(
            icon: Icons.workspace_premium_outlined,
            label: 'My plan',
            onTap: () => onNavigate(5),
          ),
          _QuickAction(
            icon: Icons.support_agent_outlined,
            label: 'Get help',
            onTap: () => onNavigate(7),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _OverviewHeading(
        title: 'Recommended for you',
        action: 'View all',
        onAction: () => onNavigate(1),
      ),
      StreamBuilder<List<LawyerDirectoryProfile>>(
        stream: LawyerDirectoryService.watchLawyers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final lawyers = snapshot.data!.take(3).toList();
          if (lawyers.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Advocate profiles will appear here when available.',
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final lawyer in lawyers)
                Card(
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    onTap: () => onNavigate(1),
                    leading: _LawyerAvatar(lawyer: lawyer, radius: 22),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lawyer.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (lawyer.verified)
                          const Icon(
                            Icons.verified,
                            color: Colors.blue,
                            size: 18,
                          ),
                      ],
                    ),
                    subtitle: Text(
                      [
                        lawyer.expertise,
                        lawyer.location,
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
    ],
  );
}

class FindLawyerPage extends StatefulWidget {
  const FindLawyerPage({
    super.key,
    required this.savedLawyerIds,
    required this.onSavedChanged,
  });

  final Set<String> savedLawyerIds;
  final Future<void> Function(String) onSavedChanged;

  @override
  State<FindLawyerPage> createState() => _FindLawyerPageState();
}

class _FindLawyerPageState extends State<FindLawyerPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _location;
  String? _expertise;
  String? _court;
  String? _availableDay;
  _ExperienceFilter _experience = _ExperienceFilter.any;
  bool _verifiedOnly = false;

  bool get _hasFilters =>
      _location != null ||
      _expertise != null ||
      _court != null ||
      _availableDay != null ||
      _experience != _ExperienceFilter.any ||
      _verifiedOnly;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<LawyerDirectoryProfile>>(
    stream: LawyerDirectoryService.watchLawyers(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _DirectoryMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Advocate directory unavailable',
          message:
              'Firestore could not load advocate profiles. Deploy the updated rules and check your connection.',
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final all = snapshot.data!;
      final locations = _options(all.map((lawyer) => lawyer.location));
      final expertise = _options(all.map((lawyer) => lawyer.expertise));
      final courts = _options(all.map((lawyer) => lawyer.court));
      final availableDays = _options(
        all.expand((lawyer) => lawyer.availability),
      );
      final visible = all.where(_matches).toList();

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _DirectoryHeader(
              controller: _searchController,
              queryChanged: (value) => setState(() => _query = value),
              onFilter: () => _openFilters(
                locations: locations,
                expertise: expertise,
                courts: courts,
                availableDays: availableDays,
              ),
              activeFilters: _activeFilterCount,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${visible.length} advocate${visible.length == 1 ? '' : 's'} found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_hasFilters)
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _DirectoryMessage(
                icon: Icons.person_search_outlined,
                title: 'No matching advocates',
                message: 'Try a broader search or remove one or more filters.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 11),
                itemBuilder: (context, index) {
                  final lawyer = visible[index];
                  return LawyerDirectoryCard(
                    lawyer: lawyer,
                    saved: widget.savedLawyerIds.contains(lawyer.id),
                    onSaved: () => widget.onSavedChanged(lawyer.id),
                    onTap: () => showLawyerDetails(context, lawyer),
                  );
                },
              ),
            ),
        ],
      );
    },
  );

  int get _activeFilterCount => [
    _location,
    _expertise,
    _court,
    _availableDay,
    if (_experience != _ExperienceFilter.any) _experience,
    if (_verifiedOnly) true,
  ].where((value) => value != null).length;

  bool _matches(LawyerDirectoryProfile lawyer) {
    if (!lawyer.matchesSearch(_query)) return false;
    if (_location != null && lawyer.location != _location) return false;
    if (_expertise != null && lawyer.expertise != _expertise) return false;
    if (_court != null && lawyer.court != _court) return false;
    if (_availableDay != null && !lawyer.availability.contains(_availableDay)) {
      return false;
    }
    if (!_experience.matches(lawyer.experienceYears)) return false;
    if (_verifiedOnly && !lawyer.verified) return false;
    return true;
  }

  List<String> _options(Iterable<String> values) =>
      values.where((value) => value.isNotEmpty).toSet().toList()..sort();

  void _clearFilters() {
    setState(() {
      _location = null;
      _expertise = null;
      _court = null;
      _availableDay = null;
      _experience = _ExperienceFilter.any;
      _verifiedOnly = false;
    });
  }

  Future<void> _openFilters({
    required List<String> locations,
    required List<String> expertise,
    required List<String> courts,
    required List<String> availableDays,
  }) async {
    var location = _location;
    var selectedExpertise = _expertise;
    var court = _court;
    var availableDay = _availableDay;
    var experience = _experience;
    var verified = _verifiedOnly;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter advocates',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _FilterDropdown(
                  label: 'Location',
                  value: location,
                  values: locations,
                  onChanged: (value) => setSheetState(() => location = value),
                ),
                _FilterDropdown(
                  label: 'Area of expertise',
                  value: selectedExpertise,
                  values: expertise,
                  onChanged: (value) =>
                      setSheetState(() => selectedExpertise = value),
                ),
                _FilterDropdown(
                  label: 'Court type',
                  value: court,
                  values: courts,
                  onChanged: (value) => setSheetState(() => court = value),
                ),
                _FilterDropdown(
                  label: 'Available day',
                  value: availableDay,
                  values: availableDays,
                  onChanged: (value) =>
                      setSheetState(() => availableDay = value),
                ),
                AppSelectField<_ExperienceFilter>(
                  label: 'Years of experience',
                  value: experience,
                  options: _ExperienceFilter.values,
                  itemLabel: (value) => value.label,
                  onChanged: (value) => setSheetState(
                    () => experience = value ?? _ExperienceFilter.any,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: verified,
                  title: const Text('Verified advocates only'),
                  onChanged: (value) => setSheetState(() => verified = value),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() {
                          location = null;
                          selectedExpertise = null;
                          court = null;
                          availableDay = null;
                          experience = _ExperienceFilter.any;
                          verified = false;
                        }),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _location = location;
                            _expertise = selectedExpertise;
                            _court = court;
                            _availableDay = availableDay;
                            _experience = experience;
                            _verifiedOnly = verified;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Show results'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showLawyerDetails(
  BuildContext pageContext,
  LawyerDirectoryProfile lawyer,
) => showModalBottomSheet<void>(
  context: pageContext,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .78,
    maxChildSize: .95,
    builder: (context, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.all(24),
      children: [
        Center(child: _LawyerAvatar(lawyer: lawyer, radius: 48)),
        const SizedBox(height: 12),
        Text(
          lawyer.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        if (lawyer.verified)
          const Center(
            child: Chip(
              avatar: Icon(Icons.verified, color: Colors.blue, size: 18),
              label: Text('Verified advocate'),
            ),
          ),
        const SizedBox(height: 8),
        Center(child: _LawyerRatingSummary(lawyer: lawyer)),
        const SizedBox(height: 16),
        _DetailRow('Expertise', lawyer.expertise),
        _DetailRow('Experience', '${lawyer.experienceYears} years'),
        _DetailRow('Court', lawyer.court),
        _DetailRow('Location', lawyer.location),
        _DetailRow(
          'Availability',
          lawyer.availability.isEmpty
              ? 'Contact for availability'
              : lawyer.availability.join(', '),
        ),
        if (lawyer.bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(lawyer.bio, style: const TextStyle(height: 1.45)),
        ],
        const SizedBox(height: 20),
        _LawyerReviews(lawyerId: lawyer.id),
        const SizedBox(height: 22),
        SavedLawyerButton(lawyerId: lawyer.id),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              pageContext,
              MaterialPageRoute(
                builder: (_) => ClientPortalSurface(
                  child: CaseBookingScreen(lawyer: lawyer),
                ),
              ),
            );
          },
          icon: const Icon(Icons.calendar_month),
          label: const Text('Book Consultation'),
        ),
      ],
    ),
  ),
);

class _LawyerRatingSummary extends StatelessWidget {
  const _LawyerRatingSummary({required this.lawyer});

  final LawyerDirectoryProfile lawyer;

  @override
  Widget build(BuildContext context) {
    if (lawyer.reviewCount == 0) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border_rounded, color: Colors.amber),
          SizedBox(width: 6),
          Text('New advocate · No user reviews yet'),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber),
        const SizedBox(width: 5),
        Text(
          '${lawyer.rating?.toStringAsFixed(1) ?? '0.0'}  (${lawyer.reviewCount} verified review${lawyer.reviewCount == 1 ? '' : 's'})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LawyerReviews extends StatelessWidget {
  const _LawyerReviews({required this.lawyerId});

  final String lawyerId;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<LawyerDirectoryReview>>(
    stream: LawyerDirectoryService.watchReviews(lawyerId),
    builder: (context, snapshot) {
      final reviews = snapshot.data ?? const <LawyerDirectoryReview>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User reviews',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Only users who paid the case fee can leave a rating and review.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (snapshot.hasError)
            const Text('Reviews could not be loaded right now.')
          else if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (reviews.isEmpty)
            const Text('No reviews yet. Completed paid cases will appear here.')
          else
            ...reviews
                .take(10)
                .map(
                  (review) => Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  review.clientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  index < review.rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 17,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(review.review),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      );
    },
  );
}

class SavedLawyerButton extends StatefulWidget {
  const SavedLawyerButton({super.key, required this.lawyerId});

  final String lawyerId;

  @override
  State<SavedLawyerButton> createState() => _SavedLawyerButtonState();
}

class _SavedLawyerButtonState extends State<SavedLawyerButton> {
  bool _updating = false;

  Future<void> _toggle(bool saved) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      if (saved) {
        await SavedLawyersService.remove(widget.lawyerId);
      } else {
        final added = await SavedLawyersService.save(widget.lawyerId);
        if (!added && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Already saved.')));
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Advocate removed from saved.' : 'Advocate saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: SavedLawyersService.watchIsSaved(widget.lawyerId),
    builder: (context, snapshot) {
      final saved = snapshot.data ?? false;
      return OutlinedButton.icon(
        onPressed: snapshot.hasError || _updating ? null : () => _toggle(saved),
        icon: _updating
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(saved ? Icons.bookmark : Icons.bookmark_border),
        label: Text(saved ? 'Saved' : 'Save advocate'),
      );
    },
  );
}

class SavedLawyersPage extends StatelessWidget {
  const SavedLawyersPage({
    super.key,
    required this.savedLawyerIds,
    required this.onSavedChanged,
  });
  final Set<String> savedLawyerIds;
  final Future<void> Function(String) onSavedChanged;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<LawyerDirectoryProfile>>(
        future: SavedLawyersService.getProfiles(savedLawyerIds),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final saved = snapshot.data!
              .where((lawyer) => savedLawyerIds.contains(lawyer.id))
              .toList();
          if (saved.isEmpty) {
            return const _DirectoryMessage(
              icon: Icons.bookmark_border,
              title: 'No saved advocates',
              message:
                  'Tap the bookmark on an advocate profile to keep it here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: saved.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => LawyerDirectoryCard(
              lawyer: saved[index],
              saved: true,
              onSaved: () => onSavedChanged(saved[index].id),
              onTap: () => showLawyerDetails(context, saved[index]),
            ),
          );
        },
      );
}

class LawyerDirectoryCard extends StatefulWidget {
  const LawyerDirectoryCard({
    super.key,
    required this.lawyer,
    required this.saved,
    required this.onSaved,
    required this.onTap,
  });
  final LawyerDirectoryProfile lawyer;
  final bool saved;
  final Future<void> Function() onSaved;
  final VoidCallback onTap;

  @override
  State<LawyerDirectoryCard> createState() => _LawyerDirectoryCardState();
}

class _LawyerDirectoryCardState extends State<LawyerDirectoryCard> {
  bool _updating = false;

  Future<void> _toggle() async {
    if (_updating) return;
    setState(() => _updating = true);
    await widget.onSaved();
    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 1,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LawyerAvatar(lawyer: widget.lawyer, radius: 34),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.lawyer.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (widget.lawyer.verified)
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 19,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.lawyer.expertise.isEmpty
                        ? 'Legal professional'
                        : widget.lawyer.expertise,
                    style: const TextStyle(
                      color: Primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      _MiniInfo(
                        Icons.work_history_outlined,
                        '${widget.lawyer.experienceYears} yrs',
                      ),
                      _MiniInfo(
                        Icons.account_balance_outlined,
                        widget.lawyer.court,
                      ),
                      _MiniInfo(
                        Icons.location_on_outlined,
                        widget.lawyer.location,
                      ),
                      _MiniInfo(
                        Icons.star_rounded,
                        widget.lawyer.reviewCount == 0
                            ? 'New · No reviews'
                            : '${widget.lawyer.rating?.toStringAsFixed(1) ?? '0.0'} · ${widget.lawyer.reviewCount} review${widget.lawyer.reviewCount == 1 ? '' : 's'}',
                      ),
                      if (widget.lawyer.online != null)
                        _MiniInfo(
                          Icons.circle,
                          widget.lawyer.online! ? 'Online' : 'Offline',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _updating ? null : _toggle,
              tooltip: widget.saved ? 'Remove saved advocate' : 'Save advocate',
              icon: _updating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(widget.saved ? Icons.bookmark : Icons.bookmark_border),
            ),
          ],
        ),
      ),
    ),
  );
}

class ClientProfilePage extends StatelessWidget {
  const ClientProfilePage({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => StreamBuilder<UserProfile>(
    stream: AuthService.watchCurrentUserProfile(UserRole.client),
    initialData: profile,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text(appErrorMessage(snapshot.error!)));
      }
      final liveProfile = snapshot.data ?? profile;
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: liveProfile.imageUrl.isEmpty
                  ? null
                  : NetworkImage(liveProfile.imageUrl),
              child: liveProfile.imageUrl.isEmpty
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            liveProfile.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          _ProfileTile(Icons.email_outlined, 'Email', liveProfile.displayEmail),
          _ProfileTile(Icons.phone_outlined, 'Phone', liveProfile.displayPhone),
          _ProfileTile(
            Icons.home_outlined,
            'Address',
            liveProfile.displayAddress,
          ),
          _ProfileTile(
            Icons.cake_outlined,
            'Date of birth',
            liveProfile.dateOfBirth.isEmpty
                ? 'Not provided'
                : liveProfile.dateOfBirth,
          ),
          _ProfileTile(
            Icons.person_outline,
            'Gender',
            liveProfile.gender.isEmpty ? 'Not provided' : liveProfile.gender,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: const Color(0xFF352019),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => _EditClientProfileSheet(profile: liveProfile),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          const DeleteAccountButton(),
        ],
      );
    },
  );
}

class _EditClientProfileSheet extends StatefulWidget {
  const _EditClientProfileSheet({required this.profile});
  final UserProfile profile;
  @override
  State<_EditClientProfileSheet> createState() =>
      _EditClientProfileSheetState();
}

class _EditClientProfileSheetState extends State<_EditClientProfileSheet> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _address = TextEditingController(text: widget.profile.address);
  late final _dob = TextEditingController(text: widget.profile.dateOfBirth);
  late final _gender = TextEditingController(text: widget.profile.gender);
  late final _bio = TextEditingController(text: widget.profile.bio);
  Uint8List? _image;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _dob.dispose();
    _gender.dispose();
    _bio.dispose();
    super.dispose();
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
      if (bytes != null && mounted) setState(() => _image = bytes);
    } catch (error) {
      if (mounted) setState(() => _error = appErrorMessage(error));
    }
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false) || _saving) return;
    if (widget.profile.imageUrl.isEmpty && _image == null) {
      setState(() => _error = 'Please add a profile photo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.updateClientProfile(
        values: {
          'name': _name.text.trim(),
          'address': _address.text.trim(),
          'dob': _dob.text.trim(),
          'gender': _gender.text.trim(),
          'bio': _bio.text.trim(),
        },
        imageBytes: _image,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Required' : null;
  Widget _field(
    String label,
    TextEditingController controller, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      validator: _required,
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
      height: MediaQuery.sizeOf(context).height * .72,
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
          const SizedBox(height: 10),
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
          Expanded(
            child: Form(
              key: _key,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ProfileAvatar(
                      imageBytes: _image,
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
                    _field('Address', _address, lines: 2),
                    _field('Date of birth', _dob),
                    _field('Gender', _gender),
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
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClientDrawer extends StatelessWidget {
  const _ClientDrawer({
    required this.profile,
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
  });
  final UserProfile profile;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: const Color(0xFF21110C),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7A482A), Color(0xFF321A12)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: profile.imageUrl.isEmpty
                      ? null
                      : NetworkImage(profile.imageUrl),
                  child: profile.imageUrl.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'User account',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...[
            (Icons.dashboard_outlined, 'Dashboard'),
            (Icons.search, 'Find an advocate'),
            (Icons.calendar_month_outlined, 'My consultations'),
            (Icons.bookmark_outline, 'Saved advocates'),
            (Icons.person_outline, 'My profile'),
            (Icons.workspace_premium_outlined, 'Subscription'),
            (Icons.auto_awesome_outlined, 'NyaySaarthi'),
            (Icons.help_outline, 'Help & support'),
          ].indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ListTile(
                selected: selectedIndex == entry.$1,
                leading: Icon(entry.$2.$1),
                title: Text(
                  entry.$2.$2,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: selectedIndex == entry.$1
                    ? const Icon(Icons.chevron_right, color: kBrown)
                    : null,
                onTap: () => onSelected(entry.$1),
              ),
            ),
          ),
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
}

class _ClientBottomNavigation extends StatelessWidget {
  const _ClientBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _pages = [0, 1, 2, 3, 6];

  @override
  Widget build(BuildContext context) {
    final selected = _pages.contains(selectedIndex)
        ? _pages.indexOf(selectedIndex)
        : 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF21110C).withValues(alpha: .96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
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
                    : const Color(0xFFD8C8BE),
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? Primary
                    : const Color(0xFFD8C8BE),
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          child: NavigationBar(
            height: 68,
            selectedIndex: selected,
            onDestinationSelected: (value) => onSelected(_pages[value]),
            backgroundColor: Colors.transparent,
            indicatorColor: Primary,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_search_outlined),
                selectedIcon: Icon(Icons.person_search_rounded),
                label: 'Find',
              ),
              NavigationDestination(
                icon: Icon(Icons.work_outline_rounded),
                selectedIcon: Icon(Icons.work_rounded),
                label: 'Cases',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_outline_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Saved',
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

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    required this.controller,
    required this.queryChanged,
    required this.onFilter,
    required this.activeFilters,
  });
  final TextEditingController controller;
  final ValueChanged<String> queryChanged;
  final VoidCallback onFilter;
  final int activeFilters;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .09),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: .15)),
      ),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find the right legal expert',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Search by name, legal issue, court, location, or availability.',
          style: TextStyle(color: Color(0xFFD8C8BE)),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: queryChanged,
                decoration: InputDecoration(
                  hintText: 'Search all advocates',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            queryChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Badge(
              isLabelVisible: activeFilters > 0,
              label: Text('$activeFilters'),
              child: IconButton.filledTonal(
                onPressed: onFilter,
                icon: const Icon(Icons.tune),
                tooltip: 'Filter advocates',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white.withValues(alpha: .11),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withValues(alpha: .17)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD8C8BE),
                      fontSize: 12,
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
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .11),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Colors.white.withValues(alpha: .17)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8C8A7).withValues(alpha: .16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverviewHeading extends StatelessWidget {
  const _OverviewHeading({
    required this.title,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      FilledButton(
        onPressed: onAction,
        style: _dashboardSectionButtonStyle,
        child: Text(action),
      ),
    ],
  );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppSelectField<String>(
      label: label,
      value: value,
      options: values,
      itemLabel: (value) => value,
      clearLabel: 'Any',
      onChanged: onChanged,
    ),
  );
}

enum _ExperienceFilter {
  any('Any experience'),
  junior('0–2 years'),
  established('3–5 years'),
  senior('6–10 years'),
  veteran('10+ years');

  const _ExperienceFilter(this.label);
  final String label;

  bool matches(int years) => switch (this) {
    any => true,
    junior => years <= 2,
    established => years >= 3 && years <= 5,
    senior => years >= 6 && years <= 10,
    veteran => years > 10,
  };
}

class _LawyerAvatar extends StatelessWidget {
  const _LawyerAvatar({required this.lawyer, required this.radius});
  final LawyerDirectoryProfile lawyer;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFF2E7DD),
    backgroundImage: lawyer.imageUrl.isEmpty
        ? null
        : NetworkImage(lawyer.imageUrl),
    child: lawyer.imageUrl.isEmpty
        ? Icon(Icons.person, size: radius, color: kBrown)
        : null,
  );
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: const Color(0xFFD8C8BE)),
      const SizedBox(width: 3),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
        child: Text(
          text.isEmpty ? 'Not provided' : text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFD8C8BE), fontSize: 12),
        ),
      ),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(label, style: const TextStyle(color: Color(0xFFD8C8BE))),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label),
      subtitle: Text(value),
    ),
  );
}

class _DirectoryMessage extends StatelessWidget {
  const _DirectoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 55, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
