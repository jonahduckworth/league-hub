"use client";

import {
  Activity,
  Building2,
  CalendarDays,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  ClipboardList,
  Clock3,
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
  MessageSquare,
  Network,
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
  Sparkles,
  Tags,
  Trash2,
  Trophy,
  UploadCloud,
  UserCheck,
  UserCog,
  UserPlus,
  UserRound,
  X,
  Users
} from "lucide-react";
import { onAuthStateChanged, signInWithEmailAndPassword, signOut, type User as FirebaseUser } from "firebase/auth";
import { collection, doc, getDoc } from "firebase/firestore";
import { deleteObject, getDownloadURL, ref as storageRef, uploadBytes } from "firebase/storage";
import { DragEvent, FormEvent, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { auth, db, demoMode, firebaseProjectId, hasFirebaseConfig, storage } from "@/lib/firebase";
import { formatAdminActionError } from "@/lib/action-errors";
import { callAdmin, type CallableName } from "@/lib/callables";
import { useAdminData } from "@/lib/firestore";
import { assignableRoles, canAccessAdmin, canManageUser, roleLabel } from "@/lib/admin-access";
import { buildHealthChecks } from "@/lib/health";
import { activePendingInvitations } from "@/lib/invitations";
import { bytesLabel, dateLabel, dateTimeLabel, timeAgo, toDate } from "@/lib/format";
import { isPolicyFileAllowed, policyStoragePath, POLICY_CATEGORIES, POLICY_FILE_MAX_BYTES } from "@/lib/policy-upload";
import { buildStructureRelationshipIndex, type StructureRelationshipIndex } from "@/lib/structure-relationships";
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
  ScheduleEvent,
  ScheduleIntegration,
  Team,
  UserRole
} from "@/lib/types";
import { Badge, Button, Card, Field, Input, Select, Textarea } from "./ui";

type SectionId = "overview" | "people" | "structure" | "schedule" | "announcements" | "policies";

const navItems: Array<{
  id: SectionId;
  label: string;
  mobileLabel: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
}> = [
  { id: "overview", label: "Overview", mobileLabel: "Home", description: "Operations at a glance", icon: LayoutDashboard },
  { id: "people", label: "People", mobileLabel: "People", description: "Members and access", icon: Users },
  { id: "structure", label: "Structure", mobileLabel: "Structure", description: "Leagues, hubs, and teams", icon: Building2 },
  { id: "schedule", label: "Schedule", mobileLabel: "Games", description: "RAMP games and sync health", icon: CalendarDays },
  { id: "announcements", label: "Announcements", mobileLabel: "News", description: "League communications", icon: Megaphone },
  { id: "policies", label: "Policies", mobileLabel: "Policies", description: "Documents and versions", icon: FileText }
];

const mobileNavItems = navItems.filter((item) => item.id !== "overview");

type ActionResult<T = unknown> =
  | { ok: true; data: T }
  | { ok: false; error: string };

type ActionRunner = (name: CallableName, payload?: Record<string, unknown>) => Promise<ActionResult>;

async function fetchAdminProfile(firebaseUser: FirebaseUser): Promise<ActionResult<AppUser>> {
  if (!db) {
    return { ok: false, error: "Firestore is not configured for the admin app." };
  }
  try {
    const userSnap = await getDoc(doc(db, "users", firebaseUser.uid));
    if (!userSnap.exists()) {
      const account = firebaseUser.email ?? firebaseUser.uid;
      return {
        ok: false,
        error: `Signed in to ${firebaseProjectId} as ${account}, but no League Hub admin profile exists for that Firebase account.`
      };
    }
    return { ok: true, data: { id: userSnap.id, ...userSnap.data() } as AppUser };
  } catch (caught) {
    const message = caught instanceof Error ? caught.message : "Unable to load your League Hub admin profile.";
    return {
      ok: false,
      error: `Signed in to ${firebaseProjectId}, but the admin profile could not be loaded: ${message}`
    };
  }
}

export function AdminApp() {
  const [currentUser, setCurrentUser] = useState<AppUser | null>(demoMode ? demoUser : null);
  const [authError, setAuthError] = useState<string | null>(null);
  const [section, setSection] = useState<SectionId>("overview");
  const [message, setMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const { data, loading, error, selectedOrgId, setSelectedOrgId, reloadStructure, isActiveDataScope } = useAdminData(currentUser);

  const loadSignedInUser = useCallback(async (firebaseUser: FirebaseUser): Promise<ActionResult<AppUser>> => {
    const result = await fetchAdminProfile(firebaseUser);
    if (result.ok) {
      setCurrentUser(result.data);
      setAuthError(null);
    } else {
      setCurrentUser(null);
      setAuthError(result.error);
    }
    return result;
  }, []);

  useEffect(() => {
    if (demoMode || !auth || !db) return undefined;
    let mounted = true;
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (!firebaseUser) {
        if (mounted) {
          setCurrentUser(null);
          setAuthError(null);
        }
        return;
      }
      const result = await fetchAdminProfile(firebaseUser);
      if (!mounted) return;
      if (result.ok) {
        setCurrentUser(result.data);
        setAuthError(null);
      } else {
        setCurrentUser(null);
        setAuthError(result.error);
      }
    });
    return () => {
      mounted = false;
      unsubscribe();
    };
  }, []);

  useEffect(() => {
    const syncSectionFromUrl = () => {
      const requested = window.location.hash.replace("#", "") as SectionId;
      setSection(navItems.some((item) => item.id === requested) ? requested : "overview");
    };

    syncSectionFromUrl();
    window.addEventListener("hashchange", syncSectionFromUrl);
    window.addEventListener("popstate", syncSectionFromUrl);
    return () => {
      window.removeEventListener("hashchange", syncSectionFromUrl);
      window.removeEventListener("popstate", syncSectionFromUrl);
    };
  }, []);

  useEffect(() => {
    setMessage(null);
    setActionError(null);
  }, [selectedOrgId]);

  const navigateToSection = useCallback((nextSection: SectionId) => {
    if (nextSection === "overview") {
      window.history.pushState(null, "", `${window.location.pathname}${window.location.search}`);
      setSection("overview");
      return;
    }
    window.location.hash = nextSection;
  }, []);

  const runAction = useCallback<ActionRunner>(async (name, payload = {}) => {
    const orgId = selectedOrgId;
    if (!orgId) {
      const missingOrg = "Select an organization first.";
      setActionError(missingOrg);
      return { ok: false, error: missingOrg };
    }
    if (demoMode) {
      setMessage(`${adminActionLabel(name)} is disabled in demo mode.`);
      return { ok: false, error: "Demo mode" };
    }
    setActionError(null);
    setMessage(null);
    try {
      const result = await callAdmin(name, { orgId, ...payload });
      if (!isActiveDataScope(orgId)) return { ok: true, data: result };
      if (name.startsWith("adminUpsert") || name.startsWith("adminDelete")) {
        await reloadStructure(orgId);
      }
      if (!isActiveDataScope(orgId)) return { ok: true, data: result };
      setMessage(`${adminActionLabel(name)} completed.`);
      return { ok: true, data: result };
    } catch (caught) {
      const errorMessage = formatAdminActionError(caught);
      if (isActiveDataScope(orgId)) setActionError(errorMessage);
      return { ok: false, error: errorMessage };
    }
  }, [isActiveDataScope, reloadStructure, selectedOrgId]);

  if (!demoMode && !hasFirebaseConfig()) {
    return <ConfigMissing />;
  }

  if (!currentUser) {
    return (
      <LoginPanel
        authError={authError}
        onClearAuthError={() => setAuthError(null)}
        onSignedIn={loadSignedInUser}
      />
    );
  }

  if (!canAccessAdmin(currentUser)) {
    return <BlockedPanel user={currentUser} />;
  }

  const activeNavItem = navItems.find((item) => item.id === section) ?? navItems[0];
  const organizationLabel = data.selectedOrg?.name ?? "No organization selected";

  return (
    <div className="min-h-screen bg-shell">
      <aside className="fixed inset-y-0 left-0 z-40 hidden w-72 flex-col overflow-hidden bg-navy text-white lg:flex">
        <div className="border-b border-white/10 px-6 py-6">
          <div className="flex items-center gap-3">
            <span className="grid size-11 place-items-center rounded-2xl bg-teal text-white shadow-[0_14px_30px_-14px_rgba(45,212,191,0.65)]">
              <ShieldCheck className="size-5" aria-hidden />
            </span>
            <div>
              <div className="text-base font-extrabold tracking-[-0.02em]">League Hub</div>
              <div className="text-xs font-semibold text-white/55">Admin workspace</div>
            </div>
          </div>
          <div className="mt-6 rounded-2xl border border-white/10 bg-white/[0.06] p-4">
            <p className="text-[10px] font-extrabold uppercase tracking-[0.16em] text-white/60">Current organization</p>
            <p className="mt-2 truncate text-sm font-bold text-white">{organizationLabel}</p>
            <div className="mt-3">
              {demoMode ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-amber/20 px-2.5 py-1 text-[11px] font-bold text-[#fde68a]">
                  <Sparkles className="size-3" aria-hidden /> Demo workspace
                </span>
              ) : (
                <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-white/65">
                  <span className="size-1.5 rounded-full bg-[#34d399]" /> Production workspace
                </span>
              )}
            </div>
          </div>
        </div>

        <nav className="thin-scrollbar flex-1 overflow-y-auto px-4 py-5" aria-label="Admin sections">
          <p className="px-3 text-[10px] font-extrabold uppercase tracking-[0.16em] text-white/60">Workspace</p>
          <div className="mt-3 grid gap-1.5">
          {navItems.map((item) => {
            const Icon = item.icon;
            const selected = section === item.id;
            return (
              <button
                key={item.id}
                type="button"
                aria-label={item.label}
                aria-current={selected ? "page" : undefined}
                className={`group flex min-h-[58px] items-center gap-3 rounded-2xl px-3.5 text-left transition-[background-color,color,transform] duration-200 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#5eead4] ${
                  selected ? "bg-white text-navy shadow-lift" : "text-white/65 hover:bg-white/[0.07] hover:text-white"
                }`}
                onClick={() => navigateToSection(item.id)}
              >
                <span className={`grid size-9 shrink-0 place-items-center rounded-xl ${selected ? "bg-teal/10 text-teal" : "bg-white/[0.07] text-white/60 group-hover:text-white"}`}>
                  <Icon className="size-[18px]" aria-hidden />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-bold">{item.label}</span>
                  <span className={`mt-0.5 block truncate text-[11px] font-medium ${selected ? "text-muted" : "text-white/60"}`}>{item.description}</span>
                </span>
                {selected && <ChevronRight className="size-4 text-teal" aria-hidden />}
              </button>
            );
          })}
          </div>
        </nav>

        <div className="border-t border-white/10 p-4">
          <div className="flex items-center gap-3 rounded-2xl bg-white/[0.05] p-3">
            <EntityAvatar name={currentUser.displayName} imageUrl={currentUser.avatarUrl} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold text-white">{currentUser.displayName}</p>
              <p className="truncate text-xs font-medium text-white/60">{roleLabel(currentUser.role)}</p>
            </div>
            <button
              type="button"
              aria-label="Sign out"
              onClick={() => auth ? signOut(auth) : setCurrentUser(null)}
              className="grid size-10 shrink-0 place-items-center rounded-xl text-white/65 transition-colors hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#5eead4]"
            >
              <LogOut className="size-4" aria-hidden />
            </button>
          </div>
        </div>
      </aside>

      <div className="min-w-0 lg:pl-72">
        <header data-admin-shell-header className="sticky top-0 z-30 border-b border-line/80 bg-white/90 backdrop-blur-xl">
          <div className="flex min-h-[72px] items-center justify-between gap-3 px-4 sm:px-6 lg:px-8">
            <div className="flex min-w-0 items-center gap-3">
              <button
                type="button"
                aria-label="Overview"
                onClick={() => navigateToSection("overview")}
                className="grid size-11 shrink-0 cursor-pointer place-items-center rounded-xl bg-navy text-white transition-colors hover:bg-[#243449] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/20 lg:hidden"
              >
                <ShieldCheck className="size-5" aria-hidden />
              </button>
              <div className="min-w-0">
                <h1 className="truncate text-lg font-extrabold tracking-[-0.02em] text-ink sm:text-xl">{activeNavItem.label}</h1>
                <p className="truncate text-xs font-semibold text-muted">{organizationLabel}</p>
              </div>
            </div>
            <div className="flex shrink-0 items-center gap-2">
              {currentUser.role === "platformOwner" && (
                <select
                  aria-label="Organization"
                  value={selectedOrgId ?? ""}
                  onChange={(event) => setSelectedOrgId(event.target.value)}
                  className="hidden min-h-11 max-w-[260px] rounded-xl border border-line bg-white px-3 text-sm font-bold text-ink shadow-sm outline-none hover:border-[#b8c4d2] focus:border-teal focus:ring-4 focus:ring-teal/10 sm:block"
                >
                  {data.orgs.map((org) => (
                    <option key={org.id} value={org.id}>{org.name}</option>
                  ))}
                </select>
              )}
              <Button variant="secondary" className="size-11 px-0 sm:w-auto sm:px-4" onClick={() => selectedOrgId && reloadStructure(selectedOrgId)} aria-label="Refresh data">
                <RefreshCw className="size-4" aria-hidden />
                <span className="hidden sm:inline">Refresh</span>
              </Button>
              <Button variant="ghost" className="size-11 px-0 lg:hidden" onClick={() => auth ? signOut(auth) : setCurrentUser(null)} aria-label="Sign out">
                <LogOut className="size-4" aria-hidden />
              </Button>
            </div>
          </div>
          {currentUser.role === "platformOwner" && (
            <div className="border-t border-line/70 px-4 py-2.5 sm:hidden">
              <label className="grid grid-cols-[auto_minmax(0,1fr)] items-center gap-3 text-xs font-bold text-muted">
                <span>Organization</span>
                <select
                  aria-label="Organization"
                  value={selectedOrgId ?? ""}
                  onChange={(event) => setSelectedOrgId(event.target.value)}
                  className="min-h-10 w-full rounded-xl border border-line bg-white px-3 text-sm font-bold text-ink outline-none focus:border-teal focus:ring-4 focus:ring-teal/10"
                >
                  {data.orgs.map((org) => (
                    <option key={org.id} value={org.id}>{org.name}</option>
                  ))}
                </select>
              </label>
            </div>
          )}
        </header>

        <main className="px-4 pb-28 pt-6 sm:px-6 sm:pt-8 lg:px-8 lg:pb-12">
          <div className="mx-auto max-w-[1440px]">
            <div className="grid gap-3">
              {message && <StatusNotice tone="success" message={message} />}
              {actionError && <StatusNotice tone="error" message={actionError} />}
              {error && <StatusNotice tone="error" message={error} />}
            </div>
            <div key={`${selectedOrgId ?? "none"}:${section}`} className={`${message || actionError || error ? "mt-5" : ""} page-enter`}>
              {loading ? <LoadingState /> : renderSection(section, data, currentUser, runAction, selectedOrgId)}
            </div>
          </div>
        </main>

        <nav
          className="fixed inset-x-3 bottom-3 z-40 grid grid-cols-5 rounded-[22px] border border-white/10 bg-navy/95 p-1.5 pb-[calc(0.375rem+env(safe-area-inset-bottom))] shadow-lift backdrop-blur-xl lg:hidden"
          aria-label="Admin sections"
        >
          {mobileNavItems.map((item) => {
            const Icon = item.icon;
            const selected = section === item.id;
            return (
              <button
                key={item.id}
                type="button"
                aria-label={item.label}
                aria-current={selected ? "page" : undefined}
                onClick={() => navigateToSection(item.id)}
                className={`flex min-h-[54px] min-w-0 flex-col items-center justify-center gap-1 rounded-2xl px-1 text-[10px] font-bold transition-colors focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#5eead4] ${selected ? "bg-white text-navy" : "text-white/70 hover:text-white"}`}
              >
                <Icon className={`size-[18px] ${selected ? "text-teal" : ""}`} aria-hidden />
                <span className="max-w-full truncate">{item.mobileLabel}</span>
              </button>
            );
          })}
        </nav>
      </div>
    </div>
  );
}

