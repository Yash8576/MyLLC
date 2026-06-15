"use client";

import { FormEvent, useEffect, useState } from "react";
import {
  User,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from "firebase/auth";
import { firebaseConfigError, getClientAuth } from "../lib/firebase";

type SavedLink = {
  shortUrl: string;
  longUrl: string;
  code: string;
  createdAt: string;
};

const apiBaseUrl = (
  process.env.NEXT_PUBLIC_NANOLINK_API_BASE_URL ?? "http://localhost:8080"
).replace(/\/$/, "");

const getIdToken = async (user: User) => {
  try {
    return await user.getIdToken();
  } catch {
    return null;
  }
};

export default function Home() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [authOpen, setAuthOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [authMode, setAuthMode] = useState<"login" | "signup">("login");
  const [user, setUser] = useState<User | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [authError, setAuthError] = useState("");
  const [longUrl, setLongUrl] = useState("");
  const [shortUrl, setShortUrl] = useState("");
  const [shortening, setShortening] = useState(false);
  const [shortenError, setShortenError] = useState("");
  const [history, setHistory] = useState<SavedLink[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState("");

  useEffect(() => {
    if (firebaseConfigError) {
      return;
    }

    const auth = getClientAuth();
    return onAuthStateChanged(auth, (nextUser) => {
      setUser(nextUser);
      if (nextUser) {
        setAuthOpen(false);
      } else {
        setHistory([]);
      }
    });
  }, []);

  const fetchHistory = async (currentUser: User) => {
    setHistoryLoading(true);
    setHistoryError("");
    try {
      const token = await getIdToken(currentUser);
      const response = await fetch(`${apiBaseUrl}/api/links`, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      });
      if (!response.ok) {
        throw new Error("Could not load history");
      }
      const data = (await response.json()) as { links: SavedLink[] };
      setHistory(data.links);
    } catch (error) {
      setHistoryError(error instanceof Error ? error.message : "Could not load history");
    } finally {
      setHistoryLoading(false);
    }
  };

  const handleShorten = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setShortenError("");
    setShortUrl("");
    setShortening(true);

    try {
      const token = user ? await getIdToken(user) : null;
      const response = await fetch(`${apiBaseUrl}/api/shorten`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ longUrl }),
      });
      const data = (await response.json()) as {
        shortUrl?: string;
        longUrl?: string;
        code?: string;
        error?: string;
      };

      if (!response.ok || !data.shortUrl || !data.code || !data.longUrl) {
        throw new Error(data.error ?? "Could not shorten URL");
      }

      setShortUrl(data.shortUrl);

      if (user) {
        const newEntry: SavedLink = {
          shortUrl: data.shortUrl,
          longUrl: data.longUrl,
          code: data.code,
          createdAt: new Date().toISOString(),
        };
        setHistory((prev) => [newEntry, ...prev]);
      }
    } catch (error) {
      setShortenError(error instanceof Error ? error.message : "Could not shorten URL");
    } finally {
      setShortening(false);
    }
  };

  const handleAuth = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setAuthError("");

    try {
      const auth = getClientAuth();
      if (authMode === "signup") {
        await createUserWithEmailAndPassword(auth, email, password);
      } else {
        await signInWithEmailAndPassword(auth, email, password);
      }
      setPassword("");
      setEmail("");
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : "Authentication failed");
    }
  };

  const openAuth = (mode: "login" | "signup") => {
    setAuthMode(mode);
    setAuthOpen(true);
    setMenuOpen(false);
  };

  const openHistory = () => {
    setHistoryOpen(true);
    setMenuOpen(false);
    if (user) {
      fetchHistory(user);
    }
  };

  return (
    <main className="page">
      <header className="topbar">
        <div className="topbar-inner">
          <div className="brand">
            <span className="brand-mark">N</span>
            Nanolink
          </div>
          <div className="menu-wrap">
            <button
              aria-label="Open menu"
              aria-expanded={menuOpen ? "true" : "false"}
              className="icon-button hamburger"
              type="button"
              onClick={() => setMenuOpen((open) => !open)}
            >
              <span />
              <span />
              <span />
            </button>
            {menuOpen ? (
              <div className="menu">
                {user ? (
                  <>
                    <button
                      className="menu-item"
                      type="button"
                      onClick={openHistory}
                    >
                      History
                    </button>
                    <button
                      className="menu-item"
                      type="button"
                      onClick={() => {
                        try {
                          const auth = getClientAuth();
                          signOut(auth);
                        } catch (error) {
                          setAuthError(
                            error instanceof Error ? error.message : "Firebase is not configured"
                          );
                        }
                        setMenuOpen(false);
                      }}
                    >
                      Sign out
                    </button>
                  </>
                ) : (
                  <>
                    <button className="menu-item" type="button" onClick={() => openAuth("login")}>
                      Login
                    </button>
                    <button className="menu-item" type="button" onClick={() => openAuth("signup")}>
                      Sign up
                    </button>
                  </>
                )}
              </div>
            ) : null}
          </div>
        </div>
      </header>

      <section className="hero">
        <div className="hero-inner">
          <p className="eyebrow">Nexacore URL shortener</p>
          <h1>Short links that stay clean.</h1>
          <p className="subtitle">
            Paste any long URL and get a compact Nanolink. You can shorten without an
            account; sign in when you want your recent links saved in history.
          </p>

          <form className="shortener" onSubmit={handleShorten}>
            <div className="url-row">
              <input
                className="url-input"
                inputMode="url"
                onChange={(event) => setLongUrl(event.target.value)}
                placeholder="Paste your URL"
                required
                type="url"
                value={longUrl}
              />
              <button className="primary-button" disabled={shortening} type="submit">
                {shortening ? "Shortening..." : "Shorten URL"}
              </button>
            </div>
            {shortenError ? <p className="error">{shortenError}</p> : null}
            {!user ? (
              <p className="hint">Anonymous links work now. Login or sign up to keep history.</p>
            ) : (
              <p className="hint">Signed in as {user.email}. New links will appear in History.</p>
            )}
            {shortUrl ? (
              <div className="result">
                <a href={shortUrl} rel="noreferrer" target="_blank">
                  {shortUrl}
                </a>
                <button
                  className="secondary-button"
                  type="button"
                  onClick={() => navigator.clipboard.writeText(shortUrl)}
                >
                  Copy
                </button>
              </div>
            ) : null}
          </form>
        </div>
      </section>

      {authOpen ? (
        <div className="panel-overlay">
          <aside className="panel" aria-label="Authentication">
            <div className="panel-header">
              <h2>{authMode === "signup" ? "Sign up" : "Login"}</h2>
              <button className="icon-button" type="button" onClick={() => setAuthOpen(false)}>
                X
              </button>
            </div>
            <form className="auth-form" onSubmit={handleAuth}>
              {firebaseConfigError ? <p className="error">{firebaseConfigError}</p> : null}
              <input
                className="auth-input"
                disabled={Boolean(firebaseConfigError)}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="Email"
                required
                type="email"
                value={email}
              />
              <input
                className="auth-input"
                disabled={Boolean(firebaseConfigError)}
                minLength={6}
                onChange={(event) => setPassword(event.target.value)}
                placeholder="Password"
                required
                type="password"
                value={password}
              />
              {authError ? <p className="error">{authError}</p> : null}
              <button className="primary-button" disabled={Boolean(firebaseConfigError)} type="submit">
                {authMode === "signup" ? "Create account" : "Login"}
              </button>
            </form>
            <p className="auth-switch">
              {authMode === "signup" ? "Already have an account? " : "Need an account? "}
              <button
                className="text-button"
                type="button"
                onClick={() => setAuthMode(authMode === "signup" ? "login" : "signup")}
              >
                {authMode === "signup" ? "Login" : "Sign up"}
              </button>
            </p>
          </aside>
        </div>
      ) : null}

      {historyOpen ? (
        <div className="panel-overlay">
          <aside className="panel" aria-label="History">
            <div className="panel-header">
              <h2>History</h2>
              <button className="icon-button" type="button" onClick={() => setHistoryOpen(false)}>
                X
              </button>
            </div>
            <div className="history-list">
              {historyLoading ? (
                <p className="hint">Loading...</p>
              ) : historyError ? (
                <p className="error">{historyError}</p>
              ) : history.length ? (
                history.map((item) => (
                  <article className="history-card" key={`${item.code}-${item.createdAt}`}>
                    <a href={item.shortUrl} rel="noreferrer" target="_blank">
                      {item.shortUrl}
                    </a>
                    <p>{item.longUrl}</p>
                  </article>
                ))
              ) : (
                <p className="hint">No saved links yet.</p>
              )}
            </div>
          </aside>
        </div>
      ) : null}
    </main>
  );
}
