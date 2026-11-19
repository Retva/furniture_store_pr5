/// <reference path="../pb_data/types.d.ts" />
/**
 * Коллекции «МебельДом».
 * Порядок: категории → материалы → производители → товары → покупатели →
 * карты скидок; users (+ role); заказы.
 *
 * Правила сначала открыты ("" = кто угодно), чтобы seed.mjs мог залить
 * данные без токена. Ролевые правила — миграция 1732010001.
 */
migrate(
  (app) => {
    const open = "";

    const categories = new Collection({
      type: "base",
      name: "categories",
      listRule: open,
      viewRule: open,
      createRule: open,
      updateRule: open,
      deleteRule: open,
      fields: [
        { name: "name", type: "text", required: true, max: 120 },
        { name: "description", type: "text", max: 2000 },
        { name: "deleted_at", type: "date" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_categories_name ON categories (name)",
      ],
    });
    app.save(categories);

    const materials = new Collection({
      type: "base",
      name: "materials",
      listRule: open,
      viewRule: open,
      createRule: open,
      updateRule: open,
      deleteRule: open,
      fields: [
        { name: "name", type: "text", required: true, max: 120 },
        {
          name: "kind",
          type: "select",
          required: true,
          maxSelect: 1,
          values: [
            "Дерево",
            "Металл",
            "Ткань",
            "Кожа",
            "Стекло",
            "Пластик",
            "Прочее",
          ],
        },
        { name: "origin", type: "text", max: 120 },
        { name: "deleted_at", type: "date" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_materials_name ON materials (name)",
      ],
    });
    app.save(materials);

    const manufacturers = new Collection({
      type: "base",
      name: "manufacturers",
      listRule: open,
      viewRule: open,
      createRule: open,
      updateRule: open,
      deleteRule: open,
      fields: [
        { name: "name", type: "text", required: true, max: 160 },
        { name: "country", type: "text", required: true, max: 80 },
        { name: "city", type: "text", max: 80 },
        { name: "founded_year", type: "number", onlyInt: true },
        { name: "email", type: "email" },
        { name: "website", type: "url" },
        {
          name: "materials",
          type: "relation",
          collectionId: materials.id,
          maxSelect: 50,
          cascadeDelete: false,
        },
        { name: "description", type: "text", max: 4000 },
        { name: "deleted_at", type: "date" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_manufacturers_name ON manufacturers (name)",
      ],
    });
    app.save(manufacturers);

    const products = new Collection({
      type: "base",
      name: "products",
      listRule: open,
      viewRule: open,
      createRule: open,
      updateRule: open,
      deleteRule: open,
      fields: [
        { name: "name", type: "text", required: true, max: 200 },
        { name: "sku", type: "text", required: true, max: 40 },
        {
          name: "manufacturer",
          type: "relation",
          required: true,
          collectionId: manufacturers.id,
          maxSelect: 1,
          cascadeDelete: false,
        },
        {
          name: "categories",
          type: "relation",
          collectionId: categories.id,
          maxSelect: 20,
          cascadeDelete: false,
        },
        {
          name: "materials",
          type: "relation",
          collectionId: materials.id,
          maxSelect: 20,
          cascadeDelete: false,
        },
        { name: "price", type: "number", required: true, onlyInt: true, min: 1 },
        { name: "stock", type: "number", required: true, onlyInt: true, min: 0 },
        { name: "width_cm", type: "number", onlyInt: true, min: 1 },
        { name: "depth_cm", type: "number", onlyInt: true, min: 1 },
        { name: "height_cm", type: "number", onlyInt: true, min: 1 },
        { name: "color", type: "text", max: 80 },
        { name: "description", type: "text", max: 4000 },
        { name: "deleted_at", type: "date" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_products_sku ON products (sku)",
      ],
    });
    app.save(products);

    const customers = new Collection({
      type: "base",
      name: "customers",
      listRule: open,
      viewRule: open,
      createRule: open,
      updateRule: open,
      deleteRule: open,
      fields: [
        { name: "full_name", type: "text", required: true, max: 160 },
        { name: "email", type: "email", required: true },
        { name: "phone", type: "text", required: true, max: 40 },
        { name: "deleted_at", type: "date" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_customers_email ON customers (email)",
      ],
    });
    app.save(customers);

    const discountCards = new Collection({
      type: "base",
      name: "discount_cards",
      listRule: open,
      viewRule: open,
      createRule: open,
      updateRule: open,
      deleteRule: open,
      fields: [
        {
          name: "customer",
          type: "relation",
          required: true,
          collectionId: customers.id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        { name: "number", type: "text", required: true, max: 40 },
        {
          name: "discount_percent",
          type: "number",
          required: true,
          onlyInt: true,
          min: 1,
          max: 50,
        },
        { name: "issued_at", type: "date", required: true },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_discount_cards_customer ON discount_cards (customer)",
        "CREATE UNIQUE INDEX idx_discount_cards_number ON discount_cards (number)",
      ],
    });
    app.save(discountCards);

    const users = app.findCollectionByNameOrId("users");
    users.fields.add(
      new SelectField({
        name: "role",
        required: true,
        maxSelect: 1,
        values: ["viewer", "manager", "admin"],
      }),
    );
    users.fields.add(
      new TextField({
        name: "username",
        required: true,
        min: 3,
        max: 40,
      }),
    );
    users.listRule = open;
    users.viewRule = open;
    users.createRule = open;
    users.updateRule = open;
    users.deleteRule = open;
    // Регистрация и вход по email; username — для отображения в приложении.
    app.save(users);

    const orders = new Collection({
      type: "base",
      name: "orders",
      listRule: open,
      viewRule: open,
      createRule: open,
      updateRule: open,
      deleteRule: open,
      fields: [
        {
          name: "customer",
          type: "relation",
          required: true,
          collectionId: customers.id,
          maxSelect: 1,
          cascadeDelete: false,
        },
        {
          name: "product",
          type: "relation",
          required: true,
          collectionId: products.id,
          maxSelect: 1,
          cascadeDelete: false,
        },
        {
          name: "user",
          type: "relation",
          collectionId: users.id,
          maxSelect: 1,
          cascadeDelete: false,
        },
        {
          name: "quantity",
          type: "number",
          required: true,
          onlyInt: true,
          min: 1,
        },
        {
          name: "total",
          type: "number",
          required: true,
          onlyInt: true,
          min: 0,
        },
        { name: "cancelled_at", type: "date" },
      ],
    });
    app.save(orders);

    try {
      const supers = app.findCollectionByNameOrId("_superusers");
      const su = new Record(supers);
      su.set("email", "admin@mebeldom.local");
      su.set("password", "mebel-admin-8090");
      app.save(su);
    } catch (_) {}
  },
  (app) => {
    for (const name of [
      "orders",
      "discount_cards",
      "customers",
      "products",
      "manufacturers",
      "materials",
      "categories",
    ]) {
      try {
        app.delete(app.findCollectionByNameOrId(name));
      } catch (_) {}
    }
  },
);
