'use client'

import React, { useEffect, useMemo, useRef, useState } from 'react'
import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import {
  collection,
  doc,
  onSnapshot,
  setDoc,
  updateDoc,
} from 'firebase/firestore'
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth'
import { auth, db } from '@/app/nexacore/shared/firebase'
import seedData from './generatedSeed.json'
import './NexAlgo.css'

type LanguageKey = 'python' | 'java' | 'cpp'
type NavMode = 'number' | 'company' | 'topic'
type ProblemStatus = 'unvisited' | 'visited' | 'attempted' | 'solved'
type ProblemsPaneMode = 'normal' | 'expanded' | 'minimized'
type DetailSectionKey =
  | 'solve'
  | 'hints'
  | 'topics'
  | 'intuition'
  | 'code'
  | 'walkthrough'
  | 'complexity'
  | 'companies'

type SeedProblem = {
  id: number
  title: string
  slug: string
  difficulty: string
  topics: string[]
  companies: string[]
  link: string
  problemStatement: string
  hints: string[]
  whatToUse: string[]
  intuition: string
  walkthrough: string
  complexity: string
  starterCodeByLanguage: Record<LanguageKey, string>
  officialSolution: string
}

type ProblemProgress = {
  id: string
  status?: ProblemStatus
  lastVisitedAt?: number
  attemptedAt?: number
  solvedAt?: number
}

type AppPreferences = {
  defaultLanguage?: LanguageKey
}

type AppConfig = {
  adminEmails?: string[]
  editorEmails?: string[]
}

type ProblemOverride = {
  id?: number
  title?: string
  slug?: string
  difficulty?: string
  topics?: string[]
  link?: string
  problemStatement?: string
  hints?: string[]
  whatToUse?: string[]
  intuition?: string
  walkthrough?: string
  complexity?: string
  codeByLanguage?: Partial<Record<LanguageKey, string>>
  companies?: string[]
  updatedBy?: string
  updatedAt?: number
}

type QuestionEditorDraft = {
  questionNumber: string
  title: string
  difficulty: string
  link: string
  problemStatement: string
  hints: string
  topics: string
  intuition: string
  walkthrough: string
  complexity: string
  companies: string
  python: string
  java: string
  cpp: string
}

const seedProblems = seedData as SeedProblem[]
const DEFAULT_LANGUAGE: LanguageKey = 'python'
const LANGUAGE_OPTIONS: Array<{ value: LanguageKey; label: string }> = [
  { value: 'python', label: 'Python' },
  { value: 'java', label: 'Java' },
  { value: 'cpp', label: 'C++' },
]
const STATUS_LABELS: Record<ProblemStatus, string> = {
  unvisited: 'Unvisited',
  visited: 'Visited',
  attempted: 'Attempted',
  solved: 'Solved',
}
const PROBLEMS_PER_PAGE = 50
const RETURN_PROMPT_KEY = 'nexalgoPendingReturnProblem'
const LANGUAGE_STORAGE_KEY = 'nexalgoDefaultLanguage'
const DETAIL_SECTION_LABELS: Array<{ key: DetailSectionKey; label: string }> = [
  { key: 'solve', label: 'Solve' },
  { key: 'hints', label: 'Hints' },
  { key: 'topics', label: 'Topics' },
  { key: 'intuition', label: 'Intuition' },
  { key: 'code', label: 'Code' },
  { key: 'walkthrough', label: 'Code walkthrough' },
  { key: 'complexity', label: 'Complexity analysis' },
  { key: 'companies', label: 'Companies' },
]

function statusForProblem(
  progressMap: Record<string, ProblemProgress>,
  problemId: number,
): ProblemStatus {
  return progressMap[String(problemId)]?.status ?? 'unvisited'
}

function difficultyToneClass(difficulty: string) {
  const normalized = difficulty.trim().toLowerCase()
  if (normalized === 'easy') return 'nexalgo-difficulty-easy'
  if (normalized === 'medium') return 'nexalgo-difficulty-medium'
  if (normalized === 'hard') return 'nexalgo-difficulty-hard'
  return ''
}

function statusToneClass(status: ProblemStatus) {
  if (status === 'unvisited') return 'nexalgo-status-unvisited'
  if (status === 'visited') return 'nexalgo-status-visited'
  if (status === 'attempted') return 'nexalgo-status-attempted'
  if (status === 'solved') return 'nexalgo-status-solved'
  return ''
}

function escapeCode(text: string) {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}

