import { Outlet } from "react-router-dom";
import { CallsOverlay, CallsProvider } from "../modules/team_calls";
import { Sidebar } from "./Sidebar";
import { Topbar } from "./Topbar";

export function AdminLayout() {
  return (
    <CallsProvider>
      <div className="flex min-h-screen flex-col bg-bg text-ink min-[900px]:h-screen min-[900px]:flex-row min-[900px]:overflow-hidden">
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col min-[900px]:overflow-hidden">
          <Topbar />
          <main className="flex-1 overflow-auto">
            <Outlet />
          </main>
        </div>
        <CallsOverlay />
      </div>
    </CallsProvider>
  );
}
