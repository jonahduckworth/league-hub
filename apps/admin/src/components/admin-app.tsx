"use client";

import {
  Activity,
  Bell,
  Building2,
  CalendarDays,
  ClipboardList,
  ExternalLink,
  FileText,
  FolderOpen,
  Inbox,
  Layers,
  LayoutDashboard,
  LogOut,
  Mail,
  MapPin,
  Megaphone,
  Phone,
  Pin,
  PinOff,
  Plus,
  RefreshCw,
  Save,
  Search,
  Shield,
  ShieldAlert,
  ShieldCheck,
  SlidersHorizontal,
  Tags,
  Trash2,
  Trophy,
  UploadCloud,
  UserCheck,
  UserCog,
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
import { Badge, Button, Card, Field, Input, Select, Textarea } from "./ui";

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
    <div className="min-h-screen bg-shell">
      <header className="sticky top-0 z-30 border-b border-line bg-white">
        <div className="flex min-h-16 items-center justify-between gap-4 px-4 md:px-6">
          <div className="flex min-w-0 items-center gap-4">
            <span className="grid size-9 shrink-0 place-items-center rounded-md border border-line bg-white text-ink">
              <ShieldCheck className="size-5" aria-hidden />
            </span>
            <div className="min-w-0">
              <h1 className="truncate text-xl font-black text-ink">{title}</h1>
              <p className="truncate text-xs font-semibold text-muted">{data.selectedOrg?.name ?? "No organization selected"}</p>
            </div>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            {currentUser.role === "platformOwner" && (
              <select
                aria-label="Organization"
                value={selectedOrgId ?? ""}
                onChange={(event) => setSelectedOrgId(event.target.value)}
                className="hidden min-h-11 rounded-md border border-line bg-white px-3 text-sm font-semibold md:block"
              >
                {data.orgs.map((org) => (
                  <option key={org.id} value={org.id}>{org.name}</option>
                ))}
              </select>
            )}
            <Badge tone="info">{roleLabel(currentUser.role)}</Badge>
            <Button variant="secondary" onClick={() => selectedOrgId && reloadStructure(selectedOrgId)} aria-label="Refresh data">
              <RefreshCw className="size-4" aria-hidden />
              <span className="hidden sm:inline">Refresh</span>
            </Button>
            <Button variant="ghost" onClick={() => auth ? signOut(auth) : setCurrentUser(null)} aria-label="Sign out">
              <LogOut className="size-4" aria-hidden />
            </Button>
          </div>
        </div>
        <nav className="flex gap-2 overflow-x-auto border-t border-line px-4 py-2 md:px-6" aria-label="Admin sections">
          {navItems.map((item) => {
            const selected = section === item.id;
            return (
              <button
                key={item.id}
                type="button"
                className={`min-h-10 whitespace-nowrap rounded-md px-3 text-sm font-semibold transition-colors ${
                  selected ? "bg-ink text-white" : "text-muted hover:bg-shell hover:text-ink"
                }`}
                onClick={() => setSection(item.id)}
              >
                {item.label}
              </button>
            );
          })}
        </nav>
      </header>

      <main className="px-4 py-8 md:px-6 md:py-10">
        <div className="mx-auto max-w-[1536px]">
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

type RailItem<T extends string> = {
  id: T;
  label: string;
  count: number;
  icon: React.ComponentType<{ className?: string }>;
};

function DirectoryLayout<T extends string>({
  title,
  description,
  action,
  railItems,
  selectedRailId,
  onSelectRail,
  panelTitle,
  panelDescription,
  searchLabel,
  searchValue,
  onSearchChange,
  children
}: {
  title: string;
  description: string;
  action: React.ReactNode;
  railItems: Array<RailItem<T>>;
  selectedRailId: T;
  onSelectRail: (id: T) => void;
  panelTitle: string;
  panelDescription: string;
  searchLabel: string;
  searchValue: string;
  onSearchChange: (value: string) => void;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-8">
      <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
        <div>
          <h2 className="text-3xl font-black text-ink md:text-4xl">{title}</h2>
          <p className="mt-2 max-w-3xl text-base font-semibold leading-7 text-muted">{description}</p>
        </div>
        <div className="shrink-0">{action}</div>
      </div>
      <div className="grid min-h-[calc(100vh-17rem)] gap-6 xl:grid-cols-[320px_minmax(0,1fr)]">
        <DirectoryRail items={railItems} selectedId={selectedRailId} onSelect={onSelectRail} />
        <section className="min-w-0">
          <div className="mb-5 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div>
              <h3 className="text-2xl font-black text-ink">{panelTitle}</h3>
              <p className="mt-1 text-base font-semibold text-muted">{panelDescription}</p>
            </div>
            <SearchBox label={searchLabel} value={searchValue} onChange={onSearchChange} />
          </div>
          {children}
        </section>
      </div>
    </div>
  );
}

function DirectoryRail<T extends string>({
  items,
  selectedId,
  onSelect
}: {
  items: Array<RailItem<T>>;
  selectedId: T;
  onSelect: (id: T) => void;
}) {
  return (
    <aside className="rounded-lg border border-line bg-white p-3 shadow-sm xl:sticky xl:top-32 xl:min-h-[560px] xl:self-start">
      <div className="grid gap-2">
        {items.map((item) => {
          const Icon = item.icon;
          const selected = item.id === selectedId;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onSelect(item.id)}
              className={`flex min-h-[88px] cursor-pointer items-center gap-4 rounded-lg px-4 text-left transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal ${
                selected ? "bg-ink text-white" : "text-ink hover:bg-shell"
              }`}
            >
              <span className={`grid size-12 shrink-0 place-items-center rounded-md ${selected ? "bg-white/15 text-white" : "bg-shell text-muted"}`}>
                <Icon className="size-5" aria-hidden />
              </span>
              <span className="min-w-0">
                <span className="block truncate text-lg font-black">{item.label}</span>
                <span className={`mt-0.5 block text-sm font-semibold ${selected ? "text-white/75" : "text-muted"}`}>
                  {item.count} {item.count === 1 ? "record" : "records"}
                </span>
              </span>
            </button>
          );
        })}
      </div>
    </aside>
  );
}

