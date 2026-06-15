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
  collection, doc, addDoc, deleteDoc, updateDoc, deleteField,
  query, orderBy, onSnapshot, serverTimestamp,
} from 'firebase/firestore'

// status: todo → in_progress → done → todo (cycle)
// deleted is a separate status used for soft-delete

type TaskStatus = 'todo' | 'in_progress' | 'done' | 'deleted'

interface Task {
  id: string
  text: string
  status: TaskStatus
  createdAt: number
  updatedAt: number
  deletedAt?: number
  prevStatus?: TaskStatus
}

const STATUS_NEXT: Record<string, TaskStatus> = {
  todo:        'in_progress',
  in_progress: 'done',
  done:        'todo',
}

const STATUS_LABEL: Record<string, string> = {
  todo:        'To Do',
  in_progress: 'In Progress',
  done:        'Done',
}

function tasksCol(uid: string) {
  return collection(db, 'users', uid, 'tasks')
}
function taskDoc(uid: string, id: string) {
  return doc(db, 'users', uid, 'tasks', id)
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
  const [tasks, setTasks] = useState<Task[]>([])
  const [newTodo, setNewTodo] = useState('')
  const [theme, setTheme] = useState('light')
  const [showAccountDropdown, setShowAccountDropdown] = useState(false)
  const [activeTab, setActiveTab] = useState<'active' | 'done' | 'deleted'>('active')
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

  // Real-time listener — fires on every write from any window/device
  useEffect(() => {
    if (!user) { setTasks([]); return }
    const q = query(tasksCol(user.uid), orderBy('createdAt', 'desc'))
    const unsub = onSnapshot(q, (snap) => {
      setTasks(
        snap.docs.map(d => {
          const data = d.data()
          return {
            id:         d.id,
            text:       data.text ?? '',
            status:     data.status ?? 'todo',
            createdAt:  data.createdAt?.toMillis?.() ?? 0,
            updatedAt:  data.updatedAt?.toMillis?.() ?? 0,
            deletedAt:  data.deletedAt?.toMillis?.() ?? undefined,
            prevStatus: data.prevStatus ?? undefined,
          } as Task
        })
      )
    })
    return unsub
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
    setShowAccountDropdown(false)
  }

  const handleLogout = async () => {
    await signOut(auth)
    setShowAccountDropdown(false)
  }

  const addTask = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user || !newTodo.trim()) return
    await addDoc(tasksCol(user.uid), {
      text:      newTodo.trim(),
      status:    'todo',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    })
    setNewTodo('')
  }

  const cycleStatus = async (task: Task) => {
    if (!user) return
    const next = STATUS_NEXT[task.status] ?? 'todo'
    await updateDoc(taskDoc(user.uid, task.id), {
      status:    next,
      updatedAt: serverTimestamp(),
    })
  }

  const softDelete = async (task: Task) => {
    if (!user) return
    await updateDoc(taskDoc(user.uid, task.id), {
      status:     'deleted',
      prevStatus: task.status,
      deletedAt:  serverTimestamp(),
      updatedAt:  serverTimestamp(),
    })
  }

  const restoreTask = async (task: Task) => {
    if (!user) return
    await updateDoc(taskDoc(user.uid, task.id), {
      status:     task.prevStatus ?? 'todo',
      prevStatus: deleteField(),
      deletedAt:  deleteField(),
      updatedAt:  serverTimestamp(),
    })
    setActiveTab('active')
  }

  const permanentDelete = async (task: Task) => {
    if (!user) return
    await deleteDoc(taskDoc(user.uid, task.id))
  }

  if (pathname?.startsWith('/nexacore/')) return null

  const activeTasks  = tasks.filter(t => t.status !== 'deleted' && t.status !== 'done')
  const doneTasks    = tasks.filter(t => t.status === 'done')
  const deletedTasks = tasks.filter(t => t.status === 'deleted')

  const visibleTasks =
    activeTab === 'active'  ? activeTasks  :
    activeTab === 'done'    ? doneTasks    :
    deletedTasks

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
                {user ? (
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
              <form className="add-todo-form" onSubmit={addTask}>
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
                  className={activeTab === 'active' ? 'active-filter' : ''}
                  onClick={() => setActiveTab('active')}
                >
                  Active{activeTasks.length > 0 ? ` ${activeTasks.length}` : ''}
                </button>
                <button
                  type="button"
                  className={activeTab === 'done' ? 'active-filter' : ''}
                  onClick={() => setActiveTab('done')}
                >
                  Done{doneTasks.length > 0 ? ` ${doneTasks.length}` : ''}
                </button>
                <button
                  type="button"
                  className={`deleted-filter${activeTab === 'deleted' ? ' active-filter' : ''}`}
                  onClick={() => setActiveTab('deleted')}
                >
                  Deleted{deletedTasks.length > 0 ? ` ${deletedTasks.length}` : ''}
                </button>
              </div>

              {/* List */}
              <p className="todo-list-header">
                {activeTab === 'active'  ? 'Active Tasks'    :
                 activeTab === 'done'    ? 'Completed Tasks'  :
                 'Recently Deleted'}
              </p>
              <div className="todo-list">
                {visibleTasks.length === 0 ? (
                  <p className="no-tasks">
                    {activeTab === 'active'  ? 'All clear — nothing active.' :
                     activeTab === 'done'    ? 'No completed tasks yet.'     :
                     'No deleted tasks.'}
                  </p>
                ) : activeTab === 'deleted' ? (
                  deletedTasks.map(task => (
                    <div key={task.id} className="todo-item">
                      <span className="todo-item-text deleted-text">
                        {task.text}
                        <span className="deleted-source-tag">({STATUS_LABEL[task.prevStatus ?? 'todo']})</span>
                      </span>
                      <button type="button" className="restore-btn" onClick={() => restoreTask(task)}>
                        Restore
                      </button>
                      <button type="button" className="delete-btn" onClick={() => permanentDelete(task)} aria-label="Delete permanently">
                        &times;
                      </button>
                    </div>
                  ))
                ) : (
                  visibleTasks.map(task => (
                    <div key={task.id} className="todo-item">
                      <button
                        type="button"
                        className={`status-badge status-${task.status}`}
                        onClick={() => cycleStatus(task)}
                        title="Click to advance status"
                      >
                        {STATUS_LABEL[task.status] ?? task.status}
                      </button>
                      <span className={`todo-item-text${task.status === 'done' ? ' completed' : ''}`}>
                        {task.text}
                      </span>
                      <button type="button" className="delete-btn" onClick={() => softDelete(task)} aria-label="Remove task">
                        &times;
                      </button>
                    </div>
                  ))
                )}
              </div>
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
