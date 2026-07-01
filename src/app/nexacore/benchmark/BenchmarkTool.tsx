'use client'

import { Fragment, useEffect, useRef, useState } from 'react'

/* ---------------------------------------------------------------------
   Calibration constants - the numbers a 100 score maps to. Picked from
   rough mid-range 2023 laptop / discrete-GPU figures so results are
   comparable device-to-device, not an absolute industry index.
   --------------------------------------------------------------------- */
const REF = {
  cpuIntSingle: 550_000_000,
  cpuFloatSingle: 47_000_000,
  cpuIntMulti: 4_700_000_000,
  cpuFloatMulti: 360_000_000,
  gpuRenderFps: 60,
  gpuExportFps: 45,
  gpuExportReadbackMBs: 800,
  gpuAiGflops: 150,
  ramWriteGBs: 7,
  ramReadGBs: 10,
  ramRandomMOpsSec: 190,
  vramUploadMBs: 4000,
  vramDownloadMBs: 1500,
  ssdWriteMBs: 1000,
  ssdReadMBs: 2200,
  webDomChurn: 28_000,
  webLayout: 75_000,
  webTextEdit: 375_000,
  webListSort: 3_800,
  webJson: 34_000,
  battDrainPctPerHour: 40,
}

const ESTIMATE_MS = { cpu: 4700, gpu: 7600, ram: 1500, ssd: 6200, web: 3500, battery: 300, display: 1600 }
const TOTAL_ESTIMATE_MS = Object.values(ESTIMATE_MS).reduce((a, b) => a + b, 0)
const STORAGE_MIN_SAMPLE_MS = 5000

function clampScore(n: number): number {
  if (!isFinite(n) || n < 0) return 0
  return Math.round(Math.min(100, n))
}

function scoreToGrade(score: number | null): string {
  if (score === null) return 'not run'
  if (score >= 85) return 'excellent'
  if (score >= 65) return 'good'
  if (score >= 40) return 'fair'
  if (score > 0) return 'weak'
  return 'not run'
}

function scoreToneClass(score: number | null): 'good' | 'warn' | 'bad' | 'na' {
  if (score === null) return 'na'
  if (score >= 65) return 'good'
  if (score >= 40) return 'warn'
  return 'bad'
}

function fmt(n: number, digits = 1): string {
  return n.toLocaleString(undefined, { maximumFractionDigits: digits, minimumFractionDigits: digits })
}

function fmtOps(n: number): string {
  if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(2)}B`
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(2)}K`
  return n.toFixed(0)
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms))
}

function guessMemoryArchitecture(renderer: string): 'unified' | 'discrete' | 'unknown' {
  const r = renderer.toLowerCase()
  const discreteHints = ['nvidia', 'geforce', 'rtx', 'gtx', 'quadro', 'radeon rx', 'radeon pro', 'firepro']
  if (discreteHints.some((h) => r.includes(h))) return 'discrete'
  const unifiedHints = ['apple', 'intel', 'iris', 'uhd graphics', 'radeon graphics', 'adreno', 'mali', 'powervr']
  if (unifiedHints.some((h) => r.includes(h))) return 'unified'
  return 'unknown'
}

type DeviceDetails = {
  platform: string
  cores: number | string
  memory: string
  viewport: string
  pixelRatio: number | string
  ua: string
  gpuRenderer: string
  gpuAdapter: string
  memArch: 'unified' | 'discrete' | 'unknown'
  processor: string
  coreTopology: string
  cpuFrequency: string
  gpuVendor: string
  gpuCores: string
  gpuGeneration: string
}

function normalizePlatform(userAgent: string, platformHint?: string, architecture?: string) {
  const ua = userAgent.toLowerCase()
  const platform = (platformHint || '').toLowerCase()
  const arch = architecture ? ` · ${architecture}` : ''

  if (ua.includes('mac os x') || platform.includes('macos')) {
    if (platform === 'macintel' && (ua.includes('arm') || architecture === 'arm')) {
      return `macOS · Apple Silicon${arch}`
    }
    return `macOS${arch}`
  }
  if (ua.includes('windows') || platform.includes('windows')) return `Windows${arch}`
  if (ua.includes('android') || platform.includes('android')) return `Android${arch}`
  if (ua.includes('linux') || platform.includes('linux')) return `Linux${arch}`
  if (ua.includes('iphone') || ua.includes('ipad')) return `iOS / iPadOS${arch}`
  return platformHint || 'unknown'
}

function detectGpuVendor(renderer: string) {
  const r = renderer.toLowerCase()
  if (r.includes('apple')) return 'Apple'
  if (r.includes('nvidia') || r.includes('geforce') || r.includes('rtx') || r.includes('gtx')) return 'NVIDIA'
  if (r.includes('amd') || r.includes('radeon')) return 'AMD'
  if (r.includes('intel') || r.includes('iris') || r.includes('uhd')) return 'Intel'
  if (r.includes('adreno')) return 'Qualcomm'
  if (r.includes('mali')) return 'Arm'
  return 'not exposed'
}

function inferProcessor(userAgent: string, renderer: string, architecture?: string) {
  const ua = userAgent.toLowerCase()
  const r = renderer.toLowerCase()
  const arch = architecture || 'not exposed'

  const appleMatch = renderer.match(/Apple\s+(M\d(?:\s?(?:Pro|Max|Ultra))?)/i)
  if (appleMatch) return `${appleMatch[1].replace(/\s+/g, ' ')} family (${arch})`
  if ((ua.includes('mac os x') || ua.includes('macintosh')) && (r.includes('apple') || architecture === 'arm')) {
    return `Apple Silicon (${arch})`
  }
  if (r.includes('intel')) return `Intel CPU (${arch})`
  if (r.includes('amd') || r.includes('radeon')) return `AMD CPU/GPU platform (${arch})`
  return `Browser exposes architecture only: ${arch}`
}

function inferGpuGeneration(renderer: string) {
  const r = renderer.toLowerCase()
  const appleMatch = renderer.match(/Apple\s+(M\d(?:\s?(?:Pro|Max|Ultra))?)/i)
  if (appleMatch) return appleMatch[1].replace(/\s+/g, ' ')
  const rtx = renderer.match(/RTX\s?(\d{4})/i)
  if (rtx) return `GeForce RTX ${rtx[1][0]}0-series`
  const gtx = renderer.match(/GTX\s?(\d{3,4})/i)
  if (gtx) return `GeForce GTX ${gtx[1][0]}00-series`
  const rx = renderer.match(/RX\s?(\d{3,4})/i)
  if (rx) return `Radeon RX ${rx[1][0]}000/series`
  if (r.includes('iris xe')) return 'Intel Iris Xe'
  if (r.includes('uhd')) return 'Intel UHD'
  return 'not exposed by browser'
}

async function getBrowserHardwareHints() {
  const uaData = (navigator as unknown as {
    userAgentData?: {
      platform?: string
      getHighEntropyValues?: (keys: string[]) => Promise<Record<string, string>>
    }
  }).userAgentData

  if (!uaData?.getHighEntropyValues) {
    return {
      platform: navigator.platform || '',
      architecture: '',
      bitness: '',
      model: '',
    }
  }

  const hints = await uaData.getHighEntropyValues([
    'architecture',
    'bitness',
    'model',
    'platform',
    'platformVersion',
  ])
  return {
    platform: hints.platform || uaData.platform || navigator.platform || '',
    architecture: hints.architecture || '',
    bitness: hints.bitness || '',
    model: hints.model || '',
  }
}

function pickBytesForDevice(large: number, mid: number, small: number): number {
  const mem = (navigator as unknown as { deviceMemory?: number }).deviceMemory
  if (!mem || mem >= 8) return large
  if (mem >= 4) return mid
  return small
}

/* ================= CPU worker ================= */
const CPU_WORKER_SRC = `
self.onmessage = function(e){
  const duration = e.data.duration;
  const mode = e.data.mode;
  let ops = 0;
  const end = performance.now() + duration;
  if (mode === 'float') {
    let x = 0.0001;
    while (performance.now() < end) {
      for (let i = 0; i < 2000; i++) {
        x += Math.sqrt(i * 1.0000001) * Math.sin(i) - Math.cos(x);
        ops++;
      }
    }
  } else {
    let x = 0;
    while (performance.now() < end) {
      for (let i = 0; i < 4000; i++) {
        x = (x ^ (i << 3)) + (x >>> 2) - (i | 5);
        x = Math.imul(x, 2654435761) >>> 0;
        ops++;
      }
    }
  }
  self.postMessage({ ops: ops });
};
`

/* ================= RAM worker ================= */
const RAM_WORKER_SRC = `
self.onmessage = function(e){
  const bytes = e.data.bytes;
  const count = Math.floor(bytes / 8);
  const buf = new Float64Array(count);

  let t0 = performance.now();
  for (let i = 0; i < count; i++) buf[i] = i * 1.0000001;
  let t1 = performance.now();
  const writeGBs = (count * 8 / 1e9) / ((t1 - t0) / 1000);

  t0 = performance.now();
  let sum = 0;
  for (let i = 0; i < count; i++) sum += buf[i];
  t1 = performance.now();
  const readGBs = (count * 8 / 1e9) / ((t1 - t0) / 1000);

  const idxCount = Math.min(4000000, count);
  const indices = new Uint32Array(idxCount);
  for (let i = 0; i < idxCount; i++) indices[i] = (Math.random() * count) | 0;
  t0 = performance.now();
  let sum2 = 0;
  for (let i = 0; i < idxCount; i++) sum2 += buf[indices[i]];
  t1 = performance.now();
  const randomMOpsSec = idxCount / ((t1 - t0) / 1000) / 1e6;

  self.postMessage({ writeGBs, readGBs, randomMOpsSec, sink: sum + sum2 });
};
`

const MATMUL_WGSL = `
struct Matrix { data: array<f32> };
@group(0) @binding(0) var<storage, read> A: Matrix;
@group(0) @binding(1) var<storage, read> B: Matrix;
@group(0) @binding(2) var<storage, read_write> C: Matrix;
const N: u32 = 256u;
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let row = gid.y;
  let col = gid.x;
  if (row >= N || col >= N) { return; }
  var sum: f32 = 0.0;
  for (var k: u32 = 0u; k < N; k = k + 1u) {
    sum = sum + A.data[row * N + k] * B.data[k * N + col];
  }
  C.data[row * N + col] = sum;
}
`

const GPU_VERT_SRC = `
  attribute vec2 aOffset; attribute float aSize; attribute vec3 aColor; attribute float aPhase;
  uniform float uTime;
  varying vec3 vColor;
  void main(){
    vColor = aColor;
    float a = uTime * 0.6 + aPhase;
    vec2 pos = aOffset + vec2(sin(a) * 0.5, cos(a * 1.3) * 0.5);
    gl_Position = vec4(pos, 0.0, 1.0);
    gl_PointSize = aSize * (1.0 + 0.4 * sin(uTime * 2.0 + aPhase));
  }`
