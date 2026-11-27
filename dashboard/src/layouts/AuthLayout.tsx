import { Outlet } from "react-router-dom";

export function AuthLayout() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-bg p-6 text-ink">
      <div className="w-full max-w-[380px]">
        <div className="mb-6 text-center">
          <p className="text-[22px] font-extrabold tracking-tight">
            NETBUIS <span className="text-accent-ink">Admin</span>
          </p>
        </div>
        <Outlet />
      </div>
    </main>
  );
}
