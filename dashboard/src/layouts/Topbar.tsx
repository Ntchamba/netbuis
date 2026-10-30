import { useLocation } from "react-router-dom";
import { ThemeToggle } from "../components/theme/ThemeToggle";
import { AvailabilityToggle } from "../modules/team_calls";
import { titleFor } from "./nav";

export function Topbar() {
  const { pathname } = useLocation();
  return (
    <header className="flex shrink-0 items-center justify-between border-b border-line px-5 py-[18px] min-[900px]:px-8 min-[900px]:py-[22px]">
      <h2 className="text-[21px] font-extrabold">{titleFor(pathname)}</h2>
      <div className="flex items-center gap-4">
        <AvailabilityToggle />
        <ThemeToggle />
      </div>
    </header>
  );
}
