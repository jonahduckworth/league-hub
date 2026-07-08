"use client";

import {
  Activity,
  Bell,
  Building2,
  ChevronRight,
  ClipboardList,
  ExternalLink,
  FileText,
  Layers,
  LayoutDashboard,
  LogOut,
  MapPin,
  Megaphone,
  Pin,
  PinOff,
  Plus,
  RefreshCw,
  Save,
  Search,
  ShieldAlert,
  ShieldCheck,
  Trash2,
  Trophy,
  UploadCloud,
  UserPlus,
  X,
  Users
} from "lucide-react";
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from "firebase/auth";
import { collection, doc, getDoc } from "firebase/firestore";
import { deleteObject, getDownloadURL, ref as storageRef, uploadBytes } from "firebase/storage";
import { DragEvent, FormEvent, useEffect, useRef, useState } from "react";
import { auth, db, demoMode, hasFirebaseConfig, storage } from "@/lib/firebase";
import { formatAdminActionError } from "@/lib/action-errors";
import { callAdmin, type CallableName } from "@/lib/callables";
import { useAdminData } from "@/lib/firestore";
import { assignableRoles, canAccessAdmin, canManageUser, roleLabel } from "@/lib/admin-access";
import { buildHealthChecks } from "@/lib/health";
import { activePendingInvitations } from "@/lib/invitations";
import { bytesLabel, dateLabel, timeAgo } from "@/lib/format";
import { isPolicyFileAllowed, policyStoragePath, POLICY_FILE_MAX_BYTES } from "@/lib/policy-upload";
import { demoUser } from "@/lib/demo-data";
import type {
  AdminData,
  Announcement,
  AnnouncementScope,
  AppUser,
  HealthCheck,
  Hub,
  League,
  Policy,
  Team,
  UserRole
} from "@/lib/types";
import { Badge, Button, Card, Field, Input, Select, TableWrap, Td, Textarea, Th } from "./ui";

type SectionId = "overview" | "people" | "structure" | "announcements" | "policies";

const navItems: Array<{ id: SectionId; label: string; icon: React.ComponentType<{ className?: string }> }> = [
  { id: "overview", label: "Overview", icon: LayoutDashboard },
  { id: "people", label: "People", icon: Users },
  { id: "structure", label: "Structure", icon: Building2 },
  { id: "announcements", label: "Announcements", icon: Megaphone },
  { id: "policies", label: "Policies", icon: FileText }
];

type ActionResult<T = unknown> =
  | { ok: true; data: T }
  | { ok: false; error: string };

type ActionRunner = (name: CallableName, payload?: Record<string, unknown>) => Promise<ActionResult>;

export function AdminApp() {
  const [currentUser, setCurrentUser] = useState<AppUser | null>(demoMode ? demoUser : null);
  const [authLoading, setAuthLoading] = useState(!demoMode && hasFirebaseConfig());
  const [section, setSection] = useState<SectionId>("overview");
  const [message, setMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const { data, loading, error, selectedOrgId, setSelectedOrgId, reloadStructure } = useAdminData(currentUser);

  useEffect(() => {
    if (demoMode || !auth || !db) return undefined;
    const firestore = db;
    return onAuthStateChanged(auth, async (firebaseUser) => {
      setAuthLoading(true);
      try {
        if (!firebaseUser) {
          setCurrentUser(null);
          return;
        }
        const userSnap = await getDoc(doc(firestore, "users", firebaseUser.uid));
        setCurrentUser(userSnap.exists() ? { id: userSnap.id, ...userSnap.data() } as AppUser : null);
      } finally {
        setAuthLoading(false);
      }
    });
  }, []);

  const runAction: ActionRunner = async (name, payload = {}) => {
    const orgId = selectedOrgId;
    if (!orgId) {
      const missingOrg = "Select an organization first.";
      setActionError(missingOrg);
      return { ok: false, error: missingOrg };
    }
    if (demoMode) {
      setMessage(`${name} is disabled in demo mode.`);
      return { ok: false, error: "Demo mode" };
    }
    setActionError(null);
    setMessage(null);
    try {
      const result = await callAdmin(name, { orgId, ...payload });
      if (name.startsWith("adminUpsert") || name.startsWith("adminDelete")) {
        await reloadStructure(orgId);
      }
      setMessage(`${name} completed.`);
      return { ok: true, data: result };
    } catch (caught) {
      const errorMessage = formatAdminActionError(caught);
      setActionError(errorMessage);
      return { ok: false, error: errorMessage };
    }
  };

  if (!demoMode && !hasFirebaseConfig()) {
    return <ConfigMissing />;
  }

  if (!currentUser) {
    return <LoginPanel loading={authLoading} />;
  }

  if (!canAccessAdmin(currentUser)) {
    return <BlockedPanel user={currentUser} />;
  }

  const title = navItems.find((item) => item.id === section)?.label ?? "Overview";

  return (
    <div className="min-h-screen">
      <aside className="fixed inset-y-0 left-0 z-20 hidden w-64 border-r border-line bg-white/90 px-3 py-4 shadow-soft backdrop-blur lg:block">
        <div className="flex min-h-14 items-center gap-3 px-2">
          <div className="grid size-11 place-items-center rounded-md bg-teal text-white">
            <ShieldCheck className="size-5" aria-hidden />
          </div>
          <div>
            <p className="text-sm font-black text-ink">League Hub</p>
            <p className="text-xs font-semibold text-muted">Admin</p>
          </div>
        </div>
        <nav className="mt-6 grid gap-1" aria-label="Admin sections">
          {navItems.map((item) => {
            const Icon = item.icon;
            const selected = section === item.id;
            return (
              <button
                key={item.id}
                type="button"
                className={`flex min-h-11 items-center gap-3 rounded-md px-3 text-sm font-semibold transition-colors ${
                  selected ? "bg-teal text-white" : "text-muted hover:bg-shell hover:text-ink"
                }`}
                onClick={() => setSection(item.id)}
              >
                <Icon className="size-4" aria-hidden />
                {item.label}
              </button>
            );
          })}
        </nav>
      </aside>

      <main className="lg:pl-64">
        <header className="sticky top-0 z-10 border-b border-line bg-shell/92 px-4 py-3 backdrop-blur md:px-6">
          <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <div>
              <h1 className="text-xl font-black text-ink md:text-2xl">{title}</h1>
              <p className="text-sm font-semibold text-muted">{data.selectedOrg?.name ?? "No organization selected"}</p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              {currentUser.role === "platformOwner" && (
                <select
                  aria-label="Organization"
                  value={selectedOrgId ?? ""}
                  onChange={(event) => setSelectedOrgId(event.target.value)}
                  className="min-h-11 rounded-md border border-line bg-white px-3 text-sm font-semibold"
                >
                  {data.orgs.map((org) => (
                    <option key={org.id} value={org.id}>{org.name}</option>
                  ))}
                </select>
              )}
              <Badge tone="info">{roleLabel(currentUser.role)}</Badge>
              <Button variant="secondary" onClick={() => selectedOrgId && reloadStructure(selectedOrgId)} aria-label="Refresh data">
                <RefreshCw className="size-4" aria-hidden />
                Refresh
              </Button>
              <Button variant="ghost" onClick={() => auth ? signOut(auth) : setCurrentUser(null)} aria-label="Sign out">
                <LogOut className="size-4" aria-hidden />
              </Button>
            </div>
          </div>
          <div className="mt-3 flex gap-2 overflow-x-auto lg:hidden" aria-label="Admin sections">
            {navItems.map((item) => (
              <button
                key={item.id}
                type="button"
                className={`min-h-10 whitespace-nowrap rounded-md px-3 text-sm font-semibold ${
                  section === item.id ? "bg-teal text-white" : "border border-line bg-white text-muted"
                }`}
                onClick={() => setSection(item.id)}
              >
                {item.label}
              </button>
            ))}
          </div>
        </header>

        <div className="px-4 py-5 md:px-6">
          {message && (
            <div className="mb-4 rounded-md border border-teal/20 bg-teal/10 px-4 py-3 text-sm font-semibold text-teal">
              {message}
            </div>
          )}
          {actionError && (
            <div className="mb-4 rounded-md border border-coral/20 bg-coral/10 px-4 py-3 text-sm font-semibold text-coral">
              {actionError}
            </div>
          )}
          {error && (
            <div className="mb-4 rounded-md border border-coral/20 bg-coral/10 px-4 py-3 text-sm font-semibold text-coral">
              {error}
            </div>
          )}
          {loading ? <LoadingState /> : renderSection(section, data, currentUser, runAction, selectedOrgId)}
        </div>
      </main>
    </div>
  );
}

function renderSection(section: SectionId, data: AdminData, currentUser: AppUser, runAction: ActionRunner, selectedOrgId?: string) {
  switch (section) {
    case "people":
      return <PeopleSection data={data} currentUser={currentUser} runAction={runAction} />;
    case "structure":
      return <StructureSection data={data} runAction={runAction} />;
    case "announcements":
      return <AnnouncementsSection data={data} runAction={runAction} />;
    case "policies":
      return <PoliciesSection data={data} runAction={runAction} selectedOrgId={selectedOrgId} />;
    default:
      return <OverviewSection data={data} />;
  }
}

function LoginPanel({ loading }: { loading: boolean }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    if (!auth) return;
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Sign in failed.");
    }
  }

  return (
    <main className="grid min-h-screen place-items-center px-4">
      <form className="w-full max-w-sm rounded-lg border border-line bg-white p-5 shadow-soft" onSubmit={submit}>
        <div className="mb-5 flex items-center gap-3">
          <div className="grid size-11 place-items-center rounded-md bg-teal text-white">
            <ShieldCheck className="size-5" aria-hidden />
          </div>
          <div>
            <h1 className="text-lg font-black text-ink">League Hub Admin</h1>
            <p className="text-sm font-semibold text-muted">Sign in</p>
          </div>
        </div>
        <div className="grid gap-3">
          <Field label="Email">
            <Input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" required />
          </Field>
          <Field label="Password">
            <Input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required />
          </Field>
          {error && <p className="text-sm font-semibold text-coral">{error}</p>}
          <Button type="submit" disabled={loading}>{loading ? "Checking..." : "Sign in"}</Button>
        </div>
      </form>
    </main>
  );
}

