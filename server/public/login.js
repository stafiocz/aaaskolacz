const button = document.querySelector('#google-signin');
const status = document.querySelector('#status');
if (!window.google?.accounts?.id) {
  status.textContent = 'Google se nepodařilo načíst. Obnov stránku a zkus to znovu.';
} else {
  google.accounts.id.initialize({
    client_id: button.dataset.clientId,
    nonce: button.dataset.nonce,
    auto_select: false,
    callback: async ({ credential }) => {
      status.textContent = 'Přihlašuji…';
      try {
        const response = await fetch('/api/auth/google', {
          method: 'POST', credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ credential, nonce: button.dataset.nonce }),
        });
        if (!response.ok) throw new Error('Login failed');
        window.location.replace('/');
      } catch {
        status.textContent = 'Přihlášení se nepodařilo. Obnov stránku a zkus to znovu.';
      }
    },
  });
  google.accounts.id.renderButton(button, { type: 'standard', theme: 'outline', size: 'large', text: 'signin_with', locale: 'cs' });
}
