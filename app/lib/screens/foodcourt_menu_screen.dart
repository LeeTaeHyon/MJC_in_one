import "package:flutter/material.dart";
import "package:mjc_in_one/services/foodcourt_menu.dart";
import "package:mjc_in_one/services/app_config_service.dart";
import "package:mjc_in_one/theme/app_colors.dart";

class FoodcourtMenuScreen extends StatefulWidget {
  const FoodcourtMenuScreen({super.key});

  @override
  State<FoodcourtMenuScreen> createState() => _FoodcourtMenuScreenState();
}

class _FoodcourtMenuScreenState extends State<FoodcourtMenuScreen> {
  late Future<List<FoodcourtMenuItem>> _menuFuture;
  final FoodcourtMenuService _service = FoodcourtMenuService();

  static const List<String> _preferredShopOrderFallback = [
    "바비든든",
    "포포420",
    "경성카츠",
    "비비고고",
    "값찌개",
  ];

  static const Map<String, String> _shopEmojiFallback = {
    "바비든든": "🍚",
    "포포420": "🍜",
    "경성카츠": "🐷",
    "비비고고": "🥗",
    "값찌개": "🍲",
  };

  List<String> _preferredShopOrder = _preferredShopOrderFallback;
  Map<String, String> _shopEmoji = _shopEmojiFallback;

  static const TextStyle _appBarTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w800,
  );

  @override
  void initState() {
    super.initState();
    _menuFuture = _service.load();
    _loadFoodcourtMeta();
  }

  Future<void> _loadFoodcourtMeta() async {
    try {
      final FoodcourtMetaConfig? meta = await AppConfigService.loadFoodcourtMeta();
      if (!mounted || meta == null) return;
      setState(() {
        if (meta.preferredShopOrder.isNotEmpty) {
          _preferredShopOrder = meta.preferredShopOrder;
        }
        if (meta.shopEmoji.isNotEmpty) {
          _shopEmoji = meta.shopEmoji;
        }
      });
    } catch (_) {
      // Keep fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<FoodcourtMenuItem>>(
      future: _menuFuture,
      builder: (context, snapshot) {
        final bool loading =
            snapshot.connectionState == ConnectionState.waiting;
        final List<FoodcourtMenuItem> items = snapshot.data ?? const [];

        if (!loading && items.isNotEmpty) {
          final Map<String, List<FoodcourtMenuItem>> grouped =
              _service.groupByShop(items);
          final List<String> shops = _orderedShops(grouped.keys.toList());

          return DefaultTabController(
            length: shops.length,
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                title: const Text("학식 메뉴"),
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                foregroundColor: scheme.onPrimary,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleTextStyle: _appBarTitleStyle,
                toolbarTextStyle: _appBarTitleStyle,
                bottom: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: scheme.onPrimary,
                  unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.75),
                  indicatorColor: scheme.onPrimary,
                  indicatorWeight: 3,
                  dividerColor: scheme.onPrimary.withValues(alpha: 0.18),
                  tabs: [for (final s in shops) Tab(text: s)],
                ),
              ),
              body: TabBarView(
                children: [
                  for (final String shop in shops)
                    _ShopTabList(
                      shop: shop,
                      items: grouped[shop] ?? const [],
                      shopEmoji: _shopEmoji,
                    ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text("학식 메뉴"),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: scheme.onPrimary,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: _appBarTitleStyle,
            toolbarTextStyle: _appBarTitleStyle,
          ),
          body: loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 220),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 220),
                    Center(child: Text("등록된 학식 메뉴가 없습니다.")),
                  ],
                ),
        );
      },
    );
  }

  List<String> _orderedShops(List<String> raw) {
    final Set<String> all =
        raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final List<String> ordered = [
      for (final s in _preferredShopOrder)
        if (all.contains(s)) s,
    ];
    final Set<String> seen = ordered.toSet();
    final List<String> extras = all.where((s) => !seen.contains(s)).toList()
      ..sort();
    return [...ordered, ...extras];
  }
}

class _ShopTabList extends StatelessWidget {
  const _ShopTabList({
    required this.shop,
    required this.items,
    required this.shopEmoji,
  });

  final String shop;
  final List<FoodcourtMenuItem> items;
  final Map<String, String> shopEmoji;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          "가격은 교내 자료 기준이며 변동될 수 있습니다.",
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _MenuListCard(shop: shop, items: items, shopEmoji: shopEmoji),
      ],
    );
  }
}

class _MenuListCard extends StatelessWidget {
  const _MenuListCard({
    required this.shop,
    required this.items,
    required this.shopEmoji,
  });

  final String shop;
  final List<FoodcourtMenuItem> items;
  final Map<String, String> shopEmoji;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.surface,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (shopEmoji[shop.trim()] ?? "").trim().isEmpty
                          ? "🍽️"
                          : (shopEmoji[shop.trim()] ?? "🍽️"),
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shop,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  "${items.length}개",
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final FoodcourtMenuItem item in items)
              _MenuPriceRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _MenuPriceRow extends StatelessWidget {
  const _MenuPriceRow({required this.item});

  final FoodcourtMenuItem item;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color priceColor =
        isDark ? AppColors.switchActiveDark : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.menu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item.formattedPrice,
            style: TextStyle(
              color: priceColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
