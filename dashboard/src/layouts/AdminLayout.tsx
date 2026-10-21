import { Outlet } from "react-router-dom";
import { Sidebar } from "./Sidebar";
import { Topbar } from "./Topbar";

export function AdminLayout() {
  return (
    <div className="flex min-h-screen flex-col bg-bg text-ink min-[900px]:h-screen min-[900px]:flex-row min-[900px]:overflow-hidden">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col min-[900px]:overflow-hidden">
        <Topbar />
        <main className="flex-1 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
