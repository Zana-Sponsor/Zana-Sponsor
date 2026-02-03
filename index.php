<?php
// خوێندنەوەی داتاکان لە فایلی database.json
$data = json_decode(@file_get_contents('database.json'), true) ?: [];
$orderId = $_GET['order_id'] ?? '';
$stats = $data[$orderId] ?? null;
?>
<!DOCTYPE html>
<html dir="rtl" lang="ku">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zana Sponsor - TikTok Ads</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@300;500;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        body { font-family: 'Vazirmatn', sans-serif; background-color: #f8fafc; }
        .chip.active { background: #000 !important; color: #fff !important; border-bottom: 3px solid #ff0050; }
    </style>
</head>
<body>

<div class="max-w-xl mx-auto p-4">
    <div class="bg-black text-white p-6 rounded-3xl mb-8 shadow-2xl">
        <h2 class="text-xl font-bold mb-4 text-center">📊 چاودێری ئەنجامی سپۆنسەر</h2>
        <form method="GET" class="flex gap-2">
            <input type="text" name="order_id" value="<?= htmlspecialchars($orderId) ?>" placeholder="کۆدی داواکاری بنووسە (بۆ نموونە: T-1234)" class="flex-1 p-3 rounded-xl text-black outline-none text-center font-bold">
            <button type="submit" class="bg-blue-600 px-6 rounded-xl font-bold hover:bg-blue-700">بپشکنە</button>
        </form>

        <?php if ($stats): ?>
        <div class="grid grid-cols-3 gap-2 mt-6 bg-gray-900 p-4 rounded-2xl border border-gray-800">
            <div class="text-center"><small class="text-gray-400 block mb-1">بینەر</small><p class="text-lg font-bold text-cyan-400"><?= $stats['views'] ?></p></div>
            <div class="text-center"><small class="text-gray-400 block mb-1">کلیک</small><p class="text-lg font-bold text-green-400"><?= $stats['clicks'] ?></p></div>
            <div class="text-center"><small class="text-gray-400 block mb-1">خەرجی</small><p class="text-lg font-bold text-red-400">$<?= $stats['spend'] ?></p></div>
        </div>
        <?php elseif ($orderId): ?>
            <p class="text-red-400 mt-4 text-sm text-center">❌ ئەم کۆدە بوونی نییە یان هێشتا چالاک نەکراوە.</p>
        <?php endif; ?>
    </div>

    <div class="bg-white p-6 rounded-3xl shadow-sm border border-gray-100">
        <h2 class="text-lg font-bold mb-6 border-r-4 border-blue-600 pr-3">🚀 داواکاری سپۆنسەری نوێ</h2>
        <form action="process.php" method="POST" enctype="multipart/form-data" class="space-y-4">
            <input type="text" name="name" placeholder="ناوی پەیج" class="w-full p-3 bg-gray-50 border rounded-xl outline-none" required>
            <input type="text" name="video_code" placeholder="کۆدی ڤیدیۆ #6721..." class="w-full p-3 bg-gray-50 border rounded-xl outline-none" required>
            <input type="url" name="link" placeholder="لینکی ڤیدیۆ" class="w-full p-3 bg-gray-50 border rounded-xl outline-none" required>
            <input type="number" name="budget" placeholder="بودجە ($)" class="w-full p-3 bg-gray-50 border rounded-xl outline-none" required>
            
            <div class="p-4 border-2 border-dashed border-gray-200 rounded-xl text-center">
                <input type="file" name="receipt" id="receipt" hidden required>
                <label for="receipt" class="cursor-pointer text-gray-500 text-sm">
                    <i class="fas fa-receipt mb-2 text-2xl"></i><br>وێنەی وەسڵی پارەدان باربکە
                </label>
            </div>

            <button type="submit" class="w-full bg-black text-white p-4 rounded-2xl font-bold text-lg hover:opacity-90 transition">ناردنی داواکاری</button>
        </form>
    </div>
</div>

</body>
</html>