function ConfigMissing() {
  return (
    <main className="grid min-h-screen place-items-center px-4">
      <Card className="max-w-xl">
        <div className="flex items-start gap-3">
          <ShieldAlert className="mt-1 size-5 text-coral" aria-hidden />
          <div>
            <h1 className="text-lg font-black">Firebase web config required</h1>
            <p className="mt-2 text-sm font-semibold leading-6 text-muted">
              Add the values from `apps/admin/.env.example` before running the production admin app.
            </p>
          </div>
        </div>
      </Card>
    </main>
  );
}

function BlockedPanel({ user }: { user: AppUser }) {
  return (
    <main className="grid min-h-screen place-items-center px-4">
      <Card className="max-w-xl">
        <div className="flex items-start gap-3">
          <ShieldAlert className="mt-1 size-5 text-coral" aria-hidden />
          <div>
            <h1 className="text-lg font-black">Admin access unavailable</h1>
            <p className="mt-2 text-sm font-semibold leading-6 text-muted">
              {user.email} is signed in as {roleLabel(user.role)}.
            </p>
          </div>
        </div>
      </Card>
    </main>
  );
}

function LoadingState() {
  return (
    <div className="grid gap-4 md:grid-cols-3">
      {Array.from({ length: 6 }).map((_, index) => (
        <div key={index} className="h-32 animate-pulse rounded-lg border border-line bg-white" />
      ))}
    </div>
  );
}

function OverviewSection({ data }: { data: AdminData }) {
  const checks = buildHealthChecks(data);
  const pendingInvitations = activePendingInvitations(data);
  const metrics = [
    ["Active Users", data.users.filter((user) => user.isActive).length],
    ["Pending Invites", pendingInvitations.length],
    ["Leagues", data.leagues.length],
    ["Hubs", data.hubs.length],
    ["Teams", data.teams.length],
    ["Policies", data.policies.length],
    ["Announcements", data.announcements.length],
    ["Chat Rooms", data.chatRooms.length]
  ];

  return (
    <div className="grid gap-5">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {metrics.map(([label, value]) => (
          <Card key={label as string}>
            <p className="text-sm font-bold text-muted">{label}</p>
            <p className="mt-2 text-3xl font-black text-ink">{value}</p>
          </Card>
        ))}
      </div>
      <div className="grid gap-5 xl:grid-cols-[1fr_1.2fr]">
        <Card>
          <SectionTitle icon={ClipboardList} title="Health" />
          <HealthGrid checks={checks} />
        </Card>
        <Card>
          <SectionTitle icon={Activity} title="Recent Admin Activity" />
          <div className="mt-3 grid gap-2">
            {data.auditLogs.slice(0, 6).map((log) => (
              <div key={log.id} className="flex min-h-12 items-center justify-between gap-3 rounded-md border border-line px-3">
                <span className="truncate text-sm font-semibold">{log.action}</span>
                <span className="whitespace-nowrap text-xs font-semibold text-muted">{timeAgo(log.createdAt)}</span>
              </div>
            ))}
            {data.auditLogs.length === 0 && <EmptyLine label="No audit entries" />}
          </div>
        </Card>
      </div>
    </div>
  );
}

function ManagementLayout({
  children,
  sidebar
}: {
  children: React.ReactNode;
  sidebar: React.ReactNode;
}) {
  return (
    <div className="grid min-h-[calc(100vh-154px)] gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
      <div className="min-w-0">{children}</div>
      <aside className="grid content-start gap-4 xl:sticky xl:top-28 xl:max-h-[calc(100vh-8rem)] xl:overflow-auto">
        {sidebar}
      </aside>
    </div>
  );
}

function PanelHeader({
  icon: Icon,
  title,
  description,
  action
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col gap-3 border-b border-line bg-white px-4 py-4 md:flex-row md:items-center md:justify-between">
      <div className="flex min-w-0 items-start gap-3">
        <span className="grid size-10 shrink-0 place-items-center rounded-md border border-line bg-shell text-teal">
          <Icon className="size-5" aria-hidden />
        </span>
        <div className="min-w-0">
          <h2 className="text-base font-black text-ink">{title}</h2>
          {description && <p className="mt-1 text-sm font-semibold leading-5 text-muted">{description}</p>}
        </div>
      </div>
      {action}
    </div>
  );
}

