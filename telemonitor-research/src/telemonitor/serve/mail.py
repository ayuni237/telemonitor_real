"""Emails sent by the worker: the link confirming a patient's address and the
link choosing a new password, in TeleMonitor's own email (Firebase does not
let this project change its templates).

The links themselves are Firebase's (Admin SDK), so both work as before. The
email goes out through an SMTP account described in secrets/smtp.json, next
to the service-account key and, like it, never committed:

    {"host": "smtp.gmail.com", "port": 465, "security": "ssl",
     "username": "<account>@gmail.com", "password": "<16-letter app password>",
     "from_address": "<account>@gmail.com", "from_name": "TeleMonitor"}

security is "ssl" (port 465) or "starttls" (port 587). Without the file the
worker sends no email and the app falls back on Firebase's standard one.
"""
from __future__ import annotations

import html
import json
import smtplib
import ssl
from dataclasses import dataclass
from email.message import EmailMessage
from email.utils import formataddr, formatdate, make_msgid
from pathlib import Path

LOGO = Path(__file__).with_name("mail_logo.png")
LOGO_CID = "logo@telemonitor"
PRIMARY = "#1A3C6E"          # AppColors.primary
SUBJECT = "Confirm your email address for TeleMonitor"
RESET_SUBJECT = "Choose a new password for TeleMonitor"
FOOTER = "TeleMonitor: home monitoring of blood pressure and blood glucose, with your clinician."


def _greeting(name: str | None) -> str:
    first = (name or "").strip().split()
    return f"Hello {first[0]}," if first else "Hello,"


def verification_email(name: str | None, link: str) -> tuple[str, str, str]:
    """Subject, plain text and HTML of the email confirming an address."""
    return _email(SUBJECT, name, link,
                  intro="Welcome to TeleMonitor. Please confirm that this is your email address: "
                        "it is the only way to set a new password if you ever forget yours.",
                  text_intro="Welcome to TeleMonitor. Please confirm your email address by opening this link:",
                  button="Confirm my email address",
                  closing="If you did not create a TeleMonitor account, you can ignore this email.")


def password_reset_email(name: str | None, link: str) -> tuple[str, str, str]:
    """Subject, plain text and HTML of the email choosing a new password."""
    return _email(RESET_SUBJECT, name, link,
                  intro="We received a request to choose a new password for your TeleMonitor account.",
                  text_intro="We received a request to choose a new password for your TeleMonitor account. "
                             "To choose it, open this link:",
                  button="Choose a new password",
                  closing="If you did not ask for this, you can ignore this email: your password stays the same.")


def _email(subject: str, name: str | None, link: str, intro: str, text_intro: str,
           button: str, closing: str) -> tuple[str, str, str]:
    hello = _greeting(name)
    text = f"{hello}\n\n{text_intro}\n\n{link}\n\n{closing}\n\n--\n{FOOTER}\n"
    h, url = html.escape(hello), html.escape(link, quote=True)
    body = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>{html.escape(subject)}</title></head>
<body style="margin:0;padding:0;background:#f3f5f9">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f5f9">
<tr><td align="center" style="padding:28px 12px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"
  style="max-width:520px;background:#ffffff;border-radius:16px;border:1px solid #e5e7eb;
  font-family:Roboto,'Segoe UI',Helvetica,Arial,sans-serif;color:#1f2937">
<tr><td style="padding:24px 28px 18px;border-bottom:3px solid {PRIMARY}">
  <img src="cid:{LOGO_CID}" width="40" height="40" alt="" style="vertical-align:middle;border:0;border-radius:10px">
  <span style="vertical-align:middle;margin-left:10px;font-size:21px;font-weight:700;color:{PRIMARY}">TeleMonitor</span>
</td></tr>
<tr><td style="padding:26px 28px 6px;font-size:15px;line-height:1.6">
  <p style="margin:0 0 14px">{h}</p>
  <p style="margin:0 0 14px">{html.escape(intro)}</p>
</td></tr>
<tr><td align="center" style="padding:14px 28px 26px">
  <a href="{url}" style="display:inline-block;background:{PRIMARY};color:#ffffff;text-decoration:none;
  font-weight:600;font-size:15px;padding:14px 30px;border-radius:10px">{html.escape(button)}</a>
</td></tr>
<tr><td style="padding:0 28px 24px;font-size:13px;line-height:1.5;color:#6b7280">
  <p style="margin:0 0 12px">If the button does not work, copy this link into your browser:<br>
  <a href="{url}" style="color:{PRIMARY};word-break:break-all">{url}</a></p>
  <p style="margin:0">{html.escape(closing)}</p>
</td></tr>
<tr><td style="padding:16px 28px;border-top:1px solid #e5e7eb;font-size:12px;line-height:1.5;color:#9ca3af">
  {html.escape(FOOTER)}
</td></tr>
</table>
</td></tr>
</table>
</body></html>
"""
    return subject, text, body


def message(to: str, sender: tuple[str, str], subject: str, text: str, body: str) -> EmailMessage:
    """A plain-text email with an HTML alternative and the logo inline."""
    msg = EmailMessage()
    msg["Subject"], msg["From"], msg["To"] = subject, formataddr(sender), to
    # an email without them looks like spam to the receiving servers
    msg["Date"] = formatdate(usegmt=True)
    msg["Message-ID"] = make_msgid("telemonitor", domain=sender[1].rpartition("@")[2] or None)
    msg.set_content(text)
    msg.add_alternative(body, subtype="html")
    if LOGO.exists():
        msg.get_payload()[1].add_related(LOGO.read_bytes(), "image", "png", cid=f"<{LOGO_CID}>")
    return msg


@dataclass
class Mailer:
    host: str
    port: int
    username: str
    password: str
    from_address: str
    from_name: str = "TeleMonitor"
    security: str = "ssl"

    @classmethod
    def from_file(cls, path: str | Path) -> Mailer | None:
        path = Path(path)
        return cls(**json.loads(path.read_text(encoding="utf8"))) if path.exists() else None

    def send(self, to: str, subject: str, text: str, body: str) -> None:
        msg = message(to, (self.from_name, self.from_address), subject, text, body)
        context = ssl.create_default_context()
        if self.security == "ssl":
            with smtplib.SMTP_SSL(self.host, self.port, context=context, timeout=30) as smtp:
                smtp.login(self.username, self.password)
                smtp.send_message(msg)
        else:
            with smtplib.SMTP(self.host, self.port, timeout=30) as smtp:
                smtp.starttls(context=context)
                smtp.login(self.username, self.password)
                smtp.send_message(msg)
