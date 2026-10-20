'use client';
import { FormEvent, useCallback, useEffect, useRef, useState } from 'react';
import { Archive, BookOpen, ExternalLink, Pencil, Plus, RefreshCw, X } from 'lucide-react';
import { callAdmin } from '@/lib/callables';
import { demoMode } from '@/lib/firebase';
import { demoData } from '@/lib/demo-data';
import { formatAdminActionError } from '@/lib/action-errors';
import type { AppUser } from '@/lib/types';
import { canManageInfoScope, infoItemInHub, infoScopeLabel, type InfoData, type InfoItem } from '@/lib/info-centre';
import { Badge, Button, Card, Field, Input, Select, Textarea } from './ui';

const empty: InfoData = { structure: { leagues: [], hubs: [], teams: [] }, sections: [], entries: [], policies: [] };
type EditorState = { type: 'section' | 'entry'; item?: InfoItem; section?: InfoItem };

export function InfoCentreWorkspace({ currentUser, orgId }: { currentUser: AppUser; orgId?: string }) {
  const key = `${currentUser.id}:${currentUser.role}:${orgId ?? ''}`;
  const scope = useRef(key);
  const generation = useRef(0);
  useEffect(() => { scope.current = key; }, [key]);
  const [state, setState] = useState<{ key: string; data: InfoData }>({ key, data: empty });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [hubId, setHubId] = useState('');
  const [preview, setPreview] = useState(false);
  const [editor, setEditor] = useState<EditorState | null>(null);
  const [busy, setBusy] = useState(false);
  const data = state.key === key ? state.data : empty;
  const load = useCallback(async () => {
    const request = ++generation.current;
    if (!orgId) { setLoading(false); return; }
    setLoading(true); setError('');
    try {
      const result = demoMode ? {
        ...empty,
        structure: { leagues: demoData.leagues, hubs: demoData.hubs, teams: demoData.teams }
      } : await callAdmin<InfoData>('infoCentreList', { orgId, preview });
      if (scope.current === key && request === generation.current) setState({ key, data: result });
    } catch (caught) {
      if (scope.current === key && request === generation.current) {
        setState({ key, data: empty }); setError(formatAdminActionError(caught));
      }
    } finally { if (scope.current === key && request === generation.current) setLoading(false); }
  }, [key, orgId, preview]);
  useEffect(() => {
    setHubId(''); setEditor(null);
    void load();
    const requestGeneration = generation.current;
    return () => { generation.current = requestGeneration + 1; };
  }, [load]);
  async function save(payload: Record<string, unknown>) {
    if (demoMode) { setError('Publishing is disabled in demo mode.'); return; }
    if (!orgId || busy) return;
    const requestKey = key;
    setBusy(true); setError('');
    try {
      await callAdmin('infoCentreUpsert', { ...payload, orgId });
      if (scope.current !== requestKey) return;
      setEditor(null); await load();
    } catch (caught) { if (scope.current === requestKey) setError(formatAdminActionError(caught)); }
    finally { if (scope.current === requestKey) setBusy(false); }
  }
  const sections = data.sections.filter((item) => infoItemInHub(item, hubId, data));
  return <div className="space-y-6">
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div><p className="text-xs font-bold uppercase tracking-widest text-muted">Resources</p>
        <h1 className="mt-1 text-3xl font-extrabold text-ink">Info Centre</h1>
        <p className="mt-2 max-w-2xl text-muted">Organize registration details, documents and useful links for your league, hubs and teams.</p></div>
      <div className="flex flex-wrap gap-2"><Button variant="secondary" onClick={() => void load()} disabled={loading}><RefreshCw className="mr-2 size-4" />Refresh</Button>
        <Button disabled={!orgId || loading || !data.structure.leagues.length} onClick={() => { setError(''); setEditor({ type: 'section' }); }}><Plus className="mr-2 size-4" />New section</Button></div>
    </div>
    <Card className="flex flex-wrap items-center gap-4 p-4">
      <Field label="Hub"><Select value={hubId} onChange={(event) => setHubId(event.target.value)}><option value="">All accessible hubs</option>{data.structure.hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</Select></Field>
      <label className="flex min-h-11 items-center gap-2 text-sm text-ink"><input type="checkbox" checked={preview} onChange={(event) => setPreview(event.target.checked)} />Show published resources only</label>
    </Card>
    {error && <div role="alert" className="rounded-xl bg-rose-50 p-4 text-red-800">{error}</div>}
    {!orgId ? <Card className="p-8 text-muted">Select an organization to manage its resources.</Card> : loading ? <div role="status"><Card className="p-8 text-muted">Loading Info Centre…</Card></div> : sections.length === 0 ?
      <Card className="p-10 text-center"><BookOpen className="mx-auto size-9 text-teal" /><h2 className="mt-4 text-xl font-bold">No sections yet</h2><p className="mt-2 text-muted">Create a section, then add resources for the people who need them.</p></Card> : sections.map((section) =>
        <Card key={section.id} className="overflow-hidden">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line p-5"><div><h2 className="text-xl font-bold">{section.title}</h2><p className="text-sm text-muted">{infoScopeLabel(section, data)} · {section.audience === 'management' ? 'Managers and admins' : 'Members'}</p></div>
            <div className="flex items-center gap-2"><Badge tone={section.status === 'published' ? 'good' : 'neutral'}>{section.status}</Badge>{section.canManage && <Button variant="secondary" onClick={() => setEditor({ type: 'section', item: section })}><Pencil className="mr-2 size-4" />Edit section</Button>}
              {!preview && <Button variant="secondary" onClick={() => setEditor({ type: 'entry', section })}><Plus className="mr-2 size-4" />Add resource</Button>}</div></div>
          <div className="grid gap-4 p-5 md:grid-cols-2">{data.entries.filter((entry) => entry.sectionId === section.id && infoItemInHub(entry, hubId, data)).map((entry) =>
            <div key={entry.id} className="rounded-xl border border-line p-4"><div className="flex items-start justify-between gap-2"><h3 className="font-bold">{entry.title}</h3><Badge tone={entry.status === 'published' ? 'good' : 'neutral'}>{entry.status}</Badge></div>
              <p className="mt-1 text-xs text-muted">{infoScopeLabel(entry, data)} · {entry.audience === 'management' ? 'Managers and admins' : 'Members'}</p>
              {entry.notes && <p className="mt-3 whitespace-pre-wrap text-sm">{entry.notes}</p>}
              {entry.inviteCode && <p className="mt-3 text-sm">Invite code: <code className="rounded bg-slate-100 px-2 py-1">{entry.inviteCode}</code></p>}
              {entry.hasPassword && <p className="mt-2 text-xs text-muted">Password stored separately · {entry.passwordAudience === 'management' ? 'Managers and admins' : 'Resource audience'}</p>}
              {entry.url && <a className="mt-3 inline-flex min-h-11 items-center gap-2 font-bold text-teal underline" href={entry.url} target="_blank" rel="noopener noreferrer">Open {entry.kind === 'registration' ? 'registration' : entry.kind === 'document' ? 'document' : 'website'}<ExternalLink className="size-4" /></a>}
              {entry.policyId && <p className="mt-2 text-sm text-muted">{data.policies.find((policy) => policy.id === entry.policyId)?.name ?? 'Restricted policy'} · Existing policy permissions apply.</p>}
              {entry.canManage && <div className="mt-3 flex gap-2"><Button variant="secondary" onClick={() => setEditor({ type: 'entry', item: entry, section })}><Pencil className="mr-2 size-4" />Edit</Button><Button variant="ghost" disabled={busy} onClick={() => void save({ ...entry, type: 'entry', expectedRevision: entry.revision, status: 'archived' })}><Archive className="mr-2 size-4" />Archive</Button></div>}
            </div>)}
            {!data.entries.some((entry) => entry.sectionId === section.id) && <p className="text-sm text-muted">No resources in this section yet.</p>}
          </div>
        </Card>)}
    {editor && <InfoEditor key={`${key}:${editor.type}:${editor.item?.id ?? editor.section?.id ?? 'new'}`} editor={editor} data={data} currentUser={currentUser} busy={busy} onClose={() => setEditor(null)} onSave={save} error={error} />}
  </div>;
}

function InfoEditor({ editor, data, currentUser, busy, onClose, onSave, error }: {
  editor: EditorState; data: InfoData; currentUser: AppUser; busy: boolean;
  onClose: () => void; onSave: (payload: Record<string, unknown>) => Promise<void>; error: string;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const node = dialog.current;
    if (node && !node.open) {
      if (typeof node.showModal === 'function') node.showModal();
      else node.setAttribute('open', '');
    }
    return () => node?.close?.();
  }, []);
  const initial = editor.item ?? editor.section;
  const defaultTeam = currentUser.role === 'managerAdmin' && !currentUser.hubIds.length ? data.structure.teams.find((team) => currentUser.teamIds.includes(team.id)) : undefined;
  const [leagueId, setLeagueId] = useState(initial?.leagueId ?? defaultTeam?.leagueId ?? data.structure.leagues[0]?.id ?? '');
  const [hubId, setHubId] = useState(initial?.hubId ?? defaultTeam?.hubId ?? (currentUser.role === 'managerAdmin' ? currentUser.hubIds[0] : '') ?? '');
  const [teamId, setTeamId] = useState(initial?.teamId ?? defaultTeam?.id ?? '');
  const [title, setTitle] = useState(editor.item?.title ?? '');
  const [kind, setKind] = useState(editor.item?.kind ?? 'link');
  const [url, setUrl] = useState(editor.item?.url ?? '');
  const [notes, setNotes] = useState(editor.item?.notes ?? '');
  const [code, setCode] = useState(editor.item?.inviteCode ?? '');
  const [policyId, setPolicyId] = useState(editor.item?.policyId ?? '');
  const [audience, setAudience] = useState(initial?.audience ?? 'members');
  const [passwordAudience, setPasswordAudience] = useState(editor.item?.passwordAudience ?? 'management');
  const [password, setPassword] = useState('');
  const [removePassword, setRemovePassword] = useState(false);
  const [status, setStatus] = useState(editor.item?.status ?? 'draft');
  const [order, setOrder] = useState(editor.item?.sortOrder ?? 0);
  const target = { leagueId, hubId: hubId || null, teamId: teamId || null };
  const valid = canManageInfoScope(currentUser, target) && title.trim().length > 0;
  const description = `${audience === 'management' ? 'Managers and admins' : 'Members'} in ${infoScopeLabel(target, data)}`;
  async function submit(event: FormEvent) {
    event.preventDefault();
    const payload: Record<string, unknown> = { type: editor.type, id: editor.item?.id, expectedRevision: editor.item?.revision ?? 0,
      ...target, title, status, audience, sortOrder: Number(order) };
    if (editor.type === 'entry') Object.assign(payload, { sectionId: editor.section?.id ?? editor.item?.sectionId, kind, url, notes, inviteCode: code, policyId, passwordAudience });
    if (editor.type === 'entry' && (removePassword || password)) payload.password = removePassword ? null : password;
    // Firebase callable payloads must not contain undefined values.
    await onSave(Object.fromEntries(Object.entries(payload).filter(([, value]) => value !== undefined)));
  }
  return <dialog ref={dialog} onCancel={(event) => { event.preventDefault(); if (!busy) onClose(); }} className="fixed inset-0 m-0 h-full max-h-none w-full max-w-none overflow-y-auto bg-navy/70 p-4 sm:p-8" aria-labelledby="info-editor-title">
    <Card className="mx-auto max-w-3xl p-6"><div className="mb-5 flex items-center justify-between"><h2 id="info-editor-title" className="text-2xl font-bold">{editor.item ? 'Edit' : 'New'} {editor.type === 'section' ? 'section' : 'resource'}</h2><Button variant="ghost" aria-label="Close editor" disabled={busy} onClick={onClose}><X className="size-5" /></Button></div>
      <form onSubmit={(event) => void submit(event)} className="space-y-4">
        <Field label="Title"><Input autoFocus required maxLength={200} value={title} onChange={(event) => setTitle(event.target.value)} /></Field>
        <div className="grid gap-4 sm:grid-cols-3"><Field label="League"><Select required value={leagueId} onChange={(event) => { setLeagueId(event.target.value); setHubId(''); setTeamId(''); }}>{data.structure.leagues.map((league) => <option key={league.id} value={league.id}>{league.name}</option>)}</Select></Field>
          <Field label="Hub"><Select value={hubId} onChange={(event) => { setHubId(event.target.value); setTeamId(''); }}><option value="">Whole league</option>{data.structure.hubs.filter((hub) => hub.leagueId === leagueId).map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</Select></Field>
          <Field label="Team"><Select value={teamId} onChange={(event) => setTeamId(event.target.value)} disabled={!hubId}><option value="">Whole hub</option>{data.structure.teams.filter((team) => team.hubId === hubId).map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}</Select></Field></div>
        {editor.type === 'entry' && <><Field label="Resource type"><Select value={kind} onChange={(event) => setKind(event.target.value)}>{[['registration','Registration'],['link','Website'],['document','Document link'],['policy','Existing policy'],['note','Information']].map(([value,label]) => <option key={value} value={value}>{label}</option>)}</Select></Field>
          {['registration','link','document'].includes(kind) && <Field label="Website or document URL"><Input required type="url" value={url} onChange={(event) => setUrl(event.target.value)} /></Field>}
          {kind === 'policy' && <Field label="Existing policy"><Select required value={policyId} onChange={(event) => setPolicyId(event.target.value)}><option value="">Choose a policy</option>{data.policies.map((policy) => <option key={policy.id} value={policy.id}>{policy.name}</option>)}</Select><p className="mt-1 text-xs text-muted">The policy keeps its existing access permissions.</p></Field>}
          {kind === 'registration' && <Field label="Invite code"><Input value={code} maxLength={200} onChange={(event) => setCode(event.target.value)} /></Field>}
          <Field label="Notes"><Textarea rows={4} maxLength={10000} value={notes} onChange={(event) => setNotes(event.target.value)} /></Field>
          <Field label={editor.item?.hasPassword ? 'Replace password (leave blank to keep)' : 'Optional password'}><Input type="password" autoComplete="new-password" maxLength={500} value={password} onChange={(event) => setPassword(event.target.value)} /></Field>
          {(password || editor.item?.hasPassword) && <><Field label="Who may reveal the password?"><Select value={passwordAudience} onChange={(event) => setPasswordAudience(event.target.value as 'management' | 'members')}><option value="management">Managers and admins</option><option value="members">Everyone in the resource audience</option></Select></Field>{editor.item?.hasPassword && <label className="flex min-h-11 items-center gap-2"><input type="checkbox" checked={removePassword} onChange={(event) => setRemovePassword(event.target.checked)} />Remove stored password</label>}</>}
        </>}
        <div className="grid gap-4 sm:grid-cols-3"><Field label="Audience"><Select value={audience} onChange={(event) => setAudience(event.target.value as 'management' | 'members')}><option value="members">Members</option><option value="management">Managers and admins</option></Select></Field>
          <Field label="Publication"><Select value={status} onChange={(event) => setStatus(event.target.value as InfoItem['status'])}><option value="draft">Draft</option><option value="published">Published</option>{editor.item && <option value="archived">Archived</option>}</Select></Field>
          <Field label="Display order"><Input required type="number" min={0} max={10000} value={order} onChange={(event) => setOrder(Number(event.target.value))} /></Field></div>
        <div className="rounded-xl border border-line bg-shell p-4"><p className="text-xs font-bold uppercase text-muted">Member preview</p><h3 className="mt-2 font-bold">{title || 'Resource title'}</h3><p className="text-sm text-muted">Visible to: {description}</p>{notes && <p className="mt-2 whitespace-pre-wrap text-sm">{notes}</p>}</div>
        {!valid && <p className="text-sm text-red-800">Enter a title and choose a scope you manage.</p>}{error && <p role="alert" className="text-sm text-red-800">{error}</p>}
        <div className="flex justify-end gap-2"><Button type="button" variant="secondary" disabled={busy} onClick={onClose}>Cancel</Button><Button type="submit" disabled={busy || !valid}>{busy ? 'Saving…' : status === 'published' ? 'Publish' : 'Save'}</Button></div>
      </form></Card>
  </dialog>;
}
