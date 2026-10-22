import { useRef, useState, type FormEvent } from "react";
import { Button, ConfirmDialog, Input, Pagination, useToast } from "../../../components/ui";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";
import { loadError, wordError } from "../errors";
import { useAddWord, useDeleteWord, useForbiddenWords, useRefreshWords } from "../hooks";
import { WORDS_PAGE_SIZE, WORD_MAX, WORD_MIN, type ForbiddenWord } from "../types";

/** Mot nettoyé (espaces) ; message d'erreur si la longueur n'est pas de 2 à 60 caractères. */
export function validateWord(raw: string): { word: string; error?: string } {
  const word = raw.trim();
  if (word.length < WORD_MIN || word.length > WORD_MAX) return { word, error: `Le mot doit faire de ${WORD_MIN} à ${WORD_MAX} caractères.` };
  return { word };
}

/** Mots interdits du filtre anti-spam : liste, ajout, suppression avec confirmation. */
export function ForbiddenWords() {
  const toast = useToast();
  const [page, setPage] = useState(1);
  const query = useForbiddenWords(page);
  const add = useAddWord();
  const del = useDeleteWord();
  const refresh = useRefreshWords();
  const [text, setText] = useState("");
  const [error, setError] = useState<string | undefined>();
  const [toDelete, setToDelete] = useState<ForbiddenWord | null>(null);
  const lockAdd = useRef(false);
  const lockDel = useRef(false);

  const outOfRange = isPageOutOfRange(query.error, page);
  const data = outOfRange ? undefined : query.data;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / WORDS_PAGE_SIZE)) : 1;
  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: WORDS_PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (lockAdd.current) return;
    const v = validateWord(text);
    setError(v.error);
    if (v.error) return;
    lockAdd.current = true;
    add.mutate(v.word, {
      onSettled: () => {
        lockAdd.current = false;
      },
      onSuccess: () => {
        setText("");
        toast.success("Mot ajouté");
      },
      onError: (err) => {
        const w = wordError(err);
        setError(w.message);
        if (w.refresh) void refresh();
      },
    });
  };

  const confirmDelete = () => {
    if (!toDelete || lockDel.current) return;
    lockDel.current = true;
    del.mutate(toDelete.id, {
      onSettled: () => {
        lockDel.current = false;
      },
      onSuccess: () => {
        setToDelete(null);
        toast.success("Mot retiré");
      },
      onError: (err) => {
        const w = wordError(err);
        toast.error(w.message);
        if (w.refresh) {
          setToDelete(null);
          void refresh();
        }
      },
    });
  };

  return (
    <section aria-label="Mots interdits" className="flex flex-col gap-3">
      <h3 className="text-[15px] font-extrabold text-ink">Mots interdits</h3>
      <p className="text-[12.5px] text-ink-2">Un message contenant un de ces mots est retenu par le filtre anti-spam. Les mots sont enregistrés sans accents ni majuscules.</p>
      <form onSubmit={submit} noValidate className="flex flex-wrap items-start gap-3">
        <Input label="Nouveau mot interdit" value={text} error={error} autoComplete="off" onChange={(e) => setText(e.target.value)} />
        <div className="self-end">
          <Button type="submit" loading={add.isPending}>
            Ajouter
          </Button>
        </div>
      </form>

      {query.isError && !data && !outOfRange ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-6 text-center">
          <p className="text-[13px] text-danger">{loadError(query.error, "les mots interdits")}</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      ) : query.isLoading ? (
        <p role="status" className="text-[13px] text-ink-2">
          Chargement…
        </p>
      ) : data && data.results.length === 0 ? (
        <p role="status" className="text-[13px] text-ink-2">
          Aucun mot interdit.
        </p>
      ) : (
        <ul className="flex flex-wrap gap-2">
          {data?.results.map((w) => (
            <li key={w.id} className="flex items-center gap-2 rounded-full border border-line bg-card py-1 pl-3 pr-1.5 text-[12.5px]">
              <span>{w.word}</span>
              <button
                type="button"
                aria-label={`Retirer le mot ${w.word}`}
                onClick={() => setToDelete(w)}
                className="h-6 w-6 cursor-pointer rounded-full border border-danger-bg bg-transparent text-danger"
              >
                ×
              </button>
            </li>
          ))}
        </ul>
      )}
      {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}

      <ConfirmDialog
        open={toDelete !== null}
        title="Retirer ce mot interdit"
        message={toDelete ? `« ${toDelete.word} » ne sera plus filtré.` : undefined}
        confirmLabel="Retirer"
        loading={del.isPending}
        onConfirm={confirmDelete}
        onCancel={() => {
          if (!del.isPending) setToDelete(null);
        }}
      />
    </section>
  );
}
