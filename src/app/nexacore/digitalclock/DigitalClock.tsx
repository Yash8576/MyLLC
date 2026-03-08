import React, { useState, useEffect } from 'react';

interface DigitalClockProps {
  textColor: string;
  clockSize: number;
}

function DigitalClock({ textColor, clockSize }: DigitalClockProps) {
  const [time, setTime] = useState(new Date());
  useEffect(() => {
    const timerID = setInterval(() => {
      setTime(new Date());
    }, 1000);
    return function cleanup() {
      clearInterval(timerID);
    }
  }, []);
  
  const formattedTime = time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  return (
    <div
      style={{
        fontSize: `${clockSize}px`,
        fontWeight: 'bold',
        textAlign: 'center',
        fontFamily: 'monospace',
        color: textColor,
      }}
    >
      {formattedTime}
    </div>
  );
}
export default DigitalClock;
