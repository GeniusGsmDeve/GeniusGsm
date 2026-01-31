import uuid
from django.shortcuts import render, redirect, get_object_or_404
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from .models import EmailMessage, SiteSetting


def index(request):
    """Show the index page and optionally generate a temporary local part.

    GET: render the page (if a local is stored in session it will be shown).
    POST: generate a new local part, persist a GeneratedAddress record, store it in
    the session and re-render the page showing the new address (no redirect).
    """
    domain = settings.ALLOWED_HOSTS[0] if settings.ALLOWED_HOSTS else 'mail.geniusgsm.com'
    current_local = request.session.get('tempmail_local')

    if request.method == 'POST':
        local = uuid.uuid4().hex[:8]
        # try to record GeneratedAddress for stats
        try:
            from .models import GeneratedAddress
            ip = request.META.get('REMOTE_ADDR') or request.META.get('HTTP_X_REAL_IP') or ''
            ua = request.META.get('HTTP_USER_AGENT', '')[:1024]
            GeneratedAddress.objects.create(local_part=local, domain=domain, source_ip=ip, user_agent=ua)
        except Exception:
            pass
        request.session['tempmail_local'] = local
        current_local = local

    address = f"{current_local}@{domain}" if current_local else None
    logo = None
    site_name = None
    try:
        logo = SiteSetting.objects.filter(key='logo_svg').values_list('value', flat=True).first()
    except Exception:
        logo = None
    try:
        site_name = SiteSetting.objects.filter(key='site_name').values_list('value', flat=True).first()
    except Exception:
        site_name = None
    return render(request, 'mailreceiver/index.html', {'domain': domain, 'address': address, 'local': current_local, 'site_logo_svg': logo, 'site_name': site_name})


def home(request):
    """Landing page: show inbox for session local or generate and redirect."""
    local = request.session.get('tempmail_local')
    if not local:
        # generate a new local part and persist a GeneratedAddress
        import uuid
        local = uuid.uuid4().hex[:8]
        try:
            from .models import GeneratedAddress
            domain = request.get_host().split(':')[0]
            ip = request.META.get('REMOTE_ADDR') or request.META.get('HTTP_X_REAL_IP') or ''
            ua = request.META.get('HTTP_USER_AGENT', '')[:1024]
            GeneratedAddress.objects.create(local_part=local, domain=domain, source_ip=ip, user_agent=ua)
        except Exception:
            pass
        request.session['tempmail_local'] = local
    return redirect('mailreceiver:inbox', local=local)


def inbox(request, local):
    """List messages where recipients contain the generated address."""
    address = f"{local}@{settings.ALLOWED_HOSTS[0]}" if settings.ALLOWED_HOSTS else f"{local}@mail.geniusgsm.com"
    qs = EmailMessage.objects.filter(mail_to__icontains=address).order_by('-received_at')
    logo = None
    site_name = None
    try:
        logo = SiteSetting.objects.filter(key='logo_svg').values_list('value', flat=True).first()
    except Exception:
        logo = None
    try:
        site_name = SiteSetting.objects.filter(key='site_name').values_list('value', flat=True).first()
    except Exception:
        site_name = None
    return render(request, 'mailreceiver/inbox.html', {'local': local, 'address': address, 'messages': qs, 'site_logo_svg': logo, 'site_name': site_name})


def inbox_api(request, local):
    """Return JSON list of messages for the given local part."""
    address = f"{local}@{settings.ALLOWED_HOSTS[0]}" if settings.ALLOWED_HOSTS else f"{local}@mail.geniusgsm.com"
    qs = EmailMessage.objects.filter(mail_to__icontains=address).order_by('-received_at')[:200]
    data = []
    for m in qs:
        data.append({
            'id': m.pk,
            'subject': m.subject or '(no subject)',
            'from': m.mail_from,
            'received_at': m.received_at.isoformat(),
            'snippet': (m.body or '')[:200],
        })
    from django.http import JsonResponse
    return JsonResponse({'local': local, 'address': address, 'messages': data})


def message_api(request, pk):
    from django.http import JsonResponse
    msg = get_object_or_404(EmailMessage, pk=pk)
    return JsonResponse({
        'id': msg.pk,
        'subject': msg.subject or '(no subject)',
        'from': msg.mail_from,
        'to': msg.mail_to,
        'headers': msg.headers,
        'body': msg.body,
        'attachments': msg.attachments,
        'received_at': msg.received_at.isoformat(),
    })


@csrf_exempt
def generate_api(request):
    """Generate a new local part and return it as JSON."""
    from django.http import JsonResponse
    if request.method != 'POST':
        return JsonResponse({'error': 'POST required'}, status=405)
    local = uuid.uuid4().hex[:8]
    # create GeneratedAddress record for tracking
    try:
        from .models import GeneratedAddress
        domain = settings.ALLOWED_HOSTS[0] if settings.ALLOWED_HOSTS else 'mail.geniusgsm.com'
        ip = request.META.get('REMOTE_ADDR') or request.META.get('HTTP_X_REAL_IP') or ''
        ua = request.META.get('HTTP_USER_AGENT', '')[:1024]
        GeneratedAddress.objects.create(local_part=local, domain=domain, source_ip=ip, user_agent=ua)
    except Exception:
        # don't fail generation if tracking fails
        pass
    return JsonResponse({'local': local})


def message_detail(request, pk):
    msg = get_object_or_404(EmailMessage, pk=pk)
    logo = None
    site_name = None
    try:
        logo = SiteSetting.objects.filter(key='logo_svg').values_list('value', flat=True).first()
    except Exception:
        logo = None
    try:
        site_name = SiteSetting.objects.filter(key='site_name').values_list('value', flat=True).first()
    except Exception:
        site_name = None
    return render(request, 'mailreceiver/message_detail.html', {'message': msg, 'site_logo_svg': logo, 'site_name': site_name})

