import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/allocation/presentation/offered_today_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/batches/data/batches_repository.dart';
import '../../features/batches/presentation/batches_screens.dart';
import '../../features/bid_book/data/bid_book_repository.dart';
import '../../features/bid_book/presentation/bid_book_screens.dart';
import '../../features/contracts/data/contracts_repository.dart';
import '../../features/contracts/presentation/contracts_screens.dart';
import '../../features/courier/data/courier_repository.dart';
import '../../features/courier/presentation/courier_screens.dart';
import '../../features/ex_factory/data/ex_factory_repository.dart';
import '../../features/ex_factory/presentation/ex_factory_screens.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/offer_lists/data/offer_lists_repository.dart';
import '../../features/offer_lists/presentation/offer_lists_screens.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/samples/data/samples_repository.dart';
import '../../features/samples/domain/sample.dart';
import '../../features/samples/presentation/sample_detail_screen.dart';
import '../../features/samples/presentation/sample_form_screen.dart';
import '../../features/samples/presentation/samples_list_screen.dart';
import '../../features/sales_register/data/sales_repository.dart';
import '../../features/sales_register/presentation/sales_screens.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../storage/prefs.dart';
import '../widgets/detail_loader.dart';
import 'routes.dart';
import 'shell_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pushes [child] above the tab bar (forms and detail screens).
GoRoute _top(String path, String name, Widget Function(GoRouterState s) child) => GoRoute(
      path: path,
      name: name,
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, s) => child(s),
    );

T? _extra<T>(GoRouterState s) => s.extra is T ? s.extra as T : null;

