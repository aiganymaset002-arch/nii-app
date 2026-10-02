<?php
// Page header/footer with role-based navigation.

function nav_items($user)
{
    $items = [
        ["home.php", "Главная", "🏠"],
        ["courses.php", "Курсы", "🎓"],
        ["events.php", "События", "📅"],
        ["programs.php", "Программы", "🚀"],
        ["news.php", "Новости", "📰"],
        ["shop.php", "Мерч", "👕"],
        ["profile.php", "Профиль", "👤"],
    ];

    if ($user && $user["role"] === "team") {
        array_splice($items, 1, 0, [["tasks.php", "Мои задачи", "✅"], ["manage-events.php", "Лаборатория и встречи", "🧪"]]);
    }

    return $items;
}

function admin_items()
{
    return [
        ["admin.php", "Панель", "📊"],
        ["tasks.php", "Задачи", "✅"],
        ["roadmap.php", "План 90 дней", "🗺️"],
        ["manage-events.php", "Конференции и встречи", "📅"],
        ["manage-courses.php", "Курсы", "🎓"],
        ["manage-programs.php", "Программы и заявки", "🚀"],
        ["manage-news.php", "Новости", "📰"],
        ["manage-shop.php", "Мерч", "👕"],
        ["manage-payments.php", "Оплаты", "💳"],
        ["manage-users.php", "Люди", "👥"],
    ];
}

function page_header($title, $user = null)
{
    global $settings;

    $current = basename($_SERVER["SCRIPT_NAME"]);
    $is_admin = $user && $user["role"] === "admin";
    $items = $is_admin ? admin_items() : nav_items($user);
    $tabs = $is_admin
        ? [["admin.php", "Панель", "📊"], ["tasks.php", "Задачи", "✅"], ["manage-events.php", "События", "📅"], ["manage-payments.php", "Оплаты", "💳"], ["home.php", "Как видят", "👁️"]]
        : array_slice(nav_items($user), 0, 4);

    if (!$is_admin && $user) {
        $tabs[] = ["profile.php", "Профиль", "👤"];
    }
    ?>
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<title><?= e($title) ?> · <?= e($settings["app_name"]) ?></title>
<meta name="theme-color" content="#1e3a8a">
<link rel="manifest" href="manifest.json">
<link rel="icon" href="assets/icon-192.png">
<link rel="apple-touch-icon" href="assets/icon-192.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="NII">
<link rel="stylesheet" href="assets/app.css?v=1">
</head>
<body class="bg-slate-100 text-slate-900 min-h-screen pb-24 md:pb-0">

<header class="bg-gradient-to-r from-blue-900 via-indigo-800 to-fuchsia-700 text-white sticky top-0 z-30">
    <div class="max-w-6xl mx-auto px-4 py-3 flex items-center gap-3">
        <a href="<?= $is_admin ? "admin.php" : "home.php" ?>" class="flex items-center gap-2 font-bold text-lg">
            <img src="assets/icon-192.png" alt="" class="w-8 h-8 rounded-lg">
            <span>NII<span class="font-light"> App</span></span>
        </a>
        <span class="flex-1"></span>
        <?php if ($user): ?>
            <?php if (has_pro($user)): ?><span class="chip bg-amber-300 text-amber-900">PRO</span><?php endif; ?>
            <span class="hidden sm:inline text-sm opacity-90"><?= e($user["name"]) ?></span>
            <a href="logout.php" class="text-sm bg-white/15 px-3 py-1.5 rounded-lg">Выйти</a>
        <?php endif; ?>
    </div>
    <?php if ($user): ?>
    <nav class="max-w-6xl mx-auto px-2 overflow-x-auto whitespace-nowrap text-sm hidden md:block">
        <?php foreach ($items as [$href, $label, $icon]): ?>
            <a href="<?= $href ?>" class="inline-block px-3 py-2 rounded-t-lg <?= $current === $href ? "bg-slate-100 text-blue-900 font-semibold" : "text-white/85 hover:text-white" ?>"><?= $icon ?> <?= e($label) ?></a>
        <?php endforeach; ?>
    </nav>
    <?php endif; ?>
</header>

<main class="max-w-6xl mx-auto px-4 py-6">
<?php if ($f = flash()): ?>
    <div class="mb-4 p-4 rounded-xl <?= $f[1] === "error" ? "bg-red-100 text-red-800" : "bg-green-100 text-green-800" ?>"><?= e($f[0]) ?></div>
<?php endif; ?>
<?php
    $GLOBALS["__tabs"] = $user ? $tabs : [];
    $GLOBALS["__menu"] = $user ? $items : [];
}

function page_footer()
{
    $current = basename($_SERVER["SCRIPT_NAME"]);
    $tabs = $GLOBALS["__tabs"] ?? [];
    $menu = $GLOBALS["__menu"] ?? [];
    ?>
</main>

<?php if ($menu): ?>
<!-- Full menu for phones -->
<div id="moreMenu" class="hidden fixed inset-0 z-40 bg-black/40 md:hidden" onclick="this.classList.add('hidden')">
    <div class="absolute bottom-20 left-3 right-3 card p-3 grid grid-cols-2 gap-2" onclick="event.stopPropagation()">
        <?php foreach ($menu as [$href, $label, $icon]): ?>
            <a href="<?= $href ?>" class="p-3 rounded-xl bg-slate-50 text-sm font-semibold"><?= $icon ?> <?= e($label) ?></a>
        <?php endforeach; ?>
    </div>
</div>
<?php endif; ?>

<?php if ($tabs): ?>
<nav class="md:hidden fixed bottom-0 inset-x-0 bg-white border-t z-30 grid grid-cols-6 text-[11px]" style="padding-bottom: env(safe-area-inset-bottom)">
    <?php foreach ($tabs as [$href, $label, $icon]): ?>
        <a href="<?= $href ?>" class="flex flex-col items-center py-2 <?= $current === $href ? "text-blue-900 font-bold" : "text-slate-500" ?>">
            <span class="text-xl leading-none"><?= $icon ?></span><span class="mt-1 truncate max-w-full px-1"><?= e($label) ?></span>
        </a>
    <?php endforeach; ?>
    <button type="button" onclick="document.getElementById('moreMenu').classList.toggle('hidden')" class="flex flex-col items-center py-2 text-slate-500">
        <span class="text-xl leading-none">☰</span><span class="mt-1">Ещё</span>
    </button>
</nav>
<?php endif; ?>

<script>
if ("serviceWorker" in navigator) { navigator.serviceWorker.register("sw.js").catch(() => {}); }
</script>
</body>
</html>
<?php
}
