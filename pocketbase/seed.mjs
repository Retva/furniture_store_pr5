/**
 * Заливка демонстрационных данных в PocketBase «МебельДом».
 *
 * Требуется: Node.js 18+, запущенный `./pocketbase serve`.
 *
 *   node seed.mjs
 *   node seed.mjs --reset
 *
 * Ходит под суперпользователем админки, поэтому работает и после
 * закрытия API Rules.
 */

const BASE = process.env.PB_URL || "http://127.0.0.1:8090";
const SUPER_EMAIL = process.env.PB_ADMIN_EMAIL || "admin@mebeldom.local";
const SUPER_PASS = process.env.PB_ADMIN_PASS || "mebel-admin-8090";

const reset = process.argv.includes("--reset");

async function req(path, { method = "GET", token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    const msg = data?.message || data?.data || text || res.statusText;
    throw new Error(`${method} ${path} → ${res.status}: ${JSON.stringify(msg)}`);
  }
  return data;
}

async function authSuper() {
  // PocketBase 0.23+: суперпользователи — коллекция _superusers
  try {
    const data = await req("/api/collections/_superusers/auth-with-password", {
      method: "POST",
      body: { identity: SUPER_EMAIL, password: SUPER_PASS },
    });
    return data.token;
  } catch (e) {
    // Старый путь админки (на всякий случай)
    const data = await req("/api/admins/auth-with-password", {
      method: "POST",
      body: { identity: SUPER_EMAIL, password: SUPER_PASS },
    });
    return data.token;
  }
}

async function listAll(token, collection) {
  const data = await req(
    `/api/collections/${collection}/records?perPage=200`,
    { token },
  );
  return data.items || [];
}

async function create(token, collection, body) {
  return req(`/api/collections/${collection}/records`, {
    method: "POST",
    token,
    body,
  });
}

async function removeAll(token, collection) {
  const items = await listAll(token, collection);
  for (const item of items) {
    await req(`/api/collections/${collection}/records/${item.id}`, {
      method: "DELETE",
      token,
    });
  }
}