function renderSection(section: SectionId, data: AdminData, currentUser: AppUser, runAction: ActionRunner, selectedOrgId?: string) {
  switch (section) {
    case "people":
      return <PeopleSection data={data} currentUser={currentUser} runAction={runAction} />;
    case "structure":
      return <StructureSection data={data} currentUser={currentUser} runAction={runAction} />;
    case "schedule":
      return <ScheduleSection data={data} currentUser={currentUser} runAction={runAction} />;
    case "announcements":
      return <AnnouncementsSection data={data} runAction={runAction} />;
    case "policies":
      return <PoliciesSection data={data} runAction={runAction} selectedOrgId={selectedOrgId} />;
    default:
      return <OverviewSection data={data} />;
  }
}

function LoginPanel({
  authError,
  onClearAuthError,
  onSignedIn
}: {
  authError?: string | null;
  onClearAuthError: () => void;
  onSignedIn: (firebaseUser: FirebaseUser) => Promise<ActionResult<AppUser>>;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    onClearAuthError();
    setError(null);
    if (!auth) {
      setError("Firebase auth is not configured.");
      return;
    }
    setSubmitting(true);
    try {
      const credential = await signInWithEmailAndPassword(auth, email, password);
      const result = await onSignedIn(credential.user);
      if (!result.ok) {
        setError(result.error);
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Sign in failed.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="relative min-h-screen overflow-hidden bg-navy px-4 py-5 sm:px-6 sm:py-8">
      <div className="pointer-events-none absolute -left-32 top-1/3 size-80 rounded-full bg-sky/20 blur-3xl" />
      <div className="pointer-events-none absolute -right-24 -top-20 size-96 rounded-full bg-teal/25 blur-3xl" />
      <div className="relative mx-auto grid min-h-[calc(100vh-2.5rem)] max-w-6xl overflow-hidden rounded-[28px] border border-white/10 bg-white shadow-lift sm:min-h-[calc(100vh-4rem)] lg:grid-cols-[1.08fr_0.92fr]">
        <section className="hidden flex-col justify-between bg-hero-glow p-12 text-white lg:flex">
          <div className="flex items-center gap-3">
            <span className="grid size-12 place-items-center rounded-2xl bg-white/10 ring-1 ring-white/15 backdrop-blur-sm">
              <ShieldCheck className="size-6" aria-hidden />
            </span>
            <div>
              <p className="text-lg font-extrabold tracking-[-0.02em]">League Hub</p>
              <p className="text-xs font-semibold text-white/55">Admin operations</p>
            </div>
          </div>
          <div className="max-w-lg">
            <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.07] px-3 py-1.5 text-xs font-bold text-white/75">
              <Sparkles className="size-3.5 text-[#5eead4]" aria-hidden /> One place to run the league
            </span>
            <h2 className="mt-6 text-5xl font-extrabold leading-[1.08] tracking-[-0.045em]">
              Clear operations.<br />Better game days.
            </h2>
            <p className="mt-5 max-w-md text-base font-medium leading-7 text-white/65">
              Manage people, league structure, announcements, and policies from a focused operations workspace.
            </p>
            <div className="mt-8 grid gap-3">
              {["Role-aware member access", "League and team structure", "Communications and policy control"].map((feature) => (
                <div key={feature} className="flex items-center gap-3 text-sm font-semibold text-white/80">
                  <span className="grid size-7 place-items-center rounded-full bg-[#2dd4bf]/15 text-[#5eead4]">
                    <CheckCircle2 className="size-4" aria-hidden />
                  </span>
                  {feature}
                </div>
              ))}
            </div>
          </div>
          <p className="text-xs font-semibold text-white/55">Secure access for authorized League Hub administrators.</p>
        </section>

        <section className="flex items-center px-5 py-8 sm:px-10 lg:px-14">
          <form className="mx-auto w-full max-w-md" onSubmit={submit}>
            <div className="mb-9">
              <div className="mb-8 flex items-center gap-3 lg:hidden">
                <span className="grid size-11 place-items-center rounded-2xl bg-navy text-white">
                  <ShieldCheck className="size-5" aria-hidden />
                </span>
                <div>
                  <p className="font-extrabold text-ink">League Hub</p>
                  <p className="text-xs font-semibold text-muted">Admin operations</p>
                </div>
              </div>
              <p className="text-xs font-extrabold uppercase tracking-[0.16em] text-teal">Administrator access</p>
              <h1 className="mt-3 text-3xl font-extrabold tracking-[-0.035em] text-ink sm:text-4xl">Welcome back</h1>
              <p className="mt-3 text-sm font-medium leading-6 text-muted">Sign in with your League Hub administrator account.</p>
            </div>
            <div className="grid gap-5">
              <Field label="Email address">
                <Input
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  autoComplete="email"
                  placeholder="you@league.ca"
                  required
                />
              </Field>
              <Field label="Password">
                <Input
                  type="password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  autoComplete="current-password"
                  placeholder="Enter your password"
                  required
                />
              </Field>
              {(error ?? authError) && (
                <div role="alert" className="rounded-xl border border-coral/20 bg-coral/10 px-3.5 py-3 text-sm font-semibold leading-5 text-coral">
                  {error ?? authError}
                </div>
              )}
              <Button className="mt-1 w-full" type="submit" disabled={submitting}>
                {submitting ? <><RefreshCw className="size-4 animate-spin" aria-hidden />Signing in...</> : <>Sign in<ChevronRight className="size-4" aria-hidden /></>}
              </Button>
            </div>
            <div className="mt-8 flex items-center gap-2 border-t border-line pt-5 text-xs font-semibold text-muted">
              <ShieldCheck className="size-4 text-teal" aria-hidden /> Protected by Firebase Authentication
            </div>
          </form>
        </section>
      </div>
    </main>
  );
}

function ConfigMissing() {
  return (
    <SystemPanel
      title="Firebase web config required"
      description="Add the values from apps/admin/.env.example before running the production admin app."
    />
  );
}

function BlockedPanel({ user }: { user: AppUser }) {
  return (
    <SystemPanel
      title="Admin access unavailable"
      description={`${user.email} is signed in as ${roleLabel(user.role)}. Ask a platform owner to update this account's access.`}
    />
  );
}

function SystemPanel({ title, description }: { title: string; description: string }) {
  return (
    <main className="relative grid min-h-screen place-items-center overflow-hidden bg-navy px-4 py-8">
      <div className="pointer-events-none absolute right-0 top-0 size-96 rounded-full bg-teal/20 blur-3xl" />
      <Card className="relative w-full max-w-lg border-white/10 p-7 shadow-lift sm:p-8">
        <span className="grid size-12 place-items-center rounded-2xl bg-coral/10 text-coral">
          <ShieldAlert className="size-6" aria-hidden />
        </span>
        <h1 className="mt-5 text-2xl font-extrabold tracking-[-0.025em] text-ink">{title}</h1>
        <p className="mt-3 text-sm font-medium leading-6 text-muted">{description}</p>
      </Card>
    </main>
  );
}

function StatusNotice({ tone, message }: { tone: "success" | "error"; message: string }) {
  const Icon = tone === "success" ? CheckCircle2 : ShieldAlert;
  return (
    <div
      role={tone === "error" ? "alert" : "status"}
      className={`flex items-start gap-3 rounded-2xl border px-4 py-3.5 text-sm font-semibold leading-5 shadow-sm ${
        tone === "success" ? "border-teal/20 bg-teal/10 text-teal" : "border-coral/20 bg-coral/10 text-coral"
      }`}
    >
      <Icon className="mt-0.5 size-4 shrink-0" aria-hidden />
      <span>{message}</span>
    </div>
  );
}

function LoadingState() {
  return (
    <div className="grid gap-5" aria-label="Loading admin data">
      <div className="h-48 animate-pulse rounded-[28px] bg-navy/10" />
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => (
          <div key={index} className="h-32 animate-pulse rounded-2xl border border-line bg-white" />
        ))}
      </div>
    </div>
  );
}

function OverviewSection({ data }: { data: AdminData }) {
  const checks = buildHealthChecks(data);
  const pendingInvitations = activePendingInvitations(data);
  const healthyChecks = checks.filter((check) => check.severity === "good").length;
  const attentionChecks = checks.length - healthyChecks;
  const primaryMetrics = [
    { label: "Active members", value: data.users.filter((user) => user.isActive).length, context: "People with current access", icon: Users, accent: "bg-teal/10 text-teal" },
    { label: "Pending invites", value: pendingInvitations.length, context: pendingInvitations.length === 1 ? "Invitation awaiting action" : "Invitations awaiting action", icon: Inbox, accent: "bg-amber/10 text-amber" },
    { label: "Teams", value: data.teams.length, context: `Across ${data.hubs.length} ${data.hubs.length === 1 ? "hub" : "hubs"}`, icon: Trophy, accent: "bg-sky/10 text-sky" },
    { label: "Policies", value: data.policies.length, context: "Published operating documents", icon: FileText, accent: "bg-grape/10 text-grape" }
  ];
  const inventoryMetrics = [
    { label: "Leagues", value: data.leagues.length, icon: Trophy },
    { label: "Hubs", value: data.hubs.length, icon: MapPin },
    { label: "Announcements", value: data.announcements.length, icon: Megaphone },
    { label: "Chat rooms", value: data.chatRooms.length, icon: MessageSquare }
  ];

  return (
    <div className="grid gap-5 sm:gap-6">
      <section className="relative overflow-hidden rounded-[28px] bg-hero-glow p-6 text-white shadow-lift sm:p-8">
        <div className="pointer-events-none absolute -right-10 -top-20 size-72 rounded-full border border-white/10" />
        <div className="pointer-events-none absolute -right-24 -top-6 size-72 rounded-full border border-white/[0.06]" />
        <div className="relative flex flex-col gap-7 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-2xl">
            <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.07] px-3 py-1.5 text-xs font-bold text-white/70">
              <Activity className="size-3.5 text-[#5eead4]" aria-hidden /> Operations overview
            </span>
            <h2 className="mt-5 text-3xl font-extrabold tracking-[-0.04em] sm:text-4xl">
              {data.selectedOrg?.name ?? "League Hub"} control center
            </h2>
            <p className="mt-3 max-w-xl text-sm font-medium leading-6 text-white/60 sm:text-base sm:leading-7">
              Monitor access, team structure, communications, and policy health from one focused workspace.
            </p>
          </div>
          <div className="min-w-[210px] rounded-2xl border border-white/10 bg-white/[0.08] p-4 backdrop-blur-sm">
            <div className="flex items-center justify-between gap-3">
              <span className="text-xs font-bold text-white/55">System readiness</span>
              <span className="text-lg font-extrabold">{healthyChecks}/{checks.length}</span>
            </div>
            <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/10">
              <div className="h-full rounded-full bg-[#2dd4bf]" style={{ width: `${checks.length ? (healthyChecks / checks.length) * 100 : 0}%` }} />
            </div>
            <p className="mt-3 text-xs font-semibold text-white/60">
              {attentionChecks === 0 ? "Everything looks ready." : `${attentionChecks} ${attentionChecks === 1 ? "item needs" : "items need"} attention.`}
            </p>
          </div>
        </div>
      </section>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {primaryMetrics.map((metric) => {
          const Icon = metric.icon;
          return (
            <Card key={metric.label} className="group p-5 transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-0.5 hover:border-[#bdc8d5] hover:shadow-soft">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-sm font-bold text-muted">{metric.label}</p>
                  <p className="mt-2 text-4xl font-extrabold tracking-[-0.04em] text-ink">{metric.value}</p>
                </div>
                <span className={`grid size-11 place-items-center rounded-2xl ${metric.accent}`}>
                  <Icon className="size-5" aria-hidden />
                </span>
              </div>
              <p className="mt-4 text-xs font-semibold text-muted">{metric.context}</p>
            </Card>
          );
        })}
      </div>

      <div className="grid gap-5 xl:grid-cols-[1.05fr_0.95fr]">
        <Card className="p-5 sm:p-6">
          <div className="flex items-start justify-between gap-4">
            <div>
              <SectionTitle icon={ClipboardList} title="Operations health" />
              <p className="mt-2 text-sm font-medium text-muted">Issues that may need an administrator&apos;s attention.</p>
            </div>
            <Badge tone={attentionChecks === 0 ? "good" : "warning"}>{attentionChecks === 0 ? "Ready" : `${attentionChecks} flagged`}</Badge>
          </div>
          <HealthGrid checks={checks} />
        </Card>
        <Card className="p-5 sm:p-6">
          <div className="flex items-start justify-between gap-4">
            <div>
              <SectionTitle icon={Activity} title="Recent activity" />
              <p className="mt-2 text-sm font-medium text-muted">Latest recorded administrator actions.</p>
            </div>
            <Clock3 className="size-5 text-muted" aria-hidden />
          </div>
          <div className="mt-5 grid gap-2">
            {data.auditLogs.slice(0, 6).map((log) => (
              <div key={log.id} className="flex min-h-14 items-center gap-3 rounded-xl border border-line/80 bg-[#fbfcfd] px-3.5 py-2.5">
                <span className="grid size-8 shrink-0 place-items-center rounded-xl bg-teal/10 text-teal">
                  <Activity className="size-4" aria-hidden />
                </span>
                <span className="min-w-0 flex-1 truncate text-sm font-bold text-ink">{adminActionLabel(log.action)}</span>
                <RelativeTime className="whitespace-nowrap text-xs font-semibold text-muted" value={log.createdAt} />
              </div>
            ))}
            {data.auditLogs.length === 0 && <EmptyLine label="No audit entries yet" />}
          </div>
        </Card>
      </div>

      <Card className="p-5 sm:p-6">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-extrabold text-ink">Organization inventory</p>
            <p className="mt-1 text-xs font-semibold text-muted">A quick count of the workspace&apos;s active content.</p>
          </div>
        </div>
        <div className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
          {inventoryMetrics.map((metric) => {
            const Icon = metric.icon;
            return (
              <div key={metric.label} className="flex items-center gap-3 rounded-2xl border border-line/70 bg-[#f8fafc] p-3.5 sm:p-4">
                <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-white text-muted shadow-sm">
                  <Icon className="size-4" aria-hidden />
                </span>
                <div className="min-w-0">
                  <p className="text-xl font-extrabold text-ink">{metric.value}</p>
                  <p className="truncate text-xs font-semibold text-muted">{metric.label}</p>
                </div>
              </div>
            );
          })}
        </div>
      </Card>
    </div>
  );
}