function RowButton({
  children,
  selected,
  onClick,
  ariaLabel
}: {
  children: React.ReactNode;
  selected?: boolean;
  onClick: () => void;
  ariaLabel: string;
}) {
  return (
    <button
      type="button"
      aria-label={ariaLabel}
      onClick={onClick}
      className={`group flex min-h-[74px] w-full items-center gap-3 border-b border-line px-4 py-3 text-left transition-colors last:border-b-0 hover:bg-shell focus-visible:outline focus-visible:outline-2 focus-visible:outline-teal ${
        selected ? "bg-teal/10" : "bg-white"
      }`}
    >
      <div className="min-w-0 flex-1">{children}</div>
      <ChevronRight className="size-5 shrink-0 text-muted transition group-hover:translate-x-0.5 group-hover:text-ink" aria-hidden />
    </button>
  );
}

function StatTile({
  label,
  value,
  icon: Icon,
  tone = "teal"
}: {
  label: string;
  value: React.ReactNode;
  icon: React.ComponentType<{ className?: string }>;
  tone?: "teal" | "mint" | "amber" | "coral";
}) {
  const toneClass =
    tone === "mint" ? "bg-mint/10 text-[#1f765a]" :
    tone === "amber" ? "bg-amber/10 text-[#8b5a17]" :
    tone === "coral" ? "bg-coral/10 text-[#a83d32]" :
    "bg-teal/10 text-teal";

  return (
    <div className="rounded-lg border border-line bg-white p-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase text-muted">{label}</p>
          <p className="mt-1 text-2xl font-black text-ink">{value}</p>
        </div>
        <span className={`grid size-11 shrink-0 place-items-center rounded-md ${toneClass}`}>
          <Icon className="size-5" aria-hidden />
        </span>
      </div>
    </div>
  );
}

function InfoRow({
  label,
  value
}: {
  label: string;
  value?: React.ReactNode;
}) {
  return (
    <div className="rounded-md bg-shell px-3 py-2">
      <p className="text-xs font-bold uppercase text-muted">{label}</p>
      <div className="mt-1 text-sm font-semibold text-ink">{value || "Not set"}</div>
    </div>
  );
}

function DrawerSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="grid gap-3">
      <h3 className="text-sm font-black uppercase text-muted">{title}</h3>
      {children}
    </section>
  );
}

function SideDrawer({
  open,
  title,
  description,
  icon: Icon,
  onClose,
  children,
  footer
}: {
  open: boolean;
  title: string;
  description?: string;
  icon: React.ComponentType<{ className?: string }>;
  onClose: () => void;
  children: React.ReactNode;
  footer?: React.ReactNode;
}) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-40">
      <button
        type="button"
        aria-label="Close drawer"
        className="absolute inset-0 cursor-default bg-slate-950/30"
        onClick={onClose}
      />
      <aside
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="absolute right-0 top-0 flex h-full w-full max-w-xl flex-col border-l border-line bg-white shadow-2xl"
      >
        <div className="border-b border-line px-6 py-5">
          <div className="flex items-start justify-between gap-4">
            <div className="flex min-w-0 gap-3">
              <span className="grid size-10 shrink-0 place-items-center rounded-md border border-line bg-shell text-teal">
                <Icon className="size-5" aria-hidden />
              </span>
              <div className="min-w-0">
                <h2 className="text-lg font-black text-ink">{title}</h2>
                {description && <p className="mt-1 text-sm font-semibold leading-5 text-muted">{description}</p>}
              </div>
            </div>
            <Button variant="ghost" aria-label="Close drawer" onClick={onClose}>
              <X className="size-4" aria-hidden />
            </Button>
          </div>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-6">
          <div className="grid gap-6">{children}</div>
        </div>
        {footer && (
          <div className="flex flex-col-reverse gap-3 border-t border-line px-6 py-4 sm:flex-row sm:justify-end">
            {footer}
          </div>
        )}
      </aside>
    </div>
  );
}