function DirectoryTable({
  countLabel,
  headers,
  children
}: {
  countLabel: string;
  headers: string[];
  children: React.ReactNode;
}) {
  return (
    <div className="overflow-hidden rounded-lg border border-line bg-white shadow-sm">
      <div className="border-b border-line px-5 py-4 text-base font-black text-ink">{countLabel}</div>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[920px] border-collapse">
          <thead className="bg-white">
            <tr className="border-b border-line">
              {headers.map((header) => (
                <th key={header} className="px-5 py-3 text-left text-xs font-black uppercase text-muted">{header}</th>
              ))}
            </tr>
          </thead>
          <tbody>{children}</tbody>
        </table>
      </div>
    </div>
  );
}

function SearchBox({
  label,
  value,
  onChange
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="relative block w-full md:w-[420px]">
      <Search className="pointer-events-none absolute left-4 top-1/2 size-5 -translate-y-1/2 text-muted" aria-hidden />
      <Input
        aria-label={label}
        className="min-h-14 rounded-lg pl-12 text-base"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={label}
      />
    </label>
  );
}

function ToolbarActionButton({
  icon: Icon,
  children,
  onClick
}: {
  icon: React.ComponentType<{ className?: string }>;
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex min-h-14 cursor-pointer items-center justify-center gap-2 rounded-lg bg-black px-5 text-base font-black text-white transition-colors hover:bg-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal"
    >
      <Icon className="size-5" aria-hidden />
      {children}
    </button>
  );
}

function ViewButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={(event) => {
        event.stopPropagation();
        onClick();
      }}
      className="inline-flex min-h-11 cursor-pointer items-center justify-center rounded-full border border-line bg-white px-6 text-sm font-black text-ink shadow-sm transition-colors hover:bg-shell focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal"
    >
      View
    </button>
  );
}

function EntityAvatar({
  name,
  imageUrl
}: {
  name: string;
  imageUrl?: string | null;
}) {
  const initials = name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("") || "?";

  return imageUrl ? (
    <span
      aria-hidden
      className="size-16 shrink-0 rounded-full bg-cover bg-center"
      style={{ backgroundImage: `url(${imageUrl})` }}
    />
  ) : (
    <span className="grid size-16 shrink-0 place-items-center rounded-full bg-shell text-lg font-black text-muted">
      {initials}
    </span>
  );
}

function DetailLine({
  icon: Icon,
  children
}: {
  icon: React.ComponentType<{ className?: string }>;
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-w-0 items-center gap-2 text-sm font-semibold text-muted">
      <Icon className="size-4 shrink-0 text-muted" aria-hidden />
      <span className="truncate">{children}</span>
    </div>
  );
}

function tableRowClass(selected?: boolean) {
  return `cursor-pointer border-b border-line transition-colors last:border-b-0 hover:bg-shell focus-visible:outline focus-visible:outline-2 focus-visible:outline-teal ${
    selected ? "bg-shell" : "bg-white"
  }`;
}

function emptyTableRow(label: string, colSpan: number) {
  return (
    <tr>
      <td className="px-5 py-6" colSpan={colSpan}>
        <EmptyLine label={label} />
      </td>
    </tr>
  );
}

function matchesQuery(values: Array<string | null | undefined>, query: string) {
  const normalized = query.trim().toLowerCase();
  if (!normalized) return true;
  return values.some((value) => (value ?? "").toLowerCase().includes(normalized));
}

function scopeLabel(scope: AnnouncementScope) {
  if (scope === "orgWide") return "Org wide";
  return `${scope[0].toUpperCase()}${scope.slice(1)}`;
}

