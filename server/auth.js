import { OAuth2Client } from 'google-auth-library';

const google = new OAuth2Client();

export async function verifyGoogle(credential, clientId, nonce) {
  const ticket = await google.verifyIdToken({ idToken: credential, audience: clientId });
  const payload = ticket.getPayload();
  if (!payload?.sub || !payload.email_verified || payload.nonce !== nonce || !payload.email) {
    throw new Error('Invalid Google identity');
  }
  return { sub: payload.sub, name: (payload.name || payload.email).slice(0, 200), email: payload.email.slice(0, 320) };
}
