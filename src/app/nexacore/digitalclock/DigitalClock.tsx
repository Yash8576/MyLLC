import { useState, useEffect } from 'react'
import './Clock.css'

interface DigitalClockProps {
  clockSize: number
  theme: string
}

function DigitalClock({ clockSize, theme }: DigitalClockProps) {
  const [time, setTime] = useState(new Date())

  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 1000)
    return () => clearInterval(id)
  }, [])

  const hours   = time.getHours()
  const minutes = String(time.getMinutes()).padStart(2, '0')
  const seconds = String(time.getSeconds()).padStart(2, '0')
  const ampm    = hours >= 12 ? 'PM' : 'AM'
  const h12     = String(hours % 12 || 12).padStart(2, '0')
  const dateStr = time.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' })

  return (
    <div
      className={`clock-root clock-${theme}`}
      style={{ '--clock-size': `${clockSize}px` } as React.CSSProperties}
    >
      <div className="clock-date">{dateStr}</div>
      <div className="clock-time">
        <span className="clock-hhmm">
          {h12}<span className="clock-sep">:</span>{minutes}
        </span>
        <div className="clock-sub">
          <span className="clock-ampm">{ampm}</span>
          <span className="clock-seconds">{seconds}</span>
        </div>
      </div>
    </div>
  )
}

export default DigitalClock
