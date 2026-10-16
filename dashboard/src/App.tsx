// Page d'accueil provisoire : le routage et les layouts arrivent avec les écrans du dashboard.
const mocks = ["true", "1"].includes(import.meta.env.VITE_USE_MOCKS ?? "");

export default function App() {
  return (
    <main className="p-8">
      <h1 className="text-2xl font-semibold">NetBuis — Administration</h1>
      {mocks && <p role="status">Mode simulé : données factices</p>}
    </main>
  );
}
