import Image from "next/image";
import {
  ArrowRight,
  BellRing,
  CalendarDays,
  Check,
  ChevronRight,
  ClipboardCheck,
  Cloud,
  LockKeyhole,
  MessageCircleMore,
  ShieldCheck,
  Sparkles,
  UsersRound,
} from "lucide-react";
import { ContactForm } from "@/components/contact-form";

const features = [
  {
    icon: CalendarDays,
    title: "Schedules that stay current",
    body: "Give every team one clean view of upcoming games, results, times, venues, and team details.",
    className: "feature-card feature-schedule",
  },
  {
    icon: MessageCircleMore,
    title: "Communication without the clutter",
    body: "Keep chats and pinned announcements together, so important updates don't disappear in the noise.",
    className: "feature-card feature-chat",
  },
  {
    icon: ClipboardCheck,
    title: "Policies where people need them",
    body: "Publish policies, forms, and league resources directly to the right leagues, hubs, or teams.",
    className: "feature-card feature-policy",
  },
  {
    icon: UsersRound,
    title: "People and roles, connected",
    body: "Make contacts, assignments, and access clear from the league office all the way to each team.",
    className: "feature-card feature-people",
  },
];

const included = [
  "Branded iOS and Android experience",
  "League schedules and results",
  "Chats and pinned announcements",
  "Policies, forms, and contacts",
  "Role-based league, hub, and team access",
  "Admin workspace and guided rollout",
];

const faqs = [
  {
    question: "Is League Hub only for hockey?",
    answer:
      "No. League Hub is built around the way leagues, regions, clubs, and teams operate, so it can support different sports and organization structures.",
  },
  {
    question: "Can League Hub use our existing schedule data?",
    answer:
      "Yes. We can connect supported public schedule sources and keep the experience native inside the app rather than sending members to another website.",
  },
  {
    question: "Who can see and manage content?",
    answer:
      "Access follows clear Platform Owner, Admin, Manager, and Staff roles, with Managers limited to their assigned leagues, hubs, and teams.",
  },
  {
    question: "How does pricing work?",
    answer:
      "Pricing is tailored to your organization size, rollout needs, and integrations. Tell us roughly how many teams you support and we'll provide a clear quote.",
  },
];