function PeopleSection({ data, currentUser, runAction }: { data: AdminData; currentUser: AppUser; runAction: ActionRunner }) {
  const [query, setQuery] = useState("");
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [selectedInviteId, setSelectedInviteId] = useState<string | null>(null);
  const [inviteRole, setInviteRole] = useState<UserRole>("staff");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteName, setInviteName] = useState("");
  const [inviteHubIds, setInviteHubIds] = useState<string[]>([]);
  const [inviteTeamIds, setInviteTeamIds] = useState<string[]>([]);

  const filteredUsers = data.users.filter((user) => {
    const haystack = `${user.displayName} ${user.email} ${user.title ?? ""}`.toLowerCase();
    return haystack.includes(query.toLowerCase());
  });
  const pendingInvitations = activePendingInvitations(data);
  const selectedUser = selectedUserId ? data.users.find((user) => user.id === selectedUserId) ?? null : null;
  const selectedInvite = selectedInviteId ? pendingInvitations.find((invite) => invite.id === selectedInviteId) ?? null : null;
  const activeUsers = data.users.filter((user) => user.isActive);
  const manageable = selectedUser ? canManageUser(currentUser, selectedUser) : false;

  async function submitInvite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = await runAction("adminCreateInvitation", {
      email: inviteEmail,
      displayName: inviteName || undefined,
      role: inviteRole,
      hubIds: inviteHubIds,
      teamIds: inviteTeamIds
    });
    if (!result.ok) return;
    setInviteEmail("");
    setInviteName("");
    setInviteHubIds([]);
    setInviteTeamIds([]);
  }

  return (
    <>
      <ManagementLayout
        sidebar={
          <>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
              <StatTile label="Active Users" value={activeUsers.length} icon={Users} />
              <StatTile label="Pending Invites" value={pendingInvitations.length} icon={UserPlus} tone="amber" />
            </div>
            <Card>
              <SectionTitle icon={Plus} title="Invite" />
              <form className="mt-3 grid gap-3" onSubmit={submitInvite}>
                <Field label="Email"><Input type="email" value={inviteEmail} onChange={(event) => setInviteEmail(event.target.value)} required /></Field>
                <Field label="Name"><Input value={inviteName} onChange={(event) => setInviteName(event.target.value)} /></Field>
                <Field label="Role">
                  <Select value={inviteRole} onChange={(event) => setInviteRole(event.target.value as UserRole)}>
                    {assignableRoles(currentUser).map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
                  </Select>
                </Field>
                <CheckboxGroup label="Hubs" options={data.hubs.map((hub) => ({ id: hub.id, label: hub.name }))} values={inviteHubIds} setValues={setInviteHubIds} />
                <CheckboxGroup label="Teams" options={data.teams.filter((team) => inviteHubIds.includes(team.hubId)).map((team) => ({ id: team.id, label: team.name }))} values={inviteTeamIds} setValues={setInviteTeamIds} />
                <Button type="submit"><Plus className="size-4" aria-hidden />Create Invite</Button>
              </form>
            </Card>
            <Card>
              <SectionTitle icon={Bell} title="Pending Invites" />
              <div className="mt-3 overflow-hidden rounded-lg border border-line bg-white">
                {pendingInvitations.map((invite) => (
                  <RowButton
                    key={invite.id}
                    selected={selectedInvite?.id === invite.id}
                    onClick={() => {
                      setSelectedInviteId(invite.id);
                      setSelectedUserId(null);
                    }}
                    ariaLabel={`Open invite for ${invite.email}`}
                  >
                    <div className="font-bold text-ink">{invite.email}</div>
                    <div className="mt-1 text-xs font-semibold text-muted">{roleLabel(invite.role)} · {dateLabel(invite.createdAt)}</div>
                  </RowButton>
                ))}
                {pendingInvitations.length === 0 && <EmptyLine label="No pending invites" />}
              </div>
            </Card>
          </>
        }
      >
        <section className="overflow-hidden rounded-lg border border-line bg-white">
          <PanelHeader
            icon={Users}
            title="Users"
            description="Open a user row to adjust role and access in a drawer."
            action={
              <label className="relative block w-full md:w-80">
                <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden />
                <Input aria-label="Search users" className="pl-9" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search users" />
              </label>
            }
          />
          <TableWrap>
            <table className="min-w-[780px] w-full border-collapse">
              <thead className="bg-shell">
                <tr>
                  <Th>Name</Th>
                  <Th>Role</Th>
                  <Th>Status</Th>
                  <Th>Scope</Th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user) => (
                  <tr
                    key={user.id}
                    tabIndex={0}
                    role="button"
                    aria-label={`Open ${user.displayName}`}
                    onClick={() => {
                      setSelectedUserId(user.id);
                      setSelectedInviteId(null);
                    }}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        setSelectedUserId(user.id);
                        setSelectedInviteId(null);
                      }
                    }}
                    className={`cursor-pointer border-t border-line transition-colors hover:bg-shell focus-visible:outline focus-visible:outline-2 focus-visible:outline-teal ${
                      selectedUser?.id === user.id ? "bg-teal/10" : ""
                    }`}
                  >
                    <Td>
                      <div className="font-bold">{user.displayName}</div>
                      <div className="truncate text-xs font-semibold text-muted">{user.email}</div>
                    </Td>
                    <Td><Badge tone={user.role === "staff" ? "neutral" : "info"}>{roleLabel(user.role)}</Badge></Td>
                    <Td><Badge tone={user.isActive ? "good" : "danger"}>{user.isActive ? "Active" : "Inactive"}</Badge></Td>
                    <Td>{user.hubIds.length} hubs · {user.teamIds.length} teams</Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </TableWrap>
          {filteredUsers.length === 0 && <div className="p-4"><EmptyLine label="No users match this search" /></div>}
        </section>
      </ManagementLayout>

      <SideDrawer
        open={Boolean(selectedUser || selectedInvite)}
        title={selectedUser?.displayName ?? selectedInvite?.email ?? "Details"}
        description={selectedUser ? selectedUser.email : selectedInvite ? "Pending invitation" : undefined}
        icon={selectedUser ? Users : UserPlus}
        onClose={() => {
          setSelectedUserId(null);
          setSelectedInviteId(null);
        }}
      >
        {selectedUser && (
          <>
            <DrawerSection title="Profile">
              <div className="grid gap-3 sm:grid-cols-2">
                <InfoRow label="Email" value={selectedUser.email} />
                <InfoRow label="Status" value={<Badge tone={selectedUser.isActive ? "good" : "danger"}>{selectedUser.isActive ? "Active" : "Inactive"}</Badge>} />
                <InfoRow label="Role" value={roleLabel(selectedUser.role)} />
                <InfoRow label="Scope" value={`${selectedUser.hubIds.length} hubs · ${selectedUser.teamIds.length} teams`} />
              </div>
            </DrawerSection>
            <DrawerSection title="Access">
              {manageable ? (
                <div className="grid gap-3">
                  <Field label="Role">
                    <Select
                      value={selectedUser.role}
                      onChange={(event) => runAction("adminUpdateUserAccess", { targetUserId: selectedUser.id, role: event.target.value })}
                    >
                      {assignableRoles(currentUser).map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
                    </Select>
                  </Field>
                  <Button
                    variant={selectedUser.isActive ? "danger" : "secondary"}
                    onClick={() => runAction("adminUpdateUserAccess", { targetUserId: selectedUser.id, isActive: !selectedUser.isActive })}
                  >
                    {selectedUser.isActive ? "Deactivate User" : "Reactivate User"}
                  </Button>
                </div>
              ) : (
                <EmptyLine label="You cannot manage this user from your current role" />
              )}
            </DrawerSection>
          </>
        )}
        {selectedInvite && (
          <>
            <DrawerSection title="Invite">
              <div className="grid gap-3 sm:grid-cols-2">
                <InfoRow label="Email" value={selectedInvite.email} />
                <InfoRow label="Role" value={roleLabel(selectedInvite.role)} />
                <InfoRow label="Created" value={dateLabel(selectedInvite.createdAt)} />
                <InfoRow label="Status" value={<Badge tone="warning">Pending</Badge>} />
              </div>
            </DrawerSection>
            <DrawerSection title="Scope">
              <InfoRow label="Hubs" value={selectedInvite.hubIds.length || "None"} />
              <InfoRow label="Teams" value={selectedInvite.teamIds.length || "None"} />
            </DrawerSection>
            <Button variant="danger" onClick={() => runAction("adminExpireInvitation", { invitationId: selectedInvite.id })}>
              Expire Invite
            </Button>
          </>
        )}
      </SideDrawer>
    </>
  );
}

type StructureSelection =
  | { type: "league"; league: League }
  | { type: "hub"; league: League; hub: Hub }
  | { type: "team"; league: League; hub: Hub; team: Team };

function StructureSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [selection, setSelection] = useState<StructureSelection | null>(null);

  return (
    <>
      <ManagementLayout
        sidebar={
          <>
            <div className="grid gap-3 sm:grid-cols-3 xl:grid-cols-1">
              <StatTile label="Leagues" value={data.leagues.length} icon={Trophy} />
              <StatTile label="Hubs" value={data.hubs.length} icon={MapPin} tone="mint" />
              <StatTile label="Teams" value={data.teams.length} icon={Users} tone="amber" />
            </div>
            <StructureForms data={data} runAction={runAction} />
          </>
        }
      >
        <section className="overflow-hidden rounded-lg border border-line bg-white">
          <PanelHeader
            icon={Building2}
            title="League Structure"
            description="Click any league, hub, or team to edit it in the drawer."
          />
          <div className="divide-y divide-line">
            {data.leagues.map((league) => {
              const hubs = data.hubs.filter((hub) => hub.leagueId === league.id);
              const leagueTeams = data.teams.filter((team) => team.leagueId === league.id);
              return (
                <div key={league.id} className="bg-white">
                  <RowButton
                    selected={selection?.type === "league" && selection.league.id === league.id}
                    onClick={() => setSelection({ type: "league", league })}
                    ariaLabel={`Open ${league.name}`}
                  >
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-black text-ink">{league.name}</span>
                      <Badge tone="info">{league.abbreviation}</Badge>
                    </div>
                    <div className="mt-1 text-xs font-semibold text-muted">{hubs.length} hubs · {leagueTeams.length} teams</div>
                  </RowButton>
                  <div className="bg-shell/60 px-4 py-3">
                    <div className="grid gap-2">
                      {hubs.map((hub) => {
                        const hubTeams = data.teams.filter((team) => team.hubId === hub.id);
                        return (
                          <div key={hub.id} className="overflow-hidden rounded-md border border-line bg-white">
                            <RowButton
                              selected={selection?.type === "hub" && selection.hub.id === hub.id}
                              onClick={() => setSelection({ type: "hub", league, hub })}
                              ariaLabel={`Open ${hub.name}`}
                            >
                              <div className="font-bold text-ink">{hub.name}</div>
                              <div className="mt-1 text-xs font-semibold text-muted">{hub.location || "No location"} · {hubTeams.length} teams</div>
                            </RowButton>
                            <div className="grid gap-1 border-t border-line bg-shell p-2 sm:grid-cols-2 2xl:grid-cols-3">
                              {hubTeams.map((team) => (
                                <button
                                  key={team.id}
                                  type="button"
                                  onClick={() => setSelection({ type: "team", league, hub, team })}
                                  className={`flex min-h-10 items-center justify-between gap-2 rounded-md border border-line bg-white px-3 text-left text-xs font-semibold transition-colors hover:border-teal hover:bg-teal/5 ${
                                    selection?.type === "team" && selection.team.id === team.id ? "border-teal bg-teal/10" : ""
                                  }`}
                                >
                                  <span className="truncate">{team.name}</span>
                                  <ChevronRight className="size-3 shrink-0 text-muted" aria-hidden />
                                </button>
                              ))}
                              {hubTeams.length === 0 && <div className="rounded-md border border-dashed border-line bg-white px-3 py-3 text-xs font-semibold text-muted">No teams</div>}
                            </div>
                          </div>
                        );
                      })}
                      {hubs.length === 0 && <EmptyLine label="No hubs in this league" />}
                    </div>
                  </div>
                </div>
              );
            })}
            {data.leagues.length === 0 && <div className="p-4"><EmptyLine label="No leagues" /></div>}
          </div>
        </section>
      </ManagementLayout>
      <StructureEditorDrawer selection={selection} onClose={() => setSelection(null)} runAction={runAction} />
    </>
  );
}