function pluralize(count: number, singular: string, plural = `${singular}s`) {
  return `${count} ${count === 1 ? singular : plural}`;
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

type PeopleView = "all" | "managers" | "staff" | "invites";

function PeopleSection({ data, currentUser, runAction }: { data: AdminData; currentUser: AppUser; runAction: ActionRunner }) {
  const [query, setQuery] = useState("");
  const [view, setView] = useState<PeopleView>("all");
  const [createInviteOpen, setCreateInviteOpen] = useState(false);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [selectedInviteId, setSelectedInviteId] = useState<string | null>(null);
  const pendingInvitations = activePendingInvitations(data);
  const managers = data.users.filter((user) => user.role === "managerAdmin" || user.role === "superAdmin");
  const staff = data.users.filter((user) => user.role === "staff");
  const usersForView =
    view === "managers" ? managers :
    view === "staff" ? staff :
    data.users;
  const filteredUsers = usersForView.filter((user) => matchesQuery([user.displayName, user.email, user.title, user.phone, user.address], query));
  const filteredInvites = pendingInvitations.filter((invite) => matchesQuery([invite.displayName, invite.email, roleLabel(invite.role)], query));
  const selectedUser = selectedUserId ? data.users.find((user) => user.id === selectedUserId) ?? null : null;
  const selectedInvite = selectedInviteId ? pendingInvitations.find((invite) => invite.id === selectedInviteId) ?? null : null;
  const manageable = selectedUser ? canManageUser(currentUser, selectedUser) : false;
  const railItems: Array<RailItem<PeopleView>> = [
    { id: "all", label: "All Members", count: data.users.length, icon: Users },
    { id: "managers", label: "Managers", count: managers.length, icon: UserCog },
    { id: "staff", label: "Staff", count: staff.length, icon: UserCheck },
    { id: "invites", label: "Pending Invites", count: pendingInvitations.length, icon: Inbox }
  ];
  const panelCopy: Record<PeopleView, { title: string; description: string }> = {
    all: { title: "All Members", description: "Everyone with current access to the admin organization." },
    managers: { title: "Managers", description: "Users with elevated league or organization access." },
    staff: { title: "Staff", description: "Staff accounts with standard access." },
    invites: { title: "Pending Invites", description: "Invitations that have not been accepted or expired." }
  };

  return (
    <>
      <DirectoryLayout
        title={`People for ${data.selectedOrg?.name ?? "League Hub"}`}
        description="Manage member roles, pending invites, and the access each person has across hubs and teams."
        action={<ToolbarActionButton icon={UserPlus} onClick={() => setCreateInviteOpen(true)}>Add Member</ToolbarActionButton>}
        railItems={railItems}
        selectedRailId={view}
        onSelectRail={(nextView) => {
          setView(nextView);
          setQuery("");
        }}
        panelTitle={panelCopy[view].title}
        panelDescription={panelCopy[view].description}
        searchLabel={view === "invites" ? "Search invites..." : "Search members..."}
        searchValue={query}
        onSearchChange={setQuery}
      >
        <DirectoryTable
          countLabel={view === "invites" ? pluralize(filteredInvites.length, "invite") : pluralize(filteredUsers.length, "member")}
          headers={view === "invites" ? ["Invite", "Access", "Details", "Action"] : ["Member", "Access", "Details", "Action"]}
        >
          {view === "invites" ? (
            <>
              {filteredInvites.map((invite) => (
                <tr
                  key={invite.id}
                  tabIndex={0}
                  role="button"
                  aria-label={`Open invite for ${invite.email}`}
                  className={tableRowClass(selectedInvite?.id === invite.id)}
                  onClick={() => {
                    setSelectedInviteId(invite.id);
                    setSelectedUserId(null);
                  }}
                  onKeyDown={(event) => {
                    if (event.key === "Enter" || event.key === " ") {
                      event.preventDefault();
                      setSelectedInviteId(invite.id);
                      setSelectedUserId(null);
                    }
                  }}
                >
                  <td className="px-5 py-5">
                    <div className="flex min-w-0 items-center gap-4">
                      <EntityAvatar name={invite.displayName ?? invite.email} />
                      <div className="min-w-0">
                        <div className="truncate text-lg font-black text-ink">{invite.displayName || invite.email}</div>
                        <DetailLine icon={Mail}>{invite.email}</DetailLine>
                      </div>
                    </div>
                  </td>
                  <td className="px-5 py-5"><Badge tone="info">{roleLabel(invite.role)}</Badge></td>
                  <td className="px-5 py-5">
                    <div className="grid gap-2">
                      <DetailLine icon={CalendarDays}>{dateLabel(invite.createdAt)}</DetailLine>
                      <DetailLine icon={Building2}>{pluralize(invite.hubIds.length, "hub")}</DetailLine>
                      <DetailLine icon={Users}>{pluralize(invite.teamIds.length, "team")}</DetailLine>
                    </div>
                  </td>
                  <td className="px-5 py-5 text-right">
                    <ViewButton
                      onClick={() => {
                        setSelectedInviteId(invite.id);
                        setSelectedUserId(null);
                      }}
                    />
                  </td>
                </tr>
              ))}
              {filteredInvites.length === 0 && emptyTableRow("No pending invites match this view", 4)}
            </>
          ) : (
            <>
                {filteredUsers.map((user) => (
                  <tr
                    key={user.id}
                    tabIndex={0}
                    role="button"
                    aria-label={`Open ${user.displayName}`}
                    className={tableRowClass(selectedUser?.id === user.id)}
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
                  >
                    <td className="px-5 py-5">
                      <div className="flex min-w-0 items-center gap-4">
                        <EntityAvatar name={user.displayName} imageUrl={user.avatarUrl} />
                        <div className="min-w-0">
                          <div className="truncate text-lg font-black text-ink">{user.displayName}</div>
                          <DetailLine icon={Mail}>{user.email}</DetailLine>
                          {user.phone && <DetailLine icon={Phone}>{user.phone}</DetailLine>}
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-5">
                      <div className="flex flex-wrap gap-2">
                        <Badge tone={user.role === "staff" ? "neutral" : "info"}>{roleLabel(user.role)}</Badge>
                        {!user.isActive && <Badge tone="danger">Inactive</Badge>}
                      </div>
                    </td>
                    <td className="px-5 py-5">
                      <div className="grid gap-2">
                        <DetailLine icon={Building2}>{pluralize(user.hubIds.length, "hub")}</DetailLine>
                        <DetailLine icon={Users}>{pluralize(user.teamIds.length, "team")}</DetailLine>
                        <DetailLine icon={MapPin}>{user.address || user.title || "No location set"}</DetailLine>
                      </div>
                    </td>
                    <td className="px-5 py-5 text-right">
                      <ViewButton
                        onClick={() => {
                          setSelectedUserId(user.id);
                          setSelectedInviteId(null);
                        }}
                      />
                    </td>
                  </tr>
                ))}
              {filteredUsers.length === 0 && emptyTableRow("No members match this view", 4)}
            </>
          )}
        </DirectoryTable>
      </DirectoryLayout>

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
      <CreateInviteDrawer
        open={createInviteOpen}
        data={data}
        currentUser={currentUser}
        runAction={runAction}
        onClose={() => setCreateInviteOpen(false)}
      />
    </>
  );
}

function CreateInviteDrawer({
  open,
  data,
  currentUser,
  runAction,
  onClose
}: {
  open: boolean;
  data: AdminData;
  currentUser: AppUser;
  runAction: ActionRunner;
  onClose: () => void;
}) {
  const [inviteRole, setInviteRole] = useState<UserRole>("staff");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteName, setInviteName] = useState("");
  const [inviteHubIds, setInviteHubIds] = useState<string[]>([]);
  const [inviteTeamIds, setInviteTeamIds] = useState<string[]>([]);

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
    onClose();
  }

  return (
    <SideDrawer open={open} title="Add Member" description="Create a pending invite with role and scope." icon={UserPlus} onClose={onClose}>
      <form className="grid gap-4" onSubmit={submitInvite}>
        <Field label="Email"><Input type="email" value={inviteEmail} onChange={(event) => setInviteEmail(event.target.value)} required /></Field>
        <Field label="Name"><Input value={inviteName} onChange={(event) => setInviteName(event.target.value)} /></Field>
        <Field label="Role">
          <Select value={inviteRole} onChange={(event) => setInviteRole(event.target.value as UserRole)}>
            {assignableRoles(currentUser).map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
          </Select>
        </Field>
        <CheckboxGroup label="Hubs" options={data.hubs.map((hub) => ({ id: hub.id, label: hub.name }))} values={inviteHubIds} setValues={setInviteHubIds} />
        <CheckboxGroup label="Teams" options={data.teams.filter((team) => inviteHubIds.includes(team.hubId)).map((team) => ({ id: team.id, label: team.name }))} values={inviteTeamIds} setValues={setInviteTeamIds} />
        <Button type="submit"><UserPlus className="size-4" aria-hidden />Create Invite</Button>
      </form>
    </SideDrawer>
  );
}

