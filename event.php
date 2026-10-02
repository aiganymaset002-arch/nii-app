<?php
// One event: details, registration, Zoom link for registered people.

require_once "config.php";
require_once "layout.php";

$user = require_login();
$uid = (int)$user["id"];
$id = (int)($_GET["id"] ?? 0);

$ev = row("SELECT e.*, u.name AS host FROM events e LEFT JOIN users u ON u.id = e.host_id WHERE e.id = ? AND (e.published = 1 OR ? = 1)",
          [$id, is_staff($user) ? 1 : 0]);

if (!$ev) {
    http_response_code(404);
    die("Мероприятие не найдено.");
}

$reg = row("SELECT * FROM event_regs WHERE event_id = ? AND user_id = ?", [$id, $uid]);
$registered = $reg && $reg["status"] === "registered";
$regs = (int)row("SELECT COUNT(*) n FROM event_regs WHERE event_id = ? AND status = 'registered'", [$id])["n"];
$full = $ev["capacity"] && $regs >= $ev["capacity"];
$locked = $ev["pro_only"] && !has_pro($user);
$free_for_me = $ev["price"] <= 0 || $user["is_family"] || is_staff($user);

if (is_post()) {
    if (post("action") === "register" && !$registered) {
        if ($locked) {
            flash("Это мероприятие доступно в NII Pro.", "error");
        } elseif ($full) {
            flash("К сожалению, мест больше нет.", "error");
        } elseif (!$free_for_me) {
            redirect("pay.php?type=event&id=" . $id);
        } else {
            q("INSERT INTO event_regs (event_id, user_id, status) VALUES (?, ?, 'registered') ON DUPLICATE KEY UPDATE status = 'registered'", [$id, $uid]);
            flash("Вы записаны! Ссылка на подключение — на этой странице.");
        }
    }

    if (post("action") === "cancel" && $registered) {
        q("UPDATE event_regs SET status = 'cancelled' WHERE id = ?", [(int)$reg["id"]]);
        flash("Запись отменена.");
    }

    redirect("event.php?id=" . $id);
}

$labels = ["conference" => "Конференция", "seminar" => "Семинар", "lab" => "Онлайн-лаборатория", "meeting" => "Встреча"];
$starts = strtotime($ev["starts_at"]);
$ends = $starts + $ev["duration_min"] * 60;
$live = time() >= $starts - 15 * 60 && time() <= $ends;

page_header($ev["title"], $user);
?>
<a href="events.php" class="text-blue-800 font-semibold">← Все события</a>

<div class="card p-6 md:p-8 mt-4">
    <div class="flex flex-wrap gap-2">
        <span class="chip bg-blue-100 text-blue-900"><?= e($labels[$ev["type"]] ?? $ev["type"]) ?></span>
        <?php if ($ev["pro_only"]): ?><span class="chip bg-amber-200 text-amber-900">PRO</span><?php endif; ?>
        <?php if (!$ev["published"]): ?><span class="chip bg-slate-200">Черновик</span><?php endif; ?>
    </div>

    <h1 class="text-2xl md:text-3xl font-bold mt-3"><?= e($ev["title"]) ?></h1>

    <div class="grid sm:grid-cols-2 gap-3 mt-4 text-slate-700">
        <p>📅 <?= date("d.m.Y", $starts) ?>, <?= date("H:i", $starts) ?>–<?= date("H:i", $ends) ?> (Астана)</p>
        <p>💳 <?= $ev["price"] > 0 ? e(money($ev["price"])) . ($free_for_me ? " · для вас бесплатно" : "") : "Бесплатно" ?></p>
        <?php if ($ev["location"]): ?><p>📍 <?= e($ev["location"]) ?></p><?php endif; ?>
        <?php if ($ev["host"]): ?><p>👤 Ведущий: <?= e($ev["host"]) ?></p><?php endif; ?>
        <p>👥 Записано: <?= $regs ?><?= $ev["capacity"] ? " из " . (int)$ev["capacity"] : "" ?></p>
    </div>

    <?php if ($ev["description"]): ?>
        <div class="mt-6 leading-7 whitespace-pre-line"><?= e($ev["description"]) ?></div>
    <?php endif; ?>

    <div class="mt-8 p-5 rounded-xl bg-slate-50">
    <?php if ($registered): ?>
        <p class="font-bold text-green-700">✓ Вы записаны</p>

        <?php if (safe_url($ev["zoom_url"])): ?>
            <a href="<?= e($ev["zoom_url"]) ?>" target="_blank" rel="noopener" class="btn btn-green mt-3 <?= $live ? "animate-pulse" : "" ?>">🎥 <?= $live ? "Подключиться сейчас" : "Ссылка на Zoom" ?></a>
        <?php else: ?>
            <p class="text-sm text-slate-500 mt-2">Ссылка на подключение появится здесь перед началом.</p>
        <?php endif; ?>

        <div class="flex flex-wrap gap-2 mt-3">
            <a href="event-ics.php?id=<?= $id ?>" class="btn btn-light">📆 Добавить в календарь</a>
            <form method="POST" onsubmit="return confirm('Отменить запись?')">
                <?= csrf_field() ?><input type="hidden" name="action" value="cancel">
                <button class="btn btn-danger">Отменить запись</button>
            </form>
        </div>
    <?php elseif ($locked): ?>
        <p class="font-semibold">Это мероприятие входит в NII Pro.</p>
        <a href="pro.php" class="btn bg-amber-300 text-amber-900 mt-3">⭐ Подключить Pro</a>
    <?php elseif ($full): ?>
        <p class="font-semibold text-red-700">Мест больше нет.</p>
    <?php else: ?>
        <form method="POST">
            <?= csrf_field() ?><input type="hidden" name="action" value="register">
            <button class="btn btn-primary text-lg"><?= $free_for_me ? "Записаться" : "Записаться и оплатить " . e(money($ev["price"])) ?></button>
        </form>
    <?php endif; ?>
    </div>
</div>
<?php page_footer();