function StructureEditorDrawer({
  selection,
  onClose,
  runAction
}: {
  selection: StructureSelection | null;
  onClose: () => void;
  runAction: ActionRunner;
}) {
  const [name, setName] = useState("");
  const [abbreviation, setAbbreviation] = useState("");
  const [location, setLocation] = useState("");
  const [ageGroup, setAgeGroup] = useState("");
  const [division, setDivision] = useState("");

  useEffect(() => {
    if (!selection) return;
    if (selection.type === "league") {
      setName(selection.league.name);
      setAbbreviation(selection.league.abbreviation);
      setLocation("");
      setAgeGroup("");
      setDivision("");
    }
    if (selection.type === "hub") {
      setName(selection.hub.name);
      setAbbreviation("");
      setLocation(selection.hub.location ?? "");
      setAgeGroup("");
      setDivision("");
    }
    if (selection.type === "team") {
      setName(selection.team.name);
      setAbbreviation("");
      setLocation("");
      setAgeGroup(selection.team.ageGroup ?? "");
      setDivision(selection.team.division ?? "");
    }
  }, [selection]);

  async function save() {
    if (!selection) return;
    if (selection.type === "league") {
      await runAction("adminUpsertLeague", {
        league: {
          id: selection.league.id,
          name,
          abbreviation,
          iconName: selection.league.iconName ?? "league"
        }
      });
    }
    if (selection.type === "hub") {
      await runAction("adminUpsertHub", {
        leagueId: selection.league.id,
        hub: {
          id: selection.hub.id,
          name,
          location,
          iconName: selection.hub.iconName ?? "hub"
        }
      });
    }
    if (selection.type === "team") {
      await runAction("adminUpsertTeam", {
        leagueId: selection.league.id,
        hubId: selection.hub.id,
        team: {
          id: selection.team.id,
          name,
          ageGroup,
          division,
          iconName: selection.team.iconName ?? "team",
          memberIds: selection.team.memberIds
        }
      });
    }
  }

  async function deleteSelection() {
    if (!selection) return;
    if (selection.type === "league") {
      await runAction("adminDeleteLeague", { leagueId: selection.league.id });
    }
    if (selection.type === "hub") {
      await runAction("adminDeleteHub", { leagueId: selection.league.id, hubId: selection.hub.id });
    }
    if (selection.type === "team") {
      await runAction("adminDeleteTeam", { leagueId: selection.league.id, hubId: selection.hub.id, teamId: selection.team.id });
    }
    onClose();
  }

  const title =
    selection?.type === "league" ? selection.league.name :
    selection?.type === "hub" ? selection.hub.name :
    selection?.type === "team" ? selection.team.name :
    "Structure";
  const Icon =
    selection?.type === "league" ? Trophy :
    selection?.type === "hub" ? MapPin :
    Users;

  return (
    <SideDrawer
      open={Boolean(selection)}
      title={title}
      description={selection ? `${selection.type[0].toUpperCase()}${selection.type.slice(1)} details` : undefined}
      icon={Icon}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" onClick={save}><Save className="size-4" aria-hidden />Save</Button>
          <Button variant="danger" onClick={deleteSelection}><Trash2 className="size-4" aria-hidden />Delete</Button>
        </>
      }
    >
      {selection && (
        <>
          <DrawerSection title="Details">
            <Field label="Name"><Input value={name} onChange={(event) => setName(event.target.value)} required /></Field>
            {selection.type === "league" && <Field label="Abbreviation"><Input value={abbreviation} onChange={(event) => setAbbreviation(event.target.value)} required /></Field>}
            {selection.type === "hub" && <Field label="Location"><Input value={location} onChange={(event) => setLocation(event.target.value)} /></Field>}
            {selection.type === "team" && (
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label="Age"><Input value={ageGroup} onChange={(event) => setAgeGroup(event.target.value)} /></Field>
                <Field label="Division"><Input value={division} onChange={(event) => setDivision(event.target.value)} /></Field>
              </div>
            )}
          </DrawerSection>
          <DrawerSection title="Context">
            <div className="grid gap-3 sm:grid-cols-2">
              {selection.type !== "league" && <InfoRow label="League" value={selection.league.name} />}
              {selection.type === "team" && <InfoRow label="Hub" value={selection.hub.name} />}
              {selection.type === "team" && <InfoRow label="Members" value={selection.team.memberIds.length} />}
            </div>
          </DrawerSection>
        </>
      )}
    </SideDrawer>
  );
}

