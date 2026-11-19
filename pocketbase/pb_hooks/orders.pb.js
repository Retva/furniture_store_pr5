/// <reference path="../pb_data/types.d.ts" />
/**
 * При создании заказа: проверка остатка, скидка по карте покупателя,
 * списание со склада. Это содержательная особенность предметной области.
 */
onRecordCreateRequest((e) => {
  const productId = e.record.get("product");
  const customerId = e.record.get("customer");
  const quantity = e.record.get("quantity") || 0;

  if (!productId || !customerId || quantity < 1) {
    throw new BadRequestError("Некорректные данные заказа.");
  }

  const product = $app.findRecordById("products", productId);
  if (product.get("deleted_at")) {
    throw new BadRequestError("Товар удалён и недоступен для заказа.");
  }

  const stock = product.get("stock") || 0;
  if (quantity > stock) {
    throw new ApiError(409, `Недостаточно на складе (доступно ${stock}).`, {});
  }

  let discount = 0;
  try {
    const cards = $app.findRecordsByFilter(
      "discount_cards",
      `customer = "${customerId}"`,
      "",
      1,
      0,
    );
    if (cards && cards.length > 0) {
      discount = cards[0].get("discount_percent") || 0;
    }
  } catch (_) {}

  const price = product.get("price") || 0;
  const total = Math.round((price * quantity * (100 - discount)) / 100);
  e.record.set("total", total);

  if (e.auth && e.auth.id) {
    e.record.set("user", e.auth.id);
  }

  e.next();

  // После успешного создания — уменьшаем остаток.
  product.set("stock", stock - quantity);
  $app.save(product);
}, "orders");

/**
 * При регистрации с клиента роль всегда viewer — нельзя назначить себе admin.
 */
onRecordCreateRequest((e) => {
  if (!e.hasSuperuserAuth()) {
    e.record.set("role", "viewer");
  }
  e.next();
}, "users");