type StructureSelection =
  | { type: "league"; league: League }
  | { type: "hub"; league: League; hub: Hub }
  | { type: "team"; league: League; hub: Hub; team: Team };

type StructureView = "leagues" | "hubs" | "teams";

function StructureSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [selection, setSelection] = useState<StructureSelection | null>(null);
  const [view, setView] = useState<StructureView>("leagues");
  const [query, setQuery] = useState("");
  const [createOpen, setCreateOpen] = useState(false);
  const filteredLeagues = data.leagues.filter((league) => matchesQuery([league.name, league.abbreviation], query));
  const filteredHubs = data.hubs.filter((hub) => {
    const league = data.leagues.find((item) => item.id === hub.leagueId);
    return matchesQuery([hub.name, hub.location, league?.name], query);
  });
  const filteredTeams = data.teams.filter((team) => {
    const league = data.leagues.find((item) => item.id === team.leagueId);
    const hub = data.hubs.find((item) => item.id === team.hubId);
    return matchesQuery([team.name, team.ageGroup, team.division, league?.name, hub?.name], query);
  });
  const railItems: Array<RailItem<StructureView>> = [
    { id: "leagues", label: "Leagues", count: data.leagues.length, icon: Trophy },
    { id: "hubs", label: "Hubs", count: data.hubs.length, icon: MapPin },
    { id: "teams", label: "Teams", count: data.teams.length, icon: Users }
  ];
  const panelCopy: Record<StructureView, { title: string; description: string; action: string; singular: string }> = {
    leagues: { title: "Leagues", description: "Top-level competition groups in this organization.", action: "Add League", singular: "league" },
    hubs: { title: "Hubs", description: "Regional or operational hubs nested under leagues.", action: "Add Hub", singular: "hub" },
    teams: { title: "Teams", description: "Team records nested under hubs and leagues.", action: "Add Team", singular: "team" }
  };

  return (
    <>
      <DirectoryLayout
        title={`Structure for ${data.selectedOrg?.name ?? "League Hub"}`}
        description="Manage the league, hub, and team hierarchy admins use when assigning access and organizing content."
        action={<ToolbarActionButton icon={Plus} onClick={() => setCreateOpen(true)}>{panelCopy[view].action}</ToolbarActionButton>}
        railItems={railItems}
        selectedRailId={view}
        onSelectRail={(nextView) => {
          setView(nextView);
          setQuery("");
        }}
        panelTitle={panelCopy[view].title}
        panelDescription={panelCopy[view].description}
        searchLabel={`Search ${panelCopy[view].title.toLowerCase()}...`}
        searchValue={query}
        onSearchChange={setQuery}
      >
        <DirectoryTable countLabel={pluralize(view === "leagues" ? filteredLeagues.length : view === "hubs" ? filteredHubs.length : filteredTeams.length, panelCopy[view].singular)} headers={["Name", "Parent", "Details", "Action"]}>
          {view === "leagues" && (
            <>
              {filteredLeagues.map((league) => {
                const hubs = data.hubs.filter((hub) => hub.leagueId === league.id);
                const teams = data.teams.filter((team) => team.leagueId === league.id);
                return (
                  <tr
                    key={league.id}
                    tabIndex={0}
                    role="button"
                    aria-label={`Open ${league.name}`}
                    className={tableRowClass(selection?.type === "league" && selection.league.id === league.id)}
                    onClick={() => setSelection({ type: "league", league })}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        setSelection({ type: "league", league });
                      }
                    }}
                  >
                    <td className="px-5 py-5">
                      <div className="flex min-w-0 items-center gap-4">
                        <EntityAvatar name={league.name} imageUrl={league.logoUrl} />
                        <div className="min-w-0">
                          <div className="truncate text-lg font-black text-ink">{league.name}</div>
                          <Badge tone="info">{league.abbreviation}</Badge>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-5"><DetailLine icon={Shield}>Organization</DetailLine></td>
                    <td className="px-5 py-5">
                      <div className="grid gap-2">
                        <DetailLine icon={MapPin}>{pluralize(hubs.length, "hub")}</DetailLine>
                        <DetailLine icon={Users}>{pluralize(teams.length, "team")}</DetailLine>
                      </div>
                    </td>
                    <td className="px-5 py-5 text-right"><ViewButton onClick={() => setSelection({ type: "league", league })} /></td>
                  </tr>
                );
              })}
              {filteredLeagues.length === 0 && emptyTableRow("No leagues match this view", 4)}
            </>
          )}
          {view === "hubs" && (
            <>
              {filteredHubs.map((hub) => {
                const league = data.leagues.find((item) => item.id === hub.leagueId);
                if (!league) return null;
                const teams = data.teams.filter((team) => team.hubId === hub.id);
                return (
                  <tr
                    key={hub.id}
                    tabIndex={0}
                    role="button"
                    aria-label={`Open ${hub.name}`}
                    className={tableRowClass(selection?.type === "hub" && selection.hub.id === hub.id)}
                    onClick={() => setSelection({ type: "hub", league, hub })}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        setSelection({ type: "hub", league, hub });
                      }
                    }}
                  >
                    <td className="px-5 py-5">
                      <div className="flex min-w-0 items-center gap-4">
                        <EntityAvatar name={hub.name} imageUrl={hub.logoUrl} />
                        <div className="min-w-0">
                          <div className="truncate text-lg font-black text-ink">{hub.name}</div>
                          <DetailLine icon={MapPin}>{hub.location || "No location"}</DetailLine>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-5"><DetailLine icon={Trophy}>{league.name}</DetailLine></td>
                    <td className="px-5 py-5"><DetailLine icon={Users}>{pluralize(teams.length, "team")}</DetailLine></td>
                    <td className="px-5 py-5 text-right"><ViewButton onClick={() => setSelection({ type: "hub", league, hub })} /></td>
                  </tr>
                );
              })}
              {filteredHubs.length === 0 && emptyTableRow("No hubs match this view", 4)}
            </>
          )}
          {view === "teams" && (
            <>
              {filteredTeams.map((team) => {
                const league = data.leagues.find((item) => item.id === team.leagueId);
                const hub = data.hubs.find((item) => item.id === team.hubId);
                if (!league || !hub) return null;
                return (
                  <tr
                    key={team.id}
                    tabIndex={0}
                    role="button"
                    aria-label={`Open ${team.name}`}
                    className={tableRowClass(selection?.type === "team" && selection.team.id === team.id)}
                    onClick={() => setSelection({ type: "team", league, hub, team })}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        setSelection({ type: "team", league, hub, team });
                      }
                    }}
                  >
                    <td className="px-5 py-5">
                      <div className="flex min-w-0 items-center gap-4">
                        <EntityAvatar name={team.name} imageUrl={team.logoUrl} />
                        <div className="min-w-0">
                          <div className="truncate text-lg font-black text-ink">{team.name}</div>
                          <DetailLine icon={Users}>{pluralize(team.memberIds.length, "member")}</DetailLine>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-5">
                      <div className="grid gap-2">
                        <DetailLine icon={Trophy}>{league.name}</DetailLine>
                        <DetailLine icon={MapPin}>{hub.name}</DetailLine>
                      </div>
                    </td>
                    <td className="px-5 py-5">
                      <div className="grid gap-2">
                        <DetailLine icon={Tags}>{team.ageGroup || "No age group"}</DetailLine>
                        <DetailLine icon={SlidersHorizontal}>{team.division || "No division"}</DetailLine>
                      </div>
                    </td>
                    <td className="px-5 py-5 text-right"><ViewButton onClick={() => setSelection({ type: "team", league, hub, team })} /></td>
                  </tr>
                );
              })}
              {filteredTeams.length === 0 && emptyTableRow("No teams match this view", 4)}
            </>
          )}
        </DirectoryTable>
      </DirectoryLayout>
      <StructureEditorDrawer selection={selection} onClose={() => setSelection(null)} runAction={runAction} />
      <StructureCreateDrawer open={createOpen} view={view} data={data} runAction={runAction} onClose={() => setCreateOpen(false)} />
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

