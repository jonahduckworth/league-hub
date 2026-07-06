"use client";

import {
  Activity,
  Bell,
  Building2,
  ClipboardList,
  FileText,
  LayoutDashboard,
  LogOut,
  Megaphone,
  MessageSquare,
  Plus,
  RefreshCw,
  Search,
  ShieldAlert,
  ShieldCheck,
  Trash2,
  Users
} from "lucide-react";
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { FormEvent, useEffect, useMemo, useState } from "react";
import { auth, db, demoMode, hasFirebaseConfig } from "@/lib/firebase";
import { callAdmin, type CallableName } from "@/lib/callables";
import { useAdminData } from "@/lib/firestore";
import { assignableRoles, canAccessAdmin, canManageUser, roleLabel } from "@/lib/admin-access";
import { buildHealthChecks } from "@/lib/health";
import { bytesLabel, dateLabel, timeAgo } from "@/lib/format";
import { demoUser } from "@/lib/demo-data";
import type {
  AdminData,
  AnnouncementScope,
  AppUser,
  ChatRoom,
  HealthCheck,
  Hub,
  League,
  Team,
  UserRole
} from "@/lib/types";
import { Badge, Button, Card, Field, Input, Select, TableWrap, Td, Textarea, Th } from "./ui";

type SectionId = "overview" | "people" | "structure" | "content" | "communications" | "audit" | "platform";

const navItems: Array<{ id: SectionId; label: string; icon: React.ComponentType<{ className?: string }> }> = [
  { id: "overview", label: "Overview", icon: LayoutDashboard },
  { id: "people", label: "People", icon: Users },
  { id: "structure", label: "Structure", icon: Building2 },
  { id: "content", label: "Content", icon: FileText },
  { id: "communications", label: "Comms", icon: MessageSquare },
  { id: "audit", label: "Audit", icon: Activity },
  { id: "platform", label: "Platform", icon: ShieldCheck }
];

type ActionRunner = (name: CallableName, payload?: Record<string, unknown>) => Promise<unknown>;

export function AdminApp() {
  const [currentUser, setCurrentUser] = useState<AppUser | null>(demoMode ? demoUser : null);
  const [authLoading, setAuthLoading] = useState(!demoMode && hasFirebaseConfig());
  const [section, setSection] = useState<SectionId>("overview");
  const [message, setMessage] = useState<string | null>(null);
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
    if (!orgId) throw new Error("Select an organization first.");
    if (demoMode) {
      setMessage(`${name} is disabled in demo mode.`);
      return null;
    }
    const result = await callAdmin(name, { orgId, ...payload });
    if (name.startsWith("adminUpsert") || name.startsWith("adminDelete")) {
      await reloadStructure(orgId);
    }
    setMessage(`${name} completed.`);
    return result;
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
          {error && (
            <div className="mb-4 rounded-md border border-coral/20 bg-coral/10 px-4 py-3 text-sm font-semibold text-coral">
              {error}
            </div>
          )}
          {loading ? <LoadingState /> : renderSection(section, data, currentUser, runAction)}
        </div>
      </main>
    </div>
  );
}

