import { Button } from "./Button";

interface PaginationProps {
  page: number; // 1-indexée
  pageCount: number;
  onPageChange: (page: number) => void;
}

export function Pagination({ page, pageCount, onPageChange }: PaginationProps) {
  if (pageCount <= 1) return null;
  return (
    <nav aria-label="Pagination" className="flex items-center justify-end gap-3 py-3">
      <Button variant="secondary" disabled={page <= 1} onClick={() => onPageChange(page - 1)}>
        Précédent
      </Button>
      <span aria-live="polite" className="text-[12.5px] text-ink-2">
        Page {page} sur {pageCount}
      </span>
      <Button variant="secondary" disabled={page >= pageCount} onClick={() => onPageChange(page + 1)}>
        Suivant
      </Button>
    </nav>
  );
}
