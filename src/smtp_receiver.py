#!/usr/bin/env python3
"""Simple SMTP receiver using aiosmtpd that saves messages to Django model EmailMessage.

Run under the project's virtualenv. By default listens on port 2525 to avoid needing root.
"""
import os
import asyncio
import email
import time
from email import policy

# Configure Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
import django
django.setup()

from django.conf import settings
from mailreceiver.models import EmailMessage, GeneratedAddress

ATTACH_DIR = os.path.join(settings.BASE_DIR, 'attachments')
os.makedirs(ATTACH_DIR, exist_ok=True)

from aiosmtpd.controller import Controller
from asgiref.sync import sync_to_async


class Handler:
    async def handle_DATA(self, server, session, envelope):
        raw_bytes = envelope.content
        try:
            msg = email.message_from_bytes(raw_bytes, policy=policy.default)
        except Exception:
            # fallback
            msg = email.message_from_string(raw_bytes.decode('utf8', errors='replace'))

        message_id = msg.get('Message-ID', '')
        subject = msg.get('Subject', '')
        mail_from = envelope.mail_from
        mail_to = ','.join(envelope.rcpt_tos)
        headers = '\n'.join([f"{k}: {v}" for k, v in msg.items()])

        # extract body (prefer plain)
        body = ''
        attachments = []
        if msg.is_multipart():
            for part in msg.walk():
                ctype = part.get_content_type()
                disp = str(part.get_content_disposition() or '')
                filename = part.get_filename()
                if filename:
                    # save attachment
                    timestamp = int(time.time())
                    safe_name = f"{timestamp}-{filename}"
                    path = os.path.join(ATTACH_DIR, safe_name)
                    with open(path, 'wb') as f:
                        f.write(part.get_payload(decode=True) or b'')
                    attachments.append({'filename': filename, 'path': path, 'size': os.path.getsize(path)})
                elif ctype == 'text/plain' and not body:
                    try:
                        body = part.get_content()
                    except Exception:
                        body = part.get_payload(decode=True).decode('utf8', errors='replace')
        else:
            try:
                body = msg.get_content()
            except Exception:
                body = msg.get_payload(decode=True).decode('utf8', errors='replace')

        # helper to find GeneratedAddress by local part
        def find_generated(local):
            try:
                return GeneratedAddress.objects.filter(local_part=local).order_by('-created_at').first()
            except Exception:
                return None

        def increment_count(addr_id):
            try:
                ga = GeneratedAddress.objects.filter(id=addr_id).first()
                if ga:
                    ga.message_count = (ga.message_count or 0) + 1
                    ga.save()
            except Exception:
                pass

        # create DB record
        try:
            # debug log
            try:
                with open('/tmp/smtp_debug.log','a') as _f:
                    _f.write(f"Creating EmailMessage: from={mail_from} to={mail_to} subj={subject}\n")
            except Exception:
                pass

            # attempt to associate with a GeneratedAddress by checking recipients
            generated_obj = None
            try:
                # envelope.rcpt_tos may contain multiple recipients; check each
                for rcpt in envelope.rcpt_tos:
                    local = rcpt.split('@', 1)[0]
                    found = await sync_to_async(find_generated, thread_sensitive=True)(local)
                    if found:
                        generated_obj = found
                        break
            except Exception:
                generated_obj = None

            create_kwargs = dict(
                message_id=message_id,
                mail_from=mail_from,
                mail_to=mail_to,
                subject=subject,
                headers=headers,
                body=body,
                attachments=str(attachments),
            )
            if generated_obj:
                create_kwargs['generated_address_id'] = generated_obj.id

            obj = await sync_to_async(EmailMessage.objects.create, thread_sensitive=True)(**create_kwargs)
            # increment counter asynchronously
            if generated_obj:
                await sync_to_async(increment_count, thread_sensitive=True)(generated_obj.id)
            try:
                with open('/tmp/smtp_debug.log','a') as _f:
                    _f.write(f"Saved EmailMessage id={obj.id}\n")
            except Exception:
                pass
            print('Saved EmailMessage id=', obj.id)
        except Exception as e:
            try:
                with open('/tmp/smtp_debug.log','a') as _f:
                    _f.write(f"Failed to save EmailMessage: {e}\n")
            except Exception:
                pass
            print('Failed to save EmailMessage:', e)

        return '250 Message accepted for delivery'


def main():
    port = int(os.environ.get('SMTP_PORT', '2525'))
    controller = Controller(Handler(), hostname='0.0.0.0', port=port)
    controller.start()
    print(f"SMTP receiver running on 0.0.0.0:{port} (CTRL-C to stop)")
    try:
        asyncio.get_event_loop().run_forever()
    except KeyboardInterrupt:
        controller.stop()


if __name__ == '__main__':
    main()