const GPU_FRAG_SRC = `
  precision mediump float; varying vec3 vColor;
  void main(){
    vec2 c = gl_PointCoord - vec2(0.5);
    float d = length(c);
    if (d > 0.5) discard;
    float alpha = smoothstep(0.5, 0.0, d);
    gl_FragColor = vec4(vColor, alpha);
  }`

const GPU_EXPORT_FRAG_SRC = `
  precision highp float; varying vec2 vUv; uniform float uTime;
  void main(){
    vec2 uv = vUv * 8.0;
    float v = 0.0;
    for (int i = 0; i < 18; i++) {
      float fi = float(i) + 1.0;
      v += sin(uv.x * fi + uTime) * cos(uv.y * fi - uTime) / fi;
    }
    gl_FragColor = vec4(0.5 + 0.5 * v, 0.4 + 0.3 * sin(uTime), 0.6 + 0.3 * cos(uTime), 1.0);
  }`
const GPU_EXPORT_VERT_SRC = `
  attribute vec2 aPos; varying vec2 vUv;
  void main(){ vUv = aPos * 0.5 + 0.5; gl_Position = vec4(aPos, 0.0, 1.0); }`

interface SubResult { label: string; value: string; score: number | null; note?: string }
interface TestResult { summary: string; score: number | null; grade: string; subs: SubResult[] }
type ResultKey = 'cpu' | 'gpu' | 'ram' | 'ssd' | 'web' | 'battery' | 'display' | 'speakers'
type ResultsMap = Partial<Record<ResultKey, TestResult>>

const LABELS: Record<ResultKey, string> = {
  cpu: 'CPU throughput',
  gpu: 'GPU compute & rendering',
  ram: 'Memory bandwidth',
  ssd: 'Storage throughput',
  web: 'Web browsing',
  battery: 'Battery',
  display: 'Display',
  speakers: 'Speakers',
}
const TAB_ORDER: ResultKey[] = ['cpu', 'gpu', 'ram', 'ssd', 'web', 'battery', 'display', 'speakers']
const TAB_LABELS: Record<ResultKey, string> = {
  cpu: 'CPU', gpu: 'GPU', ram: 'RAM', ssd: 'SSD', web: 'Web', battery: 'Battery', display: 'Display', speakers: 'Speakers',
}

function compileProgram(gl: WebGLRenderingContext, vsSrc: string, fsSrc: string): WebGLProgram {
  const compile = (type: number, src: string) => {
    const s = gl.createShader(type) as WebGLShader
    gl.shaderSource(s, src)
    gl.compileShader(s)
    return s
  }
  const prog = gl.createProgram() as WebGLProgram
  gl.attachShader(prog, compile(gl.VERTEX_SHADER, vsSrc))
  gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, fsSrc))
  gl.linkProgram(prog)
  return prog
}