function tokenizeCode(code: string, language: LanguageKey) {
  const keywords = {
    python:
      /\b(class|def|return|for|while|if|elif|else|in|and|or|not|None|True|False|break|continue|try|except|from|import)\b/,
    java:
      /\b(class|public|private|protected|static|final|return|for|while|if|else|new|int|long|double|boolean|void|null|this|break|continue)\b/,
    cpp:
      /\b(class|public|private|return|for|while|if|else|int|long|bool|void|auto|const|vector|unordered_map|string|break|continue)\b/,
  }[language]

  const tokenRegex =
    language === 'python'
      ? /(#.*$|"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\b\d+\b|\b[A-Za-z_][A-Za-z0-9_]*\b)/gm
      : /(\/\/.*$|"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\b\d+\b|\b[A-Za-z_][A-Za-z0-9_]*\b)/gm

  return code.split('\n').map((line, lineIndex) => {
    const tokens: React.ReactNode[] = []
    let lastIndex = 0
    let match: RegExpExecArray | null
    const regex = new RegExp(tokenRegex)

    while ((match = regex.exec(line))) {
      const [value] = match
      if (match.index > lastIndex) {
        tokens.push(
          <span key={`${lineIndex}-${lastIndex}`}>
            {line.slice(lastIndex, match.index)}
          </span>,
        )
      }

      let className = ''
      if (
        (language === 'python' && value.startsWith('#')) ||
        (language !== 'python' && value.startsWith('//'))
      ) {
        className = 'nexalgo-code-comment'
      } else if (value.startsWith('"') || value.startsWith("'")) {
        className = 'nexalgo-code-string'
      } else if (/^\d+$/.test(value)) {
        className = 'nexalgo-code-number'
      } else if (keywords.test(value)) {
        className = 'nexalgo-code-keyword'
      }

      tokens.push(
        <span key={`${lineIndex}-${match.index}`} className={className}>
          {value}
        </span>,
      )
      lastIndex = match.index + value.length
    }

    if (lastIndex < line.length) {
      tokens.push(<span key={`${lineIndex}-tail`}>{line.slice(lastIndex)}</span>)
    }

    return (
      <React.Fragment key={`line-${lineIndex}`}>
        {tokens}
        {lineIndex < code.split('\n').length - 1 ? '\n' : ''}
      </React.Fragment>
    )
  })
}

function CodeBlock({
  language,
  code,
}: {
  language: LanguageKey
  code: string
}) {
  const lines = useMemo(() => code.split('\n'), [code])
  const [copyState, setCopyState] = useState<'idle' | 'copied'>('idle')

  async function handleCopyCode() {
    try {
      await navigator.clipboard.writeText(code)
      setCopyState('copied')
      window.setTimeout(() => setCopyState('idle'), 1500)
    } catch {
      setCopyState('idle')
    }
  }

  return (
    <div className='nexalgo-code-block'>
      <div className='nexalgo-code-header'>
        <span>{LANGUAGE_OPTIONS.find((option) => option.value === language)?.label}</span>
        <button
          type='button'
          className='nexalgo-code-copy-btn'
          onClick={() => void handleCopyCode()}>
          {copyState === 'copied' ? 'Copied' : 'Copy code'}
        </button>
      </div>
      <div className='nexalgo-code-body'>
        <div className='nexalgo-code-lines'>
          {lines.map((_, index) => (
            <div key={index}>{index + 1}</div>
          ))}
        </div>
        <pre className='nexalgo-code-content'>{tokenizeCode(code, language)}</pre>
      </div>
    </div>
  )
}

function splitTextAreaList(value: string) {
  return value
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean)
}

function commaList(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
}

function slugifyText(value: string) {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function createEmptyQuestionDraft(): QuestionEditorDraft {
  return {
    questionNumber: '',
    title: '',
    difficulty: 'Medium',
    link: '',
    problemStatement: '',
    hints: '',
    topics: '',
    intuition: '',
    walkthrough: '',
    complexity: '',
    companies: '',
    python: '',
    java: '',
    cpp: '',
  }
}

function createQuestionDraft(problem: SeedProblem): QuestionEditorDraft {
  return {
    questionNumber: String(problem.id),
    title: problem.title,
    difficulty: problem.difficulty,
    link: problem.link,
    problemStatement: problem.problemStatement,
    hints: problem.hints.join('\n'),
    topics: problem.topics.join(', '),
    intuition: problem.intuition,
    walkthrough: problem.walkthrough,
    complexity: problem.complexity,
    companies: problem.companies.join(', '),
    python: problem.starterCodeByLanguage.python ?? '',
    java: problem.starterCodeByLanguage.java ?? '',
    cpp: problem.starterCodeByLanguage.cpp ?? '',
  }
}

export default function NexAlgoPage() {
  const pathname = usePathname()
  const router = useRouter()
  const isProjectsRoute = pathname?.startsWith('/projects/')
  const backLinkHref = isProjectsRoute ? '/#projects' : '/'

  useEffect(() => {
    if (pathname?.startsWith('/nexacore/')) {
      router.replace('/projects/nexalgo')
    }
  }, [pathname, router])

  const [userEmail, setUserEmail] = useState<string | null>(null)
  const [authMode, setAuthMode] = useState<'login' | 'signup'>('signup')
  const [navExpanded, setNavExpanded] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const [statusMenuOpen, setStatusMenuOpen] = useState(false)
  const [questionEditorOpen, setQuestionEditorOpen] = useState(false)
  const [questionEditorMode, setQuestionEditorMode] = useState<'add' | 'edit'>('edit')
  const [questionEditorError, setQuestionEditorError] = useState('')
  const [questionEditorConfirm, setQuestionEditorConfirm] = useState<
    null | 'discard' | 'publish'
  >(null)
  const [problemsPaneMode, setProblemsPaneMode] = useState<ProblemsPaneMode>('normal')
  const [navMode, setNavMode] = useState<NavMode>('number')
  const [currentPage, setCurrentPage] = useState(1)
  const [selectedTopic, setSelectedTopic] = useState<string>('')
  const [selectedCompany, setSelectedCompany] = useState<string>('')
  const [selectedProblemId, setSelectedProblemId] = useState<number>(seedProblems[0]?.id ?? 1)
  const [selectedLanguage, setSelectedLanguage] = useState<LanguageKey>(DEFAULT_LANGUAGE)
  const [defaultLanguage, setDefaultLanguage] = useState<LanguageKey>(DEFAULT_LANGUAGE)
  const [authForm, setAuthForm] = useState({
    email: '',
    password: '',
    preferredLanguage: DEFAULT_LANGUAGE as LanguageKey,
  })
  const [authError, setAuthError] = useState('')
  const [authMessage, setAuthMessage] = useState('')
  const [progressMap, setProgressMap] = useState<Record<string, ProblemProgress>>({})
  const [preferences, setPreferences] = useState<AppPreferences>({})
  const [config, setConfig] = useState<AppConfig>({})
  const [contentOverrides, setContentOverrides] = useState<Record<string, ProblemOverride>>({})
  const [editorEmailInput, setEditorEmailInput] = useState('')
  const [statusPromptProblemId, setStatusPromptProblemId] = useState<number | null>(null)
  const [editorDraft, setEditorDraft] = useState<QuestionEditorDraft>(createEmptyQuestionDraft())
  const menuPanelRef = useRef<HTMLDivElement>(null)
  const problemListRef = useRef<HTMLDivElement>(null)
  const detailPaneRef = useRef<HTMLElement>(null)
  const detailStickyHeaderRef = useRef<HTMLDivElement>(null)
  const detailSectionRefs = useRef<Record<DetailSectionKey, HTMLElement | null>>({
    solve: null,
    hints: null,
    topics: null,
    intuition: null,
    code: null,
    walkthrough: null,
    complexity: null,
    companies: null,
  })
  const [problemListScrolling, setProblemListScrolling] = useState(false)
  const [detailPaneScrolling, setDetailPaneScrolling] = useState(false)
  const [topicsExpanded, setTopicsExpanded] = useState(false)
  const [detailTailSpacerHeight, setDetailTailSpacerHeight] = useState(0)

  useEffect(() => {
    const stored = window.localStorage.getItem(LANGUAGE_STORAGE_KEY) as LanguageKey | null
    if (stored && LANGUAGE_OPTIONS.some((option) => option.value === stored)) {
      setDefaultLanguage(stored)
      setSelectedLanguage(stored)
      setAuthForm((current) => ({ ...current, preferredLanguage: stored }))
    }
  }, [])

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUserEmail(currentUser?.email ?? null)
      if (currentUser?.email) {
        setAuthMessage(`Signed in as ${currentUser.email}`)
        setAuthError('')
      }
    })

    return () => unsubscribe()
  }, [])

  useEffect(() => {
    setTopicsExpanded(false)
  }, [selectedProblemId])

  useEffect(() => {
    function updateDetailTailSpacer() {
      const pane = detailPaneRef.current
      const stickyHeader = detailStickyHeaderRef.current
      if (!pane || !stickyHeader) return

      const nextHeight = Math.max(
        120,
        pane.clientHeight - stickyHeader.offsetHeight - 64,
      )
      setDetailTailSpacerHeight(nextHeight)
    }

    updateDetailTailSpacer()
    window.addEventListener('resize', updateDetailTailSpacer)

    return () => window.removeEventListener('resize', updateDetailTailSpacer)
  }, [selectedProblemId, topicsExpanded, selectedLanguage, statusMenuOpen])

  function performDetailSectionScroll(section: DetailSectionKey) {
    const pane = detailPaneRef.current
    if (!pane) return

    if (section === 'solve') {
      pane.scrollTo({
        top: 0,
        behavior: 'smooth',
      })
      return
    }

    const target = detailSectionRefs.current[section]
    if (!target) return

    const paneRect = pane.getBoundingClientRect()
    const targetRect = target.getBoundingClientRect()
    const stickyHeaderHeight = detailStickyHeaderRef.current?.offsetHeight ?? 0
    const nextTop =
      pane.scrollTop + (targetRect.top - paneRect.top) - stickyHeaderHeight - 12

    pane.scrollTo({
      top: Math.max(0, nextTop),
      behavior: 'smooth',
    })
  }

  function scrollToDetailSection(section: DetailSectionKey) {
    if (section === 'topics' && !topicsExpanded) {
      setTopicsExpanded(true)
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          performDetailSectionScroll('topics')
        })
      })
      return
    }

    performDetailSectionScroll(section)
  }

  useEffect(() => {
    if (!userEmail) {
      setProgressMap({})
      return
    }

    const unsubscribe = onSnapshot(
      collection(db, 'users', userEmail, 'nexalgoProgress'),
      (snapshot) => {
        const nextProgress: Record<string, ProblemProgress> = {}
        snapshot.forEach((item) => {
          nextProgress[item.id] = {
            id: item.id,
            ...(item.data() as Omit<ProblemProgress, 'id'>),
          }
        })
        setProgressMap(nextProgress)
      },
    )

    return () => unsubscribe()
  }, [userEmail])

  useEffect(() => {
    if (!userEmail) {
      setPreferences({})
      return
    }

    const preferenceRef = doc(db, 'users', userEmail, 'appPreferences', 'nexalgo')
    const unsubscribe = onSnapshot(preferenceRef, async (snapshot) => {
      if (!snapshot.exists()) {
        await setDoc(
          preferenceRef,
          { defaultLanguage },
          { merge: true },
        )
        return
      }

      const nextPreferences = snapshot.data() as AppPreferences
      setPreferences(nextPreferences)
      const language = nextPreferences.defaultLanguage ?? DEFAULT_LANGUAGE
      setDefaultLanguage(language)
      setSelectedLanguage(language)
      window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language)
    })

    return () => unsubscribe()
  }, [defaultLanguage, userEmail])

  useEffect(() => {
    const unsubscribe = onSnapshot(
      doc(db, 'appConfigs', 'nexalgo'),
      async (snapshot) => {
        if (!snapshot.exists()) {
          if (userEmail) {
            await setDoc(doc(db, 'appConfigs', 'nexalgo'), {
              adminEmails: [userEmail],
              editorEmails: [],
            })
          }
          return
        }

        setConfig(snapshot.data() as AppConfig)
      },
    )

    return () => unsubscribe()
  }, [userEmail])

  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'nexalgoContent'), (snapshot) => {
      const nextOverrides: Record<string, ProblemOverride> = {}
      snapshot.forEach((item) => {
        nextOverrides[item.id] = item.data() as ProblemOverride
      })
      setContentOverrides(nextOverrides)
    })

    return () => unsubscribe()
  }, [])

  useEffect(() => {
    const handleReturnPrompt = () => {
      const pending = window.localStorage.getItem(RETURN_PROMPT_KEY)
      if (pending) {
        const problemId = Number(pending)
        if (problemId) {
          setStatusPromptProblemId(problemId)
          setSelectedProblemId(problemId)
        }
      }
    }

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        handleReturnPrompt()
      }
    }

    window.addEventListener('focus', handleReturnPrompt)
    document.addEventListener('visibilitychange', handleVisibility)
    handleReturnPrompt()

    return () => {
      window.removeEventListener('focus', handleReturnPrompt)
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [])

  useEffect(() => {
    if (!menuOpen) return

    const handleMouseDown = (event: MouseEvent) => {
      if (menuPanelRef.current && !menuPanelRef.current.contains(event.target as Node)) {
        setMenuOpen(false)
      }
    }

    document.addEventListener('mousedown', handleMouseDown)
    return () => document.removeEventListener('mousedown', handleMouseDown)
  }, [menuOpen])

  useEffect(() => {
    const problemList = problemListRef.current
    const detailPane = detailPaneRef.current
    let problemListTimer: number | null = null
    let detailPaneTimer: number | null = null

    const bindScrollIndicator = (
      element: HTMLElement | null,
      setScrolling: React.Dispatch<React.SetStateAction<boolean>>,
      getTimer: () => number | null,
      setTimer: (timer: number | null) => void,
    ) => {
      if (!element) return () => {}

      const showIndicator = () => {
        if (element.scrollHeight <= element.clientHeight) return
        setScrolling(true)
        const activeTimer = getTimer()
        if (activeTimer) window.clearTimeout(activeTimer)
        setTimer(window.setTimeout(() => setScrolling(false), 1000))
      }

      const scheduleHide = () => {
        const activeTimer = getTimer()
        if (activeTimer) window.clearTimeout(activeTimer)
        setTimer(window.setTimeout(() => setScrolling(false), 1000))
      }

      const handleKeydown = (event: KeyboardEvent) => {
        if (
          ['ArrowDown', 'ArrowUp', 'PageDown', 'PageUp', 'Home', 'End', 'Space'].includes(
            event.code,
          )
        ) {
          showIndicator()
        }
      }

      element.addEventListener('scroll', showIndicator, { passive: true })
      element.addEventListener('wheel', showIndicator, { passive: true })
      element.addEventListener('touchmove', showIndicator, { passive: true })
      element.addEventListener('mouseenter', showIndicator)
      element.addEventListener('mouseleave', scheduleHide)
      element.addEventListener('keydown', handleKeydown)

      return () => {
        element.removeEventListener('scroll', showIndicator)
        element.removeEventListener('wheel', showIndicator)
        element.removeEventListener('touchmove', showIndicator)
        element.removeEventListener('mouseenter', showIndicator)
        element.removeEventListener('mouseleave', scheduleHide)
        element.removeEventListener('keydown', handleKeydown)
      }
    }

    const cleanupProblemList = bindScrollIndicator(
      problemList,
      setProblemListScrolling,
      () => problemListTimer,
      (timer) => {
        problemListTimer = timer
      },
    )

    const cleanupDetailPane = bindScrollIndicator(
      detailPane,
      setDetailPaneScrolling,
      () => detailPaneTimer,
      (timer) => {
        detailPaneTimer = timer
      },
    )

    return () => {
      cleanupProblemList()
      cleanupDetailPane()
      if (problemListTimer) window.clearTimeout(problemListTimer)
      if (detailPaneTimer) window.clearTimeout(detailPaneTimer)
    }
  }, [problemsPaneMode, selectedProblemId])

  const isAdmin = !!userEmail && (config.adminEmails ?? []).includes(userEmail)
  const isEditor =
    isAdmin || (!!userEmail && (config.editorEmails ?? []).includes(userEmail))

  const allProblems = useMemo(() => {
    const mergedMap = new Map<number, SeedProblem>()

    seedProblems.forEach((problem) => {
      const override = contentOverrides[String(problem.id)] ?? {}
      mergedMap.set(problem.id, {
        ...problem,
        title: override.title || problem.title,
        slug: override.slug || problem.slug,
        difficulty: override.difficulty || problem.difficulty,
        topics: override.topics?.length ? override.topics : problem.topics,
        companies: override.companies?.length ? override.companies : problem.companies,
        link: override.link || problem.link,
        problemStatement: override.problemStatement || problem.problemStatement,
        hints: override.hints?.length ? override.hints : problem.hints,
        whatToUse: override.whatToUse?.length ? override.whatToUse : problem.whatToUse,
        intuition: override.intuition || problem.intuition,
        walkthrough: override.walkthrough || problem.walkthrough,
        complexity: override.complexity || problem.complexity,
        starterCodeByLanguage: {
          ...problem.starterCodeByLanguage,
          ...(override.codeByLanguage ?? {}),
        },
      })
    })

    Object.entries(contentOverrides).forEach(([id, override]) => {
      const numericId = override.id ?? Number(id)
      if (mergedMap.has(numericId) || !override.title) return

      mergedMap.set(numericId, {
        id: numericId,
        title: override.title,
        slug: override.slug || slugifyText(override.title),
        difficulty: override.difficulty || 'Medium',
        topics: override.topics ?? [],
        companies: override.companies ?? [],
        link: override.link || '',
        problemStatement: override.problemStatement || '',
        hints: override.hints ?? [],
        whatToUse: override.whatToUse ?? [],
        intuition: override.intuition || '',
        walkthrough: override.walkthrough || '',
        complexity: override.complexity || '',
        starterCodeByLanguage: {
          python: override.codeByLanguage?.python ?? '# Editor solution coming soon',
          java: override.codeByLanguage?.java ?? '// Editor solution coming soon',
          cpp: override.codeByLanguage?.cpp ?? '// Editor solution coming soon',
        },
        officialSolution: '',
      })
    })

    return Array.from(mergedMap.values()).sort((a, b) => a.id - b.id)
  }, [contentOverrides])

  const topics = useMemo(
    () =>
      Array.from(new Set(allProblems.flatMap((problem) => problem.topics))).sort((a, b) =>
        a.localeCompare(b),
      ),
    [allProblems],
  )

  const companies = useMemo(
    () =>
      Array.from(
        new Set(
          allProblems.flatMap((problem) =>
            problem.companies.length > 0 ? problem.companies : ['General'],
          ),
        ),
      ).sort((a, b) => a.localeCompare(b)),
    [allProblems],
  )

  const visibleProblems = useMemo(() => {
    if (navMode === 'topic') {
      if (!selectedTopic) return []
      return allProblems.filter((problem) => problem.topics.includes(selectedTopic))
    }

    if (navMode === 'company') {
      if (!selectedCompany) return []
      return allProblems.filter((problem) =>
        (problem.companies.length > 0 ? problem.companies : ['General']).includes(
          selectedCompany,
        ),
      )
    }

    const start = (currentPage - 1) * PROBLEMS_PER_PAGE
    return allProblems.slice(start, start + PROBLEMS_PER_PAGE)
  }, [allProblems, currentPage, navMode, selectedCompany, selectedTopic])

  const totalPages = Math.max(1, Math.ceil(allProblems.length / PROBLEMS_PER_PAGE))

  const selectedProblem =
    allProblems.find((problem) => problem.id === selectedProblemId) ?? allProblems[0]
  const mergedProblem = selectedProblem ?? null

  const solveLinks = mergedProblem
    ? [{ label: 'LeetCode', url: mergedProblem.link }].filter((item) => item.url)
    : []

  async function persistLanguage(language: LanguageKey) {
    setDefaultLanguage(language)
    setSelectedLanguage(language)
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language)

    if (!userEmail) return

    await setDoc(
      doc(db, 'users', userEmail, 'appPreferences', 'nexalgo'),
      { defaultLanguage: language },
      { merge: true },
    )
  }

  async function saveProgress(problem: SeedProblem, status: ProblemStatus) {
    if (!userEmail) return

    await setDoc(
      doc(db, 'users', userEmail, 'nexalgoProgress', String(problem.id)),
      {
        problemId: problem.id,
        title: problem.title,
        difficulty: problem.difficulty,
        topics: problem.topics,
        status,
        lastVisitedAt: Date.now(),
        attemptedAt: status === 'attempted' ? Date.now() : null,
        solvedAt: status === 'solved' ? Date.now() : null,
      },
      { merge: true },
    )
  }

  async function handleStatusChange(problem: SeedProblem, status: ProblemStatus) {
    await saveProgress(problem, status)
    setStatusMenuOpen(false)
  }

  function jumpToFilter(mode: 'topic' | 'company', value: string) {
    setProblemsPaneMode('normal')
    setNavMode(mode)
    if (mode === 'topic') {
      setSelectedTopic(value)
      return
    }
    setSelectedCompany(value)
  }

  async function handleProblemSelect(problem: SeedProblem) {
    setSelectedProblemId(problem.id)

    if (!userEmail) return

    const currentStatus = statusForProblem(progressMap, problem.id)
    if (currentStatus === 'unvisited') {
      await saveProgress(problem, 'visited')
    } else {
      await setDoc(
        doc(db, 'users', userEmail, 'nexalgoProgress', String(problem.id)),
        { lastVisitedAt: Date.now() },
        { merge: true },
      )
    }
  }

  async function handleExternalAttempt(problem: SeedProblem, url = problem.link) {
    if (!userEmail) {
      setMenuOpen(true)
      return
    }

    await saveProgress(problem, 'attempted')
    window.localStorage.setItem(RETURN_PROMPT_KEY, String(problem.id))
    window.open(url, '_blank', 'noopener,noreferrer')
  }

  async function handleSolvedChoice(status: 'solved' | 'attempted') {
    if (!mergedProblem || !userEmail) return

    await saveProgress(mergedProblem, status)
    window.localStorage.removeItem(RETURN_PROMPT_KEY)
    setStatusPromptProblemId(null)
  }

  async function handleLoginSubmit(event: React.FormEvent) {
    event.preventDefault()
    setAuthError('')
    setAuthMessage('')

    try {
      const credential = await signInWithEmailAndPassword(
        auth,
        authForm.email,
        authForm.password,
      )
      setAuthMessage(`Welcome back, ${credential.user.email}`)
      setMenuOpen(false)
    } catch (error: any) {
      setAuthError(error.message ?? 'Unable to log in.')
    }
  }

  async function handleSignupSubmit(event: React.FormEvent) {
    event.preventDefault()
    setAuthError('')
    setAuthMessage('')

    if (authForm.password.length < 6) {
      setAuthError('Password must be at least 6 characters long.')
      return
    }

    try {
      const credential = await createUserWithEmailAndPassword(
        auth,
        authForm.email,
        authForm.password,
      )

      await setDoc(
        doc(db, 'users', credential.user.email!, 'appPreferences', 'nexalgo'),
        { defaultLanguage: authForm.preferredLanguage },
        { merge: true },
      )

      await persistLanguage(authForm.preferredLanguage)
      setAuthMessage(`Account created for ${credential.user.email}`)
      setMenuOpen(false)
    } catch (error: any) {
      setAuthError(error.message ?? 'Unable to sign up.')
    }
  }

  async function handleLogout() {
    await signOut(auth)
    setMenuOpen(false)
    setAuthMessage('Signed out.')
  }

  async function addEditor() {
    if (!isAdmin || !editorEmailInput.trim()) return

    const nextEditors = Array.from(
      new Set([...(config.editorEmails ?? []), editorEmailInput.trim()]),
    )

    await updateDoc(doc(db, 'appConfigs', 'nexalgo'), {
      editorEmails: nextEditors,
    })
    setEditorEmailInput('')
  }

  async function removeEditor(email: string) {
    if (!isAdmin) return

    await updateDoc(doc(db, 'appConfigs', 'nexalgo'), {
      editorEmails: (config.editorEmails ?? []).filter((item) => item !== email),
    })
  }

  function openQuestionEditor(mode: 'add' | 'edit') {
    if (!isEditor) return
    if (mode === 'edit' && !mergedProblem) return

    setQuestionEditorMode(mode)
    setQuestionEditorError('')
    setQuestionEditorConfirm(null)
    setQuestionEditorOpen(true)
    setEditorDraft(
      mode === 'edit' && mergedProblem
        ? createQuestionDraft(mergedProblem)
        : createEmptyQuestionDraft(),
    )
  }

  function handleDiscardQuestionEditor() {
    setQuestionEditorConfirm('discard')
  }

  function confirmDiscardQuestionEditor() {
    setQuestionEditorOpen(false)
    setQuestionEditorError('')
    setQuestionEditorConfirm(null)
  }

  async function handlePublishQuestion() {
    if (!isEditor || !userEmail) return

    const questionNumber = Number(editorDraft.questionNumber)
    if (!Number.isInteger(questionNumber) || questionNumber <= 0) {
      setQuestionEditorError('Question number must be a positive whole number.')
      return
    }

    if (!editorDraft.title.trim()) {
      setQuestionEditorError('Title is required.')
      return
    }

    const existingQuestion = allProblems.find((problem) => problem.id === questionNumber)
    const editingCurrentQuestion =
      questionEditorMode === 'edit' && mergedProblem?.id === questionNumber

    if (existingQuestion && !editingCurrentQuestion) {
      setQuestionEditorError('That question number already exists.')
      return
    }

    setQuestionEditorConfirm('publish')
  }

  async function confirmPublishQuestion() {
    if (!isEditor || !userEmail) return

    const questionNumber = Number(editorDraft.questionNumber)
    if (!Number.isInteger(questionNumber) || questionNumber <= 0) return

    await setDoc(
      doc(db, 'nexalgoContent', String(questionNumber)),
      {
        id: questionNumber,
        title: editorDraft.title.trim(),
        slug: slugifyText(editorDraft.title),
        difficulty: editorDraft.difficulty.trim() || 'Medium',
        link: editorDraft.link.trim(),
        problemStatement: editorDraft.problemStatement.trim(),
        hints: splitTextAreaList(editorDraft.hints),
        topics: commaList(editorDraft.topics),
        whatToUse: [],
        intuition: editorDraft.intuition.trim(),
        walkthrough: editorDraft.walkthrough.trim(),
        complexity: editorDraft.complexity.trim(),
        companies: commaList(editorDraft.companies),
        codeByLanguage: {
          python: editorDraft.python,
          java: editorDraft.java,
          cpp: editorDraft.cpp,
        },
        updatedBy: userEmail,
        updatedAt: Date.now(),
      },
      { merge: true },
    )

    setSelectedProblemId(questionNumber)
    setQuestionEditorOpen(false)
    setQuestionEditorError('')
    setQuestionEditorConfirm(null)
  }

  const promptProblem =
    statusPromptProblemId !== null
      ? allProblems.find((problem) => problem.id === statusPromptProblemId)
      : null

  if (pathname?.startsWith('/nexacore/')) {
    return null
  }

  return (
    <div className='nexalgo-shell'>
      <header className='nexalgo-topbar'>
        <div className='nexalgo-topbar-left'>
          <Link href={backLinkHref} className='nexalgo-back-link'>
            <span aria-hidden='true'>&larr;</span>
            {isProjectsRoute ? 'Back to Projects' : 'Back to Nexacore'}
          </Link>
        </div>

        <div className='nexalgo-brand'>
          <h1>NexAlgo</h1>
          <p>Practice with structure</p>
        </div>

        <div className='nexalgo-topbar-right'>
          {isEditor ? (
            <button
              type='button'
              className='nexalgo-save-btn'
              onClick={() => openQuestionEditor('add')}>
              Add question
            </button>
          ) : null}
          {userEmail ? (
            <span className='nexalgo-status-pill solved'>
              {isAdmin ? 'Admin' : isEditor ? 'Editor' : 'Viewer'}
            </span>
          ) : (
            <span className='nexalgo-status-pill unvisited'>Sign in required</span>
          )}
          <button
            type='button'
            className='nexalgo-hamburger'
            aria-label='Open account and settings menu'
            onClick={() => setMenuOpen(true)}>
            <span />
          </button>
        </div>
      </header>

      {!userEmail ? (
        <main className='nexalgo-auth-wrap'>
          <div className='nexalgo-auth-card'>
            <div className='nexalgo-auth-grid'>
              <div className='nexalgo-auth-copy'>
                <h2>One login for NexAlgo and Todo Flow</h2>
                <p className='nexalgo-detail-subcopy'>
                  NexAlgo shares the same Firebase auth session as the todo app, so
                  signing in here signs you into both experiences automatically.
                </p>
                <p className='nexalgo-detail-subcopy'>
                  After signup, your preferred language becomes the default code tab
                  across the app.
                </p>
              </div>

              <form
                className='nexalgo-auth-form'
                onSubmit={authMode === 'login' ? handleLoginSubmit : handleSignupSubmit}>
                <h2>{authMode === 'login' ? 'Login' : 'Sign Up'}</h2>
                {authError ? <p className='nexalgo-error'>{authError}</p> : null}
                {authMessage ? <p className='nexalgo-message'>{authMessage}</p> : null}
                <input
                  type='email'
                  placeholder='Email'
                  value={authForm.email}
                  onChange={(event) =>
                    setAuthForm((current) => ({ ...current, email: event.target.value }))
                  }
                  required
                />
                <input
                  type='password'
                  placeholder='Password'
                  value={authForm.password}
                  onChange={(event) =>
                    setAuthForm((current) => ({
                      ...current,
                      password: event.target.value,
                    }))
                  }
                  required
                />
                {authMode === 'signup' ? (
                  <select
                    value={authForm.preferredLanguage}
                    onChange={(event) =>
                      setAuthForm((current) => ({
                        ...current,
                        preferredLanguage: event.target.value as LanguageKey,
                      }))
                    }>
                    {LANGUAGE_OPTIONS.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                ) : null}
                <button type='submit'>
                  {authMode === 'login' ? 'Login' : 'Create account'}
                </button>
                <button
                  type='button'
                  className='nexalgo-auth-switch'
                  onClick={() =>
                    setAuthMode((current) => (current === 'login' ? 'signup' : 'login'))
                  }>
                  {authMode === 'login'
                    ? 'Need an account? Switch to signup.'
                    : 'Already have an account? Switch to login.'}
                </button>
              </form>
            </div>
          </div>
        </main>
      ) : (
        <main className={`nexalgo-main nexalgo-main-${problemsPaneMode}`}>
          <aside className={`nexalgo-sidebar ${navExpanded ? 'expanded' : ''}`}>
              <div className='nexalgo-sidebar-header'>
                {navExpanded ? <strong>Browse</strong> : <span />}
                <button
                  type='button'
                  className='nexalgo-icon-toggle'
                  onClick={() => setNavExpanded((current) => !current)}>
                  {navExpanded ? 'Minimize' : 'Expand'}
                </button>
              </div>

            <nav className='nexalgo-nav'>
                <button
                  type='button'
                  className={navMode === 'number' ? 'active' : ''}
                  onClick={() => {
                    setNavMode('number')
                    setCurrentPage(1)
                  }}>
                  <span className='nexalgo-nav-icon'>123</span>
                  {navExpanded ? 'Sorted' : null}
                </button>
                <button
                  type='button'
                  className={navMode === 'company' ? 'active' : ''}
                  onClick={() => setNavMode('company')}>
                  <span className='nexalgo-nav-icon' aria-hidden='true'>
                    <svg viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'>
                      <path
                        d='M4 20V7.5C4 6.67 4.67 6 5.5 6H10V4.5C10 3.67 10.67 3 11.5 3H18.5C19.33 3 20 3.67 20 4.5V20'
                        stroke='currentColor'
                        strokeWidth='1.8'
                        strokeLinecap='round'
                        strokeLinejoin='round'
                      />
                      <path
                        d='M8 10H8.01M8 13H8.01M8 16H8.01M12 8H12.01M12 11H12.01M12 14H12.01M16 8H16.01M16 11H16.01M16 14H16.01'
                        stroke='currentColor'
                        strokeWidth='2.2'
                        strokeLinecap='round'
                        strokeLinejoin='round'
                      />
                    </svg>
                  </span>
                  {navExpanded ? 'Companies' : null}
                </button>
                <button
                  type='button'
                  className={navMode === 'topic' ? 'active' : ''}
                  onClick={() => setNavMode('topic')}>
                  <span className='nexalgo-nav-icon' aria-hidden='true'>
                    <svg viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'>
                      <path
                        d='M11 5H6.5C5.67 5 5 5.67 5 6.5V11L12.5 18.5C13.33 19.33 14.67 19.33 15.5 18.5L18.5 15.5C19.33 14.67 19.33 13.33 18.5 12.5L11 5Z'
                        stroke='currentColor'
                        strokeWidth='1.8'
                        strokeLinecap='round'
                        strokeLinejoin='round'
                      />
                      <circle
                        cx='8.5'
                        cy='8.5'
                        r='1.25'
                        stroke='currentColor'
                        strokeWidth='1.8'
                      />
                    </svg>
                  </span>
                  {navExpanded ? 'Topics' : null}
                </button>
            </nav>
          </aside>

          <section className={`nexalgo-list-pane nexalgo-list-pane-${problemsPaneMode}`}>
              <div className='nexalgo-pane-head'>
                <div>
                  <h2>
                  {problemsPaneMode === 'minimized'
                    ? 'Problems'
                    : navMode === 'number'
                      ? 'Sorted'
                      : navMode === 'company'
                        ? 'Companies'
                        : 'Topics'}
                </h2>
                {problemsPaneMode === 'minimized' ? (
                  <p className='nexalgo-detail-subcopy'>Compact number list</p>
                  ) : navMode === 'number' ? (
                    <p className='nexalgo-detail-subcopy'>
                      {`Showing problems ${(currentPage - 1) * PROBLEMS_PER_PAGE + 1}-${Math.min(
                        currentPage * PROBLEMS_PER_PAGE,
                        allProblems.length,
                      )}`}
                    </p>
                  ) : (
                  <div className='nexalgo-pane-filter'>
                    <label htmlFor='nexalgo-group-filter' className='nexalgo-filter-label'>
                      {navMode === 'company' ? 'Filter company' : 'Filter topic'}
                    </label>
                    <select
                      id='nexalgo-group-filter'
                      value={navMode === 'company' ? selectedCompany : selectedTopic}
                      onChange={(event) =>
                        navMode === 'company'
                          ? setSelectedCompany(event.target.value)
                          : setSelectedTopic(event.target.value)
                      }>
                      <option value=''>Select one</option>
                      {(navMode === 'company' ? companies : topics).map((option) => (
                        <option key={option} value={option}>
                          {option}
                        </option>
                      ))}
                    </select>
                  </div>
                  )}
                </div>
                <div className='nexalgo-pane-controls'>
                  {problemsPaneMode === 'minimized' ? (
                    <button
                      type='button'
                    className='nexalgo-pane-toggle'
                    onClick={() => setProblemsPaneMode('normal')}>
                    Expand
                  </button>
                ) : problemsPaneMode === 'expanded' ? (
                  <button
                    type='button'
                    className='nexalgo-pane-toggle'
                    onClick={() => setProblemsPaneMode('normal')}>
                    Minimize
                  </button>
                  ) : (
                    <>
                      <button
                        type='button'
                        className='nexalgo-pane-toggle'
                        onClick={() => setProblemsPaneMode('expanded')}>
                        Expand
                      </button>
                      <button
                        type='button'
                        className='nexalgo-pane-toggle'
                        onClick={() => setProblemsPaneMode('minimized')}>
                        Minimize
                      </button>
                    </>
                  )}
                  <span className='nexalgo-status-pill visited nexalgo-items-pill'>
                    {visibleProblems.length} items
                  </span>
                </div>
              </div>

            <div
              ref={problemListRef}
              className={`nexalgo-problem-list ${
                problemListScrolling ? 'nexalgo-scroll-active' : ''
              }`}>
              {visibleProblems.map((problem) => {
                const status = statusForProblem(progressMap, problem.id)
                const companyList =
                  problem.companies.length > 0 ? problem.companies.join(', ') : 'General'

                return (
                  <button
                    type='button'
                    key={problem.id}
                    className={`nexalgo-problem-card ${
                      selectedProblemId === problem.id ? 'active' : ''
                    } ${
                      problemsPaneMode === 'minimized'
                        ? 'nexalgo-problem-card-minimized'
                        : ''
                    }`}
                    onClick={() => handleProblemSelect(problem)}>
                    {problemsPaneMode === 'minimized' ? (
                      <span className='nexalgo-problem-number-only'>{problem.id}</span>
                    ) : (
                      <>
                        <h3>
                          {problem.id}. {problem.title}
                        </h3>
                        <p className='nexalgo-meta-line'>
                          {problem.topics.slice(0, 2).join(', ')} • {problem.difficulty} •{' '}
                          {STATUS_LABELS[status]}
                        </p>
                        <p className='nexalgo-meta-line nexalgo-problem-card-status'>
                          <span className={difficultyToneClass(problem.difficulty)}>
                            {problem.difficulty}
                          </span>{' '}
                          - <span className={statusToneClass(status)}>{STATUS_LABELS[status]}</span>
                        </p>
                        <p className='nexalgo-meta-line'>{companyList}</p>
                      </>
                    )}
                  </button>
                )
              })}
            </div>

            {problemsPaneMode !== 'minimized' && navMode === 'number' ? (
              <div className='nexalgo-pagination'>
                <button
                  type='button'
                  disabled={currentPage === 1}
                  onClick={() => setCurrentPage((page) => Math.max(1, page - 1))}>
                  Previous
                </button>
                <span>
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  type='button'
                  disabled={currentPage === totalPages}
                  onClick={() =>
                    setCurrentPage((page) => Math.min(totalPages, page + 1))
                  }>
                  Next
                </button>
              </div>
            ) : null}
          </section>

          {problemsPaneMode !== 'expanded' ? (
          <section
            ref={detailPaneRef}
            className={`nexalgo-detail-pane ${
              detailPaneScrolling ? 'nexalgo-scroll-active' : ''
            }`}>
            {mergedProblem ? (
              <>
                <div ref={detailStickyHeaderRef} className='nexalgo-detail-sticky-header'>
                  <div className='nexalgo-detail-anchor-bar'>
                    {DETAIL_SECTION_LABELS.map((section) => (
                      <button
                        type='button'
                        key={section.key}
                        className='nexalgo-detail-anchor-btn'
                        onClick={() => scrollToDetailSection(section.key)}>
                        {section.label}
                      </button>
                    ))}
                  </div>
                  <div
                    className='nexalgo-detail-status-block'
                    onMouseLeave={() => setStatusMenuOpen(false)}>
                    <span
                      className={`nexalgo-status-pill ${statusForProblem(
                        progressMap,
                        mergedProblem.id,
                      )}`}>
                      {STATUS_LABELS[statusForProblem(progressMap, mergedProblem.id)]}
                    </span>
                    <div className='nexalgo-status-menu'>
                      <button
                        type='button'
                        className='nexalgo-secondary-btn'
                        onClick={() => setStatusMenuOpen((current) => !current)}>
                        Change status
                      </button>
                      {statusMenuOpen ? (
                        <div className='nexalgo-status-menu-list'>
                          <button
                            type='button'
                            className='nexalgo-status-menu-item'
                            onClick={() => handleStatusChange(mergedProblem, 'unvisited')}>
                            Unvisited
                          </button>
                          <button
                            type='button'
                            className='nexalgo-status-menu-item'
                            onClick={() => handleStatusChange(mergedProblem, 'visited')}>
                            Visited
                          </button>
                          <button
                            type='button'
                            className='nexalgo-status-menu-item'
                            onClick={() => handleStatusChange(mergedProblem, 'attempted')}>
                            Still attempting
                          </button>
                          <button
                            type='button'
                            className='nexalgo-status-menu-item'
                            onClick={() => handleStatusChange(mergedProblem, 'solved')}>
                            Solved
                          </button>
                        </div>
                      ) : null}
                    </div>
                  </div>
                </div>

                <div className='nexalgo-detail-body'>
                  <div className='nexalgo-detail-title-row'>
                    <div>
                      <h2>
                        {mergedProblem.id}. {mergedProblem.title}
                      </h2>
                    </div>
                  </div>

                  {isEditor ? (
                    <div className='nexalgo-detail-actions'>
                      <button
                        type='button'
                        className='nexalgo-save-btn'
                        onClick={() => openQuestionEditor('edit')}>
                        Edit question
                      </button>
                    </div>
                  ) : null}

                  <div className='nexalgo-detail-sections'>
                    <section
                      ref={(node) => {
                        detailSectionRefs.current.solve = node
                      }}
                      className='nexalgo-section'>
                    <h3>Solve</h3>
                    <div className='nexalgo-solve-grid'>
                      {solveLinks.map((solveLink) => (
                          <button
                            type='button'
                            key={solveLink.label}
                            className='nexalgo-solve-card'
                            onClick={() =>
                              handleExternalAttempt(mergedProblem, solveLink.url)
                            }>
                            <span className='nexalgo-solve-card-label'>{solveLink.label}</span>
                            <svg
                              aria-hidden='true'
                              className='nexalgo-external-arrow'
                              viewBox='0 0 24 24'
                              fill='none'
                              xmlns='http://www.w3.org/2000/svg'>
                              <path
                                d='M9 5H5V19H19V15'
                                stroke='currentColor'
                                strokeWidth='2.5'
                                strokeLinecap='square'
                              />
                              <path
                                d='M10 14L19 5'
                                stroke='currentColor'
                                strokeWidth='2.5'
                                strokeLinecap='square'
                              />
                              <path
                                d='M13 5H19V11'
                                stroke='currentColor'
                                strokeWidth='2.5'
                                strokeLinecap='square'
                              />
                            </svg>
                          </button>
                      ))}
                    </div>
                      <button
                        type='button'
                        className='nexalgo-link-btn nexalgo-external-link'
                        onClick={() => handleExternalAttempt(mergedProblem)}>
                        <span>Open platform</span>
                        <span aria-hidden='true' className='nexalgo-external-arrow'>
                          <span className='nexalgo-external-arrow-glyph'>↗</span>
                        </span>
                      </button>
                    </section>

                  <section
                    ref={(node) => {
                      detailSectionRefs.current.hints = node
                    }}
                    className='nexalgo-section'>
                    <h3>Hints</h3>
                    {mergedProblem.hints.length > 0 ? (
                      <ul>
                        {mergedProblem.hints.map((hint, index) => (
                          <li key={index}>{hint}</li>
                        ))}
                      </ul>
                      ) : (
                        <p>No hints saved yet.</p>
                      )}
                  </section>

                  <section
                    ref={(node) => {
                      detailSectionRefs.current.topics = node
                    }}
                    className='nexalgo-section'>
                    <button
                      type='button'
                      className='nexalgo-section-toggle'
                      onClick={() => setTopicsExpanded((current) => !current)}
                      aria-expanded={topicsExpanded}>
                      <h3>Topics</h3>
                      <span
                        className={`nexalgo-section-toggle-icon ${
                          topicsExpanded ? 'expanded' : ''
                        }`}
                        aria-hidden='true'>
                        <svg
                          viewBox='0 0 24 24'
                          fill='none'
                          xmlns='http://www.w3.org/2000/svg'>
                          <path
                            d='M6 9L12 15L18 9'
                            stroke='currentColor'
                            strokeWidth='2'
                            strokeLinecap='round'
                            strokeLinejoin='round'
                          />
                        </svg>
                      </span>
                    </button>
                    {topicsExpanded ? (
                      <div className='nexalgo-topic-row'>
                        {mergedProblem.topics.map((topic) => (
                          <button
                            type='button'
                            key={topic}
                            className='nexalgo-chip nexalgo-chip-button'
                            onClick={() => jumpToFilter('topic', topic)}>
                            {topic}
                          </button>
                        ))}
                      </div>
                    ) : null}
                  </section>

                  <section
                    ref={(node) => {
                      detailSectionRefs.current.intuition = node
                    }}
                    className='nexalgo-section'>
                    <h3>Intuition</h3>
                    <p>{mergedProblem.intuition || 'Editor intuition coming soon.'}</p>
                  </section>

                  <section
                    ref={(node) => {
                      detailSectionRefs.current.code = node
                    }}
                    className='nexalgo-section'>
                    <h3>Code</h3>
                    <div className='nexalgo-code-tabs'>
                      {LANGUAGE_OPTIONS.map((option) => (
                        <button
                          type='button'
                          key={option.value}
                          className={selectedLanguage === option.value ? 'active' : ''}
                          onClick={() => setSelectedLanguage(option.value)}>
                          {option.label}
                        </button>
                      ))}
                    </div>
                    <CodeBlock
                      language={selectedLanguage}
                      code={
                        mergedProblem.starterCodeByLanguage[selectedLanguage] ||
                        '# Editor solution coming soon'
                      }
                    />
                  </section>

                  <section
                    ref={(node) => {
                      detailSectionRefs.current.walkthrough = node
                    }}
                    className='nexalgo-section'>
                    <h3>Code walk through</h3>
                    <p>{mergedProblem.walkthrough || 'Editor walkthrough coming soon.'}</p>
                  </section>

                  <section
                    ref={(node) => {
                      detailSectionRefs.current.complexity = node
                    }}
                    className='nexalgo-section'>
                    <h3>Complexity analysis</h3>
                    <p>{mergedProblem.complexity || 'Editor complexity notes coming soon.'}</p>
                  </section>

                  <section
                    ref={(node) => {
                      detailSectionRefs.current.companies = node
                    }}
                    className='nexalgo-section'>
                    <h3>Companies</h3>
                    <div className='nexalgo-company-row'>
                      {(mergedProblem.companies.length > 0
                        ? mergedProblem.companies
                        : ['General']
                      ).map((company) => (
                        <button
                          type='button'
                          key={company}
                          className='nexalgo-chip nexalgo-chip-button'
                          onClick={() => jumpToFilter('company', company)}>
                          {company}
                        </button>
                      ))}
                    </div>
                  </section>
                  <div
                    className='nexalgo-detail-tail-spacer'
                    aria-hidden='true'
                    style={{ height: `${detailTailSpacerHeight}px` }}
                  />
                </div>
                </div>

              </>
            ) : (
              <div className='nexalgo-empty-state'>No problem selected yet.</div>
            )}
          </section>
          ) : null}
        </main>
      )}

      {menuOpen ? (
        <div className='nexalgo-menu-scrim'>
          <aside className='nexalgo-menu-panel' ref={menuPanelRef}>
            <div className='nexalgo-menu-head'>
              <span className='nexalgo-menu-title'>Settings</span>
              <button
                type='button'
                className='nexalgo-close-btn'
                onClick={() => setMenuOpen(false)}>
                ×
              </button>
            </div>

            <section className='nexalgo-menu-section'>
              <h3>Account</h3>
              {userEmail ? (
                <>
                  <p className='nexalgo-detail-subcopy nexalgo-menu-copy'>{userEmail}</p>
                  <button type='button' className='nexalgo-danger-btn' onClick={handleLogout}>
                    Logout
                  </button>
                </>
              ) : (
                <p className='nexalgo-detail-subcopy nexalgo-menu-copy'>
                  Use the main signup card to create a shared account for NexAlgo and
                  Todo Flow.
                </p>
              )}
            </section>

            <section className='nexalgo-menu-section'>
              <h3>Default language</h3>
              <div className='nexalgo-role-list'>
                {LANGUAGE_OPTIONS.map((option) => (
                  <button
                    type='button'
                    key={option.value}
                    onClick={() => persistLanguage(option.value)}
                    className={
                      defaultLanguage === option.value
                        ? 'nexalgo-menu-choice active'
                        : 'nexalgo-menu-choice'
                    }>
                    {option.label}
                    {defaultLanguage === option.value ? ' (selected)' : ''}
                  </button>
                ))}
              </div>
            </section>

            {isAdmin ? (
              <section className='nexalgo-menu-section'>
                <h3>Editor access</h3>
                <input
                  type='email'
                  placeholder='editor@example.com'
                  value={editorEmailInput}
                  onChange={(event) => setEditorEmailInput(event.target.value)}
                />
                <div className='nexalgo-detail-actions'>
                  <button type='button' className='nexalgo-save-btn' onClick={addEditor}>
                    Add editor
                  </button>
                </div>
                <div className='nexalgo-role-list'>
                  {(config.editorEmails ?? []).map((email) => (
                    <button
                      type='button'
                      key={email}
                      onClick={() => removeEditor(email)}>
                      {email} ×
                    </button>
                  ))}
                </div>
              </section>
            ) : null}
          </aside>
        </div>
      ) : null}

      {questionEditorOpen ? (
        <div className='nexalgo-modal-scrim'>
          <div className='nexalgo-modal-card nexalgo-question-modal'>
            <div className='nexalgo-menu-head'>
              <div>
                <h3>{questionEditorMode === 'add' ? 'Add question' : 'Edit question'}</h3>
                <p className='nexalgo-detail-subcopy'>
                  {questionEditorMode === 'add'
                    ? 'Create a new question and publish it to the shared library.'
                    : 'Update the current question and publish the revised version.'}
                </p>
              </div>
              <button
                type='button'
                className='nexalgo-close-btn'
                onClick={handleDiscardQuestionEditor}>
                ×
              </button>
            </div>

            <form
              className='nexalgo-question-form'
              onSubmit={(event) => {
                event.preventDefault()
                void handlePublishQuestion()
              }}>
              {questionEditorError ? (
                <p className='nexalgo-error'>{questionEditorError}</p>
              ) : null}

              <div className='nexalgo-question-grid'>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Question number</span>
                  <input
                    type='number'
                    value={editorDraft.questionNumber}
                    disabled={questionEditorMode === 'edit'}
                    onChange={(event) =>
                      setEditorDraft((current) => ({
                        ...current,
                        questionNumber: event.target.value,
                      }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Title</span>
                  <input
                    type='text'
                    value={editorDraft.title}
                    onChange={(event) =>
                      setEditorDraft((current) => ({
                        ...current,
                        title: event.target.value,
                      }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Difficulty</span>
                  <select
                    value={editorDraft.difficulty}
                    onChange={(event) =>
                      setEditorDraft((current) => ({
                        ...current,
                        difficulty: event.target.value,
                      }))
                    }>
                    <option value='Easy'>Easy</option>
                    <option value='Medium'>Medium</option>
                    <option value='Hard'>Hard</option>
                  </select>
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Primary platform link</span>
                  <input
                    type='text'
                    value={editorDraft.link}
                    onChange={(event) =>
                      setEditorDraft((current) => ({
                        ...current,
                        link: event.target.value,
                      }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Topics</span>
                  <input
                    type='text'
                    value={editorDraft.topics}
                    onChange={(event) =>
                      setEditorDraft((current) => ({
                        ...current,
                        topics: event.target.value,
                      }))
                    }
                  />
                </label>
                <label className='nexalgo-field'>
                  <span className='nexalgo-field-label'>Companies</span>
                  <input
                    type='text'
                    value={editorDraft.companies}
                    onChange={(event) =>
                      setEditorDraft((current) => ({
                        ...current,
                        companies: event.target.value,
                      }))
                    }
                  />
                </label>
              </div>

              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Problem statement</span>
                <textarea
                  value={editorDraft.problemStatement}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      problemStatement: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Hints</span>
                <textarea
                  value={editorDraft.hints}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      hints: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Intuition</span>
                <textarea
                  value={editorDraft.intuition}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      intuition: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Code walkthrough</span>
                <textarea
                  value={editorDraft.walkthrough}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      walkthrough: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Complexity analysis</span>
                <textarea
                  value={editorDraft.complexity}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      complexity: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Python solution</span>
                <textarea
                  value={editorDraft.python}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      python: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>Java solution</span>
                <textarea
                  value={editorDraft.java}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      java: event.target.value,
                    }))
                  }
                />
              </label>
              <label className='nexalgo-field'>
                <span className='nexalgo-field-label'>C++ solution</span>
                <textarea
                  value={editorDraft.cpp}
                  onChange={(event) =>
                    setEditorDraft((current) => ({
                      ...current,
                      cpp: event.target.value,
                    }))
                  }
                />
              </label>

              <div className='nexalgo-question-actions'>
                <button
                  type='button'
                  className='nexalgo-danger-btn'
                  onClick={handleDiscardQuestionEditor}>
                  Discard
                </button>
                <button type='submit' className='nexalgo-save-btn'>
                  Publish
                </button>
              </div>
            </form>
          </div>

          {questionEditorConfirm ? (
            <div className='nexalgo-modal-scrim'>
              <div className='nexalgo-modal-card'>
                <h3>
                  {questionEditorConfirm === 'discard'
                    ? 'Discard changes?'
                    : 'Publish changes?'}
                </h3>
                <p className='nexalgo-detail-subcopy'>
                  {questionEditorConfirm === 'discard'
                    ? 'Your unsaved edits will be lost.'
                    : 'This question will be saved to the shared library.'}
                </p>
                <div className='nexalgo-status-actions'>
                  <button
                    type='button'
                    className='nexalgo-secondary-btn'
                    onClick={() => setQuestionEditorConfirm(null)}>
                    Cancel
                  </button>
                  <button
                    type='button'
                    className='nexalgo-save-btn'
                    onClick={() =>
                      questionEditorConfirm === 'discard'
                        ? confirmDiscardQuestionEditor()
                        : void confirmPublishQuestion()
                    }>
                    {questionEditorConfirm === 'discard' ? 'Discard' : 'Publish'}
                  </button>
                </div>
              </div>
            </div>
          ) : null}
        </div>
      ) : null}

      {promptProblem ? (
        <div className='nexalgo-modal-scrim'>
          <div className='nexalgo-modal-card'>
            <h3>How did it go?</h3>
            <p className='nexalgo-detail-subcopy'>
              You came back from {promptProblem.id}. {promptProblem.title}. Did you solve
              it or are you still attempting it?
            </p>
            <div className='nexalgo-status-actions'>
              <button
                type='button'
                className='nexalgo-status-action primary'
                onClick={() => handleSolvedChoice('solved')}>
                Solved
              </button>
              <button
                type='button'
                className='nexalgo-secondary-btn'
                onClick={() => handleSolvedChoice('attempted')}>
                Still attempting
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}
