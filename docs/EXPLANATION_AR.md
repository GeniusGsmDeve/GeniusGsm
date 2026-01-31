ملف شرح - TempMail
===================

هذا الملف يشرح حالة المشروع وإعدادات النشر الحالية ويُحمّل فقط كمستند توضيحي على GitHub—لا ينفذ أي تثبيت على الخادم.

موجز الحالة:
- المشروع: واجهة Django لاستقبال الرسائل المؤقتة مع مستقبل SMTP وPostgreSQL.
- النطاق المقصود: mail.geniusgsm.com
- تم إنشاء ملفات النشر التوضيحية داخل المجلد `deploy/` (nginx, systemd, env.example، run_commands.sh).
- لم تُرفع بيئة Python الافتراضية (`.venv`) ولا الحزم المورَّدة إلى المستودع على طلبك.

ماذا يحتوي هذا المستودع الآن:
- `src/` : كود مشروع Django.
- `deploy/` : قوالب ملفات nginx وsystemd و`env.example` و`run_commands.sh` وREADME نشر.
- `requirements.txt` : قائمة الاعتمادات (استعملها لتثبيت الحزم محلياً عند الحاجة).

ملاحظات هامة:
- لا تنفّذ أي سكربت تثبيت على هذا الخادم ما لم تكن مستعداً—طالبك السابق كان عدم التثبيت الآن.
- لتهيئة بيئة على خادم آخر، انسخ `deploy/env.example` إلى `src/.env` واملأ القيم الحساسة (لا ترفعها للمستودع العام).
- لبدء الخدمات على الخادم الهدف: ضع ملفات الوحدات في `/etc/systemd/system/`، شغّل `sudo systemctl daemon-reload` ثم `sudo systemctl enable --now tempmail-web.service tempmail-smtp.service`، وأضِف ملف nginx إلى `/etc/nginx/sites-available/` ثم فعّله عبر symlink وأعد تشغيل nginx.

أوامر مُقتَرحة لإدارة (مذكورة أيضاً في `deploy/run_commands.sh`):
```bash
sudo systemctl restart tempmail-web.service
sudo systemctl restart tempmail-smtp.service
sudo nginx -t && sudo systemctl restart nginx

# لتهيئة DB (كمستخدم postgres):
sudo -u postgres psql -c "CREATE USER tempmail WITH PASSWORD 'YOUR_DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE \"TempMail\" OWNER tempmail;"
```

إذا أردت، أستطيع الآن:
- (أ) عدم إجراء أي تغييرات إضافية—فقط رفعت هذا الملف كما طلبت.
- (ب) رفع أي ملفات توضيحية أخرى أو تحديث `README` بالشرح بالعربي.

تمّ الإنشاء بتاريخ: 2026-01-31