function StructureForms({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [leagueName, setLeagueName] = useState("");
  const [leagueAbbrev, setLeagueAbbrev] = useState("");
  const [leagueId, setLeagueId] = useState("");
  const [hubName, setHubName] = useState("");
  const [hubLocation, setHubLocation] = useState("");
  const [hubId, setHubId] = useState("");
  const [teamName, setTeamName] = useState("");
  const [teamAge, setTeamAge] = useState("");
  const [teamDivision, setTeamDivision] = useState("");

  async function createLeague(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = await runAction("adminUpsertLeague", { league: { name: leagueName, abbreviation: leagueAbbrev, iconName: "league" } });
    if (!result.ok) return;
    setLeagueName("");
    setLeagueAbbrev("");
  }

  async function createHub(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = await runAction("adminUpsertHub", { leagueId, hub: { name: hubName, location: hubLocation, iconName: "hub" } });
    if (!result.ok) return;
    setHubName("");
    setHubLocation("");
  }

  async function createTeam(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const hub = data.hubs.find((item) => item.id === hubId);
    if (!hub) return;
    const result = await runAction("adminUpsertTeam", { leagueId: hub.leagueId, hubId, team: { name: teamName, ageGroup: teamAge, division: teamDivision, iconName: "team" } });
    if (!result.ok) return;
    setTeamName("");
    setTeamAge("");
    setTeamDivision("");
  }

  return (
    <div className="grid gap-4 content-start">
      <Card>
        <SectionTitle icon={Plus} title="New League" />
        <form className="mt-3 grid gap-3" onSubmit={createLeague}>
          <Field label="Name"><Input value={leagueName} onChange={(event) => setLeagueName(event.target.value)} required /></Field>
          <Field label="Abbreviation"><Input value={leagueAbbrev} onChange={(event) => setLeagueAbbrev(event.target.value)} required /></Field>
          <Button type="submit">Create League</Button>
        </form>
      </Card>
      <Card>
        <SectionTitle icon={Plus} title="New Hub" />
        <form className="mt-3 grid gap-3" onSubmit={createHub}>
          <Field label="League"><Select value={leagueId} onChange={(event) => setLeagueId(event.target.value)} required><option value="">Select</option>{data.leagues.map((league) => <option key={league.id} value={league.id}>{league.name}</option>)}</Select></Field>
          <Field label="Name"><Input value={hubName} onChange={(event) => setHubName(event.target.value)} required /></Field>
          <Field label="Location"><Input value={hubLocation} onChange={(event) => setHubLocation(event.target.value)} /></Field>
          <Button type="submit">Create Hub</Button>
        </form>
      </Card>
      <Card>
        <SectionTitle icon={Plus} title="New Team" />
        <form className="mt-3 grid gap-3" onSubmit={createTeam}>
          <Field label="Hub"><Select value={hubId} onChange={(event) => setHubId(event.target.value)} required><option value="">Select</option>{data.hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</Select></Field>
          <Field label="Name"><Input value={teamName} onChange={(event) => setTeamName(event.target.value)} required /></Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Age"><Input value={teamAge} onChange={(event) => setTeamAge(event.target.value)} /></Field>
            <Field label="Division"><Input value={teamDivision} onChange={(event) => setTeamDivision(event.target.value)} /></Field>
          </div>
          <Button type="submit">Create Team</Button>
        </form>
      </Card>
    </div>
  );
}

function AnnouncementsSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scope, setScope] = useState<AnnouncementScope>("orgWide");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selectedAnnouncement = selectedId ? data.announcements.find((item) => item.id === selectedId) ?? null : null;

  async function createAnnouncement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = await runAction("adminCreateAnnouncement", { title, body, scope, isPinned: false });
    if (!result.ok) return;
    setTitle("");
    setBody("");
  }

  return (
    <>
      <ManagementLayout
        sidebar={
          <>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
              <StatTile label="Announcements" value={data.announcements.length} icon={Megaphone} />
              <StatTile label="Pinned" value={data.announcements.filter((item) => item.isPinned).length} icon={Pin} tone="amber" />
            </div>
            <Card>
              <SectionTitle icon={Plus} title="New Announcement" />
              <form className="mt-3 grid gap-3" onSubmit={createAnnouncement}>
                <Field label="Title"><Input value={title} onChange={(event) => setTitle(event.target.value)} required /></Field>
                <Field label="Body"><Textarea value={body} onChange={(event) => setBody(event.target.value)} required /></Field>
                <Field label="Scope"><Select value={scope} onChange={(event) => setScope(event.target.value as AnnouncementScope)}><option value="orgWide">Org Wide</option><option value="league">League</option><option value="hub">Hub</option><option value="team">Team</option></Select></Field>
                <Button type="submit">Post Announcement</Button>
              </form>
            </Card>
          </>
        }
      >
        <section className="overflow-hidden rounded-lg border border-line bg-white">
          <PanelHeader
            icon={Megaphone}
            title="Announcements"
            description="Click a row to edit, pin, or delete the announcement."
          />
          <div>
            {data.announcements.map((announcement) => (
              <RowButton
                key={announcement.id}
                selected={selectedAnnouncement?.id === announcement.id}
                onClick={() => setSelectedId(announcement.id)}
                ariaLabel={`Open ${announcement.title}`}
              >
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-bold text-ink">{announcement.title}</span>
                  {announcement.isPinned && <Badge tone="warning">Pinned</Badge>}
                </div>
                <div className="mt-1 truncate text-sm font-semibold text-muted">{announcement.body}</div>
                <div className="mt-2 text-xs font-semibold text-muted">{announcement.scope} · {timeAgo(announcement.createdAt)}</div>
              </RowButton>
            ))}
            {data.announcements.length === 0 && <div className="p-4"><EmptyLine label="No announcements" /></div>}
          </div>
        </section>
      </ManagementLayout>
      <AnnouncementDrawer announcement={selectedAnnouncement} onClose={() => setSelectedId(null)} runAction={runAction} />
    </>
  );
}

function AnnouncementDrawer({
  announcement,
  onClose,
  runAction
}: {
  announcement: Announcement | null;
  onClose: () => void;
  runAction: ActionRunner;
}) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scope, setScope] = useState<AnnouncementScope>("orgWide");
  const [isPinned, setIsPinned] = useState(false);

  useEffect(() => {
    if (!announcement) return;
    setTitle(announcement.title);
    setBody(announcement.body);
    setScope(announcement.scope);
    setIsPinned(announcement.isPinned);
  }, [announcement]);

  async function save() {
    if (!announcement) return;
    await runAction("adminUpdateAnnouncement", {
      announcementId: announcement.id,
      patch: { title, body, scope, isPinned }
    });
  }

  async function remove() {
    if (!announcement) return;
    await runAction("adminDeleteAnnouncement", { announcementId: announcement.id });
    onClose();
  }

  return (
    <SideDrawer
      open={Boolean(announcement)}
      title={announcement?.title ?? "Announcement"}
      description={announcement ? `${announcement.scope} · ${timeAgo(announcement.createdAt)}` : undefined}
      icon={Megaphone}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" onClick={save}><Save className="size-4" aria-hidden />Save</Button>
          <Button variant="danger" onClick={remove}><Trash2 className="size-4" aria-hidden />Delete</Button>
        </>
      }
    >
      {announcement && (
        <>
          <DrawerSection title="Content">
            <Field label="Title"><Input value={title} onChange={(event) => setTitle(event.target.value)} /></Field>
            <Field label="Body"><Textarea value={body} onChange={(event) => setBody(event.target.value)} /></Field>
            <Field label="Scope"><Select value={scope} onChange={(event) => setScope(event.target.value as AnnouncementScope)}><option value="orgWide">Org Wide</option><option value="league">League</option><option value="hub">Hub</option><option value="team">Team</option></Select></Field>
            <label className="flex min-h-11 items-center justify-between gap-3 rounded-md border border-line bg-white px-3 text-sm font-semibold">
              <span className="inline-flex items-center gap-2">{isPinned ? <Pin className="size-4 text-amber" aria-hidden /> : <PinOff className="size-4 text-muted" aria-hidden />}Pinned</span>
              <input type="checkbox" checked={isPinned} onChange={(event) => setIsPinned(event.target.checked)} />
            </label>
          </DrawerSection>
          <DrawerSection title="Author">
            <div className="grid gap-3 sm:grid-cols-2">
              <InfoRow label="Author" value={announcement.authorName} />
              <InfoRow label="Role" value={announcement.authorRole} />
            </div>
          </DrawerSection>
        </>
      )}
    </SideDrawer>
  );
}

