import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_service.dart';

class NetworkPurchasesSection extends StatefulWidget {
  const NetworkPurchasesSection({super.key});

  @override
  State<NetworkPurchasesSection> createState() => _NetworkPurchasesSectionState();
}

class _NetworkPurchasesSectionState extends State<NetworkPurchasesSection> {
  final ApiService _api = ApiService();
  late Future<List<NetworkPurchaseModel>> _purchasesFuture;

  @override
  void initState() {
    super.initState();
    _purchasesFuture = _api.getNetworkPurchases(limit: 10);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<NetworkPurchaseModel>>(
      future: _purchasesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }

        final purchases = snapshot.data ?? [];

        if (purchases.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      color: AppColors.electricBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'What your network bought',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to full network purchases page
                      },
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: purchases.length,
                  itemBuilder: (context, index) {
                    final purchase = purchases[index];
                    return _NetworkPurchaseCard(
                      purchase: purchase,
                      isDark: isDark,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _NetworkPurchaseCard extends StatelessWidget {
  final NetworkPurchaseModel purchase;
  final bool isDark;

  const _NetworkPurchaseCard({
    required this.purchase,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            // TODO: Navigate to product details
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.electricBlue.withValues(alpha: 0.3),
                      AppColors.electricBlue.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: purchase.productImage.isNotEmpty
                    ? Image.network(
                        purchase.productImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: Colors.white70,
                          );
                        },
                      )
                    : const Icon(
                        Icons.shopping_bag_outlined,
                        size: 40,
                        color: Colors.white70,
                      ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Title
                    Text(
                      purchase.productTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Price
                    Text(
                      '\$${purchase.productPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.electricBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Buyer Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: purchase.buyerAvatar != null
                              ? NetworkImage(purchase.buyerAvatar!)
                              : null,
                          backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                          child: purchase.buyerAvatar == null
                              ? Text(
                                  purchase.buyerName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            purchase.buyerName,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Time ago
                    Text(
                      _getTimeAgo(purchase.purchaseDate),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
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

  String _getTimeAgo(String dateStr) {
    try {
      final dateTime = DateTime.parse(dateStr);
      final difference = DateTime.now().difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}
