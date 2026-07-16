import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class IapService {
  IapService._internal();
  static final IapService instance = IapService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // 内购商品 ID (与 App Store Connect 配置的一致)
  static const String premiumProductId = 'dumpit_premium_monthly';

  // 购买成功的通知回调
  VoidCallback? onPurchaseSuccess;
  // 购买失败的通知回调
  Function(String)? onPurchaseError;
  // 状态提示回调
  Function(String)? onStatusUpdate;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isInitializing = false;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;

  /// 初始化 IAP 监听器
  void initialize({
    VoidCallback? onSuccess,
    Function(String)? onError,
    Function(String)? onStatus,
  }) {
    if (_isInitializing) return;
    _isInitializing = true;

    onPurchaseSuccess = onSuccess;
    onPurchaseError = onError;
    onStatusUpdate = onStatus;

    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        onPurchaseError?.call(error.toString());
      },
    );

    // 预先拉取商品信息
    _loadProducts();
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
  }

  /// 拉取内购商品详情
  Future<void> _loadProducts() async {
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      if (!_isAvailable) {
        onPurchaseError?.call('应用内购买在当前设备上不可用');
        return;
      }

      const Set<String> ids = {premiumProductId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(ids);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('未找到以下商品 ID: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('已成功载入商品: ${_products.length} 个');
    } catch (e) {
      debugPrint('拉取商品失败: $e');
    }
  }

  /// 发起购买黄金会员
  Future<void> buyPremium() async {
    if (!_isAvailable) {
      onPurchaseError?.call('内购服务暂不可用，请稍后再试');
      return;
    }

    if (_products.isEmpty) {
      onStatusUpdate?.call('正在拉取商品详情...');
      await _loadProducts();
    }

    if (_products.isEmpty) {
      onPurchaseError?.call('无法获取内购商品信息，请确认 App Store 配置');
      return;
    }

    final productDetails = _products.firstWhere(
      (p) => p.id == premiumProductId,
      orElse: () => _products.first,
    );

    final purchaseParam = PurchaseParam(productDetails: productDetails);
    try {
      onStatusUpdate?.call('正在拉起 App Store 支付...');
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onPurchaseError?.call('拉起支付失败: $e');
    }
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    onStatusUpdate?.call('正在向 App Store 请求恢复已购项目...');
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      onPurchaseError?.call('恢复购买失败: $e');
    }
  }

  /// 处理购买状态更新流
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        onStatusUpdate?.call('交易正在处理中，请稍候...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        onPurchaseError?.call(purchaseDetails.error?.message ?? '交易失败');
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        onStatusUpdate?.call('正在验证您的购买凭证...');
        
        // 获取苹果收据 Base64 数据
        final receipt = purchaseDetails.verificationData.serverVerificationData;
        
        try {
          // 调用 Go 后端验证
          final verified = await ApiService.verifyReceipt(receipt);
          if (verified) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('dumpit_is_premium', true);
            
            onStatusUpdate?.call('🎉 恭喜！黄金会员已激活！');
            onPurchaseSuccess?.call();
          } else {
            onPurchaseError?.call('购买凭证验证未通过，请重试');
          }
        } catch (e) {
          onPurchaseError?.call('验证凭证时网络出错: $e');
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        onPurchaseError?.call('用户已取消购买');
      }
    }
  }
}