function PoliciesSection({ data, runAction, selectedOrgId }: { data: AdminData; runAction: ActionRunner; selectedOrgId?: string }) {
  const [policyName, setPolicyName] = useState("");
  const [policyCategory, setPolicyCategory] = useState("General");
  const [policyFile, setPolicyFile] = useState<File | null>(null);
  const [policyError, setPolicyError] = useState<string | null>(null);
  const [policySubmitting, setPolicySubmitting] = useState(false);
  const [selectedPolicyId, setSelectedPolicyId] = useState<string | null>(null);
  const policyFileInputRef = useRef<HTMLInputElement>(null);
  const policyInputId = "policy-file-upload";
  const selectedPolicy = selectedPolicyId ? data.policies.find((policy) => policy.id === selectedPolicyId) ?? null : null;

  async function createPolicy(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPolicyError(null);

    if (!selectedOrgId) {
      setPolicyError("Select an organization first.");
      return;
    }
    if (!db || !storage) {
      setPolicyError("Firebase Storage is not configured for this environment.");
      return;
    }
    if (!policyFile) {
      setPolicyError("Choose a policy file.");
      return;
    }
    if (!isPolicyFileAllowed(policyFile)) {
      setPolicyError(`Policy files must be ${bytesLabel(POLICY_FILE_MAX_BYTES)} or smaller.`);
      return;
    }

    setPolicySubmitting(true);
    const policyId = doc(collection(db, "organizations", selectedOrgId, "policies")).id;
    const fileRef = storageRef(storage, policyStoragePath(selectedOrgId, policyId, policyFile.name));

    try {
      await uploadBytes(fileRef, policyFile, {
        contentType: policyFile.type || "application/octet-stream"
      });
      const fileUrl = await getDownloadURL(fileRef);
      const result = await runAction("adminCreatePolicy", {
        policyId,
        name: policyName,
        fileUrl,
        fileType: policyFile.type || "application/octet-stream",
        fileSize: policyFile.size,
        category: policyCategory
      });

      if (!result.ok) {
        await deleteObject(fileRef).catch(() => undefined);
        return;
      }

      setPolicyName("");
      setPolicyCategory("General");
      clearPolicyFile();
      event.currentTarget.reset();
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Policy file upload failed.";
      setPolicyError(message);
    } finally {
      setPolicySubmitting(false);
    }
  }

  function selectPolicyFile(file?: File) {
    setPolicyError(null);
    if (!file) return;
    if (!isPolicyFileAllowed(file)) {
      clearPolicyFile();
      setPolicyError(`Policy files must be ${bytesLabel(POLICY_FILE_MAX_BYTES)} or smaller.`);
      return;
    }
    setPolicyFile(file);
    if (!policyName) {
      setPolicyName(file.name.replace(/\.[^.]+$/, ""));
    }
  }

  function clearPolicyFile() {
    setPolicyFile(null);
    if (policyFileInputRef.current) {
      policyFileInputRef.current.value = "";
    }
  }

  function handlePolicyDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    selectPolicyFile(event.dataTransfer.files[0]);
  }

  return (
    <>
      <ManagementLayout
        sidebar={
          <>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
              <StatTile label="Policies" value={data.policies.length} icon={FileText} />
              <StatTile label="Versions" value={data.policies.reduce((sum, policy) => sum + policy.versions.length, 0)} icon={Layers} tone="mint" />
            </div>
            <Card>
              <SectionTitle icon={Plus} title="New Policy" />
              <form className="mt-3 grid gap-3" onSubmit={createPolicy}>
                <Field label="Name"><Input value={policyName} onChange={(event) => setPolicyName(event.target.value)} required /></Field>
                <PolicyFileField
                  inputId={policyInputId}
                  inputRef={policyFileInputRef}
                  file={policyFile}
                  error={policyError}
                  onDrop={handlePolicyDrop}
                  onSelect={selectPolicyFile}
                  onClear={() => {
                    clearPolicyFile();
                    setPolicyError(null);
                  }}
                />
                <Field label="Category"><Input value={policyCategory} onChange={(event) => setPolicyCategory(event.target.value)} required /></Field>
                <Button type="submit" disabled={policySubmitting}>{policySubmitting ? "Uploading..." : "Create Policy"}</Button>
              </form>
            </Card>
          </>
        }
      >
        <section className="overflow-hidden rounded-lg border border-line bg-white">
          <PanelHeader
            icon={FileText}
            title="Policies"
            description="Click a row to review file details, upload a version, or delete."
          />
          <div>
            {data.policies.map((policy) => (
              <RowButton
                key={policy.id}
                selected={selectedPolicy?.id === policy.id}
                onClick={() => setSelectedPolicyId(policy.id)}
                ariaLabel={`Open ${policy.name}`}
              >
                <div className="font-bold text-ink">{policy.name}</div>
                <div className="mt-1 text-sm font-semibold text-muted">{policy.category} · {bytesLabel(policy.fileSize)}</div>
                <div className="mt-2 text-xs font-semibold text-muted">Updated {timeAgo(policy.updatedAt)} · {policy.versions.length} versions</div>
              </RowButton>
            ))}
            {data.policies.length === 0 && <div className="p-4"><EmptyLine label="No policies" /></div>}
          </div>
        </section>
      </ManagementLayout>
      <PolicyDrawer policy={selectedPolicy} selectedOrgId={selectedOrgId} onClose={() => setSelectedPolicyId(null)} runAction={runAction} />
    </>
  );
}

function PolicyFileField({
  inputId,
  inputRef,
  file,
  error,
  onDrop,
  onSelect,
  onClear
}: {
  inputId: string;
  inputRef: React.RefObject<HTMLInputElement>;
  file: File | null;
  error: string | null;
  onDrop: (event: DragEvent<HTMLLabelElement>) => void;
  onSelect: (file?: File) => void;
  onClear: () => void;
}) {
  return (
    <div className="grid gap-1 text-sm font-semibold text-ink">
      <span>File</span>
      <label
        htmlFor={inputId}
        role="button"
        tabIndex={0}
        onDragOver={(event) => event.preventDefault()}
        onDrop={onDrop}
        onKeyDown={(event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            document.getElementById(inputId)?.click();
          }
        }}
        className="grid min-h-36 cursor-pointer place-items-center rounded-md border border-dashed border-line bg-white px-4 py-5 text-center transition-colors hover:border-teal hover:bg-shell focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal"
      >
        <input
          id={inputId}
          ref={inputRef}
          className="sr-only"
          type="file"
          onChange={(event) => onSelect(event.target.files?.[0])}
        />
        <span className="grid justify-items-center gap-2">
          <UploadCloud className="size-7 text-teal" aria-hidden />
          <span className="text-sm font-black text-ink">Drop a policy file here or browse</span>
          <span className="text-xs font-semibold text-muted">Up to {bytesLabel(POLICY_FILE_MAX_BYTES)}</span>
        </span>
      </label>
      {file && (
        <div className="flex min-h-11 items-center justify-between gap-3 rounded-md border border-line bg-shell px-3">
          <div className="min-w-0">
            <p className="truncate text-sm font-bold text-ink">{file.name}</p>
            <p className="text-xs font-semibold text-muted">{file.type || "File"} · {bytesLabel(file.size)}</p>
          </div>
          <button
            type="button"
            aria-label="Remove selected policy file"
            className="grid size-9 shrink-0 cursor-pointer place-items-center rounded-md text-muted transition-colors hover:bg-white hover:text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal"
            onClick={onClear}
          >
            <X className="size-4" aria-hidden />
          </button>
        </div>
      )}
      {error && <p className="text-sm font-semibold text-coral">{error}</p>}
    </div>
  );
}

