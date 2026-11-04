'use client';

import { FormEvent, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export default function LoginPage() {
  const [erro, setErro] = useState('');
  const [busy, setBusy] = useState(false);
  async function entrar(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setErro(''); setBusy(true);
    const form = new FormData(event.currentTarget);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email: String(form.get('email')), password: String(form.get('senha')) });
    if (error) { setErro('Não foi possível entrar. Confira o e-mail e a senha.'); setBusy(false); return; }
    window.location.assign('/');
  }
  return <main className="login-shell"><section className="login-card">
    <div className="brand"><img src="/atlas-logo.svg" alt="Atlas Soluções Comerciais" className="brand-logo"/></div>
    <p className="eyebrow">GESTÃO COMERCIAL</p><h1>Bem-vindo de volta</h1><p className="muted">Entre para acompanhar suas propostas.</p>
    <form onSubmit={entrar} className="form-stack"><label>E-mail<input name="email" type="email" autoComplete="username" required placeholder="voce@empresa.com" /></label><label>Senha<input name="senha" type="password" autoComplete="current-password" required /></label>{erro&&<p className="error">{erro}</p>}<button className="primary" disabled={busy}>{busy?'Entrando…':'Entrar'}</button></form>
    <p className="login-foot">Acesso individual e seguro</p>
  </section><aside className="login-aside"><div className="orb orb-one"/><div className="orb orb-two"/><div className="aside-content"><span className="eyebrow light">ATLAS SOLUÇÕES COMERCIAIS</span><h2>Clareza para<br/>cada oportunidade.</h2><p>Organize sua carteira, acompanhe resultados e mantenha cada negociação em movimento.</p><div className="aside-rule"/><span className="aside-note">Seu próximo passo começa aqui.</span></div></aside></main>;
}