function adminActionLabel(action: string) {
  const words = action
    .replace(/^admin/, "")
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .trim()
    .toLowerCase();
  return words ? `${words[0].toUpperCase()}${words.slice(1)}` : "Admin action";
}

function RelativeTime({ value, className }: { value: unknown; className?: string }) {
  const [label, setLabel] = useState("Recently");

  useEffect(() => {
    const update = () => setLabel(timeAgo(value));
    update();
    const interval = window.setInterval(update, 60000);
    return () => window.clearInterval(interval);
  }, [value]);

  return <span className={className}>{label}</span>;
}

type WorkspaceFilterItem<T extends string> = {
  id: T;
  label: string;
  count: number;
  icon: React.ComponentType<{ className?: string }>;
};

type WorkspaceMetric = {
  label: string;
  value: number | string;
};

function ManagementWorkspace<T extends string>({
  eyebrow,
  title,
  description,
  icon: HeroIcon,
  metrics,
  action,
  filters,
  selectedFilterId,
  onSelectFilter,
  panelTitle,
  panelDescription,
  searchLabel,
  searchValue,
  onSearchChange,
  children
}: {
  eyebrow: string;
  title: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  metrics: WorkspaceMetric[];
  action: React.ReactNode;
  filters: Array<WorkspaceFilterItem<T>>;
  selectedFilterId: T;
  onSelectFilter: (id: T) => void;
  panelTitle: string;
  panelDescription: string;
  searchLabel: string;
  searchValue: string;
  onSearchChange: (value: string) => void;
  children: React.ReactNode;
}) {
  return (
    <div className="grid gap-5">
      <section className="relative overflow-hidden rounded-[24px] bg-navy p-5 text-white shadow-[0_24px_60px_-36px_rgba(16,24,40,0.75)] sm:p-6 lg:p-7">
        <div className="pointer-events-none absolute -right-24 -top-24 size-72 rounded-full bg-teal/20 blur-3xl" aria-hidden />
        <div className="pointer-events-none absolute -bottom-32 left-1/3 size-72 rounded-full bg-sky/15 blur-3xl" aria-hidden />
        <div className="relative grid gap-6">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
            <div className="flex min-w-0 items-start gap-4">
              <span className="grid size-12 shrink-0 place-items-center rounded-2xl bg-white/10 text-[#5eead4] ring-1 ring-white/15 sm:size-14">
                <HeroIcon className="size-5 sm:size-6" aria-hidden />
              </span>
              <div className="min-w-0">
                <p className="text-[10px] font-extrabold uppercase tracking-[0.18em] text-[#8ff3e7]">{eyebrow}</p>
                <h2 className="mt-2 text-2xl font-extrabold tracking-[-0.035em] sm:text-3xl">{title}</h2>
                <p className="mt-2 max-w-3xl text-sm font-medium leading-6 text-white/65 sm:text-base sm:leading-7">{description}</p>
              </div>
            </div>
            <div className="shrink-0 self-stretch sm:self-auto">{action}</div>
          </div>
          <dl className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
            {metrics.map((metric) => (
              <div key={metric.label} className="rounded-2xl border border-white/10 bg-white/[0.07] px-4 py-3 backdrop-blur-sm">
                <dt className="text-[10px] font-extrabold uppercase tracking-[0.13em] text-white/50">{metric.label}</dt>
                <dd className="mt-1 text-xl font-extrabold tracking-[-0.025em] text-white sm:text-2xl">{metric.value}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <section className="min-w-0 rounded-[24px] border border-line/80 bg-white p-4 shadow-card sm:p-5 lg:p-6">
        <div className="grid gap-4 border-b border-line/80 pb-5">
          <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div className="min-w-0">
              <h3 className="text-xl font-extrabold tracking-[-0.025em] text-ink sm:text-2xl">{panelTitle}</h3>
              <p className="mt-1 text-sm font-medium text-muted">{panelDescription}</p>
            </div>
            <SearchBox label={searchLabel} value={searchValue} onChange={onSearchChange} />
          </div>
          <div className="thin-scrollbar -mx-4 overflow-x-auto px-4 sm:-mx-5 sm:px-5 lg:-mx-6 lg:px-6" role="group" aria-label={`${title} filters`}>
            <div className="flex min-w-max gap-2">
              {filters.map((item) => {
          const Icon = item.icon;
                const selected = item.id === selectedFilterId;
          return (
            <button
              key={item.id}
              type="button"
                    aria-pressed={selected}
                    onClick={() => onSelectFilter(item.id)}
                    className={`inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-xl border px-3.5 text-sm font-bold transition-[background-color,border-color,color,box-shadow] duration-200 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 ${
                      selected ? "border-navy bg-navy text-white shadow-soft" : "border-line bg-[#f8fafc] text-ink hover:border-[#b8c4d2] hover:bg-white"
              }`}
            >
                    <Icon className={`size-4 ${selected ? "text-[#5eead4]" : "text-muted"}`} aria-hidden />
                    {item.label}
                    <span className={`rounded-full px-2 py-0.5 text-[11px] font-extrabold ${selected ? "bg-white/10 text-white/75" : "bg-white text-muted ring-1 ring-line"}`}>{item.count}</span>
            </button>
          );
              })}
            </div>
          </div>
        </div>
        <div className="pt-5">{children}</div>
      </section>
    </div>
  );
}

function WorkspaceEmptyState({ icon: Icon, title, description }: { icon: React.ComponentType<{ className?: string }>; title: string; description: string }) {
  return (
    <div className="grid min-h-56 place-items-center rounded-2xl border border-dashed border-line bg-[#f8fafc] px-6 py-10 text-center">
      <div>
        <span className="mx-auto grid size-12 place-items-center rounded-2xl bg-white text-muted shadow-sm ring-1 ring-line">
          <Icon className="size-5" aria-hidden />
        </span>
        <p className="mt-4 text-base font-extrabold text-ink">{title}</p>
        <p className="mx-auto mt-1 max-w-md text-sm font-medium leading-6 text-muted">{description}</p>
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
    <label className="relative block w-full md:w-[360px]">
      <Search className="pointer-events-none absolute left-3.5 top-1/2 size-[18px] -translate-y-1/2 text-muted" aria-hidden />
      <Input
        aria-label={label}
        className="min-h-12 rounded-xl bg-white pl-11"
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
      className="inline-flex min-h-12 w-full cursor-pointer items-center justify-center gap-2 rounded-xl bg-teal px-5 text-sm font-bold text-white shadow-[0_12px_26px_-15px_rgba(15,118,110,0.9)] transition-[background-color,box-shadow,transform] duration-200 hover:bg-[#0b665f] hover:shadow-[0_16px_30px_-16px_rgba(15,118,110,0.95)] active:translate-y-px focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/20 sm:w-auto"
    >
      <Icon className="size-[18px]" aria-hidden />
      {children}
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
      className="size-12 shrink-0 rounded-2xl bg-cover bg-center ring-1 ring-line"
      style={{ backgroundImage: `url(${imageUrl})` }}
    />
  ) : (
    <span className="grid size-12 shrink-0 place-items-center rounded-2xl bg-shell text-sm font-extrabold text-muted ring-1 ring-line/70">
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
    <div className="flex min-w-0 items-center gap-2 text-[13px] font-medium text-muted">
      <Icon className="size-3.5 shrink-0 text-muted" aria-hidden />
      <span className="truncate">{children}</span>
    </div>
  );
}

function matchesQuery(values: Array<string | null | undefined>, query: string) {
  const normalized = query.trim().toLowerCase();
  if (!normalized) return true;
  return values.some((value) => (value ?? "").toLowerCase().includes(normalized));
}

function scopeLabel(scope: AnnouncementScope) {
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
    <div className="rounded-xl border border-line/70 bg-[#f8fafc] px-3.5 py-3">
      <p className="text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">{label}</p>
      <div className="mt-1.5 text-sm font-semibold text-ink">{value || "Not set"}</div>
    </div>
  );
}

function DrawerSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="overflow-hidden rounded-2xl border border-line/80 bg-[#fcfdff] shadow-sm">
      <div className="border-b border-line/70 bg-white px-4 py-3 sm:px-5">
        <h3 className="text-[11px] font-extrabold uppercase tracking-[0.12em] text-muted">{title}</h3>
      </div>
      <div className="grid gap-3.5 p-4 sm:p-5">{children}</div>
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
  description?: React.ReactNode;
  icon: React.ComponentType<{ className?: string }>;
  onClose: () => void;
  children: React.ReactNode;
  footer?: React.ReactNode;
}) {
  const dialogRef = useRef<HTMLElement>(null);
  const onCloseRef = useRef(onClose);
  const [headerOffset, setHeaderOffset] = useState(() => {
    if (typeof document === "undefined") return 0;
    return Math.max(0, Math.ceil(document.querySelector<HTMLElement>("[data-admin-shell-header]")?.getBoundingClientRect().bottom ?? 0));
  });

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (!open) return undefined;
    const syncHeaderOffset = () => {
      const header = document.querySelector<HTMLElement>("[data-admin-shell-header]");
      setHeaderOffset(Math.max(0, Math.ceil(header?.getBoundingClientRect().bottom ?? 0)));
    };
    syncHeaderOffset();
    window.addEventListener("resize", syncHeaderOffset);
    return () => window.removeEventListener("resize", syncHeaderOffset);
  }, [open]);

  useEffect(() => {
    if (!open) return undefined;
    const previousOverflow = document.body.style.overflow;
    const previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const focusableSelector = [
      "button:not([disabled])",
      "a[href]",
      "input:not([disabled])",
      "select:not([disabled])",
      "textarea:not([disabled])",
      '[tabindex]:not([tabindex="-1"])'
    ].join(",");
    const getFocusableElements = () => Array.from(
      dialogRef.current?.querySelectorAll<HTMLElement>(focusableSelector) ?? []
    ).filter((element) => !element.hasAttribute("hidden"));
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onCloseRef.current();
        return;
      }
      if (event.key !== "Tab") return;
      const focusableElements = getFocusableElements();
      if (focusableElements.length === 0) {
        event.preventDefault();
        return;
      }
      const first = focusableElements[0];
      const last = focusableElements[focusableElements.length - 1];
      if (event.shiftKey && (document.activeElement === first || !dialogRef.current?.contains(document.activeElement))) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && (document.activeElement === last || !dialogRef.current?.contains(document.activeElement))) {
        event.preventDefault();
        first.focus();
      }
    };
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", handleKeyDown);
    const focusFrame = window.requestAnimationFrame(() => getFocusableElements()[0]?.focus({ preventScroll: true }));
    return () => {
      window.cancelAnimationFrame(focusFrame);
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
      if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
    };
  }, [open]);

  if (!open || typeof document === "undefined") return null;

  return createPortal(
    <div className="fixed inset-x-0 bottom-0 z-50 flex items-end sm:items-stretch" style={{ top: headerOffset }}>
      <button
        type="button"
        aria-hidden="true"
        tabIndex={-1}
        className="drawer-backdrop absolute inset-0 cursor-default bg-navy/45 backdrop-blur-[2px]"
        onClick={onClose}
      />
      <aside
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="drawer-sheet relative ml-auto flex h-full max-h-full w-full max-w-[680px] flex-col overflow-hidden rounded-t-[28px] border border-line bg-white shadow-2xl sm:rounded-none sm:rounded-l-[28px] sm:border-y-0 sm:border-r-0"
      >
        <div className="shrink-0 border-b border-line/80 bg-white/95 px-5 pb-5 pt-3 backdrop-blur-sm sm:px-6 sm:py-5">
          <div className="mx-auto mb-3 h-1.5 w-10 rounded-full bg-line sm:hidden" aria-hidden />
          <div className="flex items-start justify-between gap-4">
            <div className="flex min-w-0 gap-3">
              <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-teal/10 text-teal ring-1 ring-teal/15 sm:size-12">
                <Icon className="size-5" aria-hidden />
              </span>
              <div className="min-w-0">
                <h2 className="text-lg font-extrabold tracking-[-0.02em] text-ink">{title}</h2>
                {description && <p className="mt-1 text-sm font-medium leading-5 text-muted">{description}</p>}
              </div>
            </div>
            <Button variant="ghost" className="size-11 shrink-0 px-0" aria-label="Close drawer" onClick={onClose}>
              <X className="size-4" aria-hidden />
            </Button>
          </div>
        </div>
        <div data-testid="drawer-scroll-region" className="thin-scrollbar min-h-0 flex-1 overflow-y-auto overscroll-contain bg-[#f8fafc]/60 px-5 py-5 sm:px-6 sm:py-6">
          <div className="grid gap-6">{children}</div>
        </div>
        {footer && (
          <div className="flex shrink-0 flex-col-reverse gap-3 border-t border-line/80 bg-white px-5 pb-[calc(1rem+env(safe-area-inset-bottom))] pt-4 sm:flex-row sm:justify-end sm:px-6 sm:py-4">
            {footer}
          </div>
        )}
      </aside>
    </div>,
    document.body
  );
}

