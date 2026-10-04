#!/usr/bin/env bash
# Gold Star SACCO (GSS) - full-stack website generator
# Usage: bash setup-goldstar.sh && cd goldstar-sacco && npm install && cp .env.example .env.local && npm run dev
set -e
mkdir -p goldstar-sacco && cd goldstar-sacco
mkdir -p app/services app/about app/contact app/feedback app/api/contact app/api/feedback app/api/chat components lib data

cat > package.json <<'EOF'
{
  "name": "goldstar-sacco",
  "private": true,
  "scripts": { "dev": "next dev", "build": "next build", "start": "next start" },
  "dependencies": {
    "better-sqlite3": "^11.0.0",
    "next": "^14.2.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0"
  }
}
EOF

cat > next.config.js <<'EOF'
module.exports = { experimental: { serverComponentsExternalPackages: ["better-sqlite3"] } };
EOF

cat > .env.example <<'EOF'
ANTHROPIC_API_KEY=your_key_here
ANTHROPIC_MODEL=claude-sonnet-5-5
EOF

# ---------------- Backend: database ----------------
cat > lib/db.js <<'EOF'
import Database from "better-sqlite3";
import path from "path";

const db = new Database(path.join(process.cwd(), "data", "gss.db"));
db.exec(`
  CREATE TABLE IF NOT EXISTS contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, email TEXT, phone TEXT,
    message TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP);
  CREATE TABLE IF NOT EXISTS feedback (
    id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, rating INTEGER,
    comment TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP);
`);
export default db;
EOF

cat > lib/validate.js <<'EOF'
export const clean = (v, max = 1000) => String(v ?? "").trim().slice(0, max);
export const isEmail = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
EOF

# ---------------- Backend: API routes ----------------
cat > app/api/contact/route.js <<'EOF'
import db from "@/lib/db";
import { clean, isEmail } from "@/lib/validate";

export async function POST(req) {
  const b = await req.json();
  const name = clean(b.name, 100), email = clean(b.email, 150),
        phone = clean(b.phone, 30), message = clean(b.message, 2000);
  if (!name || !isEmail(email) || !message)
    return Response.json({ error: "Enter your name, a valid email, and a message." }, { status: 400 });
  db.prepare("INSERT INTO contacts (name,email,phone,message) VALUES (?,?,?,?)")
    .run(name, email, phone, message);
  return Response.json({ ok: true });
}
EOF

cat > app/api/feedback/route.js <<'EOF'
import db from "@/lib/db";
import { clean } from "@/lib/validate";

export async function POST(req) {
  const b = await req.json();
  const name = clean(b.name, 100), comment = clean(b.comment, 2000);
  const rating = Number(b.rating);
  if (!comment || !(rating >= 1 && rating <= 5))
    return Response.json({ error: "Choose a rating and write a comment." }, { status: 400 });
  db.prepare("INSERT INTO feedback (name,rating,comment) VALUES (?,?,?)")
    .run(name || "Anonymous", rating, comment);
  return Response.json({ ok: true });
}

export async function GET() {
  const rows = db.prepare("SELECT name,rating,comment,created_at FROM feedback ORDER BY id DESC LIMIT 20").all();
  return Response.json(rows);
}
EOF

cat > app/api/chat/route.js <<'EOF'
import { clean } from "@/lib/validate";

const SYSTEM = `You are the Gold Star SACCO (GSS) assistant. Answer questions about the
SACCO's products and services: savings, loans, membership, and the loan amortization
calculator on the Services page. Be brief and friendly. Reply in the language the member
uses (English or Amharic). If you do not know a rate, fee, or policy, say so and ask the
member to use the Contact page. Never invent interest rates or fees.`;

