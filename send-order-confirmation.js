// netlify/functions/send-order-confirmation.js
//
// Sends an order-confirmation email to the customer using Resend
// (https://resend.com). Called from index.html's sendOrderConfirmationEmail()
// whenever SITE.orderConfirmationEmailsEnabled is true.
//
// SETUP:
//   1. Create a free Resend account at https://resend.com
//   2. Verify a sending domain (Resend → Domains) — or, for quick testing
//      before you have a domain verified, you can send FROM
//      "onboarding@resend.dev" (Resend's shared test address; fine for
//      trying this out, but switch to your own domain before going live).
//   3. Create an API key (Resend → API Keys).
//   4. In Netlify → Site settings → Environment variables, add:
//        RESEND_API_KEY = <your API key>
//        RESEND_FROM    = "Jay Walker Shopmart <orders@yourdomain.com>"
//   5. Set SITE.orderConfirmationEmailsEnabled = true in index.html.
//
// This function fails soft: if it errors, the customer still sees the
// on-screen receipt in the browser — this email is a bonus, not a
// dependency, so index.html never blocks on it.

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const RESEND_API_KEY = process.env.RESEND_API_KEY;
  const RESEND_FROM = process.env.RESEND_FROM;

  if (!RESEND_API_KEY || !RESEND_FROM) {
    // Not configured yet — respond quietly rather than throwing, since the
    // caller ignores the response either way.
    return { statusCode: 200, body: JSON.stringify({ skipped: true, reason: 'Email not configured' }) };
  }

  let payload;
  try {
    payload = JSON.parse(event.body);
  } catch (err) {
    return { statusCode: 400, body: 'Invalid JSON' };
  }

  const { orderId, shopName, replyTo, order, itemLines } = payload || {};
  if (!order || !order.email) {
    return { statusCode: 400, body: 'Missing order or customer email' };
  }

  const money = (n) => 'UGX ' + Math.round(n).toLocaleString('en-UG');

  const rowsHtml = (itemLines || []).map(line =>
    `<tr>
       <td style="padding:6px 0; border-bottom:1px solid #eee;">${escapeHtml(line.name)}${line.size ? ` (${escapeHtml(line.size)})` : ''} × ${line.qty}</td>
       <td style="padding:6px 0; border-bottom:1px solid #eee; text-align:right;">${money(line.lineTotal)}</td>
     </tr>`
  ).join('');

  const hasDelivery = typeof order.deliveryFee === 'number';
  const total = order.total != null ? order.total : order.subtotal;

  const html = `
    <div style="font-family: -apple-system, Helvetica, Arial, sans-serif; max-width: 520px; margin: 0 auto; color: #241934;">
      <h2 style="margin-bottom: 4px;">${escapeHtml(shopName || 'Your order')}</h2>
      <p style="color:#6a5f7a; margin-top:0;">Order ${escapeHtml(orderId || '')} · ${new Date(order.placedAt).toLocaleString()}</p>
      <p>Hi ${escapeHtml(order.name || '')},</p>
      <p>Thanks for your order! Here's a copy for your records. We'll be in touch by email${replyTo ? ` (${escapeHtml(replyTo)})` : ''}${order.phone ? ' or phone' : ''} to confirm payment and delivery details if we haven't already.</p>
      <table style="width:100%; border-collapse: collapse; margin: 18px 0;">
        ${rowsHtml}
        ${hasDelivery ? `<tr><td style="padding:6px 0;">Delivery${order.deliveryLabel ? ' — ' + escapeHtml(order.deliveryLabel) : ''}</td><td style="padding:6px 0; text-align:right;">${money(order.deliveryFee)}</td></tr>` : ''}
        <tr><td style="padding:10px 0 0; font-weight:bold; border-top:2px solid #241934;">Total</td><td style="padding:10px 0 0; font-weight:bold; text-align:right; border-top:2px solid #241934;">${money(total)}</td></tr>
      </table>
      ${order.address ? `<p><strong>Delivery address:</strong><br>${escapeHtml(order.address)}</p>` : ''}
      ${order.note ? `<p><strong>Note:</strong> ${escapeHtml(order.note)}</p>` : ''}
      <p style="color:#6a5f7a; font-size:0.85rem; margin-top:28px;">Questions about this order? Just reply to this email${replyTo ? ` or write to ${escapeHtml(replyTo)}` : ''}.</p>
    </div>`;

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: RESEND_FROM,
        to: order.email,
        reply_to: replyTo || undefined,
        subject: `Your order confirmation — ${shopName || ''} (${orderId || ''})`,
        html,
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error('Resend API error:', errText);
      return { statusCode: 502, body: JSON.stringify({ error: 'Email provider error' }) };
    }

    return { statusCode: 200, body: JSON.stringify({ sent: true }) };
  } catch (err) {
    console.error('send-order-confirmation error:', err);
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to send email' }) };
  }
};

function escapeHtml(str) {
  return String(str == null ? '' : str).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}
