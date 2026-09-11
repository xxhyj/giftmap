import 'package:flutter/material.dart';

import '../features/gift_finder/presentation/gift_finder_flow_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'app_scope.dart';

/// 바텀 탭 선택 상태. push된 화면에서도 탭 전환을 요청할 수 있다.
class ShellTabController extends ValueNotifier<int> {
  ShellTabController() : super(homeTab);

  static const int homeTab = 0;
  static const int finderTab = 1;
  static const int libraryTab = 2;

  void goTo(int index) => value = index;
}

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
              GiftFinderFlowScreen(),
              LibraryScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: tab.goTo,
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.card_giftcard_outlined),
                selectedIcon: Icon(Icons.card_giftcard),
                label: '선물 찾기',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: '보관함',
              ),
            ],
          ),
        );
      },
    );
  }
}
