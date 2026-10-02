<?php
// NII Pro subscription page.

require_once "config.php";
require_once "layout.php";

$user = require_login();
$pro = has_pro($user);

page_header("NII Pro", $user);
?>
<div class="max-w-3xl mx-auto">
    <div class="rounded-2xl p-8 text-white bg-gradient-to-br from-amber-500 via-orange-500 to-fuchsia-600 text-center">
        <p class="text-5xl">⭐</p>
        <h1 class="text-3xl font-bold mt-2">NII Pro</h1>
        <p class="text-xl mt-2"><?= e(money($settings["pro_price"])) ?> / месяц</p>
        <?php if ($pro): ?>
            <p class="mt-4 inline-block bg-white/20 px-4 py-2 rounded-xl font-semibold">
                ✓ У вас активен Pro <?= $user["is_family"] ? "(семейный доступ — бессрочно)" : (is_staff($user) ? "(команда НИИ)" : "до " . fmt_date($user["pro_until"])) ?>
            </p>
        <?php endif; ?>
    </div>

    <div class="card p-6 mt-6">
        <h2 class="text-xl font-bold mb-4">Что входит</h2>
        <ul class="space-y-3">
            <li class="flex gap-3"><span>🎓</span><span><strong>Все Pro-курсы</strong> исследователей НИИ: AI, инженерия, вода, assistive tech, научное письмо.</span></li>
            <li class="flex gap-3"><span>🧪</span><span><strong>Онлайн-лаборатория</strong>: запись на лабораторные сессии и консультации с учёными НИИ.</span></li>
            <li class="flex gap-3"><span>📅</span><span><strong>Закрытые семинары и мастер-классы</strong> (Pro-мероприятия).</span></li>
            <li class="flex gap-3"><span>📜</span><span><strong>Сертификаты</strong> о прохождении курсов.</span></li>
            <li class="flex gap-3"><span>🚀</span><span><strong>Приоритет</strong> при отборе на стажировки и программы НИИ.</span></li>
        </ul>

        <?php if (!$user["is_family"] && !is_staff($user)): ?>
            <a href="pay.php?type=pro" class="btn btn-primary text-lg w-full mt-6"><?= $pro ? "Продлить на " . (int)$settings["pro_days"] . " дней" : "Подключить Pro" ?> — <?= e(money($settings["pro_price"])) ?></a>
            <p class="text-sm text-slate-500 text-center mt-2">Оплата переводом на Kaspi. Pro включится после проверки чека.</p>
        <?php endif; ?>
    </div>
</div>
<?php page_footer();