function StructureCreateDrawer({
  open,
  view,
  data,
  runAction,
  onClose
}: {
  open: boolean;
  view: StructureView;
  data: AdminData;
  runAction: ActionRunner;
  onClose: () => void;
}) {
  const [leagueName, setLeagueName] = useState("");
  const [leagueAbbrev, setLeagueAbbrev] = useState("");
  const [leagueId, setLeagueId] = useState("");
  const [hubName, setHubName] = useState("");
  const [hubLocation, setHubLocation] = useState("");
  const [hubId, setHubId] = useState("");
  const [teamName, setTeamName] = useState("");
  const [teamAge, setTeamAge] = useState("");
  const [teamDivision, setTeamDivision] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (view === "leagues") {
      const result = await runAction("adminUpsertLeague", { league: { name: leagueName, abbreviation: leagueAbbrev, iconName: "league" } });
      if (!result.ok) return;
      setLeagueName("");
      setLeagueAbbrev("");
      onClose();
      return;
    }
    if (view === "hubs") {
      const result = await runAction("adminUpsertHub", { leagueId, hub: { name: hubName, location: hubLocation, iconName: "hub" } });
      if (!result.ok) return;
      setHubName("");
      setHubLocation("");
      onClose();
      return;
    }
    const hub = data.hubs.find((item) => item.id === hubId);
    if (!hub) return;
    const result = await runAction("adminUpsertTeam", { leagueId: hub.leagueId, hubId, team: { name: teamName, ageGroup: teamAge, division: teamDivision, iconName: "team" } });
    if (!result.ok) return;
    setTeamName("");
    setTeamAge("");
    setTeamDivision("");
    onClose();
  }

  const title = view === "leagues" ? "Add League" : view === "hubs" ? "Add Hub" : "Add Team";

  return (
    <SideDrawer open={open} title={title} description="Create a new structure record." icon={Building2} onClose={onClose}>
      <form className="grid gap-4" onSubmit={submit}>
        {view === "leagues" && (
          <>
            <Field label="Name"><Input value={leagueName} onChange={(event) => setLeagueName(event.target.value)} required /></Field>
            <Field label="Abbreviation"><Input value={leagueAbbrev} onChange={(event) => setLeagueAbbrev(event.target.value)} required /></Field>
          </>
        )}
        {view === "hubs" && (
          <>
            <Field label="League"><Select value={leagueId} onChange={(event) => setLeagueId(event.target.value)} required><option value="">Select</option>{data.leagues.map((league) => <option key={league.id} value={league.id}>{league.name}</option>)}</Select></Field>
            <Field label="Name"><Input value={hubName} onChange={(event) => setHubName(event.target.value)} required /></Field>
            <Field label="Location"><Input value={hubLocation} onChange={(event) => setHubLocation(event.target.value)} /></Field>
          </>
        )}
        {view === "teams" && (
          <>
            <Field label="Hub"><Select value={hubId} onChange={(event) => setHubId(event.target.value)} required><option value="">Select</option>{data.hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</Select></Field>
            <Field label="Name"><Input value={teamName} onChange={(event) => setTeamName(event.target.value)} required /></Field>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Age"><Input value={teamAge} onChange={(event) => setTeamAge(event.target.value)} /></Field>
              <Field label="Division"><Input value={teamDivision} onChange={(event) => setTeamDivision(event.target.value)} /></Field>
            </div>
          </>
        )}
        {(view === "hubs" && data.leagues.length === 0) || (view === "teams" && data.hubs.length === 0) ? (
          <EmptyLine label={view === "hubs" ? "Create a league before adding hubs" : "Create a hub before adding teams"} />
        ) : null}
        <Button type="submit"><Plus className="size-4" aria-hidden />{title}</Button>
      </form>
    </SideDrawer>
  );
}