function DrawerEditActions({
  entityKey,
  entityLabel,
  onSave,
  onDelete
}: {
  entityKey: string;
  entityLabel: string;
  onSave: () => Promise<void>;
  onDelete: () => Promise<void>;
}) {
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    setConfirmingDelete(false);
    setSaving(false);
    setDeleting(false);
  }, [entityKey]);

  async function saveChanges() {
    setSaving(true);
    try {
      await onSave();
    } finally {
      setSaving(false);
    }
  }

  async function confirmDelete() {
    setDeleting(true);
    try {
      await onDelete();
    } finally {
      setDeleting(false);
    }
  }

  if (confirmingDelete) {
    return (
      <div className="w-full rounded-2xl border border-coral/25 bg-coral/[0.06] p-3.5 sm:flex sm:items-center sm:justify-between sm:gap-4">
        <div>
          <p className="text-sm font-extrabold text-[#912f2a]">Delete this {entityLabel}?</p>
          <p className="mt-0.5 text-xs font-semibold text-[#a14a45]">This action can’t be undone.</p>
        </div>
        <div className="mt-3 flex gap-2 sm:mt-0 sm:shrink-0">
          <Button variant="secondary" className="flex-1 sm:flex-none" disabled={deleting} onClick={() => setConfirmingDelete(false)}>Cancel</Button>
          <Button variant="danger" className="flex-1 sm:flex-none" disabled={deleting} onClick={confirmDelete}>
            <Trash2 className="size-4" aria-hidden />{deleting ? "Deleting…" : "Confirm delete"}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex w-full flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
      <Button
        variant="secondary"
        className="border-coral/25 text-[#a93630] hover:border-coral/40 hover:bg-coral/[0.05]"
        disabled={saving}
        onClick={() => setConfirmingDelete(true)}
      >
        <Trash2 className="size-4" aria-hidden />Delete {entityLabel}
      </Button>
      <Button disabled={saving} onClick={saveChanges}>
        <Save className="size-4" aria-hidden />{saving ? "Saving…" : "Save changes"}
      </Button>
    </div>
  );
}

type PeopleView = "all" | "managers" | "staff" | "invites";

