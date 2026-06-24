export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-background text-foreground">
      <div className="text-6xl">🛺</div>
      <h1 className="text-2xl font-semibold">Page not found / पेज नहीं मिला</h1>
      <p className="text-muted-foreground">
        The page you are looking for does not exist.
      </p>
      <a
        href="/"
        className="rounded-md bg-primary px-4 py-2 text-primary-foreground hover:opacity-90"
      >
        Go home / होम पेज
      </a>
    </div>
  );
}
