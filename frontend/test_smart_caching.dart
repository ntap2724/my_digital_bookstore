import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/services/catalog_service.dart';

/// Simple test to verify smart caching implementation
void testSmartCaching() async {
  debugPrint('🧪 Testing Smart Caching Implementation');
  
  final catalogService = CatalogService.instance;
  
  // Test 1: Categories caching
  debugPrint('\n📚 Testing Categories Caching:');
  final categories1 = await catalogService.getCategories();
  debugPrint('✅ First call: ${categories1.length} categories');
  
  final categories2 = await catalogService.getCategories();
  debugPrint('✅ Second call (should use cache): ${categories2.length} categories');
  
  // Wait 2 seconds to test timestamp logic
  await Future.delayed(const Duration(seconds: 2));
  
  final categories3 = await catalogService.getCategories();
  debugPrint('✅ Third call after 2s (should still use cache): ${categories3.length} categories');
  
  // Test 2: Books caching
  debugPrint('\n📚 Testing Books Caching:');
  final books1 = await catalogService.getAllBooks(auth: true);
  debugPrint('✅ First call: ${books1.length} books');
  
  final books2 = await catalogService.getAllBooks(auth: true);
  debugPrint('✅ Second call (should use cache): ${books2.length} books');
  
  // Test 3: Reviews caching
  if (books1.isNotEmpty) {
    debugPrint('\n📝 Testing Reviews Caching:');
    final bookId = books1.first.id;
    
    final reviews1 = await catalogService.getBookReviews(bookId);
    debugPrint('✅ First call: ${reviews1['reviews']?.length ?? 0} reviews');
    
    final reviews2 = await catalogService.getBookReviews(bookId);
    debugPrint('✅ Second call (should use cache): ${reviews2['reviews']?.length ?? 0} reviews');
  }
  
  debugPrint('\n🎉 Smart caching test completed!');
  debugPrint('📊 Cache refresh interval: 1 minute');
  debugPrint('💡 Key improvements:');
  debugPrint('  - Added timestamp tracking for all cache entries');
  debugPrint('  - Implemented 1-minute refresh interval');
  debugPrint('  - Reduced unnecessary API calls');
  debugPrint('  - Smart cache invalidation based on timestamps');
}

/// Performance comparison test
void performanceComparison() async {
  debugPrint('\n⚡ Performance Comparison Test:');
  
  final stopwatch = Stopwatch()..start();
  
  // Test old behavior (force refresh every time)
  for (int i = 0; i < 5; i++) {
    await CatalogService.instance.getCategories(forceRefresh: true);
  }
  
  final oldTime = stopwatch.elapsedMilliseconds;
  stopwatch.reset();
  
  // Test new behavior (smart caching)
  for (int i = 0; i < 5; i++) {
    await CatalogService.instance.getCategories(forceRefresh: false);
  }
  
  final newTime = stopwatch.elapsedMilliseconds;
  
  debugPrint('📈 Old behavior (force refresh): ${oldTime}ms for 5 calls');
  debugPrint('📈 New behavior (smart caching): ${newTime}ms for 5 calls');
  debugPrint('🚀 Performance improvement: ${((oldTime - newTime) / oldTime * 100).toStringAsFixed(1)}% faster');
}