function ScheduleSection({ data, currentUser, runAction }: { data: AdminData; currentUser: AppUser; runAction: ActionRunner }) {
  const integration = data.selectedOrg?.scheduleIntegration;
  const canManage = currentUser.role === "platformOwner" || currentUser.role === "superAdmin";
  const [view, setView] = useState<"upcoming" | "results">("upcoming");
  const [loadedAt] = useState(() => Date.now());
  const [syncing, setSyncing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [settings, setSettings] = useState<ScheduleIntegration>(() => integration ?? defaultScheduleIntegration());

  useEffect(() => {
    setSettings(integration ?? defaultScheduleIntegration());
  }, [data.selectedOrg?.id, integration]);

  const upcoming = data.scheduleEvents
    .filter((event) => event.status === "scheduled" && (toDate(event.startsAt)?.getTime() ?? 0) > loadedAt)
    .sort((first, second) => (toDate(first.startsAt)?.getTime() ?? 0) - (toDate(second.startsAt)?.getTime() ?? 0));
  const results = data.scheduleEvents
    .filter((event) => event.status === "final")
    .sort((first, second) => (toDate(second.startsAt)?.getTime() ?? 0) - (toDate(first.startsAt)?.getTime() ?? 0));
  const visibleEvents = view === "upcoming" ? upcoming : results;
  const sync = data.scheduleSync;
  const syncTone = sync?.status === "ok"
    ? "good"
    : sync?.status === "warning" || sync?.status === "running"
      ? "warning"
      : sync?.status === "error"
        ? "danger"
        : "neutral";

  async function syncNow() {
    setSyncing(true);
    try {
      await runAction("adminSyncSchedule");
    } finally {
      setSyncing(false);
    }
  }

  async function saveIntegration(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    try {
      await runAction("adminUpdateScheduleIntegration", { integration: settings });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid gap-5">
      <section className="relative overflow-hidden rounded-[24px] bg-navy p-5 text-white shadow-[0_24px_60px_-36px_rgba(16,24,40,0.75)] sm:p-6 lg:p-7">
        <div className="pointer-events-none absolute -right-20 -top-24 size-72 rounded-full bg-teal/20 blur-3xl" aria-hidden />
        <div className="relative grid gap-6">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
            <div className="flex min-w-0 items-start gap-4">
              <span className="grid size-12 shrink-0 place-items-center rounded-2xl bg-white/10 text-[#5eead4] ring-1 ring-white/15 sm:size-14">
                <CalendarDays className="size-6" aria-hidden />
              </span>
              <div>
                <p className="text-[10px] font-extrabold uppercase tracking-[0.18em] text-[#8ff3e7]">Game operations</p>
                <h2 className="mt-2 text-2xl font-extrabold tracking-[-0.035em] sm:text-3xl">RAMP schedule</h2>
                <p className="mt-2 max-w-3xl text-sm font-medium leading-6 text-white/65 sm:text-base">
                  League games are imported into League Hub every six hours. Missing or unexpectedly replaced RAMP records are reconciled safely.
                </p>
              </div>
            </div>
            {canManage && (
              <Button
                type="button"
                variant="secondary"
                className="shrink-0 border-white/15 bg-white/10 text-white hover:bg-white/15"
                disabled={syncing || !integration?.enabled}
                onClick={syncNow}
              >
                <RefreshCw className={`size-4 ${syncing ? "animate-spin" : ""}`} aria-hidden />
                {syncing ? "Syncing…" : "Sync now"}
              </Button>
            )}
          </div>
          <dl className="grid grid-cols-2 gap-2.5 lg:grid-cols-4">
            {[
              { label: "Upcoming", value: upcoming.length },
              { label: "Final results", value: results.length },
              { label: "Team feeds", value: sync?.teamFeedsTotal ?? 0 },
              { label: "Recreated matched", value: sync?.replaced ?? 0 }
            ].map((metric) => (
              <div key={metric.label} className="rounded-2xl border border-white/10 bg-white/[0.07] px-4 py-3">
                <dt className="text-[10px] font-extrabold uppercase tracking-[0.13em] text-white/50">{metric.label}</dt>
                <dd className="mt-1 text-xl font-extrabold tracking-[-0.025em] text-white sm:text-2xl">{metric.value}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1.45fr)_minmax(320px,0.55fr)]">
        <Card className="min-w-0 p-4 sm:p-5 lg:p-6">
          <div className="flex flex-col gap-4 border-b border-line/80 pb-5 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 className="text-xl font-extrabold tracking-[-0.025em] text-ink">Games in League Hub</h3>
              <p className="mt-1 text-sm font-medium text-muted">Members see these games natively in the app.</p>
            </div>
            <div className="inline-flex rounded-xl border border-line bg-[#f8fafc] p-1" role="group" aria-label="Schedule view">
              {(["upcoming", "results"] as const).map((item) => (
                <button
                  key={item}
                  type="button"
                  aria-pressed={view === item}
                  onClick={() => setView(item)}
                  className={`min-h-11 cursor-pointer rounded-lg px-4 text-sm font-bold capitalize transition-colors focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 ${view === item ? "bg-navy text-white shadow-sm" : "text-muted hover:text-ink"}`}
                >
                  {item}
                </button>
              ))}
            </div>
          </div>
          <div className="mt-5 grid gap-3">
            {visibleEvents.slice(0, 100).map((event) => <AdminScheduleGame key={event.id} event={event} />)}
            {visibleEvents.length === 0 && (
              <WorkspaceEmptyState
                icon={view === "upcoming" ? CalendarDays : Trophy}
                title={view === "upcoming" ? "No upcoming games published" : "No final results yet"}
                description="The next healthy RAMP sync will add games here automatically."
              />
            )}
          </div>
        </Card>

        <div className="grid content-start gap-5">
          <Card className="p-5 sm:p-6">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-[10px] font-extrabold uppercase tracking-[0.14em] text-muted">Import health</p>
                <h3 className="mt-2 text-lg font-extrabold text-ink">Latest sync</h3>
              </div>
              <Badge tone={syncTone}>{sync?.status ?? (integration ? "Waiting" : "Not configured")}</Badge>
            </div>
            <p className="mt-4 text-sm font-medium leading-6 text-muted">
              {sync?.message ?? (integration ? "The first schedule sync has not run yet." : "Configure the official JPHL schedule source to begin importing games.")}
            </p>
            <dl className="mt-5 grid gap-3 border-t border-line/80 pt-5">
              <InfoRow label="Last success" value={dateTimeLabel(sync?.lastSuccessAt)} />
              <InfoRow label="Feeds succeeded" value={`${sync?.teamFeedsSucceeded ?? 0} / ${sync?.teamFeedsTotal ?? 0}`} />
              <InfoRow label="Games received" value={String(sync?.eventCount ?? 0)} />
              <InfoRow label="Missing preserved" value={sync?.removalsSkipped ? "Yes — safety guard active" : "No"} />
            </dl>
          </Card>

          {canManage && (
            <details className="rounded-2xl border border-line/80 bg-panel shadow-card">
              <summary className="flex min-h-14 cursor-pointer list-none items-center justify-between gap-3 px-5 text-sm font-extrabold text-ink focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15">
                RAMP source settings
                <ChevronDown className="size-4 text-muted" aria-hidden />
              </summary>
              <form className="grid gap-4 border-t border-line/80 p-5" onSubmit={saveIntegration}>
                <Field label="Season ID" hint="RAMP SID">
                  <Input required value={settings.seasonId} onChange={(event) => setSettings((current) => ({ ...current, seasonId: event.target.value }))} />
                </Field>
                <Field label="Association ID">
                  <Input required value={settings.associationId} onChange={(event) => setSettings((current) => ({ ...current, associationId: event.target.value }))} />
                </Field>
                <Field label="Timezone">
                  <Input required value={settings.timezone} onChange={(event) => setSettings((current) => ({ ...current, timezone: event.target.value }))} />
                </Field>
                <div className="grid grid-cols-2 gap-3">
                  {["14U", "15U", "17U", "18U"].map((ageGroup) => (
                    <Field key={ageGroup} label={`${ageGroup} division`}>
                      <Input
                        required
                        aria-label={`${ageGroup} division ID`}
                        value={settings.divisionIds[ageGroup] ?? ""}
                        onChange={(event) => setSettings((current) => ({
                          ...current,
                          divisionIds: { ...current.divisionIds, [ageGroup]: event.target.value }
                        }))}
                      />
                    </Field>
                  ))}
                </div>
                <label className="flex min-h-11 cursor-pointer items-center gap-3 text-sm font-bold text-ink">
                  <input
                    type="checkbox"
                    checked={settings.enabled}
                    onChange={(event) => setSettings((current) => ({ ...current, enabled: event.target.checked }))}
                    className="size-4 accent-teal"
                  />
                  Automatic schedule sync enabled
                </label>
                <Button type="submit" disabled={saving}>
                  <Save className="size-4" aria-hidden />
                  {saving ? "Saving…" : "Save source settings"}
                </Button>
              </form>
            </details>
          )}
        </div>
      </div>
    </div>
  );
}

function defaultScheduleIntegration(): ScheduleIntegration {
  return {
    provider: "ramp",
    enabled: true,
    baseUrl: "https://juniorprospectshockeyleague.com",
    associationId: "2888",
    seasonId: "12322",
    timezone: "America/Edmonton",
    divisionIds: { "14U": "16624", "15U": "16623", "17U": "23859", "18U": "16622" }
  };
}

function AdminScheduleGame({ event }: { event: ScheduleEvent }) {
  const final = event.status === "final";
  const date = event.localDate
    ? new Intl.DateTimeFormat("en", { weekday: "short", month: "short", day: "numeric", timeZone: "UTC" }).format(new Date(`${event.localDate}T12:00:00Z`))
    : dateLabel(event.startsAt);
  const time = event.localStartTime ? scheduleClockLabel(event.localStartTime) : dateTimeLabel(event.startsAt);
  return (
    <article className="grid gap-4 rounded-2xl border border-line/80 bg-[#fbfcfd] p-4 transition-[border-color,box-shadow] hover:border-[#b8c4d2] hover:shadow-soft sm:grid-cols-[116px_minmax(0,1fr)_auto] sm:items-center">
      <div>
        <p className="text-xs font-extrabold uppercase tracking-[0.08em] text-teal">{final ? "Final" : date}</p>
        <p className="mt-1 text-sm font-bold text-ink">{final ? date : time}</p>
        <p className="mt-1 text-xs font-semibold text-muted">{event.division ?? "Game"}</p>
      </div>
      <div className="min-w-0">
        <div className="flex items-center gap-3">
          <p className="min-w-0 flex-1 truncate text-sm font-extrabold text-ink">{cleanScheduleTeamName(event.firstTeamName)}</p>
          {final && <span className="text-lg font-extrabold text-ink">{event.firstScore ?? "–"}</span>}
        </div>
        <div className="mt-2 flex items-center gap-3">
          <p className="min-w-0 flex-1 truncate text-sm font-extrabold text-ink">{cleanScheduleTeamName(event.secondTeamName)}</p>
          {final && <span className="text-lg font-extrabold text-ink">{event.secondScore ?? "–"}</span>}
        </div>
        {event.location && <p className="mt-2 truncate text-xs font-medium text-muted"><MapPin className="mr-1 inline size-3.5" aria-hidden />{event.location}</p>}
      </div>
      <Badge tone={final ? "neutral" : "info"}>{final ? "Complete" : "Scheduled"}</Badge>
    </article>
  );
}

function cleanScheduleTeamName(value: string) {
  return value.replace(/^\d{2}U\s+(?:AAA|AA|A)\s+-\s+/, "").trim();
}

function scheduleClockLabel(value: string) {
  const [hour, minute] = value.split(":").map(Number);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return value;
  return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit", timeZone: "UTC" })
    .format(new Date(Date.UTC(2000, 0, 1, hour, minute)));
}

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
  const filters: Array<WorkspaceFilterItem<PeopleView>> = [
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
      <ManagementWorkspace
        eyebrow="Member directory"
        title={`People at ${data.selectedOrg?.name ?? "League Hub"}`}
        description="See who belongs to the organization, understand their hub and team access at a glance, and manage invitations without losing context."
        icon={Users}
        metrics={[
          { label: "Active members", value: data.users.filter((user) => user.isActive).length },
          { label: "Managers", value: managers.length },
          { label: "Staff", value: staff.length },
          { label: "Pending invites", value: pendingInvitations.length }
        ]}
        action={<ToolbarActionButton icon={UserPlus} onClick={() => setCreateInviteOpen(true)}>Add Member</ToolbarActionButton>}
        filters={filters}
        selectedFilterId={view}
        onSelectFilter={(nextView) => {
          setView(nextView);
          setQuery("");
        }}
        panelTitle={panelCopy[view].title}
        panelDescription={panelCopy[view].description}
        searchLabel={view === "invites" ? "Search invites..." : "Search members..."}
        searchValue={query}
        onSearchChange={setQuery}
      >
        <div className="mb-3 flex items-center justify-between gap-3">
          <p className="text-sm font-extrabold text-ink">
            {view === "invites" ? pluralize(filteredInvites.length, "invite") : pluralize(filteredUsers.length, "member")}
          </p>
          <p className="hidden text-xs font-semibold text-muted sm:block">Select a card to review access and details</p>
        </div>

        {view === "invites" ? (
          filteredInvites.length > 0 ? (
            <div className="grid gap-3 xl:grid-cols-2">
              {filteredInvites.map((invite) => (
                <button
                  key={invite.id}
                  type="button"
                  aria-label={`Open invitation for ${invite.displayName || invite.email}`}
                  onClick={() => {
                    setSelectedInviteId(invite.id);
                    setSelectedUserId(null);
                  }}
                  className={`group min-w-0 rounded-2xl border p-4 text-left transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-px hover:border-[#b8c4d2] hover:shadow-soft focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 sm:p-5 ${selectedInvite?.id === invite.id ? "border-teal/40 bg-teal/[0.035]" : "border-line bg-[#fcfdff]"}`}
                >
                  <span className="flex min-w-0 items-start gap-3.5">
                    <EntityAvatar name={invite.displayName ?? invite.email} />
                    <span className="min-w-0 flex-1">
                      <span className="flex min-w-0 items-start justify-between gap-3">
                        <span className="min-w-0">
                          <span className="block truncate text-base font-extrabold text-ink group-hover:text-teal sm:text-lg">{invite.displayName || invite.email}</span>
                          <span className="mt-1 flex min-w-0 items-center gap-2 text-sm font-medium text-muted"><Mail className="size-3.5 shrink-0" aria-hidden /><span className="truncate">{invite.email}</span></span>
                        </span>
                        <ChevronRight className="mt-1 size-4 shrink-0 text-muted transition-transform group-hover:translate-x-0.5" aria-hidden />
                      </span>
                      <span className="mt-3 flex flex-wrap gap-2"><Badge tone="warning">Pending</Badge><Badge tone="info">{roleLabel(invite.role)}</Badge></span>
                    </span>
                  </span>
                  <span className="mt-4 grid grid-cols-3 gap-2 border-t border-line/70 pt-4">
                    <span><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">Created</span><span className="mt-1 block truncate text-xs font-bold text-ink">{dateLabel(invite.createdAt)}</span></span>
                    <span><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">Hubs</span><span className="mt-1 block text-xs font-bold text-ink">{invite.hubIds.length}</span></span>
                    <span><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">Teams</span><span className="mt-1 block text-xs font-bold text-ink">{invite.teamIds.length}</span></span>
                  </span>
                </button>
              ))}
            </div>
          ) : (
            <WorkspaceEmptyState icon={Inbox} title="No pending invitations" description="No invitations match the current filter and search." />
          )
        ) : filteredUsers.length > 0 ? (
          <div className="grid gap-3 xl:grid-cols-2">
            {filteredUsers.map((user) => (
              <button
                key={user.id}
                type="button"
                aria-label={`Open ${user.displayName} member details`}
                onClick={() => {
                  setSelectedUserId(user.id);
                  setSelectedInviteId(null);
                }}
                className={`group min-w-0 rounded-2xl border p-4 text-left transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-px hover:border-[#b8c4d2] hover:shadow-soft focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 sm:p-5 ${selectedUser?.id === user.id ? "border-teal/40 bg-teal/[0.035]" : "border-line bg-[#fcfdff]"}`}
              >
                <span className="flex min-w-0 items-start gap-3.5">
                  <EntityAvatar name={user.displayName} imageUrl={user.avatarUrl} />
                  <span className="min-w-0 flex-1">
                    <span className="flex min-w-0 items-start justify-between gap-3">
                      <span className="min-w-0">
                        <span className="block truncate text-base font-extrabold text-ink group-hover:text-teal sm:text-lg">{user.displayName}</span>
                        <span className="mt-1 flex min-w-0 items-center gap-2 text-sm font-medium text-muted"><Mail className="size-3.5 shrink-0" aria-hidden /><span className="truncate">{user.email}</span></span>
                        {user.phone && <span className="mt-1 flex min-w-0 items-center gap-2 text-sm font-medium text-muted"><Phone className="size-3.5 shrink-0" aria-hidden /><span className="truncate">{user.phone}</span></span>}
                      </span>
                      <ChevronRight className="mt-1 size-4 shrink-0 text-muted transition-transform group-hover:translate-x-0.5" aria-hidden />
                    </span>
                    <span className="mt-3 flex flex-wrap gap-2">
                      <Badge tone={user.role === "staff" ? "neutral" : "info"}>{roleLabel(user.role)}</Badge>
                      <Badge tone={user.isActive ? "good" : "danger"}>{user.isActive ? "Active" : "Inactive"}</Badge>
                    </span>
                  </span>
                </span>
                <span className="mt-4 grid grid-cols-[minmax(0,1fr)_auto_auto] gap-3 border-t border-line/70 pt-4">
                  <span className="min-w-0">
                    <span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">Profile</span>
                    <span className="mt-1 block truncate text-xs font-bold text-ink">{user.title || "No title set"}</span>
                    {user.address && <span className="mt-0.5 block truncate text-[11px] font-semibold text-muted">{user.address}</span>}
                  </span>
                  <span className="min-w-12"><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">Hubs</span><span className="mt-1 block text-xs font-bold text-ink">{user.hubIds.length}</span></span>
                  <span className="min-w-12"><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">Teams</span><span className="mt-1 block text-xs font-bold text-ink">{user.teamIds.length}</span></span>
                </span>
              </button>
            ))}
          </div>
        ) : (
          <WorkspaceEmptyState icon={Users} title="No members found" description="No members match the current filter and search." />
        )}
      </ManagementWorkspace>

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
                <InfoRow label="Phone" value={selectedUser.phone} />
                <InfoRow label="Title" value={selectedUser.title} />
                <InfoRow label="Address" value={selectedUser.address} />
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

type StructureCreateRequest =
  | { type: "league" }
  | { type: "hub"; leagueId?: string }
  | { type: "team"; hubId?: string };

type StructureMapTeam = {
  team: Team;
  people: AppUser[];
  totalPeople: number;
};

type StructureMapHub = {
  hub: Hub;
  directPeople: AppUser[];
  teams: StructureMapTeam[];
  totalPeople: number;
  totalTeams: number;
};

type StructureMapLeague = {
  league: League;
  directPeople: AppUser[];
  hubs: StructureMapHub[];
  totalHubs: number;
  totalPeople: number;
  totalTeams: number;
};

function matchesPersonQuery(person: AppUser, query: string) {
  return matchesQuery([person.displayName, person.email, roleLabel(person.role)], query);
}

function StructureSection({ data, currentUser, runAction }: { data: AdminData; currentUser: AppUser; runAction: ActionRunner }) {
  const [selection, setSelection] = useState<StructureSelection | null>(null);
  const [query, setQuery] = useState("");
  const [createRequest, setCreateRequest] = useState<StructureCreateRequest | null>(null);
  const [collapsedHubIds, setCollapsedHubIds] = useState<Set<string>>(() => new Set());
  const relationships = useMemo(() => buildStructureRelationshipIndex(data), [data]);
  const hasQuery = Boolean(query.trim());
  const visibleStructure = useMemo<StructureMapLeague[]>(() => data.leagues.flatMap((league) => {
    const leagueMatches = matchesQuery([league.name, league.abbreviation, league.description], query);
    const allLeaguePeople = relationships.directPeopleForLeague(league.id);
    const matchingLeaguePeople = allLeaguePeople.filter((person) => matchesPersonQuery(person, query));
    const hubs = data.hubs
      .filter((hub) => hub.leagueId === league.id)
      .flatMap<StructureMapHub>((hub) => {
        const allHubTeams = data.teams.filter((team) => team.hubId === hub.id);
        const hubMatches = matchesQuery([hub.name, hub.location], query);
        const allHubPeople = relationships.directPeopleForHub(hub.id);
        const matchingHubPeople = allHubPeople.filter((person) => matchesPersonQuery(person, query));
        const teams = allHubTeams
          .flatMap<StructureMapTeam>((team) => {
            const teamMatches = matchesQuery([team.name, team.ageGroup, team.division], query);
            const allTeamPeople = relationships.peopleForTeam(team.id);
            const matchingTeamPeople = allTeamPeople.filter((person) => matchesPersonQuery(person, query));
            const showTeam = !hasQuery || leagueMatches || hubMatches || teamMatches || matchingTeamPeople.length > 0;
            if (!showTeam) return [];
            return [{
              team,
              people: hasQuery && !leagueMatches && !hubMatches && !teamMatches ? matchingTeamPeople : allTeamPeople,
              totalPeople: allTeamPeople.length
            }];
          });
        const showHub = !hasQuery || leagueMatches || hubMatches || matchingHubPeople.length > 0 || teams.length > 0;
        if (!showHub) return [];
        return [{
          hub,
          directPeople: hasQuery && !leagueMatches && !hubMatches ? matchingHubPeople : allHubPeople,
          teams,
          totalPeople: relationships.peopleForHub(hub.id).length,
          totalTeams: allHubTeams.length
        }];
      });
    const showLeague = !hasQuery || leagueMatches || matchingLeaguePeople.length > 0 || hubs.length > 0;
    if (!showLeague) return [];
    return [{
      league,
      directPeople: hasQuery && !leagueMatches ? matchingLeaguePeople : allLeaguePeople,
      hubs,
      totalHubs: data.hubs.filter((hub) => hub.leagueId === league.id).length,
      totalPeople: relationships.peopleForLeague(league.id).length,
      totalTeams: data.teams.filter((team) => team.leagueId === league.id).length
    }];
  }), [data, hasQuery, query, relationships]);
  const connectedPeopleCount = useMemo(() => new Set(
    data.leagues.flatMap((league) => relationships.peopleForLeague(league.id).map((person) => person.id))
  ).size, [data.leagues, relationships]);
  const allHubsCollapsed = data.hubs.length > 0 && data.hubs.every((hub) => collapsedHubIds.has(hub.id));
  const canCreateLeague = currentUser.role === "platformOwner";

  function toggleHub(hubId: string) {
    setCollapsedHubIds((current) => {
      const next = new Set(current);
      if (next.has(hubId)) next.delete(hubId);
      else next.add(hubId);
      return next;
    });
  }

  return (
    <>
      <div className="grid gap-5 sm:gap-6">
        <section className="relative overflow-hidden rounded-[28px] bg-hero-glow p-5 text-white shadow-lift sm:p-7 lg:p-8" aria-labelledby="structure-workspace-title">
          <div className="pointer-events-none absolute -right-16 -top-20 size-72 rounded-full border border-white/10" />
          <div className="pointer-events-none absolute -right-28 top-8 size-72 rounded-full border border-white/[0.06]" />
          <div className="relative flex flex-col gap-6 xl:flex-row xl:items-start xl:justify-between">
            <div className="max-w-2xl">
              <span className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.07] px-3 py-1.5 text-xs font-bold text-white/75">
                <Network className="size-3.5 text-[#5eead4]" aria-hidden /> Connected organization
              </span>
              <h2 id="structure-workspace-title" className="mt-5 text-3xl font-extrabold tracking-[-0.04em] sm:text-4xl">
                Organization structure
              </h2>
              <p className="mt-3 max-w-xl text-sm font-medium leading-6 text-white/65 sm:text-base sm:leading-7">
                See how every league, hub, team, and person fits together—then manage each record without losing its context.
              </p>
            </div>
            <div className={`grid w-full gap-2 ${canCreateLeague ? "sm:grid-cols-3" : "sm:grid-cols-2"} xl:w-auto`}>
              {canCreateLeague && <StructureAddButton label="Add league" onClick={() => setCreateRequest({ type: "league" })} primary />}
              <StructureAddButton
                label="Add hub"
                onClick={() => setCreateRequest({ type: "hub", leagueId: data.leagues.length === 1 ? data.leagues[0].id : undefined })}
                disabled={data.leagues.length === 0}
              />
              <StructureAddButton
                label="Add team"
                onClick={() => setCreateRequest({ type: "team", hubId: data.hubs.length === 1 ? data.hubs[0].id : undefined })}
                disabled={data.hubs.length === 0}
              />
            </div>
          </div>
          <div className="relative mt-7 grid grid-cols-2 gap-2 border-t border-white/10 pt-5 sm:grid-cols-4">
            <StructureMetric label="Leagues" value={data.leagues.length} icon={Trophy} />
            <StructureMetric label="Hubs" value={data.hubs.length} icon={MapPin} />
            <StructureMetric label="Teams" value={data.teams.length} icon={Users} />
            <StructureMetric label="Connected people" value={connectedPeopleCount} icon={UserRound} />
          </div>
        </section>

        <section className="min-w-0" aria-labelledby="structure-map-title">
          <div className="mb-4 rounded-2xl border border-line/80 bg-white p-4 shadow-card sm:p-5">
            <div className="flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
              <div className="min-w-0">
                <h3 id="structure-map-title" className="text-xl font-extrabold tracking-[-0.025em] text-ink sm:text-2xl">Connected structure map</h3>
                <p className="mt-1 text-sm font-medium text-muted">Follow the connector lines from leagues to hubs, teams, and their people.</p>
              </div>
              <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
                <SearchBox label="Search structure or people..." value={query} onChange={setQuery} />
                <button
                  type="button"
                  onClick={() => setCollapsedHubIds(allHubsCollapsed ? new Set() : new Set(data.hubs.map((hub) => hub.id)))}
                  disabled={hasQuery}
                  className="inline-flex min-h-12 shrink-0 items-center justify-center gap-2 rounded-xl border border-line bg-white px-4 text-sm font-bold text-ink transition-colors hover:border-[#b8c4d2] hover:bg-[#f8fafc] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 disabled:cursor-not-allowed disabled:bg-[#f8fafc] disabled:text-muted disabled:opacity-75"
                >
                  {hasQuery ? <Search className="size-4" aria-hidden /> : allHubsCollapsed ? <ChevronDown className="size-4" aria-hidden /> : <ChevronDown className="size-4 rotate-180" aria-hidden />}
                  {hasQuery ? "Matches expanded" : allHubsCollapsed ? "Expand all" : "Collapse all"}
                </button>
              </div>
            </div>
            <p className="mt-3 text-xs font-semibold text-muted" aria-live="polite">
              {hasQuery
                ? `${pluralize(visibleStructure.length, "matching league")} shown for “${query.trim()}”`
                : `${pluralize(data.leagues.length, "league")} · ${pluralize(data.hubs.length, "hub")} · ${pluralize(data.teams.length, "team")} · ${pluralize(connectedPeopleCount, "connected person", "connected people")}`}
            </p>
          </div>

          <StructureMap
            leagues={visibleStructure}
            hasQuery={hasQuery}
            collapsedHubIds={collapsedHubIds}
            onToggleHub={toggleHub}
            onSelect={setSelection}
            onAddHub={(leagueId) => setCreateRequest({ type: "hub", leagueId })}
            onAddTeam={(hubId) => setCreateRequest({ type: "team", hubId })}
          />
        </section>
      </div>
      <StructureEditorDrawer selection={selection} data={data} relationships={relationships} onClose={() => setSelection(null)} runAction={runAction} />
      <StructureCreateDrawer request={createRequest} data={data} canCreateLeague={canCreateLeague} runAction={runAction} onClose={() => setCreateRequest(null)} />
    </>
  );
}

function StructureAddButton({
  label,
  onClick,
  primary = false,
  disabled = false
}: {
  label: string;
  onClick: () => void;
  primary?: boolean;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border px-4 text-sm font-bold transition-colors focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#5eead4]/40 disabled:cursor-not-allowed disabled:opacity-45 ${
        primary
          ? "border-[#5eead4]/40 bg-[#5eead4] text-navy hover:bg-[#8ff3e7]"
          : "border-white/15 bg-white/[0.08] text-white hover:border-white/25 hover:bg-white/[0.13]"
      }`}
    >
      <Plus className="size-4" aria-hidden />
      {label}
    </button>
  );
}

function StructureMetric({ label, value, icon: Icon }: { label: string; value: number; icon: React.ComponentType<{ className?: string }> }) {
  return (
    <div className="flex min-w-0 items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.07] px-3 py-3 sm:px-4">
      <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-white/10 text-[#8ff3e7]">
        <Icon className="size-4" aria-hidden />
      </span>
      <span className="min-w-0">
        <span className="block text-xl font-extrabold tracking-[-0.03em]">{value}</span>
        <span className="block truncate text-[11px] font-bold text-white/60">{label}</span>
      </span>
    </div>
  );
}

function StructureEntityLogo({
  name,
  imageUrl,
  icon: Icon,
  level
}: {
  name: string;
  imageUrl?: string | null;
  icon: React.ComponentType<{ className?: string }>;
  level: "league" | "hub" | "team";
}) {
  const [imageFailed, setImageFailed] = useState(false);

  useEffect(() => {
    setImageFailed(false);
  }, [imageUrl]);

  const styles = {
    league: {
      frame: "size-12 rounded-2xl border-white/30 bg-white p-1.5 text-teal shadow-sm",
      icon: "size-5"
    },
    hub: {
      frame: "size-10 rounded-xl border-line bg-white p-1.5 text-sky shadow-sm",
      icon: "size-4"
    },
    team: {
      frame: "size-10 rounded-xl border-line bg-white p-1.5 text-teal shadow-sm",
      icon: "size-4"
    }
  }[level];

  return (
    <span className={`grid shrink-0 place-items-center overflow-hidden border ${styles.frame}`}>
      {imageUrl && !imageFailed ? (
        // Firebase Storage URLs are dynamic and the admin app is a static export, so use an unoptimized native image.
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={imageUrl}
          alt={`${name} logo`}
          className="size-full object-contain"
          loading="lazy"
          decoding="async"
          referrerPolicy="no-referrer"
          onError={() => setImageFailed(true)}
        />
      ) : (
        <Icon className={styles.icon} aria-hidden />
      )}
    </span>
  );
}

function StructureMap({
  leagues,
  hasQuery,
  collapsedHubIds,
  onToggleHub,
  onSelect,
  onAddHub,
  onAddTeam
}: {
  leagues: StructureMapLeague[];
  hasQuery: boolean;
  collapsedHubIds: Set<string>;
  onToggleHub: (hubId: string) => void;
  onSelect: (selection: StructureSelection) => void;
  onAddHub: (leagueId: string) => void;
  onAddTeam: (hubId: string) => void;
}) {
  if (leagues.length === 0) {
    return (
      <div className="rounded-[24px] border border-dashed border-line bg-white px-5 py-14 text-center shadow-card">
        <Search className="mx-auto size-6 text-muted" aria-hidden />
        <p className="mt-3 text-sm font-extrabold text-ink">No connected records found</p>
        <p className="mt-1 text-sm font-medium text-muted">Try another league, hub, team, person, email, or role.</p>
      </div>
    );
  }

  return (
    <div className="grid gap-5" aria-label="Connected structure map">
      {leagues.map(({ league, directPeople, hubs, totalHubs, totalPeople, totalTeams }) => (
        <article key={league.id} className="overflow-hidden rounded-[26px] border border-navy/10 bg-white shadow-card">
          <header className="relative overflow-hidden bg-navy px-4 py-5 text-white sm:px-6">
            <div className="pointer-events-none absolute -right-10 -top-16 size-48 rounded-full border border-white/10" />
            <div className="relative flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <button
                type="button"
                onClick={() => onSelect({ type: "league", league })}
                className="group flex min-h-12 min-w-0 items-center gap-3 rounded-xl text-left focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#5eead4]/45"
                aria-label={`Open ${league.name} league details`}
              >
                <StructureEntityLogo name={league.name} imageUrl={league.logoUrl} icon={Trophy} level="league" />
                <span className="min-w-0">
                  <span className="block text-[10px] font-extrabold uppercase tracking-[0.16em] text-white/55">League</span>
                  <span className="mt-1 block truncate text-xl font-extrabold tracking-[-0.025em] group-hover:text-[#8ff3e7] sm:text-2xl">{league.name}</span>
                </span>
              </button>
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full border border-white/15 bg-white/[0.08] px-3 py-1.5 text-xs font-bold text-white/80">{league.abbreviation}</span>
                <span className="rounded-full border border-white/15 bg-white/[0.08] px-3 py-1.5 text-xs font-bold text-white/80">
                  {hasQuery && hubs.length !== totalHubs ? `${hubs.length} of ${pluralize(totalHubs, "hub")}` : pluralize(totalHubs, "hub")}
                </span>
                <span className="rounded-full border border-white/15 bg-white/[0.08] px-3 py-1.5 text-xs font-bold text-white/80">{pluralize(totalTeams, "team")}</span>
                <span className="rounded-full border border-[#5eead4]/25 bg-[#5eead4]/10 px-3 py-1.5 text-xs font-bold text-[#8ff3e7]">{pluralize(totalPeople, "person", "people")}</span>
                <button
                  type="button"
                  onClick={() => onAddHub(league.id)}
                  className="inline-flex min-h-10 items-center gap-1.5 rounded-xl border border-white/15 bg-white/[0.08] px-3 text-xs font-bold text-white transition-colors hover:border-white/25 hover:bg-white/[0.13] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[#5eead4]/40"
                >
                  <Plus className="size-3.5" aria-hidden /> Add hub
                </button>
              </div>
            </div>
          </header>

          {directPeople.length > 0 && (
            <StructureAccessRow label="League access" description="People assigned directly to this league" people={directPeople} />
          )}

          <div className="structure-league-branches grid gap-3 bg-[#f8fafc] p-3 sm:gap-4 sm:p-5">
            {hubs.map(({ hub, directPeople: hubPeople, teams, totalPeople: hubPeopleCount, totalTeams: hubTeamCount }) => {
              const expanded = hasQuery || !collapsedHubIds.has(hub.id);
              const contentId = `hub-connections-${hub.id}`;
              return (
                <section key={hub.id} className="structure-hub-branch overflow-hidden rounded-2xl border border-line/90 bg-white shadow-sm">
                  <div className="flex flex-col gap-3 px-3 py-3 sm:px-4 lg:flex-row lg:items-center lg:justify-between">
                    <div className="flex min-w-0 items-center gap-2">
                      <button
                        type="button"
                        onClick={() => onToggleHub(hub.id)}
                        disabled={hasQuery}
                        aria-expanded={expanded}
                        aria-controls={contentId}
                        aria-label={hasQuery ? `${hub.name} hub expanded for search` : `${expanded ? "Collapse" : "Expand"} ${hub.name} hub`}
                        className="grid size-11 shrink-0 place-items-center rounded-xl border border-line bg-[#f8fafc] text-muted transition-colors hover:border-[#b8c4d2] hover:text-ink focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        <ChevronDown className={`size-4 transition-transform duration-200 ${expanded ? "rotate-180" : ""}`} aria-hidden />
                      </button>
                      <button
                        type="button"
                        onClick={() => onSelect({ type: "hub", league, hub })}
                        className="group flex min-h-11 min-w-0 flex-1 items-center gap-3 rounded-xl text-left focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
                        aria-label={`Open ${hub.name} hub details`}
                      >
                        <StructureEntityLogo name={hub.name} imageUrl={hub.logoUrl} icon={MapPin} level="hub" />
                        <span className="min-w-0">
                          <span className="block truncate text-base font-extrabold text-ink group-hover:text-teal">{hub.name}</span>
                          <span className="mt-0.5 block truncate text-xs font-semibold text-muted">{hub.location || "No location set"}</span>
                        </span>
                      </button>
                    </div>
                    <div className="flex flex-wrap items-center gap-2 pl-[3.25rem] sm:pl-[3.75rem] lg:pl-0">
                      <Badge tone="neutral">{hasQuery && teams.length !== hubTeamCount ? `${teams.length} of ${pluralize(hubTeamCount, "team")}` : pluralize(hubTeamCount, "team")}</Badge>
                      <Badge tone="info">{pluralize(hubPeopleCount, "person", "people")}</Badge>
                      <button
                        type="button"
                        onClick={() => onAddTeam(hub.id)}
                        className="inline-flex min-h-10 items-center gap-1.5 rounded-xl border border-line bg-white px-3 text-xs font-bold text-ink transition-colors hover:border-teal/30 hover:bg-teal/[0.045] hover:text-teal focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
                      >
                        <Plus className="size-3.5" aria-hidden /> Add team
                      </button>
                    </div>
                  </div>

                  {expanded && (
                    <div id={contentId} className="structure-hub-content border-t border-line/80 bg-[#fcfdff] p-3 sm:p-4">
                      {hubPeople.length > 0 && (
                        <StructureAccessRow label="Hub access" description="People assigned directly to this hub" people={hubPeople} compact />
                      )}
                      <div className={`grid gap-2.5 ${hubPeople.length > 0 ? "mt-3" : ""}`}>
                        {teams.map(({ team, people, totalPeople: teamPeopleCount }) => (
                          <button
                            key={team.id}
                            type="button"
                            onClick={() => onSelect({ type: "team", league, hub, team })}
                            className="structure-team-branch group grid min-h-[104px] w-full gap-3 rounded-xl border border-line bg-white p-3.5 text-left transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-px hover:border-[#b8c4d2] hover:shadow-soft focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 sm:p-4 xl:grid-cols-[minmax(220px,0.8fr)_minmax(280px,1.2fr)] xl:items-center"
                            aria-label={`Open ${team.name} team details`}
                          >
                            <span className="flex min-w-0 items-center gap-3">
                              <StructureEntityLogo name={team.name} imageUrl={team.logoUrl} icon={Users} level="team" />
                              <span className="min-w-0">
                                <span className="block truncate text-sm font-extrabold text-ink group-hover:text-teal sm:text-base">{team.name}</span>
                                <span className="mt-1 flex flex-wrap gap-1.5">
                                  {team.ageGroup && <Badge tone="neutral">{team.ageGroup}</Badge>}
                                  {team.division && <Badge tone="neutral">{team.division}</Badge>}
                                  <Badge tone="info">{pluralize(teamPeopleCount, "person", "people")}</Badge>
                                </span>
                              </span>
                            </span>
                            <span className="min-w-0 border-t border-line/70 pt-3 xl:border-l xl:border-t-0 xl:pl-4 xl:pt-0">
                              <span className="mb-2 block text-[10px] font-extrabold uppercase tracking-[0.1em] text-muted">Team roster</span>
                              <RelationshipPeoplePreview people={people} emptyLabel="No people connected to this team" />
                            </span>
                          </button>
                        ))}
                        {teams.length === 0 && <EmptyLine label={hasQuery ? "No teams in this hub match the search" : "No teams have been added to this hub"} />}
                      </div>
                    </div>
                  )}
                </section>
              );
            })}
            {hubs.length === 0 && <EmptyLine label={hasQuery ? "No hubs in this league match the search" : "No hubs have been added to this league"} />}
          </div>
        </article>
      ))}
    </div>
  );
}

function StructureAccessRow({
  label,
  description,
  people,
  compact = false
}: {
  label: string;
  description: string;
  people: AppUser[];
  compact?: boolean;
}) {
  return (
    <div className={`grid gap-3 border-line/80 bg-white ${compact ? "structure-access-branch rounded-xl border p-3" : "border-b px-4 py-4 sm:grid-cols-[180px_minmax(0,1fr)] sm:items-center sm:px-6"}`}>
      <div className="min-w-0">
        <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-muted">{label}</p>
        <p className="mt-1 text-xs font-semibold text-muted">{description}</p>
      </div>
      <RelationshipPeoplePreview people={people} emptyLabel="No direct access" />
    </div>
  );
}

function PersonInitials({ person, compact = false }: { person: AppUser; compact?: boolean }) {
  const initials = person.displayName
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("") || "?";

  return person.avatarUrl ? (
    <span
      aria-hidden
      className={`grid shrink-0 rounded-full bg-cover bg-center ring-1 ring-line ${compact ? "size-7" : "size-8"}`}
      style={{ backgroundImage: `url(${person.avatarUrl})` }}
    />
  ) : (
    <span aria-hidden className={`grid shrink-0 place-items-center rounded-full bg-shell font-extrabold text-muted ring-1 ring-line/70 ${compact ? "size-7 text-[9px]" : "size-8 text-[10px]"}`}>
      {initials}
    </span>
  );
}

function RelationshipPeoplePreview({ people, emptyLabel }: { people: AppUser[]; emptyLabel: string }) {
  if (people.length === 0) {
    return <p className="text-sm font-medium text-muted">{emptyLabel}</p>;
  }

  const visiblePeople = people.slice(0, 3);
  const remainingPeople = people.length - visiblePeople.length;
  return (
    <div className="flex flex-wrap items-center gap-2" aria-label={pluralize(people.length, "connected person", "connected people")}>
      {visiblePeople.map((person) => (
        <span key={person.id} className="inline-flex min-h-8 max-w-full items-center gap-1.5 rounded-full border border-line bg-white py-0.5 pl-0.5 pr-2.5 text-xs font-bold text-ink shadow-sm">
          <PersonInitials person={person} compact />
          <span className="max-w-[132px] truncate">{person.displayName}</span>
        </span>
      ))}
      {remainingPeople > 0 && <span className="inline-flex min-h-8 items-center rounded-full border border-line bg-white px-2.5 text-xs font-extrabold text-muted">+{remainingPeople} more</span>}
    </div>
  );
}

function ConnectedPeopleList({ people }: { people: AppUser[] }) {
  if (people.length === 0) {
    return <EmptyLine label="No people are connected to this record yet" />;
  }

  return (
    <ul className="grid gap-2.5" aria-label={pluralize(people.length, "connected person", "connected people")}>
      {people.map((person) => (
        <li key={person.id} className="flex min-h-14 items-center gap-3 rounded-xl border border-line bg-white px-3 py-2.5 shadow-sm">
          <PersonInitials person={person} />
          <span className="min-w-0 flex-1">
            <span className="block truncate text-sm font-extrabold text-ink">{person.displayName}</span>
            <span className="mt-0.5 block truncate text-xs font-medium text-muted">{roleLabel(person.role)} · {person.email}</span>
          </span>
          <Badge tone={person.isActive ? "good" : "neutral"}>{person.isActive ? "Active" : "Inactive"}</Badge>
        </li>
      ))}
    </ul>
  );
}

function StructureEditorDrawer({
  selection,
  data,
  relationships,
  onClose,
  runAction
}: {
  selection: StructureSelection | null;
  data: AdminData;
  relationships: StructureRelationshipIndex;
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
    let result: ActionResult | undefined;
    if (selection.type === "league") {
      result = await runAction("adminDeleteLeague", { leagueId: selection.league.id });
    }
    if (selection.type === "hub") {
      result = await runAction("adminDeleteHub", { leagueId: selection.league.id, hubId: selection.hub.id });
    }
    if (selection.type === "team") {
      result = await runAction("adminDeleteTeam", { leagueId: selection.league.id, hubId: selection.hub.id, teamId: selection.team.id });
    }
    if (result?.ok) onClose();
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
  const connectedPeople =
    selection?.type === "league" ? relationships.peopleForLeague(selection.league.id) :
    selection?.type === "hub" ? relationships.peopleForHub(selection.hub.id) :
    selection?.type === "team" ? relationships.peopleForTeam(selection.team.id) :
    [];
  const connectedHubs = selection?.type === "league"
    ? data.hubs.filter((hub) => hub.leagueId === selection.league.id)
    : [];
  const connectedTeams = selection?.type === "league"
    ? data.teams.filter((team) => team.leagueId === selection.league.id)
    : selection?.type === "hub"
      ? data.teams.filter((team) => team.hubId === selection.hub.id)
      : [];

  return (
    <SideDrawer
      open={Boolean(selection)}
      title={title}
      description={selection ? `${selection.type[0].toUpperCase()}${selection.type.slice(1)} details` : undefined}
      icon={Icon}
      onClose={onClose}
      footer={
        <DrawerEditActions
          entityKey={selection ? `${selection.type}:${selection.type === "league" ? selection.league.id : selection.type === "hub" ? selection.hub.id : selection.team.id}` : "structure"}
          entityLabel={selection?.type ?? "record"}
          onSave={save}
          onDelete={deleteSelection}
        />
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
          <DrawerSection title="Connections">
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {selection.type === "league" && <InfoRow label="Hubs" value={connectedHubs.length} />}
              {selection.type !== "team" && <InfoRow label="Teams" value={connectedTeams.length} />}
              {selection.type !== "league" && <InfoRow label="League" value={selection.league.name} />}
              {selection.type === "team" && <InfoRow label="Hub" value={selection.hub.name} />}
              <InfoRow label="People" value={connectedPeople.length} />
            </div>
          </DrawerSection>
          <DrawerSection title={`People (${connectedPeople.length})`}>
            <ConnectedPeopleList people={connectedPeople} />
          </DrawerSection>
        </>
      )}
    </SideDrawer>
  );
}

function StructureCreateDrawer({
  request,
  data,
  canCreateLeague,
  runAction,
  onClose
}: {
  request: StructureCreateRequest | null;
  data: AdminData;
  canCreateLeague: boolean;
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
  const type = request?.type ?? "league";

  useEffect(() => {
    if (!request) return;
    if (request.type === "hub") setLeagueId(request.leagueId ?? "");
    if (request.type === "team") setHubId(request.hubId ?? "");
  }, [request]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (type === "league") {
      if (!canCreateLeague) return;
      const result = await runAction("adminUpsertLeague", { league: { name: leagueName, abbreviation: leagueAbbrev, iconName: "league" } });
      if (!result.ok) return;
      setLeagueName("");
      setLeagueAbbrev("");
      onClose();
      return;
    }
    if (type === "hub") {
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

  const title = type === "league" ? "Add League" : type === "hub" ? "Add Hub" : "Add Team";
  const description = type === "league"
    ? "Create a top-level league for this organization."
    : type === "hub"
      ? "Connect a new hub to its parent league."
      : "Connect a new team to its parent hub and league.";

  return (
    <SideDrawer open={Boolean(request && (request.type !== "league" || canCreateLeague))} title={title} description={description} icon={Building2} onClose={onClose}>
      <form className="grid gap-4" onSubmit={submit}>
        {type === "league" && (
          <>
            <Field label="Name"><Input value={leagueName} onChange={(event) => setLeagueName(event.target.value)} required /></Field>
            <Field label="Abbreviation"><Input value={leagueAbbrev} onChange={(event) => setLeagueAbbrev(event.target.value)} required /></Field>
          </>
        )}
        {type === "hub" && (
          <>
            <Field label="League"><Select value={leagueId} onChange={(event) => setLeagueId(event.target.value)} required><option value="">Select</option>{data.leagues.map((league) => <option key={league.id} value={league.id}>{league.name}</option>)}</Select></Field>
            <Field label="Name"><Input value={hubName} onChange={(event) => setHubName(event.target.value)} required /></Field>
            <Field label="Location"><Input value={hubLocation} onChange={(event) => setHubLocation(event.target.value)} /></Field>
          </>
        )}
        {type === "team" && (
          <>
            <Field label="Hub"><Select value={hubId} onChange={(event) => setHubId(event.target.value)} required><option value="">Select</option>{data.hubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}</Select></Field>
            <Field label="Name"><Input value={teamName} onChange={(event) => setTeamName(event.target.value)} required /></Field>
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Age"><Input value={teamAge} onChange={(event) => setTeamAge(event.target.value)} /></Field>
              <Field label="Division"><Input value={teamDivision} onChange={(event) => setTeamDivision(event.target.value)} /></Field>
            </div>
          </>
        )}
        {(type === "hub" && data.leagues.length === 0) || (type === "team" && data.hubs.length === 0) ? (
          <EmptyLine label={type === "hub" ? "Create a league before adding hubs" : "Create a hub before adding teams"} />
        ) : null}
        <Button type="submit"><Plus className="size-4" aria-hidden />{title}</Button>
      </form>
    </SideDrawer>
  );
}

type AnnouncementView = "all" | "pinned" | AnnouncementScope;

function AnnouncementsSection({ data, runAction }: { data: AdminData; runAction: ActionRunner }) {
  const [query, setQuery] = useState("");
  const [view, setView] = useState<AnnouncementView>("all");
  const [createOpen, setCreateOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selectedAnnouncement = selectedId ? data.announcements.find((item) => item.id === selectedId) ?? null : null;
  const filteredAnnouncements = data.announcements
    .filter((announcement) => {
      if (view === "pinned") return announcement.isPinned;
      if (view === "league" || view === "hub" || view === "team") return announcement.scope === view;
      return true;
    })
    .filter((announcement) => matchesQuery([announcement.title, announcement.body, scopeLabel(announcement.scope), announcement.authorName], query));
  const filters: Array<WorkspaceFilterItem<AnnouncementView>> = [
    { id: "all", label: "All Posts", count: data.announcements.length, icon: Megaphone },
    { id: "pinned", label: "Pinned", count: data.announcements.filter((item) => item.isPinned).length, icon: Pin },
    { id: "league", label: "League", count: data.announcements.filter((item) => item.scope === "league").length, icon: Trophy },
    { id: "hub", label: "Hub", count: data.announcements.filter((item) => item.scope === "hub").length, icon: MapPin },
    { id: "team", label: "Team", count: data.announcements.filter((item) => item.scope === "team").length, icon: Users }
  ];
  const panelCopy: Record<AnnouncementView, { title: string; description: string }> = {
    all: { title: "All Posts", description: "Every announcement visible in the selected organization." },
    pinned: { title: "Pinned Posts", description: "High-priority announcements that stay surfaced." },
    league: { title: "League Posts", description: "Announcements shared with an entire league." },
    hub: { title: "Hub Posts", description: "Announcements shared with a specific hub." },
    team: { title: "Team Posts", description: "Announcements shared with a specific team." }
  };

  return (
    <>
      <ManagementWorkspace
        eyebrow="Communications"
        title={`Announcements for ${data.selectedOrg?.name ?? "League Hub"}`}
        description="Plan and maintain league communications in a readable feed, with priority and audience visible before you open a post."
        icon={Megaphone}
        metrics={[
          { label: "Published", value: data.announcements.length },
          { label: "Pinned", value: data.announcements.filter((item) => item.isPinned).length },
          { label: "League", value: data.announcements.filter((item) => item.scope === "league").length },
          { label: "Hub & team", value: data.announcements.filter((item) => item.scope !== "league").length }
        ]}
        action={<ToolbarActionButton icon={Megaphone} onClick={() => setCreateOpen(true)}>New Announcement</ToolbarActionButton>}
        filters={filters}
        selectedFilterId={view}
        onSelectFilter={(nextView) => {
          setView(nextView);
          setQuery("");
        }}
        panelTitle={panelCopy[view].title}
        panelDescription={panelCopy[view].description}
        searchLabel="Search announcements..."
        searchValue={query}
        onSearchChange={setQuery}
      >
        <div className="mb-3 flex items-center justify-between gap-3">
          <p className="text-sm font-extrabold text-ink">{pluralize(filteredAnnouncements.length, "announcement")}</p>
          <p className="hidden text-xs font-semibold text-muted sm:block">Newest communications remain easy to scan</p>
        </div>
        {filteredAnnouncements.length > 0 ? (
          <div className="grid gap-3 xl:grid-cols-2">
            {filteredAnnouncements.map((announcement) => (
              <button
                key={announcement.id}
                type="button"
                aria-label={`Open ${announcement.title} announcement`}
                onClick={() => setSelectedId(announcement.id)}
                className={`group flex min-h-[220px] min-w-0 flex-col rounded-2xl border p-4 text-left transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-px hover:border-[#b8c4d2] hover:shadow-soft focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 sm:p-5 ${selectedAnnouncement?.id === announcement.id ? "border-teal/40 bg-teal/[0.035]" : "border-line bg-[#fcfdff]"}`}
              >
                <span className="flex items-start justify-between gap-3">
                  <span className="flex flex-wrap gap-2">
                    {announcement.isPinned && <Badge tone="warning"><Pin className="size-3" aria-hidden />Pinned</Badge>}
                    <Badge tone={announcement.scope === "league" ? "info" : "neutral"}>{scopeLabel(announcement.scope)}</Badge>
                  </span>
                  <ChevronRight className="mt-1 size-4 shrink-0 text-muted transition-transform group-hover:translate-x-0.5" aria-hidden />
                </span>
                <span className="mt-4 block text-lg font-extrabold leading-snug tracking-[-0.02em] text-ink group-hover:text-teal sm:text-xl">{announcement.title}</span>
                <span className="workspace-card-copy mt-2 block text-sm font-medium leading-6 text-muted">{announcement.body}</span>
                <span className="mt-auto flex flex-wrap items-center justify-between gap-3 border-t border-line/70 pt-4 text-xs font-semibold text-muted">
                  <span className="inline-flex min-w-0 items-center gap-2"><Shield className="size-3.5 shrink-0" aria-hidden /><span className="truncate">{announcement.authorName}</span></span>
                  <span className="inline-flex items-center gap-2"><Clock3 className="size-3.5" aria-hidden /><RelativeTime value={announcement.createdAt} /></span>
                </span>
              </button>
            ))}
          </div>
        ) : (
          <WorkspaceEmptyState icon={Megaphone} title="No announcements found" description="No announcements match the current filter and search." />
        )}
      </ManagementWorkspace>
      <AnnouncementCreateDrawer open={createOpen} data={data} runAction={runAction} onClose={() => setCreateOpen(false)} />
      <AnnouncementDrawer announcement={selectedAnnouncement} data={data} onClose={() => setSelectedId(null)} runAction={runAction} />
    </>
  );
}

