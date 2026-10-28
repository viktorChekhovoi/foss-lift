// The fragment is never sent to Cloudflare's access logs or any referrer.
const token = new URLSearchParams(location.hash.slice(1)).get('token');
history.replaceState(null, '', location.pathname);
const button = document.getElementById('continue');
const status = document.getElementById('status');
if (!/^[a-f0-9]{64}$/.test(token || '')) {
  button.disabled = true;
  status.textContent = 'This link is invalid. Return to Foss Lift and request a new one.';
}
button.addEventListener('click', async () => {
  button.disabled = true;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch('/api/auth/consume', {
      method: 'POST', credentials: 'same-origin', cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }), signal: controller.signal,
    });
    if (!response.ok) {
      status.textContent = 'This link expired, was already used, or belongs to another browser. Request a new link in this browser.';
      return;
    }
    location.replace('/#/profile/cloud');
  } catch (_) {
    status.textContent = 'Sign-in could not finish. Check your connection and try again.';
    button.disabled = false;
  } finally { clearTimeout(timeout); }
});
