import type { ReactNode } from "react";
import { NavLink } from "react-router-dom";
import { usePermissions } from "../auth/permissions";
import { useAuth } from "../auth/useAuth";
import { cn } from "../lib/cn";
import { NAV_ITEMS, type NavIcon, type NavItem } from "./nav";
import { usePendingRequests } from "./usePendingRequests";

const FOCUS = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent";
const ITEM = "flex shrink-0 items-center justify-between gap-3 rounded-[10px] px-3.5 py-[11px] text-sm";

function Icon({ name }: { name: NavIcon }) {
  const paths: Record<NavIcon, ReactNode> = {
    overview: (
      <>
        <rect x="3" y="3" width="7" height="9" rx="1.5" />
        <rect x="14" y="3" width="7" height="5" rx="1.5" />
        <rect x="14" y="12" width="7" height="9" rx="1.5" />
        <rect x="3" y="16" width="7" height="5" rx="1.5" />
      </>
    ),
    requests: (
      <>
        <path d="M3 7l9-4 9 4-9 4-9-4z" />
        <path d="M3 7v10l9 4 9-4V7" />
      </>
    ),
    accounts: (
      <>
        <circle cx="9" cy="8" r="3.5" />
        <path d="M2.5 20c0-3.6 2.9-6.5 6.5-6.5s6.5 2.9 6.5 6.5" />
        <circle cx="18" cy="8.5" r="2.6" />
        <path d="M15.8 13.8c2.9.4 5.2 2.9 5.2 6.2" />
      </>
    ),
    referentials: (
      <>
        <path d="M4 6h16M4 12h16M4 18h10" />
        <circle cx="19" cy="18" r="2" />
      </>
    ),
    settings: (
      <>
        <path d="M4 8h10M18 8h2M4 16h2M10 16h10" />
        <circle cx="16" cy="8" r="2" />
        <circle cx="8" cy="16" r="2" />
      </>
    ),
    admins: (
      <>
        <path d="M12 3l8 3v6c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6l8-3z" />
        <path d="M9 12l2 2 4-4" />
      </>
    ),
    moderation: (
      <>
        <path d="M5 21V4" />
        <path d="M5 4h12l-2 4 2 4H5" />
      </>
    ),
    audit: (
      <>
        <path d="M6 3h9l4 4v14H6z" />
        <path d="M14 3v5h5M9 13h7M9 17h7" />
      </>
    ),
    searches: (
      <>
        <circle cx="11" cy="11" r="6.5" />
        <path d="M16 16l5 5" />
      </>
    ),
    calls: <path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z" />,
    trends: <path d="M3 17l6-6 4 4 8-8M15 7h6v6" />,
    team: <path d="M12 2l2.6 6.6L21 9l-5 4.6L17.4 21 12 17.3 6.6 21 8 13.6 3 9l6.4-.4z" />,
  };
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
      {paths[name]}
    </svg>
  );
}

function Entry({ item, pending }: { item: NavItem; pending: number | null }) {
  const content = (
    <>
      <span className="flex items-center gap-3 whitespace-nowrap">
        <Icon name={item.icon} />
        {item.label}
      </span>
      {item.badge && pending !== null && pending > 0 && (
        <span
          aria-label={`${pending} en attente`}
          className="rounded-full bg-danger-bg px-[7px] py-0.5 text-[11px] font-extrabold text-danger"
        >
          {pending}
        </span>
      )}
      {item.soon && <span className="rounded-full border border-line px-2 py-0.5 text-[10.5px] font-semibold">bientôt</span>}
    </>
  );
  if (item.soon) {
    return (
      <span aria-disabled="true" className={cn(ITEM, "cursor-not-allowed font-semibold text-ink-3 opacity-80")}>
        {content}
      </span>
    );
  }
  return (
    <NavLink
      to={item.to}
      end={item.to === "/"}
      className={({ isActive }) =>
        cn(ITEM, FOCUS, isActive ? "bg-accent font-bold text-on-accent" : "font-semibold text-ink-2 hover:bg-card")
      }
    >
      {content}
    </NavLink>
  );
}

function initials(name: string): string {
  const letters = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join("");
  return letters || "AD";
}

export function Sidebar() {
  const { me, logout } = useAuth();
  const { can } = usePermissions();
  const pending = usePendingRequests();
  const items = NAV_ITEMS.filter((i) => can(i.permission));

  return (
    <aside
      aria-label="Menu principal"
      className="flex shrink-0 flex-col gap-1 border-b border-line bg-sidebar p-3 min-[900px]:w-60 min-[900px]:border-b-0 min-[900px]:border-r min-[900px]:py-6 min-[900px]:px-0"
    >
      <div className="px-3 pb-1 text-[19px] font-extrabold tracking-[0.5px] min-[900px]:px-6 min-[900px]:pb-7">
        <span>NET</span>
        <span className="text-accent-ink">BUIS</span>
        <span className="ml-1.5 text-xs font-semibold text-ink-3">Admin</span>
      </div>
      <nav aria-label="Sections" className="flex flex-row gap-1 overflow-x-auto min-[900px]:flex-col min-[900px]:px-3">
        {items.map((item) => (
          <Entry key={item.key} item={item} pending={pending} />
        ))}
      </nav>
      <div className="min-[900px]:flex-1" />
      <div className="flex items-center gap-2.5 border-t border-line px-3.5 pt-4 min-[900px]:mx-3">
        <div
          aria-hidden="true"
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-line bg-card text-xs font-extrabold text-accent-ink"
        >
          {initials(me?.name ?? "")}
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-[12.5px] font-bold" data-testid="admin-name">
            {me?.name ?? ""}
          </div>
          <button
            type="button"
            onClick={() => void logout()}
            className={cn("cursor-pointer rounded border-0 bg-transparent p-0 text-[11px] text-ink-3 hover:underline", FOCUS)}
          >
            Déconnexion
          </button>
        </div>
      </div>
    </aside>
  );
}
