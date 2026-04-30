import "package:flutter/material.dart";
import "package:mio_notice/services/foodcourt_menu.dart";
import "package:mio_notice/theme/app_colors.dart";

class FoodcourtMenuScreen extends StatefulWidget {
  const FoodcourtMenuScreen({super.key});

  @override
  State<FoodcourtMenuScreen> createState() => _FoodcourtMenuScreenState();
}

class _FoodcourtMenuScreenState extends State<FoodcourtMenuScreen> {
  late Future<List<FoodcourtMenuItem>> _menuFuture;
  final FoodcourtMenuService _service = FoodcourtMenuService();

  @override
  void initState() {
    super.initState();
    _menuFuture = _service.loadFromAsset();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _menuFuture = _service.loadFromAsset();
    });
    await _menuFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("학식 메뉴"),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<FoodcourtMenuItem>>(
          future: _menuFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<FoodcourtMenuItem> items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: Text("등록된 학식 메뉴가 없습니다.")),
                ],
              );
            }

            final Map<String, List<FoodcourtMenuItem>> grouped =
                _service.groupByShop(items);
            final List<String> shops = grouped.keys.toList()..sort();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const Text(
                  "푸드코트별 메뉴",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "가격은 교내 자료 기준이며 변동될 수 있습니다.",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                for (final String shop in shops) ...[
                  _ShopMenuSection(
                    shop: shop,
                    items: grouped[shop] ?? const [],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShopMenuSection extends StatelessWidget {
  const _ShopMenuSection({
    required this.shop,
    required this.items,
  });

  final String shop;
  final List<FoodcourtMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black12,
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
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.primary,
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
                  style: const TextStyle(
                    color: Colors.black54,
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
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