function PolicyDrawer({
  policy,
  selectedOrgId,
  onClose,
  runAction
}: {
  policy: Policy | null;
  selectedOrgId?: string;
  onClose: () => void;
  runAction: ActionRunner;
}) {
  const [versionFile, setVersionFile] = useState<File | null>(null);
  const [versionError, setVersionError] = useState<string | null>(null);
  const [versionSubmitting, setVersionSubmitting] = useState(false);
  const versionInputRef = useRef<HTMLInputElement>(null);
  const inputId = policy ? `policy-version-${policy.id}` : "policy-version-upload";

  useEffect(() => {
    setVersionFile(null);
    setVersionError(null);
    if (versionInputRef.current) {
      versionInputRef.current.value = "";
    }
  }, [policy?.id]);

  function selectVersionFile(file?: File) {
    setVersionError(null);
    if (!file) return;
    if (!isPolicyFileAllowed(file)) {
      setVersionFile(null);
      setVersionError(`Policy files must be ${bytesLabel(POLICY_FILE_MAX_BYTES)} or smaller.`);
      return;
    }
    setVersionFile(file);
  }

  function clearVersionFile() {
    setVersionFile(null);
    if (versionInputRef.current) {
      versionInputRef.current.value = "";
    }
  }

  function handleDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    selectVersionFile(event.dataTransfer.files[0]);
  }

  async function addVersion() {
    if (!policy) return;
    setVersionError(null);
    if (!selectedOrgId) {
      setVersionError("Select an organization first.");
      return;
    }
    if (!db || !storage) {
      setVersionError("Firebase Storage is not configured for this environment.");
      return;
    }
    if (!versionFile) {
      setVersionError("Choose a policy file.");
      return;
    }

    setVersionSubmitting(true);
    const fileRef = storageRef(storage, policyStoragePath(selectedOrgId, policy.id, versionFile.name));
    try {
      await uploadBytes(fileRef, versionFile, {
        contentType: versionFile.type || "application/octet-stream"
      });
      const fileUrl = await getDownloadURL(fileRef);
      const result = await runAction("adminAddPolicyVersion", {
        policyId: policy.id,
        fileUrl,
        fileSize: versionFile.size
      });
      if (!result.ok) {
        await deleteObject(fileRef).catch(() => undefined);
        return;
      }
      clearVersionFile();
    } catch (caught) {
      setVersionError(caught instanceof Error ? caught.message : "Policy version upload failed.");
    } finally {
      setVersionSubmitting(false);
    }
  }

  async function remove() {
    if (!policy) return;
    await runAction("adminDeletePolicy", { policyId: policy.id });
    onClose();
  }

  return (
    <SideDrawer
      open={Boolean(policy)}
      title={policy?.name ?? "Policy"}
      description={policy ? `${policy.category} · ${bytesLabel(policy.fileSize)}` : undefined}
      icon={FileText}
      onClose={onClose}
      footer={policy && (
        <>
          <a
            href={policy.fileUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex min-h-11 items-center justify-center gap-2 rounded-md border border-line bg-white px-3 py-2 text-sm font-semibold text-ink transition-colors hover:bg-shell focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal"
          >
            <ExternalLink className="size-4" aria-hidden />
            Open File
          </a>
          <Button variant="danger" onClick={remove}><Trash2 className="size-4" aria-hidden />Delete</Button>
        </>
      )}
    >
      {policy && (
        <>
          <DrawerSection title="Details">
            <div className="grid gap-3 sm:grid-cols-2">
              <InfoRow label="Category" value={policy.category} />
              <InfoRow label="Size" value={bytesLabel(policy.fileSize)} />
              <InfoRow label="Uploaded By" value={policy.uploadedByName} />
              <InfoRow label="Updated" value={dateLabel(policy.updatedAt)} />
            </div>
          </DrawerSection>
          <DrawerSection title="Upload Version">
            <PolicyFileField
              inputId={inputId}
              inputRef={versionInputRef}
              file={versionFile}
              error={versionError}
              onDrop={handleDrop}
              onSelect={selectVersionFile}
              onClear={() => {
                clearVersionFile();
                setVersionError(null);
              }}
            />
            <Button onClick={addVersion} disabled={versionSubmitting}>{versionSubmitting ? "Uploading..." : "Add Version"}</Button>
          </DrawerSection>
          <DrawerSection title="Versions">
            <div className="grid gap-2">
              {policy.versions.map((version, index) => (
                <div key={`${policy.id}-${index}`} className="rounded-md border border-line bg-white px-3 py-2">
                  <div className="text-sm font-bold text-ink">Version {String(version.version ?? index + 1)}</div>
                  <div className="mt-1 text-xs font-semibold text-muted">{typeof version.fileSize === "number" ? bytesLabel(version.fileSize) : "File"} · {String(version.uploadedAt ?? "Uploaded")}</div>
                </div>
              ))}
              {policy.versions.length === 0 && <EmptyLine label="No previous versions" />}
            </div>
          </DrawerSection>
        </>
      )}
    </SideDrawer>
  );
}

function SectionTitle({ icon: Icon, title }: { icon: React.ComponentType<{ className?: string }>; title: string }) {
  return (
    <div className="flex items-center gap-2">
      <Icon className="size-5 text-teal" aria-hidden />
      <h2 className="text-base font-black text-ink">{title}</h2>
    </div>
  );
}

function HealthGrid({ checks }: { checks: HealthCheck[] }) {
  return (
    <div className="mt-3 grid gap-3 sm:grid-cols-2">
      {checks.map((check) => (
        <div key={check.id} className="rounded-md border border-line bg-white p-3">
          <div className="flex items-center justify-between gap-3">
            <span className="font-bold">{check.label}</span>
            <Badge tone={check.severity === "good" ? "good" : check.severity === "danger" ? "danger" : "warning"}>{check.severity}</Badge>
          </div>
          <p className="mt-2 text-sm font-semibold text-muted">{check.value}</p>
        </div>
      ))}
    </div>
  );
}

function EmptyLine({ label }: { label: string }) {
  return <div className="rounded-md border border-dashed border-line px-3 py-5 text-center text-sm font-semibold text-muted">{label}</div>;
}

function CheckboxGroup({
  label,
  options,
  values,
  setValues
}: {
  label: string;
  options: Array<{ id: string; label: string }>;
  values: string[];
  setValues: (values: string[]) => void;
}) {
  return (
    <fieldset className="rounded-md border border-line p-3">
      <legend className="px-1 text-sm font-bold">{label}</legend>
      <div className="grid max-h-44 gap-2 overflow-auto pt-2">
        {options.map((option) => {
          const checked = values.includes(option.id);
          return (
            <label key={option.id} className="flex min-h-9 items-center gap-2 text-sm font-semibold text-muted">
              <input
                type="checkbox"
                checked={checked}
                onChange={() => setValues(checked ? values.filter((id) => id !== option.id) : [...values, option.id])}
              />
              {option.label}
            </label>
          );
        })}
        {options.length === 0 && <span className="text-sm font-semibold text-muted">None</span>}
      </div>
    </fieldset>
  );
}