/// Detail route body: shows the list's copy at once, refreshes from the API.
Widget _detail<T>(
  GoRouterState s,
  String what,
  Future<T> Function(WidgetRef ref, int id) fetch,
  Widget Function(T item) builder,
) {
  return DetailLoader<T>(
    key: ValueKey(s.uri.toString()),
    id: int.tryParse(s.pathParameters['id'] ?? ''),
    initial: _extra<T>(s),
    fetch: fetch,
    builder: builder,
    what: what,
  );
}

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  ref.listen(onboardingSeenProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) return loc == '/splash' ? null : '/splash';

      final signedIn = auth.value is Authenticated;
      final seen = ref.read(onboardingSeenProvider);
      const open = {'/onboarding', '/login'};
      if (loc.startsWith('/legal')) return null;

      if (!signedIn) {
        if (!seen) return loc == '/onboarding' ? null : '/onboarding';
        if (loc == '/login') return null;
        final from = loc == '/splash' || open.contains(loc) ? '' : '?from=${Uri.encodeComponent(state.uri.toString())}';
        return '/login$from';
      }
      if (loc == '/splash' || open.contains(loc)) {
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') ? from : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', name: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', name: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', name: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/legal/:doc', name: Routes.legal, builder: (_, s) => LegalScreen(doc: s.pathParameters['doc']!)),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/samples',
              name: Routes.samples,
              builder: (_, _) => const SamplesListScreen(),
              routes: [
                _top('new', Routes.sampleNew, (_) => const SampleFormScreen()),
                GoRoute(path: 'batches', name: Routes.batches, builder: (_, _) => const BatchesListScreen(), routes: [
                  _top('new', Routes.batchNew, (_) => const BatchFormScreen()),
                  _top('auto', Routes.batchAuto, (_) => const AutoBatchScreen()),
                  GoRoute(path: ':id', name: Routes.batchDetail, builder: (_, s) => _detail<Batch>(s, 'batch', (r, id) => r.read(batchesRepositoryProvider).get(id), (x) => BatchDetailScreen(batch: x)), routes: [
                    _top('edit', Routes.batchEdit, (s) => BatchEditScreen(batch: _extra<Batch>(s))),
                  ]),
                ]),
                GoRoute(path: ':id', name: Routes.sampleDetail, routes: [
                  _top('edit', Routes.sampleEdit, (s) => SampleFormScreen(editing: _extra<Sample>(s))),
                ], builder: (_, s) => _detail<Sample>(s, 'sample', (r, id) => r.read(samplesRepositoryProvider).get(id), (x) => SampleDetailScreen(sample: x))),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/offers',
              name: Routes.offers,
              builder: (_, _) => const OfferListsScreen(),
              routes: [
                _top('new', Routes.offerNew, (_) => const OfferFormScreen()),
                GoRoute(path: 'today', name: Routes.offeredToday, builder: (_, _) => const OfferedTodayScreen()),
                GoRoute(path: ':id', name: Routes.offerDetail, builder: (_, s) => _detail<OfferList>(s, 'offer', (r, id) => r.read(offerListsRepositoryProvider).get(id), (x) => OfferDetailScreen(offer: x))),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', name: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bids',
              name: Routes.bids,
              builder: (_, _) => const BidBookScreen(),
              routes: [
                _top('new', Routes.bidNew, (_) => const BidFormScreen()),
                GoRoute(path: ':id', name: Routes.bidDetail, builder: (_, s) => _detail<Bid>(s, 'lot', (r, id) => r.read(bidBookRepositoryProvider).get(id), (x) => BidDetailScreen(bid: x)), routes: [
                  _top('edit', Routes.bidEdit, (s) => BidFormScreen(editing: _extra<Bid>(s))),
                ]),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              name: Routes.more,
              builder: (_, _) => const MoreScreen(),
              routes: [
                GoRoute(path: 'courier', name: Routes.courier, builder: (_, _) => const CourierListScreen(), routes: [
                  _top('new', Routes.courierNew, (_) => const CourierFormScreen()),
                  GoRoute(path: ':id', name: Routes.courierDetail, builder: (_, s) => _detail<CourierEntry>(s, 'courier entry', (r, id) => r.read(courierRepositoryProvider).get(id), (x) => CourierDetailScreen(entry: x)), routes: [
                    _top('edit', Routes.courierEdit, (s) => CourierFormScreen(editing: _extra<CourierEntry>(s))),
                  ]),
                ]),
                GoRoute(path: 'contracts', name: Routes.contracts, builder: (_, _) => const ContractsListScreen(), routes: [
                  _top('new', Routes.contractNew, (_) => const ContractFormScreen()),
                  GoRoute(path: ':id', name: Routes.contractDetail, builder: (_, s) => _detail<Contract>(s, 'contract', (r, id) => r.read(contractsRepositoryProvider).get(id), (x) => ContractDetailScreen(contract: x)), routes: [
                    _top('edit', Routes.contractEdit, (s) => ContractFormScreen(editing: _extra<Contract>(s))),
                  ]),
                ]),
                GoRoute(path: 'sales', name: Routes.sales, builder: (_, _) => const SalesListScreen(), routes: [
                  _top('new', Routes.salesNew, (_) => const SalesFormScreen()),
                  GoRoute(path: ':id', name: Routes.salesDetail, builder: (_, s) => _detail<SaleEntry>(s, 'sale', (r, id) => r.read(salesRepositoryProvider).get(id), (x) => SalesDetailScreen(entry: x))),
                ]),
                GoRoute(path: 'ex-factory', name: Routes.exFactory, builder: (_, _) => const ExFactoryListScreen(), routes: [
                  _top('new', Routes.exFactoryNew, (_) => const ExFactoryFormScreen()),
                  GoRoute(path: ':id', name: Routes.exFactoryDetail, builder: (_, s) => _detail<ExFactoryBill>(s, 'bill', (r, id) => r.read(exFactoryRepositoryProvider).get(id), (x) => ExFactoryDetailScreen(bill: x))),
                ]),
                GoRoute(path: 'settings', name: Routes.settings, builder: (_, _) => const SettingsScreen()),
              ],
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (_, s) => const _NotFound(),
  );
});

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This page doesn't exist."),
            TextButton(onPressed: () => context.go('/home'), child: const Text('Go home')),
          ],
        ),
      ),
    );
  }
}