type AnnouncementView = "all" | "pinned" | "orgWide" | "targeted";

function AnnouncementsSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [query, setQuery] = useState("");
  const [view, setView] = useState<AnnouncementView>("all");
  const [createOpen, setCreateOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selectedAnnouncement = selectedId ? data.announcements.find((item) => item.id === selectedId) ?? null : null;
  const filteredAnnouncements = data.announcements
    .filter((announcement) => {
      if (view === "pinned") return announcement.isPinned;
      if (view === "orgWide") return announcement.scope === "orgWide";
      if (view === "targeted") return announcement.scope !== "orgWide";
      return true;
    })
    .filter((announcement) => matchesQuery([announcement.title, announcement.body, scopeLabel(announcement.scope), announcement.authorName], query));
  const railItems: Array<RailItem<AnnouncementView>> = [
    { id: "all", label: "All Posts", count: data.announcements.length, icon: Megaphone },
    { id: "pinned", label: "Pinned", count: data.announcements.filter((item) => item.isPinned).length, icon: Pin },
    { id: "orgWide", label: "Org Wide", count: data.announcements.filter((item) => item.scope === "orgWide").length, icon: Bell },
    { id: "targeted", label: "Targeted", count: data.announcements.filter((item) => item.scope !== "orgWide").length, icon: SlidersHorizontal }
  ];
  const panelCopy: Record<AnnouncementView, { title: string; description: string }> = {
    all: { title: "All Posts", description: "Every announcement visible in the selected organization." },
    pinned: { title: "Pinned Posts", description: "High-priority announcements that stay surfaced." },
    orgWide: { title: "Org Wide", description: "Announcements sent to the full organization." },
    targeted: { title: "Targeted", description: "Announcements scoped to a league, hub, or team." }
  };

  return (
    <>
      <DirectoryLayout
        title={`Announcements for ${data.selectedOrg?.name ?? "League Hub"}`}
        description="Create, pin, and maintain the posts admins use to communicate updates."
        action={<ToolbarActionButton icon={Megaphone} onClick={() => setCreateOpen(true)}>New Announcement</ToolbarActionButton>}
        railItems={railItems}
        selectedRailId={view}
        onSelectRail={(nextView) => {
          setView(nextView);
          setQuery("");
        }}
        panelTitle={panelCopy[view].title}
        panelDescription={panelCopy[view].description}
        searchLabel="Search announcements..."
        searchValue={query}
        onSearchChange={setQuery}
      >
        <DirectoryTable countLabel={pluralize(filteredAnnouncements.length, "announcement")} headers={["Announcement", "Scope", "Details", "Action"]}>
          {filteredAnnouncements.map((announcement) => (
            <tr
              key={announcement.id}
              tabIndex={0}
              role="button"
              aria-label={`Open ${announcement.title}`}
              className={tableRowClass(selectedAnnouncement?.id === announcement.id)}
              onClick={() => setSelectedId(announcement.id)}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ") {
                  event.preventDefault();
                  setSelectedId(announcement.id);
                }
              }}
            >
              <td className="px-5 py-5">
                <div className="flex min-w-0 items-center gap-4">
                  <EntityAvatar name={announcement.title} />
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="truncate text-lg font-black text-ink">{announcement.title}</span>
                      {announcement.isPinned && <Badge tone="warning">Pinned</Badge>}
                    </div>
                    <p className="mt-1 max-w-xl truncate text-sm font-semibold text-muted">{announcement.body}</p>
                  </div>
                </div>
              </td>
              <td className="px-5 py-5"><Badge tone={announcement.scope === "orgWide" ? "info" : "neutral"}>{scopeLabel(announcement.scope)}</Badge></td>
              <td className="px-5 py-5">
                <div className="grid gap-2">
                  <DetailLine icon={CalendarDays}>{timeAgo(announcement.createdAt)}</DetailLine>
                  <DetailLine icon={Shield}>{announcement.authorName}</DetailLine>
                </div>
              </td>
              <td className="px-5 py-5 text-right"><ViewButton onClick={() => setSelectedId(announcement.id)} /></td>
            </tr>
          ))}
          {filteredAnnouncements.length === 0 && emptyTableRow("No announcements match this view", 4)}
        </DirectoryTable>
      </DirectoryLayout>
      <AnnouncementCreateDrawer open={createOpen} runAction={runAction} onClose={() => setCreateOpen(false)} />
      <AnnouncementDrawer announcement={selectedAnnouncement} onClose={() => setSelectedId(null)} runAction={runAction} />
    </>
  );
}