function AnnouncementCreateDrawer({
  open,
  data,
  runAction,
  onClose
}: {
  open: boolean;
  data: AdminData;
  runAction: ActionRunner;
  onClose: () => void;
}) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scope, setScope] = useState<AnnouncementScope>("league");
  const [leagueId, setLeagueId] = useState("");
  const [hubId, setHubId] = useState("");
  const [teamId, setTeamId] = useState("");
  const [isPinned, setIsPinned] = useState(false);

  useEffect(() => {
    if (open && !leagueId && data.leagues.length === 1) setLeagueId(data.leagues[0].id);
  }, [data.leagues, leagueId, open]);

  function changeScope(nextScope: AnnouncementScope) {
    setScope(nextScope);
    if (nextScope === "league") {
      setHubId("");
      setTeamId("");
    } else if (nextScope === "hub") {
      setTeamId("");
    }
  }

  async function createAnnouncement(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = await runAction("adminCreateAnnouncement", {
      title,
      body,
      scope,
      leagueId,
      hubId: scope === "league" ? null : hubId,
      teamId: scope === "team" ? teamId : null,
      isPinned
    });
    if (!result.ok) return;
    setTitle("");
    setBody("");
    setScope("league");
    setLeagueId(data.leagues.length === 1 ? data.leagues[0].id : "");
    setHubId("");
    setTeamId("");
    setIsPinned(false);
    onClose();
  }

  return (
    <SideDrawer open={open} title="New Announcement" description="Post an announcement to a league, hub, or team." icon={Megaphone} onClose={onClose}>
      <form className="grid gap-4" onSubmit={createAnnouncement}>
        <Field label="Title"><Input value={title} onChange={(event) => setTitle(event.target.value)} required /></Field>
        <Field label="Body"><Textarea value={body} onChange={(event) => setBody(event.target.value)} required /></Field>
        <AnnouncementTargetFields
          data={data}
          scope={scope}
          leagueId={leagueId}
          hubId={hubId}
          teamId={teamId}
          onScopeChange={changeScope}
          onLeagueChange={(nextLeagueId) => { setLeagueId(nextLeagueId); setHubId(""); setTeamId(""); }}
          onHubChange={(nextHubId) => { setHubId(nextHubId); setTeamId(""); }}
          onTeamChange={setTeamId}
        />
        <label className="flex min-h-12 cursor-pointer items-center justify-between gap-3 rounded-xl border border-line bg-white px-3.5 text-sm font-semibold hover:border-[#b8c4d2]">
          <span className="inline-flex items-center gap-2">{isPinned ? <Pin className="size-4 text-amber" aria-hidden /> : <PinOff className="size-4 text-muted" aria-hidden />}Pinned</span>
          <input className="size-4 accent-teal" type="checkbox" checked={isPinned} onChange={(event) => setIsPinned(event.target.checked)} />
        </label>
        <Button type="submit"><Megaphone className="size-4" aria-hidden />Post Announcement</Button>
      </form>
    </SideDrawer>
  );
}