export default function BenchmarkTool() {
  const [activeTab, setActiveTab] = useState<ResultKey | 'report'>('cpu')
  const [results, setResults] = useState<ResultsMap>({})

  function clearResult(key: ResultKey) {
    setResults((current) => {
      const next = { ...current }
      delete next[key]
      return next
    })
  }

  /* ---- device strip ---- */
  const [device, setDevice] = useState<DeviceDetails>({
    platform: '-',
    cores: '-',
    memory: '-',
    viewport: '-',
    pixelRatio: '-',
    ua: '',
    gpuRenderer: '-',
    gpuAdapter: '-',
    memArch: 'unknown',
    processor: '-',
    coreTopology: 'not exposed by browser',
    cpuFrequency: 'not exposed by browser',
    gpuVendor: '-',
    gpuCores: 'not exposed by browser',
    gpuGeneration: 'not exposed by browser',
  })

  useEffect(() => {
    document.title = 'NexaBench · NexaCore Device Diagnostics'
  }, [])

  useEffect(() => {
    let cancelled = false

    async function inspectDevice() {
      const mem = (navigator as unknown as { deviceMemory?: number }).deviceMemory
      const hints = await getBrowserHardwareHints()
      let renderer = 'not exposed'
      let adapterLabel = 'not exposed'

      const canvas = document.createElement('canvas')
      const gl = (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')) as WebGLRenderingContext | null
      if (gl) {
        const dbg = gl.getExtension('WEBGL_debug_renderer_info')
        renderer = String(dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER))
      }

      const gpuNav = (navigator as unknown as { gpu?: { requestAdapter?: () => Promise<any> } }).gpu
      try {
        const adapter = await gpuNav?.requestAdapter?.()
        if (adapter?.info) {
          const info = adapter.info
          adapterLabel = [info.vendor, info.architecture, info.device, info.description]
            .filter(Boolean)
            .join(' · ') || 'WebGPU adapter exposed'
        } else if (adapter?.requestAdapterInfo) {
          const info = await adapter.requestAdapterInfo()
          adapterLabel = [info.vendor, info.architecture, info.device, info.description]
            .filter(Boolean)
            .join(' · ') || 'WebGPU adapter exposed'
        }
      } catch {
        adapterLabel = 'not exposed'
      }

      if (cancelled) return

      const architecture = hints.architecture
        ? `${hints.architecture}${hints.bitness ? `-${hints.bitness}` : ''}`
        : ''
      const platform = normalizePlatform(navigator.userAgent, hints.platform, hints.architecture)
      const gpuVendor = detectGpuVendor(`${renderer} ${adapterLabel}`)
      setDevice({
        platform,
        cores: navigator.hardwareConcurrency || 'unknown',
        memory: mem ? `${mem} GB` : 'not exposed',
        viewport: `${window.innerWidth} × ${window.innerHeight}`,
        pixelRatio: window.devicePixelRatio || 1,
        ua: navigator.userAgent,
        gpuRenderer: renderer,
        gpuAdapter: adapterLabel,
        memArch: guessMemoryArchitecture(`${renderer} ${adapterLabel}`),
        processor: hints.model || inferProcessor(navigator.userAgent, renderer, architecture),
        coreTopology: 'P/E/S-eff core counts are not exposed to browser JavaScript',
        cpuFrequency: 'not exposed to browser JavaScript',
        gpuVendor,
        gpuCores: 'not exposed to browser JavaScript',
        gpuGeneration: inferGpuGeneration(`${renderer} ${adapterLabel}`),
      })
    }

    void inspectDevice()
    return () => {
      cancelled = true
    }
  }, [])

  /* ---- worker url caches ---- */
  const cpuWorkerUrlRef = useRef<string | null>(null)
  const ramWorkerUrlRef = useRef<string | null>(null)
  useEffect(() => {
    return () => {
      if (cpuWorkerUrlRef.current) URL.revokeObjectURL(cpuWorkerUrlRef.current)
      if (ramWorkerUrlRef.current) URL.revokeObjectURL(ramWorkerUrlRef.current)
    }
  }, [])
  function getCpuWorkerUrl(): string {
    if (!cpuWorkerUrlRef.current) {
      cpuWorkerUrlRef.current = URL.createObjectURL(new Blob([CPU_WORKER_SRC], { type: 'application/javascript' }))
    }
    return cpuWorkerUrlRef.current
  }
  function getRamWorkerUrl(): string {
    if (!ramWorkerUrlRef.current) {
      ramWorkerUrlRef.current = URL.createObjectURL(new Blob([RAM_WORKER_SRC], { type: 'application/javascript' }))
    }
    return ramWorkerUrlRef.current
  }

  function runCpuWorkerPass(mode: 'int' | 'float', duration: number, count: number): Promise<number> {
    const url = getCpuWorkerUrl()
    const jobs = Array.from({ length: count }, () => new Promise<number>((resolve) => {
      const w = new Worker(url)
      w.onmessage = (e) => { resolve(e.data.ops as number); w.terminate() }
      w.postMessage({ duration, mode })
    }))
    return Promise.all(jobs).then((arr) => arr.reduce((a, b) => a + b, 0))
  }

  /* ================= CPU ================= */
  const [cpu, setCpu] = useState({
    status: 'Idle - press run', running: false,
    singleInt: null as number | null, singleFloat: null as number | null,
    multiInt: null as number | null, multiFloat: null as number | null,
    cores: (typeof navigator !== 'undefined' ? navigator.hardwareConcurrency : 4) || 4, scaling: null as number | null, score: null as number | null,
  })

  async function executeCpuTest() {
    markSessionBatteryStart()
    clearResult('cpu')
    setCpu((c) => ({
      ...c,
      running: true,
      status: 'Warming up…',
      singleInt: null,
      singleFloat: null,
      multiInt: null,
      multiFloat: null,
      scaling: null,
      score: null,
    }))
    const cores = navigator.hardwareConcurrency || 4
    const SEG = 1100

    setCpu((c) => ({ ...c, cores, status: 'Single-core · integer workload…' }))
    const intSingleOps = await runCpuWorkerPass('int', SEG, 1)
    setCpu((c) => ({ ...c, status: 'Single-core · floating point workload…' }))
    const floatSingleOps = await runCpuWorkerPass('float', SEG, 1)
    setCpu((c) => ({ ...c, status: `Multi-core · integer workload across ${cores} threads…` }))
    const intMultiOps = await runCpuWorkerPass('int', SEG, cores)
    setCpu((c) => ({ ...c, status: `Multi-core · floating point workload across ${cores} threads…` }))
    const floatMultiOps = await runCpuWorkerPass('float', SEG, cores)

    const singleInt = Math.round(intSingleOps / (SEG / 1000))
    const singleFloat = Math.round(floatSingleOps / (SEG / 1000))
    const multiInt = Math.round(intMultiOps / (SEG / 1000))
    const multiFloat = Math.round(floatMultiOps / (SEG / 1000))

    const singleScore = clampScore((singleInt / REF.cpuIntSingle) * 50 + (singleFloat / REF.cpuFloatSingle) * 50)
    const multiScore = clampScore((multiInt / REF.cpuIntMulti) * 50 + (multiFloat / REF.cpuFloatMulti) * 50)
    const overall = Math.round(singleScore * 0.35 + multiScore * 0.65)
    const scaling = (multiInt + multiFloat) / (singleInt + singleFloat) / cores

    setCpu({
      status: 'Complete', running: false, cores,
      singleInt, singleFloat, multiInt, multiFloat, scaling, score: overall,
    })

    setResults((r) => ({
      ...r,
      cpu: {
        summary: `${overall}/100 · ${fmtOps(singleInt + singleFloat)} single / ${fmtOps(multiInt + multiFloat)} multi ops/s`,
        score: overall,
        grade: scoreToGrade(overall),
        subs: [
          { label: 'Single-core (integer)', value: `${fmtOps(singleInt)} ops/s`, score: clampScore((singleInt / REF.cpuIntSingle) * 100) },
          { label: 'Single-core (float)', value: `${fmtOps(singleFloat)} ops/s`, score: clampScore((singleFloat / REF.cpuFloatSingle) * 100) },
          { label: 'Multi-core (integer)', value: `${fmtOps(multiInt)} ops/s`, score: clampScore((multiInt / REF.cpuIntMulti) * 100) },
          { label: 'Multi-core (float)', value: `${fmtOps(multiFloat)} ops/s`, score: clampScore((multiFloat / REF.cpuFloatMulti) * 100) },
          { label: 'Scaling efficiency', value: `${(scaling * 100).toFixed(0)}% of ${cores} cores`, score: null },
        ],
      },
    }))
  }

  /* ================= GPU ================= */
  const gpuCanvasRef = useRef<HTMLCanvasElement | null>(null)
  const gpuGlRef = useRef<WebGLRenderingContext | null>(null)
  const [gpu, setGpu] = useState({
    status: 'Idle - press run', running: false, particles: null as number | null,
    renderFps: null as number | null, exportFps: null as number | null, exportReadbackMBs: null as number | null,
    aimlGflops: null as number | null, aimlAvailable: true, score: null as number | null,
  })

  function ensureGpuGl(): WebGLRenderingContext | null {
    if (gpuGlRef.current) return gpuGlRef.current
    const canvas = gpuCanvasRef.current
    if (!canvas) return null
    const gl = (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')) as WebGLRenderingContext | null
    gpuGlRef.current = gl
    return gl
  }

  function runGpuRenderPass(): Promise<{ fps: number; score: number }> {
    return new Promise((resolve) => {
      const canvas = gpuCanvasRef.current
      const gl = ensureGpuGl()
      if (!canvas || !gl) { resolve({ fps: 0, score: 0 }); return }
      const rect = canvas.getBoundingClientRect()
      const dpr = window.devicePixelRatio || 1
      canvas.width = Math.max(300, rect.width * dpr)
      canvas.height = 260 * dpr

      const prog = compileProgram(gl, GPU_VERT_SRC, GPU_FRAG_SRC)
      gl.useProgram(prog)

      const N = 32000
      setGpu((g) => ({ ...g, particles: N }))
      const offsets = new Float32Array(N * 2)
      const sizes = new Float32Array(N)
      const colors = new Float32Array(N * 3)
      const phases = new Float32Array(N)
      for (let i = 0; i < N; i++) {
        offsets[i * 2] = Math.random() * 2 - 1
        offsets[i * 2 + 1] = Math.random() * 2 - 1
        sizes[i] = 3 + Math.random() * 10
        colors[i * 3] = 0.35 + Math.random() * 0.3
        colors[i * 3 + 1] = 0.28 + Math.random() * 0.3
        colors[i * 3 + 2] = 0.95
        phases[i] = Math.random() * 10
      }
      const attr = (name: string, data: Float32Array, size: number) => {
        const buf = gl.createBuffer()
        gl.bindBuffer(gl.ARRAY_BUFFER, buf)
        gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW)
        const loc = gl.getAttribLocation(prog, name)
        gl.enableVertexAttribArray(loc)
        gl.vertexAttribPointer(loc, size, gl.FLOAT, false, 0, 0)
      }
      attr('aOffset', offsets, 2)
      attr('aSize', sizes, 1)
      attr('aColor', colors, 3)
      attr('aPhase', phases, 1)
      const uTime = gl.getUniformLocation(prog, 'uTime')

      gl.viewport(0, 0, canvas.width, canvas.height)
      gl.enable(gl.BLEND)
      gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

      let frames = 0
      const start = performance.now()
      const TEST_MS = 3000
      const frame = (t: number) => {
        gl.clearColor(0.02, 0.03, 0.03, 1)
        gl.clear(gl.COLOR_BUFFER_BIT)
        gl.uniform1f(uTime, (t - start) / 1000)
        gl.drawArrays(gl.POINTS, 0, N)
        frames++
        const elapsed = t - start
        if (elapsed < TEST_MS) {
          requestAnimationFrame(frame)
        } else {
          const fps = frames / (elapsed / 1000)
          const score = clampScore((fps / REF.gpuRenderFps) * 100)
          resolve({ fps, score })
        }
      }
      requestAnimationFrame(frame)
    })
  }

  function runGpuExportPass(): Promise<{ fps: number; readbackMBs: number; score: number }> {
    return new Promise((resolve) => {
      const canvas = document.createElement('canvas')
      canvas.width = 2048
      canvas.height = 2048
      const gl = (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')) as WebGLRenderingContext | null
      if (!gl) { resolve({ fps: 0, readbackMBs: 0, score: 0 }); return }

      const prog = compileProgram(gl, GPU_EXPORT_VERT_SRC, GPU_EXPORT_FRAG_SRC)
      gl.useProgram(prog)
      const quad = new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1])
      const buf = gl.createBuffer()
      gl.bindBuffer(gl.ARRAY_BUFFER, buf)
      gl.bufferData(gl.ARRAY_BUFFER, quad, gl.STATIC_DRAW)
      const loc = gl.getAttribLocation(prog, 'aPos')
      gl.enableVertexAttribArray(loc)
      gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0)
      const uTime = gl.getUniformLocation(prog, 'uTime')
      gl.viewport(0, 0, canvas.width, canvas.height)

      let frames = 0
      const start = performance.now()
      const RENDER_MS = 2200
      const frame = (t: number) => {
        gl.uniform1f(uTime, (t - start) / 1000)
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
        gl.finish()
        frames++
        if (t - start < RENDER_MS) {
          requestAnimationFrame(frame)
        } else {
          const fps = frames / ((t - start) / 1000)
          const size = canvas.width * canvas.height * 4
          const out = new Uint8Array(size)
          const READ_MS = 700
          let reads = 0
          const r0 = performance.now()
          while (performance.now() - r0 < READ_MS) {
            gl.readPixels(0, 0, canvas.width, canvas.height, gl.RGBA, gl.UNSIGNED_BYTE, out)
            reads++
          }
          const rElapsed = (performance.now() - r0) / 1000
          const readbackMBs = (reads * size / 1e6) / rElapsed
          const score = clampScore((fps / REF.gpuExportFps) * 50 + (readbackMBs / REF.gpuExportReadbackMBs) * 50)
          resolve({ fps, readbackMBs, score })
        }
      }
      requestAnimationFrame(frame)
    })
  }

  async function runGpuComputePass(): Promise<{ gflops: number; score: number } | null> {
    const gpuNav = (navigator as unknown as { gpu?: any }).gpu
    if (!gpuNav) return null
    try {
      const adapter = await gpuNav.requestAdapter()
      if (!adapter) return null
      const device = await adapter.requestDevice()
      const usage = (window as unknown as { GPUBufferUsage: any }).GPUBufferUsage
      const N = 256
      const size = N * N * 4
      const rand = () => { const a = new Float32Array(N * N); for (let i = 0; i < a.length; i++) a[i] = Math.random(); return a }
      const mk = (u: number, data?: Float32Array) => {
        const buf = device.createBuffer({ size, usage: u, mappedAtCreation: !!data })
        if (data) { new Float32Array(buf.getMappedRange()).set(data); buf.unmap() }
        return buf
      }
      const bufA = mk(usage.STORAGE, rand())
      const bufB = mk(usage.STORAGE, rand())
      const bufC = mk(usage.STORAGE | usage.COPY_SRC)
      const module = device.createShaderModule({ code: MATMUL_WGSL })
      const pipeline = device.createComputePipeline({ layout: 'auto', compute: { module, entryPoint: 'main' } })
      const bindGroup = device.createBindGroup({
        layout: pipeline.getBindGroupLayout(0),
        entries: [
          { binding: 0, resource: { buffer: bufA } },
          { binding: 1, resource: { buffer: bufB } },
          { binding: 2, resource: { buffer: bufC } },
        ],
      })
      const DURATION = 1500
      const start = performance.now()
      let iterations = 0
      while (performance.now() - start < DURATION) {
        const encoder = device.createCommandEncoder()
        const pass = encoder.beginComputePass()
        pass.setPipeline(pipeline)
        pass.setBindGroup(0, bindGroup)
        pass.dispatchWorkgroups(N / 8, N / 8)
        pass.end()
        device.queue.submit([encoder.finish()])
        iterations++
      }
      await device.queue.onSubmittedWorkDone()
      const elapsed = (performance.now() - start) / 1000
      const flops = iterations * 2 * Math.pow(N, 3)
      const gflops = flops / elapsed / 1e9
      const score = clampScore((gflops / REF.gpuAiGflops) * 100)
      device.destroy?.()
      return { gflops, score }
    } catch {
      return null
    }
  }

  async function executeGpuTest() {
    clearResult('gpu')
    setGpu((g) => ({
      ...g,
      running: true,
      status: 'Rendering pass - particle field under load…',
      particles: null,
      renderFps: null,
      exportFps: null,
      exportReadbackMBs: null,
      aimlGflops: null,
      aimlAvailable: true,
      score: null,
    }))
    const render = await runGpuRenderPass()
    setGpu((g) => ({ ...g, status: 'Export pass - 4K offscreen raster + pixel readback…', renderFps: render.fps }))
    const exp = await runGpuExportPass()
    setGpu((g) => ({ ...g, status: 'AI/ML pass - WebGPU matrix-multiply compute…', exportFps: exp.fps, exportReadbackMBs: exp.readbackMBs }))
    const aiml = await runGpuComputePass()

    const parts = [
      { w: 0.4, s: render.score },
      { w: 0.3, s: exp.score },
      { w: 0.3, s: aiml?.score ?? null },
    ].filter((p): p is { w: number; s: number } => p.s !== null)
    const totalW = parts.reduce((a, p) => a + p.w, 0)
    const overall = totalW > 0 ? Math.round(parts.reduce((a, p) => a + p.w * p.s, 0) / totalW) : 0

    setGpu((g) => ({
      ...g, running: false, status: 'Complete', score: overall,
      aimlGflops: aiml?.gflops ?? null, aimlAvailable: aiml !== null,
    }))

    setResults((r) => ({
      ...r,
      gpu: {
        summary: `${overall}/100 · ${device.gpuRenderer}`,
        score: overall,
        grade: scoreToGrade(overall),
        subs: [
          { label: 'Rendering (particle field)', value: `${fmt(render.fps)} fps`, score: render.score },
          { label: 'Export (4K raster + readback)', value: `${fmt(exp.fps)} fps · ${fmt(exp.readbackMBs, 0)} MB/s`, score: exp.score },
          aiml
            ? { label: 'AI/ML (matmul compute)', value: `${fmt(aiml.gflops)} GFLOPS`, score: aiml.score }
            : { label: 'AI/ML (matmul compute)', value: 'unavailable', score: null, note: 'WebGPU not supported in this browser' },
        ],
      },
    }))
  }

  /* ================= RAM ================= */
  const [ram, setRam] = useState({
    status: 'Idle - press run', running: false, bytes: 0,
    writeGBs: null as number | null, readGBs: null as number | null, randomMOpsSec: null as number | null,
    vramUploadMBs: null as number | null, vramDownloadMBs: null as number | null, score: null as number | null,
  })

  function runRamWorkerPass(bytes: number): Promise<{ writeGBs: number; readGBs: number; randomMOpsSec: number }> {
    return new Promise((resolve) => {
      const url = getRamWorkerUrl()
      const w = new Worker(url)
      w.onmessage = (e) => { resolve(e.data); w.terminate() }
      w.postMessage({ bytes })
    })
  }

  async function runVramApprox(): Promise<{ uploadMBs: number; downloadMBs: number; score: number } | null> {
    try {
      const canvas = document.createElement('canvas')
      canvas.width = 2048
      canvas.height = 2048
      const gl = (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')) as WebGLRenderingContext | null
      if (!gl) return null
      const tex = gl.createTexture()
      gl.bindTexture(gl.TEXTURE_2D, tex)
      const size = 2048 * 2048 * 4
      const data = new Uint8Array(size)
      crypto.getRandomValues(data.subarray(0, 65536))

      let uploads = 0
      let t0 = performance.now()
      const UP_MS = 600
      while (performance.now() - t0 < UP_MS) {
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 2048, 2048, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
        uploads++
      }
      gl.finish()
      const upElapsed = (performance.now() - t0) / 1000
      const uploadMBs = (uploads * size / 1e6) / upElapsed

      const fb = gl.createFramebuffer()
      gl.bindFramebuffer(gl.FRAMEBUFFER, fb)
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0)
      const out = new Uint8Array(size)
      let downloads = 0
      const DOWN_MS = 600
      t0 = performance.now()
      while (performance.now() - t0 < DOWN_MS) {
        gl.readPixels(0, 0, 2048, 2048, gl.RGBA, gl.UNSIGNED_BYTE, out)
        downloads++
      }
      const downElapsed = (performance.now() - t0) / 1000
      const downloadMBs = (downloads * size / 1e6) / downElapsed

      const score = clampScore((uploadMBs / REF.vramUploadMBs) * 50 + (downloadMBs / REF.vramDownloadMBs) * 50)
      return { uploadMBs, downloadMBs, score }
    } catch {
      return null
    }
  }

  async function executeRamTest() {
    const bytes = pickBytesForDevice(256 * 1024 * 1024, 128 * 1024 * 1024, 64 * 1024 * 1024)
    clearResult('ram')
    setRam({
      running: true,
      bytes,
      status: 'Sequential write / read / random-access passes…',
      writeGBs: null,
      readGBs: null,
      randomMOpsSec: null,
      vramUploadMBs: null,
      vramDownloadMBs: null,
      score: null,
    })
    const pass = await runRamWorkerPass(bytes)

    let vram: { uploadMBs: number; downloadMBs: number; score: number } | null = null
    if (device.memArch === 'discrete') {
      setRam((r) => ({ ...r, status: 'Discrete GPU detected - sampling VRAM upload/download bandwidth…' }))
      vram = await runVramApprox()
    }

    const score = clampScore(
      (pass.writeGBs / REF.ramWriteGBs) * 40 +
      (pass.readGBs / REF.ramReadGBs) * 40 +
      (pass.randomMOpsSec / REF.ramRandomMOpsSec) * 20
    )

    setRam({
      status: 'Complete', running: false, bytes,
      writeGBs: pass.writeGBs, readGBs: pass.readGBs, randomMOpsSec: pass.randomMOpsSec,
      vramUploadMBs: vram?.uploadMBs ?? null, vramDownloadMBs: vram?.downloadMBs ?? null,
      score,
    })

    const subs: SubResult[] = [
      { label: 'Sequential write', value: `${fmt(pass.writeGBs, 2)} GB/s`, score: clampScore((pass.writeGBs / REF.ramWriteGBs) * 100) },
      { label: 'Sequential read', value: `${fmt(pass.readGBs, 2)} GB/s`, score: clampScore((pass.readGBs / REF.ramReadGBs) * 100) },
      { label: 'Random access', value: `${fmt(pass.randomMOpsSec, 0)} M ops/s`, score: clampScore((pass.randomMOpsSec / REF.ramRandomMOpsSec) * 100) },
    ]
    if (device.memArch === 'unified') {
      subs.push({ label: 'Memory architecture', value: 'Unified - GPU shares this pool', score: null })
    } else if (vram) {
      subs.push({ label: 'VRAM upload (approx.)', value: `${fmt(vram.uploadMBs, 0)} MB/s`, score: clampScore((vram.uploadMBs / REF.vramUploadMBs) * 100) })
      subs.push({ label: 'VRAM download (approx.)', value: `${fmt(vram.downloadMBs, 0)} MB/s`, score: clampScore((vram.downloadMBs / REF.vramDownloadMBs) * 100) })
    } else if (device.memArch === 'discrete') {
      subs.push({ label: 'VRAM bandwidth', value: 'unavailable', score: null, note: 'WebGL context unavailable for VRAM sampling' })
    }

    setResults((r) => ({
      ...r,
      ram: {
        summary: `${score}/100 · ${fmt(pass.writeGBs, 1)} GB/s write / ${fmt(pass.readGBs, 1)} GB/s read`,
        score, grade: scoreToGrade(score), subs,
      },
    }))
  }

  /* ================= SSD ================= */
  const [ssd, setSsd] = useState({
    status: 'Idle - press run', running: false, engine: '-', bytes: 0,
    writeMBs: null as number | null, readMBs: null as number | null, score: null as number | null,
  })

  async function runIndexedDbFallback(chunk: Uint8Array, total: number, onStatus: (s: string) => void): Promise<{ writeMBs: number; readMBs: number; sampleMs: number }> {
    return new Promise((resolve, reject) => {
      const runId = `run-${Date.now()}-${Math.random().toString(36).slice(2)}`
      const req = indexedDB.open('bx-bench-db', 2)
      req.onupgradeneeded = () => {
        const db = req.result
        if (!db.objectStoreNames.contains('chunks')) db.createObjectStore('chunks')
      }
      req.onerror = () => reject(req.error)
      req.onsuccess = () => {
        const db = req.result
        const count = Math.ceil(total / chunk.byteLength)
        let writeBytes = 0
        let readBytes = 0
        let writeMs = 0
        let readMs = 0
        let pass = 0
        const startedAt = performance.now()

        const runPass = () => {
          pass++
          crypto.getRandomValues(chunk.subarray(0, Math.min(65536, chunk.byteLength)))
          onStatus(`IndexedDB · write/read sampling pass ${pass}…`)
          const t0 = performance.now()
          const tx = db.transaction('chunks', 'readwrite')
          const store = tx.objectStore('chunks')
          for (let i = 0; i < count; i++) store.put(chunk, `${runId}-${pass}-${i}`)
          tx.oncomplete = () => {
            const t1 = performance.now()
            writeMs += t1 - t0
            writeBytes += count * chunk.byteLength

            const t2 = performance.now()
            const tx2 = db.transaction('chunks', 'readonly')
            const store2 = tx2.objectStore('chunks')
            let passReadBytes = 0
            for (let i = 0; i < count; i++) {
              const getReq = store2.get(`${runId}-${pass}-${i}`)
              getReq.onsuccess = () => {
                passReadBytes += (getReq.result as Uint8Array | undefined)?.byteLength ?? 0
              }
            }
            tx2.oncomplete = () => {
              const t3 = performance.now()
              readMs += t3 - t2
              readBytes += passReadBytes
              const elapsed = performance.now() - startedAt
              if (elapsed < STORAGE_MIN_SAMPLE_MS) {
                runPass()
                return
              }

              const txDel = db.transaction('chunks', 'readwrite')
              const storeDel = txDel.objectStore('chunks')
              const range = IDBKeyRange.bound(`${runId}-`, `${runId}.\uffff`)
              storeDel.delete(range)
              txDel.oncomplete = () => {
                db.close()
                resolve({
                  writeMBs: (writeBytes / 1e6) / (writeMs / 1000),
                  readMBs: (readBytes / 1e6) / (readMs / 1000),
                  sampleMs: elapsed,
                })
              }
            }
            tx2.onerror = () => reject(tx2.error)
          }
          tx.onerror = () => reject(tx.error)
        }

        runPass()
      }
    })
  }

  async function executeSsdTest() {
    const TOTAL = pickBytesForDevice(128 * 1024 * 1024, 64 * 1024 * 1024, 32 * 1024 * 1024)
    const CHUNK = 4 * 1024 * 1024
    const chunk = new Uint8Array(CHUNK)
    crypto.getRandomValues(chunk.subarray(0, 65536))
    setSsd({
      status: 'Preparing fresh storage sample…',
      running: true,
      engine: '-',
      bytes: TOTAL,
      writeMBs: null,
      readMBs: null,
      score: null,
    })
    clearResult('ssd')

    let engine = 'OPFS'
    let writeMBs = 0
    let readMBs = 0
    let sampleMs = 0

    try {
      if (!('storage' in navigator) || !navigator.storage.getDirectory) throw new Error('no-opfs')
      setSsd((s) => ({ ...s, status: 'OPFS · polling write/read for at least 5 seconds…' }))
      const root = await navigator.storage.getDirectory()
      const filename = `bx-bench-${Date.now()}-${Math.random().toString(36).slice(2)}.bin`
      const handle = await root.getFileHandle(filename, { create: true })
      let writeBytes = 0
      let readBytes = 0
      let writeMs = 0
      let readMs = 0
      let pass = 0
      const startedAt = performance.now()

      do {
        pass++
        crypto.getRandomValues(chunk.subarray(0, 65536))
        setSsd((s) => ({ ...s, status: `OPFS · write/read sampling pass ${pass}…` }))
        const writable = await handle.createWritable()
        let written = 0
        const t0 = performance.now()
        while (written < TOTAL) {
          await writable.write(chunk)
          written += CHUNK
        }
        await writable.close()
        const t1 = performance.now()
        writeMs += t1 - t0
        writeBytes += written

        const t2 = performance.now()
        const file = await handle.getFile()
        const ab = await file.arrayBuffer()
        const t3 = performance.now()
        readMs += t3 - t2
        readBytes += ab.byteLength
        sampleMs = performance.now() - startedAt
      } while (sampleMs < STORAGE_MIN_SAMPLE_MS)

      writeMBs = (writeBytes / 1e6) / (writeMs / 1000)
      readMBs = (readBytes / 1e6) / (readMs / 1000)

      await root.removeEntry(filename)
    } catch {
      engine = 'IndexedDB'
      const res = await runIndexedDbFallback(chunk, TOTAL, (status) => setSsd((s) => ({ ...s, status })))
      writeMBs = res.writeMBs
      readMBs = res.readMBs
      sampleMs = res.sampleMs
    }

    const score = clampScore((writeMBs / REF.ssdWriteMBs) * 45 + (readMBs / REF.ssdReadMBs) * 55)
    setSsd({ status: 'Complete', running: false, engine, bytes: TOTAL, writeMBs, readMBs, score })

    setResults((r) => ({
      ...r,
      ssd: {
        summary: `${score}/100 · ${fmt(writeMBs, 0)} MB/s write / ${fmt(readMBs, 0)} MB/s read (${engine})`,
        score, grade: scoreToGrade(score),
        subs: [
          { label: `Sequential write (${engine})`, value: `${fmt(writeMBs, 0)} MB/s`, score: clampScore((writeMBs / REF.ssdWriteMBs) * 100) },
          { label: `Sequential read (${engine})`, value: `${fmt(readMBs, 0)} MB/s`, score: clampScore((readMBs / REF.ssdReadMBs) * 100) },
          { label: 'Sampling duration', value: `${fmt(sampleMs / 1000, 1)} seconds`, score: null },
        ],
      },
    }))
  }

  /* ================= Web browsing ================= */
  const [web, setWeb] = useState({
    status: 'Idle - press run', running: false,
    domChurnOpsSec: null as number | null, layoutOpsSec: null as number | null,
    textEditOpsSec: null as number | null, listOpsSec: null as number | null,
    jsonOpsSec: null as number | null, score: null as number | null,
  })

  async function executeWebTest() {
    clearResult('web')
    setWeb({
      running: true,
      status: 'Preparing offscreen workspace…',
      domChurnOpsSec: null,
      layoutOpsSec: null,
      textEditOpsSec: null,
      listOpsSec: null,
      jsonOpsSec: null,
      score: null,
    })
    const container = document.createElement('div')
    container.style.position = 'fixed'
    container.style.top = '-9999px'
    container.style.left = '-9999px'
    container.style.width = '300px'
    document.body.appendChild(container)
    const input = document.createElement('input')
    container.appendChild(input)
    const SEG = 650
    let sink = 0

    try {
      setWeb((w) => ({ ...w, status: 'DOM churn - creating & removing list nodes…' }))
      await sleep(20)
      let end = performance.now() + SEG
      let iters = 0
      while (performance.now() < end) {
        for (let i = 0; i < 50; i++) {
          const el = document.createElement('div')
          el.textContent = `item ${i}`
          container.appendChild(el)
        }
        while (container.childNodes.length > 1) container.removeChild(container.lastChild as ChildNode)
        iters++
      }
      const domChurnOpsSec = iters / (SEG / 1000)
      setWeb((w) => ({ ...w, domChurnOpsSec }))

      setWeb((w) => ({ ...w, status: 'Layout - forced reflow pass…' }))
      await sleep(20)
      end = performance.now() + SEG
      iters = 0
      while (performance.now() < end) {
        input.style.height = `${10 + (iters % 40)}px`
        sink += input.offsetHeight
        iters++
      }
      const layoutOpsSec = iters / (SEG / 1000)
      setWeb((w) => ({ ...w, layoutOpsSec }))

      setWeb((w) => ({ ...w, status: 'Text editing - simulated typing…' }))
      await sleep(20)
      end = performance.now() + SEG
      iters = 0
      let text = ''
      while (performance.now() < end) {
        text += 'a'
        if (text.length > 200) text = ''
        input.value = text
        input.dispatchEvent(new Event('input', { bubbles: true }))
        iters++
      }
      const textEditOpsSec = iters / (SEG / 1000)
      setWeb((w) => ({ ...w, textEditOpsSec }))

      setWeb((w) => ({ ...w, status: 'List sort & filter - re-render pass…' }))
      await sleep(20)
      const data = Array.from({ length: 2000 }, (_, i) => ({ id: i, name: `Item ${i}`, value: Math.random() }))
      end = performance.now() + SEG
      iters = 0
      while (performance.now() < end) {
        const sorted = [...data].sort((a, b) => a.value - b.value)
        const filtered = sorted.filter((d) => d.value > 0.5)
        sink += filtered.length
        iters++
      }
      const listOpsSec = iters / (SEG / 1000)
      setWeb((w) => ({ ...w, listOpsSec }))

      setWeb((w) => ({ ...w, status: 'JSON - serialize & parse pass…' }))
      await sleep(20)
      const obj = { id: 1, items: Array.from({ length: 200 }, (_, i) => ({ i, name: `n${i}`, tags: ['a', 'b', 'c'] })) }
      end = performance.now() + SEG
      iters = 0
      while (performance.now() < end) {
        const s = JSON.stringify(obj)
        const parsed = JSON.parse(s) as { items: unknown[] }
        sink += parsed.items.length
        iters++
      }
      const jsonOpsSec = iters / (SEG / 1000)

      const subScores = [
        clampScore((domChurnOpsSec / REF.webDomChurn) * 100),
        clampScore((layoutOpsSec / REF.webLayout) * 100),
        clampScore((textEditOpsSec / REF.webTextEdit) * 100),
        clampScore((listOpsSec / REF.webListSort) * 100),
        clampScore((jsonOpsSec / REF.webJson) * 100),
      ]
      const geo = Math.pow(subScores.reduce((a, b) => a * b, 1), 1 / subScores.length)
      const score = clampScore(geo)

      setWeb({
        status: 'Complete', running: false,
        domChurnOpsSec, layoutOpsSec, textEditOpsSec, listOpsSec, jsonOpsSec, score,
      })

      setResults((r) => ({
        ...r,
        web: {
          summary: `${score}/100 · Speedometer-style DOM & JS workload suite`,
          score, grade: scoreToGrade(score),
          subs: [
            { label: 'DOM churn (create/remove)', value: `${fmt(domChurnOpsSec, 0)} batches/s`, score: subScores[0] },
            { label: 'Forced layout / reflow', value: `${fmt(layoutOpsSec, 0)} reads/s`, score: subScores[1] },
            { label: 'Text input simulation', value: `${fmt(textEditOpsSec, 0)} edits/s`, score: subScores[2] },
            { label: 'List sort & filter', value: `${fmt(listOpsSec, 0)} passes/s`, score: subScores[3] },
            { label: 'JSON serialize/parse', value: `${fmt(jsonOpsSec, 0)} passes/s`, score: subScores[4] },
          ],
        },
      }))
    } finally {
      document.body.removeChild(container)
    }
  }

  /* ================= Battery ================= */
  const batteryObjRef = useRef<any>(null)
  const sessionBatteryRef = useRef<{ level: number; time: number; charging: boolean } | null>(null)
  const [battery, setBattery] = useState({
    supported: '-', level: null as number | null, charging: null as boolean | null,
    time: '-', drainSample: '-', drainRunning: false,
    sessionDrain: '-', sessionScore: null as number | null,
  })

  async function ensureBatteryObj(): Promise<any | null> {
    if (batteryObjRef.current) return batteryObjRef.current
    const nav = navigator as unknown as { getBattery?: () => Promise<any> }
    if (!nav.getBattery) return null
    try {
      const b = await nav.getBattery()
      batteryObjRef.current = b
      return b
    } catch {
      return null
    }
  }

  async function markSessionBatteryStart() {
    if (sessionBatteryRef.current) return
    const b = await ensureBatteryObj()
    if (!b) return
    sessionBatteryRef.current = { level: b.level, time: performance.now(), charging: b.charging }
  }

  function updateBatteryUI() {
    const b = batteryObjRef.current
    if (!b) return
    const level = Math.round(b.level * 100)
    const time = b.charging
      ? (isFinite(b.chargingTime) ? `${Math.round(b.chargingTime / 60)} min to full` : 'calculating…')
      : (isFinite(b.dischargingTime) ? `${Math.round(b.dischargingTime / 60)} min to empty` : 'calculating…')
    setBattery((s) => ({ ...s, level, charging: b.charging, time }))
  }

  async function executeBatteryTest() {
    clearResult('battery')
    const b = await ensureBatteryObj()
    if (!b) {
      setBattery((s) => ({ ...s, supported: 'Not supported in this browser' }))
      setResults((r) => ({ ...r, battery: { summary: 'API not supported', score: null, grade: 'not available', subs: [] } }))
      return
    }
    try {
      setBattery((s) => ({ ...s, supported: 'Supported' }))
      updateBatteryUI()
      b.addEventListener('levelchange', updateBatteryUI)
      b.addEventListener('chargingchange', updateBatteryUI)

      await markSessionBatteryStart()
      const base = sessionBatteryRef.current
      let sessionDrain = 'not enough runtime to measure - run a test first'
      let sessionScore: number | null = null
      if (base) {
        const elapsedMin = (performance.now() - base.time) / 60000
        const deltaPct = (base.level - b.level) * 100
        if (base.charging || b.charging) {
          sessionDrain = 'charging - drain not measurable'
        } else if (deltaPct <= 0 || elapsedMin <= 0) {
          sessionDrain = 'no measurable drop yet this session'
        } else {
          const pctPerHour = (deltaPct / elapsedMin) * 60
          sessionScore = clampScore(100 - (pctPerHour / REF.battDrainPctPerHour) * 100)
          sessionDrain = `~${pctPerHour.toFixed(1)}%/hr, extrapolated from ${deltaPct.toFixed(1)}% over ${elapsedMin.toFixed(1)} min of testing`
        }
      }
      setBattery((s) => ({ ...s, sessionDrain, sessionScore }))

      setResults((r) => ({
        ...r,
        battery: {
          summary: `${Math.round(b.level * 100)}% · ${b.charging ? 'charging' : 'on battery'}`,
          score: sessionScore,
          grade: sessionScore !== null ? scoreToGrade(sessionScore) : (b.charging ? 'charging' : 'read'),
          subs: [
            { label: 'Charge level', value: `${Math.round(b.level * 100)}%`, score: null },
            { label: 'Session drain (since first test)', value: sessionDrain, score: sessionScore },
          ],
        },
      }))
    } catch {
      setBattery((s) => ({ ...s, supported: 'Blocked or unavailable' }))
    }
  }

  async function sampleBatteryDrain() {
    const b = batteryObjRef.current
    if (!b) return
    setBattery((s) => ({ ...s, drainRunning: true, drainSample: 'sampling…' }))
    const startLevel = b.level
    const startTime = performance.now()
    await sleep(30000)
    const endLevel = b.level
    const elapsedMin = (performance.now() - startTime) / 60000
    const deltaPct = (startLevel - endLevel) * 100
    const drainSample = deltaPct <= 0 ? 'no measurable drop (charging or idle)' : `~${(deltaPct / elapsedMin * 60).toFixed(1)}%/hr at this load`
    setBattery((s) => ({ ...s, drainRunning: false, drainSample }))
  }

  /* ================= Display ================= */
  const [display, setDisplay] = useState({
    res: '-', dpr: '-', color: '-', gamut: '-', hdr: '-', hz: '-', measuring: false,
  })

  useEffect(() => {
    let gamut = 'srgb'
    if (window.matchMedia('(color-gamut: rec2020)').matches) gamut = 'rec2020'
    else if (window.matchMedia('(color-gamut: p3)').matches) gamut = 'display-p3'
    setDisplay((d) => ({
      ...d,
      res: `${screen.width} × ${screen.height}`,
      dpr: `${window.devicePixelRatio || 1}×`,
      color: `${screen.colorDepth}-bit`,
      gamut,
      hdr: window.matchMedia('(dynamic-range: high)').matches ? 'Supported' : 'Not detected',
    }))
  }, [])

  function executeDisplayTest(): Promise<void> {
    return new Promise((resolve) => {
      setDisplay((d) => ({ ...d, measuring: true, hz: 'measuring…' }))
      let frames = 0
      const samples: number[] = []
      let last = performance.now()
      const tick = (t: number) => {
        frames++
        samples.push(t - last)
        last = t
        if (frames < 90) {
          requestAnimationFrame(tick)
        } else {
          const sorted = samples.slice(10).sort((a, b) => a - b)
          const median = sorted[Math.floor(sorted.length / 2)]
          const hz = Math.round(1000 / median)
          setDisplay((d) => ({ ...d, hz: `${hz} Hz (approx)`, measuring: false }))
          setResults((r) => ({ ...r, display: { summary: `${screen.width}×${screen.height} · ${hz}Hz`, score: null, grade: 'read', subs: [] } }))
          resolve()
        }
      }
      requestAnimationFrame(tick)
    })
  }

  const colorSequence = ['#ff0000', '#00ff00', '#0000ff', '#ffffff', '#000000', 'linear-gradient(90deg,#000,#fff)']
  const [fsSequence, setFsSequence] = useState<string[] | null>(null)
  const [fsIndex, setFsIndex] = useState(0)
  function showFullscreenColor(sequence: string[]) { setFsSequence(sequence); setFsIndex(0) }
  function advanceFullscreen() {
    if (!fsSequence) return
    if (fsIndex + 1 >= fsSequence.length) { setFsSequence(null); return }
    setFsIndex((i) => i + 1)
  }
  useEffect(() => {
    if (!fsSequence) return
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setFsSequence(null); else advanceFullscreen() }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fsSequence, fsIndex])

  /* ================= Speakers ================= */
  const audioCtxRef = useRef<AudioContext | null>(null)
  const activeOscRef = useRef<OscillatorNode | null>(null)
  const [speakers, setSpeakers] = useState({ freq: 440, ctxStatus: 'not started', channels: '-' })

  function ensureAudioCtx(): AudioContext {
    if (!audioCtxRef.current) {
      const Ctx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext
      const ctx = new Ctx()
      audioCtxRef.current = ctx
      setSpeakers((s) => ({ ...s, ctxStatus: `running · ${ctx.sampleRate}Hz`, channels: `${ctx.destination.maxChannelCount} max` }))
      setResults((r) => ({ ...r, speakers: { summary: 'Audio context started', score: null, grade: 'tested', subs: [] } }))
    }
    const ctx = audioCtxRef.current
    if (ctx.state === 'suspended') ctx.resume()
    return ctx
  }
  function stopAudio() {
    if (activeOscRef.current) { try { activeOscRef.current.stop() } catch { /* already stopped */ } activeOscRef.current = null }
  }
  function playTone(pan: number) {
    stopAudio()
    const ctx = ensureAudioCtx()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    gain.gain.value = 0.18
    osc.frequency.value = speakers.freq
    osc.type = 'sine'
    const panner = ctx.createStereoPanner ? ctx.createStereoPanner() : null
    if (panner) { panner.pan.value = pan; osc.connect(gain).connect(panner).connect(ctx.destination) }
    else { osc.connect(gain).connect(ctx.destination) }
    osc.start()
    activeOscRef.current = osc
  }
  function playSweep() {
    stopAudio()
    const ctx = ensureAudioCtx()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    gain.gain.value = 0.15
    osc.type = 'sine'
    osc.frequency.setValueAtTime(20, ctx.currentTime)
    osc.frequency.exponentialRampToValueAtTime(20000, ctx.currentTime + 8)
    osc.connect(gain).connect(ctx.destination)
    osc.start()
    activeOscRef.current = osc
    const startT = performance.now()
    const update = () => {
      if (activeOscRef.current !== osc) return
      const elapsed = (performance.now() - startT) / 1000
      if (elapsed > 8) return
      const freq = 20 * Math.pow(1000, elapsed / 8)
      setSpeakers((s) => ({ ...s, freq: Math.min(20000, Math.round(freq)) }))
      requestAnimationFrame(update)
    }
    requestAnimationFrame(update)
    osc.stop(ctx.currentTime + 8)
  }

  /* ================= Full run ================= */
  const [fullRun, setFullRun] = useState({ active: false, progress: 0, label: '' })

  async function runFullBenchmark() {
    await markSessionBatteryStart()
    setFullRun({ active: true, progress: 0, label: 'Starting…' })
    setActiveTab('cpu')
    const steps: Array<{ label: string; weight: number; fn: () => Promise<void> }> = [
      { label: 'CPU · single & multi-core', weight: ESTIMATE_MS.cpu, fn: executeCpuTest },
      { label: 'GPU · rendering, export, AI/ML', weight: ESTIMATE_MS.gpu, fn: executeGpuTest },
      { label: 'Memory · bandwidth & latency', weight: ESTIMATE_MS.ram, fn: executeRamTest },
      { label: 'Storage · read & write throughput', weight: ESTIMATE_MS.ssd, fn: executeSsdTest },
      { label: 'Web · DOM & JS workload suite', weight: ESTIMATE_MS.web, fn: executeWebTest },
      { label: 'Battery · session drain', weight: ESTIMATE_MS.battery, fn: executeBatteryTest },
      { label: 'Display · refresh rate', weight: ESTIMATE_MS.display, fn: executeDisplayTest },
    ]
    let done = 0
    for (const step of steps) {
      setFullRun((f) => ({ ...f, label: step.label }))
      await step.fn()
      done += step.weight
      setFullRun((f) => ({ ...f, progress: Math.min(100, Math.round((done / TOTAL_ESTIMATE_MS) * 100)) }))
    }
    setFullRun({ active: false, progress: 100, label: 'Complete' })
    setActiveTab('report')
  }

  /* ================= Report ================= */
  const OVERALL_WEIGHTS: Partial<Record<ResultKey, number>> = { cpu: 0.25, gpu: 0.25, ram: 0.15, ssd: 0.15, web: 0.2 }
  function computeOverall(): number | null {
    const parts = (Object.entries(OVERALL_WEIGHTS) as [ResultKey, number][])
      .map(([key, weight]) => ({ weight, score: results[key]?.score }))
      .filter((p): p is { weight: number; score: number } => typeof p.score === 'number')
    if (!parts.length) return null
    const totalWeight = parts.reduce((a, p) => a + p.weight, 0)
    return Math.round(parts.reduce((a, p) => a + p.weight * p.score, 0) / totalWeight)
  }
  const overall = computeOverall()

  async function copyReport() {
    const lines = [
      'NexaBench - NexaCore device report',
      '-'.repeat(28),
      `Platform: ${device.platform}`,
      `Processor: ${device.processor}`,
      `Logical cores: ${device.cores}`,
      `Core topology: ${device.coreTopology}`,
      `CPU frequency: ${device.cpuFrequency}`,
      `GPU vendor: ${device.gpuVendor}`,
      `GPU renderer: ${device.gpuRenderer}`,
      `GPU adapter: ${device.gpuAdapter}`,
      `GPU generation: ${device.gpuGeneration}`,
      `GPU cores: ${device.gpuCores}`,
      '-'.repeat(28),
    ]
    TAB_ORDER.forEach((k) => {
      const r = results[k]
      lines.push(`${LABELS[k]}: ${r ? r.summary + ' (' + r.grade + ')' : 'not run'}`)
      r?.subs.forEach((s) => lines.push(`  · ${s.label}: ${s.value}${s.score !== null ? ' [' + s.score + ']' : ''}`))
    })
    if (overall !== null) {
      lines.push('-'.repeat(28))
      lines.push(`Overall score: ${overall} (${scoreToGrade(overall)})`)
    }
    lines.push('-'.repeat(28), device.ua)
    const text = lines.join('\n')
    try { await navigator.clipboard.writeText(text) } catch { /* clipboard unavailable */ }
  }

  const anyRunning = cpu.running || gpu.running || ram.running || ssd.running || web.running || fullRun.active
  const dot = (key: ResultKey) => {
    if (key === 'cpu' && cpu.running) return 'running'
    if (key === 'gpu' && gpu.running) return 'running'
    if (key === 'ram' && ram.running) return 'running'
    if (key === 'ssd' && ssd.running) return 'running'
    if (key === 'web' && web.running) return 'running'
    const r = results[key]
    if (!r) return ''
    if (r.grade === 'not available') return 'na'
    return typeof r.score === 'number' && r.score < 40 ? 'warn' : 'pass'
  }

  return (
    <>
      {fsSequence && (
        <div id="bx-fsOverlay" style={{ display: 'flex' }} onClick={advanceFullscreen}>
          <div style={{ width: '100%', height: '100%', background: fsSequence[fsIndex] }} />
          <div className="bx-hint">click / tap or press any key to advance - ESC to exit</div>
        </div>
      )}

      <aside className="bx-overall-dock" aria-label="Overall device score">
        <div className="bx-overall-dock-label">Overall</div>
        <div className={`bx-overall-dock-score ${scoreToneClass(overall)}`}>{overall ?? '--'}</div>
        <div className={`bx-overall-dock-grade ${scoreToneClass(overall)}`}>
          {overall === null ? 'run tests' : scoreToGrade(overall)}
        </div>
      </aside>

      <header className="bx-header">
        <div className="bx-scanline" />
        <div className="bx-eyebrow">NexaBench · in-browser diagnostics</div>
        <h1>Know what you're<br /><span>actually</span> running on.</h1>
        <p className="bx-lede">
          CPU, GPU, memory, storage and real-DOM web workload stress tests that run entirely in
          this tab - single and multi-core throughput, rendering / export / AI compute on the GPU,
          RAM bandwidth, disk read/write, and a Speedometer-style browsing suite - plus a battery
          efficiency score measured from the drain those tests cause. Run everything for a full
          report, or drill into one test at a time.
        </p>

        <div className="bx-device-strip">
          <div className="bx-cell"><div className="bx-k">Platform</div><div className="bx-v">{device.platform}</div></div>
          <div className="bx-cell"><div className="bx-k">Processor</div><div className="bx-v">{device.processor}</div></div>
          <div className="bx-cell"><div className="bx-k">Logical cores</div><div className="bx-v">{device.cores}</div></div>
          <div className="bx-cell"><div className="bx-k">Core topology</div><div className="bx-v">{device.coreTopology}</div></div>
          <div className="bx-cell"><div className="bx-k">CPU frequency</div><div className="bx-v">{device.cpuFrequency}</div></div>
          <div className="bx-cell"><div className="bx-k">Memory (approx)</div><div className="bx-v">{device.memory}</div></div>
          <div className="bx-cell"><div className="bx-k">GPU vendor</div><div className="bx-v">{device.gpuVendor}</div></div>
          <div className="bx-cell"><div className="bx-k">GPU</div><div className="bx-v">{device.gpuRenderer}</div></div>
          <div className="bx-cell"><div className="bx-k">GPU adapter</div><div className="bx-v">{device.gpuAdapter}</div></div>
          <div className="bx-cell"><div className="bx-k">GPU generation</div><div className="bx-v">{device.gpuGeneration}</div></div>
          <div className="bx-cell"><div className="bx-k">GPU cores</div><div className="bx-v">{device.gpuCores}</div></div>
          <div className="bx-cell"><div className="bx-k">Pixel ratio</div><div className="bx-v">{device.pixelRatio}</div></div>
        </div>
        <p className="bx-hardware-note">
          Exact P/E-core counts, live CPU frequency, GPU core counts and vendor driver IDs are hidden
          by browser privacy sandboxes on many Intel, AMD, NVIDIA and Apple devices; NexaBench shows
          native WebGL/WebGPU/UA Client Hint data wherever the browser exposes it.
        </p>

        <div className="bx-fullrun">
          <div className="bx-fullrun-copy">
            <div className="bx-fullrun-title">Run everything</div>
            <div className="bx-fullrun-sub">
              CPU, GPU, RAM, storage, web, battery &amp; display refresh - estimated <b>~{Math.round(TOTAL_ESTIMATE_MS / 1000)}s</b>
            </div>
          </div>
          <button className="bx-btn" disabled={anyRunning} onClick={runFullBenchmark}>
            {fullRun.active ? 'Running…' : 'Run full benchmark'}
          </button>
          <div className={`bx-progress-wrap ${fullRun.active ? 'active' : ''}`} style={{ flexBasis: '100%' }}>
            <div className="bx-progress-track"><i className="bx-progress-fill" style={{ width: `${fullRun.progress}%` }} /></div>
            <span className="bx-progress-label">{fullRun.progress}% · {fullRun.label}</span>
          </div>
        </div>
      </header>

      <nav className="bx-nav">
        {([['cpu', '01'], ['gpu', '02'], ['ram', '03'], ['ssd', '04'], ['web', '05'], ['battery', '06'], ['display', '07'], ['speakers', '08']] as [ResultKey, string][]).map(([key, num]) => (
          <button key={key} className={`bx-tab ${activeTab === key ? 'active' : ''}`} onClick={() => setActiveTab(key)}>
            <span className="bx-num">{num}</span> {TAB_LABELS[key]} <span className={`bx-dot ${dot(key)}`} />
          </button>
        ))}
        <button className={`bx-tab ${activeTab === 'report' ? 'active' : ''}`} onClick={() => setActiveTab('report')}>
          <span className="bx-num">#</span> Report
        </button>
      </nav>

      <main className="bx-main">
        {/* ---- CPU ---- */}
        <section className={`bx-panel ${activeTab === 'cpu' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>CPU throughput</h2>
              <p>Runs blended integer + floating-point workloads for a fixed time on a single worker thread, then again split across every logical core - the same single-core / multi-core split industry benchmarks use.</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn" disabled={anyRunning} onClick={executeCpuTest}>Run test</button>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout">
              <div className="bx-stat-row"><span className="bx-label">Status</span><span className="bx-val">{cpu.status}</span></div>
              <div className="bx-subhead">Single-core</div>
              <div className="bx-stat-row"><span className="bx-label">Integer ops/sec</span><span className="bx-val big">{cpu.singleInt !== null ? fmtOps(cpu.singleInt) : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Floating point ops/sec</span><span className="bx-val big">{cpu.singleFloat !== null ? fmtOps(cpu.singleFloat) : '-'}</span></div>
              <div className="bx-subhead">Multi-core ({cpu.cores} threads)</div>
              <div className="bx-stat-row"><span className="bx-label">Integer ops/sec</span><span className="bx-val big">{cpu.multiInt !== null ? fmtOps(cpu.multiInt) : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Floating point ops/sec</span><span className="bx-val big">{cpu.multiFloat !== null ? fmtOps(cpu.multiFloat) : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Scaling efficiency</span><span className="bx-val">{cpu.scaling !== null ? `${(cpu.scaling * 100).toFixed(0)}% of ${cpu.cores} cores` : '-'}</span></div>
            </div>
            <div className="bx-readout bx-score-block">
              <div className="bx-score-label">CPU score</div>
              <div className={`bx-score-num ${scoreToneClass(cpu.score)}`}>{cpu.score ?? '--'}</div>
              <div className={`bx-score-grade ${scoreToneClass(cpu.score)}`}>{scoreToGrade(cpu.score)}</div>
              <p className="bx-note">Runs entirely off the main thread via Web Workers, so the UI stays smooth while it runs. Score is relative (0–100), not an absolute index.</p>
            </div>
          </div>
        </section>

        {/* ---- GPU ---- */}
        <section className={`bx-panel ${activeTab === 'gpu' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>GPU compute &amp; rendering</h2>
              <p>Three passes: an animated WebGL particle field (rendering), a 4K offscreen raster with pixel readback (export/encode workloads), and a WebGPU matrix-multiply compute shader (the core op behind AI/ML inference).</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn" disabled={anyRunning} onClick={executeGpuTest}>Run test</button>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout" style={{ padding: 12 }}>
              <canvas ref={gpuCanvasRef} className="bx-canvas" height={260} />
            </div>
            <div className="bx-readout">
              <div className="bx-stat-row"><span className="bx-label">Status</span><span className="bx-val" style={{ fontSize: 12 }}>{gpu.status}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Renderer</span><span className="bx-val" style={{ maxWidth: 220, fontSize: 12 }}>{device.gpuRenderer}</span></div>
              <div className="bx-subhead">Rendering</div>
              <div className="bx-stat-row"><span className="bx-label">Particles / FPS</span><span className="bx-val">{gpu.particles?.toLocaleString() ?? '-'} · {gpu.renderFps ? fmt(gpu.renderFps) : '-'} fps</span></div>
              <div className="bx-subhead">Export</div>
              <div className="bx-stat-row"><span className="bx-label">4K raster FPS / readback</span><span className="bx-val">{gpu.exportFps ? fmt(gpu.exportFps) : '-'} fps · {gpu.exportReadbackMBs ? fmt(gpu.exportReadbackMBs, 0) : '-'} MB/s</span></div>
              <div className="bx-subhead">AI / ML compute</div>
              <div className="bx-stat-row"><span className="bx-label">Matmul throughput</span><span className="bx-val">{gpu.aimlGflops ? `${fmt(gpu.aimlGflops)} GFLOPS` : (gpu.status === 'Complete' ? 'unavailable (needs WebGPU)' : '-')}</span></div>
              <div className="bx-score-block" style={{ paddingTop: 16 }}>
                <div className="bx-score-label">GPU score</div>
                <div className={`bx-score-num ${scoreToneClass(gpu.score)}`}>{gpu.score ?? '--'}</div>
                <div className={`bx-score-grade ${scoreToneClass(gpu.score)}`}>{scoreToGrade(gpu.score)}</div>
              </div>
            </div>
          </div>
        </section>

        {/* ---- RAM ---- */}
        <section className={`bx-panel ${activeTab === 'ram' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>Memory bandwidth</h2>
              <p>Sequential write, sequential read and random-access passes over a large typed array, run in a worker so timing isn't skewed by UI work. On {device.memArch === 'discrete' ? 'discrete-GPU' : 'unified-memory'} systems this also {device.memArch === 'discrete' ? 'samples VRAM upload/download bandwidth via WebGL' : 'reflects the memory pool the GPU shares'}.</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn" disabled={anyRunning} onClick={executeRamTest}>Run test</button>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout">
              <div className="bx-stat-row"><span className="bx-label">Status</span><span className="bx-val" style={{ fontSize: 12.5 }}>{ram.status}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Test buffer size</span><span className="bx-val">{ram.bytes ? `${Math.round(ram.bytes / (1024 * 1024))} MB` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Sequential write</span><span className="bx-val big">{ram.writeGBs ? `${fmt(ram.writeGBs, 2)} GB/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Sequential read</span><span className="bx-val big">{ram.readGBs ? `${fmt(ram.readGBs, 2)} GB/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Random access</span><span className="bx-val">{ram.randomMOpsSec ? `${fmt(ram.randomMOpsSec, 0)} M ops/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Memory architecture</span><span className="bx-val">{device.memArch === 'unified' ? 'Unified (RAM ≈ VRAM)' : device.memArch === 'discrete' ? 'Discrete GPU' : 'Unknown'}</span></div>
              {ram.vramUploadMBs !== null && (
                <div className="bx-stat-row"><span className="bx-label">VRAM upload / download (approx.)</span><span className="bx-val">{fmt(ram.vramUploadMBs, 0)} / {fmt(ram.vramDownloadMBs ?? 0, 0)} MB/s</span></div>
              )}
            </div>
            <div className="bx-readout bx-score-block">
              <div className="bx-score-label">Memory score</div>
              <div className={`bx-score-num ${scoreToneClass(ram.score)}`}>{ram.score ?? '--'}</div>
              <div className={`bx-score-grade ${scoreToneClass(ram.score)}`}>{scoreToGrade(ram.score)}</div>
              <p className="bx-note">Buffer size scales down on lower-memory devices to avoid tab crashes. VRAM figures are an approximation bound by the WebGL upload path, not raw silicon bandwidth.</p>
            </div>
          </div>
        </section>

        {/* ---- SSD ---- */}
        <section className={`bx-panel ${activeTab === 'ssd' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>Storage throughput</h2>
              <p>Writes and reads a real multi-megabyte file through the Origin Private File System - genuine disk I/O through your browser's sandboxed storage, not a synthetic estimate. Falls back to IndexedDB where OPFS isn't available.</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn" disabled={anyRunning} onClick={executeSsdTest}>Run test</button>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout">
              <div className="bx-stat-row"><span className="bx-label">Status</span><span className="bx-val" style={{ fontSize: 12.5 }}>{ssd.status}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Engine</span><span className="bx-val">{ssd.engine}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Test file size</span><span className="bx-val">{ssd.bytes ? `${Math.round(ssd.bytes / (1024 * 1024))} MB` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Sequential write</span><span className="bx-val big">{ssd.writeMBs ? `${fmt(ssd.writeMBs, 0)} MB/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Sequential read</span><span className="bx-val big">{ssd.readMBs ? `${fmt(ssd.readMBs, 0)} MB/s` : '-'}</span></div>
            </div>
            <div className="bx-readout bx-score-block">
              <div className="bx-score-label">Storage score</div>
              <div className={`bx-score-num ${scoreToneClass(ssd.score)}`}>{ssd.score ?? '--'}</div>
              <div className={`bx-score-grade ${scoreToneClass(ssd.score)}`}>{scoreToGrade(ssd.score)}</div>
              <p className="bx-note">The test file is deleted immediately after the run. Numbers reflect your browser's storage layer, which sits below native disk speed on every platform.</p>
            </div>
          </div>
        </section>

        {/* ---- Web browsing ---- */}
        <section className={`bx-panel ${activeTab === 'web' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>Web browsing</h2>
              <p>Speedometer-style suite: DOM node churn, forced layout/reflow, simulated text input, list sort &amp; filter re-rendering, and JSON serialize/parse - the same categories of work real web apps spend most of their time on. Combined via geometric mean, so one weak workload can't be masked by strong ones.</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn" disabled={anyRunning} onClick={executeWebTest}>Run test</button>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout">
              <div className="bx-stat-row"><span className="bx-label">Status</span><span className="bx-val" style={{ fontSize: 12.5 }}>{web.status}</span></div>
              <div className="bx-stat-row"><span className="bx-label">DOM churn (create/remove)</span><span className="bx-val">{web.domChurnOpsSec ? `${fmt(web.domChurnOpsSec, 0)} batches/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Forced layout / reflow</span><span className="bx-val">{web.layoutOpsSec ? `${fmt(web.layoutOpsSec, 0)} reads/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Text input simulation</span><span className="bx-val">{web.textEditOpsSec ? `${fmt(web.textEditOpsSec, 0)} edits/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">List sort &amp; filter</span><span className="bx-val">{web.listOpsSec ? `${fmt(web.listOpsSec, 0)} passes/s` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">JSON serialize/parse</span><span className="bx-val">{web.jsonOpsSec ? `${fmt(web.jsonOpsSec, 0)} passes/s` : '-'}</span></div>
            </div>
            <div className="bx-readout bx-score-block">
              <div className="bx-score-label">Web score</div>
              <div className={`bx-score-num ${scoreToneClass(web.score)}`}>{web.score ?? '--'}</div>
              <div className={`bx-score-grade ${scoreToneClass(web.score)}`}>{scoreToGrade(web.score)}</div>
              <p className="bx-note">Runs directly against the real DOM, so it briefly uses the main thread like any actual web page would - this is the one test that isn't perfectly smooth by design.</p>
            </div>
          </div>
        </section>

        {/* ---- Battery ---- */}
        <section className={`bx-panel ${activeTab === 'battery' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>Battery status</h2>
              <p>Reads live battery telemetry where the browser exposes it. Records the charge level the moment you start your first test, then scores how much it drained by the time you check back - a real efficiency reading from the load you just put on the device.</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn" disabled={anyRunning} onClick={executeBatteryTest}>Check battery</button>
              <button className="bx-btn ghost small" disabled={!batteryObjRef.current || battery.drainRunning} onClick={sampleBatteryDrain}>Sample drain (30s)</button>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout">
              <div className="bx-stat-row"><span className="bx-label">Support</span><span className="bx-val">{battery.supported}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Charge level</span><span className="bx-val big">{battery.level !== null ? `${battery.level}%` : '-'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Charging</span><span className="bx-val">{battery.charging === null ? '-' : battery.charging ? 'Yes' : 'No'}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Time to full / empty</span><span className="bx-val">{battery.time}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Session drain (since first test)</span><span className="bx-val" style={{ fontSize: 12.5 }}>{battery.sessionDrain}</span></div>
              <div className="bx-stat-row"><span className="bx-label">30s drain sample</span><span className="bx-val">{battery.drainSample}</span></div>
            </div>
            <div className="bx-readout bx-score-block">
              <div className="bx-score-label">Battery efficiency score</div>
              <div className={`bx-score-num ${scoreToneClass(battery.sessionScore)}`}>{battery.sessionScore ?? '--'}</div>
              <div className={`bx-score-grade ${scoreToneClass(battery.sessionScore)}`}>{scoreToGrade(battery.sessionScore)}</div>
              <p className="bx-note">Chrome and Edge on desktop and Android expose the Battery Status API. Safari, Firefox and iOS block it for privacy - check system settings instead there.</p>
              <p className="bx-note" style={{ marginTop: 12 }}>Extrapolated from a short sample, so it reads more extreme than steady-state use - accurate direction, noisy magnitude. Not counted in the overall device score.</p>
            </div>
          </div>
        </section>

        {/* ---- Display ---- */}
        <section className={`bx-panel ${activeTab === 'display' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>Display</h2>
              <p>Resolution, pixel density and refresh rate read directly from the screen, plus full-screen colour panels for dead-pixel and uniformity checks.</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn" disabled={anyRunning || display.measuring} onClick={() => executeDisplayTest()}>Measure refresh rate</button>
              <button className="bx-btn ghost small" onClick={() => showFullscreenColor(colorSequence)}>Dead-pixel test</button>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout">
              <div className="bx-stat-row"><span className="bx-label">Resolution</span><span className="bx-val">{display.res}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Device pixel ratio</span><span className="bx-val">{display.dpr}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Colour depth</span><span className="bx-val">{display.color}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Colour gamut</span><span className="bx-val">{display.gamut}</span></div>
              <div className="bx-stat-row"><span className="bx-label">HDR</span><span className="bx-val">{display.hdr}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Measured refresh rate</span><span className="bx-val big">{display.hz}</span></div>
            </div>
            <div className="bx-readout">
              <p className="bx-note">Dead-pixel test cycles through full-screen red, green, blue, white, black and a grey gradient. Look closely across the whole panel on each colour for a spot that doesn't change, or banding on the gradient.</p>
              <div className="bx-swatch-grid">
                {colorSequence.map((c) => (
                  <div key={c} className="bx-swatch" style={{ background: c }} onClick={() => showFullscreenColor([c])} />
                ))}
              </div>
              <p className="bx-note" style={{ marginTop: 12 }}>Click any swatch for a quick fullscreen check, or use &quot;Dead-pixel test&quot; for the full guided sequence.</p>
            </div>
          </div>
        </section>

        {/* ---- Speakers ---- */}
        <section className={`bx-panel ${activeTab === 'speakers' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>Speakers &amp; audio</h2>
              <p>Isolates left/right channels and sweeps frequency range so you can catch a blown driver, a dead channel, or a rattling enclosure.</p>
            </div>
          </div>
          <div className="bx-grid-2">
            <div className="bx-readout">
              <div className="bx-freq-display">{speakers.freq} Hz</div>
              <input type="range" aria-label="Tone frequency" min={20} max={20000} step={1} value={speakers.freq} onChange={(e) => {
                const v = parseInt(e.target.value, 10)
                setSpeakers((s) => ({ ...s, freq: v }))
                if (activeOscRef.current) activeOscRef.current.frequency.value = v
              }} />
              <div className="bx-btn-row" style={{ marginTop: 18, justifyContent: 'center' }}>
                <button className="bx-btn ghost small" onClick={() => playTone(-1)}>▶ Left only</button>
                <button className="bx-btn small" onClick={() => playTone(0)}>▶ Both</button>
                <button className="bx-btn ghost small" onClick={() => playTone(1)}>▶ Right only</button>
              </div>
              <div className="bx-btn-row" style={{ marginTop: 10, justifyContent: 'center' }}>
                <button className="bx-btn ghost small" onClick={playSweep}>▶ Frequency sweep (20Hz–20kHz, 8s)</button>
                <button className="bx-btn ghost small" onClick={stopAudio}>■ Stop</button>
              </div>
            </div>
            <div className="bx-readout">
              <p className="bx-note">Left / right only isolates each channel so you can confirm both speakers actually work and aren't swapped.</p>
              <p className="bx-note" style={{ marginTop: 12 }}>The sweep plays every audible frequency in order - most phone and laptop speakers roll off before 20kHz and below ~150Hz, that's normal. Listen for crackling, distortion, or a channel that cuts out partway through, which isn't.</p>
              <div className="bx-stat-row" style={{ marginTop: 16 }}><span className="bx-label">Audio context</span><span className="bx-val">{speakers.ctxStatus}</span></div>
              <div className="bx-stat-row"><span className="bx-label">Output channels</span><span className="bx-val">{speakers.channels}</span></div>
            </div>
          </div>
        </section>

        {/* ---- Report ---- */}
        <section className={`bx-panel ${activeTab === 'report' ? 'active' : ''}`}>
          <div className="bx-panel-head">
            <div>
              <h2>Device report</h2>
              <p>A summary you can screenshot or copy before making an offer, or before wiping a machine you're about to sell.</p>
            </div>
            <div className="bx-btn-row">
              <button className="bx-btn ghost small" onClick={copyReport}>Copy as text</button>
            </div>
          </div>
          <div className="bx-readout">
            <table className="bx-table">
              <thead><tr><th>Test</th><th>Result</th><th>Score</th><th>Status</th></tr></thead>
              <tbody>
                {TAB_ORDER.map((key) => {
                  const r = results[key]
                  if (!r) return (
                    <tr key={key}><td>{LABELS[key]}</td><td>-</td><td>-</td><td><span className="bx-pill na">not run</span></td></tr>
                  )
                  const pillClass = r.grade === 'not available' ? 'na' : (typeof r.score === 'number' && r.score < 40 ? 'warn' : 'pass')
                  return (
                    <Fragment key={key}>
                      <tr>
                        <td>{LABELS[key]}</td><td>{r.summary}</td><td>{r.score ?? '-'}</td>
                        <td><span className={`bx-pill ${pillClass}`}>{r.grade}</span></td>
                      </tr>
                      {r.subs.map((s) => (
                        <tr key={`${key}-${s.label}`} className="bx-subtest">
                          <td>{s.label}</td><td>{s.value}{s.note ? ` - ${s.note}` : ''}</td><td>{s.score ?? '-'}</td><td></td>
                        </tr>
                      ))}
                    </Fragment>
                  )
                })}
              </tbody>
            </table>
          </div>
          <div className="bx-readout" style={{ marginTop: 18 }}>
            <div className="bx-score-block">
              <div className="bx-score-label">Overall device score</div>
              <div className={`bx-score-num ${scoreToneClass(overall)}`}>{overall ?? '--'}</div>
              <div className={`bx-score-grade ${scoreToneClass(overall)}`}>{overall === null ? 'run tests to generate' : scoreToGrade(overall)}</div>
              <p className="bx-note">Overall blends CPU (25%), GPU (25%), memory (15%), storage (15%) and web browsing (20%). Battery gets its own efficiency score but isn't part of this blend; display and speakers are diagnostic reads only.</p>
            </div>
          </div>
        </section>
      </main>

      <footer className="bx-footer">
        <span>NexaBench - runs entirely in your browser. Nothing is uploaded anywhere.</span>
        <span>{device.ua.slice(0, 70)}</span>
      </footer>
    </>
  )
}
