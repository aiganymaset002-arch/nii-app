<?php
require_once "config.php";
require_once "layout.php";

$user = require_login();

$programs = rows("
    SELECT p.*, (SELECT status FROM applications a WHERE a.program_id = p.id AND a.user_id = ?) AS my_status
    FROM programs p WHERE p.published = 1
    ORDER BY (p.deadline IS NOT NULL AND p.deadline < CURDATE()), p.deadline IS NULL, p.deadline", [(int)$user["id"]]);

$status_labels = ["submitted" => ["На рассмотрении", "bg-yellow-100 text-yellow-800"], "accepted" => ["Принята", "bg-green-100 text-green-800"], "rejected" => ["Отклонена", "bg-red-100 text-red-800"]];

page_header("Программы", $user);
?>
<h1 class="text-2xl font-bold mb-1">Программы НИИ</h1>
<p class="text-slate-500 mb-5">Стажировки, конкурсы, гранты и исследовательские программы. Подайте заявку прямо в приложении.</p>

<?php if (!$programs): ?><div class="card p-6 text-slate-500">Сейчас нет открытых программ.</div><?php endif; ?>

<div class="grid md:grid-cols-2 gap-4">
<?php foreach ($programs as $p): $closed = $p["deadline"] && $p["deadline"] < date("Y-m-d"); ?>
    <a href="program.php?id=<?= (int)$p["id"] ?>" class="card p-5 block <?= $closed ? "opacity-60" : "" ?>">
        <div class="flex justify-between gap-2">
            <span class="chip bg-fuchsia-100 text-fuchsia-800"><?= e($p["kind"]) ?></span>
            <?php if ($p["my_status"]): [$label, $cls] = $status_labels[$p["my_status"]]; ?><span class="chip <?= $cls ?>">Заявка: <?= $label ?></span><?php endif; ?>
        </div>
        <h2 class="font-bold text-lg mt-2"><?= e($p["title"]) ?></h2>
        <p class="text-sm text-slate-500 mt-1"><?= $closed ? "Приём заявок закрыт" : ($p["deadline"] ? "Приём заявок до " . fmt_date($p["deadline"]) : "Приём заявок открыт") ?></p>
    </a>
<?php endforeach; ?>
</div>
<?php page_footer();