function AnnouncementCreateDrawer({
  open,
  runAction,
  onClose
}: {
  open: boolean;
  runAction: ActionRunner;
  onClose: () => void;
}) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scope, setScope] = useState<AnnouncementScope>("orgWide");
  const [isPinned, setIsPinned] = useState(false);

  async function createAnnouncement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = await runAction("adminCreateAnnouncement", { title, body, scope, isPinned });
    if (!result.ok) return;
    setTitle("");
    setBody("");
    setScope("orgWide");
    setIsPinned(false);
    onClose();
  }

  return (
    <SideDrawer open={open} title="New Announcement" description="Post an announcement to the selected organization." icon={Megaphone} onClose={onClose}>
      <form className="grid gap-4" onSubmit={createAnnouncement}>
        <Field label="Title"><Input value={title} onChange={(event) => setTitle(event.target.value)} required /></Field>
        <Field label="Body"><Textarea value={body} onChange={(event) => setBody(event.target.value)} required /></Field>
        <Field label="Scope"><Select value={scope} onChange={(event) => setScope(event.target.value as AnnouncementScope)}><option value="orgWide">Org Wide</option><option value="league">League</option><option value="hub">Hub</option><option value="team">Team</option></Select></Field>
        <label className="flex min-h-11 items-center justify-between gap-3 rounded-md border border-line bg-white px-3 text-sm font-semibold">
          <span className="inline-flex items-center gap-2">{isPinned ? <Pin className="size-4 text-amber" aria-hidden /> : <PinOff className="size-4 text-muted" aria-hidden />}Pinned</span>
          <input type="checkbox" checked={isPinned} onChange={(event) => setIsPinned(event.target.checked)} />
        </label>
        <Button type="submit"><Megaphone className="size-4" aria-hidden />Post Announcement</Button>
      </form>
    </SideDrawer>
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

type PolicyView = "all" | "general" | "versioned" | "scoped";

function PoliciesSection({ data, runAction, selectedOrgId }: { data: AdminData; runAction: ActionRunner; selectedOrgId?: string }) {
  const [query, setQuery] = useState("");
  const [view, setView] = useState<PolicyView>("all");
  const [createOpen, setCreateOpen] = useState(false);
  const [selectedPolicyId, setSelectedPolicyId] = useState<string | null>(null);
  const selectedPolicy = selectedPolicyId ? data.policies.find((policy) => policy.id === selectedPolicyId) ?? null : null;
  const filteredPolicies = data.policies
    .filter((policy) => {
      if (view === "general") return policy.category.toLowerCase() === "general";
      if (view === "versioned") return policy.versions.length > 0;
      if (view === "scoped") return Boolean(policy.leagueId || policy.hubId || policy.teamId);
      return true;
    })
    .filter((policy) => matchesQuery([policy.name, policy.category, policy.uploadedByName, policy.fileType], query));
  const railItems: Array<RailItem<PolicyView>> = [
    { id: "all", label: "All Policies", count: data.policies.length, icon: FileText },
    { id: "general", label: "General", count: data.policies.filter((policy) => policy.category.toLowerCase() === "general").length, icon: FolderOpen },
    { id: "versioned", label: "Versioned", count: data.policies.filter((policy) => policy.versions.length > 0).length, icon: Layers },
    { id: "scoped", label: "Scoped", count: data.policies.filter((policy) => Boolean(policy.leagueId || policy.hubId || policy.teamId)).length, icon: SlidersHorizontal }
  ];
  const panelCopy: Record<PolicyView, { title: string; description: string }> = {
    all: { title: "All Policies", description: "Every uploaded policy file in this organization." },
    general: { title: "General", description: "Policies categorized as general operating documents." },
    versioned: { title: "Versioned", description: "Policies with previous uploads tracked in history." },
    scoped: { title: "Scoped", description: "Policies limited to a league, hub, or team." }
  };

  return (
    <>
      <DirectoryLayout
        title={`Policies for ${data.selectedOrg?.name ?? "League Hub"}`}
        description="Upload policies, review file details, and maintain versions from a focused document list."
        action={<ToolbarActionButton icon={UploadCloud} onClick={() => setCreateOpen(true)}>New Policy</ToolbarActionButton>}
        railItems={railItems}
        selectedRailId={view}
        onSelectRail={(nextView) => {
          setView(nextView);
          setQuery("");
        }}
        panelTitle={panelCopy[view].title}
        panelDescription={panelCopy[view].description}
        searchLabel="Search policies..."
        searchValue={query}
        onSearchChange={setQuery}
      >
        <DirectoryTable countLabel={pluralize(filteredPolicies.length, "policy", "policies")} headers={["Policy", "Category", "Details", "Action"]}>
          {filteredPolicies.map((policy) => (
            <tr
              key={policy.id}
              tabIndex={0}
              role="button"
              aria-label={`Open ${policy.name}`}
              className={tableRowClass(selectedPolicy?.id === policy.id)}
              onClick={() => setSelectedPolicyId(policy.id)}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === " ") {
                  event.preventDefault();
                  setSelectedPolicyId(policy.id);
                }
              }}
            >
              <td className="px-5 py-5">
                <div className="flex min-w-0 items-center gap-4">
                  <EntityAvatar name={policy.name} />
                  <div className="min-w-0">
                    <div className="truncate text-lg font-black text-ink">{policy.name}</div>
                    <DetailLine icon={FileText}>{policy.fileType || "File"}</DetailLine>
                  </div>
                </div>
              </td>
              <td className="px-5 py-5"><Badge tone="neutral">{policy.category}</Badge></td>
              <td className="px-5 py-5">
                <div className="grid gap-2">
                  <DetailLine icon={UploadCloud}>{bytesLabel(policy.fileSize)}</DetailLine>
                  <DetailLine icon={Layers}>{pluralize(policy.versions.length, "version")}</DetailLine>
                  <DetailLine icon={CalendarDays}>Updated {timeAgo(policy.updatedAt)}</DetailLine>
                </div>
              </td>
              <td className="px-5 py-5 text-right"><ViewButton onClick={() => setSelectedPolicyId(policy.id)} /></td>
            </tr>
          ))}
          {filteredPolicies.length === 0 && emptyTableRow("No policies match this view", 4)}
        </DirectoryTable>
      </DirectoryLayout>
      <PolicyCreateDrawer open={createOpen} selectedOrgId={selectedOrgId} runAction={runAction} onClose={() => setCreateOpen(false)} />
      <PolicyDrawer policy={selectedPolicy} selectedOrgId={selectedOrgId} onClose={() => setSelectedPolicyId(null)} runAction={runAction} />
    </>
  );
}

function PolicyCreateDrawer({
  open,
  selectedOrgId,
  runAction,
  onClose
}: {
  open: boolean;
  selectedOrgId?: string;
  runAction: ActionRunner;
  onClose: () => void;
}) {
  const [policyName, setPolicyName] = useState("");
  const [policyCategory, setPolicyCategory] = useState("General");
  const [policyFile, setPolicyFile] = useState<File | null>(null);
  const [policyError, setPolicyError] = useState<string | null>(null);
  const [policySubmitting, setPolicySubmitting] = useState(false);
  const policyFileInputRef = useRef<HTMLInputElement>(null);
  const policyInputId = "policy-file-upload-create";

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
      onClose();
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
    <SideDrawer open={open} title="New Policy" description="Upload a policy file and create its first record." icon={FileText} onClose={onClose}>
      <form className="grid gap-4" onSubmit={createPolicy}>
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
    </SideDrawer>
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
