import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/categories/presentation/category_screen.dart';
import '../features/gift_finder/presentation/gift_finder_flow_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/favorites_screen.dart';
import 'app_scope.dart';

/// 바텀 탭 선택 상태. push된 화면에서도 탭 전환을 요청할 수 있다.
class ShellTabController extends ValueNotifier<int> {
  ShellTabController() : super(homeTab);

  static const int homeTab = 0;
  static const int categoryTab = 1;
  static const int finderTab = 2;
  static const int favoritesTab = 3;
  static const int historyTab = 4;

  /// 탭 이동. 같은 탭을 다시 눌러도 "재진입"으로 보고 알린다.
  /// 선물추천 탭은 이 신호로 완료된 세션을 새로 시작한다.
  void goTo(int index) {
    if (value == index) {
      notifyListeners();
      return;
    }
    value = index;
  }
}

/// 홈 / 카테고리 / 선물추천 / 찜 / 기록 5개 탭.
///
/// `IndexedStack`을 유지해 탭을 바꿔도 진행 중인 추천 세션과 스크롤 위치가
/// 보존된다.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final ShellTabController tab = AppScope.of(context).shellTab;

    return ValueListenableBuilder<int>(
      valueListenable: tab,
      builder: (BuildContext context, int index, _) {
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: const <Widget>[
              HomeScreen(),
              CategoryScreen(),
              GiftFinderFlowScreen(),
              FavoritesScreen(),
              HistoryScreen(),
            ],
          ),
          bottomNavigationBar: _ShellNavigationBar(
            index: index,
            onSelected: tab.goTo,
          ),
        );
      },
    );
  }
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
            tooltip: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: '카테고리',
            tooltip: '카테고리',
          ),
          // 서비스 핵심 기능이라 채워진 아이콘으로 무게를 준다.
          NavigationDestination(
            icon: Icon(Icons.redeem_outlined),
            selectedIcon: Icon(Icons.redeem),
            label: '선물추천',
            tooltip: '선물추천',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: '찜',
            tooltip: '찜한 상품',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '기록',
            tooltip: '기록',
          ),
        ],
      ),
    );
  }
}