async function main() {
  console.log(`PocketBase: ${BASE}`);
  const token = await authSuper();
  console.log("Суперпользователь: вход выполнен");

  const existing = await listAll(token, "categories");
  if (existing.length > 0 && !reset) {
    console.error(
      "Данные уже есть. Чтобы перезалить: node seed.mjs --reset",
    );
    process.exit(1);
  }

  if (reset) {
    console.log("Очистка коллекций…");
    for (const c of [
      "orders",
      "discount_cards",
      "products",
      "manufacturers",
      "materials",
      "categories",
      "customers",
    ]) {
      await removeAll(token, c);
    }
    // Пользователей приложения не трогаем оптом — пересоздадим известных.
    const users = await listAll(token, "users");
    for (const u of users) {
      if (
        ["admin@mebeldom.ru", "manager@mebeldom.ru", "viewer@mebeldom.ru"].includes(
          u.email,
        )
      ) {
        await req(`/api/collections/users/records/${u.id}`, {
          method: "DELETE",
          token,
        });
      }
    }
  }

  const cat = {};
  for (const row of [
    { name: "Диваны", description: "Прямые, угловые и раскладные диваны" },
    { name: "Кресла", description: "Кресла для гостиной и кабинета" },
    { name: "Столы", description: "Обеденные и письменные столы" },
    { name: "Стулья", description: "Стулья и барные стулья" },
    { name: "Шкафы", description: "Шкафы-купе и распашные" },
    { name: "Кровати", description: "Кровати для взрослых и детей" },
    { name: "Комоды и тумбы", description: "Комоды и тумбы" },
    { name: "Стеллажи и полки", description: "Открытые стеллажи" },
  ]) {
    const rec = await create(token, "categories", row);
    cat[row.name] = rec.id;
  }
  console.log(`Категории: ${Object.keys(cat).length}`);

  const mat = {};
  for (const row of [
    { name: "Массив дуба", kind: "Дерево", origin: "Россия" },
    { name: "Массив сосны", kind: "Дерево", origin: "Россия" },
    { name: "ЛДСП", kind: "Дерево", origin: "Россия" },
    { name: "Велюр", kind: "Ткань", origin: "Турция" },
    { name: "Рогожка", kind: "Ткань", origin: "Россия" },
    { name: "Натуральная кожа", kind: "Кожа", origin: "Италия" },
    { name: "Сталь", kind: "Металл", origin: "Германия" },
    { name: "Закалённое стекло", kind: "Стекло", origin: "Чехия" },
  ]) {
    const rec = await create(token, "materials", row);
    mat[row.name] = rec.id;
  }
  console.log(`Материалы: ${Object.keys(mat).length}`);

  const mfr = {};
  for (const row of [
    {
      name: "Северный лес",
      country: "Россия",
      city: "Вологда",
      founded_year: 2001,
      email: "info@severles.example",
      materials: [mat["Массив дуба"], mat["Массив сосны"], mat["ЛДСП"]],
      description: "Корпусная мебель из массива и ЛДСП",
    },
    {
      name: "Casa Nobile",
      country: "Италия",
      city: "Милан",
      founded_year: 1988,
      email: "hello@casanobile.example",
      materials: [mat["Натуральная кожа"], mat["Велюр"], mat["Массив дуба"]],
      description: "Мягкая мебель премиум-класса",
    },
    {
      name: "Nordic Line",
      country: "Швеция",
      city: "Гётеборг",
      founded_year: 1995,
      email: "sales@nordicline.example",
      materials: [mat["Массив сосны"], mat["Рогожка"], mat["Сталь"]],
      description: "Скандинавский минимализм",
    },
    {
      name: "Legno Vivo",
      country: "Италия",
      city: "Верона",
      founded_year: 1976,
      email: "office@legnovivo.example",
      materials: [mat["Массив дуба"], mat["Закалённое стекло"]],
      description: "Столы и шкафы из массива",
    },
    {
      name: "МеталлФорм",
      country: "Россия",
      city: "Челябинск",
      founded_year: 2010,
      email: "order@metallform.example",
      materials: [mat["Сталь"], mat["ЛДСП"]],
      description: "Каркасы и металлическая мебель",
    },
    {
      name: "SoftHome",
      country: "Россия",
      city: "Казань",
      founded_year: 2008,
      email: "hi@softhome.example",
      materials: [mat["Велюр"], mat["Рогожка"], mat["Натуральная кожа"]],
      description: "Диваны и кресла",
    },
    {
      name: "Glass & Co",
      country: "Чехия",
      city: "Прага",
      founded_year: 1992,
      email: "cz@glassco.example",
      materials: [mat["Закалённое стекло"], mat["Сталь"]],
      description: "Столы со стеклянными столешницами",
    },
    {
      name: "УютМастер",
      country: "Россия",
      city: "Краснодар",
      founded_year: 2015,
      email: "shop@uyutmaster.example",
      materials: [mat["ЛДСП"], mat["Рогожка"]],
      description: "Доступная корпусная мебель",
    },
  ]) {
    const rec = await create(token, "manufacturers", row);
    mfr[row.name] = rec.id;
  }
  console.log(`Производители: ${Object.keys(mfr).length}`);

  const products = [
    {
      name: "Диван «Осло» прямой",
      sku: "DV-101",
      manufacturer: mfr["SoftHome"],
      categories: [cat["Диваны"]],
      materials: [mat["Велюр"]],
      price: 89900,
      stock: 8,
      width_cm: 220,
      depth_cm: 95,
      height_cm: 85,
      color: "серый",
    },
    {
      name: "Диван-кровать «Верона»",
      sku: "DV-102",
      manufacturer: mfr["Casa Nobile"],
      categories: [cat["Диваны"], cat["Кровати"]],
      materials: [mat["Натуральная кожа"]],
      price: 189000,
      stock: 3,
      width_cm: 210,
      depth_cm: 100,
      height_cm: 90,
      color: "коричневый",
    },
    {
      name: "Угловой диван «Мальмё»",
      sku: "DV-103",
      manufacturer: mfr["Nordic Line"],
      categories: [cat["Диваны"]],
      materials: [mat["Рогожка"]],
      price: 124500,
      stock: 5,
      width_cm: 280,
      depth_cm: 180,
      height_cm: 82,
      color: "бежевый",
    },
    {
      name: "Кресло «Лофт»",
      sku: "KR-201",
      manufacturer: mfr["МеталлФорм"],
      categories: [cat["Кресла"]],
      materials: [mat["Сталь"], mat["Рогожка"]],
      price: 34900,
      stock: 12,
      width_cm: 70,
      depth_cm: 75,
      height_cm: 95,
      color: "чёрный",
    },
    {
      name: "Обеденный стол «Дуб»",
      sku: "ST-301",
      manufacturer: mfr["Северный лес"],
      categories: [cat["Столы"]],
      materials: [mat["Массив дуба"]],
      price: 67900,
      stock: 6,
      width_cm: 160,
      depth_cm: 90,
      height_cm: 75,
      color: "натуральный",
    },
    {
      name: "Письменный стол «Нота»",
      sku: "ST-302",
      manufacturer: mfr["УютМастер"],
      categories: [cat["Столы"]],
      materials: [mat["ЛДСП"]],
      price: 15900,
      stock: 20,
      width_cm: 120,
      depth_cm: 60,
      height_cm: 75,
      color: "белый",
    },
    {
      name: "Стеклянный журнальный стол",
      sku: "ST-303",
      manufacturer: mfr["Glass & Co"],
      categories: [cat["Столы"]],
      materials: [mat["Закалённое стекло"], mat["Сталь"]],
      price: 28900,
      stock: 9,
      width_cm: 100,
      depth_cm: 60,
      height_cm: 45,
      color: "прозрачный",
    },
    {
      name: "Стул «Берген»",
      sku: "CH-401",
      manufacturer: mfr["Nordic Line"],
      categories: [cat["Стулья"]],
      materials: [mat["Массив сосны"]],
      price: 8900,
      stock: 30,
      width_cm: 45,
      depth_cm: 50,
      height_cm: 90,
      color: "светлое дерево",
    },
    {
      name: "Шкаф-купе «Милан»",
      sku: "SH-501",
      manufacturer: mfr["Legno Vivo"],
      categories: [cat["Шкафы"]],
      materials: [mat["Массив дуба"], mat["Закалённое стекло"]],
      price: 215000,
      stock: 2,
      width_cm: 240,
      depth_cm: 65,
      height_cm: 220,
      color: "дуб",
    },
    {
      name: "Кровать «Сон» 160",
      sku: "BD-601",
      manufacturer: mfr["SoftHome"],
      categories: [cat["Кровати"]],
      materials: [mat["Велюр"], mat["ЛДСП"]],
      price: 54900,
      stock: 7,
      width_cm: 170,
      depth_cm: 210,
      height_cm: 100,
      color: "серо-голубой",
    },
    {
      name: "Комод «Практик»",
      sku: "CM-701",
      manufacturer: mfr["УютМастер"],
      categories: [cat["Комоды и тумбы"]],
      materials: [mat["ЛДСП"]],
      price: 12900,
      stock: 15,
      width_cm: 90,
      depth_cm: 45,
      height_cm: 80,
      color: "венге",
    },
    {
      name: "Стеллаж «Библиотека»",
      sku: "RL-801",
      manufacturer: mfr["Северный лес"],
      categories: [cat["Стеллажи и полки"]],
      materials: [mat["Массив сосны"]],
      price: 24900,
      stock: 10,
      width_cm: 80,
      depth_cm: 35,
      height_cm: 180,
      color: "сосна",
    },
  ];

  const prodIds = {};
  for (const p of products) {
    const rec = await create(token, "products", p);
    prodIds[p.sku] = rec.id;
  }
  console.log(`Товары: ${products.length}`);

  const customers = [
    {
      full_name: "Анна Смирнова",
      email: "anna@mail.example",
      phone: "+7 (912) 345-67-01",
      card: { number: "MD-1001", discount_percent: 5, issued_at: "2024-03-01" },
    },
    {
      full_name: "Игорь Петров",
      email: "igor@mail.example",
      phone: "+7 (903) 111-22-33",
      card: null,
    },
    {
      full_name: "Мария Козлова",
      email: "maria@mail.example",
      phone: "+7 (916) 555-44-33",
      card: { number: "MD-1002", discount_percent: 10, issued_at: "2023-11-15" },
    },
    {
      full_name: "Олег Васильев",
      email: "oleg@mail.example",
      phone: "+7 (999) 888-77-66",
      card: null,
    },
  ];

  for (const c of customers) {
    const { card, ...rest } = c;
    const rec = await create(token, "customers", rest);
    if (card) {
      await create(token, "discount_cards", {
        customer: rec.id,
        ...card,
      });
    }
  }
  console.log(`Покупатели: ${customers.length}`);

  // Учётные записи приложения
  const appUsers = [
    {
      email: "admin@mebeldom.ru",
      password: "mebel12345",
      passwordConfirm: "mebel12345",
      username: "admin",
      name: "Администратор магазина",
      role: "admin",
      emailVisibility: true,
    },
    {
      email: "manager@mebeldom.ru",
      password: "mebel12345",
      passwordConfirm: "mebel12345",
      username: "manager",
      name: "Менеджер зала",
      role: "manager",
      emailVisibility: true,
    },
    {
      email: "viewer@mebeldom.ru",
      password: "mebel12345",
      passwordConfirm: "mebel12345",
      username: "viewer",
      name: "Покупатель Иван",
      role: "viewer",
      emailVisibility: true,
    },
  ];

  for (const u of appUsers) {
    await create(token, "users", u);
  }
  console.log("Пользователи: admin / manager / viewer (пароль mebel12345)");

  console.log("Готово.");
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