export async function POST(req) {
  const { messages = [] } = await req.json();
  const history = messages.slice(-10).map((m) => ({
    role: m.role === "assistant" ? "assistant" : "user",
    content: clean(m.content, 1500),
  }));
  if (!history.length || history[history.length - 1].role !== "user")
    return Response.json({ error: "No question received." }, { status: 400 });

  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: process.env.ANTHROPIC_MODEL || "claude-sonnet-5-5",
        max_tokens: 500,
        system: SYSTEM,
        messages: history,
      }),
    });
    const data = await r.json();
    const reply = data?.content?.map((c) => c.text || "").join("") || "";
    if (!reply) throw new Error("empty");
    return Response.json({ reply });
  } catch {
    return Response.json({ reply: "The assistant is unavailable right now. Please use the Contact page." });
  }
}
EOF

# ---------------- Frontend: global styles + layout ----------------
cat > app/globals.css <<'EOF'
:root{--navy:#0B2545;--navy2:#13315C;--gold:#D4A017;--gold-d:#9A7410;--ink:#1A2433;--mute:#5B6678;--line:#DDE3EC;--bg:#FFFFFF;--soft:#F2F5FA;--hdr:72px}
*{box-sizing:border-box;margin:0;padding:0}
html{scroll-padding-top:var(--hdr)}
body{font-family:var(--font-body),system-ui,sans-serif;color:var(--ink);background:var(--bg);line-height:1.65;padding-top:var(--hdr)}
h1,h2,h3{font-family:var(--font-head),system-ui,sans-serif;line-height:1.2;color:var(--navy)}
a{color:inherit;text-decoration:none}
:focus-visible{outline:3px solid var(--gold);outline-offset:2px}
.wrap{max-width:1120px;margin:0 auto;padding:0 20px}
.section{padding:64px 0}
.section.soft{background:var(--soft)}
.section h2{font-size:2rem;margin-bottom:12px}
.lead{max-width:62ch;color:var(--mute)}

/* fixed header */
.hdr{position:fixed;top:0;left:0;right:0;height:var(--hdr);background:var(--navy);z-index:100;box-shadow:0 2px 10px rgba(0,0,0,.25)}
.hdr .wrap{display:flex;align-items:center;justify-content:space-between;height:100%}
.logo{display:flex;align-items:center;gap:10px;color:#fff;font-family:var(--font-head);font-weight:800;font-size:1.5rem;letter-spacing:.04em}
.logo .mark{display:grid;place-items:center;width:42px;height:42px;border-radius:50%;background:var(--gold);color:var(--navy);font-size:.95rem;letter-spacing:0}
.nav{display:flex;gap:6px}
.nav a{color:#E6ECF5;padding:8px 14px;border-radius:6px;font-weight:600}
.nav a:hover,.nav a.on{background:var(--navy2);color:var(--gold)}
.burger{display:none;background:none;border:0;color:#fff;font-size:1.8rem;cursor:pointer}

/* hero */
.hero{background:var(--navy);color:#fff;padding:84px 0}
.hero h1{color:#fff;font-size:clamp(2rem,5vw,3.4rem);max-width:18ch}
.hero p{max-width:56ch;margin:18px 0 28px;color:#CBD6E6;font-size:1.1rem}
.btn{display:inline-block;background:var(--gold);color:var(--navy);font-weight:700;padding:12px 24px;border-radius:6px;border:0;cursor:pointer;font-size:1rem}
.btn:hover{background:#E4B22E}
.btn.alt{background:transparent;border:2px solid #fff;color:#fff;margin-left:10px}

/* content */
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px;margin-top:28px}
.box{border:1px solid var(--line);border-left:4px solid var(--gold);padding:22px;background:#fff;border-radius:4px}
.box h3{margin-bottom:6px;font-size:1.15rem}
.box p{color:var(--mute)}

/* forms */
.form{display:grid;gap:14px;max-width:560px;margin-top:20px}
label{font-weight:600;display:grid;gap:6px}
input,textarea,select{font:inherit;padding:10px 12px;border:1px solid #B8C2D1;border-radius:6px;width:100%}
textarea{min-height:120px;resize:vertical}
.msg{padding:10px 14px;border-radius:6px;font-weight:600}
.msg.ok{background:#E3F4E8;color:#14612B}.msg.err{background:#FBE5E5;color:#8F1D1D}
.stars{display:flex;gap:6px}.stars button{font-size:1.8rem;background:none;border:0;cursor:pointer;color:#C4CCD8}.stars button.on{color:var(--gold)}

/* calculator */
.calc{display:grid;grid-template-columns:minmax(260px,340px) 1fr;gap:28px;margin-top:24px;align-items:start}
.sum{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:16px}
.sum div{background:var(--navy);color:#fff;padding:14px;border-radius:6px}
.sum b{display:block;color:var(--gold);font-size:1.2rem}
.tbl{max-height:420px;overflow:auto;border:1px solid var(--line);border-radius:6px}
table{width:100%;border-collapse:collapse;font-size:.92rem}
th,td{padding:8px 10px;text-align:right;border-bottom:1px solid var(--line)}
th{position:sticky;top:0;background:var(--soft)}th:first-child,td:first-child{text-align:left}

/* footer */
.ftr{background:var(--navy);color:#CBD6E6;padding:48px 0 0;margin-top:0}
.ftr .cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:32px}
.ftr h4{color:var(--gold);margin-bottom:12px;font-family:var(--font-head)}
.ftr li{list-style:none;margin-bottom:8px}.ftr a:hover{color:var(--gold)}
.social{display:flex;gap:10px;margin-top:12px}
.social a{width:38px;height:38px;border-radius:50%;background:var(--navy2);display:grid;place-items:center}
.social a:hover{background:var(--gold)}.social svg{width:18px;height:18px;fill:#fff}.social a:hover svg{fill:var(--navy)}
.copy{border-top:1px solid #24406C;margin-top:36px;padding:16px 0;text-align:center;font-size:.9rem}

/* chat */
.chat-btn{position:fixed;right:20px;bottom:20px;z-index:120;width:58px;height:58px;border-radius:50%;border:0;background:var(--gold);color:var(--navy);font-size:1.6rem;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,.3)}
.chat{position:fixed;right:20px;bottom:90px;z-index:120;width:min(360px,calc(100vw - 40px));height:480px;max-height:calc(100vh - 120px);background:#fff;border-radius:10px;box-shadow:0 8px 30px rgba(0,0,0,.3);display:flex;flex-direction:column;overflow:hidden}
.chat header{background:var(--navy);color:#fff;padding:12px 16px;font-weight:700}
.chat .log{flex:1;overflow:auto;padding:12px;display:flex;flex-direction:column;gap:8px;background:var(--soft)}
.bub{max-width:85%;padding:8px 12px;border-radius:12px;white-space:pre-wrap}
.bub.user{align-self:flex-end;background:var(--navy);color:#fff}.bub.bot{align-self:flex-start;background:#fff;border:1px solid var(--line)}
.chat form{display:flex;gap:6px;padding:10px;border-top:1px solid var(--line)}
.chat input{flex:1}

@media(max-width:820px){
 .burger{display:block}
 .nav{display:none;position:absolute;top:var(--hdr);left:0;right:0;background:var(--navy);flex-direction:column;padding:10px 20px}
 .nav.open{display:flex}
 .calc{grid-template-columns:1fr}
 .btn.alt{margin:10px 0 0}
}
@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important}}
EOF

cat > app/layout.js <<'EOF'
import "./globals.css";
import { Sora, Source_Sans_3 } from "next/font/google";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import ChatWidget from "@/components/ChatWidget";

const head = Sora({ subsets: ["latin"], variable: "--font-head", weight: ["600", "700", "800"] });
const body = Source_Sans_3({ subsets: ["latin"], variable: "--font-body" });

export const metadata = {
  title: "Gold Star SACCO (GSS)",
  description: "Savings, loans, and member services from Gold Star SACCO.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={`${head.variable} ${body.variable}`}>
      <body>
        <Header />
        <main>{children}</main>
        <Footer />
        <ChatWidget />
      </body>
    </html>
  );
}
EOF

# ---------------- Frontend: components ----------------
cat > components/Header.js <<'EOF'
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

export const LINKS = [
  ["/", "Home"], ["/services", "Services"], ["/about", "About"],
  ["/contact", "Contact"], ["/feedback", "Feedback"],
];

export default function Header() {
  const path = usePathname();
  const [open, setOpen] = useState(false);
  return (
    <header className="hdr">
      <div className="wrap">
        <Link href="/" className="logo" aria-label="GSS home">
          <span className="mark">GSS</span><span>GSS</span>
        </Link>
        <button className="burger" onClick={() => setOpen(!open)} aria-label="Toggle menu">&#9776;</button>
        <nav className={`nav ${open ? "open" : ""}`}>
          {LINKS.map(([href, label]) => (
            <Link key={href} href={href} className={path === href ? "on" : ""} onClick={() => setOpen(false)}>
              {label}
            </Link>
          ))}
        </nav>
      </div>
    </header>
  );
}
EOF

cat > components/Footer.js <<'EOF'
import Link from "next/link";
import { LINKS } from "./Header";

const icon = {
  facebook: "M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.5h-1.3c-1.2 0-1.6.8-1.6 1.6V12h2.8l-.4 2.9h-2.3v7A10 10 0 0 0 22 12z",
  telegram: "M9.8 15.5l-.4 4.1c.6 0 .8-.3 1.1-.6l2.7-2.5 5.6 4.1c1 .6 1.7.3 2-.9l3.6-17c.4-1.5-.5-2.1-1.5-1.7L1.8 10.7c-1.5.6-1.5 1.4-.3 1.8l5.4 1.7L19.500 6.300c.6-.4 1.200-.2.700.2z",
  linkedin: "M4.98 3.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zM3 9.5h4V21H3zM9.5 9.5h3.8v1.600h.1c.5-1 1.800-2 3.700-2 4 0 4.700 2.600 4.700 6V21h-4v-5c0-1.200 0-2.700-1.700-2.700s-1.900 1.300-1.900 2.600V21h-4z",
};

export default function Footer() {
  return (
    <footer className="ftr">
      <div className="wrap">
        <div className="cols">
          <div>
            <div className="logo"><span className="mark">GSS</span><span>GSS</span></div>
            <p style={{ marginTop: 12 }}>Gold Star SACCO helps members save with discipline, borrow fairly, and grow together.</p>
            <div className="social">
              {Object.entries(icon).map(([n, d]) => (
                <a key={n} href={`https://${n}.com`} target="_blank" rel="noopener noreferrer" aria-label={n}>
                  <svg viewBox="0 0 24 24"><path d={d} /></svg>
                </a>
              ))}
            </div>
          </div>
          <div>
            <h4>Quick links</h4>
            <ul>{LINKS.map(([h, l]) => <li key={h}><Link href={h}>{l}</Link></li>)}</ul>
          </div>
          <div>
            <h4>Address</h4>
            <p>Gold Star SACCO<br />[Street / Sub-city]<br />[City], Ethiopia</p>
          </div>
          <div>
            <h4>Contacts</h4>
            <ul>
              <li>Phone: +251 9XX XXX XXX</li>
              <li>Email: info@goldstarsaccos.com</li>
              <li>Mon-Fri, 8:30 AM - 5:30 PM</li>
            </ul>
          </div>
        </div>
        <div className="copy">&copy; {new Date().getFullYear()} Gold Star SACCO. All rights reserved.</div>
      </div>
    </footer>
  );
}
EOF

cat > components/ChatWidget.js <<'EOF'
"use client";
import { useEffect, useRef, useState } from "react";

export default function ChatWidget() {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [text, setText] = useState("");
  const [msgs, setMsgs] = useState([
    { role: "assistant", content: "Hello! Ask me about GSS savings, loans, or membership." },
  ]);
  const log = useRef(null);
  useEffect(() => { log.current?.scrollTo(0, log.current.scrollHeight); }, [msgs, open]);

  async function send(e) {
    e.preventDefault();
    const q = text.trim();
    if (!q || busy) return;
    const next = [...msgs, { role: "user", content: q }];
    setMsgs(next); setText(""); setBusy(true);
    try {
      const r = await fetch("/api/chat", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: next.slice(1) }),
      });
      const d = await r.json();
      setMsgs([...next, { role: "assistant", content: d.reply || d.error }]);
    } catch {
      setMsgs([...next, { role: "assistant", content: "Connection problem. Please try again." }]);
    }
    setBusy(false);
  }

  return (
    <>
      {open && (
        <section className="chat" aria-label="GSS assistant">
          <header>GSS Assistant</header>
          <div className="log" ref={log}>
            {msgs.map((m, i) => <div key={i} className={`bub ${m.role === "user" ? "user" : "bot"}`}>{m.content}</div>)}
            {busy && <div className="bub bot">Typing...</div>}
          </div>
          <form onSubmit={send}>
            <input value={text} onChange={(e) => setText(e.target.value)} placeholder="Type your question" aria-label="Your question" />
            <button className="btn" disabled={busy}>Send</button>
          </form>
        </section>
      )}
      <button className="chat-btn" onClick={() => setOpen(!open)} aria-label={open ? "Close chat" : "Open chat"}>
        {open ? "\u2715" : "\uD83D\uDCAC"}
      </button>
    </>
  );
}
EOF

cat > components/LoanCalculator.js <<'EOF'
"use client";
import { useMemo, useState } from "react";

const fmt = (n) => n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export default function LoanCalculator() {
  const [amount, setAmount] = useState(100000);
  const [rate, setRate] = useState(12);
  const [months, setMonths] = useState(24);
  const [method, setMethod] = useState("reducing"); // reducing = equal installments, flat = flat rate

  const { rows, totalInterest, first } = useMemo(() => {
    const P = Number(amount), n = Math.round(Number(months)), r = Number(rate) / 100 / 12;
    if (!(P > 0) || !(n > 0) || rate < 0) return { rows: [], totalInterest: 0, first: 0 };
    const out = []; let bal = P;
    if (method === "flat") {
      const interest = (P * Number(rate) / 100 / 12);
      const pay = P / n + interest;
      for (let i = 1; i <= n; i++) { bal -= P / n; out.push({ i, pay, principal: P / n, interest, bal: Math.max(bal, 0) }); }
    } else {
      const pay = r === 0 ? P / n : (P * r) / (1 - Math.pow(1 + r, -n));
      for (let i = 1; i <= n; i++) {
        const interest = bal * r, principal = pay - interest; bal -= principal;
        out.push({ i, pay, principal, interest, bal: Math.max(bal, 0) });
      }
    }
    return { rows: out, totalInterest: out.reduce((s, x) => s + x.interest, 0), first: out[0].pay };
  }, [amount, rate, months, method]);

  return (
    <div className="calc">
      <div className="form" style={{ marginTop: 0 }}>
        <label>Loan amount (ETB)<input type="number" min="1" value={amount} onChange={(e) => setAmount(e.target.value)} /></label>
        <label>Annual interest rate (%)<input type="number" min="0" step="0.1" value={rate} onChange={(e) => setRate(e.target.value)} /></label>
        <label>Term (months)<input type="number" min="1" max="360" value={months} onChange={(e) => setMonths(e.target.value)} /></label>
        <label>Interest method
          <select value={method} onChange={(e) => setMethod(e.target.value)}>
            <option value="reducing">Reducing balance</option>
            <option value="flat">Flat rate</option>
          </select>
        </label>
      </div>
      <div>
        <div className="sum">
          <div>Monthly payment<b>{fmt(first)}</b></div>
          <div>Total interest<b>{fmt(totalInterest)}</b></div>
          <div>Total repayment<b>{fmt(Number(amount) + totalInterest)}</b></div>
        </div>
        <div className="tbl">
          <table>
            <thead><tr><th>Month</th><th>Payment</th><th>Principal</th><th>Interest</th><th>Balance</th></tr></thead>
            <tbody>
              {rows.map((x) => (
                <tr key={x.i}><td>{x.i}</td><td>{fmt(x.pay)}</td><td>{fmt(x.principal)}</td><td>{fmt(x.interest)}</td><td>{fmt(x.bal)}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
EOF

cat > components/ContactForm.js <<'EOF'
"use client";
import { useState } from "react";

export default function ContactForm() {
  const [f, setF] = useState({ name: "", email: "", phone: "", message: "" });
  const [s, setS] = useState(null);
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  async function submit(e) {
    e.preventDefault(); setS(null);
    const r = await fetch("/api/contact", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(f) });
    const d = await r.json();
    if (r.ok) { setS({ ok: true, t: "Message sent. We will reply soon." }); setF({ name: "", email: "", phone: "", message: "" }); }
    else setS({ ok: false, t: d.error });
  }

  return (
    <form className="form" onSubmit={submit}>
      <label>Full name<input value={f.name} onChange={set("name")} required /></label>
      <label>Email<input type="email" value={f.email} onChange={set("email")} required /></label>
      <label>Phone<input value={f.phone} onChange={set("phone")} /></label>
      <label>Message<textarea value={f.message} onChange={set("message")} required /></label>
      <button className="btn">Send message</button>
      {s && <div className={`msg ${s.ok ? "ok" : "err"}`}>{s.t}</div>}
    </form>
  );
}
EOF

cat > components/FeedbackForm.js <<'EOF'
"use client";
import { useEffect, useState } from "react";

export default function FeedbackForm() {
  const [name, setName] = useState("");
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");
  const [s, setS] = useState(null);
  const [list, setList] = useState([]);
  const load = () => fetch("/api/feedback").then((r) => r.json()).then(setList).catch(() => {});
  useEffect(() => { load(); }, []);

  async function submit(e) {
    e.preventDefault(); setS(null);
    const r = await fetch("/api/feedback", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name, rating, comment }) });
    const d = await r.json();
    if (r.ok) { setS({ ok: true, t: "Thank you for your feedback." }); setName(""); setRating(0); setComment(""); load(); }
    else setS({ ok: false, t: d.error });
  }

  return (
    <>
      <form className="form" onSubmit={submit}>
        <label>Name (optional)<input value={name} onChange={(e) => setName(e.target.value)} /></label>
        <div>
          <b>Rating</b>
          <div className="stars" role="radiogroup" aria-label="Rating">
            {[1, 2, 3, 4, 5].map((n) => (
              <button type="button" key={n} className={n <= rating ? "on" : ""} onClick={() => setRating(n)} aria-label={`${n} star`}>&#9733;</button>
            ))}
          </div>
        </div>
        <label>Your comment<textarea value={comment} onChange={(e) => setComment(e.target.value)} required /></label>
        <button className="btn">Submit feedback</button>
        {s && <div className={`msg ${s.ok ? "ok" : "err"}`}>{s.t}</div>}
      </form>
      <div className="grid">
        {list.map((x, i) => (
          <div className="box" key={i}>
            <h3>{x.name} <span style={{ color: "var(--gold)" }}>{"\u2605".repeat(x.rating)}</span></h3>
            <p>{x.comment}</p>
          </div>
        ))}
      </div>
    </>
  );
}
EOF

# ---------------- Frontend: pages ----------------
cat > app/page.js <<'EOF'
import Link from "next/link";

const items = [
  ["Regular savings", "Build a habit with monthly deposits and earn annual dividends as a member."],
  ["Member loans", "Borrow against your savings with clear terms and a repayment schedule you can plan around."],
  ["Loan calculator", "See your monthly payment and full amortization table before you apply."],
];

export default function Home() {
  return (
    <>
      <section className="hero">
        <div className="wrap">
          <h1>Save together. Borrow fairly. Grow as members.</h1>
          <p>Gold Star SACCO gives members a safe place to save and access affordable credit.</p>
          <Link href="/services" className="btn">Calculate your loan</Link>
          <Link href="/contact" className="btn alt">Become a member</Link>
        </div>
      </section>
      <section className="section">
        <div className="wrap">
          <h2>What members use most</h2>
          <div className="grid">
            {items.map(([t, d]) => <div className="box" key={t}><h3>{t}</h3><p>{d}</p></div>)}
          </div>
        </div>
      </section>
    </>
  );
}
EOF

cat > app/services/page.js <<'EOF'
import LoanCalculator from "@/components/LoanCalculator";

export const metadata = { title: "Services | Gold Star SACCO" };

const items = [
  ["Savings accounts", "Compulsory and voluntary savings for members."],
  ["Loans", "Personal, business, and emergency loans for members."],
  ["Member education", "Training on saving, budgeting, and managing credit."],
];

export default function Services() {
  return (
    <>
      <section className="section">
        <div className="wrap">
          <h2>Our services</h2>
          <div className="grid">
            {items.map(([t, d]) => <div className="box" key={t}><h3>{t}</h3><p>{d}</p></div>)}
          </div>
        </div>
      </section>
      <section className="section soft" id="calculator">
        <div className="wrap">
          <h2>Loan amortization calculator</h2>
          <p className="lead">Enter the amount, rate, and term to see each month's payment. Results are estimates; final terms are set by GSS.</p>
          <LoanCalculator />
        </div>
      </section>
    </>
  );
}
EOF

cat > app/about/page.js <<'EOF'
export const metadata = { title: "About | Gold Star SACCO" };

export default function About() {
  return (
    <section className="section">
      <div className="wrap">
        <h2>About Gold Star SACCO</h2>
        <p className="lead">Gold Star SACCO is a member-owned savings and credit cooperative. Members pool their savings and borrow from the pool at fair terms. [Replace with your history, registration details, and leadership.]</p>
        <div className="grid">
          <div className="box"><h3>Mission</h3><p>[Add mission statement]</p></div>
          <div className="box"><h3>Vision</h3><p>[Add vision statement]</p></div>
          <div className="box"><h3>Values</h3><p>Transparency, member ownership, and shared growth.</p></div>
        </div>
      </div>
    </section>
  );
}
EOF

cat > app/contact/page.js <<'EOF'
import ContactForm from "@/components/ContactForm";

export const metadata = { title: "Contact | Gold Star SACCO" };

export default function Contact() {
  return (
    <section className="section">
      <div className="wrap">
        <h2>Contact us</h2>
        <p className="lead">Send a message and the GSS team will reply by email or phone.</p>
        <ContactForm />
      </div>
    </section>
  );
}
EOF

cat > app/feedback/page.js <<'EOF'
import FeedbackForm from "@/components/FeedbackForm";

export const metadata = { title: "Feedback | Gold Star SACCO" };

export default function Feedback() {
  return (
    <section className="section">
      <div className="wrap">
        <h2>Member feedback</h2>
        <p className="lead">Tell us how we are doing and what we should improve.</p>
        <FeedbackForm />
      </div>
    </section>
  );
}
EOF

cat > jsconfig.json <<'EOF'
{ "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["./*"] } } }
EOF

cat > .gitignore <<'EOF'
node_modules
.next
.env.local
data/*.db
EOF

echo "Done. Next: cd goldstar-sacco && npm install && cp .env.example .env.local (add your API key) && npm run dev"
