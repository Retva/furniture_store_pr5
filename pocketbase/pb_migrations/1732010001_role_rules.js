/// <reference path="../pb_data/types.d.ts" />
/**
 * Правила доступа по ролям (после seed).
 *
 * Смотреть каталог могут все авторизованные.
 * Менять каталог — manager и admin.
 * Hard-delete/restore через обновление deleted_at — admin.
 * Покупатели и карты — manager+.
 * Заказы: создавать может manager и viewer; свои заказы видит владелец.
 *
 * После применения этой миграции анонимный seed.mjs без токена получит 403 —
 * заливайте данные до неё или под суперпользователем админки.
 */
migrate((app) => {
  const authed = '@request.auth.id != ""';
  const manager =
    '@request.auth.id != "" && (@request.auth.role = "manager" || @request.auth.role = "admin")';
  const admin = '@request.auth.id != "" && @request.auth.role = "admin"';

  function setRules(name, rules) {
    const c = app.findCollectionByNameOrId(name);
    c.listRule = rules.list;
    c.viewRule = rules.view;
    c.createRule = rules.create;
    c.updateRule = rules.update;
    c.deleteRule = rules.delete;
    app.save(c);
  }

  const catalogReadWrite = {
    list: authed,
    view: authed,
    create: manager,
    update: manager,
    delete: admin,
  };

  setRules("categories", catalogReadWrite);
  setRules("materials", catalogReadWrite);
  setRules("manufacturers", catalogReadWrite);
  setRules("products", catalogReadWrite);

  setRules("customers", {
    list: manager,
    view: manager,
    create: manager,
    update: manager,
    delete: admin,
  });

  setRules("discount_cards", {
    list: manager,
    view: manager,
    create: manager,
    update: manager,
    delete: admin,
  });

  setRules("orders", {
    list:
      '@request.auth.id != "" && (@request.auth.role = "admin" || @request.auth.role = "manager" || user = @request.auth.id)',
    view:
      '@request.auth.id != "" && (@request.auth.role = "admin" || @request.auth.role = "manager" || user = @request.auth.id)',
    create:
      '@request.auth.id != "" && (@request.auth.role = "manager" || @request.auth.role = "viewer" || @request.auth.role = "admin")',
    update: manager,
    delete: admin,
  });

  const users = app.findCollectionByNameOrId("users");
  users.listRule = admin;
  users.viewRule =
    '@request.auth.id != "" && (id = @request.auth.id || @request.auth.role = "admin")';
  // Регистрация открыта; роль при создании с клиента должна быть viewer
  // (это дополнительно проверяет хук).
  users.createRule = "";
  users.updateRule = admin;
  users.deleteRule = admin;
  app.save(users);
});
