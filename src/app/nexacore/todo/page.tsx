'use client'
import React, { useState, useEffect, useRef } from "react"
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import './TodoApp.css'
import Login from './Login'
import Signup from './Signup'
import { auth, db } from './firebase'
import { onAuthStateChanged, signOut } from 'firebase/auth'
import {
  collection, doc, setDoc, deleteDoc, updateDoc,
  query, orderBy, onSnapshot, deleteField
} from 'firebase/firestore'

const STATUS_CYCLE: Record<string, string> = {
  todo: 'started',
  started: 'stuck',
  stuck: 'done',
  done: 'todo',
}

const STATUS_LABEL: Record<string, string> = {
  todo: 'To Do',
  started: 'In Progress',
  stuck: 'Blocked',
  done: 'Done',
}

export default function TodoPage() {
  const pathname = usePathname()
  const router = useRouter()
  const isProjectsRoute = pathname?.startsWith('/projects/')
  const backLinkHref = isProjectsRoute ? '/#projects' : '/'

  useEffect(() => {
    if (pathname?.startsWith('/nexacore/')) router.replace('/projects/todo')
  }, [pathname, router])

  const [user, setUser] = useState<{ uid: string; email: string } | null>(null)
  const [isLoginView, setIsLoginView] = useState(true)
  const [todos, setTodos] = useState<any[]>([])
  const [newTodo, setNewTodo] = useState('')
  const [theme, setTheme] = useState('light')
  const [showAccountDropdown, setShowAccountDropdown] = useState(false)
  const [viewFilter, setViewFilter] = useState('active')
  const [showDeleted, setShowDeleted] = useState(false)
  const [isSuccessTransition, setIsSuccessTransition] = useState(false)
  const accountMenuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const saved = localStorage.getItem('todoTheme')
    if (saved) setTheme(saved)
  }, [])

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (u) =>
      setUser(u ? { uid: u.uid, email: u.email ?? '' } : null)
    )
    return unsub
  }, [])

  useEffect(() => {
    if (!user) { setTodos([]); return }
    const q = query(collection(db, 'users', user.uid, 'tasks'), orderBy('timestamp', 'desc'))
    return onSnapshot(q, (snap) =>
      setTodos(snap.docs.map(d => ({ id: d.id, ...d.data() })))
    )
  }, [user])

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (showAccountDropdown && accountMenuRef.current && !accountMenuRef.current.contains(e.target as Node))
        setShowAccountDropdown(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [showAccountDropdown])

  const toggleTheme = () => {
    const next = theme === 'light' ? 'dark' : 'light'
    setTheme(next)
    localStorage.setItem('todoTheme', next)
  }

  const handleAuthSuccess = () => {
    setIsSuccessTransition(true)
    setTimeout(() => { setIsSuccessTransition(false); setIsLoginView(true); setShowAccountDropdown(false) }, 800)
  }

  const handleLogout = async () => {
    await signOut(auth)
    setShowAccountDropdown(false)
  }

  const filteredTodos = todos.filter(t =>
    t.status !== 'deleted' && (viewFilter === 'active' ? !t.completed : t.completed)
  )
  const deletedTodos = todos.filter(t => t.status === 'deleted')

  const addTodo = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user || !newTodo.trim()) return
    const id = Date.now().toString()
    await setDoc(doc(db, 'users', user.uid, 'tasks', id), {
      id, text: newTodo.trim(), completed: false,
      status: 'active', taskStatus: 'todo', timestamp: Date.now(),
    })
    setNewTodo('')
  }

  const cycleStatus = async (id: string, current: string) => {
    if (!user) return
    const next = STATUS_CYCLE[current] ?? 'todo'
    await updateDoc(doc(db, 'users', user.uid, 'tasks', id), {
      taskStatus: next,
      completed: next === 'done',
      status: 'active',
    })
    if (next === 'done') setViewFilter('completed')
    else setViewFilter('active')
  }

  const moveToDeleted = async (id: string, completed: boolean, taskStatus: string) => {
    if (!user) return
    await updateDoc(doc(db, 'users', user.uid, 'tasks', id), {
      status: 'deleted', deletedDate: Date.now(),
      sourceCompleted: completed, sourceTaskStatus: taskStatus,
    })
  }

  const restoreTask = async (id: string, sourceCompleted: boolean, sourceTaskStatus: string) => {
    if (!user) return
    await updateDoc(doc(db, 'users', user.uid, 'tasks', id), {
      status: 'active', deletedDate: null,
      completed: sourceCompleted, taskStatus: sourceTaskStatus,
      sourceCompleted: deleteField(), sourceTaskStatus: deleteField(),
    })
    setViewFilter(sourceCompleted ? 'completed' : 'active')
    setShowDeleted(false)
  }

  const permanentDelete = async (id: string) => {
    if (!user) return
    await deleteDoc(doc(db, 'users', user.uid, 'tasks', id))
  }

  if (pathname?.startsWith('/nexacore/')) return null

  const activeCount = todos.filter(t => !t.completed && t.status !== 'deleted').length
  const doneCount   = todos.filter(t =>  t.completed && t.status !== 'deleted').length

  return (
    <div className={`app-wrapper ${theme}`}>

      {/* ── Header ── */}
      <header className="top-bar">
        <Link href={backLinkHref} className="back-to-nexacore">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5"/><path d="M12 19l-7-7 7-7"/>
          </svg>
          <span className="back-label">{isProjectsRoute ? 'Back to Projects' : 'Back to Nexacore'}</span>
        </Link>

        <h1 className="app-title">Todo Flow</h1>

        <div className="top-actions">
          <button type="button" onClick={toggleTheme} className="theme-toggle-btn" aria-label="Toggle theme">
            {theme === 'light' ? '☾' : '☀︎'}
          </button>
          <div className="account-menu" ref={accountMenuRef}>
            <button type="button" onClick={() => setShowAccountDropdown(p => !p)} className="account-btn">
              {user ? 'Account' : 'Sign in'}
            </button>
            {showAccountDropdown && (
              <div className="account-dropdown">
                {user && !isSuccessTransition ? (
                  <>
                    <p className="user-email">Signed in as<strong>{user.email}</strong></p>
                    <button type="button" onClick={handleLogout} className="logout-btn-dropdown">Sign out</button>
                  </>
                ) : (
                  <div className="auth-box-dropdown">
                    {isLoginView
                      ? <Login switchToSignup={() => setIsLoginView(false)} onAuthSuccess={handleAuthSuccess} />
                      : <Signup switchToLogin={() => setIsLoginView(true)} onAuthSuccess={handleAuthSuccess} />
                    }
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </header>

      {/* ── Body ── */}
      <div className="main-content">
        <div className="content-inner-wrapper">

          {user ? (
            <>
              {/* Add form */}
              <form className="add-todo-form" onSubmit={addTodo}>
                <input
                  type="text"
                  placeholder="What needs to be done?"
                  value={newTodo}
                  onChange={e => setNewTodo(e.target.value)}
                />
                <button type="submit">Add</button>
              </form>

              {/* Filters */}
              <div className="view-filters">
                <button
                  type="button"
                  className={viewFilter === 'active' && !showDeleted ? 'active-filter' : ''}
                  onClick={() => { setViewFilter('active'); setShowDeleted(false) }}
                >
                  Active{activeCount > 0 ? ` ${activeCount}` : ''}
                </button>
                <button
                  type="button"
                  className={viewFilter === 'completed' && !showDeleted ? 'active-filter' : ''}
                  onClick={() => { setViewFilter('completed'); setShowDeleted(false) }}
                >
                  Done{doneCount > 0 ? ` ${doneCount}` : ''}
                </button>
                <button
                  type="button"
                  className={`deleted-filter${showDeleted ? ' active-filter' : ''}`}
                  onClick={() => setShowDeleted(p => !p)}
                >
                  Deleted{deletedTodos.length > 0 ? ` ${deletedTodos.length}` : ''}
                </button>
              </div>

              {/* List */}
              {showDeleted ? (
                <>
                  <p className="todo-list-header">Recently Deleted</p>
                  <div className="todo-list">
                    {deletedTodos.length === 0
                      ? <p className="no-tasks">No deleted tasks.</p>
                      : deletedTodos.map(todo => (
                        <div key={todo.id} className="todo-item">
                          <span className="todo-item-text deleted-text">
                            {todo.text}
                            <span className="deleted-source-tag">({todo.sourceTaskStatus || 'todo'})</span>
                          </span>
                          <button type="button" className="restore-btn" onClick={() => restoreTask(todo.id, todo.sourceCompleted, todo.sourceTaskStatus || 'todo')}>
                            Restore
                          </button>
                          <button type="button" className="delete-btn" onClick={() => permanentDelete(todo.id)} aria-label="Delete permanently">
                            &times;
                          </button>
                        </div>
                      ))
                    }
                  </div>
                </>
              ) : (
                <>
                  <p className="todo-list-header">
                    {viewFilter === 'active' ? 'Active Tasks' : 'Completed Tasks'}
                  </p>
                  <div className="todo-list">
                    {filteredTodos.length === 0
                      ? <p className="no-tasks">{viewFilter === 'active' ? 'All clear — nothing active.' : 'No completed tasks yet.'}</p>
                      : filteredTodos.map(todo => (
                        <div key={todo.id} className="todo-item">
                          <button
                            type="button"
                            className={`status-badge status-${todo.taskStatus}`}
                            onClick={() => cycleStatus(todo.id, todo.taskStatus)}
                            title="Click to advance status"
                          >
                            {STATUS_LABEL[todo.taskStatus] ?? todo.taskStatus}
                          </button>
                          <span className={`todo-item-text${todo.completed ? ' completed' : ''}`}>
                            {todo.text}
                          </span>
                          <button type="button" className="delete-btn" onClick={() => moveToDeleted(todo.id, todo.completed, todo.taskStatus)} aria-label="Remove task">
                            &times;
                          </button>
                        </div>
                      ))
                    }
                  </div>
                </>
              )}
            </>
          ) : (
            <div className="auth-view-wrapper">
              <div className="auth-inline-card">
                {isLoginView
                  ? <Login switchToSignup={() => setIsLoginView(false)} onAuthSuccess={handleAuthSuccess} />
                  : <Signup switchToLogin={() => setIsLoginView(true)} onAuthSuccess={handleAuthSuccess} />
                }
              </div>
            </div>
          )}

        </div>
      </div>

      <style jsx global>{`
        .back-to-nexacore {
          display: inline-flex;
          align-items: center;
          gap: 0.4rem;
          color: #5000ca;
          text-decoration: none;
          padding: 0.5rem 1rem;
          border-radius: 0.5rem;
          background: rgba(80, 0, 202, 0.1);
          font-size: 0.875rem;
          font-weight: 500;
          transition: background 0.2s ease, transform 0.2s ease;
        }
        .back-to-nexacore:hover {
          background: rgba(80, 0, 202, 0.18);
          transform: translateX(-2px);
        }
        .app-wrapper.dark .back-to-nexacore { color: #bf5af2; background: rgba(191,90,242,0.12); }
        .app-wrapper.dark .back-to-nexacore:hover { background: rgba(191,90,242,0.2); }
        .back-to-nexacore svg { transition: transform 0.2s ease; }
        .back-to-nexacore:hover svg { transform: translateX(-2px); }
        @media (max-width: 768px) {
          .back-to-nexacore { padding: 0.5rem; gap: 0; }
          .back-to-nexacore .back-label { display: none; }
        }
      `}</style>
    </div>
  )
}
