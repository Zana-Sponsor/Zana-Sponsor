<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $apiToken = "8365701740:AAFdtoRdYyrDUiuUfhWzZorhwUjGHDYs588";
    $chatID = "6259019006";

    $orderID = "T-" . rand(1000, 9999);
    $name = $_POST['name'];
    $budget = $_POST['budget'];
    $code = $_POST['video_code'];
    $link = $_POST['link'];

    $message = "🌟 **داواکاری نوێی TikTok Ads**\n\n";
    $message .= "🆔 **کۆدی داواکاری:** `".$orderID."` (بۆ کڕیاری بنێرەوە)\n";
    $message .= "👤 پەیج: ".$name."\n";
    $message .= "💰 بودجە: $".$budget."\n";
    $message .= "🔢 کۆدی ڤیدیۆ: `".$code."`\n";
    $message .= "🔗 لینک: ".$link."\n";

    // ناردنی وێنەی وەسڵ و دەقەکە
    $url = "https://api.telegram.org/bot$apiToken/sendPhoto";
    $post_fields = [
        'chat_id'   => $chatID,
        'photo'     => new CURLFile($_FILES['receipt']['tmp_name']),
        'caption'   => $message,
        'parse_mode' => 'Markdown'
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["Content-Type:multipart/form-data"]);
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_fields);
    curl_exec($ch);
    curl_close($ch);

    echo "<script>alert('داواکارییەکەت نێردرا! کۆدی پشکنینی تۆ: $orderID'); window.location.href='index.php?order_id=$orderID';</script>";
}
?>