function renderSection(section: SectionId, data: AdminData, currentUser: AppUser, runAction: ActionRunner) {
  switch (section) {
    case "people":
      return <PeopleSection data={data} currentUser={currentUser} runAction={runAction} />;
    case "structure":
      return <StructureSection data={data} runAction={runAction} />;
    case "content":
      return <ContentSection data={data} runAction={runAction} />;
    case "communications":
      return <CommunicationsSection data={data} runAction={runAction} />;
    case "audit":
      return <AuditSection data={data} />;
    case "platform":
      return <PlatformSection data={data} currentUser={currentUser} />;
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
  const metrics = [
    ["Active Users", data.users.filter((user) => user.isActive).length],
    ["Pending Invites", data.invitations.filter((invite) => invite.status === "pending").length],
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

function PeopleSection({ data, currentUser, runAction }: { data: AdminData; currentUser: AppUser; runAction: ActionRunner }) {
  const [query, setQuery] = useState("");
  const [inviteRole, setInviteRole] = useState<UserRole>("staff");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteName, setInviteName] = useState("");
  const [inviteHubIds, setInviteHubIds] = useState<string[]>([]);
  const [inviteTeamIds, setInviteTeamIds] = useState<string[]>([]);

  const filteredUsers = data.users.filter((user) => {
    const haystack = `${user.displayName} ${user.email} ${user.title ?? ""}`.toLowerCase();
    return haystack.includes(query.toLowerCase());
  });

  async function submitInvite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await runAction("adminCreateInvitation", {
      email: inviteEmail,
      displayName: inviteName || undefined,
      role: inviteRole,
      hubIds: inviteHubIds,
      teamIds: inviteTeamIds
    });
    setInviteEmail("");
    setInviteName("");
    setInviteHubIds([]);
    setInviteTeamIds([]);
  }

  return (
    <div className="grid gap-5 xl:grid-cols-[1fr_360px]">
      <div className="grid gap-4">
        <Card>
          <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <SectionTitle icon={Users} title="Users" />
            <label className="relative block md:w-80">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted" aria-hidden />
              <Input aria-label="Search users" className="pl-9" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search users" />
            </label>
          </div>
        </Card>
        <TableWrap>
          <table className="min-w-[820px] w-full border-collapse">
            <thead className="bg-shell">
              <tr>
                <Th>Name</Th>
                <Th>Role</Th>
                <Th>Status</Th>
                <Th>Scope</Th>
                <Th>Actions</Th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((user) => (
                <tr key={user.id} className="border-t border-line">
                  <Td>
                    <div className="font-bold">{user.displayName}</div>
                    <div className="truncate text-xs font-semibold text-muted">{user.email}</div>
                  </Td>
                  <Td><Badge tone={user.role === "staff" ? "neutral" : "info"}>{roleLabel(user.role)}</Badge></Td>
                  <Td><Badge tone={user.isActive ? "good" : "danger"}>{user.isActive ? "Active" : "Inactive"}</Badge></Td>
                  <Td>{user.hubIds.length} hubs · {user.teamIds.length} teams</Td>
                  <Td>
                    <div className="flex flex-wrap gap-2">
                      {canManageUser(currentUser, user) && (
                        <>
                          <RoleAction user={user} currentUser={currentUser} runAction={runAction} />
                          <Button
                            variant={user.isActive ? "danger" : "secondary"}
                            onClick={() => runAction("adminUpdateUserAccess", { targetUserId: user.id, isActive: !user.isActive })}
                          >
                            {user.isActive ? "Deactivate" : "Reactivate"}
                          </Button>
                        </>
                      )}
                    </div>
                  </Td>
                </tr>
              ))}
            </tbody>
          </table>
        </TableWrap>
      </div>
      <div className="grid gap-4 content-start">
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
          <div className="mt-3 grid gap-2">
            {data.invitations.filter((invite) => invite.status === "pending").map((invite) => (
              <div key={invite.id} className="rounded-md border border-line p-3">
                <div className="font-bold">{invite.email}</div>
                <div className="text-xs font-semibold text-muted">{roleLabel(invite.role)} · {dateLabel(invite.createdAt)}</div>
                <Button className="mt-2" variant="secondary" onClick={() => runAction("adminExpireInvitation", { invitationId: invite.id })}>Expire</Button>
              </div>
            ))}
            {data.invitations.filter((invite) => invite.status === "pending").length === 0 && <EmptyLine label="No pending invites" />}
          </div>
        </Card>
      </div>
    </div>
  );
}

function RoleAction({ user, currentUser, runAction }: { user: AppUser; currentUser: AppUser; runAction: ActionRunner }) {
  const roles = assignableRoles(currentUser);
  if (roles.length === 0) return null;
  return (
    <select
      aria-label={`Change role for ${user.displayName}`}
      value={user.role}
      className="min-h-11 rounded-md border border-line bg-white px-2 text-sm font-semibold"
      onChange={(event) => runAction("adminUpdateUserAccess", { targetUserId: user.id, role: event.target.value })}
    >
      {roles.map((role) => <option key={role} value={role}>{roleLabel(role)}</option>)}
    </select>
  );
}

function StructureSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  return (
    <div className="grid gap-5 xl:grid-cols-[1fr_380px]">
      <Card>
        <SectionTitle icon={Building2} title="League Structure" />
        <div className="mt-4 grid gap-3">
          {data.leagues.map((league) => (
            <StructureLeague key={league.id} league={league} hubs={data.hubs.filter((hub) => hub.leagueId === league.id)} teams={data.teams} runAction={runAction} />
          ))}
          {data.leagues.length === 0 && <EmptyLine label="No leagues" />}
        </div>
      </Card>
      <StructureForms data={data} runAction={runAction} />
    </div>
  );
}

