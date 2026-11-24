# kyc-google-verify

This function keeps Google Cloud credentials server-side. Configure the Supabase Function secret `GOOGLE_CLOUD_SERVICE_ACCOUNT_JSON` with the Google service-account JSON for a project where Cloud Vision API is enabled. Never put this JSON in `exchange.html` or `exchange-admin.html`.

The function downloads private identity objects with the Supabase service role, runs Google Cloud Vision document text detection and selfie face detection, then stores only OCR/face metadata. It does not create public storage URLs and does not auto-approve a user; an admin must review the private images and use `ex_admin_kyc_review`.