function AnnouncementDrawer({
  announcement,
  data,
  onClose,
  runAction
}: {
  announcement: Announcement | null;
  data: AdminData;
  onClose: () => void;
  runAction: ActionRunner;
}) {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scope, setScope] = useState<AnnouncementScope>("league");
  const [leagueId, setLeagueId] = useState("");
  const [hubId, setHubId] = useState("");
  const [teamId, setTeamId] = useState("");
  const [isPinned, setIsPinned] = useState(false);

  useEffect(() => {
    if (!announcement) return;
    setTitle(announcement.title);
    setBody(announcement.body);
    setScope(announcement.scope);
    setLeagueId(announcement.leagueId ?? "");
    setHubId(announcement.hubId ?? "");
    setTeamId(announcement.teamId ?? "");
    setIsPinned(announcement.isPinned);
  }, [announcement]);

  function changeScope(nextScope: AnnouncementScope) {
    setScope(nextScope);
    if (nextScope === "league") {
      setHubId("");
      setTeamId("");
    } else if (nextScope === "hub") {
      setTeamId("");
    }
  }

  async function save() {
    if (!announcement) return;
    await runAction("adminUpdateAnnouncement", {
      announcementId: announcement.id,
      patch: {
        title,
        body,
        scope,
        leagueId,
        hubId: scope === "league" ? null : hubId,
        teamId: scope === "team" ? teamId : null,
        isPinned
      }
    });
  }

  async function remove() {
    if (!announcement) return;
    const result = await runAction("adminDeleteAnnouncement", { announcementId: announcement.id });
    if (result.ok) onClose();
  }

  return (
    <SideDrawer
      open={Boolean(announcement)}
      title={announcement?.title ?? "Announcement"}
      description={announcement ? <>{announcement.scope} · <RelativeTime value={announcement.createdAt} /></> : undefined}
      icon={Megaphone}
      onClose={onClose}
      footer={
        <DrawerEditActions
          entityKey={announcement?.id ?? "announcement"}
          entityLabel="announcement"
          onSave={save}
          onDelete={remove}
        />
      }
    >
      {announcement && (
        <>
          <DrawerSection title="Content">
            <Field label="Title"><Input value={title} onChange={(event) => setTitle(event.target.value)} /></Field>
            <Field label="Body"><Textarea value={body} onChange={(event) => setBody(event.target.value)} /></Field>
            <AnnouncementTargetFields
              data={data}
              scope={scope}
              leagueId={leagueId}
              hubId={hubId}
              teamId={teamId}
              onScopeChange={changeScope}
              onLeagueChange={(nextLeagueId) => { setLeagueId(nextLeagueId); setHubId(""); setTeamId(""); }}
              onHubChange={(nextHubId) => { setHubId(nextHubId); setTeamId(""); }}
              onTeamChange={setTeamId}
            />
            <label className="flex min-h-12 cursor-pointer items-center justify-between gap-3 rounded-xl border border-line bg-white px-3.5 text-sm font-semibold hover:border-[#b8c4d2]">
              <span className="inline-flex items-center gap-2">{isPinned ? <Pin className="size-4 text-amber" aria-hidden /> : <PinOff className="size-4 text-muted" aria-hidden />}Pinned</span>
              <input className="size-4 accent-teal" type="checkbox" checked={isPinned} onChange={(event) => setIsPinned(event.target.checked)} />
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

function AnnouncementTargetFields({
  data,
  scope,
  leagueId,
  hubId,
  teamId,
  onScopeChange,
  onLeagueChange,
  onHubChange,
  onTeamChange
}: {
  data: AdminData;
  scope: AnnouncementScope;
  leagueId: string;
  hubId: string;
  teamId: string;
  onScopeChange: (scope: AnnouncementScope) => void;
  onLeagueChange: (leagueId: string) => void;
  onHubChange: (hubId: string) => void;
  onTeamChange: (teamId: string) => void;
}) {
  const availableHubs = data.hubs.filter((hub) => hub.leagueId === leagueId);
  const availableTeams = data.teams.filter((team) => team.hubId === hubId);

  return (
    <>
      <Field label="Scope">
        <Select value={scope} onChange={(event) => onScopeChange(event.target.value as AnnouncementScope)} required>
          <option value="league">League</option>
          <option value="hub">Hub</option>
          <option value="team">Team</option>
        </Select>
      </Field>
      <Field label="League">
        <Select value={leagueId} onChange={(event) => onLeagueChange(event.target.value)} required>
          <option value="">Select a league</option>
          {data.leagues.map((league) => <option key={league.id} value={league.id}>{league.name}</option>)}
        </Select>
      </Field>
      {(scope === "hub" || scope === "team") && (
        <Field label="Hub">
          <Select value={hubId} onChange={(event) => onHubChange(event.target.value)} required>
            <option value="">Select a hub</option>
            {availableHubs.map((hub) => <option key={hub.id} value={hub.id}>{hub.name}</option>)}
          </Select>
        </Field>
      )}
      {scope === "team" && (
        <Field label="Team">
          <Select value={teamId} onChange={(event) => onTeamChange(event.target.value)} required>
            <option value="">Select a team</option>
            {availableTeams.map((team) => <option key={team.id} value={team.id}>{team.name}</option>)}
          </Select>
        </Field>
      )}
    </>
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
  const filters: Array<WorkspaceFilterItem<PolicyView>> = [
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
      <ManagementWorkspace
        eyebrow="Document library"
        title={`Policies for ${data.selectedOrg?.name ?? "League Hub"}`}
        description="Browse policies as a document library with category, scope, file details, and version history visible before opening a record."
        icon={FileText}
        metrics={[
          { label: "Documents", value: data.policies.length },
          { label: "Categories", value: new Set(data.policies.map((policy) => policy.category.toLowerCase())).size },
          { label: "Previous versions", value: data.policies.reduce((total, policy) => total + policy.versions.length, 0) },
          { label: "Scoped", value: data.policies.filter((policy) => Boolean(policy.leagueId || policy.hubId || policy.teamId)).length }
        ]}
        action={<ToolbarActionButton icon={UploadCloud} onClick={() => setCreateOpen(true)}>New Policy</ToolbarActionButton>}
        filters={filters}
        selectedFilterId={view}
        onSelectFilter={(nextView) => {
          setView(nextView);
          setQuery("");
        }}
        panelTitle={panelCopy[view].title}
        panelDescription={panelCopy[view].description}
        searchLabel="Search policies..."
        searchValue={query}
        onSearchChange={setQuery}
      >
        <div className="mb-3 flex items-center justify-between gap-3">
          <p className="text-sm font-extrabold text-ink">{pluralize(filteredPolicies.length, "policy", "policies")}</p>
          <p className="hidden text-xs font-semibold text-muted sm:block">Select a document to manage its file or version history</p>
        </div>
        {filteredPolicies.length > 0 ? (
          <div className="grid gap-3 xl:grid-cols-2">
            {filteredPolicies.map((policy) => {
              const scope = policy.teamId ? "Team scoped" : policy.hubId ? "Hub scoped" : policy.leagueId ? "League scoped" : "Organization wide";
              const fileType = policy.fileType.split("/").pop()?.toUpperCase() || "FILE";
              return (
                <button
                  key={policy.id}
                  type="button"
                  aria-label={`Open ${policy.name} policy`}
                  onClick={() => setSelectedPolicyId(policy.id)}
                  className={`group min-w-0 rounded-2xl border p-4 text-left transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-px hover:border-[#b8c4d2] hover:shadow-soft focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 sm:p-5 ${selectedPolicy?.id === policy.id ? "border-teal/40 bg-teal/[0.035]" : "border-line bg-[#fcfdff]"}`}
                >
                  <span className="flex min-w-0 items-start gap-3.5">
                    <span className="grid size-12 shrink-0 place-items-center rounded-2xl bg-teal/10 text-teal ring-1 ring-teal/10"><FileText className="size-5" aria-hidden /></span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-start justify-between gap-3">
                        <span className="min-w-0">
                          <span className="block truncate text-base font-extrabold text-ink group-hover:text-teal sm:text-lg">{policy.name}</span>
                          <span className="mt-1 block truncate text-sm font-medium text-muted">Uploaded by {policy.uploadedByName}</span>
                        </span>
                        <ChevronRight className="mt-1 size-4 shrink-0 text-muted transition-transform group-hover:translate-x-0.5" aria-hidden />
                      </span>
                      <span className="mt-3 flex flex-wrap gap-2"><Badge tone="neutral">{policy.category}</Badge><Badge tone={scope === "Organization wide" ? "info" : "neutral"}>{scope}</Badge></span>
                    </span>
                  </span>
                  <span className="mt-4 grid grid-cols-3 gap-2 border-t border-line/70 pt-4">
                    <span><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">File</span><span className="mt-1 block truncate text-xs font-bold text-ink">{fileType} · {bytesLabel(policy.fileSize)}</span></span>
                    <span><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">History</span><span className="mt-1 block text-xs font-bold text-ink">{pluralize(policy.versions.length, "version")}</span></span>
                    <span><span className="block text-[10px] font-extrabold uppercase tracking-[0.08em] text-muted">Updated</span><span className="mt-1 block text-xs font-bold text-ink"><RelativeTime value={policy.updatedAt} /></span></span>
                  </span>
                </button>
              );
            })}
          </div>
        ) : (
          <WorkspaceEmptyState icon={FolderOpen} title="No policies found" description="No policies match the current filter and search." />
        )}
      </ManagementWorkspace>
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
  const [policyCategory, setPolicyCategory] = useState<string>(POLICY_CATEGORIES[0]);
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
      setPolicyCategory(POLICY_CATEGORIES[0]);
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
        <Field label="Category">
          <Select value={policyCategory} onChange={(event) => setPolicyCategory(event.target.value)} required>
            {POLICY_CATEGORIES.map((category) => <option key={category} value={category}>{category}</option>)}
          </Select>
        </Field>
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
        className="grid min-h-36 cursor-pointer place-items-center rounded-2xl border border-dashed border-line bg-white px-4 py-5 text-center transition-colors hover:border-teal hover:bg-teal/[0.035] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
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
          <span className="text-sm font-extrabold text-ink">Drop a policy file here or browse</span>
          <span className="text-xs font-semibold text-muted">Up to {bytesLabel(POLICY_FILE_MAX_BYTES)}</span>
        </span>
      </label>
      {file && (
        <div className="flex min-h-12 items-center justify-between gap-3 rounded-xl border border-line bg-shell px-3.5">
          <div className="min-w-0">
            <p className="truncate text-sm font-bold text-ink">{file.name}</p>
            <p className="text-xs font-semibold text-muted">{file.type || "File"} · {bytesLabel(file.size)}</p>
          </div>
          <button
            type="button"
            aria-label="Remove selected policy file"
            className="grid size-9 shrink-0 cursor-pointer place-items-center rounded-xl text-muted transition-colors hover:bg-white hover:text-ink focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
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
            className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-line bg-white px-4 py-2 text-sm font-bold text-ink shadow-sm transition-colors hover:border-[#b8c4d2] hover:bg-shell focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
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
                <div key={`${policy.id}-${index}`} className="rounded-xl border border-line/80 bg-white px-3.5 py-3 shadow-sm">
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
      <h2 className="text-base font-extrabold tracking-[-0.01em] text-ink">{title}</h2>
    </div>
  );
}

function HealthGrid({ checks }: { checks: HealthCheck[] }) {
  return (
    <div className="mt-5 grid gap-3 sm:grid-cols-2">
      {checks.map((check) => {
        const StatusIcon = check.severity === "good" ? CheckCircle2 : ShieldAlert;
        return (
          <div key={check.id} className="rounded-2xl border border-line/80 bg-[#fbfcfd] p-3.5">
            <div className="flex items-center justify-between gap-3">
              <div className="flex min-w-0 items-center gap-2.5">
                <span className={`grid size-8 shrink-0 place-items-center rounded-xl ${check.severity === "good" ? "bg-mint/10 text-mint" : check.severity === "danger" ? "bg-coral/10 text-coral" : "bg-amber/10 text-amber"}`}>
                  <StatusIcon className="size-4" aria-hidden />
                </span>
                <span className="truncate text-sm font-bold text-ink">{check.label}</span>
              </div>
              <Badge tone={check.severity === "good" ? "good" : check.severity === "danger" ? "danger" : "warning"}>
                {check.severity[0].toUpperCase()}{check.severity.slice(1)}
              </Badge>
            </div>
            <p className="mt-3 pl-[42px] text-xs font-semibold text-muted">{check.value}</p>
          </div>
        );
      })}
    </div>
  );
}

function EmptyLine({ label }: { label: string }) {
  return <div className="rounded-xl border border-dashed border-line bg-[#fbfcfd] px-3 py-6 text-center text-sm font-semibold text-muted">{label}</div>;
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
    <fieldset className="rounded-xl border border-line p-3.5">
      <legend className="px-1 text-sm font-bold text-ink">{label}</legend>
      <div className="thin-scrollbar grid max-h-48 gap-1.5 overflow-auto pt-2">
        {options.map((option) => {
          const checked = values.includes(option.id);
          return (
            <label key={option.id} className="flex min-h-10 cursor-pointer items-center gap-2.5 rounded-lg px-2 text-sm font-semibold text-muted hover:bg-shell hover:text-ink">
              <input
                type="checkbox"
                className="size-4 accent-teal"
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