function StructureLeague({ league, hubs, teams, runAction }: { league: League; hubs: Hub[]; teams: Team[]; runAction: ActionRunner }) {
  return (
    <div className="rounded-lg border border-line bg-white p-3">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="font-black">{league.name}</div>
          <div className="text-xs font-semibold text-muted">{league.abbreviation} · {hubs.length} hubs</div>
        </div>
        <Button variant="danger" onClick={() => runAction("adminDeleteLeague", { leagueId: league.id })}><Trash2 className="size-4" aria-hidden />Delete</Button>
      </div>
      <div className="mt-3 grid gap-2">
        {hubs.map((hub) => (
          <div key={hub.id} className="rounded-md border border-line bg-shell p-3">
            <div className="flex items-center justify-between gap-3">
              <div className="font-bold">
                {hub.name}
                {hub.location && <span className="ml-2 text-xs text-muted">· {hub.location}</span>}
              </div>
              <Button variant="secondary" onClick={() => runAction("adminDeleteHub", { leagueId: league.id, hubId: hub.id })}>Delete Hub</Button>
            </div>
            <div className="mt-2 flex flex-wrap gap-2">
              {teams.filter((team) => team.hubId === hub.id).map((team) => (
                <span key={team.id} className="inline-flex min-h-8 items-center gap-2 rounded-md border border-line bg-white px-2 text-xs font-semibold">
                  {team.name}
                  <button type="button" aria-label={`Delete ${team.name}`} onClick={() => runAction("adminDeleteTeam", { leagueId: league.id, hubId: hub.id, teamId: team.id })}>
                    <Trash2 className="size-3 text-coral" aria-hidden />
                  </button>
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
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
    await runAction("adminUpsertLeague", { league: { name: leagueName, abbreviation: leagueAbbrev, iconName: "league" } });
    setLeagueName("");
    setLeagueAbbrev("");
  }

  async function createHub(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await runAction("adminUpsertHub", { leagueId, hub: { name: hubName, location: hubLocation, iconName: "hub" } });
    setHubName("");
    setHubLocation("");
  }

  async function createTeam(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const hub = data.hubs.find((item) => item.id === hubId);
    if (!hub) return;
    await runAction("adminUpsertTeam", { leagueId: hub.leagueId, hubId, team: { name: teamName, ageGroup: teamAge, division: teamDivision, iconName: "team" } });
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

function ContentSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scope, setScope] = useState<AnnouncementScope>("orgWide");
  const [policyName, setPolicyName] = useState("");
  const [policyUrl, setPolicyUrl] = useState("");
  const [policyCategory, setPolicyCategory] = useState("General");

  async function createAnnouncement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await runAction("adminCreateAnnouncement", { title, body, scope, isPinned: false });
    setTitle("");
    setBody("");
  }

  async function createPolicy(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await runAction("adminCreatePolicy", {
      name: policyName,
      fileUrl: policyUrl,
      fileType: "application/pdf",
      fileSize: 0,
      category: policyCategory
    });
    setPolicyName("");
    setPolicyUrl("");
  }

  return (
    <div className="grid gap-5 xl:grid-cols-2">
      <Card>
        <SectionTitle icon={Megaphone} title="Announcements" />
        <form className="mt-3 grid gap-3" onSubmit={createAnnouncement}>
          <Field label="Title"><Input value={title} onChange={(event) => setTitle(event.target.value)} required /></Field>
          <Field label="Body"><Textarea value={body} onChange={(event) => setBody(event.target.value)} required /></Field>
          <Field label="Scope"><Select value={scope} onChange={(event) => setScope(event.target.value as AnnouncementScope)}><option value="orgWide">Org Wide</option><option value="league">League</option><option value="hub">Hub</option><option value="team">Team</option></Select></Field>
          <Button type="submit">Post Announcement</Button>
        </form>
        <ListStack items={data.announcements.slice(0, 8).map((item) => ({
          id: item.id,
          title: item.title,
          subtitle: `${item.scope} · ${timeAgo(item.createdAt)}`,
          action: <Button variant="danger" onClick={() => runAction("adminDeleteAnnouncement", { announcementId: item.id })}>Delete</Button>
        }))} />
      </Card>
      <Card>
        <SectionTitle icon={FileText} title="Policies" />
        <form className="mt-3 grid gap-3" onSubmit={createPolicy}>
          <Field label="Name"><Input value={policyName} onChange={(event) => setPolicyName(event.target.value)} required /></Field>
          <Field label="File URL"><Input type="url" value={policyUrl} onChange={(event) => setPolicyUrl(event.target.value)} required /></Field>
          <Field label="Category"><Input value={policyCategory} onChange={(event) => setPolicyCategory(event.target.value)} required /></Field>
          <Button type="submit">Create Policy</Button>
        </form>
        <ListStack items={data.policies.slice(0, 8).map((item) => ({
          id: item.id,
          title: item.name,
          subtitle: `${item.category} · ${bytesLabel(item.fileSize)}`,
          action: <Button variant="danger" onClick={() => runAction("adminDeletePolicy", { policyId: item.id })}>Delete</Button>
        }))} />
      </Card>
    </div>
  );
}

function CommunicationsSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [roomId, setRoomId] = useState("");
  const [messageId, setMessageId] = useState("");

  return (
    <div className="grid gap-5 xl:grid-cols-[1fr_360px]">
      <Card>
        <SectionTitle icon={MessageSquare} title="Chat Rooms" />
        <ListStack items={data.chatRooms.map((room: ChatRoom) => ({
          id: room.id,
          title: room.name,
          subtitle: `${room.type} · ${room.lastMessage ?? "No messages"}`,
          action: <Button variant="secondary" onClick={() => runAction("adminArchiveChatRoom", { roomId: room.id })}>Archive</Button>
        }))} />
      </Card>
      <Card>
        <SectionTitle icon={Trash2} title="Moderation" />
        <form
          className="mt-3 grid gap-3"
          onSubmit={(event) => {
            event.preventDefault();
            runAction("adminDeleteMessage", { roomId, messageId });
          }}
        >
          <Field label="Room ID"><Input value={roomId} onChange={(event) => setRoomId(event.target.value)} required /></Field>
          <Field label="Message ID"><Input value={messageId} onChange={(event) => setMessageId(event.target.value)} required /></Field>
          <Button type="submit" variant="danger">Soft Delete Message</Button>
        </form>
      </Card>
    </div>
  );
}

function AuditSection({ data }: { data: AdminData }) {
  return (
    <div className="grid gap-5 xl:grid-cols-2">
      <Card>
        <SectionTitle icon={Activity} title="Audit Log" />
        <ListStack items={data.auditLogs.map((log) => ({
          id: log.id,
          title: log.action,
          subtitle: `${log.actorName ?? log.actorId} · ${timeAgo(log.createdAt)}`
        }))} />
      </Card>
      <Card>
        <SectionTitle icon={Bell} title="Notification Events" />
        <ListStack items={data.notificationEvents.map((event) => ({
          id: event.id,
          title: event.title,
          subtitle: `${event.successCount}/${event.requestedTokens} sent · ${event.failureCount} failed`
        }))} />
      </Card>
      <Card className="xl:col-span-2">
        <SectionTitle icon={ClipboardList} title="Health Checks" />
        <HealthGrid checks={buildHealthChecks(data)} />
      </Card>
    </div>
  );
}

function PlatformSection({ data, currentUser }: { data: AdminData; currentUser: AppUser }) {
  if (currentUser.role !== "platformOwner") {
    return (
      <Card>
        <SectionTitle icon={ShieldAlert} title="Platform Owner" />
        <EmptyLine label="Platform owner access only" />
      </Card>
    );
  }

  return (
    <Card>
      <SectionTitle icon={ShieldCheck} title="Organizations" />
      <TableWrap>
        <table className="mt-3 min-w-[700px] w-full border-collapse">
          <thead className="bg-shell">
            <tr><Th>Name</Th><Th>Users</Th><Th>Leagues</Th><Th>Owner</Th></tr>
          </thead>
          <tbody>
            {data.orgs.map((org) => (
              <tr key={org.id} className="border-t border-line">
                <Td><div className="font-bold">{org.name}</div><div className="text-xs text-muted">{org.id}</div></Td>
                <Td>{data.users.filter((user) => user.orgId === org.id).length}</Td>
                <Td>{data.leagues.filter((league) => league.orgId === org.id).length}</Td>
                <Td>{org.ownerId ?? "Not set"}</Td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableWrap>
    </Card>
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

function ListStack({ items }: { items: Array<{ id: string; title: string; subtitle: string; action?: React.ReactNode }> }) {
  return (
    <div className="mt-3 grid gap-2">
      {items.map((item) => (
        <div key={item.id} className="flex min-h-14 items-center justify-between gap-3 rounded-md border border-line bg-white px-3 py-2">
          <div className="min-w-0">
            <div className="truncate text-sm font-bold">{item.title}</div>
            <div className="truncate text-xs font-semibold text-muted">{item.subtitle}</div>
          </div>
          {item.action}
        </div>
      ))}
      {items.length === 0 && <EmptyLine label="No records" />}
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