export default function Home() {
  return (
    <main>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="League Hub home">
          <span className="brand-mark" aria-hidden="true">
            <Image src="/league-hub-icon.png" width={42} height={42} alt="" priority />
          </span>
          <span>League Hub</span>
        </a>
        <nav aria-label="Primary navigation">
          <a href="#features">Features</a>
          <a href="#how-it-works">How it works</a>
          <a href="#pricing">Pricing</a>
        </nav>
        <a className="button button-nav" href="#contact">
          Talk to us <ArrowRight size={16} aria-hidden="true" />
        </a>
      </header>

      <section className="hero" id="top">
        <div className="hero-glow hero-glow-one" aria-hidden="true" />
        <div className="hero-glow hero-glow-two" aria-hidden="true" />
        <div className="hero-copy">
          <div className="hero-kicker">
            <Sparkles size={16} aria-hidden="true" /> Built for modern sports organizations
          </div>
          <h1>
            Your entire league.
            <span>One trusted place.</span>
          </h1>
          <p className="hero-lead">
            Bring schedules, chats, announcements, policies, and contacts into one clean app your whole organization can rely on.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="#contact">
              Get pricing <ArrowRight size={18} aria-hidden="true" />
            </a>
            <a className="button button-secondary" href="#features">
              Explore the platform
            </a>
          </div>
          <div className="hero-proof" aria-label="League Hub core capabilities">
            <span><Check size={15} aria-hidden="true" /> Native mobile experience</span>
            <span><Check size={15} aria-hidden="true" /> Role-based access</span>
            <span><Check size={15} aria-hidden="true" /> Guided rollout</span>
          </div>
        </div>

        <div className="hero-visual" aria-label="League Hub mobile app preview">
          <div className="orbit orbit-one" aria-hidden="true" />
          <div className="orbit orbit-two" aria-hidden="true" />
          <div className="phone-shell">
            <div className="phone-screen">
              <div className="phone-status"><span>9:41</span><span>● ● ▰</span></div>
              <div className="phone-welcome">
                <span>Good evening</span>
                <div className="mini-avatar">LH</div>
              </div>
              <div className="profile-card">
                <Image src="/profile-hockey-arena.jpg" fill sizes="350px" alt="" priority />
                <div className="profile-card-content">
                  <div className="profile-avatar">JD</div>
                  <div><strong>Jordan Davis</strong><span>League Manager</span></div>
                  <ChevronRight size={20} aria-hidden="true" />
                </div>
              </div>
              <div className="next-game-card">
                <Image src="/upcoming-games-active.jpg" fill sizes="350px" alt="" priority />
                <div className="next-game-content">
                  <div className="next-game-title"><CalendarDays size={17} /><strong>Next Game</strong><ArrowRight size={17} /></div>
                  <div className="game-time">Sat, Oct 17 · 6:30 PM</div>
                  <div className="matchup"><span className="team-dot team-dot-blue">N</span><strong>North Stars</strong></div>
                  <div className="matchup"><span className="team-dot team-dot-red">W</span><strong>West Wolves</strong></div>
                  <div className="game-location">U15 AAA · Community Arena</div>
                </div>
              </div>
              <p className="quick-title">Quick Access</p>
              <div className="quick-grid">
                <div><MessageCircleMore size={20} /><strong>Chats</strong><span>Updates & announcements</span></div>
                <div><Cloud size={20} /><strong>Weather</strong><span>12° · Clear</span></div>
                <div><ClipboardCheck size={20} /><strong>Policies</strong><span>Files & rules</span></div>
                <div><UsersRound size={20} /><strong>Contacts</strong><span>People & roles</span></div>
              </div>
            </div>
          </div>
          <div className="floating-note note-schedule">
            <CalendarDays size={18} aria-hidden="true" />
            <span><strong>Schedule updated</strong><small>Everyone sees the latest</small></span>
          </div>
          <div className="floating-note note-security">
            <ShieldCheck size={18} aria-hidden="true" />
            <span><strong>Right people. Right access.</strong><small>Role-based by design</small></span>
          </div>
        </div>
      </section>

      <section className="value-strip" aria-label="League Hub value statement">
        <p>From the league office to game day</p>
        <span />
        <strong>Everyone stays on the same page.</strong>
      </section>

      <section className="section features-section" id="features">
        <div className="section-heading">
          <p className="eyebrow">Everything connected</p>
          <h2>Less searching. Less repeating. More time for the game.</h2>
          <p>
            League Hub turns the information already moving through your organization into one dependable member experience.
          </p>
        </div>
        <div className="feature-grid">
          {features.map(({ icon: Icon, title, body, className }) => (
            <article className={className} key={title}>
              <span className="feature-icon"><Icon size={23} aria-hidden="true" /></span>
              <h3>{title}</h3>
              <p>{body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="section workflow-section" id="how-it-works">
        <div className="workflow-copy">
          <p className="eyebrow eyebrow-light">One platform, two focused experiences</p>
          <h2>Simple for members. Powerful for administrators.</h2>
          <p>
            Your members get a calm, useful mobile app. Your league office gets the structure and control to keep every team informed.
          </p>
          <ul className="workflow-list">
            <li><span>01</span><div><strong>Connect your structure</strong><p>Set up leagues, hubs, teams, people, and roles.</p></div></li>
            <li><span>02</span><div><strong>Bring in your information</strong><p>Connect schedules and publish the resources members need.</p></div></li>
            <li><span>03</span><div><strong>Launch with confidence</strong><p>Roll out one branded, dependable home for your organization.</p></div></li>
          </ul>
        </div>
        <div className="admin-preview" role="img" aria-label="League Hub admin workspace preview">
          <div aria-hidden="true">
            <div className="admin-topbar"><span className="admin-brand-dot" /><strong>League Hub Admin</strong><span>Structure</span><span>People</span><span>Schedule</span></div>
            <div className="admin-body">
            <div className="admin-sidebar">
              <span className="active" /><span /><span /><span /><span />
            </div>
            <div className="admin-content">
              <div className="admin-content-heading"><div><small>ORGANIZATION</small><strong>League structure</strong></div><span className="admin-add">+ Add</span></div>
              <div className="structure-card structure-league"><span>L</span><div><small>LEAGUE</small><strong>Premier Hockey League</strong></div><b>18 hubs</b></div>
              <div className="structure-line" />
              <div className="structure-row">
                <div className="structure-card"><span>N</span><div><small>HUB</small><strong>North Region</strong></div><b>12 teams</b></div>
                <div className="structure-card"><span>S</span><div><small>HUB</small><strong>South Region</strong></div><b>14 teams</b></div>
              </div>
              <div className="people-pills"><span>JD</span><span>KM</span><span>AR</span><span>+84 connected people</span></div>
            </div>
          </div>
          </div>
        </div>
      </section>

      <section className="section pricing-section" id="pricing">
        <div className="pricing-copy">
          <p className="eyebrow">Straightforward, organization-based pricing</p>
          <h2>A rollout that fits your league—not the other way around.</h2>
          <p>
            Pricing reflects your number of teams, integrations, and rollout needs. We'll give you a clear quote with the platform and support included.
          </p>
          <div className="pricing-note">
            <LockKeyhole size={19} aria-hidden="true" />
            <span><strong>No surprise add-ons.</strong> We scope the implementation with you before launch.</span>
          </div>
        </div>
        <article className="pricing-card">
          <div className="pricing-card-top">
            <div><p>League Hub</p><h3>Built around your organization</h3></div>
            <span>Custom quote</span>
          </div>
          <ul>
            {included.map((item) => <li key={item}><Check size={17} aria-hidden="true" />{item}</li>)}
          </ul>
          <a className="button button-primary button-full" href="#contact">
            Get your pricing <ArrowRight size={18} aria-hidden="true" />
          </a>
        </article>
      </section>

      <section className="section contact-section" id="contact">
        <div className="contact-copy">
          <p className="eyebrow eyebrow-light">Let's talk</p>
          <h2>See what League Hub could look like for your organization.</h2>
          <p>
            Tell us a little about your league. You'll hear directly from Jonah—not an automated sales queue.
          </p>
          <div className="contact-details">
            <div><BellRing size={19} aria-hidden="true" /><span><strong>Personal response</strong><small>Usually within one business day</small></span></div>
            <div><ShieldCheck size={19} aria-hidden="true" /><span><strong>No-pressure conversation</strong><small>Clear answers about fit, rollout, and cost</small></span></div>
          </div>
          <a href="mailto:jonah@jdbuilds.ca">jonah@jdbuilds.ca</a>
        </div>
        <ContactForm />
      </section>

      <section className="section faq-section">
        <div className="section-heading faq-heading">
          <p className="eyebrow">Good questions</p>
          <h2>What leagues usually ask first.</h2>
        </div>
        <div className="faq-list">
          {faqs.map(({ question, answer }) => (
            <details key={question}>
              <summary>{question}<span aria-hidden="true">+</span></summary>
              <p>{answer}</p>
            </details>
          ))}
        </div>
      </section>

      <footer>
        <div className="footer-brand">
          <span className="brand-mark"><Image src="/league-hub-icon.png" width={38} height={38} alt="" /></span>
          <div><strong>League Hub</strong><span>Your league, connected.</span></div>
        </div>
        <div className="footer-links">
          <a href="#features">Features</a>
          <a href="#pricing">Pricing</a>
          <a href="#contact">Contact</a>
          <a href="https://admin.leaguehub.ca">Admin sign in</a>
        </div>
        <p>© {new Date().getFullYear()} League Hub. Built by <a href="https://jdbuilds.ca">JD Builds</a>.</p>
      </footer>
    </main>
  );
}
