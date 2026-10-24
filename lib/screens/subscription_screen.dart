import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/apple_purchase_service.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_and_conditions_screen.dart';

import '../models/subscription_plan.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../widgets/client_portal_surface.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    required this.role,
    required this.profile,
    this.embedded = false,
  });

  final UserRole role;
  final UserProfile profile;
  final bool embedded;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _processingPlan;
  late Future<SubscriptionAccess> _access;
  String _productIds = '';
  Future<void>? _products;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _access = SubscriptionService.access(widget.role);
    if (ApplePurchaseService.supported) {
      ApplePurchaseService.instance.changes.addListener(_reloadAccess);
    }
  }

  void _reloadAccess() {
    if (mounted) {
      setState(() => _access = SubscriptionService.access(widget.role));
    }
  }

  @override
  void dispose() {
    ApplePurchaseService.instance.changes.removeListener(_reloadAccess);
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    try {
      await ApplePurchaseService.instance.restore();
      _reloadAccess();
    } catch (_) {
      _showError(
        'Restore could not finish. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Widget _planList(List<SubscriptionPlan> plans) {
    Widget cards({bool appleReady = false}) => Column(
      children: [
        for (final plan in plans) ...[
          _PlanCard(
            plan: plan,
            appleProduct: ApplePurchaseService.supported
                ? ApplePurchaseService.instance.products[plan.appleProductId]
                : null,
            processing: _processingPlan == plan.documentId,
            disabled:
                _processingPlan != null ||
                _restoring ||
                (ApplePurchaseService.supported &&
                    (!appleReady ||
                        !ApplePurchaseService.instance.products.containsKey(
                          plan.appleProductId,
                        ))),
            onChoose: () => _subscribe(plan),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
    if (!ApplePurchaseService.supported) return cards();
    final ids = plans
        .map((p) => p.appleProductId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final key = (ids.toList()..sort()).join(',');
    if (_products == null || key != _productIds) {
      _productIds = key;
      _products = ApplePurchaseService.instance.loadProducts(ids);
    }
    return FutureBuilder<void>(
      future: _products,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text('Could not load App Store plans.'),
              TextButton(
                onPressed: () => setState(() => _products = null),
                child: const Text('Retry'),
              ),
            ],
          );
        }
        return Column(
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(),
            cards(appleReady: snapshot.connectionState == ConnectionState.done),
          ],
        );
      },
    );
  }

  Future<void> _subscribe(SubscriptionPlan plan) async {
    if (_processingPlan != null) return;
    setState(() => _processingPlan = plan.documentId);
    try {
      final access = await SubscriptionService.subscribe(
        plan: plan,
        role: widget.role,
        name: widget.profile.name,
        email: widget.profile.email,
        phone: widget.profile.phone,
      );
      if (!mounted) return;
      setState(() => _access = Future.value(access));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            access.isActive
                ? 'Subscription active until ${_dateLabel(access.endDate!)}.'
                : 'Purchase checked. No active subscription is currently available.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      if (!widget.embedded && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on SubscriptionActivationException catch (error) {
      await _showActivationProblem(error, plan);
    } on SubscriptionException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(
        'We could not confirm your subscription. Restore purchases or contact support before paying again.',
      );
    } finally {
      if (mounted) setState(() => _processingPlan = null);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showActivationProblem(
    SubscriptionActivationException error,
    SubscriptionPlan plan,
  ) async {
    if (!mounted) return;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('Payment received, activation needs help'),
        content: SelectableText(
          '${error.message}\n\nPayment ID: ${error.paymentId}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retry activation'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I saved the payment ID'),
          ),
        ],
      ),
    );
    if (retry == true && mounted) {
      try {
        final access = await SubscriptionService.activateRazorpayPayment(
          paymentId: error.paymentId,
          plan: plan,
          role: widget.role,
        );
        if (mounted) setState(() => _access = Future.value(access));
      } catch (_) {
        _showError(
          'Activation is still pending. Save payment ID ${error.paymentId} and contact support before paying again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: () async {
        setState(() => _access = SubscriptionService.access(widget.role));
        await _access;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Choose your access plan',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            ApplePurchaseService.supported
                ? 'Choose an Apple subscription for access to NyaySaarthi. Payment starts when you subscribe.'
                : 'Advocates receive one month of free access. Choose a plan to continue using NyaySaarthi.',
            style: TextStyle(color: Color(0xFFD8C8BE)),
          ),
          const SizedBox(height: 18),
          FutureBuilder<SubscriptionAccess>(
            future: _access,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return _AccessBanner(access: snapshot.data!);
            },
          ),
          const SizedBox(height: 18),
          StreamBuilder<List<SubscriptionPlan>>(
            stream: SubscriptionService.plans(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _MessageCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load plans',
                  message: 'Check your connection, then pull down to retry.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const _MessageCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'No plans available',
                  message:
                      'Subscriptions are currently unavailable. Please try again later.',
                );
              }
              return _planList(snapshot.data!);
            },
          ),
          if (ApplePurchaseService.supported) ...[
            ValueListenableBuilder<String?>(
              valueListenable: ApplePurchaseService.instance.message,
              builder: (context, message, _) =>
                  message == null ? const SizedBox.shrink() : Text(message),
            ),
            const SizedBox(height: 12),
            const Text(
              'Subscriptions renew automatically unless canceled in your Apple account settings at least 24 hours before the current period ends. Your Apple account will be charged at confirmation. Any existing app trial does not delay Apple billing.',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _restoring || _processingPlan != null
                      ? null
                      : _restore,
                  child: Text(_restoring ? 'Restoring…' : 'Restore Purchases'),
                ),
                TextButton(
                  onPressed: () async {
                    final opened = await launchUrl(
                      Uri.parse('https://apps.apple.com/account/subscriptions'),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened) {
                      _showError(
                        'Open Settings, your Apple account, then Subscriptions.',
                      );
                    }
                  },
                  child: const Text('Manage Subscription'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                  child: const Text('Privacy Policy'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsAndConditionsScreen(),
                    ),
                  ),
                  child: const Text('Terms of Service'),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) return content;
    return ClientPortalSurface(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Subscription')),
        body: SafeArea(child: content),
      ),
    );
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.access});
  final SubscriptionAccess access;

  @override
  Widget build(BuildContext context) {
    final trial = access.source == SubscriptionAccessSource.lawyerTrial;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: access.isActive
            ? Colors.green.withValues(alpha: .14)
            : Colors.orange.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: access.isActive
              ? Colors.green.withValues(alpha: .35)
              : Colors.orange.withValues(alpha: .35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            access.isActive ? Icons.verified_outlined : Icons.info_outline,
            color: access.isActive ? Colors.green.shade700 : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: trial
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your first month is free until ${_dateLabel(access.endDate!)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'You can use NyaySaarthi chat, court, and legal resources '
                        'now—no payment is needed during this free month.',
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'After this date, a paid plan is required. Apple subscriptions start billing immediately when purchased.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                : Text(
                    access.isActive
                        ? 'Your paid subscription is active until ${_dateLabel(access.endDate!)}.'
                        : access.message!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.processing,
    required this.disabled,
    required this.onChoose,
    this.appleProduct,
  });

  final SubscriptionPlan plan;
  final ProductDetails? appleProduct;
  final bool processing;
  final bool disabled;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => Card(
    elevation: plan.popular ? 5 : 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: plan.popular ? const Color(0xFFE8C8A7) : Colors.white24,
        width: plan.popular ? 2 : 1,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.popular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kBrown,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          if (plan.popular) const SizedBox(height: 12),
          Text(
            appleProduct?.title ?? plan.duration,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            ApplePurchaseService.supported
                ? (appleProduct?.price ?? 'Unavailable')
                : '₹${plan.price}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE8C8A7),
            ),
          ),
          if (appleProduct != null)
            Text(ApplePurchaseService.instance.billingPeriod(appleProduct!)),
          if (!ApplePurchaseService.supported && plan.discount > 0)
            Text(
              '${plan.discount}% discount included',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 14),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 9),
                  Expanded(child: Text(feature)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: disabled ? null : onChoose,
              child: Text(
                processing
                    ? 'Processing…'
                    : ApplePurchaseService.supported
                    ? 'Subscribe with Apple'
                    : 'Choose plan',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
