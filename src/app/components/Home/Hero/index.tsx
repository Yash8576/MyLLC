const Hero = () => {
  return (
    <section id='home' className='bg-slate-gray min-h-screen flex items-center'>
      <div className='container pt-24 pb-14'>
        <div className='flex flex-col items-center justify-center text-center gap-8'>
          <h1 className='text-midnight_text font-bold leading-tight'>
            Nexacore is Future company
            <br />
            that builds software
          </h1>
          <div className='mt-8'>
            <div className='w-20 h-1 bg-primary mx-auto'></div>
          </div>
        </div>
      </div>
    </section>
  )
}

export default Hero
