document.addEventListener('DOMContentLoaded', function(){
  // index page copy button
  const btnCopyIndex = document.getElementById('btn-copy-index')
  if(btnCopyIndex){
    btnCopyIndex.addEventListener('click', ()=>{
      const addr = document.getElementById('current-address').textContent.trim()
      navigator.clipboard.writeText(addr).then(()=>{
        btnCopyIndex.textContent = 'Copied'
        setTimeout(()=>btnCopyIndex.textContent='Copy',1500)
      })
    })
  }

  const addrEl = document.getElementById('address')
  const messagesEl = document.getElementById('messages')
  const subjectEl = document.getElementById('msg-subject')
  const fromEl = document.getElementById('msg-from')
  const bodyEl = document.getElementById('msg-body')
  const btnCopy = document.getElementById('btn-copy')
  const btnRefresh = document.getElementById('btn-refresh')
  const btnGenerate = document.getElementById('btn-generate')

  function localFromAddress(addr){ return addr.split('@')[0] }

  let address = addrEl.textContent.trim()
  let local = localFromAddress(address)

  async function loadInbox(){
    const res = await fetch(`/api/inbox/${local}/`)
    const json = await res.json()
    messagesEl.innerHTML = ''
    if(!json.messages.length){ messagesEl.innerHTML = '<div class="text-muted">No messages yet.</div>'; return }
    json.messages.forEach(m=>{
      const a = document.createElement('a')
      a.href='#'
      a.className = 'list-group-item list-group-item-action'
      a.dataset.id = m.id
      a.innerHTML = `${m.subject}<div class="small text-muted">From ${m.from} — ${new Date(m.received_at).toLocaleString()}</div>`
      a.addEventListener('click', async (e)=>{ e.preventDefault(); await openMessage(m.id) })
      messagesEl.appendChild(a)
    })
  }

  async function openMessage(id){
    const res = await fetch(`/api/message/${id}/`)
    const json = await res.json()
    subjectEl.textContent = json.subject
    fromEl.textContent = `From: ${json.from} — To: ${json.to} — ${new Date(json.received_at).toLocaleString()}`
    bodyEl.textContent = json.body || '(no body)'
  }

  btnCopy.addEventListener('click', ()=>{
    const current = addrEl.textContent.trim()
    navigator.clipboard.writeText(current).then(()=>{
      btnCopy.textContent = 'Copied'
      setTimeout(()=>btnCopy.textContent='Copy Address',1500)
    })
  })

  btnRefresh.addEventListener('click', async ()=>{ btnRefresh.disabled=true; await loadInbox(); btnRefresh.disabled=false })

  btnGenerate.addEventListener('click', async ()=>{
    btnGenerate.disabled=true
    const res = await fetch('/api/generate/', {method:'POST', headers:{'X-CSRFToken': getCookie('csrftoken')}})
    const json = await res.json()
    local = json.local
    const domain = addrEl && addrEl.textContent && addrEl.textContent.includes('@') ? addrEl.textContent.split('@')[1] : (address && address.split('@')[1])
    const newAddr = `${local}@${domain}`
    if(addrEl) addrEl.textContent = newAddr
    address = newAddr
    // update browser URL to reflect current inbox without full reload
    try{ window.history.replaceState(null, '', `/inbox/${local}/`) }catch(e){}
    await loadInbox()
    btnGenerate.disabled=false
  })

  function getCookie(name){
    const v = document.cookie.split('; ').find(row=>row.startsWith(name+'='))
    return v? v.split('=')[1] : ''
  }

  // initial load
  loadInbox().catch(console.error)
})
