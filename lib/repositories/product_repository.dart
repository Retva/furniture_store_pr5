import '../models/product.dart';
import '../models/product_query.dart';
import 'crud_repository.dart';

abstract interface class ProductRepository
    implements CrudRepository<Product, ProductQuery> {
  /// Сколько товаров (включая логически удалённые) ссылается на запись.
  Future<int> countByManufacturer(String manufacturerId);
  Future<int> countByCategory(String categoryId);
  Future<int> countByMaterial(String materialId);
}
